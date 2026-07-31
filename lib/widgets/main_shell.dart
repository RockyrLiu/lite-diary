import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/home/home_page.dart';
import '../pages/content/content_page.dart';
import '../pages/llm/llm_page.dart';
import '../pages/settings/settings_page.dart';
import '../providers/entry_provider.dart';
import '../services/navigation_state.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _tabHome = 0;

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (activeTab != _tabHome) {
          ref.read(activeTabProvider.notifier).state = 0;
        } else if (isGroupsMultiSelectActive) {
          isGroupsMultiSelectActive = false;
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: activeTab,
          children: const [
            HomePage(),
            ContentPage(),
            LlmPage(),
            SettingsPage(),
          ],
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Theme.of(context).colorScheme.primary.withAlpha(20),
          ),
          child: BottomNavigationBar(
            currentIndex: activeTab,
            onTap: (index) => ref.read(activeTabProvider.notifier).state = index,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
              BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '内容'),
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'LLM'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        ),
      ),
    );
  }
}
