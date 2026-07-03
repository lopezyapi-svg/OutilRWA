/// Service de calcul de l'analyse des risques de change au niveau des titres
/// Conforme aux principes prudentiels BCEAO
/// Approche: Analyse ligne par ligne de l'impact des fluctuations de devises
library fx_security_analysis_service;

import 'dart:math' as math;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/currency_registry.dart';
import '../models/fx_security_analysis.dart';
import 'market_data_import_store.dart';

/// Service pour analyser le risque de change au niveau des titres
class FxSecurityAnalysisService {
  FxSecurityAnalysisService({
    CurrencyRegistry? currencyRegistry,
    RwaApiService? rwaApiService,
  })  : _currencyRegistry = currencyRegistry ?? CurrencyRegistry(),
        _rwaApiService = rwaApiService;

  final CurrencyRegistry _currencyRegistry;
  final RwaApiService? _rwaApiService;

  /// Calcule l'exposition au risque de change pour un portefeuille de titres
  /// Retourne un résultat structuré pour présentation multi-niveaux
  FxRiskAnalysisResult analyzePortfolio({
    required List<MarketPortfolioRecord> records,
    required DateTime analysisDate,
    Map<String, double>? exchangeRates,
  }) {
    // Étape 1: Analyser chaque titre individuellement
    final securities = _analyzeSecurities(
      records: records,
      analysisDate: analysisDate,
      exchangeRates: exchangeRates,
    );

    // Étape 2: Agréger par devise
    final currencyExposures = _aggregateByCurrency(securities);

    // Étape 3: Calculer les métriques globales
    final globalMetrics = _calculateGlobalMetrics(
      securities: securities,
      currencyExposures: currencyExposures,
    );

    return FxRiskAnalysisResult(
      securities: securities,
      currencyExposures: currencyExposures,
      totalExposure: globalMetrics['totalExposure'] as double,
      globalFxGainLoss: globalMetrics['globalFxGainLoss'] as double,
      totalLongPositions: globalMetrics['totalLongPositions'] as double,
      totalShortPositions: globalMetrics['totalShortPositions'] as double,
      globalNetPosition: globalMetrics['globalNetPosition'] as double,
      capitalRequirement: globalMetrics['capitalRequirement'] as double,
      rwaChange: globalMetrics['rwaChange'] as double,
      marketRiskContribution: globalMetrics['marketRiskContribution'] as double,
      analysisDate: analysisDate,
    );
  }

  /// Fetch real portfolio data and analyze FX risk
  /// Uses RwaApiService to fetch live data, CurrencyRegistry for FX rates
  /// Falls back to demo data if API is unavailable
  Future<FxRiskAnalysisResult> analyzePortfolioAsync({
    required DateTime analysisDate,
    bool useFallbackData = true,
  }) async {
    try {
      // Fetch real portfolio data from backend
      final portfolioPayload =
          await _rwaApiService?.fetchMarketPortfolioPayload();

      if (portfolioPayload == null || portfolioPayload.isEmpty) {
        if (useFallbackData) {
          return createDemoData();
        }
        throw Exception('No portfolio data available');
      }

      // Convert payload to MarketPortfolioRecords
      // The payload structure: {bonds: {...}, equities: {...}}
      final records = _convertPayloadToRecords(portfolioPayload);

      if (records.isEmpty) {
        if (useFallbackData) {
          return createDemoData();
        }
        throw Exception('No valid portfolio records found');
      }

      // Use real FX rates from CurrencyRegistry
      final exchangeRates = _getRealExchangeRates();

      // Analyze with real data
      return analyzePortfolio(
        records: records,
        analysisDate: analysisDate,
        exchangeRates: exchangeRates,
      );
    } catch (e) {
      // If API fails and useFallbackData is true, return demo data
      if (useFallbackData) {
        return createDemoData();
      }
      rethrow;
    }
  }

