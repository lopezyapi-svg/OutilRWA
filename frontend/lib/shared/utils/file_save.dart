import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

// L'ordre compte : sur le web, `dart.library.io` est faux et
// `dart.library.js_interop` vrai ; hors navigateur, l'inverse.
import 'file_save_stub.dart'
    if (dart.library.js_interop) 'file_save_web.dart'
    if (dart.library.io) 'file_save_io.dart';

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

/// Fichier remis à l'utilisateur : écrit sur le disque (bureau) ou téléchargé
/// par le navigateur (web).
class SavedFile {
  const SavedFile(this.path);

  /// Chemin complet du fichier sur le bureau ; sur le web, le simple nom
  /// proposé au téléchargement (le navigateur choisit le dossier).
  final String path;
}

/// Écrit [bytes] pour l'utilisateur.
///
/// - **Bureau** : [location] (issue de `getSaveLocation`) porte le chemin
///   retenu dans la boîte de dialogue système.
/// - **Web** : `file_selector` ne fournit pas de chemin — `getSaveLocation`
///   renvoie une valeur vide et l'écriture `dart:io` échoue
///   (`Unsupported operation: _Namespace`). On déclenche alors un
///   téléchargement navigateur, nommé d'après [suggestedName] (le même que
///   celui passé à `getSaveLocation`), sinon d'après [location], sinon
///   « telechargement ».
Future<SavedFile> saveBytesAtLocation(
  FileSaveLocation location,
  Uint8List bytes, {
  required String requiredExtension,
  String? suggestedName,
}) async {
  final nomChoisi = suggestedName?.trim();
  final nomLocation = location.path.trim();
  final nomBrut = (nomChoisi != null && nomChoisi.isNotEmpty)
      ? nomChoisi
      : (nomLocation.isNotEmpty ? nomLocation : 'telechargement');
  final cible = ensureRequiredFileExtension(nomBrut, requiredExtension);
  final chemin = await writeBytes(cible, bytes);
  return SavedFile(chemin);
}
