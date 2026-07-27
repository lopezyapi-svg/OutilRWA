# Guide des Indicateurs Prudentiels & Risques (Risk Management)

**Auteur :** Équipe IT Finance  
**Référentiel :** Dispositif Prudentiel BCEAO / UMOA (Bâle III adapté)  

---

## Introduction

Ce document présente l'ensemble des indicateurs calculés et suivis dans l'application **Risk Management**. 
Chaque métrique est décomposée de manière claire en 3 axes :
1. **À quoi ça sert ?** (Définition financière et rôle)
2. **Comment c'est calculé ?** (Formule réglementaire)
3. **De quoi avons-nous besoin ?** (Données d'entrée nécessaires)

---

## 1. Fonds Propres Réglementaires & Ratios Prudentiels

### 1.1 Fonds Propres Effectifs (FPE)
- **À quoi ça sert ?** Mesure la totalité des ressources financières permanentes de la banque destinées à absorber d'éventuelles pertes.
- **Comment c'est calculé ?**  
  FPE = Tier 1 (Capital de base) + Tier 2 (Complémentaire)  
  *Le Tier 1 regroupe le CET1 (capital social, réserves) et l'AT1. Le Tier 2 inclut les dettes subordonnées et provisions.*
- **De quoi a-t-on besoin ?** Capital social, réserves réglementaires, report à nouveau, résultat éligible, emprunts subordonnés et déductions prudentielles.

### 1.2 Ratio CET1 (Common Equity Tier 1)
- **À quoi ça sert ?** Mesure la couverture des risques uniquement par les fonds propres de la plus haute qualité (actions ordinaires et réserves), capables d'absorber les pertes en continuité d'exploitation.
- **Comment c'est calculé ?**  
  Ratio CET1 = CET1 / RWA Total  
  *Seuil réglementaire Pilier 1 : 5.0% | Seuil cible avec Coussin de conservation : 7.5%*
- **De quoi a-t-on besoin ?** Capital ordinaire, réserves légales, report à nouveau, résultat éligible, déductions CET1 et RWA Total.

### 1.3 Ratio Tier 1 (Capital de Base)
- **À quoi ça sert ?** Évalue la solvabilité fondamentale de l'établissement en incluant le CET1 et les instruments de fonds propres additionnels de catégorie 1 (AT1).
- **Comment c'est calculé ?**  
  Ratio Tier 1 = Tier 1 / RWA Total  
  *Seuil réglementaire Pilier 1 : 6.0% | Seuil cible avec Coussin de conservation : 8.5%*
- **De quoi a-t-on besoin ?** Fonds propres CET1, instruments additionnels AT1 (actions de préférence...) et RWA Total.

### 1.4 Ratio de Solvabilité Globale (CAR - Capital Adequacy Ratio)
- **À quoi ça sert ?** Vérifie que la banque possède un niveau de capital total (FPE) suffisant pour couvrir l'ensemble de ses risques (Crédit, Marché, Opérationnel).
- **Comment c'est calculé ?**  
  Ratio Solvabilité = Fonds Propres Effectifs (FPE) / RWA Total  
  *Seuil réglementaire Pilier 1 : 9.0% | Seuil cible avec Coussin de conservation : 11.5%*
- **De quoi a-t-on besoin ?** Fonds Propres Effectifs (FPE) et montant total des RWA (Crédit + Marché + Opérationnel).

### 1.5 Ratio de Levier
- **À quoi ça sert ?** Mesure de sécurité non basée sur le risque pour éviter un surendettement excessif au bilan et hors-bilan.
- **Comment c'est calculé ?**  
  Ratio Levier = Tier 1 / Expositions Totales (non pondérées)  
  *Seuil réglementaire minimal : 3.0%*
- **De quoi a-t-on besoin ?** Capital Tier 1 et total des expositions brutes bilan + équivalents crédit hors-bilan.

---

## 2. Risque de Crédit & Actifs Pondérés (RWA)

### 2.1 Exposition au Défaut (EAD - Exposure at Default)
- **À quoi ça sert ?** Mesure le montant total du crédit auquel la banque est réellement exposée au moment du défaut.
- **Comment c'est calculé ?**  
  EAD Bilan = Encours Brut au Bilan  
  EAD Hors-Bilan = Nominal x CCF (Facteur de conversion : 0%, 20%, 50%, 100%)  
  EAD Total = EAD Bilan + EAD Hors-Bilan
- **De quoi a-t-on besoin ?** Encours comptable brut au bilan, nominal hors-bilan, type d'engagement.

### 2.2 Actifs Pondérés par le Risque de Crédit (RWA Crédit)
- **À quoi ça sert ?** Ajuste le montant de l'exposition au niveau de risque et de solvabilité de l'emprunteur. Dénominateur principal des ratios de solvabilité.
- **Comment c'est calculé ?**  
  RWA Crédit = EAD x Pondération (%)  
  *La pondération dépend de la classe de contrepartie (Souverain, Banque, PME...) et de la notation (AAA à < B-).*
- **De quoi a-t-on besoin ?** EAD, catégorie prudentielle, notation externe d'agence ou statut non noté.

### 2.3 Exigence de Fonds Propres Crédit (Capital Requis)
- **À quoi ça sert ?** Représente la réserve obligatoire de fonds propres en valeur monétaire (XOF) nécessaire pour couvrir le portefeuille de prêt.
- **Comment c'est calculé ?**  
  Capital Requis Crédit = RWA Crédit x 9.0%  
  *Seuil légal BCEAO : 9.0% (11.5% avec coussin).*
- **De quoi a-t-on besoin ?** RWA Crédit total du portefeuille.

### 2.4 Perte Attendue (EL - Expected Loss)
- **À quoi ça sert ?** Coût moyen statistique du risque sur un an, utilisé pour la tarification des prêts et le provisionnement.
- **Comment c'est calculé ?**  
  EL = PD x LGD x EAD  
  *PD = Probabilité de Défaut (%) | LGD = Taux de perte en cas de défaut (ex: 45%)*
- **De quoi a-t-on besoin ?** PD rattachée à la notation, LGD selon les garanties, EAD.

### 2.5 Perte Inattendue (UL - Unexpected Loss)
- **À quoi ça sert ?** Mesure les pertes extrêmes au-delà de la perte moyenne. Sert à déterminer le capital économique (Vasicek / CreditMetrics).
- **Comment c'est calculé ?**  
  UL = EAD x LGD x sqrt(PD x (1 - PD)) x Z_alpha  
  *Z = Quantile statistique à 99.9% (Z = 3.09).*
- **De quoi a-t-on besoin ?** PD, LGD, EAD et niveau de confiance statistique retenu.

### 2.6 Densité RWA & Taux de Risque
- **À quoi ça sert ?** Évalue la qualité et le profil de risque moyen du portefeuille de prêts.
- **Comment c'est calculé ?**  
  Densité RWA = RWA Crédit Total / EAD Total  
  Taux de Risque = RWA Crédit Total / Exposition Brute Totale
- **De quoi a-t-on besoin ?** RWA Crédit total, EAD total et exposition brute.

### 2.7 Atténuation du Risque de Crédit (CRM) & Économie de Capital
- **À quoi ça sert ?** Mesure la réduction d'exigence de fonds propres permise par l'obtention de garanties éligibles (hypothèques, cautions, avals).
- **Comment c'est calculé ?**  
  Valeur Collatéral Nette = Valeur x (1 - Décote Haircut)  
  Économie RWA = RWA Avant CRM - RWA Après CRM  
  Risque Résiduel = max(0, Exposition Brute - Couverture CRM)
- **De quoi a-t-on besoin ?** Type de garantie, valeur d'expertise, décotes réglementaires (HC, HFX) et notation du garant.

### 2.8 Taux de Défaut & Créances Souffrance (NPL)
- **À quoi ça sert ?** Détecte la dégradation de la qualité des crédits et la dépréciation des créances.
- **Comment c'est calculé ?**  
  Taux de Défaut = Encours en Défaut (>= 90 jours) / Exposition Brute  
  Taux de Couverture NPL = Provisions NPL / Encours NPL x 100
- **De quoi a-t-on besoin ?** Statut prudentiel des lignes (impayés >= 90j), encours dépréciés, provisions individuelles.

---

## 3. Risque Opérationnel

### 3.1 Business Indicator Component (BIC / CRR3)
- **À quoi ça sert ?** Calcule les fonds propres requis pour faire face aux pannes informatiques, fraudes internes/externes, litiges ou erreurs de traitement.
- **Comment c'est calculé ?**  
  BI = Composante Intérêts/Dividendes (ILDC) + Commissions (SC) + Opérations Financières (FC)  
  BIC = Application de tranches marginales (12%, 15%, 18%) sur le BI  
  RWA Opérationnel = BIC x 12.5
- **De quoi a-t-on besoin ?** 12 postes du compte de résultat consolidés sur les 3 derniers exercices.

---

## 4. Risque de Marché & Value at Risk (VaR)

### 4.1 Value at Risk (VaR)
- **À quoi ça sert ?** Mesure la perte maximale potentielle sur les portefeuilles de titres et devises sur un horizon temporel donné (ex: 1 jour) à un niveau de confiance fixé (ex: 99%).
- **Comment c'est calculé ?**  
  VaR Paramétrique = Volatilité x Quantile statistique (Z) x Valeur Portefeuille  
  *(Également modélisé par simulations historiques et Monte Carlo 10 000 tirs).*
- **De quoi a-t-on besoin ?** Historique des prix, cours de change, courbe des taux UMOA/CEMAC et sensibilités des titres.

---

## 5. Synthèse des Ratios Réglementaires BCEAO

| Indicateur | Formule | Pilier 1 (Legal) | Coussin Conservation | Cible Globale |
|---|---|:---:|:---:|:---:|
| **Ratio CET1** | CET1 / RWA Total | **5.0%** | +2.5% | **7.5%** |
| **Ratio Tier 1** | Tier 1 / RWA Total | **6.0%** | +2.5% | **8.5%** |
| **Ratio Solvabilité** | FPE / RWA Total | **9.0%** | +2.5% | **11.5%** |
| **Ratio de Levier** | Tier 1 / Expositions Totales | **3.0%** | — | **3.0%** |

---

## 6. Alertes & Pilotage

- **Taux de Défaut &ge; 5.0%** : Déclenche une alerte sur la qualité des créances.
- **Concentration Clientèle &ge; 35.0%** : Alerte sur la surexposition d'un groupe.
- **Dépassement Grand Risque &ge; 25.0% des FPE** : Dépassement de la limite légale BCEAO.
- **Indice HHI &gt; 0.25** : Signal d'une forte concentration du portefeuille.

---
*Documentation - Risk Management - Conforme au Dispositif Prudentiel BCEAO / UMOA.*