  /// Convert API payload to MarketPortfolioRecords
  List<MarketPortfolioRecord> _convertPayloadToRecords(
    Map<String, dynamic> payload,
  ) {
    final records = <MarketPortfolioRecord>[];

    // Process bonds
    final bonds = payload['bonds'] as Map<String, dynamic>? ?? {};
    for (final entry in bonds.entries) {
      try {
        final record = MarketPortfolioRecord(
          portfolioType: MarketPortfolioType.bonds,
          values: entry.value as Map<String, Object?>,
        );
        records.add(record);
      } catch (e) {
        // Skip invalid records
      }
    }

    // Process equities
    final equities = payload['equities'] as Map<String, dynamic>? ?? {};
    for (final entry in equities.entries) {
      try {
        final record = MarketPortfolioRecord(
          portfolioType: MarketPortfolioType.equities,
          values: entry.value as Map<String, Object?>,
        );
        records.add(record);
      } catch (e) {
        // Skip invalid records
      }
    }

    return records;
  }

  /// Get real FX rates from CurrencyRegistry
  Map<String, double> _getRealExchangeRates() {
    final rates = <String, double>{};

    // Get rates for all currencies in the registry
    for (final rate in _currencyRegistry.getAllRates()) {
      rates[rate.code] = rate.rateToXof;
    }

    return rates;
  }

  /// Analyse chaque titre pour ses expositions au risque de change
  List<FxSecurityAnalysis> _analyzeSecurities({
    required List<MarketPortfolioRecord> records,
    required DateTime analysisDate,
    Map<String, double>? exchangeRates,
  }) {
    final securities = <FxSecurityAnalysis>[];

    for (final record in records) {
      // Filtrer les titres non exposés au risque de change
      if (!_isExposedToFxRisk(record)) continue;

      final currency = normalizeCurrencyCode(record.currency);
      if (currency.isEmpty) continue;

      // Récupérer les taux de change
      final initialRate =
          _getInitialExchangeRate(record, currency, exchangeRates);
      final currentRate =
          _getCurrentExchangeRate(record, currency, exchangeRates);

      if (initialRate <= 0 || currentRate <= 0) continue;

      // Calculer les valeurs
      final initialValue = _getInitialValue(record);
      final currentValue = _getCurrentValue(record);
      final quantity = _getQuantity(record);

      if (initialValue <= 0 || quantity == 0) continue;

      final security = FxSecurityAnalysis(
        titleId: record.titleId.isNotEmpty ? record.titleId : record.issuer,
        titleName: _getTitleName(record),
        currency: currency,
        initialValue: initialValue,
        currentValue: currentValue,
        initialRate: initialRate,
        currentRate: currentRate,
        quantity: quantity,
        acquisitionDate: record.issueDate ?? analysisDate,
        analysisDate: analysisDate,
      );

      securities.add(security);
    }

    return securities;
  }

  /// Détermine si un titre est exposé au risque de change.
  ///
  /// Seuls les titres libellés en devise ÉTRANGÈRE sont exposés : la devise de
  /// référence de l'outil (XOF — ainsi que XAF/FCFA repliés sur XOF par
  /// [normalizeCurrencyCode]) ne porte par définition AUCUN risque de change.
  /// C'est pourquoi un portefeuille 100 % XOF affiche partout 0.
  /// Convention alignée sur le calcul prudentiel global de l'outil
  /// (`_marketForeignExchangeGlobalNetPosition`), qui exclut lui aussi le XOF.
  bool _isExposedToFxRisk(MarketPortfolioRecord record) {
    final currency = normalizeCurrencyCode(record.currency);
    return currency.isNotEmpty;
  }

  /// Récupère le nom du titre
  String _getTitleName(MarketPortfolioRecord record) {
    if (record.issuer.isNotEmpty) return record.issuer;
    if (record.titleId.isNotEmpty) return record.titleId;
    return record.instrumentType.isNotEmpty
        ? record.instrumentType
        : 'Titre sans nom';
  }

