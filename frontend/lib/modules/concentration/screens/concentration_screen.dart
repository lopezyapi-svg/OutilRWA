import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';
import '../../risque_credit_shared/services/credit_risk_submodules_service.dart';
import 'package:fl_chart/fl_chart.dart';

const double _umoaCet1Minimum = 0.05;
const double _umoaTier1Minimum = 0.06;
const double _umoaSolvencyMinimum = 0.09;
const double _umoaConservationBuffer = 0.025;
const int _counterpartyTopCount = 10;
const int _issuerResidenceCountryTopCount = 10;
const int _concentrationViewModelVersion = 5;
const double _concentrationRadius = 2;
const double _excelLargeExposureTableWidth = 1750;
const List<String> _counterpartyRatingOrder = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'B+',
  'B',
  'B-',
  '< B-',
  'Non noté',
];

class ConcentrationScreen extends StatefulWidget {
  const ConcentrationScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<ConcentrationScreen> createState() => _ConcentrationScreenState();
}

class _ConcentrationScreenState extends State<ConcentrationScreen> {
  late final CreditRiskSubmodulesService _service;
  late Future<ConcentrationModuleData> _future;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _contentScrollController = ScrollController();
  final Map<String, _ConcentrationViewModel> _viewCache = {};
  StreamSubscription<int>? _portfolioSubscription;

  final String _selectedPeriod = '12M';
  final String _selectedCountry = 'Tous';
  final String _selectedRegion = 'Tous';
  final String _selectedSector = 'Tous';
  final String _selectedSegment = 'Tous';
  final String _selectedRating = 'Tous';
  final String _selectedStatus = 'Tous';
  final String _selectedDefault = 'Tous';
  final String _selectedGuarantee = 'Tous';
  int _selectedPortfolioTab = 0;

  @override
  void initState() {
    super.initState();
    _service = CreditRiskSubmodulesService(widget.api);
    _future = _service.fetchConcentrationModule();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      _refresh();
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
    _contentScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConcentrationModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final view = _viewFor(data);

        return Column(
          children: [
            _buildFixedTopBar(context),
            Expanded(
              child: Scrollbar(
                controller: _contentScrollController,
                child: SingleChildScrollView(
                  controller: _contentScrollController,
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _selectedPortfolioTab == 0
                        ? [
                            _buildCounterpartyAndGeographyRow(view),
                            const SizedBox(height: AppTheme.pageGap),
                            _buildNplSection(view),
                          ]
                        : [
                            Padding(
                              padding: const EdgeInsets.only(top: 150),
                              child: Center(
                                child: Text(
                                  'Appétence aux risques de la banque',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppTheme.text,
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
          ],
        );
      },
    );
  }

  void _selectPortfolioTab(int index) {
    if (_selectedPortfolioTab == index) {
      return;
    }
    setState(() => _selectedPortfolioTab = index);
    if (_contentScrollController.hasClients) {
      _contentScrollController.jumpTo(0);
    }
  }

  Widget _buildFixedTopBar(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 2,
        shadowColor: const Color(0x1A0F172A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portefeuille',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lecture des expositions, concentrations et signaux de vigilance.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                  ),
                ],
              ),
            ),
            _PortfolioTabNavigation(
              selectedIndex: _selectedPortfolioTab,
              onChanged: _selectPortfolioTab,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNplSection(_ConcentrationViewModel view) {
    final defaultExposures =
        view.exposureDetails.where((e) => e.isDefault).toList();
    final encoursNpl =
        defaultExposures.fold<double>(0.0, (sum, e) => sum + e.grossAmount);
    final countNpl = defaultExposures.length;
    final totalGross = view.totalGross;
    final nplRatio = totalGross > 0 ? (encoursNpl / totalGross) : 0.0;

    final provisions = defaultExposures.fold<double>(
        0.0, (sum, e) => sum + e.estimatedProvision);
    final coverageRatio = encoursNpl > 0 ? (provisions / encoursNpl) : 0.0;
    final provisionsTotalRatio =
        totalGross > 0 ? (provisions / totalGross) : 0.0;
    final nplNet = encoursNpl - provisions;

    Widget buildBaseCard(
        {required Widget child,
        EdgeInsetsGeometry? padding,
        Color? backgroundColor}) {
      return Container(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: backgroundColor ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
    }

    // --- Row helper for label/value pairs ---
    Widget buildRow(
        {required String label,
        String? formula,
        required String value,
        bool isLast = false}) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                    if (formula != null) ...[
                      const SizedBox(height: 2),
                      Text(formula,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppTheme.muted.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
                const SizedBox(width: 16),
                Text(value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.indigo[900],
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            ),
        ],
      );
    }

    // --- Inner sub-card ---
    Widget buildSubCard({required String title, required List<Widget> rows}) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text(title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.indigo[900],
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            ),
            ...rows,
          ],
        ),
      );
    }

    // --- Summary footer ---
    final summaryBar = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Encours NPL :  ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 12)),
                  Text('${_amountMd(encoursNpl)} ${_amountUnitLabel()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Provisions totales :  ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 12)),
                  Text('${_amountMd(provisions)} ${_amountUnitLabel()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Nombre NPL :  ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 12)),
                  Text('$countNpl',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // --- Main block1 : one big outer card (like "Tombées de Flux") ---
    final block1 = buildBaseCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header matching the reference image
          Row(
            children: [
              Text('Indicateurs NPL et Provisions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          // Sub-cards row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildSubCard(
                  title: 'Non Performing Loans',
                  rows: [
                    buildRow(
                        label: 'Ratio NPL',
                        formula: '(Encours NPL / Encours total)',
                        value: AppFormatters.percent(nplRatio)),
                    buildRow(
                        label: 'Exposition nette',
                        formula: '(Encours NPL - Provisions)',
                        value: '${_amountMd(nplNet)} ${_amountUnitLabel()}',
                        isLast: true),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: AppTheme.pageGap / 4),
                  padding: const EdgeInsets.only(left: AppTheme.pageGap / 4),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.5)),
                    ),
                  ),
                  child: buildSubCard(
                    title: 'PROVISIONS',
                    rows: [
                      buildRow(
                          label: 'Provisions totales sur NPL',
                          formula: '(Somme des provisions)',
                          value:
                              '${_amountMd(provisions)} ${_amountUnitLabel()}'),
                      buildRow(
                          label: 'Taux de couverture',
                          formula: '(Provisions / Encours NPL)',
                          value: AppFormatters.percent(coverageRatio)),
                      buildRow(
                          label: 'Provisions / Encours total',
                          formula: '(Provisions / Encours total)',
                          value: AppFormatters.percent(provisionsTotalRatio),
                          isLast: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Summary bar
          summaryBar,
        ],
      ),
    );

    final chartEntries = [
      (
        label: '1 – 30 jours',
        percent: 0.20,
        amount: encoursNpl * 0.20,
        color: const Color(0xFF4ADE80)
      ),
      (
        label: '31 – 90 jours',
        percent: 0.25,
        amount: encoursNpl * 0.25,
        color: const Color(0xFF3B82F6)
      ),
      (
        label: '91 – 180 jours',
        percent: 0.30,
        amount: encoursNpl * 0.30,
        color: const Color(0xFFFBBF24)
      ),
      (
        label: '> 180 jours',
        percent: 0.25,
        amount: encoursNpl * 0.25,
        color: const Color(0xFFEF4444)
      ),
    ];

    final subBlockB = buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suivi du nombre de jours impayés',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          Expanded(
            child: Center(
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: _AnimatedDonutChart(
                      entries: chartEntries
                          .map((e) => (e.percent, e.color))
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < chartEntries.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: chartEntries[i].color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(chartEntries[i].label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppTheme.text,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500)),
                                ),
                                Text(
                                    '${(chartEntries[i].percent * 100).toInt()} %',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: AppTheme.text,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                      '${_amountMd(chartEntries[i].amount)} ${_amountUnitLabel()}',
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppTheme.muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                          if (i < chartEntries.length - 1)
                            Divider(
                                height: 1,
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Top 5 NPL expositions
    final top5Npl = defaultExposures.toList()
      ..sort((a, b) => b.grossAmount.compareTo(a.grossAmount));
    final top5 = top5Npl.take(5).toList();

    final top5Table = Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top 5 des plus grandes expositions NPL (brut)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return AlertDialog(
                            backgroundColor:
                                isDark ? AppTheme.darkCard : AppTheme.card,
                            title: Text(
                              'Toutes les expositions NPL',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppTheme.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            content: SizedBox(
                              width: 800,
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Theme.of(context)
                                                    .dividerColor
                                                    .withValues(alpha: 0.5)))),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                            width: 24,
                                            child: Text('#',
                                                style: _tableHeaderStyle())),
                                        Expanded(
                                            flex: 3,
                                            child: Text('Contrepartie',
                                                style: _tableHeaderStyle())),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Secteur',
                                                style: _tableHeaderStyle())),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Encours brut',
                                                style: _tableHeaderStyle(),
                                                textAlign: TextAlign.right)),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Provision',
                                                style: _tableHeaderStyle(),
                                                textAlign: TextAlign.right)),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Taux couv.',
                                                style: _tableHeaderStyle(),
                                                textAlign: TextAlign.right)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      addSemanticIndexes: false,
                                      itemCount: top5Npl.length,
                                      separatorBuilder: (context, index) =>
                                          Divider(
                                              color: Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.3)),
                                      itemBuilder: (context, index) {
                                        final e = top5Npl[index];
                                        final coverageRate = e.grossAmount > 0
                                            ? (e.estimatedProvision /
                                                e.grossAmount)
                                            : 0.0;

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                  width: 24,
                                                  child: Text('${index + 1}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                              color: AppTheme
                                                                  .muted,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12))),
                                              Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                      e.counterpartyName,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                              color:
                                                                  AppTheme.text,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12),
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              Expanded(
                                                  flex: 2,
                                                  child: Text(e.sector,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                              color: AppTheme
                                                                  .muted,
                                                              fontSize: 12),
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                      '${_amountMd(e.grossAmount)} ${_amountUnitLabel()}',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                              color:
                                                                  AppTheme.text,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12))),
                                              Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                      '${_amountMd(e.estimatedProvision)} ${_amountUnitLabel()}',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                              color:
                                                                  AppTheme.text,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12))),
                                              Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                      AppFormatters.percent(
                                                          coverageRate),
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                              color:
                                                                  AppTheme.text,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12))),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Voir toutes les expositions NPL',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppTheme.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            color: AppTheme.danger, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                    width: 24, child: Text('#', style: _tableHeaderStyle())),
                Expanded(
                    flex: 3,
                    child: Text('Contrepartie', style: _tableHeaderStyle())),
                Expanded(
                    flex: 2,
                    child: Text('Secteur', style: _tableHeaderStyle())),
                Expanded(
                    flex: 2,
                    child: Text('Encours brut',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text('Date d\'échéance',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Provision',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text('Taux de couverture',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Rows
          ...top5.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final coverageRate = e.grossAmount > 0
                ? (e.estimatedProvision / e.grossAmount)
                : 0.0;
            final barWidth = (coverageRate * 60).clamp(0, 60).toDouble();

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                border: i < top5.length - 1
                    ? Border(
                        bottom: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.3)))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12))),
                  Expanded(
                      flex: 3,
                      child: Text(e.counterpartyName,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 2,
                      child: Text(e.sector,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.muted, fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 2,
                      child: Text(
                          '${_amountMd(e.grossAmount)} ${_amountUnitLabel()}',
                          textAlign: TextAlign.right,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12))),
                  Expanded(
                      flex: 2,
                      child: Text(
                          '${_amountMd(e.estimatedProvision)} ${_amountUnitLabel()}',
                          textAlign: TextAlign.right,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12))),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(AppFormatters.percent(coverageRate),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppTheme.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(
                          width: 60,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: barWidth,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.danger,
                                borderRadius: BorderRadius.circular(3),
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
          }),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 310,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 16, child: block1),
                  const SizedBox(width: AppTheme.pageGap),
                  Expanded(flex: 10, child: subBlockB),
                ],
              ),
            ),
            top5Table,
          ],
        );
      },
    );
  }

  Widget _buildCounterpartyAndGeographyRow(_ConcentrationViewModel view) {
    const minRowWidth = 980.0;
    const rowHeight = 350.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content(double width) {
          return SizedBox(
            width: width,
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTopCounterparties(view)),
                const SizedBox(width: AppTheme.pageGap),
                Expanded(child: _buildSectorAndGeography(view)),
              ],
            ),
          );
        }

        final row = constraints.maxWidth >= minRowWidth
            ? content(constraints.maxWidth)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: content(minRowWidth),
              );

        return SizedBox(
          height: rowHeight,
          child: row,
        );
      },
    );
  }

  Widget _buildSectorAndGeography(_ConcentrationViewModel view) {
    return _IssuerResidenceCountryCard(
      countryRows: view.countryDistribution
          .take(_issuerResidenceCountryTopCount)
          .toList(),
      zoneRows: view.regionDistribution,
    );
  }

  Widget _buildTopCounterparties(_ConcentrationViewModel view) {
    final visibleRows =
        view.counterpartyRows.take(_counterpartyTopCount).toList();

    return _TopCounterpartyExposureCard(
      rows: visibleRows,
      allRows: view.counterpartyRows,
    );
  }

  _ConcentrationViewModel _viewFor(ConcentrationModuleData data) {
    final key = [
      _concentrationViewModelVersion,
      identityHashCode(data),
      _searchController.text.trim().toLowerCase(),
      _selectedPeriod,
      _selectedCountry,
      _selectedRegion,
      _selectedSector,
      _selectedSegment,
      _selectedRating,
      _selectedStatus,
      _selectedDefault,
      _selectedGuarantee,
    ].join('|');

    return _viewCache.putIfAbsent(
      key,
      () => _ConcentrationViewModel.fromDetails(_filteredDetails(data)),
    );
  }

  List<ConcentrationExposureDetail> _filteredDetails(
    ConcentrationModuleData data,
  ) {
    if (data.exposureDetails.isEmpty) {
      return const <ConcentrationExposureDetail>[];
    }

    final latest = data.exposureDetails
        .map((item) => item.analysisDate)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final cutoff = _periodCutoff(_selectedPeriod, latest);
    final query = _searchController.text.trim().toLowerCase();

    return data.exposureDetails.where((item) {
      final matchesQuery = query.isEmpty ||
          item.id.toLowerCase().contains(query) ||
          item.counterpartyName.toLowerCase().contains(query) ||
          item.country.toLowerCase().contains(query) ||
          item.region.toLowerCase().contains(query) ||
          item.sector.toLowerCase().contains(query) ||
          item.rating.toLowerCase().contains(query);
      final matchesDate = !item.analysisDate.isBefore(cutoff);
      final matchesCountry =
          _selectedCountry == 'Tous' || item.country == _selectedCountry;
      final matchesRegion =
          _selectedRegion == 'Tous' || item.region == _selectedRegion;
      final matchesSector =
          _selectedSector == 'Tous' || item.sector == _selectedSector;
      final matchesSegment =
          _selectedSegment == 'Tous' || item.segment == _selectedSegment;
      final matchesRating =
          _selectedRating == 'Tous' || item.rating == _selectedRating;
      final matchesStatus =
          _selectedStatus == 'Tous' || item.status == _selectedStatus;
      final matchesDefault = _selectedDefault == 'Tous' ||
          (_selectedDefault == 'Oui' && item.isDefault) ||
          (_selectedDefault == 'Non' && !item.isDefault);
      final matchesGuarantee = _selectedGuarantee == 'Tous' ||
          (_selectedGuarantee == 'Oui' && item.hasGuarantee) ||
          (_selectedGuarantee == 'Non' && !item.hasGuarantee);

      return matchesQuery &&
          matchesDate &&
          matchesCountry &&
          matchesRegion &&
          matchesSector &&
          matchesSegment &&
          matchesRating &&
          matchesStatus &&
          matchesDefault &&
          matchesGuarantee;
    }).toList(growable: false);
  }

  DateTime _periodCutoff(String period, DateTime latest) {
    return switch (period) {
      '1M' => DateTime(latest.year, latest.month - 1, latest.day),
      '3M' => DateTime(latest.year, latest.month - 3, latest.day),
      '6M' => DateTime(latest.year, latest.month - 6, latest.day),
      'YTD' => DateTime(latest.year),
      _ => DateTime(latest.year, latest.month - 12, latest.day),
    };
  }

  void _refresh() {
    setState(() {
      _viewCache.clear();
      _future = _service.fetchConcentrationModule();
    });
  }
}

