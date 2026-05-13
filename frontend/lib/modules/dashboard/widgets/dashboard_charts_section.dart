// Ce fichier affiche la zone centrale avec les graphiques principaux.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_maturity_panel.dart';
import 'dashboard_panel.dart';
import 'dashboard_theme.dart';

/// Zone centrale du dashboard qui regroupe les graphiques principaux.
class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({
    super.key,
    required this.displayCurrency,
    required this.grossCategoryEntries,
    required this.rwaCategoryEntries,
    required this.countryEntries,
    required this.crmEntries,
    required this.maturityPoints,
    required this.maturityView,
    required this.onMaturityViewChanged,
    required this.densityRwa,
    required this.coveredRatio,
  });

  final String displayCurrency;
  final List<DistributionEntry> grossCategoryEntries;
  final List<DistributionEntry> rwaCategoryEntries;
  final List<DistributionEntry> countryEntries;
  final List<DistributionEntry> crmEntries;
  final List<DashboardProjectionPoint> maturityPoints;
  final DashboardMaturityView maturityView;
  final ValueChanged<DashboardMaturityView> onMaturityViewChanged;
  final double densityRwa;
  final double coveredRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // La première ligne regroupe la structure du portefeuille et la répartition CRM.
        final primaryChartsRow = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(constraints.maxWidth, 860.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _ExposureAreaChartCard(
                    displayCurrency: displayCurrency,
                    grossEntries: grossCategoryEntries,
                    rwaEntries: rwaCategoryEntries,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 381,
                    child: Column(
                      children: [
                        _CrmDonutCard(
                          entries: crmEntries,
                          coveredRatio: coveredRatio,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _CreditGaugeCard(
                            densityRwa: densityRwa,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        // La seconde ligne reste sur une seule rangée sans scroll horizontal.
        final secondaryChartsContent = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: DashboardMaturityPanel(
                displayCurrency: displayCurrency,
                view: maturityView,
                onViewChanged: onMaturityViewChanged,
                points: maturityPoints,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _CountriesCard(
                entries: countryEntries,
                displayCurrency: displayCurrency,
              ),
            ),
          ],
        );

        return Column(
          children: [
            primaryChartsRow,
            const SizedBox(height: 8),
            secondaryChartsContent,
          ],
        );
      },
    );
  }
}

/// Carte qui affiche la répartition des RWA par catégorie d'exposition.
class _ExposureAreaChartCard extends StatefulWidget {
  const _ExposureAreaChartCard({
    required this.displayCurrency,
    required this.grossEntries,
    required this.rwaEntries,
  });

  final String displayCurrency;
  final List<DistributionEntry> grossEntries;
  final List<DistributionEntry> rwaEntries;

  @override
  State<_ExposureAreaChartCard> createState() => _ExposureAreaChartCardState();
}

/// Etat interne du graphique principal de répartition des expositions.
class _ExposureAreaChartCardState extends State<_ExposureAreaChartCard> {
  String? _activeEntryKey;

  bool get _isFcfaDisplay {
    final code = widget.displayCurrency.toUpperCase();
    return code == 'XOF' || code == 'XAF';
  }

  double _convertFromXof(double value) {
    return convertCurrencyAmount(
      value,
      fromCurrency: 'XOF',
      toCurrency: widget.displayCurrency,
    );
  }

  String _compactDisplayAmount(double value) {
    final convertedValue = _convertFromXof(value);
    final unit = displayCurrencyLabel(widget.displayCurrency);
    return '${AppFormatters.compactNumber(convertedValue)} $unit';
  }

  String _precisePercentLabel(double value) {
    final scaled = value * 100;
    if (scaled == 0) {
      return '0%';
    }

    int decimals;
    final absoluteScaled = scaled.abs();
    if (absoluteScaled >= 1) {
      decimals = 1;
    } else if (absoluteScaled >= 0.1) {
      decimals = 2;
    } else if (absoluteScaled >= 0.01) {
      decimals = 3;
    } else if (absoluteScaled >= 0.001) {
      decimals = 4;
    } else if (absoluteScaled >= 0.0001) {
      decimals = 5;
    } else if (absoluteScaled >= 0.00001) {
      decimals = 6;
    } else if (absoluteScaled >= 0.000001) {
      decimals = 7;
    } else {
      decimals = 8;
    }

    String text = '0';
    for (var currentDecimals = decimals;
        currentDecimals <= 10;
        currentDecimals++) {
      final factor = math.pow(10, currentDecimals).toDouble();
      final truncated = scaled >= 0
          ? (scaled * factor).floor() / factor
          : (scaled * factor).ceil() / factor;
      text = truncated.toStringAsFixed(currentDecimals);
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
      if (text != '0') {
        break;
      }
    }

    return '$text%';
  }

  String _fullAmountValue(double value) {
    final convertedValue = _convertFromXof(value);
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'fr_FR',
      decimalDigits: _isFcfaDisplay ? 0 : 2,
    );

