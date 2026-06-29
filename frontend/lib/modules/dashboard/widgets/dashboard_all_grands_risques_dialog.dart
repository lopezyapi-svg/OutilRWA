import 'package:flutter/material.dart';
import 'dart:ui';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardAllGrandsRisquesDialog extends StatelessWidget {
  const DashboardAllGrandsRisquesDialog({
    super.key,
    required this.exposures,
    required this.currency,
  });

  final List<TopExposure> exposures;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;
    final scale = 1000000000 / amountUnit.divisor;

    final data = List<TopExposure>.from(exposures)
      ..sort((a, b) => b.netExposure.compareTo(a.netExposure));

    const headerBg = Color(0xFF172B4D);
    const headerText = Color(0xFFFFFFFF);
    const rowEvenBg = Color(0xFFFFFFFF);
    const rowOddBg = Color(0xFFF7F8FB);
    const borderColor = Color(0xFFE3E7EE);

    Widget vDiv() => Container(width: 0.3, height: 36, color: borderColor);
    Widget vDivHeader() => Container(width: 0.3, height: 32, color: Colors.white24);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: Colors.white,
      child: Container(
        width: 900,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOUS LES GRANDS RISQUES',
                  style: DashText.eyebrow(c).copyWith(fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: c.ink,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête
                  Container(
                    decoration: const BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(2.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text('#', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Contrepartie / Groupe lié', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Pays de risque', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Catégorie d\'exposition', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Risque Brut', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Ratio RN/FP (%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Statut', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Liste scrollable
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final isEven = index.isEven;
                        final e = data[index];
                        final expScaled = (e.exposureAmount / 1000000000) * scale;
                        final netScaled = (e.netExposure / 1000000000) * scale;

                        return Container(
                          color: isEven ? rowEvenBg : rowOddBg,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.navy, fontFeatures: Dash.tabular),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(e.counterparty, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.navy), overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(e.country, style: TextStyle(fontSize: 11, color: c.ink), overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('${AppFormatters.compactNumber(expScaled)} ${amountUnit.label}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.ink, fontFeatures: Dash.tabular)),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('${AppFormatters.compactNumber(netScaled)} ${amountUnit.label}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.ink, fontFeatures: Dash.tabular)),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${e.fpRatio.toStringAsFixed(1)} %',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.accent, fontFeatures: Dash.tabular),
                                  ),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: e.status == 'Conforme' ? const Color(0xFFE3FCEF) : (e.status == 'Alerte' ? const Color(0xFFFFEBE6) : const Color(0xFFFFF0B3)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      e.status,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: e.status == 'Conforme' ? const Color(0xFF006644) : (e.status == 'Alerte' ? const Color(0xFFDE350B) : const Color(0xFFFF8B00)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
