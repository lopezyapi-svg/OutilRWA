import 'dart:io';
import 'package:excel/excel.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'dart:math' as math;
import 'dart:typed_data';

Uint8List? _repairMarketWorkbookStylesIfNeeded(Uint8List bytes) {
  try {
    final sourceArchive = ZipDecoder().decodeBytes(bytes);
    final stylesFile = sourceArchive.findFile('xl/styles.xml');
    if (stylesFile == null || !stylesFile.isFile) return null;
    final stylesXml = utf8.decode(
      stylesFile.content as List<int>,
      allowMalformed: true,
    );
    final repairedXml = _repairCustomNumberFormats(stylesXml);
    if (repairedXml == stylesXml) return null;
    return _encodeMarketWorkbookWithStyles(sourceArchive, repairedXml);
  } catch (_) {
    return null;
  }
}

Uint8List _sanitizeMarketWorkbookStyles(Uint8List bytes) {
  final sourceArchive = ZipDecoder().decodeBytes(bytes);
  final stylesFile = sourceArchive.findFile('xl/styles.xml');
  if (stylesFile == null || !stylesFile.isFile) {
    throw StateError('Le classeur Excel ne contient pas de styles lisibles.');
  }
  final repairedXml = _repairCustomNumberFormats(
    utf8.decode(stylesFile.content as List<int>, allowMalformed: true),
  );
  return _encodeMarketWorkbookWithStyles(sourceArchive, repairedXml);
}

Uint8List _encodeMarketWorkbookWithStyles(Archive sourceArchive, String styles) {
  final sanitizedArchive = Archive();
  for (final file in sourceArchive.files) {
    final content = file.isFile ? file.content as List<int> : const <int>[];
    final sanitizedContent =
        file.name == 'xl/styles.xml' ? utf8.encode(styles) : content;
    final sanitizedFile = ArchiveFile(
      file.name,
      sanitizedContent.length,
      sanitizedContent,
    )
      ..isFile = file.isFile
      ..isSymbolicLink = file.isSymbolicLink
      ..nameOfLinkedFile = file.nameOfLinkedFile
      ..mode = file.mode
      ..ownerId = file.ownerId
      ..groupId = file.groupId
      ..lastModTime = file.lastModTime
      ..comment = file.comment
      ..compress = file.compress;
    sanitizedArchive.addFile(sanitizedFile);
  }
  final sanitizedBytes = ZipEncoder().encode(sanitizedArchive);
  if (sanitizedBytes == null) {
    throw StateError('Impossible de normaliser les styles du classeur Excel.');
  }
  return Uint8List.fromList(sanitizedBytes);
}

String _repairCustomNumberFormats(String xml) {
  final numFmtPattern = RegExp(r'<numFmt\b[^>]*\bnumFmtId="(\d+)"[^>]*/>');
  final ids = [
    for (final match in numFmtPattern.allMatches(xml))
      int.tryParse(match.group(1) ?? ''),
  ].whereType<int>().toList(growable: false);
  var nextCustomId = math.max(
    164,
    ids.fold<int>(163, (maxId, id) => math.max(maxId, id)) + 1,
  );
  final remappedIds = <String, String>{};

  var repairedXml = xml.replaceAllMapped(numFmtPattern, (match) {
    final idText = match.group(1);
    final id = int.tryParse(idText ?? '');
    if (idText == null || id == null || id >= 164) {
      return match.group(0)!;
    }
    final replacementId =
        remappedIds.putIfAbsent(idText, () => '\${nextCustomId++}');
    return match.group(0)!.replaceFirst(
          'numFmtId="$idText"',
          'numFmtId="$replacementId"',
        );
  });

  for (final entry in remappedIds.entries) {
    repairedXml = repairedXml.replaceAll(
      'numFmtId="\${entry.key}"',
      'numFmtId="\${entry.value}"',
    );
  }
  return repairedXml;
}

Excel _decodeMarketWorkbook(Uint8List bytes) {
  final repairedBytes = _repairMarketWorkbookStylesIfNeeded(bytes);
  if (repairedBytes != null) {
    return Excel.decodeBytes(repairedBytes);
  }
  try {
    return Excel.decodeBytes(bytes);
  } catch (_) {
    return Excel.decodeBytes(_sanitizeMarketWorkbookStyles(bytes));
  }
}

void main() async {
  try {
    final bytes = File('../test_python.xlsx').readAsBytesSync();
    print('Decoding test_python.xlsx with market data sanitizer...');
    final excel = _decodeMarketWorkbook(bytes);
    print('Decoded successfully! Sheets: \${excel.tables.keys}');
  } catch (e, stackTrace) {
    print('Error decoding: $e');
    print(stackTrace);
  }
}
