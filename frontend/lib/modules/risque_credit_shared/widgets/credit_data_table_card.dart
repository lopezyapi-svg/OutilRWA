import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';

class CreditDataTableCard extends StatelessWidget {
  const CreditDataTableCard({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.toolbar,
    this.trailing,
    this.emptyMessage = 'Aucune donnée disponible pour les filtres sélectionnés.',
  });

  final String title;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Widget? toolbar;
  final Widget? trailing;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      trailing: trailing,
      child: Column(
        children: [
          if (toolbar != null) ...[
            toolbar!,
            const SizedBox(height: AppTheme.spacing),
          ],
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                horizontalMargin: 8,
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                dividerThickness: 0.35,
                headingTextStyle:
                    Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                columns: columns,
                rows: rows,
              ),
            ),
        ],
      ),
    );
  }
}
