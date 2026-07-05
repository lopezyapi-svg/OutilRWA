"""Routes marche pour l'actualisation des courbes de taux."""

from __future__ import annotations

import base64
import json
import re
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from fastapi import APIRouter, HTTPException, status

from app.core.config import settings
from database.connection import database_manager, utcnow_iso

router = APIRouter(prefix="/market", tags=["Market"])

_MARKET_PORTFOLIOS_PAYLOAD_KEY = "market_portfolios_payload_v1"
_MARKET_PORTFOLIOS_SAVED_AT_KEY = "market_portfolios_saved_at"
_BEAC_PAGE_URL = "https://www.beac.int/economie-stats/statistiques-titres-publics/"
_BEAC_COUNTRY_PDF_URLS = {
    "Cameroun": (
        "https://www.beac.int/wp-content/uploads/2016/10/"
        "Courbe-des-taux-de-rendement-des-titres-publics-Camerounais-mars-26.pdf"
    ),
    "Congo": (
        "https://www.beac.int/wp-content/uploads/2016/10/"
        "Courbe-des-taux-de-rendement-des-titres-publics-Congolais-mars-26.pdf"
    ),
    "Gabon": (
        "https://www.beac.int/wp-content/uploads/2016/10/"
        "Courbe-des-taux-de-rendement-des-titres-publics-Gabonais-mars-26.pdf"
    ),
}
_BEAC_COUNTRY_URL_TOKENS = {
    "Cameroun": ("cameroun", "camerounais"),
    "Congo": ("congo", "congolais"),
    "Gabon": ("gabon", "gabonais"),
}
_CEMAC_MARCH_2026_EXACT_CURVES = {
    "Cameroun": [
        ("3 mois", 0.25, 6.31),
        ("6 mois", 0.5, 7.16),
        ("1 an", 1, 8.32),
        ("1,5 ans", 1.5, 9.00),
        ("2 ans", 2, 9.41),
        ("3 ans", 3, 9.79),
        ("3,5 ans", 3.5, 9.88),
        ("4 ans", 4, 9.92),
        ("5 ans", 5, 9.97),
        ("6 ans", 6, 9.98),
        ("7 ans", 7, 9.99),
        ("8 ans", 8, 9.99),
        ("9 ans", 9, 9.98),
        ("10 ans", 10, 9.98),
        ("11 ans", 11, 9.98),
        ("12 ans", 12, 9.98),
        ("13 ans", 13, 9.98),
        ("14 ans", 14, 9.98),
        ("15 ans", 15, 9.98),
    ],
    "Congo": [
        ("3 mois", 0.25, 6.64),
        ("6 mois", 0.5, 7.67),
        ("1 an", 1, 9.09),
        ("1,5 ans", 1.5, 9.96),
        ("2 ans", 2, 10.49),
        ("3 ans", 3, 11.03),
        ("3,5 ans", 3.5, 11.17),
        ("4 ans", 4, 11.25),
        ("5 ans", 5, 11.35),
        ("6 ans", 6, 11.40),
        ("7 ans", 7, 11.43),
        ("8 ans", 8, 11.45),
        ("9 ans", 9, 11.46),
        ("10 ans", 10, 11.47),
    ],
    "Gabon": [
        ("3 mois", 0.25, 6.12),
        ("6 mois", 0.5, 7.18),
        ("1 an", 1, 8.21),
        ("1,5 ans", 1.5, 8.38),
        ("2 ans", 2, 8.13),
        ("3 ans", 3, 7.19),
        ("3,5 ans", 3.5, 6.70),
        ("4 ans", 4, 6.24),
        ("5 ans", 5, 5.47),
        ("6 ans", 6, 4.88),
        ("7 ans", 7, 4.42),
        ("8 ans", 8, 4.07),
        ("9 ans", 9, 3.79),
        ("10 ans", 10, 3.57),
    ],
}
_GEMINI_ENDPOINT_TEMPLATE = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)
_CEMAC_COUNTRIES = {
    "cameroun": "Cameroun",
    "republique centrafricaine": "République Centrafricaine",
    "centrafrique": "République Centrafricaine",
    "congo": "Congo",
    "gabon": "Gabon",
    "guinee equatoriale": "Guinée équatoriale",
    "tchad": "Tchad",
}
_HTTP_HEADERS = {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"
    ),
}


