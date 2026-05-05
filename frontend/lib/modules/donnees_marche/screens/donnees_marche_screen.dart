// Ce fichier affiche le module de suivi des donnees de marche.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';

/// Ecran de suivi des paramètres de marché utiles aux calculs.
class DonneesMarcheScreen extends StatelessWidget {
  const DonneesMarcheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          PageHeader(
            title: 'Données de mrché',
            subtitle:
                'Suivi des taux, spreads, devises et paramètres externes utilisés dans les analyses.',
          ),
          SizedBox(height: AppTheme.spacing),
          SectionCard(
            title: 'Indicateurs clés',
            child: Wrap(
              spacing: AppTheme.spacing,
              runSpacing: AppTheme.spacing,
              children: [
                _MarketTile(
                  title: 'Courbe taux',
                  value: '3.42%',
                  subtitle: 'Point 10Y actualisé',
                  icon: Icons.show_chart_rounded,
                  color: Color(0xFF5B83FF),
                ),
                _MarketTile(
                  title: 'Spread crédit',
                  value: '+118 bps',
                  subtitle: 'Segment corporate',
                  icon: Icons.analytics_outlined,
                  color: Color(0xFF7B61FF),
                ),
                _MarketTile(
                  title: 'EUR / USD',
                  value: '1.08',
                  subtitle: 'Taux spot',
                  icon: Icons.currency_exchange_rounded,
                  color: Color(0xFF22A06B),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacing),
          SectionCard(
            title: 'Jeux de données suivis',
            child: Column(
              children: [
                _DataRow(
                    label: 'Courbes souveraines',
                    status: 'Disponible',
                    source: 'Provider interne'),
                SizedBox(height: AppTheme.spacing),
                _DataRow(
                    label: 'Spreads bancaires',
                    status: 'Mis à jour',
                    source: 'Feed marché'),
                SizedBox(height: AppTheme.spacing),
                _DataRow(
                    label: 'FX & inflation',
                    status: 'Disponible',
                    source: 'Banque centrale'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile de synthèse utilisée dans l'écran données de marché.
class _MarketTile extends StatelessWidget {
  const _MarketTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title.tr(context),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E2337),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle.tr(context),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de détail utilisée dans les tableaux de marché.
class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.status,
    required this.source,
  });

  final String label;
  final String status;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.dataset_outlined, color: Color(0xFF7B61FF), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.tr(context),
                style: const TextStyle(
                  color: Color(0xFF1E2337),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                source.tr(context),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F8F0),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Text(
            status.tr(context),
            style: const TextStyle(
              color: AppTheme.success,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
