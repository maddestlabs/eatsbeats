import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/audio_engine.dart';
import 'package:eatsbeats/audio/soundfont_engine.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/widgets/arranger_context_inspector.dart';
import 'package:eatsbeats/utils/midi_file_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MIDI Import Workflow & Dynamic Timeline Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    test('Timeline totalTimelineBars defaults to 32 and expands with longer clips/loops', () {
      expect(dawState.totalTimelineBars, 32);

      // Add a clip that extends to bar 48
      final track = dawState.activeTrack;
      final longClip = TrackClip(
        id: 'long_clip_1',
        name: 'Long Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 48,
      );
      track.clips.add(longClip);

      expect(dawState.totalTimelineBars, 48);

      // Seek to bar 40 should not be clamped to 31
      dawState.seekToBar(40);
      expect(dawState.currentBar, 40);
      expect(dawState.arrangerStep, 40 * 16);
    });

    test('MIDI import sets loop points to full song length and expands timeline', () {
      final midiTrack = ParsedMidiTrack(
        trackIndex: 0,
        name: 'Lead Melody',
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 4),
          Note(id: 'n2', pitch: 64, startStep: 39 * 16, durationSteps: 4), // 40th bar
        ],
      );

      dawState.importParsedMidiTrack(midiTrack, createNewTrack: true);

      expect(dawState.totalTimelineBars, greaterThanOrEqualTo(40));
      expect(dawState.loopStartBar, 0);
      expect(dawState.loopEndBar, greaterThanOrEqualTo(40));
      expect(dawState.isLooping, true);
    });

    test('Changing track instrument from SoundFont to synth cleans sampleName and synthesizes synth audio', () {
      final track = dawState.activeTrack;
      // Simulate track created from MIDI with super_small_font.sf2
      track.sampleName = 'super_small_font.sf2';
      track.type = TrackType.luaScript;
      final sfPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'soundfont_sampler');
      track.luaScriptCode = sfPreset.code;

      expect(track.sampleName, 'super_small_font.sf2');

      // Now apply Acid 303 Bass instrument
      final acidPreset = LuaPresetLibrary.presets.firstWhere(
        (p) => p.id == 'acid_bass',
        orElse: () => LuaPresetLibrary.presets.firstWhere((p) => p.isInstrument && p.id != 'soundfont_sampler'),
      );

      dawState.applyPreset(acidPreset, targetTrack: track);

      // sampleName should be cleared so it no longer routes to SoundFont
      expect(track.sampleName, '');
      expect(track.luaScriptCode, acidPreset.code);

      // Calling playNoteOrSample should synthesize via Lua synth without errors
      expect(
        () => dawState.audioEngine.playNoteOrSample(
          track: track,
          midiNote: 60,
          velocity: 0.8,
          durationSec: 0.1,
        ),
        returnsNormally,
      );
    });
  });

  group('Arranger Context Inspector Track Properties Tests', () {
    testWidgets('Renders SHOW GUI and CHANGE buttons directly in Track Properties header card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      dawState.selectClip(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 900,
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Track Properties title is rendered
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);

      // Verify "FOLDER ORGANIZATION" is NOT present on regular tracks
      expect(find.text('FOLDER ORGANIZATION'), findsNothing);

      // Verify SHOW GUI and CHANGE buttons are rendered
      expect(find.text('SHOW GUI'), findsOneWidget);
      expect(find.text('CHANGE'), findsOneWidget);

      // Tap SHOW GUI to verify floating window opens
      await tester.tap(find.text('SHOW GUI'));
      await tester.pumpAndSettle();
      expect(dawState.floatingInstrumentTrack?.id, track.id);

      dawState.dispose();
    });
  });
}
