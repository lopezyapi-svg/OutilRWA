"""Configuration simple de l'application."""

import os
from dataclasses import dataclass
from pathlib import Path


def _load_env_file(path: Path) -> None:
    """Charge un fichier .env local sans ecraser l'environnement systeme."""

    if not path.exists():
        return

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue

        key, value = stripped.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]

        if key and key not in os.environ:
            os.environ[key] = value


_BACKEND_DIR = Path(__file__).resolve().parents[2]
_load_env_file(_BACKEND_DIR / ".env")
_load_env_file(_BACKEND_DIR.parent / ".env")


@dataclass(slots=True)
class Settings:
    """Contient les parametres simples utilises par l'API."""

    app_name: str = "Risk management API"
    app_version: str = "0.1.0"
    # Ratio de solvabilite minimum reglementaire UMOA (Capital / RWA total) :
    # 11,5 %. Ne pas confondre avec le pourcentage RWA (9 %, cf.
    # app/core/bceao_calculations.py) utilise pour convertir une exigence de
    # fonds propres marche/operationnel en equivalent RWA — ce sont deux
    # notions distinctes. Parametrable via l'environnement.
    capital_ratio: float = float(os.getenv("MINIMUM_CAPITAL_RATIO", "0.115"))
    # Seuil de tolerance pour le controle de reconciliation du tableau RWA.
    rwa_reconciliation_threshold: float = float(
        os.getenv("RWA_RECONCILIATION_THRESHOLD", "0.005")
    )
    # Libelle de perimetre affiche dans le bandeau de contexte.
    rwa_analysis_scope_label: str = os.getenv(
        "RWA_ANALYSIS_SCOPE_LABEL",
        "Portefeuille consolidé — risque de crédit",
    )
    yield_curve_ai_endpoint: str = os.getenv("YIELD_CURVE_AI_ENDPOINT", "")
    yield_curve_ai_api_key: str = os.getenv(
        "YIELD_CURVE_AI_API_KEY",
        os.getenv("GEMINI_API_KEY", ""),
    )
    yield_curve_ai_model: str = os.getenv(
        "YIELD_CURVE_AI_MODEL",
        "gemini-2.5-flash",
    )


settings = Settings()


# Plages de pondération moyenne attendues par agent économique (code -> (min, max),
# en ratio). Sert à mettre en évidence une pondération moyenne hors norme dans le
# tableau. Paramètre backend centralisé (modifiable ici sans toucher au frontend).
RWA_EXPECTED_WEIGHT_RANGES: dict[str, tuple[float, float]] = {
    "a": (0.0, 0.5),   # Souverains
    "b": (0.0, 1.0),   # Organismes publics
    "c": (0.0, 0.5),   # BMD
    "d": (0.2, 1.0),   # Institutions financières
    "e": (0.2, 1.5),   # Entreprises
    "f": (0.5, 1.0),   # Clientèle de détail
    "g": (0.0, 0.5),   # Immobilier résidentiel (attendu ~0,35 ; alerte > 0,50)
    "h": (0.5, 1.0),   # Immobilier commercial (attendu ~0,75)
    "i": (1.0, 1.5),   # Créances en souffrance
    "j": (1.0, 1.5),   # Créances à risque élevé
    "k": (0.0, 1.0),   # Autres actifs
    "l": (0.0, 1.5),   # Hors-bilan
}
