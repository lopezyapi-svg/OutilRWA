// Ce fichier affiche l'echeancier RWA du bas de page.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/dashboard_models.dart';
import 'dashboard_panel.dart';
import 'dashboard_theme.dart';

/// Vues disponibles pour l'échéancier des RWA.
enum DashboardMaturityView {
  monthly,
  quarterly,
  yearly,
}

enum _MaturityMetricMode {
  outstanding,
  released,
}

/// Panneau qui affiche l'évolution future des RWA.
class DashboardMaturityPanel extends StatefulWidget {
  const DashboardMaturityPanel({
    super.key,
    required this.displayCurrency,
    required this.view,
    required this.onViewChanged,
    required this.points,
  });

  final String displayCurrency;
  final DashboardMaturityView view;
  final ValueChanged<DashboardMaturityView> onViewChanged;
  final List<DashboardProjectionPoint> points;

  @override
  State<DashboardMaturityPanel> createState() => _DashboardMaturityPanelState();
}

/// Etat interne du panneau d'échéancier et de ses interactions.
class _DashboardMaturityPanelState extends State<DashboardMaturityPanel> {
  int? _activeIndex;
  _MaturityMetricMode _metricMode = _MaturityMetricMode.outstanding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final convertedPoints = widget.points
        .map(
          (point) => DashboardProjectionPoint(
            label: point.label,
            value: convertCurrencyAmount(
              point.value,
              fromCurrency: 'XOF',
              toCurrency: widget.displayCurrency,
            ),
          ),
        )
        .toList(growable: false);
    final computedPoints = _buildComputedPoints(convertedPoints, widget.view);
    final activeIndex =
        _activeIndex != null && _activeIndex! < computedPoints.length
            ? _activeIndex
            : null;
    final primaryLabel = _metricMode == _MaturityMetricMode.outstanding
        ? context.tr('Trajectoire RWA')
        : context.tr('RWA libéré cumulé');
    final unitScale = _resolveChartUnitScale(
      computedPoints,
      _metricMode,
      widget.displayCurrency,
    );