@router.get("/portfolios")
def get_market_portfolios() -> dict[str, Any]:
    """Retourne le portefeuille marché persistant depuis SQLite local."""

    with database_manager.read_connection() as connection:
        row = connection.execute(
            "SELECT valeur AS value FROM metadonnees_app WHERE cle = ?",
            (_MARKET_PORTFOLIOS_PAYLOAD_KEY,),
        ).fetchone()

    if row is None or not str(row["value"] or "").strip():
        return {
            "storage_backend": "sqlite",
            "empty": True,
            "payload": None,
        }

    try:
        payload = json.loads(str(row["value"]))
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": "MARKET_PORTFOLIO_SQL_PAYLOAD_INVALID",
                "message": "Le portefeuille marché stocké en SQLite est illisible.",
            },
        ) from exc

    return {
        "storage_backend": "sqlite",
        "empty": False,
        "payload": payload,
    }


@router.put("/portfolios")
def save_market_portfolios(body: dict[str, Any]) -> dict[str, Any]:
    """Persiste le portefeuille marché dans SQLite local."""

    payload = body.get("payload")
    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "MARKET_PORTFOLIO_PAYLOAD_INVALID",
                "message": "Payload portefeuille marché invalide.",
            },
        )

    encoded_payload = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    saved_at = utcnow_iso()

    with database_manager.transaction() as connection:
        connection.execute(
            """
            INSERT INTO metadonnees_app(cle, valeur)
            VALUES (?, ?)
            ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
            """,
            (_MARKET_PORTFOLIOS_PAYLOAD_KEY, encoded_payload),
        )
        connection.execute(
            """
            INSERT INTO metadonnees_app(cle, valeur)
            VALUES (?, ?)
            ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
            """,
            (_MARKET_PORTFOLIOS_SAVED_AT_KEY, saved_at),
        )
        connection.execute(
            """
            INSERT INTO metadonnees_app(cle, valeur)
            VALUES (?, ?)
            ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
            """,
            ("market_storage_backend", "sqlite"),
        )

    return {
        "status": "ok",
        "storage_backend": "sqlite",
        "saved_at": saved_at,
    }


@router.post("/portfolios")
def save_market_portfolios_compat(body: dict[str, Any]) -> dict[str, Any]:
    """Alias POST pour les clients qui n'exposent pas PUT."""

    return save_market_portfolios(body)


@router.post("/yield-curves/cemac/refresh")
def refresh_cemac_yield_curve() -> dict[str, Any]:
    """Actualise les courbes pays CEMAC depuis les PDFs BEAC."""

    if not _resolve_ai_endpoint():
        return _build_static_cemac_extraction(
            warnings=[
                (
                    "Moteur d'extraction non configure: courbes BEAC mars 2026 "
                    "exactes conservees en local."
                )
            ],
        )

    urls = _find_latest_beac_country_pdf_urls()
    extracted_curves: list[Any] = []
    warnings: list[str] = []
    for country, source_url in urls.items():
        try:
            pdf_bytes = _download_bytes(source_url)
            ai_payload = _call_ai_extractor(
                pdf_bytes=pdf_bytes,
                source_url=source_url,
            )
            raw_curves = ai_payload.get("courbes") or ai_payload.get("curves")
            if isinstance(raw_curves, list):
                extracted_curves.extend(raw_curves)
        except HTTPException as exc:
            warnings.append(
                f"{country}: extraction PDF indisponible ({exc.status_code})."
            )

    if not extracted_curves:
        return _build_static_cemac_extraction(
            warnings=[
                *warnings,
                (
                    "Aucune extraction PDF exploitable: courbes BEAC mars 2026 "
                    "exactes conservees en local."
                ),
            ],
        )

    payload = {
        "zone": "CEMAC",
        "source": "BEAC",
        "date_source": "Mars 2026",
        "courbes": extracted_curves,
    }
    result = _normalize_cemac_extraction(payload, source_url=_BEAC_PAGE_URL)
    result["warnings"] = [*result.get("warnings", []), *warnings]
    return result


