// Ecran principal du module Risque OpÃ©rationnel â€” 10 vues.
import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../models/ro_models.dart';
import '../widgets/ro_import_pertes_dialog.dart';

// â”€â”€â”€ Enum vues â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum OperationalRiskView {
  dashboard,
  registre,
  incidents,
  pertes,
  kri,
  cartographie,
  controles,
  workflow,
  plans,
  historique,
  reporting,
}

// â”€â”€â”€ Constantes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _kBlue = AppTheme.accent;
const _kSuccess = AppTheme.success;
const _kWarning = AppTheme.warning;
const _kDanger = AppTheme.danger;
const _kMuted = AppTheme.muted;

const _lignesMetier = [
  "Financement d'entreprise",
  'ActivitÃ©s de marchÃ©',
  'Banque de dÃ©tail',
  'Banque commerciale',
  'Paiements et rÃ¨glements',
  "Fonctions d'agent",
  "Gestion d'actifs",
  'Courtage de dÃ©tail',
];
const _typesEvenement = ['Interne', 'Externe', 'Processus', 'SystÃ¨me', 'Personnel', 'Juridique'];
const _statutsIncident = ['Ouvert', 'En cours', 'RÃ©solu', 'ClÃ´turÃ©'];
const _causesRacine = [
  'Erreur humaine',
  'DÃ©faillance systÃ¨me',
  'Processus inadÃ©quat',
  'Fraude interne',
  'Fraude externe',
  'Ã‰vÃ©nement externe',
  'Non dÃ©finie',
];
const _categoriesRisque = ['Processus', 'Personnel', 'SystÃ¨me', 'Externe', 'Juridique'];
const _typesControle = ['Permanent', 'PÃ©riodique', 'Ponctuel', 'Sur piÃ¨ces', 'Sur place'];
const _frequences = ['Mensuel', 'Trimestriel', 'Semestriel', 'Annuel'];
const _typesAction = ['Corrective', 'PrÃ©ventive', 'AmÃ©liorative'];
const _sourcesAction = ['Incident', 'ContrÃ´le', 'KRI', 'Audit', 'Cartographie'];
const _priorites = ['Haute', 'Moyenne', 'Basse'];
const _statutsPlan = ['A faire', 'En cours', 'TerminÃ©', 'AbandonnÃ©'];

// â”€â”€â”€ Articles rÃ©glementaires â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _artExplanations = <String, String>{
  'Art. 313':
      'Gestion du risque opÃ©rationnel â€” dispositif d\'identification, de mesure,\n'
      'de surveillance et de contrÃ´le obligatoire (Instruction UMOA).\n\n'
      'Mesure du risque (matrice 5Ã—5) :\n'
      '  Score = Impact Ã— ProbabilitÃ©   (Ã©chelle 1 â€“ 5)\n'
      '  Zone rouge : Score â‰¥ 15   |   Zone orange : 8 â€“ 14\n'
      '  Piliers : Identification â†’ Mesure â†’ Surveillance â†’ ContrÃ´le',
  'Art. 313.b':
      'DÃ©claration des incidents opÃ©rationnels â€” tout incident significatif\n'
      'doit Ãªtre documentÃ© (cause racine, pertes) avec suivi formel imposÃ©.\n\n'
      'Calcul de la perte nette :\n'
      '  Perte nette = Perte brute âˆ’ RÃ©cupÃ©rations\n'
      '  RÃ©cupÃ©rations : assurance + provisions + reversements\n'
      '  DÃ©lai de dÃ©claration : â‰¤ J+5 ouvrÃ©s aprÃ¨s dÃ©tection',
  'Art. 313.c':
      'Plans d\'actions correctives et prÃ©ventives â€” documentÃ©s, assignÃ©s\n'
      'Ã  un responsable avec Ã©chÃ©ance et taux d\'avancement obligatoires.\n\n'
      'Indicateurs de suivi :\n'
      '  Avancement (%) = (Actions terminÃ©es / Actions totales) Ã— 100\n'
      '  Taux global = Î£ avancement_i / n   (n = nb plans actifs)\n'
      '  Retard = Date_Ã©chÃ©ance âˆ’ Date_aujourd\'hui  < 0 â†’ en retard',
  'Art. 314':
      'ContrÃ´le interne â€” dispositif permanent et pÃ©riodique obligatoire.\n'
      'Conservation des documents : â‰¥ 7 ans (exigence UMOA).\n\n'
      'EfficacitÃ© du contrÃ´le :\n'
      '  Taux de conformitÃ© = (ContrÃ´les conformes / ContrÃ´les rÃ©alisÃ©s) Ã— 100\n'
      '  Couverture = Nb processus contrÃ´lÃ©s / Nb processus totaux Ã— 100\n'
      '  FrÃ©quences : permanent (quotidien/hebdo) | pÃ©riodique (mensuel/annuel)',
  'Art. 89':
      'Calcul des RWA opÃ©rationnels â€” mÃ©thode Indicateur de Base (BIA).\n\n'
      'Formule BIA :\n'
      '  Capital minimal = Î± Ã— PNBmoyâ‚ƒ\n'
      '  Î± = 15 %   (coefficient rÃ©glementaire BCEAO)\n'
      '  PNBmoyâ‚ƒ = Î£ PNBáµ¢ (positifs) / n   sur 3 derniers exercices\n'
      '  RWA_opÃ©rationnel = Capital minimal Ã· 8 %   (facteur 12,5)',
  'Art. 301/307':
      'Exigences minimales en fonds propres (dispositif prudentiel BCEAO).\n\n'
      'Ratios rÃ©glementaires :\n'
      '  Ratio Tier 1 = Fonds propres de base / RWA total  â‰¥ 5 %\n'
      '  Ratio global = Fonds propres totaux / RWA total   â‰¥ 8 %\n'
      '  RWA total = RWA_crÃ©dit + RWA_marchÃ© + RWA_opÃ©rationnel\n'
      '  Coussin de conservation : + 2,5 % des RWA (si applicable)',
  'Art. 545':
      'Stress testing â€” simulations de scÃ©narios de crise pour Ã©valuer\n'
      'la rÃ©silience du dispositif de gestion des risques.\n\n'
      'ScÃ©narios types et formule d\'impact :\n'
      '  S1 : Optimiste  |  S2 : Neutre  |  S3 : Pessimiste  |  S4 : Crise\n'
      '  Impact net = Pertes simulÃ©es âˆ’ (Provisions + Couverture assurance)\n'
      '  RÃ©silience = Fonds propres disponibles âˆ’ Pertes simulÃ©es  â‰¥ 0\n'
      '  Ratio de rÃ©sistance = FP aprÃ¨s choc / RWA stressÃ©s  â‰¥ seuil',
  'Art. 546':
      'Rapport annuel sur le dispositif de gestion des risques opÃ©rationnels,\n'
      'transmis Ã  la Commission Bancaire de l\'UMOA.\n\n'
      'Indicateurs clÃ©s Ã  reporter :\n'
      '  â€¢ RWA opÃ©rationnel = K_BIA Ã— 12,5   (avec K_BIA = 15 % Ã— PNBmoyâ‚ƒ)\n'
      '  â€¢ Pertes totales nettes = Î£ (Perte brute âˆ’ RÃ©cupÃ©rations)\n'
      '  â€¢ Taux couverture plans = Actions terminÃ©es / Total plans Ã— 100\n'
      '  â€¢ RÃ©sultats stress tests : Î”FP sous S3 et S4',
};

List<String> _extractArtRefs(String text) =>
    RegExp(r'Art\.\s*\d+[\w\./]*').allMatches(text).map((m) => m.group(0)!).toList();

String _stripArtRefs(String text) =>
    text.replaceAll(RegExp(r'\s*\(Art\..*?\)'), '').trim();

Widget _artInfo(String artRef) {
  final explanation = _artExplanations[artRef];
  if (explanation == null) return const SizedBox.shrink();
  return ExcludeSemantics(
    child: Tooltip(
      message: '$artRef\n$explanation',
      preferBelow: false,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 8),
      textStyle: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Icon(Icons.info_outline_rounded, size: 14, color: _kBlue),
    ),
  );
}

// â”€â”€â”€ Ecran principal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class RisqueOperationnelScreen extends StatelessWidget {
  const RisqueOperationnelScreen({
    super.key,
    required this.api,
    this.view = OperationalRiskView.dashboard,
  });

  final RwaApiService api;
  final OperationalRiskView view;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, artRef) = switch (view) {
      OperationalRiskView.dashboard   => ('Dashboard OpÃ©rationnel',    'KPI rÃ©glementaires et alertes (Art. 313)',                      'Art. 313'),
      OperationalRiskView.registre    => ('Registre des pertes RO',     'Registre BCEAO/UMOA â€” pertes, Capital minimal et RWA (Art. 89 & 313.b)',  'Art. 89'),
      OperationalRiskView.incidents   => ('Simulation de crise',        'Stress testing PIEAFP â€” scÃ©narios de vulnÃ©rabilitÃ© (Art. 545)', 'Art. 545'),
      OperationalRiskView.pertes      => ('Pertes opÃ©rationnelles',     'Base de pertes historiques â€” calcul RWA BIA (Art. 89)',         'Art. 89'),
      OperationalRiskView.kri         => ('KRI',                        'Indicateurs clÃ©s de risque â€” surveillance continue (Art. 313)', 'Art. 313'),
      OperationalRiskView.cartographie=> ('Cartographie des risques',   'Identification et Ã©valuation â€” matrice 5Ã—5 (Art. 313)',         'Art. 313'),
      OperationalRiskView.controles   => ('ContrÃ´les internes',         'Gestion des contrÃ´les pÃ©riodiques (Art. 314)',                  'Art. 314'),
      OperationalRiskView.workflow    => ('Workflow incidents',          'Pipeline de traitement des incidents (Art. 313.b)',             'Art. 313.b'),
      OperationalRiskView.plans       => ('Plans d\'actions',           'Actions correctives et prÃ©ventives (Art. 313.c)',               'Art. 313.c'),
      OperationalRiskView.historique  => ('Historique Ã©vÃ©nements',      'Journal de traÃ§abilitÃ© (Art. 314) â€” 7 ans UMOA',               'Art. 314'),
      OperationalRiskView.reporting   => ('Reporting opÃ©rationnel',     'GÃ©nÃ©ration des rapports rÃ©glementaires (Art. 313.c)',           'Art. 313.c'),
    };
    final content = switch (view) {
      OperationalRiskView.dashboard => _DashboardView(api: api),
      OperationalRiskView.registre  => _RegistreView(api: api),
      OperationalRiskView.incidents => _SimulationCriseView(api: api),
      OperationalRiskView.pertes => _PertesView(api: api),
      OperationalRiskView.kri => _KriView(api: api),
      OperationalRiskView.cartographie => _CartographieView(api: api),
      OperationalRiskView.controles => _ControlesView(api: api),
      OperationalRiskView.workflow => _WorkflowView(api: api),
      OperationalRiskView.plans => _PlansView(api: api),
      OperationalRiskView.historique => _HistoriqueView(api: api),
      OperationalRiskView.reporting => _ReportingView(api: api),
    };
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: title,
              subtitle: subtitle,
              subtitleSuffix: _artInfo(artRef),
            ),
            const SizedBox(height: 16),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Helpers partagÃ©s â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Color _statutColor(String statut) => switch (statut) {
      'Ouvert' => _kDanger,
      'En cours' => _kWarning,
      'RÃ©solu' => AppColors.marketNeutral,
      'ClÃ´turÃ©' => _kSuccess,
      _ => _kMuted,
    };

Color _niveauColor(String label) => switch (label) {
      'Faible' => _kSuccess,
      'Moyen' => _kWarning,
      'Ã‰levÃ©' => const Color(0xFFF97316),
      'Critique' => _kDanger,
      _ => _kMuted,
    };

Color _kriStatutColor(String s) => switch (s) {
      'normal' => _kSuccess,
      'alerte' => _kWarning,
      'critique' => _kDanger,
      _ => _kMuted,
    };

String _kriStatutLabel(String s) => switch (s) {
      'normal' => 'Normal',
      'alerte' => 'Alerte',
      'critique' => 'Critique',
      _ => 'N/A',
    };

Widget _badge(String label, Color color) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
          ],
        ),
      ),
    );

Widget _kpiBox(BuildContext context, String label, String value, IconData icon, Color color, {String? tooltip}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  // Border uniforme obligatoire pour combiner borderRadius + couleurs distinctes
  // => strip gauche colorÃ© en interne via un Container(width:4)
  return Container(
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
      boxShadow: isDark ? null : [
        BoxShadow(color: color.withValues(alpha: 0.09), blurRadius: 14, offset: const Offset(0, 3)),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: isDark ? 0.25 : 0.16),
                          color.withValues(alpha: isDark ? 0.10 : 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(label,
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkMuted : _kMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            if (tooltip != null) ...[
                              const SizedBox(width: 4),
                              ExcludeSemantics(
                                child: Tooltip(
                                  message: tooltip,
                                  preferBelow: false,
                                  waitDuration: Duration.zero,
                                  showDuration: const Duration(seconds: 10),
                                  textStyle: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2A3A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: color.withValues(alpha: 0.6)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value,
                            maxLines: 1,
                            style: TextStyle(
                              color: isDark ? AppTheme.darkText : AppTheme.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirm(BuildContext ctx, String msg, Future<void> Function() action) async {
  final ok = await showDialog<bool>(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Confirmation'),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Confirmer')),
      ],
    ),
  );
  if (ok == true) await action();
}

Widget _loadingBox() => const Center(child: CircularProgressIndicator());

Widget _errorBox(Object e) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Erreur : $e', style: const TextStyle(color: _kDanger)),
      ),
    );

// â”€â”€â”€ Form helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// Titre de section dans un formulaire
Widget _formSection(String title, {IconData? icon, Color color = _kBlue}) => Padding(
  padding: const EdgeInsets.only(top: 8, bottom: 12),
  child: Row(
    children: [
      Container(width: 3, height: 15,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 5)],
      Text(title,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 0.3)),
    ],
  ),
);

// Deux champs cÃ´te Ã  cÃ´te
Widget _formRow(Widget left, Widget right) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)],
);

Widget _field(String label, TextEditingController ctrl,
    {bool multiline = false, TextInputType? keyboardType, String? hint, bool required = false, IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 12, color: _kBlue), const SizedBox(width: 5)],
          Text(required ? '$label *' : label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: _kMuted, letterSpacing: 0.1)),
        ]),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          maxLines: multiline ? 3 : 1,
          keyboardType: keyboardType,
          inputFormatters: (keyboardType == TextInputType.number ||
                  keyboardType == const TextInputType.numberWithOptions(decimal: true))
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))]
              : null,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
          validator: required ? (v) => (v == null || v.isEmpty) ? 'Champ requis' : null : null,
        ),
      ],
    ),
  );
}

Widget _dateField(
  BuildContext ctx,
  String label,
  TextEditingController ctrl, {
  bool required = false,
  DateTime? firstDate,
  VoidCallback? onPicked,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.calendar_month_outlined, size: 12, color: _kBlue),
          const SizedBox(width: 5),
          Text(required ? '$label *' : label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: _kMuted, letterSpacing: 0.1)),
        ]),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          readOnly: true,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'jj/mm/aaaa',
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            suffixIcon: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.calendar_month_outlined, size: 14, color: _kBlue),
            ),
          ),
          validator: required ? (v) => (v == null || v.isEmpty) ? 'Champ requis' : null : null,
          onTap: () async {
            final min = firstDate ?? DateTime(2000);
            DateTime? current;
            try {
              if (ctrl.text.isNotEmpty) current = DateTime.parse(ctrl.text);
            } catch (_) {}
            final today = DateTime.now();
            final initial = current ?? (today.isBefore(min) ? min : today);
            final picked = await showDatePicker(
              context: ctx,
              initialDate: initial.isBefore(min) ? min : initial,
              firstDate: min,
              lastDate: DateTime(2100),
              helpText: 'SÃ©lectionner une date',
            );
            if (picked != null) {
              ctrl.text = picked.toIso8601String().substring(0, 10);
              onPicked?.call();
            }
          },
        ),
      ],
    ),
  );
}

Widget _sliderInt(String label, int value, void Function(int) onChanged) {
  final color = value >= 100 ? _kSuccess : value >= 50 ? _kBlue : value > 0 ? _kWarning : _kMuted;
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.bar_chart_rounded, size: 12, color: _kBlue),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                color: _kMuted, letterSpacing: 0.1)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Text('$value %',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.15),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0, max: 100, divisions: 20,
            label: '$value %',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 %', style: TextStyle(fontSize: 10, color: _kMuted)),
            Text('25 %', style: TextStyle(fontSize: 10, color: _kMuted)),
            Text('50 %', style: TextStyle(fontSize: 10, color: _kMuted)),
            Text('75 %', style: TextStyle(fontSize: 10, color: _kMuted)),
            Text('100 %', style: TextStyle(fontSize: 10, color: _kMuted)),
          ],
        ),
      ],
    ),
  );
}

Widget _dropdown<T>(String label, T? value, List<T> items, void Function(T?) onChanged,
    {bool required = false, IconData? icon, String? hint}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 12, color: _kBlue), const SizedBox(width: 5)],
          Text(required ? '$label *' : label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: _kMuted, letterSpacing: 0.1)),
        ]),
        const SizedBox(height: 5),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e.toString(), style: const TextStyle(fontSize: 13.5),
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
          validator: required ? (v) => v == null ? 'Champ requis' : null : null,
        ),
      ],
    ),
  );
}


// â”€â”€â”€ VIEW 1 : DASHBOARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Widget _bannerStat(String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(label,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9.5,
        fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    const SizedBox(height: 2),
    Text(value,
      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
  ],
);

