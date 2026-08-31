import 'package:flutter/material.dart';

import '../../../shared/widgets/page_header.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../../risque_operationnel/models/ro_models.dart';
import '../../risque_marche/repositories/foreign_exchange_repository.dart';
import '../../risque_marche/services/market_data_import_store.dart';
import '../../risque_marche/services/market_risk_aggregation_service.dart';
import '../../rwa_engine/models/rwa_credit_analysis.dart';
import '../models/fodep_models.dart';
import '../services/fodep_service.dart';
import '../widgets/fodep_charts.dart';
import '../widgets/fodep_design.dart';
import '../widgets/fodep_import_dialog.dart';
import '../../../core/theme/app_theme.dart';

enum _SectionFodep {
  conformite,
  solvabilite,
  fondsPropres,
  actifsPonderes,
  risqueCredit,
  risqueOperationnel,
  risqueMarche,
  divisionRisques,
  ratioLevier,
  normesOperations,
}

extension _SectionLabel on _SectionFodep {
  String get titre {
    switch (this) {
      case _SectionFodep.conformite: return 'Conformité aux normes';
      case _SectionFodep.solvabilite: return 'Ratios de solvabilité';
      case _SectionFodep.fondsPropres: return 'Fonds propres';
      case _SectionFodep.actifsPonderes: return 'Total des actifs pondérés';
      case _SectionFodep.risqueCredit: return 'Risque de crédit';
      case _SectionFodep.risqueOperationnel: return 'Risque opérationnel';
      case _SectionFodep.risqueMarche: return 'Risque de marché';
      case _SectionFodep.divisionRisques: return 'Division des risques';
      case _SectionFodep.ratioLevier: return 'Ratio de levier';
      case _SectionFodep.normesOperations: return 'Normes sur les opérations';
    }
  }
}

class FodepAnalyserScreen extends StatefulWidget {
  const FodepAnalyserScreen({super.key, required this.service});

  final FodepService service;

  @override
  State<FodepAnalyserScreen> createState() => _FodepAnalyserScreenState();
}

