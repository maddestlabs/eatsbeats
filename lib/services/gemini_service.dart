import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';

class ConnectionTestResult {
  final bool isSuccess;
  final int statusCode;
  final String message;
  final String? rawResponse;

  const ConnectionTestResult({
    required this.isSuccess,
    required this.statusCode,
    required this.message,
    this.rawResponse,
  });
}

/// Service for communicating with Google Gemini API
/// Supports both Bring-Your-Own-Key (BYOK) direct client mode and optional hosted proxy mode.
class GeminiService {
  static const String _defaultModel = 'gemini-3.6-flash';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static String? _apiKey;
  static String get apiKey => _apiKey ?? '';
  static set apiKey(String key) => _apiKey = key.trim();

  static bool get hasApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  static String _activeModel = _defaultModel;
  static String get activeModel => _activeModel;
  static set activeModel(String model) => _activeModel = model.trim();

  static List<String> _availableModels = [
    'gemini-3.6-flash',
    'gemini-3.0-flash',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-pro-latest',
    'gemini-2.0-flash-exp',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];
  static List<String> get availableModels => List.unmodifiable(_availableModels);

  /// Fetches the live list of supported generation models available for this API key from Google,
  /// filtered for text/multimodal synthesis compatibility and sorted newest to oldest.
  static Future<List<String>> fetchAvailableModels() async {
    final key = _apiKey?.trim() ?? '';
    if (key.isEmpty) return _availableModels;

    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': key,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawModels = data['models'] as List?;
        if (rawModels != null && rawModels.isNotEmpty) {
          final discovered = <String>[];
          for (final m in rawModels) {
            if (m is Map) {
              final methods = (m['supportedGenerationMethods'] as List?)?.map((e) => e.toString()).toList() ?? [];
              if (methods.contains('generateContent')) {
                var name = m['name']?.toString() ?? '';
                if (name.startsWith('models/')) {
                  name = name.substring(7);
                }
                if (name.isNotEmpty) {
                  discovered.add(name);
                }
              }
            }
          }
          final filtered = _filterAndSortModels(discovered);
          if (filtered.isNotEmpty) {
            _availableModels = filtered;

            // Auto-select the newest flash model if current active model is not in list
            if (!_availableModels.contains(_activeModel)) {
              final preferred = _availableModels.firstWhere(
                (m) => m.contains('flash'),
                orElse: () => _availableModels.first,
              );
              _activeModel = preferred;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[GeminiService] fetchAvailableModels error: $e');
    }
    return _availableModels;
  }

  /// Filters out non-generative models and sorts models from newest version to oldest.
  static List<String> _filterAndSortModels(Iterable<String> models) {
    final filtered = models.where((m) {
      final name = m.toLowerCase();
      if (!name.startsWith('gemini')) return false;
      if (name.contains('embedding') ||
          name.contains('aqa') ||
          name.contains('imagen') ||
          name.contains('learnlm') ||
          name.contains('robotics') ||
          name.contains('tts') ||
          name.contains('whisper')) {
        return false;
      }
      return true;
    }).toSet().toList();

    filtered.sort((a, b) {
      final vA = _extractVersion(a);
      final vB = _extractVersion(b);
      if (vA != vB) {
        return vB.compareTo(vA); // descending: newer versions first
      }
      // Prefer flash over pro for lower latency DAW operations
      final isFlashA = a.contains('flash') ? 1 : 0;
      final isFlashB = b.contains('flash') ? 1 : 0;
      if (isFlashA != isFlashB) {
        return isFlashB.compareTo(isFlashA);
      }
      // Prefer 'latest' over specific date stamps
      final isLatestA = a.contains('latest') ? 1 : 0;
      final isLatestB = b.contains('latest') ? 1 : 0;
      if (isLatestA != isLatestB) {
        return isLatestB.compareTo(isLatestA);
      }
      return a.compareTo(b);
    });

    return filtered;
  }

  static double _extractVersion(String modelName) {
    final match = RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(modelName);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '0') ?? 0.0;
    }
    return 0.0;
  }

