import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Déclenche un téléchargement navigateur : `file_selector` ne sait pas
/// écrire un fichier sur le web (`getSaveLocation` renvoie une valeur vide),
/// on passe donc par un `Blob` + un lien `<a download>` synthétique.
///
/// Retourne le nom de fichier proposé au navigateur.
Future<String> writeBytes(String target, Uint8List bytes) async {
  final nom = target
      .split(RegExp(r'[\\/]'))
      .where((segment) => segment.isNotEmpty)
      .fold<String>(target, (_, segment) => segment);

  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final ancre = web.HTMLAnchorElement()
    ..href = url
    ..download = nom
    ..style.display = 'none';
  web.document.body?.appendChild(ancre);
  ancre.click();
  ancre.remove();
  web.URL.revokeObjectURL(url);
  return nom;
}
