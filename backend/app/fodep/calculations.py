"""Calculs Fonds Propres détaillés (FPI01→FPI42) et ratios de solvabilité.

Portage de HEYFODEP (`packages/kernel/src/sections/solvabilite.ts` et le
graphe de dépendances `codes.fonds-propres.ts`), traduit en sommes directes
plutôt qu'un moteur générique à graphe : plus simple à auditer pour 45 postes
fixes, sans perte de fidélité vis-à-vis de la notice technique BCEAO.

Les ratios eux-mêmes ne sont PAS recalculés ici : ils réutilisent
``app.core.bceao_calculations.evaluate_ratios``, déjà utilisé par le tableau
de bord RisqueManagement, pour qu'un seul endroit du code porte la formule.
"""

from __future__ import annotations

from app.core.bceao_calculations import evaluate_ratios


def _s(data: dict[str, float], *codes: str) -> float:
    return sum(float(data.get(code, 0.0) or 0.0) for code in codes)


def calculer_fonds_propres_detailles(data: dict[str, float]) -> dict[str, float]:
    """Calcule tous les totaux (FPI08…FPI41) à partir des postes saisis.

    ``data`` : dict indexé par code en minuscules (ex. ``"fpi01"``), tel que
    stocké en base. Les déductions doivent déjà être en valeurs <= 0 côté
    saisie (convention de la notice, §3.3) : les totaux sont ici de simples
    sommes, jamais des soustractions.
    """

    fpi08 = _s(data, "fpi01", "fpi02", "fpi03", "fpi04", "fpi05", "fpi06", "fpi07")
    fpi14 = fpi08 + _s(
        data,
        "fpi09", "fpi10", "im012", "id009", "pa156", "pa173",
        "fpi11", "pa149", "im006", "im010", "pr004", "fpi12", "fpi13",
    )
    fpi15 = fpi14 + _s(data, "pa163")
    fpi16 = fpi15 + _s(data, "pa172", "id011")
    fpi22 = fpi16 + _s(data, "fpi20", "fpi21")

    fpi26 = _s(data, "fpi23", "fpi24", "fpi25")
    fpi28 = fpi26 + _s(data, "pa157", "pa164", "pa174", "fpi27")

    fpi29 = fpi22 + fpi28

    fpi39 = _s(
        data,
        "fpi30", "fpi31", "fpi32", "fpi33", "fpi34",
        "fpi35", "fpi36", "fpi37", "fpi38",
    )
    fpi40 = fpi39 + _s(data, "pa158", "pa165", "pa175")

    fpi41 = fpi29 + fpi40

    return {
        "fpi08": round(fpi08, 2),
        "fpi14": round(fpi14, 2),
        "fpi15": round(fpi15, 2),
        "fpi16": round(fpi16, 2),
        "fpi22": round(fpi22, 2),
        "fpi26": round(fpi26, 2),
        "fpi28": round(fpi28, 2),
        "fpi29": round(fpi29, 2),
        "fpi39": round(fpi39, 2),
        "fpi40": round(fpi40, 2),
        "fpi41": round(fpi41, 2),
    }


def calculer_ratios_solvabilite(
    totaux: dict[str, float],
    apr_total: float,
    total_expositions: float,
) -> dict:
    """Ratios CET1 / T1 / solvabilité totale / levier, sur les seuils UMOA
    déjà en vigueur dans RisqueManagement (voir dispru.SOLVABILITE_SEUILS).
    """

    fonds_propres = {
        "cet1": totaux["fpi22"],
        "t1": totaux["fpi29"],
        "total_capital": totaux["fpi41"],
    }
    return evaluate_ratios(apr_total, fonds_propres, total_expositions)
