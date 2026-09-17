import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../audio/procgen/ensemble_blueprint.dart';
import '../audio/procgen/song_archetype_registry.dart';
import '../models/chord_model.dart';
import 'secure_storage_service.dart';

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

/// Represents Gemini AI's stylistic assessment of an existing song/loop along with alternative arrangement takes.
class SongStyleAssessment {
  final String detectedGenre;
  final String stylisticVibe;
  final String harmonicObservations;
  final List<String> arrangementOpportunities;
  final List<SongStructureBlueprint> takes;

  const SongStyleAssessment({
    required this.detectedGenre,
    required this.stylisticVibe,
    required this.harmonicObservations,
    required this.arrangementOpportunities,
    required this.takes,
  });

  Map<String, dynamic> toJson() => {
    'detectedGenre': detectedGenre,
    'stylisticVibe': stylisticVibe,
    'harmonicObservations': harmonicObservations,
    'arrangementOpportunities': arrangementOpportunities,
    'takes': takes.map((t) => t.toJson()).toList(),
  };

  factory SongStyleAssessment.fromJson(Map<String, dynamic> json) {
    final rawTakes = json['takes'] as List? ?? [];
    final takes = rawTakes.map((t) => SongStructureBlueprint.fromJson(Map<String, dynamic>.from(t as Map))).toList();
    return SongStyleAssessment(
      detectedGenre: json['detectedGenre']?.toString() ?? 'Lo-Fi Chillhop',
      stylisticVibe: json['stylisticVibe']?.toString() ?? 'Warm, laid-back instrumental groove.',
      harmonicObservations: json['harmonicObservations']?.toString() ?? 'Lush extended chord movements.',
      arrangementOpportunities: (json['arrangementOpportunities'] as List?)?.map((e) => e.toString()).toList() ?? [],
      takes: takes,
    );
  }
}

/// Service for communicating with Google Gemini API
/// Supports both Bring-Your-Own-Key (BYOK) direct client mode and optional hosted proxy mode.
class GeminiService {
  static const String _defaultModel = 'gemini-3.6-flash';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static String? _apiKey;
  static String get apiKey => _apiKey ?? '';
  static set apiKey(String key) {
    _apiKey = key.trim();
    if (_apiKey!.isNotEmpty && keySource == GeminiKeySource.none) {
      keySource = GeminiKeySource.sessionOnly;
    }
  }

  static GeminiKeySource keySource = GeminiKeySource.none;

  static bool get hasApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  /// Loads the persisted key from secure vault or environment on startup
  static Future<void> loadPersistedApiKey() async {
    final result = await SecureStorageService.loadGeminiApiKey();
    if (result.key != null && result.key!.isNotEmpty) {
      _apiKey = result.key;
      keySource = result.source;
    }
  }

  /// Persists the API key to OS secure storage (or browser storage on Web)
  static Future<void> persistApiKey(String key) async {
    _apiKey = key.trim();
    if (_apiKey!.isNotEmpty) {
      await SecureStorageService.saveGeminiApiKey(_apiKey!);
      keySource = kIsWeb ? GeminiKeySource.browserStorage : GeminiKeySource.settingsFile;
    } else {
      await deleteApiKey();
    }
  }

  /// Deletes the API key from memory and persistent secure storage
  static Future<void> deleteApiKey() async {
    _apiKey = '';
    keySource = GeminiKeySource.none;
    await SecureStorageService.deleteGeminiApiKey();
  }

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

