// Ce fichier affiche le module des paramètres prudentiels.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran des paramètres et référentiels prudentiels.
class ReferentielsScreen extends StatelessWidget {
  const ReferentielsScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEAF2FF) : const Color(0xFF13203A);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Paramètres',
            subtitle: 'Référentiels et paramètres prudentiels.',
          ),
          Expanded(
            child: Center(
              child: Text(
                'Cette section est en cours de construction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
