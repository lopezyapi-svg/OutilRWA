import sys
sys.path.append('c:/OutilRWA/backend')
from app.core.runtime_paths import ensure_seed_data_file
from database.connection import database_manager
from database.repositories.exposure_repository import exposure_repository

database_manager.initialize()
record = exposure_repository.get_exposure("EXP-2026-0153")
print("GRANT DATE:", record.get("grant_date"))
print("MATURITY DATE:", record.get("maturity_date"))
print("DATE OCTROI:", record.get("date_octroi"))
