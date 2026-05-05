// Ce fichier prepare l'ecran des stress tests prudentiels.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Ecran dédié aux stress tests et sensibilités du portefeuille.
class StressTestsScreen extends StatelessWidget {
  const StressTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          PageHeader(
            title: 'Stress tests',
            subtitle:
                'Sensibilites portefeuille sur notation, CCF, garanties et capital.',
          ),
          SizedBox(height: AppTheme.spacing),
          SectionCard(
            title: 'Axes de stress',
            child: Wrap(
              spacing: AppTheme.spacing,
              runSpacing: AppTheme.spacing,
              children: [
                _StressTile(
                  icon: Icons.trending_down_rounded,
                  title: 'Degradation notation',
                  subtitle: 'Tester une migration adverse des contreparties.',
                ),
                _StressTile(
                  icon: Icons.percent_rounded,
                  title: 'Hausse CCF',
                  subtitle: 'Mesurer l effet des engagements hors bilan.',
                ),
                _StressTile(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Choc capital',
                  subtitle: 'Evaluer la sensibilite du ratio de solvabilite.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile de stress test utilisée dans l'écran dédié.
class _StressTile extends StatelessWidget {
  const _StressTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFF),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.danger),
            const SizedBox(height: 10),
            Text(
              title.tr(context),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle.tr(context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
