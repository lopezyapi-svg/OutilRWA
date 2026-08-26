import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../shared/utils/file_save.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/fodep_models.dart';
import '../services/fodep_service.dart';

Future<bool?> showFodepImportDialog(
  BuildContext context, {
  required FodepService service,
  String? initialPeriode,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FodepImportDialog(
      service: service,
      initialPeriode: initialPeriode,
    ),
  );
}

class _FodepImportDialog extends StatefulWidget {
  const _FodepImportDialog({
    required this.service,
    this.initialPeriode,
  });

  final FodepService service;
  final String? initialPeriode;

  @override
  State<_FodepImportDialog> createState() => _FodepImportDialogState();
}

class _FodepImportDialogState extends State<_FodepImportDialog> {
  bool _isDragging = false;
  bool _isParsing = false;
  bool _isSaving = false;
  bool _isDownloadingTemplate = false;

  XFile? _selectedFile;
  ImportFodepResult? _importResult;
  String? _errorMessage;
  late TextEditingController _periodeController;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final defPeriode = widget.initialPeriode ??
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _periodeController = TextEditingController(text: defPeriode);
  }

  @override
  void dispose() {
    _periodeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls']),
      ],
    );
    if (file == null) return;
    await _processFile(file);
  }

  Future<void> _processFile(XFile file) async {
    final lower = file.name.toLowerCase();
    if (!lower.endsWith('.xlsx') && !lower.endsWith('.xls')) {
      setState(() {
        _errorMessage =
            'Format de fichier non pris en charge. Seuls les fichiers Excel (.xlsx, .xls) sont acceptés.';
        _selectedFile = null;
        _importResult = null;
      });
      return;
    }

    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _selectedFile = file;
      _importResult = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final result = await widget.service.importerExcel(bytes, file.name);
      if (!mounted) return;

      setState(() {
        _importResult = result;
        if (result.periode != null && result.periode!.isNotEmpty) {
          _periodeController.text = result.periode!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _importResult = null;
      });
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  Future<void> _telechargerModele() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final bytes = await widget.service.telechargerModeleOfficiel();
      final location = await getSaveLocation(
        suggestedName: 'Matrice_FODEP_Officielle.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ],
      );
      if (location == null) return;
      await saveBytesAtLocation(location, bytes, requiredExtension: '.xlsx');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Matrice FODEP officielle téléchargée avec succès.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Téléchargement impossible : $e');
      }
    } finally {
      if (mounted) setState(() => _isDownloadingTemplate = false);
    }
  }

  Future<void> _confirmerImport() async {
    if (_importResult == null) return;

    final periode = _periodeController.text.trim();
    if (periode.isEmpty) {
      setState(() => _errorMessage = "Veuillez renseigner une date d'arrêté.");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.service.enregistrer(
        periode: periode,
        postes: _importResult!.postesDetectes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = "Erreur lors de l'enregistrement : $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _fmt(double v) {
    if (v == 0) return '0,00';
    final parts = v.toStringAsFixed(2).split('.');
    final entier = parts[0].replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ' ');
    return '$entier,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border, width: Dash.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 820,
          maxHeight: 740,
          minWidth: 640,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête du dialogue ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(
                  bottom: BorderSide(color: c.border, width: Dash.hairline),
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.indigo.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Colors.indigo,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importer une déclaration FODEP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Matrice officielle BCEAO (.xlsx) ou export réglementaire FODEP',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.close_rounded, color: c.muted, size: 20),
                    tooltip: 'Fermer',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // ── Corps ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Zone de glisser-déposer ─────────────────────────────
                    DropTarget(
                      onDragEntered: (_) => setState(() => _isDragging = true),
                      onDragExited: (_) => setState(() => _isDragging = false),
                      onDragDone: (details) {
                        setState(() => _isDragging = false);
                        if (details.files.isNotEmpty) {
                          _processFile(details.files.first);
                        }
                      },
                      child: GestureDetector(
                        onTap: _isParsing ? null : _pickFile,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: _isDragging
                                ? Colors.indigo.withValues(alpha: 0.08)
                                : (_selectedFile != null
                                    ? Colors.indigo.withValues(alpha: 0.03)
                                    : c.surfaceAlt),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isDragging
                                  ? Colors.indigo
                                  : (_selectedFile != null
                                      ? Colors.indigo.withValues(alpha: 0.5)
                                      : c.border),
                              width: _isDragging ? 2 : 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isParsing) ...[
                                const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.indigo,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Lecture et analyse de la matrice en cours…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                              ] else if (_selectedFile != null) ...[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 34,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFile!.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: c.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cliquez ou déposez un autre fichier pour changer',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: c.muted,
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 38,
                                  color: _isDragging ? Colors.indigo : c.muted,
                                ),
                                const SizedBox(height: 10),
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Glissez-déposez la matrice officielle FODEP ici, ou ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: c.ink,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: 'parcourez vos fichiers',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.indigo,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fichiers acceptés : Matrice_FODEP_Officielle.xlsx (BCEAO/DISPRU) ou export .xlsx',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Message d'erreur dans la boîte de dialogue ──────────
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Aperçu des résultats détectés ────────────────────────
                    if (_importResult != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: sombre
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.border, width: Dash.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${_importResult!.postesDetectes.length} postes DISPRU reconnus',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: 220,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Arrêté :',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: c.muted,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SizedBox(
                                          height: 30,
                                          child: TextField(
                                            controller: _periodeController,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: c.ink,
                                            ),
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                borderSide: BorderSide(
                                                  color: c.border,
                                                ),
                                              ),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Mini tableau des postes clés
                            Text(
                              'EXTRAIT DES POSTES EXTRAITS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: c.muted,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: c.divider,
                                  width: 0.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: ListView.separated(
                                  itemCount: _importResult!.postesDetectes.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    color: c.divider,
                                  ),
                                  itemBuilder: (context, idx) {
                                    final entry = _importResult!
                                        .postesDetectes.entries
                                        .elementAt(idx);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: c.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              entry.key.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.indigo,
                                                fontFeatures: Dash.tabular,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${_fmt(entry.value)} FCFA',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: c.ink,
                                              fontFeatures: Dash.tabular,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Informations et formats supportés ────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Modèle de référence : Matrice officielle FODEP BCEAO / DISPRU (EP01 à EP39).',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: c.ink,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isDownloadingTemplate
                                ? null
                                : _telechargerModele,
                            icon: _isDownloadingTemplate
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 14),
                            label: const Text(
                              'Télécharger matrice officielle',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Boutons d'action (Pied) ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(
                  top: BorderSide(color: c.border, width: Dash.hairline),
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.ink,
                      side: BorderSide(color: c.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (_importResult == null || _isSaving)
                        ? null
                        : _confirmerImport,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      _isSaving ? 'Application en cours…' : 'Appliquer au FODEP',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.indigo.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
