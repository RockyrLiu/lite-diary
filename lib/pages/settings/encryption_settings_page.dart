import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/encryption_provider.dart';
import '../../services/crypto_service.dart';

class EncryptionSettingsPage extends ConsumerStatefulWidget {
  const EncryptionSettingsPage({super.key});

  @override
  ConsumerState<EncryptionSettingsPage> createState() => _EncryptionSettingsPageState();
}

class _EncryptionSettingsPageState extends ConsumerState<EncryptionSettingsPage> {
  late final TextEditingController _pwdCtrl;
  String? _keyHex;
  bool _obscure = true;
  bool _loaded = false;
  bool _keyVisible = false;

  @override
  void initState() {
    super.initState();
    _pwdCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final cfg = await EncryptionConfig.load();
    if (!mounted) return;
    setState(() {
      _pwdCtrl.text = cfg.password;
      _keyHex = cfg.keyHex.isEmpty ? null : cfg.keyHex;
      _loaded = true;
    });
  }

  void _derive() {
    final pwd = _pwdCtrl.text.trim();
    if (pwd.isEmpty) {
      setState(() => _keyHex = null);
      return;
    }
    final salt = CryptoService.generateSalt();
    final key = CryptoService.deriveKey(pwd, salt);
    setState(() => _keyHex = CryptoService.keyToHex(key));
  }

  Future<void> _save() async {
    final pwd = _pwdCtrl.text.trim();
    if (_keyHex == null || pwd.isEmpty) {
      await EncryptionConfig.delete();
      if (mounted) _toast('加密配置已清除');
      setState(() => _keyHex = null);
      return;
    }
    // regenerate with same salt
    final salt = CryptoService.generateSalt();
    final key = CryptoService.deriveKey(pwd, salt);
    final hex = CryptoService.keyToHex(key);
    await EncryptionConfig.save(password: pwd, salt: salt, keyHex: hex);
    if (mounted) _toast('加密配置已保存');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return Scaffold(appBar: AppBar(title: const Text('加密配置')), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('加密配置')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('设置加密密码后，云端备份和本地导入导出将自动使用加密。',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _pwdCtrl,
              obscureText: _obscure,
              onChanged: (_) => _derive(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                labelText: '加密密码',
                hintText: '输入密码以派生加密密钥',
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
          if (_keyHex != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: const Text('派生密钥（请务必妥善保存）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green))),
                    IconButton(
                      icon: Icon(_keyVisible ? Icons.visibility_off : Icons.visibility, size: 20),
                      tooltip: _keyVisible ? '隐藏密钥' : '显示密钥',
                      onPressed: () => setState(() => _keyVisible = !_keyVisible),
                    ),
                  ]),
                  if (_keyVisible) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: SelectableText(_keyHex!, style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.green.shade800))),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '复制密钥',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _keyHex!));
                          _toast('密钥已复制');
                        },
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            'openssl enc -aes-256-gcm -d -K $_keyHex -iv <iv> -in backup.enc -out backup.zip',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.greenAccent),
                          ),
                        ),
                      ),
                      IconButton(
                        padding: const EdgeInsets.only(top: 24),
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '复制命令',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: 'openssl enc -aes-256-gcm -d -K $_keyHex -iv <iv> -in backup.enc -out backup.zip'));
                          _toast('命令已复制');
                        },
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(' <iv> 见 _header.json 中的 iv 字段', style: TextStyle(fontSize: 13, color: Colors.green.shade600)),
                  ],
                ]),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
              onPressed: _save,
            ),
          ),
          if (_keyHex != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('清除加密配置'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  await EncryptionConfig.delete();
                  _pwdCtrl.clear();
                  setState(() => _keyHex = null);
                  if (mounted) _toast('加密配置已清除');
                },
              ),
            ),
        ],
      ),
    );
  }
}
