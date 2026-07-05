// Dialog d'import Excel pour les pertes opérationnelles.
import 'dart:io' show PathAccessException;
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/file_save.dart';

// ─── Colonnes et valeurs attendues ────────────────────────────────────────────

const _requiredFields = [
  'date_occurrence',
  'description',
  'ligne_metier',
  'type_evenement',
  'perte_brute',
];

const _colAliases = <String, List<String>>{
  'date_occurrence': [
    'date_occurrence',
    'date occurrence',
    'date d occurrence',
    'date d\'occurrence',
    'date',
    'date_occ',
    'date_incident',
  ],
  'description': ['description', 'desc', 'libelle', 'libellé', 'objet'],
  'ligne_metier': [
    'ligne_metier',
    'ligne de metier',
    'ligne de métier',
    'ligne metier',
    'ligne métier',
    'metier',
    'métier',
    'business_line',
  ],
  'type_evenement': [
    'type_evenement',
    'type d evenement',
    "type d'evenement",
    "type d'événement",
    'type evenement',
    'type',
    'type_evt',
  ],
  'cause_racine': [
    'cause_racine',
    'cause racine',
    'cause',
    'cause_rac',
    'root_cause',
  ],
  'perte_brute': [
    'perte_brute',
    'perte brute',
    'montant brut',
    'brut',
    'perte',
    'montant',
    'gross_loss',
  ],
  'perte_recuperee': [
    'perte_recuperee',
    'perte recuperee',
    'perte récupérée',
    'recuperee',
    'recouv',
    'récupéré',
    'recovery',
  ],
  'statut': ['statut', 'etat', 'état', 'status'],
};

const _lignesMetier = [
  "Financement d'entreprise",
  'Activités de marché',
  'Banque de détail',
  'Banque commerciale',
  'Paiements et règlements',
  "Fonctions d'agent",
  "Gestion d'actifs",
  'Courtage de détail',
];

const _typesEvenement = [
  'Interne',
  'Externe',
  'Processus',
  'Système',
  'Personnel',
  'Juridique'
];
const _statutsIncident = ['Ouvert', 'En cours', 'Résolu', 'Clôturé'];

// ─── Point d'entrée ───────────────────────────────────────────────────────────

Future<bool?> showRoImportPertesDialog(
  BuildContext context, {
  required RwaApiService api,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RoImportPertesDialog(api: api),
  );
}

// ─── Modèle interne ───────────────────────────────────────────────────────────

class _ParsedRow {
  _ParsedRow({
    required this.dateOccurrence,
    required this.description,
    required this.ligneMetier,
    required this.typeEvenement,
    required this.causeRacine,
    required this.perteBrute,
    required this.perteRecuperee,
    required this.statut,
    required this.errors,
  });

  final String dateOccurrence;
  final String description;
  final String ligneMetier;
  final String typeEvenement;
  final String causeRacine;
  final double perteBrute;
  final double perteRecuperee;
  final String statut;
  final List<String> errors;

  bool get isValid => errors.isEmpty;

  Map<String, dynamic> toJson() => {
        'date_occurrence': dateOccurrence,
        'description': description,
        'ligne_metier': ligneMetier,
        'type_evenement': typeEvenement,
        'cause_racine': causeRacine,
        'perte_brute': perteBrute,
        'perte_recuperee': perteRecuperee,
        'statut': statut,
      };
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

class _RoImportPertesDialog extends StatefulWidget {
  const _RoImportPertesDialog({required this.api});
  final RwaApiService api;

  @override
  State<_RoImportPertesDialog> createState() => _RoImportPertesDialogState();
}

class _RoImportPertesDialogState extends State<_RoImportPertesDialog> {
  bool _isDragging = false;
  bool _isParsing = false;
  bool _isImporting = false;
  bool _isDownloadingTemplate = false;
  String _mode = 'merge';
  String _importStage = '';

  XFile? _selectedFile;
  List<_ParsedRow>? _parsedRows;
  String? _parseError;
  Map<String, dynamic>? _importResult;

