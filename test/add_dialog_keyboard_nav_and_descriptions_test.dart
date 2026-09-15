import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/eatscript/eats_script_library.dart';
import 'package:eatsbeats/eatscript/eats_builtin_presets.g.dart';
import 'package:eatsbeats/ui/widgets/script_search_dialog.dart';
import 'package:eatsbeats/ui/widgets/midi_fx_rack_widget.dart';
import 'package:eatsbeats/ui/widgets/modular_fx_rack_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Script Description Metadata Tests', () {
    test('All presets in presets/ have # @description: metadata defined', () {
      final presetsDir = Directory('presets');
      expect(presetsDir.existsSync(), isTrue);

      final files = presetsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.eats'))
          .toList();

      expect(files.length, equals(129));

      final missing = <String>[];
      for (final file in files) {
        final content = file.readAsStringSync();
        if (!content.contains('@description:')) {
          missing.add(file.path);
        }
      }

      expect(missing, isEmpty, reason: 'All presets must contain @description metadata');
    });

    test('EatBuiltinPresets has descriptions populated for all bundled presets', () {
      for (final preset in EatBuiltinPresets.presets) {
        expect(preset.description, isNotEmpty);
        expect(preset.description, isNot(equals('User imported Lua script')));
        expect(preset.description, isNot(equals('')));
      }
    });

    test('EatScriptLibrary parses # @description: from script code correctly', () {
      const code = '''
# @name: Test Analog Synth
# @category: instrument
# @description: Custom vintage analog synth with warm overdrive.

def init():
    pass
''';
      final parsed = EatScriptLibrary.parseFromEatScript(code);
      expect(parsed.name, equals('Test Analog Synth'));
      expect(parsed.category, equals(EatScriptCategory.instrument));
      expect(parsed.description, equals('Custom vintage analog synth with warm overdrive.'));
    });
  });

  group('Add Dialog Keyboard Navigation Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('Arrow Down navigates list and Enter selects highlighted item', (tester) async {
      final track = dawState.activeTrack;
      final initialFxCount = track.fxRack.length;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => PresetSearchDialog.showAudioFx(
                    context,
                    dawState: dawState,
                    track: track,
                  ),
                  child: const Text('OPEN DIALOG'),
                );
              },
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      expect(find.byType(PresetSearchDialog), findsOneWidget);

      // Filter to two specific items
      await tester.enterText(find.byType(TextField), 'designer');
      await tester.pumpAndSettle();

      // Press ArrowDown to navigate to the second item
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press Enter to select the highlighted item
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Dialog is dismissed and FX has been added to track
      expect(find.byType(PresetSearchDialog), findsNothing);
      expect(track.fxRack.length, equals(initialFxCount + 1));
    });
  });

  group('Track Properties Sidebar Button Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('MidiFxRackWidget + ADD MIDI FX button does not have search magnifier icon', (tester) async {
      final track = dawState.activeTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MidiFxRackWidget(
              dawState: dawState,
              track: track,
            ),
          ),
        ),
      );

      // Find '+ ADD MIDI FX' text
      expect(find.text('+ ADD MIDI FX'), findsOneWidget);

      // Verify no search icon in the '+ ADD MIDI FX' button
      final addMidiFxBtn = find.ancestor(
        of: find.text('+ ADD MIDI FX'),
        matching: find.byType(InkWell),
      );
      expect(find.descendant(of: addMidiFxBtn, matching: find.byIcon(Icons.search)), findsNothing);
    });

    testWidgets('ModularFxRackWidget + ADD FX button does not have search magnifier icon', (tester) async {
      final track = dawState.activeTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModularFxRackWidget(
              dawState: dawState,
              track: track,
            ),
          ),
        ),
      );

      // Find '+ ADD FX' text
      expect(find.text('+ ADD FX'), findsOneWidget);

      // Verify no search icon in the '+ ADD FX' button
      final addFxBtn = find.ancestor(
        of: find.text('+ ADD FX'),
        matching: find.byType(InkWell),
      );
      expect(find.descendant(of: addFxBtn, matching: find.byIcon(Icons.search)), findsNothing);
    });
  });
}
