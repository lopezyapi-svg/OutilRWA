"""Routes FastAPI du module PIEAFP (Pilier 2 / ICAAP)."""

from fastapi import APIRouter, HTTPException

from .models import (
    AutreRisque,
    AutreRisqueCreate,
    AutreRisqueUpdate,
    ChecklistItem,
    ChecklistUpdate,
    ConcentrationResult,
    GouvernanceResult,
    IrrbbResult,
    IrrbbTranche,
    IrrbbUpdate,
    PieafpDashboard,
    PieafpRapport,
    PlanificationAnnee,
    PlanificationAnneeUpdate,
    PlanificationResult,
    ScenarioStress,
    ScenarioStressCreate,
    ScenarioStressUpdate,
    StressImpact,
)
from . import services

router = APIRouter(prefix="/pieafp", tags=["PIEAFP"])


# ── Dashboard ──────────────────────────────────────────────────────────────────

@router.get("/dashboard", response_model=PieafpDashboard)
def get_dashboard() -> PieafpDashboard:
    return services.get_pieafp_dashboard()


# ── Concentration ──────────────────────────────────────────────────────────────

@router.get("/concentration", response_model=ConcentrationResult)
def get_concentration() -> ConcentrationResult:
    return services.get_concentration()


# ── IRRBB ──────────────────────────────────────────────────────────────────────

@router.get("/irrbb", response_model=IrrbbResult)
def get_irrbb(choc_bp: int = 200) -> IrrbbResult:
    return services.get_irrbb(choc_bp=choc_bp)


@router.put("/irrbb/{tranche}", response_model=IrrbbTranche)
def update_irrbb_tranche(tranche: str, data: IrrbbUpdate) -> IrrbbTranche:
    try:
        return services.update_irrbb_tranche(tranche, data)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# ── Autres risques ─────────────────────────────────────────────────────────────

@router.get("/autres-risques", response_model=list[AutreRisque])
def list_autres_risques() -> list[AutreRisque]:
    return services.list_autres_risques()


@router.post("/autres-risques", response_model=AutreRisque, status_code=201)
def create_autre_risque(data: AutreRisqueCreate) -> AutreRisque:
    return services.create_autre_risque(data)


@router.put("/autres-risques/{id_}", response_model=AutreRisque)
def update_autre_risque(id_: int, data: AutreRisqueUpdate) -> AutreRisque:
    try:
        return services.update_autre_risque(id_, data)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.delete("/autres-risques/{id_}", status_code=204)
def delete_autre_risque(id_: int) -> None:
    services.delete_autre_risque(id_)


# ── Planification ──────────────────────────────────────────────────────────────

@router.get("/planification", response_model=PlanificationResult)
def get_planification() -> PlanificationResult:
    return services.get_planification()


@router.put("/planification/{annee}", response_model=PlanificationAnnee)
def upsert_planification_annee(annee: int, data: PlanificationAnneeUpdate) -> PlanificationAnnee:
    return services.upsert_planification_annee(annee, data)


# ── Scénarios de stress ────────────────────────────────────────────────────────

@router.get("/scenarios", response_model=list[ScenarioStress])
def list_scenarios() -> list[ScenarioStress]:
    return services.list_scenarios()


@router.post("/scenarios", response_model=ScenarioStress, status_code=201)
def create_scenario(data: ScenarioStressCreate) -> ScenarioStress:
    return services.create_scenario(data)


@router.put("/scenarios/{id_}", response_model=ScenarioStress)
def update_scenario(id_: int, data: ScenarioStressUpdate) -> ScenarioStress:
    try:
        return services.update_scenario(id_, data)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.delete("/scenarios/{id_}", status_code=204)
def delete_scenario(id_: int) -> None:
    services.delete_scenario(id_)


@router.get("/scenarios/{id_}/calcul", response_model=StressImpact)
def calcul_stress(id_: int) -> StressImpact:
    try:
        return services.calcul_stress(id_)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# ── Gouvernance / Checklist ────────────────────────────────────────────────────

@router.get("/gouvernance", response_model=GouvernanceResult)
def get_gouvernance() -> GouvernanceResult:
    return services.get_gouvernance()


@router.put("/gouvernance/{id_}", response_model=ChecklistItem)
def update_checklist_item(id_: int, data: ChecklistUpdate) -> ChecklistItem:
    try:
        return services.update_checklist_item(id_, data)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# ── Rapport ────────────────────────────────────────────────────────────────────

@router.get("/rapport", response_model=PieafpRapport)
def get_rapport() -> PieafpRapport:
    return services.get_rapport()
