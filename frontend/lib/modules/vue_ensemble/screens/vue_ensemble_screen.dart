import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../expositions/models/exposition_models.dart';

const double _radius = 3;

bool _isDashboardDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _dashboardBackgroundFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF081224) : AppTheme.background;

Color _dashboardSurfaceFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF0F1B31) : Theme.of(context).cardColor;

Color _dashboardSurfaceSoftFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF14233D) : AppColors.surfaceLight;

Color _dashboardBorderFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF263856) : AppTheme.border;

Color _dashboardTextFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFFF2F6FF) : AppTheme.text;

Color _dashboardTitleFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFFE4EEFF) : AppColors.sidebar;

Color _dashboardMutedFor(BuildContext context) => _isDashboardDark(context)
    ? const Color(0xFFB2C0D9)
    : AppTheme.muted;

List<BoxShadow> _commandCardElevation(BuildContext context, Color accent) {
  final isDark = _isDashboardDark(context);
  return [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.22)
          : const Color(0xFF234A84).withValues(alpha: 0.075),
      blurRadius: 18,
      offset: const Offset(0, 9),
    ),
    BoxShadow(
      color: accent.withValues(alpha: isDark ? 0.08 : 0.055),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
}

class VueEnsembleScreen extends StatefulWidget {
  const VueEnsembleScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<VueEnsembleScreen> createState() => _VueEnsembleScreenState();
}

class _VueEnsembleScreenState extends State<VueEnsembleScreen> {
  late Future<DashboardSnapshot> _future;
  late DateTime _analysisDate;
  StreamSubscription<int>? _portfolioRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _analysisDate = DateUtils.dateOnly(DateTime.now());
    _future = _loadDashboard();
    _portfolioRefreshSubscription =
        widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _future = _loadDashboard());
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

  Future<void> _pickAnalysisDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _analysisDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: context.tr("Choisir la date d'analyse"),
    );

    if (picked == null) {
      return;
    }

    setState(() => _analysisDate = DateUtils.dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: _dashboardBackgroundFor(context),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: _dashboardBackgroundFor(context),
            child: Center(
              child: Text(
                context.tr(
                  'Erreur: {{error}}',
                  args: {'error': snapshot.error},
                ),
                style: TextStyle(color: _dashboardTextFor(context)),
              ),
            ),
          );
        }

        return _ExecutiveDashboard(
          data: snapshot.data!,
          analysisDate: _analysisDate,
          onPickAnalysisDate: _pickAnalysisDate,
        );
      },
    );
  }
}

class _ExecutiveDashboard extends StatelessWidget {
  const _ExecutiveDashboard({
    required this.data,
    required this.analysisDate,
    required this.onPickAnalysisDate,
  });

  final DashboardSnapshot data;
  final DateTime analysisDate;
  final VoidCallback onPickAnalysisDate;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.of(context);
    final metrics = {for (final metric in data.metrics) metric.key: metric};
    final exposureMetric = _metric(metrics, 'encours');
    final rwaMetric = _metric(metrics, 'rwa');
    final capitalMetric = _metric(metrics, 'capital');
    final defaultMetric = _metric(metrics, 'taux_defaut');
    final solvencyMetric = _metric(metrics, 'solvabilite');
    final valueAtRiskMetric = _metric(metrics, 'value_at_risk');
    final criticalIncidentsMetric = _metric(metrics, 'incidents_critiques');
    final concentrationMaxMetric = _metric(metrics, 'concentration_max');
    final portfolioTotals =
        _PortfolioKpiTotals.fromRows(data.portfolioOverview);
    final exposureValue = portfolioTotals.grossAmount > 0
        ? portfolioTotals.grossAmount
        : exposureMetric.value;
    final eadTotal =
        portfolioTotals.ead > 0 ? portfolioTotals.ead : exposureValue;
    final rwaValue =
        portfolioTotals.rwa > 0 ? portfolioTotals.rwa : rwaMetric.value;
    final capitalValue = portfolioTotals.capital > 0
        ? portfolioTotals.capital
        : capitalMetric.value;
    final solvencyRatio =
        rwaValue == 0 ? solvencyMetric.value : (capitalValue * 1.35) / rwaValue;
    final availableCapital = capitalValue * 1.35;
    final tier1Ratio = rwaValue == 0 ? 0.0 : capitalValue / rwaValue;
    final leverageRatio = eadTotal == 0 ? 0.0 : availableCapital / eadTotal;
    final rwaDensity = eadTotal == 0 ? 0.0 : rwaValue / eadTotal;
    final categorizedOffBalanceExposure = data.portfolioOverview
        .where(
          (item) =>
              item.category.toLowerCase().contains('hors bilan') ||
              item.id.toUpperCase().startsWith('HB'),
        )
        .fold<double>(0, (sum, item) => sum + item.grossAmount);
    final offBalanceExposure = portfolioTotals.offBalanceExposureAmount > 0
        ? portfolioTotals.offBalanceExposureAmount
        : categorizedOffBalanceExposure;
    final onBalanceExposure = portfolioTotals.onBalanceExposureAmount > 0
        ? portfolioTotals.onBalanceExposureAmount
        : math.max(0.0, exposureValue - offBalanceExposure);
    final computedGlobalVar = _valueAtRiskFromPortfolio(
      rows: data.portfolioOverview,
      rwaTrend: rwaMetric.trend,
      totalRwa: rwaValue,
      totalExposure: exposureValue,
    );
    final globalVar = valueAtRiskMetric.value > 0
        ? valueAtRiskMetric.value
        : computedGlobalVar;
    final computedCriticalIncidents = _criticalIncidentsFromPortfolio(
      rows: data.portfolioOverview,
      nplRatio: defaultMetric.value,
      totalRwa: rwaValue,
      totalExposure: exposureValue,
    );
    final criticalIncidents = criticalIncidentsMetric.value > 0
        ? criticalIncidentsMetric.value.round()
        : computedCriticalIncidents;
    final sortedRows = [...data.portfolioOverview]
      ..sort((a, b) => b.grossAmount.compareTo(a.grossAmount));
    final topExposure = sortedRows.isEmpty ? null : sortedRows.first;
    final computedTopExposureShare = topExposure == null || exposureValue == 0
        ? 0.0
        : topExposure.grossAmount / exposureValue;
    final topExposureShare = concentrationMaxMetric.value > 0
        ? concentrationMaxMetric.value
        : computedTopExposureShare;
    final topExposureLabel =
        topExposure == null || topExposure.counterparty.trim().isEmpty
            ? 'Première contrepartie'
            : topExposure.counterparty.trim();
    final mainKpis = [
      _KpiSpec(
        label: 'RWA total',
        value: _money(rwaValue, displayCurrency),
        detail: 'Risk Weighted Assets',
        icon: CupertinoIcons.shield_lefthalf_fill,
        color: AppColors.accent,
        trend: rwaMetric.trend,
      ),
      _KpiSpec(
        label: 'Exposition totale',
        value: _money(exposureValue, displayCurrency),
        detail: 'Montant brut consolidé',
        icon: CupertinoIcons.sum,
        color: AppColors.marketNeutral,
        trend: exposureMetric.trend,
      ),
      _KpiSpec(
        label: 'Capital minimum requis',
        value: _money(capitalValue, displayCurrency),
        detail: 'Minimum Required Capital',
        icon: CupertinoIcons.money_dollar_circle_fill,
        color: AppColors.warning,
        trend: capitalMetric.trend,
      ),
      _KpiSpec(
        label: 'Ratio NPL',
        value: AppFormatters.percent(defaultMetric.value),
        detail: 'Non Performing Loans',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: AppColors.warning,
        trend: defaultMetric.trend,
      ),
      _KpiSpec(
        label: 'VaR globale',
        value: _money(globalVar, displayCurrency),
        detail: 'Value at Risk',
        icon: CupertinoIcons.waveform_circle_fill,
        color: AppColors.accent,
        trend: valueAtRiskMetric.trend,
      ),
      _KpiSpec(
        label: 'Incidents critiques',
        value: '$criticalIncidents',
        detail: 'Operational Risk',
        icon: CupertinoIcons.exclamationmark_octagon_fill,
        color: AppColors.danger,
        trend: criticalIncidentsMetric.trend,
      ),
      _KpiSpec(
        label: 'Concentration max',
        value: AppFormatters.percent(topExposureShare),
        detail: topExposureLabel,
        icon: CupertinoIcons.person_2_fill,
        color: AppColors.prudentialSolvency,
        trend: concentrationMaxMetric.trend,
      ),
    ];

    final counterpartyTotals = <String, double>{};
    for (final row in data.portfolioOverview) {
      final label =
          row.counterparty.trim().isEmpty ? row.id : row.counterparty.trim();
      counterpartyTotals.update(
        label,
        (value) => value + row.grossAmount,
        ifAbsent: () => row.grossAmount,
      );
    }
    final rankedCounterparties = counterpartyTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFiveExposure = rankedCounterparties
        .take(5)
        .fold<double>(0, (sum, entry) => sum + entry.value);
    final topFiveShare =
        exposureValue == 0 ? 0.0 : topFiveExposure / exposureValue;
    final countryCount = data.portfolioOverview
        .map((row) => row.country.trim())
        .where((country) => country.isNotEmpty)
        .toSet()
        .length;
    final ratingTotals = <String, double>{};
    for (final row in data.portfolioOverview) {
      final rating = _portfolioDisplayRating(row.rating);
      ratingTotals.update(
        rating,
        (value) => value + row.grossAmount,
        ifAbsent: () => row.grossAmount,
      );
    }
    final rankedRatings = ratingTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominantRating =
        rankedRatings.isEmpty ? 'N/D' : rankedRatings.first.key;
    final dominantRatingExposure =
        rankedRatings.isEmpty ? 0.0 : rankedRatings.first.value;
    final dominantRatingShare =
        exposureValue == 0 ? 0.0 : dominantRatingExposure / exposureValue;
    final crmExposure = data.portfolioOverview.where((row) {
      final crm = row.crmType.trim().toLowerCase();
      return crm.isNotEmpty && crm != 'aucune' && crm != 'none';
    }).fold<double>(0, (sum, row) => sum + row.grossAmount);
    final crmShare = exposureValue == 0 ? 0.0 : crmExposure / exposureValue;

