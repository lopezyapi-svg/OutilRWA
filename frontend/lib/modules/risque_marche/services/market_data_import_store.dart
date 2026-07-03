import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/currency_conversion.dart';
import 'market_country_resolver.dart';
import 'market_data_local_storage.dart' as local_storage;
import 'market_risk_orchestrator.dart';

const String marketPortfolioSheetName = 'Saisir donnée';
const String marketEquityPortfolioSheetName = 'Actions';
const int _marketDataImportStorageVersion = 5;
const String _marketDataImportStorageKey = 'rwa.market_data_import.datasets.v5';

enum MarketPortfolioType { bonds, equities }

extension MarketPortfolioTypeMetadata on MarketPortfolioType {
  String get label => switch (this) {
        MarketPortfolioType.bonds => 'Obligations',
        MarketPortfolioType.equities => 'Actions',
      };

  String get singularLabel => switch (this) {
        MarketPortfolioType.bonds => 'Obligation',
        MarketPortfolioType.equities => 'Action',
      };

  String get templateFileName => switch (this) {
        MarketPortfolioType.bonds =>
          'RiskManagement_Template_Portefeuille_Obligations.xlsx',
        MarketPortfolioType.equities =>
          'RiskManagement_Template_Portefeuille_Actions.xlsx',
      };

  String get expectedPortfolioLabel => switch (this) {
        MarketPortfolioType.bonds => 'Portefeuille obligataire / titres',
        MarketPortfolioType.equities => 'Portefeuille actions / titres cotés',
      };

  String get expectedDescription => switch (this) {
        MarketPortfolioType.bonds =>
          'Le fichier importé doit contenir la feuille Saisir donnée avec les colonnes du modèle obligations.',
        MarketPortfolioType.equities =>
          'Le fichier importé doit contenir la feuille Actions avec les colonnes du modèle actions.',
      };

  String get sheetName => switch (this) {
        MarketPortfolioType.bonds => marketPortfolioSheetName,
        MarketPortfolioType.equities => marketEquityPortfolioSheetName,
      };

  List<String> get requiredHeaders => switch (this) {
        MarketPortfolioType.bonds => marketBondPortfolioRequiredHeaders,
        MarketPortfolioType.equities => marketEquityPortfolioRequiredHeaders,
      };

  String get storageKey => switch (this) {
        MarketPortfolioType.bonds => 'bonds',
        MarketPortfolioType.equities => 'equities',
      };
}

class MarketParametricVarResult {
  const MarketParametricVarResult({
    required this.confidence,
    required this.horizonDays,
    required this.varValue,
    required this.expectedShortfall,
    required this.portfolioValue,
    required this.zScore,
    required this.dailyVolatility,
    required this.modifiedDuration,
    required this.timeScale,
    required this.correlation,
    required this.expectedReturn,
    required this.riskFreeRate,
    required this.drift,
    required this.lossStdDev,
    required this.correlationAdjustment,
    required this.sharpeRatio,
    required this.rateSensitivity,
  });

  final double confidence;
  final int horizonDays;
  final double varValue;
  final double expectedShortfall;
  final double portfolioValue;
  final double zScore;
  final double dailyVolatility;
  final double modifiedDuration;
  final double timeScale;
  final double correlation;
  final double expectedReturn;
  final double riskFreeRate;
  final double drift;
  final double lossStdDev;
  final double correlationAdjustment;
  final double sharpeRatio;
  final double rateSensitivity;

  double get annualVolatility => dailyVolatility * math.sqrt(252);
  double get effectiveVolatility => dailyVolatility * timeScale;
}

class MarketCommodityPosition {
  const MarketCommodityPosition({
    required this.product,
    required this.amount,
    this.currency = 'XOF',
  });

  final String product;
  final double amount;
  final String currency;
}

class MarketPrudentialCapitalResult {
  const MarketPrudentialCapitalResult({
    required this.interestRateSpecificRisk,
    required this.interestRateGeneralRisk,
    required this.equitySpecificRisk,
    required this.equityGeneralRisk,
    required this.foreignExchangeRisk,
    required this.commodityDirectionalRisk,
    required this.commodityBasisRisk,
    required this.interestRateSpecificRiskWeightAverage,
    required this.interestRateGeneralRiskWeightAverage,
    required this.equityGrossPosition,
    required this.equityNetPosition,
    required this.foreignExchangeGlobalNetPosition,
    required this.commodityGrossPosition,
    required this.commodityNetPosition,
  });

  final double interestRateSpecificRisk;
  final double interestRateGeneralRisk;
  final double equitySpecificRisk;
  final double equityGeneralRisk;
  final double foreignExchangeRisk;
  final double commodityDirectionalRisk;
  final double commodityBasisRisk;
  final double interestRateSpecificRiskWeightAverage;
  final double interestRateGeneralRiskWeightAverage;
  final double equityGrossPosition;
  final double equityNetPosition;
  final double foreignExchangeGlobalNetPosition;
  final double commodityGrossPosition;
  final double commodityNetPosition;

  double get interestRateRisk =>
      interestRateSpecificRisk + interestRateGeneralRisk;
  double get equityRisk => equitySpecificRisk + equityGeneralRisk;
  double get commodityRisk => commodityDirectionalRisk + commodityBasisRisk;
  double get capitalRequirement =>
      interestRateRisk + equityRisk + foreignExchangeRisk + commodityRisk;
  double get marketRwa => capitalRequirement * 12.5;
}

MarketPrudentialCapitalResult calculateMarketPrudentialCapital({
  required Iterable<MarketPortfolioRecord> records,
  Iterable<MarketCommodityPosition> commodityPositions = const [],
  // Art. 399 : risque spécifique actions ramené à 4 % (au lieu de 9 %) lorsque
  // le portefeuille est jugé liquide et bien diversifié (approbation Commission
  // Bancaire requise). Désactivé par défaut.
  bool equityPortfolioLiquidAndDiversified = false,
}) {
  final marketRecords = records.toList(growable: false);
  // Risques de taux et actions : périmètre limité au portefeuille de
  // négociation (Art. 320-321). Le risque de change porte sur l'ensemble de
  // l'établissement (Art. 406) et reste calculé sur tous les enregistrements.
  final bondRecords = marketRecords
      .where((record) =>
          record.portfolioType == MarketPortfolioType.bonds &&
          record.isTradingBook)
      .toList(growable: false);
  final equityRecords = marketRecords
      .where((record) =>
          record.portfolioType == MarketPortfolioType.equities &&
          record.isTradingBook)
      .toList(growable: false);
  final interestSpecific = _marketInterestRateSpecificRisk(bondRecords);
  final interestGeneral = _marketInterestRateGeneralRisk(bondRecords);
  final bondPosition = bondRecords.fold<double>(
    0,
    (sum, record) => sum + _marketPrudentialBondPositionValue(record).abs(),
  );
  final equityPosition = _marketEquityRiskMeasure(equityRecords);
  final commodityMeasure = _marketCommodityPositionMeasure(commodityPositions);
  final equitySpecificRate = equityPortfolioLiquidAndDiversified ? 0.04 : 0.09;

  return MarketPrudentialCapitalResult(
    interestRateSpecificRisk: interestSpecific,
    interestRateGeneralRisk: interestGeneral,
    // Risque spécifique : (9% ou 4%) × Σ|net par émetteur| (Art. 398-399)
    equitySpecificRisk: equityPosition.specificRiskBase * equitySpecificRate,
    // Risque général : 9% × Σ|net par marché national/régional| (Art. 400-401)
    equityGeneralRisk: equityPosition.generalRiskBase * 0.09,
    foreignExchangeRisk: _marketForeignExchangeRisk(marketRecords),
    commodityDirectionalRisk: commodityMeasure.netPosition.abs() * 0.15,
    commodityBasisRisk: commodityMeasure.grossPosition * 0.03,
    interestRateSpecificRiskWeightAverage:
        bondPosition <= 0 ? 0 : interestSpecific / bondPosition,
    interestRateGeneralRiskWeightAverage:
        bondPosition <= 0 ? 0 : interestGeneral / bondPosition,
    equityGrossPosition: equityPosition.grossPosition,
    equityNetPosition: equityPosition.netPosition,
    foreignExchangeGlobalNetPosition:
        _marketForeignExchangeGlobalNetPosition(marketRecords),
    commodityGrossPosition: commodityMeasure.grossPosition,
    commodityNetPosition: commodityMeasure.netPosition,
  );
}

MarketParametricVarResult calculateMarketParametricVar({
  required bool hasMarketData,
  required MarketPortfolioType portfolioType,
  required double basePortfolioValue,
  required double confidence,
  required int horizonDays,
  required double portfolioScale,
  required double annualVolatility,
  required double modifiedDuration,
  required double correlation,
  required double expectedReturn,
  required double riskFreeRate,
}) {
  final portfolioValue = basePortfolioValue * portfolioScale;
  final z = marketNormalQuantile(confidence);
  final normalizedExpectedReturn = _marketDecimalRate(expectedReturn);
  final normalizedRiskFreeRate = _marketDecimalRate(riskFreeRate);
  final normalizedCorrelation = correlation.clamp(-0.999, 0.999).toDouble();
  final timeScale = math.sqrt(math.max(1, horizonDays));

  if (!hasMarketData || portfolioValue <= 0 || annualVolatility <= 0) {
    return MarketParametricVarResult(
      confidence: confidence,
      horizonDays: horizonDays,
      varValue: 0,
      expectedShortfall: 0,
      portfolioValue: 0,
      zScore: z,
      dailyVolatility: 0,
      modifiedDuration: modifiedDuration,
      timeScale: timeScale,
      correlation: normalizedCorrelation,
      expectedReturn: normalizedExpectedReturn,
      riskFreeRate: normalizedRiskFreeRate,
      drift: 0,
      lossStdDev: 0,
      correlationAdjustment: 1,
      sharpeRatio: 0,
      rateSensitivity: 0,
    );
  }

  final normalizedVolatility = _marketNormalizedVolatility(annualVolatility);
  final dailyVolatility = normalizedVolatility / math.sqrt(252);
  final sensitivityMultiplier = portfolioType == MarketPortfolioType.bonds
      ? math.max(0.0, modifiedDuration)
      : 1.0;
  final lossStdDev =
      dailyVolatility * sensitivityMultiplier * portfolioValue * timeScale;
  final varValue = math.max(0.0, z * lossStdDev).toDouble();
  final expectedShortfall =
      marketNormalPdf(z) / math.max(0.0001, 1 - confidence) * lossStdDev;
  final sharpeRatio = normalizedVolatility == 0
      ? 0.0
      : (normalizedExpectedReturn - normalizedRiskFreeRate) /
          normalizedVolatility;
  final rateSensitivity = modifiedDuration * portfolioValue * 0.0001;

  return MarketParametricVarResult(
    confidence: confidence,
    horizonDays: horizonDays,
    varValue: varValue,
    expectedShortfall: expectedShortfall,
    portfolioValue: portfolioValue,
    zScore: z,
    dailyVolatility: dailyVolatility,
    modifiedDuration: modifiedDuration,
    timeScale: timeScale,
    correlation: normalizedCorrelation,
    expectedReturn: normalizedExpectedReturn,
    riskFreeRate: normalizedRiskFreeRate,
    drift: 0,
    lossStdDev: lossStdDev,
    correlationAdjustment: 1,
    sharpeRatio: sharpeRatio,
    rateSensitivity: rateSensitivity,
  );
}

List<MarketParametricVarResult> calculateMarketParametricVarHorizons({
  required bool hasMarketData,
  required MarketPortfolioType portfolioType,
  required double basePortfolioValue,
  required double confidence,
  required double portfolioScale,
  required double annualVolatility,
  required double modifiedDuration,
  required double correlation,
  required double expectedReturn,
  required double riskFreeRate,
  List<int> horizons = const [1, 3, 10, 21],
}) {
  return [
    for (final horizon in horizons)
      calculateMarketParametricVar(
        hasMarketData: hasMarketData,
        portfolioType: portfolioType,
        basePortfolioValue: basePortfolioValue,
        confidence: confidence,
        horizonDays: horizon,
        portfolioScale: portfolioScale,
        annualVolatility: annualVolatility,
        modifiedDuration: modifiedDuration,
        correlation: correlation,
        expectedReturn: expectedReturn,
        riskFreeRate: riskFreeRate,
      ),
  ];
}

double marketNormalQuantile(double confidence) {
  if (confidence >= 0.989) return 2.3263;
  if (confidence >= 0.974) return 1.96;
  return 1.6449;
}

double marketNormalPdf(double value) {
  return math.exp(-0.5 * value * value) / math.sqrt(2 * math.pi);
}

double _marketDecimalRate(num value) {
  final resolved = value.toDouble();
  if (!resolved.isFinite) return 0;
  return resolved.abs() > 1 ? resolved / 100 : resolved;
}

double _marketNormalizedVolatility(num value) {
  final resolved = _marketDecimalRate(value).abs();
  if (!resolved.isFinite || resolved == 0) return 0.000001;
  return resolved.clamp(0.000001, 5.0).toDouble();
}

class _MarketPositionMeasure {
  const _MarketPositionMeasure({
    required this.grossPosition,
    required this.netPosition,
  });

  final double grossPosition;
  final double netPosition;
}

/// Mesure des positions actions pour l'exigence prudentielle (Art. 398-401).
/// - [specificRiskBase] : Σ |position nette par émetteur| (risque spécifique, Art. 399)
/// - [generalRiskBase]  : Σ |position nette par marché national/régional| (risque général, Art. 401)
class _MarketEquityRiskMeasure {
  const _MarketEquityRiskMeasure({
    required this.grossPosition,
    required this.netPosition,
    required this.specificRiskBase,
    required this.generalRiskBase,
  });

  final double grossPosition;
  final double netPosition;
  final double specificRiskBase;
  final double generalRiskBase;
}

class _MarketGeneralRiskBucket {
  const _MarketGeneralRiskBucket({
    required this.index,
    required this.zone,
    required this.weight,
  });

  final int index;
  final int zone;
  final double weight;
}

class _MarketBucketBalance {
  double long = 0;
  double short = 0;

  void add(double signedWeightedPosition) {
    if (signedWeightedPosition >= 0) {
      long += signedWeightedPosition;
    } else {
      short += signedWeightedPosition.abs();
    }
  }
}

enum _MarketCreditQuality { aaaToAa, aToBbb, bbToB, belowB, unrated }

double _marketInterestRateSpecificRisk(List<MarketPortfolioRecord> records) {
  var capital = 0.0;
  for (final record in records) {
    final position = _marketPrudentialBondPositionValue(record).abs();
    if (position <= 0) continue;
    capital += position * marketSpecificDebtRiskWeight(record);
  }
  return capital;
}

double _marketInterestRateGeneralRisk(List<MarketPortfolioRecord> records) {
  final balancesByCurrency = <String, Map<int, _MarketBucketBalance>>{};
  final bucketsByIndex = <int, _MarketGeneralRiskBucket>{};

  for (final record in records) {
    final position = _marketPrudentialBondPositionValue(record);
    if (position == 0) continue;
    final bucket = _marketGeneralRiskBucket(record);
    bucketsByIndex[bucket.index] = bucket;
    final weightedPosition =
        position * _marketRecordPositionSign(record) * bucket.weight;
    if (weightedPosition == 0) continue;
    final currency = normalizeCurrencyCode(record.currency);
    balancesByCurrency
        .putIfAbsent(currency, () => <int, _MarketBucketBalance>{})
        .putIfAbsent(bucket.index, () => _MarketBucketBalance())
        .add(weightedPosition);
  }

  var capital = 0.0;
  for (final entry in balancesByCurrency.entries) {
    final zoneLong = List<double>.filled(3, 0);
    final zoneShort = List<double>.filled(3, 0);

    for (final bucketEntry in entry.value.entries) {
      final bucket = bucketsByIndex[bucketEntry.key];
      if (bucket == null) continue;
      final balance = bucketEntry.value;
      final matched = math.min(balance.long, balance.short);
      capital += matched * 0.10;
      final residual = balance.long - balance.short;
      final zoneIndex = (bucket.zone - 1).clamp(0, 2).toInt();
      if (residual >= 0) {
        zoneLong[zoneIndex] += residual;
      } else {
        zoneShort[zoneIndex] += residual.abs();
      }
    }

    final zoneResidual = List<double>.filled(3, 0);
    const intraZoneFactors = [0.40, 0.30, 0.30];
    for (var index = 0; index < 3; index++) {
      final matched = math.min(zoneLong[index], zoneShort[index]);
      capital += matched * intraZoneFactors[index];
      zoneResidual[index] = zoneLong[index] - zoneShort[index];
    }

    capital += _marketMatchMaturityZones(zoneResidual, 0, 1, 0.40);
    capital += _marketMatchMaturityZones(zoneResidual, 1, 2, 0.40);
    capital += _marketMatchMaturityZones(zoneResidual, 0, 2, 1.00);
    capital += zoneResidual.fold<double>(0, (sum, value) => sum + value).abs();
  }

  return capital;
}

double _marketMatchMaturityZones(
  List<double> zoneResidual,
  int left,
  int right,
  double factor,
) {
  final leftValue = zoneResidual[left];
  final rightValue = zoneResidual[right];
  if (leftValue == 0 || rightValue == 0 || leftValue.sign == rightValue.sign) {
    return 0;
  }
  final matched = math.min(leftValue.abs(), rightValue.abs());
  zoneResidual[left] += leftValue.isNegative ? matched : -matched;
  zoneResidual[right] += rightValue.isNegative ? matched : -matched;
  return matched * factor;
}

