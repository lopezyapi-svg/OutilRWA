// Ce fichier affiche les cartes KPI du dashboard.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';

/// Modèle de contenu d'une carte KPI du dashboard.
class DashboardKpiItem {
  const DashboardKpiItem({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.gradient,
    required this.helper,
    this.valueHint,
    this.fullValue,
  });

  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final List<Color> gradient;
  final String helper;
  final String? valueHint;
  final String? fullValue;
}

/// Bandeau horizontal des KPI principaux.
class DashboardKpiStrip extends StatefulWidget {
  const DashboardKpiStrip({
    super.key,
    required this.items,
  });

  final List<DashboardKpiItem> items;

  @override
  State<DashboardKpiStrip> createState() => _DashboardKpiStripState();
}

class _DashboardKpiStripState extends State<DashboardKpiStrip> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final tight = constraints.maxWidth < 680;
        final gap = tight ? 5.0 : (compact ? 7.0 : 10.0);
        final cardHeight = tight ? 62.0 : 68.0;
        bool usesRiskInterpretation(DashboardKpiItem item) {
          return item.label == 'Densité RWA';
        }

        final hasRiskInterpretation =
            widget.items.any((item) => usesRiskInterpretation(item));
        final rowHeight = hasRiskInterpretation ? 104.0 : cardHeight;

        return SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            children: [
              for (var index = 0; index < widget.items.length; index++) ...[
                Expanded(
                  child: SizedBox(
                    height: usesRiskInterpretation(widget.items[index])
                        ? rowHeight
                        : cardHeight,
                    child: usesRiskInterpretation(widget.items[index])
                        ? _DensityMiniCard(
                            item: widget.items[index],
                            selected: _selectedIndex == index,
                            onTap: () => setState(() => _selectedIndex = index),
                          )
                        : _KpiCard(
                            item: widget.items[index],
                            selected: _selectedIndex == index,
                            onTap: () => setState(() => _selectedIndex = index),
                          ),
                  ),
                ),
                if (index != widget.items.length - 1) SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Carte individuelle d'un KPI du dashboard.
class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DashboardKpiItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

/// Etat interne qui gère l'animation au survol de la carte KPI.
class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  Color _accentColor() => widget.item.gradient.first;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentColor();
    final baseSurface = isDark ? const Color(0xFF101A2E) : Colors.white;
    final surfaceColor = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.16 : 0.075),
      baseSurface,
    );
    final borderColor = accent.withValues(
      alpha: (widget.selected || _hovered)
          ? (isDark ? 0.70 : 0.56)
          : (isDark ? 0.38 : 0.28),
    );
    final titleColor = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : const Color(0xFF63718A);
    final label = widget.item.label.tr(context);
    final helper = widget.item.helper.tr(context);
    final tooltipValue = widget.item.fullValue ?? widget.item.value;
    final tooltipMessage = '$label\n$tooltipValue\n$helper';

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, cardConstraints) {
              final width = cardConstraints.maxWidth;
              final compact = width < 150;
              final tight = width < 118;
              final micro = width < 92;
              final showIcon = width >= 98;
              final horizontalPadding = micro ? 6.0 : (tight ? 8.0 : 12.0);
              final verticalPadding = tight ? 8.0 : 10.0;
              final iconBox = tight ? 30.0 : (compact ? 34.0 : 38.0);
              final iconSize = tight ? 15.0 : (compact ? 16.0 : 18.0);
              final contentGap = tight ? 8.0 : 12.0;
              final labelFont = micro ? 7.6 : (tight ? 8.0 : 8.8);
              final valueFont = micro ? 13.6 : (tight ? 15.0 : 16.8);
              final iconSurface =
                  accent.withValues(alpha: isDark ? 0.18 : 0.13);
              final iconBorder = accent.withValues(alpha: isDark ? 0.26 : 0.16);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _hovered ? -1.5 : 0, 0),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  verticalPadding,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: borderColor,
                    width: (widget.selected || _hovered) ? 1.25 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(
                              alpha: _hovered ? 0.18 : 0.10,
                            )
                          : const Color(0xFF64748B).withValues(
                              alpha: _hovered ? 0.10 : 0.045,
                            ),
                      blurRadius: _hovered ? 16 : 10,
                      offset: Offset(0, _hovered ? 8 : 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (showIcon) ...[
                      Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: iconSurface,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: iconBorder),
                        ),
                        child: Icon(
                          widget.item.icon,
                          color: accent,
                          size: iconSize,
                        ),
                      ),
                      SizedBox(width: contentGap),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedColor,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: labelFont,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                              height: 1.05,
                            ),
                          ),
                          SizedBox(height: tight ? 5 : 6),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.item.value,
                                maxLines: 1,
                                style: TextStyle(
                                  color: titleColor,
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: valueFont,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _DensityMiniCard extends StatefulWidget {
  const _DensityMiniCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DashboardKpiItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DensityMiniCard> createState() => _DensityMiniCardState();
}

class _DensityMiniCardState extends State<_DensityMiniCard> {
  bool _hovered = false;

  double get _densityPercent {
    final normalized =
        widget.item.value.replaceAll('%', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  Color get _accent => widget.item.gradient.first;

  _DensityMiniLevel get _activeLevel {
    final hint = (widget.item.valueHint ?? '').toLowerCase();
    if (hint.contains('élev') || hint.contains('elev')) {
      return _DensityMiniLevel.high;
    }
    if (hint.contains('moyen')) {
      return _DensityMiniLevel.medium;
    }
    if (hint.contains('faible')) {
      return _DensityMiniLevel.low;
    }

    final value = _densityPercent;
    if (value >= 70) {
      return _DensityMiniLevel.high;
    }
    if (value >= 40) {
      return _DensityMiniLevel.medium;
    }
    return _DensityMiniLevel.low;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF0F1B31) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF22304B) : const Color(0xFFE2E8F2);
    final titleColor = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : AppTheme.muted;
    final activeLevel = _activeLevel;

    final levels = [
      (
        level: _DensityMiniLevel.low,
        label: context.tr('Faible'),
        helper: context.tr('peu risqué'),
        headline: context.tr('Risque faible (densité)'),
        detail: context.tr(
          'Le risque faible désigne un portefeuille dont la consommation en RWA reste modérée. Il traduit en général une qualité de crédit saine et une pression limitée sur le capital réglementaire.',
        ),
        advice: context.tr(
          'Maintenir la qualité des contreparties, préserver les garanties efficaces et suivre les concentrations par secteur.',
        ),
        color: const Color(0xFF27B36A),
        icon: Icons.verified_user_outlined,
      ),
      (
        level: _DensityMiniLevel.medium,
        label: context.tr('Moyen'),
        helper: context.tr('normal'),
        headline: context.tr('Risque moyen (densité)'),
        detail: context.tr(
          'Le risque moyen correspond à une situation équilibrée, mais plus sensible aux variations de qualité de crédit. Il nécessite une surveillance régulière car les RWA peuvent augmenter plus rapidement en cas de dégradation.',
        ),
        advice: context.tr(
          'Renforcer le suivi des expositions sensibles, revoir les couvertures disponibles et anticiper les besoins en capital.',
        ),
        color: const Color(0xFFFF8A1F),
        icon: Icons.account_balance_outlined,
      ),
      (
        level: _DensityMiniLevel.high,
        label: context.tr('Élevé'),
        helper: context.tr('alerte'),
        headline: context.tr('Risque élevé (densité)'),
        detail: context.tr(
          'Le risque élevé décrit un portefeuille plus exigeant en capital et plus exposé aux détériorations de notation. Il signale une vulnérabilité accrue et appelle une attention prioritaire sur les expositions concernées.',
        ),
        advice: context.tr(
          'Prioriser les actions de réduction de RWA, sécuriser les expositions les plus lourdes et renforcer rapidement les mécanismes de couverture.',
        ),
        color: const Color(0xFFFF4D5E),
        icon: Icons.warning_amber_rounded,
      ),
    ];
    final activeLevelData = levels.firstWhere(
      (item) => item.level == activeLevel,
    );

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _hovered ? -1.5 : 0, 0),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: (widget.selected || _hovered)
                  ? _accent.withValues(alpha: 0.48)
                  : borderColor.withValues(alpha: 0.82),
              width: (widget.selected || _hovered) ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: _hovered ? 0.14 : 0.10)
                    : const Color(0xFFB7C6DE).withValues(
                        alpha: _hovered ? 0.16 : 0.10,
                      ),
                blurRadius: _hovered ? 20 : 14,
                offset: Offset(0, _hovered ? 8 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  right: 108,
                  width: 54,
                  height: 30,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _KpiAmbientMotionPainter(
                        progress: 0.55,
                        accent: _accent,
                        isDark: isDark,
                        compact: true,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 0,
                  child: Container(
                    width: 74,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 12,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: mutedColor.withValues(alpha: 0.65),
                    size: 15,
                  ),
                ),
                Positioned(
                  bottom: -8,
                  right: -10,
                  child: IgnorePointer(
                    child: Container(
                      width: 96,
                      height: 74,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _accent.withValues(alpha: 0.00),
                            _accent.withValues(alpha: isDark ? 0.035 : 0.04),
                            _accent.withValues(alpha: isDark ? 0.075 : 0.08),
                          ],
                          stops: const [0.20, 0.58, 1.0],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(64),
                        ),
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final cardHeight = cardConstraints.maxHeight;
                    final iconDisk =
                        math.max(18.0, math.min(22.0, cardHeight * 0.20));
                    final iconSize = math.max(10.0, iconDisk * 0.46);
                    final titleFont =
                        math.max(7.8, math.min(8.2, cardHeight * 0.072));
                    final helperFont =
                        math.max(5.4, math.min(5.8, cardHeight * 0.050));
                    final valueFont =
                        math.max(17.0, math.min(18.5, cardHeight * 0.155));
                    final chipFont =
                        math.max(5.6, math.min(6.0, cardHeight * 0.052));
                    final sectionTitleFont =
                        math.max(6.5, math.min(6.9, cardHeight * 0.060));
                    final levelLabelFont =
                        math.max(5.8, math.min(6.1, cardHeight * 0.053));
                    final levelHelperFont =
                        math.max(5.0, math.min(5.3, cardHeight * 0.046));
                    final gaugeWidth =
                        math.max(70.0, math.min(82.0, cardHeight * 0.70));
                    final gaugeHeight =
                        math.max(29.0, math.min(34.0, cardHeight * 0.29));

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: iconDisk,
                                      height: iconDisk,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _accent.withValues(
                                          alpha: isDark ? 0.09 : 0.05,
                                        ),
                                        border: Border.all(
                                          color: _accent.withValues(
                                            alpha: isDark ? 0.16 : 0.10,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        widget.item.icon,
                                        color: _accent.withValues(
                                          alpha: isDark ? 0.78 : 0.58,
                                        ),
                                        size: iconSize,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.item.label.tr(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: titleColor,
                                              fontSize: titleFont,
                                              fontWeight: FontWeight.w500,
                                              height: 1.04,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            widget.item.helper.tr(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: mutedColor.withValues(
                                                alpha: isDark ? 0.94 : 0.88,
                                              ),
                                              fontSize: helperFont,
                                              fontWeight: FontWeight.w500,
                                              height: 1.02,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_densityPercent.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: valueFont,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                    height: 0.92,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 34,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: activeLevelData.color,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const Spacer(),
                                Transform.translate(
                                  offset: const Offset(0, -5),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: gaugeWidth,
                                          height: gaugeHeight,
                                          child: CustomPaint(
                                            painter: _DensityMiniGaugePainter(
                                              value: _densityPercent.clamp(
                                                  0.0, 100.0),
                                              isDark: isDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          (widget.item.valueHint ??
                                                  'Risque moyen (densité)')
                                              .tr(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _accent,
                                            fontSize: chipFont,
                                            fontWeight: FontWeight.w500,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: 98,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('Interprétation'),
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: sectionTitleFont,
                                        fontWeight: FontWeight.w500,
                                        height: 1.03,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    for (var index = 0;
                                        index < levels.length;
                                        index++) ...[
                                      Tooltip(
                                        richMessage: TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  '${levels[index].headline} : ',
                                              style: TextStyle(
                                                color: levels[index].color,
                                                fontSize: 8.2,
                                                fontWeight: FontWeight.w500,
                                                height: 1.35,
                                              ),
                                            ),
                                            TextSpan(
                                              text: levels[index].detail,
                                              style: TextStyle(
                                                color: isDark
                                                    ? const Color(0xFFF8FBFF)
                                                    : const Color(0xFF173055),
                                                fontSize: 8.1,
                                                fontWeight: FontWeight.w500,
                                                height: 1.35,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '\n\n',
                                              style: TextStyle(
                                                color: isDark
                                                    ? const Color(0xFFB8C9E6)
                                                    : const Color(0xFF5E759A),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                            WidgetSpan(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: activeLevelData.color
                                                        .withValues(
                                                      alpha:
                                                          isDark ? 0.12 : 0.06,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color: activeLevelData
                                                          .color
                                                          .withValues(
                                                        alpha: isDark
                                                            ? 0.52
                                                            : 0.40,
                                                      ),
                                                    ),
                                                  ),
                                                  child: RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              '${context.tr('Actuel')} : ',
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFFB8C9E6,
                                                                  )
                                                                : const Color(
                                                                    0xFF5E759A,
                                                                  ),
                                                            fontSize: 8.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.2,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${_densityPercent.toStringAsFixed(1)}% ',
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFFF8FBFF,
                                                                  )
                                                                : const Color(
                                                                    0xFF173055,
                                                                  ),
                                                            fontSize: 8.1,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.2,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '• ${activeLevelData.headline}',
                                                          style: TextStyle(
                                                            color:
                                                                activeLevelData
                                                                    .color,
                                                            fontSize: 8.1,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.2,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '\n${context.tr('Astuce')} : ',
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFFB8C9E6,
                                                                  )
                                                                : const Color(
                                                                    0xFF5E759A,
                                                                  ),
                                                            fontSize: 8.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: activeLevelData
                                                              .advice,
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFFF8FBFF,
                                                                  )
                                                                : const Color(
                                                                    0xFF173055,
                                                                  ),
                                                            fontSize: 8.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        waitDuration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        showDuration:
                                            const Duration(seconds: 4),
                                        preferBelow: false,
                                        verticalOffset: 10,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        constraints: const BoxConstraints(
                                          maxWidth: 240,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF122038)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: levels[index]
                                                .color
                                                .withValues(
                                                  alpha: isDark ? 0.28 : 0.22,
                                                ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: isDark ? 0.22 : 0.10,
                                              ),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: levels[index].level ==
                                                    activeLevel
                                                ? levels[index].color
                                                : levels[index]
                                                    .color
                                                    .withValues(
                                                      alpha:
                                                          isDark ? 0.10 : 0.05,
                                                    ),
                                            borderRadius:
                                                BorderRadius.circular(7),
                                            border: Border.all(
                                              color: levels[index].level ==
                                                      activeLevel
                                                  ? levels[index].color
                                                  : levels[index]
                                                      .color
                                                      .withValues(alpha: 0.16),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: levels[index].level ==
                                                          activeLevel
                                                      ? Colors.white
                                                      : levels[index].color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                levels[index].icon,
                                                color: levels[index].level ==
                                                        activeLevel
                                                    ? Colors.white
                                                    : levels[index].color,
                                                size: 11,
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      levels[index].label,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: levels[index]
                                                                    .level ==
                                                                activeLevel
                                                            ? Colors.white
                                                            : levels[index]
                                                                .color,
                                                        fontSize:
                                                            levelLabelFont,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        height: 1,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      levels[index].helper,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: levels[index]
                                                                    .level ==
                                                                activeLevel
                                                            ? Colors.white
                                                                .withValues(
                                                                    alpha: 0.86)
                                                            : mutedColor
                                                                .withValues(
                                                                alpha: isDark
                                                                    ? 0.94
                                                                    : 0.88,
                                                              ),
                                                        fontSize:
                                                            levelHelperFont,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        height: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (index != levels.length - 1)
                                        const SizedBox(height: 3),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DensityMiniGaugePainter extends CustomPainter {
  const _DensityMiniGaugePainter({
    required this.value,
    required this.isDark,
  });

  final double value;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 3);
    final radius =
        math.max(10.0, math.min(size.width / 2 - 12, size.height - 6));
    const strokeWidth = 6.5;
    const startAngle = math.pi;
    const sweep = math.pi;
    const gap = 0.02;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final segments = [
      (0.0, 0.40, const Color(0xFF27B36A), const Color(0xFF46CF84)),
      (0.40, 0.70, const Color(0xFFFFB01F), const Color(0xFFFF8426)),
      (0.70, 1.00, const Color(0xFFFF6666), const Color(0xFFFF4766)),
    ];

    for (final segment in segments) {
      final segmentStart = startAngle + (sweep * segment.$1) + gap;
      final segmentSweep =
          math.max(0.01, (sweep * (segment.$2 - segment.$1)) - (gap * 2));
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [segment.$3, segment.$4],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, segmentStart, segmentSweep, false, paint);
    }

    final normalized = (value / 100).clamp(0.0, 1.0);
    final needleAngle = startAngle + (sweep * normalized);
    final tip = Offset(
      center.dx + math.cos(needleAngle) * (radius - 5),
      center.dy + math.sin(needleAngle) * (radius - 5),
    );
    final baseLeft = Offset(
      center.dx + math.cos(needleAngle + 1.62) * 4.5,
      center.dy + math.sin(needleAngle + 1.62) * 4.5,
    );
    final baseRight = Offset(
      center.dx + math.cos(needleAngle - 1.62) * 4.5,
      center.dy + math.sin(needleAngle - 1.62) * 4.5,
    );

    final needlePath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();
    canvas.drawPath(needlePath, Paint()..color = const Color(0xFF3D7CFF));

    canvas.drawCircle(
      center,
      5,
      Paint()..color = isDark ? const Color(0xFF13213A) : Colors.white,
    );
    canvas.drawCircle(center, 2.2, Paint()..color = const Color(0xFFB7C6DE));
  }

  @override
  bool shouldRepaint(covariant _DensityMiniGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isDark != isDark;
  }
}

class _KpiAmbientMotionPainter extends CustomPainter {
  const _KpiAmbientMotionPainter({
    required this.progress,
    required this.accent,
    required this.isDark,
    required this.compact,
  });

  final double progress;
  final Color accent;
  final bool isDark;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final gridColor = accent.withValues(alpha: isDark ? 0.028 : 0.018);
    final wickColor = accent.withValues(alpha: isDark ? 0.08 : 0.055);
    final barColor = accent.withValues(alpha: isDark ? 0.065 : 0.045);
    final lineColor = accent.withValues(alpha: isDark ? 0.10 : 0.07);
    final markerGlow = accent.withValues(alpha: isDark ? 0.05 : 0.03);
    final markerColor = accent.withValues(alpha: isDark ? 0.24 : 0.16);
    final chartRect = Rect.fromLTWH(
      0,
      compact ? size.height * 0.12 : size.height * 0.14,
      size.width,
      compact ? size.height * 0.68 : size.height * 0.66,
    );

    for (var i = 0; i < 3; i++) {
      final y = chartRect.top + (chartRect.height / 2) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1,
      );
    }

    final barCount = compact ? 4 : 5;
    final step = chartRect.width / barCount;
    final barWidth = compact ? 4.0 : 5.0;
    final points = <Offset>[];

    for (var i = 0; i < barCount; i++) {
      final x = chartRect.left + (step * i) + (step * 0.5);
      final normalized = 0.38 +
          (0.22 * math.sin(t + (i * 0.58))) +
          (0.10 * math.cos((t * 0.8) + i));
      final heightFactor = normalized.clamp(0.22, 0.72);
      final y = chartRect.bottom - (chartRect.height * heightFactor);
      final openY = y + (compact ? 4.0 : 5.0);
      final closeY = y - (compact ? 2.5 : 3.0);

      canvas.drawLine(
        Offset(x, closeY - (compact ? 3 : 4)),
        Offset(x, openY + (compact ? 3 : 4)),
        Paint()
          ..color = wickColor
          ..strokeWidth = 1,
      );

      final bodyTop = math.min(openY, closeY);
      final bodyBottom = math.max(openY, closeY);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              x - (barWidth / 2), bodyTop, barWidth, bodyBottom - bodyTop),
          const Radius.circular(2),
        ),
        Paint()..color = barColor,
      );

      points.add(Offset(x, y));
    }

    final sparkPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      sparkPath.quadraticBezierTo(
          controlX, previous.dy, current.dx, current.dy);
    }

    canvas.drawPath(
      sparkPath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 0.9 : 1.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final scaledProgress = progress * (points.length - 1);
    final segmentIndex = scaledProgress.floor().clamp(0, points.length - 2);
    final segmentProgress = scaledProgress - segmentIndex;
    final start = points[segmentIndex];
    final end = points[segmentIndex + 1];
    final marker = Offset(
      ui.lerpDouble(start.dx, end.dx, segmentProgress) ?? start.dx,
      ui.lerpDouble(start.dy, end.dy, segmentProgress) ?? start.dy,
    );

    canvas.drawCircle(
      marker,
      compact ? 3.4 : 4.2,
      Paint()..color = markerGlow,
    );
    canvas.drawCircle(
      marker,
      compact ? 1.5 : 1.9,
      Paint()..color = markerColor,
    );
  }

  @override
  bool shouldRepaint(covariant _KpiAmbientMotionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark ||
        oldDelegate.compact != compact;
  }
}

enum _DensityMiniLevel {
  low,
  medium,
  high,
}