Widget _roStatusBanner(BuildContext context, RoDashboardData d) {
  final isConforme = d.widget1.statutReglementaire == 'Conforme';
  final alertCount = d.widget3.actionsEnRetard + d.widget3.kriHorsSeuil + d.widget3.controlesNonConformes;
  final gradStart = isConforme ? const Color(0xFF042B16) : const Color(0xFF3D0A0A);
  final gradEnd   = isConforme ? const Color(0xFF0D5C30) : const Color(0xFF7A1212);
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [gradStart, gradEnd],
      ),
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(color: (isConforme ? _kSuccess : _kDanger).withValues(alpha: 0.18),
          blurRadius: 18, offset: const Offset(0, 4)),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      children: [
        Container(
          width: 46, height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isConforme ? Icons.shield_rounded : Icons.warning_rounded,
            color: Colors.white, size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CONFORMITÃ‰ RÃ‰GLEMENTAIRE Â· BCEAO / UMOA',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
              const SizedBox(height: 2),
              Text(d.widget1.statutReglementaire,
                style: const TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _bannerStat('Capital minimal', AppFormatters.currency(d.widget1.exigenceFondsPropres)),
              Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.22)),
              _bannerStat('RWA', AppFormatters.currency(d.widget1.aprRisqueOp)),
            ]),
            if (alertCount > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kWarning.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kWarning.withValues(alpha: 0.50)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 12),
                  const SizedBox(width: 5),
                  Text('$alertCount alerte${alertCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _DashboardView extends StatefulWidget {
  const _DashboardView({required this.api});
  final RwaApiService api;
  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late Future<RoDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchRoDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoDashboardData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final d = snap.data!;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner statut rÃ©glementaire
              _roStatusBanner(context, d),
              const SizedBox(height: 14),
              // Widget 1 â€” Situation rÃ©glementaire
              SectionCard(
                title: 'Situation rÃ©glementaire',
                child: Row(
                  children: [
                    Expanded(child: _kpiBox(context, 'Exigence fonds propres (K)', AppFormatters.currency(d.widget1.exigenceFondsPropres), Icons.account_balance_outlined, _kBlue,
                      tooltip: 'Capital rÃ©glementaire minimum (Art. 89)\nFormule : Capital minimal = 15 % Ã— Perte nette totale\nÎ± = 15 % (coefficient BCEAO/UMOA)',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'APR risque opÃ©rationnel', AppFormatters.currency(d.widget1.aprRisqueOp), Icons.bar_chart_outlined, AppColors.prudentialSolvency,
                      tooltip: 'Actifs PondÃ©rÃ©s par le Risque opÃ©rationnel (Art. 89)\nFormule : APR = K_RO Ã— 12,5\n12,5 = 1 Ã· 8 % (facteur de conversion prudentiel)',
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kpiBox(context, 'Statut rÃ©glementaire', d.widget1.statutReglementaire,
                          d.widget1.statutReglementaire == 'Conforme' ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                          d.widget1.statutReglementaire == 'Conforme' ? _kSuccess : _kDanger,
                          tooltip: 'ConformitÃ© rÃ©glementaire (Art. 313)\nConforme si ratio Tier 1 â‰¥ 5 % et ratio global â‰¥ 8 %\nRWA total = RWA_crÃ©dit + RWA_marchÃ© + RWA_opÃ©rationnel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Widget 2 â€” Incidents
              SectionCard(
                title: 'SynthÃ¨se des incidents',
                trailing: _artInfo('Art. 313.b'),
                child: Row(
                  children: [
                    Expanded(child: _kpiBox(context, 'Incidents (mois)', '${d.widget2.totalIncidentsMois}', Icons.report_outlined, _kWarning,
                      tooltip: 'Nombre d\'incidents dÃ©clarÃ©s ce mois (Art. 313.b)\nFormule : COUNT(incidents) WHERE mois = mois_courant\nTout incident significatif doit Ãªtre dÃ©clarÃ© â‰¤ J+5',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'Pertes nettes (mois)', AppFormatters.currency(d.widget2.pertesNettesMois), Icons.trending_down_outlined, _kDanger,
                      tooltip: 'Pertes nettes du mois en cours (Art. 313.b)\nFormule : Î£ (perte_brute âˆ’ perte_rÃ©cupÃ©rÃ©e)\npour les incidents du mois courant',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'Non clÃ´turÃ©s', '${d.widget2.incidentsNonClos}', Icons.pending_outlined, AppColors.marketNeutral,
                      tooltip: 'Incidents encore ouverts ou en cours (Art. 313.b)\nFormule : COUNT(incidents) WHERE statut IN (Ouvert, En cours)\nCes incidents nÃ©cessitent un suivi actif',
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kpiBox(
                        context,
                        'Ã‰volution / N-1',
                        d.widget2.evolutionPertesPct != null ? '${d.widget2.evolutionPertesPct! >= 0 ? '+' : ''}${d.widget2.evolutionPertesPct!.toStringAsFixed(1)} %' : 'N/A',
                        Icons.compare_arrows_outlined,
                        d.widget2.evolutionPertesPct != null && d.widget2.evolutionPertesPct! > 0 ? _kDanger : _kSuccess,
                        tooltip: 'Ã‰volution des pertes vs mÃªme mois N-1\nFormule : ((Pertes_mois âˆ’ Pertes_mois_N1) Ã· |Pertes_mois_N1|) Ã— 100\n+ = dÃ©gradation   âˆ’ = amÃ©lioration',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Widget 3 â€” Alertes
              SectionCard(
                title: 'Alertes et actions',
                trailing: _artInfo('Art. 313.c'),
                child: Row(
                  children: [
                    Expanded(child: _kpiBox(context, 'Actions en retard', '${d.widget3.actionsEnRetard}', Icons.alarm_outlined, d.widget3.actionsEnRetard > 0 ? _kDanger : _kSuccess,
                      tooltip: 'Plans d\'actions dont la date d\'Ã©chÃ©ance est dÃ©passÃ©e et le statut â‰  Â«TerminÃ©Â».\nFormule : COUNT(plans) WHERE date_echeance < aujourd\'hui AND statut â‰  \'TerminÃ©\'.\nIndicateur de pilotage du suivi correctif. (Art. 313.c)')),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'ContrÃ´les non conformes', '${d.widget3.controlesNonConformes}', Icons.rule_outlined, d.widget3.controlesNonConformes > 0 ? _kWarning : _kSuccess,
                      tooltip: 'ContrÃ´les internes dont le rÃ©sultat est Ã©valuÃ© Â«Non-conformeÂ» lors de la derniÃ¨re exÃ©cution.\nFormule : COUNT(controles) WHERE resultat = \'Non-conforme\'.\nMesure la qualitÃ© du dispositif de contrÃ´le. (Art. 314)')),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'KRI hors seuil', '${d.widget3.kriHorsSeuil}', Icons.speed_outlined, d.widget3.kriHorsSeuil > 0 ? _kDanger : _kSuccess,
                      tooltip: 'Indicateurs ClÃ©s de Risque (KRI) dont le statut est Â«alerteÂ» ou Â«critiqueÂ».\nFormule : COUNT(kri) WHERE statut IN (\'alerte\', \'critique\').\nSignale les expositions dÃ©passant les limites tolÃ©rÃ©es. (Art. 89 / Art. 313)')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Widget 4 â€” Charts
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SectionCard(
                      title: 'Ã‰volution des pertes (12 mois)',
                      child: SizedBox(
                        height: 180,
                        child: d.evolutionPertes.isEmpty
                            ? const Center(child: Text('Aucune donnÃ©e', style: TextStyle(color: _kMuted)))
                            : CustomPaint(
                                painter: _RoLineChartPainter(
                                  dataBlue: d.evolutionPertes.map((e) => e.perteBrute).toList(),
                                  dataGreen: d.evolutionPertes.map((e) => e.perteNette).toList(),
                                  labels: d.evolutionPertes.map((e) => e.mois).toList(),
                                ),
                                size: Size.infinite,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SectionCard(
                      title: 'RÃ©partition par ligne de mÃ©tier',
                      child: d.repartitionLigneMetier.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('Aucun incident', style: TextStyle(color: _kMuted))),
                            )
                          : _RoPieChart(items: d.repartitionLigneMetier),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// â”€â”€â”€ VIEW 2 : SIMULATION DE CRISE â€” Art. 545 PIEAFP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SimulationCriseView extends StatefulWidget {
  const _SimulationCriseView({required this.api});
  final RwaApiService api;
  @override
  State<_SimulationCriseView> createState() => _SimulationCriseViewState();
}

class _SimulationCriseViewState extends State<_SimulationCriseView> {
  late Future<List<RoIncident>> _future;

  final _fpCtrl    = TextEditingController();
  final _aprCtrl   = TextEditingController();
  final _provCtrl  = TextEditingController();
  final _assurCtrl = TextEditingController();

  double _seuilValue = 8.0;

  bool _simulated = false;

  // (code, label, choc_losses_multiplier, accent_color)
  // S1 Optimiste : pertes Ã—0.90  (-10 %)
  // S2 Neutre    : pertes Ã—1.00  ( 0 %)
  // S3 Pessimiste: pertes Ã—1.20  (+20 %)
  // S4 Crise     : pertes Ã—1.35  (+35 %)
  static const _sc = [
    ('S1', 'Optimiste',    0.90, Color(0xFF43A047)),
    ('S2', 'Neutre',       1.00, Color(0xFF1E88E5)),
    ('S3', 'Pessimiste',   1.20, Color(0xFFFB8C00)),
    ('S4', 'Crise sÃ©vÃ¨re', 1.35, Color(0xFFE53935)),
  ];

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchRoIncidents();
    for (final c in [_fpCtrl, _aprCtrl, _provCtrl, _assurCtrl]) {
      c.addListener(_onFieldChanged);
    }
    // PrÃ©-remplir provisions depuis les incidents RO
    _future.then((incidents) {
      if (!mounted) return;
      final totalRecupere = incidents.fold(0.0, (s, i) => s + i.perteRecuperee);
      setState(() {
        if (totalRecupere > 0 && _provCtrl.text.isEmpty) {
          _provCtrl.text = totalRecupere.round().toString();
        }
        if (incidents.isNotEmpty) _simulated = true;
      });
    }).catchError((_) {});
    // PrÃ©-remplir fonds propres et RWA depuis le dashboard
    widget.api.fetchDashboard().then((DashboardSnapshot snap) {
      if (!mounted) return;
      final capitalMetricVal = snap.metrics
          .where((m) => m.key == 'capital').firstOrNull?.value ?? 0.0;
      final rwaMetricVal = snap.metrics
          .where((m) => m.key == 'rwa').firstOrNull?.value ?? 0.0;
      final totalCapital = snap.portfolioOverview.fold(0.0, (s, r) => s + r.capital);
      final totalRwa     = snap.portfolioOverview.fold(0.0, (s, r) => s + r.rwa);
      final capitalValue = totalCapital > 0 ? totalCapital : capitalMetricVal;
      final rwaValue     = totalRwa     > 0 ? totalRwa     : rwaMetricVal;
      final fp = capitalValue * 1.35;
      setState(() {
        if (fp > 0 && _fpCtrl.text.isEmpty)  _fpCtrl.text  = fp.round().toString();
        if (rwaValue > 0 && _aprCtrl.text.isEmpty) _aprCtrl.text = rwaValue.round().toString();
      });
    }).catchError((_) {});
  }

  void _onFieldChanged() {
    setState(() => _simulated = [_fpCtrl, _aprCtrl, _provCtrl, _assurCtrl]
        .any((c) => c.text.trim().isNotEmpty));
  }

  @override
  void dispose() {
    for (final c in [_fpCtrl, _aprCtrl, _provCtrl, _assurCtrl]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(' ', '').replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<RoIncident>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final items      = snap.data!;
        final pertesHisto = items.fold(0.0, (s, i) => s + i.perteNette);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Bandeau rÃ©glementaire â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.18)),
              ),
              child: Row(children: [
                const Icon(Icons.science_rounded, color: Color(0xFF1565C0), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Art. 545 UMOA â€” Ã‰valuation de la vulnÃ©rabilitÃ© Ã  des Ã©vÃ©nements exceptionnels mais plausibles (PIEAFP).\n'
                  'Base historique : ${items.length} incident(s) | Pertes nettes : ${AppFormatters.currency(pertesHisto)}',
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                )),
                _artInfo('Art. 545'),
              ]),
            ),
            const SizedBox(height: 14),

            // â”€â”€ ParamÃ¨tres â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ParamÃ¨tres de la simulation',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _simField('Fonds propres disponibles (FCFA)', _fpCtrl),
                        _simField('RWA de rÃ©fÃ©rence (FCFA)',           _aprCtrl),
                        _simField('Provisions constituÃ©es (FCFA)',     _provCtrl),
                        _simField('Couverture assurance (FCFA)',       _assurCtrl),
                        SizedBox(
                          width: 260,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(children: [
                                const Text('Seuil ratio rÃ©sistance',
                                  style: TextStyle(fontSize: 11, color: _kMuted)),
                                const Spacer(),
                                Text('${_seuilValue.toStringAsFixed(1)} %',
                                  style: const TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                              ]),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                ),
                                child: Slider(
                                  value: _seuilValue,
                                  min: 4.0,
                                  max: 25.0,
                                  divisions: 210,
                                  activeColor: const Color(0xFF1565C0),
                                  onChanged: (v) => setState(() { _seuilValue = v; _simulated = true; }),
                                ),
                              ),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('4 %', style: TextStyle(fontSize: 10, color: _kMuted)),
                                  Text('RÃ©gl. BCEAO : 8 %', style: TextStyle(fontSize: 10, color: _kMuted)),
                                  Text('25 %', style: TextStyle(fontSize: 10, color: _kMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // â”€â”€ RÃ©sultats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (_simulated) ...[
              const Text('RÃ©sultats â€” 4 scÃ©narios BCEAO',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _scCard(_sc[0], pertesHisto, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _scCard(_sc[1], pertesHisto, isDark)),
                      ]),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _scCard(_sc[2], pertesHisto, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _scCard(_sc[3], pertesHisto, isDark)),
                      ]),
                    ],
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_outlined, size: 52,
                        color: _kMuted.withValues(alpha: 0.35)),
                      const SizedBox(height: 12),
                      const Text('Saisissez au moins un paramÃ¨tre pour lancer la simulation',
                        style: TextStyle(color: _kMuted, fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text('Les rÃ©sultats s\'affichent automatiquement â€” tous les champs ne sont pas obligatoires',
                        style: TextStyle(color: _kMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _simField(String label, TextEditingController ctrl, {double width = 240}) =>
    SizedBox(
      width: width,
      child: TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))],
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );

  Widget _scCard(
    (String, String, double, Color) sc,
    double pertesHisto,
    bool isDark,
  ) {
    final (code, label, factor, color) = sc;
    final fp    = _d(_fpCtrl)    ?? 0;
    final apr   = _d(_aprCtrl)   ?? 0;
    final prov  = _d(_provCtrl)  ?? 0;
    final assur = _d(_assurCtrl) ?? 0;
    final seuil = _seuilValue / 100;

    // Formules BCEAO Art. 545
    final pertesSimulees = pertesHisto * factor;
    final impactNet      = pertesSimulees - prov - assur;
    final fpApresChoc    = fp - (impactNet > 0 ? impactNet : 0);
    final resilience     = fp - pertesSimulees;
    final aprStresses    = apr > 0 ? apr * factor : 0.0;
    final ratio          = aprStresses > 0 ? fpApresChoc / aprStresses : 0.0;
    final pass           = resilience >= 0 && (apr == 0 || ratio >= seuil);

    final pctLabel = factor == 1.0 ? '0%' : factor < 1.0
        ? 'âˆ’${((1 - factor) * 100).round()}% pertes'
        : '+${((factor - 1) * 100).round()}% pertes';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tÃªte scÃ©nario
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$code â€” $label  ($pctLabel)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (pass ? const Color(0xFF43A047) : _kDanger).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(pass ? 'âœ“ RÃ‰SILIENT' : 'âœ— VULNÃ‰RABLE',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: pass ? const Color(0xFF43A047) : _kDanger)),
            ),
          ]),
          const SizedBox(height: 12),
          // KPI row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _mini('Pertes simulÃ©es',
                AppFormatters.currency(pertesSimulees),
                factor > 1.0 ? _kDanger : const Color(0xFF43A047))),
              const SizedBox(width: 8),
              Expanded(child: _mini('Impact net',
                AppFormatters.currency(impactNet),
                impactNet > 0 ? _kDanger : const Color(0xFF43A047))),
              const SizedBox(width: 8),
              Expanded(child: _mini('RÃ©silience FP',
                AppFormatters.currency(resilience),
                resilience >= 0 ? const Color(0xFF43A047) : _kDanger)),
              if (apr > 0) ...[
                const SizedBox(width: 8),
                Expanded(child: _mini('Ratio rÃ©sistance',
                  '${(ratio * 100).toStringAsFixed(1)}%',
                  ratio >= seuil ? const Color(0xFF43A047) : _kDanger,
                  sub: 'seuil ${_seuilValue.toStringAsFixed(1)}%')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color, {String? sub}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _kMuted, height: 1.4)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: color, height: 1.2)),
        ),
        if (sub != null)
          Text(sub, style: TextStyle(fontSize: 9,
            color: _kMuted.withValues(alpha: 0.7), height: 1.3)),
      ],
    );
}

// â”€â”€â”€ VIEW 3 : PERTES (conteneur avec onglets) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PertesView extends StatefulWidget {
  const _PertesView({required this.api});
  final RwaApiService api;
  @override
  State<_PertesView> createState() => _PertesViewState();
}

class _PertesViewState extends State<_PertesView> with TickerProviderStateMixin {
  late final TabController _tab;

  static const _tabDefs = [
    (Icons.monetization_on_outlined,       'Pertes'),
    (Icons.speed_rounded,                  'KRI'),
    (Icons.map_outlined,                   'Cartographie'),
    (Icons.verified_user_outlined,         'ContrÃ´les internes'),
    (Icons.account_tree_outlined,          'Workflow'),
    (Icons.format_list_bulleted_rounded,   "Plans d'actions"),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabDefs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1829) : const Color(0xFFF0F4FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF1E2E48) : const Color(0xFFD8E4F5),
            ),
          ),
          padding: const EdgeInsets.all(5),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: BoxDecoration(
              color: _kBlue,
              borderRadius: BorderRadius.circular(7),
              boxShadow: [BoxShadow(color: _kBlue.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? AppTheme.darkMuted : _kMuted,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            tabs: _tabDefs.map((t) => Tab(
              height: 34,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.$1, size: 14),
                const SizedBox(width: 6),
                Text(t.$2),
              ]),
            )).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _PertesContent(api: widget.api),
              _KriView(api: widget.api),
              _CartographieView(api: widget.api),
              _ControlesView(api: widget.api),
              _WorkflowView(api: widget.api),
              _PlansView(api: widget.api),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€ Contenu Pertes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PertesContent extends StatefulWidget {
  const _PertesContent({required this.api});
  final RwaApiService api;
  @override
  State<_PertesContent> createState() => _PertesContentState();
}

