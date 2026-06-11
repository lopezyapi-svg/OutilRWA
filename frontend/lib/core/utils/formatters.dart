// Ce fichier regroupe les formateurs utilises dans l'interface.
import 'package:intl/intl.dart';

import '../localization/app_localization.dart';

/// Centralise les formats d'affichage des montants, pourcentages et dates.
class AppFormatters {
  static String currency(num value, {String currencyCode = 'XOF'}) {
    final formatter = NumberFormat.currency(
      locale: currencyCode.toUpperCase() == 'USD'
          ? 'en_US'
          : AppLocalizations.currentLanguage.intlLocale,
      symbol: _currencySymbol(currencyCode),
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  static String compactNumber(num value) {
    final amount = value.toDouble();
    final absolute = amount.abs();

    final decimals = absolute >= 100
        ? 0
        : absolute >= 10
            ? 1
            : 2;
    return _number(decimals).format(amount);
  }

  static String decimalNumber(num value, {int maxDecimals = 2}) {
    return _number(maxDecimals).format(value);
  }

  static String integer(num value) => _plainNumber().format(value.round());

  static String percent(num value) => NumberFormat.decimalPercentPattern(
        locale: AppLocalizations.currentLanguage.intlLocale,
        decimalDigits: 1,
      ).format(value);

  static String shortDate(DateTime value) => DateFormat(
        'dd/MM/yyyy',
        AppLocalizations.currentLanguage.intlLocale,
      ).format(value);

  static String _currencySymbol(String currencyCode) {
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

  static NumberFormat _plainNumber() =>
      NumberFormat.decimalPattern(AppLocalizations.currentLanguage.intlLocale);

  static NumberFormat _number(int decimalDigits) {
    return NumberFormat.decimalPattern(
      AppLocalizations.currentLanguage.intlLocale,
    )
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = decimalDigits;
  }
}
