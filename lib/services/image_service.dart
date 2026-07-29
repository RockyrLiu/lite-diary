import 'dart:io';
import 'package:drift/drift.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/database_provider.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// 选择图片并拷贝到应用私有目录，返回相对路径
  Future<String> pickAndSaveImage(WidgetRef ref, int entryId) async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return '';

    final appDir = await getApplicationDocumentsDirectory();
    final entryDir = Directory(p.join(appDir.path, 'images', entryId.toString()));
    if (!await entryDir.exists()) {
      await entryDir.create(recursive: true);
    }

    final originalName = p.basename(xFile.path);
    final ext = p.extension(xFile.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newName = '$timestamp$ext';
    final destPath = p.join(entryDir.path, newName);

    await File(xFile.path).copy(destPath);

    final relativePath = p.join('images', entryId.toString(), newName);

    final db = ref.read(databaseProvider);
    await db.into(db.images).insert(ImagesCompanion(
      entryId: Value(entryId),
      filePath: Value(relativePath),
      originalName: Value(originalName),
    ));

    return destPath;
  }
}
