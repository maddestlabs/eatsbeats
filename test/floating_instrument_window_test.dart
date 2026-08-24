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

    test('Accurate natural GUI height calculation for zero-padding fit', () {
      final state = DawState();
      final track = state.activeTrack;

      final height = state.getTrackNaturalGuiHeight(track);
      expect(height, greaterThanOrEqualTo(120.0));
      expect(height, lessThanOrEqualTo(600.0));

      // Auto-fit calculates exact aspect ratio without excess height
      state.fitFloatingWindowToWorkspace(const Size(800, 600), track);
      final winH = state.floatingWindowSize.height;
      // Window height should equal (content natural height * scale) + 38 titlebar
      expect(winH, lessThan(600));
    });

    test('Auto-fit and fullscreen maximization state logic', () {
      final state = DawState();
      final track = state.activeTrack;
      state.openFloatingInstrumentWindow(track);

      // Mobile screen fit: 380x720
      state.fitFloatingWindowToWorkspace(const Size(380, 720));
      expect(state.isFloatingWindowMaximized, isFalse);
      expect(state.floatingWindowSize.width, lessThanOrEqualTo(380));
      expect(state.floatingWindowSize.height, lessThanOrEqualTo(720));
      expect(state.floatingWindowPosition.dx, greaterThanOrEqualTo(0));

      // Toggle Fullscreen / Maximize
      state.toggleMaximizeFloatingWindow(const Size(800, 600));
      expect(state.isFloatingWindowMaximized, isTrue);
      expect(state.floatingWindowSize.width, equals(792)); // 800 - (4*2)
      expect(state.floatingWindowSize.height, equals(592)); // 600 - (4*2)
      expect(state.floatingWindowPosition, equals(const Offset(4, 4)));

      // Toggle back / Restore
      state.toggleMaximizeFloatingWindow(const Size(800, 600));
      expect(state.isFloatingWindowMaximized, isFalse);
    });

    testWidgets('Renders FloatingInstrumentWindow when visible and handles user interactions', (tester) async {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'Acid Synth 303';
      state.openFloatingInstrumentWindow(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: state,
              builder: (context, _) => Stack(
                children: [
                  Positioned.fill(child: Container(color: Colors.black)),
                  if (state.isFloatingWindowVisible)
                    Positioned(
                      left: state.floatingWindowPosition.dx,
                      top: state.floatingWindowPosition.dy,
                      width: state.floatingWindowSize.width,
                      height: state.floatingWindowSize.height,
                      child: FloatingInstrumentWindow(
                        dawState: state,
                        workspaceBounds: const Size(800, 600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify script-driven title bar and actions
      expect(find.text('ACID SYNTH 303'), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byTooltip('Unscrew Panel (Close VSTi - Esc)'), findsOneWidget);

      // Verify 1:1 FittedBox scaling container is rendered
      expect(find.byType(FittedBox), findsWidgets);

      // Tap Fit to Screen button
      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pumpAndSettle();
      expect(state.isFloatingWindowMaximized, isFalse);

      // Tap Fullscreen / Maximize button
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();
      expect(state.isFloatingWindowMaximized, isTrue);
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

      // Tap Unscrew Screw to Close Panel
      await tester.tap(find.byTooltip('Unscrew Panel (Close VSTi - Esc)'));
      await tester.pumpAndSettle();
      expect(state.isFloatingWindowVisible, isFalse);
    });
  });
}
