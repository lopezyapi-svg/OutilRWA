// Ecran du module stress test.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

/// Ecran de simulation des scenarios adverses.
class StressTestScreen extends StatelessWidget {
  const StressTestScreen({
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
            title: 'Stress test',
            subtitle:
                'Simulation de chocs et scénarios adverses sur le portefeuille et le capital.',
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
