// Ce fichier construit la navigation laterale reutilisable.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_module.dart';
import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';
import 'desktop_asset_image.dart';
import 'rwa_tool_logo.dart';

const Color _sidebarDeepBlue = Color(0xFF234A84);
const double _sidebarPanelRadius = 1;

/// Barre latérale qui gère la navigation entre les modules.
class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({
    super.key,
    required this.selectedModule,
    required this.onSelectModule,
    this.compact = false,
    this.showBrand = true,
    this.contentTopInset = 0,
    this.headerTrailing,
  });

  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final bool compact;
  final bool showBrand;
  final double contentTopInset;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final sidebar = compact
        ? _CompactSidebar(
            items: _sidebarItems,
            selectedModule: selectedModule,
            onSelectModule: onSelectModule,
            contentTopInset: contentTopInset,
            headerTrailing: headerTrailing,
          )
        : _ExpandedSidebar(
            items: _sidebarItems,
            selectedModule: selectedModule,
            onSelectModule: onSelectModule,
            showBrand: showBrand,
            contentTopInset: contentTopInset,
            headerTrailing: headerTrailing,
          );

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: AppTheme.fontFamily),
      child: sidebar,
    );
  }
}

/// Structure interne qui décrit une entrée du menu latéral.
class _MenuEntry {
  const _MenuEntry.leaf({
    required this.module,
    required this.icon,
    required this.label,
    this.selectable = true,
  }) : children = const [];

  const _MenuEntry.group({
    required this.icon,
    required this.label,
    required this.children,
  })  : module = null,
        selectable = false;

  final AppModule? module;
  final IconData icon;
  final String label;
  final List<_MenuEntry> children;
  final bool selectable;

  bool get hasChildren => children.isNotEmpty;

  IconData iconFor(bool selected) => selected ? _filledIconFor(icon) : icon;

  static IconData _filledIconFor(IconData icon) {
    return switch (icon) {
      Icons.autorenew_rounded => Icons.autorenew_rounded,
      Icons.file_download_outlined => Icons.file_download_rounded,
      Icons.compare_arrows_rounded => Icons.compare_arrows_rounded,
      Icons.open_in_new_rounded => Icons.open_in_new_rounded,
      Icons.notifications_none_rounded => Icons.notifications_rounded,
      Icons.business_center_outlined => Icons.business_center_rounded,
      Icons.bar_chart_rounded => Icons.insert_chart_rounded,
      Icons.analytics_outlined => Icons.analytics_rounded,
      Icons.pie_chart_outline_rounded => Icons.pie_chart_rounded,
      Icons.verified_outlined => Icons.verified_rounded,
      Icons.verified_user_outlined => Icons.verified_user_rounded,
      Icons.schedule_rounded => Icons.schedule_rounded,
      Icons.credit_card_outlined => Icons.credit_card_rounded,
      Icons.summarize_outlined => Icons.summarize_rounded,
      Icons.assignment_turned_in_outlined => Icons.assignment_turned_in_rounded,
      Icons.file_copy_outlined => Icons.file_copy_rounded,
      Icons.description_outlined => Icons.description_rounded,
      Icons.water_drop_outlined => Icons.water_drop_rounded,
      Icons.report_gmailerrorred_rounded => Icons.report_rounded,
      Icons.warning_amber_rounded => Icons.warning_rounded,
      Icons.local_fire_department_outlined =>
        Icons.local_fire_department_rounded,
      Icons.settings_outlined => Icons.settings_rounded,
      Icons.show_chart_rounded => Icons.show_chart_rounded,
      Icons.favorite_border_rounded => Icons.favorite_rounded,
      Icons.home_work_outlined => Icons.home_work_rounded,
      Icons.science_outlined => Icons.science_rounded,
      Icons.admin_panel_settings_outlined => Icons.admin_panel_settings_rounded,
      Icons.map_outlined => Icons.map_rounded,
      Icons.monetization_on_outlined => Icons.monetization_on_rounded,
      Icons.palette_outlined => Icons.palette_rounded,
      Icons.groups_2_outlined => Icons.groups_2_rounded,
      Icons.layers_outlined => Icons.layers_rounded,
      Icons.shield_outlined => Icons.shield_rounded,
      Icons.dashboard_outlined => Icons.dashboard_rounded,
      Icons.inventory_2_outlined => Icons.inventory_2_rounded,
      Icons.view_in_ar_outlined => Icons.view_in_ar_rounded,
      Icons.table_chart_outlined => Icons.table_chart_rounded,
      Icons.multiline_chart_rounded => Icons.multiline_chart_rounded,
      _ => icon,
    };
  }

