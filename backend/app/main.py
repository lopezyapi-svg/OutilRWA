"""Point d'entree principal de l'API FastAPI."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.crm.routes import router as crm_router
from app.dashboard.routes import router as dashboard_router
from app.expositions.routes import router as expositions_router
from app.hors_bilan.routes import router as hors_bilan_router
from app.market.routes import router as market_router
from app.rapports.routes import router as rapports_router
from app.referentiels.routes import router as referentiels_router
from app.risque_operationnel.routes import router as risque_operationnel_router
from database.connection import database_manager
from database.services.exposure_sync_service import exposure_sync_service

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gère le démarrage et l'arrêt de l'application."""
    # Startup
    database_manager.initialize()
    try:
        exposure_sync_service.schedule_reference_fields_backfill()
    except Exception:
        logger.exception(
            "La planification du backfill des dates/reference Expositions a échoué."
        )
    yield
    # Shutdown
    logger.info("Application en cours d'arrêt...")


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)

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
app.include_router(market_router)
app.include_router(risque_operationnel_router)


@app.get("/")
def root() -> dict[str, str]:
    """Expose un message simple de sante de l'API."""

    return {"message": "Risk management API is running"}
