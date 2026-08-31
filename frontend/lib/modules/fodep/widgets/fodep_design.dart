// Composants visuels du module FODEP, alignés sur le système institutionnel
// du dashboard (dashboard_design.dart) : panneaux plats, filet fin, un seul
// accent navy, couleur réservée au statut réglementaire. Aucune icône
// décorative, aucun aplat de couleur par carte.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localization.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/fodep_models.dart';

/// Tuile de ratio prudentiel : même habillage que DashboardRatiosRow,
/// adapté aux ratios FODEP dont le seuil (pilier 1 + coussin) est déjà
/// fusionné côté backend.
class FodepRatioTile extends StatelessWidget {
  const FodepRatioTile({super.key, required this.label, required this.ratio});

  final String label;
  final RatioDetail ratio;

  DashStatus get _status {
    switch (ratio.status) {
      case 'Excédent':
        return DashStatus.conforme;
      case 'Sous cible':
        return DashStatus.sousCible;
      default:
        return DashStatus.sousMinimum;
    }
  }

  static String _fr(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final status = _status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: Dash.shadow(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: DashText.eyebrow(c, color: c.navy)),
          const SizedBox(height: 10),
          Text('${_fr(ratio.value)} %', style: DashText.hero(c, size: 20)),
          const SizedBox(height: 6),
          Text(
            'Seuil réglementaire : ${_fr(ratio.threshold)} %'.tr(context),
            style: DashText.caption(c),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 8),
          DashStatusTag(status: status, dense: true),
        ],
      ),
    );
  }
}

/// Tuile de valeur simple (fonds propres, APR) : même habillage, sans
/// statut.
class FodepValueTile extends StatelessWidget {
  const FodepValueTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: Dash.shadow(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: DashText.eyebrow(c, color: c.navy)),
          const SizedBox(height: 10),
          Text(value, style: DashText.hero(c, size: 18)),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: DashText.caption(c)),
          ],
        ],
      ),
    );
  }
}

/// Bandeau d'information/erreur/succès, plat, cohérent avec la palette de
/// statut du dashboard (aucune couleur inventée hors de DashColors).
class FodepNotice extends StatelessWidget {
  const FodepNotice({super.key, required this.status, required this.texte, this.onClose});

  final DashStatus status;
  final String texte;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final couleur = c.status(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: couleur.withValues(alpha: 0.4), width: Dash.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte, style: DashText.value(c, color: c.ink, weight: FontWeight.w500).copyWith(fontSize: 12)),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded, size: 16, color: c.muted),
            ),
          ]
        ],
      ),
    );
  }
}


/// Onglets sobres (texte seul, soulignement navy) pour naviguer entre les
/// groupes de postes DISPRU, sans icône ni couleur de statut.
class FodepTabs extends StatelessWidget {
  const FodepTabs({
    super.key,
    required this.onglets,
    required this.selection,
    required this.onSelect,
  });

  final List<MapEntry<String, String>> onglets; // (clé, libellé)
  final String selection;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in onglets)
              _Onglet(
                label: entry.value,
                selected: selection == entry.key,
                onTap: () => onSelect(entry.key),
                c: c,
              ),
          ],
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({required this.label, required this.selected, required this.onTap, required this.c});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final DashColors c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? c.navy : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.navy : c.muted,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Primitives de formulaire « document réglementaire »
// ═══════════════════════════════════════════════════════════════════════════

/// Section numérotée d'un formulaire : pastille d'ordre navy, sur-titre en
/// capitales, filet séparateur. Donne au formulaire une structure de document
/// plutôt qu'une pile de champs.
class FodepFormSection extends StatelessWidget {
  const FodepFormSection({
    super.key,
    required this.ordre,
    required this.titre,
    required this.child,
    this.consigne,
    this.action,
  });

  final String ordre;
  final String titre;
  final String? consigne;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.navy,
                borderRadius: BorderRadius.circular(Dash.radius),
              ),
              child: Text(
                ordre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(titre.toUpperCase(), style: DashText.eyebrow(c, color: c.navy)),
            ),
            if (action != null) action!,
          ],
        ),
        if (consigne != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(consigne!, style: DashText.caption(c, color: c.muted)),
          ),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, thickness: Dash.hairline, color: c.divider),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

/// Champ texte plat, aligné DashColors : libellé + astérisque si requis,
/// surface unie, filet fin, focus navy, message d'erreur discret. Remplace les
/// TextField/OutlineInputBorder génériques.
class FodepField extends StatefulWidget {
  const FodepField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.requis = false,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.suffixIcon,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final bool requis;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final IconData? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  State<FodepField> createState() => _FodepFieldState();
}