_MarketEquityRiskMeasure _marketEquityRiskMeasure(
  List<MarketPortfolioRecord> records,
) {
  final netByIssuer = <String, double>{};
  final netByMarket = <String, double>{};
  var gross = 0.0;
  var net = 0.0;
  for (final record in records) {
    final signed = _marketPrudentialEquityPositionValue(record) *
        _marketRecordPositionSign(record);
    if (signed == 0 || !signed.isFinite) continue;
    gross += signed.abs();
    net += signed;

    // Risque spécifique : compensation des positions par émetteur (Art. 399).
    netByIssuer.update(record.issuerAnalysisKey, (value) => value + signed,
        ifAbsent: () => signed);

    // Risque général : position nette par marché national/régional (Art. 401).
    // À défaut de pays/marché renseigné, la devise sert de proxy de marché.
    final marketKey = record.marketCountryIso3.isNotEmpty
        ? record.marketCountryIso3
        : normalizeCurrencyCode(record.currency);
    netByMarket.update(marketKey, (value) => value + signed,
        ifAbsent: () => signed);
  }

  final specificBase =
      netByIssuer.values.fold<double>(0, (sum, value) => sum + value.abs());
  final generalBase =
      netByMarket.values.fold<double>(0, (sum, value) => sum + value.abs());

  return _MarketEquityRiskMeasure(
    grossPosition: gross,
    netPosition: net,
    specificRiskBase: specificBase,
    generalRiskBase: generalBase,
  );
}

_MarketPositionMeasure _marketCommodityPositionMeasure(
  Iterable<MarketCommodityPosition> positions,
) {
  final netByProduct = <String, double>{};
  var gross = 0.0;
  for (final position in positions) {
    final amount = convertCurrencyAmount(
      position.amount,
      fromCurrency: position.currency,
      toCurrency: 'XOF',
    );
    if (amount == 0 || !amount.isFinite) continue;
    final key = _foldMarketText(position.product);
    gross += amount.abs();
    netByProduct.update(key, (value) => value + amount, ifAbsent: () => amount);
  }
  final net = netByProduct.values.fold<double>(
    0,
    (sum, value) => sum + value.abs(),
  );
  return _MarketPositionMeasure(grossPosition: gross, netPosition: net);
}

double _marketForeignExchangeRisk(List<MarketPortfolioRecord> records) {
  return _marketForeignExchangeGlobalNetPosition(records) * 0.09;
}

double _marketForeignExchangeGlobalNetPosition(
  List<MarketPortfolioRecord> records,
) {
  final netByCurrency = <String, double>{};
  for (final record in records) {
    final currency = normalizeCurrencyCode(record.currency);
    if (currency.isEmpty || currency == 'XOF') continue;
    final amount = _marketPrudentialRecordPositionValue(record);
    if (amount <= 0) continue;
    netByCurrency.update(
      currency,
      (value) => value + amount * _marketRecordPositionSign(record),
      ifAbsent: () => amount * _marketRecordPositionSign(record),
    );
  }
  var longPositions = 0.0;
  var shortPositions = 0.0;
  for (final value in netByCurrency.values) {
    if (value >= 0) {
      longPositions += value;
    } else {
      shortPositions += value.abs();
    }
  }
  return math.max(longPositions, shortPositions).toDouble();
}

double _marketPrudentialRecordPositionValue(MarketPortfolioRecord record) {
  return switch (record.portfolioType) {
    MarketPortfolioType.bonds => _marketPrudentialBondPositionValue(record),
    MarketPortfolioType.equities =>
      _marketPrudentialEquityPositionValue(record),
  };
}

double _marketPrudentialBondPositionValue(MarketPortfolioRecord record) {
  final value = _bondMarketValue(record);
  if (value <= 0 || !value.isFinite) return 0;
  return convertCurrencyAmount(
    value,
    fromCurrency: record.currency,
    toCurrency: 'XOF',
  );
}

double _marketPrudentialEquityPositionValue(MarketPortfolioRecord record) {
  final value = record.valuationAmount > 0
      ? record.valuationAmount
      : record.exposureAmount;
  if (value <= 0 || !value.isFinite) return 0;
  return convertCurrencyAmount(
    value,
    fromCurrency: record.currency,
    toCurrency: 'XOF',
  );
}

double _marketRecordPositionSign(MarketPortfolioRecord record) {
  final signedQuantity = record.portfolioType == MarketPortfolioType.equities
      ? record.shares
      : record.quantity;
  if (signedQuantity < 0) return -1;
  final rawSide = [
    record.values['Sens'],
    record.values['Position'],
    record.values['Long/Short'],
    record.values['Achat/Vente'],
  ].whereType<Object>().map((value) => value.toString()).join(' ');
  final side = _foldMarketText(rawSide);
  if (side.contains('short') ||
      side.contains('courte') ||
      side.contains('vente') ||
      side.contains('vendu')) {
    return -1;
  }
  return 1;
}

// ==================== Tables réglementaires BCEAO ====================

/// Catégories réglementaires pour le risque spécifique
enum _MarketSpecificCategory {
  uemoaSovereignXof, // État UEMOA FCFA
  sovereignDebt, // Titre souverain
  eligibleDebt, // Titre éligible
  otherDebt, // Autre émetteur
}

/// Récupère la pondération spécifique selon catégorie, notation et maturité
/// Conforme au Tableau 16 BCEAO: Catégories de risques spécifiques et pondérations
double _getSpecificRiskWeight(
  _MarketSpecificCategory category,
  _MarketCreditQuality quality,
  double residualYears,
) {
  switch (category) {
    case _MarketSpecificCategory.uemoaSovereignXof:
      return 0.0000; // État UEMOA FCFA = 0%

    case _MarketSpecificCategory.sovereignDebt:
      // Tableau 16: Titres souverains
      return switch (quality) {
        _MarketCreditQuality.aaaToAa => 0.0000, // AAA à A- = 0%
        _MarketCreditQuality.aToBbb => residualYears < 0.5
            ? 0.0025
            : // < 6 mois = 0.25%
            residualYears <= 2.0
                ? 0.0100
                : // 6 à 24 mois = 1%
                0.0160, // > 24 mois = 1.6%
        _MarketCreditQuality.bbToB => 0.0800, // BB+ à B- = 9%
        _MarketCreditQuality.belowB => 0.1200, // < B- = 12%
        _MarketCreditQuality.unrated => 0.0800, // Sans notation = 9%
      };

    case _MarketSpecificCategory.eligibleDebt:
      // Tableau 16: Titres éligibles (cf infra)
      if (quality == _MarketCreditQuality.bbToB) {
        return 0.0800; // BB+ à BB- = 9%
      }
      // Tous autres (AAA-BBB- + multilatéraux sans notation)
      return residualYears < 0.5
          ? 0.0025
          : // < 6 mois = 0.25%
          residualYears <= 2.0
              ? 0.0100
              : // 6 à 24 mois = 1%
              0.0160; // > 24 mois = 1.6%

    case _MarketSpecificCategory.otherDebt:
      // Autres émetteurs (ni souverains, ni éligibles) : traités comme les
      // entreprises de qualité inférieure selon l'approche standard crédit
      // (Art. 357, Titre IV). Pondération conservatrice de 9 %.
      return switch (quality) {
        _MarketCreditQuality.aaaToAa => 0.0000, // AAA à A- = 0%
        _MarketCreditQuality.aToBbb => 0.0800, // A+ à BBB- = 9% (Art. 357)
        _MarketCreditQuality.bbToB => 0.0800, // BB+ à BB- = 9%
        _MarketCreditQuality.belowB => 0.1200, // Sous BB- = 12%
        _MarketCreditQuality.unrated => 0.0800, // Sans notation = 9%
      };
  }
}

/// Récupère la pondération générale selon le coupon et la tranche d'échéance (table BCEAO)
double marketGeneralRiskWeight(double residualYears, double couponRate) {
  return _getGeneralRiskWeight(residualYears, couponRate);
}

/// Récupère la pondération générale selon la tranche d'échéance et le coupon
/// Table BCEAO: Méthode fondée sur les échéances (Tableau 17)
double _getGeneralRiskWeight(double residualYears, double couponRate) {
  final isHighCoupon = couponRate >= 0.03; // Coupon ≥ 3%

  if (isHighCoupon) {
    // Colonne "Coupon ≥ 3%"
    if (residualYears <= 1.0 / 12.0) return 0.0000; // ≤ 1 mois
    if (residualYears <= 3.0 / 12.0) return 0.0020; // 1-3 mois
    if (residualYears <= 6.0 / 12.0) return 0.0040; // 3-6 mois
    if (residualYears <= 12.0 / 12.0) return 0.0070; // 6-12 mois
    if (residualYears <= 2.0) return 0.0125; // 1-2 ans
    if (residualYears <= 3.0) return 0.0175; // 2-3 ans
    if (residualYears <= 4.0) return 0.0225; // 3-4 ans
    if (residualYears <= 5.0) return 0.0275; // 4-5 ans
    if (residualYears <= 7.0) return 0.0325; // 5-7 ans
    if (residualYears <= 10.0) return 0.0375; // 7-10 ans
    if (residualYears <= 15.0) return 0.0450; // 10-15 ans
    if (residualYears <= 20.0) return 0.0525; // 15-20 ans
    return 0.0600; // > 20 ans
  } else {
    // Colonne "Coupon < 3%"
    if (residualYears <= 1.0 / 12.0) return 0.0000; // ≤ 1 mois
    if (residualYears <= 3.0 / 12.0) return 0.0020; // 1-3 mois
    if (residualYears <= 6.0 / 12.0) return 0.0040; // 3-6 mois
    if (residualYears <= 12.0 / 12.0) return 0.0070; // 6-12 mois
    if (residualYears <= 1.9) return 0.0125; // 1,0-1,9 ans
    if (residualYears <= 2.8) return 0.0175; // 1,9-2,8 ans
    if (residualYears <= 3.6) return 0.0225; // 2,8-3,6 ans
    if (residualYears <= 4.3) return 0.0275; // 3,6-4,3 ans
    if (residualYears <= 5.7) return 0.0325; // 4,3-5,7 ans
    if (residualYears <= 7.3) return 0.0375; // 5,7-7,3 ans
    if (residualYears <= 9.3) return 0.0450; // 7,3-9,3 ans
    if (residualYears <= 10.6) return 0.0525; // 9,3-10,6 ans
    if (residualYears <= 12.0) return 0.0600; // 10,6-12 ans
    if (residualYears <= 20.0) return 0.0800; // 12-20 ans
    return 0.1250; // > 20 ans
  }
}

/// Identifie la catégorie réglementaire d'un titre
_MarketSpecificCategory _identifySpecificCategory(
  MarketPortfolioRecord record,
  _MarketCreditQuality quality,
) {
  // 1. État UEMOA FCFA
  if (_marketIsUemoaSovereignFcfa(record)) {
    return _MarketSpecificCategory.uemoaSovereignXof;
  }

  // 2. Titre souverain (non-UEMOA ou devises autres que XOF)
  if (_marketIsSovereignDebt(record)) {
    return _MarketSpecificCategory.sovereignDebt;
  }

  // 3. Titre éligible (notations AAA-BBB- + institutions multilatérales)
  if (_marketIsEligibleDebt(record, quality)) {
    return _MarketSpecificCategory.eligibleDebt;
  }

  // 4. Autre émetteur
  return _MarketSpecificCategory.otherDebt;
}

// ===========================================================================

double marketSpecificDebtRiskWeight(MarketPortfolioRecord record) {
  final quality = _marketCreditQuality(record.rating);
  final residualYears = _bondRecordResidualYears(record);
  final category = _identifySpecificCategory(record, quality);
  return _getSpecificRiskWeight(category, quality, residualYears);
}

String marketSpecificDebtRiskCategoryLabel(MarketPortfolioRecord record) {
  final quality = _marketCreditQuality(record.rating);
  final category = _identifySpecificCategory(record, quality);
  switch (category) {
    case _MarketSpecificCategory.uemoaSovereignXof:
      return 'Souverain UEMOA';
    case _MarketSpecificCategory.sovereignDebt:
      return 'Autre Souverain';
    case _MarketSpecificCategory.eligibleDebt:
      return 'Émetteur Éligible';
    case _MarketSpecificCategory.otherDebt:
      return 'Autre Émetteur';
  }
}

_MarketGeneralRiskBucket _marketGeneralRiskBucket(
  MarketPortfolioRecord record,
) {
  final years = math.max(0.0, _bondRecordResidualYears(record)).toDouble();

  // Seuils et poids BCEAO pour le risque général (approche standard)
  const thresholds = [
    1.0 / 12.0, // ≤ 1 mois
    3.0 / 12.0, // ≤ 3 mois
    6.0 / 12.0, // ≤ 6 mois
    12.0 / 12.0, // ≤ 1 an (12 mois)
    2.0, // ≤ 2 ans
    3.0, // ≤ 3 ans
    4.0, // ≤ 4 ans
    5.0, // ≤ 5 ans
    7.0, // ≤ 7 ans
    10.0, // ≤ 10 ans
    15.0, // ≤ 15 ans
    20.0, // ≤ 20 ans
    double.infinity, // > 20 ans
  ];

  const weights = [
    0.0000, // ≤ 1 mois = 0.00%
    0.0020, // 1-3 mois = 0.20%
    0.0040, // 3-6 mois = 0.40%
    0.0070, // 6-12 mois = 0.70%
    0.0125, // 1-2 ans = 1.25%
    0.0175, // 2-3 ans = 1.75%
    0.0225, // 3-4 ans = 2.25%
    0.0275, // 4-5 ans = 2.75%
    0.0325, // 5-7 ans = 3.25%
    0.0375, // 7-10 ans = 3.75%
    0.0450, // 10-15 ans = 4.50%
    0.0525, // 15-20 ans = 5.25%
    0.0600, // > 20 ans = 6.00%
  ];

  var index = thresholds.indexWhere((threshold) => years <= threshold);
  if (index < 0) index = thresholds.length - 1;

  // Zones pour les compensations: court terme (1-4), moyen terme (5-9), long terme (10-13)
  final zone = index <= 3
      ? 1
      : index <= 8
          ? 2
          : 3;

  return _MarketGeneralRiskBucket(
    index: index,
    zone: zone,
    weight: weights[index],
  );
}

bool _marketIsUemoaSovereignFcfa(MarketPortfolioRecord record) {
  return _marketIsSovereignDebt(record) &&
      _marketIsUemoaCountry(record.issuerCountryIso3) &&
      normalizeCurrencyCode(record.currency) == 'XOF';
}

bool _marketIsSovereignDebt(MarketPortfolioRecord record) {
  final text = _foldMarketText(
    [
      record.issuer,
      record.instrumentType,
      record.instrumentCode,
      record.issuerCountry,
    ].join(' '),
  );
  return text.contains('tresor') ||
      text.contains('etat') ||
      text.contains('republique') ||
      text.contains('souverain') ||
      text.contains('ministere') ||
      text.contains('obligation du tresor') ||
      text.contains('bon du tresor') ||
      text == 'bt' ||
      text == 'ot' ||
      text.contains(' bt ') ||
      text.contains(' ot ');
}

bool _marketIsEligibleDebt(
  MarketPortfolioRecord record,
  _MarketCreditQuality quality,
) {
  if (quality == _MarketCreditQuality.aaaToAa ||
      quality == _MarketCreditQuality.aToBbb) {
    return true;
  }
  final text = _foldMarketText('${record.issuer} ${record.instrumentType}');
  return text.contains('boad') ||
      text.contains('bceao') ||
      text.contains('bad') ||
      text.contains('bid') ||
      text.contains('bird') ||
      text.contains('banque mondiale') ||
      text.contains('multilaterale') ||
      text.contains('organisme public');
}

bool _marketIsUemoaCountry(String iso3) {
  return const {'BEN', 'BFA', 'CIV', 'GNB', 'MLI', 'NER', 'SEN', 'TGO'}
      .contains(iso3.toUpperCase());
}

_MarketCreditQuality _marketCreditQuality(String rating) {
  final normalized = _foldMarketText(rating)
      .toUpperCase()
      .replaceAll(' ', '')
      .replaceAll('NOTÉ', 'NOTE');
  if (normalized.isEmpty ||
      normalized.contains('NONNOTE') ||
      normalized.contains('SANSNOTE') ||
      normalized.contains('NR')) {
    return _MarketCreditQuality.unrated;
  }
  if (normalized.contains('SOUSB-') ||
      normalized.contains('<B-') ||
      normalized.startsWith('CCC') ||
      normalized.startsWith('CC') ||
      normalized == 'C' ||
      normalized == 'D') {
    return _MarketCreditQuality.belowB;
  }
  if (const {'AAA', 'AA+', 'AA', 'AA-', 'AAA/AA'}.contains(normalized)) {
    return _MarketCreditQuality.aaaToAa;
  }
  if (const {'A+', 'A', 'A-', 'BBB+', 'BBB', 'BBB-'}.contains(normalized)) {
    return _MarketCreditQuality.aToBbb;
  }
  if (const {'BB+', 'BB', 'BB-', 'B+', 'B', 'B-'}.contains(normalized)) {
    return _MarketCreditQuality.bbToB;
  }
  return _MarketCreditQuality.unrated;
}

const List<String> marketBondPortfolioRequiredHeaders = [
  'ID Titre',
  'Date d\'analyse',
  'Pays émetteur',
  'Zone',
  'Type d\'instrument',
  'Code type d\'instrument',
  'Emetteur',
  'Mode de Placement',
  'Notation externe_S&P',
  'Notation externe_Moody\'s',
  'Notation externe_Fitch',
  'La pire notation externe',
  'Notation Interne',
  'Intention comptable',
  'Classification des titres',
  'Date d\'émission',
  'Devise',
  'Valeur nominale unitaire',
  'quantités',
  'Capital initial',
  'Prix d\'émission',
  'Prime d\'émission',
  'Prix de remboursement',
  'Prime de remboursement',
  'Date d\'échéance',
  'Coupon (%)',
  'Profil d\'amortissement',
  'Fréquence de paiement des intérêts',
  'Maturité (mois)',
  'Maturité résiduelle (mois)',
];