class _PertesContentState extends State<_PertesContent> {
  late Future<List<RoIncident>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() { _future = widget.api.fetchRoIncidents(); });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoIncident>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final items = snap.data!;
        final totalBrute = items.fold(0.0, (s, e) => s + e.perteBrute);
        final totalNette = items.fold(0.0, (s, e) => s + e.perteNette);
        final totalRecup = items.fold(0.0, (s, e) => s + e.perteRecuperee);
        final tauxRecup = totalBrute > 0 ? (totalRecup / totalBrute) * 100 : 0.0;
        final moyenne = items.isNotEmpty ? totalNette / items.length : 0.0;
        final significatifs = items.where((e) => e.significatif).length;
        final sortedTop5 = [...items]..sort((a, b) => b.perteNette.compareTo(a.perteNette));
        final top5 = sortedTop5.take(5).toList();

        final byLigne = <String, double>{};
        for (final i in items) {
          byLigne[i.ligneMetier] = (byLigne[i.ligneMetier] ?? 0) + i.perteNette;
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre de commandes
              Row(
                children: [
                  Expanded(child: _kpiBox(ctx, 'Perte brute totale', AppFormatters.currency(totalBrute), Icons.money_off, _kDanger,
                    tooltip: 'Somme des pertes avant dÃ©duction des montants rÃ©cupÃ©rÃ©s.\nFormule : Î£ perte_brute sur tous les incidents de la pÃ©riode.\nReprÃ©senthe l\'exposition totale avant attÃ©nuation. (Art. 313.b)')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Perte nette totale', AppFormatters.currency(totalNette), Icons.trending_down, _kDanger,
                    tooltip: 'Somme des pertes rÃ©ellement supportÃ©es aprÃ¨s rÃ©cupÃ©rations.\nFormule : Î£ (perte_brute âˆ’ perte_rÃ©cupÃ©rÃ©e).\nC\'est la base de calcul du Capital minimal selon l\'approche BIA. (Art. 313.b / Art. 89)')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Taux de rÃ©cupÃ©ration', '${tauxRecup.toStringAsFixed(1)} %', Icons.savings_outlined, _kSuccess,
                    tooltip: 'Part des pertes brutes rÃ©cupÃ©rÃ©e via assurances, provisions ou recours.\nFormule : (Î£ perte_rÃ©cupÃ©rÃ©e / Î£ perte_brute) Ã— 100.\nMesure l\'efficacitÃ© des mÃ©canismes d\'attÃ©nuation.')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Pertes significatives', '$significatifs', Icons.warning_outlined, _kWarning,
                    tooltip: 'Incidents dont la perte brute dÃ©passe le seuil de significativitÃ©.\nFormule : COUNT(incidents) WHERE perte_brute > seuil.\nPermet d\'identifier les Ã©vÃ©nements Ã  fort impact. (Art. 313.b)')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Perte moyenne / incident', AppFormatters.currency(moyenne), Icons.calculate_outlined, _kMuted,
                    tooltip: 'SÃ©vÃ©ritÃ© moyenne des pertes sur la pÃ©riode sÃ©lectionnÃ©e.\nFormule : Î£ perte_nette / nombre d\'incidents.\nIndicateur de gravitÃ© unitaire des incidents opÃ©rationnels.')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SectionCard(
                      title: 'Top 5 incidents par perte nette',
                      child: items.isEmpty
                          ? const Padding(padding: EdgeInsets.all(16), child: Text('Aucun incident.', style: TextStyle(color: _kMuted)))
                          : Table(
                              columnWidths: const {0: FixedColumnWidth(120), 1: FlexColumnWidth(), 2: FixedColumnWidth(110)},
                              children: [
                                _tableHeader(['RÃ©fÃ©rence', 'Description', 'Perte nette']),
                                ...top5.map((i) => TableRow(
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x11000000)))),
                                  children: [_cell(i.reference, bold: true), _cellFlex(i.description), _cell(AppFormatters.currency(i.perteNette), right: true, color: _kDanger)],
                                )),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SectionCard(
                      title: 'Pertes par ligne de mÃ©tier',
                      child: byLigne.isEmpty
                          ? const Padding(padding: EdgeInsets.all(16), child: Text('Aucune donnÃ©e.', style: TextStyle(color: _kMuted)))
                          : _RoPieChart(
                              items: byLigne.entries.map((e) => RoRepartitionItem(label: e.key, valeur: e.value.round())).toList(),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// â”€â”€â”€ VIEW 4 : KRI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _kriNumSources = <int, (String, IconData)>{
  1: ('Service IT â€” logs systÃ¨me', Icons.computer_rounded),
  2: ('Service IT â€” monitoring', Icons.monitor_heart_rounded),
  3: ('Service IT / SÃ©curitÃ© informatique', Icons.security_rounded),
  4: ('Audit interne', Icons.fact_check_rounded),
  5: ('Responsable risque opÃ©rationnel', Icons.manage_accounts_rounded),
  6: ('Service RH', Icons.people_rounded),
  7: ('Responsable risque opÃ©rationnel', Icons.manage_accounts_rounded),
  8: ('Responsable risque opÃ©rationnel', Icons.manage_accounts_rounded),
};

const _kriNumDescriptions = <int, String>{
  1: 'Erreurs de saisie sur les opÃ©rations (virements, comptes) par jour ouvrable.',
  2: 'DisponibilitÃ© du core banking en pourcentage sur la pÃ©riode.',
  3: 'Tentatives de connexion Ã©chouÃ©es ou accÃ¨s Ã  des modules sans droits par semaine.',
  4: 'ContrÃ´les planifiÃ©s dont l\'Ã©chÃ©ance est dÃ©passÃ©e sans rÃ©alisation (tolÃ©rance zÃ©ro).',
  5: 'Incidents au statut Â«OuvertÂ» ou Â«En coursÂ» depuis plus de 30 jours (critique : 1).',
  6: 'EmployÃ©s ayant quittÃ© la banque sur le trimestre (% des effectifs totaux).',
  7: 'DÃ©lai moyen en jours entre la dÃ©tection d\'un incident et sa dÃ©claration (Art. 313.b â‰¤ 5 j).',
  8: 'Plans d\'actions dont l\'Ã©chÃ©ance est dÃ©passÃ©e avec avancement < 100 % (tolÃ©rance zÃ©ro).',
};

int _extractKriNum(String nom) {
  final m = RegExp(r'(\d+)').firstMatch(nom);
  return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
}

Widget _thresholdInfoChip(String label, double seuil, String unite, String sens, Color color) {
  final symbol = sens == 'superieur' ? '>' : '<';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text('$label: $symbol $seuil $unite',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

class _KriView extends StatefulWidget {
  const _KriView({required this.api});
  final RwaApiService api;
  @override
  State<_KriView> createState() => _KriViewState();
}

class _KriViewState extends State<_KriView> {
  late Future<RoKriModuleData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() { _future = widget.api.fetchRoKri(); });

  Future<void> _addValeur(List<RoKriView> kris, {String? preselectedId}) async {
    if (kris.isEmpty) return;
    String? kriId = preselectedId ?? kris.first.definition.id;
    String? periode = 'Mensuel';
    String? source;
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final valCtrl = TextEditingController();
    final commCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final selKri = kris.firstWhere((k) => k.definition.id == kriId, orElse: () => kris.first);
          final d = selKri.definition;
          final kriNum = _extractKriNum(d.nom);
          final (srcDefault, srcIcon) = _kriNumSources[kriNum] ?? ('Responsable risque opÃ©rationnel', Icons.manage_accounts_rounded);
          source ??= srcDefault;
          final desc = _kriNumDescriptions[kriNum] ?? d.formule;

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                color: AppColors.prudentialSolvency.withValues(alpha: 0.06),
                border: Border(bottom: BorderSide(color: AppColors.prudentialSolvency.withValues(alpha: 0.15))),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.prudentialSolvency.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.speed_rounded, color: AppColors.prudentialSolvency, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Saisir une valeur KRI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Indicateur clÃ© de risque â€” mesure pÃ©riodique (Art. 313)',
                    style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w400)),
                ])),
              ]),
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _formSection('SÃ©lection de l\'indicateur', icon: Icons.speed_rounded, color: AppColors.prudentialSolvency),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.analytics_rounded, size: 12, color: _kBlue),
                              SizedBox(width: 5),
                              Text('Indicateur KRI *',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kMuted)),
                            ]),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              initialValue: kriId,
                              isExpanded: true,
                              icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                              items: kris.map((k) => DropdownMenuItem(
                                value: k.definition.id,
                                child: Text(k.definition.nom, style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) => setD(() { kriId = v; source = null; }),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                              ),
                              validator: (v) => v == null ? 'Champ requis' : null,
                            ),
                          ],
                        ),
                      ),
                      // Fiche info du KRI sÃ©lectionnÃ©
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.prudentialSolvency.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.prudentialSolvency.withValues(alpha: 0.18)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(desc, style: const TextStyle(fontSize: 11.5, color: _kMuted, height: 1.5)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 5, children: [
                              _thresholdInfoChip('Alerte', d.seuilAlerte, d.unite, d.sens, _kWarning),
                              _thresholdInfoChip('Critique', d.seuilCritique, d.unite, d.sens, _kDanger),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(srcIcon, size: 11, color: _kMuted),
                              const SizedBox(width: 5),
                              Expanded(child: Text('Source habituelle : $srcDefault',
                                style: const TextStyle(fontSize: 10.5, color: _kMuted))),
                            ]),
                          ],
                        ),
                      ),
                      _formSection('Mesure', icon: Icons.straighten_rounded, color: _kBlue),
                      _formRow(
                        _dropdown('PÃ©riode', periode, ['Hebdomadaire', 'Mensuel', 'Trimestriel'],
                          (v) => setD(() => periode = v), required: true, icon: Icons.calendar_view_month_rounded),
                        _dateField(ctx, 'Date de mesure', dateCtrl, required: true),
                      ),
                      _field('Valeur mesurÃ©e', valCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        required: true, icon: Icons.numbers_rounded,
                        hint: 'Saisir la valeur observÃ©e (ex: 3, 98.5, 2.0)'),
                      _formSection('Contexte et source', icon: Icons.info_outline_rounded, color: _kMuted),
                      _dropdown('Source de la donnÃ©e', source, [
                        'Service IT â€” logs systÃ¨me',
                        'Service IT â€” monitoring',
                        'Service IT / SÃ©curitÃ© informatique',
                        'Audit interne',
                        'Service RH',
                        'Responsable risque opÃ©rationnel',
                        'Superviseur / Chef d\'Ã©quipe',
                      ], (v) => setD(() => source = v), icon: Icons.people_rounded,
                        hint: 'Qui a fourni cette valeur ?'),
                      _field('Commentaire / contexte', commCtrl, multiline: true,
                        icon: Icons.notes_rounded,
                        hint: 'Contexte, cause identifiÃ©e ou action dÃ©clenchÃ©e...'),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            actions: [
              OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.save_rounded, size: 16),
                style: FilledButton.styleFrom(backgroundColor: AppColors.prudentialSolvency),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final commentaire = [
                    if (source != null && source!.isNotEmpty) 'Source: $source',
                    if (commCtrl.text.trim().isNotEmpty) commCtrl.text.trim(),
                  ].join(' | ');
                  try {
                    await widget.api.addRoKriValeur({
                      'kri_id': kriId,
                      'date_mesure': dateCtrl.text.trim(),
                      'valeur': double.tryParse(valCtrl.text.trim().replaceAll(',', '.')) ?? 0,
                      'commentaire': commentaire,
                      'periode': periode,
                    });
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger));
                    }
                  }
                },
                label: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) _reload();
  }

  Future<void> _showHistorique(RoKriView kri, List<RoKriView> allKris) async {
    await showDialog(
      context: context,
      builder: (ctx) => _KriHistoriqueDialog(
        kri: kri,
        kriNum: _extractKriNum(kri.definition.nom),
        onSaisir: () {
          Navigator.pop(ctx);
          _addValeur(allKris, preselectedId: kri.definition.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoKriModuleData>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final data = snap.data!;
        final kris = data.kriList;
        final normal   = kris.where((k) => k.statut == 'normal').length;
        final alerte   = kris.where((k) => k.statut == 'alerte').length;
        final critique = kris.where((k) => k.statut == 'critique').length;
        final nonRens  = kris.where((k) => k.statut == 'non_renseigne').length;

        return Column(
          children: [
            // â”€â”€ Bandeau conformitÃ© â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _KriBanner(total: kris.length, normal: normal, alerte: alerte,
              critique: critique, nonRens: nonRens),
            const SizedBox(height: 12),
            // â”€â”€ Barre d'actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Row(children: [
              if (data.kriHorsSeuil > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kDanger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kDanger.withValues(alpha: 0.30)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.notifications_active_rounded, color: _kDanger, size: 14),
                    const SizedBox(width: 6),
                    Text('${data.kriHorsSeuil} KRI hors seuil â€” action immÃ©diate requise',
                      style: const TextStyle(color: _kDanger, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Actualiser'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.prudentialSolvency),
                onPressed: kris.isEmpty ? null : () => _addValeur(kris),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Saisir une valeur'),
              ),
            ]),
            const SizedBox(height: 12),
            // â”€â”€ Grille de cartes KRI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: kris.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.speed_outlined, size: 52, color: _kMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('Aucun KRI configurÃ©', style: TextStyle(color: _kMuted, fontSize: 13)),
                    ]))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          for (int i = 0; i < kris.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _KriCard(
                                    kri: kris[i],
                                    kriNum: _extractKriNum(kris[i].definition.nom),
                                    onSaisir: () => _addValeur(kris, preselectedId: kris[i].definition.id),
                                    onHistorique: () => _showHistorique(kris[i], kris),
                                  )),
                                  if (i + 1 < kris.length) ...[
                                    const SizedBox(width: 10),
                                    Expanded(child: _KriCard(
                                      kri: kris[i + 1],
                                      kriNum: _extractKriNum(kris[i + 1].definition.nom),
                                      onSaisir: () => _addValeur(kris, preselectedId: kris[i + 1].definition.id),
                                      onHistorique: () => _showHistorique(kris[i + 1], kris),
                                    )),
                                  ] else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// â”€â”€â”€ KRI Compliance Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KriBanner extends StatelessWidget {
  const _KriBanner({required this.total, required this.normal, required this.alerte,
    required this.critique, required this.nonRens});
  final int total, normal, alerte, critique, nonRens;

  @override
  Widget build(BuildContext context) {
    final allOk = critique == 0 && alerte == 0;

    Widget statCol(String label, String value, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55),
          fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
          color: color == _kMuted ? Colors.white.withValues(alpha: 0.45) : color,
          fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ],
    );

    Widget sep() => Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.18));

    final headline = critique > 0
        ? '$critique KRI CRITIQUE${critique > 1 ? 'S' : ''} â€” ACTION IMMÃ‰DIATE REQUISE'
        : alerte > 0
            ? '$alerte KRI EN ALERTE â€” SURVEILLANCE RENFORCÃ‰E'
            : total == 0 ? 'AUCUN KRI CONFIGURÃ‰'
            : nonRens == total ? 'SAISIR LES PREMIÃˆRES VALEURS POUR ACTIVER LA SURVEILLANCE'
            : 'TOUS LES KRI DANS LES SEUILS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: allOk
              ? [const Color(0xFF042B16), const Color(0xFF0D5C30)]
              : critique > 0
                  ? [const Color(0xFF3D0A0A), const Color(0xFF7A1212)]
                  : [const Color(0xFF2D1A00), const Color(0xFF5C3600)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(
          color: (allOk ? _kSuccess : critique > 0 ? _kDanger : _kWarning).withValues(alpha: 0.20),
          blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(allOk ? Icons.shield_rounded : Icons.speed_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Text('INDICATEURS CLÃ‰S DE RISQUE Â· ART. 313 BCEAO/UMOA',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65),
                fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
            const SizedBox(height: 2),
            Text(headline,
              style: const TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w900, letterSpacing: -0.3),
              overflow: TextOverflow.ellipsis),
          ],
        )),
        Row(mainAxisSize: MainAxisSize.min, children: [
          statCol('NORMAL', '$normal', _kSuccess),
          sep(),
          statCol('ALERTE', '$alerte', _kWarning),
          sep(),
          statCol('CRITIQUE', '$critique', _kDanger),
          if (nonRens > 0) ...[sep(), statCol('N/R', '$nonRens', _kMuted)],
        ]),
      ]),
    );
  }
}

// â”€â”€â”€ KRI Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KriCard extends StatelessWidget {
  const _KriCard({required this.kri, required this.kriNum,
    required this.onSaisir, required this.onHistorique});
  final RoKriView kri;
  final int kriNum;
  final VoidCallback onSaisir;
  final VoidCallback onHistorique;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = kri.definition;
    final sc = _kriStatutColor(kri.statut);
    final sl = _kriStatutLabel(kri.statut);
    final (srcLabel, srcIcon) = _kriNumSources[kriNum] ?? ('Non spÃ©cifiÃ©', Icons.help_outline_rounded);
    final description = _kriNumDescriptions[kriNum] ?? d.formule;
    final isCrit = kri.statut == 'critique';
    final isAlt  = kri.statut == 'alerte';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCrit ? _kDanger.withValues(alpha: 0.40)
              : isAlt ? _kWarning.withValues(alpha: 0.30)
              : isDark ? AppTheme.darkBorder : AppTheme.border,
          width: isCrit ? 1.5 : 1.0,
        ),
        boxShadow: isCrit
            ? [BoxShadow(color: _kDanger.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 3))]
            : isAlt
                ? [BoxShadow(color: _kWarning.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3))]
                : isDark ? null
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: sc),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tÃªte
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.prudentialSolvency.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('KRI ${kriNum.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: AppColors.prudentialSolvency, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.nom,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.text),
                      overflow: TextOverflow.ellipsis)),
                    _badge(sl, sc),
                  ]),
                  const SizedBox(height: 8),
                  // Description
                  Text(description,
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkMuted : _kMuted,
                      height: 1.45, fontStyle: FontStyle.italic),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  // Valeur actuelle
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    kri.derniereValeur != null
                        ? Text(
                            kri.derniereValeur! % 1 == 0
                                ? kri.derniereValeur!.toInt().toString()
                                : kri.derniereValeur!.toStringAsFixed(1),
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                              color: sc, height: 1.0, letterSpacing: -1.0))
                        : Text('â€”', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                            color: _kMuted.withValues(alpha: 0.35), height: 1.0)),
                    const SizedBox(width: 5),
                    Padding(padding: const EdgeInsets.only(bottom: 4),
                      child: Text(d.unite,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkMuted : _kMuted))),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (kri.derniereDate != null)
                        Text(kri.derniereDate!, style: const TextStyle(fontSize: 10, color: _kMuted)),
                      Text(d.frequence, style: const TextStyle(fontSize: 10, color: _kMuted)),
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  // Jauge visuelle
                  if (kri.derniereValeur != null)
                    _KriGauge(kri: kri)
                  else
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: _kMuted.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _kMuted.withValues(alpha: 0.12)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Aucune valeur saisie',
                        style: TextStyle(fontSize: 9.5, color: _kMuted)),
                    ),
                  const SizedBox(height: 8),
                  // Seuils
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _thresholdInfoChip('Alerte', d.seuilAlerte, d.unite, d.sens, _kWarning),
                    _thresholdInfoChip('Critique', d.seuilCritique, d.unite, d.sens, _kDanger),
                  ]),
                  const SizedBox(height: 8),
                  // Source
                  Row(children: [
                    Icon(srcIcon, size: 11, color: _kMuted),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Source: $srcLabel',
                      style: const TextStyle(fontSize: 10, color: _kMuted),
                      overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 10),
                  // Boutons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onHistorique,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.history_rounded, size: 13),
                        label: const Text('Historique', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onSaisir,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.prudentialSolvency,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 13),
                        label: const Text('Saisir', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ]),
                  // BanniÃ¨re d'alerte contextuelle
                  if (isCrit) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kDanger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kDanger.withValues(alpha: 0.25)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.warning_rounded, color: _kDanger, size: 12),
                        SizedBox(width: 6),
                        Expanded(child: Text('Action immÃ©diate â€” dÃ©clencher un plan d\'action',
                          style: TextStyle(fontSize: 10, color: _kDanger, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ] else if (isAlt) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kWarning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kWarning.withValues(alpha: 0.25)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_rounded, color: _kWarning, size: 12),
                        SizedBox(width: 6),
                        Expanded(child: Text('Investiguer la cause et renforcer la surveillance',
                          style: TextStyle(fontSize: 10, color: _kWarning, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// â”€â”€â”€ KRI Gauge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KriGauge extends StatelessWidget {
  const _KriGauge({required this.kri});
  final RoKriView kri;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: CustomPaint(painter: _KriGaugePainter(kri: kri), size: const Size(double.infinity, 28)),
  );
}

class _KriGaugePainter extends CustomPainter {
  const _KriGaugePainter({required this.kri});
  final RoKriView kri;

  @override
  void paint(Canvas canvas, Size size) {
    final d   = kri.definition;
    final val = kri.derniereValeur;
    if (val == null) return;

    final sup = d.sens == 'superieur';
    final w = size.width;
    const barH = 8.0;
    const barTop = 12.0;

    double maxV, minV;
    if (sup) {
      maxV = math.max(val, d.seuilCritique) * 1.4;
      minV = 0.0;
    } else {
      minV = math.min(val, d.seuilCritique) * 0.85;
      maxV = 100.0;
    }
    final range = maxV - minV;
    if (range <= 0) return;

    double px(double v) => ((v - minV) / range * w).clamp(0.0, w);

    final pA = px(d.seuilAlerte);
    final pC = px(d.seuilCritique);
    final pV = px(val);

    final pGreen  = Paint()..color = _kSuccess.withValues(alpha: 0.85)..style = PaintingStyle.fill;
    final pOrange = Paint()..color = _kWarning.withValues(alpha: 0.85)..style = PaintingStyle.fill;
    final pRed    = Paint()..color = _kDanger.withValues(alpha: 0.85)..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, w, barH), const Radius.circular(4)));

    if (sup) {
      canvas.drawRect(Rect.fromLTWH(0, barTop, pA, barH), pGreen);
      if (pC > pA) canvas.drawRect(Rect.fromLTWH(pA, barTop, pC - pA, barH), pOrange);
      canvas.drawRect(Rect.fromLTWH(pC, barTop, w - pC, barH), pRed);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, barTop, pC, barH), pRed);
      if (pA > pC) canvas.drawRect(Rect.fromLTWH(pC, barTop, pA - pC, barH), pOrange);
      canvas.drawRect(Rect.fromLTWH(pA, barTop, w - pA, barH), pGreen);
    }
    canvas.restore();

    // SÃ©parateurs de seuil
    final divP = Paint()..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(pA, barTop), Offset(pA, barTop + barH), divP);
    if ((pC - pA).abs() > 2) canvas.drawLine(Offset(pC, barTop), Offset(pC, barTop + barH), divP);

    // Indicateur valeur (triangle)
    final ic = _kriStatutColor(kri.statut);
    canvas.drawPath(
      Path()..moveTo(pV, barTop - 2)..lineTo(pV - 5, barTop - 9)..lineTo(pV + 5, barTop - 9)..close(),
      Paint()..color = ic..style = PaintingStyle.fill);

    // Label valeur
    final valStr = val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
    final tp = TextPainter(
      text: TextSpan(text: valStr,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: ic)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset((pV - tp.width / 2).clamp(0.0, w - tp.width), 0));
  }

  @override
  bool shouldRepaint(_KriGaugePainter old) => true;
}

