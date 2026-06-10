"""Lanceur du backend pour les builds desktop packagés."""

from __future__ import annotations

import argparse
import logging
import os
from pathlib import Path

import uvicorn

from app.core.runtime_paths import logs_dir
from app.main import app


def _configure_logging() -> None:
    log_directory = logs_dir()
    log_directory.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(
                Path(log_directory) / "backend.log",
                encoding="utf-8",
            )
        ],
    )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Lance le backend FastAPI.")
    parser.add_argument(
        "--reload",
        action="store_true",
        help="Active le rechargement automatique en developpement.",
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("RWA_API_HOST", "127.0.0.1"),
        help="Adresse d'ecoute du serveur.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("RWA_API_PORT", "8000")),
        help="Port d'ecoute du serveur.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    _configure_logging()
    log_level = os.environ.get("RWA_API_LOG_LEVEL", "warning")
    uvicorn.run(
        "app.main:app" if args.reload else app,
        host=args.host,
        port=args.port,
        log_level=log_level,
        access_log=False,
        reload=args.reload,
    )


if __name__ == "__main__":
    main()
