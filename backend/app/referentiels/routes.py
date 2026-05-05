"""Routes API du module referentiels."""

from fastapi import APIRouter

from app.referentiels.models import ReferentialBundle
from app.referentiels.services import get_referential_bundle

router = APIRouter(prefix="/referentiels", tags=["Referentiels"])


@router.get("", response_model=ReferentialBundle)
def get_referentiels() -> ReferentialBundle:
    """Expose les tables prudentielles au frontend."""

    return get_referential_bundle()
