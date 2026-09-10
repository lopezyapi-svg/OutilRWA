"""Modèles Pydantic du module ICAAP.

Miroir applicatif des tables créées par la migration ``042_icaap.sql``.
Les vues (``*View``) sont renvoyées par l'API ; les charges utiles
(``*Save`` / ``*Update``) sont acceptées en entrée.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

StatutExercice = Literal["brouillon", "valide", "archive"]
MethodeRisque = Literal["quanti", "quali"]
TypeScenario = Literal["base", "adverse", "severe"]
StatutAction = Literal["ouvert", "en_cours", "clos"]


# --------------------------------------------------------------------------
# Exercice
# --------------------------------------------------------------------------
class ExerciceCreate(BaseModel):
    annee: int = Field(ge=2000, le=2100)
    date_arrete: str
    commentaire: str = ""


class ExerciceUpdate(BaseModel):
    date_arrete: str | None = None
    opinion_executif: str | None = None
    avis_deliberant: str | None = None
    commentaire: str | None = None


class ExerciceView(BaseModel):
    id: str
    annee: int
    date_arrete: str
    statut: StatutExercice
    auteur_id: str | None = None
    date_validation: str | None = None
    opinion_executif: str = ""
    avis_deliberant: str = ""
    commentaire: str = ""
    cree_le: str
    modifie_le: str


# --------------------------------------------------------------------------
# Cartographie des risques
# --------------------------------------------------------------------------
class RisqueEntry(BaseModel):
    id: str | None = None
    categorie: str
    libelle: str = ""
    pilier: Literal[1, 2] = 2
    # None => la méthode est dérivée serveur du seuil de matérialité.
    # Une valeur explicite est respectée (ex. « quali » forcé pour un risque
    # non quantifiable : stratégie, réputation).
    methode: MethodeRisque | None = None
    probabilite: int = Field(default=1, ge=1, le=5)
    impact: int = Field(default=1, ge=1, le=5)
    maitrise: str = ""
    commentaire: str = ""


class RisqueView(RisqueEntry):
    id: str
    exercice_id: str
    methode: MethodeRisque  # toujours résolue côté serveur
    materialite: int
    cree_le: str
    modifie_le: str


class CartographieSave(BaseModel):
    lignes: list[RisqueEntry]


# --------------------------------------------------------------------------
# Capital économique et agrégation
# --------------------------------------------------------------------------
class CapitalEcoLigne(BaseModel):
    id: str | None = None
    risque_id: str | None = None
    categorie: str
    cle_correlation: str = ""
    libelle: str = ""
    methode: str = ""
    parametres: dict[str, float] = Field(default_factory=dict)
    montant_besoin: float = 0.0
    horizon_mois: int = 12


class CapitalEcoRun(BaseModel):
    """Hypothèses d'un calcul du besoin en capital économique.

    Les montants non fournis valent 0 ; ``ratio_cible_pct`` non fourni reprend
    le paramètre prudentiel ``ratio_solvabilite_cible``. Ce calcul consomme
    des chiffres, il n'en recalcule aucun : les RWA / exigences Pilier 1 sont
    saisis ici ou repris de la photo ``capital_dispo`` de l'exercice.
    """

    ratio_cible_pct: float | None = None
    rwa_credit: float = 0.0
    rwa_marche: float = 0.0
    rwa_operationnel: float = 0.0
    exigence_marche: float | None = None
    exigence_operationnel: float | None = None
    irrbb_impact_eve: float = 0.0
    concentration_hhi: float = Field(default=0.0, ge=0.0, le=1.0)
    crm_residuel: float = 0.0
    buffers_quali: dict[str, float] = Field(default_factory=dict)


class CorrelationEntry(BaseModel):
    risque_a: str
    risque_b: str
    coefficient: float = Field(ge=-1, le=1)


class CorrelationsSave(BaseModel):
    lignes: list[CorrelationEntry]


class CouvertureView(BaseModel):
    besoin_somme_simple: float
    besoin_apres_diversification: float
    benefice_diversification: float
    capital_interne_disponible: float
    ratio_couverture: float
    seuil_alerte: float = 100.0
    en_alerte: bool
    detail_par_risque: list[CapitalEcoLigne]


# --------------------------------------------------------------------------
# Capital interne disponible
# --------------------------------------------------------------------------
class CapitalDispoUpdate(BaseModel):
    cet1: float = 0.0
    at1: float = 0.0
    t2: float = 0.0
    deductions: float = 0.0
    rwa_pilier1_total: float = 0.0
    source: str = ""


class CapitalDispoView(CapitalDispoUpdate):
    exercice_id: str
    capital_interne_total: float
    cree_le: str
    modifie_le: str


# --------------------------------------------------------------------------
# Stress testing
# --------------------------------------------------------------------------
class ScenarioEntry(BaseModel):
    id: str | None = None
    libelle: str = ""
    type_scenario: TypeScenario = "adverse"
    hypotheses: dict[str, float] = Field(default_factory=dict)
    horizon_annees: int = Field(default=3, ge=1, le=10)


class ScenarioResultatLigne(BaseModel):
    annee_proj: int
    rwa_projete: float
    resultat_projete: float
    fonds_propres_projetes: float
    ratio_projete: float


class ScenarioView(ScenarioEntry):
    id: str
    exercice_id: str
    dernier_run_le: str | None = None
    resultats: list[ScenarioResultatLigne] = Field(default_factory=list)


# --------------------------------------------------------------------------
# Planification du capital
# --------------------------------------------------------------------------
class PlanCapitalHypotheses(BaseModel):
    croissance_encours_pct: float = 0.0
    marge_nette_pct: float = 0.0
    cout_risque_pct: float = 0.0
    taux_distribution_pct: float = 0.0


class PlanCapitalLigne(BaseModel):
    annee_proj: int
    rwa_projete: float
    resultat_mis_en_reserve: float
    distributions: float
    fonds_propres_projetes: float
    ratio_projete: float
    coussin_entame: bool


class PlanCapitalView(BaseModel):
    exercice_id: str
    hypotheses: PlanCapitalHypotheses
    trajectoire: list[PlanCapitalLigne]
    annee_entame_coussin: int | None = None


# --------------------------------------------------------------------------
# Plan d'action
# --------------------------------------------------------------------------
class PlanActionEntry(BaseModel):
    id: str | None = None
    constat: str = ""
    action: str = ""
    responsable: str = ""
    echeance: str | None = None
    statut: StatutAction = "ouvert"


class PlanActionSave(BaseModel):
    lignes: list[PlanActionEntry]


# --------------------------------------------------------------------------
# Paramètres prudentiels
# --------------------------------------------------------------------------
class ParametreView(BaseModel):
    cle: str
    libelle: str
    valeur: float
    unite: str
    date_effet: str
    source: str
