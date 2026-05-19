"""Lanceur du backend pour les builds desktop packagés."""

from __future__ import annotations

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


def main() -> None:
    _configure_logging()
    host = os.environ.get("RWA_API_HOST", "127.0.0.1")
    port = int(os.environ.get("RWA_API_PORT", "8000"))
    log_level = os.environ.get("RWA_API_LOG_LEVEL", "warning")
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level=log_level,
        access_log=False,
    )


if __name__ == "__main__":
    main()
