// Ecran du module stress test.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran de simulation des scenarios adverses.
class StressTestScreen extends StatelessWidget {
  const StressTestScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Stress test',
            subtitle:
                'Simulation de chocs et scénarios adverses sur le portefeuille et le capital.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Bibliothèque de scénarios',
            content:
                'Centralisez les stress de taux, de défaut, de concentration et de liquidité pour mesurer leur impact sur les RWA, le capital et la solvabilité.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Lecture des impacts',
            content:
                'Comparez le scénario central aux hypothèses adverses, identifiez les seuils de rupture et préparez les actions de mitigation à suivre.',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: const Color(0xFFE6EAF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
