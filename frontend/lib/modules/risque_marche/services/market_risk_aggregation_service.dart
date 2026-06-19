/// Service d'agrégation des KPI risque de marché
/// Combine Taux, Change, Actions pour calculer RWA Marché Total et contributions

import '../services/foreign_exchange_risk_service.dart';
import '../services/market_data_import_store.dart';

/// Résultat agrégé de tous les risques de marché
class AggregatedMarketRiskResult {
  const AggregatedMarketRiskResult({
    required this.foreignExchangeRisk,
    required this.tauxRwa,
    required this.actionsRwa,
    required this.totalMarketRwa,
    required this.fxContributionPercent,
  });

  final ForeignExchangeRiskResult foreignExchangeRisk;
  final double tauxRwa;          // RWA du risque de taux
  final double actionsRwa;       // RWA du risque actions
  final double totalMarketRwa;   // RWA Marché total
  final double fxContributionPercent; // Contribution FX au RWA total (%)
}

/// Service pour calculer les KPI agrégés du risque de marché
class MarketRiskAggregationService {
  static final MarketRiskAggregationService _instance =
      MarketRiskAggregationService._internal();

  factory MarketRiskAggregationService() {
    return _instance;
  }

  MarketRiskAggregationService._internal();

  /// Calcule les KPI agrégés (Taux + Change + Actions)
  AggregatedMarketRiskResult calculateAggregatedRisk({
    required List<ForeignExchangePosition> fxPositions,
    MarketDataImportStore? marketStore,
  }) {
    // 1. Calcule le risque de change
    final fxRisk = calculateForeignExchangeRisk(fxPositions);

    // 2. Récupère le store des données marché
    final store = marketStore ?? MarketDataImportStore.instance;

    // 3. Récupère les RWA des autres risques
    // TODO: Implémenter les méthodes publiques dans MarketDataImportStore
    // pour retourner les RWA Taux et Actions
    final tauxRwa = _getTauxRwaFromStore(store);
    final actionsRwa = _getActionsRwaFromStore(store);

    // 4. Calcule le RWA total du marché
    final totalRwa = fxRisk.marketRwa + tauxRwa + actionsRwa;

    // 5. Calcule la contribution FX
    final fxContribution = totalRwa > 0 ? (fxRisk.marketRwa / totalRwa) * 100 : 0.0;

    return AggregatedMarketRiskResult(
      foreignExchangeRisk: fxRisk,
      tauxRwa: tauxRwa,
      actionsRwa: actionsRwa,
      totalMarketRwa: totalRwa,
      fxContributionPercent: fxContribution,
    );
  }

  /// Récupère le RWA Taux du store
  double _getTauxRwaFromStore(MarketDataImportStore store) {
    final capital = store.dataset?.prudentialCapital;
    if (capital == null) return 0.0;
    // interestRateRisk = interestRateSpecificRisk + interestRateGeneralRisk
    // RWA = capital × 12.5
    return capital.interestRateRisk * 12.5;
  }

  /// Récupère le RWA Actions du store
  double _getActionsRwaFromStore(MarketDataImportStore store) {
    final capital = store.dataset?.prudentialCapital;
    if (capital == null) return 0.0;
    // equityRisk = equitySpecificRisk + equityGeneralRisk
    return capital.equityRisk * 12.5;
  }
}
