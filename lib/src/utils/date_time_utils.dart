class DateTimeUtils {
  DateTimeUtils._();

  static const List<String> weekdays = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  static String formatToFriendlyString(DateTime date) {
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
      return weekdays[date.weekday - 1];
    }
    if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    }
    return '${date.year}年${date.month}月';
  }
}
