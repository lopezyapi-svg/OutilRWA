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
    capital_ratio: float = 0.08
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
