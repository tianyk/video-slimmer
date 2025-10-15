class DurationUtils {
  DurationUtils._();

  static String formatToClock(double secondsValue) {
    final int totalSeconds = secondsValue.round();
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final String minutesString = minutes.toString().padLeft(2, '0');
    final String secondsString = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final String hoursString = hours.toString().padLeft(2, '0');
      return '$hoursString:$minutesString:$secondsString';
    }
    return '$minutesString:$secondsString';
  }
}
