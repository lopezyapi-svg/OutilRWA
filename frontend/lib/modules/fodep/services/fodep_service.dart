// Service HTTP du module FODEP. Client dédié et léger (pas de dépendance sur
// le RwaApiService central) : FODEP est un module autonome qui ne fait que
// lire/écrire ses propres routes ainsi que consulter (sans les modifier) les
// agrégats déjà exposés par les modules RWA crédit / marché / opérationnel.
import 'dart:typed_data';

import '../../../core/services/api_client.dart';
import '../../risque_operationnel/models/ro_models.dart';
import '../../rwa_engine/models/rwa_credit_analysis.dart';
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

  /// Ventilation du RWA crédit par catégorie prudentielle (EP09-EP20) -
  /// déjà calculée par le module rwa_credit, réutilisée telle quelle (voir
  /// l'en-tête de ce fichier : FODEP ne recalcule pas ce que d'autres
  /// modules calculent déjà).
  Future<RwaCreditAnalysis> obtenirAnalyseCredit() async {
    final reponse = await api.get('/rwa-credit/analyse') as Map<String, dynamic>;
    return RwaCreditAnalysis.fromJson(reponse);
  }

  /// Détail EP21-EP22 (approche indicateur de base) - déjà calculé par le
  /// module risque opérationnel, réutilisé tel quel.
  Future<AibCalculResult> obtenirCalculAib() async {
    final reponse = await api.get('/risque-operationnel/aib/calcul') as Map<String, dynamic>;
    return AibCalculResult.fromJson(reponse);
  }

  Future<List<ParticipationEntry>> listerParticipations({String? periode}) async {
    final chemin = periode == null
        ? '/fodep/participations'
        : '/fodep/participations?periode=${Uri.encodeQueryComponent(periode)}';
    final reponse = await api.get(chemin) as List;
    return reponse
        .map((e) => ParticipationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ParticipationEntry>> enregistrerParticipations({
    required String periode,
    required List<ParticipationEntry> lignes,
  }) async {
    final reponse = await api.put('/fodep/participations', {
      'periode': periode,
      'lignes': lignes.map((l) => l.toJson()).toList(),
    }) as List;
    return reponse
        .map((e) => ParticipationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
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