    return DashboardPanel(
      title: 'Profil de maturité des RWA',
      subtitle:
          "Vue prévisionnelle de l'amortissement et de la libération projetés des RWA.",
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewChip(
            label: context.tr('Monthly'),
            selected: widget.view == DashboardMaturityView.monthly,
            onTap: () => widget.onViewChanged(DashboardMaturityView.monthly),
          ),
          const SizedBox(width: 6),
          _ViewChip(
            label: context.tr('Quarterly'),
            selected: widget.view == DashboardMaturityView.quarterly,
            onTap: () => widget.onViewChanged(DashboardMaturityView.quarterly),
          ),
          const SizedBox(width: 6),
          _ViewChip(
            label: context.tr('Yearly'),
            selected: widget.view == DashboardMaturityView.yearly,
            onTap: () => widget.onViewChanged(DashboardMaturityView.yearly),
          ),
        ],
      ),
      child: SizedBox(
        height: 258,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeader = constraints.maxWidth < 900;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compactHeader) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LegendItem(
                        color: _primarySeriesStartColor(_metricMode),
                        accentColor: _primarySeriesEndColor(_metricMode),
                        label: primaryLabel,
                      ),
                      _LegendItem(
                        color: const Color(0xFFF39B4A),
                        accentColor: const Color(0xFFF2B572),
                        label: context.tr('Amortissement mensuel'),
                      ),
                      _LegendItem(
                        color: _primarySeriesEndColor(_metricMode),
                        accentColor: _primarySeriesEndColor(_metricMode),
                        label: context.tr('Projection'),
                        dashed: true,
                      ),
                      _UnitBadge(
                        label: context.tr(
                          'Unité: {{value}}',
                          args: {'value': unitScale.label},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MetricModeSwitch(
                    mode: _metricMode,
                    onChanged: (mode) => setState(() => _metricMode = mode),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _LegendItem(
                              color: _primarySeriesStartColor(_metricMode),
                              accentColor: _primarySeriesEndColor(_metricMode),
                              label: primaryLabel,
                            ),
                            _LegendItem(
                              color: const Color(0xFFF39B4A),
                              accentColor: const Color(0xFFF2B572),
                              label: context.tr('Amortissement mensuel'),
                            ),
                            _LegendItem(
                              color: _primarySeriesEndColor(_metricMode),
                              accentColor: _primarySeriesEndColor(_metricMode),
                              label: context.tr('Projection'),
                              dashed: true,
                            ),
                            _UnitBadge(
                              label: context.tr(
                                'Unité: {{value}}',
                                args: {'value': unitScale.label},
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _MetricModeSwitch(
                        mode: _metricMode,
                        onChanged: (mode) => setState(() => _metricMode = mode),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, _) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MaturityCurvePainter(
                                isDark: isDark,
                                points: computedPoints,
                                mode: _metricMode,
                                activeIndex: activeIndex,
                                unitScale: unitScale,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                8,
                                12,
                                8,
                                10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(
                                  computedPoints.length,
                                  (index) => Expanded(
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      onEnter: (_) =>
                                          setState(() => _activeIndex = index),
                                      onExit: (_) {
                                        if (_activeIndex == index) {
                                          setState(() => _activeIndex = null);
                                        }
                                      },
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap: () => setState(
                                            () => _activeIndex = index),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bouton de sélection de vue pour l'échéancier.
class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF234A84)
              : (isDark ? const Color(0xFF14233D) : const Color(0xFFF7F9FE)),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected
                ? const Color(0xFF234A84)
                : dashboardPanelBorder(isDark),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : dashboardTitleColor(isDark),
              fontSize: 8.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.accentColor,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final Color accentColor;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 12,
          child: CustomPaint(
            painter: _LegendStrokePainter(
              color: color,
              accentColor: accentColor,
              dashed: dashed,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: dashboardSubtitleColor(isDark),
            fontSize: 8.3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _UnitBadge extends StatelessWidget {
  const _UnitBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dashboardPanelBorder(isDark)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dashboardSubtitleColor(isDark),
          fontSize: 7.9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LegendStrokePainter extends CustomPainter {
  const _LegendStrokePainter({
    required this.color,
    required this.accentColor,
    required this.dashed,
  });

  final Color color;
  final Color accentColor;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, size.height / 2)
      ..lineTo(size.width - 1, size.height / 2);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color, accentColor],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (dashed) {
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = math.min(distance + 4, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), paint);
          distance += 7;
        }
      }
    } else {
      canvas.drawPath(path, paint);
    }

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2.2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      1.4,
      Paint()..color = accentColor,
    );
  }

  @override
  bool shouldRepaint(covariant _LegendStrokePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.dashed != dashed;
  }
}

class _MetricModeSwitch extends StatelessWidget {
  const _MetricModeSwitch({
    required this.mode,
    required this.onChanged,
  });

  final _MaturityMetricMode mode;
  final ValueChanged<_MaturityMetricMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dashboardPanelBorder(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetricModeChip(
            label: context.tr('Encours RWA'),
            selected: mode == _MaturityMetricMode.outstanding,
            color: _primarySeriesEndColor(_MaturityMetricMode.outstanding),
            onTap: () => onChanged(_MaturityMetricMode.outstanding),
          ),
          const SizedBox(width: 4),
          _MetricModeChip(
            label: context.tr('RWA libéré cumulé'),
            selected: mode == _MaturityMetricMode.released,
            color: _primarySeriesEndColor(_MaturityMetricMode.released),
            onTap: () => onChanged(_MaturityMetricMode.released),
          ),
        ],
      ),
    );
  }
}

class _MetricModeChip extends StatelessWidget {
  const _MetricModeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.20 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.48) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : dashboardSubtitleColor(isDark),
            fontSize: 8.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MaturityComputedPoint {
  const _MaturityComputedPoint({
    required this.index,
    required this.label,
    required this.outstanding,
    required this.released,
    required this.delta,
    required this.isForecast,
    required this.event,
  });

  final int index;
  final String label;
  final double outstanding;
  final double released;
  final double delta;
  final bool isForecast;
  final _MaturityEvent? event;
}

class _ChartUnitScale {
  const _ChartUnitScale({
    required this.divisor,
    required this.label,
  });

  final double divisor;
  final String label;
}

