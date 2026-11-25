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

/// App version shown in Settings and compared by NEXA Update Center (keep
/// the default equal to `version:` in pubspec.yaml). `NEXA_APP_VERSION`
/// gives the second build of the update-chain test another version.
const String kAppVersion = String.fromEnvironment(
  'NEXA_APP_VERSION',
  defaultValue: '1.1.1',
);
