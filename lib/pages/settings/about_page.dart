import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const projectUrl = 'https://github.com/RockyrLiu/lite-diary';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  /// 构建时通过 --dart-define=GIT_DESCRIBE 注入的 git describe 输出。
  static const _gitDescribe = String.fromEnvironment('GIT_DESCRIBE');

  String? _version;
  bool _checking = false;

  /// 调试构建一定不是正式版，直接视为 preview；
  /// 发布构建依据注入的 git describe：恰好等于语义化版本标签时为正式版，否则为 preview。
  bool get _isPreview {
    if (kDebugMode) return true;
    if (_gitDescribe.isEmpty) return false;
    return !RegExp(r'^v?\d+\.\d+\.\d+$').hasMatch(_gitDescribe);
  }

  String? get _shortHash {
    final m = RegExp(r'-g([0-9a-f]+)$').firstMatch(_gitDescribe);
    if (m != null) return m.group(1);
    return _gitDescribe.isEmpty ? null : _gitDescribe;
  }

  /// preview 徽标中的标识：debug 构建显示 debug，注入过 git 标识时显示短哈希。
  String get _previewTag => _gitDescribe.isEmpty ? 'debug' : (_shortHash ?? '');

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    // 调试/性能构建会附加 -debug/-profile 后缀，仅用于显示与比较时剥离。
    final version = info.version.replaceFirst(
      RegExp(r'-(debug|profile|release)$'),
      '',
    );
    setState(() {
      _version = version;
    });
  }

  /// 比较 GitHub tag（如 v0.3.1）与当前版本号，返回远端是否更新。
  bool _isNewer(String tag, String current) {
    List<int> parse(String s) {
      final parts = s
          .replaceFirst(RegExp(r'^v'), '')
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      while (parts.length < 3) {
        parts.add(0);
      }
      return parts;
    }

    final a = parse(tag);
    final b = parse(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    final current = _version;
    setState(() => _checking = true);
    try {
      final resp = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/RockyrLiu/lite-diary/releases/latest',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final tag = data['tag_name']?.toString() ?? '';
      if (current == null || !_isNewer(tag, current)) {
        if (!mounted) return;
        setState(() => _checking = false);
        _snack('当前已是最新版本');
        return;
      }
      final url = data['html_url']?.toString() ?? projectUrl;
      final body = (data['body'] as String? ?? '').trim();
      if (!mounted) return;
      setState(() => _checking = false);
      final needDownload = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 $tag'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['published_at'] != null)
                  Text(
                    '发布于 ${data['published_at']!.toString().substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body.length > 500 ? '${body.substring(0, 500)}...' : body,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('前往下载'),
            ),
          ],
        ),
      );
      if (needDownload == true && mounted) {
        launchUrl(Uri.parse(url));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      _snack('检查更新失败，请检查网络后重试');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

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
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Lite Diary',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'v${_version ?? '...'}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_isPreview) ...[
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'preview($_previewTag)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            '一款简洁的私人日记应用，支持 Markdown 编辑、分组管理、标签系统、'
            '农历日历、那年今日回顾、全文搜索等功能。',
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(
              Icons.code,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('项目地址'),
            trailing: const Icon(Icons.launch, size: 18),
            onTap: () => launchUrl(Uri.parse(projectUrl)),
          ),
          ListTile(
            leading: Icon(
              _checking ? Icons.hourglass_top : Icons.update,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(_checking ? '检查中...' : '检查更新'),
            onTap: _checking ? null : _checkUpdate,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '© 2026 Yanrui Liu',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
