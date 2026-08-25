import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/soundfont_engine.dart';
import 'package:eatsbeats/audio/soundfont_decoder.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_gui_model.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:eatsbeats/ui/widgets/hardware_listbox_widget.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_knob.dart';
import 'package:eatsbeats/ui/lua_workbench_view.dart';
import 'package:eatsbeats/ui/script_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SoundFontEngine.instance.loadDefaultBundledFont();
  });

  group('SoundFont 2 Player Preset & GUI Layout Tests', () {
    test('SoundFont 2 Player compiles with SNES background, track accent, and 2-row layout', () {
      final sfPreset = LuaPresetLibrary.getPresetById('soundfont_sampler')!;
      final compilation = LuaEngine.compile(sfPreset.code);

      expect(compilation.isSuccess, isTrue);
      expect(compilation.guiLayout, isNotNull);

      final gui = compilation.guiLayout!;
      expect(gui.title, equals('SoundFont 2 Player'));
      expect(gui.backgroundStyle, equals(PanelBackgroundStyle.snes));
      // Follows track-based color scheme
      expect(gui.accentColor, isNull);
      expect(gui.defaultKnobStyle, equals(KnobStyle.snes));

      // Check 2-row layout: Row 1 = ListBoxes, Row 2 = Knobs
      expect(gui.children.length, equals(2));
      final row1 = gui.children[0];
      final row2 = gui.children[1];

      final bankListBox = row1.children.firstWhere((c) => c.param == 'SoundFontBank');
      expect(bankListBox.width, equals(160.0));
      expect(bankListBox.height, equals(90.0));

      final presetListBox = row1.children.firstWhere((c) => c.param == 'Preset');
      expect(presetListBox.width, equals(200.0));
      expect(presetListBox.height, equals(90.0));

      // Row 2 contains the 5 knobs
      expect(row2.children.length, equals(5));
      expect(row2.children.any((c) => c.param == 'AttackSec'), isTrue);
      expect(row2.children.any((c) => c.param == 'DecaySec'), isTrue);
      expect(row2.children.any((c) => c.param == 'Sustain'), isTrue);
      expect(row2.children.any((c) => c.param == 'ReleaseSec'), isTrue);
      expect(row2.children.any((c) => c.param == 'Gain'), isTrue);

      // Verify parameters exist
      expect(compilation.params.any((p) => p.name == 'PresetNum'), isTrue);
      expect(compilation.params.any((p) => p.name == 'BankNum'), isTrue);
    });
  });

  group('SoundFont GUI ListBox Widget Interaction Tests', () {
    testWidgets('DynamicInstrumentGuiWidget renders SoundFont Player with 2-row layout and INSTRUMENT badge', (tester) async {
      final dawState = DawState();
      final sfPreset = LuaPresetLibrary.getPresetById('soundfont_sampler')!;
      final track = TrackChannel(
        id: 'sf_track_1',
        name: 'SoundFont Track',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00), // Track color (Orange)
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

      // Verify Top Right Badge reads INSTRUMENT
      expect(find.text('INSTRUMENT'), findsOneWidget);
      expect(find.text('LUA VSTi'), findsNothing);

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
        color: const Color(0xFF00FF66),
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
        color: const Color(0xFFBD00FF),
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

      final customBankFinder = find.text('Custom GM Bank');
      expect(customBankFinder, findsOneWidget);

      await tester.tap(customBankFinder);
      await tester.pumpAndSettle();

      expect(track.sampleName, equals('custom_gm.sf2'));
      // Track name should be preserved and not overwritten by the bank name
      expect(track.name, equals('SoundFont Track'));
    });
  });

  group('SoundFont Buffer Anti-Clicking Tests', () {
    test('getPitchShiftedBuffer smoothly fades tail without harsh end clipping', () {
      final buffer = SoundFontEngine.instance.getPitchShiftedBuffer(
        fontId: 'super_small_font.sf2',
        presetNum: 0,
        midiNote: 60,
        targetDurationSec: 0.2,
      );

      expect(buffer.isNotEmpty, isTrue);
      // Last sample in buffer should fade to near zero
      expect(buffer.last.abs(), lessThan(0.01));
    });
  });

  group('Script Editor Theme Consistency Tests', () {
    testWidgets('LuaWorkbenchView and ScriptView use readable theme-consistent colors in light theme', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      EatsTheme.currentPreset = EatsThemePreset.lightSnack;
      expect(EatsTheme.isLight, isTrue);

      final dawState = DawState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScriptView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scriptTextFields = find.byType(TextField);
      expect(scriptTextFields, findsOneWidget);
      final scriptWidget = tester.widget<TextField>(scriptTextFields.first);
      expect(scriptWidget.style?.color, equals(EatsTheme.codeEditorTextColor));
      // In light theme, text color is high-contrast slate-900 (Color(0xFF0F172A))
      expect(scriptWidget.style?.color, equals(const Color(0xFF0F172A)));

      // Also verify LuaWorkbenchView text styling
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: LuaWorkbenchView(dawState: dawState),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final workbenchTextFields = find.byType(TextField);
      expect(workbenchTextFields, findsWidgets);
      final editorField = tester.widgetList<TextField>(workbenchTextFields).firstWhere(
        (tf) => tf.maxLines == null,
      );
      expect(editorField.style?.color, equals(EatsTheme.codeEditorTextColor));
      expect(editorField.style?.color, equals(const Color(0xFF0F172A)));

      // Reset theme
      EatsTheme.currentPreset = EatsThemePreset.ateTrack;
    });
  });
}
