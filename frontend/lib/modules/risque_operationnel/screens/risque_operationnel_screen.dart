// Ecran principal du module Risque Opérationnel — 10 vues.
import 'dart:async';
import 'dart:math' as math;

import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:excel/excel.dart' as xl show Border, BorderStyle;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/ro_models.dart';
import '../widgets/ro_import_pertes_dialog.dart';
import '../widgets/uemoi_aib_screen.dart';
import '../widgets/uemoi_as_screen.dart';
import '../widgets/uemoi_synthese_screen.dart';

// ─── Enum vues ────────────────────────────────────────────────────────────────

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

// ─── Constantes ───────────────────────────────────────────────────────────────

const _kBlue = AppTheme.accent;
const _kSuccess = AppTheme.success;
const _kWarning = AppTheme.warning;
const _kDanger = AppTheme.danger;
const _kMuted = AppTheme.muted;

/// Formate un montant FCFA avec la même unité (M / Md) que le sélecteur
/// global du Dashboard Crédit (en haut à droite de l'application) : l'unité
/// n'est pas déduite automatiquement, elle suit le choix de l'utilisateur.
String _roAmount(BuildContext context, double value) {
  final unit = PortfolioAmountUnitScope.maybeOf(context);
  final sign = value < 0 ? '-' : '';
  final scaled = value.abs() / unit.divisor;
  return '$sign${AppFormatters.decimalNumber(scaled, maxDecimals: 2)} ${unit.label}';
}

/// Formate un pourcentage avec 1 décimale, sauf si celle-ci est un 0 : dans ce
/// cas on repasse à 2 décimales pour ne pas masquer une petite valeur non nulle
/// (ex. "0.0 %" devient "0.04 %").
String _roPct(double value) {
  final oneDecimal = value.toStringAsFixed(1);
  if (oneDecimal.endsWith('.0')) {
    return value.toStringAsFixed(2);
  }
  return oneDecimal;
}

/// Formate un nombre avec au plus [maxDecimals] décimales, en supprimant les
/// zéros de fin superflus (ex. 14.0000 -> "14", 2.2500 -> "2.25").
String _roTrim(double value, {int maxDecimals = 4}) {
  var s = value.toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Assombrit une couleur de statut trop claire (ex. l'orange d'alerte) pour
/// que les chiffres des cartes du dashboard restent bien lisibles sur fond
/// clair — la teinte est conservée, seule la luminosité est réduite.
Color _roReadable(Color c) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.lightness <= 0.5) return c;
  return hsl.withLightness(0.34).toColor();
}

const _lignesMetier = [
  "Financement d'entreprise",
  'Activités de marché',
  'Banque de détail',
  'Banque commerciale',
  'Paiements et règlements',
  "Fonctions d'agent",
  "Gestion d'actifs",
  'Courtage de détail',
];
const _typesEvenement = ['Interne', 'Externe', 'Processus', 'Système', 'Personnel', 'Juridique'];
const _statutsIncident = ['Ouvert', 'En cours', 'Résolu', 'Clôturé'];
const _causesRacine = [
  'Erreur humaine',
  'Défaillance système',
  'Processus inadéquat',
  'Fraude interne',
  'Fraude externe',
  'Événement externe',
  'Non définie',
];
const _categoriesRisque = ['Processus', 'Personnel', 'Système', 'Externe', 'Juridique'];
const _typesControle = ['Permanent', 'Périodique', 'Ponctuel', 'Sur pièces', 'Sur place'];
const _frequences = ['Mensuel', 'Trimestriel', 'Semestriel', 'Annuel'];
const _typesAction = ['Corrective', 'Préventive', 'Améliorative'];
const _sourcesAction = ['Incident', 'Contrôle', 'KRI', 'Audit', 'Cartographie'];
const _manualKriIds = ['kri-01', 'kri-02', 'kri-03', 'kri-07'];
const _priorites = ['Haute', 'Moyenne', 'Basse'];
const _statutsPlan = ['A faire', 'En cours', 'Terminé', 'Abandonné'];

// ─── Articles réglementaires ──────────────────────────────────────────────────

const _artExplanations = <String, String>{
  'Art. 313':
      'Gestion du risque opérationnel — dispositif d\'identification, de mesure,\n'
      'de surveillance et de contrôle obligatoire (Instruction UMOA).\n\n'
      'Mesure du risque (matrice 5×5) :\n'
      '  Score = Impact × Probabilité   (échelle 1 – 5)\n'
      '  Zone rouge : Score ≥ 15   |   Zone orange : 8 – 14\n'
      '  Piliers : Identification → Mesure → Surveillance → Contrôle',
  'Art. 313.b':
      'Déclaration des incidents opérationnels — tout incident significatif\n'
      'doit être documenté (cause racine, pertes) avec suivi formel imposé.\n\n'
      'Calcul de la perte nette :\n'
      '  Perte nette = Perte brute − Récupérations\n'
      '  Récupérations : assurance + provisions + reversements\n'
      '  Délai de déclaration : ≤ J+5 ouvrés après détection',
  'Art. 313.c':
      'Plans d\'actions correctives et préventives — documentés, assignés\n'
      'à un responsable avec échéance et taux d\'avancement obligatoires.\n\n'
      'Indicateurs de suivi :\n'
      '  Avancement (%) = (Actions terminées / Actions totales) × 100\n'
      '  Taux global = Σ avancement_i / n   (n = nb plans actifs)\n'
      '  Retard = Date_échéance − Date_aujourd\'hui  < 0 → en retard',
  'Art. 314':
      'Contrôle interne — dispositif permanent et périodique obligatoire.\n'
      'Conservation des documents : ≥ 7 ans (exigence UMOA).\n\n'
      'Efficacité du contrôle :\n'
      '  Taux de conformité = (Contrôles conformes / Contrôles réalisés) × 100\n'
      '  Couverture = Nb processus contrôlés / Nb processus totaux × 100\n'
      '  Fréquences : permanent (quotidien/hebdo) | périodique (mensuel/annuel)',
  'Art. 89':
      'Calcul des RWA opérationnels — méthode Indicateur de Base (BIA).\n\n'
      'Formule BIA :\n'
      '  Capital minimal = α × PNBmoy₃\n'
      '  α = 15 %   (coefficient réglementaire BCEAO)\n'
      '  PNBmoy₃ = Σ PNBᵢ (positifs) / n   sur 3 derniers exercices\n'
      '  RWA_opérationnel = Capital minimal ÷ 8 %   (facteur 12,5)',
  'Art. 301/307':
      'Exigences minimales en fonds propres (dispositif prudentiel BCEAO).\n\n'
      'Ratios réglementaires :\n'
      '  Ratio Tier 1 = Fonds propres de base / RWA total  ≥ 5 %\n'
      '  Ratio global = Fonds propres totaux / RWA total   ≥ 8 %\n'
      '  RWA total = RWA_crédit + RWA_marché + RWA_opérationnel\n'
      '  Coussin de conservation : + 2,5 % des RWA (si applicable)',
  'Art. 545':
      'Stress testing — simulations de scénarios de crise pour évaluer\n'
      'la résilience du dispositif de gestion des risques.\n\n'
      'Scénarios types et formule d\'impact :\n'
      '  S1 : Optimiste  |  S2 : Neutre  |  S3 : Pessimiste  |  S4 : Crise\n'
      '  Impact net = Pertes simulées − (Provisions + Couverture assurance)\n'
      '  Résilience = Fonds propres disponibles − Pertes simulées  ≥ 0\n'
      '  Ratio de résistance = FP après choc / RWA stressés  ≥ seuil',
  'Art. 546':
      'Rapport annuel sur le dispositif de gestion des risques opérationnels,\n'
      'transmis à la Commission Bancaire de l\'UMOA.\n\n'
      'Indicateurs clés à reporter :\n'
      '  • RWA opérationnel = K_BIA × 12,5   (avec K_BIA = 15 % × PNBmoy₃)\n'
      '  • Pertes totales nettes = Σ (Perte brute − Récupérations)\n'
      '  • Taux couverture plans = Actions terminées / Total plans × 100\n'
      '  • Résultats stress tests : ΔFP sous S3 et S4',
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
      excludeFromSemantics: true,
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

// ─── Ecran principal ──────────────────────────────────────────────────────────

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
    return ExcludeSemantics(
      child: switch (view) {
        OperationalRiskView.dashboard    => _DashboardView(api: api, titleOnlyHeader: true, initialTab: 1),
        OperationalRiskView.registre     => _RegistreView(api: api),
        OperationalRiskView.incidents    => _SimulationCriseView(api: api),
        OperationalRiskView.pertes       => _PertesView(api: api),
        OperationalRiskView.historique   => _HistoriqueView(api: api),
        OperationalRiskView.reporting    => _ReportingView(api: api),
        OperationalRiskView.kri          => _RoPageWrapper(
          title: 'KRI',
          subtitle: 'Indicateurs clés de risque — surveillance continue (Art. 313)',
          artRef: 'Art. 313',
          child: _KriView(api: api),
        ),
        OperationalRiskView.cartographie => _RoPageWrapper(
          title: 'Cartographie des risques',
          subtitle: 'Identification et évaluation — matrice 5×5 (Art. 313)',
          artRef: 'Art. 313',
          child: _CartographieView(api: api),
        ),
        OperationalRiskView.controles    => _RoPageWrapper(
          title: 'Contrôles internes',
          subtitle: 'Gestion des contrôles périodiques (Art. 314)',
          artRef: 'Art. 314',
          child: _ControlesView(api: api),
        ),
        OperationalRiskView.workflow     => _RoPageWrapper(
          title: 'Workflow incidents',
          subtitle: 'Pipeline de traitement des incidents (Art. 313.b)',
          artRef: 'Art. 313.b',
          child: _WorkflowView(api: api),
        ),
        OperationalRiskView.plans        => _RoPageWrapper(
          title: "Plans d'actions",
          subtitle: 'Actions correctives et préventives (Art. 313.c)',
          artRef: 'Art. 313.c',
          child: _PlansView(api: api),
        ),
      },
    );
  }
}

// ─── Wrapper de page pour les vues réutilisées en sous-onglet ────────────────

class _RoPageWrapper extends StatelessWidget {
  const _RoPageWrapper({
    required this.title,
    required this.subtitle,
    required this.artRef,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String artRef;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: title,
            subtitle: subtitle,
            titleFontSize: 26,
            subtitleFontSize: 12.5,
            subtitleSuffix: _artInfo(artRef),
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Helpers partagés ─────────────────────────────────────────────────────────

Color _statutColor(String statut) => switch (statut) {
      'Ouvert' => _kDanger,
      'En cours' => _kWarning,
      'Résolu' => AppColors.marketNeutral,
      'Clôturé' => _kSuccess,
      _ => _kMuted,
    };

Color _niveauColor(String label) => switch (label) {
      'Faible' => _kSuccess,
      'Moyen' => _kWarning,
      'Élevé' => const Color(0xFFF97316),
      'Critique' => _kDanger,
      _ => _kMuted,
    };

// ignore: unused_element
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

String _kriExplication(String kriId) => switch (kriId) {
      'kri-01' => 'Nécessite les données RH : nombre de départs volontaires et effectif moyen de la période.',
      'kri-02' => "Nécessite les données RH : jours d'absence et jours travaillés théoriques du personnel.",
      'kri-03' => 'Nécessite le registre de formation : heures de formation par collaborateur sur la période.',
      'kri-07' => "Nécessite les résultats d'enquête de satisfaction client (notes et nombre de répondants).",
      _ => 'Données source non disponibles dans le système pour ce calcul automatique.',
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

// ─── Form helpers ─────────────────────────────────────────────────────────────

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

// Deux champs côte à côte
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
              helpText: 'Sélectionner une date',
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


// ─── VIEW 1 : DASHBOARD ───────────────────────────────────────────────────────

class _DashboardView extends StatefulWidget {
  const _DashboardView({
    required this.api,
    this.showHeader = true,
    this.showTabs = false,
    this.titleOnlyHeader = false,
    this.initialTab = 0,
  });
  final RwaApiService api;
  final bool showHeader;
  final bool showTabs;
  final bool titleOnlyHeader;
  final int initialTab;
  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late Future<RoDashboardData> _future;
  late DateTime _analysisDate;
  late int _selectedTab;

  static const _tabDefs = [
    (Icons.dashboard_outlined, 'Dashboard Opérationnel'),
    (Icons.compare_arrows_outlined, 'Dashboard CCR 3 operationel'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _analysisDate = DateUtils.dateOnly(DateTime.now());
    _future = widget.api.fetchRoDashboard();
  }

  void _refresh() {
    setState(() {
      _future = widget.api.fetchRoDashboard();
    });
  }

  Future<void> _pickAnalysisDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _analysisDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: "Choisir la date d'analyse",
    );

    if (picked == null) {
      return;
    }

    setState(() => _analysisDate = DateUtils.dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F5);

    return DecoratedBox(
      decoration: BoxDecoration(color: _roDashboardBackgroundFor(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            widget.titleOnlyHeader
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1E36) : Colors.white,
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Text(
                      'Dashboard Opérationnel',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F1B2D),
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : _RoDashboardHeader(
                    analysisDate: _analysisDate,
                    onPickAnalysisDate: _pickAnalysisDate,
                    onRefresh: _refresh,
                  ),
          if (widget.showTabs)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1E36) : Colors.white,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabDefs.length, (i) {
                    final isSelected = _selectedTab == i;
                    final fgColor = isSelected
                        ? AppColors.accent
                        : (isDark ? const Color(0xFF9FB0CE) : const Color(0xFF234A84));
                    return InkWell(
                      onTap: () => setState(() => _selectedTab = i),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected ? AppColors.accent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_tabDefs[i].$1, size: 16, color: fgColor),
                            const SizedBox(width: 8),
                            Text(
                              _tabDefs[i].$2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: fgColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          Expanded(
            child: _selectedTab == 0
                ? FutureBuilder<RoDashboardData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return _loadingBox();
                if (snap.hasError) return _errorBox(snap.error!);
                final d = snap.data!;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Builder(
                        builder: (context) {
                          final evo = d.widget2.evolutionPertesPct;
                          final evoStr = evo != null
                              ? '${evo >= 0 ? '+' : ''}${evo.toStringAsFixed(1)} %'
                              : 'N/A';
                          final evoColor =
                              evo == null ? _kMuted : (evo > 0 ? _kDanger : _kSuccess);

                          final monitoringCards = <Widget>[
                            _RoHeroStatCard(
                              label: 'Non clôturés',
                              value: '${d.widget2.incidentsNonClos}',
                              valueColor: _kWarning,
                              subtitle: 'Incidents ouverts à traiter',
                            ),
                            _RoHeroStatCard(
                              label: 'Évolution N-1',
                              value: evoStr,
                              valueColor: evoColor,
                              subtitle: 'Pertes vs même période N-1',
                            ),
                            _RoHeroStatCard(
                              label: 'Actions en retard',
                              value: '${d.widget3.actionsEnRetard}',
                              valueColor: d.widget3.actionsEnRetard > 0 ? _kDanger : _kSuccess,
                              subtitle: "Plans d'action non clôturés",
                            ),
                            _RoHeroStatCard(
                              label: 'Contrôles non conformes',
                              value: '${d.widget3.controlesNonConformes}',
                              valueColor:
                                  d.widget3.controlesNonConformes > 0 ? _kWarning : _kSuccess,
                              subtitle: 'Dernier cycle de contrôle',
                            ),
                          ];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _RoDashSummaryRow(data: d),
                              const SizedBox(height: 16),
                              if (isWide)
                                Row(
                                  children: [
                                    for (var i = 0; i < monitoringCards.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 12),
                                      Expanded(child: monitoringCards[i]),
                                    ],
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: monitoringCards[0]),
                                        const SizedBox(width: 12),
                                        Expanded(child: monitoringCards[1]),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: monitoringCards[2]),
                                        const SizedBox(width: 12),
                                        Expanded(child: monitoringCards[3]),
                                      ],
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              _IncidentsDashSection(data: d, isWide: isWide),
                            ],
                          );
                        },
                      ),
                    );
                  },
                );
              },
            )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: _Ccr3TabView(api: widget.api, isDark: isDark, onlyAnalyseRapide: true),
                  ),
          ),
        ],
      ),
    );
  }
}

Color _roDashboardBackgroundFor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0B1220)
      : const Color(0xFFF6F7F9);
}

class _RoDashboardHeader extends StatelessWidget {
  const _RoDashboardHeader({
    required this.analysisDate,
    required this.onPickAnalysisDate,
    required this.onRefresh,
  });

  final DateTime analysisDate;
  final VoidCallback onPickAnalysisDate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border, width: Dash.hairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dashboard Opérationnel',
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Tooltip(
            excludeFromSemantics: true,
            message: 'Dashboard Opérationnel — Art. 313 & 89 UMOA\n\n'
                'Capital minimum = 15 % × PNB moyen positif (BIA — Art. 89)\n'
                'RWA = Capital minimum × 12,5 (facteur prudentiel)\n'
                'Statut : Conforme si les seuils prudentiels sont respectés',
            preferBelow: false,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(fontSize: 12, color: Colors.white, height: 1.5),
            padding: const EdgeInsets.all(14),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Icon(Icons.info_outline_rounded, size: 17, color: c.muted),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            excludeFromSemantics: true,
            message: 'Date d\'analyse',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPickAnalysisDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 15, color: c.muted),
                      const SizedBox(width: 8),
                      Text(
                        AppFormatters.shortDate(analysisDate),
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: Dash.tabular,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.expand_more, size: 16, color: c.faint),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoDashboardIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onTap: onRefresh,
            colors: c,
          ),
        ],
      ),
    );
  }
}

class _RoDashboardIconButton extends StatelessWidget {
  const _RoDashboardIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final DashColors colors;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      excludeFromSemantics: true,
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Icon(icon, size: 17, color: colors.muted),
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard — barre de KPI épinglée ───────────────────────────────────────

class _RoDashSummaryItem extends StatefulWidget {
  const _RoDashSummaryItem({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.icon,
  });
  final String label, value;
  final Color accentColor;
  final IconData icon;
  @override
  State<_RoDashSummaryItem> createState() => _RoDashSummaryItemState();
}

class _RoDashSummaryItemState extends State<_RoDashSummaryItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },

      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered ? c.surfaceAlt : c.surface,
          borderRadius: BorderRadius.circular(Dash.radius),
          border: Border.all(
            color: _hovered ? widget.accentColor.withValues(alpha: 0.45) : c.border,
            width: Dash.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 15, color: widget.accentColor),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.value,
              style: DashText.hero(
                c,
                size: 18,
                color: widget.accentColor == _kSuccess ||
                        widget.accentColor == _kWarning ||
                        widget.accentColor == _kDanger
                    ? widget.accentColor
                    : c.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: DashText.caption(c, color: c.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoDashSummaryRow extends StatelessWidget {
  const _RoDashSummaryRow({required this.data});
  final RoDashboardData data;

  @override
  Widget build(BuildContext context) {
    final statutColor = data.widget1.statutReglementaire == 'Conforme' ? _kSuccess : _kDanger;

    final items = <({String label, String value, Color color, String subtitle})>[
      (
        label: 'Capital minimum (Art. 89)',
        value: _roAmount(context, data.widget1.exigenceFondsPropres),
        color: _kBlue,
        subtitle: '15 % × PNB moyen positif (BIA)',
      ),
      (
        label: 'RWA opérationnel',
        value: _roAmount(context, data.widget1.aprRisqueOp),
        color: AppColors.prudentialSolvency,
        subtitle: 'Capital minimum × 12,5',
      ),
      (
        label: 'Statut réglementaire',
        value: data.widget1.statutReglementaire,
        color: statutColor,
        subtitle: 'Conforme si seuils respectés',
      ),
      (
        label: 'Incidents (mois)',
        value: '${data.widget2.totalIncidentsMois}',
        color: _kWarning,
        subtitle: "Nombre d'incidents déclarés",
      ),
      (
        label: 'Pertes nettes (mois)',
        value: _roAmount(context, data.widget2.pertesNettesMois),
        color: _kDanger,
        subtitle: 'Perte brute - Récupérations',
      ),
      (
        label: 'KRI hors seuil',
        value: '${data.widget3.kriHorsSeuil}',
        color: data.widget3.kriHorsSeuil > 0 ? _kDanger : _kSuccess,
        subtitle: "Indicateurs en zone d'alerte",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 6
            : constraints.maxWidth >= 760
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 130,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _RoHeroStatCard(
              label: item.label,
              value: item.value,
              valueColor: item.color,
              subtitle: item.subtitle,
            );
          },
        );
      },
    );
  }
}

// ─── Carte KPI « hero » (style aligné sur le Dashboard Crédit) ───────────────

class _RoHeroStatCard extends StatefulWidget {
  const _RoHeroStatCard({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  @override
  State<_RoHeroStatCard> createState() => _RoHeroStatCardState();
}

class _RoHeroStatCardState extends State<_RoHeroStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 130,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Dash.radius),
          border: Border.all(
            color: _hovered ? Colors.indigo.shade300 : c.border,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: DashText.eyebrow(c, color: Colors.indigo).copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Divider(color: c.border, thickness: Dash.hairline, height: 1),
            const SizedBox(height: 10),
            Text(
              widget.value,
              style: DashText.hero(c, size: 19,
                  color: widget.valueColor != null ? _roReadable(widget.valueColor!) : c.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const Spacer(),
              Text(
                widget.subtitle!,
                style: DashText.caption(c, color: c.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── VIEW 2 : SIMULATION DE CRISE — Art. 545 PIEAFP ─────────────────────────

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
  bool   _simulated  = false;

  static const _sc = [
    ('S1', 'Optimiste',    0.90, Color(0xFF43A047)),
    ('S2', 'Neutre',       1.00, Color(0xFF1E88E5)),
    ('S3', 'Pessimiste',   1.20, Color(0xFFFB8C00)),
    ('S4', 'Crise sévère', 1.35, Color(0xFFE53935)),
  ];

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchRoIncidents();
    for (final c in [_fpCtrl, _aprCtrl, _provCtrl, _assurCtrl]) {
      c.addListener(_onFieldChanged);
    }
    // Pré-remplir provisions depuis les incidents RO
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
    // Pré-remplir fonds propres et RWA depuis le dashboard
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

  _CriseScResult _compute((String, String, double, Color) sc, double pertesHisto) {
    final (code, label, factor, color) = sc;
    final fp    = _d(_fpCtrl)    ?? 0;
    final apr   = _d(_aprCtrl)   ?? 0;
    final prov  = _d(_provCtrl)  ?? 0;
    final assur = _d(_assurCtrl) ?? 0;
    final seuil = _seuilValue / 100;
    final pertesSimulees = pertesHisto * factor;
    final impactNet      = pertesSimulees - prov - assur;
    final fpApresChoc    = fp - (impactNet > 0 ? impactNet : 0);
    final resilience     = fp - pertesSimulees;
    final aprStresses    = apr > 0 ? apr * factor : 0.0;
    final ratio          = aprStresses > 0 ? fpApresChoc / aprStresses : 0.0;
    final pass           = resilience >= 0 && (apr == 0 || ratio >= seuil);
    return _CriseScResult(
      code: code, label: label, factor: factor, color: color,
      pertesSimulees: pertesSimulees, impactNet: impactNet,
      fpApresChoc: fpApresChoc, resilience: resilience,
      aprStresses: aprStresses, ratio: ratio, seuil: seuil, pass: pass,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final panelBorder = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Simulation de crise',
            subtitle: 'Stress testing PIEAFP — scénarios de vulnérabilité (Art. 545)',
            titleFontSize: 26,
            subtitleFontSize: 12.5,
            subtitleSuffix: _artInfo('Art. 545'),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<RoIncident>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) return _loadingBox();
                if (snap.hasError) return _errorBox(snap.error!);
                final items       = snap.data!;
                final pertesHisto = items.fold(0.0, (s, i) => s + i.perteNette);
                final results     = _sc.map((s) => _compute(s, pertesHisto)).toList();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Panneau gauche : paramètres ───────────────────────────
                    Container(
                      width: 284,
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: panelBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête panneau
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.07),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: panelBorder)),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF1565C0)),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Paramètres',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                              _badge('Art. 545', const Color(0xFF1565C0)),
                            ]),
                          ),
                          // Champs
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _pSection('Base historique', Icons.history_rounded, _kBlue),
                                  const SizedBox(height: 8),
                                  _pInfoRow('Incidents', '${items.length}', Icons.warning_amber_rounded, _kWarning),
                                  const SizedBox(height: 4),
                                  _pInfoRow('Pertes nettes', AppFormatters.currency(pertesHisto), Icons.trending_down_rounded, _kDanger),
                                  const SizedBox(height: 16),
                                  _pSection('Capital & RWA', Icons.account_balance_rounded, const Color(0xFF1565C0)),
                                  const SizedBox(height: 8),
                                  _pField('Fonds propres (FCFA)', Icons.savings_rounded, _fpCtrl),
                                  const SizedBox(height: 8),
                                  _pField('RWA de référence (FCFA)', Icons.bar_chart_rounded, _aprCtrl),
                                  const SizedBox(height: 16),
                                  _pSection('Atténuants', Icons.shield_rounded, _kSuccess),
                                  const SizedBox(height: 8),
                                  _pField('Provisions (FCFA)', Icons.savings_outlined, _provCtrl),
                                  const SizedBox(height: 8),
                                  _pField('Assurance (FCFA)', Icons.health_and_safety_outlined, _assurCtrl),
                                  const SizedBox(height: 16),
                                  _pSection('Seuil de résistance', Icons.speed_rounded, _kWarning),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Text('Ratio cible', style: TextStyle(fontSize: 11, color: _kMuted)),
                                    const Spacer(),
                                    Text('${_seuilValue.toStringAsFixed(1)} %',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kMuted)),
                                  ]),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    ),
                                    child: Slider(
                                      value: _seuilValue,
                                      min: 4.0, max: 25.0, divisions: 210,
                                      activeColor: _kMuted,
                                      inactiveColor: _kMuted.withValues(alpha: 0.22),
                                      onChanged: (v) => setState(() { _seuilValue = v; _simulated = true; }),
                                    ),
                                  ),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('4 %',          style: TextStyle(fontSize: 10, color: _kMuted)),
                                      Text('BCEAO : 8 %',  style: TextStyle(fontSize: 10, color: _kMuted)),
                                      Text('25 %',         style: TextStyle(fontSize: 10, color: _kMuted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // ── Panneau droit : résultats ─────────────────────────────
                    Expanded(
                      child: _simulated
                        ? _CriseResultsPanel(results: results, seuil: _seuilValue, isDark: isDark)
                        : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.science_outlined, size: 64, color: _kMuted.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            const Text('Saisissez au moins un paramètre\npour lancer la simulation',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _kMuted, fontSize: 14, height: 1.5)),
                            const SizedBox(height: 6),
                            const Text('Les résultats s\'affichent automatiquement',
                              style: TextStyle(color: _kMuted, fontSize: 11)),
                          ])),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pSection(String title, IconData icon, Color _) => Row(children: [
    Icon(icon, size: 12, color: _kMuted),
    const SizedBox(width: 6),
    Text(title.toUpperCase(),
      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5)),
  ]);

  Widget _pInfoRow(String label, String value, IconData icon, Color _) => Row(children: [
    Icon(icon, size: 13, color: _kMuted),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 11, color: _kMuted)),
    const Spacer(),
    Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted)),
  ]);

  Widget _pField(String label, IconData icon, TextEditingController ctrl) => TextFormField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))],
    style: const TextStyle(fontSize: 12),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 15, color: _kMuted),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      labelStyle: const TextStyle(fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    ),
    onChanged: (_) => setState(() {}),
  );
}

// ─── Simulation de Crise — data model ─────────────────────────────────────────

class _CriseScResult {
  const _CriseScResult({
    required this.code, required this.label, required this.factor, required this.color,
    required this.pertesSimulees, required this.impactNet, required this.fpApresChoc,
    required this.resilience, required this.aprStresses, required this.ratio,
    required this.seuil, required this.pass,
  });
  final String code;
  final String label;
  final double factor;
  final Color  color;
  final double pertesSimulees;
  final double impactNet;
  final double fpApresChoc;
  final double resilience;
  final double aprStresses;
  final double ratio;
  final double seuil;
  final bool   pass;

