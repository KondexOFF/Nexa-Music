// NEXA AutoTest - WASAPI loopback recorder.
//
// Records audio output into a mono 32-bit float WAV file, so the AutoTest
// can measure real audio: which test tone is audible, crossfade overlap,
// gapless gaps, clipping, silence on pause, volume.
//
// Usage: loopback_capture.exe <out.wav> <seconds> [pid] [endpoint id]
//        loopback_capture.exe --check [endpoint id]
//                                         (can sound be measured at all?)
//
// During a recording the recorder also watches the Windows output: mute and
// volume of the default device and of the recorded process's own session
// (Volume mixer). READY / DONE report them, so a muted output is reported
// as "not measurable" instead of a wrong result.
//
// With a process id the recorder uses WASAPI *process* loopback (Windows 10
// 2004+ / Windows 11): only the audio of that process tree is recorded, so
// other programs playing at the same time (browser, voice chat, system
// sounds) cannot disturb the measurement. Without a pid, or if process
// loopback is unavailable, it records the whole default output device
// (system loopback) and says so ("mode=system").
//
// With an endpoint id ("{0.0.0.00000000}.{guid}", the device NEXA was told
// to play on, e.g. an unused digital output) it records that device only
// ("mode=device") and watches its mute / volume. The AutoTest uses this so
// its test tones are not heard on the owner's speakers or headset, and
// nothing else plays on that device to disturb the measurement.
//
// Packets are placed on a wall-clock timeline (QPC time stamps); stretches
// without packets become silence, so real gaps stay in the recording.
//
// Prints "READY ..." when the capture runs and "DONE ..." when the file is
// written. Built by tools/autotest/NEXA_AutoTest.ps1; never part of the app.

#define NOMINMAX  // std::min, not the Windows macro
#include <windows.h>

#include <audioclient.h>
#include <audioclientactivationparams.h>
#include <audiopolicy.h>
#include <endpointvolume.h>
#include <mmdeviceapi.h>
#include <mmreg.h>
#include <wrl/implements.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "mmdevapi.lib")

