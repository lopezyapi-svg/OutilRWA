// Ce fichier affiche le parcours guide de creation et d'edition des expositions.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lottie/lottie.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/exposition_models.dart';

const double _exposureFormRadius = 5;

bool _isExposureDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _wizardScreenColor(BuildContext context) => _isExposureDark(context)
    ? AppTheme.darkBackground
    : const Color(0xFFF4F7FB);

Color _wizardShellColor(BuildContext context) =>
    _isExposureDark(context) ? const Color(0xFF0D172A) : Colors.white;

Color _wizardPanelColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF101B31)
    : const Color(0xFFF9FBFE);

Color _wizardCardColor(BuildContext context) =>
    _isExposureDark(context) ? const Color(0xFF13233C) : Colors.white;

Color _wizardSoftCardColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF122038)
    : const Color(0xFFF9FBFF);

Color _wizardInputFillColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF14233D)
    : const Color(0xFFFBFCFF);

Color _wizardBorderColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF273853)
    : const Color(0xFFE4EBF6);

Color _wizardTitleColor(BuildContext context) =>
    _isExposureDark(context) ? AppTheme.darkText : const Color(0xFF0F172A);

Color _wizardBodyTitleColor(BuildContext context) =>
    _isExposureDark(context) ? AppTheme.darkText : const Color(0xFF1E293B);

Color _wizardMutedColor(BuildContext context) =>
    _isExposureDark(context) ? AppTheme.darkMuted : const Color(0xFF64748B);

Color _wizardSubtleMutedColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFFA3B1C8)
    : const Color(0xFF71839E);

class ExposureFormCard extends StatefulWidget {
  const ExposureFormCard({
    super.key,
    required this.onSubmit,
    required this.onCancel,
    required this.ratings,
    this.initialDraft,
    this.title = 'Nouvelle exposition',
    this.submitLabel = 'Enregistrer',
  });

  final Future<void> Function(ExposureDraft draft) onSubmit;
  final VoidCallback onCancel;
  final List<String> ratings;
  final ExposureDraft? initialDraft;
  final String title;
  final String submitLabel;

  @override
  State<ExposureFormCard> createState() => _ExposureFormCardState();
}

class _ExposureFormCardState extends State<ExposureFormCard> {
  static const List<String> _supportedCurrencies = ['XOF', 'XAF', 'EUR', 'USD'];
  static const String _bmdCriteriaTooltip =
      '(a) excellente notation long terme (majoritairement AAA)\n'
      '(b) actionnariat composé en grande partie de souverains ≥ AA- ou financement surtout par capital versé\n'
      '(c) fort soutien des actionnaires\n'
      '(d) niveau adéquat de capital et de liquidité\n'
      '(e) politiques de crédit et gestion des risques prudentes';
  static const String _bmdCdeCriteriaTooltip =
      '(c) fort soutien des actionnaires\n'
      '(d) niveau adéquat de capital et de liquidité\n'
      '(e) politiques de crédit et gestion des risques prudentes';
  static const String _bmdInstitutionsTooltip =
      "BIRD : Banque internationale pour la reconstruction et le développement\n"
      "SFI : Société financière internationale\n"
      "BAsD : Banque asiatique de développement\n"
      "BAD : Banque africaine de développement\n"
      "BERD : Banque européenne pour la reconstruction et le développement\n"
      "BEI : Banque européenne d'investissement\n"
      "FEI : Fonds européen d'investissement\n"
      "BNI : Banque nordique d'investissement\n"
      "BDC : Banque de développement des Caraïbes\n"
      "BIsD : Banque islamique de développement\n"
      "BDCE : Banque de développement des Caraïbes orientales\n"
      "AMGI : Agence multilatérale de garantie des investissements\n"
      "BOAD : Banque ouest-africaine de développement";
  static const String _bankInstitutionWeakPrudentialTooltip =
      "L institution a des fonds propres négatifs, ne respecte pas les ratios de solvabilité, ou il s agit d une SFD non supervisée par la Commission Bancaire.";
  static const String _bankInstitutionEligibleCategoriesTooltip =
      "(a) les entreprises du secteur bancaire\n"
      "(b) les services financiers des administrations de poste\n"
      "(c) les caisses nationales d'épargne\n"
      "(d) les autres institutions financières internationales.";
  static const String _enterpriseArticle133Tooltip =
      "Une pondération supérieure à 100 % est exigée lorsque le taux brut de dégradation du portefeuille entreprise dépasse sur deux trimestres consécutifs un seuil fixé par instruction de la BCEAO.\n\n"
      "Une pondération plus élevée est appliquée, lorsqu'une entreprise établie dans l'UMOA est soumise à une procédure de traitement prudentiel résultant de la production, par l'entreprise elle-même ou par son commissaire au compte, d'informations financières erronées.\n\n"
      "[[NOTE]]On entend par taux brut de dégradation du portefeuille, le rapport entre l'encours des créances en souffrance brutes telles que défini aux paragraphes 152 à 160 et le portefeuille de crédit brut de l'établissement. S'agissant des entreprises, le taux brut de dégradation du portefeuille est le rapport entre l'encours des créances en souffrance brutes enregistré au titre du portefeuille entreprises et l'encours total des crédits bruts octroyés à ce segment.";
  static const String _enterpriseUnratedTooltip =
      "Les expositions sur les entreprises d'investissement, autres que celles soumises à la loi uniforme portant réglementation bancaire doivent être pondérées, conformément aux règles afférentes aux créances sur les entreprises.\n\n"
      "En outre, les expositions sur les entreprises non notées ne peuvent être affectées d’une pondération plus favorable que celle portant sur l’Etat dans lequel ces entreprises ont leur siège social.";
  static const String _offBalanceLowRiskTooltip =
      'engagements révocables sans condition, à tout moment, sans préavis ou caducs automatiquement.';
  static const String _offBalanceMinorRiskTooltip =
      'engagements ≤ 1 an non révocables sans condition ; lettres de crédit commerciales à court terme, crédits documentaires.';
  static const String _offBalanceMediumRiskTooltip =
      'engagements > 1 an non révocables sans condition ; lettres de crédit documentaires non garanties par marchandises ; garanties de bonne exécution, de soumission, de tiers, crédits de confirmation.';
  static const String _offBalanceHighRiskTooltip =
      'facilités d’émission d’effets (FEE) et facilités de prise ferme renouvelables (FPR) ; substituts directs de crédit, garanties d’endettement, acceptations.';
  static const String _offBalanceVeryHighRiskTooltip =
      'opérations assimilables à des pensions, repo ou prêts de titres ; cessions d’actifs avec recours, affacturage ou escompte ; engagements d’achat d’actifs à terme ; dépôts à terme contre terme ; fraction non versée d’actions ou titres partiellement libérés ; autres éléments hors bilan non classés.';
  static const String _residentialMortgageCriteriaTooltip =
      'Ratio Prêt/Valeur (LTV) ≤ 90 %\n'
      'Ratio de couverture du service de la dette ≤ 40 %\n'
      'Accord du client pour la transmission des données au BIC';
  static const String _commercialRealEstateCriteriaTooltip =
      'Ratio Prêt/Valeur (LTV) ≤ 90 %\n'
      'Consentement du client à la transmission des données aux BIC';
  static const List<String> _nonFinancedCrmTypes = [
    'Garantie etatique',
    'Assurance credit',
    'Garantie bancaire',
  ];
  static const List<double> _coverageOptions = [
    0.0,
    0.1,
    0.2,
    0.4,
    0.5,
    0.75,
    1.0,
  ];
  static const List<_WizardStepMeta> _stepMetas = [
    _WizardStepMeta(
      shortLabel: 'Apercu',
      title: 'Introduction & apercu',
      subtitle: 'Contexte et indicateurs RWA',
      icon: Icons.shield_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Identite',
      title: 'Informations principales',
      subtitle: 'Contrepartie, pays et dates',
      icon: Icons.badge_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Categorie',
      title: 'Categorie prudentielle',
      subtitle: 'Type d exposition, notation et ponderation',
      icon: Icons.account_tree_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Finance',
      title: 'Donnees financieres',
      subtitle: 'Montant et devise',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'CRM',
      title: 'CRM & gestion du risque',
      subtitle: 'Couverture et attenuation du risque',
      icon: Icons.handshake_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Comment.',
      title: 'Commentaire & finalisation',
      subtitle: 'Analyse metier et remarques',
      icon: Icons.edit_note_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Valider',
      title: 'Validation finale',
      subtitle: 'Confirmer ou annuler l ajout',
      icon: Icons.task_alt_outlined,
    ),
  ];

  final _primaryFormKey = GlobalKey<FormState>();
  final _categoryFormKey = GlobalKey<FormState>();
  final _financialFormKey = GlobalKey<FormState>();
  final _crmFormKey = GlobalKey<FormState>();
  final _commentFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _countryController;
  final TextEditingController _exposureIdController = TextEditingController();
  final TextEditingController _grantDateController = TextEditingController();
  final TextEditingController _maturityDateController = TextEditingController();
  final ScrollController _rightPanelScrollController = ScrollController();
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late final TextEditingController _collateralController;
  late final TextEditingController _fxHaircutController;
  late final TextEditingController _guarantorNameController;

  late String _categoryCode;
  late String _countryRating;
  late String _rating;
  late String _sovereignSpecialCase;
  late String _sovereignOceNote;
  bool? _publicBodyUemoaFcfaCase;
  bool? _publicBodyFinancesNonPublicActivity;
  bool? _bmdHighQualityCase;
  bool? _bmdUemoaFcfaCase;
  bool? _bmdUemoaCriteriaSatisfied;
  bool? _bmdListedInstitutionFcfaCase;
  String? _bankInstitutionCase;
  String? _otherAssetType;
  String? _offBalanceRiskLevel;
  bool? _retailEligibilityCriteriaSatisfied;
  bool? _residentialMortgageEligible;
  bool? _commercialRealEstateEligible;
  double? _defaultedExposureInitialRiskWeight;
  bool? _defaultedExposureResidentialMortgageInDefault;
  bool? _defaultedExposureProvisionAtLeastTwentyPercent;
  bool? _enterpriseExceedsBceaoDegradationThreshold;
  bool? _enterprisePrudentialProcedure;
  bool? _enterpriseInvestmentFirmWithoutBankingLaw;
  late String _currency;
  late String _status;
  late String _crmMode;
  late String _lastSelectedCrmMode;
  late String _crmType;
  late String _issuerType;
  late String _issuerRating;
  late String _maturityBucket;
  late String _guarantorCategoryCode;
  late String _guarantorRating;
  DateTime? _grantDate;
  DateTime? _maturityDate;

