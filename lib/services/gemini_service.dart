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
Your task is to write a complete, elegant, and self-contained Lua instrument script that generates rich, synthesizable sound with a stunning hardware GUI.

EATSBEATS LUA SCRIPTING RULES:
1. Metadata header comments:
   -- @name: <Title of the Instrument>
   -- @author: Gemini AI & Eatsbeats
   -- @category: instrument
   -- @description: <Concise sound design description>
   -- @tags: <comma-separated list of semantic tags, e.g. bass, synth, punchy, analog, lead>

2. Define parameters via Param table or module:
   -- Parameters can be declared using:
   -- Param.add("Cutoff", 20.0, 20000.0, 1500.0, 1.0)
   -- Param.add("Resonance", 0.0, 1.0, 0.3, 0.01)
   -- Param.choice("Waveform", {"Saw", "Square", "Pulse"}, 0)

3. SKEUOMORPHIC HARDWARE GUI SPECIFICATION:
   Every instrument MUST define a hardware interface via a `gui = { ... }` table.
   Layout structure:
   gui = {
     style = "skeuomorphic",
     knobStyle = "vintage", -- "moog", "standard", "brushed", "vintage"
     background = "dark_metal", -- "brushed_aluminum", "dark_metal", "matte_black", "wood", "carbon_fiber"
     children = {
       {
         type = "row",
         children = {
           { type = "knob", param = "Cutoff", label = "CUTOFF", style = "moog", size = 48, accent = "#00FFFF" },
           { type = "knob", param = "Resonance", label = "RES", style = "moog", size = 48, accent = "#FF00FF" },
           { type = "knob", param = "Attack", label = "ATTACK", size = 40 },
           { type = "knob", param = "Decay", label = "DECAY", size = 40 },
           { type = "knob", param = "Sustain", label = "SUSTAIN", size = 40 },
           { type = "knob", param = "Release", label = "RELEASE", size = 40 }
         }
       },
       {
         type = "row",
         children = {
           { type = "choice", param = "Waveform", label = "OSC WAVE", options = {"Saw", "Square", "Pulse"} },
           { type = "toggle", param = "SubOsc", label = "SUB OSC", left = "OFF", right = "ON" },
           { type = "slider", param = "Volume", label = "LEVEL", orientation = "horizontal", width = 140 }
         }
       }
     }
   }

4. Sound synthesis function:
   -- Implement note generation returning audio buffers or sample evaluations.
   -- Audio functions must compute clean waveforms (sine, saw, square, triangle, FM, pulse-width, or noise), envelopes (ADSR), and resonant filters without clipping.
   -- Use math.sin, math.exp, math.max, math.min, math.tanh for soft clipping/saturation.

