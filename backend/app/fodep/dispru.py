"""Registre des codes DISPRU (Fonds Propres, Solvabilité) du FODEP BCEAO.

Portage fidèle de HEYFODEP (`packages/kernel/src/dispru/codes.fonds-propres.ts`
et `codes.solvabilite.ts`), source de vérité pour les libellés, groupes et
références réglementaires de la notice technique FODEP (BCEAO).

Convention de signe (notice technique, §3.3) : un poste marqué
``sign="deduction"`` doit toujours être saisi en valeur négative ou nulle ;
les totaux sont des sommes pures de leurs composantes (voir
``calculations.py``).
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class CodeDispru:
    code: str
    ep: str
    label: str
    groupe: str  # "CET1" | "AT1" | "T2" | "effectifs"
    sign: str = "positif"  # "positif" | "deduction"
    paragraphes: tuple[str, ...] = field(default_factory=tuple)


# ── A. Fonds propres de base durs (CET1) ────────────────────────────────────
_CET1_POSITIFS: tuple[CodeDispru, ...] = (
    CodeDispru("FPI01", "EP03", "Capital social libéré", "CET1", paragraphes=("15", "25")),
    CodeDispru("FPI02", "EP03", "Primes liées à l'émission des instruments CET1", "CET1", paragraphes=("15",)),
    CodeDispru("FPI03", "EP03", "Réserve spéciale", "CET1", paragraphes=("15",)),
    CodeDispru("FPI04", "EP03", "Autres réserves", "CET1", paragraphes=("15",)),
    CodeDispru("FPI05", "EP03", "Report à nouveau créditeur", "CET1", paragraphes=("15",)),
    CodeDispru("FPI06", "EP03", "Résultat bénéficiaire", "CET1", paragraphes=("16-24",)),
    CodeDispru("FPI07", "EP03", "Éléments de CET1 non admissibles au 1er janvier 2018 (dispositions transitoires)", "CET1", paragraphes=("497-498",)),
)

_CET1_DEDUCTIONS: tuple[CodeDispru, ...] = (
    CodeDispru("FPI09", "EP03", "Report à nouveau débiteur", "CET1", "deduction", ("28",)),
    CodeDispru("FPI10", "EP03", "Résultat déficitaire", "CET1", "deduction", ("28",)),
    CodeDispru("IM012", "EP03", "Immobilisations incorporelles (nettes d'impôts différés passif)", "CET1", "deduction", ("28",)),
    CodeDispru("ID009", "EP03", "Impôt différé actif dépendant de la rentabilité future (net d'IDP)", "CET1", "deduction", ("28",)),
    CodeDispru("PA156", "EP03", "Participations croisées éligibles au CET1", "CET1", "deduction", ("28",)),
    CodeDispru("PA173", "EP03", "Participations significatives éligibles au CET1 (hors actions ordinaires)", "CET1", "deduction", ("28",)),
    CodeDispru("FPI11", "EP03", "Réserves de valorisation pour positions moins liquides", "CET1", "deduction", ("28", "345-347")),
    CodeDispru("PA149", "EP03", "Excédent de la limite de participations dans des entités commerciales", "CET1", "deduction", ("28",)),
    CodeDispru("IM006", "EP03", "Excédent de la limite applicable aux immobilisations hors exploitation", "CET1", "deduction", ("28",)),
    CodeDispru("IM010", "EP03", "Excédent de la limite applicable au total des immobilisations et participations", "CET1", "deduction", ("28",)),
    CodeDispru("PR004", "EP03", "Excédent de la limite applicable aux prêts aux actionnaires, dirigeants et personnel", "CET1", "deduction", ("28",)),
    CodeDispru("FPI12", "EP03", "Expositions sur les établissements disposant de fonds propres négatifs", "CET1", "deduction", ("28",)),
    CodeDispru("FPI13", "EP03", "Ajustements réglementaires CET1 (insuffisance AT1 pour couvrir les déductions)", "CET1", "deduction", ("28",)),
    CodeDispru("PA163", "EP03", "Participations non significatives éligibles au CET1 (au-delà de 10 %)", "CET1", "deduction", ("28",)),
    CodeDispru("PA172", "EP03", "Participations significatives éligibles au CET1 (au-delà de 10 %)", "CET1", "deduction", ("28-33",)),
    CodeDispru("ID011", "EP03", "Impôts différés actifs sur différences temporaires (au-delà de 10 %)", "CET1", "deduction", ("28-33",)),
    CodeDispru("FPI20", "EP03", "Montant dépassant le seuil de 15 % du CET1", "CET1", "deduction", ("28-33",)),
    CodeDispru("FPI21", "EP03", "Autres déductions applicables au CET1", "CET1", "deduction"),
)

# ── B. Fonds propres de base additionnels (AT1) ─────────────────────────────
_AT1: tuple[CodeDispru, ...] = (
    CodeDispru("FPI23", "EP03", "Instruments de capital libérés (AT1)", "AT1", paragraphes=("34-35", "47")),
    CodeDispru("FPI24", "EP03", "Primes liées à l'émission des instruments AT1", "AT1", paragraphes=("34",)),
    CodeDispru("FPI25", "EP03", "Instruments de CET1 non admissibles au 1er janvier 2018 éligibles AT1 (transitoire)", "AT1", paragraphes=("27", "497-498")),
    CodeDispru("PA157", "EP03", "Participations croisées éligibles à l'AT1", "AT1", "deduction", ("38",)),
    CodeDispru("PA164", "EP03", "Participations non significatives éligibles à l'AT1 (au-delà de 10 %)", "AT1", "deduction", ("38",)),
    CodeDispru("PA174", "EP03", "Participations significatives éligibles à l'AT1", "AT1", "deduction", ("38",)),
    CodeDispru("FPI27", "EP03", "Ajustements réglementaires AT1 (insuffisance T2 pour couvrir les déductions)", "AT1", "deduction", ("38",)),
)

# ── D. Fonds propres complémentaires (T2) ───────────────────────────────────
_T2: tuple[CodeDispru, ...] = (
    CodeDispru("FPI30", "EP03", "Emprunts subordonnés", "T2", paragraphes=("39-41",)),
    CodeDispru("FPI31", "EP03", "Autres instruments de capital libérés (T2)", "T2", paragraphes=("39-41",)),
    CodeDispru("FPI32", "EP03", "Primes liées à l'émission des instruments T2", "T2", paragraphes=("39",)),
    CodeDispru("FPI33", "EP03", "Autres éléments de CET1 non admissibles au 1er janvier 2018 inclus en T2 (transitoire)", "T2", paragraphes=("27", "497-501")),
    CodeDispru("FPI34", "EP03", "Éléments de T2 non admissibles au 1er janvier 2018 inclus dans les fonds propres (transitoire)", "T2", paragraphes=("43", "497-501")),
    CodeDispru("FPI35", "EP03", "Provisions réglementées", "T2", paragraphes=("39-40",)),
    CodeDispru("FPI36", "EP03", "Fonds affectés", "T2", paragraphes=("39-41",)),
    CodeDispru("FPI37", "EP03", "Subventions d'investissement", "T2", paragraphes=("39-41",)),
    CodeDispru("FPI38", "EP03", "Comptes bloqués d'actionnaires ou d'associés", "T2", paragraphes=("39-41",)),
    CodeDispru("PA158", "EP03", "Participations croisées éligibles au T2", "T2", "deduction", ("44",)),
    CodeDispru("PA165", "EP03", "Participations non significatives éligibles au T2 (au-delà de 10 %)", "T2", "deduction", ("44",)),
    CodeDispru("PA175", "EP03", "Participations significatives éligibles au T2", "T2", "deduction", ("44",)),
)

# ── Fonds propres nets (grands risques) ─────────────────────────────────────
_EFFECTIFS: tuple[CodeDispru, ...] = (
    CodeDispru("FPI42", "EP03", "Fonds Propres Nets (pour calcul des grands risques)", "effectifs", paragraphes=("346",)),
)

# ── Limites sur opérations (EP36, EP37, EP38) ───────────────────────────────
# Groupe distinct de CET1/AT1/T2/effectifs : ces postes n'entrent dans aucun
# total de fonds propres, ils alimentent uniquement les normes RA009-RA011
# (voir calculations.py::calculer_limites_operations). Valeur nette
# uniquement — voir la note de la migration 036.
_LIMITES_OPERATIONS: tuple[CodeDispru, ...] = (
    CodeDispru("IM001", "EP36", "Immobilisations hors exploitation avant ajustement", "LIMITES"),
    CodeDispru("IM002", "EP36", "Immobilisations acquises par réalisation de garantie depuis moins de 2 ans", "LIMITES", "deduction"),
    CodeDispru("IM003", "EP36", "Immobilisations acquises par réalisation de garantie depuis plus de 2 ans, avec dérogation de la Commission Bancaire", "LIMITES", "deduction"),
    CodeDispru("PA084", "EP36", "Participations dans les sociétés immobilières", "LIMITES"),
    CodeDispru("IM007", "EP37", "Immobilisations d'exploitation ajustées", "LIMITES"),
    CodeDispru("PA106", "EP37", "Total des participations (toutes sections de l'EP34)", "LIMITES"),
    CodeDispru("PR001A", "EP38", "Montant des concours — actionnaires détenant individuellement au moins 10 % des droits de vote", "LIMITES"),
    CodeDispru("PR001B", "EP38", "Montant des concours — membres de l'organe délibérant", "LIMITES"),
    CodeDispru("PR001C", "EP38", "Montant des concours — membres de l'organe exécutif", "LIMITES"),
    CodeDispru("PR001D", "EP38", "Montant des concours — commissaires aux comptes", "LIMITES"),
    CodeDispru("PR001E", "EP38", "Montant des concours — personnel de direction", "LIMITES"),
    CodeDispru("PR001F", "EP38", "Montant des concours — cadres moyens et supérieurs", "LIMITES"),
    CodeDispru("PR001G", "EP38", "Montant des concours — personnel d'exécution", "LIMITES"),
    CodeDispru("PR001H", "EP38", "Montant des concours — autres parties liées", "LIMITES"),
    CodeDispru("PR002A", "EP38", "Engagements par signature — actionnaires détenant individuellement au moins 10 % des droits de vote", "LIMITES"),
    CodeDispru("PR002B", "EP38", "Engagements par signature — membres de l'organe délibérant", "LIMITES"),
    CodeDispru("PR002C", "EP38", "Engagements par signature — membres de l'organe exécutif", "LIMITES"),
    CodeDispru("PR002D", "EP38", "Engagements par signature — commissaires aux comptes", "LIMITES"),
    CodeDispru("PR002E", "EP38", "Engagements par signature — personnel de direction", "LIMITES"),
    CodeDispru("PR002F", "EP38", "Engagements par signature — cadres moyens et supérieurs", "LIMITES"),
    CodeDispru("PR002G", "EP38", "Engagements par signature — personnel d'exécution", "LIMITES"),
    CodeDispru("PR002H", "EP38", "Engagements par signature — autres parties liées", "LIMITES"),
)

# ── EP21 — Calcul du produit brut (approche indicateur de base) ─────────────
# La notice ne numérote pas de RO004 ; RO009 (total) est calculé, jamais saisi.
_PRODUIT_BRUT: tuple[CodeDispru, ...] = (
    CodeDispru("RO001", "EP21", "Produit d'exploitation bancaire", "PRODUIT_BRUT", paragraphes=("301-302",)),
    CodeDispru("RO002", "EP21", "Moins-values réalisées sur cessions de titres du portefeuille bancaire", "PRODUIT_BRUT", paragraphes=("301-302",)),
    CodeDispru("RO003", "EP21", "Charges d'exploitation bancaire", "PRODUIT_BRUT", "deduction", ("301-302",)),
    CodeDispru("RO005", "EP21", "Plus-values réalisées sur cessions de titres du portefeuille bancaire", "PRODUIT_BRUT", "deduction", ("301-302",)),
    CodeDispru("RO006", "EP21", "Produits nets d'exploitation bancaire exceptionnels ou inhabituels", "PRODUIT_BRUT", paragraphes=("301-302",)),
    CodeDispru("RO007", "EP21", "Produits provenant des activités d'assurance", "PRODUIT_BRUT", "deduction", ("301-302",)),
    CodeDispru("RO008", "EP21", "Produits des entités financières exclues du périmètre prudentiel", "PRODUIT_BRUT", "deduction", ("301-302",)),
)

# ── EP33 — Briques d'exposition du ratio de levier ──────────────────────────
# RL004, RL007, RL010, RL013 et RL015 sont des totaux calculés.
_LEVIER: tuple[CodeDispru, ...] = (
    CodeDispru("RL001", "EP33", "Actifs au bilan", "LEVIER"),
    CodeDispru("RL002", "EP33", "Expositions au bilan déduites des fonds propres", "LEVIER", "deduction"),
    CodeDispru("RL003", "EP33", "Expositions sur opérations assimilables à des pensions (retirées du bilan)", "LEVIER", "deduction"),
    CodeDispru("RL005", "EP33", "Dérivés non couverts par un accord-cadre de compensation bilatérale admissible", "LEVIER", paragraphes=("193-204",)),
    CodeDispru("RL006", "EP33", "Dérivés couverts par un accord-cadre de compensation bilatérale admissible", "LEVIER", paragraphes=("193-204",)),
    CodeDispru("RL008", "EP33", "Opérations assimilables à des pensions à titre d'intermédiaire", "LEVIER", paragraphes=("234-235",)),
    CodeDispru("RL009", "EP33", "Autres opérations assimilables à des pensions", "LEVIER"),
    CodeDispru("RL011", "EP33", "Engagements de financement", "LEVIER", paragraphes=("164-169",)),
    CodeDispru("RL012", "EP33", "Autres engagements hors bilan", "LEVIER", paragraphes=("164-169",)),
)

FONDS_PROPRES_CODES: tuple[CodeDispru, ...] = (
    _CET1_POSITIFS + _CET1_DEDUCTIONS + _AT1 + _T2 + _EFFECTIFS
    + _LIMITES_OPERATIONS + _PRODUIT_BRUT + _LEVIER
)

FONDS_PROPRES_REGISTRY: dict[str, CodeDispru] = {
    c.code.lower(): c for c in FONDS_PROPRES_CODES
}

# Libellés des totaux calculés (non saisis) — pour affichage / export.
TOTAUX_LABELS: dict[str, str] = {
    "fpi08": "Total des fonds propres CET1 avant déductions applicables",
    "fpi14": "Total des fonds propres CET1 ajustés avant déductions liées à des seuils",
    "fpi15": "Total des fonds propres CET1 ajustés des déductions liées aux participations non significatives",
    "fpi16": "Total des fonds propres CET1 ajustés des déductions liées aux participations significatives et IDA",
    "fpi22": "TOTAL DES FONDS PROPRES CET1",
    "fpi26": "Total des fonds propres AT1 avant déductions applicables",
    "fpi28": "TOTAL DES FONDS PROPRES AT1",
    "fpi29": "TOTAL DES FONDS PROPRES DE BASE T1",
    "fpi39": "Total des fonds propres T2 avant déductions applicables",
    "fpi40": "TOTAL DES FONDS PROPRES T2",
    "fpi41": "FONDS PROPRES EFFECTIFS",
}

# ── Solvabilité (EP02) et APR total (EP08) ──────────────────────────────────
# EP08 = somme des APR crédit + marché + opérationnel + grands risques.
# RisqueManagement calcule déjà crédit/marché/opérationnel (modules
# rwa_credit, market, risque_operationnel) : on les réutilise tels quels
# plutôt que de les recalculer (voir services.py::obtenir_apr_total).
APR_TOTAL_LABEL = "Total des actifs pondérés des risques (APR)"

# Seuils de solvabilité (%). Alignés sur la constante déjà en vigueur dans
# RisqueManagement (core/calculations.py) : 5 % CET1 / 6 % T1 / 9 % total —
# choix délibéré de l'établissement, confirmé, distinct du 4,5 % « de base »
# cité dans la notice technique BCEAO/Bâle III.
SOLVABILITE_SEUILS = {
    "cet1": 5.0,
    "t1": 6.0,
    "total": 9.0,
}
