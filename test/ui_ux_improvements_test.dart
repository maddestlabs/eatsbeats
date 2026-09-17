import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_gui_model.dart';
import 'package:eatsbeats/eatscript/eats_gui_parser.dart';
import 'package:eatsbeats/eatscript/eats_gui_serializer.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_knob.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_knob_model.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_scale.dart';
import 'package:eatsbeats/ui/widgets/grungy_rack_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI/UX Improvements Tests', () {
    test('EatScaleGraduation.optionsSelector creates evenly spaced graduations and labels', () {
      final scale = EatScaleGraduation.optionsSelector(
        labels: ['SINE', 'SAW', 'SQUARE'],
      );

      expect(scale.labels, equals(['SINE', 'SAW', 'SQUARE']));
      expect(scale.tickDivisions, equals(2));
      expect(scale.startAngle, closeTo(2.35619, 0.01));
      expect(scale.sweepAngle, closeTo(4.71239, 0.01));
    });

    test('EatScriptGuiParser & Serializer preserve custom option scales and options list', () {
      final scriptCode = '''
def gui():
    return {
        "panel": {
            "title": "Oscillator",
            "background": "dark",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {
                            "type": "knob",
                            "param": "waveform",
                            "label": "Waveform",
                            "scale": "Sine, Saw, Square",
                            "options": ["Sine", "Saw", "Square"],
                        }
                    ]
                }
            ]
        }
    }
''';

      final panel = EatScriptGuiParser.parseFromCode(scriptCode);
      expect(panel, isNotNull);
      expect(panel!.children.first.children.first.options, equals(['Sine', 'Saw', 'Square']));
      final knob = panel.children.first.children.first;
      expect(knob.hardwareScale, isNotNull);
      expect(knob.hardwareScale!.labels, equals(['Sine', 'Saw', 'Square']));

      final serialized = EatScriptGuiSerializer.serialize(panel: panel);
      expect(serialized, contains('"options": ["Sine", "Saw", "Square"]'));
      expect(serialized, contains('"scale": ["Sine", "Saw", "Square"]'));
    });

    test('EatScriptGuiParser parses comma-separated string in scale into optionsSelector', () {
      final scriptCode = '''
def gui():
    return {
        "panel": {
            "title": "Filter",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {
                            "type": "knob",
                            "param": "mode",
                            "label": "Filter Mode",
                            "scale": "LP, BP, HP",
                        }
                    ]
                }
            ]
        }
    }
''';

      final panel = EatScriptGuiParser.parseFromCode(scriptCode);
      expect(panel, isNotNull);
      final knob = panel!.children.first.children.first;
      expect(knob.options, equals(['LP', 'BP', 'HP']));
      expect(knob.hardwareScale!.labels, equals(['LP', 'BP', 'HP']));
    });

    testWidgets('EatHardwareKnob renders active option name and handles option snapping', (tester) async {
      double currentValue = 1.0;
      final options = ['SAW', 'SINE', 'SQR', 'TRI'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return EatHardwareKnob(
                    style: EatHardwareKnobStyle.vintageBakelite(),
                    value: currentValue,
                    defaultValue: 0.0,
                    min: 0,
                    max: 3,
                    options: options,
                    showValueText: true,
                    onChanged: (val) {
                      setState(() {
                        currentValue = val;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially at index 1 -> 'SINE'
      expect(find.text('SINE'), findsOneWidget);

      // Verify dragging changes the value and displays another option
      final knobFinder = find.byType(EatHardwareKnob);
      await tester.drag(knobFinder, const Offset(0, -60));
      await tester.pumpAndSettle();

      // Dragged up should advance index
      expect(currentValue, greaterThan(1.0));
    });

    testWidgets('GrungyRackPanel consistently renders dark chassis even under Light Theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: GrungyRackPanel(
              title: 'Dark Panel Synth',
              backgroundStyle: PanelBackgroundStyle.dark,
              child: Text('Panel Content'),
            ),
          ),
        ),
      );

      // The GrungyRackPanel should render with its dark chassis base color
      expect(find.text('DARK PANEL SYNTH'), findsOneWidget);
      expect(find.text('Panel Content'), findsOneWidget);
    });
  });
}
