import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedMode = await AppTheme.loadThemeMode();

  runApp(ProviderScope(
    overrides: [themeModeProvider.overrideWith((ref) => savedMode)],
    child: const DiaryLiteApp(),
  ));
}

class DiaryLiteApp extends ConsumerWidget {
  const DiaryLiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '日记',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
