import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  group('Bond reconstructed CRD', () {
    test('reconstructs active constant profile with linear principal', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0003',
          'Capital initial': 22605972280,
          'Profil d\'amortissement': 'constant',
          'Fréquence de paiement des intérêts': 'Semestrielle',
          'Maturité (mois)': 180,
          'Maturité résiduelle (mois)': 156,
          'Coupon (%)': 0.049,
        },
      );

      const expectedCapital = 22605972280 * 26 / 30;
      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(expectedCapital, epsilon: 0.01),
      );
      expect(
        record.capitalAlreadyRepaid,
        moreOrLessEquals(22605972280 - expectedCapital, epsilon: 0.01),
      );
    });

    test('reconstructs active constant annuity profile after paid periods', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0007',
          'Capital initial': 82474291920,
          'Profil d\'amortissement': 'annuité constante',
          'Fréquence de paiement des intérêts': 'Trimestrielle',
          'Maturité (mois)': 144,
          'Maturité résiduelle (mois)': 116,
          'Coupon (%)': 0.0965,
        },
      );

      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(73252186595.82242, epsilon: 0.01),
      );
      expect(
        record.capitalAlreadyRepaid,
        moreOrLessEquals(9222105324.17758, epsilon: 0.01),
      );
    });

    test('reconstructs active short monthly Treasury bill with linear profile',
        () {
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

      const expectedCapital = 3360715988 * 23 / 36;
      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(expectedCapital, epsilon: 0.01),
      );
      expect(
        record.capitalAlreadyRepaid,
        moreOrLessEquals(3360715988 - expectedCapital, epsilon: 0.01),
      );
    });

    test('reconstructs active long monthly Treasury bill with linear profile',
        () {
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

      const expectedCapital = 32558786099 * 146 / 156;
      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(expectedCapital, epsilon: 0.01),
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

    test('zero coupon profile does not create coupon cashflows', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Profil d\'amortissement': 'Zéro coupon',
          'Fréquence de paiement des intérêts': 'Semestrielle',
          'Maturité résiduelle (mois)': 60,
          'Valeur nominale unitaire': 100,
          'quantités': 1,
          'Coupon (%)': 0.05,
        },
      );

      expect(record.bondMacaulayDuration, moreOrLessEquals(5, epsilon: 1e-9));
      expect(
        record.bondModifiedDuration,
        moreOrLessEquals(5 / (1 + 0.05 / 2), epsilon: 1e-9),
      );
      expect(
        record.bondCashflowPresentValue,
        moreOrLessEquals(100 /
            (1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025)),
      );
    });

    test('redemption price does not reduce principal cashflow', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Profil d\'amortissement': 'Zéro coupon',
          'Fréquence de paiement des intérêts': 'Annuelle',
          'Maturité résiduelle (mois)': 12,
          'Valeur nominale unitaire': 100,
          'quantités': 1,
          'Coupon (%)': 0,
          'Prix de remboursement': 40,
          'Prime de remboursement': -60,
        },
      );

      expect(record.bondCashflowPresentValue, moreOrLessEquals(100));
    });
  });

  group('Market data snapshot architecture', () {
    test('dataset content signature ignores technical import timestamp', () {
      const record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0001',
          'Capital initial': 1000000000,
          'Coupon (%)': 0.05,
        },
      );
      final first = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6),
        headers: const ['ID Titre', 'Capital initial', 'Coupon (%)'],
        records: const [record],
      );
      final restored = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6, 2, 12),
        headers: const ['ID Titre', 'Capital initial', 'Coupon (%)'],
        records: const [record],
      );

      expect(first.contentSignature, restored.contentSignature);
      expect(
        MarketDataSnapshot.fromDatasets({
          MarketPortfolioType.bonds: first,
        }).contentSignature,
        MarketDataSnapshot.fromDatasets({
          MarketPortfolioType.bonds: restored,
        }).contentSignature,
      );
    });

    test('dataset content signature changes when portfolio content changes',
        () {
      final first = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6),
        headers: const ['ID Titre', 'Capital initial'],
        records: const [
          MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.bonds,
            values: {
              'ID Titre': 'CP0001',
              'Capital initial': 1000000000,
            },
          ),
        ],
      );
      final changed = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6),
        headers: const ['ID Titre', 'Capital initial'],
        records: const [
          MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.bonds,
            values: {
              'ID Titre': 'CP0001',
              'Capital initial': 1200000000,
            },
          ),
        ],
      );

      expect(first.contentSignature, isNot(changed.contentSignature));
    });
  });
}
