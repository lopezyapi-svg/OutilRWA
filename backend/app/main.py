"""Point d'entree principal de l'API FastAPI."""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.crm.routes import router as crm_router
from app.dashboard.routes import router as dashboard_router
from app.expositions.routes import router as expositions_router
from app.hors_bilan.routes import router as hors_bilan_router
from app.rapports.routes import router as rapports_router
from app.referentiels.routes import router as referentiels_router
from database.connection import database_manager
from database.services.exposure_sync_service import exposure_sync_service

logger = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name, version=settings.app_version)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(dashboard_router)
app.include_router(expositions_router)
app.include_router(hors_bilan_router)
app.include_router(crm_router)
app.include_router(referentiels_router)
app.include_router(rapports_router)


@app.on_event("startup")
def initialize_local_storage() -> None:
    """Initialise SQLite au démarrage."""

    database_manager.initialize()
    try:
        exposure_sync_service.backfill_reference_fields_from_excel()
    except Exception:
        logger.exception(
            "Le backfill des dates/reference Expositions depuis Excel a échoué."
        )


@app.get("/")
def root() -> dict[str, str]:
    """Expose un message simple de sante de l'API."""

    return {"message": "RWA Calculator API is running"}
