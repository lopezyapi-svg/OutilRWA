"""Services d'accès aux tables prudentielles."""

from __future__ import annotations

from database.repositories.referential_repository import referential_repository
from app.referentiels.models import CcfReference, RatingReference, ReferentialBundle, RiskWeightReference


def list_risk_weight_references() -> list[RiskWeightReference]:
    """Retourne les lignes de pondération RW depuis SQLite."""

    return referential_repository.list_risk_weight_references()


def list_ccf_references() -> list[CcfReference]:
    """Retourne les lignes CCF depuis SQLite."""

    return referential_repository.list_ccf_references()


def list_rating_references() -> list[RatingReference]:
    """Retourne la liste des notations disponibles."""

    return referential_repository.list_rating_references()


def get_risk_weight(segment: str, rating: str) -> float:
    """Recherche la pondération RW pour un segment et une note."""

    return referential_repository.get_risk_weight(segment, rating)


def get_ccf(engagement_type: str) -> float:
    """Recherche le CCF à appliquer à un engagement hors bilan."""

    return referential_repository.get_ccf(engagement_type)


def get_referential_bundle() -> ReferentialBundle:
    """Construit le paquet complet de référentiels."""

    return referential_repository.get_referential_bundle()
