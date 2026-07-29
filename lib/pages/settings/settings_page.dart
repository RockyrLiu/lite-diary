import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/section_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SectionHeader('通用', color: Colors.teal),
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
          const SectionHeader('导出', color: Colors.teal),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('导出'),
            subtitle: const Text('导出日记、诗稿等'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/export'),
          ),
          const SectionHeader('云端（待实现）', color: Colors.teal),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('云端配置'),
            subtitle: const Text('WebDAV 同步设置'),
            trailing: const Icon(Icons.chevron_right),
            enabled: false,
            onTap: () => context.push('/settings/cloud'),
          ),
          const SectionHeader('LLM（待实现）', color: Colors.teal),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('LLM 配置'),
            subtitle: const Text('API 地址与密钥'),
            trailing: const Icon(Icons.chevron_right),
            enabled: false,
            onTap: () => context.push('/settings/llm'),
          ),
          const SectionHeader('其他', color: Colors.teal),
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

