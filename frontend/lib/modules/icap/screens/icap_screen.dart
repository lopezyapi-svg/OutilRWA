// Ecran du module ICAAP — Pilier 2 / PIEAFP (UMOA Titre XI art. 505-549).
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/pieafp_models.dart';

enum IcapView {
  dashboard,
  capitalEconomique,
  capitalReglementaire,
  appetenceRisque,
  buffersPrudentiels,
  projectionCapital,
  analyseSolvabilite,
  plansCapital,
  reporting,
  gouvernance,
  adeqCapital,
  risquesP2,
  planification,
  stressTests,
  checklist,
  rapport,
}

class IcapScreen extends StatelessWidget {
  const IcapScreen({
    super.key,
    required this.api,
    this.view = IcapView.dashboard,
  });

  final RwaApiService api;
  final IcapView view;

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(view);
    final body = switch (view) {
      IcapView.dashboard    => _PieafpDashboardView(api: api),
      IcapView.risquesP2    => _RisquesP2View(api: api),
      IcapView.planification => _PlanificationView(api: api),
      IcapView.stressTests  => _StressTestsView(api: api),
      IcapView.gouvernance  => _GouvernanceView(api: api),
      IcapView.checklist    => _GouvernanceView(api: api),
      IcapView.rapport      => _RapportView(api: api),
      _ => _ComingSoonCard(label: content.title),
    };

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: content.title, subtitle: content.subtitle),
          AppSpacing.gapLg,
          body,
        ],
      ),
    );
  }

  _IcapViewContent _contentFor(IcapView v) => switch (v) {
    IcapView.dashboard         => const _IcapViewContent(title: 'Dashboard ICAAP', subtitle: 'Synthèse PIEAFP — adéquation interne des fonds propres (Pilier 2 UMOA)'),
    IcapView.capitalEconomique => const _IcapViewContent(title: 'Capital économique', subtitle: 'Mesure interne des besoins de capital par type de risque'),
    IcapView.capitalReglementaire => const _IcapViewContent(title: 'Capital réglementaire', subtitle: 'Exigences prudentielles et ratios réglementaires'),
    IcapView.appetenceRisque   => const _IcapViewContent(title: 'Appétence au risque', subtitle: 'Seuils ICAAP, limites internes et marges de sécurité'),
    IcapView.buffersPrudentiels => const _IcapViewContent(title: 'Buffers prudentiels', subtitle: 'Coussins de conservation, contracycliques et excédent de capital'),
    IcapView.projectionCapital => const _IcapViewContent(title: 'Projection capital', subtitle: 'Capital disponible et besoins futurs sous stress'),
    IcapView.analyseSolvabilite => const _IcapViewContent(title: 'Analyse solvabilité', subtitle: 'Diagnostic des ratios de solvabilité'),
    IcapView.plansCapital      => const _IcapViewContent(title: 'Plans de capital', subtitle: 'Leviers de renforcement des fonds propres'),
    IcapView.reporting         => const _IcapViewContent(title: 'Reporting ICAAP', subtitle: 'Indicateurs clés et pistes de restitution'),
    IcapView.gouvernance       => const _IcapViewContent(title: 'Gouvernance ICAAP', subtitle: 'Cadre de gouvernance, comités et checklist de conformité'),
    IcapView.adeqCapital       => const _IcapViewContent(title: 'Adéquation du capital', subtitle: 'Evaluation entre capital disponible et besoins identifiés'),
    IcapView.risquesP2         => const _IcapViewContent(title: 'Risques Pilier 2', subtitle: 'Concentration, IRRBB et autres risques non couverts par le Pilier 1'),
    IcapView.planification     => const _IcapViewContent(title: 'Planification du capital', subtitle: 'Trajectoire pluriannuelle et dispositif de pilotage'),
    IcapView.stressTests       => const _IcapViewContent(title: 'Stress tests', subtitle: 'Simulations de chocs et résilience du capital'),
    IcapView.checklist         => const _IcapViewContent(title: 'Checklist ICAAP', subtitle: 'Conformité du processus PIEAFP aux exigences régulatoires'),
    IcapView.rapport           => const _IcapViewContent(title: 'Rapport ICAAP', subtitle: "Synthèse soumise à l'autorité de supervision prudentielle"),
  };
}

class _IcapViewContent {
  const _IcapViewContent({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

// ──────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────────────────────────────────────

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.construction_rounded, size: 48,
            color: isDark ? AppTheme.darkMuted : AppTheme.muted),
        const SizedBox(height: 20),
        Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkText : AppTheme.text)),
        const SizedBox(height: 8),
        Text('Ce module est en cours de développement.',
            style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkMuted : AppTheme.muted)),
      ]),
    );
  }
}

Widget _loadingBox() => const SizedBox(
    height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));

Widget _errorBox(Object? err) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Erreur : $err',
          style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
    );

Color _statusColor(String statut) => switch (statut) {
      'OK'         => AppTheme.success,
      'Attention'  => AppTheme.warning,
      'N/A'        => AppTheme.muted,
      _            => AppTheme.danger,
    };

Widget _statusBadge(String statut) {
  final color = _statusColor(statut);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(statut, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

String _fmtFp(double v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)} Mds FCFA';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)} M FCFA';
  return AppFormatters.currency(v);
}

// ──────────────────────────────────────────────────────────────────────────────
// MODULE DASHBOARD PIEAFP
// ──────────────────────────────────────────────────────────────────────────────

class _PieafpDashboardView extends StatefulWidget {
  const _PieafpDashboardView({required this.api});
  final RwaApiService api;

  @override
  State<_PieafpDashboardView> createState() => _PieafpDashboardViewState();
}