class _MaturityEvent {
  const _MaturityEvent({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String label;
  final String description;
  final Color color;
  final IconData icon;
}

List<_MaturityComputedPoint> _buildComputedPoints(
  List<DashboardProjectionPoint> source,
  DashboardMaturityView view,
) {
  if (source.isEmpty) {
    return const [];
  }

  final forecastStart = _forecastStartIndex(source.length, view);
  var largestDrop = 0.0;
  int? largestDropIndex;

  for (var index = 1; index < source.length; index++) {
    final delta = source[index].value - source[index - 1].value;
    if (delta < largestDrop) {
      largestDrop = delta;
      largestDropIndex = index;
    }
  }

  final baseValue = source.first.value;
  return List.generate(source.length, (index) {
    final value = source[index].value;
    final delta = index == 0 ? 0.0 : value - source[index - 1].value;
    final released = math.max(0.0, baseValue - value);
    _MaturityEvent? event;
    if (index == largestDropIndex) {
      event = _MaturityEvent(
        label: AppLocalizations.translate("Pic d'amort."),
        description: AppLocalizations.translate(
          'Cette période concentre la baisse la plus marquée de la trajectoire. Le stock RWA se détend plus vite, ce qui accélère la libération du capital réglementaire.',
        ),
        color: const Color(0xFFF39B4A),
        icon: Icons.bolt_rounded,
      );
    } else if (index == forecastStart) {
      event = _MaturityEvent(
        label: AppLocalizations.translate('Projection'),
        description: AppLocalizations.translate(
          "A partir de ce point, la courbe devient prévisionnelle. La lecture doit être comprise comme une estimation du rythme futur d'amortissement et de relâchement des RWA.",
        ),
        color: const Color(0xFF4C7CDD),
        icon: Icons.timeline_rounded,
      );
    } else if (index == source.length - 1) {
      event = _MaturityEvent(
        label: AppLocalizations.translate('Horizon'),
        description: AppLocalizations.translate(
          "Ce point représente l'horizon de projection disponible dans le dashboard. Il permet d'estimer le niveau résiduel de RWA à la fin de la séquence observée.",
        ),
        color: const Color(0xFF1BAA63),
        icon: Icons.flag_rounded,
      );
    }

    return _MaturityComputedPoint(
      index: index,
      label: source[index].label,
      outstanding: value,
      released: released,
      delta: delta,
      isForecast: index >= forecastStart,
      event: event,
    );
  });
}

int _forecastStartIndex(int length, DashboardMaturityView view) {
  if (length <= 2) {
    return math.max(0, length - 1);
  }

  switch (view) {
    case DashboardMaturityView.monthly:
      return math.max(2, length - 4);
    case DashboardMaturityView.quarterly:
      return math.max(1, length - 2);
    case DashboardMaturityView.yearly:
      return math.max(1, length - 1);
  }
}

Color _primarySeriesStartColor(_MaturityMetricMode mode) {
  return mode == _MaturityMetricMode.outstanding
      ? const Color(0xFF8FB4FF)
      : const Color(0xFF61D39A);
}

Color _primarySeriesEndColor(_MaturityMetricMode mode) {
  return mode == _MaturityMetricMode.outstanding
      ? const Color(0xFF3F7EFF)
      : const Color(0xFF19A866);
}

_ChartUnitScale _resolveChartUnitScale(
  List<_MaturityComputedPoint> points,
  _MaturityMetricMode mode,
  String displayCurrency,
) {
  if (points.isEmpty) {
    return _ChartUnitScale(
      divisor: 1,
      label: displayCurrencyLabel(displayCurrency),
    );
  }

  var maxValue = 0.0;
  for (final point in points) {
    final primaryValue = mode == _MaturityMetricMode.outstanding
        ? point.outstanding
        : point.released;
    maxValue = math.max(maxValue, primaryValue.abs());
    maxValue = math.max(maxValue, point.delta.abs());
  }

  final currencyLabel = displayCurrencyLabel(displayCurrency);
  if (maxValue >= 1000000000) {
    return _ChartUnitScale(
      divisor: 1000000000,
      label: AppLocalizations.translate(
        'milliards {{currency}}',
        args: {'currency': currencyLabel},
      ),
    );
  }
  if (maxValue >= 1000000) {
    return _ChartUnitScale(
      divisor: 1000000,
      label: AppLocalizations.translate(
        'millions {{currency}}',
        args: {'currency': currencyLabel},
      ),
    );
  }
  if (maxValue >= 1000) {
    return _ChartUnitScale(
      divisor: 1000,
      label: AppLocalizations.translate(
        'milliers {{currency}}',
        args: {'currency': currencyLabel},
      ),
    );
  }
  return _ChartUnitScale(divisor: 1, label: currencyLabel);
}

String _formatChartValue(
  double value,
  _ChartUnitScale scale, {
  bool signed = false,
}) {
  final scaled = value / scale.divisor;
  final absScaled = scaled.abs();
  final decimals = absScaled >= 100 ? 0 : 1;
  final text = absScaled.toStringAsFixed(decimals);

  if (!signed) {
    return text;
  }

  final sign = value < 0 ? '-' : '+';
  return '$sign$text';
}

/// Painter principal de la courbe de projection RWA.
class _MaturityCurvePainter extends CustomPainter {
  const _MaturityCurvePainter({
    required this.isDark,
    required this.points,
    required this.mode,
    required this.activeIndex,
    required this.unitScale,
  });

  final bool isDark;
  final List<_MaturityComputedPoint> points;
  final _MaturityMetricMode mode;
  final int? activeIndex;
  final _ChartUnitScale unitScale;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(24, 18, size.width - 48, size.height - 56);
    final mainRect = Rect.fromLTWH(
      chartRect.left,
      chartRect.top + 2,
      chartRect.width,
      chartRect.height * 0.58,
    );
    final deltaRect = Rect.fromLTWH(
      chartRect.left,
      chartRect.top + (chartRect.height * 0.66),
      chartRect.width,
      chartRect.height * 0.14,
    );
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF22304B) : const Color(0xFFE8EEF8)
      ..strokeWidth = 1;
    final deltaGuidePaint = Paint()
      ..color = (isDark ? const Color(0xFF2C3B59) : const Color(0xFFDDE6F4))
          .withValues(alpha: 0.9)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = mainRect.top + (mainRect.height / 3) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }
    canvas.drawLine(
      Offset(chartRect.left, deltaRect.bottom),
      Offset(chartRect.right, deltaRect.bottom),
      deltaGuidePaint,
    );

