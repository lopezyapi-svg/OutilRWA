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
    seuils: dict[str, float] | None = None,
) -> dict:
    """Ratios CET1 / T1 / solvabilité totale / levier, sur les seuils en
    vigueur à la date d'arrêté (table ``fodep_seuil_prudentiel``).
    """

    fonds_propres = {
        "cet1": totaux["fpi22"],
        "t1": totaux["fpi29"],
        "total_capital": totaux["fpi41"],
    }
    return evaluate_ratios(apr_total, fonds_propres, total_expositions, seuils)


# ── Limites sur opérations (EP35-EP38 → RA006-RA011) ────────────────────────
# Normes-plafond : contrairement aux ratios de solvabilité (un minimum à
# atteindre), ce sont des maximums à ne pas dépasser. La polarité du statut
# est donc inversée par rapport à ``bceao_calculations._evaluate`` — voir
# ``_evaluer_plafond`` ci-dessous.

PR001_CATEGORIES: tuple[str, ...] = ("a", "b", "c", "d", "e", "f", "g", "h")


def _evaluer_plafond(valeur_pct: float, seuil_pct: float) -> dict:
    diff = valeur_pct - seuil_pct
    statut = "Déficit" if valeur_pct > seuil_pct else "Excédent"
    return {
        "value": round(valeur_pct, 3),
        "threshold": round(seuil_pct, 3),
        "diff_points": round(diff, 3),
        "status": statut,
    }


def calculer_produit_brut(postes: dict[str, float]) -> dict[str, float]:
    """RO009 — total du produit brut de l'EP21.

    Somme algébrique : les postes précédés de (-) dans la notice (RO003,
    RO005, RO007, RO008) sont saisis négatifs, conformément à la convention
    de signe générale.
    """

    ro009 = _s(postes, "ro001", "ro002", "ro003", "ro005", "ro006", "ro007", "ro008")
    return {"ro009": round(ro009, 2)}


def calculer_exposition_levier(postes: dict[str, float]) -> dict[str, float]:
    """Totaux de l'EP33 : RL004, RL007, RL010, RL013 et RL015.

    Les opérations assimilables à des pensions sont d'abord retirées du
    bilan (RL003, négatif) avant d'être réintégrées avec leur traitement
    propre en RL008/RL009 — un double comptage à cet endroit fausserait le
    ratio (notice, EP33).
    """

    rl004 = _s(postes, "rl001", "rl002", "rl003")
    rl007 = _s(postes, "rl005", "rl006")
    rl010 = _s(postes, "rl008", "rl009")
    rl013 = _s(postes, "rl011", "rl012")
    rl015 = rl004 + rl007 + rl010 + rl013
    return {
        "rl004": round(rl004, 2),
        "rl007": round(rl007, 2),
        "rl010": round(rl010, 2),
        "rl013": round(rl013, 2),
        "rl015": round(rl015, 2),
    }


def calculer_limites_operations(
    postes: dict[str, float],
    participations: list[dict[str, float]],
    t1: float,
    fpe: float,
    seuils: dict[str, float],
) -> tuple[dict[str, dict], dict[str, float]]:
    """Normes RA006 à RA011 (limites EP35-EP38) + excédents dérivés pour le
    CET1 (PA149, IM006, IM010, PR004).

    ``participations`` : lignes du registre EP35 (section « entités
    commerciales » de l'EP34), chacune ``{"capital_emettrice", "montant_net"}``.
    ``postes`` : dict complet des codes DISPRU déjà saisis (im001, im002,
    im003, im007, pa084, pa106, pr001a..h, pr002a..h).

    Le deuxième élément du tuple ne contient que les excédents strictement
    positifs qui *devraient* remplacer la saisie manuelle — c'est à
    l'appelant (``services.generer_apercu``) de décider s'il y a assez de
    données de registre pour justifier l'override (voir le repli documenté
    dans la migration 036).
    """

    total_participations = sum(float(p.get("montant_net", 0.0) or 0.0) for p in participations)

    ra006 = max(
        (
            float(p.get("montant_net", 0.0) or 0.0) / float(p["capital_emettrice"]) * 100
            for p in participations
            if float(p.get("capital_emettrice", 0.0) or 0.0) > 0
        ),
        default=0.0,
    )
    ra007 = (
        max((float(p.get("montant_net", 0.0) or 0.0) for p in participations), default=0.0) / t1 * 100
        if t1 > 0
        else 0.0
    )
    ra008 = total_participations / fpe * 100 if fpe > 0 else 0.0
    # Les excédents déduits du CET1 s'appuient sur les mêmes seuils que les
    # normes correspondantes : un seul paramètre daté par limite, jamais une
    # constante dupliquée entre le test de conformité et sa déduction.
    pa149 = max(0.0, total_participations - seuils["ra007"] / 100 * t1)

    # IM004 (immobilisations hors exploitation seules) sert de brique à IM005
    # (RA009, avec PA084) ET à IM008 (RA010, sans PA084 mais avec IM007) —
    # les deux totaux de l'EP37/EP38 ne se chevauchent pas malgré le nom
    # proche, voir la note de la migration 036.
    im004 = _s(postes, "im001", "im002", "im003")
    im005 = im004 + float(postes.get("pa084", 0.0) or 0.0)
    ra009 = im005 / t1 * 100 if t1 > 0 else 0.0
    im006 = max(0.0, im005 - seuils["ra009"] / 100 * t1)

    im008 = im004 + float(postes.get("im007", 0.0) or 0.0)
    im009 = im008 + float(postes.get("pa106", 0.0) or 0.0)
    ra010 = im009 / fpe * 100 if fpe > 0 else 0.0
    im010 = max(0.0, im009 - seuils["ra010"] / 100 * fpe)

    total_prets_lies = _s(
        postes,
        *(f"pr001{cat}" for cat in PR001_CATEGORIES),
        *(f"pr002{cat}" for cat in PR001_CATEGORIES),
    )
    ra011 = total_prets_lies / fpe * 100 if fpe > 0 else 0.0
    pr004 = max(0.0, total_prets_lies - seuils["ra011"] / 100 * fpe)

    ratios = {
        code: _evaluer_plafond(valeur, seuils[code])
        for code, valeur in (
            ("ra006", ra006),
            ("ra007", ra007),
            ("ra008", ra008),
            ("ra009", ra009),
            ("ra010", ra010),
            ("ra011", ra011),
        )
    }
    excedents = {
        "pa149": -round(pa149, 2),
        "im006": -round(im006, 2),
        "im010": -round(im010, 2),
        "pr004": -round(pr004, 2),
    }
    return ratios, excedents
