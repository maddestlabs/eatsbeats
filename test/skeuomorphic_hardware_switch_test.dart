import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_switch.dart';

void main() {
  group('SkeuomorphicHardwareSwitch Tests', () {
    testWidgets('Renders properly in OFF and ON states and handles tap toggling', (tester) async {
      bool switchState = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: SkeuomorphicHardwareSwitch(
                    value: switchState,
                    label: 'CHORUS FX',
                    onChanged: (val) {
                      setState(() {
                        switchState = val;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify label is rendered
      expect(find.text('CHORUS FX'), findsOneWidget);
      expect(find.byType(SkeuomorphicHardwareSwitch), findsOneWidget);

      // Tap on the switch
      await tester.tap(find.byType(CustomPaint).first);
      await tester.pumpAndSettle();

      expect(switchState, isTrue);

      // Tap again to turn off
      await tester.tap(find.byType(CustomPaint).first);
      await tester.pumpAndSettle();

      expect(switchState, isFalse);
    });

    testWidgets('Renders across all theme presets without errors', (tester) async {
      for (final preset in EatsThemePreset.values) {
        EatsTheme.currentPreset = preset;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SkeuomorphicHardwareSwitch(
                  value: true,
                  activeColor: EatsTheme.secondaryMagenta,
                  onChanged: (val) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SkeuomorphicHardwareSwitch), findsOneWidget);
      }

      // Reset to default theme
      EatsTheme.currentPreset = EatsThemePreset.ateTrack;
    });

    testWidgets('Disabled state does not trigger onChanged', (tester) async {
      bool triggered = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SkeuomorphicHardwareSwitch(
                value: false,
                onChanged: null, // Disabled
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CustomPaint).first);
      await tester.pumpAndSettle();

      expect(triggered, isFalse);
    });
  });
}
