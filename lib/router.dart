import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home/home_page.dart';
import 'pages/content/content_page.dart';
import 'pages/llm/llm_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/settings/export_page.dart';
import 'pages/settings/about_page.dart';
import 'pages/settings/display_page.dart';
import 'services/tab_notifier.dart';

GoRouter _buildRouter({
  bool showHome = true,
  bool showContent = true,
  bool showLlm = true,
  bool showSettings = true,
}) {
  final branches = <StatefulShellBranch>[];
  final navItems = <BottomNavigationBarItem>[];

  if (showHome) {
    branches.add(StatefulShellBranch(routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
    ]));
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'));
  }
  if (showContent) {
    branches.add(StatefulShellBranch(routes: [
      GoRoute(path: '/content', builder: (context, state) => const ContentPage(key: ValueKey('content-default'))),
      GoRoute(path: '/content/date/:dateStr', builder: (context, state) {
        final dateStr = state.pathParameters['dateStr']!;
        final parts = dateStr.split('-');
        DateTime? date;
        if (parts.length == 3) { date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])); }
        return ContentPage(key: ValueKey('content-$dateStr'), initialDate: date);
      }),
      GoRoute(path: '/entry/:id', builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ContentPage(key: ValueKey('entry-$id'), entryId: int.tryParse(id));
      }),
      GoRoute(path: '/entry/new', builder: (context, state) => const ContentPage(key: ValueKey('entry-new'), isNew: true)),
    ]));
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '内容'));
  }
  if (showLlm) {
    branches.add(StatefulShellBranch(routes: [
      GoRoute(path: '/llm', builder: (context, state) => const LlmPage()),
      GoRoute(path: '/llm/:id', builder: (context, state) { final id = state.pathParameters['id']!; return LlmPage(conversationId: id); }),
    ]));
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'LLM'));
  }
  if (showSettings) {
    branches.add(StatefulShellBranch(routes: [
      GoRoute(path: '/settings', builder: (context, state) => const SettingsPage(), routes: [
        GoRoute(path: 'display', builder: (context, state) => const DisplayPage()),
        GoRoute(path: 'cloud', builder: (context, state) => const SettingsPage()),
        GoRoute(path: 'llm', builder: (context, state) => const SettingsPage()),
        GoRoute(path: 'about', builder: (context, state) => const AboutPage()),
        GoRoute(path: 'export', builder: (context, state) => const ExportPage()),
      ]),
    ]));
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'));
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: tabVisibilityNotifier,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Scaffold(
          body: navigationShell,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(index),
            type: BottomNavigationBarType.fixed,
            items: navItems,
          ),
        ),
        branches: branches,
      ),
    ],
  );
}

final routerProvider = StateProvider<GoRouter>((ref) {
  // 初始用默认值构建，main() 中 reload 会更新为持久化值
  return _buildRouter();
});

Future<void> reloadRouter(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  ref.read(routerProvider.notifier).state = _buildRouter(
    showHome: prefs.getBool('tab_home') ?? true,
    showContent: prefs.getBool('tab_content') ?? true,
    showLlm: prefs.getBool('tab_llm') ?? true,
    showSettings: prefs.getBool('tab_settings') ?? true,
  );
}