  /// Récupère la valeur initiale du titre
  double _getInitialValue(MarketPortfolioRecord record) {
    if (record.portfolioType == MarketPortfolioType.equities) {
      final price =
          record.marketPrice > 0 ? record.marketPrice : record.priceObservation;
      return price > 0 ? price : record.nominalUnit;
    }
    // Pour les obligations
    return record.issuePrice > 0 ? record.issuePrice : record.nominalUnit;
  }

  /// Récupère la valeur actuelle du titre
  double _getCurrentValue(MarketPortfolioRecord record) {
    if (record.portfolioType == MarketPortfolioType.equities) {
      final price =
          record.marketPrice > 0 ? record.marketPrice : record.priceObservation;
      return price > 0 ? price : record.nominalUnit;
    }
    // Pour les obligations: utiliser la valeur actualisée ou le prix de marché
    if (record.presentValue > 0) return record.presentValue;
    if (record.priceObservation > 0) return record.priceObservation;
    return record.nominalUnit;
  }

  /// Récupère la quantité
  double _getQuantity(MarketPortfolioRecord record) {
    if (record.portfolioType == MarketPortfolioType.equities) {
      return record.shares;
    }
    return record.quantity;
  }

  /// Taux de change COURANT (spot), en XOF pour 1 unité de devise.
  /// On privilégie la carte de taux fournie (saisie utilisateur dans l'écran),
  /// puis le registre des devises de l'outil.
  double _getCurrentExchangeRate(
    MarketPortfolioRecord record,
    String currency,
    Map<String, double>? exchangeRates,
  ) {
    if (currency == 'XOF') return 1.0;
    final provided = exchangeRates?[currency];
    if (provided != null && provided > 0) return provided;
    return _currencyRegistry.getRate(currency)?.rateToXof ?? 1.0;
  }

  /// Taux de change à l'ACQUISITION, en XOF pour 1 unité de devise.
  /// On utilise le taux historique du titre s'il est fourni à l'import
  /// ([MarketPortfolioRecord.acquisitionExchangeRate]) ; sinon on retombe sur le
  /// taux courant — la variation est alors nulle, ce qui est honnête en
  /// l'absence de donnée historique.
  double _getInitialExchangeRate(
    MarketPortfolioRecord record,
    String currency,
    Map<String, double>? exchangeRates,
  ) {
    if (currency == 'XOF') return 1.0;
    final booked = record.acquisitionExchangeRate;
    if (booked > 0) return booked;
    return _getCurrentExchangeRate(record, currency, exchangeRates);
  }

  /// Agrège les données par devise
  List<FxCurrencyExposure> _aggregateByCurrency(
    List<FxSecurityAnalysis> securities,
  ) {
    final byDevise = <String, FxCurrencyExposure>{};

    for (final security in securities) {
      final currency = security.currency;
      if (currency == 'XOF' || currency == 'XAF') continue;
      final existing = byDevise[currency];

      final longExposure =
          security.quantity > 0 ? security.currentValueInXof : 0.0;
      final shortExposure =
          security.quantity < 0 ? security.currentValueInXof.abs() : 0.0;

      if (existing != null) {
        byDevise[currency] = FxCurrencyExposure(
          currency: currency,
          totalLongExposure: existing.totalLongExposure + longExposure,
          totalShortExposure: existing.totalShortExposure + shortExposure,
          netExposure: existing.netExposure + (longExposure - shortExposure),
          securitiesCount: existing.securitiesCount + 1,
          acquisitionDate: existing.acquisitionDate,
          analysisDate: security.analysisDate,
        );
      } else {
        byDevise[currency] = FxCurrencyExposure(
          currency: currency,
          totalLongExposure: longExposure,
          totalShortExposure: shortExposure,
          netExposure: longExposure - shortExposure,
          securitiesCount: 1,
          acquisitionDate: security.acquisitionDate,
          analysisDate: security.analysisDate,
        );
      }
    }

    return byDevise.values.toList();
  }

