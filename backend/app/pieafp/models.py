"""Modèles Pydantic du module PIEAFP (Pilier 2 / ICAAP — UMOA Titre XI)."""

from __future__ import annotations

from pydantic import BaseModel


# ──────────────────────────────────────────────────────────────────────────────
# CONCENTRATION (Module 1.2)
# ──────────────────────────────────────────────────────────────────────────────

class ConcentrationBar(BaseModel):
    label: str
    ead: float
    pct: float


class ConcentrationAxis(BaseModel):
    axe: str            # 'Secteur', 'Pays', 'Contrepartie'
    hhi: float          # 0–10 000
    niveau: str         # 'Faible', 'Modéré', 'Élevé'
    top_bars: list[ConcentrationBar]


class ConcentrationResult(BaseModel):
    total_ead: float
    total_fp: float
    nb_contreparties: int
    cr10_pct: float     # Top 10 EAD / FP en %
    grands_risques_nb: int   # EAD > 25% FP
    axes: list[ConcentrationAxis]


# ──────────────────────────────────────────────────────────────────────────────
# IRRBB — Interest Rate Risk in the Banking Book (Module 1.6)
# ──────────────────────────────────────────────────────────────────────────────

class IrrbbTranche(BaseModel):
    tranche: str
    ordre: int
    encours_actifs: float
    encours_passifs: float
    taux_actifs_pct: float
    taux_passifs_pct: float
    duration_annees: float


class IrrbbUpdate(BaseModel):
    encours_actifs: float
    encours_passifs: float
    taux_actifs_pct: float
    taux_passifs_pct: float


class IrrbbTrancheResult(BaseModel):
    tranche: str
    ordre: int
    encours_actifs: float
    encours_passifs: float
    taux_actifs_pct: float
    taux_passifs_pct: float
    duration_annees: float
    gap: float              # actifs - passifs
    delta_nii_200bp: float  # impact sur NII avec choc +200bp


class IrrbbResult(BaseModel):
    choc_bp: int            # 200 par défaut
    tranches: list[IrrbbTrancheResult]
    gap_total: float
    delta_nii_200bp: float  # impact total NII (FCFA)
    delta_nii_pct_fp: float # en % des FP
    niveau_risque: str      # 'Faible', 'Modéré', 'Élevé'


# ──────────────────────────────────────────────────────────────────────────────
# AUTRES RISQUES Pilier 2 (Module 1.8)
# ──────────────────────────────────────────────────────────────────────────────

class AutreRisque(BaseModel):
    id: int
    libelle: str
    categorie: str
    probabilite: int    # 1–5
    impact: int         # 1–5
    score: int          # probabilite × impact
    niveau: str         # 'Faible', 'Modéré', 'Élevé', 'Critique'
    description: str
    mesures: str
    date_evaluation: str
    cree_le: str


class AutreRisqueCreate(BaseModel):
    libelle: str
    categorie: str = "Opérationnel"
    probabilite: int = 3
    impact: int = 3
    description: str = ""
    mesures: str = ""
    date_evaluation: str = ""


class AutreRisqueUpdate(BaseModel):
    libelle: str | None = None
    categorie: str | None = None
    probabilite: int | None = None
    impact: int | None = None
    description: str | None = None
    mesures: str | None = None
    date_evaluation: str | None = None


# ──────────────────────────────────────────────────────────────────────────────
# PLANIFICATION PLURIANNUELLE (Module 2)
# ──────────────────────────────────────────────────────────────────────────────

class PlanificationAnnee(BaseModel):
    annee: int
    fp_disponibles: float
    rwa_credit_projete: float
    rwa_marche_projete: float
    rwa_op_projete: float
    rwa_total_projete: float    # computed
    resultat_net_projete: float
    dividendes_projetes: float
    emission_capital: float
    addon_pilier2: float
    fp_requis: float            # computed (8% RWA total + add-on)
    coussin: float              # fp_disponibles − fp_requis
    ratio_solvabilite_pct: float  # computed


class PlanificationAnneeUpdate(BaseModel):
    fp_disponibles: float
    rwa_credit_projete: float
    rwa_marche_projete: float
    rwa_op_projete: float
    resultat_net_projete: float
    dividendes_projetes: float
    emission_capital: float
    addon_pilier2: float


class PlanificationResult(BaseModel):
    annees: list[PlanificationAnnee]


# ──────────────────────────────────────────────────────────────────────────────
# STRESS TESTS (Module 3)
# ──────────────────────────────────────────────────────────────────────────────

class ScenarioStress(BaseModel):
    id: int
    nom: str
    description: str
    type_scenario: str
    choc_rwa_credit_pct: float
    choc_rwa_marche_pct: float
    choc_rwa_op_pct: float
    choc_perte_nette: float
    actif: bool
    cree_le: str


class ScenarioStressCreate(BaseModel):
    nom: str
    description: str = ""
    type_scenario: str = "Adverse"
    choc_rwa_credit_pct: float = 0.0
    choc_rwa_marche_pct: float = 0.0
    choc_rwa_op_pct: float = 0.0
    choc_perte_nette: float = 0.0


class ScenarioStressUpdate(BaseModel):
    nom: str | None = None
    description: str | None = None
    type_scenario: str | None = None
    choc_rwa_credit_pct: float | None = None
    choc_rwa_marche_pct: float | None = None
    choc_rwa_op_pct: float | None = None
    choc_perte_nette: float | None = None
    actif: bool | None = None


class StressImpact(BaseModel):
    scenario: ScenarioStress
    rwa_credit_base: float
    rwa_marche_base: float
    rwa_op_base: float
    rwa_total_base: float
    fp_base: float
    ratio_base_pct: float
    rwa_credit_stresse: float
    rwa_marche_stresse: float
    rwa_op_stresse: float
    rwa_total_stresse: float
    fp_stresse: float           # FP − perte nette
    ratio_stresse_pct: float
    variation_ratio_bp: float   # variation en points de base
    solvable_apres_stress: bool


# ──────────────────────────────────────────────────────────────────────────────
# GOUVERNANCE / CHECKLIST (Module 4)
# ──────────────────────────────────────────────────────────────────────────────

class ChecklistItem(BaseModel):
    id: int
    element: str
    categorie: str
    statut: str         # 'Conforme', 'En cours', 'A faire', 'Non applicable'
    date_revue: str
    responsable: str
    note: str


class ChecklistUpdate(BaseModel):
    statut: str
    date_revue: str = ""
    responsable: str = ""
    note: str = ""


class GouvernanceResult(BaseModel):
    items: list[ChecklistItem]
    nb_conforme: int
    nb_en_cours: int
    nb_a_faire: int
    nb_na: int
    taux_conformite_pct: float


# ──────────────────────────────────────────────────────────────────────────────
# DASHBOARD PIEAFP & RAPPORT
# ──────────────────────────────────────────────────────────────────────────────

class ModuleStatus(BaseModel):
    code: str
    libelle: str
    statut: str         # 'OK', 'Attention', 'A compléter', 'N/A'
    valeur_cle: str     # valeur courte à afficher (ex. "HHI: 1 250", "Δ NII: 2.1%")
    detail: str


class PieafpDashboard(BaseModel):
    fp_total: float
    rwa_total: float
    ratio_solvabilite_pct: float
    modules: list[ModuleStatus]


class PieafpRapport(BaseModel):
    date_rapport: str
    fp_total: float
    rwa_total: float
    ratio_solvabilite_pct: float
    concentration: ConcentrationResult
    irrbb: IrrbbResult
    autres_risques: list[AutreRisque]
    planification: PlanificationResult
    gouvernance: GouvernanceResult
