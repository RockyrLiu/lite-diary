import 'package:flutter/material.dart';

const appVersion = '0.2.3';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Image.asset('assets/icon.png', width: 72, height: 72),
          ),
          SizedBox(height: 16),
          Center(
            child: Text('Lite Diary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 8),
          Center(
            child: Text('v$appVersion', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          SizedBox(height: 4),
          Center(
            child: Chip(
              label: Text('测试版', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.tertiary)),
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              side: BorderSide(color: Theme.of(context).colorScheme.tertiary, width: 0.5),
              visualDensity: VisualDensity.compact,
            ),
          ),
          SizedBox(height: 24),
          Text(
            '一款简洁的私人日记应用，支持 Markdown 编辑、分组管理、标签系统、'
            '农历日历、那年今日回顾、全文搜索等功能。',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          SizedBox(height: 24),
          Center(
            child: Text('© 2026 lite_diary', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