const List<String> marketEquityPortfolioRequiredHeaders = [
  'ID Instrument',
  'Pays / marché',
  'Zone',
  'Type d\'instrument',
  'Code type d\'instrument',
  'Émetteur / Société',
  'Ticker',
  'ISIN',
  'Bourse',
  'Secteur',
  'Devise',
  'Classification du titre',
  'Intention comptable',
  'Date d\'acquisition',
  'Quantité',
  'Prix d\'achat unitaire',
  'Coût d\'acquisition',
  'Date de valorisation',
  'Cours actuel',
  'Valeur de marché',
  'Plus/(moins)-value latente',
  'Rendement latent (%)',
  'Dividende par action',
  'Rendement dividende (%)',
  'P/E',
  'Bêta',
];

const List<String> marketPortfolioRequiredHeaders =
    marketBondPortfolioRequiredHeaders;

class MarketImportInspection {
  const MarketImportInspection({
    required this.portfolioType,
    required this.fileName,
    required this.valid,
    required this.sheetFound,
    required this.sheetCount,
    required this.rowCount,
    required this.detectedHeaders,
    required this.missingHeaders,
    required this.errors,
  });

  final MarketPortfolioType portfolioType;
  final String fileName;
  final bool valid;
  final bool sheetFound;
  final int sheetCount;
  final int rowCount;
  final List<String> detectedHeaders;
  final List<String> missingHeaders;
  final List<String> errors;
}

class MarketPortfolioRecord {
  MarketPortfolioRecord({
    required this.portfolioType,
    required Map<String, Object?> values,
  }) : values = _normalizeMapKeys(values);

  final MarketPortfolioType portfolioType;
  final Map<String, Object?> values;

  static Map<String, Object?> _normalizeMapKeys(Map<String, Object?> rawMap) {
    final cleanMap = Map<String, Object?>.from(rawMap);
    for (final entry in rawMap.entries) {
      final cleanKey = _normalizeKeyName(entry.key);
      if (cleanKey != entry.key) {
        cleanMap[cleanKey] = entry.value;
      }
      final lower = entry.key.toLowerCase();
      if (lower.startsWith('quantit') ||
          lower.startsWith('qty') ||
          lower.startsWith('qt')) {
        cleanMap['quantités'] = entry.value;
        cleanMap['Quantité'] = entry.value;
      }
    }
    return cleanMap;
  }

  static String _normalizeKeyName(String key) {
    String normalized = key
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[ÀÂÄ]'), 'A')
        .replaceAll(RegExp(r'[ûüù]'), 'u')
        .replaceAll(RegExp(r'[îïì]'), 'i')
        .replaceAll(RegExp(r'[ôöò]'), 'o')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    normalized = normalized.replaceAll(RegExp(r'[\x00-\x1f\ufffd]'), '');

    final lower = normalized.toLowerCase();
    if (lower.startsWith('quantit')) {
      return 'quantités';
    }
    if (lower.startsWith('emetteur') || lower.startsWith('metteur')) {
      return 'Emetteur';
    }
    if (lower.contains('pays') &&
        (lower.contains('emett') ||
            lower.contains('marche') ||
            lower.contains('mettour'))) {
      return 'Pays émetteur';
    }
    if (lower.contains('date') &&
        (lower.contains('emiss') || lower.contains('emision'))) {
      return 'Date d\'émission';
    }
    if (lower.contains('date') &&
        (lower.contains('echean') || lower.contains('echeanc'))) {
      return 'Date d\'échéance';
    }
    if (lower.contains('valeur nominale') ||
        lower.contains('nominal unitaire')) {
      return 'Valeur nominale unitaire';
    }
    if (lower.contains('valeur actualis') ||
        lower.contains('valeur actuell') ||
        lower.contains('present value')) {
      return 'Valeur actualisée';
    }
    if (lower.contains('frequence') && lower.contains('paiement')) {
      return 'Fréquence de paiement des intérêts';
    }
    // La variante « code » doit être testée AVANT la règle générale : sinon
    // « Code type d'instrument » (qui contient aussi « type » et « instrument »)
    // serait renommé en « Type d'instrument » et écraserait le libellé complet
    // par le code abrégé.
    if (lower.contains('code') &&
        lower.contains('type') &&
        lower.contains('instrument')) {
      return 'Code type d\'instrument';
    }
    if (lower.contains('type') && lower.contains('instrument')) {
      return 'Type d\'instrument';
    }

    if (lower == 'quantite') return 'Quantité';
    if (lower == 'valeur nominale unitaire') return 'Valeur nominale unitaire';
    if (lower == 'capital initial') return 'Capital initial';
    if (lower == 'prix demission') return 'Prix d\'émission';
    if (lower == 'prime demission') return 'Prime d\'émission';
    if (lower == 'prix de remboursement') return 'Prix de remboursement';
    if (lower == 'prime de remboursement') return 'Prime de remboursement';
    if (lower == 'profil damortissement') return 'Profil d\'amortissement';
    if (lower == 'capital restant du') return 'Capital restant dû';
    if (lower == 'valeur actualisee') return 'Valeur actualisée';
    if (lower == 'coupon (%)') return 'Coupon (%)';
    if (lower == 'nombre dactions') return 'Nombre d\'actions';
    if (lower == 'cours actuel') return 'Cours actuel';
    if (lower == 'valeur de marche') return 'Valeur de marché';
    if (lower == 'volatilite annualisee (%)')
      return 'Volatilité annualisée (%)';
    if (lower == 'prix dachat unitaire') return 'Prix d\'achat unitaire';
    if (lower == 'cout dacquisition') return 'Coût d\'acquisition';
    if (lower == 'date danalyse') return 'Date d\'analyse';
    if (lower == 'la pire notation externe') return 'La pire notation externe';
    if (lower == 'maturite (mois)') return 'Maturité (mois)';
    if (lower == 'maturite residuelle (mois)')
      return 'Maturité résiduelle (mois)';

    return key;
  }

  String get issuer => _textAny(
        const ['Emetteur', 'Émetteur / Société'],
        fallback: 'Non renseigné',
      );
  String get issuerCountry => _text('Pays émetteur', fallback: '').trim();
  String get issuerCountryIso3 => _marketCountryIso3(issuerCountry);
  String get issuerAnalysisKey => _marketIssuerAnalysisKey(this);
  String get issuerAnalysisLabel => _marketIssuerAnalysisLabel(this);

  /// Code ISO3 du marché national/régional du titre (Art. 400-401).
  /// Lit « Pays émetteur » (obligations) ou « Pays / marché » (actions).
  String get marketCountryIso3 => _marketCountryIso3(
      _textAny(const ['Pays émetteur', 'Pays / marché'], fallback: '').trim());

  /// Intention comptable déclarée (Trading/HFT/FVTPL, HTM, AFS/FVOCI…).
  String get accountingIntent => _text('Intention comptable', fallback: '');

  /// Position relevant du portefeuille de négociation (Art. 316(b), 321).
  /// HTM/AFS relèvent du portefeuille bancaire ; intention inconnue = incluse
  /// par prudence (la charge taux/actions s'applique alors).
  bool get isTradingBook => _marketIsTradingBookIntent(accountingIntent);
  String get titleId => _text('ID Titre', fallback: '').trim();
  String get instrumentType =>
      _text('Type d\'instrument', fallback: 'Instrument');
  String get zone => _text('Zone', fallback: 'Non renseignée');
  String get currency => _text('Devise', fallback: 'XOF');

  /// Taux de change à l'acquisition (1 unité de devise = X XOF), lu à l'import
  /// s'il est fourni. Sert à calculer la variation de change et le gain/perte
  /// latent par rapport au taux courant (spot). Retourne 0 si la colonne est
  /// absente : l'analyse retombe alors sur le taux courant (variation nulle).
  double get acquisitionExchangeRate => _numberAny(const [
        'Taux d\'acquisition',
        'Taux acquisition',
        'Taux historique',
        'Taux de change acquisition',
        'Cours d\'acquisition',
        'Taux d\'achat',
        'Cours d\'achat',
      ]);
  String get rating => _text('La pire notation externe', fallback: '');
  String get instrumentCode =>
      _text('Code type d\'instrument', fallback: '').trim();
  DateTime? get analysisDate => _dateValue(values['Date d\'analyse']);
  DateTime? get issueDate => _dateValue(values['Date d\'émission']);
  DateTime? get maturityDate => _dateValue(values['Date d\'échéance']);
  DateTime get resolvedAnalysisDate => _marketDateOnly(_marketToday());
  bool get isActiveAtAnalysisDate => _bondIsActiveAtAnalysisDate(this);
  bool get isMaturedAtAnalysisDate => _bondIsMaturedAtAnalysisDate(this);

  double get nominalUnit => _number('Valeur nominale unitaire');
  double get quantity => _number('quantités');
  double get capitalInitial => _number('Capital initial');
  double get issuePrice => _number('Prix d\'émission');
  double get issuePremium => _number('Prime d\'émission');
  double get redemptionPrice => _number('Prix de remboursement');
  double get redemptionPremium => _number('Prime de remboursement');
  String get amortizationProfile =>
      _text('Profil d\'amortissement', fallback: '').trim();
  double get capitalRemainingDue => _numberAnyExact(const [
        'Capital restant dû',
        'Capital restant dû (MD)',
        'Capital restant dû (Md)',
        'Capital restant du',
        'Capital restant du (MD)',
        'Capital restant du (Md)',
        'CRD',
        'CRD (MD)',
        'CRD (Md)',
      ]);
  double get presentValue => _numberAnyExact(const [
        'Valeur actualisée',
        'Valeur actualisée (MD)',
        'Valeur actualisée (Md)',
        'Valeur actualisee',
        'Valeur actualisee (MD)',
        'Valeur actualisee (Md)',
        'Valeur actuelle',
        'Valeur actuelle (MD)',
        'Valeur actuelle (Md)',
        'PV',
        'PV (MD)',
        'PV (Md)',
        'Present Value',
      ]);
  double get coupon => _percentNumber('Coupon (%)');
  double get spread => _numberAnyExact(const [
        'Spread',
        'SPREAD',
        'Spread (%)',
        'SPREAD (%)',
      ]);
  double get yieldToMaturity => _rateAny(const [
        'YTM',
        'Yield To Maturity',
        'Taux actuariel',
        'Rendement actuariel',
        'Taux de rendement actuariel',
      ]);
  double get analyticalYieldToMaturity => _bondApproximateYield(this);
  double get bondMacaulayDuration => _bondMacaulayDuration(this);
  double get bondModifiedDuration => _bondModifiedDuration(this);
  double get bondCashflowPresentValue => _bondCashflowPresentValue(this);
  double get bondCashflowConvexity => _bondCashflowConvexity(this);
  double get resolvedCapitalRemainingDue => _bondOutstandingCapital(this);
  double get capitalAlreadyRepaid {
    final initialCapital = _bondInitialCapital(this);
    if (initialCapital <= 0) return 0;
    return math
        .max(0.0, initialCapital - resolvedCapitalRemainingDue)
        .toDouble();
  }

  double get maturityMonths {
    final derivedMonths = _bondDateMaturityMonths(issueDate, maturityDate);
    if (derivedMonths > 0) return derivedMonths;
    return _monthNumber('Maturité (mois)');
  }

  double get residualMaturityMonths {
    final derivedMonths =
        _bondDateMaturityMonths(resolvedAnalysisDate, maturityDate);
    if (maturityDate != null) return derivedMonths;
    return _monthNumber('Maturité résiduelle (mois)');
  }

  double get shares => _numberAny(const ['Nombre d\'actions', 'Quantité']);
  double get marketPrice =>
      _numberAny(const ['Prix de marché', 'Cours actuel']);
  double get marketValue => _number('Valeur de marché');
  double get beta => _number('Bêta');
  double get annualizedVolatilityInput =>
      _percentNumber('Volatilité annualisée (%)');
  double get expectedReturnInput {
    final explicit = _percentNumber('Rendement attendu (%)');
    if (explicit != 0) return explicit;
    return _percentNumber('Rendement latent (%)') +
        _percentNumber('Rendement dividende (%)');
  }

  int get couponPaymentsPerYear {
    final frequency = _text(
      'Fréquence de paiement des intérêts',
      fallback: '',
    ).toLowerCase();
    if (frequency.contains('mens')) return 12;
    if (frequency.contains('trim')) return 4;
    if (frequency.contains('semes') || frequency.contains('semi')) return 2;
    return 1;
  }

  double get priceObservation {
    final explicit = _numberAny(const [
      'Prix de marché',
      'Prix marche',
      'Prix actuel',
      'Prix de valorisation',
      'Prix de clôture',
      'Cours',
      'Cours actuel',
      'Valeur liquidative',
    ]);
    if (explicit > 0) return explicit;
    final quantityValue =
        portfolioType == MarketPortfolioType.equities ? shares : quantity;
    final amount = valuationAmount;
    if (quantityValue > 0 && amount > 0) return amount / quantityValue;
    return 0;
  }

  double get valuationAmount {
    final explicit = _numberAny(const [
      'Valeur de marché',
      'Valeur actuelle',
      'Valeur de valorisation',
      'Valeur marché',
    ]);
    if (explicit > 0) return explicit;
    return exposureAmount;
  }

  String get returnSeriesKey {
    if (titleId.isNotEmpty) return titleId;
    if (instrumentCode.isNotEmpty) return instrumentCode;
    final issuerText = issuer.trim();
    if (issuerText.isNotEmpty && issuerText != 'Non renseigné') {
      return issuerText;
    }
    return '';
  }

  double get exposureAmount {
    if (portfolioType == MarketPortfolioType.equities) {
      if (marketValue > 0) return marketValue;
      final acquisitionCost = _number('Coût d\'acquisition');
      if (acquisitionCost > 0) return acquisitionCost;
      if (capitalInitial > 0) return capitalInitial;
      if (shares > 0 && marketPrice > 0) return shares * marketPrice;
      if (nominalUnit > 0 && quantity > 0) return nominalUnit * quantity;
      return 0;
    }
    if (capitalInitial > 0) return capitalInitial;
    if (nominalUnit > 0 && quantity > 0) return nominalUnit * quantity;
    return 0;
  }

