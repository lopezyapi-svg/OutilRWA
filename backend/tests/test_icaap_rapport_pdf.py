"""Lot L5 du module ICAAP : plan d'action et rapport PDF."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

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


def _exercice(annee: int = 2025) -> str:
    return client.post(
        "/icaap/exercices",
        json={"annee": annee, "date_arrete": f"{annee}-12-31"},
    ).json()["id"]


def _remplir(exercice_id: str) -> None:
    client.post(
        f"/icaap/exercices/{exercice_id}/risques",
        json={"lignes": [
            {"categorie": "credit", "libelle": "Crédit", "probabilite": 5, "impact": 5},
            {"categorie": "marche", "libelle": "Marché", "probabilite": 3, "impact": 3},
            {"categorie": "reputation", "probabilite": 2, "impact": 2, "methode": "quali"},
        ]},
    )
    client.put(
        f"/icaap/exercices/{exercice_id}/capital-dispo",
        json={"cet1": 1200, "deductions": 200, "rwa_pilier1_total": 8000},
    )
    client.post(
        f"/icaap/exercices/{exercice_id}/capital-economique",
        json={"rwa_credit": 6000, "rwa_marche": 2000, "buffers_quali": {"reputation": 25}},
    )
    sc = client.post(
        f"/icaap/exercices/{exercice_id}/scenarios",
        json={"libelle": "Récession", "type_scenario": "adverse",
              "hypotheses": {"pnb_annuel": 300, "charges_annuelles": 150,
                             "cout_risque_annuel": 50, "choc_cout_risque_pct": 1.0,
                             "choc_rwa_pct": 0.1}},
    ).json()
    client.post(f"/icaap/scenarios/{sc['id']}/run")
    client.post(
        f"/icaap/exercices/{exercice_id}/plan-capital",
        json={"croissance_encours_pct": 12, "marge_nette_pct": 1.0,
              "cout_risque_pct": 1.2, "taux_distribution_pct": 0},
    )
    client.put(
        f"/icaap/exercices/{exercice_id}/plan-action",
        json={"lignes": [
            {"constat": "Ratio de couverture sous 100 %", "action": "Renforcer le CET1",
             "responsable": "DAF", "echeance": "2026-06-30", "statut": "ouvert"},
        ]},
    )
    client.put(
        f"/icaap/exercices/{exercice_id}",
        json={"opinion_executif": "Les fonds propres restent adéquats.",
              "avis_deliberant": "Le conseil approuve."},
    )


def _est_pdf(contenu: bytes) -> bool:
    return contenu[:4] == b"%PDF" and b"%%EOF" in contenu[-1024:]


# ── Plan d'action ─────────────────────────────────────────────────────────
def test_plan_action_roundtrip(temp_db):
    exercice_id = _exercice()
    maj = client.put(
        f"/api/icaap/exercices/{exercice_id}/plan-action",
        json={"lignes": [
            {"constat": "c1", "action": "a1", "responsable": "r1",
             "echeance": "2026-03-31", "statut": "en_cours"},
        ]},
    )
    assert maj.status_code == 200
    assert maj.json()[0]["statut"] == "en_cours"
    assert maj.json()[0]["id"]

    relu = client.get(f"/api/icaap/exercices/{exercice_id}/plan-action").json()
    assert len(relu) == 1 and relu[0]["action"] == "a1"


def test_plan_action_refuse_sur_exercice_verrouille(temp_db):
    exercice_id = _exercice()
    from database.connection import database_manager

    with database_manager.transaction() as conn:
        conn.execute(
            "UPDATE icaap_exercice SET statut = 'valide' WHERE id = ?",
            (exercice_id,),
        )
    r = client.put(
        f"/api/icaap/exercices/{exercice_id}/plan-action",
        json={"lignes": []},
    )
    assert r.status_code == 409


# ── Rapport PDF ───────────────────────────────────────────────────────────
def test_rapport_pdf_exercice_minimal(temp_db):
    exercice_id = _exercice()
    r = client.get(f"/api/icaap/exercices/{exercice_id}/rapport.pdf")
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/pdf"
    assert "Rapport_ICAAP_2025" in r.headers["content-disposition"]
    assert _est_pdf(r.content)
    assert len(r.content) > 2500


def test_rapport_pdf_exercice_complet_est_plus_riche(temp_db):
    minimal_id = _exercice(2024)
    minimal = client.get(f"/api/icaap/exercices/{minimal_id}/rapport.pdf").content

    complet_id = _exercice(2025)
    _remplir(complet_id)
    complet = client.get(f"/api/icaap/exercices/{complet_id}/rapport.pdf")
    assert complet.status_code == 200
    assert _est_pdf(complet.content)
    # Le rapport rempli (tables + graphique) pèse nettement plus lourd.
    assert len(complet.content) > len(minimal) + 3000


def test_rapport_pdf_exercice_inexistant_repond_404(temp_db):
    r = client.get("/api/icaap/exercices/inexistant/rapport.pdf")
    assert r.status_code == 404
    assert r.json()["detail"]["code"] == "ICAAP_EXERCICE_INTROUVABLE"


def test_rapport_pdf_disponible_apres_validation(temp_db):
    exercice_id = _exercice()
    _remplir(exercice_id)
    from database.connection import database_manager

    with database_manager.transaction() as conn:
        conn.execute(
            "UPDATE icaap_exercice SET statut = 'archive' WHERE id = ?",
            (exercice_id,),
        )
    r = client.get(f"/api/icaap/exercices/{exercice_id}/rapport.pdf")
    assert r.status_code == 200
    assert "archive" in r.headers["content-disposition"]
    assert _est_pdf(r.content)
