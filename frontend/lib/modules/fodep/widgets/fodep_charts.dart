import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../modules/dashboard/widgets/dashboard_design.dart';
import '../../../core/theme/app_theme.dart';

/// Formateur de montants en millions (même convention que l'écran FODEP).
String fodepFmtMontant(double v) {
  if (v == 0) return '0';
  final enMillions = v / 1e6;
  final parts = enMillions.toStringAsFixed(2).split('.');
  final entier = parts[0].replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ' ');
  final decimal = parts.length > 1 ? ',${parts[1]}' : '';
  return '$entier$decimal M';
}

/// Ombre douce commune aux panneaux FODEP (fintech épuré).
BoxShadow fodepOmbre(BuildContext context) {
  final sombre = Theme.of(context).brightness == Brightness.dark;
  return BoxShadow(
    color: sombre ? Colors.black.withValues(alpha: 0.45) : const Color(0xFF0F1B2D).withValues(alpha: 0.06),
    blurRadius: sombre ? 30 : 24,
    offset: const Offset(0, 8),
  );
}

/// Panneau graphique fintech : fond surface, coins arrondis, ombre douce,
/// titre en sur-titre précédé d'un trait d'accent navy.
class FodepGraphPanel extends StatelessWidget {
  const FodepGraphPanel({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [fodepOmbre(context)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: c.navy,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 10.5, color: c.muted, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}/// Compteur : affichage direct et fluide de la valeur formatée.
class FodepCompteur extends StatelessWidget {
  const FodepCompteur({
    super.key,
    required this.valeur,
    required this.format,
    this.style,
  });

  final double valeur;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(format(valeur), style: style);
  }
}

/// Pastille de statut compacte (fond teinté discret + libellé en capitales).
class FodepPastilleStatut extends StatelessWidget {
  const FodepPastilleStatut({super.key, required this.couleur, required this.libelle});

  final Color couleur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        libelle.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: couleur,
        ),
      ),
    );
  }
}

/// Jauge radiale (arc 270°) : valeur observée, seuil réglementaire matérialisé
/// par un trait, arc en dégradé, valeur directe et pastille de statut.
class FodepJaugeRadiale extends StatelessWidget {
  const FodepJaugeRadiale({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.seuil,
    required this.conforme,
    this.disponible = true,
    this.suffixe = '%',
  });

  final String libelle;
  final double valeur;
  final double seuil;
  final bool conforme;
  final bool disponible;
  final String suffixe;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final couleur = !disponible
        ? c.faint
        : (conforme ? c.conforme : c.sousMinimum);

    final maxValeur = math.max(valeur * 1.30, seuil * 1.5).clamp(1.0, double.infinity);
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final fraction = disponible ? (valeur / maxValeur).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(160, 160),
                painter: _JaugeRadialePainter(
                  fraction: fraction,
                  seuilFraction: disponible ? (seuil / maxValeur).clamp(0.0, 1.0) : 0,
                  couleur: couleur,
                  fond: sombre ? c.grid : const Color(0xFFE2E8F0),
                  traitSeuil: sombre ? Colors.white : c.navy,
                  eclaircissement: sombre ? 0.12 : 0.28,
                ),
              ),
              Positioned(
                top: 50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FodepCompteur(
                      valeur: disponible ? valeur : 0,
                      format: (v) => disponible ? '${v.toStringAsFixed(2)} $suffixe' : '—',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: disponible ? c.ink : c.faint,
                        height: 1.1,
                        letterSpacing: -0.5,
                        fontFeatures: Dash.tabular,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FodepPastilleStatut(
                      couleur: couleur,
                      libelle: !disponible
                          ? 'Non renseigné'
                          : (conforme ? 'Conforme' : 'Non conforme'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.ink),
        ),
      ],
    );
  }
}

/// Jauge radiale circulaire (semi-donut) style compte-tours automobile / cockpit.
class FodepJaugePrudentielle extends StatelessWidget {
  const FodepJaugePrudentielle({
    super.key,
    required this.titre,
    required this.valeur,
    required this.seuil,
    required this.reference,
    this.suffixe = '%',
    this.conforme = true,
    this.disponible = true,
    this.couleurAlerte,
  });

  final String titre;
  final double valeur;
  final double seuil;
  final String reference;
  final String suffixe;
  final bool conforme;
  final bool disponible;
  final Color? couleurAlerte;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final couleur = couleurAlerte ?? (disponible ? (conforme ? c.conforme : c.sousMinimum) : c.faint);

