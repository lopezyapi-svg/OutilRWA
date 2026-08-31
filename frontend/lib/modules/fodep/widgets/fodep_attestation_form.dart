import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dashboard/widgets/dashboard_design.dart';
import '../models/fodep_models.dart';
import '../services/fodep_service.dart';
import '../widgets/fodep_design.dart';
import '../widgets/fodep_signature_pad.dart';

class FodepAttestationForm extends StatefulWidget {
  const FodepAttestationForm({
    super.key,
    required this.service,
    required this.attestation,
    this.etablissement,
    this.periode,
    this.onSaved,
  });

  final FodepService service;
  final AttestationFodep attestation;
  final EtablissementView? etablissement;
  final String? periode;
  final VoidCallback? onSaved;

  @override
  State<FodepAttestationForm> createState() => _FodepAttestationFormState();
}

class _FodepAttestationFormState extends State<FodepAttestationForm> {
  static const _navy = Color(0xFF172554);

  // Controllers Renseignement
  late final TextEditingController _rensPrenomsNomCtrl;
  late final TextEditingController _rensFonctionCtrl;
  late final TextEditingController _rensTelephoneCtrl;
  late final TextEditingController _rensPosteCtrl;
  late final TextEditingController _rensEmailCtrl;

  // Controllers Transmission
  late final TextEditingController _transPrenomsNomCtrl;
  late final TextEditingController _transFonctionCtrl;
  late final TextEditingController _transTelephoneCtrl;
  late final TextEditingController _transPosteCtrl;
  late final TextEditingController _transEmailCtrl;

  // Controllers Certification
  late final TextEditingController _certifNous1Ctrl;
  late final TextEditingController _certifNous2Ctrl;

  // Controllers Signatures
  late final TextEditingController _sign1CodeCtrl;
  late final TextEditingController _sign1FonctionCtrl;
  late final TextEditingController _sign1DateCtrl;

  late final TextEditingController _sign2CodeCtrl;
  late final TextEditingController _sign2FonctionCtrl;
  late final TextEditingController _sign2DateCtrl;

  // Signature drawings
  Uint8List? _signature1;
  Uint8List? _signature2;

  // Whether to show the drawing pad (true) or the saved image (false)
  bool _dessiner1 = true;
  bool _dessiner2 = true;

  bool _chargement = false;
  String? _erreur;
  String? _succes;

