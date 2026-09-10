"""Routes FastAPI du module ICAAP.

Lots L2 à L5 : exercices, cartographie des risques, paramètres, capital
économique et couverture, stress testing, planification du capital, plan
d'action et rapport PDF.
Le routeur ne porte PAS le préfixe « /api » : ``PrefixeApiMiddleware`` le
retire avant le routage (cf. modules VaR / FODEP).
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Response, status

from app.icaap import services
from app.icaap.models import (
    CapitalDispoUpdate,
    CapitalDispoView,
    CapitalEcoLigne,
    CapitalEcoRun,
    CartographieSave,
    CorrelationEntry,
    CorrelationsSave,
    CouvertureView,
    ExerciceCreate,
    ExerciceUpdate,
    ExerciceView,
    ParametreView,
    PlanActionEntry,
    PlanActionSave,
    PlanCapitalHypotheses,
    PlanCapitalView,
    RisqueView,
    ScenarioEntry,
    ScenarioView,
)

router = APIRouter(prefix="/icaap", tags=["ICAAP"])


def _404(exc: services.IcaapIntrouvable) -> HTTPException:
    return HTTPException(
        status.HTTP_404_NOT_FOUND,
        detail={"code": "ICAAP_EXERCICE_INTROUVABLE", "message": str(exc)},
    )


def _409(exc: services.IcaapExerciceVerrouille) -> HTTPException:
    return HTTPException(
        status.HTTP_409_CONFLICT,
        detail={
            "code": "ICAAP_EXERCICE_VERROUILLE",
            "message": (
                "Cet exercice n'est plus au statut « brouillon » : il est "
                "immuable. Créez un nouvel exercice pour corriger."
            ),
        },
    )


def _422(exc: services.IcaapDonneesManquantes) -> HTTPException:
    return HTTPException(
        status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={"code": "ICAAP_DONNEES_MANQUANTES", "message": str(exc)},
    )


def _404_scenario(exc: services.IcaapScenarioIntrouvable) -> HTTPException:
    return HTTPException(
        status.HTTP_404_NOT_FOUND,
        detail={"code": "ICAAP_SCENARIO_INTROUVABLE", "message": str(exc)},
    )


@router.get("/parametres", response_model=list[ParametreView])
def lister_parametres() -> list[ParametreView]:
    """Seuils prudentiels en vigueur (ratio de solvabilité, coussin, add-ons,
    seuil de matérialité…), un enregistrement par clé."""

    return services.lister_parametres()


@router.get("/exercices", response_model=list[ExerciceView])
def lister_exercices(
    annee: int | None = None, statut: str | None = None
) -> list[ExerciceView]:
    return services.lister_exercices(annee=annee, statut=statut)


@router.post(
    "/exercices",
    response_model=ExerciceView,
    status_code=status.HTTP_201_CREATED,
)
def creer_exercice(payload: ExerciceCreate) -> ExerciceView:
    """Ouvre un exercice ICAAP pour une année. La matrice de corrélation par
    défaut est recopiée dans l'exercice, où elle devient éditable."""

    try:
        return services.creer_exercice(payload)
    except Exception as exc:  # noqa: BLE001
        message = str(exc).lower()
        if "unique" in message and "annee" in message:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                detail={
                    "code": "ICAAP_ANNEE_DEJA_OUVERTE",
                    "message": (
                        "Un exercice non archivé existe déjà pour cette année. "
                        "Archivez-le avant d'en ouvrir un nouveau."
                    ),
                },
            ) from exc
        raise


