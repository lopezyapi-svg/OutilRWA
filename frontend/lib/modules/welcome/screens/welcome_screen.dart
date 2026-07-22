import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/desktop_asset_image.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onOpenHome,
  });

  final VoidCallback onOpenHome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF081124) : const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          _WelcomeBackdrop(isDark: isDark),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth < 760 ? 14.0 : 24.0;
                final verticalPadding =
                    constraints.maxHeight < 720 ? 12.0 : 22.0;
                final availableWidth = math.max(
                  1.0,
                  constraints.maxWidth - horizontalPadding * 2,
                );
                final availableHeight = math.max(
                  1.0,
                  constraints.maxHeight - verticalPadding * 2,
                );
                final desktopLayout = availableWidth >= 980;
                final designWidth = desktopLayout
                    ? math.min(1240.0, availableWidth)
                    : math.min(760.0, availableWidth);
                final designHeight = desktopLayout ? 600.0 : 1052.0;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: availableWidth,
                      height: availableHeight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: designWidth,
                          height: designHeight,
                          child: _WelcomeMainArea(
                            isDark: isDark,
                            onOpenHome: onOpenHome,
                          ),
                        ),
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
}

class _WelcomeMainArea extends StatelessWidget {
  const _WelcomeMainArea({
    required this.isDark,
    required this.onOpenHome,
  });

  final bool isDark;
  final VoidCallback onOpenHome;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final content = _WelcomeContent(
          isDark: isDark,
          onOpenHome: onOpenHome,
        );
        final insightCard = _WelcomeInsightCarousel(isDark: isDark);

        if (stacked) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 650, child: content),
              const SizedBox(height: 5),
              SizedBox(height: 384, child: insightCard),
            ],
          );
        }

        const desktopCardHeight = 600.0;

        return Stack(
          children: [
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: SizedBox(height: desktopCardHeight, child: content),
                  ),
                  Expanded(
                    flex: 3,
                    child:
                        SizedBox(height: desktopCardHeight, child: insightCard),
                  ),
                ],
              ),
            ),
            Positioned(
              left: constraints.maxWidth * 0.7 - 9,
              top: 0,
              bottom: 0,
              width: 18,
              child: const _WelcomeCardSeparator(),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeCardSeparator extends StatelessWidget {
  const _WelcomeCardSeparator();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _WelcomeCardSeparatorPainter(
        color: Color(0xFF123A73),
      ),
    );
  }
}

class _WelcomeCardSeparatorPainter extends CustomPainter {
  const _WelcomeCardSeparatorPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    const top = 48.0;
    final bottom = size.height - 48.0;
    final linePaint = Paint()
      ..isAntiAlias = true
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(centerX, top), Offset(centerX, bottom), linePaint);

    for (final y in [top, bottom]) {
      canvas.drawCircle(
        Offset(centerX, y),
        7.2,
        Paint()
          ..isAntiAlias = true
          ..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(centerX, y),
        7.2,
        Paint()
          ..isAntiAlias = true
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        Offset(centerX, y),
        2.6,
        Paint()
          ..isAntiAlias = true
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeCardSeparatorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.isDark,
    required this.onOpenHome,
  });

  final bool isDark;
  final VoidCallback onOpenHome;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final mark = _WelcomeMark(isDark: isDark, compact: compact);
        final copy = _WelcomeCopy(isDark: isDark, onOpenHome: onOpenHome);
        final topContent = compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  mark,
                  const SizedBox(height: 6),
                  copy,
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: mark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(flex: 6, child: copy),
                ],
              );

        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact ? 650 : 560,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1B31).withValues(alpha: 0.86)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x33030A16)
                      : const Color(0x12132942),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 28 : 46,
                vertical: compact ? 34 : 42,
              ),
              child: Column(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  topContent,
                  if (compact) const SizedBox(height: 6) else const Spacer(),
                  _WelcomeBrandInsideCard(isDark: isDark, compact: compact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeMark extends StatelessWidget {
  const _WelcomeMark({
    required this.isDark,
    required this.compact,
  });

  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 176.0 : 232.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(compact ? 14 : 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132642) : const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: const DesktopAssetImage(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Risk management',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: isDark ? const Color(0xFFEAF1FF) : const Color(0xFF123A73),
            fontSize: compact ? 24 : 28,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Outil de pilotage des fonds propres',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: isDark ? const Color(0xFF9FB2D6) : const Color(0xFF365F9A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({
    required this.isDark,
    required this.onOpenHome,
  });

  final bool isDark;
  final VoidCallback onOpenHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 3,
          width: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Bienvenue dans votre espace de pilotage prudentiel',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(
            color: isDark ? const Color(0xFFF2F6FF) : const Color(0xFF13203A),
            fontSize: 34,
            fontWeight: FontWeight.w600,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Une interface conçue pour suivre les RWA, le capital minimum et les indicateurs clés avec une lecture claire, fiable et professionnelle.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(
            color: isDark ? const Color(0xFFD3DCEE) : const Color(0xFF45546E),
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 6),
        _OpenHomeButton(onPressed: onOpenHome),
      ],
    );
  }
}

