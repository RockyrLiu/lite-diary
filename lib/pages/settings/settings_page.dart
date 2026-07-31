import 'package:flutter/material.dart';

import '../../widgets/section_header.dart';
import 'display_page.dart';
import '../llm/llm_settings_page.dart';
import 'about_page.dart';
import 'export_page.dart';
import 'import_page.dart';
import 'cloud_page.dart';
import 'encryption_settings_page.dart';
import 'on_this_day_filter_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SectionHeader('通用'),
          _settingTile(context, Icons.palette, '外观', onTap: () => _push(context, const DisplayPage())),
          _settingTile(context, Icons.event, '那年今日过滤', subtitle: '设置回顾范围', onTap: () => _push(context, const OnThisDayFilterPage())),
          const SectionHeader('导入 / 导出'),
          _settingTile(context, Icons.lock, '加密配置', subtitle: '设置备份导出加密密码', onTap: () => _push(context, const EncryptionSettingsPage())),
          _settingTile(context, Icons.file_upload, '导入', subtitle: '从导出的文件恢复数据', onTap: () => _push(context, const ImportPage())),
          _settingTile(context, Icons.file_download, '导出', subtitle: '导出日记、诗稿等', onTap: () => _push(context, const ExportPage())),
          const SectionHeader('云端'),
          _settingTile(context, Icons.cloud, '云端备份', subtitle: 'WebDAV 备份与恢复', onTap: () => _push(context, const CloudPage())),
          const SectionHeader('LLM'),
          _settingTile(context, Icons.smart_toy, 'LLM 配置', subtitle: 'API 地址、密钥与分析提示词', onTap: () => _push(context, const LlmSettingsPage())),
          const SectionHeader('其他'),
          _settingTile(context, Icons.info, '关于', onTap: () => _push(context, const AboutPage())),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _settingTile(BuildContext context, IconData icon, String title, {String? subtitle, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
