import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const appVersion = '0.3.0';
const projectUrl = 'https://github.com/RockyrLiu/lite-diary';

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
          SizedBox(height: 24),
          Text(
            '一款简洁的私人日记应用，支持 Markdown 编辑、分组管理、标签系统、'
            '农历日历、那年今日回顾、全文搜索等功能。',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.code, color: Theme.of(context).colorScheme.primary),
            title: const Text('项目地址'),
            trailing: const Icon(Icons.launch, size: 18),
            onTap: () => launchUrl(Uri.parse(projectUrl)),
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              '© 2026 Yanrui Liu',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