  @override
  void initState() {
    super.initState();
    final a = widget.attestation;
    _rensPrenomsNomCtrl = TextEditingController(text: a.rensPrenomsNom);
    _rensFonctionCtrl = TextEditingController(text: a.rensFonction);
    _rensTelephoneCtrl = TextEditingController(text: a.rensTelephone);
    _rensPosteCtrl = TextEditingController(text: a.rensPoste);
    _rensEmailCtrl = TextEditingController(text: a.rensEmail);

    _transPrenomsNomCtrl = TextEditingController(text: a.transPrenomsNom);
    _transFonctionCtrl = TextEditingController(text: a.transFonction);
    _transTelephoneCtrl = TextEditingController(text: a.transTelephone);
    _transPosteCtrl = TextEditingController(text: a.transPoste);
    _transEmailCtrl = TextEditingController(text: a.transEmail);

    _certifNous1Ctrl = TextEditingController(text: a.certifNous1);
    _certifNous2Ctrl = TextEditingController(text: a.certifNous2);

    final aujourdhui = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _sign1CodeCtrl = TextEditingController(text: a.sign1Code);
    _sign1FonctionCtrl = TextEditingController(text: a.sign1Fonction);
    _sign1DateCtrl = TextEditingController(text: a.sign1Date.isNotEmpty ? a.sign1Date : aujourdhui);

    _sign2CodeCtrl = TextEditingController(text: a.sign2Code);
    _sign2FonctionCtrl = TextEditingController(text: a.sign2Fonction);
    _sign2DateCtrl = TextEditingController(text: a.sign2Date.isNotEmpty ? a.sign2Date : aujourdhui);

    if (a.sign1Image.isNotEmpty) {
      try {
        _signature1 = base64Decode(a.sign1Image);
        _dessiner1 = false;
      } catch (_) {}
    }
    if (a.sign2Image.isNotEmpty) {
      try {
        _signature2 = base64Decode(a.sign2Image);
        _dessiner2 = false;
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(covariant FodepAttestationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attestation != oldWidget.attestation) {
      final a = widget.attestation;
      _rensPrenomsNomCtrl.text = a.rensPrenomsNom;
      _rensFonctionCtrl.text = a.rensFonction;
      _rensTelephoneCtrl.text = a.rensTelephone;
      _rensPosteCtrl.text = a.rensPoste;
      _rensEmailCtrl.text = a.rensEmail;

      _transPrenomsNomCtrl.text = a.transPrenomsNom;
      _transFonctionCtrl.text = a.transFonction;
      _transTelephoneCtrl.text = a.transTelephone;
      _transPosteCtrl.text = a.transPoste;
      _transEmailCtrl.text = a.transEmail;

      _certifNous1Ctrl.text = a.certifNous1;
      _certifNous2Ctrl.text = a.certifNous2;

      _sign1CodeCtrl.text = a.sign1Code;
      _sign1FonctionCtrl.text = a.sign1Fonction;
      _sign1DateCtrl.text = a.sign1Date;

      _sign2CodeCtrl.text = a.sign2Code;
      _sign2FonctionCtrl.text = a.sign2Fonction;
      _sign2DateCtrl.text = a.sign2Date;
      
      if (a.sign1Image.isNotEmpty) {
        try {
          _signature1 = base64Decode(a.sign1Image);
          _dessiner1 = false;
        } catch (_) {}
      } else {
        _signature1 = null;
        _dessiner1 = true;
      }
      
      if (a.sign2Image.isNotEmpty) {
        try {
          _signature2 = base64Decode(a.sign2Image);
          _dessiner2 = false;
        } catch (_) {}
      } else {
        _signature2 = null;
        _dessiner2 = true;
      }
    }
  }

  @override
  void dispose() {
    _rensPrenomsNomCtrl.dispose();
    _rensFonctionCtrl.dispose();
    _rensTelephoneCtrl.dispose();
    _rensPosteCtrl.dispose();
    _rensEmailCtrl.dispose();

    _transPrenomsNomCtrl.dispose();
    _transFonctionCtrl.dispose();
    _transTelephoneCtrl.dispose();
    _transPosteCtrl.dispose();
    _transEmailCtrl.dispose();

    _certifNous1Ctrl.dispose();
    _certifNous2Ctrl.dispose();

    _sign1CodeCtrl.dispose();
    _sign1FonctionCtrl.dispose();
    _sign1DateCtrl.dispose();

    _sign2CodeCtrl.dispose();
    _sign2FonctionCtrl.dispose();
    _sign2DateCtrl.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    setState(() {
      _chargement = true;
      _erreur = null;
      _succes = null;
    });
    try {
      final result = await widget.service.enregistrerAttestation(
        AttestationFodep(
          rensPrenomsNom: _rensPrenomsNomCtrl.text.trim(),
          rensFonction: _rensFonctionCtrl.text.trim(),
          rensTelephone: _rensTelephoneCtrl.text.trim(),
          rensPoste: _rensPosteCtrl.text.trim(),
          rensEmail: _rensEmailCtrl.text.trim(),
          transPrenomsNom: _transPrenomsNomCtrl.text.trim(),
          transFonction: _transFonctionCtrl.text.trim(),
          transTelephone: _transTelephoneCtrl.text.trim(),
          transPoste: _transPosteCtrl.text.trim(),
          transEmail: _transEmailCtrl.text.trim(),
          certifNous1: _certifNous1Ctrl.text.trim(),
          certifNous2: _certifNous2Ctrl.text.trim(),
          sign1Code: _sign1CodeCtrl.text.trim(),
          sign1Fonction: _sign1FonctionCtrl.text.trim(),
          sign1Date: _sign1DateCtrl.text.trim(),
          sign1Image: _signature1 != null ? base64Encode(_signature1!) : '',
          sign2Code: _sign2CodeCtrl.text.trim(),
          sign2Fonction: _sign2FonctionCtrl.text.trim(),
          sign2Date: _sign2DateCtrl.text.trim(),
          sign2Image: _signature2 != null ? base64Encode(_signature2!) : '',
        ),
      );
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _succes = 'Attestation enregistrée avec succès (modèle BCEAO).';
      });
      widget.onSaved?.call();
      // ignore: unused_local_variable
      final _ = result;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Enregistrement impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Renseignez l\'attestation selon le modèle officiel BCEAO.',
          style: TextStyle(fontSize: 12.5, height: 1.45, color: c.muted),
        ),
        const SizedBox(height: 20),
        _formulaireBceao(c),
        if (_erreur != null) ...[
          const SizedBox(height: 16),
          FodepNotice(
            status: DashStatus.sousMinimum,
            texte: _erreur!,
            onClose: () => setState(() => _erreur = null),
          ),
        ],
        if (_succes != null) ...[
          const SizedBox(height: 16),
          FodepNotice(
            status: DashStatus.conforme,
            texte: _succes!,
            onClose: () => setState(() => _succes = null),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _chargement ? null : _sauvegarder,
              icon: _chargement
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_user_rounded, size: 17),
              label: Text(_chargement ? 'Enregistrement…' : 'Enregistrer l\'attestation'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _formulaireBceao(DashColors c) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ATTESTATION DE DECLARATION PRUDENTIELLE',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildPersonneBlock(
            'Personne-responsable du renseignement du FODEP :',
            _rensPrenomsNomCtrl, _rensFonctionCtrl, _rensTelephoneCtrl, _rensPosteCtrl, _rensEmailCtrl,
          ),
          const SizedBox(height: 24),
          _buildPersonneBlock(
            'Personne-responsable de la transmission du FODEP à la plateforme de reporting BCEAO',
            _transPrenomsNomCtrl, _transFonctionCtrl, _transTelephoneCtrl, _transPosteCtrl, _transEmailCtrl,
          ),
          const SizedBox(height: 24),
          const Text('CERTIFICATION', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Nous, '),
              Expanded(child: _bceaoTextField(_certifNous1Ctrl)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('et'),
              ),
              Expanded(child: _bceaoTextField(_certifNous2Ctrl)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'certifions que le présent formulaire a été rempli conformément aux exigences du dispositif prudentiel applicable aux établissements de crédit et aux compagnies financières de l\'Union Monétaire Ouest Africaine.\n\nEn outre, nous attestons qu\'au meilleur de notre connaissance, les données contenues dans le présent formulaire sont fiables, intègres et exhaustives.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 32),
          // --- Signataire 1 ---
          const Text('Signataire 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSignatureBlock(_sign1CodeCtrl, _sign1FonctionCtrl, _sign1DateCtrl),
          const SizedBox(height: 12),
          _buildSignaturePad(
            signature: _signature1,
            dessiner: _dessiner1,
            onChanged: (bytes) => setState(() => _signature1 = bytes),
            onEffacer: () => setState(() { _signature1 = null; _dessiner1 = true; }),
            onModifier: () => setState(() => _dessiner1 = true),
          ),
          const SizedBox(height: 24),
          // --- Signataire 2 ---
          const Text('Signataire 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSignatureBlock(_sign2CodeCtrl, _sign2FonctionCtrl, _sign2DateCtrl),
          const SizedBox(height: 12),
          _buildSignaturePad(
            signature: _signature2,
            dessiner: _dessiner2,
            onChanged: (bytes) => setState(() => _signature2 = bytes),
            onEffacer: () => setState(() { _signature2 = null; _dessiner2 = true; }),
            onModifier: () => setState(() => _dessiner2 = true),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonneBlock(String title, TextEditingController nom, TextEditingController fonction, TextEditingController tel, TextEditingController poste, TextEditingController email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 12),
        _buildRow('Prénoms et Nom :', nom),
        const SizedBox(height: 8),
        _buildRow('Fonction :', fonction),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 2, child: _buildRow('Téléphone :', tel)),
            const SizedBox(width: 16),
            Expanded(flex: 1, child: _buildRow('Poste :', poste)),
          ],
        ),
        const SizedBox(height: 8),
        _buildRow('E-mail :', email),
      ],
    );
  }

  Widget _buildRow(String label, TextEditingController ctrl) {
    return Row(
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(child: _bceaoTextField(ctrl)),
      ],
    );
  }

