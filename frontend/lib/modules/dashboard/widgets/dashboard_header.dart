// Ce fichier affiche l'en-tete compact du dashboard.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import 'dashboard_theme.dart';

/// En-tête du dashboard avec date de référence et valorisation.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.selectedDate,
    required this.valuationDate,
    required this.onPickDate,
  });

  final DateTime selectedDate;
  final DateTime valuationDate;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dashboardPanelColor(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: dashboardPanelBorder(isDark)),
        boxShadow: dashboardPanelShadow(isDark),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 840;

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderText(isDark: isDark),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CalendarPill(
                          date: selectedDate,
                          onTap: onPickDate,
                        ),
                        _InfoPill(
                          label: context.tr('Dernière évaluation'),
                          value: dashboardLongDate(valuationDate),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _HeaderText(isDark: isDark)),
                    const SizedBox(width: 8),
                    _CalendarPill(
                      date: selectedDate,
                      onTap: onPickDate,
                    ),
                    const SizedBox(width: 8),
                    _InfoPill(
                      label: context.tr('Dernière évaluation'),
                      value: dashboardLongDate(valuationDate),
                    ),
                  ],
                );
        },
      ),
    );
  }
}

/// Bloc texte interne utilisé dans l'en-tête du dashboard.
class _HeaderText extends StatelessWidget {
  const _HeaderText({
    required this.isDark,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Tableau de bord'),
          style: TextStyle(
            color: dashboardTitleColor(isDark),
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          context.tr(
            'Vue synthèse du portefeuille, des RWA et du capital prudentiel.',
          ),
          style: TextStyle(
            color: dashboardSubtitleColor(isDark),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// Pastille de date interactive affichée dans l'en-tête.
class _CalendarPill extends StatelessWidget {
  const _CalendarPill({
    required this.date,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: context.tr('Choisir une date de reférence'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: dashboardPanelBorder(isDark)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 14,
                color: Color(0xFF234A84),
              ),
              const SizedBox(width: 8),
              Text(
                dashboardLongDate(date),
                style: TextStyle(
                  color: dashboardTitleColor(isDark),
                  fontSize: 8.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille d'information secondaire affichée dans l'en-tête.
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: dashboardPanelBorder(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.tr(context),
                style: TextStyle(
                  color: dashboardSubtitleColor(isDark),
                  fontSize: 7.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: dashboardTitleColor(isDark),
                  fontSize: 8.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
