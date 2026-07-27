import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart' show AppFormatters;
import '../../../shared/widgets/section_card.dart';
import '../../risque_credit_shared/widgets/credit_module_toolbar.dart';
import '../models/ro_models.dart';
import 'ro_hero_stat_card.dart';
import 'uemoi_form_style.dart';

// Couleurs de bandeau utilisées pour distinguer visuellement les cartes
// d'exercice, dans l'ordre le plus récent -> le plus ancien.
const _kExerciceColors = [AppTheme.accent, AppColors.prudentialCapital, AppTheme.muted];

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

    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      pageBuilder: (dialogContext, _, __) => Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: StatefulBuilder(
            builder: (dialogContext, setD) {
              final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
              return Container(
                width: 420,
                constraints: const BoxConstraints(maxHeight: 640),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            initial == null ? 'Nouvel exercice PNB' : 'Modifier l\'exercice ${initial.annee}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                          color: AppTheme.muted,
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: UemoiFormCard(
                            title: initial == null ? 'Nouvel exercice' : 'Exercice ${initial.annee}',
                            subtitle: 'Indicateur de Base - BCEAO',
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
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sidebar,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          icon: saving
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 15),
                          label: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
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
          SectionCard(
            title: 'PNB annuel (N-2, N-1, N) - Indicateur de Base',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreditModuleToolbar(
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
                const SizedBox(height: AppSpacing.md),
                if (annees.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(
                      'Aucun exercice saisi. Ajoutez le PNB des 3 derniers exercices.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (var i = 0; i < annees.length; i++)
                        SizedBox(
                          width: 320,
                          child: _buildExerciceCard(annees[i], _kExerciceColors[i % _kExerciceColors.length]),
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

  Widget _buildExerciceCard(PnbAnnuelView a, Color color) {
    return UemoiFormCard(
      title: 'Exercice ${a.annee}',
      subtitle: a.sourceDocument.isEmpty ? 'Indicateur de Base - BCEAO' : a.sourceDocument,
      color: color,
      trailing: Row(
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
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
          ),
        ],
      ),
      children: [
        UemoiInfoRow(label: 'PNB total', value: AppFormatters.currency(a.produitBrutTotal)),
        UemoiInfoRow(
          label: 'Statut AIB',
          value: a.pnbPositif ? AppFormatters.currency(a.pnbRetenuAib) : 'Exclu (négatif)',
          valueColor: a.pnbPositif ? AppTheme.success : AppTheme.muted,
        ),
        UemoiInfoRow(label: 'Source', value: a.sourceDocument.isEmpty ? '-' : a.sourceDocument),
      ],
    );
  }

  Widget _buildStatGrid(AibCalculResult? r) {
    final insuffisant = r == null || r.donneesInsuffisantes;
    final stats = [
      RoHeroStatCard(
        label: 'K_IB (Exigence)',
        value: insuffisant ? '-' : AppFormatters.currency(r.kIb),
        subtitle: 'Capital risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'APR Opérationnel',
        value: insuffisant ? '-' : AppFormatters.currency(r.aprAib),
        subtitle: 'RWA risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'Capital minimal (9 %)',
        value: insuffisant ? '-' : AppFormatters.currency(r.capitalMinAib),
        subtitle: 'Capital minimum requis',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (final stat in stats) ...[
                stat,
                const SizedBox(height: AppTheme.spacing),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: AppTheme.spacing),
              Expanded(child: stats[i]),
            ],
          ],
        );
      },
    );
  }
}
