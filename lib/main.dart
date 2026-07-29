import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'services/rendering_settings.dart';
import 'services/theme_service.dart';
import 'pages/settings/display_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedMode = await AppTheme.loadThemeMode();
  final colorIndex = await AppTheme.loadColorIndex();
  final renderSettings = await loadRenderingSettings();
  final pageOrder = await loadHomePageOrder();
  await reloadRouter();

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => savedMode),
      themeColorIndexProvider.overrideWith((ref) => colorIndex),
      renderingSettingsProvider.overrideWith((ref) => renderSettings),
      homePageOrderProvider.overrideWith((ref) => pageOrder),
    ],
    child: const DiaryLiteApp(),
  ));
}

class DiaryLiteApp extends ConsumerWidget {
  const DiaryLiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorIndex = ref.watch(themeColorIndexProvider);

    return MaterialApp.router(
      title: 'Diary Lite',
      theme: AppTheme.lightTheme(colorIndex),
      darkTheme: AppTheme.darkTheme(colorIndex),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
