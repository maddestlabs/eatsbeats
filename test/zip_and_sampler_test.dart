import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/sampler_engine.dart';
import 'package:mobile_wren_daw/audio/wav_exporter.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SamplerEngine & .eats.zip Tests', () {
    test('SamplerEngine encodes and decodes WAV buffers correctly', () {
      final left = [0.0, 0.5, 1.0, 0.5, 0.0, -0.5, -1.0, -0.5];
      final right = [0.0, 0.5, 1.0, 0.5, 0.0, -0.5, -1.0, -0.5];

      final wavBytes = WavExporter.encodeWav(
        leftSamples: left,
        rightSamples: right,
        sampleRate: 44100,
      );

      expect(wavBytes.isNotEmpty, isTrue);

      final success = SamplerEngine.instance.registerSampleBytes('test_sample', wavBytes);
      expect(success, isTrue);

      final buffer = SamplerEngine.instance.getSample('test_sample');
      expect(buffer, isNotNull);
      expect(buffer!.samples.length, equals(8));
      expect(buffer.sampleRate, equals(44100));
    });

    test('DawState exports and imports .eats.zip archives', () {
      final dawState = DawState();
      dawState.projectName = 'iOS Test Project';

      // Export to .eats.zip
      final zipBytes = dawState.exportToEatsZip();
      expect(zipBytes.isNotEmpty, isTrue);

      final importedState = DawState();
      importedState.loadFromEatsZipOrLua(zipBytes: zipBytes);
      expect(importedState.projectName, equals('iOS Test Project'));
    });


    test('WaveformOverview generates 128 decimation peak points', () {
      final samples = List<double>.generate(1000, (i) => (i % 2 == 0) ? 0.8 : -0.8);
      final overview = WaveformOverview.generate(samples, 128);

      expect(overview.maxPeaks.length, equals(128));
      expect(overview.minPeaks.length, equals(128));
      expect(overview.maxPeaks.first, equals(0.8));
      expect(overview.minPeaks.first, equals(-0.8));
    });

    test('addSampleTrackFromFile registers sample and creates Sampler track clip', () {
      final dawState = DawState();
      final wavBytes = WavExporter.encodeWav(
        leftSamples: [0.1, 0.5, 0.9, 0.2],
        rightSamples: [0.1, 0.5, 0.9, 0.2],
      );

      final initialTrackCount = dawState.activePattern.tracks.length;
      dawState.addSampleTrackFromFile(fileName: 'vocal_lead.wav', fileBytes: wavBytes);

      expect(dawState.activePattern.tracks.length, equals(initialTrackCount + 1));
      final newTrack = dawState.activePattern.tracks.last;
      expect(newTrack.sampleName, equals('vocal_lead.wav'));
      expect(newTrack.clips.length, equals(1));
    });

    test('getPitchShiftedPcm returns an isolated copy that does not mutate cached samples', () {
      final originalBuffer = SamplerEngine.instance.getSample('test_sample');
      expect(originalBuffer, isNotNull);
      final firstVal = originalBuffer!.samples.first;

      final fetchedPcm = SamplerEngine.instance.getPitchShiftedPcm('test_sample', 0.0);
      fetchedPcm[0] = 999.0; // Mutate returned list

      // Original cached buffer in SamplerEngine should remain unchanged!
      expect(originalBuffer.samples.first, equals(firstVal));
      expect(originalBuffer.samples.first, isNot(equals(999.0)));
    });
  });
}



