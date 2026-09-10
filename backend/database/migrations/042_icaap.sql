-- Module ICAAP — Processus interne d'évaluation de l'adéquation des fonds
-- propres (Pilier 2 du dispositif prudentiel UMOA / BCEAO).
--
-- Le Pilier 1 est déjà instrumenté (RWA crédit, marché, opérationnel). Ce
-- module ne recalcule aucun RWA : il consomme les résultats publiés par les
-- modules rwa_credit / market / risque_operationnel, exactement comme le
-- fait le module fodep. Il ajoute par-dessus l'évaluation du capital
-- économique, les stress tests et la planification du capital.
--
-- Un exercice ICAAP = un arrêté annuel. Cycle de vie du statut :
--   brouillon  -> valide  -> archive
-- Un exercice « archive » est IMMUABLE : toute correction passe par un
-- nouvel exercice. Les paramètres prudentiels utilisés par un calcul sont
-- figés dans icaap_capital_dispo / icaap_scenario au moment du calcul, de
-- sorte qu'un arrêté ancien reste rejouable même après évolution des seuils.
--
-- Lot L1 du cahier des charges : schéma + référentiel de paramètres.
-- Les routes et services arrivent aux lots suivants.

-- --------------------------------------------------------------------------
-- En-tête d'un exercice ICAAP annuel.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_exercice (
    id                TEXT PRIMARY KEY,
    annee             INTEGER NOT NULL,
    date_arrete       TEXT NOT NULL,
    statut            TEXT NOT NULL DEFAULT 'brouillon'
                          CHECK (statut IN ('brouillon', 'valide', 'archive')),
    auteur_id         TEXT,
    date_validation   TEXT,
    opinion_executif  TEXT NOT NULL DEFAULT '',
    avis_deliberant   TEXT NOT NULL DEFAULT '',
    commentaire       TEXT NOT NULL DEFAULT '',
    cree_le           TEXT NOT NULL,
    modifie_le        TEXT NOT NULL
);

-- Une seule année ouverte à la fois hors archive : un arrêté corrigé est
-- d'abord archivé, ce qui libère l'année pour un nouvel exercice.
CREATE UNIQUE INDEX IF NOT EXISTS idx_icaap_exercice_annee_active
    ON icaap_exercice(annee)
    WHERE statut <> 'archive';