// â”€â”€â”€ Historique Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KriHistoriqueDialog extends StatelessWidget {
  const _KriHistoriqueDialog({required this.kri, required this.kriNum, required this.onSaisir});
  final RoKriView kri;
  final int kriNum;
  final VoidCallback onSaisir;

  @override
  Widget build(BuildContext context) {
    final d = kri.definition;
    final color = _kriStatutColor(kri.statut);
    final (srcLabel, srcIcon) = _kriNumSources[kriNum] ?? ('Non spÃ©cifiÃ©', Icons.help_outline_rounded);
    final hist = List<RoKriValeur>.from(kri.historique)
      ..sort((a, b) => b.dateMesure.compareTo(a.dateMesure));

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
            decoration: BoxDecoration(
              color: AppColors.prudentialSolvency.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(color: AppColors.prudentialSolvency.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.prudentialSolvency.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: Text('KRI ${kriNum.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.prudentialSolvency)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${d.unite} Â· ${d.frequence}',
                  style: const TextStyle(fontSize: 10.5, color: _kMuted)),
              ])),
              _badge(_kriStatutLabel(kri.statut), color),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Tiles info
                Row(children: [
                  Expanded(child: _infoTile('Seuil alerte',
                    '${d.sens == 'superieur' ? '>' : '<'} ${d.seuilAlerte} ${d.unite}', _kWarning)),
                  const SizedBox(width: 10),
                  Expanded(child: _infoTile('Seuil critique',
                    '${d.sens == 'superieur' ? '>' : '<'} ${d.seuilCritique} ${d.unite}', _kDanger)),
                  const SizedBox(width: 10),
                  Expanded(child: _infoTile('DerniÃ¨re valeur',
                    kri.derniereValeur != null
                        ? '${kri.derniereValeur! % 1 == 0 ? kri.derniereValeur!.toInt() : kri.derniereValeur!.toStringAsFixed(1)} ${d.unite}'
                        : 'N/A',
                    color)),
                ]),
                const SizedBox(height: 12),
                Text(_kriNumDescriptions[kriNum] ?? d.formule,
                  style: const TextStyle(fontSize: 11.5, color: _kMuted, height: 1.5)),
                const SizedBox(height: 14),
                // Sparkline
                if (kri.historique.length >= 2) ...[
                  Row(children: [
                    const Text('Ã‰volution des mesures',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    Text('${kri.historique.length} mesure(s)',
                      style: const TextStyle(fontSize: 11, color: _kMuted)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: CustomPaint(
                      painter: _KriSparklinePainter(
                        values: kri.historique.map((v) => v.valeur).toList(),
                        seuilAlerte: d.seuilAlerte,
                        seuilCritique: d.seuilCritique,
                        sens: d.sens,
                      ),
                      size: const Size(double.infinity, 100),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // Tableau
                const Text('Historique des mesures',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 8),
                hist.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _kMuted.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kMuted.withValues(alpha: 0.12)),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.history_rounded, size: 36, color: _kMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 10),
                          const Text('Aucune mesure enregistrÃ©e',
                            style: TextStyle(color: _kMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          const Text('Cliquez Â«Saisir une valeurÂ» pour commencer le suivi',
                            style: TextStyle(color: _kMuted, fontSize: 10.5)),
                        ]),
                      )
                    : Table(
                        border: TableBorder.all(color: const Color(0x15000000),
                          borderRadius: BorderRadius.circular(6)),
                        columnWidths: const {
                          0: FixedColumnWidth(110),
                          1: FixedColumnWidth(110),
                          2: FixedColumnWidth(90),
                          3: FlexColumnWidth(),
                        },
                        children: [
                          _tableHeader(['Date', 'Valeur', 'Statut', 'Commentaire']),
                          ...hist.map((v) {
                            String hs;
                            if (d.sens == 'superieur') {
                              hs = v.valeur >= d.seuilCritique ? 'critique'
                                  : v.valeur >= d.seuilAlerte ? 'alerte' : 'normal';
                            } else {
                              hs = v.valeur <= d.seuilCritique ? 'critique'
                                  : v.valeur <= d.seuilAlerte ? 'alerte' : 'normal';
                            }
                            final hc = _kriStatutColor(hs);
                            return TableRow(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0x11000000)))),
                              children: [
                                _cell(v.dateMesure),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Text(
                                      '${v.valeur % 1 == 0 ? v.valeur.toInt() : v.valeur.toStringAsFixed(1)} ${d.unite}',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: hc)),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: _badge(_kriStatutLabel(hs), hc),
                                  ),
                                ),
                                _cellFlex(v.commentaire.isEmpty ? 'â€”' : v.commentaire),
                              ],
                            );
                          }),
                        ],
                      ),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(srcIcon, size: 12, color: _kMuted),
                  const SizedBox(width: 6),
                  Text('Source de la donnÃ©e : $srcLabel',
                    style: const TextStyle(fontSize: 11, color: _kMuted)),
                ]),
              ]),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kMuted.withValues(alpha: 0.15)))),
            child: Row(children: [
              const Spacer(),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.prudentialSolvency),
                onPressed: onSaisir,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Saisir une valeur'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoTile(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
        overflow: TextOverflow.ellipsis),
    ]),
  );
}

// â”€â”€â”€ KRI Sparkline â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KriSparklinePainter extends CustomPainter {
  const _KriSparklinePainter({required this.values, required this.seuilAlerte,
    required this.seuilCritique, required this.sens});
  final List<double> values;
  final double seuilAlerte, seuilCritique;
  final String sens;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    double lo = values.reduce(math.min);
    double hi = values.reduce(math.max);
    lo = math.min(lo, math.min(seuilAlerte, seuilCritique));
    hi = math.max(hi, math.max(seuilAlerte, seuilCritique));
    final pad = math.max((hi - lo) * 0.15, 0.5);
    lo -= pad; hi += pad;
    final range = hi - lo;
    if (range <= 0) return;

    final w = size.width;
    final h = size.height - 4;
    double toX(int i) => i / (values.length - 1) * w;
    double toY(double v) => h - ((v - lo) / range * h) + 2;

    // Lignes de seuil
    canvas.drawLine(Offset(0, toY(seuilAlerte)), Offset(w, toY(seuilAlerte)),
      Paint()..color = _kWarning.withValues(alpha: 0.55)..strokeWidth = 1..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(0, toY(seuilCritique)), Offset(w, toY(seuilCritique)),
      Paint()..color = _kDanger.withValues(alpha: 0.55)..strokeWidth = 1..style = PaintingStyle.stroke);

    // Ligne
    final linePath = Path()..moveTo(toX(0), toY(values[0]));
    for (int i = 1; i < values.length; i++) { linePath.lineTo(toX(i), toY(values[i])); }
    canvas.drawPath(linePath, Paint()
      ..color = _kBlue..strokeWidth = 2..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);

    // Remplissage
    final fillPath = Path.from(linePath)
      ..lineTo(w, h + 2)..lineTo(0, h + 2)..close();
    canvas.drawPath(fillPath, Paint()
      ..color = _kBlue.withValues(alpha: 0.08)..style = PaintingStyle.fill);

    // Points colorÃ©s par statut
    for (int i = 0; i < values.length; i++) {
      Color dc;
      if (sens == 'superieur') {
        dc = values[i] >= seuilCritique ? _kDanger
            : values[i] >= seuilAlerte ? _kWarning : _kSuccess;
      } else {
        dc = values[i] <= seuilCritique ? _kDanger
            : values[i] <= seuilAlerte ? _kWarning : _kSuccess;
      }
      final cx = toX(i); final cy = toY(values[i]);
      canvas.drawCircle(Offset(cx, cy), 3.5, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(cx, cy), 3.5,
        Paint()..color = dc..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_KriSparklinePainter old) => true;
}

// â”€â”€â”€ VIEW 5 : CARTOGRAPHIE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CartographieView extends StatefulWidget {
  const _CartographieView({required this.api});
  final RwaApiService api;
  @override
  State<_CartographieView> createState() => _CartographieViewState();
}

class _CartographieViewState extends State<_CartographieView> {
  late Future<List<RoRisque>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() { _future = widget.api.fetchRoRisques(); });

  Future<void> _showForm({RoRisque? edit}) async {
    final nomCtrl = TextEditingController(text: edit?.nom ?? '');
    final controleCtrl = TextEditingController(text: edit?.controleExistant ?? '');
    String? cat = edit?.categorie ?? _categoriesRisque.first;
    String? ligne = edit?.ligneMetier ?? _lignesMetier.first;
    int proba = edit?.probabilite ?? 1;
    int impact = edit?.impact ?? 1;
    int eff = edit?.efficaciteControle ?? 3;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(color: _kBlue.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.map_rounded, color: _kBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(edit == null ? 'Nouveau risque cartographiÃ©' : 'Modifier le risque',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('Cartographie des risques opÃ©rationnels',
                  style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w400)),
              ])),
            ]),
          ),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formSection('Identification du risque', icon: Icons.search_rounded, color: _kBlue),
                    _field('Nom du risque', nomCtrl, required: true,
                      icon: Icons.label_rounded, hint: 'Ex: Risque de fraude interne'),
                    _formRow(
                      _dropdown('CatÃ©gorie', cat, _categoriesRisque, (v) => setD(() => cat = v),
                        required: true, icon: Icons.category_rounded),
                      _dropdown('Ligne de mÃ©tier', ligne, _lignesMetier, (v) => setD(() => ligne = v),
                        required: true, icon: Icons.business_rounded),
                    ),
                    _formSection('Ã‰valuation du risque brut', icon: Icons.bar_chart_rounded, color: _kWarning),
                    _formRow(
                      _dropdown('ProbabilitÃ© (1â€“5)', proba, [1, 2, 3, 4, 5],
                        (v) => setD(() => proba = v ?? 1), icon: Icons.repeat_rounded),
                      _dropdown('Impact (1â€“5)', impact, [1, 2, 3, 4, 5],
                        (v) => setD(() => impact = v ?? 1), icon: Icons.flash_on_rounded),
                    ),
                    _formSection('ContrÃ´le interne', icon: Icons.shield_rounded, color: _kSuccess),
                    _field('ContrÃ´le existant', controleCtrl, icon: Icons.notes_rounded,
                      hint: 'DÃ©crivez les contrÃ´les en place...', multiline: true),
                    _dropdown('EfficacitÃ© du contrÃ´le (1â€“5)', eff, [1, 2, 3, 4, 5],
                      (v) => setD(() => eff = v ?? 3), icon: Icons.tune_rounded),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: Icon(edit == null ? Icons.add_rounded : Icons.save_rounded, size: 16),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'nom': nomCtrl.text.trim(), 'categorie': cat, 'ligne_metier': ligne,
                  'probabilite': proba, 'impact': impact,
                  'controle_existant': controleCtrl.text.trim(), 'efficacite_controle': eff,
                };
                try {
                  edit == null ? await widget.api.createRoRisque(data) : await widget.api.updateRoRisque(edit.id, data);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger));
                }
              },
              label: Text(edit == null ? 'CrÃ©er' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoRisque>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final items = snap.data!;

        final faible   = items.where((r) => r.niveauBrut <= 4).length;
        final eleve    = items.where((r) => r.niveauBrut > 9 && r.niveauBrut <= 16).length;
        final critique = items.where((r) => r.niveauBrut > 16).length;

        return Column(
          children: [
            // â”€â”€ KPI + action â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Row(children: [
              Expanded(child: _kpiBox(ctx, 'Risques cartographiÃ©s', '${items.length}',
                Icons.map_rounded, _kBlue,
                tooltip: 'Nombre total de risques positionnÃ©s sur la matrice 5Ã—5 (Art. 313)')),
              const SizedBox(width: 10),
              Expanded(child: _kpiBox(ctx, 'Niveau faible', '$faible',
                Icons.check_circle_outline_rounded, _kSuccess,
                tooltip: 'Score PÃ—I â‰¤ 4 â€” risque acceptable, surveillance standard')),
              const SizedBox(width: 10),
              Expanded(child: _kpiBox(ctx, 'Niveau Ã©levÃ©', '$eleve',
                Icons.report_outlined, const Color(0xFFF97316),
                tooltip: 'Score PÃ—I 10â€“16 â€” plan d\'action recommandÃ©')),
              const SizedBox(width: 10),
              Expanded(child: _kpiBox(ctx, 'Niveau critique', '$critique',
                Icons.warning_amber_rounded, _kDanger,
                tooltip: 'Score PÃ—I > 16 â€” action immÃ©diate et plan obligatoire (Art. 313)')),
              const SizedBox(width: 14),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouveau risque'),
              ),
            ]),
            const SizedBox(height: 14),
            // â”€â”€ Layout principal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colonne gauche : matrice
                  SizedBox(
                    width: 330,
                    child: SectionCard(
                      title: 'Matrice d\'exposition 5Ã—5',
                      child: SingleChildScrollView(
                        child: _RoRiskMatrix(risques: items),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Colonne droite : liste
                  Expanded(
                    child: items.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.map_outlined, size: 52, color: _kMuted.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            const Text('Aucun risque enregistrÃ©.', style: TextStyle(color: _kMuted, fontSize: 13)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showForm(),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Ajouter le premier risque'),
                            ),
                          ]))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text('${items.length} risque${items.length > 1 ? 's' : ''} cartographiÃ©${items.length > 1 ? 's' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const Spacer(),
                                if (critique > 0)
                                  _badge('$critique critique${critique > 1 ? 's' : ''}', _kDanger),
                              ]),
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, idx) {
                                    final r = items[idx];
                                    return _RisqueListItem(
                                      risque: r,
                                      onEdit: () => _showForm(edit: r),
                                      onDelete: () => _confirm(ctx,
                                        'Supprimer "${r.nom}" ?',
                                        () async { await widget.api.deleteRoRisque(r.id); _reload(); }),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// â”€â”€â”€ Risque List Item â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RisqueListItem extends StatelessWidget {
  const _RisqueListItem({required this.risque, required this.onEdit, required this.onDelete});
  final RoRisque risque;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = risque;
    final lc = _niveauColor(r.niveauLabel);
    final score = r.probabilite * r.impact;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: r.niveauLabel == 'Critique' ? _kDanger.withValues(alpha: 0.35)
              : r.niveauLabel == 'Ã‰levÃ©' ? const Color(0xFFF97316).withValues(alpha: 0.28)
              : isDark ? AppTheme.darkBorder : AppTheme.border,
          width: r.niveauLabel == 'Critique' ? 1.5 : 1.0,
        ),
        boxShadow: r.niveauLabel == 'Critique'
            ? [BoxShadow(color: _kDanger.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 2))]
            : isDark ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Strip couleur
          Container(width: 4, color: lc),
          // Score circle
          Container(
            width: 60,
            alignment: Alignment.center,
            color: lc.withValues(alpha: isDark ? 0.10 : 0.06),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lc.withValues(alpha: isDark ? 0.22 : 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: lc.withValues(alpha: 0.40), width: 1.5),
                ),
                child: Text('$score',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: lc, height: 1.0)),
              ),
              const SizedBox(height: 3),
              Text('PÃ—I', style: TextStyle(fontSize: 8, color: lc.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700)),
            ]),
          ),
          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(child: Text(r.nom,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    _badge(r.niveauLabel, lc),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _risqueChip(r.categorie, Icons.category_rounded, _kBlue),
                    _risqueChip(r.ligneMetier, Icons.business_rounded, AppColors.prudentialSolvency),
                  ]),
                  const SizedBox(height: 7),
                  Row(children: [
                    _metricTile('P', '${r.probabilite}', _kWarning),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text('Ã—', style: TextStyle(fontSize: 12,
                        color: (isDark ? AppTheme.darkMuted : _kMuted).withValues(alpha: 0.7)))),
                    _metricTile('I', '${r.impact}', const Color(0xFFF97316)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text('=', style: TextStyle(fontSize: 12,
                        color: (isDark ? AppTheme.darkMuted : _kMuted).withValues(alpha: 0.7)))),
                    _metricTile('Score', '$score', lc),
                    const SizedBox(width: 14),
                    Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _kMuted.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Text('RÃ©siduel ', style: const TextStyle(fontSize: 10, color: _kMuted)),
                    Text(r.niveauResiduel.toStringAsFixed(1),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkText : AppTheme.text)),
                    if (r.controleExistant.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.shield_outlined, size: 11, color: _kSuccess),
                      const SizedBox(width: 3),
                      Text('Ctrl ${r.efficaciteControle}/5',
                        style: const TextStyle(fontSize: 10, color: _kMuted)),
                    ],
                  ]),
                ],
              ),
            ),
          ),
          // Actions
          Container(
            width: 58,
            alignment: Alignment.center,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _iconBtn(Icons.edit_outlined, _kBlue, onEdit),
              const SizedBox(height: 6),
              _iconBtn(Icons.delete_outline_rounded, _kDanger, onDelete),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _risqueChip(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
        overflow: TextOverflow.ellipsis),
    ]),
  );

  Widget _metricTile(String lbl, String val, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(3),
    ),
    child: RichText(
      text: TextSpan(children: [
        TextSpan(text: '$lbl:', style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.65),
          fontWeight: FontWeight.w500)),
        TextSpan(text: val, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w800)),
      ]),
    ),
  );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 32, height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}

// â”€â”€â”€ VIEW 6 : CONTROLES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ControlesView extends StatefulWidget {
  const _ControlesView({required this.api});
  final RwaApiService api;
  @override
  State<_ControlesView> createState() => _ControlesViewState();
}

class _ControlesViewState extends State<_ControlesView> {
  late Future<List<RoControle>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() { _future = widget.api.fetchRoControles(); });

  Future<void> _showForm({RoControle? edit}) async {
    final perCtrl = TextEditingController(text: edit?.perimetre ?? '');
    final dateCtrl = TextEditingController(text: edit?.dateDernierTest ?? '');
    final nonConfCtrl = TextEditingController(text: edit?.nonConformites ?? '');
    final validCtrl = TextEditingController(text: edit?.validateur ?? '');
    final pcCtrl = TextEditingController(text: edit != null ? '${edit.pointsConformes}' : '');
    final ptcCtrl = TextEditingController(text: edit != null ? '${edit.pointsControles}' : '');
    String? typeC = edit?.typeControle ?? _typesControle.first;
    String? freq = edit?.frequence ?? _frequences.first;
    String? resultat = edit?.resultat ?? 'En cours';
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              color: _kSuccess.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(color: _kSuccess.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kSuccess.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.shield_rounded, color: _kSuccess, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(edit == null ? 'Nouveau contrÃ´le interne' : 'Modifier le contrÃ´le',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('Dispositif de contrÃ´le opÃ©rationnel',
                  style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w400)),
              ])),
            ]),
          ),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formSection('DÃ©finition du contrÃ´le', icon: Icons.tune_rounded, color: _kSuccess),
                    _field('PÃ©rimÃ¨tre contrÃ´lÃ©', perCtrl, required: true,
                      icon: Icons.domain_rounded, hint: 'Ex: Processus de validation des crÃ©dits'),
                    _formRow(
                      _dropdown('Type de contrÃ´le', typeC, _typesControle, (v) => setD(() => typeC = v),
                        required: true, icon: Icons.category_rounded),
                      _dropdown('FrÃ©quence', freq, _frequences, (v) => setD(() => freq = v),
                        required: true, icon: Icons.schedule_rounded),
                    ),
                    _formSection('RÃ©sultat du test', icon: Icons.fact_check_rounded, color: _kWarning),
                    _formRow(
                      _dateField(ctx, 'Date dernier test', dateCtrl),
                      _dropdown('RÃ©sultat', resultat,
                        ['Conforme', 'Non-conforme', 'En cours', 'Non applicable'],
                        (v) => setD(() => resultat = v), icon: Icons.check_circle_rounded),
                    ),
                    _formRow(
                      _field('Points conformes', pcCtrl, keyboardType: TextInputType.number,
                        icon: Icons.check_rounded, hint: 'Ex: 18'),
                      _field('Points contrÃ´lÃ©s', ptcCtrl, keyboardType: TextInputType.number,
                        icon: Icons.list_rounded, hint: 'Ex: 20'),
                    ),
                    _field('Non-conformitÃ©s dÃ©tectÃ©es', nonConfCtrl, multiline: true,
                      icon: Icons.warning_amber_rounded,
                      hint: 'DÃ©crivez les Ã©carts observÃ©s...'),
                    _formSection('Validation', icon: Icons.verified_rounded, color: _kBlue),
                    _field('Validateur', validCtrl, icon: Icons.person_rounded,
                      hint: 'Nom du responsable de la validation'),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: Icon(edit == null ? Icons.add_rounded : Icons.save_rounded, size: 16),
              style: FilledButton.styleFrom(backgroundColor: _kSuccess),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'perimetre': perCtrl.text.trim(), 'type_controle': typeC, 'frequence': freq,
                  'date_dernier_test': dateCtrl.text.trim(), 'resultat': resultat,
                  'points_conformes': int.tryParse(pcCtrl.text) ?? 0,
                  'points_controles': int.tryParse(ptcCtrl.text) ?? 0,
                  'non_conformites': nonConfCtrl.text.trim(), 'validateur': validCtrl.text.trim(),
                };
                try {
                  edit == null ? await widget.api.createRoControle(data) : await widget.api.updateRoControle(edit.id, data);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger));
                }
              },
              label: Text(edit == null ? 'CrÃ©er' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<RoControle>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final items = snap.data!;
        final nonConf = items.where((c) => c.resultat == 'Non-conforme').length;
        final tauxMoyen = items.isNotEmpty ? items.fold(0.0, (s, e) => s + e.tauxConformite) / items.length : 0.0;
        return Column(
          children: [
            Row(
              children: [
                _badge('$nonConf contrÃ´le(s) non conforme(s)', nonConf > 0 ? _kDanger : _kSuccess),
                const SizedBox(width: 10),
                _badge('Taux moyen : ${tauxMoyen.toStringAsFixed(1)} %', tauxMoyen >= 80 ? _kSuccess : _kWarning),
                const Spacer(),
                FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add, size: 18), label: const Text('Nouveau contrÃ´le')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13233E) : Colors.white,
                  border: Border.all(color: isDark ? const Color(0xFF304764) : AppTheme.border),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                child: items.isEmpty
                    ? const Center(child: Text('Aucun contrÃ´le enregistrÃ©.', style: TextStyle(color: _kMuted)))
                    : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(110), 1: FlexColumnWidth(2), 2: FixedColumnWidth(100), 3: FixedColumnWidth(90), 4: FixedColumnWidth(100), 5: FixedColumnWidth(90), 6: FixedColumnWidth(90)},
                          children: [
                            _tableHeader(['RÃ©fÃ©rence', 'PÃ©rimÃ¨tre', 'Type', 'FrÃ©quence', 'Taux conf.', 'RÃ©sultat', 'Actions']),
                            ...items.map((c) => TableRow(
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x11000000)))),
                              children: [
                                _cell(c.reference, bold: true),
                                _cellFlex(c.perimetre),
                                _cell(c.typeControle),
                                _cell(c.frequence),
                                _cell('${c.tauxConformite.toStringAsFixed(1)} %', color: c.tauxConformite >= 80 ? _kSuccess : _kDanger),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Padding(padding: const EdgeInsets.all(8), child: _badge(c.resultat, c.resultat == 'Conforme' ? _kSuccess : c.resultat == 'Non-conforme' ? _kDanger : _kWarning)),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showForm(edit: c)),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: _kDanger),
                                        onPressed: () => _confirm(context, 'Supprimer ce contrÃ´le ?', () async { await widget.api.deleteRoControle(c.id); _reload(); }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// â”€â”€â”€ VIEW 7 : WORKFLOW (KANBAN) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _WorkflowView extends StatefulWidget {
  const _WorkflowView({required this.api});
  final RwaApiService api;
  @override
  State<_WorkflowView> createState() => _WorkflowViewState();
}

