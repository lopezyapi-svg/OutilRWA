import 'package:flutter/material.dart';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';
import 'dashboard_all_grands_risques_dialog.dart';

/// Données mock de démonstration pour le Top 10 des grands risques.
const List<TopExposure> kMockTop10 = [
  TopExposure(counterparty: 'Groupe Sonatel', sector: 'Télécommunications', country: 'Sénégal', rating: 'A', exposureAmount: 185000000000, netExposure: 142000000000, rwaAmount: 71000000000, fpRatio: 18.4, status: 'Conforme'),
  TopExposure(counterparty: 'Société Générale CI', sector: 'Institutions financières', country: 'Côte d\'Ivoire', rating: 'A-', exposureAmount: 163000000000, netExposure: 128000000000, rwaAmount: 64000000000, fpRatio: 16.6, status: 'Conforme'),
  TopExposure(counterparty: 'État du Sénégal', sector: 'Souverains', country: 'Sénégal', rating: 'B+', exposureAmount: 148000000000, netExposure: 148000000000, rwaAmount: 0, fpRatio: 0.0, status: 'Conforme'),
  TopExposure(counterparty: 'BOAD', sector: 'BMD', country: 'UEMOA', rating: 'BBB', exposureAmount: 132000000000, netExposure: 110000000000, rwaAmount: 55000000000, fpRatio: 14.3, status: 'Conforme'),
  TopExposure(counterparty: 'Cimencam SA', sector: 'Entreprises', country: 'Cameroun', rating: 'BB+', exposureAmount: 118000000000, netExposure: 105000000000, rwaAmount: 105000000000, fpRatio: 27.3, status: 'Alerte'),
  TopExposure(counterparty: 'Orange CI', sector: 'Télécommunications', country: 'Côte d\'Ivoire', rating: 'A-', exposureAmount: 102000000000, netExposure: 85000000000, rwaAmount: 42500000000, fpRatio: 11.0, status: 'Conforme'),
  TopExposure(counterparty: 'Port Autonome Abidjan', sector: 'Organismes publics', country: 'Côte d\'Ivoire', rating: 'BBB-', exposureAmount: 95000000000, netExposure: 80000000000, rwaAmount: 40000000000, fpRatio: 10.4, status: 'Conforme'),
  TopExposure(counterparty: 'Groupe Bolloré Africa', sector: 'Entreprises', country: 'Multi-pays', rating: 'BB', exposureAmount: 88000000000, netExposure: 78000000000, rwaAmount: 78000000000, fpRatio: 20.3, status: 'Sous cible'),
  TopExposure(counterparty: 'Ecobank TG', sector: 'Institutions financières', country: 'Togo', rating: 'B+', exposureAmount: 76000000000, netExposure: 62000000000, rwaAmount: 46500000000, fpRatio: 12.1, status: 'Conforme'),
  TopExposure(counterparty: 'Total Energies SN', sector: 'Entreprises', country: 'Sénégal', rating: 'A', exposureAmount: 71000000000, netExposure: 58000000000, rwaAmount: 29000000000, fpRatio: 7.5, status: 'Conforme'),
];

class DashboardTop10RisquesTable extends StatelessWidget {
  const DashboardTop10RisquesTable({
    super.key,
    required this.exposures,
    required this.currency,
    this.allExposures = const [],
  });

  final List<TopExposure> exposures;
  final String currency;
  final List<TopExposure> allExposures;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;
    final scale = 1000000000 / amountUnit.divisor;

    // On utilise les données du backend sans mock fallback
    final data = List<TopExposure>.from(exposures)
      ..sort((a, b) => b.netExposure.compareTo(a.netExposure));

    // Couleurs du tableau
    const headerBg = Color(0xFF172B4D);      // Navy profond
    const headerText = Color(0xFFFFFFFF);     // Blanc
    const rowEvenBg = Color(0xFFFFFFFF);      // Blanc pur
    const rowOddBg = Color(0xFFF7F8FB);       // Gris très léger (zébré)
    const borderColor = Color(0xFFE3E7EE);    // Bordure douce

    final totalGrossScaled = data.fold<double>(0.0, (sum, e) => sum + e.exposureAmount) / 1000000000 * scale;
    final totalNetScaled = data.fold<double>(0.0, (sum, e) => sum + e.netExposure) / 1000000000 * scale;
    final totalRatioFP = data.isEmpty ? 0.0 : data.fold<double>(0.0, (sum, e) => sum + e.fpRatio) / data.length;

    Widget vDiv() => Container(width: 0.3, height: 34, color: borderColor);
    Widget vDivHeader() => Container(width: 0.3, height: 30, color: Colors.white24);
    Widget vDivTotal() => Container(width: 0.3, height: 38, color: borderColor);

