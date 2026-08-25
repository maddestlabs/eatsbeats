import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/ui/widgets/preset_search_dialog.dart';
import 'package:eatsbeats/ui/widgets/floating_instrument_window.dart';
import 'package:eatsbeats/ui/widgets/modular_fx_rack_widget.dart';
import 'package:eatsbeats/ui/widgets/midi_fx_rack_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PresetSearchDialog Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('PresetSearchDialog filters Audio FX by search text and adds to rack', (tester) async {
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
                  child: const Text('OPEN SEARCH'),
                );
              },
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('OPEN SEARCH'));
      await tester.pumpAndSettle();

      expect(find.byType(PresetSearchDialog), findsOneWidget);
      expect(find.textContaining('ADD AUDIO FX'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'delay');
      await tester.pumpAndSettle();

      // Find Stereo Delay and tap it
      expect(find.textContaining('Stereo Delay'), findsWidgets);
      await tester.tap(find.textContaining('Stereo Delay').first);
      await tester.pumpAndSettle();

      // Dialog is dismissed and FX is added to track
      expect(find.byType(PresetSearchDialog), findsNothing);
      expect(track.fxRack.length, equals(initialFxCount + 1));
      expect(track.fxRack.any((f) => f.name.contains('Delay') || f.id.contains('delay')), isTrue);
    });

    testWidgets('PresetSearchDialog filters MIDI FX by search text and adds to rack', (tester) async {
      final track = dawState.activeTrack;
      final initialMidiCount = track.midiFXRack.length;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => PresetSearchDialog.showMidiFx(
                    context,
                    dawState: dawState,
                    track: track,
                  ),
                  child: const Text('OPEN MIDI SEARCH'),
                );
              },
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('OPEN MIDI SEARCH'));
      await tester.pumpAndSettle();

      expect(find.byType(PresetSearchDialog), findsOneWidget);
      expect(find.textContaining('ADD MIDI FX'), findsOneWidget);

      // Tap on first available MIDI FX
      final addButtons = find.text('ADD');
      expect(addButtons, findsWidgets);
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(find.byType(PresetSearchDialog), findsNothing);
      expect(track.midiFXRack.length, equals(initialMidiCount + 1));
    });
  });

  group('Floating GUI Window Double-Click Fill / Fit Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('Double-tapping floating GUI header toggles Fill Workspace and Fit to Screen', (tester) async {
      final track = dawState.activeTrack;
      dawState.openFloatingInstrumentWindow(track);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingInstrumentWindow(
              dawState: dawState,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.isFloatingWindowMaximized, isFalse);

      // Find the header GestureDetector
      final headerGesture = find.byType(GestureDetector).first;

      // Double tap to Fill Workspace (Fullscreen)
      await tester.tap(headerGesture);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(headerGesture);
      await tester.pumpAndSettle();

      expect(dawState.isFloatingWindowMaximized, isTrue);

      // Double tap again to Fit to Screen
      await tester.tap(headerGesture);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(headerGesture);
      await tester.pumpAndSettle();

      expect(dawState.isFloatingWindowMaximized, isFalse);
    });
  });
}
