// Test du flux de cotation en ligne du taux courant USD depuis la barre
// « Taux courants » de l'écran Risque de Change. Le service réseau est injecté
// avec un MockClient : aucun appel réseau réel n'est effectué.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rwa_calculator/modules/risque_marche/screens/fx_risk_analysis_screen.dart';
import 'package:rwa_calculator/modules/risque_marche/services/fx_rate_service.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  testWidgets('le taux USD peut être coté en ligne puis validé',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});

    // Un titre en USD suffit à faire apparaître la barre des taux courants.
    MarketDataImportStore.instance.snapshotNotifier.value =
        MarketDataSnapshot.fromDatasets(
      {
        MarketPortfolioType.bonds: MarketPortfolioDataset(
          portfolioType: MarketPortfolioType.bonds,
          fileName: 'mock.xlsx',
          importedAt: DateTime.now(),
          headers: const ['Devise', 'Valeur nominale unitaire', 'quantités'],
          records: [
            MarketPortfolioRecord(
              portfolioType: MarketPortfolioType.bonds,
              values: const {
                'Devise': 'USD',
                'Valeur nominale unitaire': 1000.0,
                'quantités': 100.0,
              },
            ),
          ],
        ),
      },
      activeType: MarketPortfolioType.bonds,
    );

    final service = FxRateService(
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'result': 'success',
              'time_last_update_unix': 1718800000,
              'base_code': 'USD',
              'rates': {'USD': 1, 'XOF': 612.34},
            }),
            200,
          )),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FxRiskAnalysisScreen(rateService: service)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Au départ, la pastille USD (taux de référence) porte l'icône crayon ;
    // l'EUR à parité fixe porte un cadenas.
    expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);

    // Ouvre l'éditeur en cliquant la pastille USD via son icône.
    await tester.tap(find.byIcon(CupertinoIcons.pencil));
    await tester.pumpAndSettle();
    expect(find.text('Taux courant — USD'), findsOneWidget);

    // Déclenche la cotation en ligne.
    await tester.tap(find.text('Récupérer le taux en ligne'));
    await tester.pump(); // démarre le future
    await tester.pumpAndSettle();

    // Le champ est rempli avec le taux coté (locale fr_FR : virgule décimale)
    // et la bannière de succès apparaît.
    expect(find.widgetWithText(TextField, '612,34'), findsOneWidget);
    expect(find.textContaining('exchangerate-api.com'), findsOneWidget);

    // Valide : le dialogue se ferme et la pastille reflète l'origine « en
    // ligne » (l'icône crayon devient une icône de cotation en ligne).
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('Taux courant — USD'), findsNothing);
    expect(find.byIcon(CupertinoIcons.cloud_download), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.pencil), findsNothing);

    addTearDown(() => MarketDataImportStore.instance.snapshotNotifier.value =
        MarketDataSnapshot.empty);
  });
}
