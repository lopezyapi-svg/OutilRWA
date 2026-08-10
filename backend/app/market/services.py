"""Resolution du capital reglementaire risque de marche pour le Dashboard.

Le module Risque de Marche (VaR, taux, actions, change) calcule et persiste
son propre resultat (`MARKET_CAPITAL_REQUIREMENT_KEY`). Ce module fournit un
point d'acces unique pour les consommateurs (dashboard, RWA credit) qui
retombent sur l'ancien stub `risque_marche` (position nette de change
simplifiee) tant que rien n'a encore ete calcule/enregistre.
"""

from __future__ import annotations

import json
from typing import Any

from database.connection import database_manager

from app.core.bceao_calculations import calculate_risque_marche

MARKET_CAPITAL_REQUIREMENT_KEY = "market_capital_requirement_v1"


def resolve_market_capital(rm_data: dict[str, Any]) -> dict[str, float]:
    """Retourne l'exigence de fonds propres et le RWA du risque de marche.

    Priorise le resultat persiste par le module Risque de Marche ; retombe
    sur `calculate_risque_marche` (stub `position_nette_change`) si rien n'a
    encore ete enregistre.
    """

    with database_manager.read_connection() as connection:
        row = connection.execute(
            "SELECT valeur FROM metadonnees_app WHERE cle = ?",
            (MARKET_CAPITAL_REQUIREMENT_KEY,),
        ).fetchone()

    if row is not None and str(row["valeur"] or "").strip():
        try:
            payload = json.loads(str(row["valeur"]))
            return {
                "exigence_fonds_propres": round(float(payload["capital_requis"]), 2),
                "rwa_marche": round(float(payload["rwa_marche"]), 2),
            }
        except (json.JSONDecodeError, KeyError, TypeError, ValueError):
            pass

    return calculate_risque_marche(rm_data)
