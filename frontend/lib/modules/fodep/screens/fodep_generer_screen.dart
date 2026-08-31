import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/fodep_models.dart';
import '../services/fodep_service.dart';

import '../widgets/fodep_attestation_form.dart';
import '../widgets/fodep_design.dart';

class FodepGenererScreen extends StatefulWidget {
  const FodepGenererScreen({super.key, required this.service});

  final FodepService service;

  @override
  State<FodepGenererScreen> createState() => _FodepGenererScreenState();
}

class _FodepGenererScreenState extends State<FodepGenererScreen> {
  bool _chargementInitial = true;
  bool _exportExcel = false;
  bool _exportPdf = false;
  String? _erreur;
  String? _succes;

  FodepApercu? _apercu;
  EtablissementView? _etablissement;
  AttestationFodep? _attestation;

  int _etape = 1;
  bool _attestationValidee = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargementInitial = true);
    try {
      final apercu = await widget.service.obtenirApercu();
      final etab = await widget.service.obtenirEtablissement();
      final attest = await widget.service.obtenirAttestation();

      if (!mounted) return;
      setState(() {
        _apercu = apercu;
        _etablissement = etab;
        _attestation = attest;
        _attestationValidee = attest.rensPrenomsNom.trim().isNotEmpty;
        _chargementInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Chargement des données réglementaires impossible : $e';
        _chargementInitial = false;
      });
    }
  }

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
      final periodeStr = _apercu?.periode != null && _apercu!.periode!.isNotEmpty
          ? _apercu!.periode!
          : DateTime.now().toIso8601String().split('T').first;

      final nomSuggere = 'Matrice_FODEP_Officielle_$periodeStr';

      Uint8List bytes;
      if (isPdf) {
        if (_apercu == null || _etablissement == null) {
          throw StateError('Données réglementaires non prêtes pour la génération.');
        }
        bytes = await widget.service.exporterPdf(periode: _apercu?.periode);
      } else {
        bytes = await widget.service.exporterExcel(periode: _apercu?.periode);
      }

      final location = await getSaveLocation(
        suggestedName: isPdf ? '$nomSuggere.pdf' : '$nomSuggere.xlsx',
        acceptedTypeGroups: [
          isPdf
              ? const XTypeGroup(label: 'Document PDF', extensions: ['pdf'])
              : const XTypeGroup(label: 'Classeur Excel', extensions: ['xlsx']),
        ],

      );

      if (location != null) {
        await saveBytesAtLocation(
          location,
          bytes,
          requiredExtension: isPdf ? '.pdf' : '.xlsx',
        );
        if (mounted) {
          setState(() {
            _succes = isPdf
                ? 'Rapport officiel FODEP exporté en PDF.'
                : 'Classeur officiel FODEP exporté.';
          });
        }
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
            subtitle: 'Complétez l\'attestation, puis exportez le FODEP.',
            titleFontSize: 24,
            subtitleFontSize: 13,
            titleSubtitleGap: 4,
          ),
        ),

        if (!_chargementInitial) _indicateurEtapes(),

        // ── Corps ──────────────────────────────────────────────────────────
        Expanded(
          child: Container(
            color: c.surfaceAlt,
            child: _chargementInitial
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_erreur != null) ...[
                              FodepNotice(
                                status: DashStatus.sousMinimum,
                                texte: _erreur!,
                                onClose: () => setState(() => _erreur = null),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (_succes != null) ...[
                              FodepNotice(
                                status: DashStatus.conforme,
                                texte: _succes!,
                                onClose: () => setState(() => _succes = null),
                              ),
                              const SizedBox(height: 20),
                            ],

                            if (_etape == 2) ...[
                            // Bandeau d'information sur l'arrêté en cours d'export
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: c.border, width: Dash.hairline),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF172554).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_rounded,
                                      color: Color(0xFF172554),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _etablissement?.denomination.isNotEmpty == true
                                              ? '${_etablissement!.denomination} (${_etablissement!.codeBceao})'
                                              : 'Établissement assujetti FODEP',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: c.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Builder(
                                          builder: (context) {
                                            String displayDate = 'Actuelle';
                                            if (_apercu?.periode != null) {
                                              displayDate = _apercu!.periode!;
                                              if (displayDate.contains('-') && displayDate.length == 10) {
                                                final parts = displayDate.split('-');
                                                if (parts[0].length == 4) {
                                                  displayDate = '${parts[2]}/${parts[1]}/${parts[0]}';
                                                }
                                              }
                                            }
                                            return Text(
                                              'Date d\'arrêté : $displayDate · Référentiel BCEAO / DISPRU',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: c.muted,
                                              ),
                                            );
                                          }
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _chargerDonnees,
                                    icon: Icon(Icons.refresh_rounded, color: c.muted, size: 20),
                                    tooltip: 'Actualiser les données',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            DashPanel(
                              title: 'FORMATS D\'EXPORTATION RÉGLEMENTAIRES',
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text(
                                     'Choisissez le format. Les données de l\'arrêté actif sont intégrées.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.45,
                                      color: c.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  LayoutBuilder(builder: (context, cx) {
                                    final large = cx.maxWidth >= 520;

                                    final boutons = [
                                      Expanded(
                                        flex: large ? 1 : 0,
                                        child: _ExportOptionCard(
                                          title: 'Format PDF Officiel',
                                          description:
                                              'Rapport paginé conforme aux exigences de la commission bancaire.',
                                          icon: Icons.picture_as_pdf_rounded,
                                          color: const Color(0xFFDC2626),
                                          isLoading: _exportPdf,
                                          isDisabled: _exportPdf || _exportExcel,
                                          onTap: () => _exporter('pdf'),
                                        ),
                                      ),
                                      SizedBox(width: large ? 20 : 0, height: large ? 0 : 20),
                                      Expanded(
                                        flex: large ? 1 : 0,
                                        child: _ExportOptionCard(
                                          title: 'Format Excel Officiel',
                                          description:
                                              'Classeur complet renseigné avec les états EP01 à EP39.',
                                          icon: Icons.table_view_rounded,
                                          color: const Color(0xFF15803D),
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
                           const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _etape = 1),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('Retour à l\'attestation'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.muted,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                side: BorderSide(color: c.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            ],

                          // ── Étape 1 : Attestation de déclaration prudentielle ──────────────
                          if (_etape == 1 && _attestation != null) ...[
                            DashPanel(
                              title: 'ATTESTATION DE DÉCLARATION PRUDENTIELLE',
                              padding: const EdgeInsets.all(28),
                              child: FodepAttestationForm(
                                key: ValueKey('${_apercu?.periode ?? ''}-${_etablissement?.codeBceao ?? ''}'),
                                service: widget.service,
                                attestation: _attestation!,
                                etablissement: _etablissement,
                                periode: _apercu?.periode,
                                onSaved: () {
                                  if (mounted) {
                                    setState(() {
                                      _attestationValidee = true;
                                      _succes = 'Attestation enregistrée avec succès.';
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (!_attestationValidee)
                              FodepNotice(
                                status: DashStatus.sousMinimum,
                                texte: 'Complétez et enregistrez l\'attestation pour continuer.',
                              ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _attestationValidee
                                    ? () => setState(() => _etape = 2)
                                    : null,
                                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                label: const Text('Continuer vers la génération'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF172554),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
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

  Widget _indicateurEtapes() {
    final c = DashColors.of(context);
    const etapes = [
      ('Attestation', Icons.verified_user_rounded),
      ('Génération', Icons.picture_as_pdf_rounded),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: Dash.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < etapes.length; i++) ...[
            _PastilleEtape(
              numero: i + 1,
              libelle: etapes[i].$1,
              icone: etapes[i].$2,
              actif: _etape == i + 1,
              fait: _etape > i + 1,
            ),
            if (i < etapes.length - 1)
              Container(
                width: 56,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: _etape > i + 1 ? const Color(0xFF172554) : c.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _PastilleEtape extends StatelessWidget {
  const _PastilleEtape({
    required this.numero,
    required this.libelle,
    required this.icone,
    required this.actif,
    required this.fait,
  });

  final int numero;
  final String libelle;
  final IconData icone;
  final bool actif;
  final bool fait;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final colore = fait || actif ? const Color(0xFF172554) : c.border;
    final texte = fait || actif ? Colors.white : c.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colore,
            shape: BoxShape.circle,
          ),
          child: Icon(icone, size: 18, color: texte),
        ),
        const SizedBox(width: 10),
        Text(
          '$numero. $libelle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: actif || fait ? c.ink : c.muted,
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
        ? Matrix4.translationValues(0.0, -3.0, 0.0)
        : Matrix4.identity();

    final hoverShadow = _isHovered && !disabled
        ? BoxShadow(
            color: widget.color.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        : BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: hoverTransform,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered && !disabled ? widget.color.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
              width: _isHovered && !disabled ? 1.5 : 1.0,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 28,
                      color: effectiveColor,
                    ),
                  ),
                  if (widget.isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: disabled ? c.muted : c.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.description,
                style: TextStyle(
                  height: 1.4,
                  fontSize: 12,
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
