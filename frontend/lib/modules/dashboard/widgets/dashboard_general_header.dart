import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import 'dashboard_design.dart';

/// Masthead du dashboard prudentiel - barre claire raffinée.
///
/// Surface blanche structurée : titre et sur-titre (cadre réglementaire) à
/// gauche, action unique « Actualiser » à droite. La sélection de date et
/// l'export ont été retirés : la date n'influençait aucun calcul et l'export
/// est couvert par le module Capital Planning.
class DashboardGeneralHeader extends StatelessWidget {
  const DashboardGeneralHeader({
    super.key,
    this.onRefresh,
  });

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border, width: Dash.hairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tableau de bord'.tr(context),
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  "Vue d'ensemble des indicateurs prudentiels".tr(context),
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _RefreshButton(onTap: onRefresh, colors: c),
        ],
      ),
    );
  }
}

/// Bouton d'actualisation : seule action du masthead, rendue en aplat navy
/// (l'accent institutionnel) pour la désigner clairement comme action primaire.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.onTap,
    required this.colors,
  });

  final VoidCallback? onTap;
  final DashColors colors;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Actualiser'.tr(context),
      child: Material(
        color: colors.navy,
        borderRadius: BorderRadius.circular(Dash.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.14),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          splashColor: Colors.white.withValues(alpha: 0.20),
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
