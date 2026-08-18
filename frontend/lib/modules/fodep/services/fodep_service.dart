// Service HTTP du module FODEP. Client dédié et léger (pas de dépendance sur
// le RwaApiService central) : FODEP est un module autonome qui ne fait que
// lire/écrire ses propres routes ainsi que consulter (sans les modifier) les
// agrégats déjà exposés par les modules RWA crédit / marché / opérationnel.
import 'dart:typed_data';

import '../../../core/services/api_client.dart';
import '../models/fodep_models.dart';

class FodepService {
  FodepService({required this.api});

  final ApiClient api;

  Future<List<CodeDispru>> listerCodesDispru() async {
    final reponse = await api.get('/fodep/dispru/fonds-propres') as List;
    return reponse
        .map((e) => CodeDispru.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FodepApercu> obtenirApercu({String? periode}) async {
    final chemin = periode == null
        ? '/fodep/fonds-propres'
        : '/fodep/fonds-propres?periode=${Uri.encodeQueryComponent(periode)}';
    final reponse = await api.get(chemin) as Map<String, dynamic>;
    return FodepApercu.fromJson(reponse);
  }

  Future<FodepApercu> enregistrer({
    required String periode,
    required Map<String, double> postes,
  }) async {
    final reponse = await api.put('/fodep/fonds-propres', {
      'periode': periode,
      'postes': postes,
    }) as Map<String, dynamic>;
    return FodepApercu.fromJson(reponse);
  }

  Future<EtablissementView> obtenirEtablissement() async {
    final reponse = await api.get('/fodep/etablissement') as Map<String, dynamic>;
    return EtablissementView.fromJson(reponse);
  }

  Future<EtablissementView> enregistrerEtablissement({
    required String denomination,
    required String codeBceao,
  }) async {
    final reponse = await api.put('/fodep/etablissement', {
      'denomination': denomination,
      'code_bceao': codeBceao,
    }) as Map<String, dynamic>;
    return EtablissementView.fromJson(reponse);
  }

  Future<Uint8List> exporterExcel({String? periode}) {
    final chemin = periode == null
        ? '/fodep/fonds-propres/export'
        : '/fodep/fonds-propres/export?periode=${Uri.encodeQueryComponent(periode)}';
    return api.getBytes(chemin);
  }

  Future<ImportFodepResult> importerExcel(Uint8List bytes, String filename) async {
    final reponse = await api.uploadBytes(
      '/fodep/fonds-propres/import',
      bytes,
      filename,
    ) as Map<String, dynamic>;
    return ImportFodepResult.fromJson(reponse);
  }
}
