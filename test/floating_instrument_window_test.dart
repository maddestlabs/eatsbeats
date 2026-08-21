import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/widgets/floating_instrument_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Floating In-App VSTi Window State & Interaction Tests', () {
    test('State management for floating instrument window', () {
      final state = DawState();
      final track = state.activeTrack;

      expect(state.isFloatingWindowVisible, isFalse);

      // Open window for track
      state.openFloatingInstrumentWindow(track);
      expect(state.isFloatingWindowVisible, isTrue);
      expect(state.floatingInstrumentTrackId, equals(track.id));
      expect(state.floatingInstrumentTrack?.id, equals(track.id));

      // Move window position
      final initialPos = state.floatingWindowPosition;
      state.updateFloatingWindowPosition(const Offset(20, 30));
      expect(state.floatingWindowPosition.dx, equals(initialPos.dx + 20));
      expect(state.floatingWindowPosition.dy, equals(initialPos.dy + 30));

      // Resize window
      final initialSize = state.floatingWindowSize;
      state.updateFloatingWindowSize(const Offset(40, 50));
      expect(state.floatingWindowSize.width, equals(initialSize.width + 40));
      expect(state.floatingWindowSize.height, equals(initialSize.height + 50));

      // Scale window
      state.setFloatingWindowScale(1.25);
      expect(state.floatingWindowScale, equals(1.25));

      // Close window
      state.closeFloatingInstrumentWindow();
      expect(state.isFloatingWindowVisible, isFalse);

      // Toggle window
      state.toggleFloatingInstrumentWindow(track);
      expect(state.isFloatingWindowVisible, isTrue);
      state.toggleFloatingInstrumentWindow(track);
      expect(state.isFloatingWindowVisible, isFalse);
    });

    testWidgets('Renders FloatingInstrumentWindow when visible and handles user interactions', (tester) async {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'Acid Synth 303';
      state.openFloatingInstrumentWindow(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: Container(color: Colors.black)),
                if (state.isFloatingWindowVisible)
                  Positioned(
                    left: state.floatingWindowPosition.dx,
                    top: state.floatingWindowPosition.dy,
                    width: state.floatingWindowSize.width,
                    height: state.floatingWindowSize.height,
                    child: FloatingInstrumentWindow(dawState: state),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify script-driven title bar and actions
      expect(find.text('ACID SYNTH 303'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      expect(find.byTooltip('Unscrew Panel (Close VSTi - Esc)'), findsOneWidget);

      // Verify 1:1 FittedBox scaling container is rendered
      expect(find.byType(FittedBox), findsWidgets);

      // Tap Tactile Screw to Unscrew / Close Panel
      await tester.tap(find.byTooltip('Unscrew Panel (Close VSTi - Esc)'));
      await tester.pumpAndSettle();
      expect(state.isFloatingWindowVisible, isFalse);
    });
  });
}
