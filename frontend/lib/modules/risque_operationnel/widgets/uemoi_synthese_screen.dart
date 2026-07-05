import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart' show AppFormatters;
import '../../../shared/widgets/section_card.dart';
import '../../risque_credit_shared/widgets/credit_data_table_card.dart';
import '../../risque_credit_shared/widgets/credit_stat_card.dart';
import '../models/ro_models.dart';

class UemoiSyntheseScreen extends StatefulWidget {
  const UemoiSyntheseScreen({super.key, required this.api});
  final RwaApiService api;

  @override
  State<UemoiSyntheseScreen> createState() => _UemoiSyntheseScreenState();
}

class _UemoiSyntheseScreenState extends State<UemoiSyntheseScreen> {
  SyntheseResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.api.fetchSynthese();
      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkMuted : AppTheme.muted;
    final ecart = r.ecartBicVsAib;
    final ratio = r.ratioCouverture;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateurs d'écart
          if (ecart != null || ratio != null) ...[
            LayoutBuilder(builder: (context, constraints) {
              final stats = [
                if (ecart != null)
                  CreditStatCard(
                    label: 'Écart BIC − AIB',
                    value: AppFormatters.currency(ecart),
                    helper: 'Risque opérationnel capital',
                    icon: ecart < 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    color: ecart < 0 ? AppTheme.success : AppTheme.danger,
                  ),
                if (ratio != null)
                  CreditStatCard(
                    label: 'Ratio couverture Pilier 1/2',
                    value: '${ratio.toStringAsFixed(2)}×',
                    helper: 'Couverture capital pertes opérationnelles',
                    icon: ratio >= 1.0
                        ? Icons.shield_outlined
                        : Icons.warning_amber_outlined,
                    color: ratio >= 1.0 ? AppColors.success : AppTheme.danger,
                  ),
              ];
              final width = constraints.maxWidth >= 620
                  ? ((constraints.maxWidth - AppTheme.spacing) / 2)
                      .clamp(0.0, 260.0)
                      .toDouble()
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppTheme.spacing,
                runSpacing: AppTheme.spacing,
                children: [
                  for (final stat in stats) SizedBox(width: width, child: stat),
                ],
              );
            }),
            AppSpacing.gapMd,
          ],

          // Tableau comparatif
          CreditDataTableCard(
            title: 'Tableau comparatif AIB / AS / BIC',
            columns: const [
              DataColumn(label: Text('Méthode')),
              DataColumn(label: Text('K (Exigence)'), numeric: true),
              DataColumn(label: Text('APR'), numeric: true),
              DataColumn(label: Text('Capital min.'), numeric: true),
              DataColumn(label: Text('Statut')),
            ],
            rows: r.lignes.map((l) {
              final isBic = l.methode.contains('BIC');
              final faded = !l.disponible;
              return DataRow(
                color: isBic
                    ? WidgetStatePropertyAll(
                        AppTheme.accent.withValues(alpha: 0.04))
                    : null,
                cells: [
                  DataCell(Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.methode,
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: faded ? muted : null)),
                      if (isBic)
                        Text('Pilotage interne — non déclaratoire',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.warning)),
                    ],
                  )),
                  DataCell(Text(
                      l.disponible ? AppFormatters.currency(l.k) : '—',
                      style: TextStyle(
                          color: faded ? muted : null,
                          fontWeight:
                              l.disponible ? FontWeight.w600 : null))),
                  DataCell(Text(
                      l.disponible ? AppFormatters.currency(l.apr) : '—',
                      style: TextStyle(color: faded ? muted : null))),
                  DataCell(Text(
                      l.disponible
                          ? AppFormatters.currency(l.capitalMin)
                          : '—',
                      style: TextStyle(color: faded ? muted : null))),
                  DataCell(_StatusBadge(ok: l.disponible, muted: muted)),
                ],
              );
            }).toList(),
          ),
          AppSpacing.gapSm,

          // Note pédagogique
          SectionCard(
            title: 'Lecture du tableau',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Note('AIB : approche par défaut BCEAO. Exigible dès la 1re année. Coefficient α = 15 %.', muted),
                _Note('AS : réservée aux établissements ayant obtenu l\'autorisation de la Commission Bancaire (art. 300).', muted),
                _Note('BIC : benchmark CRR3 (Europe). Utile pour mesurer l\'écart avec le cadre international.', muted),
                _Note('Ratio couverture < 1 → l\'exigence Pilier 1 ne couvre pas les pertes opérationnelles historiques (Pilier 2).', muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers privés ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.ok, required this.muted});
  final bool ok;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppTheme.success : muted;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(ok ? 'OK' : 'N/D',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• ', style: TextStyle(color: color)),
        Expanded(child: Text(text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
      ]),
    );
  }
}