class _FodepAnalyserScreenState extends State<FodepAnalyserScreen> {
  bool _chargement = true;
  String? _erreur;
  List<CodeDispru> _codes = [];
  FodepApercu? _apercu;
  RwaCreditAnalysis? _analyseCredit;
  AibCalculResult? _calculAib;
  MarketPrudentialCapitalResult? _capitalMarcheDetail;
  _SectionFodep _section = _SectionFodep.conformite;
  bool _enregistrementPeriode = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final codes = await widget.service.listerCodesDispru();
      final apercu = await widget.service.obtenirApercu();
      RwaCreditAnalysis? analyseCredit;
      try {
        analyseCredit = await widget.service.obtenirAnalyseCredit();
      } catch (_) {
        // Ventilation par catégorie non disponible (ex. aucune exposition
        // importée) : l'onglet retombe sur le simple total EP08 déjà connu.
        analyseCredit = null;
      }
      AibCalculResult? calculAib;
      try {
        calculAib = await widget.service.obtenirCalculAib();
      } catch (_) {
        calculAib = null;
      }
      MarketPrudentialCapitalResult? capitalMarcheDetail;
      try {
        // Ventilation EP25-EP28 (taux/actions/change/matières premières) :
        // calculée côté client par le module Risque de Marché, comme le
        // fait déjà MarketCapitalRequirementPersister pour le total persisté
        // - même source, on évite juste de dupliquer le calcul en base.
        final snapshot = MarketDataImportStore.instance.snapshotNotifier.value;
        final records = [
          ...?snapshot.datasets[MarketPortfolioType.bonds]?.records,
          ...?snapshot.datasets[MarketPortfolioType.equities]?.records,
        ];
        final fxPositions = InMemoryForeignExchangeRepository().currentPositions;
        capitalMarcheDetail = applyRealForeignExchangeRisk(
          calculateMarketPrudentialCapital(records: records),
          fxPositions,
        );
      } catch (_) {
        capitalMarcheDetail = null;
      }
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _apercu = apercu;
        _analyseCredit = analyseCredit;
        _calculAib = calculAib;
        _capitalMarcheDetail = capitalMarcheDetail;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Chargement impossible : $e';
        _chargement = false;
      });
    }
  }

  Future<void> _selectionnerArrete(DashColors c) async {
    if (_apercu == null || _enregistrementPeriode) return;
    final actuelle = DateTime.tryParse(_apercu!.periode ?? '') ?? DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: actuelle.isAfter(DateTime.now()) ? DateTime.now() : actuelle,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (choisie == null || !mounted) return;
    final periode =
        '${choisie.year.toString().padLeft(4, '0')}-${choisie.month.toString().padLeft(2, '0')}-${choisie.day.toString().padLeft(2, '0')}';
    setState(() => _enregistrementPeriode = true);
    try {
      final apercu = await widget.service.enregistrer(periode: periode, postes: _apercu!.postes);
      if (!mounted) return;
      setState(() {
        _apercu = apercu;
        _enregistrementPeriode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = "Enregistrement de l'arrêté impossible : $e";
        _enregistrementPeriode = false;
      });
    }
  }

  Widget _buildBoutonImportAncienFodep(DashColors c) {
    return InkWell(
      onTap: () async {
        final reussi = await showFodepImportDialog(
          context,
          service: widget.service,
          initialPeriode: _apercu?.periode,
        );
        if (reussi == true && mounted) {
          _charger();
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.upload_file_rounded,
              size: 14,
              color: Color(0xFF1E3A8A),
            ),
            const SizedBox(width: 7),
            Text(
              'Importer nouveau FODEP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastilleArrete(DashColors c) {
    final periode = _apercu?.periode;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBoutonImportAncienFodep(c),
        const SizedBox(width: 16),
        Tooltip(
          message: "Date d'arrêté",
          child: _buildPastilleArreteBadge(c, periode),
        ),
      ],
    );
  }

  Widget _buildPastilleArreteBadge(DashColors c, String? periode) {
    return GestureDetector(
      onTap: () => _selectionnerArrete(c),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _deepblue,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              _enregistrementPeriode ? '…' : (periode ?? 'Sélectionner'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formate une valeur **déjà exprimée en millions** (postes / totaux FODEP).
  String _fmtM(double millions) => _fmt(millions * 1e6);

  String _fmt(double v) {
    if (v == 0) return '0';
    // Format en millions par défaut
    final enMillions = v / 1e6;
    
    // On ajoute un séparateur de milliers si le montant en millions est grand
    // mais on peut simplement utiliser toStringAsFixed(2) avec un replaceAll pour l'instant
    // Pour améliorer la lisibilité des gros chiffres, on pourrait formater avec des espaces
    // Ex: 87420.50 -> 87 420,50
    final parts = enMillions.toStringAsFixed(2).split('.');
    final entier = parts[0].replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ' ');
    final decimal = parts.length > 1 ? ',${parts[1]}' : '';
    
    return '$entier$decimal M';
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(
              bottom: BorderSide(color: c.border, width: Dash.hairline),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Analyse',
                subtitle: 'Analyse des fonds propres, des risques pondérés et de la conformité',
                titleFontSize: 22,
                subtitleFontSize: 12.5,
                titleSubtitleGap: 2,
                trailing: _buildPastilleArrete(c),
              ),
              const SizedBox(height: 12),
              
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // slate-50
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: c.border, width: Dash.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final s in _SectionFodep.values)
                        _OngletEp(
                          label: s.titre,
                          selected: _section == s,
                          onTap: () => setState(() => _section = s),
                          c: c,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Contenu ────────────────────────────────────────────────────────
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_erreur != null) ...[
                        FodepNotice(status: DashStatus.sousMinimum, texte: _erreur!),
                        const SizedBox(height: 10),
                      ],
                      if (_apercu != null)
                        Expanded(
                          child: _buildSection(c),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSection(DashColors c) {
    final apercu = _apercu!;
    switch (_section) {
      case _SectionFodep.conformite: return _buildConformite(c, apercu);
      case _SectionFodep.solvabilite: return _buildSolvabilite(c, apercu);
      case _SectionFodep.fondsPropres: return _buildEp01(c, apercu);
      case _SectionFodep.actifsPonderes: return _buildActifsPonderes(c, apercu);
      case _SectionFodep.risqueCredit: return _buildEp02(c, apercu);
      case _SectionFodep.risqueOperationnel: return _buildEp04(c, apercu);
      case _SectionFodep.risqueMarche: return _buildEp03(c, apercu);
      case _SectionFodep.divisionRisques: return _buildEp29(c, apercu);
      case _SectionFodep.ratioLevier: return _buildRatioLevier(c, apercu);
      case _SectionFodep.normesOperations: return _NormesOperationsPanel(
          service: widget.service,
          apercu: apercu,
          onSaved: _charger,
        );
    }
  }

  // ── Ratios de solvabilité (EP02) ──────────────────────────────────────────
  Widget _buildSolvabilite(DashColors c, FodepApercu apercu) {
    final cet1 = apercu.ratios['cet1']?.value ?? 0;
    final tier1 = apercu.ratios['tier1']?.value ?? 0;
    final solvency = apercu.ratios['solvency']?.value ?? 0;

    final fpCet1 = apercu.totaux['fpi22'] ?? 0;
    final fpT1 = apercu.totaux['fpi29'] ?? 0;
    final fpEffectifs = apercu.totaux['fpi41'] ?? 0;

    final totalApr = apercu.apr.aprTotal;

    String pct(double v) => '${v.toStringAsFixed(2)} %';

    return FodepTable(
      children: [
        const FodepTableHeader(col1: 'Poste', col2: 'Référence', col3: 'Niveau / Montant estimé'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FodepTableGroup(title: 'Ratios de solvabilité'),
                FodepTableRow(label: 'Ratio de fonds propres CET 1 (%)', ref: 'a x 100 / d', value: pct(cet1)),
                FodepTableRow(label: 'Ratio de fonds propres de base T1 (%)', ref: 'b x 100 / d', value: pct(tier1)),
                FodepTableRow(label: 'Ratio de Solvabilité total (%)', ref: 'c x 100 / d', value: pct(solvency)),

                const FodepTableGroup(title: 'Fonds Propres'),
                FodepTableRow(label: 'Fonds propres de base durs (CET 1)', ref: 'EP03 / EP05', value: _fmtM(fpCet1)),
                FodepTableRow(label: 'Fonds propres de base (T1)', ref: 'EP03 / EP05', value: _fmtM(fpT1)),
                FodepTableRow(label: 'Fonds propres effectifs (FPE)', ref: 'EP03 / EP05', value: _fmtM(fpEffectifs)),

                const FodepTableGroup(title: 'Actifs Pondérés des risques (APR)'),
                FodepTableRow(label: 'Total des actifs pondérés des risques de crédit, de marché et opérationnel', ref: 'EP08', value: _fmt(totalApr), isLast: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── EP08 - Total des actifs pondérés des risques ───────────────────────────
  // Structure officielle (classeur BCEAO) : A. Risque de crédit (une ligne
  // par catégorie prudentielle, référence EP12-EP20) + APR01, B. Risque de
  // marché (taux/actions/change/matières premières, référence EP25-EP28) +
  // APR02, C. Risque opérationnel (EP21 ou EP23 selon l'approche autorisée)
  // + APR03, puis APR04 = somme des trois.
  Widget _buildActifsPonderes(DashColors c, FodepApercu apercu) {
    final apr = apercu.apr;
    final analyseCredit = _analyseCredit;
    final marche = _capitalMarcheDetail;
    final aib = _calculAib;
    const mult = 11.11;

    // Toutes les lignes du formulaire officiel sont présentes, y compris à
    // zéro : un état prudentiel se lit à structure constante, une ligne
    // absente n'est pas la même information qu'une ligne à zéro.
    // Les catégories i (créances en souffrance) et j (créances à risque
    // élevé) n'ont pas de ligne propre à l'EP08 : la notice les maintient
    // dans la catégorie d'exposition à laquelle elles se rapportent.
    const creditOfficiel = <(String, String, String)>[
      ('Expositions sur les souverains', 'EP12', 'a'),
      ('Expositions sur les organismes publics hors administration centrale', 'EP13', 'b'),
      ('Expositions sur les Banques Multilatérales de Développement', 'EP14', 'c'),
      ('Expositions sur les institutions financières', 'EP15', 'd'),
      ('Expositions sur les entreprises', 'EP16', 'e'),
      ('Expositions sur la clientèle de détail', 'EP17', 'f'),
      ("Expositions sur les prêts garantis par l'immobilier résidentiel", 'EP18', 'g'),
      ("Expositions sur les prêts garantis par l'immobilier commercial", 'EP19', 'h'),
      ('Autres actifs', 'EP20', 'k'),
    ];

    final rwaParCategorie = <String, double>{};
    for (final agent in analyseCredit?.agents ?? const <RwaCreditAgentRow>[]) {
      rwaParCategorie[agent.code] = (rwaParCategorie[agent.code] ?? 0) + agent.rwa;
    }

    final lignes = <List<String>>[
      for (final poste in creditOfficiel)
        [poste.$1, poste.$2, _fmt(rwaParCategorie[poste.$3] ?? 0)],
      ['Total des actifs pondérés du risque de crédit', '', _fmt(apr.rwaCredit)],
      ["APR au titre du risque de taux d'intérêt du portefeuille de négociation", 'EP25', _fmt(marche == null ? 0 : marche.interestRateRisk * mult)],
      ['APR au titre du risque de positions sur titres de propriété', 'EP26', _fmt(marche == null ? 0 : marche.equityRisk * mult)],
      ['APR au titre du risque de change', 'EP27', _fmt(marche == null ? 0 : marche.foreignExchangeRisk * mult)],
      ['APR au titre du risque de positions sur produits de base', 'EP28', _fmt(marche == null ? 0 : marche.commodityRisk * mult)],
      ['Total des actifs pondérés du risque de marché', '', _fmt(apr.rwaMarche)],
      ["Actifs pondérés selon l'approche indicateur de base", 'EP21', _fmt(aib != null && !aib.donneesInsuffisantes ? apr.rwaOperationnel : 0)],
      ["Actifs pondérés selon l'approche standard", 'EP23', _fmt(0)],
      ['Total des actifs pondérés du risque opérationnel', '', _fmt(apr.rwaOperationnel)],
    ];

    return _tableauFixe(
      c,
      titre: '',
      colonnes: const ['Poste', 'Référence', 'Montant'],
      flex: const [5, 2, 3],
      lignes: lignes,
      pied: 'TOTAL ACTIFS PONDÉRÉS DES RISQUES (APR) : ${_fmt(apr.aprTotal)}',
    );
  }

  // ── État de conformité - tableau officiel des normes prudentielles ──────────
  Widget _buildConformite(DashColors c, FodepApercu apercu) {
    final cet1 = apercu.ratios['cet1'];
    final tier1 = apercu.ratios['tier1'];
    final solvency = apercu.ratios['solvency'];
    final leverage = apercu.ratios['leverage'];

    final sections = <_ConformiteSection>[
      _ConformiteSection(
        titre: 'A. Normes de solvabilité',
        couleur: const Color(0xFF1E40AF),
        lignes: [
          _LigneConformite(code: 'RA001', libelle: 'Ratio de fonds propres CET 1 (%)', reference: 'EP02',
            seuil: cet1?.threshold, observe: cet1?.value,
            statut: cet1 != null ? (cet1.conforme ? _Statut.conforme : _Statut.infraction) : _Statut.nd),
          _LigneConformite(code: 'RA002', libelle: 'Ratio de fonds propres de base T1 (%)', reference: 'EP02',
            seuil: tier1?.threshold, observe: tier1?.value,
            statut: tier1 != null ? (tier1.conforme ? _Statut.conforme : _Statut.infraction) : _Statut.nd),
          _LigneConformite(code: 'RA003', libelle: 'Ratio de solvabilité total (%)', reference: 'EP02',
            seuil: solvency?.threshold, observe: solvency?.value,
            statut: solvency != null ? (solvency.conforme ? _Statut.conforme : _Statut.infraction) : _Statut.nd),
        ],
      ),
      _ConformiteSection(
        titre: 'B. Norme de division des risques',
        couleur: const Color(0xFF7C3AED),
        lignes: [
          () {
            final grands = _calculerGrandsRisques(apercu.totaux['fpi29'] ?? 0);
            final observe = grands.isEmpty ? null : grands.first.pourcentageT1;
            return _LigneConformite(
              code: 'RA004',
              libelle: 'Norme de division des risques',
              reference: 'EP29',
              seuil: 25,
              observe: observe,
              statut: observe == null ? _Statut.nd : (observe <= 25 ? _Statut.conforme : _Statut.infraction),
            );
          }(),
        ],
      ),
      _ConformiteSection(
        titre: 'C. Ratio de levier',
        couleur: const Color(0xFF0891B2),
        lignes: [
          _LigneConformite(code: 'RA005', libelle: 'Ratio de levier', reference: 'EP33',
            seuil: leverage?.threshold, observe: leverage?.value,
            statut: leverage != null ? (leverage.conforme ? _Statut.conforme : _Statut.infraction) : _Statut.nd),
        ],
      ),
      _ConformiteSection(
        titre: 'D. Autres normes prudentielles',
        couleur: const Color(0xFF059669),
        lignes: [
          for (final norme in const [
            ('RA006', 'Limite individuelle sur les participations dans les entités commerciales (25% du capital)', 'ra006', 'EP35'),
            ('RA007', 'Limite individuelle sur les participations dans les entités commerciales (15% des FP T1)', 'ra007', 'EP35'),
            ('RA008', 'Limite globale de participations dans les entités commerciales (60% des FP effectifs)', 'ra008', 'EP35'),
            ('RA009', 'Limite sur les immobilisations hors exploitation', 'ra009', 'EP36'),
            ('RA010', 'Limite sur le total des immobilisations et des participations', 'ra010', 'EP37'),
            ('RA011', 'Limite sur les prêts aux actionnaires, aux dirigeants et au personnel', 'ra011', 'EP38'),
          ])
            _LigneConformite(
              code: norme.$1,
              libelle: norme.$2,
              reference: norme.$4,
              seuil: apercu.ratios[norme.$3]?.threshold,
              observe: apercu.ratios[norme.$3]?.value,
              statut: apercu.ratios[norme.$3] == null
                  ? _Statut.nd
                  : (apercu.ratios[norme.$3]!.conforme ? _Statut.conforme : _Statut.infraction),
            ),
        ],
      ),
    ];
    final division = sections[1].lignes.first;
    final autres = sections[3].lignes;
    final jauges = <_LigneConformite>[
      sections[0].lignes[0],
      sections[0].lignes[1],
      sections[0].lignes[2],
      sections[2].lignes.first,
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Cartes Executive des Ratios Clés
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < jauges.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                    child: _buildCarteRatioExecutif(c, jauges[i]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTableauAutresNormes(c, [division, ...autres]),
        ],
      ),
    );
  }

  /// Carte exécutive moderne pour un ratio clé de solvabilité / levier.
  Widget _buildCarteRatioExecutif(DashColors c, _LigneConformite ligne) {
    final observe = ligne.observe;
    final seuil = ligne.seuil;
    final disponible = ligne.statut != _Statut.nd;
    final conforme = ligne.statut == _Statut.conforme;
    final marge = (observe != null && seuil != null) ? (observe - seuil) : null;
    final couleur = !disponible
        ? c.muted
        : (conforme ? const Color(0xFF15803D) : const Color(0xFFDC2626));
    final fondStatut = !disponible
        ? const Color(0xFFF1F5F9)
        : (conforme ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2));
    final titreCourt = ligne.code == 'RA005'
        ? 'Ratio de Levier'
        : ligne.libelle.split('(').first.trim();



    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // En-tête : Référence + Statut Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: Dash.hairline),
                ),
                child: Text(
                  '${ligne.code} · ${ligne.reference}',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: fondStatut,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      conforme ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 11,
                      color: couleur,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      !disponible ? 'NON RENSEIGNÉ' : (conforme ? 'CONFORME' : 'NON CONFORME'),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: couleur,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Titre du ratio
          Text(
            titreCourt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 4),

          // Valeur Principale (Gros Chiffre Hero) + Coussin/Marge
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                observe == null ? '—' : '${observe.toStringAsFixed(2)} %',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: couleur,
                  letterSpacing: -0.5,
                  fontFeatures: Dash.tabular,
                ),
              ),
              const SizedBox(width: 8),
              if (marge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: marge >= 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${marge >= 0 ? '+' : ''}${marge.toStringAsFixed(2)} %',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: marge >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      fontFeatures: Dash.tabular,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Barre de benchmark réglementaire & Seuil minimum
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seuil mini : ${seuil?.toStringAsFixed(2) ?? '—'} %',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.muted),
                  ),

                ],
              ),

            ],
          ),
        ],
      ),
    );
  }

  /// Tableau récapitulatif unifié des autres normes prudentielles.
  Widget _buildTableauAutresNormes(DashColors c, List<_LigneConformite> lignes) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _deepblue,
            child: const Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text('CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                SizedBox(
                  width: 55,
                  child: Text('RÉF.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
                ),
                Expanded(
                  flex: 5,
                  child: Text('INTITULÉ DE LA NORME PRUDENTIELLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                SizedBox(
                  width: 110,
                  child: Text('OBSERVÉ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.right),
                ),
                SizedBox(width: 16),
                SizedBox(
                  width: 110,
                  child: Text('PLAFOND', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70), textAlign: TextAlign.right),
                ),
                SizedBox(width: 16),
                SizedBox(
                  width: 130,
                  child: Text('STATUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          for (int i = 0; i < lignes.length; i++)
            Builder(builder: (context) {
              final ligne = lignes[i];
              final observe = ligne.observe;
              final seuil = ligne.seuil;
              final estInfraction = ligne.statut == _Statut.infraction;
              final estConforme = ligne.statut == _Statut.conforme;
              final couleur = estInfraction
                  ? const Color(0xFFDC2626)
                  : (estConforme ? const Color(0xFF15803D) : const Color(0xFF64748B));
              final statutTexte = estInfraction
                  ? 'Non conforme'
                  : (estConforme ? 'Conforme' : 'Non renseigné');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: estInfraction
                      ? const Color(0xFFFEF2F2)
                      : (i.isEven ? c.surface : c.surfaceAlt),
                  border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          ligne.code,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 55,
                      child: Text(
                        ligne.reference,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        ligne.libelle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: estInfraction ? FontWeight.w700 : FontWeight.w500,
                          color: estInfraction ? const Color(0xFF991B1B) : c.ink,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        observe == null ? '—' : '${observe.toStringAsFixed(2)} %',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: couleur,
                          fontFeatures: Dash.tabular,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 110,
                      child: Text(
                        seuil == null ? '—' : '${seuil.toStringAsFixed(2)} %',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.muted,
                          fontFeatures: Dash.tabular,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 130,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: couleur,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statutTexte,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: couleur,
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
  }

  // ── EP01 - Fonds propres réglementaires ──────────────────────────────────
  Widget _buildEp01(DashColors c, FodepApercu apercu) {
    final blocs = <_BlocFondsPropres>[
      _BlocFondsPropres(
        groupe: 'CET1',
        titre: 'Fonds propres de base durs (CET1)',
        sousTitre: '',
        code: 'FPI22',
        total: apercu.totaux['fpi22'] ?? 0,
      ),
      _BlocFondsPropres(
        groupe: 'AT1',
        titre: 'Fonds additionnels (AT1)',
        sousTitre: '',
        code: 'FPI29',
        total: (apercu.totaux['fpi29'] ?? 0) - (apercu.totaux['fpi22'] ?? 0),
      ),
      _BlocFondsPropres(
        groupe: 'T2',
        titre: 'Fonds complémentaires (Tier 2)',
        sousTitre: '',
        code: null,
        total: (apercu.totaux['fpi41'] ?? 0) - (apercu.totaux['fpi29'] ?? 0),
      ),
      _BlocFondsPropres(
        groupe: 'effectifs-total',
        titre: 'Fonds propres effectifs',
        sousTitre: '',
        code: 'FPI41',
        total: apercu.totaux['fpi41'] ?? 0,
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _CarteFondsPropres(bloc: blocs[0], apercu: apercu, codes: _codes, fmt: _fmt, c: c)),
                const SizedBox(width: 16),
                Expanded(child: _CarteFondsPropres(bloc: blocs[1], apercu: apercu, codes: _codes, fmt: _fmt, c: c)),
                const SizedBox(width: 16),
                Expanded(child: _CarteFondsPropres(bloc: blocs[2], apercu: apercu, codes: _codes, fmt: _fmt, c: c)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CarteFondsPropres(bloc: blocs[3], apercu: apercu, codes: _codes, fmt: _fmt, c: c),
        ],
      ),
    );
  }

  // ── EP09-EP20 - Ventilation du risque de crédit par catégorie prudentielle ──
  Widget _buildEp02(DashColors c, FodepApercu apercu) {
    final analyse = _analyseCredit;
    if (analyse == null || analyse.agents.isEmpty) {
      return DashPanel(
        title: 'Actifs pondérés au titre du risque de crédit',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LigneValeur(label: 'RWA Risque de crédit (EP08)', valeur: _fmt(apercu.apr.rwaCredit), c: c),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF0F1B2D).withValues(alpha: 0.06),
            blurRadius: Theme.of(context).brightness == Brightness.dark ? 30 : 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF172554), Color(0xFF1E3A8A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 5, child: Text('Catégorie prudentielle', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))),
                Expanded(flex: 3, child: Text('Exposition brute', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))),
                Expanded(flex: 2, child: Text('Pondération moy.', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))),
                Expanded(flex: 3, child: Text('APR', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < analyse.agents.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          color: i.isEven ? c.surface : c.surfaceAlt,
                          border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 5, child: Text(analyse.agents[i].label, style: TextStyle(fontSize: 12, color: c.ink))),
                            Expanded(flex: 3, child: Text(_fmt(analyse.agents[i].grossExposure), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink, fontFeatures: Dash.tabular))),
                            Expanded(flex: 2, child: Text(analyse.agents[i].averageWeight == null ? '-' : '${(analyse.agents[i].averageWeight! * 100).toStringAsFixed(1)} %', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: Dash.tabular))),
                            Expanded(flex: 3, child: Text(_fmt(analyse.agents[i].rwa), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.navy, fontFeatures: Dash.tabular))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: const BoxDecoration(
              color: Color(0xFF172554),
            ),
            child: Row(
              children: [
                const Expanded(flex: 5, child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                Expanded(flex: 3, child: Text(_fmt(analyse.totals.grossExposure), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, fontFeatures: Dash.tabular))),
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(flex: 3, child: Text(_fmt(analyse.totals.rwa), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, fontFeatures: Dash.tabular))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── EP25-EP28 - Risque de marché, quatre familles ───────────────────────────
  Widget _buildEp03(DashColors c, FodepApercu apercu) {
    final detail = _capitalMarcheDetail;
    if (detail == null) {
      return _tableauFixe(
        c,
        titre: 'ACTIFS PONDÉRÉS AU TITRE DU RISQUE DE MARCHÉ',
        colonnes: const ['Poste', 'Référence', 'Montant'],
        flex: const [5, 2, 3],
        lignes: [
          ['ACTIFS PONDÉRÉS AU TITRE DU RISQUE DE MARCHÉ', 'EP08', _fmt(apercu.apr.rwaMarche)],
        ],
        pied: '',
      );
    }

    const mult = 11.11;
    final commodityRenseigne = detail.commodityGrossPosition != 0 || detail.commodityDirectionalRisk != 0 || detail.commodityBasisRisk != 0;

    return _tableauFixe(
      c,
      titre: 'RISQUE DE MARCHÉ, APPROCHE STANDARD (QUATRE FAMILLES)',
      colonnes: const ['État · Composante', 'Exigence FP', 'APR'],
      flex: const [5, 3, 3],
      lignes: [
        ['Taux d\'intérêt : risque spécifique', _fmt(detail.interestRateSpecificRisk), _fmt(detail.interestRateSpecificRisk * mult)],
        ['Taux d\'intérêt : risque général', _fmt(detail.interestRateGeneralRisk), _fmt(detail.interestRateGeneralRisk * mult)],
        ['Titres de propriété : risque spécifique', _fmt(detail.equitySpecificRisk), _fmt(detail.equitySpecificRisk * mult)],
        ['Titres de propriété : risque général', _fmt(detail.equityGeneralRisk), _fmt(detail.equityGeneralRisk * mult)],
        ['Change : risque général (position nette globale)', _fmt(detail.foreignExchangeRisk), _fmt(detail.foreignExchangeRisk * mult)],
        if (commodityRenseigne) ...[
          ['Produits de base : risque directionnel', _fmt(detail.commodityDirectionalRisk), _fmt(detail.commodityDirectionalRisk * mult)],
          ['Produits de base : risque de base', _fmt(detail.commodityBasisRisk), _fmt(detail.commodityBasisRisk * mult)],
        ] else
          ['Produits de base', 'Aucune position saisie', '-'],
      ],
      pied: 'TOTAL Actifs pondérés au titre du risque de marché',
    );
  }

  // ── EP21 - Risque opérationnel, approche indicateur de base ────────────────
  // Structure officielle : section A « Calcul du produit brut » (RO001 à
  // RO009) puis section B « Calcul des actifs pondérés » (produit brut des
  // trois exercices, moyenne, alpha, exigence, APR).
  Widget _buildEp04(DashColors c, FodepApercu apercu) {
    final aib = _calculAib;
    final exercices = aib?.anneesSaisies ?? const <PnbAnnuelView>[];
    final p = apercu.postes;
    final ro009 = apercu.totaux['ro009'] ?? 0;

    final lignes = <List<String>>[
      ["Produit d'exploitation bancaire", 'EP21', _fmtM(p['ro001'] ?? 0)],
      ['Moins-values réalisées sur cessions de titres du portefeuille bancaire', 'EP21', _fmtM(p['ro002'] ?? 0)],
      ["(-) Charges d'exploitation bancaire", 'EP21', _fmtM(p['ro003'] ?? 0)],
      ['(-) Plus-values réalisées sur cessions de titres du portefeuille bancaire', 'EP21', _fmtM(p['ro005'] ?? 0)],
      ["(+/-) Produits nets d'exploitation bancaire exceptionnels ou inhabituels", 'EP21', _fmtM(p['ro006'] ?? 0)],
      ["(-) Produits provenant des activités d'assurance", 'EP21', _fmtM(p['ro007'] ?? 0)],
      ['(-) Produits des entités financières exclues du périmètre prudentiel', 'EP21', _fmtM(p['ro008'] ?? 0)],
      ['Total du produit brut', 'EP21', _fmtM(ro009)],
      for (int i = 0; i < 3; i++)
        () {
          final rang = exercices.length - 3 + i;
          final ex = rang >= 0 && rang < exercices.length ? exercices[rang] : null;
          final libelle = ['ANNÉE-3 (a)', 'ANNÉE-2 (b)', 'ANNÉE-1 (c)'][i];
          return [
            'Produit brut $libelle',
            ex == null ? '-' : ex.annee.toString(),
            ex == null ? _fmt(0) : '${_fmt(ex.produitBrutTotal)}${ex.pnbPositif ? '' : '  (exclu, ≤ 0)'}',
          ];
        }(),
      ['Moyenne du produit brut > 0  (d)', 'EP21', _fmt(aib?.pnbMoyen ?? 0)],
      ['Alpha  (e)', 'EP21', '${((aib?.alpha ?? 0.15) * 100).toStringAsFixed(0)} %'],
      ['Exigences de fonds propres  (f = d × e)', 'EP21', _fmt(aib?.kIb ?? 0)],
      ['Actifs pondérés des risques  (g = f × 12,5)', 'EP08', _fmt(apercu.apr.rwaOperationnel)],
    ];

    return _tableauFixe(
      c,
      titre: "EXIGENCES DE FONDS PROPRES AU TITRE DE L'APPROCHE INDICATEUR DE BASE",
      colonnes: const ['Poste', 'Réf. / Exercice', 'Montant'],
      flex: const [6, 2, 3],
      lignes: lignes,
      pied: '',
    );
  }

  // ── EP33 - Ratio de levier ───────────────────────────────────────────────
  // Structure officielle : A. expositions au bilan (RL001-RL004),
  // B. dérivés (RL005-RL007), C. opérations assimilables à des pensions
  // (RL008-RL010), D. hors bilan (RL011-RL013), E. calcul du ratio
  // (RL014, RL015, RA005).
  Widget _buildRatioLevier(DashColors c, FodepApercu apercu) {
    final levier = apercu.ratios['leverage'];
    final t1 = apercu.totaux['fpi29'] ?? 0;
    final p = apercu.postes;
    final tx = apercu.totaux;
    final rl015 = tx['rl015'] ?? 0;
    // Sans briques saisies, le dénominateur reste celui que le backend a
    // effectivement retenu : on le reconstitue depuis le ratio publié plutôt
    // que d'afficher un zéro qui contredirait le ratio affiché juste après.
    final expositionTotale = rl015 > 0
        ? rl015
        : ((levier != null && levier.value > 0) ? t1 / (levier.value / 100) : 0.0);

    return _tableauFixe(
      c,
      titre: 'RATIO DE LEVIER',
      colonnes: const ['Poste', 'Référence', 'Montant'],
      flex: const [6, 2, 3],
      lignes: [
        ['Actifs au bilan', 'EP33', _fmt(p['rl001'] ?? 0)],
        ['(-) Expositions au bilan déduites des fonds propres', 'EP33', _fmt(p['rl002'] ?? 0)],
        ['(-) Expositions sur opérations assimilables à des pensions', 'EP33', _fmt(p['rl003'] ?? 0)],
        ['Total des expositions au bilan', 'EP33', _fmt(tx['rl004'] ?? 0)],
        ['Dérivés non couverts par un accord-cadre de compensation admissible', 'EP33', _fmt(p['rl005'] ?? 0)],
        ['Dérivés couverts par un accord-cadre de compensation admissible', 'EP33', _fmt(p['rl006'] ?? 0)],
        ['Total des expositions sur dérivés', 'EP33', _fmt(tx['rl007'] ?? 0)],
        ["Opérations assimilables à des pensions à titre d'intermédiaire", 'EP33', _fmt(p['rl008'] ?? 0)],
        ['Autres opérations assimilables à des pensions', 'EP33', _fmt(p['rl009'] ?? 0)],
        ['Total des expositions sur opérations assimilables à des pensions', 'EP33', _fmt(tx['rl010'] ?? 0)],
        ['Engagements de financement', 'EP33', _fmt(p['rl011'] ?? 0)],
        ['Autres engagements hors bilan', 'EP33', _fmt(p['rl012'] ?? 0)],
        ['Total des expositions sur engagement hors bilan', 'EP33', _fmt(tx['rl013'] ?? 0)],
        ['Fonds propres de base T1', 'EP03 / EP05', _fmt(t1)],
        ['Exposition totale', 'EP33', _fmt(expositionTotale)],
        ['Ratio de levier (%)', 'EP01', levier == null ? '-' : '${levier.value.toStringAsFixed(2)} %'],
        ['Niveau à respecter (%)', 'EP01', levier == null ? '-' : '${levier.threshold.toStringAsFixed(2)} %'],
        ["Situation de l'établissement", 'EP01', levier == null ? '-' : (levier.conforme ? 'CONFORME' : 'INFRACTION')],
      ],
      pied: '',
    );
  }

  Widget _tableauFixe(
    DashColors c, {
    required String titre,
    required List<String> colonnes,
    required List<int> flex,
    required List<List<String>> lignes,
    required String pied,
  }) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: sombre
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF0F1B2D).withValues(alpha: 0.06),
            blurRadius: sombre ? 30 : 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titre.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: c.surface,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.navy,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titre.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF172554), Color(0xFF1E3A8A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                for (int i = 0; i < colonnes.length; i++)
                  Expanded(
                    flex: flex[i],
                    child: Text(
                      colonnes[i],
                      textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int idx = 0; idx < lignes.length; idx++)
                      Builder(
                        builder: (context) {
                          final ligne = lignes[idx];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: idx.isEven ? c.surface : c.surfaceAlt,
                              border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                for (int i = 0; i < ligne.length; i++)
                                  Expanded(
                                    flex: flex[i],
                                    child: Text(
                                      ligne[i],
                                      textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontFeatures: i > 0 ? Dash.tabular : null,
                                        fontWeight: i == ligne.length - 1 ? FontWeight.w700 : (i == 0 ? FontWeight.w500 : FontWeight.w400),
                                        color: i == ligne.length - 1
                                            ? c.navy
                                            : (i == 0 ? c.ink : c.muted),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
                ),
              ),
            ),
          ),
          if (pied.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF172554),
                border: Border(top: BorderSide(color: c.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: flex[0],
                    child: Text(
                      pied.contains(' : ') ? pied.substring(0, pied.lastIndexOf(' : ')) : pied,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (flex.length > 1)
                    Expanded(
                      flex: flex[1],
                      child: const SizedBox.shrink(),
                    ),
                  if (flex.length > 2)
                    Expanded(
                      flex: flex[2],
                      child: Text(
                        pied.contains(' : ') ? pied.substring(pied.lastIndexOf(' : ') + 3) : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFeatures: Dash.tabular,
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

  // ── EP29 - Grands risques du portefeuille bancaire et de négociation ───────
  /// Une contrepartie est un grand risque dès que son exposition atteint
  /// 10 % des fonds propres de base T1 (notice, EP29).
  ///
  /// La notice signale elle-même une ambiguïté sur le critère : le texte
  /// introductif rapporte le total des expositions au T1, le descriptif des
  /// colonnes rapporte la somme des actifs pondérés au T1. Elle demande de
  /// retenir par prudence le plus contraignant - c'est le maximum des deux
  /// rapports qui est utilisé ici, et affiché comme tel.
  List<_GrandRisque> _calculerGrandsRisques(double t1) {
    final analyse = _analyseCredit;
    if (analyse == null || t1 <= 0) return const [];

    // Une même contrepartie peut apparaître dans plusieurs catégories
    // prudentielles : le grand risque se juge sur son exposition totale.
    final parNom = <String, _GrandRisque>{};
    for (final agent in analyse.agents) {
      for (final cp in agent.counterparties) {
        final nom = cp.name.trim();
        if (nom.isEmpty) continue;
        final existant = parNom[nom];
        parNom[nom] = _GrandRisque(
          nom: nom,
          expositionBrute: (existant?.expositionBrute ?? 0) + cp.grossExposure,
          expositionNette: (existant?.expositionNette ?? 0) + cp.exposure,
          rwa: (existant?.rwa ?? 0) + cp.rwa,
          t1: t1,
        );
      }
    }

    final grands = parNom.values.where((g) => g.pourcentageT1 >= 10.0).toList()
      ..sort((a, b) => b.pourcentageT1.compareTo(a.pourcentageT1));
    return grands;
  }

  Widget _buildEp29(DashColors c, FodepApercu apercu) {
    final t1 = apercu.totaux['fpi29'] ?? 0;
    final grands = _calculerGrandsRisques(t1);

    if (grands.isEmpty) {
      return _tableauFixe(
        c,
        titre: 'GRANDS RISQUES DU PORTEFEUILLE BANCAIRE ET DE NÉGOCIATION',
        colonnes: const ['Contrepartie', 'Exposition nette', '% des FP T1'],
        flex: const [5, 3, 2],
        lignes: const [],
        pied: '',
      );
    }

    return _tableauFixe(
      c,
      titre: 'GRANDS RISQUES DU PORTEFEUILLE BANCAIRE ET DE NÉGOCIATION',
      colonnes: const ['Contrepartie', 'Exposition initiale totale', 'Exposition nette', '% des FP T1'],
      flex: const [5, 3, 3, 2],
      lignes: [
        for (final g in grands)
          [
            g.nom,
            _fmt(g.expositionBrute),
            _fmt(g.expositionNette),
            '${g.pourcentageT1.toStringAsFixed(2)} %',
          ],
      ],
      pied: '',
    );
  }



}

/// Une contrepartie candidate au statut de grand risque (EP29).
class _GrandRisque {
  const _GrandRisque({
    required this.nom,
    required this.expositionBrute,
    required this.expositionNette,
    required this.rwa,
    required this.t1,
  });

  final String nom;
  final double expositionBrute;
  final double expositionNette;
  final double rwa;
  final double t1;

  /// Le plus contraignant des deux rapports admis par la notice.
  double get pourcentageT1 {
    if (t1 <= 0) return 0;
    final surExposition = expositionNette / t1 * 100;
    final surRwa = rwa / t1 * 100;
    return surExposition > surRwa ? surExposition : surRwa;
  }
}

// ── Widgets locaux ────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// ── Composants Réutilisables pour le Design System FODEP ─────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class FodepTable extends StatelessWidget {
  const FodepTable({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: sombre
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF0F1B2D).withValues(alpha: 0.06),
            blurRadius: sombre ? 30 : 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class FodepTableHeader extends StatelessWidget {
  const FodepTableHeader({super.key, required this.col1, required this.col2, required this.col3, this.flex1 = 5, this.flex2 = 2, this.flex3 = 3});
  final String col1;
  final String col2;
  final String col3;
  final int flex1;
  final int flex2;
  final int flex3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF1E3A8A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: flex1, child: Text(col1, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))),
          if (flex2 > 0) Expanded(flex: flex2, child: Text(col2, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))),
          Expanded(flex: flex3, child: Text(col3, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))),
        ],
      ),
    );
  }
}

class FodepTableGroup extends StatelessWidget {
  const FodepTableGroup({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 11),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border(
          bottom: BorderSide(color: c.divider, width: 0.5),
          top: BorderSide(color: c.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 11,
            decoration: BoxDecoration(
              color: c.navy,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class FodepTableRow extends StatelessWidget {
  const FodepTableRow({
    super.key, 
    required this.label, 
    required this.ref, 
    required this.value, 
    this.isLast = false,
    this.flex1 = 5,
    this.flex2 = 2,
    this.flex3 = 3,
    this.isBold = false,
    this.isIndent = false,
  });
  
  final String label;
  final String ref;
  final String value;
  final bool isLast;
  final int flex1;
  final int flex2;
  final int flex3;
  final bool isBold;
  final bool isIndent;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      padding: EdgeInsets.only(left: isIndent ? 40 : 20, right: 20, top: 12, bottom: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: flex1, 
            child: Text(label, style: TextStyle(fontSize: 12.5, color: isBold ? c.ink : c.navy, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400))
          ),
          if (flex2 > 0)
            Expanded(
              flex: flex2, 
              child: Text(ref, style: TextStyle(fontSize: 11.5, color: c.muted, fontWeight: FontWeight.w500))
            ),
          Expanded(
            flex: flex3, 
            child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: c.ink, fontWeight: FontWeight.w600, fontFeatures: Dash.tabular))
          ),
        ],
      ),
    );
  }
}

class _OngletEp extends StatelessWidget {
  const _OngletEp({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final DashColors c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF172554) : c.muted,
          ),
        ),
      ),
    );
  }
}

