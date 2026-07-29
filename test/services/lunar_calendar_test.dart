import 'package:diary_lite/services/lunar_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LunarService', () {
    test('干支纪年', () {
      expect(LunarService.ganZhiYear(2026), '丙午');
      expect(LunarService.ganZhiYear(2025), '乙巳');
      expect(LunarService.ganZhiYear(2024), '甲辰');
    });

    test('农历月日 - 春节', () {
      // 2026年春节是 2月17日 → 正月初一
      expect(LunarService.lunarDay(DateTime(2026, 2, 17)), '正月初一');
    });

    test('农历月日 - 普通日', () {
      final result = LunarService.lunarDay(DateTime(2026, 8, 23));
      expect(result, isNotEmpty);
    });

    test('农历月日 - 跨年', () {
      // 2026-01-01 在 2026 年春节 (2/17) 之前，属上一年
      final result = LunarService.lunarDay(DateTime(2026, 1, 1));
      expect(result, isNotEmpty);
    });
  });
}
