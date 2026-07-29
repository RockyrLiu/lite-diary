import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/theme_service.dart';

final tabVisibilityProvider = StateProvider<Map<String, bool>>((ref) {
  return {'首页': true, '内容': true, 'LLM': true, '设置': true};
});

class DisplayPage extends ConsumerStatefulWidget {
  const DisplayPage({super.key});

  @override
  ConsumerState<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends ConsumerState<DisplayPage> {
  Map<String, bool> _tabs = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tabs = {
        '首页': prefs.getBool('tab_home') ?? true,
        '内容': prefs.getBool('tab_content') ?? true,
        'LLM': prefs.getBool('tab_llm') ?? true,
        '设置': prefs.getBool('tab_settings') ?? true,
      };
      _loaded = true;
    });
    ref.read(tabVisibilityProvider.notifier).state = Map.from(_tabs);
  }

  Future<void> _setTab(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = {'首页': 'tab_home', '内容': 'tab_content', 'LLM': 'tab_llm', '设置': 'tab_settings'}[key]!;
    await prefs.setBool(prefKey, value);
    setState(() => _tabs[key] = value);
    ref.read(tabVisibilityProvider.notifier).state = Map.from(_tabs);
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('显示控制')),
      body: ListView(
        children: [
          const _SectionHeader('主题'),
          SwitchListTile(
            title: const Text('深色模式'),
            value: currentMode == ThemeMode.dark,
            onChanged: (value) {
              final newMode = value ? ThemeMode.dark : ThemeMode.light;
              ref.read(themeModeProvider.notifier).state = newMode;
              AppTheme.saveThemeMode(newMode);
            },
          ),
          const Divider(),
          const _SectionHeader('底部导航栏'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('控制底部导航栏中显示的标签页（重启后生效）',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          if (_loaded) ...[
            SwitchListTile(
              title: const Text('首页'),
              value: _tabs['首页'] ?? true,
              onChanged: (v) => _setTab('首页', v),
            ),
            SwitchListTile(
              title: const Text('内容'),
              value: _tabs['内容'] ?? true,
              onChanged: (v) => _setTab('内容', v),
            ),
            SwitchListTile(
              title: const Text('LLM'),
              value: _tabs['LLM'] ?? true,
              onChanged: (v) => _setTab('LLM', v),
            ),
            SwitchListTile(
              title: const Text('设置'),
              value: _tabs['设置'] ?? true,
              onChanged: (v) => _setTab('设置', v),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
    );
  }
}