  bool matches(AppModule selectedModule) {
    if (selectable && module == selectedModule) {
      return true;
    }
    return children.any((child) => child.matches(selectedModule));
  }

  AppModule resolveTarget(AppModule selectedModule) {
    if (module != null) {
      return module!;
    }

    for (final child in children) {
      if (child.matches(selectedModule)) {
        return child.resolveTarget(selectedModule);
      }
    }

    final fallbackModule = children.first.module;
    if (fallbackModule == null) {
      throw StateError('Le sous-menu ne contient aucun module navigable.');
    }
    return fallbackModule;
  }
}

class _MenuSelection {
  const _MenuSelection({
    required this.module,
    required this.id,
  });

  final AppModule module;
  final String id;
}

const List<_MenuEntry> _riskCreditChildren = [
  _MenuEntry.leaf(
    module: AppModule.dashboard,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard Crédit',
  ),
  _MenuEntry.leaf(
    module: AppModule.concentrationCredit,
    icon: Icons.pie_chart_outline_rounded,
    label: 'Portefeuille',
  ),
  _MenuEntry.leaf(
    module: AppModule.expositions,
    icon: Icons.credit_card_outlined,
    label: 'Expositions',
  ),
  _MenuEntry.leaf(
    module: AppModule.dashboard,
    icon: Icons.functions_rounded,
    label: 'RWA Engine',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.crm,
    icon: Icons.verified_user_outlined,
    label: 'CRM',
  ),
  _MenuEntry.leaf(
    module: AppModule.garanties,
    icon: Icons.home_work_outlined,
    label: 'Immobilier',
  ),
  _MenuEntry.leaf(
    module: AppModule.horsBilan,
    icon: Icons.file_copy_outlined,
    label: 'Hors bilan',
  ),
  _MenuEntry.leaf(
    module: AppModule.defautsImpayes,
    icon: Icons.warning_amber_rounded,
    label: 'Défaut',
  ),
  _MenuEntry.leaf(
    module: AppModule.defautsImpayes,
    icon: Icons.bar_chart_rounded,
    label: 'PD / Scoring',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.science_outlined,
    label: 'Stress Crédit',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.reportingCredit,
    icon: Icons.summarize_outlined,
    label: 'Reporting Crédit',
  ),
];

const List<_MenuEntry> _marketRiskChildren = [
  _MenuEntry.leaf(
    module: AppModule.risqueMarche,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard Marché',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueMarcheImport,
    icon: CupertinoIcons.doc_text_fill,
    label: 'Import données',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueMarcheVar,
    icon: Icons.multiline_chart_rounded,
    label: 'VaR',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueMarcheIndicateurs,
    icon: CupertinoIcons.chart_bar_alt_fill,
    label: 'Indicateurs clés',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueMarcheCourbeTaux,
    icon: CupertinoIcons.waveform_path_ecg,
    label: 'Courbe des taux',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueMarcheAmortissementCrd,
    icon: CupertinoIcons.graph_square_fill,
    label: 'Amortissement CRD',
  ),
];

const List<_MenuEntry> _operationalRiskChildren = [
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard Opérationnel',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.report_gmailerrorred_rounded,
    label: 'Incidents',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.monetization_on_outlined,
    label: 'Pertes opérationnelles',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.speed_rounded,
    label: 'KRI',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.map_outlined,
    label: 'Cartographie des risques',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.verified_user_outlined,
    label: 'Contrôles internes',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.account_tree_outlined,
    label: 'Workflow incidents',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.format_list_bulleted_rounded,
    label: 'Plans d’actions',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.schedule_rounded,
    label: 'Historique événements',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.summarize_outlined,
    label: 'Reporting opérationnel',
    selectable: false,
  ),
];