  // ─── Thème ────────────────────────────────────────────────────────────────

  ThemeData get _theme => Theme.of(context);
  bool get _isDark => _theme.brightness == Brightness.dark;
  Color get _bg =>
      _theme.cardTheme.color ?? (_isDark ? AppTheme.darkCard : AppTheme.card);
  Color get _soft =>
      _isDark ? const Color(0xFF14233D) : const Color(0xFFF8FAFE);
  Color get _border => _theme.dividerColor;
  Color get _text =>
      _theme.textTheme.bodyLarge?.color ??
      (_isDark ? AppTheme.darkText : AppTheme.text);
  Color get _muted => _isDark ? AppTheme.darkMuted : AppTheme.muted;
  Color get _accent => _theme.colorScheme.primary;

  List<_ParsedRow> get _validRows =>
      _parsedRows?.where((r) => r.isValid).toList() ?? [];
  List<_ParsedRow> get _errorRows =>
      _parsedRows?.where((r) => !r.isValid).toList() ?? [];

  // ─── Fichier ──────────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final bytes = await widget.api.downloadRoImportTemplate();
      if (!mounted) return;
      final location = await getSaveLocation(
        suggestedName: 'modele_import_pertes_op.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ],
      );
      if (location == null) return;
      await saveBytesAtLocation(location, bytes, requiredExtension: '.xlsx');
      if (mounted) _showMsg('Modèle enregistré.');
    } on PathAccessException {
      if (mounted) {
        _showMsg(
          'Impossible d\'enregistrer : le fichier est probablement déjà ouvert '
          '(par exemple dans Excel). Fermez-le puis réessayez, ou choisissez '
          'un autre emplacement.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) _showMsg('Téléchargement impossible: $e', error: true);
    } finally {
      if (mounted) setState(() => _isDownloadingTemplate = false);
    }
  }

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (file == null) return;
    await _loadFile(file);
  }

