// Composants visuels du module FODEP, alignés sur le système institutionnel
// du dashboard (dashboard_design.dart) : panneaux plats, filet fin, un seul
// accent navy, couleur réservée au statut réglementaire. Aucune icône
// décorative, aucun aplat de couleur par carte.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/fodep_models.dart';

/// Tuile de ratio prudentiel : même habillage que DashboardRatiosRow,
/// adapté aux ratios FODEP dont le seuil (pilier 1 + coussin) est déjà
/// fusionné côté backend.
class FodepRatioTile extends StatelessWidget {
  const FodepRatioTile({super.key, required this.label, required this.ratio});

  final String label;
  final RatioDetail ratio;

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

  static String _fr(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final status = _status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: DashText.eyebrow(c, color: c.navy)),
          const SizedBox(height: 10),
          Text('${_fr(ratio.value)} %', style: DashText.hero(c, size: 20)),
          const SizedBox(height: 6),
          Text(
            'Seuil réglementaire : ${_fr(ratio.threshold)} %'.tr(context),
            style: DashText.caption(c),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 8),
          DashStatusTag(status: status, dense: true),
        ],
      ),
    );
  }
}

/// Tuile de valeur simple (fonds propres, APR) : même habillage, sans
/// statut.
class FodepValueTile extends StatelessWidget {
  const FodepValueTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: DashText.eyebrow(c, color: c.navy)),
          const SizedBox(height: 10),
          Text(value, style: DashText.hero(c, size: 18)),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: DashText.caption(c)),
          ],
        ],
      ),
    );
  }
}

/// Bandeau d'information/erreur/succès, plat, cohérent avec la palette de
/// statut du dashboard (aucune couleur inventée hors de DashColors).
class FodepNotice extends StatelessWidget {
  const FodepNotice({super.key, required this.status, required this.texte});

  final DashStatus status;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final couleur = c.status(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: couleur.withValues(alpha: 0.4), width: Dash.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte, style: DashText.value(c, color: c.ink, weight: FontWeight.w500).copyWith(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Onglets sobres (texte seul, soulignement navy) pour naviguer entre les
/// groupes de postes DISPRU, sans icône ni couleur de statut.
class FodepTabs extends StatelessWidget {
  const FodepTabs({
    super.key,
    required this.onglets,
    required this.selection,
    required this.onSelect,
  });

  final List<MapEntry<String, String>> onglets; // (clé, libellé)
  final String selection;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in onglets)
              _Onglet(
                label: entry.value,
                selected: selection == entry.key,
                onTap: () => onSelect(entry.key),
                c: c,
              ),
          ],
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({required this.label, required this.selected, required this.onTap, required this.c});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final DashColors c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? c.navy : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.navy : c.muted,
          ),
        ),
      ),
    );
  }
}
