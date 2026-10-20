#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "media_session.h"
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

  // Media keys and the Windows media overlay -> Dart ("nexa/media_keys").
  // Through the Windows media controls (SMTC), so keys reach NEXA only when
  // Windows routes them here and other players keep theirs (TD-06; no
  // global hot keys). WM_APPCOMMAND covers keys while NEXA is focused when
  // SMTC is unavailable. Dart sends "update" (playing, title, artist).
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      media_keys_channel_;
  MediaSession media_session_;
  bool media_session_attached_ = false;
  void SendMediaKey(const char* method);
  void HandleMediaCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
