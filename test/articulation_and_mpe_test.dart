import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Per-Note Articulations & MPE - Model & JSON Tests', () {
    test('Note articulation, release velocity, and MPE curve properties and aliases', () {
      final note = Note(
        id: 'n_art_1',
        pitch: 60,
        startStep: 0,
        durationSteps: 2,
        velocity: 0.8,
        articulation: 'muted',
        releaseVelocity: 0.45,
        pitchBendPoints: [[0.0, 0.0], [0.5, 2.0], [1.0, 0.0]],
        pressurePoints: [[0.0, 0.2], [0.8, 0.9]],
        timbrePoints: [[0.0, 0.1], [1.0, 0.85]],
      );

      expect(note.articulation, equals('muted'));
      expect(note.art, equals('muted'));
      expect(note.releaseVelocity, equals(0.45));
      expect(note.relVel, equals(0.45));
      expect(note.pitchBendPoints?.length, equals(3));
      expect(note.pressurePoints?.length, equals(2));
      expect(note.timbrePoints?.length, equals(2));
      expect(note.isBend, isTrue);

      // Mutate via aliases
      note.art = 'harmonics';
      expect(note.articulation, equals('harmonics'));
      note.relVel = 0.65;
      expect(note.releaseVelocity, equals(0.65));
    });

    test('Note curve interpolation works correctly', () {
      final note = Note(
        id: 'n_interp',
        pitch: 60,
        startStep: 0,
        durationSteps: 2,
        velocity: 0.8,
        pitchBendPoints: [[0.0, 0.0], [0.5, 2.0], [1.0, 4.0]],
        pressurePoints: [[0.0, 0.2], [1.0, 1.0]],
      );

      expect(note.getPitchBendAt(0.0), closeTo(0.0, 0.001));
      expect(note.getPitchBendAt(0.25), closeTo(1.0, 0.001));
      expect(note.getPitchBendAt(0.5), closeTo(2.0, 0.001));
      expect(note.getPitchBendAt(0.75), closeTo(3.0, 0.001));
      expect(note.getPitchBendAt(1.0), closeTo(4.0, 0.001));

      expect(note.getPressureAt(0.0), closeTo(0.2, 0.001));
      expect(note.getPressureAt(0.5), closeTo(0.6, 0.001));
      expect(note.getPressureAt(1.0), closeTo(1.0, 0.001));

      // Timbre fallback when no timbre points defined
      expect(note.getTimbreAt(0.5), closeTo(0.5, 0.001));
    });

    test('Note JSON serialization and deserialization preserves all articulation and MPE data', () {
      final note = Note(
        id: 'n_json_art',
        pitch: 65,
        startStep: 4.0,
        durationSteps: 1.5,
        velocity: 0.88,
        column: 1,
        articulation: 'palm_mute',
        releaseVelocity: 0.35,
        pitchBendPoints: [[0.0, 0.0], [0.5, 1.5], [1.0, 0.0]],
        pressurePoints: [[0.0, 0.1], [1.0, 0.9]],
        timbrePoints: [[0.0, 0.4], [1.0, 0.7]],
      );

      final json = note.toJson();
      expect(json['articulation'], equals('palm_mute'));
      expect(json['releaseVelocity'], equals(0.35));
      expect(json['pitchBendPoints'], isNotNull);
      expect(json['pressurePoints'], isNotNull);
      expect(json['timbrePoints'], isNotNull);

      final restored = Note.fromJson(json);
      expect(restored.articulation, equals('palm_mute'));
      expect(restored.releaseVelocity, equals(0.35));
      expect(restored.pitchBendPoints?.length, equals(3));
      expect(restored.pressurePoints?.length, equals(2));
      expect(restored.timbrePoints?.length, equals(2));
    });

    test('Note copyWith preserves or updates articulation and MPE fields', () {
      final original = Note(
        id: 'n_orig',
        pitch: 60,
        startStep: 0,
        articulation: 'muted',
        releaseVelocity: 0.4,
        pitchBendPoints: [[0.0, 0.0], [1.0, 2.0]],
      );

      final copied = original.copyWith(articulation: 'slap');
      expect(copied.articulation, equals('slap'));
      expect(copied.releaseVelocity, equals(0.4));
      expect(copied.pitchBendPoints?.length, equals(2));
    });
  });

  group('Per-Note Articulations & MPE - Lua Parsing & Serialization Tests', () {
    test('Sparse serialization keeps standard notes clean and minimal', () {
      final standardNotes = [
        Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0, velocity: 0.8),
        Note(id: 'n2', pitch: 64, startStep: 1.0, durationSteps: 1.0, velocity: 0.8),
      ];

      final luaString = EatsLuaSerializer.serializeNotes(standardNotes, relativeSteps: false);
      expect(luaString.contains('art ='), isFalse);
      expect(luaString.contains('bend ='), isFalse);
      expect(luaString.contains('pressure ='), isFalse);
      expect(luaString.contains('timbre ='), isFalse);
    });

    test('Expressive notes serialize art and MPE curves progressively', () {
      final expressiveNotes = [
        Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0, velocity: 0.8, articulation: 'muted'),
        Note(id: 'n2', pitch: 67, startStep: 2.0, durationSteps: 2.0, velocity: 0.9, pitchBendPoints: [[0.0, 0.0], [0.5, 2.0], [1.0, 0.0]]),
      ];

      final luaString = EatsLuaSerializer.serializeNotes(expressiveNotes, relativeSteps: false);
      expect(luaString.contains('art = "muted"'), isTrue);
      expect(luaString.contains('bend = { { 0.00, 0.00 }, { 0.50, 2.00 }, { 1.00, 0.00 } }'), isTrue);
    });

    test('parseNotes parses human-authored Lua note tables with art and MPE', () {
      const luaCode = '''
      notes = {
        { pitch = 79, start = 0.00, duration = 1.92, vel = 0.79 },
        { pitch = 51, start = 0.08, duration = 1.92, vel = 0.79, art = "muted", relVel = 0.3 },
        { pitch = 72, start = 2.00, duration = 2.00, vel = 0.85, bend = {{0.0, 0.0}, {0.5, 2.0}}, pressure = {{0.0, 0.1}, {1.0, 0.8}} },
        { 60, 4.00, 1.00, 0.90 }
      }
      ''';

      final parsed = EatsLuaParser.parseNotes(luaCode);
      expect(parsed.length, equals(4));

      expect(parsed[0].pitch, equals(79));
      expect(parsed[0].articulation, isNull);

      expect(parsed[1].pitch, equals(51));
      expect(parsed[1].articulation, equals('muted'));
      expect(parsed[1].releaseVelocity, closeTo(0.3, 0.01));

      expect(parsed[2].pitch, equals(72));
      expect(parsed[2].pitchBendPoints?.length, equals(2));
      expect(parsed[2].pressurePoints?.length, equals(2));

      // Compact array format
      expect(parsed[3].pitch, equals(60));
      expect(parsed[3].startStep, closeTo(4.0, 0.01));
      expect(parsed[3].velocity, closeTo(0.9, 0.01));
    });

    test('DawState export and load round-trips articulation and MPE', () {
      final state = DawState();
      final track = state.activeTrack;
      track.notes.clear();
      track.notes.addAll([
        Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2, velocity: 0.8),
        Note(id: 'n2', pitch: 64, startStep: 2, durationSteps: 2, velocity: 0.85, articulation: 'palm_mute'),
        Note(id: 'n3', pitch: 67, startStep: 4, durationSteps: 2, velocity: 0.9, pitchBendPoints: [[0.0, 0.0], [0.5, 2.0]]),
      ]);

      final songLua = state.exportToEatsLua();
      expect(songLua.contains('art = "palm_mute"'), isTrue);
      expect(songLua.contains('bend = { { 0.00, 0.00 }, { 0.50, 2.00 } }'), isTrue);

      final newState = DawState();
      newState.loadFromEatsLua(songLua);

      final loadedTrack = newState.patterns.first.tracks.firstWhere((t) => t.id == track.id);
      expect(loadedTrack.notes.length, equals(3));
      expect(loadedTrack.notes[0].articulation, isNull);
      expect(loadedTrack.notes[1].articulation, equals('palm_mute'));
      expect(loadedTrack.notes[2].pitchBendPoints?.length, equals(2));
    });
  });

  group('Per-Note Articulations & MPE - DawState Mutations', () {
    late DawState daw;

    setUp(() {
      daw = DawState();
    });

    test('setNoteArticulation and setNotesArticulation update notes and notify state', () {
      final track = daw.activeTrack;
      track.notes.clear();
      final n1 = Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2);
      final n2 = Note(id: 'n2', pitch: 64, startStep: 2, durationSteps: 2);
      track.notes.addAll([n1, n2]);

      daw.setNoteArticulation(track, n1, 'muted');
      expect(track.notes.firstWhere((n) => n.id == 'n1').articulation, equals('muted'));

      daw.setNotesArticulation(track, ['n1', 'n2'], 'harmonics');
      expect(track.notes.firstWhere((n) => n.id == 'n1').articulation, equals('harmonics'));
      expect(track.notes.firstWhere((n) => n.id == 'n2').articulation, equals('harmonics'));
    });

    test('setNoteMPECurves updates curve points on targeted note', () {
      final track = daw.activeTrack;
      track.notes.clear();
      final n1 = Note(id: 'n_mpe', pitch: 60, startStep: 0, durationSteps: 2);
      track.notes.add(n1);

      daw.setNoteMPECurves(
        track,
        n1,
        bend: [[0.0, 0.0], [0.5, 3.0]],
        pressure: [[0.0, 0.2], [1.0, 0.8]],
        timbre: [[0.0, 0.3], [1.0, 0.9]],
      );

      final updated = track.notes.firstWhere((n) => n.id == 'n_mpe');
      expect(updated.pitchBendPoints?.length, equals(2));
      expect(updated.pressurePoints?.length, equals(2));
      expect(updated.timbrePoints?.length, equals(2));
    });
  });

  group('Per-Note Articulations & MPE - DSP Graph & Audio Synthesis Tests', () {
    test('DecayEnvNode produces shorter energy when muted articulation is active', () {
      const node = DecayEnvNode(decaySec: 0.3);

      final normalCtx = GraphContext(
        durationSec: 0.3,
        freq: 440.0,
        midiNote: 69,
      );
      final normalBuf = Float32List(normalCtx.totalSamples);
      node.process(normalCtx, normalBuf);

      final mutedCtx = GraphContext(
        durationSec: 0.3,
        freq: 440.0,
        midiNote: 69,
        articulation: 'muted',
      );
      final mutedBuf = Float32List(mutedCtx.totalSamples);
      node.process(mutedCtx, mutedBuf);

      // Muted buffer decays much faster; sample at half duration should be significantly lower
      final midIdx = normalCtx.totalSamples ~/ 2;
      expect(mutedBuf[midIdx], lessThan(normalBuf[midIdx]));
    });

    test('WaveguideNode adapts to muted articulation and pitch bend curves', () {
      const exciter = PlectrumStrumExciterNode(strumSpreadMs: 4.0, pickBite: 1.0);
      const waveguide = WaveguideNode(exciter: exciter, feedback: 0.995, damping: 0.3);

      final normalBuf = GraphEvaluator.evaluate(
        root: waveguide,
        durationSec: 0.2,
        freq: 220.0,
        note: 57,
        params: {},
      );

      final mutedBuf = GraphEvaluator.evaluate(
        root: waveguide,
        durationSec: 0.2,
        freq: 220.0,
        note: 57,
        params: {},
        articulation: 'muted',
      );

      final bentBuf = GraphEvaluator.evaluate(
        root: waveguide,
        durationSec: 0.2,
        freq: 220.0,
        note: 57,
        params: {},
        pitchBendPoints: [[0.0, 0.0], [0.5, 4.0], [1.0, 0.0]],
      );

      expect(normalBuf.length, equals(mutedBuf.length));
      expect(bentBuf.length, equals(normalBuf.length));

      // Calculate total RMS energy
      double normalEnergy = 0.0;
      double mutedEnergy = 0.0;
      for (int i = 0; i < normalBuf.length; i++) {
        normalEnergy += normalBuf[i] * normalBuf[i];
        mutedEnergy += mutedBuf[i] * mutedBuf[i];
      }

      // Muted note has less sustained loop energy
      expect(mutedEnergy, lessThan(normalEnergy));
    });

    test('LuaEngine.synthesizeBuffer synthesizes with articulation and MPE dimensions', () {
      final bufNormal = LuaEngine.synthesizeBuffer(
        code: 'function Synth.process() end',
        durationSec: 0.2,
        freq: 440.0,
        note: 69,
        params: {'Cutoff': 3000.0},
      );

      final bufMuted = LuaEngine.synthesizeBuffer(
        code: 'function Synth.process() end',
        durationSec: 0.2,
        freq: 440.0,
        note: 69,
        params: {'Cutoff': 3000.0},
        articulation: 'muted',
      );

      final bufMpe = LuaEngine.synthesizeBuffer(
        code: 'function Synth.process() end',
        durationSec: 0.2,
        freq: 440.0,
        note: 69,
        params: {'Cutoff': 3000.0},
        pitchBendPoints: [[0.0, 0.0], [1.0, 2.0]],
        pressurePoints: [[0.0, 0.1], [1.0, 1.0]],
        timbrePoints: [[0.0, 0.2], [1.0, 0.9]],
      );

      expect(bufNormal.isNotEmpty, isTrue);
      expect(bufMuted.isNotEmpty, isTrue);
      expect(bufMpe.isNotEmpty, isTrue);
    });
  });
}
