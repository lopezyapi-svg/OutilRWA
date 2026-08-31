-- FODEP — Attestation de déclaration prudentielle.
--
-- La notice technique BCEAO / DISPRU exige qu'une attestation de véracité
-- accompagne la déclaration (signée par la direction et le commissaire aux
-- comptes). Jusqu'ici l'export FODEP ne contenait aucune page d'attestation :
-- l'établissement devait la produire à part. On stocke désormais, côte
-- application, les éléments de l'attestation (déclarant, qualité, fonction,
-- lieu, date, corps du texte) et on les injecte dans un onglet dédié du
-- classeur officiel — donc présents à la fois dans le fichier Excel et, par
-- conversion fidèle, dans le PDF.
--
-- Un seul enregistrement est conservé (comme pour fodep_etablissement) : il
-- s'agit de la signature « type » de l'établissement, réutilisée d'un arrêté
-- à l'autre. Le texte par défaut est fourni par le service si l'utilisateur
-- ne le personnalise pas.

CREATE TABLE IF NOT EXISTS fodep_attestation (
    id                TEXT PRIMARY KEY,
    nom_declarant     TEXT NOT NULL DEFAULT '',
    qualite          TEXT NOT NULL DEFAULT '',
    lieu             TEXT NOT NULL DEFAULT '',
    date_signature   TEXT,
    texte_attestation TEXT NOT NULL DEFAULT '',
    cree_le          TEXT NOT NULL,
    modifie_le       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fodep_attestation_modif
    ON fodep_attestation(modifie_le);
