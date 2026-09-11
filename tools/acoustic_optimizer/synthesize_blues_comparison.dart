// ─────────────────────────────────────────────────────────────────────────────
//  Eatsbeats Acoustic Physical Modeling: Blues Loop Synthesis Benchmark
//  Synthesizes the first 4 bars of 12-bar-bluesloop-double-bass to compare
//  with the real-world studio recording.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'candidate_runner.dart';

void main() {
  const sampleRate = 44100;
  const bpm = 130.4;
  const beatSec = 60.0 / bpm; // ~0.460 seconds per beat
  const totalBeats = 16; // 4 bars
  final totalDurationSec = beatSec * totalBeats + 0.8;
  final totalSamples = (totalDurationSec * sampleRate).toInt();

  final masterBuffer = Float32List(totalSamples);

  // Notes from real 12-bar-bluesloop-double-bass.wav (Bars 1 to 4)
  final walkingNotes = [
    // Bar 1
    {'midi': 41, 'gate': 0.82, 'vel': 0.85}, // F1
    {'midi': 44, 'gate': 0.80, 'vel': 0.78}, // G#1
    {'midi': 46, 'gate': 0.85, 'vel': 0.82}, // A#1
    {'midi': 48, 'gate': 0.84, 'vel': 0.88}, // C2
    // Bar 2
    {'midi': 50, 'gate': 0.82, 'vel': 0.84}, // D2
    {'midi': 46, 'gate': 0.80, 'vel': 0.80}, // A#1
    {'midi': 38, 'gate': 0.85, 'vel': 0.90}, // D1
    {'midi': 48, 'gate': 0.82, 'vel': 0.86}, // C2
    // Bar 3
    {'midi': 49, 'gate': 0.82, 'vel': 0.88}, // C#2
    {'midi': 45, 'gate': 0.84, 'vel': 0.82}, // A1
    {'midi': 41, 'gate': 0.85, 'vel': 0.86}, // F1
    {'midi': 49, 'gate': 0.80, 'vel': 0.84}, // C#2
    // Bar 4
    {'midi': 48, 'gate': 0.82, 'vel': 0.90}, // C2
    {'midi': 38, 'gate': 0.80, 'vel': 0.88}, // D1
    {'midi': 37, 'gate': 0.78, 'vel': 0.85}, // C#1
    {'midi': 39, 'gate': 0.85, 'vel': 0.86}, // D#1
  ];

  final params = <String, double>{
    'FingerFlesh': 0.72,
    'FingerMass': 2.3,
    'SlapClick': 0.38,
    'Sustain': 0.992,
    'StringDamp': 0.22,
    'Dispersion': 0.24,
    'ActionHeight': 3.2,
    'SubWarmth': 2.5,
    'BodyPunch': 3.5,
    'BodyWarmth': 0.80,
    'WoodTone': -2.0,
  };

  print('Synthesizing 4 bars of walking blues matching real recording (130.4 BPM)...');

  for (int i = 0; i < walkingNotes.length; i++) {
    final note = walkingNotes[i];
    final midi = note['midi'] as int;
    final gate = note['gate'] as double;
    final vel = note['vel'] as double;
    final freq = 440.0 * math.pow(2.0, (midi - 69.0) / 12.0);

    final noteDur = beatSec * gate;
    final noteBuf = GraphEvaluator.evaluate(
      root: GraphEvaluator.buildUprightBass(),
      durationSec: noteDur + 0.25, // allow natural ring
      freq: freq,
      note: midi,
      params: params,
      velocity: vel,
    );

    final startSample = (i * beatSec * sampleRate).toInt();
    for (int s = 0; s < noteBuf.length; s++) {
      final outIdx = startSample + s;
      if (outIdx < totalSamples) {
        masterBuffer[outIdx] += noteBuf[s];
      }
    }
  }

  final outDir = Directory('tools/acoustic_optimizer/output');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final outFile = File('${outDir.path}/synthesized_walking_blues_4bars.wav');
  writeWav(outFile, masterBuffer, sampleRate);
  print('Saved synthesized benchmark to: ${outFile.path}');
}
