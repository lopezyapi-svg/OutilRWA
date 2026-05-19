// Ecran d'analyse stratégique et recommandations.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran d'analyse et recommandations.
class AnalyseScreen extends StatelessWidget {
  const AnalyseScreen({
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
            title: 'Analyse',
            subtitle:
                'Recommendations à partir des expositions et des risques.',
          ),
          SizedBox(height: AppTheme.spacing),
          _AdviceCard(
            title: 'Synthèse des observations',
            content:
                'Le module d’analyse agrège les données des expositions, du risque de marché et du risque opérationnel. '
                'Il aide à identifier les leviers d’amélioration et les zones de concentration.',
          ),
          SizedBox(height: AppTheme.spacing),
          _AdviceCard(
            title: 'Actions recommandées',
            content:
                'Priorisez les dispositifs de couverture et de mitigation. '
                'Renforcez la surveillance des expositions sensibles et formalisez les plans de correction.',
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
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
