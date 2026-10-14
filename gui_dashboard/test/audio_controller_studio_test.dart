import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/audio_controller_studio.dart';

void main() {
  testWidgets('studio clearly reports that live audio is not connected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AudioControllerStudioScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audio Controller Studio'), findsOneWidget);
    expect(find.text('Parametric equalizer'), findsOneWidget);
    expect(find.text('Dynamics and safety'), findsOneWidget);
    expect(find.text('Analysis laboratory'), findsOneWidget);
    expect(find.text('Microphone capture / playback'), findsOneWidget);
    expect(find.text('NATIVE PROTOTYPE'), findsOneWidget);
    expect(find.text('NOT IMPLEMENTED'), findsNWidgets(3));
    expect(
      find.textContaining('No audio is being recorded.'),
      findsOneWidget,
    );
  });

  testWidgets('studio preset controls can be selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AudioControllerStudioScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Voice'));
    await tester.pumpAndSettle();

    final voiceChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Voice'),
    );
    expect(voiceChip.selected, isTrue);
  });
}