def _find_latest_beac_country_pdf_urls() -> dict[str, str]:
    urls = dict(_BEAC_COUNTRY_PDF_URLS)
    try:
        html = _download_text(_BEAC_PAGE_URL)
    except HTTPException:
        return urls

    candidates = re.findall(
        r"""href=["']([^"']*Courbe[^"']*\.pdf)["']""",
        html,
        flags=re.IGNORECASE,
    )
    resolved_countries = set()
    for raw_href in candidates:
        href = raw_href.replace("&amp;", "&")
        normalized_href = _normalize_text(urllib.parse.unquote(href))
        for country, tokens in _BEAC_COUNTRY_URL_TOKENS.items():
            if country in resolved_countries:
                continue
            if any(token in normalized_href for token in tokens):
                urls[country] = urllib.parse.urljoin(_BEAC_PAGE_URL, href)
                resolved_countries.add(country)
                break
    return urls


def _download_text(url: str) -> str:
    data = _download_bytes(url)
    return data.decode("utf-8", errors="replace")


def _download_bytes(url: str) -> bytes:
    request = urllib.request.Request(url, headers=_HTTP_HEADERS)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "SOURCE_DOWNLOAD_FAILED",
                "message": f"Source BEAC indisponible: {exc}",
            },
        ) from exc


def _call_ai_extractor(*, pdf_bytes: bytes, source_url: str) -> dict[str, Any]:
    endpoint = _resolve_ai_endpoint()
    if _is_gemini_endpoint(endpoint):
        return _call_gemini_extractor(
            endpoint=endpoint,
            pdf_bytes=pdf_bytes,
            source_url=source_url,
        )

    document_base64 = base64.b64encode(pdf_bytes).decode("ascii")
    payload = {
        "task": "extract_cemac_yield_curves",
        "model": settings.yield_curve_ai_model or None,
        "source": {
            "name": "BEAC",
            "zone": "CEMAC",
            "url": source_url,
            "mime_type": "application/pdf",
        },
        "instructions": (
            "Extraire uniquement les courbes de rendement des titres publics "
            "CEMAC presentes dans le document BEAC. Ne jamais inventer un pays "
            "ou une maturite absente. Retourner un JSON strict avec: zone, "
            "source, date_source, courbes[]. Chaque courbe doit avoir pays et "
            "points[]. Chaque point doit avoir maturite, annees, taux. Si la "
            "source separe taux_brut et taux_lisse, les inclure. Le taux doit "
            "etre en pourcentage annuel, par exemple 6.35 pour 6,35%."
        ),
        "expected_countries": [
            "Cameroun",
            "République Centrafricaine",
            "Congo",
            "Gabon",
            "Guinée équatoriale",
            "Tchad",
        ],
        "document_base64": document_base64,
    }
    body = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if settings.yield_curve_ai_api_key.strip():
        headers["Authorization"] = f"Bearer {settings.yield_curve_ai_api_key.strip()}"

    request = urllib.request.Request(
        endpoint,
        data=body,
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            raw = response.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, TimeoutError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_EXTRACTOR_FAILED",
                "message": f"Extraction PDF indisponible: {exc}",
            },
        ) from exc

    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_EXTRACTOR_INVALID_JSON",
                "message": "Le moteur d'extraction n'a pas renvoye un JSON lisible.",
            },
        ) from exc

    return _unwrap_ai_payload(decoded)