  String get factorLabel => factor == 1.0 ? 'Base ±0 %'
      : factor < 1.0 ? '−${((1 - factor) * 100).round()} % pertes'
                      : '+${((factor - 1) * 100).round()} % pertes';
}

// ─── Panneau résultats ────────────────────────────────────────────────────────

class _CriseResultsPanel extends StatelessWidget {
  const _CriseResultsPanel({required this.results, required this.seuil, required this.isDark});
  final List<_CriseScResult> results;
  final double seuil;
  final bool   isDark;

  @override
  Widget build(BuildContext context) {
    final passCount = results.where((r) => r.pass).length;
    final allPass   = passCount == results.length;
    final nonePass  = passCount == 0;
    final statusColor = allPass ? _kSuccess : nonePass ? _kDanger : _kWarning;
    final statusIcon  = allPass ? Icons.verified_rounded
        : nonePass ? Icons.dangerous_rounded : Icons.warning_amber_rounded;
    final statusText  = allPass
        ? 'Profil résilient — tous les scénarios sont couverts'
        : nonePass
            ? 'Profil vulnérable — aucun scénario n\'est couvert'
            : '$passCount / ${results.length} scénarios couverts — exposition partielle';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bannière statut global ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(statusText,
              style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            Row(children: List.generate(results.length, (i) => Container(
              margin: const EdgeInsets.only(left: 4),
              width: 11, height: 11,
              decoration: BoxDecoration(
                color: i < passCount ? _kSuccess : _kDanger,
                shape: BoxShape.circle,
              ),
            ))),
          ]),
        ),
        const SizedBox(height: 12),

        // ── 4 cartes scénarios ────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: results.asMap().entries.map((e) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: e.key < results.length - 1 ? 10 : 0),
                child: _CriseScenarioCard(result: e.value, isDark: isDark),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Carte scénario ───────────────────────────────────────────────────────────

class _CriseScenarioCard extends StatelessWidget {
  const _CriseScenarioCard({required this.result, required this.isDark});
  final _CriseScResult result;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final r        = result;
    final cardBg   = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final border   = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);
    final ratioOk  = r.aprStresses > 0 ? r.ratio >= r.seuil : true;
    final ratioStr = r.aprStresses > 0 ? '${(r.ratio * 100).toStringAsFixed(1)} %' : '—';
    final ratioProgress = r.aprStresses > 0
        ? (r.ratio / (r.seuil * 1.5)).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(
          color: r.color.withValues(alpha: 0.08),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête neutre
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14233D) : const Color(0xFFF5F7FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _kMuted, borderRadius: BorderRadius.circular(4)),
                  child: Text(r.code,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 7),
                Expanded(child: Text(r.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87))),
              ]),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3455) : const Color(0xFFE8EBF0),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(r.factorLabel,
                  style: const TextStyle(fontSize: 9.5, color: _kMuted, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          // Verdict
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              Icon(
                r.pass ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: r.pass ? _kSuccess : _kDanger,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(r.pass ? 'RÉSILIENT' : 'VULNÉRABLE',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: r.pass ? _kSuccess : _kDanger,
                  letterSpacing: 0.4,
                )),
            ]),
          ),

          // Ratio gauge
          if (r.aprStresses > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Ratio résistance', style: TextStyle(fontSize: 9, color: _kMuted)),
                  const Spacer(),
                  Text(ratioStr,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: ratioOk ? _kSuccess : _kDanger)),
                  Text(' / ${(r.seuil * 100).toStringAsFixed(1)} %',
                    style: const TextStyle(fontSize: 9, color: _kMuted)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratioProgress,
                    minHeight: 5,
                    backgroundColor: isDark ? const Color(0xFF1E3455) : const Color(0xFFE8F0FE),
                    color: ratioOk ? _kSuccess : _kDanger,
                  ),
                ),
              ]),
            ),

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5),

          // KPIs
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _kpiRow('Pertes simulées', AppFormatters.currency(r.pertesSimulees),
                    isDark ? Colors.white : Colors.black87),
                  _kpiRow('Impact net', AppFormatters.currency(r.impactNet),
                    isDark ? Colors.white : Colors.black87),
                  _kpiRow('FP après choc', AppFormatters.currency(r.fpApresChoc),
                    isDark ? Colors.white : Colors.black87),
                  _kpiRow('Résilience nette', AppFormatters.currency(r.resilience),
                    isDark ? Colors.white : Colors.black87),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(String label, String value, Color color) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(fontSize: 9.5, color: _kMuted))),
    Text(value, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
  ]);
}

// ─── Tableau comparatif (supprimé de l'affichage, conservé désactivé) ────────

// ignore: unused_element
class _CriseComparisonTable extends StatelessWidget {
  const _CriseComparisonTable({required this.results, required this.seuil, required this.isDark});
  final List<_CriseScResult> results;
  final double seuil;
  final bool   isDark;

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final hdrBg  = isDark ? const Color(0xFF0D1826) : const Color(0xFFF0F4FA);
    final border = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);

    const cols = [
      ('Scénario',         1),
      ('Choc',             1),
      ('Pertes simulées',  2),
      ('Impact net',       2),
      ('FP après choc',    2),
      ('Résilience',       2),
      ('Ratio',            1),
      ('Statut',           1),
    ];

    Widget hCell(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _kMuted)),
    );

    Widget dCell(String text, Color color) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
        overflow: TextOverflow.ellipsis),
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // En-têtes
        Container(
          decoration: BoxDecoration(
            color: hdrBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(children: cols.map((c) =>
            Expanded(flex: c.$2, child: hCell(c.$1))).toList()),
        ),
        // Lignes
        ...results.map((r) {
          final ratioStr = r.aprStresses > 0
              ? '${(r.ratio * 100).toStringAsFixed(1)} %' : '—';
          final ratioColor = r.aprStresses > 0
              ? (r.ratio >= seuil ? _kSuccess : _kDanger) : _kMuted;

          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.5))),
            ),
            child: Row(children: [
              // Scénario
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(children: [
                  Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: r.color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Expanded(child: Text('${r.code} ${r.label}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                ]),
              )),
              // Choc
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: r.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(r.factorLabel,
                    style: TextStyle(fontSize: 9, color: r.color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                ),
              )),
              Expanded(flex: 2, child: dCell(AppFormatters.currency(r.pertesSimulees),
                r.factor > 1 ? _kDanger : _kSuccess)),
              Expanded(flex: 2, child: dCell(AppFormatters.currency(r.impactNet),
                r.impactNet > 0 ? _kDanger : _kSuccess)),
              Expanded(flex: 2, child: dCell(AppFormatters.currency(r.fpApresChoc),
                r.fpApresChoc >= 0 ? _kSuccess : _kDanger)),
              Expanded(flex: 2, child: dCell(AppFormatters.currency(r.resilience),
                r.resilience >= 0 ? _kSuccess : _kDanger)),
              Expanded(child: dCell(ratioStr, ratioColor)),
              // Statut badge
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: (r.pass ? _kSuccess : _kDanger).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(r.pass ? '✓ OK' : '✗ KO',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
                      color: r.pass ? _kSuccess : _kDanger),
                    textAlign: TextAlign.center),
                ),
              )),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─── VIEW 3 : PERTES (conteneur avec onglets) ─────────────────────────────────

class _PertesView extends StatefulWidget {
  const _PertesView({required this.api});
  final RwaApiService api;
  @override
  State<_PertesView> createState() => _PertesViewState();
}

class _PertesViewState extends State<_PertesView> {
  int _mainSection = 0;
  int _selectedTab = 0;

  static const _tabDefs = [
    (Icons.monetization_on_outlined,       'Pertes'),
    (Icons.speed_rounded,                  'KRI'),
    (Icons.map_outlined,                   'Cartographie'),
    (Icons.verified_user_outlined,         'Contrôles internes'),
    (Icons.account_tree_outlined,          'Workflow'),
    (Icons.format_list_bulleted_rounded,   "Plans d'actions"),
  ];

  Widget _buildCurrentTab() {
    switch (_selectedTab) {
      case 0: return _PertesContent(api: widget.api);
      case 1: return _KriView(api: widget.api);
      case 2: return _CartographieView(api: widget.api);
      case 3: return _ControlesView(api: widget.api);
      case 4: return _WorkflowView(api: widget.api);
      case 5: return _PlansView(api: widget.api);
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F5);

    const sectionDefs = [
      (Icons.monetization_on_rounded, 'Pertes opérationnelles'),
      (Icons.analytics_outlined, 'Vue UEMOA'),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sélecteur de section ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
            ),
            child: Row(
              children: List.generate(sectionDefs.length, (i) {
                final isSelected = _mainSection == i;
                final fg = isSelected
                    ? AppColors.accent
                    : (isDark ? const Color(0xFF9FB0CE) : const Color(0xFF6B7FA8));
                return InkWell(
                  onTap: () => setState(() => _mainSection = i),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: isSelected ? AppColors.accent : Colors.transparent,
                        width: 3,
                      )),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sectionDefs[i].$1, size: 18, color: fg),
                        const SizedBox(width: 8),
                        Text(
                          sectionDefs[i].$2,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _mainSection == 0
                ? _buildPertesSection(isDark, borderColor)
                : _DashboardView(api: widget.api, showHeader: false, showTabs: false),
          ),
        ],
      ),
    );
  }

  Widget _buildPertesSection(bool isDark, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Base de pertes historiques — calcul RWA BIA (Art. 89)',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF9FB0CE) : const Color(0xFF6B7FA8),
                ),
              ),
            ),
            _artInfo('Art. 89'),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabDefs.length, (i) {
                final isSelected = _selectedTab == i;
                final fgColor = isSelected
                    ? AppColors.accent
                    : (isDark ? const Color(0xFF9FB0CE) : const Color(0xFF234A84));
                return InkWell(
                  onTap: () => setState(() => _selectedTab = i),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: isSelected ? AppColors.accent : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_tabDefs[i].$1, size: 16, color: fgColor),
                        const SizedBox(width: 8),
                        Text(
                          _tabDefs[i].$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: fgColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _buildCurrentTab()),
      ],
    );
  }
}

// ─── Analyse & Reporting (ancienne version, remplacée par _DashboardView) ─────
// ignore: unused_element
class _AnalyseReportingTab extends StatefulWidget {
  const _AnalyseReportingTab({required this.api});
  final RwaApiService api;
  @override
  State<_AnalyseReportingTab> createState() => _AnalyseReportingTabState();
}

class _AnalyseReportingTabState extends State<_AnalyseReportingTab> {
  late Future<List<RoIncident>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchRoIncidents();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<RoIncident>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final items = snap.data!;

        final totalBrute = items.fold(0.0, (s, e) => s + e.perteBrute);
        final totalNette = items.fold(0.0, (s, e) => s + e.perteNette);
        final totalRecup = items.fold(0.0, (s, e) => s + e.perteRecuperee);
        final tauxRecup = totalBrute > 0 ? (totalRecup / totalBrute * 100) : 0.0;
        final capitalBia = totalNette * 0.15;
        final significatifs = items.where((e) => e.significatif).length;

        final byType = <String, double>{};
        final byLigne = <String, double>{};
        for (final i in items) {
          byType[i.typeEvenement] = (byType[i.typeEvenement] ?? 0) + i.perteNette;
          byLigne[i.ligneMetier] = (byLigne[i.ligneMetier] ?? 0) + i.perteNette;
        }
        final sortedType = byType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final sortedLigne = byLigne.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top10 = ([...items]..sort((a, b) => b.perteNette.compareTo(a.perteNette)))
            .take(10).toList();

        final textColor = isDark ? const Color(0xFFCDD8F0) : const Color(0xFF1A2B4A);
        final mutedColor = isDark ? const Color(0xFF9FB0CE) : const Color(0xFF6B7FA8);

        final kpiCards = [
          _RoHeroStatCard(
            label: 'Capital RWA BIA',
            value: AppFormatters.currency(capitalBia),
            subtitle: '15 % × pertes nettes (Art. 89)',
            valueColor: _kBlue,
          ),
          _RoHeroStatCard(
            label: 'Taux de récupération',
            value: '${tauxRecup.toStringAsFixed(1)} %',
            subtitle: AppFormatters.currency(totalRecup),
            valueColor: _kSuccess,
          ),
          _RoHeroStatCard(
            label: 'Incidents enregistrés',
            value: '${items.length}',
            subtitle: '$significatifs significatifs',
            valueColor: _kWarning,
          ),
          _RoHeroStatCard(
            label: 'Perte nette totale',
            value: AppFormatters.currency(totalNette),
            subtitle: 'Brute : ${AppFormatters.currency(totalBrute)}',
            valueColor: _kDanger,
          ),
        ];

        final typeCard = SectionCard(
          title: 'Répartition par type d\'événement',
          child: Column(
            children: sortedType.map((e) {
              final pct = totalNette > 0 ? e.value / totalNette : 0.0;
              return _ArBar(
                label: e.key,
                value: AppFormatters.currency(e.value),
                pct: pct,
                color: _kBlue,
                textColor: textColor,
                mutedColor: mutedColor,
                isDark: isDark,
              );
            }).toList(),
          ),
        );

        final ligneCard = SectionCard(
          title: 'Répartition par ligne de métier',
          child: Column(
            children: sortedLigne.map((e) {
              final pct = totalNette > 0 ? e.value / totalNette : 0.0;
              return _ArBar(
                label: e.key,
                value: AppFormatters.currency(e.value),
                pct: pct,
                color: _kSuccess,
                textColor: textColor,
                mutedColor: mutedColor,
                isDark: isDark,
              );
            }).toList(),
          ),
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── KPIs ──
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        for (var i = 0; i < kpiCards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          kpiCards[i],
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < kpiCards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: kpiCards[i]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Répartitions ──
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 780) {
                    return Column(
                      children: [
                        typeCard,
                        const SizedBox(height: 12),
                        ligneCard,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: typeCard),
                      const SizedBox(width: 12),
                      Expanded(child: ligneCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Top 10 incidents ──
              SectionCard(
                title: 'Top 10 incidents — perte nette',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth =
                        constraints.maxWidth > 760 ? constraints.maxWidth : 760.0;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: tableWidth),
                        child: Column(
                          children: [
                            // header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(children: [
                                SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w600))),
                                Expanded(child: Text('Référence', style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w600))),
                                SizedBox(width: 120, child: Text('Type', style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w600))),
                                SizedBox(width: 140, child: Text('Ligne de métier', style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w600))),
                                SizedBox(width: 130, child: Text('Perte nette', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w600))),
                              ]),
                            ),
                            const Divider(height: 1),
                            ...List.generate(top10.length, (idx) {
                              final inc = top10[idx];
                              final bg = idx.isEven
                                  ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.transparent)
                                  : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF7F9FC));
                              return Container(
                                color: bg,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(children: [
                                  SizedBox(
                                    width: 32,
                                    child: Container(
                                      width: 22, height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _kBlue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: _kBlue, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                  Expanded(child: Text(inc.reference, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500))),
                                  SizedBox(width: 120, child: Text(inc.typeEvenement, style: TextStyle(fontSize: 11, color: mutedColor))),
                                  SizedBox(width: 140, child: Text(inc.ligneMetier, style: TextStyle(fontSize: 11, color: mutedColor), overflow: TextOverflow.ellipsis)),
                                  SizedBox(
                                    width: 130,
                                    child: Text(
                                      AppFormatters.currency(inc.perteNette),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 12, color: _kDanger, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ]),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArBar extends StatelessWidget {
  const _ArBar({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
  });

  final String label;
  final String value;
  final double pct;
  final Color color;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: textColor))),
              Text('${(pct * 100).toStringAsFixed(1)} %', style: TextStyle(fontSize: 11, color: mutedColor)),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: isDark ? const Color(0xFF263856) : const Color(0xFFEDF1F8),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contenu Pertes ───────────────────────────────────────────────────────────

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
        final byLigneCount = <String, int>{};
        final byType  = <String, double>{};
        for (final i in items) {
          byLigne[i.ligneMetier]  = (byLigne[i.ligneMetier]  ?? 0) + i.perteNette;
          byLigneCount[i.ligneMetier] = (byLigneCount[i.ligneMetier] ?? 0) + 1;
          byType[i.typeEvenement] = (byType[i.typeEvenement] ?? 0) + i.perteNette;
        }
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PertesSummaryBar(
                totalBrute: totalBrute,
                totalNette: totalNette,
                tauxRecup: tauxRecup,
                significatifs: significatifs,
                moyenne: moyenne,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top 5 ─────────────────────────────────────────────────
                  Expanded(
                    flex: 5,
                    child: _PertesTop5Card(
                      top5: top5,
                      totalNette: totalNette,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // ── Lignes de métier ──────────────────────────────────────
                  Expanded(
                    flex: 5,
                    child: _PertesLigneCard(
                      byLigne: byLigne,
                      byLigneCount: byLigneCount,
                      totalNette: totalNette,
                      isDark: isDark,
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

// ─── Point pulsant surveillance auto ─────────────────────────────────────────

class _AutoPulseDot extends StatefulWidget {
  const _AutoPulseDot({required this.active});
  final bool active;

  @override
  State<_AutoPulseDot> createState() => _AutoPulseDotState();
}

class _AutoPulseDotState extends State<_AutoPulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: _kMuted.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Top 5 incidents ─────────────────────────────────────────────────────────

class _PertesTop5Card extends StatelessWidget {
  const _PertesTop5Card({required this.top5, required this.totalNette, required this.isDark});
  final List<RoIncident> top5;
  final double totalNette;
  final bool isDark;

  static const _rankColors = [
    Color(0xFFFFB300), // or
    Color(0xFF90A4AE), // argent
    Color(0xFFBF8C5A), // bronze
    Color(0xFF5C6BC0),
    Color(0xFF42A5F5),
  ];

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final border = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);
    final maxPerte = top5.isNotEmpty ? top5.first.perteNette : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(
                color: _kDanger, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Expanded(child: Text('Top 5 — Incidents par perte nette',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              if (top5.isEmpty)
                const Text('Aucun incident', style: TextStyle(fontSize: 11, color: _kMuted))
              else
                _badge('${top5.length} incidents', _kDanger),
            ]),
          ),
          // Corps
          if (top5.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucun incident enregistré.', style: TextStyle(color: _kMuted))),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: top5.asMap().entries.map((e) {
                  final rank = e.key;
                  final i    = e.value;
                  final rc   = _rankColors[rank];
                  final prog = maxPerte > 0 ? (i.perteNette / maxPerte).clamp(0.0, 1.0) : 0.0;
                  final pct  = totalNette > 0 ? (i.perteNette / totalNette * 100) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Rang
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: rc.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: rc.withValues(alpha: 0.35)),
                            ),
                            alignment: Alignment.center,
                            child: Text('${rank + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: rc)),
                          ),
                          const SizedBox(width: 10),
                          // Référence + description
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(i.reference,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87)),
                                const SizedBox(width: 6),
                                Flexible(child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _kWarning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(i.typeEvenement,
                                    style: const TextStyle(fontSize: 9, color: _kWarning, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                                )),
                              ]),
                              const SizedBox(height: 2),
                              Text(i.description,
                                style: const TextStyle(fontSize: 10.5, color: _kMuted),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          )),
                          const SizedBox(width: 10),
                          // Montant + %
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(AppFormatters.currency(i.perteNette),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _kDanger)),
                            Text('${pct.toStringAsFixed(1)} % du total',
                              style: const TextStyle(fontSize: 9.5, color: _kMuted)),
                          ]),
                        ]),
                        const SizedBox(height: 6),
                        // Barre de progression relative
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(children: [
                            Container(height: 5, color: isDark
                                ? rc.withValues(alpha: 0.12) : rc.withValues(alpha: 0.08)),
                            FractionallySizedBox(
                              widthFactor: prog,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [rc.withValues(alpha: 0.7), rc]),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        if (rank < top5.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Divider(height: 1, thickness: 0.5,
                              color: border.withValues(alpha: 0.5)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Pertes par ligne de métier ───────────────────────────────────────────────

class _PertesLigneCard extends StatelessWidget {
  const _PertesLigneCard({
    required this.byLigne, required this.byLigneCount,
    required this.totalNette, required this.isDark,
  });
  final Map<String, double> byLigne;
  final Map<String, int>    byLigneCount;
  final double totalNette;
  final bool   isDark;

  static const _palette = [
    Color(0xFF00BCD4), Color(0xFF4CAF50), Color(0xFF673AB7),
    Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFFE91E63),
    Color(0xFFF97316), Color(0xFF84CC16),
  ];

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final border = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);

    final sorted = byLigne.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(
                color: _kBlue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Expanded(child: Text('Pertes par ligne de métier',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Text(AppFormatters.currency(totalNette),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kDanger)),
            ]),
          ),
          // Corps
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucune donnée.', style: TextStyle(color: _kMuted))),
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: sorted.asMap().entries.map((e) {
                  final idx   = e.key;
                  final ligne = e.value.key;
                  final montant = e.value.value;
                  final count = byLigneCount[ligne] ?? 0;
                  final pct   = totalNette > 0 ? (montant / totalNette) : 0.0;
                  final c     = _palette[idx % _palette.length];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 9, height: 9,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ligne,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87),
                            overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          // Nb incidents
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('$count incident${count > 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          // Montant
                          Text(AppFormatters.currency(montant),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
                          const SizedBox(width: 8),
                          // %
                          SizedBox(
                            width: 42,
                            child: Text('${(pct * 100).toStringAsFixed(1)} %',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(children: [
                            Container(height: 10,
                              color: isDark ? c.withValues(alpha: 0.12) : c.withValues(alpha: 0.09)),
                            FractionallySizedBox(
                              widthFactor: pct.clamp(0.0, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [c.withValues(alpha: 0.75), c]),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Barre KPI Pertes (style Dashboard) ──────────────────────────────────────

class _PertesSummaryBar extends StatelessWidget {
  const _PertesSummaryBar({
    required this.totalBrute,
    required this.totalNette,
    required this.tauxRecup,
    required this.significatifs,
    required this.moyenne,
  });
  final double totalBrute, totalNette, tauxRecup, moyenne;
  final int significatifs;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, Color color, String subtitle})>[
      (
        label: 'Perte brute totale',
        value: AppFormatters.currency(totalBrute),
        color: _kDanger,
        subtitle: 'Exposition totale avant atténuation',
      ),
      (
        label: 'Perte nette totale',
        value: AppFormatters.currency(totalNette),
        color: _kDanger,
        subtitle: 'Brute − récupérée (base calcul BIA)',
      ),
      (
        label: 'Taux de récupération',
        value: '${tauxRecup.toStringAsFixed(1)} %',
        color: _kSuccess,
        subtitle: 'Récupérée / brute × 100',
      ),
      (
        label: 'Pertes significatives',
        value: '$significatifs',
        color: _kWarning,
        subtitle: 'Incidents dépassant le seuil',
      ),
      (
        label: 'Perte moy. / incident',
        value: AppFormatters.currency(moyenne),
        color: _kMuted,
        subtitle: "Nette / nombre d'incidents",
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Synthèse des pertes opérationnelles',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kMuted),
              ),
            ),
            Tooltip(
              excludeFromSemantics: true,
              message: 'Pertes opérationnelles — Art. 313.b & 89 UMOA\n\n'
                  'Perte brute : Σ perte_brute (exposition totale avant atténuation)\n'
                  'Perte nette : Σ (perte_brute − perte_récupérée) — base calcul BIA\n'
                  'Taux récup. : (Σ récupérée / Σ brute) × 100\n'
                  'Significatives : incidents dépassant le seuil de significativité\n'
                  'Moy./incident : Σ perte_nette / nombre d\'incidents',
              preferBelow: false,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(fontSize: 12, color: Colors.white, height: 1.5),
              padding: const EdgeInsets.all(14),
              child: const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.accent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 5
                : constraints.maxWidth >= 560
                    ? 3
                    : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 130,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _RoHeroStatCard(
                  label: item.label,
                  value: item.value,
                  valueColor: item.color,
                  subtitle: item.subtitle,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─── VIEW 4 : KRI ─────────────────────────────────────────────────────────────

int _extractKriNum(String nom) {
  final m = RegExp(r'(\d+)').firstMatch(nom);
  return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
}

class _KriView extends StatefulWidget {
  const _KriView({required this.api});
  final RwaApiService api;
  @override
  State<_KriView> createState() => _KriViewState();
}

class _KriViewState extends State<_KriView> {
  late Future<RoKriModuleData> _future;
  String? _filterStatus;

  // ── Surveillance automatique ──────────────────────────────────────────────
  Timer?      _autoTimer;
  DateTime?   _lastAutoRefresh;
  bool        _autoRunning = false;
  // Statuts enregistrés lors du dernier cycle pour détecter les franchissements
  final Map<String, String> _prevStatuts = {};

  @override
  void initState() {
    super.initState();
    _reload();
    // Lance un premier calcul auto dès l'ouverture, puis toutes les 30 s
    _triggerAutoCalc();
    _autoTimer = Timer.periodic(const Duration(seconds: 30), (_) => _triggerAutoCalc());
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _reload() => setState(() { _future = widget.api.fetchRoKri(); });

  Future<void> _triggerAutoCalc() async {
    if (!mounted) return;
    setState(() => _autoRunning = true);
    try {
      final data = await widget.api.autoCalculKri();
      if (!mounted) return;
      _detectBreaches(data);
      setState(() {
        _future = Future.value(data);
        _lastAutoRefresh = DateTime.now();
        _autoRunning = false;
      });
    } catch (_) {
      if (mounted) setState(() => _autoRunning = false);
    }
  }

  double? _parseNumber(String text) {
    if (text.trim().isEmpty) return null;
    final normalized = text.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  double? _computeManualKriValue(String kriId, double valueA, double valueB) {
    if (valueB == 0) return null;
    return switch (kriId) {
      'kri-01' => valueA / valueB * 100,
      'kri-02' => valueA / valueB * 100,
      'kri-03' => valueA / valueB,
      'kri-07' => valueA / valueB * 100,
      _ => null,
    };
  }

  String _manualKriField1Label(String kriId) => switch (kriId) {
    'kri-01' => 'Départs volontaires',
    'kri-02' => 'Jours d’absence',
    'kri-03' => 'Total heures de formation',
    'kri-07' => 'Notes ≥ 4',
    _ => 'Valeur 1',
  };

  String _manualKriField2Label(String kriId) => switch (kriId) {
    'kri-01' => 'Effectif moyen',
    'kri-02' => 'Jours travaillés théoriques',
    'kri-03' => 'Effectif total',
    'kri-07' => 'Total réponses',
    _ => 'Valeur 2',
  };

  String _manualKriResultUnit(String kriId) => switch (kriId) {
    'kri-03' => 'Heures / employé',
    _ => '%',
  };

  String _manualKriExplanation(String kriId) => switch (kriId) {
    'kri-01' => 'Turnover = départs volontaires / effectif moyen × 100',
    'kri-02' => 'Taux d’absence = jours d’absence / jours travaillés théoriques × 100',
    'kri-03' => 'Heures formation par employé = total heures formation / effectif total',
    'kri-07' => 'Taux de satisfaction = notes ≥ 4 / total réponses × 100',
    _ => '',
  };

  Future<void> _showKriEntryDialog(List<RoKriView> availableKris) async {
    if (availableKris.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    String selectedKriId = availableKris.first.definition.id;
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final commentaireCtrl = TextEditingController();
    final fieldAController = TextEditingController();
    final fieldBController = TextEditingController();
    double? computedValue;

    void updateComputed() {
      final a = _parseNumber(fieldAController.text);
      final b = _parseNumber(fieldBController.text);
      if (a != null && b != null) {
        computedValue = _computeManualKriValue(selectedKriId, a, b);
      } else {
        computedValue = null;
      }
    }

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) {
          final selectedName = availableKris
              .firstWhere((k) => k.definition.id == selectedKriId)
              .definition
              .nom;
          final unit = _manualKriResultUnit(selectedKriId);
          return AlertDialog(
            title: const Text('Saisie des données KRI'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedKriId,
                    decoration: const InputDecoration(labelText: 'Indicateur', isDense: true),
                    items: availableKris.map((k) => DropdownMenuItem(
                      value: k.definition.id,
                      child: Text('${k.definition.id} — ${k.definition.nom}'),
                    )).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      selectedKriId = value;
                      fieldAController.clear();
                      fieldBController.clear();
                      computedValue = null;
                      setState2(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(_manualKriExplanation(selectedKriId), style: const TextStyle(fontSize: 12, color: _kMuted)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: fieldAController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: _manualKriField1Label(selectedKriId), isDense: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))],
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    onChanged: (_) {
                      updateComputed();
                      setState2(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: fieldBController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: _manualKriField2Label(selectedKriId), isDense: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Champ requis';
                      if (_parseNumber(v) == 0) return 'Ne peut pas être zéro';
                      return null;
                    },
                    onChanged: (_) {
                      updateComputed();
                      setState2(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Date de mesure', isDense: true, suffixIcon: Icon(Icons.calendar_month_outlined, size: 18)),
                    onTap: () async {
                      final current = DateTime.tryParse(dateCtrl.text) ?? DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx2,
                        initialDate: current,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        helpText: 'Sélectionner une date de mesure',
                      );
                      if (picked != null) dateCtrl.text = picked.toIso8601String().substring(0, 10);
                      setState2(() {});
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commentaireCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Commentaire (optionnel)', isDense: true),
                  ),
                  const SizedBox(height: 14),
                  if (computedValue != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kMuted.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Expanded(child: Text('Valeur calculée pour $selectedName', style: const TextStyle(fontSize: 12, color: _kMuted))),
                        Text(
                          '${computedValue!.toStringAsFixed(selectedKriId == 'kri-03' ? 1 : 1)} $unit',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx2).pop(false), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (computedValue == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de calculer la valeur KRI.')));
                    return;
                  }
                  try {
                    await widget.api.addRoKriValeur({
                      'kri_id': selectedKriId,
                      'date_mesure': dateCtrl.text,
                      'valeur': computedValue,
                      'commentaire': commentaireCtrl.text,
                    });
                    if (!ctx2.mounted) return;
                    Navigator.of(ctx2).pop(true);
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'enregistrement.')));
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    ).then((saved) {
      if (saved == true) {
        _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valeur KRI enregistrée.')));
      }
    });
  }

  void _detectBreaches(RoKriModuleData data) {
    for (final kri in data.kriList) {
      final prev = _prevStatuts[kri.definition.id];
      final curr = kri.statut;
      if (prev != null && prev != curr &&
          (curr == 'alerte' || curr == 'critique')) {
        final label = curr == 'critique' ? 'CRITIQUE' : 'ALERTE';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label — ${kri.definition.nom} a franchi un seuil'),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ));
      }
      _prevStatuts[kri.definition.id] = curr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final panelBg     = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final panelBorder = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);

    return FutureBuilder<RoKriModuleData>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final data     = snap.data!;
        final kris     = data.kriList;
        final normal   = kris.where((k) => k.statut == 'normal').length;
        final alerte   = kris.where((k) => k.statut == 'alerte').length;
        final critique = kris.where((k) => k.statut == 'critique').length;
        final nonRens  = kris.where((k) => k.statut == 'non_renseigne').length;
        final filtered = _filterStatus == null
            ? kris
            : kris.where((k) => k.statut == _filterStatus).toList();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Panneau gauche : vue d'ensemble + filtres ─────────────────
            Container(
              width: 230,
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: panelBorder),
              ),
              child: Column(children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    border: Border(bottom: BorderSide(color: panelBorder)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kMuted.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.speed_rounded, size: 15, color: _kMuted),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Vue d\'ensemble',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    _badge('Art. 313', _kMuted),
                  ]),
                ),
                // Contenu scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 4 stat tiles 2×2
                        Row(children: [
                          Expanded(child: _kriStatTile('Total', '${kris.length}', Icons.speed_rounded)),
                          const SizedBox(width: 8),
                          Expanded(child: _kriStatTile('Normal', '$normal', Icons.check_circle_rounded)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _kriStatTile('Alerte', '$alerte', Icons.warning_amber_rounded)),
                          const SizedBox(width: 8),
                          Expanded(child: _kriStatTile('Critique', '$critique', Icons.dangerous_rounded)),
                        ]),

                        const SizedBox(height: 16),
                        // Distribution
                        _kriPanelSection('Distribution', Icons.bar_chart_rounded, _kMuted),
                        const SizedBox(height: 8),
                        if (kris.isNotEmpty) _kriDistBar(normal, alerte, critique, nonRens, kris.length)
                        else const Text('Aucun KRI', style: TextStyle(fontSize: 11, color: _kMuted)),

                        const SizedBox(height: 16),
                        // Filtre par statut
                        _kriPanelSection('Filtrer', Icons.filter_list_rounded, _kMuted),
                        const SizedBox(height: 8),
                        _filterChip('Tous', null, '${kris.length}'),
                        const SizedBox(height: 5),
                        _filterChip('Normal', 'normal', '$normal'),
                        const SizedBox(height: 5),
                        _filterChip('En alerte', 'alerte', '$alerte'),
                        const SizedBox(height: 5),
                        _filterChip('Critique', 'critique', '$critique'),
                        if (nonRens > 0) ...[
                          const SizedBox(height: 5),
                          _filterChip('Non renseigné', 'non_renseigne', '$nonRens'),
                        ],

                        const SizedBox(height: 16),
                        // ── Surveillance automatique ──────────────────────
                        _kriPanelSection('Surveillance', Icons.radar_rounded, _kMuted),
                        const SizedBox(height: 8),
                        // Indicateur live
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: _kMuted.withValues(alpha: 0.18)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              _AutoPulseDot(active: _autoRunning),
                              const SizedBox(width: 7),
                              Expanded(child: Text('Calcul automatique',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: isDark ? AppTheme.darkText : AppTheme.text))),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              _autoRunning
                                ? 'Calcul en cours…'
                                : _lastAutoRefresh == null
                                  ? 'En attente…'
                                  : 'Mis à jour à ${_lastAutoRefresh!.hour.toString().padLeft(2,'0')}:${_lastAutoRefresh!.minute.toString().padLeft(2,'0')}:${_lastAutoRefresh!.second.toString().padLeft(2,'0')}',
                              style: const TextStyle(fontSize: 10, color: _kMuted),
                            ),
                            const SizedBox(height: 3),
                            const Text('Rafraîchi toutes les 30 s',
                              style: TextStyle(fontSize: 9.5, color: _kMuted)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        // Bouton calcul immédiat
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _autoRunning ? null : _triggerAutoCalc,
                            icon: const Icon(Icons.bolt_rounded, size: 15, color: _kMuted),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? AppTheme.darkText : AppTheme.text,
                              side: BorderSide(color: _kMuted.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            label: const Text('Calculer maintenant'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showKriEntryDialog(
                              data.kriList.where((k) => _manualKriIds.contains(k.definition.id)).toList()),
                            icon: const Icon(Icons.edit_calendar_outlined, size: 15, color: _kMuted),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? AppTheme.darkText : AppTheme.text,
                              side: BorderSide(color: _kMuted.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            label: const Text('Saisir données KRI'),
                          ),
                        ),

                        if (data.kriHorsSeuil > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _kMuted.withValues(alpha: 0.25)),
                            ),
                            child: Row(children: [
                              Icon(Icons.notifications_active_rounded,
                                color: isDark ? AppTheme.darkText : AppTheme.text, size: 13),
                              const SizedBox(width: 6),
                              Expanded(child: Text(
                                '${data.kriHorsSeuil} KRI hors seuil',
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkText : AppTheme.text,
                                  fontSize: 10.5, fontWeight: FontWeight.w700))),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(width: 14),

            // ── Panneau droit : bannière + grille KRI + historique ─────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KriBanner(total: kris.length, normal: normal, alerte: alerte,
                      critique: critique, nonRens: nonRens),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      SizedBox(
                        height: 160,
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.speed_outlined, size: 52, color: _kMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            kris.isEmpty ? 'Aucun KRI configuré' : 'Aucun KRI dans ce statut',
                            style: const TextStyle(color: _kMuted, fontSize: 13)),
                        ])),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < filtered.length; i += 3)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int j = i; j < math.min(i + 3, filtered.length); j++) ...[
                                    if (j > i) const SizedBox(width: 10),
                                    Expanded(child: _KriCard(
                                      kri: filtered[j],
                                      kriNum: _extractKriNum(filtered[j].definition.id),
                                    )),
                                  ],
                                  for (int j = filtered.length; j < i + 3 && filtered.length > i + 1; j++) ...[
                                    const SizedBox(width: 10),
                                    const Expanded(child: SizedBox()),
                                  ],
                                ],
                              ),
                            ),
                        ],
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

  Widget _kriPanelSection(String title, IconData icon, Color color) => Row(children: [
    Icon(icon, size: 12, color: color),
    const SizedBox(width: 6),
    Text(title.toUpperCase(),
      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
  ]);

  Widget _kriStatTile(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _kMuted.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _kMuted),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor, height: 1.1)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: _kMuted)),
      ]),
    );
  }

  Widget _kriDistBar(int normal, int alerte, int critique, int nonRens, int total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.darkText : AppTheme.text;
    final parts = <(int, Color)>[
      (critique, ink.withValues(alpha: 0.85)),
      (alerte,   ink.withValues(alpha: 0.5)),
      (normal,   ink.withValues(alpha: 0.25)),
      (nonRens,  ink.withValues(alpha: 0.10)),
    ].where((e) => e.$1 > 0).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: parts.map((e) => Expanded(
            flex: e.$1,
            child: Container(height: 8, color: e.$2),
          )).toList(),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 4, children: [
        if (normal   > 0) _distLegend('Normal ${(normal/total*100).round()}%'),
        if (alerte   > 0) _distLegend('Alerte ${(alerte/total*100).round()}%'),
        if (critique > 0) _distLegend('Critique ${(critique/total*100).round()}%'),
        if (nonRens  > 0) _distLegend('N/R ${(nonRens/total*100).round()}%'),
      ]),
    ]);
  }

  Widget _distLegend(String label) =>
    Text(label, style: const TextStyle(fontSize: 9.5, color: _kMuted));

  Widget _filterChip(String label, String? status, String count) {
    final isSelected = _filterStatus == status;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.text;
    return InkWell(
      onTap: () => setState(() => _filterStatus = isSelected ? null : status),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _kMuted.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _kMuted.withValues(alpha: isSelected ? 0.3 : 0.15)),
        ),
        child: Row(children: [
          Expanded(child: Text(label,
            style: TextStyle(fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? textColor : _kMuted))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _kMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(count,
              style: TextStyle(fontSize: 9.5, color: isSelected ? textColor : _kMuted, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ─── KRI Compliance Banner ────────────────────────────────────────────────────

class _KriBanner extends StatelessWidget {
  const _KriBanner({required this.total, required this.normal, required this.alerte,
    required this.critique, required this.nonRens});
  final int total, normal, alerte, critique, nonRens;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? AppTheme.darkText : AppTheme.text;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final surface = isDark ? AppTheme.darkCard : Colors.white;

    Widget statCol(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: _kMuted,
          fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
          color: textColor, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ],
    );

    Widget sep() => Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 10),
      color: borderColor);

    final headline = critique > 0
        ? '$critique KRI CRITIQUE${critique > 1 ? 'S' : ''} — ACTION IMMÉDIATE REQUISE'
        : alerte > 0
            ? '$alerte KRI EN ALERTE — SURVEILLANCE RENFORCÉE'
            : total == 0 ? 'AUCUN KRI CONFIGURÉ'
            : nonRens == total ? 'SAISIR LES PREMIÈRES VALEURS POUR ACTIVER LA SURVEILLANCE'
            : 'TOUS LES KRI DANS LES SEUILS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(color: _kMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(critique > 0 ? Icons.speed_rounded : Icons.shield_rounded, color: _kMuted, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            const Text('INDICATEURS CLÉS DE RISQUE · ART. 313 BCEAO/UMOA',
              style: TextStyle(color: _kMuted,
                fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
            const SizedBox(height: 2),
            Text(headline,
              style: TextStyle(color: textColor, fontSize: 14,
                fontWeight: FontWeight.w900, letterSpacing: -0.3),
              overflow: TextOverflow.ellipsis),
          ],
        )),
        Row(mainAxisSize: MainAxisSize.min, children: [
          statCol('NORMAL', '$normal'),
          sep(),
          statCol('ALERTE', '$alerte'),
          sep(),
          statCol('CRITIQUE', '$critique'),
          if (nonRens > 0) ...[sep(), statCol('N/R', '$nonRens')],
        ]),
      ]),
    );
  }
}