const List<_MenuEntry> _stressChildren = [
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard Stress',
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.public_rounded,
    label: 'Scénarios macroéconomiques',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.credit_card_outlined,
    label: 'Stress crédit',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.science_outlined,
    label: 'Stress marché',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.water_drop_outlined,
    label: 'Stress liquidité',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.home_work_outlined,
    label: 'Stress immobilier',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.center_focus_strong_rounded,
    label: 'Stress concentration',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.autorenew_rounded,
    label: 'Reverse stress testing',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.bar_chart_rounded,
    label: 'Impact solvabilité',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.monetization_on_outlined,
    label: 'Impact capital',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.summarize_outlined,
    label: 'Reporting stress',
    selectable: false,
  ),
];

const List<_MenuEntry> _icaapChildren = [
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard ICAAP',
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.bar_chart_rounded,
    label: 'Capital économique',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.layers_outlined,
    label: 'Capital réglementaire',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.favorite_border_rounded,
    label: 'Appétence au risque',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.shield_outlined,
    label: 'Buffers prudentiels',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.open_in_new_rounded,
    label: 'Projection capital',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.speed_rounded,
    label: 'Analyse solvabilité',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.format_list_bulleted_rounded,
    label: 'Plans de capital',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.summarize_outlined,
    label: 'Reporting ICAAP',
    selectable: false,
  ),
];

const List<_MenuEntry> _capitalPlanningChildren = [
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard Capital',
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.open_in_new_rounded,
    label: 'Projection RWA',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.speed_rounded,
    label: 'Projection solvabilité',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.analytics_outlined,
    label: 'Scénarios croissance',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.monetization_on_outlined,
    label: 'Besoins futurs capital',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.file_download_outlined,
    label: 'Gestion dividendes',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.inventory_2_outlined,
    label: 'Allocation capital',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.tune_rounded,
    label: 'Optimisation capital',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.shield_outlined,
    label: 'Buffers réglementaires',
    selectable: false,
  ),
];

const List<_MenuEntry> _settingsChildren = [
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.table_chart_outlined,
    label: 'Référentiels',
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.groups_2_outlined,
    label: 'Utilisateurs',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.admin_panel_settings_outlined,
    label: 'Rôles & permissions',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.description_outlined,
    label: 'Journaux système',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.tune_rounded,
    label: 'Paramètres prudentiels',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.assignment_turned_in_outlined,
    label: 'Paramètres réglementaires',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.schedule_rounded,
    label: 'Historique calculs',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.verified_outlined,
    label: 'Audit trail',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.shield_outlined,
    label: 'Sécurité',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.settings_outlined,
    label: 'Paramètres application',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.monetization_on_outlined,
    label: 'Devise',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.public_rounded,
    label: 'Langue',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.tune_rounded,
    label: 'Configuration moteurs',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.functions_rounded,
    label: 'Configuration calculs',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.view_in_ar_outlined,
    label: 'Templates',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.notifications_none_rounded,
    label: 'Seuils alertes',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: Icons.palette_outlined,
    label: 'Paramètres graphiques',
    selectable: false,
  ),
];

const List<_MenuEntry> _sidebarItems = [
  _MenuEntry.leaf(
    module: AppModule.vueEnsemble,
    icon: Icons.pie_chart_outline_rounded,
    label: 'Vue d\'ensemble',
  ),
  _MenuEntry.group(
    icon: Icons.monetization_on_outlined,
    label: 'Risque Crédit',
    children: _riskCreditChildren,
  ),
  _MenuEntry.group(
    icon: Icons.show_chart_rounded,
    label: 'Risque du Marché',
    children: _marketRiskChildren,
  ),
  _MenuEntry.group(
    icon: Icons.shield_outlined,
    label: 'Risque Opérationnel',
    children: _operationalRiskChildren,
  ),
  _MenuEntry.group(
    icon: Icons.science_outlined,
    label: 'Stress Test',
    children: _stressChildren,
  ),
  _MenuEntry.group(
    icon: Icons.business_center_outlined,
    label: 'ICAAP',
    children: _icaapChildren,
  ),
  _MenuEntry.group(
    icon: Icons.bar_chart_rounded,
    label: 'Capital Planning',
    children: _capitalPlanningChildren,
  ),
  _MenuEntry.group(
    icon: Icons.settings_outlined,
    label: 'Paramètres',
    children: _settingsChildren,
  ),
];

