import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/models/fx_security_analysis.dart';

void main() {
  group('FxSecurityAnalysis Model Calculations', () {
    final now = DateTime.now();

    test('RWA is 0.0 for local currency XOF', () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T001',
        titleName: 'Obligation XOF',
        currency: 'XOF',
        initialValue: 10000.0,
        currentValue: 10000.0,
        initialRate: 1.0,
        currentRate: 1.0,
        quantity: 100.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      expect(analysis.rwa, 0.0);
      expect(analysis.currentValueInXof, 10000.0 * 100.0 * 1.0);
    });

    test('RWA is 0.0 for local currency XAF', () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T002',
        titleName: 'Obligation XAF',
        currency: 'XAF',
        initialValue: 5000.0,
        currentValue: 5000.0,
        initialRate: 1.0,
        currentRate: 1.0,
        quantity: 50.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      expect(analysis.rwa, 0.0);
    });

    test('RWA is 100% of currentValueInXof for foreign currencies (USD)', () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T003',
        titleName: 'Obligation USD',
        currency: 'USD',
        initialValue: 100.0,
        currentValue: 110.0,
        initialRate: 600.0,
        currentRate: 610.0,
        quantity: 10.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      // currentValueInXof = currentValue * quantity * currentRate = 110.0 * 10.0 * 610.0 = 671,000.0
      expect(analysis.currentValueInXof, 671000.0);
      expect(analysis.rwa, 671000.0);
    });

    test('fxGainLoss and currencyVariationPercent are calculated correctly', () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T004',
        titleName: 'Obligation EUR',
        currency: 'EUR',
        initialValue: 200.0,
        currentValue: 200.0,
        initialRate: 650.0,
        currentRate: 655.0,
        quantity: 5.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      // initialValueInXof = 200 * 5 * 650 = 650,000.0
      // currentValueInXof = 200 * 5 * 655 = 655,000.0
      // fxGainLoss = 655,000.0 - 650,000.0 = 5,000.0
      expect(analysis.fxGainLoss, 5000.0);
      expect(analysis.currencyVariationPercent, closeTo(((655.0 - 650.0) / 650.0) * 100, 0.0001));
    });
  });
}