def _resolve_ai_endpoint() -> str:
    endpoint = settings.yield_curve_ai_endpoint.strip()
    if endpoint:
        return endpoint
    if not settings.yield_curve_ai_api_key.strip():
        return ""
    model = settings.yield_curve_ai_model.strip() or "gemini-2.5-flash"
    return _GEMINI_ENDPOINT_TEMPLATE.format(model=urllib.parse.quote(model, safe="-_."))


def _is_gemini_endpoint(endpoint: str) -> bool:
    return "generativelanguage.googleapis.com" in endpoint.lower()


def _call_gemini_extractor(
    *,
    endpoint: str,
    pdf_bytes: bytes,
    source_url: str,
) -> dict[str, Any]:
    document_base64 = base64.b64encode(pdf_bytes).decode("ascii")
    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "inline_data": {
                            "mime_type": "application/pdf",
                            "data": document_base64,
                        }
                    },
                    {"text": _gemini_extraction_prompt(source_url)},
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0,
            "responseMimeType": "application/json",
            "responseJsonSchema": _cemac_response_schema(),
        },
    }
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "x-goog-api-key": settings.yield_curve_ai_api_key.strip(),
    }
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            raw = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "GEMINI_EXTRACTOR_FAILED",
                "message": f"Gemini a refuse l'extraction: {detail[:900]}",
            },
        ) from exc
    except (urllib.error.URLError, TimeoutError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "GEMINI_EXTRACTOR_FAILED",
                "message": f"Gemini indisponible: {exc}",
            },
        ) from exc

    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "GEMINI_EXTRACTOR_INVALID_JSON",
                "message": "Gemini n'a pas renvoye une reponse JSON lisible.",
            },
        ) from exc
    return _unwrap_ai_payload(decoded)


def _gemini_extraction_prompt(source_url: str) -> str:
    return (
        "Tu es un moteur d'extraction de donnees, pas un assistant de chat. "
        "Lis le PDF BEAC fourni et extrais uniquement les courbes de rendement "
        "des titres publics de la zone CEMAC presentes dans le document. "
        "La CEMAC peut inclure Cameroun, Republique Centrafricaine, Congo, "
        "Gabon, Guinee equatoriale et Tchad. Ne jamais inventer une courbe, un "
        "pays, une maturite ou un taux absent du document. Si seules certaines "
        "courbes pays sont visibles, retourne uniquement celles-la. Les taux "
        "doivent etre en pourcentage annuel, par exemple 6.35 pour 6,35 %. "
        "Chaque point doit contenir maturite, annees et taux. Si le document "
        "separe taux brut et taux lisse, retourne aussi taux_brut et "
        "taux_lisse. Source: "
        f"{source_url}"
    )


def _cemac_response_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "zone": {"type": "string"},
            "source": {"type": "string"},
            "date_source": {"type": "string"},
            "courbes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "pays": {"type": "string"},
                        "points": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "maturite": {"type": "string"},
                                    "annees": {"type": "number"},
                                    "taux": {"type": "number"},
                                    "taux_brut": {"type": "number"},
                                    "taux_lisse": {"type": "number"},
                                },
                                "required": ["maturite", "annees", "taux"],
                            },
                        },
                    },
                    "required": ["pays", "points"],
                },
            },
        },
        "required": ["zone", "source", "date_source", "courbes"],
    }


def _unwrap_ai_payload(decoded: Any) -> dict[str, Any]:
    if isinstance(decoded, dict) and "choices" in decoded:
        content = (
            decoded.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
        )
        decoded = _parse_embedded_json(content)
    elif isinstance(decoded, dict) and "candidates" in decoded:
        parts = (
            decoded.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [])
        )
        content = "".join(
            part.get("text", "") for part in parts if isinstance(part, dict)
        )
        decoded = _parse_embedded_json(content)
    elif isinstance(decoded, dict) and isinstance(decoded.get("data"), dict):
        decoded = decoded["data"]
    elif isinstance(decoded, str):
        decoded = _parse_embedded_json(decoded)

    if not isinstance(decoded, dict):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_EXTRACTOR_UNSUPPORTED_RESPONSE",
                "message": "Reponse d'extraction non compatible avec le schema attendu.",
            },
        )
    return decoded


