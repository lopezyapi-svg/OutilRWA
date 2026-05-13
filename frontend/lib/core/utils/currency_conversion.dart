import 'formatters.dart';

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
}) {
  final converted = convertCurrencyAmount(
    amount,
    fromCurrency: fromCurrency,
    toCurrency: toCurrency,
  );
  return AppFormatters.currency(converted, currencyCode: toCurrency);
}

String compactCurrencyForDisplay(
  double amount, {
  String fromCurrency = 'XOF',
  required String toCurrency,
}) {
  final converted = convertCurrencyAmount(
    amount,
    fromCurrency: fromCurrency,
    toCurrency: toCurrency,
  );
  return '${AppFormatters.compactNumber(converted)} ${displayCurrencyLabel(toCurrency)}';
}