class _WorkflowViewState extends State<_WorkflowView> {
  late Future<List<RoIncident>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() { _future = widget.api.fetchRoIncidents(); });

  Future<void> _updateStatut(RoIncident inc, String newStatut) async {
    try {
      await widget.api.updateRoIncident(inc.id, {'statut': newStatut});
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoIncident>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final all = snap.data!;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _statutsIncident.map((s) {
            final col = all.where((i) => i.statut == s).toList();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _statutColor(s).withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radius)),
                        border: Border.all(color: _statutColor(s).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Text(s, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: _statutColor(s))),
                          Text('${col.length}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _statutColor(s))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _statutColor(s).withValues(alpha: 0.25)),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radius)),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.all(6),
                          children: col.map((inc) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inc.reference, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _kBlue)),
                                  const SizedBox(height: 4),
                                  Text(inc.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Text(AppFormatters.currency(inc.perteNette), style: const TextStyle(fontSize: 11, color: _kDanger, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  // Boutons avancement
                                  Wrap(
                                    spacing: 4,
                                    children: _nextStatuts(s).map((ns) => GestureDetector(
                                      onTap: () => _updateStatut(inc, ns),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: _statutColor(ns).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3), border: Border.all(color: _statutColor(ns).withValues(alpha: 0.4))),
                                        child: Text('â†’ $ns', style: TextStyle(fontSize: 10, color: _statutColor(ns), fontWeight: FontWeight.w600)),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<String> _nextStatuts(String current) => switch (current) {
    'Ouvert' => ['En cours'],
    'En cours' => ['RÃ©solu'],
    'RÃ©solu' => ['ClÃ´turÃ©', 'En cours'],
    _ => [],
  };
}

// â”€â”€â”€ VIEW 8 : PLANS D'ACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PlansView extends StatefulWidget {
  const _PlansView({required this.api});
  final RwaApiService api;
  @override
  State<_PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends State<_PlansView> {
  late Future<List<RoPlan>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() { _future = widget.api.fetchRoPlans(); });

  Color _sourceColor(String s) => switch (s) {
    'Incident'     => _kDanger,
    'ContrÃ´le'     => _kWarning,
    'KRI'          => AppColors.prudentialSolvency,
    'Audit'        => AppColors.marketNeutral,
    'Cartographie' => _kBlue,
    _              => _kMuted,
  };

  Future<void> _showForm({RoPlan? edit}) async {
    // Charger toutes les sources en parallÃ¨le avant d'ouvrir le dialog
    final results = await Future.wait([
      widget.api.fetchRoIncidents(),
      widget.api.fetchRoKri(),
      widget.api.fetchRoControles(),
      widget.api.fetchRoRisques(),
    ]);
    final incidents  = results[0] as List<RoIncident>;
    final kriData    = results[1] as RoKriModuleData;
    final controles  = results[2] as List<RoControle>;
    final risques    = results[3] as List<RoRisque>;

    // Construit pour chaque type de source la liste (valeur_stockÃ©e, libellÃ©_affichÃ©)
    List<(String, String)> optionsFor(String src) => switch (src) {
      'Incident'     => incidents.map((i) {
          final desc = i.description.length > 40 ? '${i.description.substring(0, 40)}â€¦' : i.description;
          return (i.reference, '${i.reference}  Â·  $desc');
        }).toList(),
      'KRI'          => kriData.kriList.map((k) => (k.definition.nom, k.definition.nom)).toList(),
      'ContrÃ´le'     => controles.map((c) {
          final peri = c.perimetre.length > 40 ? '${c.perimetre.substring(0, 40)}â€¦' : c.perimetre;
          return (c.reference, '${c.reference}  Â·  $peri');
        }).toList(),
      'Cartographie' => risques.map((r) => (r.nom, r.nom)).toList(),
      _              => <(String, String)>[],
    };

    final titreCtrl = TextEditingController(text: edit?.titre ?? '');
    final descCtrl  = TextEditingController(text: edit?.description ?? '');
    final respCtrl  = TextEditingController(text: edit?.responsable ?? '');
    final debutCtrl = TextEditingController(text: edit?.dateDebut ?? '');
    final echeCtrl  = TextEditingController(text: edit?.dateEcheance ?? '');
    final auditCtrl = TextEditingController(text: edit?.sourceRef ?? '');
    int avancement  = edit?.avancement ?? 0;
    String? type    = edit?.typeAction ?? _typesAction.first;
    String? source  = edit?.source ?? _sourcesAction.first;
    String? sourceRef = edit?.sourceRef.isNotEmpty == true ? edit!.sourceRef : null;
    String? prio    = edit?.priorite ?? _priorites[1];
    String? statut  = edit?.statut ?? _statutsPlan.first;
    DateTime? debutDate = edit?.dateDebut != null && edit!.dateDebut.isNotEmpty
        ? DateTime.tryParse(edit.dateDebut) : null;
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final opts = optionsFor(source ?? '');
          // Si la source change, rÃ©initialiser la ref si la valeur n'est plus dans la liste
          if (opts.isNotEmpty && !opts.any((o) => o.$1 == sourceRef)) {
            sourceRef = null;
          }
          final srcColor = _sourceColor(source ?? '');
          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                color: AppColors.marketNeutral.withValues(alpha: 0.06),
                border: Border(bottom: BorderSide(color: AppColors.marketNeutral.withValues(alpha: 0.15))),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.marketNeutral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: AppColors.marketNeutral, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(edit == null ? 'Nouveau plan d\'action' : 'Modifier le plan',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const Text('Suivi et traÃ§abilitÃ© des actions correctives',
                    style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w400)),
                ])),
              ]),
            ),
            content: SizedBox(
              width: 580,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _formSection('Identification du plan', icon: Icons.label_rounded, color: AppColors.marketNeutral),
                      _field('Titre du plan d\'action', titreCtrl, required: true,
                        icon: Icons.title_rounded, hint: 'Ex: Renforcer le contrÃ´le des accÃ¨s'),
                      _formRow(
                        _dropdown('Type d\'action', type, _typesAction,
                          (v) => setD(() => type = v), required: true, icon: Icons.category_rounded),
                        _dropdown('PrioritÃ©', prio, _priorites,
                          (v) => setD(() => prio = v), required: true, icon: Icons.priority_high_rounded),
                      ),
                      _field('Description', descCtrl, multiline: true, icon: Icons.notes_rounded,
                        hint: 'DÃ©crivez les actions Ã  mener et les objectifs attendus...'),

                      _formSection('Origine du plan', icon: Icons.link_rounded, color: srcColor),
                      _dropdown('Source dÃ©clencheuse', source, _sourcesAction,
                        (v) => setD(() { source = v; sourceRef = null; }),
                        required: true, icon: Icons.account_tree_rounded),

                      // SÃ©lecteur dynamique selon la source
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(width: 7, height: 7,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(color: srcColor, shape: BoxShape.circle)),
                              Text(
                                switch (source) {
                                  'Incident'     => 'Incident dÃ©clencheur *',
                                  'ContrÃ´le'     => 'ContrÃ´le non conforme *',
                                  'KRI'          => 'KRI hors seuil *',
                                  'Audit'        => 'RÃ©fÃ©rence du rapport d\'audit',
                                  'Cartographie' => 'Risque identifiÃ© en cartographie',
                                  _              => 'Ã‰lÃ©ment source',
                                },
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: srcColor),
                              ),
                            ]),
                            const SizedBox(height: 5),
                            if (source == 'Audit')
                              TextFormField(
                                controller: auditCtrl,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'AUD-2024-Q1',
                                  hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                                ),
                              )
                            else if (opts.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                  color: const Color(0xFFFBFCFF),
                                ),
                                child: const Row(children: [
                                  Icon(Icons.info_outline, size: 14, color: _kMuted),
                                  SizedBox(width: 8),
                                  Text('Aucun enregistrement disponible',
                                    style: TextStyle(fontSize: 12.5, color: _kMuted)),
                                ]),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: sourceRef,
                                isExpanded: true,
                                icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'SÃ©lectionnerâ€¦',
                                  hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                                ),
                                items: opts.map((o) => DropdownMenuItem(
                                  value: o.$1,
                                  child: Text(o.$2, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13.5)),
                                )).toList(),
                                onChanged: (v) => setD(() => sourceRef = v),
                              ),
                          ],
                        ),
                      ),

                      _formSection('Planification', icon: Icons.calendar_month_rounded, color: _kWarning),
                      _field('Responsable', respCtrl, icon: Icons.person_rounded,
                        hint: 'Nom du responsable de l\'action'),
                      _formRow(
                        _dateField(ctx, 'Date de dÃ©but', debutCtrl, onPicked: () {
                          setD(() { debutDate = DateTime.tryParse(debutCtrl.text); });
                        }),
                        _dateField(ctx, 'Date d\'Ã©chÃ©ance', echeCtrl, firstDate: debutDate),
                      ),
                      _formRow(
                        _dropdown('Statut', statut, _statutsPlan,
                          (v) => setD(() => statut = v), required: true, icon: Icons.flag_rounded),
                        const SizedBox(), // spacer
                      ),
                      _sliderInt('Avancement (%)', avancement, (v) => setD(() => avancement = v)),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: Icon(edit == null ? Icons.add_rounded : Icons.save_rounded, size: 16),
                style: FilledButton.styleFrom(backgroundColor: AppColors.marketNeutral),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final ref = source == 'Audit' ? auditCtrl.text.trim() : (sourceRef ?? '');
                  final data = {
                    'titre': titreCtrl.text.trim(), 'description': descCtrl.text.trim(),
                    'type_action': type, 'source': source, 'source_ref': ref,
                    'responsable': respCtrl.text.trim(),
                    'date_debut': debutCtrl.text.trim(), 'date_echeance': echeCtrl.text.trim(),
                    'priorite': prio, 'statut': statut, 'avancement': avancement,
                  };
                  try {
                    edit == null
                        ? await widget.api.createRoPlan(data)
                        : await widget.api.updateRoPlan(edit.id, data);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger));
                    }
                  }
                },
                label: Text(edit == null ? 'CrÃ©er' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<RoPlan>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final items = snap.data!;
        final retard = items.where((p) => p.enRetard).length;
        final txReal = items.isNotEmpty ? items.fold(0.0, (s, e) => s + e.avancement) / items.length : 0.0;
        return Column(
          children: [
            Row(
              children: [
                _badge('$retard action(s) en retard', retard > 0 ? _kDanger : _kSuccess),
                const SizedBox(width: 10),
                _badge('RÃ©alisation : ${txReal.toStringAsFixed(0)} %', txReal >= 80 ? _kSuccess : _kWarning),
                const Spacer(),
                FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add, size: 18), label: const Text('Nouveau plan')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13233E) : Colors.white,
                  border: Border.all(color: isDark ? const Color(0xFF304764) : AppTheme.border),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                child: items.isEmpty
                    ? const Center(child: Text('Aucun plan d\'action enregistrÃ©.', style: TextStyle(color: _kMuted)))
                    : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(110), 1: FlexColumnWidth(2), 2: FixedColumnWidth(130), 3: FixedColumnWidth(80), 4: FixedColumnWidth(90), 5: FixedColumnWidth(100), 6: FixedColumnWidth(80), 7: FixedColumnWidth(90)},
                          children: [
                            _tableHeader(['RÃ©fÃ©rence', 'Titre', 'Origine', 'PrioritÃ©', 'Responsable', 'Avancement', 'Statut', 'Actions']),
                            ...items.map((p) => TableRow(
                              decoration: BoxDecoration(
                                border: const Border(bottom: BorderSide(color: Color(0x11000000))),
                                color: p.enRetard ? _kDanger.withValues(alpha: 0.04) : null,
                              ),
                              children: [
                                // RÃ©fÃ©rence + date Ã©chÃ©ance
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(p.reference, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.enRetard ? _kDanger : null)),
                                        if (p.dateEcheance.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(p.dateEcheance,
                                            style: TextStyle(fontSize: 10, color: p.enRetard ? _kDanger : _kMuted,
                                              fontWeight: p.enRetard ? FontWeight.w600 : FontWeight.normal)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                _cellFlex(p.titre),
                                // Colonne Origine â€” source + rÃ©fÃ©rence source
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _sourceColor(p.source).withValues(alpha: 0.10),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: _sourceColor(p.source).withValues(alpha: 0.30)),
                                            ),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              Container(width: 5, height: 5,
                                                decoration: BoxDecoration(color: _sourceColor(p.source), shape: BoxShape.circle)),
                                              const SizedBox(width: 4),
                                              Text(p.source, style: TextStyle(color: _sourceColor(p.source),
                                                fontSize: 10, fontWeight: FontWeight.w600)),
                                            ]),
                                          ),
                                        ),
                                        if (p.sourceRef.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(p.sourceRef,
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _kMuted),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Padding(padding: const EdgeInsets.all(8), child: _badge(p.priorite, p.priorite == 'Haute' ? _kDanger : p.priorite == 'Moyenne' ? _kWarning : _kMuted))),
                                _cell(p.responsable.isEmpty ? 'â€”' : p.responsable),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(
                                          value: p.avancement / 100,
                                          backgroundColor: AppTheme.border,
                                          color: p.avancement >= 100 ? _kSuccess : _kBlue,
                                          minHeight: 5,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('${p.avancement} %', style: const TextStyle(fontSize: 10, color: _kMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Padding(padding: const EdgeInsets.all(8), child: _badge(p.statut, _planStatutColor(p.statut)))),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showForm(edit: p)),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: _kDanger),
                                        onPressed: () => _confirm(context, 'Supprimer ce plan ?', () async { await widget.api.deleteRoPlan(p.id); _reload(); }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _planStatutColor(String s) => switch (s) {
    'TerminÃ©' => _kSuccess,
    'En cours' => _kBlue,
    'A faire' => _kMuted,
    'AbandonnÃ©' => _kDanger,
    _ => _kMuted,
  };
}

// â”€â”€â”€ VIEW 9 : HISTORIQUE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HistoriqueView extends StatefulWidget {
  const _HistoriqueView({required this.api});
  final RwaApiService api;
  @override
  State<_HistoriqueView> createState() => _HistoriqueViewState();
}

class _HistoriqueViewState extends State<_HistoriqueView> {
  late Future<List<RoHistorique>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchRoHistorique();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<RoHistorique>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final items = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: _kMuted),
                const SizedBox(width: 6),
                const Text('Journal non modifiable â€” conservation 7 ans (UMOA)', style: TextStyle(fontSize: 12, color: _kMuted)),
                const Spacer(),
                _badge('${items.length} entrÃ©es', _kBlue),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13233E) : Colors.white,
                  border: Border.all(color: isDark ? const Color(0xFF304764) : AppTheme.border),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                child: items.isEmpty
                    ? const Center(child: Text('Aucun Ã©vÃ©nement enregistrÃ©.', style: TextStyle(color: _kMuted)))
                    : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(150), 1: FixedColumnWidth(90), 2: FixedColumnWidth(90), 3: FixedColumnWidth(80), 4: FixedColumnWidth(120), 5: FlexColumnWidth()},
                          children: [
                            _tableHeader(['Date', 'Menu', 'Action', 'Utilisateur', 'Ã‰lÃ©ment', 'DÃ©tail']),
                            ...items.map((h) => TableRow(
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x11000000)))),
                              children: [
                                _cell(h.dateEvenement.replaceAll('T', ' ')),
                                _cell(h.menu),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Padding(padding: const EdgeInsets.all(8), child: _badge(h.typeAction, _actionColor(h.typeAction))),
                                ),
                                _cell(h.utilisateur),
                                _cell(h.element),
                                _cellFlex(h.nouvelleValeur.isNotEmpty ? h.nouvelleValeur : h.commentaire),
                              ],
                            )),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _actionColor(String a) => switch (a) {
    'CREATE' => _kSuccess,
    'UPDATE' => _kBlue,
    'DELETE' => _kDanger,
    'EXPORT' => AppColors.prudentialSolvency,
    _ => _kMuted,
  };
}

// â”€â”€â”€ VIEW 10 : REPORTING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ReportingView extends StatefulWidget {
  const _ReportingView({required this.api});
  final RwaApiService api;
  @override
  State<_ReportingView> createState() => _ReportingViewState();
}

