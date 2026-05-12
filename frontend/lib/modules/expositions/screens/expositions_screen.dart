// Ce fichier affiche l'inventaire interactif des expositions.
import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/localization/app_localization.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../referentiels/models/referentiels_models.dart';
import '../models/exposition_models.dart';
import '../widgets/excel_import_dialog.dart';
import '../widgets/exposure_form_card.dart';

enum _ExposureTableMode { full, dense, compact, minimal }

enum _ExposureExportFormat { excel, pdf }

class _DeleteSelectionDecision {
  const _DeleteSelectionDecision({
    required this.confirmed,
    required this.reindexIds,
  });

  final bool confirmed;
  final bool reindexIds;
}

class ExpositionsScreen extends StatefulWidget {
  const ExpositionsScreen({
    super.key,
    required this.api,
    required this.displayCurrencyListenable,
  });

  final RwaApiService api;
  final ValueNotifier<String> displayCurrencyListenable;

  @override
  State<ExpositionsScreen> createState() => _ExpositionsScreenState();
}

class _ExpositionsScreenState extends State<ExpositionsScreen> {
  static const double _mainTableMinWidth = 3180;
  static const double _controlGap = 8;
  static const double _filterControlHeight = 30;
  static const double _textFilterControlHeight = 44;
  static const double _resetButtonSize = 25;
  static const double _floatingActionButtonSize = 44;
  static const double _floatingActionButtonRadius = 10;

  late Future<void> _future;
  StreamSubscription<int>? _portfolioRefreshSubscription;
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();
  final GlobalKey<TooltipState> _tableHelperTooltipKey =
      GlobalKey<TooltipState>();
  final TextEditingController _idFilterController = TextEditingController();
  final TextEditingController _counterpartyFilterController =
      TextEditingController();
  final TextEditingController _countryFilterController =
      TextEditingController();

