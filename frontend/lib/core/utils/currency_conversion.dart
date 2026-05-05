import 'formatters.dart';

const Map<String, double> _currencyRatesInXof = {
  'XOF': 1.0,
  'XAF': 1.0,
  'EUR': 655.957,
  'USD': 600.0,
};

double convertCurrencyAmount(
  double amount, {
  required String fromCurrency,
  required String toCurrency,
}) {
  final normalizedFrom = fromCurrency.toUpperCase();
  final normalizedTo = toCurrency.toUpperCase();
  final fromRate = _currencyRatesInXof[normalizedFrom] ?? 1.0;
  final toRate = _currencyRatesInXof[normalizedTo] ?? 1.0;
  final amountInXof = amount * fromRate;
  return amountInXof / toRate;
}

String displayCurrencyLabel(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'XOF':
    case 'XAF':
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
