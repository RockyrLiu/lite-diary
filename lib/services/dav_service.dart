import 'dart:convert';
import 'dart:io' as io;

import 'package:webdav_client/webdav_client.dart';

class DAVService {
  late Client _client;
  final String _root;

  DAVService({
    required String uri,
    required String user,
    required String password,
  }) : _root = _extractRoot(uri) {
    _client = newClient(uri, user: user, password: password);
    _client.setHeaders({
      'accept-charset': 'utf-8',
      'Content-Type': 'text/xml',
    });
    _client.setConnectTimeout(8000);
    _client.setSendTimeout(60000);
    _client.setReceiveTimeout(60000);
  }

  static String _extractRoot(String uri) {
    final parsed = Uri.parse(uri);
    final path = parsed.path;
    return path.endsWith('/') ? path : '$path/';
  }

  Future<bool> ping() async {
    try {
      await _client.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _remotePath(String name) => '${_root}lite_diary/$name';

  Future<void> ensureDir() async {
    try {
      await _client.mkdir('${_root}lite_diary');
    } catch (_) {}
  }

  Future<void> uploadFile(String localPath, String remoteName) async {
    await ensureDir();
    await _client.writeFromFile(localPath, _remotePath(remoteName));
  }

  Future<void> uploadString(String content, String remoteName) async {
    await ensureDir();
    final tmp = io.File(
            '${io.Directory.systemTemp.path}/lite_diary_upload_$remoteName')
        ..createSync(recursive: true);
    await tmp.writeAsString(content);
    try {
      await _client.writeFromFile(tmp.path, _remotePath(remoteName));
    } finally {
      await tmp.delete();
    }
  }

  Future<bool> downloadFile(String remoteName, String localPath) async {
    try {
      await ensureDir();
      await _client.read2File(_remotePath(remoteName), localPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> readString(String remoteName) async {
    try {
      final bytes = await _client.read(_remotePath(remoteName));
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readJson(String remoteName) async {
    final str = await readString(remoteName);
    if (str == null || str.isEmpty) return null;
    try {
      return json.decode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

}
