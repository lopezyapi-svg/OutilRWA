// Ce fichier regroupe les formateurs utilises dans l'interface.
import 'package:intl/intl.dart';

import '../localization/app_localization.dart';

/// Top-level formatter functions for easy access
String formatLargeNumber(num value) => AppFormatters.compactNumber(value);

String formatDecimal(num value, int decimals) =>
    AppFormatters.decimalNumber(value, maxDecimals: decimals);

/// Centralise les formats d'affichage des montants, pourcentages et dates.
class AppFormatters {
  static final Map<String, NumberFormat> _currencyFormatCache = {};
  static final Map<String, NumberFormat> _percentFormatCache = {};
  static final Map<String, DateFormat> _shortDateFormatCache = {};

  static String currency(num value, {String currencyCode = 'XOF'}) {
    final upper = currencyCode.toUpperCase();
    final locale =
        upper == 'USD' ? 'en_US' : AppLocalizations.currentLanguage.intlLocale;
    final key = '$locale:$upper';
    final formatter = _currencyFormatCache.putIfAbsent(key, () {
      return NumberFormat.currency(
        locale: locale,
        symbol: _currencySymbol(currencyCode),
        decimalDigits: 0,
      );
    });
    return formatter.format(value);
  }

  static String compactNumber(num value) {
    final amount = value.toDouble();
    final absolute = amount.abs();

    int decimals;
    if (absolute == 0) {
      decimals = 0;
    } else if (absolute >= 1000) {
      decimals = 0;
    } else if (absolute >= 100) {
      decimals = 1;
    } else if (absolute >= 10) {
      decimals = 2;
    } else if (absolute >= 1) {
      decimals = 3;
    } else {
      decimals = 4;
    }
    
    return _number(decimals).format(amount);
  }

  static String decimalNumber(num value, {int maxDecimals = 2}) {
    return _number(maxDecimals).format(value);
  }

  static String integer(num value) => _plainNumber().format(value.round());

  static String percent(num value) {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    final formatter = _percentFormatCache.putIfAbsent(locale, () {
      return NumberFormat.decimalPercentPattern(
          locale: locale, decimalDigits: 1);
    });
    return formatter.format(value);
  }

  static String shortDate(DateTime value) {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    final formatter = _shortDateFormatCache.putIfAbsent(
      locale,
      () => DateFormat('dd/MM/yyyy', locale),
    );
    return formatter.format(value);
  }

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

  static final Map<String, NumberFormat> _plainFormatCache = {};
  static final Map<String, NumberFormat> _numberFormatCache = {};

  static NumberFormat _plainNumber() {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    return _plainFormatCache.putIfAbsent(
      locale,
      () => NumberFormat.decimalPattern(locale),
    );
  }

  static NumberFormat _number(int decimalDigits) {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    final key = '$locale:$decimalDigits';
    return _numberFormatCache.putIfAbsent(key, () {
      return NumberFormat.decimalPattern(locale)
        ..minimumFractionDigits = 0
        ..maximumFractionDigits = decimalDigits;
    });
  }
}