  String _text(String key, {required String fallback}) {
    final value = values[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double _number(String key) => _toDouble(values[key]);
  double _numberAny(List<String> keys) {
    for (final key in keys) {
      final value = _number(key);
      if (value != 0) return value;
    }
    return 0;
  }

  double _numberAnyExact(List<String> keys) {
    for (final key in keys) {
      if (!values.containsKey(key) || values[key] == null) continue;
      return _number(key);
    }
    return 0;
  }

  double _rateAny(List<String> keys) {
    for (final key in keys) {
      final raw = _number(key);
      if (raw > 0) return raw > 1 ? raw / 100 : raw;
    }
    return 0;
  }

  String _textAny(List<String> keys, {required String fallback}) {
    for (final key in keys) {
      final value = values[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  double _percentNumber(String key) {
    final raw = _number(key);
    if (raw <= 0) return 0;
    return raw > 1 ? raw / 100 : raw;
  }

  double _monthNumber(String key) => _marketCeilMonthValue(_number(key));
}

const int _marketDatasetContentSignatureVersion = 2;
const int _marketFnvOffsetBasis = 0x811c9dc5;
const int _marketFnvPrime = 0x01000193;
const int _marketFnvMask = 0xffffffff;

int _marketSignatureAddString(int hash, String value) {
  var next = hash;
  for (final unit in value.codeUnits) {
    next ^= unit;
    next = (next * _marketFnvPrime) & _marketFnvMask;
  }
  next ^= 0x1f;
  return (next * _marketFnvPrime) & _marketFnvMask;
}

String _marketDatasetContentSignature(MarketPortfolioDataset dataset) {
  var hash = _marketFnvOffsetBasis;
  hash = _marketSignatureAddString(
    hash,
    'v$_marketDatasetContentSignatureVersion',
  );
  hash = _marketSignatureAddString(hash, dataset.portfolioType.storageKey);
  hash = _marketSignatureAddString(hash, dataset.fileName);
  hash = _marketSignatureAddString(hash, dataset.headers.length.toString());
  for (final header in dataset.headers) {
    hash = _marketSignatureAddString(hash, header);
  }
  hash = _marketSignatureAddString(hash, dataset.records.length.toString());
  for (final record in dataset.records) {
    hash = _marketSignatureAddString(hash, record.portfolioType.storageKey);
    final keys = record.values.keys.toList(growable: false)..sort();
    hash = _marketSignatureAddString(hash, keys.length.toString());
    for (final key in keys) {
      hash = _marketSignatureAddString(hash, key);
      hash =
          _marketSignatureAddString(hash, record.values[key]?.toString() ?? '');
    }
  }
  hash = _marketSignatureAddString(
    hash,
    dataset.bondCapitalRemainingDue.toStringAsFixed(6),
  );
  hash = _marketSignatureAddString(
    hash,
    dataset.bondCashflowPresentValue.toStringAsFixed(6),
  );
  hash = _marketSignatureAddString(
    hash,
    dataset.bondCashflowMacaulayDuration.toStringAsFixed(10),
  );
  hash = _marketSignatureAddString(
    hash,
    dataset.bondCashflowModifiedDuration.toStringAsFixed(10),
  );
  hash = _marketSignatureAddString(
    hash,
    dataset.bondCashflowConvexity.toStringAsFixed(10),
  );
  final metricsDate = dataset.bondCashflowMetricsDate;
  hash = _marketSignatureAddString(
    hash,
    metricsDate == null
        ? ''
        : '${metricsDate.year}-${metricsDate.month}-${metricsDate.day}',
  );
  return hash.toRadixString(16).padLeft(8, '0');
}

class MarketPortfolioDataset {
  MarketPortfolioDataset({
    required this.portfolioType,
    required this.fileName,
    required this.importedAt,
    required this.headers,
    required this.records,
    this.bondCapitalRemainingDue = 0,
    this.bondCashflowPresentValue = 0,
    this.bondCashflowMacaulayDuration = 0,
    this.bondCashflowModifiedDuration = 0,
    this.bondCashflowConvexity = 0,
    this.bondCashflowMetricsDate,
  });

  final MarketPortfolioType portfolioType;
  final String fileName;
  final DateTime importedAt;
  final List<String> headers;
  final List<MarketPortfolioRecord> records;
  final double bondCapitalRemainingDue;
  final double bondCashflowPresentValue;
  final double bondCashflowMacaulayDuration;
  final double bondCashflowModifiedDuration;
  final double bondCashflowConvexity;
  final DateTime? bondCashflowMetricsDate;

  int get rowCount => records.length;

  late final double totalExposure = _computeTotalExposure();
  late final double portfolioValue = totalExposure;
  late final double averageCoupon = _computeAverageCoupon();
  late final double weightedResidualYears = _computeWeightedResidualYears();
  late final double weightedMacaulayDuration =
      _computeWeightedMacaulayDuration();
  late final double weightedModifiedDuration =
      _computeWeightedModifiedDuration();
  late final double weightedBeta = _computeWeightedBeta();
  late final List<double> _historicalReturns =
      _computePortfolioHistoricalReturns();
  late final double annualizedVolatility = _computeAnnualizedVolatility();
  late final double expectedReturn = _computeExpectedReturn();
  late final double correlationProxy = _computeCorrelationProxy();
  late final double concentrationRatio = _computeConcentrationRatio();
  late final String dominantIssuer = _computeDominantIssuer();
  late final List<double> scenarioReturns = _computeScenarioReturns();
  late final List<double> scenarioLosses = _computeScenarioLosses();
  late final double scenarioVar99 = _computeScenarioVar99();
  late final double scenarioWorstLoss =
      scenarioLosses.isEmpty ? 0.0 : math.max(0.0, scenarioLosses.last);
  late final List<double> bondRateShockLosses = _computeBondRateShockLosses();
  late final double bondRateShockVar99 =
      _computeLossQuantile(bondRateShockLosses, 0.99);
  late final double bondRateShockWorstLoss = bondRateShockLosses.isEmpty
      ? 0.0
      : math.max(0.0, bondRateShockLosses.last).toDouble();
  late final MarketPrudentialCapitalResult prudentialCapital =
      calculateMarketPrudentialCapital(records: records);
  late final String contentSignature = _marketDatasetContentSignature(this);

  double get parametricRiskValue => portfolioValue;

  double get parametricModifiedDuration {
    if (bondCashflowModifiedDuration > 0 &&
        _isSameMarketDay(bondCashflowMetricsDate, _marketToday()) &&
        (weightedResidualYears <= 0 ||
            bondCashflowModifiedDuration <= weightedResidualYears + 0.000001)) {
      return bondCashflowModifiedDuration;
    }
    return weightedModifiedDuration;
  }

  MarketParametricVarResult calculateParametricVar({
    required double confidence,
    required int horizonDays,
    double portfolioScale = 1.0,
    double? annualVolatilityOverride,
    double? modifiedDurationOverride,
    double? correlationOverride,
    double? expectedReturnOverride,
    double riskFreeRate = 0,
  }) {
    final resolvedVolatility = annualVolatilityOverride ?? annualizedVolatility;
    return calculateMarketParametricVar(
      hasMarketData: records.isNotEmpty &&
          parametricRiskValue > 0 &&
          resolvedVolatility > 0,
      portfolioType: portfolioType,
      basePortfolioValue: parametricRiskValue,
      confidence: confidence,
      horizonDays: horizonDays,
      portfolioScale: portfolioScale,
      annualVolatility: resolvedVolatility,
      modifiedDuration: modifiedDurationOverride ?? parametricModifiedDuration,
      correlation: correlationOverride ?? correlationProxy,
      expectedReturn: expectedReturnOverride ?? expectedReturn,
      riskFreeRate: riskFreeRate,
    );
  }

  List<MarketParametricVarResult> calculateParametricVarHorizons({
    required double confidence,
    double portfolioScale = 1.0,
    double? annualVolatilityOverride,
    double? modifiedDurationOverride,
    double? correlationOverride,
    double? expectedReturnOverride,
    double riskFreeRate = 0,
    List<int> horizons = const [1, 3, 10, 21],
  }) {
    final resolvedVolatility = annualVolatilityOverride ?? annualizedVolatility;
    return calculateMarketParametricVarHorizons(
      hasMarketData: records.isNotEmpty &&
          parametricRiskValue > 0 &&
          resolvedVolatility > 0,
      portfolioType: portfolioType,
      basePortfolioValue: parametricRiskValue,
      confidence: confidence,
      portfolioScale: portfolioScale,
      annualVolatility: resolvedVolatility,
      modifiedDuration: modifiedDurationOverride ?? parametricModifiedDuration,
      correlation: correlationOverride ?? correlationProxy,
      expectedReturn: expectedReturnOverride ?? expectedReturn,
      riskFreeRate: riskFreeRate,
      horizons: horizons,
    );
  }

  double _computeTotalExposure() {
    final total = records.fold<double>(
      0,
      (sum, record) =>
          sum +
          (portfolioType == MarketPortfolioType.bonds
              ? _bondOutstandingCapital(record)
              : record.exposureAmount),
    );
    return math.max(0.0, total).toDouble();
  }

  double _computeAverageCoupon() {
    if (portfolioType == MarketPortfolioType.equities) return 0.0;
    var numerator = 0.0;
    var denominator = 0.0;
    for (final record in records) {
      final exposure = _bondOutstandingCapital(record);
      final coupon = _marketRateFraction(record.coupon);
      if (exposure <= 0 || coupon <= 0) continue;
      numerator += coupon * exposure;
      denominator += exposure;
    }
    return denominator <= 0 ? 0 : numerator / denominator;
  }

  double _computeWeightedResidualYears() {
    if (portfolioType == MarketPortfolioType.equities) {
      return weightedBeta;
    }
    var numerator = 0.0;
    var denominator = 0.0;
    for (final record in records) {
      final exposure = _bondOutstandingCapital(record);
      final years = _bondRecordResidualYears(record);
      if (exposure <= 0 || years <= 0) continue;
      numerator += years * exposure;
      denominator += exposure;
    }
    return denominator <= 0 ? 0 : numerator / denominator;
  }

  double _computeWeightedModifiedDuration() {
    if (portfolioType == MarketPortfolioType.equities) return 0;
    var numerator = 0.0;
    var denominator = 0.0;
    for (final record in records) {
      final exposure = _bondMarketValue(record);
      final duration = _bondModifiedDuration(record);
      if (exposure <= 0 || duration <= 0) continue;
      numerator += duration * exposure;
      denominator += exposure;
    }
    return denominator <= 0 ? 0 : numerator / denominator;
  }

  double _computeWeightedMacaulayDuration() {
    if (portfolioType == MarketPortfolioType.equities) return 0;
    var numerator = 0.0;
    var denominator = 0.0;
    for (final record in records) {
      final exposure = _bondMarketValue(record);
      final duration = _bondMacaulayDuration(record);
      if (exposure <= 0 || duration <= 0) continue;
      numerator += duration * exposure;
      denominator += exposure;
    }
    return denominator <= 0 ? 0 : numerator / denominator;
  }

  double _computeWeightedBeta() {
    if (records.isEmpty || totalExposure <= 0) return 1.0;
    final betaTotal = records.fold<double>(
      0,
      (sum, record) {
        final beta = record.beta > 0 ? record.beta : 1.0;
        return sum + beta * math.max(0.0, record.exposureAmount).toDouble();
      },
    );
    return (betaTotal / totalExposure).clamp(0.55, 2.2).toDouble();
  }

  double _computeAnnualizedVolatility() {
    final historicalReturns = _historicalReturns;
    if (historicalReturns.length >= 2) {
      return _standardDeviation(historicalReturns) * math.sqrt(252);
    }
    final weightedInput = _weightedPositiveAverage(
      (record) => record.annualizedVolatilityInput,
    );
    return weightedInput > 0 ? weightedInput : 0;
  }

  double _computeExpectedReturn() {
    final historicalReturns = _historicalReturns;
    if (historicalReturns.isNotEmpty) {
      final mean =
          historicalReturns.reduce((a, b) => a + b) / historicalReturns.length;
      return mean * 252;
    }
    if (portfolioType == MarketPortfolioType.equities) {
      final weightedInput =
          _weightedPositiveAverage((record) => record.expectedReturnInput);
      if (weightedInput > 0) {
        return weightedInput;
      }
      return 0;
    }
    var numerator = 0.0;
    var denominator = 0.0;
    for (final record in records) {
      final exposure = _bondMarketValue(record);
      final ytm = _bondApproximateYield(record);
      if (exposure <= 0 || ytm <= 0 || !ytm.isFinite) continue;
      numerator += ytm * exposure;
      denominator += exposure;
    }
    return denominator <= 0 ? averageCoupon : numerator / denominator;
  }

  double _computeCorrelationProxy() {
    final seriesByInstrument = _computeInstrumentReturnSeriesByDate();
    if (seriesByInstrument.length < 2) return 0;
    final exposureByKey = <String, double>{};
    for (final record in records) {
      final key = record.returnSeriesKey;
      final exposure = math.max(0.0, record.exposureAmount).toDouble();
      if (key.isEmpty || exposure <= 0) continue;
      exposureByKey.update(key, (value) => value + exposure,
          ifAbsent: () => exposure);
    }

    final entries = seriesByInstrument.entries.toList(growable: false);
    var weightedCorrelation = 0.0;
    var weightTotal = 0.0;
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final commonDates = entries[i]
            .value
            .keys
            .where(entries[j].value.containsKey)
            .toList(growable: false)
          ..sort();
        if (commonDates.length < 2) continue;
        final firstReturns = [
          for (final date in commonDates) entries[i].value[date]!,
        ];
        final secondReturns = [
          for (final date in commonDates) entries[j].value[date]!,
        ];
        final correlation = _pearsonCorrelation(firstReturns, secondReturns);
        if (!correlation.isFinite) continue;
        final pairWeight = math.sqrt(
          math.max(0.0, exposureByKey[entries[i].key] ?? 0).toDouble() *
              math.max(0.0, exposureByKey[entries[j].key] ?? 0).toDouble(),
        );
        if (pairWeight <= 0) continue;
        weightedCorrelation += correlation * pairWeight;
        weightTotal += pairWeight;
      }
    }
    return weightTotal <= 0 ? 0 : weightedCorrelation / weightTotal;
  }

  double _computeConcentrationRatio() {
    if (records.isEmpty || totalExposure <= 0) return 0;
    final byIssuer = <String, double>{};
    for (final record in records) {
      final exposure = portfolioType == MarketPortfolioType.bonds
          ? _bondOutstandingCapital(record)
          : record.exposureAmount;
      if (exposure <= 0) continue;
      byIssuer.update(
        portfolioType == MarketPortfolioType.bonds
            ? record.issuerAnalysisKey
            : record.issuer,
        (value) => value + exposure,
        ifAbsent: () => exposure,
      );
    }
    if (byIssuer.isEmpty) return 0;
    return byIssuer.values.reduce(math.max) / totalExposure;
  }

  String _computeDominantIssuer() {
    if (records.isEmpty || totalExposure <= 0) return 'Non disponible';
    final byIssuer = <String, double>{};
    final labelsByKey = <String, String>{};
    for (final record in records) {
      final exposure = portfolioType == MarketPortfolioType.bonds
          ? _bondOutstandingCapital(record)
          : record.exposureAmount;
      if (exposure <= 0) continue;
      final key = portfolioType == MarketPortfolioType.bonds
          ? record.issuerAnalysisKey
          : record.issuer;
      final label = portfolioType == MarketPortfolioType.bonds
          ? record.issuerAnalysisLabel
          : record.issuer;
      labelsByKey.putIfAbsent(key, () => label);
      byIssuer.update(
        key,
        (value) => value + exposure,
        ifAbsent: () => exposure,
      );
    }
    if (byIssuer.isEmpty) return 'Non disponible';
    final dominant = byIssuer.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );
    return labelsByKey[dominant.key] ?? dominant.key;
  }

  List<double> _computeScenarioReturns() {
    return _historicalReturns;
  }

  List<double> _computeScenarioLosses() {
    return [
      for (final value in scenarioReturns)
        if (value.isFinite) -value * portfolioValue,
    ]..sort();
  }

  double _computeScenarioVar99() {
    return _computeLossQuantile(scenarioLosses, 0.99);
  }

  List<double> _computeBondRateShockLosses() {
    if (portfolioType != MarketPortfolioType.bonds) return const [];
    final losses = <double>[];
    for (final record in records) {
      final exposure = math.max(0.0, record.exposureAmount).toDouble();
      final duration = _bondModifiedDuration(record);
      if (exposure <= 0 || duration <= 0) continue;
      final loss = duration * exposure * 0.01;
      if (loss.isFinite && loss > 0) losses.add(loss);
    }
    return losses..sort();
  }

  List<double> _computePortfolioHistoricalReturns() {
    final totalsByDate = <int, double>{};
    for (final record in records) {
      final date = record.analysisDate;
      if (date == null) continue;
      final amount = math.max(0.0, record.valuationAmount).toDouble();
      if (amount <= 0) continue;
      totalsByDate.update(
        _marketDateKey(date),
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }
    final dates = totalsByDate.keys.toList(growable: false)..sort();
    if (dates.length < 2) return const [];
    final returns = <double>[];
    for (var index = 1; index < dates.length; index++) {
      final previous = totalsByDate[dates[index - 1]] ?? 0;
      final current = totalsByDate[dates[index]] ?? 0;
      if (previous <= 0 || current <= 0) continue;
      final value = (current - previous) / previous;
      if (value.isFinite) returns.add(value);
    }
    return returns;
  }

  Map<String, Map<int, double>> _computeInstrumentReturnSeriesByDate() {
    final observations = <String, List<_MarketPriceObservation>>{};
    for (final record in records) {
      final key = record.returnSeriesKey;
      final date = record.analysisDate;
      final price = record.priceObservation;
      if (key.isEmpty || date == null || price <= 0) continue;
      observations
          .putIfAbsent(key, () => <_MarketPriceObservation>[])
          .add(_MarketPriceObservation(_marketDateKey(date), price));
    }

    final seriesByInstrument = <String, Map<int, double>>{};
    for (final entry in observations.entries) {
      final points = entry.value
        ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
      final returnsByDate = <int, double>{};
      for (var index = 1; index < points.length; index++) {
        final previous = points[index - 1].price;
        final current = points[index].price;
        if (previous <= 0 || current <= 0) continue;
        final value = (current - previous) / previous;
        if (value.isFinite) returnsByDate[points[index].dateKey] = value;
      }
      if (returnsByDate.length >= 2) {
        seriesByInstrument[entry.key] = returnsByDate;
      }
    }
    return seriesByInstrument;
  }

  double _weightedPositiveAverage(double Function(MarketPortfolioRecord) pick) {
    if (records.isEmpty || totalExposure <= 0) return 0;
    var numerator = 0.0;
    var denominator = 0.0;
    for (final record in records) {
      final value = pick(record);
      final weight = math.max(0.0, record.exposureAmount).toDouble();
      if (value > 0 && weight > 0) {
        numerator += value * weight;
        denominator += weight;
      }
    }
    return denominator <= 0 ? 0 : numerator / denominator;
  }
}

class _MarketPriceObservation {
  const _MarketPriceObservation(this.dateKey, this.price);

  final int dateKey;
  final double price;
}

enum _BondAmortizationKind { none, bullet, linear, constantAnnuity }

class _BondAmortizationSchedule {
  const _BondAmortizationSchedule({
    required this.totalPeriods,
    required this.remainingPeriods,
  });

  final int totalPeriods;
  final int remainingPeriods;

  int get paidPeriods =>
      (totalPeriods - remainingPeriods).clamp(0, totalPeriods).toInt();
}

int _marketDateKey(DateTime date) =>
    DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

DateTime _marketToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _marketDateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _isSameMarketDay(DateTime? left, DateTime right) {
  if (left == null) return false;
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

double _marketRateFraction(double raw) {
  if (!raw.isFinite) return 0;
  return raw.abs() > 1 ? raw / 100 : raw;
}

double _marketCeilMonthValue(double raw) {
  if (!raw.isFinite || raw <= 0) return 0;
  final rounded = raw.roundToDouble();
  if ((raw - rounded).abs() < 0.000001) return rounded;
  return raw.ceilToDouble();
}

double _bondDateMaturityMonths(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 0;
  return _bondCalendarMonthsCeil(start, end).toDouble();
}

bool _bondIsActiveAtAnalysisDate(MarketPortfolioRecord record) {
  final maturityDate = record.maturityDate;
  if (maturityDate == null) return false;
  return _marketDateOnly(maturityDate).isAfter(record.resolvedAnalysisDate);
}

bool _bondIsMaturedAtAnalysisDate(MarketPortfolioRecord record) {
  final maturityDate = record.maturityDate;
  if (maturityDate == null) return false;
  return !_marketDateOnly(maturityDate).isAfter(record.resolvedAnalysisDate);
}

double _bondRecordResidualYears(MarketPortfolioRecord record) {
  final months = _bondRecordResidualMonths(record);
  if (months > 0) return months / 12;
  return 0;
}

double _bondRecordResidualMonths(MarketPortfolioRecord record) {
  final importedMonths = record.residualMaturityMonths;
  return _marketCeilMonthValue(importedMonths);
}

double _bondNominalUnit(MarketPortfolioRecord record) {
  if (record.nominalUnit > 0) return record.nominalUnit;
  if (record.quantity > 0 && record.exposureAmount > 0) {
    return record.exposureAmount / record.quantity;
  }
  return 0;
}

double _bondPriceToUnitAmount(double rawPrice, double nominalUnit) {
  if (rawPrice <= 0) return 0;
  if (nominalUnit > 0 && rawPrice <= 200) {
    return nominalUnit * rawPrice / 100;
  }
  return rawPrice;
}

double _bondExplicitMarketUnitPrice(MarketPortfolioRecord record) {
  final nominal = _bondNominalUnit(record);
  final explicitMarketPrice = record._numberAny(const [
    'Prix de marché',
    'Prix marche',
    'Prix actuel',
    'Prix de valorisation',
    'Prix de clôture',
    'Cours',
    'Cours actuel',
    'Valeur liquidative',
  ]);
  final marketPrice = _bondPriceToUnitAmount(explicitMarketPrice, nominal);
  if (marketPrice > 0) return marketPrice;
  return 0;
}

double _bondPositionQuantity(MarketPortfolioRecord record) {
  if (record.quantity > 0) return record.quantity;
  final nominal = _bondNominalUnit(record);
  if (nominal > 0 && record.exposureAmount > 0) {
    return record.exposureAmount / nominal;
  }
  return 0;
}

double _bondOutstandingCapital(MarketPortfolioRecord record) {
  if (_bondIsMaturedAtAnalysisDate(record)) return 0;
  if (record.capitalRemainingDue > 0) return record.capitalRemainingDue;
  final amortizedCapital = _bondProfileOutstandingCapital(record);
  if (amortizedCapital != null) return amortizedCapital;
  final initialCapital = _bondInitialCapital(record);
  if (initialCapital > 0) return initialCapital;
  return math.max(0.0, record.exposureAmount).toDouble();
}

double _bondInitialCapital(MarketPortfolioRecord record) {
  if (record.capitalInitial > 0) return record.capitalInitial;
  final nominal = _bondNominalUnit(record);
  final quantity = _bondPositionQuantity(record);
  if (nominal > 0 && quantity > 0) return nominal * quantity;
  return 0;
}

double? _bondProfileOutstandingCapital(MarketPortfolioRecord record) {
  final initialCapital = _bondInitialCapital(record);
  if (initialCapital <= 0) return null;
  final kind = _bondAmortizationKind(record);
  if (kind == _BondAmortizationKind.none) return null;

  final schedule = _bondAmortizationSchedule(record);
  if (kind == _BondAmortizationKind.bullet) {
    if (schedule != null && schedule.remainingPeriods <= 0) return 0;
    return initialCapital;
  }
  if (schedule == null || schedule.totalPeriods <= 0) return null;
  if (schedule.remainingPeriods <= 0) return 0;
  if (schedule.paidPeriods <= 0) return initialCapital;

  final capital = switch (kind) {
    _BondAmortizationKind.linear =>
      initialCapital * schedule.remainingPeriods / schedule.totalPeriods,
    _BondAmortizationKind.constantAnnuity => _bondConstantAnnuityBalance(
        initialCapital: initialCapital,
        paidPeriods: schedule.paidPeriods,
        totalPeriods: schedule.totalPeriods,
        periodRate:
            _marketRateFraction(record.coupon) / record.couponPaymentsPerYear,
      ),
    _ => initialCapital,
  };
  if (!capital.isFinite) return initialCapital;
  return capital.clamp(0.0, initialCapital).toDouble();
}

_BondAmortizationKind _bondAmortizationKind(MarketPortfolioRecord record) {
  final profile = _foldMarketText(record.amortizationProfile);
  if (profile.isEmpty) return _BondAmortizationKind.none;
  if (profile.contains('in fine') ||
      profile.contains('bullet') ||
      profile.contains('zero coupon') ||
      profile.contains('zerocoupon') ||
      profile.contains('remboursement final') ||
      profile.contains('a l echeance') ||
      profile.contains('a echeance')) {
    return _BondAmortizationKind.bullet;
  }
  if (profile == 'constant' ||
      profile.contains('lineaire') ||
      profile.contains('linear') ||
      profile.contains('principal constant') ||
      profile.contains('capital constant') ||
      profile.contains('amortissement constant') ||
      profile.contains('amortissable') ||
      profile.contains('amorti')) {
    return _BondAmortizationKind.linear;
  }
  if (profile.contains('annuite') ||
      profile.contains('annuity') ||
      profile.contains('serie egale') ||
      profile.contains('echeance constante') ||
      profile.contains('paiement constant')) {
    return _BondAmortizationKind.constantAnnuity;
  }
  return _BondAmortizationKind.none;
}

_BondAmortizationSchedule? _bondAmortizationSchedule(
  MarketPortfolioRecord record,
) {
  final frequency = math.max(1, record.couponPaymentsPerYear);
  final periodMonths = math.max(1, (12 / frequency).round());
  final totalMonths = _bondTotalMaturityMonthsForSchedule(record);
  if (totalMonths <= 0) return null;

  final residualMonths = _bondResidualMaturityMonthsForSchedule(record);
  final totalPeriods = math.max(1, (totalMonths / periodMonths).ceil());
  final remainingPeriods = residualMonths <= 0
      ? 0
      : (residualMonths / periodMonths).ceil().clamp(0, totalPeriods).toInt();
  return _BondAmortizationSchedule(
    totalPeriods: totalPeriods,
    remainingPeriods: remainingPeriods,
  );
}

double _bondTotalMaturityMonthsForSchedule(MarketPortfolioRecord record) {
  if (record.maturityMonths > 0) return record.maturityMonths;
  final issueDate = record.issueDate;
  final maturityDate = record.maturityDate;
  if (issueDate == null || maturityDate == null) return 0;
  return _bondCalendarMonthsCeil(issueDate, maturityDate).toDouble();
}

double _bondResidualMaturityMonthsForSchedule(MarketPortfolioRecord record) {
  if (record.residualMaturityMonths > 0) return record.residualMaturityMonths;
  final analysisDate = record.analysisDate;
  final maturityDate = record.maturityDate;
  if (analysisDate == null || maturityDate == null) return 0;
  return _bondCalendarMonthsCeil(analysisDate, maturityDate).toDouble();
}

double _bondConstantAnnuityBalance({
  required double initialCapital,
  required int paidPeriods,
  required int totalPeriods,
  required double periodRate,
}) {
  if (paidPeriods <= 0) return initialCapital;
  if (paidPeriods >= totalPeriods) return 0;
  if (!periodRate.isFinite || periodRate <= 0) {
    return initialCapital * (totalPeriods - paidPeriods) / totalPeriods;
  }

  final annuityDenominator =
      1 - math.pow(1 + periodRate, -totalPeriods).toDouble();
  if (!annuityDenominator.isFinite || annuityDenominator <= 0) {
    return initialCapital;
  }
  final annuity = initialCapital * periodRate / annuityDenominator;
  final growth = math.pow(1 + periodRate, paidPeriods).toDouble();
  final balance =
      initialCapital * growth - annuity * ((growth - 1) / periodRate);
  return balance.isFinite ? balance : initialCapital;
}

int _bondCalendarMonthsCeil(DateTime start, DateTime end) {
  final startDate = _marketDateOnly(start);
  final endDate = _marketDateOnly(end);
  if (!endDate.isAfter(startDate)) return 0;
  var months =
      (endDate.year - startDate.year) * 12 + endDate.month - startDate.month;
  if (_bondAddMonths(startDate, months).isBefore(endDate)) months++;
  return math.max(0, months);
}

DateTime _bondAddMonths(DateTime date, int months) {
  final targetMonthIndex = date.month + months - 1;
  final year = date.year + targetMonthIndex ~/ 12;
  final month = targetMonthIndex % 12 + 1;
  final day = math.min(date.day, DateTime(year, month + 1, 0).day);
  return DateTime(year, month, day);
}

/// Détermine si une intention comptable relève du portefeuille de négociation
/// (Art. 316(b), 321). HTM/AFS = portefeuille bancaire. Intention inconnue ou
/// non reconnue = incluse par prudence (la charge taux/actions s'applique).
bool _marketIsTradingBookIntent(String intent) {
  final normalized = _foldMarketText(intent);
  if (normalized.isEmpty) return true;
  if (normalized.contains('trading') ||
      normalized.contains('hft') ||
      normalized.contains('fvtpl') ||
      normalized.contains('negociation') ||
      normalized.contains('transaction')) {
    return true;
  }
  if (normalized.contains('htm') ||
      normalized.contains('afs') ||
      normalized.contains('fvoci') ||
      normalized.contains('amorti') ||
      normalized.contains('jusqu') ||
      normalized.contains('disponible') ||
      normalized.contains('detenu') ||
      normalized.contains('bancaire')) {
    return false;
  }
  return true;
}

String _foldMarketText(String value) {
  return value
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[\u2019\u2018]'), "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _marketCountryIso3(String country) {
  return marketCountryIso3FromText(country);
}

String _marketIssuerAnalysisKey(MarketPortfolioRecord record) {
  final issuer = record.issuer.trim();
  final normalizedIssuer =
      issuer.isEmpty || issuer == 'Non renseigné' ? 'Non renseigné' : issuer;
  final countryCode = record.issuerCountryIso3;
  if (countryCode.isEmpty) return normalizedIssuer;
  return '$countryCode|$normalizedIssuer';
}

String _marketIssuerAnalysisLabel(MarketPortfolioRecord record) {
  final issuer = record.issuer.trim();
  final normalizedIssuer =
      issuer.isEmpty || issuer == 'Non renseigné' ? 'Non renseigné' : issuer;
  final countryCode = record.issuerCountryIso3;
  if (countryCode.isEmpty) return normalizedIssuer;
  return '$normalizedIssuer ($countryCode)';
}

double _bondMarketValue(MarketPortfolioRecord record) {
  if (_bondIsMaturedAtAnalysisDate(record)) return 0;
  if (record.presentValue > 0) return record.presentValue;
  final explicitValue = math.max(0.0, record.valuationAmount).toDouble();
  final marketPrice = _bondExplicitMarketUnitPrice(record);
  final quantity = _bondPositionQuantity(record);
  if (marketPrice > 0 && quantity > 0) return marketPrice * quantity;
  return explicitValue > 0 ? explicitValue : _bondOutstandingCapital(record);
}

double _bondRedemptionUnitAmount(MarketPortfolioRecord record) {
  final nominal = _bondNominalUnit(record);
  if (nominal <= 0) return 0;
  return nominal;
}

double _bondApproximateYield(MarketPortfolioRecord record) {
  final explicitYield = record.yieldToMaturity;
  final resolvedYield =
      explicitYield > 0 ? explicitYield : _marketRateFraction(record.coupon);
  return resolvedYield.clamp(0.0, 1.5).toDouble();
}

bool _bondIsZeroCouponProfile(MarketPortfolioRecord record) {
  final profile = _foldMarketText(record.amortizationProfile);
  return profile.contains('zero coupon') || profile.contains('zerocoupon');
}

double _bondCashflowCouponRate(MarketPortfolioRecord record) {
  if (_bondIsZeroCouponProfile(record)) return 0;
  return _marketRateFraction(record.coupon);
}

double _bondPresentValueForYield({
  required double nominal,
  required double redemption,
  required double couponRate,
  required int frequency,
  required int periods,
  required double annualYield,
}) {
  if (annualYield <= -0.999) return 0;
  final periodicBase = 1 + annualYield / frequency;
  if (periodicBase <= 0 || !periodicBase.isFinite) return 0;
  final couponCashFlow = couponRate * nominal / frequency;
  var presentValue = 0.0;
  for (var period = 1; period <= periods; period++) {
    final cashFlow = couponCashFlow + (period == periods ? redemption : 0);
    if (cashFlow <= 0) continue;
    final discount = math.pow(periodicBase, period).toDouble();
    if (discount <= 0) return 0;
    presentValue += cashFlow / discount;
  }
  return presentValue.isFinite ? presentValue : 0;
}

double _bondCashflowPresentValue(MarketPortfolioRecord record) {
  final years = _bondRecordResidualYears(record);
  final nominal = _bondNominalUnit(record);
  final redemption = _bondRedemptionUnitAmount(record);
  if (years <= 0 || nominal <= 0 || redemption <= 0) {
    return math.max(0.0, record.valuationAmount).toDouble();
  }

  final frequency = math.max(1, record.couponPaymentsPerYear);
  final periods = math.max(1, (years * frequency).ceil());
  final unitPresentValue = _bondPresentValueForYield(
    nominal: nominal,
    redemption: redemption,
    couponRate: _bondCashflowCouponRate(record),
    frequency: frequency,
    periods: periods,
    annualYield: _bondApproximateYield(record),
  );
  if (unitPresentValue <= 0 || !unitPresentValue.isFinite) {
    return math.max(0.0, record.valuationAmount).toDouble();
  }

  final quantity = record.quantity > 0
      ? record.quantity
      : record.exposureAmount > 0
          ? record.exposureAmount / nominal
          : 1.0;
  final value = unitPresentValue * math.max(0.0, quantity).toDouble();
  return value.isFinite ? math.max(0.0, value).toDouble() : 0;
}

double _bondMacaulayDuration(MarketPortfolioRecord record) {
  final years = _bondRecordResidualYears(record);
  final nominal = _bondNominalUnit(record);
  final redemption = _bondRedemptionUnitAmount(record);
  if (years <= 0 || nominal <= 0 || redemption <= 0) return 0;

  final frequency = math.max(1, record.couponPaymentsPerYear);
  final periods = math.max(1, (years * frequency).ceil());
  final couponCashFlow = _bondCashflowCouponRate(record) * nominal / frequency;
  final annualYield = _bondApproximateYield(record);
  final periodicBase = 1 + annualYield / frequency;
  if (periodicBase <= 0 || !periodicBase.isFinite) return 0;

  var macaulayNumerator = 0.0;
  var presentValue = 0.0;
  for (var period = 1; period <= periods; period++) {
    final time = math.min(period / frequency, years).toDouble();
    final cashFlow = couponCashFlow + (period == periods ? redemption : 0);
    if (cashFlow <= 0) continue;
    final discount = math.pow(periodicBase, period).toDouble();
    if (discount <= 0) continue;
    final discountedCashFlow = cashFlow / discount;
    presentValue += discountedCashFlow;
    macaulayNumerator += time * discountedCashFlow;
  }
  if (presentValue <= 0) return 0;
  final macaulay = macaulayNumerator / presentValue;
  return macaulay.isFinite ? math.max(0.0, macaulay).toDouble() : 0;
}

double _bondModifiedDuration(MarketPortfolioRecord record) {
  final macaulay = _bondMacaulayDuration(record);
  if (macaulay <= 0) return 0;
  final frequency = math.max(1, record.couponPaymentsPerYear);
  final modified = macaulay / (1 + _bondApproximateYield(record) / frequency);
  return modified.isFinite ? math.max(0.0, modified).toDouble() : 0;
}

double _bondCashflowConvexity(MarketPortfolioRecord record) {
  final years = _bondRecordResidualYears(record);
  final nominal = _bondNominalUnit(record);
  final redemption = _bondRedemptionUnitAmount(record);
  if (years <= 0 || nominal <= 0 || redemption <= 0) return 0;

  final frequency = math.max(1, record.couponPaymentsPerYear);
  final periods = math.max(1, (years * frequency).ceil());
  final annualYield = _bondApproximateYield(record);
  final periodicBase = 1 + annualYield / frequency;
  if (periodicBase <= 0 || !periodicBase.isFinite) return 0;
  final couponCashFlow = _bondCashflowCouponRate(record) * nominal / frequency;
  var convexityNumerator = 0.0;
  var presentValue = 0.0;

  for (var period = 1; period <= periods; period++) {
    final time = math.min(period / frequency, years).toDouble();
    final cashFlow = couponCashFlow + (period == periods ? redemption : 0);
    if (cashFlow <= 0) continue;
    final baseDiscount = math.pow(periodicBase, period).toDouble();
    if (baseDiscount <= 0 || !baseDiscount.isFinite) continue;
    presentValue += cashFlow / baseDiscount;
    convexityNumerator += cashFlow *
        time *
        (time + 1 / frequency) /
        (baseDiscount * periodicBase * periodicBase);
  }

  if (presentValue <= 0) return 0;
  final convexity = convexityNumerator / presentValue;
  return convexity.isFinite ? math.max(0.0, convexity).toDouble() : 0;
}

double _standardDeviation(List<double> values) {
  final filtered = values.where((value) => value.isFinite).toList();
  if (filtered.length < 2) return 0;
  final mean = filtered.reduce((a, b) => a + b) / filtered.length;
  final variance = filtered.fold<double>(
        0,
        (sum, value) => sum + math.pow(value - mean, 2).toDouble(),
      ) /
      filtered.length;
  return math.sqrt(math.max(0.0, variance).toDouble());
}

double _pearsonCorrelation(List<double> x, List<double> y) {
  final length = math.min(x.length, y.length);
  if (length < 2) return double.nan;
  final xValues = x.take(length).toList(growable: false);
  final yValues = y.take(length).toList(growable: false);
  final xMean = xValues.reduce((a, b) => a + b) / length;
  final yMean = yValues.reduce((a, b) => a + b) / length;
  var covariance = 0.0;
  var xVariance = 0.0;
  var yVariance = 0.0;
  for (var index = 0; index < length; index++) {
    final dx = xValues[index] - xMean;
    final dy = yValues[index] - yMean;
    covariance += dx * dy;
    xVariance += dx * dx;
    yVariance += dy * dy;
  }
  final denominator = math.sqrt(xVariance * yVariance);
  if (denominator <= 0) return double.nan;
  return covariance / denominator;
}

double _computeLossQuantile(List<double> sortedLosses, double confidence) {
  if (sortedLosses.isEmpty) return 0.0;
  final index = (sortedLosses.length * confidence).ceil() - 1;
  final boundedIndex = index.clamp(0, sortedLosses.length - 1).toInt();
  return math.max(0.0, sortedLosses[boundedIndex]).toDouble();
}

class MarketImportCommitResult {
  const MarketImportCommitResult({
    required this.dataset,
    required this.appended,
    required this.previousRowCount,
    required this.importedRowCount,
  });

  final MarketPortfolioDataset dataset;
  final bool appended;
  final int previousRowCount;
  final int importedRowCount;

  int get totalRowCount => dataset.rowCount;
  int get addedRowCount => appended ? importedRowCount : 0;
  int get replacedRowCount => appended ? 0 : previousRowCount;
}

class MarketDataSnapshot {
  const MarketDataSnapshot({
    required this.datasets,
    required this.activeType,
    required this.activeDataset,
    required this.contentSignature,
    required this.revision,
  });

  factory MarketDataSnapshot.fromDatasets(
    Map<MarketPortfolioType, MarketPortfolioDataset> datasets, {
    MarketPortfolioType? activeType,
    int revision = 0,
  }) {
    final normalized =
        Map<MarketPortfolioType, MarketPortfolioDataset>.unmodifiable(
      datasets,
    );
    final resolvedActiveType =
        activeType != null && normalized.containsKey(activeType)
            ? activeType
            : normalized.isEmpty
                ? null
                : normalized.keys.first;
    final parts = <String>[
      'market-snapshot-v1',
      for (final type in MarketPortfolioType.values)
        if (normalized[type] != null)
          '${type.storageKey}:${normalized[type]!.contentSignature}',
      'active:${resolvedActiveType?.storageKey ?? ''}',
    ];
    return MarketDataSnapshot(
      datasets: normalized,
      activeType: resolvedActiveType,
      activeDataset:
          resolvedActiveType == null ? null : normalized[resolvedActiveType],
      contentSignature: parts.join('|'),
      revision: revision,
    );
  }

  static final MarketDataSnapshot empty = MarketDataSnapshot.fromDatasets(
    const {},
  );

  final Map<MarketPortfolioType, MarketPortfolioDataset> datasets;
  final MarketPortfolioType? activeType;
  final MarketPortfolioDataset? activeDataset;
  final String contentSignature;
  final int revision;

  bool get hasData => datasets.values.any((dataset) => dataset.rowCount > 0);

  MarketPortfolioDataset? datasetFor(MarketPortfolioType type) {
    return datasets[type];
  }
}

class MarketDataImportStore {
  MarketDataImportStore._() {
    _restoreFuture = _restorePersistedDatasets().then((_) {});
  }

  static final MarketDataImportStore instance = MarketDataImportStore._();

  bool _hasLocalMutation = false;
  bool _sqlModeEnabled = false;
  RwaApiService? _sqlBackendApi;
  Future<void>? _sqlBackendFuture;
  late final Future<void> _restoreFuture;
  int _snapshotRevision = 0;

  Future<void> get initialized => _sqlBackendFuture ?? _restoreFuture;

  final ValueNotifier<MarketDataSnapshot> snapshotNotifier =
      ValueNotifier<MarketDataSnapshot>(MarketDataSnapshot.empty);
  final ValueNotifier<MarketPortfolioDataset?> datasetNotifier =
      ValueNotifier<MarketPortfolioDataset?>(null);
  final ValueNotifier<Map<MarketPortfolioType, MarketPortfolioDataset>>
      datasetsNotifier =
      ValueNotifier<Map<MarketPortfolioType, MarketPortfolioDataset>>(
    const {},
  );

  MarketPortfolioDataset? get dataset => snapshotNotifier.value.activeDataset;
  MarketPortfolioDataset? datasetFor(MarketPortfolioType type) =>
      snapshotNotifier.value.datasets[type];

  MarketDataSnapshot get snapshot => snapshotNotifier.value;

  MarketRiskOrchestrator get riskOrchestrator =>
      MarketRiskOrchestrator.instance;

  bool _publishDatasets(
    Map<MarketPortfolioType, MarketPortfolioDataset> datasets, {
    MarketPortfolioType? activeType,
    bool persist = false,
  }) {
    final next = MarketDataSnapshot.fromDatasets(
      datasets,
      activeType: activeType,
      revision: _snapshotRevision + 1,
    );
    final previous = snapshotNotifier.value;
    if (next.contentSignature == previous.contentSignature) {
      return false;
    }

    _snapshotRevision++;
    final published = MarketDataSnapshot.fromDatasets(
      next.datasets,
      activeType: next.activeType,
      revision: _snapshotRevision,
    );
    snapshotNotifier.value = published;
    datasetsNotifier.value = published.datasets;
    datasetNotifier.value = published.activeDataset;
    MarketRiskOrchestrator.instance.loadFromSnapshot(published);
    if (persist) _schedulePersistDatasets();
    return true;
  }

  Future<void> configureSqlBackend(RwaApiService api) {
    final existing = _sqlBackendFuture;
    if (existing != null) return existing;
    _sqlModeEnabled = true;
    _sqlBackendApi = api;
    _sqlBackendFuture = _restoreSqlDatasets(api);
    return _sqlBackendFuture!;
  }

  void addRecord(
      MarketPortfolioType portfolioType, Map<String, Object?> values) {
    final current = snapshotNotifier.value.datasets[portfolioType];
    final headers = current?.headers ?? portfolioType.requiredHeaders;
    final normalizedValues = {
      for (final header in portfolioType.requiredHeaders)
        header: values[header],
    };
    _normalizeMarketRowValues(
      normalizedValues,
      portfolioType: portfolioType,
    );
    final record = MarketPortfolioRecord(
      portfolioType: portfolioType,
      values: normalizedValues,
    );
    if (current == null) {
      final dataset = MarketPortfolioDataset(
        portfolioType: portfolioType,
        fileName: 'Saisie manuelle',
        importedAt: DateTime.now(),
        headers: headers,
        records: [record],
      );
      _publishDatasets(
        {
          ...snapshotNotifier.value.datasets,
          portfolioType: dataset,
        },
        activeType: portfolioType,
        persist: true,
      );
      return;
    }
    _publishDatasetWithRecords(
      current,
      current.records.toList(growable: true)..add(record),
    );
  }

  void updateRecord(
    MarketPortfolioType portfolioType,
    int index,
    Map<String, Object?> values,
  ) {
    final current = snapshotNotifier.value.datasets[portfolioType];
    if (current == null || index < 0 || index >= current.records.length) {
      return;
    }
    final records = current.records.toList(growable: true);
    final normalizedValues = {
      ...records[index].values,
      ...values,
    };
    _normalizeMarketRowValues(
      normalizedValues,
      portfolioType: portfolioType,
    );
    records[index] = MarketPortfolioRecord(
      portfolioType: portfolioType,
      values: normalizedValues,
    );
    _publishDatasetWithRecords(current, records);
  }

  void removeRecord(MarketPortfolioType portfolioType, int index) {
    final current = snapshotNotifier.value.datasets[portfolioType];
    if (current == null || index < 0 || index >= current.records.length) {
      return;
    }
    final records = current.records.toList(growable: true)..removeAt(index);
    _publishDatasetWithRecords(current, records);
  }

  Future<MarketImportInspection> inspectWorkbookAsync(
    Uint8List bytes,
    String fileName, {
    required MarketPortfolioType portfolioType,
  }) {
    return compute(
      _inspectWorkbookInIsolate,
      _MarketWorkbookParseRequest(
        bytes: bytes,
        fileName: fileName,
        portfolioTypeIndex: portfolioType.index,
      ),
      debugLabel: 'market-workbook-inspection',
    );
  }

  MarketImportInspection inspectWorkbook(
    Uint8List bytes,
    String fileName, {
    required MarketPortfolioType portfolioType,
  }) {
    try {
      return _inspectMarketWorkbook(bytes, fileName, portfolioType);
    } catch (error) {
      return MarketImportInspection(
        portfolioType: portfolioType,
        fileName: fileName,
        valid: false,
        sheetFound: false,
        sheetCount: 0,
        rowCount: 0,
        detectedHeaders: const [],
        missingHeaders: portfolioType.requiredHeaders,
        errors: ['Lecture du fichier impossible : $error'],
      );
    }
  }

  Future<MarketImportCommitResult> importWorkbookAsync(
    Uint8List bytes,
    String fileName, {
    required MarketPortfolioType portfolioType,
    bool append = false,
  }) async {
    await initialized;
    final parsed = await compute(
      _parseWorkbookInIsolate,
      _MarketWorkbookParseRequest(
        bytes: bytes,
        fileName: fileName,
        portfolioTypeIndex: portfolioType.index,
      ),
      debugLabel: 'market-workbook-import',
    );
    final result = _commitParsedWorkbook(
      parsed,
      fileName,
      portfolioType: portfolioType,
      append: append,
    );
    await _persistDatasets();
    return result;
  }

  MarketImportCommitResult importWorkbook(
    Uint8List bytes,
    String fileName, {
    required MarketPortfolioType portfolioType,
    bool append = false,
  }) {
    final parsed = _parseWorkbook(bytes, portfolioType);
    return _commitParsedWorkbook(
      parsed,
      fileName,
      portfolioType: portfolioType,
      append: append,
    );
  }

  MarketImportCommitResult _commitParsedWorkbook(
    _ParsedMarketWorkbook parsed,
    String fileName, {
    required MarketPortfolioType portfolioType,
    required bool append,
  }) {
    if (!parsed.sheetFound || parsed.missingHeaders.isNotEmpty) {
      throw StateError(
        'Le fichier ne respecte pas le modèle ${portfolioType.label} attendu.',
      );
    }
    final current = snapshotNotifier.value.datasets[portfolioType];
    final previousRowCount = current?.rowCount ?? 0;
    final records = append && current != null
        ? [...current.records, ...parsed.records]
        : parsed.records;
    final parsedCashflowMetricsDate =
        parsed.bondCashflowModifiedDuration > 0 ? _marketToday() : null;
    final dataset = MarketPortfolioDataset(
      portfolioType: portfolioType,
      fileName: fileName,
      importedAt: DateTime.now(),
      headers: parsed.headers,
      records: records,
      bondCapitalRemainingDue: append && current != null
          ? current.bondCapitalRemainingDue
          : parsed.bondCapitalRemainingDue,
      bondCashflowPresentValue: append && current != null
          ? current.bondCashflowPresentValue
          : parsed.bondCashflowPresentValue,
      bondCashflowMacaulayDuration: append && current != null
          ? current.bondCashflowMacaulayDuration
          : parsed.bondCashflowMacaulayDuration,
      bondCashflowModifiedDuration: append && current != null
          ? current.bondCashflowModifiedDuration
          : parsed.bondCashflowModifiedDuration,
      bondCashflowConvexity: append && current != null
          ? current.bondCashflowConvexity
          : parsed.bondCashflowConvexity,
      bondCashflowMetricsDate: append && current != null
          ? current.bondCashflowMetricsDate
          : parsedCashflowMetricsDate,
    );
    _publishDatasets(
      {
        ...snapshotNotifier.value.datasets,
        portfolioType: dataset,
      },
      activeType: portfolioType,
      persist: true,
    );
    return MarketImportCommitResult(
      dataset: dataset,
      appended: append,
      previousRowCount: previousRowCount,
      importedRowCount: parsed.records.length,
    );
  }

  void _publishDatasetWithRecords(
    MarketPortfolioDataset current,
    List<MarketPortfolioRecord> records,
  ) {
    final dataset = MarketPortfolioDataset(
      portfolioType: current.portfolioType,
      fileName: current.fileName,
      importedAt: DateTime.now(),
      headers: current.headers,
      records: records,
      bondCapitalRemainingDue: current.bondCapitalRemainingDue,
      bondCashflowPresentValue: current.bondCashflowPresentValue,
      bondCashflowMacaulayDuration: current.bondCashflowMacaulayDuration,
      bondCashflowModifiedDuration: current.bondCashflowModifiedDuration,
      bondCashflowConvexity: current.bondCashflowConvexity,
      bondCashflowMetricsDate: current.bondCashflowMetricsDate,
    );
    _publishDatasets(
      {
        ...snapshotNotifier.value.datasets,
        current.portfolioType: dataset,
      },
      activeType: current.portfolioType,
      persist: true,
    );
  }

  Future<void> _restoreSqlDatasets(RwaApiService api) async {
    try {
      await _restoreFuture;
      final payload = await api.fetchMarketPortfolioPayload();
      if (payload != null && await _restoreDecodedDatasets(payload)) {
        return;
      }

      final migrated = await _restorePersistedDatasets(allowInSqlMode: true);
      if (migrated) {
        await _persistDatasets();
      }
    } catch (error) {
      final restored = await _restorePersistedDatasets(allowInSqlMode: true);
      if (!restored) {
        debugPrint(
          'Données marché locales indisponibles pour le moment. Vérifiez que le service local est démarré.',
        );
      }
    }
  }

  Future<bool> _restorePersistedDatasets({
    bool allowInSqlMode = false,
  }) async {
    try {
      if (_sqlModeEnabled && !allowInSqlMode) return false;
      var rawPayload = await local_storage.readMarketDataPayload();
      final preferences = await SharedPreferences.getInstance();
      rawPayload ??= preferences.getString(_marketDataImportStorageKey);
      if (rawPayload == null || rawPayload.trim().isEmpty) return false;
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, dynamic>) return false;
      return await _restoreDecodedDatasets(
        decoded,
        allowInSqlMode: allowInSqlMode,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _restoreDecodedDatasets(
    Map<String, dynamic> decoded, {
    bool allowInSqlMode = true,
  }) async {
    try {
      if (_sqlModeEnabled && !allowInSqlMode) return false;
      final result = await _restoreDecodedDatasetsInBackground(decoded);
      if (_hasLocalMutation || result.datasets.isEmpty) return false;

      _publishDatasets(
        result.datasets,
        activeType: result.activeType,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<_MarketPersistedRestoreResult> _restoreDecodedDatasetsInBackground(
    Map<String, dynamic> decoded,
  ) async {
    try {
      return await compute(
        _restoreMarketDatasetsFromPayload,
        decoded,
        debugLabel: 'market-sql-restore',
      );
    } catch (error) {
      debugPrint('Restauration SQL en isolate indisponible: $error');
      return _restoreMarketDatasetsFromPayload(decoded);
    }
  }

  void _schedulePersistDatasets() {
    _hasLocalMutation = true;
    unawaited(
      _persistDatasets().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Persist market datasets failed: $error');
      }),
    );
  }

  Future<void> _persistDatasets() async {
    final activeDataset = snapshotNotifier.value.activeDataset;
    final payload = <String, Object?>{
      'version': _marketDataImportStorageVersion,
      'activeType': activeDataset?.portfolioType.storageKey,
      'datasets': {
        for (final entry in snapshotNotifier.value.datasets.entries)
          entry.key.storageKey: _datasetToPersistedJson(entry.value),
      },
    };
    final sqlApi = _sqlBackendApi;
    if (_sqlModeEnabled && sqlApi != null) {
      try {
        await sqlApi.saveMarketPortfolioPayload(payload);
        return;
      } catch (_) {
        debugPrint(
          'Sauvegarde SQL locale indisponible pour le moment. Une sauvegarde locale de secours va être utilisée.',
        );
      }
    }

    final encodedPayload = jsonEncode(payload);
    var persisted = false;
    Object? lastError;

    try {
      await local_storage.writeMarketDataPayload(encodedPayload);
      persisted = true;
    } catch (error) {
      lastError = error;
      if (error is! UnsupportedError) {
        debugPrint('Local market file persistence failed: $error');
      }
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _marketDataImportStorageKey,
        encodedPayload,
      );
      persisted = true;
    } catch (error) {
      lastError = error;
      debugPrint('SharedPreferences market persistence failed: $error');
    }

    if (!persisted) {
      throw StateError(
        'Sauvegarde locale du portefeuille marché impossible : $lastError',
      );
    }
  }

  Uint8List buildTemplateWorkbook({
    required MarketPortfolioType portfolioType,
  }) {
    return buildTemplateWorkbookForTypes(portfolioTypes: [portfolioType]);
  }

  Uint8List buildTemplateWorkbookForTypes({
    required List<MarketPortfolioType> portfolioTypes,
  }) {
    if (portfolioTypes.isEmpty) {
      throw StateError('Aucun type de portefeuille sélectionné.');
    }
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    for (var index = 0; index < portfolioTypes.length; index++) {
      final portfolioType = portfolioTypes[index];
      if (index == 0 &&
          defaultSheet != null &&
          defaultSheet != portfolioType.sheetName) {
        workbook.rename(defaultSheet, portfolioType.sheetName);
      }
      final sheet = workbook[portfolioType.sheetName];
      sheet.appendRow(
        portfolioType.requiredHeaders
            .map((header) => TextCellValue(header))
            .toList(growable: false),
      );
    }
    final bytes = workbook.save();
    if (bytes == null) {
      throw StateError('Impossible de générer le modèle Excel.');
    }
    return Uint8List.fromList(bytes);
  }
}

class _ParsedMarketWorkbook {
  const _ParsedMarketWorkbook({
    required this.sheetFound,
    required this.sheetCount,
    required this.headers,
    required this.missingHeaders,
    required this.records,
    this.bondCapitalRemainingDue = 0,
    this.bondCashflowPresentValue = 0,
    this.bondCashflowMacaulayDuration = 0,
    this.bondCashflowModifiedDuration = 0,
    this.bondCashflowConvexity = 0,
  });

  final bool sheetFound;
  final int sheetCount;
  final List<String> headers;
  final List<String> missingHeaders;
  final List<MarketPortfolioRecord> records;
  final double bondCapitalRemainingDue;
  final double bondCashflowPresentValue;
  final double bondCashflowMacaulayDuration;
  final double bondCashflowModifiedDuration;
  final double bondCashflowConvexity;
}

MarketPortfolioType? _portfolioTypeFromStorageKey(String key) {
  return switch (key) {
    'bonds' => MarketPortfolioType.bonds,
    'equities' => MarketPortfolioType.equities,
    _ => null,
  };
}

class _MarketPersistedRestoreResult {
  const _MarketPersistedRestoreResult({
    required this.datasets,
    required this.activeType,
  });

  final Map<MarketPortfolioType, MarketPortfolioDataset> datasets;
  final MarketPortfolioType? activeType;
}

_MarketPersistedRestoreResult _restoreMarketDatasetsFromPayload(
  Map<String, dynamic> decoded,
) {
  final storageVersion =
      int.tryParse(decoded['version']?.toString() ?? '') ?? 1;
  if (storageVersion < _marketDataImportStorageVersion) {
    return const _MarketPersistedRestoreResult(
      datasets: {},
      activeType: null,
    );
  }
  final datasetsPayload = decoded['datasets'];
  if (datasetsPayload is! Map) {
    return const _MarketPersistedRestoreResult(
      datasets: {},
      activeType: null,
    );
  }

  final restored = <MarketPortfolioType, MarketPortfolioDataset>{};
  for (final entry in datasetsPayload.entries) {
    final portfolioType = _portfolioTypeFromStorageKey(
      entry.key.toString(),
    );
    if (portfolioType == null) continue;
    final dataset = _datasetFromPersistedJson(portfolioType, entry.value);
    if (dataset != null) {
      restored[portfolioType] = dataset;
    }
  }

  return _MarketPersistedRestoreResult(
    datasets: restored,
    activeType: _portfolioTypeFromStorageKey(
      decoded['activeType']?.toString() ?? '',
    ),
  );
}

Map<String, Object?> _datasetToPersistedJson(MarketPortfolioDataset dataset) {
  return {
    'fileName': dataset.fileName,
    'importedAt': dataset.importedAt.toIso8601String(),
    'headers': dataset.headers,
    'bondCapitalRemainingDue': dataset.bondCapitalRemainingDue,
    'bondCashflowPresentValue': dataset.bondCashflowPresentValue,
    'bondCashflowMacaulayDuration': dataset.bondCashflowMacaulayDuration,
    'bondCashflowModifiedDuration': dataset.bondCashflowModifiedDuration,
    'bondCashflowConvexity': dataset.bondCashflowConvexity,
    'bondCashflowMetricsDate':
        dataset.bondCashflowMetricsDate?.toIso8601String(),
    'records': [
      for (final record in dataset.records)
        {
          'values': {
            for (final entry in record.values.entries)
              entry.key: _persistedValue(entry.value),
          },
        },
    ],
  };
}

MarketPortfolioDataset? _datasetFromPersistedJson(
  MarketPortfolioType portfolioType,
  Object? payload,
) {
  if (payload is! Map) return null;
  final fileName = payload['fileName']?.toString() ?? 'Base restaurée';
  final importedAt = DateTime.tryParse(
        payload['importedAt']?.toString() ?? '',
      ) ??
      DateTime.now();
  final headersPayload = payload['headers'];
  final headers = headersPayload is List
      ? headersPayload.map((value) => value.toString()).toList()
      : portfolioType.requiredHeaders;
  final recordsPayload = payload['records'];
  final records = <MarketPortfolioRecord>[];
  if (recordsPayload is List) {
    for (final rawRecord in recordsPayload) {
      if (rawRecord is! Map) continue;
      final rawValues = rawRecord['values'];
      if (rawValues is! Map) continue;
      final values = {
        for (final entry in rawValues.entries)
          entry.key.toString(): _persistedValueToObject(entry.value),
      };
      _normalizeMarketRowValues(
        values,
        portfolioType: portfolioType,
      );
      records.add(
        MarketPortfolioRecord(
          portfolioType: portfolioType,
          values: values,
        ),
      );
    }
  }
  final metricsDate = DateTime.tryParse(
    payload['bondCashflowMetricsDate']?.toString() ?? '',
  );
  final metricsAreFresh = _isSameMarketDay(metricsDate, _marketToday());
  return MarketPortfolioDataset(
    portfolioType: portfolioType,
    fileName: fileName,
    importedAt: importedAt,
    headers: headers,
    records: records,
    bondCapitalRemainingDue:
        metricsAreFresh ? _toDouble(payload['bondCapitalRemainingDue']) : 0,
    bondCashflowPresentValue:
        metricsAreFresh ? _toDouble(payload['bondCashflowPresentValue']) : 0,
    bondCashflowMacaulayDuration: metricsAreFresh
        ? _toDouble(payload['bondCashflowMacaulayDuration'])
        : 0,
    bondCashflowModifiedDuration: metricsAreFresh
        ? _toDouble(payload['bondCashflowModifiedDuration'])
        : 0,
    bondCashflowConvexity:
        metricsAreFresh ? _toDouble(payload['bondCashflowConvexity']) : 0,
    bondCashflowMetricsDate: metricsAreFresh ? metricsDate : null,
  );
}

Object? _persistedValue(Object? value) {
  if (value is DateTime) {
    return {
      'type': 'datetime',
      'value': value.toIso8601String(),
    };
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  return value.toString();
}

Object? _persistedValueToObject(Object? value) {
  if (value is Map && value['type'] == 'datetime') {
    return DateTime.tryParse(value['value']?.toString() ?? '');
  }
  return value;
}

class _MarketWorkbookParseRequest {
  const _MarketWorkbookParseRequest({
    required this.bytes,
    required this.fileName,
    required this.portfolioTypeIndex,
  });

  final Uint8List bytes;
  final String fileName;
  final int portfolioTypeIndex;

  MarketPortfolioType get portfolioType =>
      MarketPortfolioType.values[portfolioTypeIndex];
}

MarketImportInspection _inspectWorkbookInIsolate(
  _MarketWorkbookParseRequest request,
) {
  final portfolioType = request.portfolioType;
  try {
    return _inspectMarketWorkbook(
      request.bytes,
      request.fileName,
      portfolioType,
    );
  } catch (error) {
    return MarketImportInspection(
      portfolioType: portfolioType,
      fileName: request.fileName,
      valid: false,
      sheetFound: false,
      sheetCount: 0,
      rowCount: 0,
      detectedHeaders: const [],
      missingHeaders: portfolioType.requiredHeaders,
      errors: ['Lecture du fichier impossible : $error'],
    );
  }
}

MarketImportInspection _inspectMarketWorkbook(
  Uint8List bytes,
  String fileName,
  MarketPortfolioType portfolioType,
) {
  try {
    return _inspectMarketWorkbookFromXlsxXml(bytes, fileName, portfolioType);
  } catch (_) {
    return _inspectMarketWorkbookWithExcel(bytes, fileName, portfolioType);
  }
}

MarketImportInspection _inspectMarketWorkbookWithExcel(
  Uint8List bytes,
  String fileName,
  MarketPortfolioType portfolioType,
) {
  final workbook = _decodeMarketWorkbook(bytes);
  final sheetCount = workbook.tables.length;
  final requiredHeaders = portfolioType.requiredHeaders;
  final sheet = workbook.tables[portfolioType.sheetName];
  if (sheet == null) {
    return MarketImportInspection(
      portfolioType: portfolioType,
      fileName: fileName,
      valid: false,
      sheetFound: false,
      sheetCount: sheetCount,
      rowCount: 0,
      detectedHeaders: const [],
      missingHeaders: requiredHeaders,
      errors: ['La feuille "${portfolioType.sheetName}" est introuvable.'],
    );
  }

  final headers = sheet.rows.isEmpty
      ? const <String>[]
      : sheet.rows.first
          .map((cell) => _normalizeHeader(_cellToText(cell?.value)))
          .toList(growable: false);
  final missingHeaders = [
    for (final header in requiredHeaders)
      if (!headers.contains(_normalizeHeader(header))) header,
  ];
  final errors = <String>[
    if (missingHeaders.isNotEmpty)
      'Colonnes manquantes : ${missingHeaders.join(', ')}.',
  ];
  final rowCount = sheet.rows.skip(1).where(_rowHasReadableValues).length;

  return MarketImportInspection(
    portfolioType: portfolioType,
    fileName: fileName,
    valid: missingHeaders.isEmpty,
    sheetFound: true,
    sheetCount: sheetCount,
    rowCount: rowCount,
    detectedHeaders: headers.where((header) => header.isNotEmpty).toList(),
    missingHeaders: missingHeaders,
    errors: errors,
  );
}

bool _rowHasReadableValues(List<Data?> row) {
  return row.any((cell) => _cellToText(cell?.value).trim().isNotEmpty);
}

MarketImportInspection _inspectMarketWorkbookFromXlsxXml(
  Uint8List bytes,
  String fileName,
  MarketPortfolioType portfolioType,
) {
  final sheetData = _readXlsxSheetData(bytes, portfolioType.sheetName);
  final requiredHeaders = portfolioType.requiredHeaders;
  if (!sheetData.sheetFound) {
    return MarketImportInspection(
      portfolioType: portfolioType,
      fileName: fileName,
      valid: false,
      sheetFound: false,
      sheetCount: sheetData.sheetCount,
      rowCount: 0,
      detectedHeaders: const [],
      missingHeaders: requiredHeaders,
      errors: ['La feuille "${portfolioType.sheetName}" est introuvable.'],
    );
  }

  final headers = sheetData.rows.isEmpty
      ? const <String>[]
      : sheetData.rows.first
          .map((cell) => _normalizeHeader(cell?.text ?? ''))
          .toList(growable: false);
  final missingHeaders = _missingMarketHeaders(headers, requiredHeaders);
  return MarketImportInspection(
    portfolioType: portfolioType,
    fileName: fileName,
    valid: missingHeaders.isEmpty,
    sheetFound: true,
    sheetCount: sheetData.sheetCount,
    rowCount: sheetData.rows.skip(1).where(_xlsxRowHasReadableValues).length,
    detectedHeaders: headers.where((header) => header.isNotEmpty).toList(),
    missingHeaders: missingHeaders,
    errors: [
      if (missingHeaders.isNotEmpty)
        'Colonnes manquantes : ${missingHeaders.join(', ')}.',
    ],
  );
}

_ParsedMarketWorkbook _parseWorkbookFromXlsxXml(
  Uint8List bytes,
  MarketPortfolioType portfolioType,
) {
  final sheetData = _readXlsxSheetData(bytes, portfolioType.sheetName);
  final requiredHeaders = portfolioType.requiredHeaders;
  if (!sheetData.sheetFound) {
    return _ParsedMarketWorkbook(
      sheetFound: false,
      sheetCount: sheetData.sheetCount,
      headers: const [],
      missingHeaders: requiredHeaders,
      records: const [],
    );
  }
  if (sheetData.rows.isEmpty) {
    return _ParsedMarketWorkbook(
      sheetFound: true,
      sheetCount: sheetData.sheetCount,
      headers: const [],
      missingHeaders: requiredHeaders,
      records: const [],
    );
  }

  final headers = sheetData.rows.first
      .map((cell) => _normalizeHeader(cell?.text ?? ''))
      .toList(growable: false);
  final missingHeaders = _missingMarketHeaders(headers, requiredHeaders);

  final headerIndex = <String, int>{};
  for (var index = 0; index < headers.length; index++) {
    if (headers[index].isNotEmpty) {
      headerIndex[headers[index]] = index;
    }
  }

  final records = <MarketPortfolioRecord>[];
  for (final row in sheetData.rows.skip(1)) {
    if (!_xlsxRowHasReadableValues(row)) continue;
    final values = <String, Object?>{};
    for (final header in headers.where((header) => header.isNotEmpty)) {
      final index = headerIndex[_normalizeHeader(header)];
      final cell = index == null || index >= row.length ? null : row[index];
      values[header] = _coerceXlsxMarketCellValue(header, cell);
    }
    for (final header in requiredHeaders) {
      values.putIfAbsent(header, () => null);
    }
    _normalizeMarketRowValues(
      values,
      portfolioType: portfolioType,
    );
    records.add(
      MarketPortfolioRecord(
        portfolioType: portfolioType,
        values: values,
      ),
    );
  }
  const cashflowMetrics = _BondCashflowMetrics.empty;

  return _ParsedMarketWorkbook(
    sheetFound: true,
    sheetCount: sheetData.sheetCount,
    headers: headers.where((header) => header.isNotEmpty).toList(),
    missingHeaders: missingHeaders,
    records: records,
    bondCapitalRemainingDue: cashflowMetrics.capitalRemainingDue,
    bondCashflowPresentValue: cashflowMetrics.presentValue,
    bondCashflowMacaulayDuration: cashflowMetrics.macaulayDuration,
    bondCashflowModifiedDuration: cashflowMetrics.modifiedDuration,
    bondCashflowConvexity: cashflowMetrics.convexity,
  );
}

List<String> _missingMarketHeaders(
  List<String> detectedHeaders,
  List<String> requiredHeaders,
) {
  return [
    for (final header in requiredHeaders)
      if (!detectedHeaders.contains(_normalizeHeader(header))) header,
  ];
}

Object? _coerceXlsxMarketCellValue(String header, _XlsxCellValue? cell) {
  if (cell == null) return null;
  final text = cell.text.trim();
  if (text.isEmpty) return null;
  return _coerceMarketCellValue(header, text);
}

bool _xlsxRowHasReadableValues(List<_XlsxCellValue?> row) {
  return row.any((cell) => cell != null && cell.text.trim().isNotEmpty);
}

_XlsxSheetData _readXlsxSheetData(Uint8List bytes, String sheetName) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final workbookFile = archive.findFile('xl/workbook.xml');
  if (workbookFile == null || !workbookFile.isFile) {
    throw StateError('Classeur Excel illisible.');
  }
  final workbook = XmlDocument.parse(
    utf8.decode(workbookFile.content as List<int>, allowMalformed: true),
  );
  final sheets = workbook.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'sheet')
      .toList(growable: false);
  final sheetCount = sheets.length;
  final selectedSheet = sheets
      .where((element) => _xmlAttribute(element, 'name') == sheetName)
      .firstOrNull;
  if (selectedSheet == null) {
    return _XlsxSheetData(
      sheetFound: false,
      sheetCount: sheetCount,
      rows: const [],
    );
  }

  final relationId = _xmlAttribute(selectedSheet, 'id');
  final sheetTarget = relationId == null
      ? null
      : _workbookRelationshipTargets(archive)[relationId];
  if (sheetTarget == null) {
    throw StateError('Feuille Excel introuvable.');
  }
  final sheetFile = archive.findFile(_normalizeWorkbookTarget(sheetTarget));
  if (sheetFile == null || !sheetFile.isFile) {
    throw StateError('Feuille Excel introuvable.');
  }

  final sharedStrings = _readXlsxSharedStrings(archive);
  final sheet = XmlDocument.parse(
    utf8.decode(sheetFile.content as List<int>, allowMalformed: true),
  );
  return _XlsxSheetData(
    sheetFound: true,
    sheetCount: sheetCount,
    rows: _readXlsxRows(sheet, sharedStrings),
  );
}

Map<String, String> _workbookRelationshipTargets(Archive archive) {
  final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
  if (relsFile == null || !relsFile.isFile) return const {};
  final rels = XmlDocument.parse(
    utf8.decode(relsFile.content as List<int>, allowMalformed: true),
  );
  final targets = <String, String>{};
  for (final element in rels.descendants.whereType<XmlElement>()) {
    if (element.name.local != 'Relationship') continue;
    final id = _xmlAttribute(element, 'Id');
    final target = _xmlAttribute(element, 'Target');
    if (id != null && target != null) {
      targets[id] = target;
    }
  }
  return targets;
}

List<String> _readXlsxSharedStrings(Archive archive) {
  final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
  if (sharedStringsFile == null || !sharedStringsFile.isFile) return const [];
  final sharedStrings = XmlDocument.parse(
    utf8.decode(
      sharedStringsFile.content as List<int>,
      allowMalformed: true,
    ),
  );
  return sharedStrings.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'si')
      .map((element) => element.innerText)
      .toList(growable: false);
}

List<List<_XlsxCellValue?>> _readXlsxRows(
  XmlDocument sheet,
  List<String> sharedStrings,
) {
  final rows = <List<_XlsxCellValue?>>[];
  for (final rowElement in sheet.descendants.whereType<XmlElement>()) {
    if (rowElement.name.local != 'row') continue;
    final row = <_XlsxCellValue?>[];
    var nextColumnIndex = 0;
    for (final cellElement in rowElement.children.whereType<XmlElement>()) {
      if (cellElement.name.local != 'c') continue;
      final reference = _xmlAttribute(cellElement, 'r');
      final columnIndex = reference == null
          ? nextColumnIndex
          : _xlsxColumnIndexFromReference(reference);
      if (columnIndex < 0) continue;
      while (row.length <= columnIndex) {
        row.add(null);
      }
      row[columnIndex] = _readXlsxCellValue(cellElement, sharedStrings);
      nextColumnIndex = columnIndex + 1;
    }
    rows.add(row);
  }
  return rows;
}

_XlsxCellValue _readXlsxCellValue(
  XmlElement cell,
  List<String> sharedStrings,
) {
  final hasFormula = cell.children
      .whereType<XmlElement>()
      .any((element) => element.name.local == 'f');
  final type = _xmlAttribute(cell, 't');
  if (type == 'inlineStr') {
    final inlineText = cell.children
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'is')
        .map((element) => element.innerText)
        .join();
    return _XlsxCellValue(text: inlineText, isFormula: false);
  }

  final rawValue = cell.children
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'v')
      .map((element) => element.innerText)
      .firstOrNull
      ?.trim();
  if (type == 's') {
    final index = int.tryParse(rawValue ?? '');
    final text = index == null || index < 0 || index >= sharedStrings.length
        ? ''
        : sharedStrings[index];
    return _XlsxCellValue(text: text, isFormula: false);
  }
  return _XlsxCellValue(text: rawValue ?? '', isFormula: hasFormula);
}

String? _xmlAttribute(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) return attribute.value;
  }
  return null;
}

