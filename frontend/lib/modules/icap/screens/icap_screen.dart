// Ecran du module ICAP - Internal Capital Adequacy Assessment Process.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Ecran d'evaluation interne du capital (ICAAP).
/// Conforme aux exigences Bâle III et dispositif prudentiel BCEAO/UMOA.
class IcapScreen extends StatefulWidget {
  const IcapScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<IcapScreen> createState() => _IcapScreenState();
}

class _IcapScreenState extends State<IcapScreen> {
  String _selectedScenario = 'base';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'ICAAP',
            subtitle:
                'Evaluation interne de l\'adéquation du capital et des besoins de solvabilité',
            trailing: _buildScenarioSelector(isDark),
          ),
          AppSpacing.gapLg,
          _buildCapitalOverviewSection(isDark),
          AppSpacing.gapMd,
          _buildPrudentialRequirementsSection(isDark),
          AppSpacing.gapMd,
          _buildRegulatoryRatiosSection(isDark),
          AppSpacing.gapMd,
          _buildStressSimulationSection(isDark),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector(bool isDark) {
    final scenarios = [
      ('base', 'Scénario de base'),
      ('adverse', 'Scénario adverse'),
      ('severe', 'Scénario sévère'),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    scenario.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppTheme.darkText : AppTheme.text),
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

  Widget _buildCapitalOverviewSection(bool isDark) {
    final data = _getCapitalData();

    return SectionCard(
      title: 'Vue d\'ensemble du capital',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCapitalMetricCard(
                  label: 'Fonds propres CET1',
                  value: data.cet1Capital,
                  icon: CupertinoIcons.checkmark_shield_fill,
                  color: AppColors.prudentialCapital,
                  isDark: isDark,
                  helper: 'Noyau dur des fonds propres',
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: _buildCapitalMetricCard(
                  label: 'Fonds propres Tier 1',
                  value: data.tier1Capital,
                  icon: CupertinoIcons.building_2_fill,
                  color: AppColors.prudentialTier,
                  isDark: isDark,
                  helper: 'CET1 + fonds propres additionnels',
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: _buildCapitalMetricCard(
                  label: 'Fonds propres totaux',
                  value: data.totalCapital,
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  color: AppColors.prudentialSolvency,
                  isDark: isDark,
                  helper: 'Tier 1 + Tier 2',
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: _buildCapitalMetricCard(
                  label: 'RWA total',
                  value: data.totalRwa,
                  icon: CupertinoIcons.chart_bar_square_fill,
                  color: AppColors.accent,
                  isDark: isDark,
                  helper: 'Actifs pondérés aux risques',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrudentialRequirementsSection(bool isDark) {
    final data = _getCapitalData();
    final requirements = data.requirements;

    return SectionCard(
      title: 'Exigences prudentielles détaillées',
      child: Column(
        children: [
          _buildRequirementRow(
            label: 'Pilier 1: Risque de crédit',
            required: requirements.creditRiskCapital,
            available: data.totalCapital * 0.85,
            percentage: requirements.creditRiskCapital / data.totalRwa,
            isDark: isDark,
          ),
          AppSpacing.vGapSm,
          _buildRequirementRow(
            label: 'Pilier 1: Risque de marché',
            required: requirements.marketRiskCapital,
            available: data.totalCapital * 0.08,
            percentage: requirements.marketRiskCapital / data.totalRwa,
            isDark: isDark,
          ),
          AppSpacing.vGapSm,
          _buildRequirementRow(
            label: 'Pilier 1: Risque opérationnel',
            required: requirements.operationalRiskCapital,
            available: data.totalCapital * 0.07,
            percentage: requirements.operationalRiskCapital / data.totalRwa,
            isDark: isDark,
          ),
          AppSpacing.vGapMd,
          Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          AppSpacing.vGapMd,
          _buildRequirementRow(
            label: 'Capital minimum (8%)',
            required: data.totalRwa * 0.08,
            available: data.totalCapital,
            percentage: 0.08,
            isDark: isDark,
            isTotal: true,
          ),
          AppSpacing.vGapSm,
          _buildRequirementRow(
            label: 'Coussin de conservation (2.5%)',
            required: data.totalRwa * 0.025,
            available: data.totalCapital - (data.totalRwa * 0.08),
            percentage: 0.025,
            isDark: isDark,
          ),
          AppSpacing.vGapSm,
          _buildRequirementRow(
            label: 'Coussin contracyclique (0-2.5%)',
            required: data.totalRwa * requirements.countercyclicalBuffer,
            available: data.totalCapital - (data.totalRwa * 0.105),
            percentage: requirements.countercyclicalBuffer,
            isDark: isDark,
          ),
          AppSpacing.vGapMd,
          Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          AppSpacing.vGapMd,
          _buildRequirementRow(
            label: 'Total requis (avec coussins)',
            required: data.totalRwa * requirements.totalRequiredRatio,
            available: data.totalCapital,
            percentage: requirements.totalRequiredRatio,
            isDark: isDark,
            isTotal: true,
            isFinal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRegulatoryRatiosSection(bool isDark) {
    final data = _getCapitalData();
    final ratios = data.ratios;

    return SectionCard(
      title: 'Ratios réglementaires',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildRatioGauge(
                  label: 'Ratio CET1',
                  value: ratios.cet1Ratio,
                  minimum: 0.045,
                  target: 0.07,
                  isDark: isDark,
                  helper: 'Minimum: 4.5% | Cible: 7%+',
                ),
              ),
              AppSpacing.hGapLg,
              Expanded(
                child: _buildRatioGauge(
                  label: 'Ratio Tier 1',
                  value: ratios.tier1Ratio,
                  minimum: 0.06,
                  target: 0.085,
                  isDark: isDark,
                  helper: 'Minimum: 6% | Cible: 8.5%+',
                ),
              ),
              AppSpacing.hGapLg,
              Expanded(
                child: _buildRatioGauge(
                  label: 'Ratio de solvabilité global',
                  value: ratios.totalCapitalRatio,
                  minimum: 0.08,
                  target: 0.105,
                  isDark: isDark,
                  helper: 'Minimum: 8% | Cible: 10.5%+',
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          Row(
            children: [
              Expanded(
                child: _buildAdditionalMetric(
                  label: 'Ratio de levier',
                  value: ratios.leverageRatio,
                  format: 'percent',
                  icon: Icons.account_balance,
                  color: AppColors.prudentialLeverage,
                  isDark: isDark,
                  helper: 'Tier 1 / Exposition totale',
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: _buildAdditionalMetric(
                  label: 'Marge de capital excédentaire',
                  value: data.totalCapital - (data.totalRwa * 0.105),
                  format: 'currency',
                  icon: Icons.savings,
                  color: AppColors.success,
                  isDark: isDark,
                  helper: 'Capital au-delà des exigences',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStressSimulationSection(bool isDark) {
    final stressScenarios = _getStressScenarios();

    return SectionCard(
      title: 'Simulation de stress - Impact sur le capital',
      child: Column(
        children: [
          _buildStressScenarioCard(scenario: stressScenarios[0], isDark: isDark),
          AppSpacing.vGapMd,
          _buildStressScenarioCard(scenario: stressScenarios[1], isDark: isDark),
          AppSpacing.vGapMd,
          _buildStressScenarioCard(scenario: stressScenarios[2], isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildCapitalMetricCard({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? helper,
  }) {
    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.25),
        ),
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
              const Spacer(),
              if (helper != null)
                Tooltip(
                  message: helper,
                  child: Icon(Icons.info_outline, size: 16,
                      color: isDark ? AppTheme.darkMuted : AppTheme.muted),
                ),
            ],
          ),
          AppSpacing.vGapMd,
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
          AppSpacing.vGapXs,
          Text(
            AppFormatters.currency(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow({
    required String label,
    required double required,
    required double available,
    required double percentage,
    required bool isDark,
    bool isTotal = false,
    bool isFinal = false,
  }) {
    final isSufficient = available >= required;
    final statusColor = isSufficient ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFinal
            ? (isDark
                ? AppColors.accent.withValues(alpha: 0.1)
                : AppColors.accent.withValues(alpha: 0.05))
            : (isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.01)),
        borderRadius: BorderRadius.circular(5),
        border: isFinal
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                color: isDark ? AppTheme.darkText : AppTheme.text,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppFormatters.currency(required),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkText : AppTheme.text,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            flex: 2,
            child: Text(
              AppFormatters.currency(available),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          AppSpacing.hGapMd,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              AppFormatters.percent(percentage),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioGauge({
    required String label,
    required double value,
    required double minimum,
    required double target,
    required bool isDark,
    String? helper,
  }) {
    final progress = (value / target).clamp(0.0, 1.0);
    final color = value >= target
        ? AppColors.success
        : value >= minimum
            ? AppColors.warning
            : AppColors.danger;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
              ),
              if (helper != null)
                Tooltip(
                  message: helper,
                  child: Icon(Icons.info_outline, size: 16,
                      color: isDark ? AppTheme.darkMuted : AppTheme.muted),
                ),
            ],
          ),
          AppSpacing.vGapMd,
          Text(
            AppFormatters.percent(value),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          AppSpacing.vGapSm,
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          AppSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${AppFormatters.percent(minimum)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                ),
              ),
              Text(
                'Cible: ${AppFormatters.percent(target)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalMetric({
    required String label,
    required double value,
    required String format,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? helper,
  }) {
    final formattedValue = format == 'percent'
        ? AppFormatters.percent(value)
        : AppFormatters.currency(value);

    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                        ),
                      ),
                    ),
                    if (helper != null)
                      Tooltip(
                        message: helper,
                        child: Icon(Icons.info_outline, size: 16,
                            color: isDark ? AppTheme.darkMuted : AppTheme.muted),
                      ),
                  ],
                ),
                AppSpacing.vGapXs,
                Text(
                  formattedValue,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressScenarioCard({
    required _StressScenario scenario,
    required bool isDark,
  }) {
    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark
            ? scenario.color.withValues(alpha: 0.08)
            : scenario.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: scenario.color.withValues(alpha: isDark ? 0.3 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scenario.color.withValues(alpha: isDark ? 0.2 : 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(scenario.icon, color: scenario.color, size: 20),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.text,
                      ),
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      scenario.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            children: [
              Expanded(
                child: _buildStressMetric(
                  label: 'Impact CET1',
                  value: scenario.cet1Impact,
                  isDark: isDark,
                  isNegative: true,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: _buildStressMetric(
                  label: 'CET1 post-stress',
                  value: scenario.cet1PostStress,
                  isDark: isDark,
                  isNegative: false,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: _buildStressMetric(
                  label: 'Ratio post-stress',
                  value: scenario.ratioPostStress,
                  isDark: isDark,
                  isNegative: false,
                  isRatio: true,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scenario.isCompliant
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        scenario.isCompliant ? 'CONFORME' : 'NON CONFORME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scenario.isCompliant
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                      AppSpacing.vGapXs,
                      Icon(
                        scenario.isCompliant
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.xmark_circle_fill,
                        color: scenario.isCompliant
                            ? AppColors.success
                            : AppColors.danger,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStressMetric({
    required String label,
    required double value,
    required bool isDark,
    required bool isNegative,
    bool isRatio = false,
  }) {
    final displayValue = isRatio
        ? AppFormatters.percent(value)
        : AppFormatters.currency(value.abs());

    final color = isNegative
        ? AppColors.danger
        : (isDark ? AppTheme.darkText : AppTheme.text);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
          AppSpacing.vGapXs,
          Text(
            isNegative ? '-$displayValue' : displayValue,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  _CapitalData _getCapitalData() {
    return _CapitalData(
      cet1Capital: 287.5e9,
      tier1Capital: 312.8e9,
      totalCapital: 356.4e9,
      totalRwa: 2145.6e9,
      requirements: _PrudentialRequirements(
        creditRiskCapital: 1523.4e9,
        marketRiskCapital: 172.8e9,
        operationalRiskCapital: 149.2e9,
        countercyclicalBuffer: 0.015,
        totalRequiredRatio: 0.105,
      ),
      ratios: _CapitalRatios(
        cet1Ratio: 0.134,
        tier1Ratio: 0.146,
        totalCapitalRatio: 0.166,
        leverageRatio: 0.052,
      ),
    );
  }

  List<_StressScenario> _getStressScenarios() {
    final baseData = _getCapitalData();

    return [
      _StressScenario(
        name: 'Récession modérée',
        description: 'Croissance -2%, hausse NPL à 8%, baisse marchés 15%',
        cet1Impact: 28.5e9,
        cet1PostStress: baseData.cet1Capital - 28.5e9,
        ratioPostStress: (baseData.cet1Capital - 28.5e9) / baseData.totalRwa,
        isCompliant: true,
        color: AppColors.warning,
        icon: CupertinoIcons.cloud_rain,
      ),
      _StressScenario(
        name: 'Choc sévère',
        description: 'Croissance -4%, NPL à 12%, chute marchés 30%, taux +200bp',
        cet1Impact: 62.3e9,
        cet1PostStress: baseData.cet1Capital - 62.3e9,
        ratioPostStress: (baseData.cet1Capital - 62.3e9) / baseData.totalRwa,
        isCompliant: true,
        color: AppColors.operationalHigh,
        icon: CupertinoIcons.bolt_fill,
      ),
      _StressScenario(
        name: 'Crise systémique',
        description: 'Croissance -6%, NPL à 18%, krach -50%, crise liquidité',
        cet1Impact: 115.8e9,
        cet1PostStress: baseData.cet1Capital - 115.8e9,
        ratioPostStress: (baseData.cet1Capital - 115.8e9) / baseData.totalRwa,
        isCompliant: false,
        color: AppColors.danger,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
      ),
    ];
  }
}

class _CapitalData {
  final double cet1Capital;
  final double tier1Capital;
  final double totalCapital;
  final double totalRwa;
  final _PrudentialRequirements requirements;
  final _CapitalRatios ratios;

  _CapitalData({
    required this.cet1Capital,
    required this.tier1Capital,
    required this.totalCapital,
    required this.totalRwa,
    required this.requirements,
    required this.ratios,
  });
}

class _PrudentialRequirements {
  final double creditRiskCapital;
  final double marketRiskCapital;
  final double operationalRiskCapital;
  final double countercyclicalBuffer;
  final double totalRequiredRatio;

  _PrudentialRequirements({
    required this.creditRiskCapital,
    required this.marketRiskCapital,
    required this.operationalRiskCapital,
    required this.countercyclicalBuffer,
    required this.totalRequiredRatio,
  });
}

class _CapitalRatios {
  final double cet1Ratio;
  final double tier1Ratio;
  final double totalCapitalRatio;
  final double leverageRatio;

  _CapitalRatios({
    required this.cet1Ratio,
    required this.tier1Ratio,
    required this.totalCapitalRatio,
    required this.leverageRatio,
  });
}

class _StressScenario {
  final String name;
  final String description;
  final double cet1Impact;
  final double cet1PostStress;
  final double ratioPostStress;
  final bool isCompliant;
  final Color color;
  final IconData icon;

  _StressScenario({
    required this.name,
    required this.description,
    required this.cet1Impact,
    required this.cet1PostStress,
    required this.ratioPostStress,
    required this.isCompliant,
    required this.color,
    required this.icon,
  });
}
