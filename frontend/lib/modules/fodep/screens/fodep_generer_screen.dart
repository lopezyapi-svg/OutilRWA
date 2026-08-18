// Écran « Générer un FODEP » : saisie des 45 postes de Fonds Propres
// réglementaires (codes DISPRU BCEAO), calcul des totaux et ratios de
// solvabilité, export du classeur FODEP. Habillage aligné sur le système
// visuel institutionnel du dashboard (dashboard_design.dart) et sur le
// formulaire Dispositif UEMOA (uemoi_form_style.dart) : un seul accent
// navy, panneaux plats, couleur réservée au statut.
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../../risque_operationnel/widgets/uemoi_form_style.dart';
import '../models/fodep_models.dart';
import '../services/fodep_service.dart';
import '../widgets/fodep_design.dart';

class FodepGenererScreen extends StatefulWidget {
  const FodepGenererScreen({super.key, required this.service});

  final FodepService service;

  @override
  State<FodepGenererScreen> createState() => _FodepGenererScreenState();
}

const _kGroupeLibelles = <MapEntry<String, String>>[
  MapEntry('CET1', 'Fonds propres de base durs'),
  MapEntry('AT1', 'Fonds propres de base additionnels'),
  MapEntry('T2', 'Fonds propres complémentaires'),
  MapEntry('effectifs', 'Fonds propres nets'),
];

class _FodepGenererScreenState extends State<FodepGenererScreen> {
  bool _chargement = true;
  bool _enregistrement = false;
  bool _export = false;
  String? _erreur;
  String? _messageSucces;
  String _groupeSelectionne = 'CET1';

  List<CodeDispru> _codes = [];
  FodepApercu? _apercu;

