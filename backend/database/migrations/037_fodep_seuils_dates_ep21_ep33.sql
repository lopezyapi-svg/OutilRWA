-- FODEP — deux corrections d'alignement à la notice technique BCEAO.
--
-- 1) SEUILS PRUDENTIELS DATÉS
--
-- La notice est explicite (EP01, et liste des pièges de la feuille de
-- route) : « le niveau à respecter tient compte des dispositions
-- transitoires : il doit être paramétré par date d'arrêté, jamais figé
-- dans le code ». Les seuils étaient jusqu'ici des littéraux Python, ce
-- qui interdisait de rejouer un arrêté ancien avec les seuils en vigueur
-- à cette date. Ils deviennent des données datées.
--
-- Chaque ligne vaut pour [date_debut, date_fin] ; date_fin NULL signifie
-- « toujours en vigueur ». La résolution prend la ligne dont l'intervalle
-- contient la date d'arrêté (voir services.resoudre_seuils).
--
-- Les valeurs semées reprennent exactement celles qui étaient codées en
-- dur, avec pour seule date d'effet le 1er janvier 2018 (première
-- déclaration FODEP attendue, sur états arrêtés au 31 décembre 2017).
-- Aucun échéancier transitoire n'est inventé ici : ajouter une période
-- transitoire réelle se fait désormais par INSERT, sans toucher au code.
--
-- 2) POSTES EP21 (produit brut) ET EP33 (briques d'exposition du levier)
--
-- Ces deux états étaient affichés « non ventilé » faute de stockage. Même
-- mécanique que les postes des migrations 035 et 036 : structure figée,
-- un code DISPRU = une colonne. Les totaux (RO009, RL004, RL007, RL010,
-- RL013, RL015) restent calculés, jamais saisis.
--
-- Convention de signe de la notice : les postes précédés de (-) sont
-- saisis en valeurs négatives, les totaux sont des sommes algébriques.

CREATE TABLE IF NOT EXISTS fodep_seuil_prudentiel (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL,
    libelle TEXT NOT NULL DEFAULT '',
    seuil REAL NOT NULL,
    date_debut TEXT NOT NULL,
    date_fin TEXT,
    cree_le TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fodep_seuil_code_date
    ON fodep_seuil_prudentiel(code, date_debut);

INSERT OR IGNORE INTO fodep_seuil_prudentiel (id, code, libelle, seuil, date_debut, date_fin, cree_le) VALUES
    ('seuil-cet1-2018',     'cet1',     'Ratio de fonds propres CET1',                                        5.0,   '2018-01-01', NULL, datetime('now')),
    ('seuil-tier1-2018',    'tier1',    'Ratio de fonds propres de base T1',                                  6.0,   '2018-01-01', NULL, datetime('now')),
    ('seuil-solvency-2018', 'solvency', 'Ratio de solvabilité total',                                         9.0,   '2018-01-01', NULL, datetime('now')),
    ('seuil-leverage-2018', 'leverage', 'Ratio de levier',                                                    3.0,   '2018-01-01', NULL, datetime('now')),
    ('seuil-ra006-2018',    'ra006',    'Participation individuelle en entité commerciale (% du capital)',    25.0,  '2018-01-01', NULL, datetime('now')),
    ('seuil-ra007-2018',    'ra007',    'Participation individuelle en entité commerciale (% des FP T1)',     15.0,  '2018-01-01', NULL, datetime('now')),
    ('seuil-ra008-2018',    'ra008',    'Total des participations commerciales (% des FP effectifs)',         60.0,  '2018-01-01', NULL, datetime('now')),
    ('seuil-ra009-2018',    'ra009',    'Immobilisations hors exploitation (% des FP T1)',                    15.0,  '2018-01-01', NULL, datetime('now')),
    ('seuil-ra010-2018',    'ra010',    'Total immobilisations et participations (% des FP effectifs)',       100.0, '2018-01-01', NULL, datetime('now')),
    ('seuil-ra011-2018',    'ra011',    'Prêts aux actionnaires, dirigeants et personnel (% des FP effectifs)', 20.0,  '2018-01-01', NULL, datetime('now'));

-- EP21 — Calcul du produit brut (la notice ne numérote pas de RO004).
ALTER TABLE fodep_fonds_propres ADD COLUMN ro001 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN ro002 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN ro003 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN ro005 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN ro006 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN ro007 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN ro008 REAL NOT NULL DEFAULT 0;

-- EP33 — Briques d'exposition du ratio de levier.
ALTER TABLE fodep_fonds_propres ADD COLUMN rl001 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl002 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl003 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl005 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl006 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl008 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl009 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl011 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN rl012 REAL NOT NULL DEFAULT 0;