  /// Generates a standalone, synthesizable Eatscript instrument DSP script based on a natural language sound description.
  static Future<String> generateInstrumentScript({
    required String prompt,
    String category = 'instrument',
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are a master DSP audio engineer and Eatscript synthesizer developer for the Eatsbeats Digital Audio Workstation.
Your task is to write a complete, elegant, and self-contained Eatscript instrument script that generates rich, synthesizable sound with a stunning hardware GUI.

EATSBEATS EATSCRIPT SCRIPTING RULES:
1. Metadata header comments:
   # @name: <Title of the Instrument>
   # @author: Gemini AI & Eatsbeats
   # @category: instrument
   # @description: <Concise sound design description>
   # @tags: <comma-separated list of semantic tags, e.g. bass, synth, punchy, analog, lead>

2. Define parameters via init():
   def init():
       eat.param("Cutoff", min=20.0, max=20000.0, default=1500.0, step=1.0)
       eat.param("Resonance", min=0.0, max=1.0, default=0.3, step=0.01)
       eat.param("Waveform", min=0.0, max=2.0, default=0.0, options=["Saw", "Square", "Pulse"])

3. SKEUOMORPHIC HARDWARE GUI SPECIFICATION:
   Every instrument MUST define a hardware interface via a `def gui():` function returning a dictionary:
   def gui():
       return {
           "panel": {
               "title": "<Instrument Title>",
               "subtitle": "Analog Synth",
               "style": "dark",
               "layout": [
                   {
                       "type": "row",
                       "children": [
                           {"type": "knob", "param": "Cutoff", "label": "CUTOFF", "size": 52, "accent": "#00FFFF"},
                           {"type": "knob", "param": "Resonance", "label": "RES", "size": 52, "accent": "#FF00FF"},
                           {"type": "knob", "param": "Attack", "label": "ATTACK", "size": 44},
                           {"type": "knob", "param": "Decay", "label": "DECAY", "size": 44},
                           {"type": "knob", "param": "Sustain", "label": "SUSTAIN", "size": 44},
                           {"type": "knob", "param": "Release", "label": "RELEASE", "size": 44}
                       ]
                   }
               ]
           }
       }

4. Sound synthesis function:
   def process(time, freq, note, params):
       cutoff = params.get("Cutoff", 1500.0)
       # Generate audio samples using math.sin, math.exp, math.max, math.min, math.tanh
       return math.tanh(rawOutput * 1.2)

Output ONLY valid Eatscript code without markdown wrappers if possible, or wrapped in a single ```eatscript block.
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: 'Create a synthesized instrument matching: $prompt');
    return _extractCode(rawOutput);
  }

  /// Generates a standalone Eatscript Audio FX DSP plugin script with custom hardware GUI.
  static Future<String> generateAudioFxScript({
    required String prompt,
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are a boutique audio DSP plugin engineer for Eatsbeats DAW.
Write a complete, real-time Audio FX Eatscript script (Tape Saturation, Analog Chorus, Granular Delay, Reverb, Overdrive, Stereo Phaser, etc.) complete with a custom hardware GUI.

EATSBEATS FX SCRIPTING SPECIFICATION:
1. Header:
   # @name: <Effect Name>
   # @author: Gemini AI
   # @category: audio_fx
   # @description: <Effect Description>
   # @tags: audio_fx, <tags>

2. Parameter declarations in init():
   def init():
       eat.param("Drive", min=0.0, max=10.0, default=2.0, step=0.1)
       eat.param("Tone", min=200.0, max=8000.0, default=3000.0, step=10.0)
       eat.param("Mix", min=0.0, max=1.0, default=0.5, step=0.01)

3. SKEUOMORPHIC HARDWARE GUI SPECIFICATION:
   def gui():
       return {
           "panel": {
               "title": "<Effect Name>",
               "style": "silver",
               "layout": [
                   {
                       "type": "row",
                       "children": [
                           {"type": "knob", "param": "Drive", "label": "DRIVE", "size": 52, "accent": "#FF6600"},
                           {"type": "knob", "param": "Tone", "label": "TONE", "size": 48},
                           {"type": "knob", "param": "Mix", "label": "MIX", "size": 48, "accent": "#00FFCC"}
                       ]
                   }
               ]
           }
       }

4. Implement processSignal(inputSample, sampleRate, params) or evaluateEffect(buffer, params):
   # Ensure soft-clipping protection via math.tanh or polynomial waveshaping.

Output pure Eatscript code only.
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: 'Create an audio FX matching: $prompt');
    return _extractCode(rawOutput);
  }

  /// Generates a standalone Eatscript MIDI FX plugin script (Arpeggiators, Chord followers, Humanizers, etc.) with custom hardware GUI.
  static Future<String> generateMidiFxScript({
    required String prompt,
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    final systemInstruction = '''
You are a master MIDI algorithmic composer and Eatscript developer for Eatsbeats DAW.
Write a complete real-time MIDI FX script (Arpeggiator, Chord Strummer, Velocity Humanizer, Scale Snap, Octave Jumper, Euclidian Rhythm Generator, etc.) complete with a custom hardware GUI.

EATSBEATS MIDI FX SPECIFICATION:
1. Header:
   # @name: <Plugin Name>
   # @author: Gemini AI
   # @category: midi_fx
   # @description: <Description>

2. Define parameters via init():
   def init():
       eat.param("Rate", min=0.0, max=3.0, default=1.0, options=["1/4", "1/8", "1/16", "1/32"])
       eat.param("Octaves", min=1, max=4, default=2, step=1)
       eat.param("Gate", min=0.1, max=1.0, default=0.75, step=0.05)

3. SKEUOMORPHIC HARDWARE GUI:
   def gui():
       return {
           "panel": {
               "title": "<Plugin Name>",
               "subtitle": "MIDI FX Processor",
               "layout": [
                   {
                       "type": "row",
                       "children": [
                           {"type": "knob", "param": "Rate", "label": "RATE", "size": 52, "accent": "#00FFCC"},
                           {"type": "knob", "param": "Octaves", "label": "OCTAVES", "size": 48},
                           {"type": "knob", "param": "Gate", "label": "GATE", "size": 48}
                       ]
                   }
               ]
           }
       }

4. Implement transform_notes(notes, params, time_context):
   # Return transformed Note list or procedural MIDI events.

Output pure Eatscript code only.
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: 'Create a MIDI FX plugin matching: $prompt');
    return _extractCode(rawOutput);
  }

  /// Generates a complete, multi-track .eats arrangement song project with custom synthesizers and MIDI notes.
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
Your mission is to generate a complete, synthesizable, production-ready 4-track song project in Eatsbeats Eatscript format (`.eats`).

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
Each track can specify a proven factory preset (`presetId = "..."`) OR write a standalone `eatScriptCode`.
Available Factory Preset IDs you can use:
- Drums: "analog_909_kick", "analog_909_snare", "analog_909_closed_hihat", "analog_909_open_hihat", "analog_909_clap", "analog_909_rimshot", "eats_808_kick"
- Bass: "acid_303", "eats_303", "analog_bass", "sub_bass_synth", "fm_bass"
- Chords: "rhodes_epiano", "poly_lead", "analog_pad", "vintage_keys", "reggae_guitar", "spanish_guitar"
- Lead: "poly_lead", "acid_303", "ym2612_synth", "vintage_mono_lead"

EATSBEATS SONG FORMAT TEMPLATE:
```eatscript
song = {
  "version": "1.0",
  "meta": {
    "title": "<Song Title>",
    "author": "Gemini AI",
    "songKey": "$songKey",
    "bpm": $bpm,
    "masterVolume": 0.85,
    "isLooping": true,
    "loopStartBar": 0,
    "loopEndBar": $barLength,
    "masterEq": { "subCut": 28.0, "lowGain": 0.5, "midFreq": 320.0, "midGain": -1.0, "highGain": 1.2 },
    "masterLimiter": { "enabled": true, "ceilingDbfs": -0.3, "driveDb": 3.0, "targetLufs": -14.0 }
  },
  "patterns": [
    {
      "id": "p0",
      "name": "Main Groove",
      "lengthSteps": 16,
      "tracks": [
        {
          "id": "track_drums",
          "name": "Drums",
          "color": 4294923520,
          "type": "eatScript",
          "presetId": "analog_909_kick",
          "volume": 0.90,
          "pan": 0.0,
          "clips": [
            {
              "id": "clip_drums_0",
              "name": "Drums",
              "trackId": "track_drums",
              "startBar": 0,
              "barLength": $barLength,
              "notes": [
                { "id": "n1", "pitch": 36, "startStep": 0.0, "durationSteps": 1.0, "velocity": 0.95 },
                { "id": "n2", "pitch": 38, "startStep": 4.0, "durationSteps": 1.0, "velocity": 0.85 }
              ]
            }
          ]
        },
        {
          "id": "track_bass",
          "name": "Bass",
          "color": 4278253055,
          "type": "eatScript",
          "presetId": "acid_303",
          "volume": 0.85,
          "pan": 0.0,
          "clips": [
            {
              "id": "clip_bass_0",
              "name": "Bassline",
              "trackId": "track_bass",
              "startBar": 0,
              "barLength": $barLength,
              "notes": [
                { "id": "nb1", "pitch": 36, "startStep": 0.0, "durationSteps": 3.0, "velocity": 0.90 }
              ]
            }
          ]
        },
        {
          "id": "track_chords",
          "name": "Chords",
          "color": 4288479487,
          "type": "eatScript",
          "presetId": "rhodes_epiano",
          "volume": 0.75,
          "pan": -0.20,
          "clips": [
            {
              "id": "clip_chords_0",
              "name": "Chords",
              "trackId": "track_chords",
              "startBar": 0,
              "barLength": $barLength,
              "notes": [
                { "id": "nc1", "pitch": 60, "startStep": 0.0, "durationSteps": 8.0, "velocity": 0.80 },
                { "id": "nc2", "pitch": 63, "startStep": 0.0, "durationSteps": 8.0, "velocity": 0.75 },
                { "id": "nc3", "pitch": 67, "startStep": 0.0, "durationSteps": 8.0, "velocity": 0.75 }
              ]
            }
          ]
        },
        {
          "id": "track_lead",
          "name": "Lead",
          "color": 4294901862,
          "type": "eatScript",
          "presetId": "poly_lead",
          "volume": 0.80,
          "pan": 0.15,
          "clips": [
            {
              "id": "clip_lead_0",
              "name": "Lead Melody",
              "trackId": "track_lead",
              "startBar": 0,
              "barLength": $barLength,
              "notes": [
                { "id": "nl1", "pitch": 72, "startStep": 0.0, "durationSteps": 2.0, "velocity": 0.85 }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

CRITICAL RULES:
1. Every track MUST have a `type = "eatScript"` and either a `presetId = "..."` or a full `eatScriptCode = "..."`.
2. Note pitches must be standard MIDI numbers (C3 = 48, C4 = 60, etc.) harmonized in the key of $songKey.
3. Output valid executable Eatscript song map only.
''';

    final promptText = '''
PRODUCER INSTRUCTION:
Create a complete $barLength-bar $genre song arrangement in $songKey at $bpm BPM based on:
"$prompt"
''';

    final rawOutput = await _callGemini(systemInstruction: systemInstruction, userPrompt: promptText);
    return _extractCode(rawOutput);
  }

  /// Curated fallback bank of inspiring musical vision prompts if offline or key is missing.
  static final List<String> curatedPromptBank = [
    'RPG fireside tavern waltz with acoustic lute and wooden flute in 3/4 time, key of D Dorian',
    'Evolving cyberpunk battle theme starting with solo cello and transitioning into heavy bass and analog synth drop',
    'Ambient crystalline cavern in E minor with ethereal harp arpeggios, warm pad, and solo ocarina',
    'Late-night neo-soul jazz trio with upright bass, warm Rhodes piano, and swung brush drums at 82 BPM',
    'C64 8-bit European demo scene anthem in A minor with rapid 50Hz PWM arpeggio and singing pulse lead',
    'Pastoral Studio Ghibli inspired anime town theme with acoustic guitar, accordion, and whistling lead in 6/8',
    '90s Acid house rave anthem with syncopated 909 drums, squelchy resonant 303 bass, and euphoric chord stabs',
    'Moody Nordic cinematic soundscape in B minor with bowed strings, low brass drone, and solitary high flute',
    'Melodic chiptune boss battle with driving SNES slap bass, punchy 16-bit console drums, and heroic dual leads',
    'Lo-fi study beat in F major with nostalgic felt piano, sub bass, vinyl crackle, and gentle vibraphone counterpoint',
  ];

  /// Generates an imaginative, production-ready musical prompt using Gemini (with instant curated fallback).
  static Future<String> generateMagicPrompt() async {
    if (!hasApiKey) {
      final rng = math.Random();
      return curatedPromptBank[rng.nextInt(curatedPromptBank.length)];
    }

    try {
      const systemInstruction = '''
You are an imaginative music composer and creative director.
Generate a single, highly evocative, creative song arrangement prompt (1 to 2 sentences) for an algorithmic DAW ensemble.
Specify mood, interesting instrumentation (e.g. lute, cello, flutes, synth, rhodes, harp, brass...), meter (e.g. 3/4 waltz, 6/8, 4/4), tempo/BPM, and a tonal center or key/mode.
Output ONLY the plain prompt text without quotes, formatting, or prefixes.
''';

      final result = await _callGemini(
        systemInstruction: systemInstruction,
        userPrompt: 'Suggest an inspiring, creative song arrangement prompt with interesting instruments and meter.',
      );

      var clean = result.trim();
      if ((clean.startsWith('"') && clean.endsWith('"')) || (clean.startsWith("'") && clean.endsWith("'"))) {
        clean = clean.substring(1, clean.length - 1).trim();
      }
      if (clean.isNotEmpty) {
        return clean;
      }
    } catch (e) {
      debugPrint('[GeminiService] generateMagicPrompt fallback: $e');
    }

    final rng = math.Random();
    return curatedPromptBank[rng.nextInt(curatedPromptBank.length)];
  }

  /// Generates a structured [SongStructureBlueprint] from a natural language prompt using Gemini as the Song Architect.
  static Future<SongStructureBlueprint> generateEnsembleBlueprint({
    required String prompt,
    int? requestedBars,
  }) async {
    if (!hasApiKey) {
      throw Exception('Gemini API key is required. Please set your key in AI Settings.');
    }

    await SongArchetypeRegistry.initialize();
    final exemplarSummaries = SongArchetypeRegistry.generateAllExemplarSummaries();

    final systemInstruction = '''
You are an expert Music Arranger, Composer, and Song Architect for Eatsbeats DAW.
Your mission is to design a complete, multi-track Ensemble Song Blueprint in clean JSON format.
Do NOT output raw MIDI notes. Instead, output the macro-structural blueprint (instruments, roles, meter, chords, and section energy).

AVAILABLE FACTORY INSTRUMENT PRESET IDs:
- Drums/Percussion: "snes_drum_kit", "c64_sid_drum_kit", "gm_standard_drum_kit", "analog_909_kick", "analog_909_snare", "analog_909_closed_hihat"
- Bass: "snes_synth", "c64_sid_synth", "acid_303", "analog_bass", "sub_bass_synth", "felt_piano" (upright), "acoustic_bass"
- Chords/Pads/Keys: "felt_piano", "rhodes_epiano", "analog_pad", "vintage_keys", "snes_synth", "c64_sid_synth", "concert_grand_piano", "acoustic_steel_guitar", "spanish_guitar"
- Leads/Melody: "snes_synth", "c64_sid_synth", "poly_lead", "ym2612_synth", "vintage_mono_lead", "felt_piano" (vibes), "vibraphone", "spanish_guitar", "wooden_flute"

ROLES:
- "rhythm": drums/percussion
- "foundation": bass / root
- "harmonicTexture": chords/pads/strums (textureType: "sustained", "strummed", "arpeggiated", "stabs")
- "primaryMelody": main hook/solo/flute
- "counterpoint": answering lines / brass stabs / secondary harmony

MELODY DIRECTIVES (Empower high variety in leads & hooks):
- "melodyStyle": Choose an evocative style per section matching the genre/vibe:
  - "heroicAnthem": Bold triumphant leaps (4ths, 5ths, octaves), dotted figures, slides into held climaxes
  - "lyrical": Expressive, soulful, singing vocal-like phrasing with natural breath/rests
  - "syncopatedRiff": Funky, driving offbeat anticipations, punchy rhythmic hooks
  - "cascadingRun": Rapid undulating scalar runs and arpeggio waves (chiptune / synthwave)
  - "folkBallad": Pastoral lilting pentatonic, ornamental grace notes (3/4 or 4/4)
  - "bluesy": Expressive blue notes (b3, b5, b7), bent slides, call-and-response
  - "atmospheric": Spacious, floating, ethereal notes with long tails
- "melodyMotif": Optional array of 3-6 scale degree offsets (e.g. [0, 2, 4, 7], [0, 3, 7, 10], [7, 5, 3, 0], [0, 4, 7, 11]) to define the hook's signature melodic DNA.
- "melodyDensity": 0.1 to 1.0 (controlling note frequency vs space/rests).

$exemplarSummaries

INSTRUCTIONS FOR USING LOCAL ARCHETYPES & EXEMPLARS:
- When the user's prompt matches an archetype (e.g. "fantasy", "RPG", "medieval", "acoustic adventure", "Ultima", "tavern journey", "midnight bites"), or any compatible style, you MUST set "archetypeId": "<id>" in the JSON response, and draw directly from the archetype's instrumentation, lead directives (phrasing style, ornamentation, glissando density), and section hints.
- CONDITIONAL LEAD MELODY RULE: If an archetype does NOT have a lead melody track (or is an accompaniment, rhythm groove, or ambient texture), DO NOT force or include a "primaryMelody" track in the ensemble UNLESS the user explicitly asks for a lead, hook, or solo in their prompt!
- You can cross-breed multiple archetypes or introduce fresh variations (modulating keys, shifting tempos, altering chords).

RESPONSE FORMAT (JSON ONLY, NO MARKDOWN OUTSIDE JSON):
{
  "archetypeId": "fantasy_rpg_midnight_bites",
  "title": "Short Descriptive Title",
  "bpm": 120.0,
  "meter": "4/4",
  "rootPitchClass": 0,
  "mode": "minor",
  "ensemble": [
    {
      "trackId": "t1",
      "name": "Instrument Name",
      "presetId": "felt_piano",
      "role": "harmonicTexture",
      "textureType": "strummed",
      "colorHex": 4282433016
    }
  ],
  "sections": [
    {
      "name": "Intro",
      "lengthBars": 4,
      "chords": [
        { "rootPitchClass": 0, "quality": "minor", "barLength": 2.0 },
        { "rootPitchClass": 7, "quality": "minor", "barLength": 2.0 }
      ],
      "trackEnergy": { "t1": 0.8 },
      "melodyBehavior": "themeA",
      "melodyStyle": "lyrical",
      "melodyMotif": [0, 3, 7, 10],
      "melodyDensity": 0.70,
      "transitionFill": "none"
    }
  ]
}
''';

    final promptText = 'Create an ensemble song architecture blueprint for: "$prompt" ${requestedBars != null ? "targeting approximately $requestedBars bars." : ""}';
    final rawOutput = await _callGemini(
      systemInstruction: systemInstruction,
      userPrompt: promptText,
      responseMimeType: 'application/json',
    );

    final cleanJson = _cleanJsonResponse(rawOutput);
    final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
    return SongStructureBlueprint.fromJson(decoded);
  }

  /// Analyzes project telemetry, assesses genre and sonic vibe, and generates
  /// alternative arrangement takes using Gemini (with rich offline fallback).
  static Future<SongStyleAssessment> analyzeSongStyleAndGenerateTakes({
    required Map<String, dynamic> telemetry,
  }) async {
    final title = telemetry['title']?.toString() ?? 'Untitled Song';
    final bpm = (telemetry['bpm'] as num?)?.toDouble() ?? 120.0;
    final songKey = telemetry['songKey']?.toString() ?? 'C Major';
    final rawTracks = telemetry['tracks'] as List? ?? [];
    final rawChords = telemetry['chordTrack'] as List? ?? [];

    if (!hasApiKey) {
      return _generateOfflineStyleAssessment(telemetry);
    }

    try {
      final systemInstruction = '''
You are an elite Grammy-winning Music Producer, Arranger, and Musicologist for the Eatsbeats Digital Audio Workstation.
Your mission is to analyze the provided project telemetry, assess its exact musical genre and stylistic identity, and author 3 distinct alternative Arrangement Takes.

IMPORTANT RULES:
1. PRESERVE THE EXISTING TRACKS:
   The ensemble in each Take MUST retain the user's existing track IDs, names, and roles from the telemetry.
2. UTILIZE MUTED TRACKS AS CHANGE-UP / CHORUS LIFTS:
   If a track is marked `isMuted = true` (e.g. an acoustic guitar or synth layer), treat it as a secret weapon: give it `0.0` energy during Intros and Verses, and bring it to `0.9` to `1.0` energy during Choruses or Climaxes!
3. HARMONIC VARIATION:
   - For Verses and Choruses, keep the user's core chord progression.
   - For the Bridge / Change-Up, author a harmonically complementary contrasting progression (e.g. secondary dominants, modal interchange, or jazz ii-V substitutions).
4. RESPONSE FORMAT:
   Respond with pure JSON only adhering to this structure:
{
  "detectedGenre": "Short Genre Name (e.g. Lo-Fi Chillhop / Neo-Soul)",
  "stylisticVibe": "1-2 sentence aesthetic summary of the groove and mood.",
  "harmonicObservations": "Analysis of the harmonic movement and cadence.",
  "arrangementOpportunities": [
    "Key structural suggestion 1",
    "Key structural suggestion 2",
    "Key structural suggestion 3"
  ],
  "takes": [
    {
      "title": "Take 1: Classic Genre Arc",
      "bpm": $bpm,
      "meter": "4/4",
      "rootPitchClass": 0,
      "mode": "major",
      "ensemble": [
        { "trackId": "t1", "name": "Name", "role": "rhythm", "presetId": "", "colorHex": 4280465128 }
      ],
      "sections": [
        {
          "name": "Intro",
          "lengthBars": 4,
          "chords": [
            { "rootPitchClass": 5, "quality": "maj9", "barLength": 1.0 }
          ],
          "trackEnergy": { "t1": 0.0 }
        }
      ]
    }
  ]
}
''';

      final userPrompt = '''
PROJECT TELEMETRY:
${const JsonEncoder.withIndent('  ').convert(telemetry)}

Assess the genre and musical identity, and produce 3 tailored arrangement takes (Take 1: Classic Arc, Take 2: Contrasting Bridge Journey, Take 3: Dynamic Variation).
''';

      final rawOutput = await _callGemini(
        systemInstruction: systemInstruction,
        userPrompt: userPrompt,
        responseMimeType: 'application/json',
      );

      final cleanJson = _cleanJsonResponse(rawOutput);
      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return SongStyleAssessment.fromJson(decoded);
    } catch (e) {
      debugPrint('[GeminiService] analyzeSongStyleAndGenerateTakes fallback: $e');
      return _generateOfflineStyleAssessment(telemetry);
    }
  }

  /// Public offline procedural generator for style assessment and multi-take arrangements.
  static SongStyleAssessment generateOfflineStyleAssessment(Map<String, dynamic> telemetry) =>
      _generateOfflineStyleAssessment(telemetry);

  /// Offline procedural fallback generator for style assessment and takes.
  static SongStyleAssessment _generateOfflineStyleAssessment(Map<String, dynamic> telemetry) {
    final bpm = (telemetry['bpm'] as num?)?.toDouble() ?? 120.0;
    final songKey = telemetry['songKey']?.toString() ?? 'C Major';
    final isMinor = telemetry['isMinor'] == true;
    final rootPitchClass = (telemetry['songKeyRoot'] as num?)?.toInt() ?? 0;
    final rawTracks = telemetry['tracks'] as List? ?? [];
    final rawChords = telemetry['chordTrack'] as List? ?? [];

    // Parse existing chords or fallback to standard progression
    final List<EnsembleChordEvent> baseChords = [];
    if (rawChords.isNotEmpty) {
      for (final c in rawChords) {
        if (c is Map) {
          int root = 0;
          if (c['rootPitchClass'] is num) {
            root = ((c['rootPitchClass'] as num).toInt() + 120) % 12;
          } else if (c['root'] != null) {
            final idx = ChordTheory.pitchClassNames.indexOf(c['root'].toString());
            if (idx >= 0) root = idx;
          }
          final qStr = c['quality']?.toString().toLowerCase() ?? 'major';
          final len = (c['length'] as num?)?.toDouble() ?? 1.0;
          baseChords.add(EnsembleChordEvent(
            rootPitchClass: root,
            quality: ChordQuality.values.firstWhere(
              (q) => q.name.toLowerCase() == qStr,
              orElse: () => ChordQuality.major,
            ),
            barLength: len,
          ));
        }
      }
    }
    if (baseChords.isEmpty) {
      baseChords.addAll([
        EnsembleChordEvent(rootPitchClass: (rootPitchClass + 5) % 12, quality: ChordQuality.maj9, barLength: 1.0),
        EnsembleChordEvent(rootPitchClass: (rootPitchClass + 4) % 12, quality: ChordQuality.minor7, barLength: 1.0),
        EnsembleChordEvent(rootPitchClass: (rootPitchClass + 9) % 12, quality: ChordQuality.min9, barLength: 1.0),
        EnsembleChordEvent(rootPitchClass: rootPitchClass % 12, quality: ChordQuality.major7, barLength: 1.0),
      ]);
    }

    // Build ensemble track list
    final List<EnsembleTrackBlueprint> ensemble = [];
    final List<String> mutedTrackIds = [];
    for (final t in rawTracks) {
      if (t is Map) {
        final tId = t['id']?.toString() ?? 't';
        final tName = t['name']?.toString() ?? 'Track';
        final tRole = FunctionalRole.fromString(t['role']?.toString() ?? 'harmonicTexture');
        final isMuted = t['isMuted'] == true;
        if (isMuted) mutedTrackIds.add(tId);

        ensemble.add(EnsembleTrackBlueprint(
          trackId: tId,
          name: tName,
          presetId: '',
          role: tRole,
          colorHex: isMuted ? 0xFFFF3333 : 0xFF21F4E8,
        ));
      }
    }

    // Contrasting Bridge chords (e.g. ii9 -> V13 -> iii7 -> VI7)
    final bridgeChords = [
      EnsembleChordEvent(rootPitchClass: (rootPitchClass + 2) % 12, quality: ChordQuality.min9, barLength: 2.0),
      EnsembleChordEvent(rootPitchClass: (rootPitchClass + 7) % 12, quality: ChordQuality.dominant7, barLength: 2.0),
      EnsembleChordEvent(rootPitchClass: (rootPitchClass + 4) % 12, quality: ChordQuality.minor7, barLength: 2.0),
      EnsembleChordEvent(rootPitchClass: (rootPitchClass + 9) % 12, quality: ChordQuality.dominant7, barLength: 2.0),
    ];

    // Helper to generate energy map for a section
    Map<String, double> buildEnergyMap({
      required bool isIntro,
      required bool isVerse,
      required bool isChorus,
      required bool isBridge,
      required bool isOutro,
    }) {
      final map = <String, double>{};
      for (final t in ensemble) {
        final isMutedTrack = mutedTrackIds.contains(t.trackId);
        final isRhythm = t.role == FunctionalRole.rhythm;
        final isBass = t.role == FunctionalRole.foundation;

        if (isIntro) {
          map[t.trackId] = (isRhythm || isBass || isMutedTrack) ? 0.0 : 0.80;
        } else if (isVerse) {
          map[t.trackId] = isMutedTrack ? 0.0 : 0.85;
        } else if (isChorus) {
          map[t.trackId] = 0.95; // Unmute everything!
        } else if (isBridge) {
          map[t.trackId] = isRhythm ? 0.40 : (isMutedTrack ? 0.85 : 0.90);
        } else if (isOutro) {
          map[t.trackId] = (isRhythm || isBass) ? 0.0 : 0.70;
        }
      }
      return map;
    }

    // Take 1: Classic Chillhop Arc (32 Bars)
    final take1 = SongStructureBlueprint(
      title: 'Take 1: Classic Chillhop Arc',
      bpm: bpm,
      meter: '4/4',
      rootPitchClass: rootPitchClass,
      mode: isMinor ? 'minor' : 'major',
      ensemble: ensemble,
      sections: [
        EnsembleSectionBlueprint(
          name: 'Intro',
          lengthBars: 4,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: true, isVerse: false, isChorus: false, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeA,
        ),
        EnsembleSectionBlueprint(
          name: 'Verse 1',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: true, isChorus: false, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeA,
        ),
        EnsembleSectionBlueprint(
          name: 'Chorus 1',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: true, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeB,
        ),
        EnsembleSectionBlueprint(
          name: 'Verse 2',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: true, isChorus: false, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.variation,
        ),
        EnsembleSectionBlueprint(
          name: 'Outro',
          lengthBars: 4,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: false, isBridge: false, isOutro: true),
          melodyBehavior: MelodyBehavior.tacet,
        ),
      ],
    );

    // Take 2: Neo-Soul Reharmonized Journey (36 Bars with Bridge)
    final take2 = SongStructureBlueprint(
      title: 'Take 2: Neo-Soul Bridge Modulation',
      bpm: bpm,
      meter: '4/4',
      rootPitchClass: rootPitchClass,
      mode: isMinor ? 'minor' : 'major',
      ensemble: ensemble,
      sections: [
        EnsembleSectionBlueprint(
          name: 'Intro',
          lengthBars: 4,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: true, isVerse: false, isChorus: false, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeA,
        ),
        EnsembleSectionBlueprint(
          name: 'Verse 1',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: true, isChorus: false, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeA,
        ),
        EnsembleSectionBlueprint(
          name: 'Chorus 1',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: true, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeB,
        ),
        EnsembleSectionBlueprint(
          name: 'Bridge (Reharmonized)',
          lengthBars: 8,
          chords: bridgeChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: false, isBridge: true, isOutro: false),
          melodyBehavior: MelodyBehavior.callResponse,
        ),
        EnsembleSectionBlueprint(
          name: 'Chorus 2 (Climax)',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: true, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeB,
        ),
        EnsembleSectionBlueprint(
          name: 'Outro',
          lengthBars: 4,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: false, isBridge: false, isOutro: true),
          melodyBehavior: MelodyBehavior.tacet,
        ),
      ],
    );

    // Take 3: Dynamic 303 Breakdown & Crossover (32 Bars)
    final take3 = SongStructureBlueprint(
      title: 'Take 3: Dynamic 303 Breakdown',
      bpm: bpm,
      meter: '4/4',
      rootPitchClass: rootPitchClass,
      mode: isMinor ? 'minor' : 'major',
      ensemble: ensemble,
      sections: [
        EnsembleSectionBlueprint(
          name: 'Intro (Bass & DX7)',
          lengthBars: 4,
          chords: baseChords,
          trackEnergy: {
            for (final t in ensemble)
              t.trackId: (t.role == FunctionalRole.foundation || t.role == FunctionalRole.harmonicTexture) ? 0.85 : 0.0,
          },
          melodyBehavior: MelodyBehavior.themeA,
        ),
        EnsembleSectionBlueprint(
          name: 'Verse',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: true, isChorus: false, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeA,
        ),
        EnsembleSectionBlueprint(
          name: 'Chorus (Full Ensemble)',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: true, isBridge: false, isOutro: false),
          melodyBehavior: MelodyBehavior.themeB,
        ),
        EnsembleSectionBlueprint(
          name: 'Acid Bass Breakdown',
          lengthBars: 8,
          chords: baseChords,
          trackEnergy: {
            for (final t in ensemble)
              t.trackId: (t.role == FunctionalRole.foundation || t.role == FunctionalRole.rhythm) ? 0.90 : 0.0,
          },
          melodyBehavior: MelodyBehavior.variation,
        ),
        EnsembleSectionBlueprint(
          name: 'Outro',
          lengthBars: 4,
          chords: baseChords,
          trackEnergy: buildEnergyMap(isIntro: false, isVerse: false, isChorus: false, isBridge: false, isOutro: true),
          melodyBehavior: MelodyBehavior.tacet,
        ),
      ],
    );

    final genreName = (bpm >= 115 && bpm <= 135)
        ? 'Lo-Fi Chillhop / Neo-Soul Groove'
        : (bpm < 100 ? 'Lo-Fi Hip Hop / Downtempo' : 'Neo-Soul / Ambient Fusion');

    return SongStyleAssessment(
      detectedGenre: genreName,
      stylisticVibe: 'Warm, laid-back instrumental groove combining digital FM electric piano, subby analog bassline, and physical acoustic instruments.',
      harmonicObservations: 'Lush modal IVmaj9 - iiim7 - vim9 - Imaj7 progression with smooth voice-leading and rich jazz color.',
      arrangementOpportunities: [
        'Hold back the muted Steel-String Acoustic Guitar until the Chorus to provide a vibrant organic lift.',
        'Use the DX7 E-Piano and gentle hats to set an intimate atmosphere during the 4-bar Intro.',
        'Introduce contrasting ii-V harmonic movement in an 8-bar Bridge to create narrative tension before the final drop.',
      ],
      takes: [take1, take2, take3],
    );
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
    for (final prefix in ['```eatscript', '```python', '```eat', '```']) {
      if (cleaned.contains(prefix)) {
        final startIndex = cleaned.indexOf(prefix) + prefix.length;
        final endIndex = cleaned.lastIndexOf('```');
        if (endIndex > startIndex) {
          return cleaned.substring(startIndex, endIndex).trim();
        }
      }
    }
    return cleaned;
  }
}
