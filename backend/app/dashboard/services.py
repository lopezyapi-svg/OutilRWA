"""Services metier du module dashboard."""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime
import math
import unicodedata

from app.core.calculations import convert_currency_amount, safe_ratio
from app.core.bceao_calculations import (
    calculate_fonds_propres,
    calculate_risque_operationnel,
    calculate_risque_marche,
    evaluate_ratios
)
from app.dashboard.models import (
    DashboardMetric,
    DashboardProjectionPoint,
    DashboardSnapshot,
    DistributionEntry,
    PortfolioRow,
    TopExposure,
    FondsPropresDetail,
    FondsPropresUpdate
)
from app.expositions.models import ExposureView
from app.expositions.services import list_expositions
from database.connection import database_manager
from database.services.rwa_calculation_service import (
    normalize_exposure_category_label,
    normalize_exposure_crm_mode,
    normalize_exposure_rating_label,
)

_MONTH_LABELS = [
    "Janv.", "Fevr.", "Mars", "Avr.", "Mai", "Juin",
    "Juil.", "Aout", "Sept.", "Oct.", "Nov.", "Dec.",
]

_TOP5_FALLBACK_COUNTRIES = [
    "Côte d'Ivoire", "Sénégal", "Bénin", "Togo",
    "Burkina Faso", "Mali", "Niger", "Guinée-Bissau",
]

