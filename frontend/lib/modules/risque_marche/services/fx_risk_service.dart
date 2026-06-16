import 'dart:math' as math;
import '../../../core/utils/currency_conversion.dart';
import 'market_data_import_store.dart';

class FxPosition {
  final String currency;
  final double longPosition;
  final double shortPosition;
  final double netPosition;
  final double grossPosition;

  const FxPosition({
    required this.currency,
    required this.longPosition,
    required this.shortPosition,
    required this.netPosition,
    required this.grossPosition,
  });
}

class FxShockResult {
  final double shockPercent;
  final double impactOnLong;
  final double impactOnShort;
  final double netImpact;
  final String label;

  const FxShockResult({
    required this.shockPercent,
    required this.impactOnLong,
    required this.impactOnShort,
    required this.netImpact,
    required this.label,
  });
}

class FxDailyPnl {
  final double previousRate;
  final double currentRate;
  final double pnlInXof;
  final double pnlPercent;

  const FxDailyPnl({
    required this.previousRate,
    required this.currentRate,
    required this.pnlInXof,
    required this.pnlPercent,
  });
}

class FxRiskResult {
  final List<FxPosition> positionsByCurrency;
  final double globalNetPosition;
  final double globalGrossPosition;
  final double maximumLegPosition;
  final double capitalRequirement;
  final List<FxShockResult> shockResults;
  final List<Map<String, dynamic>> calculationJournal;

  const FxRiskResult({
    required this.positionsByCurrency,
    required this.globalNetPosition,
    required this.globalGrossPosition,
    required this.maximumLegPosition,
    required this.capitalRequirement,
    required this.shockResults,
    required this.calculationJournal,
  });
}

FxRiskResult calculateFxRisk({
  required List<MarketPortfolioRecord> records,
  List<double> shockScenarios = const [5, 10],
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description': 'Calcul du risque de change',
    'timestamp': DateTime.now().toIso8601String(),
  });

  final netByCurrency = <String, double>{};
  final longByCurrency = <String, double>{};
  final shortByCurrency = <String, double>{};

  for (final record in records) {
    final currency = normalizeCurrencyCode(record.currency);
    if (currency.isEmpty || currency == 'XOF') continue;
    final amount = _getRecordAmount(record);
    final sign = _marketRecordPositionSign(record);
    if (amount <= 0) continue;

    final signedAmount = amount * sign;
    netByCurrency.update(currency, (v) => v + signedAmount,
        ifAbsent: () => signedAmount);
    if (signedAmount >= 0) {
      longByCurrency.update(currency, (v) => v + signedAmount,
          ifAbsent: () => signedAmount);
    } else {
      shortByCurrency.update(currency, (v) => v + signedAmount.abs(),
          ifAbsent: () => signedAmount.abs());
    }
  }

  journal.add({
    'etape': 'Positions nettes',
    'description': '${netByCurrency.length} devises hors XOF traitées',
    'devises': netByCurrency.keys.join(', '),
  });

  final positions = netByCurrency.keys.map((currency) {
    final net = netByCurrency[currency] ?? 0.0;
    final long = longByCurrency[currency] ?? 0.0;
    final short = shortByCurrency[currency] ?? 0.0;
    return FxPosition(
      currency: currency,
      longPosition: long,
      shortPosition: short,
      netPosition: net,
      grossPosition: long + short,
    );
  }).toList();

  var longTotal = 0.0;
  var shortTotal = 0.0;
  var grossTotal = 0.0;
  for (final pos in positions) {
    longTotal += pos.longPosition;
    shortTotal += pos.shortPosition;
    grossTotal += pos.grossPosition;
  }
  final maxLeg = math.max(longTotal, shortTotal);
  final capitalReq = maxLeg * 0.08;

  journal.add({
    'etape': 'Capital requis',
    'description': 'Risque de change = 8% de la position nette globale maximale',
    'longTotal': longTotal,
    'shortTotal': shortTotal,
    'maxLeg': maxLeg,
    'capitalRequirement': capitalReq,
    'formule': 'Exigence FP Change = max(Positions_longues, Positions_courtes) × 8%',
  });

  final shocks = shockScenarios.map((percent) {
    final impactLong = longTotal * (percent / 100);
    final impactShort = -shortTotal * (percent / 100);
    final netImpact = impactLong + impactShort;
    journal.add({
      'etape': 'Choc $percent%',
      'description': 'Scénario de dépréciation de $percent%',
      'impactLong': impactLong,
      'impactShort': impactShort,
      'netImpact': netImpact,
      'formule': 'Impact = Position_longue × $percent% + Position_courte × (-$percent%)',
    });
    return FxShockResult(
      shockPercent: percent.toDouble(),
      impactOnLong: impactLong,
      impactOnShort: impactShort,
      netImpact: netImpact,
      label: 'Choc $percent%',
    );
  }).toList();

  return FxRiskResult(
    positionsByCurrency: positions,
    globalNetPosition: longTotal - shortTotal,
    globalGrossPosition: grossTotal,
    maximumLegPosition: maxLeg,
    capitalRequirement: capitalReq,
    shockResults: shocks,
    calculationJournal: journal,
  );
}

double _getRecordAmount(MarketPortfolioRecord record) {
  if (record.portfolioType == MarketPortfolioType.equities) {
    return record.valuationAmount > 0
        ? record.valuationAmount
        : record.exposureAmount;
  }
  return _bondMarketValue(record);
}

double _bondMarketValue(MarketPortfolioRecord record) {
  if (_bondIsMaturedAtAnalysisDate(record)) return 0;
  if (record.presentValue > 0) return record.presentValue;
  final explicitValue = math.max(0.0, record.valuationAmount).toDouble();
  return explicitValue > 0 ? explicitValue : _bondOutstandingCapital(record);
}

double _bondOutstandingCapital(MarketPortfolioRecord record) {
  if (_bondIsMaturedAtAnalysisDate(record)) return 0;
  if (record.capitalRemainingDue > 0) return record.capitalRemainingDue;
  final initial = record.capitalInitial > 0
      ? record.capitalInitial
      : record.exposureAmount;
  return math.max(0.0, initial).toDouble();
}

bool _bondIsMaturedAtAnalysisDate(MarketPortfolioRecord record) {
  final maturityDate = record.maturityDate;
  if (maturityDate == null) return false;
  return !_dateOnly(maturityDate).isAfter(record.resolvedAnalysisDate);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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
  ].whereType<Object>().map((v) => v.toString()).join(' ');
  final side = _foldText(rawSide);
  if (side.contains('short') ||
      side.contains('courte') ||
      side.contains('vente') ||
      side.contains('vendu')) {
    return -1;
  }
  return 1;
}

String _foldText(String value) {
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
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
