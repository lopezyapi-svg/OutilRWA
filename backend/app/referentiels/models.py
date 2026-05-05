"""Modeles du module referentiels."""

from pydantic import BaseModel, Field


class RiskWeightReference(BaseModel):
    """Represente une ligne de table de ponderation RW."""

    id: str = Field(..., description="Identifiant de la ligne de referentiel.")
    segment: str = Field(..., description="Segment prudentiel concerne.")
    rating: str = Field(..., description="Bucket de notation.")
    risk_weight: float = Field(..., description="Ponderation prudentielle.")
    approach: str = Field(..., description="Approche reglementaire utilisee.")


class CcfReference(BaseModel):
    """Represente une ligne de table CCF."""

    id: str = Field(..., description="Identifiant de la ligne CCF.")
    engagement_type: str = Field(..., description="Nature de l'engagement.")
    ccf: float = Field(..., description="Facteur de conversion de credit.")


class RatingReference(BaseModel):
    """Represente une note disponible dans l'application."""

    id: str = Field(..., description="Identifiant de la notation.")
    label: str = Field(..., description="Libelle de la note.")
    description: str = Field(..., description="Description simple de la note.")
    sort_order: int = Field(..., description="Ordre d'affichage de la note.")


class ReferentialBundle(BaseModel):
    """Regroupe les referentiels exposes au frontend."""

    risk_weights: list[RiskWeightReference]
    ccf_table: list[CcfReference]
    ratings: list[RatingReference]
