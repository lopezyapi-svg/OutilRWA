import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart' show AppFormatters;
import '../../../shared/widgets/kpi_metric_card.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/ro_models.dart';

class UemoiAibScreen extends StatefulWidget {
  const UemoiAibScreen({super.key, required this.api});
  final RwaApiService api;

  @override
  State<UemoiAibScreen> createState() => _UemoiAibScreenState();
}

class _UemoiAibScreenState extends State<UemoiAibScreen> {
  AibCalculResult? _result;
  bool _loading = true;
  String? _error;

  final _anneeCtrl = TextEditingController();
  final _pnbCtrl   = TextEditingController();
  final _srcCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _anneeCtrl.dispose();
    _pnbCtrl.dispose();
    _srcCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.api.calculeAib();
      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePnb() async {
    if (!_formKey.currentState!.validate()) return;
    final annee = int.tryParse(_anneeCtrl.text.trim());
    final pnb   = double.tryParse(_pnbCtrl.text.trim().replaceAll(' ', ''));
    if (annee == null || pnb == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.upsertPnbAnnuel(annee, {
        'produit_brut_total': pnb,
        'source_document': _srcCtrl.text.trim(),
      });
      _anneeCtrl.clear();
      _pnbCtrl.clear();
      _srcCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(int annee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer l\'exercice ?'),
        content: Text('L\'exercice $annee sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deletePnbAnnuel(annee);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
        );
      }
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

    final r = _result;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkMuted : AppTheme.muted;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeBanner(
            color: AppTheme.accent,
            icon: Icons.gavel_outlined,
            text: 'Approche Indicateur de Base — Art. 301 UEMOA · Déclaratoire BCEAO'
                ' · Coefficient α = ${r != null ? (r.alpha * 100).toStringAsFixed(0) : 15} %',
          ),
          AppSpacing.gapSm,

          if (r != null && !r.donneesInsuffisantes) ...[
            Row(children: [
              Expanded(child: KpiMetricCard(
                label: 'K_IB (Exigence)',
                value: AppFormatters.currency(r.kIb),
                helper: 'capital risque operationnel',
                icon: Icons.shield_outlined,
                color: AppTheme.accent,
              )),
              AppSpacing.hGapSm,
              Expanded(child: KpiMetricCard(
                label: 'APR Opérationnel',
                value: AppFormatters.currency(r.aprAib),
                helper: 'rwa risque operationnel',
                icon: Icons.assessment_outlined,
                color: AppColors.prudentialCapital,
              )),
              AppSpacing.hGapSm,
              Expanded(child: KpiMetricCard(
                label: 'Capital minimal (8 %)',
                value: AppFormatters.currency(r.capitalMinAib),
                helper: 'capital minimum requis',
                icon: Icons.account_balance_outlined,
                color: AppTheme.success,
              )),
            ]),
            AppSpacing.gapXs,
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              _InfoPill('n = ${r.n} ann. PNB positif', muted),
              _InfoPill('PNB moyen = ${AppFormatters.currency(r.pnbMoyen)}', muted),
              _InfoPill('Σ PNB = ${AppFormatters.currency(r.sommePnbPositifs)}', muted),
            ]),
            AppSpacing.gapSm,
          ],

          if (r != null && r.donneesInsuffisantes) ...[
            _NoticeBanner(
              color: AppTheme.warning,
              icon: Icons.warning_amber_outlined,
              text: 'Aucune donnée PNB saisie. Renseignez au moins 1 exercice pour lancer le calcul.',
            ),
            AppSpacing.gapSm,
          ],

          SectionCard(
            title: 'PNB annuel (N-2, N-1, N)',
            child: r == null || r.anneesSaisies.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: Text('Aucun exercice saisi',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted))),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      horizontalMargin: 8,
                      headingRowHeight: 36,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      dividerThickness: 0.35,
                      headingTextStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: const [
                        DataColumn(label: Text('Exercice')),
                        DataColumn(label: Text('PNB total'), numeric: true),
                        DataColumn(label: Text('Statut AIB')),
                        DataColumn(label: Text('Source')),
                        DataColumn(label: Text('')),
                      ],
                      rows: r!.anneesSaisies.map((a) => DataRow(cells: [
                        DataCell(Text('${a.annee}',
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(AppFormatters.currency(a.produitBrutTotal))),
                        DataCell(a.pnbPositif
                            ? Text(AppFormatters.currency(a.pnbRetenuAib),
                                style: const TextStyle(
                                    color: AppTheme.success, fontWeight: FontWeight.w500))
                            : Text('Exclu (négatif)',
                                style: TextStyle(color: muted))),
                        DataCell(Text(a.sourceDocument.isEmpty ? '—' : a.sourceDocument)),
                        DataCell(IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          color: AppTheme.danger,
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDelete(a.annee),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        )),
                      ])).toList(),
                    ),
                  ),
          ),
          AppSpacing.gapSm,

          SectionCard(
            title: 'Saisir / mettre à jour un exercice',
            child: Form(
              key: _formKey,
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _anneeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Exercice', hintText: '2024'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v ?? '') == null ? 'Année invalide' : null,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      controller: _pnbCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Produit Brut (FCFA)',
                          hintText: 'ex. 500 000 000'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v?.replaceAll(' ', '') ?? '') == null
                              ? 'Montant invalide'
                              : null,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      controller: _srcCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Référence documents',
                          hintText: 'Comptes audités 2024'),
                    ),
                  ),
                  FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 15),
                    label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                    onPressed: _saving ? null : _savePnb,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          _FormulaBox(
            'K_IB = Σ(PNB positifs) / n × α    |    APR = K_IB × 12,5    |    Capital = APR × 8 %\n'
            'n = années avec PNB > 0 sur 3 exercices (art. 301 UEMOA)',
          ),
        ],
      ),
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color)),
        ),
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w500)),
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
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: muted)),
    );
  }
}
