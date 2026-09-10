import 'dart:typed_data';

/// Repli : aucune plateforme cible connue. Ne devrait jamais être atteint
/// (le web et les plateformes `dart:io` ont chacun leur implémentation).
Future<String> writeBytes(String target, Uint8List bytes) {
  throw UnsupportedError(
    'Enregistrement de fichier indisponible sur cette plateforme.',
  );
}
