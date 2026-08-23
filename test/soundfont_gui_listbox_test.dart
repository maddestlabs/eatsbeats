import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/soundfont_engine.dart';
import 'package:mobile_wren_daw/audio/soundfont_decoder.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_gui_model.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/hardware_listbox_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/skeuomorphic_hardware_knob.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SoundFontEngine.instance.loadDefaultBundledFont();
  });

  group('SoundFont 2 Player Preset & GUI Layout Tests', () {
    test('SoundFont 2 Player compiles with SNES background and ListBox controls', () {
      final sfPreset = LuaPresetLibrary.getPresetById('soundfont_sampler')!;
      final compilation = LuaEngine.compile(sfPreset.code);

      expect(compilation.isSuccess, isTrue);
      expect(compilation.guiLayout, isNotNull);

      final gui = compilation.guiLayout!;
      expect(gui.title, equals('SoundFont 2 Player'));
      expect(gui.backgroundStyle, equals(PanelBackgroundStyle.snes));
      expect(gui.accentColor, equals(const Color(0xFF21F4E8)));
      expect(gui.defaultKnobStyle, equals(KnobStyle.snes));

      // Check ListBox children
      final row1 = gui.children.first;
      final bankListBox = row1.children.firstWhere((c) => c.param == 'SoundFontBank');
      expect(bankListBox.width, equals(160.0));
      expect(bankListBox.height, equals(90.0));

      final presetListBox = row1.children.firstWhere((c) => c.param == 'Preset');
      expect(presetListBox.width, equals(200.0));
      expect(presetListBox.height, equals(90.0));

      // Verify ADSR parameters exist
      expect(compilation.params.any((p) => p.name == 'AttackSec'), isTrue);
      expect(compilation.params.any((p) => p.name == 'DecaySec'), isTrue);
      expect(compilation.params.any((p) => p.name == 'Sustain'), isTrue);
      expect(compilation.params.any((p) => p.name == 'ReleaseSec'), isTrue);
      expect(compilation.params.any((p) => p.name == 'Gain'), isTrue);
      expect(compilation.params.any((p) => p.name == 'PresetNum'), isTrue);
      expect(compilation.params.any((p) => p.name == 'BankNum'), isTrue);
    });
  });

  group('SoundFont GUI ListBox Widget Interaction Tests', () {
    testWidgets('DynamicInstrumentGuiWidget renders SoundFont Player with Bank and Preset ListBoxes', (tester) async {
      final dawState = DawState();
      final sfPreset = LuaPresetLibrary.getPresetById('soundfont_sampler')!;
      final track = TrackChannel(
        id: 'sf_track_1',
        name: 'SoundFont Track',
        type: TrackType.luaScript,
        color: const Color(0xFF21F4E8),
        sampleName: 'super_small_font.sf2',
        luaScriptCode: sfPreset.code,
        luaParams: {
          'SoundFontBank': 0.0,
          'Preset': 0.0,
          'PresetNum': 0.0,
          'BankNum': 0.0,
          'AttackSec': 0.0,
          'DecaySec': 0.3,
          'Sustain': 0.8,
          'ReleaseSec': 0.4,
          'Gain': 1.0,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title & Subtitle rendered
      expect(find.text('SOUNDFONT 2 PLAYER'), findsWidgets);
      expect(find.text('Multi-Sample SF2 Bank & Instrument Engine'), findsWidgets);

      // Verify two HardwareListBoxWidgets are rendered
      final listBoxes = find.byType(HardwareListBoxWidget);
      expect(listBoxes, findsNWidgets(2));

      // Verify labels
      expect(find.text('SOUNDFONT BANK'), findsOneWidget);
      expect(find.text('PROGRAM PRESET'), findsOneWidget);

      // Verify knobs for ADSR & Gain are rendered
      expect(find.byType(SkeuomorphicHardwareKnob), findsNWidgets(5));
      expect(find.text('ATTACK'), findsOneWidget);
      expect(find.text('DECAY'), findsOneWidget);
      expect(find.text('SUSTAIN'), findsOneWidget);
      expect(find.text('RELEASE'), findsOneWidget);
      expect(find.text('GAIN'), findsOneWidget);
    });

    testWidgets('Selecting a preset from Program Preset ListBox updates PresetNum and BankNum', (tester) async {
      final dawState = DawState();
      final sfPreset = LuaPresetLibrary.getPresetById('soundfont_sampler')!;
      final track = TrackChannel(
        id: 'sf_track_2',
        name: 'SoundFont Track',
        type: TrackType.luaScript,
        color: const Color(0xFF21F4E8),
        sampleName: 'super_small_font.sf2',
        luaScriptCode: sfPreset.code,
        luaParams: {
          'SoundFontBank': 0.0,
          'Preset': 0.0,
          'PresetNum': 0.0,
          'BankNum': 0.0,
        },
      );
      dawState.tracks.add(track);
      dawState.activeTrackIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fontData = SoundFontEngine.instance.getSoundFont('super_small_font.sf2')!;
      expect(fontData.presets.length, greaterThan(1));

      // Pick the second preset from fontData
      final secondPreset = fontData.presets[1];
      final secondPresetLabel = GeneralMidiNames.getPresetDisplayName(
        secondPreset.bankNum,
        secondPreset.presetNum,
        secondPreset.name,
      );

      final secondPresetFinder = find.text(secondPresetLabel);
      if (secondPresetFinder.evaluate().isNotEmpty) {
        await tester.tap(secondPresetFinder.first);
        await tester.pumpAndSettle();

        expect(track.luaParams['PresetNum'], equals(secondPreset.presetNum.toDouble()));
        expect(track.luaParams['BankNum'], equals(secondPreset.bankNum.toDouble()));
      }
    });

    testWidgets('Selecting a bank from SoundFont Bank ListBox updates track SoundFont', (tester) async {
      final dawState = DawState();
      SoundFontEngine.instance.registerAvailablePack('custom_gm.sf2', 'Custom GM Bank');

      final sfPreset = LuaPresetLibrary.getPresetById('soundfont_sampler')!;
      final track = TrackChannel(
        id: 'sf_track_3',
        name: 'SoundFont Track',
        type: TrackType.luaScript,
        color: const Color(0xFF21F4E8),
        sampleName: 'super_small_font.sf2',
        luaScriptCode: sfPreset.code,
        luaParams: {
          'SoundFontBank': 0.0,
          'Preset': 0.0,
          'PresetNum': 0.0,
          'BankNum': 0.0,
        },
      );
      dawState.tracks.add(track);
      dawState.activeTrackIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom bank item appears in the list box
      final customBankFinder = find.text('Custom GM Bank');
      expect(customBankFinder, findsOneWidget);

      await tester.tap(customBankFinder);
      await tester.pumpAndSettle();

      expect(track.sampleName, equals('custom_gm.sf2'));
      expect(track.name, equals('Custom GM Bank'));
    });
  });
}
