// The Phase 1 DEMO content (invented collections and rows) is gone: since
// E5 every section shows real data (owner 2026-11-16: no DEMO left). Only
// the time formatter remains here, used across the app.

/// m:ss
String formatClock(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}
