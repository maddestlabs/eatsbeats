import 'dart:io';
import 'dart:math' as math;
import 'wav_io.dart';
import 'sample_metadata_parser.dart';

void main() {
  final files = Directory('tool/303/samples')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.wav'))
      .toList();

  for (final f in files) {
    final wav = WavIo.readSync(f.path);
    final mono = wav.toMono();
    final meta = SampleMetadata.parse(f, fallbackDuration: mono.length / wav.sampleRate, audio: mono, sampleRate: wav.sampleRate);
    
    // Compute RMS at 0ms, 100ms, 250ms, 500ms, 1000ms
    double rmsAt(double sec) {
      final start = (sec * wav.sampleRate).toInt();
      final len = (0.05 * wav.sampleRate).toInt();
      if (start + len > mono.length) return 0.0;
      double sum = 0.0;
      for (int i = start; i < start + len; i++) {
        sum += mono[i] * mono[i];
      }
      return math.sqrt(sum / len);
    }

    final totalSec = mono.length / wav.sampleRate;
    print('${f.uri.pathSegments.last.padRight(42)} | FileLen: ${totalSec.toStringAsFixed(2)}s | ActiveDur: ${meta.durationSec.toStringAsFixed(2)}s | RMS 50ms: ${rmsAt(0.05).toStringAsFixed(3)} | 100ms: ${rmsAt(0.10).toStringAsFixed(3)} | 150ms: ${rmsAt(0.15).toStringAsFixed(3)} | 200ms: ${rmsAt(0.20).toStringAsFixed(3)} | 250ms: ${rmsAt(0.25).toStringAsFixed(3)}');
  }
}