def _parse_embedded_json(value: str) -> dict[str, Any]:
    cleaned = value.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    match = re.search(r"\{.*\}", cleaned, flags=re.DOTALL)
    if match:
        cleaned = match.group(0)
    return json.loads(cleaned)


def _normalize_cemac_extraction(
    payload: dict[str, Any],
    *,
    source_url: str,
) -> dict[str, Any]:
    raw_curves = payload.get("courbes") or payload.get("curves") or []
    curves = []
    warnings = []

    for raw_curve in raw_curves:
        if not isinstance(raw_curve, dict):
            continue
        country = _canonical_country(
            str(
                raw_curve.get("pays")
                or raw_curve.get("country")
                or raw_curve.get("nom")
                or raw_curve.get("name")
                or ""
            )
        )
        if country is None:
            warnings.append("Courbe ignoree: pays CEMAC non reconnu.")
            continue

        points = _normalize_curve_points(raw_curve.get("points") or [])
        if len(points) < 2:
            warnings.append(f"Courbe {country} ignoree: points insuffisants.")
            continue
        curves.append({"country": country, "points": points})

    if not curves:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "AI_EXTRACTOR_EMPTY_CURVES",
                "message": "Aucune courbe pays CEMAC exploitable n'a ete extraite.",
            },
        )

    present = {curve["country"] for curve in curves}
    absent = sorted(set(_CEMAC_COUNTRIES.values()) - present)
    aggregate_points = _aggregate_points(curves)
    return {
        "status": "ok",
        "zone": "CEMAC",
        "source": payload.get("source") or "BEAC",
        "source_url": source_url,
        "source_date_label": _source_date_label(payload),
        "methodology": (
            "Actualisation CEMAC depuis les PDFs BEAC pays, "
            "conservation des courbes extraites et calcul de la courbe zone "
            "par moyenne simple des maturites communes."
        ),
        "curves": curves,
        "aggregate_points": aggregate_points,
        "countries_absent_from_document": absent,
        "warnings": warnings,
        "message": (
            f"CEMAC actualisee: {len(curves)} courbe(s) pays extraite(s)."
        ),
    }


def _build_static_cemac_extraction(
    *,
    warnings: list[str] | None = None,
) -> dict[str, Any]:
    curves = [
        {
            "country": country,
            "points": [
                {
                    "maturity": maturity,
                    "years": years,
                    "rate": rate,
                    "raw_rate": rate,
                    "smoothed_rate": rate,
                }
                for maturity, years, rate in points
            ],
        }
        for country, points in _CEMAC_MARCH_2026_EXACT_CURVES.items()
    ]
    absent = sorted(
        set(_CEMAC_COUNTRIES.values()) - set(_CEMAC_MARCH_2026_EXACT_CURVES)
    )
    return {
        "status": "ok",
        "zone": "CEMAC",
        "source": "BEAC",
        "source_url": _BEAC_PAGE_URL,
        "source_date_label": "Mars 2026",
        "methodology": (
            "Actualisation CEMAC prevue depuis les PDFs "
            "BEAC pays. En absence d'Internet, l'outil conserve ce "
            "jeu local valide BEAC mars 2026; la courbe zone est la moyenne "
            "simple des maturites communes aux pays disponibles."
        ),
        "curves": curves,
        "aggregate_points": _aggregate_points(curves),
        "countries_absent_from_document": absent,
        "warnings": warnings or [],
        "message": "CEMAC chargee depuis les tables BEAC mars 2026.",
    }


