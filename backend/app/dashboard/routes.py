"""Routes API du module dashboard."""

from fastapi import APIRouter

from app.dashboard.models import DashboardSnapshot, FondsPropresUpdate
from app.dashboard.services import get_dashboard_snapshot, update_fonds_propres

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("", response_model=DashboardSnapshot)
def get_dashboard() -> DashboardSnapshot:
    """Retourne la vue complete du dashboard."""

    return get_dashboard_snapshot()

@router.put("/fonds-propres", response_model=DashboardSnapshot)
def update_fp(data: FondsPropresUpdate) -> DashboardSnapshot:
    """Met a jour manuellement les fonds propres et retourne le nouveau dashboard."""
    return update_fonds_propres(data)
