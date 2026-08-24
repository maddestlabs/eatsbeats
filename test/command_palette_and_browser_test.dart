import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/command_palette_registry.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommandPaletteRegistry & Project Browser Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('CommandPaletteRegistry generates commands and performs fuzzy search', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final commands = CommandPaletteRegistry.getCommands(dawState, context);
              expect(commands.isNotEmpty, isTrue);

              // Test fuzzy search for "303"
              final results303 = CommandPaletteRegistry.search('303', dawState, context);
              expect(results303.any((c) => c.title.contains('303') || c.subtitle.contains('303')), isTrue);

              // Test fuzzy search for "reverb"
              final resultsReverb = CommandPaletteRegistry.search('reverb', dawState, context);
              expect(resultsReverb.isNotEmpty, isTrue);

              // Test fuzzy search for "theme"
              final resultsTheme = CommandPaletteRegistry.search('theme', dawState, context);
              expect(resultsTheme.any((c) => c.category == CommandCategory.theme), isTrue);

              return Container();
            },
          ),
        ),
      );
    });

    test('DawState handles browser toggling and preset application', () {
      expect(dawState.isBrowserOpen, isFalse);

      dawState.toggleBrowser();
      expect(dawState.isBrowserOpen, isTrue);

      dawState.toggleBrowser();
      expect(dawState.isBrowserOpen, isFalse);

      // Apply instrument preset to active track
      final synthPreset = LuaPresetLibrary.getPresetsByCategory(LuaPresetCategory.instrument).first;
      dawState.applyPreset(synthPreset);
      expect(dawState.activeTrack.name, equals(synthPreset.name));

      // Change theme preset
      dawState.setThemePreset(EatsThemePreset.midnightBites);
      expect(EatsTheme.currentPreset, equals(EatsThemePreset.midnightBites));
      expect(EatsTheme.isLight, isFalse);

      dawState.setThemePreset(EatsThemePreset.breakfast);
      expect(EatsTheme.currentPreset, equals(EatsThemePreset.breakfast));
      expect(EatsTheme.isLight, isTrue);

      dawState.setThemePreset(EatsThemePreset.dinner);
      expect(EatsTheme.currentPreset, equals(EatsThemePreset.dinner));
      expect(EatsTheme.isLight, isFalse);

      dawState.setThemePreset(EatsThemePreset.ateTrack);
      expect(EatsTheme.currentPreset, equals(EatsThemePreset.ateTrack));
    });
  });
}