class _PortfolioTabNavigation extends StatelessWidget {
  const _PortfolioTabNavigation({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    'Analyse portefeuille crédit',
    'Alertes & décisions',
  ];

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.75);

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            for (var index = 0; index < _items.length; index++)
              _PortfolioTabButton(
                label: _items[index],
                selected: selectedIndex == index,
                onTap: () => onChanged(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioTabButton extends StatelessWidget {
  const _PortfolioTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.concentrationDeeper
        : AppColors.concentrationDeeper.withValues(alpha: 0.76);

    return SizedBox(
      width: label.startsWith('Analyse')
          ? 198
          : label.startsWith('Grands')
              ? 142
              : label.startsWith('Alertes')
                  ? 172
                  : label.startsWith('Tableau')
                      ? 172
                      : 190,
      height: double.infinity,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.concentrationDeeper.withValues(alpha: 0.06),
        highlightColor: AppColors.concentrationDeeper.withValues(alpha: 0.035),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? AppColors.concentrationDeeper
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: 12.8,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _ExcelLargeExposureAnalysis {
  const _ExcelLargeExposureAnalysis({
    required this.rows,
    required this.ownFunds,
    required this.threshold10,
    required this.threshold25,
    required this.totalAuthorization,
    required this.totalGrossRisk,
    required this.totalOnBalance,
    required this.totalOffBalance,
    required this.totalGuarantee,
    required this.totalNetRisk,
    required this.topFiveGross,
    required this.topFiveNet,
  });

  factory _ExcelLargeExposureAnalysis.from(_ConcentrationViewModel view) {
    final ownFunds = _largeExposureOwnFunds(view);
    final groups = <String, _ExcelLargeExposureAccumulator>{};

    for (final detail in view.exposureDetails) {
      groups
          .putIfAbsent(
            detail.counterpartyName,
            () => _ExcelLargeExposureAccumulator(detail.counterpartyName),
          )
          .add(detail);
    }

    final rows = groups.values
        .map((item) => item.toRow(ownFunds, view.totalGross))
        .toList(growable: false)
      ..sort((left, right) => right.grossRisk.compareTo(left.grossRisk));
    final topFive = rows.take(5).toList(growable: false);

    return _ExcelLargeExposureAnalysis(
      rows: rows,
      ownFunds: ownFunds,
      threshold10: ownFunds * 0.10,
      threshold25: ownFunds * 0.25,
      totalAuthorization:
          rows.fold<double>(0.0, (sum, row) => sum + row.authorization),
      totalGrossRisk: rows.fold<double>(0.0, (sum, row) => sum + row.grossRisk),
      totalOnBalance: rows.fold<double>(0.0, (sum, row) => sum + row.onBalance),
      totalOffBalance:
          rows.fold<double>(0.0, (sum, row) => sum + row.offBalance),
      totalGuarantee: rows.fold<double>(0.0, (sum, row) => sum + row.guarantee),
      totalNetRisk: rows.fold<double>(0.0, (sum, row) => sum + row.netRisk),
      topFiveGross:
          topFive.fold<double>(0.0, (sum, row) => sum + row.grossRisk),
      topFiveNet: topFive.fold<double>(0.0, (sum, row) => sum + row.netRisk),
    );
  }

  final List<_ExcelLargeExposureRow> rows;
  final double ownFunds;
  final double threshold10;
  final double threshold25;
  final double totalAuthorization;
  final double totalGrossRisk;
  final double totalOnBalance;
  final double totalOffBalance;
  final double totalGuarantee;
  final double totalNetRisk;
  final double topFiveGross;
  final double topFiveNet;

  _ExcelLargeExposureRow? get leader => rows.isEmpty ? null : rows.first;
  double get topFiveGrossOwnFundsRatio =>
      ownFunds <= 0 ? 0.0 : topFiveGross / ownFunds;
  double get topFiveNetOwnFundsRatio =>
      ownFunds <= 0 ? 0.0 : topFiveNet / ownFunds;
  double get topFiveGrossPortfolioRatio =>
      totalGrossRisk <= 0 ? 0.0 : topFiveGross / totalGrossRisk;
  double get topFiveNetPortfolioRatio =>
      totalNetRisk <= 0 ? 0.0 : topFiveNet / totalNetRisk;
  double get leaderGrossOwnFundsRatio => leader?.grossOwnFundsRatio ?? 0.0;
  double get leaderNetOwnFundsRatio => leader?.netOwnFundsRatio ?? 0.0;
  double get leaderGrossPortfolioRatio =>
      totalGrossRisk <= 0 ? 0.0 : (leader?.grossRisk ?? 0.0) / totalGrossRisk;
  double get leaderNetPortfolioRatio =>
      totalNetRisk <= 0 ? 0.0 : (leader?.netRisk ?? 0.0) / totalNetRisk;
  double get utilizationRate =>
      totalAuthorization <= 0 ? 0.0 : totalGrossRisk / totalAuthorization;
  double get coverageRate =>
      totalGrossRisk <= 0 ? 0.0 : totalGuarantee / totalGrossRisk;
  int get warningCount =>
      rows.where((row) => row.grossOwnFundsRatio >= 0.10).length;
  int get breachCount =>
      rows.where((row) => row.netOwnFundsRatio >= 0.25).length;
}

class _ExcelLargeExposureAccumulator {
  _ExcelLargeExposureAccumulator(this.counterparty);

  final String counterparty;
  final ids = <String>[];
  final countries = <String, int>{};
  final sectors = <String, int>{};
  final ratings = <String, int>{};
  var authorization = 0.0;
  var onBalance = 0.0;
  var offBalance = 0.0;
  var grossRisk = 0.0;
  var netRisk = 0.0;
  var rwa = 0.0;

  void add(ConcentrationExposureDetail detail) {
    ids.add(detail.id);
    _count(countries, detail.country);
    _count(sectors, detail.sector);
    _count(ratings, detail.rating);
    authorization +=
        _positiveOr(detail.authorizationAmount, detail.grossAmount);
    final resolvedOnBalance =
        _positiveOr(detail.onBalanceAmount, detail.grossAmount);
    final resolvedOffBalance = math.max(0.0, detail.offBalanceAmount);
    final resolvedGross = resolvedOnBalance + resolvedOffBalance;
    onBalance += resolvedOnBalance;
    offBalance += resolvedOffBalance;
    grossRisk += resolvedGross <= 0 ? detail.grossAmount : resolvedGross;
    netRisk += detail.ead;
    rwa += detail.rwa;
  }

  _ExcelLargeExposureRow toRow(double ownFunds, double portfolioGross) {
    final guarantee = math.max(0.0, grossRisk - netRisk);
    return _ExcelLargeExposureRow(
      refs: _refsLabel(ids),
      counterparty: counterparty,
      rating: _dominantLabel(ratings),
      country: _dominantLabel(countries),
      sector: _dominantLabel(sectors),
      authorization: authorization,
      grossRisk: grossRisk,
      grossBalanceRisk: onBalance,
      onBalance: onBalance,
      offBalance: offBalance,
      guarantee: guarantee,
      netRisk: netRisk,
      rwa: rwa,
      grossOwnFundsRatio: ownFunds <= 0 ? 0.0 : grossRisk / ownFunds,
      netOwnFundsRatio: ownFunds <= 0 ? 0.0 : netRisk / ownFunds,
      portfolioRatio: portfolioGross <= 0 ? 0.0 : grossRisk / portfolioGross,
      utilizationRate: authorization <= 0 ? 0.0 : grossRisk / authorization,
    );
  }

  static void _count(Map<String, int> values, String raw) {
    final value = raw.trim().isEmpty ? 'Non renseigné' : raw.trim();
    values.update(value, (count) => count + 1, ifAbsent: () => 1);
  }
}

class _ExcelLargeExposureRow {
  const _ExcelLargeExposureRow({
    required this.refs,
    required this.counterparty,
    required this.rating,
    required this.country,
    required this.sector,
    required this.authorization,
    required this.grossRisk,
    required this.grossBalanceRisk,
    required this.onBalance,
    required this.offBalance,
    required this.guarantee,
    required this.netRisk,
    required this.rwa,
    required this.grossOwnFundsRatio,
    required this.netOwnFundsRatio,
    required this.portfolioRatio,
    required this.utilizationRate,
  });

  final String refs;
  final String counterparty;
  final String rating;
  final String country;
  final String sector;
  final double authorization;
  final double grossRisk;
  final double grossBalanceRisk;
  final double onBalance;
  final double offBalance;
  final double guarantee;
  final double netRisk;
  final double rwa;
  final double grossOwnFundsRatio;
  final double netOwnFundsRatio;
  final double portfolioRatio;
  final double utilizationRate;

  String get status {
    if (netOwnFundsRatio >= 0.25) return 'Limite 25%';
    if (grossOwnFundsRatio >= 0.10) return 'Vigilance 10%';
    return 'OK';
  }

  Color get statusColor => _ratioColor(
        math.max(grossOwnFundsRatio, netOwnFundsRatio),
      );
}

double _positiveOr(double value, double fallback) {
  return value > 0 ? value : fallback;
}

String _dominantLabel(Map<String, int> values) {
  if (values.isEmpty) return 'Non renseigné';
  final sorted = values.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  if (sorted.length == 1) return sorted.first.key;
  return '${sorted.first.key} +${sorted.length - 1}';
}

String _refsLabel(List<String> ids) {
  if (ids.isEmpty) return '-';
  final compact = ids.take(3).join('/');
  return ids.length > 3 ? '$compact/…' : compact;
}

class _ExcelLargeExposureSummary extends StatelessWidget {
  const _ExcelLargeExposureSummary({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor.withValues(alpha: 0.45);
    return Container(
      decoration: _excelPanelDecoration(context),
      child: Column(
        children: [
          const _ExcelTitleBand(
            title: 'RATIOS FONDS PROPRES REGLEMENTAIRES',
            right: 'Synthèse Top 5 et 1er groupe',
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 42,
                  child: _ExcelRegulatoryRatiosTable(analysis: analysis),
                ),
                Container(width: 1, color: border),
                Expanded(
                  flex: 58,
                  child: _ExcelTopFiveTable(analysis: analysis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExcelTitleBand extends StatelessWidget {
  const _ExcelTitleBand({
    required this.title,
    required this.right,
  });

  final String title;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.concentrationDeeper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Text(
            right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExcelRegulatoryRatiosTable extends StatelessWidget {
  const _ExcelRegulatoryRatiosTable({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ExcelRow(
          cells: [
            const _ExcelCell('Période active', flex: 3, header: true),
            _ExcelCell('En ${_amountUnitLabel()}', flex: 2, header: true),
            const _ExcelCell('Seuil', flex: 2, header: true),
            const _ExcelCell('Montant',
                flex: 2, header: true, align: TextAlign.right),
          ],
        ),
        _ExcelRow(
          cells: [
            const _ExcelCell('FP réglementaires', flex: 3, strong: true),
            _ExcelCell(_amountUnitLabel(), flex: 2),
            const _ExcelCell('Base', flex: 2),
            _ExcelCell(_fmtAmount(analysis.ownFunds),
                flex: 2, align: TextAlign.right, strong: true),
          ],
        ),
        _ExcelRow(
          cells: [
            const _ExcelCell('Seuil notification', flex: 3),
            const _ExcelCell('10%', flex: 2),
            const _ExcelCell('FP × 10%', flex: 2),
            _ExcelCell(_fmtAmount(analysis.threshold10),
                flex: 2, align: TextAlign.right),
          ],
        ),
        _ExcelRow(
          last: true,
          cells: [
            const _ExcelCell('Limite grande exposition', flex: 3),
            const _ExcelCell('25%', flex: 2),
            const _ExcelCell('FP × 25%', flex: 2),
            _ExcelCell(_fmtAmount(analysis.threshold25),
                flex: 2, align: TextAlign.right),
          ],
        ),
      ],
    );
  }
}

class _ExcelTopFiveTable extends StatelessWidget {
  const _ExcelTopFiveTable({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ExcelRow(
          cells: [
            _ExcelCell('Top 5', flex: 2, header: true),
            _ExcelCell('Montant',
                flex: 2, header: true, align: TextAlign.right),
            _ExcelCell('Top5 / FP',
                flex: 2, header: true, align: TextAlign.right),
            _ExcelCell('Top5 / portefeuille',
                flex: 3, header: true, align: TextAlign.right),
            _ExcelCell('1er groupe', flex: 3, header: true),
            _ExcelCell('1er groupe / FP',
                flex: 2, header: true, align: TextAlign.right),
            _ExcelCell('1er groupe / port.',
                flex: 2, header: true, align: TextAlign.right),
          ],
        ),
        _ExcelRow(
          cells: [
            const _ExcelCell('Brut', flex: 2, strong: true),
            _ExcelCell(_fmtAmount(analysis.topFiveGross),
                flex: 2, align: TextAlign.right, strong: true),
            _ExcelCell(
                AppFormatters.percent(analysis.topFiveGrossOwnFundsRatio),
                flex: 2,
                align: TextAlign.right,
                color: _ratioColor(analysis.topFiveGrossOwnFundsRatio)),
            _ExcelCell(
                AppFormatters.percent(analysis.topFiveGrossPortfolioRatio),
                flex: 3,
                align: TextAlign.right),
            _ExcelCell(analysis.leader?.counterparty ?? '-',
                flex: 3, strong: true),
            _ExcelCell(AppFormatters.percent(analysis.leaderGrossOwnFundsRatio),
                flex: 2,
                align: TextAlign.right,
                color: _ratioColor(analysis.leaderGrossOwnFundsRatio)),
            _ExcelCell(
                AppFormatters.percent(analysis.leaderGrossPortfolioRatio),
                flex: 2,
                align: TextAlign.right),
          ],
        ),
        _ExcelRow(
          last: true,
          cells: [
            const _ExcelCell('Net', flex: 2, strong: true),
            _ExcelCell(_fmtAmount(analysis.topFiveNet),
                flex: 2, align: TextAlign.right, strong: true),
            _ExcelCell(AppFormatters.percent(analysis.topFiveNetOwnFundsRatio),
                flex: 2,
                align: TextAlign.right,
                color: _ratioColor(analysis.topFiveNetOwnFundsRatio)),
            _ExcelCell(AppFormatters.percent(analysis.topFiveNetPortfolioRatio),
                flex: 3, align: TextAlign.right),
            _ExcelCell(analysis.leader?.counterparty ?? '-', flex: 3),
            _ExcelCell(AppFormatters.percent(analysis.leaderNetOwnFundsRatio),
                flex: 2,
                align: TextAlign.right,
                color: _ratioColor(analysis.leaderNetOwnFundsRatio)),
            _ExcelCell(AppFormatters.percent(analysis.leaderNetPortfolioRatio),
                flex: 2, align: TextAlign.right),
          ],
        ),
      ],
    );
  }
}

class _ExcelLargeExposureChart extends StatelessWidget {
  const _ExcelLargeExposureChart({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 310,
      decoration: _excelPanelDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ExcelSectionHeader(
            icon: CupertinoIcons.chart_pie_fill,
            title: 'Clients L.E. en chiffres au T3-2025',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _LargeExposurePieChart(analysis: analysis),
          ),
        ],
      ),
    );
  }
}

class _LargeExposurePieChart extends StatelessWidget {
  const _LargeExposurePieChart({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final slices = [
      _LargeExposurePieSlice(
        label: 'Autorisations',
        value: analysis.totalAuthorization,
        color: const Color(0xFF4F81BD),
      ),
      _LargeExposurePieSlice(
        label: 'Risque brut',
        value: analysis.totalGrossRisk,
        color: const Color(0xFFC0504D),
      ),
      _LargeExposurePieSlice(
        label: 'Garanties',
        value: analysis.totalGuarantee,
        color: const Color(0xFF9BBB59),
      ),
      _LargeExposurePieSlice(
        label: 'Risque net',
        value: analysis.totalNetRisk,
        color: const Color(0xFF8064A2),
      ),
    ].where((slice) => slice.value > 0).toList(growable: false);

    if (slices.isEmpty) {
      return const _EmptyInline();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        if (compact) {
          return Row(
            children: [
              Expanded(child: _LargeExposurePie(slices: slices)),
              const SizedBox(width: 10),
              SizedBox(
                width: 190,
                child: _LargeExposurePieLegend(slices: slices),
              ),
            ],
          );
        }

        return Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 210,
                height: 210,
                child: _LargeExposurePie(slices: slices),
              ),
            ),
            Positioned(
              top: 34,
              right: 16,
              child: _LargeExposureCallout(slice: slices[0], width: 245),
            ),
            Positioned(
              bottom: 22,
              left: 250,
              child: _LargeExposureCallout(slice: slices[1], width: 210),
            ),
            Positioned(
              top: 66,
              left: 22,
              child: _LargeExposureCallout(slice: slices[2], width: 210),
            ),
            Positioned(
              top: 4,
              left: 250,
              child: _LargeExposureCallout(slice: slices[3], width: 170),
            ),
          ],
        );
      },
    );
  }
}

class _LargeExposurePie extends StatelessWidget {
  const _LargeExposurePie({required this.slices});

  final List<_LargeExposurePieSlice> slices;

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        centerSpaceRadius: 0,
        sectionsSpace: 5,
        startDegreeOffset: -90,
        pieTouchData: PieTouchData(
          enabled: true,
          touchCallback: (_, __) {},
        ),
        sections: [
          for (final slice in slices)
            PieChartSectionData(
              value: slice.value,
              color: slice.color,
              radius: 84,
              title: '',
            ),
        ],
      ),
    );
  }
}

class _LargeExposurePieLegend extends StatelessWidget {
  const _LargeExposurePieLegend({required this.slices});

  final List<_LargeExposurePieSlice> slices;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slice in slices) ...[
          _LargeExposureCallout(slice: slice),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LargeExposureCallout extends StatelessWidget {
  const _LargeExposureCallout({
    required this.slice,
    this.width,
  });

  final _LargeExposurePieSlice slice;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB8B8B8)),
      ),
      child: Row(
        mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(width: 8, height: 8, color: slice.color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '${slice.label}; ${_fmtAmount(slice.value)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeExposurePieSlice {
  const _LargeExposurePieSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class _ExcelLargeExposureControlBox extends StatelessWidget {
  const _ExcelLargeExposureControlBox({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _excelPanelDecoration(context),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ExcelSectionHeader(
            icon: CupertinoIcons.doc_text_fill,
            title: 'Contrôle total portefeuille',
          ),
          const SizedBox(height: 12),
          _ExcelControlLine(
              'Autorisations', _fmtAmount(analysis.totalAuthorization)),
          _ExcelControlLine('Risque brut', _fmtAmount(analysis.totalGrossRisk)),
          _ExcelControlLine(
              'Risque brut bilan', _fmtAmount(analysis.totalOnBalance)),
          _ExcelControlLine('Hors bilan', _fmtAmount(analysis.totalOffBalance)),
          _ExcelControlLine(
              'GBPD + DN', '-${_fmtAmount(analysis.totalGuarantee)}'),
          _ExcelControlLine('Risque net', _fmtAmount(analysis.totalNetRisk),
              strong: true),
          const Divider(height: 18),
          _ExcelControlLine('Tx d’utilisation',
              AppFormatters.percent(analysis.utilizationRate)),
          _ExcelControlLine(
              'Tx couverture', AppFormatters.percent(analysis.coverageRate)),
          const Divider(height: 18),
          _ExcelControlLine('Groupes >= 10% FP', '${analysis.warningCount}',
              color: const Color(0xFFB54708)),
          _ExcelControlLine('Groupes >= 25% FP net', '${analysis.breachCount}',
              color: const Color(0xFFB42318)),
        ],
      ),
    );
  }
}

class _ExcelControlLine extends StatelessWidget {
  const _ExcelControlLine(
    this.label,
    this.value, {
    this.strong = false,
    this.color,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppTheme.text,
              fontSize: 11.5,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExcelLargeExposureGrid extends StatelessWidget {
  const _ExcelLargeExposureGrid({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _excelPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExcelTitleBand(
            title:
                'CLIENTS LARGE EXPOSURE - ${_amountUnitLabel()}  (25% FP = ${_fmtAmount(analysis.threshold25)} ${_amountUnitLabel()})',
            right: 'Tri décroissant par risque brut',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _excelLargeExposureTableWidth,
              child: Column(
                children: [
                  const _ExcelLargeExposureHeaderRow(),
                  for (var index = 0;
                      index < math.min(analysis.rows.length, 16);
                      index++)
                    _ExcelLargeExposureDataRow(
                      index: index,
                      row: analysis.rows[index],
                    ),
                  _ExcelLargeExposureTotalRow(analysis: analysis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExcelLargeExposureHeaderRow extends StatelessWidget {
  const _ExcelLargeExposureHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const _ExcelWideRow(
      header: true,
      cells: [
        _ExcelWideCell('Réf.', width: 118, align: TextAlign.center),
        _ExcelWideCell('Contrepartie', width: 210),
        _ExcelWideCell('Cotation*', width: 94, align: TextAlign.center),
        _ExcelWideCell('Pays de risque', width: 132),
        _ExcelWideCell('Autorisation', width: 118, align: TextAlign.right),
        _ExcelWideCell('Risque brut', width: 118, align: TextAlign.right),
        _ExcelWideCell('Risque brut (bilan)',
            width: 132, align: TextAlign.right),
        _ExcelWideCell('Bilan', width: 106, align: TextAlign.right),
        _ExcelWideCell('Hors bilan', width: 106, align: TextAlign.right),
        _ExcelWideCell('GBPD+DN', width: 106, align: TextAlign.right),
        _ExcelWideCell('Risque net', width: 118, align: TextAlign.right),
        _ExcelWideCell('RB/FP 10%', width: 94, align: TextAlign.right),
        _ExcelWideCell('RN/FP 25%', width: 94, align: TextAlign.right),
        _ExcelWideCell('Tx util.', width: 86, align: TextAlign.right),
        _ExcelWideCell('Statut', width: 118),
      ],
    );
  }
}

class _ExcelLargeExposureDataRow extends StatelessWidget {
  const _ExcelLargeExposureDataRow({
    required this.index,
    required this.row,
  });

  final int index;
  final _ExcelLargeExposureRow row;

  @override
  Widget build(BuildContext context) {
    return _ExcelWideRow(
      shaded: index.isOdd,
      cells: [
        _ExcelWideCell(row.refs, width: 118, align: TextAlign.center),
        _ExcelWideCell(row.counterparty, width: 210, strong: index == 0),
        _ExcelWideCell(row.rating, width: 94, align: TextAlign.center),
        _ExcelWideCell(row.country, width: 132),
        _ExcelWideCell(_fmtAmount(row.authorization),
            width: 118, align: TextAlign.right),
        _ExcelWideCell(_fmtAmount(row.grossRisk),
            width: 118, align: TextAlign.right, strong: true),
        _ExcelWideCell(_fmtAmount(row.grossBalanceRisk),
            width: 132, align: TextAlign.right),
        _ExcelWideCell(_fmtAmount(row.onBalance),
            width: 106, align: TextAlign.right),
        _ExcelWideCell(_fmtAmount(row.offBalance),
            width: 106, align: TextAlign.right),
        _ExcelWideCell('-${_fmtAmount(row.guarantee)}',
            width: 106, align: TextAlign.right),
        _ExcelWideCell(_fmtAmount(row.netRisk),
            width: 118, align: TextAlign.right, strong: true),
        _ExcelWideCell(AppFormatters.percent(row.grossOwnFundsRatio),
            width: 94,
            align: TextAlign.right,
            color: _ratioColor(row.grossOwnFundsRatio)),
        _ExcelWideCell(AppFormatters.percent(row.netOwnFundsRatio),
            width: 94,
            align: TextAlign.right,
            color: _ratioColor(row.netOwnFundsRatio)),
        _ExcelWideCell(AppFormatters.percent(row.utilizationRate),
            width: 86, align: TextAlign.right),
        _ExcelWideCell(row.status,
            width: 118, color: row.statusColor, strong: true),
      ],
    );
  }
}

class _ExcelLargeExposureTotalRow extends StatelessWidget {
  const _ExcelLargeExposureTotalRow({required this.analysis});

  final _ExcelLargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return _ExcelWideRow(
      total: true,
      cells: [
        const _ExcelWideCell('', width: 118),
        const _ExcelWideCell('TOTAL', width: 210, strong: true),
        const _ExcelWideCell('', width: 94),
        const _ExcelWideCell('', width: 132),
        _ExcelWideCell(_fmtAmount(analysis.totalAuthorization),
            width: 118, align: TextAlign.right, strong: true),
        _ExcelWideCell(_fmtAmount(analysis.totalGrossRisk),
            width: 118, align: TextAlign.right, strong: true),
        _ExcelWideCell(_fmtAmount(analysis.totalOnBalance),
            width: 132, align: TextAlign.right, strong: true),
        _ExcelWideCell(_fmtAmount(analysis.totalOnBalance),
            width: 106, align: TextAlign.right),
        _ExcelWideCell(_fmtAmount(analysis.totalOffBalance),
            width: 106, align: TextAlign.right),
        _ExcelWideCell('-${_fmtAmount(analysis.totalGuarantee)}',
            width: 106, align: TextAlign.right),
        _ExcelWideCell(_fmtAmount(analysis.totalNetRisk),
            width: 118, align: TextAlign.right, strong: true),
        _ExcelWideCell(
            AppFormatters.percent(analysis.ownFunds <= 0
                ? 0.0
                : analysis.totalGrossRisk / analysis.ownFunds),
            width: 94,
            align: TextAlign.right),
        _ExcelWideCell(
            AppFormatters.percent(analysis.ownFunds <= 0
                ? 0.0
                : analysis.totalNetRisk / analysis.ownFunds),
            width: 94,
            align: TextAlign.right),
        _ExcelWideCell(AppFormatters.percent(analysis.utilizationRate),
            width: 86, align: TextAlign.right),
        const _ExcelWideCell('', width: 118),
      ],
    );
  }
}

class _ExcelSectionHeader extends StatelessWidget {
  const _ExcelSectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.concentrationDeeper, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExcelRow extends StatelessWidget {
  const _ExcelRow({
    required this.cells,
    this.last = false,
  });

  final List<_ExcelCell> cells;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: last
                ? Colors.transparent
                : Theme.of(context).dividerColor.withValues(alpha: 0.40),
          ),
        ),
      ),
      child: Row(children: cells),
    );
  }
}

class _ExcelCell extends StatelessWidget {
  const _ExcelCell(
    this.text, {
    required this.flex,
    this.header = false,
    this.strong = false,
    this.align = TextAlign.left,
    this.color,
  });

  final String text;
  final int flex;
  final bool header;
  final bool strong;
  final TextAlign align;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            color: color ?? (header ? AppTheme.muted : AppTheme.text),
            fontSize: header ? 10 : 11,
            fontWeight: header
                ? FontWeight.w800
                : strong
                    ? FontWeight.w800
                    : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ExcelWideRow extends StatelessWidget {
  const _ExcelWideRow({
    required this.cells,
    this.header = false,
    this.shaded = false,
    this.total = false,
  });

  final List<_ExcelWideCell> cells;
  final bool header;
  final bool shaded;
  final bool total;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: header ? 38 : 42,
      decoration: BoxDecoration(
        color: total
            ? AppColors.concentrationDeeper.withValues(alpha: 0.08)
            : header
                ? const Color(0xFFF1F5F9)
                : shaded
                    ? const Color(0xFFF8FAFC)
                    : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Row(children: cells),
    );
  }
}

class _ExcelWideCell extends StatelessWidget {
  const _ExcelWideCell(
    this.text, {
    required this.width,
    this.align = TextAlign.left,
    this.strong = false,
    this.color,
  });

  final String text;
  final double width;
  final TextAlign align;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            color: color ?? AppTheme.text,
            fontSize: 10.7,
            height: 1.05,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _excelPanelDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? AppTheme.darkCard : Colors.white,
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.035),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

String _fmtAmount(double value) => _amountMd(value, maxDecimals: 1);

class _LargeExposureAnalysis {
  const _LargeExposureAnalysis({
    required this.rows,
    required this.ownFunds,
    required this.totalGross,
    required this.totalNet,
    required this.topFiveGross,
    required this.topFiveNet,
    required this.firstGroupGross,
    required this.firstGroupNet,
    required this.alertCount,
    required this.limitCount,
  });

  factory _LargeExposureAnalysis.from(_ConcentrationViewModel view) {
    final ownFunds = _largeExposureOwnFunds(view);
    final rows = view.counterpartyRows
        .map((row) => _LargeExposureRow.from(row, ownFunds, view.totalGross))
        .toList(growable: false)
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final topFive = rows.take(5).toList(growable: false);

    return _LargeExposureAnalysis(
      rows: rows,
      ownFunds: ownFunds,
      totalGross: view.totalGross,
      totalNet: view.totalEad,
      topFiveGross:
          topFive.fold<double>(0.0, (sum, row) => sum + row.grossAmount),
      topFiveNet: topFive.fold<double>(0.0, (sum, row) => sum + row.netAmount),
      firstGroupGross: rows.isEmpty ? 0.0 : rows.first.grossAmount,
      firstGroupNet: rows.isEmpty ? 0.0 : rows.first.netAmount,
      alertCount: rows.where((row) => row.grossOwnFundsRatio >= 0.10).length,
      limitCount: rows.where((row) => row.netOwnFundsRatio >= 0.25).length,
    );
  }

  final List<_LargeExposureRow> rows;
  final double ownFunds;
  final double totalGross;
  final double totalNet;
  final double topFiveGross;
  final double topFiveNet;
  final double firstGroupGross;
  final double firstGroupNet;
  final int alertCount;
  final int limitCount;

  double get topFiveGrossOwnFundsRatio =>
      ownFunds <= 0 ? 0.0 : topFiveGross / ownFunds;
  double get topFiveNetOwnFundsRatio =>
      ownFunds <= 0 ? 0.0 : topFiveNet / ownFunds;
  double get topFiveGrossPortfolioRatio =>
      totalGross <= 0 ? 0.0 : topFiveGross / totalGross;
  double get firstGroupGrossOwnFundsRatio =>
      ownFunds <= 0 ? 0.0 : firstGroupGross / ownFunds;
  _LargeExposureRow? get leader => rows.isEmpty ? null : rows.first;
}

class _LargeExposureRow {
  const _LargeExposureRow({
    required this.counterparty,
    required this.country,
    required this.sector,
    required this.fileCount,
    required this.grossAmount,
    required this.netAmount,
    required this.rwa,
    required this.grossOwnFundsRatio,
    required this.netOwnFundsRatio,
    required this.portfolioShare,
  });

  factory _LargeExposureRow.from(
    ConcentrationExposureRow row,
    double ownFunds,
    double totalGross,
  ) {
    return _LargeExposureRow(
      counterparty: row.counterpartyName,
      country: row.country,
      sector: row.sector,
      fileCount: row.exposureId,
      grossAmount: row.grossAmount,
      netAmount: row.ead,
      rwa: row.rwa,
      grossOwnFundsRatio: ownFunds <= 0 ? 0.0 : row.grossAmount / ownFunds,
      netOwnFundsRatio: ownFunds <= 0 ? 0.0 : row.ead / ownFunds,
      portfolioShare: totalGross <= 0 ? 0.0 : row.grossAmount / totalGross,
    );
  }

  final String counterparty;
  final String country;
  final String sector;
  final String fileCount;
  final double grossAmount;
  final double netAmount;
  final double rwa;
  final double grossOwnFundsRatio;
  final double netOwnFundsRatio;
  final double portfolioShare;

  String get status {
    if (netOwnFundsRatio >= 0.25) {
      return 'Limite 25%';
    }
    if (grossOwnFundsRatio >= 0.10) {
      return 'Vigilance 10%';
    }
    return 'Suivi normal';
  }

  Color get statusColor {
    if (netOwnFundsRatio >= 0.25) {
      return const Color(0xFFB42318);
    }
    if (grossOwnFundsRatio >= 0.10) {
      return const Color(0xFFB54708);
    }
    return const Color(0xFF047857);
  }
}

double _largeExposureOwnFunds(_ConcentrationViewModel view) {
  final estimated = view.totalRwa * 0.09 * 1.42;
  if (estimated > 0) {
    return estimated;
  }
  return view.totalCapital > 0 ? view.totalCapital * 1.42 : 0.0;
}

class _LargeExposureThresholdPill extends StatelessWidget {
  const _LargeExposureThresholdPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.concentrationDeeper.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.concentrationDeeper.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.concentrationDeeper,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _LargeExposureKpiGrid extends StatelessWidget {
  const _LargeExposureKpiGrid({required this.analysis});

  final _LargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 760 ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth < 760 ? 2.25 : 2.65,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _LargeExposureKpiTile(
              icon: CupertinoIcons.square_stack_3d_up_fill,
              label: 'Top 5 brut / FP',
              value: AppFormatters.percent(analysis.topFiveGrossOwnFundsRatio),
              detail:
                  '${_amountMd(analysis.topFiveGross)} ${_amountUnitLabel()}',
              color: AppColors.concentrationDeeper,
            ),
            _LargeExposureKpiTile(
              icon: CupertinoIcons.arrow_down_right_square_fill,
              label: 'Top 5 net / FP',
              value: AppFormatters.percent(analysis.topFiveNetOwnFundsRatio),
              detail: '${_amountMd(analysis.topFiveNet)} ${_amountUnitLabel()}',
              color: const Color(0xFF2563EB),
            ),
            _LargeExposureKpiTile(
              icon: CupertinoIcons.person_2_fill,
              label: 'Premier groupe / FP',
              value:
                  AppFormatters.percent(analysis.firstGroupGrossOwnFundsRatio),
              detail:
                  '${_amountMd(analysis.firstGroupGross)} ${_amountUnitLabel()}',
              color: const Color(0xFF7C3AED),
            ),
            _LargeExposureKpiTile(
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              label: 'Dossiers sous seuil',
              value: '${analysis.alertCount}',
              detail: '${analysis.limitCount} au-dessus de 25%',
              color: analysis.limitCount > 0
                  ? const Color(0xFFB42318)
                  : const Color(0xFFB54708),
            ),
          ],
        );
      },
    );
  }
}

class _LargeExposureKpiTile extends StatelessWidget {
  const _LargeExposureKpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
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

class _LargeExposureChartCard extends StatelessWidget {
  const _LargeExposureChartCard({required this.analysis});

  final _LargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final rows = analysis.rows.take(8).toList(growable: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LargeExposureSectionTitle(
              icon: CupertinoIcons.chart_bar_square_fill,
              title: 'Analyse des limites par groupe',
              subtitle:
                  'Lecture comparée du brut et du net rapportés aux fonds propres.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 292,
              child: rows.isEmpty
                  ? const _EmptyInline()
                  : _LargeExposureRatioChart(rows: rows),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeExposureRatioChart extends StatelessWidget {
  const _LargeExposureRatioChart({required this.rows});

  final List<_LargeExposureRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxRatio = rows.fold<double>(
      0.25,
      (maxValue, row) => math.max(
        maxValue,
        math.max(row.grossOwnFundsRatio, row.netOwnFundsRatio),
      ),
    );
    final maxY = math.max(0.30, (maxRatio * 1.18));

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.border.withValues(alpha: 0.65),
            strokeWidth: 0.8,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF111827),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final row = rows[group.x.toInt()];
              final label = rodIndex == 0 ? 'Brut / FP' : 'Net / FP';
              return BarTooltipItem(
                '${row.counterparty}\n$label : ${AppFormatters.percent(rod.toY)}',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              );
            },
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0.10,
              color: const Color(0xFFB54708).withValues(alpha: 0.72),
              strokeWidth: 1.4,
              dashArray: [6, 4],
            ),
            HorizontalLine(
              y: 0.25,
              color: const Color(0xFFB42318).withValues(alpha: 0.72),
              strokeWidth: 1.4,
              dashArray: [6, 4],
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Text(
                AppFormatters.percent(value),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < rows.length; index++)
            BarChartGroupData(
              x: index,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: rows[index].grossOwnFundsRatio,
                  width: 9,
                  color: AppColors.concentrationDeeper,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: rows[index].netOwnFundsRatio,
                  width: 9,
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LargeExposureLimitCard extends StatelessWidget {
  const _LargeExposureLimitCard({required this.analysis});

  final _LargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final leader = analysis.leader;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LargeExposureSectionTitle(
              icon: CupertinoIcons.shield_lefthalf_fill,
              title: 'Synthèse prudentielle',
              subtitle:
                  'Seuils inspirés du fichier de suivi des large exposures.',
            ),
            const SizedBox(height: 14),
            _LargeExposureLimitRow(
              label: 'Seuil de vigilance',
              value: '10% FP',
              detail: '${analysis.alertCount} groupe(s) concerné(s)',
              color: const Color(0xFFB54708),
            ),
            _LargeExposureLimitRow(
              label: 'Limite single-name',
              value: '25% FP',
              detail: '${analysis.limitCount} dépassement(s) net(s)',
              color: const Color(0xFFB42318),
            ),
            _LargeExposureLimitRow(
              label: 'Top 5 / portefeuille',
              value: AppFormatters.percent(analysis.topFiveGrossPortfolioRatio),
              detail:
                  '${_amountMd(analysis.topFiveGross)} ${_amountUnitLabel()} brut',
              color: AppColors.concentrationDeeper,
            ),
            const SizedBox(height: 8),
            Divider(color: border),
            const SizedBox(height: 10),
            Text(
              'Premier groupe',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              leader?.counterparty ?? 'N/D',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
            ),
            const SizedBox(height: 9),
            _LargeExposureMiniMetric(
              label: 'Brut / FP',
              value: AppFormatters.percent(leader?.grossOwnFundsRatio ?? 0.0),
            ),
            const SizedBox(height: 6),
            _LargeExposureMiniMetric(
              label: 'Net / FP',
              value: AppFormatters.percent(leader?.netOwnFundsRatio ?? 0.0),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeExposureSectionTitle extends StatelessWidget {
  const _LargeExposureSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.concentrationDeeper, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LargeExposureLimitRow extends StatelessWidget {
  const _LargeExposureLimitRow({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                      ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _LargeExposureMiniMetric extends StatelessWidget {
  const _LargeExposureMiniMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.text,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _LargeExposureTableCard extends StatelessWidget {
  const _LargeExposureTableCard({required this.analysis});

  final _LargeExposureAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LargeExposureSectionTitle(
              icon: CupertinoIcons.table_fill,
              title: 'Détail des groupes grands risques',
              subtitle:
                  'Vue structurée brut, net, RWA, ratios FP et statut de limite.',
            ),
            const SizedBox(height: 12),
            if (analysis.rows.isEmpty)
              const SizedBox(height: 180, child: Center(child: _EmptyInline()))
            else
              _LargeExposureDataTable(
                  rows: analysis.rows.take(14).toList(growable: false)),
          ],
        ),
      ),
    );
  }
}

class _LargeExposureDataTable extends StatelessWidget {
  const _LargeExposureDataTable({required this.rows});

  final List<_LargeExposureRow> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _excelLargeExposureTableWidth,
        child: Column(
          children: [
            _LargeExposureTableHeader(border: border),
            for (var index = 0; index < rows.length; index++)
              _LargeExposureTableRow(
                index: index,
                row: rows[index],
                border: border,
                shaded: index.isOdd,
              ),
          ],
        ),
      ),
    );
  }
}

class _LargeExposureTableHeader extends StatelessWidget {
  const _LargeExposureTableHeader({required this.border});

  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.concentrationDeeper.withValues(alpha: 0.07),
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: const Row(
        children: [
          _LargeExposureCell('Rang',
              width: 52, header: true, align: TextAlign.center),
          _LargeExposureCell('Contrepartie', width: 220, header: true),
          _LargeExposureCell('Pays', width: 132, header: true),
          _LargeExposureCell('Secteur', width: 148, header: true),
          _LargeExposureCell('Dossiers', width: 110, header: true),
          _LargeExposureCell('Risque brut',
              width: 112, header: true, align: TextAlign.right),
          _LargeExposureCell('Risque net',
              width: 112, header: true, align: TextAlign.right),
          _LargeExposureCell('RWA',
              width: 104, header: true, align: TextAlign.right),
          _LargeExposureCell('RB/FP',
              width: 82, header: true, align: TextAlign.right),
          _LargeExposureCell('RN/FP',
              width: 82, header: true, align: TextAlign.right),
          _LargeExposureCell('Statut', width: 166, header: true),
        ],
      ),
    );
  }
}

class _LargeExposureTableRow extends StatelessWidget {
  const _LargeExposureTableRow({
    required this.index,
    required this.row,
    required this.border,
    required this.shaded,
  });

  final int index;
  final _LargeExposureRow row;
  final Color border;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: shaded
            ? AppTheme.background.withValues(alpha: 0.42)
            : Colors.transparent,
        border:
            Border(bottom: BorderSide(color: border.withValues(alpha: 0.65))),
      ),
      child: Row(
        children: [
          _LargeExposureCell('${index + 1}',
              width: 52, align: TextAlign.center),
          _LargeExposureCell(row.counterparty, width: 220, strong: index == 0),
          _LargeExposureCell(row.country, width: 132),
          _LargeExposureCell(row.sector, width: 148),
          _LargeExposureCell(row.fileCount, width: 110),
          _LargeExposureCell(
              '${_amountMd(row.grossAmount)} ${_amountUnitLabel()}',
              width: 112,
              align: TextAlign.right,
              strong: true),
          _LargeExposureCell(
              '${_amountMd(row.netAmount)} ${_amountUnitLabel()}',
              width: 112,
              align: TextAlign.right),
          _LargeExposureCell('${_amountMd(row.rwa)} ${_amountUnitLabel()}',
              width: 104, align: TextAlign.right),
          _LargeExposureCell(AppFormatters.percent(row.grossOwnFundsRatio),
              width: 82,
              align: TextAlign.right,
              color: _ratioColor(row.grossOwnFundsRatio)),
          _LargeExposureCell(AppFormatters.percent(row.netOwnFundsRatio),
              width: 82,
              align: TextAlign.right,
              color: _ratioColor(row.netOwnFundsRatio)),
          SizedBox(
            width: 166,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: row.statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: row.statusColor.withValues(alpha: 0.22)),
                ),
                child: Text(
                  row.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: row.statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeExposureCell extends StatelessWidget {
  const _LargeExposureCell(
    this.text, {
    required this.width,
    this.header = false,
    this.strong = false,
    this.align = TextAlign.left,
    this.color,
  });

  final String text;
  final double width;
  final bool header;
  final bool strong;
  final TextAlign align;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          text,
          maxLines: header ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color ?? (header ? AppTheme.muted : AppTheme.text),
                fontSize: header ? 10.5 : 11,
                fontWeight: header
                    ? FontWeight.w800
                    : strong
                        ? FontWeight.w800
                        : FontWeight.w600,
                height: 1.1,
              ),
        ),
      ),
    );
  }
}

Color _ratioColor(double ratio) {
  if (ratio >= 0.25) {
    return const Color(0xFFB42318);
  }
  if (ratio >= 0.10) {
    return const Color(0xFFB54708);
  }
  return const Color(0xFF047857);
}

class _ConcentrationViewModel {
  const _ConcentrationViewModel({
    required this.totalGross,
    required this.totalEad,
    required this.totalRwa,
    required this.totalCapital,
    required this.hhi,
    required this.hhiBadge,
    required this.topSectorLabel,
    required this.topSectorShare,
    required this.topCounterpartyName,
    required this.topCounterpartyShare,
    required this.sectorRows,
    required this.countryRows,
    required this.regionRows,
    required this.prudentialRows,
    required this.riskWeightRows,
    required this.rwaSectorRows,
    required this.counterpartyRows,
    required this.rwaCounterpartyRows,
    required this.exposureDetails,
    required this.sectorDistribution,
    required this.countryDistribution,
    required this.regionDistribution,
    required this.ratingDistribution,
    required this.quality,
    required this.trends,
    required this.alerts,
  });

