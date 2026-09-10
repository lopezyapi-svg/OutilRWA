"""Les routes VaR doivent etre joignables par les deux clients.

Le poste de travail appelle « /var/... », le navigateur « /api/var/... » :
PrefixeApiMiddleware retire « /api » AVANT le routage. Un routeur declare sur
« /api/var » ne recevait donc jamais l'appel, ni prefixe (le prefixe etait
retire avant la comparaison) ni non prefixe (la route inconnue). L'onglet VaR
affichait « Not Found » sur les trois methodes.

Les calculs param/Monte-Carlo sont exerces sur la serie SIMULEE reproductible
(VAR_MODE_SIMULATION=1) : ces tests portent sur le routage et le contrat de
reponse, pas sur des donnees de portefeuille reelles.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.var_marche import portefeuille_data

client = TestClient(app)

PARAMETRES = {
    "type_portefeuille": "obligations",
    "niveau_confiance": 0.99,
    "horizon_jours": 1,
    "fenetre_jours": 250,
}


@pytest.fixture(scope="module", autouse=True)
def _serie_simulee_isolee(tmp_path_factory):
    """Isole la couche de donnees (repertoire vide + base dediee) et active
    la serie simulee : param et Monte-Carlo repondent alors 200 sans qu'un
    portefeuille reel soit importe sur la machine de test."""

    from database.connection import database_manager

    patchs = pytest.MonkeyPatch()
    racine_vide = tmp_path_factory.mktemp("var_routes_data")
    patchs.setattr(portefeuille_data, "app_data_root", lambda: racine_vide)
    patchs.setattr(database_manager, "db_path", racine_vide / "var_routes.db")
    patchs.setenv("VAR_MODE_SIMULATION", "1")
    patchs.delenv("VAR_POSTGRES_DSN", raising=False)
    portefeuille_data.invalider_cache_series()
    yield
    patchs.undo()
    portefeuille_data.invalider_cache_series()


def test_le_routeur_var_ne_porte_pas_le_prefixe_api():
    """Le prefixe « /api » appartient au middleware, pas au routeur."""

    from app.var_marche.routes import router

    assert router.prefix == "/var", (
        "Le routeur VaR ne doit pas porter « /api » : le middleware le retire "
        "avant le routage, la route deviendrait inatteignable."
    )


def test_parametrique_joignable_avec_et_sans_prefixe_api():
    sans_prefixe = client.get("/var/parametrique", params=PARAMETRES)
    avec_prefixe = client.get("/api/var/parametrique", params=PARAMETRES)

    assert sans_prefixe.status_code != 404
    assert avec_prefixe.status_code != 404
    assert sans_prefixe.status_code == 200
    assert avec_prefixe.status_code == 200
    assert avec_prefixe.json()["methode"] == "parametrique"


def test_montecarlo_joignable_avec_et_sans_prefixe_api():
    parametres = dict(PARAMETRES, nb_simulations=1000)
    sans_prefixe = client.get("/var/montecarlo", params=parametres)
    avec_prefixe = client.get("/api/var/montecarlo", params=parametres)

    assert sans_prefixe.status_code != 404
    assert avec_prefixe.status_code != 404
    assert sans_prefixe.status_code == 200
    assert avec_prefixe.status_code == 200
    assert avec_prefixe.json()["methode"] == "montecarlo"


def test_historique_repond_par_un_message_et_non_404_sans_historique_de_prix(
    tmp_path, monkeypatch
):
    """L'absence d'historique est une donnee manquante, pas une route absente.

    Le 404 melangeait les deux causes : l'utilisateur ne pouvait pas
    distinguer « la fonction n'existe pas » de « il manque un fichier ».
    Hors mode simulation, la reponse doit etre un 422 explicite (route bien
    presente), jamais un 404.
    """

    from database.connection import database_manager

    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    monkeypatch.setattr(
        database_manager, "db_path", tmp_path / "var_historique_vide.db"
    )
    monkeypatch.delenv("VAR_MODE_SIMULATION", raising=False)
    monkeypatch.delenv("VAR_POSTGRES_DSN", raising=False)
    portefeuille_data.invalider_cache_series()

    reponse = client.get("/api/var/historique", params=PARAMETRES)

    assert reponse.status_code != 404
    assert reponse.status_code == 422
    detail = reponse.json()["detail"]
    assert detail["code"] in {
        "VAR_PARAMETRE_INVALIDE",
        "VAR_DONNEES_ABSENTES",
    }
    assert (
        "historique" in detail["message"].lower()
        or "donnée" in detail["message"].lower()
        or "donnee" in detail["message"].lower()
    )

    portefeuille_data.invalider_cache_series()


def test_toutes_les_routes_var_declarees_sont_atteignables():
    """Aucune route VaR ne doit etre publiee sans etre joignable."""

    chemins_var = [
        route.path
        for route in app.routes
        if getattr(route, "path", "").startswith("/var/")
    ]

    assert chemins_var, "Aucune route VaR enregistree."
    for chemin in chemins_var:
        assert not chemin.startswith("/api/"), (
            f"{chemin} porte le prefixe « /api » : il sera retire par le "
            "middleware et la route ne repondra jamais."
        )
