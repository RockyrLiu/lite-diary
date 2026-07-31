import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/rendering_settings.dart';
import 'services/theme_service.dart';
import 'widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedMode = await AppTheme.loadThemeMode();
  final colorIndex = await AppTheme.loadColorIndex();
  final renderSettings = await loadRenderingSettings();

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => savedMode),
      themeColorIndexProvider.overrideWith((ref) => colorIndex),
      renderingSettingsProvider.overrideWith((ref) => renderSettings),
    ],
    child: const LiteDiaryApp(),
  ));
}

class LiteDiaryApp extends ConsumerWidget {
  const LiteDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorIndex = ref.watch(themeColorIndexProvider);
    final seed = AppTheme.seedColorFromIndex(colorIndex);

    return MaterialApp(
      title: 'Lite Diary',
      theme: AppTheme.lightTheme(seed),
      darkTheme: AppTheme.darkTheme(seed),
      themeMode: themeMode,
      home: const MainShell(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
