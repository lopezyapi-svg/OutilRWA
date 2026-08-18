import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../services/fodep_service.dart';
import '../widgets/fodep_design.dart';

class FodepGenererScreen extends StatefulWidget {
  const FodepGenererScreen({super.key, required this.service});

  final FodepService service;

  @override
  State<FodepGenererScreen> createState() => _FodepGenererScreenState();
}

class _FodepGenererScreenState extends State<FodepGenererScreen> {
  bool _exportExcel = false;
  bool _exportPdf = false;
  String? _erreur;
  String? _succes;

  Future<void> _exporter(String format) async {
    final isPdf = format == 'pdf';
    setState(() {
      _erreur = null;
      _succes = null;
      if (isPdf) {
        _exportPdf = true;
      } else {
        _exportExcel = true;
      }
    });

    try {
      final Uint8List bytes = await widget.service.exporterExcel();
      final nomSuggere = 'FODEP_fonds_propres_${DateTime.now().toIso8601String().split('T').first}';
      final location = await getSaveLocation(
        suggestedName: isPdf ? '$nomSuggere.pdf' : '$nomSuggere.xlsx',
      );
      if (location != null) {
        await saveBytesAtLocation(
          location,
          bytes,
          requiredExtension: isPdf ? '.pdf' : '.xlsx',
        );
        if (mounted) setState(() => _succes = 'Export ${isPdf ? 'PDF' : 'Excel'} enregistré avec succès.');
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Export impossible : $e');
    } finally {
      if (mounted) {
        setState(() {
          _exportPdf = false;
          _exportExcel = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(
              bottom: BorderSide(
                color: c.border,
                width: Dash.hairline,
              ),
            ),
          ),
          child: const PageHeader(
            title: 'Générer un FODEP',
            subtitle: 'Exportez le formulaire de déclaration prudentielle au format souhaité.',
            titleFontSize: 24,
            subtitleFontSize: 13,
            titleSubtitleGap: 4,
          ),
        ),

        // ── Corps ──────────────────────────────────────────────────────────
        Expanded(
          child: Container(
            color: c.surfaceAlt,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_erreur != null) ...[
                        FodepNotice(status: DashStatus.sousMinimum, texte: _erreur!),
                        const SizedBox(height: 24),
                      ],
                      if (_succes != null) ...[
                        FodepNotice(status: DashStatus.conforme, texte: _succes!),
                        const SizedBox(height: 24),
                      ],

                      DashPanel(
                        title: 'Formats de génération',
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sélectionnez le format cible pour générer le rapport. L\'export reprend les données du dernier arrêté enregistré dans le module de gestion des risques.',
                              style: DashText.value(c, weight: FontWeight.w400)
                                  .copyWith(height: 1.5, color: c.muted),
                            ),
                            const SizedBox(height: 32),
                            LayoutBuilder(builder: (context, cx) {
                              final large = cx.maxWidth >= 500;
                              
                              final boutons = [
                                Expanded(
                                  flex: large ? 1 : 0,
                                  child: _ExportOptionCard(
                                    title: 'Format PDF',
                                    description: 'Document prêt à être imprimé ou partagé. Non modifiable.',
                                    icon: Icons.picture_as_pdf_rounded,
                                    color: const Color(0xFFE53935), // Rouge standard PDF
                                    isLoading: _exportPdf,
                                    isDisabled: _exportPdf || _exportExcel,
                                    onTap: () => _exporter('pdf'),
                                  ),
                                ),
                                SizedBox(width: large ? 24 : 0, height: large ? 0 : 24),
                                Expanded(
                                  flex: large ? 1 : 0,
                                  child: _ExportOptionCard(
                                    title: 'Format Excel',
                                    description: 'Classeur contenant les données brutes et tableaux. Modifiable.',
                                    icon: Icons.table_view_rounded,
                                    color: const Color(0xFF2E7D32), // Vert standard Excel
                                    isLoading: _exportExcel,
                                    isDisabled: _exportPdf || _exportExcel,
                                    onTap: () => _exporter('excel'),
                                  ),
                                ),
                              ];

                              return large
                                  ? IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: boutons,
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: boutons,
                                    );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportOptionCard extends StatefulWidget {
  const _ExportOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  State<_ExportOptionCard> createState() => _ExportOptionCardState();
}

class _ExportOptionCardState extends State<_ExportOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    
    final disabled = widget.isDisabled;
    final effectiveColor = disabled ? widget.color.withValues(alpha: 0.5) : widget.color;
    
    final hoverTransform = _isHovered && !disabled 
        ? Matrix4.translationValues(0.0, -4.0, 0.0) 
        : Matrix4.identity();
        
    final hoverShadow = _isHovered && !disabled
        ? BoxShadow(
            color: widget.color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        : BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: hoverTransform,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered && !disabled ? widget.color.withValues(alpha: 0.5) : c.border,
              width: _isHovered && !disabled ? 2.0 : 1.0,
            ),
            boxShadow: [hoverShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 32,
                      color: effectiveColor,
                    ),
                  ),
                  if (widget.isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: DashText.value(c).copyWith(
                  fontSize: 16,
                  color: disabled ? c.muted : c.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: DashText.caption(c).copyWith(
                  height: 1.4,
                  fontSize: 13,
                  color: disabled ? c.faint : c.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