// ─── KRI Card ─────────────────────────────────────────────────────────────────

class _KriCard extends StatelessWidget {
  const _KriCard({required this.kri, required this.kriNum});
  final RoKriView kri;
  final int kriNum;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = kri.definition;
    final sl = _kriStatutLabel(kri.statut);
    final textColor  = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : _kMuted;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;

    // Tendance depuis les deux dernières mesures
    String? trendStr;
    bool?   trendUp;
    if (kri.historique.length >= 2) {
      final sorted = [...kri.historique]..sort((a, b) => b.dateMesure.compareTo(a.dateMesure));
      final last = sorted[0].valeur;
      final prev = sorted[1].valeur;
      if (prev != 0) {
        final pct = ((last - prev) / prev.abs()) * 100;
        trendStr = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %';
        trendUp  = pct >= 0;
      }
    }

    final sens = d.sens == 'superieur';
    const r = AppTheme.radius;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: const Color(0xFF4318FF).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 0.6)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'KRI ${kriNum.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w800,
                    color: mutedColor, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  excludeFromSemantics: true,
                  message: d.nom,
                  preferBelow: true,
                  child: Text(d.nom,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor),
                    overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              _badge(sl, _kMuted),
            ]),
          ),

          // ── Corps ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kri.statut == 'non_renseigne') ...[
                  // Message explicatif : données source indisponibles
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: mutedColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: mutedColor.withValues(alpha: 0.18)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: mutedColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _kriExplication(d.id),
                        style: TextStyle(fontSize: 10.5, color: mutedColor, height: 1.5),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  // Barre vide
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: mutedColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ] else ...[
                  // Valeur + tendance
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            kri.derniereValeur! % 1 == 0
                                ? kri.derniereValeur!.toInt().toString()
                                : kri.derniereValeur!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w900,
                              color: textColor, height: 1.0, letterSpacing: -1.5)),
                          const SizedBox(width: 4),
                          Text(d.unite,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: mutedColor)),
                        ],
                      ),
                      if (trendStr != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kMuted.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              trendUp! ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 11, color: mutedColor),
                            const SizedBox(width: 3),
                            Text(trendStr,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: mutedColor)),
                          ]),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _KriGauge(kri: kri),
                ],

                const SizedBox(height: 8),

                // Seuils compacts
                Row(children: [
                  Text(
                    '${sens ? '▲' : '▼'} ${d.seuilAlerte}',
                    style: TextStyle(fontSize: 10, color: mutedColor, fontWeight: FontWeight.w600)),
                  Container(
                    width: 1, height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    color: mutedColor.withValues(alpha: 0.2)),
                  Text(
                    '${sens ? '▲' : '▼'} ${d.seuilCritique} ${d.unite}',
                    style: TextStyle(fontSize: 10, color: mutedColor, fontWeight: FontWeight.w600)),
                ]),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KRI Gauge ────────────────────────────────────────────────────────────────

class _KriGauge extends StatelessWidget {
  const _KriGauge({required this.kri});
  final RoKriView kri;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: CustomPaint(
      painter: _KriGaugePainter(kri: kri, isDark: Theme.of(context).brightness == Brightness.dark),
      size: const Size(double.infinity, 28),
    ),
  );
}

class _KriGaugePainter extends CustomPainter {
  const _KriGaugePainter({required this.kri, required this.isDark});
  final RoKriView kri;
  final bool isDark;

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

    final ink = isDark ? AppTheme.darkText : AppTheme.text;
    final pLow  = Paint()..color = ink.withValues(alpha: 0.15)..style = PaintingStyle.fill;
    final pMid  = Paint()..color = ink.withValues(alpha: 0.4)..style = PaintingStyle.fill;
    final pHigh = Paint()..color = ink.withValues(alpha: 0.75)..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, w, barH), const Radius.circular(4)));

    if (sup) {
      canvas.drawRect(Rect.fromLTWH(0, barTop, pA, barH), pLow);
      if (pC > pA) canvas.drawRect(Rect.fromLTWH(pA, barTop, pC - pA, barH), pMid);
      canvas.drawRect(Rect.fromLTWH(pC, barTop, w - pC, barH), pHigh);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, barTop, pC, barH), pHigh);
      if (pA > pC) canvas.drawRect(Rect.fromLTWH(pC, barTop, pA - pC, barH), pMid);
      canvas.drawRect(Rect.fromLTWH(pA, barTop, w - pA, barH), pLow);
    }
    canvas.restore();

    // Séparateurs de seuil
    final divP = Paint()..color = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(pA, barTop), Offset(pA, barTop + barH), divP);
    if ((pC - pA).abs() > 2) canvas.drawLine(Offset(pC, barTop), Offset(pC, barTop + barH), divP);

    // Indicateur valeur (triangle)
    canvas.drawPath(
      Path()..moveTo(pV, barTop - 2)..lineTo(pV - 5, barTop - 9)..lineTo(pV + 5, barTop - 9)..close(),
      Paint()..color = ink..style = PaintingStyle.fill);

    // Label valeur
    final valStr = val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
    final tp = TextPainter(
      text: TextSpan(text: valStr,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: ink)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset((pV - tp.width / 2).clamp(0.0, w - tp.width), 0));
  }

  @override
  bool shouldRepaint(_KriGaugePainter old) => true;
}