String _normalizeWorkbookTarget(String target) {
  final normalized = target.replaceAll('\\', '/');
  if (normalized.startsWith('/')) {
    return normalized.substring(1);
  }
  if (normalized.startsWith('xl/')) return normalized;
  return 'xl/$normalized';
}

int _xlsxColumnIndexFromReference(String reference) {
  var index = 0;
  var hasLetters = false;
  for (final codeUnit in reference.toUpperCase().codeUnits) {
    if (codeUnit < 65 || codeUnit > 90) break;
    hasLetters = true;
    index = index * 26 + (codeUnit - 64);
  }
  return hasLetters ? index - 1 : -1;
}

class _XlsxSheetData {
  const _XlsxSheetData({
    required this.sheetFound,
    required this.sheetCount,
    required this.rows,
  });

  final bool sheetFound;
  final int sheetCount;
  final List<List<_XlsxCellValue?>> rows;
}

class _BondCashflowMetrics {
  const _BondCashflowMetrics({
    required this.capitalRemainingDue,
    required this.presentValue,
    required this.macaulayDuration,
    required this.modifiedDuration,
    required this.convexity,
  });

  static const empty = _BondCashflowMetrics(
    capitalRemainingDue: 0,
    presentValue: 0,
    macaulayDuration: 0,
    modifiedDuration: 0,
    convexity: 0,
  );

