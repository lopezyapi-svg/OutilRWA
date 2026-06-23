import 'dart:math' as math;
import 'market_data_import_store.dart';
import 'interest_rate_risk_service.dart';
import 'fx_risk_service.dart';
import 'equity_risk_service.dart';
import 'var_service.dart';
import 'stress_testing_service.dart';
import 'uemoa_prudential_service.dart';
import 'governance_service.dart';

class MarketRiskOrchestrator {
  final BacktestingService governance = BacktestingService.instance;

  static final MarketRiskOrchestrator instance = MarketRiskOrchestrator._();
  MarketRiskOrchestrator._();

  var _lastBondRecords = <MarketPortfolioRecord>[];
  var _lastEquityRecords = <MarketPortfolioRecord>[];
  var _lastAllRecords = <MarketPortfolioRecord>[];
  MarketPortfolioDataset? _lastBondDataset;
  MarketPortfolioDataset? _lastEquityDataset;

  void loadFromSnapshot(MarketDataSnapshot snapshot) {
    _lastBondDataset = snapshot.datasets[MarketPortfolioType.bonds];
    _lastEquityDataset = snapshot.datasets[MarketPortfolioType.equities];
    _lastBondRecords = _lastBondDataset?.records ?? [];
    _lastEquityRecords = _lastEquityDataset?.records ?? [];
    _lastAllRecords = [..._lastBondRecords, ..._lastEquityRecords];
  }

  bool get hasData => _lastAllRecords.isNotEmpty;

  // ===== RISQUE DE TAUX =====
  PortfolioRateRiskResult computeRateRisk({
    double rateShockBps = 100,
    List<double> shockScenarios = const [25, 50, 100, 200, 300],
  }) {
    final result = calculatePortfolioRateRisk(
      records: _lastBondRecords,
      rateShockBps: rateShockBps,
      shockScenarios: shockScenarios,
    );
    governance.addAuditEntry(
      service: 'interest_rate_risk',
      operation: 'calculatePortfolioRateRisk',
      inputSummary: {
        'records': _lastBondRecords.length,
        'rateShockBps': rateShockBps,
      },
      outputSummary: {
        'totalMarketValue': result.totalMarketValue,
        'portfolioDuration': result.portfolioModifiedDuration,
      },
    );
    return result;
  }

  // ===== RISQUE DE CHANGE =====
  FxRiskResult computeFxRisk({
    List<double> shockScenarios = const [5, 10],
  }) {
    final result = calculateFxRisk(
      records: _lastAllRecords,
      shockScenarios: shockScenarios,
    );
    governance.addAuditEntry(
      service: 'fx_risk',
      operation: 'calculateFxRisk',
      inputSummary: {'records': _lastAllRecords.length},
      outputSummary: {
        'globalNetPosition': result.globalNetPosition,
        'capitalRequirement': result.capitalRequirement,
      },
    );
    return result;
  }

  // ===== RISQUE ACTIONS =====
  EquityRiskResult computeEquityRisk() {
    final result = calculateEquityRisk(records: _lastEquityRecords);
    governance.addAuditEntry(
      service: 'equity_risk',
      operation: 'calculateEquityRisk',
      inputSummary: {'records': _lastEquityRecords.length},
      outputSummary: {
        'totalMarketValue': result.totalMarketValue,
        'capitalRequirement': result.capitalRequirement,
      },
    );
    return result;
  }

  // ===== VAR HISTORIQUE =====
  VarEngineResult computeHistoricalVar({
    List<double> confidences = const [0.95, 0.99],
    List<int> horizons = const [1, 10],
  }) {
    final historicalReturns = _buildHistoricalReturns();
    final portfolioValue = _totalMarketValue();
    final result = calculateHistoricalVar(
      input: HistoricalVarInput(
        historicalReturns: historicalReturns,
        portfolioValue: portfolioValue,
      ),
      confidences: confidences,
      horizons: horizons,
    );
    governance.addAuditEntry(
      service: 'var_historical',
      operation: 'calculateHistoricalVar',
      inputSummary: {
        'observations': historicalReturns.length,
        'portfolioValue': portfolioValue,
      },
      outputSummary: {'summary': result.summary},
    );
    return result;
  }

  // ===== VAR PARAMETRIQUE =====
  VarEngineResult computeParametricVar({
    List<double> confidences = const [0.95, 0.99],
    List<int> horizons = const [1, 10],
  }) {
    final dataset = _lastBondDataset ?? _lastEquityDataset;
    final portfolioValue = _totalMarketValue();
    final result = calculateParametricVar(
      input: ParametricVarInput(
        portfolioValue: portfolioValue,
        annualVolatility: dataset?.annualizedVolatility ?? 0,
        modifiedDuration: dataset?.parametricModifiedDuration ?? 0,
        expectedReturn: dataset?.expectedReturn ?? 0,
        riskFreeRate: 0,
      ),
      confidences: confidences,
      horizons: horizons,
    );
    governance.addAuditEntry(
      service: 'var_parametric',
      operation: 'calculateParametricVar',
      inputSummary: {
        'portfolioValue': portfolioValue,
        'annualVolatility': dataset?.annualizedVolatility,
      },
      outputSummary: {'summary': result.summary},
    );
    return result;
  }

