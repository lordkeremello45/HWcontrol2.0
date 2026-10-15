import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/audio_controller_studio.dart';

void main() {
  testWidgets('studio exposes live controls and starts in a safe stopped state', (tester) async {
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
      find.textContaining('Audio is not recorded.'),
      findsOneWidget,
    );
  });


  testWidgets('starts and stops the native live session through the control callback', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: AudioControllerStudioScreen(
        onLoadDevices: () async => <String, dynamic>{
          'capture': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'name': 'USB Microphone', 'isDefault': true},
          ],
          'playback': <Map<String, dynamic>>[
            <String, dynamic>{'index': 2, 'name': 'Headphones', 'isDefault': true},
          ],
        },
        onControl: (action, payload) async {
          actions.add(action);
          if (action == 'Start Audio Studio') {
            expect(payload?['captureIndex'], 0);
            expect(payload?['playbackIndex'], 2);
            expect(payload?['monitorOutput'], false);
            expect(payload?['eqGain'], hasLength(3));
            return <String, dynamic>{
              'running': true,
              'inputPeak': 0.25,
              'outputPeak': 0.2,
              'inputRms': 0.1,
              'outputRms': 0.08,
              'processedFrames': 480,
              'spectrumAvailable': true,
              'spectrumPeakFrequencyHz': 1500.0,
              'sampleRateHz': 48000.0,
              'spectrumMagnitude': List<double>.filled(513, 0.1),
            };
          }
          if (action == 'Get Audio Studio Status') {
            return <String, dynamic>{
              'running': true,
              'inputPeak': 0.25,
              'outputPeak': 0.2,
              'inputRms': 0.1,
              'outputRms': 0.08,
              'processedFrames': 960,
              'spectrumAvailable': true,
              'spectrumPeakFrequencyHz': 1500.0,
              'sampleRateHz': 48000.0,
              'spectrumMagnitude': List<double>.filled(513, 0.1),
            };
          }
          return <String, dynamic>{'running': false};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start live processing'));
    await tester.tap(find.text('Start live processing'));
    await tester.pumpAndSettle();
    expect(actions, contains('Start Audio Studio'));
    expect(find.text('LIVE • audio is processed locally'), findsOneWidget);
    expect(find.text('1500 Hz'), findsOneWidget);
    expect(find.text('Live spectrum (1024-point FFT)'), findsOneWidget);
    final liveSlider = tester.widget<Slider>(find.byType(Slider).first);
    expect(liveSlider.onChanged, isNull, reason: 'DSP parameters must not imply live reconfiguration.');
    final livePreset = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Voice'));
    expect(livePreset.onSelected, isNull, reason: 'Preset changes apply only after restarting the stream.');

    await tester.ensureVisible(find.text('Stop'));
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(actions, contains('Stop Audio Studio'));
    expect(find.text('Stopped • no microphone stream is active'), findsOneWidget);
  });

  testWidgets('falls back to a safe sample rate for malformed FFT metrics', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AudioControllerStudioScreen(
        onLoadDevices: () async => <String, dynamic>{
          'capture': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'name': 'USB Microphone', 'isDefault': true},
          ],
          'playback': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'name': 'Headphones', 'isDefault': true},
          ],
        },
        onControl: (action, payload) async {
          if (action == 'Start Audio Studio' || action == 'Get Audio Studio Status') {
            return <String, dynamic>{
              'running': true,
              'spectrumAvailable': true,
              'spectrumPeakFrequencyHz': 1500.0,
              'sampleRateHz': double.nan,
              'spectrumMagnitude': List<double>.filled(513, 0.1),
            };
          }
          return <String, dynamic>{'running': false};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start live processing'));
    await tester.tap(find.text('Start live processing'));
    await tester.pumpAndSettle();

    expect(find.text('12000 Hz'), findsOneWidget);
    expect(find.text('24000 Hz'), findsOneWidget);
  });

  testWidgets('reports an unexpected native stream stop and cancels polling', (tester) async {
    var statusCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: AudioControllerStudioScreen(
        onLoadDevices: () async => <String, dynamic>{
          'capture': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'name': 'USB Microphone', 'isDefault': true},
          ],
          'playback': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'name': 'Headphones', 'isDefault': true},
          ],
        },
        onControl: (action, payload) async {
          if (action == 'Start Audio Studio') {
            return <String, dynamic>{'running': true};
          }
          if (action == 'Get Audio Studio Status') {
            statusCalls++;
            return <String, dynamic>{'running': false};
          }
          return <String, dynamic>{'running': false};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start live processing'));
    await tester.tap(find.text('Start live processing'));
    await tester.pumpAndSettle();

    expect(statusCalls, 1);
    expect(find.textContaining('The audio stream stopped unexpectedly.'), findsOneWidget);
    expect(find.text('Stopped • no microphone stream is active'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(statusCalls, 1, reason: 'Polling must stop after the backend reports a stopped stream.');
  });

  testWidgets('does not silently switch devices after a stream disconnect', (tester) async {
    var deviceLoads = 0;
    await tester.pumpWidget(MaterialApp(
      home: AudioControllerStudioScreen(
        onLoadDevices: () async {
          deviceLoads++;
          final disconnected = deviceLoads > 1;
          return <String, dynamic>{
            'capture': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 0,
                'name': disconnected ? 'Replacement Microphone' : 'USB Microphone',
                'isDefault': true,
              },
            ],
            'playback': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 0,
                'name': disconnected ? 'Replacement Output' : 'Headphones',
                'isDefault': true,
              },
            ],
          };
        },
        onControl: (action, payload) async {
          if (action == 'Start Audio Studio') {
            return <String, dynamic>{'running': true};
          }
          if (action == 'Get Audio Studio Status') {
            return <String, dynamic>{'running': false};
          }
          return <String, dynamic>{'running': false};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start live processing'));
    await tester.tap(find.text('Start live processing'));
    await tester.pumpAndSettle();

    expect(deviceLoads, 2);
    expect(find.textContaining('A previously selected device is missing'), findsOneWidget);
    final dropdowns = tester.widgetList<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    ).toList(growable: false);
    expect(dropdowns, hasLength(2));
    expect(dropdowns[0].value, isNull);
    expect(dropdowns[1].value, isNull);
  });

  testWidgets('leaves ambiguous same-name endpoints unselected', (tester) async {
    var deviceLoads = 0;
    await tester.pumpWidget(MaterialApp(
      home: AudioControllerStudioScreen(
        onLoadDevices: () async {
          deviceLoads++;
          if (deviceLoads == 1) {
            return <String, dynamic>{
              'capture': <Map<String, dynamic>>[
                <String, dynamic>{'index': 0, 'name': 'USB Microphone', 'isDefault': true},
              ],
              'playback': <Map<String, dynamic>>[
                <String, dynamic>{'index': 0, 'name': 'Headphones', 'isDefault': true},
              ],
            };
          }
          return <String, dynamic>{
            'capture': <Map<String, dynamic>>[
              <String, dynamic>{'index': 0, 'name': 'USB Microphone', 'isDefault': true},
              <String, dynamic>{'index': 1, 'name': 'USB Microphone', 'isDefault': false},
            ],
            'playback': <Map<String, dynamic>>[
              <String, dynamic>{'index': 0, 'name': 'Headphones', 'isDefault': true},
              <String, dynamic>{'index': 1, 'name': 'Headphones', 'isDefault': false},
            ],
          };
        },
        onControl: (action, payload) async {
          if (action == 'Start Audio Studio') {
            return <String, dynamic>{'running': true};
          }
          if (action == 'Get Audio Studio Status') {
            return <String, dynamic>{'running': false};
          }
          return <String, dynamic>{'running': false};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start live processing'));
    await tester.tap(find.text('Start live processing'));
    await tester.pumpAndSettle();

    expect(deviceLoads, 2);
    expect(find.textContaining('A previously selected device is missing'), findsOneWidget);
    final dropdowns = tester.widgetList<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    ).toList(growable: false);
    expect(dropdowns, hasLength(2));
    expect(dropdowns[0].value, isNull);
    expect(dropdowns[1].value, isNull);
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

  testWidgets('detects endpoints and applies only validated Gemma suggestions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AudioControllerStudioScreen(
        onLoadDevices: () async => <String, dynamic>{
          'capture': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'name': 'USB Microphone', 'isDefault': true},
          ],
          'playback': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'name': 'Studio Speakers', 'isDefault': true},
          ],
        },
        onRecommend: (profile) async {
          expect(profile['model'], 'USB Microphone');
          return <String, dynamic>{
            'recommendation': jsonEncode(<String, dynamic>{
              'summary': 'Conservative voice profile',
              'inputGainDb': 0,
              'highPassEnabled': true,
              'highPassHz': 80,
              'noiseGateEnabled': true,
              'noiseGateThresholdDb': -48,
              'compressorEnabled': true,
              'compressorRatio': 2,
              'limiterEnabled': true,
              'limiterCeilingDb': -1,
              'eqBands': <Map<String, dynamic>>[
                <String, dynamic>{'frequencyHz': 1000, 'gainDb': 1},
              ],
              'warnings': <String>[],
            }),
          };
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Detected 1 input and 1 output endpoints'), findsOneWidget);
    await tester.ensureVisible(find.text('Ask local Gemma'));
    await tester.tap(find.text('Ask local Gemma'));
    await tester.pumpAndSettle();

    expect(find.text('Conservative voice profile'), findsOneWidget);
    await tester.ensureVisible(find.text('Apply validated settings'));
    await tester.tap(find.text('Apply validated settings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Validated Gemma settings applied'), findsOneWidget);
  });

  testWidgets('rejects malformed Gemma recommendation output', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AudioControllerStudioScreen(
        onLoadDevices: () async => <String, dynamic>{'capture': <dynamic>[], 'playback': <dynamic>[]},
        onRecommend: (_) async => <String, dynamic>{'recommendation': '{"summary":"unsafe"}'},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Device model / endpoint name'));
    await tester.enterText(find.byType(TextField).first, 'USB Mic');
    await tester.ensureVisible(find.text('Ask local Gemma'));
    await tester.tap(find.text('Ask local Gemma'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recommendation rejected'), findsOneWidget);
    expect(find.text('Apply validated settings'), findsNothing);
  });
}