  final double capitalRemainingDue;
  final double presentValue;
  final double macaulayDuration;
  final double modifiedDuration;
  final double convexity;
}

class _XlsxCellValue {
  const _XlsxCellValue({
    required this.text,
    required this.isFormula,
  });

  final String text;
  final bool isFormula;
}

_ParsedMarketWorkbook _parseWorkbookInIsolate(
  _MarketWorkbookParseRequest request,
) {
  return _parseWorkbook(request.bytes, request.portfolioType);
}

_ParsedMarketWorkbook _parseWorkbook(
  Uint8List bytes,
  MarketPortfolioType portfolioType,
) {
  try {
    return _parseWorkbookFromXlsxXml(bytes, portfolioType);
  } catch (_) {
    return _parseWorkbookWithExcel(bytes, portfolioType);
  }
}

_ParsedMarketWorkbook _parseWorkbookWithExcel(
  Uint8List bytes,
  MarketPortfolioType portfolioType,
) {
  final workbook = _decodeMarketWorkbook(bytes);
  final sheetCount = workbook.tables.length;
  final requiredHeaders = portfolioType.requiredHeaders;
  final sheet = workbook.tables[portfolioType.sheetName];
  if (sheet == null) {
    return _ParsedMarketWorkbook(
      sheetFound: false,
      sheetCount: sheetCount,
      headers: const [],
      missingHeaders: requiredHeaders,
      records: const [],
    );
  }
  if (sheet.rows.isEmpty) {
    return _ParsedMarketWorkbook(
      sheetFound: true,
      sheetCount: sheetCount,
      headers: const [],
      missingHeaders: requiredHeaders,
      records: const [],
    );
  }

  final headers = sheet.rows.first
      .map((cell) => _normalizeHeader(_cellToText(cell?.value)))
      .toList(growable: false);
  final missingHeaders = [
    for (final header in requiredHeaders)
      if (!headers.contains(_normalizeHeader(header))) header,
  ];

  final headerIndex = <String, int>{};
  for (var index = 0; index < headers.length; index++) {
    if (headers[index].isNotEmpty) {
      headerIndex[headers[index]] = index;
    }
  }

  final records = <MarketPortfolioRecord>[];
  for (final row in sheet.rows.skip(1)) {
    if (!row.any((cell) => _cellToText(cell?.value).trim().isNotEmpty)) {
      continue;
    }
    final values = <String, Object?>{};
    for (final header in headers.where((header) => header.isNotEmpty)) {
      final index = headerIndex[_normalizeHeader(header)];
      final value =
          index == null || index >= row.length ? null : row[index]?.value;
      values[header] = _coerceMarketCellValue(
        header,
        _cellToPrimitive(value),
      );
    }
    for (final header in requiredHeaders) {
      values.putIfAbsent(header, () => null);
    }
    _normalizeMarketRowValues(
      values,
      portfolioType: portfolioType,
    );
    records.add(
      MarketPortfolioRecord(
        portfolioType: portfolioType,
        values: values,
      ),
    );
  }
  const cashflowMetrics = _BondCashflowMetrics.empty;

  return _ParsedMarketWorkbook(
    sheetFound: true,
    sheetCount: sheetCount,
    headers: headers.where((header) => header.isNotEmpty).toList(),
    missingHeaders: missingHeaders,
    records: records,
    bondCapitalRemainingDue: cashflowMetrics.capitalRemainingDue,
    bondCashflowPresentValue: cashflowMetrics.presentValue,
    bondCashflowMacaulayDuration: cashflowMetrics.macaulayDuration,
    bondCashflowModifiedDuration: cashflowMetrics.modifiedDuration,
    bondCashflowConvexity: cashflowMetrics.convexity,
  );
}

