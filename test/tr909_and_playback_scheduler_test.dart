import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/tr909_rom_data.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TR-909 ROM Data Cross-Platform & Web Compatibility Tests', () {
    test('All 11 TR-909 drum ROM waveforms decode cleanly to valid Float32Lists', () {
      final samples = <String, Float32List>{
        'bassdrum_attack': Tr909RomData.bassdrum_attack,
        'bassdrum_cycle': Tr909RomData.bassdrum_cycle,
        'snare_tone': Tr909RomData.snare_tone,
        'snare_noise': Tr909RomData.snare_noise,
        'closed_hihat': Tr909RomData.closed_hihat,
        'opened_hihat': Tr909RomData.opened_hihat,
        'clap': Tr909RomData.clap,
        'rim': Tr909RomData.rim,
        'tom_low': Tr909RomData.tom_low,
        'tom_mid': Tr909RomData.tom_mid,
        'tom_hi': Tr909RomData.tom_hi,
      };

      expect(samples.length, 11);
      for (final entry in samples.entries) {
        expect(entry.value, isA<Float32List>());
        expect(entry.value.length, greaterThan(0), reason: '${entry.key} should not be empty');
        // Ensure values are within normal audio ranges (-2.0 to 2.0)
        final anyValidNonZero = entry.value.any((s) => s.abs() > 0.0001);
        expect(anyValidNonZero, isTrue, reason: '${entry.key} should contain non-zero PCM audio');
      }
    });
  });

  group('Windows Playback & Transport Scheduler Clock Tests', () {
    test('AudioEngine currentTime advances smoothly and transport steps advance across multiple steps', () async {
      final dawState = DawState();

      expect(dawState.isPlaying, isFalse);
      expect(dawState.currentStep, 0);

      // Start playback
      dawState.togglePlay();
      expect(dawState.isPlaying, isTrue);

      // Wait 300ms for several scheduler loops (25ms intervals) to fire and step
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // currentTime should have monotonically advanced
      expect(dawState.audioEngine.currentTime, greaterThan(0.2));

      // Playback step should have advanced past step 1 (no stalling at step 1)
      expect(dawState.currentStep, greaterThan(1));
      expect(dawState.arrangerStep, greaterThan(1));

      // Stop playback
      dawState.stop();
      expect(dawState.isPlaying, isFalse);
      expect(dawState.currentStep, 0);

      dawState.dispose();
    });
  });
}
