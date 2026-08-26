import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/fodep_models.dart';

/// Générateur du document officiel FODEP au format PDF conforme aux normes
/// de la Commission Bancaire de l'UMOA et de la BCEAO.
class FodepPdfExporter {
  FodepPdfExporter._();

  static Future<Uint8List> genererPdf({
    required FodepApercu apercu,
    required EtablissementView etablissement,
    required List<ParticipationEntry> participations,
    required List<CodeDispru> codesDispru,
  }) async {
    final pdf = pw.Document();

    final dateGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final periodeStr = apercu.periode != null && apercu.periode!.isNotEmpty
        ? apercu.periode!
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    String fmtMontant(double? v) {
      if (v == null || v == 0) return '0';
      final n = v.round();
      final s = n.toString();
      final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
      return s.replaceAllMapped(reg, (m) => ' ');
    }

    String fmtPct(double? v) {
      if (v == null) return '—';
      return '${v.toStringAsFixed(2)} %';
    }

    // Couleurs officielles
    const primaryNavy = PdfColor.fromInt(0xFF172554);
    const accentBlue = PdfColor.fromInt(0xFF1E40AF);
    const lightHeaderBg = PdfColor.fromInt(0xFFF1F5F9);
    const borderGrey = PdfColor.fromInt(0xFFCBD5E1);
    const rowAltBg = PdfColor.fromInt(0xFFF8FAFC);
    const alertRed = PdfColor.fromInt(0xFFDC2626);
    const successGreen = PdfColor.fromInt(0xFF15803D);

    pw.Widget buildHeader(pw.Context context) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: borderGrey, width: 0.8)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'COMMISSION BANCAIRE DE L\'UMOA  ·  BCEAO',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
                pw.Text(
                  'Formulaire de Déclaration Prudentielle (FODEP) — Base Individuelle',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  etablissement.denomination.isNotEmpty
                      ? '${etablissement.denomination} (${etablissement.codeBceao})'
                      : 'ÉTABLISSEMENT ASSUJETTI',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
                pw.Text(
                  'Arrêté au : $periodeStr  |  Généré le : $dateGen',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
      );
    }