class _WelcomeInsightMessage {
  const _WelcomeInsightMessage({
    required this.label,
    required this.title,
    required this.body,
    required this.color,
  });

  final String label;
  final String title;
  final String body;
  final Color color;
}

const List<_WelcomeInsightMessage> _welcomeInsightMessages = [
  _WelcomeInsightMessage(
    label: 'Définition clé',
    title: 'Risque de crédit',
    body:
        "Le risque de crédit est le risque résultant de l'incertitude quant à la capacité ou la volonté d'une contrepartie de remplir ses obligations : il se matérialise lorsque le client ou la contrepartie ne respecte pas ses obligations financières, c'est-à-dire le défaut, ou plus généralement lorsque la qualité de crédit de cette contrepartie se détériore, même sans défaut avéré.",
    color: Color(0xFF2563EB),
  ),
  _WelcomeInsightMessage(
    label: 'Définition clé',
    title: 'Risque de marché',
    body:
        "Le risque de marché est le risque de pertes sur les positions du bilan et du hors bilan à la suite des variations des prix de marché : il recouvre le risque relatif aux instruments liés aux taux d'intérêt et aux titres de propriété du portefeuille de négociation, ainsi que le risque de change et le risque sur produits de base encourus sur l'ensemble du bilan et du hors bilan.",
    color: Color(0xFF0EA5E9),
  ),
  _WelcomeInsightMessage(
    label: 'Définition clé',
    title: 'Risque opérationnel',
    body:
        'Le risque opérationnel est le risque de pertes résultant de carences ou de défaillances attribuables à des procédures, au personnel et aux systèmes internes, ou à des événements extérieurs : il inclut le risque juridique, mais exclut le risque stratégique et le risque de réputation.',
    color: Color(0xFF10B981),
  ),
  _WelcomeInsightMessage(
    label: 'Définition clé',
    title: 'RWA',
    body:
        'Les actifs pondérés des risques, en anglais Risk Weighted Assets (RWA), correspondent à la somme des expositions au bilan et hors bilan, pondérées selon leur niveau de risque, au titre du risque de crédit, du risque de marché et du risque opérationnel.',
    color: Color(0xFF123A73),
  ),
  _WelcomeInsightMessage(
    label: 'Définition clé',
    title: 'Ratio de solvabilité',
    body:
        "Le ratio de solvabilité est le rapport entre les fonds propres d'un établissement et ses actifs pondérés des risques : il mesure sa capacité à absorber les pertes, avec un minimum réglementaire de 8 %, porté à 10,5 % avec le coussin de conservation.",
    color: Color(0xFF7C3AED),
  ),
];

class _WelcomeInsightCarousel extends StatefulWidget {
  const _WelcomeInsightCarousel({required this.isDark});

  final bool isDark;

  @override
  State<_WelcomeInsightCarousel> createState() =>
      _WelcomeInsightCarouselState();
}

class _WelcomeInsightCarouselState extends State<_WelcomeInsightCarousel> {
  int _index = 0;
  bool _paused = false;

  void _handleMessageCycleComplete() {
    if (!mounted) return;
    setState(() {
      _index = (_index + 1) % _welcomeInsightMessages.length;
    });
  }

  void _setPaused(bool value) {
    if (_paused == value) return;
    setState(() => _paused = value);
  }

