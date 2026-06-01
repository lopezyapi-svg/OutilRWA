// Ce fichier encapsule les blocs de contenu reutilisables.
import 'package:flutter/material.dart';

import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';

/// Conteneur visuel standard utilisé pour regrouper un bloc fonctionnel.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title.trim().isNotEmpty || trailing != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasHeader) ...[
              Row(
                children: [
                  if (title.trim().isNotEmpty)
                    Expanded(
                      child: Text(
                        title.tr(context),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: AppTheme.spacing),
              Divider(color: dividerColor),
              const SizedBox(height: AppTheme.spacing),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
