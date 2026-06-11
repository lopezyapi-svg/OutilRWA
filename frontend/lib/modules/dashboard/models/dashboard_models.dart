import 'dart:math' as math;

// Ce fichier decrit les donnees affichees sur le dashboard.
/// Modèle d'une métrique affichée sur le tableau de bord.
class DashboardMetric {
  const DashboardMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.variation,
    required this.trend,
  });

  final String key;
  final String label;
  final double value;
  final String variation;
  final List<double> trend;

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    return DashboardMetric(
      key: json['key'] as String,
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
      variation: json['variation'] as String,
      trend: (json['trend'] as List<dynamic>)
          .map((item) => (item as num).toDouble())
          .toList(),
    );
  }
}

/// Modèle d'une ligne de répartition pour un graphique.
class DistributionEntry {
  const DistributionEntry({
    required this.label,
    required this.amount,
    required this.percentage,
  });

  final String label;
  final double amount;
  final double percentage;

  factory DistributionEntry.fromJson(Map<String, dynamic> json) {
    return DistributionEntry(
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

/// Représente une ligne synthétique du portefeuille.
class PortfolioRow {
  const PortfolioRow({
    required this.id,
    this.analysisDate,
    required this.counterparty,
    required this.country,
    required this.category,
    required this.rating,
    required this.crmType,
    required this.grossAmount,
    double? onBalanceExposureAmount,
    required this.offBalanceExposureAmount,
    required this.ead,
    required this.rwa,
    required this.capital,
  }) : _onBalanceExposureAmount = onBalanceExposureAmount;

  final String id;
  final DateTime? analysisDate;
  final String counterparty;
  final String country;
  final String category;
  final String rating;
  final String crmType;
  final double grossAmount;
  final double? _onBalanceExposureAmount;
  final double offBalanceExposureAmount;
  final double ead;
  final double rwa;
  final double capital;

  double get onBalanceExposureAmount {
    final value = _onBalanceExposureAmount;
    if (value != null) return value;
    if (offBalanceExposureAmount > grossAmount) {
      return grossAmount;
    }
    return math.max(0.0, grossAmount - offBalanceExposureAmount);
  }

  factory PortfolioRow.fromJson(Map<String, dynamic> json) {
    final grossAmount = (json['gross_amount'] as num).toDouble();
    final rawAnalysisDate = json['analysis_date'] as String?;
    final offBalanceExposureAmount =
        (json['off_balance_exposure_amount'] as num?)?.toDouble() ?? 0.0;
    final onBalanceExposureAmount =
        (json['on_balance_exposure_amount'] as num?)?.toDouble();

    return PortfolioRow(
      id: json['id'] as String,
      analysisDate: rawAnalysisDate == null || rawAnalysisDate.isEmpty
          ? null
          : DateTime.tryParse(rawAnalysisDate),
      counterparty: json['counterparty'] as String,
      country: (json['country'] ?? '') as String,
      category: json['category'] as String,
      rating: json['rating'] as String,
      crmType: (json['crm_type'] ?? 'Aucune') as String,
      grossAmount: grossAmount,
      onBalanceExposureAmount: onBalanceExposureAmount,
      offBalanceExposureAmount: offBalanceExposureAmount,
      ead: (json['ead'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      capital: (json['capital'] as num).toDouble(),
    );
  }
}

/// Point de projection utilisé dans l'échéancier des RWA.
class DashboardProjectionPoint {
  const DashboardProjectionPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  factory DashboardProjectionPoint.fromJson(Map<String, dynamic> json) {
    return DashboardProjectionPoint(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Agrège toutes les données nécessaires au dashboard.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.metrics,
    required this.valuationDate,
    required this.categoryDistribution,
    required this.rwaCategoryDistribution,
    required this.countryDistribution,
    required this.crmDistribution,
    required this.ratingDistribution,
    required this.rwaProjection,
    required this.portfolioOverview,
  });

  final List<DashboardMetric> metrics;
  final DateTime valuationDate;
  final List<DistributionEntry> categoryDistribution;
  final List<DistributionEntry> rwaCategoryDistribution;
  final List<DistributionEntry> countryDistribution;
  final List<DistributionEntry> crmDistribution;
  final List<DistributionEntry> ratingDistribution;
  final List<DashboardProjectionPoint> rwaProjection;
  final List<PortfolioRow> portfolioOverview;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      metrics: (json['metrics'] as List<dynamic>)
          .map((item) => DashboardMetric.fromJson(item as Map<String, dynamic>))
          .toList(),
      valuationDate: json['valuation_date'] == null
          ? DateTime.now()
          : DateTime.parse(json['valuation_date'] as String),
      categoryDistribution: (json['category_distribution'] as List<dynamic>)
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      rwaCategoryDistribution: (json['rwa_category_distribution']
                  as List<dynamic>? ??
              json['category_distribution'] as List<dynamic>? ??
              const [])
          .map(
            (item) => DistributionEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      countryDistribution:
          (json['country_distribution'] as List<dynamic>? ?? const [])
              .map((item) =>
                  DistributionEntry.fromJson(item as Map<String, dynamic>))
              .toList(),
      crmDistribution: (json['crm_distribution'] as List<dynamic>? ?? const [])
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      ratingDistribution: (json['rating_distribution'] as List<dynamic>)
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      rwaProjection: (json['rwa_projection'] as List<dynamic>? ?? const [])
          .map((item) =>
              DashboardProjectionPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      portfolioOverview: (json['portfolio_overview'] as List<dynamic>)
          .map((item) => PortfolioRow.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