namespace {

using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::FtmBase;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;

template <typename T>
void SafeRelease(T** p) {
  if (*p) {
    (*p)->Release();
    *p = nullptr;
  }
}

bool WriteWav(const wchar_t* path, const std::vector<float>& samples,
              DWORD rate) {
  FILE* f = nullptr;
  if (_wfopen_s(&f, path, L"wb") != 0 || !f) {
    return false;
  }
  const WORD channels = 1;
  const DWORD data_bytes = static_cast<DWORD>(samples.size() * sizeof(float));
  const DWORD fmt_size = 16;
  const DWORD riff_size = 4 + (8 + fmt_size) + (8 + data_bytes);
  const WORD format = 3;  // IEEE float
  const WORD bits = 32;
  const WORD block = static_cast<WORD>(channels * bits / 8);
  const DWORD byte_rate = rate * block;
  fwrite("RIFF", 1, 4, f);
  fwrite(&riff_size, 4, 1, f);
  fwrite("WAVEfmt ", 1, 8, f);
  fwrite(&fmt_size, 4, 1, f);
  fwrite(&format, 2, 1, f);
  fwrite(&channels, 2, 1, f);
  fwrite(&rate, 4, 1, f);
  fwrite(&byte_rate, 4, 1, f);
  fwrite(&block, 2, 1, f);
  fwrite(&bits, 2, 1, f);
  fwrite("data", 1, 4, f);
  fwrite(&data_bytes, 4, 1, f);
  if (!samples.empty()) {
    fwrite(samples.data(), sizeof(float), samples.size(), f);
  }
  fclose(f);
  return true;
}

int Fail(const char* step, HRESULT hr) {
  fprintf(stderr, "ERROR %s hr=0x%08lx\n", step, static_cast<unsigned long>(hr));
  return 1;
}

// Completion handler for ActivateAudioInterfaceAsync (must be agile).
class ActivationHandler
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>, FtmBase,
                          IActivateAudioInterfaceCompletionHandler> {
 public:
  ActivationHandler() { done_ = CreateEventW(nullptr, TRUE, FALSE, nullptr); }
  ~ActivationHandler() {
    if (done_) CloseHandle(done_);
  }

  STDMETHOD(ActivateCompleted)
  (IActivateAudioInterfaceAsyncOperation* operation) override {
    HRESULT activate = E_FAIL;
    IUnknown* unknown = nullptr;
    HRESULT hr = operation->GetActivateResult(&activate, &unknown);
    if (SUCCEEDED(hr) && SUCCEEDED(activate) && unknown) {
      result_ = unknown->QueryInterface(IID_PPV_ARGS(&client_));
    } else {
      result_ = FAILED(hr) ? hr : activate;
    }
    SafeRelease(&unknown);
    SetEvent(done_);
    return S_OK;
  }

  HANDLE done_ = nullptr;
  HRESULT result_ = E_FAIL;
  IAudioClient* client_ = nullptr;
};

// IAudioClient that captures only the audio of process [pid] and its
// children. Null if Windows does not support it.
IAudioClient* ActivateProcessLoopback(DWORD pid, HRESULT* error) {
  AUDIOCLIENT_ACTIVATION_PARAMS params = {};
  params.ActivationType = AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
  params.ProcessLoopbackParams.TargetProcessId = pid;
  params.ProcessLoopbackParams.ProcessLoopbackMode =
      PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE;
  PROPVARIANT variant = {};
  variant.vt = VT_BLOB;
  variant.blob.cbSize = sizeof(params);
  variant.blob.pBlobData = reinterpret_cast<BYTE*>(&params);

  auto handler = Microsoft::WRL::Make<ActivationHandler>();
  IActivateAudioInterfaceAsyncOperation* operation = nullptr;
  HRESULT hr = ActivateAudioInterfaceAsync(
      VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK, __uuidof(IAudioClient), &variant,
      handler.Get(), &operation);
  if (FAILED(hr)) {
    *error = hr;
    return nullptr;
  }
  if (WaitForSingleObject(handler->done_, 5000) != WAIT_OBJECT_0) {
    SafeRelease(&operation);
    *error = HRESULT_FROM_WIN32(ERROR_TIMEOUT);
    return nullptr;
  }
  SafeRelease(&operation);
  if (FAILED(handler->result_) || !handler->client_) {
    *error = handler->result_;
    return nullptr;
  }
  IAudioClient* client = handler->client_;
  handler->client_ = nullptr;
  return client;
}

// Mute / volume of the output: the default device (Windows volume) and the
// audio session(s) of process [pid] (its slider in the Volume mixer).
struct OutputState {
  bool endpoint_mute = false;
  float endpoint_volume = -1;
  bool session_found = false;
  bool session_mute = false;
  float session_volume = -1;
};

class OutputMonitor {
 public:
  OutputMonitor(IMMDevice* device, DWORD pid) : pid_(pid) {
    if (!device) return;
    device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                     reinterpret_cast<void**>(&endpoint_));
    if (pid_ != 0) {
      device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr,
                       reinterpret_cast<void**>(&sessions_));
    }
  }
  ~OutputMonitor() {
    SafeRelease(&endpoint_);
    SafeRelease(&sessions_);
  }

  OutputState Read() {
    OutputState s;
    if (endpoint_) {
      BOOL mute = FALSE;
      float volume = 0;
      if (SUCCEEDED(endpoint_->GetMute(&mute))) s.endpoint_mute = mute != FALSE;
      if (SUCCEEDED(endpoint_->GetMasterVolumeLevelScalar(&volume))) {
        s.endpoint_volume = volume;
      }
    }
    IAudioSessionEnumerator* list = nullptr;
    if (sessions_ && SUCCEEDED(sessions_->GetSessionEnumerator(&list))) {
      int count = 0;
      list->GetCount(&count);
      for (int i = 0; i < count; i++) {
        IAudioSessionControl* control = nullptr;
        IAudioSessionControl2* control2 = nullptr;
        ISimpleAudioVolume* volume = nullptr;
        if (SUCCEEDED(list->GetSession(i, &control)) &&
            SUCCEEDED(control->QueryInterface(IID_PPV_ARGS(&control2)))) {
          DWORD owner = 0;
          control2->GetProcessId(&owner);
          if (owner == pid_ &&
              SUCCEEDED(control->QueryInterface(IID_PPV_ARGS(&volume)))) {
            BOOL mute = FALSE;
            float level = 0;
            volume->GetMute(&mute);
            volume->GetMasterVolume(&level);
            s.session_mute = s.session_mute || mute != FALSE;
            s.session_volume = s.session_found ? std::min(s.session_volume, level) : level;
            s.session_found = true;
          }
        }
        SafeRelease(&volume);
        SafeRelease(&control2);
        SafeRelease(&control);
      }
      list->Release();
    }
    return s;
  }

 private:
  DWORD pid_;
  IAudioEndpointVolume* endpoint_ = nullptr;
  IAudioSessionManager2* sessions_ = nullptr;
};

