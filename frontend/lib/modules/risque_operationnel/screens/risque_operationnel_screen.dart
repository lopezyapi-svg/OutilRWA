// Ecran du risque opérationnel.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran de suivi des risques opérationnels.
class RisqueOperationnelScreen extends StatelessWidget {
  const RisqueOperationnelScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Risque opérationnel',
            subtitle: 'Suivi des incidents et des controles internes liés aux processus.',
          ),
          const SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Principaux indicateurs opérationnels',
            content:
                'Métriques sur les pertes, les incidents et la qualité des processus. ' 
                'L’objectif est de limiter l’impact opérationnel sur les résultats.',
          ),
          const SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Conseils pratiques',
            content:
                'Renforcez les controles clés, formalisez les procédures et surveillez ' 
                'les événements opérationnels récurrents pour réduire les risques.',
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
            color: Colors.black.withOpacity(0.03),
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
