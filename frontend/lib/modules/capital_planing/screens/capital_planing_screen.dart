// Ecran du module capital planing.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Ecran de projection du capital.
class CapitalPlaningScreen extends StatefulWidget {
  const CapitalPlaningScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<CapitalPlaningScreen> createState() => _CapitalPlaningScreenState();
}

class _CapitalPlaningScreenState extends State<CapitalPlaningScreen> {
  String _selectedScenario = 'base';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Capital Planning',
            subtitle:
                'Projection du capital, des besoins prudentiels et des marges de manoeuvre.',
            trailing: _buildScenarioSelector(isDark),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKpiSection(isDark),
                  const SizedBox(height: AppSpacing.pageGap),
                  _buildProjectionChart(isDark),
                  const SizedBox(height: AppSpacing.pageGap),
                  _buildYearlyTable(isDark),
                  const SizedBox(height: AppSpacing.pageGap),
                  _buildGapAnalysisSection(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector(bool isDark) {
    final scenarios = [
      ('base', 'Base', CupertinoIcons.chart_bar_fill),
      ('optimistic', 'Optimiste', CupertinoIcons.arrow_up_circle_fill),
      ('pessimistic', 'Pessimiste', CupertinoIcons.arrow_down_circle_fill),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2742) : const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3F5F) : const Color(0xFFE0E7F5),
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: scenarios.map((scenario) {
          final isSelected = _selectedScenario == scenario.$1;
          return GestureDetector(
            onTap: () => setState(() => _selectedScenario = scenario.$1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    scenario.$3,
                    size: 14,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppTheme.darkMuted : AppTheme.muted),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    scenario.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppTheme.darkMuted : AppTheme.muted),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiSection(bool isDark) {
    final data = _getProjectionData();
    final currentYear = data.first;

    return SectionCard(
      title: 'Indicateurs clés de projection',
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              context: context,
              label: 'Capital actuel',
              value: AppFormatters.currency(currentYear.capital),
              icon: CupertinoIcons.money_dollar_circle_fill,
              color: AppColors.prudentialCapital,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: _buildMetricCard(
              context: context,
              label: 'RWA actuel',
              value: AppFormatters.currency(currentYear.rwa),
              icon: CupertinoIcons.shield_lefthalf_fill,
              color: AppColors.accent,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: _buildMetricCard(
              context: context,
              label: 'Ratio de solvabilité',
              value: AppFormatters.percent(currentYear.ratio),
              icon: CupertinoIcons.chart_pie_fill,
              color: currentYear.ratio >= 0.105
                  ? AppColors.success
                  : AppColors.danger,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: _buildMetricCard(
              context: context,
              label: 'Projection 5 ans',
              value: '${data.last.year}',
              icon: CupertinoIcons.calendar,
              color: AppColors.prudentialSolvency,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkText : AppTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionChart(bool isDark) {
    final data = _getProjectionData();

    return SectionCard(
      title: 'Projection du capital sur 5 ans',
      child: SizedBox(
        height: 280,
        child: CustomPaint(
          painter: _CapitalProjectionChartPainter(
            data: data,
            isDark: isDark,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildYearlyTable(bool isDark) {
    final data = _getProjectionData();

    return SectionCard(
      title: 'Détail année par année',
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(80),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FixedColumnWidth(100),
          5: FlexColumnWidth(1),
        },
        children: [
          _buildTableHeader(isDark),
          ...data.map((item) => _buildTableRow(item, isDark)),
        ],
      ),
    );
  }

  TableRow _buildTableHeader(bool isDark) {
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: isDark ? AppTheme.darkText : AppTheme.text,
    );

    return TableRow(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2742) : const Color(0xFFF5F8FF),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Année', style: headerStyle),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Capital', style: headerStyle),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('RWA', style: headerStyle),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Croissance RWA', style: headerStyle),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Ratio', style: headerStyle),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Statut', style: headerStyle),
        ),
      ],
    );
  }

  TableRow _buildTableRow(_ProjectionYear item, bool isDark) {
    final textColor = isDark ? AppTheme.darkText : AppTheme.text;
    final isCompliant = item.ratio >= 0.105;

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: (isDark ? AppTheme.darkBorder : AppTheme.border)
                .withValues(alpha: 0.3),
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${item.year}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            AppFormatters.currency(item.capital),
            style: TextStyle(fontSize: 13, color: textColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            AppFormatters.currency(item.rwa),
            style: TextStyle(fontSize: 13, color: textColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            AppFormatters.percent(item.rwaGrowth),
            style: TextStyle(
              fontSize: 13,
              color: item.rwaGrowth > 0.1
                  ? AppColors.warning
                  : AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            AppFormatters.percent(item.ratio),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isCompliant ? AppColors.success : AppColors.danger,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildStatusBadge(
            isCompliant ? 'Conforme' : 'Déficit',
            isCompliant ? AppColors.success : AppColors.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGapAnalysisSection(bool isDark) {
    final data = _getProjectionData();
    final deficitYears = data.where((y) => y.ratio < 0.105).toList();
    final hasDeficit = deficitYears.isNotEmpty;

    return SectionCard(
      title: 'Analyse des besoins en capital',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  title: 'Seuil minimum réglementaire',
                  value: '10.5%',
                  icon: CupertinoIcons.shield_fill,
                  color: AppColors.prudentialCompliance,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: _buildInfoCard(
                  title: 'Années en déficit',
                  value: '${ deficitYears.length} / 5',
                  icon: CupertinoIcons.exclamationmark_triangle_fill,
                  color: hasDeficit ? AppColors.danger : AppColors.success,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: _buildInfoCard(
                  title: 'Capital gap total',
                  value: AppFormatters.currency(_calculateTotalGap(data)),
                  icon: CupertinoIcons.arrow_up_circle_fill,
                  color: AppColors.warning,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (hasDeficit) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.lightbulb_fill,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recommandations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkText : AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._buildRecommendations(deficitYears, isDark),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    size: 20,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le capital projeté reste au-dessus du seuil minimum réglementaire sur toute la période.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkText : AppTheme.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2742) : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecommendations(
    List<_ProjectionYear> deficitYears,
    bool isDark,
  ) {
    final recommendations = <Widget>[];

    for (final year in deficitYears) {
      final gap = _calculateGap(year);
      recommendations.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkText : AppTheme.text,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Année ${year.year}: ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                        text: 'Injection de capital recommandée de ',
                      ),
                      TextSpan(
                        text: AppFormatters.currency(gap),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' pour atteindre le ratio minimum de 10.5% (ratio projeté: ${AppFormatters.percent(year.ratio)}).',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return recommendations;
  }

  List<_ProjectionYear> _getProjectionData() {
    // Base year 2024
    const baseYear = 2024;
    const baseCapital = 58000000000.0; // 58B FCFA
    const baseRWA = 420000000000.0; // 420B FCFA

    final growthRate = switch (_selectedScenario) {
      'optimistic' => 0.05,
      'pessimistic' => 0.15,
      _ => 0.08,
    };

    final projections = <_ProjectionYear>[];

    for (var i = 0; i < 5; i++) {
      final year = baseYear + i;
      final rwa = baseRWA * math.pow(1 + growthRate, i);
      final capital = baseCapital; // Capital stable
      final ratio = capital / rwa;

      projections.add(
        _ProjectionYear(
          year: year,
          capital: capital,
          rwa: rwa,
          ratio: ratio,
          rwaGrowth: growthRate,
        ),
      );
    }

    return projections;
  }

  double _calculateGap(_ProjectionYear year) {
    const minRatio = 0.105;
    final requiredCapital = year.rwa * minRatio;
    return math.max(0, requiredCapital - year.capital);
  }

  double _calculateTotalGap(List<_ProjectionYear> data) {
    return data.fold(0.0, (sum, year) => sum + _calculateGap(year));
  }
}

class _ProjectionYear {
  final int year;
  final double capital;
  final double rwa;
  final double ratio;
  final double rwaGrowth;

  _ProjectionYear({
    required this.year,
    required this.capital,
    required this.rwa,
    required this.ratio,
    required this.rwaGrowth,
  });
}

class _CapitalProjectionChartPainter extends CustomPainter {
  final List<_ProjectionYear> data;
  final bool isDark;

  _CapitalProjectionChartPainter({
    required this.data,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padding = 50.0;
    const leftPadding = 80.0;
    const bottomPadding = 40.0;
    final chartWidth = size.width - leftPadding - padding;
    final chartHeight = size.height - padding - bottomPadding;

    // Find min/max for scaling
    final ratios = data.map((d) => d.ratio).toList();
    final maxRatio = ratios.reduce(math.max);
    final minRatio = ratios.reduce(math.min);
    const thresholdRatio = 0.105;

    final minY = math.min(minRatio, thresholdRatio) * 0.95;
    final maxY = math.max(maxRatio, thresholdRatio) * 1.05;

    // Draw axes
    final axisPaint = Paint()
      ..color = (isDark ? AppTheme.darkBorder : AppTheme.border)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(leftPadding, padding),
      Offset(leftPadding, padding + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftPadding, padding + chartHeight),
      Offset(leftPadding + chartWidth, padding + chartHeight),
      axisPaint,
    );

    // Draw threshold line (10.5%)
    final thresholdY = padding +
        chartHeight * (1 - (thresholdRatio - minY) / (maxY - minY));
    final thresholdPaint = Paint()
      ..color = AppColors.danger.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final thresholdPath = Path();
    for (var i = 0; i < 10; i++) {
      final x = leftPadding + (chartWidth / 10) * i;
      if (i % 2 == 0) {
        thresholdPath.moveTo(x, thresholdY);
      } else {
        thresholdPath.lineTo(x, thresholdY);
      }
    }
    canvas.drawPath(thresholdPath, thresholdPaint);

    // Draw threshold label
    final thresholdTextPainter = TextPainter(
      text: TextSpan(
        text: 'Seuil 10.5%',
        style: TextStyle(
          color: AppColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    thresholdTextPainter.layout();
    thresholdTextPainter.paint(
      canvas,
      Offset(leftPadding + chartWidth - 80, thresholdY - 18),
    );

    // Draw capital ratio line
    final linePaint = Paint()
      ..color = AppColors.prudentialCapital
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    for (var i = 0; i < data.length; i++) {
      final x = leftPadding + (chartWidth / (data.length - 1)) * i;
      final y = padding +
          chartHeight * (1 - (data[i].ratio - minY) / (maxY - minY));

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Draw points
    for (var i = 0; i < data.length; i++) {
      final x = leftPadding + (chartWidth / (data.length - 1)) * i;
      final y =
          padding + chartHeight * (1 - (data[i].ratio - minY) / (maxY - minY));

      final pointColor =
          data[i].ratio >= thresholdRatio ? AppColors.success : AppColors.danger;

      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = pointColor,
      );

      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = Colors.white,
      );

      // Draw year labels
      final yearTextPainter = TextPainter(
        text: TextSpan(
          text: '${data[i].year}',
          style: TextStyle(
            color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      yearTextPainter.layout();
      yearTextPainter.paint(
        canvas,
        Offset(x - yearTextPainter.width / 2, padding + chartHeight + 10),
      );

      // Draw ratio labels on points
      final ratioTextPainter = TextPainter(
        text: TextSpan(
          text: '${(data[i].ratio * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: pointColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      ratioTextPainter.layout();
      ratioTextPainter.paint(
        canvas,
        Offset(x - ratioTextPainter.width / 2, y - 22),
      );
    }

    // Draw Y-axis labels
    final numYLabels = 5;
    for (var i = 0; i <= numYLabels; i++) {
      final ratio = minY + (maxY - minY) * (i / numYLabels);
      final y = padding + chartHeight * (1 - i / numYLabels);

      final labelTextPainter = TextPainter(
        text: TextSpan(
          text: '${(ratio * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      labelTextPainter.layout();
      labelTextPainter.paint(
        canvas,
        Offset(leftPadding - labelTextPainter.width - 10, y - 8),
      );

      // Draw grid line
      final gridPaint = Paint()
        ..color = (isDark ? AppTheme.darkBorder : AppTheme.border)
            .withValues(alpha: 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
