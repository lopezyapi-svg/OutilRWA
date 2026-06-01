// Ce fichier affiche le tableau CRM avant et apres mitigation.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/crm_models.dart';

/// Tableau de consultation des garanties CRM.
class CrmTable extends StatelessWidget {
  const CrmTable({
    super.key,
    required this.rows,
  });

  final List<CrmRecord> rows;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        horizontalMargin: 8,
        headingRowHeight: 38,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        dividerThickness: 0.4,
        headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
        columns: [
          DataColumn(label: Text(context.tr('ID'))),
          DataColumn(label: Text(context.tr('Emprunteur'))),
          DataColumn(label: Text(context.tr('Garant'))),
          DataColumn(label: Text(context.tr('Couverture'))),
          DataColumn(label: Text(context.tr('RW Avant'))),
          DataColumn(label: Text(context.tr('RW Final'))),
          DataColumn(label: Text(context.tr('RWA Avant'))),
          DataColumn(label: Text(context.tr('RWA Apres'))),
          DataColumn(label: Text(context.tr('Economie Capital'))),
        ],
        rows: rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.id)),
              DataCell(Text(row.borrowerName)),
              DataCell(Text(row.guarantorName)),
              DataCell(Text(formatCurrencyForDisplay(
                row.coverageAmount,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(AppFormatters.percent(row.borrowerRw))),
              DataCell(Text(AppFormatters.percent(row.finalRw))),
              DataCell(Text(formatCurrencyForDisplay(
                row.rwaBefore,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(formatCurrencyForDisplay(
                row.rwaAfter,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(formatCurrencyForDisplay(
                row.capitalSaving,
                toCurrency: displayCurrency,
              ))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
