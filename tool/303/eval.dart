import 'dart:io';
import 'dart:typed_data';
import 'package:eatsbeats/eatscript/eats_tb303_core.dart';
import 'audio_metrics.dart';
import 'sample_metadata_parser.dart';
import 'wav_io.dart';

void main(List<String> args) {
  print('======================================================');
  print('       EATSBEATS TB-303 AUDIO EVALUATOR & BENCHMARK   ');
  print('======================================================\n');

  final samplesDir = Directory('tool/303/samples');
  final outputDir = Directory('tool/303/output');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final isDemo = args.contains('--demo');

  // Discover reference WAV files
  final wavFiles = samplesDir.existsSync()
      ? samplesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.wav'))
          .toList()
      : <File>[];

  if (wavFiles.isEmpty || isDemo) {
    if (!isDemo) {
      print('[!] No reference TB-303 WAV samples found in "tool/303/samples/".');
      print('    -> Place your real 303 audio samples into tool/303/samples/');
      print('    -> Read tool/303/samples/README.md for file naming guidelines.\n');
      print('Running synthetic self-test & demo render...\n');
    } else {
      print('Running synthetic self-test demo...\n');
    }

    _runDemoEvaluation(outputDir);
    return;
  }

  print('Found ${wavFiles.length} reference samples for benchmark:\n');

  double totalSimilarity = 0.0;
  double totalLoss = 0.0;
  int evaluatedCount = 0;

  for (final file in wavFiles) {
    try {
      final wavAudio = WavIo.readSync(file.path);
      final refMono = wavAudio.toMono();
      final totalFileDur = refMono.length / wavAudio.sampleRate;

      final meta = SampleMetadata.parse(
        file,
        fallbackDuration: totalFileDur,
        audio: refMono,
        sampleRate: wavAudio.sampleRate,
      );

      // Truncate refMono to active duration so trailing dead silence does not skew metrics
      final activeSamples = (meta.durationSec * wavAudio.sampleRate).toInt().clamp(64, refMono.length);
      final activeRef = Float32List.sublistView(refMono, 0, activeSamples);

      // Synthesize matching note using current EatsTb303Core
      final synthMono = EatsTb303Core.synthesizeBuffer(
        durationSec: meta.durationSec,
        freq: meta.freq,
        note: meta.midiNote,
        params: meta.params,
        isAccent: meta.isAccent,
        isSlide: meta.isSlide,
        targetMidiNote: meta.targetMidiNote,
        sampleRate: wavAudio.sampleRate.toDouble(),
      );

      // Compare
      final score = AudioMetrics.compare(
        synthMono,
        activeRef,
        sampleRate: wavAudio.sampleRate,
      );

      totalSimilarity += score.overallSimilarity;
      totalLoss += score.spectralDistance;
      evaluatedCount++;

      // Export rendered output WAV for side-by-side listening
      final outPath = 'tool/303/output/synth_${meta.filename}';
      WavIo.writeSync(outPath, synthMono, sampleRate: wavAudio.sampleRate);

      print('------------------------------------------------------');
      print('Sample: ${meta.filename}');
      print('  Note: MIDI ${meta.midiNote} (${meta.freq.toStringAsFixed(1)} Hz) | Accent: ${meta.isAccent} | Slide: ${meta.isSlide}');
      print('  Similarity: ${score.overallSimilarity.toStringAsFixed(1)}% | Spectral Loss: ${score.spectralDistance.toStringAsFixed(4)} | Env Corr: ${score.envelopeCorrelation.toStringAsFixed(4)}');
      print('  Centroid Delta: ${score.centroidDelta >= 0 ? "+" : ""}${score.centroidDelta.toStringAsFixed(1)} Hz');
      print('  Rendered: $outPath');
    } catch (e, st) {
      print('[ERROR] Failed evaluating ${file.path}: $e\n$st');
    }
  }

  if (evaluatedCount > 0) {
    final avgSimilarity = totalSimilarity / evaluatedCount;
    final avgLoss = totalLoss / evaluatedCount;

    print('\n======================================================');
    print('BENCHMARK SUMMARY ($evaluatedCount Samples)');
    print('  Average Overall Similarity: ${avgSimilarity.toStringAsFixed(1)}%');
    print('  Average Spectral Loss:     ${avgLoss.toStringAsFixed(4)}');
    print('======================================================\n');
  }
}

void _runDemoEvaluation(Directory outputDir) {
  print('Synthesizing reference baseline demos into "tool/303/output/"...');

  final testCases = [
    {
      'name': 'demo_saw_c2_accent.wav',
      'wave': 0.0,
      'note': 36,
      'freq': 65.41,
      'accent': true,
      'params': {'Cutoff': 1600.0, 'Resonance': 9.0, 'EnvMod': 0.85, 'Decay': 0.28, 'Accent': 0.8, 'Drive': 0.25},
    },
    {
      'name': 'demo_saw_c2_normal.wav',
      'wave': 0.0,
      'note': 36,
      'freq': 65.41,
      'accent': false,
      'params': {'Cutoff': 1200.0, 'Resonance': 8.0, 'EnvMod': 0.70, 'Decay': 0.35, 'Accent': 0.0, 'Drive': 0.20},
    },
    {
      'name': 'demo_sqr_c2_squelch.wav',
      'wave': 1.0,
      'note': 36,
      'freq': 65.41,
      'accent': true,
      'params': {'Cutoff': 1800.0, 'Resonance': 12.0, 'EnvMod': 0.90, 'Decay': 0.22, 'Accent': 0.85, 'Drive': 0.30},
    },
  ];

  for (final tc in testCases) {
    final name = tc['name'] as String;
    final buffer = EatsTb303Core.synthesizeBuffer(
      durationSec: 0.5,
      freq: tc['freq'] as double,
      note: tc['note'] as int,
      params: (tc['params'] as Map<String, dynamic>).cast<String, double>(),
      isAccent: tc['accent'] as bool,
    );

    final outPath = '${outputDir.path}/$name';
    WavIo.writeSync(outPath, buffer);
    print(' -> Rendered $outPath (${buffer.length} samples)');

    // Verify round-trip read & metrics
    final reRead = WavIo.readSync(outPath).toMono();
    final selfScore = AudioMetrics.compare(buffer, reRead);
    print('    Metric self-test similarity: ${selfScore.overallSimilarity.toStringAsFixed(1)}% (Loss: ${selfScore.spectralDistance.toStringAsFixed(6)})');
  }

  print('\nSelf-test demo completed successfully!');
}
