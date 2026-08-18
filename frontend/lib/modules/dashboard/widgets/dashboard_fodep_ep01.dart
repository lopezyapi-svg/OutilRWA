import 'package:flutter/material.dart';

import '../../fodep/models/fodep_models.dart';
import '../../fodep/services/fodep_service.dart';
import 'dashboard_design.dart';

/// Panneau EP01 — Fonds propres réglementaires (FODEP officiel BCEAO).
/// Chargement autonome : s'insère dans le dashboard sans dépendre du snapshot RWA.
class DashboardFodepEp01Panel extends StatefulWidget {
  const DashboardFodepEp01Panel({super.key, required this.fodep});

  final FodepService fodep;

  @override
  State<DashboardFodepEp01Panel> createState() => _DashboardFodepEp01PanelState();
}

class _DashboardFodepEp01PanelState extends State<DashboardFodepEp01Panel> {
  FodepApercu? _apercu;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final apercu = await widget.fodep.obtenirApercu();
      if (mounted) setState(() { _apercu = apercu; _chargement = false; });
    } catch (_) {
      if (mounted) setState(() => _chargement = false);
    }
  }

  String _fmt(double v) {
    if (v.abs() >= 1e9) return '${(v / 1e9).toStringAsFixed(2)} Md'.replaceAll('.', ',');
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(2)} M'.replaceAll('.', ',');
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(1)} k'.replaceAll('.', ',');
    return v.toStringAsFixed(0);
  }

  String _pct(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} %';

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    if (_chargement) {
      return const DashPanel(
        title: 'EP01 — Fonds propres réglementaires (FODEP)',
        child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator.adaptive())),
      );
    }

    final apercu = _apercu;
    if (apercu == null) return const SizedBox.shrink();

    final cet1 = apercu.totaux['fpi22'] ?? 0;
    final tier1 = apercu.totaux['fpi29'] ?? 0;
    final effectifs = apercu.totaux['fpi41'] ?? 0;

    final ratiosDef = <String, String>{
      'cet1': 'CET1',
      'tier1': 'Tier 1',
      'solvency': 'Solvabilité',
      'leverage': 'Levier',
    };

    return DashPanel(
      title: 'EP01 — Fonds propres réglementaires (FODEP)',
      trailing: apercu.periode != null
          ? Text(
              'Arrêté : ${apercu.periode}',
              style: DashText.caption(c, color: c.muted),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Totaux principaux ─────────────────────────────────────────
          LayoutBuilder(builder: (context, cx) {
            final cols = cx.maxWidth >= 700 ? 3 : (cx.maxWidth >= 450 ? 2 : 1);
            final w = (cx.maxWidth - (cols - 1) * 12.0) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Tuile(
                  label: 'Fonds propres CET1',
                  code: 'FPI22',
                  valeur: _fmt(cet1),
                  couleur: c.navy,
                  width: w,
                  c: c,
                ),
                _Tuile(
                  label: 'Fonds propres Tier 1',
                  code: 'FPI29',
                  valeur: _fmt(tier1),
                  couleur: c.ramp[2],
                  width: w,
                  c: c,
                ),
                _Tuile(
                  label: 'Fonds propres effectifs',
                  code: 'FPI41',
                  valeur: _fmt(effectifs),
                  couleur: c.ramp[4],
                  width: w,
                  c: c,
                ),
              ],
            );
          }),

          const SizedBox(height: 20),
          Divider(height: 1, thickness: 0.5, color: c.divider),
          const SizedBox(height: 16),

          // ── Ratios prudentiels ────────────────────────────────────────
          Text('Ratios prudentiels (EP08)', style: DashText.eyebrow(c, color: c.muted)),
          const SizedBox(height: 12),

          LayoutBuilder(builder: (context, cx) {
            final cols = cx.maxWidth >= 700 ? 4 : (cx.maxWidth >= 450 ? 2 : 1);
            final w = (cx.maxWidth - (cols - 1) * 8.0) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in ratiosDef.entries)
                  if (apercu.ratios[e.key] != null)
                    SizedBox(
                      width: w,
                      child: _MiniRatio(
                        label: e.value,
                        ratio: apercu.ratios[e.key]!,
                        pct: _pct,
                        c: c,
                      ),
                    ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.label,
    required this.code,
    required this.valeur,
    required this.couleur,
    required this.width,
    required this.c,
  });

  final String label;
  final String code;
  final String valeur;
  final Color couleur;
  final double width;
  final DashColors c;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(Dash.radius),
          border: Border.all(color: couleur.withValues(alpha: 0.2), width: Dash.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label.toUpperCase(), style: DashText.eyebrow(c, color: couleur)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(code, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: couleur)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(valeur, style: DashText.hero(c, size: 18).copyWith(color: couleur)),
            const SizedBox(height: 2),
            Text('FCFA', style: DashText.caption(c)),
          ],
        ),
      ),
    );
  }
}

class _MiniRatio extends StatelessWidget {
  const _MiniRatio({
    required this.label,
    required this.ratio,
    required this.pct,
    required this.c,
  });

  final String label;
  final RatioDetail ratio;
  final String Function(double) pct;
  final DashColors c;

  DashStatus get _status {
    switch (ratio.status) {
      case 'Excédent':
        return DashStatus.conforme;
      case 'Sous cible':
        return DashStatus.sousCible;
      default:
        return DashStatus.sousMinimum;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final couleur = c.status(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: couleur.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: DashText.eyebrow(c, color: c.muted)),
          const SizedBox(height: 6),
          Text(pct(ratio.value), style: DashText.hero(c, size: 16)),
          const SizedBox(height: 4),
          Row(
            children: [
              DashStatusTag(status: status, dense: true),
              const Spacer(),
              Text(
                'seuil ${pct(ratio.threshold)}',
                style: DashText.caption(c),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
