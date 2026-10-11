import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/welcome_screen.dart';

void main() {
  testWidgets('renders the original HWcontrol2.0 welcome content', (tester) async {
    var continued = false;
    var dontShowAgain = false;
    var settingsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HWControlWelcomeScreen(
          onContinue: (value) {
            continued = true;
            dontShowAgain = value;
          },
          onSettings: () => settingsOpened = true,
        ),
      ),
    );

    expect(find.text('Welcome to HWcontrol2.0'), findsOneWidget);
    expect(find.text('Monitor. Control. Protect.'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Protect'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text("Don't show this again"), findsOneWidget);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(continued, isTrue);
    expect(dontShowAgain, isFalse);

    await tester.ensureVisible(find.text('Open Dashboard'));
    await tester.tap(find.text('Open Dashboard'));
    await tester.pump();

    expect(settingsOpened, isTrue);
  });
  testWidgets('renders translated welcome copy when translations are supplied', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HWControlWelcomeScreen(
          onContinue: (_) {},
          onSettings: () {},
          translations: const <String, String>{
            'welcomeTitle': "HWcontrol2.0'ye hoş geldiniz",
            'welcomeGetStarted': 'Başlayın',
            'welcomeOpenDashboard': 'Kontrol Panelini Aç',
            'welcomePreview': 'Kontrol paneli önizlemesi',
          },
        ),
      ),
    );

    expect(find.text("HWcontrol2.0'ye hoş geldiniz"), findsOneWidget);
    expect(find.text('Başlayın'), findsOneWidget);
    expect(find.text('Kontrol Panelini Aç'), findsOneWidget);
    expect(find.text('Kontrol paneli önizlemesi'), findsOneWidget);
    expect(find.text('Welcome to HWcontrol2.0'), findsNothing);
  });

}
