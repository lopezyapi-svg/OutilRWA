-- Migration 027 : Module PIEAFP — Pilier 2 / ICAAP (UMOA Titre XI art. 505-549)
-- Couvre : concentration, IRRBB, autres risques, planification, stress tests, gouvernance.
-- Exclut le risque de liquidité (aucune donnée disponible à ce stade).

-- 1. Échéancier de repricing IRRBB (gap de taux)
CREATE TABLE IF NOT EXISTS pieafp_irrbb_echeancier (
    tranche            TEXT PRIMARY KEY,  -- '0-1m', '1-3m', '3-6m', '6-12m', '1-2a', '2-5a', '5a+'
    ordre              INTEGER NOT NULL DEFAULT 0,
    encours_actifs     REAL    NOT NULL DEFAULT 0,
    encours_passifs    REAL    NOT NULL DEFAULT 0,
    taux_actifs_pct    REAL    NOT NULL DEFAULT 0,  -- taux moyen annuel en %
    taux_passifs_pct   REAL    NOT NULL DEFAULT 0,
    duration_annees    REAL    NOT NULL DEFAULT 0,  -- durée représentative de la tranche en années
    modifie_le         TEXT    NOT NULL DEFAULT ''
);

INSERT OR IGNORE INTO pieafp_irrbb_echeancier (tranche, ordre, duration_annees) VALUES
    ('0-1m',  1, 0.042),
    ('1-3m',  2, 0.167),
    ('3-6m',  3, 0.375),
    ('6-12m', 4, 0.75),
    ('1-2a',  5, 1.5),
    ('2-5a',  6, 3.5),
    ('5a+',   7, 7.0);

-- 2. Matrice des autres risques Pilier 2 (qualitatifs)
CREATE TABLE IF NOT EXISTS pieafp_autres_risques (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    libelle          TEXT    NOT NULL,
    categorie        TEXT    NOT NULL DEFAULT 'Opérationnel',
    probabilite      INTEGER NOT NULL DEFAULT 3 CHECK(probabilite BETWEEN 1 AND 5),
    impact           INTEGER NOT NULL DEFAULT 3 CHECK(impact BETWEEN 1 AND 5),
    description      TEXT    NOT NULL DEFAULT '',
    mesures          TEXT    NOT NULL DEFAULT '',
    date_evaluation  TEXT    NOT NULL DEFAULT '',
    cree_le          TEXT    NOT NULL DEFAULT ''
);

-- 3. Planification pluriannuelle des fonds propres
CREATE TABLE IF NOT EXISTS pieafp_planification (
    annee                   INTEGER PRIMARY KEY,
    fp_disponibles          REAL    NOT NULL DEFAULT 0,
    rwa_credit_projete      REAL    NOT NULL DEFAULT 0,
    rwa_marche_projete      REAL    NOT NULL DEFAULT 0,
    rwa_op_projete          REAL    NOT NULL DEFAULT 0,
    resultat_net_projete    REAL    NOT NULL DEFAULT 0,
    dividendes_projetes     REAL    NOT NULL DEFAULT 0,
    emission_capital        REAL    NOT NULL DEFAULT 0,  -- levée de capital prévue
    addon_pilier2           REAL    NOT NULL DEFAULT 0,  -- add-on Pilier 2 estimé
    modifie_le              TEXT    NOT NULL DEFAULT ''
);

-- 4. Scénarios de stress
CREATE TABLE IF NOT EXISTS pieafp_scenarios_stress (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    nom                     TEXT    NOT NULL,
    description             TEXT    NOT NULL DEFAULT '',
    type_scenario           TEXT    NOT NULL DEFAULT 'Adverse',  -- 'Adverse', 'Sévère', 'Historique'
    choc_rwa_credit_pct     REAL    NOT NULL DEFAULT 0,   -- % hausse RWA crédit
    choc_rwa_marche_pct     REAL    NOT NULL DEFAULT 0,   -- % hausse RWA marché
    choc_rwa_op_pct         REAL    NOT NULL DEFAULT 0,   -- % hausse RWA opérationnel
    choc_perte_nette        REAL    NOT NULL DEFAULT 0,   -- perte nette absolue en FCFA
    actif                   INTEGER NOT NULL DEFAULT 1,
    cree_le                 TEXT    NOT NULL DEFAULT ''
);

-- Scénarios par défaut
INSERT OR IGNORE INTO pieafp_scenarios_stress
    (nom, description, type_scenario, choc_rwa_credit_pct, choc_rwa_marche_pct, choc_rwa_op_pct, choc_perte_nette, cree_le)
VALUES
    ('Choc modéré',  'Détérioration progressive du portefeuille crédit (+15%) et hausse des positions de marché', 'Adverse',   15, 20, 10, 0, datetime('now')),
    ('Choc sévère',  'Crise sectorielle majeure avec forte dégradation des contreparties', 'Sévère', 35, 50, 25, 0, datetime('now')),
    ('Crise 2008',   'Choc de type crise financière mondiale — compression des spreads et fuites de liquidité', 'Historique', 50, 80, 30, 0, datetime('now'));

-- 5. Checklist gouvernance PIEAFP
CREATE TABLE IF NOT EXISTS pieafp_gouvernance_checklist (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    element       TEXT    NOT NULL,
    categorie     TEXT    NOT NULL DEFAULT 'Général',
    statut        TEXT    NOT NULL DEFAULT 'A faire'
                          CHECK(statut IN ('Conforme', 'En cours', 'A faire', 'Non applicable')),
    date_revue    TEXT    NOT NULL DEFAULT '',
    responsable   TEXT    NOT NULL DEFAULT '',
    note          TEXT    NOT NULL DEFAULT ''
);

INSERT OR IGNORE INTO pieafp_gouvernance_checklist (element, categorie, statut) VALUES
    ('Politique de fonds propres approuvée par le Conseil',              'Documentation', 'A faire'),
    ('Cartographie des risques Pilier 2 documentée',                     'Documentation', 'A faire'),
    ('Simulations de crise réalisées et validées par Comité Capital',    'Processus',     'A faire'),
    ('Rapport PIEAFP soumis à l''organe délibérant',                     'Documentation', 'A faire'),
    ('Dispositif de contrôle interne couvrant le PIEAFP',               'Contrôle',      'A faire'),
    ('Intégrité et qualité des données vérifiées',                       'Contrôle',      'A faire'),
    ('Revue annuelle du Conseil documentée',                             'Gouvernance',   'A faire'),
    ('Scénarios de stress validés par Direction Générale',              'Processus',     'A faire'),
    ('Plan de capital pluriannuel formalisé',                            'Planification', 'A faire'),
    ('Limites d''appétence au risque fixées et communiquées',           'Gouvernance',   'A faire'),
    ('Communication à la BCEAO dans les délais réglementaires',         'Conformité',    'A faire'),
    ('Processus de mise à jour annuelle du PIEAFP documenté',           'Processus',     'A faire');
