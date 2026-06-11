// Ecran principal du module Risque Opérationnel — 10 vues.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/ro_models.dart';
import '../widgets/ro_import_pertes_dialog.dart';

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
const Color _kViolet = Color(0xFF7C3AED);
const Color _kCyan = Color(0xFF06B6D4);

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
      'Calcul des APR opérationnels — méthode Indicateur de Base (BIA).\n\n'
      'Formule BIA :\n'
      '  K_RO = α × PNBmoy₃\n'
      '  α = 15 %   (coefficient réglementaire BCEAO)\n'
      '  PNBmoy₃ = Σ PNBᵢ (positifs) / n   sur 3 derniers exercices\n'
      '  APR_opérationnel = K_RO ÷ 8 %   (facteur 12,5)',
  'Art. 301/307':
      'Exigences minimales en fonds propres (dispositif prudentiel BCEAO).\n\n'
      'Ratios réglementaires :\n'
      '  Ratio Tier 1 = Fonds propres de base / APR total  ≥ 5 %\n'
      '  Ratio global = Fonds propres totaux / APR total   ≥ 8 %\n'
      '  APR total = APR_crédit + APR_marché + APR_opérationnel\n'
      '  Coussin de conservation : + 2,5 % des APR (si applicable)',
  'Art. 545':
      'Stress testing — simulations de scénarios de crise pour évaluer\n'
      'la résilience du dispositif de gestion des risques.\n\n'
      'Scénarios types et formule d\'impact :\n'
      '  S1 : Optimiste  |  S2 : Neutre  |  S3 : Pessimiste  |  S4 : Crise\n'
      '  Impact net = Pertes simulées − (Provisions + Couverture assurance)\n'
      '  Résilience = Fonds propres disponibles − Pertes simulées  ≥ 0\n'
      '  Ratio de résistance = FP après choc / APR stressés  ≥ seuil',
  'Art. 546':
      'Rapport annuel sur le dispositif de gestion des risques opérationnels,\n'
      'transmis à la Commission Bancaire de l\'UMOA.\n\n'
      'Indicateurs clés à reporter :\n'
      '  • APR opérationnel = K_BIA × 12,5   (avec K_BIA = 15 % × PNBmoy₃)\n'
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
  return Tooltip(
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
    final (title, subtitle, artRef) = switch (view) {
      OperationalRiskView.dashboard   => ('Dashboard Opérationnel',    'KPI réglementaires et alertes (Art. 313)',                      'Art. 313'),
      OperationalRiskView.registre    => ('Registre des pertes RO',     'Registre BCEAO/UMOA — pertes, K_RO et APR (Art. 89 & 313.b)',  'Art. 89'),
      OperationalRiskView.incidents   => ('Simulation de crise',        'Stress testing PIEAFP — scénarios de vulnérabilité (Art. 545)', 'Art. 545'),
      OperationalRiskView.pertes      => ('Pertes opérationnelles',     'Base de pertes historiques — calcul APR BIA (Art. 89)',         'Art. 89'),
      OperationalRiskView.kri         => ('KRI',                        'Indicateurs clés de risque — surveillance continue (Art. 313)', 'Art. 313'),
      OperationalRiskView.cartographie=> ('Cartographie des risques',   'Identification et évaluation — matrice 5×5 (Art. 313)',         'Art. 313'),
      OperationalRiskView.controles   => ('Contrôles internes',         'Gestion des contrôles périodiques (Art. 314)',                  'Art. 314'),
      OperationalRiskView.workflow    => ('Workflow incidents',          'Pipeline de traitement des incidents (Art. 313.b)',             'Art. 313.b'),
      OperationalRiskView.plans       => ('Plans d\'actions',           'Actions correctives et préventives (Art. 313.c)',               'Art. 313.c'),
      OperationalRiskView.historique  => ('Historique événements',      'Journal de traçabilité (Art. 314) — 7 ans UMOA',               'Art. 314'),
      OperationalRiskView.reporting   => ('Reporting opérationnel',     'Génération des rapports réglementaires (Art. 313.c)',           'Art. 313.c'),
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
    return Padding(
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
    );
  }
}

// ─── Helpers partagés ─────────────────────────────────────────────────────────

Color _statutColor(String statut) => switch (statut) {
      'Ouvert' => _kDanger,
      'En cours' => _kWarning,
      'Résolu' => _kCyan,
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
  // => strip gauche coloré en interne via un Container(width:4)
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
                              Tooltip(
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
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: required ? (v) => v == null ? 'Champ requis' : null : null,
        ),
      ],
    ),
  );
}


