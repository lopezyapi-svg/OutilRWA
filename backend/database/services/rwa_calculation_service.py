"""Règles de calcul RWA partagées entre SQLite et les modules métier."""

from __future__ import annotations

from datetime import date
from typing import Any

from app.core.calculations import calculate_capital
from app.expositions.models import (
    Counterparty,
    ExposureCreate,
    ExposureCrmDetails,
    ExposureView,
)


def normalize_text(value: str) -> str:
    return (
        value.strip()
        .lower()
        .replace("'", " ")
        .replace("’", " ")
        .replace("-", " ")
        .replace("é", "e")
        .replace("è", "e")
        .replace("ê", "e")
        .replace("à", "a")
        .replace("â", "a")
        .replace("ô", "o")
        .replace("î", "i")
        .replace("ï", "i")
        .replace("ç", "c")
    )


SOVEREIGN_NO_SPECIAL_CASE = "Aucun de ces cas"
SOVEREIGN_LEGACY_SPECIAL_CASE = "Cas préférentiel 0 % (historique)"
SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES: tuple[str, ...] = (
    "Expositions sur États de l’UEMOA et démembrements libellées et financées en FCFA",
    "Expositions sur BCEAO libellées et financées en FCFA",
    "UEMOA",
    "CEDEAO",
    "UA",
    "UE",
    "ONU",
    "BRI",
    "FMI",
    "BCE",
    "FGD-UMOA",
)
_SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES_NORMALIZED = {
    normalize_text(item) for item in SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES
}
_SOVEREIGN_NO_SPECIAL_CASE_NORMALIZED = normalize_text(SOVEREIGN_NO_SPECIAL_CASE)
_SOVEREIGN_LEGACY_SPECIAL_CASE_NORMALIZED = normalize_text(SOVEREIGN_LEGACY_SPECIAL_CASE)


CATEGORY_OPTIONS: tuple[dict[str, str], ...] = (
    {"code": "a", "legacy": "Souverains", "prudential": "(a) souverains"},
    {"code": "b", "legacy": "Organismes publics", "prudential": "(b) organismes pub. hors Adm c"},
    {"code": "c", "legacy": "BMD", "prudential": "(c) Expositions sur les BMD"},
    {"code": "d", "legacy": "Banques", "prudential": "(d) institutions financières"},
    {"code": "e", "legacy": "Entreprises", "prudential": "(e) entreprises"},
    {"code": "f", "legacy": "Particuliers", "prudential": "(f) clientèle de détail"},
    {"code": "g", "legacy": "Immobilier residentiel", "prudential": "(g) prêts garantis par l'immo R"},
    {"code": "h", "legacy": "Immobilier commercial", "prudential": "(h) prêts garantis par l'immo C"},
    {"code": "i", "legacy": "Creances en souffrance", "prudential": "(i) créances en souffrance"},
    {"code": "j", "legacy": "Créances à risque élevé", "prudential": "(j) créances à risque élevé"},
    {"code": "k", "legacy": "Autres actifs", "prudential": "(k) autres actifs"},
    {"code": "l", "legacy": "Hors bilan", "prudential": "(l) Hors bilan"},
)

_SOVEREIGN_OCE_RW_BY_NOTE: dict[str, float] = {
    "0": 0.0,
    "1": 0.0,
    "2": 0.2,
    "3": 0.5,
    "4": 1.0,
    "5": 1.0,
    "6": 1.0,
    "7": 1.5,
}
PUBLIC_BODY_UEMOA_FCFA_RISK_WEIGHT = 0.2
BANK_INSTITUTION_EQUIVALENT_RULES_CASE = "equivalent_umoa_rules"
BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE = "weak_prudential_case"
BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE = "eligible_categories_case"
OTHER_ASSET_CASH_TYPE = "Encaisse"
OTHER_ASSET_CASH_EQUIVALENT_TYPE = (
    "Valeurs assimilées à l’encaisse, y compris l’or"
)
OTHER_ASSET_IMMEDIATE_COLLECTION_TYPE = (
    "Valeurs à l’encaissement avec crédit immédiat"
)
OTHER_ASSET_NON_SIGNIFICANT_PARTICIPATIONS_TYPE = (
    "Participations non significatives non déduites des fonds propres"
)
OTHER_ASSET_TANGIBLE_FIXED_ASSETS_TYPE = "Immobilisations corporelles"
OTHER_ASSET_MISCELLANEOUS_TYPE = "Autres actifs divers"
OTHER_ASSET_EQUITY_COMMITMENTS_TYPE = "Engagements en actions non déduits"
OTHER_ASSET_NON_EQUIVALENT_FINANCIAL_COMPANIES_TYPE = (
    "Expositions sur entreprises financières non soumises à une réglementation équivalente UMOA"
)
OTHER_ASSET_UNDEFINED_TYPE = "Autres éléments d’actifs non définis"
OTHER_ASSET_SIGNIFICANT_PARTICIPATIONS_AND_DTA_TYPE = (
    "Participations significatives et impôts différés actifs non déduits"
)
OTHER_ASSET_NON_COMPLIANT_INSTITUTIONS_TYPE = (
    "Expositions sur établissements non conformes aux ratios de solvabilité"
)
OFF_BALANCE_LOW_RISK_LEVEL = "Risque faible"
OFF_BALANCE_MINOR_RISK_LEVEL = "Risque mineur"
OFF_BALANCE_MEDIUM_RISK_LEVEL = "Risque moyen"
OFF_BALANCE_HIGH_RISK_LEVEL = "Risque élevé"
OFF_BALANCE_VERY_HIGH_RISK_LEVEL = "Risque très élevé"
OTHER_ASSET_TYPE_OPTIONS: tuple[str, ...] = (
    OTHER_ASSET_CASH_TYPE,
    OTHER_ASSET_CASH_EQUIVALENT_TYPE,
    OTHER_ASSET_IMMEDIATE_COLLECTION_TYPE,
    OTHER_ASSET_NON_SIGNIFICANT_PARTICIPATIONS_TYPE,
    OTHER_ASSET_TANGIBLE_FIXED_ASSETS_TYPE,
    OTHER_ASSET_MISCELLANEOUS_TYPE,
    OTHER_ASSET_EQUITY_COMMITMENTS_TYPE,
    OTHER_ASSET_NON_EQUIVALENT_FINANCIAL_COMPANIES_TYPE,
    OTHER_ASSET_UNDEFINED_TYPE,
    OTHER_ASSET_SIGNIFICANT_PARTICIPATIONS_AND_DTA_TYPE,
    OTHER_ASSET_NON_COMPLIANT_INSTITUTIONS_TYPE,
)
OFF_BALANCE_RISK_LEVEL_OPTIONS: tuple[str, ...] = (
    OFF_BALANCE_LOW_RISK_LEVEL,
    OFF_BALANCE_MINOR_RISK_LEVEL,
    OFF_BALANCE_MEDIUM_RISK_LEVEL,
    OFF_BALANCE_HIGH_RISK_LEVEL,
    OFF_BALANCE_VERY_HIGH_RISK_LEVEL,
)


