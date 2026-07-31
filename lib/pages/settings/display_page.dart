import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/theme_service.dart';
import '../../services/rendering_settings.dart';

import '../../widgets/section_header.dart';
import '../../widgets/color_scheme_box.dart';

final homePageOrderProvider = StateProvider<List<int>>((ref) => const [1, 2, 0]);

final tabVisibilityProvider = StateProvider<Map<String, bool>>((ref) => {
  'tab_home': true,
  'tab_content': true,
  'tab_llm': true,
  'tab_settings': true,
});

Future<Map<String, bool>> loadTabVisibility() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'tab_home': prefs.getBool('tab_home') ?? true,
    'tab_content': prefs.getBool('tab_content') ?? true,
    'tab_llm': prefs.getBool('tab_llm') ?? true,
    'tab_settings': prefs.getBool('tab_settings') ?? true,
  };
}

Future<void> saveTabVisibility(Map<String, bool> tabs) async {
  final prefs = await SharedPreferences.getInstance();
  for (final entry in tabs.entries) {
    await prefs.setBool(entry.key, entry.value);
  }
}

Future<void> saveHomePageOrder(List<int> order) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('home_page_order', order.map((e) => e.toString()).toList());
}

class DisplayPage extends ConsumerStatefulWidget {
  const DisplayPage({super.key});

  @override
  ConsumerState<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends ConsumerState<DisplayPage> {
  static const _tabItems = <({String prefKey, String label})>[
    (prefKey: 'tab_home', label: '首页'),
    (prefKey: 'tab_content', label: '内容'),
    (prefKey: 'tab_llm', label: 'LLM'),
    (prefKey: 'tab_settings', label: '设置'),
  ];

  Map<String, bool> _tabs = {};
  List<int> _pageOrder = [1, 2, 0];
  bool _loaded = false;

  static const _pageNames = ['那年今日', '日历', '分组'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _tabs = {};
      for (final item in _tabItems) {
        _tabs[item.prefKey] = prefs.getBool(item.prefKey) ?? true;
      }
      final order = prefs.getStringList('home_page_order');
      _pageOrder = order != null && order.length == 3 ? order.map(int.parse).toList() : [1, 2, 0];
      _loaded = true;
    });
  }

  void _movePage(int from, bool down) {
    final to = down ? from + 1 : from - 1;
    if (to < 0 || to >= _pageOrder.length) return;
    setState(() {
      final tmp = _pageOrder[from]; _pageOrder[from] = _pageOrder[to]; _pageOrder[to] = tmp;
    });
    ref.read(homePageOrderProvider.notifier).state = List.from(_pageOrder);
    saveHomePageOrder(_pageOrder);
  }

  Future<void> _setTab(String prefKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
    ref.read(tabVisibilityProvider.notifier).state = {
      ...ref.read(tabVisibilityProvider),
      prefKey: value,
    };
    saveTabVisibility(ref.read(tabVisibilityProvider));
    if (!mounted) return;
    setState(() => _tabs[prefKey] = value);
  }

  int get _activeTabCount => _tabs.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(themeModeProvider);
    final colorIndex = ref.watch(themeColorIndexProvider);
    final renderSettings = ref.watch(renderingSettingsProvider);
    final presets = ThemeColors.presetColors;

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        children: [
              const SectionHeader('主题色彩'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              children: List.generate(presets.length, (i) {
                final color = i == 0 ? null : presets[i]; // 0=自动(系统)
                return ColorSchemeBox(
                  seedColor: color,
                  isSelected: i == colorIndex,
                  onTap: () {
                    ref.read(themeColorIndexProvider.notifier).state = i;
                    AppTheme.saveColorIndex(i);
                  },
                  badge: i == 0 ? Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ) : null,
                );
              }),
            ),
          ),
          const Divider(),
          const SectionHeader('主题'),
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
          const SectionHeader('首页显示'),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('第一页面为打开应用时的默认首页，上下箭头调整顺序', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          if (_loaded)
            Column(children: List.generate(_pageOrder.length, (i) {
              final idx = _pageOrder[i];
              return ListTile(
                leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                title: Text(_pageNames[idx]),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (i > 0) IconButton(icon: const Icon(Icons.arrow_upward, size: 20), onPressed: () => _movePage(i, false)),
                  if (i < _pageOrder.length - 1) IconButton(icon: const Icon(Icons.arrow_downward, size: 20), onPressed: () => _movePage(i, true)),
                ]),
              );
            })),
          const Divider(),
          const SectionHeader('渲染'),
          ListTile(
            title: const Text('标题字号'),
            subtitle: Text('${renderSettings.titleSize.toInt()} px'),
            trailing: SizedBox(width: 160, child: Slider(value: renderSettings.titleSize, min: 16, max: 36, divisions: 20, onChanged: (v) {
              final s = renderSettings.copyWith(titleSize: v);
              ref.read(renderingSettingsProvider.notifier).state = s;
              saveRenderingSettings(s);
            })),
          ),
          ListTile(
            title: const Text('正文字号'),
            subtitle: Text('${renderSettings.bodySize.toInt()} px'),
            trailing: SizedBox(width: 160, child: Slider(value: renderSettings.bodySize, min: 12, max: 28, divisions: 16, onChanged: (v) {
              final s = renderSettings.copyWith(bodySize: v);
              ref.read(renderingSettingsProvider.notifier).state = s;
              saveRenderingSettings(s);
            })),
          ),
          const Divider(),
          const SectionHeader('底部导航栏'),
          if (_loaded) ...[
            for (final item in _tabItems)
              SwitchListTile(
                title: Text(item.label),
                value: _tabs[item.prefKey] ?? true,
                onChanged: (v) {
                  if (!v && _activeTabCount <= 1) return;
                  _setTab(item.prefKey, v);
                },
              ),
          ],
        ],
      ),
    );
  }
}
