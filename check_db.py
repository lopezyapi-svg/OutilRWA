import sqlite3
conn = sqlite3.connect('c:/OutilRWA/backend/data/rwa_data.db')
print(conn.execute("SELECT date_octroi, date_echeance FROM expositions WHERE id='EXP-2026-0153'").fetchone())
