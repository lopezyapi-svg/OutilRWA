"""Module ICAAP — Pilier 2 du dispositif prudentiel UMOA / BCEAO.

Processus interne d'évaluation de l'adéquation des fonds propres :
cartographie des risques, capital économique, stress tests, planification
du capital et rapport ICAAP.

Comme le module ``fodep``, ce module ne recalcule aucun RWA : il consomme
les résultats des modules ``rwa_credit`` / ``market`` / ``risque_operationnel``.

Lot L1 : schéma (migration 042_icaap.sql) et modèles. Les routes et
services arrivent aux lots suivants.
"""