class _ReportingViewState extends State<_ReportingView> {
  String _periode = 'Mensuel';
  String _destinataire = 'Organe exÃ©cutif';
  bool _generating = false;
  String? _savedFileName;
  final _dateDebutCtrl = TextEditingController();
  final _dateFinCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyQuickPeriod('Mensuel');
  }

  @override
  void dispose() {
    _dateDebutCtrl.dispose();
    _dateFinCtrl.dispose();
    super.dispose();
  }

  void _applyQuickPeriod(String periode) {
    final now = DateTime.now();
    final DateTime debut;
    switch (periode) {
      case 'Trimestriel':
        final q = ((now.month - 1) ~/ 3) * 3 + 1;
        debut = DateTime(now.year, q, 1);
      case 'Semestriel':
        debut = DateTime(now.year, now.month <= 6 ? 1 : 7, 1);
      case 'Annuel':
        debut = DateTime(now.year, 1, 1);
      default:
        debut = DateTime(now.year, now.month, 1);
    }
    setState(() {
      _periode = periode;
      _dateDebutCtrl.text = debut.toIso8601String().substring(0, 10);
      _dateFinCtrl.text   = now.toIso8601String().substring(0, 10);
    });
  }

  String _fmtDisp(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }

  String get _periodeLabel {
    final d = _dateDebutCtrl.text;
    final f = _dateFinCtrl.text;
    if (d.isNotEmpty && f.isNotEmpty) return '${_fmtDisp(d)} â€” ${_fmtDisp(f)}';
    return _periode;
  }

  // â”€â”€â”€ GÃ©nÃ©ration + dialog de sauvegarde â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _generateAndSave() async {
    setState(() { _generating = true; _savedFileName = null; });
    try {
      // 1. RÃ©cupÃ©rer les donnÃ©es
      final results = await Future.wait([
        widget.api.fetchRoDashboard(),
        widget.api.fetchRoIncidents(),
        widget.api.fetchRoKri(),
        widget.api.fetchRoRisques(),
        widget.api.fetchRoControles(),
        widget.api.fetchRoPlans(),
      ]);
      final dash      = results[0] as RoDashboardData;
      final kriData   = results[2] as RoKriModuleData;
      final risques   = results[3] as List<RoRisque>;
      final controles = results[4] as List<RoControle>;
      final plans     = results[5] as List<RoPlan>;

      final debut = _dateDebutCtrl.text.isNotEmpty ? DateTime.tryParse(_dateDebutCtrl.text) : null;
      final fin   = _dateFinCtrl.text.isNotEmpty   ? DateTime.tryParse(_dateFinCtrl.text)   : null;
      final incidents = (results[1] as List<RoIncident>).where((i) {
        try {
          final d = DateTime.parse(i.dateOccurrence);
          if (debut != null && d.isBefore(debut)) return false;
          if (fin   != null && d.isAfter(fin.add(const Duration(days: 1)))) return false;
          return true;
        } catch (_) { return true; }
      }).toList();

      // 2. Construire le PDF
      final now = DateTime.now();
      final bytes = await _buildPdf(dash, incidents, kriData.kriList, risques, controles, plans, now);

      if (!mounted) return;

      // 3. Dialog de sauvegarde natif Windows
      final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final location = await getSaveLocation(
        suggestedName: 'rapport_ro_${_periode.toLowerCase()}_$ts.pdf',
        acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
      );
      if (!mounted || location == null) return;

      // 4. Enregistrer
      final saved = await saveBytesAtLocation(location, bytes, requiredExtension: '.pdf');
      if (!mounted) return;

      final fileName = saved.path.split(RegExp(r'[\\/]')).last;
      setState(() => _savedFileName = fileName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _kSuccess,
        content: Text('Rapport enregistrÃ© : $fileName'),
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _kDanger,
          content: Text('Erreur : $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // â”€â”€â”€ Construction du document PDF â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<Uint8List> _buildPdf(
    RoDashboardData dash,
    List<RoIncident> incidents,
    List<RoKriView> kris,
    List<RoRisque> risques,
    List<RoControle> controles,
    List<RoPlan> plans,
    DateTime now,
  ) async {
    final doc = pw.Document();
    const headerBg  = PdfColor.fromInt(0xFF0F2544);
    const accentBg  = PdfColor.fromInt(0xFF2563EB);
    const borderCol = PdfColor.fromInt(0xFFE5E7EB);
    const mutedCol  = PdfColor.fromInt(0xFF6B7280);

    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    const mutedStyle  = pw.TextStyle(fontSize: 8.5, color: mutedCol);
    const bodyStyle   = pw.TextStyle(fontSize: 9);
    final headerStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    pw.Widget sectionBanner(String text) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(color: headerBg, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );

    pw.Widget kpiGrid(List<(String label, String value)> items) => pw.Row(
      children: items.map((item) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderCol), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(item.$1, style: mutedStyle),
            pw.SizedBox(height: 3),
            pw.Text(item.$2, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: headerBg)),
          ]),
        ),
      )).toList(),
    );

    pw.Widget table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: headerStyle,
        headerDecoration: const pw.BoxDecoration(color: accentBg),
        cellStyle: bodyStyle,
        border: pw.TableBorder.all(color: borderCol, width: 0.4),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Rapport Risque OpÃ©rationnel -- $_periodeLabel', style: mutedStyle),
          pw.Text('$_destinataire  Â·  $dateStr', style: mutedStyle),
        ]),
      ),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Confidentiel -- Usage interne', style: mutedStyle),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: mutedStyle),
        ]),
      ),
      build: (_) => [

        // â”€â”€ COUVERTURE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(22),
          decoration: pw.BoxDecoration(color: headerBg, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RAPPORT DE RISQUE OPÃ‰RATIONNEL',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 6),
            pw.Text('PÃ©riode : $_periodeLabel  Â·  Destinataire : $_destinataire',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            pw.Text('Date de gÃ©nÃ©ration : $dateStr',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            pw.SizedBox(height: 4),
            pw.Text('Art. 313, 313.b, 313.c, 314, 545, 546 -- UMOA/BCEAO',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          ]),
        ),
        pw.SizedBox(height: 16),

        // â”€â”€ 1. SYNTHÃˆSE GÃ‰NÃ‰RALE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        sectionBanner('1. SYNTHÃˆSE GÃ‰NÃ‰RALE  '),
        kpiGrid([
          ('Exigence fonds propres (K)', AppFormatters.currency(dash.widget1.exigenceFondsPropres)),
          ('RWA risque opÃ©rationnel',    AppFormatters.currency(dash.widget1.aprRisqueOp)),
          ('Statut rÃ©glementaire',       dash.widget1.statutReglementaire),
          ('Incidents (mois)',           '${dash.widget2.totalIncidentsMois}'),
          ('Non clÃ´turÃ©s',              '${dash.widget2.incidentsNonClos}'),
          ('Actions en retard',         '${dash.widget3.actionsEnRetard}'),
        ]),
        pw.SizedBox(height: 12),

        // â”€â”€ 2. INCIDENTS ET PERTES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        sectionBanner('2. INCIDENTS ET PERTES  '),
        kpiGrid([
          ('Pertes brutes totales', AppFormatters.currency(incidents.fold(0.0, (s, i) => s + i.perteBrute))),
          ('Pertes nettes totales', AppFormatters.currency(incidents.fold(0.0, (s, i) => s + i.perteNette))),
          ('Incidents significatifs', '${incidents.where((i) => i.significatif).length}'),
        ]),
        pw.SizedBox(height: 6),
        if (incidents.isEmpty)
          pw.Text('Aucun incident enregistrÃ©.', style: mutedStyle)
        else ...[
          table(
            ['RÃ©fÃ©rence', 'Date', 'Ligne mÃ©tier', 'Perte brute', 'Perte nette', 'Statut'],
            incidents.take(15).map((i) => [
              i.reference, i.dateOccurrence, i.ligneMetier,
              AppFormatters.currency(i.perteBrute),
              AppFormatters.currency(i.perteNette),
              i.statut,
            ]).toList(),
          ),
          if (incidents.length > 15)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text('... et ${incidents.length - 15} autres incidents.', style: mutedStyle),
            ),
        ],
        pw.SizedBox(height: 12),

        // â”€â”€ 3. INDICATEURS CLÃ‰S (KRI) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        sectionBanner('3. INDICATEURS CLÃ‰S DE RISQUE  '),
        if (kris.isEmpty)
          pw.Text('Aucun KRI configurÃ©.', style: mutedStyle)
        else
          table(
            ['KRI', 'UnitÃ©', 'Seuil alerte', 'DerniÃ¨re valeur', 'DerniÃ¨re date', 'Statut'],
            kris.map((k) => [
              k.definition.nom, k.definition.unite,
              k.definition.sens == 'superieur' ? '> ${k.definition.seuilAlerte}' : '< ${k.definition.seuilAlerte}',
              k.derniereValeur != null ? '${k.derniereValeur!.toStringAsFixed(1)} ${k.definition.unite}' : 'N/A',
              k.derniereDate ?? 'N/A',
              k.statut.toUpperCase(),
            ]).toList(),
          ),
        pw.SizedBox(height: 12),

        // â”€â”€ 4. CARTOGRAPHIE DES RISQUES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        sectionBanner('4. CARTOGRAPHIE DES RISQUES  '),
        if (risques.isEmpty)
          pw.Text('Aucun risque enregistrÃ©.', style: mutedStyle)
        else
          table(
            ['Risque', 'CatÃ©gorie', 'Prob.', 'Impact', 'Niveau brut', 'Niveau rÃ©siduel'],
            risques.map((r) => [
              r.nom, r.categorie,
              '${r.probabilite}/5', '${r.impact}/5',
              r.niveauLabel, r.niveauResiduel.toStringAsFixed(1),
            ]).toList(),
          ),
        pw.SizedBox(height: 12),

        // â”€â”€ 5. CONTRÃ”LES INTERNES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        sectionBanner('5. CONTRÃ”LES INTERNES  '),
        if (controles.isNotEmpty) ...[
          kpiGrid([
            ('Total contrÃ´les', '${controles.length}'),
            ('Non conformes', '${controles.where((c) => c.resultat == 'Non-conforme').length}'),
            ('Taux moyen', '${(controles.fold(0.0, (s, c) => s + c.tauxConformite) / controles.length).toStringAsFixed(1)} %'),
          ]),
          table(
            ['RÃ©fÃ©rence', 'PÃ©rimÃ¨tre', 'Type', 'FrÃ©quence', 'Taux conf.', 'RÃ©sultat'],
            controles.map((c) => [
              c.reference, c.perimetre, c.typeControle, c.frequence,
              '${c.tauxConformite.toStringAsFixed(1)} %', c.resultat,
            ]).toList(),
          ),
        ] else
          pw.Text('Aucun contrÃ´le enregistrÃ©.', style: mutedStyle),
        pw.SizedBox(height: 12),

        // â”€â”€ 6. PLANS D'ACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        sectionBanner('6. PLANS D\'ACTIONS  '),
        if (plans.isNotEmpty) ...[
          kpiGrid([
            ('Plans total', '${plans.length}'),
            ('En retard', '${plans.where((p) => p.enRetard).length}'),
            ('RÃ©alisation moy.', '${(plans.fold(0.0, (s, p) => s + p.avancement) / plans.length).toStringAsFixed(0)} %'),
          ]),
          table(
            ['RÃ©fÃ©rence', 'Titre', 'PrioritÃ©', 'Responsable', 'Ã‰chÃ©ance', 'Avancement', 'Statut'],
            plans.map((p) => [
              p.reference,
              p.titre.length > 30 ? '${p.titre.substring(0, 28)}â€¦' : p.titre,
              p.priorite,
              p.responsable.isEmpty ? 'â€”' : p.responsable,
              p.dateEcheance.isEmpty ? 'â€”' : p.dateEcheance,
              '${p.avancement} %', p.statut,
            ]).toList(),
          ),
        ] else
          pw.Text('Aucun plan d\'action enregistrÃ©.', style: mutedStyle),
        pw.SizedBox(height: 12),

        // â”€â”€ 7. SIMULATION DE CRISE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        sectionBanner('7. SIMULATION DE CRISE  '),
        table(
          ['ScÃ©nario', 'Variation PNB', 'RWA estimÃ©', 'Exigence fonds propres'],
          [
            ['Optimiste',    '+10 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 1.10), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 1.10)],
            ['Neutre',        '0 %',  AppFormatters.currency(dash.widget1.aprRisqueOp),        AppFormatters.currency(dash.widget1.exigenceFondsPropres)],
            ['Pessimiste',   '-20 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 0.80), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 0.80)],
            ['Crise sÃ©vÃ¨re', '-35 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 0.65), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 0.65)],
          ],
        ),
        pw.SizedBox(height: 16),

        // â”€â”€ PIED â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text(
          'Rapport gÃ©nÃ©rÃ© le $dateStr -- Outil RWA -- Confidentiel',
          style: mutedStyle,
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    return doc.save();
  }

  // â”€â”€â”€ Interface â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'ParamÃ¨tres du rapport',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('PÃ©riode rapide :',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkMuted : _kMuted)),
                    const SizedBox(width: 10),
                    ...['Mensuel', 'Trimestriel', 'Semestriel', 'Annuel'].map((p) {
                      final sel = _periode == p &&
                          _dateDebutCtrl.text.isNotEmpty && _dateFinCtrl.text.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _applyQuickPeriod(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? _kBlue : _kBlue.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? _kBlue : _kBlue.withValues(alpha: 0.25)),
                            ),
                            child: Text(p, style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _kBlue,
                            )),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _reportingDateField(context, 'Date de dÃ©but', _dateDebutCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _reportingDateField(context, 'Date de fin', _dateFinCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown('Destinataire', _destinataire,
                      ['Organe exÃ©cutif', 'Organe dÃ©libÃ©rant', 'Commission Bancaire'],
                      (v) => setState(() => _destinataire = v ?? 'Organe exÃ©cutif'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Structure du rapport',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_artInfo('Art. 313.c'), const SizedBox(width: 4), _artInfo('Art. 546')],
            ),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(44),
                1: FlexColumnWidth(1.4),
                2: FlexColumnWidth(3),
                3: FixedColumnWidth(52),
              },
              children: [
                _tableHeader(['#', 'Section', 'Ã‰lÃ©ments inclus', 'RÃ©f.']),
                ...[
                  ('1', 'SynthÃ¨se gÃ©nÃ©rale',       '',           ['Exigence de fonds propres (Art. 301/307)', 'RWA risque opÃ©rationnel (Art. 89)', 'Statut de conformitÃ©', 'Ã‰volution N-1']),
                  ('2', 'Incidents et pertes',      'Art. 313.b', ['Nombre total d\'incidents', 'Pertes nettes totales', 'Top 5 incidents par perte', 'RÃ©partition par ligne de mÃ©tier']),
                  ('3', 'Indicateurs clÃ©s (KRI)',   '',           ['Tableau des KRI avec statut', 'Ã‰volutions significatives', 'Alertes et actions associÃ©es']),
                  ('4', 'Cartographie des risques', '',           ['Matrice des risques (heatmap)', 'Top 5 risques critiques', 'Ã‰volution risque rÃ©siduel']),
                  ('5', 'ContrÃ´les internes',       'Art. 314',   ['Taux de conformitÃ© global', 'ContrÃ´les non conformes', 'Plan de contrÃ´le', 'Actions correctives en cours']),
                  ('6', 'Plans d\'action',          'Art. 313.c', ['Taux de rÃ©alisation', 'Actions en retard', 'Actions terminÃ©es (pÃ©riode)']),
                  ('7', 'Simulation de crise',      'Art. 545',   ['ScÃ©nario optimiste (+10 %)', 'ScÃ©nario neutre (0 %)', 'ScÃ©nario pessimiste (-20 %)', 'ScÃ©nario crise sÃ©vÃ¨re (-35 %)']),
                  ('8', 'Annexes',                  '',           ['DÃ©tail des incidents', 'Journal des modifications', 'Glossaire']),
                ].map<TableRow>((r) => TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0x11000000))),
                  ),
                  children: [
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Center(
                          child: Container(
                            width: 24, height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _kBlue.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(r.$1,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kBlue)),
                          ),
                        ),
                      ),
                    ),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Text(r.$2,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: r.$4.map((item) {
                            final refs = _extractArtRefs(item);
                            final clean = _stripArtRefs(item);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4, height: 4,
                                    decoration: BoxDecoration(
                                      color: _kBlue.withValues(alpha: 0.40),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(clean, style: const TextStyle(fontSize: 12)),
                                  ...refs.map((ref) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: _artInfo(ref),
                                  )),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: r.$3.isNotEmpty ? _artInfo(r.$3) : const SizedBox(),
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _generating ? null : _generateAndSave,
                icon: _generating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(_generating ? 'GÃ©nÃ©ration en coursâ€¦' : 'GÃ©nÃ©rer le rapport Â· $_periodeLabel'),
              ),
              if (_savedFileName != null) ...[
                const SizedBox(width: 14),
                const Icon(Icons.check_circle_outline, size: 16, color: _kSuccess),
                const SizedBox(width: 4),
                Flexible(child: Text(_savedFileName!, style: const TextStyle(color: _kSuccess, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportingDateField(BuildContext context, String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_month_outlined, size: 12, color: _kBlue),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kMuted, letterSpacing: 0.1)),
          ]),
          const SizedBox(height: 5),
          TextFormField(
            controller: ctrl,
            readOnly: true,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'jj/mm/aaaa',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
              suffixIcon: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _kBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.calendar_month_outlined, size: 14, color: _kBlue),
              ),
            ),
            onTap: () async {
              DateTime? current;
              try { if (ctrl.text.isNotEmpty) current = DateTime.parse(ctrl.text); } catch (_) {}
              final picked = await showDatePicker(
                context: context,
                initialDate: current ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: 'SÃ©lectionner une date',
              );
              if (picked != null) setState(() => ctrl.text = picked.toIso8601String().substring(0, 10));
            },
          ),
        ],
      ),
    );
  }

}

// â”€â”€â”€ VIEW : REGISTRE DES PERTES RO (BCEAO/UMOA) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Design alignÃ© sur le Tableau des expositions (dÃ©gradÃ© navy, panel F6F9FF, KPI footer)

class _RegistreView extends StatefulWidget {
  const _RegistreView({required this.api});
  final RwaApiService api;
  @override
  State<_RegistreView> createState() => _RegistreViewState();
}

class _RegistreViewState extends State<_RegistreView> {
  late Future<List<RoIncident>> _future;
  String? _filterStatut;
  String? _filterLigne;
  String? _filterType;
  final _searchCtrl = TextEditingController();
  String _search = '';

