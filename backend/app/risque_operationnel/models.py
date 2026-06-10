"""Modèles Pydantic du module Risque Opérationnel."""

from pydantic import BaseModel, Field


# ─── Incidents ────────────────────────────────────────────────────────────────

class IncidentCreate(BaseModel):
    date_occurrence: str = Field(..., description="JJ/MM/AAAA")
    description: str
    ligne_metier: str
    type_evenement: str
    cause_racine: str = ""
    perte_brute: float = 0.0
    perte_recuperee: float = 0.0
    statut: str = "Ouvert"


class IncidentUpdate(BaseModel):
    date_occurrence: str | None = None
    description: str | None = None
    ligne_metier: str | None = None
    type_evenement: str | None = None
    cause_racine: str | None = None
    perte_brute: float | None = None
    perte_recuperee: float | None = None
    statut: str | None = None


class IncidentView(BaseModel):
    id: str
    reference: str
    date_occurrence: str
    description: str
    ligne_metier: str
    type_evenement: str
    cause_racine: str
    perte_brute: float
    perte_recuperee: float
    perte_nette: float
    statut: str
    significatif: bool
    cree_le: str
    modifie_le: str


# ─── KRI ──────────────────────────────────────────────────────────────────────

class KriDefinition(BaseModel):
    id: str
    nom: str
    unite: str
    formule: str
    seuil_alerte: float
    seuil_critique: float
    sens: str
    frequence: str


class KriValeurCreate(BaseModel):
    kri_id: str
    date_mesure: str
    valeur: float
    commentaire: str = ""


class KriValeurView(BaseModel):
    id: str
    kri_id: str
    date_mesure: str
    valeur: float
    commentaire: str
    cree_le: str


class KriView(BaseModel):
    definition: KriDefinition
    derniere_valeur: float | None
    derniere_date: str | None
    statut: str
    historique: list[KriValeurView]


class KriModuleData(BaseModel):
    kri_list: list[KriView]
    kri_hors_seuil: int


# ─── Risques ──────────────────────────────────────────────────────────────────

class RisqueCreate(BaseModel):
    nom: str
    categorie: str
    ligne_metier: str
    probabilite: int = Field(ge=1, le=5)
    impact: int = Field(ge=1, le=5)
    controle_existant: str = ""
    efficacite_controle: int = Field(default=3, ge=1, le=5)
    plan_action_ref: str = ""


class RisqueUpdate(BaseModel):
    nom: str | None = None
    categorie: str | None = None
    ligne_metier: str | None = None
    probabilite: int | None = None
    impact: int | None = None
    controle_existant: str | None = None
    efficacite_controle: int | None = None
    plan_action_ref: str | None = None


class RisqueView(BaseModel):
    id: str
    nom: str
    categorie: str
    ligne_metier: str
    probabilite: int
    impact: int
    niveau_brut: int
    controle_existant: str
    efficacite_controle: int
    niveau_residuel: float
    niveau_label: str
    plan_action_ref: str
    cree_le: str
    modifie_le: str


# ─── Contrôles internes ───────────────────────────────────────────────────────

class ControleCreate(BaseModel):
    perimetre: str
    type_controle: str
    frequence: str
    date_dernier_test: str = ""
    resultat: str = "En cours"
    points_conformes: int = 0
    points_controles: int = 0
    non_conformites: str = ""
    validateur: str = ""


class ControleUpdate(BaseModel):
    perimetre: str | None = None
    type_controle: str | None = None
    frequence: str | None = None
    date_dernier_test: str | None = None
    resultat: str | None = None
    points_conformes: int | None = None
    points_controles: int | None = None
    non_conformites: str | None = None
    validateur: str | None = None


class ControleView(BaseModel):
    id: str
    reference: str
    perimetre: str
    type_controle: str
    frequence: str
    date_dernier_test: str
    prochaine_date: str
    resultat: str
    taux_conformite: float
    points_conformes: int
    points_controles: int
    non_conformites: str
    validateur: str
    cree_le: str
    modifie_le: str


# ─── Plans d'actions ──────────────────────────────────────────────────────────

class PlanCreate(BaseModel):
    titre: str
    description: str = ""
    type_action: str = "Corrective"
    source: str = "Incident"
    source_ref: str = ""
    responsable: str = ""
    date_debut: str = ""
    date_echeance: str = ""
    priorite: str = "Moyenne"
    statut: str = "A faire"
    avancement: int = 0


class PlanUpdate(BaseModel):
    titre: str | None = None
    description: str | None = None
    type_action: str | None = None
    source: str | None = None
    source_ref: str | None = None
    responsable: str | None = None
    date_debut: str | None = None
    date_echeance: str | None = None
    priorite: str | None = None
    statut: str | None = None
    avancement: int | None = None


class PlanView(BaseModel):
    id: str
    reference: str
    titre: str
    description: str
    type_action: str
    source: str
    source_ref: str
    responsable: str
    date_debut: str
    date_echeance: str
    jours_restants: int
    priorite: str
    statut: str
    avancement: int
    en_retard: bool
    cree_le: str
    modifie_le: str


# ─── Historique ───────────────────────────────────────────────────────────────

class IncidentImportItem(BaseModel):
    date_occurrence: str
    description: str
    ligne_metier: str
    type_evenement: str
    cause_racine: str = ""
    perte_brute: float = 0.0
    perte_recuperee: float = 0.0
    statut: str = "Ouvert"


class IncidentBulkImportRequest(BaseModel):
    incidents: list[IncidentImportItem]
    mode: str = "merge"  # "merge" | "replace"


class IncidentImportResult(BaseModel):
    imported: int
    skipped: int
    errors: list[str]


class HistoriqueView(BaseModel):
    id: int
    date_evenement: str
    utilisateur: str
    menu: str
    type_action: str
    element: str
    ancienne_valeur: str
    nouvelle_valeur: str
    commentaire: str


# ─── Dashboard ────────────────────────────────────────────────────────────────

class DashboardWidget1(BaseModel):
    exigence_fonds_propres: float
    apr_risque_op: float
    statut_reglementaire: str


class DashboardWidget2(BaseModel):
    total_incidents_mois: int
    pertes_nettes_mois: float
    incidents_non_clos: int
    evolution_pertes_pct: float | None


class DashboardWidget3(BaseModel):
    actions_en_retard: int
    controles_non_conformes: int
    kri_hors_seuil: int


class EvolutionPoint(BaseModel):
    mois: str
    perte_brute: float
    perte_nette: float


class RepartitionItem(BaseModel):
    label: str
    valeur: int


class DashboardData(BaseModel):
    widget1: DashboardWidget1
    widget2: DashboardWidget2
    widget3: DashboardWidget3
    evolution_pertes: list[EvolutionPoint]
    repartition_ligne_metier: list[RepartitionItem]
    repartition_type: list[RepartitionItem]