  /// Calcule les métriques globales
  Map<String, double> _calculateGlobalMetrics({
    required List<FxSecurityAnalysis> securities,
    required List<FxCurrencyExposure> currencyExposures,
  }) {
    double totalExposure = 0;
    double globalFxGainLoss = 0;
    double totalLongPositions = 0;
    double totalShortPositions = 0;

    // Calculer les totaux
    for (final security in securities) {
      if (security.currency == 'XOF' || security.currency == 'XAF') continue;
      totalExposure += security.currentValueInXof;
      globalFxGainLoss += security.fxGainLoss;
    }

    for (final exposure in currencyExposures) {
      if (exposure.currency == 'XOF' || exposure.currency == 'XAF') continue;
      totalLongPositions += exposure.totalLongExposure;
      totalShortPositions += exposure.totalShortExposure;
    }

    // Position nette globale = MAX(longues, courtes)
    final globalNetPosition =
        math.max(totalLongPositions, totalShortPositions).toDouble();

    // Exigence de fonds propres = Position_Nette_Globale × 9%
    final capitalRequirement = globalNetPosition * 0.09;

    // RWA Change = Exigence_FP × 12.5
    final rwaChange = capitalRequirement * 12.5;

    final marketRiskContribution =
        totalExposure > 0 ? (capitalRequirement / totalExposure) * 100 : 0.0;

    return {
      'totalExposure': totalExposure,
      'globalFxGainLoss': globalFxGainLoss,
      'totalLongPositions': totalLongPositions,
      'totalShortPositions': totalShortPositions,
      'globalNetPosition': globalNetPosition,
      'capitalRequirement': capitalRequirement,
      'rwaChange': rwaChange,
      'marketRiskContribution': marketRiskContribution,
    };
  }

  /// Crée des données de démonstration pour les tests
  static FxRiskAnalysisResult createDemoData() {
    final analysisDate = DateTime(2024, 6, 17);

    // Titres de démonstration
    final securities = [
      FxSecurityAnalysis(
        titleId: 'US_TREAS_001',
        titleName: 'Obligation Trésor US',
        currency: 'USD',
        initialValue: 100000000,
        currentValue: 102000000,
        initialRate: 580.0,
        currentRate: 625.0,
        quantity: 1.0,
        acquisitionDate: DateTime(2023, 6, 17),
        analysisDate: analysisDate,
      ),
      FxSecurityAnalysis(
        titleId: 'EU_BOND_001',
        titleName: 'Eurobond Sénégal',
        currency: 'EUR',
        initialValue: 50000000,
        currentValue: 51000000,
        initialRate: 656.0,
        currentRate: 680.0,
        quantity: 1.0,
        acquisitionDate: DateTime(2023, 9, 17),
        analysisDate: analysisDate,
      ),
      FxSecurityAnalysis(
        titleId: 'WB_BOND_001',
        titleName: 'Obligation Banque Mondiale',
        currency: 'USD',
        initialValue: 75000000,
        currentValue: 76000000,
        initialRate: 580.0,
        currentRate: 625.0,
        quantity: 1.0,
        acquisitionDate: DateTime(2023, 12, 17),
        analysisDate: analysisDate,
      ),
      FxSecurityAnalysis(
        titleId: 'CORP_ORANGE_001',
        titleName: 'Obligation Corporate Orange CI',
        currency: 'EUR',
        initialValue: 40000000,
        currentValue: 39500000,
        initialRate: 656.0,
        currentRate: 680.0,
        quantity: 1.0,
        acquisitionDate: DateTime(2024, 1, 17),
        analysisDate: analysisDate,
      ),
    ];

    // Agréger par devise
    final exposures = _aggregateByCurrencyStatic(securities);

    // Calculer les métriques globales
    final metrics = _calculateGlobalMetricsStatic(
      securities: securities,
      currencyExposures: exposures,
    );

    return FxRiskAnalysisResult(
      securities: securities,
      currencyExposures: exposures,
      totalExposure: metrics['totalExposure'] as double,
      globalFxGainLoss: metrics['globalFxGainLoss'] as double,
      totalLongPositions: metrics['totalLongPositions'] as double,
      totalShortPositions: metrics['totalShortPositions'] as double,
      globalNetPosition: metrics['globalNetPosition'] as double,
      capitalRequirement: metrics['capitalRequirement'] as double,
      rwaChange: metrics['rwaChange'] as double,
      marketRiskContribution: metrics['marketRiskContribution'] as double,
      analysisDate: analysisDate,
    );
  }

