import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';

import '../../expositions/widgets/excel_import_dialog.dart';
import '../../risque_marche/screens/market_data_import_screen.dart';
import '../../risque_operationnel/widgets/ro_import_pertes_dialog.dart';

class ImportationsScreen extends StatefulWidget {
  const ImportationsScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<ImportationsScreen> createState() => _ImportationsScreenState();
}

class _ImportationsScreenState extends State<ImportationsScreen> {
  String? successMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.pagePadding,
              top: AppTheme.pagePadding,
              right: AppTheme.pagePadding,
              bottom: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion des Importations',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
                const SizedBox(height: 6),
                Text(
                  'Importez et consolidez les données d\'exposition par catégorie pour le calcul des risques pondérés (RWA).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (AppTheme.pagePadding * 2),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.accent.withValues(alpha: 0.1),
                                        width: 2,
                                      ),
                                    ),
                                    child: Lottie.asset(
                                      successMessage != null ? 'assets/lotties/Success.json' : 'assets/lotties/import_loader.json',
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      repeat: successMessage == null,
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 180,
                                        child: _buildImportCard(
                                          context,
                                          title: 'Risque de Crédit',
                                          backgroundColor: AppTheme.accent,
                                          borderColor: AppTheme.accent,
                                          textColor: Colors.white,
                                          onTap: () async {
                                            final result = await showExcelImportDialog(
                                              context,
                                              api: widget.api,
                                              onImportApplied: () async {},
                                            );
                                            if (!mounted) return;
                                            if (result != null) {
                                              setState(() {
                                                successMessage = 'Données risque de crédit chargées avec succès';
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: 180,
                                        child: _buildImportCard(
                                          context,
                                          title: 'Risque de Marché',
                                          backgroundColor: AppTheme.success,
                                          borderColor: AppTheme.success,
                                          textColor: Colors.white,
                                          onTap: () async {
                                            final success = await showMarketDataImportDialog(context);
                                            if (!mounted) return;
                                            if (success) {
                                              setState(() {
                                                successMessage = 'Données risque de marché chargées avec succès';
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: 180,
                                        child: _buildImportCard(
                                          context,
                                          title: 'Risque Opérationnel',
                                          backgroundColor: AppTheme.warning,
                                          borderColor: AppTheme.warning,
                                          textColor: Colors.white,
                                          onTap: () async {
                                            final success = await showRoImportPertesDialog(context, api: widget.api);
                                            if (!mounted) return;
                                            if (success == true) {
                                              setState(() {
                                                successMessage = 'Données risque opérationnel chargées avec succès';
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (successMessage != null) ...[
                                    const SizedBox(height: 32),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle, color: AppTheme.success),
                                          const SizedBox(width: 8),
                                          Text(
                                            successMessage!,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: AppTheme.success,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return Card(
      elevation: 0,
      color: backgroundColor ?? Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: borderColor ?? Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: textColor ?? AppTheme.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

