"""Déblocage de la VaR par la seule courbe UEMOA, sans portefeuille importé.

Scénario : l'utilisateur n'a importé aucune position obligataire mais a
actualisé la courbe des taux. Les VaR paramétrique et Monte-Carlo doivent
alors se calculer en mode réglementaire à partir de la valeur et de la
duration modifiée saisies ; la VaR historique reste indisponible.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.var_marche import portefeuille_data

client = TestClient(app)

_BASE = {
    "type_portefeuille": "obligations",
    "niveau_confiance": 0.99,
    "horizon_jours": 1,
    "fenetre_jours": 250,
}


@pytest.fixture(autouse=True)
def _donnees_isolees_courbe_seule(tmp_path, monkeypatch):
    """Répertoire vide + base dédiée + simulation OFF, puis dépôt d'une
    courbe UEMOA sur cinq jours (aucune position)."""

    from database.connection import database_manager

    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    monkeypatch.setattr(
        database_manager, "db_path", tmp_path / "var_courbe_seule.db"
    )
    monkeypatch.delenv("VAR_MODE_SIMULATION", raising=False)
    monkeypatch.delenv("VAR_POSTGRES_DSN", raising=False)

    lignes = ["date;maturite_annees;taux_pct"]
    for i, jour in enumerate(range(20, 25)):
        taux_5a = 6.50 + 0.03 * i
        lignes += [
            f"2026-05-{jour:02d};1;5.60",
            f"2026-05-{jour:02d};5;{taux_5a:.2f}",
            f"2026-05-{jour:02d};10;7.10",
        ]
    (tmp_path / "historique_taux.csv").write_text(
        "\n".join(lignes) + "\n", encoding="utf-8"
    )
    portefeuille_data.invalider_cache_series()
    yield
    portefeuille_data.invalider_cache_series()


def test_parametrique_debloquee_par_la_courbe():
    reponse = client.get(
        "/api/var/parametrique",
        params={
            **_BASE,
            "valeur_portefeuille": 500.0,
            "duration_modifiee": 3.4,
            "volatilite": 0.03,
        },
    )
    assert reponse.status_code == 200, reponse.text
    corps = reponse.json()
    assert corps["source_donnees"] == "courbe"
    assert corps["mode_calcul"] == "reglementaire"
    assert corps["var"] > 0
    assert any("réglementaire" in a for a in corps["avertissements"])


def test_montecarlo_debloquee_par_la_courbe():
    reponse = client.get(
        "/api/var/montecarlo",
        params={
            **_BASE,
            "valeur_portefeuille": 500.0,
            "duration_modifiee": 3.4,
            "volatilite": 0.03,
            "nb_simulations": 10_000,
        },
    )
    assert reponse.status_code == 200, reponse.text
    corps = reponse.json()
    assert corps["source_donnees"] == "courbe"
    assert corps["var"] > 0


def test_valeur_portefeuille_exigee():
    reponse = client.get("/api/var/parametrique", params=_BASE)
    assert reponse.status_code == 422
    assert reponse.json()["detail"]["code"] == "VAR_VALEUR_PORTEFEUILLE_REQUISE"


def test_duration_positive_exigee():
    reponse = client.get(
        "/api/var/parametrique",
        params={**_BASE, "valeur_portefeuille": 500.0, "duration_modifiee": 0.0},
    )
    assert reponse.status_code == 422
    assert reponse.json()["detail"]["code"] == "VAR_DURATION_REQUISE"


def test_historique_reste_indisponible_sans_prix():
    reponse = client.get(
        "/api/var/historique",
        params={**_BASE, "valeur_portefeuille": 500.0},
    )
    assert reponse.status_code == 422
    assert reponse.json()["detail"]["code"] in {
        "VAR_PARAMETRE_INVALIDE",
        "VAR_DONNEES_ABSENTES",
    }
