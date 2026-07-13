// Écran de génération du rapport global — synthèse consolidée du Dashboard,
// du Risque Crédit, du Risque de Marché et du Risque Opérationnel dans un
// même document PDF réglementaire (UMOA/BCEAO).
import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../expositions/models/exposition_models.dart';
import '../../risque_marche/repositories/foreign_exchange_repository.dart';
import '../../risque_marche/services/market_data_import_store.dart';
import '../../risque_marche/services/market_risk_aggregation_service.dart';
import '../../risque_operationnel/models/ro_models.dart';

// ─── Constantes couleur ───────────────────────────────────────────────────
// Dupliquées depuis risque_operationnel_screen.dart (constantes privées à ce
// fichier là-bas, sans lien de dépendance entre les deux modules).
const _kBlue = AppTheme.accent;
const _kSuccess = AppTheme.success;
const _kDanger = AppTheme.danger;
const _kMuted = AppTheme.muted;

// ─── Articles réglementaires ──────────────────────────────────────────────
// Dupliqué depuis risque_operationnel_screen.dart pour les mêmes raisons.
const _artExplanations = <String, String>{
  'Art. 313':
      'Gestion du risque opérationnel — dispositif d\'identification, de mesure,\n'
      'de surveillance et de contrôle obligatoire (Instruction UMOA).\n\n'
      'Mesure du risque (matrice 5×5) :\n'
      '  Score = Impact × Probabilité   (échelle 1 – 5)\n'
      '  Zone rouge : Score ≥ 15   |   Zone orange : 8 – 14\n'
      '  Piliers : Identification → Mesure → Surveillance → Contrôle',
  'Art. 313.b':
      'Déclaration des incidents opérationnels — tout incident significatif\n'
      'doit être documenté (cause racine, pertes) avec suivi formel imposé.\n\n'
      'Calcul de la perte nette :\n'
      '  Perte nette = Perte brute − Récupérations\n'
      '  Récupérations : assurance + provisions + reversements\n'
      '  Délai de déclaration : ≤ J+5 ouvrés après détection',
  'Art. 313.c':
      'Plans d\'actions correctives et préventives — documentés, assignés\n'
      'à un responsable avec échéance et taux d\'avancement obligatoires.\n\n'
      'Indicateurs de suivi :\n'
      '  Avancement (%) = (Actions terminées / Actions totales) × 100\n'
      '  Taux global = Σ avancement_i / n   (n = nb plans actifs)\n'
      '  Retard = Date_échéance − Date_aujourd\'hui  < 0 → en retard',
  'Art. 314':
      'Contrôle interne — dispositif permanent et périodique obligatoire.\n'
      'Conservation des documents : ≥ 7 ans (exigence UMOA).\n\n'
      'Efficacité du contrôle :\n'
      '  Taux de conformité = (Contrôles conformes / Contrôles réalisés) × 100\n'
      '  Couverture = Nb processus contrôlés / Nb processus totaux × 100\n'
      '  Fréquences : permanent (quotidien/hebdo) | périodique (mensuel/annuel)',
  'Art. 89':
      'Calcul des RWA opérationnels — méthode Indicateur de Base (BIA).\n\n'
      'Formule BIA :\n'
      '  Capital minimal = α × PNBmoy₃\n'
      '  α = 15 %   (coefficient réglementaire BCEAO)\n'
      '  PNBmoy₃ = Σ PNBᵢ (positifs) / n   sur 3 derniers exercices\n'
      '  RWA_opérationnel = Capital minimal ÷ 9 %   (facteur 11,111111)',
  'Art. 301/307':
      'Exigences minimales en fonds propres (dispositif prudentiel BCEAO).\n\n'
      'Ratios réglementaires :\n'
      '  Ratio Tier 1 = Fonds propres de base / RWA total  ≥ 5 %\n'
      '  Ratio global = Fonds propres totaux / RWA total   ≥ 8 %\n'
      '  RWA total = RWA_crédit + RWA_marché + RWA_opérationnel\n'
      '  Coussin de conservation : + 2,5 % des RWA (si applicable)',
  'Art. 545':
      'Stress testing — simulations de scénarios de crise pour évaluer\n'
      'la résilience du dispositif de gestion des risques.\n\n'
      'Scénarios types et formule d\'impact :\n'
      '  S1 : Optimiste  |  S2 : Neutre  |  S3 : Pessimiste  |  S4 : Crise\n'
      '  Impact net = Pertes simulées − (Provisions + Couverture assurance)\n'
      '  Résilience = Fonds propres disponibles − Pertes simulées  ≥ 0\n'
      '  Ratio de résistance = FP après choc / RWA stressés  ≥ seuil',
  'Art. 546':
      'Rapport annuel sur le dispositif de gestion des risques,\n'
      'transmis à la Commission Bancaire de l\'UMOA.\n\n'
      'Indicateurs clés à reporter :\n'
      '  • RWA total = RWA_crédit + RWA_marché + RWA_opérationnel\n'
      '  • Ratios réglementaires (CET1, Tier 1, solvabilité, levier)\n'
      '  • Pertes totales nettes = Σ (Perte brute − Récupérations)\n'
      '  • Résultats stress tests : ΔFP sous S3 et S4',
};

