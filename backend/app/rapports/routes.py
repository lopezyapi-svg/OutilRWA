"""Routes API du module rapports."""

from fastapi import APIRouter, status

from app.rapports.models import ReportRequest, ReportView
from app.rapports.services import generate_report, list_reports

router = APIRouter(prefix="/rapports", tags=["Rapports"])


@router.get("", response_model=list[ReportView])
def get_reports() -> list[ReportView]:
    """Retourne les rapports disponibles."""

    return list_reports()


@router.post("", response_model=ReportView, status_code=status.HTTP_201_CREATED)
def post_report(payload: ReportRequest) -> ReportView:
    """Genere un nouveau rapport."""

    return generate_report(payload)