def resolve_category(category: str) -> dict[str, str]:
    normalized = normalize_text(category)
    for option in CATEGORY_OPTIONS:
        if normalized in {
            normalize_text(option["legacy"]),
            normalize_text(option["prudential"]),
        }:
            return option
        if option["code"] == "j" and normalized == normalize_text("Risque eleve"):
            return option
    return CATEGORY_OPTIONS[4]


def bucketize_rating(rating: str) -> str:
    normalized = rating.strip().upper()
    if normalized == "AAA/AA":
        return "AAA/AA"
    if normalized == "BB/B":
        return "BB/B"
    if normalized in {"AAA", "AA+", "AA", "AA-"}:
        return "AAA/AA"
    if normalized in {"A+", "A", "A-"}:
        return "A"
    if normalized in {"BBB+", "BBB", "BBB-"}:
        return "BBB"
    if normalized in {"BB+", "BB", "BB-", "B+", "B", "B-"}:
        return "BB/B"
    if normalized == "< B-":
        return "< B-"
    return "Non noté"


def lookup_sovereign_oce_risk_weight(note: str) -> float:
    return _SOVEREIGN_OCE_RW_BY_NOTE.get(str(note or "").strip(), 1.0)


def has_public_body_preferential_uemoa_case(
    public_body_uemoa_fcfa_case: bool | None,
    public_body_non_public_activity: bool | None,
) -> bool:
    return public_body_uemoa_fcfa_case is True and public_body_non_public_activity is False


def has_public_body_enterprise_override(
    public_body_uemoa_fcfa_case: bool | None,
    public_body_non_public_activity: bool | None,
) -> bool:
    return public_body_uemoa_fcfa_case is True and public_body_non_public_activity is True


def has_bmd_priority_zero_weight_case(
    bmd_high_quality_case: bool | None,
    bmd_uemoa_fcfa_case: bool | None,
    bmd_uemoa_criteria_satisfied: bool | None,
    bmd_listed_institution_fcfa_case: bool | None,
) -> bool:
    return (
        bmd_high_quality_case is True
        or (bmd_uemoa_fcfa_case is True and bmd_uemoa_criteria_satisfied is True)
        or bmd_listed_institution_fcfa_case is True
    )


def coerce_bank_institution_case(value: str | None) -> str | None:
    raw = str(value or "").strip()
    if not raw:
        return None
    normalized = normalize_text(raw)
    if normalized == normalize_text(BANK_INSTITUTION_EQUIVALENT_RULES_CASE):
        return BANK_INSTITUTION_EQUIVALENT_RULES_CASE
    if normalized == normalize_text(BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE):
        return BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE
    if normalized == normalize_text(BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE):
        return BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE
    if "equival" in normalized and "umoa" in normalized:
        return BANK_INSTITUTION_EQUIVALENT_RULES_CASE
    if (
        "degrad" in normalized
        or "solvabil" in normalized
        or "fonds propres" in normalized
    ):
        return BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE
    if "categor" in normalized and "banc" in normalized:
        return BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE
    return None


def coerce_other_asset_type(
    value: str | None, *, fallback_to_undefined: bool = False
) -> str | None:
    raw = str(value or "").strip()
    if raw:
        normalized = normalize_text(raw)
        for option in OTHER_ASSET_TYPE_OPTIONS:
            if normalized == normalize_text(option):
                return option
        if normalized == normalize_text("Autres actifs"):
            return OTHER_ASSET_UNDEFINED_TYPE
    return OTHER_ASSET_UNDEFINED_TYPE if fallback_to_undefined else None


def lookup_other_asset_risk_weight(other_asset_type: str | None) -> float:
    resolved = coerce_other_asset_type(
        other_asset_type,
        fallback_to_undefined=True,
    )
    if resolved in {
        OTHER_ASSET_CASH_TYPE,
        OTHER_ASSET_CASH_EQUIVALENT_TYPE,
    }:
        return 0.0
    if resolved == OTHER_ASSET_IMMEDIATE_COLLECTION_TYPE:
        return 0.2
    if resolved in {
        OTHER_ASSET_SIGNIFICANT_PARTICIPATIONS_AND_DTA_TYPE,
        OTHER_ASSET_NON_COMPLIANT_INSTITUTIONS_TYPE,
    }:
        return 2.5
    return 1.0


def lookup_country_rating_risk_weight(country_rating: str) -> float:
    bucket = bucketize_rating(country_rating)
    if bucket == "AAA/AA":
        return 0.0
    if bucket == "A":
        return 0.2
    if bucket == "BBB":
        return 0.5
    if bucket == "BB/B":
        return 1.0
    if bucket == "< B-":
        return 1.5
    return 1.0


def should_apply_unrated_counterparty_country_floor(category_code: str) -> bool:
    return category_code not in {"a", "k", "l"}


def apply_unrated_counterparty_country_floor(
    risk_weight: float,
    rating: str,
    *,
    category_code: str,
    country_rating: str | None = None,
) -> float:
    if not should_apply_unrated_counterparty_country_floor(category_code):
        return risk_weight
    if bucketize_rating(rating) != "Non noté":
        return risk_weight
    country_weight = lookup_country_rating_risk_weight(country_rating or "Non noté")
    floor = max(1.0, country_weight)
    return max(risk_weight, floor)


def infer_off_balance_risk_level_from_factor(factor: float | None) -> str | None:
    if factor is None:
        return None
    epsilon = 0.0001
    if abs(factor - 0.1) <= epsilon:
        return OFF_BALANCE_LOW_RISK_LEVEL
    if abs(factor - 0.2) <= epsilon:
        return OFF_BALANCE_MINOR_RISK_LEVEL
    if abs(factor - 0.5) <= epsilon:
        return OFF_BALANCE_MEDIUM_RISK_LEVEL
    if abs(factor - 0.75) <= epsilon:
        return OFF_BALANCE_HIGH_RISK_LEVEL
    if abs(factor - 1.0) <= epsilon:
        return OFF_BALANCE_VERY_HIGH_RISK_LEVEL
    return None


def coerce_off_balance_risk_level(
    value: str | None,
    *,
    fallback_to_very_high: bool = False,
    factor_hint: float | None = None,
) -> str | None:
    raw = str(value or "").strip()
    if raw:
        normalized = normalize_text(raw)
        for option in OFF_BALANCE_RISK_LEVEL_OPTIONS:
            if normalized == normalize_text(option):
                return option
    inferred = infer_off_balance_risk_level_from_factor(factor_hint)
    if inferred is not None:
        return inferred
    return OFF_BALANCE_VERY_HIGH_RISK_LEVEL if fallback_to_very_high else None