Excel _decodeMarketWorkbook(Uint8List bytes) {
  final repairedBytes = _repairMarketWorkbookStylesIfNeeded(bytes);
  if (repairedBytes != null) {
    return Excel.decodeBytes(repairedBytes);
  }
  try {
    return Excel.decodeBytes(bytes);
  } catch (_) {
    return Excel.decodeBytes(_sanitizeMarketWorkbookStyles(bytes));
  }
}

Uint8List? _repairMarketWorkbookStylesIfNeeded(Uint8List bytes) {
  try {
    final sourceArchive = ZipDecoder().decodeBytes(bytes);
    final stylesFile = sourceArchive.findFile('xl/styles.xml');
    if (stylesFile == null || !stylesFile.isFile) return null;
    final stylesXml = utf8.decode(
      stylesFile.content as List<int>,
      allowMalformed: true,
    );
    final repairedXml = _repairCustomNumberFormats(stylesXml);
    if (repairedXml == stylesXml) return null;
    return _encodeMarketWorkbookWithStyles(sourceArchive, repairedXml);
  } catch (_) {
    return null;
  }
}

Uint8List _sanitizeMarketWorkbookStyles(Uint8List bytes) {
  final sourceArchive = ZipDecoder().decodeBytes(bytes);
  final stylesFile = sourceArchive.findFile('xl/styles.xml');
  if (stylesFile == null || !stylesFile.isFile) {
    throw StateError('Le classeur Excel ne contient pas de styles lisibles.');
  }
  final repairedXml = _repairCustomNumberFormats(
    utf8.decode(stylesFile.content as List<int>, allowMalformed: true),
  );
  return _encodeMarketWorkbookWithStyles(sourceArchive, repairedXml);
}