  @override
  Widget build(BuildContext context) {
    final message = _welcomeInsightMessages[_index];
    final textColor =
        widget.isDark ? const Color(0xFFEAF1FF) : const Color(0xFF13203A);
    final mutedColor =
        widget.isDark ? const Color(0xFFAAB8D2) : const Color(0xFF5B6A84);
    return SizedBox(
      width: double.infinity,
      child: MouseRegion(
        onEnter: (_) => _setPaused(true),
        onExit: (_) => _setPaused(false),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF111F37).withValues(alpha: 0.82)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: widget.isDark
                    ? const Color(0x44030A16)
                    : const Color(0x17132942),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Essentiels métier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 280,
                child: _WelcomeInsightMessageView(
                  key: ValueKey(_index),
                  message: message,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  paused: _paused,
                  onCycleComplete: _handleMessageCycleComplete,
                ),
              ),
              const Spacer(),
              const _WelcomeBrandAdStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeInsightMessageView extends StatefulWidget {
  const _WelcomeInsightMessageView({
    super.key,
    required this.message,
    required this.textColor,
    required this.mutedColor,
    required this.paused,
    required this.onCycleComplete,
  });

  final _WelcomeInsightMessage message;
  final Color textColor;
  final Color mutedColor;
  final bool paused;
  final VoidCallback onCycleComplete;

  @override
  State<_WelcomeInsightMessageView> createState() =>
      _WelcomeInsightMessageViewState();
}

class _WelcomeInsightMessageViewState extends State<_WelcomeInsightMessageView>
    with SingleTickerProviderStateMixin {
  static const _typewriterStepDuration = Duration(milliseconds: 46);
  static const _messageHoldDuration = Duration(milliseconds: 3400);

  late final AnimationController _cursorController;
  Timer? _textTimer;
  Timer? _holdTimer;
  int _visibleCharacters = 0;
  bool _erasing = false;

  int get _totalCharacters =>
      widget.message.title.length + widget.message.body.length;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..repeat();
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant _WelcomeInsightMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _startTyping();
    } else if (!oldWidget.paused && widget.paused) {
      _pauseCycle();
    } else if (oldWidget.paused && !widget.paused) {
      _resumeCycle();
    }
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _holdTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  void _startTyping() {
    _textTimer?.cancel();
    _holdTimer?.cancel();
    setState(() {
      _erasing = false;
      _visibleCharacters = 0;
    });
    if (widget.paused) return;
    _continueTyping();
  }

  void _continueTyping() {
    _textTimer?.cancel();
    _textTimer = Timer.periodic(_typewriterStepDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (widget.paused) {
        timer.cancel();
        return;
      }
      if (_visibleCharacters >= _totalCharacters) {
        timer.cancel();
        _scheduleErasing();
        return;
      }
      setState(() => _visibleCharacters += 1);
    });
  }

  void _scheduleErasing() {
    _holdTimer?.cancel();
    if (!mounted || widget.paused) return;

    _holdTimer = Timer(_messageHoldDuration, () {
      if (!mounted || widget.paused) return;
      _startErasing();
    });
  }

  void _pauseCycle() {
    _textTimer?.cancel();
    _holdTimer?.cancel();
    _textTimer = null;
    _holdTimer = null;
  }

  void _resumeCycle() {
    if (_erasing) {
      _startErasing();
    } else if (_visibleCharacters >= _totalCharacters) {
      _scheduleErasing();
    } else {
      _continueTyping();
    }
  }