  List<ExposureRecord> _allRows = const [];
  List<String> _ratings = prudentialRatings;
  String _categoryFilter = 'Toutes';
  String _zoneFilter = 'Toutes';
  String _ratingFilter = 'Toutes';
  String _crmFilter = 'Toutes';
  String _displayCurrency = 'XOF';
  String? _sortColumnKey = 'id';
  bool _sortAscending = true;
  bool _isImporting = false;
  bool _isDeleting = false;
  bool _isExporting = false;
  bool _hasLoadedReferentiels = false;
  Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _displayCurrency = widget.displayCurrencyListenable.value;
    widget.displayCurrencyListenable.addListener(_handleDisplayCurrencyChanged);
    _future = _refresh();
    _portfolioRefreshSubscription =
        widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      _queueRefresh();
    });
  }

  @override
  void dispose() {
    _portfolioRefreshSubscription?.cancel();
    widget.displayCurrencyListenable
        .removeListener(_handleDisplayCurrencyChanged);
    _tableVerticalController.dispose();
    _tableHorizontalController.dispose();
    _idFilterController.dispose();
    _counterpartyFilterController.dispose();
    _countryFilterController.dispose();
    super.dispose();
  }

  void _handleDisplayCurrencyChanged() {
    final nextCurrency = widget.displayCurrencyListenable.value;
    if (!mounted || _displayCurrency == nextCurrency) return;
    setState(() {
      _displayCurrency = nextCurrency;
    });
  }

  Future<void> _queueRefresh() {
    final refreshFuture = _refresh();
    if (mounted) {
      setState(() {
        _future = refreshFuture;
      });
    } else {
      _future = refreshFuture;
    }
    return refreshFuture;
  }

  @override
  Widget build(BuildContext context) {
    final screenBusyMessage = _screenBusyMessage;
    final isScreenBusy = screenBusyMessage != null;

    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _allRows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && _allRows.isEmpty) {
          return Center(
            child: Text(
              context.tr('Erreur: {{error}}', args: {'error': snapshot.error}),
            ),
          );
        }

        final visibleRows = _buildVisibleRows();
        final visibleSummary = _summarize(visibleRows);

        return LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: PageHeader(
                          title: 'Expositions',
                          subtitle:
                              'Grille prudentielle de saisie, import, modification et suivi RWA avec zone UEMOA/CEMAC automatique.',
                          titleFontSize: 22,
                          subtitleFontSize: 11,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          trailing: _buildHeaderActionButtons(visibleRows),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, areaConstraints) {
                            final sectionWidth = areaConstraints.maxWidth > 1760
                                ? 1760.0
                                : areaConstraints.maxWidth;
                            return Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: sectionWidth,
                                height: areaConstraints.maxHeight,
                                child: SectionCard(
                                  title: '',
                                  child: Expanded(
                                    child: Column(
                                      children: [
                                        _buildControlsPanel(
                                          context,
                                        ),
                                        const SizedBox(height: 0),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                top: 16,
                                                child:
                                                    _buildScrollableExposureTable(
                                                  context,
                                                  visibleRows,
                                                ),
                                              ),
                                              Positioned(
                                                right: 4,
                                                top: 0,
                                                child: _buildTableHelperHint(
                                                  context,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        _buildCompactSummaryCards(
                                          context,
                                          visibleSummary,
                                          visibleRows.length,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 18,
                    bottom: 44,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_selectedIds.isNotEmpty) ...[
                          _buildDeleteSelectionButton(),
                          const SizedBox(height: 10),
                        ],
                        _buildFloatingIconButton(
                          onPressed: isScreenBusy ? null : _openCreatePanel,
                          tooltip: context.tr('Ajouter une exposition'),
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          icon: Icons.add,
                        ),
                      ],
                    ),
                  ),
                  if (screenBusyMessage != null)
                    Positioned.fill(
                      child: _buildScreenBusyOverlay(
                        context,
                        message: screenBusyMessage,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeleteSelectionButton() {
    return _buildFloatingIconButton(
      onPressed: _isDeleting || _isImporting ? null : _deleteSelection,
      tooltip: context.tr('Supprimer la sélection'),
      backgroundColor: AppTheme.danger,
      foregroundColor: Colors.white,
      child: _isDeleting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.delete_outline_rounded, size: 20),
    );
  }

  Widget _buildHeaderActionButtons(List<ExposureRecord> visibleRows) {
    final isScreenBusy = _screenBusyMessage != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildHeaderActionButton(
          label: _isImporting
              ? context.tr('Importation...')
              : context.tr('Import'),
          icon: Icons.file_upload_outlined,
          iconWidget: _isImporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : null,
          onPressed: isScreenBusy ? null : _showImportDialog,
          color: const Color(0xFF1E88E5),
        ),
        _buildHeaderActionButton(
          label: _isExporting
              ? context.tr('Exportation...')
              : context.tr('Export'),
          icon: Icons.file_download_outlined,
          iconWidget: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : null,
          onPressed: isScreenBusy || visibleRows.isEmpty
              ? null
              : () => _exportView(visibleRows),
          color: const Color(0xFF14A44D),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    Widget? iconWidget,
  }) {
    return SizedBox(
      height: 30,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          visualDensity: VisualDensity.compact,
        ),
        icon: iconWidget ?? Icon(icon, size: 14),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildFloatingButtonFrame({required Widget child}) {
    return SizedBox(
      width: _floatingActionButtonSize,
      height: _floatingActionButtonSize,
      child: child,
    );
  }

  Widget _buildFloatingIconButton({
    required VoidCallback? onPressed,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
    IconData? icon,
    Widget? child,
  }) {
    return Tooltip(
      message: tooltip,
      child: _buildFloatingButtonFrame(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: EdgeInsets.zero,
            minimumSize: const Size(
              _floatingActionButtonSize,
              _floatingActionButtonSize,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                _floatingActionButtonRadius,
              ),
            ),
          ),
          child: child ?? Icon(icon!, size: 20),
        ),
      ),
    );
  }

  String? get _screenBusyMessage {
    if (_isDeleting) {
      return 'Suppression des expositions en cours...';
    }
    if (_isImporting) {
      return 'Importation des expositions en cours...';
    }
    if (_isExporting) {
      return 'Exportation des expositions en cours...';
    }
    return null;
  }

  Widget _buildScreenBusyOverlay(
    BuildContext context, {
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.22),
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3C5E) : const Color(0xFFD9E4F6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.26 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Merci de patienter pendant la mise à jour des données.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600,
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

  final TextStyle _tableHeadingStyle = const TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 8.1,
    height: 1.0,
    letterSpacing: 0.18,
    color: Color(0xFFF5F8FF),
  );

  TextStyle get _tableCellStyle {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 9.8,
      height: 1.1,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
    );
  }

  Widget _buildScrollableExposureTable(
    BuildContext context,
    List<ExposureRecord> visibleRows,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13233E) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF304764) : AppTheme.border,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const tableMode = _ExposureTableMode.full;
            final viewportWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth - 2
                : MediaQuery.sizeOf(context).width - 24;
            final tableWidth = viewportWidth < _mainTableMinWidth
                ? _mainTableMinWidth
                : viewportWidth;
            final columnWidths = _mainTableColumnWidths(tableWidth, tableMode);

            return Scrollbar(
              controller: _tableHorizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _tableHorizontalController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      _buildStickyTableHeader(
                        columnWidths,
                        tableMode,
                        visibleRows,
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _tableVerticalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _tableVerticalController,
                            physics: const ClampingScrollPhysics(),
                            child: DataTable(
                              headingRowHeight: 0,
                              dataTextStyle: _tableCellStyle,
                              horizontalMargin: 0,
                              showCheckboxColumn: false,
                              columnSpacing: 0,
                              dataRowMinHeight: 38,
                              dataRowMaxHeight: 42,
                              columns: _buildBodyColumns(
                                columnWidths,
                                tableMode,
                              ),
                              rows: _buildDataRows(
                                visibleRows,
                                columnWidths,
                                tableMode,
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildCompactSummaryCards(
    BuildContext context,
    ExposureSummary summary,
    int visibleCount,
  ) {
    final rwAverage = summary.totalEad == 0
        ? 0.0
        : (summary.totalRwa / summary.totalEad) * 100;

    return Row(
      children: [
        Expanded(
          child: _buildCompactSummaryCard(
            context,
            label: 'Lignes',
            value: '$visibleCount',
            detail: context.tr(
              '{{count}} select.',
              args: {'count': _selectedIds.length},
            ),
            icon: Icons.segment_rounded,
            color: AppTheme.sidebarLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactSummaryCard(
            context,
            label: 'Exposition totale brute',
            value:
                '${AppFormatters.compactNumber(summary.totalExpositions)} $_displayCurrencyLabel',
            detail: 'Vue cour.',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.sidebarLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactSummaryCard(
            context,
            label: 'RWA total',
            value:
                '${AppFormatters.compactNumber(summary.totalRwa)} $_displayCurrencyLabel',
            detail: 'RW ${rwAverage.toStringAsFixed(0)}%',
            icon: Icons.shield_outlined,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactSummaryCard(
            context,
            label: 'Capital min.',
            value:
                '${AppFormatters.compactNumber(summary.totalCapital)} $_displayCurrencyLabel',
            detail: 'Exig. reg.',
            icon: Icons.account_balance_outlined,
            color: AppTheme.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSummaryCard(
    BuildContext context, {
    required String label,
    required String value,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints.tightFor(height: 40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 11, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 8.2,
                    height: 1,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                          fontSize: 9.1,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          detail.tr(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 7.8,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _fullTableColumnKeys = [
    'select',
    'id',
    'grant_date',
    'maturity_date',
    'exposure_maturity',
    'residual_maturity',
    'counterparty',
    'counterparty_rating',
    'country',
    'country_rating',
    'country_rw',
    'category',
    'rw',
    'gross',
    'source_currency',
    'crm_exists',
    'crm_type',
    'ead_bilan',
    'ead_total',
    'rwa',
    'capital',
  ];

  static const List<String> _denseTableColumnKeys = [
    'select',
    'id',
    'counterparty',
    'geo',
    'category',
    'rating',
    'gross',
    'ead',
    'rw',
    'rwa',
    'crm',
  ];

  static const List<String> _compactTableColumnKeys = [
    'select',
    'id',
    'counterparty',
    'geo',
    'category',
    'gross',
    'rw',
    'rwa',
    'crm',
  ];

  static const List<String> _minimalTableColumnKeys = [
    'select',
    'id',
    'counterparty',
    'category',
    'gross',
    'rwa',
    'crm',
  ];

  static const List<double> _mainTableWidthWeights = [
    0.32,
    0.82,
    0.98,
    1.02,
    1.18,
    1.16,
    1.48,
    1.12,
    1.02,
    1.08,
    0.95,
    1.32,
    0.92,
    1.22,
    0.60,
    0.86,
    0.94,
    1.02,
    1.02,
    1.08,
    1.10,
  ];

  static const List<double> _denseTableWidthWeights = [
    0.40,
    0.70,
    1.75,
    1,
    1.15,
    0.75,
    1,
    1,
    0.65,
    1,
    1,
  ];

  static const List<double> _compactTableWidthWeights = [
    0.75,
    1.10,
    2.35,
    1.55,
    1.75,
    1.55,
    1.10,
    1.40,
    1.45,
  ];

  static const List<double> _minimalTableWidthWeights = [
    0.85,
    1.25,
    3.00,
    2.30,
    2.00,
    1.80,
    1.80,
  ];

  List<double> _scaledColumnWidths(
    double maxWidth,
    List<double> weights, {
    bool includeCheckbox = false,
  }) {
    final totalWeight = weights.fold<double>(0, (sum, item) => sum + item);
    final reservedWidth = includeCheckbox ? 42.0 : 0.0;
    final usableWidth = (maxWidth - reservedWidth).clamp(0.0, double.infinity);
    return weights
        .map((weight) => usableWidth * (weight / totalWeight))
        .toList(growable: false);
  }

  List<String> _tableColumnKeysForMode(_ExposureTableMode mode) {
    switch (mode) {
      case _ExposureTableMode.full:
        return _fullTableColumnKeys;
      case _ExposureTableMode.dense:
        return _denseTableColumnKeys;
      case _ExposureTableMode.compact:
        return _compactTableColumnKeys;
      case _ExposureTableMode.minimal:
        return _minimalTableColumnKeys;
    }
  }

  List<double> _tableWeightsForMode(_ExposureTableMode mode) {
    switch (mode) {
      case _ExposureTableMode.full:
        return _mainTableWidthWeights;
      case _ExposureTableMode.dense:
        return _denseTableWidthWeights;
      case _ExposureTableMode.compact:
        return _compactTableWidthWeights;
      case _ExposureTableMode.minimal:
        return _minimalTableWidthWeights;
    }
  }

  bool _showCheckboxColumn(_ExposureTableMode mode) {
    return false;
  }

  List<double> _mainTableColumnWidths(
    double maxWidth,
    _ExposureTableMode mode,
  ) {
    return _scaledColumnWidths(
      maxWidth,
      _tableWeightsForMode(mode),
      includeCheckbox: _showCheckboxColumn(mode),
    );
  }

  Widget _tableFittedContent({
    required double width,
    required String text,
    required TextStyle style,
    String? tooltip,
    Alignment alignment = Alignment.centerLeft,
    TextAlign textAlign = TextAlign.left,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );

    return SizedBox(
      width: width,
      child: tooltip == null || tooltip.trim().isEmpty
          ? content
          : Tooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 180),
              showDuration: const Duration(seconds: 4),
              preferBelow: false,
              verticalOffset: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: TextStyle(
                color:
                    isDark ? const Color(0xFFF8FBFF) : const Color(0xFFF8FBFF),
                fontSize: 10.4,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF213252).withOpacity(0.98)
                    : const Color(0xFF16325C).withOpacity(0.96),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4D6C97)
                      : const Color(0xFF6F92C4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.32 : 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: content,
            ),
    );
  }

  Widget _tableText(
    String text,
    double width, {
    String? tooltip,
    Alignment alignment = Alignment.centerLeft,
    TextAlign textAlign = TextAlign.left,
    TextStyle? style,
  }) {
    return _tableFittedContent(
      width: width,
      text: text,
      style: style ?? _tableCellStyle,
      tooltip: tooltip,
      alignment: alignment,
      textAlign: textAlign,
    );
  }

  Widget _tableAmountText(
    double value, {
    required String currencyCode,
    required double width,
    Alignment alignment = Alignment.centerLeft,
    TextAlign textAlign = TextAlign.left,
    TextStyle? style,
  }) {
    final fullValue = AppFormatters.currency(value, currencyCode: currencyCode);
    final compactValue = AppFormatters.compactNumber(value);
    return _tableFittedContent(
      width: width,
      text: compactValue,
      style: style ?? _tableCellStyle,
      tooltip: fullValue,
      alignment: alignment,
      textAlign: textAlign,
    );
  }

  double _rwPercentValue(ExposureRecord row) {
    return (row.finalRw * 100).clamp(0.0, double.infinity).toDouble();
  }

  Color _rwGaugeColor(double rwPercent) {
    if (rwPercent <= 50) {
      return const Color(0xFF2FBF71);
    }
    if (rwPercent <= 100) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFE04F5F);
  }

  Color _rwRowTint(double rwPercent, {required bool isSelected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _rwGaugeColor(rwPercent).withOpacity(
      isDark ? (isSelected ? 0.22 : 0.12) : (isSelected ? 0.18 : 0.08),
    );
  }

  String _compactCrmValue(String value) {
    switch (value) {
      case 'CRM financee':
        return 'Financee';
      case 'CRM non financee':
        return 'Non financee';
      default:
        return value;
    }
  }

  String _compactGeoValue(ExposureRecord row) {
    final zone = switch (row.zone) {
      'Hors zone' => 'HZ',
      _ => row.zone,
    };
    return '${row.counterparty.country} / $zone';
  }

  int? _exposureIdOrder(String id) {
    if (!id.startsWith('CP')) {
      return null;
    }
    return int.tryParse(id.substring(2));
  }

  int _compareExposureIds(String left, String right) {
    final leftOrder = _exposureIdOrder(left);
    final rightOrder = _exposureIdOrder(right);
    if (leftOrder != null && rightOrder != null) {
      return leftOrder.compareTo(rightOrder);
    }
    if (leftOrder != null) {
      return -1;
    }
    if (rightOrder != null) {
      return 1;
    }
    return left.compareTo(right);
  }

  String _normalizeRatingForSort(String rating) {
    return rating
        .trim()
        .toUpperCase()
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('À', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Î', 'I')
        .replaceAll('Ï', 'I')
        .replaceAll('Ô', 'O')
        .replaceAll('Û', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _ratingSortRank(String rating) {
    final normalized = _normalizeRatingForSort(rating);
    const directRanks = <String, int>{
      'AAA': 0,
      'AA+': 1,
      'AA': 2,
      'AA-': 3,
      'AAA/AA': 3,
      'A+': 4,
      'A': 5,
      'A-': 6,
      'BBB+': 7,
      'BBB': 8,
      'BBB-': 9,
      'BB+': 10,
      'BB': 11,
      'BB-': 12,
      'BB/B': 12,
      'B+': 13,
      'B': 14,
      'B-': 15,
      '< B-': 16,
    };

    final directRank = directRanks[normalized];
    if (directRank != null) {
      return directRank;
    }

    if (normalized.contains('NON NOTE')) {
      return 17;
    }

    return switch (bucketizeRating(rating)) {
      'AAA/AA' => 3,
      'A' => 5,
      'BBB' => 8,
      'BB/B' => 12,
      '< B-' => 16,
      _ => 17,
    };
  }

  int _compareRatings(String left, String right) {
    final leftRank = _ratingSortRank(left);
    final rightRank = _ratingSortRank(right);
    if (leftRank != rightRank) {
      return leftRank.compareTo(rightRank);
    }
    return _normalizeRatingForSort(left)
        .compareTo(_normalizeRatingForSort(right));
  }

  List<String> _sortRatings(List<String> ratings) {
    final ordered = ratings
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: true);
    ordered.sort(_compareRatings);
    return ordered;
  }

  int _compareNullableDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return -1;
    }
    if (right == null) {
      return 1;
    }
    return left.compareTo(right);
  }

  String _formatExposureDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return AppFormatters.shortDate(value);
  }

  int _durationInMonths(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return 0;
    }
    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }

  String _formatDurationMonths(int totalMonths) {
    return '$totalMonths mois';
  }

  String _exposureMaturityLabel(ExposureRecord row) {
    return _formatDurationMonths(
      _durationInMonths(row.grantDate, row.maturityDate),
    );
  }

  String _residualMaturityLabel(ExposureRecord row) {
    return _formatDurationMonths(
      _durationInMonths(row.analysisDate, row.maturityDate),
    );
  }

  double _countryRiskWeightValue(ExposureRecord row) {
    return lookupPrudentialRiskWeight('a', row.counterparty.countryRating);
  }

  String _formatRiskWeight(double value) {
    final percent = value * 100;
    final decimals = percent == percent.roundToDouble() ? 0 : 1;
    return '${percent.toStringAsFixed(decimals)}%';
  }

  String _crmExistsLabel(ExposureRecord row) {
    return row.crmModeLabel == 'Aucune' ? 'Non' : 'Oui';
  }

  String _crmTypeTableValue(ExposureRecord row) {
    switch (row.crmModeLabel) {
      case 'CRM financee':
        return 'financee';
      case 'CRM non financee':
        return 'non financee';
      default:
        return 'aucune';
    }
  }

  String _columnLabelForKey(String key, _ExposureTableMode mode) {
    switch (key) {
      case 'select':
        return '';
      case 'id':
        return 'ID_Exposition';
      case 'grant_date':
        return "Date d'octroi";
      case 'maturity_date':
        return "Date d'échéance";
      case 'exposure_maturity':
        return "Maturité de l'exposition";
      case 'residual_maturity':
        return 'Maturité résiduelle';
      case 'counterparty':
        return 'Contrepartie';
      case 'counterparty_rating':
        return 'Notation_externe_contrepartie';
      case 'country':
        return 'Pays_contrepartie';
      case 'country_rating':
        return 'Notation_externe_pays';
      case 'country_rw':
        return 'Pondération_pays';
      case 'geo':
        return 'Geo';
      case 'source_currency':
        return 'Devise';
      case 'category':
        return "Catégorie d'exposition";
      case 'rating':
        return 'Notation';
      case 'gross':
        return 'Montant_exposition_brut';
      case 'crm_exists':
        return 'CRM_existe';
      case 'crm_type':
        return 'Type_CRM';
      case 'ead_bilan':
        return 'EAD_bilan';
      case 'ead_total':
        return 'EAD_Total';
      case 'rw':
        return 'Pondération (RW)';
      case 'rwa':
        return 'RWA_crédit';
      case 'capital':
        return 'Capital_min_reg';
      case 'crm':
        return 'CRM';
      default:
        return key;
    }
  }

  Alignment _columnAlignment(String key) {
    if (key == 'ead' || key == 'rwa') {
      return Alignment.centerLeft;
    }
    if (key == 'rw') {
      return Alignment.centerLeft;
    }
    return Alignment.centerLeft;
  }

  TextAlign _columnTextAlign(String key) {
    if (key == 'ead' || key == 'rwa') {
      return TextAlign.left;
    }
    if (key == 'rw') {
      return TextAlign.left;
    }
    return TextAlign.left;
  }

  String? _sortKeyForColumn(String key) {
    switch (key) {
      case 'id':
      case 'grant_date':
      case 'maturity_date':
      case 'exposure_maturity':
      case 'residual_maturity':
      case 'counterparty':
      case 'counterparty_rating':
      case 'country':
      case 'country_rating':
      case 'country_rw':
      case 'source_currency':
      case 'category':
      case 'rating':
      case 'gross':
      case 'crm_exists':
      case 'crm_type':
      case 'ead_bilan':
      case 'ead_total':
      case 'rw':
      case 'rwa':
      case 'capital':
        return key;
      default:
        return null;
    }
  }

  bool _areAllRowsSelected(List<ExposureRecord> rows) {
    return rows.isNotEmpty &&
        rows.every((row) => _selectedIds.contains(row.id));
  }

  bool _areSomeRowsSelected(List<ExposureRecord> rows) {
    return rows.any((row) => _selectedIds.contains(row.id));
  }

  Widget _tableCheckbox({
    required double width,
    required bool? value,
    required ValueChanged<bool?>? onChanged,
    bool tristate = false,
    Color? borderColor,
    Color? activeColor,
    Color? checkColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBorderColor = borderColor ??
        (isDark ? const Color(0xFFAEC2E4) : AppTheme.sidebarLight);
    final resolvedActiveColor = activeColor ?? AppTheme.sidebarLight;
    final resolvedCheckColor = checkColor ?? Colors.white;
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.center,
        child: Checkbox(
          value: value,
          tristate: tristate,
          onChanged: onChanged,
          activeColor: resolvedActiveColor,
          checkColor: resolvedCheckColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: resolvedBorderColor, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyTableHeader(
    List<double> widths,
    _ExposureTableMode mode,
    List<ExposureRecord> rows,
  ) {
    final columnKeys = _tableColumnKeysForMode(mode);
    final allSelected = _areAllRowsSelected(rows);
    final someSelected = _areSomeRowsSelected(rows);

    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A518A),
            Color(0xFF23477A),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
      ),
      child: Row(
        children: List<Widget>.generate(columnKeys.length, (index) {
          final key = columnKeys[index];
          if (key == 'select') {
            return SizedBox(
              width: widths[index],
              height: 36,
              child: _tableCheckbox(
                width: widths[index],
                value: rows.isEmpty
                    ? false
                    : (allSelected
                        ? true
                        : someSelected
                            ? null
                            : false),
                tristate: true,
                borderColor: Colors.white,
                activeColor: Colors.white,
                checkColor: AppTheme.sidebarLight,
                onChanged: rows.isEmpty
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedIds.addAll(rows.map((row) => row.id));
                          } else {
                            _selectedIds.removeAll(rows.map((row) => row.id));
                          }
                        });
                      },
              ),
            );
          }

          return _buildStickyHeaderCell(
            width: widths[index],
            label: _columnLabelForKey(key, mode),
            sortKey: _sortKeyForColumn(key),
            alignment: _columnAlignment(key),
            textAlign: _columnTextAlign(key),
          );
        }),
      ),
    );
  }

  Widget _buildStickyHeaderCell({
    required double width,
    required String label,
    required Alignment alignment,
    required TextAlign textAlign,
    String? sortKey,
  }) {
    final isSortable = sortKey != null;
    final isSorted = isSortable && _sortColumnKey == sortKey;
    final arrowIcon = _sortAscending
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return SizedBox(
      width: width,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !isSortable ? null : () => _toggleSort(sortKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: label,
                    child: Align(
                      alignment: alignment,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: _tableHeadingStyle,
                              textAlign: textAlign,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                          if (isSortable && isSorted) ...[
                            const SizedBox(width: 4),
                            Icon(
                              arrowIcon,
                              size: 13,
                              color: Colors.white,
                            ),
                          ],
                        ],
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
  }

  List<DataColumn> _buildBodyColumns(
    List<double> widths,
    _ExposureTableMode mode,
  ) {
    final columnKeys = _tableColumnKeysForMode(mode);

    return List<DataColumn>.generate(columnKeys.length, (index) {
      return DataColumn(
        label: SizedBox(width: widths[index]),
      );
    });
  }

  Widget _tableCellForKey(
    ExposureRecord row,
    String key,
    double width,
  ) {
    switch (key) {
      case 'select':
        return _tableCheckbox(
          width: width,
          value: _selectedIds.contains(row.id),
          onChanged: (selected) {
            setState(() {
              if (selected == true) {
                _selectedIds.add(row.id);
              } else {
                _selectedIds.remove(row.id);
              }
            });
          },
        );
      case 'id':
        return _tableText(row.id, width);
      case 'grant_date':
        return _tableText(_formatExposureDate(row.grantDate), width);
      case 'maturity_date':
        return _tableText(_formatExposureDate(row.maturityDate), width);
      case 'exposure_maturity':
        return _tableText(_exposureMaturityLabel(row), width);
      case 'residual_maturity':
        return _tableText(_residualMaturityLabel(row), width);
      case 'counterparty':
        return _tableText(row.counterparty.name, width);
      case 'counterparty_rating':
        return _tableText(row.counterparty.rating, width);
      case 'country':
        return _tableText(row.counterparty.country, width);
      case 'country_rating':
        return _tableText(row.counterparty.countryRating, width);
      case 'country_rw':
        return _tableText(
            _formatRiskWeight(_countryRiskWeightValue(row)), width);
      case 'geo':
        return _tableText(_compactGeoValue(row), width);
      case 'source_currency':
        return _tableText(row.currency, width);
      case 'category':
        return _tableText(row.categoryLabel, width);
      case 'rating':
        return _tableText(row.ratingLabel.tr(context), width);
      case 'gross':
        return _tableAmountText(
          _convertRowAmount(row.grossAmount, row.currency),
          currencyCode: _displayCurrency,
          width: width,
        );
      case 'crm_exists':
        return _tableText(_crmExistsLabel(row), width);
      case 'crm_type':
        return _tableText(_crmTypeTableValue(row), width);
      case 'ead_bilan':
      case 'ead_total':
        return _tableAmountText(
          _convertRowAmount(row.ead, row.currency),
          currencyCode: _displayCurrency,
          width: width,
        );
      case 'rw':
        final rwPercent = _rwPercentValue(row);
        return _tableText(
          '${rwPercent.toStringAsFixed(1)}%',
          width,
          alignment: Alignment.centerLeft,
          textAlign: TextAlign.left,
          style: _tableCellStyle.copyWith(
            color: _rwGaugeColor(rwPercent),
            fontWeight: FontWeight.w800,
          ),
        );
      case 'rwa':
        return _tableAmountText(
          _convertRowAmount(row.rwa, row.currency),
          currencyCode: _displayCurrency,
          width: width,
        );
      case 'capital':
        return _tableAmountText(
          _convertRowAmount(row.capital, row.currency),
          currencyCode: _displayCurrency,
          width: width,
        );
      case 'crm':
        return _tableText(
            _compactCrmValue(row.crmModeLabel.tr(context)), width);
      default:
        return _tableText('', width);
    }
  }

  List<DataRow> _buildDataRows(
    List<ExposureRecord> rows,
    List<double> widths,
    _ExposureTableMode mode,
  ) {
    final columnKeys = _tableColumnKeysForMode(mode);
    return rows.map((row) {
      final isSelected = _selectedIds.contains(row.id);
      final rwPercent = _rwPercentValue(row);
      return DataRow(
        selected: isSelected,
        color: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected) || isSelected;
          return _rwRowTint(rwPercent, isSelected: selected);
        }),
        cells: List<DataCell>.generate(columnKeys.length, (index) {
          final key = columnKeys[index];
          return DataCell(
            key == 'select'
                ? _tableCellForKey(row, key, widths[index])
                : InkWell(
                    onDoubleTap: () => _openEditPanel(row),
                    child: _tableCellForKey(row, key, widths[index]),
                  ),
          );
        }),
      );
    }).toList();
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumnKey != column) {
        _sortColumnKey = column;
        _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumnKey = null;
        _sortAscending = true;
      }
    });
  }

  Widget _buildControlsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101C32) : const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7ECF5),
        ),
      ),
      child: Theme(
        data: _compactControlsTheme(theme),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._columnFilterFields,
            const SizedBox(width: 12),
            SizedBox(
              height: _resetButtonSize,
              width: _resetButtonSize,
              child: Tooltip(
                message: 'Réinitialiser',
                child: ElevatedButton(
                  onPressed: _resetFilters,
                  style: ElevatedButton.styleFrom(
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(
                      isDark ? 0.34 : 0.16,
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFFFF9A1F)
                        : const Color(0xFFFF8A00),
                    foregroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    minimumSize: const Size(
                      _resetButtonSize,
                      _resetButtonSize,
                    ),
                    padding: EdgeInsets.zero,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFFFFB14D)
                          : const Color(0xFFFF8A00),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  child: const Icon(
                    Icons.restart_alt_rounded,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHelperHint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        key: _tableHelperTooltipKey,
        triggerMode: TooltipTriggerMode.longPress,
        waitDuration: const Duration(milliseconds: 180),
        showDuration: const Duration(seconds: 6),
        preferBelow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2742) : const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isDark ? const Color(0xFF446A99) : const Color(0xFFC8D8F2),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x33040A16) : const Color(0x140F172A),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        richMessage: WidgetSpan(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHelperTooltipLine(
                  text: 'Double cliquez pour modifier une exposition.',
                  bulletColor: const Color(0xFF4C7BF3),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildHelperTooltipLine(
                  text: "Cliquez sur l'entête d'une colonne pour trier.",
                  bulletColor: const Color(0xFF7C5CFC),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildHelperTooltipLine(
                  text:
                      'Ajoutez une nouvelle exposition via le bouton flottant bleu.',
                  bulletColor: const Color(0xFF20B26B),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildHelperTooltipLine(
                  text:
                      'Pour supprimer une ou plusieurs lignes, cochez les cases concernées puis supprimez-les.',
                  bulletColor: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () =>
              _tableHelperTooltipKey.currentState?.ensureTooltipVisible(),
          child: Container(
            height: 16,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF173055).withOpacity(0.92)
                  : const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF3B5E92) : const Color(0xFFBDD1F2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 10,
                  color: isDark
                      ? const Color(0xFFF5F8FF)
                      : const Color(0xFF31588F),
                ),
                const SizedBox(width: 3),
                Text(
                  'Aide',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFF5F8FF)
                        : const Color(0xFF31588F),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelperTooltipLine({
    required String text,
    required Color bulletColor,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: bulletColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? const Color(0xFFF2F6FF) : const Color(0xFF31415F),
              fontSize: 10.1,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  ThemeData _compactControlsTheme(
    ThemeData baseTheme, {
    double minHeight = _filterControlHeight,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    double labelFontSize = 8.8,
    double floatingLabelFontSize = 8.8,
    double hintFontSize = 9.8,
  }) {
    final isDark = baseTheme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF22304B) : const Color(0xFFDCE5F1);
    final fillColor = isDark ? const Color(0xFF14233D) : Colors.white;
    final labelColor =
        isDark ? const Color(0xFF9FB3D4) : const Color(0xFF637792);
    final hintColor =
        isDark ? const Color(0xFF8EA1BF) : const Color(0xFF7B8AA3);

    return baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        isDense: true,
        filled: true,
        fillColor: fillColor,
        constraints: BoxConstraints(
          minHeight: minHeight,
          maxHeight: minHeight,
        ),
        contentPadding: contentPadding,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: baseTheme.textTheme.labelMedium?.copyWith(
          color: labelColor,
          fontWeight: FontWeight.w700,
          fontSize: labelFontSize,
        ),
        floatingLabelStyle: baseTheme.textTheme.labelMedium?.copyWith(
          color: AppTheme.accent,
          fontWeight: FontWeight.w800,
          fontSize: floatingLabelFontSize,
        ),
        hintStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: hintColor,
          fontSize: hintFontSize,
          fontWeight: FontWeight.w600,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildCompactDropdownField({
    required String value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      menuMaxHeight: 320,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 9.8,
          ),
      decoration: InputDecoration(
        labelText: label.tr(context),
      ),
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 9.8,
                    ),
              ),
            ),
          )
          .toList(),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 9.8,
                    ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    double? width,
    double height = _textFilterControlHeight,
  }) {
    return Theme(
      data: _compactControlsTheme(
        Theme.of(context),
        minHeight: height,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelFontSize: 8.8,
        floatingLabelFontSize: 8.8,
        hintFontSize: 9.8,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          maxLines: 1,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 9.8,
              ),
          decoration: InputDecoration(
            labelText: label.tr(context),
            hintText: hint.tr(context),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveField({
    required int flex,
    required Widget child,
  }) {
    return Expanded(flex: flex, child: child);
  }

  List<Widget> get _columnFilterFields {
    final children = <Widget>[
      _buildResponsiveField(
        flex: 15,
        child: _buildCompactTextField(
          controller: _counterpartyFilterController,
          label: 'Contrepartie',
          hint: 'Nom ou raison sociale',
          height: _textFilterControlHeight,
        ),
      ),
      _buildResponsiveField(
        flex: 12,
        child: _buildCompactTextField(
          controller: _countryFilterController,
          label: 'Pays',
          hint: 'Pays de résidence',
          height: _textFilterControlHeight,
        ),
      ),
      _buildResponsiveField(
        flex: 15,
        child: SizedBox(
          height: _filterControlHeight,
          child: _buildCompactDropdownField(
            value: _categoryFilter,
            label: 'Catégorie',
            items: [
              'Toutes',
              ...exposureCategories.map((item) => item.prudentialLabel),
            ],
            onChanged: (value) =>
                setState(() => _categoryFilter = value ?? 'Toutes'),
          ),
        ),
      ),
      _buildResponsiveField(
        flex: 14,
        child: SizedBox(
          height: _filterControlHeight,
          child: _buildCompactDropdownField(
            value: _zoneFilter,
            label: 'Zone',
            items: const ['Toutes', 'UEMOA', 'CEMAC', 'Hors zone'],
            onChanged: (value) =>
                setState(() => _zoneFilter = value ?? 'Toutes'),
          ),
        ),
      ),
      _buildResponsiveField(
        flex: 14,
        child: SizedBox(
          height: _filterControlHeight,
          child: _buildCompactDropdownField(
            value: _ratingFilter,
            label: 'Notation',
            items: ['Toutes', ..._ratings],
            onChanged: (value) =>
                setState(() => _ratingFilter = value ?? 'Toutes'),
          ),
        ),
      ),
      _buildResponsiveField(
        flex: 14,
        child: SizedBox(
          height: _filterControlHeight,
          child: _buildCompactDropdownField(
            value: _crmFilter,
            label: 'Type CRM',
            items: const [
              'Toutes',
              'Aucune',
              'CRM financee',
              'CRM non financee',
            ],
            onChanged: (value) =>
                setState(() => _crmFilter = value ?? 'Toutes'),
          ),
        ),
      ),
    ];

    return [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(width: _controlGap),
        children[index],
      ],
    ];
  }

  void _resetFilters() {
    setState(() {
      _idFilterController.clear();
      _counterpartyFilterController.clear();
      _countryFilterController.clear();
      _categoryFilter = 'Toutes';
      _zoneFilter = 'Toutes';
      _ratingFilter = 'Toutes';
      _crmFilter = 'Toutes';
    });
  }

  List<ExposureRecord> _buildVisibleRows() {
    final idFilter = _idFilterController.text.trim().toLowerCase();
    final counterpartyFilter =
        _counterpartyFilterController.text.trim().toLowerCase();
    final countryFilter = _countryFilterController.text.trim().toLowerCase();

    final rows = _allRows.where((row) {
      final matchesId =
          idFilter.isEmpty || row.id.toLowerCase().contains(idFilter);
      final matchesCounterparty = counterpartyFilter.isEmpty ||
          row.counterparty.name.toLowerCase().contains(counterpartyFilter);
      final matchesCountry = countryFilter.isEmpty ||
          row.counterparty.country.toLowerCase().contains(countryFilter);
      final matchesCategory =
          _categoryFilter == 'Toutes' || row.categoryLabel == _categoryFilter;
      final matchesZone = _zoneFilter == 'Toutes' || row.zone == _zoneFilter;
      final matchesRating =
          _ratingFilter == 'Toutes' || row.ratingLabel == _ratingFilter;
      final matchesCrm =
          _crmFilter == 'Toutes' || row.crmModeLabel == _crmFilter;

      return matchesId &&
          matchesCounterparty &&
          matchesCountry &&
          matchesCategory &&
          matchesZone &&
          matchesRating &&
          matchesCrm;
    }).toList();

    if (_sortColumnKey != null) {
      rows.sort((left, right) {
        final comparison = switch (_sortColumnKey) {
          'id' => _compareExposureIds(left.id, right.id),
          'grant_date' =>
            _compareNullableDates(left.grantDate, right.grantDate),
          'maturity_date' =>
            _compareNullableDates(left.maturityDate, right.maturityDate),
          'exposure_maturity' => _durationInMonths(
              left.grantDate,
              left.maturityDate,
            ).compareTo(
              _durationInMonths(right.grantDate, right.maturityDate),
            ),
          'residual_maturity' => _durationInMonths(
              left.analysisDate,
              left.maturityDate,
            ).compareTo(
              _durationInMonths(right.analysisDate, right.maturityDate),
            ),
          'counterparty' =>
            left.counterparty.name.compareTo(right.counterparty.name),
          'counterparty_rating' => _compareRatings(
              left.counterparty.rating, right.counterparty.rating),
          'country' =>
            left.counterparty.country.compareTo(right.counterparty.country),
          'country_rating' => _compareRatings(left.counterparty.countryRating,
              right.counterparty.countryRating),
          'country_rw' => _countryRiskWeightValue(left)
              .compareTo(_countryRiskWeightValue(right)),
          'source_currency' => left.currency.compareTo(right.currency),
          'category' => left.categoryLabel.compareTo(right.categoryLabel),
          'rating' => _compareRatings(left.ratingLabel, right.ratingLabel),
          'crm_exists' =>
            _crmExistsLabel(left).compareTo(_crmExistsLabel(right)),
          'crm_type' =>
            _crmTypeTableValue(left).compareTo(_crmTypeTableValue(right)),
          'ead_bilan' => _convertRowAmount(left.ead, left.currency)
              .compareTo(_convertRowAmount(right.ead, right.currency)),
          'ead_total' => _convertRowAmount(left.ead, left.currency)
              .compareTo(_convertRowAmount(right.ead, right.currency)),
          'rw' => left.finalRw.compareTo(right.finalRw),
          'rwa' => _convertRowAmount(left.rwa, left.currency)
              .compareTo(_convertRowAmount(right.rwa, right.currency)),
          'capital' => _convertRowAmount(left.capital, left.currency)
              .compareTo(_convertRowAmount(right.capital, right.currency)),
          'crm' => left.crmModeLabel.compareTo(right.crmModeLabel),
          _ => _convertRowAmount(left.grossAmount, left.currency)
              .compareTo(_convertRowAmount(right.grossAmount, right.currency)),
        };
        return _sortAscending ? comparison : -comparison;
      });
    }

    return rows;
  }

  ExposureSummary _summarize(List<ExposureRecord> rows) {
    return ExposureSummary(
      totalExpositions: rows.fold<double>(
          0,
          (sum, item) =>
              sum + _convertRowAmount(item.grossAmount, item.currency)),
      totalEad: rows.fold<double>(
          0, (sum, item) => sum + _convertRowAmount(item.ead, item.currency)),
      totalRwa: rows.fold<double>(
          0, (sum, item) => sum + _convertRowAmount(item.rwa, item.currency)),
      totalCapital: rows.fold<double>(0,
          (sum, item) => sum + _convertRowAmount(item.capital, item.currency)),
    );
  }

  double _convertAmountForDisplay(double amount, String sourceCurrency) {
    return convertAmount(
      amount,
      fromCurrency: sourceCurrency,
      toCurrency: _displayCurrency,
    );
  }

  String get _displayCurrencyLabel {
    switch (_displayCurrency.toUpperCase()) {
      case 'XOF':
      case 'XAF':
        return 'FCFA';
      default:
        return _displayCurrency.toUpperCase();
    }
  }

  double _convertRowAmount(double amount, String sourceCurrency) {
    return _convertAmountForDisplay(amount, sourceCurrency);
  }

  Future<void> _refresh() async {
    final moduleFuture = widget.api.fetchExpositionsModule();
    final referentielsFuture = _hasLoadedReferentiels
        ? Future<ReferentielsModuleData?>.value(null)
        : widget.api.fetchReferentiels().then<ReferentielsModuleData?>(
              (value) => value,
              onError: (_) => null,
            );

    final module = await moduleFuture;
    final referentiels = await referentielsFuture;

    if (!mounted) {
      return;
    }

    setState(() {
      _allRows = module.exposures;
      if (referentiels != null) {
        _ratings = _sortRatings(
            referentiels.ratings.map((item) => item.label).toList());
        _hasLoadedReferentiels = true;
      }
      if (_ratings.isEmpty) {
        _ratings = _sortRatings(prudentialRatings);
      }
      _selectedIds = _selectedIds
          .where((id) => _allRows.any((row) => row.id == id))
          .toSet();
    });
  }

  void _upsertLocalExposure(ExposureRecord record) {
    final nextRows = _allRows.toList(growable: true);
    final index = nextRows.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      nextRows[index] = record;
    } else {
      nextRows.add(record);
    }

    setState(() {
      _allRows = nextRows;
      _selectedIds = _selectedIds
          .where((id) => _allRows.any((row) => row.id == id))
          .toSet();
    });
  }

  Future<void> _openCreatePanel() async {
    final nextExposureId = await widget.api.fetchNextExposureId();
    final draft = ExposureDraft(
      id: nextExposureId,
      counterpartyName: 'Nouvelle contrepartie',
      country: 'Cote d\'Ivoire',
      countryRating: 'Non noté',
      categoryCode: 'e',
      rating: _ratings.contains('BBB') ? 'BBB' : _ratings.first,
      grossAmount: 1000000,
      loanTotalAmount: 1000000,
      onBalanceExposureAmount: 1000000,
      currency: _displayCurrency,
      status: 'Active',
      crmMode: 'Aucune',
      crmType: 'Garantie etatique',
      collateralValue: 0,
      issuerType: financedCrmIssuerTypes.first,
      issuerRating: _ratings.contains('AAA') ? 'AAA' : _ratings.first,
      maturityBucket: financedCrmMaturityBuckets.first,
      fxHaircut: 0,
      guarantorName: '',
      guarantorCategoryCode: 'a',
      guarantorRating: _ratings.contains('AAA') ? 'AAA' : _ratings.first,
      guarantorCountry: '',
      guarantorCountryRating: 'Non noté',
      crmCoveragePercent: 0,
      comment: '',
      analysisDate: DateTime.now(),
      sovereignSpecialCase: sovereignNoSpecialCase,
      sovereignPreferentialZeroWeight: false,
      sovereignOceEstablished: false,
      sovereignOceNote: '',
      publicBodyUemoaFcfaCase: null,
      publicBodyFinancesNonPublicActivity: null,
      bmdHighQualityCase: null,
      bmdUemoaFcfaCase: null,
      bmdUemoaCriteriaSatisfied: null,
      bmdListedInstitutionFcfaCase: null,
      bankInstitutionCase: null,
      otherAssetType: null,
      offBalanceRiskLevel: null,
      retailEligibilityCriteriaSatisfied: null,
      residentialMortgageEligible: null,
      commercialRealEstateEligible: null,
      defaultedExposureInitialRiskWeight: null,
      defaultedExposureResidentialMortgageInDefault: null,
      defaultedExposureProvisionAtLeastTwentyPercent: null,
      enterpriseExceedsBceaoDegradationThreshold: null,
      enterprisePrudentialProcedure: null,
      enterpriseInvestmentFirmWithoutBankingLaw: null,
    );
    await _showEditorPage(draft, isCreateMode: true);
  }

  Future<void> _openEditPanel(ExposureRecord row) async {
    await _showEditorPage(row.toDraft(), isCreateMode: false);
  }

  Future<void> _saveDraft(
    ExposureDraft draft, {
    required bool isCreateMode,
  }) async {
    final savedRecord = isCreateMode
        ? await widget.api.createExposure(draft)
        : await widget.api.updateExposure(draft);
    if (!mounted) {
      return;
    }

    _upsertLocalExposure(savedRecord);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCreateMode
              ? context.tr('Exposition ajoutee.')
              : context.tr('Exposition mise a jour.'),
        ),
      ),
    );
  }

  Future<void> _showEditorPage(
    ExposureDraft draft, {
    required bool isCreateMode,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          return Scaffold(
            backgroundColor: Colors.black.withOpacity(0.22),
            body: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: MediaQuery.of(routeContext).size.width > 1320
                      ? 560
                      : MediaQuery.of(routeContext).size.width,
                  height: double.infinity,
                  child: Material(
                    elevation: 16,
                    child: ExposureFormCard(
                      initialDraft: draft,
                      ratings: _ratings,
                      title: isCreateMode
                          ? 'Ajouter une exposition'
                          : 'Modifier l exposition',
                      submitLabel: isCreateMode ? 'Ajouter' : 'Mettre a jour',
                      onCancel: () => Navigator.of(routeContext).pop(),
                      onSubmit: (submittedDraft) async {
                        await _saveDraft(
                          submittedDraft,
                          isCreateMode: isCreateMode,
                        );
                        if (mounted && routeContext.mounted) {
                          Navigator.of(routeContext).pop();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteSelection() async {
    if (_isDeleting || _isImporting) {
      return;
    }

    final ids = _selectedIds.toList()..sort(_compareExposureIds);
    if (ids.isEmpty) {
      return;
    }

    final decision = await _confirmDeleteSelection(ids);
    if (!decision.confirmed) {
      return;
    }

    try {
      if (mounted) {
        setState(() => _isDeleting = true);
      }
      final result = await widget.api.deleteExposures(
        ids,
        reindexIds: decision.reindexIds,
      );
      final deletedIds =
          List<String>.from(result['deleted_ids'] as List? ?? const []);
      final missingIds =
          List<String>.from(result['missing_ids'] as List? ?? const []);
      final reindexedIds = result['reindexed_ids'] == true;

      if (mounted) {
        setState(() {
          _selectedIds = <String>{};
        });
      }
      await _queueRefresh();
      if (mounted) {
        final message = _buildDeleteResultMessage(
          deletedIds: deletedIds,
          missingIds: missingIds,
          reindexedIds: reindexedIds,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _buildDeleteErrorMessage(
                error,
                reindexIds: decision.reindexIds,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<_DeleteSelectionDecision> _confirmDeleteSelection(
    List<String> ids,
  ) async {
    if (!mounted) {
      return const _DeleteSelectionDecision(
        confirmed: false,
        reindexIds: false,
      );
    }

    final previewIds = ids.take(6).join(', ');
    final remainingCount = ids.length - 6;
    var reindexIds = false;

    final decision = await showDialog<_DeleteSelectionDecision>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Confirmer la suppression')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ids.length == 1
                        ? context.tr(
                            'Cette action supprimera l exposition selectionnee dans le tableau et dans la base locale.',
                          )
                        : context.tr(
                            'Cette action supprimera les expositions selectionnees dans le tableau et dans la base locale.',
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    remainingCount > 0
                        ? '$previewIds, et $remainingCount autre(s).'
                        : previewIds,
                    style:
                        Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: reindexIds,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      context.tr('Mettre a jour les IDs apres suppression'),
                    ),
                    subtitle: Text(
                      context.tr(
                        'Exemple: si CP003 est supprime, CP004 devient CP003.',
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        reindexIds = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    const _DeleteSelectionDecision(
                      confirmed: false,
                      reindexIds: false,
                    ),
                  ),
                  child: Text(context.tr('Annuler')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _DeleteSelectionDecision(
                      confirmed: true,
                      reindexIds: reindexIds,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.tr('Supprimer')),
                ),
              ],
            );
          },
        );
      },
    );

    return decision ??
        const _DeleteSelectionDecision(
          confirmed: false,
          reindexIds: false,
        );
  }

  String _buildDeleteResultMessage({
    required List<String> deletedIds,
    required List<String> missingIds,
    required bool reindexedIds,
  }) {
    if (deletedIds.isNotEmpty && missingIds.isEmpty) {
      if (reindexedIds) {
        return context.tr(
          '{{count}} exposition(s) supprimee(s). Les IDs ont ete renumerotes automatiquement.',
          args: {'count': deletedIds.length},
        );
      }
      return context.tr(
        '{{count}} exposition(s) supprimee(s) du tableau et de la base locale.',
        args: {'count': deletedIds.length},
      );
    }
    if (deletedIds.isNotEmpty && missingIds.isNotEmpty) {
      final prefix = reindexedIds
          ? context.tr(
              '{{deleted}} exposition(s) supprimee(s) et IDs renumerotes.',
              args: {'deleted': deletedIds.length},
            )
          : context.tr(
              '{{deleted}} exposition(s) supprimee(s).',
              args: {'deleted': deletedIds.length},
            );
      return context.tr(
        '{{prefix}} {{missing}} introuvable(s): {{ids}}.',
        args: {
          'prefix': prefix,
          'missing': missingIds.length,
          'ids': missingIds.join(', '),
        },
      );
    }
    if (missingIds.isNotEmpty) {
      return context.tr(
        'Aucune suppression effectuee. IDs introuvables: {{ids}}.',
        args: {'ids': missingIds.join(', ')},
      );
    }
    return context.tr('Aucune exposition supprimee.');
  }

  String _buildDeleteErrorMessage(
    Object error, {
    required bool reindexIds,
  }) {
    if (reindexIds && error is ApiException && error.statusCode >= 500) {
      return context.tr(
        'Suppression impossible pendant la mise a jour des IDs. Redemarrez le backend Python puis reessayez.',
      );
    }
    return context.tr(
      'Suppression impossible: {{error}}',
      args: {'error': error},
    );
  }

  Future<void> _exportView(List<ExposureRecord> rows) async {
    final format = await _showExportFormatDialog();
    if (!mounted || format == null) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      switch (format) {
        case _ExposureExportFormat.excel:
          await _exportExcelWorkbook();
          break;
        case _ExposureExportFormat.pdf:
          await _exportVisibleTablePdf(rows);
          break;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(
            context.tr(
              'Export impossible: {{error}}',
              args: {'error': error},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<_ExposureExportFormat?> _showExportFormatDialog() {
    Widget buildOption({
      required BuildContext dialogContext,
      required _ExposureExportFormat format,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color accent,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(dialogContext).pop(format),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(dialogContext).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return showDialog<_ExposureExportFormat>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('Choisir le format d export')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildOption(
                  dialogContext: dialogContext,
                  format: _ExposureExportFormat.excel,
                  icon: Icons.table_chart_rounded,
                  title: context.tr('Exporter en Excel'),
                  subtitle: context.tr(
                    'Classeur complet base sur le modele RWA.',
                  ),
                  accent: const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 10),
                buildOption(
                  dialogContext: dialogContext,
                  format: _ExposureExportFormat.pdf,
                  icon: Icons.picture_as_pdf_rounded,
                  title: context.tr('Exporter en PDF'),
                  subtitle: context.tr(
                    'Tableau visible uniquement, au format paysage.',
                  ),
                  accent: const Color(0xFFB45309),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('Fermer')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportExcelWorkbook() async {
    final bytes = await widget.api.downloadExposureExcelExport();
    final location = await getSaveLocation(
      suggestedName: 'export_expositions_rwa_${_exportTimestamp()}.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (!mounted || location == null) {
      return;
    }

    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(context.tr('Export Excel enregistre avec succes.')),
      ),
    );
  }

  Future<void> _exportVisibleTablePdf(List<ExposureRecord> rows) async {
    final pdfBytes = await _buildVisibleTablePdf(rows);
    final location = await getSaveLocation(
      suggestedName: 'export_expositions_rwa_${_exportTimestamp()}.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (!mounted || location == null) {
      return;
    }

    final file = File(location.path);
    await file.writeAsBytes(pdfBytes, flush: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(context.tr('Export PDF enregistre avec succes.')),
      ),
    );
  }

  Future<Uint8List> _buildVisibleTablePdf(List<ExposureRecord> rows) async {
    final document = pw.Document();
    const pdfColumnKeys = <String>[
      'id',
      'grant_date',
      'maturity_date',
      'exposure_maturity',
      'residual_maturity',
      'counterparty',
      'counterparty_rating',
      'country',
      'country_rating',
      'country_rw',
      'category',
      'rw',
      'gross',
      'source_currency',
      'crm_exists',
      'crm_type',
      'ead_bilan',
      'ead_total',
      'rwa',
      'capital',
    ];
    final headers = pdfColumnKeys
        .map((key) => _columnLabelForKey(key, _ExposureTableMode.full))
        .toList(growable: false);
    final pdfColumnWeights = pdfColumnKeys
        .map((key) => _mainTableWidthWeights[_fullTableColumnKeys.indexOf(key)])
        .toList(growable: false);
    final columnWidths = <int, pw.TableColumnWidth>{
      for (var index = 0; index < pdfColumnWeights.length; index++)
        index: pw.FlexColumnWidth(pdfColumnWeights[index]),
    };

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(14),
        build: (_) => [
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.6,
              ),
              verticalInside: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.6,
              ),
              top: pw.BorderSide(
                color: PdfColor.fromInt(0xFF24467A),
                width: 0.8,
              ),
              bottom: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.8,
              ),
              left: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.8,
              ),
              right: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            columnWidths: columnWidths,
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF24467A),
                ),
                children: headers
                    .map(
                      (header) => _pdfTableCell(
                        header,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8.1,
                      ),
                    )
                    .toList(),
              ),
              for (final row in rows)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: _pdfRowColor(_rwPercentValue(row)),
                  ),
                  children: pdfColumnKeys
                      .map((key) => _pdfCellForColumn(row, key))
                      .toList(growable: false),
                ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfTableCell(
    String text, {
    PdfColor? color,
    pw.FontWeight? fontWeight,
    double fontSize = 8.4,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        maxLines: 2,
        style: pw.TextStyle(
          color: color ?? PdfColor.fromInt(0xFF1F2A44),
          fontSize: fontSize,
          fontWeight: fontWeight ?? pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfCellForColumn(ExposureRecord row, String key) {
    switch (key) {
      case 'id':
        return _pdfTableCell(row.id);
      case 'grant_date':
        return _pdfTableCell(_formatExposureDate(row.grantDate));
      case 'maturity_date':
        return _pdfTableCell(_formatExposureDate(row.maturityDate));
      case 'exposure_maturity':
        return _pdfTableCell(_exposureMaturityLabel(row));
      case 'residual_maturity':
        return _pdfTableCell(_residualMaturityLabel(row));
      case 'counterparty':
        return _pdfTableCell(row.counterparty.name);
      case 'counterparty_rating':
        return _pdfTableCell(row.counterparty.rating);
      case 'country':
        return _pdfTableCell(row.counterparty.country);
      case 'country_rating':
        return _pdfTableCell(row.counterparty.countryRating);
      case 'country_rw':
        return _pdfTableCell(_formatRiskWeight(_countryRiskWeightValue(row)));
      case 'category':
        return _pdfTableCell(row.categoryLabel);
      case 'rw':
        return _pdfTableCell(
          _formatRiskWeight(row.finalRw),
          color: _pdfRwColor(_rwPercentValue(row)),
          fontWeight: pw.FontWeight.bold,
        );
      case 'gross':
        return _pdfTableCell(
          AppFormatters.compactNumber(
            _convertRowAmount(row.grossAmount, row.currency),
          ),
        );
      case 'source_currency':
        return _pdfTableCell(row.currency);
      case 'crm_exists':
        return _pdfTableCell(_crmExistsLabel(row));
      case 'crm_type':
        return _pdfTableCell(_crmTypeTableValue(row));
      case 'ead_bilan':
      case 'ead_total':
        return _pdfTableCell(
          AppFormatters.compactNumber(
            _convertRowAmount(row.ead, row.currency),
          ),
        );
      case 'rwa':
        return _pdfTableCell(
          AppFormatters.compactNumber(
            _convertRowAmount(row.rwa, row.currency),
          ),
        );
      case 'capital':
        return _pdfTableCell(
          AppFormatters.compactNumber(
            _convertRowAmount(row.capital, row.currency),
          ),
        );
      default:
        return _pdfTableCell('');
    }
  }

  PdfColor _pdfRowColor(double rwPercent) {
    if (rwPercent <= 50) {
      return PdfColor.fromInt(0xFFF2FAF5);
    }
    if (rwPercent <= 100) {
      return PdfColor.fromInt(0xFFFFF7EA);
    }
    return PdfColor.fromInt(0xFFFFF1F1);
  }

  PdfColor _pdfRwColor(double rwPercent) {
    if (rwPercent <= 50) {
      return PdfColor.fromInt(0xFF18A957);
    }
    if (rwPercent <= 100) {
      return PdfColor.fromInt(0xFFD68A00);
    }
    return PdfColor.fromInt(0xFFE04F5F);
  }

  String _exportTimestamp() {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final now = DateTime.now();
    return '${now.year}${twoDigits(now.month)}${twoDigits(now.day)}_'
        '${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}';
  }

  Future<void> _showImportDialog() async {
    Map<String, dynamic>? successfulImportResult;
    setState(() => _isImporting = true);
    try {
      successfulImportResult = await showExcelImportDialog(
        context,
        api: widget.api,
        onImportApplied: _queueRefresh,
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
    if (!mounted || successfulImportResult == null) {
      return;
    }
    final rejectedRows =
        (successfulImportResult['rejected_rows'] as num?)?.toInt() ?? 0;
    final importedRows =
        (successfulImportResult['imported_rows'] as num?)?.toInt() ?? 0;
    final updatedRows =
        (successfulImportResult['updated_rows'] as num?)?.toInt() ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(
          rejectedRows > 0
              ? 'Import terminé. $rejectedRows ligne(s) rejetée(s), $importedRows importée(s), $updatedRows mise(s) à jour.'
              : 'Import terminé avec succès.',
        ),
      ),
    );
  }
}
