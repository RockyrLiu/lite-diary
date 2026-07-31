import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/entry_provider.dart';
import 'router.dart';
import 'services/rendering_settings.dart';
import 'services/theme_service.dart';
import 'services/tab_notifier.dart';
import 'pages/settings/display_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedMode = await AppTheme.loadThemeMode();
  final colorIndex = await AppTheme.loadColorIndex();
  final renderSettings = await loadRenderingSettings();
  final pageOrder = await loadHomePageOrder();

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => savedMode),
      themeColorIndexProvider.overrideWith((ref) => colorIndex),
      renderingSettingsProvider.overrideWith((ref) => renderSettings),
      homePageOrderProvider.overrideWith((ref) => pageOrder),
    ],
    child: const LiteDiaryApp(),
  ));
}

class LiteDiaryApp extends ConsumerStatefulWidget {
  const LiteDiaryApp({super.key});

  @override
  ConsumerState<LiteDiaryApp> createState() => _LiteDiaryAppState();
}

class _LiteDiaryAppState extends ConsumerState<LiteDiaryApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => reloadRouter(ref));
    tabVisibilityNotifier.addListener(_onTabVisibilityChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabVisibilityNotifier.removeListener(_onTabVisibilityChanged);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final router = ref.read(routerProvider);
    try {
      if (isGroupsMultiSelectActive) {
        isGroupsMultiSelectActive = false;
        return true;
      }
      final loc = router.routerDelegate.currentConfiguration.last.matchedLocation;
      if (loc.startsWith('/content') || loc.startsWith('/entry')) {
        router.go('/');
        return true;
      }
      if (loc.startsWith('/llm')) {
        router.go('/');
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _onTabVisibilityChanged() {
    reloadRouter(ref);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final colorIndex = ref.watch(themeColorIndexProvider);
    final seed = AppTheme.seedColorFromIndex(colorIndex);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Lite Diary',
      theme: AppTheme.lightTheme(seed),
      darkTheme: AppTheme.darkTheme(seed),
      themeMode: themeMode,
      routerConfig: router,
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
