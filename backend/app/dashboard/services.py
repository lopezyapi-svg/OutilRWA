"""Services metier du module dashboard."""

from __future__ import annotations

from collections import defaultdict
from datetime import date
import math
import unicodedata

from app.core.calculations import convert_currency_amount, safe_ratio
from app.dashboard.models import (
    DashboardMetric,
    DashboardProjectionPoint,
    DashboardSnapshot,
    DistributionEntry,
    PortfolioRow,
)
from app.expositions.models import ExposureView
from app.expositions.services import list_expositions
from database.services.rwa_calculation_service import (
    normalize_exposure_category_label,
    normalize_exposure_crm_mode,
    normalize_exposure_rating_label,
)


_MONTH_LABELS = [
    "Janv.",
    "Fevr.",
    "Mars",
    "Avr.",
    "Mai",
    "Juin",
    "Juil.",
    "Aout",
    "Sept.",
    "Oct.",
    "Nov.",
    "Dec.",
]

_TOP5_FALLBACK_COUNTRIES = [
    "Côte d'Ivoire",
    "Sénégal",
    "Bénin",
    "Togo",
    "Burkina Faso",
    "Mali",
    "Niger",
    "Guinée-Bissau",
]

_CRM_BUCKET_ORDER = (
    "CRM financee",
    "CRM non financee",
    "Aucune",
)
_DISPLAY_CURRENCY = "XOF"


def _build_metric(key: str, label: str, value: float) -> DashboardMetric:
    trend = [round(value, 2) for _ in range(7)]
    return DashboardMetric(
        key=key,
        label=label,
        value=round(value, 2),
        variation="+0.0% M/M",
        trend=trend,
    )


def _build_distribution_from_buckets(
    buckets: dict[str, float],
    ordered_labels: tuple[str, ...] | None = None,
) -> list[DistributionEntry]:
    total = sum(buckets.values())
    entries = [
        DistributionEntry(
            label=label,
            amount=round(amount, 2),
            percentage=safe_ratio(amount, total),
        )
        for label, amount in buckets.items()
    ]
    entries.sort(key=lambda item: item.amount, reverse=True)

    if ordered_labels is None:
        return entries

    ordered_lookup = {entry.label: entry for entry in entries}
    return [
        ordered_lookup.get(
            label,
            DistributionEntry(label=label, amount=0.0, percentage=0.0),
        )
        for label in ordered_labels
    ]


def _normalize_row(row: ExposureView) -> dict[str, object]:
    on_balance_source = (
        row.on_balance_exposure_amount
        if row.on_balance_exposure_amount is not None
        else row.gross_amount
    )
    off_balance_source = row.off_balance_exposure_amount or 0.0
    has_exposure_breakdown = (
        row.on_balance_exposure_amount is not None
        or row.off_balance_exposure_amount is not None
    )
    if has_exposure_breakdown:
        gross_source = on_balance_source + off_balance_source
    elif row.loan_total_amount is not None and row.loan_total_amount > 0:
        gross_source = row.loan_total_amount
    else:
        gross_source = row.gross_amount
    gross_amount = convert_currency_amount(
        gross_source,
        from_currency=row.currency,
        to_currency=_DISPLAY_CURRENCY,
    )
    on_balance_amount = convert_currency_amount(
        on_balance_source,
        from_currency=row.currency,
        to_currency=_DISPLAY_CURRENCY,
    )
    off_balance_amount = convert_currency_amount(
        off_balance_source,
        from_currency=row.currency,
        to_currency=_DISPLAY_CURRENCY,
    )
    ead = convert_currency_amount(
        row.ead,
        from_currency=row.currency,
        to_currency=_DISPLAY_CURRENCY,
    )
    rwa = convert_currency_amount(
        row.rwa,
        from_currency=row.currency,
        to_currency=_DISPLAY_CURRENCY,
    )
    capital = convert_currency_amount(
        row.capital,
        from_currency=row.currency,
        to_currency=_DISPLAY_CURRENCY,
    )
    return {
        "row": row,
        "category": normalize_exposure_category_label(row.counterparty.category),
        "rating": normalize_exposure_rating_label(row.counterparty.rating),
        "crm_mode": normalize_exposure_crm_mode(row.crm_type, row.crm_details),
        "gross_amount": gross_amount,
        "on_balance_exposure_amount": on_balance_amount,
        "off_balance_exposure_amount": off_balance_amount,
        "ead": ead,
        "rwa": rwa,
        "capital": capital,
    }