    if (points.isEmpty) {
      return;
    }

    final firstForecastIndex = points.indexWhere((item) => item.isForecast);
    final forecastStart = firstForecastIndex <= 0
        ? math.max(1, points.length - 1)
        : firstForecastIndex;
    final primaryValues = points
        .map(
          (item) => mode == _MaturityMetricMode.outstanding
              ? item.outstanding
              : item.released,
        )
        .toList();
    final deltaValues =
        points.map((item) => item.delta.abs()).toList(growable: false);
    final primaryOffsets = _seriesOffsets(mainRect, primaryValues);
    final deltaOffsets = _seriesOffsets(deltaRect, deltaValues);
    final primarySolidPath =
        _buildSmoothPath(primaryOffsets.take(forecastStart + 1).toList());
    final primaryForecastPath =
        _buildSmoothPath(primaryOffsets.skip(forecastStart).toList());
    final deltaSolidPath =
        _buildSmoothPath(deltaOffsets.take(forecastStart + 1).toList());
    final deltaForecastPath =
        _buildSmoothPath(deltaOffsets.skip(forecastStart).toList());
    final primaryStartColor = _primarySeriesStartColor(mode);
    final primaryEndColor = _primarySeriesEndColor(mode);
    const deltaColor = Color(0xFFF39B4A);