  factory _ConcentrationViewModel.fromDetails(
    List<ConcentrationExposureDetail> details,
  ) {
    final totalGross =
        details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
    final totalEad = details.fold<double>(0.0, (sum, item) => sum + item.ead);
    final totalRwa = details.fold<double>(0.0, (sum, item) => sum + item.rwa);
    final totalCapital =
        details.fold<double>(0.0, (sum, item) => sum + item.capital);
    final sectorGroups = _groupDetails(details, (item) => item.sector);
    final countryGroups = _groupDetails(details, (item) => item.country);
    final regionGroups = _groupDetails(details, (item) => item.region);
    final prudentialGroups =
        _groupDetails(details, (item) => item.prudentialCategory);
    final counterpartyGroups =
        _groupDetails(details, (item) => item.counterpartyName);
    final riskWeightGroups =
        _groupDetails(details, (item) => _riskWeightBucket(item.riskWeight));

    final sectorRows = _sectorRows(sectorGroups, totalGross, totalRwa)
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final countryRows = _breakdownRows(
      countryGroups,
      'Pays',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final regionRows = _breakdownRows(
      regionGroups,
      'Région',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final prudentialRows = _breakdownRows(
      prudentialGroups,
      'Catégorie prudentielle',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final counterpartyRows = _counterpartyRows(counterpartyGroups, totalGross)
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final rwaCounterpartyRows = [...counterpartyRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final exposureDetails = [...details]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final rwaSectorRows = [...sectorRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final riskWeightRows = _riskWeightRows(
      riskWeightGroups,
      totalEad,
      totalRwa,
    )..sort((left, right) => left.weight.compareTo(right.weight));
    final ratingDistribution = _ratingDistribution(details, totalGross);
    final hhi = _hhi(counterpartyRows.map((item) => item.share));
    final trends = _trends(details);

    return _ConcentrationViewModel(
      totalGross: totalGross,
      totalEad: totalEad,
      totalRwa: totalRwa,
      totalCapital: totalCapital,
      hhi: hhi,
      hhiBadge: _hhiBadge(hhi),
      topSectorLabel: sectorRows.isEmpty ? 'N/D' : sectorRows.first.sector,
      topSectorShare: sectorRows.isEmpty ? 0.0 : sectorRows.first.share,
      topCounterpartyName: counterpartyRows.isEmpty
          ? 'N/D'
          : counterpartyRows.first.counterpartyName,
      topCounterpartyShare:
          counterpartyRows.isEmpty ? 0.0 : counterpartyRows.first.share,
      sectorRows: sectorRows,
      countryRows: countryRows,
      regionRows: regionRows,
      prudentialRows: prudentialRows,
      riskWeightRows: riskWeightRows,
      rwaSectorRows: rwaSectorRows,
      counterpartyRows: counterpartyRows,
      rwaCounterpartyRows: rwaCounterpartyRows,
      exposureDetails: exposureDetails,
      sectorDistribution: _distribution(
        sectorRows.map((item) => (item.sector, item.grossAmount, item.share)),
      ),
      countryDistribution: _distribution(
        countryRows.map(
          (item) => (item.label, item.grossAmount, item.portfolioShare),
        ),
      ),
      regionDistribution: _distribution(
        regionRows.map(
          (item) => (item.label, item.grossAmount, item.portfolioShare),
        ),
      ),
      ratingDistribution: ratingDistribution,
      quality: _quality(details, totalGross, totalEad, trends),
      trends: trends,
      alerts: _alerts(
        latestDate: _latestDate(details),
        totalRwa: totalRwa,
        hhi: hhi,
        sectorRows: sectorRows,
        counterpartyRows: counterpartyRows,
        countryRows: countryRows,
        rwaCounterpartyRows: rwaCounterpartyRows,
        trends: trends,
      ),
    );
  }

  final double totalGross;
  final double totalEad;
  final double totalRwa;
  final double totalCapital;
  final double hhi;
  final String hhiBadge;
  final String topSectorLabel;
  final double topSectorShare;
  final String topCounterpartyName;
  final double topCounterpartyShare;
  final List<SectorConcentrationRow> sectorRows;
  final List<ConcentrationBreakdownRow> countryRows;
  final List<ConcentrationBreakdownRow> regionRows;
  final List<ConcentrationBreakdownRow> prudentialRows;
  final List<RiskWeightBucketRow> riskWeightRows;
  final List<SectorConcentrationRow> rwaSectorRows;
  final List<ConcentrationExposureRow> counterpartyRows;
  final List<ConcentrationExposureRow> rwaCounterpartyRows;
  final List<ConcentrationExposureDetail> exposureDetails;
  final List<DistributionEntry> sectorDistribution;
  final List<DistributionEntry> countryDistribution;
  final List<DistributionEntry> regionDistribution;
  final List<DistributionEntry> ratingDistribution;
  final PortfolioQualitySummary quality;
  final List<ConcentrationTrendPoint> trends;
  final List<ConcentrationAlert> alerts;
}

class _DetailAccumulator {
  _DetailAccumulator(this.label);

  final Object label;
  var exposureCount = 0;
  var grossAmount = 0.0;
  var ead = 0.0;
  var rwa = 0.0;
  var sector = 'Non renseigné';
  var country = 'Non renseigné';

  void add(ConcentrationExposureDetail item) {
    exposureCount += 1;
    grossAmount += item.grossAmount;
    ead += item.ead;
    rwa += item.rwa;
    if (sector == 'Non renseigné' || sector.isEmpty) {
      sector = item.sector;
    }
    if (country == 'Non renseigné' || country.isEmpty) {
      country = item.country;
    }
  }

  double get averageRiskWeight => ead == 0 ? 0.0 : rwa / ead;
}

Map<Object, _DetailAccumulator> _groupDetails(
  List<ConcentrationExposureDetail> details,
  Object Function(ConcentrationExposureDetail item) keyOf,
) {
  final groups = <Object, _DetailAccumulator>{};
  for (final item in details) {
    final key = keyOf(item);
    groups.putIfAbsent(key, () => _DetailAccumulator(key)).add(item);
  }
  return groups;
}

List<SectorConcentrationRow> _sectorRows(
  Map<Object, _DetailAccumulator> groups,
  double totalGross,
  double totalRwa,
) {
  return groups.values
      .map(
        (item) => SectorConcentrationRow(
          sector: item.label.toString(),
          exposureCount: item.exposureCount,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
          share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
        ),
      )
      .toList(growable: false);
}

List<ConcentrationBreakdownRow> _breakdownRows(
  Map<Object, _DetailAccumulator> groups,
  String group,
  double totalGross,
  double totalRwa,
) {
  return groups.values
      .map(
        (item) => ConcentrationBreakdownRow(
          label: item.label.toString(),
          group: group,
          exposureCount: item.exposureCount,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          portfolioShare: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
          rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
        ),
      )
      .toList(growable: false);
}

List<ConcentrationExposureRow> _counterpartyRows(
  Map<Object, _DetailAccumulator> groups,
  double totalGross,
) {
  return groups.values
      .map(
        (item) => ConcentrationExposureRow(
          exposureId: '${item.exposureCount} dossier(s)',
          counterpartyName: item.label.toString(),
          country: item.country,
          sector: item.sector,
          segment: item.sector,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
        ),
      )
      .toList(growable: false);
}

List<RiskWeightBucketRow> _riskWeightRows(
  Map<Object, _DetailAccumulator> groups,
  double totalEad,
  double totalRwa,
) {
  return groups.entries
      .map(
        (entry) => RiskWeightBucketRow(
          label: _riskWeightBucketLabel(entry.key as double),
          weight: entry.key as double,
          exposureCount: entry.value.exposureCount,
          ead: entry.value.ead,
          rwa: entry.value.rwa,
          portfolioShare: totalEad == 0 ? 0.0 : entry.value.ead / totalEad,
          rwaShare: totalRwa == 0 ? 0.0 : entry.value.rwa / totalRwa,
        ),
      )
      .toList(growable: false);
}

List<DistributionEntry> _distribution(
  Iterable<(String, double, double)> rows,
) {
  return rows
      .map(
        (item) => DistributionEntry(
          label: item.$1,
          amount: item.$2,
          percentage: item.$3,
        ),
      )
      .toList(growable: false);
}

List<DistributionEntry> _ratingDistribution(
  List<ConcentrationExposureDetail> details,
  double totalGross,
) {
  final totals = <String, double>{
    for (final rating in _counterpartyRatingOrder) rating: 0.0,
  };
  for (final item in details) {
    final rating = _normalizedRatingBucket(item.rating);
    totals.update(
      rating,
      (value) => value + item.grossAmount,
      ifAbsent: () => item.grossAmount,
    );
  }

  return [
    for (final rating in _counterpartyRatingOrder)
      DistributionEntry(
        label: rating,
        amount: totals[rating] ?? 0.0,
        percentage:
            totalGross == 0 ? 0.0 : (totals[rating] ?? 0.0) / totalGross,
      ),
  ];
}

PortfolioQualitySummary _quality(
  List<ConcentrationExposureDetail> details,
  double totalGross,
  double totalEad,
  List<ConcentrationTrendPoint> trends,
) {
  final defaultRows = details.where((item) => item.isDefault).toList();
  final defaultGross =
      defaultRows.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  final weightedPd = details.fold<double>(
    0.0,
    (sum, item) => sum + item.pd * item.ead,
  );
  final weightedLgd = details.fold<double>(
    0.0,
    (sum, item) => sum + item.lgd * item.ead,
  );
  final estimatedProvision = defaultRows.fold<double>(
    0.0,
    (sum, item) => sum + item.estimatedProvision,
  );
  final nplTrend =
      trends.length < 2 ? 0.0 : trends.last.npl - trends[trends.length - 2].npl;

  return PortfolioQualitySummary(
    nplRatio: totalGross == 0 ? 0.0 : defaultGross / totalGross,
    defaultRate: details.isEmpty ? 0.0 : defaultRows.length / details.length,
    defaultGross: defaultGross,
    riskCoverage: defaultGross == 0 ? 0.0 : estimatedProvision / defaultGross,
    averagePd: totalEad == 0 ? 0.0 : weightedPd / totalEad,
    averageLgd: totalEad == 0 ? 0.0 : weightedLgd / totalEad,
    nplTrend: nplTrend,
    defaultTrend: nplTrend,
    coverageTrend: 0.0,
  );
}

List<ConcentrationTrendPoint> _trends(
  List<ConcentrationExposureDetail> details,
) {
  final groups = <DateTime, List<ConcentrationExposureDetail>>{};
  for (final item in details) {
    final key = DateTime(item.analysisDate.year, item.analysisDate.month);
    groups.putIfAbsent(key, () => <ConcentrationExposureDetail>[]).add(item);
  }
  final dates = groups.keys.toList()..sort();

  return [
    for (final date in dates)
      ConcentrationTrendPoint(
        label: _monthLabel(date),
        date: date,
        ead: groups[date]!.fold<double>(0.0, (sum, item) => sum + item.ead),
        rwa: groups[date]!.fold<double>(0.0, (sum, item) => sum + item.rwa),
        npl: _nplRatio(groups[date]!),
        hhi: _hhiForDetails(groups[date]!),
      ),
  ];
}

List<ConcentrationAlert> _alerts({
  required DateTime latestDate,
  required double totalRwa,
  required double hhi,
  required List<SectorConcentrationRow> sectorRows,
  required List<ConcentrationExposureRow> counterpartyRows,
  required List<ConcentrationBreakdownRow> countryRows,
  required List<ConcentrationExposureRow> rwaCounterpartyRows,
  required List<ConcentrationTrendPoint> trends,
}) {
  final alerts = <ConcentrationAlert>[];
  final ownFundsEstimate = totalRwa * 0.09 * 1.42;

  if (sectorRows.isNotEmpty && sectorRows.first.share > 0.25) {
    alerts.add(
      ConcentrationAlert(
        level: 'Secteur',
        severity: sectorRows.first.share > 0.40 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message:
            '${sectorRows.first.sector} concentre ${AppFormatters.percent(sectorRows.first.share)} du portefeuille.',
        recommendation:
            'Revoir les limites sectorielles et arbitrer les nouvelles entrées.',
      ),
    );
  }
  if (counterpartyRows.isNotEmpty && ownFundsEstimate > 0) {
    final ratio = counterpartyRows.first.grossAmount / ownFundsEstimate;
    if (ratio > 0.10) {
      alerts.add(
        ConcentrationAlert(
          level: 'Client',
          severity: ratio > 0.25 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${counterpartyRows.first.counterpartyName} atteint ${AppFormatters.percent(ratio)} des fonds propres estimés.',
          recommendation:
              'Contrôler la limite single-name, les garanties et les sûretés mobilisables.',
        ),
      );
    }
  }
  if (hhi > 1800) {
    alerts.add(
      ConcentrationAlert(
        level: 'HHI',
        severity: hhi > 2500 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message: 'Indice HHI à ${hhi.toStringAsFixed(0)}.',
        recommendation:
            'Diversifier le portefeuille ou renforcer les seuils internes.',
      ),
    );
  }
  if (countryRows.isNotEmpty && countryRows.first.portfolioShare > 0.25) {
    alerts.add(
      ConcentrationAlert(
        level: 'Pays',
        severity: countryRows.first.portfolioShare > 0.40 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message:
            '${countryRows.first.label} représente ${AppFormatters.percent(countryRows.first.portfolioShare)} du portefeuille.',
        recommendation:
            'Tester les limites pays et les scénarios de stress souverain.',
      ),
    );
  }
  if (rwaCounterpartyRows.isNotEmpty && totalRwa > 0) {
    final topFiveRwa = rwaCounterpartyRows
        .take(5)
        .fold<double>(0.0, (sum, item) => sum + item.rwa);
    final share = topFiveRwa / totalRwa;
    if (share > 0.40) {
      alerts.add(
        ConcentrationAlert(
          level: 'RWA',
          severity: share > 0.60 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${AppFormatters.percent(share)} du RWA est porté par moins de 5 contreparties.',
          recommendation:
              'Prioriser les revues de rating, garanties et arbitrages RWA.',
        ),
      );
    }
  }
  if (trends.length >= 2 && trends[trends.length - 2].ead > 0) {
    final growth = (trends.last.ead - trends[trends.length - 2].ead) /
        trends[trends.length - 2].ead;
    if (growth > 0.15) {
      alerts.add(
        ConcentrationAlert(
          level: 'Croissance',
          severity: growth > 0.30 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              'Croissance EAD de ${AppFormatters.percent(growth)} sur la dernière période.',
          recommendation:
              'Vérifier les nouveaux engagements et leur consommation RWA.',
        ),
      );
    }
  }

  return alerts;
}

DateTime _latestDate(List<ConcentrationExposureDetail> details) {
  if (details.isEmpty) {
    return DateTime.now();
  }
  return details
      .map((item) => item.analysisDate)
      .reduce((left, right) => left.isAfter(right) ? left : right);
}

double _hhi(Iterable<double> shares) {
  return shares.fold<double>(
    0.0,
    (sum, share) => sum + math.pow(share * 100, 2).toDouble(),
  );
}

double _hhiForDetails(List<ConcentrationExposureDetail> details) {
  final totalGross =
      details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  if (totalGross == 0) {
    return 0.0;
  }
  final totals = <String, double>{};
  for (final item in details) {
    totals.update(
      item.counterpartyName,
      (value) => value + item.grossAmount,
      ifAbsent: () => item.grossAmount,
    );
  }
  return _hhi(totals.values.map((amount) => amount / totalGross));
}

String _hhiBadge(double hhi) {
  if (hhi >= 1800) {
    return 'Élevé';
  }
  if (hhi >= 1000) {
    return 'Moyen';
  }
  return 'Faible';
}

double _riskWeightBucket(double weight) {
  const buckets = <double>[0.0, 0.20, 0.50, 0.75, 1.0, 1.50];
  return buckets.reduce(
    (closest, bucket) =>
        (weight - bucket).abs() < (weight - closest).abs() ? bucket : closest,
  );
}

String _riskWeightBucketLabel(double weight) {
  return '${(weight * 100).round()} %';
}

double _nplRatio(List<ConcentrationExposureDetail> details) {
  final totalGross =
      details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  if (totalGross == 0) {
    return 0.0;
  }
  final defaultGross = details
      .where((item) => item.isDefault)
      .fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  return defaultGross / totalGross;
}

String _normalizedRatingBucket(String rating) {
  final raw = rating.trim();
  if (raw.isEmpty || raw == '-') {
    return 'Non noté';
  }

  var normalized = raw
      .toUpperCase()
      .replaceAll('É', 'E')
      .replaceAll('È', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Ë', 'E')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Î', 'I')
      .replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O')
      .replaceAll('Û', 'U')
      .replaceAll('Ù', 'U')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized == 'NON NOTE' ||
      normalized == 'NON NOTEE' ||
      normalized == 'NON RENSEIGNE' ||
      normalized == 'NR' ||
      normalized == 'N/R' ||
      normalized == 'ND' ||
      normalized == 'N.D.' ||
      normalized == 'N/A') {
    return 'Non noté';
  }

  normalized = normalized.replaceAll(' ', '');
  if (normalized == '<B-' || normalized.startsWith('CCC')) {
    return '< B-';
  }
  if (normalized == 'CC' ||
      normalized == 'C' ||
      normalized == 'D' ||
      normalized == 'SD') {
    return '< B-';
  }
  if (normalized.contains('/')) {
    for (final part in normalized.split('/')) {
      final bucket = _normalizedRatingBucket(part);
      if (bucket != 'Non noté' && bucket != '< B-') {
        return bucket;
      }
    }
    return '< B-';
  }

  for (final rating in _counterpartyRatingOrder) {
    if (normalized == rating.replaceAll(' ', '').toUpperCase()) {
      return rating;
    }
  }

  return 'Non noté';
}

String _monthLabel(DateTime date) {
  const months = [
    'Janv.',
    'Févr.',
    'Mars',
    'Avr.',
    'Mai',
    'Juin',
    'Juil.',
    'Août',
    'Sept.',
    'Oct.',
    'Nov.',
    'Déc.',
  ];
  return months[date.month - 1];
}

TextStyle _tableHeaderStyle() {
  return const TextStyle(
    color: AppTheme.muted,
    fontWeight: FontWeight.w600,
    fontSize: 11,
  );
}

String _amountMd(double value, {int maxDecimals = 1}) {
  final scaled = value / PortfolioAmountUnitPreference.current.divisor;
  final decimals = maxDecimals.clamp(0, 5);

  if (scaled == 0) {
    return '0';
  }

  if (decimals > 0 &&
      PortfolioAmountUnitPreference.current.divisor >= 1000000000) {
    final precisionFloor = math.pow(10, -decimals).toDouble();
    if (scaled.abs() < precisionFloor) {
      final minimumLabel = '0,${''.padLeft(decimals - 1, '0')}1';
      return scaled.isNegative ? '-$minimumLabel' : '< $minimumLabel';
    }
  }

  // Fall through to normal formatting.

  return _formatFullFrenchNumber(scaled, decimals);
}

String _amountUnitLabel() => PortfolioAmountUnitPreference.current.label;

String _amountUnitFcfaLabel() => '${_amountUnitLabel()} FCFA';

String _formatFullFrenchNumber(double value, int decimals) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final trimmed = decimals == 0
      ? fixed
      : fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  final parts = trimmed.split('.');
  final integer = parts.first;
  final decimal = parts.length > 1 ? parts[1] : '';
  final groups = <String>[];

  for (var end = integer.length; end > 0; end -= 3) {
    final start = math.max(0, end - 3);
    groups.insert(0, integer.substring(start, end));
  }

  final sign = value.isNegative ? '-' : '';
  final integerLabel = groups.isEmpty ? '0' : groups.join(' ');
  return decimal.isEmpty ? '$sign$integerLabel' : '$sign$integerLabel,$decimal';
}

class _RwaExposureColumnSpec {
  const _RwaExposureColumnSpec(
    this.label,
    this.width, {
    this.align = TextAlign.left,
  });

  final String label;
  final double width;
  final TextAlign align;

  _RwaExposureColumnSpec copyWith({double? width}) {
    return _RwaExposureColumnSpec(
      label,
      width ?? this.width,
      align: align,
    );
  }
}

const List<_RwaExposureColumnSpec> _rwaExposureColumns = [
  _RwaExposureColumnSpec('ID exposition', 118),
  _RwaExposureColumnSpec('Contrepartie', 230),
  _RwaExposureColumnSpec('Catégorie', 160),
  _RwaExposureColumnSpec('Pays', 120),
  _RwaExposureColumnSpec('EAD', 132, align: TextAlign.right),
  _RwaExposureColumnSpec('RWA', 132, align: TextAlign.right),
  _RwaExposureColumnSpec('Pondération', 122, align: TextAlign.center),
  _RwaExposureColumnSpec('Couverture CRM', 144, align: TextAlign.center),
  _RwaExposureColumnSpec('Contribution RWA', 164),
];

class _RwaExposureTableCard extends StatefulWidget {
  const _RwaExposureTableCard({
    required this.rows,
    required this.totalRwa,
  });

  final List<ConcentrationExposureDetail> rows;
  final double totalRwa;

  @override
  State<_RwaExposureTableCard> createState() => _RwaExposureTableCardState();
}

class _RwaExposureTableCardState extends State<_RwaExposureTableCard> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  String? _selectedRowId;
  var _sortColumnIndex = 5;
  var _sortAscending = false;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final sortedRows = _sortedRows(rows);

    return SectionCard(
      title: '',
      child: rows.isEmpty
          ? const _EmptyInline(
              message:
                  'Aucune exposition RWA disponible sur le périmètre filtré.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RwaExposureSummaryStrip(
                  rows: rows,
                  totalRwa: widget.totalRwa,
                ),
                const SizedBox(height: 6),
                const _RwaAmountUnitLegend(),
                const SizedBox(height: 6),
                Expanded(child: _buildTable(context, sortedRows)),
              ],
            ),
    );
  }