// ─── VIEW 5 : CARTOGRAPHIE ────────────────────────────────────────────────────

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
                Text(edit == null ? 'Nouveau risque cartographié' : 'Modifier le risque',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('Cartographie des risques opérationnels',
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
                      _dropdown('Catégorie', cat, _categoriesRisque, (v) => setD(() => cat = v),
                        required: true, icon: Icons.category_rounded),
                      _dropdown('Ligne de métier', ligne, _lignesMetier, (v) => setD(() => ligne = v),
                        required: true, icon: Icons.business_rounded),
                    ),
                    _formSection('Évaluation du risque brut', icon: Icons.bar_chart_rounded, color: _kWarning),
                    _formRow(
                      _dropdown('Probabilité (1–5)', proba, [1, 2, 3, 4, 5],
                        (v) => setD(() => proba = v ?? 1), icon: Icons.repeat_rounded),
                      _dropdown('Impact (1–5)', impact, [1, 2, 3, 4, 5],
                        (v) => setD(() => impact = v ?? 1), icon: Icons.flash_on_rounded),
                    ),
                    _formSection('Contrôle interne', icon: Icons.shield_rounded, color: _kSuccess),
                    _field('Contrôle existant', controleCtrl, icon: Icons.notes_rounded,
                      hint: 'Décrivez les contrôles en place...', multiline: true),
                    _dropdown('Efficacité du contrôle (1–5)', eff, [1, 2, 3, 4, 5],
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
              label: Text(edit == null ? 'Créer' : 'Enregistrer'),
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
            // ── KPI + action ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _CartographieSummaryBar(
                    total: items.length,
                    faible: faible,
                    eleve: eleve,
                    critique: critique,
                  ),
                ),
                const SizedBox(width: 14),
                FilledButton.icon(
                  onPressed: () => _showForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouveau risque'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Layout principal ──────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colonne gauche : matrice
                  SizedBox(
                    width: 330,
                    child: SectionCard(
                      title: 'Matrice d\'exposition 5×5',
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
                            const Text('Aucun risque enregistré.', style: TextStyle(color: _kMuted, fontSize: 13)),
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
                                Text('${items.length} risque${items.length > 1 ? 's' : ''} cartographié${items.length > 1 ? 's' : ''}',
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

// ─── Risque List Item ─────────────────────────────────────────────────────────

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
              : r.niveauLabel == 'Élevé' ? const Color(0xFFF97316).withValues(alpha: 0.28)
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
              Text('P×I', style: TextStyle(fontSize: 8, color: lc.withValues(alpha: 1.0),
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
                      child: Text('×', style: TextStyle(fontSize: 12,
                        color: (isDark ? AppTheme.darkMuted : _kMuted).withValues(alpha: 1.0)))),
                    _metricTile('I', '${r.impact}', const Color(0xFFF97316)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text('=', style: TextStyle(fontSize: 12,
                        color: (isDark ? AppTheme.darkMuted : _kMuted).withValues(alpha: 1.0)))),
                    _metricTile('Score', '$score', lc),
                    const SizedBox(width: 14),
                    Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _kMuted.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    const Text('Résiduel ', style: TextStyle(fontSize: 10, color: _kMuted)),
                    Text(r.niveauResiduel.toStringAsFixed(1),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkText : AppTheme.text)),
                    if (r.controleExistant.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.shield_outlined, size: 11, color: _kSuccess),
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
        TextSpan(text: '$lbl:', style: TextStyle(fontSize: 9, color: color.withValues(alpha: 1.0),
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

// ─── Barre KPI Cartographie (style Dashboard) ────────────────────────────────

class _CartographieSummaryBar extends StatelessWidget {
  const _CartographieSummaryBar({
    required this.total,
    required this.faible,
    required this.eleve,
    required this.critique,
  });
  final int total, faible, eleve, critique;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, Color color, String subtitle})>[
      (
        label: 'Risques cartographiés',
        value: '$total',
        color: _kBlue,
        subtitle: 'Total du référentiel de risques',
      ),
      (
        label: 'Niveau faible',
        value: '$faible',
        color: _kSuccess,
        subtitle: 'P×I ≤ 4 — surveillance standard',
      ),
      (
        label: 'Niveau élevé',
        value: '$eleve',
        color: const Color(0xFFF97316),
        subtitle: 'P×I 10–16 — plan recommandé',
      ),
      (
        label: 'Niveau critique',
        value: '$critique',
        color: _kDanger,
        subtitle: 'P×I > 16 — action immédiate',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Synthèse de la cartographie des risques',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kMuted),
              ),
            ),
            Tooltip(
              excludeFromSemantics: true,
              message: 'Cartographie des risques — Art. 313 UMOA\n\n'
                  'Score = Probabilité × Impact (matrice 5×5)\n'
                  'Faible : P×I ≤ 4 — surveillance standard\n'
                  'Élevé  : P×I 10–16 — plan d\'action recommandé\n'
                  'Critique : P×I > 16 — action immédiate obligatoire',
              preferBelow: false,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(fontSize: 12, color: Colors.white, height: 1.5),
              padding: const EdgeInsets.all(14),
              child: const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.accent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 130,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _RoHeroStatCard(
                  label: item.label,
                  value: item.value,
                  valueColor: item.color,
                  subtitle: item.subtitle,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─── VIEW 6 : CONTROLES ───────────────────────────────────────────────────────

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
                Text(edit == null ? 'Nouveau contrôle interne' : 'Modifier le contrôle',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('Dispositif de contrôle opérationnel',
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
                    _formSection('Définition du contrôle', icon: Icons.tune_rounded, color: _kSuccess),
                    _field('Périmètre contrôlé', perCtrl, required: true,
                      icon: Icons.domain_rounded, hint: 'Ex: Processus de validation des crédits'),
                    _formRow(
                      _dropdown('Type de contrôle', typeC, _typesControle, (v) => setD(() => typeC = v),
                        required: true, icon: Icons.category_rounded),
                      _dropdown('Fréquence', freq, _frequences, (v) => setD(() => freq = v),
                        required: true, icon: Icons.schedule_rounded),
                    ),
                    _formSection('Résultat du test', icon: Icons.fact_check_rounded, color: _kWarning),
                    _formRow(
                      _dateField(ctx, 'Date dernier test', dateCtrl),
                      _dropdown('Résultat', resultat,
                        ['Conforme', 'Non-conforme', 'En cours', 'Non applicable'],
                        (v) => setD(() => resultat = v), icon: Icons.check_circle_rounded),
                    ),
                    _formRow(
                      _field('Points conformes', pcCtrl, keyboardType: TextInputType.number,
                        icon: Icons.check_rounded, hint: 'Ex: 18'),
                      _field('Points contrôlés', ptcCtrl, keyboardType: TextInputType.number,
                        icon: Icons.list_rounded, hint: 'Ex: 20'),
                    ),
                    _field('Non-conformités détectées', nonConfCtrl, multiline: true,
                      icon: Icons.warning_amber_rounded,
                      hint: 'Décrivez les écarts observés...'),
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
              label: Text(edit == null ? 'Créer' : 'Enregistrer'),
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
                _badge('$nonConf contrôle(s) non conforme(s)', nonConf > 0 ? _kDanger : _kSuccess),
                const SizedBox(width: 10),
                _badge('Taux moyen : ${tauxMoyen.toStringAsFixed(1)} %', tauxMoyen >= 80 ? _kSuccess : _kWarning),
                const Spacer(),
                FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add, size: 18), label: const Text('Nouveau contrôle')),
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
                    ? const Center(child: Text('Aucun contrôle enregistré.', style: TextStyle(color: _kMuted)))
                    : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(110), 1: FlexColumnWidth(2), 2: FixedColumnWidth(100), 3: FixedColumnWidth(90), 4: FixedColumnWidth(100), 5: FixedColumnWidth(90), 6: FixedColumnWidth(90)},
                          children: [
                            _tableHeader(['Référence', 'Périmètre', 'Type', 'Fréquence', 'Taux conf.', 'Résultat', 'Actions']),
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
                                        onPressed: () => _confirm(context, 'Supprimer ce contrôle ?', () async { await widget.api.deleteRoControle(c.id); _reload(); }),
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

// ─── VIEW 7 : WORKFLOW (KANBAN) ───────────────────────────────────────────────

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
                                        child: Text('→ $ns', style: TextStyle(fontSize: 10, color: _statutColor(ns), fontWeight: FontWeight.w600)),
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
    'En cours' => ['Résolu'],
    'Résolu' => ['Clôturé', 'En cours'],
    _ => [],
  };
}

// ─── VIEW 8 : PLANS D'ACTIONS ─────────────────────────────────────────────────

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
    'Contrôle'     => _kWarning,
    'KRI'          => AppColors.prudentialSolvency,
    'Audit'        => AppColors.marketNeutral,
    'Cartographie' => _kBlue,
    _              => _kMuted,
  };

  Future<void> _showForm({RoPlan? edit}) async {
    // Charger toutes les sources en parallèle avant d'ouvrir le dialog
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

    // Construit pour chaque type de source la liste (valeur_stockée, libellé_affiché)
    List<(String, String)> optionsFor(String src) => switch (src) {
      'Incident'     => incidents.map((i) {
          final desc = i.description.length > 40 ? '${i.description.substring(0, 40)}…' : i.description;
          return (i.reference, '${i.reference}  ·  $desc');
        }).toList(),
      'KRI'          => kriData.kriList.map((k) => (k.definition.nom, k.definition.nom)).toList(),
      'Contrôle'     => controles.map((c) {
          final peri = c.perimetre.length > 40 ? '${c.perimetre.substring(0, 40)}…' : c.perimetre;
          return (c.reference, '${c.reference}  ·  $peri');
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
          // Si la source change, réinitialiser la ref si la valeur n'est plus dans la liste
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
                  const Text('Suivi et traçabilité des actions correctives',
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
                        icon: Icons.title_rounded, hint: 'Ex: Renforcer le contrôle des accès'),
                      _formRow(
                        _dropdown('Type d\'action', type, _typesAction,
                          (v) => setD(() => type = v), required: true, icon: Icons.category_rounded),
                        _dropdown('Priorité', prio, _priorites,
                          (v) => setD(() => prio = v), required: true, icon: Icons.priority_high_rounded),
                      ),
                      _field('Description', descCtrl, multiline: true, icon: Icons.notes_rounded,
                        hint: 'Décrivez les actions à mener et les objectifs attendus...'),

                      _formSection('Origine du plan', icon: Icons.link_rounded, color: srcColor),
                      _dropdown('Source déclencheuse', source, _sourcesAction,
                        (v) => setD(() { source = v; sourceRef = null; }),
                        required: true, icon: Icons.account_tree_rounded),

                      // Sélecteur dynamique selon la source
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
                                  'Incident'     => 'Incident déclencheur *',
                                  'Contrôle'     => 'Contrôle non conforme *',
                                  'KRI'          => 'KRI hors seuil *',
                                  'Audit'        => 'Référence du rapport d\'audit',
                                  'Cartographie' => 'Risque identifié en cartographie',
                                  _              => 'Élément source',
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
                                  hintText: 'Sélectionner…',
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
                        _dateField(ctx, 'Date de début', debutCtrl, onPicked: () {
                          setD(() { debutDate = DateTime.tryParse(debutCtrl.text); });
                        }),
                        _dateField(ctx, 'Date d\'échéance', echeCtrl, firstDate: debutDate),
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
                label: Text(edit == null ? 'Créer' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) _reload();
  }

  String? _filterStatut;
  String? _filterPriorite;

  Color _prioriteColor(String p) => switch (p) {
    'Haute'   => _kDanger,
    'Moyenne' => _kWarning,
    _         => _kMuted,
  };

  Color _planStatutColor(String s) => switch (s) {
    'Terminé'   => _kSuccess,
    'En cours'  => _kBlue,
    'A faire'   => _kMuted,
    'Abandonné' => const Color(0xFF9E9E9E),
    _           => _kMuted,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg     = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final panelBorder = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);

    return FutureBuilder<List<RoPlan>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final all     = snap.data!;
        final actifs  = all.where((p) => p.statut != 'Terminé' && p.statut != 'Abandonné').toList();
        final enCours = all.where((p) => p.statut == 'En cours').length;
        final termines = all.where((p) => p.statut == 'Terminé').length;
        final retard  = all.where((p) => p.enRetard).length;
        final txReal  = all.isNotEmpty
            ? all.fold(0.0, (s, e) => s + e.avancement) / all.length : 0.0;

        // Plans en violation potentielle du délai 90j UEMOA (Art. 313.b)
        final now = DateTime.now();
        final violations90j = actifs.where((p) {
          if (p.creeLe.isEmpty) return false;
          final cree = DateTime.tryParse(p.creeLe);
          if (cree == null) return false;
          return now.difference(cree).inDays > 90;
        }).toList();

        // Filtrage
        var filtered = all.where((p) {
          if (_filterStatut != null && p.statut != _filterStatut) return false;
          if (_filterPriorite != null && p.priorite != _filterPriorite) return false;
          return true;
        }).toList();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Panneau gauche ──────────────────────────────────────────
            Container(
              width: 230,
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: panelBorder),
              ),
              child: Column(children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.marketNeutral.withValues(alpha: 0.07),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    border: Border(bottom: BorderSide(color: panelBorder)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.marketNeutral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.task_alt_rounded, size: 15, color: AppColors.marketNeutral),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Plans d\'action',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    _badge('Art. 313.c', AppColors.marketNeutral),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // KPI tiles
                      Row(children: [
                        Expanded(child: _planStatTile('Total',     '${all.length}',   _kBlue,    Icons.task_alt_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _planStatTile('En cours',  '$enCours',         _kWarning, Icons.hourglass_top_rounded)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _planStatTile('Terminés',  '$termines',        _kSuccess, Icons.check_circle_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _planStatTile('En retard', '$retard',          _kDanger,  Icons.warning_amber_rounded)),
                      ]),

                      const SizedBox(height: 14),

                      // Taux global BCEAO
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (txReal >= 80 ? _kSuccess : _kWarning).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (txReal >= 80 ? _kSuccess : _kWarning).withValues(alpha: 0.25)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.analytics_rounded, size: 12,
                              color: txReal >= 80 ? _kSuccess : _kWarning),
                            const SizedBox(width: 5),
                            const Text('Taux global BCEAO',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 6),
                          Text('${txReal.toStringAsFixed(0)} %',
                            style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900,
                              color: txReal >= 80 ? _kSuccess : _kWarning,
                              height: 1.0)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: txReal / 100,
                            backgroundColor: (txReal >= 80 ? _kSuccess : _kWarning).withValues(alpha: 0.15),
                            color: txReal >= 80 ? _kSuccess : _kWarning,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          const SizedBox(height: 4),
                          Text(txReal >= 80 ? 'Conforme UEMOA' : 'Sous le seuil (80 %)',
                            style: TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w600,
                              color: txReal >= 80 ? _kSuccess : _kWarning)),
                        ]),
                      ),

                      // Alerte 90j UEMOA
                      if (violations90j.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _kDanger.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: _kDanger.withValues(alpha: 0.3)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Row(children: [
                              Icon(Icons.gavel_rounded, size: 12, color: _kDanger),
                              SizedBox(width: 5),
                              Text('Délai 90j dépassé',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kDanger)),
                            ]),
                            const SizedBox(height: 4),
                            Text('${violations90j.length} plan(s) non clôturé(s) après 90 jours (Art. 313.b)',
                              style: const TextStyle(fontSize: 9.5, color: _kDanger, height: 1.4)),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Filtres statut
                      _planPanelSection('Statut', Icons.filter_list_rounded),
                      const SizedBox(height: 7),
                      _planFilterChip('Tous', null, null, _kBlue, '${all.length}',
                        _filterStatut == null && _filterPriorite == null,
                        () => setState(() { _filterStatut = null; _filterPriorite = null; })),
                      const SizedBox(height: 4),
                      for (final s in _statutsPlan) ...[
                        _planFilterChip(s, s, null, _planStatutColor(s),
                          '${all.where((p) => p.statut == s).length}',
                          _filterStatut == s,
                          () => setState(() { _filterStatut = s; _filterPriorite = null; })),
                        const SizedBox(height: 4),
                      ],

                      const SizedBox(height: 12),

                      // Filtres priorité
                      _planPanelSection('Priorité', Icons.priority_high_rounded),
                      const SizedBox(height: 7),
                      for (final pr in _priorites) ...[
                        _planFilterChip(pr, null, pr, _prioriteColor(pr),
                          '${all.where((p) => p.priorite == pr).length}',
                          _filterPriorite == pr,
                          () => setState(() { _filterPriorite = pr; _filterStatut = null; })),
                        const SizedBox(height: 4),
                      ],

                      const SizedBox(height: 14),

                      // Bouton nouveau plan
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.marketNeutral,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _showForm(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Nouveau plan'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(width: 14),

            // ── Panneau droit : liste des plans ────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alerte UEMOA globale
                    if (violations90j.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _kDanger.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kDanger.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.gavel_rounded, color: _kDanger, size: 16),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            '${violations90j.length} plan(s) dépassent le délai réglementaire de 90 jours sans clôture '
                            '(Art. 313.b UEMOA). Une escalade à la Direction est requise.',
                            style: const TextStyle(fontSize: 11.5, color: _kDanger, fontWeight: FontWeight.w500))),
                        ]),
                      ),

                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: const Text('Aucun plan correspondant au filtre.',
                          style: TextStyle(color: _kMuted, fontSize: 13)),
                      )
                    else
                      ...filtered.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlanCard(
                          plan: p,
                          sourceColor: _sourceColor(p.source),
                          prioriteColor: _prioriteColor(p.priorite),
                          statutColor: _planStatutColor(p.statut),
                          isDark: isDark,
                          age90j: () {
                            if (p.creeLe.isEmpty) return false;
                            final cree = DateTime.tryParse(p.creeLe);
                            if (cree == null) return false;
                            return DateTime.now().difference(cree).inDays > 90 &&
                                p.statut != 'Terminé' && p.statut != 'Abandonné';
                          }(),
                          onEdit: () => _showForm(edit: p),
                          onDelete: () => _confirm(context, 'Supprimer ce plan d\'action ?',
                            () async { await widget.api.deleteRoPlan(p.id); _reload(); }),
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _planStatTile(String label, String val, Color c, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c, height: 1.0)),
          Text(label, style: TextStyle(fontSize: 9, color: isDark ? AppTheme.darkMuted : _kMuted)),
        ]),
      ]),
    );
  }

  Widget _planPanelSection(String label, IconData icon) => Row(children: [
    Icon(icon, size: 12, color: _kMuted),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5)),
  ]);

  Widget _planFilterChip(String label, String? filtStatut, String? filtPrio,
      Color c, String count, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? c.withValues(alpha: 0.4) : c.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(width: 7, height: 7,
            decoration: BoxDecoration(color: active ? c : c.withValues(alpha: 0.4), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? c : _kMuted))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: c.withValues(alpha: active ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(count, style: TextStyle(fontSize: 9.5, color: active ? c : _kMuted, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.sourceColor,
    required this.prioriteColor,
    required this.statutColor,
    required this.isDark,
    required this.age90j,
    required this.onEdit,
    required this.onDelete,
  });

  final RoPlan plan;
  final Color  sourceColor;
  final Color  prioriteColor;
  final Color  statutColor;
  final bool   isDark;
  final bool   age90j;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E1E33) : Colors.white;
    final border = isDark ? const Color(0xFF1E3455) : const Color(0xFFDDE7F5);
    final p = plan;
    final prog = p.avancement / 100.0;
    final progressColor = p.avancement >= 100
        ? _kSuccess
        : p.enRetard ? _kDanger : _kBlue;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: age90j ? _kDanger.withValues(alpha: 0.5)
               : p.enRetard ? _kDanger.withValues(alpha: 0.3)
               : border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bande priorité gauche
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: prioriteColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1 : référence + titre + badges
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.marketNeutral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(p.reference,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                            color: AppColors.marketNeutral)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Tooltip(
                        excludeFromSemantics: true,
                        message: p.titre,
                        preferBelow: true,
                        child: Text(p.titre,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87),
                          overflow: TextOverflow.ellipsis),
                      )),
                      const SizedBox(width: 8),
                      // Type action
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(p.typeAction,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF5C6BC0),
                            fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      // Source badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: sourceColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(p.source,
                          style: TextStyle(fontSize: 9.5, color: sourceColor,
                            fontWeight: FontWeight.w600)),
                      ),
                      if (age90j) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kDanger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _kDanger.withValues(alpha: 0.35)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.gavel_rounded, size: 9, color: _kDanger),
                            SizedBox(width: 3),
                            Text('+90j UEMOA', style: TextStyle(fontSize: 9, color: _kDanger,
                              fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ],
                    ]),

                    const SizedBox(height: 8),

                    // Ligne 2 : description + responsable + dates
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Description + source ref
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.description.isNotEmpty)
                            Tooltip(
                              excludeFromSemantics: true,
                              message: p.description,
                              preferBelow: true,
                              child: Text(p.description,
                                style: const TextStyle(fontSize: 11, color: _kMuted, height: 1.4),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          if (p.sourceRef.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.link_rounded, size: 10, color: _kMuted),
                              const SizedBox(width: 4),
                              Text(p.sourceRef,
                                style: const TextStyle(fontSize: 10, color: _kMuted,
                                  fontWeight: FontWeight.w500)),
                            ]),
                          ],
                        ],
                      )),

                      const SizedBox(width: 16),

                      // Responsable + dates
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (p.responsable.isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.person_rounded, size: 11, color: _kMuted),
                            const SizedBox(width: 4),
                            Text(p.responsable,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        if (p.dateDebut.isNotEmpty || p.dateEcheance.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.calendar_today_outlined, size: 10, color: _kMuted),
                            const SizedBox(width: 4),
                            Text(
                              [if (p.dateDebut.isNotEmpty) p.dateDebut,
                               if (p.dateEcheance.isNotEmpty) p.dateEcheance].join(' → '),
                              style: TextStyle(fontSize: 10, color: p.enRetard ? _kDanger : _kMuted,
                                fontWeight: p.enRetard ? FontWeight.w700 : FontWeight.normal)),
                          ]),
                        ],
                        if (p.enRetard) ...[
                          const SizedBox(height: 2),
                          const Text('En retard', style: TextStyle(fontSize: 9.5, color: _kDanger,
                            fontWeight: FontWeight.w700)),
                        ] else if (p.joursRestants > 0 && p.statut != 'Terminé') ...[
                          const SizedBox(height: 2),
                          Text('J−${p.joursRestants}',
                            style: TextStyle(fontSize: 9.5,
                              color: p.joursRestants <= 7 ? _kWarning : _kMuted,
                              fontWeight: p.joursRestants <= 7 ? FontWeight.w700 : FontWeight.normal)),
                        ],
                      ]),
                    ]),

                    const SizedBox(height: 10),

                    // Ligne 3 : barre avancement + statut + actions
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      // Avancement
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('${p.avancement} %',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                                color: progressColor)),
                            const SizedBox(width: 8),
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: prog.clamp(0.0, 1.0),
                                backgroundColor: progressColor.withValues(alpha: 0.12),
                                color: progressColor,
                                minHeight: 7,
                              ),
                            )),
                          ]),
                        ],
                      )),

                      const SizedBox(width: 12),

                      // Statut badge
                      _badge(p.statut, statutColor),

                      const SizedBox(width: 8),

                      // Priorité badge
                      _badge(p.priorite, prioriteColor),

                      const SizedBox(width: 8),

                      // Actions
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Modifier',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: _kDanger),
                        tooltip: 'Supprimer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: onDelete,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── VIEW 9 : HISTORIQUE ──────────────────────────────────────────────────────

class _HistoriqueView extends StatefulWidget {
  const _HistoriqueView({required this.api});
  final RwaApiService api;
  @override
  State<_HistoriqueView> createState() => _HistoriqueViewState();
}

