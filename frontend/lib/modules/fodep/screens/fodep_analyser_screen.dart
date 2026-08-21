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
      setState(() {
        _codes = codes;
        _apercu = apercu;
        _analyseCredit = analyseCredit;
        _calculAib = calculAib;
        _capitalMarcheDetail = capitalMarcheDetail;
        _chargement = false;
      });
    } catch (e) {
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
    return GestureDetector(
      onTap: () {
        // TODO: Implémenter l'import d'un ancien FODEP
      },
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border, width: Dash.hairline),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file_rounded,
              size: 14,
              color: c.ink,
            ),
            const SizedBox(width: 8),
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                titleFontSize: 24,
                subtitleFontSize: 13,
                titleSubtitleGap: 4,
                trailing: _buildPastilleArrete(c),
              ),
              const SizedBox(height: 24),
              
              // ── Barre d'onglets (Segmented Control style) ──────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // slate-50
                    borderRadius: BorderRadius.circular(8),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_erreur != null) ...[
                        FodepNotice(status: DashStatus.sousMinimum, texte: _erreur!),
                        const SizedBox(height: 16),
                      ],
                      if (_apercu != null)
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.012),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(_section),
                              child: _buildSection(c),
                            ),
                          ),
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
                FodepTableRow(label: 'Fonds propres de base durs (CET 1)', ref: 'EP03 / EP05', value: _fmt(fpCet1)),
                FodepTableRow(label: 'Fonds propres de base (T1)', ref: 'EP03 / EP05', value: _fmt(fpT1)),
                FodepTableRow(label: 'Fonds propres effectifs (FPE)', ref: 'EP03 / EP05', value: _fmt(fpEffectifs)),

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
      titre: 'TOTAL DES ACTIFS PONDÉRÉS DES RISQUES',
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
          FodepGraphPanel(
            title: 'RATIOS CLÉS - NIVEAU OBSERVÉ VS SEUIL RÉGLEMENTAIRE',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < jauges.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                      child: _buildJauge(c, jauges[i]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FodepGraphPanel(
            title: 'AUTRES NORMES PRUDENTIELLES',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeur = (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final ligne in [division, ...autres])
                      SizedBox(
                        width: largeur,
                        child: _CarteNormeStatut(c: c, ligne: ligne),
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

  /// Jauge radiale d'un ratio de solvabilité / levier.
  Widget _buildJauge(DashColors c, _LigneConformite ligne) {
    return FodepJaugeRadiale(
      libelle: ligne.code == 'RA005' ? 'Levier' : ligne.libelle.split('(').first.trim(),
      valeur: ligne.observe ?? 0,
      seuil: ligne.seuil ?? 0,
      conforme: ligne.statut == _Statut.conforme,
      disponible: ligne.statut != _Statut.nd,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      decoration: const BoxDecoration(
                        color: Color(0xFF172554),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text("TOTAL - repris à l'EP08", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                          Expanded(flex: 3, child: Text(_fmt(analyse.totals.grossExposure), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, fontFeatures: Dash.tabular))),
                          const Expanded(flex: 2, child: SizedBox()),
                          Expanded(flex: 3, child: Text(_fmt(analyse.totals.rwa), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, fontFeatures: Dash.tabular))),
                        ],
                      ),
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
        pied: 'Détail par famille de risque indisponible (module Risque de Marché non initialisé).',
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
      pied: 'TOTAL Actifs pondérés au titre du risque de marché : ${_fmt(detail.marketRwa)} '
          '(exigence de fonds propres agrégée ${_fmt(detail.capitalRequirement)} × 11,11).',
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
      ["Produit d'exploitation bancaire", 'EP21', _fmt(p['ro001'] ?? 0)],
      ['Moins-values réalisées sur cessions de titres du portefeuille bancaire', 'EP21', _fmt(p['ro002'] ?? 0)],
      ["(-) Charges d'exploitation bancaire", 'EP21', _fmt(p['ro003'] ?? 0)],
      ['(-) Plus-values réalisées sur cessions de titres du portefeuille bancaire', 'EP21', _fmt(p['ro005'] ?? 0)],
      ["(+/-) Produits nets d'exploitation bancaire exceptionnels ou inhabituels", 'EP21', _fmt(p['ro006'] ?? 0)],
      ["(-) Produits provenant des activités d'assurance", 'EP21', _fmt(p['ro007'] ?? 0)],
      ['(-) Produits des entités financières exclues du périmètre prudentiel', 'EP21', _fmt(p['ro008'] ?? 0)],
      ['Total du produit brut', 'EP21', _fmt(ro009)],
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
      pied: aib == null || aib.donneesInsuffisantes
          ? 'Aucun produit brut annuel saisi dans le module Risque Opérationnel : les montants restent à zéro.'
          : '${aib.n} exercice(s) à produit brut positif retenu(s) dans la moyenne.',
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
      pied: rl015 > 0
          ? 'Exposition totale issue des briques saisies ci-dessus.'
          : "Briques d'exposition non renseignées : l'exposition totale retenue reste celle reconstituée sur le portefeuille. Saisissez-les dans l'onglet Normes sur les opérations.",
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
              ),
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
        pied: t1 <= 0
            ? 'Fonds propres de base T1 nuls : le seuil de 10 % ne peut pas être appliqué.'
            : "Aucune contrepartie n'atteint 10 % des fonds propres de base T1 : l'établissement ne déclare aucun grand risque sur cet arrêté.",
      );
    }

    final plusEleve = grands.first.pourcentageT1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 340,
          child: FodepGraphPanel(
            title: 'EXPOSITIONS AU-DELÀ DU SEUIL DE 10 % DES FONDS PROPRES DE BASE T1',
            child: Center(
              child: FodepBarresHorizontales(
                maxValeur: 25,
                seuils: const [10, 25],
                format: (v) => '${v.toStringAsFixed(1)} %',
                donnees: [
                  for (final g in grands)
                    FodepBarreDonnee(
                      libelle: g.nom,
                      valeur: g.pourcentageT1,
                      couleur: g.pourcentageT1 > 25 ? c.sousMinimum : c.ramp[0],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _tableauFixe(
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
            pied: '${grands.length} contrepartie(s) au-delà du seuil de 10 % des fonds propres de base T1. '
                'Niveau observé le plus élevé : ${plusEleve.toStringAsFixed(2)} % (limite 25 %). '
                'Rapport retenu : le plus contraignant entre exposition nette et actifs pondérés, la notice laissant les deux définitions ouvertes. '
                "Identifiants Centrale des risques, pays et secteur non disponibles : l'application ne tient pas ce référentiel.",
          ),
        ),
      ],
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

class _OngletEp extends StatefulWidget {
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
  State<_OngletEp> createState() => _OngletEpState();
}

class _OngletEpState extends State<_OngletEp> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final c = widget.c;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : (_isHovered ? c.border.withValues(alpha: 0.6) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF172554) : (_isHovered ? c.ink : c.muted),
            ),
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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
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
                color: estDeduction && valeur < 0 ? c.sousMinimum : c.navy,
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

// ── Card de synthèse conformité ────────────────────────────────────────────────




/// Carte compacte de statut d'une norme (pastille + libellé + observé vs seuil).
class _CarteNormeStatut extends StatelessWidget {
  const _CarteNormeStatut({required this.c, required this.ligne});

  final DashColors c;
  final _LigneConformite ligne;

  Color get _couleur {
    switch (ligne.statut) {
      case _Statut.conforme:
        return c.conforme;
      case _Statut.infraction:
        return c.sousMinimum;
      case _Statut.nd:
        return c.faint;
    }
  }

  String get _statutTexte {
    switch (ligne.statut) {
      case _Statut.conforme:
        return 'Conforme';
      case _Statut.infraction:
        return 'Non conforme';
      case _Statut.nd:
        return 'Non renseigné';
    }
  }

  @override
  Widget build(BuildContext context) {
    final observe = ligne.observe;
    final seuil = ligne.seuil;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF0F1B2D).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.border, width: Dash.hairline),
                ),
                child: Text(
                  '${ligne.code} · ${ligne.reference}',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.4),
                ),
              ),
              const Spacer(),
              FodepPastilleStatut(couleur: _couleur, libelle: _statutTexte),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ligne.libelle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.ink, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              observe == null
                  ? 'Non renseigné'
                  : 'Observé : ${observe.toStringAsFixed(2)} %   ·   Seuil : ${seuil?.toStringAsFixed(2) ?? '-'} %',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: observe == null ? c.faint : _couleur,
                height: 1.3,
                fontFeatures: Dash.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Normes sur les opérations (EP35-EP38 → RA006-RA011) ─────────────────────
