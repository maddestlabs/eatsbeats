import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';

void main() {
  group('Physical Modeling ADSR & Limit Cycle Continuous Sound Verification', () {
    final physicalInstruments = <String, Function()>{
      'Trumpet': () => GraphEvaluator.buildOrchestralTrumpet(),
      'Trombone': () => GraphEvaluator.buildTenorTrombone(),
      'Tuba': () => GraphEvaluator.buildTuba(),
      'MutedTrumpet': () => GraphEvaluator.buildMutedTrumpet(),
      'FrenchHorn': () => GraphEvaluator.buildFrenchHorn(),
      'BrassSection': () => GraphEvaluator.buildBrassSection(),
      'Clarinet': () => GraphEvaluator.buildClarinet(),
      'AltoSax': () => GraphEvaluator.buildAltoSax(),
      'TenorSax': () => GraphEvaluator.buildTenorSax(),
      'Oboe': () => GraphEvaluator.buildOboe(),
      'Bassoon': () => GraphEvaluator.buildBassoon(),
      'Sitar': () => GraphEvaluator.buildSitar(),
      'Flute': () => GraphEvaluator.buildConcertFlute(),
    };

    test('All physical models maintain continuous limit-cycle oscillations with 0% DC latchup', () {
      const double sr = 44100.0;
      const double duration = 0.5;

      for (final entry in physicalInstruments.entries) {
        final root = entry.value() as dynamic;
        final buffer = GraphEvaluator.evaluate(
          root: root,
          durationSec: duration,
          freq: 440.0,
          note: 69,
          params: {},
          velocity: 0.85,
        );

        int zx = 0;
        int satCount = 0;
        final start = (sr * 0.1).toInt();
        final end = (sr * 0.4).toInt();
        for (int i = start; i < end - 1; i++) {
          if ((buffer[i] >= 0 && buffer[i + 1] < 0) || (buffer[i] < 0 && buffer[i + 1] >= 0)) {
            zx++;
          }
          if (buffer[i].abs() >= 0.70) {
            satCount++;
          }
        }
        final satPct = satCount / (end - start) * 100;

        print('${entry.key.padRight(14)}: ZeroCrossings in 0.3s = ${zx.toString().padLeft(4)}, Saturation = ${satPct.toStringAsFixed(1)}%');

        expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue, reason: '${entry.key} contains NaN/Inf');
        expect(zx, greaterThan(30), reason: '${entry.key} failed to oscillate in sustain region');
        expect(satPct, lessThan(20.0), reason: '${entry.key} has excessive DC rail saturation');
      }
    });

    test('Proportional ADSR scaling ensures healthy audio on short tracker 16th-note steps (0.125s)', () {
      const double sr = 44100.0;
      const double shortDuration = 0.125; // 16th note at 120 BPM

      for (final entry in physicalInstruments.entries) {
        final root = entry.value() as dynamic;
        final buffer = GraphEvaluator.evaluate(
          root: root,
          durationSec: shortDuration,
          freq: 440.0,
          note: 69,
          params: {},
          velocity: 0.85,
        );

        double maxAbs = 0.0;
        double sumSq = 0.0;
        for (final sample in buffer) {
          maxAbs = math.max(maxAbs, sample.abs());
          sumSq += sample * sample;
        }
        final rms = math.sqrt(sumSq / buffer.length);

        expect(buffer.length, equals((sr * shortDuration).toInt()));
        expect(maxAbs, greaterThan(0.04), reason: '${entry.key} is silent on 0.125s step');
        expect(rms, greaterThan(0.01), reason: '${entry.key} RMS too low on 0.125s step');
      }
    });
  });
}