class _HistoriqueViewState extends State<_HistoriqueView> {
  late Future<List<RoHistorique>> _future;
  final _dateDebutCtrl = TextEditingController();
  final _dateFinCtrl   = TextEditingController();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchRoHistorique();
  }

  @override
  void dispose() {
    _dateDebutCtrl.dispose();
    _dateFinCtrl.dispose();
    super.dispose();
  }

  List<RoHistorique> _applyFilters(List<RoHistorique> all) {
    final debut = DateTime.tryParse(_dateDebutCtrl.text);
    final fin   = DateTime.tryParse(_dateFinCtrl.text);
    return all.where((h) {
      final d = DateTime.tryParse(h.dateEvenement);
      if (d == null) return true;
      if (debut != null && d.isBefore(debut)) return false;
      if (fin   != null && d.isAfter(fin.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime? current;
    try { if (ctrl.text.isNotEmpty) current = DateTime.parse(ctrl.text); } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Sélectionner une date',
    );
    if (picked != null && mounted) {
      setState(() => ctrl.text = picked.toIso8601String().substring(0, 10));
    }
  }

  String get _periodeLabel {
    final d = _dateDebutCtrl.text;
    final f = _dateFinCtrl.text;
    if (d.isNotEmpty && f.isNotEmpty) return ' [$d → $f]';
    if (d.isNotEmpty) return ' [depuis $d]';
    if (f.isNotEmpty) return ' [jusqu\'au $f]';
    return '';
  }

  Future<void> _exportData(List<RoHistorique> items) async {
    if (items.isEmpty || _exporting) return;

    final format = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final th      = Theme.of(ctx);
        final isDlgDk = th.brightness == Brightness.dark;
        final bg      = th.cardTheme.color ?? (isDlgDk ? const Color(0xFF1B2C4A) : Colors.white);
        final soft    = isDlgDk ? const Color(0xFF14233D) : const Color(0xFFF8FAFE);
        final border  = th.dividerColor;
        final txt     = th.textTheme.bodyLarge?.color ?? (isDlgDk ? Colors.white : Colors.black87);
        final muted   = isDlgDk ? const Color(0xFF8BA3C7) : const Color(0xFF94A3B8);
        final accent  = th.colorScheme.primary;

        Widget optionRow({
          required IconData icon,
          required Color color,
          required String label,
          required String badge,
          required String description,
          required String value,
        }) => InkWell(
          onTap: () => Navigator.pop(ctx, value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: soft,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: txt)),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(badge, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 11.5, color: muted)),
              ])),
              Icon(Icons.chevron_right_rounded, color: muted, size: 20),
            ]),
          ),
        );

        return Dialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: 460,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.file_download_outlined, color: accent, size: 22),
                    const SizedBox(width: 10),
                    Text('Exporter l\'historique',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: txt)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('xlsx / pdf',
                          style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: muted),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Sélectionnez le format du fichier à générer.',
                      style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 18),
                  optionRow(
                    icon: Icons.table_chart_outlined,
                    color: const Color(0xFF1E88E5),
                    label: 'Excel',
                    badge: '.xlsx',
                    description: 'Tableur éditable — formules, filtres et tri',
                    value: 'excel',
                  ),
                  const SizedBox(height: 10),
                  optionRow(
                    icon: Icons.picture_as_pdf_outlined,
                    color: const Color(0xFFE53935),
                    label: 'PDF',
                    badge: '.pdf',
                    description: 'Document mis en page, prêt à imprimer ou partager',
                    value: 'pdf',
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(foregroundColor: muted),
                      child: const Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || format == null) return;

    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      final ts  = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
      if (format == 'excel') {
        await _saveExcel(items, ts);
      } else {
        await _savePdf(items, ts);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveExcel(List<RoHistorique> items, String ts) async {
    final workbook     = Excel.createExcel();
    const sheetName    = 'Historique';
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) workbook.rename(defaultSheet, sheetName);
    final sheet = workbook[sheetName];

    final cBlueDark = ExcelColor.fromHexString('FF1D4ED8');
    final cWhite    = ExcelColor.fromHexString('FFFFFFFF');
    final cBorder   = ExcelColor.fromHexString('FFCBD5E1');
    final cGrey     = ExcelColor.fromHexString('FFF1F5F9');
    final cRowAlt   = ExcelColor.fromHexString('FFF8FAFC');
    final thin = xl.Border(borderStyle: xl.BorderStyle.Thin, borderColorHex: cBorder);

    CellStyle base({ExcelColor? bg, ExcelColor? fg, bool bold = false, int size = 10,
      HorizontalAlign hAlign = HorizontalAlign.Left}) =>
        CellStyle(
          backgroundColorHex: bg ?? ExcelColor.none,
          fontColorHex: fg ?? ExcelColor.black,
          bold: bold, fontSize: size,
          horizontalAlign: hAlign,
          verticalAlign: VerticalAlign.Center,
          leftBorder: thin, rightBorder: thin, topBorder: thin, bottomBorder: thin,
        );

    const lastCol = 5;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: 0),
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('Historique Événements — Risque Opérationnel$_periodeLabel'),
      cellStyle: base(bg: cBlueDark, fg: cWhite, bold: true, size: 13, hAlign: HorizontalAlign.Center),
    );
    sheet.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      base(bg: cBlueDark, fg: cWhite, bold: true, size: 13, hAlign: HorizontalAlign.Center),
    );
    sheet.setRowHeight(0, 36);

    const headers = ['Date', 'Menu', 'Action', 'Utilisateur', 'Élément', 'Détail'];
    for (var c = 0; c < headers.length; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1),
        TextCellValue(headers[c]),
        cellStyle: base(bg: cGrey, bold: true, size: 10, hAlign: HorizontalAlign.Center),
      );
    }
    sheet.setRowHeight(1, 22);
    const colWidths = [22.0, 18.0, 14.0, 16.0, 20.0, 40.0];
    for (var c = 0; c < colWidths.length; c++) {
      sheet.setColumnWidth(c, colWidths[c]);
    }

    for (var i = 0; i < items.length; i++) {
      final h      = items[i];
      final row    = i + 2;
      final altBg  = i.isEven ? cWhite : cRowAlt;
      final detail = h.nouvelleValeur.isNotEmpty ? h.nouvelleValeur : h.commentaire;
      final cells  = [h.dateEvenement.replaceAll('T', ' '), h.menu, h.typeAction, h.utilisateur, h.element, detail];
      for (var c = 0; c < cells.length; c++) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
          TextCellValue(cells[c]),
          cellStyle: base(bg: altBg),
        );
      }
      sheet.setRowHeight(row, 18);
    }

    final rawBytes = workbook.save();
    if (rawBytes == null) return;
    final location = await getSaveLocation(
      suggestedName: 'historique_ro_$ts.xlsx',
      acceptedTypeGroups: const [XTypeGroup(label: 'Excel', extensions: ['xlsx'])],
    );
    if (!mounted || location == null) return;
    await saveBytesAtLocation(location, Uint8List.fromList(rawBytes), requiredExtension: '.xlsx');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export Excel réussi'), backgroundColor: _kSuccess),
      );
    }
  }

  Future<void> _savePdf(List<RoHistorique> items, String ts) async {
    final fontNormal = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf'));
    final fontBold   = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSans-Bold.ttf'));

    const headerBg  = PdfColor.fromInt(0xFF0F2544);
    const borderCol = PdfColor.fromInt(0xFFE5E7EB);
    const mutedCol  = PdfColor.fromInt(0xFF6B7280);

    final now     = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    final headerStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fontBold);
    final bodyStyle   = pw.TextStyle(fontSize: 7.5, font: fontNormal);
    final mutedStyle  = pw.TextStyle(fontSize: 8, color: mutedCol, font: fontNormal);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(base: fontNormal, bold: fontBold),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const pw.BoxDecoration(color: headerBg, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Historique Événements — Risque Opérationnel',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fontBold)),
            pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFFB0C4D8), font: fontNormal)),
          ]),
        ),
        if (_periodeLabel.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, left: 2),
            child: pw.Text('Période filtrée :$_periodeLabel', style: mutedStyle),
          ),
        pw.SizedBox(height: 10),
      ]),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Menu', 'Action', 'Utilisateur', 'Élément', 'Détail'],
          data: items.map((h) => [
            h.dateEvenement.replaceAll('T', ' '),
            h.menu,
            h.typeAction,
            h.utilisateur,
            h.element,
            h.nouvelleValeur.isNotEmpty ? h.nouvelleValeur : h.commentaire,
          ]).toList(),
          headerStyle: headerStyle,
          cellStyle: bodyStyle,
          headerDecoration: const pw.BoxDecoration(color: headerBg),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
          border: pw.TableBorder.all(color: borderCol, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(72),
            1: pw.FixedColumnWidth(60),
            2: pw.FixedColumnWidth(48),
            3: pw.FixedColumnWidth(60),
            4: pw.FixedColumnWidth(80),
            5: pw.FlexColumnWidth(),
          },
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.center,
            3: pw.Alignment.centerLeft,
            4: pw.Alignment.centerLeft,
            5: pw.Alignment.centerLeft,
          },
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text('Document généré le $dateStr — Outil RWA — ${items.length} entrée(s)',
          style: mutedStyle, textAlign: pw.TextAlign.center),
      ],
    ));

    final pdfBytes = await doc.save();
    final location = await getSaveLocation(
      suggestedName: 'historique_ro_$ts.pdf',
      acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (!mounted || location == null) return;
    await saveBytesAtLocation(location, pdfBytes, requiredExtension: '.pdf');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export PDF réussi'), backgroundColor: _kSuccess),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Historique événements',
            subtitle: 'Journal de traçabilité (Art. 314) — 7 ans UMOA',
            titleFontSize: 26,
            subtitleFontSize: 12.5,
            subtitleSuffix: _artInfo('Art. 314'),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<RoHistorique>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) return _loadingBox();
                if (snap.hasError) return _errorBox(snap.error!);
                final allItems      = snap.data!;
                final filteredItems = _applyFilters(allItems);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Barre filtres + export ──────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: _kMuted),
                        const SizedBox(width: 6),
                        const Text('Journal non modifiable — conservation 7 ans (UMOA)',
                            style: TextStyle(fontSize: 12, color: _kMuted)),
                        const Spacer(),
                        // Date début
                        _histDateField('Date début', _dateDebutCtrl, isDark, () => _pickDate(_dateDebutCtrl)),
                        const SizedBox(width: 6),
                        // Date fin
                        _histDateField('Date fin', _dateFinCtrl, isDark, () => _pickDate(_dateFinCtrl)),
                        const SizedBox(width: 6),
                        // Reset
                        if (_dateDebutCtrl.text.isNotEmpty || _dateFinCtrl.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Tooltip(
                              excludeFromSemantics: true,
                              message: 'Réinitialiser les filtres',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => setState(() {
                                  _dateDebutCtrl.clear();
                                  _dateFinCtrl.clear();
                                }),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.clear, size: 16, color: _kMuted),
                                ),
                              ),
                            ),
                          ),
                        // Bouton exporter
                        SizedBox(
                          height: 30,
                          child: FilledButton.icon(
                            onPressed: (filteredItems.isEmpty || _exporting) ? null : () => _exportData(filteredItems),
                            style: FilledButton.styleFrom(
                              backgroundColor: (filteredItems.isNotEmpty && !_exporting) ? _kSuccess : (isDark ? const Color(0xFF1B2B47) : const Color(0xFFE8EEF8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: _exporting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.file_download_outlined, size: 15),
                            label: const Text('Exporter', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _badge('${filteredItems.length} / ${allItems.length} entrées', _kBlue),
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
                        child: filteredItems.isEmpty
                            ? Center(child: Text(
                                allItems.isEmpty ? 'Aucun événement enregistré.' : 'Aucun résultat pour ces dates.',
                                style: const TextStyle(color: _kMuted),
                              ))
                            : SingleChildScrollView(
                                child: Table(
                                  columnWidths: const {0: FixedColumnWidth(150), 1: FixedColumnWidth(90), 2: FixedColumnWidth(90), 3: FixedColumnWidth(80), 4: FixedColumnWidth(120), 5: FlexColumnWidth()},
                                  children: [
                                    _tableHeader(['Date', 'Menu', 'Action', 'Utilisateur', 'Élément', 'Détail']),
                                    ...filteredItems.map((h) => TableRow(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _histDateField(String label, TextEditingController ctrl, bool isDark, VoidCallback onTap) {
    return SizedBox(
      width: 130,
      height: 32,
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: onTap,
        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: _kMuted),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 14, color: _kMuted),
        ),
      ),
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

// ─── VIEW 10 : REPORTING ──────────────────────────────────────────────────────

class _ReportingView extends StatefulWidget {
  const _ReportingView({required this.api});
  final RwaApiService api;
  @override
  State<_ReportingView> createState() => _ReportingViewState();
}

class _ReportingViewState extends State<_ReportingView> {
  String _periode = 'Mensuel';
  String _destinataire = 'Organe exécutif';
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
    if (d.isNotEmpty && f.isNotEmpty) return '${_fmtDisp(d)} — ${_fmtDisp(f)}';
    return _periode;
  }

  // ─── Génération + dialog de sauvegarde ──────────────────────────────────────

  Future<void> _generateAndSave() async {
    setState(() { _generating = true; _savedFileName = null; });
    try {
      // 1. Récupérer les données
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
        content: Text('Rapport enregistré : $fileName'),
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

  // ─── Construction du document PDF ───────────────────────────────────────────

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
          pw.Text('Rapport Risque Opérationnel -- $_periodeLabel', style: mutedStyle),
          pw.Text('$_destinataire  ·  $dateStr', style: mutedStyle),
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

        // ── COUVERTURE ────────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(22),
          decoration: pw.BoxDecoration(color: headerBg, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RAPPORT DE RISQUE OPÉRATIONNEL',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 6),
            pw.Text('Période : $_periodeLabel  ·  Destinataire : $_destinataire',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            pw.Text('Date de génération : $dateStr',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            pw.SizedBox(height: 4),
            pw.Text('Art. 313, 313.b, 313.c, 314, 545, 546 -- UMOA/BCEAO',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          ]),
        ),
        pw.SizedBox(height: 16),

        // ── 1. SYNTHÈSE GÉNÉRALE ─────────────────────────────────────────────
        sectionBanner('1. SYNTHÈSE GÉNÉRALE  '),
        kpiGrid([
          ('Exigence fonds propres (K)', AppFormatters.currency(dash.widget1.exigenceFondsPropres)),
          ('RWA risque opérationnel',    AppFormatters.currency(dash.widget1.aprRisqueOp)),
          ('Statut réglementaire',       dash.widget1.statutReglementaire),
          ('Incidents (mois)',           '${dash.widget2.totalIncidentsMois}'),
          ('Non clôturés',              '${dash.widget2.incidentsNonClos}'),
          ('Actions en retard',         '${dash.widget3.actionsEnRetard}'),
        ]),
        pw.SizedBox(height: 12),

        // ── 2. INCIDENTS ET PERTES ───────────────────────────────────────────
        sectionBanner('2. INCIDENTS ET PERTES  '),
        kpiGrid([
          ('Pertes brutes totales', AppFormatters.currency(incidents.fold(0.0, (s, i) => s + i.perteBrute))),
          ('Pertes nettes totales', AppFormatters.currency(incidents.fold(0.0, (s, i) => s + i.perteNette))),
          ('Incidents significatifs', '${incidents.where((i) => i.significatif).length}'),
        ]),
        pw.SizedBox(height: 6),
        if (incidents.isEmpty)
          pw.Text('Aucun incident enregistré.', style: mutedStyle)
        else ...[
          table(
            ['Référence', 'Date', 'Ligne métier', 'Perte brute', 'Perte nette', 'Statut'],
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

        // ── 3. INDICATEURS CLÉS (KRI) ────────────────────────────────────────
        sectionBanner('3. INDICATEURS CLÉS DE RISQUE  '),
        if (kris.isEmpty)
          pw.Text('Aucun KRI configuré.', style: mutedStyle)
        else
          table(
            ['KRI', 'Unité', 'Seuil alerte', 'Dernière valeur', 'Dernière date', 'Statut'],
            kris.map((k) => [
              k.definition.nom, k.definition.unite,
              k.definition.sens == 'superieur' ? '> ${k.definition.seuilAlerte}' : '< ${k.definition.seuilAlerte}',
              k.derniereValeur != null ? '${k.derniereValeur!.toStringAsFixed(1)} ${k.definition.unite}' : 'N/A',
              k.derniereDate ?? 'N/A',
              k.statut.toUpperCase(),
            ]).toList(),
          ),
        pw.SizedBox(height: 12),

        // ── 4. CARTOGRAPHIE DES RISQUES ──────────────────────────────────────
        sectionBanner('4. CARTOGRAPHIE DES RISQUES  '),
        if (risques.isEmpty)
          pw.Text('Aucun risque enregistré.', style: mutedStyle)
        else
          table(
            ['Risque', 'Catégorie', 'Prob.', 'Impact', 'Niveau brut', 'Niveau résiduel'],
            risques.map((r) => [
              r.nom, r.categorie,
              '${r.probabilite}/5', '${r.impact}/5',
              r.niveauLabel, r.niveauResiduel.toStringAsFixed(1),
            ]).toList(),
          ),
        pw.SizedBox(height: 12),

        // ── 5. CONTRÔLES INTERNES ────────────────────────────────────────────
        sectionBanner('5. CONTRÔLES INTERNES  '),
        if (controles.isNotEmpty) ...[
          kpiGrid([
            ('Total contrôles', '${controles.length}'),
            ('Non conformes', '${controles.where((c) => c.resultat == 'Non-conforme').length}'),
            ('Taux moyen', '${(controles.fold(0.0, (s, c) => s + c.tauxConformite) / controles.length).toStringAsFixed(1)} %'),
          ]),
          table(
            ['Référence', 'Périmètre', 'Type', 'Fréquence', 'Taux conf.', 'Résultat'],
            controles.map((c) => [
              c.reference, c.perimetre, c.typeControle, c.frequence,
              '${c.tauxConformite.toStringAsFixed(1)} %', c.resultat,
            ]).toList(),
          ),
        ] else
          pw.Text('Aucun contrôle enregistré.', style: mutedStyle),
        pw.SizedBox(height: 12),

        // ── 6. PLANS D'ACTIONS ───────────────────────────────────────────────
        sectionBanner('6. PLANS D\'ACTIONS  '),
        if (plans.isNotEmpty) ...[
          kpiGrid([
            ('Plans total', '${plans.length}'),
            ('En retard', '${plans.where((p) => p.enRetard).length}'),
            ('Réalisation moy.', '${(plans.fold(0.0, (s, p) => s + p.avancement) / plans.length).toStringAsFixed(0)} %'),
          ]),
          table(
            ['Référence', 'Titre', 'Priorité', 'Responsable', 'Échéance', 'Avancement', 'Statut'],
            plans.map((p) => [
              p.reference,
              p.titre.length > 30 ? '${p.titre.substring(0, 28)}…' : p.titre,
              p.priorite,
              p.responsable.isEmpty ? '—' : p.responsable,
              p.dateEcheance.isEmpty ? '—' : p.dateEcheance,
              '${p.avancement} %', p.statut,
            ]).toList(),
          ),
        ] else
          pw.Text('Aucun plan d\'action enregistré.', style: mutedStyle),
        pw.SizedBox(height: 12),

        // ── 7. SIMULATION DE CRISE ───────────────────────────────────────────
        sectionBanner('7. SIMULATION DE CRISE  '),
        table(
          ['Scénario', 'Variation PNB', 'RWA estimé', 'Exigence fonds propres'],
          [
            ['Optimiste',    '+10 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 1.10), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 1.10)],
            ['Neutre',        '0 %',  AppFormatters.currency(dash.widget1.aprRisqueOp),        AppFormatters.currency(dash.widget1.exigenceFondsPropres)],
            ['Pessimiste',   '-20 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 0.80), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 0.80)],
            ['Crise sévère', '-35 %', AppFormatters.currency(dash.widget1.aprRisqueOp * 0.65), AppFormatters.currency(dash.widget1.exigenceFondsPropres * 0.65)],
          ],
        ),
        pw.SizedBox(height: 16),

        // ── PIED ─────────────────────────────────────────────────────────────
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text(
          'Rapport généré le $dateStr -- Outil RWA -- Confidentiel',
          style: mutedStyle,
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    return doc.save();
  }

  // ─── Interface ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Reporting opérationnel',
            subtitle: 'Génération des rapports réglementaires (Art. 313.c)',
            titleFontSize: 26,
            subtitleFontSize: 12.5,
            subtitleSuffix: _artInfo('Art. 313.c'),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCard(
                    title: 'Paramètres du rapport',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Période rapide :',
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
                    Expanded(child: _reportingDateField(context, 'Date de début', _dateDebutCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _reportingDateField(context, 'Date de fin', _dateFinCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown('Destinataire', _destinataire,
                      ['Organe exécutif', 'Organe délibérant', 'Commission Bancaire'],
                      (v) => setState(() => _destinataire = v ?? 'Organe exécutif'))),
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
                _tableHeader(['#', 'Section', 'Éléments inclus', 'Réf.']),
                ...[
                  ('1', 'Synthèse générale',       '',           ['Exigence de fonds propres (Art. 301/307)', 'RWA risque opérationnel (Art. 89)', 'Statut de conformité', 'Évolution N-1']),
                  ('2', 'Incidents et pertes',      'Art. 313.b', ['Nombre total d\'incidents', 'Pertes nettes totales', 'Top 5 incidents par perte', 'Répartition par ligne de métier']),
                  ('3', 'Indicateurs clés (KRI)',   '',           ['Tableau des KRI avec statut', 'Évolutions significatives', 'Alertes et actions associées']),
                  ('4', 'Cartographie des risques', '',           ['Matrice des risques (heatmap)', 'Top 5 risques critiques', 'Évolution risque résiduel']),
                  ('5', 'Contrôles internes',       'Art. 314',   ['Taux de conformité global', 'Contrôles non conformes', 'Plan de contrôle', 'Actions correctives en cours']),
                  ('6', 'Plans d\'action',          'Art. 313.c', ['Taux de réalisation', 'Actions en retard', 'Actions terminées (période)']),
                  ('7', 'Simulation de crise',      'Art. 545',   ['Scénario optimiste (+10 %)', 'Scénario neutre (0 %)', 'Scénario pessimiste (-20 %)', 'Scénario crise sévère (-35 %)']),
                  ('8', 'Annexes',                  '',           ['Détail des incidents', 'Journal des modifications', 'Glossaire']),
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
                label: Text(_generating ? 'Génération en cours…' : 'Générer le rapport · $_periodeLabel'),
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
            ),
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
                helpText: 'Sélectionner une date',
              );
              if (picked != null) setState(() => ctrl.text = picked.toIso8601String().substring(0, 10));
            },
          ),
        ],
      ),
    );
  }

}

// ─── VIEW : REGISTRE DES PERTES RO (BCEAO/UMOA) ──────────────────────────────
// Design aligné sur le Tableau des expositions (dégradé navy, panel F6F9FF, KPI footer)

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
  void _onVTrail() => _syncV(_vTrailCtrl);
  void _syncV(ScrollController src) {
    if (_isSyncV || !src.hasClients) return;
    _isSyncV = true;
    for (final c in [_vBodyCtrl, _vFixedCtrl, _vTrailCtrl]) {
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
    _vTrailCtrl.addListener(_onVTrail);
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hCtrl.dispose();
    _vBodyCtrl.removeListener(_onVBody);
    _vFixedCtrl.removeListener(_onVFixed);
    _vTrailCtrl.removeListener(_onVTrail);
    _vBodyCtrl.dispose();
    _vFixedCtrl.dispose();
    _vTrailCtrl.dispose();
    super.dispose();
  }

  // Cache pour le footer (mis à jour quand le future se résout)
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
                Text('Modifier — ${edit.reference}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('Mise à jour conforme Art. 313.b UMOA',
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
                      _dropdown('Ligne de métier', ligne, _lignesMetier, (v) => setD(() => ligne = v),
                        required: true, icon: Icons.business_rounded),
                      _dropdown('Type d\'événement', type, _typesEvenement, (v) => setD(() => type = v),
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
                      _field('Perte récupérée (FCFA)', recupCtrl,
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

  final _hCtrl       = ScrollController();
  final _vBodyCtrl   = ScrollController();
  final _vFixedCtrl  = ScrollController();
  final _vTrailCtrl  = ScrollController();
  bool  _isSyncV     = false;

  int _selectedTab    = 0;
  int _uemoiSubTab    = 0;

  static const _tabDefs = [
    (Icons.compare_arrows_outlined,  'CCR3'),
    (Icons.policy_outlined,          'Dispositif UEMOI'),
  ];

  static const _uemoiSubTabDefs = [
    (Icons.trending_up_outlined,   'A1 — Indicateur de Base (AIB)'),
    (Icons.account_tree_outlined,  'A2 — Approche Standard (AS)'),
    (Icons.analytics_outlined,     'B1 — BIC / Pilotage interne'),
    (Icons.warning_amber_outlined, 'C1 — Pertes opérationnelles'),
    (Icons.dashboard_outlined,     'C2 — Tableau de bord'),
    (Icons.compare_arrows_outlined,'Synthèse globale'),
  ];

  static const _rowH = 48.0;

  static const _colLabels = [
    'Référence', 'Date', 'Ligne de métier', "Type d'événement",
    'Description', 'Cause racine', 'Perte brute (FCFA)', 'Récupéré (FCFA)',
    'Perte nette (FCFA)', 'Capital minimal 15 %', 'RWA (×12,5)', 'Statut', 'Actions',
  ];

  static const _colW = [140.0, 110.0, 190.0, 160.0, 260.0, 190.0, 155.0, 150.0, 155.0, 160.0, 145.0, 105.0, 80.0];

  // Visibilité des colonnes
  final List<bool> _visibleCols = List.filled(13, true);
  final _colMenuCtrl = MenuController();

  // Sélection de ligne
  String? _selectedId;

  int    get _visibleCount => _visibleCols.where((v) => v).length;

  // Colonnes défilantes (exclut col 0 figée à gauche et col 12 figée à droite)
  List<(String, double)> get _scrollableColDefs => [
    for (int i = 1; i <= 11; i++)
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

  // Demande le format puis génère le fichier
  Future<void> _exportData() async {
    final items = _apply(_cachedItems);
    if (items.isEmpty) return;

    // ── Dialogue de choix du format ──────────────────────────────────────
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final th      = Theme.of(ctx);
        final isDlgDk = th.brightness == Brightness.dark;
        final bg      = th.cardTheme.color ?? (isDlgDk ? const Color(0xFF1B2C4A) : Colors.white);
        final soft    = isDlgDk ? const Color(0xFF14233D) : const Color(0xFFF8FAFE);
        final border  = th.dividerColor;
        final txt     = th.textTheme.bodyLarge?.color ?? (isDlgDk ? Colors.white : Colors.black87);
        final muted   = isDlgDk ? const Color(0xFF8BA3C7) : const Color(0xFF94A3B8);
        final accent  = th.colorScheme.primary;

        Widget optionRow({
          required IconData icon,
          required Color color,
          required String label,
          required String badge,
          required String description,
          required String value,
        }) {
          return InkWell(
            onTap: () => Navigator.pop(ctx, value),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: soft,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: txt)),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(badge,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text(description,
                            style: TextStyle(fontSize: 11.5, color: muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted, size: 20),
                ],
              ),
            ),
          );
        }

        return Dialog(
          backgroundColor: bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: 460,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── En-tête ──
                  Row(children: [
                    Icon(Icons.file_download_outlined, color: accent, size: 22),
                    const SizedBox(width: 10),
                    Text('Exporter le registre',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: txt)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('xlsx / pdf',
                          style: TextStyle(
                              fontSize: 10,
                              color: accent,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: muted),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Sélectionnez le format du fichier à générer.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 18),
                  // ── Options ──
                  optionRow(
                    icon: Icons.table_chart_outlined,
                    color: const Color(0xFF1E88E5),
                    label: 'Excel',
                    badge: '.xlsx',
                    description:
                        'Tableur éditable — formules, filtres et tri',
                    value: 'excel',
                  ),
                  const SizedBox(height: 10),
                  optionRow(
                    icon: Icons.picture_as_pdf_outlined,
                    color: const Color(0xFFE53935),
                    label: 'PDF',
                    badge: '.pdf',
                    description:
                        'Document mis en page, prêt à imprimer ou partager',
                    value: 'pdf',
                  ),
                  const SizedBox(height: 16),
                  // ── Annuler ──
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(foregroundColor: muted),
                      child: const Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || format == null) return;

    final now = DateTime.now();
    final ts  = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    if (format == 'excel') {
      await _saveExcel(items, ts);
    } else {
      await _savePdf(items, ts);
    }
  }

  Future<void> _saveExcel(List<RoIncident> items, String ts) async {
    final workbook     = Excel.createExcel();
    const sheetName    = 'Registre RO';
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.rename(defaultSheet, sheetName);
    }
    final sheet = workbook[sheetName];

    // ── Palette ────────────────────────────────────────────────────────────
    final cBlueDark  = ExcelColor.fromHexString('FF1D4ED8');
    final cBlueLight = ExcelColor.fromHexString('FFDBEAFE');
    final cGrey      = ExcelColor.fromHexString('FFF1F5F9');
    final cWhite     = ExcelColor.fromHexString('FFFFFFFF');
    final cRowAlt    = ExcelColor.fromHexString('FFF8FAFC');
    final cGreenDark = ExcelColor.fromHexString('FF15803D');
    final cGreenLt   = ExcelColor.fromHexString('FFDCFCE7');
    final cMuted     = ExcelColor.fromHexString('FF475569');
    final cBorder    = ExcelColor.fromHexString('FFCBD5E1');

    final thin = xl.Border(borderStyle: xl.BorderStyle.Thin, borderColorHex: cBorder);

    CellStyle baseStyle({
      ExcelColor? bg,
      ExcelColor? fg,
      bool bold = false,
      int size = 10,
      HorizontalAlign hAlign = HorizontalAlign.Left,
      VerticalAlign   vAlign = VerticalAlign.Center,
      TextWrapping? wrap,
    }) =>
        CellStyle(
          backgroundColorHex: bg ?? ExcelColor.none,
          fontColorHex: fg ?? ExcelColor.black,
          bold: bold,
          fontSize: size,
          horizontalAlign: hAlign,
          verticalAlign: vAlign,
          textWrapping: wrap,
          leftBorder: thin, rightBorder: thin,
          topBorder: thin,  bottomBorder: thin,
        );

    // ── Ligne 1 : Titre (fusionné A1:L1) ──────────────────────────────────
    const lastCol = 11;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: 0),
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('Registre des Pertes Opérationnelles — Risque Opérationnel BCEAO'),
      cellStyle: baseStyle(
        bg: cBlueDark, fg: cWhite, bold: true, size: 13,
        hAlign: HorizontalAlign.Center,
      ),
    );
    sheet.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      baseStyle(
        bg: cBlueDark, fg: cWhite, bold: true, size: 13,
        hAlign: HorizontalAlign.Center,
      ),
    );
    sheet.setRowHeight(0, 36);

    // ── Ligne 2 : En-têtes de colonnes ────────────────────────────────────
    const colDefs = [
      ('Référence',                  true,  14.0),
      ('Date',                       true,  12.0),
      ('Ligne de métier',            true,  22.0),
      ("Type d'événement",           true,  18.0),
      ('Description',                true,  36.0),
      ('Cause racine',               false, 20.0),
      ('Perte brute (FCFA)',         true,  18.0),
      ('Récupéré (FCFA)',            false, 18.0),
      ('Perte nette (FCFA)',         true,  18.0),
      ('Capital 15 % (FCFA)',        true,  18.0),
      ('RWA ×12,5 (FCFA)',           true,  18.0),
      ('Statut',                     false, 14.0),
    ];

    for (int c = 0; c < colDefs.length; c++) {
      final (label, required, width) = colDefs[c];
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1),
        TextCellValue('${required ? "★ " : "○ "}$label'),
        cellStyle: baseStyle(
          bg: required ? cBlueLight : cGrey,
          fg: required ? cBlueDark  : cMuted,
          bold: true,
          hAlign: HorizontalAlign.Center,
          wrap: TextWrapping.WrapText,
        ),
      );
      sheet.setColumnWidth(c, width);
    }
    sheet.setRowHeight(1, 34);

    // ── Ligne 3 : Totaux (ligne verte) ────────────────────────────────────
    double totalBrut = 0, totalRec = 0, totalNette = 0, totalKro = 0, totalApr = 0;
    for (final i in items) {
      totalBrut  += i.perteBrute;
      totalRec   += i.perteRecuperee;
      totalNette += i.perteNette;
      totalKro   += i.perteNette * 0.15;
      totalApr   += i.perteNette * 0.15 * 12.5;
    }
    const totRow = 2;
    final totLabels = <int, String>{0: 'TOTAL (${items.length} incidents)'};
    final totVals = <int, int>{
      6: totalBrut.round(), 7: totalRec.round(), 8: totalNette.round(),
      9: totalKro.round(),  10: totalApr.round(),
    };
    for (int c = 0; c <= lastCol; c++) {
      final val = totVals[c] != null
          ? IntCellValue(totVals[c]!)
          : TextCellValue(totLabels[c] ?? '');
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totRow),
        val,
        cellStyle: baseStyle(
          bg: cGreenLt, fg: cGreenDark, bold: true,
          hAlign: (totVals.containsKey(c)) ? HorizontalAlign.Right : HorizontalAlign.Left,
        ),
      );
    }
    sheet.setRowHeight(totRow, 22);

    // ── Lignes de données (à partir de la ligne 4) ────────────────────────
    for (int r = 0; r < items.length; r++) {
      final i   = items[r];
      final kro = i.perteNette * 0.15;
      final apr = kro * 12.5;
      final bg  = r.isEven ? cWhite : cRowAlt;
      final rowIdx = r + 3;

      final textVals = <int, String>{
        0: i.reference, 1: i.dateOccurrence, 2: i.ligneMetier,
        3: i.typeEvenement, 4: i.description, 5: i.causeRacine, 11: i.statut,
      };
      final numVals = <int, int>{
        6: i.perteBrute.round(), 7: i.perteRecuperee.round(),
        8: i.perteNette.round(), 9: kro.round(), 10: apr.round(),
      };

      for (int c = 0; c <= lastCol; c++) {
        final isNum = numVals.containsKey(c);
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
          isNum ? IntCellValue(numVals[c]!) : TextCellValue(textVals[c] ?? ''),
          cellStyle: baseStyle(
            bg: bg,
            hAlign: isNum ? HorizontalAlign.Right : HorizontalAlign.Left,
            wrap: (c == 4) ? TextWrapping.WrapText : null,
          ),
        );
      }
      sheet.setRowHeight(rowIdx, 20);
    }

    // ── Sauvegarde ────────────────────────────────────────────────────────
    final rawBytes = workbook.save();
    if (rawBytes == null) return;

    final location = await getSaveLocation(
      suggestedName: 'registre_ro_$ts.xlsx',
      acceptedTypeGroups: const [XTypeGroup(label: 'Excel', extensions: ['xlsx'])],
    );
    if (!mounted || location == null) return;

    await saveBytesAtLocation(location, Uint8List.fromList(rawBytes), requiredExtension: '.xlsx');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export Excel réussi'),
        backgroundColor: Color(0xFF14A44D),
      ));
    }
  }

  Future<void> _savePdf(List<RoIncident> items, String ts) async {
    // ── Polices (IBM Plex Sans — supporte tout le Latin étendu) ─────────
    final fontNormal = pw.Font.ttf(
      await rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf'));
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/IBMPlexSans-Bold.ttf'));
    final fontItalic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/IBMPlexSans-Italic.ttf'));

    // ── Palette (identique au reporting opérationnel) ────────────────────
    const headerBg  = PdfColor.fromInt(0xFF0F2544);  // navy foncé
    const accentBg  = PdfColor.fromInt(0xFF2563EB);  // bleu accent
    const greenBg   = PdfColor.fromInt(0xFF15803D);  // vert total
    const borderCol = PdfColor.fromInt(0xFFE5E7EB);
    const mutedCol  = PdfColor.fromInt(0xFF6B7280);

    final now     = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/'
                    '${now.month.toString().padLeft(2,'0')}/'
                    '${now.year}';

    const mutedStyle  = pw.TextStyle(fontSize: 8, color: mutedCol);
    const bodyStyle   = pw.TextStyle(fontSize: 7.5);
    final headerStyle = pw.TextStyle(
      fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    // ── Calculs agrégés ──────────────────────────────────────────────────
    final totalBrut  = items.fold(0.0, (s, i) => s + i.perteBrute);
    final totalRec   = items.fold(0.0, (s, i) => s + i.perteRecuperee);
    final totalNette = items.fold(0.0, (s, i) => s + i.perteNette);
    final totalKro   = totalNette * 0.15;
    final totalApr   = totalKro  * 12.5;
    final nbSignif   = items.where((i) => i.significatif).length;

    String fmt(double v) {
      if (v >= 1e9)  return '${(v / 1e9).toStringAsFixed(1)} Md';
      if (v >= 1e6)  return '${(v / 1e6).toStringAsFixed(1)} M';
      if (v >= 1e3)  return '${(v / 1e3).toStringAsFixed(0)} K';
      return v.toStringAsFixed(0);
    }

    // ── Helpers de widgets ───────────────────────────────────────────────
    pw.Widget sectionBanner(String text) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: headerBg,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(text,
        style: pw.TextStyle(
          fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );

    pw.Widget kpiCard(String label, String value, {PdfColor? valueColor}) =>
      pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderCol),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: mutedStyle),
              pw.SizedBox(height: 3),
              pw.Text(value,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: valueColor ?? headerBg,
                )),
            ],
          ),
        ),
      );

    pw.Widget kpiRow(List<(String, String, PdfColor?)> kpis) => pw.Row(
      children: kpis.map((k) => kpiCard(k.$1, k.$2, valueColor: k.$3)).toList(),
    );

    // Ligne de total sous le tableau
    pw.Widget totalRow(List<String> totals) => pw.Container(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDCFCE7)),
      child: pw.Row(
        children: totals.asMap().entries.map((e) => pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: pw.Text(e.value,
              style: pw.TextStyle(
                fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: greenBg)),
          ),
        )).toList(),
      ),
    );

    // ── Données du tableau ───────────────────────────────────────────────
    const tableHeaders = [
      'Réf.', 'Date', 'Ligne de métier', "Type d'évén.",
      'Perte brute', 'Récupéré', 'Perte nette', 'Capital min. (15 %)', 'RWA ×12,5', 'Statut',
    ];

    final tableRows = items.map((i) {
      final kro = i.perteNette * 0.15;
      final apr = kro * 12.5;
      return [
        i.reference,
        i.dateOccurrence,
        i.ligneMetier.length > 18 ? '${i.ligneMetier.substring(0,16)}…' : i.ligneMetier,
        i.typeEvenement,
        fmt(i.perteBrute),
        fmt(i.perteRecuperee),
        fmt(i.perteNette),
        fmt(kro),
        fmt(apr),
        i.statut,
      ];
    }).toList();

    // ── Construction du document ─────────────────────────────────────────
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base:   fontNormal,
        bold:   fontBold,
        italic: fontItalic,
      ),
    );
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 30),

      // En-tête de chaque page
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Registre des Pertes — Risque Opérationnel BCEAO',
              style: mutedStyle),
            pw.Text('Export du $dateStr', style: mutedStyle),
          ],
        ),
      ),

      // Pied de page
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Confidentiel — Usage interne', style: mutedStyle),
            pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: mutedStyle),
          ],
        ),
      ),

      build: (_) => [

        // ── Bloc couverture ─────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: headerBg,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('REGISTRE DES PERTES OPÉRATIONNELLES',
                style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Art. 313, 314, 545, 546 — UMOA/BCEAO  ·  Généré le $dateStr',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // ── 1. Synthèse ─────────────────────────────────────────────────
        sectionBanner('1. SYNTHÈSE'),
        kpiRow([
          ('Incidents totaux',    '${items.length}',        null),
          ('Incidents significatifs', '$nbSignif',          null),
          ('Pertes brutes',       '${fmt(totalBrut)} FCFA', null),
          ('Pertes récupérées',   '${fmt(totalRec)} FCFA',  null),
          ('Pertes nettes',       '${fmt(totalNette)} FCFA', null),
        ]),
        kpiRow([
          ('Capital minimum (15 %)', '${fmt(totalKro)} FCFA', accentBg),
          ('RWA — Risque opérationnel',   '${fmt(totalApr)} FCFA', accentBg),
          ('Taux de récupération',
            totalBrut > 0 ? '${(totalRec / totalBrut * 100).toStringAsFixed(1)} %' : '0 %',
            null),
        ]),
        pw.SizedBox(height: 12),

        // ── 2. Registre détaillé ─────────────────────────────────────────
        sectionBanner('2. REGISTRE DÉTAILLÉ  (${items.length} incident${items.length > 1 ? "s" : ""})'),
        if (items.isEmpty)
          pw.Text('Aucun incident dans le registre.', style: mutedStyle)
        else ...[
          pw.TableHelper.fromTextArray(
            headers: tableHeaders,
            data: tableRows,
            headerStyle: headerStyle,
            headerDecoration: const pw.BoxDecoration(color: accentBg),
            cellStyle: bodyStyle,
            border: pw.TableBorder.all(color: borderCol, width: 0.4),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            columnWidths: const {
              0: pw.FixedColumnWidth(42),
              1: pw.FixedColumnWidth(52),
              2: pw.FixedColumnWidth(80),
              3: pw.FixedColumnWidth(60),
              4: pw.FixedColumnWidth(56),
              5: pw.FixedColumnWidth(52),
              6: pw.FixedColumnWidth(56),
              7: pw.FixedColumnWidth(56),
              8: pw.FixedColumnWidth(56),
              9: pw.FixedColumnWidth(44),
            },
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC)),
          ),
          // Ligne totaux
          totalRow([
            'TOTAL', '', '', '',
            fmt(totalBrut), fmt(totalRec), fmt(totalNette),
            fmt(totalKro), fmt(totalApr), '',
          ]),
        ],
        pw.SizedBox(height: 16),

        // ── Pied ────────────────────────────────────────────────────────
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text(
          'Document généré le $dateStr — Outil RWA — Confidentiel',
          style: mutedStyle,
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    final pdfBytes = await doc.save();
    final location = await getSaveLocation(
      suggestedName: 'registre_ro_$ts.pdf',
      acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (!mounted || location == null) return;

    await saveBytesAtLocation(location, pdfBytes, requiredExtension: '.pdf');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export PDF réussi'),
        backgroundColor: Color(0xFF14A44D),
      ));
    }
  }

  // Recadre le scroll horizontal dans ses limites après un changement de colonnes visibles
  void _clampHScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hCtrl.hasClients) {
        final max = _hCtrl.position.maxScrollExtent;
        if (_hCtrl.offset > max) _hCtrl.jumpTo(max);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F5);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Import de données',
            titleFontSize: 26,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tabDefs.length, (i) {
                        final isSelected = _selectedTab == i;
                        final fgColor = isSelected
                            ? AppColors.accent
                            : (isDark ? const Color(0xFF9FB0CE) : const Color(0xFF234A84));
                        return InkWell(
                          onTap: () => setState(() => _selectedTab = i),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(
                                color: isSelected ? AppColors.accent : Colors.transparent,
                                width: 2,
                              )),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_tabDefs[i].$1, size: 16, color: fgColor),
                                const SizedBox(width: 8),
                                Text(
                                  _tabDefs[i].$2,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: fgColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildCurrentTab(isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(bool isDark) {
    switch (_selectedTab) {
      case 0: return _buildCcr3Content(isDark);
      case 1: return _buildDispositifUemoiContent(isDark);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildDispositifUemoiContent(bool isDark) {
    final borderColor = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F5);
    final muted       = isDark ? const Color(0xFF8BA3C7) : const Color(0xFF94A3B8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bandeau informatif ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1E36) : const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 14, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AIB et AS sont déclaratoires BCEAO (Pilier 1). BIC est un outil de pilotage interne uniquement. PIEAFP relève du Pilier 2 (art. 534-535).',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ]),
        ),

        // ── Barre de sous-onglets ───────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_uemoiSubTabDefs.length, (i) {
                final isSelected = _uemoiSubTab == i;
                final fgColor = isSelected
                    ? AppColors.accent
                    : (isDark ? const Color(0xFF9FB0CE) : const Color(0xFF234A84));
                return InkWell(
                  onTap: () => setState(() => _uemoiSubTab = i),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: isSelected ? AppColors.accent : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_uemoiSubTabDefs[i].$1, size: 14, color: fgColor),
                        const SizedBox(width: 6),
                        Text(
                          _uemoiSubTabDefs[i].$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: fgColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Contenu du sous-onglet actif ────────────────────────────────────
        Expanded(child: _buildUemoiSubTab(isDark)),
      ],
    );
  }

  Widget _buildUemoiSubTab(bool isDark) {
    switch (_uemoiSubTab) {
      case 0: return UemoiAibScreen(api: widget.api);
      case 1: return UemoiAsScreen(api: widget.api);
      case 2: return _CorepTabView(api: widget.api, isDark: isDark);
      case 3: return _buildRegistreContent(isDark);
      case 4: return _buildUemoiPlaceholder(isDark, 'C2 — Tableau de bord & indicateurs', 'Pilier 2 PIEAFP — indicateurs agrégés', Icons.dashboard_outlined, 'BLOC C');
      case 5: return UemoiSyntheseScreen(api: widget.api);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildUemoiPlaceholder(bool isDark, String title, String subtitle, IconData icon, String bloc) {
    final muted      = isDark ? const Color(0xFF8BA3C7) : const Color(0xFF94A3B8);
    final blocColor  = isDark ? const Color(0xFF1E88E5) : const Color(0xFF1565C0);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: blocColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: blocColor.withValues(alpha: 0.3)),
            ),
            child: Text(bloc, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: blocColor)),
          ),
          const SizedBox(height: 16),
          Icon(icon, size: 44, color: muted.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(title,    style: TextStyle(color: muted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 10),
          Text('Section en cours de développement', style: TextStyle(color: muted.withValues(alpha: 1.0), fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildRegistreContent(bool isDark) {
    // Footer data depuis le cache (0 pendant le chargement)
    final cached = _apply(_cachedItems);
    final cBrute = cached.fold(0.0, (s, i) => s + i.perteBrute);
    final cNette = cached.fold(0.0, (s, i) => s + i.perteNette);
    final cKro   = cNette * 0.15;
    final cApr   = cKro * 12.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panneau de contrôles ─────────────────────────────────────────
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
              _fDropLabeled('Ligne de métier',  _filterLigne,  _lignesMetier,    (v) => setState(() => _filterLigne  = v), 138, isDark),
              const SizedBox(width: 6),
              _fDropLabeled("Type d'événement", _filterType,   _typesEvenement,  (v) => setState(() => _filterType   = v), 130, isDark),
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
                        hintText: 'Référence…',
                        prefixIcon: Icon(Icons.search_outlined, size: 14),
                        prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(width: 34, height: 34,
                child: Tooltip(excludeFromSemantics: true, message: 'Réinitialiser les filtres',
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
              // ── Sélecteur de colonnes ──────────────────────────────────────
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
                        onTap: () {
                          setState(() {
                            final allOn = _visibleCols.every((v) => v);
                            for (int k = 0; k < _visibleCols.length; k++) {
                              _visibleCols[k] = !allOn;
                            }
                          });
                          _clampHScroll();
                        },
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
                        if (v != null) {
                          setState(() => _visibleCols[ci] = v);
                          _clampHScroll();
                        }
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
                _cachedItems.isEmpty ? null : _exportData,
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
        // ── Tableau ──────────────────────────────────────────────────────
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
        // ── Footer KPI (style Dashboard Opérationnel) ────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: const Color(0xFF1E3A5F).withValues(alpha: isDark ? 0.5 : 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(height: 3, color: AppTheme.accent.withValues(alpha: 0.7)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1A2A4A), const Color(0xFF13203A)]
                        : [const Color(0xFFF8F9FF), const Color(0xFFF0F2FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: _RoDashSummaryItem(label: 'Pertes', value: '${cached.length}', accentColor: AppTheme.accent, icon: Icons.list_alt_outlined)),
                    Container(width: 1, height: 40, color: AppTheme.accent.withValues(alpha: 0.25)),
                    Expanded(child: _RoDashSummaryItem(label: 'Perte brute', value: AppFormatters.currency(cBrute), accentColor: _kDanger, icon: Icons.trending_down_outlined)),
                    Container(width: 1, height: 40, color: AppTheme.accent.withValues(alpha: 0.25)),
                    Expanded(child: _RoDashSummaryItem(label: 'Perte nette', value: AppFormatters.currency(cNette), accentColor: _kDanger, icon: Icons.account_balance_outlined)),
                    Container(width: 1, height: 40, color: AppTheme.accent.withValues(alpha: 0.25)),
                    Expanded(child: _RoDashSummaryItem(label: 'Capital minimum (Art. 89)', value: AppFormatters.currency(cKro), accentColor: AppColors.prudentialSolvency, icon: Icons.shield_outlined)),
                    Container(width: 1, height: 40, color: AppTheme.accent.withValues(alpha: 0.25)),
                    Expanded(child: _RoDashSummaryItem(label: 'RWA opérationnel', value: AppFormatters.currency(cApr), accentColor: AppColors.marketNeutral, icon: Icons.bar_chart_outlined)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // ── helpers UI ──────────────────────────────────────────────────────────────

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
          const Text('Aucune entrée dans le registre', style: TextStyle(color: _kMuted, fontSize: 14, fontWeight: FontWeight.w600)),
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
      final trailVisible = _visibleCols[12];
      final trailW       = trailVisible ? _colW[12] : 0.0;
      final scrollColW   = _scrollableMinW;
      final availW       = (bc.maxWidth.isFinite ? bc.maxWidth : scrollColW) - fixedW - trailW;
      final scrollMinW   = math.max(scrollColW, availW > 0 ? availW : scrollColW);

      const headerStyle  = TextStyle(color: Color(0xFFF5F8FF), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.18, height: 1);
      const headerGrad   = BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A518A), Color(0xFF23477A)]),
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      );

      // ── Données ligne par ligne ──────────────────────────────────────────
      final fixedCells      = <Widget>[];
      final scrollableCells = <Widget>[];
      final trailCells      = <Widget>[];

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

        // Col 0 — colonne figée
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

        // Cols 1-11 — zone défilante
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
        ];

        // Col 12 — colonne Actions figée à droite
        trailCells.add(SizedBox(
          height: _rowH,
          child: Material(
            color: rowBg,
            child: InkWell(
              onTap: onTap,
              hoverColor: hoverColor,
              child: Container(
                decoration: rowDeco,
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
            ),
          ),
        ));

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
            // ── En-tête ──────────────────────────────────────────────────────
            SizedBox(
              height: 40,
              child: Row(children: [
                // Cellule d'en-tête de la colonne figée
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
                // En-têtes défilants (cols 1-11)
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
                // En-tête Actions figé à droite
                if (trailVisible) Container(
                  width: trailW,
                  height: 40,
                  decoration: headerGrad.copyWith(
                    border: const Border(
                      bottom: BorderSide(color: Color(0x1AFFFFFF)),
                      left:   BorderSide(color: Color(0x33FFFFFF)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_colLabels[12], style: headerStyle, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ]),
            ),
            // ── Corps ────────────────────────────────────────────────────────
            Expanded(
              child: Row(children: [
                // Colonne Référence figée à gauche
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
                // Zone défilante (cols 1-11)
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
                // Colonne Actions figée à droite
                if (trailVisible) Container(
                  width: trailW,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: isDark ? const Color(0xFF304764) : const Color(0xFFD6E0EF))),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06), blurRadius: 10, offset: const Offset(-3, 0))],
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      controller: _vTrailCtrl,
                      child: Column(children: trailCells),
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

  Widget _buildCcr3Content(bool isDark) =>
      _Ccr3TabView(api: widget.api, isDark: isDark, hideAnalyseRapideTab: true);

}


// ─── CRR3-COREP — Onglet BIC avec saisie directe du PNB ──────────────────────

class _CorepTabView extends StatefulWidget {
  const _CorepTabView({required this.api, required this.isDark});
  final RwaApiService api;
  final bool isDark;

  @override
  State<_CorepTabView> createState() => _CorepTabViewState();
}

class _CorepTabViewState extends State<_CorepTabView> {
  int _view = 0;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  int _anneeN = DateTime.now().year - 1;
  OpRiskCalculResult? _result;

  DecisionPilotageResult? _decision;
  bool _decisionLoading = false;
  String? _decisionError;

  late final List<TextEditingController> _pnbCtrl; // 3 ctrl : index 0=N-2, 1=N-1, 2=N

  final _pSeuilIldc = TextEditingController();
  final _pCoef1     = TextEditingController();
  final _pCoef2     = TextEditingController();
  final _pCoef3     = TextEditingController();
  final _pSeuil1    = TextEditingController();
  final _pSeuil2    = TextEditingController();
  final _pMultRea   = TextEditingController();
  final _pTauxConv  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pnbCtrl = List.generate(3, (_) => TextEditingController());
    _load();
    _loadDecision();
  }

  @override
  void dispose() {
    for (final c in _pnbCtrl) { c.dispose(); }
    for (final c in [_pSeuilIldc, _pCoef1, _pCoef2, _pCoef3,
                     _pSeuil1, _pSeuil2, _pMultRea, _pTauxConv]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.calculeOpRiskBic(anneeN: _anneeN);
      _populatePnbCtrl(result);
      _populateParamControllers(result.params);
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadDecision() async {
    setState(() { _decisionLoading = true; _decisionError = null; });
    try {
      final result = await widget.api.fetchDecisionPilotage();
      if (mounted) setState(() { _decision = result; _decisionLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _decisionError = e.toString(); _decisionLoading = false; });
    }
  }

  void _populatePnbCtrl(OpRiskCalculResult r) {
    for (var i = 0; i < 3; i++) {
      final v = r.inputs[i].pnb;
      _pnbCtrl[i].text = v == 0 ? '' : v.toStringAsFixed(0);
    }
  }

  void _populateParamControllers(OpRiskParametres p) {
    _pSeuilIldc.text = (p.seuilIldc * 100).toStringAsFixed(4);
    _pCoef1.text     = (p.coefTranche1 * 100).toStringAsFixed(0);
    _pCoef2.text     = (p.coefTranche2 * 100).toStringAsFixed(0);
    _pCoef3.text     = (p.coefTranche3 * 100).toStringAsFixed(0);
    _pSeuil1.text    = p.seuil1Fcfa.toStringAsFixed(0);
    _pSeuil2.text    = p.seuil2Fcfa.toStringAsFixed(0);
    _pMultRea.text   = p.multiplicateurRea.toStringAsFixed(1);
    _pTauxConv.text  = p.tauxConversionEurFcfa.toStringAsFixed(3);
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

  Future<void> _saveInputs() async {
    if (_result == null) return;
    setState(() => _saving = true);
    try {
      for (var i = 0; i < 3; i++) {
        await widget.api.upsertBicInput(_result!.annees[i], {
          'pnb': _parse(_pnbCtrl[i]),
        });
      }
      final refreshed = await widget.api.calculeOpRiskBic(anneeN: _anneeN);
      _populatePnbCtrl(refreshed);
      if (mounted) {
        setState(() { _result = refreshed; _saving = false; _view = 1; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PNB sauvegardé — résultats mis à jour'),
          backgroundColor: Color(0xFF14A44D),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _saveParams() async {
    setState(() => _saving = true);
    try {
      final data = {
        'seuil_ildc': _parse(_pSeuilIldc) / 100,
        'coef_tranche1': _parse(_pCoef1) / 100,
        'coef_tranche2': _parse(_pCoef2) / 100,
        'coef_tranche3': _parse(_pCoef3) / 100,
        'seuil1_fcfa': _parse(_pSeuil1),
        'seuil2_fcfa': _parse(_pSeuil2),
        'multiplicateur_rea': _parse(_pMultRea),
        'taux_conversion_eur_fcfa': _parse(_pTauxConv),
      };
      final newParams = await widget.api.updateBicParametres(data);
      final refreshed = await widget.api.calculeOpRiskBic(anneeN: _anneeN);
      _populateParamControllers(newParams);
      _populatePnbCtrl(refreshed);
      if (mounted) {
        setState(() { _result = refreshed; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Paramètres mis à jour'),
          backgroundColor: Color(0xFF14A44D),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  bool get _dk => widget.isDark;
  Color get _border => _dk ? const Color(0xFF263856) : const Color(0xFFDDE7F5);
  Color get _card   => _dk ? const Color(0xFF101C32) : const Color(0xFFF6F9FF);
  Color get _surf   => _dk ? const Color(0xFF0D1A2E) : Colors.white;
  Color get _txt    => _dk ? Colors.white : const Color(0xFF1F2937);
  Color get _muted  => _dk ? const Color(0xFF8BA3C7) : const Color(0xFF6B7280);

  static const _kAccent = Color(0xFF2563EB);
  static const _kGreen  = Color(0xFF14A44D);
  static const _kRed    = Color(0xFFDC2626);

  String _fcfa(double v) {
    if (v == 0) return '0 FCFA';
    final abs = v.abs();
    final sign = v < 0 ? '−' : '';
    if (abs >= 1e9) return '$sign${(abs / 1e9).toStringAsFixed(3)} Md FCFA';
    if (abs >= 1e6) return '$sign${(abs / 1e6).toStringAsFixed(3)} M FCFA';
    return '$sign${abs.toStringAsFixed(2)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: Colors.red),
          const SizedBox(height: 8),
          Text('Impossible de charger les données BIC COREP', style: TextStyle(color: _txt)),
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _load,
              icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        const SizedBox(height: 10),
        Expanded(
          child: switch (_view) {
            0 => _buildSaisieView(),
            1 => _buildResultsView(),
            2 => _buildAnalyseRapideView(),
            3 => _buildParamsView(),
            _ => _buildDecisionView(),
          },
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final years = _result?.annees ?? [_anneeN - 2, _anneeN - 1, _anneeN];
    final yearLabel = '${years[0]} · ${years[1]} · ${years[2]}';

    Widget tab(int idx, IconData icon, String label) {
      final sel = _view == idx;
      return GestureDetector(
        onTap: () => setState(() => _view = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? _kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: sel ? Colors.white : _muted),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 11.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? Colors.white : _muted,
            )),
          ]),
        ),
      );
    }

    Widget yearBtn(IconData icon, VoidCallback onTap) => Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Icon(icon, size: 12, color: _kAccent),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border, width: 0.8),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_outlined, size: 14, color: _kAccent),
        const SizedBox(width: 6),
        Text('CRR3-COREP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            yearBtn(Icons.remove, () {
              setState(() { _anneeN--; _result = null; });
              _load();
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(yearLabel, style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: _kAccent)),
            ),
            yearBtn(Icons.add, () {
              setState(() { _anneeN++; _result = null; });
              _load();
            }),
          ]),
        ),
        const SizedBox(width: 14),
        tab(0, Icons.edit_note_outlined, 'Saisie PNB'),
        const SizedBox(width: 4),
        tab(1, Icons.analytics_outlined, 'Résultats'),
        const SizedBox(width: 4),
        tab(2, Icons.speed_outlined, 'Analyse rapide'),
        const SizedBox(width: 4),
        tab(3, Icons.tune_outlined, 'Paramètres'),
        const SizedBox(width: 4),
        tab(4, Icons.gavel_rounded, 'Décision'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0891B2).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.4)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.info_outline, size: 11, color: Color(0xFF0891B2)),
            SizedBox(width: 4),
            Text('Art. 315–321 CRR3 • PNB saisi directement',
              style: TextStyle(fontSize: 10, color: Color(0xFF0891B2), fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  // ── Vue Saisie : 3 champs PNB ─────────────────────────────────────────────────

  Widget _buildSaisieView() {
    final years = _result?.annees ?? [_anneeN - 2, _anneeN - 1, _anneeN];

    Widget pnbCell(int i) => SizedBox(
      height: 34,
      child: TextField(
        controller: _pnbCtrl[i],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 13, color: _txt),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(fontSize: 12, color: _muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          isDense: true,
          filled: true,
          fillColor: _surf,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: _kAccent, width: 1.5),
          ),
        ),
      ),
    );

    return Column(
      children: [
        // En-tête colonnes
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _card, border: Border.all(color: _border, width: 0.8)),
          child: Row(children: [
            const SizedBox(width: 260),
            for (var i = 0; i < 3; i++) ...[
              const SizedBox(width: 8),
              Expanded(child: Text(
                'N${i == 2 ? "" : i == 1 ? "−1" : "−2"} (${years[i]})',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: i == 2 ? _kAccent : _txt),
              )),
            ],
          ]),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: _surf,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              SizedBox(
                width: 260,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Produit Net Bancaire (PNB)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _txt)),
                  const SizedBox(height: 2),
                  Text('Montant annuel en FCFA', style: TextStyle(fontSize: 10.5, color: _muted)),
                ]),
              ),
              for (var i = 0; i < 3; i++) ...[
                const SizedBox(width: 8),
                Expanded(child: pnbCell(i)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0891B2).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Color(0xFF0891B2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Entrez le PNB (Produit Net Bancaire) pour chacune des 3 années. '
                'Le système appliquera les règles CRR3 (ILDC, SC, FC, BI, BIC) et la méthode BIA (15 % × PNB moyen). '
                'Pour saisir le détail des composantes, utilisez l\'onglet CCR3.',
                style: TextStyle(fontSize: 11, color: const Color(0xFF0891B2).withValues(alpha: 1.0)),
              ),
            ),
          ]),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Montants en FCFA', style: TextStyle(fontSize: 10.5, color: _muted)),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : _saveInputs,
              icon: _saving
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 15),
              label: Text(_saving ? 'Sauvegarde…' : 'Sauvegarder & Calculer'),
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
            ),
          ],
        ),
      ],
    );
  }

  // ── Vue Résultats (identique à CCR3) ─────────────────────────────────────────

  Widget _buildResultsView() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();

    if (r.donneesInsuffisantes) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: _muted),
          const SizedBox(height: 10),
          Text('Aucun PNB saisi', style: TextStyle(fontSize: 15, color: _txt)),
          const SizedBox(height: 4),
          Text('Entrez le PNB des 3 exercices dans l\'onglet Saisie PNB.',
              style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _view = 0),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Aller à la Saisie'),
          ),
        ]),
      );
    }

    Widget kpiCard(String title, String value, {Color? valueColor, String? subtitle, IconData? icon}) =>
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surf, border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 14, color: _muted), const SizedBox(width: 5)],
              Expanded(child: Text(title,
                style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: valueColor ?? _txt)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 10.5, color: _muted)),
            ],
          ]),
        );

    Widget detailRow(String label, String value, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(
              fontSize: 11.5, color: bold ? _txt : _muted,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
            Text(value, style: TextStyle(
              fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: color ?? _txt)),
          ]),
        );

    Widget detailCard(String title, Color accent, List<Widget> rows) =>
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _surf, border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Text(title, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
            ),
            ...rows,
            const SizedBox(height: 4),
          ]),
        );

    final bi   = r.biDetail;
    final ildc = r.ildcDetail;
    final sc   = r.scDetail;
    final fc   = r.fcDetail;

    final trancheLabel = 'Tranche ${bi.trancheActive} '
        '(${bi.trancheActive == 1 ? "${(r.params.coefTranche1 * 100).toStringAsFixed(0)} %" :
           bi.trancheActive == 2 ? "${(r.params.coefTranche2 * 100).toStringAsFixed(0)} %" :
           "${(r.params.coefTranche3 * 100).toStringAsFixed(0)} %"})';

    final ecartPos = r.ecart >= 0;

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth >= 700 ? 4 : 2;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              kpiCard('OFR CRR3 (BIC)', _fcfa(r.ofrCrr3),
                  valueColor: _kAccent, icon: Icons.shield_outlined,
                  subtitle: 'Fonds propres min. requis'),
              kpiCard('REA CRR3', _fcfa(r.reaCrr3),
                  icon: Icons.bar_chart_outlined,
                  subtitle: '× ${r.params.multiplicateurRea.toStringAsFixed(1)}'),
              kpiCard('Tranche BIC', trancheLabel,
                  icon: Icons.layers_outlined,
                  valueColor: bi.trancheActive == 1 ? _kGreen :
                              bi.trancheActive == 2 ? Colors.orange : _kRed,
                  subtitle: bi.margeAvantTrancheSuivante != null
                      ? 'Marge : ${_fcfa(bi.margeAvantTrancheSuivante!)}'
                      : 'Tranche maximale'),
              kpiCard('Écart CRR3 − BIA', _fcfa(r.ecart),
                  icon: Icons.compare_arrows_outlined,
                  valueColor: ecartPos ? _kRed : _kGreen,
                  subtitle: ecartPos ? 'CRR3 > BIA' : 'CRR3 < BIA (favorable)'),
            ],
          );
        }),
        const SizedBox(height: 12),

        detailCard('ILDC — Intérêts, Leasing & Dividendes', _kAccent, [
          detailRow('IC = moy(IP − IV)', _fcfa(ildc.ic)),
          detailRow('AC = moy(Tréso + Créances − Provisions)', _fcfa(ildc.ac)),
          detailRow('Plafond ILDC  (AC × ${(r.params.seuilIldc * 100).toStringAsFixed(4)} %)', _fcfa(ildc.plafondIldc)),
          if (ildc.plafondActif)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
                  SizedBox(width: 5),
                  Text('Plafond ILDC actif — ABS(IC) > AC×seuil',
                    style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          detailRow('Dividendes perçus (moy)', _fcfa(ildc.dividendes)),
          Divider(height: 1, color: _border),
          detailRow('ILDC retenu', _fcfa(ildc.ildc), bold: true, color: _kAccent),
        ]),

        detailCard('SC — Services', const Color(0xFF7C3AED), [
          detailRow('Autres produits exploitation (moy)', _fcfa(sc.oi)),
          detailRow('Autres charges exploitation (moy)', _fcfa(sc.oe)),
          detailRow('MAX(OI, OE) retenu', _fcfa(math.max(sc.oi, sc.oe))),
          detailRow('Commissions perçues (moy)', _fcfa(sc.fi)),
          detailRow('Commissions versées (moy)', _fcfa(sc.fe)),
          detailRow('MAX(FI, FE) retenu', _fcfa(math.max(sc.fi, sc.fe))),
          Divider(height: 1, color: _border),
          detailRow('SC retenu', _fcfa(sc.sc), bold: true, color: const Color(0xFF7C3AED)),
        ]),

        detailCard('FC — Financière', const Color(0xFFEA580C), [
          detailRow('ABS(Résultat Ptf négociation) moy', _fcfa(fc.tc)),
          detailRow('ABS(Résultat Ptf bancaire) moy', _fcfa(fc.bc)),
          Divider(height: 1, color: _border),
          detailRow('FC retenu', _fcfa(fc.fc), bold: true, color: const Color(0xFFEA580C)),
        ]),

        detailCard('BI & BIC', _kAccent, [
          detailRow('ILDC', _fcfa(ildc.ildc)),
          detailRow('SC', _fcfa(sc.sc)),
          detailRow('FC', _fcfa(fc.fc)),
          Divider(height: 1, color: _border),
          detailRow('Business Indicator (BI)', _fcfa(bi.bi), bold: true),
          detailRow(trancheLabel, _fcfa(bi.bic), bold: true, color: _kAccent),
          detailRow('OFR CRR3  (ILM = 1 par hypothèse)', _fcfa(r.ofrCrr3), bold: true, color: _kAccent),
          detailRow('REA CRR3  (×${r.params.multiplicateurRea.toStringAsFixed(1)})', _fcfa(r.reaCrr3), bold: true),
        ]),

        detailCard('Comparatif — Approche Indicateur de Base (BIA)', const Color(0xFF0891B2), [
          detailRow('OFR BIA  (15 % × PNB moy)', _fcfa(r.ofrBia)),
          detailRow('REA BIA', _fcfa(r.reaBia)),
          Divider(height: 1, color: _border),
          detailRow('Écart (CRR3 − BIA)', _fcfa(r.ecart), bold: true,
              color: r.ecart >= 0 ? _kRed : _kGreen),
        ]),
      ]),
    );
  }

  // ── Vue Analyse rapide (identique à CCR3) ─────────────────────────────────────

  Widget _buildAnalyseRapideView() {
    final r = _result;
    if (r == null || r.donneesInsuffisantes) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: _muted),
          const SizedBox(height: 10),
          Text('Aucune donnée disponible', style: TextStyle(fontSize: 15, color: _txt)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _view = 0),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Aller à la Saisie'),
          ),
        ]),
      );
    }
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildArKpiRow(r),
        const SizedBox(height: 12),
        _buildBiCompositionCard(r),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, bc) {
          final side = (bc.maxWidth - 12) / 2;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: side, child: _buildComparBarCard(
              'OFR — CRR3 vs BIA',
              [('OFR CRR3', r.ofrCrr3, _kAccent), ('OFR BIA', r.ofrBia, const Color(0xFF94A3B8))],
            )),
            const SizedBox(width: 12),
            SizedBox(width: side, child: _buildComparBarCard(
              'REA — CRR3 vs BIA',
              [('REA CRR3', r.reaCrr3, _kAccent), ('REA BIA', r.reaBia, const Color(0xFF94A3B8))],
            )),
          ]);
        }),
        const SizedBox(height: 12),
        _buildTranchePositionCard(r),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildArKpiRow(OpRiskCalculResult r) {
    final ecartPos = r.ecart > 0;
    final ecartColor = ecartPos ? _kRed : _kGreen;

    Widget card(String label, String value, {Color? valueColor, String? sub}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surf, border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: valueColor ?? _txt)),
              if (sub != null) Text(sub, style: TextStyle(fontSize: 9.5, color: _muted)),
            ]),
          ),
        );

    return Row(children: [
      card('OFR CRR3', _fcfa(r.ofrCrr3), valueColor: _kAccent),
      const SizedBox(width: 8),
      card('OFR BIA', _fcfa(r.ofrBia), valueColor: const Color(0xFF0891B2)),
      const SizedBox(width: 8),
      card('Écart', _fcfa(r.ecart), valueColor: ecartColor,
          sub: ecartPos ? 'CRR3 > BIA' : 'CRR3 ≤ BIA'),
      const SizedBox(width: 8),
      card('Tranche BIC', 'T${r.biDetail.trancheActive}',
          valueColor: r.biDetail.trancheActive == 1 ? _kGreen :
                      r.biDetail.trancheActive == 2 ? Colors.orange : _kRed),
    ]);
  }

  Widget _buildBiCompositionCard(OpRiskCalculResult r) {
    final total = r.biDetail.bi;
    Widget barRow(String label, double v, Color c) {
      final pct = total > 0 ? (v / total).clamp(0.0, 1.0) : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 11, color: _muted))),
          Expanded(
            child: LayoutBuilder(builder: (_, bc) => Stack(children: [
              Container(height: 16,
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(3))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 16, width: bc.maxWidth * pct,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(3)),
              ),
            ])),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 130, child: Text(_fcfa(v),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600))),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Composition du BI (Business Indicator)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
        const SizedBox(height: 10),
        barRow('ILDC', r.ildcDetail.ildc, _kAccent),
        barRow('SC', r.scDetail.sc, const Color(0xFF7C3AED)),
        barRow('FC', r.fcDetail.fc, const Color(0xFFEA580C)),
        Divider(height: 16, color: _border),
        Row(children: [
          Text('BI total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
          const Spacer(),
          Text(_fcfa(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kAccent)),
        ]),
      ]),
    );
  }

  Widget _buildComparBarCard(String title, List<(String, double, Color)> bars) {
    final maxV = bars.fold(0.0, (m, b) => math.max(m, b.$2));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _BicBarPainter(
              bars: bars,
              maxV: maxV > 0 ? maxV : 1,
              borderColor: _border,
              mutedColor: _muted,
              textColor: _txt,
              isDark: _dk,
            ),
            child: const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 8),
        ...bars.map((b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Container(width: 10, height: 10,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: b.$3, borderRadius: BorderRadius.circular(2))),
            Text(b.$1, style: TextStyle(fontSize: 11, color: _muted)),
            const Spacer(),
            Text(_fcfa(b.$2), style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: b.$3)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildTranchePositionCard(OpRiskCalculResult r) {
    final bi = r.biDetail;
    final s1 = r.params.seuil1Fcfa;
    final s2 = r.params.seuil2Fcfa;
    final biV = bi.bi;
    final maxRange = math.max(biV * 1.2, s2 * 1.1);

    Widget trancheBar(String label, double from, double to, Color c) {
      final pctFrom = (from / maxRange).clamp(0.0, 1.0);
      final pctTo   = (to   / maxRange).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w600))),
          Expanded(
            child: LayoutBuilder(builder: (_, bc) => SizedBox(
              height: 18,
              child: Stack(children: [
                Container(height: 18, decoration: BoxDecoration(
                  color: _border.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3))),
                Positioned(
                  left: bc.maxWidth * pctFrom,
                  width: bc.maxWidth * (pctTo - pctFrom),
                  top: 0, bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                if (biV > 0)
                  Positioned(
                    left: bc.maxWidth * (biV / maxRange).clamp(0.0, 1.0) - 1,
                    top: 0, bottom: 0,
                    child: Container(width: 2, color: _kRed),
                  ),
              ]),
            )),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Position Tranche BIC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
        const SizedBox(height: 4),
        Text('BI = ${_fcfa(biV)}   •   Seuils : ${_fcfa(s1)} / ${_fcfa(s2)}',
          style: TextStyle(fontSize: 11, color: _muted)),
        const SizedBox(height: 10),
        trancheBar('T1 (${(r.params.coefTranche1 * 100).toStringAsFixed(0)} %)', 0, s1, _kGreen),
        trancheBar('T2 (${(r.params.coefTranche2 * 100).toStringAsFixed(0)} %)', s1, s2, Colors.orange),
        trancheBar('T3 (${(r.params.coefTranche3 * 100).toStringAsFixed(0)} %)', s2, maxRange, _kRed),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text('Position BI actuelle', style: TextStyle(fontSize: 11, color: _muted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (bi.trancheActive == 1 ? _kGreen :
                      bi.trancheActive == 2 ? Colors.orange : _kRed).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Tranche ${bi.trancheActive} active',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: bi.trancheActive == 1 ? _kGreen :
                       bi.trancheActive == 2 ? Colors.orange : _kRed)),
          ),
        ]),
      ]),
    );
  }

  // ── Vue Décision — Analyse et reporting (dispositif UEMOA) ────────────────────

  Color _decisionColor(String niveau) {
    switch (niveau) {
      case 'Maîtrisé': return _kGreen;
      case 'Sous surveillance': return const Color(0xFFF59E0B);
      case 'Vigilance renforcée': return const Color(0xFFEA580C);
      default: return _kRed;
    }
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'conforme': return _kGreen;
      case 'attention': return const Color(0xFFF59E0B);
      default: return _kRed;
    }
  }

  IconData _statutIcon(String statut) {
    switch (statut) {
      case 'conforme': return Icons.check_circle_outline;
      case 'attention': return Icons.warning_amber_outlined;
      default: return Icons.error_outline;
    }
  }

  Widget _buildDecisionView() {
    if (_decisionLoading && _decision == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_decisionError != null && _decision == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: Colors.red),
          const SizedBox(height: 8),
          Text('Impossible de charger l\'analyse de pilotage', style: TextStyle(color: _txt)),
          const SizedBox(height: 4),
          Text(_decisionError!, style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _loadDecision,
              icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ]),
      );
    }
    final d = _decision!;
    final color = _decisionColor(d.niveauGlobal);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Verdict global ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, size: 32, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Niveau de pilotage : ', style: TextStyle(fontSize: 13, color: _muted)),
                  Text(d.niveauGlobal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('Score ${d.scoreGlobal}/${d.scoreMax}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Rafraîchir l\'analyse',
                    child: InkWell(
                      onTap: _decisionLoading ? null : _loadDecision,
                      child: Icon(Icons.refresh, size: 18,
                        color: _decisionLoading ? _muted.withValues(alpha: 0.4) : _muted),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(d.synthese, style: TextStyle(fontSize: 12, color: _txt, height: 1.4)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Organe de reporting ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surf, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Icon(Icons.account_balance_outlined, size: 20, color: _kAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Organe de reporting recommandé (Art. 313.b — seuils Pilier 2)',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _muted)),
                const SizedBox(height: 3),
                Text(d.organeReporting,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _txt)),
                const SizedBox(height: 3),
                Text(d.organeReportingMotif, style: TextStyle(fontSize: 11, color: _muted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Critères de décision ─────────────────────────────────────────────
        Text('Critères d\'analyse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _txt)),
        const SizedBox(height: 8),
        ...d.criteres.map((c) {
          final sc = _statutColor(c.statut);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surf, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_statutIcon(c.statut), size: 18, color: sc),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${c.code} — ${c.libelle}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                      child: Text(c.referenceReglementaire,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: sc)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('${c.valeurObservee}  •  seuil : ${c.seuilReference}',
                    style: TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 4),
                  Text(c.commentaire, style: TextStyle(fontSize: 11, color: _txt, height: 1.3)),
                ]),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),

        // ── Recommandations ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surf, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.checklist_outlined, size: 16, color: _kAccent),
              const SizedBox(width: 8),
              Text('Recommandations', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _txt)),
            ]),
            const SizedBox(height: 8),
            ...d.recommandations.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(Icons.arrow_right, size: 16, color: _muted),
                ),
                Expanded(child: Text(r, style: TextStyle(fontSize: 11.5, color: _txt, height: 1.35))),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Analyse générée le ${d.dateAnalyse}', style: TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Vue Paramètres (identique à CCR3) ─────────────────────────────────────────

  Widget _buildParamsView() {
    Widget paramField(TextEditingController ctrl, String label, String hint) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
              width: 280,
              child: Text(label, style: TextStyle(fontSize: 12, color: _txt))),
            SizedBox(
              width: 140,
              child: TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: _txt),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: _muted, fontSize: 11),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  filled: true, fillColor: _surf,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: _border)),
                  focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide(color: _kAccent, width: 1.5)),
                ),
              ),
            ),
          ]),
        );

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surf, border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paramètres du calcul BIC CRR3',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _txt)),
            const SizedBox(height: 4),
            Text('Art. 315–321 CRR3 (Règlement UE 2019/876 adapté BCEAO)',
              style: TextStyle(fontSize: 11, color: _muted)),
            const Divider(height: 20),
            paramField(_pSeuilIldc, 'Seuil plafond ILDC (%)', '2.26'),
            paramField(_pCoef1, 'Taux BIC Tranche 1 (%)', '12'),
            paramField(_pCoef2, 'Taux BIC Tranche 2 (%)', '18'),
            paramField(_pCoef3, 'Taux BIC Tranche 3 (%)', '24'),
            const Divider(height: 16),
            paramField(_pSeuil1, 'Seuil BI Tranche 1→2 (FCFA)', '0'),
            paramField(_pSeuil2, 'Seuil BI Tranche 2→3 (FCFA)', '0'),
            const Divider(height: 16),
            paramField(_pMultRea, 'Multiplicateur REA', '12.5'),
            paramField(_pTauxConv, 'Taux EUR→FCFA', '655.957'),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              FilledButton.icon(
                onPressed: _saving ? null : _saveParams,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 15),
                label: Text(_saving ? 'Sauvegarde…' : 'Enregistrer les paramètres'),
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}