  void _onVBody()  => _syncV(_vBodyCtrl);
  void _onVFixed() => _syncV(_vFixedCtrl);
  void _syncV(ScrollController src) {
    if (_isSyncV || !src.hasClients) return;
    _isSyncV = true;
    for (final c in [_vBodyCtrl, _vFixedCtrl]) {
      if (c == src || !c.hasClients) continue;
      final t = src.offset.clamp(c.position.minScrollExtent, c.position.maxScrollExtent);
      if ((c.offset - t).abs() > 0.5) c.jumpTo(t);
    }
    _isSyncV = false;
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.toLowerCase()));
    _vBodyCtrl.addListener(_onVBody);
    _vFixedCtrl.addListener(_onVFixed);
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hCtrl.dispose();
    _vBodyCtrl.removeListener(_onVBody);
    _vFixedCtrl.removeListener(_onVFixed);
    _vBodyCtrl.dispose();
    _vFixedCtrl.dispose();
    super.dispose();
  }

  // Cache pour le footer (mis Ã  jour quand le future se rÃ©sout)
  List<RoIncident> _cachedItems = [];

  void _reload() {
    final f = widget.api.fetchRoIncidents();
    f.then((data) { if (mounted) setState(() => _cachedItems = data); }).catchError((_) {});
    setState(() { _future = f; });
  }

  Future<void> _openImport() async {
    final ok = await showRoImportPertesDialog(context, api: widget.api);
    if (ok == true) _reload();
  }

  Future<void> _showWizard() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RoIncidentWizardDialog(api: widget.api),
    );
    if (ok == true) _reload();
  }

  Future<void> _showEditForm(RoIncident edit) async {
    final dateCtrl  = TextEditingController(text: edit.dateOccurrence);
    final descCtrl  = TextEditingController(text: edit.description);
    final brutCtrl  = TextEditingController(text: edit.perteBrute.toStringAsFixed(0));
    final recupCtrl = TextEditingController(text: edit.perteRecuperee.toStringAsFixed(0));
    String? causeRacine = _causesRacine.contains(edit.causeRacine) ? edit.causeRacine : null;
    String? ligne  = _lignesMetier.contains(edit.ligneMetier)       ? edit.ligneMetier   : _lignesMetier.first;
    String? type   = _typesEvenement.contains(edit.typeEvenement)   ? edit.typeEvenement : _typesEvenement.first;
    String? statut = _statutsIncident.contains(edit.statut)         ? edit.statut        : _statutsIncident.first;
    final formKey  = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(color: _kBlue.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.edit_outlined, color: _kBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Modifier â€” ${edit.reference}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('Mise Ã  jour conforme Art. 313.b UMOA',
                  style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w400)),
              ])),
            ]),
          ),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formSection('Identification', icon: Icons.calendar_today_rounded, color: _kBlue),
                    _formRow(
                      _dateField(ctx, 'Date d\'occurrence', dateCtrl, required: true),
                      _dropdown('Statut', statut, _statutsIncident, (v) => setD(() => statut = v),
                        required: true, icon: Icons.flag_rounded),
                    ),
                    _formSection('Classification', icon: Icons.category_rounded, color: _kWarning),
                    _formRow(
                      _dropdown('Ligne de mÃ©tier', ligne, _lignesMetier, (v) => setD(() => ligne = v),
                        required: true, icon: Icons.business_rounded),
                      _dropdown('Type d\'Ã©vÃ©nement', type, _typesEvenement, (v) => setD(() => type = v),
                        required: true, icon: Icons.label_rounded),
                    ),
                    _dropdown('Cause racine', causeRacine, _causesRacine,
                      (v) => setD(() => causeRacine = v), icon: Icons.search_rounded),
                    _formSection('Description', icon: Icons.notes_rounded),
                    _field('Description de l\'incident', descCtrl,
                      multiline: true, required: true),
                    _formSection('Impact financier', icon: Icons.monetization_on_rounded, color: _kDanger),
                    _formRow(
                      _field('Perte brute (FCFA)', brutCtrl,
                        keyboardType: TextInputType.number, required: true,
                        icon: Icons.trending_down_rounded),
                      _field('Perte rÃ©cupÃ©rÃ©e (FCFA)', recupCtrl,
                        keyboardType: TextInputType.number, icon: Icons.trending_up_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await widget.api.updateRoIncident(edit.id, {
                    'date_occurrence': dateCtrl.text.trim(),
                    'description':     descCtrl.text.trim(),
                    'ligne_metier':    ligne,
                    'type_evenement':  type,
                    'cause_racine':    causeRacine ?? '',
                    'perte_brute':     double.tryParse(brutCtrl.text)  ?? 0,
                    'perte_recuperee': double.tryParse(recupCtrl.text) ?? 0,
                    'statut':          statut,
                  });
                  if (ctx.mounted) { Navigator.pop(ctx, true); }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur : $e'), backgroundColor: _kDanger));
                  }
                }
              },
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _reload();
  }

  List<RoIncident> _apply(List<RoIncident> all) => all.where((i) {
    if (_filterStatut != null && i.statut != _filterStatut) return false;
    if (_filterLigne  != null && i.ligneMetier   != _filterLigne)  return false;
    if (_filterType   != null && i.typeEvenement != _filterType)   return false;
    if (_search.isNotEmpty) {
      final hay = '${i.reference} ${i.description} ${i.causeRacine}'.toLowerCase();
      if (!hay.contains(_search)) return false;
    }
    return true;
  }).toList();

  final _hCtrl      = ScrollController();
  final _vBodyCtrl  = ScrollController();
  final _vFixedCtrl = ScrollController();
  bool  _isSyncV    = false;

  static const _rowH = 48.0;

  static const _colLabels = [
    'RÃ©fÃ©rence', 'Date', 'Ligne de mÃ©tier', "Type d'Ã©vÃ©nement",
    'Description', 'Cause racine', 'Perte brute (FCFA)', 'RÃ©cupÃ©rÃ© (FCFA)',
    'Perte nette (FCFA)', 'Capital minimal 15 %', 'RWA (Ã—12,5)', 'Statut', 'Actions',
  ];

  static const _colW = [140.0, 110.0, 190.0, 160.0, 260.0, 190.0, 155.0, 150.0, 155.0, 160.0, 145.0, 105.0, 80.0];

  // VisibilitÃ© des colonnes
  final List<bool> _visibleCols = List.filled(13, true);
  final _colMenuCtrl = MenuController();

  // SÃ©lection de ligne
  String? _selectedId;

  int    get _visibleCount => _visibleCols.where((v) => v).length;

  // Colonnes dÃ©filantes (exclut col 0 quand elle est figÃ©e)
  List<(String, double)> get _scrollableColDefs => [
    for (int i = 1; i < _colLabels.length; i++)
      if (_visibleCols[i]) (_colLabels[i], _colW[i]),
  ];
  double get _scrollableMinW => _scrollableColDefs.fold(0.0, (s, c) => s + c.$2);

  void _resetFilters() => setState(() {
    _filterStatut = null;
    _filterLigne  = null;
    _filterType   = null;
    _searchCtrl.clear();
    _search = '';
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Footer data depuis le cache (0 pendant le chargement)
    final cached = _apply(_cachedItems);
    final cBrute = cached.fold(0.0, (s, i) => s + i.perteBrute);
    final cNette = cached.fold(0.0, (s, i) => s + i.perteNette);
    final cKro   = cNette * 0.15;
    final cApr   = cKro * 12.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // â”€â”€ Panneau de contrÃ´les â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101C32) : const Color(0xFFF6F9FF),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: isDark ? const Color(0xFF22304B) : const Color(0xFFDDE7F6), width: 0.8),
            boxShadow: [BoxShadow(color: isDark ? const Color(0x26040A16) : const Color(0x080F172A), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF14233D) : Colors.white,
                constraints: const BoxConstraints(minHeight: 32, maxHeight: 32),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 1.2)),
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _fDropLabeled('Statut',           _filterStatut, _statutsIncident, (v) => setState(() => _filterStatut = v), 100, isDark),
              const SizedBox(width: 6),
              _fDropLabeled('Ligne de mÃ©tier',  _filterLigne,  _lignesMetier,    (v) => setState(() => _filterLigne  = v), 138, isDark),
              const SizedBox(width: 6),
              _fDropLabeled("Type d'Ã©vÃ©nement", _filterType,   _typesEvenement,  (v) => setState(() => _filterType   = v), 130, isDark),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recherche',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFB8C8E8) : const Color(0xFF2563EB))),
                    const SizedBox(height: 3),
                    TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 11),
                      decoration: const InputDecoration(
                        hintText: 'RÃ©fÃ©renceâ€¦',
                        prefixIcon: Icon(Icons.search_outlined, size: 14),
                        prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(width: 34, height: 34,
                child: Tooltip(message: 'RÃ©initialiser les filtres',
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppTheme.warning,
                      backgroundColor: isDark ? const Color(0xFF13243F) : Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 1,
                      shadowColor: isDark ? const Color(0x22040A16) : const Color(0x10F59E0B),
                      side: BorderSide(color: isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    child: const Icon(Icons.restart_alt_rounded, size: 15, color: AppTheme.warning),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // â”€â”€ SÃ©lecteur de colonnes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              MenuAnchor(
                controller: _colMenuCtrl,
                alignmentOffset: const Offset(0, 4),
                style: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF14233D) : Colors.white),
                  surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isDark ? const Color(0xFF22304B) : const Color(0xFFDCE5F1)),
                    )),
                  elevation: WidgetStateProperty.all(6),
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 4)),
                  maximumSize: WidgetStateProperty.all(const Size(220, 380)),
                ),
                menuChildren: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
                    child: Row(children: [
                      Text('Colonnes visibles',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF374151))),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() {
                          final allOn = _visibleCols.every((v) => v);
                          for (int k = 0; k < _visibleCols.length; k++) {
                            _visibleCols[k] = !allOn;
                          }
                        }),
                        child: Text(
                          _visibleCols.every((v) => v) ? 'Aucune' : 'Toutes',
                          style: const TextStyle(fontSize: 11, color: AppTheme.accent,
                            fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  for (int ci = 0; ci < _colLabels.length; ci++)
                    CheckboxMenuButton(
                      value: _visibleCols[ci],
                      onChanged: (v) {
                        if (v != null) setState(() => _visibleCols[ci] = v);
                      },
                      child: Text(_colLabels[ci],
                        style: TextStyle(fontSize: 12,
                          color: isDark ? Colors.white : const Color(0xFF1F2937))),
                    ),
                ],
                child: SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: () => _colMenuCtrl.isOpen
                        ? _colMenuCtrl.close()
                        : _colMenuCtrl.open(),
                    icon: Icon(Icons.visibility_outlined, size: 14,
                      color: _visibleCount < _colLabels.length
                          ? AppTheme.accent
                          : (isDark ? const Color(0xFFDCEBFF) : const Color(0xFF374151))),
                    label: Text('Colonnes ($_visibleCount)',
                      style: TextStyle(fontSize: 11,
                        color: _visibleCount < _colLabels.length
                            ? AppTheme.accent
                            : (isDark ? const Color(0xFFDCEBFF) : const Color(0xFF374151)))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: isDark ? const Color(0xFFDCEBFF) : const Color(0xFF374151),
                      backgroundColor: isDark ? const Color(0xFF13243F) : Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 1,
                      shadowColor: isDark ? const Color(0x22040A16) : const Color(0x102563EB),
                      side: BorderSide(
                        color: _visibleCount < _colLabels.length
                            ? AppTheme.accent
                            : (isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6))),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _topBtn('Import',   Icons.file_upload_outlined,   const Color(0xFF1E88E5), _openImport, isDark),
              const SizedBox(width: 6),
              _topBtn('Exporter', Icons.file_download_outlined, const Color(0xFF14A44D),
                _cachedItems.isEmpty ? null : () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export Excel â€” Ã  implÃ©menter'))),
                isDark),
              const SizedBox(width: 10),
              SizedBox(height: 32,
                child: FilledButton.icon(
                  onPressed: _showWizard,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Ajouter'),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        // â”€â”€ Tableau â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Expanded(
          child: FutureBuilder<List<RoIncident>>(
            future: _future,
            builder: (ctx, snap) {
              if (!snap.hasData) return snap.hasError ? _errorBox(snap.error!) : _loadingBox();
              return _buildTable(ctx, _apply(snap.data!), isDark);
            },
          ),
        ),
        const SizedBox(height: 6),
        // â”€â”€ Footer KPI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 110, child: _sumCard('Pertes', '${cached.length}', AppTheme.accent,
            tooltip:
              'Nombre de pertes\n'
              'RÃ´le : comptage total des incidents\n'
              'enregistrÃ©s dans la base.\n'
              'Formule : COUNT(incidents)',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('Perte brute', AppFormatters.currency(cBrute), _kDanger,
            tooltip:
              'Perte brute totale\n'
              'RÃ´le : montant total avant toute rÃ©cupÃ©ration.\n'
              'Formule : Î£ perte_brute\n'
              '(somme de toutes les pertes brutes)',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('Perte nette', AppFormatters.currency(cNette), _kDanger,
            tooltip:
              'Perte nette totale (Art. 313.b)\n'
              'RÃ´le : montant rÃ©el supportÃ© aprÃ¨s rÃ©cupÃ©rations.\n'
              'Formule : Î£ (perte_brute âˆ’ perte_rÃ©cupÃ©rÃ©e)\n'
              'RÃ©cupÃ©rations = assurance + provisions + reversements',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('K_RO 15 % (Art. 89)', AppFormatters.currency(cKro), AppColors.prudentialSolvency,
            tooltip:
              'Exigence de fonds propres â€” Risque OpÃ©rationnel\n'
              'RÃ´le : capital rÃ©glementaire minimum Ã  dÃ©tenir.\n'
              'Formule BIA : Capital minimal = Î± Ã— Perte nette totale\n'
              'Î± = 15 %  (coefficient BCEAO/UMOA, Art. 89)',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('APR opÃ©rationnel', AppFormatters.currency(cApr), AppColors.marketNeutral,
            tooltip:
              'Actifs PondÃ©rÃ©s par le Risque opÃ©rationnel\n'
              'RÃ´le : base de calcul du ratio de solvabilitÃ©.\n'
              'Formule : RWA = Capital minimal Ã· 8 % = Capital minimal Ã— 12,5\n'
              '12,5 = facteur de conversion prudentiel (Art. 89)',
          )),
        ])),
      ],
    );
  }


  // â”€â”€ helpers UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _topBtn(String label, IconData icon, Color color, VoidCallback? onPressed, bool isDark) => SizedBox(
    height: 30,
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: onPressed != null ? color : (isDark ? const Color(0xFF1B2B47) : const Color(0xFFE8EEF8)),
        foregroundColor: onPressed != null ? Colors.white : (isDark ? const Color(0xFF6F7E96) : const Color(0xFF8A98AC)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    ),
  );

  Widget _fDropLabeled(String label, String? value, List<String> opts, ValueChanged<String?> onChange, double width, bool isDark) {
    final borderColor = isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6);
    final fillColor   = isDark ? const Color(0xFF13243F) : Colors.white;
    final labelColor  = isDark ? const Color(0xFFB8C8E8) : const Color(0xFF2563EB);
    return SizedBox(
      width: width,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? null : [
                  const BoxShadow(color: Color(0x0A2563EB), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8, top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              color: fillColor,
              child: Text(label,
                style: TextStyle(fontSize: 8.2, fontWeight: FontWeight.w600, color: labelColor, height: 1),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: value,
                  isExpanded: true,
                  isDense: true,
                  hint: Text('Tous',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF9AA8BA)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                    color: isDark ? Colors.white38 : Colors.black38),
                  dropdownColor: isDark ? const Color(0xFF14233D) : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Tous', style: TextStyle(fontSize: 12))),
                    ...opts.map((s) => DropdownMenuItem<String?>(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    )),
                  ],
                  onChanged: onChange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext ctx, List<RoIncident> items, bool isDark) {
    if (items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13233E) : Colors.white,
          border: Border.all(color: isDark ? const Color(0xFF304764) : AppTheme.border),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.table_rows_outlined, size: 48, color: _kMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          const Text('Aucune entrÃ©e dans le registre', style: TextStyle(color: _kMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Ajoutez une perte ou importez un fichier Excel', style: TextStyle(color: _kMuted, fontSize: 12)),
          const SizedBox(height: 18),
          Wrap(spacing: 10, children: [
            _topBtn('Importer Excel',   Icons.file_upload_outlined, const Color(0xFF1E88E5), _openImport,  isDark),
            _topBtn('Ajouter une perte', Icons.add,                 AppTheme.accent,         _showWizard,  isDark),
          ]),
        ])),
      );
    }

    return LayoutBuilder(builder: (_, bc) {
      final fixedVisible = _visibleCols[0];
      final fixedW       = fixedVisible ? _colW[0] : 0.0;
      final scrollColW   = _scrollableMinW;
      final availW       = (bc.maxWidth.isFinite ? bc.maxWidth : scrollColW) - fixedW;
      final scrollMinW   = math.max(scrollColW, availW > 0 ? availW : scrollColW);

      const headerStyle  = TextStyle(color: Color(0xFFF5F8FF), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.18, height: 1);
      const headerGrad   = BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A518A), Color(0xFF23477A)]),
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      );
      // â”€â”€ DonnÃ©es ligne par ligne â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      final fixedCells      = <Widget>[];
      final scrollableCells = <Widget>[];

      for (var (rowIdx, i) in items.indexed) {
        final kro        = i.perteNette * 0.15;
        final apr        = kro * 12.5;
        final isSelected = _selectedId == i.id;

        final rowBg = isSelected
            ? (isDark ? const Color(0xFF243B63) : const Color(0xFFDCEBFF))
            : (rowIdx.isEven
                ? (isDark ? const Color(0xFF111D33) : Colors.white)
                : (isDark ? const Color(0xFF16243C) : const Color(0xFFF7FAFF)));
        final rowBorderColor = isSelected
            ? (isDark ? const Color(0xFF5B7DB0) : const Color(0xFF8AB8FF))
            : (isDark ? const Color(0x14FFFFFF) : const Color(0x11000000));
        final rowDeco = BoxDecoration(
          border: Border(bottom: BorderSide(color: rowBorderColor, width: isSelected ? 1.2 : 0.7)),
        );
        final hoverColor = isSelected
            ? Colors.transparent
            : AppTheme.accent.withValues(alpha: isDark ? 0.10 : 0.05);
        void onTap() => setState(() => _selectedId = isSelected ? null : i.id);

        // Col 0 â€” colonne figÃ©e
        fixedCells.add(SizedBox(
          height: _rowH,
          child: Material(
            color: rowBg,
            child: InkWell(
              onTap: onTap,
              hoverColor: hoverColor,
              child: Container(
                decoration: rowDeco,
                alignment: Alignment.centerLeft,
                child: _rc(i.reference, _colW[0], bold: true),
              ),
            ),
          ),
        ));

        // Cols 1-12 â€” zone dÃ©filante
        final scrollCols = <Widget>[
          if (_visibleCols[1])  _rc(i.dateOccurrence,                    _colW[1]),
          if (_visibleCols[2])  _rcf(i.ligneMetier,                      _colW[2]),
          if (_visibleCols[3])  _rcf(i.typeEvenement,                    _colW[3]),
          if (_visibleCols[4])  _rcf(i.description,                      _colW[4]),
          if (_visibleCols[5])  _rcf(i.causeRacine,                      _colW[5]),
          if (_visibleCols[6])  _rc(AppFormatters.currency(i.perteBrute),     _colW[6],  right: true),
          if (_visibleCols[7])  _rc(AppFormatters.currency(i.perteRecuperee), _colW[7],  right: true, color: i.perteRecuperee > 0 ? _kSuccess : _kMuted),
          if (_visibleCols[8])  _rc(AppFormatters.currency(i.perteNette),     _colW[8],  right: true, color: i.perteNette > 0 ? _kDanger : null),
          if (_visibleCols[9])  _rc(AppFormatters.currency(kro),              _colW[9],  right: true, color: AppColors.prudentialSolvency),
          if (_visibleCols[10]) _rc(AppFormatters.currency(apr),              _colW[10], right: true, color: AppColors.marketNeutral),
          if (_visibleCols[11]) SizedBox(width: _colW[11], child: Padding(padding: const EdgeInsets.all(8), child: _badge(i.statut, _statutColor(i.statut)))),
          if (_visibleCols[12]) SizedBox(
            width: _colW[12],
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 32, height: 32, child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.edit_outlined, size: 15, color: isDark ? Colors.white54 : _kMuted),
                tooltip: 'Modifier',
                onPressed: () => _showEditForm(i),
              )),
              SizedBox(width: 32, height: 32, child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.delete_outline, size: 15, color: _kDanger),
                tooltip: 'Supprimer',
                onPressed: () => _confirm(context, 'Supprimer cet incident ?', () async {
                  await widget.api.deleteRoIncident(i.id);
                  _reload();
                }),
              )),
            ]),
          ),
        ];

        scrollableCells.add(SizedBox(
          height: _rowH,
          child: Material(
            color: rowBg,
            child: InkWell(
              onTap: onTap,
              hoverColor: hoverColor,
              child: Container(
                decoration: rowDeco,
                child: Row(children: scrollCols),
              ),
            ),
          ),
        ));
      }

      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13233E) : Colors.white,
          border: Border.all(color: isDark ? const Color(0xFF304764) : AppTheme.border),
          borderRadius: BorderRadius.circular(5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // â”€â”€ En-tÃªte â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SizedBox(
              height: 40,
              child: Row(children: [
                // Cellule d'en-tÃªte de la colonne figÃ©e
                if (fixedVisible) Container(
                  width: fixedW,
                  height: 40,
                  decoration: headerGrad.copyWith(
                    border: const Border(
                      bottom: BorderSide(color: Color(0x1AFFFFFF)),
                      right:  BorderSide(color: Color(0x33FFFFFF)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_colLabels[0], style: headerStyle, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                // En-tÃªtes dÃ©filants
                Expanded(
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _hCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(-(_hCtrl.hasClients ? _hCtrl.offset : 0.0), 0),
                        child: child,
                      ),
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 0,
                        maxWidth: double.infinity,
                        child: SizedBox(
                          width: scrollMinW,
                          child: Container(
                            height: 40,
                            decoration: headerGrad,
                            child: Row(
                              children: _scrollableColDefs.map((c) => SizedBox(
                                width: c.$2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(c.$1, style: headerStyle, overflow: TextOverflow.ellipsis),
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            // â”€â”€ Corps â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: Row(children: [
                // Colonne figÃ©e â€” dÃ©file uniquement verticalement
                if (fixedVisible) Container(
                  width: fixedW,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: isDark ? const Color(0xFF304764) : const Color(0xFFD6E0EF))),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06), blurRadius: 10, offset: const Offset(3, 0))],
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      controller: _vFixedCtrl,
                      child: Column(children: fixedCells),
                    ),
                  ),
                ),
                // Zone dÃ©filante â€” dÃ©file horizontalement et verticalement
                Expanded(
                  child: SingleChildScrollView(
                    controller: _vBodyCtrl,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hCtrl,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: scrollMinW),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: scrollableCells,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      );
    });
  }

  Widget _rc(String t, double w, {bool bold = false, bool right = false, Color? color}) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(t,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 12, color: color),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );

  Widget _rcf(String t, double w) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(t, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );

  Widget _sumCard(String label, String value, Color color, {String? tooltip}) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.11), color.withValues(alpha: 0.05)],
      ),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(label.toUpperCase(),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700,
                            letterSpacing: 0.7, height: 1.2),
                        ),
                      ),
                      if (tooltip != null) ...[
                        const SizedBox(width: 4),
                        ExcludeSemantics(
                          child: Tooltip(
                            message: tooltip,
                            preferBelow: false,
                            waitDuration: Duration.zero,
                            showDuration: const Duration(seconds: 10),
                            textStyle: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2A3A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Icon(Icons.info_outline_rounded, size: 12, color: color.withValues(alpha: 0.70)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                    child: Text(value, maxLines: 1,
                      style: TextStyle(color: color, fontSize: 15.5, fontWeight: FontWeight.w800,
                        height: 1, letterSpacing: -0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


// â”€â”€â”€ Wizard â€” DÃ©clarer un incident opÃ©rationnel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RoIncidentWizardDialog extends StatefulWidget {
  const _RoIncidentWizardDialog({required this.api});
  final RwaApiService api;

  @override
  State<_RoIncidentWizardDialog> createState() => _RoIncidentWizardDialogState();
}

class _RoIncidentWizardDialogState extends State<_RoIncidentWizardDialog> {
  int _step = 1;
  static const int _totalSteps = 4;
  bool _submitting = false;

  // Ã‰tape 1 â€” Identification
  final _dateCtrl = TextEditingController();
  String _ligne = _lignesMetier.first;
  String _type = _typesEvenement.first;

  // Ã‰tape 2 â€” Description
  final _descCtrl = TextEditingController();
  String _causeRacine = _causesRacine.first;

  // Ã‰tape 3 â€” Impact
  final _brutCtrl = TextEditingController();
  final _recupCtrl = TextEditingController();

  // Ã‰tape 4 â€” Validation
  String _statut = _statutsIncident.first;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  static const _stepLabels = ['Identification', 'Description', 'Impact', 'Validation'];
  static const _stepSubtitles = [
    'Date, ligne, type',
    'DÃ©tails et cause',
    'Pertes (FCFA)',
    'RÃ©capitulatif',
  ];
  static const _stepIcons = [
    Icons.badge_outlined,
    Icons.edit_note_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.task_alt_outlined,
  ];

  @override
  void dispose() {
    _dateCtrl.dispose();
    _descCtrl.dispose();
    _brutCtrl.dispose();
    _recupCtrl.dispose();
    super.dispose();
  }

  bool _validateCurrent() {
    return switch (_step) {
      1 => _step1Key.currentState?.validate() ?? false,
      2 => _step2Key.currentState?.validate() ?? false,
      3 => _step3Key.currentState?.validate() ?? false,
      _ => true,
    };
  }

  void _next() { if (_validateCurrent() && _step < _totalSteps) setState(() => _step++); }
  void _prev() { if (_step > 1) setState(() => _step--); }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.api.createRoIncident({
        'date_occurrence': _dateCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'ligne_metier': _ligne,
        'type_evenement': _type,
        'cause_racine': _causeRacine,
        'perte_brute': double.tryParse(_brutCtrl.text) ?? 0,
        'perte_recuperee': double.tryParse(_recupCtrl.text) ?? 0,
        'statut': _statut,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: _kDanger),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tÃªte
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.report_problem_outlined, color: _kBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DÃ©clarer un incident', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('Risque opÃ©rationnel â€” Art. 313 BCEAO', style: TextStyle(fontSize: 11, color: _kMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Indicateur d'Ã©tapes
              _buildStepBar(),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Contenu de l'Ã©tape
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_step) {
                    1 => _buildStep1(),
                    2 => _buildStep2(),
                    3 => _buildStep3(),
                    _ => _buildStep4(),
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Boutons de navigation
              _buildNavRow(),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ Indicateur d'Ã©tapes horizontal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStepBar() {
    return Row(
      children: List.generate(_totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          final done = i ~/ 2 + 1 < _step;
          return Expanded(child: Container(height: 2, color: done ? _kBlue : (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : AppTheme.border)));
        }
        final n = i ~/ 2 + 1;
        final active = n == _step;
        final done = n < _step;
        final col = active ? _kBlue : done ? _kSuccess : _kMuted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (active || done) ? col.withValues(alpha: 0.12) : (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : AppTheme.border).withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(color: col, width: active ? 2 : 1),
              ),
              child: done
                  ? const Icon(Icons.check, size: 16, color: _kSuccess)
                  : Icon(_stepIcons[i ~/ 2], size: 16, color: col),
            ),
            const SizedBox(height: 4),
            Text(
              _stepLabels[i ~/ 2],
              style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: col),
            ),
            Text(
              _stepSubtitles[i ~/ 2],
              style: const TextStyle(fontSize: 9, color: _kMuted),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }

  // â”€â”€ Ã‰tape 1 : Identification â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep1() => Form(
    key: _step1Key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizBanner(
          icon: Icons.badge_outlined,
          title: 'Identification de l\'incident',
          subtitle: 'Art. 313.b â€” DÃ©clarez dans les 5 jours ouvrÃ©s suivant la dÃ©tection',
        ),
        const SizedBox(height: 16),
        _formSection('Quand et oÃ¹ ?', icon: Icons.calendar_today_rounded, color: _kDanger),
        _dateField(context, 'Date d\'occurrence', _dateCtrl, required: true),
        _formSection('Classification', icon: Icons.category_rounded, color: _kWarning),
        _formRow(
          _dropdown('Ligne de mÃ©tier', _ligne, _lignesMetier,
            (v) { if (v != null) setState(() => _ligne = v); },
            required: true, icon: Icons.business_rounded),
          _dropdown('Type d\'Ã©vÃ©nement', _type, _typesEvenement,
            (v) { if (v != null) setState(() => _type = v); },
            required: true, icon: Icons.label_rounded),
        ),
      ],
    ),
  );

  // â”€â”€ Ã‰tape 2 : Description â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep2() => Form(
    key: _step2Key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizBanner(
          icon: Icons.edit_note_outlined,
          title: 'Description et cause racine',
          subtitle: 'DÃ©crivez prÃ©cisÃ©ment l\'incident et identifiez sa cause principale',
        ),
        const SizedBox(height: 16),
        _formSection('Que s\'est-il passÃ© ?', icon: Icons.notes_rounded, color: _kBlue),
        _field('Description de l\'incident', _descCtrl, multiline: true, required: true,
          icon: Icons.description_rounded,
          hint: 'Que s\'est-il passÃ© ? Quels systÃ¨mes / processus sont concernÃ©s ?'),
        _formSection('Analyse', icon: Icons.search_rounded, color: _kWarning),
        _dropdown('Cause racine identifiÃ©e', _causeRacine, _causesRacine,
          (v) { if (v != null) setState(() => _causeRacine = v); },
          icon: Icons.account_tree_rounded),
      ],
    ),
  );

  // â”€â”€ Ã‰tape 3 : Impact financier â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep3() => Form(
    key: _step3Key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizBanner(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Impact financier',
          subtitle: 'Art. 89 â€” Perte nette = Perte brute âˆ’ RÃ©cupÃ©rations. Saisir en FCFA.',
        ),
        const SizedBox(height: 16),
        _formSection('Montants de perte', icon: Icons.monetization_on_rounded, color: _kDanger),
        _formRow(
          _field('Perte brute (FCFA)', _brutCtrl,
            keyboardType: TextInputType.number, required: true,
            icon: Icons.trending_down_rounded,
            hint: 'Montant total avant rÃ©cupÃ©rations'),
          _field('Perte rÃ©cupÃ©rÃ©e (FCFA)', _recupCtrl,
            keyboardType: TextInputType.number,
            icon: Icons.trending_up_rounded,
            hint: 'Assurances, provisions, reversements'),
        ),
        const SizedBox(height: 4),
        // Estimation BIA temps rÃ©el
        ListenableBuilder(
          listenable: Listenable.merge([_brutCtrl, _recupCtrl]),
          builder: (_, __) {
            final brut = double.tryParse(_brutCtrl.text) ?? 0;
            final recup = double.tryParse(_recupCtrl.text) ?? 0;
            if (brut == 0) return const SizedBox.shrink();
            final nette = brut - recup;
            final kBia = nette * 0.15;
            final apr = kBia * 12.5;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBlue.withValues(alpha: 0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate_outlined, size: 13, color: _kBlue),
                      SizedBox(width: 6),
                      Text('Estimation BIA (Art. 89) â€” indicative', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _biaKpi('Perte brute', AppFormatters.currency(brut))),
                      Expanded(child: _biaKpi('Perte nette', AppFormatters.currency(nette))),
                      Expanded(child: _biaKpi('Capital minimal (15 %)', AppFormatters.currency(kBia))),
                      Expanded(child: _biaKpi('RWA estimÃ©', AppFormatters.currency(apr))),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );

  // â”€â”€ Ã‰tape 4 : RÃ©capitulatif + validation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep4() {
    final brut = double.tryParse(_brutCtrl.text) ?? 0;
    final recup = double.tryParse(_recupCtrl.text) ?? 0;
    final nette = brut - recup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizBanner(
          icon: Icons.task_alt_outlined,
          title: 'Validation finale',
          subtitle: 'VÃ©rifiez les informations avant d\'enregistrer l\'incident',
        ),
        const SizedBox(height: 16),
        // RÃ©capitulatif
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RÃ©capitulatif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _kBlue)),
              const SizedBox(height: 12),
              _recap('Date d\'occurrence', _dateCtrl.text.isEmpty ? 'â€”' : _dateCtrl.text),
              _recap('Ligne de mÃ©tier', _ligne),
              _recap('Type d\'Ã©vÃ©nement', _type),
              _recap('Cause racine', _causeRacine),
              _recap('Description', () {
                final s = _descCtrl.text.trim();
                return s.length > 90 ? '${s.substring(0, 87)}â€¦' : (s.isEmpty ? 'â€”' : s);
              }()),
              const Divider(height: 16),
              _recap('Perte brute', AppFormatters.currency(brut)),
              _recap('Perte rÃ©cupÃ©rÃ©e', AppFormatters.currency(recup)),
              _recap('Perte nette', AppFormatters.currency(nette), highlight: nette > 0),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _dropdown('Statut de l\'incident', _statut, _statutsIncident, (v) { if (v != null) setState(() => _statut = v); }, required: true),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kSuccess.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kSuccess.withValues(alpha: 0.20)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: _kSuccess),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'L\'incident sera ajoutÃ© Ã  la base de pertes et inclus dans le calcul BIA (Art. 89).',
                  style: TextStyle(fontSize: 11, color: _kSuccess),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // â”€â”€ Helpers visuels â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _wizBanner({required IconData icon, required String title, required String subtitle}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: _kBlue),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: _kMuted, height: 1.3)),
          ],
        ),
      ),
    ],
  );

  Widget _biaKpi(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: _kMuted)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue)),
    ],
  );

  Widget _recap(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 11, color: _kMuted))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? _kDanger : null,
            ),
          ),
        ),
      ],
    ),
  );

  // â”€â”€ Boutons navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildNavRow() => Row(
    children: [
      if (_step > 1)
        OutlinedButton.icon(
          onPressed: _prev,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('PrÃ©cÃ©dent'),
          style: OutlinedButton.styleFrom(foregroundColor: _kMuted, side: const BorderSide(color: _kMuted)),
        ),
      const Spacer(),
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
      const SizedBox(width: 8),
      if (_step < _totalSteps)
        FilledButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: Text('Ã‰tape suivante ($_step/$_totalSteps)'),
        )
      else
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 18),
          label: const Text('Enregistrer l\'incident'),
          style: FilledButton.styleFrom(backgroundColor: _kSuccess),
        ),
    ],
  );
}

