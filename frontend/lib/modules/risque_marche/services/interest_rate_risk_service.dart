import 'dart:math' as math;
import 'market_data_import_store.dart';

class RateRiskInput {
  final MarketPortfolioRecord record;
  final double marketValue;
  final double outstandingCapital;
  final double residualYears;
  final double couponRate;
  final double yieldToMaturity;
  final int paymentsPerYear;

  const RateRiskInput({
    required this.record,
    required this.marketValue,
    required this.outstandingCapital,
    required this.residualYears,
    required this.couponRate,
    required this.yieldToMaturity,
    required this.paymentsPerYear,
  });
}

class RateRiskResult {
  final double marketValue;
  final double macaulayDuration;
  final double modifiedDuration;
  final double sensitivity;
  final double convexity;
  final double priceChangeLinear;
  final double priceChangeWithConvexity;
  final double rateShockBps;
  final double yieldToMaturity;
  final double couponRate;
  final double residualYears;
  final double outstandingCapital;
  final Map<String, dynamic> formulaDetails;

  const RateRiskResult({
    required this.marketValue,
    required this.macaulayDuration,
    required this.modifiedDuration,
    required this.sensitivity,
    required this.convexity,
    required this.priceChangeLinear,
    required this.priceChangeWithConvexity,
    required this.rateShockBps,
    required this.yieldToMaturity,
    required this.couponRate,
    required this.residualYears,
    required this.outstandingCapital,
    required this.formulaDetails,
  });
}

class RateShockResult {
  final double shockBps;
  final double priceImpactLinear;
  final double priceImpactWithConvexity;
  final double newPrice;
  final String label;

  const RateShockResult({
    required this.shockBps,
    required this.priceImpactLinear,
    required this.priceImpactWithConvexity,
    required this.newPrice,
    required this.label,
  });
}

class PortfolioRateRiskResult {
  final List<RateRiskResult> byInstrument;
  final double totalMarketValue;
  final double portfolioModifiedDuration;
  final double portfolioMacaulayDuration;
  final double portfolioConvexity;
  final double portfolioSensitivity;
  final Map<double, RateShockResult> shockResults;
  final List<Map<String, dynamic>> calculationJournal;

  const PortfolioRateRiskResult({
    required this.byInstrument,
    required this.totalMarketValue,
    required this.portfolioModifiedDuration,
    required this.portfolioMacaulayDuration,
    required this.portfolioConvexity,
    required this.portfolioSensitivity,
    required this.shockResults,
    required this.calculationJournal,
  });
}

PortfolioRateRiskResult calculatePortfolioRateRisk({
  required List<MarketPortfolioRecord> records,
  double rateShockBps = 100,
  List<double> shockScenarios = const [25, 50, 100, 200, 300],
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description': 'Calcul du risque de taux sur ${records.length} obligations',
    'timestamp': DateTime.now().toIso8601String(),
  });

  final inputs = <RateRiskInput>[];
  for (final record in records) {
    if (record.portfolioType != MarketPortfolioType.bonds) continue;
    final marketValue = _localBondMarketValue(record);
    final outstanding = _localBondOutstanding(record);
    final years = _localResidualYears(record);
    if (marketValue <= 0 || years <= 0) continue;
    inputs.add(RateRiskInput(
      record: record,
      marketValue: marketValue,
      outstandingCapital: outstanding,
      residualYears: years,
      couponRate: _localRateFraction(record.coupon),
      yieldToMaturity: _localBondYield(record),
      paymentsPerYear: math.max(1, record.couponPaymentsPerYear),
    ));
  }

  journal.add({
    'etape': 'Extraction',
    'description': '${inputs.length} obligations actives extraites',
    'totalMarketValue': inputs.fold(0.0, (s, i) => s + i.marketValue),
  });

  final results = <RateRiskResult>[];
  var totalValue = 0.0;
  var weightedDuration = 0.0;
  var weightedConvexity = 0.0;
  var weightedMacaulay = 0.0;

  for (final input in inputs) {
    final r = _calculateInstrumentRateRisk(input, rateShockBps, journal);
    results.add(r);
    totalValue += r.marketValue;
    weightedDuration += r.modifiedDuration * r.marketValue;
    weightedConvexity += r.convexity * r.marketValue;
    weightedMacaulay += r.macaulayDuration * r.marketValue;
  }

  final portDuration = totalValue > 0 ? weightedDuration / totalValue : 0.0;
  final portConvexity = totalValue > 0 ? weightedConvexity / totalValue : 0.0;
  final portMacaulay = totalValue > 0 ? weightedMacaulay / totalValue : 0.0;
  final portSensitivity = portDuration * totalValue * 0.0001;

  journal.add({
    'etape': 'Portefeuille',
    'description': 'Agrégation des risques taux',
    'duration': portDuration,
    'convexity': portConvexity,
    'sensitivity': portSensitivity,
    'formule': 'Duration portefeuille = Σ(Duration_i × MV_i) / Σ MV_i',
  });

  final shocks = <double, RateShockResult>{};
  for (final shock in shockScenarios) {
    final linearImpact = -portDuration * (shock / 10000) * totalValue;
    final convexityAdjustment =
        0.5 * portConvexity * math.pow(shock / 10000, 2) * totalValue;
    final withConvexity = linearImpact + convexityAdjustment;
    shocks[shock.toDouble()] = RateShockResult(
      shockBps: shock.toDouble(),
      priceImpactLinear: linearImpact,
      priceImpactWithConvexity: withConvexity,
      newPrice: totalValue + withConvexity,
      label: 'Choc ${shock}bps',
    );
    journal.add({
      'etape': 'Choc ${shock}bps',
      'description': 'Scénario de hausse des taux',
      'linear': linearImpact,
      'withConvexity': withConvexity,
      'formule':
          'ΔP ≈ -D_m × Δy × P + ½ × C × (Δy)² × P = ${withConvexity.toStringAsFixed(2)}',
    });
  }

  return PortfolioRateRiskResult(
    byInstrument: results,
    totalMarketValue: totalValue,
    portfolioModifiedDuration: portDuration,
    portfolioMacaulayDuration: portMacaulay,
    portfolioConvexity: portConvexity,
    portfolioSensitivity: portSensitivity,
    shockResults: shocks,
    calculationJournal: journal,
  );
}

