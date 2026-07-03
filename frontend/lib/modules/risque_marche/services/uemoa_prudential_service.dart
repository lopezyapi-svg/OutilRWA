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
    'reglement': 'Dispositif prudentiel UMOA, Titre VI, Art. 316-442',
    'norme': 'Instruction n°026-11-2016 (BCEAO) — Approche standard marché',
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
    'formule':
        'Exigence Taux = Risque spécifique + Risque général (Art. 349-394)',
  });

  journal.add({
    'etape': 'Risque actions',
    'description': 'Spécifique (9% par émetteur) + Général (9% par marché)',
    'specific': prudentialResult.equitySpecificRisk,
    'general': prudentialResult.equityGeneralRisk,
    'total': equityRisk,
    'formule':
        'Exigence Actions = 9%×Σ|net émetteur| + 9%×Σ|net marché| (Art. 398-401)',
  });

  journal.add({
    'etape': 'Risque de change',
    'description': '9% de la position nette globale',
    'netPosition': prudentialResult.foreignExchangeGlobalNetPosition,
    'total': fxRisk,
    'formule':
        'Exigence Change = max(Σ longues, Σ courtes) × 9% (Art. 416-417)',
  });

  journal.add({
    'etape': 'Synthèse',
    'description': 'Exigence globale et RWA Marché',
    'totalCapital': totalCapital,
    'marketRwa': rwa,
    'formule': 'RWA Marché = Exigence_FP_Marché × 12,5 (= 1/0,08)',
    'article': 'Dispositif prudentiel UMOA, Art. 318-319',
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
  // Seuil minimum de solvabilité dans l'UMOA (8,5 %). Le 9 % ne sert qu'au
  // facteur de conversion RWA (12,5 = 1/0,08), pas au seuil de conformité.
  double minimumRatio = 0.085,
}) {
  final ratio = marketRwa > 0 ? actualCapital / marketRwa : 0.0;
  final compliant = ratio >= minimumRatio;
  final shortfall = compliant ? 0.0 : marketRwa * minimumRatio - actualCapital;
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
      'reglement':
          'Dispositif prudentiel UMOA — ratio de solvabilité (Titre III)',
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

/// Résultat de l'évaluation des exemptions de calcul des exigences de fonds
/// propres au titre du risque de marché (Art. 326-327).
class MarketRiskExemptionAssessment {
  final bool interestAndEquityExempt; // Art. 326
  final bool foreignExchangeExempt; // Art. 327
  final double
      tradingBookRatio; // portefeuille de négociation / assiette (Art. 326)
  final Map<String, dynamic> details;

  const MarketRiskExemptionAssessment({
    required this.interestAndEquityExempt,
    required this.foreignExchangeExempt,
    required this.tradingBookRatio,
    required this.details,
  });
}

/// Évalue les exemptions de calcul (Art. 326-327). Les entrées proviennent du
/// bilan et des fonds propres de l'établissement (hors module marché), d'où le
/// passage explicite des paramètres. Toute valeur non disponible (≤ 0) rend
/// l'exemption correspondante non applicable, par prudence.
MarketRiskExemptionAssessment assessMarketRiskExemptions({
  required double tradingBookValue,
  required double totalAssets,
  double offBalanceAbsolute = 0,
  double derivativesAbsolute = 0,
  required double fxGrossVolume, // max(Σ brutes longues, Σ brutes courtes)
  required double fxGlobalNetPosition,
  required double eligibleOwnFunds, // FP admissibles (Art. 327 a)
  required double effectiveOwnFunds, // FP effectifs (Art. 327 b)
}) {
  // Art. 326 : exonération taux + actions si le portefeuille de négociation
  // ne dépasse pas 2 % de (actif total + |hors bilan| + |dérivés|).
  final base326 = totalAssets + offBalanceAbsolute + derivativesAbsolute;
  final tradingRatio =
      base326 > 0 ? tradingBookValue / base326 : double.infinity;
  final interestEquityExempt = base326 > 0 && tradingRatio <= 0.02;

  // Art. 327 : exonération change si (a) volume de change ≤ 100 % des FP
  // admissibles ET (b) position nette globale ≤ 2 % des FP effectifs.
  final fxVolumeOk = eligibleOwnFunds > 0 && fxGrossVolume <= eligibleOwnFunds;
  final fxNetOk =
      effectiveOwnFunds > 0 && fxGlobalNetPosition <= 0.02 * effectiveOwnFunds;
  final fxExempt = fxVolumeOk && fxNetOk;

  return MarketRiskExemptionAssessment(
    interestAndEquityExempt: interestEquityExempt,
    foreignExchangeExempt: fxExempt,
    tradingBookRatio: tradingRatio.isFinite ? tradingRatio : 0.0,
    details: {
      'article_326':
          'Exonération taux/actions si négociation ≤ 2 % de l\'assiette',
      'ratio_negociation': tradingRatio.isFinite ? tradingRatio : null,
      'seuil_326': 0.02,
      'exempt_taux_actions': interestEquityExempt,
      'article_327':
          'Exonération change si volume ≤ 100 % FP et position nette ≤ 2 % FP',
      'fx_volume_conforme': fxVolumeOk,
      'fx_position_nette_conforme': fxNetOk,
      'exempt_change': fxExempt,
    },
  );
}
