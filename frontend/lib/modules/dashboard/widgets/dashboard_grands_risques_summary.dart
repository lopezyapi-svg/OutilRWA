import 'package:flutter/material.dart';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';
import 'dashboard_all_grands_risques_dialog.dart';

import 'dashboard_all_categories_risques_dialog.dart';

class DashboardGrandsRisquesSummary extends StatelessWidget {
  const DashboardGrandsRisquesSummary({
    super.key,
    required this.exposures,
    required this.currency,
    this.allCategories = const [],
  });

  final List<TopExposure> exposures;
  final String currency;
  final List<DistributionEntry> allCategories;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;
    final scale = 1000000000 / amountUnit.divisor;

    // Calculs de synthèse
    final totalRisques = exposures.length;
    final totalNet = exposures.fold<double>(0.0, (sum, e) => sum + e.netExposure);
    // Classification par statut
    final alertes = exposures.where((e) => e.status == 'Dépassement').length;
    final conformes = exposures.where((e) => e.status == 'Dans la norme').length;

    // Top secteurs (jusqu'à 5)
    final mapSecteurs = <String, double>{};
    for (final cat in allCategories) {
      mapSecteurs[cat.label] = 0.0;
    }
    for (final e in exposures) {
      mapSecteurs[e.sector] = (mapSecteurs[e.sector] ?? 0.0) + e.netExposure;
    }
    final sortedSecteurs = mapSecteurs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSecteurs = sortedSecteurs.take(5).toList();

    return DashPanel(
      title: 'SYNTHÈSE DES GRANDS RISQUES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Gros indicateurs
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildMetric(
                  context,
                  label: 'Total grands risques',
                  value: totalRisques.toString(),
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildMetric(
                  context,
                  label: 'Risque Net Total',
                  value: AppFormatters.formatAmountValue(totalNet),
                  suffix: AppFormatters.formatAmountSuffix(totalNet),
                  color: const Color(0xFF0F172A),
                  centerValue: true,
                ),
              ),
            ],
          ),
          Divider(height: 16, thickness: 1, color: Colors.indigo.withOpacity(0.2)),
          const Text(
            'CLASSIFICATION PRUDENTIELLE',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.indigo),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildStatusPill('Dans la norme', '< 25%', conformes, const Color(0xFFE3FCEF), const Color(0xFF006644))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatusPill('Dépassement', '> 25%', alertes, const Color(0xFFFFEBE6), const Color(0xFFDE350B))),
            ],
          ),
          Divider(height: 16, thickness: 1, color: Colors.indigo.withOpacity(0.2)),
          if (topSecteurs.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'CATÉGORIES LES PLUS CONCENTRÉES ( TOP 5 )',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.indigo),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => DashboardAllCategoriesRisquesDialog(
                          categories: sortedSecteurs,
                          totalNet: totalNet,
                          scale: scale,
                          amountUnit: amountUnit,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    hoverColor: c.navy.withOpacity(0.08),
                    splashColor: c.navy.withOpacity(0.12),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Voir tous', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.navy)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 10, color: c.navy),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...topSecteurs.asMap().entries.map((entry) {
              final index = entry.key;
              final s = entry.value;
              final valScaled = (s.value / 1000000000) * scale;
              final pctDouble = (totalNet > 0) ? (s.value / totalNet * 100) : 0.0;
              final pct = pctDouble.toStringAsFixed(1);
              
              String cleanName = s.key.replaceFirst(RegExp(r'^\([a-zA-Z]\)\s*'), '').trim();
              if (cleanName.isNotEmpty) {
                cleanName = cleanName[0].toUpperCase() + cleanName.substring(1);
              }

              final isLast = index == topSecteurs.length - 1;

              return Container(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(bottom: BorderSide(color: c.navy.withOpacity(0.1), width: 0.5)),
                ),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.navy.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.navy),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Category Name
                    Expanded(
                      child: Text(
                        cleanName,
                        style: TextStyle(fontSize: 10, color: c.navy, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Absolute Value
                    Text(
                      '${AppFormatters.compactNumber(valScaled)} ${amountUnit.label}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.ink, fontFeatures: Dash.tabular),
                    ),
                    const SizedBox(width: 6),
                    // Percentage Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$pct%',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c.accent, fontFeatures: Dash.tabular),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, {required String label, required String value, required Color color, bool centerValue = false, String? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // Fond gris très clair / blanc cassé
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFF1E3A8A), width: 0.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06), // Ombre pro et douce
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E293B), // Gris très foncé / Navy profond, fini le côté "délavé"
                fontWeight: FontWeight.w700, // Plus de graisse pour plus de netteté
                letterSpacing: 0.1, // Réduire l'espacement qui peut donner cet effet flou
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Le "divider un peu beau" et "une belle couleur"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (suffix != null)
                    TextSpan(
                      text: suffix,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
              textAlign: centerValue ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String title, String subtitle, int count, Color bgColor, Color textColor) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
          child: Text(
            title,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }
}