def lookup_off_balance_fcec(off_balance_risk_level: str | None) -> float:
    resolved = coerce_off_balance_risk_level(
        off_balance_risk_level,
        fallback_to_very_high=True,
    )
    if resolved == OFF_BALANCE_LOW_RISK_LEVEL:
        return 0.1
    if resolved == OFF_BALANCE_MINOR_RISK_LEVEL:
        return 0.2
    if resolved == OFF_BALANCE_MEDIUM_RISK_LEVEL:
        return 0.5
    if resolved == OFF_BALANCE_HIGH_RISK_LEVEL:
        return 0.75
    return 1.0


def compute_initial_maturity_months(
    grant_date: date | None, maturity_date: date | None
) -> int:
    if grant_date is None or maturity_date is None:
        return 4
    months = (maturity_date.year - grant_date.year) * 12 + (
        maturity_date.month - grant_date.month
    )
    if maturity_date.day < grant_date.day:
        months -= 1
    return max(months, 0)


def has_short_initial_maturity(
    grant_date: date | None, maturity_date: date | None
) -> bool:
    return compute_initial_maturity_months(grant_date, maturity_date) <= 3


def lookup_bank_institution_risk_weight(
    rating: str, *, is_short_initial_maturity: bool
) -> float:
    bucket = bucketize_rating(rating)
    if is_short_initial_maturity:
        if bucket in {"AAA/AA", "A", "BBB"}:
            return 0.2
        if bucket == "BB/B":
            return 0.5
        if bucket == "< B-":
            return 1.5
        return 0.2
    if bucket == "AAA/AA":
        return 0.2
    if bucket in {"A", "BBB"}:
        return 0.5
    if bucket == "BB/B":
        return 1.0
    if bucket == "< B-":
        return 1.5
    return 0.5


def lookup_enterprise_risk_weight(
    rating: str,
    *,
    enterprise_exceeds_bceao_degradation_threshold: bool = False,
    enterprise_prudential_procedure: bool = False,
) -> float:
    if (
        enterprise_exceeds_bceao_degradation_threshold
        or enterprise_prudential_procedure
    ):
        return 1.5
    normalized = str(rating or "").strip().upper()
    if normalized in {"AAA", "AA+", "AA", "AA-"}:
        return 0.2
    if normalized in {"A+", "A", "A-"}:
        return 0.5
    if normalized in {"BBB+", "BBB", "BBB-", "BB+", "BB", "BB-"}:
        return 1.0
    if normalized in {"< BB-", "B+", "B", "B-", "< B-"}:
        return 1.5
    return 1.0


def lookup_residential_mortgage_risk_weight(
    residential_mortgage_eligible: bool | None,
) -> float:
    return 0.35 if residential_mortgage_eligible is True else 1.0


def lookup_commercial_real_estate_risk_weight(
    commercial_real_estate_eligible: bool | None,
) -> float:
    return 0.75 if commercial_real_estate_eligible is True else 1.0


def lookup_defaulted_exposure_risk_weight(
    initial_risk_weight: float | None,
    *,
    is_residential_mortgage_in_default: bool | None,
    provision_at_least_twenty_percent: bool | None,
) -> float:
    resolved_initial_risk_weight = max(0.0, min(float(initial_risk_weight or 1.0), 2.5))
    if resolved_initial_risk_weight > 1.0:
        return resolved_initial_risk_weight
    if is_residential_mortgage_in_default is True:
        return 1.0
    if is_residential_mortgage_in_default is False:
        if provision_at_least_twenty_percent is True:
            return 1.0
        if provision_at_least_twenty_percent is False:
            return 1.5
    return resolved_initial_risk_weight


def normalize_sovereign_special_case(
    value: str | None, *, fallback_to_legacy: bool = False
) -> str:
    raw = str(value or "").strip()
    if not raw:
        return (
            SOVEREIGN_LEGACY_SPECIAL_CASE
            if fallback_to_legacy
            else SOVEREIGN_NO_SPECIAL_CASE
        )
    normalized = normalize_text(raw)
    if normalized == _SOVEREIGN_LEGACY_SPECIAL_CASE_NORMALIZED:
        return SOVEREIGN_LEGACY_SPECIAL_CASE
    if normalized == _SOVEREIGN_NO_SPECIAL_CASE_NORMALIZED:
        return SOVEREIGN_NO_SPECIAL_CASE
    for item in SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES:
        if normalized == normalize_text(item):
            return item
    return (
        SOVEREIGN_LEGACY_SPECIAL_CASE
        if fallback_to_legacy
        else SOVEREIGN_NO_SPECIAL_CASE
    )


def has_sovereign_priority_zero_weight_case(
    sovereign_special_case: str | None,
    *,
    sovereign_preferential_zero_weight: bool = False,
) -> bool:
    normalized = normalize_text(str(sovereign_special_case or ""))
    return (
        normalized in _SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES_NORMALIZED
        or normalized == _SOVEREIGN_LEGACY_SPECIAL_CASE_NORMALIZED
        or sovereign_preferential_zero_weight
    )