  Future<void> _loadFile(XFile file) async {
    if (!file.name.toLowerCase().endsWith('.xlsx')) {
      _showMsg('Seuls les fichiers .xlsx sont acceptés.', error: true);
      return;
    }
    setState(() {
      _isParsing = true;
      _parsedRows = null;
      _parseError = null;
      _selectedFile = file;
      _importResult = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final rows = _parseExcel(bytes);
      if (mounted) setState(() => _parsedRows = rows);
    } catch (e) {
      if (mounted) setState(() => _parseError = 'Lecture impossible: $e');
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  // ─── Parsing Excel (client-side) ──────────────────────────────────────────

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String? _matchField(String rawHeader) {
    final n = _norm(rawHeader);
    for (final entry in _colAliases.entries) {
      for (final alias in entry.value) {
        if (_norm(alias) == n) return entry.key;
      }
    }
    return null;
  }

  static String _cellStr(Data? cell) {
    if (cell == null) return '';
    try {
      final v = cell.value;
      if (v == null) return '';
      if (v is TextCellValue) return (v.value.text ?? '').trim();
      if (v is IntCellValue) return v.value.toString();
      if (v is DoubleCellValue) return v.value.toString();
      if (v is DateTimeCellValue) {
        // asDateTimeLocal() peut être null dans certaines versions du package
        try {
          final dt = v.asDateTimeLocal();
          return '${dt.year}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')}';
        } catch (_) {
          // Fallback : construire depuis les champs directs
          return '${v.year}-'
              '${v.month.toString().padLeft(2, '0')}-'
              '${v.day.toString().padLeft(2, '0')}';
        }
      }
      return v.toString().trim();
    } catch (_) {
      return '';
    }
  }

  static double _parseNum(String s) {
    if (s.isEmpty) return 0;
    final clean = s
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }

  static String _parseDate(String s) {
    s = s.trim();
    if (s.isEmpty) return '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return s.substring(0, 10);
    final m = RegExp(r'^(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})').firstMatch(s);
    if (m != null) {
      final y = m.group(3)!;
      final mo = m.group(2)!.padLeft(2, '0');
      final d = m.group(1)!.padLeft(2, '0');
      return '$y-$mo-$d';
    }
    return s;
  }

  static String _matchLigne(String s) {
    final n = s.trim().toLowerCase();
    if (n.isEmpty) return s;
    for (final l in _lignesMetier) {
      if (l.toLowerCase() == n) return l;
    }
    final minLen = math.min(5, n.length);
    for (final l in _lignesMetier) {
      if (l.toLowerCase().contains(n.substring(0, minLen))) return l;
    }
    return s;
  }

  static String _matchType(String s) {
    final n = s.trim().toLowerCase();
    for (final t in _typesEvenement) {
      if (t.toLowerCase() == n) return t;
    }
    return s;
  }

  static String _matchStatut(String s) {
    final n = s.trim().toLowerCase();
    for (final st in _statutsIncident) {
      if (st.toLowerCase() == n) return st;
    }
    return 'Ouvert';
  }

  List<_ParsedRow> _parseExcel(Uint8List bytes) {
    // Décode avec protection contre les erreurs internes du package excel
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('Fichier illisible ou corrompu : $e');
    }
    if (excel.tables.isEmpty) throw Exception('Aucune feuille trouvée.');

    // Cherche la feuille "Incidents" — lookup explicitement null-safe
    Sheet? sheet;
    for (final key in excel.tables.keys) {
      if (key.toLowerCase().contains('incident')) {
        final candidate = excel.tables[key];
        if (candidate != null) {
          sheet = candidate;
          break;
        }
      }
    }
    // Fallback : première feuille non nulle
    if (sheet == null) {
      for (final key in excel.tables.keys) {
        final candidate = excel.tables[key];
        if (candidate != null) {
          sheet = candidate;
          break;
        }
      }
    }
    if (sheet == null) {
      throw Exception('Aucune feuille lisible dans le fichier.');
    }

    final allRows = sheet.rows;
    if (allRows.isEmpty) throw Exception('Feuille vide.');

    // ── Étape 1 : trouver la ligne d'en-têtes ──────────────────────────────
    // Scanne les 6 premières lignes et garde celle avec le plus de colonnes
    // reconnues. Cela gère : fichier simple (headers en ligne 1) ET le
    // template téléchargé (titre en ligne 1, headers en ligne 2).
    int headerRowIdx = 0;
    var bestColMap = <int, String>{};

    for (var ri = 0; ri < math.min(6, allRows.length); ri++) {
      final row = allRows[ri];
      final candidate = <int, String>{};
      for (var ci = 0; ci < row.length; ci++) {
        final raw = _cellStr(row[ci]);
        if (raw.isEmpty) continue;
        final field = _matchField(raw);
        if (field != null) candidate[ci] = field;
      }
      if (candidate.length > bestColMap.length) {
        bestColMap = candidate;
        headerRowIdx = ri;
      }
    }

    // Vérification colonnes obligatoires
    final missing =
        _requiredFields.where((f) => !bestColMap.values.contains(f)).toList();
    if (missing.isNotEmpty) {
      throw Exception('Colonnes manquantes : ${missing.join(', ')}');
    }

    // ── Étape 2 : détecter et sauter les lignes de consignes ──────────────
    // Le template a une ligne "hints" juste après les en-têtes (ex : "AAAA-MM-JJ
    // ou JJ/MM/AAAA"). On la saute si elle ne contient pas de date parseable
    // ET pas de nombre valide dans perte_brute.
    final dateColIdx = bestColMap.entries
        .where((e) => e.value == 'date_occurrence')
        .map((e) => e.key)
        .firstOrNull;
    final pertColIdx = bestColMap.entries
        .where((e) => e.value == 'perte_brute')
        .map((e) => e.key)
        .firstOrNull;

    int dataStartRow = headerRowIdx + 1;
    while (dataStartRow < allRows.length && dataStartRow <= headerRowIdx + 2) {
      final row = allRows[dataStartRow];
      if (row.every((c) => _cellStr(c).isEmpty)) {
        dataStartRow++;
        continue;
      }
      final dateVal = (dateColIdx != null && dateColIdx < row.length)
          ? _cellStr(row[dateColIdx])
          : '';
      final pertVal = (pertColIdx != null && pertColIdx < row.length)
          ? _cellStr(row[pertColIdx])
          : '';
      final hasDate = _parseDate(dateVal).isNotEmpty;
      final hasNum = _parseNum(pertVal) > 0;
      // Si ni date ni montant valide → ligne hint, on saute
      if (!hasDate && !hasNum) {
        dataStartRow++;
      } else {
        break;
      }
    }

    // ── Étape 3 : parser les lignes de données ─────────────────────────────
    String getField(List<Data?> row, String field) {
      final ci = bestColMap.entries
          .where((e) => e.value == field)
          .map((e) => e.key)
          .firstOrNull;
      if (ci == null) return '';
      return ci < row.length ? _cellStr(row[ci]) : '';
    }

    final result = <_ParsedRow>[];
    for (var ri = dataStartRow; ri < allRows.length; ri++) {
      final row = allRows[ri];
      if (row.every((c) => _cellStr(c).isEmpty)) continue;

      final errors = <String>[];

      final dateStr = _parseDate(getField(row, 'date_occurrence'));
      if (dateStr.isEmpty) errors.add('date_occurrence manquante');

      final desc = getField(row, 'description');
      if (desc.isEmpty) errors.add('description manquante');

      final ligneRaw = getField(row, 'ligne_metier');
      final ligne = _matchLigne(ligneRaw);
      if (!_lignesMetier.contains(ligne)) {
        errors.add('ligne_metier invalide : "$ligneRaw"');
      }

      final typeRaw = getField(row, 'type_evenement');
      final type = _matchType(typeRaw);
      if (!_typesEvenement.contains(type)) {
        errors.add('type_evenement invalide : "$typeRaw"');
      }

      final perteBrute = _parseNum(getField(row, 'perte_brute'));
      if (perteBrute <= 0) errors.add('perte_brute doit être > 0');

      result.add(_ParsedRow(
        dateOccurrence: dateStr,
        description: desc,
        ligneMetier: ligne,
        typeEvenement: type,
        causeRacine: getField(row, 'cause_racine'),
        perteBrute: perteBrute,
        perteRecuperee: _parseNum(getField(row, 'perte_recuperee')),
        statut: _matchStatut(getField(row, 'statut')),
        errors: errors,
      ));
    }

    if (result.isEmpty) throw Exception('Aucune ligne de données trouvée.');
    return result;
  }

