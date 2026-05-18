import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

String ensureRequiredFileExtension(String path, String requiredExtension) {
  final trimmedExtension = requiredExtension.trim();
  if (trimmedExtension.isEmpty) {
    throw ArgumentError.value(
      requiredExtension,
      'requiredExtension',
      'L extension requise ne peut pas etre vide.',
    );
  }

  final normalizedExtension = trimmedExtension.startsWith('.')
      ? trimmedExtension
      : '.$trimmedExtension';
  if (path.toLowerCase().endsWith(normalizedExtension.toLowerCase())) {
    return path;
  }
  return '$path$normalizedExtension';
}

Future<File> saveBytesAtLocation(
  FileSaveLocation location,
  Uint8List bytes, {
  required String requiredExtension,
}) async {
  final targetPath = ensureRequiredFileExtension(
    location.path,
    requiredExtension,
  );
  final file = File(targetPath);
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