class _PieafpDashboardViewState extends State<_PieafpDashboardView> {
  late Future<PieafpDashboard> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchPieafpDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PieafpDashboard>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final data = snap.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // KPI strip
          _KpiStrip(data: data),
          const SizedBox(height: 16),
          // Module cards grid
          SectionCard(
            title: 'Cartographie des risques Pilier 2',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: data.modules.map((m) => _ModuleCard(m: m)).toList(),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.data});
  final PieafpDashboard data;

  @override
  Widget build(BuildContext context) {
    final ratio = data.ratioSolvabilitePct;
    final ratioColor = ratio >= 12 ? AppTheme.success : (ratio >= 8 ? AppTheme.warning : AppTheme.danger);
    return Row(children: [
      Expanded(child: _KpiTile(label: 'Fonds propres', value: _fmtFp(data.fpTotal), color: AppTheme.accent)),
      const SizedBox(width: 12),
      Expanded(child: _KpiTile(label: 'RWA total', value: _fmtFp(data.rwaTotal), color: AppTheme.muted)),
      const SizedBox(width: 12),
      Expanded(child: _KpiTile(
          label: 'Ratio de solvabilité',
          value: '${data.ratioSolvabilitePct.toStringAsFixed(2)} %',
          color: ratioColor,
          subtitle: ratio >= 8 ? 'Seuil min. 8 % ✓' : '⚠ Sous le seuil réglementaire')),
    ]);
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.color, this.subtitle});
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkMuted : AppTheme.muted)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
        ]
      ]),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.m});
  final ModuleStatus m;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _statusColor(m.statut);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(m.libelle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        _statusBadge(m.statut),
        const SizedBox(height: 6),
        Text(m.valeurCle,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkText : AppTheme.text)),
        const SizedBox(height: 4),
        Text(m.detail,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MODULE RISQUES PILIER 2 (Concentration + IRRBB + Autres risques)
// ──────────────────────────────────────────────────────────────────────────────

class _RisquesP2View extends StatefulWidget {
  const _RisquesP2View({required this.api});
  final RwaApiService api;

  @override
  State<_RisquesP2View> createState() => _RisquesP2ViewState();
}

class _RisquesP2ViewState extends State<_RisquesP2View> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: '1.2 — Concentration'),
          Tab(text: '1.6 — IRRBB'),
          Tab(text: '1.8 — Autres risques'),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 700,
        child: TabBarView(controller: _tabs, children: [
          _ConcentrationTab(api: widget.api),
          _IrrbbTab(api: widget.api),
          _AutresRisquesTab(api: widget.api),
        ]),
      ),
    ]);
  }
}

// ── Concentration ─────────────────────────────────────────────────────────────

class _ConcentrationTab extends StatefulWidget {
  const _ConcentrationTab({required this.api});
  final RwaApiService api;

  @override
  State<_ConcentrationTab> createState() => _ConcentrationTabState();
}

class _ConcentrationTabState extends State<_ConcentrationTab> {
  late Future<ConcentrationResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchConcentration();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConcentrationResult>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final d = snap.data!;

        if (d.totalEad == 0) {
          return const Center(child: Text('Aucune exposition active dans le portefeuille.'));
        }

        return SingleChildScrollView(
          child: Column(children: [
            // KPI ligne
            Row(children: [
              Expanded(child: _KpiTile(label: 'EAD total', value: _fmtFp(d.totalEad), color: AppTheme.accent)),
              const SizedBox(width: 12),
              Expanded(child: _KpiTile(label: 'Contreparties actives', value: '${d.nbContreparties}', color: AppTheme.muted)),
              const SizedBox(width: 12),
              Expanded(child: _KpiTile(
                  label: 'Grands risques (> 25% FP)',
                  value: '${d.grandsRisquesNb}',
                  color: d.grandsRisquesNb > 0 ? AppTheme.danger : AppTheme.success)),
              const SizedBox(width: 12),
              Expanded(child: _KpiTile(
                  label: 'CR10 / Fonds propres',
                  value: '${d.cr10Pct.toStringAsFixed(1)} %',
                  color: d.cr10Pct > 800 ? AppTheme.danger : AppTheme.warning)),
            ]),
            const SizedBox(height: 16),
            // Axes HHI
            ...d.axes.map((axis) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SectionCard(
                title: 'Concentration par ${axis.axe} — HHI : ${NumberFormat('#,###').format(axis.hhi.round())}',
                trailing: _statusBadge(axis.niveau),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    _HhiGauge(hhi: axis.hhi),
                    const SizedBox(height: 16),
                    ...axis.topBars.take(8).map((b) => _ConcentrationBar(bar: b, totalEad: d.totalEad)),
                  ]),
                ),
              ),
            )),
          ]),
        );
      },
    );
  }
}

class _HhiGauge extends StatelessWidget {
  const _HhiGauge({required this.hhi});
  final double hhi;

  @override
  Widget build(BuildContext context) {
    final ratio = (hhi / 10000).clamp(0.0, 1.0);
    final color = hhi < 1000 ? AppTheme.success : (hhi < 1800 ? AppTheme.warning : AppTheme.danger);
    return Column(children: [
      SizedBox(
        height: 12,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('0', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
        Text('HHI = ${hhi.round()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const Text('10 000', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
      ]),
      const SizedBox(height: 4),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _HhiZone(label: '< 1 000 Faible', color: AppTheme.success),
        SizedBox(width: 12),
        _HhiZone(label: '1 000–1 800 Modéré', color: AppTheme.warning),
        SizedBox(width: 12),
        _HhiZone(label: '> 1 800 Élevé', color: AppTheme.danger),
      ]),
    ]);
  }
}

class _HhiZone extends StatelessWidget {
  const _HhiZone({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
  ]);
}

class _ConcentrationBar extends StatelessWidget {
  const _ConcentrationBar({required this.bar, required this.totalEad});
  final ConcentrationBar bar;
  final double totalEad;

