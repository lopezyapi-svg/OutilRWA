"""Lot L4 du module ICAAP : stress testing et planification du capital."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.icaap import calculations as calc
from app.main import app

client = TestClient(app)


@pytest.fixture
def temp_db(tmp_path, monkeypatch):
    from database.connection import database_manager

    monkeypatch.setattr(database_manager, "db_path", tmp_path / "test_rwa.db")
    connection = database_manager.connect()
    try:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL
            )
            """
        )
        for path in sorted(database_manager.migrations_dir.glob("*.sql")):
            try:
                version = int(path.stem.split("_", 1)[0])
            except ValueError:
                continue
            if version == 42:
                continue
            connection.execute(
                "INSERT OR IGNORE INTO schema_migrations(version, name, applied_at) "
                "VALUES (?, ?, ?)",
                (version, path.stem, "test"),
            )
        connection.commit()
    finally:
        connection.close()
    database_manager.initialize()
    yield database_manager


def _exercice_avec_capital(rwa: float = 8000.0) -> str:
    r = client.post(
        "/icaap/exercices", json={"annee": 2025, "date_arrete": "2025-12-31"}
    )
    exercice_id = r.json()["id"]
    client.put(
        f"/icaap/exercices/{exercice_id}/capital-dispo",
        json={"cet1": 1200, "deductions": 200, "rwa_pilier1_total": rwa},
    )
    return exercice_id


# ── Fonctions pures ────────────────────────────────────────────────────────
def test_projeter_scenario_a_une_ligne_par_annee_plus_la_base():
    lignes = calc.projeter_scenario(
        fonds_propres_0=1000, rwa_0=8000, hypotheses={}, horizon_annees=3
    )
    assert [l["annee_proj"] for l in lignes] == [0, 1, 2, 3]
    assert lignes[0]["ratio_projete"] == pytest.approx(12.5)


def test_projeter_scenario_choc_adverse_degrade_le_ratio():
    lignes = calc.projeter_scenario(
        fonds_propres_0=1000,
        rwa_0=8000,
        hypotheses={
            "pnb_annuel": 300, "charges_annuelles": 150, "cout_risque_annuel": 50,
            "choc_pnb_pct": -0.20, "choc_cout_risque_pct": 1.0, "choc_rwa_pct": 0.10,
        },
        horizon_annees=3,
    )
    assert lignes[-1]["ratio_projete"] < lignes[0]["ratio_projete"]
    assert lignes[-1]["rwa_projete"] > lignes[0]["rwa_projete"]


def test_projeter_plan_capital_detecte_l_entame_du_coussin():
    lignes, annee = calc.projeter_plan_capital(
        fonds_propres_0=1000, rwa_0=8000,
        croissance_encours_pct=15, marge_nette_pct=1.0, cout_risque_pct=1.5,
        taux_distribution_pct=0, horizon_annees=3, seuil_coussin_pct=11.5,
    )
    assert annee == 1
    assert lignes[1]["coussin_entame"] is True


def test_projeter_plan_capital_trajectoire_saine_ne_declenche_rien():
    lignes, annee = calc.projeter_plan_capital(
        fonds_propres_0=1000, rwa_0=8000,
        croissance_encours_pct=5, marge_nette_pct=3.0, cout_risque_pct=0.5,
        taux_distribution_pct=0, horizon_annees=3, seuil_coussin_pct=11.5,
    )
    assert annee is None
    assert all(not l["coussin_entame"] for l in lignes)


# ── Stress testing bout en bout ───────────────────────────────────────────
def test_creation_execution_scenario(temp_db):
    exercice_id = _exercice_avec_capital()
    cree = client.post(
        f"/api/icaap/exercices/{exercice_id}/scenarios",
        json={
            "libelle": "Récession sévère",
            "type_scenario": "severe",
            "horizon_annees": 3,
            "hypotheses": {
                "pnb_annuel": 300, "charges_annuelles": 150,
                "cout_risque_annuel": 50, "choc_pnb_pct": -0.20,
                "choc_cout_risque_pct": 1.0, "choc_rwa_pct": 0.10,
            },
        },
    )
    assert cree.status_code == 201, cree.text
    scenario_id = cree.json()["id"]
    assert cree.json()["resultats"] == []

    run = client.post(f"/api/icaap/scenarios/{scenario_id}/run")
    assert run.status_code == 200, run.text
    resultats = run.json()["resultats"]
    assert [r["annee_proj"] for r in resultats] == [0, 1, 2, 3]
    assert resultats[0]["ratio_projete"] == pytest.approx(12.5)
    assert resultats[-1]["ratio_projete"] < 12.5
    assert run.json()["dernier_run_le"] is not None

    liste = client.get(f"/api/icaap/exercices/{exercice_id}/scenarios").json()
    assert len(liste) == 1 and len(liste[0]["resultats"]) == 4


def test_run_sans_capital_dispo_repond_422(temp_db):
    r = client.post(
        "/icaap/exercices", json={"annee": 2027, "date_arrete": "2027-12-31"}
    )
    exercice_id = r.json()["id"]
    cree = client.post(
        f"/api/icaap/exercices/{exercice_id}/scenarios",
        json={"libelle": "s", "hypotheses": {}},
    )
    run = client.post(f"/api/icaap/scenarios/{cree.json()['id']}/run")
    assert run.status_code == 422
    assert run.json()["detail"]["code"] == "ICAAP_DONNEES_MANQUANTES"


def test_scenario_inexistant_repond_404(temp_db):
    r = client.post("/api/icaap/scenarios/inexistant/run")
    assert r.status_code == 404
    assert r.json()["detail"]["code"] == "ICAAP_SCENARIO_INTROUVABLE"


def test_suppression_scenario(temp_db):
    exercice_id = _exercice_avec_capital()
    cree = client.post(
        f"/api/icaap/exercices/{exercice_id}/scenarios",
        json={"libelle": "à supprimer", "hypotheses": {}},
    )
    sid = cree.json()["id"]
    assert client.delete(f"/api/icaap/scenarios/{sid}").status_code == 204
    assert client.get(f"/api/icaap/scenarios/{sid}").status_code == 404


# ── Planification du capital ──────────────────────────────────────────────
def test_plan_capital_bout_en_bout(temp_db):
    exercice_id = _exercice_avec_capital()
    calcul = client.post(
        f"/api/icaap/exercices/{exercice_id}/plan-capital",
        json={
            "croissance_encours_pct": 15, "marge_nette_pct": 1.0,
            "cout_risque_pct": 1.5, "taux_distribution_pct": 0,
        },
    )
    assert calcul.status_code == 200, calcul.text
    body = calcul.json()
    assert [l["annee_proj"] for l in body["trajectoire"]] == [0, 1, 2, 3]
    assert body["annee_entame_coussin"] == 1

    relu = client.get(f"/api/icaap/exercices/{exercice_id}/plan-capital").json()
    assert relu["annee_entame_coussin"] == 1
    assert relu["hypotheses"]["croissance_encours_pct"] == pytest.approx(15.0)


def test_plan_capital_refuse_sur_exercice_verrouille(temp_db):
    exercice_id = _exercice_avec_capital()
    from database.connection import database_manager

    with database_manager.transaction() as conn:
        conn.execute(
            "UPDATE icaap_exercice SET statut = 'valide' WHERE id = ?",
            (exercice_id,),
        )
    r = client.post(
        f"/api/icaap/exercices/{exercice_id}/plan-capital",
        json={"croissance_encours_pct": 5, "marge_nette_pct": 2.0,
              "cout_risque_pct": 0.5, "taux_distribution_pct": 0},
    )
    assert r.status_code == 409
