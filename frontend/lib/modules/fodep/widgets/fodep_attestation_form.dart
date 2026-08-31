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

/// Formulaire d'attestation de déclaration prudentielle (modèle BCEAO).
///
/// Parcours : on renseigne les deux responsables et la certification, on appose
/// les signatures dans une boîte de dialogue dédiée, puis « Vérifier et
/// enregistrer » ouvre un récapitulatif à confirmer avant l'envoi.
class FodepAttestationForm extends StatefulWidget {
  const FodepAttestationForm({
    super.key,
    required this.service,
    required this.attestation,
    this.etablissement,
    this.periode,
    this.onSaved,
    this.onDirtyChanged,
  });

  final FodepService service;
  final AttestationFodep attestation;
  final EtablissementView? etablissement;
  final String? periode;
  final VoidCallback? onSaved;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<FodepAttestationForm> createState() => _FodepAttestationFormState();
}

class _FodepAttestationFormState extends State<FodepAttestationForm> {
  // ── Renseignement ────────────────────────────────────────────────────────
  final _rensNom = TextEditingController();
  final _rensFonction = TextEditingController();
  final _rensTel = TextEditingController();
  final _rensPoste = TextEditingController();
  final _rensEmail = TextEditingController();

  // ── Transmission ─────────────────────────────────────────────────────────
  final _transNom = TextEditingController();
  final _transFonction = TextEditingController();
  final _transTel = TextEditingController();
  final _transPoste = TextEditingController();
  final _transEmail = TextEditingController();

  // ── Certification ────────────────────────────────────────────────────────
  final _certif1 = TextEditingController();
  final _certif2 = TextEditingController();

  // ── Signatures ───────────────────────────────────────────────────────────
  final _sign1Code = TextEditingController();
  final _sign1Fonction = TextEditingController();
  final _sign1Date = TextEditingController();
  final _sign2Code = TextEditingController();
  final _sign2Fonction = TextEditingController();
  final _sign2Date = TextEditingController();
  Uint8List? _signature1;
  Uint8List? _signature2;

  static const _texteCertification =
      'certifions que le présent formulaire a été rempli conformément aux '
      'exigences du dispositif prudentiel applicable aux établissements de '
      "crédit et aux compagnies financières de l'Union Monétaire Ouest "
      "Africaine.\n\nEn outre, nous attestons qu'au meilleur de notre "
      'connaissance, les données contenues dans le présent formulaire sont '
      'fiables, intègres et exhaustives.';

  late String _reference; // signature-valeur de l'état enregistré
  final _erreurs = <String, String>{};
  bool _chargement = false;

  List<TextEditingController> get _tous => [
        _rensNom, _rensFonction, _rensTel, _rensPoste, _rensEmail,
        _transNom, _transFonction, _transTel, _transPoste, _transEmail,
        _certif1, _certif2,
        _sign1Code, _sign1Fonction, _sign1Date,
        _sign2Code, _sign2Fonction, _sign2Date,
      ];

  @override
  void initState() {
    super.initState();
    _hydrater(widget.attestation);
    _reference = _modele().signatureValeur;
    for (final c in _tous) {
      c.addListener(_recalculerDirty);
    }
  }

