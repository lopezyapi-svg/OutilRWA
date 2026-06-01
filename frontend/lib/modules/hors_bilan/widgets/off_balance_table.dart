// Ce fichier affiche le tableau des engagements hors bilan.
import 'package:flutter/material.dart';

import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/hors_bilan_models.dart';

/// Tableau d'affichage des engagements hors bilan.
class OffBalanceTable extends StatelessWidget {
  const OffBalanceTable({
    super.key,
    required this.rows,
  });

  final List<OffBalanceRecord> rows;

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
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Contrepartie')),
          DataColumn(label: Text('Nature d\'engagement')),
          DataColumn(label: Text('Nominal')),
          DataColumn(label: Text('CCF')),
          DataColumn(label: Text('EAD')),
          DataColumn(label: Text('RW')),
          DataColumn(label: Text('RWA')),
          DataColumn(label: Text('Capital')),
        ],
        rows: rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.id)),
              DataCell(Text(row.counterpartyName)),
              DataCell(Text(row.engagementType)),
              DataCell(Text(formatCurrencyForDisplay(
                row.nominalAmount,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(AppFormatters.percent(row.ccf))),
              DataCell(Text(formatCurrencyForDisplay(
                row.ead,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(AppFormatters.percent(row.riskWeight))),
              DataCell(Text(formatCurrencyForDisplay(
                row.rwa,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(formatCurrencyForDisplay(
                row.capital,
                toCurrency: displayCurrency,
              ))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
