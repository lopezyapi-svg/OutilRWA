// Écran « Analyser un FODEP existant » : lecture directe du dernier arrêté
// FODEP déjà enregistré dans RisqueManagement (postes, totaux, ratios), sans
// import de fichier. Même système visuel que l'écran Générer
// (dashboard_design.dart).
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/fodep_models.dart';
import '../services/fodep_service.dart';
import '../widgets/fodep_design.dart';

class FodepAnalyserScreen extends StatefulWidget {
  const FodepAnalyserScreen({super.key, required this.service});

  final FodepService service;

  @override
  State<FodepAnalyserScreen> createState() => _FodepAnalyserScreenState();
}

const _kGroupeLibelles = <MapEntry<String, String>>[
  MapEntry('CET1', 'Fonds propres de base durs'),
  MapEntry('AT1', 'Fonds propres de base additionnels'),
  MapEntry('T2', 'Fonds propres complémentaires'),
  MapEntry('effectifs', 'Fonds propres nets'),
];

class _FodepAnalyserScreenState extends State<FodepAnalyserScreen> {
  bool _chargement = true;
  String? _erreur;
  List<CodeDispru> _codes = [];
  FodepApercu? _apercu;
  String _groupeSelectionne = 'CET1';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final codes = await widget.service.listerCodesDispru();
      final apercu = await widget.service.obtenirApercu();
      setState(() {
        _codes = codes;
        _apercu = apercu;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = 'Chargement impossible : $e';
        _chargement = false;
      });
    }
  }

  String _fmt(double v) {
    if (v.abs() >= 1000000000) {
      return '${(v / 1000000000).toStringAsFixed(1)} Md'.replaceAll('.', ',');
    }
    if (v.abs() >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)} M'.replaceAll('.', ',');
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final apercu = _apercu;
    final c = DashColors.of(context);

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
            title: 'Analyser un FODEP existant',
            subtitle: 'Lecture du dernier arrêté enregistré dans RisqueManagement.',
            titleFontSize: 20,
            subtitleFontSize: 12,
            titleSubtitleGap: 2,
          ),
        ),
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_erreur != null) ...[
                        FodepNotice(status: DashStatus.sousMinimum, texte: _erreur!),
                        const SizedBox(height: AppTheme.spacing * 2),
                      ],
                      if (apercu != null) ...[
                        _buildTuiles(apercu),
                        const SizedBox(height: AppTheme.pageGap),
                        _buildPostes(c),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTuiles(FodepApercu apercu) {
    final ratios = apercu.ratios;
    final tuiles = <Widget>[
      FodepValueTile(label: 'Fonds propres CET1', value: _fmt(apercu.totaux['fpi22'] ?? 0), caption: 'FPI22'),
      FodepValueTile(label: 'Fonds propres T1', value: _fmt(apercu.totaux['fpi29'] ?? 0), caption: 'FPI29'),
      FodepValueTile(label: 'Fonds propres effectifs', value: _fmt(apercu.totaux['fpi41'] ?? 0), caption: 'FPI41'),
      FodepValueTile(
        label: 'APR total',
        value: _fmt(apercu.apr.aprTotal),
        caption: 'EP08 : crédit + marché + opérationnel',
      ),
      if (ratios['cet1'] != null) FodepRatioTile(label: 'Ratio CET1', ratio: ratios['cet1']!),
      if (ratios['tier1'] != null) FodepRatioTile(label: 'Ratio T1', ratio: ratios['tier1']!),
      if (ratios['solvency'] != null) FodepRatioTile(label: 'Ratio de solvabilité', ratio: ratios['solvency']!),
      if (ratios['leverage'] != null) FodepRatioTile(label: 'Ratio de levier', ratio: ratios['leverage']!),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);
        final width = (constraints.maxWidth - (columns - 1) * AppTheme.spacing * 2) / columns;
        return Wrap(
          spacing: AppTheme.spacing * 2,
          runSpacing: AppTheme.spacing * 2,
          children: [for (final t in tuiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }

  Widget _buildPostes(DashColors c) {
    final groupesPresents = _kGroupeLibelles.where((e) => _codes.any((code) => code.groupe == e.key)).toList();
    if (groupesPresents.isNotEmpty && !groupesPresents.any((e) => e.key == _groupeSelectionne)) {
      _groupeSelectionne = groupesPresents.first.key;
    }
    final apercu = _apercu;

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
          const SizedBox(height: 4),
          for (final code in _codes.where((c) => c.groupe == _groupeSelectionne))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
              child: Row(
                children: [
                  SizedBox(width: 60, child: Text(code.code, style: DashText.value(c, color: c.navy))),
                  Expanded(child: Text(code.label, style: DashText.value(c, weight: FontWeight.w500))),
                  Text(
                    _fmt(apercu?.postes[code.code.toLowerCase()] ?? 0),
                    style: DashText.value(c, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
