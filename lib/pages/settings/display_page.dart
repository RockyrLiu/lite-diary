import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/theme_service.dart';
import '../../services/rendering_settings.dart';

import '../../widgets/section_header.dart';
import '../../widgets/color_scheme_box.dart';


final homePageOrderProvider = StateProvider<List<int>>((ref) => const [1, 2, 0]);

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
      _tabs = {
        '首页': prefs.getBool('tab_home') ?? true,
        '内容': prefs.getBool('tab_content') ?? true,
        'LLM': prefs.getBool('tab_llm') ?? true,
        '设置': prefs.getBool('tab_settings') ?? true,
      };
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

  Future<void> _setTab(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = {'首页': 'tab_home', '内容': 'tab_content', 'LLM': 'tab_llm', '设置': 'tab_settings'}[key]!;
    await prefs.setBool(prefKey, value);
    if (!mounted) return;
    setState(() => _tabs[key] = value);
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(themeModeProvider);
    final colorIndex = ref.watch(themeColorIndexProvider);
    final renderSettings = ref.watch(renderingSettingsProvider);
    final presets = ThemeColors.presetColors;

    return Scaffold(
      appBar: AppBar(title: const Text('显示控制')),
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
                  badge: i == 0 ? const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.auto_awesome, size: 14, color: Colors.white70),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('第一页面为打开应用时的默认首页，上下箭头调整顺序', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('即时生效', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          if (_loaded) ...[
            SwitchListTile(title: const Text('首页'), value: _tabs['首页'] ?? true, onChanged: (v) => _setTab('首页', v)),
            SwitchListTile(title: const Text('内容'), value: _tabs['内容'] ?? true, onChanged: (v) => _setTab('内容', v)),
            SwitchListTile(title: const Text('LLM'), value: _tabs['LLM'] ?? true, onChanged: (v) => _setTab('LLM', v)),
            SwitchListTile(title: const Text('设置'), value: _tabs['设置'] ?? true, onChanged: (v) => _setTab('设置', v)),
          ],
        ],
      ),
    );
  }
}
