/// Service de calcul du risque de change conforme BCEAO
/// Approche standard: Position nette globale × 9%
library;

import 'dart:math' as math;

import '../models/currency_registry.dart';

/// Représente une position de change par devise
class ForeignExchangePosition {
  const ForeignExchangePosition({
    required this.currency,
    required this.assets,
    required this.liabilities,
    required this.forwardPurchases,
    required this.forwardSales,
  });

  final String currency;
  final double assets; // Actifs en devise
  final double liabilities; // Passifs en devise
  final double forwardPurchases; // Achats à terme en devise
  final double forwardSales; // Ventes à terme en devise

  /// Calcule la position nette : Actifs - Passifs - Achats_à_terme + Ventes_à_terme
  double get netPosition =>
      assets - liabilities - forwardPurchases + forwardSales;

  /// Détermine si la position est longue (positive)
  bool get isLong => netPosition > 0;

  /// Détermine si la position est courte (négative)
  bool get isShort => netPosition < 0;

  /// Valeur absolue de la position nette
  double get absolutePosition => netPosition.abs();
}

/// Résultat du calcul du risque de change
class ForeignExchangeRiskResult {
  const ForeignExchangeRiskResult({
    required this.positions,
    required this.totalLongPositions,
    required this.totalShortPositions,
    required this.globalNetPosition,
    required this.capitalRequirement,
    required this.marketRwa,
  });

  final List<ForeignExchangePosition> positions;
  final double totalLongPositions; // Somme des positions positives
  final double
      totalShortPositions; // Somme des positions négatives (valeur absolue)
  final double globalNetPosition; // MAX(longues, courtes)
  final double capitalRequirement; // Position_Nette_Globale × 9%
  final double marketRwa; // Capital_Requirement × 12.5
}

/// Calcule le risque de change conformément à l'approche standard BCEAO
/// Article 45 du dispositif prudentiel
ForeignExchangeRiskResult calculateForeignExchangeRisk(
  List<ForeignExchangePosition> positions,
) {
  double totalLong = 0.0;
  double totalShort = 0.0;

  // Pour chaque devise, classer position longue ou courte
  for (final position in positions) {
    if (position.netPosition > 0) {
      totalLong += position.netPosition;
    } else if (position.netPosition < 0) {
      totalShort += position.netPosition.abs();
    }
  }

  // Position nette globale = MAX(longues, courtes)
  final globalNetPosition = math.max(totalLong, totalShort);

  // Exigence de fonds propres = Position_Nette_Globale × 9%
  final capitalRequirement = globalNetPosition * 0.09;

  // RWA = Exigence_FP × 12.5
  final marketRwa = capitalRequirement * 12.5;

  return ForeignExchangeRiskResult(
    positions: positions,
    totalLongPositions: totalLong,
    totalShortPositions: totalShort,
    globalNetPosition: globalNetPosition,
    capitalRequirement: capitalRequirement,
    marketRwa: marketRwa,
  );
}

/// Calcule l'analyse statistique des positions
PositionAnalysis analyzePositions(List<ForeignExchangePosition> positions) {
  if (positions.isEmpty) {
    return const PositionAnalysis(
      totalDevises: 0,
      longPositions: 0,
      shortPositions: 0,
      neutralPositions: 0,
      averagePositionSize: 0,
      largestLongPosition: 0,
      largestShortPosition: 0,
      concentrationRatio: 0,
    );
  }

  final registry = CurrencyRegistry();
  int longCount = 0;
  int shortCount = 0;
  int neutralCount = 0;
  double largestLong = 0;
  double largestShort = 0;
  double totalAbsolute = 0;

  for (final pos in positions) {
    final rate = registry.getRate(pos.currency);
    final rateValue = rate?.rateToXof ?? 1.0;
    final positionInXof = pos.netPosition * rateValue;

    totalAbsolute += positionInXof.abs();

    if (pos.netPosition > 0) {
      longCount++;
      largestLong = math.max(largestLong, positionInXof);
    } else if (pos.netPosition < 0) {
      shortCount++;
      largestShort = math.max(largestShort, positionInXof.abs());
    } else {
      neutralCount++;
    }
  }

  final averageSize =
      positions.isNotEmpty ? totalAbsolute / positions.length : 0.0;
  final concentrationRatio = largestLong > 0 || largestShort > 0
      ? (math.max(largestLong, largestShort)) /
          (totalAbsolute > 0 ? totalAbsolute : 1)
      : 0.0;

  return PositionAnalysis(
    totalDevises: positions.length,
    longPositions: longCount,
    shortPositions: shortCount,
    neutralPositions: neutralCount,
    averagePositionSize: averageSize,
    largestLongPosition: largestLong,
    largestShortPosition: largestShort,
    concentrationRatio: concentrationRatio,
  );
}