    return DashPanel(
      title: 'TOP 10 DES GRANDS RISQUES',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allExposures.isNotEmpty) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => DashboardAllGrandsRisquesDialog(
                      exposures: allExposures,
                      currency: currency,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                hoverColor: c.navy.withValues(alpha: 0.08),
                splashColor: c.navy.withValues(alpha: 0.12),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir tous',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.navy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 12, color: c.navy),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  // ── En-tête ──
                  Container(
                    color: headerBg,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    child: Row(
                      children: [
                        const _HeaderCell(label: '#', width: 32, align: TextAlign.center),
                        vDivHeader(),
                        const _HeaderCell(label: 'Contrepartie / Groupe lié', flex: 3),
                        vDivHeader(),
                        const _HeaderCell(label: 'Pays de risque', flex: 2),
                        vDivHeader(),
                        const _HeaderCell(label: 'Risque Brut', flex: 2, align: TextAlign.right),
                        vDivHeader(),
                        const _HeaderCell(label: 'Risque Net', flex: 2, align: TextAlign.right),
                        vDivHeader(),
                        const _HeaderCell(label: 'Ratio RN/FP (%)', flex: 2, align: TextAlign.right),
                        vDivHeader(),
                        const _HeaderCell(label: 'Statut', flex: 2, align: TextAlign.center),
                      ],
                    ),
                  ),
                  // ── Lignes de données ──
                  Column(
                    children: List.generate(
                      data.length < 10 ? 10 : data.length,
                      (index) {
                        final isEven = index.isEven;
                        
                        if (index >= data.length) {
                          return Container(
                            color: isEven ? rowEvenBg : rowOddBg,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            child: Container(
                              decoration: const BoxDecoration(),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFC1C7D0),
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                  vDiv(),
                                  const Expanded(flex: 3, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                ],
                              ),
                            ),
                          );
                        }

                        final e = data[index];
                        final expScaled = e.exposureAmount;
                        final netScaled = e.netExposure;

                        return Container(
                          color: isEven ? rowEvenBg : rowOddBg,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          child: Container(
                            decoration: const BoxDecoration(),
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            child: Row(
                              children: [
                                // Rang
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: c.navy,
                                      fontFeatures: Dash.tabular,
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Contrepartie
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      e.counterparty,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: c.navy,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Pays de risque
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      e.country,
                                      style: TextStyle(fontSize: 11, color: c.ink),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Risque Brut
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${AppFormatters.formatAmountValue(expScaled)} ${AppFormatters.formatAmountSuffix(expScaled)}'.trim(),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: c.ink,
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Risque Net
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${AppFormatters.formatAmountValue(netScaled)} ${AppFormatters.formatAmountSuffix(netScaled)}'.trim(),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: c.ink,
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Ratio RN/FP (%)
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${e.fpRatio.toStringAsFixed(1)} %',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: e.fpRatio > 25 ? c.sousMinimum : e.fpRatio > 15 ? c.sousCible : c.ink,
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Statut
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: _StatutBadge(status: e.status, colors: c),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // ── Ligne des Totaux ──
                  if (data.isNotEmpty)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F4F8),
                        border: Border(top: BorderSide(color: borderColor, width: 1.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      child: Row(
                        children: [
                          const SizedBox(width: 32),
                          vDivTotal(),
                          const Expanded(
                            flex: 3,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: headerBg,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          const Expanded(flex: 2, child: SizedBox.shrink()),
                          vDivTotal(),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${AppFormatters.compactNumber(totalGrossScaled)} ${amountUnit.label}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: headerBg,
                                  fontFeatures: Dash.tabular,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${AppFormatters.compactNumber(totalNetScaled)} ${amountUnit.label}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: headerBg,
                                  fontFeatures: Dash.tabular,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${totalRatioFP.toStringAsFixed(1)} %',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: totalRatioFP > 25 ? c.sousMinimum : headerBg,
                                  fontFeatures: Dash.tabular,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          const Expanded(flex: 2, child: SizedBox.shrink()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cellule d'en-tête du tableau.
class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    this.flex,
    this.width,
    this.align = TextAlign.left,
  });

  final String label;
  final int? flex;
  final double? width;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 10.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}

/// Badge de statut avec pastille colorée.
class _StatutBadge extends StatelessWidget {
  const _StatutBadge({required this.status, required this.colors});

  final String status;
  final DashColors colors;

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color textColor;
    Color bgColor;

    switch (status) {
      case 'Alerte':
        dotColor = colors.sousMinimum;
        textColor = colors.sousMinimum;
        bgColor = const Color(0xFFFEF2F2);
        break;
      case 'Sous cible':
        dotColor = colors.sousCible;
        textColor = colors.sousCible;
        bgColor = const Color(0xFFFFFBEB);
        break;
      default: // Conforme
        dotColor = colors.conforme;
        textColor = colors.conforme;
        bgColor = const Color(0xFFF0FDF4);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
