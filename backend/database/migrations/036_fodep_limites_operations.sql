-- FODEP — normes EP34 à EP39 : limites sur participations, immobilisations
-- et prêts liés (notice technique BCEAO, RA006 à RA011 de l'EP01).
--
-- Deux mécanismes distincts, fidèles à la structure du classeur officiel :
--
-- 1) fodep_participation : registre ouvert des participations dans des
--    entités commerciales (section D de l'EP34, testée par l'EP35). Une
--    ligne par participation, contrairement aux postes fixes ci-dessous —
--    le nombre de lignes de participations n'est pas borné par la notice.
--
-- 2) Nouveaux postes fixes sur fodep_fonds_propres (EP36, EP37, EP38) : ces
--    états ont une structure figée, même mécanique que les 45 codes déjà
--    portés par la migration 035 (un code DISPRU = une colonne = une
--    valeur). L'Excel officiel présente ces postes en couple brut/net, mais
--    seul le montant net alimente les formules de seuil (EP36 c/d, EP37 c/d,
--    EP38 j/k) : le brut est un détail d'audit non repris ici, comme le sont
--    déjà la plupart des 45 postes de la migration 035.
--    - EP36 : im001, im002, im003 (immobilisations hors exploitation, avant
--      IM004/IM005 qui restent calculés, jamais saisis)
--    - EP37 : im007 (immobilisations d'exploitation ajustées), pa106 (total
--      des participations, toutes sections de l'EP34 confondues — distinct
--      du registre fodep_participation qui ne couvre que la section
--      « entités commerciales »)
--    - EP38 : pr001 et pr002 (montant des concours / engagements par
--      signature), une colonne par catégorie de bénéficiaire (a à h, dans
--      l'ordre de la notice : actionnaires ≥10 %, organe délibérant, organe
--      exécutif, commissaires aux comptes, personnel de direction, cadres,
--      personnel d'exécution, autres parties liées)
--
-- pa149, im006, im010 et pr004 (déjà présents depuis la migration 035)
-- restent la saisie manuelle de repli : le service applicatif les recalcule
-- automatiquement dès que ce nouveau registre/postes contiennent des
-- données, sans casser les espaces qui n'en ont pas encore.

CREATE TABLE IF NOT EXISTS fodep_participation (
    id TEXT PRIMARY KEY,
    periode TEXT NOT NULL,
    denomination_emettrice TEXT NOT NULL DEFAULT '',
    capital_emettrice REAL NOT NULL DEFAULT 0,
    montant_net REAL NOT NULL DEFAULT 0,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fodep_participation_periode
    ON fodep_participation(periode);

ALTER TABLE fodep_fonds_propres ADD COLUMN im001 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN im002 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN im003 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN im007 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pa084 REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pa106 REAL NOT NULL DEFAULT 0;

ALTER TABLE fodep_fonds_propres ADD COLUMN pr001a REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr001b REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr001c REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr001d REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr001e REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr001f REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr001g REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr001h REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002a REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002b REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002c REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002d REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002e REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002f REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002g REAL NOT NULL DEFAULT 0;
ALTER TABLE fodep_fonds_propres ADD COLUMN pr002h REAL NOT NULL DEFAULT 0;