def _normalize_curve_points(raw_points: Any) -> list[dict[str, float | str]]:
    if not isinstance(raw_points, list):
        return []

    points = []
    seen = set()
    for raw_point in raw_points:
        if not isinstance(raw_point, dict):
            continue
        label = str(
            raw_point.get("maturite")
            or raw_point.get("maturity")
            or raw_point.get("label")
            or ""
        )
        years = _number_or_none(raw_point.get("annees") or raw_point.get("years"))
        if years is None:
            years = _parse_maturity_years(label)
        rate = _number_or_none(
            raw_point.get("taux_lisse")
            or raw_point.get("taux_lissé")
            or raw_point.get("smoothed_rate")
            or raw_point.get("smoothedRate")
            or raw_point.get("taux")
            or raw_point.get("rate")
        )
        raw_rate = _number_or_none(
            raw_point.get("taux_brut")
            or raw_point.get("raw_rate")
            or raw_point.get("rawRate")
        )
        if years is None or rate is None or years <= 0:
            continue
        if rate <= 1:
            rate *= 100
        if raw_rate is None:
            raw_rate = rate
        elif raw_rate <= 1:
            raw_rate *= 100
        if rate <= 0 or rate > 30:
            continue
        key = round(years, 4)
        if key in seen:
            continue
        seen.add(key)
        points.append(
            {
                "maturity": _format_maturity_label(years, fallback=label),
                "years": round(years, 6),
                "rate": round(rate, 6),
                "raw_rate": round(raw_rate, 6),
                "smoothed_rate": round(rate, 6),
            }
        )

    points.sort(key=lambda point: float(point["years"]))
    return points


def _aggregate_points(curves: list[dict[str, Any]]) -> list[dict[str, float | str]]:
    grouped: dict[float, list[float]] = {}
    for curve in curves:
        for point in curve["points"]:
            key = round(float(point["years"]), 6)
            grouped.setdefault(key, []).append(
                float(point.get("smoothed_rate") or point["rate"])
            )

    aggregate = []
    required_count = len(curves)
    for years, rates in sorted(grouped.items()):
        if required_count > 1 and len(rates) < required_count:
            continue
        aggregate.append(
            {
                "maturity": _format_maturity_label(years),
                "years": years,
                "rate": round(sum(rates) / len(rates), 6),
                "raw_rate": round(sum(rates) / len(rates), 6),
                "smoothed_rate": round(sum(rates) / len(rates), 6),
            }
        )
    return aggregate


def _canonical_country(value: str) -> str | None:
    normalized = _normalize_text(value)
    for token, country in _CEMAC_COUNTRIES.items():
        if token in normalized:
            return country
    return None


def _normalize_text(value: str) -> str:
    without_accents = "".join(
        char
        for char in unicodedata.normalize("NFKD", value)
        if not unicodedata.combining(char)
    )
    return re.sub(r"\s+", " ", without_accents.lower()).strip()


def _number_or_none(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    if value is None:
        return None
    cleaned = str(value).replace("%", "").replace(",", ".").strip()
    try:
        return float(cleaned)
    except ValueError:
        return None


def _parse_maturity_years(label: str) -> float | None:
    normalized = _normalize_text(label).replace(",", ".")
    match = re.search(r"(\d+(?:\.\d+)?)", normalized)
    if not match:
        return None
    amount = float(match.group(1))
    return amount / 12 if "mois" in normalized else amount


def _format_maturity_label(years: float, fallback: str = "") -> str:
    if fallback.strip():
        return fallback.strip()
    if years < 1:
        months = round(years * 12)
        return f"{months} mois"
    if abs(years - round(years)) < 0.001:
        rounded = round(years)
        return f"{rounded} an" if rounded == 1 else f"{rounded} ans"
    return f"{str(round(years, 1)).replace('.', ',')} ans"


def _source_date_label(payload: dict[str, Any]) -> str:
    for key in ("date_source", "source_date", "sourceDate", "source_date_label"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return "Source BEAC actualisee"
