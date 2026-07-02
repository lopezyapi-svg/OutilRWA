import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart' show AppFormatters;
import '../../../shared/widgets/kpi_metric_card.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/ro_models.dart';
import 'decision_panel.dart';

class UemoiAsScreen extends StatefulWidget {
  const UemoiAsScreen({super.key, required this.api});
  final RwaApiService api;

  @override
  State<UemoiAsScreen> createState() => _UemoiAsScreenState();
}

class _UemoiAsScreenState extends State<UemoiAsScreen> {
  AsCalculResult? _result;
  ParametresAs? _params;
  List<BetaLigneView> _betas = [];
  bool _loading = true;
  String? _error;

  int _anneeSelect = DateTime.now().year - 1;
  final Map<String, TextEditingController> _pnbCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _pnbCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.api.calculeAs(),
        widget.api.fetchAsParametres(),
        widget.api.fetchBetaLignes(),
      ]);
      final r = results[0] as AsCalculResult;
      final p = results[1] as ParametresAs;
      final b = results[2] as List<BetaLigneView>;

      for (final c in _pnbCtrls.values) {
        c.dispose();
      }
      _pnbCtrls.clear();

      final lignes = await widget.api.fetchPnbLignes(_anneeSelect);
      final lignesMap = {for (final l in lignes) l.ligneMetier: l.produitBrutLigne};
      for (final beta in b) {
        final val = lignesMap[beta.ligneMetier];
        _pnbCtrls[beta.ligneMetier] = TextEditingController(
          text: val != null ? val.toStringAsFixed(0) : '',
        );
      }

      setState(() { _result = r; _params = p; _betas = b; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAllLignes() async {
    setState(() => _saving = true);
    try {
      for (final entry in _pnbCtrls.entries) {
        final val = double.tryParse(entry.value.text.trim().replaceAll(' ', ''));
        if (val != null) {
          await widget.api.upsertPnbLigne(_anneeSelect, entry.key, val);
        }
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PNB enregistrés'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 36),
          AppSpacing.gapMd,
          Text('Erreur de chargement', style: Theme.of(context).textTheme.bodyMedium),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ]),
      );
    }

    final r = _result!;
    final p = _params!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkMuted : AppTheme.muted;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière autorisation Commission Bancaire
          if (!p.asAutorisee)
            const _NoticeBanner(
              color: AppTheme.danger,
              icon: Icons.lock_outlined,
              text: 'L\'Approche Standard nécessite l\'autorisation préalable de la Commission Bancaire'
                  ' (art. 300 UEMOA). Les calculs ci-dessous sont affichés à titre indicatif uniquement.',
            )
          else
            _NoticeBanner(
              color: AppTheme.success,
              icon: Icons.verified_outlined,
              text: 'Approche Standard — Art. 305-311 UEMOA · Autorisation CB obtenue'
                  '${p.referenceAutorisation.isNotEmpty ? " · Réf. ${p.referenceAutorisation}" : ""}',
            ),
          AppSpacing.gapSm,

          // KPI résultats
          if (!r.donneesInsuffisantes) ...[
            Row(children: [
              Expanded(child: KpiMetricCard(
                label: 'K_AS (Exigence)',
                value: AppFormatters.currency(r.kAs),
                helper: 'capital risque operationnel',
                icon: Icons.shield_outlined,
                color: AppTheme.accent,
              )),
              AppSpacing.hGapSm,
              Expanded(child: KpiMetricCard(
                label: 'APR Opérationnel',
                value: AppFormatters.currency(r.aprAs),
                helper: 'rwa risque operationnel',
                icon: Icons.assessment_outlined,
                color: AppColors.prudentialCapital,
              )),
              AppSpacing.hGapSm,
              Expanded(child: KpiMetricCard(
                label: 'Capital minimal (8 %)',
                value: AppFormatters.currency(r.capitalMinAs),
                helper: 'capital minimum requis',
                icon: Icons.account_balance_outlined,
                color: AppTheme.success,
              )),
            ]),
            AppSpacing.gapSm,
          ],

          if (r.donneesInsuffisantes) ...[
            const _NoticeBanner(
              color: AppTheme.warning,
              icon: Icons.warning_amber_outlined,
              text: 'Aucune donnée PNB par ligne de métier saisie.'
                  ' Renseignez les 8 lignes pour les 3 exercices.',
            ),
            AppSpacing.gapSm,
          ],

          // Détail par année (expansion)
          if (r.detailParAnnee.isNotEmpty) ...[
            SectionCard(
              title: 'Détail par année (K = PNB × β)',
              child: Column(
                children: r.detailParAnnee
                    .map((d) => _AnneeDetailTile(d: d, muted: muted))
                    .toList(),
              ),
            ),
            AppSpacing.gapSm,
          ],

          // Saisie PNB par ligne
          SectionCard(
            title: 'PNB par ligne de métier',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ...[DateTime.now().year - 2, DateTime.now().year - 1, DateTime.now().year].map((y) =>
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text('$y',
                        style: const TextStyle(fontSize: 11)),
                    selected: _anneeSelect == y,
                    onSelected: (_) async {
                      setState(() => _anneeSelect = y);
                      final lignes = await widget.api.fetchPnbLignes(y);
                      final lignesMap = {
                        for (final l in lignes) l.ligneMetier: l.produitBrutLigne
                      };
                      setState(() {
                        for (final e in _pnbCtrls.entries) {
                          final val = lignesMap[e.key];
                          e.value.text = val != null ? val.toStringAsFixed(0) : '';
                        }
                      });
                    },
                  ),
                ),
              ),
            ]),
            child: Column(
              children: [
                // En-tête
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text('Ligne de métier',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
                    SizedBox(width: 52, child: Text('β',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: Text('PNB $_anneeSelect (FCFA)',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
                  ]),
                ),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: AppSpacing.sm),
                ..._betas.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(b.ligneMetier,
                        style: Theme.of(context).textTheme.bodyMedium)),
                    SizedBox(
                      width: 52,
                      child: Center(child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                        ),
                        child: Text('${(b.beta * 100).toStringAsFixed(0)} %',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600)),
                      )),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: TextFormField(
                      controller: _pnbCtrls[b.ligneMetier],
                      keyboardType: TextInputType.number,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(hintText: '0'),
                    )),
                  ]),
                )),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 15),
                    label: Text(_saving ? 'Enregistrement…' : 'Enregistrer $_anneeSelect'),
                    onPressed: _saving ? null : _saveAllLignes,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,

          const _FormulaBox(
            'Formule AS (art. 305-311) :'
            '  K_annee = MAX(Σ(PNB_ligne × β), 0)'
            '  →  K_AS = MOYENNE(K_N-2, K_N-1, K_N)'
            '  →  APR = K_AS × 12,5',
          ),
          AppSpacing.gapSm,

          DecisionPanel(loader: widget.api.fetchDecisionAs),
        ],
      ),
    );
  }
}

