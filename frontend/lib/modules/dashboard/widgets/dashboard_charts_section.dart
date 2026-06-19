// Ce fichier affiche la zone centrale avec les graphiques principaux.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/dashboard_models.dart';
import 'dashboard_panel.dart';
import 'dashboard_theme.dart';

/// Zone centrale du dashboard qui regroupe les graphiques principaux.
class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({
    super.key,
    required this.displayCurrency,
    required this.grossCategoryEntries,
    required this.rwaCategoryEntries,
    required this.crmEntries,
    required this.coveredRatio,
  });

  final String displayCurrency;
  final List<DistributionEntry> grossCategoryEntries;
  final List<DistributionEntry> rwaCategoryEntries;
  final List<DistributionEntry> crmEntries;
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
                  child: _CrmDonutCard(
                    entries: crmEntries,
                    coveredRatio: coveredRatio,
                  ),
                ),
              ],
            ),
          ),
        );
        return primaryChartsRow;
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

  String _compactDisplayAmount(double value) {
    return formatCurrencyInDisplayUnit(
      value,
      toCurrency: widget.displayCurrency,
      amountUnit: PortfolioAmountUnitPreference.current,
    );
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
    return formatCurrencyInDisplayUnit(
      value,
      toCurrency: widget.displayCurrency,
      amountUnit: PortfolioAmountUnitPreference.current,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barTrackColor =
        isDark ? const Color(0xFF263C60) : const Color(0xFFE2EAF5);
    final rankedGrossEntries = [...widget.grossEntries]
      ..sort((left, right) => right.amount.compareTo(left.amount));
    final visibleGrossEntries = rankedGrossEntries.take(5).toList();
    final rankedRwaEntries = [...widget.rwaEntries]
      ..sort((left, right) => right.amount.compareTo(left.amount));
    final visibleRwaEntries = rankedRwaEntries.take(5).toList();

    const categoryBarColor = Color(0xFF2563EB);

    Widget buildEmptyCategoryCard(String title) {
      return Container(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
        decoration: BoxDecoration(
          color: dashboardPanelColor(isDark).withValues(
            alpha: isDark ? 0.68 : 1,
          ),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: dashboardPanelBorder(isDark)),
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
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
        decoration: BoxDecoration(
          color: dashboardPanelColor(isDark).withValues(
            alpha: isDark ? 0.68 : 1,
          ),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: dashboardPanelBorder(isDark)),
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
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
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
                    const color = categoryBarColor;
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
                                  onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) setState(() => _activeEntryKey = entryKey);
                                  }),
                                  onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted && _activeEntryKey == entryKey) {
                                      setState(() => _activeEntryKey = null);
                                    }
                                  }),
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
                                                fontSize: 11.2,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _precisePercentLabel(
                                              entry.percentage,
                                            ),
                                            style: const TextStyle(
                                              color: color,
                                              fontSize: 10.2,
                                              fontWeight: FontWeight.w500,
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
                                          borderRadius: BorderRadius.circular(5),
                                          child: Stack(
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                height: isActive ? 16 : 14,
                                                color: barTrackColor,
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: animatedWidth,
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  height: isActive ? 16 : 14,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        color,
                                                        color.withValues(
                                                          alpha: isActive
                                                              ? 0.96
                                                              : 0.82,
                                                        ),
                                                      ],
                                                    ),
                                                    boxShadow: isActive
                                                        ? [
                                                            BoxShadow(
                                                              color: color
                                                                  .withValues(
                                                                alpha: 0.28,
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
                                              fontSize: 9.3,
                                              fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
        decoration: BoxDecoration(
          color: dashboardPanelColor(isDark).withValues(
            alpha: isDark ? 0.68 : 1,
          ),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: dashboardPanelBorder(isDark)),
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
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
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
                  const color = categoryBarColor;
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
                                  height: 21,
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
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                        alpha: isActive ? 0.15 : 0.09,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      _precisePercentLabel(entry.percentage),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: color,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 9),
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
                                          width: isActive ? 48 : 44,
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
                                                                      ? 0.96
                                                                      : 0.90,
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
                                    fontSize: 10.2,
                                    fontWeight: FontWeight.w500,
                                    height: 1.12,
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
        height: 330,
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

    final cleanedLabel = label
        .replaceFirst(
          RegExp(r'^\s*\(?[a-z]\)\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'\s*\(?[a-z]\)\s*$', caseSensitive: false),
          '',
        )
        .trim();
    final mappedLabel = exposureLabels[cleanedLabel] ?? exposureLabels[label];

    // Cette table protège l'affichage contre les variantes de libellés entrantes.
    return mappedLabel != null
        ? AppLocalizations.translate(mappedLabel)
        : dashboardExposureLabel(cleanedLabel);
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
        return const Color(0xFF2563EB);
      case 'crm non financé':
      case 'crm non finance':
      case 'crm non financee':
      case 'unfinanced':
      case 'non financé':
        return const Color(0xFFEF4444);
      case 'sans crm':
      case 'aucune':
      case 'no crm':
      case 'pas de crm':
        return const Color(0xFF10B981);
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
        height: 330,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 178,
                  height: 178,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(178),
                        painter: _CrmDonutPainter(
                          segments: segments,
                          activeIndex: boundedActiveIndex,
                        ),
                      ),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF0F1B31) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dashboardPanelBorder(isDark)
                                .withValues(alpha: 0.78),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0x26040A16)
                                  : const Color(0x0F334155),
                              blurRadius: 16,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
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
                                      fontSize: 16.4,
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getCrmLabel(activeEntry.label),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: dashboardSubtitleColor(isDark),
                                      fontSize: 7.4,
                                      fontWeight: FontWeight.w500,
                                      height: 1.12,
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
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: Row(
                children: widget.entries.asMap().entries.map((item) {
                  final index = item.key;
                  final entry = item.value;
                  final color = _getCrmColor(entry.label);
                  final isActive = boundedActiveIndex == index;
                  final titleColor = isActive
                      ? dashboardTitleColor(isDark)
                      : dashboardSubtitleColor(isDark);
                  final valueColor = color;
                  final markerColor = color;

                  return Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _hoveredIndex = index);
                      }),
                      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _hoveredIndex == index) {
                          setState(() => _hoveredIndex = null);
                        }
                      }),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(
                            left: index == 0 ? 0 : 5,
                            right: index == widget.entries.length - 1 ? 0 : 5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(
                              alpha: isActive
                                  ? (isDark ? 0.22 : 0.14)
                                  : (isDark ? 0.11 : 0.08),
                            ),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: color.withValues(
                                alpha: isActive
                                    ? (isDark ? 0.70 : 0.58)
                                    : (isDark ? 0.42 : 0.34),
                              ),
                              width: isActive ? 1.15 : 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: color.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
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
                                    width: 6.4,
                                    height: 6.4,
                                    decoration: BoxDecoration(
                                      color: markerColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                                          fontSize: 9.4,
                                          fontWeight: FontWeight.w500,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  dashboardCompactPercent(entry.percentage),
                                  style: TextStyle(
                                    color: valueColor,
                                    fontSize: 9.4,
                                    fontWeight: FontWeight.w500,
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
      final segmentOpacity = hasActiveSegment && !isActive ? 0.68 : 1.0;

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
