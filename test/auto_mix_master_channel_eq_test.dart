import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track Channel Strip EQ & Tags Model Tests', () {
    test('TrackChannel initializes with clean flat EQ and semantic tag getters', () {
      final track = TrackChannel(
        id: 't_kick',
        name: 'Acoustic Kick Drum',
        color: Colors.green,
        type: TrackType.synth,
        tags: ['kick', 'acoustic'],
      );

      expect(track.eqEnabled, isFalse);
      expect(track.eqHpf, 20.0);
      expect(track.eqLowGain, 0.0);
      expect(track.eqMidFreq, 1000.0);
      expect(track.eqMidGain, 0.0);
      expect(track.eqMidQ, 1.0);
      expect(track.eqHighGain, 0.0);
      expect(track.tags, equals(['kick', 'acoustic']));
      expect(track.primaryTag, equals('kick'));
    });

    test('TrackChannel primaryTag infers from track name when tags list is empty', () {
      final bassTrack = TrackChannel(
        id: 't_303',
        name: 'Acid 303 Sub',
        color: Colors.purple,
        type: TrackType.synth,
      );
      expect(bassTrack.primaryTag, equals('bass'));

      final rhodesTrack = TrackChannel(
        id: 't_keys',
        name: 'Electric Rhodes',
        color: Colors.blue,
        type: TrackType.synth,
      );
      expect(rhodesTrack.primaryTag, equals('piano'));

      final voxTrack = TrackChannel(
        id: 't_vox',
        name: 'Main Vocal Chop',
        color: Colors.orange,
        type: TrackType.synth,
      );
      expect(voxTrack.primaryTag, equals('vocal'));
    });

    test('TrackChannel copyWith and JSON serialization preserves EQ and tags', () {
      final track = TrackChannel(
        id: 't_snare',
        name: 'Snare 909',
        color: Colors.red,
        type: TrackType.synth,
        eqEnabled: true,
        eqHpf: 150.0,
        eqLowGain: 2.5,
        eqMidFreq: 2400.0,
        eqMidGain: -3.0,
        eqMidQ: 2.0,
        eqHighGain: 1.5,
        tags: ['snare', 'analog'],
      );

      final json = track.toJson();
      expect(json['eqEnabled'], isTrue);
      expect(json['eqHpf'], 150.0);
      expect(json['eqLowGain'], 2.5);
      expect(json['eqMidFreq'], 2400.0);
      expect(json['eqMidGain'], -3.0);
      expect(json['eqMidQ'], 2.0);
      expect(json['eqHighGain'], 1.5);
      expect(json['tags'], equals(['snare', 'analog']));

      final restored = TrackChannel.fromJson(json);
      expect(restored.eqEnabled, isTrue);
      expect(restored.eqHpf, 150.0);
      expect(restored.eqLowGain, 2.5);
      expect(restored.eqMidFreq, 2400.0);
      expect(restored.eqMidGain, -3.0);
      expect(restored.eqMidQ, 2.0);
      expect(restored.eqHighGain, 1.5);
      expect(restored.tags, equals(['snare', 'analog']));
      expect(restored.primaryTag, equals('snare'));
    });
  });

  group('DawState Master Bus & Telemetry Tests', () {
    test('DawState sets Master EQ and Master Limiter with clamped ranges', () {
      final dawState = DawState();

      dawState.setMasterEq(
        subCut: 30.0,
        lowGain: 1.5,
        midFreq: 400.0,
        midGain: -2.0,
        highGain: 2.5,
      );

      expect(dawState.masterSubCut, 30.0);
      expect(dawState.masterLowGain, 1.5);
      expect(dawState.masterMidFreq, 400.0);
      expect(dawState.masterMidGain, -2.0);
      expect(dawState.masterHighGain, 2.5);

      dawState.setMasterLimiter(
        enabled: true,
        ceilingDbfs: -0.5,
        driveDb: 3.0,
        targetLufs: -12.0,
      );

      expect(dawState.masterLimiterEnabled, isTrue);
      expect(dawState.masterCeilingDbfs, -0.5);
      expect(dawState.masterLimiterDrive, 3.0);
      expect(dawState.masterTargetLufs, -12.0);
    });

    test('extractMixTelemetry generates structured telemetry map for Gemini AI', () {
      final dawState = DawState();
      final telemetry = dawState.extractMixTelemetry(genreVibe: 'lofi', targetLufs: -14.0);

      expect(telemetry['version'], equals('1.0'));
      expect(telemetry['targetLufs'], equals(-14.0));
      expect(telemetry['genreVibe'], equals('lofi'));
      expect(telemetry.containsKey('master'), isTrue);
      expect(telemetry.containsKey('tracks'), isTrue);

      final master = telemetry['master'] as Map;
      expect(master.containsKey('subCut'), isTrue);
      expect(master.containsKey('limiterEnabled'), isTrue);

      final tracks = telemetry['tracks'] as Map;
      expect(tracks.isNotEmpty, isTrue);

      final firstTrack = tracks.values.first as Map;
      expect(firstTrack.containsKey('role'), isTrue);
      expect(firstTrack.containsKey('peakDbfs'), isTrue);
      expect(firstTrack.containsKey('rmsDbfs'), isTrue);
      expect(firstTrack.containsKey('crestFactorDb'), isTrue);
      expect(firstTrack.containsKey('dominantFreqHz'), isTrue);
      expect(firstTrack.containsKey('energyBands'), isTrue);
      expect(firstTrack.containsKey('eq'), isTrue);
    });
  });

  group('Lua Script Library & @tags Parsing Tests', () {
    test('parseFromLuaScript extracts -- @tags: header', () {
      const luaCode = '''
-- @name: Vintage 808 Sub
-- @category: instrument
-- @description: Pure sine 808 boom with punch envelope
-- @tags: bass, 808, sub, analog

local Synth808 = {}
return Synth808
''';

      final script = LuaScriptLibrary.parseFromLuaScript(luaCode);
      expect(script.name, equals('Vintage 808 Sub'));
      expect(script.tags, equals(['bass', '808', 'sub', 'analog']));
      expect(script.primaryTag, equals('bass'));
    });
  });

  group('EatsLua Serialization & Parsing Roundtrip Tests', () {
    test('Full project roundtrip serializes and parses track EQ and master processing', () {
      final dawState = DawState();
      dawState.projectName = 'Telemetry Mix Master Test';
      dawState.setMasterEq(subCut: 32.0, lowGain: -1.0, midFreq: 450.0, midGain: -2.5, highGain: 1.8);
      dawState.setMasterLimiter(enabled: true, ceilingDbfs: -0.3, driveDb: 4.0, targetLufs: -14.0);

      final track = dawState.activePattern.tracks.first;
      dawState.setTrackEq(
        track: track,
        enabled: true,
        hpf: 80.0,
        lowGain: -3.0,
        midFreq: 500.0,
        midGain: -1.5,
        midQ: 1.8,
        highGain: 2.0,
      );
      track.tags = ['kick', 'punchy'];

      final luaString = EatsLuaSerializer.serialize(dawState, projectName: dawState.projectName);
      expect(luaString.contains('masterEq = {'), isTrue);
      expect(luaString.contains('masterLimiter = {'), isTrue);
      expect(luaString.contains('subCut = 32.0'), isTrue);
      expect(luaString.contains('tags = { "kick", "punchy" }'), isTrue);
      expect(luaString.contains('hpf = 80.0'), isTrue);

      final restoredState = DawState();
      final title = EatsLuaParser.populateDawState(restoredState, luaString);

      expect(title, equals('Telemetry Mix Master Test'));
      expect(restoredState.masterSubCut, 32.0);
      expect(restoredState.masterLowGain, -1.0);
      expect(restoredState.masterMidFreq, 450.0);
      expect(restoredState.masterMidGain, -2.5);
      expect(restoredState.masterHighGain, 1.8);
      expect(restoredState.masterLimiterEnabled, isTrue);
      expect(restoredState.masterCeilingDbfs, -0.3);
      expect(restoredState.masterLimiterDrive, 4.0);
      expect(restoredState.masterTargetLufs, -14.0);

      final restoredTrack = restoredState.activePattern.tracks.first;
      expect(restoredTrack.eqEnabled, isTrue);
      expect(restoredTrack.eqHpf, 80.0);
      expect(restoredTrack.eqLowGain, -3.0);
      expect(restoredTrack.eqMidFreq, 500.0);
      expect(restoredTrack.eqMidGain, -1.5);
      expect(restoredTrack.eqMidQ, 1.8);
      expect(restoredTrack.eqHighGain, 2.0);
      expect(restoredTrack.tags, equals(['kick', 'punchy']));
    });
  });
}
