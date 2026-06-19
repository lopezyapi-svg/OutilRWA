// Ecran d'analyse stratégique et recommandations.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../shared/widgets/page_header.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../models/analyse_models.dart';
import '../services/analyse_service.dart';
import '../widgets/analyse_chart_card.dart';
import '../widgets/analyse_insight_card.dart';
import '../widgets/analyse_kpi_row.dart';
import '../widgets/analyse_recommendation_card.dart';

/// Ecran d'analyse et recommandations.
class AnalyseScreen extends StatefulWidget {
  const AnalyseScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<AnalyseScreen> createState() => _AnalyseScreenState();
}

class _AnalyseScreenState extends State<AnalyseScreen> {
  late AnalyseService _service;
  late Future<AnalyseData> _future;
  StreamSubscription<int>? _portfolioSubscription;
  String _selectedView = 'all'; // all, portfolio, risk, optimization

  @override
  void initState() {
    super.initState();
    _service = AnalyseService(widget.api);
    _future = _service.fetchAnalyseData();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _future = _service.fetchAnalyseData();
      });
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyseData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur: ${snapshot.error}'),
          );
        }

        final data = snapshot.data!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: AppSpacing.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Analyse & Recommandations',
                subtitle: 'Insights et actions pour optimiser votre portefeuille',
                trailing: _buildViewSelector(isDark),
              ),
              AppSpacing.gapLg,

              // KPIs principaux
              _buildKpiSection(data, isDark),
              AppSpacing.gapLg,

              // Contenu selon la vue sélectionnée
              if (_selectedView == 'all' || _selectedView == 'portfolio')
                ..._buildPortfolioAnalysis(data, isDark),

              if (_selectedView == 'all' || _selectedView == 'risk')
                ..._buildRiskAnalysis(data, isDark),

              if (_selectedView == 'all' || _selectedView == 'optimization')
                ..._buildOptimizationSection(data, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewSelector(bool isDark) {
    final views = [
      ('all', 'Vue complète', Icons.dashboard),
      ('portfolio', 'Portefeuille', Icons.pie_chart),
      ('risk', 'Risques', Icons.warning_amber_rounded),
      ('optimization', 'Optimisation', Icons.lightbulb_outline),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: views.map((view) {
          final isSelected = _selectedView == view.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Material(
              color: isSelected
                  ? AppColors.accent
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                onTap: () => setState(() => _selectedView = view.$1),
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        view.$3,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppTheme.darkMuted : AppTheme.muted),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        view.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppTheme.darkText : AppTheme.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiSection(AnalyseData data, bool isDark) {
    return AnalyseKpiRow(
      kpis: [
        AnalyseKpi(
          label: 'Qualité portefeuille',
          value: data.portfolioQualityScore.toStringAsFixed(1),
          suffix: '/10',
          icon: Icons.star,
          color: _qualityColor(data.portfolioQualityScore),
          trend: data.qualityTrend,
        ),
        AnalyseKpi(
          label: 'Concentration',
          value: '${(data.concentrationLevel * 100).toStringAsFixed(0)}%',
          icon: Icons.donut_small,
          color: _concentrationColor(data.concentrationLevel),
          trend: data.concentrationTrend,
        ),
        AnalyseKpi(
          label: 'Couverture CRM',
          value: '${(data.crmCoverageRatio * 100).toStringAsFixed(1)}%',
          icon: Icons.shield,
          color: AppColors.success,
          trend: data.crmTrend,
        ),
        AnalyseKpi(
          label: 'Potentiel réduction',
          value: formatCurrencyCompact(data.rwaReductionPotential),
          icon: Icons.trending_down,
          color: AppColors.accent,
          trend: 'up',
        ),
      ],
    );
  }

  Color _qualityColor(double score) {
    if (score >= 8) return AppColors.qualityExcellent;
    if (score >= 6.5) return AppColors.qualityGood;
    if (score >= 5) return AppColors.qualityAverage;
    if (score >= 3.5) return AppColors.qualityFair;
    return AppColors.qualityPoor;
  }

  Color _concentrationColor(double level) {
    if (level >= 0.4) return AppColors.danger;
    if (level >= 0.25) return AppColors.warning;
    return AppColors.success;
  }

  List<Widget> _buildPortfolioAnalysis(AnalyseData data, bool isDark) {
    return [
      _buildSectionTitle('Analyse du portefeuille', isDark),
      AppSpacing.gapMd,

      // Distribution et concentration
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnalyseChartCard(
              title: 'Distribution par secteur',
              chart: _buildPieChart(data.sectorDistribution, isDark),
              insights: data.sectorInsights,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: AnalyseChartCard(
              title: 'Distribution par notation',
              chart: _buildBarChart(data.ratingDistribution, isDark),
              insights: data.ratingInsights,
            ),
          ),
        ],
      ),
      AppSpacing.gapMd,

      // Insights clés
      AnalyseInsightCard(
        title: 'Observations clés',
        insights: [
          if (data.topConcentration != null)
            AnalyseInsight(
              icon: Icons.warning_amber,
              severity: 'high',
              message:
                  'Concentration excessive sur ${data.topConcentration!.label}: ${(data.topConcentration!.percentage * 100).toStringAsFixed(1)}%',
              recommendation:
                  'Diversifier les expositions pour réduire le risque de concentration',
            ),
          if (data.lowRatedExposure > 0.15)
            AnalyseInsight(
              icon: Icons.trending_down,
              severity: 'medium',
              message:
                  'Exposition significative aux notations spéculatives: ${(data.lowRatedExposure * 100).toStringAsFixed(1)}%',
              recommendation:
                  'Renforcer les garanties ou réduire progressivement ces expositions',
            ),
          if (data.weightedAverageRating != null)
            AnalyseInsight(
              icon: Icons.assessment,
              severity: 'info',
              message:
                  'Notation moyenne pondérée du portefeuille: ${data.weightedAverageRating}',
              recommendation:
                  'Qualité globale ${_ratingQuality(data.weightedAverageRating!)}',
            ),
        ],
      ),
      AppSpacing.gapLg,
    ];
  }

  List<Widget> _buildRiskAnalysis(AnalyseData data, bool isDark) {
    return [
      _buildSectionTitle('Analyse des risques', isDark),
      AppSpacing.gapMd,

      // Évolution RWA et alertes
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AnalyseChartCard(
              title: 'Évolution du RWA',
              chart: _buildTrendChart(data.rwaEvolution, isDark),
              insights: [
                'Variation sur 12 mois: ${data.rwaVariation >= 0 ? '+' : ''}${(data.rwaVariation * 100).toStringAsFixed(1)}%',
                'Capital requis: ${formatCurrencyCompact(data.currentCapital)}',
              ],
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: AnalyseInsightCard(
              title: 'Alertes prudentielles',
              insights: data.prudentialAlerts.map((alert) {
                return AnalyseInsight(
                  icon: _alertIcon(alert.severity),
                  severity: alert.severity,
                  message: alert.message,
                  recommendation: alert.action,
                );
              }).toList(),
            ),
          ),
        ],
      ),
      AppSpacing.gapMd,

      // Top expositions à risque
      _buildTopRiskExposures(data, isDark),
      AppSpacing.gapLg,
    ];
  }

  List<Widget> _buildOptimizationSection(AnalyseData data, bool isDark) {
    return [
      _buildSectionTitle('Recommandations d\'optimisation', isDark),
      AppSpacing.gapMd,

      // Recommandations actionnables
      ...data.recommendations.map((rec) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnalyseRecommendationCard(
            recommendation: rec,
          ),
        );
      }),

      if (data.recommendations.isEmpty)
        _buildEmptyRecommendations(isDark),
    ];
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? AppTheme.darkText : AppTheme.text,
      ),
    );
  }

  Widget _buildPieChart(List<DistributionEntry> data, bool isDark) {
    if (data.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          'Graphique circulaire - Distribution',
          style: TextStyle(
            color: isDark ? AppTheme.darkMuted : AppTheme.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<DistributionEntry> data, bool isDark) {
    if (data.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: data.take(5).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: entry.percentage.clamp(0.0, 1.0),
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  AppColors.accent.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${(entry.percentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkText : AppTheme.text,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrendChart(List<RwaEvolutionPoint> data, bool isDark) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minValue = data.map((p) => p.value).reduce((a, b) => a < b ? a : b);

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CustomPaint(
          painter: _TrendChartPainter(
            data: data,
            maxValue: maxValue,
            minValue: minValue,
            isDark: isDark,
          ),
          child: Container(),
        ),
      ),
    );
  }

  Widget _buildTopRiskExposures(AnalyseData data, bool isDark) {
    if (data.topRiskExposures.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 10 expositions à fort RWA',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
          AppSpacing.gapMd,
          ...data.topRiskExposures.take(10).map((exposure) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      exposure.counterparty,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkText : AppTheme.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatCurrencyCompact(exposure.rwa),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ratingColor(exposure.rating)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      exposure.rating,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ratingColor(exposure.rating),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyRecommendations(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppColors.success,
            ),
            AppSpacing.gapMd,
            Text(
              'Aucune recommandation critique',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkText : AppTheme.text,
              ),
            ),
            AppSpacing.gapSm,
            Text(
              'Votre portefeuille est bien optimisé',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkMuted : AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _alertIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      default:
        return Icons.info_outline;
    }
  }

  String _ratingQuality(String rating) {
    final r = rating.toUpperCase();
    if (r.startsWith('AAA') || r.startsWith('AA')) return 'excellente';
    if (r.startsWith('A')) return 'très bonne';
    if (r.startsWith('BBB')) return 'bonne';
    if (r.startsWith('BB') || r.startsWith('B')) return 'acceptable';
    return 'à surveiller';
  }
}

// Painter pour le graphique de tendance
class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
    required this.isDark,
  });

  final List<RwaEvolutionPoint> data;
  final double maxValue;
  final double minValue;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final range = maxValue - minValue;
    if (range == 0) return;

    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accent.withValues(alpha: 0.2),
          AppColors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedValue = (data[i].value - minValue) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

