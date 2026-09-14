import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/ui/transport_header.dart';
import 'package:eatsbeats/theme/eats_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DawState dawState;

  setUp(() {
    dawState = DawState(enableMeterTimer: false);
  });

  tearDown(() {
    dawState.dispose();
  });

  group('Collapsible Settings Dialog Tests', () {
    testWidgets('Only Project Hub is open by default, others collapsed by default', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: TransportHeader(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open settings dialog via Eatsbeats Settings tooltip
      final settingsBtn = find.byTooltip('Eatsbeats Settings');
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.text('EATSBEATS SETTINGS'), findsOneWidget);

      // Section headers should all be present
      expect(find.text('PROJECT HUB'), findsOneWidget);
      expect(find.text('SESSION PERSISTENCE & AUTO-RESTORE'), findsOneWidget);
      expect(find.text('DISPLAY & WORKSPACE'), findsOneWidget);
      expect(find.text('AUDIO ENGINE CONFIG'), findsOneWidget);
      expect(find.text('CREDITS & ACKNOWLEDGMENTS'), findsOneWidget);

      // 1. Project Hub contents: OPEN by default
      expect(find.text('COMPOSITION DETAILS'), findsOneWidget);
      expect(find.text('Title / Song Name'), findsOneWidget);
      expect(find.text('Author / Creator'), findsOneWidget);
      expect(find.text('SAVE (.eats)'), findsOneWidget);
      expect(find.text('LOAD (.eats)'), findsOneWidget);
      expect(find.text('IMPORT / EXPORT'), findsOneWidget);
      expect(find.text('EXPORT WAV'), findsOneWidget);

      // 2. Session Persistence contents: COLLAPSED by default
      expect(find.text('Restore last project on startup'), findsNothing);
      expect(find.text('Auto-save project state'), findsNothing);
      expect(find.text('RESET TO DEFAULT TEMPLATE (CLEAN SLATE)'), findsNothing);

      // 3. Display & Workspace contents: COLLAPSED by default
      expect(find.text('UI MAGNIFICATION'), findsNothing);
      expect(find.text('UI THEME ENGINE'), findsNothing);
      expect(find.text('SCREEN SHADERS & CRT FX'), findsNothing);
      expect(find.text('GUI ANIMATIONS & CPU'), findsNothing);

      // 4. Audio Engine Config contents: COLLAPSED by default
      expect(find.textContaining('Pure-Dart Eatscript DSP Engine'), findsNothing);

      // 5. Credits contents: COLLAPSED by default
      expect(find.textContaining('Commuted Waveguide Piano Physical Models'), findsNothing);
    });

    testWidgets('Tapping section headers expands and collapses them', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: TransportHeader(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open settings dialog
      await tester.tap(find.byTooltip('Eatsbeats Settings'));
      await tester.pumpAndSettle();

      // Collapse Project Hub
      await tester.tap(find.text('PROJECT HUB'));
      await tester.pumpAndSettle();
      expect(find.text('COMPOSITION DETAILS'), findsNothing);
      expect(find.text('SAVE (.eats)'), findsNothing);

      // Re-expand Project Hub
      await tester.tap(find.text('PROJECT HUB'));
      await tester.pumpAndSettle();
      expect(find.text('COMPOSITION DETAILS'), findsOneWidget);
      expect(find.text('SAVE (.eats)'), findsOneWidget);

      // Expand Session Persistence
      expect(find.text('Restore last project on startup'), findsNothing);
      await tester.tap(find.text('SESSION PERSISTENCE & AUTO-RESTORE'));
      await tester.pumpAndSettle();
      expect(find.text('Restore last project on startup'), findsOneWidget);
      expect(find.text('Auto-save project state'), findsOneWidget);

      // Collapse Session Persistence
      await tester.tap(find.text('SESSION PERSISTENCE & AUTO-RESTORE'));
      await tester.pumpAndSettle();
      expect(find.text('Restore last project on startup'), findsNothing);

      // Expand Display & Workspace
      expect(find.text('UI MAGNIFICATION'), findsNothing);
      await tester.tap(find.text('DISPLAY & WORKSPACE'));
      await tester.pumpAndSettle();
      expect(find.text('UI MAGNIFICATION'), findsOneWidget);
      expect(find.text('GUI ANIMATIONS & CPU'), findsOneWidget);

      // Expand Audio Engine Config
      expect(find.textContaining('Pure-Dart Eatscript DSP Engine'), findsNothing);
      await tester.tap(find.text('AUDIO ENGINE CONFIG'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pure-Dart Eatscript DSP Engine'), findsOneWidget);

      // Expand Credits & Acknowledgments
      expect(find.textContaining('Commuted Waveguide Piano Physical Models'), findsNothing);
      await tester.tap(find.text('CREDITS & ACKNOWLEDGMENTS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Commuted Waveguide Piano Physical Models'), findsOneWidget);
    });
  });
}
