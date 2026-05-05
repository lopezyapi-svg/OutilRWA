// Ce fichier prepare l'ecran de simulation des scenarios RWA.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Ecran dédié aux simulations de scénarios prudentiels.
class SimulationScreen extends StatelessWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          PageHeader(
            title: 'Simulation',
            subtitle: 'Construction de scenarios RWA, CRM et capital minimum.',
          ),
          SizedBox(height: AppTheme.spacing),
          SectionCard(
            title: 'Scenarios disponibles',
            child: Wrap(
              spacing: AppTheme.spacing,
              runSpacing: AppTheme.spacing,
              children: [
                _ScenarioTile(
                  icon: Icons.auto_graph_rounded,
                  title: 'Variation RW',
                  subtitle: 'Simuler une hausse ou baisse des ponderations.',
                ),
                _ScenarioTile(
                  icon: Icons.shield_outlined,
                  title: 'Effet CRM',
                  subtitle: 'Tester une couverture garantie supplementaire.',
                ),
                _ScenarioTile(
                  icon: Icons.account_balance_outlined,
                  title: 'Capital',
                  subtitle: 'Mesurer l impact sur le capital minimum.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile de scénario utilisée dans l'écran simulation.
class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({
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
            Icon(icon, color: AppTheme.accent),
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