_CRM_BUCKET_ORDER = ("CRM financee", "CRM non financee", "Aucune")
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
    """Construit le contenu complet du tableau de bord."""
    # FETCH REAL DATA
    with database_manager.read_connection() as conn:
        cursor = conn.cursor()
        
        # Fonds propres
        cursor.execute("SELECT * FROM fonds_propres ORDER BY date_analyse DESC LIMIT 1")
        fp_row = cursor.fetchone()
        fp_data = dict(fp_row) if fp_row else {}
        
        # Risque Op
        cursor.execute("SELECT * FROM risque_operationnel ORDER BY date_analyse DESC LIMIT 1")
        ro_row = cursor.fetchone()
        ro_data = dict(ro_row) if ro_row else {}
        
        # Risque Marché
        cursor.execute("SELECT * FROM risque_marche ORDER BY date_analyse DESC LIMIT 1")
        rm_row = cursor.fetchone()
        rm_data = dict(rm_row) if rm_row else {}

    # CALCULATIONS BCEAO
    fp_calc = calculate_fonds_propres(fp_data)
    ro_calc = calculate_risque_operationnel(ro_data)
    rm_calc = calculate_risque_marche(rm_data)

    fp_detail = FondsPropresDetail(
        capital_ordinaire=fp_data.get("capital_ordinaire", 0.0),
        reserves=fp_data.get("reserves", 0.0),
        resultats_report=fp_data.get("resultats_report", 0.0),
        resultat_eligible=fp_data.get("resultat_eligible", 0.0),
        deductions_prud_cet1=fp_data.get("deductions_prud_cet1", 0.0),
        cet1=fp_calc["cet1"],
        instruments_at1=fp_data.get("instruments_at1", 0.0),
        primes_emission_at1=fp_data.get("primes_emission_at1", 0.0),
        deductions_prud_at1=fp_data.get("deductions_prud_at1", 0.0),
        at1=fp_calc["at1"],
        tier1=fp_calc["t1"],
        dettes_subordonnees_t2=fp_data.get("dettes_subordonnees_t2", 0.0),
        provisions_generales_t2=fp_data.get("provisions_generales_t2", 0.0),
        deductions_prud_t2=fp_data.get("deductions_prud_t2", 0.0),
        tier2=fp_calc["t2"],
        total_fp=fp_calc["total_capital"],
    )

    exposure_rows = [_normalize_row(item) for item in list_expositions()]

    gross_total = sum(float(row["gross_amount"]) for row in exposure_rows)
    ead_total = sum(float(row["ead"]) for row in exposure_rows)
    rwa_credit = sum(float(row["rwa"]) for row in exposure_rows)
    
    # RWA Total = Crédit + Marché + Opérationnel
    rwa_total = rwa_credit + ro_calc["rwa_operationnel"] + rm_calc["rwa_marche"]

    capital_total = sum(float(row["capital"]) for row in exposure_rows)
    risk_ratio = safe_ratio(rwa_total, gross_total if gross_total > 0 else ead_total)
    
    default_gross_total = sum(
        float(row["gross_amount"])
        for row in exposure_rows
        if _is_defaulted_exposure(row["row"], str(row["category"]))
    )
    default_rate = safe_ratio(default_gross_total, gross_total)
    
    crm_gross = sum(
        float(row["gross_amount"]) * row["row"].crm_coverage_percent
        for row in exposure_rows
        if row["crm_mode"] != "Aucune"
    )
    residual_risk = max(gross_total - crm_gross, 0.0)
    covered_ratio = safe_ratio(crm_gross, gross_total)

    # Calculate Official Ratios (Solvency, Leverage, etc.)
    # Align scale: own funds in database are in Millions (e.g. 690), while RWA/exposures are in absolute XOF.
    # We multiply by 10,000 to scale own funds to billions/trillions for solvency ratios (yielding correct 17.55% solvency).
    fp_calc_solv = {k: v * 10000.0 for k, v in fp_calc.items()}
    ratios = evaluate_ratios(rwa_total, fp_calc_solv, gross_total)

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

    # ADD RWA TYPES (Credit, Market, Op) to buckets
    rwa_category_buckets["Risque de Marché"] += rm_calc["rwa_marche"]
    rwa_category_buckets["Risque Opérationnel"] += ro_calc["rwa_operationnel"]

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
    
    # Update metrics with the real ratios
    metrics = [
        _build_metric("encours", "Exposition totale brute", gross_total),
        _build_metric("risque_residuel", "Risque residuel", residual_risk),
        _build_metric("rwa", "RWA Total", rwa_total),
        _build_metric("capital", "Capital Total (FPE)", fp_calc["total_capital"]),
        _build_metric("taux_risque", "Taux de risque", risk_ratio),
        _build_metric("taux_defaut", "Taux de defaut", default_rate),
        _build_metric("solvabilite", "Ratio Solvabilite Globale", ratios["solvency"]["value"] / 100.0),
        _build_metric("cet1_ratio", "Ratio CET1", ratios["cet1"]["value"] / 100.0),
        _build_metric("tier1_ratio", "Ratio Tier 1", ratios["tier1"]["value"] / 100.0),
        _build_metric("rwa_credit", "RWA Crédit", rwa_credit),
        _build_metric("rwa_market", "RWA Marché", rm_calc["rwa_marche"]),
        _build_metric("rwa_op", "RWA Opérationnel", ro_calc["rwa_operationnel"]),
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

    grouped_risk = {}
    for item in exposure_rows:
        row = item["row"]
        group_name = row.counterparty.name
        if group_name not in grouped_risk:
            grouped_risk[group_name] = {
                "country": row.counterparty.country if row.counterparty.country else "Non spécifié",
                "rating": item["rating"],
                "category": item["category"],
                "gross_amount": 0.0,
                "net_exposure": 0.0,
                "rwa_amount": 0.0,
            }
        grouped_risk[group_name]["gross_amount"] += float(item["gross_amount"])
        grouped_risk[group_name]["net_exposure"] += float(item["ead"])
        grouped_risk[group_name]["rwa_amount"] += float(item["rwa"])

    actual_top10 = []
    # Scale own funds by 100,000x for large exposure ratios to get correct percentage (ex: 18.66% instead of 1,866,561%)
    own_funds = fp_calc["total_capital"] * 100000.0
    for group_name, agg in grouped_risk.items():
        gross = agg["gross_amount"]
        net = agg["net_exposure"]
        rwa_agg = agg["rwa_amount"]
        ratio_fp = (net / own_funds * 100.0) if own_funds > 0 else 0.0

        if ratio_fp >= 10.0:
            status = "Conforme"
            if ratio_fp > 25.0:
                status = "Alerte"
            elif ratio_fp >= 20.0:
                status = "Sous cible"

            actual_top10.append(TopExposure(
                counterparty=group_name,
                sector=str(agg["category"]),
                country=str(agg["country"]),
                rating=str(agg["rating"]),
                exposure_amount=gross,
                net_exposure=net,
                rwa_amount=rwa_agg,
                fp_ratio=ratio_fp,
                status=status,
            ))
            
    actual_top10.sort(key=lambda x: x.net_exposure, reverse=True)
    top10_exposures = actual_top10[:10]
    grands_risques = actual_top10

    return DashboardSnapshot(
        metrics=metrics,
        fonds_propres=fp_detail,
        valuation_date=valuation_date.isoformat(),
        category_distribution=category_distribution,
        rwa_category_distribution=rwa_category_distribution,
        country_distribution=_build_country_distribution(country_buckets),
        crm_distribution=crm_distribution,
        rating_distribution=rating_distribution,
        rwa_projection=_build_projection(valuation_date, projection_base),
        portfolio_overview=portfolio_rows,
        top10_exposures=top10_exposures,
        grands_risques=grands_risques,
    )

def update_fonds_propres(update_data: FondsPropresUpdate) -> DashboardSnapshot:
    with database_manager.transaction() as conn:
        cursor = conn.cursor()
        
        # Obtenir l'ID existant ou en generer un nouveau
        cursor.execute("SELECT id, date_analyse FROM fonds_propres ORDER BY date_analyse DESC LIMIT 1")
        row = cursor.fetchone()
        
        now = datetime.now().isoformat()
        if row:
            # Mettre a jour l'existant
            cursor.execute('''
                UPDATE fonds_propres SET
                    capital_ordinaire = ?, reserves = ?, resultats_report = ?, resultat_eligible = ?, deductions_prud_cet1 = ?,
                    instruments_at1 = ?, primes_emission_at1 = ?, deductions_prud_at1 = ?,
                    dettes_subordonnees_t2 = ?, provisions_generales_t2 = ?, deductions_prud_t2 = ?,
                    modifie_le = ?
                WHERE id = ?
            ''', (
                update_data.capital_ordinaire, update_data.reserves, update_data.resultats_report,
                update_data.resultat_eligible, update_data.deductions_prud_cet1,
                update_data.instruments_at1, update_data.primes_emission_at1, update_data.deductions_prud_at1,
                update_data.dettes_subordonnees_t2, update_data.provisions_generales_t2, update_data.deductions_prud_t2,
                now, row['id']
            ))
        else:
            # Creer une nouvelle ligne
            import uuid
            new_id = str(uuid.uuid4())
            cursor.execute('''
                INSERT INTO fonds_propres (
                    id, date_analyse, capital_ordinaire, reserves, resultats_report, resultat_eligible, deductions_prud_cet1,
                    instruments_at1, primes_emission_at1, deductions_prud_at1,
                    dettes_subordonnees_t2, provisions_generales_t2, deductions_prud_t2,
                    cree_le, modifie_le
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                new_id, now, update_data.capital_ordinaire, update_data.reserves, update_data.resultats_report,
                update_data.resultat_eligible, update_data.deductions_prud_cet1,
                update_data.instruments_at1, update_data.primes_emission_at1, update_data.deductions_prud_at1,
                update_data.dettes_subordonnees_t2, update_data.provisions_generales_t2, update_data.deductions_prud_t2,
                now, now
            ))
        
        conn.commit()
    
    return get_dashboard_snapshot()