    _drawGlowPath(
      canvas,
      primarySolidPath,
      primaryEndColor.withValues(alpha: isDark ? 0.22 : 0.14),
      strokeWidth: 6.2,
      blurSigma: 8,
    );
    canvas.drawPath(
      primarySolidPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [primaryStartColor, primaryEndColor],
        ).createShader(mainRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final forecastPrimaryPaint = Paint()
      ..color = primaryEndColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawDashedPath(canvas, primaryForecastPath, forecastPrimaryPaint);

    canvas.drawPath(
      deltaSolidPath,
      Paint()
        ..color = deltaColor.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    _drawDashedPath(
      canvas,
      deltaForecastPath,
      Paint()
        ..color = deltaColor.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      dashLength: 5,
      gapLength: 4,
    );

    for (var index = 0; index < primaryOffsets.length; index++) {
      final mainPoint = primaryOffsets[index];
      final deltaPoint = deltaOffsets[index];
      final active = activeIndex == index;
      final event = points[index].event;

      if (active) {
        canvas.drawLine(
          Offset(mainPoint.dx, mainRect.top - 4),
          Offset(mainPoint.dx, chartRect.bottom + 6),
          Paint()
            ..color = primaryEndColor.withValues(alpha: isDark ? 0.20 : 0.12)
            ..strokeWidth = 1,
        );
      }

      if (points[index].delta.abs() > 0 &&
          (active || event != null || index == primaryOffsets.length - 1)) {
        _paintCenteredText(
          canvas,
          _formatChartValue(points[index].delta, unitScale, signed: true),
          deltaPoint.translate(0, -11),
          TextStyle(
            color: deltaColor.withValues(alpha: active ? 1 : 0.88),
            fontSize: active ? 7.3 : 6.8,
            fontWeight: FontWeight.w800,
          ),
          maxWidth: 86,
        );
      }

      if (event != null) {
        _paintEventTag(
          canvas,
          event.label,
          mainPoint.translate(0, -28),
          event.color,
          chartRect,
        );
      }

      canvas.drawCircle(
        mainPoint,
        active ? 6.4 : 5.2,
        Paint()..color = isDark ? const Color(0xFF101C32) : Colors.white,
      );
      canvas.drawCircle(
        mainPoint,
        active ? 3.9 : 3.0,
        Paint()..color = primaryEndColor,
      );
      if (active || event != null) {
        canvas.drawCircle(
          mainPoint,
          active ? 10.5 : 8.6,
          Paint()..color = primaryEndColor.withValues(alpha: active ? 0.12 : 0.07),
        );
      }

      canvas.drawCircle(
        deltaPoint,
        active ? 3.7 : 3.0,
        Paint()..color = isDark ? const Color(0xFF101C32) : Colors.white,
      );
      canvas.drawCircle(
        deltaPoint,
        active ? 2.1 : 1.6,
        Paint()..color = deltaColor,
      );

      _paintCenteredText(
        canvas,
        _formatChartValue(primaryValues[index], unitScale),
        mainPoint.translate(0, -14),
        TextStyle(
          color: active
              ? dashboardTitleColor(isDark)
              : dashboardSubtitleColor(isDark),
          fontSize: active ? 8.0 : 7.4,
          fontWeight: active ? FontWeight.w800 : FontWeight.w700,
        ),
        maxWidth: 82,
      );

      _paintCenteredText(
        canvas,
        points[index].label,
        Offset(mainPoint.dx, chartRect.bottom + 13),
        TextStyle(
          color: dashboardTitleColor(isDark),
          fontSize: 8.1,
          fontWeight: active ? FontWeight.w800 : FontWeight.w700,
        ),
        maxWidth: 48,
      );
    }
  }

  List<Offset> _seriesOffsets(Rect rect, List<double> values) {
    final maxValue = values.isEmpty ? 1.0 : values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final step = values.length <= 1 ? 0.0 : rect.width / (values.length - 1);

    return List.generate(values.length, (index) {
      final normalized = (values[index] / safeMax).clamp(0.0, 1.0);
      return Offset(
        rect.left + (step * index),
        rect.bottom - (rect.height * normalized),
      );
    });
  }

  Path _buildSmoothPath(List<Offset> points) {
    if (points.isEmpty) {
      return Path();
    }
    if (points.length == 1) {
      return Path()..addOval(Rect.fromCircle(center: points.first, radius: 1));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + ((p2.dx - p0.dx) / 6),
        p1.dy + ((p2.dy - p0.dy) / 6),
      );
      final cp2 = Offset(
        p2.dx - ((p3.dx - p1.dx) / 6),
        p2.dy - ((p3.dy - p1.dy) / 6),
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawGlowPath(
    Canvas canvas,
    Path path,
    Color color, {
    required double strokeWidth,
    required double blurSigma,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma),
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dashLength = 6,
    double gapLength = 5,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  void _paintEventTag(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    Rect bounds,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 6.8,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 76);

    final width = textPainter.width + 12;
    final height = textPainter.height + 6;
    final left = (center.dx - (width / 2)).clamp(
      bounds.left + 2,
      bounds.right - width - 2,
    );
    final top = center.dy - height;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(999),
    );

    canvas.drawRRect(
      rect,
      Paint()..color = color.withValues(alpha: isDark ? 0.16 : 0.10),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.32 : 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(
      canvas,
      Offset(left + 6, top + ((height - textPainter.height) / 2)),
    );
  }

  void _paintCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    double maxWidth = 80,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    painter.paint(
      canvas,
      Offset(center.dx - (painter.width / 2), center.dy - (painter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _MaturityCurvePainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.mode != mode ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.unitScale.divisor != unitScale.divisor ||
        oldDelegate.unitScale.label != unitScale.label ||
        oldDelegate.points != points;
  }
}