  @override
  Widget build(BuildContext context) {
    final pct = totalEad > 0 ? (bar.ead / totalEad).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 140, child: Text(bar.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(children: [
            Container(height: 18, decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(3))),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(height: 18, decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3))),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 48, child: Text('${bar.pct.toStringAsFixed(1)} %',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right)),
      ]),
    );
  }
}

// ── IRRBB ─────────────────────────────────────────────────────────────────────

class _IrrbbTab extends StatefulWidget {
  const _IrrbbTab({required this.api});
  final RwaApiService api;

  @override
  State<_IrrbbTab> createState() => _IrrbbTabState();
}

class _IrrbbTabState extends State<_IrrbbTab> {
  late Future<IrrbbResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchIrrbb();
  }

  void _reload() => setState(() => _future = widget.api.fetchIrrbb());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IrrbbResult>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final d = snap.data!;

        final niiColor = d.niveauRisque == 'Faible' ? AppTheme.success
            : (d.niveauRisque == 'Modéré' ? AppTheme.warning : AppTheme.danger);

        return SingleChildScrollView(
          child: Column(children: [
            Row(children: [
              Expanded(child: _KpiTile(
                  label: 'ΔNII (choc +${d.chocBp} pb)',
                  value: _fmtFp(d.deltaNii200bp),
                  color: niiColor)),
              const SizedBox(width: 12),
              Expanded(child: _KpiTile(
                  label: 'ΔNII / Fonds propres',
                  value: '${d.deltaNiiPctFp.toStringAsFixed(1)} %',
                  color: niiColor)),
              const SizedBox(width: 12),
              Expanded(child: _KpiTile(
                  label: 'GAP total',
                  value: _fmtFp(d.gapTotal),
                  color: d.gapTotal >= 0 ? AppTheme.success : AppTheme.danger)),
              const SizedBox(width: 12),
              Expanded(child: _KpiTile(
                  label: 'Niveau de risque',
                  value: d.niveauRisque,
                  color: niiColor)),
            ]),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Échéancier de repricing (gap actifs − passifs)',
              trailing: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Actualiser', style: TextStyle(fontSize: 12)),
                onPressed: _reload,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  // Header
                  _IrrbbHeaderRow(),
                  const Divider(height: 12),
                  ...d.tranches.map((t) => _IrrbbRow(
                    t: t,
                    onEdit: () => _editTranche(ctx, t),
                  )),
                  const Divider(height: 12),
                  // Total row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const SizedBox(width: 70, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      Expanded(child: Text(_fmtFp(d.tranches.fold(0.0, (s, t) => s + t.encoursActifs)),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                      Expanded(child: Text(_fmtFp(d.tranches.fold(0.0, (s, t) => s + t.encoursPassifs)),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                      Expanded(child: Text(_fmtFp(d.gapTotal),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: d.gapTotal >= 0 ? AppTheme.success : AppTheme.danger),
                          textAlign: TextAlign.right)),
                      Expanded(child: Text(_fmtFp(d.deltaNii200bp),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: niiColor),
                          textAlign: TextAlign.right)),
                      const SizedBox(width: 40),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Formule : ΔNII = Σ GAP_t × Δr × duration_t  •  Choc standard : +200 pb  •  Seuil d\'alerte : ΔNII > 15 % des fonds propres',
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _editTranche(BuildContext context, IrrbbTrancheResult t) async {
    final actifsCtrl = TextEditingController(text: t.encoursActifs.toStringAsFixed(0));
    final passifsCtrl = TextEditingController(text: t.encoursPassifs.toStringAsFixed(0));
    final tauxActifsCtrl = TextEditingController(text: t.tauxActifsPct.toStringAsFixed(2));
    final tauxPassifsCtrl = TextEditingController(text: t.tauxPassifsPct.toStringAsFixed(2));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier la tranche ${t.tranche}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _EditField(label: 'Encours actifs (FCFA)', ctrl: actifsCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Encours passifs (FCFA)', ctrl: passifsCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Taux actifs (%)', ctrl: tauxActifsCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Taux passifs (%)', ctrl: tauxPassifsCtrl),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    try {
      await widget.api.updateIrrbbTranche(t.tranche, {
        'encours_actifs': double.tryParse(actifsCtrl.text) ?? t.encoursActifs,
        'encours_passifs': double.tryParse(passifsCtrl.text) ?? t.encoursPassifs,
        'taux_actifs_pct': double.tryParse(tauxActifsCtrl.text) ?? t.tauxActifsPct,
        'taux_passifs_pct': double.tryParse(tauxPassifsCtrl.text) ?? t.tauxPassifsPct,
      });
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _IrrbbHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.muted);
    return const Row(children: [
      SizedBox(width: 70, child: Text('Tranche', style: style)),
      Expanded(child: Text('Actifs', style: style, textAlign: TextAlign.right)),
      Expanded(child: Text('Passifs', style: style, textAlign: TextAlign.right)),
      Expanded(child: Text('GAP', style: style, textAlign: TextAlign.right)),
      Expanded(child: Text('ΔNII +200pb', style: style, textAlign: TextAlign.right)),
      SizedBox(width: 40),
    ]);
  }
}

class _IrrbbRow extends StatelessWidget {
  const _IrrbbRow({required this.t, required this.onEdit});
  final IrrbbTrancheResult t;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final gapColor = t.gap >= 0 ? AppTheme.success : AppTheme.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 70,
            child: Text(t.tranche, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: Text(_fmtFp(t.encoursActifs),
            style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        Expanded(child: Text(_fmtFp(t.encoursPassifs),
            style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        Expanded(child: Text(_fmtFp(t.gap),
            style: TextStyle(fontSize: 12, color: gapColor, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right)),
        Expanded(child: Text(_fmtFp(t.deltaNii200bp),
            style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        SizedBox(width: 40, child: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 14),
          onPressed: onEdit,
          tooltip: 'Modifier',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
        )),
      ]),
    );
  }
}

// ── Autres risques ────────────────────────────────────────────────────────────

class _AutresRisquesTab extends StatefulWidget {
  const _AutresRisquesTab({required this.api});
  final RwaApiService api;