  Widget _buildSignatureBlock(TextEditingController code, TextEditingController fonction, TextEditingController date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 130, child: Text('Code Signature :', style: TextStyle(fontSize: 11))),
            Expanded(flex: 1, child: _bceaoTextField(code)),
            const Spacer(flex: 2),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildRow('Fonction :', fonction)),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 50, child: Text('Date :', style: TextStyle(fontSize: 11))),
                  Expanded(child: _bceaoDateField(date)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Zone de dessin de signature avec boutons Effacer / Importer / Modifier.
  Widget _buildSignaturePad({
    required Uint8List? signature,
    required bool dessiner,
    required ValueChanged<Uint8List?> onChanged,
    required VoidCallback onEffacer,
    required VoidCallback onModifier,
  }) {
    final c = DashColors.of(context);

    Future<void> importerImage() async {
      final fichier = await openFiles(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg']),
        ],
      );
      if (fichier.isEmpty) return;
      final bytes = await fichier.first.readAsBytes();
      onChanged(bytes);
    }

    if (dessiner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FodepSignaturePad(
            height: 120,
            initialImage: signature,
            onChanged: onChanged,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: importerImage,
                icon: const Icon(Icons.upload_file_outlined, size: 14),
                label: const Text('Importer', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: _navy),
              ),
              if (signature != null)
                TextButton.icon(
                  onPressed: onEffacer,
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('Effacer', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
            ],
          ),
        ],
      );
    }

    // Show the captured image with Modifier / Importer / Effacer buttons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (signature != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: c.border, width: Dash.hairline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.memory(signature, height: 90, fit: BoxFit.contain),
          )
        else
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: c.border, width: Dash.hairline),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('Aucune signature', style: TextStyle(fontSize: 11, color: c.muted)),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: onModifier,
              icon: const Icon(Icons.draw_outlined, size: 14),
              label: const Text('Dessiner', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: c.muted),
            ),
            TextButton.icon(
              onPressed: importerImage,
              icon: const Icon(Icons.upload_file_outlined, size: 14),
              label: const Text('Importer', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: _navy),
            ),
            if (signature != null)
              TextButton.icon(
                onPressed: onEffacer,
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('Effacer', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bceaoTextField(TextEditingController controller) {
    return Container(
      height: 24,
      color: const Color(0xFFFFF7DB),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 11),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
          isDense: true,
        ),
      ),
    );
  }

  /// Champ date cliquable avec date picker.
  Widget _bceaoDateField(TextEditingController controller) {
    return GestureDetector(
      onTap: () async {
        // Parse current value or default to today
        DateTime initial = DateTime.now();
        try {
          if (controller.text.isNotEmpty) {
            initial = DateFormat('yyyy-MM-dd').parse(controller.text);
          }
        } catch (_) {}

        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: const Locale('fr', 'FR'),
        );
        if (picked != null) {
          controller.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      },
      child: AbsorbPointer(
        child: Container(
          height: 24,
          color: const Color(0xFFFFF7DB),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
              isDense: true,
              suffixIcon: Icon(Icons.calendar_today, size: 13),
              suffixIconConstraints: BoxConstraints(maxWidth: 24, maxHeight: 24),
            ),
          ),
        ),
      ),
    );
  }
}
