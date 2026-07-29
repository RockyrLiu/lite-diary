import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/home/home_page.dart';
import 'pages/content/content_page.dart';
import 'pages/llm/llm_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/settings/export_page.dart';

final router = GoRouter(
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
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
              BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '内容'),
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'LLM'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/content',
              builder: (context, state) {
                final dateStr = state.uri.queryParameters['date'];
                DateTime? date;
                if (dateStr != null) {
                  final parts = dateStr.split('-');
                  if (parts.length == 3) {
                    date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                  }
                }
                return ContentPage(initialDate: date);
              },
            ),
            GoRoute(
              path: '/entry/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '');
                return ContentPage(entryId: id);
              },
            ),
            GoRoute(
              path: '/entry/new',
              builder: (context, state) => const ContentPage(isNew: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/llm', builder: (context, state) => const LlmPage()),
            GoRoute(
              path: '/llm/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return LlmPage(conversationId: id);
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
            GoRoute(path: '/settings/cloud', builder: (context, state) => const SettingsPage()),
            GoRoute(path: '/settings/encryption', builder: (context, state) => const SettingsPage()),
            GoRoute(path: '/settings/llm', builder: (context, state) => const SettingsPage()),
            GoRoute(path: '/settings/display', builder: (context, state) => const SettingsPage()),
            GoRoute(path: '/settings/about', builder: (context, state) => const SettingsPage()),
            GoRoute(path: '/export', builder: (context, state) => const ExportPage()),
          ],
        ),
      ],
    ),
  ],
);