def lookup_prudential_risk_weight(
    category_code: str,
    rating: str,
    *,
    country_rating: str | None = None,
    sovereign_special_case: str = "",
    sovereign_preferential_zero_weight: bool = False,
    sovereign_oce_established: bool = False,
    sovereign_oce_note: str = "",
    public_body_uemoa_fcfa_case: bool | None = None,
    public_body_non_public_activity: bool | None = None,
    bmd_high_quality_case: bool | None = None,
    bmd_uemoa_fcfa_case: bool | None = None,
    bmd_uemoa_criteria_satisfied: bool | None = None,
    bmd_listed_institution_fcfa_case: bool | None = None,
    bank_institution_case: str | None = None,
    other_asset_type: str | None = None,
    off_balance_risk_level: str | None = None,
    retail_eligibility_criteria_satisfied: bool | None = None,
    residential_mortgage_eligible: bool | None = None,
    commercial_real_estate_eligible: bool | None = None,
    defaulted_exposure_initial_risk_weight: float | None = None,
    defaulted_exposure_residential_mortgage_in_default: bool | None = None,
    defaulted_exposure_provision_at_least_twenty_percent: bool | None = None,
    enterprise_exceeds_bceao_degradation_threshold: bool | None = None,
    enterprise_prudential_procedure: bool | None = None,
    enterprise_investment_firm_without_banking_law: bool | None = None,
    grant_date: date | None = None,
    maturity_date: date | None = None,
) -> float:
    bucket = bucketize_rating(rating)
    def finalize(risk_weight: float) -> float:
        return apply_unrated_counterparty_country_floor(
            risk_weight,
            rating,
            category_code=category_code,
            country_rating=country_rating,
        )

    if category_code == "a" and has_sovereign_priority_zero_weight_case(
        sovereign_special_case,
        sovereign_preferential_zero_weight=sovereign_preferential_zero_weight,
    ):
        return finalize(0.0)
    if category_code == "a" and bucket == "Non noté" and sovereign_oce_established:
        return finalize(lookup_sovereign_oce_risk_weight(sovereign_oce_note))
    if category_code == "b" and has_public_body_preferential_uemoa_case(
        public_body_uemoa_fcfa_case,
        public_body_non_public_activity,
    ):
        return finalize(PUBLIC_BODY_UEMOA_FCFA_RISK_WEIGHT)
    if category_code == "b" and has_public_body_enterprise_override(
        public_body_uemoa_fcfa_case,
        public_body_non_public_activity,
    ):
        return lookup_prudential_risk_weight(
            "e",
            rating,
            country_rating=country_rating,
        )
    if category_code == "c" and has_bmd_priority_zero_weight_case(
        bmd_high_quality_case,
        bmd_uemoa_fcfa_case,
        bmd_uemoa_criteria_satisfied,
        bmd_listed_institution_fcfa_case,
    ):
        return finalize(0.0)
    if category_code == "d":
        resolved_bank_case = coerce_bank_institution_case(bank_institution_case)
        if resolved_bank_case == BANK_INSTITUTION_EQUIVALENT_RULES_CASE:
            return finalize(1.0)
        if resolved_bank_case == BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE:
            return finalize(2.5)
        if resolved_bank_case == BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE:
            return finalize(lookup_bank_institution_risk_weight(
                rating,
                is_short_initial_maturity=has_short_initial_maturity(
                    grant_date, maturity_date
                ),
            ))
    if category_code == "e":
        return finalize(lookup_enterprise_risk_weight(
            rating,
            enterprise_exceeds_bceao_degradation_threshold=
                enterprise_exceeds_bceao_degradation_threshold is True,
            enterprise_prudential_procedure=
                enterprise_prudential_procedure is True,
        ))
    if category_code == "f":
        if retail_eligibility_criteria_satisfied is False:
            return lookup_prudential_risk_weight(
                "e",
                rating,
                country_rating=country_rating,
                enterprise_exceeds_bceao_degradation_threshold=
                    enterprise_exceeds_bceao_degradation_threshold,
                enterprise_prudential_procedure=
                    enterprise_prudential_procedure,
                enterprise_investment_firm_without_banking_law=
                    enterprise_investment_firm_without_banking_law,
                grant_date=grant_date,
                maturity_date=maturity_date,
            )
        return finalize(0.75)
    if category_code == "k":
        return finalize(lookup_other_asset_risk_weight(other_asset_type))
    if category_code == "l":
        return finalize(lookup_off_balance_fcec(off_balance_risk_level))
    if category_code == "g":
        return finalize(
            lookup_residential_mortgage_risk_weight(
                residential_mortgage_eligible
            )
        )
    if category_code == "h":
        if commercial_real_estate_eligible is False:
            return lookup_prudential_risk_weight(
                "e",
                rating,
                country_rating=country_rating,
                enterprise_exceeds_bceao_degradation_threshold=
                    enterprise_exceeds_bceao_degradation_threshold,
                enterprise_prudential_procedure=
                    enterprise_prudential_procedure,
                enterprise_investment_firm_without_banking_law=
                    enterprise_investment_firm_without_banking_law,
                grant_date=grant_date,
                maturity_date=maturity_date,
            )
        return finalize(
            lookup_commercial_real_estate_risk_weight(
                commercial_real_estate_eligible
            )
        )
    if category_code == "i":
        return finalize(lookup_defaulted_exposure_risk_weight(
            defaulted_exposure_initial_risk_weight,
            is_residential_mortgage_in_default=
                defaulted_exposure_residential_mortgage_in_default,
            provision_at_least_twenty_percent=
                defaulted_exposure_provision_at_least_twenty_percent,
        ))
    if category_code == "j":
        return finalize(1.5)
    if category_code == "k":
        return finalize(1.0)
    lookup = {
        "a": {"AAA/AA": 0.0, "A": 0.2, "BBB": 0.5, "BB/B": 1.0, "< B-": 1.5, "Non noté": 1.0},
        "b": {"AAA/AA": 0.2, "A": 0.5, "BBB": 1.0, "BB/B": 1.0, "< B-": 1.5, "Non noté": 1.0},
        "c": {"AAA/AA": 0.2, "A": 0.5, "BBB": 0.5, "BB/B": 1.0, "< B-": 1.5, "Non noté": 0.5},
        "d": {"AAA/AA": 0.2, "A": 0.5, "BBB": 0.5, "BB/B": 1.0, "< B-": 1.5, "Non noté": 1.0},
    }
    return finalize(lookup.get(category_code, lookup["d"]).get(bucket, 1.0))


def normalize_maturity_bucket(value: str) -> str:
    normalized = normalize_text(value).replace(" ", "")
    if normalized in {"<=1an", "<=1ans"}:
        return "<=1 an"
    if normalized in {"1a3ans", "1-3ans"}:
        return "1-3 ans"
    if normalized in {"3a5ans", "3-5ans", "1a5ans", "1-5ans"}:
        return "3-5 ans"
    if normalized == "5-10ans":
        return "5-10 ans"
    if normalized in {">10ans", ">5ans"}:
        return ">10 ans"
    return value or "<=1 an"


def normalize_financed_crm_currency(currency: str) -> str:
    normalized = str(currency or "").strip().upper()
    if normalized in {"XOF", "XAF", "FCFA"}:
        return "FCFA"
    return normalized


def normalize_financed_crm_rating(rating: str) -> str:
    normalized = str(rating or "").strip().upper()
    if normalized in {"NON NOTE", "NON NOTÉ"}:
        return "NON NOTE"
    return normalized


def is_financed_crm_debt_collateral(collateral_type: str) -> bool:
    return collateral_type in {
        "Titre de dette souverain",
        "Titre non noté émis par un État de l UMOA",
        "Titre de dette émis par un autre émetteur",
        "Titre garanti par un agent agréé par la BRVM",
        "Titre bancaire non noté",
    }


def lookup_financed_crm_hfx(exposure_currency: str, collateral_currency: str) -> float:
    exposure = normalize_financed_crm_currency(exposure_currency)
    collateral = normalize_financed_crm_currency(collateral_currency)
    if exposure == collateral:
        return 0.0
    if (exposure == "FCFA" and collateral == "EUR") or (
        exposure == "EUR" and collateral == "FCFA"
    ):
        return 0.0
    return 0.08


