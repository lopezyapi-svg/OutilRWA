import 'dart:io';
import 'dart:typed_data';

/// Écrit les octets sur le disque, à l'emplacement choisi par l'utilisateur
/// dans la boîte de dialogue système. Retourne le chemin complet du fichier.
Future<String> writeBytes(String target, Uint8List bytes) async {
  final file = File(target);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
