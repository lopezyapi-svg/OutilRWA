import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import 'dashboard_design.dart';

class DashboardAllCategoriesRisquesDialog extends StatelessWidget {
  const DashboardAllCategoriesRisquesDialog({
    super.key,
    required this.categories,
    required this.totalNet,
    required this.scale,
    required this.amountUnit,
  });

  final List<MapEntry<String, double>> categories;
  final double totalNet;
  final double scale;
  final PortfolioAmountUnit amountUnit;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

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
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOUTES LES CATÉGORIES (GRANDS RISQUES)'.tr(context),
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
                        const SizedBox(
                          width: 32,
                          child: Text('#', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Catégorie d\'exposition'.tr(context), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Risque Net'.tr(context), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                        vDivHeader(),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Part (%)'.tr(context), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: headerText)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Liste scrollable
                  Flexible(
                    child: ListView.builder(addSemanticIndexes: false,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final isEven = index.isEven;
                        final entry = categories[index];
                        final valScaled = (entry.value / 1000000000) * scale;
                        final pct = (totalNet > 0) ? (entry.value / totalNet * 100) : 0.0;
                        
                        String formatCategory(String raw) {
                          String cleaned = raw.replaceFirst(RegExp(r'^\([a-zA-Z]\)\s*'), '').trim();
                          if (cleaned.isEmpty) return cleaned;
                          return cleaned[0].toUpperCase() + cleaned.substring(1);
                        }

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
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(formatCategory(entry.key).tr(context), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.navy), overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('${AppFormatters.compactNumber(valScaled)} ${amountUnit.label}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.ink, fontFeatures: Dash.tabular)),
                                ),
                              ),
                              vDiv(),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    (entry.value > 0 && pct < 0.05)
                                        ? '< 0.1 %'
                                        : '${pct.toStringAsFixed(1)} %',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.accent, fontFeatures: Dash.tabular),
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