  // ─── Import ───────────────────────────────────────────────────────────────

  Future<void> _runImport() async {
    final valid = _validRows;
    if (valid.isEmpty) return;

    if (_mode == 'replace') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer le remplacement'),
          content: const Text(
            'Tous les incidents existants seront supprimés, puis remplacés '
            'par les données du fichier. Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _isImporting = true;
      _importStage = 'Envoi des données au serveur…';
    });

    try {
      final result = await widget.api.importRoIncidents(
        valid.map((r) => r.toJson()).toList(),
        mode: _mode,
      );
      if (!mounted) return;
      setState(() {
        _importResult = result;
        _importStage = 'Terminé';
      });
    } catch (e) {
      if (mounted) _showMsg('Erreur import: $e', error: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.success,
    ));
  }

  // ─── Build principal ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
              const SizedBox(height: 14),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2F6EEA), Color(0xFF12A7B4)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: const Icon(
              Icons.cloud_upload,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Importation de données (Risque Opérationnel)',
              style: TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, false),
            tooltip: 'Fermer',
          ),
        ],
      );

  // ─── Corps ────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_importResult != null) return _buildResultScreen();
    if (_parsedRows != null) return _buildPreviewScreen();
    return _buildDropZoneScreen();
  }

  // ─── Écran 1 : Drop zone ──────────────────────────────────────────────────

  Widget _buildDropZoneScreen() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Expanded(child: _buildDropZone()),
              const SizedBox(height: 12),
              _buildModeSelector(),
            ],
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 330,
          child: _buildFormatCard(),
        ),
      ],
    );
  }

  Widget _buildDropZone() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (d) async {
        setState(() => _isDragging = false);
        if (d.files.isNotEmpty) await _loadFile(d.files.first);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isDragging ? _accent.withValues(alpha: 0.06) : _bg,
          border: Border.all(
            color: _isDragging ? _accent : _border,
            width: _isDragging ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _isParsing
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Lecture du fichier...',
                        style: TextStyle(color: AppTheme.muted)),
                  ],
                ),
              )
            : _parseError != null
                ? _buildParseErrorContent()
                : _buildDropContent(),
      ),
    );
  }

  Widget _buildDropContent() => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _isDragging
                  ? Icons.file_download_done_rounded
                  : Icons.upload_file_outlined,
              size: 38,
              color: _isDragging ? _accent : _muted,
            ),
            const SizedBox(height: 18),
            Text(
              _isDragging
                  ? 'Déposez le fichier pour lancer le contrôle'
                  : 'Déposez le fichier de pertes ici',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _isDragging ? _accent : _text,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le classeur est lu localement avant import. Vous pourrez corriger ou retirer les lignes sensibles avant validation.',
              style: TextStyle(fontSize: 13, color: _muted, height: 1.45),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open_outlined, size: 17),
                  label: const Text('Choisir un fichier'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _isDownloadingTemplate ? null : _downloadTemplate,
                  icon: _isDownloadingTemplate
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Modèle Excel'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Fichier accepté: .xlsx. En-têtes en première ligne ou ligne 2 du modèle.',
              style: TextStyle(fontSize: 11.5, color: _muted),
            ),
          ],
        ),
      );

  Widget _buildParseErrorContent() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 44, color: AppTheme.danger),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _parseError!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _parseError = null;
              _selectedFile = null;
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Choisir un autre fichier'),
          ),
        ],
      );

  Widget _buildFormatCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contrôles avant import',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              Icon(Icons.rule_outlined, size: 16, color: _accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Le fichier peut venir du modèle ou d’un export interne, tant que les champs essentiels sont présents.',
            style: TextStyle(fontSize: 12, color: _muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          _formatCheck('Date d’occurrence', 'AAAA-MM-JJ ou JJ/MM/AAAA', true),
          _formatCheck('Description', 'Libellé lisible de l’incident', true),
          _formatCheck('Ligne de métier', 'Référentiel BCEAO attendu', true),
          _formatCheck('Type d’événement', 'Interne, Externe, Processus...', true),
          _formatCheck('Perte brute', 'Montant en FCFA', true),
          _formatCheck('Cause, récupéré, statut', 'Champs acceptés si présents', false),
          const Spacer(),
          Divider(height: 18, color: _border),
          TextButton.icon(
            onPressed: _isDownloadingTemplate ? null : _downloadTemplate,
            icon: _isDownloadingTemplate
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 15),
            label: const Text('Télécharger le modèle'),
          ),
        ],
      ),
    );
  }

  Widget _formatCheck(String label, String detail, bool required) {
    final color = required ? _accent : _muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              required ? Icons.check_circle_outline : Icons.info_outline,
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 11, color: _muted, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Écran 2 : Prévisualisation ────────────────────────────────────────────

  Widget _buildPreviewScreen() {
    final rows = _parsedRows!;
    final valid = _validRows;
    final errors = _errorRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileInfoBar(rows, valid, errors),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreviewTable(rows),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildErrorPanel(errors),
                ],
                const SizedBox(height: 10),
                _buildBiaNotice(valid),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildModeSelector(),
      ],
    );
  }

  Widget _buildFileInfoBar(
    List<_ParsedRow> rows,
    List<_ParsedRow> valid,
    List<_ParsedRow> errors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart_outlined, size: 18, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedFile!.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _text,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _badge('${rows.length} lignes', const Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          _badge('${valid.length} valides', AppTheme.success),
          if (errors.isNotEmpty) ...[
            const SizedBox(width: 6),
            _badge('${errors.length} erreur(s)', AppTheme.danger),
          ],
          TextButton.icon(
            onPressed: () => setState(() {
              _parsedRows = null;
              _selectedFile = null;
            }),
            icon: const Icon(Icons.swap_horiz, size: 15),
            label: const Text('Changer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable(List<_ParsedRow> rows) {
    final previewEntries = rows.asMap().entries.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aperçu des premières lignes (${previewEntries.length}/${rows.length})',
          style: TextStyle(
            fontSize: 12,
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF13233E) : Colors.white,
            border: Border.all(
                color: _isDark ? const Color(0xFF304764) : AppTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(100),
              1: FlexColumnWidth(2.2),
              2: FixedColumnWidth(145),
              3: FixedColumnWidth(85),
              4: FixedColumnWidth(95),
              5: FixedColumnWidth(24),
              6: FixedColumnWidth(70),
            },
            children: [
              _tHeader([
                'Date',
                'Description',
                'Ligne de métier',
                'Type',
                'Perte brute',
                '',
                'Actions'
              ]),
              ...previewEntries.map((e) => _tRow(e.key, e.value)),
            ],
          ),
        ),
        if (rows.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              '… et ${rows.length - 10} ligne(s) supplémentaire(s)',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
          ),
      ],
    );
  }

  TableRow _tHeader(List<String> cols) => TableRow(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A518A), Color(0xFF23477A)],
          ),
          border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
        ),
        children: cols
            .map((c) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF5F8FF),
                      letterSpacing: 0.18,
                    ),
                  ),
                ))
            .toList(),
      );

  TableRow _tRow(int index, _ParsedRow r) {
    return TableRow(
      decoration: BoxDecoration(
        color: r.isValid ? null : AppTheme.danger.withValues(alpha: 0.04),
        border:
            Border(bottom: BorderSide(color: _border.withValues(alpha: 0.4))),
      ),
      children: [
        _tCell(r.dateOccurrence),
        _tCell(r.description, overflow: true),
        _tCell(r.ligneMetier, overflow: true),
        _tCell(r.typeEvenement),
        _tCell(_fmtCurrency(r.perteBrute), right: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: r.isValid
              ? const Icon(Icons.check_circle_outline,
                  size: 14, color: AppTheme.success)
              : Tooltip(
                  excludeFromSemantics: true,
                  message: r.errors.join('\n'),
                  child: const Icon(Icons.error_outline,
                      size: 14, color: AppTheme.danger),
                ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.edit_outlined, size: 14, color: _muted),
                  tooltip: 'Modifier',
                  onPressed: () => _editRow(index, r),
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete_outline,
                      size: 14, color: AppTheme.danger),
                  tooltip: 'Supprimer',
                  onPressed: () => setState(() => _parsedRows!.removeAt(index)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editRow(int index, _ParsedRow original) async {
    final dateCtrl = TextEditingController(text: original.dateOccurrence);
    final descCtrl = TextEditingController(text: original.description);
    final bruteCtrl =
        TextEditingController(text: original.perteBrute.toStringAsFixed(0));
    final recupCtrl = TextEditingController(
        text: original.perteRecuperee == 0
            ? ''
            : original.perteRecuperee.toStringAsFixed(0));
    final causeCtrl = TextEditingController(text: original.causeRacine);
    String ligne = _lignesMetier.contains(original.ligneMetier)
        ? original.ligneMetier
        : _lignesMetier.first;
    String type = _typesEvenement.contains(original.typeEvenement)
        ? original.typeEvenement
        : _typesEvenement.first;
    String statut = _statutsIncident.contains(original.statut)
        ? original.statut
        : _statutsIncident.first;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Widget textField(String label, TextEditingController ctrl,
                  {bool number = false, bool required = true, String? hint}) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: TextFormField(
                  controller: ctrl,
                  keyboardType:
                      number ? TextInputType.number : TextInputType.text,
                  inputFormatters: number
                      ? [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))]
                      : null,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  validator: required
                      ? (v) => (v == null || v.trim().isEmpty)
                          ? 'Champ requis'
                          : null
                      : null,
                ),
              );

          Widget dropField<T>(String label, T val, List<T> items,
                  void Function(T?) onChange) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: DropdownButtonFormField<T>(
                  initialValue: val,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  items: items
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.toString(),
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: onChange,
                ),
              );

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.07),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(children: [
                Icon(Icons.edit_outlined, color: _accent, size: 18),
                const SizedBox(width: 3),
                const Text('Modifier la ligne',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: TextFormField(
                          controller: dateCtrl,
                          readOnly: true,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Date d\'occurrence *',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 3, vertical: 3),
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.calendar_month_outlined, size: 16),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Requis' : null,
                          onTap: () async {
                            DateTime? cur;
                            try {
                              cur = DateTime.parse(dateCtrl.text);
                            } catch (_) {}
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: cur ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              dateCtrl.text =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            }
                          },
                        ),
                      ),
                      textField('Description *', descCtrl),
                      Row(children: [
                        Expanded(
                            child: dropField<String>(
                                'Ligne de métier *',
                                ligne,
                                _lignesMetier,
                                (v) => setD(() => ligne = v ?? ligne))),
                        const SizedBox(width: 3),
                        Expanded(
                            child: dropField<String>(
                                "Type d'événement *",
                                type,
                                _typesEvenement,
                                (v) => setD(() => type = v ?? type))),
                      ]),
                      Row(children: [
                        Expanded(
                            child: textField('Perte brute (FCFA) *', bruteCtrl,
                                number: true, hint: 'Ex: 500000')),
                        const SizedBox(width: 3),
                        Expanded(
                            child: textField('Perte récupérée', recupCtrl,
                                number: true, required: false, hint: 'Ex: 0')),
                      ]),
                      Row(children: [
                        Expanded(
                            child: textField('Cause racine', causeCtrl,
                                required: false, hint: 'Optionnel')),
                        const SizedBox(width: 3),
                        Expanded(
                            child: dropField<String>(
                                'Statut',
                                statut,
                                _statutsIncident,
                                (v) => setD(() => statut = v ?? statut))),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined, size: 16),
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx, true);
                },
                label: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final errors = <String>[];
      final dateStr = dateCtrl.text.trim();
      if (dateStr.isEmpty) errors.add('date_occurrence manquante');
      final desc = descCtrl.text.trim();
      if (desc.isEmpty) errors.add('description manquante');
      if (!_lignesMetier.contains(ligne)) errors.add('ligne_metier invalide');
      if (!_typesEvenement.contains(type)) {
        errors.add('type_evenement invalide');
      }
      final perteBrute =
          double.tryParse(bruteCtrl.text.replaceAll(' ', '')) ?? 0;
      if (perteBrute <= 0) errors.add('perte_brute doit être > 0');

      setState(() => _parsedRows![index] = _ParsedRow(
            dateOccurrence: dateStr,
            description: desc,
            ligneMetier: ligne,
            typeEvenement: type,
            causeRacine: causeCtrl.text.trim(),
            perteBrute: perteBrute,
            perteRecuperee:
                double.tryParse(recupCtrl.text.replaceAll(' ', '')) ?? 0,
            statut: statut,
            errors: errors,
          ));
    }
    dateCtrl.dispose();
    descCtrl.dispose();
    bruteCtrl.dispose();
    recupCtrl.dispose();
    causeCtrl.dispose();
  }

  Widget _tCell(String t, {bool right = false, bool overflow = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        t,
        overflow: overflow ? TextOverflow.ellipsis : null,
        maxLines: overflow ? 1 : null,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontSize: 11, color: _text),
      ),
    );
  }

  Widget _buildErrorPanel(List<_ParsedRow> errors) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  size: 14, color: AppTheme.danger),
              const SizedBox(width: 6),
              Text(
                '${errors.length} ligne(s) invalide(s) — seront ignorées à l\'import',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...errors.take(6).map((r) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '• ${r.errors.join(' | ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.danger,
                  ),
                ),
              )),
          if (errors.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '  … et ${errors.length - 6} autre(s)',
                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBiaNotice(List<_ParsedRow> valid) {
    if (valid.isEmpty) return const SizedBox.shrink();
    final totalBrute = valid.fold(0.0, (s, r) => s + r.perteBrute);
    final totalNette =
        valid.fold(0.0, (s, r) => s + r.perteBrute - r.perteRecuperee);
    final kBia = totalNette * 0.15;
    final apr = kBia * (1 / 0.09);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Impact BIA estimé après import',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              Text(
                'Art. 89',
                style: TextStyle(
                  fontSize: 11,
                  color: _accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _biaKpi('Perte brute', _fmtCurrency(totalBrute))),
              const SizedBox(width: 10),
              Expanded(child: _biaKpi('Perte nette', _fmtCurrency(totalNette))),
              const SizedBox(width: 10),
              Expanded(child: _biaKpi('Capital 15 %', _fmtCurrency(kBia))),
              const SizedBox(width: 10),
              Expanded(child: _biaKpi('APR x11,111111', _fmtCurrency(apr))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Calcul indicatif sur les lignes valides: capital minimal = 15 % des pertes nettes, APR = capital minimal x 11,111111.',
            style: TextStyle(
              fontSize: 10.5,
              color: _muted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _biaKpi(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _soft,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: _muted)),
            const SizedBox(height: 3),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
          ],
        ),
      );

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.merge_type_outlined, size: 16, color: _muted),
          const SizedBox(width: 8),
          Text(
            'Mode d\'import',
            style: TextStyle(
              fontSize: 12,
              color: _text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          _modeChip(
            'merge',
            'Ajouter au registre',
            Icons.playlist_add_check_circle_outlined,
            const Color(0xFF1D4ED8),
            'Conserve les incidents existants et ajoute les nouveaux',
          ),
          const SizedBox(width: 8),
          _modeChip(
            'replace',
            'Remplacer le registre',
            Icons.restart_alt_rounded,
            AppTheme.danger,
            'Supprime TOUS les incidents existants avant l\'import',
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
    String value,
    String label,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    final selected = _mode == value;
    return Tooltip(
      excludeFromSemantics: true,
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _mode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : _soft,
            border: Border.all(
              color: selected ? color : _border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? color : _muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? color : _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Écran 3 : Résultat ────────────────────────────────────────────────────

  Widget _buildResultScreen() {
    final r = _importResult!;
    final imported = r['imported'] as int? ?? 0;
    final importErrors = (r['errors'] as List?)?.cast<String>() ?? [];

    return Center(
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 28, color: AppTheme.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Import terminé',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$imported incident(s) ajouté(s) au registre.',
              style: TextStyle(fontSize: 14, color: _text),
            ),
            if (importErrors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${importErrors.length} ligne(s) ignorée(s) côté serveur.',
                style: const TextStyle(fontSize: 12, color: AppTheme.danger),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _mode == 'replace'
                  ? 'Mode utilisé: remplacement du registre.'
                  : 'Mode utilisé: ajout aux données existantes.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualiser le registre'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    if (_importResult != null) return const SizedBox.shrink();

    final canImport =
        _parsedRows != null && _validRows.isNotEmpty && !_isImporting;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (_isImporting) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_importStage,
                      style: TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 4),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ] else
            Expanded(
              child: Text(
                _parsedRows == null
                    ? 'Sélectionnez un fichier pour lancer le contrôle.'
                    : '${_validRows.length} ligne(s) prête(s), ${_errorRows.length} à corriger ou ignorer.',
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
            ),
          TextButton(
            onPressed:
                _isImporting ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: canImport ? _runImport : null,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_rounded, size: 18),
            label: Text(
              _parsedRows == null
                  ? 'Importer'
                  : 'Importer ${_validRows.length} incident(s)',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Utilitaires visuels ──────────────────────────────────────────────────

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  String _fmtCurrency(double v) {
    if (v == 0) return '0';
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)} G';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)} M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)} K';
    return v.toStringAsFixed(0);
  }
}
