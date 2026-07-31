import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/home/home_page.dart';
import '../pages/content/content_page.dart';
import '../pages/llm/llm_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/display_page.dart';
import '../providers/entry_provider.dart';
import '../services/navigation_state.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _tabDefs = <({int logicalIndex, IconData icon, String label, String prefKey})>[
    (logicalIndex: 0, icon: Icons.home, label: '首页', prefKey: 'tab_home'),
    (logicalIndex: 1, icon: Icons.edit_note, label: '内容', prefKey: 'tab_content'),
    (logicalIndex: 2, icon: Icons.chat, label: 'LLM', prefKey: 'tab_llm'),
    (logicalIndex: 3, icon: Icons.settings, label: '设置', prefKey: 'tab_settings'),
  ];

  static const _pages = <Widget>[
    HomePage(),
    ContentPage(),
    LlmPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    final tabVisibility = ref.watch(tabVisibilityProvider);

    final visibleTabs = _tabDefs
        .where((t) => tabVisibility[t.prefKey] ?? true)
        .map((t) => t.logicalIndex)
        .toList();
    if (visibleTabs.isEmpty) visibleTabs.add(0);
    final firstVisibleTab = visibleTabs.first;

    final visibleIndex = visibleTabs.indexOf(activeTab);
    final displayIndex = visibleIndex >= 0 ? visibleIndex : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (activeTab != firstVisibleTab) {
          ref.read(activeTabProvider.notifier).state = firstVisibleTab;
        } else if (isGroupsMultiSelectActive) {
          isGroupsMultiSelectActive = false;
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: activeTab,
          children: _pages,
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          ),
          child: BottomNavigationBar(
            currentIndex: displayIndex,
            onTap: (visibleIndex) {
              if (visibleIndex < visibleTabs.length) {
                ref.read(activeTabProvider.notifier).state = visibleTabs[visibleIndex];
              }
            },
            type: BottomNavigationBarType.fixed,
            items: visibleTabs.map((logicalIndex) {
              final def = _tabDefs.firstWhere((t) => t.logicalIndex == logicalIndex);
              return BottomNavigationBarItem(icon: Icon(def.icon), label: def.label);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
