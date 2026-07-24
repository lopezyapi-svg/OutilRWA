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

    # On verifie que la route existe, pas qu'elle trouve des donnees : le
    # dossier « backend/data » est ignore par le depot, un poste neuf n'a donc
    # aucun portefeuille. Un 422 « donnees absentes » prouve deja que la route
    # a ete atteinte ; c'est le 404 qui trahissait le prefixe fautif.
    assert sans_prefixe.status_code != 404
    assert avec_prefixe.status_code != 404


def test_montecarlo_joignable_avec_et_sans_prefixe_api():
    parametres = dict(PARAMETRES, nb_simulations=1000)
    sans_prefixe = client.get("/var/montecarlo", params=parametres)
    avec_prefixe = client.get("/api/var/montecarlo", params=parametres)

    assert sans_prefixe.status_code != 404
    assert avec_prefixe.status_code != 404


def test_historique_joignable_avec_et_sans_prefixe_api():
    sans_prefixe = client.get("/var/historique", params=PARAMETRES)
    avec_prefixe = client.get("/api/var/historique", params=PARAMETRES)

    assert sans_prefixe.status_code != 404
    assert avec_prefixe.status_code != 404


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
