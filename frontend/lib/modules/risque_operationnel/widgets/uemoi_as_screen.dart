import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart' show AppFormatters;
import '../../../shared/widgets/section_card.dart';
import '../models/ro_models.dart';
import 'ro_hero_stat_card.dart';
import 'uemoi_form_style.dart';

class UemoiAsScreen extends StatefulWidget {
  const UemoiAsScreen({super.key, required this.api});
  final RwaApiService api;

  @override
  State<UemoiAsScreen> createState() => _UemoiAsScreenState();
}

class _UemoiAsScreenState extends State<UemoiAsScreen> {
  AsCalculResult? _result;
  List<BetaLigneView> _betas = [];
  bool _loading = true;
  String? _error;

  int _anneeSelect = DateTime.now().year - 1;
  List<int> _yearChips = [
    DateTime.now().year - 2,
    DateTime.now().year - 1,
    DateTime.now().year,
  ];
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

      setState(() {
        _result = r;
        _betas = b;
        final years = {..._yearChips, ...r.detailParAnnee.map((d) => d.annee)};
        _yearChips = years.toList()..sort();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectAnnee(int y) async {
    setState(() => _anneeSelect = y);
    final lignes = await widget.api.fetchPnbLignes(y);
    final lignesMap = {for (final l in lignes) l.ligneMetier: l.produitBrutLigne};
    setState(() {
      for (final e in _pnbCtrls.entries) {
        final val = lignesMap[e.key];
        e.value.text = val != null ? val.toStringAsFixed(0) : '';
      }
    });
  }

  Future<void> _addCustomYear() async {
    final ctrl = TextEditingController();
    final year = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter une année'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'ex. 2022'),
          onSubmitted: (v) {
            final y = int.tryParse(v.trim());
            if (y != null) Navigator.pop(dialogContext, y);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final y = int.tryParse(ctrl.text.trim());
              if (y != null) Navigator.pop(dialogContext, y);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (year == null || year < 2000 || year > 2100) return;
    if (!_yearChips.contains(year)) {
      setState(() => _yearChips = [..._yearChips, year]..sort());
    }
    await _selectAnnee(year);
  }

  // Années réellement comptées dans le calcul K_AS : celles ayant un
  // exercice PNB annuel saisi dans Indicateur de Base (AIB) - voir
  // `calcul_as()` côté backend, qui dérive `detail_par_annee` de
  // `list_pnb_annuel()` et non des chips choisis dans cet écran.
  Set<int> get _anneesRetenuesCalcul =>
      (_result?.detailParAnnee ?? const <AsAnneeDetail>[]).map((d) => d.annee).toSet();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkMuted : AppTheme.muted;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI résultats
          if (!r.donneesInsuffisantes) ...[
            _buildStatGrid(r),
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
          UemoiFormCard(
            title: 'PNB par ligne de métier',
            subtitle: 'Approche Standard - saisie annuelle par ligne de métier BCEAO',
            color: AppTheme.accent,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ..._yearChips.map((y) {
                final retenue = _anneesRetenuesCalcul.contains(y);
                return Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Tooltip(
                    message: retenue
                        ? 'Année $y incluse dans le calcul K_AS'
                        : "Année $y non incluse dans le calcul : ajoutez d'abord un exercice PNB $y"
                            " dans l'onglet Indicateur de Base (AIB)",
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$y', style: const TextStyle(fontSize: 11)),
                          if (retenue) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.check_circle, size: 11, color: AppTheme.success),
                          ],
                        ],
                      ),
                      selected: _anneeSelect == y,
                      onSelected: (_) => _selectAnnee(y),
                    ),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Tooltip(
                  message: 'Ajouter une autre année',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _addCustomYear,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.muted.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.add, size: 14, color: AppTheme.muted),
                    ),
                  ),
                ),
              ),
            ]),
            children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 13, color: AppTheme.muted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Seules les années marquées ✓ ci-dessus (celles ayant un exercice PNB '
                        'annuel saisi dans Indicateur de Base - AIB) sont comptées dans le K_AS.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                      ),
                    ),
                  ]),
                ),
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
                    Expanded(flex: 2, child: SizedBox(
                      height: 32,
                      child: TextFormField(
                        controller: _pnbCtrls[b.ligneMetier],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          hintText: '0',
                          suffixText: ' FCFA',
                          suffixStyle: const TextStyle(fontSize: 9.5, color: AppTheme.muted),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(color: AppTheme.accent, width: 1.2)),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                        ),
                      ),
                    )),
                  ]),
                )),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 15),
                    label: Text(_saving ? 'Enregistrement…' : 'Enregistrer $_anneeSelect'),
                    onPressed: _saving ? null : _saveAllLignes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sidebar,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(AsCalculResult r) {
    final stats = [
      RoHeroStatCard(
        label: 'K_AS (Exigence)',
        value: AppFormatters.currency(r.kAs),
        subtitle: 'Capital risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'APR Opérationnel',
        value: AppFormatters.currency(r.aprAs),
        subtitle: 'RWA risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'Capital minimal (9 %)',
        value: AppFormatters.currency(r.capitalMinAs),
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