List<String> _extractArtRefs(String text) =>
    RegExp(r'Art\.\s*\d+[\w\./]*').allMatches(text).map((m) => m.group(0)!).toList();

String _stripArtRefs(String text) =>
    text.replaceAll(RegExp(r'\s*\(Art\..*?\)'), '').trim();

Widget _artInfo(String artRef) {
  final explanation = _artExplanations[artRef];
  if (explanation == null) return const SizedBox.shrink();
  return ExcludeSemantics(
    child: Tooltip(
      excludeFromSemantics: true,
      message: '$artRef\n$explanation',
      preferBelow: false,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 8),
      textStyle: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Icon(Icons.info_outline_rounded, size: 14, color: _kBlue),
    ),
  );
}

Widget _dropdown<T>(String label, T? value, List<T> items, void Function(T?) onChanged,
    {bool required = false, IconData? icon, String? hint}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 12, color: _kBlue), const SizedBox(width: 5)],
          Text(required ? '$label *' : label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: _kMuted, letterSpacing: 0.1)),
        ]),
        const SizedBox(height: 5),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e.toString(), style: const TextStyle(fontSize: 13.5),
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
          validator: required ? (v) => v == null ? 'Champ requis' : null : null,
        ),
      ],
    ),
  );
}

TableRow _tableHeader(List<String> headers) {
  return TableRow(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF2A518A), Color(0xFF23477A)],
      ),
      border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
    ),
    children: headers.map((h) => TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Text(h,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10,
            color: Color(0xFFF5F8FF), letterSpacing: 0.18)),
      ),
    )).toList(),
  );
}

/// Lit la valeur d'une métrique du dashboard par sa clé, 0 si absente.
double _metricValue(List<DashboardMetric> metrics, String key) {
  for (final m in metrics) {
    if (m.key == key) return m.value;
  }
  return 0.0;
}

// ─── Ecran ─────────────────────────────────────────────────────────────────

class ReportingGlobalScreen extends StatefulWidget {
  const ReportingGlobalScreen({super.key, required this.api});
  final RwaApiService api;
  @override
  State<ReportingGlobalScreen> createState() => _ReportingGlobalScreenState();
}

