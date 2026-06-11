import 'formatters.dart';

enum PortfolioAmountUnit {
  million('M', 1000000),
  billion('Md', 1000000000);

  const PortfolioAmountUnit(this.label, this.divisor);

  final String label;
  final double divisor;
}

class PortfolioAmountUnitPreference {
  static PortfolioAmountUnit current = PortfolioAmountUnit.billion;
}

const Map<String, double> _currencyRatesInXof = {
  'XOF': 1.0,
  'EUR': 655.957,
  'USD': 600.0,
};

String normalizeCurrencyCode(String currencyCode) {
  final normalized = currencyCode.trim().toUpperCase();
  if (normalized == 'XAF' || normalized == 'FCFA') {
    return 'XOF';
  }
  return normalized;
}

double convertCurrencyAmount(
  double amount, {
  required String fromCurrency,
  required String toCurrency,
}) {
  final normalizedFrom = normalizeCurrencyCode(fromCurrency);
  final normalizedTo = normalizeCurrencyCode(toCurrency);
  final fromRate = _currencyRatesInXof[normalizedFrom] ?? 1.0;
  final toRate = _currencyRatesInXof[normalizedTo] ?? 1.0;
  final amountInXof = amount * fromRate;
  return amountInXof / toRate;
}

String displayCurrencyLabel(String currencyCode) {
  switch (normalizeCurrencyCode(currencyCode)) {
    case 'XOF':
      return 'FCFA';
    case 'EUR':
      return 'EUR';
    case 'USD':
      return 'USD';
    default:
      return currencyCode.toUpperCase();
  }
}

String formatCurrencyForDisplay(
  double amount, {
  String fromCurrency = 'XOF',
  required String toCurrency,
  int maxDecimals = 2,
}) {
  return formatCurrencyInDisplayUnit(
    amount,
    fromCurrency: fromCurrency,
    toCurrency: toCurrency,
    amountUnit: PortfolioAmountUnitPreference.current,
    maxDecimals: maxDecimals,
  );
}

String compactCurrencyForDisplay(
  double amount, {
  String fromCurrency = 'XOF',
  required String toCurrency,
  PortfolioAmountUnit? amountUnit,
  int maxDecimals = 2,
}) {
  return formatCurrencyInDisplayUnit(
    amount,
    fromCurrency: fromCurrency,
    toCurrency: toCurrency,
    amountUnit: amountUnit ?? PortfolioAmountUnitPreference.current,
    maxDecimals: maxDecimals,
  );
}

String formatCurrencyInDisplayUnit(
  double amount, {
  String fromCurrency = 'XOF',
  required String toCurrency,
  required PortfolioAmountUnit amountUnit,
  int maxDecimals = 2,
}) {
  final converted = convertCurrencyAmount(
    amount,
    fromCurrency: fromCurrency,
    toCurrency: toCurrency,
  );
  final scaled = converted / amountUnit.divisor;
  return '${AppFormatters.decimalNumber(scaled, maxDecimals: maxDecimals)} ${amountUnit.label} ${displayCurrencyLabel(toCurrency)}';
}