  void _startErasing() {
    _textTimer?.cancel();
    _holdTimer?.cancel();

    if (_visibleCharacters <= 0) {
      Future<void>.microtask(() {
        if (mounted) widget.onCycleComplete();
      });
      return;
    }

    setState(() => _erasing = true);
    if (widget.paused) return;
    _textTimer = Timer.periodic(_typewriterStepDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (widget.paused) {
        timer.cancel();
        return;
      }
      if (_visibleCharacters <= 0) {
        timer.cancel();
        widget.onCycleComplete();
        return;
      }
      setState(() => _visibleCharacters -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cursorController,
      builder: (context, _) {
        final visibleCharacters = math.min(
          _totalCharacters,
          math.max(0, _visibleCharacters),
        );
        final titleCharacters = math.min(
          widget.message.title.length,
          visibleCharacters,
        );
        final bodyCharacters = math.max(
          0,
          math.min(
            widget.message.body.length,
            visibleCharacters - widget.message.title.length,
          ),
        );
        final showBodyCursor = bodyCharacters > 0 ||
            (!_erasing && visibleCharacters >= widget.message.title.length);
        final showTitleCursor = !showBodyCursor;
        final cursorVisible = _cursorController.value < 0.56;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: widget.message.color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: 0.18,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 64,
              child: Align(
                alignment: Alignment.topLeft,
                child: _WelcomeTypedText(
                  text: widget.message.title.substring(0, titleCharacters),
                  showCursor: showTitleCursor && cursorVisible,
                  cursorColor: widget.message.color,
                  color: widget.textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.08,
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: _WelcomeTypedText(
                  text: widget.message.body.substring(0, bodyCharacters),
                  showCursor: showBodyCursor && cursorVisible,
                  cursorColor: widget.message.color,
                  color: const Color(0xFF123A73),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.36,
                  maxLines: 10,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeTypedText extends StatelessWidget {
  const _WelcomeTypedText({
    required this.text,
    required this.showCursor,
    required this.cursorColor,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    required this.height,
    required this.maxLines,
  });

  final String text;
  final bool showCursor;
  final Color cursorColor;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final double height;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          TextSpan(
            text: showCursor ? '|' : '',
            style: TextStyle(
              color: cursorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
      ),
    );
  }
}

class _OpenHomeButton extends StatelessWidget {
  const _OpenHomeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(CupertinoIcons.square_grid_2x2_fill, size: 17),
        label: const Text('Accéder à l’accueil'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF123A73),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WelcomeBrandInsideCard extends StatelessWidget {
  const _WelcomeBrandInsideCard({
    required this.isDark,
    required this.compact,
  });

  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFF9FB2D6) : const Color(0xFF52647F);
    final year = DateTime.now().year;

    return Transform.translate(
      offset: Offset(compact ? 24 : 68, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "© $year Heymann's Inc. Tous droits réservés.",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFFE2EAFE) : const Color(0xFF314765),
              fontSize: compact ? 10.8 : 11.6,
              fontWeight: FontWeight.w500,
              height: 1.18,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            'Propriété et confidentialité',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10.4 : 11.1,
              fontWeight: FontWeight.w500,
              height: 1.28,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            'Toute reproduction ou diffusion non autorisée est interdite.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withValues(alpha: 0.82),
              fontSize: compact ? 9.6 : 10.0,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBrandAdStrip extends StatelessWidget {
  const _WelcomeBrandAdStrip();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFDDE7FA) : const Color(0xFF314765);
    final mutedColor =
        isDark ? const Color(0xFF9FB2D6) : const Color(0xFF64748B);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF15243D).withValues(alpha: 0.72)
            : const Color(0xFFF6F9FD),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 30,
            child: ClipRect(
              child: Transform.scale(
                scale: 1.34,
                child: const DesktopAssetImage(
                  'assets/images/heymanns_logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 28,
            color: isDark ? const Color(0xFF2E466C) : const Color(0xFFD8E5F7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Heymann's Inc.",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Leader de l'ALM et du Risk management en Afrique subsaharienne",
                  maxLines: 3,
                  overflow: TextOverflow.clip,
                  softWrap: true,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 9.0,
                    fontWeight: FontWeight.w500,
                    height: 1.16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF081124),
                  Color(0xFF0D1830),
                  Color(0xFF101D35),
                ]
              : const [
                  Color(0xFFF7FAFF),
                  Color(0xFFEFF4FA),
                  Color(0xFFF8FAFC),
                ],
        ),
      ),
      child: CustomPaint(
        painter: _WelcomeBackdropPainter(isDark: isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WelcomeBackdropPainter extends CustomPainter {
  const _WelcomeBackdropPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark ? const Color(0x102B426A) : const Color(0x1695A3B8)
      ..strokeWidth = 1;
    const gridStep = 54.0;
    for (var x = 0.0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final bandPaint = Paint()
      ..color = isDark ? const Color(0x162563EB) : const Color(0x132563EB)
      ..style = PaintingStyle.fill;
    final band = Path()
      ..moveTo(size.width * 0.66, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.86, size.height)
      ..close();
    canvas.drawPath(band, bandPaint);

    final linePaint = Paint()
      ..color = isDark ? const Color(0x202563EB) : const Color(0x24365F9A)
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(0, size.height * 0.22),
      Offset(size.width, size.height * 0.22),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WelcomeBackdropPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