@router.get("/exercices/{exercice_id}", response_model=ExerciceView)
def obtenir_exercice(exercice_id: str) -> ExerciceView:
    try:
        return services.obtenir_exercice(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc


@router.put("/exercices/{exercice_id}", response_model=ExerciceView)
def mettre_a_jour_exercice(
    exercice_id: str, payload: ExerciceUpdate
) -> ExerciceView:
    """Met à jour l'en-tête (date d'arrêté, opinions, commentaire). Refusé si
    l'exercice n'est plus au statut « brouillon »."""

    try:
        return services.mettre_a_jour_exercice(exercice_id, payload)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc


@router.get(
    "/exercices/{exercice_id}/risques", response_model=list[RisqueView]
)
def lister_cartographie(exercice_id: str) -> list[RisqueView]:
    try:
        return services.lister_cartographie(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc


@router.post(
    "/exercices/{exercice_id}/risques", response_model=list[RisqueView]
)
def enregistrer_cartographie(
    exercice_id: str, payload: CartographieSave
) -> list[RisqueView]:
    """Remplace intégralement la cartographie des risques de l'exercice. La
    matérialité (probabilité x impact) et la bascule quanti/quali sont
    recalculées serveur."""

    try:
        return services.enregistrer_cartographie(exercice_id, payload.lignes)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc


# ── Capital interne disponible ─────────────────────────────────────────────
@router.get(
    "/exercices/{exercice_id}/capital-dispo",
    response_model=CapitalDispoView | None,
)
def obtenir_capital_dispo(exercice_id: str) -> CapitalDispoView | None:
    try:
        return services.obtenir_capital_dispo(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc


@router.put(
    "/exercices/{exercice_id}/capital-dispo", response_model=CapitalDispoView
)
def enregistrer_capital_dispo(
    exercice_id: str, payload: CapitalDispoUpdate
) -> CapitalDispoView:
    """Fige la photo du capital interne disponible (CET1/AT1/T2 - déductions)
    à la date d'arrêté de l'exercice."""

    try:
        return services.enregistrer_capital_dispo(exercice_id, payload)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc


# ── Matrice de corrélation ────────────────────────────────────────────────
@router.get(
    "/exercices/{exercice_id}/correlations",
    response_model=list[CorrelationEntry],
)
def lister_correlations(exercice_id: str) -> list[CorrelationEntry]:
    try:
        return services.lister_correlations(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc


@router.put(
    "/exercices/{exercice_id}/correlations",
    response_model=list[CorrelationEntry],
)
def enregistrer_correlations(
    exercice_id: str, payload: CorrelationsSave
) -> list[CorrelationEntry]:
    """Remplace la matrice de corrélation de l'exercice (moitié supérieure ;
    diagonale = 1 implicite)."""

    try:
        return services.enregistrer_correlations(exercice_id, payload.lignes)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc


# ── Moteur de capital économique ──────────────────────────────────────────
@router.post(
    "/exercices/{exercice_id}/capital-economique",
    response_model=list[CapitalEcoLigne],
)
def calculer_capital_economique(
    exercice_id: str, payload: CapitalEcoRun
) -> list[CapitalEcoLigne]:
    """Calcule le besoin en capital économique pour chaque risque de la
    cartographie et le persiste. Rejoue intégralement à chaque appel."""

    try:
        return services.calculer_capital_economique(exercice_id, payload)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc
    except services.IcaapDonneesManquantes as exc:
        raise _422(exc) from exc


@router.get(
    "/exercices/{exercice_id}/couverture", response_model=CouvertureView
)
def obtenir_couverture(exercice_id: str) -> CouvertureView:
    """Ratio de couverture ICAAP = capital interne disponible / besoin global
    après diversification. Renvoie aussi la somme simple et le bénéfice de
    diversification."""

    try:
        return services.obtenir_couverture(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapDonneesManquantes as exc:
        raise _422(exc) from exc


# ── Stress testing ────────────────────────────────────────────────────────
@router.get(
    "/exercices/{exercice_id}/scenarios", response_model=list[ScenarioView]
)
def lister_scenarios(exercice_id: str) -> list[ScenarioView]:
    try:
        return services.lister_scenarios(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc


@router.post(
    "/exercices/{exercice_id}/scenarios",
    response_model=ScenarioView,
    status_code=status.HTTP_201_CREATED,
)
def creer_scenario(exercice_id: str, payload: ScenarioEntry) -> ScenarioView:
    """Enregistre un scénario de stress (chocs en hypothèses). Le calcul se
    lance ensuite par POST .../scenarios/{id}/run."""

    try:
        return services.creer_scenario(exercice_id, payload)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc


@router.get("/scenarios/{scenario_id}", response_model=ScenarioView)
def obtenir_scenario(scenario_id: str) -> ScenarioView:
    try:
        return services.obtenir_scenario(scenario_id)
    except services.IcaapScenarioIntrouvable as exc:
        raise _404_scenario(exc) from exc


@router.delete("/scenarios/{scenario_id}")
def supprimer_scenario(scenario_id: str) -> Response:
    try:
        services.supprimer_scenario(scenario_id)
    except services.IcaapScenarioIntrouvable as exc:
        raise _404_scenario(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/scenarios/{scenario_id}/run", response_model=ScenarioView)
def executer_scenario(scenario_id: str) -> ScenarioView:
    """Exécute le scénario : projette RWA, résultat, fonds propres et ratio de
    solvabilité post-choc pour chaque année de l'horizon. Rejoue à chaque
    appel."""

    try:
        return services.executer_scenario(scenario_id)
    except services.IcaapScenarioIntrouvable as exc:
        raise _404_scenario(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc
    except services.IcaapDonneesManquantes as exc:
        raise _422(exc) from exc


# ── Planification du capital ──────────────────────────────────────────────
@router.get(
    "/exercices/{exercice_id}/plan-capital",
    response_model=PlanCapitalView | None,
)
def obtenir_plan_capital(exercice_id: str) -> PlanCapitalView | None:
    try:
        return services.obtenir_plan_capital(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc


@router.post(
    "/exercices/{exercice_id}/plan-capital", response_model=PlanCapitalView
)
def calculer_plan_capital(
    exercice_id: str, payload: PlanCapitalHypotheses
) -> PlanCapitalView:
    """Projette le capital sur l'horizon prudentiel (paramètre
    horizon_plan_capital_annees) et signale l'année où le ratio passerait sous
    minimum + coussin de conservation."""

    try:
        return services.calculer_plan_capital(exercice_id, payload)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc
    except services.IcaapDonneesManquantes as exc:
        raise _422(exc) from exc


# ── Plan d'action ─────────────────────────────────────────────────────────
@router.get(
    "/exercices/{exercice_id}/plan-action",
    response_model=list[PlanActionEntry],
)
def lister_plan_action(exercice_id: str) -> list[PlanActionEntry]:
    try:
        return services.lister_plan_action(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc


@router.put(
    "/exercices/{exercice_id}/plan-action",
    response_model=list[PlanActionEntry],
)
def enregistrer_plan_action(
    exercice_id: str, payload: PlanActionSave
) -> list[PlanActionEntry]:
    """Remplace intégralement le plan d'action de l'exercice."""

    try:
        return services.enregistrer_plan_action(exercice_id, payload.lignes)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except services.IcaapExerciceVerrouille as exc:
        raise _409(exc) from exc


# ── Rapport PDF ───────────────────────────────────────────────────────────
@router.get("/exercices/{exercice_id}/rapport.pdf")
def rapport_pdf(exercice_id: str) -> Response:
    """Rapport ICAAP complet en PDF (page de garde, synthèse, cartographie,
    capital économique, stress tests, planification du capital, plan d'action,
    opinions)."""

    from app.icaap import pdf

    try:
        exercice = services.obtenir_exercice(exercice_id)
        contenu = pdf.construire_rapport_pdf(exercice_id)
    except services.IcaapIntrouvable as exc:
        raise _404(exc) from exc
    except Exception as exc:  # noqa: BLE001 - remonte une erreur lisible
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": "ICAAP_RAPPORT_PDF_ERREUR",
                "message": f"Génération du PDF impossible : {exc}",
            },
        ) from exc

    nom = f"Rapport_ICAAP_{exercice.annee}_{exercice.statut}.pdf"
    return Response(
        content=contenu,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{nom}"'},
    )