  @override
  State<_AutresRisquesTab> createState() => _AutresRisquesTabState();
}

class _AutresRisquesTabState extends State<_AutresRisquesTab> {
  late Future<List<AutreRisque>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchAutresRisques();
  }

  void _reload() => setState(() => _future = widget.api.fetchAutresRisques());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AutreRisque>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final items = snap.data!;

        return SingleChildScrollView(
          child: SectionCard(
            title: 'Matrice des risques Pilier 2 (${items.length})',
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
              onPressed: () => _addRisque(ctx),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun risque identifié. Cliquez sur "Ajouter" pour commencer.')))
                  : Column(children: [
                      _RisqueHeader(),
                      const Divider(height: 12),
                      ...items.map((r) => _RisqueRow(r: r, onDelete: () => _deleteRisque(r.id))),
                    ]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addRisque(BuildContext context) async {
    final libelleCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau risque Pilier 2'),
        content: _EditField(label: 'Libellé du risque', ctrl: libelleCtrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await widget.api.createAutreRisque({'libelle': libelleCtrl.text, 'categorie': 'Autre', 'probabilite': 3, 'impact': 3});
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _deleteRisque(int id) async {
    try {
      await widget.api.deleteAutreRisque(id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _RisqueHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.muted);
    return const Row(children: [
      Expanded(flex: 3, child: Text('Libellé', style: s)),
      Expanded(child: Text('Catégorie', style: s)),
      SizedBox(width: 40, child: Text('P', style: s, textAlign: TextAlign.center)),
      SizedBox(width: 40, child: Text('I', style: s, textAlign: TextAlign.center)),
      SizedBox(width: 60, child: Text('Niveau', style: s, textAlign: TextAlign.center)),
      SizedBox(width: 36),
    ]);
  }
}

class _RisqueRow extends StatelessWidget {
  const _RisqueRow({required this.r, required this.onDelete});
  final AutreRisque r;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final niveauColor = switch (r.niveau) {
      'Critique' => AppTheme.danger,
      'Élevé'    => const Color(0xFFFF6B35),
      'Modéré'   => AppTheme.warning,
      _          => AppTheme.success,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 3, child: Text(r.libelle, style: const TextStyle(fontSize: 12))),
        Expanded(child: Text(r.categorie, style: const TextStyle(fontSize: 12, color: AppTheme.muted))),
        SizedBox(width: 40, child: Text('${r.probabilite}', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        SizedBox(width: 40, child: Text('${r.impact}', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        SizedBox(width: 60, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: niveauColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
          child: Text(r.niveau, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: niveauColor)),
        ))),
        SizedBox(width: 36, child: IconButton(
          icon: const Icon(Icons.delete_outline, size: 14, color: AppTheme.muted),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
        )),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MODULE PLANIFICATION (Module 2)
// ──────────────────────────────────────────────────────────────────────────────

class _PlanificationView extends StatefulWidget {
  const _PlanificationView({required this.api});
  final RwaApiService api;

  @override
  State<_PlanificationView> createState() => _PlanificationViewState();
}

class _PlanificationViewState extends State<_PlanificationView> {
  late Future<PlanificationResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchPlanification();
  }

  void _reload() => setState(() => _future = widget.api.fetchPlanification());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlanificationResult>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final d = snap.data!;

        return Column(children: [
          // Graphique trajectoire
          SectionCard(
            title: 'Trajectoire pluriannuelle du ratio de solvabilité',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(height: 200, child: _PlanifChart(annees: d.annees)),
            ),
          ),
          const SizedBox(height: 16),
          // Table de planification
          SectionCard(
            title: 'Projections par année',
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: _reload,
              tooltip: 'Actualiser',
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _PlanifHeader(),
                const Divider(height: 12),
                ...d.annees.map((a) => _PlanifRow(
                  a: a,
                  onEdit: () => _editAnnee(ctx, a),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'FP requis = RWA total × 8 % + Add-on Pilier 2  •  Coussin = FP disponibles − FP requis  •  Seuil réglementaire minimal : 8 %',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _editAnnee(BuildContext context, PlanificationAnnee a) async {
    final fpCtrl = TextEditingController(text: a.fpDisponibles.toStringAsFixed(0));
    final creditCtrl = TextEditingController(text: a.rwaCreditProjecte.toStringAsFixed(0));
    final marcheCtrl = TextEditingController(text: a.rwaMarcheProjecte.toStringAsFixed(0));
    final opCtrl = TextEditingController(text: a.rwaOpProjecte.toStringAsFixed(0));
    final addonCtrl = TextEditingController(text: a.addonPilier2.toStringAsFixed(0));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier les projections ${a.annee}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _EditField(label: 'Fonds propres disponibles', ctrl: fpCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'RWA crédit projeté', ctrl: creditCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'RWA marché projeté', ctrl: marcheCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'RWA opérationnel projeté', ctrl: opCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Add-on Pilier 2', ctrl: addonCtrl),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    try {
      await widget.api.upsertPlanificationAnnee(a.annee, {
        'fp_disponibles': double.tryParse(fpCtrl.text) ?? a.fpDisponibles,
        'rwa_credit_projete': double.tryParse(creditCtrl.text) ?? a.rwaCreditProjecte,
        'rwa_marche_projete': double.tryParse(marcheCtrl.text) ?? a.rwaMarcheProjecte,
        'rwa_op_projete': double.tryParse(opCtrl.text) ?? a.rwaOpProjecte,
        'resultat_net_projete': a.resultatNetProjecte,
        'dividendes_projetes': a.dividendesProjectes,
        'emission_capital': a.emissionCapital,
        'addon_pilier2': double.tryParse(addonCtrl.text) ?? a.addonPilier2,
      });
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _PlanifChart extends StatelessWidget {
  const _PlanifChart({required this.annees});
  final List<PlanificationAnnee> annees;

  @override
  Widget build(BuildContext context) {
    if (annees.isEmpty) return const Center(child: Text('Aucune donnée'));
    final maxRatio = annees.map((a) => a.ratioSolvabilitePct).fold(0.0, math.max);
    final chartMax = math.max(maxRatio * 1.3, 20.0);

    return CustomPaint(
      painter: _PlanifChartPainter(annees: annees, chartMax: chartMax),
    );
  }
}

class _PlanifChartPainter extends CustomPainter {
  const _PlanifChartPainter({required this.annees, required this.chartMax});
  final List<PlanificationAnnee> annees;
  final double chartMax;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = EdgeInsets.fromLTRB(50, 10, 20, 30);
    final w = size.width - pad.left - pad.right;
    final h = size.height - pad.top - pad.bottom;

    // Zone solvable (> 8%)
    final y8 = pad.top + h * (1 - 8 / chartMax);
    canvas.drawRect(
      Rect.fromLTWH(pad.left, pad.top, w, y8 - pad.top),
      Paint()..color = AppTheme.success.withValues(alpha: 0.07),
    );
    canvas.drawLine(
      Offset(pad.left, y8), Offset(pad.left + w, y8),
      Paint()..color = AppTheme.success.withValues(alpha: 0.4)..strokeWidth = 1,
    );

    // Axe Y labels
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (final pct in [0.0, 8.0, 12.0, 16.0, 20.0]) {
      if (pct > chartMax) break;
      final y = pad.top + h * (1 - pct / chartMax);
      textPainter.text = TextSpan(
          text: '${pct.toStringAsFixed(0)} %',
          style: const TextStyle(fontSize: 9, color: AppTheme.muted));
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 5));
      canvas.drawLine(Offset(pad.left, y), Offset(pad.left + w, y),
          Paint()..color = AppTheme.border.withValues(alpha: 0.5)..strokeWidth = 0.5);
    }

    if (annees.isEmpty) return;
    final step = w / (annees.length - 1 == 0 ? 1 : annees.length - 1);

    // Coussin (filled area between ratio et 8%)
    final fillPath = Path();
    for (var i = 0; i < annees.length; i++) {
      final x = pad.left + i * step;
      final ratio = annees[i].ratioSolvabilitePct;
      final yRatio = pad.top + h * (1 - ratio / chartMax);
      if (i == 0) {
        fillPath.moveTo(x, yRatio);
      } else {
        fillPath.lineTo(x, yRatio);
      }
    }
    for (var i = annees.length - 1; i >= 0; i--) {
      final x = pad.left + i * step;
      fillPath.lineTo(x, y8);
    }
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = AppTheme.accent.withValues(alpha: 0.15));

    // Ligne ratio
    final linePath = Path();
    for (var i = 0; i < annees.length; i++) {
      final x = pad.left + i * step;
      final ratio = annees[i].ratioSolvabilitePct;
      final yRatio = pad.top + h * (1 - ratio / chartMax);
      if (i == 0) {
        linePath.moveTo(x, yRatio);
      } else {
        linePath.lineTo(x, yRatio);
      }
    }
    canvas.drawPath(linePath, Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Points + labels
    for (var i = 0; i < annees.length; i++) {
      final x = pad.left + i * step;
      final ratio = annees[i].ratioSolvabilitePct;
      final y = pad.top + h * (1 - ratio / chartMax);
      canvas.drawCircle(Offset(x, y), 5,
          Paint()..color = AppTheme.accent);
      canvas.drawCircle(Offset(x, y), 3,
          Paint()..color = Colors.white);

      // Ratio label
      textPainter.text = TextSpan(
          text: '${ratio.toStringAsFixed(1)} %',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accent));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 18));

      // Année label
      textPainter.text = TextSpan(
          text: '${annees[i].annee}',
          style: const TextStyle(fontSize: 10, color: AppTheme.muted));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _PlanifChartPainter old) =>
      old.annees != annees || old.chartMax != chartMax;
}

class _PlanifHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.muted);
    return const Row(children: [
      SizedBox(width: 60, child: Text('Année', style: s)),
      Expanded(child: Text('FP dispo.', style: s, textAlign: TextAlign.right)),
      Expanded(child: Text('RWA total', style: s, textAlign: TextAlign.right)),
      Expanded(child: Text('FP requis', style: s, textAlign: TextAlign.right)),
      Expanded(child: Text('Coussin', style: s, textAlign: TextAlign.right)),
      Expanded(child: Text('Ratio', style: s, textAlign: TextAlign.right)),
      SizedBox(width: 36),
    ]);
  }
}

class _PlanifRow extends StatelessWidget {
  const _PlanifRow({required this.a, required this.onEdit});
  final PlanificationAnnee a;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ratioColor = a.ratioSolvabilitePct >= 12 ? AppTheme.success
        : (a.ratioSolvabilitePct >= 8 ? AppTheme.warning : AppTheme.danger);
    final coussinColor = a.coussin >= 0 ? AppTheme.success : AppTheme.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 60, child: Text('${a.annee}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        Expanded(child: Text(_fmtFp(a.fpDisponibles),
            style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        Expanded(child: Text(_fmtFp(a.rwaTotalProjecte),
            style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        Expanded(child: Text(_fmtFp(a.fpRequis),
            style: const TextStyle(fontSize: 12, color: AppTheme.muted), textAlign: TextAlign.right)),
        Expanded(child: Text(_fmtFp(a.coussin),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: coussinColor),
            textAlign: TextAlign.right)),
        Expanded(child: Text('${a.ratioSolvabilitePct.toStringAsFixed(1)} %',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ratioColor),
            textAlign: TextAlign.right)),
        SizedBox(width: 36, child: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 14),
          onPressed: onEdit,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
        )),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MODULE STRESS TESTS (Module 3)
// ──────────────────────────────────────────────────────────────────────────────

class _StressTestsView extends StatefulWidget {
  const _StressTestsView({required this.api});
  final RwaApiService api;

  @override
  State<_StressTestsView> createState() => _StressTestsViewState();
}

class _StressTestsViewState extends State<_StressTestsView> {
  late Future<List<ScenarioStress>> _future;
  StressImpact? _selectedImpact;
  int? _computingId;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchScenarios();
  }

  void _reload() {
    setState(() {
      _future = widget.api.fetchScenarios();
      _selectedImpact = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScenarioStress>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final scenarios = snap.data!;

        return Column(children: [
          SectionCard(
            title: 'Scénarios de stress (${scenarios.length})',
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Nouveau scénario', style: TextStyle(fontSize: 12)),
              onPressed: () => _addScenario(ctx),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: scenarios.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun scénario défini.')))
                  : Column(
                      children: scenarios.map((s) => _ScenarioCard(
                        s: s,
                        isComputing: _computingId == s.id,
                        onCalcul: () => _runStress(s.id),
                        onDelete: () => _deleteScenario(s.id),
                      )).toList(),
                    ),
            ),
          ),
          if (_selectedImpact != null) ...[
            const SizedBox(height: 16),
            _StressResultCard(impact: _selectedImpact!),
          ],
        ]);
      },
    );
  }

  Future<void> _runStress(int id) async {
    setState(() => _computingId = id);
    try {
      final impact = await widget.api.calculStress(id);
      if (!mounted) return;
      setState(() {
        _selectedImpact = impact;
        _computingId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _computingId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _addScenario(BuildContext context) async {
    final nomCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final creditCtrl = TextEditingController(text: '0');
    final marcheCtrl = TextEditingController(text: '0');
    final opCtrl = TextEditingController(text: '0');
    final perteCtrl = TextEditingController(text: '0');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau scénario de stress'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _EditField(label: 'Nom du scénario', ctrl: nomCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Description', ctrl: descCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Choc RWA crédit (%)', ctrl: creditCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Choc RWA marché (%)', ctrl: marcheCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Choc RWA opérationnel (%)', ctrl: opCtrl),
            const SizedBox(height: 8),
            _EditField(label: 'Perte nette absolue (FCFA)', ctrl: perteCtrl),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    try {
      await widget.api.createScenario({
        'nom': nomCtrl.text,
        'description': descCtrl.text,
        'choc_rwa_credit_pct': double.tryParse(creditCtrl.text) ?? 0,
        'choc_rwa_marche_pct': double.tryParse(marcheCtrl.text) ?? 0,
        'choc_rwa_op_pct': double.tryParse(opCtrl.text) ?? 0,
        'choc_perte_nette': double.tryParse(perteCtrl.text) ?? 0,
      });
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _deleteScenario(int id) async {
    try {
      await widget.api.deleteScenario(id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.s,
    required this.isComputing,
    required this.onCalcul,
    required this.onDelete,
  });
  final ScenarioStress s;
  final bool isComputing;
  final VoidCallback onCalcul;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (s.typeScenario) {
      'Sévère'      => AppTheme.danger,
      'Historique'  => AppTheme.accent,
      _             => AppTheme.warning,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
            child: Text(s.typeScenario, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(s.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.muted),
            onPressed: onDelete,
            tooltip: 'Supprimer',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28),
          ),
        ]),
        if (s.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(s.description, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 16, children: [
          _ChocChip(label: 'Crédit', value: s.chocRwaCreditPct),
          _ChocChip(label: 'Marché', value: s.chocRwaArchePct),
          _ChocChip(label: 'Opérationnel', value: s.chocRwaOpPct),
          if (s.chocPerteNette > 0)
            _ChocChip(label: 'Perte nette', value: s.chocPerteNette, isCurrency: true),
        ]),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: isComputing
              ? const SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.calculate_outlined, size: 14),
          label: Text(isComputing ? 'Calcul...' : 'Simuler l\'impact',
              style: const TextStyle(fontSize: 12)),
          onPressed: isComputing ? null : onCalcul,
        ),
      ]),
    );
  }
}

class _ChocChip extends StatelessWidget {
  const _ChocChip({required this.label, required this.value, this.isCurrency = false});
  final String label;
  final double value;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text('$label : ', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
    Text(isCurrency ? _fmtFp(value) : '+${value.toStringAsFixed(0)} %',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

class _StressResultCard extends StatelessWidget {
  const _StressResultCard({required this.impact});
  final StressImpact impact;

  @override
  Widget build(BuildContext context) {
    final color = impact.solvableApresStress ? AppTheme.success : AppTheme.danger;
    return SectionCard(
      title: 'Résultat — ${impact.scenario.nom}',
      trailing: _statusBadge(impact.solvableApresStress ? 'OK' : 'Attention'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            _StressCell(label: 'Ratio base', value: '${impact.ratioBasePct.toStringAsFixed(2)} %',
                color: impact.ratioBasePct >= 8 ? AppTheme.success : AppTheme.danger),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward, color: AppTheme.muted),
            const SizedBox(width: 12),
            _StressCell(label: 'Ratio stressé', value: '${impact.ratioStressePct.toStringAsFixed(2)} %',
                color: color),
            const SizedBox(width: 24),
            _StressCell(label: 'Variation', value: '${impact.variationRatioBp.toStringAsFixed(0)} pb',
                color: impact.variationRatioBp < 0 ? AppTheme.danger : AppTheme.success),
            const SizedBox(width: 24),
            _StressCell(label: 'FP stressés', value: _fmtFp(impact.fpStresse), color: color),
          ]),
          const SizedBox(height: 12),
          // Waterfall bars
          Row(children: [
            Expanded(child: _WaterfallBar(label: 'RWA crédit\nbase', value: impact.rwaCreditBase, max: impact.rwaTotalStresse, color: AppTheme.accent.withValues(alpha: 0.7))),
            const SizedBox(width: 4),
            Expanded(child: _WaterfallBar(label: 'RWA crédit\nstressé', value: impact.rwaCreditStresse, max: impact.rwaTotalStresse, color: AppTheme.accent)),
            const SizedBox(width: 16),
            Expanded(child: _WaterfallBar(label: 'RWA marché\nbase', value: impact.rwaMarcheBase, max: impact.rwaTotalStresse, color: AppTheme.warning.withValues(alpha: 0.7))),
            const SizedBox(width: 4),
            Expanded(child: _WaterfallBar(label: 'RWA marché\nstressé', value: impact.rwaMarcheStresse, max: impact.rwaTotalStresse, color: AppTheme.warning)),
            const SizedBox(width: 16),
            Expanded(child: _WaterfallBar(label: 'RWA op.\nbase', value: impact.rwaOpBase, max: impact.rwaTotalStresse, color: AppTheme.danger.withValues(alpha: 0.7))),
            const SizedBox(width: 4),
            Expanded(child: _WaterfallBar(label: 'RWA op.\nstressé', value: impact.rwaOpStresse, max: impact.rwaTotalStresse, color: AppTheme.danger)),
          ]),
        ]),
      ),
    );
  }
}

class _StressCell extends StatelessWidget {
  const _StressCell({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
  ]);
}

class _WaterfallBar extends StatelessWidget {
  const _WaterfallBar({required this.label, required this.value, required this.max, required this.color});
  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      SizedBox(
        height: 80,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted), textAlign: TextAlign.center),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MODULE GOUVERNANCE / CHECKLIST (Module 4)
// ──────────────────────────────────────────────────────────────────────────────

class _GouvernanceView extends StatefulWidget {
  const _GouvernanceView({required this.api});
  final RwaApiService api;

  @override
  State<_GouvernanceView> createState() => _GouvernanceViewState();
}

class _GouvernanceViewState extends State<_GouvernanceView> {
  late Future<GouvernanceResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchGouvernance();
  }

  void _reload() => setState(() => _future = widget.api.fetchGouvernance());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GouvernanceResult>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final d = snap.data!;

        return Column(children: [
          // KPI donut + stats
          SectionCard(
            title: 'Conformité PIEAFP',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                // Mini donut
                SizedBox(width: 120, height: 120,
                    child: CustomPaint(
                        painter: _GouvernanceDonut(
                            conforme: d.nbConforme, enCours: d.nbEnCours,
                            aFaire: d.nbAFaire, na: d.nbNa))),
                const SizedBox(width: 24),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d.tauxConformitePct.toStringAsFixed(0)} %',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                          color: d.tauxConformitePct >= 80 ? AppTheme.success : AppTheme.warning)),
                  const Text('taux de conformité', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _LegendDot(color: AppTheme.success, label: 'Conforme (${d.nbConforme})'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.warning, label: 'En cours (${d.nbEnCours})'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.danger, label: 'À faire (${d.nbAFaire})'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.muted, label: 'N/A (${d.nbNa})'),
                  ]),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // Checklist
          SectionCard(
            title: 'Checklist de conformité PIEAFP',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: d.items.map((item) => _ChecklistRow(
                item: item,
                onUpdate: (statut) => _updateItem(item.id, statut),
              )).toList()),
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _updateItem(int id, String statut) async {
    try {
      await widget.api.updateChecklistItem(id, {'statut': statut});
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _GouvernanceDonut extends CustomPainter {
  const _GouvernanceDonut({
    required this.conforme,
    required this.enCours,
    required this.aFaire,
    required this.na,
  });
  final int conforme, enCours, aFaire, na;

  @override
  void paint(Canvas canvas, Size size) {
    final total = (conforme + enCours + aFaire + na).toDouble();
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeW = radius * 0.38;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeW;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeW / 2);
    final segments = [
      (conforme / total, AppTheme.success),
      (enCours / total, AppTheme.warning),
      (aFaire / total, AppTheme.danger),
      (na / total, AppTheme.muted),
    ];
    var startAngle = -math.pi / 2;
    for (final (pct, color) in segments) {
      if (pct <= 0) continue;
      paint.color = color;
      final sweep = pct * 2 * math.pi;
      canvas.drawArc(rect, startAngle, sweep - 0.04, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _GouvernanceDonut old) => false;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
  ]);
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item, required this.onUpdate});
  final ChecklistItem item;
  final ValueChanged<String> onUpdate;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.statut) {
      'Conforme'        => AppTheme.success,
      'En cours'        => AppTheme.warning,
      'Non applicable'  => AppTheme.muted,
      _                 => AppTheme.danger,
    };
    final icon = switch (item.statut) {
      'Conforme'        => Icons.check_circle_outline,
      'En cours'        => Icons.pending_outlined,
      'Non applicable'  => Icons.remove_circle_outline,
      _                 => Icons.radio_button_unchecked,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: statusColor),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.element, style: const TextStyle(fontSize: 13)),
          Text(item.categorie, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
        ])),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: item.statut,
          underline: const SizedBox(),
          isDense: true,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
          items: const ['Conforme', 'En cours', 'A faire', 'Non applicable']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) { if (val != null) onUpdate(val); },
        ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MODULE RAPPORT PIEAFP (Module 5)
