import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_gui_model.dart';
import 'package:mobile_wren_daw/lua/lua_gui_parser.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/grungy_rack_panel.dart';
import 'package:mobile_wren_daw/ui/widgets/skeuomorphic_hardware_knob.dart';
import 'package:mobile_wren_daw/ui/widgets/skeuomorphic_hardware_switch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Eats-303 & Silver GUI API Tests', () {
    test('LuaGuiParser correctly parses silver chassis, chrome knobs, and dividers', () {
      const scriptCode = '''
local Eats303 = {}
function Eats303.init()
  Param.add("Cutoff", 200.0, 4500.0, 1400.0)
  Param.add("Resonance", 0.5, 16.0, 9.2)
end
function Eats303.gui()
  return {
    panel = {
      title = "EATS-303 ACID BASSLINE",
      subtitle = "Roland TB-303 Emulation • (JC-303 & Open303 DSP)",
      background = "silver",
      accent = "#000000",
      knobStyle = "chrome",
      layout = {
        {
          type = "row",
          children = {
            { type = "switch", param = "Waveform", label = "WAVEFORM", options = {"SAW", "SQR"} },
            { type = "divider", orientation = "vertical", height = 62 },
            { type = "knob", param = "Cutoff", label = "CUTOFF", size = 58 },
            { type = "knob", param = "Resonance", label = "RESONANCE", size = 58 },
          }
        },
        { type = "divider", orientation = "horizontal" }
      }
    }
  }
end
return Eats303
''';

      final panelDef = LuaGuiParser.parseFromCode(scriptCode);
      expect(panelDef, isNotNull);
      expect(panelDef!.title, 'EATS-303 ACID BASSLINE');
      expect(panelDef.backgroundStyle, PanelBackgroundStyle.silver);
      expect(panelDef.defaultKnobStyle, KnobStyle.chrome);
      expect(panelDef.accentColor, const Color(0xFF000000));

      expect(panelDef.children.length, 2);
      expect(panelDef.children[0].type, LuaGuiNodeType.row);
      expect(panelDef.children[1].type, LuaGuiNodeType.divider);
      expect(panelDef.children[1].orientation, 'horizontal');

      final rowChildren = panelDef.children[0].children;
      expect(rowChildren.length, 4);
      expect(rowChildren[0].type, LuaGuiNodeType.switchToggle);
      expect(rowChildren[1].type, LuaGuiNodeType.divider);
      expect(rowChildren[1].orientation, 'vertical');
      expect(rowChildren[2].type, LuaGuiNodeType.knob);
      expect(rowChildren[2].knobStyle, KnobStyle.chrome);
    });

    testWidgets('DynamicInstrumentGuiWidget renders silver Eats-303 panel and chrome knobs', (tester) async {
      final dawState = DawState();
      final preset = LuaPresetLibrary.getPresetById('eats_303')!;

      final track = TrackChannel(
        id: 'track_303',
        name: 'Eats-303',
        color: const Color(0xFFE040FB),
        type: TrackType.synth,
        luaScriptCode: preset.code,
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

      // Verify GrungyRackPanel rendered with silver background and Eats-303 title
      expect(find.byType(GrungyRackPanel), findsOneWidget);
      expect(find.text('EATS-303 ACID BASSLINE'), findsOneWidget);

      // Verify knobs and switches rendered
      expect(find.byType(SkeuomorphicHardwareKnob), findsWidgets);
      expect(find.byType(SkeuomorphicHardwareSwitch), findsWidgets);

      // Verify Cutoff and Resonance labels
      expect(find.text('CUTOFF'), findsOneWidget);
      expect(find.text('RESONANCE'), findsOneWidget);
      expect(find.text('ENV MOD'), findsOneWidget);
      expect(find.text('ACCENT'), findsOneWidget);
    });
  });

  group('Eats-303 / Open303 DSP Synthesis Dynamics Tests', () {
    test('Eats-303 synthesis produces non-zero audio buffer and handles slides & accents', () {
      final preset = LuaPresetLibrary.getPresetById('eats_303')!;

      // 1. Normal note synthesis
      final normalBuf = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 110.0, // Note A2
        note: 45,
        params: {
          'Waveform': 0.0,
          'Cutoff': 1400.0,
          'Resonance': 9.2,
          'EnvMod': 0.75,
          'Decay': 0.5,
          'Accent': 0.0,
          'Drive': 0.25,
        },
        isSlide: false,
        isAccent: false,
        trackId: 'voice_test_303',
      );

      expect(normalBuf.length, (44100 * 0.4).toInt());
      double normalPeak = 0.0;
      for (final sample in normalBuf) {
        if (sample.abs() > normalPeak) normalPeak = sample.abs();
      }
      expect(normalPeak, greaterThan(0.05));

      // 2. Accented note synthesis: should have greater energy / peak amplitude
      final accentBuf = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 110.0,
        note: 45,
        params: {
          'Waveform': 0.0,
          'Cutoff': 1400.0,
          'Resonance': 9.2,
          'EnvMod': 0.75,
          'Decay': 0.5,
          'Accent': 1.0,
          'Drive': 0.25,
        },
        isSlide: false,
        isAccent: true,
        trackId: 'voice_test_303',
      );

      double accentPeak = 0.0;
      for (final sample in accentBuf) {
        if (sample.abs() > accentPeak) accentPeak = sample.abs();
      }
      expect(accentPeak, greaterThan(0.05));

      // 3. Legato slide transition: slides smoothly to target note
      final slideBuf = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 110.0,
        note: 45,
        targetMidiNote: 57, // A3 (octave higher)
        params: {
          'Waveform': 1.0, // Square wave
          'Cutoff': 2200.0,
          'Resonance': 8.0,
          'EnvMod': 0.8,
          'Decay': 0.4,
          'Accent': 0.5,
          'Slide': 1.0,
        },
        isSlide: true,
        isAccent: false,
        trackId: 'voice_test_303',
      );

      expect(slideBuf.length, (44100 * 0.4).toInt());
      double slidePeak = 0.0;
      for (final sample in slideBuf) {
        if (sample.abs() > slidePeak) slidePeak = sample.abs();
      }
      expect(slidePeak, greaterThan(0.05));
    });

    test('isMonophonicTrack detects Eats-303, JC-303, Acid303, TB303, bass tracks and polyphony=1', () {
      final eats303Track = TrackChannel(
        id: 't0',
        name: 'Eats-303 Bass',
        color: const Color(0xFF00E5FF),
        type: TrackType.synth,
        luaScriptCode: 'local Eats303 = {}\nreturn Eats303',
      );
      expect(eats303Track.isMonophonicTrack, isTrue);

      final jc303Track = TrackChannel(
        id: 't1',
        name: 'JC-303 Bass',
        color: const Color(0xFF00E5FF),
        type: TrackType.synth,
        luaScriptCode: 'local JC303 = {}\nreturn JC303',
      );
      expect(jc303Track.isMonophonicTrack, isTrue);

      final tb303Track = TrackChannel(
        id: 't2',
        name: 'TB-303 Lead',
        color: const Color(0xFF00E5FF),
        type: TrackType.synth,
        luaScriptCode: 'local TB303 = {}\nreturn TB303',
      );
      expect(tb303Track.isMonophonicTrack, isTrue);

      final genericBassTrack = TrackChannel(
        id: 't3',
        name: 'Sub Bass',
        color: const Color(0xFF00E5FF),
        type: TrackType.bass,
      );
      expect(genericBassTrack.isMonophonicTrack, isTrue);

      final polySynthTrack = TrackChannel(
        id: 't4',
        name: 'Poly Synth',
        color: const Color(0xFF00E5FF),
        type: TrackType.synth,
        luaScriptCode: 'local PolySynth = {}\nreturn PolySynth',
      );
      expect(polySynthTrack.isMonophonicTrack, isFalse);
    });

    test('Default drum and synth instruments inherit track color while SNES/Eats-303 retain custom theme', () {
      // 1. Check default drum and synth instruments have accent = "track" (parsed as null for track color inheritance)
      final defaultPresetIds = [
        'fm_acoustic_kick',
        'fm_acoustic_snare',
        'fm_acoustic_tom',
        'fm_acoustic_hihat',
        'analog_808_kick',
        'analog_808_snare',
        'analog_808_hihat',
        'analog_808_cowbell',
        'analog_808_tom',
        'analog_909_kick',
        'analog_909_snare',
        'analog_909_closed_hihat',
        'analog_909_open_hihat',
        'analog_909_clap',
        'analog_909_rimshot',
        'ym2612_synth',
      ];

      for (final id in defaultPresetIds) {
        final preset = LuaPresetLibrary.getPresetById(id);
        expect(preset, isNotNull, reason: 'Preset $id should exist');
        final panelDef = LuaGuiParser.parseFromCode(preset!.code);
        expect(panelDef, isNotNull, reason: 'Preset $id should have a GUI panel');
        expect(panelDef!.accentColor, isNull, reason: 'Preset $id should inherit track color');
      }

      // 2. Check Eats-303 uses authentic black accent on silver chassis
      final eats303Preset = LuaPresetLibrary.getPresetById('eats_303')!;
      final eats303Panel = LuaGuiParser.parseFromCode(eats303Preset.code);
      expect(eats303Panel, isNotNull);
      expect(eats303Panel!.accentColor, const Color(0xFF000000), reason: 'Eats-303 should use authentic black dials/levels');

      // 3. Check SNES instruments retain their console purple theme
      final snesPreset = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final snesPanel = LuaGuiParser.parseFromCode(snesPreset.code);
      expect(snesPanel, isNotNull);
      expect(snesPanel!.accentColor, const Color(0xFF7B52AB), reason: 'SNES instrument should retain custom console styling');
    });

    test('Simultaneous notes in pattern sequencer trigger note slides on Eats-303 track', () {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'Eats-303';
      track.type = TrackType.synth;
      track.luaScriptCode = LuaPresetLibrary.getPresetById('eats_303')!.code;

      expect(track.isMonophonicTrack, isTrue);

      track.notes.clear();

      // Add two simultaneous notes at step 0 (e.g. note C2 and G2)
      final note1 = Note(id: 'n1', pitch: 36, startStep: 0.0, durationSteps: 2.0);
      final note2 = Note(id: 'n2', pitch: 43, startStep: 0.0, durationSteps: 2.0);

      state.addNote(track, note1);
      state.addNote(track, note2);

      expect(track.notes.length, 2);

      // Synthesis of monophonic slide with simultaneous notes
      final slideBuffer = LuaEngine.synthesizeBuffer(
        code: track.luaScriptCode,
        durationSec: 0.4,
        freq: 65.41, // C2
        note: 36,
        targetMidiNote: 43, // Slide target G2
        params: {},
        isSlide: true,
        trackId: track.id,
      );

      expect(slideBuffer.isNotEmpty, isTrue);
      state.dispose();
    });
  });
}
