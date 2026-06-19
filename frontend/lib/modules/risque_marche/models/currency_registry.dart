/// Référentiel des devises et taux de conversion
/// Utilisé pour convertir les positions en devise de référence (XOF)

/// Représente une devise avec son taux de change
class CurrencyRate {
  const CurrencyRate({
    required this.code,
    required this.label,
    required this.rateToXof,
    required this.lastUpdate,
  });

  final String code;                  // Code devise (USD, EUR, etc.)
  final String label;                 // Libellé complet
  final double rateToXof;             // Taux de change vers XOF
  final DateTime lastUpdate;          // Date de mise à jour du taux

  /// Convertit une montant depuis cette devise vers XOF
  double toXof(double amount) => amount * rateToXof;

  /// Convertit un montant depuis XOF vers cette devise
  double fromXof(double xofAmount) => xofAmount / rateToXof;
}

/// Référentiel des devises principales
class CurrencyRegistry {
  static final CurrencyRegistry _instance = CurrencyRegistry._internal();

  factory CurrencyRegistry() {
    return _instance;
  }

  CurrencyRegistry._internal();

  // L'application ne gère que trois devises principales : XOF, EUR, USD.
  // Les taux sont alignés sur ceux de `currency_conversion.dart` et du backend
  // (`calculations.py`) pour garantir une source unique et cohérente.
  // XAF/FCFA sont repliés vers XOF par `normalizeCurrencyCode`.
  final Map<String, CurrencyRate> _rates = {
    'XOF': CurrencyRate(
      code: 'XOF',
      label: 'Franc CFA BCEAO',
      rateToXof: 1.0,
      lastUpdate: DateTime(2026, 6, 17),
    ),
    'EUR': CurrencyRate(
      code: 'EUR',
      label: 'Euro',
      rateToXof: 655.957, // Parité fixe FCFA/Euro
      lastUpdate: DateTime(2026, 6, 17),
    ),
    'USD': CurrencyRate(
      code: 'USD',
      label: 'Dollar américain',
      rateToXof: 600.0,
      lastUpdate: DateTime(2026, 6, 17),
    ),
  };

  /// Récupère le taux de change pour une devise
  CurrencyRate? getRate(String currencyCode) => _rates[currencyCode];

  /// Retourne toutes les devises disponibles
  List<CurrencyRate> getAllRates() => _rates.values.toList();

  /// Met à jour un taux de change
  void updateRate(String currencyCode, double newRate) {
    final existing = _rates[currencyCode];
    if (existing != null) {
      _rates[currencyCode] = CurrencyRate(
        code: existing.code,
        label: existing.label,
        rateToXof: newRate,
        lastUpdate: DateTime.now(),
      );
    }
  }
}

/// Analyse statistique des positions
class PositionAnalysis {
  const PositionAnalysis({
    required this.totalDevises,
    required this.longPositions,
    required this.shortPositions,
    required this.neutralPositions,
    required this.averagePositionSize,
    required this.largestLongPosition,
    required this.largestShortPosition,
    required this.concentrationRatio,
  });

  final int totalDevises;                 // Nombre de devises
  final int longPositions;                // Nombre de positions longues
  final int shortPositions;               // Nombre de positions courtes
  final int neutralPositions;             // Nombre de positions neutres
  final double averagePositionSize;       // Taille moyenne en XOF
  final double largestLongPosition;       // Plus grande position longue
  final double largestShortPosition;      // Plus grande position courte
  final double concentrationRatio;        // Ratio de concentration (0-1)
}
