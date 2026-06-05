import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/welcome/screens/welcome_screen.dart';

void main() {
  Future<void> pumpWelcomeAtSize(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(onOpenHome: () {}),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Essentiels métier'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(tester.takeException(), isNull);
  }

  testWidgets('welcome screen renders carousel without layout exceptions',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpWelcomeAtSize(tester, const Size(1440, 900));
  });

  testWidgets('welcome screen scales down instead of scrolling',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpWelcomeAtSize(tester, const Size(1280, 640));
  });
}