  List<ConcentrationExposureDetail> _sortedRows(
    List<ConcentrationExposureDetail> rows,
  ) {
    final sortedRows = rows.toList(growable: false);
    sortedRows.sort((left, right) {
      final comparison = _compareRows(left, right, _sortColumnIndex);
      if (comparison != 0) {
        return _sortAscending ? comparison : -comparison;
      }
      return _compareText(left.id, right.id);
    });
    return sortedRows;
  }

  int _compareRows(
    ConcentrationExposureDetail left,
    ConcentrationExposureDetail right,
    int columnIndex,
  ) {
    return switch (columnIndex) {
      0 => _compareText(left.id, right.id),
      1 => _compareText(left.counterpartyName, right.counterpartyName),
      2 => _compareText(left.prudentialCategory, right.prudentialCategory),
      3 => _compareText(left.country, right.country),
      4 => left.ead.compareTo(right.ead),
      5 => left.rwa.compareTo(right.rwa),
      6 => left.riskWeight.compareTo(right.riskWeight),
      7 => left.crmCoverageRatio.compareTo(right.crmCoverageRatio),
      8 => _rwaContribution(left).compareTo(_rwaContribution(right)),
      _ => 0,
    };
  }

  int _compareText(String left, String right) {
    return left.toLowerCase().compareTo(right.toLowerCase());
  }

