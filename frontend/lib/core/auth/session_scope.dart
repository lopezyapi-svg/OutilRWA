import 'package:flutter/material.dart';

import 'session_controller.dart';

/// Rend la session accessible depuis n'importe quel écran.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SessionScope>()
        ?.notifier;
  }

  /// Droit d'écriture de l'utilisateur courant.
  ///
  /// Hors de toute session (tests de widgets, application de bureau montée
  /// sans portée), la réponse est « oui » : l'absence d'authentification
  /// signifie un usage local, pas un utilisateur bridé. C'est le serveur qui
  /// tranche de toute façon — ce drapeau ne fait que masquer l'inutile.
  static bool peutEditer(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null || !controller.authentificationRequise) {
      return true;
    }
    return controller.peutEditer;
  }
}

/// N'affiche son contenu qu'aux comptes disposant du droit d'édition.
///
/// Masquer une action ne la protège pas : le garde du backend refuse la
/// requête de toute façon. Ce widget évite seulement de proposer un bouton
/// qui finirait en message d'erreur.
class EditionSeulement extends StatelessWidget {
  const EditionSeulement({
    super.key,
    required this.child,
    this.remplacement,
  });

  final Widget child;

  /// Affiché à la place du contenu pour un compte en consultation. Par défaut
  /// rien du tout.
  final Widget? remplacement;

  @override
  Widget build(BuildContext context) {
    if (SessionScope.peutEditer(context)) {
      return child;
    }
    return remplacement ?? const SizedBox.shrink();
  }
}

/// Bandeau discret rappelant que le compte est en lecture seule.
class BandeauConsultation extends StatelessWidget {
  const BandeauConsultation({super.key});

  @override
  Widget build(BuildContext context) {
    if (SessionScope.peutEditer(context)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Consultation',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
