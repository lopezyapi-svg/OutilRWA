// Ce fichier affiche le tableau des rapports generes.
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/report_models.dart';

/// Tableau de consultation des rapports générés.
class ReportTable extends StatelessWidget {
  const ReportTable({
    super.key,
    required this.reports,
  });

  final List<ReportRecord> reports;

  @override
  Widget build(BuildContext context) {
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
              fontWeight: FontWeight.w800,
            ),
        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Periode')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Monnaie')),
          DataColumn(label: Text('Portee')),
          DataColumn(label: Text('Export PDF')),
          DataColumn(label: Text('Export Excel')),
        ],
        rows: reports.map((report) {
          return DataRow(
            cells: [
              DataCell(Text(report.id)),
              DataCell(Text(AppFormatters.shortDate(report.createdAt))),
              DataCell(Text(report.period)),
              DataCell(Text(report.reportType)),
              DataCell(Text(report.currency)),
              DataCell(Text(report.exposureScope)),
              DataCell(Text(report.exports['pdf'] ?? '-')),
              DataCell(Text(report.exports['excel'] ?? '-')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