  @override
  void didUpdateWidget(covariant FodepAttestationForm old) {
    super.didUpdateWidget(old);
    if (widget.attestation.signatureValeur != old.attestation.signatureValeur) {
      _hydrater(widget.attestation);
      _reference = _modele().signatureValeur;
      _erreurs.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _recalculerDirty());
    }
  }

  @override
  void dispose() {
    for (final c in _tous) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrater(AttestationFodep a) {
    _rensNom.text = a.rensPrenomsNom;
    _rensFonction.text = a.rensFonction;
    _rensTel.text = a.rensTelephone;
    _rensPoste.text = a.rensPoste;
    _rensEmail.text = a.rensEmail;

    _transNom.text = a.transPrenomsNom;
    _transFonction.text = a.transFonction;
    _transTel.text = a.transTelephone;
    _transPoste.text = a.transPoste;
    _transEmail.text = a.transEmail;

    _certif1.text = a.certifNous1;
    _certif2.text = a.certifNous2;

    final parDefaut = widget.periode?.trim().isNotEmpty == true
        ? widget.periode!.trim()
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    _sign1Code.text = a.sign1Code;
    _sign1Fonction.text = a.sign1Fonction;
    _sign1Date.text = a.sign1Date.isNotEmpty ? a.sign1Date : parDefaut;
    _sign2Code.text = a.sign2Code;
    _sign2Fonction.text = a.sign2Fonction;
    _sign2Date.text = a.sign2Date.isNotEmpty ? a.sign2Date : parDefaut;

    _signature1 = _decoder(a.sign1Image);
    _signature2 = _decoder(a.sign2Image);
  }

  Uint8List? _decoder(String b64) {
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  AttestationFodep _modele() => AttestationFodep(
        rensPrenomsNom: _rensNom.text.trim(),
        rensFonction: _rensFonction.text.trim(),
        rensTelephone: _rensTel.text.trim(),
        rensPoste: _rensPoste.text.trim(),
        rensEmail: _rensEmail.text.trim(),
        transPrenomsNom: _transNom.text.trim(),
        transFonction: _transFonction.text.trim(),
        transTelephone: _transTel.text.trim(),
        transPoste: _transPoste.text.trim(),
        transEmail: _transEmail.text.trim(),
        certifNous1: _certif1.text.trim(),
        certifNous2: _certif2.text.trim(),
        sign1Code: _sign1Code.text.trim(),
        sign1Fonction: _sign1Fonction.text.trim(),
        sign1Date: _sign1Date.text.trim(),
        sign1Image: _signature1 != null ? base64Encode(_signature1!) : '',
        sign2Code: _sign2Code.text.trim(),
        sign2Fonction: _sign2Fonction.text.trim(),
        sign2Date: _sign2Date.text.trim(),
        sign2Image: _signature2 != null ? base64Encode(_signature2!) : '',
      );

  bool get _dirty => _modele().signatureValeur != _reference;

  void _recalculerDirty() {
    widget.onDirtyChanged?.call(_dirty);
    // Une saisie après un contrôle en échec efface les messages d'erreur.
    if (_erreurs.isNotEmpty) setState(_erreurs.clear);
  }

  // ── Validation ───────────────────────────────────────────────────────────

  static final _reEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool _valider() {
    final e = <String, String>{};
    void requis(String cle, TextEditingController c, [String msg = 'Champ requis.']) {
      if (c.text.trim().isEmpty) e[cle] = msg;
    }

    requis('rensNom', _rensNom);
    requis('rensFonction', _rensFonction);
    if (_rensEmail.text.trim().isEmpty) {
      e['rensEmail'] = 'Champ requis.';
    } else if (!_reEmail.hasMatch(_rensEmail.text.trim())) {
      e['rensEmail'] = 'Adresse e-mail invalide.';
    }

    requis('transNom', _transNom);
    requis('transFonction', _transFonction);
    if (_transEmail.text.trim().isEmpty) {
      e['transEmail'] = 'Champ requis.';
    } else if (!_reEmail.hasMatch(_transEmail.text.trim())) {
      e['transEmail'] = 'Adresse e-mail invalide.';
    }

    requis('certif1', _certif1, 'Nom du premier certificateur requis.');
    requis('sign1Code', _sign1Code);
    requis('sign1Fonction', _sign1Fonction);
    requis('sign1Date', _sign1Date);

    setState(() {
      _erreurs
        ..clear()
        ..addAll(e);
    });
    return e.isEmpty;
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _reprendreCoordonnees() {
    setState(() {
      _transNom.text = _rensNom.text;
      _transFonction.text = _rensFonction.text;
      _transTel.text = _rensTel.text;
      _transPoste.text = _rensPoste.text;
      _transEmail.text = _rensEmail.text;
    });
  }

  void _reinitialiser() {
    _hydrater(widget.attestation);
    setState(() => _erreurs.clear());
    _recalculerDirty();
  }

  Future<void> _choisirDate(TextEditingController ctrl) async {
    DateTime? initiale;
    try {
      if (ctrl.text.isNotEmpty) initiale = DateFormat('yyyy-MM-dd').parse(ctrl.text);
    } catch (_) {}
    final choisie = await pickFodepDate(context: context, initiale: initiale);
    if (choisie != null) {
      ctrl.text = DateFormat('yyyy-MM-dd').format(choisie);
      _recalculerDirty();
    }
  }

  Future<void> _apposerSignature(int index) async {
    final actuelle = index == 1 ? _signature1 : _signature2;
    final resultat = await showFodepDialog<_ResultatSignature>(
      context: context,
      eyebrow: 'Signataire $index',
      titre: 'Apposer la signature',
      maxWidth: 520,
      contenu: _DialogueSignature(initiale: actuelle),
      actions: const [], // les actions sont gérées dans le contenu
    );
    if (resultat == null) return;
    setState(() {
      if (resultat.effacee) {
        if (index == 1) {
          _signature1 = null;
        } else {
          _signature2 = null;
        }
      } else if (resultat.bytes != null) {
        if (index == 1) {
          _signature1 = resultat.bytes;
        } else {
          _signature2 = resultat.bytes;
        }
      }
    });
    _recalculerDirty();
  }

  Future<void> _verifierEtEnregistrer() async {
    if (!_valider()) {
      showFodepToast(context, 'Certains champs obligatoires sont incomplets.',
          status: DashStatus.sousMinimum);
      return;
    }
    final confirme = await showFodepDialog<bool>(
      context: context,
      eyebrow: 'Contrôle avant enregistrement',
      titre: 'Attestation de déclaration prudentielle',
      maxWidth: 620,
      contenu: _Recapitulatif(
        modele: _modele(),
        etablissement: widget.etablissement,
        periode: widget.periode,
        texteCertification: _texteCertification,
        signature1: _signature1,
        signature2: _signature2,
      ),
      actions: [
        Builder(
          builder: (ctx) => fodepGhostButton(
            context: ctx,
            label: 'Modifier',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => fodepPrimaryButton(
            context: ctx,
            label: 'Confirmer et enregistrer',
            icon: Icons.verified_user_rounded,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    );
    if (confirme == true) await _enregistrer();
  }

  Future<void> _enregistrer() async {
    setState(() => _chargement = true);
    try {
      await widget.service.enregistrerAttestation(_modele());
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _reference = _modele().signatureValeur;
      });
      widget.onDirtyChanged?.call(false);
      widget.onSaved?.call();
      showFodepToast(context, 'Attestation enregistrée (modèle BCEAO).');
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      showFodepToast(context, 'Enregistrement impossible : $e',
          status: DashStatus.sousMinimum);
    }
  }

  // ── Rendu ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final nomEtab = widget.etablissement?.denomination.trim().isNotEmpty == true
        ? widget.etablissement!.denomination.trim()
        : "L'établissement assujetti";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$nomEtab — attestation à joindre à la déclaration transmise à la '
          "BCEAO et à la Commission Bancaire de l'UMOA.",
          style: DashText.caption(c, color: c.muted).copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),

        FodepFormSection(
          ordre: '1',
          titre: 'Personne responsable du renseignement du FODEP',
          child: _blocPersonne(
            nom: _rensNom, cleNom: 'rensNom',
            fonction: _rensFonction, cleFonction: 'rensFonction',
            tel: _rensTel, poste: _rensPoste,
            email: _rensEmail, cleEmail: 'rensEmail',
          ),
        ),
        const SizedBox(height: 30),

        FodepFormSection(
          ordre: '2',
          titre: 'Personne responsable de la transmission à la plateforme BCEAO',
          action: fodepGhostButton(
            context: context,
            label: 'Reprendre le nº 1',
            icon: Icons.copy_all_rounded,
            onPressed: _reprendreCoordonnees,
          ),
          child: _blocPersonne(
            nom: _transNom, cleNom: 'transNom',
            fonction: _transFonction, cleFonction: 'transFonction',
            tel: _transTel, poste: _transPoste,
            email: _transEmail, cleEmail: 'transEmail',
          ),
        ),
        const SizedBox(height: 30),

        FodepFormSection(
          ordre: '3',
          titre: 'Certification',
          consigne: 'Identité des personnes qui engagent l\'établissement.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(builder: (context, cx) {
                final large = cx.maxWidth >= 460;
                final champs = [
                  Expanded(
                    flex: large ? 1 : 0,
                    child: FodepField(
                      label: 'Nous, (1)',
                      controller: _certif1,
                      requis: true,
                      error: _erreurs['certif1'],
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  SizedBox(width: large ? 16 : 0, height: large ? 0 : 14),
                  Expanded(
                    flex: large ? 1 : 0,
                    child: FodepField(
                      label: 'et (2)',
                      controller: _certif2,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ];
                return large
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: champs)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: champs);
              }),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(Dash.radius),
                  border: Border(left: BorderSide(color: c.navy, width: 2)),
                ),
                child: Text(
                  _texteCertification,
                  style: DashText.value(c, color: c.muted, weight: FontWeight.w500)
                      .copyWith(fontSize: 12, height: 1.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        FodepFormSection(
          ordre: '4',
          titre: 'Signatures et cachet',
          consigne: 'Le signataire nº 1 est obligatoire ; le nº 2 (commissaire '
              'aux comptes) est facultatif.',
          child: LayoutBuilder(builder: (context, cx) {
            final large = cx.maxWidth >= 560;
            final cartes = [
              Expanded(
                flex: large ? 1 : 0,
                child: _carteSignataire(
                  index: 1,
                  code: _sign1Code, fonction: _sign1Fonction, date: _sign1Date,
                  signature: _signature1,
                  cleCode: 'sign1Code', cleFonction: 'sign1Fonction', cleDate: 'sign1Date',
                ),
              ),
              SizedBox(width: large ? 16 : 0, height: large ? 0 : 16),
              Expanded(
                flex: large ? 1 : 0,
                child: _carteSignataire(
                  index: 2,
                  code: _sign2Code, fonction: _sign2Fonction, date: _sign2Date,
                  signature: _signature2,
                ),
              ),
            ];
            return large
                ? IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cartes))
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cartes);
          }),
        ),
        const SizedBox(height: 26),

        Row(
          children: [
            if (_dirty)
              Expanded(
                child: Text(
                  'Modifications non enregistrées.',
                  style: DashText.caption(c, color: c.status(DashStatus.sousCible)),
                ),
              )
            else
              const Spacer(),
            if (_dirty) ...[
              fodepGhostButton(
                context: context,
                label: 'Réinitialiser',
                onPressed: _chargement ? null : _reinitialiser,
              ),
              const SizedBox(width: 10),
            ],
            fodepPrimaryButton(
              context: context,
              label: 'Vérifier et enregistrer',
              icon: Icons.verified_user_rounded,
              busy: _chargement,
              onPressed: _verifierEtEnregistrer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _blocPersonne({
    required TextEditingController nom,
    required String cleNom,
    required TextEditingController fonction,
    required String cleFonction,
    required TextEditingController tel,
    required TextEditingController poste,
    required TextEditingController email,
    required String cleEmail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, cx) {
          final large = cx.maxWidth >= 460;
          final ligne1 = [
            Expanded(
              flex: large ? 3 : 0,
              child: FodepField(
                label: 'Prénoms et Nom', controller: nom, requis: true,
                error: _erreurs[cleNom], textCapitalization: TextCapitalization.words,
              ),
            ),
            SizedBox(width: large ? 16 : 0, height: large ? 0 : 14),
            Expanded(
              flex: large ? 2 : 0,
              child: FodepField(
                label: 'Fonction', controller: fonction, requis: true,
                error: _erreurs[cleFonction], textCapitalization: TextCapitalization.words,
              ),
            ),
          ];
          return large
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: ligne1)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: ligne1);
        }),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, cx) {
          final large = cx.maxWidth >= 460;
          final ligne2 = [
            Expanded(
              flex: large ? 2 : 0,
              child: FodepField(
                label: 'Téléphone', controller: tel,
                keyboardType: TextInputType.phone, suffixIcon: Icons.call_outlined,
              ),
            ),
            SizedBox(width: large ? 16 : 0, height: large ? 0 : 14),
            Expanded(
              flex: large ? 1 : 0,
              child: FodepField(label: 'Poste', controller: poste),
            ),
          ];
          return large
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: ligne2)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: ligne2);
        }),
        const SizedBox(height: 14),
        FodepField(
          label: 'E-mail', controller: email, requis: true,
          error: _erreurs[cleEmail], keyboardType: TextInputType.emailAddress,
          suffixIcon: Icons.alternate_email_rounded,
        ),
      ],
    );
  }

  Widget _carteSignataire({
    required int index,
    required TextEditingController code,
    required TextEditingController fonction,
    required TextEditingController date,
    required Uint8List? signature,
    String? cleCode,
    String? cleFonction,
    String? cleDate,
  }) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('SIGNATAIRE $index', style: DashText.eyebrow(c, color: c.navy)),
              const Spacer(),
              if (index == 2)
                Text('facultatif', style: DashText.caption(c, color: c.faint)),
            ],
          ),
          const SizedBox(height: 14),
          FodepField(
            label: 'Code signature', controller: code,
            requis: index == 1, error: cleCode == null ? null : _erreurs[cleCode],
          ),
          const SizedBox(height: 12),
          FodepField(
            label: 'Fonction', controller: fonction,
            requis: index == 1, error: cleFonction == null ? null : _erreurs[cleFonction],
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          FodepField(
            label: 'Date', controller: date, requis: index == 1,
            error: cleDate == null ? null : _erreurs[cleDate],
            readOnly: true, onTap: () => _choisirDate(date),
            suffixIcon: Icons.event_outlined,
          ),
          const SizedBox(height: 14),
          _zoneSignature(index, signature),
        ],
      ),
    );
  }

  Widget _zoneSignature(int index, Uint8List? signature) {
    final c = DashColors.of(context);
    if (signature != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 96,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(Dash.radius),
              border: Border.all(color: c.border, width: Dash.hairline),
            ),
            child: Image.memory(signature, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: fodepGhostButton(
              context: context,
              label: 'Remplacer',
              icon: Icons.gesture_rounded,
              onPressed: () => _apposerSignature(index),
            ),
          ),
        ],
      );
    }
    return InkWell(
      onTap: () => _apposerSignature(index),
      borderRadius: BorderRadius.circular(Dash.radius),
      child: Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Dash.radius),
          border: Border.all(color: c.border, width: Dash.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gesture_rounded, size: 20, color: c.muted),
            const SizedBox(height: 6),
            Text('Apposer la signature', style: DashText.caption(c, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Boîte de dialogue : capture de signature
// ═══════════════════════════════════════════════════════════════════════════

class _ResultatSignature {
  const _ResultatSignature({this.bytes, this.effacee = false});
  final Uint8List? bytes;
  final bool effacee;
}

class _DialogueSignature extends StatefulWidget {
  const _DialogueSignature({this.initiale});
  final Uint8List? initiale;

  @override
  State<_DialogueSignature> createState() => _DialogueSignatureState();
}

class _DialogueSignatureState extends State<_DialogueSignature> {
  Uint8List? _courante;

  @override
  void initState() {
    super.initState();
    _courante = widget.initiale;
  }

  Future<void> _importer() async {
    final fichiers = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg']),
      ],
    );
    if (fichiers.isEmpty) return;
    final bytes = await fichiers.first.readAsBytes();
    if (mounted) setState(() => _courante = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tracez la signature à la souris ou au stylet, ou importez une image '
          '(fond transparent recommandé).',
          style: DashText.caption(c, color: c.muted).copyWith(height: 1.5),
        ),
        const SizedBox(height: 14),
        FodepSignaturePad(
          height: 190,
          initialImage: _courante,
          onChanged: (b) => _courante = b,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            fodepGhostButton(
              context: context,
              label: 'Importer une image',
              icon: Icons.image_outlined,
              onPressed: _importer,
            ),
            const Spacer(),
            fodepGhostButton(
              context: context,
              label: 'Retirer',
              icon: Icons.delete_outline_rounded,
              danger: true,
              onPressed: () =>
                  Navigator.of(context).pop(const _ResultatSignature(effacee: true)),
            ),
            const SizedBox(width: 10),
            fodepPrimaryButton(
              context: context,
              label: 'Valider',
              onPressed: () =>
                  Navigator.of(context).pop(_ResultatSignature(bytes: _courante)),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Boîte de dialogue : récapitulatif avant enregistrement
// ═══════════════════════════════════════════════════════════════════════════

class _Recapitulatif extends StatelessWidget {
  const _Recapitulatif({
    required this.modele,
    required this.etablissement,
    required this.periode,
    required this.texteCertification,
    required this.signature1,
    required this.signature2,
  });

  final AttestationFodep modele;
  final EtablissementView? etablissement;
  final String? periode;
  final String texteCertification;
  final Uint8List? signature1;
  final Uint8List? signature2;

  String get _dateArrete {
    final p = periode?.trim() ?? '';
    if (p.length == 10 && p[4] == '-') {
      final parts = p.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return p.isEmpty ? '—' : p;
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    Widget titre(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(t.toUpperCase(), style: DashText.eyebrow(c, color: c.navy)),
        );

    Widget signature(String label, Uint8List? img) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 150, child: Text(label, style: DashText.caption(c, color: c.muted))),
              const SizedBox(width: 12),
              Expanded(
                child: img == null
                    ? Text('Aucune signature manuscrite',
                        style: DashText.value(c, color: c.faint, weight: FontWeight.w600))
                    : Container(
                        height: 60,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(Dash.radius),
                          border: Border.all(color: c.border, width: Dash.hairline),
                        ),
                        child: Image.memory(img, fit: BoxFit.contain),
                      ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FodepRecapLigne(
          label: 'Établissement',
          valeur: etablissement?.denomination ?? '',
        ),
        FodepRecapLigne(label: 'Code BCEAO', valeur: etablissement?.codeBceao ?? ''),
        FodepRecapLigne(label: "Date d'arrêté", valeur: _dateArrete),

        titre('Renseignement du FODEP'),
        FodepRecapLigne(label: 'Prénoms et Nom', valeur: modele.rensPrenomsNom),
        FodepRecapLigne(label: 'Fonction', valeur: modele.rensFonction),
        FodepRecapLigne(label: 'Téléphone / Poste',
            valeur: [modele.rensTelephone, modele.rensPoste].where((s) => s.isNotEmpty).join(' · ')),
        FodepRecapLigne(label: 'E-mail', valeur: modele.rensEmail),

        titre('Transmission à la BCEAO'),
        FodepRecapLigne(label: 'Prénoms et Nom', valeur: modele.transPrenomsNom),
        FodepRecapLigne(label: 'Fonction', valeur: modele.transFonction),
        FodepRecapLigne(label: 'Téléphone / Poste',
            valeur: [modele.transTelephone, modele.transPoste].where((s) => s.isNotEmpty).join(' · ')),
        FodepRecapLigne(label: 'E-mail', valeur: modele.transEmail),

        titre('Certification'),
        FodepRecapLigne(
          label: 'Nous,',
          valeur: [modele.certifNous1, modele.certifNous2].where((s) => s.isNotEmpty).join(' et '),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(Dash.radius),
            border: Border(left: BorderSide(color: c.navy, width: 2)),
          ),
          child: Text(
            texteCertification,
            style: DashText.caption(c, color: c.muted).copyWith(fontSize: 11.5, height: 1.5),
          ),
        ),

        titre('Signataire 1'),
        FodepRecapLigne(label: 'Code / Fonction',
            valeur: [modele.sign1Code, modele.sign1Fonction].where((s) => s.isNotEmpty).join(' · ')),
        FodepRecapLigne(label: 'Date', valeur: modele.sign1Date),
        signature('Signature', signature1),

        titre('Signataire 2'),
        FodepRecapLigne(label: 'Code / Fonction',
            valeur: [modele.sign2Code, modele.sign2Fonction].where((s) => s.isNotEmpty).join(' · ')),
        FodepRecapLigne(label: 'Date', valeur: modele.sign2Date),
        signature('Signature', signature2),
      ],
    );
  }
}