/// Variante compacte de la sidebar affichant surtout les icônes.
class _CompactSidebar extends StatelessWidget {
  const _CompactSidebar({
    required this.items,
    required this.selectedModule,
    required this.onSelectModule,
    required this.contentTopInset,
    this.headerTrailing,
  });

  final List<_MenuEntry> items;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final double contentTopInset;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1B31).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(_sidebarPanelRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE5E8F5),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33040A16) : const Color(0x120F172A),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 2),
          if (contentTopInset > 0) SizedBox(height: contentTopInset),
          if (headerTrailing != null) ...[
            Align(
              alignment: Alignment.center,
              child: headerTrailing!,
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = items[index];
                if (entry.hasChildren) {
                  return _CompactNavGroup(
                    entry: entry,
                    selectedModule: selectedModule,
                    onSelectModule: onSelectModule,
                  );
                }

                return _CompactNavButton(
                  entry: entry,
                  selected: entry.matches(selectedModule),
                  onTap: () => onSelectModule(
                    entry.resolveTarget(selectedModule),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF22304B) : const Color(0xFFE5ECFA),
          ),
          const SizedBox(height: 8),
          const _CompactSidebarLogo(),
        ],
      ),
    );
  }
}

/// Bloc logo affiché en haut de la sidebar compacte.
class _CompactSidebarLogo extends StatelessWidget {
  const _CompactSidebarLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 42,
      height: 34,
      child: DesktopAssetImage(
        'assets/images/heymanns_logo.png',
        fit: BoxFit.contain,
        color: isDark ? const Color(0xFFEAF1FF) : null,
        colorBlendMode: isDark ? BlendMode.srcIn : null,
        opacity: isDark
            ? const AlwaysStoppedAnimation<double>(0.82)
            : const AlwaysStoppedAnimation<double>(1),
      ),
    );
  }
}

/// Groupe de navigation compact affiché dans une carte flottante.
class _CompactNavGroup extends StatelessWidget {
  const _CompactNavGroup({
    required this.entry,
    required this.selectedModule,
    required this.onSelectModule,
  });

  final _MenuEntry entry;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupSelected = entry.matches(selectedModule);
    final popupBackground = isDark ? const Color(0xFF0F1B31) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF263856) : const Color(0xFFDDE6F4);

    return PopupMenuButton<_MenuSelection>(
      tooltip: '',
      offset: const Offset(48, -4),
      color: popupBackground,
      elevation: 10,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: borderColor),
      ),
      constraints: const BoxConstraints(
        minWidth: 194,
        maxWidth: 220,
      ),
      onSelected: (selection) => onSelectModule(selection.module),
      itemBuilder: (context) => [
        for (final child in entry.children)
          PopupMenuItem<_MenuSelection>(
            key: ValueKey('${entry.label}:${child.label}:compact'),
            value: _MenuSelection(
              module: child.resolveTarget(selectedModule),
              id: '${entry.label}:${child.label}:compact',
            ),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: _CompactFloatingMenuItem(
              entry: child,
              selected: child.matches(selectedModule),
            ),
          ),
      ],
      child: _CompactNavButtonSurface(
        entry: entry,
        selected: groupSelected,
      ),
    );
  }
}

class _CompactFloatingMenuItem extends StatelessWidget {
  const _CompactFloatingMenuItem({
    required this.entry,
    required this.selected,
  });

