#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Hot key ids and the Dart method each media key sends.
constexpr int kMediaHotKeyBase = 0xB100;
constexpr UINT kMediaVirtualKeys[4] = {VK_MEDIA_PLAY_PAUSE, VK_MEDIA_NEXT_TRACK,
                                       VK_MEDIA_PREV_TRACK, VK_MEDIA_STOP};
constexpr const char* kMediaMethods[4] = {"playPause", "next", "previous",
                                          "stop"};

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  media_keys_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "nexa/media_keys",
          &flutter::StandardMethodCodec::GetInstance());
  RegisterMediaKeys();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterMediaKeys() {
  for (int i = 0; i < 4; i++) {
    media_hotkeys_registered_[i] =
        RegisterHotKey(GetHandle(), kMediaHotKeyBase + i, MOD_NOREPEAT,
                       kMediaVirtualKeys[i]) != 0;
  }
}

void FlutterWindow::UnregisterMediaKeys() {
  for (int i = 0; i < 4; i++) {
    if (media_hotkeys_registered_[i]) {
      UnregisterHotKey(GetHandle(), kMediaHotKeyBase + i);
      media_hotkeys_registered_[i] = false;
    }
  }
}

void FlutterWindow::SendMediaKey(const char* method) {
  if (media_keys_channel_) {
    media_keys_channel_->InvokeMethod(method, nullptr);
  }
}

void FlutterWindow::OnDestroy() {
  UnregisterMediaKeys();
  media_keys_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_HOTKEY: {
      const int index = static_cast<int>(wparam) - kMediaHotKeyBase;
      if (index >= 0 && index < 4) {
        SendMediaKey(kMediaMethods[index]);
        return 0;
      }
      break;
    }
    case WM_APPCOMMAND: {
      switch (GET_APPCOMMAND_LPARAM(lparam)) {
        case APPCOMMAND_MEDIA_PLAY_PAUSE:
          SendMediaKey(kMediaMethods[0]);
          return TRUE;
        case APPCOMMAND_MEDIA_NEXTTRACK:
          SendMediaKey(kMediaMethods[1]);
          return TRUE;
        case APPCOMMAND_MEDIA_PREVIOUSTRACK:
          SendMediaKey(kMediaMethods[2]);
          return TRUE;
        case APPCOMMAND_MEDIA_STOP:
          SendMediaKey(kMediaMethods[3]);
          return TRUE;
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
