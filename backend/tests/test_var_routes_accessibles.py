"""Les routes VaR doivent etre joignables par les deux clients.

Le poste de travail appelle « /var/... », le navigateur « /api/var/... » :
PrefixeApiMiddleware retire « /api » AVANT le routage. Un routeur declare sur
« /api/var » ne recevait donc jamais l'appel, ni prefixe (le prefixe etait
retire avant la comparaison) ni non prefixe (la route inconnue). L'onglet VaR
affichait « Not Found » sur les trois methodes.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

PARAMETRES = {
    "type_portefeuille": "obligations",
    "niveau_confiance": 0.99,
    "horizon_jours": 1,
    "fenetre_jours": 250,
}


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

    assert sans_prefixe.status_code == 200
    assert avec_prefixe.status_code == 200
    assert avec_prefixe.json()["methode"] == "parametrique"


def test_montecarlo_joignable_avec_et_sans_prefixe_api():
    parametres = dict(PARAMETRES, nb_simulations=1000)
    sans_prefixe = client.get("/var/montecarlo", params=parametres)
    avec_prefixe = client.get("/api/var/montecarlo", params=parametres)

    assert sans_prefixe.status_code == 200
    assert avec_prefixe.status_code == 200
    assert avec_prefixe.json()["methode"] == "montecarlo"


def test_historique_repond_422_et_non_404_sans_historique_de_prix():
    """L'absence d'historique est une donnee manquante, pas une route absente.

    Le 404 melangeait les deux causes : l'utilisateur ne pouvait pas
    distinguer « la fonction n'existe pas » de « il manque un fichier ».
    """

    reponse = client.get("/api/var/historique", params=PARAMETRES)

    assert reponse.status_code == 422
    detail = reponse.json()["detail"]
    assert detail["code"] == "VAR_PARAMETRE_INVALIDE"
    assert "historique" in detail["message"].lower()


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