    // We scale max to be value + 30%, or threshold + 50%, whichever is larger, 
    // so the gauge is never completely full.
    final maxValeur = math.max(valeur * 1.30, seuil * 1.5).clamp(1.0, double.infinity);
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final fraction = disponible ? (valeur / maxValeur).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(160, 160),
                painter: _JaugeRadialePainter(
                  fraction: fraction,
                  seuilFraction: disponible ? (seuil / maxValeur).clamp(0.0, 1.0) : 0,
                  couleur: couleur,
                  fond: sombre ? c.grid : const Color(0xFFE2E8F0),
                  traitSeuil: sombre ? Colors.white : c.navy,
                  eclaircissement: sombre ? 0.12 : 0.28,
                ),
              ),
              Positioned(
                top: 50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FodepCompteur(
                      valeur: disponible ? valeur : 0,
                      format: (v) => disponible ? '${v.toStringAsFixed(2)} $suffixe' : '—',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: disponible ? c.ink : c.faint,
                        height: 1.1,
                        letterSpacing: -0.5,
                        fontFeatures: Dash.tabular,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FodepPastilleStatut(
                      couleur: couleur,
                      libelle: !disponible
                          ? 'Non renseigné'
                          : (conforme ? 'Conforme' : 'Non conforme'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.muted, height: 1.3),
        ),
        Text(
          disponible ? 'Seuil : ${seuil.toStringAsFixed(2)} $suffixe' : '',
          style: TextStyle(fontSize: 10, color: c.faint, height: 1.3),
        ),
      ],
    );
  }
}

class _JaugeRadialePainter extends CustomPainter {
  const _JaugeRadialePainter({
    required this.fraction,
    required this.seuilFraction,
    required this.couleur,
    required this.fond,
    required this.traitSeuil,
    required this.eclaircissement,
  });

  final double fraction;
  final double seuilFraction;
  final Color couleur;
  final Color fond;
  final Color traitSeuil;

  /// Facteur d'éclaircissement du dégradé de l'arc (thème sombre = plus faible).
  final double eclaircissement;

  @override
  void paint(Canvas canvas, Size size) {
    // 240° arc for a more elegant dashboard look
    // Starts at 150° (bottom-left) and sweeps 240° clockwise to 30° (bottom-right)
    final centre = Offset(size.width / 2, size.height / 2 + 10);
    final rayon = size.width / 2 - 16;
    const start = math.pi * 5 / 6;  // 150°
    const sweep = math.pi * 4 / 3;  // 240°

    final rect = Rect.fromCircle(center: centre, radius: rayon);
    
    // Thinner background track
    final peintureFond = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = fond;
      
    // Thicker active arc with a gradient
    final peintureArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [couleur, Color.lerp(couleur, Colors.white, eclaircissement)!],
        transform: const GradientRotation(start),
      ).createShader(rect);

    // Glow effect behind the active arc
    if (fraction > 0.01) {
      final peintureGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = couleur.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, start, sweep * fraction.clamp(0.0, 1.0), false, peintureGlow);
    }

    // Draw track
    canvas.drawArc(rect, start, sweep, false, peintureFond);
    
    // Draw active arc
    if (fraction > 0.01) {
      canvas.drawArc(rect, start, sweep * fraction.clamp(0.0, 1.0), false, peintureArc);
    }

    // Elegant threshold marker: small circle on the track
    if (seuilFraction > 0 && seuilFraction < 1) {
      final angle = start + sweep * seuilFraction;
      final pCentre = centre + Offset(math.cos(angle), math.sin(angle)) * rayon;
      
      final peintureTraitBg = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white;
        
      final peintureTraitFg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = traitSeuil;
        
      canvas.drawCircle(pCentre, 5, peintureTraitBg);
      canvas.drawCircle(pCentre, 5, peintureTraitFg);
    }
  }

  @override
  bool shouldRepaint(_JaugeRadialePainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.seuilFraction != seuilFraction ||
      oldDelegate.couleur != couleur;
}

/// Une donnée de barre horizontale.
class FodepBarreDonnee {
  const FodepBarreDonnee({required this.libelle, required this.valeur, this.couleur, this.seuil});

  final String libelle;
  final double valeur;
  final Color? couleur;

  /// Seuil propre à cette barre, matérialisé par un trait vertical.
  final double? seuil;
}

/// Barres horizontales fintech : libellé, barre arrondie animée en dégradé,
/// valeur en puce à droite, seuils verticaux annotés (ex. 10 % et 25 %).
class FodepBarresHorizontales extends StatelessWidget {
  const FodepBarresHorizontales({
    super.key,
    required this.donnees,
    this.seuils = const <double>[],
    this.maxValeur,
    this.format = fodepFmtMontant,
  });

  final List<FodepBarreDonnee> donnees;
  final List<double> seuils;
  final double? maxValeur;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final max = math.max(maxValeur ?? donnees.fold<double>(0, (m, d) => math.max(m, d.valeur)), 0).toDouble();