Output ONLY valid Lua code without markdown wrappers if possible, or wrapped in a single ```lua block.
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: 'Create a synthesized instrument matching: $prompt');
    return _extractCode(rawOutput);
  }

  /// Generates a standalone Lua Audio FX DSP plugin script with custom hardware GUI.
  static Future<String> generateAudioFxScript({
    required String prompt,
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are a boutique audio DSP plugin engineer for Eatsbeats DAW.
Write a complete, real-time Audio FX Lua script (Tape Saturation, Analog Chorus, Granular Delay, Reverb, Overdrive, Stereo Phaser, etc.) complete with a custom hardware GUI.

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

3. SKEUOMORPHIC HARDWARE GUI SPECIFICATION:
   gui = {
     style = "skeuomorphic",
     knobStyle = "vintage",
     background = "brushed_aluminum",
     children = {
       {
         type = "row",
         children = {
           { type = "knob", param = "Drive", label = "DRIVE", style = "vintage", size = 48, accent = "#FF6600" },
           { type = "knob", param = "Tone", label = "TONE", size = 44 },
           { type = "knob", param = "Mix", label = "MIX", size = 44, accent = "#00FFCC" }
         }
       }
     }
   }

4. Implement processSignal(inputSample, sampleRate) or evaluateEffect(buffer, params):
   -- Ensure soft-clipping protection via math.tanh or polynomial waveshaping.

Output pure Lua code only.
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: 'Create an audio FX matching: $prompt');
    return _extractCode(rawOutput);
  }

  /// Generates a complete, multi-track .eats.lua arrangement song project with custom synthesizers and MIDI notes.
  static Future<String> generateSongProject({
    required String prompt,
    String genre = 'Synthwave',
    double bpm = 120.0,
    String songKey = 'C Minor',
    int barLength = 8,
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are a Grammy-winning music producer, arranger, and DSP sound engineer for Eatsbeats DAW.
Your mission is to generate a complete, synthesizable, production-ready 4-track song project in Eatsbeats Lua format (`.eats.lua`).

SONG SPECIFICATION:
- Title: Generated from prompt
- BPM: $bpm
- Key: $songKey
- Scale Length: $barLength Bars (16 steps per bar)

ARRANGEMENT REQUIREMENTS:
Create exactly 4 complementary, well-orchestrated tracks:
1. Track 1: DRUMS (Kick on 1 & 3 or 4-on-the-floor, Snare on 2 & 4, Hi-Hats with grooves).
2. Track 2: BASS (Punchy analog or 808 sub bass locked to the kick and chord root notes).
3. Track 3: CHORDS / HARMONY (Lush polysynth, electric piano, or rhythm pads playing chord progressions).
4. Track 4: MELODY / LEAD (Catchy hook or vocal-style lead synth with slides and expressive velocities).

PRESET & SYNTHESIZER INSTRUCTIONS:
Each track can specify a proven factory preset (`presetId = "..."`) OR write a standalone `luaScriptCode`.
Available Factory Preset IDs you can use:
- Drums: "analog_909_kick", "analog_909_snare", "analog_909_closed_hihat", "analog_909_open_hihat", "analog_909_clap", "analog_909_rimshot", "eats_808_kick"
- Bass: "acid_303", "eats_303", "analog_bass", "sub_bass_synth", "fm_bass"
- Chords: "rhodes_epiano", "poly_lead", "analog_pad", "vintage_keys", "reggae_guitar", "spanish_guitar"
- Lead: "poly_lead", "acid_303", "ym2612_synth", "vintage_mono_lead"

EATSBEATS SONG FORMAT TEMPLATE:
```lua
return eatsbeats.song {
  version = "1.0",
  meta = {
    title = "<Song Title>",
    author = "Gemini AI",
    songKey = "$songKey",
    bpm = $bpm,
    masterVolume = 0.85,
    isLooping = true,
    loopStartBar = 0,
    loopEndBar = $barLength,
    masterEq = { subCut = 28.0, lowGain = 0.5, midFreq = 320.0, midGain = -1.0, highGain = 1.2 },
    masterLimiter = { enabled = true, ceilingDbfs = -0.3, driveDb = 3.0, targetLufs = -14.0 }
  },

  patterns = {
    {
      id = "p0",
      name = "Main Groove",
      lengthSteps = 16,
      tracks = {
        -- TRACK 1: DRUMS
        {
          id = "track_drums",
          name = "Drums",
          color = 0xFFFF5500,
          type = "luaScript",
          presetId = "analog_909_kick",
          volume = 0.90,
          pan = 0.0,
          clips = {
            {
              id = "clip_drums_0",
              name = "Drums",
              trackId = "track_drums",
              startBar = 0,
              barLength = $barLength,
              notes = {
                { id = "n1", pitch = 36, startStep = 0.0, durationSteps = 1.0, velocity = 0.95 },
                { id = "n2", pitch = 38, startStep = 4.0, durationSteps = 1.0, velocity = 0.85 },
                -- additional drum notes across the $barLength bars...
              }
            }
          }
        },
        -- TRACK 2: BASS
        {
          id = "track_bass",
          name = "Bass",
          color = 0xFF00E5FF,
          type = "luaScript",
          presetId = "acid_303",
          volume = 0.85,
          pan = 0.0,
          clips = {
            {
              id = "clip_bass_0",
              name = "Bassline",
              trackId = "track_bass",
              startBar = 0,
              barLength = $barLength,
              notes = {
                { id = "nb1", pitch = 36, startStep = 0.0, durationSteps = 3.0, velocity = 0.90 },
                -- additional bass notes in key of $songKey...
              }
            }
          }
        },
        -- TRACK 3: CHORDS
        {
          id = "track_chords",
          name = "Chords",
          color = 0xFF9D00FF,
          type = "luaScript",
          presetId = "rhodes_epiano",
          volume = 0.75,
          pan = -0.20,
          clips = {
            {
              id = "clip_chords_0",
              name = "Chords",
              trackId = "track_chords",
              startBar = 0,
              barLength = $barLength,
              notes = {
                { id = "nc1", pitch = 60, startStep = 0.0, durationSteps = 8.0, velocity = 0.80 },
                { id = "nc2", pitch = 63, startStep = 0.0, durationSteps = 8.0, velocity = 0.75 },
                { id = "nc3", pitch = 67, startStep = 0.0, durationSteps = 8.0, velocity = 0.75 },
                -- chord progression notes...
              }
            }
          }
        },
        -- TRACK 4: LEAD
        {
          id = "track_lead",
          name = "Lead",
          color = 0xFFFF0066,
          type = "luaScript",
          presetId = "poly_lead",
          volume = 0.80,
          pan = 0.15,
          clips = {
            {
              id = "clip_lead_0",
              name = "Lead Melody",
              trackId = "track_lead",
              startBar = 0,
              barLength = $barLength,
              notes = {
                { id = "nl1", pitch = 72, startStep = 0.0, durationSteps = 2.0, velocity = 0.85 },
                -- melody notes...
              }
            }
          }
        }
      }
    }
  }
}
```

CRITICAL RULES:
1. Every track MUST have a `type = "luaScript"` and either a `presetId = "..."` or a full `luaScriptCode = [[ ... ]]`.
2. Note pitches must be standard MIDI numbers (C3 = 48, C4 = 60, etc.) harmonized in the key of $songKey.
3. Output valid executable Lua only.
''';

    final promptText = '''
PRODUCER INSTRUCTION:
Create a complete $barLength-bar $genre song arrangement in $songKey at $bpm BPM based on:
"$prompt"
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: promptText);
    return _extractCode(rawOutput);
  }

  /// Low-level Gemini REST API caller with automatic model fallback and timeout protection.
  static Future<String> _callGemini({
    required String systemInstruction,
    required String userPrompt,
    String? responseMimeType,
    Duration timeout = const Duration(seconds: 75),
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
        ).timeout(timeout);

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

    throw Exception('Gemini API request failed (${lastResponse?.statusCode ?? 404}): ${lastResponse?.body ?? "No supported models available or request timed out."}');
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
