import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/command_palette_registry.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/ui/widgets/ui_scale_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Scale Engine & Dialog Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    tearDown(() {
      dawState.dispose();
    });

    test('DawState handles UI scale preview, commit, revert, and reset', () {
      expect(dawState.uiScale, 1.0);

      // Preview scale change
      dawState.setUiScalePreview(0.85);
      expect(dawState.uiScale, 0.85);

      // Revert to initial
      dawState.revertUiScale(1.0);
      expect(dawState.uiScale, 1.0);

      // Commit scale change
      dawState.commitUiScale(0.75);
      expect(dawState.uiScale, 0.75);

      // Reset
      dawState.resetUiScale();
      expect(dawState.uiScale, 1.0);
    });

    testWidgets('UiScaleDialog renders and supports preview with cancel/revert', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => UiScaleDialog.show(context, dawState),
                  child: const Text('Open Scale Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Scale Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('DISPLAY & UI SCALE'), findsOneWidget);
      expect(find.text('QUICK PRESETS'), findsOneWidget);
      expect(find.text('UPDATE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);

      // Tap "75% Compact" preset chip
      await tester.tap(find.text('75% Compact'));
      await tester.pumpAndSettle();

      // UI Scale should preview at 0.75 live
      expect(dawState.uiScale, 0.75);

      // Tap CANCEL - should revert back to 1.0
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(dawState.uiScale, 1.0);
    });

    testWidgets('UiScaleDialog commits scale on UPDATE', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => UiScaleDialog.show(context, dawState),
                  child: const Text('Open Scale Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Scale Dialog'));
      await tester.pumpAndSettle();

      // Tap "125% Large" preset chip
      await tester.tap(find.text('125% Large'));
      await tester.pumpAndSettle();

      expect(dawState.uiScale, 1.25);

      // Tap UPDATE - should commit 1.25
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(dawState.uiScale, 1.25);
    });

    testWidgets('CommandPaletteRegistry contains UI scale commands', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final commands = CommandPaletteRegistry.getCommands(dawState, context);
              final scaleCommands = commands.where((c) => c.title.contains('UI Scale')).toList();
              expect(scaleCommands.isNotEmpty, isTrue);
              return Container();
            },
          ),
        ),
      );
    });
  });
}
