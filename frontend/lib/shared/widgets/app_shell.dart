// Ce fichier structure le layout principal de l'application.
import 'package:flutter/material.dart';

import '../../core/app_module.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/global_search_entry.dart';
import '../../core/services/rwa_api_service.dart';
import '../../core/theme/app_theme.dart';
import 'rwa_tool_logo.dart';
import 'sidebar_navigation.dart';

/// Coquille principale de l'application avec top bar, sidebar et contenu.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.api,
    required this.selectedModule,
    required this.onSelectModule,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.portfolioDisplayCurrency,
    required this.appLanguage,
    required this.child,
  });

  final RwaApiService api;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<AppLanguage> appLanguage;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Etat interne qui pilote la recherche, la sidebar et la top bar.
class _AppShellState extends State<AppShell> {
  static const double _screenSpacing = AppTheme.spacing;
  static const double _compactSidebarWidth = 60;
  static const double _expandedSidebarWidth = 220;
  static const double _sidebarToggleReserve = 20;
  bool _isSidebarCompact = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1120;

        if (isDesktop) {
          return _buildDesktopShell();
        }

        return _buildMobileShell();
      },
    );
  }

  Widget _buildDesktopShell() {
    final sidebarWidth = _isSidebarCompact
        ? _compactSidebarWidth
        : _expandedSidebarWidth;
    final sidebarAreaWidth = sidebarWidth + _sidebarToggleReserve;
    final toggleLeft = sidebarWidth - 10;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF091224)
          : const Color(0xFFEAE9F8),
      body: Stack(
        children: [
          // Ce fond reste fixe derrière tout l'espace de travail.
          _DecorativeBackdrop(dark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(_screenSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // La top bar concentre la marque, la recherche et les actions globales.
                  _WorkspaceTopBar(
                    api: widget.api,
                    onSelectModule: widget.onSelectModule,
                    themeMode: widget.themeMode,
                    onThemeModeChanged: widget.onThemeModeChanged,
                    selectedModule: widget.selectedModule,
                    portfolioDisplayCurrency: widget.portfolioDisplayCurrency,
                    appLanguage: widget.appLanguage,
                  ),
                  const SizedBox(height: AppTheme.spacing),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: sidebarAreaWidth,
                          child: RepaintBoundary(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _DesktopSidebarFrame(
                                    width: sidebarWidth,
                                    selectedModule: widget.selectedModule,
                                    onSelectModule: widget.onSelectModule,
                                  ),
                                ),
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  top: 16,
                                  left: toggleLeft,
                                  child: _SidebarToggleButton(
                                    compact: _isSidebarCompact,
                                    onTap: () => setState(
                                      () => _isSidebarCompact =
                                          !_isSidebarCompact,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: RepaintBoundary(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F1B31).withOpacity(0.92)
                                    : Colors.white.withOpacity(0.80),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius,
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF22304B)
                                      : const Color(0xFFE5E8F5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? const Color(0x33040A16)
                                        : const Color(0x120F172A),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius,
                                ),
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileShell() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF091224)
          : const Color(0xFFF0F2F8),
      // Sur mobile, la navigation passe dans un drawer pour conserver de l'espace utile.
      drawer: Drawer(
        child: SidebarNavigation(
          selectedModule: widget.selectedModule,
          onSelectModule: (module) {
            Navigator.of(context).pop();
            widget.onSelectModule(module);
          },
          compact: false,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_screenSpacing),
          child: Column(
            children: [
              // La barre mobile garde seulement le contexte courant et l'accès au menu.
              _TopBar(
                selectedModule: widget.selectedModule,
                showMenuButton: true,
              ),
              const SizedBox(height: _screenSpacing),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1B31) : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: isDark ? const Color(0xFF22304B) : AppTheme.border,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fond décoratif léger affiché derrière l'espace de travail.
class _DecorativeBackdrop extends StatelessWidget {
  const _DecorativeBackdrop({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF091224), Color(0xFF0B1630), Color(0xFF0F1D38)]
              : const [Color(0xFFF2F0FF), Color(0xFFE8F0FB), Color(0xFFF6F3FF)],
        ),
      ),
      child: Stack(
        children: [
          _BackdropOrb(
            alignment: Alignment.topLeft,
            size: 360,
            colors: dark
                ? const [Color(0x224C8FFF), Color(0x004C8FFF)]
                : const [Color(0x33BCA7FF), Color(0x00BCA7FF)],
            offset: Offset(-110, -100),
          ),
          _BackdropOrb(
            alignment: Alignment.centerRight,
            size: 420,
            colors: dark
                ? const [Color(0x1C7E6CFF), Color(0x007E6CFF)]
                : const [Color(0x33C3A6FF), Color(0x00C3A6FF)],
            offset: Offset(130, 0),
          ),
          _BackdropOrb(
            alignment: Alignment.bottomLeft,
            size: 320,
            colors: dark
                ? const [Color(0x1423A6FF), Color(0x0023A6FF)]
                : const [Color(0x33A6FFE3), Color(0x00A6FFE3)],
            offset: Offset(-60, 90),
          ),
        ],
      ),
    );
  }
}

/// Élément décoratif circulaire utilisé dans le fond d'écran.
class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    required this.alignment,
    required this.size,
    required this.colors,
    required this.offset,
  });

  final Alignment alignment;
  final double size;
  final List<Color> colors;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}

