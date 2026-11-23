/// m:ss
String formatClock(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}
