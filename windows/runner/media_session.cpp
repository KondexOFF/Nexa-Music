#include "media_session.h"

#include <roapi.h>
#include <systemmediatransportcontrolsinterop.h>
#include <wrl/event.h>
#include <wrl/wrappers/corewrappers.h>

namespace {

using ABI::Windows::Media::ISystemMediaTransportControls;
using ABI::Windows::Media::ISystemMediaTransportControlsButtonPressedEventArgs;
using ABI::Windows::Media::ISystemMediaTransportControlsDisplayUpdater;
using ABI::Windows::Media::IMusicDisplayProperties;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Wrappers::HString;
using Microsoft::WRL::Wrappers::HStringReference;

using ButtonHandler = ABI::Windows::Foundation::ITypedEventHandler<
    ABI::Windows::Media::SystemMediaTransportControls*,
    ABI::Windows::Media::SystemMediaTransportControlsButtonPressedEventArgs*>;

// UTF-8 -> HSTRING.
HString ToHString(const std::string& utf8) {
  HString result;
  if (utf8.empty()) {
    return result;
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  if (length <= 0) {
    return result;
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), length);
  result.Set(wide.c_str(), static_cast<unsigned int>(wide.size()));
  return result;
}

}  // namespace

MediaSession::~MediaSession() { Detach(); }

bool MediaSession::Attach(HWND window) {
  Detach();
  ComPtr<ISystemMediaTransportControlsInterop> interop;
  HRESULT hr = RoGetActivationFactory(
      HStringReference(RuntimeClass_Windows_Media_SystemMediaTransportControls)
          .Get(),
      IID_PPV_ARGS(&interop));
  if (FAILED(hr) || !interop) {
    return false;
  }
  ComPtr<ISystemMediaTransportControls> controls;
  hr = interop->GetForWindow(window, IID_PPV_ARGS(&controls));
  if (FAILED(hr) || !controls) {
    return false;
  }
  controls->put_IsPlayEnabled(true);
  controls->put_IsPauseEnabled(true);
  controls->put_IsStopEnabled(true);
  controls->put_IsNextEnabled(true);
  controls->put_IsPreviousEnabled(true);
  // Hidden until something is loaded (Update with a title).
  controls->put_IsEnabled(false);
  controls->put_PlaybackStatus(
      ABI::Windows::Media::MediaPlaybackStatus_Closed);

  auto handler = Microsoft::WRL::Callback<ButtonHandler>(
      [window](ISystemMediaTransportControls*,
               ISystemMediaTransportControlsButtonPressedEventArgs* args)
          -> HRESULT {
        ABI::Windows::Media::SystemMediaTransportControlsButton button;
        if (FAILED(args->get_Button(&button))) {
          return S_OK;
        }
        WPARAM code = 0;
        switch (button) {
          case ABI::Windows::Media::SystemMediaTransportControlsButton_Play:
            code = kPlay;
            break;
          case ABI::Windows::Media::SystemMediaTransportControlsButton_Pause:
            code = kPause;
            break;
          case ABI::Windows::Media::SystemMediaTransportControlsButton_Stop:
            code = kStop;
            break;
          case ABI::Windows::Media::SystemMediaTransportControlsButton_Next:
            code = kNext;
            break;
          case ABI::Windows::Media::
              SystemMediaTransportControlsButton_Previous:
            code = kPrevious;
            break;
          default:
            return S_OK;
        }
        // System thread -> UI thread.
        PostMessage(window, kButtonMessage, code, 0);
        return S_OK;
      });
  if (!handler ||
      FAILED(controls->add_ButtonPressed(handler.Get(), &button_token_))) {
    return false;
  }
  controls_ = controls;
  attached_ = true;
  return true;
}

void MediaSession::Detach() {
  if (controls_) {
    if (attached_) {
      controls_->remove_ButtonPressed(button_token_);
    }
    controls_->put_IsEnabled(false);
  }
  controls_.Reset();
  attached_ = false;
}

void MediaSession::Update(bool playing, const std::string& title,
                          const std::string& artist) {
  if (!controls_) {
    return;
  }
  if (title.empty()) {
    controls_->put_PlaybackStatus(
        ABI::Windows::Media::MediaPlaybackStatus_Closed);
    controls_->put_IsEnabled(false);
    return;
  }
  controls_->put_IsEnabled(true);
  controls_->put_PlaybackStatus(
      playing ? ABI::Windows::Media::MediaPlaybackStatus_Playing
              : ABI::Windows::Media::MediaPlaybackStatus_Paused);

  ComPtr<ISystemMediaTransportControlsDisplayUpdater> updater;
  if (FAILED(controls_->get_DisplayUpdater(&updater)) || !updater) {
    return;
  }
  updater->put_Type(ABI::Windows::Media::MediaPlaybackType_Music);
  ComPtr<IMusicDisplayProperties> music;
  if (SUCCEEDED(updater->get_MusicProperties(&music)) && music) {
    HString t = ToHString(title);
    HString a = ToHString(artist);
    music->put_Title(t.Get());
    music->put_Artist(a.Get());
  }
  updater->Update();
}