class _FodepFieldState extends State<FodepField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final aErreur = widget.error != null && widget.error!.isNotEmpty;
    final Color bordure = aErreur
        ? c.status(DashStatus.sousMinimum)
        : _focus.hasFocus
            ? c.navy
            : c.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: DashText.caption(c, color: c.muted).copyWith(fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: widget.label),
              if (widget.requis)
                TextSpan(text: '  *', style: TextStyle(color: c.status(DashStatus.sousMinimum))),
            ],
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.readOnly ? c.surfaceAlt : c.surface,
            borderRadius: BorderRadius.circular(Dash.radius),
            border: Border.all(color: bordure, width: _focus.hasFocus || aErreur ? 1.2 : Dash.hairline),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            textCapitalization: widget.textCapitalization,
            maxLines: widget.maxLines,
            cursorColor: c.navy,
            cursorWidth: 1.5,
            style: DashText.value(c, color: c.ink, weight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintStyle: DashText.caption(c, color: c.faint),
              contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
              border: InputBorder.none,
              suffixIcon: widget.suffixIcon == null
                  ? null
                  : Icon(widget.suffixIcon, size: 15, color: c.muted),
              suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          ),
        ),
        if (aErreur) ...[
          const SizedBox(height: 4),
          Text(
            widget.error!,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: c.status(DashStatus.sousMinimum),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bouton primaire institutionnel : aplat navy, coins nets, pas d'ombre.
Widget fodepPrimaryButton({
  required BuildContext context,
  required String label,
  required VoidCallback? onPressed,
  IconData? icon,
  bool busy = false,
}) {
  final c = DashColors.of(context);
  return FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: c.navy,
      foregroundColor: Colors.white,
      disabledBackgroundColor: c.navy.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dash.radius)),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const SizedBox(
            width: 13, height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        else if (icon != null)
          Icon(icon, size: 16),
        if (busy || icon != null) const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}

/// Bouton secondaire « fantôme » : texte navy, filet fin, fond transparent.
Widget fodepGhostButton({
  required BuildContext context,
  required String label,
  required VoidCallback? onPressed,
  IconData? icon,
  bool danger = false,
}) {
  final c = DashColors.of(context);
  final couleur = danger ? c.status(DashStatus.sousMinimum) : c.muted;
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: couleur,
      side: BorderSide(color: c.border, width: Dash.hairline),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dash.radius)),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 7)],
        Text(label),
      ],
    ),
  );
}

/// Boîte de dialogue institutionnelle : surface plate, filet fin, en-tête
/// eyebrow + titre, pas d'élévation « Material ». Remplace les AlertDialog
/// génériques.
Future<T?> showFodepDialog<T>({
  required BuildContext context,
  required String titre,
  required Widget contenu,
  required List<Widget> actions,
  String? eyebrow,
  double maxWidth = 560,
}) {
  final c = DashColors.of(context);
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Dialog(
      backgroundColor: c.surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.32),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dash.radiusLg),
        side: BorderSide(color: c.border, width: Dash.hairline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) ...[
                          Text(eyebrow.toUpperCase(), style: DashText.eyebrow(c, color: c.navy)),
                          const SizedBox(height: 5),
                        ],
                        Text(
                          titre,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 18, color: c.muted),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: Dash.hairline, color: c.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: contenu,
              ),
            ),
            if (actions.isNotEmpty) ...[
              Divider(height: 1, thickness: Dash.hairline, color: c.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Sélecteur de date thématisé (coins nets, en-tête navy, pas de pastel) —
/// évite le rendu Material par défaut.
Future<DateTime?> pickFodepDate({
  required BuildContext context,
  DateTime? initiale,
  DateTime? premiere,
  DateTime? derniere,
}) {
  final c = DashColors.of(context);
  final base = Theme.of(context);
  return showDatePicker(
    context: context,
    initialDate: initiale ?? DateTime.now(),
    firstDate: premiere ?? DateTime(2015),
    lastDate: derniere ?? DateTime(2100),
    locale: const Locale('fr', 'FR'),
    builder: (context, child) => Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: c.navy,
          onPrimary: Colors.white,
          surface: c.surface,
          onSurface: c.ink,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: c.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dash.radius),
            side: BorderSide(color: c.border, width: Dash.hairline),
          ),
          headerBackgroundColor: c.navy,
          headerForegroundColor: Colors.white,
          dividerColor: c.divider,
        ),
      ),
      child: child!,
    ),
  );
}

/// Toast plat, ancré en bas, un point de statut : succès/erreur transitoire
/// sans empiler des bandeaux dans la page.
void showFodepToast(
  BuildContext context,
  String message, {
  DashStatus status = DashStatus.conforme,
}) {
  final c = DashColors.of(context);
  final couleur = c.status(status);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface,
        elevation: 6,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dash.radius),
          side: BorderSide(color: couleur.withValues(alpha: 0.5), width: Dash.hairline),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Paire libellé / valeur pour les récapitulatifs en boîte de dialogue.
class FodepRecapLigne extends StatelessWidget {
  const FodepRecapLigne({super.key, required this.label, required this.valeur});

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final vide = valeur.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: DashText.caption(c, color: c.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              vide ? '—' : valeur,
              style: DashText.value(
                c,
                color: vide ? c.faint : c.ink,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
