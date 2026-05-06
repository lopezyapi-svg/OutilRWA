// Ce fichier decrit les donnees et regles du module expositions.

String _normalizeExposureLabel(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll("'", ' ')
      .replaceAll('’', ' ')
      .replaceAll('-', ' ')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ô', 'o')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class ExposureCategoryOption {
  const ExposureCategoryOption({
    required this.code,
    required this.label,
    required this.prudentialLabel,
    this.legacyLabel,
    this.fixedRiskWeight,
  });

  final String code;
  final String label;
  final String prudentialLabel;
  final String? legacyLabel;
  final double? fixedRiskWeight;
}

const List<ExposureCategoryOption> exposureCategories = [
  ExposureCategoryOption(
    code: 'a',
    label: 'Souverains',
    prudentialLabel: '(a) souverains',
    legacyLabel: 'Souverains',
  ),
  ExposureCategoryOption(
    code: 'b',
    label: 'Organismes publics',
    prudentialLabel: '(b) organismes pub. hors Adm c',
  ),
  ExposureCategoryOption(
    code: 'c',
    label: 'BMD',
    prudentialLabel: '(c) Expositions sur les BMD',
  ),
  ExposureCategoryOption(
    code: 'd',
    label: 'Institutions financieres',
    prudentialLabel: '(d) institutions financieres',
    legacyLabel: 'Banques',
  ),
  ExposureCategoryOption(
    code: 'e',
    label: 'Entreprises',
    prudentialLabel: '(e) entreprises',
    legacyLabel: 'Entreprises',
  ),
  ExposureCategoryOption(
    code: 'f',
    label: 'Clientele de detail',
    prudentialLabel: '(f) clientele de detail',
    legacyLabel: 'Particuliers',
  ),
  ExposureCategoryOption(
    code: 'g',
    label: 'Immobilier residentiel',
    prudentialLabel: "(g) prêts garantis par l'immo R",
    fixedRiskWeight: 0.35,
  ),
  ExposureCategoryOption(
    code: 'h',
    label: 'Immobilier commercial',
    prudentialLabel: "(h) prêts garantis par l'immo C",
    fixedRiskWeight: 0.75,
  ),
  ExposureCategoryOption(
    code: 'i',
    label: 'Creances en souffrance',
    prudentialLabel: '(i) creances en souffrance',
    fixedRiskWeight: 1.5,
  ),
  ExposureCategoryOption(
    code: 'j',
    label: 'Créances à risque élevé',
    prudentialLabel: '(j) créances à risque élevé',
    legacyLabel: 'Risque eleve',
    fixedRiskWeight: 1.5,
  ),
  ExposureCategoryOption(
    code: 'k',
    label: 'Autres actifs',
    prudentialLabel: '(k) autres actifs',
  ),
  ExposureCategoryOption(
    code: 'l',
    label: 'Hors bilan',
    prudentialLabel: '(l) Hors bilan',
  ),
];

const List<String> financedCrmIssuerTypes = [
  'souverain',
  'autre',
];

const List<String> financedCrmCollateralRatings = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'non_noté_état_umoa',
  'garanti_brvm',
  'bancaire_non_noté',
  'actions_brvm',
  'autres_actions',
  'opcvm',
  'liquidité',
];

const List<String> prudentialRatings = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'B+',
  'B',
  'B-',
  '< B-',
  'Non noté',
];

const List<String> enterpriseRatingOptions = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  '< BB-',
  'Non noté',
];

const double residentialMortgageEligibleRiskWeight = 0.35;
const double commercialRealEstateEligibleRiskWeight = 0.75;
const List<double> defaultedExposureInitialRiskWeightOptions = [
  0.2,
  0.35,
  0.5,
  0.75,
  1.0,
  1.5,
  2.5,
];

const List<String> financedCrmMaturityBuckets = [
  '<=1 an',
  '1-3 ans',
  '3-5 ans',
  '5-10 ans',
  '>10 ans',
];

const List<String> guarantorEligibleCategoryCodes = [
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'k',
];

const String sovereignNoSpecialCase = 'Aucun de ces cas';
const String sovereignLegacySpecialCase = 'Cas préférentiel 0 % (historique)';
const List<String> sovereignZeroWeightSpecialCases = [
  'Expositions sur États de l’UEMOA et démembrements libellées et financées en FCFA',
  'Expositions sur BCEAO libellées et financées en FCFA',
  'UEMOA',
  'CEDEAO',
  'UA',
  'UE',
  'ONU',
  'BRI',
  'FMI',
  'BCE',
  'FGD-UMOA',
];
const List<String> sovereignSpecialCaseOptions = [
  ...sovereignZeroWeightSpecialCases,
  sovereignNoSpecialCase,
];
const List<String> sovereignRatingOptions = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'B+',
  'B',
  'B-',
  '< B-',
  'Non noté',
];

String coerceSovereignSpecialCase(
  String? value, {
  bool fallbackToLegacy = false,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    final normalized = _normalizeExposureLabel(trimmed);
    if (normalized == _normalizeExposureLabel(sovereignLegacySpecialCase)) {
      return sovereignLegacySpecialCase;
    }
    if (normalized == _normalizeExposureLabel(sovereignNoSpecialCase)) {
      return sovereignNoSpecialCase;
    }
    for (final option in sovereignZeroWeightSpecialCases) {
      if (_normalizeExposureLabel(option) == normalized) {
        return option;
      }
    }
  }
  return fallbackToLegacy ? sovereignLegacySpecialCase : sovereignNoSpecialCase;
}

bool hasSovereignPriorityZeroWeightCase(
  String? sovereignSpecialCase, {
  bool sovereignPreferentialZeroWeight = false,
}) {
  final normalized = coerceSovereignSpecialCase(
    sovereignSpecialCase,
    fallbackToLegacy: sovereignPreferentialZeroWeight,
  );
  return sovereignZeroWeightSpecialCases.contains(normalized) ||
      normalized == sovereignLegacySpecialCase ||
      sovereignPreferentialZeroWeight;
}

const Map<String, double> currencyRatesInXaf = {
  'XAF': 1.0,
  'XOF': 1.0,
  'EUR': 655.957,
  'USD': 600.0,
};

const Map<String, String> _financedCrmCollateralRatingLabelsByKey = {
  'AAA': 'AAA',
  'AA+': 'AA+',
  'AA': 'AA',
  'AA-': 'AA-',
  'A+': 'A+',
  'A': 'A',
  'A-': 'A-',
  'BBB+': 'BBB+',
  'BBB': 'BBB',
  'BBB-': 'BBB-',
  'BB+': 'BB+',
  'BB': 'BB',
  'BB-': 'BB-',
  'NON_NOTE_ETAT_UMOA': 'non_noté_état_umoa',
  'GARANTI_BRVM': 'garanti_brvm',
  'BANCAIRE_NON_NOTE': 'bancaire_non_noté',
  'ACTIONS_BRVM': 'actions_brvm',
  'AUTRES_ACTIONS': 'autres_actions',
  'OPCVM': 'opcvm',
  'LIQUIDITE': 'liquidité',
};

ExposureCategoryOption exposureCategoryByCode(String code) {
  return exposureCategories.firstWhere(
    (item) => item.code == code,
    orElse: () => exposureCategories[4],
  );
}

ExposureCategoryOption exposureCategoryByName(String label) {
  final normalized = _normalizeExposureLabel(label);
  return exposureCategories.firstWhere(
    (item) =>
        _normalizeExposureLabel(item.label) == normalized ||
        _normalizeExposureLabel(item.prudentialLabel) == normalized ||
        _normalizeExposureLabel(item.legacyLabel ?? '') == normalized,
    orElse: () => exposureCategories[4],
  );
}

List<ExposureCategoryOption> get guarantorEligibleCategories =>
    exposureCategories
        .where((item) => guarantorEligibleCategoryCodes.contains(item.code))
        .toList(growable: false);