std::string DeviceName(IMMDevice* device) {
  std::string out = "unknown";
  IPropertyStore* store = nullptr;
  if (device && SUCCEEDED(device->OpenPropertyStore(STGM_READ, &store))) {
    PROPVARIANT name;
    PropVariantInit(&name);
    // PKEY_Device_FriendlyName
    const PROPERTYKEY friendly = {
        {0xa45c254e, 0xdf1c, 0x4efd, {0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0}}, 14};
    if (SUCCEEDED(store->GetValue(friendly, &name)) &&
        name.vt == VT_LPWSTR) {
      const int n = WideCharToMultiByte(CP_UTF8, 0, name.pwszVal, -1, nullptr, 0, nullptr, nullptr);
      if (n > 1) {
        out.assign(static_cast<size_t>(n - 1), '\0');
        WideCharToMultiByte(CP_UTF8, 0, name.pwszVal, -1, &out[0], n, nullptr, nullptr);
      }
    }
    PropVariantClear(&name);
    store->Release();
  }
  return out;
}

LONGLONG Now100ns() {
  static LARGE_INTEGER freq = {};
  if (freq.QuadPart == 0) QueryPerformanceFrequency(&freq);
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  return static_cast<LONGLONG>(now.QuadPart * 10000000.0 / freq.QuadPart);
}

// "--check": can the AutoTest measure sound at all? Prints one CHECK line.
// Exit 0 = ready, 3 = output muted or at 0 %, 4 = no output device,
// 5 = loopback capture not available.
// The output device to use: [endpoint] if given, else the Windows default.
HRESULT GetOutput(IMMDeviceEnumerator* enumerator, const wchar_t* endpoint,
                  IMMDevice** device) {
  if (endpoint && *endpoint) {
    return enumerator->GetDevice(endpoint, device);
  }
  return enumerator->GetDefaultAudioEndpoint(eRender, eConsole, device);
}

