// Ce fichier construit la navigation laterale reutilisable.
import 'package:flutter/material.dart';

import '../../core/app_module.dart';
import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';
import 'rwa_tool_logo.dart';

const Color _sidebarDeepBlue = Color(0xFF234A84);

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
    if (compact) {
      return _CompactSidebar(
        items: _sidebarItems,
        selectedModule: selectedModule,
        onSelectModule: onSelectModule,
        contentTopInset: contentTopInset,
        headerTrailing: headerTrailing,
      );
    }

    return _ExpandedSidebar(
      items: _sidebarItems,
      selectedModule: selectedModule,
      onSelectModule: onSelectModule,
      showBrand: showBrand,
      contentTopInset: contentTopInset,
      headerTrailing: headerTrailing,
    );
  }
}

/// Structure interne qui décrit une entrée du menu latéral.
class _MenuEntry {
  const _MenuEntry.leaf({
    required this.module,
    required this.icon,
    required this.label,
  }) : children = const [];

  const _MenuEntry.group({
    required this.icon,
    required this.label,
    required this.children,
  }) : module = null;

  final AppModule? module;
  final IconData icon;
  final String label;
  final List<_MenuEntry> children;

  bool get hasChildren => children.isNotEmpty;

  bool matches(AppModule selectedModule) {
    if (module == selectedModule) {
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

const List<_MenuEntry> _riskCreditChildren = [
  _MenuEntry.leaf(
    module: AppModule.dashboard,
    icon: Icons.space_dashboard_rounded,
    label: 'Tableau de bord',
  ),
  _MenuEntry.leaf(
    module: AppModule.expositions,
    icon: Icons.view_list_rounded,
    label: 'Expositions',
  ),
];

const List<_MenuEntry> _sidebarItems = [
  _MenuEntry.group(
    icon: Icons.table_chart_rounded,
    label: 'Risque de crédit',
    children: _riskCreditChildren,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueMarche,
    icon: Icons.show_chart_rounded,
    label: 'Risque de marché',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.shield_outlined,
    label: 'Risque opérationnel',
  ),
  _MenuEntry.leaf(
    module: AppModule.analyse,
    icon: Icons.analytics_outlined,
    label: 'Analyse',
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.science_outlined,
    label: 'Stress test',
  ),
  _MenuEntry.leaf(
    module: AppModule.icap,
    icon: Icons.account_balance_outlined,
    label: 'ICAP',
  ),
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.timeline_rounded,
    label: 'Capital planing',
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
      child: Image(
        image: const AssetImage('assets/images/heymanns_logo.png'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF162742) : const Color(0xFFF1F5FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: selected
                  ? (isDark
                      ? const Color(0xFF34537F)
                      : const Color(0xFFD7E2FF))
                  : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: isDark
                          ? const Color(0x22040A16)
                          : const Color(0x142F55D4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(entry.icon, size: 16, color: iconColor),
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
            borderRadius: BorderRadius.circular(AppTheme.radius),
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

/// Groupe de navigation avec sous-éléments.
class _ExpandedNavGroup extends StatefulWidget {
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
  State<_ExpandedNavGroup> createState() => _ExpandedNavGroupState();
}

class _ExpandedNavGroupState extends State<_ExpandedNavGroup> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.entry.matches(widget.selectedModule);
  }

  @override
  void didUpdateWidget(covariant _ExpandedNavGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasSelected = oldWidget.entry.matches(oldWidget.selectedModule);
    final isSelected = widget.entry.matches(widget.selectedModule);

    if ((!wasSelected && isSelected) ||
        (!oldWidget.showLabel && widget.showLabel && isSelected)) {
      _isExpanded = true;
    } else if (wasSelected && !isSelected) {
      _isExpanded = false;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.showLabel) {
      return _ExpandedNavTile(
        entry: widget.entry,
        selected: widget.entry.matches(widget.selectedModule),
        showLabel: false,
        onTap: () => widget.onSelectModule(
          widget.entry.resolveTarget(widget.selectedModule),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExpandedNavTile(
          entry: widget.entry,
          selected: widget.entry.matches(widget.selectedModule),
          showLabel: true,
          trailing: Icon(
            _isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isDark
                ? const Color(0xFFD7E3FA)
                : const Color(0xFF5270A7),
          ),
          onTap: _toggleExpanded,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: _isExpanded
              ? Padding(
                  key: const ValueKey<String>('risk-credit-submenu'),
                  padding: const EdgeInsets.only(left: 18, right: 4, bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF11203A).withValues(alpha: 0.96)
                          : const Color(0xFFFDFDFE).withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF223754)
                            : const Color(0xFFE8ECF6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x18040A16)
                              : const Color(0x0A0F172A),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 7,
                          top: 4,
                          bottom: 6,
                          child: Container(
                            width: 1.1,
                            color: isDark
                                ? const Color(0xFF223754)
                                : const Color(0xFFE3E8F2),
                          ),
                        ),
                        Column(
                          children: [
                            for (final child in widget.entry.children)
                              _ExpandedSubNavTile(
                                entry: child,
                                selected: child.matches(widget.selectedModule),
                                onTap: () => widget.onSelectModule(
                                  child.resolveTarget(widget.selectedModule),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
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
        fontWeight: FontWeight.w800,
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
            child: Image(
              image: const AssetImage('assets/images/heymanns_logo.png'),
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
            context.tr("LEADER DE L'ALM EN AFRIQUE SUBSAHARIENNE"),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFF8FA6CB)
                  : const Color.fromARGB(255, 13, 33, 64),
              fontSize: 7,
              fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile d'un sous-menu de navigation.
class _ExpandedSubNavTile extends StatelessWidget {
  const _ExpandedSubNavTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _MenuEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDark ? const Color(0xFFD7E3FA) : const Color(0xFF345DA8);
    final mutedColor =
        isDark ? const Color(0xFF9FB2D6) : const Color(0xFF71829F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF172844) : const Color(0xFFF3F5F9))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: selected
                  ? (isDark
                      ? const Color(0xFF2D4B76)
                      : const Color(0xFFE3E8F2))
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accentColor : mutedColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.label.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? accentColor
                        : (isDark
                            ? const Color(0xFF9FB2D6)
                            : const Color(0xFF6B7790)),
                    fontSize: 10.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: accentColor,
                ),
              ],
            ],
          ),
        ),
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
              fontWeight: FontWeight.w800,
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
    final iconColor = isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue;
    final textColor = selected
        ? (isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1E3F74))
        : (isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue);
    const tileRadius = 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tileRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF162742) : const Color(0xFFEFF5FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tileRadius),
            border: Border.all(
              color: selected
                  ? (isDark ? const Color(0xFF34537F) : const Color(0xFFD7E4FB))
                  : Colors.transparent,
              width: 0.6,
            ),
          ),
          child: !showLabel
              ? Center(child: Icon(entry.icon, size: 17, color: iconColor))
              : Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDark
                                ? const Color(0xFF1C3154)
                                : const Color(0xFFDDEBFF))
                            : (isDark
                                ? const Color(0xFF14233D)
                                : const Color(0xFFF7FAFF)),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Icon(entry.icon, size: 15, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.label.tr(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w700,
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