// ──────────────────────────────────────────────────────────────────────────────

class _RapportView extends StatefulWidget {
  const _RapportView({required this.api});
  final RwaApiService api;

  @override
  State<_RapportView> createState() => _RapportViewState();
}

class _RapportViewState extends State<_RapportView> {
  late Future<PieafpRapport> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchPieafpRapport();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PieafpRapport>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return _loadingBox();
        if (snap.hasError) return _errorBox(snap.error);
        final r = snap.data!;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header rapport
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent.withValues(alpha: 0.9), AppTheme.accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.description_outlined, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RAPPORT PIEAFP — Processus Interne d\'Évaluation de l\'Adéquation des Fonds Propres',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Date d\'établissement : ${r.dateRapport}  •  Cadre réglementaire : UMOA Titre XI art. 505-549',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          // Section 1 : Solvabilité
          _RapportSection(
            numero: '1',
            titre: 'Adéquation des fonds propres',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RapportLigne('Fonds propres totaux (Tier 1 + Tier 2)', _fmtFp(r.fpTotal)),
              _RapportLigne('RWA total (crédit + marché + opérationnel)', _fmtFp(r.rwaTotal)),
              _RapportLigne('Ratio de solvabilité', '${r.ratioSolvabilitePct.toStringAsFixed(2)} %',
                  color: r.ratioSolvabilitePct >= 8 ? AppTheme.success : AppTheme.danger),
              const _RapportLigne('Seuil réglementaire minimal (BCEAO)', '8,00 %'),
              _RapportLigne('Excédent / Déficit de capital',
                  _fmtFp(r.fpTotal - r.rwaTotal * 0.08),
                  color: r.fpTotal >= r.rwaTotal * 0.08 ? AppTheme.success : AppTheme.danger),
            ]),
          ),
          const SizedBox(height: 12),
          // Section 2 : Risques Pilier 2
          _RapportSection(
            numero: '2',
            titre: 'Cartographie des risques Pilier 2',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RapportSousSection('1.2 Risque de concentration',
                  r.concentration.axes.isEmpty
                      ? 'Aucune donnée — portefeuille vide'
                      : 'HHI max : ${r.concentration.axes.map((a) => a.hhi).fold(0.0, math.max).round()} '
                        '• ${r.concentration.nbContreparties} contreparties actives '
                        '• ${r.concentration.grandsRisquesNb} grand(s) risque(s) (> 25% FP)'),
              const SizedBox(height: 8),
              _RapportSousSection('1.6 Risque de taux (IRRBB)',
                  'ΔNII (choc +${r.irrbb.chocBp} pb) = ${_fmtFp(r.irrbb.deltaNii200bp)} '
                  '(${r.irrbb.deltaNiiPctFp.toStringAsFixed(1)} % des FP) — Niveau : ${r.irrbb.niveauRisque}'),
              const SizedBox(height: 8),
              const _RapportSousSection('1.7 Risque de liquidité',
                  'Hors périmètre PIEAFP — données indisponibles à ce stade (LCR/NSFR non calculés)'),
              const SizedBox(height: 8),
              _RapportSousSection('1.8 Autres risques Pilier 2',
                  '${r.autresRisques.length} risque(s) identifié(s) — '
                  '${r.autresRisques.where((x) => x.niveau == "Critique").length} critique(s), '
                  '${r.autresRisques.where((x) => x.niveau == "Élevé").length} élevé(s)'),
            ]),
          ),
          const SizedBox(height: 12),
          // Section 3 : Planification
          _RapportSection(
            numero: '3',
            titre: 'Planification pluriannuelle du capital',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: r.planification.annees.map((a) => _RapportLigne(
                    '${a.annee} — Ratio projeté',
                    '${a.ratioSolvabilitePct.toStringAsFixed(1)} %  (coussin : ${_fmtFp(a.coussin)})',
                    color: a.ratioSolvabilitePct >= 8 ? AppTheme.success : AppTheme.danger)).toList()),
          ),
          const SizedBox(height: 12),
          // Section 4 : Gouvernance
          _RapportSection(
            numero: '4',
            titre: 'Gouvernance et conformité du processus',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RapportLigne('Taux de conformité checklist PIEAFP',
                  '${r.gouvernance.tauxConformitePct.toStringAsFixed(0)} %',
                  color: r.gouvernance.tauxConformitePct >= 80 ? AppTheme.success : AppTheme.warning),
              _RapportLigne('Éléments conformes', '${r.gouvernance.nbConforme} / ${r.gouvernance.items.length}'),
              _RapportLigne('Éléments en cours', '${r.gouvernance.nbEnCours}'),
              _RapportLigne('Éléments à traiter', '${r.gouvernance.nbAFaire}',
                  color: r.gouvernance.nbAFaire > 0 ? AppTheme.danger : null),
            ]),
          ),
          const SizedBox(height: 16),
          // Pied de page
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.muted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Ce rapport est établi dans le cadre du PIEAFP conformément à UMOA Titre XI (art. 505-549) et aux instructions BCEAO. '
              'Il est destiné à la Direction Générale, au Conseil d\'Administration et à la BCEAO dans le cadre de la surveillance prudentielle (SREP).',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ),
        ]);
      },
    );
  }
}

class _RapportSection extends StatelessWidget {
  const _RapportSection({required this.numero, required this.titre, required this.child});
  final String numero;
  final String titre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              child: Center(child: Text(numero,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 10),
            Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }
}

class _RapportLigne extends StatelessWidget {
  const _RapportLigne(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.muted))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: color ?? AppTheme.text)),
    ]),
  );
}

class _RapportSousSection extends StatelessWidget {
  const _RapportSousSection(this.titre, this.texte);
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(titre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    const SizedBox(height: 3),
    Text(texte, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
  ]);
}

// ──────────────────────────────────────────────────────────────────────────────
// Utilitaire partagé — champ de saisie
// ──────────────────────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  const _EditField({required this.label, required this.ctrl});
  final String label;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  );
}
