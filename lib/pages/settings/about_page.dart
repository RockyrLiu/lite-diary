import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Center(
            child: Icon(Icons.edit_note, size: 72, color: Colors.teal),
          ),
          SizedBox(height: 16),
          Center(
            child: Text('日记 Lite', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 8),
          Center(
            child: Text('v0.1.0', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          SizedBox(height: 24),
          Text(
            '一款简洁的私人日记应用，支持 Markdown 编辑、分组管理、标签系统、'
            '农历日历、那年今日回顾、全文搜索等功能。',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          SizedBox(height: 24),
          _InfoItem(label: '技术栈', value: 'Flutter + Riverpod + drift + go_router'),
          _InfoItem(label: '运行平台', value: 'Android / Linux / Windows / Web'),
          SizedBox(height: 24),
          Center(
            child: Text('© 2026 diary_lite', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label：', style: const TextStyle(color: Colors.grey, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
