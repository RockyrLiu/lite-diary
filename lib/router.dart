import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home/home_page.dart';
import 'pages/content/content_page.dart';
import 'pages/llm/llm_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/settings/export_page.dart';
import 'pages/settings/about_page.dart';
import 'pages/settings/display_page.dart';

final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

GoRouter buildRouter({
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
      GoRoute(path: '/content', builder: (context, state) {
        final dateStr = state.uri.queryParameters['date'];
        DateTime? date;
        if (dateStr != null) {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          }
        }
        return ContentPage(key: ValueKey('content-${dateStr ?? 'today'}'), initialDate: date);
      }),
      GoRoute(path: '/content/date/:dateStr', builder: (context, state) {
        final dateStr = state.pathParameters['dateStr']!;
        final parts = dateStr.split('-');
        DateTime? date;
        if (parts.length == 3) {
          date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
        return ContentPage(key: ValueKey('content-$dateStr'), initialDate: date);
      }),
      GoRoute(path: '/entry/:id', builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return ContentPage(entryId: id);
      }),
      GoRoute(path: '/entry/new', builder: (context, state) => const ContentPage(isNew: true)),
    ]));
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '内容'));
  }
  if (showLlm) {
    branches.add(StatefulShellBranch(routes: [
      GoRoute(path: '/llm', builder: (context, state) => const LlmPage()),
      GoRoute(path: '/llm/:id', builder: (context, state) {
        final id = state.pathParameters['id']!;
        return LlmPage(conversationId: id);
      }),
    ]));
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'LLM'));
  }
  if (showSettings) {
    branches.add(StatefulShellBranch(routes: [
      GoRoute(path: '/settings', builder: (context, state) => const SettingsPage(), routes: [
        GoRoute(path: 'display', builder: (context, state) => const DisplayPage()),
        GoRoute(path: 'encryption', builder: (context, state) => const SettingsPage()),
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
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => navigationShell.goBranch(index),
              type: BottomNavigationBarType.fixed,
              items: navItems,
            ),
          );
        },
        branches: branches,
      ),
    ],
  );
}

GoRouter router = buildRouter();

Future<void> reloadRouter() async {
  final prefs = await _prefs;
  router = buildRouter(
    showHome: prefs.getBool('tab_home') ?? true,
    showContent: prefs.getBool('tab_content') ?? true,
    showLlm: prefs.getBool('tab_llm') ?? true,
    showSettings: prefs.getBool('tab_settings') ?? true,
  );
}