class _ReportingGlobalScreenState extends State<ReportingGlobalScreen> {
  String _periode = 'Mensuel';
  String _destinataire = 'Organe exécutif';
  bool _generating = false;
  String? _savedFileName;
  final _dateDebutCtrl = TextEditingController();
  final _dateFinCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyQuickPeriod('Mensuel');
  }

  @override
  void dispose() {
    _dateDebutCtrl.dispose();
    _dateFinCtrl.dispose();
    super.dispose();
  }

  void _applyQuickPeriod(String periode) {
    final now = DateTime.now();
    final DateTime debut;
    switch (periode) {
      case 'Trimestriel':
        final q = ((now.month - 1) ~/ 3) * 3 + 1;
        debut = DateTime(now.year, q, 1);
      case 'Semestriel':
        debut = DateTime(now.year, now.month <= 6 ? 1 : 7, 1);
      case 'Annuel':
        debut = DateTime(now.year, 1, 1);
      default:
        debut = DateTime(now.year, now.month, 1);
    }
    setState(() {
      _periode = periode;
      _dateDebutCtrl.text = debut.toIso8601String().substring(0, 10);
      _dateFinCtrl.text   = now.toIso8601String().substring(0, 10);
    });
  }

  String _fmtDisp(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }

  String get _periodeLabel {
    final d = _dateDebutCtrl.text;
    final f = _dateFinCtrl.text;
    if (d.isNotEmpty && f.isNotEmpty) return '${_fmtDisp(d)} — ${_fmtDisp(f)}';
    return _periode;
  }

  // ─── Risque de Marché : accès direct aux singletons du module, sans passer
  // par RisqueMarcheScreen (mêmes sources que l'écran Risque de Marché,
  // voir risque_marche_screen.dart:30398-30417) ─────────────────────────────

  Future<MarketPrudentialCapitalResult> _computeMarketResult() async {
    await MarketDataImportStore.instance.initialized;
    await InMemoryForeignExchangeRepository().initialized;
    final snapshot = MarketDataImportStore.instance.snapshotNotifier.value;
    final records = [
      ...?snapshot.datasetFor(MarketPortfolioType.bonds)?.records,
      ...?snapshot.datasetFor(MarketPortfolioType.equities)?.records,
    ];
    final fxPositions = InMemoryForeignExchangeRepository().currentPositions;
    final base = calculateMarketPrudentialCapital(records: records);
    return applyRealForeignExchangeRisk(base, fxPositions);
  }

  // ─── Génération + dialog de sauvegarde ──────────────────────────────────────

  Future<void> _generateAndSave() async {
    setState(() { _generating = true; _savedFileName = null; });
    try {
      // 1. Récupérer les données de tous les domaines en parallèle
      final results = await Future.wait([
        widget.api.fetchRoDashboard(),
        widget.api.fetchRoIncidents(),
        widget.api.fetchRoKri(),
        widget.api.fetchRoRisques(),
        widget.api.fetchRoControles(),
        widget.api.fetchRoPlans(),
        widget.api.fetchDashboard(),
        widget.api.fetchExpositionsModule(),
        _computeMarketResult(),
      ]);
      final dash = results[0] as RoDashboardData;
      final kriData = results[2] as RoKriModuleData;
      final risques = results[3] as List<RoRisque>;
      final controles = results[4] as List<RoControle>;
      final plans = results[5] as List<RoPlan>;
      final globalDash = results[6] as DashboardSnapshot;
      final creditSummary = (results[7] as ExposureModuleData).summary;
      final marketResult = results[8] as MarketPrudentialCapitalResult;

      final debut = _dateDebutCtrl.text.isNotEmpty ? DateTime.tryParse(_dateDebutCtrl.text) : null;
      final fin   = _dateFinCtrl.text.isNotEmpty   ? DateTime.tryParse(_dateFinCtrl.text)   : null;
      final incidents = (results[1] as List<RoIncident>).where((i) {
        try {
          final d = DateTime.parse(i.dateOccurrence);
          if (debut != null && d.isBefore(debut)) return false;
          if (fin   != null && d.isAfter(fin.add(const Duration(days: 1)))) return false;
          return true;
        } catch (_) { return true; }
      }).toList();

      if (!mounted) return;

      // 2. Construire le PDF
      final now = DateTime.now();
      final bytes = await _buildPdf(
        dash, incidents, kriData.kriList, risques, controles, plans,
        globalDash, creditSummary, marketResult, now,
      );

      if (!mounted) return;

      // 3. Dialog de sauvegarde natif Windows
      final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final location = await getSaveLocation(
        suggestedName: 'rapport_global_${_periode.toLowerCase()}_$ts.pdf',
        acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
      );
      if (!mounted || location == null) return;

      // 4. Enregistrer
      final saved = await saveBytesAtLocation(location, bytes, requiredExtension: '.pdf');
      if (!mounted) return;

      final fileName = saved.path.split(RegExp(r'[\\/]')).last;
      setState(() => _savedFileName = fileName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _kSuccess,
        content: Text('Rapport enregistré : $fileName'),
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _kDanger,
          content: Text('Erreur : $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ─── Construction du document PDF ───────────────────────────────────────────

  Future<Uint8List> _buildPdf(
    RoDashboardData dash,
    List<RoIncident> incidents,
    List<RoKriView> kris,
    List<RoRisque> risques,
    List<RoControle> controles,
    List<RoPlan> plans,
    DashboardSnapshot globalDash,
    ExposureSummary creditSummary,
    MarketPrudentialCapitalResult marketResult,
    DateTime now,
  ) async {
    final doc = pw.Document();
    const headerBg  = PdfColor.fromInt(0xFF0F2544);
    const accentBg  = PdfColor.fromInt(0xFF2563EB);
    const borderCol = PdfColor.fromInt(0xFFE5E7EB);
    const mutedCol  = PdfColor.fromInt(0xFF6B7280);

    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    const mutedStyle  = pw.TextStyle(fontSize: 8.5, color: mutedCol);
    const bodyStyle   = pw.TextStyle(fontSize: 9);
    final headerStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    pw.Widget sectionBanner(String text) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(color: headerBg, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );

    pw.Widget kpiGrid(List<(String label, String value)> items) => pw.Row(
      children: items.map((item) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderCol), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(item.$1, style: mutedStyle),
            pw.SizedBox(height: 3),
            pw.Text(item.$2, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: headerBg)),
          ]),
        ),
      )).toList(),
    );

    pw.Widget table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: headerStyle,
        headerDecoration: const pw.BoxDecoration(color: accentBg),
        cellStyle: bodyStyle,
        border: pw.TableBorder.all(color: borderCol, width: 0.4),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      );

    // Décomposition du capital requis marché — taux / actions / change (FX),
    // même formule REA = Capital × 1/9% que le reste de l'outil.
    const reaMultiplier = 1 / 0.09;
    final marketTotal = marketResult.capitalRequirement;
    String marketShare(double component) =>
        marketTotal > 0 ? '${(component / marketTotal * 100).toStringAsFixed(1)} %' : '0,0 %';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Rapport Risque Global -- $_periodeLabel', style: mutedStyle),
          pw.Text('$_destinataire  ·  $dateStr', style: mutedStyle),
        ]),
      ),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Confidentiel -- Usage interne', style: mutedStyle),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: mutedStyle),
        ]),
      ),
      build: (_) => [

        // ── COUVERTURE ────────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(22),
          decoration: pw.BoxDecoration(color: headerBg, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RAPPORT DE RISQUE GLOBAL',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 6),
            pw.Text('Période : $_periodeLabel  ·  Destinataire : $_destinataire',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            pw.Text('Date de génération : $dateStr',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            pw.SizedBox(height: 4),
            pw.Text('Art. 301/307, 313, 313.b, 313.c, 314, 545, 546 -- UMOA/BCEAO',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          ]),
        ),
        pw.SizedBox(height: 16),

        // ── 1. SYNTHÈSE GLOBALE ──────────────────────────────────────────────
        sectionBanner('1. SYNTHÈSE GLOBALE  '),
        kpiGrid([
          ('RWA Total',          AppFormatters.currency(_metricValue(globalDash.metrics, 'rwa'))),
          ('RWA Crédit',         AppFormatters.currency(_metricValue(globalDash.metrics, 'rwa_credit'))),
          ('RWA Marché',         AppFormatters.currency(_metricValue(globalDash.metrics, 'rwa_market'))),
          ('RWA Opérationnel',   AppFormatters.currency(_metricValue(globalDash.metrics, 'rwa_op'))),
          ('Capital Total (FPE)', AppFormatters.currency(_metricValue(globalDash.metrics, 'capital'))),
        ]),
        kpiGrid([
          ('Ratio CET1',           AppFormatters.percent(_metricValue(globalDash.metrics, 'cet1_ratio'))),
          ('Ratio Tier 1',         AppFormatters.percent(_metricValue(globalDash.metrics, 'tier1_ratio'))),
          ('Ratio de solvabilité', AppFormatters.percent(_metricValue(globalDash.metrics, 'solvabilite'))),
          ('Ratio de levier',      AppFormatters.percent(_metricValue(globalDash.metrics, 'ratio_levier'))),
        ]),
        pw.SizedBox(height: 6),

        // ── 2. RISQUE CRÉDIT ─────────────────────────────────────────────────
        sectionBanner('2. RISQUE CRÉDIT  '),
        kpiGrid([
          ('Nombre d\'expositions', creditSummary.totalExpositions.toStringAsFixed(0)),
          ('EAD total',             AppFormatters.currency(creditSummary.totalEad)),
          ('RWA Crédit',            AppFormatters.currency(creditSummary.totalRwa)),
          ('Capital requis',        AppFormatters.currency(creditSummary.totalCapital)),
        ]),
        pw.SizedBox(height: 6),
        if ((globalDash.top10Exposures ?? const []).isEmpty)
          pw.Text('Aucune exposition enregistrée.', style: mutedStyle)
        else
          table(
            ['Contrepartie', 'Secteur', 'Pays', 'Rating', 'Exposition', 'RWA', 'Statut'],
            (globalDash.top10Exposures ?? const []).take(5).map((e) => [
              e.counterparty, e.sector, e.country, e.rating,
              AppFormatters.currency(e.exposureAmount),
              AppFormatters.currency(e.rwaAmount),
              e.status,
            ]).toList(),
          ),
        pw.SizedBox(height: 12),

        // ── 3. RISQUE DE MARCHÉ ──────────────────────────────────────────────
        sectionBanner('3. RISQUE DE MARCHÉ  '),
        kpiGrid([
          ('RWA Marché',           AppFormatters.currency(marketResult.marketRwa)),
          ('Capital requis marché', AppFormatters.currency(marketResult.capitalRequirement)),
        ]),
        pw.SizedBox(height: 6),
        table(
          ['Composante', 'Capital requis', 'RWA', '% du total'],
          [
            [
              'Taux d\'intérêt',
              AppFormatters.currency(marketResult.interestRateRisk),
              AppFormatters.currency(marketResult.interestRateRisk * reaMultiplier),
              marketShare(marketResult.interestRateRisk),
            ],
            [
              'Actions',
              AppFormatters.currency(marketResult.equityRisk),
              AppFormatters.currency(marketResult.equityRisk * reaMultiplier),
              marketShare(marketResult.equityRisk),
            ],
            [
              'Change (FX)',
              AppFormatters.currency(marketResult.foreignExchangeRisk),
              AppFormatters.currency(marketResult.foreignExchangeRisk * reaMultiplier),
              marketShare(marketResult.foreignExchangeRisk),
            ],
            [
              'Total',
              AppFormatters.currency(marketResult.capitalRequirement),
              AppFormatters.currency(marketResult.marketRwa),
              '100,0 %',
            ],
          ],
        ),
        pw.SizedBox(height: 12),

        // ── 4. SYNTHÈSE GÉNÉRALE — RISQUE OPÉRATIONNEL ───────────────────────
        sectionBanner('4. SYNTHÈSE GÉNÉRALE — RISQUE OPÉRATIONNEL  '),
        kpiGrid([
          ('Exigence fonds propres (K)', AppFormatters.currency(dash.widget1.exigenceFondsPropres)),
          ('RWA risque opérationnel',    AppFormatters.currency(dash.widget1.aprRisqueOp)),
          ('Statut réglementaire',       dash.widget1.statutReglementaire),
          ('Incidents (mois)',           '${dash.widget2.totalIncidentsMois}'),
          ('Non clôturés',              '${dash.widget2.incidentsNonClos}'),
          ('Actions en retard',         '${dash.widget3.actionsEnRetard}'),
        ]),
        pw.SizedBox(height: 12),

        // ── 5. INCIDENTS ET PERTES ───────────────────────────────────────────
        sectionBanner('5. INCIDENTS ET PERTES  '),
        kpiGrid([
          ('Pertes brutes totales', AppFormatters.currency(incidents.fold(0.0, (s, i) => s + i.perteBrute))),
          ('Pertes nettes totales', AppFormatters.currency(incidents.fold(0.0, (s, i) => s + i.perteNette))),
          ('Incidents significatifs', '${incidents.where((i) => i.significatif).length}'),
        ]),
        pw.SizedBox(height: 6),
        if (incidents.isEmpty)
          pw.Text('Aucun incident enregistré.', style: mutedStyle)
        else ...[
          table(
            ['Référence', 'Date', 'Ligne métier', 'Perte brute', 'Perte nette', 'Statut'],
            incidents.take(15).map((i) => [
              i.reference, i.dateOccurrence, i.ligneMetier,
              AppFormatters.currency(i.perteBrute),
              AppFormatters.currency(i.perteNette),
              i.statut,
            ]).toList(),
          ),
          if (incidents.length > 15)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text('... et ${incidents.length - 15} autres incidents.', style: mutedStyle),
            ),
        ],
        pw.SizedBox(height: 12),

        // ── 6. INDICATEURS CLÉS (KRI) ────────────────────────────────────────
        sectionBanner('6. INDICATEURS CLÉS DE RISQUE  '),
        if (kris.isEmpty)
          pw.Text('Aucun KRI configuré.', style: mutedStyle)
        else
          table(
            ['KRI', 'Unité', 'Seuil alerte', 'Dernière valeur', 'Dernière date', 'Statut'],
            kris.map((k) => [
              k.definition.nom, k.definition.unite,
              k.definition.sens == 'superieur' ? '> ${k.definition.seuilAlerte}' : '< ${k.definition.seuilAlerte}',
              k.derniereValeur != null ? '${k.derniereValeur!.toStringAsFixed(1)} ${k.definition.unite}' : 'N/A',
              k.derniereDate ?? 'N/A',
              k.statut.toUpperCase(),
            ]).toList(),
          ),
        pw.SizedBox(height: 12),

        // ── 7. CARTOGRAPHIE DES RISQUES ──────────────────────────────────────
        sectionBanner('7. CARTOGRAPHIE DES RISQUES  '),
        if (risques.isEmpty)
          pw.Text('Aucun risque enregistré.', style: mutedStyle)
        else
          table(
            ['Risque', 'Catégorie', 'Prob.', 'Impact', 'Niveau brut', 'Niveau résiduel'],
            risques.map((r) => [
              r.nom, r.categorie,
              '${r.probabilite}/5', '${r.impact}/5',
              r.niveauLabel, r.niveauResiduel.toStringAsFixed(1),
            ]).toList(),
          ),
        pw.SizedBox(height: 12),

        // ── 8. CONTRÔLES INTERNES ────────────────────────────────────────────
        sectionBanner('8. CONTRÔLES INTERNES  '),
        if (controles.isNotEmpty) ...[
          kpiGrid([
            ('Total contrôles', '${controles.length}'),
            ('Non conformes', '${controles.where((c) => c.resultat == 'Non-conforme').length}'),
            ('Taux moyen', '${(controles.fold(0.0, (s, c) => s + c.tauxConformite) / controles.length).toStringAsFixed(1)} %'),
          ]),
          table(
            ['Référence', 'Périmètre', 'Type', 'Fréquence', 'Taux conf.', 'Résultat'],
            controles.map((c) => [
              c.reference, c.perimetre, c.typeControle, c.frequence,
              '${c.tauxConformite.toStringAsFixed(1)} %', c.resultat,
            ]).toList(),
          ),
        ] else
          pw.Text('Aucun contrôle enregistré.', style: mutedStyle),
        pw.SizedBox(height: 12),

        // ── 9. PLANS D'ACTIONS ───────────────────────────────────────────────
        sectionBanner('9. PLANS D\'ACTIONS  '),
        if (plans.isNotEmpty) ...[
          kpiGrid([
            ('Plans total', '${plans.length}'),
            ('En retard', '${plans.where((p) => p.enRetard).length}'),
            ('Réalisation moy.', '${(plans.fold(0.0, (s, p) => s + p.avancement) / plans.length).toStringAsFixed(0)} %'),
          ]),
          table(
            ['Référence', 'Titre', 'Priorité', 'Responsable', 'Échéance', 'Avancement', 'Statut'],
            plans.map((p) => [
              p.reference,
              p.titre.length > 30 ? '${p.titre.substring(0, 28)}…' : p.titre,
              p.priorite,
              p.responsable.isEmpty ? '—' : p.responsable,
              p.dateEcheance.isEmpty ? '—' : p.dateEcheance,
              '${p.avancement} %', p.statut,
            ]).toList(),
          ),
        ] else
          pw.Text('Aucun plan d\'action enregistré.', style: mutedStyle),
        pw.SizedBox(height: 12),

        // ── 10. SIMULATION DE CRISE ──────────────────────────────────────────
        sectionBanner('10. SIMULATION DE CRISE  '),
        table(
          ['Scénario', 'Variation PNB', 'RWA estimé', 'Exigence fonds propres'],
          [
            ['Optimiste',    '+10 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 1.10), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 1.10)],
            ['Neutre',        '0 %',  AppFormatters.currency(dash.widget1.aprRisqueOp),        AppFormatters.currency(dash.widget1.exigenceFondsPropres)],
            ['Pessimiste',   '-20 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 0.80), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 0.80)],
            ['Crise sévère', '-35 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 0.65), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 0.65)],
          ],
        ),
        pw.SizedBox(height: 16),

        // ── PIED ─────────────────────────────────────────────────────────────
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text(
          'Rapport généré le $dateStr -- Outil RWA -- Confidentiel',
          style: mutedStyle,
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    return doc.save();
  }

  // ─── Interface ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Reporting global',
            subtitle: 'Génération du rapport consolidé — Dashboard, Crédit, Marché, Opérationnel',
            titleFontSize: 26,
            subtitleFontSize: 12.5,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCard(
                    title: 'Paramètres du rapport',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Période rapide :',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkMuted : _kMuted)),
                    const SizedBox(width: 10),
                    ...['Mensuel', 'Trimestriel', 'Semestriel', 'Annuel'].map((p) {
                      final sel = _periode == p &&
                          _dateDebutCtrl.text.isNotEmpty && _dateFinCtrl.text.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _applyQuickPeriod(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? _kBlue : _kBlue.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? _kBlue : _kBlue.withValues(alpha: 0.25)),
                            ),
                            child: Text(p, style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _kBlue,
                            )),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _reportingDateField(context, 'Date de début', _dateDebutCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _reportingDateField(context, 'Date de fin', _dateFinCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown('Destinataire', _destinataire,
                      ['Organe exécutif', 'Organe délibérant', 'Commission Bancaire'],
                      (v) => setState(() => _destinataire = v ?? 'Organe exécutif'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Structure du rapport',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_artInfo('Art. 301/307'), const SizedBox(width: 4), _artInfo('Art. 546')],
            ),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(44),
                1: FlexColumnWidth(1.4),
                2: FlexColumnWidth(3),
                3: FixedColumnWidth(52),
              },
              children: [
                _tableHeader(['#', 'Section', 'Éléments inclus', 'Réf.']),
                ...[
                  ('1',  'Synthèse globale',                              '',           ['RWA Total (Crédit + Marché + Opérationnel) (Art. 301/307)', 'Capital total et fonds propres', 'Ratios CET1, Tier 1, Solvabilité, Levier']),
                  ('2',  'Risque Crédit',                                 '',           ['Nombre d\'expositions, EAD, RWA, capital requis', 'Top 5 expositions par RWA', 'Statut de conformité par contrepartie']),
                  ('3',  'Risque de Marché',                              '',           ['RWA et capital requis global', 'Décomposition Taux / Actions / Change (FX)', 'Part de chaque composante dans le capital requis']),
                  ('4',  'Synthèse générale (Risque Opérationnel)',       '',           ['Exigence de fonds propres (Art. 301/307)', 'RWA risque opérationnel (Art. 89)', 'Statut de conformité', 'Évolution N-1']),
                  ('5',  'Incidents et pertes',                           'Art. 313.b', ['Nombre total d\'incidents', 'Pertes nettes totales', 'Top 5 incidents par perte', 'Répartition par ligne de métier']),
                  ('6',  'Indicateurs clés (KRI)',                        '',           ['Tableau des KRI avec statut', 'Évolutions significatives', 'Alertes et actions associées']),
                  ('7',  'Cartographie des risques',                      '',           ['Matrice des risques (heatmap)', 'Top 5 risques critiques', 'Évolution risque résiduel']),
                  ('8',  'Contrôles internes',                            'Art. 314',   ['Taux de conformité global', 'Contrôles non conformes', 'Plan de contrôle', 'Actions correctives en cours']),
                  ('9',  'Plans d\'action',                               'Art. 313.c', ['Taux de réalisation', 'Actions en retard', 'Actions terminées (période)']),
                  ('10', 'Simulation de crise',                           'Art. 545',   ['Scénario optimiste (+10 %)', 'Scénario neutre (0 %)', 'Scénario pessimiste (-20 %)', 'Scénario crise sévère (-35 %)']),
                  ('11', 'Annexes',                                       '',           ['Détail des incidents', 'Journal des modifications', 'Glossaire']),
                ].map<TableRow>((r) => TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0x11000000))),
                  ),
                  children: [
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Center(
                          child: Container(
                            width: 24, height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _kBlue.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(r.$1,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kBlue)),
                          ),
                        ),
                      ),
                    ),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Text(r.$2,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: r.$4.map((item) {
                            final refs = _extractArtRefs(item);
                            final clean = _stripArtRefs(item);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4, height: 4,
                                    decoration: BoxDecoration(
                                      color: _kBlue.withValues(alpha: 0.40),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(clean, style: const TextStyle(fontSize: 12)),
                                  ...refs.map((ref) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: _artInfo(ref),
                                  )),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: r.$3.isNotEmpty ? _artInfo(r.$3) : const SizedBox(),
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _generating ? null : _generateAndSave,
                icon: _generating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(_generating ? 'Génération en cours…' : 'Générer le rapport · $_periodeLabel'),
              ),
              if (_savedFileName != null) ...[
                const SizedBox(width: 14),
                const Icon(Icons.check_circle_outline, size: 16, color: _kSuccess),
                const SizedBox(width: 4),
                Flexible(child: Text(_savedFileName!, style: const TextStyle(color: _kSuccess, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ],
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportingDateField(BuildContext context, String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_month_outlined, size: 12, color: _kBlue),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kMuted, letterSpacing: 0.1)),
          ]),
          const SizedBox(height: 5),
          TextFormField(
            controller: ctrl,
            readOnly: true,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'jj/mm/aaaa',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
              suffixIcon: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _kBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.calendar_month_outlined, size: 14, color: _kBlue),
              ),
            ),
            onTap: () async {
              DateTime? current;
              try { if (ctrl.text.isNotEmpty) current = DateTime.parse(ctrl.text); } catch (_) {}
              final picked = await showDatePicker(
                context: context,
                initialDate: current ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: 'Sélectionner une date',
              );
              if (picked != null) setState(() => ctrl.text = picked.toIso8601String().substring(0, 10));
            },
          ),
        ],
      ),
    );
  }
}