// ─── Tile année avec ExpansionTile ─────────────────────────────────────────────

class _AnneeDetailTile extends StatelessWidget {
  const _AnneeDetailTile({required this.d, required this.muted});
  final AsAnneeDetail d;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final kOk = d.kRetenu >= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ExpansionTile(
        key: PageStorageKey<int>(d.annee),
        tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 0),
        title: Row(children: [
          Text('Exercice ${d.annee}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          _KPill('K : ${AppFormatters.currency(d.kTotal)}',
              d.kTotal >= 0 ? AppTheme.success : AppTheme.danger),
          const SizedBox(width: AppSpacing.sm),
          _KPill('Retenu : ${AppFormatters.currency(d.kRetenu)}',
              kOk ? AppTheme.accent : AppTheme.warning),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Column(
              children: d.lignes.map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(l.ligneMetier,
                      style: Theme.of(context).textTheme.bodyMedium)),
                  Expanded(flex: 2, child: Text(AppFormatters.currency(l.pnb),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium)),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(width: 48, child: Text(
                      '× ${(l.beta * 100).toStringAsFixed(0)} %',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted))),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: Text(
                      '= ${AppFormatters.currency(l.kLigne)}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: l.kLigne >= 0 ? null : AppTheme.warning))),
                ]),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _KPill extends StatelessWidget {
  const _KPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Helpers privés ───────────────────────────────────────────────────────────

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner(
      {required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 14),
        AppSpacing.hGapMd,
        Expanded(
          child: Text(text,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ),
      ]),
    );
  }
}

class _FormulaBox extends StatelessWidget {
  const _FormulaBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkMuted : AppTheme.muted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.border),
      ),
      child: Text(text,
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
    );
  }
}
