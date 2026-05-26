"""Connexion SQLite, initialisation et utilitaires de base."""

from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
import re
import shutil
import sqlite3
from threading import Lock
from typing import Iterator

from app.core.runtime_paths import (
    app_data_root,
    backups_dir,
    ensure_seed_data_file,
    resource_path,
)

DATA_DIR = app_data_root()
BACKUP_DIR = backups_dir()
DATABASE_PATH = ensure_seed_data_file("rwa_data.db")
SCHEMA_PATH = resource_path("database", "schema.sql")
MIGRATIONS_DIR = resource_path("database", "migrations")


def utcnow_iso() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat()


class DatabaseManager:
    """Gère la base SQLite locale de l'application."""

    def __init__(
        self,
        db_path: Path = DATABASE_PATH,
        schema_path: Path = SCHEMA_PATH,
        migrations_dir: Path = MIGRATIONS_DIR,
    ) -> None:
        self.db_path = db_path
        self.schema_path = schema_path
        self.migrations_dir = migrations_dir
        self._lock = Lock()

    def connect(self) -> sqlite3.Connection:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(
            self.db_path,
            timeout=30,
            check_same_thread=False,
        )
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = WAL")
        connection.execute("PRAGMA synchronous = NORMAL")
        connection.execute("PRAGMA temp_store = MEMORY")
        return connection

    def initialize(self) -> None:
        with self._lock:
            connection = self.connect()
            try:
                connection.execute(
                    """
                    CREATE TABLE IF NOT EXISTS schema_migrations (
                        version INTEGER PRIMARY KEY,
                        name TEXT NOT NULL,
                        applied_at TEXT NOT NULL
                    )
                    """
                )
                schema_sql = self.schema_path.read_text(encoding="utf-8")
                connection.executescript(schema_sql)
                self._apply_migrations(connection)
                self._ensure_runtime_compatibility(connection)
                connection.commit()
            finally:
                connection.close()

    def _apply_migrations(self, connection: sqlite3.Connection) -> None:
        if not self.migrations_dir.exists():
            return
        applied_versions = {
            int(row["version"])
            for row in connection.execute("SELECT version FROM schema_migrations")
        }
        for migration_path in sorted(self.migrations_dir.glob("*.sql")):
            prefix = migration_path.stem.split("_", maxsplit=1)[0]
            try:
                version = int(prefix)
            except ValueError:
                continue
            if version in applied_versions:
                continue
            sql = migration_path.read_text(encoding="utf-8")
            if sql.strip():
                for statement in self._iter_sql_statements(sql):
                    try:
                        connection.execute(statement)
                    except sqlite3.OperationalError as exc:
                        if self._can_ignore_migration_error(connection, statement, exc):
                            continue
                        raise
            connection.execute(
                """
                INSERT INTO schema_migrations(version, name, applied_at)
                VALUES (?, ?, ?)
                """,
                (version, migration_path.stem, utcnow_iso()),
            )
            applied_versions.add(version)

    def _iter_sql_statements(self, sql: str) -> list[str]:
        """Découpe un script SQL simple en instructions exécutables."""
        cleaned_lines: list[str] = []
        for line in sql.splitlines():
            stripped = line.strip()
            if stripped.startswith("--"):
                continue
            cleaned_lines.append(line)
        cleaned_sql = "\n".join(cleaned_lines)
        return [statement.strip() for statement in cleaned_sql.split(";") if statement.strip()]

    def _can_ignore_migration_error(
        self,
        connection: sqlite3.Connection,
        statement: str,
        error: sqlite3.OperationalError,
    ) -> bool:
        message = str(error).lower()
        if "duplicate column name" in message:
            match = re.search(
                r"alter\s+table\s+([a-zA-Z_][\w]*)\s+add\s+column\s+([a-zA-Z_][\w]*)",
                statement,
                flags=re.IGNORECASE,
            )
            if not match:
                return False
            table_name, column_name = match.group(1), match.group(2)
            existing_columns = {
                str(row["name"]).lower()
                for row in connection.execute(f"PRAGMA table_info({table_name})")
            }
            return column_name.lower() in existing_columns
        if "already exists" in message:
            return True
        # DROP COLUMN sur une colonne déjà supprimée (DB déjà migrée ou schéma frais)
        if "no such column" in message:
            if re.search(r"alter\s+table\s+\S+\s+drop\s+column", statement, re.IGNORECASE):
                return True
            # RENAME COLUMN sur une colonne absente = déjà renommée
            if re.search(r"alter\s+table\s+\S+\s+rename\s+column", statement, re.IGNORECASE):
                return True
            # INSERT...SELECT depuis des colonnes absentes : schéma frais, rien à migrer
            if statement.strip().upper().startswith("INSERT"):
                return True
        # RENAME TABLE sur une table absente = déjà renommée ou schéma frais
        if "no such table" in message:
            if re.search(r"alter\s+table\s+\S+\s+rename\s+to", statement, re.IGNORECASE):
                return True
        return False

    def _ensure_runtime_compatibility(self, connection: sqlite3.Connection) -> None:
        # Note : les colonnes de type prudentiel ont été déplacées dans leurs
        # sous-tables respectives par la migration 019. La migration 021 a renommé
        # toutes les tables et colonnes en français.
        self._ensure_table_column(
            connection,
            table_name="expositions",
            column_name="champs_source_json",
            column_definition="TEXT NOT NULL DEFAULT '{}'",
        )
        for column_name, column_definition in (
            ("devise_collateral", "TEXT NOT NULL DEFAULT 'XOF'"),
            (
                "type_collateral",
                "TEXT NOT NULL DEFAULT 'Liquidités dans la même devise'",
            ),
            ("convertible_indice_principal", "INTEGER NOT NULL DEFAULT 1"),
            ("opcvm_decote_max", "REAL NOT NULL DEFAULT 0.30"),
            ("elements_panier_json", "TEXT NOT NULL DEFAULT '[]'"),
            ("devise_exposition", "TEXT NOT NULL DEFAULT 'XOF'"),
            ("ponderation", "REAL NOT NULL DEFAULT 0"),
            ("collateral_eligible", "INTEGER NOT NULL DEFAULT 1"),
            ("motif_ineligibilite", "TEXT NOT NULL DEFAULT ''"),
            ("he", "REAL NOT NULL DEFAULT 0"),
            ("hc", "REAL NOT NULL DEFAULT 0"),
            ("hfx", "REAL NOT NULL DEFAULT 0"),
            ("eva", "REAL NOT NULL DEFAULT 0"),
            ("cva", "REAL NOT NULL DEFAULT 0"),
            ("ead_apres_crm_financee", "REAL NOT NULL DEFAULT 0"),
            ("rwa_final", "REAL NOT NULL DEFAULT 0"),
            ("gain_crm", "REAL NOT NULL DEFAULT 0"),
        ):
            self._ensure_table_column(
                connection,
                table_name="crm_financee",
                column_name=column_name,
                column_definition=column_definition,
            )

    def _ensure_table_column(
        self,
        connection: sqlite3.Connection,
        *,
        table_name: str,
        column_name: str,
        column_definition: str,
    ) -> None:
        existing_columns = {
            str(row["name"])
            for row in connection.execute(f"PRAGMA table_info({table_name})")
        }
        if column_name in existing_columns:
            return
        connection.execute(
            f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}"
        )

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        connection = self.connect()
        try:
            connection.execute("BEGIN")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def create_backup(self, prefix: str = "rwa_data") -> Path | None:
        if not self.db_path.exists():
            return None
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        backup_path = BACKUP_DIR / f"{prefix}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        shutil.copy2(self.db_path, backup_path)
        return backup_path


database_manager = DatabaseManager()