def _lookup_financed_crm_debt_haircut(
    *,
    collateral_type: str,
    issuer_type: str,
    rating: str,
    maturity_bucket: str,
) -> float:
    sovereign = "souverain" in normalize_text(issuer_type)
    bucket = normalize_maturity_bucket(maturity_bucket)
    normalized_rating = normalize_financed_crm_rating(rating)

    if collateral_type == "Titre non noté émis par un État de l UMOA":
        if bucket == "<=1 an":
            return 0.005 if sovereign else 0.01
        if bucket == "1-3 ans":
            return 0.02 if sovereign else 0.03
        if bucket == "3-5 ans":
            return 0.02 if sovereign else 0.04
        if bucket == "5-10 ans":
            return 0.04 if sovereign else 0.06
        return 0.04 if sovereign else 0.12

    if collateral_type in {
        "Titre garanti par un agent agréé par la BRVM",
        "Titre bancaire non noté",
    }:
        if bucket == "<=1 an":
            return 0.01 if sovereign else 0.02
        if bucket == "1-3 ans":
            return 0.03 if sovereign else 0.04
        if bucket == "3-5 ans":
            return 0.03 if sovereign else 0.06
        if bucket == "5-10 ans":
            return 0.06 if sovereign else 0.12
        return 0.06 if sovereign else 0.20

    if normalized_rating in {"AAA", "AA+", "AA", "AA-"}:
        if bucket == "<=1 an":
            return 0.005 if sovereign else 0.01
        if bucket == "1-3 ans":
            return 0.02 if sovereign else 0.03
        if bucket == "3-5 ans":
            return 0.02 if sovereign else 0.04
        if bucket == "5-10 ans":
            return 0.04 if sovereign else 0.06
        return 0.04 if sovereign else 0.12

    if normalized_rating in {"A+", "A", "A-", "BBB+", "BBB", "BBB-"}:
        if bucket == "<=1 an":
            return 0.01 if sovereign else 0.02
        if bucket == "1-3 ans":
            return 0.03 if sovereign else 0.04
        if bucket == "3-5 ans":
            return 0.03 if sovereign else 0.06
        if bucket == "5-10 ans":
            return 0.06 if sovereign else 0.12
        return 0.06 if sovereign else 0.20

    if normalized_rating in {"BB+", "BB", "BB-"} and sovereign:
        return 0.15
    return 0.0


def _evaluate_single_financed_collateral(
    *,
    exposure_currency: str,
    collateral_value: float,
    collateral_currency: str,
    collateral_type: str,
    issuer_type: str,
    rating: str,
    maturity_bucket: str,
    convertible_main_index: bool,
    opcvm_highest_haircut: float,
) -> dict[str, Any]:
    if collateral_value <= 0:
        return {
            "eligible": False,
            "reason": "Valeur de sûreté non renseignée.",
            "value": 0.0,
            "hc": 0.0,
            "hfx": 0.0,
            "cva": 0.0,
        }

    if collateral_type == "Autre sûreté non éligible":
        return {
            "eligible": False,
            "reason": "Cette sûreté n est pas reconnue par le dispositif prudentiel.",
            "value": collateral_value,
            "hc": 0.0,
            "hfx": 0.0,
            "cva": 0.0,
        }

    normalized_rating = normalize_financed_crm_rating(rating)
    eligible = True
    reason = ""
    hc = 0.0

    if collateral_type in {
        "Liquidités dans la même devise",
        "Liquidités dans une devise différente",
    }:
        hc = 0.0
    elif collateral_type in {
        "Or",
        "Action de l indice BRVM 10",
        "Action d un indice principal reconnu",
    }:
        hc = 0.20
    elif collateral_type == "Autre action cotée à la BRVM ou sur une bourse reconnue":
        hc = 0.30
    elif collateral_type == "Obligation convertible en action":
        hc = 0.20 if convertible_main_index else 0.30
    elif collateral_type == "OPCVM / FI":
        hc = max(0.0, float(opcvm_highest_haircut or 0.30))
    elif collateral_type in {
        "Titre non noté émis par un État de l UMOA",
        "Titre garanti par un agent agréé par la BRVM",
        "Titre bancaire non noté",
    }:
        hc = _lookup_financed_crm_debt_haircut(
            collateral_type=collateral_type,
            issuer_type=issuer_type,
            rating=rating,
            maturity_bucket=maturity_bucket,
        )
    elif collateral_type in {
        "Titre de dette souverain",
        "Titre de dette émis par un autre émetteur",
    }:
        if normalized_rating == "NON NOTE":
            eligible = False
            reason = "La notation de la sûreté doit être renseignée pour ce titre de dette."
        elif normalized_rating == "< B-":
            eligible = False
            reason = "Les titres en dessous de BB- ne sont pas éligibles."
        elif normalized_rating in {"BB+", "BB", "BB-"} and "souverain" not in normalize_text(issuer_type):
            eligible = False
            reason = "Un autre émetteur noté BB+ à BB- n est pas éligible à la CRM financée."
        else:
            hc = _lookup_financed_crm_debt_haircut(
                collateral_type=collateral_type,
                issuer_type=issuer_type,
                rating=rating,
                maturity_bucket=maturity_bucket,
            )
    else:
        eligible = False
        reason = "Cette sûreté n est pas éligible à la réduction réglementaire."

    hfx = lookup_financed_crm_hfx(exposure_currency, collateral_currency)
    cva = (
        max(collateral_value * max(0.0, 1.0 - hc - hfx), 0.0) if eligible else 0.0
    )
    return {
        "eligible": eligible,
        "reason": reason,
        "value": collateral_value,
        "hc": hc,
        "hfx": hfx,
        "cva": cva,
    }