  /// Tests connectivity and API key validity against Gemini, auto-discovering supported models.
  static Future<ConnectionTestResult> testConnection() async {
    final key = _apiKey?.trim() ?? '';
    if (key.isEmpty) {
      return const ConnectionTestResult(
        isSuccess: false,
        statusCode: 0,
        message: 'No API key provided. Paste your key from Google AI Studio.',
      );
    }

    // 1. Fetch live models supported for this key
    await fetchAvailableModels();

    // 2. Test generation with active model (and auto-fallback if 404)
    final candidateModels = [_activeModel, ..._availableModels].toSet().toList();

    for (final model in candidateModels) {
      try {
        final uri = Uri.parse('$_baseUrl/$model:generateContent?key=$key');
        final payload = {
          'contents': [
            {
              'parts': [
                {'text': 'Hello'}
              ]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 5,
          }
        };

        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          _activeModel = model;
          return ConnectionTestResult(
            isSuccess: true,
            statusCode: 200,
            message: 'Connected to $model! Key verified and ready to mix.',
          );
        } else if (response.statusCode == 404) {
          // Model name not found on this endpoint, try next candidate
          continue;
        } else {
          String msg = 'HTTP ${response.statusCode}';
          try {
            final bodyJson = jsonDecode(response.body);
            if (bodyJson is Map && bodyJson['error'] is Map) {
              final err = bodyJson['error'] as Map;
              final message = err['message'] as String? ?? '';
              final status = err['status'] as String? ?? '';
              msg = status.isNotEmpty ? '$status: $message' : message;
            }
          } catch (_) {
            msg = response.body;
          }

          if (response.statusCode == 400 && msg.contains('API_KEY_INVALID')) {
            msg = 'Invalid API key or key is brand new (Google takes ~30-60s to propagate new keys).';
          }

          return ConnectionTestResult(
            isSuccess: false,
            statusCode: response.statusCode,
            message: msg,
            rawResponse: response.body,
          );
        }
      } catch (e) {
        debugPrint('[GeminiService] testConnection error on $model: $e');
      }
    }

    return const ConnectionTestResult(
      isSuccess: false,
      statusCode: 404,
      message: 'Could not connect to any supported Gemini models with this key.',
    );
  }

