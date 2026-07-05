import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart' show AppFormatters;
import '../../risque_credit_shared/widgets/credit_data_table_card.dart';
import '../../risque_credit_shared/widgets/credit_module_toolbar.dart';
import '../../risque_credit_shared/widgets/credit_stat_card.dart';
import '../models/ro_models.dart';
import 'uemoi_form_style.dart';

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
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  Future<void> _openExerciceDialog({PnbAnnuelView? initial}) async {
    final anneeCtrl = TextEditingController(text: initial == null ? '' : '${initial.annee}');
    final pnbCtrl = TextEditingController(
        text: initial == null ? '' : initial.produitBrutTotal.toStringAsFixed(0));
    final srcCtrl = TextEditingController(text: initial?.sourceDocument ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setD) => AlertDialog(
          title: Text(initial == null ? 'Nouvel exercice PNB' : 'Modifier l\'exercice ${initial.annee}'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: UemoiFormCard(
                title: initial == null ? 'Nouvel exercice' : 'Exercice ${initial.annee}',
                subtitle: 'Indicateur de Base — BCEAO',
                color: AppTheme.accent,
                children: [
                  UemoiFormField(
                    label: 'Exercice',
                    controller: anneeCtrl,
                    enabled: initial == null,
                    hint: '2024',
                    numeric: true,
                    required: true,
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Année invalide' : null,
                  ),
                  UemoiFormField(
                    label: 'Produit Brut',
                    controller: pnbCtrl,
                    hint: 'ex. 500 000 000',
                    suffixText: ' FCFA',
                    numeric: true,
                    required: true,
                    validator: (v) => double.tryParse(v?.replaceAll(' ', '') ?? '') == null
                        ? 'Montant invalide'
                        : null,
                  ),
                  UemoiFormField(
                    label: 'Référence documents',
                    controller: srcCtrl,
                    hint: 'Comptes audités 2024',
                    numeric: false,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final annee = int.tryParse(anneeCtrl.text.trim());
                      final pnb = double.tryParse(pnbCtrl.text.trim().replaceAll(' ', ''));
                      if (annee == null || pnb == null) return;
                      setD(() => saving = true);
                      try {
                        await widget.api.upsertPnbAnnuel(annee, {
                          'produit_brut_total': pnb,
                          'source_document': srcCtrl.text.trim(),
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (e) {
                        setD(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
                          );
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 15),
              label: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );

    anneeCtrl.dispose();
    pnbCtrl.dispose();
    srcCtrl.dispose();

    if (ok == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(initial == null
                ? 'Exercice enregistré avec succès.'
                : 'Exercice mis à jour avec succès.'),
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.success, content: Text('Exercice supprimé.')),
        );
      }
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
    final query = _searchCtrl.text.trim().toLowerCase();
    final annees = (r?.anneesSaisies ?? const <PnbAnnuelView>[]).where((a) {
      if (query.isEmpty) return true;
      return '${a.annee}'.contains(query) || a.sourceDocument.toLowerCase().contains(query);
    }).toList(growable: false);

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatGrid(r),
          AppSpacing.gapMd,
          CreditDataTableCard(
            title: 'PNB annuel (N-2, N-1, N) — Indicateur de Base',
            emptyMessage: 'Aucun exercice saisi. Ajoutez le PNB des 3 derniers exercices.',
            toolbar: CreditModuleToolbar(
              searchController: _searchCtrl,
              searchHint: 'Rechercher un exercice ou une source',
              onSearchChanged: (_) => setState(() {}),
              actions: [
                FilledButton.icon(
                  onPressed: () => _openExerciceDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouvel exercice'),
                ),
              ],
            ),
            columns: const [
              DataColumn(label: Text('Exercice')),
              DataColumn(label: Text('PNB total'), numeric: true),
              DataColumn(label: Text('Statut AIB')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Actions')),
            ],
            rows: annees
                .map((a) => DataRow(cells: [
                      DataCell(Text('${a.annee}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(AppFormatters.currency(a.produitBrutTotal))),
                      DataCell(a.pnbPositif
                          ? Text(AppFormatters.currency(a.pnbRetenuAib),
                              style: const TextStyle(
                                  color: AppTheme.success, fontWeight: FontWeight.w500))
                          : const Text('Exclu (négatif)', style: TextStyle(color: AppTheme.muted))),
                      DataCell(Text(a.sourceDocument.isEmpty ? '—' : a.sourceDocument)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Modifier',
                            onPressed: () => _openExerciceDialog(initial: a),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Supprimer',
                            onPressed: () => _confirmDelete(a.annee),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppTheme.danger),
                          ),
                        ],
                      )),
                    ]))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(AibCalculResult? r) {
    final insuffisant = r == null || r.donneesInsuffisantes;
    final stats = [
      CreditStatCard(
        label: 'K_IB (Exigence)',
        value: insuffisant ? '—' : AppFormatters.currency(r.kIb),
        helper: 'Capital risque opérationnel',
        icon: Icons.shield_outlined,
        color: AppTheme.accent,
      ),
      CreditStatCard(
        label: 'APR Opérationnel',
        value: insuffisant ? '—' : AppFormatters.currency(r.aprAib),
        helper: 'RWA risque opérationnel',
        icon: Icons.assessment_outlined,
        color: AppColors.prudentialCapital,
      ),
      CreditStatCard(
        label: 'Capital minimal (9 %)',
        value: insuffisant ? '—' : AppFormatters.currency(r.capitalMinAib),
        helper: 'Capital minimum requis',
        icon: Icons.account_balance_outlined,
        color: AppTheme.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 960
            ? 210.0
            : constraints.maxWidth >= 620
                ? ((constraints.maxWidth - AppTheme.spacing) / 2).clamp(0.0, 210.0).toDouble()
                : constraints.maxWidth;

        return Wrap(
          spacing: AppTheme.spacing,
          runSpacing: AppTheme.spacing,
          children: [
            for (final stat in stats) SizedBox(width: width, child: stat),
          ],
        );
      },
    );
  }
}