def compute_financed_crm_details(
    payload: ExposureCreate,
    *,
    risk_weight: float,
    crm_details: dict[str, Any],
) -> dict[str, Any]:
    exposure_currency = str(crm_details.get("exposure_currency") or payload.currency or "XOF")
    collateral_value = float(crm_details.get("collateral_value", 0.0) or 0.0)
    collateral_currency = str(crm_details.get("collateral_currency") or exposure_currency)
    collateral_type = str(
        crm_details.get("collateral_type") or "Liquidités dans la même devise"
    )
    issuer_type = str(crm_details.get("issuer_type") or "autre émetteur")
    issuer_rating = str(crm_details.get("issuer_rating") or "Non noté")
    maturity_bucket = str(crm_details.get("maturity_bucket") or "<=1 an")
    convertible_main_index = bool(crm_details.get("convertible_main_index", True))
    opcvm_highest_haircut = float(
        crm_details.get("opcvm_highest_haircut", 0.30) or 0.30
    )
    basket_items = list(crm_details.get("basket_items") or [])

    gross_amount = float(payload.gross_amount or 0.0)
    he = 0.0
    eva = gross_amount * (1 + he)

    if collateral_type == "Panier d actifs" and basket_items:
        total_value = 0.0
        total_cva = 0.0
        weighted_hc = 0.0
        weighted_hfx = 0.0
        ineligible_reasons: list[str] = []
        for item in basket_items:
            row = dict(item or {})
            item_value = float(row.get("value", 0.0) or 0.0)
            outcome = _evaluate_single_financed_collateral(
                exposure_currency=exposure_currency,
                collateral_value=item_value,
                collateral_currency=str(row.get("currency") or collateral_currency),
                collateral_type=str(row.get("collateral_type") or "Liquidités dans la même devise"),
                issuer_type=str(row.get("issuer_role") or "autre émetteur"),
                rating=str(row.get("rating") or "Non noté"),
                maturity_bucket=str(row.get("residual_maturity_bucket") or "<=1 an"),
                convertible_main_index=bool(row.get("convertible_main_index", True)),
                opcvm_highest_haircut=float(
                    row.get("opcvm_highest_haircut", 0.30) or 0.30
                ),
            )
            total_value += item_value
            total_cva += float(outcome["cva"])
            weighted_hc += item_value * float(outcome["hc"])
            weighted_hfx += item_value * float(outcome["hfx"])
            if not outcome["eligible"] and outcome["reason"]:
                ineligible_reasons.append(str(outcome["reason"]))
        denominator = total_value if total_value > 0 else 1.0
        eligible = total_cva > 0
        eligibility_reason = "" if eligible else (
            ineligible_reasons[0] if ineligible_reasons else "Aucun actif éligible dans le panier."
        )
        hc = weighted_hc / denominator
        hfx = weighted_hfx / denominator
        cva = total_cva if eligible else 0.0
        collateral_value = total_value
    else:
        outcome = _evaluate_single_financed_collateral(
            exposure_currency=exposure_currency,
            collateral_value=collateral_value,
            collateral_currency=collateral_currency,
            collateral_type=collateral_type,
            issuer_type=issuer_type,
            rating=issuer_rating,
            maturity_bucket=maturity_bucket,
            convertible_main_index=convertible_main_index,
            opcvm_highest_haircut=opcvm_highest_haircut,
        )
        eligible = bool(outcome["eligible"])
        eligibility_reason = str(outcome["reason"] or "")
        hc = float(outcome["hc"])
        hfx = float(outcome["hfx"])
        cva = float(outcome["cva"]) if eligible else 0.0

    ead_after_financed_crm = max(0.0, eva - cva) if eligible else gross_amount
    rwa_final = ead_after_financed_crm * risk_weight
    crm_gain = max(0.0, gross_amount - ead_after_financed_crm)
    coverage_percent = clamp_ratio(crm_gain / gross_amount) if gross_amount > 0 else 0.0

    return {
        "mode": "CRM financee",
        "label": crm_details.get("label") or payload.crm_type,
        "collateral_value": collateral_value,
        "collateral_currency": collateral_currency,
        "collateral_type": collateral_type,
        "issuer_type": issuer_type,
        "issuer_rating": issuer_rating,
        "maturity_bucket": normalize_maturity_bucket(maturity_bucket),
        "convertible_main_index": convertible_main_index,
        "opcvm_highest_haircut": opcvm_highest_haircut,
        "basket_items": basket_items,
        "fx_haircut": hfx,
        "exposure_currency": exposure_currency,
        "risk_weight": risk_weight,
        "eligible": eligible,
        "eligibility_reason": eligibility_reason,
        "he": he,
        "hc": hc,
        "hfx": hfx,
        "eva": eva,
        "cva": cva,
        "ead_after_financed_crm": ead_after_financed_crm,
        "rwa_final": rwa_final,
        "crm_gain": crm_gain,
        "coverage_percent": coverage_percent,
    }


def crm_mode_from_type(crm_type: str) -> str:
    normalized = normalize_text(crm_type)
    if not normalized or normalized in {"aucune", "sans crm"}:
        return "Aucune"
    if "non financ" in normalized or "garantie" in normalized or "assurance" in normalized:
        return "CRM non financee"
    if "cash" in normalized or "collateral" in normalized or "financee" in normalized:
        return "CRM financee"
    return "CRM non financee"


def normalize_exposure_category_label(category: str) -> str:
    return resolve_category(category)["prudential"]


def normalize_exposure_rating_label(rating: str) -> str:
    return bucketize_rating(rating)


def normalize_exposure_crm_mode(crm_type: str, crm_details: Any | None = None) -> str:
    if crm_details is None:
        return crm_mode_from_type(crm_type)
    details = model_dump(crm_details)
    mode = str(details.get("mode") or "").strip()
    return mode or crm_mode_from_type(crm_type)


def model_dump(model: Any) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return dict(model.model_dump())
    if hasattr(model, "dict"):
        return dict(model.dict())
    return dict(model)


def clamp_ratio(value: float) -> float:
    return max(0.0, min(value, 1.0))


def crm_details_payload(payload: ExposureCreate) -> dict[str, Any]:
    crm_details = model_dump(payload.crm_details)
    crm_mode = crm_details.get("mode") or crm_mode_from_type(payload.crm_type)
    crm_details["mode"] = crm_mode
    crm_details["label"] = crm_details.get("label") or payload.crm_type
    crm_details["maturity_bucket"] = normalize_maturity_bucket(str(crm_details.get("maturity_bucket") or "<=1 an"))
    crm_details["coverage_percent"] = clamp_ratio(
        float(crm_details.get("coverage_percent", payload.crm_coverage_percent or 0.0))
    )
    crm_details["collateral_currency"] = str(
        crm_details.get("collateral_currency") or payload.currency or "XOF"
    )
    crm_details["collateral_type"] = str(
        crm_details.get("collateral_type") or "Liquidités dans la même devise"
    )
    crm_details["exposure_currency"] = str(
        crm_details.get("exposure_currency") or payload.currency or "XOF"
    )
    if crm_mode == "CRM non financee":
        country_rating = str(crm_details.get("guarantor_country_rating") or "")
        crm_details["guarantor_country_rw"] = (
            lookup_prudential_risk_weight("a", country_rating)
            if country_rating
            else 0.0
        )
    return crm_details


