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
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 44,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 920,
                            ),
                            child: _WelcomeContent(
                              isDark: isDark,
                              onOpenHome: onOpenHome,
                            ),
                          ),
                        ),
                        const _WelcomeFooter(),
                      ],
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

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.isDark,
    required this.onOpenHome,
  });

  final bool isDark;
  final VoidCallback onOpenHome;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1B31).withValues(alpha: 0.86)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFDDE6F4),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33030A16) : const Color(0x12132942),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 42),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final mark = _WelcomeMark(isDark: isDark, compact: compact);
            final copy = _WelcomeCopy(isDark: isDark, onOpenHome: onOpenHome);

            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  mark,
                  const SizedBox(height: 30),
                  copy,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: mark,
                  ),
                ),
                const SizedBox(width: 42),
                Expanded(flex: 6, child: copy),
              ],
            );
          },
        ),
      ),
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
    final size = compact ? 132.0 : 166.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132642) : const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isDark ? const Color(0xFF2E466C) : const Color(0xFFD8E5F7),
              width: 0.9,
            ),
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
        const SizedBox(height: 18),
        Text(
          'Risk management',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: isDark ? const Color(0xFFEAF1FF) : const Color(0xFF123A73),
            fontSize: compact ? 24 : 28,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Outil de pilotage des fonds propres',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: isDark ? const Color(0xFF9FB2D6) : const Color(0xFF365F9A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
        const SizedBox(height: 18),
        Text(
          'Bienvenue dans votre espace de pilotage prudentiel',
          style: TextStyle(
            color: isDark ? const Color(0xFFF2F6FF) : const Color(0xFF13203A),
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Une interface conçue pour suivre les RWA, le capital minimum et les indicateurs clés avec une lecture claire, fiable et professionnelle.',
          style: TextStyle(
            color: isDark ? const Color(0xFFC0CBE0) : const Color(0xFF53617A),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 30),
        _OpenHomeButton(onPressed: onOpenHome),
      ],
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WelcomeFooter extends StatelessWidget {
  const _WelcomeFooter();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF9FB2D6) : const Color(0xFF52647F);

    return Padding(
      padding: const EdgeInsets.only(top: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 132,
            height: 54,
            child: DesktopAssetImage(
              'assets/images/heymanns_logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Conçu avec soin par Heymann's",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFFE2EAFE) : const Color(0xFF314765),
              fontSize: 11.8,
              fontWeight: FontWeight.w500,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Leader de l'ALM en Afrique subsaharienne",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10.8,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Propriété et confidentialité',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withValues(alpha: 0.82),
              fontSize: 9.8,
              fontWeight: FontWeight.w400,
              height: 1.2,
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
