import 'package:lunar/lunar.dart';

/// 农历服务
final class LunarService {
  LunarService._();

  /// 干支纪年（如 "丙午"）
  static String ganZhiYear(int gregorianYear) {
    final lunar = Lunar.fromDate(DateTime(gregorianYear, 6, 1));
    return '${lunar.getYearGan()}${lunar.getYearZhi()}';
  }

  /// 公历日期 → 农历月日（如 "七月十三"）
  static String lunarDay(DateTime date) {
    final lunar = Lunar.fromDate(date);
    return '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  }

  /// 公历日期 → 农历简写（初一显示月份，其余只显示日子）
  /// 如初一 → "七月"，初二 → "初二"，初十 → "初十"
  static String lunarDayShort(DateTime date) {
    final lunar = Lunar.fromDate(date);
    final day = lunar.getDayInChinese();
    if (day == '初一') {
      return '${lunar.getMonthInChinese()}月';
    }
    // 只取"初X"、"十X"、"廿X"、"三十"等日子部分
    // dayInChinese 已返回如 "初二"、"十三"、"廿一"
    if (day == '二十') return '二十';
    if (day == '三十') return '三十';
    return day;
  }
}
