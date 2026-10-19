class VideoEditingRules {
  const VideoEditingRules._();

  static bool isValidTrimRange({
    required int startMs,
    required int endMs,
    required int durationMs,
    int minimumSelectionMs = 100,
  }) {
    return durationMs > 0 &&
        startMs >= 0 &&
        endMs <= durationMs &&
        endMs - startMs >= minimumSelectionMs;
  }

  static int speedAdjustedDurationMs({
    required int durationMs,
    required double speed,
  }) {
    if (durationMs < 0 || speed <= 0) {
      throw ArgumentError('Duration and speed must be positive.');
    }
    return (durationMs / speed).round();
  }
}