  int _currentStep = 1;
  double _coverage = 0.0;
  bool _sovereignPreferentialZeroWeight = false;
  bool _sovereignPriorityQuestionAnsweredYes = false;
  bool _sovereignOceEstablished = false;
  bool _crmSelectionStage = true;
  bool _submitting = false;
  bool _showStickyStepHeader = false;
  bool _expandStickyStepHeader = false;
  ScrollDirection _rightPanelScrollDirection = ScrollDirection.idle;
  bool _rightPanelScrollSyncScheduled = false;
  bool? _pendingShowStickyStepHeader;
  bool? _pendingExpandStickyStepHeader;
  ScrollDirection? _pendingRightPanelScrollDirection;
  bool _didResolveScopedCurrency = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _nameController = TextEditingController(
      text: draft?.counterpartyName ?? 'Nouvelle contrepartie',
    );
    _exposureIdController.text = draft?.id ?? '';
    _countryController =
        TextEditingController(text: draft?.country ?? 'Cameroun');
    _grantDate = draft?.grantDate;
    _maturityDate = draft?.maturityDate;
    _grantDateController.text = _formatDateForField(_grantDate);
    _maturityDateController.text = _formatDateForField(_maturityDate);
    _amountController = TextEditingController(
      text: (draft?.grossAmount ?? 1000000).toStringAsFixed(0),
    );
    _commentController = TextEditingController(text: draft?.comment ?? '');
    _collateralController = TextEditingController(
      text: (draft?.collateralValue ?? 0).toStringAsFixed(0),
    );
    _fxHaircutController = TextEditingController(
      text: ((draft?.fxHaircut ?? 0) * 100).toStringAsFixed(2),
    );
    _guarantorNameController =
        TextEditingController(text: draft?.guarantorName ?? '');
    _categoryCode =
        exposureCategories.any((item) => item.code == draft?.categoryCode)
            ? draft!.categoryCode
            : 'e';
    _countryRating = _resolveRatingValue(
      draft?.countryRating,
      preferred: 'Non noté',
    );
    _rating = _resolveRatingValue(
      draft?.rating,
      preferred: 'BBB',
    );
    if ((_categoryCode == 'a' || _categoryCode == 'c') &&
        !prudentialRatings.contains(_rating)) {
      _rating = 'Non noté';
    }
    _sovereignSpecialCase = coerceSovereignSpecialCase(
      draft?.sovereignSpecialCase,
      fallbackToLegacy: draft?.sovereignPreferentialZeroWeight ?? false,
    );
    _sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
      _sovereignSpecialCase,
      sovereignPreferentialZeroWeight:
          draft?.sovereignPreferentialZeroWeight ?? false,
    );
    _sovereignPriorityQuestionAnsweredYes =
        _sovereignSpecialCase != sovereignNoSpecialCase ||
            _sovereignPreferentialZeroWeight;
    _sovereignOceEstablished = draft?.sovereignOceEstablished ?? false;
    _sovereignOceNote = sovereignOceNotes.contains(draft?.sovereignOceNote)
        ? draft!.sovereignOceNote
        : sovereignOceNotes.first;
    _publicBodyUemoaFcfaCase = draft?.publicBodyUemoaFcfaCase;
    _publicBodyFinancesNonPublicActivity =
        draft?.publicBodyFinancesNonPublicActivity;
    _bmdHighQualityCase = draft?.bmdHighQualityCase;
    _bmdUemoaFcfaCase = draft?.bmdUemoaFcfaCase;
    _bmdUemoaCriteriaSatisfied = draft?.bmdUemoaCriteriaSatisfied;
    _bmdListedInstitutionFcfaCase = draft?.bmdListedInstitutionFcfaCase;
    _bankInstitutionCase =
        coerceBankInstitutionCase(draft?.bankInstitutionCase);
    _otherAssetType = coerceOtherAssetType(
      draft?.otherAssetType,
      fallbackToUndefined: _categoryCode == 'k' && draft != null,
    );
    _offBalanceRiskLevel = coerceOffBalanceRiskLevel(
      draft?.offBalanceRiskLevel,
      fallbackToVeryHigh: _categoryCode == 'l' && draft != null,
    );
    _retailEligibilityCriteriaSatisfied =
        draft?.retailEligibilityCriteriaSatisfied;
    _residentialMortgageEligible = draft?.residentialMortgageEligible;
    _commercialRealEstateEligible = draft?.commercialRealEstateEligible;
    _defaultedExposureInitialRiskWeight =
        draft?.defaultedExposureInitialRiskWeight;
    _defaultedExposureResidentialMortgageInDefault =
        draft?.defaultedExposureResidentialMortgageInDefault;
    _defaultedExposureProvisionAtLeastTwentyPercent =
        draft?.defaultedExposureProvisionAtLeastTwentyPercent;
    _enterpriseExceedsBceaoDegradationThreshold =
        draft?.enterpriseExceedsBceaoDegradationThreshold;
    _enterprisePrudentialProcedure = draft?.enterprisePrudentialProcedure;
    _enterpriseInvestmentFirmWithoutBankingLaw =
        draft?.enterpriseInvestmentFirmWithoutBankingLaw;
    if (!_isPublicBodyCategory) {
      _publicBodyUemoaFcfaCase = null;
      _publicBodyFinancesNonPublicActivity = null;
    }
    if (!_isBmdCategory) {
      _bmdHighQualityCase = null;
      _bmdUemoaFcfaCase = null;
      _bmdUemoaCriteriaSatisfied = null;
      _bmdListedInstitutionFcfaCase = null;
    }
    if (!_isBankInstitutionCategory) {
      _bankInstitutionCase = null;
    }
    if (_categoryCode != 'k') {
      _otherAssetType = null;
    }
    if (!_isOffBalanceCategory) {
      _offBalanceRiskLevel = null;
    }
    if (!_isRetailCategory) {
      _retailEligibilityCriteriaSatisfied = null;
    }
    if (!_isResidentialMortgageCategory) {
      _residentialMortgageEligible = null;
    }
    if (!_isCommercialRealEstateCategory) {
      _commercialRealEstateEligible = null;
    }
    if (!_isDefaultedExposureCategory) {
      _defaultedExposureInitialRiskWeight = null;
      _defaultedExposureResidentialMortgageInDefault = null;
      _defaultedExposureProvisionAtLeastTwentyPercent = null;
    }
    if (!_isEnterpriseLikeCategory) {
      _enterpriseExceedsBceaoDegradationThreshold = null;
      _enterprisePrudentialProcedure = null;
      _enterpriseInvestmentFirmWithoutBankingLaw = null;
    }
    _currency = _resolveCurrency(draft?.currency);
    _status = draft?.status ?? 'Active';
    _crmMode = draft?.crmMode ?? 'Aucune';
    _lastSelectedCrmMode = _crmMode == 'Aucune' ? 'CRM financee' : _crmMode;
    _crmType = _nonFinancedCrmTypes.contains(draft?.crmType)
        ? draft!.crmType
        : 'Garantie etatique';
    _issuerType = financedCrmIssuerTypes.contains(draft?.issuerType)
        ? draft!.issuerType
        : financedCrmIssuerTypes.first;
    _issuerRating = draft?.issuerRating != null
        ? coerceFinancedCrmCollateralRating(draft!.issuerRating)
        : financedCrmCollateralRatings.first;
    _maturityBucket = financedCrmMaturityBuckets.contains(draft?.maturityBucket)
        ? draft!.maturityBucket
        : financedCrmMaturityBuckets.first;
    _guarantorCategoryCode =
        guarantorEligibleCategoryCodes.contains(draft?.guarantorCategoryCode)
            ? draft!.guarantorCategoryCode
            : guarantorEligibleCategoryCodes.first;
    _guarantorRating = _resolveRatingValue(
      draft?.guarantorRating,
      preferred: 'AAA',
    );
    _coverage = draft?.crmCoveragePercent ?? 0.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveScopedCurrency || widget.initialDraft?.currency != null) {
      return;
    }
    _currency = _resolveCurrency(
      PortfolioCurrencyScope.maybeOf(context, fallback: _currency),
      fallback: _currency,
    );
    _didResolveScopedCurrency = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _exposureIdController.dispose();
    _countryController.dispose();
    _grantDateController.dispose();
    _maturityDateController.dispose();
    _rightPanelScrollController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    _collateralController.dispose();
    _fxHaircutController.dispose();
    _guarantorNameController.dispose();
    super.dispose();
  }

  List<String> get _availableRatings {
    final unique = <String>[];
    for (final raw in widget.ratings) {
      final value = raw.trim();
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    if (unique.isNotEmpty) {
      return unique;
    }
    return prudentialRatings
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _resolveCurrency(String? value, {String fallback = 'XOF'}) {
    final normalized = value?.trim().toUpperCase();
    if (normalized != null && _supportedCurrencies.contains(normalized)) {
      return normalized;
    }
    return fallback;
  }

  String _resolveRatingValue(
    String? value, {
    String? preferred,
  }) {
    final ratings = _availableRatings;
    if (value != null && ratings.contains(value)) {
      return value;
    }
    if (preferred != null && ratings.contains(preferred)) {
      return preferred;
    }
    return ratings.first;
  }

  List<String> get _availableCountryOptions {
    final unique = <String>[];
    final current = _countryController.text.trim();
    if (current.isNotEmpty) {
      unique.add(current);
    }
    for (final raw in worldCountries) {
      final value = raw.trim();
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    return unique;
  }

  String get _detectedCountryZone {
    final value = _countryController.text.trim();
    if (value.isEmpty) {
      return context.tr('Non determinee');
    }
    return computeZone(value);
  }

  Color _zoneAccentColor(String zone) {
    switch (zone) {
      case 'UEMOA':
        return const Color(0xFF0F766E);
      case 'CEMAC':
        return const Color(0xFF2563EB);
      case 'Hors zone':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Widget _dropdownLabel(
    String text, {
    bool translate = false,
  }) {
    return Text(
      translate ? text.tr(context) : text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  List<DropdownMenuItem<String>> _stringDropdownItems(
    List<String> items, {
    bool translate = false,
  }) {
    final unique = <String>[];
    for (final raw in items) {
      final value = raw.trim();
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    return unique
        .map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: _dropdownLabel(item, translate: translate),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _selectedStringDropdownItems(
    List<String> items, {
    bool translate = false,
  }) {
    final unique = <String>[];
    for (final raw in items) {
      final value = raw.trim();
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    return unique
        .map(
          (item) => Align(
            alignment: Alignment.centerLeft,
            child: _dropdownLabel(item, translate: translate),
          ),
        )
        .toList(growable: false);
  }

  InlineSpan _buildBankInstitutionTooltipContent(
    String title,
    String message,
  ) {
    final lines = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      return const TextSpan(text: '');
    }

    return TextSpan(
      children: [
        TextSpan(
          text: '$title\n',
          style: const TextStyle(
            fontSize: 12.4,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        for (var index = 0; index < lines.length; index++)
          TextSpan(
            text:
                '${lines[index].startsWith('(') ? '• ' : ''}${lines[index]}${index == lines.length - 1 ? '' : '\n'}',
            style: const TextStyle(
              fontSize: 11.4,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE8EEF9),
              height: 1.42,
            ),
          ),
      ],
    );
  }

  Widget _buildBankInstitutionInfoTooltip({
    required String title,
    required String message,
    required Widget child,
  }) {
    return Tooltip(
      richMessage: _buildBankInstitutionTooltipContent(title, message),
      constraints: const BoxConstraints(maxWidth: 350),
      waitDuration: const Duration(milliseconds: 140),
      showDuration: const Duration(seconds: 12),
      preferBelow: false,
      verticalOffset: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D4B7A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
      child: child,
    );
  }

  Widget _bankInstitutionCaseDropdownLabel(
    String item, {
    bool includeInfoIcon = false,
  }) {
    final label = bankInstitutionCaseLabel(item);
    if (!includeInfoIcon) {
      return _dropdownLabel(label);
    }
    if (item == bankInstitutionWeakPrudentialCase) {
      return Row(
        children: [
          Expanded(child: _dropdownLabel(label)),
          const SizedBox(width: 8),
          _buildBankInstitutionInfoTooltip(
            title: context.tr('Critères'),
            message: _bankInstitutionWeakPrudentialTooltip.tr(context),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.accent.withAlpha(31),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppTheme.accent,
              ),
            ),
          ),
        ],
      );
    }
    if (item != bankInstitutionEligibleCategoriesCase) {
      return _dropdownLabel(label);
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dropdownLabel(label),
              const SizedBox(height: 2),
              Text(
                context.tr(
                  '(veuillez consulter le point infos pour en savoir plus)',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9.2,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent.withAlpha(170),
                      height: 1.15,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildBankInstitutionInfoTooltip(
          title: context.tr('Catégories concernées'),
          message: _bankInstitutionEligibleCategoriesTooltip.tr(context),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(31),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppTheme.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _otherAssetTypeDropdownLabel(
    String item, {
    bool includeInfoIcon = false,
  }) {
    final label = _dropdownLabel(item);
    if (!includeInfoIcon) {
      return label;
    }

    String? tooltipTitle;
    String? tooltipMessage;
    if (item == otherAssetMiscellaneousType) {
      tooltipTitle = context.tr('Exemples inclus');
      tooltipMessage =
          context.tr('comptes d’ordre, dépôts, débiteurs, FCP, stocks.');
    } else if (item == otherAssetEquityCommitmentsType) {
      tooltipTitle = context.tr('Précision');
      tooltipMessage = context.tr(
        'hors engagements soumis à 250 % et hors actifs à risque élevé soumis à 150 %.',
      );
    }

    if (tooltipMessage == null || tooltipMessage.trim().isEmpty) {
      return label;
    }

    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        _buildBankInstitutionInfoTooltip(
          title: tooltipTitle ?? context.tr('Précision'),
          message: tooltipMessage,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(31),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppTheme.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _offBalanceRiskLevelDropdownLabel(
    String item, {
    bool includeInfoIcon = false,
  }) {
    final label = _dropdownLabel(item);
    if (!includeInfoIcon) {
      return label;
    }

    final tooltipMessage = switch (item) {
      offBalanceLowRiskLevel => _offBalanceLowRiskTooltip,
      offBalanceMinorRiskLevel => _offBalanceMinorRiskTooltip,
      offBalanceMediumRiskLevel => _offBalanceMediumRiskTooltip,
      offBalanceHighRiskLevel => _offBalanceHighRiskTooltip,
      offBalanceVeryHighRiskLevel => _offBalanceVeryHighRiskTooltip,
      _ => '',
    };
    if (tooltipMessage.trim().isEmpty) {
      return label;
    }

    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        _buildBankInstitutionInfoTooltip(
          title: item,
          message: tooltipMessage,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(31),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppTheme.accent,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(context);
    final preview = _buildPreview();

    return Container(
      color: _wizardScreenColor(context),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const Divider(height: 1),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useSplitLayout = constraints.maxWidth >= 980;
                      final contentWidth = constraints.maxWidth - 40;
                      final fixedMainCardHeight = useSplitLayout ? 528.0 : null;
                      final useFixedMainCard = fixedMainCardHeight != null;
                      final leftPaneWidth = useSplitLayout
                          ? (contentWidth - 18) / 2
                          : contentWidth;
                      final kpiWidth = leftPaneWidth >= 580
                          ? (leftPaneWidth - 10) / 2
                          : contentWidth;

                      final leftColumn = _buildFixedSummaryColumn(
                        context,
                        preview,
                        displayCurrency,
                        kpiWidth,
                      );
                      final rightPanel = _buildCurrentRightPanel(
                        context,
                        preview,
                        displayCurrency,
                        fixedHeight: useFixedMainCard,
                      );

                      final sharedContent = useSplitLayout
                          ? Row(
                              crossAxisAlignment: useFixedMainCard
                                  ? CrossAxisAlignment.stretch
                                  : CrossAxisAlignment.start,
                              children: [
                                Expanded(child: rightPanel),
                                const SizedBox(width: 18),
                                Expanded(child: leftColumn),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                leftColumn,
                                const SizedBox(height: 16),
                                rightPanel,
                              ],
                            );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Container(
                          width: double.infinity,
                          constraints: fixedMainCardHeight == null
                              ? const BoxConstraints()
                              : BoxConstraints(
                                  minHeight: fixedMainCardHeight,
                                  maxHeight: fixedMainCardHeight,
                                ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _wizardShellColor(context),
                            borderRadius:
                                BorderRadius.circular(_exposureFormRadius),
                            border:
                                Border.all(color: _wizardBorderColor(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopActionStepRow(context),
                              const SizedBox(height: 10),
                              if (useFixedMainCard)
                                Expanded(child: sharedContent)
                              else
                                sharedContent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_submitting) _buildSavingOverlay(context),
        ],
      ),
    );
  }

  Widget _buildFixedSummaryColumn(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
    double kpiWidth,
  ) {
    final compactKpiWidth = kpiWidth > 168 ? 168.0 : kpiWidth;
    final items = _buildIntroKpis(context, preview, displayCurrency);
    final isDark = _isExposureDark(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _wizardSoftCardColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(color: _wizardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x0D9DB4CC),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3.0,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF4E79D8) : const Color(0xFFBFD3F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(_exposureFormRadius),
                bottomLeft: Radius.circular(_exposureFormRadius),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : compactKpiWidth * 2 + spacing;
                  final twoColumnWidth = (availableWidth - spacing) / 2;
                  final itemWidth = twoColumnWidth < compactKpiWidth
                      ? twoColumnWidth
                      : compactKpiWidth;

                  return Wrap(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? const [
                                          Color(0xFF1A335C),
                                          Color(0xFF153D39),
                                        ]
                                      : const [
                                          Color(0xFFE7EEFF),
                                          Color(0xFFE1F7F2),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF2E4667)
                                      : const Color(0xFFD7E2F2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? const Color(0x22000000)
                                        : const Color(0x110F172A),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
                                size: 21,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Synthese',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: _wizardTitleColor(context),
                                          letterSpacing: -0.1,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lecture rapide du profil RWA, des expositions et des echeances',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 10,
                                          color: _wizardMutedColor(context),
                                          height: 1.2,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final item in items)
                            SizedBox(
                              width: itemWidth,
                              child: _HeroKpiCard(
                                label: item.label,
                                value: item.value,
                                icon: item.icon,
                                accent: item.accent,
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: SizedBox(
                          width: availableWidth,
                          child: Container(
                            height: 146,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF101E34)
                                  : const Color(0xFFF8FBFF),
                              borderRadius:
                                  BorderRadius.circular(_exposureFormRadius),
                            ),
                            alignment: Alignment.center,
                            child: Lottie.asset(
                              'assets/lotties/rwa_dashboard.json',
                              width: 196,
                              height: 118,
                              fit: BoxFit.contain,
                              repeat: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionStepRow(BuildContext context) {
    final visibleStepCount = _stepMetas.length - 1;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _IntroActionButton(
                icon: Icons.restart_alt_rounded,
                accent: const Color(0xFFF59E0B),
                filled: true,
                onTap: _resetDraftValues,
              ),
              const SizedBox(width: 10),
              for (var visibleIndex = 0;
                  visibleIndex < visibleStepCount;
                  visibleIndex++) ...[
                _StepOverviewChip(
                  number: visibleIndex + 1,
                  isActive: visibleIndex + 1 == _currentStep,
                  isCompleted: visibleIndex + 1 < _currentStep ||
                      (!_crmExists &&
                          visibleIndex + 1 == 4 &&
                          _currentStep > 4),
                ),
                if (visibleIndex < visibleStepCount - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentRightPanel(
      BuildContext context, _ExposurePreview preview, String displayCurrency,
      {required bool fixedHeight}) {
    final stickyHeight =
        _showStickyStepHeader ? (_expandStickyStepHeader ? 58.0 : 38.0) : 0.0;

    return Container(
      height: fixedHeight ? double.infinity : null,
      decoration: BoxDecoration(
        color: _wizardPanelColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(color: _wizardBorderColor(context)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: fixedHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: stickyHeight,
            child: stickyHeight <= 0
                ? null
                : Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildStickyStepHeader(context),
                  ),
          ),
          if (fixedHeight)
            Expanded(
              child: _buildRightPanelScrollable(
                context,
                preview,
                displayCurrency,
              ),
            )
          else
            _buildRightPanelScrollable(
              context,
              preview,
              displayCurrency,
            ),
          const SizedBox(height: 12),
          _buildInlineStepFooter(context),
        ],
      ),
    );
  }

  Widget _buildRightPanelScrollable(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
  ) {
    return RawScrollbar(
      controller: _rightPanelScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 2.5,
      radius: const Radius.circular(999),
      crossAxisMargin: 1,
      mainAxisMargin: 4,
      thumbColor: AppTheme.accent.withOpacity(
        _isExposureDark(context) ? 0.9 : 0.72,
      ),
      trackColor: _wizardBorderColor(context).withOpacity(0.55),
      trackBorderColor: Colors.transparent,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleRightPanelScrollNotification,
        child: SingleChildScrollView(
          controller: _rightPanelScrollController,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: _buildCurrentRightStepContent(
            context,
            preview,
            displayCurrency,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentRightStepContent(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
  ) {
    switch (_currentStep) {
      case 1:
        return _PrimaryInformationStepScreen(
          title: _stepMetas[1].title,
          subtitle: _stepMetas[1].subtitle,
          formKey: _primaryFormKey,
          fields: [
            _buildFieldCard(
              context: context,
              title: 'Contrepartie',
              subtitle: 'Nom ou raison sociale',
              icon: Icons.business_outlined,
              child: TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Nom de la contrepartie'),
                ),
                validator: _requiredValidator,
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'ID Exposition',
              subtitle: 'Identifiant de la ligne',
              icon: Icons.tag_outlined,
              child: TextFormField(
                controller: _exposureIdController,
                readOnly: true,
                enableInteractiveSelection: false,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Genere automatiquement'),
                ),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Date d octroi',
              subtitle: 'Date de mise en place',
              icon: Icons.event_available_outlined,
              child: TextFormField(
                controller: _grantDateController,
                readOnly: true,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Choisir une date'),
                  suffixIcon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: Color(0xFF7A8AA4),
                  ),
                ),
                onTap: () => _pickDate(
                  currentValue: _grantDate,
                  onChanged: (value) {
                    _grantDate = value;
                    _syncDateController(_grantDateController, value);
                    if (_maturityDate != null &&
                        value != null &&
                        _maturityDate!.isBefore(value)) {
                      _maturityDate = value;
                      _syncDateController(_maturityDateController, value);
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Date d echeance',
              subtitle: 'Date de fin prevue',
              icon: Icons.event_busy_outlined,
              child: TextFormField(
                controller: _maturityDateController,
                readOnly: true,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Choisir une date'),
                  suffixIcon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: Color(0xFF7A8AA4),
                  ),
                ),
                validator: (value) {
                  if (_grantDate != null &&
                      _maturityDate != null &&
                      _maturityDate!.isBefore(_grantDate!)) {
                    return context.tr('Echeance anterieure a l octroi');
                  }
                  return null;
                },
                onTap: () => _pickDate(
                  currentValue: _maturityDate,
                  firstDate: _grantDate ?? DateTime(2000),
                  onChanged: (value) {
                    _maturityDate = value;
                    _syncDateController(_maturityDateController, value);
                    setState(() {});
                  },
                ),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Pays',
              subtitle: 'Pays de residence',
              icon: Icons.public_outlined,
              child: DropdownButtonFormField<String>(
                value: _countryController.text.trim().isEmpty
                    ? null
                    : _countryController.text.trim(),
                isExpanded: true,
                menuMaxHeight: 320,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Selectionner un pays'),
                ),
                validator: (value) {
                  final country = (value ?? _countryController.text).trim();
                  return country.isEmpty ? context.tr('Champ requis') : null;
                },
                selectedItemBuilder: (context) =>
                    _selectedStringDropdownItems(_availableCountryOptions),
                items: _stringDropdownItems(_availableCountryOptions),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _countryController.text = value;
                  });
                },
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Notation du pays',
              subtitle: 'Pays de residence',
              icon: Icons.flag_circle_outlined,
              child: DropdownButtonFormField<String>(
                value: _resolveRatingValue(
                  _countryRating,
                  preferred: 'Non noté',
                ),
                isExpanded: true,
                decoration: _fieldDecoration(context),
                selectedItemBuilder: (context) =>
                    _selectedStringDropdownItems(_availableRatings),
                items: _stringDropdownItems(_availableRatings),
                onChanged: (value) =>
                    setState(() => _countryRating = value ?? _countryRating),
              ),
            ),
          ],
        );
      case 2:
        return _CategoryStepScreen(
          title: _stepMetas[2].title,
          subtitle: _stepMetas[2].subtitle,
          formKey: _categoryFormKey,
          content: _buildCategoryStepBody(context),
        );
      case 3:
        return _FinancialDataStepScreen(
          title: _stepMetas[3].title,
          subtitle: _stepMetas[3].subtitle,
          formKey: _financialFormKey,
          fields: [
            _buildFieldCard(
              context: context,
              title: 'Montant brut',
              subtitle: 'Montant de l exposition',
              icon: Icons.payments_outlined,
              child: TextFormField(
                controller: _amountController,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Montant brut'),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = _parseDecimal(value);
                  return parsed == null ? context.tr('Montant invalide') : null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Devise',
              subtitle: 'Devise de saisie',
              icon: Icons.currency_exchange_outlined,
              child: DropdownButtonFormField<String>(
                value: _currency,
                decoration: _fieldDecoration(context),
                items: const ['XOF', 'XAF', 'EUR', 'USD']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _currency = value ?? _currency),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'CRM existe ?',
              subtitle: 'Presence d une couverture',
              icon: Icons.handshake_outlined,
              child: DropdownButtonFormField<String>(
                value: _crmExists ? 'OUI' : 'NON',
                decoration: _fieldDecoration(context),
                items: const ['OUI', 'NON']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  final nextValue = value ?? 'NON';
                  _setCrmExists(nextValue == 'OUI');
                },
              ),
            ),
          ],
          helper: const SizedBox.shrink(),
        );
      case 4:
        if (_crmSelectionStage) {
          return _CrmChoiceStepScreen(
            title: _stepMetas[4].title,
            subtitle: 'Choisissez d abord le type de CRM',
            selectedMode: _crmMode,
            choices: [
              _ChoiceCardData(
                value: 'CRM financee',
                label: context.tr('CRM financee'),
                icon: Icons.shield_outlined,
                accent: const Color(0xFF0F766E),
              ),
              _ChoiceCardData(
                value: 'CRM non financee',
                label: context.tr('CRM non financee'),
                icon: Icons.handshake_outlined,
                accent: AppTheme.accent,
              ),
            ],
            onModeChanged: (value) {
              setState(() {
                _crmMode = value;
                _lastSelectedCrmMode = value;
              });
            },
          );
        }
        return _CrmDetailsStepScreen(
          title:
              _crmMode == 'CRM financee' ? 'CRM financee' : 'CRM non financee',
          subtitle: _crmMode == 'CRM financee'
              ? 'Parametres de la surete financee'
              : 'Parametres de la garantie non financee',
          formKey: _crmFormKey,
          icon: _crmMode == 'CRM financee'
              ? Icons.shield_outlined
              : Icons.handshake_outlined,
          accent: _crmMode == 'CRM financee'
              ? const Color(0xFF0F766E)
              : AppTheme.accent,
          child: _buildCrmDynamicBody(context),
        );
      case 5:
        return _CommentStepScreen(
          title: _stepMetas[5].title,
          subtitle: _stepMetas[5].subtitle,
          formKey: _commentFormKey,
          commentField: TextFormField(
            controller: _commentController,
            maxLines: 8,
            decoration: _fieldDecoration(
              context,
              hint: context.tr(
                'Commentaire de suivi, hypothese de gestion ou precision de validation',
              ),
            ),
          ),
        );
      case 6:
        return _FinalDecisionStepScreen(
          title: _stepMetas[6].title,
          subtitle: _stepMetas[6].subtitle,
          submitting: _submitting,
          onConfirm: _submit,
          onBack: _goBack,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool get _isSovereignCategory => _categoryCode == 'a';
  bool get _isPublicBodyCategory => _categoryCode == 'b';
  bool get _isBmdCategory => _categoryCode == 'c';
  bool get _isBankInstitutionCategory => _categoryCode == 'd';
  bool get _isRetailCategory => _categoryCode == 'f';
  bool get _isResidentialMortgageCategory => _categoryCode == 'g';
  bool get _isCommercialRealEstateCategory => _categoryCode == 'h';
  bool get _isDefaultedExposureCategory => _categoryCode == 'i';
  bool get _isHighRiskExposureCategory => _categoryCode == 'j';
  bool get _isOtherAssetsCategory => _categoryCode == 'k';
  bool get _isOffBalanceCategory => _categoryCode == 'l';
  bool get _isEnterpriseCategory => _categoryCode == 'e';
  bool get _usesRetailEnterpriseLogic =>
      _isRetailCategory && _retailEligibilityCriteriaSatisfied == false;
  bool get _usesCommercialRealEstateEnterpriseLogic =>
      _isCommercialRealEstateCategory && _commercialRealEstateEligible == false;
  bool get _isEnterpriseLikeCategory =>
      _isEnterpriseCategory ||
      _usesRetailEnterpriseLogic ||
      _usesCommercialRealEstateEnterpriseLogic;
  bool get _hasSovereignPriorityCase =>
      _isSovereignCategory &&
      hasSovereignPriorityZeroWeightCase(
        _sovereignSpecialCase,
        sovereignPreferentialZeroWeight: _sovereignPreferentialZeroWeight,
      );
  bool get _usesPublicBodyEnterpriseLogic =>
      _isPublicBodyCategory &&
      hasPublicBodyEnterpriseOverride(
        _publicBodyUemoaFcfaCase,
        _publicBodyFinancesNonPublicActivity,
      );
  bool get _hasBmdPriorityCase =>
      _isBmdCategory &&
      hasBmdPriorityZeroWeightCase(
        bmdHighQualityCase: _bmdHighQualityCase,
        bmdUemoaFcfaCase: _bmdUemoaFcfaCase,
        bmdUemoaCriteriaSatisfied: _bmdUemoaCriteriaSatisfied,
        bmdListedInstitutionFcfaCase: _bmdListedInstitutionFcfaCase,
      );
  bool get _shouldShowBmdListedInstitutionQuestion =>
      _isBmdCategory &&
      _bmdHighQualityCase == false &&
      ((_bmdUemoaFcfaCase == true && _bmdUemoaCriteriaSatisfied == false) ||
          _bmdUemoaFcfaCase == false);
  bool get _shouldShowBmdRatingField =>
      _isBmdCategory &&
      !_hasBmdPriorityCase &&
      _bmdHighQualityCase == false &&
      _bmdUemoaFcfaCase != null &&
      (_bmdUemoaFcfaCase == false || _bmdUemoaCriteriaSatisfied != null) &&
      _bmdListedInstitutionFcfaCase == false;
  bool get _usesBankInstitutionMatrix =>
      _isBankInstitutionCategory &&
      _bankInstitutionCase == bankInstitutionEligibleCategoriesCase;
  bool get _usesEnterprisePrudentialPenalty =>
      _isEnterpriseLikeCategory &&
      _enterpriseExceedsBceaoDegradationThreshold == false &&
      _enterprisePrudentialProcedure == true;
  bool get _shouldAskEnterprisePrudentialProcedure =>
      _isEnterpriseLikeCategory &&
      _enterpriseExceedsBceaoDegradationThreshold == false;
  bool get _shouldAskEnterpriseInvestmentFirm =>
      _isEnterpriseLikeCategory &&
      _enterpriseExceedsBceaoDegradationThreshold == false &&
      _enterprisePrudentialProcedure == false;
  bool get _shouldShowEnterpriseRatingField =>
      _isEnterpriseLikeCategory &&
      _enterpriseExceedsBceaoDegradationThreshold == false &&
      _enterprisePrudentialProcedure == false &&
      _enterpriseInvestmentFirmWithoutBankingLaw != null;
  bool get _usesDefaultedExposureCarryForward =>
      _isDefaultedExposureCategory &&
      (_defaultedExposureInitialRiskWeight ?? 0) > 1.0;
  bool get _shouldAskDefaultedResidentialQuestion =>
      _isDefaultedExposureCategory &&
      _defaultedExposureInitialRiskWeight != null &&
      _defaultedExposureInitialRiskWeight! <= 1.0;
  bool get _shouldAskDefaultedProvisionLevel =>
      _shouldAskDefaultedResidentialQuestion &&
      _defaultedExposureResidentialMortgageInDefault == false;
  bool get _hasBankInitialMaturityDates =>
      _grantDate != null && _maturityDate != null;

  void _handleCategoryChanged(String? value) {
    final nextCode = value ?? _categoryCode;
    setState(() {
      _categoryCode = nextCode;
      if (!_isSovereignCategory) {
        _sovereignSpecialCase = sovereignNoSpecialCase;
        _sovereignPreferentialZeroWeight = false;
        _sovereignPriorityQuestionAnsweredYes = false;
        _sovereignOceEstablished = false;
        _sovereignOceNote = sovereignOceNotes.first;
      } else {
        _sovereignSpecialCase = coerceSovereignSpecialCase(
          _sovereignSpecialCase,
          fallbackToLegacy: _sovereignPreferentialZeroWeight,
        );
        _sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
          _sovereignSpecialCase,
          sovereignPreferentialZeroWeight: _sovereignPreferentialZeroWeight,
        );
        _sovereignPriorityQuestionAnsweredYes =
            _sovereignSpecialCase != sovereignNoSpecialCase ||
                _sovereignPreferentialZeroWeight;
        if (!sovereignRatingOptions.contains(_rating)) {
          _rating = 'Non noté';
        }
      }
      if (!_isPublicBodyCategory) {
        _publicBodyUemoaFcfaCase = null;
        _publicBodyFinancesNonPublicActivity = null;
      }
      if (!_isBmdCategory) {
        _bmdHighQualityCase = null;
        _bmdUemoaFcfaCase = null;
        _bmdUemoaCriteriaSatisfied = null;
        _bmdListedInstitutionFcfaCase = null;
      }
      if (!_isBankInstitutionCategory) {
        _bankInstitutionCase = null;
      }
      if (!_isOtherAssetsCategory) {
        _otherAssetType = null;
      }
      if (!_isOffBalanceCategory) {
        _offBalanceRiskLevel = null;
      }
      if (!_isRetailCategory) {
        _retailEligibilityCriteriaSatisfied = null;
      }
      if (!_isResidentialMortgageCategory) {
        _residentialMortgageEligible = null;
      }
      if (!_isCommercialRealEstateCategory) {
        _commercialRealEstateEligible = null;
      }
      if (!_isDefaultedExposureCategory) {
        _defaultedExposureInitialRiskWeight = null;
        _defaultedExposureResidentialMortgageInDefault = null;
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
      if (!_isEnterpriseLikeCategory) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
      if ((_isBmdCategory || _isBankInstitutionCategory) &&
          !prudentialRatings.contains(_rating)) {
        _rating = 'Non noté';
      }
      if (_isEnterpriseLikeCategory &&
          !enterpriseRatingOptions.contains(_rating)) {
        _rating = 'Non noté';
      }
    });
  }

  String _retailCriteriaTooltip(BuildContext context) {
    return [
      context.tr('Destination : particulier ou PME/PMI'),
      context.tr(
          'Produits concernés : crédits CT/MT/LT, découverts, cartes de crédit, crédit-bail, facilités aux PME'),
      context
          .tr('Granularité : exposition ≤ 0,2 % du portefeuille retail global'),
      context.tr(
          'Faible montant : encours agrégé par contrepartie ≤ 150 millions FCFA'),
      context.tr(
          'Consentement BIC : accord du client pour transmission des données au BIC'),
    ].join('\n');
  }

  void _handlePublicBodyUemoaQuestionChanged(bool? value) {
    setState(() {
      _publicBodyUemoaFcfaCase = value;
      if (value != true) {
        _publicBodyFinancesNonPublicActivity = null;
      }
    });
  }

  void _handlePublicBodyNonPublicActivityChanged(bool? value) {
    setState(() {
      _publicBodyFinancesNonPublicActivity = value;
    });
  }

  void _handleBmdHighQualityChanged(bool? value) {
    setState(() {
      _bmdHighQualityCase = value;
      _bmdUemoaFcfaCase = null;
      _bmdUemoaCriteriaSatisfied = null;
      _bmdListedInstitutionFcfaCase = null;
    });
  }

  void _handleBmdUemoaQuestionChanged(bool? value) {
    setState(() {
      _bmdUemoaFcfaCase = value;
      _bmdUemoaCriteriaSatisfied = null;
      _bmdListedInstitutionFcfaCase = null;
    });
  }

  void _handleBmdUemoaCriteriaChanged(bool? value) {
    setState(() {
      _bmdUemoaCriteriaSatisfied = value;
      _bmdListedInstitutionFcfaCase = null;
    });
  }

  void _handleBmdListedInstitutionChanged(bool? value) {
    setState(() {
      _bmdListedInstitutionFcfaCase = value;
    });
  }

  void _handleBankInstitutionCaseChanged(String? value) {
    final resolvedValue = coerceBankInstitutionCase(value);
    setState(() {
      _bankInstitutionCase = resolvedValue;
      if (_usesBankInstitutionMatrix && !prudentialRatings.contains(_rating)) {
        _rating = 'Non noté';
      }
    });
  }

  void _handleOtherAssetTypeChanged(String? value) {
    setState(() {
      _otherAssetType = coerceOtherAssetType(value);
    });
  }

  void _handleOffBalanceRiskLevelChanged(String? value) {
    setState(() {
      _offBalanceRiskLevel = coerceOffBalanceRiskLevel(value);
    });
  }

  void _handleEnterpriseBceaoDegradationChanged(bool? value) {
    setState(() {
      _enterpriseExceedsBceaoDegradationThreshold = value;
      if (value != false) {
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
    });
  }

  void _handleEnterprisePrudentialProcedureChanged(bool? value) {
    setState(() {
      _enterprisePrudentialProcedure = value;
      if (value != false) {
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
    });
  }

  void _handleEnterpriseInvestmentFirmChanged(bool? value) {
    setState(() {
      _enterpriseInvestmentFirmWithoutBankingLaw = value;
    });
  }

  void _handleRetailEligibilityChanged(bool? value) {
    setState(() {
      _retailEligibilityCriteriaSatisfied = value;
      if (value != false) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      } else if (!enterpriseRatingOptions.contains(_rating)) {
        _rating = 'Non noté';
      }
    });
  }

  void _handleResidentialMortgageEligibilityChanged(bool? value) {
    setState(() {
      _residentialMortgageEligible = value;
    });
  }

  void _handleCommercialRealEstateEligibilityChanged(bool? value) {
    setState(() {
      _commercialRealEstateEligible = value;
      if (value != false) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      } else if (!enterpriseRatingOptions.contains(_rating)) {
        _rating = 'Non noté';
      }
    });
  }

  void _handleDefaultedExposureInitialRiskWeightChanged(double? value) {
    setState(() {
      _defaultedExposureInitialRiskWeight = value;
      if (value == null || value > 1.0) {
        _defaultedExposureResidentialMortgageInDefault = null;
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
    });
  }

  void _handleDefaultedExposureResidentialMortgageChanged(bool? value) {
    setState(() {
      _defaultedExposureResidentialMortgageInDefault = value;
      if (value != false) {
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
    });
  }

  void _handleDefaultedExposureProvisionLevelChanged(bool? value) {
    setState(() {
      _defaultedExposureProvisionAtLeastTwentyPercent = value;
    });
  }

  void _handleSovereignPriorityQuestionChanged(bool? value) {
    final answeredYes = value ?? false;
    setState(() {
      _sovereignPriorityQuestionAnsweredYes = answeredYes;
      if (!answeredYes) {
        _sovereignSpecialCase = sovereignNoSpecialCase;
        _sovereignPreferentialZeroWeight = false;
        _sovereignOceEstablished = false;
        _sovereignOceNote = sovereignOceNotes.first;
      } else if (_sovereignSpecialCase == sovereignNoSpecialCase) {
        _sovereignSpecialCase = sovereignLegacySpecialCase;
        _sovereignPreferentialZeroWeight = true;
        _sovereignOceEstablished = false;
        _sovereignOceNote = sovereignOceNotes.first;
      }
    });
  }

  void _handleCounterpartyRatingChanged(String? value) {
    final nextRating = value ?? _rating;
    setState(() {
      _rating = nextRating;
      if (_rating != 'Non noté') {
        _sovereignOceEstablished = false;
        _sovereignOceNote = sovereignOceNotes.first;
      }
    });
  }

  Widget _buildCategoryStepBody(BuildContext context) {
    final cards = <Widget>[
      _StepGridFullWidth(
        child: _buildFieldCard(
          context: context,
          title: 'Categorie prudentielle',
          subtitle: 'Type d exposition',
          icon: Icons.account_tree_outlined,
          child: DropdownButtonFormField<String>(
            value: exposureCategories.any((item) => item.code == _categoryCode)
                ? _categoryCode
                : 'e',
            isExpanded: true,
            decoration: _fieldDecoration(context),
            validator: (value) => value == null || value.trim().isEmpty
                ? context.tr('Champ requis')
                : null,
            selectedItemBuilder: (context) => exposureCategories
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(growable: false),
            items: exposureCategories
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.code,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(),
            onChanged: _handleCategoryChanged,
          ),
        ),
      ),
    ];

    if (_isPublicBodyCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Cas UEMOA en FCFA ?',
            subtitle:
                'Organisme public hors administration centrale des Etats de l UEMOA',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<bool>(
              value: _publicBodyUemoaFcfaCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handlePublicBodyUemoaQuestionChanged,
            ),
          ),
        ),
      );
    }

    if (_isPublicBodyCategory && _publicBodyUemoaFcfaCase == true) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: "L'organisme finance-t-il une activité non publique ?",
            subtitle: '',
            icon: Icons.domain_verification_outlined,
            child: DropdownButtonFormField<bool>(
              value: _publicBodyFinancesNonPublicActivity,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handlePublicBodyNonPublicActivityChanged,
            ),
          ),
        ),
      );
    }

    if (_isSovereignCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'Cette exposition concerne-t-elle des souverains UEMOA/BCEAO ou leurs démembrements libellés et financés en FCFA, ou des institutions internationales ?',
            subtitle: '',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<bool>(
              value: _sovereignPriorityQuestionAnsweredYes,
              decoration: _fieldDecoration(context),
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleSovereignPriorityQuestionChanged,
            ),
          ),
        ),
      );
    }

    if (_isBmdCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition concerne-t-elle une BMD répondant aux critères suivants ?',
            subtitle: "Consultez l'icône pour en savoir plus sur les critères.",
            icon: Icons.account_balance_outlined,
            inlineTooltip: _bmdCriteriaTooltip,
            hideLeadingIcon: true,
            subtitleColor: AppTheme.accent,
            child: DropdownButtonFormField<bool>(
              value: _bmdHighQualityCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdHighQualityChanged,
            ),
          ),
        ),
      );
    }

    if (_isBmdCategory && _bmdHighQualityCase == false) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition concerne-t-elle une BMD des États de l’UEMOA libellée et financée en FCFA ?',
            subtitle: '',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<bool>(
              value: _bmdUemoaFcfaCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdUemoaQuestionChanged,
            ),
          ),
        ),
      );
    }

    if (_isBmdCategory &&
        _bmdHighQualityCase == false &&
        _bmdUemoaFcfaCase == true) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'La BMD respecte-t-elle les critères c), d) et e) ?',
            subtitle: '',
            icon: Icons.fact_check_outlined,
            inlineTooltip: _bmdCdeCriteriaTooltip,
            child: DropdownButtonFormField<bool>(
              value: _bmdUemoaCriteriaSatisfied,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdUemoaCriteriaChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldShowBmdListedInstitutionQuestion) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition concerne-t-elle l’une des institutions suivantes : BIRD, SFI, BAsD, BAD, BERD, BEI, FEI, BNI, BDC, BIsD, BDCE, AMGI ou BOAD libellée et financée en FCFA ?',
            subtitle: 'Consulter l’icône info pour voir les sigles.',
            icon: Icons.account_balance_outlined,
            inlineTooltip: _bmdInstitutionsTooltip,
            tooltipTitle: 'Sigles',
            child: DropdownButtonFormField<bool>(
              value: _bmdListedInstitutionFcfaCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdListedInstitutionChanged,
            ),
          ),
        ),
      );
    }

    if (_isBankInstitutionCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: "Situation de l'institution bancaire",
            subtitle: 'Choisir le traitement applicable',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<String>(
              value: _bankInstitutionCase,
              isExpanded: true,
              decoration: _fieldDecoration(context,
                  hint: context.tr('Choisir une option')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Champ requis')
                  : null,
              selectedItemBuilder: (context) => bankInstitutionCaseOptions
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: _bankInstitutionCaseDropdownLabel(item),
                    ),
                  )
                  .toList(growable: false),
              items: bankInstitutionCaseOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: _bankInstitutionCaseDropdownLabel(
                        item,
                        includeInfoIcon: true,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _handleBankInstitutionCaseChanged,
            ),
          ),
        ),
      );
    }

    if (_isOtherAssetsCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Type d’élément d’actif',
            subtitle: '',
            icon: Icons.inventory_2_outlined,
            inlineTooltip:
                'Les autres éléments d’actifs correspondent aux expositions non prises en compte dans les autres catégories prudentielles, hors éléments déjà déduits des fonds propres et hors expositions soumises à des exigences spécifiques.',
            tooltipTitle: 'Définition',
            placeInlineTooltipBeforeTitle: true,
            child: DropdownButtonFormField<String>(
              value: _otherAssetType,
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Choisir une option'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Champ requis')
                  : null,
              selectedItemBuilder: (context) => otherAssetTypeOptions
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: _otherAssetTypeDropdownLabel(item),
                    ),
                  )
                  .toList(growable: false),
              items: otherAssetTypeOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: _otherAssetTypeDropdownLabel(
                        item,
                        includeInfoIcon: true,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _handleOtherAssetTypeChanged,
            ),
          ),
        ),
      );
    }

    if (_isOffBalanceCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Niveau de risque hors bilan',
            subtitle: '',
            icon: Icons.assessment_outlined,
            child: DropdownButtonFormField<String>(
              value: _offBalanceRiskLevel,
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Choisir une option'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Champ requis')
                  : null,
              selectedItemBuilder: (context) => offBalanceRiskLevelOptions
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: _offBalanceRiskLevelDropdownLabel(item),
                    ),
                  )
                  .toList(growable: false),
              items: offBalanceRiskLevelOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: _offBalanceRiskLevelDropdownLabel(
                        item,
                        includeInfoIcon: true,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _handleOffBalanceRiskLevelChanged,
            ),
          ),
        ),
      );
    }

    if (_isRetailCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition respecte-t-elle les critères de classement en clientèle de détail ?',
            subtitle: "Consulter l’icône info pour voir les critères.",
            icon: Icons.groups_2_outlined,
            inlineTooltip: _retailCriteriaTooltip(context),
            tooltipTitle: 'Critères',
            child: DropdownButtonFormField<bool>(
              value: _retailEligibilityCriteriaSatisfied,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleRetailEligibilityChanged,
            ),
          ),
        ),
      );
      if (_retailEligibilityCriteriaSatisfied == true) {
        cards.add(
          _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.rule_folder_outlined,
              accent: const Color(0xFF2563EB),
              text:
                  '• ${context.tr('En cas de défaut, l’exposition relève de la catégorie des expositions en défaut.')}\n'
                  '• ${context.tr('Les actions, obligations et créances hypothécaires bénéficiant d’un régime spécifique ne relèvent pas de la clientèle de détail.')}',
            ),
          ),
        );
      }
    }

    if (_isResidentialMortgageCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                "L’exposition respecte-t-elle les conditions d’éligibilité des prêts garantis par l’immobilier résidentiel ?",
            subtitle: "Consulter l’icône info pour voir les critères.",
            icon: Icons.home_work_outlined,
            inlineTooltip: _residentialMortgageCriteriaTooltip,
            tooltipTitle: 'Critères',
            child: DropdownButtonFormField<bool>(
              value: _residentialMortgageEligible,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleResidentialMortgageEligibilityChanged,
            ),
          ),
        ),
      );

      if (_residentialMortgageEligible == false) {
        cards.add(
          _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.swap_horiz_rounded,
              accent: const Color(0xFFF59E0B),
              text:
                  "La pondération de 35 % n’est pas appliquée.\nSélectionner une catégorie prudentielle appropriée pour poursuivre.",
            ),
          ),
        );
      }

      cards.add(
        _StepGridFullWidth(
          child: _InfoBanner(
            icon: Icons.analytics_outlined,
            accent: const Color(0xFF2563EB),
            text:
                'La pondération peut être relevée au-delà de 35 % si la qualité du portefeuille global se dégrade selon les seuils BCEAO.',
          ),
        ),
      );
    }

    if (_isCommercialRealEstateCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                "L’exposition respecte-t-elle les conditions d’éligibilité de l’immobilier commercial ?",
            subtitle: "Consulter l’icône info pour voir les critères.",
            icon: Icons.business_outlined,
            inlineTooltip: _commercialRealEstateCriteriaTooltip,
            tooltipTitle: 'Critères',
            child: DropdownButtonFormField<bool>(
              value: _commercialRealEstateEligible,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleCommercialRealEstateEligibilityChanged,
            ),
          ),
        ),
      );

      if (_commercialRealEstateEligible == false) {
        cards.add(
          _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.apartment_outlined,
              accent: const Color(0xFFF59E0B),
              text:
                  "La pondération de 75 % n’est pas appliquée.\nL’exposition est traitée comme une créance sur une entreprise.",
            ),
          ),
        );
      }

      if (_commercialRealEstateEligible == true) {
        cards.add(
          _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.analytics_outlined,
              accent: const Color(0xFF2563EB),
              text:
                  'La pondération peut être relevée au-delà de 75 % en cas de dégradation du portefeuille selon les règles applicables.',
            ),
          ),
        );
      }
    }

    if (_isDefaultedExposureCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'Quelle est la pondération initiale de l’exposition avant défaut ?',
            subtitle: 'Sélectionner le niveau avant défaut',
            icon: Icons.percent_outlined,
            child: DropdownButtonFormField<double>(
              value: _defaultedExposureInitialRiskWeight,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              selectedItemBuilder: (context) =>
                  defaultedExposureInitialRiskWeightOptions
                      .map((item) => Text(_formatPercent(item)))
                      .toList(growable: false),
              items: defaultedExposureInitialRiskWeightOptions
                  .map(
                    (item) => DropdownMenuItem<double>(
                      value: item,
                      child: Text(_formatPercent(item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _handleDefaultedExposureInitialRiskWeightChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldAskDefaultedResidentialQuestion) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition est-elle un prêt immobilier résidentiel en défaut ?',
            subtitle: '',
            icon: Icons.home_outlined,
            child: DropdownButtonFormField<bool>(
              value: _defaultedExposureResidentialMortgageInDefault,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleDefaultedExposureResidentialMortgageChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldAskDefaultedProvisionLevel) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Quel est le niveau de provisions constitué sur l’encours ?',
            subtitle: '',
            icon: Icons.inventory_2_outlined,
            child: DropdownButtonFormField<bool>(
              value: _defaultedExposureProvisionAtLeastTwentyPercent,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Provisions < 20 % de l’encours')),
                ),
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Provisions ≥ 20 % de l’encours')),
                ),
              ],
              onChanged: _handleDefaultedExposureProvisionLevelChanged,
            ),
          ),
        ),
      );
    }

    if (_usesDefaultedExposureCarryForward) {
      cards.add(
        _StepGridFullWidth(
          child: _InfoBanner(
            icon: Icons.sync_alt_outlined,
            accent: const Color(0xFF2563EB),
            text:
                "La même pondération que l’exposition avant défaut est conservée.",
          ),
        ),
      );
    }

    if (_isEnterpriseLikeCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Le portefeuille entreprises dépasse-t-il le seuil BCEAO ?',
            subtitle: 'Deux trimestres consécutifs',
            icon: Icons.insights_outlined,
            inlineTooltip: _enterpriseArticle133Tooltip,
            tooltipTitle: 'Article 133',
            child: DropdownButtonFormField<bool>(
              value: _enterpriseExceedsBceaoDegradationThreshold,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleEnterpriseBceaoDegradationChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldAskEnterprisePrudentialProcedure) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                "L'entreprise fait-elle l'objet d'une procédure prudentielle ?",
            subtitle: 'Vérification réglementaire',
            icon: Icons.policy_outlined,
            inlineTooltip: _enterpriseArticle133Tooltip,
            tooltipTitle: 'Article 133',
            child: DropdownButtonFormField<bool>(
              value: _enterprisePrudentialProcedure,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleEnterprisePrudentialProcedureChanged,
            ),
          ),
        ),
      );
    }

    if (_usesEnterprisePrudentialPenalty) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Procédure prudentielle détectée',
            subtitle: 'Pondération renforcée appliquée',
            icon: Icons.gpp_bad_outlined,
            inlineTooltip: _enterpriseArticle133Tooltip,
            tooltipTitle: 'Article 133',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: _wizardInputFillColor(context),
                borderRadius: BorderRadius.circular(_exposureFormRadius),
                border: Border.all(color: _wizardBorderColor(context)),
              ),
              child: Text(
                context.tr('Pondération appliquée : 150 %'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11.6,
                      fontWeight: FontWeight.w700,
                      color: _wizardBodyTitleColor(context),
                    ),
              ),
            ),
          ),
        ),
      );
    }

    if (_shouldAskEnterpriseInvestmentFirm) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                "S'agit-il d'une entreprise d'investissement non soumise à la loi bancaire ?",
            subtitle: 'Traitement spécifique',
            icon: Icons.corporate_fare_outlined,
            child: DropdownButtonFormField<bool>(
              value: _enterpriseInvestmentFirmWithoutBankingLaw,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleEnterpriseInvestmentFirmChanged,
            ),
          ),
        ),
      );
    }

    final shouldShowRatingField =
        (_isSovereignCategory && !_sovereignPriorityQuestionAnsweredYes) ||
            (_isPublicBodyCategory &&
                (_publicBodyUemoaFcfaCase == false ||
                    _usesPublicBodyEnterpriseLogic)) ||
            (_isBmdCategory && _shouldShowBmdRatingField) ||
            (_isBankInstitutionCategory && _usesBankInstitutionMatrix) ||
            _shouldShowEnterpriseRatingField ||
            (!_isSovereignCategory &&
                !_isPublicBodyCategory &&
                !_isBmdCategory &&
                !_isBankInstitutionCategory &&
                !_isEnterpriseCategory &&
                !_isRetailCategory &&
                !_isResidentialMortgageCategory &&
                !_isCommercialRealEstateCategory &&
                !_isDefaultedExposureCategory &&
                !_isHighRiskExposureCategory &&
                !_isOtherAssetsCategory &&
                !_isOffBalanceCategory);
    final ratingOptions = _isSovereignCategory ||
            _isPublicBodyCategory ||
            _isBmdCategory ||
            _isBankInstitutionCategory
        ? prudentialRatings
        : _isEnterpriseLikeCategory
            ? enterpriseRatingOptions
            : _availableRatings;

    if (shouldShowRatingField) {
      final ratingCard = _buildFieldCard(
        context: context,
        title: _isEnterpriseLikeCategory
            ? "Notation de l'entreprise"
            : _isBankInstitutionCategory
                ? 'Notation de l institution'
                : _isSovereignCategory
                    ? 'Notation de la contrepartie'
                    : _isBmdCategory
                        ? 'Notation de la BMD'
                        : _usesPublicBodyEnterpriseLogic
                            ? 'Notation de la contrepartie'
                            : _isPublicBodyCategory
                                ? 'Notation de l organisme public'
                                : 'Notation de la contrepartie',
        subtitle: _isEnterpriseLikeCategory
            ? ''
            : _isBankInstitutionCategory
                ? ''
                : _isSovereignCategory
                    ? 'Notation externe'
                    : _isBmdCategory
                        ? 'Pondération automatique selon la notation sélectionnée.'
                        : _usesPublicBodyEnterpriseLogic
                            ? 'Traitement comme une entreprise'
                            : _isPublicBodyCategory
                                ? 'Ponderation automatique'
                                : 'Note de credit',
        icon: Icons.stars_outlined,
        inlineTooltip:
            _isEnterpriseLikeCategory ? _enterpriseUnratedTooltip : null,
        tooltipTitle: _isEnterpriseLikeCategory ? 'Article 134' : 'Critères',
        child: DropdownButtonFormField<String>(
          value: _resolveRatingValue(
            _rating,
            preferred: (_isSovereignCategory ||
                    _isPublicBodyCategory ||
                    _isBmdCategory ||
                    _isEnterpriseLikeCategory ||
                    _isBankInstitutionCategory)
                ? 'Non noté'
                : 'BBB',
          ),
          isExpanded: true,
          decoration: _fieldDecoration(context),
          validator: (value) {
            if ((_isSovereignCategory ||
                    _isPublicBodyCategory ||
                    _isBmdCategory ||
                    _isEnterpriseLikeCategory ||
                    _isBankInstitutionCategory) &&
                (value == null || value.trim().isEmpty)) {
              return context.tr('Champ requis');
            }
            return null;
          },
          selectedItemBuilder: (context) =>
              _selectedStringDropdownItems(ratingOptions),
          items: _stringDropdownItems(ratingOptions),
          onChanged: _handleCounterpartyRatingChanged,
        ),
      );
      cards.add(
        (_isBankInstitutionCategory || _isEnterpriseLikeCategory)
            ? _StepGridFullWidth(child: ratingCard)
            : ratingCard,
      );
    }

    if (_isSovereignCategory &&
        !_sovereignPriorityQuestionAnsweredYes &&
        _rating == 'Non noté') {
      cards.add(
        _buildFieldCard(
          context: context,
          title: 'Le souverain est-il établi par les OCE ?',
          subtitle: '',
          icon: Icons.fact_check_outlined,
          child: CheckboxListTile(
            value: _sovereignOceEstablished,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              context.tr('Oui'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    color: _wizardBodyTitleColor(context),
                  ),
            ),
            onChanged: (value) {
              setState(() {
                _sovereignOceEstablished = value ?? false;
                if (!_sovereignOceEstablished) {
                  _sovereignOceNote = sovereignOceNotes.first;
                }
              });
            },
          ),
        ),
      );
    }

    if (_isSovereignCategory &&
        !_hasSovereignPriorityCase &&
        _rating == 'Non noté' &&
        _sovereignOceEstablished) {
      cards.add(
        _buildFieldCard(
          context: context,
          title: 'Note OCE',
          subtitle: 'Échelle de 0 à 7',
          icon: Icons.filter_8_outlined,
          child: DropdownButtonFormField<String>(
            value: sovereignOceNotes.contains(_sovereignOceNote)
                ? _sovereignOceNote
                : sovereignOceNotes.first,
            isExpanded: true,
            decoration: _fieldDecoration(context),
            selectedItemBuilder: (context) => _selectedStringDropdownItems(
              sovereignOceNotes,
            ),
            items: _stringDropdownItems(sovereignOceNotes),
            onChanged: (value) => setState(
              () => _sovereignOceNote = value ?? _sovereignOceNote,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepGrid(children: cards),
      ],
    );
  }

  Widget _buildInlineStepFooter(BuildContext context) {
    final isFirst = _currentStep == 1;
    final isLast = _currentStep == _stepMetas.length - 1;
    if (isLast) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _submitting || isFirst ? null : _goBack,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            backgroundColor: _wizardCardColor(context),
            foregroundColor: _wizardMutedColor(context),
            side: BorderSide(color: _wizardBorderColor(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_exposureFormRadius),
            ),
          ),
          icon: const Icon(Icons.west_rounded, size: 14),
          label: Text(
            context.tr('Precedent'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10.2,
            ),
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _submitting ? null : _handlePrimaryAction,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_exposureFormRadius),
            ),
          ),
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.east_rounded, size: 16),
          label: Text(
            context.tr('Suivant'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 10.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 14, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF13233D),
                    Color(0xFF0F2430),
                  ]
                : const [
                    Color(0xFFF8FBFF),
                    Color(0xFFF2FAF8),
                  ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(_exposureFormRadius),
          border: Border.all(
            color: isDark ? const Color(0xFF293B58) : const Color(0xFFDCE5F3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF0F766E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_exposureFormRadius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title.tr(context),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _wizardTitleColor(context),
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    context.tr(
                      'Parcours guide en plusieurs etapes pour une saisie claire, rapide et metier.',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _wizardMutedColor(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF182944).withOpacity(0.98)
                    : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(_exposureFormRadius),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF30435F)
                      : const Color(0xFFD7E2F2),
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _submitting ? null : widget.onCancel,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _wizardBodyTitleColor(context),
                ),
                tooltip: context.tr('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingOverlay(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Positioned.fill(
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withOpacity(
          isDark ? 0.36 : 0.46,
        ),
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _wizardCardColor(context),
            borderRadius: BorderRadius.circular(_exposureFormRadius),
            border: Border.all(color: _wizardBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialDraft == null
                          ? context.tr('Ajout de l exposition en cours...')
                          : context
                              .tr('Mise a jour de l exposition en cours...'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Traitement en cours... Cette operation peut prendre quelques secondes.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _wizardMutedColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_KpiData> _buildIntroKpis(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
  ) {
    final maturityMonths = (_grantDate != null && _maturityDate != null)
        ? _positiveMonthDifference(_grantDate!, _maturityDate!)
        : null;
    final residualMaturityMonths = _maturityDate != null
        ? _positiveMonthDifference(DateTime.now(), _maturityDate!)
        : null;
    final isOffBalance = _isOffBalanceCategory;
    final counterpartyName = _nameController.text.trim();
    final residenceCountry = _countryController.text.trim();
    final detectedZone = _detectedCountryZone;
    final crmTypeLabel = switch (_crmMode) {
      'CRM financee' => 'Financee',
      'CRM non financee' => 'Non financee',
      _ => 'Aucune',
    };
    return [
      _KpiData(
        label: context.tr('Contrepartie'),
        value: counterpartyName.isEmpty ? '-' : counterpartyName,
        icon: Icons.business_outlined,
        accent: const Color(0xFF2563EB),
      ),
      _KpiData(
        label: context.tr('Pays de residence'),
        value: residenceCountry.isEmpty ? '-' : residenceCountry,
        icon: Icons.flag_circle_outlined,
        accent: const Color(0xFF0891B2),
      ),
      _KpiData(
        label: context.tr('Zone'),
        value: detectedZone,
        icon: Icons.travel_explore_outlined,
        accent: _zoneAccentColor(detectedZone),
      ),
      _KpiData(
        label: context.tr('Type de CRM'),
        value: crmTypeLabel,
        icon: Icons.handshake_outlined,
        accent: const Color(0xFF0F766E),
      ),
      _KpiData(
        label: context.tr('EAD'),
        value: compactCurrencyForDisplay(
          preview.ead,
          fromCurrency: _currency,
          toCurrency: displayCurrency,
        ),
        icon: Icons.account_balance_wallet_outlined,
        accent: AppTheme.accent,
      ),
      if (isOffBalance)
        _KpiData(
          label: context.tr('Niveau de risque'),
          value: _offBalanceRiskLevel ?? '-',
          icon: Icons.warning_amber_rounded,
          accent: const Color(0xFFDC2626),
        )
      else
        _KpiData(
          label: context.tr('RW brut'),
          value: _formatPercent(preview.originalRw),
          icon: Icons.filter_tilt_shift_rounded,
          accent: const Color(0xFF14B8A6),
        ),
      _KpiData(
        label: isOffBalance ? context.tr('FCEC') : context.tr('RW final'),
        value: _formatPercent(preview.finalRw),
        icon: isOffBalance ? Icons.rule_folder_outlined : Icons.tune_rounded,
        accent:
            isOffBalance ? const Color(0xFF2563EB) : const Color(0xFFF59E0B),
      ),
      _KpiData(
        label: context.tr('RWA'),
        value: compactCurrencyForDisplay(
          preview.rwa,
          fromCurrency: _currency,
          toCurrency: displayCurrency,
        ),
        icon: Icons.analytics_outlined,
        accent: const Color(0xFF0F766E),
      ),
      _KpiData(
        label: context.tr('Maturite'),
        value: _formatMonthCount(maturityMonths),
        icon: Icons.date_range_outlined,
        accent: const Color(0xFF6366F1),
      ),
      _KpiData(
        label: context.tr('Maturite residuelle'),
        value: _formatMonthCount(residualMaturityMonths),
        icon: Icons.timelapse_rounded,
        accent: const Color(0xFF7C3AED),
      ),
    ];
  }

  Widget _buildCrmDynamicBody(BuildContext context) {
    if (_isOffBalanceCategory) {
      return _InfoBanner(
        icon: Icons.rule_folder_outlined,
        accent: const Color(0xFF2563EB),
        text: context.tr(
          'Le FCEC est déterminé automatiquement selon le niveau de risque hors bilan sélectionné.',
        ),
      );
    }

    if (_crmMode == 'Aucune') {
      return _InfoBanner(
        icon: Icons.info_outline,
        accent: const Color(0xFF64748B),
        text: context.tr(
          'Aucune attenuation selectionnee. Le RW final reste aligne sur le RW brut.',
        ),
      );
    }

    if (_crmMode == 'CRM financee') {
      return _StepGrid(
        children: [
          _buildFieldCard(
            context: context,
            title: 'Valeur du collateral',
            subtitle: 'Montant eligible',
            icon: Icons.account_balance_outlined,
            child: TextFormField(
              controller: _collateralController,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Valeur du collateral'),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _crmMode == 'CRM financee' ? _amountValidator : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _buildFieldCard(
            context: context,
            title: 'Type d emetteur',
            subtitle: 'Nature du collateral',
            icon: Icons.category_outlined,
            child: DropdownButtonFormField<String>(
              value: financedCrmIssuerTypes.contains(_issuerType)
                  ? _issuerType
                  : financedCrmIssuerTypes.first,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              selectedItemBuilder: (context) => _selectedStringDropdownItems(
                financedCrmIssuerTypes,
                translate: true,
              ),
              items: _stringDropdownItems(
                financedCrmIssuerTypes,
                translate: true,
              ),
              onChanged: (value) =>
                  setState(() => _issuerType = value ?? _issuerType),
            ),
          ),
          _buildFieldCard(
            context: context,
            title: 'Notation du collateral',
            subtitle: 'Qualite de l emetteur',
            icon: Icons.workspace_premium_outlined,
            child: DropdownButtonFormField<String>(
              value: financedCrmCollateralRatings.contains(_issuerRating)
                  ? _issuerRating
                  : financedCrmCollateralRatings.first,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              selectedItemBuilder: (context) => _selectedStringDropdownItems(
                financedCrmCollateralRatings,
              ),
              items: _stringDropdownItems(financedCrmCollateralRatings),
              onChanged: (value) =>
                  setState(() => _issuerRating = value ?? _issuerRating),
            ),
          ),
          _buildFieldCard(
            context: context,
            title: 'Maturite',
            subtitle: 'Bucket prudentiel',
            icon: Icons.schedule_outlined,
            child: DropdownButtonFormField<String>(
              value: financedCrmMaturityBuckets.contains(_maturityBucket)
                  ? _maturityBucket
                  : financedCrmMaturityBuckets.first,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              selectedItemBuilder: (context) => _selectedStringDropdownItems(
                financedCrmMaturityBuckets,
                translate: true,
              ),
              items: _stringDropdownItems(
                financedCrmMaturityBuckets,
                translate: true,
              ),
              onChanged: (value) =>
                  setState(() => _maturityBucket = value ?? _maturityBucket),
            ),
          ),
          _buildFieldCard(
            context: context,
            title: 'Decote de change',
            subtitle: 'Hfx en pourcentage',
            icon: Icons.percent_rounded,
            child: TextFormField(
              controller: _fxHaircutController,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Ex: 8'),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _crmMode == 'CRM financee' ? _percentValidator : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      );
    }

    return _StepGrid(
      children: [
        _buildFieldCard(
          context: context,
          title: 'Type de garantie',
          subtitle: 'Garantie ou assurance',
          icon: Icons.workspace_premium_outlined,
          child: DropdownButtonFormField<String>(
            value: _nonFinancedCrmTypes.contains(_crmType)
                ? _crmType
                : _nonFinancedCrmTypes.first,
            isExpanded: true,
            decoration: _fieldDecoration(context),
            selectedItemBuilder: (context) => _selectedStringDropdownItems(
              _nonFinancedCrmTypes,
              translate: true,
            ),
            items: _stringDropdownItems(
              _nonFinancedCrmTypes,
              translate: true,
            ),
            onChanged: (value) => setState(() => _crmType = value ?? _crmType),
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Nom du garant',
          subtitle: 'Entite couvrante',
          icon: Icons.person_outline_rounded,
          child: TextFormField(
            controller: _guarantorNameController,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Nom du garant'),
            ),
            validator:
                _crmMode == 'CRM non financee' ? _requiredValidator : null,
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Categorie du garant',
          subtitle: 'Profil prudentiel',
          icon: Icons.apartment_outlined,
          child: DropdownButtonFormField<String>(
            value:
                guarantorEligibleCategoryCodes.contains(_guarantorCategoryCode)
                    ? _guarantorCategoryCode
                    : guarantorEligibleCategoryCodes.first,
            isExpanded: true,
            decoration: _fieldDecoration(context),
            selectedItemBuilder: (context) => guarantorEligibleCategories
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(growable: false),
            items: guarantorEligibleCategories
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.code,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(
              () => _guarantorCategoryCode = value ?? _guarantorCategoryCode,
            ),
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Notation du garant',
          subtitle: 'Notation prise en compte',
          icon: Icons.star_border_rounded,
          child: DropdownButtonFormField<String>(
            value: _resolveRatingValue(
              _guarantorRating,
              preferred: 'AAA',
            ),
            isExpanded: true,
            decoration: _fieldDecoration(context),
            selectedItemBuilder: (context) =>
                _selectedStringDropdownItems(_availableRatings),
            items: _stringDropdownItems(_availableRatings),
            onChanged: (value) =>
                setState(() => _guarantorRating = value ?? _guarantorRating),
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Couverture',
          subtitle: 'Part de l exposition couverte',
          icon: Icons.pie_chart_outline_rounded,
          child: DropdownButtonFormField<double>(
            value: _coverageOptions.contains(_coverage)
                ? _coverage
                : _coverageOptions.first,
            decoration: _fieldDecoration(context),
            items: _coverageOptions
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text('${(item * 100).toStringAsFixed(0)} %'),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _coverage = value ?? _coverage),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    String? inlineTooltip,
    bool placeInlineTooltipBeforeTitle = false,
    bool hideLeadingIcon = false,
    String? iconTooltip,
    String tooltipTitle = 'Critères',
    Color? subtitleColor,
    required Widget child,
  }) {
    final compactTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 11.6,
          fontWeight: FontWeight.w600,
          color: _wizardBodyTitleColor(context),
        );

    return _CompactFieldCard(
      title: title.tr(context),
      subtitle: subtitle.tr(context),
      icon: icon,
      inlineTooltip: inlineTooltip?.tr(context),
      placeInlineTooltipBeforeTitle: placeInlineTooltipBeforeTitle,
      hideLeadingIcon: hideLeadingIcon,
      iconTooltip: iconTooltip?.tr(context),
      tooltipTitle: tooltipTitle.tr(context),
      subtitleColor: subtitleColor,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
                titleMedium: compactTextStyle,
                bodyLarge: compactTextStyle,
                bodyMedium: compactTextStyle,
              ),
        ),
        child: child,
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: _wizardInputFillColor(context),
      suffixIcon: suffixIcon,
      hintStyle: TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        color: _wizardMutedColor(context),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: BorderSide(color: _wizardBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.15),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: const BorderSide(color: AppTheme.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.15),
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_submitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_validateCurrentStep()) {
      return;
    }
    if (_currentStep == 3 && !_crmExists) {
      await _goToStep(5);
      return;
    }
    if (_currentStep == 3 && _crmExists) {
      setState(() {
        _crmSelectionStage = true;
      });
      await _goToStep(4);
      return;
    }
    if (_currentStep == 4 && _crmSelectionStage) {
      setState(() {
        _crmSelectionStage = false;
        _resetRightPanelStickyState();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_rightPanelScrollController.hasClients) {
          return;
        }
        _rightPanelScrollController.jumpTo(0);
      });
      return;
    }
    if (_currentStep == _stepMetas.length - 1) {
      await _submit();
      return;
    }
    await _goToStep(_currentStep + 1);
  }

  Future<void> _goBack() async {
    if (_currentStep <= 1) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (_currentStep == 4 && !_crmSelectionStage) {
      setState(() {
        _crmSelectionStage = true;
        _resetRightPanelStickyState();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_rightPanelScrollController.hasClients) {
          return;
        }
        _rightPanelScrollController.jumpTo(0);
      });
      return;
    }
    if (_currentStep == 5 && _crmExists) {
      setState(() {
        _crmSelectionStage = false;
      });
      await _goToStep(4);
      return;
    }
    final previousStep =
        (_currentStep == 5 && !_crmExists) ? 3 : _currentStep - 1;
    await _goToStep(previousStep);
  }

  Future<void> _goToStep(int target) async {
    var boundedTarget = target.clamp(1, _stepMetas.length - 1);
    if (!_crmExists && boundedTarget == 4) {
      boundedTarget = 5;
    }
    if (_currentStep == boundedTarget) {
      return;
    }
    setState(() {
      _currentStep = boundedTarget;
      _resetRightPanelStickyState();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rightPanelScrollController.hasClients) {
        return;
      }
      _rightPanelScrollController.jumpTo(0);
    });
  }

  bool _handleRightPanelScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    var nextDirection = _rightPanelScrollDirection;
    if (notification is UserScrollNotification) {
      nextDirection = notification.direction;
    }

    final offset = notification.metrics.pixels;
    final nextShowSticky = offset > 12;
    final nextExpandSticky = nextShowSticky &&
        (offset <= 64 || nextDirection == ScrollDirection.forward);

    if (nextShowSticky != _showStickyStepHeader ||
        nextExpandSticky != _expandStickyStepHeader ||
        nextDirection != _rightPanelScrollDirection) {
      _pendingShowStickyStepHeader = nextShowSticky;
      _pendingExpandStickyStepHeader = nextExpandSticky;
      _pendingRightPanelScrollDirection = nextDirection;
      if (!_rightPanelScrollSyncScheduled) {
        _rightPanelScrollSyncScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rightPanelScrollSyncScheduled = false;
          if (!mounted) {
            return;
          }
          final resolvedShowSticky =
              _pendingShowStickyStepHeader ?? _showStickyStepHeader;
          final resolvedExpandSticky =
              _pendingExpandStickyStepHeader ?? _expandStickyStepHeader;
          final resolvedDirection =
              _pendingRightPanelScrollDirection ?? _rightPanelScrollDirection;
          _pendingShowStickyStepHeader = null;
          _pendingExpandStickyStepHeader = null;
          _pendingRightPanelScrollDirection = null;
          if (resolvedShowSticky != _showStickyStepHeader ||
              resolvedExpandSticky != _expandStickyStepHeader ||
              resolvedDirection != _rightPanelScrollDirection) {
            setState(() {
              _showStickyStepHeader = resolvedShowSticky;
              _expandStickyStepHeader = resolvedExpandSticky;
              _rightPanelScrollDirection = resolvedDirection;
            });
          }
        });
      }
    }
    return false;
  }

  void _resetRightPanelStickyState() {
    _showStickyStepHeader = false;
    _expandStickyStepHeader = false;
    _rightPanelScrollDirection = ScrollDirection.idle;
    _pendingShowStickyStepHeader = null;
    _pendingExpandStickyStepHeader = null;
    _pendingRightPanelScrollDirection = null;
  }

  bool get _crmExists => _crmMode != 'Aucune';

  String _coerceGuarantorRating(String? value) {
    if (widget.ratings.contains(value)) {
      return value!;
    }
    if (widget.ratings.contains('AAA')) {
      return 'AAA';
    }
    return widget.ratings.isNotEmpty ? widget.ratings.first : '';
  }

  void _setCrmExists(bool exists) {
    setState(() {
      if (exists) {
        if (_crmMode == 'Aucune') {
          _crmMode = _lastSelectedCrmMode;
        }
        _crmSelectionStage = true;
      } else {
        if (_crmMode != 'Aucune') {
          _lastSelectedCrmMode = _crmMode;
        }
        _crmMode = 'Aucune';
        _crmSelectionStage = true;
      }
    });
  }

  Color _currentStepAccent() {
    switch (_currentStep) {
      case 1:
        return AppTheme.accent;
      case 2:
        return const Color(0xFF2563EB);
      case 3:
        return const Color(0xFF0F766E);
      case 4:
        return const Color(0xFF0891B2);
      case 5:
        return const Color(0xFFF59E0B);
      case 6:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  Widget _buildStickyStepHeader(BuildContext context) {
    final meta = _stepMetas[_currentStep];
    final accent = _currentStepAccent();
    final isExpanded = _expandStickyStepHeader;
    final isDark = _isExposureDark(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: isExpanded ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: _wizardCardColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x0A5B6B81),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isExpanded ? 32 : 24,
            height: isExpanded ? 32 : 24,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(_exposureFormRadius),
            ),
            child: Icon(
              meta.icon,
              color: accent,
              size: isExpanded ? 17 : 14,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                meta.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _wizardBodyTitleColor(context),
                      fontSize: 12.2,
                      height: 1.0,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _resetDraftValues() {
    final draft = widget.initialDraft;
    setState(() {
      _nameController.text = draft?.counterpartyName ?? 'Nouvelle contrepartie';
      _exposureIdController.text = draft?.id ?? '';
      _countryController.text = draft?.country ?? 'Cameroun';
      _countryRating = _resolveRatingValue(
        draft?.countryRating,
        preferred: 'Non noté',
      );
      _grantDate = draft?.grantDate;
      _maturityDate = draft?.maturityDate;
      _syncDateController(_grantDateController, _grantDate);
      _syncDateController(_maturityDateController, _maturityDate);
      _amountController.text =
          (draft?.grossAmount ?? 1000000).toStringAsFixed(0);
      _commentController.text = draft?.comment ?? '';
      _collateralController.text =
          (draft?.collateralValue ?? 0).toStringAsFixed(0);
      _fxHaircutController.text =
          ((draft?.fxHaircut ?? 0) * 100).toStringAsFixed(2);
      _guarantorNameController.text = draft?.guarantorName ?? '';
      _categoryCode =
          exposureCategories.any((item) => item.code == draft?.categoryCode)
              ? draft!.categoryCode
              : 'e';
      _rating = _resolveRatingValue(
        draft?.rating,
        preferred: (_categoryCode == 'a' ||
                _categoryCode == 'b' ||
                _categoryCode == 'c' ||
                _categoryCode == 'd' ||
                _categoryCode == 'e')
            ? 'Non noté'
            : 'BBB',
      );
      if ((_categoryCode == 'a' ||
              _categoryCode == 'c' ||
              _categoryCode == 'd') &&
          !prudentialRatings.contains(_rating)) {
        _rating = 'Non noté';
      }
      if (_categoryCode == 'e' && !enterpriseRatingOptions.contains(_rating)) {
        _rating = 'Non noté';
      }
      _bankInstitutionCase =
          coerceBankInstitutionCase(draft?.bankInstitutionCase);
      _sovereignSpecialCase = coerceSovereignSpecialCase(
        draft?.sovereignSpecialCase,
        fallbackToLegacy: draft?.sovereignPreferentialZeroWeight ?? false,
      );
      _sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
        _sovereignSpecialCase,
        sovereignPreferentialZeroWeight:
            draft?.sovereignPreferentialZeroWeight ?? false,
      );
      _sovereignPriorityQuestionAnsweredYes =
          _sovereignSpecialCase != sovereignNoSpecialCase ||
              _sovereignPreferentialZeroWeight;
      _sovereignOceEstablished = draft?.sovereignOceEstablished ?? false;
      _sovereignOceNote = sovereignOceNotes.contains(draft?.sovereignOceNote)
          ? draft!.sovereignOceNote
          : sovereignOceNotes.first;
      _publicBodyUemoaFcfaCase = draft?.publicBodyUemoaFcfaCase;
      _publicBodyFinancesNonPublicActivity =
          draft?.publicBodyFinancesNonPublicActivity;
      _bmdHighQualityCase = draft?.bmdHighQualityCase;
      _bmdUemoaFcfaCase = draft?.bmdUemoaFcfaCase;
      _bmdUemoaCriteriaSatisfied = draft?.bmdUemoaCriteriaSatisfied;
      _bmdListedInstitutionFcfaCase = draft?.bmdListedInstitutionFcfaCase;
      _bankInstitutionCase =
          coerceBankInstitutionCase(draft?.bankInstitutionCase);
      _otherAssetType = coerceOtherAssetType(
        draft?.otherAssetType,
        fallbackToUndefined: _categoryCode == 'k' && draft != null,
      );
      _offBalanceRiskLevel = coerceOffBalanceRiskLevel(
        draft?.offBalanceRiskLevel,
        fallbackToVeryHigh: _categoryCode == 'l' && draft != null,
      );
      _retailEligibilityCriteriaSatisfied =
          draft?.retailEligibilityCriteriaSatisfied;
      _residentialMortgageEligible = draft?.residentialMortgageEligible;
      _commercialRealEstateEligible = draft?.commercialRealEstateEligible;
      _defaultedExposureInitialRiskWeight =
          draft?.defaultedExposureInitialRiskWeight;
      _defaultedExposureResidentialMortgageInDefault =
          draft?.defaultedExposureResidentialMortgageInDefault;
      _defaultedExposureProvisionAtLeastTwentyPercent =
          draft?.defaultedExposureProvisionAtLeastTwentyPercent;
      _enterpriseExceedsBceaoDegradationThreshold =
          draft?.enterpriseExceedsBceaoDegradationThreshold;
      _enterprisePrudentialProcedure = draft?.enterprisePrudentialProcedure;
      _enterpriseInvestmentFirmWithoutBankingLaw =
          draft?.enterpriseInvestmentFirmWithoutBankingLaw;
      if (_categoryCode != 'b') {
        _publicBodyUemoaFcfaCase = null;
        _publicBodyFinancesNonPublicActivity = null;
      }
      if (_categoryCode != 'c') {
        _bmdHighQualityCase = null;
        _bmdUemoaFcfaCase = null;
        _bmdUemoaCriteriaSatisfied = null;
        _bmdListedInstitutionFcfaCase = null;
      }
      if (_categoryCode != 'd') {
        _bankInstitutionCase = null;
      }
      if (_categoryCode != 'k') {
        _otherAssetType = null;
      }
      if (_categoryCode != 'l') {
        _offBalanceRiskLevel = null;
      }
      if (_categoryCode != 'f') {
        _retailEligibilityCriteriaSatisfied = null;
      }
      if (_categoryCode != 'g') {
        _residentialMortgageEligible = null;
      }
      if (_categoryCode != 'h') {
        _commercialRealEstateEligible = null;
      }
      if (_categoryCode != 'i') {
        _defaultedExposureInitialRiskWeight = null;
        _defaultedExposureResidentialMortgageInDefault = null;
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
      if (!_isEnterpriseLikeCategory) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
      _currency = draft?.currency ?? 'XOF';
      _status = draft?.status ?? 'Active';
      _crmMode = draft?.crmMode ?? 'Aucune';
      _lastSelectedCrmMode = _crmMode == 'Aucune' ? 'CRM financee' : _crmMode;
      _crmType = _nonFinancedCrmTypes.contains(draft?.crmType)
          ? draft!.crmType
          : 'Garantie etatique';
      _issuerType = financedCrmIssuerTypes.contains(draft?.issuerType)
          ? draft!.issuerType
          : financedCrmIssuerTypes.first;
      _issuerRating = draft?.issuerRating != null
          ? coerceFinancedCrmCollateralRating(draft!.issuerRating)
          : financedCrmCollateralRatings.first;
      _maturityBucket =
          financedCrmMaturityBuckets.contains(draft?.maturityBucket)
              ? draft!.maturityBucket
              : financedCrmMaturityBuckets.first;
      _guarantorCategoryCode =
          guarantorEligibleCategoryCodes.contains(draft?.guarantorCategoryCode)
              ? draft!.guarantorCategoryCode
              : guarantorEligibleCategoryCodes.first;
      _guarantorRating = _resolveRatingValue(
        _coerceGuarantorRating(draft?.guarantorRating),
        preferred: 'AAA',
      );
      _coverage = draft?.crmCoveragePercent ?? 0.0;
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _primaryFormKey.currentState?.validate() ?? true;
      case 2:
        final isValid = _categoryFormKey.currentState?.validate() ?? true;
        if (!isValid) {
          return false;
        }
        if (_usesBankInstitutionMatrix && !_hasBankInitialMaturityDates) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'Renseigner les dates d octroi et d echeance pour determiner la matrice bancaire.',
                ),
              ),
            ),
          );
          return false;
        }
        if (_isResidentialMortgageCategory &&
            _residentialMortgageEligible == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'Cette exposition doit être reclassée dans une autre catégorie prudentielle.',
                ),
              ),
            ),
          );
          return false;
        }
        return true;
      case 3:
        return _financialFormKey.currentState?.validate() ?? true;
      case 4:
        return _crmSelectionStage
            ? true
            : (_crmFormKey.currentState?.validate() ?? true);
      case 5:
        return _commentFormKey.currentState?.validate() ?? true;
      default:
        return true;
    }
  }

  _ExposurePreview _buildPreview() {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final collateral =
        double.tryParse(_collateralController.text.replaceAll(',', '.')) ?? 0.0;
    final fxHaircut = _parsePercent(_fxHaircutController.text) ?? 0.0;
    final metrics = computeDraftMetrics(
      _draftFromValues(
        grossAmount: amount,
        collateralValue: collateral,
        fxHaircut: fxHaircut,
        comment: _commentController.text,
      ),
    );
    return _ExposurePreview(
      originalRw: metrics.originalRw,
      ead: metrics.ead,
      finalRw: metrics.finalRw,
      rwa: metrics.rwa,
    );
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final grossAmount = _parseDecimal(_amountController.text);
    final collateralValue = _crmMode == 'CRM financee'
        ? _parseDecimal(_collateralController.text)
        : 0.0;
    final fxHaircut = _crmMode == 'CRM financee'
        ? _parsePercent(_fxHaircutController.text)
        : 0.0;
    if (grossAmount == null || collateralValue == null || fxHaircut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Verifier les montants saisis.'))),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final draft = _draftFromValues(
        grossAmount: grossAmount,
        collateralValue: collateralValue,
        fxHaircut: fxHaircut,
        comment: _commentController.text.trim(),
      );
      await widget.onSubmit(draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Echec de l enregistrement: {{error}}',
              args: {'error': error},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty)
        ? context.tr('Champ requis')
        : null;
  }

  String? _amountValidator(String? value) {
    final parsed = _parseDecimal(value);
    return parsed == null ? context.tr('Montant invalide') : null;
  }

  String? _percentValidator(String? value) {
    final parsed = _parsePercent(value);
    return parsed == null ? context.tr('Pourcentage invalide') : null;
  }

  String _formatDateForField(DateTime? value) {
    if (value == null) {
      return '';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  int _positiveMonthDifference(DateTime start, DateTime end) {
    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }

  String _formatMonthCount(int? months) {
    return '${months ?? 0} mois';
  }

  void _syncDateController(
    TextEditingController controller,
    DateTime? value,
  ) {
    controller.text = _formatDateForField(value);
  }

  Future<void> _pickDate({
    required DateTime? currentValue,
    required ValueChanged<DateTime?> onChanged,
    DateTime? firstDate,
  }) async {
    final minimumDate = firstDate ?? DateTime(2000);
    final today = DateTime.now();
    final initialDate = currentValue == null
        ? (today.isBefore(minimumDate) ? minimumDate : today)
        : (currentValue.isBefore(minimumDate) ? minimumDate : currentValue);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minimumDate,
      lastDate: DateTime(2100),
      helpText: context.tr('Selectionner une date'),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  double? _parseDecimal(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  double? _parsePercent(String? raw) {
    final parsed = _parseDecimal(raw);
    if (parsed == null) {
      return null;
    }
    return parsed > 1 ? parsed / 100.0 : parsed;
  }

  ExposureDraft _draftFromValues({
    required double grossAmount,
    required double collateralValue,
    required double fxHaircut,
    required String comment,
  }) {
    final trimmedId = _exposureIdController.text.trim();
    final resolvedSovereignSpecialCase = coerceSovereignSpecialCase(
      _sovereignSpecialCase,
      fallbackToLegacy: _sovereignPreferentialZeroWeight,
    );
    final sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
      resolvedSovereignSpecialCase,
      sovereignPreferentialZeroWeight: _sovereignPreferentialZeroWeight,
    );
    return ExposureDraft(
      id: trimmedId.isEmpty ? widget.initialDraft?.id : trimmedId,
      counterpartyName: _nameController.text.trim(),
      country: _countryController.text.trim(),
      countryRating: _countryRating,
      categoryCode: _categoryCode,
      rating: _rating,
      grossAmount: grossAmount,
      currency: _currency,
      status: _status,
      crmMode: _crmMode,
      crmType: _crmMode == 'CRM non financee' ? _crmType : 'Cash collateral',
      collateralValue: _crmMode == 'CRM financee' ? collateralValue : 0.0,
      issuerType: _crmMode == 'CRM financee' ? _issuerType : '',
      issuerRating: _crmMode == 'CRM financee' ? _issuerRating : '',
      maturityBucket: _crmMode == 'CRM financee'
          ? _maturityBucket
          : financedCrmMaturityBuckets.first,
      fxHaircut: _crmMode == 'CRM financee' ? fxHaircut : 0.0,
      guarantorName: _crmMode == 'CRM non financee'
          ? _guarantorNameController.text.trim()
          : '',
      guarantorCategoryCode:
          _crmMode == 'CRM non financee' ? _guarantorCategoryCode : 'a',
      guarantorRating: _crmMode == 'CRM non financee' ? _guarantorRating : '',
      crmCoveragePercent: _crmMode == 'CRM non financee' ? _coverage : 0.0,
      comment: comment,
      analysisDate: widget.initialDraft?.analysisDate ?? DateTime.now(),
      grantDate: _grantDate,
      maturityDate: _maturityDate,
      sovereignSpecialCase: resolvedSovereignSpecialCase,
      sovereignPreferentialZeroWeight: sovereignPreferentialZeroWeight,
      sovereignOceEstablished: _sovereignOceEstablished,
      sovereignOceNote: _sovereignOceNote,
      publicBodyUemoaFcfaCase: _publicBodyUemoaFcfaCase,
      publicBodyFinancesNonPublicActivity: _publicBodyFinancesNonPublicActivity,
      bmdHighQualityCase: _bmdHighQualityCase,
      bmdUemoaFcfaCase: _bmdUemoaFcfaCase,
      bmdUemoaCriteriaSatisfied: _bmdUemoaCriteriaSatisfied,
      bmdListedInstitutionFcfaCase: _bmdListedInstitutionFcfaCase,
      bankInstitutionCase: _bankInstitutionCase,
      otherAssetType: _otherAssetType,
      offBalanceRiskLevel: _offBalanceRiskLevel,
      retailEligibilityCriteriaSatisfied: _retailEligibilityCriteriaSatisfied,
      residentialMortgageEligible: _residentialMortgageEligible,
      commercialRealEstateEligible: _commercialRealEstateEligible,
      defaultedExposureInitialRiskWeight: _defaultedExposureInitialRiskWeight,
      defaultedExposureResidentialMortgageInDefault:
          _defaultedExposureResidentialMortgageInDefault,
      defaultedExposureProvisionAtLeastTwentyPercent:
          _defaultedExposureProvisionAtLeastTwentyPercent,
      enterpriseExceedsBceaoDegradationThreshold:
          _enterpriseExceedsBceaoDegradationThreshold,
      enterprisePrudentialProcedure: _enterprisePrudentialProcedure,
      enterpriseInvestmentFirmWithoutBankingLaw:
          _enterpriseInvestmentFirmWithoutBankingLaw,
    );
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(0)} %';
  }
}

class _WizardStepMeta {
  const _WizardStepMeta({
    required this.shortLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String shortLabel;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
}

class _ChoiceCardData {
  const _ChoiceCardData({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;
}

class _IntroActionButton extends StatelessWidget {
  const _IntroActionButton({
    required this.icon,
    required this.accent,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = filled ? accent : accent.withOpacity(0.08);
    final foreground = filled ? Colors.white : accent;
    final borderColor = filled ? accent : accent.withOpacity(0.22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(_exposureFormRadius),
            border: Border.all(color: borderColor),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 13,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _CompactFieldCard extends StatelessWidget {
  const _CompactFieldCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.inlineTooltip,
    this.placeInlineTooltipBeforeTitle = false,
    this.hideLeadingIcon = false,
    this.iconTooltip,
    this.tooltipTitle = 'Critères',
    this.subtitleColor,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? inlineTooltip;
  final bool placeInlineTooltipBeforeTitle;
  final bool hideLeadingIcon;
  final String? iconTooltip;
  final String tooltipTitle;
  final Color? subtitleColor;
  final Widget child;

  InlineSpan _buildTooltipContent(String title, String message) {
    final lines = message.split('\n').map((line) => line.trim()).toList();

    if (lines.isEmpty) {
      return const TextSpan(text: '');
    }

    final spans = <InlineSpan>[
      TextSpan(
        text: '$title\n',
        style: const TextStyle(
          fontSize: 12.4,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    ];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      final isNote = line.startsWith('[[NOTE]]');
      if (isNote) {
        final noteText = line.replaceFirst('[[NOTE]]', '').trimLeft();
        spans.add(
          TextSpan(
            text: '$noteText${index == lines.length - 1 ? '' : '\n'}',
            style: const TextStyle(
              fontSize: 10.2,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: Color(0xFFFFB86B),
              height: 1.35,
            ),
          ),
        );
        continue;
      }

      final separatorIndex = line.indexOf(':');
      final hasLabelValueFormat =
          separatorIndex > 0 && separatorIndex < line.length - 1;

      if (hasLabelValueFormat) {
        final label = line.substring(0, separatorIndex).trim();
        final detail = line.substring(separatorIndex + 1).trim();
        spans.add(
          TextSpan(
            children: [
              const TextSpan(
                text: '• ',
                style: TextStyle(
                  fontSize: 11.4,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8FB4FF),
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 11.3,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: ' : $detail${index == lines.length - 1 ? '' : '\n'}',
                style: const TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE8EEF9),
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
        continue;
      }

      final text = line.startsWith('(') ? '• $line' : '• $line';
      spans.add(
        TextSpan(
          text: '$text${index == lines.length - 1 ? '' : '\n'}',
          style: const TextStyle(
            fontSize: 11.2,
            fontWeight: FontWeight.w500,
            color: Color(0xFFE8EEF9),
            height: 1.48,
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildModernTooltip({
    required BuildContext context,
    required String title,
    required String message,
    required Widget child,
  }) {
    return Tooltip(
      richMessage: _buildTooltipContent(title, message),
      constraints: const BoxConstraints(maxWidth: 350),
      waitDuration: const Duration(milliseconds: 140),
      showDuration: const Duration(seconds: 12),
      preferBelow: false,
      verticalOffset: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D4B7A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    final iconBadge = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2B47) : const Color(0xFFF4F7FE),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
      ),
      child: Icon(icon, size: 14, color: AppTheme.accent),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _wizardCardColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(color: _wizardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!hideLeadingIcon) ...[
                if (iconTooltip != null && iconTooltip!.trim().isNotEmpty)
                  _buildModernTooltip(
                    context: context,
                    title: tooltipTitle,
                    message: iconTooltip!,
                    child: iconBadge,
                  )
                else
                  iconBadge,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (placeInlineTooltipBeforeTitle &&
                            inlineTooltip != null &&
                            inlineTooltip!.trim().isNotEmpty) ...[
                          _buildModernTooltip(
                            context: context,
                            title: tooltipTitle,
                            message: inlineTooltip!,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 1.5),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _wizardBodyTitleColor(context),
                                  fontSize: 10.8,
                                ),
                          ),
                        ),
                        if (inlineTooltip != null &&
                            inlineTooltip!.trim().isNotEmpty &&
                            !placeInlineTooltipBeforeTitle) ...[
                          const SizedBox(width: 6),
                          _buildModernTooltip(
                            context: context,
                            title: tooltipTitle,
                            message: inlineTooltip!,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 1.5),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: subtitleColor ??
                                  _wizardSubtleMutedColor(context),
                              fontSize: 9.1,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _PrimaryInformationStepScreen extends StatelessWidget {
  const _PrimaryInformationStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.fields,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.badge_outlined,
      accent: AppTheme.accent,
      child: Form(
        key: formKey,
        child: _StepGrid(children: fields),
      ),
    );
  }
}

class _CategoryStepScreen extends StatelessWidget {
  const _CategoryStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.content,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.account_tree_outlined,
      accent: const Color(0xFF2563EB),
      child: Form(
        key: formKey,
        child: content,
      ),
    );
  }
}

class _FinancialDataStepScreen extends StatelessWidget {
  const _FinancialDataStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.fields,
    required this.helper,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final Widget helper;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.account_balance_wallet_outlined,
      accent: const Color(0xFF0F766E),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepGrid(children: fields),
            const SizedBox(height: 16),
            helper,
          ],
        ),
      ),
    );
  }
}

class _CrmChoiceStepScreen extends StatelessWidget {
  const _CrmChoiceStepScreen({
    required this.title,
    required this.subtitle,
    required this.selectedMode,
    required this.choices,
    required this.onModeChanged,
  });

  final String title;
  final String subtitle;
  final String selectedMode;
  final List<_ChoiceCardData> choices;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.handshake_outlined,
      accent: const Color(0xFF0F766E),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 260),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final item in choices)
                _ModeChoiceCard(
                  label: item.label,
                  icon: item.icon,
                  accent: item.accent,
                  selected: selectedMode == item.value,
                  onTap: () => onModeChanged(item.value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrmDetailsStepScreen extends StatelessWidget {
  const _CrmDetailsStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      child: Form(
        key: formKey,
        child: child,
      ),
    );
  }
}

class _CommentStepScreen extends StatelessWidget {
  const _CommentStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.commentField,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final Widget commentField;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.edit_note_outlined,
      accent: const Color(0xFFF59E0B),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            commentField,
          ],
        ),
      ),
    );
  }
}

class _FinalDecisionStepScreen extends StatelessWidget {
  const _FinalDecisionStepScreen({
    required this.title,
    required this.subtitle,
    required this.submitting,
    required this.onConfirm,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final bool submitting;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.task_alt_outlined,
      accent: const Color(0xFF16A34A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 260),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              OutlinedButton.icon(
                onPressed: submitting ? null : () => onBack(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(144, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  backgroundColor: _wizardCardColor(context),
                  foregroundColor: _wizardMutedColor(context),
                  side: BorderSide(color: _wizardBorderColor(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_exposureFormRadius),
                  ),
                ),
                icon: const Icon(Icons.west_rounded, size: 18),
                label: Text(
                  context.tr('Precedent'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: submitting ? null : () => onConfirm(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(196, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_exposureFormRadius),
                  ),
                ),
                icon: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.task_alt_rounded, size: 18),
                label: Text(
                  context.tr('Ajouter l exposition'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepSurface extends StatelessWidget {
  const _StepSurface({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _wizardCardColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(color: _wizardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(_exposureFormRadius),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _wizardBodyTitleColor(context),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _wizardSubtleMutedColor(context),
                            fontSize: 10.3,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StepGrid extends StatelessWidget {
  const _StepGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 10.0;
        final columns = constraints.maxWidth >= 440 ? 2 : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: child is _StepGridFullWidth
                    ? constraints.maxWidth
                    : itemWidth,
                child: child is _StepGridFullWidth ? child.child : child,
              ),
          ],
        );
      },
    );
  }
}

class _StepGridFullWidth extends StatelessWidget {
  const _StepGridFullWidth({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _HeroKpiCard extends StatelessWidget {
  const _HeroKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(color: _wizardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x0A8BA3BF),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(_exposureFormRadius),
            ),
            child: Icon(icon, size: 12, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _wizardMutedColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 9.6,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: _wizardBodyTitleColor(context),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepOverviewChip extends StatelessWidget {
  const _StepOverviewChip({
    required this.number,
    required this.isActive,
    required this.isCompleted,
  });

  final int number;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    final accent = isActive
        ? AppTheme.accent
        : isCompleted
            ? const Color(0xFF0F766E)
            : const Color(0xFF94A3B8);
    final background = isActive
        ? (isDark ? const Color(0xFF152A4D) : const Color(0xFFEEF4FF))
        : isCompleted
            ? (isDark ? const Color(0xFF102B27) : const Color(0xFFEEF8F4))
            : (isDark ? const Color(0xFF13233C) : const Color(0xFFF8FAFC));

    return Container(
      width: 36,
      height: 30,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(
          color: isActive
              ? (isDark ? const Color(0xFF335596) : const Color(0xFFCFE0FF))
              : isCompleted
                  ? (isDark ? const Color(0xFF1F5448) : const Color(0xFFCFEBDD))
                  : (isDark
                      ? const Color(0xFF2B3B56)
                      : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 8.6,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  const _ModeChoiceCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_exposureFormRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 206,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(isDark ? 0.16 : 0.10)
              : (isDark ? const Color(0xFF13233C) : const Color(0xFFFBFCFE)),
          borderRadius: BorderRadius.circular(_exposureFormRadius),
          border: Border.all(
            color: selected
                ? accent.withOpacity(0.70)
                : (isDark ? const Color(0xFF2B3B56) : const Color(0xFFDDE6F2)),
            width: selected ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accent.withOpacity(isDark ? 0.12 : 0.08)
                  : (isDark
                      ? const Color(0x22000000)
                      : const Color(0x0A8AA3C2)),
              blurRadius: selected ? 14 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withOpacity(0.12)
                    : (isDark
                        ? const Color(0xFF1A2A45)
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(_exposureFormRadius),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? accent : _wizardMutedColor(context),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? accent : _wizardBodyTitleColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.8,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.accent,
    required this.text,
  });

  final IconData icon;
  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(color: accent.withOpacity(isDark ? 0.26 : 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _wizardBodyTitleColor(context),
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExposurePreview {
  const _ExposurePreview({
    required this.originalRw,
    required this.ead,
    required this.finalRw,
    required this.rwa,
  });

  final double originalRw;
  final double ead;
  final double finalRw;
  final double rwa;
}