  double _rwaContribution(ConcentrationExposureDetail row) {
    if (widget.totalRwa <= 0) return 0;
    return row.rwa / widget.totalRwa;
  }

  void _sortByColumn(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = !_isNumericRwaColumn(columnIndex);
      }
    });

    if (_verticalController.hasClients) {
      _verticalController.jumpTo(0);
    }
  }

  bool _isNumericRwaColumn(int columnIndex) {
    return switch (columnIndex) {
      4 || 5 || 6 || 7 || 8 => true,
      _ => false,
    };
  }

  List<_RwaExposureColumnSpec> _expandedColumnsForWidth(
    double availableWidth,
    int fixedColumnIndex,
    List<int> scrollableColumnIndexes,
  ) {
    final fixedWidth = _rwaExposureColumns[fixedColumnIndex].width;
    final scrollableViewport = math.max(0.0, availableWidth - fixedWidth);
    final baseScrollableWidth = scrollableColumnIndexes.fold<double>(
      0.0,
      (sum, index) => sum + _rwaExposureColumns[index].width,
    );

    if (scrollableViewport <= baseScrollableWidth || baseScrollableWidth <= 0) {
      return _rwaExposureColumns;
    }

    final extraWidth = scrollableViewport - baseScrollableWidth;
    return List<_RwaExposureColumnSpec>.generate(
      _rwaExposureColumns.length,
      (index) {
        final column = _rwaExposureColumns[index];
        if (!scrollableColumnIndexes.contains(index)) {
          return column;
        }
        final ratio = column.width / baseScrollableWidth;
        return column.copyWith(width: column.width + extraWidth * ratio);
      },
      growable: false,
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<ConcentrationExposureDetail> rows,
  ) {
    const headerHeight = 38.0;
    const rowHeight = 45.0;
    final bodyHeight = rows.length <= 7 ? rows.length * rowHeight : 306.0;
    final tableHeight = headerHeight + bodyHeight;
    const leftColumnIndex = 0;
    final scrollableColumnIndexes = List<int>.generate(
      _rwaExposureColumns.length - 1,
      (index) => index + 1,
      growable: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveColumns = _expandedColumnsForWidth(
          constraints.maxWidth,
          leftColumnIndex,
          scrollableColumnIndexes,
        );
        final scrollableColumns = scrollableColumnIndexes
            .map((index) => effectiveColumns[index])
            .toList(growable: false);
        final scrollableWidth = scrollableColumns.fold<double>(
          0.0,
          (sum, column) => sum + column.width,
        );
        final fixedWidth = effectiveColumns[leftColumnIndex].width;
        final centerViewportWidth =
            math.max(0.0, constraints.maxWidth - fixedWidth);
        final needsHorizontalScroll = scrollableWidth > centerViewportWidth;

        return Container(
          height: tableHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(_concentrationRadius),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RwaExposurePinnedColumn(
                rows: rows,
                columns: effectiveColumns,
                columnIndex: leftColumnIndex,
                totalRwa: widget.totalRwa,
                verticalController: _verticalController,
                headerHeight: headerHeight,
                rowHeight: rowHeight,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                onSort: _sortByColumn,
                selectedRowId: _selectedRowId,
                onRowSelected: _selectRow,
              ),
              Expanded(
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: needsHorizontalScroll,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: scrollableWidth,
                      height: tableHeight,
                      child: Column(
                        children: [
                          _RwaExposureTableHeader(
                            columns: scrollableColumns,
                            columnIndexes: scrollableColumnIndexes,
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _sortAscending,
                            onSort: _sortByColumn,
                          ),
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: rows.length > 7,
                              notificationPredicate: (notification) =>
                                  notification.metrics.axis == Axis.vertical,
                              child: ListView.builder(
                                addSemanticIndexes: false,
                                controller: _verticalController,
                                physics: const ClampingScrollPhysics(),
                                itemExtent: rowHeight,
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  return _RwaExposureDataRow(
                                    row: rows[index],
                                    index: index,
                                    totalRwa: widget.totalRwa,
                                    columns: effectiveColumns,
                                    columnIndexes: scrollableColumnIndexes,
                                    selected: _selectedRowId == rows[index].id,
                                    onSelected: _selectRow,
                                  );
                                },
                              ),
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
        );
      },
    );
  }

  void _selectRow(ConcentrationExposureDetail row) {
    if (_selectedRowId == row.id) return;
    setState(() => _selectedRowId = row.id);
  }
}

class _RwaExposureSummaryStrip extends StatelessWidget {
  const _RwaExposureSummaryStrip({
    required this.rows,
    required this.totalRwa,
  });

  final List<ConcentrationExposureDetail> rows;
  final double totalRwa;

  @override
  Widget build(BuildContext context) {
    final totalEad = rows.fold<double>(0.0, (sum, item) => sum + item.ead);
    final averageRiskWeight = totalEad <= 0 ? 0.0 : totalRwa / totalEad;
    final topExposure = rows.first;
    final topShare =
        totalRwa <= 0 ? 0.0 : (topExposure.rwa / totalRwa).clamp(0.0, 1.0);
    final defaultCount = rows.where((item) => item.isDefault).length;
    final tiles = [
      _RwaSummaryTile(
        label: 'RWA crédit',
        value: _amountMd(totalRwa),
        caption: 'capital consommé',
        color: AppTheme.accent,
      ),
      _RwaSummaryTile(
        label: 'EAD total',
        value: _amountMd(totalEad),
        caption: 'base exposée',
        color: AppTheme.success,
      ),
      _RwaSummaryTile(
        label: 'RW moyen',
        value: AppFormatters.percent(averageRiskWeight),
        caption: 'pondération moyenne',
        color: _riskWeightColor(averageRiskWeight),
      ),
      _RwaSummaryTile(
        label: 'Plus fort contributeur',
        value: AppFormatters.percent(topShare.toDouble()),
        caption: topExposure.counterpartyName,
        color: AppTheme.warning,
      ),
      _RwaSummaryTile(
        label: 'Défauts',
        value: '$defaultCount',
        caption: 'expositions marquées',
        color: defaultCount > 0 ? AppTheme.danger : AppTheme.success,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppTheme.accent.withValues(alpha: 0.035),
          Theme.of(context).cardColor,
        ),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  Expanded(child: tiles[index]),
                  if (index != tiles.length - 1) const SizedBox(width: gap),
                ],
              ],
            );
          }

          final tileWidth = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles)
                SizedBox(
                  width: tileWidth,
                  child: tile,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RwaSummaryTile extends StatelessWidget {
  const _RwaSummaryTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surface = Color.alphaBlend(
      color.withValues(alpha: 0.022),
      Theme.of(context).cardColor,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.34),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _RwaAmountUnitLegend extends StatelessWidget {
  const _RwaAmountUnitLegend();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppColors.concentrationPrimary,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.concentrationPrimary.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.number,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              'Montants en ${_amountUnitFcfaLabel()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RwaExposureTableHeader extends StatelessWidget {
  const _RwaExposureTableHeader({
    required this.columns,
    required this.columnIndexes,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_RwaExposureColumnSpec> columns;
  final List<int> columnIndexes;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppTheme.sidebarLight,
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            _RwaExposureHeaderCell(
              column: columns[index],
              columnIndex: columnIndexes[index],
              sorted: sortColumnIndex == columnIndexes[index],
              ascending: sortAscending,
              onSort: onSort,
            ),
        ],
      ),
    );
  }
}

class _RwaExposureHeaderCell extends StatelessWidget {
  const _RwaExposureHeaderCell({
    required this.column,
    required this.columnIndex,
    required this.sorted,
    required this.ascending,
    required this.onSort,
  });

  final _RwaExposureColumnSpec column;
  final int columnIndex;
  final bool sorted;
  final bool ascending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: column.width,
      height: double.infinity,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(columnIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: sorted
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: sorted
                      ? Colors.white.withValues(alpha: 0.78)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: _headerAlignment(column.align),
                  child: Padding(
                    padding: EdgeInsets.only(right: sorted ? 12 : 0),
                    child: Text(
                      column.label,
                      textAlign: column.align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1,
                          ),
                    ),
                  ),
                ),
                if (sorted)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      ascending
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      color: Colors.white,
                      size: 10,
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

Alignment _headerAlignment(TextAlign align) {
  return switch (align) {
    TextAlign.right || TextAlign.end => Alignment.centerRight,
    TextAlign.center || TextAlign.justify => Alignment.center,
    _ => Alignment.centerLeft,
  };
}

class _RwaExposurePinnedColumn extends StatelessWidget {
  const _RwaExposurePinnedColumn({
    required this.rows,
    required this.columns,
    required this.columnIndex,
    required this.totalRwa,
    required this.verticalController,
    required this.headerHeight,
    required this.rowHeight,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.selectedRowId,
    required this.onRowSelected,
  });

  final List<ConcentrationExposureDetail> rows;
  final List<_RwaExposureColumnSpec> columns;
  final int columnIndex;
  final double totalRwa;
  final ScrollController verticalController;
  final double headerHeight;
  final double rowHeight;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;
  final String? selectedRowId;
  final ValueChanged<ConcentrationExposureDetail> onRowSelected;

