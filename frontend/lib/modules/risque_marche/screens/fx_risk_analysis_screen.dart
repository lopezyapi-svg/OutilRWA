/// Écran d'analyse du Risque de Change - Version refactorisée
/// Présentation multi-niveaux: Titres, Agrégation Devise, Calculs Prudentiels
/// Conforme à la spécification BCEAO
library fx_risk_analysis_screen;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/fx_security_analysis.dart';
import '../services/fx_security_analysis_service.dart';
import '../services/market_data_import_store.dart';

const Color _fxPrimary = Color(0xFF2563EB);
const Color _fxSuccess = Color(0xFF10B981);
const Color _fxDanger = Color(0xFFEF4444);
const Color _fxWarning = Color(0xFFF59E0B);
const Color _fxText = Color(0xFF1F2937);
const Color _fxMuted = Color(0xFF6B7280);
const Color _fxBorder = Color(0xFFE5E7EB);

bool _isFxDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _fxSurfaceFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFF1F2937) : Colors.white;

Color _fxBorderFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFF374151) : _fxBorder;

Color _fxTextFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFFF3F4F6) : _fxText;

Color _fxMutedFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFFD1D5DB) : _fxMuted;

/// Écran principal d'analyse du Risque de Change
class FxRiskAnalysisScreen extends StatefulWidget {
  const FxRiskAnalysisScreen({
    super.key,
    this.initialData,
  });

  final FxRiskAnalysisResult? initialData;

  @override
  State<FxRiskAnalysisScreen> createState() => _FxRiskAnalysisScreenState();
}

class _FxRiskAnalysisScreenState extends State<FxRiskAnalysisScreen> {
  FxRiskAnalysisResult _analysisResult = _emptyFxRiskAnalysisResult();
  final _service = FxSecurityAnalysisService();
  bool _loadingMarketData = true;

  List<MarketPortfolioRecord> get _records {
    final snapshot = MarketDataImportStore.instance.snapshotNotifier.value;
    final bonds = snapshot.datasetFor(MarketPortfolioType.bonds)?.records ?? [];
    return bonds;
  }

  @override
  void initState() {
    super.initState();
    MarketDataImportStore.instance.snapshotNotifier.addListener(_onDataChanged);
    _loadMarketDataAndRunAnalysis();
  }

  void _onDataChanged() {
    if (mounted) _runAnalysis();
  }

  Future<void> _loadMarketDataAndRunAnalysis() async {
    await MarketDataImportStore.instance.initialized;
    if (!mounted) return;
    setState(() => _loadingMarketData = false);
    _runAnalysis();
  }

  void _runAnalysis() {
    final records = _records;
    if (records.isEmpty) {
      setState(() => _analysisResult = _emptyFxRiskAnalysisResult());
      return;
    }
    try {
      final result = _service.analyzePortfolio(
        records: records,
        analysisDate: DateTime.now(),
      );
      if (mounted) {
        setState(() => _analysisResult = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analysisResult = _emptyFxRiskAnalysisResult());
      }
    }
  }