// ─── VIEW 1 : DASHBOARD ───────────────────────────────────────────────────────

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
              Text('CONFORMITÉ RÉGLEMENTAIRE · BCEAO / UMOA',
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
              _bannerStat('K_RO', AppFormatters.currency(d.widget1.exigenceFondsPropres)),
              Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.22)),
              _bannerStat('APR', AppFormatters.currency(d.widget1.aprRisqueOp)),
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
              // Banner statut réglementaire
              _roStatusBanner(context, d),
              const SizedBox(height: 14),
              // Widget 1 — Situation réglementaire
              SectionCard(
                title: 'Situation réglementaire',
                child: Row(
                  children: [
                    Expanded(child: _kpiBox(context, 'Exigence fonds propres (K)', AppFormatters.currency(d.widget1.exigenceFondsPropres), Icons.account_balance_outlined, _kBlue,
                      tooltip: 'Capital réglementaire minimum (Art. 89)\nFormule : K_RO = 15 % × Perte nette totale\nα = 15 % (coefficient BCEAO/UMOA)',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'APR risque opérationnel', AppFormatters.currency(d.widget1.aprRisqueOp), Icons.bar_chart_outlined, _kViolet,
                      tooltip: 'Actifs Pondérés par le Risque opérationnel (Art. 89)\nFormule : APR = K_RO × 12,5\n12,5 = 1 ÷ 8 % (facteur de conversion prudentiel)',
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kpiBox(context, 'Statut réglementaire', d.widget1.statutReglementaire,
                          d.widget1.statutReglementaire == 'Conforme' ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                          d.widget1.statutReglementaire == 'Conforme' ? _kSuccess : _kDanger,
                          tooltip: 'Conformité réglementaire (Art. 313)\nConforme si ratio Tier 1 ≥ 5 % et ratio global ≥ 8 %\nAPR total = APR_crédit + APR_marché + APR_opérationnel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Widget 2 — Incidents
              SectionCard(
                title: 'Synthèse des incidents',
                trailing: _artInfo('Art. 313.b'),
                child: Row(
                  children: [
                    Expanded(child: _kpiBox(context, 'Incidents (mois)', '${d.widget2.totalIncidentsMois}', Icons.report_outlined, _kWarning,
                      tooltip: 'Nombre d\'incidents déclarés ce mois (Art. 313.b)\nFormule : COUNT(incidents) WHERE mois = mois_courant\nTout incident significatif doit être déclaré ≤ J+5',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'Pertes nettes (mois)', AppFormatters.currency(d.widget2.pertesNettesMois), Icons.trending_down_outlined, _kDanger,
                      tooltip: 'Pertes nettes du mois en cours (Art. 313.b)\nFormule : Σ (perte_brute − perte_récupérée)\npour les incidents du mois courant',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'Non clôturés', '${d.widget2.incidentsNonClos}', Icons.pending_outlined, _kCyan,
                      tooltip: 'Incidents encore ouverts ou en cours (Art. 313.b)\nFormule : COUNT(incidents) WHERE statut IN (Ouvert, En cours)\nCes incidents nécessitent un suivi actif',
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kpiBox(
                        context,
                        'Évolution / N-1',
                        d.widget2.evolutionPertesPct != null ? '${d.widget2.evolutionPertesPct! >= 0 ? '+' : ''}${d.widget2.evolutionPertesPct!.toStringAsFixed(1)} %' : 'N/A',
                        Icons.compare_arrows_outlined,
                        d.widget2.evolutionPertesPct != null && d.widget2.evolutionPertesPct! > 0 ? _kDanger : _kSuccess,
                        tooltip: 'Évolution des pertes vs même mois N-1\nFormule : ((Pertes_mois − Pertes_mois_N1) ÷ |Pertes_mois_N1|) × 100\n+ = dégradation   − = amélioration',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Widget 3 — Alertes
              SectionCard(
                title: 'Alertes et actions',
                trailing: _artInfo('Art. 313.c'),
                child: Row(
                  children: [
                    Expanded(child: _kpiBox(context, 'Actions en retard', '${d.widget3.actionsEnRetard}', Icons.alarm_outlined, d.widget3.actionsEnRetard > 0 ? _kDanger : _kSuccess,
                      tooltip: 'Plans d\'actions dont la date d\'échéance est dépassée et le statut ≠ «Terminé».\nFormule : COUNT(plans) WHERE date_echeance < aujourd\'hui AND statut ≠ \'Terminé\'.\nIndicateur de pilotage du suivi correctif. (Art. 313.c)')),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'Contrôles non conformes', '${d.widget3.controlesNonConformes}', Icons.rule_outlined, d.widget3.controlesNonConformes > 0 ? _kWarning : _kSuccess,
                      tooltip: 'Contrôles internes dont le résultat est évalué «Non-conforme» lors de la dernière exécution.\nFormule : COUNT(controles) WHERE resultat = \'Non-conforme\'.\nMesure la qualité du dispositif de contrôle. (Art. 314)')),
                    const SizedBox(width: 10),
                    Expanded(child: _kpiBox(context, 'KRI hors seuil', '${d.widget3.kriHorsSeuil}', Icons.speed_outlined, d.widget3.kriHorsSeuil > 0 ? _kDanger : _kSuccess,
                      tooltip: 'Indicateurs Clés de Risque (KRI) dont le statut est «alerte» ou «critique».\nFormule : COUNT(kri) WHERE statut IN (\'alerte\', \'critique\').\nSignale les expositions dépassant les limites tolérées. (Art. 89 / Art. 313)')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Widget 4 — Charts
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SectionCard(
                      title: 'Évolution des pertes (12 mois)',
                      child: SizedBox(
                        height: 180,
                        child: d.evolutionPertes.isEmpty
                            ? const Center(child: Text('Aucune donnée', style: TextStyle(color: _kMuted)))
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
                      title: 'Répartition par ligne de métier',
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
  final _seuilCtrl = TextEditingController(text: '8.0');

  bool _simulated = false;

  // (code, label, choc_losses_multiplier, accent_color)
  // S1 Optimiste : pertes ×0.90  (-10 %)
  // S2 Neutre    : pertes ×1.00  ( 0 %)
  // S3 Pessimiste: pertes ×1.20  (+20 %)
  // S4 Crise     : pertes ×1.35  (+35 %)
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
    for (final c in [_fpCtrl, _aprCtrl, _provCtrl, _assurCtrl, _seuilCtrl]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() => _simulated = [_fpCtrl, _aprCtrl, _provCtrl, _assurCtrl]
        .any((c) => c.text.trim().isNotEmpty));
  }

  @override
  void dispose() {
    for (final c in [_fpCtrl, _aprCtrl, _provCtrl, _assurCtrl, _seuilCtrl]) {
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
            // ── Bandeau réglementaire ─────────────────────────────────────────
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
                  'Art. 545 UMOA — Évaluation de la vulnérabilité à des événements exceptionnels mais plausibles (PIEAFP).\n'
                  'Base historique : ${items.length} incident(s) | Pertes nettes : ${AppFormatters.currency(pertesHisto)}',
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                )),
                _artInfo('Art. 545'),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Paramètres ────────────────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Paramètres de la simulation',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _simField('Fonds propres disponibles (FCFA)', _fpCtrl),
                        _simField('APR de référence (FCFA)',           _aprCtrl),
                        _simField('Provisions constituées (FCFA)',     _provCtrl),
                        _simField('Couverture assurance (FCFA)',       _assurCtrl),
                        _simField('Seuil ratio résistance (%)',        _seuilCtrl, width: 220),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Lancer la simulation'),
                        onPressed: () => setState(() => _simulated = true),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Résultats ─────────────────────────────────────────────────────
            if (_simulated) ...[
              const Text('Résultats — 4 scénarios BCEAO',
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
                      const Text('Saisissez au moins un paramètre pour lancer la simulation',
                        style: TextStyle(color: _kMuted, fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text('Les résultats s\'affichent automatiquement — tous les champs ne sont pas obligatoires',
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
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
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
    final seuil = (_d(_seuilCtrl) ?? 8.0) / 100;

    // Formules BCEAO Art. 545
    final pertesSimulees = pertesHisto * factor;
    final impactNet      = pertesSimulees - prov - assur;
    final fpApresChoc    = fp - (impactNet > 0 ? impactNet : 0);
    final resilience     = fp - pertesSimulees;
    final aprStresses    = apr > 0 ? apr * factor : 0.0;
    final ratio          = aprStresses > 0 ? fpApresChoc / aprStresses : 0.0;
    final pass           = resilience >= 0 && (apr == 0 || ratio >= seuil);

    final pctLabel = factor == 1.0 ? '0%' : factor < 1.0
        ? '−${((1 - factor) * 100).round()}% pertes'
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
          // En-tête scénario
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$code — $label  ($pctLabel)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (pass ? const Color(0xFF43A047) : _kDanger).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(pass ? '✓ RÉSILIENT' : '✗ VULNÉRABLE',
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
              Expanded(child: _mini('Pertes simulées',
                AppFormatters.currency(pertesSimulees),
                factor > 1.0 ? _kDanger : const Color(0xFF43A047))),
              const SizedBox(width: 8),
              Expanded(child: _mini('Impact net',
                AppFormatters.currency(impactNet),
                impactNet > 0 ? _kDanger : const Color(0xFF43A047))),
              const SizedBox(width: 8),
              Expanded(child: _mini('Résilience FP',
                AppFormatters.currency(resilience),
                resilience >= 0 ? const Color(0xFF43A047) : _kDanger)),
              if (apr > 0) ...[
                const SizedBox(width: 8),
                Expanded(child: _mini('Ratio résistance',
                  '${(ratio * 100).toStringAsFixed(1)}%',
                  ratio >= seuil ? const Color(0xFF43A047) : _kDanger,
                  sub: 'seuil ${(_d(_seuilCtrl) ?? 8.0).toStringAsFixed(1)}%')),
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

// ─── VIEW 3 : PERTES (conteneur avec onglets) ─────────────────────────────────

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
    (Icons.verified_user_outlined,         'Contrôles internes'),
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
                    tooltip: 'Somme des pertes avant déduction des montants récupérés.\nFormule : Σ perte_brute sur tous les incidents de la période.\nReprésenthe l\'exposition totale avant atténuation. (Art. 313.b)')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Perte nette totale', AppFormatters.currency(totalNette), Icons.trending_down, _kDanger,
                    tooltip: 'Somme des pertes réellement supportées après récupérations.\nFormule : Σ (perte_brute − perte_récupérée).\nC\'est la base de calcul du K_RO selon l\'approche BIA. (Art. 313.b / Art. 89)')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Taux de récupération', '${tauxRecup.toStringAsFixed(1)} %', Icons.savings_outlined, _kSuccess,
                    tooltip: 'Part des pertes brutes récupérée via assurances, provisions ou recours.\nFormule : (Σ perte_récupérée / Σ perte_brute) × 100.\nMesure l\'efficacité des mécanismes d\'atténuation.')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Pertes significatives', '$significatifs', Icons.warning_outlined, _kWarning,
                    tooltip: 'Incidents dont la perte brute dépasse le seuil de significativité.\nFormule : COUNT(incidents) WHERE perte_brute > seuil.\nPermet d\'identifier les événements à fort impact. (Art. 313.b)')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBox(ctx, 'Perte moyenne / incident', AppFormatters.currency(moyenne), Icons.calculate_outlined, _kMuted,
                    tooltip: 'Sévérité moyenne des pertes sur la période sélectionnée.\nFormule : Σ perte_nette / nombre d\'incidents.\nIndicateur de gravité unitaire des incidents opérationnels.')),
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
                                _tableHeader(['Référence', 'Description', 'Perte nette']),
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
                      title: 'Pertes par ligne de métier',
                      child: byLigne.isEmpty
                          ? const Padding(padding: EdgeInsets.all(16), child: Text('Aucune donnée.', style: TextStyle(color: _kMuted)))
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

// ─── VIEW 4 : KRI ─────────────────────────────────────────────────────────────

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

  Future<void> _addValeur(List<RoKriView> kris) async {
    String? kriId = kris.first.definition.id;
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final valCtrl = TextEditingController();
    final commCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              color: _kViolet.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(color: _kViolet.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kViolet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.speed_rounded, color: _kViolet, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Saisir une valeur KRI',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Indicateur de risque clé — mesure périodique',
                  style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w400)),
              ])),
            ]),
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formSection('Sélection de l\'indicateur', icon: Icons.speed_rounded, color: _kViolet),
                    _dropdown('Indicateur KRI', kriId, kris.map((k) => k.definition.id).toList(),
                      (v) => setD(() => kriId = v), required: true, icon: Icons.analytics_rounded,
                      hint: 'Choisir l\'indicateur à mesurer'),
                    _formSection('Mesure', icon: Icons.straighten_rounded, color: _kBlue),
                    _formRow(
                      _dateField(ctx, 'Date de mesure', dateCtrl, required: true),
                      _field('Valeur mesurée', valCtrl, keyboardType: TextInputType.number,
                        required: true, icon: Icons.numbers_rounded, hint: 'Ex: 2.5'),
                    ),
                    _field('Commentaire', commCtrl, icon: Icons.notes_rounded,
                      hint: 'Contexte ou explication de la mesure...'),
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
              style: FilledButton.styleFrom(backgroundColor: _kViolet),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await widget.api.addRoKriValeur({
                    'kri_id': kriId,
                    'date_mesure': dateCtrl.text.trim(),
                    'valeur': double.tryParse(valCtrl.text) ?? 0,
                    'commentaire': commCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger));
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoKriModuleData>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error!);
        final data = snap.data!;
        return Column(
          children: [
            Row(
              children: [
                _badge('${data.kriHorsSeuil} KRI hors seuil', data.kriHorsSeuil > 0 ? _kDanger : _kSuccess),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _addValeur(data.kriList),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Saisir valeur'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FixedColumnWidth(70),
                      2: FixedColumnWidth(90),
                      3: FixedColumnWidth(80),
                      4: FixedColumnWidth(80),
                      5: FixedColumnWidth(100),
                      6: FixedColumnWidth(100),
                    },
                    children: [
                      _tableHeader(['KRI', 'Unité', 'Seuil alerte', 'Fréq.', 'Dernière val.', 'Dernière date', 'Statut']),
                      ...data.kriList.map((k) {
                        final d = k.definition;
                        return TableRow(
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x11000000)))),
                          children: [
                            _cell(d.nom, bold: true),
                            _cell(d.unite),
                            _cell(d.sens == 'superieur' ? '> ${d.seuilAlerte}' : '< ${d.seuilAlerte}'),
                            _cell(d.frequence),
                            _cell(k.derniereValeur != null ? '${k.derniereValeur!.toStringAsFixed(1)} ${d.unite}' : 'N/A'),
                            _cell(k.derniereDate ?? 'N/A'),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: _kriStatutColor(k.statut), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(_kriStatutLabel(k.statut), style: TextStyle(color: _kriStatutColor(k.statut), fontWeight: FontWeight.w600, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
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
        return Column(
          children: [
            Row(
              children: [
                const Text('Matrice 5×5 — positionnement des risques identifiés', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add, size: 18), label: const Text('Nouveau risque')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Matrice heatmap
                _RoRiskMatrix(risques: items),
                const SizedBox(width: 16),
                // Liste des risques
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('Aucun risque enregistré.', style: TextStyle(color: _kMuted)))
                      : Card(
                          margin: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            child: Table(
                              columnWidths: const {0: FlexColumnWidth(2), 1: FixedColumnWidth(80), 2: FixedColumnWidth(70), 3: FixedColumnWidth(80), 4: FixedColumnWidth(80)},
                              children: [
                                _tableHeader(['Risque', 'Catégorie', 'Niveau brut', 'Niveau résiduel', 'Actions']),
                                ...items.map((r) => TableRow(
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x11000000)))),
                                  children: [
                                    _cell(r.nom, bold: true),
                                    _cell(r.categorie),
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Padding(padding: const EdgeInsets.all(8), child: _badge(r.niveauLabel, _niveauColor(r.niveauLabel))),
                                    ),
                                    _cell(r.niveauResiduel.toStringAsFixed(1)),
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showForm(edit: r)),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: _kDanger),
                                            onPressed: () => _confirm(context, 'Supprimer ce risque ?', () async { await widget.api.deleteRoRisque(r.id); _reload(); }),
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
            ),
          ],
        );
      },
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
              child: Card(
                margin: EdgeInsets.zero,
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
    'KRI'          => _kViolet,
    'Audit'        => _kCyan,
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
                color: _kCyan.withValues(alpha: 0.06),
                border: Border(bottom: BorderSide(color: _kCyan.withValues(alpha: 0.15))),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: _kCyan, size: 18),
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
                      _formSection('Identification du plan', icon: Icons.label_rounded, color: _kCyan),
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
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'AUD-2024-Q1',
                                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Sélectionner…',
                                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                style: FilledButton.styleFrom(backgroundColor: _kCyan),
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

  @override
  Widget build(BuildContext context) {
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
                _badge('Réalisation : ${txReal.toStringAsFixed(0)} %', txReal >= 80 ? _kSuccess : _kWarning),
                const Spacer(),
                FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add, size: 18), label: const Text('Nouveau plan')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: items.isEmpty
                    ? const Center(child: Text('Aucun plan d\'action enregistré.', style: TextStyle(color: _kMuted)))
                    : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(110), 1: FlexColumnWidth(2), 2: FixedColumnWidth(130), 3: FixedColumnWidth(80), 4: FixedColumnWidth(90), 5: FixedColumnWidth(100), 6: FixedColumnWidth(80), 7: FixedColumnWidth(90)},
                          children: [
                            _tableHeader(['Référence', 'Titre', 'Origine', 'Priorité', 'Responsable', 'Avancement', 'Statut', 'Actions']),
                            ...items.map((p) => TableRow(
                              decoration: BoxDecoration(
                                border: const Border(bottom: BorderSide(color: Color(0x11000000))),
                                color: p.enRetard ? _kDanger.withValues(alpha: 0.04) : null,
                              ),
                              children: [
                                // Référence + date échéance
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
                                // Colonne Origine — source + référence source
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
                                _cell(p.responsable.isEmpty ? '—' : p.responsable),
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
    'Terminé' => _kSuccess,
    'En cours' => _kBlue,
    'A faire' => _kMuted,
    'Abandonné' => _kDanger,
    _ => _kMuted,
  };
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

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchRoHistorique();
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('Journal non modifiable — conservation 7 ans (UMOA)', style: TextStyle(fontSize: 12, color: _kMuted)),
                const Spacer(),
                _badge('${items.length} entrées', _kBlue),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: items.isEmpty
                    ? const Center(child: Text('Aucun événement enregistré.', style: TextStyle(color: _kMuted)))
                    : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(150), 1: FixedColumnWidth(90), 2: FixedColumnWidth(90), 3: FixedColumnWidth(80), 4: FixedColumnWidth(120), 5: FlexColumnWidth()},
                          children: [
                            _tableHeader(['Date', 'Menu', 'Action', 'Utilisateur', 'Élément', 'Détail']),
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
    'EXPORT' => _kViolet,
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
          ('APR risque opérationnel',    AppFormatters.currency(dash.widget1.aprRisqueOp)),
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
          ['Scénario', 'Variation PNB', 'APR estimé', 'Exigence fonds propres'],
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
    return SingleChildScrollView(
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
                  ('1', 'Synthèse générale',       '',           ['Exigence de fonds propres (Art. 301/307)', 'APR risque opérationnel (Art. 89)', 'Statut de conformité', 'Évolution N-1']),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.toLowerCase()));
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _hCtrl.dispose();
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

  final _hCtrl = ScrollController();

  static const _colLabels = [
    'Référence', 'Date', 'Ligne de métier', "Type d'événement",
    'Description', 'Cause racine', 'Perte brute (FCFA)', 'Récupéré (FCFA)',
    'Perte nette (FCFA)', 'K_RO 15 %', 'APR (×12,5)', 'Statut', 'Actions',
  ];

  static const _colW = [120.0, 95.0, 170.0, 130.0, 220.0, 170.0, 120.0, 120.0, 120.0, 100.0, 120.0, 90.0, 80.0];

  // Visibilité des colonnes
  final List<bool> _visibleCols = List.filled(13, true);
  final _colMenuCtrl = MenuController();

  List<(String, double)> get _visibleColDefs => [
    for (int i = 0; i < _colLabels.length; i++)
      if (_visibleCols[i]) (_colLabels[i], _colW[i]),
  ];
  double get _visibleMinW => _visibleColDefs.fold(0.0, (s, c) => s + c.$2);
  int    get _visibleCount => _visibleCols.where((v) => v).length;

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
        // ── Boutons Import / Exporter ────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _topBtn('Import',   Icons.file_upload_outlined,   const Color(0xFF1E88E5), _openImport, isDark),
          const SizedBox(width: 8),
          _topBtn('Exporter', Icons.file_download_outlined, const Color(0xFF14A44D),
            _cachedItems.isEmpty ? null : () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export Excel — à implémenter'))),
            isDark),
        ]),
        const SizedBox(height: 8),
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
                  borderSide: BorderSide(color: isDark ? const Color(0xFF22304B) : const Color(0xFFDCE5F1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF22304B) : const Color(0xFFDCE5F1))),
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
                        color: isDark ? const Color(0xFF9CB2D4) : const Color(0xFF6B7280))),
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
              SizedBox(width: 32, height: 32,
                child: Tooltip(message: 'Réinitialiser',
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                    child: Icon(Icons.restart_alt_rounded, size: 15, color: isDark ? Colors.white54 : AppTheme.text),
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
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => _colMenuCtrl.isOpen
                        ? _colMenuCtrl.close()
                        : _colMenuCtrl.open(),
                    icon: Icon(Icons.view_column_outlined, size: 14,
                      color: _visibleCount < _colLabels.length
                          ? AppTheme.accent
                          : (isDark ? Colors.white70 : const Color(0xFF374151))),
                    label: Text('Colonnes ($_visibleCount)',
                      style: TextStyle(fontSize: 11,
                        color: _visibleCount < _colLabels.length
                            ? AppTheme.accent
                            : (isDark ? Colors.white70 : const Color(0xFF374151)))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: BorderSide(
                        color: _visibleCount < _colLabels.length
                            ? AppTheme.accent
                            : (isDark ? const Color(0xFF22304B) : const Color(0xFFDCE5F1))),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                ),
              ),
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
        // ── Footer KPI ────────────────────────────────────────────────────
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 110, child: _sumCard('Pertes', '${cached.length}', AppTheme.accent,
            tooltip:
              'Nombre de pertes\n'
              'Rôle : comptage total des incidents\n'
              'enregistrés dans la base.\n'
              'Formule : COUNT(incidents)',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('Perte brute', AppFormatters.currency(cBrute), _kDanger,
            tooltip:
              'Perte brute totale\n'
              'Rôle : montant total avant toute récupération.\n'
              'Formule : Σ perte_brute\n'
              '(somme de toutes les pertes brutes)',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('Perte nette', AppFormatters.currency(cNette), _kDanger,
            tooltip:
              'Perte nette totale (Art. 313.b)\n'
              'Rôle : montant réel supporté après récupérations.\n'
              'Formule : Σ (perte_brute − perte_récupérée)\n'
              'Récupérations = assurance + provisions + reversements',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('K_RO 15 % (Art. 89)', AppFormatters.currency(cKro), _kViolet,
            tooltip:
              'Exigence de fonds propres — Risque Opérationnel\n'
              'Rôle : capital réglementaire minimum à détenir.\n'
              'Formule BIA : K_RO = α × Perte nette totale\n'
              'α = 15 %  (coefficient BCEAO/UMOA, Art. 89)',
          )),
          const SizedBox(width: 6),
          Expanded(child: _sumCard('APR opérationnel', AppFormatters.currency(cApr), _kCyan,
            tooltip:
              'Actifs Pondérés par le Risque opérationnel\n'
              'Rôle : base de calcul du ratio de solvabilité.\n'
              'Formule : APR = K_RO ÷ 8 % = K_RO × 12,5\n'
              '12,5 = facteur de conversion prudentiel (Art. 89)',
          )),
        ])),
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
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF9CB2D4) : const Color(0xFF6B7280))),
          const SizedBox(height: 3),
          _fDrop(label, value, opts, onChange, width, isDark),
        ],
      ),
    );
  }

  Widget _fDrop(String label, String? value, List<String> opts, ValueChanged<String?> onChange, double width, bool isDark) {
    return SizedBox(
      width: width,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14233D) : Colors.white,
          border: Border.all(color: isDark ? const Color(0xFF22304B) : const Color(0xFFDCE5F1)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              isExpanded: true,
              isDense: true,
              hint: Text(label,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
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
      final visW = _visibleMinW;
      final minW = math.max(visW, bc.maxWidth.isFinite ? bc.maxWidth : visW);
      final rowDecoration = BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0x14FFFFFF) : const Color(0x11000000))),
      );
      final rows = items.map((i) {
        final kro = i.perteNette * 0.15;
        final apr = kro * 12.5;
        final allCells = <Widget>[
          _rc(i.reference,                              120, bold: true),                                                               // 0
          _rc(i.dateOccurrence,                          95),                                                                          // 1
          _rcf(i.ligneMetier,                           170),                                                                          // 2
          _rcf(i.typeEvenement,                         130),                                                                          // 3
          _rcf(i.description,                           220),                                                                          // 4
          _rcf(i.causeRacine,                           170),                                                                          // 5
          _rc(AppFormatters.currency(i.perteBrute),     120, right: true),                                                             // 6
          _rc(AppFormatters.currency(i.perteRecuperee), 120, right: true, color: i.perteRecuperee > 0 ? _kSuccess : _kMuted),          // 7
          _rc(AppFormatters.currency(i.perteNette),     120, right: true, color: i.perteNette > 0 ? _kDanger : null),                  // 8
          _rc(AppFormatters.currency(kro),              100, right: true, color: _kViolet),                                            // 9
          _rc(AppFormatters.currency(apr),              120, right: true, color: _kCyan),                                              // 10
          SizedBox(width: 90, child: Padding(padding: const EdgeInsets.all(8), child: _badge(i.statut, _statutColor(i.statut)))),      // 11
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32, height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.edit_outlined, size: 15,
                      color: isDark ? Colors.white54 : _kMuted),
                    tooltip: 'Modifier',
                    onPressed: () => _showEditForm(i),
                  ),
                ),
                SizedBox(
                  width: 32, height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete_outline, size: 15, color: _kDanger),
                    tooltip: 'Supprimer',
                    onPressed: () => _confirm(context, 'Supprimer cet incident ?', () async {
                      await widget.api.deleteRoIncident(i.id);
                      _reload();
                    }),
                  ),
                ),
              ],
            ),
          ),  // 12
        ];
        return Container(
          decoration: rowDecoration,
          child: Row(children: [
            for (int ci = 0; ci < allCells.length; ci++)
              if (_visibleCols[ci]) allCells[ci],
          ]),
        );
      }).toList();

      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13233E) : Colors.white,
          border: Border.all(color: isDark ? const Color(0xFF304764) : AppTheme.border),
          borderRadius: BorderRadius.circular(5),
        ),
        clipBehavior: Clip.antiAlias,
        // Column ici reçoit une hauteur bornée depuis Expanded(FutureBuilder) parent
        child: Column(
          children: [
            // ── En-tête sticky : Transform.translate piloté par _hCtrl (pas de 2e ScrollPosition) ──
            SizedBox(
              height: 40,
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
                      width: minW,
                      child: Container(
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF2A518A), Color(0xFF23477A)],
                          ),
                          border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
                        ),
                        child: Row(
                          children: _visibleColDefs.map((c) => SizedBox(
                            width: c.$2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(c.$1,
                                style: const TextStyle(color: Color(0xFFF5F8FF), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.18, height: 1),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Corps : Expanded ici est dans une Column à hauteur bornée ──
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _hCtrl,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minW),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rows,
                    ),
                  ),
                ),
              ),
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
                        Tooltip(
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
                      Expanded(child: _biaKpi('K_RO (15 %)', AppFormatters.currency(kBia))),
                      Expanded(child: _biaKpi('APR estimé', AppFormatters.currency(apr))),
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

  @override
  Widget build(BuildContext context) {
    const size = 5;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color cellColor(int p, int i) {
      final score = p * i;
      if (score <= 4) return _kSuccess;
      if (score <= 9) return _kWarning;
      if (score <= 16) return const Color(0xFFF97316);
      return _kDanger;
    }
    int countAt(int p, int i) => risques.where((r) => r.probabilite == p && r.impact == i).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Labels haut
        Row(
          children: [
            const SizedBox(width: 48),
            ...List.generate(size, (i) => SizedBox(
              width: 44,
              child: Text('I=${i + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kMuted)),
            )),
          ],
        ),
        const SizedBox(height: 2),
        ...List.generate(size, (pi) {
          final p = size - pi;
          return Row(
            children: [
              SizedBox(
                width: 48,
                child: Text('P=$p', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kMuted)),
              ),
              ...List.generate(size, (ii) {
                final impact = ii + 1;
                final cnt = countAt(p, impact);
                final c = cellColor(p, impact);
                return Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: isDark ? 0.35 : 0.25),
                    border: Border.all(color: c.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: cnt > 0 ? Center(child: Text('$cnt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c))) : null,
                );
              }),
            ],
          );
        }),
        const SizedBox(height: 6),
        // Légende
        Wrap(
          spacing: 12,
          children: [
            _legendItem('Faible (≤4)', _kSuccess),
            _legendItem('Moyen (5–9)', _kWarning),
            _legendItem('Élevé (10–16)', const Color(0xFFF97316)),
            _legendItem('Critique (>16)', _kDanger),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: _kMuted)),
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
    final palette = [_kDanger, _kWarning, _kBlue, _kSuccess, _kViolet, _kCyan, const Color(0xFFF97316), const Color(0xFF84CC16)];
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

// ─── Table helpers ────────────────────────────────────────────────────────────

TableRow _tableHeader(List<String> headers) {
  return TableRow(
    decoration: const BoxDecoration(
      color: Color(0xFFF4F7FD),
      border: Border(bottom: BorderSide(color: Color(0xFFDDE5F5), width: 1.5)),
    ),
    children: headers.map((h) => TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Text(h.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 9.5,
            color: _kMuted, letterSpacing: 0.5)),
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