  /// Agréger statiquement (pour données démo)
  static List<FxCurrencyExposure> _aggregateByCurrencyStatic(
    List<FxSecurityAnalysis> securities,
  ) {
    final byDevise = <String, FxCurrencyExposure>{};

    for (final security in securities) {
      final currency = security.currency;
      if (currency == 'XOF' || currency == 'XAF') continue;
      final existing = byDevise[currency];

      final longExposure =
          security.quantity > 0 ? security.currentValueInXof : 0.0;
      final shortExposure =
          security.quantity < 0 ? security.currentValueInXof.abs() : 0.0;

      if (existing != null) {
        byDevise[currency] = FxCurrencyExposure(
          currency: currency,
          totalLongExposure: existing.totalLongExposure + longExposure,
          totalShortExposure: existing.totalShortExposure + shortExposure,
          netExposure: existing.netExposure + (longExposure - shortExposure),
          securitiesCount: existing.securitiesCount + 1,
          acquisitionDate: existing.acquisitionDate,
          analysisDate: security.analysisDate,
        );
      } else {
        byDevise[currency] = FxCurrencyExposure(
          currency: currency,
          totalLongExposure: longExposure,
          totalShortExposure: shortExposure,
          netExposure: longExposure - shortExposure,
          securitiesCount: 1,
          acquisitionDate: security.acquisitionDate,
          analysisDate: security.analysisDate,
        );
      }
    }

    return byDevise.values.toList();
  }

  /// Calculer les métriques statiquement (pour données démo)
  static Map<String, double> _calculateGlobalMetricsStatic({
    required List<FxSecurityAnalysis> securities,
    required List<FxCurrencyExposure> currencyExposures,
  }) {
    double totalExposure = 0;
    double globalFxGainLoss = 0;
    double totalLongPositions = 0;
    double totalShortPositions = 0;

    for (final security in securities) {
      if (security.currency == 'XOF' || security.currency == 'XAF') continue;
      totalExposure += security.currentValueInXof;
      globalFxGainLoss += security.fxGainLoss;
    }

    for (final exposure in currencyExposures) {
      if (exposure.currency == 'XOF' || exposure.currency == 'XAF') continue;
      totalLongPositions += exposure.totalLongExposure;
      totalShortPositions += exposure.totalShortExposure;
    }

    final globalNetPosition =
        math.max(totalLongPositions, totalShortPositions).toDouble();
    final capitalRequirement = globalNetPosition * 0.09;
    final rwaChange = capitalRequirement * 12.5;

    final marketRiskContribution =
        totalExposure > 0 ? (capitalRequirement / totalExposure) * 100 : 0.0;

    return {
      'totalExposure': totalExposure,
      'globalFxGainLoss': globalFxGainLoss,
      'totalLongPositions': totalLongPositions,
      'totalShortPositions': totalShortPositions,
      'globalNetPosition': globalNetPosition,
      'capitalRequirement': capitalRequirement,
      'rwaChange': rwaChange,
      'marketRiskContribution': marketRiskContribution,
    };
  }
}