// ─── CCR3 — Onglet BIC CRR3 ──────────────────────────────────────────────────

class _Ccr3TabView extends StatefulWidget {
  const _Ccr3TabView({
    required this.api,
    required this.isDark,
    this.onlyAnalyseRapide = false,
    this.hideAnalyseRapideTab = false,
  });
  final RwaApiService api;
  final bool isDark;
  /// Quand true, seul l'onglet "Analyse rapide" est accessible — Résultats,
  /// Saisie et Paramètres sont masqués (saisie/config à faire depuis UEMOI).
  final bool onlyAnalyseRapide;
  /// Quand true, le bouton "Analyse rapide" est masqué (les autres onglets
  /// restent accessibles) — utilisé sur l'écran Import de données.
  final bool hideAnalyseRapideTab;

  @override
  State<_Ccr3TabView> createState() => _Ccr3TabViewState();
}

class _Ccr3TabViewState extends State<_Ccr3TabView> {
  // Vues internes : 0 = Analyse rapide (par défaut), 1 = Résultats, 2 = Saisie, 3 = Paramètres
  int _view = 0;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  // Année N (dernier exercice clos) — modifiable par l'utilisateur
  int _anneeN = DateTime.now().year - 1;

  OpRiskCalculResult? _result;

  // Contrôleurs indexés par [yearIndex 0..2][fieldIndex 0..13]
  // Ordre des champs : voir _kFields
  late final List<List<TextEditingController>> _ctrl;

