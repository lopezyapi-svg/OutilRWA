// Ecran du module ICAP.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran d'evaluation interne du capital.
class IcapScreen extends StatelessWidget {
  const IcapScreen({
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
            title: 'ICAP',
            subtitle:
                'Evaluation interne de l’adéquation du capital et des besoins de solvabilité.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Périmètre d’évaluation',
            content:
                'Regroupez les hypothèses de capital interne, les contraintes réglementaires et les risques matériels pour établir une lecture cohérente de l’adéquation du capital.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Décisions de pilotage',
            content:
                'Identifiez les coussins disponibles, les limites de concentration et les besoins d’ajustement pour sécuriser la trajectoire prudentielle.',
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
