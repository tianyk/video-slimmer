/// 星期几的中文表示
const List<String> _weekdays = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 将日期格式化为友好的中文字符串
///
/// 根据日期与当前时间的关系，返回不同的格式：
/// - 今天：返回 "今天"
/// - 昨天：返回 "昨天"
/// - 7天内：返回星期几（如 "周一"）
/// - 今年内：返回 "月日"（如 "10月23日"）
/// - 其他：返回 "年月"（如 "2024年10月"）
String formatDateToFriendlyString(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime yesterday = today.subtract(const Duration(days: 1));
  final DateTime videoDate = DateTime(date.year, date.month, date.day);
  if (videoDate == today) {
    return '今天';
  }
  if (videoDate == yesterday) {
    return '昨天';
  }
  if (now.difference(date).inDays < 7) {
    return _weekdays[date.weekday - 1];
  }
  if (date.year == now.year) {
    return '${date.month}月${date.day}日';
  }
  return '${date.year}年${date.month}月';
}

/// 将时长（秒）格式化为时钟格式字符串
///
/// 根据时长自动选择合适的格式：
/// - 小于1小时：返回 "mm:ss"（如 "05:30"）
/// - 大于等于1小时：返回 "hh:mm:ss"（如 "01:05:30"）
///
/// [secondsValue] 时长（单位：秒），支持小数，会自动四舍五入
String formatDurationToClock(double secondsValue) {
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