  /// Mixes and masters a project by sending telemetry and receiving structured parameter adjustments.
  static Future<Map<String, dynamic>> executeMixAndMaster({
    required Map<String, dynamic> telemetry,
    String genre = 'auto',
    double targetLufs = -14.0,
    String customInstructions = '',
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are an elite, Grammy-winning Audio Mixing & Mastering Engineer working inside the Eatsbeats Digital Audio Workstation.
Your mission is to analyze the provided track energy telemetry and return a surgical, musically balanced mix & master parameter patch.

CRITICAL MIXING RULES:
1. LOW END ANCHORING:
   - Only ONE element (usually Kick or Sub Bass) should own 30-60 Hz.
   - High-pass (HPF) non-bass instruments (guitars: 100-120Hz, snares: 80Hz, keys: 80-100Hz, vocals: 120Hz, hats/cymbals: 200-350Hz).
2. FREQUENCY DE-MASKING:
   - If Kick and Bass clash, notch 250-350 Hz on the kick or carve 60-80 Hz on the bass.
   - Clear boxiness/mud in the 250-500 Hz region for guitars, keys, and pads.
   - Enhance clarity (2.5 - 5 kHz) on vocals and snare snap.
   - Add air (8 - 12 kHz high shelf) to acoustic instruments, vocals, and hi-hats.
3. STEREO PLACEMENT:
   - Kick, Snare, Main Vocal, and Sub Bass must remain solid center (pan: 0.0).
   - Hats, Percussion, Guitars, and Keys should be balanced across the stereo field (-0.4 to +0.4).
   - Pads and ambient elements should have wide stereo imaging.
4. MASTER BUS CONSOLE:
   - Master subCut: 25-35 Hz to eliminate DC offset and sub rumble.
   - Master Low Shelf: -1.0 to +1.5 dB for tight low-end control.
   - Master Mid Gain: -0.5 to -2.0 dB around 300-400 Hz if the mix is muddy.
   - Master High Shelf: +0.5 to +2.0 dB for modern commercial air and polish.
   - Master Limiter: Enabled = true, ceilingDbfs = -0.3 dBFS, driveDb calculated to achieve target LUFS ($targetLufs LUFS).

RESPONSE FORMAT:
You MUST respond with pure JSON adhering exactly to this structure without markdown formatting or code blocks:
{
  "summary": "Concise mixing notes explaining key decisions",
  "master": {
    "subCut": 28.0,
    "lowGain": 0.5,
    "midFreq": 320.0,
    "midGain": -1.2,
    "highGain": 1.5,
    "limiterEnabled": true,
    "ceilingDbfs": -0.3,
    "limiterDrive": 3.5,
    "targetLufs": $targetLufs
  },
  "tracks": {
    "<track_id>": {
      "volume": 0.85,
      "pan": 0.0,
      "eq": {
        "enabled": true,
        "hpf": 80.0,
        "lowGain": -1.5,
        "midFreq": 320.0,
        "midGain": -2.0,
        "midQ": 1.5,
        "highGain": 1.0
      },
      "comment": "Cut mud at 320Hz, added 1dB air shelf"
    }
  }
}
''';

    final promptText = '''
TARGET GENRE / VIBE: $genre
TARGET INTEGRATED LOUDNESS: $targetLufs LUFS
ADDITIONAL PRODUCER INSTRUCTIONS: ${customInstructions.isNotEmpty ? customInstructions : 'None'}

PROJECT TELEMETRY:
${jsonEncode(telemetry)}
''';

    final rawJson = await _callGemini(systemInstruction: systemInstruction, userPrompt: promptText, responseMimeType: 'application/json');
    return jsonDecode(_cleanJsonResponse(rawJson)) as Map<String, dynamic>;
  }

  /// Generates a standalone, synthesizable Lua instrument DSP script based on a natural language sound description.
  static Future<String> generateInstrumentScript({
    required String prompt,
    String category = 'instrument',
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are a master DSP audio engineer and Lua synthesizer developer for the Eatsbeats Digital Audio Workstation.
Your task is to write a complete, elegant, and self-contained Lua instrument script that generates rich, synthesizable sound.

EATSBEATS LUA SCRIPTING RULES:
1. Metadata header comments:
   -- @name: <Title of the Instrument>
   -- @author: Gemini AI & Eatsbeats
   -- @category: instrument
   -- @description: <Concise sound design description>
   -- @tags: <comma-separated list of semantic tags, e.g. bass, synth, punchy, analog>

2. Define parameters via Param table or module:
   -- Parameters can be declared using:
   -- Param.add("Name", min, max, default, step)
   -- Param.choice("Name", {"Option1", "Option2"}, defaultIndex)

3. Sound synthesis function:
   -- Implement note generation returning audio buffers or sample evaluations.
   -- Audio functions must compute clean waveforms (sine, saw, square, triangle, FM, pulse-width, or noise), envelopes (ADSR), and resonant filters without clipping.
   -- Use math.sin, math.exp, math.max, math.min, math.tanh for soft clipping/saturation.

4. Output ONLY valid Lua code without markdown wrappers if possible, or wrapped in a single ```lua block.
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: 'Create an instrument matching: $prompt');
    return _extractCode(rawOutput);
  }

  /// Generates a standalone Lua Audio FX DSP plugin script.
  static Future<String> generateAudioFxScript({
    required String prompt,
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are a boutique audio DSP plugin engineer for Eatsbeats DAW.
Write a complete, real-time Audio FX Lua script (Tape Saturation, Analog Chorus, Granular Delay, Reverb, Overdrive, Stereo Phaser, etc.).

EATSBEATS FX SCRIPTING SPECIFICATION:
1. Header:
   -- @name: <Effect Name>
   -- @author: Gemini AI
   -- @category: audio_fx
   -- @description: <Effect Description>
   -- @tags: audio_fx, <tags>

2. Parameter declarations:
   -- Param.add("Drive", 0.0, 10.0, 2.0, 0.1)
   -- Param.add("Tone", 200.0, 8000.0, 3000.0, 10.0)
   -- Param.add("Mix", 0.0, 1.0, 0.5, 0.01)

3. Implement processSignal(inputSample, sampleRate) or evaluateEffect(buffer, params):
   -- Ensure soft-clipping protection via math.tanh or polynomial waveshaping.

Output pure Lua code only.
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: 'Create an audio FX matching: $prompt');
    return _extractCode(rawOutput);
  }

  /// Low-level Gemini REST API caller with automatic model fallback.
  static Future<String> _callGemini({
    required String systemInstruction,
    required String userPrompt,
    String? responseMimeType,
  }) async {
    final key = _apiKey?.trim() ?? '';
    final candidateModels = [_activeModel, ..._availableModels].toSet().toList();

    http.Response? lastResponse;

    for (final model in candidateModels) {
      final uri = Uri.parse('$_baseUrl/$model:generateContent?key=$key');
      final payload = {
        'system_instruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
        'contents': [
          {
            'parts': [
              {'text': userPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          if (responseMimeType != null) 'responseMimeType': responseMimeType,
        }
      };

      try {
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: jsonEncode(payload),
        );

        lastResponse = response;

        if (response.statusCode == 200) {
          _activeModel = model;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            throw Exception('No response candidates received from Gemini API.');
          }

          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts == null || parts.isEmpty) {
            throw Exception('Empty content returned from Gemini.');
          }

          return parts[0]['text'] as String? ?? '';
        } else if (response.statusCode == 404) {
          // Model not found on this endpoint, try next candidate
          continue;
        } else {
          throw Exception('Gemini API request failed (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('Gemini API request failed')) {
          rethrow;
        }
        debugPrint('[GeminiService] _callGemini attempt failed on $model: $e');
      }
    }

    throw Exception('Gemini API request failed (${lastResponse?.statusCode ?? 404}): ${lastResponse?.body ?? "No supported models available."}');
  }

  static String _cleanJsonResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  static String _extractCode(String raw) {
    var cleaned = raw.trim();
    if (cleaned.contains('```lua')) {
      final startIndex = cleaned.indexOf('```lua') + 6;
      final endIndex = cleaned.lastIndexOf('```');
      if (endIndex > startIndex) {
        return cleaned.substring(startIndex, endIndex).trim();
      }
    } else if (cleaned.contains('```')) {
      final startIndex = cleaned.indexOf('```') + 3;
      final endIndex = cleaned.lastIndexOf('```');
      if (endIndex > startIndex) {
        return cleaned.substring(startIndex, endIndex).trim();
      }
    }
    return cleaned;
  }
}