IconData _iconForModule(AppModule module) {
  switch (module) {
    case AppModule.dashboard:
      return Icons.grid_view_rounded;
    case AppModule.expositions:
      return Icons.inventory_2_outlined;
    case AppModule.horsBilan:
      return Icons.account_balance_wallet_outlined;
    case AppModule.crm:
      return Icons.analytics_outlined;
    case AppModule.referentiels:
      return Icons.menu_book_outlined;
    case AppModule.rapports:
      return Icons.assessment_outlined;
  }
}

/// Barre supérieure de l'espace de travail.
class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.api,
    required this.onSelectModule,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.selectedModule,
    required this.portfolioDisplayCurrency,
    required this.appLanguage,
  });

  final RwaApiService api;
  final ValueChanged<AppModule> onSelectModule;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final AppModule selectedModule;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<AppLanguage> appLanguage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1B31).withOpacity(0.94)
            : Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x26040A16) : const Color(0x0D0F172A),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ces seuils permettent de simplifier progressivement la barre sur des largeurs réduites.
          final showActionButtons = constraints.maxWidth >= 1380;

          return Row(
            children: [
              // La marque reste à gauche pour ancrer la lecture de l'application.
              const _ShellBrand(),
              const Spacer(),
              _PortfolioCurrencyPicker(
                selectedCurrencyListenable: portfolioDisplayCurrency,
              ),
              const SizedBox(width: 6),
              _ThemeModePill(
                themeMode: themeMode,
                onThemeModeChanged: onThemeModeChanged,
              ),
              const SizedBox(width: 6),
              _LanguagePicker(appLanguage: appLanguage),
              if (showActionButtons) ...[
                // Les actions secondaires et primaires ne s'affichent que sur les écrans larges.
                const SizedBox(width: 8),
                _HeaderGhostButton(
                  label: context.tr('Exporter'),
                  icon: Icons.file_download_outlined,
                ),
                const SizedBox(width: 6),
                _HeaderPrimaryButton(
                  label: context.tr('Nouvelle analyse'),
                  icon: Icons.add_rounded,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Bloc de marque affiché dans la barre supérieure.
class _ShellBrand extends StatelessWidget {
  const _ShellBrand();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : const Color(0xFFF9FAFF),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3C5E) : const Color(0xFFD9E4F6),
            ),
          ),
          child: const RwaToolLogo(size: 40),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('RWA Crédit'),
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFC9D6FF)
                    : const Color.fromARGB(255, 85, 98, 245),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 0.1),
            Text(
              context.tr('Outil de pilotage des fonds propres'),
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF8FA0BC)
                    : const Color.fromARGB(255, 10, 3, 141),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cadre qui positionne la sidebar sur desktop.
class _DesktopSidebarFrame extends StatelessWidget {
  const _DesktopSidebarFrame({
    required this.width,
    required this.selectedModule,
    required this.onSelectModule,
  });

  final double width;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        child: ClipRect(
          child: SidebarNavigation(
            selectedModule: selectedModule,
            onSelectModule: onSelectModule,
            compact: false,
            showBrand: false,
            contentTopInset: 0,
          ),
        ),
      ),
    );
  }
}

/// Bouton qui replie ou déplie la sidebar.
class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF14233D) : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      elevation: 4,
      shadowColor: isDark ? const Color(0x33040A16) : const Color(0x150F172A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          width: 30,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3C5E) : const Color(0xFFD9E4F6),
            ),
          ),
          child: Icon(
            compact ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            color: isDark ? const Color(0xFFD7E3FA) : const Color(0xFF47619C),
            size: 16,
          ),
        ),
      ),
    );
  }
}

