// Ecran de comparaison réglementaire UEMOA (BCEAO) vs CEMAC (COBAC).
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Analyse comparative des spécificités du dispositif prudentiel UEMOA
/// (Bâle III BCEAO) par rapport au dispositif CEMAC (COBAC).
class IcapUemoaCemacScreen extends StatelessWidget {
  const IcapUemoaCemacScreen({super.key});

  static const Color _uemoa = AppColors.zoneUemoa;
  static const Color _cemac = AppColors.zoneCemac;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Spécificités UEMOA vs CEMAC',
            subtitle:
                'Comparaison des dispositifs prudentiels BCEAO (UEMOA) et COBAC (CEMAC) – Bâle III adapté',
          ),
          AppSpacing.gapLg,
          _buildZoneBadges(isDark),
          AppSpacing.gapMd,
          _buildSummaryCards(isDark),
          AppSpacing.gapMd,
          _buildComparisonTable(isDark),
          AppSpacing.gapMd,
          _buildRatiosSection(isDark),
          AppSpacing.gapMd,
          _buildOperationalRiskSection(isDark),
          AppSpacing.gapMd,
          _buildUemoaSpecificsSection(isDark),
          AppSpacing.gapMd,
          _buildCommonPointsSection(isDark),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Badges de zone
  // ---------------------------------------------------------------------------

  Widget _buildZoneBadges(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildZoneBadge(
            label: 'UEMOA',
            subLabel:
                'Banque Centrale des États de l\'Afrique de l\'Ouest (BCEAO)',
            color: _uemoa,
            isDark: isDark,
            icon: CupertinoIcons.building_2_fill,
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: _buildZoneBadge(
            label: 'CEMAC',
            subLabel: 'Commission Bancaire de l\'Afrique Centrale (COBAC)',
            color: _cemac,
            isDark: isDark,
            icon: CupertinoIcons.globe,
          ),
        ),
      ],
    );
  }

  Widget _buildZoneBadge({
    required String label,
    required String subLabel,
    required Color color,
    required bool isDark,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.14),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cartes de différences clés
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(bool isDark) {
    return SectionCard(
      title: 'Différences clés',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildDiffCard(
              label: 'Ratio solvabilité min.',
              uemoaValue: '9,0 %',
              cemacValue: '8,0 %',
              isDark: isDark,
              note: 'UEMOA +1 pt',
              cemacAbsent: false,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: _buildDiffCard(
              label: 'Ratio cible (avec coussin)',
              uemoaValue: '11,5 %',
              cemacValue: '10,5 %',
              isDark: isDark,
              note: 'UEMOA +1 pt',
              cemacAbsent: false,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: _buildDiffCard(
              label: 'Ratio de levier',
              uemoaValue: '≥ 3 %',
              cemacValue: 'Non défini',
              isDark: isDark,
              note: 'Exclusif UEMOA',
              cemacAbsent: true,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: _buildDiffCard(
              label: 'Risque opérationnel',
              uemoaValue: 'BIA + Standard',
              cemacValue: 'BIA uniquement',
              isDark: isDark,
              note: 'Approche suppl. UEMOA',
              cemacAbsent: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffCard({
    required String label,
    required String uemoaValue,
    required String cemacValue,
    required bool isDark,
    required String note,
    required bool cemacAbsent,
  }) {
    final cemacColor = cemacAbsent ? AppColors.danger : _cemac;

    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
          AppSpacing.vGapMd,
          _buildZoneValue(zone: 'UEMOA', value: uemoaValue, color: _uemoa),
          AppSpacing.vGapSm,
          _buildZoneValue(zone: 'CEMAC', value: cemacValue, color: cemacColor),
          AppSpacing.vGapSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneValue({
    required String zone,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              zone,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tableau comparatif complet
  // ---------------------------------------------------------------------------

  Widget _buildComparisonTable(bool isDark) {
    final rows = [
      const _CompRow('CET1 minimum', 'Art. 91(a)', '5,0 %', '4,5 %', false),
      const _CompRow('Tier 1 minimum', 'Art. 91(b)', '7,5 %', '7,5 %', true),
      const _CompRow('Ratio FPE minimum (solvabilité)', 'Art. 91(c)', '9,0 %',
          '8,0 %', false),
      const _CompRow('Coussin de conservation (CET1)', 'Art. 92-97', '2,5 %',
          '2,5 %', true),
      const _CompRow('Coussin contracyclique', 'Art. 98-100', '0 – 2,5 %',
          '0 – 2,5 %', true),
      const _CompRow('Ratio cible (avec coussins)', 'Art. 103', '11,5 % (FPE)',
          '10,5 % (FPE)', false),
      const _CompRow('Ratio de levier minimum', 'Art. 468-469',
          '≥ 3 % (T1 / Exposition)', 'Non défini', false),
      const _CompRow('Division des risques', 'Art. 451', '≤ 25 % des FP T1',
          '≤ 25 % des FP T1', true),
      const _CompRow('Risque opérationnel – approches', 'Art. 299-315',
          'BIA (α=15 %) + Standard (β)', 'BIA uniquement', false),
      const _CompRow('Exemption souverain (FCFA)', 'Art. 117',
          '0 % (États UEMOA)', '0 % (États CEMAC)', true),
      const _CompRow('Obligations sécurisées', 'Art. 462',
          '20 % sous conditions', 'Non spécifié', false),
      const _CompRow('Prêts immobiliers résidentiels', 'Art. 142-145',
          '35 % (LTV ≤ 90 %, CSD ≤ 40 %)', 'Référentiel COBAC', false),
      const _CompRow('Prêts immobiliers commerciaux', 'Art. 146-149',
          '75 % (LTV ≤ 90 %)', 'Référentiel COBAC', false),
      const _CompRow('Prêts aux dirigeants', 'Art. 490', '≤ 20 % des FPE',
          '≤ 20 % des FPE', true),
      const _CompRow('Dispositions transitoires', 'Tableau 22',
          'Calendrier 2018-2022', 'En vigueur dès 2017', false),
      const _CompRow('Coussin systémique (D-SIB)', 'Art. 101-102',
          'Surcharge pour D-SIB', 'Non spécifié', false),
      const _CompRow('Ratio de liquidité court terme (RLCT)', 'Art. 582',
          '≥ 100 % (ALHQ / Sorties)', 'LCR (≥ 100 %)', true),
      const _CompRow('Ratio de liquidité long terme (RLLT)', 'Art. 583',
          '≥ 100 % (NSFR)', 'NSFR (≥ 100 %)', true),
    ];

    return SectionCard(
      title: 'Tableau comparatif complet',
      child: Column(
        children: [
          _buildTableHeader(isDark),
          const SizedBox(height: 6),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildTableRow(r, isDark),
            ),
          ),
          AppSpacing.vGapMd,
          _buildLegend(isDark),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'Thème / Référence',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkMuted : AppTheme.muted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildHeaderZone('UEMOA (BCEAO)', _uemoa),
          ),
          Expanded(
            flex: 3,
            child: _buildHeaderZone('CEMAC (COBAC)', _cemac),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildHeaderZone(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(_CompRow row, bool isDark) {
    final isAbsent = row.cemac == 'Non défini' || row.cemac == 'Non spécifié';
    final cemacColor = isAbsent ? AppColors.danger : _cemac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark
              ? AppColors.borderDark.withValues(alpha: 0.5)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.theme,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.ref,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.uemoa,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _uemoa,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.cemac,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cemacColor,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Center(
              child: Icon(
                row.same
                    ? Icons.check_circle_rounded
                    : Icons.compare_arrows_rounded,
                size: 15,
                color: row.same ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Row(
      children: [
        _buildLegendItem(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          label: 'Identique dans les deux zones',
          isDark: isDark,
        ),
        const SizedBox(width: 4),
        _buildLegendItem(
          icon: Icons.compare_arrows_rounded,
          color: AppColors.warning,
          label: 'Différence entre UEMOA et CEMAC',
          isDark: isDark,
        ),
        const SizedBox(width: 4),
        _buildLegendItem(
          icon: Icons.cancel_rounded,
          color: AppColors.danger,
          label: 'Absent / non spécifié en CEMAC',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required IconData icon,
    required Color color,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppTheme.darkMuted : AppTheme.muted,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Comparaison visuelle des ratios prudentiels
  // ---------------------------------------------------------------------------

  Widget _buildRatiosSection(bool isDark) {
    return SectionCard(
      title: 'Comparaison des ratios prudentiels',
      child: Column(
        children: [
          _buildRatioCompRow(
            label: 'CET1 – Fonds propres de base de catégorie 1',
            ref: 'Art. 91(a)',
            uemoaMin: 0.05,
            uemoaTarget: 0.075,
            cemacMin: 0.045,
            cemacTarget: 0.07,
            isDark: isDark,
          ),
          AppSpacing.vGapMd,
          _buildRatioCompRow(
            label: 'Tier 1 – Fonds propres de catégorie 1',
            ref: 'Art. 91(b)',
            uemoaMin: 0.075,
            uemoaTarget: 0.085,
            cemacMin: 0.075,
            cemacTarget: 0.085,
            isDark: isDark,
          ),
          AppSpacing.vGapMd,
          _buildRatioCompRow(
            label: 'FPE / Solvabilité globale',
            ref: 'Art. 91(c) + Art. 92',
            uemoaMin: 0.09,
            uemoaTarget: 0.115,
            cemacMin: 0.09,
            cemacTarget: 0.105,
            isDark: isDark,
          ),
          AppSpacing.vGapMd,
          _buildLeverageRow(isDark),
        ],
      ),
    );
  }

  Widget _buildRatioCompRow({
    required String label,
    required String ref,
    required double uemoaMin,
    required double uemoaTarget,
    required double cemacMin,
    required double cemacTarget,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
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
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
              ),
              Text(
                ref,
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: _buildRatioBar(
                  zone: 'UEMOA',
                  min: uemoaMin,
                  target: uemoaTarget,
                  color: _uemoa,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildRatioBar(
                  zone: 'CEMAC',
                  min: cemacMin,
                  target: cemacTarget,
                  color: _cemac,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioBar({
    required String zone,
    required double min,
    required double target,
    required Color color,
    required bool isDark,
  }) {
    final pctMin = '${(min * 100).toStringAsFixed(1)} %';
    final pctTarget = '${(target * 100).toStringAsFixed(1)} %';
    const maxScale = 0.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  zone,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              'Cible: $pctTarget',
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppTheme.darkMuted : AppTheme.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: constraints.maxWidth *
                      (target / maxScale).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width:
                      constraints.maxWidth * (min / maxScale).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Min: $pctMin',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkMuted : AppTheme.muted,
              ),
            ),
            Text(
              'Avec coussin: $pctTarget',
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppTheme.darkMuted : AppTheme.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeverageRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withValues(alpha: 0.06)
            : AppColors.warning.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ratio de levier – Art. 468-469',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'T1 / Exposition totale (bilan + hors-bilan)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hGapMd,
          _buildCompChip('UEMOA', '≥ 3 %', _uemoa, isDark),
          AppSpacing.hGapMd,
          _buildCompChip('CEMAC', 'Non défini', AppColors.danger, isDark),
        ],
      ),
    );
  }

  Widget _buildCompChip(String zone, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          zone,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Risque opérationnel – approches
  // ---------------------------------------------------------------------------

  Widget _buildOperationalRiskSection(bool isDark) {
    return SectionCard(
      title: 'Risque opérationnel – Approches réglementaires',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildOpRiskUemoa(isDark)),
              AppSpacing.hGapMd,
              Expanded(child: _buildOpRiskCemac(isDark)),
            ],
          ),
          AppSpacing.vGapMd,
          _buildBetaTable(isDark),
        ],
      ),
    );
  }

  Widget _buildOpRiskUemoa(bool isDark) {
    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: _uemoa.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _uemoa.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UEMOA (BCEAO)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _uemoa,
            ),
          ),
          AppSpacing.vGapMd,
          _buildApproachItem(
            name: 'Approche indicateur de base (BIA)',
            ref: 'Art. 301',
            formula: 'K = (Σ PB+ × 15 %) / n',
            available: true,
            isDark: isDark,
          ),
          AppSpacing.vGapSm,
          _buildApproachItem(
            name: 'Approche standard (SA)',
            ref: 'Art. 305-314',
            formula:
                'K = (Σ max(Σ PBᵢ × βᵢ, 0)) / 3\n8 lignes de métier • β ∈ {12 %, 15 %, 19 %}',
            available: true,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildOpRiskCemac(bool isDark) {
    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: _cemac.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _cemac.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CEMAC (COBAC)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _cemac,
            ),
          ),
          AppSpacing.vGapMd,
          _buildApproachItem(
            name: 'Approche indicateur de base (BIA)',
            ref: '–',
            formula: 'K = (Σ PB+ × 15 %) / n',
            available: true,
            isDark: isDark,
          ),
          AppSpacing.vGapSm,
          _buildApproachItem(
            name: 'Approche standard (SA)',
            ref: '–',
            formula: 'Non autorisée dans le dispositif COBAC actuel',
            available: false,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildApproachItem({
    required String name,
    required String ref,
    required String formula,
    required bool available,
    required bool isDark,
  }) {
    final statusColor = available ? AppColors.success : AppColors.danger;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            available ? Icons.check_rounded : Icons.close_rounded,
            size: 10,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.text,
                      ),
                    ),
                  ),
                  if (ref != '–')
                    Text(
                      ref,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                formula,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                  height: 1.4,
                  fontFamily: formula.contains('K =') ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBetaTable(bool isDark) {
    const betas = [
      ('Financement d\'entreprise', '19 %'),
      ('Activités de marchés', '19 %'),
      ('Banque de détail', '12 %'),
      ('Banque commerciale', '15 %'),
      ('Paiements et règlements', '19 %'),
      ('Services d\'agence', '15 %'),
      ('Gestion d\'actifs', '12 %'),
      ('Courtage de détail', '12 %'),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
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
              Text(
                'Coefficients β – Approche standard (UEMOA uniquement)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkText : AppTheme.text,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Annexe 4 / Art. 309',
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                ),
              ),
            ],
          ),
          AppSpacing.vGapMd,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: betas.map((b) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3, vertical: 6.0),
                decoration: BoxDecoration(
                  color: _uemoa.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _uemoa.withValues(alpha: isDark ? 0.3 : 0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.$1,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _uemoa,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Spécificités exclusives UEMOA
  // ---------------------------------------------------------------------------

  Widget _buildUemoaSpecificsSection(bool isDark) {
    const items = [
      (
        title: 'Ratio de levier (Art. 468-469)',
        icon: Icons.account_balance_rounded,
        desc:
            'Exigence minimale de 3 % (T1 / Exposition totale bilan + hors-bilan). '
            'Indicateur complémentaire limitant l\'effet de levier excessif. '
            'Absent du dispositif COBAC actuel.',
      ),
      (
        title: 'Obligations sécurisées (Art. 462)',
        icon: Icons.security_rounded,
        desc:
            'Pondération à 20 % sous conditions strictes (qualité des actifs, isolation '
            'juridique, ratio de couverture). Non spécifié dans le référentiel COBAC.',
      ),
      (
        title: 'Critères LTV pour l\'immobilier (Art. 142-149)',
        icon: Icons.home_work_rounded,
        desc: 'Pondération résidentielle 35 % si LTV ≤ 90 % et CSD ≤ 40 %. '
            'Pondération commerciale 75 % si LTV ≤ 90 %. '
            'Critères LTV explicites et chiffrés absents en CEMAC.',
      ),
      (
        title: 'Approche standard risque opérationnel (Art. 305-314)',
        icon: Icons.settings_applications_rounded,
        desc: '8 lignes de métier avec des β spécifiques (12 % à 19 %) '
            'sous conditions d\'agrément BCEAO. Approche non disponible en CEMAC.',
      ),
      (
        title: 'Calendrier transitoire 2018-2022 (Tableau 22)',
        icon: Icons.schedule_rounded,
        desc:
            'Montée en charge progressive : CET1 de 5 % (min) à 7,5 % (cible), '
            'T1 de 7,5 % à 8,5 %, FPE de 9 % à 11,5 %. '
            'CEMAC: entrée en vigueur directe en 2017.',
      ),
      (
        title: 'Coussin systémique D-SIB (Art. 101-102)',
        icon: Icons.shield_rounded,
        desc:
            'Surcharge en fonds propres supplémentaires pour les établissements '
            'd\'importance systémique intérieure, fixée par la BCEAO. '
            'Non spécifié explicitement en CEMAC.',
      ),
    ];

    return SectionCard(
      title: 'Spécificités exclusives UEMOA',
      child: Column(
        children: items.indexed.map((entry) {
          final (index, item) = entry;
          return Padding(
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 8 : 0),
            child: _buildSpecItem(
              title: item.title,
              icon: item.icon,
              desc: item.desc,
              isDark: isDark,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpecItem({
    required String title,
    required IconData icon,
    required String desc,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _uemoa.withValues(alpha: isDark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _uemoa.withValues(alpha: isDark ? 0.25 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _uemoa.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, color: _uemoa, size: 16),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _uemoa.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'UEMOA',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _uemoa,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Points communs
  // ---------------------------------------------------------------------------

  Widget _buildCommonPointsSection(bool isDark) {
    const commons = [
      (
        theme: 'Coussin de conservation (2,5 %)',
        ref: 'Art. 92-97',
        detail:
            'Composé intégralement de CET1. Restrictions de distributions progressives '
            'si le ratio CET1 descend sous la cible (Tableau 1).',
      ),
      (
        theme: 'Division des risques',
        ref: 'Art. 451',
        detail:
            'Exposition maximale à une contrepartie ≤ 25 % des fonds propres T1. '
            'Déclaration semestrielle des grandes expositions.',
      ),
      (
        theme: 'Exemption souveraine (monnaie locale)',
        ref: 'Art. 117',
        detail:
            'Créances sur États membres libellées et refinancées en FCFA : pondération 0 %. '
            'Valable dans les deux zones monétaires.',
      ),
      (
        theme: 'Prêts aux dirigeants et administrateurs',
        ref: 'Art. 490',
        detail:
            'Encours des prêts aux dirigeants, administrateurs et actionnaires significatifs '
            '≤ 20 % des fonds propres éligibles.',
      ),
      (
        theme: 'Coussin contracyclique (0 – 2,5 %)',
        ref: 'Art. 98-100',
        detail:
            'Coussin variable activé par l\'autorité de supervision selon la phase du cycle '
            'économique (BCEAO ou COBAC).',
      ),
      (
        theme: 'OEEC reconnus',
        ref: 'Tableau 10',
        detail:
            'Agences de notation reconnues : Standard & Poor\'s, Moody\'s, Fitch et DBRS '
            'pour les évaluations de crédit externes.',
      ),
    ];

    return SectionCard(
      title: 'Points communs UEMOA – CEMAC',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: commons.take(3).toList().indexed.map((entry) {
                final (index, c) = entry;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < 2 ? 8 : 0),
                  child: _buildCommonItem(c.theme, c.ref, c.detail, isDark),
                );
              }).toList(),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              children: commons.skip(3).toList().indexed.map((entry) {
                final (index, c) = entry;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < 2 ? 8 : 0),
                  child: _buildCommonItem(c.theme, c.ref, c.detail, isDark),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonItem(
      String theme, String ref, String detail, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.success.withValues(alpha: isDark ? 0.22 : 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.check_rounded,
                size: 10, color: AppColors.success),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkText : AppTheme.text,
                        ),
                      ),
                    ),
                    Text(
                      ref,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                    height: 1.4,
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

// ---------------------------------------------------------------------------
// Modèle de données interne pour les lignes du tableau comparatif
// ---------------------------------------------------------------------------

class _CompRow {
  const _CompRow(this.theme, this.ref, this.uemoa, this.cemac, this.same);

  final String theme;
  final String ref;
  final String uemoa;
  final String cemac;
  final bool same;
}
