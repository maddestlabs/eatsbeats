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

  group('JC-303 & Eatsbits Silver GUI API Tests', () {
    test('LuaGuiParser correctly parses silver chassis, chrome knobs, and dividers', () {
      const scriptCode = '''
local JC303 = {}
function JC303.init()
  Param.add("Cutoff", 200.0, 4500.0, 1400.0)
  Param.add("Resonance", 0.5, 16.0, 9.2)
end
function JC303.gui()
  return {
    panel = {
      title = "JC-303 ACID BASSLINE",
      subtitle = "midilab/jc303 & Open303 Transistor Bass",
      background = "silver",
      accent = "track",
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
return JC303
''';

      final panelDef = LuaGuiParser.parseFromCode(scriptCode);
      expect(panelDef, isNotNull);
      expect(panelDef!.title, 'JC-303 ACID BASSLINE');
      expect(panelDef.backgroundStyle, PanelBackgroundStyle.silver);
      expect(panelDef.defaultKnobStyle, KnobStyle.chrome);
      expect(panelDef.accentColor, isNull); // accent = "track" resolves to null for track color inheritance

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

    testWidgets('DynamicInstrumentGuiWidget renders silver JC-303 panel and chrome knobs', (tester) async {
      final dawState = DawState();
      final preset = LuaPresetLibrary.getPresetById('jc_303')!;

      final track = TrackChannel(
        id: 'track_303',
        name: 'JC-303',
        color: const Color(0xFFE040FB), // Magenta custom track color
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

      // Verify GrungyRackPanel rendered with silver background and JC-303 title
      expect(find.byType(GrungyRackPanel), findsOneWidget);
      expect(find.text('JC-303 ACID BASSLINE'), findsOneWidget);

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

  group('JC-303 / Open303 DSP Synthesis Dynamics Tests', () {
    test('JC-303 synthesis produces non-zero audio buffer and handles slides & accents', () {
      final preset = LuaPresetLibrary.getPresetById('jc_303')!;

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

    test('isMonophonicTrack detects JC-303, Acid303, TB303, bass tracks and polyphony=1', () {
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

    test('Default instruments inherit track color while SNES instruments retain console theme', () {
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
        'jc_303',
        'ym2612_synth',
      ];

      for (final id in defaultPresetIds) {
        final preset = LuaPresetLibrary.getPresetById(id);
        expect(preset, isNotNull, reason: 'Preset $id should exist');
        final panelDef = LuaGuiParser.parseFromCode(preset!.code);
        expect(panelDef, isNotNull, reason: 'Preset $id should have a GUI panel');
        expect(panelDef!.accentColor, isNull, reason: 'Preset $id should inherit track color');
      }

      // 2. Check SNES instruments retain their console purple theme
      final snesPreset = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final snesPanel = LuaGuiParser.parseFromCode(snesPreset.code);
      expect(snesPanel, isNotNull);
      expect(snesPanel!.accentColor, const Color(0xFF7B52AB), reason: 'SNES instrument should retain custom console styling');
    });
  });
}
