import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lite_diary/main.dart';

void main() {
  testWidgets('应用启动', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LiteDiaryApp()));
    await tester.pump();
    expect(find.text('Lite Diary'), findsOneWidget);
  });
}
