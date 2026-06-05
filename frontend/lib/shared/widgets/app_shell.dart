// Ce fichier structure le layout principal de l'application.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_module.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_conversion.dart';
import 'desktop_asset_image.dart';
import 'sidebar_navigation.dart';

const double _sidebarToggleButtonWidth = 28;
const double _sidebarToggleButtonHeight = 28;
const double _sidebarToggleHitArea = 42;
const double _sidebarToggleButtonRadius = 6;
const double _desktopPanelGap = AppTheme.pageGap;
const double _desktopRailWidth = 54;
const double _desktopOverlayWidth = 220;
const double _workspaceTopBarControlHeight = 24;
const double _workspaceTopBarControlRadius = 2;
const Duration _desktopSidebarOpenDuration = Duration(milliseconds: 60);
const Duration _desktopSidebarCloseDuration = Duration(milliseconds: 60);

/// Coquille principale de l'application avec top bar, sidebar et contenu.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.selectedModule,
    required this.onSelectModule,
    required this.onReturnToWelcome,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.portfolioDisplayCurrency,
    required this.appLanguage,
    required this.child,
  });

  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final VoidCallback onReturnToWelcome;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<AppLanguage> appLanguage;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Etat interne qui pilote la sidebar et la top bar.
class _AppShellState extends State<AppShell> {
  static const double _screenSpacing = AppTheme.pagePadding;
  bool _isSidebarOverlayOpen = false;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF091224) : const Color(0xFFEAE9F8),
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
                  // La top bar concentre la marque et les actions globales.
                  _WorkspaceTopBar(
                    themeMode: widget.themeMode,
                    onThemeModeChanged: widget.onThemeModeChanged,
                    selectedModule: widget.selectedModule,
                    onReturnToWelcome: widget.onReturnToWelcome,
                    portfolioDisplayCurrency: widget.portfolioDisplayCurrency,
                    appLanguage: widget.appLanguage,
                  ),
                  const SizedBox(height: AppTheme.pageGap),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            end: _isSidebarOverlayOpen ? 1 : 0,
                          ),
                          duration: _isSidebarOverlayOpen
                              ? _desktopSidebarOpenDuration
                              : _desktopSidebarCloseDuration,
                          curve: _isSidebarOverlayOpen
                              ? Curves.easeOutQuart
                              : Curves.easeInQuart,
                          builder: (context, progress, _) {
                            final sidebarWidth = _desktopRailWidth +
                                (_desktopOverlayWidth - _desktopRailWidth) *
                                    progress;
                            final showCompact =
                                !_isSidebarOverlayOpen && progress <= 0.001;
                            return SizedBox(
                              width: sidebarWidth,
                              child: RepaintBoundary(
                                child: ClipRect(
                                  child: showCompact
                                      ? _DesktopSidebarFrame(
                                          compact: true,
                                          width: _desktopRailWidth,
                                          selectedModule: widget.selectedModule,
                                          onSelectModule:
                                              _handleDesktopModuleSelection,
                                          showBrand: false,
                                          showToggleButton: true,
                                          onToggleSidebar:
                                              _toggleDesktopSidebarOverlay,
                                        )
                                      : IgnorePointer(
                                          ignoring: progress < 0.98,
                                          child: OverflowBox(
                                            alignment: Alignment.centerLeft,
                                            minWidth: _desktopOverlayWidth,
                                            maxWidth: _desktopOverlayWidth,
                                            child: SizedBox(
                                              width: _desktopOverlayWidth,
                                              child: _DesktopSidebarFrame(
                                                compact: false,
                                                width: _desktopOverlayWidth,
                                                selectedModule:
                                                    widget.selectedModule,
                                                onSelectModule:
                                                    _handleDesktopModuleSelection,
                                                showBrand: false,
                                                showToggleButton: true,
                                                onToggleSidebar:
                                                    _toggleDesktopSidebarOverlay,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: _desktopPanelGap),
                        Expanded(
                          child: RepaintBoundary(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F1B31)
                                        .withValues(alpha: 0.92)
                                    : Colors.white.withValues(alpha: 0.80),
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
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
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

  void _toggleDesktopSidebarOverlay() {
    setState(() => _isSidebarOverlayOpen = !_isSidebarOverlayOpen);
  }

  void _handleDesktopModuleSelection(AppModule module) {
    if (module == AppModule.risqueMarcheImport) {
      widget.onSelectModule(module);
      return;
    }
    if (module == widget.selectedModule) {
      return;
    }
    widget.onSelectModule(module);
  }

  Widget _buildMobileShell() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF091224) : const Color(0xFFF0F2F8),
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
                onReturnToWelcome: widget.onReturnToWelcome,
              ),
              const SizedBox(height: AppTheme.pageGap),
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

/// Fond analytique discret affiché derrière l'espace de travail.
class _DecorativeBackdrop extends StatelessWidget {
  const _DecorativeBackdrop({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [Color(0xFF091224), Color(0xFF0B1630), Color(0xFF0F1B31)]
        : const [Color(0xFFF3F6FB), Color(0xFFEAF0F8), Color(0xFFF8FAFC)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _WorkspaceBackdropPainter(dark: dark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WorkspaceBackdropPainter extends CustomPainter {
  const _WorkspaceBackdropPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = dark ? const Color(0x142C4166) : const Color(0x1A9BA8BD)
      ..strokeWidth = 1;
    const gridStep = 48.0;
    for (var x = 0.0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final bandPaint = Paint()
      ..color = dark ? const Color(0x102563EB) : const Color(0x102563EB)
      ..style = PaintingStyle.fill;
    final bandPath = Path()
      ..moveTo(size.width * 0.52, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.82, size.height)
      ..close();
    canvas.drawPath(bandPath, bandPaint);

    final baselinePaint = Paint()
      ..color = dark ? const Color(0x242563EB) : const Color(0x24365F9A)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(0, size.height * 0.18),
      Offset(size.width, size.height * 0.18),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WorkspaceBackdropPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}

IconData _iconForModule(AppModule module) {
  return module.icon;
}

/// Barre supérieure de l'espace de travail.
class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.selectedModule,
    required this.onReturnToWelcome,
    required this.portfolioDisplayCurrency,
    required this.appLanguage,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final AppModule selectedModule;
  final VoidCallback onReturnToWelcome;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<AppLanguage> appLanguage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 66,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1B31).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(2),
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
          final showHeaderStatus = constraints.maxWidth >= 1080;

          return Row(
            children: [
              // La marque reste à gauche pour ancrer la lecture de l'application.
              const _ShellBrand(),
              const Spacer(),
              _HeaderIconButton(
                icon: CupertinoIcons.circle_grid_3x3_fill,
                accent: const Color(0xFF2563EB),
                onPressed: onReturnToWelcome,
              ),
              const SizedBox(width: 6),
              if (showHeaderStatus) ...[
                const _HeaderIconButton(
                  icon: CupertinoIcons.bell_fill,
                  accent: Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
              ],
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
                  icon: CupertinoIcons.arrow_down_doc_fill,
                ),
                const SizedBox(width: 6),
                _HeaderPrimaryButton(
                  label: context.tr('Nouvelle analyse'),
                  icon: CupertinoIcons.plus,
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
          width: 46,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14233D)
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.14)
                    : const Color(0xFF234A84).withValues(alpha: 0.055),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const DesktopAssetImage(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Risk management'),
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFC9D6FF) : const Color(0xFF123A73),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 0.1),
            Text(
              context.tr('Outil de pilotage des fonds propres'),
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF8FA0BC) : const Color(0xFF365F9A),
                fontSize: 10.2,
                fontWeight: FontWeight.w500,
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
    required this.compact,
    required this.width,
    required this.selectedModule,
    required this.onSelectModule,
    this.showBrand = false,
    this.showToggleButton = false,
    this.onToggleSidebar,
  });

  final bool compact;
  final double width;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final bool showBrand;
  final bool showToggleButton;
  final VoidCallback? onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        child: ClipRect(
          child: SidebarNavigation(
            selectedModule: selectedModule,
            onSelectModule: onSelectModule,
            compact: compact,
            showBrand: showBrand,
            contentTopInset: 0,
            headerTrailing: showToggleButton && onToggleSidebar != null
                ? _SidebarToggleButton(
                    compact: compact,
                    onTap: onToggleSidebar!,
                  )
                : null,
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

    return TooltipVisibility(
      visible: compact,
      child: SizedBox(
        width: _sidebarToggleHitArea,
        height: _sidebarToggleHitArea,
        child: Tooltip(
          message: 'Ouvrir le menu',
          waitDuration: const Duration(milliseconds: 160),
          showDuration: const Duration(milliseconds: 1500),
          preferBelow: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF102A55),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFF2F5D9F)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A0F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.05,
          ),
          child: Center(
            child: Material(
              color: isDark ? const Color(0xFF14233D) : Colors.white,
              borderRadius: BorderRadius.circular(_sidebarToggleButtonRadius),
              elevation: 3,
              shadowColor:
                  isDark ? const Color(0x33040A16) : const Color(0x150F172A),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                  _sidebarToggleButtonRadius,
                ),
                child: Container(
                  width: _sidebarToggleButtonWidth,
                  height: _sidebarToggleButtonHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      _sidebarToggleButtonRadius,
                    ),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A3C5E)
                          : const Color(0xFFD9E4F6),
                    ),
                  ),
                  child: Icon(
                    compact
                        ? CupertinoIcons.chevron_right
                        : CupertinoIcons.chevron_left,
                    color: isDark
                        ? const Color(0xFFD7E3FA)
                        : const Color(0xFF47619C),
                    size: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
    final icon =
        isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded;
    final iconColor =
        isDarkMode ? const Color(0xFFF4F7FF) : const Color(0xFF234A84);
    final backgroundColor =
        isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD);
    final borderColor =
        isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onThemeModeChanged(nextMode),
        borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: _workspaceTopBarControlHeight,
          height: _workspaceTopBarControlHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
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
                size: 13,
                color: iconColor,
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
        final normalizedSelectedCurrency =
            normalizeCurrencyCode(selectedCurrency);
        return PopupMenuButton<String>(
          tooltip: '',
          padding: EdgeInsets.zero,
          onSelected: (value) {
            final normalizedValue = normalizeCurrencyCode(value);
            if (normalizedValue == normalizedSelectedCurrency) return;
            selectedCurrencyListenable.value = normalizedValue;
          },
          offset: const Offset(0, _workspaceTopBarControlHeight + 8),
          color: isDark ? const Color(0xFF14233D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
            side: BorderSide(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'XOF',
              height: 40,
              child: _CurrencyMenuItem(
                currencyCode: 'XOF',
                label: context.tr('XOF - FCFA BCEAO'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'EUR',
              height: 40,
              child: _CurrencyMenuItem(
                currencyCode: 'EUR',
                label: context.tr('EUR - Euro'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'USD',
              height: 40,
              child: _CurrencyMenuItem(
                currencyCode: 'USD',
                label: context.tr('USD - Dollar americain'),
              ),
            ),
          ],
          child: Container(
            height: _workspaceTopBarControlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD),
              borderRadius:
                  BorderRadius.circular(_workspaceTopBarControlRadius),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CurrencyBadge(
                  currencyCode: normalizedSelectedCurrency,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  normalizedSelectedCurrency,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
                    fontSize: 9.8,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 12,
                  color: isDark ? const Color(0xFFD7E3FA) : AppTheme.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyMenuItem extends StatelessWidget {
  const _CurrencyMenuItem({
    required this.currencyCode,
    required this.label,
  });

  final String currencyCode;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _CurrencyBadge(currencyCode: currencyCode, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({
    required this.currencyCode,
    this.size = 16,
  });

  final String currencyCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeCurrencyCode(currencyCode);
    final symbol = switch (normalized) {
      'XOF' => 'CFA',
      'EUR' => '€',
      'USD' => r'$',
      _ => normalized.length <= 3 ? normalized : normalized.substring(0, 3),
    };
    final color = switch (normalized) {
      'XOF' => const Color(0xFF06B6D4),
      'EUR' => const Color(0xFF2563EB),
      'USD' => const Color(0xFF10B981),
      _ => AppTheme.muted,
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        symbol,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: symbol.length > 1 ? size * 0.34 : size * 0.62,
          fontWeight: FontWeight.w500,
          height: 1,
          letterSpacing: 0,
        ),
      ),
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
          tooltip: '',
          padding: EdgeInsets.zero,
          onSelected: (value) => appLanguage.value = value,
          offset: const Offset(0, _workspaceTopBarControlHeight + 8),
          color: isDark ? const Color(0xFF14233D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
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
          child: Container(
            height: _workspaceTopBarControlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD),
              borderRadius:
                  BorderRadius.circular(_workspaceTopBarControlRadius),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
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
                  radius: _workspaceTopBarControlRadius,
                ),
                const SizedBox(width: 5),
                Text(
                  selectedLanguage.shortLabel,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
                    fontSize: 9.8,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 12,
                  color: isDark ? const Color(0xFFD7E3FA) : AppTheme.muted,
                ),
              ],
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
              fontWeight: FontWeight.w500,
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
            AppLanguage.francais =>
              const CustomPaint(painter: _FrenchFlagPainter()),
            AppLanguage.anglais =>
              const CustomPaint(painter: _UnionJackPainter()),
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.accent,
    this.onPressed,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
        child: Container(
          width: _workspaceTopBarControlHeight,
          height: _workspaceTopBarControlHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD),
            borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
            border: Border.all(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          child: Icon(icon, size: 13, color: accent),
        ),
      ),
    );
  }
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
              fontWeight: FontWeight.w500,
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
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x222563EB),
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Structure globale de la barre supérieure.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.selectedModule,
    required this.showMenuButton,
    required this.onReturnToWelcome,
  });

  final AppModule selectedModule;
  final bool showMenuButton;
  final VoidCallback onReturnToWelcome;

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
          Icon(_iconForModule(selectedModule), color: const Color(0xFF2563EB)),
          const SizedBox(width: AppTheme.spacing),
          Text(
            selectedModule.title.tr(context),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFF2F6FF)
                      : const Color(0xFF1E2337),
                ),
          ),
          const Spacer(),
          _HeaderIconButton(
            icon: CupertinoIcons.circle_grid_3x3_fill,
            accent: const Color(0xFF2563EB),
            onPressed: onReturnToWelcome,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.notifications_none_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}
