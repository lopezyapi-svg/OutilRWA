"""Routes FastAPI du module Risque Opérationnel."""

from fastapi import APIRouter, Query
from fastapi.responses import Response

from .models import (
    ControleCreate,
    ControleUpdate,
    ControleView,
    DashboardData,
    HistoriqueView,
    IncidentBulkImportRequest,
    IncidentCreate,
    IncidentImportResult,
    IncidentUpdate,
    IncidentView,
    KriModuleData,
    KriValeurCreate,
    KriValeurView,
    PlanCreate,
    PlanUpdate,
    PlanView,
    RisqueCreate,
    RisqueUpdate,
    RisqueView,
)
from . import services

router = APIRouter(prefix="/risque-operationnel", tags=["Risque Opérationnel"])


# ─── Dashboard ────────────────────────────────────────────────────────────────

@router.get("/dashboard", response_model=DashboardData)
def get_dashboard() -> DashboardData:
    return services.get_dashboard()


# ─── Incidents ────────────────────────────────────────────────────────────────

@router.get("/incidents", response_model=list[IncidentView])
def list_incidents(
    statut: str | None = Query(default=None),
    ligne_metier: str | None = Query(default=None),
) -> list[IncidentView]:
    return services.list_incidents(statut=statut, ligne_metier=ligne_metier)


@router.post("/incidents", response_model=IncidentView, status_code=201)
def create_incident(data: IncidentCreate) -> IncidentView:
    return services.create_incident(data)


@router.put("/incidents/{id_}", response_model=IncidentView)
def update_incident(id_: str, data: IncidentUpdate) -> IncidentView:
    return services.update_incident(id_, data)


@router.delete("/incidents/{id_}", status_code=204)
def delete_incident(id_: str) -> None:
    services.delete_incident(id_)


@router.get("/incidents/import/template")
def download_import_template() -> Response:
    """Télécharge le modèle Excel d'import des pertes opérationnelles."""
    template_bytes = services.build_ro_import_template()
    return Response(
        content=template_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=modele_import_pertes_op.xlsx"},
    )


@router.post("/incidents/import", response_model=IncidentImportResult)
def bulk_import_incidents(data: IncidentBulkImportRequest) -> IncidentImportResult:
    return services.bulk_import_incidents(data)


# ─── KRI ──────────────────────────────────────────────────────────────────────

@router.get("/kri", response_model=KriModuleData)
def get_kri() -> KriModuleData:
    return services.get_kri_module()


@router.post("/kri/valeurs", response_model=KriValeurView, status_code=201)
def add_kri_valeur(data: KriValeurCreate) -> KriValeurView:
    return services.add_kri_valeur(data)


@router.post("/kri/auto-calcul", response_model=KriModuleData)
def auto_calcul_kri() -> KriModuleData:
    return services.auto_calcul_kri()


# ─── Cartographie des risques ─────────────────────────────────────────────────

@router.get("/risques", response_model=list[RisqueView])
def list_risques() -> list[RisqueView]:
    return services.list_risques()


@router.post("/risques", response_model=RisqueView, status_code=201)
def create_risque(data: RisqueCreate) -> RisqueView:
    return services.create_risque(data)


@router.put("/risques/{id_}", response_model=RisqueView)
def update_risque(id_: str, data: RisqueUpdate) -> RisqueView:
    return services.update_risque(id_, data)


@router.delete("/risques/{id_}", status_code=204)
def delete_risque(id_: str) -> None:
    services.delete_risque(id_)


# ─── Contrôles internes ───────────────────────────────────────────────────────

@router.get("/controles", response_model=list[ControleView])
def list_controles() -> list[ControleView]:
    return services.list_controles()


@router.post("/controles", response_model=ControleView, status_code=201)
def create_controle(data: ControleCreate) -> ControleView:
    return services.create_controle(data)


@router.put("/controles/{id_}", response_model=ControleView)
def update_controle(id_: str, data: ControleUpdate) -> ControleView:
    return services.update_controle(id_, data)


@router.delete("/controles/{id_}", status_code=204)
def delete_controle(id_: str) -> None:
    services.delete_controle(id_)


# ─── Plans d'actions ──────────────────────────────────────────────────────────

@router.get("/plans", response_model=list[PlanView])
def list_plans() -> list[PlanView]:
    return services.list_plans()


@router.post("/plans", response_model=PlanView, status_code=201)
def create_plan(data: PlanCreate) -> PlanView:
    return services.create_plan(data)


@router.put("/plans/{id_}", response_model=PlanView)
def update_plan(id_: str, data: PlanUpdate) -> PlanView:
    return services.update_plan(id_, data)


@router.delete("/plans/{id_}", status_code=204)
def delete_plan(id_: str) -> None:
    services.delete_plan(id_)


# ─── Historique ───────────────────────────────────────────────────────────────

@router.get("/historique", response_model=list[HistoriqueView])
def list_historique(limit: int = Query(default=200, le=1000)) -> list[HistoriqueView]:
    return services.list_historique(limit=limit)
