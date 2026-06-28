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

class FondsPropresDetail {
  const FondsPropresDetail({
    required this.capitalOrdinaire,
    required this.reserves,
    required this.resultatsReport,
    required this.resultatEligible,
    required this.deductionsPrudCet1,
    required this.cet1,
    required this.instrumentsAt1,
    required this.primesEmissionAt1,
    required this.deductionsPrudAt1,
    required this.at1,
    required this.tier1,
    required this.dettesSubordonneesT2,
    required this.provisionsGeneralesT2,
    required this.deductionsPrudT2,
    required this.tier2,
    required this.totalFp,
  });

  final double capitalOrdinaire;
  final double reserves;
  final double resultatsReport;
  final double resultatEligible;
  final double deductionsPrudCet1;
  final double cet1;
  final double instrumentsAt1;
  final double primesEmissionAt1;
  final double deductionsPrudAt1;
  final double at1;
  final double tier1;
  final double dettesSubordonneesT2;
  final double provisionsGeneralesT2;
  final double deductionsPrudT2;
  final double tier2;
  final double totalFp;

  factory FondsPropresDetail.fromJson(Map<String, dynamic> json) {
    return FondsPropresDetail(
      capitalOrdinaire: (json['capital_ordinaire'] as num?)?.toDouble() ?? 0.0,
      reserves: (json['reserves'] as num?)?.toDouble() ?? 0.0,
      resultatsReport: (json['resultats_report'] as num?)?.toDouble() ?? 0.0,
      resultatEligible: (json['resultat_eligible'] as num?)?.toDouble() ?? 0.0,
      deductionsPrudCet1: (json['deductions_prud_cet1'] as num?)?.toDouble() ?? 0.0,
      cet1: (json['cet1'] as num?)?.toDouble() ?? 0.0,
      instrumentsAt1: (json['instruments_at1'] as num?)?.toDouble() ?? 0.0,
      primesEmissionAt1: (json['primes_emission_at1'] as num?)?.toDouble() ?? 0.0,
      deductionsPrudAt1: (json['deductions_prud_at1'] as num?)?.toDouble() ?? 0.0,
      at1: (json['at1'] as num?)?.toDouble() ?? 0.0,
      tier1: (json['tier1'] as num?)?.toDouble() ?? 0.0,
      dettesSubordonneesT2: (json['dettes_subordonnees_t2'] as num?)?.toDouble() ?? 0.0,
      provisionsGeneralesT2: (json['provisions_generales_t2'] as num?)?.toDouble() ?? 0.0,
      deductionsPrudT2: (json['deductions_prud_t2'] as num?)?.toDouble() ?? 0.0,
      tier2: (json['tier2'] as num?)?.toDouble() ?? 0.0,
      totalFp: (json['total_fp'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FondsPropresUpdate {
  const FondsPropresUpdate({
    required this.capitalOrdinaire,
    required this.reserves,
    required this.resultatsReport,
    required this.resultatEligible,
    required this.deductionsPrudCet1,
    required this.instrumentsAt1,
    required this.primesEmissionAt1,
    required this.deductionsPrudAt1,
    required this.dettesSubordonneesT2,
    required this.provisionsGeneralesT2,
    required this.deductionsPrudT2,
  });

  final double capitalOrdinaire;
  final double reserves;
  final double resultatsReport;
  final double resultatEligible;
  final double deductionsPrudCet1;
  final double instrumentsAt1;
  final double primesEmissionAt1;
  final double deductionsPrudAt1;
  final double dettesSubordonneesT2;
  final double provisionsGeneralesT2;
  final double deductionsPrudT2;

  Map<String, dynamic> toJson() {
    return {
      'capital_ordinaire': capitalOrdinaire,
      'reserves': reserves,
      'resultats_report': resultatsReport,
      'resultat_eligible': resultatEligible,
      'deductions_prud_cet1': deductionsPrudCet1,
      'instruments_at1': instrumentsAt1,
      'primes_emission_at1': primesEmissionAt1,
      'deductions_prud_at1': deductionsPrudAt1,
      'dettes_subordonnees_t2': dettesSubordonneesT2,
      'provisions_generales_t2': provisionsGeneralesT2,
      'deductions_prud_t2': deductionsPrudT2,
    };
  }
}

/// Modèle pour une ligne du Top 10 des grands risques (expositions).
class TopExposure {
  const TopExposure({
    required this.counterparty,
    required this.sector,
    required this.country,
    required this.rating,
    required this.exposureAmount,
    required this.netExposure,
    required this.rwaAmount,
    required this.fpRatio,
    required this.status,
  });

  final String counterparty;
  final String sector;
  final String country;
  final String rating;
  final double exposureAmount;
  final double netExposure;
  final double rwaAmount;
  final double fpRatio;
  final String status;

  factory TopExposure.fromJson(Map<String, dynamic> json) {
    return TopExposure(
      counterparty: json['counterparty'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      country: json['country'] as String? ?? 'Non spécifié',
      rating: json['rating'] as String? ?? '',
      exposureAmount: (json['exposure_amount'] as num?)?.toDouble() ?? 0.0,
      netExposure: (json['net_exposure'] as num?)?.toDouble() ?? 0.0,
      rwaAmount: (json['rwa_amount'] as num?)?.toDouble() ?? 0.0,
      fpRatio: (json['fp_ratio'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Conforme',
    );
  }
}

/// Agrège toutes les données nécessaires au dashboard.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.metrics,
    this.fondsPropres,
    required this.valuationDate,
    required this.categoryDistribution,
    required this.rwaTypeDistribution,
    required this.rwaCategoryDistribution,
    required this.countryDistribution,
    required this.crmDistribution,
    required this.ratingDistribution,
    required this.rwaProjection,
    required this.portfolioOverview,
    this.top10Exposures = const [],
    this.grandsRisques = const [],
  });

  final List<DashboardMetric> metrics;
  final FondsPropresDetail? fondsPropres;
  final DateTime valuationDate;
  final List<DistributionEntry> categoryDistribution;
  final List<DistributionEntry> rwaTypeDistribution;
  final List<DistributionEntry> rwaCategoryDistribution;
  final List<DistributionEntry> countryDistribution;
  final List<DistributionEntry> crmDistribution;
  final List<DistributionEntry> ratingDistribution;
  final List<DashboardProjectionPoint> rwaProjection;
  final List<PortfolioRow> portfolioOverview;
  final List<TopExposure>? top10Exposures;
  final List<TopExposure> grandsRisques;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      metrics: (json['metrics'] as List<dynamic>)
          .map((item) => DashboardMetric.fromJson(item as Map<String, dynamic>))
          .toList(),
      fondsPropres: json['fonds_propres'] != null 
          ? FondsPropresDetail.fromJson(json['fonds_propres'] as Map<String, dynamic>)
          : null,
      valuationDate: json['valuation_date'] == null
          ? DateTime.now()
          : DateTime.parse(json['valuation_date'] as String),
      categoryDistribution: (json['category_distribution'] as List<dynamic>)
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      rwaTypeDistribution: (json['rwa_type_distribution'] as List<dynamic>? ?? const [])
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
      top10Exposures: json['top10_exposures'] != null
          ? (json['top10_exposures'] as List<dynamic>)
              .map((item) => TopExposure.fromJson(item as Map<String, dynamic>))
              .toList()
          : <TopExposure>[],
      grandsRisques: json['grands_risques'] != null
          ? (json['grands_risques'] as List<dynamic>)
              .map((item) => TopExposure.fromJson(item as Map<String, dynamic>))
              .toList()
          : <TopExposure>[],
    );
  }
}
