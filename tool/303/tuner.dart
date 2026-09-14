import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:eatsbeats/eatscript/eats_tb303_core.dart';
import 'audio_metrics.dart';
import 'sample_metadata_parser.dart';
import 'wav_io.dart';

void main(List<String> args) async {
  print('======================================================');
  print('       EATSBEATS TB-303 GEMINI AUTONOMOUS TUNER       ');
  print('======================================================\n');

  // Parse CLI args
  String? apiKey = Platform.environment['GEMINI_API_KEY'];
  String model = 'gemini-2.5-flash';
  int maxIterations = 5;
  double targetSimilarity = 90.0;

  for (final arg in args) {
    if (arg.startsWith('--api-key=')) {
      apiKey = arg.substring('--api-key='.length).trim();
    } else if (arg.startsWith('--model=')) {
      model = arg.substring('--model='.length).trim();
    } else if (arg.startsWith('--max-iterations=')) {
      maxIterations = int.tryParse(arg.substring('--max-iterations='.length)) ?? 5;
    } else if (arg.startsWith('--target=')) {
      targetSimilarity = double.tryParse(arg.substring('--target='.length)) ?? 90.0;
    }
  }

  if (apiKey == null || apiKey.isEmpty) {
    print('[ERROR] Missing GEMINI_API_KEY.');
    print('Please set the environment variable or pass --api-key=YOUR_KEY');
    print('Example:');
    print('  \$env:GEMINI_API_KEY="AIzaSy..."');
    print('  dart run tool/303/tuner.dart --max-iterations=6\n');
    exit(1);
  }

  final samplesDir = Directory('tool/303/samples');
  final wavFiles = samplesDir.existsSync()
      ? samplesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.wav'))
          .toList()
      : <File>[];

  if (wavFiles.isEmpty) {
    print('[!] No reference samples found in "tool/303/samples/".');
    print('Please add reference TB-303 WAV files to calibrate against.');
    print('See tool/303/samples/README.md for details.\n');
    exit(1);
  }

  print('Loaded ${wavFiles.length} reference samples.');
  print('Model: $model | Max Iterations: $maxIterations | Target: $targetSimilarity%\n');

  final coreFile = File('lib/eatscript/eats_tb303_core.dart');
  if (!coreFile.existsSync()) {
    print('[ERROR] Cannot find lib/eatscript/eats_tb303_core.dart');
    exit(1);
  }

  String championCode = coreFile.readAsStringSync();
  double championScore = _evaluateCurrentCorpus(wavFiles).overallSimilarity;
  print('Baseline Score: ${championScore.toStringAsFixed(2)}% similarity\n');

  final client = HttpClient();

  for (int iter = 1; iter <= maxIterations; iter++) {
    print('\n>>> [Iteration $iter / $maxIterations] Querying Gemini for DSP refinements...');

    final benchmark = _evaluateCurrentCorpus(wavFiles);
    final prompt = _buildOptimizationPrompt(
      currentCode: championCode,
      benchmark: benchmark,
      iteration: iter,
    );

    String? responseText;
    try {
      responseText = await _callGeminiApi(client, apiKey, model, prompt);
    } catch (e) {
      print('[ERROR] Gemini API call failed: $e');
      break;
    }

    if (responseText == null) {
      print('[!] No response from Gemini, skipping iteration.');
      continue;
    }

    final candidateCode = _extractDartCode(responseText);
    if (candidateCode == null || candidateCode.length < 500) {
      print('[!] Failed to extract valid Dart code from response.');
      continue;
    }

    // Temporarily write candidate to disk
    coreFile.writeAsStringSync(candidateCode);

    // Verify syntax / compilation via analyzer or dry-run test
    final compileResult = Process.runSync(
      'dart',
      ['analyze', 'lib/eatscript/eats_tb303_core.dart'],
      runInShell: true,
    );

    if (compileResult.exitCode != 0) {
      print('[!] Candidate has syntax/analysis errors. Reverting to champion.');
      coreFile.writeAsStringSync(championCode);
      continue;
    }

    // Evaluate audio performance on candidate
    double candidateScore = 0.0;
    try {
      // Clear voice states to ensure clean test
      EatsTb303Core.clearAllVoices();
      final evalResult = _evaluateCurrentCorpus(wavFiles);
      candidateScore = evalResult.overallSimilarity;
    } catch (e) {
      print('[!] Candidate crashed during audio rendering: $e. Reverting.');
      coreFile.writeAsStringSync(championCode);
      continue;
    }

    print('Candidate Score: ${candidateScore.toStringAsFixed(2)}% (Champion: ${championScore.toStringAsFixed(2)}%)');

    if (candidateScore > championScore + 0.1) {
      final delta = candidateScore - championScore;
      print('>>> [CHAMPION PROMOTED] Score improved by +${delta.toStringAsFixed(2)}% (Now ${candidateScore.toStringAsFixed(2)}%)!');
      championScore = candidateScore;
      championCode = candidateCode;
      // Backup current best
      File('tool/303/output/eats_tb303_core_iter_$iter.dart').writeAsStringSync(candidateCode);
    } else {
      print('>>> [REVERTED] Candidate did not beat champion (${candidateScore.toStringAsFixed(2)}% <= ${championScore.toStringAsFixed(2)}%). Reverting.');
      coreFile.writeAsStringSync(championCode);
    }

    if (championScore >= targetSimilarity) {
      print('\nTarget similarity of $targetSimilarity% reached! Stopping early.');
      break;
    }
  }

  client.close();

  print('\n======================================================');
  print('TUNING FINISHED! Final Score: ${championScore.toStringAsFixed(2)}%');
  print('Final DSP saved to: lib/eatscript/eats_tb303_core.dart');
  print('======================================================\n');
}

