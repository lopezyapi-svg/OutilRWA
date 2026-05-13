// Ce fichier assemble le dashboard RWA a partir de composants modulaires.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/dashboard_models.dart';
import '../widgets/dashboard_charts_section.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_kpi_strip.dart';
import '../widgets/dashboard_maturity_panel.dart';
import '../widgets/dashboard_theme.dart';

/// Ecran principal de pilotage des RWA et du capital.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Etat interne qui charge et rafraîchit les données du dashboard.
class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardSnapshot> _future;
  StreamSubscription<int>? _portfolioRefreshSubscription;
  DateTime _selectedDate = DateTime.now();
  DashboardMaturityView _maturityView = DashboardMaturityView.monthly;

  @override
  void initState() {
    super.initState();
    _future = _loadDashboard();
    _portfolioRefreshSubscription =
        widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _future = _loadDashboard();
      });
    });
  }

  @override
  void dispose() {
    _portfolioRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<DashboardSnapshot> _loadDashboard() {
    return widget.api.fetchDashboard();
  }

  Future<void> _pickReferenceDate() async {
    // Ce sélecteur permet de tester une autre date d'observation dans l'en-tête.
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: context.tr('Choisir une date de reférence'),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        // Les états de chargement et d'erreur restent volontairement très simples.
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              context.tr('Erreur: {{error}}', args: {'error': snapshot.error}),
            ),
          );
        }

        final data = snapshot.data!;
        final displayCurrency = PortfolioCurrencyScope.of(context);
        // Cette table permet de retrouver chaque métrique par clé métier.
        final metrics = {
          for (final metric in data.metrics) metric.key: metric,
        };

        // On récupère les métriques attendues par les cartes du bandeau supérieur.
        final grossMetric = _metric(metrics, 'encours');
        final rwaMetric = _metric(metrics, 'rwa');
        final capitalMetric = _metric(metrics, 'capital');
        final riskMetric = _metric(metrics, 'taux_risque');
        final solvencyMetric = _metric(metrics, 'solvabilite');
        final crmMetric = _metric(metrics, 'crm');
        final densityRwa = _densityRwaPercent(
          rwaMetric.value,
          grossMetric.value,
        );
        final densityKpi = DashboardKpiItem(
          label: 'Densité RWA',
          value: '${densityRwa.toStringAsFixed(1)}%',
          delta: '',
          icon: Icons.query_stats_rounded,
          gradient: _densityRwaGradient(densityRwa),
          helper: 'RWA total / Exposition totale brute',
          valueHint: _densityRwaHint(densityRwa),
        );

        final kpis = [
          DashboardKpiItem(
            label: 'Exposition totale brute',
            value: _dashboardKpiCurrencyValue(
              grossMetric.value,
              displayCurrency,
            ),
            fullValue: formatCurrencyForDisplay(
              grossMetric.value,
              toCurrency: displayCurrency,
            ),
            delta: grossMetric.variation,
            icon: Icons.account_balance_wallet_outlined,
            gradient: const [Color(0xFF5E8EFF), Color(0xFF356FFF)],
            helper: 'Exposition brute',
          ),
          DashboardKpiItem(
            label: 'RWA total',
            value: _dashboardKpiCurrencyValue(
              rwaMetric.value,
              displayCurrency,
            ),
            fullValue: formatCurrencyForDisplay(
              rwaMetric.value,
              toCurrency: displayCurrency,
            ),
            delta: rwaMetric.variation,
            icon: Icons.shield_outlined,
            gradient: const [Color(0xFF37C87C), Color(0xFF20A25B)],
            helper: 'Actifs pondérés aux risques',
          ),
          DashboardKpiItem(
            label: 'Capital minimum requis',
            value: _dashboardKpiCurrencyValue(
              capitalMetric.value,
              displayCurrency,
            ),
            fullValue: formatCurrencyForDisplay(
              capitalMetric.value,
              toCurrency: displayCurrency,
            ),
            delta: capitalMetric.variation,
            icon: Icons.account_balance_outlined,
            gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            helper: 'Exigence a 8%',
          ),
          DashboardKpiItem(
            label: 'Ratio de solvabilite',
            value: dashboardCompactPercent(solvencyMetric.value),
            delta: solvencyMetric.variation,
            icon: Icons.analytics_outlined,
            gradient: const [Color(0xFF22B8CF), Color(0xFF0F9FB8)],
            helper: 'Fonds propres / RWA',
          ),
        ];

        // Les graphiques reprennent désormais uniquement les catégories réellement présentes dans les données chargées.
        final categoryEntries = data.categoryDistribution
            .where((entry) => entry.amount > 0)
            .toList();
        final rwaCategoryEntries = data.rwaCategoryDistribution
            .where((entry) => entry.amount > 0)
            .toList();
        final crmEntries = _completeCrmDistribution(data.crmDistribution);
        final countryEntries = data.countryDistribution.take(5).toList();
        // La maturité est recalculée selon la vue choisie par l'utilisateur.
        final maturityPoints = _buildProjectionEntries(
          data.rwaProjection,
          _maturityView,
          data.valuationDate,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // L'en-tête rassemble les dates de référence et l'action d'export.
              DashboardHeader(
                selectedDate: _selectedDate,
                valuationDate: data.valuationDate,
                onPickDate: () {
                  _pickReferenceDate();
                },
              ),
              const SizedBox(height: 8),
              // Le bandeau KPI résume immédiatement les agrégats clés du portefeuille.
              DashboardKpiStrip(
                items: kpis,
                trailingCard: DashboardCreditGaugeCard(
                  averageRiskWeight: riskMetric.value,
                  compact: true,
                ),
              ),
              const SizedBox(height: 8),
              // La zone centrale combine les vues de structure, concentration et mitigation.
              DashboardChartsSection(
                displayCurrency: displayCurrency,
                grossCategoryEntries: categoryEntries,
                rwaCategoryEntries: rwaCategoryEntries,
                countryEntries: countryEntries,
                crmEntries: crmEntries,
                maturityPoints: maturityPoints,
                maturityView: _maturityView,
                onMaturityViewChanged: (view) =>
                    setState(() => _maturityView = view),
                coveredRatio: crmMetric.value,
                densityItem: densityKpi,
              ),
            ],
          ),
        );
      },
    );
  }
}

