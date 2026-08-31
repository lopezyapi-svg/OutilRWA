-- FODEP — Signature de l'attestation de déclaration prudentielle.
--
-- La notice technique exige que l'attestation soit revêtue de la signature de
-- l'établissement. On stocke désormais l'image de la signature (dessinée à la
-- main dans l'interface ou importée depuis un fichier) côté application, en
-- base64, et on l'injecte dans le bloc de signature de l'onglet ATTESTATION
-- (donc présente à la fois dans le fichier Excel et, par conversion fidèle,
-- dans le PDF).

ALTER TABLE fodep_attestation ADD COLUMN signature TEXT;
