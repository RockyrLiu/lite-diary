import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('通用'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('外观'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/display'),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('加密'),
            subtitle: const Text('设置密码保护数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/encryption'),
          ),
          const _SectionHeader('数据'),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('导出数据'),
            subtitle: const Text('导出日记为 ZIP 文件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/export'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories),
            title: const Text('导出诗稿'),
            subtitle: const Text('将诗词分组导出为诗稿'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/export'),
          ),
          const _SectionHeader('云端（待实现）'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('云端配置'),
            subtitle: const Text('WebDAV 同步设置'),
            trailing: const Icon(Icons.chevron_right),
            enabled: false,
            onTap: () => context.push('/settings/cloud'),
          ),
          const _SectionHeader('LLM（待实现）'),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('LLM 配置'),
            subtitle: const Text('API 地址与密钥'),
            trailing: const Icon(Icons.chevron_right),
            enabled: false,
            onTap: () => context.push('/settings/llm'),
          ),
          const _SectionHeader('其他'),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('那年今日过滤'),
            subtitle: const Text('设置回顾范围'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
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