    return '${formatter.format(convertedValue)} ${displayCurrencyLabel(widget.displayCurrency)}';
  }

  Widget _buildExposureTooltip({
    required String label,
    required double amount,
    required Widget child,
  }) {
    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 10.4,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          TextSpan(
            text: '\n${_fullAmountValue(amount)}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 9.6,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
      waitDuration: const Duration(milliseconds: 80),
      showDuration: const Duration(seconds: 3),
      preferBelow: false,
      verticalOffset: 10,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      constraints: const BoxConstraints(maxWidth: 190),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: const Color(0xFFD8E2EF),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  double _axisMaxInMillions(double rawValueInMillions) {
    if (_isFcfaDisplay) {
      return 1000.0;
    }

    final safeValue = math.max(rawValueInMillions, 0.1);
    final roughStep = safeValue / 4;
    double step;

    if (roughStep <= 0.1) {
      step = 0.1;
    } else if (roughStep <= 0.25) {
      step = 0.25;
    } else if (roughStep <= 0.5) {
      step = 0.5;
    } else if (roughStep <= 1) {
      step = 1;
    } else if (roughStep <= 2.5) {
      step = 2.5;
    } else if (roughStep <= 5) {
      step = 5;
    } else if (roughStep <= 10) {
      step = 10;
    } else if (roughStep <= 25) {
      step = 25;
    } else if (roughStep <= 50) {
      step = 50;
    } else {
      step = 100;
    }

    return (safeValue / step).ceil() * step;
  }

  List<double> _axisTicksInMillions(double axisMax) {
    if (_isFcfaDisplay) {
      return const [
        0.0,
        100.0,
        200.0,
        300.0,
        400.0,
        500.0,
        600.0,
        700.0,
        800.0,
        900.0,
        1000.0,
      ];
    }

    final step = axisMax / 4;
    return List<double>.generate(5, (index) => step * index);
  }

  String _axisTickLabel(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
  }

  double _axisPosition(double value, List<double> ticks, double axisMax) {
    final safeAxisMax = axisMax <= 0 ? 1.0 : axisMax;
    final clampedValue = value.clamp(0.0, safeAxisMax).toDouble();
    return clampedValue / safeAxisMax;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barTrackColor = isDark
        ? const Color(0xFF22304B).withValues(alpha: 0.34)
        : const Color(0xFFEEF2F7);
    final rankedGrossEntries = [...widget.grossEntries]
      ..sort((left, right) => right.amount.compareTo(left.amount));
    final visibleGrossEntries = rankedGrossEntries.take(5).toList();
    final rankedRwaEntries = [...widget.rwaEntries]
      ..sort((left, right) => right.amount.compareTo(left.amount));
    final visibleRwaEntries = rankedRwaEntries.take(5).toList();

    bool isRiskHighlight(DistributionEntry entry) =>
        dashboardExposureLabel(entry.label) == 'créances à risque élevé';

    Color hierarchicalBarTone(DistributionEntry entry) {
      switch (dashboardExposureLabel(entry.label)) {
        case 'souverains':
          return const Color(0xFF3B82F6);
        case 'organismes pub. hors Adm c':
          return const Color(0xFF3B82F6);
        case 'Expositions sur les BMD':
          return const Color(0xFFCBD5E1);
        case 'institutions financières':
          return const Color(0xFF3B82F6);
        case 'entreprises':
          return const Color(0xFF3B82F6);
        case 'clientèle de détail':
          return const Color(0xFF16A34A);
        case "prêts garantis par l'immo R":
          return const Color(0xFFF59E0B);
        case "prêts garantis par l'immo C":
          return const Color(0xFFF59E0B);
        case 'créances en souffrance':
          return const Color(0xFFDC2626);
        case 'créances à risque élevé':
          return const Color(0xFFDC2626);
        case 'autres actifs':
          return const Color(0xFF16A34A);
        case 'Hors bilan':
          return const Color(0xFFCBD5E1);
        default:
          return const Color(0xFFCBD5E1);
      }
    }

    double hierarchicalBarOpacity(DistributionEntry entry) => 1.0;

    Color valueLabelColor(DistributionEntry entry) =>
        isDark ? const Color(0xFFF5F8FF) : const Color(0xFF23344C);

    const grossTopFivePalette = [
      Color(0xFF2563EB),
      Color(0xFF14B8A6),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
    ];

    const rwaTopFivePalette = [
      Color(0xFF0F766E),
      Color(0xFF65A30D),
      Color(0xFFD97706),
      Color(0xFFDB2777),
      Color(0xFF7C3AED),
    ];

    Widget buildEmptyCategoryCard(String title) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111E34) : const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDark ? const Color(0xFF22304B) : const Color(0xFFE6ECF5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dashboardTitleColor(isDark),
                  fontSize: 10.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  context.tr('Aucune catégorie disponible'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dashboardSubtitleColor(isDark),
                    fontSize: 10.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildTopFiveCategoryCard({
      required String title,
      required List<DistributionEntry> entries,
      required String entryKeyPrefix,
    }) {
      if (entries.isEmpty) {
        return buildEmptyCategoryCard(title);
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111E34) : const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDark ? const Color(0xFF22304B) : const Color(0xFFE6ECF5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dashboardTitleColor(isDark),
                  fontSize: 10.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: List.generate(
                  entries.length,
                  (index) {
                    final entry = entries[index];
                    final entryKey = '$entryKeyPrefix-$index';
                    final exposureLabel = _getExposureLabel(entry.label);
                    final color =
                        grossTopFivePalette[index % grossTopFivePalette.length];
                    final targetWidth = entry.percentage <= 0
                        ? 0.015
                        : entry.percentage.clamp(0.06, 1.0).toDouble();
                    final isActive = _activeEntryKey == entryKey;

                    return Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: targetWidth),
                        duration: Duration(milliseconds: 420 + (index * 110)),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedWidth, _) {
                          final progress = targetWidth <= 0
                              ? 0.0
                              : (animatedWidth / targetWidth)
                                  .clamp(0.0, 1.0)
                                  .toDouble();

                          return Opacity(
                            opacity: 0.55 + (progress * 0.45),
                            child: Transform.translate(
                              offset: Offset((1 - progress) * 10, 0),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == entries.length - 1 ? 0 : 6,
                                ),
                                child: MouseRegion(
                                  onEnter: (_) => setState(
                                    () => _activeEntryKey = entryKey,
                                  ),
                                  onExit: (_) {
                                    if (_activeEntryKey == entryKey) {
                                      setState(() => _activeEntryKey = null);
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              exposureLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: dashboardTitleColor(
                                                  isDark,
                                                ),
                                                fontSize: 8.6,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _precisePercentLabel(
                                              entry.percentage,
                                            ),
                                            style: TextStyle(
                                              color: dashboardSubtitleColor(
                                                isDark,
                                              ),
                                              fontSize: 7.6,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOut,
                                        transform: Matrix4.translationValues(
                                          0,
                                          isActive ? -1 : 0,
                                          0,
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          child: Stack(
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                height: isActive ? 12 : 10,
                                                color: barTrackColor,
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: animatedWidth,
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  height: isActive ? 12 : 10,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        color,
                                                        color.withValues(
                                                          alpha: isActive
                                                              ? 0.82
                                                              : 0.62,
                                                        ),
                                                      ],
                                                    ),
                                                    boxShadow: isActive
                                                        ? [
                                                            BoxShadow(
                                                              color: color
                                                                  .withValues(
                                                                alpha: 0.18,
                                                              ),
                                                              blurRadius: 8,
                                                              offset:
                                                                  const Offset(
                                                                0,
                                                                2,
                                                              ),
                                                            ),
                                                          ]
                                                        : const [],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      SizedBox(
                                        height: 14,
                                        child: FittedBox(
                                          alignment: Alignment.centerLeft,
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            isActive
                                                ? _fullAmountValue(
                                                    entry.amount,
                                                  )
                                                : _compactDisplayAmount(
                                                    entry.amount,
                                                  ),
                                            style: TextStyle(
                                              color: dashboardSubtitleColor(
                                                isDark,
                                              ),
                                              fontSize: 6.8,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    String shortExposureLabel(String raw) {
      switch (dashboardExposureLabel(raw)) {
        case 'organismes pub. hors Adm c':
          return context.tr('Org. publics');
        case 'Expositions sur les BMD':
          return 'BMD';
        case 'institutions financières':
          return context.tr('Institutions fin.');
        case 'clientèle de détail':
          return context.tr('Clientèle détail');
        case "prêts garantis par l'immo R":
          return context.tr('Immo R');
        case "prêts garantis par l'immo C":
          return context.tr('Immo C');
        case 'créances en souffrance':
          return context.tr('En souffrance');
        case 'créances à risque élevé':
          return context.tr('Risque élevé');
        default:
          return _getExposureLabel(raw);
      }
    }

    Widget buildTopFiveRwaBarCard({
      required String title,
      required List<DistributionEntry> entries,
    }) {
      if (entries.isEmpty) {
        return buildEmptyCategoryCard(title);
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111E34) : const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDark ? const Color(0xFF22304B) : const Color(0xFFE6ECF5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dashboardTitleColor(isDark),
                  fontSize: 10.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(entries.length, (index) {
                  final entry = entries[index];
                  final barKey = 'rwa-vertical-$index';
                  final isActive = _activeEntryKey == barKey;
                  final label = _getExposureLabel(entry.label);
                  final color =
                      rwaTopFivePalette[index % rwaTopFivePalette.length];
                  final fillRatio = entry.percentage
                      .clamp(
                        0.0,
                        1.0,
                      )
                      .toDouble();

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: index == entries.length - 1 ? 0 : 4,
                      ),
                      child: MouseRegion(
                        onEnter: (_) =>
                            setState(() => _activeEntryKey = barKey),
                        onExit: (_) {
                          if (_activeEntryKey == barKey) {
                            setState(() => _activeEntryKey = null);
                          }
                        },
                        child: AnimatedScale(
                          scale: isActive ? 1.025 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            transform: Matrix4.translationValues(
                              0,
                              isActive ? -3 : 0,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 24,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        isActive
                                            ? _fullAmountValue(entry.amount)
                                            : _compactDisplayAmount(
                                                entry.amount,
                                              ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isActive
                                              ? dashboardTitleColor(isDark)
                                              : dashboardTitleColor(
                                                  isDark,
                                                ).withValues(alpha: 0.88),
                                          fontSize: 6.7,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final availableHeight =
                                          constraints.maxHeight.isFinite
                                              ? constraints.maxHeight
                                              : 180.0;
                                      final targetHeight = fillRatio <= 0
                                          ? 0.0
                                          : math.max(
                                              availableHeight * fillRatio,
                                              16.0,
                                            );
                                      final hoverHeight = isActive
                                          ? math.min(
                                              availableHeight,
                                              targetHeight + 10,
                                            )
                                          : targetHeight;

                                      return Align(
                                        alignment: Alignment.bottomCenter,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          curve: Curves.easeOut,
                                          width: isActive ? 38 : 34,
                                          height: availableHeight,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            child: Stack(
                                              alignment: Alignment.bottomCenter,
                                              children: [
                                                Positioned.fill(
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: barTrackColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (fillRatio > 0)
                                                  Positioned(
                                                    left: 0,
                                                    right: 0,
                                                    bottom: 0,
                                                    child:
                                                        TweenAnimationBuilder<
                                                            double>(
                                                      tween: Tween(
                                                        begin: 0,
                                                        end: hoverHeight,
                                                      ),
                                                      duration: Duration(
                                                        milliseconds:
                                                            420 + (index * 110),
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      builder: (
                                                        context,
                                                        animatedHeight,
                                                        _,
                                                      ) {
                                                        return DecoratedBox(
                                                          decoration:
                                                              BoxDecoration(
                                                            gradient:
                                                                LinearGradient(
                                                              begin: Alignment
                                                                  .topCenter,
                                                              end: Alignment
                                                                  .bottomCenter,
                                                              colors: [
                                                                color
                                                                    .withValues(
                                                                  alpha: isActive
                                                                      ? 1
                                                                      : 0.96,
                                                                ),
                                                                color
                                                                    .withValues(
                                                                  alpha: isActive
                                                                      ? 0.92
                                                                      : 0.82,
                                                                ),
                                                              ],
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              2,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: color
                                                                    .withValues(
                                                                  alpha: isActive
                                                                      ? 0.30
                                                                      : 0.22,
                                                                ),
                                                                blurRadius:
                                                                    isActive
                                                                        ? 12
                                                                        : 8,
                                                                offset: Offset(
                                                                  0,
                                                                  isActive
                                                                      ? 5
                                                                      : 3,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: SizedBox(
                                                            height:
                                                                animatedHeight,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  shortExposureLabel(label),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isActive
                                        ? dashboardTitleColor(isDark)
                                        : dashboardTitleColor(
                                            isDark,
                                          ).withValues(alpha: 0.9),
                                    fontSize: 7.7,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _precisePercentLabel(entry.percentage),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isActive
                                        ? color
                                        : dashboardSubtitleColor(isDark),
                                    fontSize: 7.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    }

    return DashboardPanel(
      title: "Repartition de l'exposition par catégorie",
      subtitle: '',
      child: SizedBox(
        height: 308,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: buildTopFiveCategoryCard(
                title: "Top 5 de l'exposition totale brute",
                entries: visibleGrossEntries,
                entryKeyPrefix: 'gross',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildTopFiveRwaBarCard(
                title: 'Top 5 du RWA total par catégorie',
                entries: visibleRwaEntries,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getExposureLabel(String label) {
    const exposureLabels = {
      'sovereign': 'Souverains',
      'public_admin': 'Organismes pub. hors Adm c',
      'bmd': 'Expositions sur les BMD',
      'financial': 'Institutions financières',
      'corporate': 'Entreprises',
      'retail': 'Clientèle de détail',
      'real_estate_r': "Prêts garantis par l'immobilier R",
      'real_estate_c': "Prêts garantis par l'immobilier C",
      'impaired': 'Créances en souffrance',
      'high_risk': 'Créances à risque élevé',
      'other_assets': 'Autres actifs',
      'off_balance': 'Hors bilan',
      'souverains': 'Souverains',
      'organismes pub. hors Adm c': 'Organismes pub. hors Adm c',
      'Expositions sur les BMD': 'Expositions sur les BMD',
      'institutions financières': 'Institutions financières',
      'entreprises': 'Entreprises',
      'clientèle de détail': 'Clientèle de détail',
      "prêts garantis par l'immo R": "Prêts garantis par l'immo R",
      "prêts garantis par l'immo C": "Prêts garantis par l'immo C",
      'créances en souffrance': 'Créances en souffrance',
      'créances à risque élevé': 'Créances à risque élevé',
      'autres actifs': 'Autres actifs',
      'Hors bilan': 'Hors bilan',
    };

    // Cette table protège l'affichage contre les variantes de libellés entrantes.
    return AppLocalizations.translate(exposureLabels[label] ?? label);
  }

  IconData _getExposureIcon(String raw) {
    switch (dashboardExposureLabel(raw)) {
      case 'souverains':
        return Icons.account_balance_outlined;
      case 'organismes pub. hors Adm c':
        return Icons.corporate_fare_outlined;
      case 'Expositions sur les BMD':
        return Icons.public_outlined;
      case 'institutions financières':
        return Icons.account_balance_outlined;
      case 'entreprises':
        return Icons.business_center_outlined;
      case 'clientèle de détail':
        return Icons.groups_2_outlined;
      case "prêts garantis par l'immo R":
        return Icons.home_outlined;
      case "prêts garantis par l'immo C":
        return Icons.house_outlined;
      case 'créances en souffrance':
        return Icons.warning_amber_rounded;
      case 'créances à risque élevé':
        return Icons.change_history_outlined;
      case 'autres actifs':
        return Icons.inventory_2_outlined;
      case 'Hors bilan':
        return Icons.blur_circular_outlined;
      default:
        return Icons.stacked_bar_chart_rounded;
    }
  }
}

/// Carte qui affiche la répartition des techniques CRM.
class _CrmDonutCard extends StatefulWidget {
  const _CrmDonutCard({
    required this.entries,
    required this.coveredRatio,
  });

  final List<DistributionEntry> entries;
  final double coveredRatio;

  @override
  State<_CrmDonutCard> createState() => _CrmDonutCardState();
}

/// Etat interne du donut CRM et de ses interactions.
class _CrmDonutCardState extends State<_CrmDonutCard> {
  int? _hoveredIndex;
  int? _selectedIndex;

  Color _getCrmColor(String label) {
    switch (label.toLowerCase()) {
      case 'crm financé':
      case 'crm finance':
      case 'crm financee':
      case 'financed':
      case 'financé':
        return const Color(0xFF2D6CDF); // Bleu
      case 'crm non financé':
      case 'crm non finance':
      case 'crm non financee':
      case 'unfinanced':
      case 'non financé':
        return const Color(0xFFE24A4A); // Rouge
      case 'sans crm':
      case 'aucune':
      case 'no crm':
      case 'pas de crm':
        return const Color(0xFF00C853); // Vert pur
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getCrmLabel(String label) {
    switch (label.toLowerCase()) {
      case 'crm financé':
      case 'crm finance':
      case 'crm financee':
      case 'financed':
      case 'financé':
        return AppLocalizations.translate('CRM financee');
      case 'crm non financé':
      case 'crm non finance':
      case 'crm non financee':
      case 'unfinanced':
      case 'non financé':
        return AppLocalizations.translate('CRM non financee');
      case 'sans crm':
      case 'aucune':
      case 'no crm':
      case 'pas de crm':
        return AppLocalizations.translate('Aucune');
      default:
        return label;
    }
  }

  String _getCrmChipLabel(String label) {
    switch (label.toLowerCase()) {
      case 'crm financé':
      case 'crm finance':
      case 'crm financee':
      case 'financed':
      case 'financé':
        return AppLocalizations.translate('CRM financee');
      case 'crm non financé':
      case 'crm non finance':
      case 'crm non financee':
      case 'unfinanced':
      case 'non financé':
        return AppLocalizations.translate('CRM non financee');
      case 'sans crm':
      case 'aucune':
      case 'no crm':
      case 'pas de crm':
        return AppLocalizations.translate('Aucune');
      default:
        return label;
    }
  }

  List<_CrmSegmentLayout> _buildSegments() {
    var startAngle = -math.pi / 2;
    final segments = <_CrmSegmentLayout>[];

    for (var index = 0; index < widget.entries.length; index++) {
      final entry = widget.entries[index];
      final color = _getCrmColor(entry.label);
      final sweepAngle = math.max(0.0, entry.percentage * math.pi * 2);

      segments.add(
        _CrmSegmentLayout(
          index: index,
          entry: entry,
          color: color,
          startAngle: startAngle,
          sweepAngle: sweepAngle,
        ),
      );

      startAngle += sweepAngle;
    }

    return segments;
  }

  int? _defaultActiveIndex() {
    if (widget.entries.isEmpty) {
      return null;
    }

    var bestIndex = 0;
    var bestPercentage = widget.entries.first.percentage;
    for (var index = 1; index < widget.entries.length; index++) {
      final candidate = widget.entries[index].percentage;
      if (candidate > bestPercentage) {
        bestPercentage = candidate;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segments = _buildSegments();
    final resolvedActiveIndex =
        _hoveredIndex ?? _selectedIndex ?? _defaultActiveIndex();
    final boundedActiveIndex = resolvedActiveIndex == null
        ? null
        : math.min(
            math.max(resolvedActiveIndex, 0),
            widget.entries.length - 1,
          );
    final activeEntry = resolvedActiveIndex == null
        ? null
        : widget.entries[boundedActiveIndex!];

    return DashboardPanel(
      title: 'Répartition totale par type de CRM',
      subtitle: '',
      child: SizedBox(
        height: 146,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 102,
                  height: 102,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(102),
                        painter: _CrmDonutPainter(
                          segments: segments,
                          activeIndex: boundedActiveIndex,
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF101C32) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0x22040A16)
                                  : const Color(0x120F172A),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: activeEntry == null
                            ? null
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dashboardCompactPercent(
                                      activeEntry.percentage,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: dashboardTitleColor(isDark),
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getCrmLabel(activeEntry.label),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: dashboardSubtitleColor(isDark),
                                      fontSize: 5.0,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 24,
              child: Row(
                children: widget.entries.asMap().entries.map((item) {
                  final index = item.key;
                  final entry = item.value;
                  final color = _getCrmColor(entry.label);
                  final isActive = boundedActiveIndex == index;
                  final titleColor =
                      isActive ? Colors.white : dashboardTitleColor(isDark);
                  final valueColor = isActive ? Colors.white : color;
                  final markerColor = isActive ? Colors.white : color;

                  return Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveredIndex = index),
                      onExit: (_) {
                        if (_hoveredIndex == index) {
                          setState(() => _hoveredIndex = null);
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(
                            left: index == 0 ? 0 : 3,
                            right: index == widget.entries.length - 1 ? 0 : 3,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withValues(alpha: isDark ? 0.90 : 0.92)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: isActive
                                  ? color
                                  : color.withValues(
                                      alpha: isDark ? 0.58 : 0.32,
                                    ),
                              width: isActive ? 1.35 : 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: color.withValues(
                                        alpha: isDark ? 0.34 : 0.28,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : kElevationToShadow[10],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: 4.5,
                                    height: 4.5,
                                    decoration: BoxDecoration(
                                      color: markerColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _getCrmChipLabel(entry.label),
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                          color: titleColor,
                                          fontSize: 7.2,
                                          fontWeight: FontWeight.w800,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  dashboardCompactPercent(entry.percentage),
                                  style: TextStyle(
                                    color: valueColor,
                                    fontSize: 6.9,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte qui affiche le top pays contributeurs.
class _CountriesCard extends StatefulWidget {
  const _CountriesCard({
    required this.entries,
    required this.displayCurrency,
  });

  final List<DistributionEntry> entries;
  final String displayCurrency;

  @override
  State<_CountriesCard> createState() => _CountriesCardState();
}

class _CountriesCardState extends State<_CountriesCard> {
  int? _activeIndex;

  String _shortAmount(double value) {
    return compactCurrencyForDisplay(
      value,
      toCurrency: widget.displayCurrency,
    );
  }

  String _fullAmount(double value) {
    return formatCurrencyForDisplay(
      value,
      toCurrency: widget.displayCurrency,
    );
  }

  String _countryContributionLabel(double percentage) {
    if (percentage >= 0.25) {
      return AppLocalizations.translate('Contribution principale');
    }
    if (percentage >= 0.10) {
      return AppLocalizations.translate('Contribution notable');
    }
    return AppLocalizations.translate('Contribution secondaire');
  }

  InlineSpan _countryTooltipMessage(
    DistributionEntry entry,
    bool isDark,
  ) {
    final percent = dashboardCompactPercent(entry.percentage);
    final amount = _fullAmount(entry.amount);
    final intensity = _countryContributionLabel(entry.percentage);
    final tooltipTitleColor =
        isDark ? const Color(0xFFF8FBFF) : const Color(0xFF173055);
    final tooltipSubtitleColor =
        isDark ? const Color(0xFFB8C9E6) : const Color(0xFF5E759A);
    final tooltipAccent =
        isDark ? const Color(0xFFFFB86B) : const Color(0xFFF28C28);

    return TextSpan(
      children: [
        TextSpan(
          text: '${entry.label}\n',
          style: TextStyle(
            color: tooltipTitleColor,
            fontSize: 9.2,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        TextSpan(
          text: '$amount\n',
          style: TextStyle(
            color: tooltipTitleColor,
            fontSize: 8.8,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        TextSpan(
          text:
              '${AppLocalizations.translate("{{percent}} de l\\'encours total", args: {
                'percent': percent
              })}\n',
          style: TextStyle(
            color: tooltipSubtitleColor,
            fontSize: 8.0,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        TextSpan(
          text: intensity,
          style: TextStyle(
            color: tooltipAccent,
            fontSize: 7.7,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardPanel(
      title: "Top 5 de l'encours total par pays UEMOA",
      subtitle: '',
      child: SizedBox(
        height: 258,
        child: Column(
          children: List.generate(
            widget.entries.length,
            (index) {
              final entry = widget.entries[index];
              final color = dashboardCountryBarColor(index);
              final lowValue = entry.percentage <= 0.08;
              final targetWidth = entry.percentage <= 0
                  ? 0.015
                  : entry.percentage.clamp(0.06, 1.0).toDouble();
              final isActive = _activeIndex == index;
              final rowSurface = isActive
                  ? (isDark ? const Color(0xFF152842) : const Color(0xFFF5F9FF))
                  : Colors.transparent;
              final rowBorder = isActive
                  ? color.withValues(alpha: isDark ? 0.34 : 0.22)
                  : Colors.transparent;
              final trackColor =
                  isDark ? const Color(0xFF14233D) : const Color(0xFFEEF3F9);
              final tooltipFillColor =
                  isDark ? const Color(0xFF122038) : const Color(0xFFFFF7F0);
              final tooltipBorderColor =
                  isDark ? const Color(0xFFB97D49) : const Color(0xFFFFC58B);
              final tooltipTextColor =
                  isDark ? const Color(0xFFF8FBFF) : const Color(0xFF173055);
              final fillOpacity = lowValue ? 0.60 : (index >= 3 ? 0.78 : 1.0);
              final percentColor =
                  isActive ? color : dashboardTitleColor(isDark);
              final labelColor = isActive
                  ? color.withValues(alpha: isDark ? 0.96 : 0.88)
                  : dashboardTitleColor(isDark);

              return Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: targetWidth),
                  duration: Duration(milliseconds: 420 + (index * 110)),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedWidth, _) {
                    final progress = (animatedWidth / targetWidth)
                        .clamp(0.0, 1.0)
                        .toDouble();

                    return Opacity(
                      opacity: 0.55 + (progress * 0.45),
                      child: Transform.translate(
                        offset: Offset((1 - progress) * 10, 0),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: index == widget.entries.length - 1 ? 0 : 5,
                          ),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _activeIndex = index),
                            onExit: (_) {
                              if (_activeIndex == index) {
                                setState(() => _activeIndex = null);
                              }
                            },
                            child: Tooltip(
                              richMessage: _countryTooltipMessage(
                                entry,
                                isDark,
                              ),
                              waitDuration: const Duration(milliseconds: 220),
                              preferBelow: false,
                              verticalOffset: 28,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: tooltipFillColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: tooltipBorderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? const Color(0x24040A16)
                                        : const Color(0x14B86A24),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              textStyle: TextStyle(
                                color: tooltipTextColor,
                                fontSize: 8.0,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                transform: Matrix4.translationValues(
                                  isActive ? 3 : 0,
                                  isActive ? -1 : 0,
                                  0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: rowSurface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: rowBorder,
                                    width: isActive ? 1.15 : 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 5),
                                          ),
                                        ]
                                      : const [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entry.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: labelColor,
                                              fontSize: 7.6,
                                              fontWeight: FontWeight.w800,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          dashboardCompactPercent(
                                            entry.percentage,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: percentColor,
                                            fontSize: 7.1,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      curve: Curves.easeOut,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: Stack(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              height: isActive ? 12 : 10,
                                              color: trackColor,
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: animatedWidth,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                height: isActive ? 12 : 10,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      color.withValues(
                                                        alpha: isActive
                                                            ? math.min(
                                                                1.0,
                                                                fillOpacity +
                                                                    0.12,
                                                              )
                                                            : fillOpacity,
                                                      ),
                                                      Color.lerp(
                                                        color,
                                                        Colors.white,
                                                        lowValue ? 0.36 : 0.18,
                                                      )!
                                                          .withValues(
                                                        alpha: isActive
                                                            ? math.min(
                                                                1.0,
                                                                fillOpacity +
                                                                    0.12,
                                                              )
                                                            : fillOpacity,
                                                      ),
                                                    ],
                                                  ),
                                                  boxShadow: isActive
                                                      ? [
                                                          BoxShadow(
                                                            color: color
                                                                .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                            blurRadius: 10,
                                                            offset:
                                                                const Offset(
                                                              0,
                                                              2,
                                                            ),
                                                          ),
                                                        ]
                                                      : const [],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    SizedBox(
                                      width: double.infinity,
                                      height: isActive ? 10 : 8,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            isActive
                                                ? _fullAmount(entry.amount)
                                                : _shortAmount(entry.amount),
                                            style: TextStyle(
                                              color:
                                                  dashboardSubtitleColor(isDark)
                                                      .withValues(
                                                alpha: isActive
                                                    ? 1
                                                    : (lowValue ? 0.78 : 0.94),
                                              ),
                                              fontSize: isActive ? 6.6 : 6.4,
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Carte qui affiche la jauge de densité RWA.
class _CreditGaugeCard extends StatefulWidget {
  const _CreditGaugeCard({
    required this.densityRwa,
    this.compact = false,
  });

  final double densityRwa;
  final bool compact;

  @override
  State<_CreditGaugeCard> createState() => _CreditGaugeCardState();
}

/// Etat interne qui anime légèrement la jauge pour la rendre plus vivante.
class _CreditGaugeCardState extends State<_CreditGaugeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardHeight = widget.compact ? 172.0 : 335.0;
    final diskSize = widget.compact ? 48.0 : 96.0;
    // La densité RWA arrive déjà en pourcentage métier.
    final baseValue = widget.densityRwa.clamp(0.0, 150.0).toDouble();
    final displayValue = baseValue;
    final densityLabel = _getDensityLabel(displayValue);
    final activeLevel = _getDensityLevel(displayValue);
    final activeColor = _getDensityColor(displayValue);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = Curves.easeInOut.transform(_pulseController.value);

        if (widget.compact) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: dashboardPanelColor(isDark),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: dashboardPanelBorder(isDark)),
              boxShadow: dashboardPanelShadow(isDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Densité RWA',
                  style: TextStyle(
                    color: dashboardTitleColor(isDark),
                    fontSize: 9.9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'RWA total / Exposition totale brute',
                  style: TextStyle(
                    color: dashboardSubtitleColor(isDark),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 188,
                            child: CustomPaint(
                              painter: _GaugePainter(
                                value: displayValue,
                                isDark: isDark,
                                pulse: pulse,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compactDiskTop =
                                      (constraints.maxHeight * 0.80) -
                                          (diskSize / 2);

                                  return Stack(
                                    children: [
                                      Positioned(
                                        top: compactDiskTop,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Container(
                                            width: diskSize,
                                            height: diskSize,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF101C32)
                                                  : const Color(0xFFFFFFFF),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF243756)
                                                    : const Color(0xFFE8ECF4),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isDark
                                                      ? const Color(0x33040A16)
                                                      : const Color(0x180F172A),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${displayValue.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    color: dashboardTitleColor(
                                                      isDark,
                                                    ),
                                                    fontSize: 9.4,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.8,
                                                    height: 0.9,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  densityLabel,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: activeColor,
                                                    fontSize: 5.3,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _DensityRiskLegend(
                        activeLevel: activeLevel,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return DashboardPanel(
          title: 'Densité RWA du portefeuille',
          subtitle:
              'RWA total / Exposition totale brute',
          child: SizedBox(
            height: cardHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _GaugePainter(
                value: displayValue,
                isDark: isDark,
                pulse: pulse,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final diskTop =
                      (constraints.maxHeight * 0.80) - (diskSize / 2);

                  return Stack(
                    children: [
                      Positioned(
                        top: diskTop,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            // Le disque suit le vrai centre de la jauge pour aligner proprement le pointeur.
                            width: diskSize,
                            height: diskSize,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF101C32)
                                  : const Color(0xFFFFFFFF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF243756)
                                    : const Color(0xFFE8ECF4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? const Color(0x33040A16)
                                      : const Color(0x180F172A),
                                  blurRadius: 10 + (pulse * 4),
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF234A84)
                                      .withValues(alpha: isDark ? 0.10 : 0.05),
                                  blurRadius: 18 + (pulse * 8),
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${displayValue.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: dashboardTitleColor(isDark),
                                    fontSize: widget.compact ? 12 : 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.4,
                                    height: 0.85,
                                  ),
                                ),
                                SizedBox(height: widget.compact ? 4 : 6),
                                Text(
                                  densityLabel,
                                  style: TextStyle(
                                    color: activeColor,
                                    fontSize: widget.compact ? 7.4 : 9.5,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    height: 1,
                                  ),
                                ),
                                if (!widget.compact) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'RWA / Exposition brute',
                                    style: TextStyle(
                                      color: dashboardSubtitleColor(isDark),
                                      fontSize: 7,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _getDensityLabel(double value) {
    if (value <= 50) {
      return 'Risque faible';
    }
    if (value <= 100) {
      return 'Risque moyen';
    }
    return 'Risque élevé';
  }

  _DensityRiskLevel _getDensityLevel(double value) {
    if (value <= 50) {
      return _DensityRiskLevel.low;
    }
    if (value <= 100) {
      return _DensityRiskLevel.medium;
    }
    return _DensityRiskLevel.high;
  }

  Color _getDensityColor(double value) {
    return switch (_getDensityLevel(value)) {
      _DensityRiskLevel.low => const Color(0xFF2FBF71),
      _DensityRiskLevel.medium => const Color(0xFFF59E0B),
      _DensityRiskLevel.high => const Color(0xFFE04F5F),
    };
  }
}

enum _DensityRiskLevel {
  low,
  medium,
  high,
}

class _DensityRiskLegend extends StatefulWidget {
  const _DensityRiskLegend({
    required this.activeLevel,
    required this.isDark,
  });

  final _DensityRiskLevel activeLevel;
  final bool isDark;

  @override
  State<_DensityRiskLegend> createState() => _DensityRiskLegendState();
}

class _DensityRiskLegendState extends State<_DensityRiskLegend> {
  _DensityRiskLevel? _hoveredLevel;

  @override
  Widget build(BuildContext context) {
    final titleColor = dashboardTitleColor(widget.isDark);
    final mutedColor = dashboardSubtitleColor(widget.isDark);
    final displayedLevel = _hoveredLevel ?? widget.activeLevel;
    final levels = [
      (
        level: _DensityRiskLevel.low,
        label: context.tr('Faible'),
        helper: context.tr('peu risqué'),
        headline: context.tr('Risque faible (densité)'),
        detail: context.tr(
          'Le risque faible désigne un portefeuille dont la consommation en RWA reste modérée. Il traduit en général une qualité de crédit saine et une pression limitée sur le capital réglementaire.',
        ),
        advice: context.tr(
          'Maintenir la qualité des contreparties, préserver les garanties efficaces et suivre les concentrations par secteur.',
        ),
        color: const Color(0xFF2FBF71),
        icon: Icons.verified_user_outlined,
      ),
      (
        level: _DensityRiskLevel.medium,
        label: context.tr('Moyen'),
        helper: context.tr('normal'),
        headline: context.tr('Risque moyen (densité)'),
        detail: context.tr(
          'Le risque moyen correspond à une situation équilibrée, mais plus sensible aux variations de qualité de crédit. Il nécessite une surveillance régulière car les RWA peuvent augmenter plus rapidement en cas de dégradation.',
        ),
        advice: context.tr(
          'Renforcer le suivi des expositions sensibles, revoir les couvertures disponibles et anticiper les besoins en capital.',
        ),
        color: const Color(0xFFF59E0B),
        icon: Icons.account_balance_outlined,
      ),
      (
        level: _DensityRiskLevel.high,
        label: context.tr('Élevé'),
        helper: context.tr('alerte'),
        headline: context.tr('Risque élevé (densité)'),
        detail: context.tr(
          'Le risque élevé décrit un portefeuille plus exigeant en capital et plus exposé aux détériorations de notation. Il signale une vulnérabilité accrue et appelle une attention prioritaire sur les expositions concernées.',
        ),
        advice: context.tr(
          'Prioriser les actions de réduction de RWA, sécuriser les expositions les plus lourdes et renforcer rapidement les mécanismes de couverture.',
        ),
        color: const Color(0xFFE04F5F),
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Interprétation'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 7.1,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          for (var index = 0; index < levels.length; index++) ...[
            Tooltip(
              richMessage: TextSpan(
                children: [
                  TextSpan(
                    text: '${levels[index].headline} :\n',
                    style: TextStyle(
                      color: levels[index].color,
                      fontSize: 10.2,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  TextSpan(
                    text: levels[index].detail,
                    style: TextStyle(
                      color: widget.isDark
                          ? const Color(0xFFF8FBFF)
                          : const Color(0xFF173055),
                      fontSize: 9.4,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  TextSpan(
                    text: '\n\n${context.tr('Astuce')} :\n',
                    style: TextStyle(
                      color: widget.isDark
                          ? const Color(0xFFB8C9E6)
                          : const Color(0xFF5E759A),
                      fontSize: 9.4,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  TextSpan(
                    text: levels[index].advice,
                    style: TextStyle(
                      color: widget.isDark
                          ? const Color(0xFFF8FBFF)
                          : const Color(0xFF173055),
                      fontSize: 9.4,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              waitDuration: const Duration(milliseconds: 120),
              showDuration: const Duration(seconds: 5),
              preferBelow: false,
              verticalOffset: 10,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF122038) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: levels[index]
                      .color
                      .withValues(alpha: widget.isDark ? 0.30 : 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.24 : 0.12,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() {
                  _hoveredLevel = levels[index].level;
                }),
                onExit: (_) => setState(() {
                  _hoveredLevel = null;
                }),
                child: _DensityRiskTile(
                  active: levels[index].level == displayedLevel,
                  current: levels[index].level == widget.activeLevel,
                  color: levels[index].color,
                  icon: levels[index].icon,
                  label: levels[index].label,
                  helper: levels[index].helper,
                  mutedColor: mutedColor,
                  isDark: widget.isDark,
                ),
              ),
            ),
            if (index != levels.length - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _DensityRiskTile extends StatelessWidget {
  const _DensityRiskTile({
    required this.active,
    required this.current,
    required this.color,
    required this.icon,
    required this.label,
    required this.helper,
    required this.mutedColor,
    required this.isDark,
  });

  final bool active;
  final bool current;
  final Color color;
  final IconData icon;
  final String label;
  final String helper;
  final Color mutedColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      scale: active ? 1.02 : 1,
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: isDark ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: current || active ? color : color.withValues(alpha: 0.18),
          width: current ? 1.2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.24 : 0.18),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: current ? 6 : 4,
            height: current ? 6 : 4,
            decoration: BoxDecoration(
              color: active ? Colors.white : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            icon,
            color: active ? Colors.white : color,
            size: 11,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : color,
                    fontSize: 6.1,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? Colors.white.withValues(alpha: 0.86)
                        : mutedColor.withValues(alpha: isDark ? 0.94 : 0.88),
                    fontSize: 5.2,
                    fontWeight: FontWeight.w700,
                    height: 1,
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
}

/// Ligne de légende avec valeur et indicateur visuel.
class _LegendStatTile extends StatelessWidget {
  const _LegendStatTile({
    required this.color,
    required this.title,
    required this.value,
    required this.active,
  });

  final Color color;
  final String title;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? (isDark ? const Color(0xFF162745) : const Color(0xFFF5F8FF))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.32) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: dashboardTitleColor(isDark),
                fontSize: 8.9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: dashboardSubtitleColor(isDark),
              fontSize: 8.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de plage de valeurs utilisée sous les graphiques.
class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Tooltip personnalisé utilisé sur les graphiques du dashboard.
class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.width,
    required this.title,
    required this.value,
    required this.secondary,
  });

  final double width;
  final String title;
  final String value;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101C32) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: dashboardPanelBorder(isDark)),
          boxShadow: dashboardPanelShadow(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dashboardTitleColor(isDark),
                fontSize: 8.7,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: dashboardTitleColor(isDark),
                fontSize: 9.8,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              secondary,
              style: TextStyle(
                color: dashboardSubtitleColor(isDark),
                fontSize: 8.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter qui dessine la grille du graphique horizontal des expositions.
class _ExposureHorizontalGridPainter extends CustomPainter {
  const _ExposureHorizontalGridPainter({
    required this.isDark,
    required this.ticks,
    required this.axisMax,
  });

  final bool isDark;
  final List<double> ticks;
  final double axisMax;

  double _axisPosition(double value) {
    final safeAxisMax = axisMax <= 0 ? 1.0 : axisMax;
    final clampedValue = value.clamp(0.0, safeAxisMax).toDouble();
    return clampedValue / safeAxisMax;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark
          ? const Color(0xFF22304B).withValues(alpha: 0.42)
          : const Color(0xFFD9E2EF)
      ..strokeWidth = 0.8;

    for (final tick in ticks) {
      final x = size.width * _axisPosition(tick);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExposureHorizontalGridPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.axisMax != axisMax ||
        oldDelegate.ticks != ticks;
  }
}

/// Painter qui dessine le donut du CRM.
class _CrmDonutPainter extends CustomPainter {
  const _CrmDonutPainter({
    required this.segments,
    required this.activeIndex,
  });

  final List<_CrmSegmentLayout> segments;
  final int? activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 24.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 22;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..color = const Color(0xFFE8EEF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    for (final segment in segments) {
      if (segment.sweepAngle <= 0) {
        continue;
      }

      final isActive = activeIndex == segment.index;
      final hasActiveSegment = activeIndex != null;
      final segmentOpacity = hasActiveSegment && !isActive ? 0.42 : 1.0;

      final paint = Paint()
        ..color = segment.color.withValues(alpha: segmentOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;

      canvas.drawArc(
        rect,
        segment.startAngle,
        segment.sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrmDonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.activeIndex != activeIndex;
  }
}

class _CrmSegmentLayout {
  const _CrmSegmentLayout({
    required this.index,
    required this.entry,
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
  });

  final int index;
  final DistributionEntry entry;
  final Color color;
  final double startAngle;
  final double sweepAngle;
}

/// Painter qui dessine la jauge de qualité de crédit.
class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.value,
    required this.isDark,
    required this.pulse,
  });

  final double value;
  final bool isDark;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    // Le cadran principal est dimensionné à partir de la place réellement disponible.
    final centerX = size.width / 2;
    final arcWidth = math.min(size.width - 64, size.height * 3.2);
    final rect = Rect.fromCenter(
      center: Offset(centerX, size.height * 0.84),
      width: arcWidth,
      height: arcWidth,
    );
    const minValue = 0.0;
    const maxValue = 150.0;
    const startAngle = math.pi * 1.025;
    const sweepAngle = math.pi * 0.95;
    const strokeWidth = 28.0;
    final normalized =
        ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    final activeAngle = startAngle + (sweepAngle * normalized);

    // L'arc de base reste discret pour laisser la priorité à la portion colorée.
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF182842) : const Color(0xFFEDEFF4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, startAngle, sweepAngle, false, basePaint);

    final arcPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: math.pi * 2,
        colors: [
          Color(0xFF2FBF71),
          Color(0xFF2FBF71),
          Color(0xFFF59E0B),
          Color(0xFFE04F5F),
          Color(0xFFE04F5F),
        ],
        stops: [0.0, 0.33, 0.66, 0.86, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    final center = rect.center;
    final radius = rect.width / 2;
    final arcStartPoint = Offset(
      center.dx + math.cos(startAngle) * radius,
      center.dy + math.sin(startAngle) * radius,
    );
    final arcEndPoint = Offset(
      center.dx + math.cos(startAngle + sweepAngle) * radius,
      center.dy + math.sin(startAngle + sweepAngle) * radius,
    );
    final baselinePaint = Paint()
      ..color = isDark
          ? const Color(0xFF121D30).withValues(alpha: 0.78)
          : Colors.white.withValues(alpha: 0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.square;
    final baselineY =
        math.max(arcStartPoint.dy, arcEndPoint.dy) + (strokeWidth * 0.06);
    final baselineStart = Offset(
      arcStartPoint.dx - (strokeWidth * 0.42),
      baselineY,
    );
    final baselineEnd = Offset(
      arcEndPoint.dx + (strokeWidth * 0.42),
      baselineY,
    );

    canvas.drawLine(
      baselineStart,
      baselineEnd,
      baselinePaint,
    );

    // Adaptation fluide de la longueur du pointeur à la taille réelle disponible
    final availableHeight = size.height - 120;
    final pointerLength = math.max(72.0, availableHeight * 0.40);
    const pointerHalfWidth = 7.0;

    // Le pointeur triangulaire vient se caler sur la valeur courante de la jauge.
    final tip = Offset(
      center.dx + math.cos(activeAngle) * (radius - 22),
      center.dy + math.sin(activeAngle) * (radius - 22),
    );
    final pointerBase = Offset(
      center.dx + math.cos(activeAngle) * (radius - pointerLength),
      center.dy + math.sin(activeAngle) * (radius - pointerLength),
    );
    final perpendicular = Offset(-math.sin(activeAngle), math.cos(activeAngle));
    final pointerPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        pointerBase.dx + perpendicular.dx * pointerHalfWidth,
        pointerBase.dy + perpendicular.dy * pointerHalfWidth,
      )
      ..lineTo(
        pointerBase.dx - perpendicular.dx * pointerHalfWidth,
        pointerBase.dy - perpendicular.dy * pointerHalfWidth,
      )
      ..close();

    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = isDark ? const Color(0xFFE8EEF8) : const Color(0xFF252839)
        ..style = PaintingStyle.fill,
    );

    // La cible circulaire rend le point de lecture plus visible que la seule pointe.
    canvas.drawCircle(
      tip,
      18 + (pulse * 5),
      Paint()
        ..color = const Color(0xFF234A84).withValues(alpha: 0.05 + (pulse * 0.05)),
    );
    canvas.drawCircle(
      tip,
      14,
      Paint()..color = const Color(0xFF234A84).withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      tip,
      6,
      Paint()
        ..color = isDark ? const Color(0xFF101C32) : Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      tip,
      4,
      Paint()..color = const Color(0xFF234A84),
    );
    canvas.drawCircle(
      tip,
      8,
      Paint()
        ..color = const Color(0xFF234A84).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    Color tickColor(double tickValue) {
      if (tickValue <= 50) {
        return const Color(0xFF2FBF71);
      }
      if (tickValue <= 100) {
        return const Color(0xFFF59E0B);
      }
      return const Color(0xFFE04F5F);
    }

    final ticks = List.generate(7, (index) {
      final value = index * 25.0;
      final ratio = value / maxValue;
      final angle = startAngle + (sweepAngle * ratio);
      final majorTick = value % 50 == 0;
      final isLastTick = value == maxValue;

      return (
        value: value,
        color: tickColor(value),
        radialOffset: isLastTick
            ? 17.0
            : majorTick
                ? 19.0
                : 24.0,
        tangentOffset: isLastTick ? 6.0 : math.sin(angle) * 2.0,
        rotation: ((angle - (math.pi / 2)) * 0.72).clamp(-0.62, 0.62),
        dashOuter: isLastTick
            ? 18.0
            : majorTick
                ? 18.0
                : 13.0,
      );
    });
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final tick in ticks) {
      // Les graduations clés structurent la lecture en trois zones de risque.
      final tickRatio = (tick.value - minValue) / (maxValue - minValue);
      final tickAngle = startAngle + (sweepAngle * tickRatio);
      final radial = Offset(math.cos(tickAngle), math.sin(tickAngle));
      final tangent = Offset(-math.sin(tickAngle), math.cos(tickAngle));
      // Les tirets sont au bord extérieur de l'arc.
      final dashOuterRadius = radius + (strokeWidth * 0.70);
      final dashInnerRadius = dashOuterRadius - tick.dashOuter;
      final dashStart = Offset(
        center.dx + radial.dx * dashInnerRadius,
        center.dy + radial.dy * dashInnerRadius,
      );
      final dashEnd = Offset(
        center.dx + radial.dx * dashOuterRadius,
        center.dy + radial.dy * dashOuterRadius,
      );
      final adjustedDashStart = tick.value == 0
          ? dashStart.translate(0, -3)
          : tick.value == 150
              ? dashStart.translate(0, -3)
              : dashStart;
      final adjustedDashEnd = tick.value == 0
          ? dashEnd.translate(0, -1)
          : tick.value == 150
              ? dashEnd.translate(0, -1)
              : dashEnd;
      final baseOffset = Offset(
        center.dx +
            radial.dx * (radius + tick.radialOffset) +
            tangent.dx * tick.tangentOffset,
        center.dy +
            radial.dy * (radius + tick.radialOffset) +
            tangent.dy * tick.tangentOffset,
      );
      final offset = tick.value == 150
          ? baseOffset.translate(8, 6)
          : tick.value == 0
              ? baseOffset.translate(-8, 6)
              : baseOffset;
      final rotation = tick.rotation.toDouble();

      canvas.drawLine(
        adjustedDashStart,
        adjustedDashEnd,
        Paint()
          ..color = tick.color.withValues(alpha: 0.95)
          ..strokeWidth = tick.value % 50 == 0 ? 2.2 : 1.6
          ..strokeCap = StrokeCap.round,
      );

      if (tick.value % 50 != 0) {
        continue;
      }

      textPainter.text = TextSpan(
        text: '${tick.value.toInt()}',
        style: TextStyle(
          color: tick.color,
          fontSize: tick.value % 50 == 0 ? 9.4 : 8.3,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();
      final labelRotation = switch (tick.value.toInt()) {
        0 => -0.10,
        50 => -0.44,
        100 => 0.44,
        150 => 0.08,
        _ => tick.rotation.toDouble(),
      };
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(labelRotation);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    final innerRadius = radius - 70;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final innerGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFFA8C7FF).withValues(alpha: 0.12 + (pulse * 0.04)),
                const Color(0xFFA8C7FF).withValues(alpha: 0.0),
              ]
            : [
                const Color(0xFFBFD8FF).withValues(alpha: 0.20 + (pulse * 0.05)),
                const Color(0xFFBFD8FF).withValues(alpha: 0.0),
              ],
      ).createShader(
        Rect.fromLTWH(
          innerRect.left,
          innerRect.top,
          innerRect.width,
          innerRect.height * 0.90,
        ),
      )
      ..style = PaintingStyle.fill;
    final innerFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF193252).withValues(alpha: 0.34 + (pulse * 0.04)),
                const Color(0xFF11213C).withValues(alpha: 0.08),
              ]
            : [
                const Color(0xFFF1F6FF).withValues(alpha: 0.92),
                const Color(0xFFDDEAFF).withValues(alpha: 0.68 + (pulse * 0.04)),
              ],
      ).createShader(
        Rect.fromLTWH(
          innerRect.left,
          innerRect.top,
          innerRect.width,
          innerRect.height,
        ),
      )
      ..style = PaintingStyle.fill;
    final innerShadowPaint = Paint()
      ..color = isDark
          ? const Color.fromARGB(255, 106, 136, 197).withValues(alpha: 0.14)
          : const Color.fromARGB(255, 141, 189, 248).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    // Le fond intérieur reste volontairement en demi-cercle supérieur pour accompagner l'arc principal.
    canvas.drawArc(innerRect, math.pi, math.pi, true, innerFillPaint);
    // Un voile lumineux anime légèrement le fond sans nuire à la lisibilité.
    canvas.drawArc(innerRect, math.pi, math.pi, true, innerGlowPaint);
    // Le contour léger suit la même moitié haute pour garder une lecture propre.
    canvas.drawArc(innerRect, math.pi, math.pi, false, innerShadowPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.isDark != isDark ||
        oldDelegate.pulse != pulse;
  }
}
