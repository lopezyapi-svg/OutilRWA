"""Fonctions de calcul partagees par les modules metier."""

from __future__ import annotations

from collections.abc import Iterable, Mapping

from app.core.config import settings


_CURRENCY_RATES_IN_XAF = {
    "XAF": 1.0,
    "XOF": 1.0,
    "EUR": 655.957,
    "USD": 600.0,
}


def bucketize_rating(rating: str) -> str:
    """Mappe une notation vers un bucket prudentiel simple.

    Entree:
        rating: notation libre recue dans les donnees.
    Sortie:
        Le bucket de notation exploitable par les referentiels.
    """

    # La notation libre est normalisee avant d'etre comparee aux buckets internes.
    normalized = rating.strip().upper()
    if normalized in {"AAA", "AA+", "AA", "AA-"}:
        return "AAA/AA"
    if normalized in {"A+", "A", "A-"}:
        return "A"
    if normalized in {"BBB+", "BBB", "BBB-"}:
        return "BBB"
    if normalized in {"BB+", "BB", "BB-", "B+", "B", "B-"}:
        return "BB/B"
    return "Non noté"


def calculate_ead(nominal_amount: float, ccf: float = 1.0) -> float:
    """Calcule l'exposition au defaut a partir du nominal.

    Entrees:
        nominal_amount: montant brut ou nominal.
        ccf: facteur de conversion du credit.
    Sortie:
        Le montant EAD.
    """

    return round(nominal_amount * ccf, 2)


def apply_crm_substitution(
    original_risk_weight: float,
    guarantor_risk_weight: float,
    coverage_ratio: float,
) -> float:
    """Applique une substitution simple de ponderation liee a la CRM.

    Entrees:
        original_risk_weight: ponderation avant garantie.
        guarantor_risk_weight: ponderation du garant.
        coverage_ratio: part de l'exposition couverte entre 0 et 1.
    Sortie:
        La ponderation finale apres CRM.
    """

    # La couverture est bornee pour rester entre absence totale et couverture complete.
    bounded_ratio = max(0.0, min(coverage_ratio, 1.0))
    # La part couverte prend le RW du garant, la part non couverte garde celui de l'emprunteur.
    covered_part = bounded_ratio * guarantor_risk_weight
    uncovered_part = (1 - bounded_ratio) * original_risk_weight
    return round(covered_part + uncovered_part, 4)


def calculate_rwa(ead: float, risk_weight: float) -> float:
    """Calcule le RWA a partir de l'EAD et de la ponderation.

    Entrees:
        ead: exposition au defaut.
        risk_weight: ponderation prudentielle.
    Sortie:
        Le RWA.
    """

    return round(ead * risk_weight, 2)


def calculate_capital(rwa: float, capital_ratio: float = settings.capital_ratio) -> float:
    """Calcule le capital reglementaire minimum.

    Entrees:
        rwa: actifs ponderes par les risques.
        capital_ratio: ratio reglementaire cible.
    Sortie:
        Le capital minimum.
    """

    return round(rwa * capital_ratio, 2)


def convert_currency_amount(
    amount: float,
    *,
    from_currency: str,
    to_currency: str = "XOF",
) -> float:
    """Convertit un montant entre devises avec le barème partagé frontend/backend."""

    normalized_from = (from_currency or "XOF").upper()
    normalized_to = (to_currency or "XOF").upper()
    from_rate = _CURRENCY_RATES_IN_XAF.get(normalized_from, 1.0)
    to_rate = _CURRENCY_RATES_IN_XAF.get(normalized_to, 1.0)
    return (amount * from_rate) / to_rate


def safe_ratio(numerator: float, denominator: float) -> float:
    """Retourne un ratio simple en evitant une division par zero.

    Entrees:
        numerator: valeur au numerateur.
        denominator: valeur au denominateur.
    Sortie:
        Le ratio calcule ou 0 si le denominateur est nul.
    """

    if denominator == 0:
        return 0.0
    # Certaines categories peuvent representer une part tres faible du total.
    # On garde plus de precision pour eviter de les ecraser a zero dans les graphiques.
    return round(numerator / denominator, 8)


def aggregate_portfolio(items: Iterable[Mapping[str, float]]) -> dict[str, float]:
    """Agrege un portefeuille de lignes de calcul.

    Entree:
        items: lignes contenant au moins gross_amount, ead, rwa et capital.
    Sortie:
        Un dictionnaire de totaux de portefeuille.
    """

    total_gross = 0.0
    total_ead = 0.0
    total_rwa = 0.0
    total_capital = 0.0

    for item in items:
        # Chaque ligne contribue aux quatre agregats standards du portefeuille.
        total_gross += float(item.get("gross_amount", 0.0))
        total_ead += float(item.get("ead", 0.0))
        total_rwa += float(item.get("rwa", 0.0))
        total_capital += float(item.get("capital", 0.0))

    return {
        "gross_amount": round(total_gross, 2),
        "ead": round(total_ead, 2),
        "rwa": round(total_rwa, 2),
        "capital": round(total_capital, 2),
    }