  final _MenuEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBlue =
        isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    final iconColor = selected ? Colors.white : const Color(0xFF71829F);
    final textColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : const Color(0xFF60708B));

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? selectedBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Icon(
            entry.iconFor(selected),
            size: 16,
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xFF9FB2D6) : iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.label.tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 10.4,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactNavButtonSurface extends StatelessWidget {
  const _CompactNavButtonSurface({
    required this.entry,
    required this.selected,
  });

  final _MenuEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue);
    const buttonSize = 36.0;
    const iconSize = 16.0;
    final selectedColor =
        isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: selected ? selectedColor : Colors.transparent,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: isDark
                      ? const Color(0x553B82F6)
                      : const Color(0x332563EB),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(entry.iconFor(selected), size: iconSize, color: iconColor),
      ),
    );
  }
}

/// Bouton de navigation individuel pour la sidebar compacte.
class _CompactNavButton extends StatelessWidget {
  const _CompactNavButton({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _MenuEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: _CompactNavButtonSurface(
          entry: entry,
          selected: selected,
        ),
      ),
    );
  }
}

/// Variante ouverte de la sidebar avec icônes et libellés.
class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.items,
    required this.selectedModule,
    required this.onSelectModule,
    required this.showBrand,
    required this.contentTopInset,
    this.headerTrailing,
  });

  final List<_MenuEntry> items;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final bool showBrand;
  final double contentTopInset;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCondensed = constraints.maxWidth < 118;
        final panelPadding = isCondensed ? 8.0 : AppTheme.spacing;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(panelPadding),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1B31).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(_sidebarPanelRadius),
            border: Border.all(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE5E8F5),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isDark ? const Color(0x33040A16) : const Color(0x120F172A),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contentTopInset > 0) SizedBox(height: contentTopInset),
              if (showBrand && !isCondensed) ...[
                const _BrandHeader(),
                const SizedBox(height: 12),
              ],
              if (!isCondensed) ...[
                Row(
                  children: [
                    Expanded(
                      child: _SidebarSectionTitle(context.tr('Navigation')),
                    ),
                    if (headerTrailing != null) ...[
                      const SizedBox(width: 8),
                      headerTrailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    if (entry.hasChildren) {
                      return _ExpandedNavGroup(
                        entry: entry,
                        selectedModule: selectedModule,
                        onSelectModule: onSelectModule,
                        showLabel: !isCondensed,
                      );
                    }

                    return _ExpandedNavTile(
                      entry: entry,
                      selected: entry.matches(selectedModule),
                      showLabel: !isCondensed,
                      onTap: () => onSelectModule(
                        entry.resolveTarget(selectedModule),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Divider(
                height: 1,
                thickness: 1,
                color:
                    isDark ? const Color(0xFF22304B) : const Color(0xFFE5ECFA),
              ),
              const SizedBox(height: 10),
              if (isCondensed) ...[
                const Center(child: _CompactSidebarLogo()),
              ] else ...[
                _SidebarSectionTitle(context.tr('Service')),
                const SizedBox(height: 8),
                const _SidebarServiceCard(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Groupe de navigation ouvert affichant ses sous-sections en panneau flottant.
class _ExpandedNavGroup extends StatelessWidget {
  const _ExpandedNavGroup({
    required this.entry,
    required this.selectedModule,
    required this.onSelectModule,
    required this.showLabel,
  });

  final _MenuEntry entry;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupSelected = entry.matches(selectedModule);
    final popupBackground = isDark ? const Color(0xFF0F1B31) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF263856) : const Color(0xFFDDE6F4);
    final popupOffset =
        showLabel ? const Offset(205, -4) : const Offset(48, -4);

    return TooltipVisibility(
      visible: false,
      child: PopupMenuButton<_MenuSelection>(
        tooltip: '',
        offset: popupOffset,
        color: popupBackground,
        elevation: 10,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: borderColor),
        ),
        constraints: const BoxConstraints(
          minWidth: 220,
          maxWidth: 252,
        ),
        onSelected: (selection) => onSelectModule(selection.module),
        itemBuilder: (context) => [
          for (final child in entry.children)
            PopupMenuItem<_MenuSelection>(
              key: ValueKey('${entry.label}:${child.label}:expanded'),
              value: _MenuSelection(
                module: child.resolveTarget(selectedModule),
                id: '${entry.label}:${child.label}:expanded',
              ),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: _CompactFloatingMenuItem(
                entry: child,
                selected: child.matches(selectedModule),
              ),
            ),
        ],
        child: IgnorePointer(
          child: _ExpandedNavTile(
            entry: entry,
            selected: groupSelected,
            showLabel: showLabel,
            trailing: showLabel
                ? Icon(
                    Icons.chevron_right_rounded,
                    size: 12,
                    color: groupSelected
                        ? Colors.white.withValues(alpha: 0.95)
                        : (isDark
                            ? const Color(0xFFD7E3FA)
                            : const Color(0xFF5270A7)),
                  )
                : null,
            onTap: () {},
          ),
        ),
      ),
    );
  }
}

/// Titre de section utilisé dans la sidebar étendue.
class _SidebarSectionTitle extends StatelessWidget {
  const _SidebarSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      label,
      style: TextStyle(
        color: isDark ? const Color(0xFF9CB2D4) : _sidebarDeepBlue,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Carte d'information affichée en bas de la sidebar.
class _SidebarServiceCard extends StatelessWidget {
  const _SidebarServiceCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 58,
            child: DesktopAssetImage(
              'assets/images/heymanns_logo.png',
              fit: BoxFit.contain,
              color: isDark ? const Color(0xFFEAF1FF) : null,
              colorBlendMode: isDark ? BlendMode.srcIn : null,
              opacity: isDark
                  ? const AlwaysStoppedAnimation<double>(0.84)
                  : const AlwaysStoppedAnimation<double>(1),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(
              "LEADER DE L'ALM ET DU RISK MANAGEMENT EN AFRIQUE SUBSAHARIENNE",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFF8FA6CB)
                  : const Color.fromARGB(255, 13, 33, 64),
              fontSize: 7,
              fontWeight: FontWeight.w500,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF22304B) : const Color(0xFFD9E4F6),
          ),
          const SizedBox(height: 6),
          Text(
            'Version : 1.0.0'.tr(context),
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFD7E3FA)
                  : const Color.fromARGB(255, 6, 24, 57),
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête de marque affiché dans la sidebar ouverte.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3C5E) : const Color(0xFFD9E4F6),
            ),
          ),
          child: const RwaToolLogo(size: 34),
        ),
        const SizedBox(width: AppTheme.spacing),
        Expanded(
          child: Text(
            context.tr('Risk management'),
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFD7E3FA)
                  : const Color.fromARGB(255, 16, 42, 94),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tuile de navigation complète pour la sidebar étendue.
class _ExpandedNavTile extends StatelessWidget {
  const _ExpandedNavTile({
    required this.entry,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.trailing,
  });

  final _MenuEntry entry;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBlue =
        isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    final iconColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue);
    final textColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue);
    final tileColor = selected
        ? selectedBlue
        : (isDark
            ? const Color(0xFF16304F).withValues(alpha: 0.46)
            : const Color(0xFFF4F8FF));
    final tileBorderColor = selected ? selectedBlue : Colors.transparent;
    final tileBorderWidth = selected ? 1.0 : 0.0;
    final tileShadow = selected
        ? [
            BoxShadow(
              color: selectedBlue.withValues(alpha: isDark ? 0.34 : 0.22),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ]
        : [
            BoxShadow(
              color: isDark ? const Color(0x0A040A16) : const Color(0x040F172A),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ];
    const tileRadius = 5.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tileRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(tileRadius),
            border: Border.all(
              color: tileBorderColor,
              width: tileBorderWidth,
            ),
            boxShadow: tileShadow,
          ),
          child: !showLabel
              ? Center(
                  child: Icon(
                    entry.iconFor(selected),
                    size: 17,
                    color: iconColor,
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.16)
                            : (isDark
                                ? const Color(0xFF14233D)
                                : const Color(0xFFF7FAFF)),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Icon(
                        entry.iconFor(selected),
                        size: 14,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        entry.label.tr(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10.4,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
