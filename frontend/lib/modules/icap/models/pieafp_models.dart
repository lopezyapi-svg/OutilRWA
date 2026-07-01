// Modèles Dart pour le module PIEAFP (Pilier 2 / ICAAP — UMOA Titre XI).

// ──────────────────────────────────────────────────────────────────────────────
// CONCENTRATION (Module 1.2)
// ──────────────────────────────────────────────────────────────────────────────

class ConcentrationBar {
  const ConcentrationBar({
    required this.label,
    required this.ead,
    required this.pct,
  });
  final String label;
  final double ead;
  final double pct;

  factory ConcentrationBar.fromJson(Map<String, dynamic> j) =>
      ConcentrationBar(
        label: j['label'] as String? ?? '',
        ead: (j['ead'] as num?)?.toDouble() ?? 0.0,
        pct: (j['pct'] as num?)?.toDouble() ?? 0.0,
      );
}

class ConcentrationAxis {
  const ConcentrationAxis({
    required this.axe,
    required this.hhi,
    required this.niveau,
    required this.topBars,
  });
  final String axe;
  final double hhi;
  final String niveau;
  final List<ConcentrationBar> topBars;

  factory ConcentrationAxis.fromJson(Map<String, dynamic> j) =>
      ConcentrationAxis(
        axe: j['axe'] as String? ?? '',
        hhi: (j['hhi'] as num?)?.toDouble() ?? 0.0,
        niveau: j['niveau'] as String? ?? '',
        topBars: (j['top_bars'] as List<dynamic>? ?? [])
            .map((e) => ConcentrationBar.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ConcentrationResult {
  const ConcentrationResult({
    required this.totalEad,
    required this.totalFp,
    required this.nbContreparties,
    required this.cr10Pct,
    required this.grandsRisquesNb,
    required this.axes,
  });
  final double totalEad;
  final double totalFp;
  final int nbContreparties;
  final double cr10Pct;
  final int grandsRisquesNb;
  final List<ConcentrationAxis> axes;

  factory ConcentrationResult.fromJson(Map<String, dynamic> j) =>
      ConcentrationResult(
        totalEad: (j['total_ead'] as num?)?.toDouble() ?? 0.0,
        totalFp: (j['total_fp'] as num?)?.toDouble() ?? 0.0,
        nbContreparties: (j['nb_contreparties'] as num?)?.toInt() ?? 0,
        cr10Pct: (j['cr10_pct'] as num?)?.toDouble() ?? 0.0,
        grandsRisquesNb: (j['grands_risques_nb'] as num?)?.toInt() ?? 0,
        axes: (j['axes'] as List<dynamic>? ?? [])
            .map((e) => ConcentrationAxis.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// IRRBB (Module 1.6)
// ──────────────────────────────────────────────────────────────────────────────

class IrrbbTrancheResult {
  const IrrbbTrancheResult({
    required this.tranche,
    required this.ordre,
    required this.encoursActifs,
    required this.encoursPassifs,
    required this.tauxActifsPct,
    required this.tauxPassifsPct,
    required this.durationAnnees,
    required this.gap,
    required this.deltaNii200bp,
  });
  final String tranche;
  final int ordre;
  final double encoursActifs;
  final double encoursPassifs;
  final double tauxActifsPct;
  final double tauxPassifsPct;
  final double durationAnnees;
  final double gap;
  final double deltaNii200bp;

  factory IrrbbTrancheResult.fromJson(Map<String, dynamic> j) =>
      IrrbbTrancheResult(
        tranche: j['tranche'] as String? ?? '',
        ordre: (j['ordre'] as num?)?.toInt() ?? 0,
        encoursActifs: (j['encours_actifs'] as num?)?.toDouble() ?? 0.0,
        encoursPassifs: (j['encours_passifs'] as num?)?.toDouble() ?? 0.0,
        tauxActifsPct: (j['taux_actifs_pct'] as num?)?.toDouble() ?? 0.0,
        tauxPassifsPct: (j['taux_passifs_pct'] as num?)?.toDouble() ?? 0.0,
        durationAnnees: (j['duration_annees'] as num?)?.toDouble() ?? 0.0,
        gap: (j['gap'] as num?)?.toDouble() ?? 0.0,
        deltaNii200bp: (j['delta_nii_200bp'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'encours_actifs': encoursActifs,
        'encours_passifs': encoursPassifs,
        'taux_actifs_pct': tauxActifsPct,
        'taux_passifs_pct': tauxPassifsPct,
      };
}

class IrrbbResult {
  const IrrbbResult({
    required this.chocBp,
    required this.tranches,
    required this.gapTotal,
    required this.deltaNii200bp,
    required this.deltaNiiPctFp,
    required this.niveauRisque,
  });
  final int chocBp;
  final List<IrrbbTrancheResult> tranches;
  final double gapTotal;
  final double deltaNii200bp;
  final double deltaNiiPctFp;
  final String niveauRisque;

  factory IrrbbResult.fromJson(Map<String, dynamic> j) => IrrbbResult(
        chocBp: (j['choc_bp'] as num?)?.toInt() ?? 200,
        tranches: (j['tranches'] as List<dynamic>? ?? [])
            .map((e) => IrrbbTrancheResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        gapTotal: (j['gap_total'] as num?)?.toDouble() ?? 0.0,
        deltaNii200bp: (j['delta_nii_200bp'] as num?)?.toDouble() ?? 0.0,
        deltaNiiPctFp: (j['delta_nii_pct_fp'] as num?)?.toDouble() ?? 0.0,
        niveauRisque: j['niveau_risque'] as String? ?? '',
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// AUTRES RISQUES (Module 1.8)
// ──────────────────────────────────────────────────────────────────────────────

class AutreRisque {
  const AutreRisque({
    required this.id,
    required this.libelle,
    required this.categorie,
    required this.probabilite,
    required this.impact,
    required this.score,
    required this.niveau,
    required this.description,
    required this.mesures,
    required this.dateEvaluation,
    required this.creeLe,
  });
  final int id;
  final String libelle;
  final String categorie;
  final int probabilite;
  final int impact;
  final int score;
  final String niveau;
  final String description;
  final String mesures;
  final String dateEvaluation;
  final String creeLe;

  factory AutreRisque.fromJson(Map<String, dynamic> j) => AutreRisque(
        id: (j['id'] as num?)?.toInt() ?? 0,
        libelle: j['libelle'] as String? ?? '',
        categorie: j['categorie'] as String? ?? '',
        probabilite: (j['probabilite'] as num?)?.toInt() ?? 1,
        impact: (j['impact'] as num?)?.toInt() ?? 1,
        score: (j['score'] as num?)?.toInt() ?? 1,
        niveau: j['niveau'] as String? ?? '',
        description: j['description'] as String? ?? '',
        mesures: j['mesures'] as String? ?? '',
        dateEvaluation: j['date_evaluation'] as String? ?? '',
        creeLe: j['cree_le'] as String? ?? '',
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// PLANIFICATION (Module 2)
// ──────────────────────────────────────────────────────────────────────────────

class PlanificationAnnee {
  const PlanificationAnnee({
    required this.annee,
    required this.fpDisponibles,
    required this.rwaCreditProjecte,
    required this.rwaMarcheProjecte,
    required this.rwaOpProjecte,
    required this.rwaTotalProjecte,
    required this.resultatNetProjecte,
    required this.dividendesProjectes,
    required this.emissionCapital,
    required this.addonPilier2,
    required this.fpRequis,
    required this.coussin,
    required this.ratioSolvabilitePct,
  });
  final int annee;
  final double fpDisponibles;
  final double rwaCreditProjecte;
  final double rwaMarcheProjecte;
  final double rwaOpProjecte;
  final double rwaTotalProjecte;
  final double resultatNetProjecte;
  final double dividendesProjectes;
  final double emissionCapital;
  final double addonPilier2;
  final double fpRequis;
  final double coussin;
  final double ratioSolvabilitePct;

  factory PlanificationAnnee.fromJson(Map<String, dynamic> j) =>
      PlanificationAnnee(
        annee: (j['annee'] as num?)?.toInt() ?? 0,
        fpDisponibles: (j['fp_disponibles'] as num?)?.toDouble() ?? 0.0,
        rwaCreditProjecte:
            (j['rwa_credit_projete'] as num?)?.toDouble() ?? 0.0,
        rwaMarcheProjecte:
            (j['rwa_marche_projete'] as num?)?.toDouble() ?? 0.0,
        rwaOpProjecte: (j['rwa_op_projete'] as num?)?.toDouble() ?? 0.0,
        rwaTotalProjecte:
            (j['rwa_total_projete'] as num?)?.toDouble() ?? 0.0,
        resultatNetProjecte:
            (j['resultat_net_projete'] as num?)?.toDouble() ?? 0.0,
        dividendesProjectes:
            (j['dividendes_projetes'] as num?)?.toDouble() ?? 0.0,
        emissionCapital: (j['emission_capital'] as num?)?.toDouble() ?? 0.0,
        addonPilier2: (j['addon_pilier2'] as num?)?.toDouble() ?? 0.0,
        fpRequis: (j['fp_requis'] as num?)?.toDouble() ?? 0.0,
        coussin: (j['coussin'] as num?)?.toDouble() ?? 0.0,
        ratioSolvabilitePct:
            (j['ratio_solvabilite_pct'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'fp_disponibles': fpDisponibles,
        'rwa_credit_projete': rwaCreditProjecte,
        'rwa_marche_projete': rwaMarcheProjecte,
        'rwa_op_projete': rwaOpProjecte,
        'resultat_net_projete': resultatNetProjecte,
        'dividendes_projetes': dividendesProjectes,
        'emission_capital': emissionCapital,
        'addon_pilier2': addonPilier2,
      };
}

class PlanificationResult {
  const PlanificationResult({required this.annees});
  final List<PlanificationAnnee> annees;

  factory PlanificationResult.fromJson(Map<String, dynamic> j) =>
      PlanificationResult(
        annees: (j['annees'] as List<dynamic>? ?? [])
            .map((e) =>
                PlanificationAnnee.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// STRESS TESTS (Module 3)
// ──────────────────────────────────────────────────────────────────────────────

class ScenarioStress {
  const ScenarioStress({
    required this.id,
    required this.nom,
    required this.description,
    required this.typeScenario,
    required this.chocRwaCreditPct,
    required this.chocRwaArchePct,
    required this.chocRwaOpPct,
    required this.chocPerteNette,
    required this.actif,
    required this.creeLe,
  });
  final int id;
  final String nom;
  final String description;
  final String typeScenario;
  final double chocRwaCreditPct;
  final double chocRwaArchePct;
  final double chocRwaOpPct;
  final double chocPerteNette;
  final bool actif;
  final String creeLe;

  factory ScenarioStress.fromJson(Map<String, dynamic> j) => ScenarioStress(
        id: (j['id'] as num?)?.toInt() ?? 0,
        nom: j['nom'] as String? ?? '',
        description: j['description'] as String? ?? '',
        typeScenario: j['type_scenario'] as String? ?? '',
        chocRwaCreditPct:
            (j['choc_rwa_credit_pct'] as num?)?.toDouble() ?? 0.0,
        chocRwaArchePct:
            (j['choc_rwa_marche_pct'] as num?)?.toDouble() ?? 0.0,
        chocRwaOpPct: (j['choc_rwa_op_pct'] as num?)?.toDouble() ?? 0.0,
        chocPerteNette: (j['choc_perte_nette'] as num?)?.toDouble() ?? 0.0,
        actif: (j['actif'] as bool?) ?? true,
        creeLe: j['cree_le'] as String? ?? '',
      );
}

class StressImpact {
  const StressImpact({
    required this.scenario,
    required this.rwaCreditBase,
    required this.rwaMarcheBase,
    required this.rwaOpBase,
    required this.rwaTotalBase,
    required this.fpBase,
    required this.ratioBasePct,
    required this.rwaCreditStresse,
    required this.rwaMarcheStresse,
    required this.rwaOpStresse,
    required this.rwaTotalStresse,
    required this.fpStresse,
    required this.ratioStressePct,
    required this.variationRatioBp,
    required this.solvableApresStress,
  });
  final ScenarioStress scenario;
  final double rwaCreditBase;
  final double rwaMarcheBase;
  final double rwaOpBase;
  final double rwaTotalBase;
  final double fpBase;
  final double ratioBasePct;
  final double rwaCreditStresse;
  final double rwaMarcheStresse;
  final double rwaOpStresse;
  final double rwaTotalStresse;
  final double fpStresse;
  final double ratioStressePct;
  final double variationRatioBp;
  final bool solvableApresStress;

  factory StressImpact.fromJson(Map<String, dynamic> j) => StressImpact(
        scenario: ScenarioStress.fromJson(
            j['scenario'] as Map<String, dynamic>),
        rwaCreditBase: (j['rwa_credit_base'] as num?)?.toDouble() ?? 0.0,
        rwaMarcheBase: (j['rwa_marche_base'] as num?)?.toDouble() ?? 0.0,
        rwaOpBase: (j['rwa_op_base'] as num?)?.toDouble() ?? 0.0,
        rwaTotalBase: (j['rwa_total_base'] as num?)?.toDouble() ?? 0.0,
        fpBase: (j['fp_base'] as num?)?.toDouble() ?? 0.0,
        ratioBasePct: (j['ratio_base_pct'] as num?)?.toDouble() ?? 0.0,
        rwaCreditStresse:
            (j['rwa_credit_stresse'] as num?)?.toDouble() ?? 0.0,
        rwaMarcheStresse:
            (j['rwa_marche_stresse'] as num?)?.toDouble() ?? 0.0,
        rwaOpStresse: (j['rwa_op_stresse'] as num?)?.toDouble() ?? 0.0,
        rwaTotalStresse: (j['rwa_total_stresse'] as num?)?.toDouble() ?? 0.0,
        fpStresse: (j['fp_stresse'] as num?)?.toDouble() ?? 0.0,
        ratioStressePct: (j['ratio_stresse_pct'] as num?)?.toDouble() ?? 0.0,
        variationRatioBp:
            (j['variation_ratio_bp'] as num?)?.toDouble() ?? 0.0,
        solvableApresStress: (j['solvable_apres_stress'] as bool?) ?? false,
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// GOUVERNANCE / CHECKLIST (Module 4)
// ──────────────────────────────────────────────────────────────────────────────

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.element,
    required this.categorie,
    required this.statut,
    required this.dateRevue,
    required this.responsable,
    required this.note,
  });
  final int id;
  final String element;
  final String categorie;
  final String statut;
  final String dateRevue;
  final String responsable;
  final String note;

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        element: j['element'] as String? ?? '',
        categorie: j['categorie'] as String? ?? '',
        statut: j['statut'] as String? ?? 'A faire',
        dateRevue: j['date_revue'] as String? ?? '',
        responsable: j['responsable'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

class GouvernanceResult {
  const GouvernanceResult({
    required this.items,
    required this.nbConforme,
    required this.nbEnCours,
    required this.nbAFaire,
    required this.nbNa,
    required this.tauxConformitePct,
  });
  final List<ChecklistItem> items;
  final int nbConforme;
  final int nbEnCours;
  final int nbAFaire;
  final int nbNa;
  final double tauxConformitePct;

  factory GouvernanceResult.fromJson(Map<String, dynamic> j) =>
      GouvernanceResult(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nbConforme: (j['nb_conforme'] as num?)?.toInt() ?? 0,
        nbEnCours: (j['nb_en_cours'] as num?)?.toInt() ?? 0,
        nbAFaire: (j['nb_a_faire'] as num?)?.toInt() ?? 0,
        nbNa: (j['nb_na'] as num?)?.toInt() ?? 0,
        tauxConformitePct:
            (j['taux_conformite_pct'] as num?)?.toDouble() ?? 0.0,
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// DASHBOARD PIEAFP
// ──────────────────────────────────────────────────────────────────────────────

class ModuleStatus {
  const ModuleStatus({
    required this.code,
    required this.libelle,
    required this.statut,
    required this.valeurCle,
    required this.detail,
  });
  final String code;
  final String libelle;
  final String statut;
  final String valeurCle;
  final String detail;

  factory ModuleStatus.fromJson(Map<String, dynamic> j) => ModuleStatus(
        code: j['code'] as String? ?? '',
        libelle: j['libelle'] as String? ?? '',
        statut: j['statut'] as String? ?? '',
        valeurCle: j['valeur_cle'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
      );
}

class PieafpDashboard {
  const PieafpDashboard({
    required this.fpTotal,
    required this.rwaTotal,
    required this.ratioSolvabilitePct,
    required this.modules,
  });
  final double fpTotal;
  final double rwaTotal;
  final double ratioSolvabilitePct;
  final List<ModuleStatus> modules;

  factory PieafpDashboard.fromJson(Map<String, dynamic> j) =>
      PieafpDashboard(
        fpTotal: (j['fp_total'] as num?)?.toDouble() ?? 0.0,
        rwaTotal: (j['rwa_total'] as num?)?.toDouble() ?? 0.0,
        ratioSolvabilitePct:
            (j['ratio_solvabilite_pct'] as num?)?.toDouble() ?? 0.0,
        modules: (j['modules'] as List<dynamic>? ?? [])
            .map((e) => ModuleStatus.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// RAPPORT PIEAFP (Module 5)
// ──────────────────────────────────────────────────────────────────────────────

class PieafpRapport {
  const PieafpRapport({
    required this.dateRapport,
    required this.fpTotal,
    required this.rwaTotal,
    required this.ratioSolvabilitePct,
    required this.concentration,
    required this.irrbb,
    required this.autresRisques,
    required this.planification,
    required this.gouvernance,
  });
  final String dateRapport;
  final double fpTotal;
  final double rwaTotal;
  final double ratioSolvabilitePct;
  final ConcentrationResult concentration;
  final IrrbbResult irrbb;
  final List<AutreRisque> autresRisques;
  final PlanificationResult planification;
  final GouvernanceResult gouvernance;

  factory PieafpRapport.fromJson(Map<String, dynamic> j) => PieafpRapport(
        dateRapport: j['date_rapport'] as String? ?? '',
        fpTotal: (j['fp_total'] as num?)?.toDouble() ?? 0.0,
        rwaTotal: (j['rwa_total'] as num?)?.toDouble() ?? 0.0,
        ratioSolvabilitePct:
            (j['ratio_solvabilite_pct'] as num?)?.toDouble() ?? 0.0,
        concentration: ConcentrationResult.fromJson(
            j['concentration'] as Map<String, dynamic>),
        irrbb: IrrbbResult.fromJson(j['irrbb'] as Map<String, dynamic>),
        autresRisques: (j['autres_risques'] as List<dynamic>? ?? [])
            .map((e) => AutreRisque.fromJson(e as Map<String, dynamic>))
            .toList(),
        planification: PlanificationResult.fromJson(
            j['planification'] as Map<String, dynamic>),
        gouvernance: GouvernanceResult.fromJson(
            j['gouvernance'] as Map<String, dynamic>),
      );
}
