import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DSP ADSR & Envelope Unit Tests', () {
    test('LuaEngine.evaluateAdsr curves through Attack, Decay, Sustain, and Release', () {
      const attack = 0.1;
      const decay = 0.1;
      const sustain = 0.5;
      const release = 0.2;
      const duration = 0.4;

      // 1. Initial / start of attack
      expect(LuaEngine.evaluateAdsr(0.0, attack, decay, sustain, release, duration), closeTo(0.0, 0.001));

      // 2. Mid-attack (0.05s)
      expect(LuaEngine.evaluateAdsr(0.05, attack, decay, sustain, release, duration), closeTo(0.5, 0.05));

      // 3. Peak of attack / start of decay (0.1s)
      expect(LuaEngine.evaluateAdsr(0.1, attack, decay, sustain, release, duration), closeTo(1.0, 0.001));

      // 4. Mid-decay (0.15s) -> should be between 1.0 and 0.5
      final midDecay = LuaEngine.evaluateAdsr(0.15, attack, decay, sustain, release, duration);
      expect(midDecay, greaterThan(0.5));
      expect(midDecay, lessThan(1.0));

      // 5. Sustain phase (0.25s to 0.4s)
      expect(LuaEngine.evaluateAdsr(0.25, attack, decay, sustain, release, duration), closeTo(0.5, 0.001));
      expect(LuaEngine.evaluateAdsr(0.35, attack, decay, sustain, release, duration), closeTo(0.5, 0.001));

      // 6. Release phase (0.5s -> 0.1s into 0.2s release)
      final midRelease = LuaEngine.evaluateAdsr(0.5, attack, decay, sustain, release, duration);
      expect(midRelease, closeTo(0.25, 0.05));

      // 7. Post-release (0.7s) -> silence
      expect(LuaEngine.evaluateAdsr(0.7, attack, decay, sustain, release, duration), closeTo(0.0, 0.001));
    });

    test('Zero attack time yields immediate transient full volume', () {
      expect(LuaEngine.evaluateAdsr(0.0, 0.0, 0.1, 0.8, 0.2, 0.4), equals(1.0));
      expect(LuaEngine.evaluateEnv(0.0, 0.0, 0.2, 0.4), equals(1.0));
    });
  });

  group('SoundFont Preset & Sampler ADSR Configuration Tests', () {
    test('SoundFont 2 Player preset compiles without FilterCutoff and with AttackSec default 0.0', () {
      final sfPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'soundfont_sampler');
      final compiled = LuaEngine.compile(sfPreset.code);

      expect(compiled.isSuccess, isTrue);

      // Verify FilterCutoff is removed
      final hasFilterCutoff = compiled.params.any((p) => p.name == 'FilterCutoff');
      expect(hasFilterCutoff, isFalse, reason: 'FilterCutoff should not be in soundfont preset');

      // Verify AttackSec defaults to 0.0
      final attackParam = compiled.params.firstWhere((p) => p.name == 'AttackSec');
      expect(attackParam.defaultValue, equals(0.0));

      // Verify PresetNum and BankNum exist
      expect(compiled.params.any((p) => p.name == 'PresetNum'), isTrue);
      expect(compiled.params.any((p) => p.name == 'BankNum'), isTrue);
    });

    test('Sampler Instrument preset compiles with full ADSR parameter set', () {
      final samplerPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'sampler_instrument');
      final compiled = LuaEngine.compile(samplerPreset.code);

      expect(compiled.isSuccess, isTrue);
      expect(compiled.params.any((p) => p.name == 'AttackSec'), isTrue);
      expect(compiled.params.any((p) => p.name == 'DecaySec'), isTrue);
      expect(compiled.params.any((p) => p.name == 'Sustain'), isTrue);
      expect(compiled.params.any((p) => p.name == 'ReleaseSec'), isTrue);
    });
  });

  group('Sequencer & Piano Roll Polyphony Tests', () {
    test('Polyphonic track plays multiple simultaneous notes on the same step', () {
      final daw = DawState();
      final track = TrackChannel(
        id: 'poly_track',
        name: 'SoundFont Poly',
        type: TrackType.synth,
        color: const Color(0xFF21F4E8),
        sampleName: 'test.sf2',
      );

      // Add a clip with a 3-note chord on step 0
      final clip = TrackClip(
        id: 'clip_poly_1',
        name: 'Chord Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2), // C4
          Note(id: 'n2', pitch: 64, startStep: 0, durationSteps: 2), // E4
          Note(id: 'n3', pitch: 67, startStep: 0, durationSteps: 2), // G4
        ],
      );
      track.clips.add(clip);
      daw.activePattern.tracks.clear();
      daw.activePattern.tracks.add(track);

      expect(track.isMonophonicTrack, isFalse);

      final matchingNotes = clip.notes.where((n) => n.startStep.toInt() == 0).toList();
      expect(matchingNotes.length, equals(3));
    });
  });
}
