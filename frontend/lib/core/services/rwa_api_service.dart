// Ce fichier centralise l'acces aux donnees et le mode mock.
import 'dart:async';
import 'dart:typed_data';

import '../../modules/crm/models/crm_models.dart';
import '../../modules/dashboard/models/dashboard_models.dart';
import '../../modules/expositions/models/exposition_models.dart';
import '../../modules/hors_bilan/models/hors_bilan_models.dart';
import '../../modules/rapports/models/report_models.dart';
import '../../modules/referentiels/models/referentiels_models.dart';
import '../../modules/risque_operationnel/models/ro_models.dart';
import 'api_client.dart';
import 'api_runtime_environment.dart' as runtime_environment;

String _resolveDefaultApiBaseUrl() {
  final runtimeBaseUrl =
      runtime_environment.runtimeEnvironmentValue('RWA_API_BASE_URL')?.trim();
  if (runtimeBaseUrl != null && runtimeBaseUrl.isNotEmpty) {
    return runtimeBaseUrl;
  }

  const buildBaseUrl = String.fromEnvironment('RWA_API_BASE_URL');
  if (buildBaseUrl.isNotEmpty) {
    return buildBaseUrl;
  }

  final runtimeHost =
      runtime_environment.runtimeEnvironmentValue('RWA_API_HOST')?.trim();
  final runtimePort =
      runtime_environment.runtimeEnvironmentValue('RWA_API_PORT')?.trim();
  final host =
      runtimeHost == null || runtimeHost.isEmpty ? '127.0.0.1' : runtimeHost;
  final port =
      runtimePort == null || runtimePort.isEmpty ? '8000' : runtimePort;
  return 'http://$host:$port';
}

/// Service principal qui orchestre les appels API et les données mockées.
class RwaApiService {
  RwaApiService({
    this.useMockData = true,
    String? baseUrl,
    ApiClient? client,
  }) : _client = client ??
            ApiClient(
              baseUrl: baseUrl ?? _resolveDefaultApiBaseUrl(),
            );

  final bool useMockData;
  final ApiClient _client;
  final bool enableOfflineFallback = false;
  final StreamController<int> _portfolioRefreshController =
      StreamController<int>.broadcast();
  int _portfolioRefreshTick = 0;
  Future<DashboardSnapshot>? _dashboardFuture;
  Future<ExposureModuleData>? _expositionsFuture;
  Future<OffBalanceModuleData>? _horsBilanFuture;
  Future<CrmModuleData>? _crmFuture;
  Future<ReferentielsModuleData>? _referentielsFuture;
  Future<ReportsModuleData>? _reportsFuture;

  Stream<int> get portfolioRefreshStream => _portfolioRefreshController.stream;

  Future<Map<String, dynamic>> refreshCemacYieldCurves() async {
    final payload =
        await _client.post('/market/yield-curves/cemac/refresh', {});
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    throw StateError('Réponse CEMAC invalide.');
  }

