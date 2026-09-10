"""Lot L3 du module ICAAP : capital économique, corrélations, couverture."""

from __future__ import annotations

import math

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


def _exercice() -> str:
    r = client.post(
        "/icaap/exercices", json={"annee": 2025, "date_arrete": "2025-12-31"}
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _cartographie(exercice_id: str) -> None:
    r = client.post(
        f"/icaap/exercices/{exercice_id}/risques",
        json={
            "lignes": [
                {"categorie": "credit", "probabilite": 5, "impact": 5},
                {"categorie": "marche", "probabilite": 3, "impact": 4},
                {"categorie": "operationnel", "probabilite": 3, "impact": 4},
                {"categorie": "reputation", "probabilite": 2, "impact": 2,
                 "methode": "quali"},
            ]
        },
    )
    assert r.status_code == 200, r.text


# ── Fonctions pures ────────────────────────────────────────────────────────
def test_cle_correlation_normalise_les_libelles():
    assert calc.cle_correlation("Risque de crédit") == "credit"
    assert calc.cle_correlation("IRRBB") == "taux"
    assert calc.cle_correlation("Grands risques") == "concentration"
    assert calc.cle_correlation("Truc inconnu") == "autre"


def test_agregation_correlation_parfaite_egale_somme_simple():
    besoins = {"credit": 300.0, "marche": 400.0}
    corr = [("credit", "marche", 1.0)]
    assert calc.agreger_par_correlation(besoins, corr) == pytest.approx(700.0)


def test_agregation_correlation_nulle_est_racine_des_carres():
    besoins = {"credit": 300.0, "marche": 400.0}
    assert calc.agreger_par_correlation(besoins, []) == pytest.approx(500.0)


def test_agregation_un_seul_risque_est_lui_meme():
    assert calc.agreger_par_correlation({"credit": 250.0}, []) == pytest.approx(250.0)


def test_diversification_reduit_le_besoin():
    besoins = {"credit": 300.0, "marche": 400.0, "operationnel": 200.0}
    corr = [
        ("credit", "marche", 0.5),
        ("credit", "operationnel", 0.3),
        ("marche", "operationnel", 0.2),
    ]
    diversifie = calc.agreger_par_correlation(besoins, corr)
    assert diversifie < calc.somme_simple(besoins)
    assert diversifie > 500.0  # au-dessus du cas décorrélé


# ── Bout en bout ──────────────────────────────────────────────────────────
def test_calcul_capital_economique_et_couverture(temp_db):
    exercice_id = _exercice()
    _cartographie(exercice_id)

    maj = client.put(
        f"/api/icaap/exercices/{exercice_id}/capital-dispo",
        json={"cet1": 800, "at1": 100, "t2": 200, "deductions": 100,
              "rwa_pilier1_total": 10000, "source": "arrêté 12/2025"},
    )
    assert maj.status_code == 200
    assert maj.json()["capital_interne_total"] == pytest.approx(1000.0)

    calcul = client.post(
        f"/api/icaap/exercices/{exercice_id}/capital-economique",
        json={
            "ratio_cible_pct": 11.5,
            "rwa_credit": 6000,
            "rwa_marche": 2000,
            "rwa_operationnel": 2000,
            "irrbb_impact_eve": 50,
            "buffers_quali": {"reputation": 25},
        },
    )
    assert calcul.status_code == 200, calcul.text
    lignes = {l["cle_correlation"]: l for l in calcul.json()}
    assert lignes["credit"]["montant_besoin"] == pytest.approx(690.0)  # 6000 * 11.5%
    assert lignes["marche"]["montant_besoin"] == pytest.approx(230.0)
    assert lignes["reputation"]["montant_besoin"] == pytest.approx(25.0)

    couv = client.get(f"/api/icaap/exercices/{exercice_id}/couverture")
    assert couv.status_code == 200, couv.text
    body = couv.json()
    assert body["besoin_somme_simple"] >= body["besoin_apres_diversification"] > 0
    assert body["benefice_diversification"] == pytest.approx(
        body["besoin_somme_simple"] - body["besoin_apres_diversification"], abs=0.01
    )
    assert body["capital_interne_disponible"] == pytest.approx(1000.0)
    # capital 1000 < besoin diversifié (~1035) => alerte
    assert body["en_alerte"] is (body["ratio_couverture"] < 100.0)


def test_couverture_sans_capital_dispo_repond_422(temp_db):
    exercice_id = _exercice()
    _cartographie(exercice_id)
    client.post(
        f"/api/icaap/exercices/{exercice_id}/capital-economique",
        json={"rwa_credit": 1000},
    )
    r = client.get(f"/api/icaap/exercices/{exercice_id}/couverture")
    assert r.status_code == 422
    assert r.json()["detail"]["code"] == "ICAAP_DONNEES_MANQUANTES"


def test_couverture_sans_calcul_prealable_repond_422(temp_db):
    exercice_id = _exercice()
    _cartographie(exercice_id)
    client.put(
        f"/api/icaap/exercices/{exercice_id}/capital-dispo",
        json={"cet1": 1000},
    )
    r = client.get(f"/api/icaap/exercices/{exercice_id}/couverture")
    assert r.status_code == 422


def test_capital_economique_sans_cartographie_repond_422(temp_db):
    exercice_id = _exercice()
    r = client.post(
        f"/api/icaap/exercices/{exercice_id}/capital-economique",
        json={"rwa_credit": 1000},
    )
    assert r.status_code == 422


def test_matrice_correlation_initialisee_puis_remplacee(temp_db):
    exercice_id = _exercice()
    initiale = client.get(f"/api/icaap/exercices/{exercice_id}/correlations").json()
    assert len(initiale) > 0  # recopiée du gabarit à la création

    remplacee = client.put(
        f"/api/icaap/exercices/{exercice_id}/correlations",
        json={"lignes": [
            {"risque_a": "marche", "risque_b": "credit", "coefficient": 0.9},
            {"risque_a": "x", "risque_b": "x", "coefficient": 0.5},  # diagonale ignorée
        ]},
    )
    assert remplacee.status_code == 200
    corr = remplacee.json()
    assert len(corr) == 1
    assert corr[0]["risque_a"] == "credit" and corr[0]["risque_b"] == "marche"
    assert corr[0]["coefficient"] == pytest.approx(0.9)


def test_calcul_refuse_sur_exercice_verrouille(temp_db):
    exercice_id = _exercice()
    _cartographie(exercice_id)
    from database.connection import database_manager

    with database_manager.transaction() as conn:
        conn.execute(
            "UPDATE icaap_exercice SET statut = 'valide' WHERE id = ?",
            (exercice_id,),
        )
    r = client.post(
        f"/api/icaap/exercices/{exercice_id}/capital-economique",
        json={"rwa_credit": 1000},
    )
    assert r.status_code == 409
