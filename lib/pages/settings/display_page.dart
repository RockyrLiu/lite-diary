import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/theme_service.dart';

class DisplayPage extends ConsumerWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
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
          const _SectionHeader('关于主题'),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '当前默认为白色主题。开启深色模式后，应用将使用深色配色方案。',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
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
