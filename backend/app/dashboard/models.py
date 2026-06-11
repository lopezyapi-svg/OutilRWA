"""Modeles du module dashboard."""

from pydantic import BaseModel, Field


class DashboardMetric(BaseModel):
    """Represente une carte de KPI du dashboard."""

    key: str = Field(..., description="Cle technique du KPI.")
    label: str = Field(..., description="Libelle metier du KPI.")
    value: float = Field(..., description="Valeur principale du KPI.")
    variation: str = Field(..., description="Variation courte affichee sur la carte.")
    trend: list[float] = Field(..., description="Serie courte pour le mini graphique.")


class DistributionEntry(BaseModel):
    """Represente une repartition simple pour un graphique."""

    label: str = Field(..., description="Libelle de la categorie.")
    amount: float = Field(..., description="Montant du bucket.")
    percentage: float = Field(..., description="Part du bucket dans le total.")


class PortfolioRow(BaseModel):
    """Represente une ligne de synthese du portefeuille."""

    id: str
    analysis_date: str
    counterparty: str
    country: str
    category: str
    rating: str
    crm_type: str
    gross_amount: float
    on_balance_exposure_amount: float = 0.0
    off_balance_exposure_amount: float = 0.0
    ead: float
    rwa: float
    capital: float


class DashboardProjectionPoint(BaseModel):
    """Represente un point de projection de maturite."""

    label: str
    value: float

class DashboardSnapshot(BaseModel):
    """Represente le contenu complet du dashboard."""

    metrics: list[DashboardMetric]
    valuation_date: str
    category_distribution: list[DistributionEntry]
    rwa_category_distribution: list[DistributionEntry]
    country_distribution: list[DistributionEntry]
    crm_distribution: list[DistributionEntry]
    rating_distribution: list[DistributionEntry]
    rwa_projection: list[DashboardProjectionPoint]
    portfolio_overview: list[PortfolioRow]
