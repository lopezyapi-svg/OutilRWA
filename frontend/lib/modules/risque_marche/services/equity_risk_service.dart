import 'dart:math' as math;
import 'market_data_import_store.dart';

class EquityPositionResult {
  final String issuer;
  final double marketValue;
  final double weight;
  final double return_;
  final double beta;
  final double contribution;

  const EquityPositionResult({
    required this.issuer,
    required this.marketValue,
    required this.weight,
    required this.return_,
    required this.beta,
    required this.contribution,
  });
}

class EquityRiskResult {
  final List<EquityPositionResult> positions;
  final double totalMarketValue;
  final double portfolioReturn;
  final double portfolioVolatility;
  final double portfolioBeta;
  final double concentrationRatio;
  final String dominantIssuer;
  final double capitalRequirement;
  final Map<String, dynamic> formulaDetails;
  final List<Map<String, dynamic>> calculationJournal;

  const EquityRiskResult({
    required this.positions,
    required this.totalMarketValue,
    required this.portfolioReturn,
    required this.portfolioVolatility,
    required this.portfolioBeta,
    required this.concentrationRatio,
    required this.dominantIssuer,
    required this.capitalRequirement,
    required this.formulaDetails,
    required this.calculationJournal,
  });
}

EquityRiskResult calculateEquityRisk({
  required List<MarketPortfolioRecord> records,
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description': 'Calcul du risque actions',
    'timestamp': DateTime.now().toIso8601String(),
  });

  final equityRecords = records
      .where((r) => r.portfolioType == MarketPortfolioType.equities)
      .toList();

  journal.add({
    'etape': 'Extraction',
    'description': '${equityRecords.length} lignes actions extraites',
  });

  var totalValue = 0.0;
  final positionData = <_EquityData>[];
  for (final record in equityRecords) {
    final mv = math.max(0.0, record.marketValue).toDouble();
    final exposure = math.max(0.0, record.exposureAmount).toDouble();
    final value = mv > 0 ? mv : exposure;
    if (value <= 0) continue;
    totalValue += value;
    positionData.add(_EquityData(
      issuer: record.issuer,
      marketValue: value,
      return_: record.expectedReturnInput,
      beta: record.beta > 0 ? record.beta : 1.0,
      volatility: record.annualizedVolatilityInput,
    ));
  }

  if (totalValue <= 0) {
    return EquityRiskResult(
      positions: [],
      totalMarketValue: 0,
      portfolioReturn: 0,
      portfolioVolatility: 0,
      portfolioBeta: 1.0,
      concentrationRatio: 0,
      dominantIssuer: 'Non disponible',
      capitalRequirement: 0,
      formulaDetails: {'note': 'Aucune donnée actions'},
      calculationJournal: journal,
    );
  }

  var weightedReturn = 0.0;
  var weightedBeta = 0.0;
  var weightedVol = 0.0;
  final positions = <EquityPositionResult>[];
  final byIssuer = <String, double>{};

  for (final data in positionData) {
    final weight = data.marketValue / totalValue;
    weightedReturn += data.return_ * weight;
    weightedBeta += data.beta * weight;
    weightedVol += data.volatility * weight;
    final contribution = data.beta * weight;
    byIssuer.update(data.issuer, (v) => v + data.marketValue,
        ifAbsent: () => data.marketValue);
    positions.add(EquityPositionResult(
      issuer: data.issuer,
      marketValue: data.marketValue,
      weight: weight,
      return_: data.return_,
      beta: data.beta,
      contribution: contribution,
    ));
  }

  final concentration = byIssuer.values.reduce(math.max) / totalValue;
  final dominant =
      byIssuer.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  final grossPosition = totalValue;
  final capitalReq = grossPosition * 0.08;

  journal.add({
    'etape': 'Indicateurs synthétiques',
    'description': 'Calcul des indicateurs agrégés',
    'return': weightedReturn,
    'beta': weightedBeta,
    'volatility': weightedVol,
    'concentration': concentration,
    'formule_beta': 'β_portefeuille = Σ(β_i × poids_i)',
    'formule_concentration': 'C = max(Emetteur) / Total',
  });

  journal.add({
    'etape': 'Capital requis',
    'description': 'Risque spécifique + général actions = 8% de la position brute',
    'grossPosition': grossPosition,
    'capitalRequirement': capitalReq,
    'formule': 'Exigence FP Actions = Position_brute × 8%',
  });

  final details = {
    'formule_rendement': 'R_portefeuille = Σ(R_i × MV_i / MV_total)',
    'formule_volatilite': 'σ_portefeuille = Σ(σ_i × poids_i) (approximation)',
    'formule_beta': 'β_portefeuille = Σ(β_i × poids_i)',
    'formule_concentration': 'Ratio = max(Emetteur) / Total',
    'formule_capital': 'Exigence = Position_brute × 8% (Bâle II standard)',
  };

  return EquityRiskResult(
    positions: positions,
    totalMarketValue: totalValue,
    portfolioReturn: weightedReturn,
    portfolioVolatility: weightedVol,
    portfolioBeta: weightedBeta.clamp(0.55, 2.2),
    concentrationRatio: concentration,
    dominantIssuer: dominant,
    capitalRequirement: capitalReq,
    formulaDetails: details,
    calculationJournal: journal,
  );
}

class _EquityData {
  final String issuer;
  final double marketValue;
  final double return_;
  final double beta;
  final double volatility;

  const _EquityData({
    required this.issuer,
    required this.marketValue,
    required this.return_,
    required this.beta,
    required this.volatility,
  });
}