def _text_key(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return normalized.encode("ascii", "ignore").decode("ascii").lower()


def _country_key(value: str) -> str:
    return _text_key(value).replace("'", " ").replace("-", " ").strip()


def _canonical_country_label(value: str) -> str:
    aliases = {
        "cote d ivoire": "Côte d'Ivoire",
        "senegal": "Sénégal",
        "benin": "Bénin",
        "guinee bissau": "Guinée-Bissau",
        "guinee equatoriale": "Guinée équatoriale",
    }
    normalized = " ".join(_country_key(value).split())
    return aliases.get(normalized, value.strip())


def _is_defaulted_exposure(row: ExposureView, category: str) -> bool:
    status_key = _text_key(row.status)
    category_key = _text_key(category)
    raw_category_key = _text_key(row.counterparty.category)
    return (
        "defaut" in status_key
        or "defaut" in category_key
        or "souffrance" in category_key
        or "defaut" in raw_category_key
        or "souffrance" in raw_category_key
    )


def _build_country_distribution(buckets: dict[str, float]) -> list[DistributionEntry]:
    total = sum(buckets.values())
    entries = sorted(
        [
            DistributionEntry(
                label=country,
                amount=round(amount, 2),
                percentage=safe_ratio(amount, total),
            )
            for country, amount in buckets.items()
        ],
        key=lambda item: item.amount,
        reverse=True,
    )
    top = entries[:5]
    existing = {item.label for item in top}
    for candidate in _TOP5_FALLBACK_COUNTRIES:
        if len(top) >= 5:
            break
        if candidate in existing:
            continue
        top.append(DistributionEntry(label=candidate, amount=0.0, percentage=0.0))
    return top


def _build_projection(valuation_date: date, base_rwa: float) -> list[DashboardProjectionPoint]:
    points: list[DashboardProjectionPoint] = []
    for month_index in range(12):
        point_month = valuation_date.month + month_index + 1
        year_shift = (point_month - 1) // 12
        month = ((point_month - 1) % 12) + 1
        _ = valuation_date.year + year_shift
        ratio = max(0.0, 1 - (month_index * 0.045))
        projected = round(base_rwa * ratio, 2)
        points.append(
            DashboardProjectionPoint(
                label=_MONTH_LABELS[month - 1],
                value=projected,
            )
        )
    return points


def _max_grouped_share(
    exposure_rows: list[dict[str, object]],
    total: float,
    *,
    key_name: str,
    amount_name: str,
) -> float:
    if total <= 0:
        return 0.0

    buckets: dict[str, float] = defaultdict(float)
    for item in exposure_rows:
        key_value = item.get(key_name)
        if key_name == "counterparty":
            row = item["row"]
            key_value = row.counterparty.name
        elif key_name == "category":
            key_value = item["category"]
        buckets[str(key_value or "Non renseigne")] += float(item[amount_name])

    return max(buckets.values(), default=0.0) / total


def _portfolio_value_at_risk(
    exposure_rows: list[dict[str, object]],
    *,
    gross_total: float,
    rwa_total: float,
) -> float:
    if not exposure_rows or rwa_total <= 0:
        return 0.0

    densities = [
        float(row["rwa"]) / float(row["ead"])
        for row in exposure_rows
        if float(row["ead"]) > 0
    ]
    average_density = safe_ratio(rwa_total, gross_total)
    density_mean = (
        sum(densities) / len(densities)
        if densities
        else average_density
    )
    density_variance = (
        sum((density - density_mean) ** 2 for density in densities) / len(densities)
        if densities
        else 0.0
    )
    concentration_share = _max_grouped_share(
        exposure_rows,
        rwa_total,
        key_name="counterparty",
        amount_name="rwa",
    )
    volatility_proxy = min(
        max(
            math.sqrt(density_variance) * 0.45
            + average_density * 0.035
            + concentration_share * 0.08,
            0.006,
        ),
        0.16,
    )
    return rwa_total * volatility_proxy * 1.65


def _critical_incident_count(
    exposure_rows: list[dict[str, object]],
    *,
    default_rate: float,
    gross_total: float,
    rwa_total: float,
) -> int:
    if not exposure_rows:
        return 0

    incidents = 0
    counterparty_share = _max_grouped_share(
        exposure_rows,
        gross_total,
        key_name="counterparty",
        amount_name="gross_amount",
    )
    category_share = _max_grouped_share(
        exposure_rows,
        rwa_total,
        key_name="category",
        amount_name="rwa",
    )
    has_very_high_density = any(
        float(row["ead"]) > 0 and float(row["rwa"]) / float(row["ead"]) >= 1.5
        for row in exposure_rows
    )
    has_uncovered_large_risk = any(
        rwa_total > 0
        and float(row["rwa"]) / rwa_total >= 0.18
        and str(row["crm_mode"]).strip().lower() in {"", "aucune", "none"}
        for row in exposure_rows
    )

    if default_rate >= 0.05:
        incidents += 1
    if counterparty_share >= 0.35:
        incidents += 1
    if category_share >= 0.50:
        incidents += 1
    if has_very_high_density:
        incidents += 1
    if has_uncovered_large_risk:
        incidents += 1

    return incidents


def get_dashboard_snapshot() -> DashboardSnapshot:
    """Construit le contenu complet du tableau de bord.

    Entree:
        Aucune.
    Sortie:
        Les KPI, graphiques et apercu portefeuille.
    """

    exposure_rows = [_normalize_row(item) for item in list_expositions()]

    gross_total = sum(float(row["gross_amount"]) for row in exposure_rows)
    ead_total = sum(float(row["ead"]) for row in exposure_rows)
    rwa_total = sum(float(row["rwa"]) for row in exposure_rows)
    capital_total = sum(float(row["capital"]) for row in exposure_rows)
    risk_ratio = safe_ratio(rwa_total, gross_total if gross_total > 0 else ead_total)
    default_gross_total = sum(
        float(row["gross_amount"])
        for row in exposure_rows
        if _is_defaulted_exposure(row["row"], str(row["category"]))
    )
    default_rate = safe_ratio(default_gross_total, gross_total)
    solvency_ratio = safe_ratio(capital_total * 1.35, rwa_total)
    crm_gross = sum(
        float(row["gross_amount"]) * row["row"].crm_coverage_percent
        for row in exposure_rows
        if row["crm_mode"] != "Aucune"
    )
    residual_risk = max(gross_total - crm_gross, 0.0)
    covered_ratio = safe_ratio(crm_gross, gross_total)

    portfolio_rows = [
        PortfolioRow(
            id=row["row"].id,
            analysis_date=row["row"].analysis_date.isoformat(),
            counterparty=row["row"].counterparty.name,
            country=row["row"].counterparty.country,
            category=row["category"],
            rating=row["rating"],
            crm_type=row["crm_mode"],
            gross_amount=round(float(row["gross_amount"]), 2),
            on_balance_exposure_amount=round(
                float(row["on_balance_exposure_amount"]),
                2,
            ),
            off_balance_exposure_amount=round(
                float(row["off_balance_exposure_amount"]),
                2,
            ),
            ead=round(float(row["ead"]), 2),
            rwa=round(float(row["rwa"]), 2),
            capital=round(float(row["capital"]), 2),
        )
        for row in exposure_rows
    ]

    category_buckets: dict[str, float] = defaultdict(float)
    rwa_category_buckets: dict[str, float] = defaultdict(float)
    country_buckets: dict[str, float] = defaultdict(float)
    crm_buckets: dict[str, float] = defaultdict(float)
    rating_buckets: dict[str, float] = defaultdict(float)
    for item in exposure_rows:
        row = item["row"]
        category = str(item["category"])
        rating = str(item["rating"])
        crm_mode = str(item["crm_mode"])
        category_buckets[category] += float(item["gross_amount"])
        rwa_category_buckets[category] += float(item["rwa"])
        country_buckets[_canonical_country_label(row.counterparty.country)] += float(item["rwa"])
        crm_buckets[crm_mode] += float(item["gross_amount"])
        rating_buckets[rating] += float(item["gross_amount"])

    category_distribution = _build_distribution_from_buckets(category_buckets)
    rwa_category_distribution = _build_distribution_from_buckets(rwa_category_buckets)
    crm_distribution = _build_distribution_from_buckets(crm_buckets, ordered_labels=_CRM_BUCKET_ORDER)
    rating_distribution = _build_distribution_from_buckets(rating_buckets)

    valuation_date = max((row["row"].analysis_date for row in exposure_rows), default=date.today())
    projection_base = rwa_total
    value_at_risk = _portfolio_value_at_risk(
        exposure_rows,
        gross_total=gross_total,
        rwa_total=rwa_total,
    )
    critical_incidents = _critical_incident_count(
        exposure_rows,
        default_rate=default_rate,
        gross_total=gross_total,
        rwa_total=rwa_total,
    )
    concentration_max = _max_grouped_share(
        exposure_rows,
        gross_total,
        key_name="counterparty",
        amount_name="gross_amount",
    )
    metrics = [
        _build_metric("encours", "Exposition totale brute", gross_total),
        _build_metric("risque_residuel", "Risque residuel", residual_risk),
        _build_metric("rwa", "RWA", rwa_total),
        _build_metric("capital", "Capital", capital_total),
        _build_metric("taux_risque", "Taux de risque", risk_ratio),
        _build_metric("taux_defaut", "Taux de defaut", default_rate),
        _build_metric("solvabilite", "Solvabilite", solvency_ratio),
        _build_metric("crm", "Couverture CRM", covered_ratio),
        _build_metric("value_at_risk", "VaR globale", value_at_risk),
        _build_metric(
            "incidents_critiques",
            "Incidents critiques",
            float(critical_incidents),
        ),
        _build_metric(
            "concentration_max",
            "Concentration max",
            concentration_max,
        ),
    ]

    return DashboardSnapshot(
        metrics=metrics,
        valuation_date=valuation_date.isoformat(),
        category_distribution=category_distribution,
        rwa_category_distribution=rwa_category_distribution,
        country_distribution=_build_country_distribution(country_buckets),
        crm_distribution=crm_distribution,
        rating_distribution=rating_distribution,
        rwa_projection=_build_projection(valuation_date, projection_base),
        portfolio_overview=portfolio_rows,
    )
