import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const appVersion = '0.2.1';

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
            child: SvgPicture.asset('assets/icon.svg', width: 72, height: 72),
          ),
          SizedBox(height: 16),
          Center(
            child: Text('Lite Diary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 8),
          Center(
            child: Text('v$appVersion', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          SizedBox(height: 4),
          Center(
            child: Chip(
              label: Text('测试版', style: TextStyle(fontSize: 11, color: Colors.orange)),
              backgroundColor: Color(0x1AFF9800),
              side: BorderSide(color: Colors.orange, width: 0.5),
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
          _InfoItem(label: '技术栈', value: 'Flutter + Riverpod + drift'),
          _InfoItem(label: '运行平台', value: 'Android / Linux / Windows / Web'),
          SizedBox(height: 24),
          Center(
            child: Text('© 2026 lite_diary', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
