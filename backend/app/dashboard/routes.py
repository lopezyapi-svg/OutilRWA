"""Routes API du module dashboard."""

from fastapi import APIRouter

from app.dashboard.models import DashboardSnapshot
from app.dashboard.services import get_dashboard_snapshot

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("", response_model=DashboardSnapshot)
def get_dashboard() -> DashboardSnapshot:
    """Retourne la vue complete du dashboard."""

    return get_dashboard_snapshot()
