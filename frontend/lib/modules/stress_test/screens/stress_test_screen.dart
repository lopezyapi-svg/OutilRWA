// Ecran du module stress test.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Ecran de simulation des scenarios adverses.
class StressTestScreen extends StatefulWidget {
  const StressTestScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<StressTestScreen> createState() => _StressTestScreenState();
}

class _StressTestScreenState extends State<StressTestScreen> {
  String _selectedScenario = 'recession';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scenario = _getScenarioData(_selectedScenario);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Stress Test',
            subtitle: 'Simulation de chocs et scénarios adverses sur le portefeuille et le capital.',
            trailing: _buildScenarioSelector(isDark),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScenarioInfoSection(scenario, isDark),
                  const SizedBox(height: AppSpacing.md),
                  _buildImpactOverviewSection(scenario, isDark),
                  const SizedBox(height: AppSpacing.md),
                  _buildCategoryImpactSection(scenario, isDark),
                  const SizedBox(height: AppSpacing.md),
                  _buildCapitalAdequacySection(scenario, isDark),
                  const SizedBox(height: AppSpacing.md),
                  _buildScenarioComparisonSection(isDark),
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
      ('recession', 'Récession modérée'),
      ('sectoral', 'Crise sectorielle'),
      ('systemic', 'Crise systémique'),
      ('market', 'Choc de marché'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: scenarios.map((scenario) {
          final isSelected = _selectedScenario == scenario.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Material(
              color: isSelected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                onTap: () => setState(() => _selectedScenario = scenario.$1),
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    scenario.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? AppTheme.darkText : AppTheme.text),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScenarioInfoSection(_StressScenario scenario, bool isDark) {
    return SectionCard(
      title: 'Configuration du scénario',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.severityColor(scenario.severity).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  scenario.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.severityColor(scenario.severity),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  scenario.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildParameterChip('Impact RWA', '+${(scenario.rwaImpact * 100).toStringAsFixed(0)}%', isDark),
              _buildParameterChip('Hausse NPL', '+${(scenario.nplIncrease * 100).toStringAsFixed(0)}%', isDark),
              _buildParameterChip('Impact PIB', '${(scenario.gdpImpact * 100).toStringAsFixed(1)}%', isDark),
              if (scenario.spreadIncrease > 0)
                _buildParameterChip('Spreads', '+${scenario.spreadIncrease} bps', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactOverviewSection(_StressScenario scenario, bool isDark) {
    const baseCapital = 58000000000.0;
    const baseRwa = 420000000000.0;
    const baseRatio = baseCapital / baseRwa;

    final stressedRwa = baseRwa * (1 + scenario.rwaImpact);
    final stressedRatio = baseCapital / stressedRwa;
    final capitalGap = stressedRatio < 0.105 ? (stressedRwa * 0.105 - baseCapital) : 0.0;

    return SectionCard(
      title: 'Vue d\'ensemble de l\'impact',
      child: Row(
        children: [
          Expanded(
            child: _buildImpactMetricCard(
              label: 'RWA stressé',
              baseValue: baseRwa,
              stressedValue: stressedRwa,
              icon: CupertinoIcons.chart_bar_square_fill,
              color: AppColors.accent,
              isDark: isDark,
              format: 'currency',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildImpactMetricCard(
              label: 'Impact RWA',
              baseValue: 0,
              stressedValue: stressedRwa - baseRwa,
              icon: CupertinoIcons.arrow_up_circle_fill,
              color: AppColors.danger,
              isDark: isDark,
              format: 'currency',
              showDelta: false,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildImpactMetricCard(
              label: 'Ratio de solvabilité',
              baseValue: baseRatio,
              stressedValue: stressedRatio,
              icon: CupertinoIcons.gauge,
              color: stressedRatio >= 0.105 ? AppColors.success : AppColors.danger,
              isDark: isDark,
              format: 'percent',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildImpactMetricCard(
              label: 'Déficit de capital',
              baseValue: 0,
              stressedValue: capitalGap,
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              color: capitalGap > 0 ? AppColors.danger : AppColors.success,
              isDark: isDark,
              format: 'currency',
              showDelta: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMetricCard({
    required String label,
    required double baseValue,
    required double stressedValue,
    required IconData icon,
    required Color color,
    required bool isDark,
    required String format,
    bool showDelta = true,
  }) {
    final formattedValue = format == 'percent'
        ? AppFormatters.percent(stressedValue)
        : AppFormatters.currency(stressedValue);

    final delta = showDelta && baseValue > 0 ? ((stressedValue - baseValue) / baseValue) : 0.0;
    final deltaText = showDelta && baseValue > 0
        ? '${delta >= 0 ? '+' : ''}${(delta * 100).toStringAsFixed(1)}%'
        : '';

    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedValue,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
          if (showDelta && deltaText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              deltaText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: delta >= 0 ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryImpactSection(_StressScenario scenario, bool isDark) {
    final categories = _getCategoryImpacts(scenario);

    return SectionCard(
      title: 'Impact par catégorie prudentielle',
      child: Column(
        children: categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCategoryImpactRow(cat, isDark),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryImpactRow(_CategoryImpact impact, bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            impact.category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            AppFormatters.currency(impact.baseRwa),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            AppFormatters.currency(impact.stressedRwa),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '+${(impact.impactPercent * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapitalAdequacySection(_StressScenario scenario, bool isDark) {
    const baseCapital = 58000000000.0;
    const baseRwa = 420000000000.0;
    const baseRatio = baseCapital / baseRwa;
    final stressedRwa = baseRwa * (1 + scenario.rwaImpact);
    final stressedRatio = baseCapital / stressedRwa;

    return SectionCard(
      title: 'Adéquation du capital',
      child: Row(
        children: [
          Expanded(
            child: _buildRatioComparison(
              label: 'Scénario de base',
              ratio: baseRatio,
              isDark: isDark,
              isStressed: false,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Icon(
            CupertinoIcons.arrow_right,
            color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: _buildRatioComparison(
              label: 'Sous stress',
              ratio: stressedRatio,
              isDark: isDark,
              isStressed: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioComparison({
    required String label,
    required double ratio,
    required bool isDark,
    required bool isStressed,
  }) {
    final isCompliant = ratio >= 0.105;
    final color = isCompliant ? AppColors.success : AppColors.danger;

    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isStressed ? color.withValues(alpha: 0.4) : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isStressed ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppFormatters.percent(ratio),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: isStressed ? color : (isDark ? AppTheme.darkText : AppTheme.text),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              isCompliant ? 'Conforme' : 'Non conforme',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (ratio / 0.15).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seuil: 10.5%',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioComparisonSection(bool isDark) {
    final scenarios = ['recession', 'sectoral', 'systemic', 'market']
        .map((id) => _getScenarioData(id))
        .toList();

    const baseCapital = 58000000000.0;
    const baseRwa = 420000000000.0;

    return SectionCard(
      title: 'Comparaison des scénarios',
      child: SizedBox(
        height: 300,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: scenarios.map((scenario) {
            final stressedRwa = baseRwa * (1 + scenario.rwaImpact);
            final stressedRatio = baseCapital / stressedRwa;
            final isCompliant = stressedRatio >= 0.105;
            final color = isCompliant ? AppColors.success : AppColors.danger;
            final height = (stressedRatio / 0.15 * 250).clamp(20.0, 250.0);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.percent(stressedRatio),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.7)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scenario.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkText : AppTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  _StressScenario _getScenarioData(String id) {
    switch (id) {
      case 'recession':
        return _StressScenario(
          id: 'recession',
          name: 'Récession modérée',
          description: 'Ralentissement économique avec hausse modérée des défauts',
          severity: 'medium',
          rwaImpact: 0.15,
          nplIncrease: 0.03,
          gdpImpact: -0.02,
          spreadIncrease: 0,
        );
      case 'sectoral':
        return _StressScenario(
          id: 'sectoral',
          name: 'Crise sectorielle',
          description: 'Effondrement d\'un secteur clé (immobilier, énergie)',
          severity: 'high',
          rwaImpact: 0.35,
          nplIncrease: 0.08,
          gdpImpact: -0.035,
          spreadIncrease: 150,
        );
      case 'systemic':
        return _StressScenario(
          id: 'systemic',
          name: 'Crise systémique',
          description: 'Choc économique majeur affectant tous les secteurs',
          severity: 'critical',
          rwaImpact: 0.55,
          nplIncrease: 0.15,
          gdpImpact: -0.05,
          spreadIncrease: 300,
        );
      case 'market':
        return _StressScenario(
          id: 'market',
          name: 'Choc de marché',
          description: 'Hausse brutale des taux et volatilité des marchés',
          severity: 'high',
          rwaImpact: 0.25,
          nplIncrease: 0.05,
          gdpImpact: -0.015,
          spreadIncrease: 200,
        );
      default:
        return _getScenarioData('recession');
    }
  }

  List<_CategoryImpact> _getCategoryImpacts(_StressScenario scenario) {
    const baseRwa = 420000000000.0;
    final categories = {
      'Administrations centrales': 0.15,
      'Banques': 0.12,
      'Entreprises': 0.45,
      'Crédits immobiliers': 0.18,
      'Autres expositions': 0.10,
    };

    return categories.entries.map((entry) {
      final baseAmount = baseRwa * entry.value;
      final impact = scenario.rwaImpact * (entry.key == 'Entreprises' ? 1.2 : entry.key == 'Crédits immobiliers' ? 1.3 : 1.0);
      final stressedAmount = baseAmount * (1 + impact);

      return _CategoryImpact(
        category: entry.key,
        baseRwa: baseAmount,
        stressedRwa: stressedAmount,
        impactPercent: impact,
      );
    }).toList();
  }
}

class _StressScenario {
  final String id;
  final String name;
  final String description;
  final String severity;
  final double rwaImpact;
  final double nplIncrease;
  final double gdpImpact;
  final int spreadIncrease;

  _StressScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.severity,
    required this.rwaImpact,
    required this.nplIncrease,
    required this.gdpImpact,
    required this.spreadIncrease,
  });
}

class _CategoryImpact {
  final String category;
  final double baseRwa;
  final double stressedRwa;
  final double impactPercent;

  _CategoryImpact({
    required this.category,
    required this.baseRwa,
    required this.stressedRwa,
    required this.impactPercent,
  });
}