  @override
  void dispose() {
    MarketDataImportStore.instance.snapshotNotifier
        .removeListener(_onDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPIs fixes en haut
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding,
                AppTheme.pagePadding, AppTheme.pagePadding, 0),
            child: _FxKpiSection(result: _analysisResult),
          ),
          const SizedBox(height: 16),
          // Titre fixe
          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
            child: Text(
              'Titres exposés au risque de change',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tableau fixe (scroll interne)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 0,
                  AppTheme.pagePadding, AppTheme.pagePadding),
              child: _loadingMarketData
                  ? const Center(child: CupertinoActivityIndicator())
                  : _analysisResult.securities.isEmpty
                      ? const _FxEmptyState()
                      : _FxSecuritiesTable(
                          securities: _analysisResult.securities,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

FxRiskAnalysisResult _emptyFxRiskAnalysisResult() {
  final now = DateTime.now();
  return FxRiskAnalysisResult(
    securities: const [],
    currencyExposures: const [],
    totalExposure: 0,
    globalFxGainLoss: 0,
    totalLongPositions: 0,
    totalShortPositions: 0,
    globalNetPosition: 0,
    capitalRequirement: 0,
    rwaChange: 0,
    marketRiskContribution: 0,
    analysisDate: now,
  );
}

class _FxEmptyState extends StatelessWidget {
  const _FxEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _fxSurfaceFor(context),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _fxBorderFor(context)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _fxPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Icon(
                CupertinoIcons.tray,
                color: _fxPrimary,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune donnée marché importée',
              style: TextStyle(
                color: _fxTextFor(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Importez le portefeuille depuis la base risque marché pour afficher les titres exposés.',
              style: TextStyle(
                color: _fxMutedFor(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section des KPIs
class _FxKpiSection extends StatelessWidget {
  const _FxKpiSection({required this.result});

  final FxRiskAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final itemsPerRow = w < 600
            ? 2
            : w < 1000
                ? 3
                : 5;

        final gain = result.globalFxGainLoss;
        final gainPercent = result.totalExposure > 0
            ? (gain / result.totalExposure) * 100
            : 0.0;

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: itemsPerRow,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 86,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _FxKpiCard(
              icon: CupertinoIcons.money_dollar_circle_fill,
              label: 'Exposition Totale',
              value: formatLargeNumber(result.totalExposure),
              unit: 'FCFA',
              color: _fxPrimary,
              subtitle:
                  '${result.currenciesCount} devise${result.currenciesCount > 1 ? 's' : ''} · ${result.exposedSecuritiesCount} titre${result.exposedSecuritiesCount > 1 ? 's' : ''}',
            ),
            _FxKpiCard(
              icon: CupertinoIcons.chart_bar_alt_fill,
              label: 'Gain/Perte Global',
              value: formatLargeNumber(gain.abs()),
              unit: 'FCFA',
              color: gain >= 0 ? _fxSuccess : _fxDanger,
              isNegative: gain < 0,
              subtitle:
                  '${result.securitiesWithGain} gain${result.securitiesWithGain > 1 ? 's' : ''} · ${result.securitiesWithLoss} perte${result.securitiesWithLoss > 1 ? 's' : ''}',
              trend: gain.abs() < 0.01
                  ? null
                  : _FxTrend(
                      isPositive: gain >= 0,
                      label:
                          '${gain >= 0 ? '+' : '−'}${gainPercent.abs().toStringAsFixed(2)}%',
                    ),
            ),
            _FxKpiCard(
              icon: CupertinoIcons.shield_lefthalf_fill,
              label: 'Exigence FP Change',
              value: formatLargeNumber(result.capitalRequirement),
              unit: 'FCFA',
              color: _fxWarning,
              subtitle: 'Position nette × 8 %',
            ),
            _FxKpiCard(
              icon: CupertinoIcons.graph_circle_fill,
              label: 'RWA Change',
              value: formatLargeNumber(result.rwaChange),
              unit: 'FCFA',
              color: _fxDanger,
              subtitle: 'Exigence FP × 12,5',
            ),
            _FxKpiCard(
              icon: CupertinoIcons.chart_pie_fill,
              label: 'Contribution Risque Marché',
              value: result.marketRiskContribution.toStringAsFixed(1),
              unit: '%',
              color: _fxPrimary,
              subtitle: 'Part du RWA marché total',
            ),
          ],
        );
      },
    );
  }
}

/// Indicateur de tendance affiché dans une puce sur la carte KPI.
class _FxTrend {
  const _FxTrend({required this.isPositive, required this.label});

  final bool isPositive;
  final String label;
}

/// Carte KPI moderne — badge dégradé, hiérarchie typographique soignée,
/// sous-titre contextuel, puce de tendance et effet de survol.
class _FxKpiCard extends StatefulWidget {
  const _FxKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.subtitle,
    this.trend,
    this.isNegative = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? subtitle;
  final _FxTrend? trend;
  final bool isNegative;

  @override
  State<_FxKpiCard> createState() => _FxKpiCardState();
}

class _FxKpiCardState extends State<_FxKpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = _isFxDark(context);
    final surface = _fxSurfaceFor(context);
    final color = widget.color;
    // Fond légèrement teinté par l'accent pour un rendu riche et premium.
    final tinted = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.10 : 0.045),
      surface,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [surface, tinted],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: _hovered ? 0.20 : 0.09),
              blurRadius: _hovered ? 22 : 13,
              offset: Offset(0, _hovered ? 10 : 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge d'icône en dégradé avec halo coloré.
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    Color.lerp(color, Colors.black, 0.22) ?? color,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.38),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _fxMutedFor(context),
                          ),
                        ),
                      ),
                      if (widget.trend != null) ...[
                        const SizedBox(width: 6),
                        _FxTrendChip(trend: widget.trend!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.isNegative ? '−${widget.value}' : widget.value,
                          style: TextStyle(
                            fontSize: 21,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _fxTextFor(context),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1.5),
                          child: Text(
                            widget.unit,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: _fxMutedFor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _fxMutedFor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puce de tendance (▲/▼) affichée en haut de carte.
class _FxTrendChip extends StatelessWidget {
  const _FxTrendChip({required this.trend});

  final _FxTrend trend;

  @override
  Widget build(BuildContext context) {
    final color = trend.isPositive ? _fxSuccess : _fxDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend.isPositive
                ? CupertinoIcons.arrow_up_right
                : CupertinoIcons.arrow_down_right,
            size: 9,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            trend.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tableau des titres exposés - colonnes TITRE et STATUT fixes
class _FxSecuritiesTable extends StatefulWidget {
  const _FxSecuritiesTable({required this.securities});

  final List<FxSecurityAnalysis> securities;

  @override
  State<_FxSecuritiesTable> createState() => _FxSecuritiesTableState();
}

class _FxSecuritiesTableState extends State<_FxSecuritiesTable> {
  // Défilement VERTICAL : une seule liste virtualisée (ListView.builder) pour
  // tout le corps. Chaque ligne est UN widget unique qui contient à la fois la
  // colonne gauche figée, le milieu et la colonne droite figée ; comme tout
  // partage l'unique position de défilement vertical, les colonnes figées ne
  // peuvent JAMAIS dériver par rapport au milieu — l'alignement est garanti par
  // construction, sans aucune synchronisation à maintenir. La virtualisation
  // est conservée : seules les lignes visibles sont construites (indispensable
  // pour un portefeuille de plusieurs milliers de titres).
  final ScrollController _bodyVSC = ScrollController();

  // Défilement HORIZONTAL du milieu : synchronisé entre l'entête, le pied et
  // chaque ligne visible via le groupe lié — c'est précisément l'usage prévu de
  // ce paquet (synchroniser le défilement horizontal d'une liste de lignes).
  // Chaque ligne ajoute son contrôleur au groupe à sa création et le retire au
  // recyclage ; le groupe ne gère donc à tout instant que les lignes visibles.
  final LinkedScrollControllerGroup _hGroup = LinkedScrollControllerGroup();
  late final ScrollController _headerHSC = _hGroup.addAndGet();
  late final ScrollController _footerHSC = _hGroup.addAndGet();

  int? _selectedIndex;
  static const Color _selColor = Color(0xFFE3F2FD);

  @override
  void dispose() {
    _headerHSC.dispose();
    _footerHSC.dispose();
    _bodyVSC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final securities = widget.securities;
    final longSecurities =
        securities.where((s) => s.positionType == FxPositionType.long).toList();
    final shortSecurities = securities
        .where((s) => s.positionType == FxPositionType.short)
        .toList();

    double sumLongNominalXof = 0, sumLongRwa = 0, sumLongGain = 0;
    double sumShortNominalXof = 0, sumShortRwa = 0, sumShortGain = 0;

    for (final s in longSecurities) {
      sumLongNominalXof += s.currentValueInXof;
      sumLongRwa += s.rwa;
      sumLongGain += s.fxGainLoss;
    }
    for (final s in shortSecurities) {
      sumShortNominalXof += s.currentValueInXof;
      sumShortRwa += s.rwa;
      sumShortGain += s.fxGainLoss;
    }

    const rowH = 40.0;
    const headerTextLight = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white);
    final cellText = TextStyle(fontSize: 11, color: _fxTextFor(context));

    return LayoutBuilder(builder: (context, constraints) {
      // Largeurs naturelles des colonnes.
      const naturalColW = <int, double>{
        0: 180, // ÉMETTEUR (Left fixed)
        1: 80, // DEVISE
        2: 190, // VALEUR NOMINALE (XOF)
        3: 140, // VARIATION DEVISE (%)
        4: 120, // GAIN/PERTE (%)
        5: 120, // POSITION
        6: 150, // RWA (XOF)
        7: 160, // GAIN/PERTE DE CHANGE (Right fixed)
      };
      const naturalMiddle = 80 + 190 + 140 + 120 + 120 + 150; // 800
      // Quand le tableau dispose de plus d'espace que sa largeur naturelle, on
      // étire proportionnellement les colonnes du milieu pour occuper toute la
      // largeur : plus d'espace vide entre RWA (XOF) et GAIN/PERTE DE CHANGE.
      // Sinon (écran étroit) on garde les largeurs naturelles et le milieu
      // défile horizontalement comme avant.
      final availableMiddle =
          constraints.maxWidth - naturalColW[0]! - naturalColW[7]!;
      final stretch =
          constraints.maxWidth.isFinite && availableMiddle > naturalMiddle
              ? availableMiddle / naturalMiddle
              : 1.0;
      final colW = <int, double>{
        0: naturalColW[0]!,
        1: naturalColW[1]! * stretch,
        2: naturalColW[2]! * stretch,
        3: naturalColW[3]! * stretch,
        4: naturalColW[4]! * stretch,
        5: naturalColW[5]! * stretch,
        6: naturalColW[6]! * stretch,
        7: naturalColW[7]!,
      };
      final middleWidth =
          colW[1]! + colW[2]! + colW[3]! + colW[4]! + colW[5]! + colW[6]!;
      // build header cells for scrollable middle (cols 1-6), sized with colW
      final headerMiddle = Row(children: [
        SizedBox(
            width: colW[1]!,
            child: _HCell('DEVISE', TextAlign.left, headerTextLight)),
        SizedBox(
            width: colW[2]!,
            child: _HCell(
                'VALEUR NOMINALE (XOF)', TextAlign.right, headerTextLight)),
        SizedBox(
            width: colW[3]!,
            child: _HCell(
                'VARIATION DEVISE (%)', TextAlign.right, headerTextLight)),
        SizedBox(
            width: colW[4]!,
            child: _HCell('GAIN/PERTE (%)', TextAlign.right, headerTextLight)),
        SizedBox(
            width: colW[5]!,
            child: _HCell('POSITION', TextAlign.center, headerTextLight)),
        SizedBox(
            width: colW[6]!,
            child: _HCell('RWA (XOF)', TextAlign.right, headerTextLight)),
      ]);

      // Largeurs des 6 colonnes du milieu (cols 1..6), dans l'ordre.
      final middleWidths = <double>[
        colW[1]!,
        colW[2]!,
        colW[3]!,
        colW[4]!,
        colW[5]!,
        colW[6]!,
      ];

      // footer builders per section
      Widget leftFooter(String label, Color bg) => Container(
            height: rowH,
            width: colW[0]!,
            decoration: BoxDecoration(
                color: bg,
                border:
                    const Border(top: BorderSide(color: _fxBorder, width: 1))),
            child: _FCell(label, context, bold: true),
          );
      Widget middleFooter(double nominalXof, double rwaXof, Color bg) =>
          Container(
            height: rowH,
            decoration: BoxDecoration(
                color: bg,
                border:
                    const Border(top: BorderSide(color: _fxBorder, width: 1))),
            child: Row(children: [
              SizedBox(width: colW[1]!, child: _FCell('', context)),
              SizedBox(
                  width: colW[2]!,
                  child: _FCell(formatLargeNumber(nominalXof), context,
                      bold: true, align: TextAlign.right)),
              SizedBox(
                  width: colW[3]!,
                  child: _FCell('—', context, align: TextAlign.right)),
              SizedBox(
                  width: colW[4]!,
                  child: _FCell('—', context, align: TextAlign.right)),
              SizedBox(width: colW[5]!, child: _FCell('', context)),
              SizedBox(
                  width: colW[6]!,
                  child: _FCell(formatLargeNumber(rwaXof), context,
                      bold: true, align: TextAlign.right)),
            ]),
          );
      Widget rightFooter(double gain, Color bg) => Container(
            height: rowH,
            width: colW[7]!,
            decoration: BoxDecoration(
                color: bg,
                border:
                    const Border(top: BorderSide(color: _fxBorder, width: 1))),
            child: _FCell(formatLargeNumber(gain), context,
                bold: true,
                color: gain >= 0 ? _fxSuccess : _fxDanger,
                align: TextAlign.right),
          );

      return Container(
        decoration: BoxDecoration(
          color: _fxSurfaceFor(context),
          border: Border.all(color: _fxBorderFor(context)),
          borderRadius: BorderRadius.circular(1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: Builder(
            builder: (context) {
              const bottomH = rowH + 1.0 + rowH;

              return Column(children: [
                // Header row
                SizedBox(
                  height: rowH,
                  child: Row(children: [
                    Container(
                        width: colW[0]!,
                        color: const Color(0xFF1A237E),
                        child: _HCell(
                            'ÉMETTEUR', TextAlign.left, headerTextLight)),
                    Expanded(
                      child: Container(
                        height: rowH,
                        color: const Color(0xFF1A237E),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _headerHSC,
                            child: headerMiddle,
                          ),
                        ),
                      ),
                    ),
                    Container(
                        width: colW[7]!,
                        color: const Color(0xFF1A237E),
                        child: _HCell('GAIN/PERTE DE CHANGE', TextAlign.right,
                            headerTextLight)),
                  ]),
                ),
                Container(height: 1, color: _fxBorder),
                // Body — liste verticale unique et VIRTUALISÉE. Chaque ligne
                // (_FxSecurityRow) porte la colonne gauche figée, le milieu
                // défilant et la colonne droite figée ; toutes partagent
                // l'unique défilement vertical, donc l'alignement des colonnes
                // figées avec le milieu est garanti par construction. Le milieu
                // de chaque ligne se synchronise horizontalement avec l'entête,
                // le pied et les autres lignes via le groupe lié.
                Expanded(
                  child: Scrollbar(
                    controller: _bodyVSC,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _bodyVSC,
                      itemExtent: rowH,
                      itemCount: securities.length,
                      itemBuilder: (context, i) {
                        final cells =
                            _buildDataCells(securities[i], i, cellText);
                        final selected = i == _selectedIndex;
                        final bg = selected
                            ? _selColor
                            : (i.isEven
                                ? Colors.transparent
                                : Colors.black.withValues(alpha: 0.02));
                        return _FxSecurityRow(
                          hGroup: _hGroup,
                          height: rowH,
                          background: bg,
                          leftWidth: colW[0]!,
                          middleWidth: middleWidth,
                          rightWidth: colW[7]!,
                          leftCell: cells[0],
                          middleCells: cells.sublist(1, 7),
                          middleWidths: middleWidths,
                          rightCell: cells[7],
                          onTap: () => setState(() =>
                              _selectedIndex = _selectedIndex == i ? null : i),
                        );
                      },
                    ),
                  ),
                ),
                // Fixed footer rows
                SizedBox(
                  height: bottomH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: colW[0]!,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            leftFooter('Position Longue',
                                _fxSuccess.withValues(alpha: 0.06)),
                            const Divider(height: 0, thickness: 1, color: _fxBorder),
                            leftFooter('Position Courte',
                                _fxDanger.withValues(alpha: 0.06)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _footerHSC,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                middleFooter(sumLongNominalXof, sumLongRwa,
                                    _fxSuccess.withValues(alpha: 0.06)),
                                const Divider(
                                    height: 0, thickness: 1, color: _fxBorder),
                                middleFooter(sumShortNominalXof, sumShortRwa,
                                    _fxDanger.withValues(alpha: 0.06)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: colW[7]!,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            rightFooter(sumLongGain,
                                _fxSuccess.withValues(alpha: 0.06)),
                            const Divider(height: 0, thickness: 1, color: _fxBorder),
                            rightFooter(sumShortGain,
                                _fxDanger.withValues(alpha: 0.06)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]);
            },
          ),
        ),
      );
    });
  }

  /// Construit les 8 cellules d'une ligne (cols 0..7). Le fond (zébrage /
  /// sélection) est porté par la ligne elle-même (_FxSecurityRow), les cellules
  /// restent donc transparentes.
  List<Widget> _buildDataCells(
      FxSecurityAnalysis s, int index, TextStyle baseStyle) {
    return [
      _DCell(s.titleName, baseStyle),
      _DCell(s.currency,
          baseStyle.copyWith(fontWeight: FontWeight.w600, color: _fxPrimary),
          chip: _fxPrimary.withValues(alpha: 0.08)),
      _DCell(formatLargeNumber(s.currentValueInXof), baseStyle,
          align: TextAlign.right),
      _DCell(
          '${s.currencyVariationPercent >= 0 ? '+' : ''}${formatDecimal(s.currencyVariationPercent, 2)}%',
          baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: s.currencyVariationPercent >= 0 ? _fxSuccess : _fxDanger),
          align: TextAlign.right),
      _DCell(
          '${s.fxGainLossPercent >= 0 ? '+' : ''}${formatDecimal(s.fxGainLossPercent, 2)}%',
          baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: s.fxGainLossPercent >= 0 ? _fxSuccess : _fxDanger),
          align: TextAlign.right),
      _DCell(
          s.positionLabel,
          baseStyle.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: s.positionType == FxPositionType.long
                  ? _fxSuccess
                  : _fxDanger),
          align: TextAlign.center,
          chip: s.positionType == FxPositionType.long
              ? _fxSuccess.withValues(alpha: 0.1)
              : _fxDanger.withValues(alpha: 0.1)),
      _DCell(formatLargeNumber(s.rwa),
          baseStyle.copyWith(fontWeight: FontWeight.w600),
          align: TextAlign.right),
      _DCell(
          formatLargeNumber(s.fxGainLoss),
          baseStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: s.fxGainLoss >= 0 ? _fxSuccess : _fxDanger),
          align: TextAlign.right),
    ];
  }
}

/// Une ligne du corps du tableau.
///
/// Structure : colonne gauche figée · milieu défilant horizontalement · colonne
/// droite figée — le tout dans UN seul widget, donc partageant l'unique
/// défilement vertical de la liste (alignement garanti). Le milieu possède son
/// propre [ScrollController] ajouté au [LinkedScrollControllerGroup] partagé :
/// toutes les lignes visibles, l'entête et le pied défilent ainsi
/// horizontalement à l'unisson. Le contrôleur est ajouté à la création de la
/// ligne et libéré à son recyclage, ce qui préserve la virtualisation.
class _FxSecurityRow extends StatefulWidget {
  const _FxSecurityRow({
    required this.hGroup,
    required this.height,
    required this.background,
    required this.leftWidth,
    required this.middleWidth,
    required this.rightWidth,
    required this.leftCell,
    required this.middleCells,
    required this.middleWidths,
    required this.rightCell,
    required this.onTap,
  });

  final LinkedScrollControllerGroup hGroup;
  final double height;
  final Color background;
  final double leftWidth;
  final double middleWidth;
  final double rightWidth;
  final Widget leftCell;
  final List<Widget> middleCells;
  final List<double> middleWidths;
  final Widget rightCell;
  final VoidCallback onTap;

  @override
  State<_FxSecurityRow> createState() => _FxSecurityRowState();
}

class _FxSecurityRowState extends State<_FxSecurityRow> {
  late final ScrollController _hsc = widget.hGroup.addAndGet();

  @override
  void dispose() {
    _hsc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.background,
          border: Border(
            bottom: BorderSide(
                color: _fxBorder.withValues(alpha: 0.3), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: widget.leftWidth, child: widget.leftCell),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _hsc,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: widget.middleWidth,
                    child: Row(
                      children: [
                        for (int j = 0; j < widget.middleCells.length; j++)
                          SizedBox(
                              width: widget.middleWidths[j],
                              child: widget.middleCells[j]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: widget.rightWidth, child: widget.rightCell),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets internes ───

/// Ligne d'entête (pas d'ellipsis, tout doit être visible)
/// Convertit un [TextAlign] horizontal en [Alignment] de cellule.
Alignment _cellAlignment(TextAlign align) => switch (align) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };

Widget _HCell(String text, TextAlign align, TextStyle style) => Container(
      height: 40,
      alignment: _cellAlignment(align),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(text, style: style, textAlign: align, maxLines: 1),
    );

/// Ligne de donnée
Widget _DCell(String text, TextStyle style,
        {TextAlign align = TextAlign.left, Color? chip, Color? bg}) =>
    Container(
      height: 40,
      decoration: BoxDecoration(color: bg ?? Colors.transparent),
      alignment: _cellAlignment(align),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: chip != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: chip, borderRadius: BorderRadius.circular(3)),
              child: Text(text,
                  style: style,
                  textAlign: align,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            )
          : Text(text,
              style: style,
              textAlign: align,
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
    );

/// Ligne de footer
Widget _FCell(String text, BuildContext context,
        {TextAlign align = TextAlign.left, bool bold = false, Color? color}) =>
    _buildCell(
      text,
      TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? _fxTextFor(context)),
      align,
      10,
    );

/// Cellule générique avec hauteur et alignement
Widget _buildCell(String text, TextStyle style, TextAlign align, double padH) =>
    Container(
      height: 40,
      alignment: _cellAlignment(align),
      padding: EdgeInsets.symmetric(horizontal: padH),
      child: Text(text,
          style: style,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          maxLines: 1),
    );
