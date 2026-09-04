import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Load eats_volts.eats.lua and play sounds', () async {
    final dawState = DawState(enableMeterTimer: true);
    final file = File('demos/eats_volts.eats.lua');
    final code = file.readAsStringSync();

    print('Loading demo eats_volts.eats.lua (${code.length} bytes)...');
    final sw = Stopwatch()..start();
    dawState.loadFromEatsLua(code);
    sw.stop();
    print('Demo loaded in ${sw.elapsedMilliseconds}ms');

    print('Patterns count: ${dawState.patterns.length}');
    for (int p = 0; p < dawState.patterns.length; p++) {
      final pat = dawState.patterns[p];
      print('Pattern $p: ${pat.name} (tracks: ${pat.tracks.length})');
      for (final t in pat.tracks) {
        print('  Track: ${t.id} (${t.name}, type: ${t.type}, notes: ${t.notes.length}, clips: ${t.clips.length}, fx: ${t.fxRack.length})');
        for (final fx in t.fxRack) {
          print('    FX: ${fx.id} (${fx.name}, type: ${fx.type}, ir: ${fx.irSampleName})');
        }
      }
    }
    print('Master FX count: ${dawState.masterTrack.fxRack.length}');
    for (final fx in dawState.masterTrack.fxRack) {
      print('  Master FX: ${fx.id} (${fx.name}, type: ${fx.type}, ir: ${fx.irSampleName})');
    }

    // Now trigger sound on the Eats Volts track
    final voltsTrack = dawState.patterns[0].tracks.firstWhere((t) => t.name.contains('Volts'));
    print('Testing sound generation on Eats Volts track: ${voltsTrack.id}...');

    print('1. Synthesizing buffer for note 36...');
    final swSynth = Stopwatch()..start();
    final buf = dawState.audioEngine.synthesizeBufferForTrack(
      track: voltsTrack,
      midiNote: 36,
      velocity: 0.85,
      durationSec: 1.935,
    );
    swSynth.stop();
    print('Synthesized ${buf.length} samples in ${swSynth.elapsedMilliseconds}ms');

    print('2. Triggering togglePlay()...');
    dawState.togglePlay();
    expect(dawState.isPlaying, isTrue);

    // Let scheduler run a few ticks
    await Future.delayed(const Duration(milliseconds: 200));

    print('3. Stopping playback...');
    dawState.stop();
    expect(dawState.isPlaying, isFalse);

    print('Test finished successfully!');
  });
}
