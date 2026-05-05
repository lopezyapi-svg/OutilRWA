"""Configuration simple de l'application."""

from dataclasses import dataclass


@dataclass(slots=True)
class Settings:
    """Contient les parametres simples utilises par l'API."""

    app_name: str = "RWA Calculator API"
    app_version: str = "0.1.0"
    capital_ratio: float = 0.08


settings = Settings()