  // Contrôleurs paramètres
  final _pSeuilIldc     = TextEditingController();
  final _pCoef1         = TextEditingController();
  final _pCoef2         = TextEditingController();
  final _pCoef3         = TextEditingController();
  final _pSeuil1        = TextEditingController();
  final _pSeuil2        = TextEditingController();
  final _pMultRea       = TextEditingController();
  final _pTauxConv      = TextEditingController();

  static const _kFields = [
    // ILDC
    'interets_percus', 'interets_verses', 'dividendes_percus',
    'tresorerie_et_banques_centrales', 'creances_etablissements_credit',
    'creances_clientele', 'provisions',
    // SC
    'autres_produits_exploitation', 'autres_charges_exploitation',
    'commissions_percues', 'commissions_versees',
    // FC
    'resultat_portefeuille_negociation', 'resultat_portefeuille_bancaire',
    // BIA
    'pnb',
  ];

  static const _kLabels = [
    'Intérêts perçus', 'Intérêts versés', 'Dividendes perçus',
    'Trésorerie & Banques centrales', 'Créances sur Étab. de crédit',
    'Créances clientèle (brut)', 'Provisions sur créances',
    'Autres produits d\'exploitation', 'Autres charges d\'exploitation',
    'Commissions perçues', 'Commissions versées',
    'Résultat net Ptf négociation', 'Résultat net Ptf bancaire',
    'PNB (Produit Net Bancaire)',
  ];

  static const _kSections = [
    ('ILDC (Composante Intérêts, Leasing & Dividendes)', 0, 7),
    ('SC (Composante Services)', 7, 11),
    ('FC (Composante Financière)', 11, 13),
    ('BIA (Comparatif Indicateur de Base)', 13, 14),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = List.generate(3, (_) =>
        List.generate(_kFields.length, (_) => TextEditingController()));
    _load();
  }

  @override
  void dispose() {
    for (final row in _ctrl) {
      for (final c in row) { c.dispose(); }
    }
    for (final c in [_pSeuilIldc, _pCoef1, _pCoef2, _pCoef3,
                     _pSeuil1, _pSeuil2, _pMultRea, _pTauxConv]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.calculeOpRiskBic(anneeN: _anneeN);
      _populateControllers(result);
      _populateParamControllers(result.params);
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _populateControllers(OpRiskCalculResult r) {
    for (var yi = 0; yi < 3; yi++) {
      final inp = r.inputs[yi];
      final vals = [
        inp.interetsPercus, inp.interetsVerses, inp.dividendesPercus,
        inp.tresorerie, inp.creancesEtabCredit, inp.creancesClientele, inp.provisions,
        inp.autresProduits, inp.autresCharges,
        inp.commissionsPercues, inp.commissionsVersees,
        inp.resPfNegociation, inp.resPfBancaire,
        inp.pnb,
      ];
      for (var fi = 0; fi < _kFields.length; fi++) {
        _ctrl[yi][fi].text = vals[fi] == 0 ? '' : vals[fi].toStringAsFixed(0);
      }
    }
  }

  void _populateParamControllers(OpRiskParametres p) {
    _pSeuilIldc.text  = _roTrim(p.seuilIldc * 100, maxDecimals: 4);
    _pCoef1.text      = (p.coefTranche1 * 100).toStringAsFixed(0);
    _pCoef2.text      = (p.coefTranche2 * 100).toStringAsFixed(0);
    _pCoef3.text      = (p.coefTranche3 * 100).toStringAsFixed(0);
    _pSeuil1.text     = p.seuil1Fcfa.toStringAsFixed(0);
    _pSeuil2.text     = p.seuil2Fcfa.toStringAsFixed(0);
    _pMultRea.text    = p.multiplicateurRea.toStringAsFixed(1);
    _pTauxConv.text   = p.tauxConversionEurFcfa.toStringAsFixed(3);
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

  Future<void> _saveInputs() async {
    if (_result == null) return;
    setState(() => _saving = true);
    try {
      for (var yi = 0; yi < 3; yi++) {
        final annee = _result!.annees[yi];
        final data = <String, dynamic>{};
        for (var fi = 0; fi < _kFields.length; fi++) {
          data[_kFields[fi]] = _parse(_ctrl[yi][fi]);
        }
        await widget.api.upsertBicInput(annee, data);
      }
      final refreshed = await widget.api.calculeOpRiskBic();
      _populateControllers(refreshed);
      if (mounted) {
        setState(() { _result = refreshed; _saving = false; _view = 1; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Données sauvegardées — résultats mis à jour'),
          backgroundColor: Color(0xFF14A44D),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _saveParams() async {
    setState(() => _saving = true);
    try {
      final data = {
        'seuil_ildc': _parse(_pSeuilIldc) / 100,
        'coef_tranche1': _parse(_pCoef1) / 100,
        'coef_tranche2': _parse(_pCoef2) / 100,
        'coef_tranche3': _parse(_pCoef3) / 100,
        'seuil1_fcfa': _parse(_pSeuil1),
        'seuil2_fcfa': _parse(_pSeuil2),
        'multiplicateur_rea': _parse(_pMultRea),
        'taux_conversion_eur_fcfa': _parse(_pTauxConv),
      };
      final newParams = await widget.api.updateBicParametres(data);
      final refreshed = await widget.api.calculeOpRiskBic();
      _populateParamControllers(newParams);
      _populateControllers(refreshed);
      if (mounted) {
        setState(() { _result = refreshed; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Paramètres mis à jour'),
          backgroundColor: Color(0xFF14A44D),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Couleurs thème ────────────────────────────────────────────────────────────
  bool get _dk => widget.isDark;
  Color get _border => _dk ? const Color(0xFF263856) : const Color(0xFFDDE7F5);
  Color get _card   => _dk ? const Color(0xFF101C32) : const Color(0xFFF6F9FF);
  Color get _surf   => _dk ? const Color(0xFF0D1A2E) : Colors.white;
  Color get _txt    => _dk ? Colors.white : const Color(0xFF1F2937);
  Color get _muted  => _dk ? const Color(0xFFC7D5EA) : const Color(0xFF3F4C5E);

  static const _kAccent = Color(0xFF2563EB);
  static const _kGreen  = Color(0xFF14A44D);
  static const _kRed    = Color(0xFFDC2626);

  String _fcfa(double v) {
    if (v == 0) return '0 FCFA';
    final abs = v.abs();
    final sign = v < 0 ? '−' : '';
    if (abs >= 1e9) return '$sign${(abs / 1e9).toStringAsFixed(3)} Md FCFA';
    if (abs >= 1e6) return '$sign${(abs / 1e6).toStringAsFixed(3)} M FCFA';
    return '$sign${abs.toStringAsFixed(2)} FCFA';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: Colors.red),
          const SizedBox(height: 8),
          Text('Impossible de charger les données BIC', style: TextStyle(color: _txt)),
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        const SizedBox(height: 10),
        Expanded(
          child: widget.onlyAnalyseRapide
              ? _buildAnalyseRapideView()
              : switch (_view) {
                  0 => _buildAnalyseRapideView(),
                  1 => _buildResultsView(),
                  2 => _buildSaisieView(),
                  _ => _buildParamsView(),
                },
        ),
      ],
    );
  }

  // ── Barre de navigation ───────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final years = _result?.annees ?? [_anneeN - 2, _anneeN - 1, _anneeN];
    final yearLabel = '${years[0]} · ${years[1]} · ${years[2]}';

    Widget tab(int idx, IconData icon, String label) {
      final sel = _view == idx;
      const glow = Color(0xFF3B5BFF);
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _view = idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: sel
                    ? const [Color(0xFF4A6BFF), Color(0xFF1830B8)]
                    : const [Color(0xFF16213E), Color(0xFF0B1226)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: sel ? const Color(0xFF8FA5FF) : glow.withValues(alpha: 0.35),
                width: sel ? 1.3 : 1,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(color: glow.withValues(alpha: 0.28), blurRadius: 8, spreadRadius: 0),
                      BoxShadow(color: glow.withValues(alpha: 0.12), blurRadius: 14),
                    ]
                  : [
                      BoxShadow(color: glow.withValues(alpha: 0.06), blurRadius: 4),
                    ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label.toUpperCase(), style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 0.5,
              )),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined, size: 14, color: _kAccent),
          const SizedBox(width: 6),
          Text('BIC / CRR3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
          const SizedBox(width: 8),
          // Sélecteur d'années — cliquer sur − / + pour changer l'exercice N
          Container(
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _yearBtn(Icons.remove, () {
                setState(() { _anneeN--; _result = null; });
                _load();
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(yearLabel, style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: _kAccent)),
              ),
              _yearBtn(Icons.add, () {
                setState(() { _anneeN++; _result = null; });
                _load();
              }),
            ]),
          ),
          const SizedBox(width: 14),
          if (!widget.onlyAnalyseRapide) ...[
            if (!widget.hideAnalyseRapideTab) ...[
              tab(0, Icons.speed_outlined, 'Analyse rapide'),
              const SizedBox(width: 4),
            ],
            tab(2, Icons.edit_note_outlined, 'Saisie'),
            const SizedBox(width: 4),
            tab(1, Icons.analytics_outlined, 'Résultats'),
            const SizedBox(width: 4),
            tab(3, Icons.tune_outlined, 'Paramètres'),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  Widget _yearBtn(IconData icon, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(3),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Icon(icon, size: 12, color: _kAccent),
      ),
    ),
  );

  // ── Vue Saisie ────────────────────────────────────────────────────────────────

  Widget _buildSaisieView() {
    final years = _result?.annees ?? [0, 0, 0];

    Widget inputCell(int yi, int fi) => SizedBox(
      height: 40,
      child: TextField(
        controller: _ctrl[yi][fi],
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, color: _txt),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(fontSize: 11.5, color: _muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          isDense: true,
          filled: true,
          fillColor: _surf,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: _kAccent, width: 1.5),
          ),
        ),
      ),
    );

    Widget sectionHeader(String title, Color color) => Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border(
          left: BorderSide(color: color, width: 3),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: Text(title, style: TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );

    const sectionColors = [_kAccent, Color(0xFF7C3AED), Color(0xFFEA580C), Color(0xFF0891B2)];

    return Column(
      children: [
        // En-tête colonnes
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _card,
            border: Border.all(color: _border, width: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const SizedBox(width: 240, child: Text('Poste',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
              for (var yi = 0; yi < 3; yi++) ...[
                const SizedBox(width: 8),
                Expanded(child: Text('N${yi == 2 ? "" : yi == 1 ? "−1" : "−2"} (${years[yi]})',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: yi == 2 ? _kAccent : _txt))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Tableau saisie — une section = un bloc distinct
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final (title, from, to) in _kSections) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _surf,
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        sectionHeader(title, sectionColors[_kSections.indexOf(
                            _kSections.firstWhere((s) => s.$2 == from))]),
                        for (var fi = from; fi < to; fi++) ...[
                          if (fi > from) Divider(height: 1, color: _border),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 240,
                                  child: Text(_kLabels[fi],
                                    style: TextStyle(fontSize: 12, color: _txt),
                                    overflow: TextOverflow.ellipsis),
                                ),
                                for (var yi = 0; yi < 3; yi++) ...[
                                  const SizedBox(width: 8),
                                  Expanded(child: inputCell(yi, fi)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Bouton sauvegarde
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Montants en FCFA · valeurs absolues (positif = produit, négatif = charge pour FC)',
              style: TextStyle(fontSize: 10, color: _muted)),
            const Spacer(),
            MouseRegion(
              cursor: _saving ? SystemMouseCursors.basic : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _saving ? null : _saveInputs,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4A6BFF), Color(0xFF1830B8)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF8FA5FF), width: 1.3),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF3B5BFF).withValues(alpha: _saving ? 0.12 : 0.28), blurRadius: 8, spreadRadius: 0),
                      BoxShadow(color: const Color(0xFF3B5BFF).withValues(alpha: _saving ? 0.06 : 0.12), blurRadius: 14),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _saving
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 15, color: Colors.white),
                    const SizedBox(width: 8),
                    Text((_saving ? 'Sauvegarde…' : 'Sauvegarder & Calculer').toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Vue Résultats ─────────────────────────────────────────────────────────────

  Widget _buildResultsView() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();

    if (r.donneesInsuffisantes) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: _muted),
          const SizedBox(height: 10),
          Text('Aucune donnée saisie', style: TextStyle(fontSize: 15, color: _txt)),
          const SizedBox(height: 4),
          Text('Allez dans l\'onglet Saisie pour entrer les données des 3 exercices.',
              style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _view = 2),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Aller à la Saisie'),
          ),
        ]),
      );
    }

    Widget detailRow(String label, String value, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(
                fontSize: 11.5, color: bold ? _txt : _muted,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
              Text(value, style: TextStyle(
                fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color ?? _txt)),
            ],
          ),
        );

    Widget detailCard(String title, List<Widget> rows) =>
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _surf, border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: Text(title, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _txt)),
              ),
              ...rows,
              const SizedBox(height: 4),
            ],
          ),
        );

    final bi   = r.biDetail;
    final ildc = r.ildcDetail;
    final sc   = r.scDetail;
    final fc   = r.fcDetail;

    final trancheLabel = 'Tranche ${bi.trancheActive} '
        '(${bi.trancheActive == 1 ? "${(r.params.coefTranche1 * 100).toStringAsFixed(0)} %" :
           bi.trancheActive == 2 ? "${(r.params.coefTranche2 * 100).toStringAsFixed(0)} %" :
           "${(r.params.coefTranche3 * 100).toStringAsFixed(0)} %"})';

    final detailCards = <Widget>[
      // Détail ILDC
      detailCard('ILDC (Intérêts, Leasing & Dividendes)', [
        detailRow('IC = moy(IP − IV)', _fcfa(ildc.ic)),
        detailRow('AC = moy(Tréso + Créances − Provisions)', _fcfa(ildc.ac)),
        detailRow('Plafond ILDC  (AC × ${(r.params.seuilIldc * 100).toStringAsFixed(4)} %)', _fcfa(ildc.plafondIldc)),
        if (ildc.plafondActif)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
                SizedBox(width: 5),
                Text('Plafond ILDC actif (ABS(IC) > AC×seuil)',
                  style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        detailRow('Dividendes perçus (moy)', _fcfa(ildc.dividendes)),
        Divider(height: 1, color: _border),
        detailRow('ILDC retenu', _fcfa(ildc.ildc), bold: true),
      ]),

      // Détail SC
      detailCard('SC (Services)', [
        detailRow('Autres produits exploitation (moy)', _fcfa(sc.oi)),
        detailRow('Autres charges exploitation (moy)', _fcfa(sc.oe)),
        detailRow('MAX(OI, OE) retenu', _fcfa(math.max(sc.oi, sc.oe))),
        detailRow('Commissions perçues (moy)', _fcfa(sc.fi)),
        detailRow('Commissions versées (moy)', _fcfa(sc.fe)),
        detailRow('MAX(FI, FE) retenu', _fcfa(math.max(sc.fi, sc.fe))),
        Divider(height: 1, color: _border),
        detailRow('SC retenu', _fcfa(sc.sc), bold: true),
      ]),

      // Détail FC
      detailCard('FC (Financière)', [
        detailRow('ABS(Résultat Ptf négociation) moy', _fcfa(fc.tc)),
        detailRow('ABS(Résultat Ptf bancaire) moy', _fcfa(fc.bc)),
        Divider(height: 1, color: _border),
        detailRow('FC retenu', _fcfa(fc.fc), bold: true),
      ]),

      // BI et BIC
      detailCard('BI & BIC', [
        detailRow('ILDC', _fcfa(ildc.ildc)),
        detailRow('SC', _fcfa(sc.sc)),
        detailRow('FC', _fcfa(fc.fc)),
        Divider(height: 1, color: _border),
        detailRow('Business Indicator (BI)', _fcfa(bi.bi), bold: true),
        detailRow(trancheLabel, _fcfa(bi.bic), bold: true),
        detailRow('OFR CRR3  (ILM = 1 par hypothèse)', _fcfa(r.ofrCrr3), bold: true),
        detailRow('REA CRR3  (×${r.params.multiplicateurRea.toStringAsFixed(1)})', _fcfa(r.reaCrr3), bold: true),
      ]),

      // Comparatif BIA
      detailCard('Comparatif (Approche Indicateur de Base, BIA)', [
        detailRow('OFR BIA  (15 % × PNB moy)', _fcfa(r.ofrBia)),
        detailRow('REA BIA', _fcfa(r.reaBia)),
        Divider(height: 1, color: _border),
        detailRow('Écart (CRR3 − BIA)', _fcfa(r.ecart), bold: true,
            color: r.ecart >= 0 ? _kRed : _kGreen),
      ]),
    ];

    return SingleChildScrollView(
      child: LayoutBuilder(builder: (_, bc) {
        final compact = bc.maxWidth < 700;
        if (compact) {
          return Column(
            children: [
              for (final card in detailCards) ...[
                card,
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        // Regroupe les cartes par paire ; chaque paire est étirée à la même
        // hauteur (celle de la carte la plus haute) grâce à IntrinsicHeight.
        final rows = <Widget>[];
        for (var i = 0; i < detailCards.length; i += 2) {
          final isLastAlone = i == detailCards.length - 1;
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: isLastAlone
                    ? [Expanded(child: detailCards[i]), const Spacer()]
                    : [
                        Expanded(child: detailCards[i]),
                        const SizedBox(width: 12),
                        Expanded(child: detailCards[i + 1]),
                      ],
              ),
            ),
          );
          rows.add(const SizedBox(height: 12));
        }
        return Column(children: rows);
      }),
    );
  }

  // ── Vue Analyse rapide ───────────────────────────────────────────────────────

  Widget _buildAnalyseRapideView() {
    final r = _result;
    if (r == null || r.donneesInsuffisantes) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: _muted),
          const SizedBox(height: 10),
          Text('Aucune donnée disponible', style: TextStyle(fontSize: 15, color: _txt)),
          const SizedBox(height: 4),
          if (widget.onlyAnalyseRapide)
            Text('La saisie se fait depuis la section UEMOI.',
                style: TextStyle(fontSize: 11.5, color: _muted))
          else ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _view = 2),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Aller à la Saisie'),
            ),
          ],
        ]),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1 — KPI cards
          _buildArKpiRow(r),
          const SizedBox(height: 12),
          // 2 — Composition BI
          _buildBiCompositionCard(r),
          const SizedBox(height: 12),
          // 3 — OFR + REA comparaison côte à côte
          LayoutBuilder(builder: (_, bc) {
            final side = (bc.maxWidth - 12) / 2;
            final c = DashColors.of(context);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: side, child: _buildComparBarCard(
                'OFR (CRR3 vs BIA)',
                [('OFR CRR3', r.ofrCrr3, c.accent), ('OFR BIA', r.ofrBia, c.navy)],
              )),
              const SizedBox(width: 12),
              SizedBox(width: side, child: _buildComparBarCard(
                'REA (CRR3 vs BIA)',
                [('REA CRR3', r.reaCrr3, c.accent), ('REA BIA', r.reaBia, c.navy)],
              )),
            ]);
          }),
          const SizedBox(height: 12),
          // 4 — Position tranche
          _buildTranchePositionCard(r),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── 1. KPI cards ──────────────────────────────────────────────────────────────

  Widget _buildArKpiRow(OpRiskCalculResult r) {
    final ecartPos = r.ecart > 0;
    final ecartColor = ecartPos ? _kRed : _kGreen;
    final bi = r.biDetail;
    final trancheLabel = 'Tranche ${bi.trancheActive} '
        '(${bi.trancheActive == 1 ? "${(r.params.coefTranche1 * 100).toStringAsFixed(0)} %" :
           bi.trancheActive == 2 ? "${(r.params.coefTranche2 * 100).toStringAsFixed(0)} %" :
           "${(r.params.coefTranche3 * 100).toStringAsFixed(0)} %"})';

    return Row(children: [
      Expanded(child: _RoHeroStatCard(
        label: 'OFR CRR3',
        value: _roAmount(context, r.ofrCrr3),
        valueColor: _kAccent,
        subtitle: 'Besoin en fonds propres',
      )),
      const SizedBox(width: 12),
      Expanded(child: _RoHeroStatCard(
        label: 'REA CRR3',
        value: _roAmount(context, r.reaCrr3),
        subtitle: '× ${r.params.multiplicateurRea.toStringAsFixed(1)}',
      )),
      const SizedBox(width: 12),
      Expanded(child: _RoHeroStatCard(
        label: 'OFR BIA',
        value: _roAmount(context, r.ofrBia),
        subtitle: '15 % × PNB moy',
      )),
      const SizedBox(width: 12),
      Expanded(child: _RoHeroStatCard(
        label: 'Écart OFR (CRR3 − BIA)',
        value: '${r.ecart > 0 ? "+" : ""}${_roAmount(context, r.ecart)}',
        valueColor: ecartColor,
        subtitle: ecartPos ? 'CRR3 > BIA (défavorable)' : 'CRR3 < BIA (favorable)',
      )),
      const SizedBox(width: 12),
      Expanded(child: _RoHeroStatCard(
        label: 'Tranche BIC',
        value: trancheLabel,
        valueColor: bi.trancheActive == 1 ? _kGreen :
                    bi.trancheActive == 2 ? Colors.orange : _kRed,
        subtitle: bi.margeAvantTrancheSuivante != null
            ? 'Marge : ${_roAmount(context, bi.margeAvantTrancheSuivante!)}'
            : 'Tranche maximale',
      )),
    ]);
  }

  // ── 2. Composition du BI ──────────────────────────────────────────────────────

  Widget _buildBiCompositionCard(OpRiskCalculResult r) {
    final c = DashColors.of(context);
    final ildc = r.ildcDetail.ildc;
    final sc   = r.scDetail.sc;
    final fc   = r.fcDetail.fc;
    final bi   = r.biDetail.bi;
    final total = bi > 0 ? bi : 1.0;

    final components = [
      ('ILDC', ildc, c.navy),
      ('SC',   sc,   c.accent),
      ('FC',   fc,   const Color(0xFF38BDF8)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf, border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Composition du Business Indicator (BI)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _txt)),
          const SizedBox(height: 12),
          // Barre empilée
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  for (final (_, v, c) in components)
                    if (v > 0)
                      Expanded(
                        flex: (v / total * 10000).round().clamp(1, 9999999),
                        child: Container(color: c),
                      ),
                  // espace vide si bi = 0
                  if (bi <= 0)
                    Expanded(child: Container(color: _border)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Légende
          Row(
            children: [
              for (final (lbl, v, c) in components) ...[
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: RichText(text: TextSpan(children: [
                    TextSpan(text: lbl,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                    TextSpan(
                        text: '  ${_roAmount(context, v)}  (${_roPct(v / total * 100)} %)',
                        style: TextStyle(fontSize: 10.5, color: _muted)),
                  ])),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: _border),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.account_balance_wallet_outlined, size: 13, color: _muted),
            const SizedBox(width: 5),
            Text('BI total : ', style: TextStyle(fontSize: 11, color: _muted)),
            Text(_roAmount(context, bi),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _txt)),
          ]),
        ],
      ),
    );
  }

  // ── 3. Graphiques de comparaison verticaux ────────────────────────────────────

  Widget _buildComparBarCard(String title, List<(String, double, Color)> bars) {
    final maxV = bars.fold(0.0, (m, b) => math.max(m, b.$2));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf, border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: _txt)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _BicBarPainter(
                bars: bars,
                maxV: maxV,
                borderColor: _border,
                mutedColor: _muted,
                textColor: _txt,
                isDark: _dk,
              ),
              size: const Size(double.infinity, 150),
            ),
          ),
          const SizedBox(height: 8),
          // Légende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (lbl, v, c) in bars) ...[
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text('$lbl : ${_roAmount(context, v)}',
                    style: TextStyle(fontSize: 10.5, color: _muted)),
                const SizedBox(width: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Position dans la tranche ───────────────────────────────────────────────

  Widget _buildTranchePositionCard(OpRiskCalculResult r) {
    final bi   = r.biDetail.bi;
    final s1   = r.params.seuil1Fcfa;
    final s2   = r.params.seuil2Fcfa;
    final t    = r.biDetail.trancheActive;
    final marge = r.biDetail.margeAvantTrancheSuivante;

    // Plafond de l'axe : s2 × 1.05 pour voir les 3 zones
    final axisMax = s2 * 1.05;
    double rel(double v) => (v / axisMax).clamp(0.0, 1.0);

    final biRel = rel(bi);
    final s1Rel = rel(s1);
    final s2Rel = rel(s2);

    // Couleur de la position selon la tranche active
    final biColor = t == 1 ? _kGreen : t == 2 ? Colors.orange : _kRed;

    Widget trancheRow(String label, double pct, Color color, double zoneStart, double zoneEnd) {
      final start = zoneStart.clamp(0.0, 1.0);
      final end = zoneEnd.clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
            width: 64,
            child: Text('$label (${pct.toStringAsFixed(0)} %)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (_, bc) {
              final w = bc.maxWidth;
              return SizedBox(
                height: 16,
                child: Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(color: _border.withValues(alpha: 0.5)),
                  ),
                  if (end > start)
                    Positioned(
                      left: start * w,
                      width: (end - start) * w,
                      top: 0, bottom: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(color: color),
                      ),
                    ),
                  Positioned(
                    left: (biRel * w - 1).clamp(0.0, w - 2),
                    top: 0, bottom: 0,
                    child: Container(width: 2, color: _kRed),
                  ),
                ]),
              );
            }),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surf, border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Position Tranche BIC',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _txt))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: biColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Tranche $t active',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: biColor)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('BI = ${_roAmount(context, bi)}  •  Seuils : ${_roAmount(context, s1)} / ${_roAmount(context, s2)}',
              style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 16),
          trancheRow('T1', r.params.coefTranche1 * 100, _kGreen, 0, s1Rel),
          trancheRow('T2', r.params.coefTranche2 * 100, Colors.orange, s1Rel, s2Rel),
          trancheRow('T3', r.params.coefTranche3 * 100, _kRed, s2Rel, 1.0),
          const SizedBox(height: 6),
          Row(children: [
            Container(width: 10, height: 10, color: _kRed),
            const SizedBox(width: 6),
            Text('Position BI actuelle', style: TextStyle(fontSize: 10.5, color: _muted)),
          ]),
          if (marge != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.arrow_forward_outlined, size: 12, color: _muted),
              const SizedBox(width: 5),
              Text('Marge avant tranche ${t + 1} : ${_roAmount(context, marge)}',
                  style: TextStyle(fontSize: 11, color: _muted)),
            ]),
          ] else ...[
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: _kRed),
              SizedBox(width: 5),
              Text('Tranche maximale atteinte',
                  style: TextStyle(fontSize: 11, color: _kRed, fontWeight: FontWeight.w600)),
            ]),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _arDot(Color c) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  // Format FCFA avec séparateur d'espace (format français)
  String _arFcfa(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '− ' : '';
    // Formatage entier avec espaces insécables comme séparateurs de milliers
    final str = abs.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );
    return '$sign$intPart,${parts[1]} FCFA';
  }

  // ── Vue Paramètres ────────────────────────────────────────────────────────────

  Widget _buildParamsView() {
    Widget paramField(TextEditingController ctrl, String label, String hint) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 280,
                child: Text(label, style: TextStyle(fontSize: 12, color: _txt))),
              const SizedBox(width: 10),
              SizedBox(
                width: 200,
                height: 34,
                child: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 12, color: _txt),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 11, color: _muted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    isDense: true,
                    filled: true, fillColor: _surf,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: _border)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(color: _kAccent, width: 1.5)),
                  ),
                ),
              ),
            ],
          ),
        );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surf, border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coefficients et seuils BIC', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _txt)),
                const SizedBox(height: 12),
                paramField(_pSeuilIldc, 'Seuil ILDC (%)', '2.25'),
                paramField(_pCoef1, 'Coefficient tranche 1 (%)', '12'),
                paramField(_pCoef2, 'Coefficient tranche 2 (%)', '15'),
                paramField(_pCoef3, 'Coefficient tranche 3 (%)', '18'),
                const SizedBox(height: 8),
                Divider(color: _border),
                const SizedBox(height: 8),
                Text('Seuils en FCFA  (Option A recommandée : parité EUR/FCFA fixe = 655,957)',
                    style: TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 8),
                paramField(_pSeuil1, 'Seuil 1 (FCFA)  ≈ 1 Md EUR', '655957000000'),
                paramField(_pSeuil2, 'Seuil 2 (FCFA)  ≈ 30 Mds EUR', '19678710000000'),
                paramField(_pTauxConv, 'Taux conversion EUR → FCFA', '655.957'),
                paramField(_pMultRea, 'Multiplicateur REA', '12.5'),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MouseRegion(
                      cursor: _saving ? SystemMouseCursors.basic : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _saving ? null : _saveParams,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF4A6BFF), Color(0xFF1830B8)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF8FA5FF), width: 1.3),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF3B5BFF).withValues(alpha: _saving ? 0.25 : 0.55), blurRadius: 14, spreadRadius: 0.5),
                              BoxShadow(color: const Color(0xFF3B5BFF).withValues(alpha: _saving ? 0.12 : 0.25), blurRadius: 26, spreadRadius: 2),
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _saving
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 15, color: Colors.white),
                            const SizedBox(width: 8),
                            Text((_saving ? 'Sauvegarde…' : 'Enregistrer les paramètres').toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 0.5)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Graphique comparaison barres verticales (Analyse rapide CRR3) ───────────

