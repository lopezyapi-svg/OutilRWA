// Ce fichier affiche le module des echeanciers et flux.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Ecran de lecture des échéanciers et flux attendus.
class EcheanciersFluxScreen extends StatelessWidget {
  const EcheanciersFluxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          PageHeader(
            title: 'Échéanciers & Flux',
            subtitle:
                'Visualisation des maturités, remboursements, flux futurs et jalons du portefeuille.',
          ),
          SizedBox(height: AppTheme.spacing),
          SectionCard(
            title: 'Vue maturité',
            child: Wrap(
              spacing: AppTheme.spacing,
              runSpacing: AppTheme.spacing,
              children: [
                _MaturityTile(
                    bucket: '0 - 3 mois',
                    value: '18.4 M€',
                    color: Color(0xFF5B83FF)),
                _MaturityTile(
                    bucket: '3 - 12 mois',
                    value: '26.1 M€',
                    color: Color(0xFF7B61FF)),
                _MaturityTile(
                    bucket: '1 - 5 ans',
                    value: '42.7 M€',
                    color: Color(0xFF22A06B)),
                _MaturityTile(
                    bucket: '5 ans +',
                    value: '15.9 M€',
                    color: Color(0xFFF59E0B)),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacing),
          SectionCard(
            title: 'Prochains flux',
            child: Column(
              children: [
                _FlowRow(
                    date: '05/05/2026',
                    label: 'Coupon obligataire',
                    amount: '+ 420 000 €'),
                SizedBox(height: AppTheme.spacing),
                _FlowRow(
                    date: '17/05/2026',
                    label: 'Amortissement prêt',
                    amount: '- 1 200 000 €'),
                SizedBox(height: AppTheme.spacing),
                _FlowRow(
                    date: '30/05/2026',
                    label: 'Flux CRM attendu',
                    amount: '+ 280 000 €'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile de synthèse utilisée dans l'écran échéanciers.
class _MaturityTile extends StatelessWidget {
  const _MaturityTile({
    required this.bucket,
    required this.value,
    required this.color,
  });

  final String bucket;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Icon(Icons.timeline_rounded, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            bucket.tr(context),
            style: const TextStyle(
              color: Color(0xFF1E2337),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de flux affichée dans l'écran échéanciers.
class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.date,
    required this.label,
    required this.amount,
  });

  final String date;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4FB),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Text(
            date,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing),
        Expanded(
          child: Text(
            label.tr(context),
            style: const TextStyle(
              color: Color(0xFF1E2337),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Color(0xFF5B83FF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
