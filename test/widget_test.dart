import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diary_lite/main.dart';

void main() {
  testWidgets('应用启动', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DiaryLiteApp()));
    await tester.pump();
    expect(find.text('Diary Lite'), findsOneWidget);
  });
}
