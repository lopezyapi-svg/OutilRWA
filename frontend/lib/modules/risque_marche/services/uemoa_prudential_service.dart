import 'market_data_import_store.dart';

class UemoaCapitalRequirement {
  final double interestRateRisk;
  final double equityRisk;
  final double foreignExchangeRisk;
  final double totalCapitalRequirement;
  final double marketRwa;
  final Map<String, dynamic> components;
  final List<Map<String, dynamic>> calculationJournal;

  const UemoaCapitalRequirement({
    required this.interestRateRisk,
    required this.equityRisk,
    required this.foreignExchangeRisk,
    required this.totalCapitalRequirement,
    required this.marketRwa,
    required this.components,
    required this.calculationJournal,
  });
}

class UemoaLimitCheck {
  final double actualCapital;
  final double marketRwa;
  final double capitalRatio;
  final double minimumRatio;
  final bool compliant;
  final double shortfall;
  final double excessCapital;
  final Map<String, dynamic> details;

  const UemoaLimitCheck({
    required this.actualCapital,
    required this.marketRwa,
    required this.capitalRatio,
    required this.minimumRatio,
    required this.compliant,
    required this.shortfall,
    required this.excessCapital,
    required this.details,
  });
}

UemoaCapitalRequirement calculateUemoaMarketCapitalRequirement({
  required MarketPrudentialCapitalResult prudentialResult,
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description': 'Calcul des exigences de fonds propres UEMOA/BCEAO',
    'timestamp': DateTime.now().toIso8601String(),
    'reglement': 'Règlement n°XX/2024/BCEAO relatif aux fonds propres',
    'norme': 'Bâle II/III - Approche standard marché',
  });

  final interestRateRisk = prudentialResult.interestRateRisk;
  final equityRisk = prudentialResult.equityRisk;
  final fxRisk = prudentialResult.foreignExchangeRisk;
  final totalCapital = prudentialResult.capitalRequirement;
  final rwa = prudentialResult.marketRwa;

  journal.add({
    'etape': 'Risque de taux',
    'description': 'Risque spécifique + général',
    'specific': prudentialResult.interestRateSpecificRisk,
    'general': prudentialResult.interestRateGeneralRisk,
    'total': interestRateRisk,
    'formule': 'Exigence Taux = Σ(Positions × pondérations par catégorie/échéance)',
  });

  journal.add({
    'etape': 'Risque actions',
    'description': '8% de la position brute',
    'specific': prudentialResult.equitySpecificRisk,
    'general': prudentialResult.equityGeneralRisk,
    'total': equityRisk,
    'formule': 'Exigence Actions = Position_brute × 8% (Bâle II standard)',
  });

  journal.add({
    'etape': 'Risque de change',
    'description': '8% de la position globale maximale',
    'netPosition': prudentialResult.foreignExchangeGlobalNetPosition,
    'total': fxRisk,
    'formule': 'Exigence Change = max(Positions_longues, Positions_courtes) × 8%',
  });

  journal.add({
    'etape': 'Synthèse',
    'description': 'Exigence globale et RWA Marché',
    'totalCapital': totalCapital,
    'marketRwa': rwa,
    'formule': 'RWA Marché = Exigence_FP_Marché × 12.5',
    'article': 'Article 45 - Règlement BCEAO Fonds Propres',
  });

  return UemoaCapitalRequirement(
    interestRateRisk: interestRateRisk,
    equityRisk: equityRisk,
    foreignExchangeRisk: fxRisk,
    totalCapitalRequirement: totalCapital,
    marketRwa: rwa,
    components: {
      'interest_rate_specific': prudentialResult.interestRateSpecificRisk,
      'interest_rate_general': prudentialResult.interestRateGeneralRisk,
      'equity_specific': prudentialResult.equitySpecificRisk,
      'equity_general': prudentialResult.equityGeneralRisk,
      'foreign_exchange': prudentialResult.foreignExchangeRisk,
      'interest_rate_specific_weight_avg':
          prudentialResult.interestRateSpecificRiskWeightAverage,
      'interest_rate_general_weight_avg':
          prudentialResult.interestRateGeneralRiskWeightAverage,
      'equity_gross': prudentialResult.equityGrossPosition,
      'equity_net': prudentialResult.equityNetPosition,
      'fx_global_net': prudentialResult.foreignExchangeGlobalNetPosition,
    },
    calculationJournal: journal,
  );
}

UemoaLimitCheck checkUemoaCapitalLimit({
  required double actualCapital,
  required double marketRwa,
  double minimumRatio = 0.08,
}) {
  final ratio = marketRwa > 0 ? actualCapital / marketRwa : 0.0;
  final compliant = ratio >= minimumRatio;
  final shortfall = compliant
      ? 0.0
      : marketRwa * minimumRatio - actualCapital;
  final excess = compliant ? actualCapital - marketRwa * minimumRatio : 0.0;

  return UemoaLimitCheck(
    actualCapital: actualCapital,
    marketRwa: marketRwa,
    capitalRatio: ratio,
    minimumRatio: minimumRatio,
    compliant: compliant,
    shortfall: shortfall,
    excessCapital: excess,
    details: {
      'reglement': 'BCEAO Fonds Propres - Article 45',
      'ratio_minimum': minimumRatio,
      'ratio_calcule': ratio,
      'conforme': compliant ? 'OUI' : 'NON',
      'observation': compliant
          ? 'Ratio fonds propres réglementaires ≥ seuil minimum'
          : 'Déficit en fonds propres : $shortfall',
      'alerte_renforcee': ratio < minimumRatio * 1.2 ? true : false,
    },
  );
}