  // ===== VAR MONTE-CARLO =====
  VarEngineResult computeMonteCarloVar({
    List<double> confidences = const [0.95, 0.99],
    List<int> horizons = const [1, 10],
    int numSimulations = 10000,
  }) {
    final dataset = _lastBondDataset ?? _lastEquityDataset;
    final portfolioValue = _totalMarketValue();
    final result = calculateMonteCarloVar(
      input: MonteCarloVarInput(
        portfolioValue: portfolioValue,
        annualVolatility: dataset?.annualizedVolatility ?? 0,
        expectedReturn: dataset?.expectedReturn ?? 0,
        numSimulations: numSimulations,
        modifiedDuration: dataset?.parametricModifiedDuration ?? 0,
        bondRecords: _lastBondRecords,
        equityRecords: _lastEquityRecords,
      ),
      confidences: confidences,
      horizons: horizons,
    );
    governance.addAuditEntry(
      service: 'var_monte_carlo',
      operation: 'calculateMonteCarloVar',
      inputSummary: {
        'portfolioValue': portfolioValue,
        'simulations': numSimulations,
      },
      outputSummary: {'summary': result.summary},
    );
    return result;
  }

  // ===== COMPARAISON VAR =====
  VarComparisonResult computeVarComparison({
    double confidence = 0.99,
    int horizonDays = 1,
    int numSimulations = 10000,
  }) {
    final historicalReturns = _buildHistoricalReturns();
    final portfolioValue = _totalMarketValue();
    final dataset = _lastBondDataset ?? _lastEquityDataset;
    return compareVarMethods(
      historicalInput: HistoricalVarInput(
        historicalReturns: historicalReturns,
        portfolioValue: portfolioValue,
      ),
      parametricInput: ParametricVarInput(
        portfolioValue: portfolioValue,
        annualVolatility: dataset?.annualizedVolatility ?? 0,
        modifiedDuration: dataset?.parametricModifiedDuration ?? 0,
        expectedReturn: dataset?.expectedReturn ?? 0,
        riskFreeRate: 0,
      ),
      monteCarloInput: MonteCarloVarInput(
        portfolioValue: portfolioValue,
        annualVolatility: dataset?.annualizedVolatility ?? 0,
        expectedReturn: dataset?.expectedReturn ?? 0,
        numSimulations: numSimulations,
        modifiedDuration: dataset?.parametricModifiedDuration ?? 0,
        bondRecords: _lastBondRecords,
        equityRecords: _lastEquityRecords,
      ),
      confidence: confidence,
      horizonDays: horizonDays,
    );
  }

  // ===== STRESS TESTING =====
  StressTestingResult computeStressTests({
    required double baseCapitalRequirement,
    double baseCapitalRatio = 0.12,
  }) {
    final result = calculateStressScenarios(
      allRecords: _lastAllRecords,
      baseCapitalRequirement: baseCapitalRequirement,
      baseCapitalRatio: baseCapitalRatio,
    );
    governance.addAuditEntry(
      service: 'stress_testing',
      operation: 'calculateStressScenarios',
      inputSummary: {
        'records': _lastAllRecords.length,
        'capital': baseCapitalRequirement,
      },
      outputSummary: {
        'worstScenario': result.worstScenario,
        'worstLoss': result.worstLoss,
      },
    );
    return result;
  }

  // ===== UEMOA PRUDENTIAL =====
  UemoaCapitalRequirement computeUemoaCapital() {
    final prudentialResult = calculateMarketPrudentialCapital(
      records: _lastAllRecords,
    );
    return calculateUemoaMarketCapitalRequirement(
      prudentialResult: prudentialResult,
    );
  }

  UemoaLimitCheck checkUemoaCompliance({
    required double actualCapital,
    double minimumRatio = 0.085, // Seuil de solvabilité minimum UMOA
  }) {
    final prudentialResult = calculateMarketPrudentialCapital(
      records: _lastAllRecords,
    );
    return checkUemoaCapitalLimit(
      actualCapital: actualCapital,
      marketRwa: prudentialResult.marketRwa,
      minimumRatio: minimumRatio,
    );
  }

  // ===== FULL RISK REPORT =====
  Map<String, dynamic> generateFullRiskReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'portfolio': {
        'totalValue': _totalMarketValue(),
        'bonds': _lastBondRecords.length,
        'equities': _lastEquityRecords.length,
      },
      'services_disponibles': [
        'interest_rate_risk',
        'fx_risk',
        'equity_risk',
        'var_historical',
        'var_parametric',
        'var_monte_carlo',
        'stress_testing',
        'uemoa_prudential',
        'governance',
      ],
      'note': 'Tous les services sont indépendants et auditables.',
    };
  }

  // ===== HELPERS =====
  double _totalMarketValue() {
    double total = 0;
    for (final r in _lastBondRecords) {
      total += r.valuationAmount > 0 ? r.valuationAmount : r.exposureAmount;
    }
    for (final r in _lastEquityRecords) {
      total += r.marketValue > 0 ? r.marketValue : r.exposureAmount;
    }
    return total;
  }

  List<double> _buildHistoricalReturns() {
    final totalsByDate = <int, double>{};
    for (final r in _lastAllRecords) {
      final date = r.analysisDate;
      if (date == null) continue;
      final amount = math.max(0.0, r.valuationAmount).toDouble();
      if (amount <= 0) continue;
      final key = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      totalsByDate.update(key, (v) => v + amount, ifAbsent: () => amount);
    }
    final dates = totalsByDate.keys.toList()..sort();
    if (dates.length < 2) return [];
    final returns = <double>[];
    for (var i = 1; i < dates.length; i++) {
      final prev = totalsByDate[dates[i - 1]] ?? 0;
      final curr = totalsByDate[dates[i]] ?? 0;
      if (prev <= 0 || curr <= 0) continue;
      final r = (curr - prev) / prev;
      if (r.isFinite) returns.add(r);
    }
    return returns;
  }
}