  @override
  Widget build(BuildContext context) {
    final column = columns[columnIndex];
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.76);
    final shadowColor = const Color(0xFF0F172A).withValues(alpha: 0.08);
    final pinnedRows = Column(
      children: List.generate(
        rows.length,
        (index) => SizedBox(
          height: rowHeight,
          child: _RwaExposureDataRow(
            row: rows[index],
            index: index,
            totalRwa: totalRwa,
            columns: columns,
            columnIndexes: [columnIndex],
            selected: selectedRowId == rows[index].id,
            onSelected: onRowSelected,
            showSelectionStripe: true,
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SizedBox(
        width: column.width,
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: _RwaExposureTableHeader(
                columns: [column],
                columnIndexes: [columnIndex],
                sortColumnIndex: sortColumnIndex,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: verticalController,
                  builder: (context, child) {
                    final offset = verticalController.hasClients
                        ? verticalController.offset
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(0, -offset),
                      child: child,
                    );
                  },
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: SizedBox(
                      height: rows.length * rowHeight,
                      child: pinnedRows,
                    ),
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

class _RwaExposureDataRow extends StatefulWidget {
  const _RwaExposureDataRow({
    required this.row,
    required this.index,
    required this.totalRwa,
    required this.columns,
    required this.columnIndexes,
    required this.selected,
    required this.onSelected,
    this.showSelectionStripe = false,
  });

  final ConcentrationExposureDetail row;
  final int index;
  final double totalRwa;
  final List<_RwaExposureColumnSpec> columns;
  final List<int> columnIndexes;
  final bool selected;
  final ValueChanged<ConcentrationExposureDetail> onSelected;
  final bool showSelectionStripe;

  @override
  State<_RwaExposureDataRow> createState() => _RwaExposureDataRowState();
}

class _RwaExposureDataRowState extends State<_RwaExposureDataRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final rwaShare = widget.totalRwa <= 0
        ? 0.0
        : (row.rwa / widget.totalRwa).clamp(0.0, 1.0).toDouble();
    final riskColor = _riskWeightColor(row.riskWeight);
    final baseColor = widget.selected
        ? AppTheme.accent.withValues(alpha: 0.12)
        : widget.index.isEven
            ? Theme.of(context).cardColor
            : Color.alphaBlend(
                AppTheme.accent.withValues(alpha: 0.025),
                Theme.of(context).cardColor,
              );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = true);
      }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = false);
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelected(row),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hovered && !widget.selected
                ? Color.alphaBlend(
                    AppTheme.accent.withValues(alpha: 0.055),
                    Theme.of(context).cardColor,
                  )
                : baseColor,
          ),
          foregroundDecoration: BoxDecoration(
            border: Border(
              left: widget.selected && widget.showSelectionStripe
                  ? const BorderSide(color: AppTheme.accent, width: 2.5)
                  : BorderSide.none,
              bottom: BorderSide(
                color: widget.selected
                    ? AppTheme.accent.withValues(alpha: 0.26)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.72),
              ),
            ),
          ),
          child: Row(
            children: [
              for (final columnIndex in widget.columnIndexes)
                _buildCell(
                  context,
                  columnIndex,
                  row,
                  rwaShare,
                  riskColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    int columnIndex,
    ConcentrationExposureDetail row,
    double rwaShare,
    Color riskColor,
  ) {
    final spec = widget.columns[columnIndex];
    return switch (columnIndex) {
      0 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.text,
                  fontSize: 12,
                  fontFamily: AppTheme.dataFontFamily,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ),
      1 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.counterpartyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      2 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.prudentialCategory,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      3 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.country,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      4 => _RwaTextCell(
          spec: spec,
          child: _RwaAmountText(
            label: _amountMd(row.ead, maxDecimals: 5),
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      5 => _RwaTextCell(
          spec: spec,
          child: _RwaAmountText(
            label: _amountMd(row.rwa, maxDecimals: 5),
            color: AppTheme.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      6 => _RwaTextCell(
          spec: spec,
          child: Align(
            alignment: Alignment.center,
            child: _RwaBadge(
              label: AppFormatters.percent(row.riskWeight),
              color: riskColor,
            ),
          ),
        ),
      7 => _RwaTextCell(
          spec: spec,
          child: Align(
            alignment: Alignment.center,
            child: _RwaBadge(
              label: AppFormatters.percent(row.crmCoverageRatio),
              color: _crmCoverageColor(row.crmCoverageRatio),
            ),
          ),
        ),
      8 => _RwaTextCell(
          spec: spec,
          child: _RwaShareCell(share: rwaShare),
        ),
      _ => _RwaTextCell(
          spec: spec,
          child: const SizedBox.shrink(),
        ),
    };
  }
}

class _RwaTextCell extends StatelessWidget {
  const _RwaTextCell({
    required this.spec,
    required this.child,
  });

  final _RwaExposureColumnSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: spec.width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DefaultTextStyle.merge(
          textAlign: spec.align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
          child: child,
        ),
      ),
    );
  }
}

class _RwaAmountText extends StatelessWidget {
  const _RwaAmountText({
    required this.label,
    required this.color,
    required this.fontWeight,
  });

  final String label;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: fontWeight,
                height: 1,
              ),
        ),
      ),
    );
  }
}

class _RwaShareCell extends StatelessWidget {
  const _RwaShareCell({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppFormatters.percent(share),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.text,
                fontSize: 11.6,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(_concentrationRadius),
          child: Stack(
            children: [
              Container(
                height: 4,
                color: AppTheme.border.withValues(alpha: 0.72),
              ),
              FractionallySizedBox(
                widthFactor: share.clamp(0.0, 1.0).toDouble(),
                child: Container(
                  height: 4,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _crmCoverageColor(double value) {
  if (value >= 0.50) return AppTheme.success;
  if (value > 0) return AppColors.qualityAverage;
  return AppTheme.muted;
}

class _RwaBadge extends StatelessWidget {
  const _RwaBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
}

class _RiskWeightLegend extends StatelessWidget {
  const _RiskWeightLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RiskWeightLegendItem(label: 'EAD', color: AppColors.riskWeightGreen),
        SizedBox(width: 3),
        _RiskWeightLegendItem(label: 'RWA', color: AppColors.riskWeightDark),
      ],
    );
  }
}

class _RiskWeightLegendItem extends StatelessWidget {
  const _RiskWeightLegendItem({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_concentrationRadius),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
        ),
      ],
    );
  }
}

enum _GeographyCardMode { countries, zones }

class _IssuerResidenceCountryCard extends StatefulWidget {
  const _IssuerResidenceCountryCard({
    required this.countryRows,
    required this.zoneRows,
  });

  final List<DistributionEntry> countryRows;
  final List<DistributionEntry> zoneRows;

