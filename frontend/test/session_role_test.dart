// Le rôle « consultation » ne doit jamais se voir proposer une action que le
// serveur refusera. Le masquage n'est pas une protection — le garde du backend
// l'est — mais une interface qui propose des impasses n'est pas utilisable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:rwa_calculator/core/auth/session_controller.dart';
import 'package:rwa_calculator/core/auth/session_scope.dart';

/// Client qui répond ce qu'on lui dit, sans réseau.
class _ClientFactice extends http.BaseClient {
  _ClientFactice(this.reponses);

  /// Chemin -> (code, corps JSON)
  final Map<String, (int, String)> reponses;
  final List<String> appels = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final chemin = request.url.path;
    appels.add('${request.method} $chemin');
    final (code, corps) = reponses[chemin] ?? (404, '{}');
    return http.StreamedResponse(
      Stream.value(corps.codeUnits),
      code,
      request: request,
    );
  }
}

Future<SessionController> _sessionAvecRole(String role) async {
  final controller = SessionController(
    baseUrl: 'http://test',
    client: _ClientFactice({
      '/auth/me': (401, '{}'),
      '/auth/refresh': (
        200,
        '{"access_token":"jeton","expires_in":3600,'
            '"profil":{"identifiant":"u","role":"$role"}}'
      ),
    }),
  );
  await controller.initialiser();
  return controller;
}

Widget _sous(SessionController session, Widget child) {
  return MaterialApp(
    home: SessionScope(
      controller: session,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('état de session', () {
    test('sans authentification exigée, la session est ouverte en édition', () async {
      final controller = SessionController(
        baseUrl: 'http://test',
        client: _ClientFactice({
          '/auth/me': (200, '{"identifiant":"local","role":"edition"}'),
        }),
      );
      await controller.initialiser();

      expect(controller.authentificationRequise, isFalse);
      expect(controller.etat, SessionState.connecte);
      expect(controller.peutEditer, isTrue);
    });

    test('sans cookie valide, l\'écran de connexion est demandé', () async {
      final controller = SessionController(
        baseUrl: 'http://test',
        client: _ClientFactice({
          '/auth/me': (401, '{}'),
          '/auth/refresh': (401, '{}'),
        }),
      );
      await controller.initialiser();

      expect(controller.etat, SessionState.deconnecte);
      expect(controller.accessToken, isNull);
      expect(controller.peutEditer, isFalse);
    });

    test('un cookie encore valide rouvre la session sans mot de passe', () async {
      final controller = await _sessionAvecRole('consultation');

      expect(controller.etat, SessionState.connecte);
      expect(controller.accessToken, 'jeton');
      expect(controller.peutEditer, isFalse);
    });

    test('un rôle inconnu ne donne pas le droit d\'écrire', () async {
      final controller = await _sessionAvecRole('administrateur_fantaisie');
      expect(controller.peutEditer, isFalse);
    });

    test('la déconnexion efface le jeton conservé en mémoire', () async {
      final controller = await _sessionAvecRole('edition');
      expect(controller.accessToken, isNotNull);

      await controller.deconnecter();

      expect(controller.accessToken, isNull);
      expect(controller.etat, SessionState.deconnecte);
    });
  });

  group('masquage des actions', () {
    testWidgets('une action d\'édition disparaît en consultation',
        (tester) async {
      final session = await _sessionAvecRole('consultation');
      await tester.pumpWidget(
        _sous(
          session,
          const EditionSeulement(child: Text('Importer un fichier')),
        ),
      );
      await tester.pump();

      expect(find.text('Importer un fichier'), findsNothing);
      session.dispose();
    });

    testWidgets('la même action reste visible en édition', (tester) async {
      final session = await _sessionAvecRole('edition');
      await tester.pumpWidget(
        _sous(
          session,
          const EditionSeulement(child: Text('Importer un fichier')),
        ),
      );
      await tester.pump();

      expect(find.text('Importer un fichier'), findsOneWidget);
      session.dispose();
    });

    testWidgets('hors de toute session, rien n\'est masqué', (tester) async {
      // Application de bureau : pas d'authentification, donc pas de bridage.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditionSeulement(child: Text('Importer un fichier')),
          ),
        ),
      );

      expect(find.text('Importer un fichier'), findsOneWidget);
    });

    testWidgets('le bandeau de consultation ne s\'affiche qu\'en lecture seule',
        (tester) async {
      final lecture = await _sessionAvecRole('consultation');
      await tester.pumpWidget(_sous(lecture, const BandeauConsultation()));
      await tester.pump();
      expect(find.text('Consultation'), findsOneWidget);

      final edition = await _sessionAvecRole('edition');
      await tester.pumpWidget(_sous(edition, const BandeauConsultation()));
      await tester.pump();
      expect(find.text('Consultation'), findsNothing);
      lecture.dispose();
      edition.dispose();
    });
  });
}
