import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../expositions/models/exposition_models.dart';

const Color _engineDeepBlue = Color(0xFF172554);
const Color _engineBlue = Color(0xFF2563EB);
const Color _engineIndigo = Color(0xFF4338CA);
const Color _engineSidebarBg = Color(0xFFF5F7FF);
const double _radius = 2;

class RwaEngineScreen extends StatefulWidget {
  const RwaEngineScreen({super.key, required this.api});

  final RwaApiService api;

  @override
  State<RwaEngineScreen> createState() => _RwaEngineScreenState();
}

class _RwaEngineScreenState extends State<RwaEngineScreen> {
  late Future<ExposureModuleData> _future;
  StreamSubscription<int>? _refreshSubscription;
  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchExpositionsModule();
    _refreshSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) return;
      setState(() => _future = widget.api.fetchExpositionsModule());
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExposureModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        if (data.exposures.isEmpty) {
          return const _EngineEmptyState();
        }

        final view = _RwaEngineView.from(data.exposures);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.pagePadding,
                AppTheme.pagePadding,
                0,
              ),
              child: _EngineHeader(view: view),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pagePadding,
                      AppTheme.pageGap,
                      0,
                      AppTheme.pagePadding,
                    ),
                    child: _EngineSideBar(
                      expanded: _isSidebarExpanded,
                      onToggle: () => setState(
                        () => _isSidebarExpanded = !_isSidebarExpanded,
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RwaEngineView {
  const _RwaEngineView({
    required this.exposures,
    required this.totalGross,
    required this.totalEad,
    required this.totalRwa,
    required this.totalCapital,
    required this.averageRw,
    required this.crmCoveredEad,
    required this.crmRelief,
    required this.categoryRows,
    required this.topRwaRows,
    required this.anomalies,
  });

  final List<ExposureRecord> exposures;
  final double totalGross;
  final double totalEad;
  final double totalRwa;
  final double totalCapital;
  final double averageRw;
  final double crmCoveredEad;
  final double crmRelief;
  final List<_EngineCategoryRow> categoryRows;
  final List<ExposureRecord> topRwaRows;
  final List<_EngineAnomaly> anomalies;

  factory _RwaEngineView.from(List<ExposureRecord> exposures) {
    final totalGross =
        exposures.fold<double>(0, (sum, item) => sum + item.grossAmount);
    final totalEad = exposures.fold<double>(0, (sum, item) => sum + item.ead);
    final totalRwa = exposures.fold<double>(0, (sum, item) => sum + item.rwa);
    final totalCapital =
        exposures.fold<double>(0, (sum, item) => sum + item.capital);
    final categoryMap = <String, _EngineCategoryAccumulator>{};
    for (final item in exposures) {
      categoryMap
          .putIfAbsent(item.categoryLabel, () => _EngineCategoryAccumulator())
          .add(item);
    }
    final categoryRows = categoryMap.entries
        .map((entry) => _EngineCategoryRow(
              label: entry.key.trim().isEmpty ? 'Non renseigné' : entry.key,
              count: entry.value.count,
              ead: entry.value.ead,
              rwa: entry.value.rwa,
              averageRw:
                  entry.value.ead <= 0 ? 0 : entry.value.rwa / entry.value.ead,
              share: totalRwa <= 0 ? 0 : entry.value.rwa / totalRwa,
            ))
        .toList(growable: false)
      ..sort((left, right) => right.rwa.compareTo(left.rwa));

    final coveredEad = exposures
        .where((item) =>
            item.crmModeLabel != 'Aucune' || item.crmCoveragePercent > 0)
        .fold<double>(0, (sum, item) => sum + item.ead);
    final theoreticalRwaBeforeCrm = exposures.fold<double>(
      0,
      (sum, item) => sum + item.ead * item.originalRw,
    );
    final relief = math.max(0, theoreticalRwaBeforeCrm - totalRwa).toDouble();
    final topRwaRows = exposures.toList(growable: false)
      ..sort((left, right) => right.rwa.compareTo(left.rwa));

    return _RwaEngineView(
      exposures: exposures,
      totalGross: totalGross,
      totalEad: totalEad,
      totalRwa: totalRwa,
      totalCapital: totalCapital,
      averageRw: totalEad <= 0 ? 0 : totalRwa / totalEad,
      crmCoveredEad: coveredEad,
      crmRelief: relief,
      categoryRows: categoryRows,
      topRwaRows: topRwaRows.take(8).toList(growable: false),
      anomalies: _engineAnomalies(exposures),
    );
  }
}

class _EngineCategoryAccumulator {
  var count = 0;
  var ead = 0.0;
  var rwa = 0.0;

  void add(ExposureRecord item) {
    count += 1;
    ead += item.ead;
    rwa += item.rwa;
  }
}

class _EngineCategoryRow {
  const _EngineCategoryRow({
    required this.label,
    required this.count,
    required this.ead,
    required this.rwa,
    required this.averageRw,
    required this.share,
  });

  final String label;
  final int count;
  final double ead;
  final double rwa;
  final double averageRw;
  final double share;
}

class _EngineAnomaly {
  const _EngineAnomaly({
    required this.title,
    required this.detail,
    required this.level,
  });

  final String title;
  final String detail;
  final _EngineAnomalyLevel level;
}

enum _EngineAnomalyLevel { high, medium, low }

List<_EngineAnomaly> _engineAnomalies(List<ExposureRecord> rows) {
  final anomalies = <_EngineAnomaly>[];
  final missingRating =
      rows.where((item) => item.ratingLabel == 'Non noté').length;
  final missingCrm = rows
      .where((item) =>
          item.crmModeLabel != 'Aucune' && item.crmCoveragePercent <= 0)
      .length;
  final highRw = rows.where((item) => item.finalRw >= 1.0).length;
  final zeroRwa = rows.where((item) => item.ead > 0 && item.rwa == 0).length;
  final defaulted = rows.where((item) => item.isDefaultLike).length;

  if (missingRating > 0) {
    anomalies.add(_EngineAnomaly(
      title: 'Notations à compléter',
      detail: '$missingRating exposition(s) sans notation exploitable.',
      level: _EngineAnomalyLevel.medium,
    ));
  }
  if (missingCrm > 0) {
    anomalies.add(_EngineAnomaly(
      title: 'CRM incomplet',
      detail: '$missingCrm exposition(s) avec couverture non renseignée.',
      level: _EngineAnomalyLevel.high,
    ));
  }
  if (highRw > 0) {
    anomalies.add(_EngineAnomaly(
      title: 'Pondérations élevées',
      detail: '$highRw exposition(s) à RW final supérieur ou égal à 100 %.',
      level: _EngineAnomalyLevel.high,
    ));
  }
  if (zeroRwa > 0) {
    anomalies.add(_EngineAnomaly(
      title: 'RWA nul à vérifier',
      detail: '$zeroRwa exposition(s) avec EAD positif et RWA nul.',
      level: _EngineAnomalyLevel.medium,
    ));
  }
  if (defaulted > 0) {
    anomalies.add(_EngineAnomaly(
      title: 'Expositions en défaut',
      detail: '$defaulted exposition(s) doivent rester isolées dans le calcul.',
      level: _EngineAnomalyLevel.high,
    ));
  }
  if (anomalies.isEmpty) {
    anomalies.add(const _EngineAnomaly(
      title: 'Contrôle cohérent',
      detail: 'Aucun signal bloquant détecté dans les données chargées.',
      level: _EngineAnomalyLevel.low,
    ));
  }
  return anomalies;
}

class _EngineHeader extends StatelessWidget {
  const _EngineHeader({required this.view});

  final _RwaEngineView view;

  @override
  Widget build(BuildContext context) {
    return _EnginePanel(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _EngineIconBox(
                icon: CupertinoIcons.function,
                color: _engineIndigo,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RWA Engine',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: _engineDeepBlue,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Calcul, explication, contrôle et simulation du capital réglementaire.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
              _EngineStatusPill(
                label: '${view.exposures.length} expositions',
                color: _engineBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngineSideBar extends StatelessWidget {
  const _EngineSideBar({
    required this.expanded,
    required this.onToggle,
  });

  static const double expandedWidth = 260;
  static const double collapsedWidth = 72;

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: _engineSidebarBg,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: _engineIndigo.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _EngineSidebarToggleButton(
            expanded: expanded,
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}

class _EngineSidebarToggleButton extends StatelessWidget {
  const _EngineSidebarToggleButton({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          expanded ? 'Réduire la barre latérale' : 'Agrandir la barre latérale',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: _EngineSplitPanelIcon(expanded: expanded),
        ),
      ),
    );
  }
}

class _EngineSplitPanelIcon extends StatelessWidget {
  const _EngineSplitPanelIcon({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 19,
      height: 18,
      child: CustomPaint(
        painter: _EngineSplitPanelIconPainter(expanded: expanded),
      ),
    );
  }
}

class _EngineSplitPanelIconPainter extends CustomPainter {
  const _EngineSplitPanelIconPainter({required this.expanded});

  final bool expanded;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _engineDeepBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = _engineDeepBlue.withValues(alpha: expanded ? 0.12 : 0.22)
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, stroke);

    final splitX = expanded ? size.width * 0.38 : size.width * 0.62;
    canvas.drawLine(
      Offset(splitX, 2),
      Offset(splitX, size.height - 2),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1.8, 1.8, splitX - 3.6, size.height - 3.6),
        const Radius.circular(2.8),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _EngineSplitPanelIconPainter oldDelegate) {
    return oldDelegate.expanded != expanded;
  }
}

class _EnginePanel extends StatelessWidget {
  const _EnginePanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _EngineIconBox extends StatelessWidget {
  const _EngineIconBox({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}

class _EngineStatusPill extends StatelessWidget {
  const _EngineStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _EngineEmptyState extends StatelessWidget {
  const _EngineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _EngineIconBox(
                icon: CupertinoIcons.function, color: _engineIndigo, size: 44),
            const SizedBox(height: 12),
            Text(
              'Aucune exposition chargée',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _engineDeepBlue,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              'Le moteur RWA utilisera les expositions créées ou importées dans la section Expositions.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
