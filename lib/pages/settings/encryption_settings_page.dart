import 'dart:convert';

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
  late final TextEditingController _headerCtrl;
  String? _keyHex;
  String? _salt;
  bool _obscure = true;
  bool _loaded = false;
  bool _keyVisible = false;
  bool _showRecovery = false;
  String? _headerSalt;
  String? _headerIv;
  String? _restoredKeyHex;
  String? _headerError;

  @override
  void initState() {
    super.initState();
    _pwdCtrl = TextEditingController();
    _headerCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final cfg = await EncryptionConfig.load();
    if (!mounted) return;
    setState(() {
      _pwdCtrl.text = cfg.password;
      _keyHex = cfg.keyHex.isEmpty ? null : cfg.keyHex;
      _salt = cfg.salt.isEmpty ? null : cfg.salt;
      _loaded = true;
    });
  }

  void _derive() {
    final pwd = _pwdCtrl.text.trim();
    if (pwd.isEmpty) {
      setState(() {
        _keyHex = null;
        _restoredKeyHex = null;
      });
      return;
    }
    _salt ??= CryptoService.generateSalt();
    final key = CryptoService.deriveKey(pwd, _salt!);
    setState(() => _keyHex = CryptoService.keyToHex(key));
    if (_headerSalt != null) _deriveFromHeader();
  }

  Future<void> _save() async {
    final pwd = _pwdCtrl.text.trim();
    if (_keyHex == null || pwd.isEmpty) {
      await EncryptionConfig.delete();
      if (mounted) _toast('加密配置已清除');
      setState(() => _keyHex = null);
      return;
    }
    _salt ??= CryptoService.generateSalt();
    final key = CryptoService.deriveKey(pwd, _salt!);
    final hex = CryptoService.keyToHex(key);
    await EncryptionConfig.save(password: pwd, salt: _salt!, keyHex: hex);
    if (mounted) _toast('加密配置已保存');
  }

  void _parseHeader(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _headerSalt = null;
        _headerIv = null;
        _restoredKeyHex = null;
        _headerError = null;
      });
      return;
    }
    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      final salt = json['salt'] as String?;
      if (salt == null) {
        setState(() => _headerError = 'JSON 中未找到 salt 字段');
        return;
      }
      _headerSalt = salt;
      _headerIv = json['iv'] as String?;
    } catch (_) {
      _headerSalt = trimmed;
      _headerIv = null;
    }
    _headerError = null;
    _deriveFromHeader();
  }

  void _deriveFromHeader() {
    final pwd = _pwdCtrl.text.trim();
    if (_headerSalt == null) return;
    if (pwd.isEmpty) {
      setState(() => _restoredKeyHex = null);
      return;
    }
    try {
      final key = CryptoService.deriveKey(pwd, _headerSalt!);
      setState(() => _restoredKeyHex = CryptoService.keyToHex(key));
    } catch (e) {
      setState(() {
        _headerError = '派生失败: $e';
        _restoredKeyHex = null;
      });
    }
  }

  void _applyRestoredKey() {
    if (_restoredKeyHex == null || _headerSalt == null) return;
    setState(() {
      _keyHex = _restoredKeyHex;
      _salt = _headerSalt;
    });
    _toast('已应用恢复的密钥，请点击"保存配置"以持久化');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _headerCtrl.dispose();
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
                            'uv run --with cryptography python3 -c \'from cryptography.hazmat.primitives.ciphers.aead import AESGCM\n'
                            'd=open("backup.zip.enc","rb").read()\n'
                            'open("backup.zip","wb").write(AESGCM(bytes.fromhex("$_keyHex")).decrypt(bytes.fromhex("${_headerIv ?? '<iv>'}"),d[16:],None))\'',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.greenAccent),
                          ),
                        ),
                      ),
                      IconButton(
                        padding: const EdgeInsets.only(top: 24),
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '复制命令',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: "uv run --with cryptography python3 -c 'from cryptography.hazmat.primitives.ciphers.aead import AESGCM\n"
                              "d=open(\"backup.zip.enc\",\"rb\").read()\n"
                              "open(\"backup.zip\",\"wb\").write(AESGCM(bytes.fromhex(\"$_keyHex\")).decrypt(bytes.fromhex(\"${_headerIv ?? '<iv>'}\"),d[16:],None))'"));
                          _toast('命令已复制');
                        },
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(_headerIv != null ? ' IV 已从 _header.json 自动填充' : ' <iv> 见 _header.json 中的 iv 字段',
                        style: TextStyle(fontSize: 13, color: Colors.green.shade600)),
                  ],
                ]),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: Icon(_showRecovery ? Icons.expand_less : Icons.expand_more),
              label: const Text('从备份头恢复密钥'),
              onPressed: () => setState(() => _showRecovery = !_showRecovery),
            ),
          ),
          if (_showRecovery) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _headerCtrl,
                minLines: 3,
                maxLines: 5,
                onChanged: _parseHeader,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.document_scanner),
                  border: const OutlineInputBorder(),
                  labelText: '_header.json 内容',
                  hintText: '粘贴 _header.json 的内容',
                  isDense: true,
                ),
              ),
            ),
            if (_headerError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_headerError!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
              ),
            if (_restoredKeyHex != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('恢复的密钥', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue)),
                    const SizedBox(height: 8),
                    SelectableText(_restoredKeyHex!, style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.blue.shade800)),
                    if (_headerIv != null) ...[
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'uv run --with cryptography python3 -c \'from cryptography.hazmat.primitives.ciphers.aead import AESGCM\n'
                              'd=open("backup.zip.enc","rb").read()\n'
                              'open("backup.zip","wb").write(AESGCM(bytes.fromhex("$_restoredKeyHex")).decrypt(bytes.fromhex("$_headerIv"),d[16:],None))\'',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.lightBlueAccent),
                            ),
                          ),
                        ),
                        IconButton(
                          padding: const EdgeInsets.only(top: 24),
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: '复制命令',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: "uv run --with cryptography python3 -c 'from cryptography.hazmat.primitives.ciphers.aead import AESGCM\n"
                                "d=open(\"backup.zip.enc\",\"rb\").read()\n"
                                "open(\"backup.zip\",\"wb\").write(AESGCM(bytes.fromhex(\"$_restoredKeyHex\")).decrypt(bytes.fromhex(\"$_headerIv\"),d[16:],None))'"));
                            _toast('命令已复制');
                          },
                        ),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('使用此密钥'),
                        onPressed: _applyRestoredKey,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
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
