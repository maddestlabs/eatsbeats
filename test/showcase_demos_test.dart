import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';
import 'package:eatsbeats/lua/lua_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Showcase Song Demos Tests', () {
    test('Yamaha DX7 Tokyo Nights demo parses and synthesizes properly', () {
      final file = File('demos/yamaha_dx7_showcase.eats.lua');
      expect(file.existsSync(), isTrue);

      final code = file.readAsStringSync();
      final dawState = DawState();
      final title = EatsLuaParser.populateDawState(dawState, code);

      expect(title, equals('Yamaha DX7 — Tokyo Nights'));
      expect(dawState.patterns.isNotEmpty, isTrue);
      final pattern = dawState.patterns.first;
      expect(pattern.tracks.length, equals(3));

      // Test synthesis on each track
      for (final track in pattern.tracks) {
        expect(track.notes.isNotEmpty, isTrue);
        final buffer = LuaEngine.synthesizeBuffer(
          code: track.luaScriptCode,
          durationSec: 0.2,
          freq: 440.0,
          note: 69,
          params: track.luaParams,
        );
        expect(buffer.isNotEmpty, isTrue);
        double maxAmp = 0.0;
        for (final s in buffer) {
          if (s.abs() > maxAmp) maxAmp = s.abs();
        }
        expect(maxAmp, greaterThan(0.01), reason: '${track.name} should produce audio');
      }
    });

    test('Commodore 64 Cyber Assault demo parses and synthesizes properly', () {
      final file = File('demos/c64_sid_showcase.eats.lua');
      expect(file.existsSync(), isTrue);

      final code = file.readAsStringSync();
      final dawState = DawState();
      final title = EatsLuaParser.populateDawState(dawState, code);

      expect(title, equals('C64 — Cyber Assault'));
      expect(dawState.patterns.isNotEmpty, isTrue);
      final pattern = dawState.patterns.first;
      expect(pattern.tracks.length, equals(4));

      // Test synthesis on each track
      for (final track in pattern.tracks) {
        expect(track.notes.isNotEmpty, isTrue);
        final buffer = LuaEngine.synthesizeBuffer(
          code: track.luaScriptCode,
          durationSec: 0.2,
          freq: 440.0,
          note: 69,
          params: track.luaParams,
        );
        expect(buffer.isNotEmpty, isTrue);
        double maxAmp = 0.0;
        for (final s in buffer) {
          if (s.abs() > maxAmp) maxAmp = s.abs();
        }
        expect(maxAmp, greaterThan(0.01), reason: '${track.name} should produce audio');
      }
    });
  });
}
