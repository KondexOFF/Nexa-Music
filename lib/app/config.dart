// Build-time configuration passed with --dart-define, so that no personal
// file paths are stored in the repository.

/// Phase 0 audio test file (optional).
const String kTestAudioPath = String.fromEnvironment('NEXA_TEST_AUDIO');

/// Runs the Phase 0 audio self-test instead of the app.
const bool kRunSelfTest = bool.fromEnvironment('NEXA_SELFTEST');

/// Folder for the Phase 0 self-test log and PNG.
const String kProbeLogDir = String.fromEnvironment('NEXA_PROBE_LOG_DIR');

/// When set, the app renders fixed window sizes, saves screenshots into this
/// folder and exits (Phase 1 visual evidence).
const String kCaptureDir = String.fromEnvironment('NEXA_CAPTURE_DIR');

/// App version shown in Settings (keep equal to `version:` in pubspec.yaml).
const String kAppVersion = '1.0.0';