class CorpusBenchmarkResult {
  final double overallSimilarity;
  final double avgSpectralLoss;
  final double avgEnvCorr;
  final List<String> sampleReports;

  CorpusBenchmarkResult({
    required this.overallSimilarity,
    required this.avgSpectralLoss,
    required this.avgEnvCorr,
    required this.sampleReports,
  });
}

CorpusBenchmarkResult _evaluateCurrentCorpus(List<File> wavFiles) {
  double totalSim = 0.0;
  double totalLoss = 0.0;
  double totalCorr = 0.0;
  final reports = <String>[];

  for (final file in wavFiles) {
    final wavAudio = WavIo.readSync(file.path);
    final refMono = wavAudio.toMono();
    final totalFileDur = refMono.length / wavAudio.sampleRate;
    final meta = SampleMetadata.parse(
      file,
      fallbackDuration: totalFileDur,
      audio: refMono,
      sampleRate: wavAudio.sampleRate,
    );

    final activeSamples = (meta.durationSec * wavAudio.sampleRate).toInt().clamp(64, refMono.length);
    final activeRef = Float32List.sublistView(refMono, 0, activeSamples);

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

    final score = AudioMetrics.compare(
      synthMono,
      activeRef,
      sampleRate: wavAudio.sampleRate,
    );

    totalSim += score.overallSimilarity;
    totalLoss += score.spectralDistance;
    totalCorr += score.envelopeCorrelation;

    reports.add(score.toMarkdownReport(title: meta.filename));
  }

  final count = wavFiles.isNotEmpty ? wavFiles.length : 1;
  return CorpusBenchmarkResult(
    overallSimilarity: totalSim / count,
    avgSpectralLoss: totalLoss / count,
    avgEnvCorr: totalCorr / count,
    sampleReports: reports,
  );
}

String _buildOptimizationPrompt({
  required String currentCode,
  required CorpusBenchmarkResult benchmark,
  required int iteration,
}) {
  final buffer = StringBuffer();
  buffer.writeln('''
You are an expert audio DSP engineer specializing in virtual analog modeling of the Roland TB-303 synthesizer.
Your goal is to modify the provided pure-Dart DSP engine (`EatsTb303Core`) to approximate real TB-303 recordings.

### TB-303 Analog Circuit Physics Context:
1. **Oscillator Stage**:
   - Sawtooth is created from an integrator circuit, with a highpass differentiator causing low-frequency phase tilt.
   - Square wave is derived by passing the saw through a differential pair, resulting in an asymmetrical pulse with downward exponential droop during each half-cycle.
2. **Diode Ladder Filter (4-Pole 24dB/oct)**:
   - 4-pole diode ladder with non-linear saturation at each stage.
   - **Critical**: There is a 150Hz 1-pole highpass filter in the resonance feedback loop, which prevents low bass from dominating resonance.
   - Filter resonance is damped at high cutoff frequencies.
3. **Envelope & Accent**:
   - Filter envelope has a ~3ms soft attack followed by exponential decay.
   - Accented notes charge an auxiliary capacitor, simultaneously shortening the decay to snappy ~200ms and delivering a rapid ~35ms transient squelch pulse.
4. **VCA & Saturation**:
   - Roland BA662 OTA / VCA saturates smoothly (asymmetrical tanh/soft-clip).

### Current Metric Benchmark (Iteration $iteration):
- **Overall Similarity**: ${benchmark.overallSimilarity.toStringAsFixed(2)}%
- **Average Multi-Scale Spectral Loss**: ${benchmark.avgSpectralLoss.toStringAsFixed(4)}
- **Average Envelope Correlation**: ${benchmark.avgEnvCorr.toStringAsFixed(4)}

### Detailed Sample Discrepancies:
${benchmark.sampleReports.take(6).join('\n')}

### Current `eats_tb303_core.dart` Source Code:
```dart
$currentCode
```

### Instructions:
- Output the complete, updated `lib/eatscript/eats_tb303_core.dart` file enclosed in ```dart ... ``` markdown tags.
- Keep the public API (`EatsTb303Core.synthesizeBuffer`, `synthesizeSample`, `clearVoice`, `clearAllVoices`) intact.
- Improve oscillator shapes, filter transfer functions, resonance feedback loop damping, or envelope curves to reduce spectral loss.
- Pure Dart only with zero external dependencies.
''');
  return buffer.toString();
}

Future<String?> _callGeminiApi(
  HttpClient client,
  String apiKey,
  String model,
  String prompt,
) async {
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
  );

  final request = await client.postUrl(uri);
  request.headers.set('Content-Type', 'application/json; charset=UTF-8');

  final payload = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': prompt}
        ]
      }
    ],
    'generationConfig': {
      'temperature': 0.2,
      'maxOutputTokens': 8192,
    }
  });

  request.write(payload);
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    throw HttpException('Gemini API returned status ${response.statusCode}: $responseBody');
  }

  final parsed = jsonDecode(responseBody) as Map<String, dynamic>;
  final candidates = parsed['candidates'] as List<dynamic>?;
  if (candidates == null || candidates.isEmpty) return null;

  final content = candidates[0]['content'] as Map<String, dynamic>?;
  final parts = content?['parts'] as List<dynamic>?;
  if (parts == null || parts.isEmpty) return null;

  return parts[0]['text'] as String?;
}

String? _extractDartCode(String markdown) {
  final match = RegExp(r'```dart([\s\S]*?)```', multiLine: true).firstMatch(markdown);
  if (match != null) {
    return match.group(1)?.trim();
  }
  return null;
}