RateRiskResult _calculateInstrumentRateRisk(
    RateRiskInput input, double shockBps, List<Map<String, dynamic>> journal) {
  final frequency = input.paymentsPerYear;
  final periods = math.max(1, (input.residualYears * frequency).ceil());
  final couponCF = input.couponRate * input.outstandingCapital / frequency;
  final yieldPerPeriod = input.yieldToMaturity / frequency;
  final periodicBase = 1 + yieldPerPeriod;

  var macaulayNum = 0.0;
  var pv = 0.0;
  var convNum = 0.0;

  for (var period = 1; period <= periods; period++) {
    final time = math.min(period / frequency, input.residualYears);
    final cf = couponCF + (period == periods ? input.outstandingCapital : 0.0);
    if (cf <= 0) continue;
    final discount = math.pow(periodicBase, period);
    if (discount <= 0) continue;
    final dcf = cf / discount;
    pv += dcf;
    macaulayNum += time * dcf;
    convNum += cf *
        time *
        (time + 1 / frequency) /
        (discount * periodicBase * periodicBase);
  }

  if (pv <= 0) {
    return RateRiskResult(
      marketValue: input.marketValue,
      macaulayDuration: 0,
      modifiedDuration: 0,
      sensitivity: 0,
      convexity: 0,
      priceChangeLinear: 0,
      priceChangeWithConvexity: 0,
      rateShockBps: shockBps,
      yieldToMaturity: input.yieldToMaturity,
      couponRate: input.couponRate,
      residualYears: input.residualYears,
      outstandingCapital: input.outstandingCapital,
      formulaDetails: {'note': 'PV nul ou négatif'},
    );
  }

  final macaulay = macaulayNum / pv;
  final modified = macaulay / periodicBase;
  final convexity = convNum / pv;
  final sensitivity = modified * input.marketValue * 0.0001;
  final linearChange = -modified * (shockBps / 10000) * input.marketValue;
  final convexAdj =
      0.5 * convexity * math.pow(shockBps / 10000, 2) * input.marketValue;

  final details = {
    'formule_duration': 'D_mac = Σ(t × CF_t / (1+y)^t) / PV',
    'formule_modified': 'D_mod = D_mac / (1 + y/f)',
    'formule_convexite': 'C = Σ(CF_t × t × (t+1/f) / (1+y)^{t+2}) / PV',
    'formule_variation': 'ΔP ≈ -D_mod × Δy × P + ½ × C × (Δy)² × P',
    'macaulay_calculation': macaulayNum,
    'present_value': pv,
    'convexity_calculation': convNum,
  };

  return RateRiskResult(
    marketValue: input.marketValue,
    macaulayDuration: math.max(0, macaulay),
    modifiedDuration: math.max(0, modified),
    sensitivity: math.max(0, sensitivity),
    convexity: math.max(0, convexity),
    priceChangeLinear: linearChange,
    priceChangeWithConvexity: linearChange + convexAdj,
    rateShockBps: shockBps,
    yieldToMaturity: input.yieldToMaturity,
    couponRate: input.couponRate,
    residualYears: input.residualYears,
    outstandingCapital: input.outstandingCapital,
    formulaDetails: details,
  );
}

double _localBondMarketValue(MarketPortfolioRecord record) {
  if (_localIsMatured(record)) return 0;
  if (record.presentValue > 0) return record.presentValue;
  final explicit = math.max(0.0, record.valuationAmount).toDouble();
  return explicit > 0 ? explicit : _localBondOutstanding(record);
}

double _localBondOutstanding(MarketPortfolioRecord record) {
  if (_localIsMatured(record)) return 0;
  if (record.capitalRemainingDue > 0) return record.capitalRemainingDue;
  final initial =
      record.capitalInitial > 0 ? record.capitalInitial : record.exposureAmount;
  return math.max(0.0, initial).toDouble();
}

double _localResidualYears(MarketPortfolioRecord record) {
  final months = record.residualMaturityMonths;
  return months > 0 ? months / 12 : 0;
}

double _localRateFraction(double raw) {
  if (!raw.isFinite) return 0;
  return raw.abs() > 1 ? raw / 100 : raw;
}

double _localBondYield(MarketPortfolioRecord record) {
  final explicit = record.yieldToMaturity;
  final resolved = explicit > 0 ? explicit : _localRateFraction(record.coupon);
  return resolved.clamp(0.0, 1.5);
}

bool _localIsMatured(MarketPortfolioRecord record) {
  final maturity = record.maturityDate;
  if (maturity == null) return false;
  return !DateTime(maturity.year, maturity.month, maturity.day)
      .isAfter(record.resolvedAnalysisDate);
}
