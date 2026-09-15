"""Non-régression des moteurs de calcul du Risque Opérationnel (BIC/CRR3, AIB,
Approche Standard).

Aucun test n'existait pour ce module avant celui-ci alors qu'il porte le
calcul du capital réglementaire pour risque opérationnel (Bâle III /
dispositif UEMOA) : une régression silencieuse fausserait directement les
exigences de fonds propres remontées au régulateur. Les valeurs attendues
sont calculées à la main à partir des formules réglementaires (art. 301,
308, 311, 315-321) et des paramètres par défaut réellement seedés par les
migrations (alpha 15 %, bêtas Bâle II par ligne de métier, seuils BIC en
FCFA, ratio de solvabilité 9 %), pas rétro-ajustées sur la sortie du code.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.fixture
def temp_db(tmp_path, monkeypatch):
    from database.connection import database_manager

    # Contrairement au fixture ICAAP (qui pré-marque les migrations comme
    # appliquées parce que schema.sql définit déjà les tables icaap_*), les
    # tables op_pnb_annuel / op_parametres_aib / op_beta_lignes n'existent
    # QUE via les migrations 025/028 : il faut les laisser réellement
    # s'exécuter sur la base fraîche, donc ne rien pré-insérer dans
    # schema_migrations.
    monkeypatch.setattr(database_manager, "db_path", tmp_path / "test_rwa.db")
    database_manager.initialize()
    yield database_manager


def _saisir_input_bic(annee: int, **postes: float) -> None:
    r = client.put(f"/risque-operationnel/bic/inputs/{annee}", json=postes)
    assert r.status_code == 200, r.text


def test_calcul_bic_crr3_conforme_a_la_formule_reglementaire(temp_db) -> None:
    """BIC = tranches marginales de BI = ILDC + SC + FC (art. 315-321), avec
    plafonnement de l'ILDC à seuil_ildc x AC (2,25 % par défaut) et le
    repli BIA (15 % du PNB moyen) calculé en parallèle pour comparaison."""

    postes = dict(
        interets_percus=100.0,
        interets_verses=30.0,
        dividendes_percus=10.0,
        autres_produits_exploitation=50.0,
        autres_charges_exploitation=20.0,
        commissions_percues=80.0,
        commissions_versees=40.0,
        resultat_portefeuille_negociation=-15.0,
        resultat_portefeuille_bancaire=25.0,
        tresorerie_et_banques_centrales=200.0,
        creances_etablissements_credit=300.0,
        creances_clientele=1000.0,
        provisions=50.0,
    )
    # Mêmes postes sur les 3 exercices N-2, N-1, N : la moyenne vaut alors
    # exactement chaque poste, ce qui simplifie la vérification manuelle.
    for annee in (2023, 2024, 2025):
        _saisir_input_bic(annee, **postes)

    r = client.get("/risque-operationnel/bic/calcul", params={"annee_n": 2025})
    assert r.status_code == 200, r.text
    resultat = r.json()

    # ILDC : IC = intérêts perçus - versés = 70 ; AC = trésorerie + créances
    # étab. crédit + (créances clientèle - provisions) = 200+300+950 = 1450 ;
    # plafond = AC x 2,25 % = 32,625 < |IC| = 70 -> plafond actif, retenu.
    assert resultat["ildc_detail"]["ic"] == pytest.approx(70.0)
    assert resultat["ildc_detail"]["ac"] == pytest.approx(1450.0)
    assert resultat["ildc_detail"]["plafond_ildc"] == pytest.approx(32.625)
    assert resultat["ildc_detail"]["plafond_actif"] is True
    ildc_attendu = 32.625 + 10.0  # plafond + dividendes
    assert resultat["ildc_detail"]["ildc"] == pytest.approx(ildc_attendu)

    # SC = max(OI, OE) + max(FI, FE) = max(50,20) + max(80,40) = 50 + 80 = 130.
    sc_attendu = 130.0
    assert resultat["sc_detail"]["sc"] == pytest.approx(sc_attendu)

    # FC = |résultat négociation| + |résultat bancaire| = 15 + 25 = 40.
    fc_attendu = 40.0
    assert resultat["fc_detail"]["fc"] == pytest.approx(fc_attendu)

    bi_attendu = ildc_attendu + sc_attendu + fc_attendu  # 212,625
    assert resultat["bi_detail"]["bi"] == pytest.approx(bi_attendu)

    # BI très inférieur au premier seuil (655 957 000 000 FCFA) : tranche 1,
    # coefficient 12 % appliqué à la totalité du BI.
    assert resultat["bi_detail"]["tranche_active"] == 1
    bic_attendu = bi_attendu * 0.12
    assert resultat["bi_detail"]["bic"] == pytest.approx(bic_attendu)

    # OFR CRR3 = BIC (ILM = 1 par hypothèse) ; REA = OFR x 12,5.
    assert resultat["ofr_crr3"] == pytest.approx(bic_attendu)
    assert resultat["rea_crr3"] == pytest.approx(bic_attendu * 12.5)

    # PNB effectif (non saisi -> reconstitué) = (100-30)+10+(80-40)+(-15+25)
    # +(50-20) = 160. OFR BIA = 15 % du PNB moyen ; REA BIA = OFR BIA x 12,5.
    pnb_attendu = 160.0
    ofr_bia_attendu = pnb_attendu * 0.15
    assert resultat["ofr_bia"] == pytest.approx(ofr_bia_attendu)
    assert resultat["rea_bia"] == pytest.approx(ofr_bia_attendu * 12.5)
    assert resultat["ecart"] == pytest.approx(bic_attendu - ofr_bia_attendu)
    assert resultat["donnees_insuffisantes"] is False


def test_calcul_bic_plafond_ildc_inactif_quand_ic_sous_le_seuil(temp_db) -> None:
    """Si |IC| <= plafond, l'ILDC retient IC brut (pas le plafond) : la
    branche `plafond_actif = False` doit produire un résultat différent de
    la branche plafonnée testée ci-dessus, pas juste un cas symétrique."""

    postes = dict(
        interets_percus=40.0,
        interets_verses=35.0,  # IC = 5, très inférieur au plafond
        dividendes_percus=0.0,
        tresorerie_et_banques_centrales=200.0,
        creances_etablissements_credit=300.0,
        creances_clientele=1000.0,
        provisions=50.0,
    )
    for annee in (2023, 2024, 2025):
        _saisir_input_bic(annee, **postes)

    r = client.get("/risque-operationnel/bic/calcul", params={"annee_n": 2025})
    assert r.status_code == 200, r.text
    resultat = r.json()

    assert resultat["ildc_detail"]["ic"] == pytest.approx(5.0)
    assert resultat["ildc_detail"]["plafond_actif"] is False
    assert resultat["ildc_detail"]["ildc"] == pytest.approx(5.0)


def test_calcul_aib_moyenne_sur_3_derniers_exercices_positifs(temp_db) -> None:
    """AIB (art. 301) : K_IB = alpha (15 %) x moyenne des PNB positifs des 3
    derniers exercices (un exercice négatif est exclu de la moyenne, pas
    compté comme 0) ; APR = K_IB / ratio de solvabilité (9 %)."""

    for annee, pnb in ((2023, 100.0), (2024, 200.0), (2025, 300.0)):
        r = client.put(
            f"/risque-operationnel/aib/pnb/{annee}",
            json={"produit_brut_total": pnb, "source_document": "test"},
        )
        assert r.status_code == 200, r.text

    r = client.get("/risque-operationnel/aib/calcul")
    assert r.status_code == 200, r.text
    resultat = r.json()

    assert resultat["n"] == 3
    assert resultat["somme_pnb_positifs"] == pytest.approx(600.0)
    assert resultat["pnb_moyen"] == pytest.approx(200.0)
    k_ib_attendu = 200.0 * 0.15
    assert resultat["k_ib"] == pytest.approx(k_ib_attendu)
    apr_attendu = k_ib_attendu / 0.09
    assert resultat["apr_aib"] == pytest.approx(apr_attendu)
    assert resultat["capital_min_aib"] == pytest.approx(k_ib_attendu)


def test_calcul_aib_exclut_les_exercices_a_pnb_negatif_de_la_moyenne(temp_db) -> None:
    """Un PNB négatif ne compte ni dans la somme ni dans le diviseur n (sinon
    une perte réduirait indûment le capital requis)."""

    for annee, pnb in ((2023, 100.0), (2024, -50.0), (2025, 300.0)):
        r = client.put(
            f"/risque-operationnel/aib/pnb/{annee}",
            json={"produit_brut_total": pnb},
        )
        assert r.status_code == 200, r.text

    r = client.get("/risque-operationnel/aib/calcul")
    assert r.status_code == 200, r.text
    resultat = r.json()

    assert resultat["n"] == 2
    assert resultat["somme_pnb_positifs"] == pytest.approx(400.0)
    assert resultat["pnb_moyen"] == pytest.approx(200.0)


def test_calcul_aib_refuse_un_4e_exercice_sans_en_supprimer_un(temp_db) -> None:
    """L'Indicateur de Base porte sur exactement 3 exercices : un 4e ajout
    doit être un 400, jamais une moyenne silencieusement faussée sur 4 ans."""

    for annee in (2023, 2024, 2025):
        r = client.put(
            f"/risque-operationnel/aib/pnb/{annee}",
            json={"produit_brut_total": 100.0},
        )
        assert r.status_code == 200, r.text

    r = client.put(
        "/risque-operationnel/aib/pnb/2026",
        json={"produit_brut_total": 100.0},
    )
    assert r.status_code == 400, r.text


def test_calcul_as_utilise_les_betas_reglementaires_par_ligne(temp_db) -> None:
    """AS (art. 311) : K_AS = somme, sur l'exercice le plus récent renseigné,
    des PNB de ligne x bêta réglementaire de la ligne (planché à 0 au
    total), avec les bêtas Bâle II pré-chargés par la migration 028."""

    lignes = {
        "Financement d'entreprise": (500.0, 0.18),  # bêta 18 %
        "Banque de détail": (1000.0, 0.12),  # bêta 12 %
    }
    for ligne, (pnb, _beta) in lignes.items():
        r = client.put(
            f"/risque-operationnel/as/pnb-lignes/2025/{ligne}",
            json={"produit_brut_ligne": pnb},
        )
        assert r.status_code == 200, r.text

    r = client.get("/risque-operationnel/as/calcul")
    assert r.status_code == 200, r.text
    resultat = r.json()

    k_total_attendu = sum(pnb * beta for pnb, beta in lignes.values())  # 500*0.18+1000*0.12=210
    assert resultat["k_as"] == pytest.approx(k_total_attendu)
    apr_attendu = k_total_attendu / 0.09
    assert resultat["apr_as"] == pytest.approx(apr_attendu)
    assert resultat["capital_min_as"] == pytest.approx(k_total_attendu)
    assert resultat["donnees_insuffisantes"] is False

    detail = resultat["detail_par_annee"][0]
    assert detail["annee"] == 2025
    par_ligne = {l["ligne_metier"]: l for l in detail["lignes"]}
    assert par_ligne["Financement d'entreprise"]["beta"] == pytest.approx(0.18)
    assert par_ligne["Banque de détail"]["beta"] == pytest.approx(0.12)


def test_calcul_as_plancher_a_zero_si_k_total_negatif(temp_db) -> None:
    """Un PNB de ligne négatif peut rendre K_total négatif : le capital
    retenu est alors plafonné à 0, jamais négatif (art. 308)."""

    r = client.put(
        "/risque-operationnel/as/pnb-lignes/2025/Banque de détail",
        json={"produit_brut_ligne": -1000.0},
    )
    assert r.status_code == 200, r.text

    r = client.get("/risque-operationnel/as/calcul")
    assert r.status_code == 200, r.text
    resultat = r.json()

    assert resultat["k_as"] == pytest.approx(0.0)
    detail = resultat["detail_par_annee"][0]
    assert detail["k_total"] == pytest.approx(-1000.0 * 0.12)
    assert detail["k_retenu"] == pytest.approx(0.0)


def test_calcul_aib_et_as_signalent_l_absence_de_donnees(temp_db) -> None:
    """Sans aucune saisie, les deux approches doivent le dire explicitement
    (`donnees_insuffisantes`), jamais renvoyer silencieusement un capital à 0
    comme si le risque opérationnel du portefeuille était nul."""

    r = client.get("/risque-operationnel/aib/calcul")
    assert r.status_code == 200, r.text
    assert r.json()["n"] == 0
    assert r.json()["capital_min_aib"] == pytest.approx(0.0)

    r = client.get("/risque-operationnel/as/calcul")
    assert r.status_code == 200, r.text
    resultat = r.json()
    assert resultat["donnees_insuffisantes"] is True
    assert resultat["k_as"] == pytest.approx(0.0)
