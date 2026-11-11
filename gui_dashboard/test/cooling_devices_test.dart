import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/cooling_devices.dart';

void main() {
  test('parses independent read-only liquid-cooling telemetry', () {
    final snapshot = LiquidCoolingSnapshot.fromJson(<String, dynamic>{
      'state': 'available',
      'backend': 'liquidctl',
      'reason': '',
      'devices': <dynamic>[
        <String, dynamic>{
          'id': '0123456789abcdef',
          'name': 'Example AIO',
          'backend': 'liquidctl',
          'state': 'available',
          'readings': <dynamic>[
            <String, dynamic>{
              'kind': 'coolantTemperature',
              'value': 31.5,
              'unit': '°C',
            },
            <String, dynamic>{
              'kind': 'pumpRPM',
              'value': 2400,
              'unit': 'RPM',
            },
          ],
        },
      ],
    });

    expect(snapshot.state, 'available');
    expect(snapshot.devices, hasLength(1));
    expect(snapshot.devices.single.readings, hasLength(2));
    expect(snapshot.devices.single.readings.first.kind, 'coolantTemperature');
  });

  test('drops malformed numeric readings and keeps unavailable state explicit', () {
    final snapshot = LiquidCoolingSnapshot.fromJson(<String, dynamic>{
      'state': 'partial',
      'backend': 'liquidctl',
      'reason': 'No recognized sensor values.',
      'devices': <dynamic>[
        <String, dynamic>{
          'name': 'Unknown controller',
          'state': 'partial',
          'readings': <dynamic>[
            <String, dynamic>{
              'kind': 'pumpRPM',
              'value': 'not-a-number',
              'unit': 'RPM',
            },
          ],
        },
      ],
    });

    expect(snapshot.state, 'partial');
    expect(snapshot.devices.single.readings, isEmpty);
  });

  test('missing optional adapter remains unavailable', () {
    const snapshot = LiquidCoolingSnapshot.unavailable();
    expect(snapshot.state, 'unavailable');
    expect(snapshot.backend, 'liquidctl');
    expect(snapshot.devices, isEmpty);
  });

  test('failed refresh preserves last valid readings as stale', () {
    final snapshot = LiquidCoolingSnapshot.fromJson(<String, dynamic>{
      'state': 'available',
      'backend': 'liquidctl',
      'devices': <dynamic>[
        <String, dynamic>{
          'name': 'Example AIO',
          'state': 'available',
          'readings': <dynamic>[
            <String, dynamic>{
              'kind': 'pumpRPM',
              'value': 2300,
              'unit': 'RPM',
            },
          ],
        },
      ],
    });

    final stale = snapshot.asStale();
    expect(stale.state, 'stale');
    expect(stale.devices.single.readings.single.value, 2300);
  });


  testWidgets('renders liquid-cooling readings and read-only boundary', (tester) async {
    final snapshot = LiquidCoolingSnapshot.fromJson(<String, dynamic>{
      'state': 'available',
      'backend': 'liquidctl',
      'devices': <dynamic>[
        <String, dynamic>{
          'name': 'Example AIO',
          'state': 'available',
          'readings': <dynamic>[
            <String, dynamic>{
              'kind': 'pumpRPM',
              'value': 2300,
              'unit': 'RPM',
            },
            <String, dynamic>{
              'kind': 'coolantTemperature',
              'value': 31.5,
              'unit': '°C',
            },
          ],
        },
      ],
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LiquidCoolingPanel(
          snapshot: snapshot,
          translate: (_, english) => english,
        ),
      ),
    ));

    expect(find.text('Liquid-cooling telemetry'), findsOneWidget);
    expect(find.textContaining('Pump speed: 2300.0 RPM'), findsOneWidget);
    expect(find.textContaining('Coolant temperature: 31.5 °C'), findsOneWidget);
    expect(
      find.text('Read-only adapter. HWcontrol does not initialize, reconfigure or control the detected device.'),
      findsOneWidget,
    );
  });
}