    final secondaryKpis = [
      _FactSpec(
        label: 'Contreparties suivies',
        value: '${counterpartyTotals.length}',
        color: AppColors.accent,
        explanation:
            'Compte le nombre de contreparties distinctes réellement présentes dans le portefeuille importé.',
        analysis:
            '${counterpartyTotals.length} contrepartie(s) sont suivies dans cette vue. Ce volume donne une première lecture de la granularité du portefeuille.',
        impact:
            'Plus le nombre de contreparties est faible, plus la surveillance single-name doit être stricte.',
      ),
      _FactSpec(
        label: 'Pays couverts',
        value: '$countryCount',
        color: AppColors.marketNeutral,
        explanation:
            'Mesure l\'étendue géographique du portefeuille à partir des pays renseignés sur les expositions importées.',
        analysis:
            '$countryCount pays distinct(s) sont représentés. Cette lecture complète l\'analyse de concentration géographique.',
        impact:
            'Une base pays trop concentrée rend le portefeuille plus sensible aux chocs souverains ou régionaux.',
      ),
      _FactSpec(
        label: 'Notation dominante',
        value: dominantRating,
        color: AppColors.sidebar,
        explanation:
            'Identifie la notation qui concentre le plus d\'exposition brute dans le portefeuille.',
        analysis:
            'Le bucket $dominantRating porte ${AppFormatters.percent(dominantRatingShare)} de l\'exposition totale, soit ${_money(dominantRatingExposure, displayCurrency)}.',
        impact:
            'Une notation dominante trop exposée rend le portefeuille plus sensible aux migrations de rating et aux hausses de pondération.',
      ),
      _FactSpec(
        label: 'Poids Top 5',
        value: AppFormatters.percent(topFiveShare),
        color: AppColors.prudentialSolvency,
        explanation:
            'Mesure la part de l\'exposition totale portée par les cinq premières contreparties.',
        formulaLatex:
            r'\text{Top 5}=\frac{\sum_{j=1}^{5}\text{Exposition}_{j}}{\text{Exposition totale}}',
        analysis:
            'Les cinq premières contreparties représentent ${AppFormatters.percent(topFiveShare)} de l\'exposition totale, soit ${_money(topFiveExposure, displayCurrency)}.',
        impact:
            'Plus ce poids est élevé, plus le pilotage des limites et garanties des grandes signatures devient prioritaire.',
      ),
      _FactSpec(
        label: 'Couverture CRM',
        value: AppFormatters.percent(crmShare),
        color: AppColors.success,
        explanation:
            'Indique la part de l\'exposition brute portée par des expositions disposant d\'un dispositif CRM ou d\'une garantie renseignée.',
        formulaLatex:
            r'\text{CRM}=\frac{\sum \text{Exposition avec CRM}}{\text{Exposition totale}}',
        analysis:
            '${AppFormatters.percent(crmShare)} de l\'exposition brute est associée à un CRM renseigné, soit ${_money(crmExposure, displayCurrency)}.',
        impact:
            'Une couverture CRM faible peut accroître la consommation de capital si les pondérations ou les expositions se détériorent.',
      ),
    ];
    final varShare = rwaValue == 0 ? 0.0 : globalVar / rwaValue;
    final briefColor = topExposureShare >= 0.30 || solvencyRatio < 0.08
        ? AppColors.danger
        : topExposureShare >= 0.18 || solvencyRatio < 0.12 || varShare >= 0.25
            ? AppColors.warning
            : AppColors.success;
    final executiveBrief = _ExecutiveBriefSpec(
      title: briefColor == AppColors.success
          ? 'Profil prudentiel maîtrisé : concentration, solvabilité et VaR restent dans les seuils de pilotage.'
          : briefColor == AppColors.danger
              ? 'Alerte de pilotage : concentration single-name et coussin prudentiel sous pression.'
              : 'Surveillance renforcée : concentration single-name et marge de solvabilité à piloter.',
      body:
          "La contrepartie dominante ($topExposureLabel) représente ${AppFormatters.percent(topExposureShare)} de l'exposition brute. Le ratio de solvabilité ressort à ${AppFormatters.percent(solvencyRatio)} ; la VaR absorbe ${AppFormatters.percent(varShare)} du RWA total.",
      color: AppColors.accent,
      statusColor: briefColor,
      actions: [
        _ExecutiveAction(
          label: topExposureShare >= 0.18
              ? 'Revue limite single-name'
              : 'Surveillance des limites',
          value: topExposureShare >= 0.18
              ? 'Contrôler l\'utilisation de limite, les collatéraux éligibles et l\'exposition nette sur $topExposureLabel.'
              : 'Maintenir les seuils single-name et suivre les entrées pouvant modifier la concentration.',
        ),
        _ExecutiveAction(
          label: solvencyRatio < 0.12
              ? 'Pilotage capital / RWA'
              : 'Préservation du capital',
          value: solvencyRatio < 0.12
              ? 'Mesurer l\'effet d\'un allègement RWA ou d\'un renforcement des fonds propres sur le coussin prudentiel.'
              : 'Protéger le coussin prudentiel avant toute croissance d\'engagements.',
        ),
        _ExecutiveAction(
          label: varShare >= 0.25 ? 'Stress de marché' : 'Contrôle périodique',
          value: varShare >= 0.25
              ? 'Appliquer un choc de taux et isoler les poches qui consomment le plus de VaR.'
              : 'Suivre les migrations de notation, la VaR et la trajectoire mensuelle des RWA.',
        ),
      ],
      recommendation: topExposureShare >= 0.18
          ? 'Mettre sous revue la limite single-name de $topExposureLabel, recalibrer les garanties éligibles et simuler une réduction progressive de l\'exposition nette.'
          : solvencyRatio < 0.12
              ? 'Sécuriser le coussin prudentiel : arbitrer baisse des RWA, renforcement des fonds propres et ralentissement des nouveaux engagements.'
              : 'Maintenir le dispositif de surveillance : migrations de notation, consommation de capital et trajectoire mensuelle des RWA.',
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: _dashboardBackgroundFor(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              8,
              6,
              8,
              0,
            ),
            child: _DashboardTitle(
              analysisDate: analysisDate,
              onPickAnalysisDate: onPickAnalysisDate,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                8,
                6,
                8,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CommandCenterPanel(
                    items: mainKpis,
                    solvencyRatio: solvencyRatio,
                    availableCapital: availableCapital,
                    rwaValue: rwaValue,
                    onBalanceExposure: onBalanceExposure,
                    offBalanceExposure: offBalanceExposure,
                    tier1Ratio: tier1Ratio,
                    leverageRatio: leverageRatio,
                    rwaDensity: rwaDensity,
                    displayCurrency: displayCurrency,
                  ),
                  const SizedBox(height: 6),
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RiskConcentrationPanel(
                              rows: data.portfolioOverview,
                              sectors: data.categoryDistribution,
                              countries: data.countryDistribution,
                              displayCurrency: displayCurrency,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _RwaEvolutionAnalyticsPanel(
                              rows: data.portfolioOverview,
                              displayCurrency: displayCurrency,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ExecutiveRiskBrief(brief: executiveBrief),
                  const SizedBox(height: 6),
                  _SecondaryKpiBar(items: secondaryKpis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTitle extends StatelessWidget {
  const _DashboardTitle({
    required this.analysisDate,
    required this.onPickAnalysisDate,
  });

  final DateTime analysisDate;
  final VoidCallback onPickAnalysisDate;

  @override
  Widget build(BuildContext context) {
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      borderRadius: _radius,
      elevation: 26,
      showBorder: false,
      child: Row(
        children: [
          const _IconBox(
            icon: CupertinoIcons.chart_pie_fill,
            color: AppColors.accent,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('Dashboard exécutif'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('Pilotage prudentiel RWA - Approche Standard'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(
            icon: CupertinoIcons.calendar,
            caption: 'Date d\'analyse',
            label: AppFormatters.shortDate(analysisDate),
            onTap: onPickAnalysisDate,
          ),
        ],
      ),
    );
  }
}

class _CommandCenterPanel extends StatelessWidget {
  const _CommandCenterPanel({
    required this.items,
    required this.solvencyRatio,
    required this.availableCapital,
    required this.rwaValue,
    required this.onBalanceExposure,
    required this.offBalanceExposure,
    required this.tier1Ratio,
    required this.leverageRatio,
    required this.rwaDensity,
    required this.displayCurrency,
  });

  final List<_KpiSpec> items;
  final double solvencyRatio;
  final double availableCapital;
  final double rwaValue;
  final double onBalanceExposure;
  final double offBalanceExposure;
  final double tier1Ratio;
  final double leverageRatio;
  final double rwaDensity;
  final String displayCurrency;
  static const double _desktopPanelHeight = 198;
  static const double _desktopRiskLedgerHeight = _desktopPanelHeight;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = _isDashboardDark(context);
    final surface = _dashboardSurfaceFor(context);
    final soft = _dashboardSurfaceSoftFor(context);
    final rwa = items[0];
    final exposure = items.length > 1 ? items[1] : rwa;
    final onBalance = _KpiSpec(
      label: 'Exposition au bilan',
      value: _money(onBalanceExposure, displayCurrency),
      detail: 'Engagements portés au bilan',
      icon: CupertinoIcons.building_2_fill,
      color: const Color(0xFF67E8F9),
      trend: _flatTrend(onBalanceExposure),
    );
    final offBalance = _KpiSpec(
      label: 'Exposition au hors bilan',
      value: _money(offBalanceExposure, displayCurrency),
      detail: 'Engagements hors bilan',
      icon: CupertinoIcons.rectangle_stack_badge_plus,
      color: const Color(0xFFBFDBFE),
      trend: _flatTrend(offBalanceExposure),
    );
    final npl = items.length > 3 ? items[3] : rwa;
    final valueAtRisk = items.length > 4 ? items[4] : rwa;
    final incidents = items.length > 5 ? items[5] : rwa;
    final concentration = items.length > 6 ? items[6] : rwa;

    return _Panel(
      padding: EdgeInsets.zero,
      elevation: 22,
      showBorder: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [surface, const Color(0xFF0B1730)]
                  : [surface, soft.withValues(alpha: 0.86)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1040;
              final primary = _CommandPrimaryBlock(
                rwa: rwa,
                exposure: exposure,
                onBalance: onBalance,
                offBalance: offBalance,
              );
              final compass = _CapitalCompassPanel(
                solvencyRatio: solvencyRatio,
                availableCapital: availableCapital,
                rwaValue: rwaValue,
                tier1Ratio: tier1Ratio,
                leverageRatio: leverageRatio,
                displayCurrency: displayCurrency,
              );
              final ledger = _CommandRiskLedger(
                valueAtRisk: valueAtRisk,
                npl: npl,
                incidents: incidents,
                concentration: concentration,
              );

              if (compact) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      const SizedBox(height: 10),
                      SizedBox(height: 186, child: compass),
                      const SizedBox(height: 10),
                      ledger,
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: _desktopRiskLedgerHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 318,
                        height: _desktopPanelHeight,
                        child: primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: _desktopPanelHeight,
                          child: compass,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 332,
                        height: _desktopRiskLedgerHeight,
                        child: ledger,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CommandPrimaryBlock extends StatelessWidget {
  const _CommandPrimaryBlock({
    required this.rwa,
    required this.exposure,
    required this.onBalance,
    required this.offBalance,
  });

  final _KpiSpec rwa;
  final _KpiSpec exposure;
  final _KpiSpec onBalance;
  final _KpiSpec offBalance;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Colors.white.withValues(alpha: 0.18);
    final titleColor = Colors.white.withValues(alpha: 0.94);
    final labelColor = Colors.white.withValues(alpha: 0.72);
    const valueColor = Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF173B8F),
            Color(0xFF0E2D68),
          ],
        ),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: _commandCardElevation(context, AppColors.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _IconBox(
                  icon: CupertinoIcons.shield_lefthalf_fill,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Portefeuille prudentiel'.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rwa.label.tr(context).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 9.6,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rwa.value,
                maxLines: 1,
                style: const TextStyle(
                  color: valueColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 0.96,
                ),
              ),
            ),
            const SizedBox(height: 5),
            _CommandPrimaryDivider(color: dividerColor),
            const SizedBox(height: 4),
            _CommandMeasureRow(
              item: exposure,
              labelColor: labelColor,
              valueColor: valueColor,
            ),
            const SizedBox(height: 4),
            _CommandPrimaryDivider(color: dividerColor),
            const SizedBox(height: 4),
            _CommandMeasureRow(
              item: onBalance,
              labelColor: labelColor,
              valueColor: valueColor,
            ),
            const SizedBox(height: 4),
            _CommandPrimaryDivider(color: dividerColor),
            const SizedBox(height: 4),
            _CommandMeasureRow(
              item: offBalance,
              labelColor: labelColor,
              valueColor: valueColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandPrimaryDivider extends StatelessWidget {
  const _CommandPrimaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      color: color,
    );
  }
}

class _CommandMeasureRow extends StatelessWidget {
  const _CommandMeasureRow({
    required this.item,
    this.labelColor,
    this.valueColor,
  });

  final _KpiSpec item;
  final Color? labelColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textColor = _dashboardTextFor(context);

    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            item.label.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor ?? textColor.withValues(alpha: 0.76),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 118),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              item.value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor ?? textColor,
                fontSize: 14.2,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CapitalCompassPanel extends StatelessWidget {
  const _CapitalCompassPanel({
    required this.solvencyRatio,
    required this.availableCapital,
    required this.rwaValue,
    required this.tier1Ratio,
    required this.leverageRatio,
    required this.displayCurrency,
  });

  final double solvencyRatio;
  final double availableCapital;
  final double rwaValue;
  final double tier1Ratio;
  final double leverageRatio;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final textColor = _dashboardTextFor(context);
    final titleColor = _dashboardTitleFor(context);
    final mutedColor = _dashboardMutedFor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.018)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
        boxShadow: _commandCardElevation(context, AppColors.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fillBottom =
                constraints.maxHeight.isFinite;
            final cushion = _CapitalCushionReading(
              availableCapital: availableCapital,
              rwaValue: rwaValue,
              displayCurrency: displayCurrency,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _IconBox(
                      icon: CupertinoIcons.compass_fill,
                      color: AppColors.accent,
                      size: 26,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Boussole prudentielle'.tr(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Position du capital face aux seuils.'.tr(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 10.4,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppFormatters.percent(solvencyRatio),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Ratio de solvabilité actuel'.tr(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CapitalCompassMiniStat(
                      label: 'Ratio CET1',
                      value: AppFormatters.percent(tier1Ratio),
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    _CapitalCompassMiniStat(
                      label: 'Ratio levier',
                      value: AppFormatters.percent(leverageRatio),
                      color: AppColors.prudentialSolvency,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (fillBottom) Expanded(child: cushion) else cushion,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CapitalCompassMiniStat extends StatelessWidget {
  const _CapitalCompassMiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.095),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedColor,
              fontSize: 8.8,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapitalCushionReading extends StatelessWidget {
  const _CapitalCushionReading({
    required this.availableCapital,
    required this.rwaValue,
    required this.displayCurrency,
  });

  final double availableCapital;
  final double rwaValue;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final textColor = _dashboardTextFor(context);
    const minimumRatio = 0.08;
    final minimumCapital = rwaValue * minimumRatio;
    final cushion = availableCapital - minimumCapital;
    final cushionColor = cushion >= 0 ? AppColors.accent : AppColors.danger;
    final cushionTileColor = cushion >= 0 ? AppColors.success : AppColors.danger;
    final reading = cushion >= 0
        ? 'Réserve de capital mobilisable au-dessus du minimum réglementaire.'
        : 'Coussin insuffisant face au minimum réglementaire.';
    final cushionValue =
        '${cushion >= 0 ? '+' : '-'}${_money(cushion.abs(), displayCurrency)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: cushionColor.withValues(alpha: isDark ? 0.12 : 0.075),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: cushionColor,
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  reading.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _CapitalCushionTile(
                  label: 'Capital minimum',
                  value: _money(minimumCapital, displayCurrency),
                  caption: 'seuil 8 %',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _CapitalCushionTile(
                  label: 'Coussin',
                  value: cushionValue,
                  caption: 'réserve',
                  color: cushionTileColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapitalCushionTile extends StatelessWidget {
  const _CapitalCushionTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.085),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedColor,
              fontSize: 8.2,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value.tr(context),
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandRiskLedger extends StatelessWidget {
  const _CommandRiskLedger({
    required this.valueAtRisk,
    required this.npl,
    required this.incidents,
    required this.concentration,
  });

  final _KpiSpec valueAtRisk;
  final _KpiSpec npl;
  final _KpiSpec incidents;
  final _KpiSpec concentration;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final titleColor = _dashboardTitleFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.018)
            : Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: _commandCardElevation(context, AppColors.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Risques à décider'.tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Les signaux qui orientent la surveillance immédiate.'
                  .tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mutedColor,
                fontSize: 8.4,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            _CommandRiskRow(item: valueAtRisk),
            const SizedBox(height: 2),
            _CommandRiskRow(item: npl),
            const SizedBox(height: 2),
            _CommandRiskRow(item: incidents),
            const SizedBox(height: 2),
            _CommandRiskRow(item: concentration),
          ],
        ),
      ),
    );
  }
}

class _CommandRiskRow extends StatefulWidget {
  const _CommandRiskRow({required this.item});

  final _KpiSpec item;

  @override
  State<_CommandRiskRow> createState() => _CommandRiskRowState();
}

class _CommandRiskRowState extends State<_CommandRiskRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);
    final accentColor = widget.item.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.004 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            _hovered ? 2 : 0,
            _hovered ? -1 : 0,
            0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? accentColor.withValues(alpha: _hovered ? 0.17 : 0.12)
                : accentColor.withValues(alpha: _hovered ? 0.115 : 0.075),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: accentColor.withValues(alpha: _hovered ? 0.34 : 0),
              width: 0.8,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color:
                          accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 26,
                height: 22,
                alignment: Alignment.center,
                transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: isDark
                        ? (_hovered ? 0.28 : 0.20)
                        : (_hovered ? 0.18 : 0.13),
                  ),
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Icon(widget.item.icon, color: accentColor, size: 12.5),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.label.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      widget.item.detail.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor.withValues(alpha: 0.96),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.item.value,
                    maxLines: 1,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: _hovered ? 13.6 : 13.2,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryKpiBar extends StatelessWidget {
  const _SecondaryKpiBar({required this.items});

  final List<_FactSpec> items;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);
    final borderColor = _dashboardBorderFor(context);

    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconBox(
                icon: CupertinoIcons.list_bullet_below_rectangle,
                color: AppColors.marketNeutral,
                size: 28,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registre prudentiel'.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Signaux de structure qui complètent la lecture exécutive.'
                          .tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 9.2,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: AppColors.marketNeutral.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(1),
                  border: Border.all(
                    color: AppColors.marketNeutral.withValues(alpha: isDark ? 0.46 : 0.34),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.shield_lefthalf_fill,
                      size: 11,
                      color: AppColors.marketNeutral.withValues(alpha: isDark ? 0.96 : 0.88),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Risque de crédit'.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFE8FBFF) : AppColors.marketNeutral,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minColumnWidth = 184.0;
                const dividerWidth = 1.0;
                final itemCount = math.max(items.length, 1);
                final dividerCount = math.max(items.length - 1, 0);
                final availableForCells = constraints.maxWidth.isFinite
                    ? math.max(
                        0.0,
                        constraints.maxWidth - dividerCount * dividerWidth,
                      )
                    : minColumnWidth * itemCount;
                final columnWidth = math.max(
                  minColumnWidth,
                  availableForCells / itemCount,
                );
                final rowWidth =
                    columnWidth * items.length + dividerCount * dividerWidth;
                final row = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      SizedBox(
                        width: columnWidth,
                        child: _PrudentialLedgerCell(item: items[index]),
                      ),
                      if (index != items.length - 1)
                        SizedBox(
                          height: 44,
                          child: VerticalDivider(
                            width: 1,
                            thickness: 0.8,
                            color: borderColor,
                          ),
                        ),
                    ],
                  ],
                );

                if (rowWidth <= constraints.maxWidth) {
                  return row;
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(width: rowWidth, child: row),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PrudentialLedgerCell extends StatelessWidget {
  const _PrudentialLedgerCell({required this.item});

  final _FactSpec item;

  @override
  Widget build(BuildContext context) {
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label.tr(context).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 7.6,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _FactInfoButton(item: item),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveRiskBrief extends StatelessWidget {
  const _ExecutiveRiskBrief({required this.brief});

  final _ExecutiveBriefSpec brief;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);
    final surfaceSoft = _dashboardSurfaceSoftFor(context);
    final borderColor = _dashboardBorderFor(context);
    final titleColor = _dashboardTitleFor(context);

    return _Panel(
      padding: EdgeInsets.zero,
      elevation: 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFEFEFEFE),
            border: Border(
              left: BorderSide(color: brief.statusColor, width: 3),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1040;
              final content = _ExecutiveBriefContent(
                brief: brief,
                titleColor: titleColor,
                mutedColor: mutedColor,
              );
              final priority = _ExecutivePriorityDecision(
                brief: brief,
                textColor: textColor,
                mutedColor: mutedColor,
                surfaceSoft: surfaceSoft,
                borderColor: borderColor,
                isDark: isDark,
              );
              final actions = _ExecutiveActionStrip(
                brief: brief,
                textColor: textColor,
                mutedColor: mutedColor,
                surfaceSoft: surfaceSoft,
                borderColor: borderColor,
                isDark: isDark,
              );

              if (compact) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      const SizedBox(height: 6),
                      priority,
                      const SizedBox(height: 6),
                      actions,
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: content),
                        const SizedBox(width: 8),
                        SizedBox(width: 360, child: priority),
                      ],
                    ),
                    const SizedBox(height: 6),
                    actions,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExecutiveBriefContent extends StatelessWidget {
  const _ExecutiveBriefContent({
    required this.brief,
    required this.titleColor,
    required this.mutedColor,
  });

  final _ExecutiveBriefSpec brief;
  final Color titleColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _IconBox(
              icon: CupertinoIcons.doc_text_fill,
              color: brief.color,
              size: 30,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Synthèse exécutive'.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13.4,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text.rich(
          _executiveHighlightedSpan(
            context,
            text: brief.title,
            baseStyle: TextStyle(
              color: titleColor,
              fontSize: 16.4,
              fontWeight: FontWeight.w700,
              height: 1.16,
            ),
            accent: brief.color,
            highlightColor: titleColor,
            highlightWeight: FontWeight.w900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 7),
        Text.rich(
          _executiveHighlightedSpan(
            context,
            text: brief.body,
            baseStyle: TextStyle(
              color: mutedColor,
              fontSize: 10.7,
              fontWeight: FontWeight.w600,
              height: 1.42,
            ),
            accent: brief.color,
            highlightColor: titleColor,
            highlightWeight: FontWeight.w900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ExecutivePriorityDecision extends StatelessWidget {
  const _ExecutivePriorityDecision({
    required this.brief,
    required this.textColor,
    required this.mutedColor,
    required this.surfaceSoft,
    required this.borderColor,
    required this.isDark,
  });

  final _ExecutiveBriefSpec brief;
  final Color textColor;
  final Color mutedColor;
  final Color surfaceSoft;
  final Color borderColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const bubbleColor = Color(0xFEFEFEFE);
    const bubbleAccent = Color(0xFF3730A3);

    return _HoverProgress(
      builder: (context, hover) {
        final animatedBorder = bubbleAccent.withValues(
          alpha: 0.18 + hover * 0.16,
        );
        final animatedShadow = bubbleAccent.withValues(
          alpha: (isDark ? 0.24 : 0.16) + hover * 0.10,
        );

        return Transform.translate(
          offset: Offset(hover * 1.5, 9 - hover * 3),
          child: Transform.scale(
            scale: 1 + hover * 0.008,
            alignment: Alignment.center,
            child: CustomPaint(
              painter: _ExecutiveSpeechBubblePainter(
                color: bubbleColor,
                borderColor: animatedBorder,
                shadowColor: animatedShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(29, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -hover * 1.5),
                      child: Transform.scale(
                        scale: 1 + hover * 0.045,
                        child: Container(
                          width: 31,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: bubbleAccent.withValues(
                              alpha: 0.10 + hover * 0.05,
                            ),
                            borderRadius: BorderRadius.circular(_radius * 3),
                          ),
                          child: const Icon(
                            CupertinoIcons.chat_bubble_text_fill,
                            color: bubbleAccent,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            _executiveHighlightedSpan(
                              context,
                              text: brief.recommendation,
                              baseStyle: TextStyle(
                                color: mutedColor,
                                fontSize: 9.8,
                                fontWeight: FontWeight.w600,
                                height: 1.36,
                              ),
                              accent: bubbleAccent,
                              highlightColor: textColor,
                              highlightWeight: FontWeight.w900,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExecutiveSpeechBubblePainter extends CustomPainter {
  const _ExecutiveSpeechBubblePainter({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
  });

  static const double _tailWidth = 14;
  static const double _tailHeight = 23;
  static const double _radius = 14;

  final Color color;
  final Color borderColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _bubblePath(size);
    canvas.drawShadow(path, shadowColor, 9, true);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, fill);

    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    canvas.drawPath(path, border);
  }

  Path _bubblePath(Size size) {
    const left = _tailWidth;
    final right = size.width;
    const top = 0.0;
    final bottom = size.height;
    final radius = math.min(_radius, math.min(size.height, size.width) / 2);
    final tailCenter =
        math.min(bottom - radius - 4, math.max(top + radius + 4, 35.0));
    final tailTop = tailCenter - _tailHeight / 2;
    final tailBottom = tailCenter + _tailHeight / 2;

    return Path()
      ..moveTo(left + radius, top)
      ..lineTo(right - radius, top)
      ..quadraticBezierTo(right, top, right, top + radius)
      ..lineTo(right, bottom - radius)
      ..quadraticBezierTo(right, bottom, right - radius, bottom)
      ..lineTo(left + radius, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - radius)
      ..lineTo(left, tailBottom)
      ..quadraticBezierTo(left * 0.58, tailBottom - 2, 0, tailCenter)
      ..quadraticBezierTo(left * 0.58, tailTop + 2, left, tailTop)
      ..lineTo(left, top + radius)
      ..quadraticBezierTo(left, top, left + radius, top)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _ExecutiveSpeechBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}

class _ExecutiveActionStrip extends StatelessWidget {
  const _ExecutiveActionStrip({
    required this.brief,
    required this.textColor,
    required this.mutedColor,
    required this.surfaceSoft,
    required this.borderColor,
    required this.isDark,
  });

  final _ExecutiveBriefSpec brief;
  final Color textColor;
  final Color mutedColor;
  final Color surfaceSoft;
  final Color borderColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final actions = brief.actions.take(3).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final cards = [
          for (var index = 0; index < actions.length; index++)
            _ExecutiveActionCard(
              action: actions[index],
              index: index,
              accent: brief.statusColor,
              highlightColor: textColor,
              textColor: textColor,
              mutedColor: mutedColor,
              surfaceSoft: surfaceSoft,
              borderColor: borderColor,
              isDark: isDark,
            ),
        ];

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                cards[index],
                if (index != cards.length - 1) const SizedBox(height: 7),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _ExecutiveActionCard extends StatelessWidget {
  const _ExecutiveActionCard({
    required this.action,
    required this.index,
    required this.accent,
    required this.highlightColor,
    required this.textColor,
    required this.mutedColor,
    required this.surfaceSoft,
    required this.borderColor,
    required this.isDark,
  });

  final _ExecutiveAction action;
  final int index;
  final Color accent;
  final Color highlightColor;
  final Color textColor;
  final Color mutedColor;
  final Color surfaceSoft;
  final Color borderColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _HoverProgress(
      builder: (context, hover) {
        final baseSurface =
            isDark ? surfaceSoft.withValues(alpha: 0.64) : surfaceSoft;
        final activeSurface = Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.12 : 0.045),
          baseSurface,
        );
        final activeBorder = accent.withValues(alpha: isDark ? 0.62 : 0.46);
        final valueColor = Color.lerp(
          mutedColor,
          textColor.withValues(alpha: 0.90),
          hover,
        )!;

        return Transform.translate(
          offset: Offset(0, -3 * hover),
          child: Transform.scale(
            scale: 1 + (hover * 0.006),
            alignment: Alignment.center,
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: Color.lerp(baseSurface, activeSurface, hover),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: Color.lerp(borderColor, activeBorder, hover)!,
                  width: 1 + (hover * 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: (isDark ? 0.16 : 0.11) * hover,
                    ),
                    blurRadius: 8 + (hover * 14),
                    offset: Offset(0, 4 + (hover * 5)),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.scale(
                    scale: 1 + (hover * 0.08),
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: (isDark ? 0.18 : 0.11) + (hover * 0.08),
                        ),
                        borderRadius: BorderRadius.circular(_radius),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.18 + hover * 0.18),
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          _executiveHighlightedSpan(
                            context,
                            text: action.label,
                            baseStyle: TextStyle(
                              color: textColor,
                              fontSize: 9.3,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                            accent: accent,
                            highlightColor: highlightColor,
                            highlightWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          _executiveHighlightedSpan(
                            context,
                            text: action.value,
                            baseStyle: TextStyle(
                              color: valueColor,
                              fontSize: 8.7,
                              fontWeight: FontWeight.w600,
                              height: 1.24,
                            ),
                            accent: accent,
                            highlightColor: highlightColor,
                            highlightWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExecutiveBriefSpec {
  const _ExecutiveBriefSpec({
    required this.title,
    required this.body,
    required this.color,
    required this.statusColor,
    required this.actions,
    required this.recommendation,
  });

  final String title;
  final String body;
  final Color color;
  final Color statusColor;
  final List<_ExecutiveAction> actions;
  final String recommendation;
}

class _ExecutiveAction {
  const _ExecutiveAction({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _ExecutiveHighlightRange {
  const _ExecutiveHighlightRange(this.start, this.end);

  final int start;
  final int end;
}

TextSpan _executiveHighlightedSpan(
  BuildContext context, {
  required String text,
  required TextStyle baseStyle,
  required Color accent,
  Color? highlightColor,
  FontWeight highlightWeight = FontWeight.w800,
}) {
  final value = text.tr(context);
  final ranges = <_ExecutiveHighlightRange>[];

  void addPattern(RegExp pattern) {
    for (final match in pattern.allMatches(value)) {
      final overlaps = ranges.any(
        (range) => match.start < range.end && match.end > range.start,
      );
      if (!overlaps) {
        ranges.add(_ExecutiveHighlightRange(match.start, match.end));
      }
    }
  }

  final terms = [
    'concentration single-name',
    'limite single-name',
    'contrepartie dominante',
    'ratio de solvabilité',
    'marge de solvabilité',
    'coussin prudentiel',
    'seuils de pilotage',
    'exposition brute',
    'exposition nette',
    'collatéraux éligibles',
    'garanties éligibles',
    'fonds propres',
    'allègement RWA',
    'stress de marché',
    'choc de taux',
    'migrations de notation',
    'consommation de capital',
    'trajectoire mensuelle',
    'nouveaux engagements',
    'single-name',
    'solvabilité',
    'concentration',
    'capital',
    'VaR',
    'RWA',
  ]..sort((left, right) => right.length.compareTo(left.length));

  for (final term in terms) {
    addPattern(
      RegExp(RegExp.escape(term), caseSensitive: false, unicode: true),
    );
  }
  addPattern(
    RegExp(
      r'\b\d{1,3}(?:[ \u00A0\u202F]\d{3})*(?:,\d+)?[\s\u00A0\u202F]?(?:%|Md FCFA|Mds FCFA|Md|Mds|bps)',
      caseSensitive: false,
      unicode: true,
    ),
  );
  addPattern(RegExp(r'\([^)]+\)', unicode: true));

  if (ranges.isEmpty) {
    return TextSpan(text: value, style: baseStyle);
  }

  ranges.sort((left, right) => left.start.compareTo(right.start));
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final range in ranges) {
    if (cursor < range.start) {
      spans.add(TextSpan(text: value.substring(cursor, range.start)));
    }
    spans.add(
      TextSpan(
        text: value.substring(range.start, range.end),
        style: baseStyle.copyWith(
          color: highlightColor ?? accent,
          fontWeight: highlightWeight,
        ),
      ),
    );
    cursor = range.end;
  }
  if (cursor < value.length) {
    spans.add(TextSpan(text: value.substring(cursor)));
  }

  return TextSpan(style: baseStyle, children: spans);
}

class _FactInfoButton extends StatelessWidget {
  const _FactInfoButton({required this.item});

  final _FactSpec item;

  @override
  Widget build(BuildContext context) {
    return _PinnedTopRichTooltip.content(
      content: _FactTooltipBody(item: item),
      waitDuration: const Duration(milliseconds: 180),
      showDuration: const Duration(seconds: 11),
      screenMargin: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      padding: const EdgeInsets.all(14),
      maxWidth: 430,
      decoration: BoxDecoration(
        color: AppTheme.text.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: item.color.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      child: Container(
        width: 15,
        height: 15,
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.info_circle,
          color: item.color.withValues(alpha: 0.48),
          size: 15,
        ),
      ),
    );
  }
}

class _FactTooltipBody extends StatelessWidget {
  const _FactTooltipBody({required this.item});

  final _FactSpec item;

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      color: Color(0xFFE7EEF9),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.38,
    );

    return SizedBox(
      width: 390,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.info,
                color: const Color(0xFFE7EEF9).withValues(alpha: 0.86),
                size: 14,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.label.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEAF2FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(item.explanation, style: bodyStyle),
          const SizedBox(height: 12),
          if (item.formulaLatex != null) ...[
            _FactTooltipSection(
              title: 'Formule de calcul',
              color: item.color,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Math.tex(
                    item.formulaLatex!,
                    mathStyle: MathStyle.text,
                    textStyle: const TextStyle(
                      color: Color(0xFFEAF2FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    onErrorFallback: (_) => Text(
                      item.formulaLatex!,
                      style: const TextStyle(
                        color: Color(0xFFEAF2FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(
              'Valeur actuelle : ${item.value}',
              style: const TextStyle(
                color: Color(0xFFE7EEF9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 11),
          _FactTooltipSection(
            title: 'Analyse de la valeur',
            color: item.color,
            child: Text(item.analysis, style: bodyStyle),
          ),
          const SizedBox(height: 10),
          _FactTooltipSection(
            title: 'Impact prudentiel',
            color: item.color,
            child: Text(item.impact, style: bodyStyle),
          ),
        ],
      ),
    );
  }
}

class _FactTooltipSection extends StatelessWidget {
  const _FactTooltipSection({
    required this.title,
    required this.color,
    required this.child,
  });

  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFBFD0EA),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _FactSpec {
  const _FactSpec({
    required this.label,
    required this.value,
    required this.color,
    required this.explanation,
    this.formulaLatex,
    required this.analysis,
    required this.impact,
  });

  final String label;
  final String value;
  final Color color;
  final String explanation;
  final String? formulaLatex;
  final String analysis;
  final String impact;
}

enum _ConcentrationMode { clients, sectors, geography }

enum _RiskSummaryDesign {
  counterpartyNetwork,
  rwaTrend,
  riskShield,
  sectorBuildings,
  portfolioPie,
  concentrationGauge,
  geoGlobe,
  zoneDonut,
  exposureStack,
}

class _ConcentrationEntry {
  const _ConcentrationEntry({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  final String label;
  final double amount;
  final double percentage;
  final Color color;
}

class _RiskConcentrationPanel extends StatefulWidget {
  const _RiskConcentrationPanel({
    required this.rows,
    required this.sectors,
    required this.countries,
    required this.displayCurrency,
  });

  final List<PortfolioRow> rows;
  final List<DistributionEntry> sectors;
  final List<DistributionEntry> countries;
  final String displayCurrency;

  @override
  State<_RiskConcentrationPanel> createState() =>
      _RiskConcentrationPanelState();
}

class _RiskConcentrationPanelState extends State<_RiskConcentrationPanel> {
  static const double _bodyHeight = 220;
  static const double _summaryRailWidth = 110;
  static const List<String> _sectorLabels = [
    'Immobilier',
    'Commerce',
    'Industrie',
    'Informel',
    'Télécom',
    'Agriculture',
  ];
  static const List<String> _zoneLabels = [
    'CEMAC',
    'UEMOA',
    'Hors zone',
  ];
  static const List<Color> _zoneColors = [
    AppColors.success,
    AppColors.accent,
    AppColors.warning,
  ];
  static const List<Color> _chartColors = [
    AppColors.marketNeutral,
    AppColors.accent,
    AppColors.prudentialSolvency,
    AppColors.warning,
    AppColors.success,
    Color(0xFFF97316),
  ];

  _ConcentrationMode _mode = _ConcentrationMode.clients;

  @override
  Widget build(BuildContext context) {
    final accent = _modeColor(_mode);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PinnedTopRichTooltip(
                richMessage: _riskConcentrationTooltip(),
                waitDuration: const Duration(milliseconds: 250),
                showDuration: const Duration(seconds: 8),
                screenMargin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                maxWidth: 560,
                decoration: BoxDecoration(
                  color: AppTheme.text.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                child: _IconBox(
                  icon: CupertinoIcons.exclamationmark_shield_fill,
                  color: accent,
                  size: 32,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Concentration des Risques'.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Analyse des concentrations critiques du portefeuille'
                          .tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 8.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _modeSwitch(),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: _bodyHeight,
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 780),
                    reverseDuration: const Duration(milliseconds: 520),
                    switchInCurve: Curves.linear,
                    switchOutCurve: Curves.easeOutCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (final child in previousChildren)
                            Positioned.fill(child: child),
                          if (currentChild != null)
                            Positioned.fill(child: currentChild),
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey(_mode);

                      if (!incoming) {
                        return FadeTransition(
                          opacity: Tween<double>(begin: 0.58, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.972, end: 1).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      }

                      return _DrapePageTransition(
                        animation: animation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_mode),
                      child: _modeContent(
                        mode: _mode,
                        width: constraints.maxWidth,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _setMode(_ConcentrationMode mode) {
    if (_mode == mode) {
      return;
    }

    setState(() {
      _mode = mode;
    });
  }

  TextSpan _riskConcentrationTooltip() {
    return const TextSpan(
      style: TextStyle(
        color: Color(0xFFE7EEF9),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.38,
      ),
      children: [
        TextSpan(
          text: 'Lecture prudentielle des concentrations\n\n',
          style: TextStyle(
            color: Color(0xFFEAF2FF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: 'Objectif : ',
          style: TextStyle(
            color: Color(0xFF67E8F9),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              'identifier les concentrations excessives susceptibles d\'augmenter la pression prudentielle et la vulnérabilité du portefeuille de crédit.\n\n',
        ),
        TextSpan(
          text: 'Concentration : ',
          style: TextStyle(
            color: Color(0xFF93C5FD),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: 'analyse la répartition des expositions par :\n',
        ),
        TextSpan(
          text:
              '• contreparties ;\n• secteurs d\'activité ;\n• zones géographiques ;\n',
        ),
        TextSpan(
          text:
              'afin de détecter les dépendances importantes et les poches de risque dominantes.\n\n',
        ),
        TextSpan(
          text: 'Dominance : ',
          style: TextStyle(
            color: Color(0xFFA7F3D0),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              'met en évidence le segment principal du portefeuille ainsi que son poids relatif dans l\'exposition globale.\n\n',
        ),
        TextSpan(
          text: 'Visualisation : ',
          style: TextStyle(
            color: Color(0xFFFBBF24),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              'les graphiques permettent d\'observer rapidement les concentrations critiques, les déséquilibres du portefeuille et les zones nécessitant une surveillance renforcée.\n\n',
        ),
        TextSpan(
          text: 'Synthèse : ',
          style: TextStyle(
            color: Color(0xFFC4B5FD),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              'la part dominante, le niveau d\'exposition et la structure des concentrations facilitent le pilotage prudentiel et l\'analyse du risque de crédit.',
        ),
      ],
    );
  }

  Widget _modeSwitch() {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _dashboardSurfaceSoftFor(context),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _dashboardBorderFor(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(
            mode: _ConcentrationMode.clients,
            tooltip: 'Concentration clientèle',
            activeIcon: CupertinoIcons.person_2_fill,
            inactiveIcon: CupertinoIcons.person_2,
          ),
          _modeButton(
            mode: _ConcentrationMode.sectors,
            tooltip: 'Concentration sectorielle',
            activeIcon: CupertinoIcons.building_2_fill,
            inactiveIcon: CupertinoIcons.building_2_fill,
          ),
          _modeButton(
            mode: _ConcentrationMode.geography,
            tooltip: 'Concentration géographique',
            activeIcon: CupertinoIcons.globe,
            inactiveIcon: CupertinoIcons.globe,
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required _ConcentrationMode mode,
    required String tooltip,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final selected = _mode == mode;
    final color = _modeColor(mode);

    return Tooltip(
      message: tooltip.tr(context),
      waitDuration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: AppTheme.text.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      textStyle: const TextStyle(
        color: Color(0xFFEAF2FF),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_radius),
          child: InkWell(
            onTap: selected ? null : () => _setMode(mode),
            borderRadius: BorderRadius.circular(_radius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.38)
                      : Colors.transparent,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: selected ? 1.08 : 1,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 170),
                  reverseDuration: const Duration(milliseconds: 120),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.82, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    selected ? activeIcon : inactiveIcon,
                    key: ValueKey('${mode.name}-$selected'),
                    size: 15,
                    color: selected ? color : AppTheme.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeContent({
    required _ConcentrationMode mode,
    required double width,
  }) {
    return switch (mode) {
      _ConcentrationMode.clients => _clientContent(width),
      _ConcentrationMode.sectors => _sectorContent(width),
      _ConcentrationMode.geography => _geographyContent(width),
    };
  }

  Widget _clientContent(double width) {
    final entries = _clientEntries();
    final concentration = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.percentage,
    );
    final delta = _clientRwaDelta(entries);
    final level = _riskLevel(concentration);
    final color = _riskColor(concentration);
    final sideGap = _sideGapFor(width);

    return Row(
      children: [
        Expanded(
          child: _ModeBlockEntrance(
            child: _chartShell(
              title: 'Top 5 contreparties les plus exposées',
              titleWeight: FontWeight.w800,
              child: _horizontalBars(entries),
            ),
          ),
        ),
        SizedBox(width: sideGap),
        SizedBox(
          width: _summaryWidthFor(width),
          child: _ModeBlockEntrance(
            delay: 0.12,
            child: Column(
              children: [
                _summaryTile(
                  label: 'Concentration globale',
                  value: AppFormatters.percent(concentration),
                  color: color,
                  design: _RiskSummaryDesign.counterpartyNetwork,
                ),
                const SizedBox(height: 8),
                _summaryTile(
                  label: 'Variation RWA / EAD',
                  value: _signedPercent(delta),
                  color: delta >= 0 ? AppColors.warning : AppColors.success,
                  design: _RiskSummaryDesign.rwaTrend,
                ),
                const SizedBox(height: 8),
                _summaryTile(
                  label: 'Niveau de risque',
                  value: level,
                  color: color,
                  design: _RiskSummaryDesign.riskShield,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectorContent(double width) {
    final entries = _sectorEntries();
    final dominant = _dominant(entries);
    final concentration = dominant.percentage;
    final level = _riskLevel(concentration);
    final sideGap = _sideGapFor(width);

    return Row(
      children: [
        Expanded(
          child: _ModeBlockEntrance(
            child: _chartShell(
              title: 'Répartition sectorielle du portefeuille',
              child: _verticalBars(entries),
            ),
          ),
        ),
        SizedBox(width: sideGap),
        SizedBox(
          width: _summaryWidthFor(width),
          child: _ModeBlockEntrance(
            delay: 0.12,
            child: Column(
              children: [
                _summaryTile(
                  label: 'Secteur dominant',
                  value: dominant.label,
                  color: dominant.color,
                  design: _RiskSummaryDesign.sectorBuildings,
                ),
                const SizedBox(height: 8),
                _summaryTile(
                  label: 'Part portefeuille',
                  value: AppFormatters.percent(dominant.percentage),
                  color: dominant.color,
                  design: _RiskSummaryDesign.portfolioPie,
                ),
                const SizedBox(height: 8),
                _summaryTile(
                  label: 'Concentration',
                  value: level,
                  color: _riskColor(concentration),
                  design: _RiskSummaryDesign.concentrationGauge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _geographyContent(double width) {
    final entries = _geographyEntries();
    final dominant = _dominant(entries);
    final sideGap = _sideGapFor(width);

    return Row(
      children: [
        Expanded(
          child: _ModeBlockEntrance(
            child: _chartShell(
              title: 'Concentration géographique',
              child: _geographyVisual(entries, dominant),
            ),
          ),
        ),
        SizedBox(width: sideGap),
        SizedBox(
          width: _summaryWidthFor(width),
          child: _ModeBlockEntrance(
            delay: 0.12,
            child: Column(
              children: [
                _summaryTile(
                  label: 'Zone dominante',
                  value: dominant.label,
                  color: dominant.color,
                  design: _RiskSummaryDesign.geoGlobe,
                ),
                const SizedBox(height: 8),
                _summaryTile(
                  label: 'Part zone',
                  value: AppFormatters.percent(dominant.percentage),
                  color: AppColors.warning,
                  design: _RiskSummaryDesign.zoneDonut,
                ),
                const SizedBox(height: 8),
                _summaryTile(
                  label: 'Exp. zone dominante',
                  value: _money(dominant.amount, widget.displayCurrency),
                  color: AppColors.marketNeutral,
                  design: _RiskSummaryDesign.exposureStack,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _summaryWidthFor(double width) {
    if (width < 360) {
      return 78;
    }
    if (width < 430) {
      return 94;
    }
    if (width < 520) {
      return 112;
    }
    return _summaryRailWidth;
  }

  double _sideGapFor(double width) {
    return width < 430 ? 6 : 10;
  }

  Widget _geographyVisual(
    List<_ConcentrationEntry> entries,
    _ConcentrationEntry dominant,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        final donutSize = constraints.maxWidth < 260
            ? 78.0
            : constraints.maxWidth < 330
                ? 98.0
                : 132.0;

        return Row(
          children: [
            SizedBox(
              width: donutSize,
              height: donutSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _HoverProgress(
                    builder: (context, hover) {
                      return _EntranceProgress(
                        builder: (context, enter) {
                          return Transform.rotate(
                            angle: hover * 0.045,
                            child: Transform.scale(
                              scale: 1 + hover * 0.035,
                              child: CustomPaint(
                                painter: _ConcentrationDonutPainter(
                                  entries: entries,
                                  emphasis: hover,
                                  progress: enter,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppFormatters.percent(dominant.percentage),
                          style: TextStyle(
                            color: dominant.color,
                            fontSize: compact ? 13 : 16,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Dominant',
                        style: TextStyle(
                          color: _dashboardMutedFor(context),
                          fontSize: compact ? 8 : 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: compact ? 8 : 16),
            Expanded(child: _geoLegend(entries)),
          ],
        );
      },
    );
  }

  Widget _chartShell({
    required String title,
    required Widget child,
    FontWeight titleWeight = FontWeight.w700,
  }) {
    final surface = _dashboardSurfaceSoftFor(context);
    final border = _dashboardBorderFor(context);
    final textColor = _dashboardTextFor(context);

    return Container(
      height: _bodyHeight,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            surface.withValues(alpha: _isDashboardDark(context) ? 0.56 : 0.78),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: border.withValues(alpha: 0.86)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: titleWeight,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required Color color,
    required _RiskSummaryDesign design,
  }) {
    return Expanded(
      child: _RiskSummaryTile(
        label: label,
        value: value,
        color: color,
        design: design,
      ),
    );
  }

  Widget _horizontalBars(List<_ConcentrationEntry> entries) {
    if (_hasNoData(entries)) {
      return _emptyChart();
    }

    return _EntranceProgress(
      builder: (context, enter) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 270;
            final tight = constraints.maxWidth < 220;
            final showValue = constraints.maxWidth >= 145;
            final gap = constraints.maxWidth < 170
                ? 4.0
                : compact
                    ? 6.0
                    : 8.0;
            final valueWidth = showValue
                ? compact
                    ? 36.0
                    : 44.0
                : 0.0;
            final targetLabelWidth = tight
                ? 70.0
                : compact
                    ? 86.0
                    : 112.0;
            final labelRoom = constraints.maxWidth -
                valueWidth -
                (showValue ? gap * 2 : gap) -
                28;
            final labelWidth = labelRoom.clamp(42.0, targetLabelWidth);
            final barHeight = compact ? 6.0 : 7.0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final entry in entries)
                  _HoverProgress(
                    builder: (context, hover) {
                      return SizedBox(
                        height: compact ? 26 : 28,
                        child: Row(
                          children: [
                            SizedBox(
                              width: labelWidth,
                              child: Text(
                                entry.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _dashboardTextFor(context),
                                  fontSize: compact ? 9 : 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final targetWidth = constraints.maxWidth *
                                      entry.percentage.clamp(0.0, 1.0);
                                  final animatedWidth = targetWidth * enter;

                                  return Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      Container(
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: _dashboardBorderFor(context)
                                              .withValues(alpha: 0.55),
                                          borderRadius:
                                              BorderRadius.circular(_radius),
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: Offset(0, -hover * 1.4),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 260),
                                          curve: Curves.easeOutCubic,
                                          width: animatedWidth,
                                          height: barHeight + hover * 1.4,
                                          decoration: BoxDecoration(
                                            color: entry.color,
                                            borderRadius:
                                                BorderRadius.circular(_radius),
                                            boxShadow: [
                                              BoxShadow(
                                                color: entry.color.withValues(
                                                  alpha: 0.18 + hover * 0.12,
                                                ),
                                                blurRadius: 9 + hover * 8,
                                                offset:
                                                    Offset(0, 3 + hover * 3),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            if (showValue) ...[
                              SizedBox(width: gap),
                              SizedBox(
                                width: valueWidth,
                                child: Text(
                                  AppFormatters.percent(entry.percentage),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Color.lerp(
                                      AppTheme.muted,
                                      entry.color,
                                      hover * 0.35,
                                    ),
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _verticalBars(List<_ConcentrationEntry> entries) {
    if (_hasNoData(entries)) {
      return _emptyChart();
    }

    return _EntranceProgress(
      builder: (context, enter) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final entry in entries)
              Expanded(
                child: _HoverProgress(
                  builder: (context, hover) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 16,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.percent(entry.percentage),
                                style: TextStyle(
                                  color: Color.lerp(
                                    AppTheme.muted,
                                    entry.color,
                                    hover * 0.3,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor:
                                    entry.percentage.clamp(0.0, 1.0) * enter,
                                child: Transform.translate(
                                  offset: Offset(0, -hover * 3),
                                  child: Transform.scale(
                                    scaleY: 1 + hover * 0.035,
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 260),
                                      curve: Curves.easeOutCubic,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: entry.color.withValues(
                                          alpha: 0.88 + hover * 0.08,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(_radius),
                                        boxShadow: [
                                          BoxShadow(
                                            color: entry.color.withValues(
                                              alpha: 0.16 + hover * 0.14,
                                            ),
                                            blurRadius: 10 + hover * 10,
                                            offset: Offset(0, 4 + hover * 5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          SizedBox(
                            height: 18,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                entry.label,
                                maxLines: 1,
                                style: TextStyle(
                                  color: _dashboardTextFor(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _geoLegend(List<_ConcentrationEntry> entries) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 78,
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dashboardTextFor(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GeoLegendLeader(
                    color: _dashboardBorderFor(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppFormatters.percent(entry.percentage),
                  style: TextStyle(
                    color: _dashboardMutedFor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _emptyChart() {
    return Center(
      child: Text(
        'Données indisponibles'.tr(context),
        style: TextStyle(
          color: _dashboardMutedFor(context),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<_ConcentrationEntry> _clientEntries() {
    final totals = <String, double>{};
    final total = widget.rows.fold<double>(
      0,
      (sum, row) => sum + row.grossAmount,
    );

    for (final row in widget.rows) {
      totals.update(
        _counterpartyLabel(row),
        (value) => value + row.grossAmount,
        ifAbsent: () => row.grossAmount,
      );
    }

    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (var index = 0; index < math.min(5, ranked.length); index++)
        _ConcentrationEntry(
          label: ranked[index].key,
          amount: ranked[index].value,
          percentage: total == 0 ? 0 : ranked[index].value / total,
          color: _RiskConcentrationPanelState._chartColors[
              index % _RiskConcentrationPanelState._chartColors.length],
        ),
    ];
  }

  List<_ConcentrationEntry> _sectorEntries() {
    final totals = {
      for (final label in _RiskConcentrationPanelState._sectorLabels)
        label: 0.0,
    };
    final unmatched = <DistributionEntry>[];
    final source = widget.sectors.isNotEmpty
        ? widget.sectors
        : _categoryDistributionFromRows();

    for (final entry in source) {
      final bucket = _sectorBucketFor(entry.label);
      if (bucket == null) {
        unmatched.add(entry);
        continue;
      }
      totals.update(bucket, (value) => value + entry.amount);
    }

    if (totals.values.every((value) => value == 0) && unmatched.isNotEmpty) {
      for (var index = 0; index < unmatched.length; index++) {
        final label = _RiskConcentrationPanelState._sectorLabels[
            index % _RiskConcentrationPanelState._sectorLabels.length];
        totals.update(label, (value) => value + unmatched[index].amount);
      }
    }

    final total = totals.values.fold<double>(0, (sum, value) => sum + value);

    return [
      for (var index = 0;
          index < _RiskConcentrationPanelState._sectorLabels.length;
          index++)
        _ConcentrationEntry(
          label: _RiskConcentrationPanelState._sectorLabels[index],
          amount:
              totals[_RiskConcentrationPanelState._sectorLabels[index]] ?? 0,
          percentage: total == 0
              ? 0
              : (totals[_RiskConcentrationPanelState._sectorLabels[index]] ??
                      0) /
                  total,
          color: _RiskConcentrationPanelState._chartColors[
              index % _RiskConcentrationPanelState._chartColors.length],
        ),
    ];
  }

  List<_ConcentrationEntry> _geographyEntries() {
    final totals = {
      for (final label in _RiskConcentrationPanelState._zoneLabels) label: 0.0,
    };

    for (final row in widget.rows) {
      final zone = computeZone(row.country);
      totals.update(
        zone,
        (value) => value + row.grossAmount,
        ifAbsent: () => row.grossAmount,
      );
    }

    final total = totals.values.fold<double>(0, (sum, value) => sum + value);

    return [
      for (var index = 0;
          index < _RiskConcentrationPanelState._zoneLabels.length;
          index++)
        _ConcentrationEntry(
          label: _RiskConcentrationPanelState._zoneLabels[index],
          amount: totals[_RiskConcentrationPanelState._zoneLabels[index]] ?? 0,
          percentage: total == 0
              ? 0
              : (totals[_RiskConcentrationPanelState._zoneLabels[index]] ?? 0) /
                  total,
          color: _RiskConcentrationPanelState._zoneColors[
              index % _RiskConcentrationPanelState._zoneColors.length],
        ),
    ];
  }

  List<DistributionEntry> _categoryDistributionFromRows() {
    final totals = <String, double>{};
    final total = widget.rows.fold<double>(
      0,
      (sum, row) => sum + row.grossAmount,
    );
    for (final row in widget.rows) {
      totals.update(
        row.category,
        (value) => value + row.grossAmount,
        ifAbsent: () => row.grossAmount,
      );
    }
    return totals.entries
        .map(
          (entry) => DistributionEntry(
            label: entry.key,
            amount: entry.value,
            percentage: total == 0 ? 0 : entry.value / total,
          ),
        )
        .toList();
  }

  double _clientRwaDelta(List<_ConcentrationEntry> entries) {
    final labels = entries.map((entry) => entry.label).toSet();
    final totalEad = widget.rows.fold<double>(0, (sum, row) => sum + row.ead);
    final totalRwa = widget.rows.fold<double>(0, (sum, row) => sum + row.rwa);
    final topEad = widget.rows
        .where((row) => labels.contains(_counterpartyLabel(row)))
        .fold<double>(0, (sum, row) => sum + row.ead);
    final topRwa = widget.rows
        .where((row) => labels.contains(_counterpartyLabel(row)))
        .fold<double>(0, (sum, row) => sum + row.rwa);

    if (totalEad == 0 || totalRwa == 0) {
      return 0;
    }
    return (topRwa / totalRwa) - (topEad / totalEad);
  }

  _ConcentrationEntry _dominant(List<_ConcentrationEntry> entries) {
    if (entries.isEmpty) {
      return const _ConcentrationEntry(
        label: 'N/D',
        amount: 0,
        percentage: 0,
        color: AppTheme.muted,
      );
    }
    return entries.reduce(
      (current, next) => next.percentage > current.percentage ? next : current,
    );
  }

  bool _hasNoData(List<_ConcentrationEntry> entries) {
    return entries.isEmpty || entries.every((entry) => entry.amount == 0);
  }

  String _counterpartyLabel(PortfolioRow row) {
    final label = row.counterparty.trim();
    return label.isEmpty ? row.id : label;
  }

  Color _modeColor(_ConcentrationMode mode) {
    return switch (mode) {
      _ConcentrationMode.clients => AppColors.accent,
      _ConcentrationMode.sectors => AppColors.warning,
      _ConcentrationMode.geography => AppColors.marketNeutral,
    };
  }

  String _riskLevel(double value) {
    if (value >= 0.45) {
      return 'Élevé';
    }
    if (value >= 0.28) {
      return 'Surveillé';
    }
    return 'Maîtrisé';
  }

  Color _riskColor(double value) {
    if (value >= 0.45) {
      return AppColors.danger;
    }
    if (value >= 0.28) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  String _signedPercent(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${AppFormatters.percent(value.abs())}';
  }
}

class _GeoLegendLeader extends StatelessWidget {
  const _GeoLegendLeader({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _GeoLegendLeaderPainter(color: color.withValues(alpha: 0.9)),
      ),
    );
  }
}

class _GeoLegendLeaderPainter extends CustomPainter {
  const _GeoLegendLeaderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    var startX = 0.0;
    final y = size.height / 2;

    while (startX < size.width) {
      final endX = math.min(startX + dashWidth, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _GeoLegendLeaderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RiskSummaryTile extends StatefulWidget {
  const _RiskSummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.design,
  });

  final String label;
  final String value;
  final Color color;
  final _RiskSummaryDesign design;

  @override
  State<_RiskSummaryTile> createState() => _RiskSummaryTileState();
}

class _RiskSummaryTileState extends State<_RiskSummaryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 112;

          return AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            offset: _hovered ? const Offset(0, -0.01) : Offset.zero,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: _hovered ? 1.004 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 7 : 9),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color:
                      widget.color.withValues(alpha: _hovered ? 0.07 : 0.045),
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: _hovered ? 0.065 : 0.025,
                      ),
                      blurRadius: _hovered ? 10 : 5,
                      offset: Offset(0, _hovered ? 4 : 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            opacity: _hovered
                                ? (compact ? 0.045 : 0.055)
                                : (compact ? 0.022 : 0.028),
                            child: AnimatedRotation(
                              turns: _hovered ? 0.004 : 0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                scale: _hovered ? 1.025 : 1,
                                child: Transform.translate(
                                  offset: Offset(compact ? 18 : 22, 0),
                                  child: SizedBox(
                                    width: compact ? 88 : 112,
                                    height: compact ? 88 : 112,
                                    child: CustomPaint(
                                      painter: _RiskSummaryDesignPainter(
                                        design: widget.design,
                                        color: widget.color,
                                        compact: compact,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label.tr(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _dashboardMutedFor(context),
                            fontSize: compact ? 8 : 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: compact ? 4 : 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.value,
                            maxLines: 1,
                            style: TextStyle(
                              color: widget.color.withValues(
                                alpha: _hovered ? 0.92 : 0.84,
                              ),
                              fontSize: compact ? 14 : 16,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RiskSummaryDesignPainter extends CustomPainter {
  const _RiskSummaryDesignPainter({
    required this.design,
    required this.color,
    required this.compact,
  });

  final _RiskSummaryDesign design;
  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 112;
    canvas
      ..save()
      ..translate(
          (size.width - 112 * scale) / 2, (size.height - 112 * scale) / 2)
      ..scale(scale);

    final stroke = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final thin = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    final fillStrong = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    switch (design) {
      case _RiskSummaryDesign.counterpartyNetwork:
        _paintCounterpartyNetwork(canvas, stroke, thin, fill, fillStrong);
      case _RiskSummaryDesign.rwaTrend:
        _paintRwaTrend(canvas, stroke, thin, fill, fillStrong);
      case _RiskSummaryDesign.riskShield:
        _paintRiskShield(canvas, stroke, thin, fill);
      case _RiskSummaryDesign.sectorBuildings:
        _paintSectorBuildings(canvas, stroke, thin, fill, fillStrong);
      case _RiskSummaryDesign.portfolioPie:
        _paintPortfolioPie(canvas, stroke, thin, fill);
      case _RiskSummaryDesign.concentrationGauge:
        _paintConcentrationGauge(canvas, stroke, thin, fill, fillStrong);
      case _RiskSummaryDesign.geoGlobe:
        _paintGeoGlobe(canvas, stroke, thin, fill, fillStrong);
      case _RiskSummaryDesign.zoneDonut:
        _paintZoneDonut(canvas, stroke, thin, fill);
      case _RiskSummaryDesign.exposureStack:
        _paintExposureStack(canvas, stroke, thin, fill, fillStrong);
    }

    canvas.restore();
  }

  void _paintCounterpartyNetwork(
    Canvas canvas,
    Paint stroke,
    Paint thin,
    Paint fill,
    Paint fillStrong,
  ) {
    final points = [
      const Offset(56, 56),
      const Offset(22, 30),
      const Offset(26, 88),
      const Offset(88, 28),
      const Offset(92, 88),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
      path.moveTo(points.first.dx, points.first.dy);
    }
    canvas.drawPath(path, thin);
    canvas.drawCircle(points.first, 21, fill);
    canvas.drawCircle(points.first, 21, stroke);
    canvas.drawCircle(points.first.translate(0, -5), 5.5, fillStrong);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 58, 22, 13),
        const Radius.circular(2),
      ),
      fillStrong,
    );
    for (final point in points.skip(1)) {
      canvas.drawCircle(point, 12, fill);
      canvas.drawCircle(point, 12, stroke);
    }
  }

  void _paintRwaTrend(
    Canvas canvas,
    Paint stroke,
    Paint thin,
    Paint fill,
    Paint fillStrong,
  ) {
    canvas.drawLine(const Offset(18, 90), const Offset(96, 90), thin);
    canvas.drawLine(const Offset(18, 90), const Offset(18, 24), thin);
    canvas.drawLine(const Offset(28, 70), const Offset(96, 70), thin);
    canvas.drawLine(const Offset(28, 50), const Offset(96, 50), thin);
    final path = Path()
      ..moveTo(24, 78)
      ..lineTo(42, 62)
      ..lineTo(58, 70)
      ..lineTo(78, 38)
      ..lineTo(98, 28);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(const Offset(78, 38), 6, fillStrong);
    canvas.drawPath(
      Path()
        ..moveTo(88, 28)
        ..lineTo(98, 28)
        ..lineTo(98, 38),
      stroke,
    );
  }

  void _paintRiskShield(Canvas canvas, Paint stroke, Paint thin, Paint fill) {
    final shield = Path()
      ..moveTo(56, 16)
      ..lineTo(88, 28)
      ..quadraticBezierTo(86, 66, 56, 96)
      ..quadraticBezierTo(26, 66, 24, 28)
      ..close();
    canvas.drawPath(shield, fill);
    canvas.drawPath(shield, stroke);
    canvas.drawLine(const Offset(56, 40), const Offset(56, 64), stroke);
    canvas.drawCircle(const Offset(56, 78), 4.8, stroke);
    canvas.drawCircle(const Offset(56, 56), 46, thin);
  }

  void _paintSectorBuildings(
    Canvas canvas,
    Paint stroke,
    Paint thin,
    Paint fill,
    Paint fillStrong,
  ) {
    canvas.drawLine(const Offset(16, 94), const Offset(100, 94), thin);
    final buildings = [
      const Rect.fromLTWH(24, 44, 22, 50),
      const Rect.fromLTWH(48, 24, 26, 70),
      const Rect.fromLTWH(76, 52, 22, 42),
    ];
    for (final rect in buildings) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)), fill);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)), stroke);
    }
    for (final x in [31.0, 39.0, 56.0, 66.0, 83.0, 91.0]) {
      for (final y in [40.0, 56.0, 72.0]) {
        if (y < 50 && (x < 52 || x > 72)) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 4, 6), const Radius.circular(2)),
          fillStrong,
        );
      }
    }
  }

  void _paintPortfolioPie(Canvas canvas, Paint stroke, Paint thin, Paint fill) {
    final rect = Rect.fromCircle(center: const Offset(56, 54), radius: 35);
    canvas.drawCircle(const Offset(56, 54), 38, fill);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 0.86, false, stroke);
    canvas.drawArc(rect, math.pi * 0.04, math.pi * 0.58, false, thin);
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 0.55, false, thin);
    canvas.drawCircle(const Offset(56, 54), 16,
        Paint()..color = Colors.white.withValues(alpha: 0.54));
    canvas.drawLine(const Offset(26, 96), const Offset(90, 96), thin);
    canvas.drawLine(const Offset(38, 104), const Offset(76, 104), thin);
  }

  void _paintConcentrationGauge(
    Canvas canvas,
    Paint stroke,
    Paint thin,
    Paint fill,
    Paint fillStrong,
  ) {
    final rect = Rect.fromCircle(center: const Offset(56, 68), radius: 42);
    canvas.drawArc(rect, math.pi * 0.84, math.pi * 1.32, false, thin);
    canvas.drawArc(rect, math.pi * 1.55, math.pi * 0.58, false, stroke);
    canvas.drawLine(const Offset(56, 68), const Offset(86, 50), stroke);
    canvas.drawCircle(const Offset(56, 68), 8, fillStrong);
    canvas.drawPath(
      Path()
        ..moveTo(22, 84)
        ..lineTo(34, 76)
        ..moveTo(90, 84)
        ..lineTo(78, 76),
      thin,
    );
  }

  void _paintGeoGlobe(
    Canvas canvas,
    Paint stroke,
    Paint thin,
    Paint fill,
    Paint fillStrong,
  ) {
    canvas.drawCircle(const Offset(54, 56), 38, fill);
    canvas.drawCircle(const Offset(54, 56), 38, stroke);
    canvas.drawOval(const Rect.fromLTWH(40, 18, 28, 76), thin);
    canvas.drawLine(const Offset(18, 56), const Offset(90, 56), thin);
    canvas.drawLine(const Offset(24, 38), const Offset(84, 38), thin);
    canvas.drawLine(const Offset(24, 74), const Offset(84, 74), thin);
    final pin = Path()
      ..moveTo(82, 20)
      ..quadraticBezierTo(98, 34, 82, 54)
      ..quadraticBezierTo(66, 34, 82, 20)
      ..close();
    canvas.drawPath(pin, fillStrong);
    canvas.drawPath(pin, stroke);
    canvas.drawCircle(const Offset(82, 34), 5, fill);
  }

  void _paintZoneDonut(Canvas canvas, Paint stroke, Paint thin, Paint fill) {
    final rect = Rect.fromCircle(center: const Offset(56, 56), radius: 38);
    canvas.drawCircle(const Offset(56, 56), 42, fill);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 0.58, false, stroke);
    canvas.drawArc(rect, math.pi * 0.04, math.pi * 0.42, false, thin);
    canvas.drawArc(rect, math.pi * 0.55, math.pi * 0.36, false, thin);
    canvas.drawArc(rect, math.pi * 1.04, math.pi * 0.5, false, thin);
    final compass = Path()
      ..moveTo(56, 30)
      ..lineTo(66, 58)
      ..lineTo(56, 82)
      ..lineTo(46, 58)
      ..close();
    canvas.drawPath(
        compass, Paint()..color = Colors.white.withValues(alpha: 0.58));
    canvas.drawPath(compass, thin);
  }

  void _paintExposureStack(
    Canvas canvas,
    Paint stroke,
    Paint thin,
    Paint fill,
    Paint fillStrong,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 28, 74, 36), const Radius.circular(2)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 28, 74, 36), const Radius.circular(2)),
      thin,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(16, 46, 80, 40), const Radius.circular(2)),
      Paint()..color = color.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(16, 46, 80, 40), const Radius.circular(2)),
      stroke,
    );
    canvas.drawLine(const Offset(30, 58), const Offset(78, 58), thin);
    canvas.drawLine(const Offset(30, 72), const Offset(66, 72), thin);
    for (final x in [32.0, 56.0, 80.0]) {
      canvas.drawCircle(Offset(x, 98), 12, fillStrong);
      canvas.drawCircle(Offset(x, 98), 12, thin);
    }
  }

  @override
  bool shouldRepaint(covariant _RiskSummaryDesignPainter oldDelegate) {
    return oldDelegate.design != design ||
        oldDelegate.color != color ||
        oldDelegate.compact != compact;
  }
}

class _RwaEvolutionAnalyticsPanel extends StatefulWidget {
  const _RwaEvolutionAnalyticsPanel({
    required this.rows,
    required this.displayCurrency,
  });

  final List<PortfolioRow> rows;
  final String displayCurrency;

  @override
  State<_RwaEvolutionAnalyticsPanel> createState() =>
      _RwaEvolutionAnalyticsPanelState();
}

class _RwaEvolutionAnalyticsPanelState
    extends State<_RwaEvolutionAnalyticsPanel> {
  static const List<String> _periods = ['1M', '3M', '6M', '1Y', 'ALL'];
  static const List<String> _monthLabels = [
    'Janv.',
    'Févr.',
    'Mars',
    'Avr.',
    'Mai',
    'Juin',
    'Juil.',
    'Août',
    'Sept.',
    'Oct.',
    'Nov.',
    'Déc.',
  ];
  String _selectedPeriod = '6M';
  DateTime _selectedReferenceDate = DateTime.now();
  _RwaHoverInfo? _hoverInfo;

  @override
  void initState() {
    super.initState();
    _selectedReferenceDate = _latestPortfolioDate();
  }

  @override
  void didUpdateWidget(covariant _RwaEvolutionAnalyticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows != widget.rows &&
        !_hasDataForYear(_selectedReferenceDate.year)) {
      _selectedReferenceDate = _latestPortfolioDate();
      _hoverInfo = null;
    }
  }

  DateTime _latestPortfolioDate() {
    final dates = widget.rows
        .map((row) => row.analysisDate)
        .whereType<DateTime>()
        .toList(growable: false);
    if (dates.isEmpty) {
      return DateTime.now();
    }
    dates.sort();
    return dates.last;
  }

  bool _hasDataForYear(int year) {
    return widget.rows.any((row) => row.analysisDate?.year == year);
  }

  @override
  Widget build(BuildContext context) {
    final series = _visibleSeries();
    final exposureSeries =
        series.isEmpty ? const <_RwaChartPoint>[] : series.first.points;
    final hasExposureData = exposureSeries.isNotEmpty;
    final currentExposure = hasExposureData ? exposureSeries.last.value : 0.0;
    final averageExposure = hasExposureData
        ? exposureSeries.fold<double>(0, (sum, point) => sum + point.value) /
            exposureSeries.length
        : 0.0;
    final peakPoint = hasExposureData
        ? exposureSeries.reduce(
            (left, right) => left.value >= right.value ? left : right,
          )
        : null;
    final periodVariation =
        exposureSeries.length < 2 || exposureSeries.first.value == 0
            ? 0.0
            : (exposureSeries.last.value - exposureSeries.first.value) /
                exposureSeries.first.value;

    return _PanelBlock(
      title: 'Exposition totale mensuelle',
      subtitle: "Suivi mensuel du niveau d'exposition du portefeuille",
      icon: CupertinoIcons.chart_bar_square_fill,
      iconTooltip: _rwaEvolutionTooltip(),
      color: AppColors.concentrationPrimary,
      trailing: _RwaTimelineControls(
        selectedDate: _selectedReferenceDate,
        onDateChanged: (value) => setState(() {
          _selectedReferenceDate = value;
          _hoverInfo = null;
        }),
        periods: _periods,
        selectedPeriod: _selectedPeriod,
        onPeriodChanged: (value) => setState(() {
          _selectedPeriod = value;
          _hoverInfo = null;
        }),
      ),
      child: SizedBox(
        height: _RiskConcentrationPanelState._bodyHeight,
        child: hasExposureData
            ? Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const minChartWidth = 520.0;
                        final chartWidth =
                            math.max(constraints.maxWidth, minChartWidth);
                        final chart = SizedBox(
                          width: chartWidth,
                          child: _RwaChartSurface(
                            series: series,
                            displayCurrency: widget.displayCurrency,
                            hoverInfo: _hoverInfo,
                            onHover: (info) =>
                                setState(() => _hoverInfo = info),
                            onExit: () => setState(() => _hoverInfo = null),
                          ),
                        );

                        if (constraints.maxWidth >= minChartWidth) {
                          return chart;
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: chart,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  _RwaAnalyticsSummary(
                    displayCurrency: widget.displayCurrency,
                    currentExposure: currentExposure,
                    averageExposure: averageExposure,
                    peakLabel: peakPoint?.label ?? '-',
                    peakExposure: peakPoint?.value ?? 0.0,
                    periodVariation: periodVariation,
                  ),
                ],
              )
            : const _RwaEvolutionEmptyState(),
      ),
    );
  }

  TextSpan _rwaEvolutionTooltip() {
    return const TextSpan(
      style: TextStyle(
        color: Color(0xFFE7EEF9),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.38,
      ),
      children: [
        TextSpan(
          text: 'Lecture mensuelle de l\'exposition\n\n',
          style: TextStyle(
            color: Color(0xFFEAF2FF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: 'Objectif : ',
          style: TextStyle(
            color: Color(0xFF67E8F9),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              "suivre le niveau d'exposition totale du portefeuille mois par mois afin d'identifier les phases de croissance ou de réduction du stock de risque.\n\n",
        ),
        TextSpan(
          text: 'Exposition totale : ',
          style: TextStyle(
            color: Color(0xFF93C5FD),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              'montant consolidé des engagements suivis sur chaque mois de la période sélectionnée.\n\n',
        ),
        TextSpan(
          text: 'Bâtons : ',
          style: TextStyle(
            color: Color(0xFFFBBF24),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              "chaque mois est représenté par un seul bâton pour faciliter la comparaison directe des niveaux d'exposition.\n\n",
        ),
        TextSpan(
          text: 'Synthèse : ',
          style: TextStyle(
            color: Color(0xFFC4B5FD),
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text:
              "les indicateurs du bas résument l'exposition actuelle, la moyenne de période, le pic observé et l'évolution globale.",
        ),
      ],
    );
  }

  List<_RwaSeries> _visibleSeries() {
    final basePoints = _basePoints();
    final takeCount = switch (_selectedPeriod) {
      '1M' => 1,
      '3M' => 3,
      '6M' => 6,
      '1Y' => 12,
      _ => basePoints.length,
    };
    final visiblePoints = basePoints.length <= takeCount
        ? basePoints
        : basePoints.sublist(basePoints.length - takeCount);
    return [
      _RwaSeries(
        label: 'Exposition totale',
        color: AppColors.concentrationPrimary,
        points: [
          for (final point in visiblePoints)
            _RwaChartPoint(
              label: point.label,
              value: point.value,
            ),
        ],
      ),
    ];
  }

  List<DashboardProjectionPoint> _basePoints() {
    final monthTotals = List<double>.filled(12, 0.0);
    for (final row in widget.rows) {
      final date = row.analysisDate;
      if (date == null || date.year != _selectedReferenceDate.year) {
        continue;
      }
      monthTotals[date.month - 1] += row.grossAmount;
    }

    final activeMonths = <int>[
      for (var index = 0; index < monthTotals.length; index++)
        if (monthTotals[index] > 0) index,
    ];
    if (activeMonths.isEmpty) {
      return const [];
    }

    final firstMonth = activeMonths.first;
    final lastMonth = activeMonths.last;

    return [
      for (var index = firstMonth; index <= lastMonth; index++)
        DashboardProjectionPoint(
          label: _monthLabels[index],
          value: monthTotals[index],
        ),
    ];
  }
}

class _RwaEvolutionEmptyState extends StatelessWidget {
  const _RwaEvolutionEmptyState();

  @override
  Widget build(BuildContext context) {
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);
    final borderColor = _dashboardBorderFor(context);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(_radius),
              ),
              child: const Icon(
                CupertinoIcons.chart_bar_square,
                color: AppColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Aucune donnée disponible'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aucun point mensuel ne correspond à la période sélectionnée.'
                  .tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RwaChartSurface extends StatelessWidget {
  const _RwaChartSurface({
    required this.series,
    required this.displayCurrency,
    required this.hoverInfo,
    required this.onHover,
    required this.onExit,
  });

  final List<_RwaSeries> series;
  final String displayCurrency;
  final _RwaHoverInfo? hoverInfo;
  final ValueChanged<_RwaHoverInfo?> onHover;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final unitLabel = _chartMoneyUnitLabel(
      _RwaEvolutionChartPainter.maxBarValue(series),
      displayCurrency,
    );

    return Column(
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: _RwaLegend(series: series),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: _RwaUnitBadge(unitLabel: unitLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              return MouseRegion(
                onHover: (event) =>
                    onHover(_hoverFrom(event.localPosition, size)),
                onExit: (_) => onExit(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 780),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, _) {
                        return CustomPaint(
                          painter: _RwaEvolutionChartPainter(
                            series: series,
                            progress: progress,
                            hoverInfo: hoverInfo,
                            displayCurrency: displayCurrency,
                            axisColor: _dashboardMutedFor(context),
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                    if (hoverInfo != null)
                      Positioned(
                        left: _hoverSummaryLeft(
                          hoverInfo!.position.dx,
                          constraints.maxWidth,
                        ),
                        top: _hoverSummaryTop(),
                        child: _RwaHoverSummary(
                          info: hoverInfo!,
                          displayCurrency: displayCurrency,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  _RwaHoverInfo? _hoverFrom(Offset position, Size size) {
    if (series.isEmpty ||
        series.first.points.isEmpty ||
        size.width <= 0 ||
        size.height <= 0) {
      return null;
    }

    final bounds = _RwaEvolutionChartPainter.chartBounds(size);
    if (!bounds.inflate(10).contains(position)) {
      return null;
    }

    final pointCount = series.first.points.length;
    final groupWidth = bounds.width / pointCount;
    final index = ((position.dx - bounds.left) / groupWidth)
        .floor()
        .clamp(0, pointCount - 1);
    final selectedPoint = series.first.points[index];
    final maxTotal = _RwaEvolutionChartPainter.maxBarValue(series);
    final barTop = _RwaEvolutionChartPainter.valueToY(
      bounds,
      selectedPoint.value,
      maxTotal,
    );
    final previousValue =
        index == 0 ? selectedPoint.value : series.first.points[index - 1].value;
    final variation = previousValue == 0
        ? 0.0
        : (selectedPoint.value - previousValue) / previousValue;
    final x = bounds.left + groupWidth * (index + 0.5);

    return _RwaHoverInfo(
      series: series.first,
      point: selectedPoint,
      index: index,
      variation: variation,
      position: Offset(x, barTop),
    );
  }

  double _hoverSummaryLeft(double anchorX, double width) {
    const summaryWidth = 196.0;
    return (anchorX - summaryWidth / 2)
        .clamp(8.0, math.max(8.0, width - summaryWidth - 8));
  }

  double _hoverSummaryTop() {
    return 2;
  }
}

class _RwaLegend extends StatelessWidget {
  const _RwaLegend({required this.series});

  final List<_RwaSeries> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final item in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  color: _dashboardMutedFor(context),
                  fontSize: 9.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RwaUnitBadge extends StatelessWidget {
  const _RwaUnitBadge({required this.unitLabel});

  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(1),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.number,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            'Montants en $unitLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.2,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RwaHoverSummary extends StatelessWidget {
  const _RwaHoverSummary({
    required this.info,
    required this.displayCurrency,
  });

  final _RwaHoverInfo info;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final variationPrefix = info.variation >= 0 ? '+' : '';
    final variationColor = info.variation >= 0 ? AppColors.warning : AppColors.success;
    final surface = _dashboardSurfaceFor(context);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return SizedBox(
      width: 196,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: info.series.color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF13203A).withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: info.series.color,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      info.series.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: info.series.color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _money(info.point.value, displayCurrency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      info.point.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 8.6,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                  Text(
                    '$variationPrefix${AppFormatters.percent(info.variation)}',
                    style: TextStyle(
                      color: variationColor,
                      fontSize: 8.8,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RwaTimelineControls extends StatelessWidget {
  const _RwaTimelineControls({
    required this.selectedDate,
    required this.onDateChanged,
    required this.periods,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final List<String> periods;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final initialDate = selectedDate.isAfter(today) ? today : selectedDate;
    final surface = _dashboardSurfaceSoftFor(context);
    final border = _dashboardBorderFor(context);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return Container(
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () async {
              final pickedYear = await showDialog<int>(
                context: context,
                builder: (dialogContext) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                  child: SizedBox(
                    width: 286,
                    height: 332,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Text(
                            context.tr('Année de référence'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Divider(height: 1, color: border),
                        Expanded(
                          child: YearPicker(
                            firstDate: DateTime(2000),
                            lastDate: today,
                            selectedDate: initialDate,
                            onChanged: (value) {
                              Navigator.of(dialogContext).pop(value.year);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              if (pickedYear != null && context.mounted) {
                onDateChanged(_dateWithYear(selectedDate, pickedYear));
              }
            },
            borderRadius: BorderRadius.circular(_radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Center(
                child: Text(
                  '${selectedDate.year}',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            color: AppTheme.border,
          ),
          for (final period in periods)
            InkWell(
              onTap: () => onPeriodChanged(period),
              borderRadius: BorderRadius.circular(_radius),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedPeriod == period
                      ? AppColors.accent.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    color: selectedPeriod == period ? AppColors.accent : AppTheme.muted,
                    fontSize: 9,
                    fontWeight: selectedPeriod == period
                        ? FontWeight.w700
                        : FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  DateTime _dateWithYear(DateTime date, int year) {
    final maxDay = DateUtils.getDaysInMonth(year, date.month);
    return DateTime(year, date.month, math.min(date.day, maxDay));
  }
}

class _RwaAnalyticsSummary extends StatelessWidget {
  const _RwaAnalyticsSummary({
    required this.displayCurrency,
    required this.currentExposure,
    required this.averageExposure,
    required this.peakLabel,
    required this.peakExposure,
    required this.periodVariation,
  });

  final String displayCurrency;
  final double currentExposure;
  final double averageExposure;
  final String peakLabel;
  final double peakExposure;
  final double periodVariation;

  @override
  Widget build(BuildContext context) {
    final variationPrefix = periodVariation >= 0 ? '+' : '';
    final variationColor = periodVariation >= 0 ? AppColors.warning : AppColors.success;

    return Row(
      children: [
        Expanded(
          child: _RwaSummaryTile(
            label: 'Exposition actuelle',
            value: _money(currentExposure, displayCurrency),
            color: AppColors.concentrationPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RwaSummaryTile(
            label: 'Moyenne période',
            value: _money(averageExposure, displayCurrency),
            color: AppColors.concentrationPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RwaSummaryTile(
            label: 'Pic mensuel',
            value: '$peakLabel · ${_money(peakExposure, displayCurrency)}',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RwaSummaryTile(
            label: 'Évolution période',
            value: '$variationPrefix${AppFormatters.percent(periodVariation)}',
            color: variationColor,
          ),
        ),
      ],
    );
  }
}

class _RwaSummaryTile extends StatelessWidget {
  const _RwaSummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surface = _dashboardSurfaceFor(context);
    final muted = _dashboardMutedFor(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 9.6,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RwaEvolutionChartPainter extends CustomPainter {
  const _RwaEvolutionChartPainter({
    required this.series,
    required this.progress,
    required this.displayCurrency,
    required this.axisColor,
    this.hoverInfo,
  });

  final List<_RwaSeries> series;
  final double progress;
  final String displayCurrency;
  final Color axisColor;
  final _RwaHoverInfo? hoverInfo;

  static Rect chartBounds(Size size) {
    return Rect.fromLTWH(
      70,
      8,
      math.max(1, size.width - 82),
      math.max(1, size.height - 34),
    );
  }

  static double maxBarValue(List<_RwaSeries> series) {
    if (series.isEmpty || series.first.points.isEmpty) {
      return 1;
    }
    var maxValue = 0.0;
    for (final point in series.first.points) {
      maxValue = math.max(maxValue, point.value);
    }
    return maxValue <= 0 ? 1 : _niceChartMax(maxValue);
  }

  static double _niceChartMax(double value) {
    final target = value * 1.14;
    if (target <= 0) {
      return 1;
    }
    final exponent = math
        .pow(
          10,
          (math.log(target) / math.ln10).floor(),
        )
        .toDouble();
    final normalized = target / exponent;
    final niceNormalized = normalized <= 1
        ? 1.0
        : normalized <= 2
            ? 2.0
            : normalized <= 2.5
                ? 2.5
                : normalized <= 5
                    ? 5.0
                    : 10.0;
    return niceNormalized * exponent;
  }

  static double valueToY(
    Rect bounds,
    double value,
    double maxValue,
  ) {
    const topInset = 18.0;
    const bottomInset = 7.0;
    final plotTop = bounds.top + topInset;
    final plotBottom = bounds.bottom - bottomInset;
    final plotHeight = math.max(1.0, plotBottom - plotTop);
    return plotBottom - (value / math.max(1.0, maxValue) * plotHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = chartBounds(size);
    final hasPoints = series.isNotEmpty && series.first.points.isNotEmpty;
    final maxValue = hasPoints ? maxBarValue(series) : 1.0;
    final plotBackground = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(_radius),
    );
    canvas.drawRRect(
      plotBackground,
      Paint()..color = AppColors.surfaceLight.withValues(alpha: 0.42),
    );

    final gridPaint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.54)
      ..strokeWidth = 0.8;

    for (var index = 0; index <= 4; index++) {
      final value = maxValue * (1 - index / 4);
      final y = valueToY(bounds, value, maxValue);
      _drawDashedLine(
        canvas,
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(bounds.left, bounds.top),
      Offset(bounds.left, bounds.bottom),
      Paint()
        ..color = axisColor.withValues(alpha: 0.34)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(bounds.left, bounds.bottom),
      Offset(bounds.right, bounds.bottom),
      Paint()
        ..color = axisColor.withValues(alpha: 0.34)
        ..strokeWidth = 1,
    );

    if (!hasPoints) {
      return;
    }

    _drawYAxisLabels(canvas, bounds, maxValue);
    _drawXAxisLabels(canvas, bounds);

    canvas.save();
    canvas.clipRect(bounds);

    final groupWidth = bounds.width / series.first.points.length;
    final barWidth = math.min(34.0, math.max(16.0, groupWidth * 0.26));
    for (var index = 0; index < series.first.points.length; index++) {
      final value = series.first.points[index].value;
      final centerX = bounds.left + groupWidth * (index + 0.5);
      final left = centerX - barWidth / 2;
      final bottom = valueToY(bounds, 0, maxValue);
      final top = valueToY(bounds, value * progress, maxValue);
      final isHovered = hoverInfo?.index == index;
      final faded = hoverInfo != null && !isHovered;
      final opacity = faded ? 0.42 : 1.0;
      final barRect = Rect.fromLTRB(left, top, left + barWidth, bottom);
      const topRadius = Radius.circular(_radius);
      const bottomRadius = Radius.circular(1.2);
      final clip = RRect.fromRectAndCorners(
        barRect,
        topLeft: topRadius,
        topRight: topRadius,
        bottomLeft: bottomRadius,
        bottomRight: bottomRadius,
      );

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          barRect.shift(const Offset(0, 3)),
          topLeft: topRadius,
          topRight: topRadius,
          bottomLeft: bottomRadius,
          bottomRight: bottomRadius,
        ),
        Paint()..color = series.first.color.withValues(alpha: 0.08 * opacity),
      );

      canvas.save();
      canvas.clipRRect(clip);
      canvas.drawRRect(
        clip,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6366F1).withValues(alpha: 0.96 * opacity),
              const Color(0xFF4338CA).withValues(alpha: 0.98 * opacity),
            ],
          ).createShader(barRect),
      );
      canvas.restore();

      if (isHovered) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left - 3, top - 3, left + barWidth + 3, bottom + 1),
            topRadius,
          ),
          Paint()
            ..color = series.first.color.withValues(alpha: 0.24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }

      if (progress > 0.92 &&
          (series.first.points.length <= 8 || index.isEven)) {
        _drawBarValueLabel(
          canvas,
          bounds,
          centerX,
          top - 6,
          value,
        );
      }
    }
    canvas.restore();

    if (hoverInfo != null) {
      final hover = hoverInfo!;
      canvas.drawLine(
        Offset(hover.position.dx, bounds.top),
        Offset(hover.position.dx, bounds.bottom),
        Paint()
          ..color = series.first.color.withValues(alpha: 0.16)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawYAxisLabels(
    Canvas canvas,
    Rect bounds,
    double maxValue,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      maxLines: 1,
      ellipsis: '…',
    );

    for (var index = 0; index <= 4; index++) {
      final ratio = index / 4;
      final value = maxValue * (1 - ratio);
      final y = valueToY(bounds, value, maxValue);
      textPainter.text = TextSpan(
        text: _axisMoneyLabel(value, displayCurrency),
        style: TextStyle(
          color: axisColor.withValues(alpha: 0.92),
          fontSize: 8.8,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
      textPainter.layout(maxWidth: 68);
      textPainter.paint(
        canvas,
        Offset(
            bounds.left - textPainter.width - 11, y - textPainter.height / 2),
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, Rect bounds) {
    if (series.isEmpty || series.first.points.isEmpty) {
      return;
    }

    final points = series.first.points;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final groupWidth = bounds.width / points.length;
    final labelEvery = points.length <= 7 ? 1 : 2;

    for (var index = 0; index < points.length; index++) {
      if (index != 0 && index != points.length - 1 && index % labelEvery != 0) {
        continue;
      }

      textPainter.text = TextSpan(
        text: points[index].label,
        style: TextStyle(
          color: axisColor.withValues(alpha: 0.96),
          fontSize: 8.8,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
      textPainter.layout(maxWidth: 46);
      final x =
          bounds.left + groupWidth * (index + 0.5) - textPainter.width / 2;
      final clampedX =
          x.clamp(bounds.left - 4, bounds.right - textPainter.width + 4);
      textPainter.paint(canvas, Offset(clampedX.toDouble(), bounds.bottom + 8));
    }
  }

  void _drawBarValueLabel(
    Canvas canvas,
    Rect bounds,
    double centerX,
    double top,
    double value,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: _axisMoneyLabel(value, displayCurrency),
        style: TextStyle(
          color: axisColor.withValues(alpha: 0.98),
          fontSize: 8.4,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    )..layout(maxWidth: 54);
    final x = (centerX - textPainter.width / 2)
        .clamp(bounds.left, bounds.right - textPainter.width)
        .toDouble();
    textPainter.paint(canvas, Offset(x, math.max(bounds.top + 1, top - 10)));
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dash = 4.0;
    const gap = 4.0;
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) {
      return;
    }
    final direction = delta / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final segmentEnd = math.min(drawn + dash, distance);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * segmentEnd,
        paint,
      );
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RwaEvolutionChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.progress != progress ||
        oldDelegate.displayCurrency != displayCurrency ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.hoverInfo != hoverInfo;
  }
}

class _RwaChartPoint {
  const _RwaChartPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class _RwaSeries {
  const _RwaSeries({
    required this.label,
    required this.color,
    required this.points,
  });

  final String label;
  final Color color;
  final List<_RwaChartPoint> points;
}

class _RwaHoverInfo {
  const _RwaHoverInfo({
    required this.series,
    required this.point,
    required this.index,
    required this.variation,
    required this.position,
  });

  final _RwaSeries series;
  final _RwaChartPoint point;
  final int index;
  final double variation;
  final Offset position;
}

class _PanelBlock extends StatelessWidget {
  const _PanelBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
    this.iconTooltip,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;
  final InlineSpan? iconTooltip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final iconBox = _IconBox(icon: icon, color: color, size: 26);
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconTooltip == null)
                iconBox
              else
                _PinnedTopRichTooltip(
                  richMessage: iconTooltip!,
                  waitDuration: const Duration(milliseconds: 250),
                  showDuration: const Duration(seconds: 8),
                  screenMargin: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  maxWidth: 410,
                  decoration: BoxDecoration(
                    color: AppTheme.text.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  textStyle: const TextStyle(
                    color: Color(0xFFEAF2FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.42,
                  ),
                  child: iconBox,
                ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 8.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.borderRadius = _radius,
    this.elevation = 12,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double elevation;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDashboardDark(context);
    final surface = _dashboardSurfaceFor(context);
    final border = _dashboardBorderFor(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: border) : null,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF4A5F7D))
                .withValues(alpha: isDark ? 0.24 : 0.14),
            blurRadius: elevation,
            offset: Offset(0, elevation * 0.28),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PinnedTopRichTooltip extends StatefulWidget {
  const _PinnedTopRichTooltip({
    required this.richMessage,
    required this.child,
    required this.decoration,
    required this.textStyle,
    required this.padding,
    required this.maxWidth,
    required this.screenMargin,
    this.waitDuration = const Duration(milliseconds: 250),
    this.showDuration = const Duration(seconds: 8),
  }) : content = null;

  const _PinnedTopRichTooltip.content({
    required this.content,
    required this.child,
    required this.decoration,
    required this.textStyle,
    required this.padding,
    required this.maxWidth,
    required this.screenMargin,
    this.waitDuration = const Duration(milliseconds: 250),
    this.showDuration = const Duration(seconds: 8),
  }) : richMessage = null;

  final InlineSpan? richMessage;
  final Widget? content;
  final Widget child;
  final Decoration decoration;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final double maxWidth;
  final EdgeInsets screenMargin;
  final Duration waitDuration;
  final Duration showDuration;

  @override
  State<_PinnedTopRichTooltip> createState() => _PinnedTopRichTooltipState();
}

class _PinnedTopRichTooltipState extends State<_PinnedTopRichTooltip> {
  OverlayEntry? _entry;
  Timer? _showTimer;
  Timer? _hideTimer;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _dismissTimer?.cancel();
    _removeTooltip();
    super.dispose();
  }

  void _scheduleShow() {
    _hideTimer?.cancel();
    if (_entry != null) {
      return;
    }
    _showTimer?.cancel();
    _showTimer = Timer(widget.waitDuration, _showTooltip);
  }

  void _scheduleHide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 90), _removeTooltip);
  }

  void _toggleTooltip() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_entry == null) {
      _showTooltip();
    } else {
      _removeTooltip();
    }
  }

  void _showTooltip() {
    if (!mounted || _entry != null) {
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final overlay = Overlay.of(context);
    final overlayRenderObject = overlay.context.findRenderObject();
    if (overlayRenderObject is! RenderBox) {
      return;
    }

    final targetOffset = renderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayRenderObject,
    );
    final targetRect = targetOffset & renderObject.size;

    _entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: _PinnedTopTooltipOverlay(
          anchorRect: targetRect,
          anchorGap: 8,
          decoration: widget.decoration,
          maxWidth: widget.maxWidth,
          padding: widget.padding,
          content: widget.content,
          richMessage: widget.richMessage,
          screenMargin: widget.screenMargin,
          textStyle: widget.textStyle,
          onEnter: () {
            _hideTimer?.cancel();
          },
          onExit: _scheduleHide,
        ),
      ),
    );

    overlay.insert(_entry!);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(widget.showDuration, _removeTooltip);
  }

  void _removeTooltip() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _scheduleShow(),
      onExit: (_) => _scheduleHide(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleTooltip,
        child: widget.child,
      ),
    );
  }
}

class _PinnedTopTooltipOverlay extends StatelessWidget {
  const _PinnedTopTooltipOverlay({
    required this.anchorRect,
    required this.anchorGap,
    required this.decoration,
    required this.maxWidth,
    required this.padding,
    required this.content,
    required this.richMessage,
    required this.screenMargin,
    required this.textStyle,
    required this.onEnter,
    required this.onExit,
  });

  final Rect anchorRect;
  final double anchorGap;
  final Decoration decoration;
  final double maxWidth;
  final EdgeInsets padding;
  final Widget? content;
  final InlineSpan? richMessage;
  final EdgeInsets screenMargin;
  final TextStyle textStyle;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final tooltipContent = content ??
        RichText(
          text: TextSpan(
            style: textStyle,
            children: [richMessage ?? const TextSpan()],
          ),
        );

    return CustomSingleChildLayout(
      delegate: _PinnedTopTooltipLayoutDelegate(
        anchorGap: anchorGap,
        anchorRect: anchorRect,
        maxWidth: maxWidth,
        screenMargin: screenMargin,
      ),
      child: MouseRegion(
        onEnter: (_) => onEnter(),
        onExit: (_) => onExit(),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: decoration,
            child: Padding(
              padding: padding,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: tooltipContent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedTopTooltipLayoutDelegate extends SingleChildLayoutDelegate {
  const _PinnedTopTooltipLayoutDelegate({
    required this.anchorRect,
    required this.anchorGap,
    required this.maxWidth,
    required this.screenMargin,
  });

  final Rect anchorRect;
  final double anchorGap;
  final double maxWidth;
  final EdgeInsets screenMargin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxUsableWidth = math
        .max(
          0.0,
          constraints.maxWidth - screenMargin.horizontal,
        )
        .toDouble();
    final maxUsableHeight = math
        .max(
          0.0,
          constraints.maxHeight - screenMargin.vertical,
        )
        .toDouble();

    return BoxConstraints(
      maxWidth: math.min(maxWidth, maxUsableWidth).toDouble(),
      maxHeight: maxUsableHeight.toDouble(),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = math
        .max(
          screenMargin.left,
          size.width - childSize.width - screenMargin.right,
        )
        .toDouble();
    final left = anchorRect.left.clamp(screenMargin.left, maxLeft).toDouble();

    final aboveAnchor = anchorRect.top - childSize.height - anchorGap;
    final maxTop = math
        .max(
          screenMargin.top,
          size.height - childSize.height - screenMargin.bottom,
        )
        .toDouble();
    final top = aboveAnchor < screenMargin.top
        ? screenMargin.top
        : math.min(aboveAnchor, maxTop).toDouble();

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_PinnedTopTooltipLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        anchorGap != oldDelegate.anchorGap ||
        maxWidth != oldDelegate.maxWidth ||
        screenMargin != oldDelegate.screenMargin;
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.caption,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = _dashboardSurfaceSoftFor(context);
    final border = _dashboardBorderFor(context);
    final textColor = _dashboardTextFor(context);

    final hasCaption = caption != null && caption!.trim().isNotEmpty;
    final pill = Container(
      height: hasCaption ? 38 : 30,
      padding: EdgeInsets.symmetric(horizontal: hasCaption ? 11 : 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.marketNeutral),
          SizedBox(width: hasCaption ? 7 : 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCaption) ...[
                Text(
                  caption!.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dashboardMutedFor(context),
                    fontSize: 7.4,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: hasCaption ? 9.3 : 9.6,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) {
      return pill;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: pill,
      ),
    );
  }
}

typedef _HoverProgressBuilder = Widget Function(
  BuildContext context,
  double progress,
);

class _DrapePageTransition extends StatelessWidget {
  const _DrapePageTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(
          animation.value.clamp(0.0, 1.0),
        );

        return Transform.translate(
          offset: Offset(0, -10 * (1 - progress)),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _dashboardSurfaceSoftFor(context),
                    border: Border.all(
                      color:
                          _dashboardBorderFor(context).withValues(alpha: 0.42),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: _DrapeRevealClipper(progress: progress),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: child ?? const SizedBox.shrink(),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.08),
                                  AppColors.accent.withValues(alpha: 0.035),
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.28, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DrapeEdgePainter(
                      progress: progress,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DrapeRevealClipper extends CustomClipper<Path> {
  const _DrapeRevealClipper({required this.progress});

  final double progress;

  @override
  Path getClip(Size size) {
    if (progress <= 0) {
      return Path();
    }
    if (progress >= 1) {
      return Path()..addRect(Offset.zero & size);
    }

    return Path()
      ..addRect(
        Rect.fromLTWH(0, 0, size.width, size.height * progress),
      );
  }

  @override
  bool shouldReclip(covariant _DrapeRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

class _DrapeEdgePainter extends CustomPainter {
  const _DrapeEdgePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02 || progress >= 0.995) {
      return;
    }

    final width = size.width;
    final height = size.height;
    final y = (height * progress).clamp(0.0, height);
    final bandHeight = (height * 0.13).clamp(18.0, 34.0);
    final foldRect = Rect.fromLTWH(0, y - bandHeight * 0.55, width, bandHeight);
    final shadowRect = Rect.fromLTWH(
      0,
      y - 7,
      width,
      (height * 0.24).clamp(38.0, 64.0),
    );

    canvas
      ..drawRect(
        shadowRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.text.withValues(alpha: 0.14),
              AppTheme.muted.withValues(alpha: 0.08),
              AppTheme.border.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0, 0.22, 0.56, 1],
          ).createShader(shadowRect),
      )
      ..drawRect(
        foldRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppTheme.muted.withValues(alpha: 0.045),
              Colors.white.withValues(alpha: 0.52),
              AppTheme.border.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0, 0.28, 0.48, 0.68, 1],
          ).createShader(foldRect),
      )
      ..drawLine(
        Offset(0, y),
        Offset(width, y),
        Paint()
          ..color = AppTheme.border.withValues(alpha: 0.7)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        Offset(0, y - 1),
        Offset(width, y - 1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.86)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(covariant _DrapeEdgePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ModeBlockEntrance extends StatelessWidget {
  const _ModeBlockEntrance({
    required this.child,
    this.delay = 0,
  });

  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.linear,
      child: child,
      builder: (context, value, child) {
        final delayed = ((value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final progress = Curves.easeOutCubic.transform(delayed);

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - progress)),
            child: Transform.scale(
              scale: 0.992 + progress * 0.008,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _EntranceProgress extends StatelessWidget {
  const _EntranceProgress({required this.builder});

  final _HoverProgressBuilder builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return builder(context, progress);
      },
    );
  }
}

class _HoverProgress extends StatefulWidget {
  const _HoverProgress({required this.builder});

  final _HoverProgressBuilder builder;

  @override
  State<_HoverProgress> createState() => _HoverProgressState();
}

class _HoverProgressState extends State<_HoverProgress> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _hovered ? 1 : 0),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          return widget.builder(context, progress);
        },
      ),
    );
  }
}

class _ConcentrationDonutPainter extends CustomPainter {
  const _ConcentrationDonutPainter({
    required this.entries,
    this.emphasis = 0,
    this.progress = 1,
  });

  final List<_ConcentrationEntry> entries;
  final double emphasis;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final stroke = shortestSide * (0.18 + emphasis * 0.012);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: (shortestSide - stroke) / 2,
    );
    final background = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.24 + emphasis * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, background);

    final total = entries.fold<double>(0, (sum, entry) => sum + entry.amount);
    if (total == 0) {
      return;
    }

    var start = -math.pi / 2;
    for (final entry in entries.where((item) => item.amount > 0)) {
      final sweep = entry.amount / total * math.pi * 2 * progress;
      final paint = Paint()
        ..color = entry.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += entry.amount / total * math.pi * 2;
    }

    canvas.drawCircle(
      center,
      (shortestSide / 2) - stroke - 1,
      Paint()
        ..color = AppColors.surfaceLight.withValues(alpha: 0.96)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ConcentrationDonutPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.emphasis != emphasis ||
        oldDelegate.progress != progress;
  }
}

class _KpiSpec {
  const _KpiSpec({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.trend,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final List<double> trend;
}

class _PortfolioKpiTotals {
  const _PortfolioKpiTotals({
    required this.grossAmount,
    required this.onBalanceExposureAmount,
    required this.offBalanceExposureAmount,
    required this.ead,
    required this.rwa,
    required this.capital,
  });

  final double grossAmount;
  final double onBalanceExposureAmount;
  final double offBalanceExposureAmount;
  final double ead;
  final double rwa;
  final double capital;

  factory _PortfolioKpiTotals.fromRows(List<PortfolioRow> rows) {
    return _PortfolioKpiTotals(
      grossAmount: rows.fold<double>(
        0,
        (sum, item) => sum + item.grossAmount,
      ),
      onBalanceExposureAmount: rows.fold<double>(
        0,
        (sum, item) => sum + item.onBalanceExposureAmount,
      ),
      offBalanceExposureAmount: rows.fold<double>(
        0,
        (sum, item) => sum + item.offBalanceExposureAmount,
      ),
      ead: rows.fold<double>(0, (sum, item) => sum + item.ead),
      rwa: rows.fold<double>(0, (sum, item) => sum + item.rwa),
      capital: rows.fold<double>(0, (sum, item) => sum + item.capital),
    );
  }
}

DashboardMetric _metric(Map<String, DashboardMetric> metrics, String key) {
  return metrics[key] ??
      DashboardMetric(
        key: key,
        label: key,
        value: 0,
        variation: '+0.0% M/M',
        trend: const [0, 0, 0, 0],
      );
}

String _portfolioDisplayRating(String rating) {
  final trimmed = rating.trim();
  if (trimmed.isEmpty) {
    return 'Non noté';
  }
  if (prudentialRatings.contains(trimmed)) {
    return trimmed;
  }
  final normalized = trimmed
      .toUpperCase()
      .replaceAll('É', 'E')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized == 'NON NOTE' || normalized == 'NON NOTÉ') {
    return 'Non noté';
  }
  return 'Non noté';
}

String _money(double value, String displayCurrency) {
  final amount = compactCurrencyForDisplay(value, toCurrency: displayCurrency);
  return _groupLeadingMoneyNumber(amount);
}

String _groupLeadingMoneyNumber(String value) {
  return value.replaceFirstMapped(
    RegExp(r'^(-?\d{4,})(?=\s)'),
    (match) => _groupMoneyDigits(match.group(1)!),
  );
}

String _groupMoneyDigits(String value) {
  final isNegative = value.startsWith('-');
  final digits = isNegative ? value.substring(1) : value;
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    if (index > 0 && remaining % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[index]);
  }

  return isNegative ? '-$buffer' : buffer.toString();
}

String _axisMoneyLabel(double value, String displayCurrency) {
  final moneyLabel = _money(value, displayCurrency);
  final match = _moneyUnitPattern.firstMatch(moneyLabel);
  final scale = match?.group(1)?.trim();
  final normalizedValue = scale == null || scale.isEmpty
      ? value
      : switch (scale) {
          'k' => value / 1000,
          'M' => value / 1000000,
          'Md' || 'Bn' => value / 1000000000,
          _ => value,
        };
  return _compactAxisNumber(normalizedValue);
}

String _compactAxisNumber(double value) {
  if (value.abs() < 0.005) {
    return '0';
  }

  final rounded = (value * 10).roundToDouble() / 10;
  final hasDecimal = (rounded - rounded.roundToDouble()).abs() > 0.001;
  if (!hasDecimal) {
    return rounded.toStringAsFixed(0).replaceAll('.', ',');
  }
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}

String _chartMoneyUnitLabel(double value, String displayCurrency) {
  final moneyLabel = _money(value, displayCurrency);
  final match = _moneyUnitPattern.firstMatch(moneyLabel);
  final scale = match?.group(1)?.trim();
  final currency =
      match?.group(2)?.trim() ?? displayCurrencyLabel(displayCurrency);

  return scale == null || scale.isEmpty ? currency : '$scale $currency';
}

final RegExp _moneyUnitPattern = RegExp(
  r'\s+(?:(Md|M|k|Bn)\s+)?(FCFA|XOF|XAF|EUR|USD|[A-Z]{3,4})$',
);

List<double> _flatTrend(double value) {
  return List<double>.generate(7, (index) => value);
}

double _valueAtRiskFromTrend(List<double> values) {
  if (values.length < 2) {
    return 0;
  }

  final returns = <double>[];
  for (var index = 1; index < values.length; index++) {
    final previous = values[index - 1];
    if (previous == 0) {
      continue;
    }
    returns.add((values[index] - previous) / previous);
  }

  if (returns.isEmpty) {
    return 0;
  }

  final mean = returns.reduce((a, b) => a + b) / returns.length;
  final variance = returns.fold<double>(
        0,
        (sum, item) => sum + math.pow(item - mean, 2).toDouble(),
      ) /
      returns.length;

  return values.last.abs() * math.sqrt(variance) * 1.65;
}

double _valueAtRiskFromPortfolio({
  required List<PortfolioRow> rows,
  required List<double> rwaTrend,
  required double totalRwa,
  required double totalExposure,
}) {
  final trendVar = _valueAtRiskFromTrend(rwaTrend);
  if (trendVar > 0) {
    return trendVar;
  }
  if (rows.isEmpty || totalRwa <= 0) {
    return 0;
  }

  final densities = [
    for (final row in rows)
      if (row.ead > 0) row.rwa / row.ead,
  ];
  final averageDensity = totalExposure == 0 ? 0.0 : totalRwa / totalExposure;
  final densityMean = densities.isEmpty
      ? averageDensity
      : densities.reduce((a, b) => a + b) / densities.length;
  final densityVariance = densities.isEmpty
      ? 0.0
      : densities.fold<double>(
            0,
            (sum, item) => sum + math.pow(item - densityMean, 2).toDouble(),
          ) /
          densities.length;
  final concentrationShare = _maxGroupedShare(
    rows,
    totalRwa,
    keyOf: (row) => row.counterparty,
    amountOf: (row) => row.rwa,
  );
  final volatilityProxy = (math.sqrt(densityVariance) * 0.45 +
          averageDensity * 0.035 +
          concentrationShare * 0.08)
      .clamp(0.006, 0.16)
      .toDouble();

  return totalRwa * volatilityProxy * 1.65;
}

int _criticalIncidentsFromPortfolio({
  required List<PortfolioRow> rows,
  required double nplRatio,
  required double totalRwa,
  required double totalExposure,
}) {
  if (rows.isEmpty) {
    return 0;
  }

  var incidents = 0;
  final counterpartyShare = _maxGroupedShare(
    rows,
    totalExposure,
    keyOf: (row) => row.counterparty,
    amountOf: (row) => row.grossAmount,
  );
  final categoryShare = _maxGroupedShare(
    rows,
    totalRwa,
    keyOf: (row) => row.category,
    amountOf: (row) => row.rwa,
  );
  final hasVeryHighDensity = rows.any(
    (row) => row.ead > 0 && row.rwa / row.ead >= 1.5,
  );
  final hasUncoveredLargeRisk = rows.any((row) {
    final crm = row.crmType.toLowerCase();
    final share = totalRwa == 0 ? 0.0 : row.rwa / totalRwa;
    return share >= 0.18 && (crm.contains('aucune') || crm.trim().isEmpty);
  });

  if (nplRatio >= 0.05) incidents++;
  if (counterpartyShare >= 0.35) incidents++;
  if (categoryShare >= 0.50) incidents++;
  if (hasVeryHighDensity) incidents++;
  if (hasUncoveredLargeRisk) incidents++;

  return incidents;
}

double _maxGroupedShare(
  List<PortfolioRow> rows,
  double total, {
  required String Function(PortfolioRow row) keyOf,
  required double Function(PortfolioRow row) amountOf,
}) {
  if (total <= 0) {
    return 0;
  }
  final buckets = <String, double>{};
  for (final row in rows) {
    buckets.update(
      keyOf(row),
      (value) => value + amountOf(row),
      ifAbsent: () => amountOf(row),
    );
  }
  if (buckets.isEmpty) {
    return 0;
  }
  final maxAmount = buckets.values.reduce(math.max);
  return maxAmount / total;
}

String? _sectorBucketFor(String label) {
  final normalized = _normalizedRiskLabel(label);
  if (normalized.contains('immo')) {
    return 'Immobilier';
  }
  if (normalized.contains('commerce') ||
      normalized.contains('retail') ||
      normalized.contains('detail')) {
    return 'Commerce';
  }
  if (normalized.contains('industrie') ||
      normalized.contains('entreprise') ||
      normalized.contains('corporate')) {
    return 'Industrie';
  }
  if (normalized.contains('informel') ||
      normalized.contains('tpe') ||
      normalized.contains('particulier')) {
    return 'Informel';
  }
  if (normalized.contains('telecom')) {
    return 'Télécom';
  }
  if (normalized.contains('agric')) {
    return 'Agriculture';
  }
  return null;
}

String _normalizedRiskLabel(String value) {
  var normalized = value.toLowerCase();
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
