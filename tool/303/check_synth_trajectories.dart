import 'dart:io';
import 'dart:typed_data';
import 'wav_io.dart';

void main() {
  final files = [
    'saw_c2_cut100_res0_env100_dec100.wav',
    'saw_c2_cut50_res100_env100_dec100.wav',
    'saw_c2_cut50_res100_env50_dec100.wav',
    'saw_c2_cut50_res100_env50_dec50.wav',
    'saw_c2_cut50_res50_env50_dec50.wav',
  ];

  print('AUDIBLE SWEEP & PARAMETER TRAJECTORY COMPARISON (NEW SYNTH):');
  for (final name in files) {
    final path = 'tool/303/output/synth_$name';
    final f = File(path);
    if (!f.existsSync()) continue;

    final synthWav = WavIo.readSync(path);
    final mono = synthWav.toMono();

    double calcCentroid(Float32List mono, double startSec, double durSec, int sRate) {
      final start = (startSec * sRate).toInt();
      final len = (durSec * sRate).toInt();
      if (start + len > mono.length) return 0.0;
      int zc = 0;
      for (int i = start; i < start + len - 1; i++) {
        if (mono[i] * mono[i + 1] < 0) zc++;
      }
      return (zc * 0.5) / durSec;
    }

    final p1 = calcCentroid(mono, 0.02, 0.03, synthWav.sampleRate);
    final p2 = calcCentroid(mono, 0.07, 0.03, synthWav.sampleRate);
    final p3 = calcCentroid(mono, 0.15, 0.03, synthWav.sampleRate);

    print('${name.padRight(36)} | 20ms: ${p1.toStringAsFixed(0).padLeft(4)} Hz | 70ms: ${p2.toStringAsFixed(0).padLeft(4)} Hz | 150ms: ${p3.toStringAsFixed(0).padLeft(4)} Hz | Drop: ${(p1 - p3).toStringAsFixed(0).padLeft(4)} Hz');
  }
}