DashboardMetric _metric(Map<String, DashboardMetric> metrics, String key) {
  return metrics[key] ??
      DashboardMetric(
        key: key,
        label: key,
        value: 0,
        variation: '+0.0%',
        trend: const [0, 0, 0, 0],
      );
}

String _dashboardKpiCurrencyValue(double value, String displayCurrency) {
  return compactCurrencyForDisplay(
    value,
    toCurrency: displayCurrency,
  );
}

double _densityRwaPercent(double rwaTotal, double grossExposure) {
  if (grossExposure <= 0) {
    return 0.0;
  }
  return ((rwaTotal / grossExposure) * 100).clamp(0.0, 999.0).toDouble();
}

List<Color> _densityRwaGradient(double densityPercent) {
  if (densityPercent >= 70) {
    return const [Color(0xFFFF6B6B), Color(0xFFFF4766)];
  }
  if (densityPercent >= 40) {
    return const [Color(0xFFFFAA2A), Color(0xFFFF7A21)];
  }
  return const [Color(0xFF39C97A), Color(0xFF22A863)];
}

String _densityRwaHint(double densityPercent) {
  if (densityPercent >= 70) {
    return 'Risque élevé (densité)';
  }
  if (densityPercent >= 40) {
    return 'Risque moyen (densité)';
  }
  return 'Risque faible (densité)';
}

List<DistributionEntry> _completeCrmDistribution(
    List<DistributionEntry> entries) {
  const labels = ['CRM financee', 'CRM non financee', 'Aucune'];
  final normalizedEntries = entries
      .map(
        (entry) => DistributionEntry(
          label: _normalizeDashboardCrmLabel(entry.label),
          amount: entry.amount,
          percentage: entry.percentage,
        ),
      )
      .toList();

  final completed = labels
      .map(
        // On garantit la présence des trois segments du donut CRM.
        (label) => normalizedEntries.firstWhere(
          (entry) => entry.label == label,
          orElse: () =>
              DistributionEntry(label: label, amount: 0, percentage: 0),
        ),
      )
      .toList();

  final positiveSum = completed.fold<double>(
    0,
    (sum, entry) => sum + (entry.percentage > 0 ? entry.percentage : 0),
  );

  if (positiveSum <= 0) {
    return completed;
  }

  return completed
      .map(
        (entry) => DistributionEntry(
          label: entry.label,
          amount: entry.amount,
          percentage: entry.percentage / positiveSum,
        ),
      )
      .toList();
}

String _normalizeDashboardCrmLabel(String raw) {
  final normalized =
      raw.trim().toLowerCase().replaceAll('é', 'e').replaceAll('è', 'e');
  if (normalized.contains('non') && normalized.contains('finance')) {
    return 'CRM non financee';
  }
  if (normalized.contains('finance')) {
    return 'CRM financee';
  }
  if (normalized == 'aucune' || normalized.contains('sans crm')) {
    return 'Aucune';
  }
  return raw;
}

List<DashboardProjectionPoint> _buildProjectionEntries(
  List<DashboardProjectionPoint> raw,
  DashboardMaturityView view,
  DateTime valuationDate,
) {
  if (raw.isEmpty) {
    return [];
  }

  switch (view) {
    case DashboardMaturityView.monthly:
      // La vue mensuelle reprend directement les 12 prochains points.
      return raw.take(12).toList();
    case DashboardMaturityView.quarterly:
      final quarterPoints = <DashboardProjectionPoint>[];

      for (var index = 0; index < raw.length; index += 3) {
        // Chaque trimestre agrège un bloc de trois mois pour lisser la lecture.
        final bucket = raw.skip(index).take(3).toList();
        if (bucket.isEmpty) {
          continue;
        }

        final amount =
            bucket.map((item) => item.value).reduce((a, b) => a + b) /
                bucket.length;
        quarterPoints.add(
          DashboardProjectionPoint(
            label: 'Q${(index ~/ 3) + 1}',
            value: amount,
          ),
        );
      }

      return quarterPoints;
    case DashboardMaturityView.yearly:
      // La vue annuelle synthétise la tendance en trois points simples.
      final average =
          raw.map((item) => item.value).reduce((a, b) => a + b) / raw.length;
      return [
        DashboardProjectionPoint(
          label: '${valuationDate.year}',
          value: average,
        ),
        DashboardProjectionPoint(
          label: '${valuationDate.year + 1}',
          value: average * 0.88,
        ),
        DashboardProjectionPoint(
          label: '${valuationDate.year + 2}',
          value: average * 0.74,
        ),
      ];
  }
}