class _BicBarPainter extends CustomPainter {
  const _BicBarPainter({
    required this.bars,
    required this.maxV,
    required this.borderColor,
    required this.mutedColor,
    required this.textColor,
    required this.isDark,
  });

  final List<(String label, double value, Color color)> bars;
  final double maxV;
  final Color borderColor, mutedColor, textColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || maxV <= 0 || size.width < 60 || size.height < 40) return;

    const leftPad = 56.0;
    const bottomPad = 32.0;
    const topPad = 16.0;
    final chartW = size.width - leftPad - 8;
    final chartH = size.height - bottomPad - topPad;
    const chartL = leftPad;
    final chartB = size.height - bottomPad;
    const chartT = topPad;

    // Axe
    final axisPaint = Paint()
      ..color = mutedColor.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(chartL, chartT), Offset(chartL, chartB), axisPaint);
    canvas.drawLine(Offset(chartL, chartB), Offset(size.width - 8, chartB), axisPaint);

    // Grille horizontale (4 lignes)
    final gridPaint = Paint()
      ..color = borderColor.withValues(alpha: isDark ? 0.35 : 0.55)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 4; i++) {
      final y = chartB - chartH * i / 4;
      canvas.drawLine(Offset(chartL, y), Offset(size.width - 8, y), gridPaint);
      final tickVal = maxV * i / 4;
      _paintLabel(canvas, _shortNum(tickVal),
          Offset(0, y - 6), chartL - 4, TextAlign.right,
          mutedColor.withValues(alpha: 1.0), 8.5);
    }

    // Barres
    final nBars = bars.length;
    final groupW = chartW / nBars;
    final barW = (groupW * 0.50).clamp(16.0, 52.0);

    for (var i = 0; i < nBars; i++) {
      final (lbl, v, c) = bars[i];
      final centerX = chartL + groupW * (i + 0.5);
      final barH = chartH * (v / maxV).clamp(0.0, 1.0);
      final rect = Rect.fromLTWH(
        centerX - barW / 2, chartB - barH, barW, barH);
      final rRect = RRect.fromRectAndCorners(rect,
          topLeft: const Radius.circular(3), topRight: const Radius.circular(3));
      canvas.drawRRect(rRect, Paint()..color = c.withValues(alpha: 0.90)..style = PaintingStyle.fill);

      // Valeur au-dessus de la barre
      _paintLabel(canvas, _shortNum(v),
          Offset(centerX - groupW * 0.45, chartB - barH - 14),
          groupW * 0.9, TextAlign.center,
          c, 9.5, fontWeight: FontWeight.w700);

      // Étiquette sous l'axe
      _paintLabel(canvas, lbl,
          Offset(centerX - groupW * 0.45, chartB + 6),
          groupW * 0.9, TextAlign.center,
          mutedColor.withValues(alpha: 1.0), 9.0);
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset offset, double maxWidth,
      TextAlign align, Color color, double fontSize,
      {FontWeight fontWeight = FontWeight.w500}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
          fontSize: fontSize, color: color, fontWeight: fontWeight)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(minWidth: 0, maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  String _shortNum(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 1e9)  return '$sign${(abs / 1e9).toStringAsFixed(1)} Md';
    if (abs >= 1e6)  return '$sign${(abs / 1e6).toStringAsFixed(1)} M';
    if (abs >= 1e3)  return '$sign${(abs / 1e3).toStringAsFixed(1)} k';
    return '$sign${abs.toStringAsFixed(0)}';
  }

  @override
  bool shouldRepaint(covariant _BicBarPainter old) =>
      old.bars != bars || old.maxV != maxV || old.isDark != isDark;
}


// ─── Wizard — Déclarer un incident opérationnel ───────────────────────────────

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

  // Étape 1 — Identification
  final _dateCtrl = TextEditingController();
  String _ligne = _lignesMetier.first;
  String _type = _typesEvenement.first;

  // Étape 2 — Description
  final _descCtrl = TextEditingController();
  String _causeRacine = _causesRacine.first;

  // Étape 3 — Impact
  final _brutCtrl = TextEditingController();
  final _recupCtrl = TextEditingController();

  // Étape 4 — Validation
  String _statut = _statutsIncident.first;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  static const _stepLabels = ['Identification', 'Description', 'Impact', 'Validation'];
  static const _stepSubtitles = [
    'Date, ligne, type',
    'Détails et cause',
    'Pertes (FCFA)',
    'Récapitulatif',
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
              // En-tête
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
                        Text('Déclarer un incident', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('Risque opérationnel — Art. 313 BCEAO', style: TextStyle(fontSize: 11, color: _kMuted)),
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
              // Indicateur d'étapes
              _buildStepBar(),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Contenu de l'étape
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

  // ── Indicateur d'étapes horizontal ────────────────────────────────────────
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

  // ── Étape 1 : Identification ───────────────────────────────────────────────
  Widget _buildStep1() => Form(
    key: _step1Key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizBanner(
          icon: Icons.badge_outlined,
          title: 'Identification de l\'incident',
          subtitle: 'Art. 313.b — Déclarez dans les 5 jours ouvrés suivant la détection',
        ),
        const SizedBox(height: 16),
        _formSection('Quand et où ?', icon: Icons.calendar_today_rounded, color: _kDanger),
        _dateField(context, 'Date d\'occurrence', _dateCtrl, required: true),
        _formSection('Classification', icon: Icons.category_rounded, color: _kWarning),
        _formRow(
          _dropdown('Ligne de métier', _ligne, _lignesMetier,
            (v) { if (v != null) setState(() => _ligne = v); },
            required: true, icon: Icons.business_rounded),
          _dropdown('Type d\'événement', _type, _typesEvenement,
            (v) { if (v != null) setState(() => _type = v); },
            required: true, icon: Icons.label_rounded),
        ),
      ],
    ),
  );

  // ── Étape 2 : Description ─────────────────────────────────────────────────
  Widget _buildStep2() => Form(
    key: _step2Key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizBanner(
          icon: Icons.edit_note_outlined,
          title: 'Description et cause racine',
          subtitle: 'Décrivez précisément l\'incident et identifiez sa cause principale',
        ),
        const SizedBox(height: 16),
        _formSection('Que s\'est-il passé ?', icon: Icons.notes_rounded, color: _kBlue),
        _field('Description de l\'incident', _descCtrl, multiline: true, required: true,
          icon: Icons.description_rounded,
          hint: 'Que s\'est-il passé ? Quels systèmes / processus sont concernés ?'),
        _formSection('Analyse', icon: Icons.search_rounded, color: _kWarning),
        _dropdown('Cause racine identifiée', _causeRacine, _causesRacine,
          (v) { if (v != null) setState(() => _causeRacine = v); },
          icon: Icons.account_tree_rounded),
      ],
    ),
  );

  // ── Étape 3 : Impact financier ────────────────────────────────────────────
  Widget _buildStep3() => Form(
    key: _step3Key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizBanner(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Impact financier',
          subtitle: 'Art. 89 — Perte nette = Perte brute − Récupérations. Saisir en FCFA.',
        ),
        const SizedBox(height: 16),
        _formSection('Montants de perte', icon: Icons.monetization_on_rounded, color: _kDanger),
        _formRow(
          _field('Perte brute (FCFA)', _brutCtrl,
            keyboardType: TextInputType.number, required: true,
            icon: Icons.trending_down_rounded,
            hint: 'Montant total avant récupérations'),
          _field('Perte récupérée (FCFA)', _recupCtrl,
            keyboardType: TextInputType.number,
            icon: Icons.trending_up_rounded,
            hint: 'Assurances, provisions, reversements'),
        ),
        const SizedBox(height: 4),
        // Estimation BIA temps réel
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
                      Text('Estimation BIA (Art. 89) — indicative', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _biaKpi('Perte brute', AppFormatters.currency(brut))),
                      Expanded(child: _biaKpi('Perte nette', AppFormatters.currency(nette))),
                      Expanded(child: _biaKpi('Capital minimal (15 %)', AppFormatters.currency(kBia))),
                      Expanded(child: _biaKpi('RWA estimé', AppFormatters.currency(apr))),
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

  // ── Étape 4 : Récapitulatif + validation ──────────────────────────────────
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
          subtitle: 'Vérifiez les informations avant d\'enregistrer l\'incident',
        ),
        const SizedBox(height: 16),
        // Récapitulatif
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
              const Text('Récapitulatif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _kBlue)),
              const SizedBox(height: 12),
              _recap('Date d\'occurrence', _dateCtrl.text.isEmpty ? '—' : _dateCtrl.text),
              _recap('Ligne de métier', _ligne),
              _recap('Type d\'événement', _type),
              _recap('Cause racine', _causeRacine),
              _recap('Description', () {
                final s = _descCtrl.text.trim();
                return s.length > 90 ? '${s.substring(0, 87)}…' : (s.isEmpty ? '—' : s);
              }()),
              const Divider(height: 16),
              _recap('Perte brute', AppFormatters.currency(brut)),
              _recap('Perte récupérée', AppFormatters.currency(recup)),
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
                  'L\'incident sera ajouté à la base de pertes et inclus dans le calcul BIA (Art. 89).',
                  style: TextStyle(fontSize: 11, color: _kSuccess),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers visuels ───────────────────────────────────────────────────────
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

  // ── Boutons navigation ────────────────────────────────────────────────────
  Widget _buildNavRow() => Row(
    children: [
      if (_step > 1)
        OutlinedButton.icon(
          onPressed: _prev,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Précédent'),
          style: OutlinedButton.styleFrom(foregroundColor: _kMuted, side: const BorderSide(color: _kMuted)),
        ),
      const Spacer(),
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
      const SizedBox(width: 8),
      if (_step < _totalSteps)
        FilledButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: Text('Étape suivante ($_step/$_totalSteps)'),
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

// ─── Shared visual widgets ────────────────────────────────────────────────────

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
    if (s <= 16) return 'Élevé';
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
        // ── Axes + grille ─────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne gauche : label vertical + numéros P
            Column(children: [
              // Espace pour aligner avec le label "IMPACT →" + chiffres
              const SizedBox(height: 34),
              // Numéros P (5 → 1, top → bottom)
              ...List.generate(5, (pi) {
                final p = 5 - pi;
                return SizedBox(
                  height: cellSz + 3,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (pi == 2)
                      const RotatedBox(quarterTurns: -1,
                        child: Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text('PROBABILITÉ ↑',
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
                  const Text('IMPACT →',
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
                // Grille 5×5
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
                        excludeFromSemantics: true,
                        key: ValueKey('matrix_${p}_$impact'),
                        message: cnt == 0
                            ? 'P=$p × I=$impact = $score ($zl)\nAucun risque positionné ici'
                            : 'P=$p × I=$impact = $score ($zl)\n${names.join('\n')}',
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
                                      color: c.withValues(alpha: 1.0),
                                      fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                                ])
                              : Text('$score',
                                  style: TextStyle(fontSize: 10,
                                    color: c.withValues(alpha: 1.0),
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
        // ── Légende ───────────────────────────────────────────────────────
        Wrap(spacing: 10, runSpacing: 6, children: [
          _legendItem('Faible ≤4', _kSuccess),
          _legendItem('Moyen 5–9', _kWarning),
          _legendItem('Élevé 10–16', const Color(0xFFF97316)),
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

    // Légende
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

// ─── Suivi des incidents — mini-dashboard ────────────────────────────────────

class _IncidentsDashSection extends StatelessWidget {
  const _IncidentsDashSection({required this.data, required this.isWide});
  final RoDashboardData data;
  final bool isWide;

  static const _palette = <Color>[
    _kBlue,
    _kSuccess,
    _kWarning,
    _kDanger,
    AppColors.prudentialSolvency,
    AppColors.marketNeutral,
    Color(0xFFF97316),
    Color(0xFF84CC16),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lossesChart = DashPanel(
      title: 'Évolution des pertes',
      subtitle: 'Pertes brutes et nettes sur 12 mois',
      child: SizedBox(
        height: 190,
        child: data.evolutionPertes.isEmpty
            ? const Center(
                child: Text('Aucune donnée', style: TextStyle(color: _kMuted)))
            : CustomPaint(
                painter: _RoLineChartPainter(
                  dataBlue:
                      data.evolutionPertes.map((e) => e.perteBrute).toList(),
                  dataGreen:
                      data.evolutionPertes.map((e) => e.perteNette).toList(),
                  labels: data.evolutionPertes.map((e) => e.mois).toList(),
                ),
                size: Size.infinite,
              ),
      ),
    );

    final eventBars = DashPanel(
      title: "Typologie d'événements",
      subtitle: 'Répartition des incidents par nature',
      child: SizedBox(
        height: 190,
        child: data.repartitionType.isEmpty
            ? const Center(
                child: Text('Aucun incident', style: TextStyle(color: _kMuted)))
            : CustomPaint(
                painter: _RoVertBarChartPainter(
                  items: data.repartitionType,
                  isDark: isDark,
                  palette: _palette,
                ),
                size: Size.infinite,
              ),
      ),
    );

    final businessLines = DashPanel(
      title: 'Lignes de métier',
      subtitle: 'Poids relatif par périmètre',
      child: SizedBox(
        height: 180,
        child: data.repartitionLigneMetier.isEmpty
            ? const Center(
                child: Text('Aucun incident', style: TextStyle(color: _kMuted)))
            : _RoDonutChart(
                items: data.repartitionLigneMetier,
                palette: _palette,
                isDark: isDark,
              ),
      ),
    );

    final typeShare = DashPanel(
      title: 'Répartition par type',
      subtitle: 'Lecture synthétique des causes',
      child: data.repartitionType.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: Text('Aucun incident',
                      style: TextStyle(color: _kMuted))),
            )
          : _RoPieChart(items: data.repartitionType),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: lossesChart),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: eventBars),
              ],
            ),
          )
        else ...[
          lossesChart,
          const SizedBox(height: 16),
          eventBars,
        ],
        const SizedBox(height: 16),
        if (isWide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: businessLines),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: typeShare),
              ],
            ),
          )
        else ...[
          businessLines,
          const SizedBox(height: 16),
          typeShare,
        ],
      ],
    );
  }
}

// ─── Vertical bar chart ───────────────────────────────────────────────────────

class _RoVertBarChartPainter extends CustomPainter {
  const _RoVertBarChartPainter({
    required this.items,
    required this.isDark,
    required this.palette,
  });
  final List<RoRepartitionItem> items;
  final bool isDark;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    const padL = 8.0, padR = 8.0, padT = 18.0, padB = 36.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final maxV = items.map((e) => e.valeur).reduce(math.max).toDouble();
    if (maxV == 0) return;

    final slotW = w / items.length;
    final barW = slotW * 0.55;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Grille horizontale
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
          .withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = padT + h - (i / 4) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
    }

    for (var i = 0; i < items.length; i++) {
      final color = palette[i % palette.length];
      final barH = (items[i].valeur / maxV) * h;
      final x = padL + i * slotW + (slotW - barW) / 2;
      final y = padT + h - barH;

      // Fond de barre
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, padT, barW, h), const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: isDark ? 0.12 : 0.08),
      );

      // Barre remplie
      if (barH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, barW, barH), const Radius.circular(4)),
          Paint()
            ..shader = LinearGradient(
              colors: [color.withValues(alpha: 0.70), color],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTWH(x, y, barW, barH)),
        );
      }

      // Valeur au-dessus
      textPainter.text = TextSpan(
        text: '${items[i].valeur}',
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x + barW / 2 - textPainter.width / 2, y - 13));

      // Label X (tronqué à 7 chars)
      final lbl = items[i].label.length > 7
          ? '${items[i].label.substring(0, 7)}.'
          : items[i].label;
      textPainter.text = TextSpan(
        text: lbl,
        style: const TextStyle(color: _kMuted, fontSize: 7.5),
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(x + barW / 2 - textPainter.width / 2, padT + h + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _RoVertBarChartPainter old) =>
      old.items != items;
}

// ─── Donut chart ──────────────────────────────────────────────────────────────

class _RoDonutChart extends StatelessWidget {
  const _RoDonutChart({
    required this.items,
    required this.palette,
    required this.isDark,
  });
  final List<RoRepartitionItem> items;
  final List<Color> palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0, (s, e) => s + e.valeur);
    if (total == 0) return const SizedBox();

    final sorted = items.asMap().entries.toList()
      ..sort((a, b) => b.value.valeur.compareTo(a.value.valeur));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut avec taille explicite
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(
              items: items,
              palette: palette,
              total: total,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Légende
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var entry in sorted.take(6)) ...[
                Row(children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: palette[entry.key % palette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      entry.value.label,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(entry.value.valeur / total * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: palette[entry.key % palette.length],
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.items,
    required this.palette,
    required this.total,
    required this.isDark,
  });
  final List<RoRepartitionItem> items;
  final List<Color> palette;
  final int total;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeW = 18.0;
    double start = -math.pi / 2;

    for (var i = 0; i < items.length; i++) {
      final sweep = (items[i].valeur / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + 0.05,
        sweep - 0.10,
        false,
        Paint()
          ..color = palette[i % palette.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }

    // Total au centre
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$total\n',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
          const TextSpan(
            text: 'incidents',
            style: TextStyle(fontSize: 8, color: _kMuted),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: radius * 1.4);
    tp.paint(
        canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.total != total;
}

// ─── Table helpers ────────────────────────────────────────────────────────────

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


