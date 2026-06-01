import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/kpi_metric_card.dart';
import '../../dashboard/models/dashboard_models.dart';

const Color _background = Color(0xFFF4F7FB);
const Color _surface = Color(0xFFFFFFFF);
const Color _surfaceSoft = Color(0xFFF8FAFC);
const Color _border = Color(0xFFDDE7F5);
const Color _primary = Color(0xFF2563EB);
const Color _cyan = Color(0xFF06B6D4);
const Color _success = Color(0xFF10B981);
const Color _warning = Color(0xFFF59E0B);
const Color _violet = Color(0xFF7C3AED);
const Color _danger = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFF13203A);
const Color _textSecondary = Color(0xFF64748B);
const double _radius = 2;

bool _isDashboardDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _dashboardBackgroundFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF081224) : _background;

Color _dashboardSurfaceFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF0F1B31) : _surface;

Color _dashboardSurfaceSoftFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF14233D) : _surfaceSoft;

Color _dashboardBorderFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF263856) : _border;

Color _dashboardTextFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFFF2F6FF) : _textPrimary;

Color _dashboardMutedFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF9FB0CE) : _textSecondary;

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
    final offBalanceExposure = data.portfolioOverview
        .where(
          (item) =>
              item.category.toLowerCase().contains('hors bilan') ||
              item.id.toUpperCase().startsWith('HB'),
        )
        .fold<double>(0, (sum, item) => sum + item.grossAmount);
    final globalVar = _valueAtRiskFromPortfolio(
      rows: data.portfolioOverview,
      rwaTrend: rwaMetric.trend,
      totalRwa: rwaValue,
      totalExposure: exposureValue,
    );
    final criticalIncidents = _criticalIncidentsFromPortfolio(
      rows: data.portfolioOverview,
      nplRatio: defaultMetric.value,
      totalRwa: rwaValue,
      totalExposure: exposureValue,
    );
    final mainKpis = [
      _KpiSpec(
        label: 'RWA total',
        value: _money(rwaValue, displayCurrency),
        detail: 'Risk Weighted Assets',
        icon: CupertinoIcons.shield_lefthalf_fill,
        color: _primary,
        trend: rwaMetric.trend,
      ),
      _KpiSpec(
        label: 'Ratio de solvabilité',
        value: AppFormatters.percent(solvencyRatio),
        detail: 'Solvency Ratio',
        icon: CupertinoIcons.chart_bar_square_fill,
        color: _cyan,
        trend: solvencyMetric.trend,
      ),
      _KpiSpec(
        label: 'Capital minimum requis',
        value: _money(capitalValue, displayCurrency),
        detail: 'Minimum Required Capital',
        icon: CupertinoIcons.money_dollar_circle_fill,
        color: _primary,
        trend: capitalMetric.trend,
      ),
      _KpiSpec(
        label: 'Ratio NPL',
        value: AppFormatters.percent(defaultMetric.value),
        detail: 'Non Performing Loans',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: _warning,
        trend: defaultMetric.trend,
      ),
      _KpiSpec(
        label: 'VaR globale',
        value: _money(globalVar, displayCurrency),
        detail: 'Value at Risk',
        icon: CupertinoIcons.waveform_circle_fill,
        color: _violet,
        trend: rwaMetric.trend,
      ),
      _KpiSpec(
        label: 'Incidents critiques',
        value: '$criticalIncidents',
        detail: 'Operational Risk',
        icon: CupertinoIcons.exclamationmark_octagon_fill,
        color: _danger,
        trend: _flatTrend(criticalIncidents.toDouble()),
      ),
    ];

    final secondaryKpis = [
      _FactSpec(
        label: 'Ratio CET1',
        value: AppFormatters.percent(tier1Ratio),
        color: _cyan,
        explanation:
            'Indique la capacité du portefeuille à absorber ses pertes via les fonds propres de meilleure qualité.',
        formulaLatex:
            r'\text{Ratio CET1}=\frac{\text{CET1}}{\text{RWA total}}\times100',
        analysis: _cet1RatioAnalysis(tier1Ratio),
        impact: _cet1RatioImpact(tier1Ratio),
      ),
      _FactSpec(
        label: 'Ratio de levier',
        value: AppFormatters.percent(leverageRatio),
        color: _violet,
        explanation:
            'Mesure la couverture de l’exposition totale par les fonds propres, sans pondérer les actifs par le risque.',
        formulaLatex:
            r'\text{Levier}=\frac{\text{Fonds propres eligibles}}{\text{Exposition totale}}\times100',
        analysis: _leverageRatioAnalysis(leverageRatio),
        impact: _leverageRatioImpact(leverageRatio),
      ),
      _FactSpec(
        label: 'Exposition totale',
        value: _money(exposureValue, displayCurrency),
        color: _primary,
        explanation:
            'Agrège le volume de crédit porté par le portefeuille et sert de base au suivi de la taille du risque.',
        formulaLatex:
            r'\text{Exposition totale}=\sum_{i=1}^{n}\text{Montant brut}_{i}',
        analysis: _totalExposureAnalysis(exposureValue, displayCurrency),
        impact: _totalExposureImpact(exposureValue),
      ),
      _FactSpec(
        label: 'Expositions hors bilan',
        value: _money(offBalanceExposure, displayCurrency),
        color: _warning,
        explanation:
            'Suit les engagements non encore inscrits au bilan qui peuvent devenir des expositions après conversion.',
        formulaLatex:
            r'\text{Hors bilan}=\sum_{i\in HB}\text{Montant brut}_{i}',
        analysis: _offBalanceExposureAnalysis(
          offBalanceExposure,
          exposureValue,
          displayCurrency,
        ),
        impact: _offBalanceExposureImpact(offBalanceExposure),
      ),
      _FactSpec(
        label: 'Densité RWA',
        value: AppFormatters.percent(rwaDensity),
        color: _success,
        explanation:
            'Mesure l’intensité en actifs pondérés : elle compare les RWA générés à l’exposition totale.',
        formulaLatex:
            r'\text{Densite RWA}=\frac{\text{RWA total}}{\text{EAD totale}}\times100',
        analysis: _rwaDensityAnalysis(rwaDensity),
        impact: _rwaDensityImpact(rwaDensity),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(color: _dashboardBackgroundFor(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // ignore: prefer_const_constructors
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              0,
            ),
            child: _DashboardTitle(
              analysisDate: analysisDate,
              onPickAnalysisDate: onPickAnalysisDate,
              rows: data.portfolioOverview.length,
              displayCurrency: displayCurrency,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              // ignore: prefer_const_constructors
              padding: EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.pageGap + 8,
                AppTheme.pagePadding,
                AppTheme.pagePadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MainKpiStrip(items: mainKpis),
                  // ignore: prefer_const_constructors
                  SizedBox(height: AppTheme.pageGap),
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
                          // ignore: prefer_const_constructors
                          SizedBox(width: AppTheme.pageGap),
                          Expanded(
                            child: _RwaEvolutionAnalyticsPanel(
                              points: data.rwaProjection,
                              totalRwa: rwaMetric.value,
                              displayCurrency: displayCurrency,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // ignore: prefer_const_constructors
                  SizedBox(height: AppTheme.pageGap),
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
    required this.rows,
    required this.displayCurrency,
  });

  final DateTime analysisDate;
  final VoidCallback onPickAnalysisDate;
  final int rows;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final textColor = _dashboardTextFor(context);
    final mutedColor = _dashboardMutedFor(context);

    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      borderRadius: _radius,
      elevation: 32,
      showBorder: false,
      child: Row(
        children: [
          const _IconBox(
            icon: CupertinoIcons.chart_pie_fill,
            color: _primary,
            size: 28,
          ),
          const SizedBox(width: 8),
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
                    fontSize: 13.8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('Pilotage prudentiel RWA - Approche Standard'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(
            icon: CupertinoIcons.calendar,
            label: AppFormatters.shortDate(analysisDate),
            onTap: onPickAnalysisDate,
          ),
          const SizedBox(width: 6),
          _StatusPill(
            icon: CupertinoIcons.number_square,
            label: '$rows lignes',
          ),
          const SizedBox(width: 6),
          _StatusPill(
            icon: CupertinoIcons.money_dollar_circle_fill,
            label: displayCurrencyLabel(displayCurrency),
          ),
        ],
      ),
    );
  }
}

class _MainKpiStrip extends StatelessWidget {
  const _MainKpiStrip({required this.items});

  final List<_KpiSpec> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const minCardWidth = 178.0;
        final itemCount = math.max(items.length, 1);
        final totalGap = gap * math.max(itemCount - 1, 0);
        final minRowWidth = minCardWidth * itemCount + totalGap;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : minRowWidth;
        final rowWidth = math.max(availableWidth, minRowWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: rowWidth,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(width: gap),
                  Expanded(child: _MainKpiCard(item: items[index])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MainKpiCard extends StatelessWidget {
  const _MainKpiCard({required this.item});

  final _KpiSpec item;

  @override
  Widget build(BuildContext context) {
    return KpiMetricCard(
      label: item.label,
      value: item.value,
      helper: item.detail,
      icon: item.icon,
      color: item.color,
      trend: item.trend,
      fullValue: item.value,
      borderRadius: _radius,
    );
  }
}

class _SecondaryKpiBar extends StatelessWidget {
  const _SecondaryKpiBar({required this.items});

  final List<_FactSpec> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          const cardHeight = 48.0;
          const minCardWidth = 164.0;
          final totalGap = gap * math.max(items.length - 1, 0);
          final fluidWidth = constraints.maxWidth.isFinite
              ? (constraints.maxWidth - totalGap) / math.max(items.length, 1)
              : minCardWidth;
          final cardWidth = math.max(minCardWidth, fluidWidth);
          final rowWidth = cardWidth * items.length + totalGap;

          final row = Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _FactTile(item: items[index]),
                ),
                if (index != items.length - 1) const SizedBox(width: gap),
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
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.item});

  final _FactSpec item;

  @override
  Widget build(BuildContext context) {
    final borderColor = item.color.withValues(alpha: 0.34);
    final surface = _dashboardSurfaceFor(context);
    final textColor = _dashboardTextFor(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: borderColor, width: 0.9),
          boxShadow: [
            BoxShadow(
              color: item.color.withValues(alpha: 0.055),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 30, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label.tr(context).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 7.4,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 10.2,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _FactInfoButton(item: item),
            ),
          ],
        ),
      ),
    );
  }
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
        color: _textPrimary.withValues(alpha: 0.94),
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
                    fontWeight: FontWeight.w600,
                    height: 1.08,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(item.explanation, style: bodyStyle),
          const SizedBox(height: 12),
          _FactTooltipSection(
            title: 'Formule de calcul',
            color: item.color,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                  item.formulaLatex,
                  mathStyle: MathStyle.text,
                  textStyle: const TextStyle(
                    color: Color(0xFFEAF2FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  onErrorFallback: (_) => Text(
                    item.formulaLatex,
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
            fontWeight: FontWeight.w600,
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
    required this.formulaLatex,
    required this.analysis,
    required this.impact,
  });

  final String label;
  final String value;
  final Color color;
  final String explanation;
  final String formulaLatex;
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
  static const double _bodyHeight = 236;
  static const double _summaryRailWidth = 146;
  static const List<String> _sectorLabels = [
    'Immobilier',
    'Commerce',
    'Industrie',
    'Informel',
    'Télécom',
    'Agriculture',
  ];
  static const List<String> _zoneLabels = [
    'UEMOA',
    'CEMAC',
    'Hors Zone',
    'Europe',
    'Asie',
  ];
  static const List<double> _fictiveZoneShares = [
    0.42,
    0.18,
    0.16,
    0.14,
    0.10,
  ];
  static const List<Color> _chartColors = [
    _cyan,
    _primary,
    _violet,
    _warning,
    _success,
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
                  color: _textPrimary.withValues(alpha: 0.94),
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
                  fontWeight: FontWeight.w400,
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
                        fontWeight: FontWeight.w600,
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _modeSwitch(),
            ],
          ),
          const SizedBox(height: 12),
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
        fontWeight: FontWeight.w400,
        height: 1.38,
      ),
      children: [
        TextSpan(
          text: 'Lecture prudentielle des concentrations\n\n',
          style: TextStyle(
            color: Color(0xFFEAF2FF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: 'Objectif : ',
          style: TextStyle(
            color: Color(0xFF67E8F9),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text:
              'identifier les concentrations excessives susceptibles d’augmenter la pression prudentielle et la vulnérabilité du portefeuille de crédit.\n\n',
        ),
        TextSpan(
          text: 'Concentration : ',
          style: TextStyle(
            color: Color(0xFF93C5FD),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: 'analyse la répartition des expositions par :\n',
        ),
        TextSpan(
          text:
              '• contreparties ;\n• secteurs d’activité ;\n• zones géographiques ;\n',
        ),
        TextSpan(
          text:
              'afin de détecter les dépendances importantes et les poches de risque dominantes.\n\n',
        ),
        TextSpan(
          text: 'Dominance : ',
          style: TextStyle(
            color: Color(0xFFA7F3D0),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text:
              'met en évidence le segment principal du portefeuille ainsi que son poids relatif dans l’exposition globale.\n\n',
        ),
        TextSpan(
          text: 'Visualisation : ',
          style: TextStyle(
            color: Color(0xFFFBBF24),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text:
              'les graphiques permettent d’observer rapidement les concentrations critiques, les déséquilibres du portefeuille et les zones nécessitant une surveillance renforcée.\n\n',
        ),
        TextSpan(
          text: 'Synthèse : ',
          style: TextStyle(
            color: Color(0xFFC4B5FD),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text:
              'la part dominante, le niveau d’exposition et la structure des concentrations facilitent le pilotage prudentiel et l’analyse du risque de crédit.',
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
            color: _primary.withValues(alpha: 0.08),
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
        color: _textPrimary.withValues(alpha: 0.94),
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
                    color: selected ? color : _textSecondary,
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
                  color: delta >= 0 ? _warning : _success,
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
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.amount);
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
                  color: dominant.color,
                  design: _RiskSummaryDesign.zoneDonut,
                ),
                const SizedBox(height: 8),
                _summaryTile(
                  label: 'Exposition totale',
                  value: _money(total, widget.displayCurrency),
                  color: _primary,
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
      return 84;
    }
    if (width < 430) {
      return 104;
    }
    if (width < 520) {
      return 124;
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
                          fontWeight: FontWeight.w700,
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

  Widget _chartShell({required String title, required Widget child}) {
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
              fontWeight: FontWeight.w700,
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

    final maxShare = entries.fold<double>(
      0,
      (maxValue, entry) => math.max(maxValue, entry.percentage),
    );

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
                                  final targetWidth = maxShare == 0
                                      ? 0.0
                                      : constraints.maxWidth *
                                          (entry.percentage / maxShare)
                                              .clamp(0.0, 1.0);
                                  final width = targetWidth * enter;
                                  final animatedWidth =
                                      (width + hover * 8).clamp(
                                    0.0,
                                    constraints.maxWidth,
                                  );

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
                                      _textSecondary,
                                      entry.color,
                                      hover * 0.35,
                                    ),
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w700,
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

    final maxShare = entries.fold<double>(
      0,
      (maxValue, entry) => math.max(maxValue, entry.percentage),
    );

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
                                    _textSecondary,
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
                                heightFactor: maxShare == 0
                                    ? 0
                                    : (entry.percentage / maxShare)
                                            .clamp(0.04, 1.0) *
                                        enter,
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
                                  fontWeight: FontWeight.w700,
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
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dashboardTextFor(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<_ConcentrationEntry> _clientEntries() {
    final totals = <String, double>{};
    final total = widget.rows.fold<double>(0, (sum, row) => sum + row.ead);

    for (final row in widget.rows) {
      totals.update(
        _counterpartyLabel(row),
        (value) => value + row.ead,
        ifAbsent: () => row.ead,
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
          color: _chartColors[index % _chartColors.length],
        ),
    ];
  }

  List<_ConcentrationEntry> _sectorEntries() {
    final totals = {for (final label in _sectorLabels) label: 0.0};
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
        final label = _sectorLabels[index % _sectorLabels.length];
        totals.update(label, (value) => value + unmatched[index].amount);
      }
    }

    final total = totals.values.fold<double>(0, (sum, value) => sum + value);

    return [
      for (var index = 0; index < _sectorLabels.length; index++)
        _ConcentrationEntry(
          label: _sectorLabels[index],
          amount: totals[_sectorLabels[index]] ?? 0,
          percentage:
              total == 0 ? 0 : (totals[_sectorLabels[index]] ?? 0) / total,
          color: _chartColors[index % _chartColors.length],
        ),
    ];
  }

  List<_ConcentrationEntry> _geographyEntries() {
    final source = widget.countries.isNotEmpty
        ? widget.countries
        : _countryDistributionFromRows();
    final sourceTotal =
        source.fold<double>(0, (sum, entry) => sum + entry.amount);
    final portfolioTotal =
        widget.rows.fold<double>(0, (sum, row) => sum + row.rwa);
    final displayTotal = sourceTotal > 0 ? sourceTotal : portfolioTotal;
    final baseAmount = displayTotal > 0 ? displayTotal : 100.0;

    // Donnees temporaires diversifiees pour eviter un affichage concentre a 100%.
    return [
      for (var index = 0; index < _zoneLabels.length; index++)
        _ConcentrationEntry(
          label: _zoneLabels[index],
          amount: baseAmount * _fictiveZoneShares[index],
          percentage: _fictiveZoneShares[index],
          color: _chartColors[index % _chartColors.length],
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

  List<DistributionEntry> _countryDistributionFromRows() {
    final totals = <String, double>{};
    final total = widget.rows.fold<double>(0, (sum, row) => sum + row.rwa);
    for (final row in widget.rows) {
      totals.update(
        row.country,
        (value) => value + row.rwa,
        ifAbsent: () => row.rwa,
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
    final topEad = entries.fold<double>(0, (sum, entry) => sum + entry.amount);
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
        color: _textSecondary,
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
      _ConcentrationMode.clients => _primary,
      _ConcentrationMode.sectors => _warning,
      _ConcentrationMode.geography => _cyan,
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
      return _danger;
    }
    if (value >= 0.28) {
      return _warning;
    }
    return _success;
  }

  String _signedPercent(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${AppFormatters.percent(value.abs())}';
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
            offset: _hovered ? const Offset(0, -0.025) : Offset.zero,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: _hovered ? 1.012 : 1,
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
                  border: Border.all(
                    color: widget.color.withValues(
                      alpha: _hovered ? 0.28 : 0.16,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: _hovered ? 0.1 : 0.025,
                      ),
                      blurRadius: _hovered ? 15 : 5,
                      offset: Offset(0, _hovered ? 7 : 2),
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
                              turns: _hovered ? 0.012 : 0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                scale: _hovered ? 1.08 : 1,
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
                            fontWeight: FontWeight.w700,
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
    required this.points,
    required this.totalRwa,
    required this.displayCurrency,
  });

  final List<DashboardProjectionPoint> points;
  final double totalRwa;
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
  static const List<List<double>> _creditRwaProfiles = [
    [
      0.960,
      0.990,
      0.975,
      1.015,
      1.000,
      1.038,
      1.022,
      1.052,
      1.034,
      1.060,
      1.045,
      1.072
    ],
    [
      0.910,
      0.940,
      0.925,
      0.955,
      0.985,
      0.965,
      1.005,
      1.025,
      1.010,
      1.040,
      1.018,
      1.050
    ],
    [
      0.880,
      0.905,
      0.935,
      0.918,
      0.950,
      0.975,
      0.955,
      0.990,
      1.020,
      1.000,
      1.028,
      1.012
    ],
    [
      0.840,
      0.870,
      0.862,
      0.890,
      0.925,
      0.910,
      0.945,
      0.965,
      0.952,
      0.982,
      1.005,
      0.992
    ],
    [
      0.800,
      0.830,
      0.815,
      0.848,
      0.872,
      0.858,
      0.895,
      0.922,
      0.905,
      0.936,
      0.956,
      0.945
    ],
    [
      0.780,
      0.802,
      0.828,
      0.812,
      0.840,
      0.867,
      0.850,
      0.882,
      0.914,
      0.895,
      0.924,
      0.948
    ],
  ];
  String _selectedPeriod = '6M';
  DateTime _selectedReferenceDate = DateTime.now();
  _RwaHoverInfo? _hoverInfo;

  @override
  Widget build(BuildContext context) {
    final series = _visibleSeries();
    final creditSeries =
        series.isEmpty ? const <_RwaChartPoint>[] : series.first.points;
    final hasRwaData = creditSeries.isNotEmpty;
    final currentTotal = hasRwaData ? creditSeries.last.value : 0.0;
    final monthlyVariation = creditSeries.length < 2 ||
            creditSeries[creditSeries.length - 2].value == 0
        ? 0.0
        : (creditSeries.last.value -
                creditSeries[creditSeries.length - 2].value) /
            creditSeries[creditSeries.length - 2].value;
    final periodVariation =
        creditSeries.length < 2 || creditSeries.first.value == 0
            ? 0.0
            : (creditSeries.last.value - creditSeries.first.value) /
                creditSeries.first.value;
    final trend = monthlyVariation > 0.004
        ? 'Hausse'
        : monthlyVariation < -0.004
            ? 'Baisse'
            : 'Stable';

    return _PanelBlock(
      title: 'Évolution des RWA',
      subtitle: 'Suivi dynamique des RWA Crédit en approche standard',
      icon: CupertinoIcons.chart_bar_square_fill,
      iconTooltip: _rwaEvolutionTooltip(),
      color: _primary,
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
        child: hasRwaData
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
                    total: currentTotal,
                    variation: monthlyVariation,
                    trend: trend,
                    periodVariation: periodVariation,
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  TextSpan _rwaEvolutionTooltip() {
    return const TextSpan(
      style: TextStyle(
        color: Color(0xFFE7EEF9),
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.38,
      ),
      children: [
        TextSpan(
          text: 'Lecture prudentielle des RWA Crédit\n\n',
          style: TextStyle(
            color: Color(0xFFEAF2FF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: 'Objectif : ',
          style: TextStyle(
            color: Color(0xFF67E8F9),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text:
              'suivre l’évolution des actifs pondérés par les risques afin d’évaluer la pression en capital générée par le portefeuille de crédit au fil du temps.\n\n',
        ),
        TextSpan(
          text: 'RWA Crédit = actifs pondérés par le risque de crédit. ',
          style: TextStyle(
            color: Color(0xFF93C5FD),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: 'Une hausse des RWA peut traduire :\n',
        ),
        TextSpan(
          text:
              '• une augmentation des expositions ;\n• une dégradation du profil de risque ;\n• ou une pondération réglementaire plus élevée.\n\n',
        ),
        TextSpan(
          text: 'Courbe : ',
          style: TextStyle(
            color: Color(0xFFFBBF24),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text:
              'compare les niveaux de RWA sur la période sélectionnée afin d’identifier :\n',
        ),
        TextSpan(
          text:
              '• une accélération du risque ;\n• une stabilisation ;\n• ou une amélioration du portefeuille.\n\n',
        ),
        TextSpan(
          text: 'Synthèse : ',
          style: TextStyle(
            color: Color(0xFFC4B5FD),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: 'les indicateurs affichés permettent une lecture rapide de :\n',
        ),
        TextSpan(
          text:
              '• la tendance globale ;\n• la variation mensuelle ;\n• et l’évolution prudentielle du risque de crédit.',
        ),
      ],
    );
  }

  List<_RwaSeries> _visibleSeries() {
    final basePoints = _basePoints();
    final takeCount = switch (_selectedPeriod) {
      '1M' => 2,
      '3M' => 4,
      '6M' => 7,
      '1Y' => 12,
      _ => basePoints.length,
    };
    final visiblePoints = basePoints.length <= takeCount
        ? basePoints
        : basePoints.sublist(basePoints.length - takeCount);

    return [
      _RwaSeries(
        label: 'RWA Crédit',
        color: _primary,
        points: [
          for (var index = 0; index < visiblePoints.length; index++)
            _RwaChartPoint(
              label: visiblePoints[index].label,
              value: visiblePoints[index].value,
            ),
        ],
      ),
    ];
  }

  List<DashboardProjectionPoint> _basePoints() {
    final currentDate = DateTime.now();
    if (_selectedReferenceDate.year != currentDate.year) {
      return const [];
    }

    final selectedYearOffset = (currentDate.year - _selectedReferenceDate.year)
        .clamp(0, _creditRwaProfiles.length - 1)
        .toInt();
    final monthCount = _selectedReferenceDate.month.clamp(1, 12).toInt();
    final profile = _creditRwaProfiles[selectedYearOffset];
    final normalizedIndex =
        (monthCount - 1).clamp(0, profile.length - 1).toInt();
    final normalizedValue =
        profile[normalizedIndex] == 0 ? 1.0 : profile[normalizedIndex];
    final creditShare =
        (0.69 - selectedYearOffset * 0.035).clamp(0.52, 0.72).toDouble();
    final creditAnchor = widget.totalRwa * creditShare;

    return [
      for (var index = 0; index < monthCount; index++)
        DashboardProjectionPoint(
          label: _monthLabels[index],
          value: creditAnchor * profile[index] / normalizedValue,
        ),
    ];
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
    return Column(
      children: [
        _RwaLegend(series: series),
        const SizedBox(height: 8),
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
                        left: _tooltipLeft(hoverInfo!.position.dx, size.width),
                        top: _tooltipTop(hoverInfo!.position.dy),
                        child: _RwaTooltip(
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

    final allValues = series
        .expand((item) => item.points.map((point) => point.value))
        .toList();
    final minValue = allValues.reduce(math.min);
    final maxValue = allValues.reduce(math.max);
    final span =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;
    final pointCount = series.first.points.length;
    final xStep = pointCount <= 1 ? 0.0 : bounds.width / (pointCount - 1);
    final index = pointCount <= 1
        ? 0
        : ((position.dx - bounds.left) / xStep)
            .round()
            .clamp(0, pointCount - 1);

    _RwaSeries selectedSeries = series.first;
    var selectedPoint = selectedSeries.points[index];
    var selectedDy = _RwaEvolutionChartPainter.valueToY(
      bounds,
      selectedPoint.value,
      minValue,
      span,
    );
    var nearestDistance = (position.dy - selectedDy).abs();

    for (final candidate in series.skip(1)) {
      final point = candidate.points[index];
      final dy = _RwaEvolutionChartPainter.valueToY(
        bounds,
        point.value,
        minValue,
        span,
      );
      final distance = (position.dy - dy).abs();
      if (distance < nearestDistance) {
        selectedSeries = candidate;
        selectedPoint = point;
        selectedDy = dy;
        nearestDistance = distance;
      }
    }

    final previousValue = index == 0
        ? selectedPoint.value
        : selectedSeries.points[index - 1].value;
    final variation = previousValue == 0
        ? 0.0
        : (selectedPoint.value - previousValue) / previousValue;

    return _RwaHoverInfo(
      series: selectedSeries,
      point: selectedPoint,
      index: index,
      variation: variation,
      position: Offset(bounds.left + xStep * index, selectedDy),
    );
  }

  double _tooltipLeft(double anchorX, double width) {
    return (anchorX - 86).clamp(8.0, math.max(8.0, width - 172));
  }

  double _tooltipTop(double anchorY) {
    return math.max(6, anchorY - 82);
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RwaTooltip extends StatelessWidget {
  const _RwaTooltip({
    required this.info,
    required this.displayCurrency,
  });

  final _RwaHoverInfo info;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final variationPrefix = info.variation >= 0 ? '+' : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF13203A).withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13203A).withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              info.series.label,
              style: TextStyle(
                color: info.series.color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _money(info.point.value, displayCurrency),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$variationPrefix${AppFormatters.percent(info.variation)} • ${info.point.label}',
              style: const TextStyle(
                color: Color(0xFFC8D4E8),
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
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
                              fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.w700,
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
            color: _border,
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
                      ? _primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    color: selectedPeriod == period ? _primary : _textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
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
    required this.total,
    required this.variation,
    required this.trend,
    required this.periodVariation,
  });

  final String displayCurrency;
  final double total;
  final double variation;
  final String trend;
  final double periodVariation;

  @override
  Widget build(BuildContext context) {
    final variationPrefix = variation >= 0 ? '+' : '';
    final periodVariationPrefix = periodVariation >= 0 ? '+' : '';
    final trendColor = trend == 'Hausse'
        ? _warning
        : trend == 'Baisse'
            ? _success
            : _textSecondary;

    return Row(
      children: [
        Expanded(
          child: _RwaSummaryTile(
            label: 'RWA Crédit actuel',
            value: _money(total, displayCurrency),
            color: _primary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RwaSummaryTile(
            label: 'Variation mensuelle',
            value: '$variationPrefix${AppFormatters.percent(variation)}',
            color: variation >= 0 ? _warning : _success,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RwaSummaryTile(
            label: 'Tendance globale',
            value: trend,
            color: trendColor,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RwaSummaryTile(
            label: 'Évolution période',
            value:
                '$periodVariationPrefix${AppFormatters.percent(periodVariation)}',
            color: periodVariation >= 0 ? _warning : _success,
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
              fontWeight: FontWeight.w500,
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
      74,
      8,
      math.max(1, size.width - 86),
      math.max(1, size.height - 28),
    );
  }

  static double valueToY(
    Rect bounds,
    double value,
    double minValue,
    double span,
  ) {
    const topInset = 18.0;
    const bottomInset = 3.0;
    final plotTop = bounds.top + topInset;
    final plotBottom = bounds.bottom - bottomInset;
    final plotHeight = math.max(1.0, plotBottom - plotTop);
    return plotBottom - ((value - minValue) / span * plotHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = chartBounds(size);
    final gridPaint = Paint()
      ..color = _border.withValues(alpha: 0.70)
      ..strokeWidth = 0.8;

    for (var index = 0; index <= 4; index++) {
      final y = bounds.top + bounds.height * index / 4;
      canvas.drawLine(
          Offset(bounds.left, y), Offset(bounds.right, y), gridPaint);
    }

    if (series.isEmpty || series.first.points.isEmpty) {
      return;
    }

    final allValues = series
        .expand((item) => item.points.map((point) => point.value))
        .toList();
    final minValue = allValues.reduce(math.min);
    final maxValue = allValues.reduce(math.max);
    final span =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;

    _drawYAxisLabels(canvas, bounds, minValue, maxValue, span);
    _drawXAxisLabels(canvas, bounds);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(
        bounds.left, bounds.top, bounds.width * progress, bounds.height));

    for (final item in series) {
      final offsets = _offsetsFor(item, bounds, minValue, span);
      if (offsets.isEmpty) {
        continue;
      }

      final path = _smoothPath(offsets);
      final fillPath = Path.from(path)
        ..lineTo(offsets.last.dx, bounds.bottom)
        ..lineTo(offsets.first.dx, bounds.bottom)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = item.color.withValues(alpha: 0.055)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();

    if (hoverInfo != null) {
      final hover = hoverInfo!;
      final x = hover.position.dx;
      canvas.drawLine(
        Offset(x, bounds.top),
        Offset(x, bounds.bottom),
        Paint()
          ..color = _textSecondary.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        hover.position,
        4.5,
        Paint()..color = _surface,
      );
      canvas.drawCircle(
        hover.position,
        4.5,
        Paint()
          ..color = hover.series.color
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawYAxisLabels(
    Canvas canvas,
    Rect bounds,
    double minValue,
    double maxValue,
    double span,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      maxLines: 1,
      ellipsis: '…',
    );

    for (var index = 0; index <= 4; index++) {
      final y = bounds.top + bounds.height * index / 4;
      final value = maxValue - span * index / 4;
      textPainter.text = TextSpan(
        text: _axisMoneyLabel(value, displayCurrency),
        style: TextStyle(
          color: axisColor,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      );
      textPainter.layout(maxWidth: 62);
      textPainter.paint(
        canvas,
        Offset(bounds.left - textPainter.width - 9, y - textPainter.height / 2),
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, Rect bounds) {
    if (series.isEmpty || series.first.points.isEmpty) {
      return;
    }

    final points = series.first.points;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final xStep = points.length <= 1 ? 0.0 : bounds.width / (points.length - 1);
    final labelEvery = points.length <= 7 ? 1 : 2;

    for (var index = 0; index < points.length; index++) {
      if (index != 0 && index != points.length - 1 && index % labelEvery != 0) {
        continue;
      }

      textPainter.text = TextSpan(
        text: points[index].label,
        style: TextStyle(
          color: axisColor,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
      textPainter.layout(maxWidth: 46);
      final x = bounds.left + xStep * index - textPainter.width / 2;
      final clampedX =
          x.clamp(bounds.left - 4, bounds.right - textPainter.width + 4);
      textPainter.paint(canvas, Offset(clampedX.toDouble(), bounds.bottom + 8));
    }
  }

  List<Offset> _offsetsFor(
    _RwaSeries item,
    Rect bounds,
    double minValue,
    double span,
  ) {
    if (item.points.isEmpty) {
      return const [];
    }
    final xStep =
        item.points.length <= 1 ? 0.0 : bounds.width / (item.points.length - 1);
    return [
      for (var index = 0; index < item.points.length; index++)
        Offset(
          bounds.left + xStep * index,
          valueToY(bounds, item.points[index].value, minValue, span),
        ),
    ];
  }

  Path _smoothPath(List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    if (offsets.length == 1) {
      return path;
    }

    for (var index = 0; index < offsets.length - 1; index++) {
      final p0 = index == 0 ? offsets[index] : offsets[index - 1];
      final p1 = offsets[index];
      final p2 = offsets[index + 1];
      final p3 = index + 2 < offsets.length ? offsets[index + 2] : p2;
      final control1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final control2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        p2.dx,
        p2.dy,
      );
    }

    return path;
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
    final iconBox = _IconBox(icon: icon, color: color, size: 30);
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
                    color: _textPrimary.withValues(alpha: 0.94),
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
                        fontSize: 13,
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
                        fontWeight: FontWeight.w500,
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = _dashboardSurfaceSoftFor(context);
    final border = _dashboardBorderFor(context);
    final textColor = _dashboardTextFor(context);

    final pill = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _cyan),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
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
                                  _primary.withValues(alpha: 0.035),
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
              _textPrimary.withValues(alpha: 0.14),
              _textSecondary.withValues(alpha: 0.08),
              _border.withValues(alpha: 0.12),
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
              _textSecondary.withValues(alpha: 0.045),
              Colors.white.withValues(alpha: 0.52),
              _border.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0, 0.28, 0.48, 0.68, 1],
          ).createShader(foldRect),
      )
      ..drawLine(
        Offset(0, y),
        Offset(width, y),
        Paint()
          ..color = _border.withValues(alpha: 0.7)
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
      ..color = _border.withValues(alpha: 0.24 + emphasis * 0.08)
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
        ..color = _surfaceSoft.withValues(alpha: 0.96)
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
    required this.ead,
    required this.rwa,
    required this.capital,
  });

  final double grossAmount;
  final double ead;
  final double rwa;
  final double capital;

  factory _PortfolioKpiTotals.fromRows(List<PortfolioRow> rows) {
    return _PortfolioKpiTotals(
      grossAmount: rows.fold<double>(
        0,
        (sum, item) => sum + item.grossAmount,
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

String _money(double value, String displayCurrency) {
  return compactCurrencyForDisplay(value, toCurrency: displayCurrency);
}

String _axisMoneyLabel(double value, String displayCurrency) {
  return _money(value, displayCurrency)
      .replaceAll(' milliards ', ' Md ')
      .replaceAll(' billion ', ' Bn ')
      .replaceAll(' billions ', ' Bn ')
      .replaceAll(' million ', ' M ')
      .replaceAll(' millions ', ' M ')
      .replaceAll(' $displayCurrency', '')
      .trim();
}

String _cet1RatioAnalysis(double value) {
  final display = AppFormatters.percent(value);
  if (value <= 0) {
    return 'Le ratio CET1 n’est pas alimenté : aucune couverture en capital exploitable n’est observée sur cette lecture.';
  }
  if (value < 0.08) {
    return 'À $display, le ratio est inférieur au repère prudentiel interne de 8 %. La marge de capital est fragile.';
  }
  if (value < 0.105) {
    return 'À $display, le portefeuille couvre le socle prudentiel, mais la marge reste étroite face à une hausse des RWA.';
  }
  return 'À $display, la couverture est confortable : le portefeuille dispose d’une marge de capital plus robuste.';
}

String _cet1RatioImpact(double value) {
  if (value < 0.08) {
    return 'Impact négatif : limitation possible de la croissance des expositions, besoin de renforcer les fonds propres ou de réduire les actifs les plus pondérés.';
  }
  if (value < 0.105) {
    return 'Impact sous surveillance : une dégradation de qualité crédit ou une concentration plus forte peut rapidement consommer la marge disponible.';
  }
  return 'Impact favorable : meilleure capacité d’absorption des pertes et plus de souplesse pour piloter le portefeuille.';
}

String _leverageRatioAnalysis(double value) {
  final display = AppFormatters.percent(value);
  if (value <= 0) {
    return 'Le ratio de levier est nul : les fonds propres éligibles ne couvrent pas l’exposition totale dans cette vue.';
  }
  if (value < 0.03) {
    return 'À $display, le niveau est inférieur au repère usuel de 3 %. Le bilan apparaît trop levierisé.';
  }
  if (value < 0.06) {
    return 'À $display, le levier est acceptable mais demande un suivi rapproché si l’exposition totale progresse.';
  }
  return 'À $display, le ratio de levier est solide : l’exposition totale reste bien couverte par le capital disponible.';
}

String _leverageRatioImpact(double value) {
  if (value < 0.03) {
    return 'Impact négatif : risque de contrainte de bilan et pression possible pour augmenter les fonds propres ou réduire les expositions.';
  }
  if (value < 0.06) {
    return 'Impact modéré : la croissance du portefeuille doit rester cohérente avec le capital disponible.';
  }
  return 'Impact favorable : le portefeuille conserve une marge de bilan plus confortable, même sans pondération par le risque.';
}

String _totalExposureAnalysis(double value, String displayCurrency) {
  final display = _money(value, displayCurrency);
  if (value <= 0) {
    return 'Aucune exposition totale n’est détectée sur la base actuelle.';
  }
  return 'Le portefeuille porte $display d’exposition. Cette base indique la taille brute du risque avant lecture fine des pondérations.';
}

String _totalExposureImpact(double value) {
  if (value <= 0) {
    return 'Impact nul à ce stade : aucun volume ne vient alimenter les RWA ou le besoin en capital.';
  }
  return 'Impact structurel : plus l’exposition totale augmente, plus le portefeuille peut générer de RWA, même si la qualité des contreparties reste stable.';
}

String _offBalanceExposureAnalysis(
  double value,
  double totalExposure,
  String displayCurrency,
) {
  final display = _money(value, displayCurrency);
  if (value <= 0) {
    return 'Aucune exposition hors bilan n’est identifiée. Le risque latent lié aux engagements non tirés est limité dans cette vue.';
  }

  final share = totalExposure == 0 ? 0.0 : value / totalExposure;
  return 'Les engagements hors bilan représentent $display, soit ${AppFormatters.percent(share)} de l’exposition totale.';
}

String _offBalanceExposureImpact(double value) {
  if (value <= 0) {
    return 'Impact favorable : pas de pression additionnelle visible via les facteurs de conversion hors bilan.';
  }
  return 'Impact à surveiller : ces engagements peuvent être convertis en EAD via les CCF et augmenter les RWA si leur utilisation progresse.';
}

String _rwaDensityAnalysis(double value) {
  final display = AppFormatters.percent(value);
  if (value <= 0) {
    return 'La densité RWA est nulle : les expositions ne génèrent pas encore d’actifs pondérés dans cette lecture.';
  }
  if (value < 0.5) {
    return 'À $display, la densité est faible : le portefeuille consomme peu de RWA par unité d’exposition.';
  }
  if (value < 1) {
    return 'À $display, la densité est modérée : la charge en capital reste proportionnée à l’exposition.';
  }
  if (value < 1.5) {
    return 'À $display, la densité est élevée : les RWA dépassent l’exposition, signe d’un portefeuille fortement pondéré.';
  }
  return 'À $display, la densité est très élevée : les actifs pondérés excèdent largement l’exposition.';
}

String _rwaDensityImpact(double value) {
  if (value <= 0) {
    return 'Impact nul : aucune consommation de capital n’est matérialisée par les RWA.';
  }
  if (value < 1) {
    return 'Impact contenu : le portefeuille reste relativement efficient en capital, sous réserve de stabilité des notations et garanties.';
  }
  if (value < 1.5) {
    return 'Impact important : la consommation de capital est élevée et peut limiter la capacité de croissance du portefeuille.';
  }
  return 'Impact critique : priorité au pilotage des pondérations, des garanties et des concentrations pour réduire la pression sur le capital.';
}

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
