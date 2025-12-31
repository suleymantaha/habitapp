import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ImageStorage {
  static Future<String> saveImageFile({
    required String sourcePath,
    required String id,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final ext = _fileExtension(sourcePath);
    final target = File('${dir.path}/$id$ext');
    await File(sourcePath).copy(target.path);
    return target.path;
  }
}

String _fileExtension(String path) {
  final lastDot = path.lastIndexOf('.');
  if (lastDot == -1) return '.jpg';
  final ext = path.substring(lastDot);
  if (ext.length > 6) return '.jpg';
  return ext;
}