-- --------------------------------------------------------------------------
-- Cartographie des risques d'un exercice.
-- materialite = probabilite (1..5) x impact (1..5). Au-delà du seuil
-- paramétrable (icaap_parametre 'seuil_materialite_quanti'), le risque est
-- traité en quantitatif ; en deçà, en qualitatif.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_risque (
    id            TEXT PRIMARY KEY,
    exercice_id   TEXT NOT NULL REFERENCES icaap_exercice(id) ON DELETE CASCADE,
    categorie     TEXT NOT NULL,
    libelle       TEXT NOT NULL DEFAULT '',
    pilier        INTEGER NOT NULL DEFAULT 2 CHECK (pilier IN (1, 2)),
    methode       TEXT NOT NULL DEFAULT 'quali'
                      CHECK (methode IN ('quanti', 'quali')),
    probabilite   INTEGER NOT NULL DEFAULT 1 CHECK (probabilite BETWEEN 1 AND 5),
    impact        INTEGER NOT NULL DEFAULT 1 CHECK (impact BETWEEN 1 AND 5),
    materialite   INTEGER NOT NULL DEFAULT 1,
    maitrise      TEXT NOT NULL DEFAULT '',
    commentaire   TEXT NOT NULL DEFAULT '',
    cree_le       TEXT NOT NULL,
    modifie_le    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_icaap_risque_exercice
    ON icaap_risque(exercice_id);

-- --------------------------------------------------------------------------
-- Besoin en capital économique par risque.
-- parametres_json conserve les hypothèses de calcul (add-on, choc de taux,
-- indice de concentration...) pour la traçabilité.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_capital_eco (
    id              TEXT PRIMARY KEY,
    exercice_id     TEXT NOT NULL REFERENCES icaap_exercice(id) ON DELETE CASCADE,
    risque_id       TEXT REFERENCES icaap_risque(id) ON DELETE CASCADE,
    categorie       TEXT NOT NULL,
    methode         TEXT NOT NULL DEFAULT '',
    parametres_json TEXT NOT NULL DEFAULT '{}',
    montant_besoin  REAL NOT NULL DEFAULT 0,
    horizon_mois    INTEGER NOT NULL DEFAULT 12,
    cree_le         TEXT NOT NULL,
    modifie_le      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_icaap_capital_eco_exercice
    ON icaap_capital_eco(exercice_id);

-- --------------------------------------------------------------------------
-- Matrice de corrélation servant à l'agrégation du besoin global :
--   besoin_global = racine( r^T . C . r )
-- Symétrique : une seule ligne par paire (risque_a < risque_b). La diagonale
-- vaut 1 et n'est pas stockée.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_correlation (
    id           TEXT PRIMARY KEY,
    exercice_id  TEXT NOT NULL REFERENCES icaap_exercice(id) ON DELETE CASCADE,
    risque_a     TEXT NOT NULL,
    risque_b     TEXT NOT NULL,
    coefficient  REAL NOT NULL DEFAULT 0
                     CHECK (coefficient BETWEEN -1 AND 1),
    cree_le      TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_icaap_correlation_paire
    ON icaap_correlation(exercice_id, risque_a, risque_b);

-- --------------------------------------------------------------------------
-- Capital interne disponible à la date d'arrêté de l'exercice.
-- Les composantes sont figées ici (photo), pas relues dynamiquement.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_capital_dispo (
    id                    TEXT PRIMARY KEY,
    exercice_id           TEXT NOT NULL UNIQUE
                              REFERENCES icaap_exercice(id) ON DELETE CASCADE,
    cet1                  REAL NOT NULL DEFAULT 0,
    at1                   REAL NOT NULL DEFAULT 0,
    t2                    REAL NOT NULL DEFAULT 0,
    deductions            REAL NOT NULL DEFAULT 0,
    capital_interne_total REAL NOT NULL DEFAULT 0,
    rwa_pilier1_total     REAL NOT NULL DEFAULT 0,
    source                TEXT NOT NULL DEFAULT '',
    cree_le               TEXT NOT NULL,
    modifie_le            TEXT NOT NULL
);

-- --------------------------------------------------------------------------
-- Scénario de stress test. hypotheses_json porte les chocs :
--   { "cout_risque_bp": +150, "rwa_pct": +0.08, "pnb_pct": -0.10, ... }
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_scenario (
    id              TEXT PRIMARY KEY,
    exercice_id     TEXT NOT NULL REFERENCES icaap_exercice(id) ON DELETE CASCADE,
    libelle         TEXT NOT NULL DEFAULT '',
    type_scenario   TEXT NOT NULL DEFAULT 'adverse'
                        CHECK (type_scenario IN ('base', 'adverse', 'severe')),
    hypotheses_json TEXT NOT NULL DEFAULT '{}',
    horizon_annees  INTEGER NOT NULL DEFAULT 3,
    dernier_run_le  TEXT,
    cree_le         TEXT NOT NULL,
    modifie_le      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_icaap_scenario_exercice
    ON icaap_scenario(exercice_id);

-- --------------------------------------------------------------------------
-- Résultat d'un scénario, une ligne par année projetée.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_scenario_resultat (
    id                     TEXT PRIMARY KEY,
    scenario_id            TEXT NOT NULL REFERENCES icaap_scenario(id) ON DELETE CASCADE,
    annee_proj             INTEGER NOT NULL,
    rwa_projete            REAL NOT NULL DEFAULT 0,
    resultat_projete       REAL NOT NULL DEFAULT 0,
    fonds_propres_projetes REAL NOT NULL DEFAULT 0,
    ratio_projete          REAL NOT NULL DEFAULT 0,
    cree_le                TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_icaap_scenario_resultat_annee
    ON icaap_scenario_resultat(scenario_id, annee_proj);

-- --------------------------------------------------------------------------
-- Planification du capital sur l'horizon prudentiel (projection déterministe).
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_plan_capital (
    id                     TEXT PRIMARY KEY,
    exercice_id            TEXT NOT NULL REFERENCES icaap_exercice(id) ON DELETE CASCADE,
    annee_proj             INTEGER NOT NULL,
    hypotheses_json        TEXT NOT NULL DEFAULT '{}',
    rwa_projete            REAL NOT NULL DEFAULT 0,
    resultat_mis_en_reserve REAL NOT NULL DEFAULT 0,
    distributions          REAL NOT NULL DEFAULT 0,
    fonds_propres_projetes REAL NOT NULL DEFAULT 0,
    ratio_projete          REAL NOT NULL DEFAULT 0,
    coussin_entame         INTEGER NOT NULL DEFAULT 0,
    cree_le                TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_icaap_plan_capital_annee
    ON icaap_plan_capital(exercice_id, annee_proj);

-- --------------------------------------------------------------------------
-- Plan d'action correctif issu de l'ICAAP.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_plan_action (
    id           TEXT PRIMARY KEY,
    exercice_id  TEXT NOT NULL REFERENCES icaap_exercice(id) ON DELETE CASCADE,
    constat      TEXT NOT NULL DEFAULT '',
    action       TEXT NOT NULL DEFAULT '',
    responsable  TEXT NOT NULL DEFAULT '',
    echeance     TEXT,
    statut       TEXT NOT NULL DEFAULT 'ouvert'
                     CHECK (statut IN ('ouvert', 'en_cours', 'clos')),
    cree_le      TEXT NOT NULL,
    modifie_le   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_icaap_plan_action_exercice
    ON icaap_plan_action(exercice_id);

-- --------------------------------------------------------------------------
-- Paramètres prudentiels versionnés. Aucun seuil n'est codé en dur ailleurs :
-- la résolution prend la ligne dont date_effet est la plus récente <= date
-- d'arrêté de l'exercice, pour une clé donnée.
--
-- ATTENTION : les valeurs semées ci-dessous sont les cibles UMOA « pleines »
-- (dispositif de Bâle II/III de la BCEAO, échéancier transitoire arrivé à
-- terme) reprises de la documentation publique. Elles DOIVENT être vérifiées
-- par la fonction risques avant mise en production et corrigées par simple
-- INSERT (nouvelle date_effet), sans toucher au code.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_parametre (
    id          TEXT PRIMARY KEY,
    cle         TEXT NOT NULL,
    libelle     TEXT NOT NULL DEFAULT '',
    valeur      REAL NOT NULL,
    unite       TEXT NOT NULL DEFAULT '',
    date_effet  TEXT NOT NULL,
    source      TEXT NOT NULL DEFAULT '',
    cree_le     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_icaap_parametre_cle
    ON icaap_parametre(cle, date_effet);

INSERT OR IGNORE INTO icaap_parametre (id, cle, libelle, valeur, unite, date_effet, source, cree_le) VALUES
    ('par-ratio-solva-min-2022',  'ratio_solvabilite_min',      'Ratio de solvabilité global minimum (hors coussin)',            9.0,   'pct',   '2022-01-01', 'Dispositif prudentiel UMOA / BCEAO — à vérifier', datetime('now')),
    ('par-ratio-cet1-min-2022',   'ratio_cet1_min',             'Ratio CET1 minimum (hors coussin)',                             5.0,   'pct',   '2022-01-01', 'Dispositif prudentiel UMOA / BCEAO — à vérifier', datetime('now')),
    ('par-ratio-t1-min-2022',     'ratio_tier1_min',            'Ratio de fonds propres de base T1 minimum (hors coussin)',      6.0,   'pct',   '2022-01-01', 'Dispositif prudentiel UMOA / BCEAO — à vérifier', datetime('now')),
    ('par-coussin-conserv-2022',  'coussin_conservation',       'Coussin de conservation des fonds propres',                     2.5,   'pct',   '2022-01-01', 'Dispositif prudentiel UMOA / BCEAO — à vérifier', datetime('now')),
    ('par-ratio-solva-cible-2022','ratio_solvabilite_cible',    'Ratio de solvabilité cible (minimum + coussin de conservation)',11.5,  'pct',   '2022-01-01', 'Dispositif prudentiel UMOA / BCEAO — à vérifier', datetime('now')),
    ('par-ratio-levier-min-2022', 'ratio_levier_min',           'Ratio de levier minimum',                                       3.0,   'pct',   '2022-01-01', 'Dispositif prudentiel UMOA / BCEAO — à vérifier', datetime('now')),
    ('par-seuil-materialite',     'seuil_materialite_quanti',   'Seuil de matérialité (probabilité x impact) déclenchant un traitement quantitatif', 12.0, 'points', '2022-01-01', 'Choix méthodologique interne', datetime('now')),
    ('par-choc-taux-bp',          'irrbb_choc_taux_bp',         'Choc de taux appliqué au portefeuille bancaire pour l''IRRBB',   200.0, 'bp',    '2022-01-01', 'Choix méthodologique interne', datetime('now')),
    ('par-addon-concentration',   'addon_concentration_max',    'Add-on de capital maximal au titre du risque de concentration', 0.15,  'ratio', '2022-01-01', 'Choix méthodologique interne', datetime('now')),
    ('par-horizon-plan-capital',  'horizon_plan_capital_annees','Horizon de la planification du capital',                        3.0,   'annees','2022-01-01', 'Choix méthodologique interne', datetime('now'));

-- --------------------------------------------------------------------------
-- Corrélations par défaut entre grandes familles de risques (moitié
-- supérieure de la matrice, risque_a < risque_b par ordre alphabétique).
-- Table SANS clé étrangère : c'est un gabarit, pas une donnée d'exercice.
-- À la création d'un exercice, le service recopie ces lignes dans
-- icaap_correlation, où elles deviennent éditables pour cet exercice.
-- Valeurs prudentes et documentées ; choix méthodologique interne à valider.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icaap_correlation_defaut (
    id           TEXT PRIMARY KEY,
    risque_a     TEXT NOT NULL,
    risque_b     TEXT NOT NULL,
    coefficient  REAL NOT NULL DEFAULT 0 CHECK (coefficient BETWEEN -1 AND 1),
    cree_le      TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_icaap_correlation_defaut_paire
    ON icaap_correlation_defaut(risque_a, risque_b);

INSERT OR IGNORE INTO icaap_correlation_defaut (id, risque_a, risque_b, coefficient, cree_le) VALUES
    ('corr-def-credit-marche',              'credit',        'marche',        0.50, datetime('now')),
    ('corr-def-credit-operationnel',        'credit',        'operationnel',  0.30, datetime('now')),
    ('corr-def-credit-taux',                'credit',        'taux',          0.40, datetime('now')),
    ('corr-def-concentration-credit',       'concentration', 'credit',        0.60, datetime('now')),
    ('corr-def-marche-operationnel',        'marche',        'operationnel',  0.20, datetime('now')),
    ('corr-def-marche-taux',                'marche',        'taux',          0.50, datetime('now')),
    ('corr-def-concentration-marche',       'concentration', 'marche',        0.30, datetime('now')),
    ('corr-def-operationnel-taux',          'operationnel',  'taux',          0.20, datetime('now')),
    ('corr-def-concentration-taux',         'concentration', 'taux',          0.25, datetime('now')),
    ('corr-def-concentration-operationnel', 'concentration', 'operationnel',  0.20, datetime('now'));
