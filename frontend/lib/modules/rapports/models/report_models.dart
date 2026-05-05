// Ce fichier decrit les donnees du module rapports.
/// Ligne détaillée d'un rapport exportable.
class ReportLine {
  const ReportLine({
    required this.source,
    required this.itemId,
    required this.counterparty,
    required this.amount,
    required this.ead,
    required this.rwa,
    required this.capital,
  });

  final String source;
  final String itemId;
  final String counterparty;
  final double amount;
  final double ead;
  final double rwa;
  final double capital;

  factory ReportLine.fromJson(Map<String, dynamic> json) {
    return ReportLine(
      source: json['source'] as String,
      itemId: json['item_id'] as String,
      counterparty: json['counterparty'] as String,
      amount: (json['amount'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      capital: (json['capital'] as num).toDouble(),
    );
  }
}

/// Représente un rapport généré et stocké.
class ReportRecord {
  const ReportRecord({
    required this.id,
    required this.createdAt,
    required this.period,
    required this.reportType,
    required this.currency,
    required this.exposureScope,
    required this.includeCategoryChart,
    required this.includeRatingChart,
    required this.exports,
    required this.lines,
  });

  final String id;
  final DateTime createdAt;
  final String period;
  final String reportType;
  final String currency;
  final String exposureScope;
  final bool includeCategoryChart;
  final bool includeRatingChart;
  final Map<String, String> exports;
  final List<ReportLine> lines;

  factory ReportRecord.fromJson(Map<String, dynamic> json) {
    return ReportRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      period: json['period'] as String,
      reportType: json['report_type'] as String,
      currency: json['currency'] as String,
      exposureScope: json['exposure_scope'] as String,
      includeCategoryChart: json['include_category_chart'] as bool,
      includeRatingChart: json['include_rating_chart'] as bool,
      exports: (json['exports'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((item) => ReportLine.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Données complètes de l'écran rapports.
class ReportsModuleData {
  const ReportsModuleData({
    required this.reports,
  });

  final List<ReportRecord> reports;
}

/// Paramètres saisis avant génération d'un rapport.
class ReportDraft {
  const ReportDraft({
    required this.period,
    required this.reportType,
    required this.currency,
    required this.exposureScope,
    required this.includeCategoryChart,
    required this.includeRatingChart,
  });

  final String period;
  final String reportType;
  final String currency;
  final String exposureScope;
  final bool includeCategoryChart;
  final bool includeRatingChart;

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'report_type': reportType,
      'currency': currency,
      'exposure_scope': exposureScope,
      'include_category_chart': includeCategoryChart,
      'include_rating_chart': includeRatingChart,
    };
  }
}