    pw.Widget buildFooter(pw.Context context) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: borderGrey, width: 0.6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Document Réglementaire Officiel Confidentiel  ·  Circulaire n° 004-2017 / BCEAO / CB-UMOA',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} sur ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: primaryNavy,
              ),
            ),
          ],
        ),
      );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PAGE 1 : PAGE DE GARDE & ÉTAT DE CONFORMITÉ (EP01 & EP02)
    // ══════════════════════════════════════════════════════════════════════════
    final cet1 = apercu.ratios['cet1'];
    final t1 = apercu.ratios['tier1'];
    final solv = apercu.ratios['solvency'];
    final lev = apercu.ratios['leverage'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 24),
        header: buildHeader,
        footer: buildFooter,
        build: (context) => [
          // Titre principal
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: pw.BoxDecoration(
              color: primaryNavy,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DÉCLARATION PRUDENTIELLE RÉGLEMENTAIRE (FODEP)',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Dispositif Prudentiel Bâle II / Bâle III — Zone UMOA',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey300),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: accentBlue,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'ARRÊTÉ : $periodeStr',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Bloc Identification Établissement
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: lightHeaderBg,
              borderRadius: pw.BorderRadius.circular(3),
              border: pw.Border.all(color: borderGrey, width: 0.5),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Dénomination : ${etablissement.denomination.isNotEmpty ? etablissement.denomination : "Non renseignée"}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'Code d\'agrément BCEAO : ${etablissement.codeBceao.isNotEmpty ? etablissement.codeBceao : "—"}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                  ),
                ),
                pw.Text(
                  'Unité monétaire : Francs CFA (XOF)',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── EP01 : ÉTAT DE CONFORMITÉ AUX NORMES PRUDENTIELLES ─────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: accentBlue,
            child: pw.Text(
              'ÉTAT EP01 — CONFORMITÉ AUX NORMES PRUDENTIELLES',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(48),
              1: const pw.FlexColumnWidth(6),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(70),
              4: const pw.FixedColumnWidth(70),
              5: const pw.FixedColumnWidth(75),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightHeaderBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Code', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Norme prudentielle', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Réf.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Niveau requis', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Niveau observé', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Conformité', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              // Lignes EP01
              ...[
                ('RA001', 'Ratio de fonds propres CET 1 (%)', 'EP02', cet1?.threshold, cet1?.value, cet1 != null && cet1.conforme),
                ('RA002', 'Ratio de fonds propres de base T1 (%)', 'EP02', t1?.threshold, t1?.value, t1 != null && t1.conforme),
                ('RA003', 'Ratio de solvabilité total (%)', 'EP02', solv?.threshold, solv?.value, solv != null && solv.conforme),
                ('RA004', 'Norme de division des risques (Grands risques <= 25%)', 'EP29', 25.0, apercu.ratios['ra004']?.value ?? 0.0, apercu.ratios['ra004']?.conforme ?? true),
                ('RA005', 'Ratio de levier (Exposition globale >= 3%)', 'EP33', lev?.threshold, lev?.value, lev != null && lev.conforme),
                ('RA006', 'Limite indiv. participations entités com. (25% capital)', 'EP35', apercu.ratios['ra006']?.threshold ?? 25.0, apercu.ratios['ra006']?.value, apercu.ratios['ra006']?.conforme ?? true),
                ('RA007', 'Limite indiv. participations entités com. (15% FP T1)', 'EP35', apercu.ratios['ra007']?.threshold ?? 15.0, apercu.ratios['ra007']?.value, apercu.ratios['ra007']?.conforme ?? true),
                ('RA008', 'Limite globale participations entités com. (60% FPE)', 'EP35', apercu.ratios['ra008']?.threshold ?? 60.0, apercu.ratios['ra008']?.value, apercu.ratios['ra008']?.conforme ?? true),
                ('RA009', 'Limite sur les immobilisations hors exploitation (15%)', 'EP36', apercu.ratios['ra009']?.threshold ?? 15.0, apercu.ratios['ra009']?.value, apercu.ratios['ra009']?.conforme ?? true),
                ('RA010', 'Limite total immobilisations et participations (100%)', 'EP37', apercu.ratios['ra010']?.threshold ?? 100.0, apercu.ratios['ra010']?.value, apercu.ratios['ra010']?.conforme ?? true),
                ('RA011', 'Limite prêts actionnaires/dirigeants/personnel (20%)', 'EP38', apercu.ratios['ra011']?.threshold ?? 20.0, apercu.ratios['ra011']?.value, apercu.ratios['ra011']?.conforme ?? true),
              ].map((row) {
                final estConforme = row.$6;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: !estConforme ? const PdfColor.fromInt(0xFFFEF2F2) : PdfColors.white,
                  ),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row.$1, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row.$2, style: const pw.TextStyle(fontSize: 7.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row.$3, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtPct(row.$4), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtPct(row.$5), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: estConforme ? successGreen : alertRed))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(estConforme ? 'CONFORME' : 'NON CONFORME', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: estConforme ? successGreen : alertRed))),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── EP02 : CALCUL DES RATIOS DE SOLVABILITÉ ───────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: primaryNavy,
            child: pw.Text(
              'ÉTAT EP02 — CALCUL DES RATIOS DE SOLVABILITÉ ET FONDS PROPRES',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FlexColumnWidth(6),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FixedColumnWidth(110),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightHeaderBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Code', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Poste / Agrégat de Solvabilité', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Réf.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Montant (FCFA) / Ratio', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...[
                ('FPI22', 'Fonds propres de base durs (CET 1)', 'EP03', fmtMontant(apercu.totaux['fpi22'])),
                ('FPI28', 'Fonds propres additionnels (AT 1)', 'EP03', fmtMontant((apercu.totaux['fpi29'] ?? 0) - (apercu.totaux['fpi22'] ?? 0))),
                ('FPI29', 'Total des fonds propres de base (Tier 1)', 'EP03', fmtMontant(apercu.totaux['fpi29'])),
                ('FPI40', 'Fonds propres complémentaires (Tier 2)', 'EP03', fmtMontant((apercu.totaux['fpi41'] ?? 0) - (apercu.totaux['fpi29'] ?? 0))),
                ('FPI41', 'TOTAL DES FONDS PROPRES EFFECTIFS', 'EP03', fmtMontant(apercu.totaux['fpi41'])),
                ('APR_TOT', 'TOTAL DES ACTIFS PONDÉRÉS DES RISQUES (APR)', 'EP08', fmtMontant(apercu.apr.aprTotal)),
                ('RA001', 'Ratio CET 1 (Min 5,00%)', 'EP02', fmtPct(cet1?.value)),
                ('RA002', 'Ratio Tier 1 (Min 6,00%)', 'EP02', fmtPct(t1?.value)),
                ('RA003', 'Ratio de solvabilité global (Min 9,00%)', 'EP02', fmtPct(solv?.value)),
                ('RA005', 'Ratio de levier (Min 3,00%)', 'EP33', fmtPct(lev?.value)),
              ].map((row) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row.$1, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row.$2, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row.$3, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row.$4, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );

    // ══════════════════════════════════════════════════════════════════════════
    // PAGE 2 : EP03 - CALCUL DÉTAILLÉ DES FONDS PROPRES (FPI01 à FPI41)
    // ══════════════════════════════════════════════════════════════════════════
    final codesEp03 = codesDispru.where((c) => c.ep == 'EP03').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 24),
        header: buildHeader,
        footer: buildFooter,
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: primaryNavy,
            child: pw.Text(
              'ÉTAT EP03 — DÉTAIL DES FONDS PROPRES SUR BASE INDIVIDUELLE',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(48),
              1: const pw.FixedColumnWidth(40),
              2: const pw.FlexColumnWidth(6),
              3: const pw.FixedColumnWidth(95),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightHeaderBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Code', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Sens', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Libellé réglementaire DISPRU', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Montant (FCFA)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              for (int i = 0; i < codesEp03.length; i++)
                () {
                  final codeObj = codesEp03[i];
                  final val = apercu.postes[codeObj.code.toLowerCase()];
                  final isDeduction = codeObj.estDeduction;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : rowAltBg,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3.5),
                        child: pw.Text(codeObj.code, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryNavy)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3.5),
                        child: pw.Text(isDeduction ? '(-)' : '(+)', style: pw.TextStyle(fontSize: 7, color: isDeduction ? alertRed : successGreen)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3.5),
                        child: pw.Text(codeObj.label, style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3.5),
                        child: pw.Text(fmtMontant(val), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  );
                }(),
            ],
          ),
        ],
      ),
    );

    // ══════════════════════════════════════════════════════════════════════════
    // PAGE 3 : EP08 (APR) & EP33 (LEVIER) & EP35-38 (NORMES SUR OPÉRATIONS)
    // ══════════════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 24),
        header: buildHeader,
        footer: buildFooter,
        build: (context) => [
          // EP08 : ACTIFS PONDÉRÉS DES RISQUES
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: primaryNavy,
            child: pw.Text(
              'ÉTAT EP08 — VENTILATION DES ACTIFS PONDÉRÉS DES RISQUES (APR)',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FlexColumnWidth(6),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(95),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightHeaderBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Catégorie', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Nature du Risque', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Réf.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('RWA (FCFA)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...[
                ('Crédit', 'Risque de crédit et de contrepartie', 'EP09-EP20', fmtMontant(apercu.apr.rwaCredit)),
                ('Marché', 'Risque de marché (taux, change, actions)', 'EP23-EP28', fmtMontant(apercu.apr.rwaMarche)),
                ('Opérationnel', 'Risque opérationnel (Approche Indicateur de Base)', 'EP21-EP22', fmtMontant(apercu.apr.rwaOperationnel)),
                ('TOTAL', 'TOTAL DES ACTIFS PONDÉRÉS (APR)', 'EP08', fmtMontant(apercu.apr.aprTotal)),
              ].map((r) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: r.$1 == 'TOTAL' ? lightHeaderBg : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.$1, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.$3, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.$4, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 14),

          // EP35 : PARTICIPATIONS DANS LES ENTITÉS COMMERCIALES
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: accentBlue,
            child: pw.Text(
              'ÉTAT EP35 — PARTICIPATIONS DANS DES ENTITÉS COMMERCIALES',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
          if (participations.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderGrey, width: 0.5),
              ),
              child: pw.Text(
                'Aucune participation enregistrée pour cet arrêté.',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: borderGrey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(5),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(55),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: lightHeaderBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Entreprise émettrice', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Capital (FCFA)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Montant Net (FCFA)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('% Détenu', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                for (final part in participations)
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(part.denominationEmettrice, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMontant(part.capitalEmettrice), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMontant(part.montantNet), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          part.capitalEmettrice > 0
                              ? '${(part.montantNet / part.capitalEmettrice * 100).toStringAsFixed(2)} %'
                              : '0.00 %',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 14),

          // SIGNATURES & VALIDATION RÉGLEMENTAIRE
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderGrey, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Le Responsable du Contrôle Prudentiel :', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 24),
                    pw.Text('Date & Signature : ...................................', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('La Direction Générale :', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 24),
                    pw.Text('Date & Signature : ...................................', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
