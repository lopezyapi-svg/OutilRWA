// Ecran du risque de marché.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran de suivi des risques de marché.
class RisqueMarcheScreen extends StatelessWidget {
  const RisqueMarcheScreen({
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
            title: 'Risque de marché',
            subtitle:
                'Evaluation des tendances de marché et impacts sur le portefeuille.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Synthèse du risque de marché',
            content:
                'Analyse des variations de taux, des changes et des prix des actifs. '
                'Identifiez les sensibilités principales et surveillez les expositions critiques.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Recommandations',
            content: 'Vérifiez la concentration sectorielle et géographique. '
                'Privilégiez les couvertures adaptées aux expositions sensibles aux taux et changes.',
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
