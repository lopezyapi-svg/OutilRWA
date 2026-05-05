"""Modeles du module rapports."""

from datetime import date

from pydantic import BaseModel, Field


class ReportRequest(BaseModel):
    """Represente les filtres utilises pour generer un rapport."""

    period: str = Field(..., description="Periode de reporting.")
    report_type: str = Field(..., description="Type de rapport attendu.")
    currency: str = Field(default="EUR", description="Monnaie du rapport.")
    exposure_scope: str = Field(default="Toutes", description="Portee des expositions.")
    include_category_chart: bool = Field(default=True, description="Inclut la repartition par categorie.")
    include_rating_chart: bool = Field(default=True, description="Inclut la repartition par notation.")


class ReportLine(BaseModel):
    """Represente une ligne de rapport detaille."""

    source: str
    item_id: str
    counterparty: str
    amount: float
    ead: float
    rwa: float
    capital: float


class ReportView(BaseModel):
    """Represente un rapport genere et ses exports."""

    id: str
    created_at: date
    period: str
    report_type: str
    currency: str
    exposure_scope: str
    include_category_chart: bool
    include_rating_chart: bool
    exports: dict[str, str]
    lines: list[ReportLine] = []

