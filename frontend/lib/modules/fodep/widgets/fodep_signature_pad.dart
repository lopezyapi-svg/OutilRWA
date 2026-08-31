import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Pad de signature : l'utilisateur dessine son signature au doigt, à la souris
/// ou au stylet. Le rendu est exporté en PNG (transparent) via [onChanged].
class FodepSignaturePad extends StatefulWidget {
  const FodepSignaturePad({
    super.key,
    required this.onChanged,
    this.initialImage,
    this.height = 160,
  });

  final ValueChanged<Uint8List?> onChanged;
  final Uint8List? initialImage;
  final double height;

  @override
  State<FodepSignaturePad> createState() => _FodepSignaturePadState();
}

class _FodepSignaturePadState extends State<FodepSignaturePad> {
  List<List<Offset>> _traits = [];
  ui.Image? _imageInitiale;
  bool _dessine = false;
  final GlobalKey _boundaryKey = GlobalKey();

  bool get _aDessine => _traits.isNotEmpty || _imageInitiale != null;

  @override
  void initState() {
    super.initState();
    _chargerImageInitiale();
  }

  @override
  void didUpdateWidget(covariant FodepSignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImage != oldWidget.initialImage) {
      _imageInitiale = null;
      _traits = [];
      _chargerImageInitiale();
    }
  }

  void _chargerImageInitiale() {
    final bytes = widget.initialImage;
    if (bytes == null) return;
    ui.instantiateImageCodec(bytes).then((codec) async {
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _imageInitiale = frame.image);
    }).catchError((_) {});
  }

  void _effacer() {
    setState(() {
      _traits = [];
      _imageInitiale = null;
    });
    widget.onChanged(null);
  }

  Future<void> _exporter() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data != null && mounted) {
        widget.onChanged(data.buffer.asUint8List());
      }
    } catch (_) {
      // L'export échoue rarement ; on ignore en cas de problème de rendu.
    }
  }

  void _onDown(PointerDownEvent e) {
    _dessine = true;
    setState(() {
      _traits = List<List<Offset>>.from(_traits)..add([e.localPosition]);
    });
  }

  void _onMove(PointerMoveEvent e) {
    if (!_dessine) return;
    setState(() {
      final trait = List<Offset>.from(_traits.last)..add(e.localPosition);
      _traits = List<List<Offset>>.from(_traits);
      _traits[_traits.length - 1] = trait;
    });
  }

  void _onUp(PointerEvent e) {
    if (!_dessine) return;
    _dessine = false;
    _exporter();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _PeintreSignature(
                      traits: _traits,
                      imageInitiale: _imageInitiale,
                      couleur: Colors.black87,
                    ),
                    size: Size.infinite,
                  ),
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onDown,
                      onPointerMove: _onMove,
                      onPointerUp: _onUp,
                      onPointerCancel: _onUp,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _aDessine ? _effacer : null,
              icon: const Icon(Icons.cleaning_services_outlined, size: 16),
              label: const Text('Effacer'),
              style: TextButton.styleFrom(foregroundColor: c.primary),
            ),
          ],
        ),
      ],
    );
  }
}

class _PeintreSignature extends CustomPainter {
  const _PeintreSignature({
    required this.traits,
    required this.imageInitiale,
    required this.couleur,
  });

  final List<List<Offset>> traits;
  final ui.Image? imageInitiale;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageInitiale != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: imageInitiale!,
        fit: BoxFit.contain,
      );
    }
    final crayon = Paint()
      ..color = couleur
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final trait in traits) {
      if (trait.length == 1) {
        canvas.drawCircle(trait.first, 1.6, crayon);
        continue;
      }
      if (trait.length < 2) continue;
      final path = Path()..moveTo(trait.first.dx, trait.first.dy);
      for (var i = 1; i < trait.length; i++) {
        path.lineTo(trait[i].dx, trait[i].dy);
      }
      canvas.drawPath(path, crayon);
    }
  }

  @override
  bool shouldRepaint(covariant _PeintreSignature old) =>
      old.traits != traits || old.imageInitiale != imageInitiale;
}
