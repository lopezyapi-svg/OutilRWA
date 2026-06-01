// Ecran du risque de marché.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart' as fm;
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../services/market_data_import_store.dart';

enum MarketRiskView { dashboard, indicators, yieldCurves, varRisk }

enum _VarMethod { historical, parametric, monteCarlo }

enum _MonteCarloDistribution { normal, student, empirical }

enum _FloatingPanelPlacement { right, down, up }

enum _MarketDashboardTab { visualisation, dataTable }

enum _MarketTableSortKey {
  issuer,
  country,
  zone,
  rating,
  accountingIntent,
  residualMaturity,
  instrumentType,
  exposure,
  currency,
}

const Color _marketPrimary = Color(0xFF2563EB);
const Color _marketCyan = Color(0xFF06B6D4);
const Color _marketSuccess = Color(0xFF10B981);
const Color _marketWarning = Color(0xFFF59E0B);
const Color _marketViolet = Color(0xFF7C3AED);
const Color _marketDanger = Color(0xFFEF4444);
const Color _marketDashboardDeepBlue = Color(0xFF234A84);
const Color _marketText = Color(0xFF13203A);
const Color _marketMuted = Color(0xFF64748B);
const Color _marketBorder = Color(0xFFDDE7F5);
const Color _marketSurface = Color(0xFFFFFFFF);
const Color _marketSurfaceSoft = Color(0xFFF8FAFC);
const double _yieldCurveChartLeft = 42.0;
const double _yieldCurveChartRight = 14.0;
const double _yieldCurveChartTop = 14.0;
const double _yieldCurveChartBottom = 30.0;
const String _yieldZoneSeriesId = '__zone__';
const String _yieldCurveNoDataLottie =
    'assets/lotties/yield_curve_no_data.json';
const List<String> _uemoaYieldCountries = [
  'Bénin',
  'Burkina Faso',
  'Côte d\'Ivoire',
  'Guinée-Bissau',
  'Mali',
  'Niger',
  'Sénégal',
  'Togo',
];
const List<String> _cemacYieldCountries = [
  'Cameroun',
  'Congo',
  'Gabon',
  'République Centrafricaine',
  'Guinée équatoriale',
  'Tchad',
];
const List<Color> _yieldCountryPalette = [
  Color(0xFF0F766E),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFE11D48),
  Color(0xFF4F46E5),
  Color(0xFFB45309),
  Color(0xFFDB2777),
  Color(0xFFF97316),
  Color(0xFF0284C7),
  Color(0xFF14B8A6),
  Color(0xFFA855F7),
  Color(0xFF475569),
  Color(0xFFDC2626),
];
const double _varMethodCardsHeight = 430;
const double _varParameterPanelWidth = 232;
const double _varMethodTabWidth = 118;
const Duration _varMethodTransitionDuration = Duration(milliseconds: 260);
const Curve _varMethodTransitionCurve = Curves.easeOutCubic;

String _marketTr(
  String source, {
  Map<String, Object?> args = const {},
}) {
  return AppLocalizations.translate(source, args: args);
}

String _daysLabel(int value) {
  return AppLocalizations.isEnglish ? '$value days' : '$value jours';
}

String _shortDaysLabel(int value) {
  return AppLocalizations.isEnglish ? '${value}d' : '$value j';
}

const double _defaultHistoricalConfidence = 0.99;
const int _defaultHistoricalHorizon = 1;
const int _defaultHistoricalWindow = 500;
const MarketPortfolioType _defaultHistoricalPortfolio =
    MarketPortfolioType.bonds;
const double _defaultParamConfidence = 0.99;
const int _defaultParamHorizon = 10;
const double _defaultParamPortfolioScale = 1.0;
const double _defaultParamVolatility = 0.03;
const double _defaultParamDuration = 5.1351417368715235;
const double _defaultParamCorrelation = 0.38;
const double _defaultParamExpectedReturn = 0.028;
const double _defaultParamRiskFreeRate = 0.045;
const double _defaultMcConfidence = 0.99;
const int _defaultMcHorizon = 10;
const int _defaultMcSimulations = 50000;
const double _defaultMcCorrelation = 0.42;
const _MonteCarloDistribution _defaultMcDistribution =
    _MonteCarloDistribution.normal;

bool _isMarketDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _marketSurfaceFor(BuildContext context) =>
    _isMarketDark(context) ? const Color(0xFF0F1B31) : _marketSurface;

Color _marketBorderFor(BuildContext context) =>
    _isMarketDark(context) ? const Color(0xFF263856) : _marketBorder;

Color _marketTextFor(BuildContext context) =>
    _isMarketDark(context) ? const Color(0xFFEAF2FF) : _marketText;

Color _marketMutedFor(BuildContext context) =>
    _isMarketDark(context) ? const Color(0xFF9FB0CE) : _marketMuted;

Color _marketSurfaceSoftFor(BuildContext context) =>
    _isMarketDark(context) ? const Color(0xFF162642) : _marketSurfaceSoft;

Rect _yieldCurveChartBounds(Size size) {
  return Rect.fromLTWH(
    _yieldCurveChartLeft,
    _yieldCurveChartTop,
    math.max(1, size.width - _yieldCurveChartLeft - _yieldCurveChartRight),
    math.max(1, size.height - _yieldCurveChartTop - _yieldCurveChartBottom),
  );
}

/// Ecran de suivi des risques de marché.
class RisqueMarcheScreen extends StatelessWidget {
  const RisqueMarcheScreen({
    super.key,
    required this.api,
    this.view = MarketRiskView.dashboard,
  });

  final RwaApiService api;
  final MarketRiskView view;

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      MarketRiskView.dashboard => _buildDashboard(context),
      MarketRiskView.indicators => const _MarketIndicatorsWorkspace(),
      MarketRiskView.yieldCurves => _MarketYieldCurvesWorkspace(api: api),
      MarketRiskView.varRisk => _ValueAtRiskModule(api: api),
    };
  }

  Widget _buildDashboard(BuildContext context) {
    return const _MarketDashboard();
  }
}

class _MarketYieldCurvesWorkspace extends StatefulWidget {
  const _MarketYieldCurvesWorkspace({required this.api});

  final RwaApiService api;

  @override
  State<_MarketYieldCurvesWorkspace> createState() =>
      _MarketYieldCurvesWorkspaceState();
}

class _MarketYieldCurvesWorkspaceState
    extends State<_MarketYieldCurvesWorkspace> {
  late final _YieldCurveRepository _repository =
      _YieldCurveRepository(api: widget.api);
  List<_YieldCurveSnapshot> _snapshots = _YieldCurveRepository.seedSnapshots;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadCurves();
  }

  Future<void> _loadCurves() async {
    var snapshots = _YieldCurveRepository.seedSnapshots;
    try {
      snapshots = await _repository.load().timeout(
            const Duration(seconds: 3),
            onTimeout: () => _YieldCurveRepository.seedSnapshots,
          );
    } catch (_) {
      snapshots = _YieldCurveRepository.seedSnapshots;
    }
    if (!mounted) return;
    setState(() {
      _snapshots = snapshots;
      _loading = false;
    });
  }

  Future<void> _refreshCurves() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
    });

    late final _YieldCurveRefreshResult result;
    try {
      result = await _repository.refreshOnline(_snapshots);
    } catch (_) {
      result = _YieldCurveRefreshResult(
        snapshots: _snapshots,
        message:
            'Actualisation impossible. Dernières courbes locales conservées.',
      );
    }
    if (!mounted) return;
    setState(() {
      _snapshots = result.snapshots;
      _refreshing = false;
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _YieldCurveRefreshDialog(
        message: result.message,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Courbe des taux',
            subtitle:
                'Courbes de référence UEMOA et CEMAC pour l’actualisation des flux et les analyses de valorisation.',
            titleFontSize: 26,
            subtitleFontSize: 12.5,
            trailing: _YieldCurveHeaderActions(
              refreshing: _refreshing,
              onPressed: _refreshCurves,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const _MarketCard(
                    child: SizedBox(
                      height: 280,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _marketPrimary,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 14.0;
                            const minCardWidth = 520.0;
                            final cardWidth = math.max(
                              minCardWidth,
                              (constraints.maxWidth - gap) / 2,
                            );
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var index = 0;
                                      index < _snapshots.length;
                                      index++) ...[
                                    SizedBox(
                                      width: cardWidth,
                                      child: _YieldCurveSnapshotCard(
                                        snapshot: _snapshots[index],
                                      ),
                                    ),
                                    if (index < _snapshots.length - 1)
                                      const SizedBox(width: gap),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _YieldCurveRefreshDialog extends StatelessWidget {
  const _YieldCurveRefreshDialog({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final text = _marketTextFor(context);
    final border = _marketBorderFor(context);
    final statusLines = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _marketSurfaceFor(context),
            border: Border.all(color: border.withValues(alpha: 0.86)),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _marketPrimary.withValues(
                        alpha: isDark ? 0.16 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_clockwise,
                      color: _marketPrimary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Actualisation des courbes'.tr(context),
                      style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Column(
                children: [
                  for (var index = 0; index < statusLines.length; index++) ...[
                    _YieldCurveRefreshStatusLine(message: statusLines[index]),
                    if (index < statusLines.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onClose,
                  style: FilledButton.styleFrom(
                    backgroundColor: _marketPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: Text(
                    'Fermer'.tr(context),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YieldCurveRefreshStatusLine extends StatelessWidget {
  const _YieldCurveRefreshStatusLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final normalized = message.toLowerCase();
    final isWarning =
        normalized.contains('non actualisée') || normalized.contains('conserv');
    final accent = isWarning ? _marketWarning : _marketSuccess;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.30 : 0.18),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.tr(context),
              style: TextStyle(
                color: _marketTextFor(context).withValues(alpha: 0.88),
                fontSize: 12.3,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YieldCurveHeaderActions extends StatelessWidget {
  const _YieldCurveHeaderActions({
    required this.refreshing,
    required this.onPressed,
  });

  final bool refreshing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _YieldCurveRefreshButton(
          refreshing: refreshing,
          onPressed: onPressed,
        ),
        const SizedBox(width: 8),
        const _YieldCurveInfoBanner(),
      ],
    );
  }
}

class _YieldCurveRefreshButton extends StatelessWidget {
  const _YieldCurveRefreshButton({
    required this.refreshing,
    required this.onPressed,
  });

  final bool refreshing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Actualiser depuis les sources officielles',
      child: Semantics(
        label: 'Actualiser'.tr(context),
        button: true,
        child: SizedBox.square(
          dimension: 32,
          child: FilledButton(
            onPressed: refreshing ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _marketPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _marketPrimary.withValues(alpha: 0.45),
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(32),
              fixedSize: const Size.square(32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child: refreshing
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(CupertinoIcons.arrow_clockwise, size: 16),
          ),
        ),
      ),
    );
  }
}

class _YieldCurveInfoBanner extends StatelessWidget {
  const _YieldCurveInfoBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final tooltip = [
      'Référentiel d’actualisation utilisé pour chaque zone monétaire.',
      'En mode hors connexion, la dernière version locale validée reste disponible.',
      'La synchronisation réseau est lancée uniquement sur action utilisateur.',
    ].join('\n').tr(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 350),
        showDuration: const Duration(seconds: 5),
        preferBelow: false,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162642) : const Color(0xFF13203A),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        child: Semantics(
          label: 'Usage interne'.tr(context),
          child: SizedBox.square(
            dimension: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _marketPrimary.withValues(alpha: isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.info_circle_fill,
                  color: _marketPrimary,
                  size: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YieldCurveSnapshotCard extends StatefulWidget {
  const _YieldCurveSnapshotCard({required this.snapshot});

  final _YieldCurveSnapshot snapshot;

  @override
  State<_YieldCurveSnapshotCard> createState() =>
      _YieldCurveSnapshotCardState();
}

class _YieldCurveSnapshotCardState extends State<_YieldCurveSnapshotCard> {
  int? _selectedPointIndex;
  int? _hoveredPointIndex;
  Set<String> _selectedSeriesIds = const {_yieldZoneSeriesId};

  @override
  void didUpdateWidget(covariant _YieldCurveSnapshotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.id != widget.snapshot.id) {
      _selectedSeriesIds = const {_yieldZoneSeriesId};
      _selectedPointIndex = null;
      _hoveredPointIndex = null;
      return;
    }
    _selectedSeriesIds = _sanitizeYieldSelection(
      widget.snapshot,
      _selectedSeriesIds,
    );
  }

  void _toggleSeries(String seriesId) {
    if (!_isYieldSeriesSelectable(widget.snapshot, seriesId)) return;

    final next = {..._selectedSeriesIds};
    if (seriesId == _yieldZoneSeriesId) {
      if (next.contains(seriesId)) {
        if (next.length > 1) next.remove(seriesId);
      } else {
        next.add(seriesId);
      }
    } else if (next.length == 1 && next.contains(_yieldZoneSeriesId)) {
      next
        ..clear()
        ..add(seriesId);
    } else if (!next.add(seriesId)) {
      next.remove(seriesId);
    }

    setState(() {
      _selectedSeriesIds = _sanitizeYieldSelection(widget.snapshot, next);
      _selectedPointIndex = null;
      _hoveredPointIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final selectedSeriesIds =
        _sanitizeYieldSelection(snapshot, _selectedSeriesIds);
    if (selectedSeriesIds.length != _selectedSeriesIds.length ||
        !selectedSeriesIds.containsAll(_selectedSeriesIds)) {
      _selectedSeriesIds = selectedSeriesIds;
    }
    final visibleSeries = snapshot.displaySeries(selectedSeriesIds);
    final stripItems = _yieldPointStripItems(visibleSeries);
    final primarySeries = _primaryYieldSeries(visibleSeries);
    final primaryPoints = primarySeries?.points ?? const <_YieldCurvePoint>[];
    final selectedPointIndex = _selectedPointIndex != null &&
            _selectedPointIndex! < primaryPoints.length
        ? _selectedPointIndex
        : null;
    final activePointIndex =
        _hoveredPointIndex != null && _hoveredPointIndex! < primaryPoints.length
            ? _hoveredPointIndex
            : selectedPointIndex;
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final border = _marketBorderFor(context);
    final color = snapshot.color;
    final hasDrawableData = primaryPoints.length >= 2;
    final shortPoint = hasDrawableData ? primaryPoints.first : null;
    final tenYear = hasDrawableData ? primarySeries?.pointNear(10) : null;
    final longPoint = hasDrawableData ? tenYear ?? primaryPoints.last : null;
    final maxPoint = hasDrawableData
        ? primaryPoints.reduce(
            (best, point) => point.rate > best.rate ? point : best,
          )
        : null;
    final slopeBps = hasDrawableData && longPoint != null && shortPoint != null
        ? (longPoint.rate - shortPoint.rate) * 100
        : null;

    return _MarketCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.sourceName} · ${snapshot.sourceDateLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _YieldCurveSourceInfoButton(snapshot: snapshot),
            ],
          ),
          const SizedBox(height: 14),
          if (hasDrawableData) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _YieldCurveMetricChip(
                  label: 'Court terme · ${shortPoint!.label}',
                  value: _formatYieldRate(shortPoint.rate),
                  color: color,
                ),
                _YieldCurveMetricChip(
                  label: tenYear == null
                      ? 'Point long · ${longPoint!.label}'
                      : 'Point 10Y · ${longPoint!.label}',
                  value: _formatYieldRate(longPoint.rate),
                  color: _marketCyan,
                ),
                _YieldCurveMetricChip(
                  label: 'Pente CT / ${longPoint.label}',
                  value: _formatYieldSpread(slopeBps!),
                  color: _marketWarning,
                ),
                _YieldCurveMetricChip(
                  label: 'Pic · ${maxPoint!.label}',
                  value: _formatYieldRate(maxPoint.rate),
                  color: _marketSuccess,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Container(
            height: 286,
            decoration: BoxDecoration(
              color: _marketSurfaceSoftFor(context)
                  .withValues(alpha: _isMarketDark(context) ? 0.64 : 0.90),
              border: Border.all(color: border.withValues(alpha: 0.72)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: _YieldCurveChart(
                snapshot: snapshot,
                selectedSeriesIds: selectedSeriesIds,
                selectedPointIndex: activePointIndex,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (snapshot.hasSeriesControls) ...[
            _YieldCurveCountryLegend(
              snapshot: snapshot,
              selectedSeriesIds: selectedSeriesIds,
              onToggle: _toggleSeries,
            ),
            const SizedBox(height: 10),
          ],
          if (hasDrawableData)
            SizedBox(
              height: visibleSeries.length > 1 ? 48 : 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = stripItems[index];
                  final isPrimary = item.series.id == primarySeries?.id;
                  return _YieldCurvePointTile(
                    point: item.point,
                    seriesLabel:
                        visibleSeries.length > 1 ? item.series.label : null,
                    color: item.series.color,
                    selected: isPrimary && activePointIndex == item.pointIndex,
                    onHoverChanged: (hovered) {
                      if (!isPrimary) return;
                      setState(() {
                        _hoveredPointIndex = hovered
                            ? item.pointIndex
                            : _hoveredPointIndex == item.pointIndex
                                ? null
                                : _hoveredPointIndex;
                      });
                    },
                    onTap: () {
                      if (!isPrimary) return;
                      setState(() {
                        _selectedPointIndex =
                            selectedPointIndex == item.pointIndex
                                ? null
                                : item.pointIndex;
                      });
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemCount: stripItems.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _YieldCurveMetricChip extends StatelessWidget {
  const _YieldCurveMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isMarketDark(context) ? 0.16 : 0.08),
        border: Border.all(
          color: color.withValues(alpha: _isMarketDark(context) ? 0.32 : 0.18),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr(context).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _marketMutedFor(context),
              fontSize: 8.6,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _marketTextFor(context).withValues(alpha: 0.90),
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _YieldCurveSourceInfoButton extends StatelessWidget {
  const _YieldCurveSourceInfoButton({required this.snapshot});

  final _YieldCurveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final tooltip = [
      'Source : ${snapshot.sourceName}',
      'Référence : ${snapshot.sourceDateLabel}',
      snapshot.methodology,
    ].join('\n').tr(context);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 5),
      preferBelow: true,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162642) : const Color(0xFF13203A),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11.4,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      child: Semantics(
        label: 'Source de la courbe'.tr(context),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: snapshot.color.withValues(alpha: isDark ? 0.14 : 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.info_circle_fill,
            color: snapshot.color,
            size: 14,
          ),
        ),
      ),
    );
  }
}

class _YieldCurveCountryLegend extends StatelessWidget {
  const _YieldCurveCountryLegend({
    required this.snapshot,
    required this.selectedSeriesIds,
    required this.onToggle,
  });

  final _YieldCurveSnapshot snapshot;
  final Set<String> selectedSeriesIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final countries = _yieldCountriesFor(snapshot);

    final zoneChip = _YieldCurveSeriesControlChip(
      label: 'Zone',
      color: snapshot.color,
      available: snapshot.points.length >= 2,
      selected: selectedSeriesIds.contains(_yieldZoneSeriesId),
      tooltip: 'Courbe globale ${snapshot.title}',
      onTap: () => onToggle(_yieldZoneSeriesId),
    );
    final countryChips = [
      for (final country in countries)
        _YieldCurveSeriesControlChip(
          label: country,
          color: _yieldCountryColorFor(country, snapshot.id),
          available: (snapshot.countryCurve(country)?.points.length ?? 0) >= 2,
          selected: selectedSeriesIds.contains(_yieldCountrySeriesId(country)),
          tooltip: null,
          onTap: () => onToggle(_yieldCountrySeriesId(country)),
        ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          zoneChip,
          if (countryChips.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0;
                          index < countryChips.length;
                          index++) ...[
                        countryChips[index],
                        if (index < countryChips.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _YieldCurveSeriesControlChip extends StatelessWidget {
  const _YieldCurveSeriesControlChip({
    required this.label,
    required this.color,
    required this.available,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final Color color;
  final bool available;
  final bool selected;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final chipColor = color;
    final isActive = selected;

    final control = Semantics(
      button: true,
      selected: isActive,
      enabled: true,
      label: label.tr(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: chipColor.withValues(
                alpha: isActive
                    ? (_isMarketDark(context) ? 0.22 : 0.13)
                    : available
                        ? 0.07
                        : (_isMarketDark(context) ? 0.10 : 0.05),
              ),
              border: Border.all(
                color: chipColor.withValues(
                  alpha: isActive
                      ? (_isMarketDark(context) ? 0.68 : 0.50)
                      : available
                          ? (_isMarketDark(context) ? 0.38 : 0.30)
                          : (_isMarketDark(context) ? 0.30 : 0.22),
                ),
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: chipColor.withValues(
                          alpha: _isMarketDark(context) ? 0.16 : 0.08,
                        ),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: available
                        ? (isActive
                            ? _marketTextFor(context)
                            : _marketMutedFor(context))
                        : muted.withValues(alpha: 0.66),
                    fontSize: 9.6,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    height: 1,
                  ),
                ),
                if (isActive && available) ...[
                  const SizedBox(width: 5),
                  Icon(
                    CupertinoIcons.checkmark,
                    size: 10,
                    color: chipColor,
                  ),
                ] else if (!available) ...[
                  const SizedBox(width: 5),
                  Icon(
                    CupertinoIcons.exclamationmark_circle,
                    size: 10,
                    color: muted.withValues(alpha: 0.62),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final tooltipText = tooltip?.trim();
    if (tooltipText == null || tooltipText.isEmpty) return control;

    return Tooltip(
      message: tooltipText.tr(context),
      waitDuration: const Duration(milliseconds: 300),
      child: control,
    );
  }
}

class _YieldCurvePointTile extends StatelessWidget {
  const _YieldCurvePointTile({
    required this.point,
    required this.color,
    required this.selected,
    required this.onHoverChanged,
    required this.onTap,
    this.seriesLabel,
  });

  final _YieldCurvePoint point;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;
  final String? seriesLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final hasSeriesLabel =
        seriesLabel != null && seriesLabel!.trim().isNotEmpty;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: hasSeriesLabel ? 88 : 60,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: isDark ? 0.18 : 0.10)
                : _marketSurfaceSoftFor(context)
                    .withValues(alpha: isDark ? 0.68 : 0.86),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: isDark ? 0.58 : 0.38)
                  : _marketBorderFor(context).withValues(alpha: 0.82),
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasSeriesLabel)
                Text(
                  seriesLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? color : _marketMutedFor(context),
                    fontSize: 7.7,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              Text(
                point.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : _marketMutedFor(context),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              Text(
                _formatYieldRate(point.rate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.1,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YieldCurveChart extends StatefulWidget {
  const _YieldCurveChart({
    required this.snapshot,
    required this.selectedSeriesIds,
    required this.selectedPointIndex,
  });

  final _YieldCurveSnapshot snapshot;
  final Set<String> selectedSeriesIds;
  final int? selectedPointIndex;

  @override
  State<_YieldCurveChart> createState() => _YieldCurveChartState();
}

class _YieldCurveChartState extends State<_YieldCurveChart> {
  int? _hoverPointIndex;

  int? _nearestPointIndex(Offset position, Size size) {
    final series = _primaryYieldSeries(
      widget.snapshot.displaySeries(widget.selectedSeriesIds),
    );
    final points = series?.points ?? const <_YieldCurvePoint>[];
    if (points.length < 2) return null;
    final chart = _yieldCurveChartBounds(size);
    if (!chart.inflate(10).contains(position)) return null;

    final minYear = points.map((point) => point.years).reduce(math.min);
    final maxYear = points.map((point) => point.years).reduce(math.max);
    final yearSpan = math.max(0.1, maxYear - minYear);

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = chart.left + (point.years - minYear) / yearSpan * chart.width;
      final distance = (position.dx - x).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final visibleSeries = widget.snapshot.displaySeries(
      widget.selectedSeriesIds,
    );
    final primarySeries = _primaryYieldSeries(visibleSeries);
    if (primarySeries == null || primarySeries.points.length < 2) {
      return _YieldCurveNoDataChart(color: widget.snapshot.color);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final activePointIndex = _hoverPointIndex ?? widget.selectedPointIndex;
        return MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (event) {
            final nextIndex = _nearestPointIndex(event.localPosition, size);
            if (nextIndex == _hoverPointIndex) return;
            setState(() => _hoverPointIndex = nextIndex);
          },
          onExit: (_) {
            if (_hoverPointIndex == null) return;
            setState(() => _hoverPointIndex = null);
          },
          child: TweenAnimationBuilder<double>(
            key: ValueKey(activePointIndex),
            tween: Tween<double>(
              begin: 0,
              end: activePointIndex == null ? 0 : 1,
            ),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (context, activePointProgress, child) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _YieldCurvePainter(
                      series: visibleSeries,
                      color: widget.snapshot.color,
                      text: _marketTextFor(context),
                      muted: _marketMutedFor(context),
                      grid: _marketBorderFor(context),
                      surface: _marketSurfaceFor(context),
                      activeSeriesId: primarySeries.id,
                      selectedPointIndex: activePointIndex,
                      activePointProgress: activePointProgress,
                    ),
                    child: child,
                  ),
                ],
              );
            },
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _YieldCurveNoDataChart extends StatelessWidget {
  const _YieldCurveNoDataChart({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _marketSurfaceFor(context).withValues(
            alpha: isDark ? 0.62 : 0.82,
          ),
          border: Border.all(color: color.withValues(alpha: 0.16)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              _yieldCurveNoDataLottie,
              width: 126,
              height: 82,
              animate: false,
              repeat: false,
            ),
            const SizedBox(height: 8),
            Text(
              'Données indisponibles'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: text,
                fontSize: 12.6,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Aucune série exploitable pour cette courbe.'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 10.4,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YieldCurvePainter extends CustomPainter {
  const _YieldCurvePainter({
    required this.series,
    required this.color,
    required this.text,
    required this.muted,
    required this.grid,
    required this.surface,
    required this.activeSeriesId,
    required this.selectedPointIndex,
    required this.activePointProgress,
  });

  final List<_YieldCurveDisplaySeries> series;
  final Color color;
  final Color text;
  final Color muted;
  final Color grid;
  final Color surface;
  final String activeSeriesId;
  final int? selectedPointIndex;
  final double activePointProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final drawableSeries = [
      for (final item in series)
        if (item.points.length >= 2) item,
    ];
    if (drawableSeries.isEmpty || size.width <= 0 || size.height <= 0) return;

    final chart = _yieldCurveChartBounds(size);
    final allPoints = [
      for (final item in drawableSeries) ...item.points,
    ];

    final minYear = allPoints.map((point) => point.years).reduce(math.min);
    final maxYear = allPoints.map((point) => point.years).reduce(math.max);
    final minRate =
        (allPoints.map((point) => point.rate).reduce(math.min) - 0.6).floor();
    final maxRate =
        (allPoints.map((point) => point.rate).reduce(math.max) + 0.6).ceil();
    final rateSpan = math.max(1.0, (maxRate - minRate).toDouble());
    final yearSpan = math.max(0.1, maxYear - minYear);

    double xFor(_YieldCurvePoint point) =>
        chart.left + (point.years - minYear) / yearSpan * chart.width;
    double yFor(_YieldCurvePoint point) =>
        chart.bottom - (point.rate - minRate) / rateSpan * chart.height;

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.72)
      ..strokeWidth = 0.8;
    for (var index = 0; index <= 4; index++) {
      final y = chart.top + chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final rate = maxRate - rateSpan * index / 4;
      _paintChartLabel(
        canvas,
        '${rate.toStringAsFixed(1).replaceAll('.', ',')}%',
        Offset(0, y - 6),
        muted,
        width: _yieldCurveChartLeft - 8,
        align: TextAlign.right,
      );
    }

    final axisPaint = Paint()
      ..color = grid
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chart.left, chart.top),
      Offset(chart.left, chart.bottom),
      axisPaint,
    );

    final orderedSeries = [
      for (final item in drawableSeries)
        if (!item.isZone) item,
      for (final item in drawableSeries)
        if (item.isZone) item,
    ];
    final fillSeries = _fillYieldSeries(orderedSeries);
    if (fillSeries != null) {
      final fillLine = _yieldSeriesPath(fillSeries.points, xFor, yFor);
      final fillPath = Path()
        ..moveTo(xFor(fillSeries.points.first), chart.bottom)
        ..addPath(fillLine, Offset.zero)
        ..lineTo(xFor(fillSeries.points.last), chart.bottom)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fillSeries.color.withValues(alpha: 0.16),
              fillSeries.color.withValues(alpha: 0.02),
            ],
          ).createShader(chart),
      );
    }

    for (final item in orderedSeries) {
      final path = _yieldSeriesPath(item.points, xFor, yFor);
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = item.isZone ? 2.5 : 1.9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = item.color.withValues(alpha: item.isZone ? 0.98 : 0.82),
      );
    }

    final activeSeries = _seriesById(drawableSeries, activeSeriesId);
    if (selectedPointIndex != null &&
        selectedPointIndex! >= 0 &&
        activeSeries != null &&
        selectedPointIndex! < activeSeries.points.length &&
        activePointProgress > 0) {
      final progress = activePointProgress.clamp(0.0, 1.0);
      final point = activeSeries.points[selectedPointIndex!];
      final offset = Offset(xFor(point), yFor(point));
      final guidePaint = Paint()
        ..color = activeSeries.color.withValues(alpha: 0.30 * progress)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(offset.dx, chart.top),
        Offset(offset.dx, chart.bottom),
        guidePaint,
      );
      canvas.drawCircle(
        offset,
        5.2 + 3.2 * progress,
        Paint()..color = activeSeries.color.withValues(alpha: 0.16 * progress),
      );
      canvas.drawCircle(
        offset,
        3.8 + 1.3 * progress,
        Paint()..color = surface.withValues(alpha: 0.98 * progress),
      );
      canvas.drawCircle(
        offset,
        2.4 + progress,
        Paint()..color = activeSeries.color.withValues(alpha: progress),
      );
      _paintSelectionLabel(
        canvas,
        chart,
        offset,
        point,
        activeSeries,
        progress,
      );
    }

    final labelPoints = activeSeries?.points ?? drawableSeries.first.points;
    final labelIndexes = <int>{
      0,
      (labelPoints.length / 3).floor(),
      (labelPoints.length * 2 / 3).floor(),
      labelPoints.length - 1,
    };
    for (final index in labelIndexes) {
      final point = labelPoints[index.clamp(0, labelPoints.length - 1)];
      _paintChartLabel(
        canvas,
        point.label,
        Offset(xFor(point) - 26, chart.bottom + 10),
        muted,
        width: 52,
        align: TextAlign.center,
      );
    }
  }

  void _paintChartLabel(
    Canvas canvas,
    String label,
    Offset offset,
    Color color, {
    required double width,
    required TextAlign align,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  void _paintSelectionLabel(
    Canvas canvas,
    Rect chart,
    Offset anchor,
    _YieldCurvePoint point,
    _YieldCurveDisplaySeries series,
    double progress,
  ) {
    final label =
        '${series.label} · ${point.label} · ${_formatYieldRate(point.rate)}';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: text.withValues(alpha: progress),
          fontSize: 9.2,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 112);

    final width = painter.width + 14;
    const height = 22.0;
    final left = (anchor.dx - width / 2)
        .clamp(chart.left + 4, chart.right - width - 4)
        .toDouble();
    final top = (anchor.dy - 30 - 4 * progress)
        .clamp(chart.top + 4, chart.bottom - 34)
        .toDouble();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = surface.withValues(alpha: 0.96 * progress),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = series.color.withValues(alpha: 0.28 * progress),
    );
    painter.paint(canvas, Offset(left + 7, top + 6));
  }

  @override
  bool shouldRepaint(covariant _YieldCurvePainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.color != color ||
        oldDelegate.text != text ||
        oldDelegate.muted != muted ||
        oldDelegate.grid != grid ||
        oldDelegate.surface != surface ||
        oldDelegate.activeSeriesId != activeSeriesId ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.activePointProgress != activePointProgress;
  }
}

class _YieldCurveRepository {
  const _YieldCurveRepository({required this.api});

  final RwaApiService api;

  static const _cacheKey = 'market_yield_curves.snapshots.v1';
  static const _umoaPageUrl =
      'https://www.umoatitres.org/fr/ressources-2/courbe-des-taux/';
  static const _umoaSeedWorkbookUrl =
      'https://www.umoatitres.org/wp-content/uploads/2026/06/COURBES-DE-TAUX.au_.29.05.2026.xlsx';
  static const _beacPdfUrl =
      'https://www.beac.int/wp-content/uploads/2016/10/Courbe-des-taux-de-rendement-des-titres-publics-CEMAC-mars-26.pdf';
  static const _onlineHeaders = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/125.0 Safari/537.36',
  };

  static const List<_YieldCurveSnapshot> seedSnapshots = [
    _YieldCurveSnapshot(
      id: 'uemoa',
      title: 'Zone UEMOA',
      sourceName: 'UMOA-Titres',
      sourceUrl: _umoaPageUrl,
      sourceDateLabel: '29/05/2026',
      methodology:
          'Courbe agrégée par moyenne des taux après lissage publiés par pays UEMOA.',
      color: _marketPrimary,
      points: [
        _YieldCurvePoint('1 mois', 0.0833333, 5.613200),
        _YieldCurvePoint('3 mois', 0.25, 6.469800),
        _YieldCurvePoint('6 mois', 0.5, 6.395800),
        _YieldCurvePoint('9 mois', 0.75, 6.401200),
        _YieldCurvePoint('1 an', 1, 6.471800),
        _YieldCurvePoint('2 ans', 2, 6.924700),
        _YieldCurvePoint('3 ans', 3, 7.270900),
        _YieldCurvePoint('4 ans', 4, 7.444600),
        _YieldCurvePoint('5 ans', 5, 7.487200),
        _YieldCurvePoint('6 ans', 6, 7.442300),
        _YieldCurvePoint('7 ans', 7, 7.343200),
        _YieldCurvePoint('8 ans', 8, 7.260700),
        _YieldCurvePoint('9 ans', 9, 7.146100),
        _YieldCurvePoint('10 ans', 10, 7.018200),
        _YieldCurvePoint('11 ans', 11, 6.798600),
        _YieldCurvePoint('12 ans', 12, 6.619600),
        _YieldCurvePoint('13 ans', 13, 6.444500),
        _YieldCurvePoint('14 ans', 14, 6.275900),
        _YieldCurvePoint('15 ans', 15, 6.115700),
      ],
      countryCurves: [
        _YieldCurveCountryCurve(
          country: 'Bénin',
          points: [
            _YieldCurvePoint('3 mois', 0.25, 2.990954),
            _YieldCurvePoint('6 mois', 0.5, 4.715681),
            _YieldCurvePoint('9 mois', 0.75, 5.680358),
            _YieldCurvePoint('1 an', 1, 6.209993),
            _YieldCurvePoint('2 ans', 2, 6.691528),
            _YieldCurvePoint('3 ans', 3, 6.598669),
            _YieldCurvePoint('4 ans', 4, 6.540016),
            _YieldCurvePoint('5 ans', 5, 6.574211),
            _YieldCurvePoint('6 ans', 6, 6.683055),
            _YieldCurvePoint('7 ans', 7, 6.840883),
            _YieldCurvePoint('8 ans', 8, 7.026519),
            _YieldCurvePoint('9 ans', 9, 7.224606),
            _YieldCurvePoint('10 ans', 10, 7.424713),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Burkina Faso',
          points: [
            _YieldCurvePoint('3 mois', 0.25, 10.210034),
            _YieldCurvePoint('6 mois', 0.5, 7.633648),
            _YieldCurvePoint('9 mois', 0.75, 6.378918),
            _YieldCurvePoint('1 an', 1, 5.852344),
            _YieldCurvePoint('2 ans', 2, 6.172297),
            _YieldCurvePoint('3 ans', 3, 6.958613),
            _YieldCurvePoint('4 ans', 4, 7.402324),
            _YieldCurvePoint('5 ans', 5, 7.539664),
            _YieldCurvePoint('6 ans', 6, 7.467567),
            _YieldCurvePoint('7 ans', 7, 7.263432),
            _YieldCurvePoint('8 ans', 8, 6.982091),
            _YieldCurvePoint('9 ans', 9, 6.660880),
            _YieldCurvePoint('10 ans', 10, 6.324529),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Côte d\'Ivoire',
          points: [
            _YieldCurvePoint('1 mois', 0.0833333, 4.582956),
            _YieldCurvePoint('3 mois', 0.25, 4.221409),
            _YieldCurvePoint('6 mois', 0.5, 4.148893),
            _YieldCurvePoint('9 mois', 0.75, 4.359879),
            _YieldCurvePoint('1 an', 1, 4.681646),
            _YieldCurvePoint('2 ans', 2, 5.928647),
            _YieldCurvePoint('3 ans', 3, 6.678333),
            _YieldCurvePoint('4 ans', 4, 7.085710),
            _YieldCurvePoint('5 ans', 5, 7.302869),
            _YieldCurvePoint('6 ans', 6, 7.410356),
            _YieldCurvePoint('7 ans', 7, 7.452156),
            _YieldCurvePoint('8 ans', 8, 7.454102),
            _YieldCurvePoint('9 ans', 9, 7.432137),
            _YieldCurvePoint('10 ans', 10, 7.396362),
            _YieldCurvePoint('11 ans', 11, 7.353239),
            _YieldCurvePoint('12 ans', 12, 7.306894),
            _YieldCurvePoint('13 ans', 13, 7.259929),
            _YieldCurvePoint('14 ans', 14, 7.213940),
            _YieldCurvePoint('15 ans', 15, 7.169862),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Guinée-Bissau',
          points: [
            _YieldCurvePoint('3 mois', 0.25, 5.515108),
            _YieldCurvePoint('6 mois', 0.5, 5.297135),
            _YieldCurvePoint('9 mois', 0.75, 5.365819),
            _YieldCurvePoint('1 an', 1, 5.581698),
            _YieldCurvePoint('2 ans', 2, 6.762488),
            _YieldCurvePoint('3 ans', 3, 7.644052),
            _YieldCurvePoint('4 ans', 4, 8.098125),
            _YieldCurvePoint('5 ans', 5, 8.226151),
            _YieldCurvePoint('6 ans', 6, 8.134052),
            _YieldCurvePoint('7 ans', 7, 7.903239),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Mali',
          points: [
            _YieldCurvePoint('1 mois', 0.0833333, 6.276536),
            _YieldCurvePoint('3 mois', 0.25, 6.051355),
            _YieldCurvePoint('6 mois', 0.5, 5.887475),
            _YieldCurvePoint('9 mois', 0.75, 5.867032),
            _YieldCurvePoint('1 an', 1, 5.937270),
            _YieldCurvePoint('2 ans', 2, 6.550344),
            _YieldCurvePoint('3 ans', 3, 7.132631),
            _YieldCurvePoint('4 ans', 4, 7.503899),
            _YieldCurvePoint('5 ans', 5, 7.691527),
            _YieldCurvePoint('6 ans', 6, 7.750529),
            _YieldCurvePoint('7 ans', 7, 7.726427),
            _YieldCurvePoint('8 ans', 8, 7.651507),
            _YieldCurvePoint('9 ans', 9, 7.547534),
            _YieldCurvePoint('10 ans', 10, 7.428840),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Niger',
          points: [
            _YieldCurvePoint('1 mois', 0.0833333, 5.330627),
            _YieldCurvePoint('3 mois', 0.25, 10.086622),
            _YieldCurvePoint('6 mois', 0.5, 10.684822),
            _YieldCurvePoint('9 mois', 0.75, 10.639201),
            _YieldCurvePoint('1 an', 1, 10.453893),
            _YieldCurvePoint('2 ans', 2, 9.497635),
            _YieldCurvePoint('3 ans', 3, 8.638126),
            _YieldCurvePoint('4 ans', 4, 7.950300),
            _YieldCurvePoint('5 ans', 5, 7.420562),
            _YieldCurvePoint('6 ans', 6, 7.025558),
            _YieldCurvePoint('7 ans', 7, 6.742591),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Sénégal',
          points: [
            _YieldCurvePoint('1 mois', 0.0833333, 6.262821),
            _YieldCurvePoint('3 mois', 0.25, 6.748154),
            _YieldCurvePoint('6 mois', 0.5, 7.129395),
            _YieldCurvePoint('9 mois', 0.75, 7.291151),
            _YieldCurvePoint('1 an', 1, 7.357578),
            _YieldCurvePoint('2 ans', 2, 7.507158),
            _YieldCurvePoint('3 ans', 3, 7.757887),
            _YieldCurvePoint('4 ans', 4, 7.974260),
            _YieldCurvePoint('5 ans', 5, 8.075365),
            _YieldCurvePoint('6 ans', 6, 8.056367),
            _YieldCurvePoint('7 ans', 7, 7.938937),
            _YieldCurvePoint('8 ans', 8, 7.749200),
            _YieldCurvePoint('9 ans', 9, 7.510444),
            _YieldCurvePoint('10 ans', 10, 7.241372),
            _YieldCurvePoint('11 ans', 11, 6.956226),
            _YieldCurvePoint('12 ans', 12, 6.665471),
            _YieldCurvePoint('13 ans', 13, 6.376557),
            _YieldCurvePoint('14 ans', 14, 6.094609),
            _YieldCurvePoint('15 ans', 15, 5.822999),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Togo',
          points: [
            _YieldCurvePoint('3 mois', 0.25, 5.934855),
            _YieldCurvePoint('6 mois', 0.5, 5.669427),
            _YieldCurvePoint('9 mois', 0.75, 5.626942),
            _YieldCurvePoint('1 an', 1, 5.699903),
            _YieldCurvePoint('2 ans', 2, 6.287686),
            _YieldCurvePoint('3 ans', 3, 6.758810),
            _YieldCurvePoint('4 ans', 4, 7.002037),
            _YieldCurvePoint('5 ans', 5, 7.067013),
            _YieldCurvePoint('6 ans', 6, 7.010836),
            _YieldCurvePoint('7 ans', 7, 6.878180),
            _YieldCurvePoint('8 ans', 8, 6.700972),
            _YieldCurvePoint('9 ans', 9, 6.501098),
            _YieldCurvePoint('10 ans', 10, 6.293094),
            _YieldCurvePoint('11 ans', 11, 6.086302),
            _YieldCurvePoint('12 ans', 12, 5.886470),
            _YieldCurvePoint('13 ans', 13, 5.696898),
            _YieldCurvePoint('14 ans', 14, 5.519257),
            _YieldCurvePoint('15 ans', 15, 5.354149),
          ],
        ),
      ],
    ),
    _YieldCurveSnapshot(
      id: 'cemac',
      title: 'Zone CEMAC',
      sourceName: 'BEAC',
      sourceUrl: _beacPdfUrl,
      sourceDateLabel: 'Mars 2026',
      methodology:
          'Courbe agrégée par moyenne des courbes Cameroun, Congo et Gabon publiées par la BEAC.',
      color: _marketSuccess,
      points: [
        _YieldCurvePoint('3 mois', 0.25, 6.353846),
        _YieldCurvePoint('6 mois', 0.5, 7.335043),
        _YieldCurvePoint('1 an', 1, 8.540326),
        _YieldCurvePoint('1,5 ans', 1.5, 9.116861),
        _YieldCurvePoint('2 ans', 2, 9.345299),
        _YieldCurvePoint('3 ans', 3, 9.338772),
        _YieldCurvePoint('3,5 ans', 3.5, 9.249573),
        _YieldCurvePoint('4 ans', 4, 9.140793),
        _YieldCurvePoint('5 ans', 5, 8.931935),
        _YieldCurvePoint('6 ans', 6, 8.753535),
        _YieldCurvePoint('7 ans', 7, 8.614297),
        _YieldCurvePoint('8 ans', 8, 8.503341),
        _YieldCurvePoint('9 ans', 9, 8.414141),
        _YieldCurvePoint('10 ans', 10, 8.340171),
      ],
      countryCurves: [
        _YieldCurveCountryCurve(
          country: 'Cameroun',
          points: [
            _YieldCurvePoint('3 mois', 0.25, 6.3082),
            _YieldCurvePoint('6 mois', 0.5, 7.1566),
            _YieldCurvePoint('1 an', 1, 8.3184),
            _YieldCurvePoint('1,5 ans', 1.5, 9.0037),
            _YieldCurvePoint('2 ans', 2, 9.4084),
            _YieldCurvePoint('3 ans', 3, 9.7935),
            _YieldCurvePoint('3,5 ans', 3.5, 9.8783),
            _YieldCurvePoint('4 ans', 4, 9.9240),
            _YieldCurvePoint('5 ans', 5, 9.9697),
            _YieldCurvePoint('6 ans', 6, 9.9828),
            _YieldCurvePoint('7 ans', 7, 9.9893),
            _YieldCurvePoint('8 ans', 8, 9.9893),
            _YieldCurvePoint('9 ans', 9, 9.9828),
            _YieldCurvePoint('10 ans', 10, 9.9828),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Congo',
          points: [
            _YieldCurvePoint('3 mois', 0.25, 6.6345),
            _YieldCurvePoint('6 mois', 0.5, 7.6657),
            _YieldCurvePoint('1 an', 1, 9.0886),
            _YieldCurvePoint('1,5 ans', 1.5, 9.9632),
            _YieldCurvePoint('2 ans', 2, 10.4984),
            _YieldCurvePoint('3 ans', 3, 11.0336),
            _YieldCurvePoint('3,5 ans', 3.5, 11.1706),
            _YieldCurvePoint('4 ans', 4, 11.2555),
            _YieldCurvePoint('5 ans', 5, 11.3534),
            _YieldCurvePoint('6 ans', 6, 11.3991),
            _YieldCurvePoint('7 ans', 7, 11.4317),
            _YieldCurvePoint('8 ans', 8, 11.4513),
            _YieldCurvePoint('9 ans', 9, 11.4643),
            _YieldCurvePoint('10 ans', 10, 11.4709),
          ],
        ),
        _YieldCurveCountryCurve(
          country: 'Gabon',
          points: [
            _YieldCurvePoint('3 mois', 0.25, 6.1189),
            _YieldCurvePoint('6 mois', 0.5, 7.1828),
            _YieldCurvePoint('1 an', 1, 8.2140),
            _YieldCurvePoint('1,5 ans', 1.5, 8.3837),
            _YieldCurvePoint('2 ans', 2, 8.1291),
            _YieldCurvePoint('3 ans', 3, 7.1893),
            _YieldCurvePoint('3,5 ans', 3.5, 6.6998),
            _YieldCurvePoint('4 ans', 4, 6.2429),
            _YieldCurvePoint('5 ans', 5, 5.4727),
            _YieldCurvePoint('6 ans', 6, 4.8788),
            _YieldCurvePoint('7 ans', 7, 4.4219),
            _YieldCurvePoint('8 ans', 8, 4.0695),
            _YieldCurvePoint('9 ans', 9, 3.7953),
            _YieldCurvePoint('10 ans', 10, 3.5669),
          ],
        ),
      ],
    ),
  ];

  Future<List<_YieldCurveSnapshot>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return seedSnapshots;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final snapshots = decoded
          .whereType<Map<String, dynamic>>()
          .map(_YieldCurveSnapshot.fromJson)
          .map(_hydrateYieldSnapshotFromSeed)
          .where((snapshot) => snapshot.points.length >= 2)
          .toList(growable: false);
      return snapshots.length >= 2 ? snapshots : seedSnapshots;
    } catch (_) {
      return seedSnapshots;
    }
  }

  Future<_YieldCurveRefreshResult> refreshOnline(
    List<_YieldCurveSnapshot> current,
  ) async {
    final updatedById = {for (final snapshot in current) snapshot.id: snapshot};
    final messages = <String>[];
    var refreshed = false;

    try {
      final uemoa = await _fetchUemoaCurve();
      updatedById[uemoa.id] = uemoa;
      refreshed = true;
      messages.add('UEMOA actualisée au ${uemoa.sourceDateLabel}');
    } catch (error) {
      messages.add('UEMOA conservée en local');
    }

    try {
      final cemac = await _fetchCemacCurveViaAi(
        updatedById['cemac'] ?? seedSnapshots.last,
      );
      updatedById[cemac.id] = cemac;
      refreshed = true;
      messages.add('CEMAC actualisée au ${cemac.sourceDateLabel}');
    } catch (error) {
      final localCemac = updatedById['cemac'] ?? seedSnapshots.last;
      messages.add(
        'CEMAC non actualisée, courbe locale conservée au ${localCemac.sourceDateLabel}',
      );
    }

    final snapshots = [
      updatedById['uemoa'] ?? seedSnapshots.first,
      updatedById['cemac'] ?? seedSnapshots.last,
    ];
    if (refreshed) {
      await _save(snapshots);
    }

    return _YieldCurveRefreshResult(
      snapshots: snapshots,
      message: messages.join('\n'),
    );
  }

  Future<void> _save(List<_YieldCurveSnapshot> snapshots) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cacheKey,
      jsonEncode([for (final snapshot in snapshots) snapshot.toJson()]),
    );
  }

  Future<_YieldCurveSnapshot> _fetchUemoaCurve() async {
    final pageResponse = await http
        .get(Uri.parse(_umoaPageUrl), headers: _onlineHeaders)
        .timeout(const Duration(seconds: 18));
    if (pageResponse.statusCode >= 400) {
      throw StateError('UMOA-Titres indisponible.');
    }

    final linkPattern = RegExp(
      r'''href=["']([^"']+\.xlsx)["'][^>]*>\s*COURBES D(?:E|ES) TAUX au\s*([0-9]{2}[./-][0-9]{2}[./-][0-9]{4})''',
      caseSensitive: false,
      multiLine: true,
    );
    final candidates = <_YieldCurveSourceCandidate>[
      _YieldCurveSourceCandidate(
        url: _umoaSeedWorkbookUrl,
        sourceDate: DateTime(2026, 5, 29),
      ),
    ];
    for (final match in linkPattern.allMatches(pageResponse.body)) {
      final date = _parseYieldSourceDate(match.group(2)!);
      if (date == null) continue;
      candidates.add(
        _YieldCurveSourceCandidate(
          url: Uri.parse(_umoaPageUrl)
              .resolve(match.group(1)!.replaceAll('&amp;', '&'))
              .toString(),
          sourceDate: date,
        ),
      );
    }
    if (candidates.isEmpty) {
      throw StateError('Lien UMOA-Titres introuvable.');
    }
    candidates
        .sort((left, right) => left.sourceDate.compareTo(right.sourceDate));

    final selected = candidates.last;
    final workbookResponse = await http
        .get(Uri.parse(selected.url), headers: _onlineHeaders)
        .timeout(const Duration(seconds: 24));
    if (workbookResponse.statusCode >= 400) {
      throw StateError('Fichier UMOA-Titres indisponible.');
    }

    return _parseUemoaWorkbook(
      workbookResponse.bodyBytes,
      sourceUrl: selected.url,
      sourceDateLabel: _formatYieldSourceDate(selected.sourceDate),
    );
  }

  Future<_YieldCurveSnapshot> _fetchCemacCurveViaAi(
    _YieldCurveSnapshot current,
  ) async {
    final payload = await api
        .refreshCemacYieldCurves()
        .timeout(const Duration(seconds: 140));
    final countryCurves = _parseYieldCountryCurves(payload['curves']);
    final aggregatePoints = _parseYieldCurvePoints(payload['aggregate_points']);
    if (countryCurves.isEmpty || aggregatePoints.length < 2) {
      throw StateError('Extraction CEMAC non exploitable.');
    }

    final sourceUrl = (payload['source_url'] as String?)?.trim();
    final sourceDateLabel = (payload['source_date_label'] as String?)?.trim();
    final methodology = (payload['methodology'] as String?)?.trim();

    return current.copyWith(
      sourceUrl: sourceUrl == null || sourceUrl.isEmpty
          ? current.sourceUrl
          : sourceUrl,
      sourceDateLabel: sourceDateLabel == null || sourceDateLabel.isEmpty
          ? current.sourceDateLabel
          : sourceDateLabel,
      methodology: methodology == null || methodology.isEmpty
          ? 'Données extraites du PDF BEAC avec conservation des courbes pays.'
          : methodology,
      points: aggregatePoints,
      countryCurves: countryCurves,
      checkedAt: DateTime.now(),
    );
  }

  _YieldCurveSnapshot _parseUemoaWorkbook(
    Uint8List bytes, {
    required String sourceUrl,
    required String sourceDateLabel,
  }) {
    final workbook = Excel.decodeBytes(bytes);
    final ratesByMaturity = <double, List<double>>{};
    final countryCurves = <_YieldCurveCountryCurve>[];

    for (final entry in workbook.tables.entries) {
      final sheetName = _normalizeYieldText(entry.key);
      if (sheetName.startsWith('feuil')) continue;
      final rows = entry.value.rows;
      final sheetRatesByMaturity = <double, List<double>>{};
      int? maturityColumn;
      int? smoothedRateColumn;
      var headerRow = -1;

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
          final header = _normalizeYieldText(_yieldCellText(row[columnIndex]));
          if (header == 'maturite') {
            maturityColumn = columnIndex;
          }
          if (header.contains('taux apres') || header.contains('taux lisse')) {
            smoothedRateColumn = columnIndex;
          }
        }
        if (maturityColumn != null && smoothedRateColumn != null) {
          headerRow = rowIndex;
          break;
        }
      }

      if (headerRow < 0 ||
          maturityColumn == null ||
          smoothedRateColumn == null) {
        continue;
      }

      for (final row in rows.skip(headerRow + 1)) {
        if (maturityColumn >= row.length || smoothedRateColumn >= row.length) {
          continue;
        }
        final years = _parseYieldMaturityYears(
          _yieldCellText(row[maturityColumn]),
        );
        final rate = _yieldCellNumber(row[smoothedRateColumn]);
        if (years == null || rate == null || !rate.isFinite) continue;
        final percentRate = rate.abs() <= 1 ? rate * 100 : rate;
        ratesByMaturity.putIfAbsent(years, () => []).add(percentRate);
        sheetRatesByMaturity.putIfAbsent(years, () => []).add(percentRate);
      }

      if (sheetRatesByMaturity.length >= 2) {
        final country = _canonicalUemoaCountry(entry.key) ?? entry.key.trim();
        countryCurves.add(
          _YieldCurveCountryCurve(
            country: country,
            points: _averageYieldPoints(sheetRatesByMaturity),
          ),
        );
      }
    }

    if (ratesByMaturity.length < 2) {
      throw StateError('Courbe UMOA-Titres non lisible.');
    }

    final points = _averageYieldPoints(ratesByMaturity);

    return seedSnapshots.first.copyWith(
      sourceUrl: sourceUrl,
      sourceDateLabel: sourceDateLabel,
      checkedAt: DateTime.now(),
      points: points,
      countryCurves: countryCurves,
    );
  }
}

_YieldCurveSnapshot _hydrateYieldSnapshotFromSeed(
  _YieldCurveSnapshot snapshot,
) {
  if (snapshot.id != 'uemoa') return snapshot;

  for (final seed in _YieldCurveRepository.seedSnapshots) {
    if (seed.id == snapshot.id && seed.countryCurves.isNotEmpty) {
      final mergedCurves = [...snapshot.countryCurves];
      for (final seedCurve in seed.countryCurves) {
        final existingIndex = mergedCurves.indexWhere(
          (curve) =>
              _normalizeYieldText(curve.country) ==
              _normalizeYieldText(seedCurve.country),
        );
        if (existingIndex < 0) {
          mergedCurves.add(seedCurve);
        } else if (mergedCurves[existingIndex].points.length < 2) {
          mergedCurves[existingIndex] = seedCurve;
        }
      }
      return snapshot.copyWith(countryCurves: mergedCurves);
    }
  }
  return snapshot;
}

class _YieldCurveRefreshResult {
  const _YieldCurveRefreshResult({
    required this.snapshots,
    required this.message,
  });

  final List<_YieldCurveSnapshot> snapshots;
  final String message;
}

class _YieldCurveSourceCandidate {
  const _YieldCurveSourceCandidate({
    required this.url,
    required this.sourceDate,
  });

  final String url;
  final DateTime sourceDate;
}

List<_YieldCurveCountryCurve> _parseYieldCountryCurves(Object? payload) {
  final items = payload is List ? payload : const [];
  final curves = <_YieldCurveCountryCurve>[];
  for (final item in items) {
    if (item is! Map) continue;
    final values = Map<String, dynamic>.from(item);
    final country =
        (values['country'] ?? values['pays'] ?? '').toString().trim();
    final points = _parseYieldCurvePoints(values['points']);
    if (country.isEmpty || points.length < 2) continue;
    curves.add(_YieldCurveCountryCurve(country: country, points: points));
  }
  return curves;
}

List<_YieldCurvePoint> _parseYieldCurvePoints(Object? payload) {
  final items = payload is List ? payload : const [];
  final points = <_YieldCurvePoint>[];
  final seen = <double>{};
  for (final item in items) {
    if (item is! Map) continue;
    final values = Map<String, dynamic>.from(item);
    final label =
        (values['maturity'] ?? values['maturite'] ?? values['label'] ?? '')
            .toString()
            .trim();
    final years = _yieldDynamicNumber(values['years'] ?? values['annees']) ??
        _parseYieldMaturityYears(label);
    final rate = _yieldDynamicNumber(values['rate'] ?? values['taux']);
    if (years == null || rate == null || years <= 0) continue;
    final percentRate = rate.abs() <= 1 ? rate * 100 : rate;
    if (percentRate <= 0 || percentRate > 30) continue;
    final key = double.parse(years.toStringAsFixed(6));
    if (!seen.add(key)) continue;
    points.add(
      _YieldCurvePoint(
        label.isEmpty ? _formatYieldMaturityLabel(years) : label,
        years,
        percentRate,
      ),
    );
  }
  points.sort((left, right) => left.years.compareTo(right.years));
  return points;
}

List<_YieldCurvePoint> _averageYieldPoints(Map<double, List<double>> values) {
  final points = values.entries.map((entry) {
    final average =
        entry.value.reduce((left, right) => left + right) / entry.value.length;
    return _YieldCurvePoint(
      _formatYieldMaturityLabel(entry.key),
      entry.key,
      average,
    );
  }).toList()
    ..sort((left, right) => left.years.compareTo(right.years));
  return points;
}

double? _yieldDynamicNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return _parseYieldNumber(value.toString());
}

class _YieldCurveDisplaySeries {
  const _YieldCurveDisplaySeries({
    required this.id,
    required this.label,
    required this.color,
    required this.points,
    required this.isZone,
  });

  final String id;
  final String label;
  final Color color;
  final List<_YieldCurvePoint> points;
  final bool isZone;

  _YieldCurvePoint? pointNear(double targetYears) {
    if (points.isEmpty) return null;
    return points.reduce((best, point) {
      final bestDistance = (best.years - targetYears).abs();
      final pointDistance = (point.years - targetYears).abs();
      return pointDistance < bestDistance ? point : best;
    });
  }
}

class _YieldCurvePointStripItem {
  const _YieldCurvePointStripItem({
    required this.series,
    required this.point,
    required this.pointIndex,
  });

  final _YieldCurveDisplaySeries series;
  final _YieldCurvePoint point;
  final int pointIndex;
}

class _YieldCurveSnapshot {
  const _YieldCurveSnapshot({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    required this.sourceDateLabel,
    required this.methodology,
    required this.color,
    required this.points,
    this.countryCurves = const [],
    this.checkedAt,
  });

  final String id;
  final String title;
  final String sourceName;
  final String sourceUrl;
  final String sourceDateLabel;
  final String methodology;
  final Color color;
  final List<_YieldCurvePoint> points;
  final List<_YieldCurveCountryCurve> countryCurves;
  final DateTime? checkedAt;

  bool get hasSeriesControls =>
      points.length >= 2 ||
      countryCurves.isNotEmpty ||
      _yieldCountriesFor(this).isNotEmpty;

  List<_YieldCurveDisplaySeries> displaySeries(Set<String> selectedIds) {
    final sanitized = _sanitizeYieldSelection(this, selectedIds);
    final items = <_YieldCurveDisplaySeries>[];
    if (sanitized.contains(_yieldZoneSeriesId)) {
      items.add(
        _YieldCurveDisplaySeries(
          id: _yieldZoneSeriesId,
          label: 'Zone',
          color: color,
          points: points,
          isZone: true,
        ),
      );
    }
    for (final country in _yieldCountriesFor(this)) {
      final id = _yieldCountrySeriesId(country);
      if (!sanitized.contains(id)) continue;
      final curve = countryCurve(country);
      if (curve == null) continue;
      items.add(
        _YieldCurveDisplaySeries(
          id: id,
          label: country,
          color: _yieldCountryColorFor(country, this.id),
          points: curve.points,
          isZone: false,
        ),
      );
    }
    return items;
  }

  _YieldCurvePoint? pointNear(double targetYears) {
    if (points.isEmpty) return null;
    return points.reduce((best, point) {
      final bestDistance = (best.years - targetYears).abs();
      final pointDistance = (point.years - targetYears).abs();
      return pointDistance < bestDistance ? point : best;
    });
  }

  _YieldCurveCountryCurve? countryCurve(String country) {
    final target = _normalizeYieldText(country);
    for (final curve in countryCurves) {
      if (_normalizeYieldText(curve.country) == target) {
        return curve;
      }
    }
    return null;
  }

  _YieldCurveSnapshot copyWith({
    String? sourceUrl,
    String? sourceDateLabel,
    String? methodology,
    List<_YieldCurvePoint>? points,
    List<_YieldCurveCountryCurve>? countryCurves,
    DateTime? checkedAt,
  }) {
    return _YieldCurveSnapshot(
      id: id,
      title: title,
      sourceName: sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceDateLabel: sourceDateLabel ?? this.sourceDateLabel,
      methodology: methodology ?? this.methodology,
      color: color,
      points: points ?? this.points,
      countryCurves: countryCurves ?? this.countryCurves,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'sourceDateLabel': sourceDateLabel,
      'methodology': methodology,
      'color': color.toARGB32(),
      'checkedAt': checkedAt?.toIso8601String(),
      'points': [for (final point in points) point.toJson()],
      'countryCurves': [
        for (final curve in countryCurves) curve.toJson(),
      ],
    };
  }

  factory _YieldCurveSnapshot.fromJson(Map<String, dynamic> json) {
    return _YieldCurveSnapshot(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      sourceDateLabel: json['sourceDateLabel'] as String? ?? '',
      methodology: json['methodology'] as String? ?? '',
      color:
          Color((json['color'] as num?)?.toInt() ?? _marketPrimary.toARGB32()),
      checkedAt: json['checkedAt'] is String
          ? DateTime.tryParse(json['checkedAt'] as String)
          : null,
      points: [
        for (final item in (json['points'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) _YieldCurvePoint.fromJson(item),
      ],
      countryCurves: [
        for (final item
            in (json['countryCurves'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>)
            _YieldCurveCountryCurve.fromJson(item),
      ],
    );
  }
}

class _YieldCurveCountryCurve {
  const _YieldCurveCountryCurve({
    required this.country,
    required this.points,
  });

  final String country;
  final List<_YieldCurvePoint> points;

  Map<String, Object?> toJson() {
    return {
      'country': country,
      'points': [for (final point in points) point.toJson()],
    };
  }

  factory _YieldCurveCountryCurve.fromJson(Map<String, dynamic> json) {
    return _YieldCurveCountryCurve(
      country: json['country'] as String? ?? '',
      points: [
        for (final item in (json['points'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) _YieldCurvePoint.fromJson(item),
      ],
    );
  }
}

class _YieldCurvePoint {
  const _YieldCurvePoint(this.label, this.years, this.rate);

  final String label;
  final double years;
  final double rate;

  Map<String, Object?> toJson() {
    return {
      'label': label,
      'years': years,
      'rate': rate,
    };
  }

  factory _YieldCurvePoint.fromJson(Map<String, dynamic> json) {
    return _YieldCurvePoint(
      json['label'] as String? ?? '',
      (json['years'] as num?)?.toDouble() ?? 0,
      (json['rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

String _formatYieldRate(double value) {
  final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
  return '$formatted %';
}

String _formatYieldSpread(double basisPoints) {
  final rounded = basisPoints.round();
  final sign = rounded > 0 ? '+' : '';
  return '$sign$rounded pb';
}

List<String> _yieldKnownCountriesForZone(String zoneId) {
  return switch (zoneId) {
    'uemoa' => _uemoaYieldCountries,
    'cemac' => _cemacYieldCountries,
    _ => const <String>[],
  };
}

Color _yieldCountryColorFor(String country, String zoneId) {
  final normalized = _normalizeYieldText(country);
  final zoneCountries = _yieldKnownCountriesForZone(zoneId);
  final zoneIndex = zoneCountries.indexWhere(
    (item) => _normalizeYieldText(item) == normalized,
  );
  if (zoneIndex >= 0) {
    final offset = zoneId == 'cemac' ? _uemoaYieldCountries.length : 0;
    return _yieldCountryPalette[
        (offset + zoneIndex) % _yieldCountryPalette.length];
  }

  final allCountries = [..._uemoaYieldCountries, ..._cemacYieldCountries];
  final globalIndex = allCountries.indexWhere(
    (item) => _normalizeYieldText(item) == normalized,
  );
  if (globalIndex >= 0) {
    return _yieldCountryPalette[globalIndex % _yieldCountryPalette.length];
  }

  final hash = normalized.codeUnits.fold<int>(
    0,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );
  return _yieldCountryPalette[hash % _yieldCountryPalette.length];
}

List<String> _yieldCountriesFor(_YieldCurveSnapshot snapshot) {
  final countries = <String>[];
  void addCountry(String country) {
    final trimmed = country.trim();
    if (trimmed.isEmpty) return;
    final normalized = _normalizeYieldText(trimmed);
    final alreadyAdded = countries.any(
      (item) => _normalizeYieldText(item) == normalized,
    );
    if (!alreadyAdded) countries.add(trimmed);
  }

  for (final country in _yieldKnownCountriesForZone(snapshot.id)) {
    addCountry(country);
  }
  for (final curve in snapshot.countryCurves) {
    addCountry(curve.country);
  }
  return countries;
}

String _yieldCountrySeriesId(String country) {
  return 'country:${_normalizeYieldText(country)}';
}

bool _isYieldSeriesSelectable(_YieldCurveSnapshot snapshot, String id) {
  if (id == _yieldZoneSeriesId) return snapshot.points.length >= 2;
  return _yieldCountriesFor(snapshot).any(
    (country) => _yieldCountrySeriesId(country) == id,
  );
}

Set<String> _sanitizeYieldSelection(
  _YieldCurveSnapshot snapshot,
  Set<String> selectedIds,
) {
  final validIds = <String>{};
  if (snapshot.points.length >= 2) validIds.add(_yieldZoneSeriesId);
  for (final country in _yieldCountriesFor(snapshot)) {
    validIds.add(_yieldCountrySeriesId(country));
  }
  if (validIds.isEmpty) return const <String>{};

  final sanitized = {
    for (final id in selectedIds)
      if (validIds.contains(id)) id,
  };
  if (sanitized.isEmpty) {
    return validIds.contains(_yieldZoneSeriesId)
        ? const {_yieldZoneSeriesId}
        : {validIds.first};
  }
  return sanitized;
}

String? _canonicalUemoaCountry(String value) {
  final normalized = _normalizeYieldText(value);
  const aliases = {
    'burkina': 'Burkina Faso',
    'cote d\'ivoire': 'Côte d\'Ivoire',
    'cote d ivoire': 'Côte d\'Ivoire',
    'guinee bissau': 'Guinée-Bissau',
  };
  for (final entry in aliases.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  for (final country in _uemoaYieldCountries) {
    if (normalized.contains(_normalizeYieldText(country))) {
      return country;
    }
  }
  return null;
}

_YieldCurveDisplaySeries? _primaryYieldSeries(
  List<_YieldCurveDisplaySeries> series,
) {
  for (final item in series) {
    if (item.points.length >= 2) return item;
  }
  return null;
}

_YieldCurveDisplaySeries? _seriesById(
  List<_YieldCurveDisplaySeries> series,
  String id,
) {
  for (final item in series) {
    if (item.id == id) return item;
  }
  return null;
}

_YieldCurveDisplaySeries? _fillYieldSeries(
  List<_YieldCurveDisplaySeries> series,
) {
  if (series.length == 1) return series.first;
  for (final item in series) {
    if (item.isZone) return item;
  }
  return null;
}

Path _yieldSeriesPath(
  List<_YieldCurvePoint> points,
  double Function(_YieldCurvePoint point) xFor,
  double Function(_YieldCurvePoint point) yFor,
) {
  final path = Path()..moveTo(xFor(points.first), yFor(points.first));
  for (final point in points.skip(1)) {
    path.lineTo(xFor(point), yFor(point));
  }
  return path;
}

List<_YieldCurvePointStripItem> _yieldPointStripItems(
  List<_YieldCurveDisplaySeries> series,
) {
  return [
    for (final item in series)
      if (item.points.length >= 2)
        for (var index = 0; index < item.points.length; index++)
          _YieldCurvePointStripItem(
            series: item,
            point: item.points[index],
            pointIndex: index,
          ),
  ];
}

DateTime? _parseYieldSourceDate(String value) {
  final match = RegExp(r'(\d{2})[./-](\d{2})[./-](\d{4})').firstMatch(value);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(3)!),
    int.parse(match.group(2)!),
    int.parse(match.group(1)!),
  );
}

String _formatYieldSourceDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}

String _formatYieldMaturityLabel(double years) {
  if (years < 1) {
    final months = (years * 12).round();
    return '$months mois';
  }
  final isInteger = (years - years.round()).abs() < 0.001;
  final number = isInteger
      ? years.round().toString()
      : years.toStringAsFixed(1).replaceAll('.', ',');
  return '$number an${years >= 2 ? 's' : ''}';
}

double? _parseYieldMaturityYears(String value) {
  final normalized = _normalizeYieldText(value).replaceAll(',', '.');
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!);
  if (amount == null) return null;
  return normalized.contains('mois') ? amount / 12 : amount;
}

String _normalizeYieldText(String value) {
  return value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ç', 'c')
      .replaceAll('ô', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ï', 'i')
      .replaceAll('î', 'i')
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _yieldCellText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  return switch (value) {
    TextCellValue() => value.value.text ?? '',
    IntCellValue() => value.value.toString(),
    DoubleCellValue() => value.value.toString(),
    BoolCellValue() => value.value.toString(),
    DateCellValue() => value.asDateTimeLocal().toIso8601String(),
    DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
    TimeCellValue() => value.toString(),
    _ => value.toString(),
  };
}

double? _yieldCellNumber(Data? cell) {
  final value = cell?.value;
  if (value == null) return null;
  return switch (value) {
    IntCellValue() => value.value.toDouble(),
    DoubleCellValue() => value.value,
    TextCellValue() => _parseYieldNumber(value.value.text ?? ''),
    _ => _parseYieldNumber(value.toString()),
  };
}

double? _parseYieldNumber(String value) {
  final cleaned = value
      .replaceAll('%', '')
      .replaceAll('\u00A0', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(cleaned);
}

class _MarketIndicatorsWorkspace extends StatelessWidget {
  const _MarketIndicatorsWorkspace();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<
        Map<MarketPortfolioType, MarketPortfolioDataset>>(
      valueListenable: MarketDataImportStore.instance.datasetsNotifier,
      builder: (context, datasets, _) {
        final dataset = datasets[MarketPortfolioType.bonds];
        return Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: dataset == null || dataset.rowCount == 0
              ? const SizedBox(height: 1)
              : FutureBuilder<_BondDashboardStats>(
                  future: _bondDashboardStatsForAsync(dataset),
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    if (stats == null) {
                      return const _MarketDeferredLoadingState(
                        title: 'Chargement des indicateurs',
                        subtitle:
                            'Nous préparons les chiffres du portefeuille.',
                      );
                    }
                    return _BondKeyIndicatorsSection(stats: stats);
                  },
                ),
        );
      },
    );
  }
}

final Expando<Map<String, _BondDashboardStats>> _bondDashboardStatsCache =
    Expando<Map<String, _BondDashboardStats>>('bond-dashboard-stats');
final Expando<Map<String, Future<_BondDashboardStats>>>
    _bondDashboardStatsFutureCache =
    Expando<Map<String, Future<_BondDashboardStats>>>(
  'bond-dashboard-stats-future',
);

Future<_BondDashboardStats> _bondDashboardStatsForAsync(
  MarketPortfolioDataset dataset,
) async {
  final yieldCurves = await _loadBondPricingYieldCurves();
  final signature = _bondYieldCurvePricingSignature(yieldCurves);
  final cacheBySignature =
      _bondDashboardStatsCache[dataset] ?? <String, _BondDashboardStats>{};
  _bondDashboardStatsCache[dataset] = cacheBySignature;
  final cached = cacheBySignature[signature];
  if (cached != null) return SynchronousFuture(cached);
  final futureBySignature = _bondDashboardStatsFutureCache[dataset] ??
      <String, Future<_BondDashboardStats>>{};
  _bondDashboardStatsFutureCache[dataset] = futureBySignature;
  final cachedFuture = futureBySignature[signature];
  if (cachedFuture != null) return cachedFuture;

  final future =
      _computeBondDashboardStatsAsync(dataset, yieldCurves).then((stats) {
    cacheBySignature[signature] = stats;
    futureBySignature.remove(signature);
    return stats;
  });
  futureBySignature[signature] = future;
  return future;
}

Future<_BondDashboardStats> _computeBondDashboardStatsAsync(
  MarketPortfolioDataset dataset,
  List<_YieldCurveSnapshot> yieldCurves,
) async {
  final request = _BondDashboardStatsRequest(
    dataset: dataset,
    yieldCurves: yieldCurves,
  );
  try {
    return await compute(
      _computeBondDashboardStats,
      request,
      debugLabel: 'bond-dashboard-stats',
    );
  } catch (error) {
    debugPrint('Calcul asynchrone stats obligations indisponible: $error');
    return _BondDashboardStats.from(dataset, yieldCurves: yieldCurves);
  }
}

_BondDashboardStats _computeBondDashboardStats(
  _BondDashboardStatsRequest request,
) {
  return _BondDashboardStats.from(
    request.dataset,
    yieldCurves: request.yieldCurves,
  );
}

class _BondDashboardStatsRequest {
  const _BondDashboardStatsRequest({
    required this.dataset,
    required this.yieldCurves,
  });

  final MarketPortfolioDataset dataset;
  final List<_YieldCurveSnapshot> yieldCurves;
}

Future<List<_YieldCurveSnapshot>> _loadBondPricingYieldCurves() async {
  final preferences = await SharedPreferences.getInstance();
  final raw = preferences.getString(_YieldCurveRepository._cacheKey);
  if (raw == null || raw.trim().isEmpty) {
    return _YieldCurveRepository.seedSnapshots;
  }

  try {
    final decoded = jsonDecode(raw) as List<dynamic>;
    final snapshots = decoded
        .whereType<Map<String, dynamic>>()
        .map(_YieldCurveSnapshot.fromJson)
        .map(_hydrateYieldSnapshotFromSeed)
        .where((snapshot) => snapshot.points.length >= 2)
        .toList(growable: false);
    return snapshots.length >= 2
        ? snapshots
        : _YieldCurveRepository.seedSnapshots;
  } catch (error) {
    debugPrint('Courbes de taux locales indisponibles pour le pricing: $error');
    return _YieldCurveRepository.seedSnapshots;
  }
}

String _bondYieldCurvePricingSignature(List<_YieldCurveSnapshot> snapshots) {
  return snapshots.map((snapshot) {
    final pointStamp = snapshot.points
        .map(
          (point) =>
              '${point.years.toStringAsFixed(4)}:${point.rate.toStringAsFixed(4)}',
        )
        .join(',');
    final countryStamp = snapshot.countryCurves.map((curve) {
      final points = curve.points
          .map(
            (point) =>
                '${point.years.toStringAsFixed(4)}:${point.rate.toStringAsFixed(4)}',
          )
          .join(',');
      return '${curve.country}:$points';
    }).join(';');
    return [
      snapshot.id,
      snapshot.sourceDateLabel,
      pointStamp,
      countryStamp,
    ].join('|');
  }).join('||');
}

class _MarketDeferredLoadingState extends StatelessWidget {
  const _MarketDeferredLoadingState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return _MarketCard(
      child: SizedBox(
        height: 220,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BondKeyIndicatorsSection extends StatelessWidget {
  const _BondKeyIndicatorsSection({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final items = _BondKeyIndicatorSpec.fromStats(stats);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _marketSurfaceFor(context).withValues(
          alpha: _isMarketDark(context) ? 0.86 : 0.98,
        ),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _marketBorderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BondKeyIndicatorsHeader(text: text, muted: muted),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: _marketBorderFor(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _BondIndicatorContentBoard(stats: stats, items: items),
            ),
          ),
        ],
      ),
    );
  }
}

class _BondKeyIndicatorsHeader extends StatelessWidget {
  const _BondKeyIndicatorsHeader({
    required this.text,
    required this.muted,
  });

  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _marketPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: _marketPrimary.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              CupertinoIcons.chart_bar_alt_fill,
              size: 13,
              color: _marketPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Indicateurs clés',
                  style: TextStyle(
                    color: text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Portefeuille obligataire',
                  style: TextStyle(
                    color: muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    height: 1,
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

class _BondKeyIndicatorSpec {
  const _BondKeyIndicatorSpec({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.formula,
    required this.detail,
    required this.caption,
    required this.category,
    required this.method,
    required this.reading,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String formula;
  final String detail;
  final String caption;
  final String category;
  final String method;
  final String reading;

  static List<_BondKeyIndicatorSpec> fromStats(_BondDashboardStats stats) {
    return [
      _BondKeyIndicatorSpec(
        label: 'Capital restant dû',
        value: _bondIndicatorMoneyValue(stats.capitalRemainingDue),
        unit: 'FCFA',
        icon: CupertinoIcons.creditcard_fill,
        color: _marketPrimary,
        formula: r'CRD=\sum_i Principal_{i,restant}',
        detail:
            "Encours restant reconstruit à partir du capital initial, de la date d'analyse du jour et du profil d'amortissement.",
        caption: 'Principal restant',
        category: 'Valorisation',
        method: 'Capital restant selon amortissement',
        reading: 'Dette encore portée au portefeuille',
      ),
      _BondKeyIndicatorSpec(
        label: 'Valeur actualisée',
        value: _bondIndicatorMoneyValue(stats.presentValue),
        unit: 'FCFA',
        icon: CupertinoIcons.money_dollar_circle_fill,
        color: _marketSuccess,
        formula: r'PV=\sum_i PV_i',
        detail:
            'Somme des flux futurs actualisés avec la courbe des taux locale de la zone et, si disponible, du pays émetteur.',
        caption: 'PV courbe de taux',
        category: 'Valorisation',
        method: 'Actualisation des cash-flows',
        reading: 'Valeur économique des positions',
      ),
      _BondKeyIndicatorSpec(
        label: 'Rendement Actuariel (YTM)',
        value: _bondIndicatorPercent(stats.yieldToMaturity),
        unit: '',
        icon: CupertinoIcons.arrow_up_right_circle_fill,
        color: _marketWarning,
        formula: r'\bar{y}=\frac{\sum_i y_i\times w_i}{\sum_i w_i}',
        detail:
            'YTM équivalent recalculé par titre à partir de la PV courbe de taux, puis pondéré par valeur actualisée.',
        caption: 'Moteur de performance',
        category: 'Rendement',
        method: 'Taux plat équivalent pondéré',
        reading: 'Performance long terme',
      ),
      _BondKeyIndicatorSpec(
        label: 'Coupon moyen pondéré',
        value: _bondIndicatorPercent(stats.weightedCoupon),
        unit: 'coupon',
        icon: CupertinoIcons.percent,
        color: _marketCyan,
        formula: r'\bar{c}=\frac{\sum_i c_i\times w_i}{\sum_i w_i}',
        detail: 'Coupon facial importé, pondéré par capital restant dû.',
        caption: 'Coupon pondéré',
        category: 'Rendement',
        method: 'Moyenne pondérée par CRD',
        reading: 'Portage contractuel du portefeuille',
      ),
      _BondKeyIndicatorSpec(
        label: 'Spread coupon / YTM',
        value: _bondIndicatorBps(stats.couponYtmSpread),
        unit: 'bps',
        icon: CupertinoIcons.waveform_path_ecg,
        color: _marketViolet,
        formula: r'Spread=(\bar{c}-YTM)\times10000',
        detail:
            'Écart entre coupon moyen et rendement actuariel, exprimé en points de base.',
        caption: 'Écart coupon vs YTM',
        category: 'Rendement',
        method: 'Coupon moyen moins YTM',
        reading: 'Prime ou décote de portage',
      ),
      _BondKeyIndicatorSpec(
        label: 'Maturité résiduelle moy.',
        value: _bondIndicatorMonths(stats.weightedMaturityYears * 12),
        unit: 'mois',
        icon: CupertinoIcons.calendar,
        color: _marketPrimary,
        formula: r'M_{res}=\frac{\sum_i M_i\times Encours_i}{\sum_i Encours_i}',
        detail:
            "Maturité résiduelle calculée entre la date d'échéance et la date d'analyse du jour, puis pondérée.",
        caption: 'Échéance restante',
        category: 'Maturité',
        method: 'Maturité résiduelle calculée',
        reading: 'Horizon physique moyen',
      ),
      _BondKeyIndicatorSpec(
        label: 'Titres actifs',
        value: stats.activeBondCount.toString(),
        unit: '/ ${stats.dataset.rowCount}',
        icon: CupertinoIcons.check_mark_circled_solid,
        color: _marketSuccess,
        formula: r'N_{actifs}=\#\{i:E_i>D_{analyse}\}',
        detail:
            "Nombre de titres dont la date d'échéance est strictement postérieure à la date d'analyse du jour.",
        caption: 'Portefeuille vivant',
        category: 'Maturité',
        method: "Date d'échéance > date d'analyse",
        reading: '${stats.maturedBondCount} titre(s) arrivé(s) à terme',
      ),
      _BondKeyIndicatorSpec(
        label: 'Duration Macaulay',
        value: _bondIndicatorYears(stats.macaulayDuration),
        unit: 'ans',
        icon: CupertinoIcons.time_solid,
        color: _marketSuccess,
        formula: r'D_{Mac}=\frac{\sum_t t\times\frac{CF_t}{(1+y)^t}}{PV}',
        detail:
            'Centre de gravité des flux futurs actualisés avec le YTM équivalent recalculé.',
        caption: 'Timing économique des flux',
        category: 'Sensibilité',
        method: 'Poids temporel des flux actualisés',
        reading: 'Délai économique de récupération',
      ),
      _BondKeyIndicatorSpec(
        label: 'Duration modifiée',
        value: _bondIndicatorYears(stats.modifiedDuration),
        unit: 'ans',
        icon: CupertinoIcons.gauge,
        color: _marketViolet,
        formula: r'D_{mod}=\frac{D_{Mac}}{1+\frac{YTM}{m}}',
        detail:
            'Mesure l’exposition directe du portefeuille au risque de taux via les YTM équivalents par titre.',
        caption: 'Sensibilité prix/taux',
        category: 'Sensibilité',
        method: 'Macaulay corrigée du YTM',
        reading: 'Impact par point de base',
      ),
      _BondKeyIndicatorSpec(
        label: 'Convexité',
        value: _bondIndicatorDecimal(stats.convexity),
        unit: '',
        icon: CupertinoIcons.bolt_fill,
        color: _marketWarning,
        formula: r'C=\frac{\sum_t t(t+1)\frac{CF_t}{(1+y)^{t+2}}}{PV}',
        detail:
            'Correction de second ordre de la relation prix/taux lorsque les variations deviennent importantes.',
        caption: 'Courbure prix/taux',
        category: 'Sensibilité',
        method: 'Second ordre des flux actualisés',
        reading: 'Effet non linéaire taux/prix',
      ),
    ];
  }
}

class _BondIndicatorContentBoard extends StatelessWidget {
  const _BondIndicatorContentBoard({
    required this.stats,
    required this.items,
  });

  final _BondDashboardStats stats;
  final List<_BondKeyIndicatorSpec> items;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BondIndicatorRowsBundle>(
      future: _bondIndicatorRowsForAsync(stats),
      builder: (context, snapshot) {
        final rows = snapshot.data;
        if (rows == null) {
          return Column(
            children: [
              _BondIndicatorOverviewSwitcher(
                items: items,
                zoneRows: const [],
              ),
              const SizedBox(height: 10),
              const Expanded(
                child: _MarketDeferredLoadingState(
                  title: 'Chargement du tableau',
                  subtitle: 'Nous préparons les titres à afficher.',
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _BondIndicatorOverviewSwitcher(
              items: items,
              zoneRows: rows.zoneRows,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _BondTitleIndicatorsTable(rows: rows.titleRows),
            ),
          ],
        );
      },
    );
  }
}

final Expando<_BondIndicatorRowsBundle> _bondIndicatorRowsCache =
    Expando<_BondIndicatorRowsBundle>('bond-indicator-rows');
final Expando<Future<_BondIndicatorRowsBundle>> _bondIndicatorRowsFutureCache =
    Expando<Future<_BondIndicatorRowsBundle>>('bond-indicator-rows-future');

Future<_BondIndicatorRowsBundle> _bondIndicatorRowsForAsync(
  _BondDashboardStats stats,
) {
  final cached = _bondIndicatorRowsCache[stats];
  if (cached != null) return SynchronousFuture(cached);
  final cachedFuture = _bondIndicatorRowsFutureCache[stats];
  if (cachedFuture != null) return cachedFuture;

  final future = _computeBondIndicatorRowsAsync(stats).then((rows) {
    _bondIndicatorRowsCache[stats] = rows;
    return rows;
  });
  _bondIndicatorRowsFutureCache[stats] = future;
  return future;
}

Future<_BondIndicatorRowsBundle> _computeBondIndicatorRowsAsync(
  _BondDashboardStats stats,
) async {
  try {
    return await compute(
      _computeBondIndicatorRows,
      stats,
      debugLabel: 'bond-indicator-rows',
    );
  } catch (error) {
    debugPrint('Calcul asynchrone lignes obligations indisponible: $error');
    return _computeBondIndicatorRows(stats);
  }
}

_BondIndicatorRowsBundle _computeBondIndicatorRows(_BondDashboardStats stats) {
  return _BondIndicatorRowsBundle(
    zoneRows: _buildBondIndicatorZoneRows(stats),
    titleRows: _buildBondIndicatorTitleRows(stats),
  );
}

List<_BondZoneMonetaryRow> _buildBondIndicatorZoneRows(
  _BondDashboardStats stats,
) {
  final totals = <String, double>{};
  final ytmNumerators = <String, double>{};
  final ytmDenominators = <String, double>{};
  final durationNumerators = <String, double>{};
  final durationDenominators = <String, double>{};
  for (final record in stats.dataset.records) {
    final capital = _bondOutstandingCapitalValue(record);
    if (capital <= 0) continue;
    final coupon = _bondCouponFraction(record.coupon);
    final maturityYears = _bondMaturityYears(record);
    final metrics = _bondRecordFixedIncomeMetrics(
      record: record,
      capital: capital,
      coupon: coupon,
      maturity: maturityYears,
      yieldCurves: stats.yieldCurves,
    );
    final valuationWeight =
        metrics.presentValue > 0 ? metrics.presentValue : capital;
    final zone = _bondZoneLabel(record);
    totals[zone] = (totals[zone] ?? 0) + capital;
    if (metrics.yieldToMaturity.isFinite && valuationWeight > 0) {
      ytmNumerators[zone] = (ytmNumerators[zone] ?? 0) +
          metrics.yieldToMaturity * valuationWeight;
      ytmDenominators[zone] = (ytmDenominators[zone] ?? 0) + valuationWeight;
    }
    if (metrics.modified > 0 && valuationWeight > 0) {
      durationNumerators[zone] =
          (durationNumerators[zone] ?? 0) + metrics.modified * valuationWeight;
      durationDenominators[zone] =
          (durationDenominators[zone] ?? 0) + valuationWeight;
    }
  }

  final total = totals.values.fold<double>(0, (sum, value) => sum + value);
  if (total <= 0) {
    return [
      _BondZoneMonetaryRow(
        zone: 'Portefeuille',
        capital: stats.totalExposure,
        share: 1,
        ytm: stats.yieldToMaturity,
        duration: stats.modifiedDuration,
      ),
    ];
  }

  final rows = totals.entries.map((entry) {
    final amount = entry.value;
    return _BondZoneMonetaryRow(
      zone: entry.key,
      capital: amount,
      share: amount / total,
      ytm: (ytmDenominators[entry.key] ?? 0) <= 0
          ? 0
          : (ytmNumerators[entry.key] ?? 0) / ytmDenominators[entry.key]!,
      duration: (durationDenominators[entry.key] ?? 0) <= 0
          ? 0
          : (durationNumerators[entry.key] ?? 0) /
              durationDenominators[entry.key]!,
    );
  }).toList()
    ..sort((a, b) => b.capital.compareTo(a.capital));
  return rows.take(6).toList(growable: false);
}

List<_BondTitleIndicatorRow> _buildBondIndicatorTitleRows(
  _BondDashboardStats stats,
) {
  final shareTotal = stats.dataset.records.fold<double>(0, (sum, record) {
    final capital = _bondOutstandingCapitalValue(record);
    if (capital <= 0) return sum;
    final metrics = _bondRecordFixedIncomeMetrics(
      record: record,
      capital: capital,
      coupon: _bondCouponFraction(record.coupon),
      maturity: _bondMaturityYears(record),
      yieldCurves: stats.yieldCurves,
    );
    final base = metrics.presentValue > 0 ? metrics.presentValue : capital;
    return sum + math.max(0.0, base).toDouble();
  });
  final rows = <_BondTitleIndicatorRow>[];

  for (final record in stats.dataset.records) {
    final capital = _bondOutstandingCapitalValue(record);
    if (capital <= 0) continue;
    final coupon = _bondCouponFraction(record.coupon);
    final maturityYears = _bondMaturityYears(record);
    final residualMaturityMonths = _bondMaturityMonths(record);
    final maturityMonths = _bondTotalMaturityMonths(record);
    final metrics = _bondRecordFixedIncomeMetrics(
      record: record,
      capital: capital,
      coupon: coupon,
      maturity: maturityYears,
      yieldCurves: stats.yieldCurves,
    );
    final issuer = record.issuer.trim();
    final instrument = record.instrumentType.trim();
    final code = record.instrumentCode.trim();
    final titleId = record.titleId;
    final country = record.values['Pays émetteur']?.toString().trim() ?? '';
    final title = issuer.isNotEmpty && issuer != 'Non renseigné'
        ? issuer
        : code.isNotEmpty
            ? code
            : instrument.isNotEmpty
                ? instrument
                : 'Titre obligataire';

    rows.add(
      _BondTitleIndicatorRow(
        titleId: titleId.isEmpty ? '-' : titleId,
        title: title,
        country: country.isEmpty ? 'Non renseigné' : country,
        zone: _bondZoneLabel(record),
        rating: _bondRatingLabel(record),
        issueDate: record.issueDate,
        maturityDate: record.maturityDate,
        capital: capital,
        presentValue: metrics.presentValue,
        share: shareTotal <= 0
            ? 0
            : (metrics.presentValue > 0 ? metrics.presentValue : capital) /
                shareTotal,
        ytm: metrics.yieldToMaturity,
        coupon: coupon,
        spread: record.spread,
        maturityMonths: maturityMonths,
        residualMaturityMonths: residualMaturityMonths,
        macaulay: metrics.macaulay,
        modified: metrics.modified,
        convexity: metrics.convexity,
      ),
    );
  }

  rows.sort((left, right) => right.capital.compareTo(left.capital));
  return rows;
}

class _BondIndicatorRowsBundle {
  const _BondIndicatorRowsBundle({
    required this.zoneRows,
    required this.titleRows,
  });

  final List<_BondZoneMonetaryRow> zoneRows;
  final List<_BondTitleIndicatorRow> titleRows;
}

enum _BondIndicatorOverviewMode { kpis, zones }

const double _bondIndicatorOverviewHeight = 154;

class _BondIndicatorOverviewSwitcher extends StatefulWidget {
  const _BondIndicatorOverviewSwitcher({
    required this.items,
    required this.zoneRows,
  });

  final List<_BondKeyIndicatorSpec> items;
  final List<_BondZoneMonetaryRow> zoneRows;

  @override
  State<_BondIndicatorOverviewSwitcher> createState() =>
      _BondIndicatorOverviewSwitcherState();
}

class _BondIndicatorOverviewSwitcherState
    extends State<_BondIndicatorOverviewSwitcher> {
  _BondIndicatorOverviewMode _mode = _BondIndicatorOverviewMode.kpis;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _bondIndicatorOverviewHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: _mode == _BondIndicatorOverviewMode.kpis
                  ? _BondIndicatorKpiPanel(
                      key: const ValueKey('bond-overview-kpis'),
                      items: widget.items,
                    )
                  : _BondZoneMonetaryTable(
                      key: const ValueKey('bond-overview-zones'),
                      rows: widget.zoneRows,
                    ),
            ),
          ),
          Positioned(
            top: 2,
            right: 8,
            child: _BondIndicatorOverviewToggle(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
          ),
        ],
      ),
    );
  }
}

class _BondIndicatorOverviewToggle extends StatelessWidget {
  const _BondIndicatorOverviewToggle({
    required this.mode,
    required this.onChanged,
  });

  final _BondIndicatorOverviewMode mode;
  final ValueChanged<_BondIndicatorOverviewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final isDark = _isMarketDark(context);

    return Container(
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _marketSurfaceFor(context),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BondIndicatorOverviewToggleButton(
            icon: CupertinoIcons.chart_bar_alt_fill,
            selected: mode == _BondIndicatorOverviewMode.kpis,
            isDark: isDark,
            onTap: () => onChanged(_BondIndicatorOverviewMode.kpis),
          ),
          _BondIndicatorOverviewToggleButton(
            icon: CupertinoIcons.globe,
            selected: mode == _BondIndicatorOverviewMode.zones,
            isDark: isDark,
            onTap: () => onChanged(_BondIndicatorOverviewMode.zones),
          ),
        ],
      ),
    );
  }
}

class _BondIndicatorOverviewToggleButton extends StatelessWidget {
  const _BondIndicatorOverviewToggleButton({
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 28,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _marketPrimary.withValues(alpha: isDark ? 0.30 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(
            icon,
            size: 12,
            color: selected ? _marketPrimary : muted,
          ),
        ),
      ),
    );
  }
}

class _BondIndicatorKpiPanel extends StatelessWidget {
  const _BondIndicatorKpiPanel({
    super.key,
    required this.items,
  });

  final List<_BondKeyIndicatorSpec> items;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final isDark = _isMarketDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: _marketSurfaceFor(context).withValues(
          alpha: isDark ? 0.86 : 0.98,
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.075),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _marketPrimary.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Icon(
                  CupertinoIcons.briefcase_fill,
                  size: 14,
                  color: _marketPrimary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synthèse du portefeuille obligataire'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text.withValues(alpha: 0.72),
                        fontSize: 12.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Valorisation, rendement, maturité et sensibilité',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted.withValues(alpha: 0.95),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 78),
            ],
          ),
          const SizedBox(height: 8),
          _BondIndicatorCardGrid(items: items),
        ],
      ),
    );
  }
}

class _BondZoneMonetaryRow {
  const _BondZoneMonetaryRow({
    required this.zone,
    required this.capital,
    required this.share,
    required this.ytm,
    required this.duration,
  });

  final String zone;
  final double capital;
  final double share;
  final double ytm;
  final double duration;
}

class _BondZoneMonetaryTable extends StatelessWidget {
  const _BondZoneMonetaryTable({
    super.key,
    required this.rows,
  });

  final List<_BondZoneMonetaryRow> rows;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final isDark = _isMarketDark(context);
    final border = _marketBorderFor(context);
    final totalCapital = rows.fold<double>(0, (sum, row) => sum + row.capital);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: _marketSurfaceFor(context).withValues(
          alpha: isDark ? 0.86 : 0.98,
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.075),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _marketPrimary.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Icon(
                  CupertinoIcons.globe,
                  size: 14,
                  color: _marketPrimary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allocation par zone monétaire'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text.withValues(alpha: 0.72),
                        fontSize: 12.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Poids du capital, rendement et sensibilité par zone',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted.withValues(alpha: 0.95),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 78),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns =
                  constraints.maxWidth < 760 ? 1 : math.min(2, rows.length);
              final safeColumns = math.max(1, columns);
              final available = constraints.maxWidth - gap * (safeColumns - 1);
              final cardWidth = available / safeColumns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final row in rows)
                    SizedBox(
                      width: cardWidth,
                      child: _BondZoneAllocationCard(
                        row: row,
                        totalCapital: totalCapital,
                        text: text,
                        muted: muted,
                        border: border,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BondZoneAllocationCard extends StatelessWidget {
  const _BondZoneAllocationCard({
    required this.row,
    required this.totalCapital,
    required this.text,
    required this.muted,
    required this.border,
  });

  final _BondZoneMonetaryRow row;
  final double totalCapital;
  final Color text;
  final Color muted;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final accent = _bondZoneAccent(row.zone);
    final isDark = _isMarketDark(context);
    final capitalRatio = row.share.clamp(0.0, 1.0).toDouble();

    return Container(
      height: 78,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: isDark
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.055),
                _marketSurfaceFor(context),
              )
            : accent.withValues(alpha: 0.040),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  row.zone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              _BondZoneShareChip(row: row, color: accent),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _BondZoneMetricText(
                  label: 'Capital',
                  value: '${_bondIndicatorMdValue(row.capital)} Md',
                  text: text,
                  muted: muted,
                ),
              ),
              _BondZoneMetricText(
                label: 'YTM',
                value: _bondIndicatorPercent(row.ytm),
                text: text,
                muted: muted,
                alignEnd: true,
              ),
              const SizedBox(width: 12),
              _BondZoneMetricText(
                label: 'Duration',
                value:
                    '${_marketDecimalNumberText(row.duration, decimals: 2, trimTrailingZeros: false)} ans',
                text: text,
                muted: muted,
                alignEnd: true,
              ),
            ],
          ),
          const Spacer(),
          Stack(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: capitalRatio,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BondZoneShareChip extends StatelessWidget {
  const _BondZoneShareChip({required this.row, required this.color});

  final _BondZoneMonetaryRow row;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isMarketDark(context) ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        _bondIndicatorPercent(row.share),
        style: TextStyle(
          color: _marketTextFor(context),
          fontSize: 9.8,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _BondZoneMetricText extends StatelessWidget {
  const _BondZoneMetricText({
    required this.label,
    required this.value,
    required this.text,
    required this.muted,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color text;
  final Color muted;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: text,
            fontSize: 11.4,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: muted.withValues(alpha: 0.72),
            fontSize: 8.1,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

Color _bondZoneAccent(String zone) {
  final normalized = zone.toLowerCase();
  if (normalized.contains('uemoa')) return _marketPrimary;
  if (normalized.contains('cemac')) return _marketCyan;
  if (normalized.contains('hors')) return _marketViolet;
  return _marketWarning;
}

class _BondTitleIndicatorRow {
  const _BondTitleIndicatorRow({
    required this.titleId,
    required this.title,
    required this.country,
    required this.zone,
    required this.rating,
    required this.issueDate,
    required this.maturityDate,
    required this.capital,
    required this.presentValue,
    required this.share,
    required this.ytm,
    required this.coupon,
    required this.spread,
    required this.maturityMonths,
    required this.residualMaturityMonths,
    required this.macaulay,
    required this.modified,
    required this.convexity,
  });

  final String titleId;
  final String title;
  final String country;
  final String zone;
  final String rating;
  final DateTime? issueDate;
  final DateTime? maturityDate;
  final double capital;
  final double presentValue;
  final double share;
  final double ytm;
  final double coupon;
  final double spread;
  final double maturityMonths;
  final double residualMaturityMonths;
  final double macaulay;
  final double modified;
  final double convexity;

  String get selectionKey {
    final issueKey = issueDate?.millisecondsSinceEpoch ?? 0;
    final maturityKey = maturityDate?.millisecondsSinceEpoch ?? 0;
    return [
      titleId,
      title,
      country,
      zone,
      rating,
      issueKey,
      maturityKey,
      capital.toStringAsFixed(2),
      presentValue.toStringAsFixed(2),
    ].join('|');
  }
}

enum _BondTitleColumn {
  titleId,
  title,
  country,
  zone,
  rating,
  issueDate,
  maturityDate,
  capital,
  presentValue,
  share,
  ytm,
  coupon,
  spread,
  maturityMonths,
  residualMaturityMonths,
  macaulay,
  modified,
  convexity,
  sensitivity,
}

const _bondTitleEssentialColumns = <_BondTitleColumn>[
  _BondTitleColumn.titleId,
  _BondTitleColumn.title,
  _BondTitleColumn.country,
  _BondTitleColumn.issueDate,
  _BondTitleColumn.maturityDate,
  _BondTitleColumn.zone,
  _BondTitleColumn.rating,
  _BondTitleColumn.capital,
  _BondTitleColumn.share,
  _BondTitleColumn.ytm,
  _BondTitleColumn.coupon,
  _BondTitleColumn.residualMaturityMonths,
  _BondTitleColumn.modified,
];

extension _BondTitleColumnMeta on _BondTitleColumn {
  String get label => switch (this) {
        _BondTitleColumn.titleId => 'ID Titre',
        _BondTitleColumn.title => 'Titre / émetteur',
        _BondTitleColumn.country => 'Pays émetteur',
        _BondTitleColumn.zone => 'Zone',
        _BondTitleColumn.rating => 'Notation externe',
        _BondTitleColumn.issueDate => 'Date d\'émission',
        _BondTitleColumn.maturityDate => 'Date d\'échéance',
        _BondTitleColumn.capital => 'Capital restant dû (Md)',
        _BondTitleColumn.presentValue => 'Valeur actualisée (Md)',
        _BondTitleColumn.share => 'Part du portefeuille',
        _BondTitleColumn.ytm => 'Rendement actuariel (YTM)',
        _BondTitleColumn.coupon => 'Coupon',
        _BondTitleColumn.spread => 'Spread coupon / YTM',
        _BondTitleColumn.maturityMonths => 'Maturité totale (mois)',
        _BondTitleColumn.residualMaturityMonths => 'Maturité résiduelle (mois)',
        _BondTitleColumn.macaulay => 'Duration Macaulay (ans)',
        _BondTitleColumn.modified => 'Duration modifiée (ans)',
        _BondTitleColumn.convexity => 'Convexité',
        _BondTitleColumn.sensitivity => 'Sensibilité 1%',
      };

  double get width => switch (this) {
        _BondTitleColumn.titleId => 118,
        _BondTitleColumn.title => 230,
        _BondTitleColumn.country => 150,
        _BondTitleColumn.zone => 92,
        _BondTitleColumn.rating => 126,
        _BondTitleColumn.issueDate => 130,
        _BondTitleColumn.maturityDate => 130,
        _BondTitleColumn.capital => 170,
        _BondTitleColumn.presentValue => 170,
        _BondTitleColumn.share => 150,
        _BondTitleColumn.ytm => 180,
        _BondTitleColumn.coupon => 168,
        _BondTitleColumn.spread => 156,
        _BondTitleColumn.maturityMonths => 156,
        _BondTitleColumn.residualMaturityMonths => 180,
        _BondTitleColumn.macaulay => 170,
        _BondTitleColumn.modified => 170,
        _BondTitleColumn.convexity => 112,
        _BondTitleColumn.sensitivity => 148,
      };

  bool get isText => switch (this) {
        _BondTitleColumn.title ||
        _BondTitleColumn.titleId ||
        _BondTitleColumn.country ||
        _BondTitleColumn.zone ||
        _BondTitleColumn.rating =>
          true,
        _ => false,
      };

  bool get defaultAscending =>
      isText ||
      this == _BondTitleColumn.issueDate ||
      this == _BondTitleColumn.maturityDate;

  double numericValue(_BondTitleIndicatorRow row) {
    return switch (this) {
      _BondTitleColumn.issueDate =>
        row.issueDate?.millisecondsSinceEpoch.toDouble() ?? -1,
      _BondTitleColumn.maturityDate =>
        row.maturityDate?.millisecondsSinceEpoch.toDouble() ?? -1,
      _BondTitleColumn.capital => row.capital,
      _BondTitleColumn.presentValue => row.presentValue,
      _BondTitleColumn.share => row.share,
      _BondTitleColumn.ytm => row.ytm,
      _BondTitleColumn.coupon => row.coupon,
      _BondTitleColumn.spread => row.spread,
      _BondTitleColumn.maturityMonths => row.maturityMonths,
      _BondTitleColumn.residualMaturityMonths => row.residualMaturityMonths,
      _BondTitleColumn.macaulay => row.macaulay,
      _BondTitleColumn.modified => row.modified,
      _BondTitleColumn.convexity => row.convexity,
      _BondTitleColumn.sensitivity => row.modified * row.capital * 0.01,
      _ => 0,
    };
  }

  String textValue(_BondTitleIndicatorRow row) {
    return switch (this) {
      _BondTitleColumn.titleId => row.titleId,
      _BondTitleColumn.title => row.title,
      _BondTitleColumn.country => row.country,
      _BondTitleColumn.zone => row.zone,
      _BondTitleColumn.rating => row.rating,
      _BondTitleColumn.issueDate =>
        row.issueDate == null ? '-' : AppFormatters.shortDate(row.issueDate!),
      _BondTitleColumn.maturityDate => row.maturityDate == null
          ? '-'
          : AppFormatters.shortDate(row.maturityDate!),
      _BondTitleColumn.capital => _bondIndicatorMdValue(row.capital),
      _BondTitleColumn.presentValue => _bondIndicatorMdValue(row.presentValue),
      _BondTitleColumn.share => _bondIndicatorPercent(row.share),
      _BondTitleColumn.ytm => _bondIndicatorPercent(row.ytm),
      _BondTitleColumn.coupon => _bondIndicatorPercent(row.coupon),
      _BondTitleColumn.spread => _bondIndicatorDecimal(row.spread),
      _BondTitleColumn.maturityMonths =>
        _bondIndicatorMonths(row.maturityMonths),
      _BondTitleColumn.residualMaturityMonths =>
        _bondIndicatorMonths(row.residualMaturityMonths),
      _BondTitleColumn.macaulay => _bondIndicatorYears(row.macaulay),
      _BondTitleColumn.modified => _bondIndicatorYears(row.modified),
      _BondTitleColumn.convexity => _bondIndicatorDecimal(row.convexity),
      _BondTitleColumn.sensitivity => _bondIndicatorMoneyValue(
          row.modified * row.capital * 0.01,
        ),
    };
  }
}

int _compareBondTitleRows(
  _BondTitleIndicatorRow left,
  _BondTitleIndicatorRow right,
  _BondTitleColumn column,
) {
  if (column.isText) {
    return column
        .textValue(left)
        .toLowerCase()
        .compareTo(column.textValue(right).toLowerCase());
  }
  return column.numericValue(left).compareTo(column.numericValue(right));
}

bool _bondTitleColumnSetsEqual(
  Set<_BondTitleColumn> left,
  Set<_BondTitleColumn> right,
) {
  return left.length == right.length && left.containsAll(right);
}

void _forwardVerticalPointerScroll(
  PointerSignalEvent event,
  ScrollController target,
) {
  if (event is! PointerScrollEvent || !target.hasClients) return;
  final nextOffset = (target.offset + event.scrollDelta.dy)
      .clamp(
        target.position.minScrollExtent,
        target.position.maxScrollExtent,
      )
      .toDouble();
  if ((target.offset - nextOffset).abs() < 0.5) return;
  target.jumpTo(nextOffset);
}

Widget _withoutDesktopScrollbars(BuildContext context, Widget child) {
  return ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: child,
  );
}

class _BondTitleIndicatorsTable extends StatefulWidget {
  const _BondTitleIndicatorsTable({required this.rows});

  final List<_BondTitleIndicatorRow> rows;

  static const _rowHeight = 36.0;
  static const _headerHeight = 52.0;

  @override
  State<_BondTitleIndicatorsTable> createState() =>
      _BondTitleIndicatorsTableState();
}

class _BondTitleIndicatorsTableState extends State<_BondTitleIndicatorsTable> {
  Set<_BondTitleColumn> _visibleColumns = Set.of(_BondTitleColumn.values);
  _BondTitleColumn _sortColumn = _BondTitleColumn.capital;
  bool _sortAscending = false;
  final _pinnedRowsScrollController = ScrollController();
  final _dataRowsScrollController = ScrollController();
  final _issuerSearchController = TextEditingController();
  String _issuerQuery = '';
  String? _selectedRowKey;
  bool _syncingRowsScroll = false;

  List<_BondTitleColumn> get _orderedVisibleColumns {
    return _BondTitleColumn.values
        .where(_visibleColumns.contains)
        .toList(growable: false);
  }

  void _handleSort(_BondTitleColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
        return;
      }
      _sortColumn = column;
      _sortAscending = column.defaultAscending;
    });
  }

  void _handleVisibleColumnsChanged(Set<_BondTitleColumn> columns) {
    if (columns.isEmpty) return;
    if (_bondTitleColumnSetsEqual(_visibleColumns, columns)) return;
    setState(() {
      _visibleColumns = columns;
      if (!_visibleColumns.contains(_sortColumn)) {
        _sortColumn = _BondTitleColumn.values.firstWhere(
          _visibleColumns.contains,
        );
        _sortAscending = _sortColumn.defaultAscending;
      }
    });
  }

  List<_BondTitleIndicatorRow> _filteredSortedRows() {
    final query = _issuerQuery.trim().toLowerCase();
    final sorted = query.isEmpty
        ? widget.rows.toList()
        : widget.rows
            .where((row) => row.title.toLowerCase().contains(query))
            .toList();
    sorted.sort((left, right) {
      final comparison = _compareBondTitleRows(left, right, _sortColumn);
      final resolved = _sortAscending ? comparison : -comparison;
      if (resolved != 0) return resolved;
      return _compareBondTitleRows(left, right, _BondTitleColumn.title);
    });
    return sorted;
  }

  void _handleSearchChanged(String value) {
    setState(() => _issuerQuery = value);
  }

  void _clearSearch() {
    _issuerSearchController.clear();
    _handleSearchChanged('');
  }

  void _handleRowSelected(_BondTitleIndicatorRow row) {
    setState(() => _selectedRowKey = row.selectionKey);
  }

  void _syncRowsScroll(ScrollController source, ScrollController target) {
    if (_syncingRowsScroll || !source.hasClients || !target.hasClients) {
      return;
    }
    final nextOffset = source.offset
        .clamp(
          target.position.minScrollExtent,
          target.position.maxScrollExtent,
        )
        .toDouble();
    if ((target.offset - nextOffset).abs() < 0.5) return;
    _syncingRowsScroll = true;
    target.jumpTo(nextOffset);
    _syncingRowsScroll = false;
  }

  @override
  void initState() {
    super.initState();
    _pinnedRowsScrollController.addListener(
      () => _syncRowsScroll(
        _pinnedRowsScrollController,
        _dataRowsScrollController,
      ),
    );
    _dataRowsScrollController.addListener(
      () => _syncRowsScroll(
        _dataRowsScrollController,
        _pinnedRowsScrollController,
      ),
    );
  }

  @override
  void dispose() {
    _pinnedRowsScrollController.dispose();
    _dataRowsScrollController.dispose();
    _issuerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final border = _marketBorderFor(context);
    final isDark = _isMarketDark(context);
    final visibleColumns = _orderedVisibleColumns;
    final pinnedColumn = visibleColumns.contains(_BondTitleColumn.titleId)
        ? _BondTitleColumn.titleId
        : null;
    final scrollColumns = pinnedColumn == null
        ? visibleColumns
        : visibleColumns
            .where((column) => column != pinnedColumn)
            .toList(growable: false);
    final sortedRows = _filteredSortedRows();
    final scrollContentWidth = scrollColumns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );
    final tableHeight = (88 +
            math.min(sortedRows.length, 8) *
                _BondTitleIndicatorsTable._rowHeight)
        .clamp(204.0, 372.0)
        .toDouble();

    return Container(
      width: double.infinity,
      height: tableHeight,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
      decoration: BoxDecoration(
        color: _marketSurfaceFor(context).withValues(
          alpha: isDark ? 0.88 : 0.98,
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.070),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.table_fill,
                  size: 14,
                  color: _marketPrimary.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 7),
                Text(
                  'Indicateurs par titre'.toUpperCase(),
                  style: TextStyle(
                    color: muted,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.85,
                    height: 1,
                  ),
                ),
                const Spacer(),
                _BondIssuerSearchField(
                  controller: _issuerSearchController,
                  value: _issuerQuery,
                  onChanged: _handleSearchChanged,
                  onClear: _clearSearch,
                ),
                const SizedBox(width: 8),
                _BondTitleColumnVisibilityButton(
                  visibleColumns: _visibleColumns,
                  onChanged: _handleVisibleColumnsChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.025)
                      : const Color(0xFFF8FBFF),
                  border: Border.all(color: border.withValues(alpha: 0.78)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pinnedWidth = pinnedColumn?.width ?? 0;
                    final scrollWidth = math.max(
                      0.0,
                      constraints.maxWidth - pinnedWidth,
                    );
                    final tableWidth = math.max(
                      scrollWidth,
                      scrollContentWidth,
                    );

                    final rowsContent = sortedRows.isEmpty
                        ? Center(
                            child: Text(
                              _issuerQuery.trim().isEmpty
                                  ? 'Aucun titre exploitable'
                                  : 'Aucun émetteur trouvé',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _dataRowsScrollController,
                            primary: false,
                            itemExtent: _BondTitleIndicatorsTable._rowHeight,
                            itemCount: sortedRows.length,
                            itemBuilder: (context, index) {
                              return _BondTitleIndicatorsDataRow(
                                row: sortedRows[index],
                                columns: scrollColumns,
                                alternate: index.isOdd,
                                selected: sortedRows[index].selectionKey ==
                                    _selectedRowKey,
                                showSelectionStripe: pinnedColumn == null,
                                onSelected: () =>
                                    _handleRowSelected(sortedRows[index]),
                              );
                            },
                          );

                    return Row(
                      children: [
                        if (pinnedColumn != null)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: _marketSurfaceFor(context),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.24 : 0.08,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(4, 0),
                                ),
                              ],
                              border: Border(
                                right: BorderSide(
                                  color: border.withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                            child: SizedBox(
                              width: pinnedColumn.width,
                              child: Column(
                                children: [
                                  _BondTitleIndicatorsHeaderRow(
                                    columns: [pinnedColumn],
                                    sortColumn: _sortColumn,
                                    sortAscending: _sortAscending,
                                    onSort: _handleSort,
                                  ),
                                  Expanded(
                                    child: sortedRows.isEmpty
                                        ? const SizedBox.shrink()
                                        : Listener(
                                            onPointerSignal: (event) =>
                                                _forwardVerticalPointerScroll(
                                              event,
                                              _dataRowsScrollController,
                                            ),
                                            child: _withoutDesktopScrollbars(
                                              context,
                                              ListView.builder(
                                                controller:
                                                    _pinnedRowsScrollController,
                                                primary: false,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                itemExtent:
                                                    _BondTitleIndicatorsTable
                                                        ._rowHeight,
                                                itemCount: sortedRows.length,
                                                itemBuilder: (context, index) {
                                                  return _BondTitleIndicatorsDataRow(
                                                    row: sortedRows[index],
                                                    columns: [pinnedColumn],
                                                    alternate: index.isOdd,
                                                    selected: sortedRows[index]
                                                            .selectionKey ==
                                                        _selectedRowKey,
                                                    onSelected: () =>
                                                        _handleRowSelected(
                                                      sortedRows[index],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                children: [
                                  _BondTitleIndicatorsHeaderRow(
                                    columns: scrollColumns,
                                    sortColumn: _sortColumn,
                                    sortAscending: _sortAscending,
                                    onSort: _handleSort,
                                  ),
                                  Expanded(child: rowsContent),
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
        ],
      ),
    );
  }
}

class _BondTitleIndicatorsHeaderRow extends StatelessWidget {
  const _BondTitleIndicatorsHeaderRow({
    required this.columns,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_BondTitleColumn> columns;
  final _BondTitleColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<_BondTitleColumn> onSort;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    return Container(
      height: _BondTitleIndicatorsTable._headerHeight,
      color: isDark
          ? Color.alphaBlend(
              _marketPrimary.withValues(alpha: 0.32),
              const Color(0xFF0F1B31),
            )
          : _marketPrimary.withValues(alpha: 0.16),
      child: Row(
        children: [
          for (final column in columns)
            _BondTitleHeaderCell(
              column: column,
              sorted: sortColumn == column,
              sortAscending: sortAscending,
              onTap: () => onSort(column),
            ),
        ],
      ),
    );
  }
}

class _BondTitleHeaderCell extends StatelessWidget {
  const _BondTitleHeaderCell({
    required this.column,
    required this.sorted,
    required this.sortAscending,
    required this.onTap,
  });

  final _BondTitleColumn column;
  final bool sorted;
  final bool sortAscending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final alignLeft = column.isText || column.width <= 96;
    final icon = sorted
        ? (sortAscending
            ? CupertinoIcons.chevron_up
            : CupertinoIcons.chevron_down)
        : CupertinoIcons.arrow_up_arrow_down;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: column.width,
          height: double.infinity,
          alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: border.withValues(alpha: 0.44)),
              bottom: BorderSide(color: border.withValues(alpha: 0.60)),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  column.label.toUpperCase(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: alignLeft ? TextAlign.left : TextAlign.right,
                  style: TextStyle(
                    color: sorted ? _marketPrimary : _marketDashboardDeepBlue,
                    fontSize: 9.0,
                    fontWeight: FontWeight.w800,
                    height: 1.03,
                    letterSpacing: 0.25,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: sorted ? 10 : 9,
                color: sorted
                    ? _marketPrimary
                    : _marketDashboardDeepBlue.withValues(alpha: 0.48),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BondTitleIndicatorsDataRow extends StatelessWidget {
  const _BondTitleIndicatorsDataRow({
    required this.row,
    required this.columns,
    required this.alternate,
    required this.selected,
    required this.onSelected,
    this.showSelectionStripe = true,
  });

  final _BondTitleIndicatorRow row;
  final List<_BondTitleColumn> columns;
  final bool alternate;
  final bool selected;
  final VoidCallback onSelected;
  final bool showSelectionStripe;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final background = alternate
        ? (isDark
            ? const Color(0xFF14233D).withValues(alpha: 0.42)
            : const Color(0xFFF5F9FF))
        : _marketSurfaceFor(context);
    final selectedBackground = Color.alphaBlend(
      _marketPrimary.withValues(alpha: isDark ? 0.24 : 0.12),
      background,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelected,
        child: SizedBox(
          height: _BondTitleIndicatorsTable._rowHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: selected ? selectedBackground : background,
                  child: Row(
                    children: [
                      for (final column in columns)
                        _BondTitleTableCell(
                          column.textValue(row),
                          width: column.width,
                          alignLeft: column.isText,
                          selected: selected,
                        ),
                    ],
                  ),
                ),
              ),
              if (selected && showSelectionStripe)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: _marketPrimary),
                    child: SizedBox(width: 3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BondIssuerSearchField extends StatelessWidget {
  const _BondIssuerSearchField({
    required this.controller,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return SizedBox(
      width: 240,
      height: 28,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: _marketPrimary,
        style: TextStyle(
          color: text,
          fontSize: 11.4,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher émetteur'.tr(context),
          hintStyle: TextStyle(
            color: muted.withValues(alpha: 0.72),
            fontSize: 11.2,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            CupertinoIcons.search,
            size: 14,
            color: muted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 28,
          ),
          suffixIcon: value.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 14,
                    color: muted.withValues(alpha: 0.78),
                  ),
                ),
          isDense: true,
          filled: true,
          fillColor: _marketSurfaceFor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: const BorderSide(color: _marketPrimary),
          ),
        ),
      ),
    );
  }
}

class _BondTitleColumnVisibilityButton extends StatefulWidget {
  const _BondTitleColumnVisibilityButton({
    required this.visibleColumns,
    required this.onChanged,
  });

  final Set<_BondTitleColumn> visibleColumns;
  final ValueChanged<Set<_BondTitleColumn>> onChanged;

  @override
  State<_BondTitleColumnVisibilityButton> createState() =>
      _BondTitleColumnVisibilityButtonState();
}

class _BondTitleColumnVisibilityButtonState
    extends State<_BondTitleColumnVisibilityButton> {
  final _menuController = MenuController();
  Set<_BondTitleColumn> _draftColumns = Set.of(_BondTitleColumn.values);

  void _open(MenuController controller) {
    setState(() => _draftColumns = widget.visibleColumns.toSet());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !controller.isOpen) {
        controller.open();
      }
    });
  }

  void _setDraft(Set<_BondTitleColumn> columns) {
    if (columns.isEmpty) return;
    setState(() => _draftColumns = columns);
    widget.onChanged(columns);
  }

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final text = _marketTextFor(context);
    final count = _menuController.isOpen
        ? _draftColumns.length
        : widget.visibleColumns.length;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-186, 8),
      menuChildren: [
        _BondTitleColumnVisibilityPanel(
          draftColumns: _draftColumns,
          onDraftChanged: _setDraft,
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : _open(controller),
          borderRadius: BorderRadius.circular(2),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            width: 142,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _marketSurfaceFor(context),
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.eye_fill, size: 14, color: text),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Colonnes ($count)'.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 11,
                  color: _marketMutedFor(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BondTitleColumnVisibilityPanel extends StatelessWidget {
  const _BondTitleColumnVisibilityPanel({
    required this.draftColumns,
    required this.onDraftChanged,
  });

  final Set<_BondTitleColumn> draftColumns;
  final ValueChanged<Set<_BondTitleColumn>> onDraftChanged;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final surface = _marketSurfaceFor(context);
    final allColumns = _BondTitleColumn.values.toSet();
    final essentialColumns = _bondTitleEssentialColumns.toSet();
    final allSelected = _bondTitleColumnSetsEqual(draftColumns, allColumns);
    final essentialSelected =
        _bondTitleColumnSetsEqual(draftColumns, essentialColumns);

    return Container(
      width: 306,
      height: 452,
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Colonnes visibles'.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                _MarketColumnQuickAction(
                  label: 'Tout',
                  active: allSelected,
                  onTap: () => onDraftChanged(allColumns),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '·',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _MarketColumnQuickAction(
                  label: 'Essentiel',
                  active: essentialSelected,
                  onTap: () => onDraftChanged(essentialColumns),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final column in _BondTitleColumn.values)
                    _BondTitleColumnOptionRow(
                      label: column.label,
                      selected: draftColumns.contains(column),
                      enabled: draftColumns.length > 1 ||
                          !draftColumns.contains(column),
                      onTap: () {
                        final next = draftColumns.toSet();
                        next.contains(column)
                            ? next.remove(column)
                            : next.add(column);
                        onDraftChanged(next);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BondTitleColumnOptionRow extends StatelessWidget {
  const _BondTitleColumnOptionRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return InkWell(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            const SizedBox(width: 14),
            SizedBox(
              width: 22,
              child: selected
                  ? Icon(
                      CupertinoIcons.check_mark,
                      size: 15,
                      color: enabled ? _marketPrimary : muted,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled
                      ? (selected ? text : muted.withValues(alpha: 0.92))
                      : muted.withValues(alpha: 0.58),
                  fontSize: 12.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _BondTitleTableCell extends StatelessWidget {
  const _BondTitleTableCell(
    this.value, {
    required this.width,
    this.alignLeft = false,
    this.selected = false,
  });

  final String value;
  final double width;
  final bool alignLeft;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final border = _marketBorderFor(context);
    final resolvedAlignLeft = alignLeft || width >= 180;

    return Container(
      width: width,
      height: double.infinity,
      alignment:
          resolvedAlignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: border.withValues(alpha: 0.44)),
        ),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: resolvedAlignLeft ? TextAlign.left : TextAlign.right,
        style: TextStyle(
          color: selected ? _marketDashboardDeepBlue : text,
          fontSize: 11.2,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          height: 1.05,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BondRecordFixedIncomeMetrics {
  const _BondRecordFixedIncomeMetrics({
    required this.presentValue,
    required this.yieldToMaturity,
    required this.marketRate,
    required this.macaulay,
    required this.modified,
    required this.convexity,
  });

  final double presentValue;
  final double yieldToMaturity;
  final double marketRate;
  final double macaulay;
  final double modified;
  final double convexity;
}

_BondRecordFixedIncomeMetrics _bondRecordFixedIncomeMetrics({
  required MarketPortfolioRecord record,
  required double capital,
  required double coupon,
  required double maturity,
  required List<_YieldCurveSnapshot> yieldCurves,
}) {
  if (capital <= 0) {
    return const _BondRecordFixedIncomeMetrics(
      presentValue: 0,
      yieldToMaturity: 0,
      marketRate: 0,
      macaulay: 0,
      modified: 0,
      convexity: 0,
    );
  }

  final frequency = math.max(1, record.couponPaymentsPerYear);
  final fallbackYield = _bondFallbackMarketYield(record, coupon);
  final cashflows = _bondFutureCashflows(
    record: record,
    capital: capital,
    coupon: coupon,
    maturity: maturity,
  );
  if (cashflows.isEmpty) {
    return _BondRecordFixedIncomeMetrics(
      presentValue: capital,
      yieldToMaturity: fallbackYield,
      marketRate: fallbackYield,
      macaulay: maturity,
      modified: fallbackYield > -0.99
          ? maturity / (1 + fallbackYield / frequency)
          : maturity,
      convexity: math.max(0.0, maturity * (maturity + 1)).toDouble(),
    );
  }

  final marketRate = _bondPricingCurveRate(
        record: record,
        yieldCurves: yieldCurves,
        years: maturity > 0 ? maturity : cashflows.last.time,
      ) ??
      fallbackYield;
  final presentValue = _bondTermStructurePresentValue(
    record: record,
    yieldCurves: yieldCurves,
    cashflows: cashflows,
    fallbackYield: fallbackYield,
  );
  final resolvedPresentValue =
      presentValue > 0 && presentValue.isFinite ? presentValue : capital;
  final yieldToMaturity = _bondSolveEquivalentYield(
    cashflows: cashflows,
    targetPresentValue: resolvedPresentValue,
    frequency: frequency,
    fallbackYield: marketRate,
  );
  final durationMetrics = _bondDurationMetricsFromYield(
    cashflows: cashflows,
    presentValue: resolvedPresentValue,
    annualYield: yieldToMaturity,
    frequency: frequency,
  );

  return _BondRecordFixedIncomeMetrics(
    presentValue: resolvedPresentValue,
    yieldToMaturity: yieldToMaturity.isFinite ? yieldToMaturity : marketRate,
    marketRate: marketRate.isFinite ? marketRate : fallbackYield,
    macaulay: durationMetrics.macaulay,
    modified: durationMetrics.modified,
    convexity: durationMetrics.convexity,
  );
}

enum _BondPricingAmortizationKind { bullet, linear, constantAnnuity }

class _BondPricingCashflow {
  const _BondPricingCashflow({
    required this.time,
    required this.amount,
  });

  final double time;
  final double amount;
}

class _BondPricingDurationMetrics {
  const _BondPricingDurationMetrics({
    required this.macaulay,
    required this.modified,
    required this.convexity,
  });

  final double macaulay;
  final double modified;
  final double convexity;
}

List<_BondPricingCashflow> _bondFutureCashflows({
  required MarketPortfolioRecord record,
  required double capital,
  required double coupon,
  required double maturity,
}) {
  if (capital <= 0 || maturity <= 0) return const [];
  final frequency = math.max(1, record.couponPaymentsPerYear);
  final periods = math.max(1, (maturity * frequency).ceil());
  final kind = _bondPricingAmortizationKind(record);
  final cashflows = <_BondPricingCashflow>[];

  var outstanding = capital;
  var previousTime = 0.0;
  if (kind == _BondPricingAmortizationKind.bullet) {
    for (var period = 1; period <= periods; period++) {
      final time = math.min(period / frequency, maturity).toDouble();
      final periodLength = math.max(0.0, time - previousTime).toDouble();
      final couponCashflow = outstanding * coupon * periodLength;
      final principalCashflow =
          period == periods ? _bondRedemptionPrincipal(record, outstanding) : 0;
      final amount = couponCashflow + principalCashflow;
      if (amount > 0) {
        cashflows.add(_BondPricingCashflow(time: time, amount: amount));
      }
      previousTime = time;
    }
    return cashflows;
  }

  if (kind == _BondPricingAmortizationKind.constantAnnuity && coupon > 0) {
    final periodRate = coupon / frequency;
    final denominator = 1 - math.pow(1 + periodRate, -periods).toDouble();
    final annuity = denominator > 0 ? capital * periodRate / denominator : 0.0;
    if (annuity > 0 && annuity.isFinite) {
      for (var period = 1; period <= periods; period++) {
        final time = math.min(period / frequency, maturity).toDouble();
        final interest = outstanding * periodRate;
        final principal = period == periods
            ? outstanding
            : math
                .min(outstanding, math.max(0.0, annuity - interest))
                .toDouble();
        final amount = interest + principal;
        if (amount > 0) {
          cashflows.add(_BondPricingCashflow(time: time, amount: amount));
        }
        outstanding = math.max(0.0, outstanding - principal).toDouble();
        previousTime = time;
      }
      return cashflows;
    }
  }

  final scheduledPrincipal = capital / periods;
  for (var period = 1; period <= periods; period++) {
    final time = math.min(period / frequency, maturity).toDouble();
    final periodLength = math.max(0.0, time - previousTime).toDouble();
    final couponCashflow = outstanding * coupon * periodLength;
    final principal = period == periods
        ? outstanding
        : math.min(outstanding, scheduledPrincipal).toDouble();
    final amount = couponCashflow + principal;
    if (amount > 0) {
      cashflows.add(_BondPricingCashflow(time: time, amount: amount));
    }
    outstanding = math.max(0.0, outstanding - principal).toDouble();
    previousTime = time;
  }
  return cashflows;
}

_BondPricingAmortizationKind _bondPricingAmortizationKind(
  MarketPortfolioRecord record,
) {
  final profile =
      _normalizeYieldText(record.amortizationProfile).replaceAll("'", ' ');
  if (profile.contains('in fine') ||
      profile.contains('bullet') ||
      profile.contains('zero coupon') ||
      profile.contains('zerocoupon') ||
      profile.contains('remboursement final') ||
      profile.contains('a l echeance') ||
      profile.contains('a echeance')) {
    return _BondPricingAmortizationKind.bullet;
  }
  if (profile == 'constant' && _isBondPricingShortMonthlyTreasuryBill(record)) {
    return _BondPricingAmortizationKind.linear;
  }
  if (profile == 'constant' ||
      profile.contains('annuite') ||
      profile.contains('annuity') ||
      profile.contains('echeance constante') ||
      profile.contains('paiement constant')) {
    return _BondPricingAmortizationKind.constantAnnuity;
  }
  if (profile.contains('lineaire') ||
      profile.contains('linear') ||
      profile.contains('principal constant') ||
      profile.contains('capital constant') ||
      profile.contains('amortissement constant') ||
      profile.contains('amortissable') ||
      profile.contains('amorti')) {
    return _BondPricingAmortizationKind.linear;
  }
  return _BondPricingAmortizationKind.bullet;
}

bool _isBondPricingShortMonthlyTreasuryBill(MarketPortfolioRecord record) {
  final code = _normalizeYieldText(record.instrumentCode).replaceAll(' ', '');
  final type = _normalizeYieldText(record.instrumentType);
  return record.maturityMonths > 0 &&
      record.maturityMonths <= 36 &&
      record.couponPaymentsPerYear == 12 &&
      (code == 'bt' || type.contains('bon du tresor'));
}

double _bondRedemptionPrincipal(
  MarketPortfolioRecord record,
  double outstanding,
) {
  if (outstanding <= 0) return 0;
  final redemptionPrice = record.redemptionPrice;
  if (redemptionPrice > 0) {
    final nominal = record.nominalUnit;
    final multiplier = nominal > 0 && redemptionPrice > 200
        ? redemptionPrice / nominal
        : redemptionPrice <= 2
            ? redemptionPrice
            : redemptionPrice <= 200
                ? redemptionPrice / 100
                : 0.0;
    if (multiplier.isFinite && multiplier > 0 && multiplier <= 3) {
      return (outstanding * multiplier).toDouble();
    }
  }

  final premium = record.redemptionPremium;
  if (premium != 0 && premium.isFinite) {
    final premiumFraction = premium.abs() <= 2
        ? premium
        : premium.abs() <= 200
            ? premium / 100
            : 0.0;
    return math.max(0.0, outstanding * (1 + premiumFraction)).toDouble();
  }
  return outstanding;
}

double _bondFallbackMarketYield(MarketPortfolioRecord record, double coupon) {
  final explicitYield = record.yieldToMaturity;
  if (explicitYield.isFinite && explicitYield > -0.99 && explicitYield != 0) {
    return explicitYield.clamp(-0.95, 1.5).toDouble();
  }
  if (coupon.isFinite && coupon > 0) return coupon.clamp(0.0, 1.5).toDouble();
  return 0.0;
}

double _bondTermStructurePresentValue({
  required MarketPortfolioRecord record,
  required List<_YieldCurveSnapshot> yieldCurves,
  required List<_BondPricingCashflow> cashflows,
  required double fallbackYield,
}) {
  if (cashflows.isEmpty) return 0;
  final frequency = math.max(1, record.couponPaymentsPerYear);
  var presentValue = 0.0;
  for (final cashflow in cashflows) {
    final rate = _bondPricingCurveRate(
          record: record,
          yieldCurves: yieldCurves,
          years: cashflow.time,
        ) ??
        fallbackYield;
    final yieldPerPeriod = rate / frequency;
    if (yieldPerPeriod <= -0.999) continue;
    final discountPeriods = cashflow.time * frequency;
    final discount = math.pow(1 + yieldPerPeriod, discountPeriods).toDouble();
    if (discount <= 0 || !discount.isFinite) continue;
    presentValue += cashflow.amount / discount;
  }
  return presentValue.isFinite ? math.max(0.0, presentValue).toDouble() : 0;
}

double _bondSolveEquivalentYield({
  required List<_BondPricingCashflow> cashflows,
  required double targetPresentValue,
  required int frequency,
  required double fallbackYield,
}) {
  if (cashflows.isEmpty || targetPresentValue <= 0) return fallbackYield;

  double priceAt(double annualYield) {
    final yieldPerPeriod = annualYield / frequency;
    if (yieldPerPeriod <= -0.999) return double.infinity;
    var price = 0.0;
    for (final cashflow in cashflows) {
      final discountPeriods = cashflow.time * frequency;
      final discount = math.pow(1 + yieldPerPeriod, discountPeriods).toDouble();
      if (discount <= 0 || !discount.isFinite) return double.nan;
      price += cashflow.amount / discount;
    }
    return price;
  }

  var low = -0.95;
  var high = 1.5;
  final lowPrice = priceAt(low);
  final highPrice = priceAt(high);
  if (!lowPrice.isFinite || !highPrice.isFinite) return fallbackYield;
  if (targetPresentValue >= lowPrice) return low;
  if (targetPresentValue <= highPrice) return high;

  for (var iteration = 0; iteration < 80; iteration++) {
    final mid = (low + high) / 2;
    final price = priceAt(mid);
    if (!price.isFinite) break;
    if (price > targetPresentValue) {
      low = mid;
    } else {
      high = mid;
    }
  }
  final solved = (low + high) / 2;
  return solved.isFinite ? solved.clamp(-0.95, 1.5).toDouble() : fallbackYield;
}

_BondPricingDurationMetrics _bondDurationMetricsFromYield({
  required List<_BondPricingCashflow> cashflows,
  required double presentValue,
  required double annualYield,
  required int frequency,
}) {
  if (cashflows.isEmpty || presentValue <= 0) {
    return const _BondPricingDurationMetrics(
      macaulay: 0,
      modified: 0,
      convexity: 0,
    );
  }

  final yieldPerPeriod = annualYield / frequency;
  if (yieldPerPeriod <= -0.999) {
    return const _BondPricingDurationMetrics(
      macaulay: 0,
      modified: 0,
      convexity: 0,
    );
  }

  var macaulayNumerator = 0.0;
  var convexityNumerator = 0.0;
  var pricedValue = 0.0;
  for (final cashflow in cashflows) {
    final discountPeriods = cashflow.time * frequency;
    final discount = math.pow(1 + yieldPerPeriod, discountPeriods).toDouble();
    if (discount <= 0 || !discount.isFinite) continue;
    final discountedCashflow = cashflow.amount / discount;
    pricedValue += discountedCashflow;
    macaulayNumerator += cashflow.time * discountedCashflow;

    final convexityDiscount =
        math.pow(1 + yieldPerPeriod, discountPeriods + 2).toDouble();
    if (convexityDiscount > 0 && convexityDiscount.isFinite) {
      convexityNumerator += cashflow.amount *
          discountPeriods *
          (discountPeriods + 1) /
          (frequency * frequency * convexityDiscount);
    }
  }

  final denominator = pricedValue > 0 ? pricedValue : presentValue;
  if (denominator <= 0) {
    return const _BondPricingDurationMetrics(
      macaulay: 0,
      modified: 0,
      convexity: 0,
    );
  }

  final macaulay = macaulayNumerator / denominator;
  final modified = macaulay / (1 + yieldPerPeriod);
  final convexity = convexityNumerator / denominator;
  return _BondPricingDurationMetrics(
    macaulay: macaulay.isFinite ? math.max(0.0, macaulay).toDouble() : 0,
    modified: modified.isFinite ? math.max(0.0, modified).toDouble() : 0,
    convexity: convexity.isFinite ? math.max(0.0, convexity).toDouble() : 0,
  );
}

double? _bondPricingCurveRate({
  required MarketPortfolioRecord record,
  required List<_YieldCurveSnapshot> yieldCurves,
  required double years,
}) {
  final points = _bondPricingCurvePoints(record, yieldCurves);
  if (points.length < 2) return null;
  return _bondInterpolateYieldCurveRate(points, years);
}

List<_YieldCurvePoint> _bondPricingCurvePoints(
  MarketPortfolioRecord record,
  List<_YieldCurveSnapshot> yieldCurves,
) {
  final zoneId = _bondPricingZoneId(record);
  if (zoneId.isEmpty) return const [];
  final snapshot = yieldCurves.cast<_YieldCurveSnapshot?>().firstWhere(
        (item) => item?.id == zoneId,
        orElse: () => null,
      );
  if (snapshot == null) return const [];

  final country = _marketRecordText(record, 'Pays émetteur', '');
  final countryCurve = _bondPricingCountryCurve(snapshot, country);
  if (countryCurve != null && countryCurve.points.length >= 2) {
    return countryCurve.points;
  }
  return snapshot.points;
}

_YieldCurveCountryCurve? _bondPricingCountryCurve(
  _YieldCurveSnapshot snapshot,
  String country,
) {
  final target = _normalizeYieldText(country);
  if (target.isEmpty) return null;
  for (final curve in snapshot.countryCurves) {
    final normalized = _normalizeYieldText(curve.country);
    if (normalized == target ||
        target.contains(normalized) ||
        normalized.contains(target)) {
      return curve;
    }
  }
  return null;
}

String _bondPricingZoneId(MarketPortfolioRecord record) {
  final zone = _normalizeYieldText(_bondZoneLabel(record));
  if (zone.contains('uemoa')) return 'uemoa';
  if (zone.contains('cemac')) return 'cemac';
  return '';
}

double? _bondInterpolateYieldCurveRate(
  List<_YieldCurvePoint> points,
  double years,
) {
  final validPoints = points.where((point) => point.rate.isFinite).toList()
    ..sort((left, right) => left.years.compareTo(right.years));
  if (validPoints.isEmpty) return null;
  if (validPoints.length == 1 || years <= validPoints.first.years) {
    return validPoints.first.rate / 100;
  }
  if (years >= validPoints.last.years) {
    return validPoints.last.rate / 100;
  }

  for (var index = 1; index < validPoints.length; index++) {
    final right = validPoints[index];
    final left = validPoints[index - 1];
    if (years > right.years) continue;
    final span = right.years - left.years;
    if (span <= 0) return right.rate / 100;
    final ratio = (years - left.years) / span;
    final rate = left.rate + (right.rate - left.rate) * ratio;
    return rate / 100;
  }
  return validPoints.last.rate / 100;
}

class _BondIndicatorCardGrid extends StatelessWidget {
  const _BondIndicatorCardGrid({required this.items});

  final List<_BondKeyIndicatorSpec> items;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    const rowGap = 7.0;
    const cardHeight = 48.0;
    const maxItemsPerRow = 5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? maxItemsPerRow
            : width >= 760
                ? 4
                : width >= 560
                    ? 3
                    : width >= 360
                        ? 2
                        : 1;
        final safeColumns = math.min(columns, math.max(1, items.length));
        final cardWidth =
            (width - gap * math.max(0, safeColumns - 1)) / safeColumns;
        final rowCount =
            items.isEmpty ? 0 : (items.length / safeColumns).ceil();
        final contentHeight = rowCount == 0
            ? 0.0
            : rowCount * cardHeight + math.max(0, rowCount - 1) * rowGap;

        return SizedBox(
          height: contentHeight,
          child: Wrap(
            spacing: gap,
            runSpacing: rowGap,
            children: [
              for (final item in items)
                SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _BondInstitutionalIndicatorCard(item: item),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BondInstitutionalIndicatorCard extends StatelessWidget {
  const _BondInstitutionalIndicatorCard({required this.item});

  final _BondKeyIndicatorSpec item;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final isDark = _isMarketDark(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _BondIndicatorInfoDialog(item: item),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Color.alphaBlend(
                    item.color.withValues(alpha: 0.08),
                    _marketSurfaceFor(context),
                  )
                : item.color.withValues(alpha: 0.065),
            border: Border.all(color: item.color.withValues(alpha: 0.26)),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: isDark ? 0.18 : 0.13),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(item.icon, size: 15.5, color: item.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        maxLines: 1,
                        text: TextSpan(
                          text: item.value,
                          style: TextStyle(
                            color: text,
                            fontSize: 14.6,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                          children: [
                            if (item.unit.isNotEmpty)
                              TextSpan(
                                text: ' ${item.unit}',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 9.2,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted.withValues(alpha: 0.96),
                        fontSize: 9.8,
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
      ),
    );
  }
}

class _BondIndicatorInfoDialog extends StatelessWidget {
  const _BondIndicatorInfoDialog({required this.item});

  final _BondKeyIndicatorSpec item;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 470,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _marketSurfaceFor(context),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: item.color.withValues(alpha: 0.26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(CupertinoIcons.xmark, size: 15, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: item.color.withValues(alpha: 0.18)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: fm.Math.tex(
                  item.formula,
                  textStyle: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.detail,
              style: TextStyle(
                color: muted,
                fontSize: 12.7,
                fontWeight: FontWeight.w600,
                height: 1.38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _BondValuationChart extends StatelessWidget {
  const _BondValuationChart({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final entries = [
      _BondCompactBarEntry(
        label: 'CRD',
        value: stats.capitalRemainingDue,
        color: _marketPrimary,
      ),
      _BondCompactBarEntry(
        label: 'PV',
        value: stats.presentValue,
        color: _marketSuccess,
      ),
      _BondCompactBarEntry(
        label: 'Encours',
        value: stats.totalExposure,
        color: _marketCyan,
      ),
    ];
    return _BondHorizontalBars(entries: entries, moneyValues: true);
  }
}

// ignore: unused_element
class _BondYieldChart extends StatelessWidget {
  const _BondYieldChart({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final entries = [
      _BondCompactBarEntry(
        label: 'Coupon',
        value: stats.weightedCoupon,
        color: _marketCyan,
      ),
      _BondCompactBarEntry(
        label: 'YTM',
        value: stats.yieldToMaturity,
        color: _marketWarning,
      ),
      _BondCompactBarEntry(
        label: 'Spread',
        value: stats.couponYtmSpread,
        color: _marketViolet,
      ),
    ];
    return CustomPaint(
      painter: _BondYieldSpreadPainter(
        entries: entries,
        text: _marketTextFor(context),
        muted: _marketMutedFor(context),
        grid: _marketBorderFor(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

// ignore: unused_element
class _BondSensitivityChart extends StatelessWidget {
  const _BondSensitivityChart({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BondSensitivityPainter(
        macaulay: stats.macaulayDuration,
        modified: stats.modifiedDuration,
        convexity: stats.convexity,
        text: _marketTextFor(context),
        muted: _marketMutedFor(context),
        grid: _marketBorderFor(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BondCompactBarEntry {
  const _BondCompactBarEntry({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class _BondHorizontalBars extends StatelessWidget {
  const _BondHorizontalBars({
    required this.entries,
    required this.moneyValues,
  });

  final List<_BondCompactBarEntry> entries;
  final bool moneyValues;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final text = _marketTextFor(context);
    final maxValue = entries.fold<double>(
      0,
      (max, entry) => math.max(max, entry.value.abs()),
    );
    final denominator = maxValue <= 0 ? 1.0 : maxValue;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final entry in entries)
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: entry.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (entry.value.abs() / denominator)
                          .clamp(0.025, 1.0)
                          .toDouble(),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: entry.color.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: entry.color.withValues(alpha: 0.11),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: Text(
                  moneyValues
                      ? _bondIndicatorMoneyValue(entry.value)
                      : AppFormatters.percent(entry.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _BondYieldSpreadPainter extends CustomPainter {
  const _BondYieldSpreadPainter({
    required this.entries,
    required this.text,
    required this.muted,
    required this.grid,
  });

  final List<_BondCompactBarEntry> entries;
  final Color text;
  final Color muted;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const left = 8.0;
    final right = size.width - 8;
    const top = 8.0;
    final bottom = size.height - 24;
    final baseline = (top + bottom) / 2;
    final maxAbs = entries.fold<double>(
      0.001,
      (max, entry) => math.max(max, entry.value.abs()),
    );

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.70)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, baseline), Offset(right, baseline), gridPaint);

    final slot = (right - left) / entries.length;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final centerX = left + slot * index + slot / 2;
      final normalized = (entry.value.abs() / maxAbs).clamp(0.04, 1.0);
      final barHeight = (bottom - top) * 0.48 * normalized;
      final y = entry.value >= 0 ? baseline - barHeight : baseline;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, y + barHeight / 2),
          width: math.min(34, slot * 0.42),
          height: barHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = entry.color.withValues(alpha: 0.72),
      );
      _paintText(
        canvas,
        entry.label,
        Offset(centerX, bottom + 8),
        muted,
        9.5,
        FontWeight.w700,
        align: TextAlign.center,
      );
      _paintText(
        canvas,
        AppFormatters.percent(entry.value),
        Offset(centerX, y - 11),
        entry.color,
        9.5,
        FontWeight.w800,
        align: TextAlign.center,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String value,
    Offset center,
    Color color,
    double fontSize,
    FontWeight weight, {
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 92);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BondYieldSpreadPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.text != text ||
        oldDelegate.muted != muted ||
        oldDelegate.grid != grid;
  }
}

class _BondSensitivityPainter extends CustomPainter {
  const _BondSensitivityPainter({
    required this.macaulay,
    required this.modified,
    required this.convexity,
    required this.text,
    required this.muted,
    required this.grid,
  });

  final double macaulay;
  final double modified;
  final double convexity;
  final Color text;
  final Color muted;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final chart = Rect.fromLTWH(8, 8, size.width - 16, size.height - 30);
    final maxDuration = math.max(1.0, math.max(macaulay, modified));
    final bars = [
      _BondCompactBarEntry(
          label: 'Dmac', value: macaulay, color: _marketSuccess),
      _BondCompactBarEntry(
          label: 'Dmod', value: modified, color: _marketViolet),
    ];
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.62)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      gridPaint,
    );

    final slot = chart.width / 3;
    for (var index = 0; index < bars.length; index++) {
      final entry = bars[index];
      final height = chart.height *
          (entry.value / maxDuration).clamp(0.04, 1.0).toDouble();
      final centerX = chart.left + slot * index + slot * 0.52;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 16, chart.bottom - height, 32, height),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = entry.color.withValues(alpha: 0.70),
      );
      _paintText(
        canvas,
        entry.label,
        Offset(centerX, chart.bottom + 12),
        muted,
        9.5,
        FontWeight.w700,
      );
      _paintText(
        canvas,
        entry.value.toStringAsFixed(2).replaceAll('.', ','),
        Offset(centerX, chart.bottom - height - 10),
        entry.color,
        9.5,
        FontWeight.w800,
      );
    }

    final curvePaint = Paint()
      ..color = _marketWarning.withValues(alpha: 0.82)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final curve = Path()
      ..moveTo(chart.left + slot * 2.0, chart.bottom)
      ..cubicTo(
        chart.left + slot * 2.22,
        chart.top + chart.height * 0.80,
        chart.left + slot * 2.46,
        chart.top + chart.height * 0.26,
        chart.right - 10,
        chart.top + chart.height * 0.34,
      );
    canvas.drawPath(curve, curvePaint);
    _paintText(
      canvas,
      'Conv.',
      Offset(chart.left + slot * 2.36, chart.bottom + 12),
      muted,
      9.5,
      FontWeight.w700,
    );
    _paintText(
      canvas,
      _bondIndicatorDecimal(convexity),
      Offset(chart.right - 22, chart.top + 12),
      _marketWarning,
      9.5,
      FontWeight.w800,
    );
  }

  void _paintText(
    Canvas canvas,
    String value,
    Offset center,
    Color color,
    double fontSize,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 86);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BondSensitivityPainter oldDelegate) {
    return oldDelegate.macaulay != macaulay ||
        oldDelegate.modified != modified ||
        oldDelegate.convexity != convexity ||
        oldDelegate.text != text ||
        oldDelegate.muted != muted ||
        oldDelegate.grid != grid;
  }
}

String _bondIndicatorMoneyValue(double value) {
  if (!value.isFinite) return '-';
  final normalized = value.abs();
  if (normalized >= 1000000000) {
    return '${_marketDecimalNumberText(
      value / 1000000000,
      decimals: 2,
      trimTrailingZeros: false,
    )} Md';
  }
  if (normalized >= 1000000) {
    return '${_marketDecimalNumberText(
      value / 1000000,
      decimals: 2,
      trimTrailingZeros: false,
    )} M';
  }
  return value.toStringAsFixed(0).replaceAll('.', ',');
}

String _bondIndicatorMdValue(double value) {
  if (!value.isFinite) return '-';
  return _marketDecimalNumberText(
    value / 1000000000,
    decimals: 2,
    trimTrailingZeros: false,
  );
}

String _bondIndicatorBps(double value) {
  if (!value.isFinite) return '-';
  return _marketDecimalNumberText(
    value * 10000,
    decimals: 2,
    trimTrailingZeros: false,
  );
}

String _bondIndicatorDecimal(double value) {
  if (!value.isFinite) return '-';
  return _marketDecimalNumberText(
    value,
    decimals: 2,
    trimTrailingZeros: false,
  );
}

String _bondIndicatorPercent(double value) {
  if (!value.isFinite) return '-';
  return '${_marketDecimalNumberText(
    value * 100,
    decimals: 2,
    trimTrailingZeros: false,
  )} %';
}

String _bondIndicatorYears(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String _bondIndicatorMonths(double value) {
  if (!value.isFinite || value <= 0) return '0';
  return _bondMonthCount(value).toStringAsFixed(0);
}

class _MarketDashboard extends StatefulWidget {
  const _MarketDashboard();

  @override
  State<_MarketDashboard> createState() => _MarketDashboardState();
}

class _MarketDashboardState extends State<_MarketDashboard> {
  _MarketDashboardTab _selectedTab = _MarketDashboardTab.visualisation;
  MarketPortfolioType _selectedVisualisationType = MarketPortfolioType.bonds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.pagePadding,
            AppTheme.pagePadding,
            0,
          ),
          child: _MarketDashboardTabBar(
            selectedTab: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<
              Map<MarketPortfolioType, MarketPortfolioDataset>>(
            valueListenable: MarketDataImportStore.instance.datasetsNotifier,
            builder: (context, datasets, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: switch (_selectedTab) {
                  _MarketDashboardTab.visualisation => Padding(
                      key: const ValueKey('market-dashboard-visualisation'),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding,
                        AppTheme.pageGap,
                        AppTheme.pagePadding,
                        AppTheme.pagePadding,
                      ),
                      child: _MarketDashboardVisualisation(
                        datasets: datasets,
                        selectedType: _selectedVisualisationType,
                        onTypeChanged: (type) {
                          setState(() => _selectedVisualisationType = type);
                        },
                      ),
                    ),
                  _MarketDashboardTab.dataTable => Padding(
                      key: const ValueKey('market-dashboard-data-table'),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding,
                        AppTheme.pageGap,
                        AppTheme.pagePadding,
                        AppTheme.pagePadding,
                      ),
                      child: _MarketDashboardDataTable(
                        dataset: datasets[_selectedVisualisationType],
                        selectedType: _selectedVisualisationType,
                        onTypeChanged: (type) {
                          setState(() => _selectedVisualisationType = type);
                        },
                      ),
                    ),
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarketDashboardTabBar extends StatelessWidget {
  const _MarketDashboardTabBar({
    required this.selectedTab,
    required this.onChanged,
  });

  final _MarketDashboardTab selectedTab;
  final ValueChanged<_MarketDashboardTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final border = _marketBorderFor(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          _MarketDashboardTabButton(
            label: 'Visualisation d’indicateurs',
            selected: selectedTab == _MarketDashboardTab.visualisation,
            onTap: () => onChanged(_MarketDashboardTab.visualisation),
          ),
          _MarketDashboardTabButton(
            label: 'Tableau des données',
            selected: selectedTab == _MarketDashboardTab.dataTable,
            onTap: () => onChanged(_MarketDashboardTab.dataTable),
          ),
          Expanded(
            child: SizedBox(
              height: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.01)
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketDashboardTabButton extends StatelessWidget {
  const _MarketDashboardTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final text = _marketTextFor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius),
      ),
      child: SizedBox(
        height: 42,
        width: 230,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: selected ? _marketDashboardDeepBlue : muted,
                  fontSize: 12.8,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0,
                ),
                child: Text(label.tr(context)),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 2.5,
              width: selected ? 210 : 0,
              decoration: BoxDecoration(
                color: selected ? _marketDashboardDeepBlue : text,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketDashboardVisualisation extends StatelessWidget {
  const _MarketDashboardVisualisation({
    required this.datasets,
    required this.selectedType,
    required this.onTypeChanged,
  });

  final Map<MarketPortfolioType, MarketPortfolioDataset> datasets;
  final MarketPortfolioType selectedType;
  final ValueChanged<MarketPortfolioType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final source = datasets[selectedType];
    final hasData = source != null && source.rowCount > 0;

    return _MarketCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MarketVisualHeader(
            selectedType: selectedType,
            onTypeChanged: onTypeChanged,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!hasData)
                    _MarketVisualEmptyState(type: selectedType)
                  else if (selectedType == MarketPortfolioType.bonds)
                    _BondInstitutionalDashboard(dataset: source)
                  else ...[
                    _MarketAnalyticKpiGrid(dataset: source),
                    const SizedBox(height: 10),
                    _MarketVisualTwoColumnLayout(
                      left: _MarketConcentrationPanel(dataset: source),
                      right: _MarketScenarioRiskPanel(dataset: source),
                    ),
                    const SizedBox(height: 10),
                    _MarketVisualTwoColumnLayout(
                      left: _MarketAllocationPanel(dataset: source),
                      right: _MarketRiskSignalPanel(dataset: source),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketVisualHeader extends StatelessWidget {
  const _MarketVisualHeader({
    required this.selectedType,
    required this.onTypeChanged,
  });

  final MarketPortfolioType selectedType;
  final ValueChanged<MarketPortfolioType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selectedType == MarketPortfolioType.bonds
                ? _marketPrimary.withValues(alpha: 0.10)
                : _marketSuccess.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: selectedType == MarketPortfolioType.bonds
                  ? _marketPrimary.withValues(alpha: 0.24)
                  : _marketSuccess.withValues(alpha: 0.24),
            ),
          ),
          child: Icon(
            selectedType == MarketPortfolioType.bonds
                ? CupertinoIcons.doc_text_fill
                : CupertinoIcons.chart_bar_alt_fill,
            size: 15,
            color: selectedType == MarketPortfolioType.bonds
                ? _marketPrimary
                : _marketSuccess,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visualisation ${selectedType.label}'.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _MarketPortfolioTypeToggle(
          selectedType: selectedType,
          onChanged: onTypeChanged,
        ),
      ],
    );
  }
}

class _MarketPortfolioTypeToggle extends StatelessWidget {
  const _MarketPortfolioTypeToggle({
    required this.selectedType,
    required this.onChanged,
  });

  final MarketPortfolioType selectedType;
  final ValueChanged<MarketPortfolioType> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final isDark = _isMarketDark(context);

    return SizedBox(
      width: 286,
      height: 31,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF6F9FE),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Row(
            children: [
              for (final type in MarketPortfolioType.values)
                Expanded(
                  child: _MarketPortfolioTypeToggleButton(
                    type: type,
                    selected: selectedType == type,
                    onTap: () => onChanged(type),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketPortfolioTypeToggleButton extends StatelessWidget {
  const _MarketPortfolioTypeToggleButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final MarketPortfolioType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent =
        type == MarketPortfolioType.bonds ? _marketPrimary : _marketSuccess;
    final muted = _marketMutedFor(context);
    final icon = type == MarketPortfolioType.bonds
        ? CupertinoIcons.doc_text_fill
        : CupertinoIcons.chart_bar_alt_fill;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : accent,
              ),
              const SizedBox(width: 7),
              Text(
                type.label.tr(context),
                style: TextStyle(
                  color: selected ? Colors.white : muted,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketVisualEmptyState extends StatelessWidget {
  const _MarketVisualEmptyState({required this.type});

  final MarketPortfolioType type;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final text = _marketTextFor(context);

    return Container(
      height: 238,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _marketSurfaceSoftFor(context),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _marketBorderFor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == MarketPortfolioType.bonds
                ? CupertinoIcons.doc_text
                : CupertinoIcons.chart_bar,
            size: 30,
            color: muted,
          ),
          const SizedBox(height: 10),
          Text(
            'Aucune donnée ${type.label} importée',
            style: TextStyle(
              color: text,
              fontSize: 13.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Importez le modèle ${type.label} pour activer les indicateurs et graphiques.',
            style: TextStyle(
              color: muted,
              fontSize: 10.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketVisualTwoColumnLayout extends StatelessWidget {
  const _MarketVisualTwoColumnLayout({
    required this.left,
    required this.right,
  });

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: [
              left,
              const SizedBox(height: 10),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 13, child: left),
            const SizedBox(width: 10),
            Expanded(flex: 12, child: right),
          ],
        );
      },
    );
  }
}

class _MarketAnalyticKpiSpec {
  const _MarketAnalyticKpiSpec({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _MarketAnalyticKpiGrid extends StatelessWidget {
  const _MarketAnalyticKpiGrid({required this.dataset});

  final MarketPortfolioDataset dataset;

  @override
  Widget build(BuildContext context) {
    final specs = _marketAnalyticKpis(dataset);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const minWidth = 158.0;
        final columns = math.max(
          2,
          math.min(
              6, ((constraints.maxWidth + gap) / (minWidth + gap)).floor()),
        );
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final spec in specs)
              SizedBox(
                width: width,
                height: 46,
                child: _MarketAnalyticKpiCard(spec: spec),
              ),
          ],
        );
      },
    );
  }
}

class _MarketAnalyticKpiCard extends StatelessWidget {
  const _MarketAnalyticKpiCard({required this.spec});

  final _MarketAnalyticKpiSpec spec;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final isDark = _isMarketDark(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : spec.color.withValues(alpha: 0.050),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: spec.color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 21,
            height: 21,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(spec.icon, size: 11.5, color: spec.color),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.label.tr(context).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 7.2,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 11.7,
                    fontWeight: FontWeight.w700,
                    height: 1,
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

class _BondInstitutionalDashboard extends StatelessWidget {
  const _BondInstitutionalDashboard({required this.dataset});

  final MarketPortfolioDataset dataset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BondDashboardStats>(
      future: _bondDashboardStatsForAsync(dataset),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        if (stats == null) {
          return const _MarketDeferredLoadingState(
            title: 'Chargement du dashboard',
            subtitle: 'Nous préparons la vue du portefeuille.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BondDashboardKpiStrip(stats: stats),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final performance = _BondSimulationPanel(stats: stats);
                final rating = _BondRatingPanel(stats: stats);
                if (compact) {
                  return Column(
                    children: [
                      performance,
                      const SizedBox(height: 10),
                      rating,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 15, child: performance),
                    const SizedBox(width: 10),
                    Expanded(flex: 10, child: rating),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final countries = _BondCountryPanel(stats: stats);
                final zones = _BondZonePanel(stats: stats);
                final issuers = _BondIssuerConcentrationPanel(stats: stats);
                if (compact) {
                  return Column(
                    children: [
                      countries,
                      const SizedBox(height: 10),
                      zones,
                      const SizedBox(height: 10),
                      issuers,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 10, child: countries),
                    const SizedBox(width: 10),
                    Expanded(flex: 8, child: zones),
                    const SizedBox(width: 10),
                    Expanded(flex: 12, child: issuers),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final maturity = _BondMaturityPanel(stats: stats);
                final scatter = _BondCouponMaturityPanel(stats: stats);
                final risk = _BondRiskAnalyticsPanel(stats: stats);
                if (compact) {
                  return Column(
                    children: [
                      maturity,
                      const SizedBox(height: 10),
                      scatter,
                      const SizedBox(height: 10),
                      risk,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: maturity),
                    const SizedBox(width: 10),
                    Expanded(flex: 11, child: scatter),
                    const SizedBox(width: 10),
                    Expanded(flex: 8, child: risk),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _BondDashboardStats {
  const _BondDashboardStats({
    required this.dataset,
    required this.yieldCurves,
    required this.totalExposure,
    required this.capitalRemainingDue,
    required this.presentValue,
    required this.weightedCoupon,
    required this.yieldToMaturity,
    required this.couponYtmSpread,
    required this.weightedMaturityYears,
    required this.macaulayDuration,
    required this.modifiedDuration,
    required this.convexity,
    required this.activeBondCount,
    required this.maturedBondCount,
    required this.issuerCount,
    required this.dominantIssuer,
    required this.dominantIssuerShare,
    required this.dominantRating,
    required this.topFiveConcentration,
    required this.durationProxy,
    required this.rateSensitivity,
    required this.var99,
    required this.worstLoss,
    required this.volatility,
    required this.correlation,
    required this.ratingEntries,
    required this.countryEntries,
    required this.zoneEntries,
    required this.issuerEntries,
    required this.maturityBuckets,
    required this.couponBuckets,
    required this.lossSeries,
  });

  final MarketPortfolioDataset dataset;
  final List<_YieldCurveSnapshot> yieldCurves;
  final double totalExposure;
  final double capitalRemainingDue;
  final double presentValue;
  final double weightedCoupon;
  final double yieldToMaturity;
  final double couponYtmSpread;
  final double weightedMaturityYears;
  final double macaulayDuration;
  final double modifiedDuration;
  final double convexity;
  final int activeBondCount;
  final int maturedBondCount;
  final int issuerCount;
  final String dominantIssuer;
  final double dominantIssuerShare;
  final String dominantRating;
  final double topFiveConcentration;
  final double durationProxy;
  final double rateSensitivity;
  final double var99;
  final double worstLoss;
  final double volatility;
  final double correlation;
  final List<_MarketDistributionEntry> ratingEntries;
  final List<_MarketDistributionEntry> countryEntries;
  final List<_MarketDistributionEntry> zoneEntries;
  final List<_MarketDistributionEntry> issuerEntries;
  final List<_BondMaturityBucket> maturityBuckets;
  final List<_BondCouponBucket> couponBuckets;
  final List<double> lossSeries;

  static _BondDashboardStats from(
    MarketPortfolioDataset dataset, {
    required List<_YieldCurveSnapshot> yieldCurves,
  }) {
    final records = dataset.records;
    final activeBondCount =
        records.where((record) => record.isActiveAtAnalysisDate).length;
    final maturedBondCount =
        records.where((record) => record.isMaturedAtAnalysisDate).length;
    var capitalRemainingDueTotal = 0.0;
    var presentValueTotal = 0.0;
    var couponNumerator = 0.0;
    var couponDenominator = 0.0;
    var ytmNumerator = 0.0;
    var ytmDenominator = 0.0;
    var maturityNumerator = 0.0;
    var maturityDenominator = 0.0;
    var macaulayNumerator = 0.0;
    var modifiedNumerator = 0.0;
    var convexityNumerator = 0.0;
    var durationDenominator = 0.0;
    final issuers = <String>{};

    for (final record in records) {
      final capital = _bondOutstandingCapitalValue(record);
      if (capital <= 0) continue;
      final coupon = _bondCouponFraction(record.coupon);
      final maturityYears = _bondMaturityYears(record);
      final metrics = _bondRecordFixedIncomeMetrics(
        record: record,
        capital: capital,
        coupon: coupon,
        maturity: maturityYears,
        yieldCurves: yieldCurves,
      );
      final valuationWeight =
          metrics.presentValue > 0 ? metrics.presentValue : capital;
      if (capital > 0) capitalRemainingDueTotal += capital;
      if (metrics.presentValue > 0) presentValueTotal += metrics.presentValue;
      if (capital > 0 && coupon.isFinite) {
        couponNumerator += coupon * capital;
        couponDenominator += capital;
      }
      if (maturityYears > 0 && capital > 0) {
        maturityNumerator += maturityYears * capital;
        maturityDenominator += capital;
      }
      if (valuationWeight > 0) {
        if (metrics.yieldToMaturity.isFinite) {
          ytmNumerator += metrics.yieldToMaturity * valuationWeight;
          ytmDenominator += valuationWeight;
        }
        if ((metrics.macaulay > 0 ||
                metrics.modified > 0 ||
                metrics.convexity > 0) &&
            valuationWeight > 0) {
          macaulayNumerator += metrics.macaulay * valuationWeight;
          modifiedNumerator += metrics.modified * valuationWeight;
          convexityNumerator += metrics.convexity * valuationWeight;
          durationDenominator += valuationWeight;
        }
      }
      final issuer = record.issuer.trim();
      if (issuer.isNotEmpty && issuer != 'Non renseigné') issuers.add(issuer);
    }
    final total = capitalRemainingDueTotal > 0
        ? capitalRemainingDueTotal
        : math.max(0.0, dataset.totalExposure).toDouble();

    final issuerEntries = _bondGroupedEntries(
      dataset,
      (record) => record.issuer,
      limit: 10,
    );
    final ratingEntries = _bondGroupedEntries(
      dataset,
      _bondRatingLabel,
      limit: 8,
    );
    final topFiveAmount = issuerEntries
        .take(5)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final hasHistoricalReturns = dataset.scenarioReturns.isNotEmpty;
    final lossSeries = hasHistoricalReturns
        ? [
            for (final value in dataset.scenarioReturns)
              -value * dataset.portfolioValue,
          ]
        : dataset.bondRateShockLosses;
    final weightedCoupon =
        couponDenominator <= 0 ? 0.0 : couponNumerator / couponDenominator;
    final weightedMaturity = maturityDenominator <= 0
        ? 0.0
        : maturityNumerator / maturityDenominator;
    final capitalRemainingDue = total;
    final presentValue = presentValueTotal > 0 ? presentValueTotal : total;
    final yieldToMaturity = ytmDenominator <= 0
        ? weightedCoupon
        : (ytmNumerator / ytmDenominator).clamp(-0.99, 1.5).toDouble();
    final macaulayDuration = durationDenominator <= 0
        ? weightedMaturity
        : macaulayNumerator / durationDenominator;
    final modifiedDuration = durationDenominator <= 0
        ? macaulayDuration
        : modifiedNumerator / durationDenominator;
    final couponYtmSpread = weightedCoupon - yieldToMaturity;
    final convexity = durationDenominator <= 0
        ? math.max(0.0, macaulayDuration * (macaulayDuration + 1)).toDouble()
        : convexityNumerator / durationDenominator;

    return _BondDashboardStats(
      dataset: dataset,
      yieldCurves: yieldCurves,
      totalExposure: total,
      capitalRemainingDue: capitalRemainingDue,
      presentValue: presentValue,
      weightedCoupon: weightedCoupon,
      yieldToMaturity: yieldToMaturity,
      couponYtmSpread: couponYtmSpread,
      weightedMaturityYears: weightedMaturity,
      macaulayDuration: macaulayDuration,
      modifiedDuration: modifiedDuration,
      convexity: convexity,
      activeBondCount: activeBondCount,
      maturedBondCount: maturedBondCount,
      issuerCount: issuers.length,
      dominantIssuer:
          issuerEntries.isEmpty ? 'Non disponible' : issuerEntries.first.label,
      dominantIssuerShare:
          issuerEntries.isEmpty ? 0 : issuerEntries.first.share,
      dominantRating:
          ratingEntries.isEmpty ? 'Non noté' : ratingEntries.first.label,
      topFiveConcentration: total <= 0 ? 0 : topFiveAmount / total,
      durationProxy: modifiedDuration,
      rateSensitivity: modifiedDuration * presentValue * 0.0001,
      var99: hasHistoricalReturns
          ? dataset.scenarioVar99
          : dataset.bondRateShockVar99,
      worstLoss: hasHistoricalReturns
          ? dataset.scenarioWorstLoss
          : dataset.bondRateShockWorstLoss,
      volatility: dataset.annualizedVolatility,
      correlation: dataset.correlationProxy,
      ratingEntries: ratingEntries,
      countryEntries: _bondGroupedEntries(
        dataset,
        (record) => _marketRecordText(record, 'Pays émetteur', 'Non renseigné'),
        limit: 10,
      ),
      zoneEntries: _bondGroupedEntries(
        dataset,
        _bondZoneLabel,
        limit: 3,
      ),
      issuerEntries: issuerEntries,
      maturityBuckets: _bondMaturityBuckets(dataset),
      couponBuckets: _bondCouponBuckets(dataset),
      lossSeries: lossSeries,
    );
  }
}

class _BondDashboardKpiStrip extends StatelessWidget {
  const _BondDashboardKpiStrip({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _BondDashboardKpiItem(
        label: 'Encours total',
        value: _marketShortXofAmount(stats.totalExposure),
        icon: CupertinoIcons.money_dollar_circle_fill,
        color: _marketPrimary,
      ),
      _BondDashboardKpiItem(
        label: 'Titres actifs',
        value: '${stats.activeBondCount}/${stats.dataset.rowCount}',
        icon: CupertinoIcons.check_mark_circled_solid,
        color: _marketSuccess,
      ),
      _BondDashboardKpiItem(
        label: 'Coupon moyen',
        value: AppFormatters.percent(stats.weightedCoupon),
        icon: CupertinoIcons.percent,
        color: _marketSuccess,
      ),
      _BondDashboardKpiItem(
        label: 'Maturité moyenne',
        value: '${_bondIndicatorMonths(stats.weightedMaturityYears * 12)} mois',
        icon: CupertinoIcons.time_solid,
        color: _marketViolet,
      ),
      _BondDashboardKpiItem(
        label: 'Émetteur dominant',
        value: stats.dominantIssuer,
        icon: CupertinoIcons.scope,
        color: _marketWarning,
      ),
      _BondDashboardKpiItem(
        label: 'Rating dominant',
        value: stats.dominantRating,
        icon: CupertinoIcons.star_fill,
        color: _marketPrimary,
      ),
      _BondDashboardKpiItem(
        label: 'Top 5 émetteurs',
        value: AppFormatters.percent(stats.topFiveConcentration),
        icon: CupertinoIcons.chart_pie_fill,
        color: _marketDanger,
      ),
    ];

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(child: _BondDashboardKpiCard(item: items[index])),
            if (index < items.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _BondDashboardKpiItem {
  const _BondDashboardKpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _BondDashboardKpiCard extends StatelessWidget {
  const _BondDashboardKpiCard({required this.item});

  final _BondDashboardKpiItem item;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final isDark = _isMarketDark(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : item.color.withValues(alpha: 0.050),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: item.color.withValues(alpha: isDark ? 0.24 : 0.28),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 21,
            height: 21,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(item.icon, size: 11.5, color: item.color),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 7.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 11.7,
                    fontWeight: FontWeight.w700,
                    height: 1,
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

class _BondSectionPanel extends StatelessWidget {
  const _BondSectionPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.height,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final hasSubtitle = subtitle.trim().isNotEmpty;
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _marketSurfaceSoftFor(context)
            .withValues(alpha: _isMarketDark(context) ? 0.50 : 0.74),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _marketBorderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: text,
              fontSize: 13.1,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted,
                fontSize: 10.0,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            const SizedBox(height: 11),
          ] else
            const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
    if (height == null) return panel;
    return SizedBox(height: height, child: panel);
  }
}

class _BondSimulationPanel extends StatelessWidget {
  const _BondSimulationPanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _BondSectionPanel(
      height: 262,
      title: 'Distribution des pertes simulées',
      subtitle:
          'Queue de risque, seuil VaR 99% et exposition aux chocs de taux',
      child: Column(
        children: [
          Expanded(
            child: _BondLossDistributionChart(
              losses: stats.lossSeries,
              var99: stats.var99,
              worstLoss: stats.worstLoss,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MarketMicroMetric(
                  label: 'VaR 99%',
                  value: _marketReadableMoney(stats.var99),
                  color: _marketDanger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MarketMicroMetric(
                  label: 'Pire perte',
                  value: _marketReadableMoney(stats.worstLoss),
                  color: _marketWarning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MarketMicroMetric(
                  label: 'Sensibilité au risque de taux',
                  value: _marketReadableMoney(stats.rateSensitivity),
                  color: _marketViolet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BondRatingPanel extends StatelessWidget {
  const _BondRatingPanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    return SizedBox(
      height: 262,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: BoxDecoration(
          color: _marketSurfaceFor(context),
          borderRadius: BorderRadius.circular(1),
          border: Border.all(
            color: _marketBorderFor(context).withValues(alpha: 0.72),
            width: 0.7,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par notation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Qualité crédit pondérée par encours',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted,
                fontSize: 9.8,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _MarketDonutBreakdown(
                entries: stats.ratingEntries.take(6).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BondCountryPanel extends StatelessWidget {
  const _BondCountryPanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _BondSectionPanel(
      height: 286,
      title: 'Pays émetteurs',
      subtitle: 'Top 10 par poids d’encours',
      child: _BondHorizontalBarChart(entries: stats.countryEntries),
    );
  }
}

class _BondZonePanel extends StatelessWidget {
  const _BondZonePanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _BondSectionPanel(
      height: 286,
      title: 'Répartition par zone',
      subtitle: 'Allocation géographique en zones prudentielles',
      child: _BondZoneAllocation(entries: stats.zoneEntries),
    );
  }
}

class _BondIssuerConcentrationPanel extends StatelessWidget {
  const _BondIssuerConcentrationPanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _BondSectionPanel(
      height: 286,
      title: 'Principaux émetteurs',
      subtitle: 'Top 8 par poids d’encours',
      child:
          _BondIssuerRankedBars(entries: stats.issuerEntries.take(8).toList()),
    );
  }
}

class _BondMaturityPanel extends StatelessWidget {
  const _BondMaturityPanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _BondSectionPanel(
      height: 268,
      title: 'Structure des maturités',
      subtitle:
          "Durée résiduelle moyenne : ${stats.weightedMaturityYears.toStringAsFixed(1).replaceAll('.', ',')} ans",
      child: _BondMaturityHistogramChart(
        buckets: stats.maturityBuckets,
        averageYears: stats.weightedMaturityYears,
      ),
    );
  }
}

class _BondCouponMaturityPanel extends StatelessWidget {
  const _BondCouponMaturityPanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _BondSectionPanel(
      height: 268,
      title: 'Coupon par maturité',
      subtitle: 'Coupon moyen pondéré et encours par tranche résiduelle',
      child: _BondCouponCurveChart(
        buckets: stats.couponBuckets,
      ),
    );
  }
}

class _BondRiskAnalyticsPanel extends StatelessWidget {
  const _BondRiskAnalyticsPanel({required this.stats});

  final _BondDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _BondSectionPanel(
      height: 268,
      title: 'Sensibilité obligataire',
      subtitle: 'Volatilité, corrélation, duration et impact du risque de taux',
      child: _MarketRiskTileGrid(
        columns: 1,
        itemHeight: 48,
        compact: true,
        items: [
          _MarketRiskTileData(
            label: 'Volatilité',
            value: AppFormatters.percent(stats.volatility),
            color: _marketCyan,
          ),
          _MarketRiskTileData(
            label: 'Corrélation',
            value: stats.correlation.toStringAsFixed(2).replaceAll('.', ','),
            color: _marketViolet,
          ),
          _MarketRiskTileData(
            label: 'Duration',
            value: stats.durationProxy.toStringAsFixed(2).replaceAll('.', ','),
            color: _marketPrimary,
          ),
          _MarketRiskTileData(
            label: 'Sensibilité',
            value: _marketShortXofAmount(stats.rateSensitivity),
            color: _marketWarning,
          ),
        ],
      ),
    );
  }
}

class _BondHorizontalBarChart extends StatelessWidget {
  const _BondHorizontalBarChart({required this.entries});

  final List<_MarketDistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final border = _marketBorderFor(context);
    final isDark = _isMarketDark(context);
    final maxAmount =
        entries.fold<double>(0, (max, item) => math.max(max, item.amount));
    final shown = entries.take(10).toList();
    return Column(
      children: [
        for (var index = 0; index < shown.length; index++) ...[
          Expanded(
            child: _BondDistributionBarRow(
              entry: shown[index],
              maxAmount: maxAmount,
              emphasized: index == 0,
              isLast: index == shown.length - 1,
              text: text,
              muted: muted,
              border: border,
              isDark: isDark,
            ),
          ),
          if (index != shown.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _BondDistributionBarRow extends StatefulWidget {
  const _BondDistributionBarRow({
    required this.entry,
    required this.maxAmount,
    required this.emphasized,
    required this.isLast,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  final _MarketDistributionEntry entry;
  final double maxAmount;
  final bool emphasized;
  final bool isLast;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  @override
  State<_BondDistributionBarRow> createState() =>
      _BondDistributionBarRowState();
}

class _BondDistributionBarRowState extends State<_BondDistributionBarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final widthFactor = widget.maxAmount <= 0
        ? 0.0
        : (widget.entry.amount / widget.maxAmount).clamp(0.025, 1.0);
    final baseAlpha = widget.emphasized ? 0.86 : 0.58;
    return Tooltip(
      message:
          '${widget.entry.label}\n${AppFormatters.percent(widget.entry.share)} du portefeuille\n${_marketReadableMoney(widget.entry.amount)}',
      waitDuration: const Duration(milliseconds: 220),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.emphasized || _hovered
                ? _marketPrimary.withValues(
                    alpha: widget.isDark
                        ? (_hovered ? 0.16 : 0.10)
                        : (_hovered ? 0.075 : 0.045),
                  )
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.border.withValues(
                  alpha: widget.isLast ? 0 : 0.52,
                ),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    widget.entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.text,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 13,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          height: _hovered ? 8.5 : 7,
                          decoration: BoxDecoration(
                            color: _marketPrimary.withValues(
                              alpha: widget.isDark ? 0.13 : 0.075,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: widthFactor,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            height: _hovered ? 9.5 : 7,
                            decoration: BoxDecoration(
                              color: _marketPrimary.withValues(
                                alpha: _hovered
                                    ? (baseAlpha + 0.16).clamp(0.0, 1.0)
                                    : baseAlpha,
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: _hovered
                                  ? [
                                      BoxShadow(
                                        color: _marketPrimary.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text(
                    AppFormatters.percent(widget.entry.share),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: widget.emphasized || _hovered
                          ? _marketPrimary
                          : widget.muted,
                      fontSize: 9.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BondIssuerRankedBars extends StatelessWidget {
  const _BondIssuerRankedBars({required this.entries});

  final List<_MarketDistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final border = _marketBorderFor(context);
    final isDark = _isMarketDark(context);
    final maxShare = entries.fold<double>(
      0,
      (max, entry) => math.max(max, entry.share),
    );
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          Expanded(
            child: _BondIssuerRankedRow(
              entry: entries[index],
              rank: index + 1,
              maxShare: maxShare,
              emphasized: index == 0,
              isLast: index == entries.length - 1,
              text: text,
              muted: muted,
              border: border,
              isDark: isDark,
            ),
          ),
          if (index != entries.length - 1) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _BondIssuerRankedRow extends StatefulWidget {
  const _BondIssuerRankedRow({
    required this.entry,
    required this.rank,
    required this.maxShare,
    required this.emphasized,
    required this.isLast,
    required this.text,
    required this.muted,
    required this.border,
    required this.isDark,
  });

  final _MarketDistributionEntry entry;
  final int rank;
  final double maxShare;
  final bool emphasized;
  final bool isLast;
  final Color text;
  final Color muted;
  final Color border;
  final bool isDark;

  @override
  State<_BondIssuerRankedRow> createState() => _BondIssuerRankedRowState();
}

class _BondIssuerRankedRowState extends State<_BondIssuerRankedRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final widthFactor = widget.maxShare <= 0
        ? 0.0
        : (widget.entry.share / widget.maxShare).clamp(0.025, 1.0);
    final baseAlpha = widget.emphasized ? 0.88 : 0.58;
    return Tooltip(
      message:
          '#${widget.rank} ${widget.entry.label}\n${AppFormatters.percent(widget.entry.share)} du portefeuille\n${_marketReadableMoney(widget.entry.amount)}',
      waitDuration: const Duration(milliseconds: 220),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: widget.emphasized || _hovered
                ? _marketPrimary.withValues(
                    alpha: widget.isDark
                        ? (_hovered ? 0.16 : 0.11)
                        : (_hovered ? 0.080 : 0.055),
                  )
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.border.withValues(
                  alpha: widget.isLast ? 0 : 0.58,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '#${widget.rank}',
                  style: TextStyle(
                    color: widget.emphasized || _hovered
                        ? _marketPrimary
                        : widget.muted,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  widget.entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.text,
                    fontSize: 9.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 12,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        height: _hovered ? 7.8 : 6,
                        decoration: BoxDecoration(
                          color: _marketPrimary.withValues(
                            alpha: widget.isDark ? 0.13 : 0.075,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          height: _hovered ? 8.8 : 6,
                          decoration: BoxDecoration(
                            color: _marketPrimary.withValues(
                              alpha: _hovered
                                  ? (baseAlpha + 0.15).clamp(0.0, 1.0)
                                  : baseAlpha,
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: _hovered
                                ? [
                                    BoxShadow(
                                      color: _marketPrimary.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: Text(
                  AppFormatters.percent(widget.entry.share),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: widget.emphasized || _hovered
                        ? _marketPrimary
                        : widget.muted,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BondZoneAllocation extends StatelessWidget {
  const _BondZoneAllocation({required this.entries});

  final List<_MarketDistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final zones = _orderedZoneEntries(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < zones.length; index++) ...[
          Expanded(child: _BondZoneRow(entry: zones[index])),
          if (index < zones.length - 1) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _BondZoneRow extends StatefulWidget {
  const _BondZoneRow({required this.entry});

  final _MarketDistributionEntry entry;

  @override
  State<_BondZoneRow> createState() => _BondZoneRowState();
}

class _BondZoneRowState extends State<_BondZoneRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 155),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(14, 3, 10, 3),
        decoration: BoxDecoration(
          color: widget.entry.color.withValues(
            alpha: _isMarketDark(context)
                ? (_hovered ? 0.18 : 0.12)
                : (_hovered ? 0.085 : 0.052),
          ),
          borderRadius: BorderRadius.circular(2),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.entry.color.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: text,
                fontSize: 10.1,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppFormatters.percent(widget.entry.share),
              textAlign: TextAlign.left,
              style: TextStyle(
                color: widget.entry.color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _marketReadableMoney(widget.entry.amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: muted,
                fontSize: 8.6,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: widget.entry.share.clamp(0.0, 1.0),
                ),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: _hovered ? 4.5 : 3,
                    backgroundColor: widget.entry.color.withValues(alpha: 0.10),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(widget.entry.color),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BondMaturityBucket {
  const _BondMaturityBucket({
    required this.label,
    required this.minYears,
    required this.maxYears,
    required this.amount,
    required this.color,
  });

  final String label;
  final double minYears;
  final double maxYears;
  final double amount;
  final Color color;
}

class _BondCouponBucket {
  const _BondCouponBucket({
    required this.label,
    required this.amount,
    required this.weightedCoupon,
    required this.color,
  });

  final String label;
  final double amount;
  final double weightedCoupon;
  final Color color;
}

class _BondLossDistributionChart extends StatefulWidget {
  const _BondLossDistributionChart({
    required this.losses,
    required this.var99,
    required this.worstLoss,
  });

  final List<double> losses;
  final double var99;
  final double worstLoss;

  @override
  State<_BondLossDistributionChart> createState() =>
      _BondLossDistributionChartState();
}

class _BondLossDistributionChartState
    extends State<_BondLossDistributionChart> {
  Offset? _hoverPosition;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => setState(() => _hoverPosition = event.localPosition),
      onExit: (_) => setState(() => _hoverPosition = null),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _hoverPosition == null ? 0 : 1),
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        builder: (context, hoverProgress, _) {
          return CustomPaint(
            painter: _BondLossDistributionPainter(
              losses: widget.losses,
              var99: widget.var99,
              worstLoss: widget.worstLoss,
              color: _marketPrimary,
              danger: _marketDanger,
              warning: _marketWarning,
              muted: _marketMutedFor(context),
              text: _marketTextFor(context),
              isDark: _isMarketDark(context),
              hoverPosition: _hoverPosition,
              hoverProgress: hoverProgress,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _BondMaturityHistogramChart extends StatefulWidget {
  const _BondMaturityHistogramChart({
    required this.buckets,
    required this.averageYears,
  });

  final List<_BondMaturityBucket> buckets;
  final double averageYears;

  @override
  State<_BondMaturityHistogramChart> createState() =>
      _BondMaturityHistogramChartState();
}

class _BondMaturityHistogramChartState
    extends State<_BondMaturityHistogramChart> {
  Offset? _hoverPosition;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => setState(() => _hoverPosition = event.localPosition),
      onExit: (_) => setState(() => _hoverPosition = null),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _hoverPosition == null ? 0 : 1),
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        builder: (context, hoverProgress, _) {
          return CustomPaint(
            painter: _BondMaturityHistogramPainter(
              buckets: widget.buckets,
              averageYears: widget.averageYears,
              color: _marketPrimary,
              success: _marketSuccess,
              warning: _marketWarning,
              muted: _marketMutedFor(context),
              text: _marketTextFor(context),
              isDark: _isMarketDark(context),
              hoverPosition: _hoverPosition,
              hoverProgress: hoverProgress,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _BondCouponCurveChart extends StatefulWidget {
  const _BondCouponCurveChart({required this.buckets});

  final List<_BondCouponBucket> buckets;

  @override
  State<_BondCouponCurveChart> createState() => _BondCouponCurveChartState();
}

class _BondCouponCurveChartState extends State<_BondCouponCurveChart> {
  Offset? _hoverPosition;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => setState(() => _hoverPosition = event.localPosition),
      onExit: (_) => setState(() => _hoverPosition = null),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _hoverPosition == null ? 0 : 1),
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        builder: (context, hoverProgress, _) {
          return CustomPaint(
            painter: _BondCouponCurvePainter(
              buckets: widget.buckets,
              color: _marketCyan,
              warning: _marketWarning,
              muted: _marketMutedFor(context),
              text: _marketTextFor(context),
              isDark: _isMarketDark(context),
              hoverPosition: _hoverPosition,
              hoverProgress: hoverProgress,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _BondLossDistributionPainter extends CustomPainter {
  const _BondLossDistributionPainter({
    required this.losses,
    required this.var99,
    required this.worstLoss,
    required this.color,
    required this.danger,
    required this.warning,
    required this.muted,
    required this.text,
    required this.isDark,
    this.hoverPosition,
    this.hoverProgress = 0,
  });

  final List<double> losses;
  final double var99;
  final double worstLoss;
  final Color color;
  final Color danger;
  final Color warning;
  final Color muted;
  final Color text;
  final bool isDark;
  final Offset? hoverPosition;
  final double hoverProgress;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 50.0;
    const top = 10.0;
    const bottom = 30.0;
    const right = 12.0;
    final chart = Rect.fromLTWH(
      left,
      top,
      math.max(1, size.width - left - right),
      math.max(1, size.height - top - bottom),
    );
    final grid = Paint()
      ..color = (isDark ? Colors.white : _marketBorder).withValues(alpha: 0.55)
      ..strokeWidth = 0.7;
    for (final fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = chart.top + chart.height * fraction;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    for (final fraction in [0.0, 0.5, 1.0]) {
      final x = chart.left + chart.width * fraction;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), grid);
    }
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      Paint()
        ..color = muted.withValues(alpha: 0.55)
        ..strokeWidth = 0.9,
    );

    if (losses.length < 2) return;
    final sorted = losses.toList()..sort();
    final minValue = math.min(0.0, sorted.first);
    final maxValue = math.max(worstLoss, sorted.last);
    final span = math.max(1.0, maxValue - minValue);
    double xFor(double value) =>
        chart.left + ((value - minValue) / span) * chart.width;

    final varX = xFor(var99);
    canvas.drawRect(
      Rect.fromLTRB(varX, chart.top, chart.right, chart.bottom),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            danger.withValues(alpha: 0.015),
            danger.withValues(alpha: 0.13),
          ],
        ).createShader(
            Rect.fromLTRB(varX, chart.top, chart.right, chart.bottom)),
    );

    const binCount = 28;
    final bins = List<int>.filled(binCount, 0);
    for (final value in sorted) {
      final index = (((value - minValue) / span) * (binCount - 1))
          .round()
          .clamp(0, binCount - 1);
      bins[index]++;
    }
    final maxCount = math.max(1, bins.reduce(math.max));
    final gap = math.max(2.0, chart.width / 220);
    final barWidth =
        math.max(2.0, (chart.width - gap * (binCount - 1)) / binCount);
    final hoverBin = hoverPosition != null && chart.contains(hoverPosition!)
        ? (((hoverPosition!.dx - chart.left) / chart.width) * binCount)
            .floor()
            .clamp(0, binCount - 1)
            .toInt()
        : null;
    for (var index = 0; index < binCount; index++) {
      final start = minValue + span * index / binCount;
      final end = minValue + span * (index + 1) / binCount;
      final midpoint = (start + end) / 2;
      final isHovered = hoverBin == index;
      final height = chart.height * (bins[index] / maxCount);
      final animatedHeight =
          math.min(chart.height, height + (isHovered ? 8 * hoverProgress : 0));
      final rect = Rect.fromLTWH(
        chart.left + index * (barWidth + gap),
        chart.bottom - animatedHeight,
        barWidth,
        animatedHeight,
      );
      final isTail = midpoint >= var99;
      final barColor = isTail ? danger : color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              barColor.withValues(
                alpha: (isTail ? 0.72 : 0.58) + (isHovered ? 0.16 : 0),
              ),
              barColor.withValues(alpha: isTail ? 0.22 : 0.16),
            ],
          ).createShader(rect),
      );
    }

    final densityPath = Path();
    for (var index = 0; index < binCount; index++) {
      final x = chart.left + index * (barWidth + gap) + barWidth / 2;
      final smoothed = _smoothBin(bins, index) / maxCount;
      final y = chart.bottom - chart.height * smoothed;
      if (index == 0) {
        densityPath.moveTo(x, y);
      } else {
        densityPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      densityPath,
      Paint()
        ..color = color.withValues(alpha: hoverBin == null ? 0.92 : 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hoverBin == null ? 2.2 : 5.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      densityPath,
      Paint()
        ..color = color.withValues(alpha: hoverBin == null ? 0.92 : 1.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hoverBin == null ? 2.2 : 2.4 + hoverProgress * 0.8
        ..strokeCap = StrokeCap.round,
    );
    if (hoverBin != null) {
      final x = chart.left + hoverBin * (barWidth + gap) + barWidth / 2;
      final smoothed = _smoothBin(bins, hoverBin) / maxCount;
      final y = chart.bottom - chart.height * smoothed;
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..strokeWidth = 0.9,
      );
      canvas.drawCircle(
        Offset(x, y),
        4.8 + hoverProgress * 1.8,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        Offset(x, y),
        3.2,
        Paint()..color = color,
      );
    }

    canvas.drawLine(
      Offset(varX, chart.top),
      Offset(varX, chart.bottom),
      Paint()
        ..color = danger
        ..strokeWidth = 2.0,
    );

    _paintSmallLabel(
      canvas,
      'VaR 99%',
      Offset(varX + 6, chart.top + 10),
      danger,
      TextAlign.left,
    );
    _paintSmallLabel(
      canvas,
      'queue extrême',
      Offset(chart.right - 6, chart.bottom - 34),
      warning,
      TextAlign.right,
    );
    _paintSmallLabel(
        canvas, 'fréquence', Offset(chart.left, 1), muted, TextAlign.left);
    _paintSmallLabel(canvas, 'pertes simulées',
        Offset(chart.right, size.height - 9), text, TextAlign.right);
    _paintSmallLabel(canvas, _marketReadableMoney(minValue),
        Offset(chart.left, chart.bottom + 14), muted, TextAlign.left);
    _paintSmallLabel(canvas, _marketReadableMoney(maxValue),
        Offset(chart.right, chart.bottom + 14), muted, TextAlign.right);
    if (hoverBin != null) {
      final start = minValue + span * hoverBin / binCount;
      final end = minValue + span * (hoverBin + 1) / binCount;
      _paintChartTooltip(
        canvas,
        [
          'Classe de pertes',
          '${_marketReadableMoney(start)} → ${_marketReadableMoney(end)}',
          '${bins[hoverBin]} simulations',
        ],
        hoverPosition!,
        chart,
        color,
        isDark,
      );
    }
  }

  double _smoothBin(List<int> bins, int index) {
    final left = bins[math.max(0, index - 1)];
    final center = bins[index];
    final right = bins[math.min(bins.length - 1, index + 1)];
    return (left + center * 2 + right) / 4;
  }

  @override
  bool shouldRepaint(covariant _BondLossDistributionPainter oldDelegate) {
    return oldDelegate.losses != losses ||
        oldDelegate.var99 != var99 ||
        oldDelegate.worstLoss != worstLoss ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.isDark != isDark;
  }
}

class _BondMaturityHistogramPainter extends CustomPainter {
  const _BondMaturityHistogramPainter({
    required this.buckets,
    required this.averageYears,
    required this.color,
    required this.success,
    required this.warning,
    required this.muted,
    required this.text,
    required this.isDark,
    this.hoverPosition,
    this.hoverProgress = 0,
  });

  final List<_BondMaturityBucket> buckets;
  final double averageYears;
  final Color color;
  final Color success;
  final Color warning;
  final Color muted;
  final Color text;
  final bool isDark;
  final Offset? hoverPosition;
  final double hoverProgress;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0;
    const bottom = 26.0;
    const top = 8.0;
    final chart = Rect.fromLTWH(
      left,
      top,
      math.max(1, size.width - left - 8),
      math.max(1, size.height - top - bottom),
    );
    final maxAmount =
        buckets.fold<double>(0, (max, bucket) => math.max(max, bucket.amount));
    final grid = Paint()
      ..color = (isDark ? Colors.white : _marketBorder).withValues(alpha: 0.52)
      ..strokeWidth = 0.7;
    final yMax = maxAmount <= 0 ? 1.0 : maxAmount;
    for (final fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = chart.bottom - chart.height * fraction;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _paintSmallLabel(
        canvas,
        _marketAxisMdAmount(yMax * fraction),
        Offset(chart.left - 6, y),
        muted,
        TextAlign.right,
      );
    }
    _paintSmallLabel(
      canvas,
      'Encours',
      Offset(chart.left, chart.top - 6),
      muted,
      TextAlign.left,
    );
    if (buckets.isEmpty) return;
    const gap = 10.0;
    final barWidth =
        (chart.width - gap * (buckets.length - 1)) / buckets.length;
    final hoverIndex = hoverPosition != null && chart.contains(hoverPosition!)
        ? (((hoverPosition!.dx - chart.left) / chart.width) * buckets.length)
            .floor()
            .clamp(0, buckets.length - 1)
            .toInt()
        : null;
    final centers = <Offset>[];
    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      final ratio = maxAmount <= 0 ? 0.0 : bucket.amount / maxAmount;
      final isHovered = hoverIndex == index;
      final barHeight = math.max(4.0, chart.height * ratio);
      final animatedHeight = math.min(
        chart.height,
        barHeight + (isHovered ? 9 * hoverProgress : 0),
      );
      final x = chart.left + index * (barWidth + gap);
      final rect = Rect.fromLTWH(
        x,
        chart.bottom - animatedHeight,
        barWidth,
        animatedHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bucket.color.withValues(alpha: isHovered ? 1.0 : 0.90),
              bucket.color.withValues(alpha: 0.22),
            ],
          ).createShader(rect),
      );
      centers.add(Offset(x + barWidth / 2, chart.bottom - barHeight));
      _paintSmallLabel(canvas, bucket.label,
          Offset(x + barWidth / 2, size.height - 10), text, TextAlign.center);
    }
    final density = Path();
    for (var index = 0; index < centers.length; index++) {
      final point = Offset(centers[index].dx, centers[index].dy - 5);
      if (index == 0) {
        density.moveTo(point.dx, point.dy);
      } else {
        density.quadraticBezierTo(
          (centers[index - 1].dx + point.dx) / 2,
          math.min(centers[index - 1].dy, point.dy) - 10,
          point.dx,
          point.dy,
        );
      }
    }
    canvas.drawPath(
      density,
      Paint()
        ..color = success.withValues(alpha: hoverIndex == null ? 0.85 : 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hoverIndex == null ? 1.8 : 5.0,
    );
    canvas.drawPath(
      density,
      Paint()
        ..color = success.withValues(alpha: hoverIndex == null ? 0.85 : 0.96)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hoverIndex == null ? 1.8 : 2.2 + hoverProgress * 0.8,
    );
    if (hoverIndex != null && hoverIndex < centers.length) {
      final point = Offset(centers[hoverIndex].dx, centers[hoverIndex].dy - 5);
      canvas.drawLine(
        Offset(point.dx, chart.top),
        Offset(point.dx, chart.bottom),
        Paint()
          ..color = success.withValues(alpha: 0.22)
          ..strokeWidth = 0.9,
      );
      canvas.drawCircle(
        point,
        4.6 + hoverProgress * 1.8,
        Paint()..color = success.withValues(alpha: 0.18),
      );
      canvas.drawCircle(point, 3.0, Paint()..color = success);
    }
    final maxYears = buckets.last.maxYears;
    final avgX =
        chart.left + (averageYears / maxYears).clamp(0.0, 1.0) * chart.width;
    _drawDashedVerticalLine(
      canvas,
      avgX,
      chart.top,
      chart.bottom,
      Paint()
        ..color = warning.withValues(alpha: 0.72)
        ..strokeWidth = 1.2,
    );
    final labelAlign =
        avgX > chart.center.dx ? TextAlign.right : TextAlign.left;
    final labelOffset = Offset(
      avgX + (labelAlign == TextAlign.right ? -5 : 5),
      chart.top + 8,
    );
    _paintSmallLabel(
      canvas,
      'maturité moyenne',
      labelOffset,
      warning,
      labelAlign,
    );
    if (hoverIndex != null) {
      final bucket = buckets[hoverIndex];
      _paintChartTooltip(
        canvas,
        [
          bucket.label,
          _marketReadableMoney(bucket.amount),
          'Maturité max ${bucket.maxYears.toStringAsFixed(0)} ans',
        ],
        hoverPosition!,
        chart,
        bucket.color,
        isDark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BondMaturityHistogramPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.averageYears != averageYears ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.isDark != isDark;
  }
}

String _marketAxisMdAmount(double value) {
  final amount = _marketAmountInBillions(value);
  if (amount.abs() < 0.005) return '0';
  return '${_marketMoneyNumber(amount)} Md';
}

class _BondCouponCurvePainter extends CustomPainter {
  const _BondCouponCurvePainter({
    required this.buckets,
    required this.color,
    required this.warning,
    required this.muted,
    required this.text,
    required this.isDark,
    this.hoverPosition,
    this.hoverProgress = 0,
  });

  final List<_BondCouponBucket> buckets;
  final Color color;
  final Color warning;
  final Color muted;
  final Color text;
  final bool isDark;
  final Offset? hoverPosition;
  final double hoverProgress;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const bottom = 34.0;
    const top = 10.0;
    final chart = Rect.fromLTWH(
      left,
      top,
      math.max(1, size.width - left - 10),
      math.max(1, size.height - top - bottom),
    );
    final axis = Paint()
      ..color = muted.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(chart.left, chart.bottom),
        Offset(chart.right, chart.bottom), axis);
    canvas.drawLine(
        Offset(chart.left, chart.top), Offset(chart.left, chart.bottom), axis);

    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = chart.top + chart.height * fraction;
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        Paint()
          ..color =
              (isDark ? Colors.white : _marketBorder).withValues(alpha: 0.45)
          ..strokeWidth = 0.7,
      );
    }

    if (buckets.isEmpty) return;
    final maxAmount =
        buckets.map((bucket) => bucket.amount).fold<double>(0, math.max);
    final maxCoupon = math.max(
      0.01,
      buckets.map((bucket) => bucket.weightedCoupon).fold<double>(0, math.max),
    );
    final yMax = math.max(0.01, maxCoupon * 1.20);
    const gap = 12.0;
    final barWidth =
        (chart.width - gap * (buckets.length - 1)) / buckets.length;
    final points = <Offset>[];
    final hoverIndex = hoverPosition != null && chart.contains(hoverPosition!)
        ? (((hoverPosition!.dx - chart.left) / chart.width) * buckets.length)
            .floor()
            .clamp(0, buckets.length - 1)
            .toInt()
        : null;

    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      final x = chart.left + index * (barWidth + gap);
      final centerX = x + barWidth / 2;
      final amountRatio = maxAmount <= 0 ? 0.0 : bucket.amount / maxAmount;
      final barHeight = math.max(3.0, chart.height * amountRatio);
      final isHovered = hoverIndex == index;
      final animatedHeight = math.min(
        chart.height,
        barHeight + (isHovered ? 8 * hoverProgress : 0),
      );
      final rect = Rect.fromLTWH(
        x,
        chart.bottom - animatedHeight,
        barWidth,
        animatedHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bucket.color.withValues(alpha: isHovered ? 0.62 : 0.42),
              bucket.color.withValues(alpha: 0.08),
            ],
          ).createShader(rect),
      );

      final couponY = chart.bottom -
          (bucket.weightedCoupon / yMax).clamp(0.0, 1.0) * chart.height;
      points.add(Offset(centerX, couponY));
      _paintSmallLabel(
        canvas,
        bucket.label,
        Offset(centerX, size.height - 10),
        text,
        TextAlign.center,
      );
      _paintSmallLabel(
        canvas,
        AppFormatters.percent(bucket.weightedCoupon),
        Offset(centerX, couponY - 12),
        bucket.color,
        TextAlign.center,
      );
    }
    if (hoverIndex != null && hoverIndex < points.length) {
      final point = points[hoverIndex];
      canvas.drawLine(
        Offset(point.dx, chart.top),
        Offset(point.dx, chart.bottom),
        Paint()
          ..color = buckets[hoverIndex].color.withValues(alpha: 0.28)
          ..strokeWidth = 1.0,
      );
    }

    final path = Path();
    for (var index = 0; index < points.length; index++) {
      if (index == 0) {
        path.moveTo(points[index].dx, points[index].dy);
      } else {
        final previous = points[index - 1];
        final current = points[index];
        path.cubicTo(
          previous.dx + (current.dx - previous.dx) * 0.45,
          previous.dy,
          previous.dx + (current.dx - previous.dx) * 0.55,
          current.dy,
          current.dx,
          current.dy,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.18 + hoverProgress * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 + hoverProgress
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    for (var index = 0; index < points.length; index++) {
      final isHovered = hoverIndex == index;
      canvas.drawCircle(
        points[index],
        6 + (isHovered ? 3 * hoverProgress : 0),
        Paint()
          ..color = buckets[index].color.withValues(
                alpha: isHovered ? 0.22 : 0.16,
              ),
      );
      canvas.drawCircle(
        points[index],
        isHovered ? 4.8 : 4.2,
        Paint()
          ..color = buckets[index].color.withValues(
                alpha: isHovered ? 1.0 : 0.88,
              ),
      );
    }

    _paintSmallLabel(canvas, 'coupon pondéré',
        Offset(chart.left + 4, chart.top + 8), color, TextAlign.left);
    _paintSmallLabel(canvas, 'encours', Offset(chart.right - 2, chart.top + 8),
        warning, TextAlign.right);
    if (hoverIndex != null) {
      final bucket = buckets[hoverIndex];
      _paintChartTooltip(
        canvas,
        [
          bucket.label,
          'Coupon ${AppFormatters.percent(bucket.weightedCoupon)}',
          'Encours ${_marketReadableMoney(bucket.amount)}',
        ],
        hoverPosition!,
        chart,
        bucket.color,
        isDark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BondCouponCurvePainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.isDark != isDark;
  }
}

class _MarketConcentrationPanel extends StatelessWidget {
  const _MarketConcentrationPanel({required this.dataset});

  final MarketPortfolioDataset dataset;

  @override
  Widget build(BuildContext context) {
    final entries = _marketTopExposureEntries(dataset, limit: 5);
    final isBonds = dataset.portfolioType == MarketPortfolioType.bonds;
    return _MarketVisualPanel(
      title: isBonds ? 'Émetteurs obligataires' : 'Top lignes actions',
      subtitle: isBonds
          ? '${dataset.dominantIssuer} pèse ${AppFormatters.percent(dataset.concentrationRatio)}'
          : 'Top 5 par poids de marché',
      child: isBonds
          ? _MarketIssuerCardList(entries: entries)
          : _MarketEquityRankedBars(entries: entries),
    );
  }
}

class _MarketAllocationPanel extends StatelessWidget {
  const _MarketAllocationPanel({required this.dataset});

  final MarketPortfolioDataset dataset;

  @override
  Widget build(BuildContext context) {
    final isBonds = dataset.portfolioType == MarketPortfolioType.bonds;
    final entries = dataset.portfolioType == MarketPortfolioType.bonds
        ? _marketGroupedEntries(
            dataset,
            (record) => record.rating.isEmpty ? 'Non noté' : record.rating,
            limit: 5,
          )
        : _marketGroupedEntries(
            dataset,
            (record) => _marketRecordText(record, 'Secteur', 'Non renseigné'),
            limit: 5,
          );

    return _MarketVisualPanel(
      title: isBonds ? 'Structure de notation' : 'Répartition sectorielle',
      subtitle: isBonds
          ? 'Poids des qualités de crédit'
          : 'Poids des secteurs en valeur de marché',
      child: isBonds
          ? _MarketDonutBreakdown(entries: entries)
          : _MarketSectorTileGrid(entries: entries),
    );
  }
}

class _MarketIssuerCardList extends StatelessWidget {
  const _MarketIssuerCardList({required this.entries});

  final List<_MarketDistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 520
            ? constraints.maxWidth
            : (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < entries.length; index++)
              SizedBox(
                width: itemWidth,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: entries[index].color.withValues(alpha: 0.055),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: entries[index].color.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: entries[index].color.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: entries[index].color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entries[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: text,
                                fontSize: 11.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _marketCompactMoney(entries[index].amount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted,
                                fontSize: 9.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppFormatters.percent(entries[index].share),
                        style: TextStyle(
                          color: entries[index].color,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MarketEquityRankedBars extends StatelessWidget {
  const _MarketEquityRankedBars({required this.entries});

  final List<_MarketDistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final border = _marketBorderFor(context);
    final isDark = _isMarketDark(context);
    final maxShare = entries.fold<double>(
      0,
      (max, entry) => math.max(max, entry.share),
    );

    return SizedBox(
      height: 168,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: index == 0
                      ? _marketPrimary.withValues(alpha: isDark ? 0.11 : 0.055)
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: border.withValues(
                        alpha: index == entries.length - 1 ? 0 : 0.56,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: index == 0 ? _marketPrimary : muted,
                          fontSize: 9.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        entries[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 9.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _marketPrimary.withValues(
                                alpha: isDark ? 0.13 : 0.075,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: maxShare <= 0
                                ? 0
                                : (entries[index].share / maxShare)
                                    .clamp(0.025, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: _marketPrimary.withValues(
                                  alpha: index == 0 ? 0.88 : 0.58,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      child: Text(
                        AppFormatters.percent(entries[index].share),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: index == 0 ? _marketPrimary : muted,
                          fontSize: 9.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index != entries.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _MarketDonutBreakdown extends StatefulWidget {
  const _MarketDonutBreakdown({required this.entries});

  final List<_MarketDistributionEntry> entries;

  @override
  State<_MarketDonutBreakdown> createState() => _MarketDonutBreakdownState();
}

class _MarketDonutBreakdownState extends State<_MarketDonutBreakdown> {
  Offset? _hoverPosition;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final dominant = widget.entries.isEmpty ? null : widget.entries.first;
    final dominantShare = dominant?.share ?? 0;
    final concentrationLabel = dominantShare >= 0.40
        ? 'Part élevée'
        : dominantShare >= 0.25
            ? 'Dominant'
            : 'Diffus';
    final concentrationColor =
        dominantShare >= 0.40 ? _marketWarning : dominant?.color ?? muted;

    return Row(
      children: [
        SizedBox(
          width: 118,
          height: 118,
          child: MouseRegion(
            onHover: (event) {
              setState(() => _hoverPosition = event.localPosition);
            },
            onExit: (_) => setState(() => _hoverPosition = null),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: _hoverPosition == null ? 0 : 1,
              ),
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              builder: (context, hoverProgress, child) {
                return CustomPaint(
                  foregroundPainter: _MarketDonutPainter(
                    entries: widget.entries,
                    track: _marketBorderFor(context).withValues(alpha: 0.45),
                    hoverPosition: _hoverPosition,
                    hoverProgress: hoverProgress,
                    isDark: _isMarketDark(context),
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dominant == null
                          ? '-'
                          : AppFormatters.percent(dominant.share),
                      style: TextStyle(
                        color: dominant?.color ?? muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: concentrationColor.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: Text(
                        concentrationLabel,
                        style: TextStyle(
                          color: concentrationColor,
                          fontSize: 6.8,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final entry in widget.entries) ...[
                Tooltip(
                  message:
                      '${entry.label}\n${AppFormatters.percent(entry.share)}\n${_marketReadableMoney(entry.amount)}',
                  waitDuration: const Duration(milliseconds: 220),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: entry.color,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: text,
                            fontSize: 10.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        AppFormatters.percent(entry.share),
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry != widget.entries.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketSectorTileGrid extends StatelessWidget {
  const _MarketSectorTileGrid({required this.entries});

  final List<_MarketDistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 520
            ? constraints.maxWidth
            : (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: entry.color.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: entry.color,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            entry.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: text,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppFormatters.percent(entry.share),
                          style: TextStyle(
                            color: entry.color,
                            fontSize: 11.4,
                            fontWeight: FontWeight.w800,
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
    );
  }
}

class _MarketDonutPainter extends CustomPainter {
  const _MarketDonutPainter({
    required this.entries,
    required this.track,
    required this.isDark,
    this.hoverPosition,
    this.hoverProgress = 0,
  });

  final List<_MarketDistributionEntry> entries;
  final Color track;
  final bool isDark;
  final Offset? hoverPosition;
  final double hoverProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 23.0;
    const segmentGap = 0.034;
    final radius = math.min(size.width, size.height) / 2 - 15;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    int? hoveredIndex;
    if (hoverPosition != null && entries.isNotEmpty) {
      final distance = (hoverPosition! - center).distance;
      final inRing = distance >= radius - strokeWidth / 2 - 8 &&
          distance <= radius + strokeWidth / 2 + 8;
      if (inRing) {
        var angle = math.atan2(
                hoverPosition!.dy - center.dy, hoverPosition!.dx - center.dx) +
            math.pi / 2;
        while (angle < 0) {
          angle += math.pi * 2;
        }
        while (angle >= math.pi * 2) {
          angle -= math.pi * 2;
        }
        var cursor = 0.0;
        for (var index = 0; index < entries.length; index++) {
          final sweep = math.max(0.035, entries[index].share * math.pi * 2);
          if (angle >= cursor && angle <= cursor + sweep) {
            hoveredIndex = index;
            break;
          }
          cursor += sweep;
        }
      }
    }

    final segmentPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    var start = -math.pi / 2;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final isHovered = hoveredIndex == index;
      final sweep = math.max(0.035, entry.share * math.pi * 2);
      final visibleSweep = math.max(0.001, sweep - segmentGap);
      if (isHovered) {
        canvas.drawArc(
          rect,
          start + segmentGap / 2,
          visibleSweep,
          false,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 8 * hoverProgress
            ..strokeCap = StrokeCap.butt
            ..color = entry.color.withValues(alpha: 0.18),
        );
      }
      segmentPaint
        ..strokeWidth = strokeWidth + (isHovered ? 4 * hoverProgress : 0)
        ..color = entry.color.withValues(alpha: isHovered ? 1.0 : 0.94);
      canvas.drawArc(
        rect,
        start + segmentGap / 2,
        visibleSweep,
        false,
        segmentPaint,
      );
      start += sweep;
    }
    if (hoveredIndex != null && hoverPosition != null) {
      final entry = entries[hoveredIndex];
      _paintChartTooltip(
        canvas,
        [
          entry.label,
          AppFormatters.percent(entry.share),
          _marketReadableMoney(entry.amount),
        ],
        hoverPosition!,
        Offset.zero & size,
        entry.color,
        isDark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarketDonutPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.track != track ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.isDark != isDark;
  }
}

class _MarketScenarioRiskPanel extends StatelessWidget {
  const _MarketScenarioRiskPanel({required this.dataset});

  final MarketPortfolioDataset dataset;

  @override
  Widget build(BuildContext context) {
    final returns = dataset.scenarioReturns;
    final var99 = dataset.scenarioVar99;
    final worst = dataset.scenarioWorstLoss;

    return _MarketVisualPanel(
      title: dataset.portfolioType == MarketPortfolioType.bonds
          ? 'Pertes obligataires simulées'
          : 'Chocs actions simulés',
      subtitle:
          'VaR 99% ${_marketCompactMoney(var99)} · perte max ${_marketCompactMoney(worst)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 92,
            child: CustomPaint(
              painter: _MarketScenarioSparkPainter(
                returns: returns,
                color: dataset.portfolioType == MarketPortfolioType.bonds
                    ? _marketPrimary
                    : _marketSuccess,
                danger: _marketDanger,
                isDark: _isMarketDark(context),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MarketMicroMetric(
                  label: 'VaR 99%',
                  value: _marketCompactMoney(var99),
                  color: _marketDanger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MarketMicroMetric(
                  label: 'Pire perte',
                  value: _marketCompactMoney(worst),
                  color: _marketWarning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketRiskSignalPanel extends StatelessWidget {
  const _MarketRiskSignalPanel({required this.dataset});

  final MarketPortfolioDataset dataset;

  @override
  Widget build(BuildContext context) {
    final isBonds = dataset.portfolioType == MarketPortfolioType.bonds;

    return _MarketVisualPanel(
      title: isBonds ? 'Maturité et portage' : 'Profil bêta / rendement',
      subtitle: isBonds
          ? '${dataset.weightedResidualYears.toStringAsFixed(1).replaceAll('.', ',')} ans pondérés · coupon ${AppFormatters.percent(dataset.averageCoupon)}'
          : 'Bêta ${dataset.weightedBeta.toStringAsFixed(2).replaceAll('.', ',')} · rendement ${AppFormatters.percent(dataset.expectedReturn)}',
      child: Column(
        children: [
          SizedBox(
            height: 104,
            child: CustomPaint(
              painter: isBonds
                  ? _MarketMaturityLadderPainter(
                      records: dataset.records,
                      color: _marketPrimary,
                      muted: _marketBorderFor(context),
                      text: _marketMutedFor(context),
                    )
                  : _MarketEquityScatterPainter(
                      records: dataset.records,
                      color: _marketSuccess,
                      danger: _marketDanger,
                      muted: _marketBorderFor(context),
                      text: _marketMutedFor(context),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          _MarketRiskTileGrid(
            items: isBonds
                ? [
                    _MarketRiskTileData(
                      label: 'Volatilité',
                      value: AppFormatters.percent(
                        dataset.annualizedVolatility,
                      ),
                      color: _marketCyan,
                    ),
                    _MarketRiskTileData(
                      label: 'Concentration',
                      value: AppFormatters.percent(dataset.concentrationRatio),
                      color: _marketWarning,
                    ),
                    _MarketRiskTileData(
                      label: 'Corrélation',
                      value: dataset.correlationProxy
                          .toStringAsFixed(2)
                          .replaceAll('.', ','),
                      color: _marketViolet,
                    ),
                    _MarketRiskTileData(
                      label: 'Maturité',
                      value:
                          '${dataset.weightedResidualYears.toStringAsFixed(1).replaceAll('.', ',')} ans',
                      color: _marketPrimary,
                    ),
                  ]
                : [
                    _MarketRiskTileData(
                      label: 'Volatilité',
                      value: AppFormatters.percent(
                        dataset.annualizedVolatility,
                      ),
                      color: _marketCyan,
                    ),
                    _MarketRiskTileData(
                      label: 'Bêta pondéré',
                      value: dataset.weightedBeta
                          .toStringAsFixed(2)
                          .replaceAll('.', ','),
                      color: _marketPrimary,
                    ),
                    _MarketRiskTileData(
                      label: 'Rendement',
                      value: AppFormatters.percent(dataset.expectedReturn),
                      color: _marketSuccess,
                    ),
                    _MarketRiskTileData(
                      label: 'Corrélation',
                      value: dataset.correlationProxy
                          .toStringAsFixed(2)
                          .replaceAll('.', ','),
                      color: _marketViolet,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _MarketRiskTileData {
  const _MarketRiskTileData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _MarketRiskTileGrid extends StatelessWidget {
  const _MarketRiskTileGrid({
    required this.items,
    this.columns,
    this.itemHeight,
    this.compact = false,
  });

  final List<_MarketRiskTileData> items;
  final int? columns;
  final double? itemHeight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = compact ? 5.0 : 6.0;
        final resolvedColumns =
            (columns ?? (constraints.maxWidth >= 240 ? 2 : 1))
                .clamp(1, math.max(1, items.length));
        final rows = (items.length / resolvedColumns).ceil();
        final width = (constraints.maxWidth - gap * (resolvedColumns - 1)) /
            resolvedColumns;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : rows * 54 + gap * (rows - 1);
        final height = itemHeight ??
            ((maxHeight - gap * (rows - 1)) / rows).clamp(48.0, 58.0);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.color.withValues(
                      alpha: _isMarketDark(context) ? 0.13 : 0.055,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 7 : 8,
                      vertical: compact ? 5 : 7,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: compact ? 2.4 : 3,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.label.tr(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: compact ? 8.2 : 8.7,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              SizedBox(height: compact ? 3 : 4),
                              Text(
                                item.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: text,
                                  fontSize: compact ? 10.8 : 12.0,
                                  fontWeight: FontWeight.w800,
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
              ),
          ],
        );
      },
    );
  }
}

class _MarketMaturityLadderPainter extends CustomPainter {
  const _MarketMaturityLadderPainter({
    required this.records,
    required this.color,
    required this.muted,
    required this.text,
  });

  final List<MarketPortfolioRecord> records;
  final Color color;
  final Color muted;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final buckets = List<double>.filled(5, 0);
    for (final record in records) {
      final years = _bondMaturityYears(record);
      final index = years < 1
          ? 0
          : years < 3
              ? 1
              : years < 5
                  ? 2
                  : years < 7
                      ? 3
                      : 4;
      buckets[index] += math.max(0, record.exposureAmount);
    }
    final maxValue = buckets.fold<double>(0, math.max);
    const chartTop = 8.0;
    final chartBottom = size.height - 22;
    final chartHeight = math.max(1.0, chartBottom - chartTop);
    const gap = 12.0;
    final barWidth = (size.width - gap * (buckets.length - 1)) / buckets.length;
    final labels = ['<1A', '1-3A', '3-5A', '5-7A', '>7A'];

    final grid = Paint()
      ..color = muted.withValues(alpha: 0.42)
      ..strokeWidth = 0.8;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = chartTop + chartHeight * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var index = 0; index < buckets.length; index++) {
      final x = index * (barWidth + gap);
      final ratio = maxValue <= 0 ? 0.0 : buckets[index] / maxValue;
      final height = math.max(4.0, chartHeight * ratio);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartBottom - height, barWidth, height),
        const Radius.circular(4),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.88),
            color.withValues(alpha: 0.20),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
      _paintSmallLabel(
        canvas,
        labels[index],
        Offset(x + barWidth / 2, size.height - 13),
        text,
        TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarketMaturityLadderPainter oldDelegate) {
    return oldDelegate.records != records ||
        oldDelegate.color != color ||
        oldDelegate.muted != muted ||
        oldDelegate.text != text;
  }
}

class _MarketEquityScatterPainter extends CustomPainter {
  const _MarketEquityScatterPainter({
    required this.records,
    required this.color,
    required this.danger,
    required this.muted,
    required this.text,
  });

  final List<MarketPortfolioRecord> records;
  final Color color;
  final Color danger;
  final Color muted;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = muted.withValues(alpha: 0.50)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(0, size.height - 18),
      Offset(size.width, size.height - 18),
      axis,
    );
    canvas.drawLine(const Offset(20, 0), Offset(20, size.height - 18), axis);

    if (records.isEmpty) return;
    final maxExposure = records
        .map((record) => record.exposureAmount)
        .fold<double>(0, math.max);
    final sample = records.length > 90 ? records.take(90) : records;
    for (final record in sample) {
      final beta = (record.beta > 0 ? record.beta : 1.0).clamp(0.45, 2.2);
      final expectedReturn =
          (record.expectedReturnInput != 0 ? record.expectedReturnInput : 0.055)
              .clamp(-0.08, 0.28);
      final x = 20 + ((beta - 0.45) / 1.75) * (size.width - 28);
      final y = (size.height - 22) -
          ((expectedReturn + 0.08) / 0.36) * (size.height - 30);
      final radius = maxExposure <= 0
          ? 4.5
          : (4 + (record.exposureAmount / maxExposure) * 8).clamp(4.0, 12.0);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = (beta > 1.25 ? danger : color).withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = (beta > 1.25 ? danger : color).withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    _paintSmallLabel(canvas, 'bêta', Offset(size.width - 14, size.height - 8),
        text, TextAlign.right);
    _paintSmallLabel(
        canvas, 'rend.', const Offset(22, 8), text, TextAlign.left);
  }

  @override
  bool shouldRepaint(covariant _MarketEquityScatterPainter oldDelegate) {
    return oldDelegate.records != records ||
        oldDelegate.color != color ||
        oldDelegate.danger != danger ||
        oldDelegate.muted != muted ||
        oldDelegate.text != text;
  }
}

void _paintSmallLabel(
  Canvas canvas,
  String label,
  Offset offset,
  Color color,
  TextAlign align,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontSize: 8.5,
        fontWeight: FontWeight.w600,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 80);
  final dx = switch (align) {
    TextAlign.center => offset.dx - painter.width / 2,
    TextAlign.right => offset.dx - painter.width,
    _ => offset.dx,
  };
  painter.paint(canvas, Offset(dx, offset.dy - painter.height / 2));
}

void _paintChartTooltip(
  Canvas canvas,
  List<String> lines,
  Offset anchor,
  Rect bounds,
  Color accent,
  bool isDark,
) {
  if (lines.isEmpty) return;
  final painters = <TextPainter>[];
  for (var index = 0; index < lines.length; index++) {
    final painter = TextPainter(
      text: TextSpan(
        text: lines[index],
        style: TextStyle(
          color: index == 0
              ? accent
              : (isDark ? const Color(0xFFEAF2FF) : const Color(0xFF13203A)),
          fontSize: index == 0 ? 8.8 : 8.2,
          fontWeight: index == 0 ? FontWeight.w700 : FontWeight.w500,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 150);
    painters.add(painter);
  }

  final width =
      painters.fold<double>(0, (max, painter) => math.max(max, painter.width)) +
          18;
  final height =
      painters.fold<double>(0, (sum, painter) => sum + painter.height) + 14;
  var left = anchor.dx + 12;
  var top = anchor.dy - height - 10;
  if (left + width > bounds.right) left = anchor.dx - width - 12;
  if (left < bounds.left) left = bounds.left + 4;
  if (top < bounds.top) top = anchor.dy + 12;
  if (top + height > bounds.bottom) top = bounds.bottom - height - 4;

  final rect = Rect.fromLTWH(left, top, width, height);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(3)),
    Paint()
      ..color = isDark
          ? const Color(0xFF0F1B31).withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.96),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(3)),
    Paint()
      ..color = accent.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
  );

  var dy = top + 7;
  for (final painter in painters) {
    painter.paint(canvas, Offset(left + 9, dy));
    dy += painter.height;
  }
}

class _MarketVisualPanel extends StatelessWidget {
  const _MarketVisualPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _marketSurfaceSoftFor(context)
            .withValues(alpha: _isMarketDark(context) ? 0.50 : 0.72),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _marketBorderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: text,
              fontSize: 13.2,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted,
              fontSize: 10.2,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MarketDistributionEntry {
  const _MarketDistributionEntry({
    required this.label,
    required this.amount,
    required this.share,
    required this.color,
  });

  final String label;
  final double amount;
  final double share;
  final Color color;
}

class _MarketMicroMetric extends StatelessWidget {
  const _MarketMicroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _marketMutedFor(context),
              fontSize: 9.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketScenarioSparkPainter extends CustomPainter {
  const _MarketScenarioSparkPainter({
    required this.returns,
    required this.color,
    required this.danger,
    required this.isDark,
  });

  final List<double> returns;
  final Color color;
  final Color danger;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : _marketBorder).withValues(alpha: 0.42)
      ..strokeWidth = 0.7;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (returns.length < 2) return;
    final sample = returns.length > 180
        ? [
            for (var index = 0; index < 180; index++)
              returns[(index * (returns.length - 1) / 179).round()]
          ]
        : returns;
    final minValue = sample.reduce(math.min);
    final maxValue = sample.reduce(math.max);
    final span =
        (maxValue - minValue).abs() < 0.000001 ? 0.000001 : maxValue - minValue;

    final path = Path();
    for (var index = 0; index < sample.length; index++) {
      final x =
          sample.length == 1 ? 0.0 : index / (sample.length - 1) * size.width;
      final y = size.height - ((sample[index] - minValue) / span) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.16),
          color.withValues(alpha: 0.01),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final zeroY = size.height - ((0 - minValue) / span) * size.height;
    if (zeroY >= 0 && zeroY <= size.height) {
      canvas.drawLine(
        Offset(0, zeroY),
        Offset(size.width, zeroY),
        Paint()
          ..color = danger.withValues(alpha: 0.28)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarketScenarioSparkPainter oldDelegate) {
    return oldDelegate.returns != returns ||
        oldDelegate.color != color ||
        oldDelegate.danger != danger ||
        oldDelegate.isDark != isDark;
  }
}

List<_MarketAnalyticKpiSpec> _marketAnalyticKpis(
  MarketPortfolioDataset dataset,
) {
  final isBonds = dataset.portfolioType == MarketPortfolioType.bonds;
  return [
    _MarketAnalyticKpiSpec(
      label: isBonds ? 'Exposition totale' : 'Valeur de marché',
      value: _marketReadableMoney(dataset.totalExposure),
      color: _marketPrimary,
      icon: CupertinoIcons.money_dollar_circle_fill,
    ),
    _MarketAnalyticKpiSpec(
      label: isBonds ? 'Émetteur dominant' : 'Position dominante',
      value: dataset.dominantIssuer,
      color: _marketWarning,
      icon: CupertinoIcons.person_2_fill,
    ),
    _MarketAnalyticKpiSpec(
      label: isBonds ? 'Maturité pondérée' : 'Bêta pondéré',
      value: isBonds
          ? '${dataset.weightedResidualYears.toStringAsFixed(1).replaceAll('.', ',')} ans'
          : dataset.weightedBeta.toStringAsFixed(2).replaceAll('.', ','),
      color: _marketViolet,
      icon: CupertinoIcons.time_solid,
    ),
    _MarketAnalyticKpiSpec(
      label: isBonds ? 'Coupon moyen' : 'Rendement attendu',
      value: AppFormatters.percent(
        isBonds ? dataset.averageCoupon : dataset.expectedReturn,
      ),
      color: _marketSuccess,
      icon: CupertinoIcons.percent,
    ),
    _MarketAnalyticKpiSpec(
      label: 'Volatilité',
      value: AppFormatters.percent(dataset.annualizedVolatility),
      color: _marketCyan,
      icon: CupertinoIcons.waveform_path_ecg,
    ),
    _MarketAnalyticKpiSpec(
      label: 'Corrélation',
      value: dataset.correlationProxy.toStringAsFixed(2).replaceAll('.', ','),
      color: _marketDanger,
      icon: CupertinoIcons.link_circle_fill,
    ),
  ];
}

List<_MarketDistributionEntry> _bondGroupedEntries(
  MarketPortfolioDataset dataset,
  String Function(MarketPortfolioRecord record) labelOf, {
  required int limit,
}) {
  const colors = [
    _marketPrimary,
    _marketCyan,
    _marketViolet,
    _marketWarning,
    _marketSuccess,
    _marketDanger,
    Color(0xFF0F766E),
    Color(0xFF475569),
  ];
  final total = dataset.records.fold<double>(
    0,
    (sum, record) => sum + math.max(0.0, _bondOutstandingCapitalValue(record)),
  );
  if (dataset.records.isEmpty || total <= 0) {
    return const [
      _MarketDistributionEntry(
        label: 'Non disponible',
        amount: 0,
        share: 0,
        color: _marketMuted,
      ),
    ];
  }
  final grouped = <String, double>{};
  for (final record in dataset.records) {
    final exposure = math.max(0.0, _bondOutstandingCapitalValue(record));
    if (exposure <= 0) continue;
    final label = labelOf(record).trim();
    final key = label.isEmpty ? 'Non renseigné' : label;
    grouped.update(key, (value) => value + exposure, ifAbsent: () => exposure);
  }
  final ranked = grouped.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return [
    for (var index = 0; index < math.min(limit, ranked.length); index++)
      _MarketDistributionEntry(
        label: ranked[index].key,
        amount: ranked[index].value,
        share: total <= 0 ? 0 : ranked[index].value / total,
        color: colors[index % colors.length],
      ),
  ];
}

String _bondRatingLabel(MarketPortfolioRecord record) {
  final candidates = [
    record.rating,
    _marketRecordText(record, 'Notation externe_S&P', ''),
    _marketRecordText(record, 'Notation externe_Moody\'s', ''),
    _marketRecordText(record, 'Notation externe_Fitch', ''),
    _marketRecordText(record, 'Notation Interne', ''),
  ];
  for (final candidate in candidates) {
    final normalized = candidate.trim();
    if (normalized.isNotEmpty && normalized != '-') return normalized;
  }
  return 'Non noté';
}

String _bondZoneLabel(MarketPortfolioRecord record) {
  final raw = record.zone.trim().toLowerCase();
  if (raw.contains('uem')) return 'UEMOA';
  if (raw.contains('cem')) return 'CEMAC';
  if (raw.contains('hors')) return 'Hors Zone';
  if (raw.contains('zone') || raw.isEmpty || raw == 'non renseignée') {
    return 'Hors Zone';
  }
  return 'Hors Zone';
}

List<_MarketDistributionEntry> _orderedZoneEntries(
  List<_MarketDistributionEntry> entries,
) {
  const colors = {
    'UEMOA': _marketPrimary,
    'CEMAC': _marketCyan,
    'Hors Zone': _marketViolet,
  };
  final byLabel = {for (final entry in entries) entry.label: entry};
  return [
    for (final label in const ['UEMOA', 'CEMAC', 'Hors Zone'])
      _MarketDistributionEntry(
        label: label,
        amount: byLabel[label]?.amount ?? 0,
        share: byLabel[label]?.share ?? 0,
        color: colors[label]!,
      ),
  ];
}

double _bondCouponFraction(double rawCoupon) {
  if (rawCoupon <= 0) return 0;
  return rawCoupon > 1 ? rawCoupon / 100 : rawCoupon;
}

double _bondOutstandingCapitalValue(MarketPortfolioRecord record) {
  return record.resolvedCapitalRemainingDue;
}

double _bondMaturityYears(MarketPortfolioRecord record) {
  final months = _bondMaturityMonths(record);
  if (months > 0) return months / 12;
  return 0;
}

double _bondMaturityMonths(MarketPortfolioRecord record) {
  final importedMonths = record.residualMaturityMonths;
  return _bondMonthCount(importedMonths);
}

double _bondTotalMaturityMonths(MarketPortfolioRecord record) {
  return _bondMonthCount(record.maturityMonths);
}

double _bondMonthCount(double raw) {
  if (!raw.isFinite || raw <= 0) return 0;
  final rounded = raw.roundToDouble();
  if ((raw - rounded).abs() < 0.000001) return rounded;
  return raw.ceilToDouble();
}

List<_BondMaturityBucket> _bondMaturityBuckets(
  MarketPortfolioDataset dataset,
) {
  final buckets = [
    const _BondMaturityBucket(
      label: '<1A',
      minYears: 0,
      maxYears: 1,
      amount: 0,
      color: _marketSuccess,
    ),
    const _BondMaturityBucket(
      label: '1-3A',
      minYears: 1,
      maxYears: 3,
      amount: 0,
      color: _marketCyan,
    ),
    const _BondMaturityBucket(
      label: '3-5A',
      minYears: 3,
      maxYears: 5,
      amount: 0,
      color: _marketPrimary,
    ),
    const _BondMaturityBucket(
      label: '5-7A',
      minYears: 5,
      maxYears: 7,
      amount: 0,
      color: _marketViolet,
    ),
    const _BondMaturityBucket(
      label: '>7A',
      minYears: 7,
      maxYears: 12,
      amount: 0,
      color: _marketWarning,
    ),
  ];
  final amounts = List<double>.filled(buckets.length, 0);
  for (final record in dataset.records) {
    final years = _bondMaturityYears(record);
    final index = years < 1
        ? 0
        : years < 3
            ? 1
            : years < 5
                ? 2
                : years < 7
                    ? 3
                    : 4;
    amounts[index] += math.max(0, record.exposureAmount);
  }
  return [
    for (var index = 0; index < buckets.length; index++)
      _BondMaturityBucket(
        label: buckets[index].label,
        minYears: buckets[index].minYears,
        maxYears: buckets[index].maxYears,
        amount: amounts[index],
        color: buckets[index].color,
      ),
  ];
}

List<_BondCouponBucket> _bondCouponBuckets(MarketPortfolioDataset dataset) {
  const labels = ['<1A', '1-3A', '3-5A', '5-7A', '>7A'];
  const colors = [
    _marketSuccess,
    _marketCyan,
    _marketPrimary,
    _marketViolet,
    _marketWarning,
  ];
  final amounts = List<double>.filled(labels.length, 0);
  final couponNumerators = List<double>.filled(labels.length, 0);

  for (final record in dataset.records) {
    final exposure = math.max(0.0, record.exposureAmount);
    if (exposure <= 0) continue;
    final years = _bondMaturityYears(record);
    final index = years < 1
        ? 0
        : years < 3
            ? 1
            : years < 5
                ? 2
                : years < 7
                    ? 3
                    : 4;
    amounts[index] += exposure;
    couponNumerators[index] += _bondCouponFraction(record.coupon) * exposure;
  }

  return [
    for (var index = 0; index < labels.length; index++)
      _BondCouponBucket(
        label: labels[index],
        amount: amounts[index],
        weightedCoupon:
            amounts[index] <= 0 ? 0 : couponNumerators[index] / amounts[index],
        color: colors[index],
      ),
  ];
}

List<_MarketDistributionEntry> _marketTopExposureEntries(
  MarketPortfolioDataset dataset, {
  required int limit,
}) {
  return _marketGroupedEntries(
    dataset,
    (record) => record.issuer,
    limit: limit,
  );
}

List<_MarketDistributionEntry> _marketGroupedEntries(
  MarketPortfolioDataset dataset,
  String Function(MarketPortfolioRecord record) labelOf, {
  required int limit,
}) {
  const colors = [
    _marketPrimary,
    _marketCyan,
    _marketViolet,
    _marketWarning,
    _marketSuccess,
    _marketDanger,
  ];
  final total = dataset.totalExposure;
  if (dataset.records.isEmpty || total <= 0) {
    return [
      const _MarketDistributionEntry(
        label: 'Non disponible',
        amount: 0,
        share: 0,
        color: _marketMuted,
      ),
    ];
  }

  final grouped = <String, double>{};
  for (final record in dataset.records) {
    final label = labelOf(record).trim();
    final key = label.isEmpty ? 'Non renseigné' : label;
    grouped.update(
      key,
      (value) => value + record.exposureAmount,
      ifAbsent: () => record.exposureAmount,
    );
  }
  final ranked = grouped.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));

  return [
    for (var index = 0; index < math.min(limit, ranked.length); index++)
      _MarketDistributionEntry(
        label: ranked[index].key,
        amount: ranked[index].value,
        share: ranked[index].value / total,
        color: colors[index % colors.length],
      ),
  ];
}

String _marketRecordText(
  MarketPortfolioRecord record,
  String key,
  String fallback,
) {
  final value = record.values[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _marketCompactMoney(double value) {
  return _marketMoneyText(value, displayCurrency: 'XOF');
}

String _marketReadableMoney(double value) {
  return _marketMoneyText(value, displayCurrency: 'XOF');
}

String _marketShortXofAmount(double value) {
  return _marketMoneyText(value, displayCurrency: 'XOF');
}

extension _MarketTableSortKeyX on _MarketTableSortKey {
  String get label => switch (this) {
        _MarketTableSortKey.issuer => 'Émetteur',
        _MarketTableSortKey.country => 'Pays',
        _MarketTableSortKey.zone => 'Zone',
        _MarketTableSortKey.rating => 'Notation',
        _MarketTableSortKey.accountingIntent => 'Intention',
        _MarketTableSortKey.residualMaturity => 'Maturité résid.',
        _MarketTableSortKey.instrumentType => 'Type',
        _MarketTableSortKey.exposure => 'Exposition',
        _MarketTableSortKey.currency => 'Devise',
      };

  IconData get icon => switch (this) {
        _MarketTableSortKey.issuer => CupertinoIcons.building_2_fill,
        _MarketTableSortKey.country => CupertinoIcons.flag_fill,
        _MarketTableSortKey.zone => CupertinoIcons.globe,
        _MarketTableSortKey.rating => CupertinoIcons.star_fill,
        _MarketTableSortKey.accountingIntent => CupertinoIcons.briefcase_fill,
        _MarketTableSortKey.residualMaturity => CupertinoIcons.calendar,
        _MarketTableSortKey.instrumentType => CupertinoIcons.square_stack_3d_up,
        _MarketTableSortKey.exposure => CupertinoIcons.money_dollar_circle_fill,
        _MarketTableSortKey.currency => CupertinoIcons.arrow_2_circlepath,
      };
}

class _MarketPortfolioTableEntry {
  const _MarketPortfolioTableEntry({
    required this.index,
    required this.record,
  });

  final int index;
  final MarketPortfolioRecord record;
}

class _MarketDashboardDataTable extends StatelessWidget {
  const _MarketDashboardDataTable({
    required this.dataset,
    required this.selectedType,
    required this.onTypeChanged,
  });

  final MarketPortfolioDataset? dataset;
  final MarketPortfolioType selectedType;
  final ValueChanged<MarketPortfolioType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final records = dataset?.records ?? const <MarketPortfolioRecord>[];
    final portfolioType = dataset?.portfolioType ?? selectedType;

    return _MarketCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tableau des données'.tr(context),
                        style: TextStyle(
                          color: text,
                          fontSize: 14.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _MarketPortfolioTypeSwitch(
                  selectedType: selectedType,
                  onChanged: onTypeChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MarketPortfolioMetricStrip(
            dataset: dataset,
            selectedType: selectedType,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _MarketPortfolioDetailsTable(
              portfolioType: portfolioType,
              records: records,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketPortfolioTypeSwitch extends StatelessWidget {
  const _MarketPortfolioTypeSwitch({
    required this.selectedType,
    required this.onChanged,
  });

  final MarketPortfolioType selectedType;
  final ValueChanged<MarketPortfolioType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final border = _marketBorderFor(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF3F7FD),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MarketPortfolioTypeButton(
              type: MarketPortfolioType.bonds,
              selected: selectedType == MarketPortfolioType.bonds,
              onTap: () => onChanged(MarketPortfolioType.bonds),
            ),
            _MarketPortfolioTypeButton(
              type: MarketPortfolioType.equities,
              selected: selectedType == MarketPortfolioType.equities,
              onTap: () => onChanged(MarketPortfolioType.equities),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketPortfolioTypeButton extends StatelessWidget {
  const _MarketPortfolioTypeButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final MarketPortfolioType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final color =
        type == MarketPortfolioType.bonds ? _marketPrimary : _marketSuccess;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 30,
        width: 128,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == MarketPortfolioType.bonds
                  ? CupertinoIcons.doc_text_fill
                  : CupertinoIcons.chart_bar_alt_fill,
              size: 13,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 7),
            Text(
              type.label.tr(context),
              style: TextStyle(
                color: selected ? Colors.white : muted,
                fontSize: 9.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketPortfolioMetricStrip extends StatelessWidget {
  const _MarketPortfolioMetricStrip({
    required this.dataset,
    required this.selectedType,
  });

  final MarketPortfolioDataset? dataset;
  final MarketPortfolioType selectedType;

  @override
  Widget build(BuildContext context) {
    final records = dataset?.records ?? const <MarketPortfolioRecord>[];
    final portfolioType = dataset?.portfolioType ?? selectedType;
    final issuers = records.map((record) => record.issuer).toSet().length;
    final zones = records.map((record) => record.zone).toSet().length;
    final currencies = records.map((record) => record.currency).toSet().length;
    final residualYears = dataset?.weightedResidualYears ?? 0;
    final coupon = dataset?.averageCoupon ?? 0;
    final exposure = dataset?.totalExposure ?? 0;

    final cards = [
      _MarketPortfolioMetricData(
        label: portfolioType == MarketPortfolioType.bonds
            ? 'Lignes titres'
            : 'Lignes actions',
        value: AppFormatters.compactNumber(records.length),
        color: _marketPrimary,
        icon: CupertinoIcons.square_stack_3d_up_fill,
      ),
      _MarketPortfolioMetricData(
        label: 'Émetteurs',
        value: AppFormatters.compactNumber(issuers),
        color: _marketCyan,
        icon: CupertinoIcons.person_2_fill,
      ),
      _MarketPortfolioMetricData(
        label: 'Zones',
        value: AppFormatters.compactNumber(zones),
        color: _marketViolet,
        icon: CupertinoIcons.globe,
      ),
      _MarketPortfolioMetricData(
        label: 'Devises',
        value: AppFormatters.compactNumber(currencies),
        color: _marketSuccess,
        icon: CupertinoIcons.money_dollar_circle_fill,
      ),
      _MarketPortfolioMetricData(
        label: portfolioType == MarketPortfolioType.bonds
            ? 'Exposition totale'
            : 'Valeur de marché',
        value: _marketCompactMoney(exposure),
        color: _marketWarning,
        icon: CupertinoIcons.chart_bar_alt_fill,
      ),
      _MarketPortfolioMetricData(
        label: portfolioType == MarketPortfolioType.bonds
            ? 'Maturité pondérée'
            : 'Bêta pondéré',
        value: portfolioType == MarketPortfolioType.bonds
            ? '${residualYears.toStringAsFixed(1).replaceAll('.', ',')} ans'
            : residualYears.toStringAsFixed(2).replaceAll('.', ','),
        color: _marketDanger,
        icon: CupertinoIcons.time_solid,
      ),
      _MarketPortfolioMetricData(
        label: portfolioType == MarketPortfolioType.bonds
            ? 'Coupon moyen'
            : 'Volatilité',
        value: portfolioType == MarketPortfolioType.bonds
            ? AppFormatters.percent(coupon)
            : AppFormatters.percent(dataset?.annualizedVolatility ?? 0),
        color: _marketCyan,
        icon: CupertinoIcons.percent,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            _MarketPortfolioMetricCard(data: cards[index]),
            if (index < cards.length - 1) const SizedBox(width: 9),
          ],
        ],
      ),
    );
  }
}

class _MarketPortfolioMetricData {
  const _MarketPortfolioMetricData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _MarketPortfolioMetricCard extends StatelessWidget {
  const _MarketPortfolioMetricCard({required this.data});

  final _MarketPortfolioMetricData data;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final isDark = _isMarketDark(context);

    return Container(
      width: 156,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : data.color.withValues(alpha: 0.055),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(data.icon, size: 15, color: data.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.label.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 8.2,
                    fontWeight: FontWeight.w600,
                    height: 1,
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

class _MarketPortfolioDetailsTable extends StatefulWidget {
  const _MarketPortfolioDetailsTable({
    required this.portfolioType,
    required this.records,
  });

  final MarketPortfolioType portfolioType;
  final List<MarketPortfolioRecord> records;

  static const _rowHeight = 42.0;
  static const _headerHeight = 54.0;
  static const _actionsWidth = 96.0;

  @override
  State<_MarketPortfolioDetailsTable> createState() =>
      _MarketPortfolioDetailsTableState();
}

class _MarketPortfolioDetailsTableState
    extends State<_MarketPortfolioDetailsTable> {
  final _pinnedDataScrollController = ScrollController();
  final _dataScrollController = ScrollController();
  final _actionsScrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _syncingVerticalScroll = false;
  int? _selectedRowIndex;
  _MarketTableSortKey _sortKey = _MarketTableSortKey.issuer;
  String? _sortHeader;
  bool _sortAscending = true;
  final Map<MarketPortfolioType, Set<String>> _visibleColumnsByType = {};

  @override
  void initState() {
    super.initState();
    _pinnedDataScrollController.addListener(
      () => _syncVerticalScroll(
        _pinnedDataScrollController,
        _dataScrollController,
        _actionsScrollController,
      ),
    );
    _dataScrollController.addListener(
      () => _syncVerticalScroll(
        _dataScrollController,
        _pinnedDataScrollController,
        _actionsScrollController,
      ),
    );
    _actionsScrollController.addListener(
      () => _syncVerticalScroll(
        _actionsScrollController,
        _dataScrollController,
        _pinnedDataScrollController,
      ),
    );
  }

  @override
  void dispose() {
    _pinnedDataScrollController.dispose();
    _dataScrollController.dispose();
    _actionsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MarketPortfolioDetailsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portfolioType != widget.portfolioType ||
        (_selectedRowIndex != null &&
            _selectedRowIndex! >= widget.records.length)) {
      _selectedRowIndex = null;
    }
    if (oldWidget.portfolioType != widget.portfolioType) {
      _searchController.clear();
      _sortKey = _MarketTableSortKey.issuer;
      _sortHeader = null;
      _sortAscending = true;
    }
  }

  void _syncVerticalScroll(
    ScrollController source,
    ScrollController primaryTarget, [
    ScrollController? secondaryTarget,
  ]) {
    if (_syncingVerticalScroll || !source.hasClients) {
      return;
    }
    _syncingVerticalScroll = true;
    for (final target in [
      primaryTarget,
      if (secondaryTarget != null) secondaryTarget
    ]) {
      if (!target.hasClients) continue;
      final targetOffset = source.offset
          .clamp(
            target.position.minScrollExtent,
            target.position.maxScrollExtent,
          )
          .toDouble();
      if ((target.offset - targetOffset).abs() >= 0.5) {
        target.jumpTo(targetOffset);
      }
    }
    _syncingVerticalScroll = false;
  }

  Future<void> _editRecord(int index) async {
    if (index < 0 || index >= widget.records.length) return;
    setState(() => _selectedRowIndex = index);
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _MarketPortfolioEditDialog(
        portfolioType: widget.portfolioType,
        record: widget.records[index],
      ),
    );
    if (values == null || !mounted) return;
    MarketDataImportStore.instance.updateRecord(
      widget.portfolioType,
      index,
      values,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _marketPrimary,
        content: Text('Ligne mise à jour.'.tr(context)),
      ),
    );
  }

  Future<void> _addRecord() async {
    final emptyRecord = MarketPortfolioRecord(
      portfolioType: widget.portfolioType,
      values: {
        for (final header in widget.portfolioType.requiredHeaders) header: ''
      },
    );
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _MarketPortfolioEditDialog(
        portfolioType: widget.portfolioType,
        record: emptyRecord,
        title: 'Ajouter une ligne',
        confirmLabel: 'Ajouter',
      ),
    );
    if (values == null || !mounted) return;
    MarketDataImportStore.instance.addRecord(widget.portfolioType, values);
    setState(() => _selectedRowIndex = widget.records.length);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _marketSuccess,
        content: Text('Ligne ajoutée.'.tr(context)),
      ),
    );
  }

  Future<void> _deleteRecord(int index) async {
    if (index < 0 || index >= widget.records.length) return;
    setState(() => _selectedRowIndex = index);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          title: Text('Supprimer la ligne ?'.tr(context)),
          content: Text(
            'Cette ligne sera retirée du portefeuille importé localement.'
                .tr(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler'.tr(context)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _marketDanger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Supprimer'.tr(context)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    MarketDataImportStore.instance.removeRecord(widget.portfolioType, index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _marketDanger,
        content: Text('Ligne supprimée.'.tr(context)),
      ),
    );
  }

  Set<String> _visibleColumnSet(List<String> headers) {
    final available = headers.toSet();
    final selected = _visibleColumnsByType[widget.portfolioType];
    if (selected == null) {
      return _marketDefaultColumnSet(widget.portfolioType, headers);
    }
    final resolved = selected.where(available.contains).toSet();
    return resolved.isEmpty
        ? _marketDefaultColumnSet(widget.portfolioType, headers)
        : resolved;
  }

  List<_MarketPortfolioTableEntry> _visibleEntries(
    List<MarketPortfolioRecord> records,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final entries = <_MarketPortfolioTableEntry>[];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (query.isNotEmpty &&
          !record.values.values.any(
            (value) => value.toString().toLowerCase().contains(query),
          )) {
        continue;
      }
      entries.add(_MarketPortfolioTableEntry(index: index, record: record));
    }

    entries.sort((a, b) => _compareEntries(a, b));
    return entries;
  }

  int _compareEntries(
    _MarketPortfolioTableEntry left,
    _MarketPortfolioTableEntry right,
  ) {
    final sortHeader = _sortHeader;
    if (sortHeader != null) {
      final leftValue = left.record.values[sortHeader];
      final rightValue = right.record.values[sortHeader];
      final leftEmpty = _marketPortfolioSortValueIsEmpty(leftValue);
      final rightEmpty = _marketPortfolioSortValueIsEmpty(rightValue);
      if (leftEmpty || rightEmpty) {
        if (leftEmpty && rightEmpty) return left.index.compareTo(right.index);
        return leftEmpty ? 1 : -1;
      }
      final result = _compareMarketPortfolioHeaderValues(
        sortHeader,
        leftValue,
        rightValue,
      );
      final resolved = _sortAscending ? result : -result;
      return resolved == 0 ? left.index.compareTo(right.index) : resolved;
    }

    final result = switch (_sortKey) {
      _MarketTableSortKey.exposure => right.record.exposureAmount.compareTo(
          left.record.exposureAmount,
        ),
      _MarketTableSortKey.residualMaturity => _compareMarketNumbers(
          _bondMaturityYears(left.record),
          _bondMaturityYears(right.record),
        ),
      _MarketTableSortKey.rating => _compareMarketRatings(
          left.record.rating,
          right.record.rating,
        ),
      _ => _marketTableSortValue(left.record, _sortKey).toLowerCase().compareTo(
          _marketTableSortValue(right.record, _sortKey).toLowerCase()),
    };
    return result == 0 ? left.index.compareTo(right.index) : result;
  }

  void _handleHeaderSort(String header) {
    setState(() {
      if (_sortHeader == header) {
        _sortAscending = !_sortAscending;
        return;
      }
      _sortHeader = header;
      _sortAscending = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final border = _marketBorderFor(context);
    final allHeaders = widget.portfolioType.requiredHeaders;
    final visibleColumnSet = _visibleColumnSet(allHeaders);
    final headers =
        allHeaders.where(visibleColumnSet.contains).toList(growable: false);
    final pinnedHeader = widget.portfolioType == MarketPortfolioType.bonds &&
            headers.contains('ID Titre')
        ? 'ID Titre'
        : null;
    final scrollHeaders = pinnedHeader == null
        ? headers
        : headers.where((header) => header != pinnedHeader).toList(
              growable: false,
            );
    final records = widget.records;
    final visibleEntries = _visibleEntries(records);
    final totalWidth = scrollHeaders.fold<double>(
      0,
      (sum, header) => sum + _marketPortfolioColumnWidth(header),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MarketPortfolioTableToolbar(
            portfolioType: widget.portfolioType,
            sortKey: _sortKey,
            queryController: _searchController,
            allHeaders: allHeaders,
            visibleHeaders: visibleColumnSet,
            onSortChanged: (sortKey) => setState(() {
              _sortKey = sortKey;
              _sortHeader = null;
              _sortAscending = true;
            }),
            onQueryChanged: (_) => setState(() {}),
            onColumnsChanged: (values) {
              setState(() {
                _visibleColumnsByType[widget.portfolioType] = values;
              });
            },
            onAdd: _addRecord,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  color: _marketSurfaceFor(context),
                ),
                child: Row(
                  children: [
                    if (pinnedHeader != null)
                      _MarketPortfolioPinnedColumn(
                        header: pinnedHeader,
                        portfolioType: widget.portfolioType,
                        entries: visibleEntries,
                        hasRecords: records.isNotEmpty,
                        controller: _pinnedDataScrollController,
                        scrollTargetController: _dataScrollController,
                        sortHeader: _sortHeader,
                        sortAscending: _sortAscending,
                        selectedRowIndex: _selectedRowIndex,
                        onSort: _handleHeaderSort,
                        onSelect: (index) {
                          setState(() {
                            _selectedRowIndex =
                                _selectedRowIndex == index ? null : index;
                          });
                        },
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: totalWidth,
                          child: Column(
                            children: [
                              _MarketPortfolioHeaderRow(
                                headers: scrollHeaders,
                                portfolioType: widget.portfolioType,
                                sortHeader: _sortHeader,
                                sortAscending: _sortAscending,
                                onSort: _handleHeaderSort,
                              ),
                              if (records.isEmpty)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Importez un fichier GPO ${widget.portfolioType.label} conforme pour afficher les ${headers.length} colonnes du portefeuille.'
                                          .tr(context),
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 10.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              else if (visibleEntries.isEmpty)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Aucune ligne ne correspond aux filtres.'
                                          .tr(context),
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 10.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.builder(
                                    controller: _dataScrollController,
                                    primary: false,
                                    itemExtent:
                                        _MarketPortfolioDetailsTable._rowHeight,
                                    itemCount: visibleEntries.length,
                                    itemBuilder: (context, index) {
                                      final entry = visibleEntries[index];
                                      return _MarketPortfolioDataRow(
                                        record: entry.record,
                                        headers: scrollHeaders,
                                        selected:
                                            _selectedRowIndex == entry.index,
                                        alternate: index.isOdd,
                                        onTap: () {
                                          setState(() {
                                            _selectedRowIndex =
                                                _selectedRowIndex == entry.index
                                                    ? null
                                                    : entry.index;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _MarketPortfolioActionsColumn(
                      portfolioType: widget.portfolioType,
                      entries: visibleEntries,
                      hasRecords: records.isNotEmpty,
                      controller: _actionsScrollController,
                      scrollTargetController: _dataScrollController,
                      selectedRowIndex: _selectedRowIndex,
                      onEdit: _editRecord,
                      onDelete: _deleteRecord,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketPortfolioTableToolbar extends StatelessWidget {
  const _MarketPortfolioTableToolbar({
    required this.portfolioType,
    required this.sortKey,
    required this.queryController,
    required this.allHeaders,
    required this.visibleHeaders,
    required this.onSortChanged,
    required this.onQueryChanged,
    required this.onColumnsChanged,
    required this.onAdd,
  });

  final MarketPortfolioType portfolioType;
  final _MarketTableSortKey sortKey;
  final TextEditingController queryController;
  final List<String> allHeaders;
  final Set<String> visibleHeaders;
  final ValueChanged<_MarketTableSortKey> onSortChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Set<String>> onColumnsChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final muted = _marketMutedFor(context);
    final text = _marketTextFor(context);
    final isDark = _isMarketDark(context);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101B31) : Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: SizedBox(
              height: 30,
              child: TextField(
                controller: queryController,
                onChanged: onQueryChanged,
                style: TextStyle(
                  color: text,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Rechercher une ligne...'.tr(context),
                  hintStyle: TextStyle(
                    color: muted.withValues(alpha: 0.75),
                    fontSize: 10.2,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 13,
                    color: muted,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 30, minHeight: 28),
                  isDense: true,
                  filled: true,
                  fillColor: _marketSurfaceSoftFor(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: const BorderSide(color: _marketPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MarketSortButton(sortKey: sortKey, onChanged: onSortChanged),
          const SizedBox(width: 8),
          _MarketColumnVisibilityButton(
            portfolioType: portfolioType,
            headers: allHeaders,
            visibleHeaders: visibleHeaders,
            onChanged: onColumnsChanged,
          ),
          const Spacer(),
          const SizedBox(width: 8),
          SizedBox(
            height: 30,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(CupertinoIcons.plus, size: 13),
              label: Text(
                'Ajouter'.tr(context),
                style: const TextStyle(
                  fontSize: 10.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _marketPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketSortButton extends StatelessWidget {
  const _MarketSortButton({
    required this.sortKey,
    required this.onChanged,
  });

  final _MarketTableSortKey sortKey;
  final ValueChanged<_MarketTableSortKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final muted = _marketMutedFor(context);
    final text = _marketTextFor(context);

    return PopupMenuButton<_MarketTableSortKey>(
      tooltip: '',
      initialValue: sortKey,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final key in _MarketTableSortKey.values)
          PopupMenuItem(
            value: key,
            child: Row(
              children: [
                Icon(key.icon, size: 14, color: _marketPrimary),
                const SizedBox(width: 9),
                Text(
                  key.label.tr(context),
                  style: TextStyle(
                    color: text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 30,
        width: 172,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _marketSurfaceSoftFor(context),
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.arrow_up_arrow_down, size: 13, color: muted),
            const SizedBox(width: 8),
            Text(
              'Trier par'.tr(context),
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                sortKey.label.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_down, size: 12, color: muted),
          ],
        ),
      ),
    );
  }
}

class _MarketColumnGroup {
  const _MarketColumnGroup({
    required this.label,
    required this.headers,
  });

  final String label;
  final List<String> headers;
}

class _MarketColumnVisibilityButton extends StatefulWidget {
  const _MarketColumnVisibilityButton({
    required this.portfolioType,
    required this.headers,
    required this.visibleHeaders,
    required this.onChanged,
  });

  final MarketPortfolioType portfolioType;
  final List<String> headers;
  final Set<String> visibleHeaders;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_MarketColumnVisibilityButton> createState() =>
      _MarketColumnVisibilityButtonState();
}

class _MarketColumnVisibilityButtonState
    extends State<_MarketColumnVisibilityButton> {
  final _menuController = MenuController();
  Set<String> _draftHeaders = {};

  void _open(MenuController controller) {
    setState(() => _draftHeaders = widget.visibleHeaders.toSet());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !controller.isOpen) {
        controller.open();
      }
    });
  }

  void _setDraft(Set<String> headers) {
    if (headers.isEmpty) return;
    setState(() => _draftHeaders = headers);
    widget.onChanged(headers);
  }

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final count = _menuController.isOpen
        ? _draftHeaders.length
        : widget.visibleHeaders.length;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-170, 8),
      menuChildren: [
        _MarketColumnVisibilityPanel(
          portfolioType: widget.portfolioType,
          headers: widget.headers,
          draftHeaders: _draftHeaders,
          onDraftChanged: _setDraft,
        ),
      ],
      builder: (context, controller, child) {
        final text = _marketTextFor(context);
        return InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : _open(controller),
          borderRadius: BorderRadius.circular(2),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            width: 166,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.eye_fill,
                  size: 15,
                  color: text,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Colonnes ($count)'.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarketColumnVisibilityPanel extends StatelessWidget {
  const _MarketColumnVisibilityPanel({
    required this.portfolioType,
    required this.headers,
    required this.draftHeaders,
    required this.onDraftChanged,
  });

  final MarketPortfolioType portfolioType;
  final List<String> headers;
  final Set<String> draftHeaders;
  final ValueChanged<Set<String>> onDraftChanged;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final surface = _marketSurfaceFor(context);
    final groups = _marketColumnGroups(portfolioType, headers);
    final allHeaders = headers.toSet();
    final defaultHeaders = _marketDefaultColumnSet(portfolioType, headers);
    final allSelected = _marketColumnSetsEqual(draftHeaders, allHeaders);
    final defaultSelected =
        !allSelected && _marketColumnSetsEqual(draftHeaders, defaultHeaders);

    return Container(
      width: 336,
      height: 560,
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Colonnes visibles'.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _MarketColumnQuickAction(
                  label: 'Tout',
                  active: allSelected,
                  onTap: () => onDraftChanged(allHeaders),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '·',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _MarketColumnQuickAction(
                  label: 'Défaut',
                  active: defaultSelected,
                  onTap: () => onDraftChanged(
                    defaultHeaders,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var groupIndex = 0;
                      groupIndex < groups.length;
                      groupIndex++) ...[
                    if (groupIndex > 0)
                      Divider(height: 1, thickness: 1, color: border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: Text(
                        groups[groupIndex].label.tr(context),
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    for (final header in groups[groupIndex].headers)
                      _MarketColumnOptionRow(
                        label: _marketColumnDisplayLabel(header),
                        selected: draftHeaders.contains(header),
                        onTap: () {
                          final next = draftHeaders.toSet();
                          next.contains(header)
                              ? next.remove(header)
                              : next.add(header);
                          onDraftChanged(next);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketColumnQuickAction extends StatelessWidget {
  const _MarketColumnQuickAction({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Text(
          label.tr(context),
          style: TextStyle(
            color: active ? _marketPrimary : muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

bool _marketColumnSetsEqual(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

class _MarketColumnOptionRow extends StatelessWidget {
  const _MarketColumnOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            const SizedBox(width: 18),
            SizedBox(
              width: 26,
              child: selected
                  ? const Icon(CupertinoIcons.check_mark, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? text : muted.withValues(alpha: 0.92),
                  fontSize: 13.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

Set<String> _marketDefaultColumnSet(
  MarketPortfolioType portfolioType,
  List<String> headers,
) {
  if (portfolioType == MarketPortfolioType.bonds) {
    return headers.toSet();
  }
  final preferred = switch (portfolioType) {
    MarketPortfolioType.bonds => const <String>[],
    MarketPortfolioType.equities => const [
        'ID Instrument',
        'Pays / marché',
        'Zone',
        'Type d\'instrument',
        'Code type d\'instrument',
        'Émetteur / Société',
        'Ticker',
        'Bourse',
        'Secteur',
        'Devise',
        'Classification du titre',
        'Intention comptable',
        'Quantité',
        'Valeur de marché',
      ],
  };
  final available = headers.toSet();
  final resolved = preferred.where(available.contains).toSet();
  return resolved.isEmpty ? available : resolved;
}

List<_MarketColumnGroup> _marketColumnGroups(
  MarketPortfolioType portfolioType,
  List<String> headers,
) {
  final grouped = switch (portfolioType) {
    MarketPortfolioType.bonds => const [
        _MarketColumnGroup(
          label: 'Identification',
          headers: [
            'ID Titre',
            'Date d\'analyse',
            'Pays émetteur',
            'Zone',
            'Type d\'instrument',
            'Code type d\'instrument',
            'Emetteur',
            'Mode de Placement',
          ],
        ),
        _MarketColumnGroup(
          label: 'Notation',
          headers: [
            'Notation externe_S&P',
            'Notation externe_Moody\'s',
            'Notation externe_Fitch',
            'La pire notation externe',
            'Notation Interne',
          ],
        ),
        _MarketColumnGroup(
          label: 'Classification',
          headers: [
            'Intention comptable',
            'Classification des titres',
          ],
        ),
        _MarketColumnGroup(
          label: 'Dates et maturités',
          headers: [
            'Date d\'émission',
            'Date d\'échéance',
            'Profil d\'amortissement',
            'Fréquence de paiement des intérêts',
            'Maturité (mois)',
            'Maturité résiduelle (mois)',
          ],
        ),
        _MarketColumnGroup(
          label: 'Montants et coupons',
          headers: [
            'Devise',
            'Valeur nominale unitaire',
            'quantités',
            'Capital initial',
            'Prix d\'émission',
            'Prime d\'émission',
            'Prix de remboursement',
            'Prime de remboursement',
            'Coupon (%)',
            'Spread',
            'SPREAD',
          ],
        ),
      ],
    MarketPortfolioType.equities => const [
        _MarketColumnGroup(
          label: 'Identification',
          headers: [
            'ID Instrument',
            'Pays / marché',
            'Zone',
            'Type d\'instrument',
            'Code type d\'instrument',
            'Émetteur / Société',
            'Ticker',
            'ISIN',
            'Bourse',
            'Secteur',
          ],
        ),
        _MarketColumnGroup(
          label: 'Classification',
          headers: [
            'Devise',
            'Classification du titre',
            'Intention comptable',
          ],
        ),
        _MarketColumnGroup(
          label: 'Position',
          headers: [
            'Date d\'acquisition',
            'Quantité',
            'Prix d\'achat unitaire',
            'Coût d\'acquisition',
            'Date de valorisation',
            'Cours actuel',
            'Valeur de marché',
          ],
        ),
        _MarketColumnGroup(
          label: 'Performance',
          headers: [
            'Plus/(moins)-value latente',
            'Rendement latent (%)',
            'Dividende par action',
            'Rendement dividende (%)',
            'P/E',
            'Bêta',
          ],
        ),
      ],
  };
  final available = headers.toSet();
  final result = [
    for (final group in grouped)
      _MarketColumnGroup(
        label: group.label,
        headers:
            group.headers.where(available.contains).toList(growable: false),
      ),
  ].where((group) => group.headers.isNotEmpty).toList(growable: false);
  final groupedHeaders = result.expand((group) => group.headers).toSet();
  final remaining = headers
      .where((header) => !groupedHeaders.contains(header))
      .toList(growable: false);
  if (remaining.isEmpty) return result;
  return [
    ...result,
    _MarketColumnGroup(label: 'Autres', headers: remaining),
  ];
}

String _marketColumnDisplayLabel(String header) {
  return switch (header) {
    'ID Titre' => 'ID Titre',
    'Date d\'analyse' => 'Date d\'analyse',
    'Pays émetteur' => 'Pays émetteur',
    'Pays / marché' => 'Pays / marché',
    'Type d\'instrument' => 'Type d\'instrument',
    'Code type d\'instrument' => 'Code type d\'instrument',
    'Emetteur' => 'Emetteur',
    'Émetteur / Société' => 'Émetteur / Société',
    'Mode de Placement' => 'Mode de Placement',
    'Notation externe_S&P' => 'Notation externe S&P',
    'Notation externe_Moody\'s' => 'Notation externe Moody\'s',
    'Notation externe_Fitch' => 'Notation externe Fitch',
    'La pire notation externe' => 'La pire notation externe',
    'Notation Interne' => 'Notation Interne',
    'Classification des titres' || 'Classification du titre' => header,
    'Valeur nominale unitaire' => 'Valeur nominale unitaire',
    'quantités' || 'Quantité' => 'Quantité',
    'Capital initial' => 'Capital initial',
    'SPREAD' => 'Spread',
    'Maturité résiduelle (mois)' => 'Maturité résiduelle (mois)',
    'Prix d\'achat unitaire' => 'Prix d\'achat unitaire',
    'Coût d\'acquisition' => 'Coût d\'acquisition',
    'Plus/(moins)-value latente' => 'Plus/(moins)-value latente',
    'Rendement latent (%)' => 'Rendement latent (%)',
    'Rendement dividende (%)' => 'Rendement dividende (%)',
    _ => header,
  };
}

class _MarketPortfolioPinnedColumn extends StatelessWidget {
  const _MarketPortfolioPinnedColumn({
    required this.header,
    required this.portfolioType,
    required this.entries,
    required this.hasRecords,
    required this.controller,
    required this.scrollTargetController,
    required this.sortHeader,
    required this.sortAscending,
    required this.selectedRowIndex,
    required this.onSort,
    required this.onSelect,
  });

  final String header;
  final MarketPortfolioType portfolioType;
  final List<_MarketPortfolioTableEntry> entries;
  final bool hasRecords;
  final ScrollController controller;
  final ScrollController scrollTargetController;
  final String? sortHeader;
  final bool sortAscending;
  final int? selectedRowIndex;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final border = _marketBorderFor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _marketSurfaceFor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 11,
            offset: const Offset(4, 0),
          ),
        ],
        border: Border(
          right: BorderSide(color: border.withValues(alpha: 0.78)),
        ),
      ),
      child: SizedBox(
        width: _marketPortfolioColumnWidth(header),
        child: Column(
          children: [
            _MarketPortfolioHeaderRow(
              headers: [header],
              portfolioType: portfolioType,
              sortHeader: sortHeader,
              sortAscending: sortAscending,
              onSort: onSort,
            ),
            if (!hasRecords)
              const Expanded(child: SizedBox.shrink())
            else
              Expanded(
                child: Listener(
                  onPointerSignal: (event) => _forwardVerticalPointerScroll(
                    event,
                    scrollTargetController,
                  ),
                  child: _withoutDesktopScrollbars(
                    context,
                    ListView.builder(
                      controller: controller,
                      primary: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemExtent: _MarketPortfolioDetailsTable._rowHeight,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _MarketPortfolioDataRow(
                          record: entry.record,
                          headers: [header],
                          selected: selectedRowIndex == entry.index,
                          alternate: index.isOdd,
                          onTap: () => onSelect(entry.index),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketPortfolioActionsColumn extends StatelessWidget {
  const _MarketPortfolioActionsColumn({
    required this.portfolioType,
    required this.entries,
    required this.hasRecords,
    required this.controller,
    required this.scrollTargetController,
    required this.selectedRowIndex,
    required this.onEdit,
    required this.onDelete,
  });

  final MarketPortfolioType portfolioType;
  final List<_MarketPortfolioTableEntry> entries;
  final bool hasRecords;
  final ScrollController controller;
  final ScrollController scrollTargetController;
  final int? selectedRowIndex;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);

    return Container(
      width: _MarketPortfolioDetailsTable._actionsWidth,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: _isMarketDark(context) ? 0.18 : 0.06),
            blurRadius: 14,
            offset: const Offset(-6, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _MarketPortfolioActionsHeader(portfolioType: portfolioType),
          if (!hasRecords || entries.isEmpty)
            Expanded(child: ColoredBox(color: _marketSurfaceFor(context)))
          else
            Expanded(
              child: Listener(
                onPointerSignal: (event) => _forwardVerticalPointerScroll(
                  event,
                  scrollTargetController,
                ),
                child: _withoutDesktopScrollbars(
                  context,
                  ListView.builder(
                    controller: controller,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    itemExtent: _MarketPortfolioDetailsTable._rowHeight,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _MarketPortfolioActionRow(
                        portfolioType: portfolioType,
                        selected: selectedRowIndex == entry.index,
                        alternate: index.isOdd,
                        onEdit: () => onEdit(entry.index),
                        onDelete: () => onDelete(entry.index),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketPortfolioEditDialog extends StatefulWidget {
  const _MarketPortfolioEditDialog({
    required this.portfolioType,
    required this.record,
    this.title = 'Modifier la ligne',
    this.confirmLabel = 'Enregistrer',
  });

  final MarketPortfolioType portfolioType;
  final MarketPortfolioRecord record;
  final String title;
  final String confirmLabel;

  @override
  State<_MarketPortfolioEditDialog> createState() =>
      _MarketPortfolioEditDialogState();
}

class _MarketPortfolioEditDialogState
    extends State<_MarketPortfolioEditDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final header in widget.portfolioType.requiredHeaders)
        header: TextEditingController(
          text: _marketEditValue(widget.record.values[header]),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop({
      for (final entry in _controllers.entries)
        entry.key: _parseMarketEditValue(entry.value.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _marketTextFor(context);
    final muted = _marketMutedFor(context);
    final border = _marketBorderFor(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      title: Text(
        widget.title.tr(context),
        style: TextStyle(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final header in widget.portfolioType.requiredHeaders)
                SizedBox(
                  width: 235,
                  child: TextField(
                    controller: _controllers[header],
                    style: TextStyle(
                      color: text,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: header,
                      labelStyle: TextStyle(
                        color: muted,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w600,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: _marketSurfaceSoftFor(context),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2),
                        borderSide: const BorderSide(color: _marketPrimary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Annuler'.tr(context)),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _marketPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child: Text(widget.confirmLabel.tr(context)),
        ),
      ],
    );
  }
}

String _marketEditValue(Object? value) {
  if (value == null) return '';
  if (value is DateTime) return AppFormatters.shortDate(value);
  return value.toString();
}

Object? _parseMarketEditValue(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final normalized = text
      .replaceAll('\u00A0', '')
      .replaceAll(' ', '')
      .replaceAll('FCFA', '')
      .replaceAll('%', '')
      .replaceAll(',', '.');
  final number = double.tryParse(normalized);
  return number ?? text;
}

class _MarketPortfolioActionsHeader extends StatelessWidget {
  const _MarketPortfolioActionsHeader({required this.portfolioType});

  final MarketPortfolioType portfolioType;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final accent = portfolioType == MarketPortfolioType.bonds
        ? _marketPrimary
        : _marketSuccess;
    final headerBg = isDark
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.32),
            const Color(0xFF0F1B31),
          )
        : accent.withValues(alpha: 0.18);
    return Container(
      height: _MarketPortfolioDetailsTable._headerHeight,
      alignment: Alignment.center,
      color: headerBg,
      child: const Text(
        'ACTIONS',
        style: TextStyle(
          color: _marketDashboardDeepBlue,
          fontSize: 9.4,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _MarketPortfolioActionRow extends StatelessWidget {
  const _MarketPortfolioActionRow({
    required this.portfolioType,
    required this.selected,
    required this.alternate,
    required this.onEdit,
    required this.onDelete,
  });

  final MarketPortfolioType portfolioType;
  final bool selected;
  final bool alternate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final selectionBg =
        isDark ? const Color(0xFF2B2A38) : const Color(0xFFFFF5DA);
    final selectionBorder =
        const Color(0xFFD99A13).withValues(alpha: isDark ? 0.52 : 0.42);
    final background = selected
        ? selectionBg
        : alternate
            ? (isDark
                ? const Color(0xFF14233D).withValues(alpha: 0.55)
                : const Color(0xFFF5F9FF))
            : _marketSurfaceFor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: selected ? BorderSide(color: selectionBorder) : BorderSide.none,
          bottom: BorderSide(
            color: selected
                ? selectionBorder
                : _marketBorderFor(context).withValues(alpha: 0.56),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MarketPortfolioActionButton(
            tooltip: 'Modifier la ligne',
            icon: CupertinoIcons.square_pencil,
            color: _marketTextFor(context),
            onTap: onEdit,
          ),
          const SizedBox(width: 10),
          _MarketPortfolioActionButton(
            tooltip: 'Supprimer la ligne',
            icon: CupertinoIcons.trash,
            color: _marketDanger,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _MarketPortfolioActionButton extends StatelessWidget {
  const _MarketPortfolioActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip.tr(context),
      waitDuration: const Duration(milliseconds: 350),
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _MarketPortfolioHeaderRow extends StatelessWidget {
  const _MarketPortfolioHeaderRow({
    required this.headers,
    required this.portfolioType,
    required this.sortHeader,
    required this.sortAscending,
    required this.onSort,
  });

  final List<String> headers;
  final MarketPortfolioType portfolioType;
  final String? sortHeader;
  final bool sortAscending;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final accent = portfolioType == MarketPortfolioType.bonds
        ? _marketPrimary
        : _marketSuccess;
    final headerBg = isDark
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.32),
            const Color(0xFF0F1B31),
          )
        : accent.withValues(alpha: 0.18);

    return Container(
      height: _MarketPortfolioDetailsTable._headerHeight,
      color: headerBg,
      child: Row(
        children: [
          for (final header in headers)
            _MarketPortfolioHeaderCell(
              header: header,
              width: _marketPortfolioColumnWidth(header),
              sorted: sortHeader == header,
              sortAscending: sortAscending,
              onTap: () => onSort(header),
            ),
        ],
      ),
    );
  }
}

class _MarketPortfolioHeaderCell extends StatelessWidget {
  const _MarketPortfolioHeaderCell({
    required this.header,
    required this.width,
    required this.sorted,
    required this.sortAscending,
    required this.onTap,
  });

  final String header;
  final double width;
  final bool sorted;
  final bool sortAscending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);
    final label = _marketColumnDisplayLabel(header);
    final icon = sorted
        ? (sortAscending
            ? CupertinoIcons.chevron_up
            : CupertinoIcons.chevron_down)
        : CupertinoIcons.arrow_up_arrow_down;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: border.withValues(alpha: 0.48)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    color: sorted ? _marketPrimary : _marketDashboardDeepBlue,
                    fontSize: 10.2,
                    fontWeight: FontWeight.w800,
                    height: 1.03,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                size: sorted ? 11 : 10,
                color: sorted
                    ? _marketPrimary
                    : _marketDashboardDeepBlue.withValues(alpha: 0.42),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketPortfolioDataRow extends StatelessWidget {
  const _MarketPortfolioDataRow({
    required this.record,
    required this.headers,
    required this.selected,
    required this.alternate,
    required this.onTap,
  });

  final MarketPortfolioRecord record;
  final List<String> headers;
  final bool selected;
  final bool alternate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final selectionBg =
        isDark ? const Color(0xFF2B2A38) : const Color(0xFFFFF5DA);
    final selectionBorder =
        const Color(0xFFD99A13).withValues(alpha: isDark ? 0.52 : 0.42);
    final text = selected
        ? (isDark ? const Color(0xFFFFF4D6) : const Color(0xFF1B2235))
        : _marketTextFor(context);
    final background = selected
        ? selectionBg
        : alternate
            ? (isDark
                ? const Color(0xFF14233D).withValues(alpha: 0.55)
                : const Color(0xFFF5F9FF))
            : _marketSurfaceFor(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          height: _MarketPortfolioDetailsTable._rowHeight,
          decoration: BoxDecoration(
            color: background,
            border: selected
                ? Border.symmetric(
                    horizontal: BorderSide(color: selectionBorder),
                  )
                : null,
          ),
          child: Row(
            children: [
              for (final header in headers)
                _MarketPortfolioCell(
                  width: _marketPortfolioColumnWidth(header),
                  child: _marketPortfolioCellContent(
                    context: context,
                    header: header,
                    record: record,
                    selected: selected,
                    textColor: text,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketPortfolioTagStyle {
  const _MarketPortfolioTagStyle({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

class _MarketPortfolioValueBadge extends StatelessWidget {
  const _MarketPortfolioValueBadge({
    required this.label,
    required this.style,
    this.alignment = Alignment.center,
  });

  final String label;
  final _MarketPortfolioTagStyle style;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _marketPortfolioBadgeWidth(label, constraints.maxWidth);
        return Align(
          alignment: alignment,
          child: SizedBox(
            width: width,
            height: 26,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.foreground,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double _marketPortfolioBadgeWidth(String label, double maxWidth) {
  final compactText = label.trim();
  final estimated = compactText.length * 8.0 + 28;
  final cap = math.min(maxWidth, 96.0);
  return estimated.clamp(48.0, cap).toDouble();
}

Widget _marketPortfolioCellContent({
  required BuildContext context,
  required String header,
  required MarketPortfolioRecord record,
  required bool selected,
  required Color textColor,
}) {
  final value = _formatMarketPortfolioCell(
    header,
    record.values[header],
    currency: record.currency,
  );
  final tagStyle = _marketPortfolioTagStyleFor(
    context,
    header,
    value,
  );
  if (tagStyle != null) {
    return _MarketPortfolioValueBadge(
      label: value,
      style: tagStyle,
      alignment: header == 'Intention comptable' ||
              header == 'La pire notation externe'
          ? Alignment.centerLeft
          : Alignment.center,
    );
  }

  return Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: textColor,
      fontSize: 10.8,
      fontWeight: selected || _marketPortfolioEmphasizedHeader(header)
          ? FontWeight.w700
          : FontWeight.w500,
    ),
  );
}

_MarketPortfolioTagStyle? _marketPortfolioTagStyleFor(
  BuildContext context,
  String header,
  String value,
) {
  final label = value.trim();
  if (label.isEmpty || label == '-') return null;

  final Color? accent = switch (header) {
    'Zone' => _marketZoneTagColor(label),
    'Notation externe_S&P' ||
    'Notation externe_Moody\'s' ||
    'Notation externe_Fitch' ||
    'La pire notation externe' =>
      _marketRatingTagColor(label),
    'Intention comptable' => _marketAccountingTagColor(label),
    _ => null,
  };
  if (accent == null) return null;
  return _marketPortfolioTagStyle(context, accent);
}

_MarketPortfolioTagStyle _marketPortfolioTagStyle(
  BuildContext context,
  Color accent,
) {
  final isDark = _isMarketDark(context);
  final background = isDark
      ? Color.alphaBlend(
          accent.withValues(alpha: 0.13),
          _marketSurfaceSoftFor(context),
        )
      : accent.withValues(alpha: 0.055);
  final foreground = isDark && accent.computeLuminance() < 0.46
      ? Color.lerp(accent, Colors.white, 0.34)!
      : accent;
  return _MarketPortfolioTagStyle(
    background: background,
    foreground: foreground,
  );
}

bool _marketPortfolioEmphasizedHeader(String header) {
  return header == 'Pays émetteur' ||
      header == 'Pays / marché' ||
      header == 'Emetteur' ||
      header == 'Émetteur / Société';
}

String _marketNormalizeTag(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Ä', 'A')
      .replaceAll('Ç', 'C')
      .replaceAll('É', 'E')
      .replaceAll('È', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Ë', 'E')
      .replaceAll('Î', 'I')
      .replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O')
      .replaceAll('Ö', 'O')
      .replaceAll('Ù', 'U')
      .replaceAll('Û', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll(RegExp(r'[\s_\-/]+'), ' ');
}

Color _marketZoneTagColor(String value) {
  final normalized = _marketNormalizeTag(value);
  if (normalized.contains('UEMOA')) return _marketViolet;
  if (normalized.contains('CEMAC')) return _marketPrimary;
  if (normalized.contains('CEDEAO') || normalized.contains('ECOWAS')) {
    return _marketSuccess;
  }
  if (normalized.contains('EURO') || normalized.contains('UE')) {
    return _marketCyan;
  }
  return const Color(0xFF64748B);
}

Color _marketRatingTagColor(String value) {
  final normalized = _marketNormalizeTag(value).replaceAll(' ', '');
  if (normalized.contains('NONNOTE') ||
      normalized == 'NR' ||
      normalized == 'N/A') {
    return const Color(0xFF64748B);
  }
  if (normalized.startsWith('AAA') ||
      normalized.startsWith('AA') ||
      normalized.startsWith('A')) {
    return const Color(0xFF059669);
  }
  if (normalized.startsWith('BBB')) return const Color(0xFF0D9488);
  if (normalized.startsWith('BB') || normalized.startsWith('B')) {
    return _marketWarning;
  }
  if (normalized.startsWith('CCC') ||
      normalized.startsWith('CC') ||
      normalized.startsWith('C') ||
      normalized.startsWith('D')) {
    return const Color(0xFFDC2626);
  }
  return const Color(0xFF64748B);
}

Color _marketAccountingTagColor(String value) {
  final normalized = _marketNormalizeTag(value);
  if (normalized.contains('AFS') ||
      normalized.contains('FVOCI') ||
      normalized.contains('DISPONIBLE')) {
    return const Color(0xFF0D9488);
  }
  if (normalized.contains('HTM') ||
      normalized.contains('AMORTI') ||
      normalized.contains('JUSQU')) {
    return _marketPrimary;
  }
  if (normalized.contains('TRADING') ||
      normalized.contains('HFT') ||
      normalized.contains('FVTPL') ||
      normalized.contains('NEGOCIATION')) {
    return const Color(0xFFEA580C);
  }
  return _marketViolet;
}

String _marketAccountingIntentLabel(String value) {
  final text = value.trim();
  final normalized = _marketNormalizeTag(text);
  if (normalized.contains('AFS') ||
      normalized.contains('FVOCI') ||
      normalized.contains('AVAILABLE') ||
      normalized.contains('DISPONIBLE')) {
    return 'AFS';
  }
  if (normalized.contains('HTM') ||
      normalized.contains('HELD') ||
      normalized.contains('MATUR') ||
      normalized.contains('AMORTI') ||
      normalized.contains('JUSQU')) {
    return 'HTM';
  }
  if (normalized.contains('TRADING') ||
      normalized.contains('HFT') ||
      normalized.contains('FVTPL') ||
      normalized.contains('NEGOCIATION')) {
    return 'Trading';
  }
  return text;
}

class _MarketPortfolioCell extends StatelessWidget {
  const _MarketPortfolioCell({
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final border = _marketBorderFor(context);

    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: border.withValues(alpha: 0.48)),
        ),
      ),
      child: child,
    );
  }
}

double _marketPortfolioColumnWidth(String header) {
  if (header == 'ID Titre') return 118;
  if (header == 'Date d\'analyse') return 145;
  if (header == 'ID Instrument') return 150;
  if (header == 'Ticker') return 110;
  if (header == 'ISIN') return 150;
  if (header == 'Bourse') return 170;
  if (header == 'Secteur') return 170;
  if (header == 'Pays / marché') return 160;
  if (header == 'Émetteur / Société') return 300;
  if (header == 'Classification du titre') return 210;
  if (header == 'Quantité') return 130;
  if (header == 'Prix d\'achat unitaire') return 175;
  if (header == 'Coût d\'acquisition') return 175;
  if (header == 'Cours actuel') return 145;
  if (header == 'Plus/(moins)-value latente') return 210;
  if (header == 'Rendement latent (%)') return 180;
  if (header == 'Dividende par action') return 180;
  if (header == 'Rendement dividende (%)') return 205;
  if (header == 'P/E') return 100;
  if (header == 'Bêta') return 100;
  if (header == 'La pire notation externe') return 230;
  if (header.contains('Notation externe')) return 220;
  if (header.contains('Prix de remboursement')) return 220;
  if (header.contains('Prime de remboursement')) return 220;
  if (header.contains('Fréquence de paiement')) return 285;
  if (header.contains('Valeur nominale')) return 230;
  if (header.contains('Code type')) return 230;
  if (header.contains('Classification')) return 230;
  if (header.contains('amortissement')) return 225;
  if (header.contains('résiduelle')) return 235;
  if (header.contains('Volatilité') || header.contains('Rendement attendu')) {
    return 180;
  }
  if (header == 'Date de valorisation' || header == 'Date d\'acquisition') {
    return 170;
  }
  if (header == 'Nombre d\'actions' || header == 'Valeur de marché') {
    return header == 'Valeur de marché' ? 190 : 165;
  }
  if (header == 'Liquidité moyenne') return 165;
  if (_isMarketMoneyHeader(header)) return 190;
  if (header.contains('émission') || header.contains('échéance')) return 165;
  if (header == 'Emetteur') return 300;
  if (header == 'Type d\'instrument') return 260;
  if (header == 'Mode de Placement') return 200;
  if (header == 'Pays émetteur') return 180;
  if (header == 'Intention comptable') return 220;
  return 135;
}

String _formatMarketPortfolioCell(
  String header,
  Object? value, {
  String currency = 'XOF',
}) {
  if (value == null) return '-';
  if (value is DateTime) return AppFormatters.shortDate(value);
  if (value is num) {
    return _formatMarketPortfolioNumericCell(
      header,
      value.toDouble(),
      currency: currency,
    );
  }
  final text = value.toString().trim();
  if (_looksLikeDisplayedFormula(text)) return '-';
  if (header == 'Intention comptable') {
    return text.isEmpty ? '-' : _marketAccountingIntentLabel(text);
  }
  final parsedNumber = _parseMarketPortfolioNumber(text);
  if (parsedNumber != null &&
      (header.contains('(%)') || _isMarketMoneyHeader(header))) {
    return _formatMarketPortfolioNumericCell(
      header,
      parsedNumber,
      currency: currency,
    );
  }
  return text.isEmpty ? '-' : text;
}

int _compareMarketPortfolioHeaderValues(
  String header,
  Object? left,
  Object? right,
) {
  final leftEmpty = _marketPortfolioSortValueIsEmpty(left);
  final rightEmpty = _marketPortfolioSortValueIsEmpty(right);
  if (leftEmpty || rightEmpty) {
    if (leftEmpty && rightEmpty) return 0;
    return leftEmpty ? 1 : -1;
  }

  final leftDate = _marketPortfolioSortDate(left);
  final rightDate = _marketPortfolioSortDate(right);
  if (leftDate != null && rightDate != null) {
    return leftDate.compareTo(rightDate);
  }

  if (header.toLowerCase().contains('notation')) {
    return _compareMarketRatings(
      _marketPortfolioSortText(left),
      _marketPortfolioSortText(right),
    );
  }

  final leftNumber = _marketPortfolioSortNumber(left);
  final rightNumber = _marketPortfolioSortNumber(right);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }

  return _marketPortfolioSortText(left)
      .toLowerCase()
      .compareTo(_marketPortfolioSortText(right).toLowerCase());
}

bool _marketPortfolioSortValueIsEmpty(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  return false;
}

DateTime? _marketPortfolioSortDate(Object? value) {
  if (value is DateTime) return value;
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  final parsedIso = DateTime.tryParse(text);
  if (parsedIso != null) return parsedIso;
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

double? _marketPortfolioSortNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return _parseMarketPortfolioNumber(value);
  return null;
}

String _marketPortfolioSortText(Object? value) {
  if (value == null) return '';
  if (value is DateTime) return AppFormatters.shortDate(value);
  return value.toString().trim();
}

String _formatMarketPortfolioNumericCell(
  String header,
  double value, {
  required String currency,
}) {
  if (header.contains('(%)')) {
    return _marketPercentText(value);
  }
  if (_isMarketMoneyHeader(header)) {
    return _marketMoneyText(
      value,
      displayCurrency: currency,
      convertFromXof: false,
      compactUnit: true,
      maxDecimals: 3,
    );
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return _marketDecimalNumberText(value, decimals: 3);
}

double? _parseMarketPortfolioNumber(String value) {
  var text = value.trim();
  if (text.isEmpty) return null;
  text = text
      .replaceAll('\u00A0', ' ')
      .replaceAll('%', '')
      .replaceAll(
        RegExp(r'\b(XOF|XAF|FCFA|EUR|USD)\b', caseSensitive: false),
        '',
      )
      .trim();
  text = text.replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) return null;

  final lastComma = text.lastIndexOf(',');
  final lastDot = text.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    text = lastComma > lastDot
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text.replaceAll(',', '');
  } else if (lastComma >= 0) {
    text = text.replaceAll(',', '.');
  }
  return double.tryParse(text);
}

String _marketPercentText(double value) {
  final ratio = value.abs() > 1 ? value / 100 : value;
  return '${_marketDecimalNumberText(
    ratio * 100,
    decimals: 3,
    trimTrailingZeros: true,
  )}%';
}

String _marketTableSortValue(
  MarketPortfolioRecord record,
  _MarketTableSortKey key,
) {
  return switch (key) {
    _MarketTableSortKey.issuer => record.issuer,
    _MarketTableSortKey.country => _marketPortfolioRecordTextAny(
        record,
        const ['Pays émetteur', 'Pays / marché'],
        'Non renseigné',
      ),
    _MarketTableSortKey.zone => record.zone,
    _MarketTableSortKey.rating => record.rating,
    _MarketTableSortKey.accountingIntent => _marketAccountingIntentLabel(
        _marketPortfolioRecordTextAny(
          record,
          const ['Intention comptable'],
          '',
        ),
      ),
    _MarketTableSortKey.residualMaturity => _bondMaturityYears(
        record,
      ).toString(),
    _MarketTableSortKey.instrumentType => record.instrumentType,
    _MarketTableSortKey.exposure => record.exposureAmount.toString(),
    _MarketTableSortKey.currency => record.currency,
  };
}

String _marketPortfolioRecordTextAny(
  MarketPortfolioRecord record,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = record.values[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

int _compareMarketNumbers(double left, double right) {
  final normalizedLeft = left > 0 ? left : double.infinity;
  final normalizedRight = right > 0 ? right : double.infinity;
  return normalizedLeft.compareTo(normalizedRight);
}

int _compareMarketRatings(String left, String right) {
  final leftRank = _marketRatingRank(left);
  final rightRank = _marketRatingRank(right);
  final rankCompare = leftRank.compareTo(rightRank);
  if (rankCompare != 0) return rankCompare;
  return left.toLowerCase().compareTo(right.toLowerCase());
}

int _marketRatingRank(String rating) {
  final normalized = rating.trim().toUpperCase();
  if (normalized.isEmpty) return 999;
  const ranks = {
    'AAA': 1,
    'AA+': 2,
    'AA': 3,
    'AA-': 4,
    'A+': 5,
    'A': 6,
    'A-': 7,
    'BBB+': 8,
    'BBB': 9,
    'BBB-': 10,
    'BB+': 11,
    'BB': 12,
    'BB-': 13,
    'B+': 14,
    'B': 15,
    'B-': 16,
    'CCC+': 17,
    'CCC': 18,
    'CCC-': 19,
    'CC': 20,
    'C': 21,
    'D': 22,
    'AA1': 2,
    'AA2': 3,
    'AA3': 4,
    'A1': 5,
    'A2': 6,
    'A3': 7,
    'BAA1': 8,
    'BAA2': 9,
    'BAA3': 10,
    'BA1': 11,
    'BA2': 12,
    'BA3': 13,
    'B1': 14,
    'B2': 15,
    'B3': 16,
    'CAA1': 17,
    'CAA2': 18,
    'CAA3': 19,
    'CA': 20,
  };
  return ranks[normalized] ?? 998;
}

bool _looksLikeDisplayedFormula(String text) {
  return text.startsWith('=') ||
      text.startsWith('IF(') ||
      text.startsWith('OR(') ||
      text.startsWith('DATEDIF(') ||
      text.contains('DATEDIF(');
}

bool _isMarketMoneyHeader(String header) {
  if (header.contains('(%)')) return false;
  final normalized = header.toLowerCase();
  return normalized.contains('prix') ||
      normalized.contains('prime') ||
      normalized.contains('valeur') ||
      normalized.contains('capital') ||
      normalized.contains('coût') ||
      normalized.contains('cout') ||
      normalized.contains('cours') ||
      normalized.contains('montant') ||
      normalized.contains('exposition') ||
      normalized.contains('liquidité') ||
      normalized.contains('liquidite');
}

String _marketMoneyText(
  double value, {
  required String displayCurrency,
  bool convertFromXof = true,
  bool compactUnit = false,
  int maxDecimals = 2,
}) {
  final converted = convertFromXof
      ? convertCurrencyAmount(
          value,
          fromCurrency: 'XOF',
          toCurrency: displayCurrency,
        )
      : value;
  final amountInBillions = _marketAmountInBillions(converted);
  return '${_marketMoneyNumber(amountInBillions, maxDecimals: maxDecimals)} Md ${displayCurrencyLabel(displayCurrency)}';
}

double _marketAmountInBillions(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000) {
    return value / 1000000000;
  }
  return value;
}

String _marketMoneyNumber(double value, {int maxDecimals = 2}) {
  final isNegative = value < 0;
  final absolute = value.abs();
  final decimals = maxDecimals <= 2
      ? absolute >= 100
          ? 0
          : absolute >= 10
              ? 1
              : 2
      : maxDecimals;
  var fixed = absolute.toStringAsFixed(decimals);
  if (fixed.contains('.')) {
    fixed =
        fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = fixed.split('.');
  final groupedInteger = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => AppLocalizations.isEnglish ? ',' : ' ',
  );
  final decimalPart = parts.length > 1 && parts[1].isNotEmpty
      ? '${AppLocalizations.isEnglish ? '.' : ','}${parts[1]}'
      : '';
  final sign = isNegative && absolute > 0 ? '-' : '';
  return '$sign$groupedInteger$decimalPart';
}

String _marketDecimalNumberText(
  double value, {
  required int decimals,
  bool trimTrailingZeros = true,
}) {
  final isNegative = value < 0;
  final absolute = value.abs();
  var fixed = absolute.toStringAsFixed(decimals);
  if (trimTrailingZeros && fixed.contains('.')) {
    fixed =
        fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = fixed.split('.');
  final groupedInteger = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => AppLocalizations.isEnglish ? ',' : ' ',
  );
  final decimalPart = parts.length > 1 && parts[1].isNotEmpty
      ? '${AppLocalizations.isEnglish ? '.' : ','}${parts[1]}'
      : '';
  final sign = isNegative && absolute > 0 ? '-' : '';
  return '$sign$groupedInteger$decimalPart';
}

class _ValueAtRiskModule extends StatefulWidget {
  const _ValueAtRiskModule({required this.api});

  final RwaApiService api;

  @override
  State<_ValueAtRiskModule> createState() => _ValueAtRiskModuleState();
}

class _ValueAtRiskModuleState extends State<_ValueAtRiskModule> {
  late final Future<DashboardSnapshot> _dashboardFuture;

  _VarMethod _method = _VarMethod.historical;

  double _historicalConfidence = _defaultHistoricalConfidence;
  int _historicalHorizon = _defaultHistoricalHorizon;
  int _historicalWindow = _defaultHistoricalWindow;
  MarketPortfolioType _historicalPortfolio = _defaultHistoricalPortfolio;

  double _paramConfidence = _defaultParamConfidence;
  int _paramHorizon = _defaultParamHorizon;
  double _paramCorrelation = _defaultParamCorrelation;
  double _paramExpectedReturn = _defaultParamExpectedReturn;
  double _paramRiskFreeRate = _defaultParamRiskFreeRate;
  double? _paramVolatilityOverride;
  double? _paramPortfolioValueOverride;
  double? _paramDurationOverride;

  double _mcConfidence = _defaultMcConfidence;
  int _mcHorizon = _defaultMcHorizon;
  int _mcSimulations = _defaultMcSimulations;
  double _mcCorrelation = _defaultMcCorrelation;
  _MonteCarloDistribution _mcDistribution = _defaultMcDistribution;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.api.fetchDashboard();
  }

  void _resetActiveMethodDefaults() {
    setState(() {
      switch (_method) {
        case _VarMethod.historical:
          _historicalConfidence = _defaultHistoricalConfidence;
          _historicalHorizon = _defaultHistoricalHorizon;
          _historicalWindow = _defaultHistoricalWindow;
          _historicalPortfolio = _defaultHistoricalPortfolio;
        case _VarMethod.parametric:
          _paramConfidence = _defaultParamConfidence;
          _paramHorizon = _defaultParamHorizon;
          _paramCorrelation = _defaultParamCorrelation;
          _paramExpectedReturn = _defaultParamExpectedReturn;
          _paramRiskFreeRate = _defaultParamRiskFreeRate;
          _resetParametricAdvancedDefaults(notify: false);
        case _VarMethod.monteCarlo:
          _mcConfidence = _defaultMcConfidence;
          _mcHorizon = _defaultMcHorizon;
          _mcSimulations = _defaultMcSimulations;
          _mcCorrelation = _defaultMcCorrelation;
          _mcDistribution = _defaultMcDistribution;
      }
    });
  }

  void _resetParametricAdvancedDefaults({bool notify = true}) {
    void reset() {
      _paramVolatilityOverride = null;
      _paramPortfolioValueOverride = null;
      _paramDurationOverride = null;
    }

    if (notify) {
      setState(reset);
    } else {
      reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(context);

    return FutureBuilder<DashboardSnapshot>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        return ValueListenableBuilder<
            Map<MarketPortfolioType, MarketPortfolioDataset>>(
          valueListenable: MarketDataImportStore.instance.datasetsNotifier,
          builder: (context, datasets, _) {
            final dataset = datasets[_historicalPortfolio];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.pagePadding,
                    AppTheme.pagePadding,
                    AppTheme.pagePadding,
                  ),
                  child: PageHeader(
                    title: 'VALUE AT RISK (VaR)',
                    subtitle: 'Mesure et simulation du risque de marché',
                    titleFontSize: 26,
                    subtitleFontSize: 12.5,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _VarMethodSwitch(
                          selected: _method,
                          onChanged: (value) => setState(() => _method = value),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      0,
                      AppTheme.pagePadding,
                      AppTheme.pagePadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (snapshot.connectionState != ConnectionState.done &&
                            dataset == null)
                          const _MarketCard(
                            child: SizedBox(
                              height: 260,
                              child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else
                          FutureBuilder<_VarPortfolioContext>(
                            future: _varPortfolioContextForAsync(
                              dataset,
                              _historicalPortfolio,
                            ),
                            builder: (context, portfolioSnapshot) {
                              final portfolio = portfolioSnapshot.data;
                              if (portfolio == null) {
                                return const _MarketDeferredLoadingState(
                                  title: 'Chargement de la VaR',
                                  subtitle:
                                      'Nous préparons les données de risque.',
                                );
                              }
                              return _UnifiedVarMethodView(
                                method: _method,
                                portfolio: portfolio,
                                displayCurrency: displayCurrency,
                                historicalConfidence: _historicalConfidence,
                                historicalHorizon: _historicalHorizon,
                                historicalWindow: _historicalWindow,
                                historicalPortfolio: _historicalPortfolio,
                                paramConfidence: _paramConfidence,
                                paramHorizon: _paramHorizon,
                                paramCorrelation: _paramCorrelation,
                                paramExpectedReturn: _paramExpectedReturn,
                                paramRiskFreeRate: _paramRiskFreeRate,
                                paramVolatilityOverride:
                                    _paramVolatilityOverride,
                                paramPortfolioValueOverride:
                                    _paramPortfolioValueOverride,
                                paramDurationOverride: _paramDurationOverride,
                                mcConfidence: _mcConfidence,
                                mcHorizon: _mcHorizon,
                                mcSimulations: _mcSimulations,
                                mcCorrelation: _mcCorrelation,
                                mcDistribution: _mcDistribution,
                                onResetDefaults: _resetActiveMethodDefaults,
                                onHistoricalConfidenceChanged: (value) =>
                                    setState(
                                  () => _historicalConfidence = value,
                                ),
                                onHistoricalHorizonChanged: (value) => setState(
                                  () => _historicalHorizon = value,
                                ),
                                onHistoricalWindowChanged: (value) => setState(
                                  () => _historicalWindow = value,
                                ),
                                onHistoricalPortfolioChanged: (value) =>
                                    setState(() {
                                  _historicalPortfolio = value;
                                  _resetParametricAdvancedDefaults(
                                    notify: false,
                                  );
                                }),
                                onParamConfidenceChanged: (value) => setState(
                                  () => _paramConfidence = value,
                                ),
                                onParamHorizonChanged: (value) => setState(
                                  () => _paramHorizon = value,
                                ),
                                onParamCorrelationChanged: (value) => setState(
                                  () => _paramCorrelation = value,
                                ),
                                onParamExpectedReturnChanged: (value) =>
                                    setState(
                                  () => _paramExpectedReturn = value,
                                ),
                                onParamRiskFreeRateChanged: (value) => setState(
                                  () => _paramRiskFreeRate = value,
                                ),
                                onParamVolatilityChanged: (value) => setState(
                                  () => _paramVolatilityOverride = value,
                                ),
                                onParamPortfolioValueChanged: (value) =>
                                    setState(
                                  () => _paramPortfolioValueOverride = value,
                                ),
                                onParamDurationChanged: (value) => setState(
                                  () => _paramDurationOverride = value,
                                ),
                                onParamAdvancedDefaultsReset:
                                    _resetParametricAdvancedDefaults,
                                onMcConfidenceChanged: (value) => setState(
                                  () => _mcConfidence = value,
                                ),
                                onMcHorizonChanged: (value) => setState(
                                  () => _mcHorizon = value,
                                ),
                                onMcSimulationsChanged: (value) => setState(
                                  () => _mcSimulations = value,
                                ),
                                onMcCorrelationChanged: (value) => setState(
                                  () => _mcCorrelation = value,
                                ),
                                onMcDistributionChanged: (value) => setState(
                                  () => _mcDistribution = value,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _UnifiedVarMethodView extends StatelessWidget {
  const _UnifiedVarMethodView({
    required this.method,
    required this.portfolio,
    required this.displayCurrency,
    required this.historicalConfidence,
    required this.historicalHorizon,
    required this.historicalWindow,
    required this.historicalPortfolio,
    required this.paramConfidence,
    required this.paramHorizon,
    required this.paramCorrelation,
    required this.paramExpectedReturn,
    required this.paramRiskFreeRate,
    required this.paramVolatilityOverride,
    required this.paramPortfolioValueOverride,
    required this.paramDurationOverride,
    required this.mcConfidence,
    required this.mcHorizon,
    required this.mcSimulations,
    required this.mcCorrelation,
    required this.mcDistribution,
    required this.onResetDefaults,
    required this.onHistoricalConfidenceChanged,
    required this.onHistoricalHorizonChanged,
    required this.onHistoricalWindowChanged,
    required this.onHistoricalPortfolioChanged,
    required this.onParamConfidenceChanged,
    required this.onParamHorizonChanged,
    required this.onParamCorrelationChanged,
    required this.onParamExpectedReturnChanged,
    required this.onParamRiskFreeRateChanged,
    required this.onParamVolatilityChanged,
    required this.onParamPortfolioValueChanged,
    required this.onParamDurationChanged,
    required this.onParamAdvancedDefaultsReset,
    required this.onMcConfidenceChanged,
    required this.onMcHorizonChanged,
    required this.onMcSimulationsChanged,
    required this.onMcCorrelationChanged,
    required this.onMcDistributionChanged,
  });

  final _VarMethod method;
  final _VarPortfolioContext portfolio;
  final String displayCurrency;
  final double historicalConfidence;
  final int historicalHorizon;
  final int historicalWindow;
  final MarketPortfolioType historicalPortfolio;
  final double paramConfidence;
  final int paramHorizon;
  final double paramCorrelation;
  final double paramExpectedReturn;
  final double paramRiskFreeRate;
  final double? paramVolatilityOverride;
  final double? paramPortfolioValueOverride;
  final double? paramDurationOverride;
  final double mcConfidence;
  final int mcHorizon;
  final int mcSimulations;
  final double mcCorrelation;
  final _MonteCarloDistribution mcDistribution;
  final VoidCallback onResetDefaults;
  final ValueChanged<double> onHistoricalConfidenceChanged;
  final ValueChanged<int> onHistoricalHorizonChanged;
  final ValueChanged<int> onHistoricalWindowChanged;
  final ValueChanged<MarketPortfolioType> onHistoricalPortfolioChanged;
  final ValueChanged<double> onParamConfidenceChanged;
  final ValueChanged<int> onParamHorizonChanged;
  final ValueChanged<double> onParamCorrelationChanged;
  final ValueChanged<double> onParamExpectedReturnChanged;
  final ValueChanged<double> onParamRiskFreeRateChanged;
  final ValueChanged<double> onParamVolatilityChanged;
  final ValueChanged<double> onParamPortfolioValueChanged;
  final ValueChanged<double> onParamDurationChanged;
  final VoidCallback onParamAdvancedDefaultsReset;
  final ValueChanged<double> onMcConfidenceChanged;
  final ValueChanged<int> onMcHorizonChanged;
  final ValueChanged<int> onMcSimulationsChanged;
  final ValueChanged<double> onMcCorrelationChanged;
  final ValueChanged<_MonteCarloDistribution> onMcDistributionChanged;

  @override
  Widget build(BuildContext context) {
    final historicalResult = _HistoricalVarResult.calculate(
      portfolio: portfolio,
      confidence: historicalConfidence,
      horizonDays: historicalHorizon,
      windowDays: historicalWindow,
    );
    const defaultParamVolatility = _defaultParamVolatility;
    final importedParamDuration = portfolio.durationYears;
    final defaultParamDuration =
        importedParamDuration != null && importedParamDuration > 0
            ? importedParamDuration
            : (portfolio.portfolioType == MarketPortfolioType.bonds
                ? _defaultParamDuration
                : 1.0);
    final defaultParamPortfolioValue = portfolio.parametricPortfolioValue;
    final effectiveParamVolatility =
        paramVolatilityOverride ?? defaultParamVolatility;
    final effectiveParamPortfolioValue =
        paramPortfolioValueOverride ?? defaultParamPortfolioValue;
    final effectiveParamDuration =
        paramDurationOverride ?? defaultParamDuration;
    final effectiveParamCorrelation = _parameterValueFromImport(
      selected: paramCorrelation,
      defaultValue: _defaultParamCorrelation,
      imported: portfolio.correlation,
    );
    final effectiveParamExpectedReturn = _parameterValueFromImport(
      selected: paramExpectedReturn,
      defaultValue: _defaultParamExpectedReturn,
      imported: portfolio.expectedReturn,
    );
    final parametricResult = _ParametricVarResult.calculate(
      hasMarketData: portfolio.hasImportedData &&
          effectiveParamPortfolioValue > 0 &&
          effectiveParamVolatility > 0,
      portfolioType: portfolio.portfolioType,
      basePortfolioValue: effectiveParamPortfolioValue,
      confidence: paramConfidence,
      horizonDays: paramHorizon,
      portfolioScale: _defaultParamPortfolioScale,
      volatility: effectiveParamVolatility,
      duration: effectiveParamDuration,
      correlation: effectiveParamCorrelation,
      expectedReturn: effectiveParamExpectedReturn,
      riskFreeRate: paramRiskFreeRate,
    );
    final monteCarloResult = method == _VarMethod.monteCarlo
        ? _MonteCarloVarResult.calculateCached(
            portfolio: portfolio,
            confidence: mcConfidence,
            horizonDays: mcHorizon,
            simulations: mcSimulations,
            correlation: mcCorrelation,
            distribution: mcDistribution,
            volatility: portfolio.volatility,
            expectedReturn: portfolio.expectedReturn,
          )
        : _MonteCarloVarResult.empty(mcConfidence);
    final insight = _insight(historicalResult);
    final formula = _formulaSpec();
    final kpiItems = _kpiItems(
      historicalResult,
      parametricResult,
      monteCarloResult,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MethodHeader(
          icon: method.icon,
          color: method.color,
          title: method.title,
          subtitle: method.subtitle,
          insight: insight,
          formula: formula,
        ),
        const SizedBox(height: AppTheme.pageGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final parameterWidth = _resolvedParameterPanelWidth(constraints);
            return SizedBox(
              height: _varMethodCardsHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: parameterWidth,
                    height: double.infinity,
                    child: _MarketCard(
                      padding: const EdgeInsets.all(12),
                      child: _PersistentVarContentStack(
                        activeIndex: method.index,
                        children: [
                          _ParameterStack(
                            title: 'Paramètres de calcul',
                            children: _historicalParameters(),
                          ),
                          _ParameterStack(
                            title: 'Paramètres dynamiques',
                            children: _parametricParameters(
                              parametricResult,
                              defaultVolatility: defaultParamVolatility,
                              defaultPortfolioValue: defaultParamPortfolioValue,
                              defaultDuration: defaultParamDuration,
                            ),
                          ),
                          _ParameterStack(
                            title: 'Paramètres de simulation',
                            children: _monteCarloParameters(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.pageGap),
                  Expanded(
                    child: _MarketCard(
                      child: _PersistentVarContentStack(
                        activeIndex: method.index,
                        children: [
                          _VarChartPanel(
                            title: 'Histogramme des pertes historiques',
                            subtitle:
                                'Distribution observée et seuil de perte VaR',
                            kpis: kpiItems,
                            onResetDefaults: onResetDefaults,
                            child: _HistoricalLossHistogram(
                              result: historicalResult,
                              displayCurrency: displayCurrency,
                            ),
                          ),
                          _VarChartPanel(
                            title: 'Courbe normale Delta-Normale',
                            subtitle:
                                'Quantile normal et zone de perte estimée',
                            kpis: kpiItems,
                            onResetDefaults: onResetDefaults,
                            child: _NormalCurveChart(
                              result: parametricResult,
                              displayCurrency: displayCurrency,
                            ),
                          ),
                          _VarChartPanel(
                            title: 'Distribution P&L simulée',
                            subtitle: 'Scénarios simulés et pertes extrêmes',
                            kpis: kpiItems,
                            onResetDefaults: onResetDefaults,
                            child: _MonteCarloDistributionChart(
                              result: monteCarloResult,
                              displayCurrency: displayCurrency,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _historicalParameters() {
    return [
      _portfolioTypeChoice(),
      _ChoiceGroup<double>(
        label: 'Niveau de confiance',
        value: historicalConfidence,
        values: const [0.95, 0.975, 0.99],
        labelFor: (value) => AppFormatters.percent(value),
        onChanged: onHistoricalConfidenceChanged,
      ),
      _ChoiceGroup<int>(
        label: 'Horizon',
        value: historicalHorizon,
        values: const [1, 3, 10, 21],
        labelFor: _horizonLabel,
        onChanged: onHistoricalHorizonChanged,
      ),
      _ChoiceGroup<int>(
        label: 'Fenêtre historique',
        value: historicalWindow,
        values: const [250, 500, 1000],
        labelFor: _daysLabel,
        onChanged: onHistoricalWindowChanged,
      ),
    ];
  }

  List<Widget> _parametricParameters(
    _ParametricVarResult result, {
    required double defaultVolatility,
    required double defaultPortfolioValue,
    required double defaultDuration,
  }) {
    return [
      _portfolioTypeChoice(),
      _ChoiceGroup<double>(
        label: 'Niveau de confiance',
        value: paramConfidence,
        values: const [0.95, 0.975, 0.99],
        labelFor: (value) => AppFormatters.percent(value),
        onChanged: onParamConfidenceChanged,
      ),
      _ChoiceGroup<int>(
        label: 'Horizon',
        value: paramHorizon,
        values: const [1, 3, 10, 21],
        labelFor: _horizonLabel,
        onChanged: onParamHorizonChanged,
      ),
      _FloatingParametricPanel(
        enabled: method == _VarMethod.parametric,
        result: result,
        displayCurrency: displayCurrency,
        defaultVolatility: defaultVolatility,
        defaultPortfolioValue: defaultPortfolioValue,
        defaultDuration: defaultDuration,
        onVolatilityChanged: onParamVolatilityChanged,
        onPortfolioValueChanged: onParamPortfolioValueChanged,
        onDurationChanged: onParamDurationChanged,
        onResetDefaults: onParamAdvancedDefaultsReset,
      ),
    ];
  }

  List<Widget> _monteCarloParameters() {
    return [
      _portfolioTypeChoice(),
      _ChoiceGroup<int>(
        label: 'Nombre de simulations',
        value: mcSimulations,
        values: const [10000, 50000, 100000],
        labelFor: (value) => value >= 1000 ? '${value ~/ 1000} 000' : '$value',
        onChanged: onMcSimulationsChanged,
      ),
      _ChoiceGroup<_MonteCarloDistribution>(
        label: 'Distribution',
        value: mcDistribution,
        values: _MonteCarloDistribution.values,
        labelFor: (value) => value.label,
        onChanged: onMcDistributionChanged,
      ),
      _ChoiceGroup<int>(
        label: 'Horizon',
        value: mcHorizon,
        values: const [1, 3, 10, 21],
        labelFor: _horizonLabel,
        onChanged: onMcHorizonChanged,
      ),
      _ChoiceGroup<double>(
        label: 'Niveau de confiance',
        value: mcConfidence,
        values: const [0.95, 0.975, 0.99],
        labelFor: (value) => AppFormatters.percent(value),
        onChanged: onMcConfidenceChanged,
      ),
      _SliderParameter(
        label: 'Corrélations',
        value: mcCorrelation,
        min: -0.7,
        max: 0.95,
        divisions: 66,
        display: mcCorrelation.toStringAsFixed(2),
        onChanged: onMcCorrelationChanged,
      ),
    ];
  }

  Widget _portfolioTypeChoice() {
    return _ChoiceGroup<MarketPortfolioType>(
      label: 'Type de portefeuille',
      value: historicalPortfolio,
      values: MarketPortfolioType.values,
      labelFor: (value) => value.label,
      onChanged: onHistoricalPortfolioChanged,
    );
  }

  List<_VarKpiSpec> _kpiItems(
    _HistoricalVarResult historicalResult,
    _ParametricVarResult parametricResult,
    _MonteCarloVarResult monteCarloResult,
  ) {
    return switch (method) {
      _VarMethod.historical => [
          if (historicalResult.losses.isEmpty)
            ...const []
          else ...[
            _VarKpiSpec(
              label: 'Valeur du portefeuille',
              value: _money(portfolio.portfolioValue, displayCurrency),
              detail: historicalPortfolio.label,
              icon: CupertinoIcons.briefcase_fill,
              color: _marketSuccess,
            ),
            _VarKpiSpec(
              label: 'VaR Historique',
              value: _money(historicalResult.varValue, displayCurrency),
              detail:
                  '${AppFormatters.percent(historicalConfidence)} · ${_shortDaysLabel(historicalHorizon)}',
              icon: CupertinoIcons.waveform_circle_fill,
              color: _marketPrimary,
            ),
            _VarKpiSpec(
              label: 'Expected Shortfall',
              value:
                  _money(historicalResult.expectedShortfall, displayCurrency),
              detail: 'Perte moyenne au-delà du seuil',
              icon: CupertinoIcons.chart_bar_square_fill,
              color: _marketViolet,
            ),
            _VarKpiSpec(
              label: 'Pire perte observée',
              value: _money(historicalResult.worstLoss, displayCurrency),
              detail: AppLocalizations.isEnglish
                  ? '${historicalResult.windowDays} recalculated observations'
                  : '${historicalResult.windowDays} observations recalculées',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              color: _marketDanger,
            ),
            _VarKpiSpec(
              label: 'Volatilité historique',
              value: AppFormatters.percent(historicalResult.volatility),
              detail: 'Volatilité annualisée',
              icon: CupertinoIcons.waveform_path_ecg,
              color: _marketCyan,
            ),
            _VarKpiSpec(
              label: 'Queue extrême',
              value: '${historicalResult.tailCount}',
              detail: 'Observations au-delà de la VaR',
              icon: CupertinoIcons.scope,
              color: _marketWarning,
            ),
          ],
        ],
      _VarMethod.parametric => [
          if (!portfolio.hasImportedData ||
              parametricResult.portfolioValue <= 0 ||
              parametricResult.lossStdDev <= 0)
            ...const []
          else ...[
            _VarKpiSpec(
              label: 'Valeur du portefeuille',
              value: _money(parametricResult.portfolioValue, displayCurrency),
              detail: 'Base de calcul',
              icon: CupertinoIcons.briefcase_fill,
              color: _marketSuccess,
            ),
            _VarKpiSpec(
              label: 'VaR Paramétrique',
              value: _money(parametricResult.varValue, displayCurrency),
              detail: 'Z = ${parametricResult.zScore.toStringAsFixed(4)}',
              icon: CupertinoIcons.function,
              color: _marketViolet,
            ),
            _VarKpiSpec(
              label: 'Expected Shortfall',
              value:
                  _money(parametricResult.expectedShortfall, displayCurrency),
              detail: 'Queue normale au-delà du quantile',
              icon: CupertinoIcons.chart_bar_square_fill,
              color: _marketPrimary,
            ),
            _VarKpiSpec(
              label: 'Volatilité',
              value: AppFormatters.percent(parametricResult.annualVolatility),
              detail: 'Entrée principale du modèle',
              icon: CupertinoIcons.waveform_path_ecg,
              color: _marketCyan,
            ),
            _VarKpiSpec(
              label: 'Ratio de Sharpe',
              value: parametricResult.sharpeRatio.toStringAsFixed(2),
              detail: 'Prime de risque / volatilité',
              icon: CupertinoIcons.speedometer,
              color: parametricResult.sharpeRatio >= 0
                  ? _marketSuccess
                  : _marketDanger,
            ),
            _VarKpiSpec(
              label: 'Sensibilité taux',
              value: _money(parametricResult.rateSensitivity, displayCurrency),
              detail: 'Impact indicatif de 100 pb',
              icon: CupertinoIcons.percent,
              color: _marketWarning,
            ),
          ],
        ],
      _VarMethod.monteCarlo => [
          if (monteCarloResult.losses.isEmpty)
            ...const []
          else ...[
            _VarKpiSpec(
              label: 'Valeur du portefeuille',
              value: _money(portfolio.portfolioValue, displayCurrency),
              detail: portfolio.portfolioType.label,
              icon: CupertinoIcons.briefcase_fill,
              color: _marketSuccess,
            ),
            _VarKpiSpec(
              label: 'VaR Monte-Carlo',
              value: _money(monteCarloResult.varValue, displayCurrency),
              detail: AppLocalizations.isEnglish
                  ? '${mcSimulations ~/ 1000}k simulated scenarios'
                  : '${mcSimulations ~/ 1000}k scénarios simulés',
              icon: CupertinoIcons.chart_bar_alt_fill,
              color: _marketCyan,
            ),
            _VarKpiSpec(
              label: 'Expected Shortfall',
              value:
                  _money(monteCarloResult.expectedShortfall, displayCurrency),
              detail: 'Moyenne des scénarios de queue',
              icon: CupertinoIcons.chart_bar_square_fill,
              color: _marketViolet,
            ),
            _VarKpiSpec(
              label: 'Worst Case',
              value: _money(monteCarloResult.worstCase, displayCurrency),
              detail: 'Pire scénario généré',
              icon: CupertinoIcons.exclamationmark_octagon_fill,
              color: _marketDanger,
            ),
            _VarKpiSpec(
              label: 'Scénarios extrêmes',
              value: '${monteCarloResult.extremeScenarioCount}',
              detail: 'Observations au-delà de la VaR',
              icon: CupertinoIcons.scope,
              color: _marketWarning,
            ),
            _VarKpiSpec(
              label: 'Distribution',
              value: mcDistribution.label,
              detail: AppLocalizations.isEnglish
                  ? 'Correlation ${mcCorrelation.toStringAsFixed(2)}'
                  : 'Corrélation ${mcCorrelation.toStringAsFixed(2)}',
              icon: CupertinoIcons.link,
              color: _marketPrimary,
            ),
          ],
        ],
    };
  }

  _VarInsightSpec _insight(_HistoricalVarResult historicalResult) {
    return switch (method) {
      _VarMethod.historical => _VarInsightSpec(
          color: _marketPrimary,
          title: 'Comprendre la lecture historique',
          body: AppLocalizations.isEnglish
              ? 'With a confidence level of ${AppFormatters.percent(historicalConfidence)}, '
                  'the loss over ${_daysLabel(historicalHorizon)} does not exceed ${_money(historicalResult.varValue, displayCurrency)} '
                  'in most historical scenarios. '
                  '${AppFormatters.percent(1 - historicalConfidence)} of observations exceed this threshold; '
                  'in this extreme zone, the expected average loss rises to ${_money(historicalResult.expectedShortfall, displayCurrency)}.'
              : 'Avec un niveau de confiance de ${AppFormatters.percent(historicalConfidence)}, '
                  'la perte sur $historicalHorizon jour(s) ne dépasse pas ${_money(historicalResult.varValue, displayCurrency)} '
                  'dans la majorité des scénarios historiques. '
                  '${AppFormatters.percent(1 - historicalConfidence)} des observations dépassent ce seuil ; '
                  'dans cette zone extrême, la perte moyenne attendue monte à ${_money(historicalResult.expectedShortfall, displayCurrency)}.',
        ),
      _VarMethod.parametric => const _VarInsightSpec(
          color: _marketViolet,
          title: 'Comprendre la formule paramétrique',
          body: 'La volatilité définit l’amplitude normale des mouvements. '
              'Le niveau de confiance fixe le quantile Zα : plus il est élevé, plus la perte retenue est prudente. '
              'Pour les obligations, la VaR Delta-Normale applique Z, σ, Dmod, PV et √(T/252). Pour les actions, le facteur de sensibilité reste égal à 1.',
        ),
      _VarMethod.monteCarlo => const _VarInsightSpec(
          color: _marketCyan,
          title: 'Comprendre la simulation Monte-Carlo',
          body:
              'Chaque scénario projette une trajectoire possible du portefeuille. '
              'Les corrélations relient les facteurs de marché, puis le portefeuille est revalorisé. '
              'La VaR correspond au quantile de perte extrait de la distribution simulée ; les scénarios extrêmes alimentent l’Expected Shortfall.',
          footer: _SimulationPipeline(onDark: true),
        ),
    };
  }

  _VarFormulaSpec _formulaSpec() {
    return switch (method) {
      _VarMethod.historical => const _VarFormulaSpec(
          color: _marketPrimary,
          title: 'Formules - VaR historique',
          formulas: [
            r'R_t=\frac{P_t-P_{t-1}}{P_{t-1}}',
            r'\mathrm{VaR}_{\alpha,1j}=-Q_{1-\alpha}(R)\times V',
            r'\mathrm{VaR}_{\alpha,T}=\mathrm{VaR}_{\alpha,1j}\times\sqrt{T}',
            r'\widehat{\mathrm{ES}}_{\alpha,T}=\mathbb{E}\left[L\mid L\geq \widehat{\mathrm{VaR}}_{\alpha,T}\right]',
          ],
          variables:
              'Rₜ : rendement historique ; V : valeur du portefeuille ; α : niveau de confiance ; T : horizon en jours ; Q : quantile empirique.',
        ),
      _VarMethod.parametric => const _VarFormulaSpec(
          color: _marketViolet,
          title: 'Formules - VaR paramétrique',
          formulas: [
            r'\sigma_{1j}=\frac{\sigma_{\mathrm{annuelle}}}{\sqrt{252}}',
            r'\kappa=D_{\mathrm{mod}}\ \mathrm{(obligations)},\quad \kappa=1\ \mathrm{(actions)}',
            r'\mathrm{VaR}_{\alpha,T}=z_{\alpha}\times\sigma_{1j}\times\kappa\times V\times\sqrt{T}',
            r'\mathrm{ES}_{\alpha,T}=\frac{\varphi(z_{\alpha})}{1-\alpha}\times\sigma_{1j}\times\kappa\times V\times\sqrt{T}',
          ],
          variables:
              'zα : quantile normal ; σ : volatilité annualisée convertie en volatilité journalière ; κ : Dmod pour obligations, 1 pour actions ; V : valeur du portefeuille ; T : horizon en jours ; φ : densité normale.',
        ),
      _VarMethod.monteCarlo => const _VarFormulaSpec(
          color: _marketCyan,
          title: 'Formules - VaR Monte-Carlo',
          formulas: [
            r'\varepsilon_i\sim\mathcal{D}(0,1)',
            r'R_i=\mu\frac{T}{252}+\sigma_{1j}\sqrt{T}\,\varepsilon_i',
            r'L_i=-R_i\times V',
            r'\widehat{\mathrm{VaR}}_{\alpha,T}=Q_{\alpha}\left(\{L_i\}_{i=1}^{N}\right)',
            r'\widehat{\mathrm{ES}}_{\alpha,T}=\frac{1}{N_{\alpha}}\sum_{L_i\geq \widehat{\mathrm{VaR}}_{\alpha,T}}L_i',
          ],
          variables:
              'εᵢ : choc aléatoire selon la distribution choisie ; Rᵢ : rendement simulé ; Lᵢ : perte simulée ; V : valeur du portefeuille ; N : scénarios.',
        ),
    };
  }
}

class _PersistentVarContentStack extends StatelessWidget {
  const _PersistentVarContentStack({
    required this.activeIndex,
    required this.children,
  });

  final int activeIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < children.length; index++)
          _PersistentVarContentLayer(
            active: index == activeIndex,
            child: children[index],
          ),
      ],
    );
  }
}

class _PersistentVarContentLayer extends StatelessWidget {
  const _PersistentVarContentLayer({
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: _varMethodTransitionDuration,
          curve: _varMethodTransitionCurve,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0, 0.008),
            duration: _varMethodTransitionDuration,
            curve: _varMethodTransitionCurve,
            child: TickerMode(
              enabled: active,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _VarChartPanel extends StatelessWidget {
  const _VarChartPanel({
    required this.title,
    required this.subtitle,
    required this.kpis,
    required this.onResetDefaults,
    required this.child,
  });

  final String title;
  final String subtitle;
  final List<_VarKpiSpec> kpis;
  final VoidCallback onResetDefaults;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = constraints.maxWidth < 920 ? 280.0 : 340.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: titleWidth),
                  child: _SectionTitle(title: title, subtitle: subtitle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VarHeaderKpiStrip(items: kpis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _VarResetDefaultsButton(onPressed: onResetDefaults),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VarResetDefaultsButton extends StatefulWidget {
  const _VarResetDefaultsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_VarResetDefaultsButton> createState() =>
      _VarResetDefaultsButtonState();
}

class _VarResetDefaultsButtonState extends State<_VarResetDefaultsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final surface = _marketSurfaceFor(context);
    final border = _marketBorderFor(context);
    final muted = _marketMutedFor(context);

    return Tooltip(
      message: 'Réinitialiser les paramètres par défaut'.tr(context),
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  _hovered ? _marketPrimary.withValues(alpha: 0.10) : surface,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    _hovered ? _marketPrimary.withValues(alpha: 0.32) : border,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: _marketPrimary.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              CupertinoIcons.arrow_counterclockwise,
              size: 15,
              color: _hovered ? _marketPrimary : muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _VarInsightSpec {
  const _VarInsightSpec({
    required this.color,
    required this.title,
    required this.body,
    this.footer,
  });

  final Color color;
  final String title;
  final String body;
  final Widget? footer;
}

class _VarFormulaSpec {
  const _VarFormulaSpec({
    required this.color,
    required this.title,
    required this.formulas,
    required this.variables,
  });

  final Color color;
  final String title;
  final List<String> formulas;
  final String variables;
}

String _horizonLabel(int value) {
  if (value == 1) {
    return AppLocalizations.isEnglish ? '1 day' : '1 jour';
  }
  if (value == 3) {
    return AppLocalizations.isEnglish ? '3 days' : '3 jours';
  }
  if (value == 10) {
    return AppLocalizations.isEnglish ? '10 days' : '10 jours';
  }
  return AppLocalizations.isEnglish ? '1 month' : '1 mois';
}

class _VarMethodSwitch extends StatelessWidget {
  const _VarMethodSwitch({
    required this.selected,
    required this.onChanged,
  });

  final _VarMethod selected;
  final ValueChanged<_VarMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final surface = _marketSurfaceFor(context);
    final border = _marketBorderFor(context);
    final muted = _marketMutedFor(context);

    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF334155).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: _varMethodTabWidth * _VarMethod.values.length,
        height: double.infinity,
        child: Stack(
          children: [
            AnimatedPositioned(
              left: selected.index * _varMethodTabWidth,
              top: 0,
              bottom: 0,
              width: _varMethodTabWidth,
              duration: _varMethodTransitionDuration,
              curve: _varMethodTransitionCurve,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _marketPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _marketPrimary.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final method in _VarMethod.values)
                  SizedBox(
                    width: _varMethodTabWidth,
                    height: double.infinity,
                    child: InkWell(
                      onTap: () => onChanged(method),
                      borderRadius: BorderRadius.circular(5),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: _varMethodTransitionDuration,
                          curve: _varMethodTransitionCurve,
                          style: TextStyle(
                            color: selected == method ? _marketPrimary : muted,
                            fontSize: 10.4,
                            fontWeight: selected == method
                                ? FontWeight.w600
                                : FontWeight.w500,
                            letterSpacing: 0,
                          ),
                          child: Text(method.label.tr(context)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodHeader extends StatelessWidget {
  const _MethodHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.insight,
    required this.formula,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final _VarInsightSpec insight;
  final _VarFormulaSpec formula;

  @override
  Widget build(BuildContext context) {
    final textColor = _marketTextFor(context);
    final mutedColor = _marketMutedFor(context);

    return _MarketCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _MethodInsightIcon(
            icon: icon,
            color: color,
            insight: insight,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr(context),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.tr(context),
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _FormulaDetailsButton(spec: formula),
        ],
      ),
    );
  }
}

class _MethodInsightIcon extends StatefulWidget {
  const _MethodInsightIcon({
    required this.icon,
    required this.color,
    required this.insight,
  });

  final IconData icon;
  final Color color;
  final _VarInsightSpec insight;

  @override
  State<_MethodInsightIcon> createState() => _MethodInsightIconState();
}

class _MethodInsightIconState extends State<_MethodInsightIcon> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;
  Timer? _hideTimer;
  bool _isVisible = false;

  void _showTooltip() {
    _hideTimer?.cancel();
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
    if (mounted) {
      setState(() => _isVisible = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 180), _hideTooltip);
  }

  void _hideTooltip() {
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
    if (mounted) {
      setState(() => _isVisible = false);
    }
  }

  @override
  void didUpdateWidget(covariant _MethodInsightIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _entry?.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.centerRight,
            followerAnchor: Alignment.centerLeft,
            offset: const Offset(10, 0),
            child: MouseRegion(
              onEnter: (_) => _hideTimer?.cancel(),
              onExit: (_) => _scheduleHide(),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset((1 - value) * -6, 0),
                        child: Transform.scale(
                          scale: 0.985 + value * 0.015,
                          alignment: Alignment.centerLeft,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _MethodInsightTooltip(insight: widget.insight),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        onEnter: (_) => _showTooltip(),
        onExit: (_) => _scheduleHide(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _isVisible ? 0.16 : 0.11),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.color.withValues(alpha: _isVisible ? 0.42 : 0.28),
            ),
            boxShadow: _isVisible
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(widget.icon, color: widget.color, size: 17),
        ),
      ),
    );
  }
}

class _MethodInsightTooltip extends StatelessWidget {
  const _MethodInsightTooltip({required this.insight});

  final _VarInsightSpec insight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _marketText.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: insight.color.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title.tr(context),
                        style: TextStyle(
                          color: insight.color,
                          fontSize: 12.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        insight.body.tr(context),
                        style: const TextStyle(
                          color: Color(0xFFE5EDF8),
                          fontSize: 10.8,
                          fontWeight: FontWeight.w400,
                          height: 1.42,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (insight.footer != null) ...[
              const SizedBox(height: 12),
              insight.footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _FormulaDetailsButton extends StatefulWidget {
  const _FormulaDetailsButton({required this.spec});

  final _VarFormulaSpec spec;

  @override
  State<_FormulaDetailsButton> createState() => _FormulaDetailsButtonState();
}

class _FormulaDetailsButtonState extends State<_FormulaDetailsButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;
  Timer? _hideTimer;
  bool _isVisible = false;

  void _showTooltip() {
    _hideTimer?.cancel();
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
    if (mounted) {
      setState(() => _isVisible = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 180), _hideTooltip);
  }

  void _hideTooltip() {
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
    if (mounted) {
      setState(() => _isVisible = false);
    }
  }

  @override
  void didUpdateWidget(covariant _FormulaDetailsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _entry?.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 42),
            child: MouseRegion(
              onEnter: (_) => _hideTimer?.cancel(),
              onExit: (_) => _scheduleHide(),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * -5),
                        child: Transform.scale(
                          scale: 0.985 + value * 0.015,
                          alignment: Alignment.topRight,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _FormulaDetailsTooltip(spec: widget.spec),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        onEnter: (_) => _showTooltip(),
        onExit: (_) => _scheduleHide(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _entry == null ? _showTooltip : _hideTooltip,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            scale: _isVisible ? 1.04 : 1,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.spec.color
                      .withValues(alpha: _isVisible ? 0.42 : 0.26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.spec.color.withValues(
                      alpha: _isVisible ? 0.16 : 0.10,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                'Σ',
                style: TextStyle(
                  color: widget.spec.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormulaDetailsTooltip extends StatelessWidget {
  const _FormulaDetailsTooltip({required this.spec});

  final _VarFormulaSpec spec;

  @override
  Widget build(BuildContext context) {
    final surface = _marketSurfaceFor(context);
    final textColor = _marketTextFor(context);
    final maxWidth = math.max(
      360.0,
      math.min(640.0, MediaQuery.sizeOf(context).width - 24),
    );
    final maxHeight = math.max(
      360.0,
      MediaQuery.sizeOf(context).height - 170,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: spec.color.withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF13203A).withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: spec.color.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                      border:
                          Border.all(color: spec.color.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      'Σ',
                      style: TextStyle(
                        color: spec.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      spec.title.tr(context),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13.4,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FormulaTextSection(
                title: 'Formules de calcul',
                color: spec.color,
                child: Column(
                  children: [
                    for (var index = 0;
                        index < spec.formulas.length;
                        index++) ...[
                      _FormulaMathBlock(
                        latex: spec.formulas[index],
                      ),
                      if (index < spec.formulas.length - 1)
                        const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _FormulaTextSection(
                title: 'Variables',
                color: spec.color,
                body: spec.variables,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormulaMathBlock extends StatelessWidget {
  const _FormulaMathBlock({
    required this.latex,
  });

  final String latex;

  @override
  Widget build(BuildContext context) {
    final textColor = _marketTextFor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: fm.Math.tex(
          latex,
          mathStyle: fm.MathStyle.display,
          textStyle: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FormulaTextSection extends StatelessWidget {
  const _FormulaTextSection({
    required this.title,
    required this.color,
    this.body,
    this.child,
  });

  final String title;
  final Color color;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final surfaceSoft = _marketSurfaceSoftFor(context);
    final muted = _marketMutedFor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceSoft,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                title.tr(context),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (child != null)
            child!
          else
            Text(
              (body ?? '').tr(context),
              style: TextStyle(
                color: muted,
                fontSize: 10.2,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}

double _resolvedParameterPanelWidth(BoxConstraints constraints) {
  final maxWidth = constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : _varParameterPanelWidth;
  return math.min(maxWidth, _varParameterPanelWidth);
}

class _ParameterStack extends StatelessWidget {
  const _ParameterStack({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textColor = _marketTextFor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr(context),
          style: TextStyle(
            color: textColor,
            fontSize: 13.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final surface = _marketSurfaceSoftFor(context);
    final border = _marketBorderFor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InputLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 34,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color:
                surface.withValues(alpha: _isMarketDark(context) ? 0.72 : 0.94),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: border.withValues(alpha: 0.95),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF334155).withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < values.length; index++) ...[
                Expanded(
                  child: _ChoiceSegment<T>(
                    item: values[index],
                    selected: values[index] == value,
                    label: labelFor(values[index]),
                    onTap: () => onChanged(values[index]),
                  ),
                ),
                if (index < values.length - 1)
                  Container(
                    width: 0.8,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: values[index] == value || values[index + 1] == value
                        ? Colors.transparent
                        : border.withValues(alpha: 0.72),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceSegment<T> extends StatelessWidget {
  const _ChoiceSegment({
    required this.item,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final T item;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);
    final isPortfolioChoice = item is MarketPortfolioType;
    final selectedColor =
        isPortfolioChoice ? _marketDashboardDeepBlue : _marketPrimary;
    final unselectedTextColor = isPortfolioChoice
        ? _marketTextFor(context).withValues(alpha: 0.86)
        : muted.withValues(alpha: 0.9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: isPortfolioChoice ? 0.98 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: isPortfolioChoice ? 1 : 0.24)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(
                        alpha: isPortfolioChoice ? 0.18 : 0.075),
                    blurRadius: isPortfolioChoice ? 8 : 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.tr(context),
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? (isPortfolioChoice ? Colors.white : _marketPrimary)
                    : unselectedTextColor,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingParametricPanel extends StatefulWidget {
  const _FloatingParametricPanel({
    required this.enabled,
    required this.result,
    required this.displayCurrency,
    required this.defaultVolatility,
    required this.defaultPortfolioValue,
    required this.defaultDuration,
    required this.onVolatilityChanged,
    required this.onPortfolioValueChanged,
    required this.onDurationChanged,
    required this.onResetDefaults,
  });

  final bool enabled;
  final _ParametricVarResult result;
  final String displayCurrency;
  final double defaultVolatility;
  final double defaultPortfolioValue;
  final double defaultDuration;
  final ValueChanged<double> onVolatilityChanged;
  final ValueChanged<double> onPortfolioValueChanged;
  final ValueChanged<double> onDurationChanged;
  final VoidCallback onResetDefaults;

  @override
  State<_FloatingParametricPanel> createState() =>
      _FloatingParametricPanelState();
}

class _FloatingParametricPanelState extends State<_FloatingParametricPanel> {
  static const double _panelWidth = 300;
  static const double _panelHeightEstimate = 260;
  static const double _panelLift = 48;
  static const double _panelTopMargin = 16;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;
  Timer? _hideTimer;
  bool _isOpen = false;
  bool _isHovering = false;
  _FloatingPanelPlacement _placement = _FloatingPanelPlacement.right;
  double _rightPanelLift = _panelLift;

  void _handleEnter() {
    if (!widget.enabled) {
      return;
    }
    _isHovering = true;
    _showPanel();
  }

  void _handleExit() {
    _isHovering = false;
    _scheduleHide();
  }

  void _showPanel() {
    if (!widget.enabled) {
      return;
    }
    _hideTimer?.cancel();
    _updatePlacement();
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
    if (mounted) {
      setState(() => _isOpen = true);
    }
  }

  void _updatePlacement() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    final triggerBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || triggerBox == null || !triggerBox.hasSize) {
      _placement = _FloatingPanelPlacement.right;
      return;
    }

    final triggerOrigin = triggerBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final triggerSize = triggerBox.size;
    final spaceRight =
        overlayBox.size.width - triggerOrigin.dx - triggerSize.width;
    final spaceBelow =
        overlayBox.size.height - triggerOrigin.dy - triggerSize.height;
    final spaceAbove = triggerOrigin.dy;
    _rightPanelLift = math.min(
      _panelLift,
      math.max(0, triggerOrigin.dy - _panelTopMargin),
    );

    if (spaceRight >= _panelWidth + 14) {
      _placement = _FloatingPanelPlacement.right;
    } else if (spaceBelow >= _panelHeightEstimate || spaceBelow >= spaceAbove) {
      _placement = _FloatingPanelPlacement.down;
    } else {
      _placement = _FloatingPanelPlacement.up;
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_isHovering) {
      return;
    }

    _hideTimer = Timer(const Duration(milliseconds: 220), _hidePanel);
  }

  void _hidePanel({bool notify = true}) {
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
    _isHovering = false;
    if (notify && mounted) {
      setState(() => _isOpen = false);
    } else {
      _isOpen = false;
    }
  }

  @override
  void didUpdateWidget(covariant _FloatingParametricPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _hidePanel(notify: false);
      return;
    }
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _entry?.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    final targetAnchor = switch (_placement) {
      _FloatingPanelPlacement.right => Alignment.topRight,
      _FloatingPanelPlacement.down => Alignment.bottomLeft,
      _FloatingPanelPlacement.up => Alignment.topLeft,
    };
    final followerAnchor = switch (_placement) {
      _FloatingPanelPlacement.right => Alignment.topLeft,
      _FloatingPanelPlacement.down => Alignment.topLeft,
      _FloatingPanelPlacement.up => Alignment.bottomLeft,
    };
    final offset = switch (_placement) {
      _FloatingPanelPlacement.right => Offset(8, -_rightPanelLift),
      _FloatingPanelPlacement.down => const Offset(0, 8),
      _FloatingPanelPlacement.up => const Offset(0, -8),
    };

    return Positioned.fill(
      child: Stack(
        children: [
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: targetAnchor,
            followerAnchor: followerAnchor,
            offset: offset,
            child: MouseRegion(
              onEnter: (_) => _handleEnter(),
              onExit: (_) => _handleExit(),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final entranceOffset = switch (_placement) {
                      _FloatingPanelPlacement.right =>
                        Offset((1 - value) * -8, 0),
                      _FloatingPanelPlacement.down =>
                        Offset(0, (1 - value) * -6),
                      _FloatingPanelPlacement.up => Offset(0, (1 - value) * 6),
                    };
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: entranceOffset,
                        child: Transform.scale(
                          scale: 0.985 + value * 0.015,
                          alignment: Alignment.topLeft,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _floatingContent(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingContent(BuildContext context) {
    final volatilityMax = math.max(
      0.15,
      math.max(widget.defaultVolatility, widget.result.annualVolatility) * 2,
    );
    final portfolioMax = math.max(
      1.0,
      math.max(widget.defaultPortfolioValue, widget.result.portfolioValue) * 2,
    );
    final durationMax = math.max(
      12.0,
      math.max(widget.defaultDuration, widget.result.duration) * 2,
    );

    return Container(
      width: _panelWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _marketPrimary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _marketPrimary.withValues(alpha: 0.08),
            blurRadius: 38,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _marketPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _marketPrimary.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.settings_solid,
                  color: _marketPrimary,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paramètres avancés'.tr(context),
                  style: TextStyle(
                    color: _marketTextFor(context),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Delta-Normale'.tr(context),
                style: TextStyle(
                  color: _marketPrimary.withValues(alpha: 0.82),
                  fontSize: 8.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Réinitialiser'.tr(context),
                button: true,
                child: InkWell(
                  onTap: widget.onResetDefaults,
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _marketPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: _marketPrimary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_counterclockwise,
                      color: _marketPrimary,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _SliderParameter(
            label: 'Volatilité σ',
            value: widget.result.annualVolatility
                .clamp(0.0, volatilityMax)
                .toDouble(),
            min: 0,
            max: volatilityMax,
            divisions: 150,
            display: AppFormatters.percent(widget.result.annualVolatility),
            onChanged: widget.onVolatilityChanged,
          ),
          _SliderParameter(
            label: 'Valeur du portefeuille',
            value: widget.result.portfolioValue
                .clamp(0.0, portfolioMax)
                .toDouble(),
            min: 0,
            max: portfolioMax,
            divisions: 120,
            display:
                _money(widget.result.portfolioValue, widget.displayCurrency),
            onChanged: widget.onPortfolioValueChanged,
          ),
          _SliderParameter(
            label: 'Duration modifiée',
            value: widget.result.duration.clamp(0.0, durationMax).toDouble(),
            min: 0,
            max: durationMax,
            divisions: 120,
            display: widget.result.duration.toStringAsFixed(2),
            onChanged: widget.onDurationChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceSoft = _marketSurfaceSoftFor(context);
    final border = _marketBorderFor(context);
    final textColor = _marketTextFor(context);
    final mutedColor = _marketMutedFor(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _handleEnter(),
        onExit: (_) => _handleExit(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color:
                _isOpen ? _marketPrimary.withValues(alpha: 0.1) : surfaceSoft,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _isOpen ? _marketPrimary.withValues(alpha: 0.28) : border,
            ),
            boxShadow: _isOpen
                ? [
                    BoxShadow(
                      color: _marketPrimary.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _marketPrimary.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.settings_solid,
                  color: _marketPrimary,
                  size: 12,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paramètres avancés'.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 9.7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${AppFormatters.percent(widget.result.annualVolatility)} · ${_money(widget.result.portfolioValue, widget.displayCurrency)}'
                          .tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 170),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: Icon(
                  _isOpen
                      ? switch (_placement) {
                          _FloatingPanelPlacement.right =>
                            Icons.keyboard_arrow_right_rounded,
                          _FloatingPanelPlacement.down =>
                            Icons.keyboard_arrow_down_rounded,
                          _FloatingPanelPlacement.up =>
                            Icons.keyboard_arrow_up_rounded,
                        }
                      : Icons.keyboard_arrow_right_rounded,
                  key: ValueKey('${_isOpen}_$_placement'),
                  color: _marketPrimary,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderParameter extends StatelessWidget {
  const _SliderParameter({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = _marketTextFor(context);
    final inactiveTrackColor = _isMarketDark(context)
        ? const Color(0xFF223452)
        : const Color(0xFFE8EEF8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _InputLabel(label)),
            Text(
              display,
              style: TextStyle(
                color: textColor,
                fontSize: 9.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _marketPrimary,
            inactiveTrackColor: inactiveTrackColor,
            thumbColor: _marketPrimary,
            overlayColor: _marketPrimary.withValues(alpha: 0.12),
            trackHeight: 2.4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: SizedBox(
            height: 28,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = _marketMutedFor(context);

    return Text(
      label.tr(context),
      style: TextStyle(
        color: muted,
        fontSize: 9.6,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textColor = _marketTextFor(context);
    final mutedColor = _marketMutedFor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr(context),
          style: TextStyle(
            color: textColor,
            fontSize: 13.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle.tr(context),
          style: TextStyle(
            color: mutedColor,
            fontSize: 9.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VarHeaderKpiStrip extends StatelessWidget {
  const _VarHeaderKpiStrip({required this.items});

  final List<_VarKpiSpec> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cardWidth = 104.0;
        const gap = 5.0;
        const stripHeight = 34.0;
        final contentWidth =
            items.length * cardWidth + math.max(0, items.length - 1) * gap;
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              SizedBox(
                width: cardWidth,
                height: stripHeight,
                child: _VarMiniKpiCard(item: items[index]),
              ),
              if (index < items.length - 1) const SizedBox(width: gap),
            ],
          ],
        );

        if (contentWidth <= constraints.maxWidth) {
          return SizedBox(
            height: stripHeight,
            child: Align(alignment: Alignment.topRight, child: row),
          );
        }

        return SizedBox(
          height: stripHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: row,
          ),
        );
      },
    );
  }
}

class _VarMiniKpiCard extends StatelessWidget {
  const _VarMiniKpiCard({required this.item});

  final _VarKpiSpec item;

  @override
  Widget build(BuildContext context) {
    final surface = _marketSurfaceFor(context);
    final muted = _marketMutedFor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: _isMarketDark(context) ? 0.72 : 0.92),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: item.color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF334155).withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(item.icon, size: 9, color: item.color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.value,
                      maxLines: 1,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: 0,
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
  }
}

class _VarKpiSpec {
  const _VarKpiSpec({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _HistoricalLossHistogram extends StatefulWidget {
  const _HistoricalLossHistogram({
    required this.result,
    required this.displayCurrency,
  });

  final _HistoricalVarResult result;
  final String displayCurrency;

  @override
  State<_HistoricalLossHistogram> createState() =>
      _HistoricalLossHistogramState();
}

class _HistoricalLossHistogramState extends State<_HistoricalLossHistogram> {
  _HistoricalHistogramHover? _hover;

  @override
  void didUpdateWidget(covariant _HistoricalLossHistogram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.animationKey != widget.result.animationKey &&
        _hover != null) {
      _hover = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.losses.isEmpty) {
      return const SizedBox.shrink();
    }
    final metrics = _HistoricalHistogramMetrics.from(widget.result);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: (event) {
            final hover = _hoverFrom(event.localPosition, size, metrics);
            if (hover != _hover) {
              setState(() => _hover = hover);
            }
          },
          onExit: (_) {
            if (_hover != null) setState(() => _hover = null);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(widget.result.animationKey),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 680),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) {
                  return CustomPaint(
                    painter: _HistoricalHistogramPainter(
                      result: widget.result,
                      metrics: metrics,
                      progress: progress,
                      hover: _hover,
                      displayCurrency: widget.displayCurrency,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
              if (_hover != null)
                Positioned(
                  left: _tooltipX(_hover!.position.dx, size.width),
                  top: _tooltipY(_hover!.position.dy, size.height),
                  child: _HistoricalHistogramTooltip(
                    hover: _hover!,
                    result: widget.result,
                    metrics: metrics,
                    displayCurrency: widget.displayCurrency,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  _HistoricalHistogramHover? _hoverFrom(
    Offset position,
    Size size,
    _HistoricalHistogramMetrics metrics,
  ) {
    if (metrics.bins.isEmpty || size.width <= 0 || size.height <= 0) {
      return null;
    }
    final chart = _HistoricalHistogramPainter.chartBounds(size);
    if (!chart.inflate(14).contains(position)) return null;

    final varX = metrics.xForLoss(chart, widget.result.varValue);
    final p95X = metrics.xForLoss(chart, metrics.percentile95);
    final p99X = metrics.xForLoss(chart, metrics.percentile99);

    if ((position.dx - varX).abs() <= 9) {
      return _HistoricalHistogramHover(
        kind: _HistoricalHoverKind.varLine,
        position: Offset(varX, position.dy),
      );
    }
    if ((position.dx - p99X).abs() <= 8) {
      return _HistoricalHistogramHover(
        kind: _HistoricalHoverKind.percentile99,
        position: Offset(p99X, position.dy),
      );
    }
    if ((position.dx - p95X).abs() <= 8) {
      return _HistoricalHistogramHover(
        kind: _HistoricalHoverKind.percentile95,
        position: Offset(p95X, position.dy),
      );
    }
    if (!chart.contains(position)) return null;

    final width = chart.width / metrics.bins.length;
    final index = ((position.dx - chart.left) / width)
        .floor()
        .clamp(0, metrics.bins.length - 1);
    return _HistoricalHistogramHover(
      kind: _HistoricalHoverKind.bin,
      binIndex: index,
      position: Offset(
        chart.left + width * (index + 0.5),
        position.dy.clamp(chart.top, chart.bottom),
      ),
    );
  }

  double _tooltipX(double x, double width) {
    return (x + 12).clamp(8.0, math.max(8.0, width - 318));
  }

  double _tooltipY(double y, double height) {
    return (y - 88).clamp(8.0, math.max(8.0, height - 116));
  }
}

class _HistoricalHistogramPainter extends CustomPainter {
  const _HistoricalHistogramPainter({
    required this.result,
    required this.metrics,
    required this.progress,
    required this.hover,
    required this.displayCurrency,
  });

  final _HistoricalVarResult result;
  final _HistoricalHistogramMetrics metrics;
  final double progress;
  final _HistoricalHistogramHover? hover;
  final String displayCurrency;

  static Rect chartBounds(Size size) {
    return Rect.fromLTWH(
      66,
      34,
      math.max(1, size.width - 92),
      math.max(1, size.height - 76),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chart = chartBounds(size);
    if (metrics.bins.isEmpty) return;

    _drawHistoricalDepth(canvas, chart);
    _drawHistoricalGrid(canvas, chart, metrics, displayCurrency);
    _paintHistoricalTailWash(canvas, chart, metrics, result);

    for (var index = 0; index < result.bins.length; index++) {
      _drawHistoricalBar(canvas, chart, index);
    }

    _drawHistoricalDensity(canvas, chart, metrics);
    _drawHistoricalMarkers(canvas, chart, metrics, result, displayCurrency);
    _drawHistoricalAnnotations(canvas, chart, metrics, result);
    _drawHistoricalHover(canvas, chart, metrics, hover);
  }

  @override
  bool shouldRepaint(covariant _HistoricalHistogramPainter oldDelegate) {
    return true;
  }

  void _drawHistoricalBar(Canvas canvas, Rect chart, int index) {
    final bin = metrics.bins[index];
    final barWidth = chart.width / metrics.bins.length;
    final height = chart.height * (bin.count / metrics.maxCount) * progress;
    final rect = Rect.fromLTWH(
      chart.left + index * barWidth + 2,
      chart.bottom - height,
      math.max(2, barWidth - 4),
      height,
    );
    if (rect.height <= 0) return;

    final midpoint = (bin.start + bin.end) / 2;
    final isTail = bin.end >= result.varValue;
    final isHovered =
        hover?.kind == _HistoricalHoverKind.bin && hover?.binIndex == index;
    final tailProgress = ((midpoint - result.varValue) /
            math.max(1.0, metrics.maxLoss - result.varValue))
        .clamp(0.0, 1.0)
        .toDouble();
    final baseColor = isTail
        ? Color.lerp(_marketWarning, _marketDanger, 0.42 + tailProgress * 0.42)!
        : Color.lerp(_marketPrimary, _marketCyan, 0.16)!;
    final alpha = isHovered
        ? 0.84
        : isTail
            ? 0.55 + tailProgress * 0.16
            : 0.34;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, 2), const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.025),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withValues(alpha: alpha),
            baseColor.withValues(alpha: math.max(0.16, alpha - 0.18)),
          ],
        ).createShader(rect),
    );
  }
}

class _HistoricalHistogramMetrics {
  const _HistoricalHistogramMetrics({
    required this.bins,
    required this.totalObservations,
    required this.maxCount,
    required this.minLoss,
    required this.maxLoss,
    required this.percentile95,
    required this.percentile99,
  });

  final List<_LossBin> bins;
  final int totalObservations;
  final int maxCount;
  final double minLoss;
  final double maxLoss;
  final double percentile95;
  final double percentile99;

  double get span => (maxLoss - minLoss).abs() < 0.01 ? 1.0 : maxLoss - minLoss;

  static _HistoricalHistogramMetrics from(_HistoricalVarResult result) {
    final bins = result.bins;
    return _HistoricalHistogramMetrics(
      bins: bins,
      totalObservations: result.losses.length,
      maxCount: bins.fold<int>(1, (max, bin) => math.max(max, bin.count)),
      minLoss: bins.isEmpty ? 0.0 : bins.first.start,
      maxLoss: bins.isEmpty ? 1.0 : bins.last.end,
      percentile95: _rawQuantile(result.losses, 0.95),
      percentile99: _rawQuantile(result.losses, 0.99),
    );
  }

  double xForLoss(Rect chart, double loss) {
    return (chart.left + ((loss - minLoss) / span) * chart.width)
        .clamp(chart.left, chart.right)
        .toDouble();
  }

  double probabilityForBin(int index) {
    if (totalObservations == 0) return 0;
    return bins[index].count / totalObservations;
  }

  double cumulativeThroughBin(int index) {
    if (totalObservations == 0) return 0;
    final cumulative =
        bins.take(index + 1).fold<int>(0, (sum, bin) => sum + bin.count);
    return cumulative / totalObservations;
  }

  double percentileStartForBin(int index) {
    if (totalObservations == 0) return 0;
    final previous =
        bins.take(index).fold<int>(0, (sum, bin) => sum + bin.count);
    return previous / totalObservations;
  }
}

enum _HistoricalHoverKind { bin, varLine, percentile95, percentile99 }

class _HistoricalHistogramHover {
  const _HistoricalHistogramHover({
    required this.kind,
    required this.position,
    this.binIndex,
  });

  final _HistoricalHoverKind kind;
  final Offset position;
  final int? binIndex;

  @override
  bool operator ==(Object other) {
    return other is _HistoricalHistogramHover &&
        other.kind == kind &&
        other.binIndex == binIndex &&
        (other.position.dx - position.dx).abs() < 0.5 &&
        (other.position.dy - position.dy).abs() < 0.5;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        binIndex,
        position.dx.round(),
        position.dy.round(),
      );
}

class _HistoricalHistogramTooltip extends StatelessWidget {
  const _HistoricalHistogramTooltip({
    required this.hover,
    required this.result,
    required this.metrics,
    required this.displayCurrency,
  });

  final _HistoricalHistogramHover hover;
  final _HistoricalVarResult result;
  final _HistoricalHistogramMetrics metrics;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 308),
      child: _ChartTooltip(
        title: content.title,
        value: content.value,
        detail: content.detail,
      ),
    );
  }

  ({String title, String value, String detail}) _content(BuildContext context) {
    if (hover.kind == _HistoricalHoverKind.varLine) {
      return (
        title: 'Seuil VaR historique',
        value:
            'VaR ${AppFormatters.percent(result.confidence)} : ${_money(result.varValue, displayCurrency)}',
        detail: context.tr(
          '{{count}} observations · {{probability}} au-delà du seuil · ES {{expectedShortfall}}',
          args: {
            'count': result.tailCount,
            'probability': AppFormatters.percent(result.tailProbability),
            'expectedShortfall':
                _money(result.expectedShortfall, displayCurrency),
          },
        ),
      );
    }
    if (hover.kind == _HistoricalHoverKind.percentile95) {
      return (
        title: '95e percentile',
        value: _money(metrics.percentile95, displayCurrency),
        detail:
            'Repère de pertes élevées : 95% des observations historiques restent sous ce niveau.',
      );
    }
    if (hover.kind == _HistoricalHoverKind.percentile99) {
      return (
        title: '99e percentile',
        value: _money(metrics.percentile99, displayCurrency),
        detail:
            'Queue extrême : 1% des observations historiques dépassent ce repère.',
      );
    }

    final index = hover.binIndex!.clamp(0, metrics.bins.length - 1);
    final bin = metrics.bins[index];
    final probability = metrics.probabilityForBin(index);
    final cumulative = metrics.cumulativeThroughBin(index);
    final percentileStart = metrics.percentileStartForBin(index);
    final interval =
        '${_axisMoneyLabel(bin.start, displayCurrency)} → ${_axisMoneyLabel(bin.end, displayCurrency)}';
    return (
      title: 'Intervalle de pertes historiques',
      value: interval,
      detail: context.tr(
        '{{count}} observations · {{probability}} des scénarios · cumul {{cumulative}} · P{{lower}}-P{{upper}}',
        args: {
          'count': bin.count,
          'probability': AppFormatters.percent(probability),
          'cumulative': AppFormatters.percent(cumulative),
          'lower': (percentileStart * 100).toStringAsFixed(1),
          'upper': (cumulative * 100).toStringAsFixed(1),
        },
      ),
    );
  }
}

void _drawHistoricalDepth(Canvas canvas, Rect chart) {
  canvas.drawRect(
    chart,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _marketPrimary.withValues(alpha: 0.020),
          _marketPrimary.withValues(alpha: 0.006),
        ],
      ).createShader(chart),
  );
}

void _drawHistoricalGrid(
  Canvas canvas,
  Rect chart,
  _HistoricalHistogramMetrics metrics,
  String displayCurrency,
) {
  final horizontal = Paint()
    ..color = _marketBorder.withValues(alpha: 0.58)
    ..strokeWidth = 0.85;
  for (var index = 0; index <= 4; index++) {
    final y = chart.top + chart.height * index / 4;
    final count = (metrics.maxCount * (4 - index) / 4).round();
    canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), horizontal);
    _paintAxisLabel(
      canvas,
      '$count',
      Offset(chart.left - 8, y),
      rightAlign: true,
      maxWidth: 48,
    );
  }

  final vertical = Paint()
    ..color = _marketBorder.withValues(alpha: 0.24)
    ..strokeWidth = 0.7;
  for (var index = 1; index < 4; index++) {
    final x = chart.left + chart.width * index / 4;
    canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), vertical);
  }

  _drawLossXAxis(
      canvas, chart, metrics.minLoss, metrics.maxLoss, displayCurrency);
  _paintAxisLabel(
    canvas,
    'Pertes / gains (${_axisUnitLabel(metrics.minLoss, metrics.maxLoss, displayCurrency)})',
    Offset(chart.center.dx, chart.bottom + 29),
    center: true,
    maxWidth: 170,
  );
  _paintAxisLabel(
    canvas,
    'Fréquence',
    Offset(chart.left - 8, chart.top - 12),
    rightAlign: true,
    maxWidth: 56,
  );
  _paintAxisLabel(
    canvas,
    'gains ←',
    Offset(chart.left, chart.bottom + 40),
    maxWidth: 58,
  );
  _paintAxisLabel(
    canvas,
    'pertes sévères →',
    Offset(chart.right, chart.bottom + 40),
    rightAlign: true,
    maxWidth: 96,
  );
}

void _paintHistoricalTailWash(
  Canvas canvas,
  Rect chart,
  _HistoricalHistogramMetrics metrics,
  _HistoricalVarResult result,
) {
  final varX = metrics.xForLoss(chart, result.varValue);
  if (varX >= chart.right) return;
  final rect = Rect.fromLTRB(varX, chart.top, chart.right, chart.bottom);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _marketWarning.withValues(alpha: 0.030),
          _marketDanger.withValues(alpha: 0.080),
        ],
      ).createShader(rect),
  );
}

void _drawHistoricalDensity(
  Canvas canvas,
  Rect chart,
  _HistoricalHistogramMetrics metrics,
) {
  if (metrics.bins.length < 3) return;

  final points = <Offset>[];
  final barWidth = chart.width / metrics.bins.length;
  for (var index = 0; index < metrics.bins.length; index++) {
    final count = _smoothedHistoricalCount(metrics.bins, index);
    final ratio = count / metrics.maxCount;
    final x = chart.left + barWidth * (index + 0.5);
    final y = chart.bottom - chart.height * ratio * 0.88;
    points.add(Offset(x, y));
  }

  final path = _smoothPath(points);
  canvas.drawPath(
    path,
    Paint()
      ..color = _marketPrimary.withValues(alpha: 0.15)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = _marketPrimary.withValues(alpha: 0.58)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

double _smoothedHistoricalCount(List<_LossBin> bins, int index) {
  var weighted = 0.0;
  var weightTotal = 0.0;
  for (var offset = -2; offset <= 2; offset++) {
    final resolved = index + offset;
    if (resolved < 0 || resolved >= bins.length) continue;
    final weight = switch (offset.abs()) {
      0 => 0.38,
      1 => 0.24,
      _ => 0.07,
    };
    weighted += bins[resolved].count * weight;
    weightTotal += weight;
  }
  return weightTotal == 0
      ? bins[index].count.toDouble()
      : weighted / weightTotal;
}

Path _smoothPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var index = 1; index < points.length; index++) {
    final previous = points[index - 1];
    final current = points[index];
    final middle = Offset(
      (previous.dx + current.dx) / 2,
      (previous.dy + current.dy) / 2,
    );
    path.quadraticBezierTo(previous.dx, previous.dy, middle.dx, middle.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

void _drawHistoricalMarkers(
  Canvas canvas,
  Rect chart,
  _HistoricalHistogramMetrics metrics,
  _HistoricalVarResult result,
  String displayCurrency,
) {
  _drawHistoricalPercentileMarker(
    canvas,
    chart,
    metrics,
    loss: metrics.percentile95,
    label: 'P95',
    color: _marketCyan,
    topOffset: 42,
    dashed: true,
  );
  _drawHistoricalPercentileMarker(
    canvas,
    chart,
    metrics,
    loss: metrics.percentile99,
    label: 'P99',
    color: _marketViolet,
    topOffset: 68,
    dashed: true,
  );

  final varX = metrics.xForLoss(chart, result.varValue);
  canvas.drawLine(
    Offset(varX, chart.top + 2),
    Offset(varX, chart.bottom),
    Paint()
      ..color = _marketDanger.withValues(alpha: 0.18)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawLine(
    Offset(varX, chart.top + 2),
    Offset(varX, chart.bottom),
    Paint()
      ..color = _marketDanger
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round,
  );
  _paintParametricPill(
    canvas,
    'VaR ${AppFormatters.percent(result.confidence)} : ${_axisMoneyLabel(result.varValue, displayCurrency)}',
    Offset(math.min(varX + 8, chart.right - 182), chart.top + 6),
    color: _marketDanger,
    maxWidth: 180,
  );
}

void _drawHistoricalPercentileMarker(
  Canvas canvas,
  Rect chart,
  _HistoricalHistogramMetrics metrics, {
  required double loss,
  required String label,
  required Color color,
  required double topOffset,
  bool dashed = false,
}) {
  final x = metrics.xForLoss(chart, loss);
  final paint = Paint()
    ..color = color.withValues(alpha: 0.34)
    ..strokeWidth = 1.1;
  if (dashed) {
    _drawDashedVerticalLine(canvas, x, chart.top + 5, chart.bottom, paint);
  } else {
    canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), paint);
  }
  _paintParametricPill(
    canvas,
    label,
    Offset(
        (x + 8).clamp(chart.left + 2, chart.right - 48), chart.top + topOffset),
    color: color,
    maxWidth: 46,
    compact: true,
  );
}

void _drawDashedVerticalLine(
  Canvas canvas,
  double x,
  double top,
  double bottom,
  Paint paint,
) {
  var y = top;
  while (y < bottom) {
    canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 5, bottom)), paint);
    y += 10;
  }
}

void _drawHistoricalAnnotations(
  Canvas canvas,
  Rect chart,
  _HistoricalHistogramMetrics metrics,
  _HistoricalVarResult result,
) {
  final varX = metrics.xForLoss(chart, result.varValue);
  _paintParametricPill(
    canvas,
    'Distribution historique des pertes',
    Offset(chart.left + 8, chart.top + 8),
    color: _marketPrimary,
    maxWidth: 186,
    compact: true,
  );

  final tailLeft =
      math.max(chart.left + 8, math.min(varX + 14, chart.right - 192));
  _paintParametricPill(
    canvas,
    'Zone des pertes extrêmes',
    Offset(tailLeft, chart.bottom - 78),
    color: _marketWarning,
    maxWidth: 168,
    compact: true,
  );
  _paintParametricPill(
    canvas,
    '${AppFormatters.percent(result.tailProbability)} des observations dépassent ce seuil',
    Offset(tailLeft, chart.bottom - 50),
    color: _marketDanger,
    maxWidth: 190,
    compact: true,
  );
}

void _drawHistoricalHover(
  Canvas canvas,
  Rect chart,
  _HistoricalHistogramMetrics metrics,
  _HistoricalHistogramHover? hover,
) {
  if (hover == null) return;
  final color = switch (hover.kind) {
    _HistoricalHoverKind.varLine => _marketDanger,
    _HistoricalHoverKind.percentile95 => _marketCyan,
    _HistoricalHoverKind.percentile99 => _marketViolet,
    _HistoricalHoverKind.bin => _marketPrimary,
  };
  canvas.drawLine(
    Offset(hover.position.dx, chart.top),
    Offset(hover.position.dx, chart.bottom),
    Paint()
      ..color = color.withValues(alpha: 0.16)
      ..strokeWidth = 1,
  );
}

class _NormalCurveChart extends StatelessWidget {
  const _NormalCurveChart({
    required this.result,
    required this.displayCurrency,
  });

  final _ParametricVarResult result;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    if (result.portfolioValue <= 0 || result.lossStdDev <= 0) {
      return const SizedBox.shrink();
    }
    return _InteractiveNormalCurveChart(
      result: result,
      displayCurrency: displayCurrency,
    );
  }
}

class _InteractiveNormalCurveChart extends StatefulWidget {
  const _InteractiveNormalCurveChart({
    required this.result,
    required this.displayCurrency,
  });

  final _ParametricVarResult result;
  final String displayCurrency;

  @override
  State<_InteractiveNormalCurveChart> createState() =>
      _InteractiveNormalCurveChartState();
}

class _InteractiveNormalCurveChartState
    extends State<_InteractiveNormalCurveChart> {
  _ParametricCurveHover? _hover;

  @override
  Widget build(BuildContext context) {
    final metrics = _ParametricDistributionMetrics.from(widget.result);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: (event) {
            final hover = _hoverFrom(event.localPosition, size, metrics);
            if (hover != _hover) {
              setState(() => _hover = hover);
            }
          },
          onExit: (_) {
            if (_hover != null) setState(() => _hover = null);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(widget.result.animationKey),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 680),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) {
                  return CustomPaint(
                    painter: _NormalCurvePainter(
                      result: widget.result,
                      metrics: metrics,
                      progress: progress,
                      displayCurrency: widget.displayCurrency,
                      hover: _hover,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
              if (_hover != null)
                Positioned(
                  left: _tooltipX(_hover!.position.dx, size.width),
                  top: _tooltipY(_hover!.position.dy, size.height),
                  child: _ParametricCurveTooltip(
                    hover: _hover!,
                    result: widget.result,
                    displayCurrency: widget.displayCurrency,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  _ParametricCurveHover? _hoverFrom(
    Offset position,
    Size size,
    _ParametricDistributionMetrics metrics,
  ) {
    if (size.width <= 0 || size.height <= 0) return null;
    final chart = _NormalCurvePainter.chartBounds(size);
    if (!chart.inflate(12).contains(position)) return null;

    final loss =
        metrics.lossAtX(chart, position.dx.clamp(chart.left, chart.right));
    final curveY = _NormalCurvePainter.yForLoss(chart, metrics, loss, 1);
    final varX = metrics.xForLoss(chart, widget.result.varValue);
    final meanX = metrics.xForLoss(chart, metrics.meanLoss);
    final nearVar = (position.dx - varX).abs() <= 12;
    final nearMean = (position.dx - meanX).abs() <= 9;
    final inTail = loss >= widget.result.varValue && position.dy >= curveY - 16;
    final nearCurve = (position.dy - curveY).abs() <= 18;

    if (!nearVar && !nearMean && !inTail && !nearCurve) return null;

    final clampedLoss = loss.clamp(metrics.minLoss, metrics.maxLoss).toDouble();
    return _ParametricCurveHover(
      position: Offset(position.dx, position.dy),
      loss: clampedLoss,
      percentile: _normalCdf(
        (clampedLoss - metrics.meanLoss) / metrics.stdLoss,
      ),
      density: metrics.pdf(clampedLoss),
      kind: nearVar
          ? _ParametricHoverKind.varLine
          : nearMean
              ? _ParametricHoverKind.mean
              : inTail
                  ? _ParametricHoverKind.tail
                  : _ParametricHoverKind.curve,
    );
  }

  double _tooltipX(double x, double width) {
    return (x + 12).clamp(8.0, math.max(8.0, width - 292));
  }

  double _tooltipY(double y, double height) {
    return (y - 72).clamp(8.0, math.max(8.0, height - 96));
  }
}

class _NormalCurvePainter extends CustomPainter {
  const _NormalCurvePainter({
    required this.result,
    required this.metrics,
    required this.progress,
    required this.displayCurrency,
    required this.hover,
  });

  final _ParametricVarResult result;
  final _ParametricDistributionMetrics metrics;
  final double progress;
  final String displayCurrency;
  final _ParametricCurveHover? hover;

  static Rect chartBounds(Size size) {
    return Rect.fromLTWH(
      58,
      34,
      math.max(1, size.width - 82),
      math.max(1, size.height - 72),
    );
  }

  static double yForLoss(
    Rect chart,
    _ParametricDistributionMetrics metrics,
    double loss,
    double progress,
  ) {
    final densityRatio = metrics.pdf(loss) / metrics.referencePeak;
    final visibleRatio = math.min(1.18, densityRatio) / 1.18;
    return chart.bottom - visibleRatio * chart.height * 0.82 * progress;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chart = chartBounds(size);
    _drawParametricGrid(canvas, chart, metrics);
    _drawParametricAxis(canvas, chart, metrics, displayCurrency);

    final path = Path();
    final fillPath = Path();
    final tailPath = Path();
    const samples = 240;
    var tailStarted = false;

    for (var i = 0; i <= samples; i++) {
      final loss = metrics.minLoss + metrics.span * i / samples;
      final x = metrics.xForLoss(chart, loss);
      final y = yForLoss(chart, metrics, loss, progress);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chart.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (loss >= result.varValue) {
        if (!tailStarted) {
          final varX = metrics.xForLoss(chart, result.varValue);
          final varY = yForLoss(chart, metrics, result.varValue, progress);
          tailPath
            ..moveTo(varX, chart.bottom)
            ..lineTo(varX, varY);
          tailStarted = true;
        }
        tailPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(chart.right, chart.bottom)
      ..close();
    tailPath
      ..lineTo(chart.right, chart.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _marketViolet.withValues(alpha: 0.14),
            _marketViolet.withValues(alpha: 0.025),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      tailPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _marketDanger.withValues(alpha: 0.24),
            _marketWarning.withValues(alpha: 0.10),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _marketViolet.withValues(alpha: 0.18)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _marketViolet
        ..strokeWidth = 2.9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawParametricMarkers(canvas, chart, metrics, result, displayCurrency);
    _drawParametricAnnotations(canvas, chart, metrics, result);
    if (hover != null) {
      _drawParametricHover(canvas, chart, metrics, hover!);
    }
  }

  @override
  bool shouldRepaint(covariant _NormalCurvePainter oldDelegate) {
    return true;
  }
}

class _ParametricDistributionMetrics {
  const _ParametricDistributionMetrics({
    required this.meanLoss,
    required this.stdLoss,
    required this.referenceStd,
    required this.minLoss,
    required this.maxLoss,
  });

  final double meanLoss;
  final double stdLoss;
  final double referenceStd;
  final double minLoss;
  final double maxLoss;

  double get span => math.max(1.0, maxLoss - minLoss);
  double get referencePeak => _normalPdf(0) / referenceStd;

  static _ParametricDistributionMetrics from(_ParametricVarResult result) {
    final stdLoss = math.max(result.lossStdDev, result.portfolioValue * 0.001);
    final meanLoss = -result.drift;
    final referenceStd = math.max(
      result.portfolioValue * (0.032 / math.sqrt(252)) * math.sqrt(10),
      result.portfolioValue * 0.01,
    );
    final left = [
      meanLoss - referenceStd * 2.35,
      meanLoss - stdLoss * 3.6,
      -referenceStd * 0.95,
    ].reduce(math.min);
    final right = [
      meanLoss + referenceStd * 3.15,
      meanLoss + stdLoss * 3.65,
      result.varValue * 1.15,
      referenceStd * 1.8,
    ].reduce(math.max);

    return _ParametricDistributionMetrics(
      meanLoss: meanLoss,
      stdLoss: stdLoss,
      referenceStd: referenceStd,
      minLoss: left,
      maxLoss: right,
    );
  }

  double pdf(double loss) {
    final z = (loss - meanLoss) / stdLoss;
    return _normalPdf(z) / stdLoss;
  }

  double xForLoss(Rect chart, double loss) {
    return chart.left + ((loss - minLoss) / span) * chart.width;
  }

  double lossAtX(Rect chart, double x) {
    final ratio = ((x - chart.left) / chart.width).clamp(0.0, 1.0);
    return minLoss + ratio * span;
  }
}

enum _ParametricHoverKind { curve, mean, varLine, tail }

class _ParametricCurveHover {
  const _ParametricCurveHover({
    required this.position,
    required this.loss,
    required this.percentile,
    required this.density,
    required this.kind,
  });

  final Offset position;
  final double loss;
  final double percentile;
  final double density;
  final _ParametricHoverKind kind;
}

class _ParametricCurveTooltip extends StatelessWidget {
  const _ParametricCurveTooltip({
    required this.hover,
    required this.result,
    required this.displayCurrency,
  });

  final _ParametricCurveHover hover;
  final _ParametricVarResult result;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final exceedance = AppFormatters.percent(1 - result.confidence);
    final horizon = _horizonLabel(result.horizonDays);
    final title = switch (hover.kind) {
      _ParametricHoverKind.varLine => 'Seuil VaR Delta-Normale',
      _ParametricHoverKind.tail => 'Queue de pertes extrêmes',
      _ParametricHoverKind.mean => 'Moyenne μ',
      _ParametricHoverKind.curve => 'Distribution des pertes',
    };
    final value = switch (hover.kind) {
      _ParametricHoverKind.varLine =>
        'VaR ${AppFormatters.percent(result.confidence)} : ${_money(result.varValue, displayCurrency)}',
      _ParametricHoverKind.mean => 'μ : ${_money(hover.loss, displayCurrency)}',
      _ => _money(hover.loss, displayCurrency),
    };
    final detail = switch (hover.kind) {
      _ParametricHoverKind.varLine => context.tr(
          'Perte maximale probable sur {{horizon}} ; {{exceedance}} des scénarios dépassent ce seuil.',
          args: {
            'horizon': horizon,
            'exceedance': exceedance,
          },
        ),
      _ParametricHoverKind.tail => context.tr(
          'Percentile {{percentile}} · zone critique au-delà du quantile.',
          args: {'percentile': AppFormatters.percent(hover.percentile)},
        ),
      _ParametricHoverKind.mean => context.tr(
          'Centre neutre de la distribution Delta-Normale standard.',
        ),
      _ParametricHoverKind.curve => context.tr(
          'Percentile {{percentile}} · σ* {{volatility}}.',
          args: {
            'percentile': AppFormatters.percent(hover.percentile),
            'volatility': AppFormatters.percent(result.effectiveVolatility),
          },
        ),
    };

    return _ChartTooltip(title: title, value: value, detail: detail);
  }
}

void _drawParametricGrid(
  Canvas canvas,
  Rect chart,
  _ParametricDistributionMetrics metrics,
) {
  final horizontal = Paint()
    ..color = _marketBorder.withValues(alpha: 0.60)
    ..strokeWidth = 0.8;
  for (var index = 0; index <= 4; index++) {
    final y = chart.top + chart.height * index / 4;
    canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), horizontal);
  }

  final vertical = Paint()
    ..color = _marketBorder.withValues(alpha: 0.36)
    ..strokeWidth = 0.8;
  for (final loss in [
    metrics.meanLoss - metrics.stdLoss,
    metrics.meanLoss,
    metrics.meanLoss + metrics.stdLoss,
    metrics.meanLoss + metrics.stdLoss * 2,
  ]) {
    if (loss < metrics.minLoss || loss > metrics.maxLoss) continue;
    final x = metrics.xForLoss(chart, loss);
    canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), vertical);
  }
}

void _drawParametricAxis(
  Canvas canvas,
  Rect chart,
  _ParametricDistributionMetrics metrics,
  String displayCurrency,
) {
  final axis = Paint()
    ..color = _marketBorder.withValues(alpha: 0.92)
    ..strokeWidth = 1;
  canvas.drawLine(Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom), axis);

  final ticks = [
    (metrics.minLoss, 'Gain'),
    (0.0, '0'),
    (metrics.meanLoss, 'μ'),
    (metrics.meanLoss + metrics.stdLoss, '+1σ'),
    (metrics.meanLoss + metrics.stdLoss * 2, '+2σ'),
    (metrics.maxLoss, 'Perte'),
  ];

  for (final tick in ticks) {
    if (tick.$1 < metrics.minLoss || tick.$1 > metrics.maxLoss) continue;
    final x = metrics.xForLoss(chart, tick.$1);
    canvas.drawLine(
      Offset(x, chart.bottom),
      Offset(x, chart.bottom + 4),
      axis,
    );
    _paintAxisLabel(
      canvas,
      tick.$2 == '0'
          ? '0'
          : tick.$2 == 'Gain' || tick.$2 == 'Perte'
              ? _axisMoneyLabel(tick.$1, displayCurrency)
              : tick.$2,
      Offset(x, chart.bottom + 10),
      center: true,
      maxWidth: 54,
    );
  }

  _paintParametricLabel(
    canvas,
    'Pertes / gains simulés',
    Offset(chart.center.dx, chart.bottom + 26),
    color: _marketMuted,
    align: TextAlign.center,
    maxWidth: 140,
  );
  _paintParametricLabel(
    canvas,
    'Densité',
    Offset(chart.left - 2, chart.top - 12),
    color: _marketMuted,
    maxWidth: 70,
  );
}

void _drawParametricMarkers(
  Canvas canvas,
  Rect chart,
  _ParametricDistributionMetrics metrics,
  _ParametricVarResult result,
  String displayCurrency,
) {
  final meanX = metrics.xForLoss(chart, metrics.meanLoss);
  final sigmaX = metrics.xForLoss(chart, metrics.meanLoss + metrics.stdLoss);
  final varX = metrics.xForLoss(chart, result.varValue);

  final sigmaPaint = Paint()
    ..color = _marketViolet.withValues(alpha: 0.20)
    ..strokeWidth = 1;
  canvas.drawLine(
      Offset(sigmaX, chart.top + 12), Offset(sigmaX, chart.bottom), sigmaPaint);

  final meanPaint = Paint()
    ..color = _marketPrimary.withValues(alpha: 0.50)
    ..strokeWidth = 1.2;
  canvas.drawLine(
      Offset(meanX, chart.top + 8), Offset(meanX, chart.bottom), meanPaint);
  _paintParametricPill(
    canvas,
    'μ',
    Offset(meanX + 8, chart.top + 14),
    color: _marketPrimary,
  );

  canvas.drawLine(
    Offset(varX, chart.top + 2),
    Offset(varX, chart.bottom),
    Paint()
      ..color = _marketDanger.withValues(alpha: 0.16)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawLine(
    Offset(varX, chart.top + 2),
    Offset(varX, chart.bottom),
    Paint()
      ..color = _marketDanger
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round,
  );

  _paintParametricPill(
    canvas,
    'VaR ${AppFormatters.percent(result.confidence)} : ${_axisMoneyLabel(result.varValue, displayCurrency)} $displayCurrency',
    Offset(math.min(varX + 10, chart.right - 180), chart.top + 8),
    color: _marketDanger,
    maxWidth: 178,
  );
  _paintParametricPill(
    canvas,
    'Quantile Zα ${result.zScore.toStringAsFixed(4)}',
    Offset(math.min(varX + 10, chart.right - 142), chart.top + 38),
    color: _marketWarning,
    maxWidth: 140,
    compact: true,
  );
}

void _drawParametricAnnotations(
  Canvas canvas,
  Rect chart,
  _ParametricDistributionMetrics metrics,
  _ParametricVarResult result,
) {
  final varX = metrics.xForLoss(chart, result.varValue);
  final tailProbability = AppFormatters.percent(1 - result.confidence);
  _paintParametricPill(
    canvas,
    'Distribution des pertes potentielles',
    Offset(chart.left + 10, chart.top + 10),
    color: _marketViolet,
    maxWidth: 184,
    compact: true,
  );

  final tailX = math.min(varX + 18, chart.right - 190);
  _paintParametricPill(
    canvas,
    _marketTr(
      '{{value}} des scénarios dépassent ce seuil',
      args: {'value': tailProbability},
    ),
    Offset(math.max(chart.left + 12, tailX), chart.bottom - 76),
    color: _marketDanger,
    maxWidth: 188,
    compact: true,
  );
  _paintParametricPill(
    canvas,
    'Zone de pertes extrêmes',
    Offset(math.max(chart.left + 12, tailX), chart.bottom - 48),
    color: _marketWarning,
    maxWidth: 160,
    compact: true,
  );

  final sigmaLabelX =
      metrics.xForLoss(chart, metrics.meanLoss + metrics.stdLoss);
  _paintParametricPill(
    canvas,
    'σ* ${AppFormatters.percent(result.effectiveVolatility)}',
    Offset(math.min(sigmaLabelX + 10, chart.right - 90), chart.top + 70),
    color: _marketCyan,
    maxWidth: 88,
    compact: true,
  );
}

void _drawParametricHover(
  Canvas canvas,
  Rect chart,
  _ParametricDistributionMetrics metrics,
  _ParametricCurveHover hover,
) {
  final x = metrics.xForLoss(chart, hover.loss);
  final y = _NormalCurvePainter.yForLoss(chart, metrics, hover.loss, 1);
  final color = switch (hover.kind) {
    _ParametricHoverKind.varLine || _ParametricHoverKind.tail => _marketDanger,
    _ParametricHoverKind.mean => _marketPrimary,
    _ParametricHoverKind.curve => _marketViolet,
  };
  canvas.drawLine(
    Offset(x, chart.top),
    Offset(x, chart.bottom),
    Paint()
      ..color = color.withValues(alpha: 0.20)
      ..strokeWidth = 1,
  );
  canvas.drawCircle(
    Offset(x, y),
    5.5,
    Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    Offset(x, y),
    3.8,
    Paint()..color = _marketSurface,
  );
  canvas.drawCircle(
    Offset(x, y),
    3.8,
    Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke,
  );
}

void _paintParametricPill(
  Canvas canvas,
  String text,
  Offset offset, {
  required Color color,
  double maxWidth = 130,
  bool compact = false,
}) {
  final resolvedText = _marketTr(text);
  final painter = TextPainter(
    text: TextSpan(
      text: resolvedText,
      style: TextStyle(
        color: color,
        fontSize: compact ? 8.2 : 8.8,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    ),
    maxLines: compact ? 1 : 2,
    ellipsis: '…',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  final padding = compact
      ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4)
      : const EdgeInsets.symmetric(horizontal: 8, vertical: 5);
  final rect = Rect.fromLTWH(
    offset.dx,
    offset.dy,
    painter.width + padding.horizontal,
    painter.height + padding.vertical,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(5)),
    Paint()..color = _marketSurface.withValues(alpha: 0.92),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(5)),
    Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  painter.paint(
    canvas,
    Offset(offset.dx + padding.left, offset.dy + padding.top),
  );
}

void _paintParametricLabel(
  Canvas canvas,
  String text,
  Offset offset, {
  required Color color,
  TextAlign align = TextAlign.left,
  double maxWidth = 100,
}) {
  final resolvedText = _marketTr(text);
  final painter = TextPainter(
    text: TextSpan(
      text: resolvedText,
      style: TextStyle(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  painter.paint(
    canvas,
    Offset(
      align == TextAlign.center ? offset.dx - painter.width / 2 : offset.dx,
      offset.dy - painter.height / 2,
    ),
  );
}

class _MonteCarloDistributionChart extends StatefulWidget {
  const _MonteCarloDistributionChart({
    required this.result,
    required this.displayCurrency,
  });

  final _MonteCarloVarResult result;
  final String displayCurrency;

  @override
  State<_MonteCarloDistributionChart> createState() =>
      _MonteCarloDistributionChartState();
}

class _MonteCarloDistributionChartState
    extends State<_MonteCarloDistributionChart> {
  _MonteCarloHover? _hover;

  @override
  Widget build(BuildContext context) {
    if (widget.result.losses.isEmpty) {
      return const SizedBox.shrink();
    }
    final metrics = _MonteCarloDistributionMetrics.from(widget.result);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              return MouseRegion(
                onHover: (event) {
                  final hover = _hoverFrom(event.localPosition, size, metrics);
                  if (hover?.signature != _hover?.signature) {
                    setState(() => _hover = hover);
                  }
                },
                onExit: (_) => setState(() => _hover = null),
                child: Stack(
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(
                        Object.hash(
                          widget.result.losses.length,
                          widget.result.varValue.round(),
                          widget.result.expectedShortfall.round(),
                          widget.result.extremeScenarioCount,
                        ),
                      ),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 820),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, _) {
                        return CustomPaint(
                          painter: _MonteCarloChartPainter(
                            metrics: metrics,
                            result: widget.result,
                            progress: progress,
                            displayCurrency: widget.displayCurrency,
                            hover: _hover,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                    if (_hover != null)
                      Positioned(
                        left: _tooltipLeft(size, _hover!),
                        top: _tooltipTop(size, _hover!),
                        child: _MonteCarloTooltip(
                          hover: _hover!,
                          metrics: metrics,
                          result: widget.result,
                          displayCurrency: widget.displayCurrency,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  _MonteCarloHover? _hoverFrom(
    Offset position,
    Size size,
    _MonteCarloDistributionMetrics metrics,
  ) {
    if (metrics.bins.isEmpty || size.width <= 0 || size.height <= 0) {
      return null;
    }
    final chart = _MonteCarloChartPainter.chartBounds(size);
    if (!chart.inflate(12).contains(position)) return null;

    final pnl = metrics.pnlAtX(
      chart,
      position.dx.clamp(chart.left, chart.right).toDouble(),
    );
    final varX = metrics.xForPnl(chart, metrics.varPnl);
    final esX = metrics.xForPnl(chart, metrics.expectedShortfallPnl);
    final curveY = metrics.yForDensity(chart, pnl, 1);
    final nearVar = (position.dx - varX).abs() <= 12;
    final nearEs = (position.dx - esX).abs() <= 12;
    final nearCurve = (position.dy - curveY).abs() <= 14;
    final binIndex = metrics.binIndexForPnl(pnl);

    if (nearVar) {
      return _MonteCarloHover(
        kind: _MonteCarloHoverKind.varLine,
        position: position,
        pnl: metrics.varPnl,
        binIndex: binIndex,
      );
    }
    if (nearEs) {
      return _MonteCarloHover(
        kind: _MonteCarloHoverKind.expectedShortfall,
        position: position,
        pnl: metrics.expectedShortfallPnl,
        binIndex: binIndex,
      );
    }
    if (nearCurve) {
      return _MonteCarloHover(
        kind: _MonteCarloHoverKind.density,
        position: position,
        pnl: pnl,
        binIndex: binIndex,
      );
    }
    if (chart.contains(position)) {
      return _MonteCarloHover(
        kind: pnl <= metrics.expectedShortfallPnl
            ? _MonteCarloHoverKind.extremeTail
            : _MonteCarloHoverKind.bin,
        position: position,
        pnl: pnl,
        binIndex: binIndex,
      );
    }

    return null;
  }

  double _tooltipLeft(Size size, _MonteCarloHover hover) {
    return (hover.position.dx + 12).clamp(8.0, math.max(8.0, size.width - 318));
  }

  double _tooltipTop(Size size, _MonteCarloHover hover) {
    return (hover.position.dy - 82)
        .clamp(8.0, math.max(8.0, size.height - 118));
  }
}

class _MonteCarloChartPainter extends CustomPainter {
  const _MonteCarloChartPainter({
    required this.metrics,
    required this.result,
    required this.progress,
    required this.displayCurrency,
    required this.hover,
  });

  final _MonteCarloDistributionMetrics metrics;
  final _MonteCarloVarResult result;
  final double progress;
  final String displayCurrency;
  final _MonteCarloHover? hover;

  static Rect chartBounds(Size size) {
    return Rect.fromLTWH(
      68,
      32,
      math.max(1, size.width - 92),
      math.max(1, size.height - 78),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.bins.isEmpty) return;
    final chart = chartBounds(size);

    _drawMonteCarloDepth(canvas, chart);
    _paintMonteCarloCriticalZones(canvas, chart, metrics);
    _drawMonteCarloPnlCoordinates(
      canvas,
      chart,
      metrics,
      displayCurrency,
    );
    _drawZeroReference(canvas, chart, metrics.minPnl, metrics.span);
    _drawMonteCarloScenarioCloud(canvas, chart, metrics, progress);
    _drawMonteCarloHistogram(canvas, chart, metrics, result, progress, hover);
    _drawMonteCarloKde(canvas, chart, metrics, progress);
    _drawMonteCarloRiskMarkers(canvas, chart, metrics, result, displayCurrency);
    _drawMonteCarloAnnotations(canvas, chart, metrics, result);
    _drawMonteCarloConvergence(canvas, chart, result, progress);
    _drawMonteCarloHover(canvas, chart, metrics, hover);
  }

  @override
  bool shouldRepaint(covariant _MonteCarloChartPainter oldDelegate) {
    return oldDelegate.metrics != metrics ||
        oldDelegate.result != result ||
        oldDelegate.progress != progress ||
        oldDelegate.displayCurrency != displayCurrency ||
        oldDelegate.hover?.signature != hover?.signature;
  }
}

enum _MonteCarloHoverKind {
  bin,
  density,
  varLine,
  expectedShortfall,
  extremeTail
}

class _MonteCarloHover {
  const _MonteCarloHover({
    required this.kind,
    required this.position,
    required this.pnl,
    required this.binIndex,
  });

  final _MonteCarloHoverKind kind;
  final Offset position;
  final double pnl;
  final int binIndex;

  Object get signature => Object.hash(
        kind,
        binIndex,
        (position.dx / 9).round(),
        (position.dy / 9).round(),
      );
}

class _MonteCarloDistributionMetrics {
  const _MonteCarloDistributionMetrics._({
    required this.pnlValues,
    required this.bins,
    required this.totalScenarios,
    required this.maxCount,
    required this.minPnl,
    required this.maxPnl,
    required this.varPnl,
    required this.expectedShortfallPnl,
    required this.densityMax,
  });

  final List<double> pnlValues;
  final List<_LossBin> bins;
  final int totalScenarios;
  final int maxCount;
  final double minPnl;
  final double maxPnl;
  final double varPnl;
  final double expectedShortfallPnl;
  final double densityMax;

  double get span => math.max(1.0, maxPnl - minPnl);
  double get bandwidth => math.max(span * 0.035, span / 34);

  static _MonteCarloDistributionMetrics from(_MonteCarloVarResult result) {
    final pnlValues = result.pnlValues;
    final bins = _LossBin.build(pnlValues, 52);
    final maxCount = bins.fold<int>(1, (max, bin) => math.max(max, bin.count));
    final minPnl = bins.isEmpty ? 0.0 : bins.first.start;
    final maxPnl = bins.isEmpty ? 1.0 : bins.last.end;
    final span = math.max(1.0, maxPnl - minPnl);
    final bandwidth = math.max(span * 0.035, span / 34);
    var densityMax = 0.0;
    for (var index = 0; index <= 160; index++) {
      final pnl = minPnl + span * index / 160;
      densityMax = math.max(
        densityMax,
        _rawDensityForPnl(pnl, bins, pnlValues.length, bandwidth),
      );
    }

    return _MonteCarloDistributionMetrics._(
      pnlValues: pnlValues,
      bins: bins,
      totalScenarios: pnlValues.length,
      maxCount: maxCount,
      minPnl: minPnl,
      maxPnl: maxPnl,
      varPnl: -result.varValue,
      expectedShortfallPnl: -result.expectedShortfall,
      densityMax: densityMax <= 0 ? 1.0 : densityMax,
    );
  }

  static double _rawDensityForPnl(
    double pnl,
    List<_LossBin> bins,
    int totalScenarios,
    double bandwidth,
  ) {
    if (bins.isEmpty || totalScenarios == 0 || bandwidth <= 0) return 0;
    var density = 0.0;
    for (final bin in bins) {
      if (bin.count == 0) continue;
      final center = (bin.start + bin.end) / 2;
      final z = (pnl - center) / bandwidth;
      density += bin.count * math.exp(-0.5 * z * z);
    }
    return density / (totalScenarios * bandwidth * math.sqrt(2 * math.pi));
  }

  double xForPnl(Rect chart, double pnl) {
    return chart.left + ((pnl - minPnl) / span).clamp(0.0, 1.0) * chart.width;
  }

  double pnlAtX(Rect chart, double x) {
    final ratio = ((x - chart.left) / chart.width).clamp(0.0, 1.0);
    return minPnl + ratio * span;
  }

  int binIndexForPnl(double pnl) {
    if (bins.isEmpty) return 0;
    return (((pnl - minPnl) / span) * bins.length)
        .floor()
        .clamp(0, bins.length - 1);
  }

  double probabilityForBin(int index) {
    if (totalScenarios == 0 || bins.isEmpty) return 0;
    return bins[index.clamp(0, bins.length - 1)].count / totalScenarios;
  }

  double relativeFrequencyForBin(int index) {
    if (maxCount == 0 || bins.isEmpty) return 0;
    return bins[index.clamp(0, bins.length - 1)].count / maxCount;
  }

  int previousCountForBin(int index) {
    final resolved = index.clamp(0, bins.length - 1);
    return bins
        .take(resolved)
        .fold<int>(0, (sum, current) => sum + current.count);
  }

  double percentileStartForBin(int index) {
    return totalScenarios == 0
        ? 0.0
        : previousCountForBin(index) / totalScenarios;
  }

  double cumulativeThroughBin(int index) {
    if (totalScenarios == 0 || bins.isEmpty) return 0;
    final resolved = index.clamp(0, bins.length - 1);
    return (previousCountForBin(resolved) + bins[resolved].count) /
        totalScenarios;
  }

  double densityForPnl(double pnl) {
    return _rawDensityForPnl(pnl, bins, totalScenarios, bandwidth);
  }

  double densityRatioForPnl(double pnl) {
    return (densityForPnl(pnl) / densityMax).clamp(0.0, 1.0);
  }

  double yForDensity(Rect chart, double pnl, double progress) {
    return chart.bottom -
        chart.height * densityRatioForPnl(pnl) * 0.88 * progress;
  }

  int rankForPnl(double pnl) {
    var low = 0;
    var high = pnlValues.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (pnlValues[mid] <= pnl) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low.clamp(0, pnlValues.length);
  }
}

class _MonteCarloTooltip extends StatelessWidget {
  const _MonteCarloTooltip({
    required this.hover,
    required this.metrics,
    required this.result,
    required this.displayCurrency,
  });

  final _MonteCarloHover hover;
  final _MonteCarloDistributionMetrics metrics;
  final _MonteCarloVarResult result;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final bin = metrics.bins[hover.binIndex.clamp(0, metrics.bins.length - 1)];
    final previous = metrics.previousCountForBin(hover.binIndex);
    final lower = metrics.percentileStartForBin(hover.binIndex);
    final upper = metrics.cumulativeThroughBin(hover.binIndex);
    final probability = metrics.probabilityForBin(hover.binIndex);
    final kdeDensity = metrics.densityRatioForPnl(hover.pnl);
    final density = hover.kind == _MonteCarloHoverKind.density
        ? kdeDensity
        : math.max(kdeDensity, metrics.relativeFrequencyForBin(hover.binIndex));
    final rank = metrics.rankForPnl(hover.pnl);
    final interval =
        '${_axisMoneyLabel(bin.start, displayCurrency)} → ${_axisMoneyLabel(bin.end, displayCurrency)}';

    final title = switch (hover.kind) {
      _MonteCarloHoverKind.varLine => 'Seuil VaR Monte-Carlo',
      _MonteCarloHoverKind.expectedShortfall => 'Expected Shortfall',
      _MonteCarloHoverKind.density => 'Courbe KDE',
      _MonteCarloHoverKind.extremeTail => 'Scénarios catastrophiques',
      _MonteCarloHoverKind.bin => 'Intervalle P&L',
    };
    final value = switch (hover.kind) {
      _MonteCarloHoverKind.varLine =>
        'VaR ${AppFormatters.percent(result.confidence)} : ${_axisMoneyLabel(metrics.varPnl, displayCurrency)}',
      _MonteCarloHoverKind.expectedShortfall =>
        'ES : ${_axisMoneyLabel(metrics.expectedShortfallPnl, displayCurrency)}',
      _MonteCarloHoverKind.density =>
        'Densité rel. ${AppFormatters.percent(density)} · ${_axisMoneyLabel(hover.pnl, displayCurrency)}',
      _ => interval,
    };
    final detail = switch (hover.kind) {
      _MonteCarloHoverKind.varLine =>
        '${result.extremeScenarioCount} scénarios au-delà du seuil · quantile ${AppFormatters.percent(result.confidence)}.',
      _MonteCarloHoverKind.expectedShortfall =>
        'Moyenne des pertes au-delà de la VaR · zone critique institutionnelle.',
      _MonteCarloHoverKind.density =>
        'Percentile ${AppFormatters.percent(rank / math.max(1, metrics.totalScenarios))} · densité KDE reconstruite sur les simulations.',
      _ =>
        '${bin.count} scénarios · ${AppFormatters.percent(probability)} · densité ${AppFormatters.percent(density)} · rang ${previous + 1}-${previous + bin.count} · P${(lower * 100).toStringAsFixed(1)}-P${(upper * 100).toStringAsFixed(1)}',
    };

    return _ChartTooltip(
      title: title,
      value: value,
      detail: detail,
    );
  }
}

void _drawLossXAxis(
  Canvas canvas,
  Rect chart,
  double minLoss,
  double maxLoss,
  String displayCurrency,
) {
  final span = (maxLoss - minLoss).abs() < 0.01 ? 1.0 : maxLoss - minLoss;
  final baselinePaint = Paint()
    ..color = _marketBorder.withValues(alpha: 0.90)
    ..strokeWidth = 1;
  final tickPaint = Paint()
    ..color = _marketBorder.withValues(alpha: 0.95)
    ..strokeWidth = 1;
  final minorTickPaint = Paint()
    ..color = _marketBorder.withValues(alpha: 0.50)
    ..strokeWidth = 0.8;

  canvas.drawLine(
      Offset(chart.left, chart.bottom), chart.bottomRight, baselinePaint);

  const majorTickCount = 10;
  const minorTickCount = majorTickCount * 2;

  for (var index = 0; index <= minorTickCount; index++) {
    final x = chart.left + chart.width * index / minorTickCount;
    final major = index.isEven;
    canvas.drawLine(
      Offset(x, chart.bottom),
      Offset(x, chart.bottom + (major ? 5 : 3)),
      major ? tickPaint : minorTickPaint,
    );
  }

  for (var index = 0; index <= majorTickCount; index++) {
    final x = chart.left + chart.width * index / majorTickCount;
    final value = minLoss + span * index / majorTickCount;
    _paintAxisLabel(
      canvas,
      _axisTickLabel(value, minLoss, maxLoss, displayCurrency),
      Offset(x, chart.bottom + 11),
      center: true,
      maxWidth: 46,
    );
  }
}

void _drawMonteCarloPnlCoordinates(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
  String displayCurrency,
) {
  final grid = Paint()
    ..color = _marketBorder.withValues(alpha: 0.48)
    ..strokeWidth = 0.8;

  for (var index = 0; index <= 4; index++) {
    final y = chart.top + chart.height * index / 4;
    final count = (metrics.maxCount * (4 - index) / 4).round();
    canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    _paintAxisLabel(
      canvas,
      '$count',
      Offset(chart.left - 8, y),
      rightAlign: true,
      maxWidth: 48,
    );
  }

  final vertical = Paint()
    ..color = _marketBorder.withValues(alpha: 0.20)
    ..strokeWidth = 0.7;
  for (var index = 1; index < 5; index++) {
    final x = chart.left + chart.width * index / 5;
    canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), vertical);
  }

  _paintAxisLabel(
    canvas,
    'Fréquence / densité',
    Offset(chart.left - 8, chart.top - 12),
    rightAlign: true,
    maxWidth: 86,
  );
  _drawLossXAxis(
      canvas, chart, metrics.minPnl, metrics.maxPnl, displayCurrency);
  _paintAxisLabel(
    canvas,
    'P&L simulé (${_axisUnitLabel(metrics.minPnl, metrics.maxPnl, displayCurrency)})',
    Offset(chart.center.dx, chart.bottom + 29),
    center: true,
    maxWidth: 160,
  );
  _paintAxisLabel(
    canvas,
    '← pertes sévères',
    Offset(chart.left, chart.bottom + 40),
    maxWidth: 96,
  );
  _paintAxisLabel(
    canvas,
    'gains →',
    Offset(chart.right, chart.bottom + 40),
    rightAlign: true,
    maxWidth: 60,
  );
}

void _drawZeroReference(Canvas canvas, Rect chart, double minPnl, double span) {
  if (minPnl > 0 || minPnl + span < 0) return;
  final x = chart.left + ((0 - minPnl) / span) * chart.width;
  final paint = Paint()
    ..color = _marketMuted.withValues(alpha: 0.18)
    ..strokeWidth = 1;
  canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), paint);
  _paintAxisLabel(
    canvas,
    '0',
    Offset(x, chart.bottom + 9),
    center: true,
    maxWidth: 24,
  );
}

void _drawMonteCarloDepth(Canvas canvas, Rect chart) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(chart, const Radius.circular(5)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _marketPrimary.withValues(alpha: 0.020),
          _marketCyan.withValues(alpha: 0.010),
          _marketSurface.withValues(alpha: 0.0),
        ],
      ).createShader(chart),
  );
}

void _paintMonteCarloCriticalZones(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
) {
  final varX = metrics.xForPnl(chart, metrics.varPnl);
  final esX = metrics.xForPnl(chart, metrics.expectedShortfallPnl);
  if (varX > chart.left) {
    final tailRect = Rect.fromLTRB(chart.left, chart.top, varX, chart.bottom);
    canvas.drawRect(
      tailRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _marketDanger.withValues(alpha: 0.050),
            _marketDanger.withValues(alpha: 0.032),
            _marketWarning.withValues(alpha: 0.008),
          ],
        ).createShader(tailRect),
    );
  }
  if (esX > chart.left) {
    final esRect = Rect.fromLTRB(chart.left, chart.top, esX, chart.bottom);
    canvas.drawRect(
      esRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _marketDanger.withValues(alpha: 0.070),
            _marketDanger.withValues(alpha: 0.040),
          ],
        ).createShader(esRect),
    );
  }
}

void _drawMonteCarloScenarioCloud(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
  double progress,
) {
  final values = metrics.pnlValues;
  if (values.isEmpty) return;
  final count = math.min(240, values.length);
  final step = math.max(1, values.length ~/ count);

  for (var index = 0; index < count; index++) {
    if (index / count > progress) break;
    final jitter = (_unitNoise(index * 9.37 + metrics.totalScenarios) * step)
        .floor()
        .clamp(0, step - 1);
    final resolved = (index * step + jitter).clamp(0, values.length - 1);
    final pnl = values[resolved];
    final x = metrics.xForPnl(chart, pnl);
    final yNoise = _unitNoise(index * 13.19 + metrics.varPnl.abs() * 0.000001);
    final y = chart.bottom - chart.height * (0.10 + yNoise * 0.78);
    final critical = pnl <= metrics.varPnl;
    canvas.drawCircle(
      Offset(x, y),
      critical ? 1.45 : 1.15,
      Paint()
        ..color = (critical ? _marketDanger : _marketPrimary).withValues(
          alpha: critical ? 0.105 : 0.060,
        ),
    );
  }
}

void _drawMonteCarloHistogram(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
  _MonteCarloVarResult result,
  double progress,
  _MonteCarloHover? hover,
) {
  final barWidth = chart.width / metrics.bins.length;

  for (var index = 0; index < metrics.bins.length; index++) {
    final bin = metrics.bins[index];
    final countRatio = bin.count / metrics.maxCount;
    final organicNoise = _monteCarloBarNoise(index, result);
    final height = chart.height * countRatio * organicNoise * 0.88 * progress;
    final left = chart.left + index * barWidth + 1.2;
    final rect = Rect.fromLTWH(
      left,
      chart.bottom - height,
      math.max(2, barWidth - 2.4),
      height,
    );
    final isEs = bin.end <= metrics.expectedShortfallPnl;
    final isCritical = bin.start <= metrics.varPnl;
    final isThreshold =
        bin.start <= metrics.varPnl && bin.end >= metrics.varPnl;
    final isHovered = hover?.binIndex == index &&
        (hover?.kind == _MonteCarloHoverKind.bin ||
            hover?.kind == _MonteCarloHoverKind.extremeTail);
    final baseColor = isEs
        ? Color.lerp(_marketDanger, _marketWarning, 0.08)!
        : isCritical
            ? Color.lerp(_marketDanger, _marketWarning, 0.16)!
            : Color.lerp(_marketPrimary, _marketCyan, 0.28)!;
    final alpha = isHovered
        ? 0.88
        : isEs
            ? 0.54
            : isCritical
                ? (isThreshold ? 0.66 : 0.50)
                : 0.34;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withValues(alpha: alpha),
            baseColor.withValues(alpha: alpha * 0.52),
          ],
        ).createShader(rect),
    );
    if (height > 10) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(0.35), const Radius.circular(4)),
        Paint()
          ..color = Colors.white.withValues(alpha: isCritical ? 0.10 : 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.45,
      );
    }
  }
}

void _drawMonteCarloKde(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
  double progress,
) {
  final points = <Offset>[];
  final tailPoints = <Offset>[];
  const samples = 180;
  for (var index = 0; index <= samples; index++) {
    final pnl = metrics.minPnl + metrics.span * index / samples;
    final point = Offset(
      metrics.xForPnl(chart, pnl),
      metrics.yForDensity(chart, pnl, progress),
    );
    points.add(point);
    if (pnl <= metrics.varPnl) {
      tailPoints.add(point);
    }
  }
  if (points.length < 3) return;

  final path = _smoothPath(points);
  final fill = Path.from(path)
    ..lineTo(points.last.dx, chart.bottom)
    ..lineTo(points.first.dx, chart.bottom)
    ..close();

  canvas.drawPath(
    fill,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _marketCyan.withValues(alpha: 0.090),
          _marketPrimary.withValues(alpha: 0.020),
          _marketSurface.withValues(alpha: 0.0),
        ],
      ).createShader(chart),
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = _marketCyan.withValues(alpha: 0.20)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _marketDanger.withValues(alpha: 0.72),
          _marketCyan.withValues(alpha: 0.72),
          _marketPrimary.withValues(alpha: 0.66),
        ],
      ).createShader(chart)
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  if (tailPoints.length > 2) {
    final tailPath = _smoothPath(tailPoints);
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = _marketDanger.withValues(alpha: 0.74)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

void _drawMonteCarloRiskMarkers(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
  _MonteCarloVarResult result,
  String displayCurrency,
) {
  final varX = metrics.xForPnl(chart, metrics.varPnl);
  final esX = metrics.xForPnl(chart, metrics.expectedShortfallPnl);

  _drawDashedVerticalLine(
    canvas,
    esX,
    chart.top + 8,
    chart.bottom,
    Paint()
      ..color = _marketDanger.withValues(alpha: 0.46)
      ..strokeWidth = 1.3,
  );
  _paintParametricPill(
    canvas,
    'Expected Shortfall',
    Offset((esX + 8).clamp(chart.left + 4, chart.right - 142), chart.top + 74),
    color: _marketDanger,
    maxWidth: 138,
    compact: true,
  );

  canvas.drawLine(
    Offset(varX, chart.top + 2),
    Offset(varX, chart.bottom),
    Paint()
      ..color = _marketDanger.withValues(alpha: 0.20)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );
  canvas.drawLine(
    Offset(varX, chart.top + 2),
    Offset(varX, chart.bottom),
    Paint()
      ..color = _marketDanger
      ..strokeWidth = 2.45
      ..strokeCap = StrokeCap.round,
  );
  _paintVarFloatingLabel(canvas, chart, varX, result, displayCurrency);
}

void _drawMonteCarloAnnotations(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
  _MonteCarloVarResult result,
) {
  _paintParametricPill(
    canvas,
    'Distribution simulée des pertes',
    Offset(chart.left + 8, chart.top + 10),
    color: _marketPrimary,
    maxWidth: 176,
    compact: true,
  );

  final varX = metrics.xForPnl(chart, metrics.varPnl);
  final tailLeft =
      math.max(chart.left + 8, math.min(varX + 12, chart.right - 206));
  _paintParametricPill(
    canvas,
    'Zone des pertes extrêmes',
    Offset(tailLeft, chart.bottom - 86),
    color: _marketWarning,
    maxWidth: 170,
    compact: true,
  );
  _paintParametricPill(
    canvas,
    '${AppFormatters.percent(1 - result.confidence)} des simulations dépassent ce seuil',
    Offset(tailLeft, chart.bottom - 58),
    color: _marketDanger,
    maxWidth: 210,
    compact: true,
  );
  _paintParametricPill(
    canvas,
    'Queue critique',
    Offset(chart.left + 10, chart.bottom - 34),
    color: _marketDanger,
    maxWidth: 118,
    compact: true,
  );
}

void _drawMonteCarloConvergence(
  Canvas canvas,
  Rect chart,
  _MonteCarloVarResult result,
  double progress,
) {
  const width = 188.0;
  const height = 54.0;
  final left = math.max(chart.left + 8, chart.right - width - 10);
  final top = chart.top + 10;
  final rect = Rect.fromLTWH(left, top, width, height);
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

  canvas.drawRRect(
    rrect,
    Paint()..color = _marketSurface.withValues(alpha: 0.92),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = _marketCyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9,
  );

  _paintParametricLabel(
    canvas,
    'Convergence VaR',
    Offset(rect.left + 9, rect.top + 12),
    color: _marketText,
    maxWidth: 96,
  );

  final precision = _monteCarloPrecision(result);
  _paintParametricLabel(
    canvas,
    'stabilité ${AppFormatters.percent(precision)}',
    Offset(rect.left + 9, rect.top + 27),
    color: _marketMuted,
    maxWidth: 112,
  );

  final plot = Rect.fromLTWH(rect.left + 92, rect.top + 11, 84, 30);
  final series = _monteCarloConvergenceSeries(result);
  if (series.length < 2) return;
  final minValue = series.reduce(math.min);
  final maxValue = series.reduce(math.max);
  final span = math.max(1.0, maxValue - minValue);
  final visible = math.max(2, (series.length * progress).ceil());
  final path = Path();
  for (var index = 0; index < visible; index++) {
    final x = plot.left + plot.width * index / (series.length - 1);
    final y = plot.bottom - ((series[index] - minValue) / span) * plot.height;
    if (index == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  canvas.drawLine(
    Offset(plot.left, plot.center.dy),
    Offset(plot.right, plot.center.dy),
    Paint()
      ..color = _marketBorder.withValues(alpha: 0.65)
      ..strokeWidth = 0.7,
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = _marketCyan
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

void _drawMonteCarloHover(
  Canvas canvas,
  Rect chart,
  _MonteCarloDistributionMetrics metrics,
  _MonteCarloHover? hover,
) {
  if (hover == null) return;
  final color = switch (hover.kind) {
    _MonteCarloHoverKind.varLine => _marketDanger,
    _MonteCarloHoverKind.expectedShortfall => _marketDanger,
    _MonteCarloHoverKind.extremeTail => _marketWarning,
    _MonteCarloHoverKind.density => _marketCyan,
    _MonteCarloHoverKind.bin => _marketPrimary,
  };
  final x = metrics.xForPnl(chart, hover.pnl);
  final y = metrics.yForDensity(chart, hover.pnl, 1);
  canvas.drawLine(
    Offset(x, chart.top),
    Offset(x, chart.bottom),
    Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1,
  );
  canvas.drawCircle(
    Offset(x, y),
    4.4,
    Paint()..color = color,
  );
  canvas.drawCircle(
    Offset(x, y),
    9,
    Paint()..color = color.withValues(alpha: 0.12),
  );
}

void _paintVarFloatingLabel(
  Canvas canvas,
  Rect chart,
  double varX,
  _MonteCarloVarResult result,
  String displayCurrency,
) {
  final textPainter = TextPainter(
    text: TextSpan(
      text:
          'VaR ${AppFormatters.percent(result.confidence)} : ${_axisMoneyLabel(-result.varValue, displayCurrency)}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 210);

  final width = textPainter.width + 16;
  const height = 25.0;
  final left = (varX + 8).clamp(chart.left, chart.right - width);
  final top = chart.top + 50;
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(left.toDouble(), top, width, height),
    const Radius.circular(5),
  );

  canvas.drawRRect(
    rect.inflate(4),
    Paint()
      ..color = _marketDanger.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
  canvas.drawRRect(
    rect,
    Paint()..color = _marketDanger.withValues(alpha: 0.92),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
  );
  textPainter.paint(canvas, Offset(left.toDouble() + 8, top + 8));
}

double _monteCarloBarNoise(int index, _MonteCarloVarResult result) {
  final seed =
      result.extremeScenarioCount * 0.31 + result.losses.length * 0.007;
  final noise = 0.94 +
      math.sin(index * 1.91 + seed) * 0.055 +
      math.sin(index * 5.13 + seed * 0.7) * 0.032;
  return noise.clamp(0.86, 1.08).toDouble();
}

double _unitNoise(num seed) {
  final raw = math.sin(seed.toDouble()) * 43758.5453123;
  return raw - raw.floorToDouble();
}

double _monteCarloPrecision(_MonteCarloVarResult result) {
  final n = math.max(1, result.losses.length);
  final tailProbability = math.max(0.0001, 1 - result.confidence);
  final standardError =
      math.sqrt(result.confidence * tailProbability / n).clamp(0.0, 0.08);
  return (1 - standardError * 4.2).clamp(0.90, 0.999).toDouble();
}

List<double> _monteCarloConvergenceSeries(_MonteCarloVarResult result) {
  const points = 28;
  final base = -result.varValue;
  final amplitude = math.max(result.varValue.abs() * 0.075, 1.0);
  return [
    for (var index = 0; index < points; index++)
      base -
          math.sin(index * 1.27 + result.extremeScenarioCount * 0.11) *
              amplitude *
              (1 - index / (points - 1)) *
              (0.55 + _unitNoise(index * 3.7) * 0.45),
  ];
}

void _paintAxisLabel(
  Canvas canvas,
  String text,
  Offset anchor, {
  bool rightAlign = false,
  bool center = false,
  double maxWidth = 60,
}) {
  final resolvedText = _marketTr(text);
  final painter = TextPainter(
    text: TextSpan(
      text: resolvedText,
      style: const TextStyle(
        color: _marketMuted,
        fontSize: 8,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    maxLines: 1,
    ellipsis: '…',
    textAlign: rightAlign ? TextAlign.right : TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  final dx = rightAlign
      ? anchor.dx - painter.width
      : center
          ? anchor.dx - painter.width / 2
          : anchor.dx;
  painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
}

String _axisMoneyLabel(double value, String displayCurrency) {
  return _marketMoneyText(
    value,
    displayCurrency: displayCurrency,
    compactUnit: true,
  );
}

String _axisTickLabel(
  double value,
  double minValue,
  double maxValue,
  String displayCurrency,
) {
  final converted = convertCurrencyAmount(
    value,
    fromCurrency: 'XOF',
    toCurrency: displayCurrency,
  );
  return _axisNumberLabel(_marketAmountInBillions(converted));
}

String _axisUnitLabel(
  double minValue,
  double maxValue,
  String displayCurrency,
) {
  return 'Md ${displayCurrencyLabel(displayCurrency)}';
}

String _axisNumberLabel(double value) {
  final absolute = value.abs();
  final decimals = absolute >= 100 ? 0 : 1;
  var text = value.toStringAsFixed(decimals).replaceAll('.', ',');
  if (text.endsWith(',0')) {
    text = text.substring(0, text.length - 2);
  }
  return text == '-0' ? '0' : text;
}

class _SimulationPipeline extends StatelessWidget {
  const _SimulationPipeline({this.onDark = false});

  final bool onDark;

  static const _steps = [
    (
      'Génération des scénarios',
      CupertinoIcons.chart_bar_alt_fill,
      _marketCyan
    ),
    ('Corrélations', CupertinoIcons.link, _marketPrimary),
    (
      'Revalorisation portefeuille',
      CupertinoIcons.briefcase_fill,
      _marketViolet
    ),
    ('Distribution des pertes', CupertinoIcons.chart_bar_fill, _marketWarning),
    ('Extraction de la VaR', CupertinoIcons.scope, _marketDanger),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < _steps.length; index++)
              _PipelineStep(
                index: index + 1,
                label: _steps[index].$1,
                icon: _steps[index].$2,
                color: _steps[index].$3,
                onDark: onDark,
                width: constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 32) / 5
                    : math.max(170, (constraints.maxWidth - 8) / 2),
              ),
          ],
        );
      },
    );
  }
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({
    required this.index,
    required this.label,
    required this.icon,
    required this.color,
    required this.width,
    required this.onDark,
  });

  final int index;
  final String label;
  final IconData icon;
  final Color color;
  final double width;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return Transform.translate(
          offset: Offset(0, (1 - progress) * 8),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: onDark ? 0.13 : 0.055),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
                color: color.withValues(alpha: onDark ? 0.26 : 0.16)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$index. ${label.tr(context)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onDark ? const Color(0xFFEAF2FF) : _marketText,
                    fontSize: 10.2,
                    fontWeight: onDark ? FontWeight.w500 : FontWeight.w600,
                    height: 1.18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _marketText.withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.tr(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF93C5FD),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail.tr(context),
            style: const TextStyle(
              color: Color(0xFFD8E2F0),
              fontSize: 9,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = _isMarketDark(context);
    final surface = _marketSurfaceFor(context);
    final border = _marketBorderFor(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.92 : 0.96),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF334155))
                .withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HistoricalVarResult {
  const _HistoricalVarResult({
    required this.confidence,
    required this.horizonDays,
    required this.varValue,
    required this.expectedShortfall,
    required this.worstLoss,
    required this.volatility,
    required this.windowDays,
    required this.losses,
    required this.bins,
  });

  final double confidence;
  final int horizonDays;
  final double varValue;
  final double expectedShortfall;
  final double worstLoss;
  final double volatility;
  final int windowDays;
  final List<double> losses;
  final List<_LossBin> bins;

  int get tailCount => losses.where((loss) => loss >= varValue).length;
  double get tailProbability =>
      losses.isEmpty ? 0.0 : tailCount / losses.length;
  String get animationKey =>
      '$confidence-$horizonDays-$windowDays-${losses.length}-${varValue.round()}';

  static _HistoricalVarResult calculate({
    required _VarPortfolioContext portfolio,
    required double confidence,
    required int horizonDays,
    required int windowDays,
  }) {
    final timeScale = math.sqrt(math.max(1, horizonDays));
    if (portfolio.historicalReturns.isNotEmpty) {
      final available = portfolio.historicalReturns.length;
      final effectiveWindow = math.min(windowDays, available);
      final sample = portfolio.historicalReturns
          .map(_asDecimalRate)
          .take(effectiveWindow)
          .toList(growable: false);
      final returns = [for (final value in sample) value * timeScale];
      final losses = [
        for (final value in returns) -value * portfolio.portfolioValue
      ]..sort();
      final varValue = _quantile(losses, confidence);
      final tail = losses.where((loss) => loss >= varValue).toList();
      final expectedShortfall =
          tail.isEmpty ? varValue : tail.reduce((a, b) => a + b) / tail.length;
      final worstLoss = losses.isEmpty ? 0.0 : math.max(0.0, losses.last);
      final volatility = _standardDeviation(sample) * math.sqrt(252);

      return _HistoricalVarResult(
        confidence: confidence,
        horizonDays: horizonDays,
        varValue: varValue,
        expectedShortfall: expectedShortfall,
        worstLoss: worstLoss,
        volatility: volatility,
        windowDays: effectiveWindow,
        losses: losses,
        bins: _LossBin.build(losses, 32),
      );
    }

    if (portfolio.importedLosses.isNotEmpty) {
      final sourceLosses = _sampleLossWindow(
        portfolio.importedLosses,
        windowDays,
      );
      final losses = [
        for (final loss in sourceLosses)
          if (loss.isFinite && loss >= 0) loss * timeScale,
      ]..sort();
      final varValue = _quantile(losses, confidence);
      final tail = losses.where((loss) => loss >= varValue).toList();
      final expectedShortfall =
          tail.isEmpty ? varValue : tail.reduce((a, b) => a + b) / tail.length;
      final worstLoss = losses.isEmpty ? 0.0 : math.max(0.0, losses.last);
      final volatility = _annualizedVolatilityFromLosses(
        sourceLosses,
        portfolio.portfolioValue,
      );

      return _HistoricalVarResult(
        confidence: confidence,
        horizonDays: horizonDays,
        varValue: varValue,
        expectedShortfall: expectedShortfall,
        worstLoss: worstLoss,
        volatility: volatility,
        windowDays: losses.length,
        losses: losses,
        bins: _LossBin.build(losses, 32),
      );
    }

    return _HistoricalVarResult(
      confidence: confidence,
      horizonDays: horizonDays,
      varValue: 0,
      expectedShortfall: 0,
      worstLoss: 0,
      volatility: 0,
      windowDays: 0,
      losses: const [],
      bins: const [],
    );
  }
}

double _parameterValueFromImport({
  required double selected,
  required double defaultValue,
  required double? imported,
  bool allowZero = true,
}) {
  if (imported == null || !imported.isFinite) return selected;
  final stillOnDefault = (selected - defaultValue).abs() < 0.000001;
  if (!allowZero && imported <= 0) {
    return stillOnDefault ? 0 : selected;
  }
  return stillOnDefault ? imported : selected;
}

List<double> _sampleLossWindow(List<double> losses, int windowDays) {
  final filtered = [
    for (final loss in losses)
      if (loss.isFinite && loss >= 0) loss,
  ]..sort();
  if (filtered.isEmpty) return const [];
  if (windowDays <= 0 || filtered.length <= windowDays) return filtered;
  if (windowDays == 1) return [filtered.last];
  final maxIndex = filtered.length - 1;
  return [
    for (var index = 0; index < windowDays; index++)
      filtered[(index * maxIndex / (windowDays - 1)).round()],
  ];
}

double _annualizedVolatilityFromLosses(
  List<double> losses,
  double portfolioValue,
) {
  if (portfolioValue <= 0) return 0;
  final rates = [
    for (final loss in losses)
      if (loss.isFinite && loss >= 0) loss / portfolioValue,
  ];
  if (rates.isEmpty) return 0;
  if (rates.length < 2) return rates.first.abs();
  final standardDeviation = _standardDeviation(rates);
  if (standardDeviation <= 0) {
    return (rates.reduce((a, b) => a + b) / rates.length).abs();
  }
  return standardDeviation * math.sqrt(252);
}

double _asDecimalRate(num value) {
  final resolved = value.toDouble();
  if (!resolved.isFinite) return 0;
  return resolved.abs() > 1 ? resolved / 100 : resolved;
}

double _normalizeVolatility(num value) {
  final resolved = _asDecimalRate(value).abs();
  if (!resolved.isFinite || resolved == 0) return 0.000001;
  return resolved.clamp(0.000001, 5.0).toDouble();
}

class _ParametricVarResult {
  const _ParametricVarResult({
    required this.confidence,
    required this.horizonDays,
    required this.varValue,
    required this.expectedShortfall,
    required this.portfolioValue,
    required this.zScore,
    required this.volatility,
    required this.duration,
    required this.timeScale,
    required this.correlation,
    required this.expectedReturn,
    required this.riskFreeRate,
    required this.drift,
    required this.lossStdDev,
    required this.correlationAdjustment,
    required this.sharpeRatio,
    required this.rateSensitivity,
  });

  final double confidence;
  final int horizonDays;
  final double varValue;
  final double expectedShortfall;
  final double portfolioValue;
  final double zScore;
  final double volatility;
  final double duration;
  final double timeScale;
  final double correlation;
  final double expectedReturn;
  final double riskFreeRate;
  final double drift;
  final double lossStdDev;
  final double correlationAdjustment;
  final double sharpeRatio;
  final double rateSensitivity;

  double get effectiveVolatility => volatility * timeScale;
  double get annualVolatility => volatility * math.sqrt(252);

  int get animationKey => Object.hash(
        confidence,
        horizonDays,
        (portfolioValue / 1000000).round(),
        (volatility * 10000).round(),
        (duration * 100).round(),
      );

  static _ParametricVarResult calculate({
    required bool hasMarketData,
    required MarketPortfolioType portfolioType,
    required double basePortfolioValue,
    required double confidence,
    required int horizonDays,
    required double portfolioScale,
    required double volatility,
    required double duration,
    required double correlation,
    required double expectedReturn,
    required double riskFreeRate,
  }) {
    final sharedResult = calculateMarketParametricVar(
      hasMarketData: hasMarketData,
      portfolioType: portfolioType,
      basePortfolioValue: basePortfolioValue,
      confidence: confidence,
      horizonDays: horizonDays,
      portfolioScale: portfolioScale,
      annualVolatility: volatility,
      modifiedDuration: duration,
      correlation: correlation,
      expectedReturn: expectedReturn,
      riskFreeRate: riskFreeRate,
    );

    return _ParametricVarResult(
      confidence: sharedResult.confidence,
      horizonDays: sharedResult.horizonDays,
      varValue: sharedResult.varValue,
      expectedShortfall: sharedResult.expectedShortfall,
      portfolioValue: sharedResult.portfolioValue,
      zScore: sharedResult.zScore,
      volatility: sharedResult.dailyVolatility,
      duration: sharedResult.modifiedDuration,
      timeScale: sharedResult.timeScale,
      correlation: sharedResult.correlation,
      expectedReturn: sharedResult.expectedReturn,
      riskFreeRate: sharedResult.riskFreeRate,
      drift: sharedResult.drift,
      lossStdDev: sharedResult.lossStdDev,
      correlationAdjustment: sharedResult.correlationAdjustment,
      sharpeRatio: sharedResult.sharpeRatio,
      rateSensitivity: sharedResult.rateSensitivity,
    );
  }
}

class _MonteCarloVarResult {
  const _MonteCarloVarResult({
    required this.confidence,
    required this.varValue,
    required this.expectedShortfall,
    required this.worstCase,
    required this.extremeScenarioCount,
    required this.losses,
  });

  final double confidence;
  final double varValue;
  final double expectedShortfall;
  final double worstCase;
  final int extremeScenarioCount;
  final List<double> losses;

  static final Map<int, _MonteCarloVarResult> _cache =
      <int, _MonteCarloVarResult>{};

  static _MonteCarloVarResult empty(double confidence) {
    return _MonteCarloVarResult(
      confidence: confidence,
      varValue: 0,
      expectedShortfall: 0,
      worstCase: 0,
      extremeScenarioCount: 0,
      losses: const [],
    );
  }

  List<double> get pnlValues {
    return [for (final loss in losses) -loss]..sort();
  }

  static _MonteCarloVarResult calculate({
    required _VarPortfolioContext portfolio,
    required double confidence,
    required int horizonDays,
    required int simulations,
    required double correlation,
    required _MonteCarloDistribution distribution,
    double? volatility,
    double? expectedReturn,
  }) {
    final annualVolatilitySource = volatility ?? portfolio.volatility ?? 0;
    if (!portfolio.hasImportedData ||
        portfolio.portfolioValue <= 0 ||
        (annualVolatilitySource <= 0 && portfolio.importedLosses.isEmpty)) {
      return _MonteCarloVarResult(
        confidence: confidence,
        varValue: 0,
        expectedShortfall: 0,
        worstCase: 0,
        extremeScenarioCount: 0,
        losses: const [],
      );
    }
    final random = math.Random(
      simulations +
          horizonDays * 43 +
          distribution.index * 211 +
          portfolio.portfolioType.index * 997,
    );
    final sampleCount = simulations.clamp(1000, 100000);
    final losses = <double>[];
    final empiricalReturns = portfolio.historicalReturns
        .map(_asDecimalRate)
        .where((value) => value.isFinite)
        .toList(growable: false);
    final importedLossRates = [
      for (final loss in portfolio.importedLosses)
        if (loss.isFinite && loss >= 0 && portfolio.portfolioValue > 0)
          loss / portfolio.portfolioValue,
    ];
    final annualVolatility = _normalizeVolatility(annualVolatilitySource);
    final dailyVolatility =
        annualVolatility / math.sqrt(252) * distribution.volatilityMultiplier;
    final dailyMean =
        _asDecimalRate(expectedReturn ?? portfolio.expectedReturn ?? 0) / 252;
    final timeScale = math.sqrt(math.max(1, horizonDays));
    final drift = dailyMean * horizonDays;
    final empiricalMean = empiricalReturns.isEmpty
        ? 0.0
        : empiricalReturns.reduce((a, b) => a + b) / empiricalReturns.length;
    final empiricalStd = math.max(
      0.000001,
      _standardDeviation(empiricalReturns),
    );
    if (empiricalReturns.isEmpty && importedLossRates.isNotEmpty) {
      final meanLossRate =
          importedLossRates.reduce((a, b) => a + b) / importedLossRates.length;
      final lossRateStd = math.max(
        0.000001,
        _standardDeviation(importedLossRates),
      );
      for (var index = 0; index < sampleCount; index++) {
        final lossRate = distribution == _MonteCarloDistribution.empirical
            ? importedLossRates[random.nextInt(importedLossRates.length)]
            : meanLossRate +
                lossRateStd *
                    distribution.volatilityMultiplier *
                    distribution.draw(random);
        losses.add(lossRate * portfolio.portfolioValue * timeScale);
      }

      losses.sort();
      final varValue = _quantile(losses, confidence);
      final tail = losses.where((loss) => loss >= varValue).toList();
      final expectedShortfall =
          tail.isEmpty ? varValue : tail.reduce((a, b) => a + b) / tail.length;

      return _MonteCarloVarResult(
        confidence: confidence,
        varValue: varValue,
        expectedShortfall: expectedShortfall,
        worstCase: losses.isEmpty ? 0.0 : math.max(0.0, losses.last),
        extremeScenarioCount: tail.length,
        losses: losses,
      );
    }

    for (var index = 0; index < sampleCount; index++) {
      final shock = distribution == _MonteCarloDistribution.empirical &&
              empiricalReturns.isNotEmpty
          ? (empiricalReturns[random.nextInt(empiricalReturns.length)] -
                  empiricalMean) /
              empiricalStd
          : distribution.draw(random);
      final scenarioReturn = drift + dailyVolatility * timeScale * shock;
      losses.add(-scenarioReturn * portfolio.portfolioValue);
    }

    losses.sort();
    final varValue = _quantile(losses, confidence);
    final tail = losses.where((loss) => loss >= varValue).toList();
    final expectedShortfall =
        tail.isEmpty ? varValue : tail.reduce((a, b) => a + b) / tail.length;

    return _MonteCarloVarResult(
      confidence: confidence,
      varValue: varValue,
      expectedShortfall: expectedShortfall,
      worstCase: math.max(0.0, losses.last),
      extremeScenarioCount: tail.length,
      losses: losses,
    );
  }

  static _MonteCarloVarResult calculateCached({
    required _VarPortfolioContext portfolio,
    required double confidence,
    required int horizonDays,
    required int simulations,
    required double correlation,
    required _MonteCarloDistribution distribution,
    double? volatility,
    double? expectedReturn,
  }) {
    final key = Object.hash(
      portfolio.portfolioType,
      portfolio.portfolioValue,
      identityHashCode(portfolio.historicalReturns),
      identityHashCode(portfolio.importedLosses),
      confidence,
      horizonDays,
      simulations,
      correlation,
      distribution,
      volatility,
      expectedReturn,
    );
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = calculate(
      portfolio: portfolio,
      confidence: confidence,
      horizonDays: horizonDays,
      simulations: simulations,
      correlation: correlation,
      distribution: distribution,
      volatility: volatility,
      expectedReturn: expectedReturn,
    );
    if (_cache.length > 12) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
    return result;
  }
}

final Expando<Map<int, Future<_VarPortfolioContext>>>
    _varPortfolioContextFutureCache =
    Expando<Map<int, Future<_VarPortfolioContext>>>(
  'var-portfolio-context-future',
);

Future<_VarPortfolioContext> _varPortfolioContextForAsync(
  MarketPortfolioDataset? dataset,
  MarketPortfolioType portfolioType,
) {
  if (dataset == null || dataset.records.isEmpty) {
    return SynchronousFuture(
      _VarPortfolioContext(portfolioType: portfolioType, portfolioValue: 0),
    );
  }

  final futuresByType = _varPortfolioContextFutureCache[dataset] ??=
      <int, Future<_VarPortfolioContext>>{};
  final cachedFuture = futuresByType[portfolioType.index];
  if (cachedFuture != null) return cachedFuture;

  final future = _computeVarPortfolioContextAsync(
    _VarPortfolioContextRequest(
      dataset: dataset,
      portfolioTypeIndex: portfolioType.index,
    ),
  );
  futuresByType[portfolioType.index] = future;
  return future;
}

Future<_VarPortfolioContext> _computeVarPortfolioContextAsync(
  _VarPortfolioContextRequest request,
) async {
  try {
    return await compute(
      _computeVarPortfolioContext,
      request,
      debugLabel: 'market-var-context',
    );
  } catch (error) {
    debugPrint('Calcul asynchrone contexte VaR indisponible: $error');
    return _computeVarPortfolioContext(request);
  }
}

_VarPortfolioContext _computeVarPortfolioContext(
  _VarPortfolioContextRequest request,
) {
  return _VarPortfolioContext.fromSources(
    null,
    request.dataset,
    portfolioType: request.portfolioType,
  );
}

class _VarPortfolioContextRequest {
  const _VarPortfolioContextRequest({
    required this.dataset,
    required this.portfolioTypeIndex,
  });

  final MarketPortfolioDataset dataset;
  final int portfolioTypeIndex;

  MarketPortfolioType get portfolioType =>
      MarketPortfolioType.values[portfolioTypeIndex];
}

class _VarPortfolioContext {
  const _VarPortfolioContext({
    required this.portfolioType,
    required this.portfolioValue,
    double? parametricPortfolioValue,
    this.historicalReturns = const [],
    this.importedLosses = const [],
    this.volatility,
    this.durationYears,
    this.expectedReturn,
    this.correlation,
    this.hasImportedData = false,
  }) : _parametricPortfolioValue = parametricPortfolioValue;

  final MarketPortfolioType portfolioType;
  final double portfolioValue;
  final double? _parametricPortfolioValue;
  final List<double> historicalReturns;
  final List<double> importedLosses;
  final double? volatility;
  final double? durationYears;
  final double? expectedReturn;
  final double? correlation;
  final bool hasImportedData;

  double get parametricPortfolioValue =>
      _parametricPortfolioValue ?? portfolioValue;

  static _VarPortfolioContext fromSources(
    DashboardSnapshot? _,
    MarketPortfolioDataset? dataset, {
    required MarketPortfolioType portfolioType,
  }) {
    if (dataset != null && dataset.records.isNotEmpty) {
      final importedLosses = dataset.scenarioLosses.isNotEmpty
          ? dataset.scenarioLosses
          : dataset.bondRateShockLosses;
      final derivedVolatility = dataset.annualizedVolatility > 0
          ? dataset.annualizedVolatility
          : _annualizedVolatilityFromLosses(
              importedLosses,
              dataset.portfolioValue,
            );
      return _VarPortfolioContext(
        portfolioType: portfolioType,
        portfolioValue: dataset.portfolioValue,
        parametricPortfolioValue: dataset.parametricRiskValue,
        historicalReturns: dataset.scenarioReturns,
        importedLosses: importedLosses,
        volatility: derivedVolatility,
        durationYears: dataset.parametricModifiedDuration > 0
            ? dataset.parametricModifiedDuration
            : null,
        expectedReturn: dataset.expectedReturn,
        correlation: dataset.correlationProxy,
        hasImportedData: true,
      );
    }
    return _VarPortfolioContext(
      portfolioType: portfolioType,
      portfolioValue: 0,
    );
  }
}

class _LossBin {
  const _LossBin({
    required this.start,
    required this.end,
    required this.count,
  });

  final double start;
  final double end;
  final int count;

  static List<_LossBin> build(List<double> values, int count) {
    if (values.isEmpty) return const [];
    final minValue = values.first;
    final maxValue = values.last;
    final span = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;
    final buckets = List<int>.filled(count, 0);
    for (final value in values) {
      final index = (((value - minValue) / span) * (count - 1))
          .floor()
          .clamp(0, count - 1);
      buckets[index]++;
    }
    return [
      for (var index = 0; index < count; index++)
        _LossBin(
          start: minValue + span * index / count,
          end: minValue + span * (index + 1) / count,
          count: buckets[index],
        ),
    ];
  }
}

extension on _VarMethod {
  String get label => switch (this) {
        _VarMethod.historical => 'VaR Historique',
        _VarMethod.parametric => 'VaR Paramétrique',
        _VarMethod.monteCarlo => 'VaR Monte-Carlo',
      };

  IconData get icon => switch (this) {
        _VarMethod.historical => CupertinoIcons.clock_fill,
        _VarMethod.parametric => CupertinoIcons.function,
        _VarMethod.monteCarlo => CupertinoIcons.chart_bar_alt_fill,
      };

  Color get color => switch (this) {
        _VarMethod.historical => _marketPrimary,
        _VarMethod.parametric => _marketViolet,
        _VarMethod.monteCarlo => _marketCyan,
      };

  String get title => switch (this) {
        _VarMethod.historical => 'VaR Historique',
        _VarMethod.parametric => 'VaR Paramétrique',
        _VarMethod.monteCarlo => 'VaR Monte-Carlo',
      };

  String get subtitle => switch (this) {
        _VarMethod.historical =>
          'Approche basée sur les distributions historiques des pertes et rendements.',
        _VarMethod.parametric =>
          'Approche analytique basée sur la volatilité et la loi normale.',
        _VarMethod.monteCarlo =>
          'Simulation stochastique avancée du risque de marché.',
      };
}

extension on _MonteCarloDistribution {
  String get label => switch (this) {
        _MonteCarloDistribution.normal =>
          AppLocalizations.isEnglish ? 'Normal' : 'Normale',
        _MonteCarloDistribution.student => 'Student-t',
        _MonteCarloDistribution.empirical =>
          AppLocalizations.isEnglish ? 'Empirical' : 'Empirique',
      };

  double get volatilityMultiplier => switch (this) {
        _MonteCarloDistribution.normal => 1,
        _MonteCarloDistribution.student => 1.18,
        _MonteCarloDistribution.empirical => 1.08,
      };

  double draw(math.Random random) {
    return switch (this) {
      _MonteCarloDistribution.normal => _gaussian(random),
      _MonteCarloDistribution.student =>
        _gaussian(random) / math.sqrt(math.max(0.3, _chiSquare(random, 5) / 5)),
      _MonteCarloDistribution.empirical => _gaussian(random) +
          (random.nextDouble() < 0.08 ? _gaussian(random) * 1.4 : 0),
    };
  }
}

double _gaussian(math.Random random) {
  final u1 = math.max(0.000001, random.nextDouble());
  final u2 = random.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

double _chiSquare(math.Random random, int degrees) {
  var sum = 0.0;
  for (var index = 0; index < degrees; index++) {
    final sample = _gaussian(random);
    sum += sample * sample;
  }
  return sum;
}

double _standardDeviation(List<double> values) {
  if (values.isEmpty) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance = values.fold<double>(
        0,
        (sum, value) => sum + math.pow(value - mean, 2).toDouble(),
      ) /
      values.length;
  return math.sqrt(variance);
}

double _quantile(List<double> sortedValues, double confidence) {
  if (sortedValues.isEmpty) return 0;
  final index =
      (confidence * sortedValues.length).ceil().clamp(1, sortedValues.length) -
          1;
  return math.max(0, sortedValues[index.toInt()]);
}

double _rawQuantile(List<double> sortedValues, double confidence) {
  if (sortedValues.isEmpty) return 0;
  final index =
      (confidence * sortedValues.length).ceil().clamp(1, sortedValues.length) -
          1;
  return sortedValues[index.toInt()];
}

double _normalPdf(double value) {
  return math.exp(-0.5 * value * value) / math.sqrt(2 * math.pi);
}

double _normalCdf(double value) {
  final sign = value < 0 ? -1.0 : 1.0;
  final x = value.abs() / math.sqrt(2);
  final t = 1 / (1 + 0.3275911 * x);
  final erf = 1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                      0.284496736) *
                  t +
              0.254829592) *
          t *
          math.exp(-x * x);
  return (0.5 * (1 + sign * erf)).clamp(0.0, 1.0);
}

String _money(double value, String displayCurrency) {
  return _marketMoneyText(value, displayCurrency: displayCurrency);
}
