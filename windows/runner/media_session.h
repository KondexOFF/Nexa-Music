#ifndef RUNNER_MEDIA_SESSION_H_
#define RUNNER_MEDIA_SESSION_H_

#include <windows.h>

#include <windows.media.h>
#include <wrl/client.h>

#include <string>

// NEXA Music in the Windows media controls (System Media Transport
// Controls, SMTC): the media keys and the Windows media overlay reach NEXA
// through the system, also while the window is in the background, and only
// when Windows routes them to NEXA - other players keep their keys (TD-06).
//
// Button presses arrive on a system thread; they are posted to [window] as
// [kButtonMessage] (WPARAM = button) and handled on the UI thread.
class MediaSession {
 public:
  static constexpr UINT kButtonMessage = WM_APP + 0x31;

  // Button codes in kButtonMessage's WPARAM.
  enum Button : WPARAM { kPlay = 1, kPause, kStop, kNext, kPrevious };

  MediaSession() = default;
  ~MediaSession();

  MediaSession(const MediaSession&) = delete;
  MediaSession& operator=(const MediaSession&) = delete;

  // Connects to the SMTC of [window]. Returns false when Windows offers no
  // SMTC for this window (then only WM_APPCOMMAND works, while focused).
  bool Attach(HWND window);
  void Detach();

  // Playback state and the song shown in the Windows media overlay.
  // UTF-8 strings; an empty title means nothing is loaded.
  void Update(bool playing, const std::string& title,
              const std::string& artist);

 private:
  Microsoft::WRL::ComPtr<ABI::Windows::Media::ISystemMediaTransportControls>
      controls_;
  EventRegistrationToken button_token_{};
  bool attached_ = false;
};

#endif  // RUNNER_MEDIA_SESSION_H_