Uint8List _encodeMarketWorkbookWithStyles(
    Archive sourceArchive, String styles) {
  final sanitizedArchive = Archive();

  for (final file in sourceArchive.files) {
    final content = file.isFile ? file.content as List<int> : const <int>[];
    final sanitizedContent =
        file.name == 'xl/styles.xml' ? utf8.encode(styles) : content;
    final sanitizedFile = ArchiveFile(
      file.name,
      sanitizedContent.length,
      sanitizedContent,
    )
      ..isFile = file.isFile
      ..isSymbolicLink = file.isSymbolicLink
      ..nameOfLinkedFile = file.nameOfLinkedFile
      ..mode = file.mode
      ..ownerId = file.ownerId
      ..groupId = file.groupId
      ..lastModTime = file.lastModTime
      ..comment = file.comment
      ..compress = file.compress;
    sanitizedArchive.addFile(sanitizedFile);
  }

  final sanitizedBytes = ZipEncoder().encode(sanitizedArchive);
  if (sanitizedBytes == null) {
    throw StateError('Impossible de normaliser les styles du classeur Excel.');
  }
  return Uint8List.fromList(sanitizedBytes);
}

String _repairCustomNumberFormats(String xml) {
  final numFmtPattern = RegExp(r'<numFmt\b[^>]*\bnumFmtId="(\d+)"[^>]*/>');
  final ids = [
    for (final match in numFmtPattern.allMatches(xml))
      int.tryParse(match.group(1) ?? ''),
  ].whereType<int>().toList(growable: false);
  var nextCustomId = math.max(
    164,
    ids.fold<int>(163, (maxId, id) => math.max(maxId, id)) + 1,
  );
  final remappedIds = <String, String>{};

  var repairedXml = xml.replaceAllMapped(numFmtPattern, (match) {
    final idText = match.group(1);
    final id = int.tryParse(idText ?? '');
    if (idText == null || id == null || id >= 164) {
      return match.group(0)!;
    }
    final replacementId =
        remappedIds.putIfAbsent(idText, () => '${nextCustomId++}');
    return match.group(0)!.replaceFirst(
          'numFmtId="$idText"',
          'numFmtId="$replacementId"',
        );
  });

  for (final entry in remappedIds.entries) {
    repairedXml = repairedXml.replaceAll(
      'numFmtId="${entry.key}"',
      'numFmtId="${entry.value}"',
    );
  }
  return repairedXml;
}

Object? _cellToPrimitive(CellValue? value) {
  return switch (value) {
    null => null,
    TextCellValue() => value.value.text ?? '',
    IntCellValue() => value.value,
    DoubleCellValue() => value.value,
    BoolCellValue() => value.value,
    DateCellValue() => value.asDateTimeLocal(),
    DateTimeCellValue() => value.asDateTimeLocal(),
    TimeCellValue() => value.toString(),
    FormulaCellValue() => null,
  };
}

void _normalizeMarketRowValues(
  Map<String, Object?> values, {
  required MarketPortfolioType portfolioType,
}) {
  for (final entry in values.entries.toList()) {
    if (_looksLikeFormula(entry.value)) {
      values[entry.key] = null;
    }
  }

  if (portfolioType == MarketPortfolioType.bonds) {
    final nominalUnit = _toDouble(values['Valeur nominale unitaire']);
    final quantity = _toDouble(values['quantités']);
    final capitalInitial = _toDouble(values['Capital initial']);
    if (capitalInitial <= 0 && nominalUnit > 0 && quantity > 0) {
      values['Capital initial'] = nominalUnit * quantity;
    }

    final issuePrice = _toDouble(values['Prix d\'émission']);
    final issuePremium = _toDouble(values['Prime d\'émission']);
    if (issuePremium == 0 && nominalUnit > 0 && issuePrice > 0) {
      values['Prime d\'émission'] = nominalUnit - issuePrice;
    }

    final redemptionPrice = _toDouble(values['Prix de remboursement']);
    final redemptionPremium = _toDouble(values['Prime de remboursement']);
    if (redemptionPremium == 0 && nominalUnit > 0 && redemptionPrice > 0) {
      values['Prime de remboursement'] = redemptionPrice - nominalUnit;
    }

    final analysisDate = _marketToday();
    final issueDate = _dateValue(values['Date d\'émission']);
    final maturityDate = _dateValue(values['Date d\'échéance']);
    values.putIfAbsent(
      '__Maturité importée (mois)',
      () => values['Maturité (mois)'],
    );
    values.putIfAbsent(
      '__Maturité résiduelle importée (mois)',
      () => values['Maturité résiduelle (mois)'],
    );
    values['Date d\'analyse'] = analysisDate;
    if (issueDate != null && maturityDate != null) {
      values['Maturité (mois)'] = _bondDateMaturityMonths(
        issueDate,
        maturityDate,
      );
    }
    if (maturityDate != null) {
      values['Maturité résiduelle (mois)'] = _bondDateMaturityMonths(
        analysisDate,
        maturityDate,
      );
    }
  }

  if (portfolioType == MarketPortfolioType.equities) {
    final quantity = _toDouble(values['Quantité']);
    final currentPrice = _toDouble(values['Cours actuel']);
    final acquisitionPrice = _toDouble(values['Prix d\'achat unitaire']);
    final marketValue = _toDouble(values['Valeur de marché']);
    final acquisitionCost = _toDouble(values['Coût d\'acquisition']);
    if (marketValue <= 0 && quantity > 0 && currentPrice > 0) {
      values['Valeur de marché'] = quantity * currentPrice;
    }
    if (acquisitionCost <= 0 && quantity > 0 && acquisitionPrice > 0) {
      values['Coût d\'acquisition'] = quantity * acquisitionPrice;
    }
  }
}

bool _looksLikeFormula(Object? value) {
  if (value == null || value is num || value is DateTime || value is bool) {
    return false;
  }
  final text = value.toString().trim();
  if (text.isEmpty) return false;
  return text.startsWith('=') ||
      text.startsWith('IF(') ||
      text.startsWith('OR(') ||
      text.startsWith('DATEDIF(') ||
      text.contains('DATEDIF(');
}

DateTime? _dateValue(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || _looksLikeFormula(text)) return null;
  final serial = _toDouble(text);
  if (serial > 20000 && serial < 80000) {
    return DateTime(1899, 12, 30).add(Duration(days: serial.round()));
  }
  final slashParts = text.split(RegExp(r'[/.-]'));
  if (slashParts.length == 3) {
    final first = int.tryParse(slashParts[0]);
    final second = int.tryParse(slashParts[1]);
    final third = int.tryParse(slashParts[2]);
    if (first != null && second != null && third != null) {
      final year = third < 100 ? 2000 + third : third;
      return DateTime(year, second, first);
    }
  }
  return DateTime.tryParse(text);
}

Object? _coerceMarketCellValue(String header, Object? value) {
  if (value == null) return null;
  if (_looksLikeFormula(value)) return null;
  if (_isMarketDateHeader(header)) {
    if (value is DateTime) return value;
    final serial = _toDouble(value);
    if (serial > 20000 && serial < 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial.round()));
    }
    return value;
  }
  if (_isMarketNumericHeader(header)) {
    return _coerceMarketNumericValue(value);
  }
  return value;
}

bool _isMarketDateHeader(String header) {
  return const {
    'Date d\'analyse',
    'Date d\'émission',
    'Date d\'échéance',
    'Date d\'acquisition',
    'Date de valorisation',
  }.contains(header);
}

bool _isMarketNumericHeader(String header) {
  return const {
    'Valeur nominale unitaire',
    'quantités',
    'Capital initial',
    'Prix d\'émission',
    'Prime d\'émission',
    'Prix de remboursement',
    'Prime de remboursement',
    'Capital restant dû',
    'Capital restant dû (MD)',
    'Capital restant dû (Md)',
    'Capital restant du',
    'Capital restant du (MD)',
    'Capital restant du (Md)',
    'CRD',
    'CRD (MD)',
    'CRD (Md)',
    'Valeur actualisée',
    'Valeur actualisée (MD)',
    'Valeur actualisée (Md)',
    'Valeur actualisee',
    'Valeur actualisee (MD)',
    'Valeur actualisee (Md)',
    'Valeur actuelle',
    'Valeur actuelle (MD)',
    'Valeur actuelle (Md)',
    'PV',
    'PV (MD)',
    'PV (Md)',
    'Present Value',
    'YTM',
    'Yield To Maturity',
    'Taux actuariel',
    'Rendement actuariel',
    'Taux de rendement actuariel',
    'Spread',
    'SPREAD',
    'Spread (%)',
    'SPREAD (%)',
    'Coupon (%)',
    'Maturité (mois)',
    'Maturité résiduelle (mois)',
    'Quantité',
    'Prix d\'achat unitaire',
    'Coût d\'acquisition',
    'Cours actuel',
    'Valeur de marché',
    'Plus/(moins)-value latente',
    'Rendement latent (%)',
    'Dividende par action',
    'Rendement dividende (%)',
    'P/E',
    'Bêta',
  }.contains(header);
}

Object? _coerceMarketNumericValue(Object? value) {
  if (value is DateTime && _isEarlyExcelSerialDate(value)) {
    return _earlyExcelSerialNumber(value);
  }
  return value;
}

bool _isEarlyExcelSerialDate(DateTime value) {
  return value.isAfter(DateTime(1899, 12, 30)) &&
      value.isBefore(DateTime(1900, 3, 1));
}

double _earlyExcelSerialNumber(DateTime value) {
  return value.difference(DateTime(1899, 12, 30)).inMilliseconds /
      Duration.millisecondsPerDay;
}

String _cellToText(CellValue? value) {
  final primitive = _cellToPrimitive(value);
  if (primitive == null) return '';
  if (primitive is DateTime) {
    return '${primitive.day.toString().padLeft(2, '0')}/'
        '${primitive.month.toString().padLeft(2, '0')}/'
        '${primitive.year}';
  }
  return primitive.toString();
}

String _normalizeHeader(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is DateTime && _isEarlyExcelSerialDate(value)) {
    return _earlyExcelSerialNumber(value);
  }
  final text = value
      .toString()
      .replaceAll('\u00A0', '')
      .replaceAll(' ', '')
      .replaceAll('FCFA', '')
      .replaceAll('%', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(text) ?? 0;
}
