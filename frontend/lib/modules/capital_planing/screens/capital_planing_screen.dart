// Ecran du module capital planing.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran de projection du capital.
class CapitalPlaningScreen extends StatelessWidget {
  const CapitalPlaningScreen({
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
            title: 'Capital planing',
            subtitle:
                'Projection du capital, des besoins prudentiels et des marges de manoeuvre.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Trajectoire prévisionnelle',
            content:
                'Projetez l’évolution du capital disponible, des besoins réglementaires et des coussins afin de visualiser les marges de manoeuvre sur plusieurs horizons.',
          ),
          SizedBox(height: AppTheme.spacing),
          _InfoCard(
            title: 'Arbitrages de gestion',
            content:
                'Préparez les décisions de distribution, de croissance des encours et de renforcement du capital en fonction des contraintes prudentielles attendues.',
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