String normalizeFinancedCrmCollateralRating(String rating) {
  return rating
      .trim()
      .toUpperCase()
      .replaceAll('É', 'E')
      .replaceAll('È', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Î', 'I')
      .replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O')
      .replaceAll('Û', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ç', 'C')
      .replaceAll(' ', '_');
}

String coerceFinancedCrmCollateralRating(String rating) {
  final normalized = normalizeFinancedCrmCollateralRating(rating);
  return _financedCrmCollateralRatingLabelsByKey[normalized] ??
      (financedCrmCollateralRatings.contains(rating)
          ? rating
          : financedCrmCollateralRatings.first);
}

String bucketizeRating(String rating) {
  final normalized = rating.trim().toUpperCase();
  if (normalized == 'AAA/AA') {
    return 'AAA/AA';
  }
  if (normalized == 'BB/B') {
    return 'BB/B';
  }
  if (['AAA', 'AA+', 'AA', 'AA-'].contains(normalized)) {
    return 'AAA/AA';
  }
  if (['A+', 'A', 'A-'].contains(normalized)) {
    return 'A';
  }
  if (['BBB+', 'BBB', 'BBB-'].contains(normalized)) {
    return 'BBB';
  }
  if (['BB+', 'BB', 'BB-', 'B+', 'B', 'B-'].contains(normalized)) {
    return 'BB/B';
  }
  if (normalized == '< B-') {
    return '< B-';
  }
  return 'Non noté';
}

double lookupSovereignOceRiskWeight(String note) {
  switch (note.trim()) {
    case '0':
    case '1':
      return 0.0;
    case '2':
      return 0.2;
    case '3':
      return 0.5;
    case '4':
    case '5':
    case '6':
      return 1.0;
    case '7':
      return 1.5;
    default:
      return 1.0;
  }
}

const String bankInstitutionEquivalentRulesCase = 'equivalent_umoa_rules';
const String bankInstitutionWeakPrudentialCase = 'weak_prudential_case';
const String bankInstitutionEligibleCategoriesCase = 'eligible_categories_case';

const List<String> bankInstitutionCaseOptions = [
  bankInstitutionEquivalentRulesCase,
  bankInstitutionWeakPrudentialCase,
  bankInstitutionEligibleCategoriesCase,
];

String bankInstitutionCaseLabel(String value) {
  switch (value) {
    case bankInstitutionEquivalentRulesCase:
      return "Banque hors UMOA soumise à des règles équivalentes à celles de l'UMOA";
    case bankInstitutionWeakPrudentialCase:
      return 'Banque en difficulté prudentielle';
    case bankInstitutionEligibleCategoriesCase:
      return 'Institution faisant partie des categories suivantes :';
    default:
      return "Banque hors UMOA soumise à des règles équivalentes à celles de l'UMOA";
  }
}

const String otherAssetCashType = 'Encaisse';
const String otherAssetCashEquivalentType =
    'Valeurs assimilées à l’encaisse, y compris l’or';
const String otherAssetImmediateCollectionType =
    'Valeurs à l’encaissement avec crédit immédiat';
const String otherAssetNonSignificantParticipationsType =
    'Participations non significatives non déduites des fonds propres';
const String otherAssetTangibleFixedAssetsType = 'Immobilisations corporelles';
const String otherAssetMiscellaneousType = 'Autres actifs divers';
const String otherAssetEquityCommitmentsType =
    'Engagements en actions non déduits';
const String otherAssetNonEquivalentFinancialCompaniesType =
    'Expositions sur entreprises financières non soumises à une réglementation équivalente UMOA';
const String otherAssetUndefinedType = 'Autres éléments d’actifs non définis';
const String otherAssetSignificantParticipationsAndDtaType =
    'Participations significatives et impôts différés actifs non déduits';
const String otherAssetNonCompliantInstitutionsType =
    'Expositions sur établissements non conformes aux ratios de solvabilité';

const List<String> otherAssetTypeOptions = [
  otherAssetCashType,
  otherAssetCashEquivalentType,
  otherAssetImmediateCollectionType,
  otherAssetNonSignificantParticipationsType,
  otherAssetTangibleFixedAssetsType,
  otherAssetMiscellaneousType,
  otherAssetEquityCommitmentsType,
  otherAssetNonEquivalentFinancialCompaniesType,
  otherAssetUndefinedType,
  otherAssetSignificantParticipationsAndDtaType,
  otherAssetNonCompliantInstitutionsType,
];

const String offBalanceLowRiskLevel = 'Risque faible';
const String offBalanceMinorRiskLevel = 'Risque mineur';
const String offBalanceMediumRiskLevel = 'Risque moyen';
const String offBalanceHighRiskLevel = 'Risque élevé';
const String offBalanceVeryHighRiskLevel = 'Risque très élevé';

const List<String> offBalanceRiskLevelOptions = [
  offBalanceLowRiskLevel,
  offBalanceMinorRiskLevel,
  offBalanceMediumRiskLevel,
  offBalanceHighRiskLevel,
  offBalanceVeryHighRiskLevel,
];

String? coerceOtherAssetType(
  String? value, {
  bool fallbackToUndefined = false,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    final normalized = _normalizeExposureLabel(trimmed);
    for (final option in otherAssetTypeOptions) {
      if (normalized == _normalizeExposureLabel(option)) {
        return option;
      }
    }
    if (normalized == _normalizeExposureLabel('Autres actifs')) {
      return otherAssetUndefinedType;
    }
  }
  return fallbackToUndefined ? otherAssetUndefinedType : null;
}

double lookupOtherAssetRiskWeight(String? otherAssetType) {
  switch (coerceOtherAssetType(otherAssetType, fallbackToUndefined: true)) {
    case otherAssetCashType:
    case otherAssetCashEquivalentType:
      return 0.0;
    case otherAssetImmediateCollectionType:
      return 0.2;
    case otherAssetSignificantParticipationsAndDtaType:
    case otherAssetNonCompliantInstitutionsType:
      return 2.5;
    default:
      return 1.0;
  }
}

String? inferOffBalanceRiskLevelFromFactor(double? factor) {
  if (factor == null) {
    return null;
  }
  const epsilon = 0.0001;
  if ((factor - 0.1).abs() <= epsilon) {
    return offBalanceLowRiskLevel;
  }
  if ((factor - 0.2).abs() <= epsilon) {
    return offBalanceMinorRiskLevel;
  }
  if ((factor - 0.5).abs() <= epsilon) {
    return offBalanceMediumRiskLevel;
  }
  if ((factor - 0.75).abs() <= epsilon) {
    return offBalanceHighRiskLevel;
  }
  if ((factor - 1.0).abs() <= epsilon) {
    return offBalanceVeryHighRiskLevel;
  }
  return null;
}

String? coerceOffBalanceRiskLevel(
  String? value, {
  bool fallbackToVeryHigh = false,
  double? factorHint,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    final normalized = _normalizeExposureLabel(trimmed);
    for (final option in offBalanceRiskLevelOptions) {
      if (normalized == _normalizeExposureLabel(option)) {
        return option;
      }
    }
  }
  final inferred = inferOffBalanceRiskLevelFromFactor(factorHint);
  if (inferred != null) {
    return inferred;
  }
  return fallbackToVeryHigh ? offBalanceVeryHighRiskLevel : null;
}

double lookupOffBalanceFcec(String? offBalanceRiskLevel) {
  switch (coerceOffBalanceRiskLevel(
    offBalanceRiskLevel,
    fallbackToVeryHigh: true,
  )) {
    case offBalanceLowRiskLevel:
      return 0.1;
    case offBalanceMinorRiskLevel:
      return 0.2;
    case offBalanceMediumRiskLevel:
      return 0.5;
    case offBalanceHighRiskLevel:
      return 0.75;
    case offBalanceVeryHighRiskLevel:
    default:
      return 1.0;
  }
}

double lookupEnterpriseRiskWeight(
  String rating, {
  bool enterpriseExceedsBceaoDegradationThreshold = false,
  bool enterprisePrudentialProcedure = false,
}) {
  if (enterpriseExceedsBceaoDegradationThreshold ||
      enterprisePrudentialProcedure) {
    return 1.5;
  }
  final normalized = rating.trim().toUpperCase();
  if (['AAA', 'AA+', 'AA', 'AA-'].contains(normalized)) {
    return 0.2;
  }
  if (['A+', 'A', 'A-'].contains(normalized)) {
    return 0.5;
  }
  if (['BBB+', 'BBB', 'BBB-', 'BB+', 'BB', 'BB-'].contains(normalized)) {
    return 1.0;
  }
  if (['< BB-', 'B+', 'B', 'B-', '< B-'].contains(normalized)) {
    return 1.5;
  }
  return 1.0;
}

double lookupResidentialMortgageRiskWeight(bool? isEligible) {
  return isEligible == true ? residentialMortgageEligibleRiskWeight : 1.0;
}

double lookupCommercialRealEstateRiskWeight(bool? isEligible) {
  return isEligible == true ? commercialRealEstateEligibleRiskWeight : 1.0;
}

double lookupDefaultedExposureRiskWeight(
  double? initialRiskWeight, {
  bool? isResidentialMortgageInDefault,
  bool? provisionAtLeastTwentyPercent,
}) {
  final resolvedInitialRiskWeight =
      (initialRiskWeight ?? 1.0).clamp(0.0, 2.5).toDouble();
  if (resolvedInitialRiskWeight > 1.0) {
    return resolvedInitialRiskWeight;
  }
  if (isResidentialMortgageInDefault == true) {
    return 1.0;
  }
  if (isResidentialMortgageInDefault == false) {
    if (provisionAtLeastTwentyPercent == true) {
      return 1.0;
    }
    if (provisionAtLeastTwentyPercent == false) {
      return 1.5;
    }
  }
  return resolvedInitialRiskWeight;
}

String? coerceBankInstitutionCase(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = _normalizeExposureLabel(value);
  for (final option in bankInstitutionCaseOptions) {
    if (normalized == _normalizeExposureLabel(option)) {
      return option;
    }
  }
  if (normalized.contains('equival') && normalized.contains('umoa')) {
    return bankInstitutionEquivalentRulesCase;
  }
  if (normalized.contains('degrad') ||
      normalized.contains('solvabil') ||
      normalized.contains('fonds propres')) {
    return bankInstitutionWeakPrudentialCase;
  }
  if (normalized.contains('categor') && normalized.contains('banc')) {
    return bankInstitutionEligibleCategoriesCase;
  }
  return null;
}

bool hasShortInitialMaturity(DateTime? grantDate, DateTime? maturityDate) {
  if (grantDate == null || maturityDate == null) {
    return false;
  }
  return computeInitialMaturityMonths(grantDate, maturityDate) <= 3;
}

int computeInitialMaturityMonths(DateTime grantDate, DateTime maturityDate) {
  var months = (maturityDate.year - grantDate.year) * 12 +
      maturityDate.month -
      grantDate.month;
  if (maturityDate.day < grantDate.day) {
    months -= 1;
  }
  return months < 0 ? 0 : months;
}

double lookupBankInstitutionRiskWeight(
  String rating, {
  required bool isShortInitialMaturity,
}) {
  final ratingBucket = bucketizeRating(rating);
  if (isShortInitialMaturity) {
    switch (ratingBucket) {
      case 'AAA/AA':
      case 'A':
      case 'BBB':
        return 0.2;
      case 'BB/B':
        return 0.5;
      case '< B-':
        return 1.5;
      default:
        return 0.2;
    }
  }
  switch (ratingBucket) {
    case 'AAA/AA':
      return 0.2;
    case 'A':
      return 0.5;
    case 'BBB':
      return 0.5;
    case 'BB/B':
      return 1.0;
    case '< B-':
      return 1.5;
    default:
      return 0.5;
  }
}

double lookupPrudentialRiskWeight(
  String categoryCode,
  String rating, {
  String sovereignSpecialCase = sovereignNoSpecialCase,
  bool sovereignPreferentialZeroWeight = false,
  bool sovereignOceEstablished = false,
  String sovereignOceNote = '',
  bool? publicBodyUemoaFcfaCase,
  bool? publicBodyFinancesNonPublicActivity,
  bool? bmdHighQualityCase,
  bool? bmdUemoaFcfaCase,
  bool? bmdUemoaCriteriaSatisfied,
  bool? bmdListedInstitutionFcfaCase,
  String? bankInstitutionCase,
  String? otherAssetType,
  String? offBalanceRiskLevel,
  bool? retailEligibilityCriteriaSatisfied,
  bool? enterpriseExceedsBceaoDegradationThreshold,
  bool? enterprisePrudentialProcedure,
  bool? enterpriseInvestmentFirmWithoutBankingLaw,
  bool? residentialMortgageEligible,
  bool? commercialRealEstateEligible,
  double? defaultedExposureInitialRiskWeight,
  bool? defaultedExposureResidentialMortgageInDefault,
  bool? defaultedExposureProvisionAtLeastTwentyPercent,
  DateTime? grantDate,
  DateTime? maturityDate,
}) {
  final category = exposureCategoryByCode(categoryCode);
  final ratingBucket = bucketizeRating(rating);
  if (categoryCode == 'a' &&
      hasSovereignPriorityZeroWeightCase(
        sovereignSpecialCase,
        sovereignPreferentialZeroWeight: sovereignPreferentialZeroWeight,
      )) {
    return 0.0;
  }
  if (categoryCode == 'a' &&
      ratingBucket == 'Non noté' &&
      sovereignOceEstablished) {
    return lookupSovereignOceRiskWeight(sovereignOceNote);
  }
  if (categoryCode == 'b' &&
      hasPublicBodyPreferentialUemoaCase(
        publicBodyUemoaFcfaCase,
        publicBodyFinancesNonPublicActivity,
      )) {
    return publicBodyUemoaFcfaRiskWeight;
  }
  if (categoryCode == 'b' &&
      hasPublicBodyEnterpriseOverride(
        publicBodyUemoaFcfaCase,
        publicBodyFinancesNonPublicActivity,
      )) {
    return lookupPrudentialRiskWeight('e', rating);
  }
  if (categoryCode == 'c' &&
      hasBmdPriorityZeroWeightCase(
        bmdHighQualityCase: bmdHighQualityCase,
        bmdUemoaFcfaCase: bmdUemoaFcfaCase,
        bmdUemoaCriteriaSatisfied: bmdUemoaCriteriaSatisfied,
        bmdListedInstitutionFcfaCase: bmdListedInstitutionFcfaCase,
      )) {
    return 0.0;
  }
  if (categoryCode == 'd') {
    final resolvedBankInstitutionCase =
        coerceBankInstitutionCase(bankInstitutionCase);
    if (resolvedBankInstitutionCase == bankInstitutionEquivalentRulesCase) {
      return 1.0;
    }
    if (resolvedBankInstitutionCase == bankInstitutionWeakPrudentialCase) {
      return 2.5;
    }
    if (resolvedBankInstitutionCase == bankInstitutionEligibleCategoriesCase) {
      return lookupBankInstitutionRiskWeight(
        rating,
        isShortInitialMaturity:
            hasShortInitialMaturity(grantDate, maturityDate),
      );
    }
  }
  if (categoryCode == 'e') {
    return lookupEnterpriseRiskWeight(
      rating,
      enterpriseExceedsBceaoDegradationThreshold:
          enterpriseExceedsBceaoDegradationThreshold == true,
      enterprisePrudentialProcedure: enterprisePrudentialProcedure == true,
    );
  }
  if (categoryCode == 'g') {
    return lookupResidentialMortgageRiskWeight(residentialMortgageEligible);
  }
  if (categoryCode == 'h') {
    if (commercialRealEstateEligible == false) {
      return lookupPrudentialRiskWeight(
        'e',
        rating,
        enterpriseExceedsBceaoDegradationThreshold:
            enterpriseExceedsBceaoDegradationThreshold,
        enterprisePrudentialProcedure: enterprisePrudentialProcedure,
        enterpriseInvestmentFirmWithoutBankingLaw:
            enterpriseInvestmentFirmWithoutBankingLaw,
      );
    }
    return lookupCommercialRealEstateRiskWeight(commercialRealEstateEligible);
  }
  if (categoryCode == 'i') {
    return lookupDefaultedExposureRiskWeight(
      defaultedExposureInitialRiskWeight,
      isResidentialMortgageInDefault:
          defaultedExposureResidentialMortgageInDefault,
      provisionAtLeastTwentyPercent:
          defaultedExposureProvisionAtLeastTwentyPercent,
    );
  }
  if (categoryCode == 'f') {
    if (retailEligibilityCriteriaSatisfied == false) {
      return lookupPrudentialRiskWeight(
        'e',
        rating,
        enterpriseExceedsBceaoDegradationThreshold:
            enterpriseExceedsBceaoDegradationThreshold,
        enterprisePrudentialProcedure: enterprisePrudentialProcedure,
        enterpriseInvestmentFirmWithoutBankingLaw:
            enterpriseInvestmentFirmWithoutBankingLaw,
        grantDate: grantDate,
        maturityDate: maturityDate,
      );
    }
    return 0.75;
  }
  if (categoryCode == 'k') {
    return lookupOtherAssetRiskWeight(otherAssetType);
  }
  if (categoryCode == 'l') {
    return lookupOffBalanceFcec(offBalanceRiskLevel);
  }
  if (category.fixedRiskWeight != null) {
    return category.fixedRiskWeight!;
  }

  switch (categoryCode) {
    case 'a':
      switch (ratingBucket) {
        case 'AAA/AA':
          return 0.0;
        case 'A':
          return 0.2;
        case 'BBB':
          return 0.5;
        case 'BB/B':
          return 1.0;
        case '< B-':
          return 1.5;
        default:
          return 1.0;
      }
    case 'b':
      switch (ratingBucket) {
        case 'AAA/AA':
          return 0.2;
        case 'A':
          return 0.5;
        case 'BBB':
          return 1.0;
        case 'BB/B':
          return 1.0;
        case '< B-':
          return 1.5;
        default:
          return 1.0;
      }
    case 'c':
      switch (ratingBucket) {
        case 'AAA/AA':
          return 0.2;
        case 'A':
          return 0.5;
        case 'BBB':
          return 0.5;
        case 'BB/B':
          return 1.0;
        case '< B-':
          return 1.5;
        default:
          return 0.5;
      }
    case 'd':
      switch (ratingBucket) {
        case 'AAA/AA':
          return 0.2;
        case 'A':
          return 0.5;
        case 'BBB':
          return 0.5;
        case 'BB/B':
          return 1.0;
        case '< B-':
          return 1.5;
        default:
          return 1.0;
      }
    default:
      return 1.0;
  }
}

const List<String> uemoaCountries = [
  'Benin',
  'Burkina Faso',
  'Cote d Ivoire',
  'Guinee-Bissau',
  'Mali',
  'Niger',
  'Senegal',
  'Togo',
];

const List<String> cemacCountries = [
  'Cameroun',
  'Centrafrique',
  'Tchad',
  'Congo',
  'Gabon',
  'Guinee equatoriale',
];

const List<String> worldCountries = [
  'Afghanistan',
  'Afrique du Sud',
  'Albanie',
  'Algerie',
  'Allemagne',
  'Andorre',
  'Angola',
  'Antigua-et-Barbuda',
  'Arabie saoudite',
  'Argentine',
  'Armenie',
  'Australie',
  'Autriche',
  'Azerbaidjan',
  'Bahamas',
  'Bahrein',
  'Bangladesh',
  'Barbade',
  'Belgique',
  'Belize',
  'Benin',
  'Bhoutan',
  'Bielorussie',
  'Birmanie',
  'Bolivie',
  'Bosnie-Herzegovine',
  'Botswana',
  'Bresil',
  'Brunei',
  'Bulgarie',
  'Burkina Faso',
  'Burundi',
  'Cambodge',
  'Cameroun',
  'Canada',
  'Cap-Vert',
  'Centrafrique',
  'Chili',
  'Chine',
  'Chypre',
  'Colombie',
  'Comores',
  'Congo',
  'Coree du Nord',
  'Coree du Sud',
  'Costa Rica',
  "Cote d'Ivoire",
  'Croatie',
  'Cuba',
  'Danemark',
  'Djibouti',
  'Dominique',
  'Egypte',
  'Emirats arabes unis',
  'Equateur',
  'Erythree',
  'Espagne',
  'Estonie',
  'Eswatini',
  'Etats-Unis',
  'Ethiopie',
  'Fidji',
  'Finlande',
  'France',
  'Gabon',
  'Gambie',
  'Georgie',
  'Ghana',
  'Grece',
  'Grenade',
  'Guatemala',
  'Guinee',
  'Guinee-Bissau',
  'Guinee equatoriale',
  'Guyana',
  'Haiti',
  'Honduras',
  'Hongrie',
  'Iles Marshall',
  'Iles Salomon',
  'Inde',
  'Indonesie',
  'Irak',
  'Iran',
  'Irlande',
  'Islande',
  'Israel',
  'Italie',
  'Jamaïque',
  'Japon',
  'Jordanie',
  'Kazakhstan',
  'Kenya',
  'Kirghizistan',
  'Kiribati',
  'Kosovo',
  'Koweit',
  'Laos',
  'Lesotho',
  'Lettonie',
  'Liban',
  'Liberia',
  'Libye',
  'Liechtenstein',
  'Lituanie',
  'Luxembourg',
  'Macedoine du Nord',
  'Madagascar',
  'Malaisie',
  'Malawi',
  'Maldives',
  'Mali',
  'Malte',
  'Maroc',
  'Maurice',
  'Mauritanie',
  'Mexique',
  'Micronesie',
  'Moldavie',
  'Monaco',
  'Mongolie',
  'Montenegro',
  'Mozambique',
  'Namibie',
  'Nauru',
  'Nepal',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'Norvege',
  'Nouvelle-Zelande',
  'Oman',
  'Ouganda',
  'Ouzbekistan',
  'Pakistan',
  'Palaos',
  'Palestine',
  'Panama',
  'Papouasie-Nouvelle-Guinee',
  'Paraguay',
  'Pays-Bas',
  'Perou',
  'Philippines',
  'Pologne',
  'Portugal',
  'Qatar',
  'Republique centrafricaine',
  'Republique democratique du Congo',
  'Republique dominicaine',
  'Republique tcheque',
  'Roumanie',
  'Royaume-Uni',
  'Russie',
  'Rwanda',
  'Saint-Christophe-et-Nieves',
  'Sainte-Lucie',
  'Saint-Marin',
  'Saint-Vincent-et-les-Grenadines',
  'Salvador',
  'Samoa',
  'Sao Tome-et-Principe',
  'Senegal',
  'Serbie',
  'Seychelles',
  'Sierra Leone',
  'Singapour',
  'Slovaquie',
  'Slovenie',
  'Somalie',
  'Soudan',
  'Soudan du Sud',
  'Sri Lanka',
  'Suede',
  'Suisse',
  'Suriname',
  'Syrie',
  'Tadjikistan',
  'Taiwan',
  'Tanzanie',
  'Tchad',
  'Thailande',
  'Timor oriental',
  'Togo',
  'Tonga',
  'Trinite-et-Tobago',
  'Tunisie',
  'Turkmenistan',
  'Turquie',
  'Tuvalu',
  'Ukraine',
  'Uruguay',
  'Vanuatu',
  'Vatican',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambie',
  'Zimbabwe',
];

const List<String> managedCountries = [
  ...uemoaCountries,
  ...cemacCountries,
  'France',
  'Allemagne',
  'Espagne',
  'Italie',
  'Maroc',
  'Tunisie',
  'Nigeria',
  'Ghana',
];

String _normalizeCountry(String value) {
  return value
      .toLowerCase()
      .replaceAll("'", ' ')
      .replaceAll('-', ' ')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('û', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String computeZone(String country) {
  final normalized = _normalizeCountry(country);
  if (uemoaCountries.map(_normalizeCountry).contains(normalized)) {
    return 'UEMOA';
  }
  if (cemacCountries.map(_normalizeCountry).contains(normalized)) {
    return 'CEMAC';
  }
  return 'Hors zone';
}

double convertAmount(
  double amount, {
  required String fromCurrency,
  required String toCurrency,
}) {
  final normalizedFrom = fromCurrency.toUpperCase();
  final normalizedTo = toCurrency.toUpperCase();
  final fromRate = currencyRatesInXaf[normalizedFrom] ?? 1.0;
  final toRate = currencyRatesInXaf[normalizedTo] ?? 1.0;
  final amountInXaf = amount * fromRate;
  return amountInXaf / toRate;
}

class CounterpartyModel {
  const CounterpartyModel({
    required this.id,
    required this.name,
    required this.country,
    required this.countryRating,
    required this.category,
    required this.rating,
  });

  final String id;
  final String name;
  final String country;
  final String countryRating;
  final String category;
  final String rating;

  factory CounterpartyModel.fromJson(Map<String, dynamic> json) {
    return CounterpartyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      countryRating: (json['country_rating'] ?? 'Non noté') as String,
      category: json['category'] as String,
      rating: json['rating'] as String,
    );
  }
}

class ExposureCrmDetails {
  const ExposureCrmDetails({
    required this.mode,
    required this.label,
    required this.collateralValue,
    required this.issuerType,
    required this.issuerRating,
    required this.maturityBucket,
    required this.fxHaircut,
    required this.guarantorName,
    required this.guarantorCategory,
    required this.guarantorRating,
    required this.guarantorCountry,
    required this.guarantorCountryRating,
    required this.coveragePercent,
  });

  final String mode;
  final String label;
  final double collateralValue;
  final String issuerType;
  final String issuerRating;
  final String maturityBucket;
  final double fxHaircut;
  final String guarantorName;
  final String guarantorCategory;
  final String guarantorRating;
  final String guarantorCountry;
  final String guarantorCountryRating;
  final double coveragePercent;

  factory ExposureCrmDetails.fromJson(Map<String, dynamic>? json) {
    return ExposureCrmDetails(
      mode: (json?['mode'] ?? 'Aucune') as String,
      label: (json?['label'] ?? '') as String,
      collateralValue: ((json?['collateral_value'] ?? 0) as num).toDouble(),
      issuerType: (json?['issuer_type'] ?? '') as String,
      issuerRating: (json?['issuer_rating'] ?? '') as String,
      maturityBucket: (json?['maturity_bucket'] ?? '<=1 an') as String,
      fxHaircut: ((json?['fx_haircut'] ?? 0) as num).toDouble(),
      guarantorName: (json?['guarantor_name'] ?? '') as String,
      guarantorCategory: (json?['guarantor_category'] ?? '') as String,
      guarantorRating: (json?['guarantor_rating'] ?? '') as String,
      guarantorCountry: (json?['guarantor_country'] ?? '') as String,
      guarantorCountryRating: (json?['guarantor_country_rating'] ?? '') as String,
      coveragePercent: ((json?['coverage_percent'] ??
              json?['crm_coverage_percent'] ??
              0) as num)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'label': label,
      'collateral_value': collateralValue,
      'issuer_type': issuerType,
      'issuer_rating': issuerRating,
      'maturity_bucket': maturityBucket,
      'fx_haircut': fxHaircut,
      'guarantor_name': guarantorName,
      'guarantor_category': guarantorCategory,
      'guarantor_rating': guarantorRating,
      'guarantor_country': guarantorCountry,
      'guarantor_country_rating': guarantorCountryRating,
      'coverage_percent': coveragePercent,
    };
  }
}

class ExposureRecord {
  const ExposureRecord({
    required this.id,
    required this.analysisDate,
    this.grantDate,
    this.maturityDate,
    required this.counterparty,
    required this.grossAmount,
    required this.currency,
    required this.crmType,
    required this.crmCoveragePercent,
    required this.originalRw,
    required this.finalRw,
    required this.ead,
    required this.rwa,
    required this.capital,
    required this.comment,
    required this.status,
    required this.crmDetails,
    required this.sovereignSpecialCase,
    required this.sovereignPreferentialZeroWeight,
    required this.sovereignOceEstablished,
    required this.sovereignOceNote,
    required this.publicBodyUemoaFcfaCase,
    required this.publicBodyFinancesNonPublicActivity,
    required this.bmdHighQualityCase,
    required this.bmdUemoaFcfaCase,
    required this.bmdUemoaCriteriaSatisfied,
    required this.bmdListedInstitutionFcfaCase,
    required this.bankInstitutionCase,
    required this.otherAssetType,
    required this.offBalanceRiskLevel,
    required this.retailEligibilityCriteriaSatisfied,
    required bool? residentialMortgageEligible,
    required bool? commercialRealEstateEligible,
    required this.enterpriseExceedsBceaoDegradationThreshold,
    required this.enterprisePrudentialProcedure,
    required this.enterpriseInvestmentFirmWithoutBankingLaw,
    required this.defaultedExposureInitialRiskWeight,
    required this.defaultedExposureResidentialMortgageInDefault,
    required this.defaultedExposureProvisionAtLeastTwentyPercent,
  })  : residentialMortgageEligible = residentialMortgageEligible,
        commercialRealEstateEligible = commercialRealEstateEligible;

  final String id;
  final DateTime analysisDate;
  final DateTime? grantDate;
  final DateTime? maturityDate;
  final CounterpartyModel counterparty;
  final double grossAmount;
  final String currency;
  final String crmType;
  final double crmCoveragePercent;
  final double originalRw;
  final double finalRw;
  final double ead;
  final double rwa;
  final double capital;
  final String comment;
  final String status;
  final ExposureCrmDetails crmDetails;
  final String sovereignSpecialCase;
  final bool sovereignPreferentialZeroWeight;
  final bool sovereignOceEstablished;
  final String sovereignOceNote;
  final bool? publicBodyUemoaFcfaCase;
  final bool? publicBodyFinancesNonPublicActivity;
  final bool? bmdHighQualityCase;
  final bool? bmdUemoaFcfaCase;
  final bool? bmdUemoaCriteriaSatisfied;
  final bool? bmdListedInstitutionFcfaCase;
  final String? bankInstitutionCase;
  final String? otherAssetType;
  final String? offBalanceRiskLevel;
  final bool? retailEligibilityCriteriaSatisfied;
  final bool? enterpriseExceedsBceaoDegradationThreshold;
  final bool? enterprisePrudentialProcedure;
  final bool? enterpriseInvestmentFirmWithoutBankingLaw;
  final bool? residentialMortgageEligible;
  final bool? commercialRealEstateEligible;
  final double? defaultedExposureInitialRiskWeight;
  final bool? defaultedExposureResidentialMortgageInDefault;
  final bool? defaultedExposureProvisionAtLeastTwentyPercent;

  ExposureCategoryOption get categoryOption =>
      exposureCategoryByName(counterparty.category);
  String get categoryCode => categoryOption.code;
  String get categoryLabel => categoryOption.prudentialLabel;
  String get ratingLabel => bucketizeRating(counterparty.rating);
  String get crmModeLabel => crmDetails.mode;
  String get zone => computeZone(counterparty.country);
  bool get isDefaultLike => status == 'En defaut' || categoryCode == 'i';

  factory ExposureRecord.fromJson(Map<String, dynamic> json) {
    final counterparty = CounterpartyModel.fromJson(
      json['counterparty'] as Map<String, dynamic>,
    );
    final categoryCode = exposureCategoryByName(counterparty.category).code;
    final crmType = (json['crm_type'] ?? 'Aucune') as String;
    final crmCoveragePercent =
        (json['crm_coverage_percent'] as num? ?? 0).toDouble();
    final rawCrmDetails = json['crm_details'] as Map<String, dynamic>?;
    final normalizedCrmType = crmType.toLowerCase();
    final legacySovereignPreferentialZeroWeight =
        (json['sovereign_preferential_zero_weight'] ?? false) as bool;
    final inferredCrmMode = normalizedCrmType.contains('garantie') ||
            normalizedCrmType.contains('assurance') ||
            normalizedCrmType.contains('non finance')
        ? 'CRM non financee'
        : normalizedCrmType.contains('cash') ||
                normalizedCrmType.contains('collateral') ||
                normalizedCrmType.contains('financee')
            ? 'CRM financee'
            : crmType == 'Aucune'
                ? 'Aucune'
                : 'CRM non financee';
    final crmDetails = ExposureCrmDetails.fromJson(
      rawCrmDetails ??
          {
            'mode': inferredCrmMode,
            'label': crmType,
            'coverage_percent': crmCoveragePercent,
          },
    );
    return ExposureRecord(
      id: json['id'] as String,
      analysisDate: DateTime.parse(json['analysis_date'] as String),
      grantDate: json['grant_date'] == null
          ? null
          : DateTime.parse(json['grant_date'] as String),
      maturityDate: json['maturity_date'] == null
          ? null
          : DateTime.parse(json['maturity_date'] as String),
      counterparty: counterparty,
      grossAmount: (json['gross_amount'] as num).toDouble(),
      currency: (json['currency'] ?? 'XOF') as String,
      crmType: crmType,
      crmCoveragePercent: crmCoveragePercent == 0
          ? crmDetails.coveragePercent
          : crmCoveragePercent,
      originalRw: (json['original_rw'] as num).toDouble(),
      finalRw: (json['final_rw'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      capital: (json['capital'] as num).toDouble(),
      comment: (json['comment'] ?? '') as String,
      status: (json['status'] ?? 'Active') as String,
      crmDetails: crmDetails,
      sovereignSpecialCase: coerceSovereignSpecialCase(
        json['sovereign_special_case'] as String?,
        fallbackToLegacy: legacySovereignPreferentialZeroWeight,
      ),
      sovereignPreferentialZeroWeight: legacySovereignPreferentialZeroWeight,
      sovereignOceEstablished:
          (json['sovereign_oce_established'] ?? false) as bool,
      sovereignOceNote: (json['sovereign_oce_note'] ?? '') as String,
      publicBodyUemoaFcfaCase: json['public_body_uemoa_fcfa_case'] as bool?,
      publicBodyFinancesNonPublicActivity:
          json['public_body_non_public_activity'] as bool?,
      bmdHighQualityCase: json['bmd_high_quality_case'] as bool?,
      bmdUemoaFcfaCase: json['bmd_uemoa_fcfa_case'] as bool?,
      bmdUemoaCriteriaSatisfied: json['bmd_uemoa_criteria_satisfied'] as bool?,
      bmdListedInstitutionFcfaCase:
          json['bmd_listed_institution_fcfa_case'] as bool?,
      bankInstitutionCase:
          coerceBankInstitutionCase(json['bank_institution_case'] as String?),
      otherAssetType: coerceOtherAssetType(
            json['other_asset_type'] as String?,
            fallbackToUndefined: categoryCode == 'k',
          ) ??
          (categoryCode == 'k' ? otherAssetUndefinedType : null),
      offBalanceRiskLevel: coerceOffBalanceRiskLevel(
            json['off_balance_risk_level'] as String?,
            fallbackToVeryHigh: categoryCode == 'l',
            factorHint: (json['final_rw'] as num?)?.toDouble(),
          ) ??
          (categoryCode == 'l' ? offBalanceVeryHighRiskLevel : null),
      retailEligibilityCriteriaSatisfied:
          json['retail_eligibility_criteria_satisfied'] as bool?,
      enterpriseExceedsBceaoDegradationThreshold:
          json['enterprise_exceeds_bceao_degradation_threshold'] as bool?,
      enterprisePrudentialProcedure:
          json['enterprise_prudential_procedure'] as bool?,
      enterpriseInvestmentFirmWithoutBankingLaw:
          json['enterprise_investment_firm_without_banking_law'] as bool?,
      residentialMortgageEligible:
          json['residential_mortgage_eligible'] as bool?,
      commercialRealEstateEligible:
          json['commercial_real_estate_eligible'] as bool?,
      defaultedExposureInitialRiskWeight:
          (json['defaulted_exposure_initial_risk_weight'] as num?)?.toDouble(),
      defaultedExposureResidentialMortgageInDefault:
          json['defaulted_exposure_residential_mortgage_in_default'] as bool?,
      defaultedExposureProvisionAtLeastTwentyPercent:
          json['defaulted_exposure_provision_at_least_twenty_percent'] as bool?,
    );
  }

  ExposureDraft toDraft() {
    return ExposureDraft(
      id: id,
      counterpartyName: counterparty.name,
      country: counterparty.country,
      countryRating: counterparty.countryRating,
      categoryCode: categoryCode,
      rating: counterparty.rating,
      grossAmount: grossAmount,
      currency: currency,
      status: status,
      crmMode: crmDetails.mode == 'Aucune' ? 'Aucune' : crmDetails.mode,
      crmType: crmType,
      collateralValue: crmDetails.collateralValue,
      issuerType: crmDetails.issuerType,
      issuerRating: crmDetails.issuerRating,
      maturityBucket: crmDetails.maturityBucket,
      fxHaircut: crmDetails.fxHaircut,
      guarantorName: crmDetails.guarantorName,
      guarantorCategoryCode: crmDetails.guarantorCategory.isEmpty
          ? 'a'
          : exposureCategoryByName(crmDetails.guarantorCategory).code,
      guarantorRating: crmDetails.guarantorRating,
      guarantorCountry: crmDetails.guarantorCountry,
      guarantorCountryRating: crmDetails.guarantorCountryRating,
      crmCoveragePercent: crmCoveragePercent,
      comment: comment,
      analysisDate: analysisDate,
      grantDate: grantDate,
      maturityDate: maturityDate,
      sovereignSpecialCase: sovereignSpecialCase,
      sovereignPreferentialZeroWeight: sovereignPreferentialZeroWeight,
      sovereignOceEstablished: sovereignOceEstablished,
      sovereignOceNote: sovereignOceNote,
      publicBodyUemoaFcfaCase: publicBodyUemoaFcfaCase,
      publicBodyFinancesNonPublicActivity: publicBodyFinancesNonPublicActivity,
      bmdHighQualityCase: bmdHighQualityCase,
      bmdUemoaFcfaCase: bmdUemoaFcfaCase,
      bmdUemoaCriteriaSatisfied: bmdUemoaCriteriaSatisfied,
      bmdListedInstitutionFcfaCase: bmdListedInstitutionFcfaCase,
      bankInstitutionCase: bankInstitutionCase,
      otherAssetType: otherAssetType,
      offBalanceRiskLevel: offBalanceRiskLevel,
      retailEligibilityCriteriaSatisfied: retailEligibilityCriteriaSatisfied,
      enterpriseExceedsBceaoDegradationThreshold:
          enterpriseExceedsBceaoDegradationThreshold,
      enterprisePrudentialProcedure: enterprisePrudentialProcedure,
      enterpriseInvestmentFirmWithoutBankingLaw:
          enterpriseInvestmentFirmWithoutBankingLaw,
      residentialMortgageEligible: residentialMortgageEligible,
      commercialRealEstateEligible: commercialRealEstateEligible,
      defaultedExposureInitialRiskWeight: defaultedExposureInitialRiskWeight,
      defaultedExposureResidentialMortgageInDefault:
          defaultedExposureResidentialMortgageInDefault,
      defaultedExposureProvisionAtLeastTwentyPercent:
          defaultedExposureProvisionAtLeastTwentyPercent,
    );
  }
}

class ExposureSummary {
  const ExposureSummary({
    required this.totalExpositions,
    required this.totalEad,
    required this.totalRwa,
    required this.totalCapital,
  });

  final double totalExpositions;
  final double totalEad;
  final double totalRwa;
  final double totalCapital;

  factory ExposureSummary.fromJson(Map<String, dynamic> json) {
    return ExposureSummary(
      totalExpositions: (json['total_expositions'] as num).toDouble(),
      totalEad: (json['total_ead'] as num).toDouble(),
      totalRwa: (json['total_rwa'] as num).toDouble(),
      totalCapital: (json['total_capital'] as num).toDouble(),
    );
  }
}

class ExposureModuleData {
  const ExposureModuleData({
    required this.exposures,
    required this.summary,
  });

  final List<ExposureRecord> exposures;
  final ExposureSummary summary;
}

class ExposureDraft {
  const ExposureDraft({
    this.id,
    required this.counterpartyName,
    required this.country,
    required this.countryRating,
    required this.categoryCode,
    required this.rating,
    required this.grossAmount,
    required this.currency,
    required this.status,
    required this.crmMode,
    required this.crmType,
    required this.collateralValue,
    required this.issuerType,
    required this.issuerRating,
    required this.maturityBucket,
    required this.fxHaircut,
    required this.guarantorName,
    required this.guarantorCategoryCode,
    required this.guarantorRating,
    required this.guarantorCountry,
    required this.guarantorCountryRating,
    required this.crmCoveragePercent,
    required this.comment,
    required this.analysisDate,
    this.grantDate,
    this.maturityDate,
    required this.sovereignSpecialCase,
    required this.sovereignPreferentialZeroWeight,
    required this.sovereignOceEstablished,
    required this.sovereignOceNote,
    required this.publicBodyUemoaFcfaCase,
    required this.publicBodyFinancesNonPublicActivity,
    required this.bmdHighQualityCase,
    required this.bmdUemoaFcfaCase,
    required this.bmdUemoaCriteriaSatisfied,
    required this.bmdListedInstitutionFcfaCase,
    required this.bankInstitutionCase,
    required this.otherAssetType,
    required this.offBalanceRiskLevel,
    required this.retailEligibilityCriteriaSatisfied,
    required this.enterpriseExceedsBceaoDegradationThreshold,
    required this.enterprisePrudentialProcedure,
    required this.enterpriseInvestmentFirmWithoutBankingLaw,
    required this.residentialMortgageEligible,
    required this.commercialRealEstateEligible,
    required this.defaultedExposureInitialRiskWeight,
    required this.defaultedExposureResidentialMortgageInDefault,
    required this.defaultedExposureProvisionAtLeastTwentyPercent,
  });

  final String? id;
  final String counterpartyName;
  final String country;
  final String countryRating;
  final String categoryCode;
  final String rating;
  final double grossAmount;
  final String currency;
  final String status;
  final String crmMode;
  final String crmType;
  final double collateralValue;
  final String issuerType;
  final String issuerRating;
  final String maturityBucket;
  final double fxHaircut;
  final String guarantorName;
  final String guarantorCategoryCode;
  final String guarantorRating;
  final String guarantorCountry;
  final String guarantorCountryRating;
  final double crmCoveragePercent;
  final String comment;
  final DateTime analysisDate;
  final DateTime? grantDate;
  final DateTime? maturityDate;
  final String sovereignSpecialCase;
  final bool sovereignPreferentialZeroWeight;
  final bool sovereignOceEstablished;
  final String sovereignOceNote;
  final bool? publicBodyUemoaFcfaCase;
  final bool? publicBodyFinancesNonPublicActivity;
  final bool? bmdHighQualityCase;
  final bool? bmdUemoaFcfaCase;
  final bool? bmdUemoaCriteriaSatisfied;
  final bool? bmdListedInstitutionFcfaCase;
  final String? bankInstitutionCase;
  final String? otherAssetType;
  final String? offBalanceRiskLevel;
  final bool? retailEligibilityCriteriaSatisfied;
  final bool? enterpriseExceedsBceaoDegradationThreshold;
  final bool? enterprisePrudentialProcedure;
  final bool? enterpriseInvestmentFirmWithoutBankingLaw;
  final bool? residentialMortgageEligible;
  final bool? commercialRealEstateEligible;
  final double? defaultedExposureInitialRiskWeight;
  final bool? defaultedExposureResidentialMortgageInDefault;
  final bool? defaultedExposureProvisionAtLeastTwentyPercent;

  ExposureCategoryOption get category => exposureCategoryByCode(categoryCode);
  ExposureCategoryOption get guarantorCategory =>
      exposureCategoryByCode(guarantorCategoryCode);

  String get backendCategory => category.prudentialLabel;

  String get backendCrmType {
    switch (crmMode) {
      case 'CRM financee':
        return 'Cash collateral';
      case 'CRM non financee':
        return crmType == 'Aucune' ? 'Garantie etatique' : crmType;
      default:
        return 'Aucune';
    }
  }

  Map<String, dynamic> get crmDetailsJson {
    return {
      'mode': crmMode,
      'label': crmType,
      'collateral_value': collateralValue,
      'issuer_type': issuerType,
      'issuer_rating': issuerRating,
      'maturity_bucket': maturityBucket,
      'fx_haircut': fxHaircut,
      'guarantor_name': guarantorName,
      'guarantor_category': guarantorCategory.prudentialLabel,
      'guarantor_rating': guarantorRating,
      'guarantor_country': guarantorCountry,
      'guarantor_country_rating': guarantorCountryRating,
      'coverage_percent': crmCoveragePercent,
    };
  }
}

const List<String> sovereignOceNotes = ['0', '1', '2', '3', '4', '5', '6', '7'];
const double publicBodyUemoaFcfaRiskWeight = 0.2;

bool hasPublicBodyPreferentialUemoaCase(
  bool? publicBodyUemoaFcfaCase,
  bool? publicBodyFinancesNonPublicActivity,
) {
  return publicBodyUemoaFcfaCase == true &&
      publicBodyFinancesNonPublicActivity == false;
}

bool hasPublicBodyEnterpriseOverride(
  bool? publicBodyUemoaFcfaCase,
  bool? publicBodyFinancesNonPublicActivity,
) {
  return publicBodyUemoaFcfaCase == true &&
      publicBodyFinancesNonPublicActivity == true;
}

bool hasBmdPriorityZeroWeightCase({
  bool? bmdHighQualityCase,
  bool? bmdUemoaFcfaCase,
  bool? bmdUemoaCriteriaSatisfied,
  bool? bmdListedInstitutionFcfaCase,
}) {
  return bmdHighQualityCase == true ||
      (bmdUemoaFcfaCase == true && bmdUemoaCriteriaSatisfied == true) ||
      bmdListedInstitutionFcfaCase == true;
}

class ExposureComputation {
  const ExposureComputation({
    required this.originalRw,
    required this.finalRw,
    required this.ead,
    required this.rwa,
    required this.capital,
    required this.effectiveCoverage,
    required this.haircut,
  });

  final double originalRw;
  final double finalRw;
  final double ead;
  final double rwa;
  final double capital;
  final double effectiveCoverage;
  final double haircut;
}

ExposureComputation computeDraftMetrics(ExposureDraft draft) {
  final originalRw = lookupPrudentialRiskWeight(
    draft.categoryCode,
    draft.rating,
    sovereignSpecialCase: draft.sovereignSpecialCase,
    sovereignPreferentialZeroWeight: draft.sovereignPreferentialZeroWeight,
    sovereignOceEstablished: draft.sovereignOceEstablished,
    sovereignOceNote: draft.sovereignOceNote,
    publicBodyUemoaFcfaCase: draft.publicBodyUemoaFcfaCase,
    publicBodyFinancesNonPublicActivity:
        draft.publicBodyFinancesNonPublicActivity,
    bmdHighQualityCase: draft.bmdHighQualityCase,
    bmdUemoaFcfaCase: draft.bmdUemoaFcfaCase,
    bmdUemoaCriteriaSatisfied: draft.bmdUemoaCriteriaSatisfied,
    bmdListedInstitutionFcfaCase: draft.bmdListedInstitutionFcfaCase,
    bankInstitutionCase: draft.bankInstitutionCase,
    otherAssetType: draft.otherAssetType,
    offBalanceRiskLevel: draft.offBalanceRiskLevel,
    retailEligibilityCriteriaSatisfied:
        draft.retailEligibilityCriteriaSatisfied,
    enterpriseExceedsBceaoDegradationThreshold:
        draft.enterpriseExceedsBceaoDegradationThreshold,
    enterprisePrudentialProcedure: draft.enterprisePrudentialProcedure,
    enterpriseInvestmentFirmWithoutBankingLaw:
        draft.enterpriseInvestmentFirmWithoutBankingLaw,
    residentialMortgageEligible: draft.residentialMortgageEligible,
    commercialRealEstateEligible: draft.commercialRealEstateEligible,
    defaultedExposureInitialRiskWeight:
        draft.defaultedExposureInitialRiskWeight,
    defaultedExposureResidentialMortgageInDefault:
        draft.defaultedExposureResidentialMortgageInDefault,
    defaultedExposureProvisionAtLeastTwentyPercent:
        draft.defaultedExposureProvisionAtLeastTwentyPercent,
    grantDate: draft.grantDate,
    maturityDate: draft.maturityDate,
  );
  final amount = draft.grossAmount;
  if (draft.categoryCode == 'l') {
    final fcec = lookupOffBalanceFcec(draft.offBalanceRiskLevel);
    final rwa = amount * fcec;
    return ExposureComputation(
      originalRw: fcec,
      finalRw: fcec,
      ead: amount,
      rwa: rwa,
      capital: rwa * 0.08,
      effectiveCoverage: 0.0,
      haircut: 0.0,
    );
  }
  var ead = amount;
  var finalRw = originalRw;
  var effectiveCoverage = 0.0;
  var haircut = 0.0;

  if (draft.crmMode == 'CRM financee') {
    haircut = lookupFinancedCrmHaircut(
      issuerType: draft.issuerType,
      rating: draft.issuerRating,
      maturityBucket: draft.maturityBucket,
    );
    effectiveCoverage = amount == 0
        ? 0.0
        : (draft.collateralValue / amount).clamp(0.0, 1.0).toDouble();
    final exposureAdjusted = amount * (1 - haircut);
    final collateralAdjusted = draft.collateralValue *
        (1 - haircut - draft.fxHaircut).clamp(0.0, double.infinity);
    ead = (exposureAdjusted - collateralAdjusted)
        .clamp(0.0, double.infinity)
        .toDouble();
  } else if (draft.crmMode == 'CRM non financee') {
    effectiveCoverage = draft.crmCoveragePercent.clamp(0.0, 1.0).toDouble();
    final guarantorRw = lookupPrudentialRiskWeight(
      draft.guarantorCategoryCode,
      draft.guarantorRating.isEmpty ? draft.rating : draft.guarantorRating,
    );
    finalRw = ((effectiveCoverage * guarantorRw) +
            ((1 - effectiveCoverage) * originalRw))
        .clamp(0.0, 1.5)
        .toDouble();
  }

  final rwa = ead * finalRw;
  return ExposureComputation(
    originalRw: originalRw,
    finalRw: finalRw,
    ead: ead,
    rwa: rwa,
    capital: rwa * 0.08,
    effectiveCoverage: effectiveCoverage,
    haircut: haircut,
  );
}

double lookupFinancedCrmHaircut({
  required String issuerType,
  required String rating,
  required String maturityBucket,
}) {
  final cluster = _haircutCluster(rating);
  final sovereign = issuerType.toLowerCase().trim() == 'souverain';
  final bucket = _normalizeMaturityBucket(maturityBucket);

  if (cluster == 'AAA_AA') {
    return switch (bucket) {
      '<=1 an' => sovereign ? 0.005 : 0.01,
      '1-3 ans' => sovereign ? 0.02 : 0.03,
      '3-5 ans' => sovereign ? 0.02 : 0.04,
      '5-10 ans' => sovereign ? 0.04 : 0.06,
      '>10 ans' => sovereign ? 0.04 : 0.12,
      _ => 0.0,
    };
  }
  if (cluster == 'A_BBB') {
    return switch (bucket) {
      '<=1 an' => sovereign ? 0.01 : 0.02,
      '1-3 ans' => sovereign ? 0.03 : 0.04,
      '3-5 ans' => sovereign ? 0.03 : 0.06,
      '5-10 ans' => sovereign ? 0.06 : 0.12,
      '>10 ans' => sovereign ? 0.06 : 0.20,
      _ => 0.0,
    };
  }
  if (cluster == 'BB') {
    return sovereign ? 0.15 : 0.0;
  }
  if (cluster == 'ACTION_BRVM') {
    return 0.20;
  }
  if (cluster == 'AUTRE_ACTION') {
    return 0.30;
  }
  if (cluster == 'LIQUIDITE' || cluster == 'OPCVM') {
    return 0.0;
  }
  return 0.0;
}

String _normalizeMaturityBucket(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(' ', '');
  if (normalized == '<=1an' || normalized == '<=1ans') return '<=1 an';
  if (normalized == '1-3ans' || normalized == '1a3ans') return '1-3 ans';
  if (normalized == '3-5ans' ||
      normalized == '1a5ans' ||
      normalized == '1-5ans') return '3-5 ans';
  if (normalized == '5-10ans') return '5-10 ans';
  if (normalized == '>10ans' || normalized == '>5ans') return '>10 ans';
  return value;
}

String _haircutCluster(String rating) {
  final normalized = normalizeFinancedCrmCollateralRating(rating);
  if (['AAA', 'AA+', 'AA', 'AA-', 'AAA/AA', 'NON_NOTE_ETAT_UMOA']
      .contains(normalized)) {
    return 'AAA_AA';
  }
  if ([
    'A+',
    'A',
    'A-',
    'BBB+',
    'BBB',
    'BBB-',
    'GARANTI_BRVM',
    'BANCAIRE_NON_NOTE'
  ].contains(normalized)) {
    return 'A_BBB';
  }
  if (['BB+', 'BB', 'BB-', 'BB/B'].contains(normalized)) {
    return 'BB';
  }
  if (normalized == 'ACTIONS_BRVM') return 'ACTION_BRVM';
  if (normalized == 'AUTRES_ACTIONS') return 'AUTRE_ACTION';
  if (normalized == 'OPCVM') return 'OPCVM';
  if (normalized == 'LIQUIDITE') return 'LIQUIDITE';
  return '';
}
