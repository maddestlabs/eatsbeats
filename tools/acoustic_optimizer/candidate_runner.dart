// ─────────────────────────────────────────────────────────────────────────────
//  Eatsbeats Acoustic Physical Modeling: Standalone Candidate Runner
//  Synthesizes headless WAV files of Upright Bass for acoustic analysis.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eatsbeats/audio/graph/graph_evaluator.dart';

void main(List<String> args) async {
  final outDir = Directory('tools/acoustic_optimizer/output');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // Parse optional parameter overrides from CLI (e.g. --params '{"FingerFlesh": 0.8}')
  Map<String, double> paramOverrides = {};
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--params' && i + 1 < args.length) {
      try {
        final decoded = jsonDecode(args[i + 1]) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is num) paramOverrides[key] = val.toDouble();
        });
      } catch (e) {
        stderr.writeln('Error parsing --params: $e');
      }
    }
  }

  // Base parameters for 3/4 acoustic upright double bass
  final baseParams = <String, double>{
    'FingerFlesh': 0.70,
    'FingerMass': 2.2,
    'SlapClick': 0.35,
    'Sustain': 0.995,
    'StringDamp': 0.28,
    'Dispersion': 0.22,
    'ActionHeight': 3.2,
    'SubWarmth': 2.0,
    'BodyPunch': 3.0,
    'BodyWarmth': 0.75,
    'WoodTone': -3.5,
  };
  baseParams.addAll(paramOverrides);

  // Multi-octave chromatic targets matching FL Studio Flex studio recording
  final notesToRender = [
    {'name': 'C1', 'midi': 24, 'freq': 32.703},
    {'name': 'C2', 'midi': 36, 'freq': 65.406},
    {'name': 'C3', 'midi': 48, 'freq': 130.813},
    {'name': 'C4', 'midi': 60, 'freq': 261.626},
  ];

  final sampleRate = 44100;
  final durationSec = 2.5;

  print('Synthesizing Upright Bass candidate audio...');
  print('Parameters: ${jsonEncode(baseParams)}');

  for (final noteInfo in notesToRender) {
    final noteName = noteInfo['name'] as String;
    final midiNote = noteInfo['midi'] as int;
    final freq = noteInfo['freq'] as double;

    // Render at mezzo-forte (0.75) and fortissimo (1.0)
    for (final vel in [0.75, 1.0]) {
      final velLabel = vel >= 0.9 ? 'ff' : 'mf';
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildUprightBass(),
        durationSec: durationSec,
        freq: freq,
        note: midiNote,
        params: baseParams,
        velocity: vel,
      );

      final wavFile = File('${outDir.path}/${noteName}_$velLabel.wav');
      writeWav(wavFile, buffer, sampleRate);
      print('  -> Generated ${wavFile.path} (${buffer.length} samples)');
    }
  }

  print('Candidate synthesis complete. WAVs ready in ${outDir.path}');
}

/// Encodes 32-bit float audio buffer to 16-bit mono PCM WAV.
void writeWav(File file, Float32List buffer, int sampleRate) {
  final numSamples = buffer.length;
  final byteRate = sampleRate * 2; // 16-bit mono
  final blockAlign = 2;
  final subChunk2Size = numSamples * 2;
  final chunkSize = 36 + subChunk2Size;

  final bytes = BytesBuilder();

  // RIFF header
  bytes.add(ascii.encode('RIFF'));
  bytes.add(_int32(chunkSize));
  bytes.add(ascii.encode('WAVE'));

  // fmt subchunk
  bytes.add(ascii.encode('fmt '));
  bytes.add(_int32(16)); // Subchunk1Size for PCM
  bytes.add(_int16(1));  // AudioFormat: 1 = PCM
  bytes.add(_int16(1));  // NumChannels: 1 (mono)
  bytes.add(_int32(sampleRate));
  bytes.add(_int32(byteRate));
  bytes.add(_int16(blockAlign));
  bytes.add(_int16(16)); // BitsPerSample

  // data subchunk
  bytes.add(ascii.encode('data'));
  bytes.add(_int32(subChunk2Size));

  // Convert float (-1.0 to 1.0) to 16-bit PCM (-32768 to 32767)
  final pcmData = Uint8List(subChunk2Size);
  final byteData = ByteData.sublistView(pcmData);
  for (int i = 0; i < numSamples; i++) {
    final sample = buffer[i].clamp(-1.0, 1.0);
    final pcmInt = (sample * 32767.0).round().clamp(-32768, 32767);
    byteData.setInt16(i * 2, pcmInt, Endian.little);
  }
  bytes.add(pcmData);

  file.writeAsBytesSync(bytes.toBytes());
}

List<int> _int16(int val) {
  final b = ByteData(2)..setInt16(0, val, Endian.little);
  return b.buffer.asUint8List();
}

List<int> _int32(int val) {
  final b = ByteData(4)..setInt32(0, val, Endian.little);
  return b.buffer.asUint8List();
}
