"""Lot L2 du module ICAAP : exercices, cartographie des risques, paramètres.

Base temporaire : schema.sql est à jour ; les migrations historiques (schéma
anglais d'origine) ne sont pas rejouées — on les marque appliquées, SAUF
042_icaap.sql qui porte les tables testées ici.
"""

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
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL
            )
            """
        )
        for path in sorted(database_manager.migrations_dir.glob("*.sql")):
            try:
                version = int(path.stem.split("_", 1)[0])
            except ValueError:
                continue
            if version == 42:  # doit réellement s'exécuter
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


def _creer_exercice(annee: int = 2025, date_arrete: str = "2025-12-31") -> dict:
    reponse = client.post(
        "/icaap/exercices",
        json={"annee": annee, "date_arrete": date_arrete, "commentaire": "essai"},
    )
    assert reponse.status_code == 201, reponse.text
    return reponse.json()


# ── Routeur ─────────────────────────────────────────────────────────────────
def test_le_routeur_icaap_ne_porte_pas_le_prefixe_api():
    from app.icaap.routes import router

    assert router.prefix == "/icaap"


# ── Paramètres ──────────────────────────────────────────────────────────────
def test_parametres_exposent_la_valeur_en_vigueur_par_cle(temp_db):
    reponse = client.get("/api/icaap/parametres")
    assert reponse.status_code == 200
    params = {p["cle"]: p for p in reponse.json()}
    assert "ratio_solvabilite_min" in params
    assert "seuil_materialite_quanti" in params
    # une seule ligne par clé (la plus récente)
    cles = [p["cle"] for p in reponse.json()]
    assert len(cles) == len(set(cles))


# ── Exercices ───────────────────────────────────────────────────────────────
def test_creation_exercice_recopie_la_matrice_de_correlation_par_defaut(temp_db):
    exercice = _creer_exercice()
    assert exercice["statut"] == "brouillon"

    from database.connection import database_manager

    with database_manager.read_connection() as conn:
        n_defaut = conn.execute(
            "SELECT COUNT(*) FROM icaap_correlation_defaut"
        ).fetchone()[0]
        n_exercice = conn.execute(
            "SELECT COUNT(*) FROM icaap_correlation WHERE exercice_id = ?",
            (exercice["id"],),
        ).fetchone()[0]
    assert n_exercice == n_defaut > 0


def test_liste_et_lecture_exercice(temp_db):
    cree = _creer_exercice()
    liste = client.get("/api/icaap/exercices").json()
    assert any(e["id"] == cree["id"] for e in liste)

    detail = client.get(f"/api/icaap/exercices/{cree['id']}")
    assert detail.status_code == 200
    assert detail.json()["annee"] == 2025


def test_exercice_inexistant_repond_404_et_non_500(temp_db):
    reponse = client.get("/api/icaap/exercices/inexistant")
    assert reponse.status_code == 404
    assert reponse.json()["detail"]["code"] == "ICAAP_EXERCICE_INTROUVABLE"


def test_annee_deja_ouverte_repond_409(temp_db):
    _creer_exercice(annee=2026, date_arrete="2026-12-31")
    doublon = client.post(
        "/icaap/exercices",
        json={"annee": 2026, "date_arrete": "2026-12-31"},
    )
    assert doublon.status_code == 409
    assert doublon.json()["detail"]["code"] == "ICAAP_ANNEE_DEJA_OUVERTE"


def test_mise_a_jour_entete_en_brouillon(temp_db):
    cree = _creer_exercice()
    maj = client.put(
        f"/api/icaap/exercices/{cree['id']}",
        json={"opinion_executif": "Fonds propres jugés adéquats."},
    )
    assert maj.status_code == 200
    assert maj.json()["opinion_executif"] == "Fonds propres jugés adéquats."


def test_exercice_verrouille_refuse_la_modification(temp_db):
    cree = _creer_exercice()
    from database.connection import database_manager

    with database_manager.transaction() as conn:
        conn.execute(
            "UPDATE icaap_exercice SET statut = 'valide' WHERE id = ?",
            (cree["id"],),
        )

    maj = client.put(
        f"/api/icaap/exercices/{cree['id']}",
        json={"commentaire": "tentative"},
    )
    assert maj.status_code == 409
    assert maj.json()["detail"]["code"] == "ICAAP_EXERCICE_VERROUILLE"

    risques = client.post(
        f"/api/icaap/exercices/{cree['id']}/risques",
        json={"lignes": [{"categorie": "credit", "probabilite": 3, "impact": 3}]},
    )
    assert risques.status_code == 409


# ── Cartographie des risques ────────────────────────────────────────────────
def test_cartographie_calcule_materialite_et_bascule_quanti(temp_db):
    cree = _creer_exercice()
    payload = {
        "lignes": [
            {"categorie": "credit", "libelle": "Risque de crédit",
             "probabilite": 4, "impact": 4},
            {"categorie": "reputation", "libelle": "Risque de réputation",
             "probabilite": 2, "impact": 2, "methode": "quali"},
        ]
    }
    reponse = client.post(
        f"/api/icaap/exercices/{cree['id']}/risques", json=payload
    )
    assert reponse.status_code == 200
    par_categorie = {r["categorie"]: r for r in reponse.json()}

    assert par_categorie["credit"]["materialite"] == 16
    assert par_categorie["credit"]["methode"] == "quanti"  # 16 >= seuil 12
    assert par_categorie["reputation"]["materialite"] == 4
    assert par_categorie["reputation"]["methode"] == "quali"  # sous le seuil


def test_cartographie_remplace_integralement(temp_db):
    cree = _creer_exercice()
    client.post(
        f"/api/icaap/exercices/{cree['id']}/risques",
        json={"lignes": [{"categorie": "credit", "probabilite": 3, "impact": 3}]},
    )
    client.post(
        f"/api/icaap/exercices/{cree['id']}/risques",
        json={"lignes": [{"categorie": "marche", "probabilite": 2, "impact": 2}]},
    )
    final = client.get(f"/api/icaap/exercices/{cree['id']}/risques").json()
    assert [r["categorie"] for r in final] == ["marche"]


def test_cartographie_sur_exercice_inexistant_repond_404(temp_db):
    reponse = client.post(
        "/api/icaap/exercices/inexistant/risques",
        json={"lignes": []},
    )
    assert reponse.status_code == 404