/// Champ de recherche globale présent dans la top bar.
class _GlobalSearchField extends StatefulWidget {
  const _GlobalSearchField({
    required this.api,
    required this.panelWidth,
    required this.onSelectModule,
  });

  final RwaApiService api;
  final double panelWidth;
  final ValueChanged<AppModule> onSelectModule;

  @override
  State<_GlobalSearchField> createState() => _GlobalSearchFieldState();
}

/// Etat interne du champ de recherche et de sa liste de résultats.
class _GlobalSearchFieldState extends State<_GlobalSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<GlobalSearchEntry> _catalog = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    // On charge une seule fois le catalogue pour garder une saisie fluide ensuite.
    final catalog = await widget.api.fetchGlobalSearchCatalog();
    if (!mounted) {
      return;
    }
    setState(() {
      _catalog = catalog;
      _isLoading = false;
    });
  }

  Iterable<GlobalSearchEntry> _buildOptions(TextEditingValue value) {
    if (_catalog.isEmpty) {
      return const <GlobalSearchEntry>[];
    }

    final query = value.text.trim();
    if (query.isEmpty) {
      // Sans recherche, on met en avant les modules pour faciliter la navigation rapide.
      return _catalog
          .where((entry) => entry.section == 'Module')
          .take(8)
          .toList(growable: false);
    }

    final normalizedQuery = _normalize(query);
    // Chaque résultat reçoit un score simple pour remonter les correspondances les plus utiles.
    final scored =
        _catalog
            .map(
              (entry) =>
                  (entry: entry, score: _scoreEntry(entry, normalizedQuery)),
            )
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(10).map((item) => item.entry).toList(growable: false);
  }

  int _scoreEntry(GlobalSearchEntry entry, String query) {
    final title = _normalize(entry.title);
    final subtitle = _normalize(entry.subtitle);
    final section = _normalize(entry.section);
    final index = _normalize(entry.searchIndex);

    // On favorise d'abord le titre exact, puis les préfixes, puis les autres correspondances.
    if (title == query) {
      return 140;
    }
    if (title.startsWith(query)) {
      return 110;
    }
    if (title.contains(query)) {
      return 80;
    }
    if (section.contains(query)) {
      return 55;
    }
    if (subtitle.contains(query)) {
      return 40;
    }
    if (index.contains(query)) {
      return 24;
    }
    return 0;
  }

  String _normalize(String value) {
    const source = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
    const target = 'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().split('')) {
      // Cette normalisation rend la recherche tolérante aux accents.
      final index = source.toLowerCase().indexOf(char);
      buffer.write(index >= 0 ? target.toLowerCase()[index] : char);
    }
    return buffer.toString();
  }

  void _handleSubmit() {
    final results = _buildOptions(_controller.value).toList(growable: false);
    if (results.isEmpty) {
      return;
    }
    _selectEntry(results.first);
  }

  void _selectEntry(GlobalSearchEntry entry) {
    widget.onSelectModule(entry.module);
    _controller
      ..text = entry.title
      ..selection = TextSelection.collapsed(offset: entry.title.length);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RawAutocomplete<GlobalSearchEntry>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (entry) => entry.title,
      optionsBuilder: _buildOptions,
      onSelected: _selectEntry,
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return SizedBox(
          height: 30,
          child: TextField(
            controller: textEditingController,
            focusNode: focusNode,
            onSubmitted: (_) => _handleSubmit(),
            style: TextStyle(
              color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: context.tr('Recherche rapide'),
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFF8FA0BC) : AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 14,
                color: isDark ? const Color(0xFF8FA0BC) : AppTheme.muted,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 30,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              suffixIcon: _isLoading
                  ? const Padding(
                      // Un loader léger indique que le catalogue n'est pas encore prêt.
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (textEditingController.text.isEmpty
                        ? null
                        : IconButton(
                            // Le bouton efface rapidement la requête sans quitter le champ.
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {});
                            },
                            splashRadius: 14,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: isDark
                                  ? const Color(0xFF8FA0BC)
                                  : AppTheme.muted,
                            ),
                          )),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF14233D)
                  : const Color(0xFFF7F8FD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF22304B)
                      : const Color(0xFFE7EAF5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF22304B)
                      : const Color(0xFFE7EAF5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: const BorderSide(
                  color: Color(0xFF234A84),
                  width: 1,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final results = options.toList(growable: false);
        if (results.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: widget.panelWidth,
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 360),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1B31) : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF22304B)
                      : const Color(0xFFE5E8F5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x33040A16)
                        : const Color(0x160F172A),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isDark
                      ? const Color(0xFF22304B)
                      : const Color(0xFFE9EEF9),
                ),
                itemBuilder: (context, index) {
                  final entry = results[index];
                  return InkWell(
                    onTap: () => onSelected(entry),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // L'icône donne un repère immédiat sur le module cible.
                          Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF14233D)
                                  : const Color(0xFFF4F7FF),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                            ),
                            child: Icon(
                              _iconForModule(entry.module),
                              size: 13,
                              color: isDark
                                  ? const Color(0xFFD7E3FA)
                                  : const Color(0xFF234A84),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Le titre reste prioritaire, le sous-texte précise le contexte fonctionnel.
                                Text(
                                  entry.title.tr(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFF2F6FF)
                                        : AppTheme.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.subtitle.tr(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF8FA0BC)
                                        : AppTheme.muted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            // La pastille rappelle dans quelle grande section se trouve l'entrée.
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF162742)
                                  : const Color(0xFFEFF5FF),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                            ),
                            child: Text(
                              entry.section,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFD7E3FA)
                                    : const Color(0xFF234A84),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sélecteur de thème affiché sous forme de pill.