int Check(const wchar_t* endpoint) {
  IMMDeviceEnumerator* enumerator = nullptr;
  IMMDevice* device = nullptr;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                              IID_PPV_ARGS(&enumerator))) ||
      FAILED(GetOutput(enumerator, endpoint, &device))) {
    printf("CHECK device=none\n");
    SafeRelease(&enumerator);
    return 4;
  }
  OutputState state;
  {
    OutputMonitor monitor(device, 0);
    state = monitor.Read();
  }
  // System loopback of the default device.
  HRESULT system_hr = E_FAIL;
  IAudioClient* client = nullptr;
  WAVEFORMATEX* format = nullptr;
  if (SUCCEEDED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                 reinterpret_cast<void**>(&client))) &&
      SUCCEEDED(client->GetMixFormat(&format))) {
    system_hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                   AUDCLNT_STREAMFLAGS_LOOPBACK, 2000000, 0,
                                   format, nullptr);
  }
  CoTaskMemFree(format);
  SafeRelease(&client);
  // Process loopback (what the AutoTest records), tried on this process.
  HRESULT process_hr = S_OK;
  IAudioClient* process = ActivateProcessLoopback(GetCurrentProcessId(), &process_hr);
  if (process) {
    WAVEFORMATEX wanted = {};
    wanted.wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
    wanted.nChannels = 2;
    wanted.nSamplesPerSec = 48000;
    wanted.wBitsPerSample = 32;
    wanted.nBlockAlign = 8;
    wanted.nAvgBytesPerSec = 48000 * 8;
    process_hr = process->Initialize(
        AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM, 2000000,
        0, &wanted, nullptr);
    process->Release();
  } else if (SUCCEEDED(process_hr)) {
    process_hr = E_FAIL;
  }
  printf("CHECK device=\"%s\" endpoint_mute=%d endpoint_volume=%.3f "
         "system_loopback=%s process_loopback=%s\n",
         DeviceName(device).c_str(), state.endpoint_mute ? 1 : 0, state.endpoint_volume,
         SUCCEEDED(system_hr) ? "ok" : "failed", SUCCEEDED(process_hr) ? "ok" : "failed");
  fflush(stdout);
  SafeRelease(&device);
  SafeRelease(&enumerator);
  if (FAILED(system_hr) && FAILED(process_hr)) return 5;
  if (state.endpoint_mute || (state.endpoint_volume >= 0 && state.endpoint_volume < 0.01f)) return 3;
  return 0;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc >= 2 && wcscmp(argv[1], L"--check") == 0) {
    if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return 5;
    const int code = Check(argc >= 3 ? argv[2] : nullptr);
    CoUninitialize();
    return code;
  }
  if (argc < 3) {
    fprintf(stderr,
            "usage: loopback_capture <out.wav> <seconds> [pid] [endpoint id] | "
            "--check [endpoint id]\n");
    return 2;
  }
  const double seconds = _wtof(argv[2]);
  const DWORD pid = argc >= 4 ? static_cast<DWORD>(_wtoi(argv[3])) : 0;
  const wchar_t* endpoint = argc >= 5 && *argv[4] ? argv[4] : nullptr;
  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(hr)) return Fail("CoInitializeEx", hr);

  IMMDeviceEnumerator* enumerator = nullptr;
  IMMDevice* device = nullptr;
  IAudioClient* render = nullptr;
  IAudioRenderClient* render_client = nullptr;
  IAudioClient* capture = nullptr;
  IAudioCaptureClient* capture_client = nullptr;
  WAVEFORMATEX* mix_format = nullptr;
  WAVEFORMATEX* render_format = nullptr;
  UINT32 render_frames = 0;
  HANDLE packet_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);

  // Format of the captured data.
  WORD channels = 2;
  DWORD rate = 48000;
  bool is_float = true;
  WORD bits = 32;
  const char* mode = "system";
  HRESULT process_error = S_OK;

  // Output device (the given endpoint or the default one): watched for
  // mute / volume during the recording (and used for system loopback).
  if (SUCCEEDED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                 IID_PPV_ARGS(&enumerator)))) {
    hr = GetOutput(enumerator, endpoint, &device);
    if (FAILED(hr) && endpoint) return Fail("GetDevice endpoint", hr);
  }
  if (pid != 0 && !endpoint) {
    capture = ActivateProcessLoopback(pid, &process_error);
  }
  if (capture) {
    // Process loopback has no mix format of its own: ask for float stereo
    // and let Windows convert.
    WAVEFORMATEX wanted = {};
    wanted.wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
    wanted.nChannels = channels;
    wanted.nSamplesPerSec = rate;
    wanted.wBitsPerSample = bits;
    wanted.nBlockAlign = static_cast<WORD>(channels * bits / 8);
    wanted.nAvgBytesPerSec = rate * wanted.nBlockAlign;
    hr = capture->Initialize(
        AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
            AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
            AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
        2000000, 0, &wanted, nullptr);
    if (FAILED(hr)) {
      process_error = hr;
      SafeRelease(&capture);
    } else {
      mode = "process";
    }
  }

  if (!capture) {
    // System loopback of the default output device. A silent render stream
    // keeps packets coming while nothing plays.
    if (!device) return Fail("GetDefaultAudioEndpoint", E_FAIL);
    if (endpoint) mode = "device";
    hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                          reinterpret_cast<void**>(&render));
    if (FAILED(hr)) return Fail("Activate render", hr);
    render->GetMixFormat(&render_format);
    hr = render->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 2000000, 0,
                            render_format, nullptr);
    if (FAILED(hr)) return Fail("Initialize render", hr);
    hr = render->GetService(IID_PPV_ARGS(&render_client));
    if (FAILED(hr)) return Fail("GetService render", hr);
    render->GetBufferSize(&render_frames);
    BYTE* buffer = nullptr;
    if (SUCCEEDED(render_client->GetBuffer(render_frames, &buffer))) {
      render_client->ReleaseBuffer(render_frames, AUDCLNT_BUFFERFLAGS_SILENT);
    }
    render->Start();

    hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                          reinterpret_cast<void**>(&capture));
    if (FAILED(hr)) return Fail("Activate capture", hr);
    hr = capture->GetMixFormat(&mix_format);
    if (FAILED(hr)) return Fail("GetMixFormat", hr);
    hr = capture->Initialize(
        AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
        2000000, 0, mix_format, nullptr);
    if (FAILED(hr)) return Fail("Initialize loopback", hr);
    channels = mix_format->nChannels;
    rate = mix_format->nSamplesPerSec;
    bits = mix_format->wBitsPerSample;
    is_float = mix_format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT;
    if (mix_format->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
      const auto* ext = reinterpret_cast<WAVEFORMATEXTENSIBLE*>(mix_format);
      is_float = ext->SubFormat.Data1 == 3;  // KSDATAFORMAT_SUBTYPE_IEEE_FLOAT
    }
  }

  hr = capture->SetEventHandle(packet_event);
  if (FAILED(hr)) return Fail("SetEventHandle", hr);
  hr = capture->GetService(IID_PPV_ARGS(&capture_client));
  if (FAILED(hr)) return Fail("GetService capture", hr);

  const size_t target = static_cast<size_t>(seconds * rate);
  std::vector<float> samples;
  samples.reserve(target + rate);
  unsigned long discontinuities = 0;
  unsigned long packets = 0;

  auto* monitor = new OutputMonitor(device, pid);
  const OutputState first = monitor->Read();
  bool muted_seen = first.endpoint_mute || first.session_mute;
  float min_endpoint = first.endpoint_volume;
  float min_session = first.session_found ? first.session_volume : -1;
  bool session_seen = first.session_found;
  auto watch = [&]() {
    const OutputState s = monitor->Read();
    muted_seen = muted_seen || s.endpoint_mute || s.session_mute;
    if (s.endpoint_volume >= 0) {
      min_endpoint = min_endpoint < 0 ? s.endpoint_volume : std::min(min_endpoint, s.endpoint_volume);
    }
    if (s.session_found) {
      min_session = min_session < 0 ? s.session_volume : std::min(min_session, s.session_volume);
      session_seen = true;
    }
  };

  hr = capture->Start();
  if (FAILED(hr)) return Fail("Start capture", hr);
  const LONGLONG start = Now100ns();
  const LONGLONG duration = static_cast<LONGLONG>(seconds * 10000000.0);
  LONGLONG next_watch = start;
  printf("READY mode=%s rate=%lu channels=%u float=%d bits=%u device=\"%s\" "
         "endpoint_mute=%d endpoint_volume=%.3f session=%d session_mute=%d session_volume=%.3f",
         mode, static_cast<unsigned long>(rate), channels, is_float ? 1 : 0, bits,
         DeviceName(device).c_str(), first.endpoint_mute ? 1 : 0, first.endpoint_volume,
         first.session_found ? 1 : 0, first.session_mute ? 1 : 0, first.session_volume);
  if (pid != 0 && FAILED(process_error)) {
    printf(" process_loopback_error=0x%08lx",
           static_cast<unsigned long>(process_error));
  }
  printf("\n");
  fflush(stdout);

  // Mono (mean of all channels): matches the analyser's downmix.
  auto append = [&](const BYTE* data, UINT32 frames, bool silent) {
    for (UINT32 i = 0; i < frames; i++) {
      double sum = 0;
      if (!silent && data) {
        for (WORD c = 0; c < channels; c++) {
          const size_t k = static_cast<size_t>(i) * channels + c;
          if (is_float && bits == 32) {
            sum += reinterpret_cast<const float*>(data)[k];
          } else if (bits == 16) {
            sum += reinterpret_cast<const short*>(data)[k] / 32768.0;
          } else if (bits == 32) {
            sum += reinterpret_cast<const int*>(data)[k] / 2147483648.0;
          }
        }
      }
      samples.push_back(static_cast<float>(sum / channels));
    }
  };
  const size_t max_jump = rate / 50;  // 20 ms

  while (Now100ns() - start < duration) {
    if (Now100ns() >= next_watch) {
      watch();  // mute / volume, four times a second
      next_watch = Now100ns() + 2500000;
    }
    if (render) {
      UINT32 padding = 0;
      if (SUCCEEDED(render->GetCurrentPadding(&padding)) &&
          padding < render_frames) {
        const UINT32 free_frames = render_frames - padding;
        BYTE* buffer = nullptr;
        if (SUCCEEDED(render_client->GetBuffer(free_frames, &buffer))) {
          render_client->ReleaseBuffer(free_frames, AUDCLNT_BUFFERFLAGS_SILENT);
        }
      }
    }
    WaitForSingleObject(packet_event, 20);
    UINT32 packet = 0;
    capture_client->GetNextPacketSize(&packet);
    while (packet > 0) {
      BYTE* data = nullptr;
      UINT32 frames = 0;
      DWORD flags = 0;
      UINT64 qpc = 0;
      if (FAILED(capture_client->GetBuffer(&data, &frames, &flags, nullptr,
                                           &qpc))) {
        break;
      }
      packets++;
      if (flags & AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY) {
        discontinuities++;
      }
      // Wall-clock place of this packet: a hole of more than 20 ms (no
      // packets while nothing played) becomes silence.
      if (qpc != 0 && static_cast<LONGLONG>(qpc) > start) {
        const size_t expected = static_cast<size_t>(
            (static_cast<LONGLONG>(qpc) - start) * static_cast<double>(rate) /
            10000000.0);
        if (expected > samples.size() + max_jump) {
          samples.resize(expected, 0.0f);
        }
      }
      append(data, frames, (flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0);
      capture_client->ReleaseBuffer(frames);
      capture_client->GetNextPacketSize(&packet);
    }
  }
  capture->Stop();
  if (render) render->Stop();
  if (samples.size() < target) {
    samples.resize(target, 0.0f);  // trailing silence without packets
  } else if (samples.size() > target) {
    samples.resize(target);
  }

  const bool ok = WriteWav(argv[1], samples, rate);
  watch();
  printf("DONE mode=%s frames=%zu packets=%lu discontinuities=%lu written=%d "
         "muted_seen=%d min_endpoint_volume=%.3f session_seen=%d min_session_volume=%.3f\n",
         mode, samples.size(), packets, discontinuities, ok ? 1 : 0, muted_seen ? 1 : 0,
         min_endpoint, session_seen ? 1 : 0, min_session);
  fflush(stdout);

  delete monitor;
  CoTaskMemFree(mix_format);
  CoTaskMemFree(render_format);
  SafeRelease(&capture_client);
  SafeRelease(&capture);
  SafeRelease(&render_client);
  SafeRelease(&render);
  SafeRelease(&device);
  SafeRelease(&enumerator);
  CloseHandle(packet_event);
  CoUninitialize();
  return ok ? 0 : 1;
}
