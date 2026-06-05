// Ce fichier affiche le tableau des expositions.
import 'package:flutter/material.dart';

import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/exposition_models.dart';

/// Tableau qui affiche les expositions filtrées.
class ExposureTable extends StatelessWidget {
  const ExposureTable({
    super.key,
    required this.rows,
  });

  final List<ExposureRecord> rows;

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
              fontWeight: FontWeight.w500,
            ),
        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Contrepartie')),
          DataColumn(label: Text('Categorie')),
          DataColumn(label: Text('Notation')),
          DataColumn(label: Text('Pays')),
          DataColumn(label: Text('Montant Brut')),
          DataColumn(label: Text('CRM')),
          DataColumn(label: Text('RW Final')),
          DataColumn(label: Text('RWA')),
          DataColumn(label: Text('Capital')),
        ],
        rows: rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.id)),
              DataCell(Text(row.counterparty.name)),
              DataCell(Text(row.categoryLabel)),
              DataCell(Text(row.counterparty.rating)),
              DataCell(Text(row.counterparty.country)),
              DataCell(Text(formatCurrencyForDisplay(
                row.grossAmount,
                fromCurrency: row.currency,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(
                  '${(row.crmCoveragePercent * 100).toStringAsFixed(0)} %')),
              DataCell(Text('${(row.finalRw * 100).toStringAsFixed(0)} %')),
              DataCell(Text(formatCurrencyForDisplay(
                row.rwa,
                fromCurrency: row.currency,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(formatCurrencyForDisplay(
                row.capital,
                fromCurrency: row.currency,
                toCurrency: displayCurrency,
              ))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
