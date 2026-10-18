#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Windows media keys (play/pause, next, previous, stop) -> Dart
  // ("nexa/media_keys"). Registered as global hot keys so they also work
  // while NEXA Music is in the background; WM_APPCOMMAND is the fallback
  // when another app already owns a key.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      media_keys_channel_;
  bool media_hotkeys_registered_[4] = {false, false, false, false};
  void RegisterMediaKeys();
  void UnregisterMediaKeys();
  void SendMediaKey(const char* method);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