def compute_metrics(payload: ExposureCreate, category_code: str, crm_details: dict[str, Any]) -> dict[str, float]:
    original_rw = lookup_prudential_risk_weight(
        category_code,
        payload.rating,
        country_rating=payload.country_rating,
        sovereign_special_case=payload.sovereign_special_case,
        sovereign_preferential_zero_weight=payload.sovereign_preferential_zero_weight,
        sovereign_oce_established=payload.sovereign_oce_established,
        sovereign_oce_note=payload.sovereign_oce_note,
        public_body_uemoa_fcfa_case=payload.public_body_uemoa_fcfa_case,
        public_body_non_public_activity=payload.public_body_non_public_activity,
        bmd_high_quality_case=payload.bmd_high_quality_case,
        bmd_uemoa_fcfa_case=payload.bmd_uemoa_fcfa_case,
        bmd_uemoa_criteria_satisfied=payload.bmd_uemoa_criteria_satisfied,
        bmd_listed_institution_fcfa_case=payload.bmd_listed_institution_fcfa_case,
        bank_institution_case=payload.bank_institution_case,
        other_asset_type=payload.other_asset_type,
        off_balance_risk_level=payload.off_balance_risk_level,
        retail_eligibility_criteria_satisfied=
            payload.retail_eligibility_criteria_satisfied,
        residential_mortgage_eligible=payload.residential_mortgage_eligible,
        commercial_real_estate_eligible=payload.commercial_real_estate_eligible,
        defaulted_exposure_initial_risk_weight=
            payload.defaulted_exposure_initial_risk_weight,
        defaulted_exposure_residential_mortgage_in_default=
            payload.defaulted_exposure_residential_mortgage_in_default,
        defaulted_exposure_provision_at_least_twenty_percent=
            payload.defaulted_exposure_provision_at_least_twenty_percent,
        enterprise_exceeds_bceao_degradation_threshold=
            payload.enterprise_exceeds_bceao_degradation_threshold,
        enterprise_prudential_procedure=payload.enterprise_prudential_procedure,
        enterprise_investment_firm_without_banking_law=
            payload.enterprise_investment_firm_without_banking_law,
        grant_date=payload.grant_date,
        maturity_date=payload.maturity_date,
    )
    final_rw = original_rw
    gross_amount = payload.gross_amount
    ead = gross_amount
    effective_coverage = 0.0
    guarantor_rw = 0.0
    haircut = 0.0

    if category_code == "l":
        rwa = round(ead * final_rw, 2)
        capital = calculate_capital(rwa)
        return {
            "original_rw": round(original_rw, 4),
            "final_rw": round(final_rw, 4),
            "ead": round(ead, 2),
            "rwa": rwa,
            "capital": capital,
            "effective_coverage": 0.0,
            "guarantor_rw": 0.0,
            "haircut": 0.0,
        }

    if crm_details["mode"] == "CRM financee":
        financed_details = compute_financed_crm_details(
            payload,
            risk_weight=original_rw,
            crm_details=crm_details,
        )
        crm_details.update(financed_details)
        effective_coverage = float(financed_details["coverage_percent"])
        haircut = float(financed_details["hc"])
        ead = float(financed_details["ead_after_financed_crm"])
        final_rw = original_rw
    elif crm_details["mode"] == "CRM non financee":
        effective_coverage = clamp_ratio(float(crm_details.get("coverage_percent", payload.crm_coverage_percent)))
        guarantor_category = resolve_category(str(crm_details.get("guarantor_category") or "Souverains"))
        guarantor_rating = str(crm_details.get("guarantor_rating") or payload.rating)
        guarantor_rw = lookup_prudential_risk_weight(guarantor_category["code"], guarantor_rating)
        covered_ead = gross_amount * effective_coverage
        uncovered_ead = gross_amount - covered_ead
        rwa = (covered_ead * guarantor_rw) + (uncovered_ead * guarantor_rw)
        final_rw = 0.0 if gross_amount == 0 else max(0.0, min(rwa / gross_amount, 1.5))

    rwa = round(ead * final_rw, 2)
    capital = calculate_capital(rwa)
    return {
        "original_rw": round(original_rw, 4),
        "final_rw": round(final_rw, 4),
        "ead": round(ead, 2),
        "rwa": rwa,
        "capital": capital,
        "effective_coverage": round(effective_coverage, 4),
        "guarantor_rw": round(guarantor_rw, 4),
        "haircut": round(haircut, 4),
    }


def build_exposure_record(payload: ExposureCreate, exposure_id: str) -> dict[str, Any]:
    category = resolve_category(payload.category)
    crm_details = crm_details_payload(payload)
    metrics = compute_metrics(payload, category["code"], crm_details)
    crm_details["coverage_percent"] = metrics["effective_coverage"]
    crm_details["haircut"] = metrics["haircut"]
    if crm_details["mode"] == "CRM financee":
        crm_details["risk_weight"] = metrics["original_rw"]
        crm_details["rwa_final"] = metrics["rwa"]
        crm_details["ead_after_financed_crm"] = metrics["ead"]
    return {
        "id": exposure_id,
        "analysis_date": payload.analysis_date,
        "grant_date": payload.grant_date,
        "maturity_date": payload.maturity_date,
        "counterparty_name": payload.counterparty_name,
        "country": payload.country,
        "country_rating": payload.country_rating,
        "category_raw": category["prudential"],
        "category_dashboard": category["legacy"],
        "category_standard": category["legacy"],
        "rating": payload.rating,
        "gross_amount": payload.gross_amount,
        "currency": payload.currency or "XOF",
        "status": payload.status or "Active",
        "sovereign_special_case": normalize_sovereign_special_case(
            payload.sovereign_special_case,
            fallback_to_legacy=payload.sovereign_preferential_zero_weight,
        ),
        "sovereign_preferential_zero_weight": payload.sovereign_preferential_zero_weight,
        "sovereign_oce_established": payload.sovereign_oce_established,
        "sovereign_oce_note": payload.sovereign_oce_note or "",
        "public_body_uemoa_fcfa_case": payload.public_body_uemoa_fcfa_case,
        "public_body_non_public_activity": payload.public_body_non_public_activity,
        "bmd_high_quality_case": payload.bmd_high_quality_case,
        "bmd_uemoa_fcfa_case": payload.bmd_uemoa_fcfa_case,
        "bmd_uemoa_criteria_satisfied": payload.bmd_uemoa_criteria_satisfied,
        "bmd_listed_institution_fcfa_case": payload.bmd_listed_institution_fcfa_case,
        "bank_institution_case": coerce_bank_institution_case(
            payload.bank_institution_case
        ),
        "other_asset_type": coerce_other_asset_type(
            payload.other_asset_type,
            fallback_to_undefined=category["code"] == "k",
        ),
        "off_balance_risk_level": coerce_off_balance_risk_level(
            payload.off_balance_risk_level,
            fallback_to_very_high=category["code"] == "l",
        ),
        "retail_eligibility_criteria_satisfied":
            payload.retail_eligibility_criteria_satisfied,
        "residential_mortgage_eligible": payload.residential_mortgage_eligible,
        "commercial_real_estate_eligible":
            payload.commercial_real_estate_eligible,
        "defaulted_exposure_initial_risk_weight":
            payload.defaulted_exposure_initial_risk_weight,
        "defaulted_exposure_residential_mortgage_in_default":
            payload.defaulted_exposure_residential_mortgage_in_default,
        "defaulted_exposure_provision_at_least_twenty_percent":
            payload.defaulted_exposure_provision_at_least_twenty_percent,
        "enterprise_exceeds_bceao_degradation_threshold":
            payload.enterprise_exceeds_bceao_degradation_threshold,
        "enterprise_prudential_procedure": payload.enterprise_prudential_procedure,
        "enterprise_investment_firm_without_banking_law":
            payload.enterprise_investment_firm_without_banking_law,
        "crm_exists": metrics["effective_coverage"] > 0.0 or crm_details["mode"] != "Aucune",
        "crm_type": payload.crm_type,
        "crm_mode": crm_details["mode"],
        "crm_label": crm_details["label"],
        "crm_coverage_percent": metrics["effective_coverage"],
        "crm_details": crm_details,
        "guarantor_rw": metrics["guarantor_rw"],
        "original_rw": metrics["original_rw"],
        "final_rw": metrics["final_rw"],
        "ead": metrics["ead"],
        "rwa": metrics["rwa"],
        "capital": metrics["capital"],
        "comment": payload.comment,
    }


