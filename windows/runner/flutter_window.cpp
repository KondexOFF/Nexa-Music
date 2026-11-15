#include "flutter_window.h"

#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Dart methods the media keys send.
constexpr const char* kMediaMethods[4] = {"playPause", "next", "previous",
                                          "stop"};

int IntArg(const flutter::EncodableMap& map, const char* key, int fallback) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it != map.end()) {
    if (const auto* value = std::get_if<int32_t>(&it->second)) {
      return *value;
    }
  }
  return fallback;
}

bool BoolArg(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it != map.end()) {
    if (const auto* value = std::get_if<bool>(&it->second)) {
      return *value;
    }
  }
  return false;
}

std::string StringArg(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it != map.end()) {
    if (const auto* value = std::get_if<std::string>(&it->second)) {
      return *value;
    }
  }
  return std::string();
}

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
  media_keys_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMediaCall(call, std::move(result));
      });
  media_session_attached_ = media_session_.Attach(GetHandle());
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "nexa/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleWindowCall(call, std::move(result));
      });
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

void FlutterWindow::HandleMediaCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "update") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      bool playing = false;
      auto it = args->find(flutter::EncodableValue("playing"));
      if (it != args->end()) {
        if (const auto* value = std::get_if<bool>(&it->second)) {
          playing = *value;
        }
      }
      media_session_.Update(playing, StringArg(*args, "title"),
                            StringArg(*args, "artist"));
    }
    result->Success(flutter::EncodableValue(media_session_attached_));
    return;
  }
  result->NotImplemented();
}

void FlutterWindow::HandleWindowCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  HWND hwnd = GetHandle();
  if (call.method_name() != "setMini" || !args || !hwnd) {
    result->NotImplemented();
    return;
  }
  if (BoolArg(*args, "on")) {
    if (!mini_mode_) {
      normal_placement_.length = sizeof(WINDOWPLACEMENT);
      GetWindowPlacement(hwnd, &normal_placement_);
      mini_mode_ = true;
    }
    if (IsZoomed(hwnd) || IsIconic(hwnd)) {
      ShowWindow(hwnd, SW_RESTORE);
    }
    const UINT dpi = FlutterDesktopGetDpiForHWnd(hwnd);
    const double scale = dpi / 96.0;
    RECT want{0, 0, static_cast<LONG>(IntArg(*args, "width", 420) * scale),
              static_cast<LONG>(IntArg(*args, "height", 276) * scale)};
    AdjustWindowRectExForDpi(&want, GetWindowLong(hwnd, GWL_STYLE), FALSE,
                             GetWindowLong(hwnd, GWL_EXSTYLE), dpi);
    const int width = want.right - want.left;
    const int height = want.bottom - want.top;
    MONITORINFO monitor{sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                   &monitor);
    const int margin = static_cast<int>(16 * scale);
    SetWindowPos(hwnd, HWND_TOPMOST, monitor.rcWork.right - width - margin,
                 monitor.rcWork.bottom - height - margin, width, height,
                 SWP_SHOWWINDOW);
  } else if (mini_mode_) {
    mini_mode_ = false;
    SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    SetWindowPlacement(hwnd, &normal_placement_);
  }
  result->Success(flutter::EncodableValue(true));
}

void FlutterWindow::SendMediaKey(const char* method) {
  if (media_keys_channel_) {
    media_keys_channel_->InvokeMethod(method, nullptr);
  }
}

void FlutterWindow::OnDestroy() {
  media_session_.Detach();
  media_session_attached_ = false;
  media_keys_channel_ = nullptr;
  window_channel_ = nullptr;
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
    case MediaSession::kButtonMessage:
      switch (wparam) {
        case MediaSession::kPlay:
          SendMediaKey("play");
          return 0;
        case MediaSession::kPause:
          SendMediaKey("pause");
          return 0;
        case MediaSession::kStop:
          SendMediaKey(kMediaMethods[3]);
          return 0;
        case MediaSession::kNext:
          SendMediaKey(kMediaMethods[1]);
          return 0;
        case MediaSession::kPrevious:
          SendMediaKey(kMediaMethods[2]);
          return 0;
      }
      break;
    case WM_APPCOMMAND: {
      // With the Windows media controls attached, Windows routes media keys
      // itself (no double handling); without them, react while focused.
      if (media_session_attached_) {
        break;
      }
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