  @override
  State<_IssuerResidenceCountryCard> createState() =>
      _IssuerResidenceCountryCardState();
}

class _IssuerResidenceCountryCardState
    extends State<_IssuerResidenceCountryCard> {
  var _mode = _GeographyCardMode.zones;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;
    final showingCountries = _mode == _GeographyCardMode.countries;
    final title = showingCountries
        ? 'Top 10 des pays de résidence émetteurs'
        : 'Concentration géographique';

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.concentrationPrimary,
                          fontSize: 13.4,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                _GeoCardModeSelector(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Divider(color: border),
            const SizedBox(height: 7),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: showingCountries
                    ? _IssuerResidenceCountryBars(
                        key: const ValueKey('countries'),
                        rows: widget.countryRows,
                      )
                    : _ZoneDistributionView(
                        key: const ValueKey('zones'),
                        rows: widget.zoneRows,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoCardModeSelector extends StatelessWidget {
  const _GeoCardModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final _GeographyCardMode mode;
  final ValueChanged<_GeographyCardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ModeSwitchGroup(
      items: [
        _ModeSwitchItem(
          label: 'Pays',
          icon: CupertinoIcons.flag,
          selected: mode == _GeographyCardMode.countries,
          onTap: () => onChanged(_GeographyCardMode.countries),
        ),
        _ModeSwitchItem(
          label: 'Zones',
          icon: CupertinoIcons.globe,
          selected: mode == _GeographyCardMode.zones,
          onTap: () => onChanged(_GeographyCardMode.zones),
        ),
      ],
    );
  }
}

class _ModeSwitchGroup extends StatelessWidget {
  const _ModeSwitchGroup({required this.items});

  final List<_ModeSwitchItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _ModeSwitchButton(item: items[index]),
          if (index != items.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _ModeSwitchItem {
  const _ModeSwitchItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

class _ModeSwitchButton extends StatelessWidget {
  const _ModeSwitchButton({required this.item});

  final _ModeSwitchItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? Colors.white : AppColors.concentrationPrimary;
    final background = item.selected
        ? AppColors.concentrationPrimary
        : AppColors.concentrationPrimary.withValues(alpha: 0.065);

    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(_concentrationRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(_concentrationRadius),
            border: Border.all(
              color: item.selected
                  ? AppColors.concentrationPrimary
                  : AppColors.concentrationPrimary.withValues(alpha: 0.26),
            ),
            boxShadow: item.selected
                ? [
                    BoxShadow(
                      color: AppColors.concentrationPrimary
                          .withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _IssuerResidenceCountryBars extends StatelessWidget {
  const _IssuerResidenceCountryBars({
    super.key,
    required this.rows,
  });

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight / rows.length;
        return Column(
          children: List.generate(rows.length, (index) {
            final row = rows[index];
            return SizedBox(
              height: rowHeight,
              child: _HorizontalShareRow(
                label: row.label,
                share: row.percentage,
                labelWidth: 124,
                color: AppColors.concentrationPrimary,
              ),
            );
          }),
        );
      },
    );
  }
}

class _ZoneDistributionView extends StatelessWidget {
  const _ZoneDistributionView({
    super.key,
    required this.rows,
  });

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    final entries = _standardZoneEntries(rows);
    final activeEntries = entries
        .where((item) => item.amount > 0 || item.percentage > 0)
        .toList(growable: false);
    if (activeEntries.isEmpty) {
      return const _EmptyInline(
        message: 'Aucune répartition par zone disponible.',
      );
    }

    final dominant = activeEntries.reduce(
      (left, right) => right.percentage > left.percentage ? right : left,
    );
    final colors = [for (final entry in entries) _geoZoneColor(entry.label)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final donutSize = math.min(
          compact ? 116.0 : 132.0,
          math.max(96.0, constraints.maxHeight - 12),
        );
        final legendWidth = compact ? 142.0 : 170.0;
        final metricsWidth = compact ? 104.0 : 118.0;
        final contentWidth = donutSize + legendWidth + metricsWidth + 82;

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: math.min(constraints.maxWidth, contentWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: donutSize,
                  child: Center(
                    child: _ZoneDonutChart(
                      entries: activeEntries,
                      colors: [
                        for (final entry in activeEntries)
                          _geoZoneColor(entry.label),
                      ],
                      size: donutSize,
                      dominant: dominant,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                SizedBox(
                  width: legendWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < entries.length; index++)
                        _ZoneLegendRow(
                          entry: entries[index],
                          color: colors[index],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: metricsWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ZoneMetricTile(
                        label: 'Zone dominante',
                        value: dominant.label,
                        color: _geoZoneColor(dominant.label),
                        emphasize: true,
                      ),
                      const SizedBox(height: 7),
                      _ZoneMetricTile(
                        label: 'Part zone',
                        value: AppFormatters.percent(dominant.percentage),
                        color: _geoZoneColor(dominant.label),
                      ),
                      const SizedBox(height: 7),
                      _ZoneMetricTile(
                        label: 'Exp. zone dominante',
                        value:
                            '${_amountMd(dominant.amount)} ${_amountUnitLabel()}',
                        color: AppColors.riskWeightDark,
                      ),
                    ],
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

class _ZoneDonutChart extends StatelessWidget {
  const _ZoneDonutChart({
    required this.entries,
    required this.colors,
    required this.size,
    required this.dominant,
  });

  final List<DistributionEntry> entries;
  final List<Color> colors;
  final double size;
  final DistributionEntry dominant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ZoneDonutPainter(entries: entries, colors: colors),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppFormatters.percent(dominant.percentage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _geoZoneColor(dominant.label),
                      fontSize: size < 120 ? 12.5 : 14,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dominant',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneDonutPainter extends CustomPainter {
  const _ZoneDonutPainter({
    required this.entries,
    required this.colors,
  });

  final List<DistributionEntry> entries;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final totalShare =
        entries.fold<double>(0.0, (sum, item) => sum + item.percentage);
    final strokeWidth = size.shortestSide * 0.15;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = AppColors.riskWeightTrack.withValues(alpha: 0.72);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, paint);

    var startAngle = -math.pi / 2;
    for (var index = 0; index < entries.length; index++) {
      final share = totalShare <= 0
          ? 0.0
          : (entries[index].percentage / totalShare).clamp(0.0, 1.0);
      final sweepAngle = share * math.pi * 2;
      if (sweepAngle <= 0) continue;
      paint.color = colors[index % colors.length];
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _ZoneDonutPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.colors != colors;
  }
}

class _AnimatedDonutChart extends StatefulWidget {
  final List<(double percent, Color color)> entries;
  const _AnimatedDonutChart({required this.entries});

  @override
  State<_AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<_AnimatedDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.entries.fold<double>(0, (sum, item) => sum + item.$1);

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                touchedIndex = -1;
                return;
              }
              touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 16,
        sections: widget.entries.asMap().entries.map((e) {
          final isTouched = e.key == touchedIndex;
          final radius = isTouched ? 36.0 : 30.0;
          final percentage =
              total > 0 ? '${(e.value.$1 / total * 100).round()}%' : '0%';

          return PieChartSectionData(
            color: e.value.$2,
            value: e.value.$1 <= 0 ? 0.0001 : e.value.$1,
            title: isTouched ? percentage : '',
            radius: radius,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ZoneLegendRow extends StatelessWidget {
  const _ZoneLegendRow({
    required this.entry,
    required this.color,
  });

  final DistributionEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.text,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppFormatters.percent(entry.percentage),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _ZoneMetricTile extends StatelessWidget {
  const _ZoneMetricTile({
    required this.label,
    required this.value,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasize ? 0.12 : 0.075),
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 8.4,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: emphasize ? 14.2 : 13.2,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

List<DistributionEntry> _standardZoneEntries(List<DistributionEntry> rows) {
  const labels = ['UEMOA', 'CEMAC', 'Hors zone'];
  final amounts = <String, double>{
    for (final label in labels) label: 0.0,
  };
  final percentages = <String, double>{
    for (final label in labels) label: 0.0,
  };

  for (final row in rows) {
    final label = _standardZoneLabel(row.label);
    amounts[label] = (amounts[label] ?? 0.0) + row.amount;
    percentages[label] = (percentages[label] ?? 0.0) + row.percentage;
  }

  return [
    for (final label in labels)
      DistributionEntry(
        label: label,
        amount: amounts[label] ?? 0.0,
        percentage: percentages[label] ?? 0.0,
      ),
  ];
}

String _standardZoneLabel(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('cemac')) {
    return 'CEMAC';
  }
  if (normalized.contains('uemoa')) {
    return 'UEMOA';
  }
  return 'Hors zone';
}

Color _geoZoneColor(String label) {
  return switch (_standardZoneLabel(label)) {
    'UEMOA' => Colors.blue,
    'CEMAC' => Colors.indigo,
    _ => AppColors.concentrationDeeper,
  };
}

class _SeeAllButton extends StatefulWidget {
  const _SeeAllButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  State<_SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<_SeeAllButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: (_hovered && widget.onPressed != null) ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            overlayColor: Colors.transparent,
            elevation: _hovered ? 3 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text(
            'Voir tout',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCounterpartyExposureCard extends StatelessWidget {
  const _TopCounterpartyExposureCard({
    required this.rows,
    required this.allRows,
  });

  final List<ConcentrationExposureRow> rows;
  final List<ConcentrationExposureRow> allRows;

  void _showAllCounterparties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : AppTheme.card,
          title: Text(
            'Toutes les expositions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          content: SizedBox(
            width: 500,
            height: MediaQuery.of(context).size.height * 0.7,
            child: ListView.separated(
              addSemanticIndexes: false,
              itemCount: allRows.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final row = allRows[index];
                final t = index / (allRows.isEmpty ? 1 : allRows.length);
                final c = t < 0.35
                    ? AppColors.concentrationDeeper
                    : t < 0.7
                        ? Colors.indigo
                        : Colors.blue;
                return SizedBox(
                  height: 28,
                  child: _HorizontalShareRow(
                    label: '${index + 1}. ${row.counterpartyName}',
                    share: row.share,
                    labelWidth: 200,
                    color: c,
                    valueColor: c,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.text,
              ),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top 10 des contreparties les plus exposées',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.concentrationPrimary,
                          fontSize: 13.4,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                  ),
                ),
                _SeeAllButton(
                  onPressed: rows.isEmpty
                      ? null
                      : () => _showAllCounterparties(context),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Divider(color: border),
            const SizedBox(height: 7),
            Expanded(
              child: _CounterpartyBars(rows: rows),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterpartyBars extends StatelessWidget {
  const _CounterpartyBars({required this.rows});

  final List<ConcentrationExposureRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight / rows.length;
        return Column(
          children: List.generate(rows.length, (index) {
            final row = rows[index];
            final t = index / (rows.isEmpty ? 1 : rows.length);
            final c = t < 0.35
                ? AppColors.concentrationDeeper
                : t < 0.7
                    ? Colors.indigo
                    : Colors.blue;
            return SizedBox(
              height: rowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: _HorizontalShareRow(
                  label: '${index + 1}. ${row.counterpartyName}',
                  share: row.share,
                  labelWidth: 158,
                  color: c,
                  valueColor: c,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _HorizontalShareRow extends StatefulWidget {
  const _HorizontalShareRow({
    required this.label,
    required this.share,
    required this.labelWidth,
    required this.color,
    this.valueColor,
  });

  final String label;
  final double share;
  final double labelWidth;
  final Color color;
  final Color? valueColor;

  @override
  State<_HorizontalShareRow> createState() => _HorizontalShareRowState();
}

class _HorizontalShareRowState extends State<_HorizontalShareRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseShare = widget.share.clamp(0.0, 1.0).toDouble();
    final animatedShare =
        (_hovered ? baseShare * 1.045 : baseShare).clamp(0.0, 1.0).toDouble();
    final labelColor =
        _hovered ? AppTheme.text : AppTheme.text.withValues(alpha: 0.92);
    final valueColor = _hovered
        ? widget.color
        : widget.valueColor ?? AppColors.concentrationDark;
    final barHeight = _hovered ? 18.0 : 12.0;

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        children: [
          SizedBox(
            width: widget.labelWidth,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: labelColor,
                        fontSize: 10.4,
                        fontWeight:
                            _hovered ? FontWeight.w700 : FontWeight.w600,
                        height: 1,
                      ) ??
                  TextStyle(
                    color: labelColor,
                    fontSize: 10.4,
                    fontWeight: _hovered ? FontWeight.w700 : FontWeight.w600,
                    height: 1,
                  ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: animatedShare),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, widthFactor, _) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(
                          alpha: _hovered ? 0.14 : 0.09,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(
                            alpha: _hovered ? 1 : 0.94,
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: _hovered
                              ? [
                                  BoxShadow(
                                    color: widget.color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: valueColor,
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ) ??
                                  TextStyle(
                                    color: valueColor,
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                          child: Text(
                            AppFormatters.percent(widget.share),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
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
      ),
    );
  }
}

class _RiskWeightChart extends StatelessWidget {
  const _RiskWeightChart({
    super.key,
    required this.rows,
  });

  final List<RiskWeightBucketRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    final sortedRows = rows.toList(growable: false)
      ..sort((left, right) => left.weight.compareTo(right.weight));
    final dominantRwa = sortedRows.reduce(
      (left, right) => right.rwaShare > left.rwaShare ? right : left,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        const gap = 8.0;
        final cardWidth = math.max(
          compact ? 132.0 : 156.0,
          (constraints.maxWidth - gap * (sortedRows.length - 1)) /
              sortedRows.length,
        );
        final contentWidth =
            cardWidth * sortedRows.length + gap * (sortedRows.length - 1);

        final bucketCards = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < sortedRows.length; index++) ...[
              SizedBox(
                width: cardWidth,
                child: _RiskWeightBucketCard(
                  row: sortedRows[index],
                  isDominant: sortedRows[index] == dominantRwa,
                ),
              ),
              if (index != sortedRows.length - 1)
                SizedBox(
                  width: gap,
                  child: Center(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: AppTheme.border.withValues(alpha: 0.75),
                    ),
                  ),
                ),
            ],
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, bucketConstraints) {
                  if (contentWidth > constraints.maxWidth) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: contentWidth,
                        height: bucketConstraints.maxHeight,
                        child: bucketCards,
                      ),
                    );
                  }
                  return bucketCards;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RiskWeightBucketCard extends StatefulWidget {
  const _RiskWeightBucketCard({
    required this.row,
    required this.isDominant,
  });

  final RiskWeightBucketRow row;
  final bool isDominant;

  @override
  State<_RiskWeightBucketCard> createState() => _RiskWeightBucketCardState();
}

class _RiskWeightBucketCardState extends State<_RiskWeightBucketCard> {
  @override
  Widget build(BuildContext context) {
    const accent = AppColors.panelAccent;
    final eadShare = widget.row.portfolioShare;
    final rwaShare = widget.row.rwaShare;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.text,
                                  fontSize: 13.6,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _riskWeightTone(widget.row.weight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.text.withValues(alpha: 0.68),
                        fontSize: 8.2,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _RiskWeightShareMeter(
                    label: 'EAD',
                    share: eadShare,
                    amount: widget.row.ead,
                    shareLabel: 'Part portefeuille',
                    color: AppColors.riskWeightGreen,
                    valueColor: AppColors.riskWeightText,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _RiskWeightShareMeter(
                    label: 'RWA',
                    share: rwaShare,
                    amount: widget.row.rwa,
                    shareLabel: 'Part RWA',
                    color: AppColors.riskWeightDark,
                    valueColor: AppColors.riskWeightDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _RiskWeightAmountLine(
            ead: widget.row.ead,
            rwa: widget.row.rwa,
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _RiskWeightAmountLine extends StatelessWidget {
  const _RiskWeightAmountLine({
    required this.ead,
    required this.rwa,
    required this.color,
  });

  final double ead;
  final double rwa;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_amountMd(ead)} ${_amountUnitLabel()}',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.text.withValues(alpha: 0.72),
                    fontSize: 8.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        Icon(
          CupertinoIcons.arrow_right,
          size: 10,
          color: color.withValues(alpha: 0.72),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${_amountMd(rwa)} ${_amountUnitLabel()}',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 8.4,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskWeightShareMeter extends StatefulWidget {
  const _RiskWeightShareMeter({
    required this.label,
    required this.share,
    required this.amount,
    required this.shareLabel,
    required this.color,
    required this.valueColor,
  });

  final String label;
  final double share;
  final double amount;
  final String shareLabel;
  final Color color;
  final Color valueColor;

  @override
  State<_RiskWeightShareMeter> createState() => _RiskWeightShareMeterState();
}

class _RiskWeightShareMeterState extends State<_RiskWeightShareMeter> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final heightFactor = widget.share.clamp(0.0, 1.0).toDouble();

    return Tooltip(
      message: [
        widget.label,
        '${widget.shareLabel.replaceFirst('Part ', '')} : ${AppFormatters.percent(widget.share)}',
        'Encours : ${_amountMd(widget.amount)} ${_amountUnitFcfaLabel()}',
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.fromLTRB(3, 8, 3, 8),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      preferBelow: false,
      verticalOffset: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: widget.color.withValues(alpha: 0.46)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10.4,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hovered = true);
        }),
        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hovered = false);
        }),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: widget.valueColor.withValues(
                          alpha: _hovered ? 1 : 0.92,
                        ),
                        fontSize: _hovered ? 8.4 : 8,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ) ??
                  TextStyle(
                    color: widget.valueColor
                        .withValues(alpha: _hovered ? 1 : 0.92),
                    fontSize: _hovered ? 8.4 : 8,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
              child: Text(
                AppFormatters.percent(widget.share),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 30,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: heightFactor),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    builder: (context, fillFactor, _) {
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? widget.color.withValues(alpha: 0.13)
                                  : AppColors.riskWeightTrack,
                              borderRadius:
                                  BorderRadius.circular(_concentrationRadius),
                            ),
                          ),
                          FractionallySizedBox(
                            heightFactor: fillFactor,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    widget.color.withValues(
                                      alpha: _hovered ? 1 : 0.96,
                                    ),
                                    widget.color.withValues(
                                      alpha: _hovered ? 0.92 : 0.78,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  _concentrationRadius,
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
      ),
    );
  }
}

Color _riskWeightColor(double weight) {
  if (weight <= 0.001) {
    return const Color(0xFF0F9F6E);
  }
  if (weight <= 0.20) {
    return const Color(0xFF0EA5E9);
  }
  if (weight <= 0.50) {
    return const Color(0xFF4F46E5);
  }
  if (weight <= 0.75) {
    return const Color(0xFFF59E0B);
  }
  if (weight <= 1.0) {
    return const Color(0xFF7C3AED);
  }
  return const Color(0xFFE11D48);
}

String _riskWeightTone(double weight) {
  if (weight <= 0.001) {
    return 'Exposition neutralisée';
  }
  if (weight <= 0.20) {
    return 'Faible consommation';
  }
  if (weight <= 0.50) {
    return 'Risque modéré';
  }
  if (weight <= 0.75) {
    return 'Transition à suivre';
  }
  if (weight <= 1.0) {
    return 'Pondération standard';
  }
  return 'Capital intensif';
}

List<ConcentrationAlert> _rankedAlerts(List<ConcentrationAlert> alerts) {
  return alerts.toList(growable: false)
    ..sort(
      (left, right) =>
          _severityRank(right.severity).compareTo(_severityRank(left.severity)),
    );
}

String _selectedAlertHeaderTitle(ConcentrationAlert? alert) {
  if (alert == null) {
    return 'Aucune alerte active';
  }
  return _compactAlertHeaderTitle(alert.message);
}

String _compactAlertHeaderTitle(String message) {
  return message
      .replaceAll('des fonds propres estimés', 'des fonds propres')
      .replaceAll(RegExp(r'\.$'), '')
      .trim();
}

List<List<String>> _alertKpiNarratives(
  ConcentrationAlert? alert,
  _ConcentrationViewModel view,
) {
  return [[], [], [], [], [], []];
}

enum _AlertSeverityBand { critical, intermediate, watch }

_AlertSeverityBand _alertSeverityBand(ConcentrationAlert alert) {
  return switch (alert.severity.toLowerCase()) {
    'élevé' || 'eleve' => _AlertSeverityBand.critical,
    'moyen' => _AlertSeverityBand.intermediate,
    _ => _AlertSeverityBand.watch,
  };
}

String _alertSeverityBandLabel(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'critique',
    _AlertSeverityBand.intermediate => 'intermédiaire',
    _ => 'sous surveillance',
  };
}

String _alertSignalSubject(ConcentrationAlert alert) {
  final compact = _compactAlertHeaderTitle(alert.message);
  final match = RegExp(
    r'^(.*?)\s+(atteint|présente|presente|concentre)\b',
    caseSensitive: false,
  ).firstMatch(compact);
  if (match == null) {
    return compact;
  }
  final subject = match.group(1)?.trim();
  if (subject == null || subject.isEmpty) {
    return alert.level;
  }
  return subject;
}

class _AlertNarrativeSet {
  const _AlertNarrativeSet({
    required this.signal,
    required this.risk,
    required this.impact,
    required this.decision,
    required this.action,
    required this.control,
  });

  final List<String> signal;
  final List<String> risk;
  final List<String> impact;
  final List<String> decision;
  final List<String> action;
  final List<String> control;

  List<List<String>> get cards => [
        _compactAlertCard(signal),
        _compactAlertCard(risk),
        _compactAlertCard(impact),
        _compactAlertCard(decision),
        _compactAlertCard(action),
        _compactAlertCard(control),
      ];
}

List<String> _compactAlertCard(List<String> items) {
  return items
      .map(_compactAlertNarrative)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _compactAlertNarrative(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return '';
  }

  final colonIndex = normalized.indexOf(':');
  if (colonIndex <= 0) {
    return _normalizeAlertNarrativeValue(normalized);
  }

  final label = _compactAlertNarrativeLabel(
    normalized.substring(0, colonIndex).trim(),
  );
  final value = _normalizeAlertNarrativeValue(
    normalized.substring(colonIndex + 1).trim(),
  );
  return '$label: $value';
}

String _compactAlertNarrativeLabel(String label) {
  final key = label.toLowerCase().replaceAll('’', "'");
  const labels = {
    'la situation observée': 'Situation',
    'la base analysée': 'Base',
    'la lecture du risque': 'Risque',
    'la qualité crédit': 'Qualité',
    "l'impact portefeuille": 'Portefeuille',
    "l'impact sur le capital": 'Capital',
    'la décision de comité': 'Comité',
    "l'orientation de gestion": 'Orientation',
    'la production nouvelle': 'Production',
    'la gestion des garanties': 'Garanties',
    'le rythme de contrôle': 'Rythme',
    'les indicateurs suivis': 'Indicateurs',
    'la contrepartie concernée': 'Contrepartie',
    "l'exposition mesurée": 'Exposition',
    'la gravité observée': 'Gravité',
    'la lecture prudentielle': 'Lecture',
    'la perte potentielle': 'Perte',
    'le comité risque': 'Comité',
    "l'arbitrage attendu": 'Arbitrage',
    'la limite opérationnelle': 'Limite',
    'les sûretés mobilisables': 'Sûretés',
    'le secteur concerné': 'Secteur',
    "la base d'exposition": 'Exposition',
    'le choc métier': 'Choc',
    'le pays concerné': 'Pays',
    'le scénario pays': 'Scénario',
    'le rwa concentré': 'RWA',
    'l’exposition dominante': 'Exposition',
    "l'indice hhi": 'HHI',
    'la croissance observée': 'Croissance',
    'la base de comparaison': 'Comparaison',
    'le signal détecté': 'Signal',
  };

  final mapped = labels[key];
  if (mapped != null) {
    return mapped;
  }

  return label.replaceFirst(RegExp(r"^(La|Le|Les|L’|L')\s+"), '').trim();
}

String _normalizeAlertNarrativeValue(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}


_AlertNarrativeSet _sectorNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final row = _matchingSector(alert, view) ??
      (view.sectorRows.isEmpty ? null : view.sectorRows.first);
  final sector = row?.sector ?? _alertSignalSubject(alert);

  return _AlertNarrativeSet(
    signal: [
      'Le secteur concerné : le secteur $sector représente ${AppFormatters.percent(row?.share ?? 0)} du portefeuille.',
      'La base d’exposition : ce secteur regroupe ${row?.exposureCount ?? 0} exposition(s), avec un EAD de ${_amountMdFcfa(row?.ead ?? 0)} et un RWA de ${_amountMdFcfa(row?.rwa ?? 0)}.',
      'L’origine du signal : la concentration métier dépasse le seuil interne de diversification.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} en raison d’une corrélation sectorielle accrue.',
      'La lecture prudentielle : le Pilier 2 impose de suivre les concentrations sectorielles et géographiques.',
      'La sensibilité mesurée : le RW moyen atteint ${AppFormatters.percent(row?.averageRiskWeight ?? 0)} et la part RWA ressort à ${AppFormatters.percent(row?.rwaShare ?? 0)}.',
    ],
    impact: [
      'Le choc métier : une dégradation du secteur toucherait plusieurs contreparties liées.',
      'L’impact sur le capital : environ ${_amountMdFcfa((row?.rwa ?? 0) * 0.09)} de capital indicatif dépend de ce secteur.',
      'L’effet portefeuille : la diversification réelle baissera si les nouvelles entrées restent corrélées.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur le plafond sectoriel et la production nouvelle.',
      'L’arbitrage attendu : les nouvelles entrées doivent être réorientées vers des secteurs moins corrélés.',
      'La condition d’acceptation : seuls les dossiers qui améliorent le mix de risque doivent être privilégiés.',
    ],
    action: [
      'Le plafond opérationnel : il faut appliquer ${_primaryMeasure(band)} aux nouveaux tickets du secteur $sector.',
      'La sélection des dossiers : les contreparties mieux notées, garanties ou moins consommatrices de RWA doivent être prioritaires.',
      'Le plan d’exécution : une limite sectorielle et un plan de réallocation doivent être matérialisés.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le poids sectoriel et les nouvelles entrées.',
      'Les indicateurs suivis : la part brute, la part RWA, le RW moyen et le nombre d’expositions doivent être rapprochés.',
      'La preuve de gouvernance : les arbitrages de comité et les validations d’exception doivent être conservés.',
    ],
  );
}

_AlertNarrativeSet _countryNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final row = _matchingCountry(alert, view) ??
      (view.countryRows.isEmpty ? null : view.countryRows.first);
  final country = row?.label ?? _alertSignalSubject(alert);

  return _AlertNarrativeSet(
    signal: [
      'Le pays concerné : le pays $country concentre ${AppFormatters.percent(row?.portfolioShare ?? 0)} du portefeuille.',
      'La base d’exposition : cette juridiction porte ${row?.exposureCount ?? 0} exposition(s), avec un EAD de ${_amountMdFcfa(row?.ead ?? 0)} et un RWA de ${_amountMdFcfa(row?.rwa ?? 0)}.',
      'L’origine du signal : l’exposition géographique dépasse le seuil pays suivi en interne.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que plusieurs expositions dépendent d’une même juridiction.',
      'La lecture prudentielle : la concentration géographique fait partie des risques à piloter dans la revue interne.',
      'La sensibilité mesurée : le RW moyen atteint ${AppFormatters.percent(row?.averageRiskWeight ?? 0)} et la part RWA ressort à ${AppFormatters.percent(row?.rwaShare ?? 0)}.',
    ],
    impact: [
      'Le scénario pays : un choc souverain ou macroéconomique pourrait se transmettre aux contreparties locales.',
      'L’impact sur le capital : environ ${_amountMdFcfa((row?.rwa ?? 0) * 0.09)} de capital indicatif est exposé à ce pays.',
      'L’effet portefeuille : la diversification baissera si la croissance reste concentrée sur $country.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur le plafond pays et le stress souverain.',
      'L’arbitrage attendu : les entrées non compensées par d’autres juridictions doivent être limitées.',
      'La condition d’acceptation : l’effet pays doit être documenté avant toute nouvelle exposition significative.',
    ],
    action: [
      'Le plafond pays : il faut appliquer ${_primaryMeasure(band)} aux nouveaux dossiers.',
      'Le stress souverain : l’EAD, le RWA et les défauts doivent être testés sous scénario défavorable.',
      'Le plan d’exécution : la production doit être rééquilibrée vers des pays moins concentrés.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le poids pays et les expositions associées.',
      'Les indicateurs suivis : la part portefeuille, la part RWA, le RW moyen et les nouveaux engagements doivent être rapprochés.',
      'La preuve de gouvernance : la validation risque, le stress test et la décision de limite doivent être tracés.',
    ],
  );
}

_AlertNarrativeSet _rwaNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final rows = view.rwaCounterpartyRows.take(5).toList(growable: false);
  final topFiveRwa = rows.fold<double>(0.0, (sum, item) => sum + item.rwa);
  final share = view.totalRwa <= 0 ? 0.0 : topFiveRwa / view.totalRwa;
  final leader = rows.isEmpty ? null : rows.first;

  return _AlertNarrativeSet(
    signal: [
      'Le RWA concentré : les ${rows.length} premières contreparties portent ${AppFormatters.percent(share)} du RWA crédit.',
      'L’exposition dominante : ${leader?.counterpartyName ?? 'N/D'} porte à elle seule ${_amountMdFcfa(leader?.rwa ?? 0)} de RWA.',
      'L’origine du signal : le capital réglementaire est concentré sur un nombre réduit d’expositions.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que la consommation de capital dépend de peu d’expositions.',
      'La lecture prudentielle : les RWA doivent rester traçables par exposition et par facteur de risque.',
      'La sensibilité mesurée : le top 5 porte ${_amountMdFcfa(topFiveRwa)} sur un RWA crédit de ${_amountMdFcfa(view.totalRwa)}.',
    ],
    impact: [
      'L’impact sur le capital : environ ${_amountMdFcfa(topFiveRwa * 0.09)} de capital indicatif dépend du top 5.',
      'L’effet portefeuille : une erreur de rating, de pondération ou de garantie pèserait fortement sur le ratio.',
      'La résilience attendue : l’effet de diversification restera faible si les expositions RWA restent dominantes.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur les expositions les plus consommatrices de capital.',
      'L’arbitrage attendu : les ratings, les garanties reconnues et le rendement prudentiel doivent être revus.',
      'La condition d’acceptation : les actifs qui réduisent le RWA sans déplacer le risque doivent être prioritaires.',
    ],
    action: [
      'L’optimisation RWA : il faut appliquer ${_primaryMeasure(band)} aux expositions dominantes.',
      'Les leviers disponibles : le collatéral éligible, les sûretés opposables, les garanties ou la réduction nette doivent être étudiés.',
      'Le plan d’exécution : les actions doivent être classées par gain RWA, coût commercial et délai.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le top 5 RWA et les changements de pondération.',
      'Les indicateurs suivis : le RWA, l’EAD, le RW moyen, le rating, la garantie et la contribution au capital doivent être rapprochés.',
      'La preuve de calcul : le résultat avant et après arbitrage prudentiel doit être conservé.',
    ],
  );
}

_AlertNarrativeSet _hhiNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  return _AlertNarrativeSet(
    signal: [
      'L’indice HHI : il atteint ${view.hhi.toStringAsFixed(0)} et traduit une granularité ${view.hhiBadge.toLowerCase()}.',
      'La base analysée : le portefeuille contient ${view.counterpartyRows.length} contreparties suivies.',
      'L’origine du signal : les grandes expositions portent un poids élevé, notamment ${view.topCounterpartyName}.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que la diversification globale se dégrade.',
      'La lecture prudentielle : le capital standard ne capture pas toujours toute la vulnérabilité des portefeuilles peu granulaires.',
      'La sensibilité mesurée : la première contrepartie pèse ${AppFormatters.percent(view.topCounterpartyShare)} et le premier secteur pèse ${AppFormatters.percent(view.topSectorShare)}.',
    ],
    impact: [
      'L’effet portefeuille : la résilience baisse si plusieurs grands débiteurs se dégradent en même temps.',
      'L’impact sur le capital : le RWA crédit de ${_amountMdFcfa(view.totalRwa)} dépend d’une base peu dispersée.',
      'Le pilotage attendu : une limite de concentration complète doit compléter le suivi du RWA.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur le seuil HHI et l’appétit de concentration.',
      'L’arbitrage attendu : les grandes expositions doivent être abaissées ou les limites d’entrée doivent être renforcées.',
      'La condition d’acceptation : le top 10 ne doit pas augmenter sans compensation de diversification.',
    ],
    action: [
      'La diversification attendue : il faut appliquer ${_primaryMeasure(band)} aux plus fortes expositions.',
      'Les leviers disponibles : les nouveaux noms, la syndication, les remboursements ciblés ou les garanties renforcées doivent être utilisés.',
      'Le plan d’exécution : une trajectoire de baisse graduelle du HHI doit être suivie.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le HHI et le poids des grandes expositions.',
      'Les indicateurs suivis : le HHI, le top 1, le top 3, le top secteur, le top pays et le RWA concentré doivent être rapprochés.',
      'La preuve de gouvernance : les décisions qui améliorent ou dégradent la granularité doivent être tracées.',
    ],
  );
}

_AlertNarrativeSet _growthNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final previous =
      view.trends.length < 2 ? null : view.trends[view.trends.length - 2];
  final current = view.trends.isEmpty ? null : view.trends.last;
  final growth = previous == null || previous.ead <= 0 || current == null
      ? 0.0
      : (current.ead - previous.ead) / previous.ead;

  return _AlertNarrativeSet(
    signal: [
      'La croissance observée : l’EAD progresse de ${AppFormatters.percent(growth)} sur la dernière période.',
      'La base de comparaison : l’EAD courant atteint ${_amountMdFcfa(current?.ead ?? view.totalEad)} contre ${_amountMdFcfa(previous?.ead ?? 0)} sur la période précédente.',
      'L’origine du signal : les engagements augmentent rapidement avant la stabilisation complète des limites.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que la dynamique d’entrée accélère.',
      'La lecture prudentielle : la revue interne doit prévenir l’accumulation rapide de risques corrélés.',
      'La sensibilité mesurée : le RWA courant atteint ${_amountMdFcfa(current?.rwa ?? view.totalRwa)} et le NPL ressort à ${AppFormatters.percent(current?.npl ?? view.quality.nplRatio)}.',
    ],
    impact: [
      'L’effet portefeuille : la croissance peut masquer une concentration client, secteur ou pays.',
      'L’impact sur le capital : la consommation de RWA augmente si les nouveaux dossiers sont fortement pondérés.',
      'La qualité d’entrée : le rating, la PD, la LGD et les garanties doivent être contrôlés avant l’extension.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur les nouveaux tickets et la qualité d’entrée.',
      'L’arbitrage attendu : seuls les flux qui respectent les limites et le rendement RWA doivent être acceptés.',
      'La condition d’acceptation : chaque hausse doit être rattachée à une origine client, secteur, pays ou produit.',
    ],
    action: [
      'La production nouvelle : il faut appliquer ${_primaryMeasure(band)} aux engagements non validés.',
      'Le contrôle préalable : le rating, les garanties, le statut défaut et l’effet RWA doivent être vérifiés avant tirage.',
      'Le plan d’exécution : les nouveaux dossiers qui dégradent les concentrations existantes doivent être isolés.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre les entrées, les sorties et les variations de RWA.',
      'Les indicateurs suivis : la croissance EAD, la variation RWA, le NPL, le HHI et la concentration par segment doivent être rapprochés.',
      'La preuve de gouvernance : le rapprochement entre les flux commerciaux et les limites de risque doit être conservé.',
    ],
  );
}

_AlertNarrativeSet _genericNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  return _AlertNarrativeSet(
    signal: [
      'Le signal détecté : ${_compactAlertHeaderTitle(alert.message)}.',
      'La base analysée : le portefeuille porte un EAD de ${_amountMdFcfa(view.totalEad)} et un RWA de ${_amountMdFcfa(view.totalRwa)}.',
      'L’origine probable : ${alert.recommendation}',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} selon le seuil détecté.',
      'La lecture du risque : le signal doit être rapproché des limites internes et du capital mobilisé.',
      'Le cadre prudentiel : le pilotage des expositions concentrées doit rester documenté.',
    ],
    impact: [
      'L’effet portefeuille : l’impact sur la diversification, la qualité et le capital doit être vérifié.',
      'L’impact sur le capital : la contribution RWA liée au signal doit être isolée.',
      'La qualité crédit : la PD, la LGD, les défauts et les garanties disponibles doivent être rapprochés.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} avec une justification documentée.',
      'L’arbitrage attendu : l’exposition doit être réduite, couverte ou acceptée sous condition.',
      'La condition d’acceptation : l’exposition ne doit pas être étendue sans validation risque.',
    ],
    action: [
      'La mesure opérationnelle : il faut appliquer ${_primaryMeasure(band)} jusqu’à stabilisation.',
      'Les leviers disponibles : la limite, la garantie, le rating, l’échéancier ou la réduction nette doivent être examinés.',
      'Le plan d’exécution : un responsable et une date cible doivent être définis.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le signal et les seuils.',
      'Les indicateurs suivis : l’exposition résiduelle, le RWA, les garanties et la décision comité doivent être rapprochés.',
      'La preuve de gouvernance : la décision et le retour sous seuil doivent être conservés.',
    ],
  );
}

ConcentrationExposureRow? _matchingCounterparty(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
) {
  final messageKey = _alertSearchKey(alert.message);
  final subjectKey = _alertSearchKey(_alertSignalSubject(alert));
  for (final row in view.counterpartyRows) {
    final rowKey = _alertSearchKey(row.counterpartyName);
    if (messageKey.contains(rowKey) ||
        subjectKey.contains(rowKey) ||
        rowKey.contains(subjectKey)) {
      return row;
    }
  }
  return null;
}

SectorConcentrationRow? _matchingSector(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
) {
  final messageKey = _alertSearchKey(alert.message);
  final subjectKey = _alertSearchKey(_alertSignalSubject(alert));
  for (final row in view.sectorRows) {
    final rowKey = _alertSearchKey(row.sector);
    if (messageKey.contains(rowKey) ||
        subjectKey.contains(rowKey) ||
        rowKey.contains(subjectKey)) {
      return row;
    }
  }
  return null;
}

ConcentrationBreakdownRow? _matchingCountry(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
) {
  final messageKey = _alertSearchKey(alert.message);
  final subjectKey = _alertSearchKey(_alertSignalSubject(alert));
  for (final row in view.countryRows) {
    final rowKey = _alertSearchKey(row.label);
    if (messageKey.contains(rowKey) ||
        subjectKey.contains(rowKey) ||
        rowKey.contains(subjectKey)) {
      return row;
    }
  }
  return null;
}

List<ConcentrationExposureDetail> _detailsForCounterparty(
  _ConcentrationViewModel view,
  String counterpartyName,
) {
  final key = _alertSearchKey(counterpartyName);
  return view.exposureDetails
      .where((item) => _alertSearchKey(item.counterpartyName) == key)
      .toList(growable: false);
}

double _weightedCrmCoverage(List<ConcentrationExposureDetail> details) {
  final totalEad = details.fold<double>(0.0, (sum, item) => sum + item.ead);
  if (totalEad <= 0) {
    return 0;
  }
  return details.fold<double>(
        0.0,
        (sum, item) => sum + item.crmCoverageRatio * item.ead,
      ) /
      totalEad;
}

String _dominantRating(List<ConcentrationExposureDetail> details) {
  if (details.isEmpty) {
    return 'N/D';
  }
  final totals = <String, double>{};
  for (final item in details) {
    totals.update(
      item.rating,
      (value) => value + item.ead,
      ifAbsent: () => item.ead,
    );
  }
  final sorted = totals.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return sorted.first.key;
}

String _amountMdFcfa(double value) {
  return '${_amountMd(value)} ${_amountUnitFcfaLabel()}';
}

String _alertSearchKey(String value) {
  return value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('ô', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _decisionTempo(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'une décision immédiate',
    _AlertSeverityBand.intermediate => 'une décision de réduction progressive',
    _AlertSeverityBand.watch => 'une surveillance renforcée',
  };
}

String _primaryMeasure(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'le blocage des hausses non couvertes',
    _AlertSeverityBand.intermediate =>
      'le conditionnement des nouvelles entrées',
    _AlertSeverityBand.watch => 'le maintien sous seuil de vigilance',
  };
}

String _controlCadence(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'un suivi hebdomadaire',
    _AlertSeverityBand.intermediate => 'un suivi mensuel',
    _AlertSeverityBand.watch => 'une revue à chaque clôture',
  };
}

class _KpiInfographicStep {
  const _KpiInfographicStep({
    required this.title,
    required this.color,
    required this.icon,
  });

  final String title;
  final Color color;
  final IconData icon;
}

const List<_KpiInfographicStep> _alertsKpiSteps = [
  _KpiInfographicStep(
    title: 'SIGNAL',
    color: Color(0xFF263B52),
    icon: CupertinoIcons.exclamationmark_shield_fill,
  ),
  _KpiInfographicStep(
    title: 'RISQUE',
    color: Color(0xFFFF8500),
    icon: CupertinoIcons.gauge,
  ),
  _KpiInfographicStep(
    title: 'IMPACT',
    color: Color(0xFF94D600),
    icon: CupertinoIcons.chart_bar_alt_fill,
  ),
  _KpiInfographicStep(
    title: 'DÉCISION',
    color: Color(0xFF11B9B7),
    icon: CupertinoIcons.flag,
  ),
  _KpiInfographicStep(
    title: 'ACTION',
    color: Color(0xFF38A4E8),
    icon: CupertinoIcons.checkmark_rectangle,
  ),
  _KpiInfographicStep(
    title: 'CONTRÔLE',
    color: Color(0xFFB300C8),
    icon: CupertinoIcons.shield_lefthalf_fill,
  ),
];

class _AlertsKpiInfographic extends StatefulWidget {
  const _AlertsKpiInfographic({
    required this.alerts,
    required this.view,
  });

  final List<ConcentrationAlert> alerts;
  final _ConcentrationViewModel view;

  @override
  State<_AlertsKpiInfographic> createState() => _AlertsKpiInfographicState();
}

class _AlertsKpiInfographicState extends State<_AlertsKpiInfographic> {
  var _selectedAlertIndex = 0;

  @override
  void didUpdateWidget(covariant _AlertsKpiInfographic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAlertIndex >= widget.alerts.length) {
      _selectedAlertIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankedAlerts = _rankedAlerts(widget.alerts);
    final safeSelectedIndex = rankedAlerts.isEmpty
        ? 0
        : math.min(_selectedAlertIndex, rankedAlerts.length - 1);
    final selectedAlert =
        rankedAlerts.isEmpty ? null : rankedAlerts[safeSelectedIndex];
    final alertTitle = _selectedAlertHeaderTitle(selectedAlert);
    final narratives = _alertKpiNarratives(selectedAlert, widget.view);

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 900.0;
        const infographicHeight = 440.0;
        final width = math.max(minWidth, constraints.maxWidth);
        final surface = Theme.of(context).cardColor;

        final content = SizedBox(
          width: width,
          height: infographicHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(_concentrationRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.055),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _AlertsKpiInfographicCanvas(
              width: width,
              alertCount: widget.alerts.length,
              alertTitle: alertTitle,
              alerts: rankedAlerts,
              selectedAlertIndex: safeSelectedIndex,
              onAlertSelected: (index) {
                if (index == _selectedAlertIndex) {
                  return;
                }
                setState(() => _selectedAlertIndex = index);
              },
              narratives: narratives,
            ),
          ),
        );

        if (constraints.maxWidth >= minWidth) {
          return content;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: content,
        );
      },
    );
  }
}

class _AlertsKpiInfographicCanvas extends StatelessWidget {
  const _AlertsKpiInfographicCanvas({
    required this.width,
    required this.alertCount,
    required this.alertTitle,
    required this.alerts,
    required this.selectedAlertIndex,
    required this.onAlertSelected,
    required this.narratives,
  });

  final double width;
  final int alertCount;
  final String alertTitle;
  final List<ConcentrationAlert> alerts;
  final int selectedAlertIndex;
  final ValueChanged<int> onAlertSelected;
  final List<List<String>> narratives;

  @override
  Widget build(BuildContext context) {
    const headerHeight = 82.0;
    const headerGap = 8.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      child: Column(
        children: [
          Center(
            child: _KpiHeaderBadge(
              width: math.min(520.0, width - 72),
              height: headerHeight,
              title: 'Alertes ($alertCount)',
              subtitle: alertTitle,
              alerts: alerts,
              selectedAlertIndex: selectedAlertIndex,
              onAlertSelected: onAlertSelected,
            ),
          ),
          const SizedBox(height: headerGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0;
                    index < _alertsKpiSteps.length;
                    index++) ...[
                  Expanded(
                    child: _KpiStepCard(
                      step: _alertsKpiSteps[index],
                      narrativeItems: narratives[index],
                      index: index < 3 ? index + 1 : index - 2,
                    ),
                  ),
                  if (index == 2)
                    const _AlertGroupDivider(topExtension: headerGap)
                  else if (index != _alertsKpiSteps.length - 1)
                    const SizedBox(width: 3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertGroupDivider extends StatelessWidget {
  const _AlertGroupDivider({required this.topExtension});

  final double topExtension;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE11D48);

    return SizedBox(
      width: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -topExtension),
              child: SizedBox(
                width: 2.4,
                height: constraints.maxHeight + topExtension,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
  }
}

class _KpiStepCard extends StatefulWidget {
  const _KpiStepCard({
    required this.step,
    required this.narrativeItems,
    required this.index,
  });

  final _KpiInfographicStep step;
  final List<String> narrativeItems;
  final int index;

  @override
  State<_KpiStepCard> createState() => _KpiStepCardState();
}

class _KpiStepCardState extends State<_KpiStepCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final surface = Color.alphaBlend(
      step.color.withValues(alpha: _hovered ? 0.075 : 0.048),
      Theme.of(context).cardColor,
    );

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = true);
      }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = false);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          border: Border.all(
            color: step.color.withValues(alpha: _hovered ? 0.34 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: step.color.withValues(alpha: _hovered ? 0.14 : 0.06),
              blurRadius: _hovered ? 14 : 9,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: step.color,
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                  ),
                  child: Icon(
                    step.icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.text,
                          fontSize: 12.7,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                ),
                Text(
                  widget.index.toString().padLeft(2, '0'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: step.color.withValues(alpha: 0.82),
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(_concentrationRadius),
                ),
                child: _KpiNarrativeList(
                  items: widget.narrativeItems,
                  color: step.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiNarrativeList extends StatelessWidget {
  const _KpiNarrativeList({
    required this.items,
    required this.color,
  });

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SizedBox(
          width: constraints.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _KpiNarrativeBullet(
                  text: items[index],
                  color: color,
                ),
                if (index != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: content,
          ),
        );
      },
    );
  }
}

class _KpiNarrativeBullet extends StatelessWidget {
  const _KpiNarrativeBullet({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colonIndex = text.indexOf(':');
    final hasLabel = colonIndex > 0;
    final label = hasLabel ? text.substring(0, colonIndex).trimRight() : '';
    final value = hasLabel ? text.substring(colonIndex + 1).trimLeft() : text;
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.text.withValues(alpha: 0.76),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.12,
          letterSpacing: 0,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5.2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: const SizedBox(width: 5.5, height: 5.5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            textAlign: TextAlign.start,
            softWrap: true,
            text: TextSpan(
              style: baseStyle,
              children: [
                if (hasLabel)
                  TextSpan(
                    text: '$label:\n',
                    style: baseStyle?.copyWith(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiHeaderBadge extends StatelessWidget {
  const _KpiHeaderBadge({
    required this.width,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.alerts,
    required this.selectedAlertIndex,
    required this.onAlertSelected,
  });

  final double width;
  final double height;
  final String title;
  final String subtitle;
  final List<ConcentrationAlert> alerts;
  final int selectedAlertIndex;
  final ValueChanged<int> onAlertSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 6, 5, 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDFDFD),
              Color(0xFFEDEDED),
            ],
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: AppColors.alertCritical,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF43113),
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4B5563),
                    fontSize: 10.6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1,
                  ),
            ),
            if (alerts.length > 1) ...[
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: SizedBox(
                      height: 16,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          children: [
                            for (var index = 0;
                                index < alerts.length;
                                index++) ...[
                              _KpiAlertSelectorChip(
                                alert: alerts[index],
                                index: index,
                                selected: index == selectedAlertIndex,
                                onSelected: onAlertSelected,
                              ),
                              if (index < alerts.length - 1)
                                const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiAlertSelectorChip extends StatelessWidget {
  const _KpiAlertSelectorChip({
    required this.alert,
    required this.index,
    required this.selected,
    required this.onSelected,
  });

  final ConcentrationAlert alert;
  final int index;
  final bool selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFFF43113) : _severityColor(alert.severity);

    return Tooltip(
      richMessage: _alertSelectorTooltipMessage(alert, index, color),
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 6),
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      preferBelow: false,
      verticalOffset: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.0 : 0.58),
              ),
            ),
            child: Text(
              '${index + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white : color,
                    fontSize: 8.1,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

InlineSpan _alertSelectorTooltipMessage(
  ConcentrationAlert alert,
  int index,
  Color color,
) {
  final title = _compactAlertHeaderTitle(alert.message);
  final severity = alert.severity.trim().isEmpty ? 'Signal' : alert.severity;
  final scope = alert.level.trim().isEmpty ? 'Concentration' : alert.level;

  return TextSpan(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 10.4,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    children: [
      TextSpan(
        text: 'Alerte ${(index + 1).toString().padLeft(2, '0')}\n',
        style: TextStyle(
          color: color,
          fontSize: 11.8,
          fontWeight: FontWeight.w900,
          height: 1.2,
        ),
      ),
      TextSpan(
        text: '$severity • $scope\n',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 9.6,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
      const TextSpan(text: '\n'),
      TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.6,
          fontWeight: FontWeight.w800,
          height: 1.32,
        ),
      ),
    ],
  );
}

int _severityRank(String severity) {
  return switch (severity.toLowerCase()) {
    'élevé' || 'eleve' => 3,
    'moyen' => 2,
    _ => 1,
  };
}

Color _severityColor(String severity) {
  return switch (severity.toLowerCase()) {
    'élevé' || 'eleve' => AppTheme.danger,
    'moyen' => AppTheme.warning,
    _ => AppTheme.success,
  };
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({
    this.message = 'Portefeuille vide',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