def exposure_record_to_view(record: dict[str, Any]) -> ExposureView:
    crm_details = record.get("crm_details", {})
    category_label = (
        record.get("category_raw") or record.get("category_standard") or "Entreprises"
    )
    category = resolve_category(str(category_label))
    counterparty = Counterparty(
        id=record["id"],
        name=record["counterparty_name"],
        country=record["country"],
        country_rating=record.get("country_rating", "Non noté"),
        category=category_label,
        rating=record["rating"],
    )
    return ExposureView(
        id=record["id"],
        analysis_date=record["analysis_date"],
        grant_date=record.get("grant_date"),
        maturity_date=record.get("maturity_date"),
        counterparty=counterparty,
        gross_amount=record["gross_amount"],
        currency=record.get("currency", "XOF"),
        status=record.get("status", "Active"),
        sovereign_special_case=normalize_sovereign_special_case(
            str(record.get("sovereign_special_case") or ""),
            fallback_to_legacy=bool(
                record.get("sovereign_preferential_zero_weight", False)
            ),
        ),
        sovereign_preferential_zero_weight=bool(
            record.get("sovereign_preferential_zero_weight", False)
        ),
        sovereign_oce_established=bool(record.get("sovereign_oce_established", False)),
        sovereign_oce_note=str(record.get("sovereign_oce_note") or ""),
        public_body_uemoa_fcfa_case=record.get("public_body_uemoa_fcfa_case"),
        public_body_non_public_activity=record.get("public_body_non_public_activity"),
        bmd_high_quality_case=record.get("bmd_high_quality_case"),
        bmd_uemoa_fcfa_case=record.get("bmd_uemoa_fcfa_case"),
        bmd_uemoa_criteria_satisfied=record.get("bmd_uemoa_criteria_satisfied"),
        bmd_listed_institution_fcfa_case=record.get("bmd_listed_institution_fcfa_case"),
        bank_institution_case=coerce_bank_institution_case(
            record.get("bank_institution_case")
        ),
        other_asset_type=record.get("other_asset_type"),
        off_balance_risk_level=coerce_off_balance_risk_level(
            record.get("off_balance_risk_level"),
            fallback_to_very_high=category["code"] == "l",
            factor_hint=float(record.get("final_rw", 0.0) or 0.0),
        ),
        retail_eligibility_criteria_satisfied=record.get(
            "retail_eligibility_criteria_satisfied"
        ),
        residential_mortgage_eligible=record.get(
            "residential_mortgage_eligible"
        ),
        commercial_real_estate_eligible=record.get(
            "commercial_real_estate_eligible"
        ),
        defaulted_exposure_initial_risk_weight=record.get(
            "defaulted_exposure_initial_risk_weight"
        ),
        defaulted_exposure_residential_mortgage_in_default=record.get(
            "defaulted_exposure_residential_mortgage_in_default"
        ),
        defaulted_exposure_provision_at_least_twenty_percent=record.get(
            "defaulted_exposure_provision_at_least_twenty_percent"
        ),
        enterprise_exceeds_bceao_degradation_threshold=record.get(
            "enterprise_exceeds_bceao_degradation_threshold"
        ),
        enterprise_prudential_procedure=record.get(
            "enterprise_prudential_procedure"
        ),
        enterprise_investment_firm_without_banking_law=record.get(
            "enterprise_investment_firm_without_banking_law"
        ),
        crm_type=record["crm_type"],
        crm_coverage_percent=record.get("crm_coverage_percent", 0.0),
        crm_details=ExposureCrmDetails(**crm_details),
        original_rw=record["original_rw"],
        final_rw=record["final_rw"],
        ead=record["ead"],
        rwa=record["rwa"],
        capital=record["capital"],
        comment=record.get("comment"),
    )


def view_to_exposure_record(view: ExposureView) -> dict[str, Any]:
    category = resolve_category(view.counterparty.category)
    crm_details = model_dump(view.crm_details)
    return {
        "id": view.id,
        "analysis_date": view.analysis_date,
        "grant_date": view.grant_date,
        "maturity_date": view.maturity_date,
        "counterparty_name": view.counterparty.name,
        "country": view.counterparty.country,
        "country_rating": view.counterparty.country_rating,
        "category_raw": category["prudential"],
        "category_dashboard": category["legacy"],
        "category_standard": category["legacy"],
        "rating": view.counterparty.rating,
        "gross_amount": view.gross_amount,
        "currency": view.currency,
        "status": view.status,
        "sovereign_special_case": view.sovereign_special_case,
        "sovereign_preferential_zero_weight": view.sovereign_preferential_zero_weight,
        "sovereign_oce_established": view.sovereign_oce_established,
        "sovereign_oce_note": view.sovereign_oce_note,
        "public_body_uemoa_fcfa_case": view.public_body_uemoa_fcfa_case,
        "public_body_non_public_activity": view.public_body_non_public_activity,
        "bmd_high_quality_case": view.bmd_high_quality_case,
        "bmd_uemoa_fcfa_case": view.bmd_uemoa_fcfa_case,
        "bmd_uemoa_criteria_satisfied": view.bmd_uemoa_criteria_satisfied,
        "bmd_listed_institution_fcfa_case": view.bmd_listed_institution_fcfa_case,
        "bank_institution_case": coerce_bank_institution_case(
            view.bank_institution_case
        ),
        "other_asset_type": view.other_asset_type,
        "off_balance_risk_level": coerce_off_balance_risk_level(
            view.off_balance_risk_level,
            fallback_to_very_high=category["code"] == "l",
            factor_hint=view.final_rw,
        ),
        "retail_eligibility_criteria_satisfied":
            view.retail_eligibility_criteria_satisfied,
        "residential_mortgage_eligible": view.residential_mortgage_eligible,
        "commercial_real_estate_eligible":
            view.commercial_real_estate_eligible,
        "defaulted_exposure_initial_risk_weight":
            view.defaulted_exposure_initial_risk_weight,
        "defaulted_exposure_residential_mortgage_in_default":
            view.defaulted_exposure_residential_mortgage_in_default,
        "defaulted_exposure_provision_at_least_twenty_percent":
            view.defaulted_exposure_provision_at_least_twenty_percent,
        "enterprise_exceeds_bceao_degradation_threshold":
            view.enterprise_exceeds_bceao_degradation_threshold,
        "enterprise_prudential_procedure": view.enterprise_prudential_procedure,
        "enterprise_investment_firm_without_banking_law":
            view.enterprise_investment_firm_without_banking_law,
        "crm_exists": view.crm_coverage_percent > 0.0 or crm_details.get("mode") != "Aucune",
        "crm_type": view.crm_type,
        "crm_mode": crm_details.get("mode") or crm_mode_from_type(view.crm_type),
        "crm_label": crm_details.get("label") or view.crm_type,
        "crm_coverage_percent": view.crm_coverage_percent,
        "crm_details": crm_details,
        "guarantor_rw": lookup_prudential_risk_weight(
            resolve_category(str(crm_details.get("guarantor_category") or "Souverains"))["code"],
            str(crm_details.get("guarantor_rating") or view.counterparty.rating),
        )
        if crm_details.get("mode") == "CRM non financee"
        else 0.0,
        "original_rw": view.original_rw,
        "final_rw": view.final_rw,
        "ead": view.ead,
        "rwa": view.rwa,
        "capital": view.capital,
        "comment": view.comment,
    }
