import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/foreign_exchange_risk_service.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_risk_aggregation_service.dart';

MarketPrudentialCapitalResult _baseWithForeignExchangeApproximation({
  required double foreignExchangeRisk,
  required double foreignExchangeGlobalNetPosition,
}) {
  return MarketPrudentialCapitalResult(
    interestRateSpecificRisk: 0,
    interestRateGeneralRisk: 0,
    equitySpecificRisk: 0,
    equityGeneralRisk: 0,
    foreignExchangeRisk: foreignExchangeRisk,
    commodityDirectionalRisk: 0,
    commodityBasisRisk: 0,
    interestRateSpecificRiskWeightAverage: 0,
    interestRateGeneralRiskWeightAverage: 0,
    equityGrossPosition: 0,
    equityNetPosition: 0,
    foreignExchangeGlobalNetPosition: foreignExchangeGlobalNetPosition,
    commodityGrossPosition: 0,
    commodityNetPosition: 0,
  );
}

void main() {
  group('applyRealForeignExchangeRisk', () {
    test(
        'aucune position actif/passif saisie : conserve l\'approximation '
        'tirée des colonnes devise des titres importés (ne remplace pas par zéro)',
        () {
      final base = _baseWithForeignExchangeApproximation(
        foreignExchangeRisk: 1008000000, // 1,008 Md FCFA (9 % de 11,2 Md)
        foreignExchangeGlobalNetPosition: 11200000000,
      );

      final result = applyRealForeignExchangeRisk(base, const []);

      expect(result.foreignExchangeRisk, base.foreignExchangeRisk);
      expect(result.foreignExchangeGlobalNetPosition,
          base.foreignExchangeGlobalNetPosition);
      expect(result.marketRwa, base.marketRwa);
    });

    test(
        'positions actif/passif saisies : remplace l\'approximation par le '
        'risque réel calculé sur ces positions', () {
      final base = _baseWithForeignExchangeApproximation(
        foreignExchangeRisk: 1008000000,
        foreignExchangeGlobalNetPosition: 11200000000,
      );
      const positions = [
        ForeignExchangePosition(
          currency: 'USD',
          assets: 500000000,
          liabilities: 0,
          forwardPurchases: 0,
          forwardSales: 0,
        ),
      ];

      final result = applyRealForeignExchangeRisk(base, positions);

      expect(result.foreignExchangeGlobalNetPosition, 500000000);
      expect(result.foreignExchangeRisk, 500000000 * 0.09);
      expect(result.foreignExchangeRisk, isNot(base.foreignExchangeRisk));
    });
  });
}
