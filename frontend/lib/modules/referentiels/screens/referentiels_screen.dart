// Ce fichier affiche le module des referentiels prudentiels.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../models/referentiels_models.dart';
import '../widgets/reference_table_card.dart';

/// Ecran de consultation des tables RW, CCF et notations.
class ReferentielsScreen extends StatefulWidget {
  const ReferentielsScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<ReferentielsScreen> createState() => _ReferentielsScreenState();
}

/// Etat interne de l'écran référentiels et de ses onglets.
class _ReferentielsScreenState extends State<ReferentielsScreen> {
  late Future<ReferentielsModuleData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchReferentiels();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReferentielsModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              context.tr('Erreur: {{error}}', args: {'error': snapshot.error}),
            ),
          );
        }

        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Référentiels',
                subtitle:
                    'Tables de pondération, Credit Conversion Factors et notations de calcul.',
              ),
              const SizedBox(height: AppTheme.spacing),
              ReferenceTableCard(
                title: 'Tables des Ponderations',
                columns: const ['Segment', 'Notation', 'RW', 'Approche'],
                rows: data.riskWeights
                    .map(
                      (item) => [
                        item.segment,
                        item.rating,
                        AppFormatters.percent(item.riskWeight),
                        item.approach,
                      ],
                    )
                    .toList(),
              ),
              const SizedBox(height: AppTheme.spacing),
              ReferenceTableCard(
                title: 'Tables des Credit Conversion Factors',
                columns: const ['Nature d\'Engagement', 'CCF'],
                rows: data.ccfTable
                    .map(
                      (item) => [
                        item.engagementType,
                        AppFormatters.percent(item.ccf),
                      ],
                    )
                    .toList(),
              ),
              const SizedBox(height: AppTheme.spacing),
              ReferenceTableCard(
                title: 'Echelle des Notations',
                columns: const ['Notation', 'Description'],
                rows: data.ratings
                    .map((item) => [item.label, item.description])
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