  Future<Map<String, dynamic>?> fetchMarketPortfolioPayload() async {
    final payload = await _client.get('/market/portfolios');
    if (payload is! Map) return null;
    final map = Map<String, dynamic>.from(payload);
    final data = map['payload'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> saveMarketPortfolioPayload(
    Map<String, Object?> payload,
  ) async {
    await _client.put('/market/portfolios', {'payload': payload});
  }

  final List<Map<String, dynamic>> _riskWeights = [
    {
      'id': 'RW001',
      'segment': 'Souverains',
      'rating': 'AAA/AA',
      'risk_weight': 0.0,
      'approach': 'Standard',
    },
    {
      'id': 'RW002',
      'segment': 'Souverains',
      'rating': 'A',
      'risk_weight': 0.2,
      'approach': 'Standard',
    },
    {
      'id': 'RW003',
      'segment': 'Souverains',
      'rating': 'BBB',
      'risk_weight': 0.5,
      'approach': 'Standard',
    },
    {
      'id': 'RW005',
      'segment': 'Banques',
      'rating': 'AAA/AA',
      'risk_weight': 0.2,
      'approach': 'Standard',
    },
    {
      'id': 'RW006',
      'segment': 'Banques',
      'rating': 'A',
      'risk_weight': 0.5,
      'approach': 'Standard',
    },
    {
      'id': 'RW007',
      'segment': 'Banques',
      'rating': 'BBB',
      'risk_weight': 1.0,
      'approach': 'Standard',
    },
    {
      'id': 'RW009',
      'segment': 'Entreprises',
      'rating': 'AAA/AA',
      'risk_weight': 0.2,
      'approach': 'Standard',
    },
    {
      'id': 'RW010',
      'segment': 'Entreprises',
      'rating': 'A',
      'risk_weight': 0.5,
      'approach': 'Standard',
    },
    {
      'id': 'RW011',
      'segment': 'Entreprises',
      'rating': 'BBB',
      'risk_weight': 1.0,
      'approach': 'Standard',
    },
    {
      'id': 'RW012',
      'segment': 'Entreprises',
      'rating': 'BB/B',
      'risk_weight': 1.5,
      'approach': 'Standard',
    },
    {
      'id': 'RW014',
      'segment': 'Particuliers',
      'rating': 'AAA/AA',
      'risk_weight': 0.35,
      'approach': 'Standard',
    },
    {
      'id': 'RW016',
      'segment': 'Particuliers',
      'rating': 'BBB',
      'risk_weight': 0.75,
      'approach': 'Standard',
    },
    {
      'id': 'RW017',
      'segment': 'Particuliers',
      'rating': 'BB/B',
      'risk_weight': 1.0,
      'approach': 'Standard',
    },
  ];

  final List<Map<String, dynamic>> _ccfTable = [
    {'id': 'CCF001', 'engagement_type': 'Credit documentaire', 'ccf': 0.75},
    {'id': 'CCF002', 'engagement_type': 'Lignes de credit', 'ccf': 0.5},
    {'id': 'CCF003', 'engagement_type': 'Instruments financiers', 'ccf': 1.0},
    {'id': 'CCF004', 'engagement_type': 'Garanties financieres', 'ccf': 0.5},
    {'id': 'CCF005', 'engagement_type': 'Engagement de garantie', 'ccf': 1.0},
  ];

  final List<Map<String, dynamic>> _ratings = [
    {
      'id': 'RT001',
      'label': 'AAA/AA',
      'description': 'Qualite de signature tres forte',
      'sort_order': 1,
    },
    {
      'id': 'RT002',
      'label': 'A',
      'description': 'Qualite de signature solide',
      'sort_order': 2,
    },
    {
      'id': 'RT003',
      'label': 'BBB',
      'description': 'Qualite investment grade',
      'sort_order': 3,
    },
    {
      'id': 'RT004',
      'label': 'BB/B',
      'description': 'Qualite speculative',
      'sort_order': 4,
    },
    {
      'id': 'RT005',
      'label': 'Non noté',
      'description': 'Absence de notation externe',
      'sort_order': 5,
    },
  ];

  final List<Map<String, dynamic>> _exposures = [
    {
      'id': 'CP001',
      'analysis_date': '2026-04-21',
      'counterparty': {
        'id': 'CP001',
        'name': 'Societe A',
        'country': "Cote d'Ivoire",
        'category': 'Entreprises',
        'rating': 'BBB',
      },
      'gross_amount': 50000000.0,
      'crm_type': 'Garantie etatique',
      'crm_coverage_percent': 0.4,
      'original_rw': 1.0,
      'final_rw': 0.6,
      'ead': 50000000.0,
      'rwa': 30000000.0,
      'capital': 2400000.0,
      'comment': "Portefeuille corporate Cote d'Ivoire",
    },
    {
      'id': 'CP002',
      'analysis_date': '2026-04-21',
      'counterparty': {
        'id': 'CP002',
        'name': 'Banque X',
        'country': 'Senegal',
        'category': 'Banques',
        'rating': 'A',
      },
      'gross_amount': 30000000.0,
      'crm_type': 'Cash collateral',
      'crm_coverage_percent': 0.2,
      'original_rw': 0.5,
      'final_rw': 0.4,
      'ead': 30000000.0,
      'rwa': 12000000.0,
      'capital': 960000.0,
      'comment': 'Ligne interbancaire',
    },
    {
      'id': 'CP003',
      'analysis_date': '2026-04-21',
      'counterparty': {
        'id': 'CP003',
        'name': 'Etat Y',
        'country': 'Benin',
        'category': 'Souverains',
        'rating': 'AA',
      },
      'gross_amount': 40000000.0,
      'crm_type': 'Aucune',
      'crm_coverage_percent': 0.0,
      'original_rw': 0.0,
      'final_rw': 0.0,
      'ead': 40000000.0,
      'rwa': 0.0,
      'capital': 0.0,
      'comment': 'Exposition souveraine',
    },
    {
      'id': 'CP004',
      'analysis_date': '2026-04-21',
      'counterparty': {
        'id': 'CP004',
        'name': 'Client ABC',
        'country': "Cote d'Ivoire",
        'category': 'Particuliers',
        'rating': 'BB+',
      },
      'gross_amount': 10000000.0,
      'crm_type': 'Assurance credit',
      'crm_coverage_percent': 0.75,
      'original_rw': 1.0,
      'final_rw': 0.25,
      'ead': 10000000.0,
      'rwa': 2500000.0,
      'capital': 200000.0,
      'comment': 'Retail securise',
    },
    {
      'id': 'CP005',
      'analysis_date': '2026-04-21',
      'counterparty': {
        'id': 'CP005',
        'name': 'Client XYZ',
        'country': 'Togo',
        'category': 'Entreprises',
        'rating': 'BBB',
      },
      'gross_amount': 18000000.0,
      'crm_type': 'Garantie bancaire',
      'crm_coverage_percent': 0.35,
      'original_rw': 1.0,
      'final_rw': 0.7,
      'ead': 18000000.0,
      'rwa': 9500000.0,
      'capital': 760000.0,
      'comment': 'Portefeuille corporate Togo',
    },
    {
      'id': 'CP006',
      'analysis_date': '2026-04-21',
      'counterparty': {
        'id': 'CP006',
        'name': 'Banque ABC',
        'country': 'Burkina Faso',
        'category': 'Banques',
        'rating': 'A',
      },
      'gross_amount': 16000000.0,
      'crm_type': 'Cash collateral',
      'crm_coverage_percent': 0.25,
      'original_rw': 0.5,
      'final_rw': 0.4,
      'ead': 16000000.0,
      'rwa': 6800000.0,
      'capital': 544000.0,
      'comment': 'Ligne interbancaire Burkina Faso',
    },
  ];

  final List<Map<String, dynamic>> _offBalance = [
    {
      'id': 'HB001',
      'analysis_date': '2026-04-21',
      'counterparty_id': 'CP002',
      'counterparty_name': 'Banque X',
      'category': 'Banques',
      'rating': 'A',
      'engagement_type': 'Credit documentaire',
      'nominal_amount': 10000000.0,
      'ccf': 0.75,
      'ead': 7500000.0,
      'risk_weight': 0.5,
      'rwa': 3750000.0,
      'capital': 300000.0,
      'comment': 'Flux import',
    },
    {
      'id': 'HB002',
      'analysis_date': '2026-04-21',
      'counterparty_id': 'CP005',
      'counterparty_name': 'Client XYZ',
      'category': 'Entreprises',
      'rating': 'BBB',
      'engagement_type': 'Lignes de credit',
      'nominal_amount': 15000000.0,
      'ccf': 0.5,
      'ead': 7500000.0,
      'risk_weight': 1.0,
      'rwa': 7500000.0,
      'capital': 600000.0,
      'comment': 'Lignes non annullables',
    },
    {
      'id': 'HB003',
      'analysis_date': '2026-04-21',
      'counterparty_id': 'CP006',
      'counterparty_name': 'Banque ABC',
      'category': 'Banques',
      'rating': 'A',
      'engagement_type': 'Instruments financiers',
      'nominal_amount': 8000000.0,
      'ccf': 1.0,
      'ead': 8000000.0,
      'risk_weight': 0.5,
      'rwa': 4000000.0,
      'capital': 320000.0,
      'comment': 'Back-up market',
    },
  ];

  final List<Map<String, dynamic>> _crmItems = [
    {
      'id': 'CRM001',
      'exposure_id': 'CP001',
      'borrower_name': 'Societe A',
      'borrower_category': 'Entreprises',
      'borrower_rating': 'BBB',
      'gross_amount': 50000000.0,
      'guarantor_name': 'Etat Francais',
      'guarantor_category': 'Souverains',
      'guarantor_rating': 'AA',
      'guarantee_type': 'CRM non financee',
      'coverage_amount': 20000000.0,
      'coverage_ratio': 0.4,
      'borrower_rw': 1.0,
      'guarantor_rw': 0.0,
      'final_rw': 0.6,
      'ead': 50000000.0,
      'rwa_before': 50000000.0,
      'rwa_after': 30000000.0,
      'capital_before': 4000000.0,
      'capital_after': 2400000.0,
      'rwa_reduction': 20000000.0,
      'capital_saving': 1600000.0,
    },
    {
      'id': 'CRM002',
      'exposure_id': 'CP002',
      'borrower_name': 'Banque X',
      'borrower_category': 'Banques',
      'borrower_rating': 'A',
      'gross_amount': 30000000.0,
      'guarantor_name': 'Societe Z',
      'guarantor_category': 'Entreprises',
      'guarantor_rating': 'A',
      'guarantee_type': 'CRM financee',
      'coverage_amount': 9000000.0,
      'coverage_ratio': 0.3,
      'borrower_rw': 0.5,
      'guarantor_rw': 0.5,
      'final_rw': 0.5,
      'ead': 30000000.0,
      'rwa_before': 15000000.0,
      'rwa_after': 15000000.0,
      'capital_before': 1200000.0,
      'capital_after': 1200000.0,
      'rwa_reduction': 0.0,
      'capital_saving': 0.0,
    },
    {
      'id': 'CRM003',
      'exposure_id': 'CP004',
      'borrower_name': 'Client ABC',
      'borrower_category': 'Particuliers',
      'borrower_rating': 'BB+',
      'gross_amount': 10000000.0,
      'guarantor_name': 'Assurance C',
      'guarantor_category': 'Entreprises',
      'guarantor_rating': 'BBB',
      'guarantee_type': 'Assurance credit',
      'coverage_amount': 4500000.0,
      'coverage_ratio': 0.45,
      'borrower_rw': 1.0,
      'guarantor_rw': 1.0,
      'final_rw': 1.0,
      'ead': 10000000.0,
      'rwa_before': 10000000.0,
      'rwa_after': 10000000.0,
      'capital_before': 800000.0,
      'capital_after': 800000.0,
      'rwa_reduction': 0.0,
      'capital_saving': 0.0,
    },
  ];

  final List<Map<String, dynamic>> _reports = [
    {
      'id': 'RPT001',
      'created_at': '2026-04-19',
      'period': 'Mars 2026',
      'report_type': 'Synthese',
      'currency': 'EUR',
      'exposure_scope': 'Toutes',
      'include_category_chart': true,
      'include_rating_chart': true,
      'exports': {
        'pdf': '/exports/RPT001.pdf',
        'excel': '/exports/RPT001.xlsx',
      },
      'lines': <Map<String, dynamic>>[],
    },
    {
      'id': 'RPT002',
      'created_at': '2026-04-20',
      'period': 'Mars 2026',
      'report_type': 'Detaille',
      'currency': 'EUR',
      'exposure_scope': 'Toutes',
      'include_category_chart': true,
      'include_rating_chart': false,
      'exports': {
        'pdf': '/exports/RPT002.pdf',
        'excel': '/exports/RPT002.xlsx',
      },
      'lines': <Map<String, dynamic>>[],
    },
  ];

  // ─── Risque Opérationnel ─────────────────────────────────────────────────

  Future<RoDashboardData> fetchRoDashboard() async {
    final json = await _client.get('/risque-operationnel/dashboard') as Map<String, dynamic>;
    return RoDashboardData.fromJson(json);
  }

  Future<List<RoIncident>> fetchRoIncidents({String? statut, String? ligneMetier}) async {
    var path = '/risque-operationnel/incidents';
    final params = <String>[];
    if (statut != null) params.add('statut=${Uri.encodeComponent(statut)}');
    if (ligneMetier != null) params.add('ligne_metier=${Uri.encodeComponent(ligneMetier)}');
    if (params.isNotEmpty) path = '$path?${params.join('&')}';
    final json = await _client.get(path) as List<dynamic>;
    return json.map((e) => RoIncident.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RoIncident> createRoIncident(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/incidents', data) as Map<String, dynamic>;
    return RoIncident.fromJson(json);
  }

  Future<RoIncident> updateRoIncident(String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/incidents/$id', data) as Map<String, dynamic>;
    return RoIncident.fromJson(json);
  }

  Future<void> deleteRoIncident(String id) async {
    await _client.delete('/risque-operationnel/incidents/$id');
  }

  Future<Uint8List> downloadRoImportTemplate() async {
    return _client.getBytes('/risque-operationnel/incidents/import/template');
  }

  Future<Map<String, dynamic>> importRoIncidents(
    List<Map<String, dynamic>> incidents, {
    String mode = 'merge',
  }) async {
    final json = await _client.post('/risque-operationnel/incidents/import', {
      'incidents': incidents,
      'mode': mode,
    }) as Map<String, dynamic>;
    return json;
  }

  Future<RoKriModuleData> fetchRoKri() async {
    final json = await _client.get('/risque-operationnel/kri') as Map<String, dynamic>;
    return RoKriModuleData.fromJson(json);
  }

  Future<RoKriValeur> addRoKriValeur(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/kri/valeurs', data) as Map<String, dynamic>;
    return RoKriValeur.fromJson(json);
  }

  Future<RoKriModuleData> autoCalculKri() async {
    final json = await _client.post('/risque-operationnel/kri/auto-calcul', {}) as Map<String, dynamic>;
    return RoKriModuleData.fromJson(json);
  }

  Future<List<RoRisque>> fetchRoRisques() async {
    final json = await _client.get('/risque-operationnel/risques') as List<dynamic>;
    return json.map((e) => RoRisque.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RoRisque> createRoRisque(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/risques', data) as Map<String, dynamic>;
    return RoRisque.fromJson(json);
  }

  Future<RoRisque> updateRoRisque(String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/risques/$id', data) as Map<String, dynamic>;
    return RoRisque.fromJson(json);
  }

  Future<void> deleteRoRisque(String id) async {
    await _client.delete('/risque-operationnel/risques/$id');
  }

  Future<List<RoControle>> fetchRoControles() async {
    final json = await _client.get('/risque-operationnel/controles') as List<dynamic>;
    return json.map((e) => RoControle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RoControle> createRoControle(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/controles', data) as Map<String, dynamic>;
    return RoControle.fromJson(json);
  }

  Future<RoControle> updateRoControle(String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/controles/$id', data) as Map<String, dynamic>;
    return RoControle.fromJson(json);
  }

  Future<void> deleteRoControle(String id) async {
    await _client.delete('/risque-operationnel/controles/$id');
  }

  Future<List<RoPlan>> fetchRoPlans() async {
    final json = await _client.get('/risque-operationnel/plans') as List<dynamic>;
    return json.map((e) => RoPlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RoPlan> createRoPlan(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/plans', data) as Map<String, dynamic>;
    return RoPlan.fromJson(json);
  }

  Future<RoPlan> updateRoPlan(String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/plans/$id', data) as Map<String, dynamic>;
    return RoPlan.fromJson(json);
  }

  Future<void> deleteRoPlan(String id) async {
    await _client.delete('/risque-operationnel/plans/$id');
  }

  Future<List<RoHistorique>> fetchRoHistorique({int limit = 200}) async {
    final json = await _client.get('/risque-operationnel/historique?limit=$limit') as List<dynamic>;
    return json.map((e) => RoHistorique.fromJson(e as Map<String, dynamic>)).toList();
  }

  void dispose() {
    _portfolioRefreshController.close();
  }

  void _notifyPortfolioChanged() {
    _invalidatePortfolioCaches();
    if (_portfolioRefreshController.isClosed) {
      return;
    }
    _portfolioRefreshController.add(++_portfolioRefreshTick);
  }

  void _invalidatePortfolioCaches() {
    _dashboardFuture = null;
    _expositionsFuture = null;
    _horsBilanFuture = null;
    _crmFuture = null;
    _reportsFuture = null;
  }

  Future<T> _memoizeFuture<T>({
    required Future<T>? cached,
    required Future<T>? Function() getCache,
    required void Function(Future<T>? value) setCache,
    required Future<T> Function() load,
  }) {
    if (cached != null) {
      return cached;
    }

    final future = load();
    setCache(future);
    future.then<void>((_) {}, onError: (_) {
      if (identical(getCache(), future)) {
        setCache(null);
      }
    });
    return future;
  }

  Future<DashboardSnapshot> fetchDashboard() async {
    return _memoizeFuture<DashboardSnapshot>(
      cached: _dashboardFuture,
      getCache: () => _dashboardFuture,
      setCache: (value) => _dashboardFuture = value,
      load: () async {
        if (!useMockData) {
          // En mode réel, on délègue entièrement l'assemblage au backend.
          final json = await _client.get('/dashboard') as Map<String, dynamic>;
          return DashboardSnapshot.fromJson(json);
        }
        // En mode démo, on reconstruit un snapshot cohérent à partir des jeux locaux.
        return _withDelay(_buildMockDashboard());
      },
    );
  }

  Future<ExposureModuleData> fetchExpositionsModule() async {
    return _memoizeFuture<ExposureModuleData>(
      cached: _expositionsFuture,
      getCache: () => _expositionsFuture,
      setCache: (value) => _expositionsFuture = value,
      load: () async {
        if (!useMockData) {
          try {
            final exposuresJson =
                await _client.get('/expositions') as List<dynamic>;
            final summaryJson = await _client.get('/expositions/summary')
                as Map<String, dynamic>;
            return ExposureModuleData(
              exposures: exposuresJson
                  .map(
                    (item) =>
                        ExposureRecord.fromJson(item as Map<String, dynamic>),
                  )
                  .toList(),
              summary: ExposureSummary.fromJson(summaryJson),
            );
          } catch (_) {
            if (!enableOfflineFallback) rethrow;
          }
        }

        final exposures =
            _exposures.map((item) => ExposureRecord.fromJson(item)).toList();
        return _withDelay(
          ExposureModuleData(
            exposures: exposures,
            summary: _computeExposureSummary(exposures),
          ),
        );
      },
    );
  }

  Future<String> fetchNextExposureId() async {
    if (!useMockData) {
      try {
        final response = Map<String, dynamic>.from(
          await _client.get('/expositions/next-id') as Map,
        );
        final identifier = (response['id'] ?? '').toString().trim();
        if (identifier.isNotEmpty) {
          return identifier;
        }
      } catch (error) {
        try {
          final module = await fetchExpositionsModule();
          return _nextExposureIdFromIdentifiers(
            module.exposures.map((item) => item.id),
          );
        } catch (_) {
          if (!enableOfflineFallback) rethrow;
          if (error is Error) {
            rethrow;
          }
        }
      }
    }

    return _withDelay(_nextExposureId());
  }

  Future<Uint8List> downloadExposureExcelExport() async {
    if (!useMockData) {
      return _client.getBytes('/expositions/export/excel/download');
    }

    throw UnsupportedError('L export Excel n est pas disponible en mode demo.');
  }

  Map<String, dynamic> _buildExposurePayload(ExposureDraft draft) {
    return {
      'id': draft.id,
      'analysis_date': draft.analysisDate.toIso8601String().split('T').first,
      'grant_date': draft.grantDate?.toIso8601String().split('T').first,
      'maturity_date': draft.maturityDate?.toIso8601String().split('T').first,
      'counterparty_name': draft.counterpartyName,
      'country': draft.country,
      'country_rating': draft.countryRating,
      'category': draft.backendCategory,
      'rating': draft.rating,
      'gross_amount': draft.grossAmount,
      'loan_total_amount': draft.loanTotalAmount,
      'on_balance_exposure_amount': draft.onBalanceExposureAmount,
      'off_balance_exposure_amount': draft.offBalanceExposureAmount,
      'currency': draft.currency,
      'status': draft.status,
      'sovereign_special_case': draft.sovereignSpecialCase,
      'sovereign_preferential_zero_weight':
          draft.sovereignPreferentialZeroWeight,
      'sovereign_oce_established': draft.sovereignOceEstablished,
      'sovereign_oce_note': draft.sovereignOceNote,
      'public_body_uemoa_fcfa_case': draft.publicBodyUemoaFcfaCase,
      'public_body_non_public_activity':
          draft.publicBodyFinancesNonPublicActivity,
      'bmd_high_quality_case': draft.bmdHighQualityCase,
      'bmd_uemoa_fcfa_case': draft.bmdUemoaFcfaCase,
      'bmd_uemoa_criteria_satisfied': draft.bmdUemoaCriteriaSatisfied,
      'bmd_listed_institution_fcfa_case': draft.bmdListedInstitutionFcfaCase,
      'bank_institution_case': draft.bankInstitutionCase,
      'other_asset_type': draft.otherAssetType,
      'off_balance_risk_level': draft.offBalanceRiskLevel,
      'retail_eligibility_criteria_satisfied':
          draft.retailEligibilityCriteriaSatisfied,
      'residential_mortgage_eligible': draft.residentialMortgageEligible,
      'commercial_real_estate_eligible': draft.commercialRealEstateEligible,
      'defaulted_exposure_initial_risk_weight':
          draft.defaultedExposureInitialRiskWeight,
      'defaulted_exposure_residential_mortgage_in_default':
          draft.defaultedExposureResidentialMortgageInDefault,
      'defaulted_exposure_provision_at_least_twenty_percent':
          draft.defaultedExposureProvisionAtLeastTwentyPercent,
      'enterprise_exceeds_bceao_degradation_threshold':
          draft.enterpriseExceedsBceaoDegradationThreshold,
      'enterprise_prudential_procedure': draft.enterprisePrudentialProcedure,
      'enterprise_investment_firm_without_banking_law':
          draft.enterpriseInvestmentFirmWithoutBankingLaw,
      'crm_type': draft.backendCrmType,
      'crm_coverage_percent': _effectiveCrmCoverage(draft),
      'crm_details': draft.crmDetailsJson,
      'comment': draft.comment,
    };
  }

  Future<ExposureRecord> createExposure(ExposureDraft draft) async {
    if (!useMockData) {
      try {
        final response = Map<String, dynamic>.from(
          await _client.post('/expositions', _buildExposurePayload(draft))
              as Map,
        );
        _notifyPortfolioChanged();
        return ExposureRecord.fromJson(response);
      } catch (_) {
        if (!enableOfflineFallback) rethrow;
      }
    }

    final id = _nextExposureId();
    final created = _buildExposureMapFromDraft(draft, id);
    _exposures.add(created);
    _notifyPortfolioChanged();
    return ExposureRecord.fromJson(created);
  }

  Future<ExposureRecord> updateExposure(ExposureDraft draft) async {
    final id = draft.id;
    if (id == null || id.isEmpty) {
      return createExposure(draft);
    }

    if (!useMockData) {
      try {
        final response = Map<String, dynamic>.from(
          await _client.put('/expositions/$id', _buildExposurePayload(draft))
              as Map,
        );
        _notifyPortfolioChanged();
        return ExposureRecord.fromJson(response);
      } catch (_) {
        if (!enableOfflineFallback) rethrow;
      }
    }

    final index = _exposures.indexWhere((item) => item['id'] == id);
    final replacement = _buildExposureMapFromDraft(draft, id);
    if (index >= 0) {
      _exposures[index] = replacement;
    } else {
      _exposures.add(replacement);
    }
    _notifyPortfolioChanged();
    return ExposureRecord.fromJson(replacement);
  }

  Future<ExposureRecord> previewExposure(ExposureDraft draft) async {
    if (!useMockData) {
      final response = Map<String, dynamic>.from(
        await _client.post('/expositions/preview', _buildExposurePayload(draft))
            as Map,
      );
      return ExposureRecord.fromJson(response);
    }

    final previewId =
        draft.id?.isNotEmpty == true ? draft.id! : 'PREVIEW_EXPOSITION';
    return _withDelay(
      ExposureRecord.fromJson(_buildExposureMapFromDraft(draft, previewId)),
    );
  }

  Future<Map<String, dynamic>> deleteExposures(
    List<String> ids, {
    bool reindexIds = false,
  }) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) {
      return {
        'requested_ids': const <String>[],
        'deleted_ids': const <String>[],
        'missing_ids': const <String>[],
        'deleted_count': 0,
        'missing_count': 0,
      };
    }

    if (!useMockData) {
      try {
        final response = Map<String, dynamic>.from(
          await _client.post('/expositions/delete', {
            'ids': normalizedIds,
            'reindex_ids': reindexIds,
          }) as Map,
        );
        _notifyPortfolioChanged();
        return response;
      } catch (_) {
        if (!enableOfflineFallback) rethrow;
      }
    }

    final deletedIds = _exposures
        .where((item) => normalizedIds.contains((item['id'] ?? '').toString()))
        .map((item) => (item['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final missingIds = normalizedIds
        .where((id) => !deletedIds.contains(id))
        .toList(growable: false);

    _exposures.removeWhere(
      (item) => normalizedIds.contains((item['id'] ?? '').toString()),
    );
    final renumberedIds =
        reindexIds ? _reindexMockExposureIds() : <String, String>{};
    _notifyPortfolioChanged();
    return {
      'requested_ids': normalizedIds,
      'deleted_ids': deletedIds,
      'missing_ids': missingIds,
      'deleted_count': deletedIds.length,
      'missing_count': missingIds.length,
      'reindexed_ids': reindexIds && renumberedIds.isNotEmpty,
      'renumbered_ids': renumberedIds,
    };
  }

  Future<Map<String, dynamic>> importExposureCsvContent(
    String csvContent,
  ) async {
    if (!useMockData) {
      try {
        final response = Map<String, dynamic>.from(
          await _client.post('/expositions/import/csv', {'content': csvContent})
              as Map<String, dynamic>,
        );
        _notifyPortfolioChanged();
        return response;
      } catch (_) {
        if (!enableOfflineFallback) rethrow;
      }
    }

    final importedLines = csvContent
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .skip(1)
        .length;
    final response = {
      'status': 'success',
      'imported': importedLines,
      'imported_balance': importedLines,
      'imported_off_balance': 0,
      'total_lines_processed': importedLines,
    };
    _notifyPortfolioChanged();
    return response;
  }

  Future<Map<String, dynamic>> importExposureExcelFile(
    Uint8List bytes,
    String filename, {
    String mode = 'merge',
  }) async {
    if (!useMockData) {
      try {
        final response = Map<String, dynamic>.from(
          await _client.uploadBytes(
            '/expositions/import/upload',
            bytes,
            filename,
            fields: {'mode': mode},
          ) as Map<String, dynamic>,
        );
        _notifyPortfolioChanged();
        return response;
      } catch (_) {
        if (!enableOfflineFallback) rethrow;
      }
    }

    final response = {
      'status': 'success',
      'rows_read': 0,
      'valid_rows': 0,
      'imported_rows': 0,
      'updated_rows': 0,
      'rejected_rows': 0,
      'file': filename,
      'mode': mode,
      'errors': const <Map<String, dynamic>>[],
    };
    _notifyPortfolioChanged();
    return _withDelay(response);
  }

  Future<Map<String, dynamic>> inspectExposureExcelFile(
    Uint8List bytes,
    String filename,
  ) async {
    if (!useMockData) {
      try {
        return Map<String, dynamic>.from(
          await _client.uploadBytes(
            '/expositions/import/upload/inspect',
            bytes,
            filename,
          ) as Map,
        );
      } catch (_) {
        if (!enableOfflineFallback) rethrow;
      }
    }

    return _withDelay(<String, dynamic>{
      'file': filename,
      'valid': true,
      'sheet_count': 0,
      'detected_sheets': const <String>[],
      'sheets': const <Map<String, dynamic>>[],
      'errors': const <Map<String, dynamic>>[],
      'rows_read_by_sheet': const <String, int>{},
      'duration_ms': 0,
      'steps_ms': const <String, dynamic>{},
    });
  }

  Future<Map<String, dynamic>> fetchExcelImportSpec() async {
    if (!useMockData) {
      try {
        return Map<String, dynamic>.from(
          await _client.get('/expositions/import/spec') as Map,
        );
      } catch (_) {
        if (!enableOfflineFallback) rethrow;
      }
    }

    return _withDelay(<String, dynamic>{
      'accepted_extensions': const ['.xlsx'],
      'sheets': const <Map<String, dynamic>>[],
      'required_sheet_names': const <String>[],
      'optional_sheet_names': const <String>[],
      'notes': const <String>[],
    });
  }

  Future<Uint8List> downloadExcelImportTemplate() async {
    if (!useMockData) {
      return _client.getBytes('/expositions/import/template');
    }

    return _withDelay(Uint8List(0));
  }

  Future<OffBalanceModuleData> fetchHorsBilanModule() async {
    return _memoizeFuture<OffBalanceModuleData>(
      cached: _horsBilanFuture,
      getCache: () => _horsBilanFuture,
      setCache: (value) => _horsBilanFuture = value,
      load: () async {
        if (!useMockData) {
          // Le hors bilan suit le même découpage détail + synthèse.
          final itemsJson = await _client.get('/hors-bilan') as List<dynamic>;
          final summaryJson =
              await _client.get('/hors-bilan/summary') as Map<String, dynamic>;
          return OffBalanceModuleData(
            items: itemsJson
                .map(
                  (item) =>
                      OffBalanceRecord.fromJson(item as Map<String, dynamic>),
                )
                .toList(),
            summary: OffBalanceSummary.fromJson(summaryJson),
          );
        }

        // Les données mock sont converties avant agrégation pour rester proches du mode réel.
        final items =
            _offBalance.map((item) => OffBalanceRecord.fromJson(item)).toList();
        return _withDelay(
          OffBalanceModuleData(
            items: items,
            summary: _computeOffBalanceSummary(items),
          ),
        );
      },
    );
  }

  Future<void> createOffBalance(OffBalanceDraft draft) async {
    if (!useMockData) {
      await _client.post('/hors-bilan', {
        'analysis_date': draft.analysisDate.toIso8601String().split('T').first,
        'counterparty_id': draft.counterpartyId,
        'engagement_type': draft.engagementType,
        'nominal_amount': draft.nominalAmount,
        'comment': draft.comment,
      });
      _notifyPortfolioChanged();
      return;
    }

    // Quelques règles simples suffisent ici pour produire un scénario crédible côté UI.
    final ccf = _lookupCcf(draft.engagementType);
    final category = draft.counterpartyId.startsWith('CP002') ||
            draft.counterpartyId.startsWith('CP006')
        ? 'Banques'
        : 'Entreprises';
    final rating = category == 'Banques' ? 'A' : 'BBB';
    final ead = draft.nominalAmount * ccf;
    final rw = _lookupRiskWeight(category, rating);
    final id = 'HB${(_offBalance.length + 1).toString().padLeft(3, '0')}';
    _offBalance.add({
      'id': id,
      'analysis_date': draft.analysisDate.toIso8601String().split('T').first,
      'counterparty_id': draft.counterpartyId,
      'counterparty_name': draft.counterpartyId == 'CP002'
          ? 'Banque X'
          : 'Nouvelle contrepartie',
      'category': category,
      'rating': rating,
      'engagement_type': draft.engagementType,
      'nominal_amount': draft.nominalAmount,
      'ccf': ccf,
      'ead': ead,
      'risk_weight': rw,
      'rwa': ead * rw,
      'capital': ead * rw * 0.08,
      'comment': draft.comment,
    });
    _notifyPortfolioChanged();
  }

  Future<CrmModuleData> fetchCrmModule() async {
    return _memoizeFuture<CrmModuleData>(
      cached: _crmFuture,
      getCache: () => _crmFuture,
      setCache: (value) => _crmFuture = value,
      load: () async {
        if (!useMockData) {
          final json = await _client.get('/crm') as Map<String, dynamic>;
          return CrmModuleData.fromJson(json);
        }

        final items =
            _crmItems.map((item) => CrmRecord.fromJson(item)).toList();
        // Le premier scénario sert de highlight par défaut pour garder une bannière vivante.
        final highlight = items.isEmpty
            ? null
            : CrmHighlight(
                borrowerName: items.first.borrowerName,
                borrowerRw: items.first.borrowerRw,
                guarantorName: items.first.guarantorName,
                guarantorRw: items.first.guarantorRw,
                finalRw: items.first.finalRw,
                label: 'RWA reduit',
              );
        // Le résumé CRM consolide les effets avant/après et la couverture moyenne.
        final summary = CrmSummary(
          totalExpositions: items.fold<double>(
            0.0,
            (sum, item) => sum + item.grossAmount,
          ),
          totalEad: items.fold<double>(0.0, (sum, item) => sum + item.ead),
          totalRwaBefore: items.fold<double>(
            0.0,
            (sum, item) => sum + item.rwaBefore,
          ),
          totalRwaAfter: items.fold<double>(
            0.0,
            (sum, item) => sum + item.rwaAfter,
          ),
          totalCapitalAfter: items.fold<double>(
            0.0,
            (sum, item) => sum + item.capitalAfter,
          ),
          averageCoverage: items.isEmpty
              ? 0.0
              : items.fold<double>(
                    0.0,
                    (sum, item) => sum + item.coverageRatio,
                  ) /
                  items.length,
        );
        return _withDelay(
          CrmModuleData(highlight: highlight, items: items, summary: summary),
        );
      },
    );
  }

  Future<ReferentielsModuleData> fetchReferentiels() async {
    return _memoizeFuture<ReferentielsModuleData>(
      cached: _referentielsFuture,
      getCache: () => _referentielsFuture,
      setCache: (value) => _referentielsFuture = value,
      load: () async {
        if (!useMockData) {
          final json =
              await _client.get('/referentiels') as Map<String, dynamic>;
          return ReferentielsModuleData.fromJson(json);
        }

        // Les trois tables sont servies ensemble car elles alimentent tous les écrans métiers.
        return _withDelay(
          ReferentielsModuleData(
            riskWeights: _riskWeights
                .map((item) => RiskWeightRow.fromJson(item))
                .toList(),
            ccfTable: _ccfTable.map((item) => CcfRow.fromJson(item)).toList(),
            ratings: _ratings.map((item) => RatingRow.fromJson(item)).toList(),
          ),
        );
      },
    );
  }

  Future<ReportsModuleData> fetchReports() async {
    return _memoizeFuture<ReportsModuleData>(
      cached: _reportsFuture,
      getCache: () => _reportsFuture,
      setCache: (value) => _reportsFuture = value,
      load: () async {
        if (!useMockData) {
          final json = await _client.get('/rapports') as List<dynamic>;
          return ReportsModuleData(
            reports: json
                .map(
                  (item) => ReportRecord.fromJson(item as Map<String, dynamic>),
                )
                .toList(),
          );
        }

        return _withDelay(
          ReportsModuleData(
            reports:
                _reports.map((item) => ReportRecord.fromJson(item)).toList(),
          ),
        );
      },
    );
  }

  Future<void> generateReport(ReportDraft draft) async {
    if (!useMockData) {
      await _client.post('/rapports', draft.toJson());
      _reportsFuture = null;
      return;
    }

    // Le rapport mock fusionne les lignes bilan et hors bilan dans une même sortie.
    final lines = [
      ..._exposures.map(
        (item) => {
          'source': 'Exposition',
          'item_id': item['id'],
          'counterparty':
              (item['counterparty'] as Map<String, dynamic>)['name'],
          'amount': item['gross_amount'],
          'ead': item['ead'],
          'rwa': item['rwa'],
          'capital': item['capital'],
        },
      ),
      ..._offBalance.map(
        (item) => {
          'source': 'Hors bilan',
          'item_id': item['id'],
          'counterparty': item['counterparty_name'],
          'amount': item['nominal_amount'],
          'ead': item['ead'],
          'rwa': item['rwa'],
          'capital': item['capital'],
        },
      ),
    ];

    final id = 'RPT${(_reports.length + 1).toString().padLeft(3, '0')}';
    // Le rapport détaillé conserve toutes les lignes, la synthèse n'en garde qu'un extrait.
    _reports.insert(0, {
      'id': id,
      'created_at': DateTime.now().toIso8601String().split('T').first,
      'period': draft.period,
      'report_type': draft.reportType,
      'currency': draft.currency,
      'exposure_scope': draft.exposureScope,
      'include_category_chart': draft.includeCategoryChart,
      'include_rating_chart': draft.includeRatingChart,
      'exports': {'pdf': '/exports/$id.pdf', 'excel': '/exports/$id.xlsx'},
      'lines': draft.reportType == 'Detaille' ? lines : lines.take(5).toList(),
    });
    _reportsFuture = null;
  }

  DashboardSnapshot _buildMockDashboard() {
    // Les modèles sont d'abord reconstruits pour réutiliser les mêmes objets que l'UI.
    final exposureModels =
        _exposures.map((item) => ExposureRecord.fromJson(item)).toList();
    final valuationDate = _resolveValuationDate(exposureModels);
    // Les agrégats principaux servent ensuite à tous les KPI et graphiques.
    final gross = exposureModels.fold<double>(
      0.0,
      (sum, item) => sum + _dashboardGrossAmount(item),
    );
    final totalEad = exposureModels.fold<double>(
      0.0,
      (sum, item) => sum + item.ead,
    );
    final rwa = exposureModels.fold<double>(0.0, (sum, item) => sum + item.rwa);
    final capital = exposureModels.fold<double>(
      0.0,
      (sum, item) => sum + item.capital,
    );
    final coveredGross = exposureModels
        .where((item) => item.crmModeLabel != 'Aucune')
        .fold<double>(
          0.0,
          (sum, item) =>
              sum + (_dashboardGrossAmount(item) * item.crmCoveragePercent),
        );
    final residualRisk =
        (gross - coveredGross).clamp(0.0, double.infinity).toDouble();
    final coveredExposureRatio = gross == 0 ? 0.0 : coveredGross / gross;
    final defaultGross = exposureModels
        .where((item) => item.isDefaultLike)
        .fold<double>(0.0, (sum, item) => sum + _dashboardGrossAmount(item));
    final defaultRate = gross == 0 ? 0.0 : defaultGross / gross;
    final averageRiskRate = totalEad == 0 ? 0.0 : rwa / totalEad;
    final ownFunds = capital * 1.42;
    final solvencyRatio = rwa == 0 ? 0.0 : ownFunds / rwa;

    // Ces valeurs sont rangées par clé pour simplifier l'assemblage des cartes.
    final metricValues = <String, double>{
      'encours': gross,
      'risque_residuel': residualRisk,
      'rwa': rwa,
      'capital': capital,
      'taux_risque': averageRiskRate,
      'taux_defaut': defaultRate,
      'solvabilite': solvencyRatio,
      'crm': coveredExposureRatio,
    };

    return DashboardSnapshot(
      metrics: [
        _buildMetric(
          key: 'encours',
          label: 'Exposition totale brute',
          value: metricValues['encours']!,
          growthRate: 0.028,
        ),
        _buildMetric(
          key: 'risque_residuel',
          label: 'Risque residuel',
          value: metricValues['risque_residuel']!,
          growthRate: 0.0,
        ),
        _buildMetric(
          key: 'rwa',
          label: 'RWA total',
          value: metricValues['rwa']!,
          growthRate: 0.016,
        ),
        _buildMetric(
          key: 'capital',
          label: 'Capital minimum requis',
          value: metricValues['capital']!,
          growthRate: 0.012,
        ),
        _buildMetric(
          key: 'taux_risque',
          label: 'Taux de risque moyen',
          value: metricValues['taux_risque']!,
          growthRate: -0.008,
        ),
        _buildMetric(
          key: 'taux_defaut',
          label: 'Taux de defaut',
          value: metricValues['taux_defaut']!,
          growthRate: 0.0,
        ),
        _buildMetric(
          key: 'solvabilite',
          label: 'Ratio de solvabilite',
          value: metricValues['solvabilite']!,
          growthRate: 0.006,
        ),
        _buildMetric(
          key: 'crm',
          label: 'Expositions couvertes',
          value: metricValues['crm']!,
          growthRate: 0.018,
        ),
      ],
      // Chaque graphique du dashboard reçoit son propre jeu de données prêt à l'emploi.
      valuationDate: valuationDate,
      categoryDistribution: _buildDistributionByCategory(
        exposureModels,
        useGrossAmount: true,
      ),
      rwaCategoryDistribution: _buildDistributionByCategory(exposureModels),
      countryDistribution: _buildDistributionByCountry(exposureModels),
      crmDistribution: _buildDistributionByCrmType(exposureModels),
      ratingDistribution: _buildDistributionByRating(exposureModels),
      rwaProjection: _buildRwaProjection(exposureModels, valuationDate),
      portfolioOverview: exposureModels
          .map(
            (item) => PortfolioRow(
              id: item.id,
              analysisDate: item.analysisDate,
              counterparty: item.counterparty.name,
              country: item.counterparty.country,
              category: item.categoryLabel,
              rating: _portfolioDisplayRating(item.counterparty.rating),
              crmType: item.crmModeLabel,
              grossAmount: _dashboardGrossAmount(item),
              onBalanceExposureAmount: _dashboardOnBalanceAmount(item),
              offBalanceExposureAmount: _dashboardOffBalanceAmount(item),
              ead: item.ead,
              rwa: item.rwa,
              capital: item.capital,
            ),
          )
          .toList(),
    );
  }

  double _dashboardOnBalanceAmount(ExposureRecord exposure) {
    return exposure.onBalanceExposureAmount ?? exposure.grossAmount;
  }

  double _dashboardOffBalanceAmount(ExposureRecord exposure) {
    return exposure.offBalanceExposureAmount ?? 0.0;
  }

  double _dashboardGrossAmount(ExposureRecord exposure) {
    final hasBreakdown = exposure.onBalanceExposureAmount != null ||
        exposure.offBalanceExposureAmount != null;
    if (hasBreakdown) {
      return _dashboardOnBalanceAmount(exposure) +
          _dashboardOffBalanceAmount(exposure);
    }
    final loanTotal = exposure.loanTotalAmount;
    if (loanTotal != null && loanTotal > 0) {
      return loanTotal;
    }
    return exposure.grossAmount;
  }

  String _portfolioDisplayRating(String rating) {
    final trimmed = rating.trim();
    if (trimmed.isEmpty) {
      return 'Non noté';
    }
    if (prudentialRatings.contains(trimmed)) {
      return trimmed;
    }
    final normalized = trimmed
        .toUpperCase()
        .replaceAll('É', 'E')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized == 'NON NOTE' || normalized == 'NON NOTÉ') {
      return 'Non noté';
    }
    return 'Non noté';
  }

  ExposureSummary _computeExposureSummary(List<ExposureRecord> exposures) {
    // Le résumé expositions additionne simplement les grandeurs déjà calculées par ligne.
    return ExposureSummary(
      totalExpositions: exposures.fold<double>(
        0.0,
        (sum, item) => sum + _dashboardGrossAmount(item),
      ),
      totalEad: exposures.fold<double>(0.0, (sum, item) => sum + item.ead),
      totalRwa: exposures.fold<double>(0.0, (sum, item) => sum + item.rwa),
      totalCapital: exposures.fold<double>(
        0.0,
        (sum, item) => sum + item.capital,
      ),
    );
  }

  Map<String, dynamic> _buildExposureMapFromDraft(
    ExposureDraft draft,
    String id,
  ) {
    final metrics = computeDraftMetrics(draft);
    return {
      'id': id,
      'analysis_date': draft.analysisDate.toIso8601String().split('T').first,
      'grant_date': draft.grantDate?.toIso8601String().split('T').first,
      'maturity_date': draft.maturityDate?.toIso8601String().split('T').first,
      'counterparty': {
        'id': id,
        'name': draft.counterpartyName,
        'country': draft.country,
        'country_rating': draft.countryRating,
        'category': draft.category.prudentialLabel,
        'rating': draft.rating,
      },
      'gross_amount': draft.grossAmount,
      'loan_total_amount': draft.loanTotalAmount,
      'on_balance_exposure_amount': draft.onBalanceExposureAmount,
      'off_balance_exposure_amount': draft.offBalanceExposureAmount,
      'currency': draft.currency,
      'status': draft.status,
      'sovereign_special_case': draft.sovereignSpecialCase,
      'sovereign_preferential_zero_weight':
          draft.sovereignPreferentialZeroWeight,
      'sovereign_oce_established': draft.sovereignOceEstablished,
      'sovereign_oce_note': draft.sovereignOceNote,
      'public_body_uemoa_fcfa_case': draft.publicBodyUemoaFcfaCase,
      'public_body_non_public_activity':
          draft.publicBodyFinancesNonPublicActivity,
      'bmd_high_quality_case': draft.bmdHighQualityCase,
      'bmd_uemoa_fcfa_case': draft.bmdUemoaFcfaCase,
      'bmd_uemoa_criteria_satisfied': draft.bmdUemoaCriteriaSatisfied,
      'bmd_listed_institution_fcfa_case': draft.bmdListedInstitutionFcfaCase,
      'bank_institution_case': draft.bankInstitutionCase,
      'other_asset_type': draft.otherAssetType,
      'off_balance_risk_level': draft.offBalanceRiskLevel,
      'retail_eligibility_criteria_satisfied':
          draft.retailEligibilityCriteriaSatisfied,
      'residential_mortgage_eligible': draft.residentialMortgageEligible,
      'commercial_real_estate_eligible': draft.commercialRealEstateEligible,
      'defaulted_exposure_initial_risk_weight':
          draft.defaultedExposureInitialRiskWeight,
      'defaulted_exposure_residential_mortgage_in_default':
          draft.defaultedExposureResidentialMortgageInDefault,
      'defaulted_exposure_provision_at_least_twenty_percent':
          draft.defaultedExposureProvisionAtLeastTwentyPercent,
      'enterprise_exceeds_bceao_degradation_threshold':
          draft.enterpriseExceedsBceaoDegradationThreshold,
      'enterprise_prudential_procedure': draft.enterprisePrudentialProcedure,
      'enterprise_investment_firm_without_banking_law':
          draft.enterpriseInvestmentFirmWithoutBankingLaw,
      'crm_type': draft.backendCrmType,
      'crm_coverage_percent': _effectiveCrmCoverage(draft),
      'crm_details': draft.crmDetailsJson,
      'original_rw': metrics.originalRw,
      'final_rw': metrics.finalRw,
      'ead': metrics.ead,
      'rwa': metrics.rwa,
      'capital': metrics.capital,
      'comment': draft.comment,
    };
  }

  double _effectiveCrmCoverage(ExposureDraft draft) {
    if (draft.crmMode == 'CRM financee') {
      return computeFinancedCrmSnapshot(draft).coveragePercent;
    }
    if (draft.crmMode == 'CRM non financee') {
      return draft.crmCoveragePercent.clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  String _nextExposureId() {
    return _nextExposureIdFromIdentifiers(
      _exposures.map((item) => (item['id'] as String?) ?? ''),
    );
  }

  String _nextExposureIdFromIdentifiers(Iterable<String> identifiers) {
    var max = 0;
    for (final identifier in identifiers) {
      if (!identifier.startsWith('CP')) {
        continue;
      }
      final parsed = int.tryParse(identifier.substring(2));
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return 'CP${(max + 1).toString().padLeft(3, '0')}';
  }

  Map<String, String> _reindexMockExposureIds() {
    final orderedIds = _exposures
        .map((item) => (item['id'] ?? '').toString())
        .where((identifier) {
      if (!identifier.startsWith('CP')) {
        return false;
      }
      return int.tryParse(identifier.substring(2)) != null;
    }).toList(growable: false)
      ..sort((left, right) {
        final leftIndex = int.parse(left.substring(2));
        final rightIndex = int.parse(right.substring(2));
        return leftIndex.compareTo(rightIndex);
      });

    final renumberedIds = <String, String>{};
    for (var index = 0; index < orderedIds.length; index++) {
      final currentId = orderedIds[index];
      final nextId = 'CP${(index + 1).toString().padLeft(3, '0')}';
      if (currentId != nextId) {
        renumberedIds[currentId] = nextId;
      }
    }
    if (renumberedIds.isEmpty) {
      return renumberedIds;
    }

    for (final item in _exposures) {
      final currentId = (item['id'] ?? '').toString();
      final nextId = renumberedIds[currentId];
      if (nextId == null) {
        continue;
      }
      item['id'] = nextId;
      final counterparty = item['counterparty'];
      if (counterparty is Map<String, dynamic>) {
        counterparty['id'] = nextId;
      }
    }

    for (final item in _offBalance) {
      final currentId = (item['counterparty_id'] ?? '').toString();
      final nextId = renumberedIds[currentId];
      if (nextId != null) {
        item['counterparty_id'] = nextId;
      }
    }

    for (final item in _crmItems) {
      final currentId = (item['exposure_id'] ?? '').toString();
      final nextId = renumberedIds[currentId];
      if (nextId != null) {
        item['exposure_id'] = nextId;
      }
    }

    return renumberedIds;
  }

  OffBalanceSummary _computeOffBalanceSummary(List<OffBalanceRecord> items) {
    // Le résumé hors bilan reprend la même logique, avec le nominal comme encours brut.
    return OffBalanceSummary(
      totalEngagements: items.fold<double>(
        0.0,
        (sum, item) => sum + item.nominalAmount,
      ),
      totalEad: items.fold<double>(0.0, (sum, item) => sum + item.ead),
      totalRwa: items.fold<double>(0.0, (sum, item) => sum + item.rwa),
      totalCapital: items.fold<double>(0.0, (sum, item) => sum + item.capital),
    );
  }

  List<DistributionEntry> _buildDistributionByCategory(
    List<ExposureRecord> exposures, {
    bool useGrossAmount = false,
  }) {
    final totals = <String, double>{};
    final global = exposures.fold<double>(
      0.0,
      (sum, item) =>
          sum + (useGrossAmount ? _dashboardGrossAmount(item) : item.rwa),
    );
    for (final exposure in exposures) {
      // Chaque exposition alimente le seau de sa catégorie prudentielle.
      totals.update(
        exposure.categoryLabel,
        (value) =>
            value +
            (useGrossAmount ? _dashboardGrossAmount(exposure) : exposure.rwa),
        ifAbsent: () =>
            useGrossAmount ? _dashboardGrossAmount(exposure) : exposure.rwa,
      );
    }
    return totals.entries
        .map(
          (entry) => DistributionEntry(
            label: entry.key,
            amount: entry.value,
            percentage: global == 0 ? 0.0 : entry.value / global,
          ),
        )
        .toList();
  }

  List<DistributionEntry> _buildDistributionByCountry(
    List<ExposureRecord> exposures,
  ) {
    final totals = <String, double>{};
    final global = exposures.fold<double>(0.0, (sum, item) => sum + item.rwa);
    for (final exposure in exposures) {
      // La concentration géographique se lit ici à partir du RWA par pays.
      final country = canonicalCountryName(
        exposure.counterparty.country,
        fallback: exposure.counterparty.country,
      );
      totals.update(
        country,
        (value) => value + exposure.rwa,
        ifAbsent: () => exposure.rwa,
      );
    }

    final entries = totals.entries
        .map(
          (entry) => DistributionEntry(
            label: entry.key,
            amount: entry.value,
            percentage: global == 0 ? 0.0 : entry.value / global,
          ),
        )
        .toList()
      // Les pays sont ensuite triés pour ne conserver que les plus contributeurs.
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return entries.take(5).toList();
  }

  List<DistributionEntry> _buildDistributionByCrmType(
    List<ExposureRecord> exposures,
  ) {
    final totals = <String, double>{};
    final global = exposures.fold<double>(
      0.0,
      (sum, item) => sum + _dashboardGrossAmount(item),
    );

    for (final exposure in exposures) {
      // Le CRM est mesuré sur l'encours couvert et non sur le seul RWA.
      final label = _normalizeCrmType(exposure.crmModeLabel);
      totals.update(
        label,
        (value) => value + _dashboardGrossAmount(exposure),
        ifAbsent: () => _dashboardGrossAmount(exposure),
      );
    }

    return totals.entries
        .map(
          (entry) => DistributionEntry(
            label: entry.key,
            amount: entry.value,
            percentage: global == 0 ? 0.0 : entry.value / global,
          ),
        )
        .toList();
  }

  List<DistributionEntry> _buildDistributionByRating(
    List<ExposureRecord> exposures,
  ) {
    final totals = <String, double>{};
    final global = exposures.fold<double>(
      0.0,
      (sum, item) => sum + _dashboardGrossAmount(item),
    );
    for (final exposure in exposures) {
      // La répartition notation s'appuie sur la notation de la contrepartie porteuse.
      totals.update(
        exposure.ratingLabel,
        (value) => value + _dashboardGrossAmount(exposure),
        ifAbsent: () => _dashboardGrossAmount(exposure),
      );
    }
    return totals.entries
        .map(
          (entry) => DistributionEntry(
            label: entry.key,
            amount: entry.value,
            percentage: global == 0 ? 0.0 : entry.value / global,
          ),
        )
        .toList();
  }

  List<DashboardProjectionPoint> _buildRwaProjection(
    List<ExposureRecord> exposures,
    DateTime valuationDate,
  ) {
    final labels = <String>[
      'Janv.',
      'Fevr.',
      'Mars',
      'Avr.',
      'Mai',
      'Juin',
      'Juil.',
      'Aout',
      'Sept.',
      'Oct.',
      'Nov.',
      'Dec.',
    ];

    final projection = <DashboardProjectionPoint>[];
    for (var monthIndex = 0; monthIndex < 12; monthIndex++) {
      final pointDate = DateTime(
        valuationDate.year,
        valuationDate.month + monthIndex + 1,
        1,
      );
      var projectedRwa = 0.0;

      for (var index = 0; index < exposures.length; index++) {
        final exposure = exposures[index];
        // Chaque catégorie reçoit un rythme d'amortissement simple pour matérialiser la décroissance.
        final pace = _amortizationPaceForCategory(exposure.categoryLabel) +
            (index % 3) * 0.006;
        final remainingFactor =
            (1 - (pace * monthIndex)).clamp(0.42, 1.0).toDouble();
        projectedRwa += exposure.rwa * remainingFactor;
      }

      projection.add(
        DashboardProjectionPoint(
          label: labels[pointDate.month - 1],
          value: projectedRwa,
        ),
      );
    }

    return projection;
  }

  DashboardMetric _buildMetric({
    required String key,
    required String label,
    required double value,
    required double growthRate,
  }) {
    // La variation affichée sur les cartes découle directement de la mini-série tendance.
    final trend = _buildMetricTrend(value, growthRate);
    final first = trend.first;
    final last = trend.last;
    final delta = first == 0 ? 0.0 : ((last - first) / first);
    final prefix = delta >= 0 ? '+' : '';
    final variation = '$prefix${(delta * 100).toStringAsFixed(1)}% M/M';

    return DashboardMetric(
      key: key,
      label: label,
      value: value,
      variation: variation,
      trend: trend,
    );
  }

  List<double> _buildMetricTrend(double value, double growthRate) {
    final base = value == 0 ? 1.0 : value;
    return List<double>.generate(7, (index) {
      // Une légère oscillation casse le rendu trop linéaire des sparklines.
      final position = index / 6;
      final oscillation = 1 + (((index % 2 == 0) ? -1 : 1) * 0.018);
      final factor = (1 - growthRate) + (growthRate * position);
      return base * factor * oscillation;
    });
  }

  DateTime _resolveValuationDate(List<ExposureRecord> exposures) {
    // La date de valorisation prend le point le plus récent présent dans les jeux de données.
    final dates = <DateTime>[...exposures.map((item) => item.analysisDate)];

    if (dates.isEmpty) {
      return DateTime.now();
    }

    dates.sort((a, b) => a.compareTo(b));
    return dates.last;
  }

  String _normalizeCrmType(String crmType) {
    final normalized = crmType.toLowerCase();
    // Les différentes formulations UI sont ramenées à trois familles CRM.
    if (normalized.contains('aucune') || normalized.contains('sans crm')) {
      return 'Aucune';
    }
    if (normalized.contains('cash') ||
        normalized.contains('financee') ||
        normalized.contains('financée')) {
      return 'CRM financee';
    }
    return 'CRM non financee';
  }

  double _amortizationPaceForCategory(String category) {
    final normalized = category
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e');
    if (normalized.contains('souverain')) {
      return 0.014;
    }
    if (normalized.contains('institution')) {
      return 0.022;
    }
    if (normalized.contains('entreprise')) {
      return 0.028;
    }
    if (normalized.contains('detail')) {
      return 0.024;
    }
    return 0.02;
  }

  double _lookupRiskWeight(String category, String rating) {
    // La notation libre est d'abord rabattue vers le bucket prudentiel attendu.
    final bucket = _bucketizeRating(rating);
    final match = _riskWeights.firstWhere(
      (item) => item['segment'] == category && item['rating'] == bucket,
      orElse: () => {'risk_weight': 1.0},
    );
    return (match['risk_weight'] as num).toDouble();
  }

  double _lookupCcf(String engagementType) {
    // Un CCF par défaut à 100 % évite de bloquer la création mock si la table est incomplète.
    final match = _ccfTable.firstWhere(
      (item) => item['engagement_type'] == engagementType,
      orElse: () => {'ccf': 1.0},
    );
    return (match['ccf'] as num).toDouble();
  }

  String _bucketizeRating(String rating) {
    final normalized = rating.toUpperCase();
    // Cette normalisation aligne les notations utilisateur avec les référentiels RW.
    if (['AAA', 'AA+', 'AA', 'AA-'].contains(normalized)) {
      return 'AAA/AA';
    }
    if (['A+', 'A', 'A-'].contains(normalized)) {
      return 'A';
    }
    if (['BBB+', 'BBB', 'BBB-'].contains(normalized)) {
      return 'BBB';
    }
    if (['BB+', 'BB', 'BB-', 'B+', 'B', 'B-'].contains(normalized)) {
      return 'BB/B';
    }
    return 'Non noté';
  }

  Future<T> _withDelay<T>(T value) {
    // Ce petit délai simule une latence réseau et évite un rendu trop brutal en mode mock.
    return Future<T>.delayed(const Duration(milliseconds: 220), () => value);
  }
}