// â”€â”€â”€ Shared visual widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RoRiskMatrix extends StatelessWidget {
  const _RoRiskMatrix({required this.risques});
  final List<RoRisque> risques;

  static Color _zoneColor(int p, int i) {
    final s = p * i;
    if (s <= 4) return _kSuccess;
    if (s <= 9) return _kWarning;
    if (s <= 16) return const Color(0xFFF97316);
    return _kDanger;
  }

  static String _zoneLabel(int p, int i) {
    final s = p * i;
    if (s <= 4) return 'Faible';
    if (s <= 9) return 'Moyen';
    if (s <= 16) return 'Ã‰levÃ©';
    return 'Critique';
  }

  List<String> _namesAt(int p, int i) =>
      risques.where((r) => r.probabilite == p && r.impact == i).map((r) => r.nom).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const cellSz = 42.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // â”€â”€ Axes + grille â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne gauche : label vertical + numÃ©ros P
            Column(children: [
              // Espace pour aligner avec le label "IMPACT â†’" + chiffres
              SizedBox(height: 34),
              // NumÃ©ros P (5 â†’ 1, top â†’ bottom)
              ...List.generate(5, (pi) {
                final p = 5 - pi;
                return SizedBox(
                  height: cellSz + 3,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (pi == 2)
                      RotatedBox(quarterTurns: -1,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('PROBABILITÃ‰ â†‘',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                              color: _kMuted, letterSpacing: 0.7)),
                        ))
                    else
                      const SizedBox(width: 60),
                    Text('$p',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted)),
                  ]),
                );
              }),
            ]),
            const SizedBox(width: 6),
            // Colonne droite : axe Impact (haut) + grille
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Axe Impact
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('IMPACT â†’',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700,
                      color: _kMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Row(children: List.generate(5, (i) => SizedBox(
                    width: cellSz + 3,
                    child: Text('${i + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted)),
                  ))),
                ]),
                const SizedBox(height: 4),
                // Grille 5Ã—5
                ...List.generate(5, (pi) {
                  final p = 5 - pi;
                  return Row(
                    children: List.generate(5, (ii) {
                      final impact = ii + 1;
                      final names = _namesAt(p, impact);
                      final cnt   = names.length;
                      final c     = _zoneColor(p, impact);
                      final zl    = _zoneLabel(p, impact);
                      final score = p * impact;

                      return ExcludeSemantics(
                        child: Tooltip(
                        key: ValueKey('matrix_${p}_$impact'),
                        message: cnt == 0
                            ? 'P=$p Ã— I=$impact = $score ($zl)\nAucun risque positionnÃ© ici'
                            : 'P=$p Ã— I=$impact = $score ($zl)\n${names.join('\n')}',
                        waitDuration: const Duration(milliseconds: 300),
                        showDuration: const Duration(seconds: 6),
                        textStyle: const TextStyle(fontSize: 11, color: Colors.white, height: 1.55),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2A3A),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Container(
                          width: cellSz,
                          height: cellSz,
                          margin: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                c.withValues(alpha: isDark ? 0.38 : 0.20),
                                c.withValues(alpha: isDark ? 0.20 : 0.09),
                              ],
                            ),
                            border: Border.all(
                              color: cnt > 0 ? c.withValues(alpha: 0.75) : c.withValues(alpha: 0.30),
                              width: cnt > 0 ? 1.5 : 0.8,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: cnt > 0
                                ? [BoxShadow(color: c.withValues(alpha: 0.18), blurRadius: 5)]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: cnt > 0
                              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text('$cnt',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: cnt > 9 ? 13 : 17,
                                      color: c, height: 1.0)),
                                  Text('risque${cnt > 1 ? 's' : ''}',
                                    style: TextStyle(fontSize: 7,
                                      color: c.withValues(alpha: 0.72),
                                      fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                                ])
                              : Text('$score',
                                  style: TextStyle(fontSize: 10,
                                    color: c.withValues(alpha: isDark ? 0.40 : 0.25),
                                    fontWeight: FontWeight.w700)),
                        ),
                      ),
                      );
                    }),
                  );
                }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        // â”€â”€ LÃ©gende â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Wrap(spacing: 10, runSpacing: 6, children: [
          _legendItem('Faible â‰¤4', _kSuccess),
          _legendItem('Moyen 5â€“9', _kWarning),
          _legendItem('Ã‰levÃ© 10â€“16', const Color(0xFFF97316)),
          _legendItem('Critique >16', _kDanger),
        ]),
        if (risques.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
            ),
            child: const Row(children: [
              Icon(Icons.touch_app_rounded, size: 11, color: _kBlue),
              SizedBox(width: 5),
              Text('Survolez une cellule pour voir les risques',
                style: TextStyle(fontSize: 10, color: _kMuted)),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _legendItem(String label, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: c.withValues(alpha: 0.55)),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _kMuted)),
    ],
  );
}

class _RoPieChart extends StatelessWidget {
  const _RoPieChart({required this.items});
  final List<RoRepartitionItem> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0, (s, e) => s + e.valeur);
    if (total == 0) return const SizedBox();
    final palette = [_kBlue, _kSuccess, _kWarning, _kDanger, AppColors.prudentialSolvency, AppColors.marketNeutral, const Color(0xFFF97316), const Color(0xFF84CC16)];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sorted = items.asMap().entries.toList()
      ..sort((a, b) => b.value.valeur.compareTo(a.value.valeur));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: sorted.map((entry) {
          final c = palette[entry.key % palette.length];
          final pct = total > 0 ? entry.value.valeur / total : 0.0;
          final pctStr = (pct * 100).toStringAsFixed(1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        entry.value.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkText : AppTheme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pctStr %',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                        height: 9,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? c.withValues(alpha: 0.14) : c.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [c.withValues(alpha: 0.75), c],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RoLineChartPainter extends CustomPainter {
  const _RoLineChartPainter({required this.dataBlue, required this.dataGreen, required this.labels});
  final List<double> dataBlue;
  final List<double> dataGreen;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataBlue.isEmpty) return;
    const padL = 48.0, padB = 28.0, padT = 12.0, padR = 8.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final all = [...dataBlue, ...dataGreen];
    final maxV = all.reduce(math.max);
    if (maxV == 0) return;

    final gridPaint = Paint()..color = const Color(0x22000000)..strokeWidth = 0.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = padT + h - (i / gridLines) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
      final val = (maxV * i / gridLines).round();
      textPainter.text = TextSpan(text: val >= 1000000 ? '${(val / 1000000).toStringAsFixed(1)}M' : '$val', style: const TextStyle(color: _kMuted, fontSize: 8));
      textPainter.layout();
      textPainter.paint(canvas, Offset(padL - textPainter.width - 4, y - textPainter.height / 2));
    }

    void drawLine(List<double> data, Color color) {
      if (data.isEmpty) return;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = padL + (i / (data.length - 1)) * w;
        final y = padT + h - (data[i] / maxV) * h;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }

    drawLine(dataBlue, _kBlue);
    drawLine(dataGreen, _kSuccess);

    final step = labels.length > 1 ? w / (labels.length - 1) : w;
    for (var i = 0; i < labels.length; i++) {
      if (i % 3 != 0) continue;
      textPainter.text = TextSpan(text: labels[i], style: const TextStyle(color: _kMuted, fontSize: 8));
      textPainter.layout();
      textPainter.paint(canvas, Offset(padL + i * step - textPainter.width / 2, padT + h + 6));
    }

    // LÃ©gende
    canvas.drawLine(const Offset(padL, padT - 4), const Offset(padL + 20, padT - 4), Paint()..color = _kBlue..strokeWidth = 2);
    textPainter.text = const TextSpan(text: 'Brute', style: TextStyle(color: _kMuted, fontSize: 8));
    textPainter.layout();
    textPainter.paint(canvas, const Offset(padL + 24, padT - 8));
    canvas.drawLine(const Offset(padL + 60, padT - 4), const Offset(padL + 80, padT - 4), Paint()..color = _kSuccess..strokeWidth = 2);
    textPainter.text = const TextSpan(text: 'Nette', style: TextStyle(color: _kMuted, fontSize: 8));
    textPainter.layout();
    textPainter.paint(canvas, const Offset(padL + 84, padT - 8));
  }

  @override
  bool shouldRepaint(covariant _RoLineChartPainter old) => old.dataBlue != dataBlue;
}

// â”€â”€â”€ Table helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

TableRow _tableHeader(List<String> headers) {
  return TableRow(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF2A518A), Color(0xFF23477A)],
      ),
      border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
    ),
    children: headers.map((h) => TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Text(h,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10,
            color: Color(0xFFF5F8FF), letterSpacing: 0.18)),
      ),
    )).toList(),
  );
}

TableCell _cell(String text, {bool bold = false, bool right = false, Color? color}) => TableCell(
  verticalAlignment: TableCellVerticalAlignment.middle,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontSize: 12,
        color: color,
        letterSpacing: bold ? 0.1 : 0,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  ),
);

TableCell _cellFlex(String text) => TableCell(
  verticalAlignment: TableCellVerticalAlignment.middle,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Text(text, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
  ),
);
