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
    this.trailingCard,
    this.trailingCardWidth,
  });

  final List<DashboardKpiItem> items;
  final Widget? trailingCard;
  final double? trailingCardWidth;

  @override
  State<DashboardKpiStrip> createState() => _DashboardKpiStripState();
}

class _DashboardKpiStripState extends State<DashboardKpiStrip> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final itemCount = math.max(
          widget.items.length + (widget.trailingCard != null ? 1 : 0),
          1,
        );
        final fluidWidth =
            (constraints.maxWidth - (gap * (itemCount - 1))) / itemCount;
        final baseCardWidth = fluidWidth >= 101.0 ? (fluidWidth - 20) : 90.0;
        final trailingCardWidth =
            widget.trailingCardWidth ?? baseCardWidth + 95;
        double widthFor(DashboardKpiItem item) {
          if (item.label == 'Densité RWA') {
            return baseCardWidth + 95;
          }
          return baseCardWidth;
        }

        final totalWidth =
            widget.items.fold<double>(0, (sum, item) => sum + widthFor(item)) +
                (widget.trailingCard != null ? trailingCardWidth : 0) +
                (gap * math.max(itemCount - 1, 0));
        final cards = Row(
          children: [
            for (var index = 0; index < widget.items.length; index++) ...[
              SizedBox(
                width: widthFor(widget.items[index]),
                height: widget.items[index].label == 'Densité RWA' ? 114 : 114,
                child: widget.items[index].label == 'Densité RWA'
                    ? DashboardDensityCard.fromItem(
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
              if (index != widget.items.length - 1 ||
                  widget.trailingCard != null)
                const SizedBox(width: gap),
            ],
            if (widget.trailingCard != null)
              SizedBox(
                width: trailingCardWidth,
                height: 114,
                child: widget.trailingCard,
              ),
          ],
        );

        if (totalWidth <= constraints.maxWidth) {
          return cards;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: cards,
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
  static const List<String> _currencySuffixes = ['FCFA', 'EUR', 'USD'];

  Color _accentColor() {
    return widget.item.gradient.first;
  }

  String? get _currencySuffix {
    final trimmedValue = widget.item.value.trim().toUpperCase();
    for (final suffix in _currencySuffixes) {
      if (trimmedValue.endsWith(' $suffix')) {
        return suffix;
      }
    }
    return null;
  }

  bool get _isCurrencyValue {
    return _currencySuffix != null;
  }

  bool get _isPercentValue {
    return widget.item.value.trim().endsWith('%');
  }

  String? get _unitPart {
    if (_isPercentValue) {
      return null;
    }
    if (!_isCurrencyValue) {
      return null;
    }

    final mainValue = widget.item.value
        .trim()
        .substring(
          0,
          widget.item.value.trim().length - _currencySuffix!.length,
        )
        .trimRight();
    final parts = mainValue.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : null;
  }

  String? get _suffixPart {
    if (_isCurrencyValue) {
      return _currencySuffix;
    }
    return null;
  }

  String get _numberPart {
    if (_isPercentValue) {
      return widget.item.value.trim();
    }
    if (!_isCurrencyValue) {
      return widget.item.value.trim();
    }

    final mainValue = widget.item.value
        .trim()
        .substring(
          0,
          widget.item.value.trim().length - _currencySuffix!.length,
        )
        .trimRight();
    final parts = mainValue.split(' ');
    return parts.isNotEmpty ? parts.first : mainValue;
  }

  Widget _buildValueBlock(Color titleColor, Color mutedColor, Color accent) {
    final unitPart = _unitPart;
    final suffixPart = _suffixPart;
    final valueHint = widget.item.valueHint;
    final hoverFullValue =
        _hovered && !_isPercentValue ? widget.item.fullValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _numberPart,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 4),
        if (unitPart != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(height: 1),
                  children: [
                    TextSpan(
                      text: unitPart,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (suffixPart != null)
                      TextSpan(
                        text: '  $suffixPart',
                        style: TextStyle(
                          color: mutedColor.withOpacity(0.76),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (hoverFullValue != null) ...[
                const SizedBox(height: 2),
                Text(
                  hoverFullValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor.withOpacity(0.92),
                    fontSize: 7.6,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (valueHint != null) ...[
                const SizedBox(height: 1),
                Text(
                  valueHint.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 8.6,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentColor();
    final surfaceColor = isDark ? const Color(0xFF0F1B31) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF22304B) : const Color(0xFFE2E8F2);
    final titleColor = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : AppTheme.muted;
    final iconSurface =
        isDark ? accent.withOpacity(0.10) : accent.withOpacity(0.06);
    final iconTint =
        isDark ? accent.withOpacity(0.78) : accent.withOpacity(0.58);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
                  ? accent.withOpacity(0.48)
                  : borderColor.withOpacity(0.82),
              width: (widget.selected || _hovered) ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(_hovered ? 0.14 : 0.10)
                    : const Color(0xFFB7C6DE).withOpacity(
                        _hovered ? 0.16 : 0.10,
                      ),
                blurRadius: _hovered ? 20 : 14,
                offset: Offset(0, _hovered ? 8 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LayoutBuilder(
              builder: (context, cardConstraints) {
                final cardHeight = cardConstraints.maxHeight;
                final topInset = math.max(4.0, cardHeight * 0.045);
                final iconDisk =
                    math.max(20.0, math.min(28.0, cardHeight * 0.24));
                final iconSize = math.max(12.0, iconDisk * 0.46);
                final numberFont =
                    math.max(16.0, math.min(21.0, cardHeight * 0.18));
                final unitFont =
                    math.max(10.2, math.min(12.2, cardHeight * 0.105));
                final fcfaFont =
                    math.max(9.2, math.min(10.4, cardHeight * 0.090));
                final titleFont =
                    math.max(8.2, math.min(9.2, cardHeight * 0.078));
                final helperFont =
                    math.max(7.0, math.min(7.6, cardHeight * 0.066));
                final valueGap = math.max(2.0, cardHeight * 0.035);
                final accentGap = math.max(2.0, cardHeight * 0.025);
                final unitPart = _unitPart;
                final suffixPart = _suffixPart;
                final hoverFullValue =
                    _hovered && !_isPercentValue ? widget.item.fullValue : null;

                return Stack(
                  children: [
                    Positioned(
                      right: 10,
                      top: 18,
                      bottom: 10,
                      width: math.min(74.0, cardConstraints.maxWidth * 0.34),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _KpiAmbientMotionPainter(
                            progress: 0.42,
                            accent: accent,
                            isDark: isDark,
                            compact: false,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 0,
                      child: Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(2),
                            bottomRight: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: topInset + 2,
                      right: 14,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: mutedColor.withOpacity(0.65),
                        size: 14,
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -10,
                      child: IgnorePointer(
                        child: Container(
                          width: 92,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withOpacity(0.00),
                                accent.withOpacity(isDark ? 0.04 : 0.045),
                                accent.withOpacity(isDark ? 0.08 : 0.09),
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
                    Padding(
                      padding: EdgeInsets.fromLTRB(10, topInset, 10, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: iconDisk,
                            height: iconDisk,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: iconSurface,
                              border: Border.all(
                                color: accent.withOpacity(isDark ? 0.16 : 0.10),
                              ),
                            ),
                            child: Icon(
                              widget.item.icon,
                              color: iconTint,
                              size: iconSize,
                            ),
                          ),
                          SizedBox(height: valueGap),
                          Text(
                            _numberPart,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: numberFont,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (unitPart != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(height: 1),
                                    children: [
                                      TextSpan(
                                        text: unitPart,
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: unitFont,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (suffixPart != null)
                                        TextSpan(
                                          text: '  $suffixPart',
                                          style: TextStyle(
                                            color: mutedColor.withOpacity(0.76),
                                            fontSize: fcfaFont,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (hoverFullValue != null) ...[
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        hoverFullValue,
                                        style: TextStyle(
                                          color: mutedColor.withOpacity(0.92),
                                          fontSize: math.max(
                                            7.0,
                                            helperFont + 0.2,
                                          ),
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            (_isPercentValue
                                ? SizedBox(height: unitFont)
                                : Text(
                                    widget.item.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: unitFont,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )),
                          SizedBox(height: accentGap),
                          Container(
                            width: 18,
                            height: 2,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.label.tr(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: titleFont,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                            ),
                          ),
                          const SizedBox(height: 0.5),
                          Text(
                            widget.item.helper.tr(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  mutedColor.withOpacity(isDark ? 0.96 : 0.92),
                              fontSize: helperFont,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardDensityCard extends StatefulWidget {
  const DashboardDensityCard({
    super.key,
    required this.densityPercent,
    required this.icon,
    required this.gradient,
    required this.helper,
    this.valueHint,
    this.selected = false,
    this.onTap,
  });

  factory DashboardDensityCard.fromItem({
    Key? key,
    required DashboardKpiItem item,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final normalized = item.value.replaceAll('%', '').replaceAll(',', '.');
    return DashboardDensityCard(
      key: key,
      densityPercent: double.tryParse(normalized) ?? 0.0,
      icon: item.icon,
      gradient: item.gradient,
      helper: item.helper,
      valueHint: item.valueHint,
      selected: selected,
      onTap: onTap,
    );
  }

  final double densityPercent;
  final IconData icon;
  final List<Color> gradient;
  final String helper;
  final String? valueHint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<DashboardDensityCard> createState() => _DashboardDensityCardState();
}

class _DashboardDensityCardState extends State<DashboardDensityCard> {
  bool _hovered = false;

  double get _densityPercent => widget.densityPercent;

  Color get _accent => widget.gradient.first;

  _DensityMiniLevel get _activeLevel {
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
                  ? _accent.withOpacity(0.48)
                  : borderColor.withOpacity(0.82),
              width: (widget.selected || _hovered) ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(_hovered ? 0.14 : 0.10)
                    : const Color(0xFFB7C6DE).withOpacity(
                        _hovered ? 0.16 : 0.10,
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
                    color: mutedColor.withOpacity(0.65),
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
                            _accent.withOpacity(0.00),
                            _accent.withOpacity(isDark ? 0.035 : 0.04),
                            _accent.withOpacity(isDark ? 0.075 : 0.08),
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
                        math.max(9.4, math.min(9.9, cardHeight * 0.086));
                    final helperFont =
                        math.max(6.2, math.min(6.6, cardHeight * 0.058));
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
                        math.max(78.0, math.min(92.0, cardHeight * 0.78));
                    final gaugeHeight =
                        math.max(32.0, math.min(38.0, cardHeight * 0.33));

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
                                        color: _accent.withOpacity(
                                          isDark ? 0.09 : 0.05,
                                        ),
                                        border: Border.all(
                                          color: _accent.withOpacity(
                                            isDark ? 0.16 : 0.10,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        widget.icon,
                                        color: _accent.withOpacity(
                                          isDark ? 0.78 : 0.58,
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
                                            context.tr('Densité RWA'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: titleColor,
                                              fontSize: titleFont,
                                              fontWeight: FontWeight.w800,
                                              height: 1.04,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            widget.helper.tr(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: mutedColor.withOpacity(
                                                isDark ? 0.94 : 0.88,
                                              ),
                                              fontSize: helperFont,
                                              fontWeight: FontWeight.w600,
                                              height: 1.02,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    '${_densityPercent.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: valueFont,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.7,
                                      height: 0.92,
                                    ),
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
                                          (widget.valueHint ??
                                                  'Risque moyen (densité)')
                                              .tr(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _accent,
                                            fontSize: chipFont,
                                            fontWeight: FontWeight.w700,
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
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: SizedBox(
                                  width: 98,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('Interprétation'),
                                        style: TextStyle(
                                          color: titleColor,
                                          fontSize: sectionTitleFont,
                                          fontWeight: FontWeight.w800,
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
                                                  fontWeight: FontWeight.w800,
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
                                                  fontWeight: FontWeight.w600,
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
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.4,
                                                ),
                                              ),
                                              WidgetSpan(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 6,
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: activeLevelData
                                                          .color
                                                          .withOpacity(
                                                        isDark ? 0.12 : 0.06,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: activeLevelData
                                                            .color
                                                            .withOpacity(
                                                          isDark ? 0.52 : 0.40,
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
                                                                  FontWeight
                                                                      .w700,
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
                                                                  FontWeight
                                                                      .w800,
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
                                                                  FontWeight
                                                                      .w800,
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
                                                                  FontWeight
                                                                      .w700,
                                                              height: 1.4,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                activeLevelData
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
                                                                  FontWeight
                                                                      .w600,
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
                                                  .withOpacity(
                                                    isDark ? 0.28 : 0.22,
                                                  ),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  isDark ? 0.22 : 0.10,
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
                                                      .withOpacity(
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
                                                        .withOpacity(0.16),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: levels[index]
                                                                .level ==
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        levels[index].label,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                                              FontWeight.w800,
                                                          height: 1,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 1),
                                                      Text(
                                                        levels[index].helper,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: levels[index]
                                                                      .level ==
                                                                  activeLevel
                                                              ? Colors.white
                                                                  .withOpacity(
                                                                      0.86)
                                                              : mutedColor
                                                                  .withOpacity(
                                                                  isDark
                                                                      ? 0.94
                                                                      : 0.88,
                                                                ),
                                                          fontSize:
                                                              levelHelperFont,
                                                          fontWeight:
                                                              FontWeight.w600,
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
    final gridColor = accent.withOpacity(isDark ? 0.028 : 0.018);
    final wickColor = accent.withOpacity(isDark ? 0.08 : 0.055);
    final barColor = accent.withOpacity(isDark ? 0.065 : 0.045);
    final lineColor = accent.withOpacity(isDark ? 0.10 : 0.07);
    final markerGlow = accent.withOpacity(isDark ? 0.05 : 0.03);
    final markerColor = accent.withOpacity(isDark ? 0.24 : 0.16);
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