const Color _deepblue = Color(0xFF172554);

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
  static const _postesImmobilisations = <(String, String)>[
    ('im001', 'Immobilisations hors exploitation avant ajustement'),
    ('im002', 'Acquises par réalisation de garantie depuis moins de 2 ans'),
    ('im003', 'Acquises par réalisation de garantie depuis plus de 2 ans (dérogation CB)'),
    ('pa084', 'Participations dans les sociétés immobilières'),
    ('im007', 'Immobilisations d\'exploitation ajustées'),
    ('pa106', 'Total des participations (toutes sections de l\'EP34)'),
  ];

  static const _postesProduitBrut = <(String, String)>[
    ('ro001', "Produit d'exploitation bancaire"),
    ('ro002', 'Moins-values réalisées sur cessions de titres du portefeuille bancaire'),
    ('ro003', "(-) Charges d'exploitation bancaire"),
    ('ro005', '(-) Plus-values réalisées sur cessions de titres du portefeuille bancaire'),
    ('ro006', "(+/-) Produits nets d'exploitation bancaire exceptionnels ou inhabituels"),
    ('ro007', "(-) Produits provenant des activités d'assurance"),
    ('ro008', '(-) Produits des entités financières exclues du périmètre prudentiel'),
  ];

  static const _postesLevier = <(String, String)>[
    ('rl001', 'Actifs au bilan'),
    ('rl002', '(-) Expositions au bilan déduites des fonds propres'),
    ('rl003', '(-) Expositions sur opérations assimilables à des pensions'),
    ('rl005', 'Dérivés non couverts par un accord-cadre de compensation admissible'),
    ('rl006', 'Dérivés couverts par un accord-cadre de compensation admissible'),
    ('rl008', "Opérations assimilables à des pensions à titre d'intermédiaire"),
    ('rl009', 'Autres opérations assimilables à des pensions'),
    ('rl011', 'Engagements de financement'),
    ('rl012', 'Autres engagements hors bilan'),
  ];

  static const _categories = <(String, String)>[
    ('a', 'Actionnaires ≥ 10 % des droits de vote'),
    ('b', 'Membres de l\'organe délibérant'),
    ('c', 'Membres de l\'organe exécutif'),
    ('d', 'Commissaires aux comptes'),
    ('e', 'Personnel de direction'),
    ('f', 'Cadres moyens et supérieurs'),
    ('g', 'Personnel d\'exécution'),
    ('h', 'Autres parties liées'),
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
      for (final poste in _postesImmobilisations) poste.$1: _controleur(poste.$1),
      for (final poste in _postesProduitBrut) poste.$1: _controleur(poste.$1),
      for (final poste in _postesLevier) poste.$1: _controleur(poste.$1),
      for (final cat in _categories) 'pr001${cat.$1}': _controleur('pr001${cat.$1}'),
      for (final cat in _categories) 'pr002${cat.$1}': _controleur('pr002${cat.$1}'),
    };
    _chargerParticipations();
  }

  TextEditingController _controleur(String code) {
    final valeur = widget.apercu.postes[code] ?? 0;
    return TextEditingController(text: valeur == 0 ? '' : _formatNombre(valeur));
  }

  String _formatNombre(double v) {
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return s.replaceAll('.', ',');
  }

  double _parseNombre(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

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
        _succes = 'Registre des participations enregistré.';
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
        _succes = 'Postes enregistrés.';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_erreur != null) ...[
            FodepNotice(status: DashStatus.sousMinimum, texte: _erreur!),
            const SizedBox(height: 16),
          ],
          if (_succes != null) ...[
            FodepNotice(status: DashStatus.conforme, texte: _succes!),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 20),
          _buildSectionParticipations(c),
          const SizedBox(height: 24),
          _buildSectionImmobilisations(c),
          const SizedBox(height: 24),
          _buildSectionPrets(c),
          const SizedBox(height: 24),
          _buildSectionPostes(
            c,
            titre: 'PRODUIT BRUT',
            postes: _postesProduitBrut,
          ),
          const SizedBox(height: 24),
          _buildSectionPostes(
            c,
            titre: "BRIQUES D'EXPOSITION DU RATIO DE LEVIER",
            postes: _postesLevier,
          ),
        ],
      ),
    );
  }

  /// Grille de postes à structure figée (EP21, EP33) - même rendu que la
  /// section immobilisations, dont elle partage la mécanique.
  Widget _buildSectionPostes(
    DashColors c, {
    required String titre,
    required List<(String, String)> postes,
  }) {
    return _panneau(
      c,
      titre: titre,
      pied: Row(children: [const Spacer(), _boutonEnregistrer(_sauvegarderPostes)]),
      child: Column(
        children: [
          for (final poste in postes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(poste.$2, style: TextStyle(fontSize: 12, color: c.ink))),
                  const SizedBox(width: 12),
                  _champ(c, _controleurs[poste.$1]!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _panneau(DashColors c, {required String titre, required Widget child, Widget? pied}) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _deepblue,
            child: Text(titre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          child,
          if (pied != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.divider, width: Dash.hairline)),
              ),
              child: pied,
            ),
        ],
      ),
    );
  }

  Widget _champ(DashColors c, TextEditingController controleur, {double width = 110}) {
    return SizedBox(
      width: width,
      height: 34,
      child: TextField(
        controller: controleur,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: c.border, width: Dash.hairline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: c.border, width: Dash.hairline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: c.navy, width: 1.2)),
          hintText: '0',
        ),
      ),
    );
  }

  Widget _lienTexte(DashColors c, String texte, VoidCallback onTap, {Color? couleur}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        texte,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: couleur ?? c.navy),
      ),
    );
  }

  Widget _boutonEnregistrer(VoidCallback onTap) {
    return GestureDetector(
      onTap: _enregistrement ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: _enregistrement ? _deepblue.withValues(alpha: 0.5) : _deepblue,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_enregistrement) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _enregistrement ? 'Enregistrement…' : 'Enregistrer',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── EP34/EP35 - Registre des participations commerciales ───────────────────
  Widget _buildSectionParticipations(DashColors c) {
    return _panneau(
      c,
      titre: 'PARTICIPATIONS DANS DES ENTITÉS COMMERCIALES',
      pied: Row(
        children: [
          _lienTexte(c, '+ Ajouter une ligne', () {
            setState(() {
              _participations = [
                ..._participations,
                const ParticipationEntry(denominationEmettrice: '', capitalEmettrice: 0, montantNet: 0),
              ];
            });
          }),
          const Spacer(),
          _boutonEnregistrer(_sauvegarderParticipations),
        ],
      ),
      child: _chargement
          ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFF8FAFC),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text('DÉNOMINATION DE L\'ÉMETTRICE', style: DashText.eyebrow(c, color: c.muted))),
                    SizedBox(width: 120, child: Text('CAPITAL ÉMETTRICE', style: DashText.eyebrow(c, color: c.muted), textAlign: TextAlign.right)),
                    const SizedBox(width: 8),
                    SizedBox(width: 120, child: Text('MONTANT NET', style: DashText.eyebrow(c, color: c.muted), textAlign: TextAlign.right)),
                    const SizedBox(width: 12),
                    const SizedBox(width: 60),
                  ]),
                ),
                if (_participations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Aucune participation enregistrée.', style: DashText.caption(c)),
                  )
                else
                  for (int i = 0; i < _participations.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              initialValue: _participations[i].denominationEmettrice,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Dénomination'),
                              onChanged: (v) => _participations[i] = _participations[i].copyWith(denominationEmettrice: v),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              initialValue: _participations[i].capitalEmettrice == 0 ? '' : _formatNombre(_participations[i].capitalEmettrice),
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '0'),
                              onChanged: (v) => _participations[i] = _participations[i].copyWith(capitalEmettrice: _parseNombre(v)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              initialValue: _participations[i].montantNet == 0 ? '' : _formatNombre(_participations[i].montantNet),
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '0'),
                              onChanged: (v) => _participations[i] = _participations[i].copyWith(montantNet: _parseNombre(v)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: _lienTexte(c, 'Retirer', () => setState(() => _participations = [..._participations]..removeAt(i)), couleur: const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }

  // ── EP36/EP37 - Immobilisations et participations ──────────────────────────
  Widget _buildSectionImmobilisations(DashColors c) {
    return _panneau(
      c,
      titre: 'IMMOBILISATIONS ET PARTICIPATIONS',
      pied: Row(children: [const Spacer(), _boutonEnregistrer(_sauvegarderPostes)]),
      child: Column(
        children: [
          for (final poste in _postesImmobilisations)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(poste.$2, style: TextStyle(fontSize: 12, color: c.ink))),
                  const SizedBox(width: 12),
                  _champ(c, _controleurs[poste.$1]!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── EP38 - Prêts aux actionnaires, dirigeants et personnel ──────────────────
  Widget _buildSectionPrets(DashColors c) {
    return _panneau(
      c,
      titre: 'PRÊTS AUX ACTIONNAIRES, DIRIGEANTS ET PERSONNEL',
      pied: Row(children: [const Spacer(), _boutonEnregistrer(_sauvegarderPostes)]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(children: [
              const Expanded(flex: 3, child: SizedBox()),
              SizedBox(width: 110, child: Text('CONCOURS (PR001)', style: DashText.eyebrow(c, color: c.muted), textAlign: TextAlign.right)),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: Text('ENGAGEMENTS (PR002)', style: DashText.eyebrow(c, color: c.muted), textAlign: TextAlign.right)),
            ]),
          ),
          for (final cat in _categories)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(cat.$2, style: TextStyle(fontSize: 12, color: c.ink))),
                  _champ(c, _controleurs['pr001${cat.$1}']!, width: 110),
                  const SizedBox(width: 8),
                  _champ(c, _controleurs['pr002${cat.$1}']!, width: 110),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

