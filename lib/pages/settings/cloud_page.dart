import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/cloud_backup_service.dart';
import '../../providers/encryption_provider.dart';

class CloudPage extends ConsumerStatefulWidget {
  const CloudPage({super.key});

  @override
  ConsumerState<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends ConsumerState<CloudPage> {
  bool? _connected;
  bool _checking = false;
  bool _loading = false;
  String? _status;
  bool _encrypt = false;
  bool _hasEncryptionKey = false;

  static const _fileName = 'backup.zip / backup.zip.enc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cfg = await EncryptionConfig.load();
      if (mounted) {
        setState(() {
          _hasEncryptionKey = cfg.keyHex.isNotEmpty;
          _encrypt = _hasEncryptionKey;
        });
      }
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    if (!mounted) return;
    setState(() {
      _checking = true;
      _connected = null;
    });
    final svc = CloudBackupService(ref);
    final ok = await svc.testConnection();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _connected = ok;
    });
  }

  Future<void> _showDavDialog() async {
    final cfg = await CloudBackupService(ref).getDavConfig();
    if (!mounted) return;

    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => _WebDAVDialog(
        initialUri: cfg.uri,
        initialUser: cfg.user,
        configured: cfg.configured,
      ),
    );

    if (saved == 'save' && mounted) {
      _checkConnection();
    } else if (saved == 'delete' && mounted) {
      final confirm = await _showDeleteConfirmDialog();
      if (confirm == true) {
        await CloudBackupService(ref).deleteDavConfig();
        if (mounted) _checkConnection();
      }
    }
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除配置'),
        content: const Text('确定要清除 WebDAV 配置吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('删除')),
        ],
      ),
    );
  }

  Future<void> _backup() async {
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final svc = CloudBackupService(ref);
      final result = await svc.backup(
        encrypt: _encrypt,
        onProgress: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _status = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '备份失败：$e';
        });
      }
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复数据'),
        content: const Text('将从云端下载备份并导入，已存在的条目将跳过。确定恢复？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final svc = CloudBackupService(ref);
      final result = await svc.restore(
        onProgress: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _status =
              '${result.message}（导入 ${result.imported} 篇，跳过 ${result.skipped} 篇重复）';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '恢复失败：$e';
        });
      }
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _connectionDot() {
    if (_checking) {
      return const SizedBox(
          width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1));
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _connected == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('云端备份')),
      body: ListView(
        children: [
          _sectionHeader('远程 WebDAV'),
          FutureBuilder(
            future: CloudBackupService(ref).getDavConfig(),
            builder: (context, snapshot) {
              final configured = snapshot.data?.configured ?? false;
              final user = snapshot.data?.user ?? '';

              if (!configured) {
                return ListTile(
                  leading: const Icon(Icons.account_box),
                  title: const Text('未配置'),
                  subtitle: const Text('请绑定 WebDAV 服务器'),
                  trailing: FilledButton.tonal(
                    onPressed: _showDavDialog,
                    child: const Text('绑定'),
                  ),
                );
              }
              return Column(children: [
                ListTile(
                  leading: const Icon(Icons.account_box),
                  title: Text(user,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Row(children: [
                    const Text('连接状态 '),
                    _connectionDot(),
                  ]),
                  trailing: FilledButton.tonal(
                    onPressed: _showDavDialog,
                    child: const Text('编辑'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: const Text('文件'),
                  subtitle: const Text(_fileName),
                ),
                ListTile(
                  onTap: _loading ? null : _backup,
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('备份'),
                  subtitle: const Text('上传本地数据到 WebDAV'),
                ),
                ListTile(
                  onTap: _loading ? null : _restore,
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('恢复'),
                  subtitle: const Text('下载远程备份并导入'),
                ),
              ]);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock),
            title: Text(_encrypt ? '加密' : '不加密'),
            subtitle: Text(_hasEncryptionKey ? '使用加密配置中的密钥加密备份' : '请在"加密配置"中设置密码后启用'),
            value: _encrypt,
            onChanged: _hasEncryptionKey ? (v) => setState(() => _encrypt = v) : null,
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _status!.contains('失败')
                      ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
                      : _status!.contains('最新')
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _status!.contains('失败')
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WebDAVDialog extends StatefulWidget {
  final String initialUri;
  final String initialUser;
  final bool configured;

  const _WebDAVDialog({
    required this.initialUri,
    required this.initialUser,
    required this.configured,
  });

  @override
  State<_WebDAVDialog> createState() => _WebDAVDialogState();
}

class _WebDAVDialogState extends State<_WebDAVDialog> {
  late final uriCtrl = TextEditingController(text: widget.initialUri);
  late final userCtrl = TextEditingController(text: widget.initialUser);
  late final passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    uriCtrl.dispose();
    userCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dav_uri', uriCtrl.text.trim());
    await prefs.setString('dav_user', userCtrl.text.trim());
    final pw = passwordCtrl.text.trim();
    if (pw.isNotEmpty) {
      await prefs.setString('dav_password', pw);
    }
    if (mounted) Navigator.pop(context, 'save');
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  void _delete() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, 'delete');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebDAV 配置'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: uriCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
                labelText: '服务器地址',
                helperText: 'https://example.com/remote.php/dav/files/user/',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入服务器地址' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: userCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.account_circle),
                border: OutlineInputBorder(),
                labelText: '用户名',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入用户名' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.password),
                border: const OutlineInputBorder(),
                labelText: '密码',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.configured)
          TextButton(onPressed: _delete, style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text('删除')),
        TextButton(onPressed: _cancel, child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