    if (donnees.isEmpty || max <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucune donnée à représenter.',
            style: TextStyle(fontSize: 11.5, color: c.faint),
          ),
        ),
      );
    }

    final couleurs = [c.ramp[0], c.ramp[1], c.ramp[2], c.ramp[3], c.ramp[4]];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < donnees.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _BarreHAnimee(
            donnee: donnees[i],
            index: i,
            max: max,
            couleur: donnees[i].couleur ?? couleurs[i % couleurs.length],
            format: format,
            seuilsGlobaux: seuils,
          ),
        ],
        if (seuils.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                for (final s in seuils)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 16, height: 1, color: c.muted.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        'Seuil ${s.toStringAsFixed(0)} %',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: c.muted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BarreHAnimee extends StatelessWidget {
  const _BarreHAnimee({
    required this.donnee,
    required this.index,
    required this.max,
    required this.couleur,
    required this.format,
    required this.seuilsGlobaux,
  });

  final FodepBarreDonnee donnee;
  final int index;
  final double max;
  final Color couleur;
  final String Function(double) format;
  final List<double> seuilsGlobaux;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final d = donnee;
    final fraction = max > 0 ? (d.valeur / max).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            d.libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.ink),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 24,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeur = constraints.maxWidth;
                return CustomPaint(
                  size: Size(largeur, 24),
                  painter: _BarreHPainter(
                    fraction: fraction,
                    couleur: couleur,
                    fond: c.grid,
                    seuilFraction: d.seuil == null || max <= 0 ? null : d.seuil! / max,
                    seuils: seuilsGlobaux.map((s) => max > 0 ? (s / max).clamp(0.0, 1.0) : 0.0).toList(),
                    couleurSeuil: c.border,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          constraints: const BoxConstraints(minWidth: 86),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: c.border, width: Dash.hairline),
          ),
          child: Text(
            format(d.valeur),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: c.navy,
              fontFeatures: Dash.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarreHPainter extends CustomPainter {
  const _BarreHPainter({
    required this.fraction,
    required this.couleur,
    required this.fond,
    required this.seuils,
    required this.couleurSeuil,
    this.seuilFraction,
  });

  final double fraction;
  final Color couleur;
  final Color fond;
  final List<double> seuils;
  final Color couleurSeuil;

  /// Seuil spécifique à la barre dessinée (trait vertical continu).
  final double? seuilFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 5, size.width, 10),
      const Radius.circular(AppTheme.radius),
    );
    canvas.drawRRect(rect, Paint()..color = fond);
    if (fraction > 0.01) {
      final largeur = size.width * fraction.clamp(0.0, 1.0);
      final rectRempli = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height / 2 - 5, largeur.clamp(4.0, size.width).toDouble(), 10),
        const Radius.circular(AppTheme.radius),
      );
      canvas.drawRRect(
        rectRempli,
        Paint()
          ..shader = LinearGradient(
            colors: [couleur, Color.lerp(couleur, Colors.white, 0.22)!],
          ).createShader(rectRempli.outerRect),
      );
    }
    final peintureSeuil = Paint()
      ..strokeWidth = 1
      ..color = couleurSeuil
      ..strokeCap = StrokeCap.round;
    for (final s in seuils) {
      if (s <= 0 || s >= 1) continue;
      final x = size.width * s;
      const pas = 4.0;
      var y = size.height / 2 - 7.0;
      while (y < size.height / 2 + 7) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + pas / 2, size.height / 2 + 7)), peintureSeuil);
        y += pas;
      }
    }
    if (seuilFraction != null && seuilFraction! > 0 && seuilFraction! < 1) {
      final x = size.width * seuilFraction!;
      canvas.drawLine(
        Offset(x, size.height / 2 - 8),
        Offset(x, size.height / 2 + 8),
        Paint()
          ..strokeWidth = 2
          ..color = couleurSeuil
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BarreHPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.couleur != couleur ||
      oldDelegate.seuils != seuils ||
      oldDelegate.seuilFraction != seuilFraction;
}

/// Donut (fl_chart) : composition d'un total, valeur au centre animée,
/// légende en puces. Balayage animé au montage (swapAnimation).
class FodepDonut extends StatelessWidget {
  const FodepDonut({
    super.key,
    required this.segments,
    required this.couleurs,
    required this.centreTitre,
    required this.centreValeur,
    this.format = fodepFmtMontant,
  });

  final List<FodepBarreDonnee> segments;
  final List<Color> couleurs;
  final String centreTitre;
  final String centreValeur;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final positifs = segments.where((s) => s.valeur > 0).toList();
    final total = positifs.fold<double>(0, (m, s) => m + s.valeur);

    if (positifs.isEmpty || total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucune donnée à représenter.',
            style: TextStyle(fontSize: 11.5, color: c.faint),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 168,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 0,
                  centerSpaceRadius: 60,
                  sections: [
                    for (int i = 0; i < positifs.length; i++)
                      PieChartSectionData(
                        value: positifs[i].valeur,
                        color: couleurs[i % couleurs.length],
                        radius: 22,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FodepCompteur(
                    valeur: total,
                    format: format,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                      height: 1.1,
                      fontFeatures: Dash.tabular,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centreTitre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: c.muted, height: 1.3),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            for (int i = 0; i < positifs.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.border, width: Dash.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: couleurs[i % couleurs.length], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${positifs[i].libelle} · ${format(positifs[i].valeur)}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}