  final _periodeCtrl = TextEditingController();
  final _denominationCtrl = TextEditingController();
  final _codeBceaoCtrl = TextEditingController();
  final Map<String, TextEditingController> _posteCtrl = {};

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _periodeCtrl.dispose();
    _denominationCtrl.dispose();
    _codeBceaoCtrl.dispose();
    for (final c in _posteCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final codes = await widget.service.listerCodesDispru();
      final apercu = await widget.service.obtenirApercu();
      final etablissement = await widget.service.obtenirEtablissement();
      setState(() {
        _codes = codes;
        _apercu = apercu;
        // Le panneau de saisie de la période a été retiré : sans lui, une
        // période vide bloquerait l'enregistrement sans aucun moyen de la
        // renseigner. Repli sur la date du jour tant qu'un autre écran ne
        // pilote pas explicitement l'arrêté.
        _periodeCtrl.text = apercu.periode ??
            DateTime.now().toIso8601String().split('T').first;
        _denominationCtrl.text = etablissement.denomination;
        _codeBceaoCtrl.text = etablissement.codeBceao;
        for (final code in codes) {
          final key = code.code.toLowerCase();
          _posteCtrl[key] = TextEditingController(
            text: _formatEditable(apercu.postes[key] ?? 0.0),
          );
        }
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = 'Chargement impossible : $e';
        _chargement = false;
      });
    }
  }

  String _formatEditable(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  Map<String, double> _lireValeursSaisies() {
    final result = <String, double>{};
    for (final entry in _posteCtrl.entries) {
      final texte =
          entry.value.text.trim().replaceAll(' ', '').replaceAll(',', '.');
      result[entry.key] = double.tryParse(texte) ?? 0.0;
    }
    return result;
  }

  Future<void> _enregistrer() async {
    final periode = _periodeCtrl.text.trim();
    if (periode.isEmpty) {
      setState(() => _erreur =
          "La période (ex. 2026-06-30) est requise avant d'enregistrer.");
      return;
    }
    setState(() {
      _enregistrement = true;
      _erreur = null;
      _messageSucces = null;
    });
    try {
      if (_denominationCtrl.text.trim().isNotEmpty ||
          _codeBceaoCtrl.text.trim().isNotEmpty) {
        await widget.service.enregistrerEtablissement(
          denomination: _denominationCtrl.text.trim(),
          codeBceao: _codeBceaoCtrl.text.trim(),
        );
      }
      final apercu = await widget.service.enregistrer(
        periode: periode,
        postes: _lireValeursSaisies(),
      );
      setState(() {
        _apercu = apercu;
        _enregistrement = false;
        _messageSucces = 'Arrêté $periode enregistré.';
      });
    } catch (e) {
      setState(() {
        _erreur = 'Enregistrement impossible : $e';
        _enregistrement = false;
      });
    }
  }

  Future<void> _exporter() async {
    setState(() {
      _export = true;
      _erreur = null;
    });
    try {
      final Uint8List bytes = await widget.service.exporterExcel(
        periode:
            _periodeCtrl.text.trim().isEmpty ? null : _periodeCtrl.text.trim(),
      );
      final nomSuggere = _periodeCtrl.text.trim().isEmpty
          ? 'brouillon'
          : _periodeCtrl.text.trim();
      final location = await getSaveLocation(
        suggestedName: 'FODEP_fonds_propres_$nomSuggere.xlsx',
      );
      if (location != null) {
        await saveBytesAtLocation(location, bytes, requiredExtension: '.xlsx');
        if (mounted) setState(() => _messageSucces = 'Export enregistré.');
      }
    } catch (e) {
      setState(() => _erreur = 'Export impossible : $e');
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    final apercu = _apercu;
    final c = DashColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF22304B) : AppTheme.border,
              ),
            ),
          ),
          child: const PageHeader(
            title: 'Générer un FODEP',
            subtitle:
                'Fonds propres réglementaires (codes DISPRU, dispositif BCEAO/UMOA).',
            titleFontSize: 20,
            subtitleFontSize: 12,
            titleSubtitleGap: 2,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_erreur != null) ...[
                  FodepNotice(status: DashStatus.sousMinimum, texte: _erreur!),
                  const SizedBox(height: AppTheme.spacing * 2),
                ],
                if (_messageSucces != null) ...[
                  FodepNotice(
                      status: DashStatus.conforme, texte: _messageSucces!),
                  const SizedBox(height: AppTheme.spacing * 2),
                ],
                if (apercu != null) _buildTuiles(apercu, c),
                const SizedBox(height: AppTheme.pageGap),
                if (apercu != null) _buildPostes(),
                const SizedBox(height: AppTheme.pageGap),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _enregistrement ? null : _enregistrer,
                      icon: _enregistrement
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: const Text("Enregistrer l'arrêté"),
                    ),
                    const SizedBox(width: AppTheme.spacing * 2),
                    OutlinedButton.icon(
                      onPressed: _export ? null : _exporter,
                      icon: _export
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Exporter en Excel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTuiles(FodepApercu apercu, DashColors c) {
    final ratios = apercu.ratios;
    final tuiles = <Widget>[
      FodepValueTile(
          label: 'Fonds propres CET1',
          value: _fmt(apercu.totaux['fpi22'] ?? 0),
          caption: 'FPI22'),
      FodepValueTile(
          label: 'Fonds propres T1',
          value: _fmt(apercu.totaux['fpi29'] ?? 0),
          caption: 'FPI29'),
      FodepValueTile(
          label: 'Fonds propres effectifs',
          value: _fmt(apercu.totaux['fpi41'] ?? 0),
          caption: 'FPI41'),
      FodepValueTile(
        label: 'APR total',
        value: _fmt(apercu.apr.aprTotal),
        caption: 'EP08 : crédit + marché + opérationnel',
      ),
      if (ratios['cet1'] != null)
        FodepRatioTile(label: 'Ratio CET1', ratio: ratios['cet1']!),
      if (ratios['tier1'] != null)
        FodepRatioTile(label: 'Ratio T1', ratio: ratios['tier1']!),
      if (ratios['solvency'] != null)
        FodepRatioTile(
            label: 'Ratio de solvabilité', ratio: ratios['solvency']!),
      if (ratios['leverage'] != null)
        FodepRatioTile(label: 'Ratio de levier', ratio: ratios['leverage']!),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : (constraints.maxWidth >= 600 ? 2 : 1);
        final width =
            (constraints.maxWidth - (columns - 1) * AppTheme.spacing * 2) /
                columns;
        return Wrap(
          spacing: AppTheme.spacing * 2,
          runSpacing: AppTheme.spacing * 2,
          children: [for (final t in tuiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }

  String _fmt(double v) {
    if (v.abs() >= 1000000000)
      return '${(v / 1000000000).toStringAsFixed(1)} Md'.replaceAll('.', ',');
    if (v.abs() >= 1000000)
      return '${(v / 1000000).toStringAsFixed(1)} M'.replaceAll('.', ',');
    return v.toStringAsFixed(0);
  }

  Widget _buildPostes() {
    final groupesPresents = _kGroupeLibelles
        .where((e) => _codes.any((c) => c.groupe == e.key))
        .toList();
    if (groupesPresents.isNotEmpty &&
        !groupesPresents.any((e) => e.key == _groupeSelectionne)) {
      _groupeSelectionne = groupesPresents.first.key;
    }
    final libelleGroupe = groupesPresents
        .firstWhere((e) => e.key == _groupeSelectionne,
            orElse: () => groupesPresents.first)
        .value;

    return DashPanel(
      title: 'Postes réglementaires (codes DISPRU)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FodepTabs(
            onglets: groupesPresents,
            selection: _groupeSelectionne,
            onSelect: (g) => setState(() => _groupeSelectionne = g),
          ),
          const SizedBox(height: 14),
          UemoiFormCard(
            title: libelleGroupe,
            children: [
              for (final code
                  in _codes.where((c) => c.groupe == _groupeSelectionne))
                UemoiFormField(
                  label: code.estDeduction
                      ? '${code.code} : ${code.label} (déduction)'
                      : '${code.code} : ${code.label}',
                  controller: _posteCtrl[code.code.toLowerCase()]!,
                  numeric: true,
                  signed: code.estDeduction,
                  suffixText: 'FCFA',
                  labelFlex: 8,
                  fieldFlex: 5,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
