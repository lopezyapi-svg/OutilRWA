import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  group('Bond reconstructed CRD', () {
    test('keeps active constant profile at capital initial', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0003',
          'Capital initial': 22605972280,
          'Profil d\'amortissement': 'constant',
          'Fréquence de paiement des intérêts': 'Semestrielle',
          'Maturité (mois)': 180,
          'Maturité résiduelle (mois)': 172,
          'Coupon (%)': 0.049,
        },
      );

      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(22605972280, epsilon: 0.01),
      );
      expect(record.capitalAlreadyRepaid, 0);
    });

    test('keeps active constant annuity profile at capital initial', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0007',
          'Capital initial': 82474291920,
          'Profil d\'amortissement': 'annuité constante',
          'Fréquence de paiement des intérêts': 'Trimestrielle',
          'Maturité (mois)': 144,
          'Maturité résiduelle (mois)': 132,
          'Coupon (%)': 0.0965,
        },
      );

      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(82474291920, epsilon: 0.01),
      );
      expect(record.capitalAlreadyRepaid, 0);
    });

    test('keeps active short monthly Treasury bill at capital initial', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0344',
          'Type d\'instrument': 'Bon du trésor - BT',
          'Code type d\'instrument': 'BT',
          'Capital initial': 3360715988,
          'Profil d\'amortissement': 'constant',
          'Fréquence de paiement des intérêts': 'Mensuelle',
          'Maturité (mois)': 36,
          'Maturité résiduelle (mois)': 23,
          'Coupon (%)': 0.0862,
        },
      );

      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(3360715988, epsilon: 0.01),
      );
      expect(record.capitalAlreadyRepaid, 0);
    });

    test('keeps active long monthly Treasury bill at capital initial', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0138',
          'Type d\'instrument': 'Bon du trésor - BT',
          'Code type d\'instrument': 'BT',
          'Capital initial': 32558786099,
          'Profil d\'amortissement': 'constant',
          'Fréquence de paiement des intérêts': 'Mensuelle',
          'Maturité (mois)': 156,
          'Maturité résiduelle (mois)': 146,
          'Coupon (%)': 0.0854,
        },
      );

      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(32558786099, epsilon: 0.01),
      );
    });

    test('derives maturities from dates before imported month columns', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Date d\'analyse': DateTime(2026, 6, 1),
          'Date d\'émission': DateTime(2024, 1, 1),
          'Date d\'échéance': DateTime(2032, 1, 1),
          'Maturité (mois)': 1,
          'Maturité résiduelle (mois)': 1,
        },
      );

      expect(record.maturityMonths, 96);
      expect(record.residualMaturityMonths, 67);
      expect(record.isActiveAtAnalysisDate, isTrue);
    });

    test('sets matured bonds outstanding capital to zero', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Date d\'analyse': DateTime(2026, 6, 1),
          'Date d\'émission': DateTime(2024, 1, 1),
          'Date d\'échéance': DateTime(2026, 6, 1),
          'Capital initial': 1000000000,
          'Profil d\'amortissement': 'In fine',
          'Fréquence de paiement des intérêts': 'Annuelle',
        },
      );

      expect(record.isMaturedAtAnalysisDate, isTrue);
      expect(record.residualMaturityMonths, 0);
      expect(record.resolvedCapitalRemainingDue, 0);
    });

    test('keeps present value distinct from active capital', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Capital initial': 1000000000,
          'Valeur actualisée': 950000000,
        },
      );

      expect(record.resolvedCapitalRemainingDue, 1000000000);
      expect(record.presentValue, 950000000);
    });

    test('builds issuer analysis identity from country and issuer', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Pays émetteur': 'Côte d\'Ivoire',
          'Emetteur': 'Trésor public',
        },
      );

      expect(record.issuerCountryIso3, 'CIV');
      expect(record.issuerAnalysisKey, 'CIV|Trésor public');
      expect(record.issuerAnalysisLabel, 'Trésor public (CIV)');
    });
  });
}