// ── EP01 - Carte de composante de fonds propres (CET1 / AT1 / T2 / effectifs) ──

class _BlocFondsPropres {
  const _BlocFondsPropres({
    required this.groupe,
    required this.titre,
    required this.sousTitre,
    required this.code,
    required this.total,
  });

  final String groupe;
  final String titre;
  final String sousTitre;
  final String? code;
  final double total;
}

class _CarteFondsPropres extends StatelessWidget {
  const _CarteFondsPropres({
    required this.bloc,
    required this.apercu,
    required this.codes,
    required this.fmt,
    required this.c,
  });

  final _BlocFondsPropres bloc;
  final FodepApercu apercu;
  final List<CodeDispru> codes;
  final String Function(double) fmt;
  final DashColors c;

  @override
  Widget build(BuildContext context) {
    final lignes = codes.where((cd) => cd.groupe == bloc.groupe).toList();
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: sombre
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF0F1B2D).withValues(alpha: 0.06),
            blurRadius: sombre ? 30 : 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête : indicateur principal ────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF172554), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bloc.titre,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                if (bloc.sousTitre.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    bloc.sousTitre,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FodepCompteur(
                        valeur: bloc.total,
                        format: fmt,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFeatures: Dash.tabular,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FCFA',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Détail des postes ──────────────────────────────────────────
          if (lignes.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(flex: 7, child: Text('LIBELLÉ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6))),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Text('MONTANT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6), textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 1, thickness: Dash.hairline, color: c.divider),
            Expanded(
              child: Scrollbar(
                thumbVisibility: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      for (int i = 0; i < lignes.length; i++)
                        _LignePoste(
                          index: i + 1,
                          code: lignes[i],
                          valeur: apercu.postes[lignes[i].code.toLowerCase()] ?? 0,
                          fmt: fmt,
                          c: c,
                        ),
                      const SizedBox(height: 8),
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

class _LignePoste extends StatelessWidget {
  const _LignePoste({
    required this.index,
    required this.code,
    required this.valeur,
    required this.fmt,
    required this.c,
  });

  final int index;
  final CodeDispru code;
  final double valeur;
  final String Function(double) fmt;
  final DashColors c;

  @override
  Widget build(BuildContext context) {
    final estDeduction = code.estDeduction;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: c.border, width: Dash.hairline),
            ),
            child: Text(
              '$index',
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: c.muted),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 7,
            child: Text(
              estDeduction ? '${code.label}  (déduction)' : code.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: c.ink,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              fmt(valeur),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: Dash.tabular,
                color: estDeduction && valeur < 0 ? c.sousMinimum : Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneValeur extends StatelessWidget {
  const _LigneValeur({
    required this.label,
    required this.valeur,
    required this.c,
  });

  final String label;
  final String valeur;
  final DashColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.ink,
              ),
            ),
          ),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modèles locaux pour l'État de conformité ─────────────────────────────────

enum _Statut { conforme, infraction, nd }

class _ConformiteSection {
  const _ConformiteSection({required this.titre, required this.couleur, required this.lignes});
  final String titre;
  final Color couleur;
  final List<_LigneConformite> lignes;
}

class _LigneConformite {
  const _LigneConformite({
    required this.code,
    required this.libelle,
    required this.reference,
    required this.seuil,
    required this.observe,
    required this.statut,
  });
  final String code;
  final String libelle;
  final String reference;
  final double? seuil;
  final double? observe;
  final _Statut statut;
}



// ── Normes sur les opérations (EP34-EP38 → RA006-RA011) ─────────────────────
const Color _deepblue = Color(0xFF172554);

enum _SousOngletNormes {
  participations('Participations', Icons.business_outlined, 'EP34 / EP35'),
  immobilisations('Immobilisations', Icons.account_balance_outlined, 'EP36 / EP37'),
  prets('Prêts & Dirigeants', Icons.people_outline, 'EP38'),
  complements('Compléments RO & Levier', Icons.tune_outlined, 'EP21 / EP33');

  const _SousOngletNormes(this.label, this.icon, this.ref);
  final String label;
  final IconData icon;
  final String ref;
}

class _InfoPrudentielle {
  const _InfoPrudentielle({
    required this.titre,
    required this.reference,
    this.description,
    required this.regles,
  });

  final String titre;
  final String reference;
  final String? description;
  final List<(String, String)> regles;
}

class _InfoTooltipBouton extends StatelessWidget {
  const _InfoTooltipBouton({
    required this.info,
    this.iconColor = Colors.white,
    this.backgroundColor,
    this.iconSize = 14,
    this.padding = const EdgeInsets.all(3.5),
  });

  final _InfoPrudentielle info;
  final Color iconColor;
  final Color? backgroundColor;
  final double iconSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      richMessage: TextSpan(
        children: [
          // Titre
          TextSpan(
            text: '${info.titre}\n',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),
          // Référence
          TextSpan(
            text: '${info.reference.toUpperCase()}\n\n',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
              letterSpacing: 0.5,
              height: 1.2,
            ),
          ),
          // Description
          if (info.description != null && info.description!.isNotEmpty) ...[
            TextSpan(
              text: '${info.description}\n\n',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
          ],
          // Règles
          for (int i = 0; i < info.regles.length; i++) ...[
            const TextSpan(
              text: '• ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
                height: 1.45,
              ),
            ),
            TextSpan(
              text: '${info.regles[i].$1} : ',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                height: 1.45,
              ),
            ),
            TextSpan(
              text: '${info.regles[i].$2}${i < info.regles.length - 1 ? '\n\n' : ''}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: const Color(0xFFCBD5E1), width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      waitDuration: const Duration(milliseconds: 100),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.info_outline, size: iconSize, color: iconColor),
      ),
    );
  }
}

class _NormesOperationsPanel extends StatefulWidget {
  const _NormesOperationsPanel({
    required this.service,
    required this.apercu,
    required this.onSaved,
  });

  final FodepService service;
  final FodepApercu apercu;
  final VoidCallback onSaved;

  @override
  State<_NormesOperationsPanel> createState() => _NormesOperationsPanelState();
}

class _NormesOperationsPanelState extends State<_NormesOperationsPanel> {
  _SousOngletNormes _ongletActif = _SousOngletNormes.participations;

  static const _postesImmobilisations = <(String, String, String)>[
    ('im001', 'Immobilisations hors exploitation avant ajustement', 'Valeur brute des actifs non affectés à l\'activité bancaire'),
    ('im002', 'Acquises par réalisation de garantie (< 2 ans)', 'Biens reçus en recouvrement depuis moins de deux ans'),
    ('im003', 'Acquises par réalisation de garantie (> 2 ans, dérog. CB)', 'Biens conservés avec autorisation de la Commission Bancaire'),
    ('pa084', 'Participations dans les sociétés immobilières', 'Titres de filiales et participations immobilières'),
    ('im007', 'Immobilisations d\'exploitation ajustées', 'Bâtiments, équipements et matériel informatique d\'exploitation'),
    ('pa106', 'Total des participations (toutes sections EP34)', 'Somme des participations financières et non financières'),
  ];

  static const _postesProduitBrut = <(String, String, bool)>[
    ('ro001', "Produit d'exploitation bancaire (PEB)", true),
    ('ro002', 'Moins-values de cession de titres du portefeuille bancaire', true),
    ('ro003', "Charges d'exploitation bancaire", false),
    ('ro005', 'Plus-values de cession de titres du portefeuille bancaire', false),
    ('ro006', "Produits nets d'exploitation bancaire exceptionnels", true),
    ('ro007', "Produits provenant des activités d'assurance", false),
    ('ro008', 'Produits des entités financières exclues du périmètre', false),
  ];

  static const _postesLevier = <(String, String, String)>[
    ('rl001', 'Actifs au bilan', 'Total des actifs comptables'),
    ('rl002', 'Expositions au bilan déduites des fonds propres', 'Déductions prudentielles applicables'),
    ('rl003', 'Expositions sur opérations assimilables à des pensions', 'Ajustements pour pensions livrées'),
    ('rl005', 'Dérivés non couverts par un accord-cadre admissible', 'Juste valeur de remplacement + add-on'),
    ('rl006', 'Dérivés couverts par un accord-cadre admissible', 'Montant net sous accord de compensation'),
    ('rl008', "Pensions à titre d'intermédiaire", 'Opérations de pension pour compte de tiers'),
    ('rl009', 'Autres opérations assimilables à des pensions', 'Pensions standard'),
    ('rl011', 'Engagements de financement', 'Lignes de crédit confirmées et garanties données'),
    ('rl012', 'Autres engagements hors bilan', 'Autres engagements conditionnels'),
  ];

  static const _categoriesPrets = <(String, String)>[
    ('a', 'Actionnaires détenant ≥ 10 % des droits de vote'),
    ('b', 'Membres de l\'organe délibérant (Conseil d\'administration)'),
    ('c', 'Membres de l\'organe exécutif (Direction Générale)'),
    ('d', 'Commissaires aux comptes'),
    ('e', 'Personnel de direction'),
    ('f', 'Cadres moyens et supérieurs'),
    ('g', 'Personnel d\'exécution'),
    ('h', 'Autres parties liées et apparentées'),
  ];

  bool _chargement = true;
  bool _enregistrement = false;
  String? _erreur;
  String? _succes;
  List<ParticipationEntry> _participations = [];
  late final Map<String, TextEditingController> _controleurs;

  @override
  void initState() {
    super.initState();
    _controleurs = {
      for (final p in _postesImmobilisations) p.$1: _controleur(p.$1),
      for (final p in _postesProduitBrut) p.$1: _controleur(p.$1),
      for (final p in _postesLevier) p.$1: _controleur(p.$1),
      for (final cat in _categoriesPrets) 'pr001${cat.$1}': _controleur('pr001${cat.$1}'),
      for (final cat in _categoriesPrets) 'pr002${cat.$1}': _controleur('pr002${cat.$1}'),
    };
    _chargerParticipations();
  }

  TextEditingController _controleur(String code) {
    final valeur = widget.apercu.postes[code] ?? 0;
    final ctrl = TextEditingController(text: valeur == 0 ? '' : _formatNombre(valeur));
    ctrl.addListener(() => setState(() {}));
    return ctrl;
  }

  String _formatNombre(double v) {
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return s.replaceAll('.', ',');
  }

  double _parseNombre(String s) => double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

  @override
  void didUpdateWidget(covariant _NormesOperationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apercu.periode != widget.apercu.periode) {
      for (final entry in _controleurs.entries) {
        final valeur = widget.apercu.postes[entry.key] ?? 0;
        entry.value.text = valeur == 0 ? '' : _formatNombre(valeur);
      }
      _chargerParticipations();
    }
  }

  @override
  void dispose() {
    for (final c in _controleurs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerParticipations() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final participations = await widget.service.listerParticipations(periode: widget.apercu.periode);
      if (!mounted) return;
      setState(() {
        _participations = participations;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Chargement du registre impossible : $e';
        _chargement = false;
      });
    }
  }

  Future<void> _sauvegarderParticipations() async {
    final periode = widget.apercu.periode;
    if (periode == null) return;
    setState(() {
      _enregistrement = true;
      _erreur = null;
      _succes = null;
    });
    try {
      final lignes = await widget.service.enregistrerParticipations(periode: periode, lignes: _participations);
      if (!mounted) return;
      setState(() {
        _participations = lignes;
        _enregistrement = false;
        _succes = 'Registre des participations enregistré avec succès.';
      });
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Enregistrement impossible : $e';
        _enregistrement = false;
      });
    }
  }

  Future<void> _sauvegarderPostes() async {
    final periode = widget.apercu.periode;
    if (periode == null) return;
    setState(() {
      _enregistrement = true;
      _erreur = null;
      _succes = null;
    });
    try {
      final postes = Map<String, double>.from(widget.apercu.postes);
      for (final entry in _controleurs.entries) {
        postes[entry.key] = _parseNombre(entry.value.text);
      }
      await widget.service.enregistrer(periode: periode, postes: postes);
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _succes = 'Données enregistrées avec succès.';
      });
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Enregistrement impossible : $e';
        _enregistrement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final periode = widget.apercu.periode;

    if (periode == null) {
      return const FodepNotice(
        status: DashStatus.sousMinimum,
        texte: "Aucun arrêté enregistré : renseignez d'abord une période (import ou saisie des fonds propres, onglet Fonds propres) avant de compléter les limites sur opérations.",
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_erreur != null) ...[
          FodepNotice(status: DashStatus.sousMinimum, texte: _erreur!),
          const SizedBox(height: 12),
        ],
        if (_succes != null) ...[
          FodepNotice(status: DashStatus.conforme, texte: _succes!),
          const SizedBox(height: 12),
        ],

        // ── Sélecteur de sous-onglets + Icône Info avec infobulle au survol ───
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: c.border, width: Dash.hairline),
                ),
                child: Row(
                  children: [
                    for (final tab in _SousOngletNormes.values)
                      Expanded(
                        child: _buildBoutonOnglet(c, tab),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _InfoTooltipBouton(
              info: const _InfoPrudentielle(
                titre: 'NORMES PRUDENTIELLES SUR LES OPÉRATIONS',
                reference: 'Circulaire BCEAO & Loi Bancaire',
                description: 'Ce module regroupe la collecte des postes extra-comptables nécessaires à l\'évaluation des plafonds prudentiels et des coefficients réglementaires :',
                regles: [
                  ('EP34 / EP35', 'Contrôle des participations dans les entités commerciales (plafonds 15 % T1 et 60 % FP effectifs).'),
                  ('EP36 / EP37', 'Limites d\'engagement dans les immobilisations (15 % hors exploitation et 100 % global).'),
                  ('EP38', 'Encadrement des concours et engagements aux actionnaires, dirigeants et personnel (20 % max).'),
                  ('EP21 & EP33', 'Ajustements pour le Risque Opérationnel et éléments d\'exposition pour le Ratio de Levier.'),
                ],
              ),
              iconColor: _deepblue,
              iconSize: 18,
              padding: const EdgeInsets.all(9),
              backgroundColor: c.surface,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Zone défilante avec le contenu ──────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildContenuOnglet(c),
          ),
        ),

        const SizedBox(height: 8),

        // ── Barre d'actions FIXE en bas ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: c.border, width: Dash.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_ongletActif == _SousOngletNormes.participations)
                _boutonAjouter(c, 'Ajouter une participation', () {
                  setState(() {
                    _participations = [
                      ..._participations,
                      const ParticipationEntry(denominationEmettrice: '', capitalEmettrice: 0, montantNet: 0),
                    ];
                  });
                })
              else
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: c.muted),
                    const SizedBox(width: 6),
                    Text(
                      'Montants exprimés en millions de FCFA (M)',
                      style: TextStyle(fontSize: 11.5, color: c.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              const Spacer(),
              _boutonEnregistrer(
                _ongletActif == _SousOngletNormes.participations
                    ? _sauvegarderParticipations
                    : _sauvegarderPostes,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoutonOnglet(DashColors c, _SousOngletNormes tab) {
    final actif = _ongletActif == tab;
    return InkWell(
      onTap: () => setState(() {
        _ongletActif = tab;
        _erreur = null;
        _succes = null;
      }),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: actif ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: actif
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 16,
              color: actif ? _deepblue : c.muted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tab.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  color: actif ? _deepblue : c.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: actif ? _deepblue.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                tab.ref,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: actif ? _deepblue : c.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenuOnglet(DashColors c) {
    switch (_ongletActif) {
      case _SousOngletNormes.participations:
        return _buildSectionParticipations(c);
      case _SousOngletNormes.immobilisations:
        return _buildSectionImmobilisations(c);
      case _SousOngletNormes.prets:
        return _buildSectionPrets(c);
      case _SousOngletNormes.complements:
        return _buildSectionComplements(c);
    }
  }

  // ── 1. Onglet Participations (EP34 / EP35) ──────────────────────────────────
  Widget _buildSectionParticipations(DashColors c) {
    final totalMontant = _participations.fold<double>(0, (s, p) => s + p.montantNet);
    final fpEffectifs = widget.apercu.totaux['fpe40'] ?? 0;

    return _panneau(
      c,
      titre: 'REGISTRE DES PARTICIPATIONS DANS LES ENTITÉS COMMERCIALES (EP34)',
      infoTooltip: const _InfoPrudentielle(
        titre: 'RÈGLES PRUDENTIELLES SUR LES PARTICIPATIONS',
        reference: 'EP34 & EP35 · DISPRU RA006, RA007 & RA008',
        description: 'L\'établissement bancaire doit respecter deux plafonds stricts sur les détentions de titres commerciaux :',
        regles: [
          ('Plafond individuel (RA006 & RA007)', 'Maximum 15 % des fonds propres de base T1 par entité, et 25 % du capital social de l\'émettrice.'),
          ('Plafond global (RA008)', 'Le cumul de toutes les participations commerciales ne peut excéder 60 % des fonds propres effectifs.'),
        ],
      ),
      kpis: [
        _kpiPillHeader('Total net', '${_formatNombre(totalMontant)} M'),
        if (fpEffectifs > 0)
          _kpiPillHeader(
            'Part FP effectifs',
            '${((totalMontant / fpEffectifs) * 100).toStringAsFixed(1)} % / 60 %',
            couleurValeur: (totalMontant / fpEffectifs) > 0.6 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
          ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 4, child: Text('DÉNOMINATION DE L\'ÉMETTRICE', style: DashText.eyebrow(c, color: c.muted))),
                const SizedBox(width: 140, child: Text('CAPITAL ÉMETTRICE (M)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
                const SizedBox(width: 16),
                const SizedBox(width: 140, child: Text('MONTANT NET DÉTENU (M)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
                const SizedBox(width: 16),
                const SizedBox(width: 100, child: Text('% DÉTENTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
                const SizedBox(width: 60),
              ],
            ),
          ),
          if (_chargement)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
          else if (_participations.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.business_center_outlined, size: 36, color: c.muted.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text('Aucune participation enregistrée pour cet arrêté.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.muted)),
                  const SizedBox(height: 4),
                  Text('Utilisez le bouton "Ajouter une participation" en bas de l\'écran pour déclarer vos détentions.', style: TextStyle(fontSize: 11, color: c.muted)),
                ],
              ),
            )
          else
            for (int i = 0; i < _participations.length; i++)
              Builder(builder: (context) {
                final p = _participations[i];
                final pct = p.capitalEmettrice > 0 ? (p.montantNet / p.capitalEmettrice * 100) : 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: i.isEven ? c.surface : c.surfaceAlt,
                    border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
                      ),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          initialValue: p.denominationEmettrice,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Ex : Société Commerciale SA',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: c.border, width: Dash.hairline)),
                          ),
                          onChanged: (v) => _participations[i] = _participations[i].copyWith(denominationEmettrice: v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          initialValue: p.capitalEmettrice == 0 ? '' : _formatNombre(p.capitalEmettrice),
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: Dash.tabular),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '0,00',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: c.border, width: Dash.hairline)),
                          ),
                          onChanged: (v) => setState(() => _participations[i] = _participations[i].copyWith(capitalEmettrice: _parseNombre(v))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          initialValue: p.montantNet == 0 ? '' : _formatNombre(p.montantNet),
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _deepblue, fontFeatures: Dash.tabular),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '0,00',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: c.border, width: Dash.hairline)),
                          ),
                          onChanged: (v) => setState(() => _participations[i] = _participations[i].copyWith(montantNet: _parseNombre(v))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 100,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: pct > 25 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            pct > 0 ? '${pct.toStringAsFixed(1)} %' : '-',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: pct > 25 ? c.sousMinimum : c.ink,
                              fontFeatures: Dash.tabular,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                          tooltip: 'Supprimer',
                          onPressed: () => setState(() => _participations = [..._participations]..removeAt(i)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }

  // ── 2. Onglet Immobilisations (EP36 / EP37) ─────────────────────────────────
  Widget _buildSectionImmobilisations(DashColors c) {
    final fpEffectifs = widget.apercu.totaux['fpe40'] ?? 0;
    final horsExploitation = _parseNombre(_controleurs['im001']?.text ?? '0');
    final immosExploit = _parseNombre(_controleurs['im007']?.text ?? '0');
    final totalPart = _parseNombre(_controleurs['pa106']?.text ?? '0');
    final totalGlobal = horsExploitation + immosExploit + totalPart;

    return _panneau(
      c,
      titre: 'POSTES D\'IMMOBILISATIONS ET PARTICIPATIONS (EP36 / EP37)',
      infoTooltip: const _InfoPrudentielle(
        titre: 'RÈGLES PRUDENTIELLES SUR LES IMMOBILISATIONS',
        reference: 'EP36 & EP37 · DISPRU RA009 & RA010',
        description: 'La réglementation BCEAO encadre l\'engagement des fonds bancaires dans les actifs immobilisés :',
        regles: [
          ('Plafond hors exploitation (RA009)', 'Maximum 15 % des fonds propres effectifs pour les biens non affectés à l\'activité bancaire.'),
          ('Plafond global (RA010)', 'Le total des immobilisations nettes et participations ne doit pas dépasser 100 % des fonds propres effectifs.'),
        ],
      ),
      kpis: [
        if (fpEffectifs > 0) ...[
          _kpiPillHeader(
            'Hors exploitation',
            '${((horsExploitation / fpEffectifs) * 100).toStringAsFixed(1)} % / 15 %',
            couleurValeur: (horsExploitation / fpEffectifs) > 0.15 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
          ),
          _kpiPillHeader(
            'Total immobilisé',
            '${((totalGlobal / fpEffectifs) * 100).toStringAsFixed(1)} % / 100 %',
            couleurValeur: (totalGlobal / fpEffectifs) > 1.0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
          ),
        ],
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const SizedBox(width: 60, child: Text('CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(child: Text('INTITULÉ DU POSTE & DESCRIPTION', style: DashText.eyebrow(c, color: c.muted))),
                const SizedBox(width: 140, child: Text('MONTANT (M FCFA)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
              ],
            ),
          ),
          for (int idx = 0; idx < _postesImmobilisations.length; idx++)
            Builder(builder: (context) {
              final item = _postesImmobilisations[idx];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: idx.isEven ? c.surface : c.surfaceAlt,
                  border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.$1.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text(item.$3, style: TextStyle(fontSize: 11, color: c.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _champ(c, _controleurs[item.$1]!, width: 140),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── 3. Onglet Prêts aux Dirigeants & Personnel (EP38) ────────────────────────
  Widget _buildSectionPrets(DashColors c) {
    final fpEffectifs = widget.apercu.totaux['fpe40'] ?? 0;
    double totalConcours = 0;
    double totalEngagements = 0;
    for (final cat in _categoriesPrets) {
      totalConcours += _parseNombre(_controleurs['pr001${cat.$1}']?.text ?? '0');
      totalEngagements += _parseNombre(_controleurs['pr002${cat.$1}']?.text ?? '0');
    }
    final totalGlobalPrets = totalConcours + totalEngagements;

    return _panneau(
      c,
      titre: 'VENTILATION PAR CATÉGORIE DE BÉNÉFICIAIRE (EP38)',
      infoTooltip: const _InfoPrudentielle(
        titre: 'PRÊTS AUX ACTIONNAIRES, DIRIGEANTS ET PERSONNEL',
        reference: 'EP38 · ARTICLE 85 LOI BANCAIRE (RA011)',
        description: 'L\'article 85 de la loi bancaire encadre les concours et engagements octroyés aux personnes liées à la gouvernance ou au personnel :',
        regles: [
          ('Concours et engagements', 'Comprend les crédits directs (PR001) et les engagements par signature (PR002).'),
          ('Plafond global (RA011)', 'Le total des concours et engagements ne peut excéder 20 % des fonds propres effectifs.'),
        ],
      ),
      kpis: [
        _kpiPillHeader('Total Prêts', '${_formatNombre(totalGlobalPrets)} M'),
        if (fpEffectifs > 0)
          _kpiPillHeader(
            'Part FP',
            '${((totalGlobalPrets / fpEffectifs) * 100).toStringAsFixed(1)} % / 20 %',
            couleurValeur: (totalGlobalPrets / fpEffectifs) > 0.20 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
          ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 4, child: Text('CATÉGORIE DE BÉNÉFICIAIRE', style: DashText.eyebrow(c, color: c.muted))),
                const SizedBox(width: 140, child: Text('CONCOURS PR001 (M)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
                const SizedBox(width: 16),
                const SizedBox(width: 140, child: Text('ENGAGEMENTS PR002 (M)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
                const SizedBox(width: 16),
                const SizedBox(width: 120, child: Text('SOUS-TOTAL (M)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
              ],
            ),
          ),
          for (int idx = 0; idx < _categoriesPrets.length; idx++)
            Builder(builder: (context) {
              final cat = _categoriesPrets[idx];
              final pr001 = _parseNombre(_controleurs['pr001${cat.$1}']?.text ?? '0');
              final pr002 = _parseNombre(_controleurs['pr002${cat.$1}']?.text ?? '0');
              final subtotal = pr001 + pr002;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: idx.isEven ? c.surface : c.surfaceAlt,
                  border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(cat.$1.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.muted)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(cat.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
                    ),
                    const SizedBox(width: 16),
                    _champ(c, _controleurs['pr001${cat.$1}']!, width: 140),
                    const SizedBox(width: 16),
                    _champ(c, _controleurs['pr002${cat.$1}']!, width: 140),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 120,
                      child: Text(
                        subtotal > 0 ? _formatNombre(subtotal) : '-',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: subtotal > 0 ? _deepblue : c.muted,
                          fontFeatures: Dash.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          // Ligne de Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _deepblue.withValues(alpha: 0.05),
            child: Row(
              children: [
                const SizedBox(width: 32),
                const Expanded(
                  flex: 4,
                  child: Text('TOTAL GÉNÉRAL DES PRÊTS ET ENGAGEMENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _deepblue)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  child: Text(_formatNombre(totalConcours), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _deepblue, fontFeatures: Dash.tabular)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  child: Text(_formatNombre(totalEngagements), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _deepblue, fontFeatures: Dash.tabular)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: Text(_formatNombre(totalGlobalPrets), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _deepblue, fontFeatures: Dash.tabular)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Onglet Compléments RO & Levier (EP21 & EP33) ─────────────────────────
  Widget _buildSectionComplements(DashColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Produit Brut (EP21)
        _panneau(
          c,
          titre: '1. AJUSTEMENTS DU PRODUIT BRUT (RISQUE OPÉRATIONNEL - EP21)',
          infoTooltip: const _InfoPrudentielle(
            titre: 'AJUSTEMENTS DU PRODUIT BRUT (RISQUE OPÉRATIONNEL)',
            reference: 'EP21 · CALCUL DES REVENUS OPÉRATIONNELS (AIB / AS)',
            description: 'Permet de retraiter le Produit Net d\'Exploitation Bancaire (PNEB) des éléments non opérationnels :',
            regles: [
              ('Postes d\'addition (+)', 'Réintégrations des charges ou produits exceptionnels prévus par la réglementation.'),
              ('Postes de déduction (-)', 'Retraitements des éléments non récurrents afin d\'obtenir l\'assiette réelle de risque.'),
            ],
          ),
          child: Column(
            children: [
              for (int idx = 0; idx < _postesProduitBrut.length; idx++)
                Builder(builder: (context) {
                  final p = _postesProduitBrut[idx];
                  final estPositif = p.$3;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: idx.isEven ? c.surface : c.surfaceAlt,
                      border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: estPositif ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            estPositif ? '(+) AJOUT' : '(-) DÉDUCTION',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: estPositif ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(p.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
                        ),
                        const SizedBox(width: 16),
                        _champ(c, _controleurs[p.$1]!, width: 140),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Ratio de Levier (EP33)
        _panneau(
          c,
          titre: '2. BRIQUES D\'EXPOSITION DU RATIO DE LEVIER (EP33)',
          infoTooltip: const _InfoPrudentielle(
            titre: 'BRIQUES D\'EXPOSITION DU RATIO DE LEVIER',
            reference: 'EP33 · EXPOSITION GLOBALE RATIO DE LEVIER (RL001 À RL012)',
            description: 'Ces rubriques complètent les actifs bilanciels pour former le dénominateur de l\'exposition totale :',
            regles: [
              ('Hors-bilan (RL011-012)', 'Intègre les engagements de financement et garanties données après application des FCR.'),
              ('Dérivés et pensions', 'Intègre la valeur de remplacement et le risque potentiel futur (add-on).'),
            ],
          ),
          child: Column(
            children: [
              for (int idx = 0; idx < _postesLevier.length; idx++)
                Builder(builder: (context) {
                  final p = _postesLevier[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: idx.isEven ? c.surface : c.surfaceAlt,
                      border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              p.$1.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(p.$3, style: TextStyle(fontSize: 11, color: c.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _champ(c, _controleurs[p.$1]!, width: 140),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ── Widgets utilitaires de présentation ─────────────────────────────────────
  Widget _kpiPillHeader(String label, String valeur, {Color? couleurValeur}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: Dash.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label : ', style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
          Text(valeur, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleurValeur ?? Colors.white)),
        ],
      ),
    );
  }

  Widget _panneau(
    DashColors c, {
    required String titre,
    required Widget child,
    _InfoPrudentielle? infoTooltip,
    List<Widget>? kpis,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _deepblue,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          titre,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (infoTooltip != null) ...[
                        const SizedBox(width: 8),
                        _InfoTooltipBouton(info: infoTooltip),
                      ],
                    ],
                  ),
                ),
                if (kpis != null && kpis.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: kpis,
                  ),
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _champ(DashColors c, TextEditingController controleur, {double width = 120}) {
    return SizedBox(
      width: width,
      height: 36,
      child: TextField(
        controller: controleur,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: Dash.tabular),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: c.border, width: Dash.hairline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: c.border, width: Dash.hairline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: _deepblue, width: 1.3)),
          hintText: '0,00',
        ),
      ),
    );
  }

  Widget _boutonAjouter(DashColors c, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 16, color: _deepblue),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _deepblue)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        side: const BorderSide(color: _deepblue, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }

  Widget _boutonEnregistrer(VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _enregistrement ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _deepblue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_enregistrement) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            ),
            const SizedBox(width: 8),
          ] else ...[
            const Icon(Icons.check, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            _enregistrement ? 'Enregistrement…' : 'Enregistrer les données',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}