class _ThemeModePill extends StatelessWidget {
  const _ThemeModePill({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDarkMode = themeMode == ThemeMode.dark;
    final nextMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    final tooltip = isDarkMode
        ? context.tr('Passer en mode clair')
        : context.tr('Passer en mode sombre');
    final icon = isDarkMode
        ? Icons.dark_mode_rounded
        : Icons.light_mode_rounded;
    final iconColor = isDarkMode
        ? const Color(0xFFF4F7FF)
        : const Color(0xFF234A84);
    final backgroundColor = isDark
        ? const Color(0xFF14233D)
        : const Color(0xFFF7F8FD);
    final borderColor = isDark
        ? const Color(0xFF22304B)
        : const Color(0xFFE7EAF5);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 2),
      preferBelow: false,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onThemeModeChanged(nextMode),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 28,
            height: 16,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.88,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  icon,
                  key: ValueKey<bool>(isDarkMode),
                  size: 8,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de langue compact affiché dans la top bar.
class _PortfolioCurrencyPicker extends StatelessWidget {
  const _PortfolioCurrencyPicker({required this.selectedCurrencyListenable});

  final ValueNotifier<String> selectedCurrencyListenable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: selectedCurrencyListenable,
      builder: (context, selectedCurrency, _) {
        return PopupMenuButton<String>(
          tooltip: context.tr("Devise par défaut de l'application"),
          onSelected: (value) {
            if (value == selectedCurrency) return;
            selectedCurrencyListenable.value = value;
          },
          offset: const Offset(0, 38),
          color: isDark ? const Color(0xFF14233D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'XOF',
              height: 40,
              child: Text(context.tr('XOF - FCFA BCEAO')),
            ),
            PopupMenuItem<String>(
              value: 'XAF',
              height: 40,
              child: Text(context.tr('XAF - FCFA BEAC')),
            ),
            PopupMenuItem<String>(
              value: 'EUR',
              height: 40,
              child: Text(context.tr('EUR - Euro')),
            ),
            PopupMenuItem<String>(
              value: 'USD',
              height: 40,
              child: Text(context.tr('USD - Dollar americain')),
            ),
          ],
          child: Tooltip(
            message: context.tr("Devise par défaut de l'application"),
            waitDuration: const Duration(milliseconds: 220),
            showDuration: const Duration(seconds: 2),
            preferBelow: false,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            child: Container(
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF14233D)
                    : const Color(0xFFF7F8FD),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF22304B)
                      : const Color(0xFFE7EAF5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.currency_exchange_rounded,
                    size: 8,
                    color: isDark ? const Color(0xFFD7E3FA) : AppTheme.muted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    selectedCurrency.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
                      fontSize: 8.2,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 9,
                    color: isDark ? const Color(0xFFD7E3FA) : AppTheme.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sélecteur de langue compact affiché dans la top bar.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.appLanguage});

  final ValueNotifier<AppLanguage> appLanguage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, selectedLanguage, _) {
        return PopupMenuButton<AppLanguage>(
          tooltip: context.tr('Langue'),
          onSelected: (value) => appLanguage.value = value,
          offset: const Offset(0, 38),
          color: isDark ? const Color(0xFF14233D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          itemBuilder: (context) => [
            _buildLanguageMenuItem(
              language: AppLanguage.francais,
              isDark: isDark,
            ),
            _buildLanguageMenuItem(
              language: AppLanguage.anglais,
              isDark: isDark,
            ),
          ],
          child: Tooltip(
            message: selectedLanguage == AppLanguage.francais
                ? context.tr('Français')
                : context.tr('Anglais'),
            waitDuration: const Duration(milliseconds: 220),
            showDuration: const Duration(seconds: 2),
            preferBelow: false,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            child: Container(
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF14233D)
                    : const Color(0xFFF7F8FD),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF22304B)
                      : const Color(0xFFE7EAF5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LanguageFlag(
                    language: selectedLanguage,
                    width: 16,
                    height: 12,
                    showBorder: false,
                    radius: AppTheme.radius - 0.5,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    selectedLanguage.shortLabel,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
                      fontSize: 8.6,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 9,
                    color: isDark ? const Color(0xFFD7E3FA) : AppTheme.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<AppLanguage> _buildLanguageMenuItem({
    required AppLanguage language,
    required bool isDark,
  }) {
    return PopupMenuItem<AppLanguage>(
      value: language,
      height: 36,
      child: Row(
        children: [
          _LanguageFlag(language: language, width: 20, height: 14),
          const SizedBox(width: 8),
          Text(
            language.shortLabel,
            style: TextStyle(
              color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageFlag extends StatelessWidget {
  const _LanguageFlag({
    required this.language,
    required this.width,
    required this.height,
    this.showBorder = true,
    this.radius = 2,
  });

  final AppLanguage language;
  final double width;
  final double height;
  final bool showBorder;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showBorder
                ? Border.all(color: const Color(0xFFD7DFEE), width: 0.8)
                : null,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: switch (language) {
            AppLanguage.francais => CustomPaint(painter: _FrenchFlagPainter()),
            AppLanguage.anglais => CustomPaint(painter: _UnionJackPainter()),
          },
        ),
      ),
    );
  }
}

class _FrenchFlagPainter extends CustomPainter {
  const _FrenchFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripeWidth = size.width / 3;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, stripeWidth, size.height),
      Paint()..color = const Color(0xFF123A73),
    );
    canvas.drawRect(
      Rect.fromLTWH(stripeWidth, 0, stripeWidth, size.height),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(stripeWidth * 2, 0, stripeWidth, size.height),
      Paint()..color = const Color(0xFFD90F2D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnionJackPainter extends CustomPainter {
  const _UnionJackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF15357A);
    canvas.drawRect(Offset.zero & size, background);

    final whiteWide = size.height * 0.34;
    final redWide = size.height * 0.18;
    final whiteCrossWide = size.height * 0.42;
    final redCrossWide = size.height * 0.22;

    final whiteDiagonal = Paint()
      ..color = Colors.white
      ..strokeWidth = whiteWide
      ..strokeCap = StrokeCap.square;
    final redDiagonal = Paint()
      ..color = const Color(0xFFD90F2D)
      ..strokeWidth = redWide
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      whiteDiagonal,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      whiteDiagonal,
    );
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      redDiagonal,
    );
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), redDiagonal);

    final whiteCross = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: whiteCrossWide,
      ),
      whiteCross,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: whiteCrossWide,
        height: size.height,
      ),
      whiteCross,
    );

    final redCross = Paint()..color = const Color(0xFFD90F2D);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: redCrossWide,
      ),
      redCross,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: redCrossWide,
        height: size.height,
      ),
      redCross,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bouton secondaire au style discret pour la top bar.
class _HeaderGhostButton extends StatelessWidget {
  const _HeaderGhostButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF8FA0BC) : AppTheme.muted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFFD7E0F3) : const Color(0xFF4B556B),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal de la top bar pour l'action mise en avant.
class _HeaderPrimaryButton extends StatelessWidget {
  const _HeaderPrimaryButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B5CFF), Color(0xFF8A68FF)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x226C5CFD),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Structure globale de la barre supérieure.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.selectedModule, required this.showMenuButton});

  final AppModule selectedModule;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B31) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          Icon(_iconForModule(selectedModule), color: const Color(0xFF6C5CFD)),
          const SizedBox(width: AppTheme.spacing),
          Text(
            selectedModule.title.tr(context),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1E2337),
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_none_rounded, color: AppTheme.muted),
          const SizedBox(width: AppTheme.spacing),
          const Icon(Icons.search_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}
