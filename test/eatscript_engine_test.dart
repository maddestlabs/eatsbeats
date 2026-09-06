import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eat_token.dart';
import 'package:eatsbeats/eatscript/eat_lexer.dart';
import 'package:eatsbeats/eatscript/eat_parser.dart';
import 'package:eatsbeats/eatscript/eat_interpreter.dart';
import 'package:eatsbeats/eatscript/eat_api.dart';
import 'package:eatsbeats/eatscript/eat_script_engine.dart';
import 'package:eatsbeats/eatscript/eat_transpiler.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/lua/default_song.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/lua/midi_pipeline_engine.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/audio/time_context.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/utils/eats_storage_helper.dart';

void main() {
  group('Eatscript Lexer Tests', () {
    test('Tokenizes basic math and variables', () {
      final code = 'tempo = 120 + 4 * 2';
      final lexer = EatLexer(code);
      final tokens = lexer.tokenize();

      expect(tokens.any((t) => t.type == EatTokenType.identifier && t.lexeme == 'tempo'), isTrue);
      expect(tokens.any((t) => t.type == EatTokenType.assign), isTrue);
      expect(tokens.any((t) => t.type == EatTokenType.number && t.literal == 120), isTrue);
      expect(tokens.any((t) => t.type == EatTokenType.plus), isTrue);
      expect(tokens.any((t) => t.type == EatTokenType.multiply), isTrue);
    });

    test('Handles Python indentation (INDENT and DEDENT)', () {
      final code = '''
if True:
    a = 10
    if a > 5:
        b = 20
c = 30
''';
      final lexer = EatLexer(code);
      final tokens = lexer.tokenize();

      final indents = tokens.where((t) => t.type == EatTokenType.indent).length;
      final dedents = tokens.where((t) => t.type == EatTokenType.dedent).length;

      expect(indents, equals(2));
      expect(dedents, equals(2));
    });

    test('Tokenizes strings with quotes and escapes', () {
      final code = 'msg = "Hello \\"World\\""\ntext = \'Single quote\'';
      final lexer = EatLexer(code);
      final tokens = lexer.tokenize();

      final strTokens = tokens.where((t) => t.type == EatTokenType.string).toList();
      expect(strTokens.length, equals(2));
      expect(strTokens[0].literal, equals('Hello "World"'));
      expect(strTokens[1].literal, equals('Single quote'));
    });
  });

  group('Eatscript Parser & Interpreter Tests', () {
    test('Evaluates arithmetic with correct precedence', () {
      final code = '''
x = 2 + 3 * 4
y = (2 + 3) * 4
z = 2 ** 3
''';
      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      final program = parser.parse();

      final interpreter = EatInterpreter();
      interpreter.interpret(program);

      expect(interpreter.globals.get('x', line: 1, column: 1), equals(14));
      expect(interpreter.globals.get('y', line: 1, column: 1), equals(20));
      expect(interpreter.globals.get('z', line: 1, column: 1), equals(8));
    });

    test('Evaluates control flow: if/elif/else', () {
      final code = '''
score = 85
grade = "F"
if score >= 90:
    grade = "A"
elif score >= 80:
    grade = "B"
else:
    grade = "C"
''';
      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      final program = parser.parse();

      final interpreter = EatInterpreter();
      interpreter.interpret(program);

      expect(interpreter.globals.get('grade', line: 1, column: 1), equals('B'));
    });

    test('Evaluates for loop with range() and sum', () {
      final code = '''
total = 0
for i in range(1, 6):
    total += i
''';
      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      final program = parser.parse();

      final interpreter = EatInterpreter();
      interpreter.interpret(program);

      expect(interpreter.globals.get('total', line: 1, column: 1), equals(15));
    });

    test('Supports user-defined functions with default arguments', () {
      final code = '''
def add_values(a, b=10):
    return a + b

res1 = add_values(5)
res2 = add_values(5, 20)
''';
      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      final program = parser.parse();

      final interpreter = EatInterpreter();
      interpreter.interpret(program);

      expect(interpreter.globals.get('res1', line: 1, column: 1), equals(15));
      expect(interpreter.globals.get('res2', line: 1, column: 1), equals(25));
    });

    test('Prevents infinite loops with execution step limiter', () {
      final code = '''
while True:
    pass
''';
      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      final program = parser.parse();

      final interpreter = EatInterpreter(maxExecutionSteps: 500);

      expect(
        () => interpreter.interpret(program),
        throwsA(isA<EatRuntimeException>()),
      );
    });
  });

  group('Eatscript Music API (eat.*) Tests', () {
    test('Registers parameters via eat.param', () {
      final code = '''
rate = eat.param("rate", 0.125, 1.0, 0.25)
octave = eat.param("octave", -2, 2, 0, step=1)
''';
      final context = EatScriptContext(paramValues: {'rate': 0.5});
      final interpreter = EatInterpreter();
      EatHostApi.install(interpreter, context);

      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      interpreter.interpret(parser.parse());

      expect(context.params.length, equals(2));
      expect(context.params[0].name, equals('rate'));
      expect(context.params[0].defaultValue, equals(0.25));
      expect(interpreter.globals.get('rate', line: 1, column: 1), equals(0.5)); // bound value
      expect(interpreter.globals.get('octave', line: 1, column: 1), equals(0)); // default value
    });

    test('Generates notes with eat.add_note', () {
      final code = '''
for step in range(4):
    eat.add_note(pitch=60 + step * 2, start=step * 0.5, duration=0.4, velocity=0.9)
''';
      final context = EatScriptContext();
      final interpreter = EatInterpreter();
      EatHostApi.install(interpreter, context);

      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      interpreter.interpret(parser.parse());

      expect(context.notes.length, equals(4));
      expect(context.notes[0].pitch, equals(60));
      expect(context.notes[1].pitch, equals(62));
      expect(context.notes[3].startStep, equals(1.5));
    });

    test('Euclidean rhythm generation', () {
      final code = '''
hits = []
for i in range(16):
    if eat.euclidean(i, 16, 4):
        hits.append(i)
''';
      final context = EatScriptContext();
      final interpreter = EatInterpreter();
      EatHostApi.install(interpreter, context);

      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      interpreter.interpret(parser.parse());

      final hits = interpreter.globals.get('hits', line: 1, column: 1) as List;
      expect(hits.length, equals(4));
      expect(hits, equals([0, 4, 8, 12]));
    });

    test('Music theory: scale generation and snap to chord', () {
      final code = '''
c_major = eat.scale("C4", "major")
c_minor = eat.scale("C4", "minor")
snapped = eat.snap_to_chord(61, "Cmaj") # C#4 snapped to Cmaj (60 or 64)
''';
      final context = EatScriptContext();
      final interpreter = EatInterpreter();
      EatHostApi.install(interpreter, context);

      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      interpreter.interpret(parser.parse());

      final majorScale = interpreter.globals.get('c_major', line: 1, column: 1) as List;
      expect(majorScale, equals([60, 62, 64, 65, 67, 69, 71]));

      final snappedNote = interpreter.globals.get('snapped', line: 1, column: 1);
      expect([60, 64].contains(snappedNote), isTrue);
    });

    test('Humanize and Transpose transformations', () {
      final code = '''
eat.add_note(pitch=60, start=0.0, duration=1.0, velocity=0.8)
eat.add_note(pitch=64, start=1.0, duration=1.0, velocity=0.8)
eat.transpose(semitones=2)
''';
      final context = EatScriptContext();
      final interpreter = EatInterpreter();
      EatHostApi.install(interpreter, context);

      final lexer = EatLexer(code);
      final parser = EatParser(lexer.tokenize());
      interpreter.interpret(parser.parse());

      expect(context.notes[0].pitch, equals(62));
      expect(context.notes[1].pitch, equals(66));
    });
  });

  group('EatScriptEngine Facade Tests', () {
    test('Compiles valid Eatscript and extracts metadata', () {
      final code = '''
# Generative Pattern
eat.param("density", 1, 16, 8)
for i in range(4):
    eat.add_note(60 + i, i * 1.0, 0.5)
''';
      final res = EatScriptEngine.compile(code);
      expect(res.isSuccess, isTrue);
      expect(res.params.length, equals(1));
      expect(res.params.first.name, equals('density'));
    });

    test('Catches syntax errors with line/column information', () {
      final code = '''
x = 10
if x > 5
    y = 20
'''; // Missing colon
      final res = EatScriptEngine.compile(code);
      expect(res.isSuccess, isFalse);
      expect(res.errorLine, equals(2));
      expect(res.errorMessage, contains('Expected ":"'));
    });

    test('Executes clip script and generates transformed notes', () {
      final code = '''
pulses = eat.param("pulses", 1, 8, 4)
for s in range(8):
    if eat.euclidean(s, 8, pulses):
        eat.add_note(pitch=60, start=s * 0.5, duration=0.25)
''';
      final notes = EatScriptEngine.executeClipScript(
        code,
        [],
        paramValues: {'pulses': 2},
      );

      expect(notes.length, equals(2));
    });

    test('Parses complete Eatscript song project map', () {
      final songCode = '''
# Midnight Bites (Eatscript Template)
song = {
    "version": "1.0",
    "meta": {
        "title": "Midnight Bites",
        "author": "Eatsbeats",
        "bpm": 124.0,
        "masterVolume": 0.85,
        "isSongMode": False,
        "isLooping": True,
        "loopStartBar": 0,
        "loopEndBar": 2,
    },
    "patterns": [
        {
            "id": "p0",
            "name": "Pattern A",
            "lengthSteps": 16,
            "tracks": [
                {
                    "id": "t_kick",
                    "name": "Eats Kick",
                    "color": 0xffff007a,
                    "type": "synth",
                    "volume": 0.95,
                    "pan": 0.0,
                    "notes": [
                        {"id": "k_0", "pitch": 36, "startStep": 0.0, "durationSteps": 1.0, "velocity": 0.95},
                        {"id": "k_4", "pitch": 36, "startStep": 4.0, "durationSteps": 1.0, "velocity": 0.95},
                    ],
                }
            ]
        }
    ]
}
''';
      final map = EatScriptEngine.parseDataMap(songCode);
      expect(map.isNotEmpty, isTrue);
      expect(map['meta']['title'], equals('Midnight Bites'));
      expect((map['patterns'] as List).length, equals(1));
      expect((map['patterns'][0]['tracks'][0]['notes'] as List).length, equals(2));
    });

    test('DawState loads Eatscript song project directly', () {
      final dawState = DawState();
      final songCode = '''
# Midnight Bites (Eatscript Template)
song = {
    "version": "1.0",
    "meta": {
        "title": "Midnight Bites Eatscript",
        "author": "Eatsbeats",
        "bpm": 128.0,
        "masterVolume": 0.85,
        "isSongMode": False,
        "isLooping": True,
        "loopStartBar": 0,
        "loopEndBar": 2,
    },
    "patterns": [
        {
            "id": "p0",
            "name": "Pattern A",
            "lengthSteps": 16,
            "tracks": [
                {
                    "id": "t_kick",
                    "name": "Eats Kick",
                    "color": 0xffff007a,
                    "type": "synth",
                    "volume": 0.95,
                    "pan": 0.0,
                    "notes": [
                        {"id": "k_0", "pitch": 36, "startStep": 0.0, "durationSteps": 1.0, "velocity": 0.95},
                    ],
                }
            ]
        }
    ]
}
''';
      dawState.loadFromEatsLua(songCode);
      expect(dawState.projectName, equals('Midnight Bites Eatscript'));
      expect(dawState.bpm, equals(128.0));
      expect(dawState.activePattern.tracks.first.name, equals('Eats Kick'));
      expect(dawState.activePattern.tracks.first.notes.first.pitch, equals(36));
    });

    test('Generate default_song_eat.dart', () {
      final map = EatsLuaParser.parseLuaTableToMap(DefaultSong.midnightBitesLua);
      expect(map.isNotEmpty, isTrue);

      const eatsKickEatscript = '''# --- Procedural Sub Kick Drum (Eatscript) ---
import math

def init():
    eat.param("StartFreq", min=100.0, max=300.0, default=160.0)
    eat.param("EndFreq", min=30.0, max=60.0, default=42.0)
    eat.param("PitchDecay", min=0.01, max=0.2, default=0.035)
    eat.param("AmpDecay", min=0.05, max=4.0, default=0.35)
    eat.param("Click", min=0.0, max=1.0, default=0.0)

def process(time, freq, note, params):
    startF = params.get("StartFreq", 160.0)
    endF = params.get("EndFreq", 42.0)
    pDecay = params.get("PitchDecay", 0.035)
    aDecay = params.get("AmpDecay", 0.35)
    click = params.get("Click", 0.0)

    curFreq = endF + (startF - endF) * math.exp(-time / max(0.005, pDecay))
    phase = 2.0 * math.pi * curFreq * time
    subSine = math.sin(phase)

    clickTransient = (math.random() * 2.0 - 1.0) * math.exp(-time * 150.0) * click
    env = math.exp(-time * 4.0 / max(0.01, aDecay))
    rawOutput = (subSine * 0.85 + clickTransient * 0.15) * env

    maxDur = max(0.1, aDecay)
    fadeStart = maxDur - 0.04
    edgeFade = 1.0
    if time > fadeStart:
        norm = max(0.0, min(1.0, (maxDur - time) / 0.04))
        edgeFade = 0.5 * (1.0 - math.cos(math.pi * norm))
    if time >= maxDur:
        edgeFade = 0.0
    return math.tanh(rawOutput * edgeFade * 1.3)

def gui():
    return {
        "panel": {
            "title": "EATS KICK",
            "subtitle": "Sub Kick Drum Generator",
            "accent": "#FF4444",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "StartFreq", "label": "START", "size": 52},
                        {"type": "knob", "param": "EndFreq", "label": "END", "size": 52},
                        {"type": "knob", "param": "PitchDecay", "label": "P.DECAY", "size": 52},
                        {"type": "knob", "param": "AmpDecay", "label": "DECAY", "size": 52},
                        {"type": "knob", "param": "Click", "label": "CLICK", "size": 52},
                    ]
                }
            ]
        }
    }

ProceduralKick = True
''';

      const eatsSnareEatscript = '''# --- Procedural Snare Drum (Eatscript) ---
import math

def init():
    eat.param("ToneFreq", min=100.0, max=320.0, default=185.0)
    eat.param("Snappy", min=0.0, max=1.0, default=0.65)
    eat.param("Decay", min=0.05, max=0.8, default=0.18)
    eat.param("Variation", min=0.0, max=1.0, default=0.0)

def process(time, freq, note, params):
    toneFreq = params.get("ToneFreq", 185.0)
    snappy = params.get("Snappy", 0.65)
    decay = params.get("Decay", 0.18)
    variation = params.get("Variation", 0.0)

    if variation > 0.001:
        vOffset = (math.sin(note * 12.9898) * 0.5 + 0.5) * variation
        toneFreq = toneFreq * (1.0 + (vOffset - 0.5 * variation) * 0.08)
        decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.15)

    sweepFreq = toneFreq * (1.0 + 1.2 * math.exp(-time * 60.0))
    body = math.sin(2.0 * math.pi * sweepFreq * time) * math.exp(-time * 22.0)
    overtone = math.sin(2.0 * math.pi * (toneFreq * 1.75) * time) * math.exp(-time * 30.0) * 0.35
    tonalCore = body + overtone

    noise = (math.random() * 2.0 - 1.0) * math.exp(-time / max(0.01, decay))
    click = (math.random() * 2.0 - 1.0) * math.exp(-time * 250.0) * 0.25

    output = tonalCore * (1.0 - snappy * 0.6) + noise * (snappy * 1.2) + click
    return math.tanh(output * 1.3)

def gui():
    return {
        "panel": {
            "title": "EATS SNARE",
            "subtitle": "Snare Drum Synthesizer",
            "accent": "#00FFCC",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "ToneFreq", "label": "TONE", "size": 52},
                        {"type": "knob", "param": "Snappy", "label": "SNAPPY", "size": 52},
                        {"type": "knob", "param": "Decay", "label": "DECAY", "size": 52},
                        {"type": "knob", "param": "Variation", "label": "VAR", "size": 52},
                    ]
                }
            ]
        }
    }

ProceduralSnare = True
''';

      const eatsHiHatEatscript = '''# --- Procedural Hi-Hat Synth (Eatscript) ---
import math

def init():
    eat.param("Cutoff", min=3000.0, max=14000.0, default=7500.0)
    eat.param("Decay", min=0.01, max=0.6, default=0.06)
    eat.param("Metallic", min=0.0, max=1.0, default=0.15)
    eat.param("Variation", min=0.0, max=1.0, default=0.0)

def process(time, freq, note, params):
    cutoff = params.get("Cutoff", 7500.0)
    decay = params.get("Decay", 0.06)
    metallic = params.get("Metallic", 0.15)
    variation = params.get("Variation", 0.0)

    if variation > 0.001:
        vOffset = (math.sin(note * 78.233) * 0.5 + 0.5) * variation
        cutoff = cutoff * (1.0 + (vOffset - 0.5 * variation) * 0.12)
        decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.18)

    env = math.exp(-time / max(0.005, decay))
    ring1 = math.sin(2.0 * math.pi * 320.0 * time)
    ring2 = math.sin(2.0 * math.pi * 540.0 * time)
    ring3 = math.sin(2.0 * math.pi * 890.0 * time)
    metallicRing = (ring1 + ring2 + ring3) * 0.333

    noise = (math.random() * 2.0 - 1.0)
    rawSignal = noise * (1.0 - metallic * 0.3) + metallicRing * (metallic * 0.3)
    return math.tanh(rawSignal * env * 1.1)

def gui():
    return {
        "panel": {
            "title": "EATS HI-HAT",
            "subtitle": "Metallic Hat Synthesizer",
            "accent": "#FFCC00",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Cutoff", "label": "CUTOFF", "size": 52},
                        {"type": "knob", "param": "Decay", "label": "DECAY", "size": 52},
                        {"type": "knob", "param": "Metallic", "label": "METALLIC", "size": 52},
                        {"type": "knob", "param": "Variation", "label": "VAR", "size": 52},
                    ]
                }
            ]
        }
    }

ProceduralHiHat = True
''';

      const eats303Eatscript = '''# --- Eats-303 Acid Bassline (Eatscript) ---
import math

def init():
    eat.param("Waveform", min=0.0, max=1.0, default=0.0, step=1.0)
    eat.param("Pitch", min=-12.0, max=12.0, default=0.0, step=1.0)
    eat.param("Cutoff", min=200.0, max=4500.0, default=1400.0)
    eat.param("Resonance", min=0.5, max=16.0, default=9.2)
    eat.param("EnvMod", min=0.0, max=1.0, default=0.75)
    eat.param("Decay", min=0.05, max=1.2, default=0.28)
    eat.param("Accent", min=0.0, max=1.0, default=0.78)
    eat.param("Octave", min=-2.0, max=0.0, default=0.0, step=1.0)
    eat.param("SubWaveform", min=0.0, max=1.0, default=0.0, step=1.0)
    eat.param("SubVolume", min=0.0, max=1.0, default=0.0)
    eat.param("Drive", min=0.0, max=1.0, default=0.25)
    eat.param("Slide", min=0.0, max=1.0, default=0.0)

def process(time, freq, note, params, targetNote=0, isSlide=False, isAccent=False):
    waveType = params.get("Waveform", 0.0)
    pitch = params.get("Pitch", 0.0)
    cutoff = params.get("Cutoff", 1400.0)
    res = params.get("Resonance", 9.2)
    envMod = params.get("EnvMod", 0.75)
    decay = params.get("Decay", 0.28)
    accent = params.get("Accent", 0.78)
    drive = params.get("Drive", 0.25)
    octave = int(params.get("Octave", 0.0) + 0.5)
    subWave = params.get("SubWaveform", 0.0)
    subVol = params.get("SubVolume", 0.0)

    baseFreq = freq * (2.0 ** (octave + pitch / 12.0))
    phase = time * baseFreq
    normPhase = phase - math.floor(phase)
    sawRaw = 2.0 * normPhase - 1.0
    sawHP = sawRaw - 0.85 * math.exp(-time * 12.0)
    sqrRaw = 0.78 if normPhase < 0.48 else -0.78
    osc = (1.0 - waveType) * sawHP + waveType * sqrRaw

    hasAccent = isAccent or (accent > 0.7 and not isSlide)
    activeDecay = 0.200 if hasAccent else decay
    softAttack = 1.0 - math.exp(-time / 0.003)
    env = softAttack * math.exp(-time / activeDecay)
    accentPulse = (accent * 0.55 * math.exp(-time / 0.035)) if hasAccent else 0.0

    output = osc * env
    if drive > 0.02:
        output = math.tanh(output * (1.0 + drive * 3.5))
    return output

def gui():
    return {
        "panel": {
            "title": "EATS-303 ACID BASSLINE",
            "subtitle": "Eats-303 Acid Synth • (JC-303 & Open303 DSP)",
            "background": "silver",
            "accent": "#000000",
            "knobStyle": "chrome",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "switch", "param": "Waveform", "label": "WAVEFORM", "options": ["SAW", "SQR"]},
                        {"type": "divider", "orientation": "vertical", "height": 62},
                        {"type": "knob", "param": "Pitch", "label": "PITCH", "size": 52, "knobStyle": "chrome"},
                        {"type": "knob", "param": "Cutoff", "label": "CUTOFF", "size": 58, "knobStyle": "chrome"},
                        {"type": "knob", "param": "Resonance", "label": "RESONANCE", "size": 58, "knobStyle": "chrome"},
                        {"type": "knob", "param": "EnvMod", "label": "ENV MOD", "size": 54, "knobStyle": "chrome"},
                        {"type": "knob", "param": "Decay", "label": "DECAY", "size": 54, "knobStyle": "chrome"},
                        {"type": "knob", "param": "Accent", "label": "ACCENT", "size": 54, "knobStyle": "chrome"},
                    ]
                },
                {"type": "divider", "orientation": "horizontal"},
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Octave", "label": "OCTAVE", "size": 50, "knobStyle": "chrome"},
                        {"type": "divider", "orientation": "vertical", "height": 56},
                        {"type": "switch", "param": "SubWaveform", "label": "SUB OSC", "options": ["SIN", "SQR"]},
                        {"type": "knob", "param": "SubVolume", "label": "SUB VOL", "size": 52, "knobStyle": "chrome"},
                        {"type": "divider", "orientation": "vertical", "height": 56},
                        {"type": "slider", "param": "Slide", "label": "PORTAMENTO SLIDE", "orientation": "horizontal", "size": 140},
                        {"type": "divider", "orientation": "vertical", "height": 56},
                        {"type": "knob", "param": "Drive", "label": "DRIVE", "size": 54, "knobStyle": "chrome"},
                    ]
                }
            ]
        }
    }

Eats303 = True
JC303 = True
''';

      final patterns = map['patterns'] as List;
      for (final p in patterns) {
        final tracks = (p as Map)['tracks'] as List;
        for (final t in tracks) {
          final tMap = t as Map;
          final name = tMap['name'].toString();
          if (name.contains('Kick')) {
            tMap['luaScriptCode'] = eatsKickEatscript;
          } else if (name.contains('Snare')) {
            tMap['luaScriptCode'] = eatsSnareEatscript;
          } else if (name.contains('Hi-Hat') || name.contains('HiHat')) {
            tMap['luaScriptCode'] = eatsHiHatEatscript;
          } else if (name.contains('303')) {
            tMap['luaScriptCode'] = eats303Eatscript;
          }
        }
      }

      final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
      final q = "'''";
      final fileContent = 'class DefaultSongEat {\n  static const String midnightBitesEat = r$q# Eatsbeats Song File: "Midnight Bites" (Eatscript)\n# Generated by Eatsbeats DAW\n\nsong = $jsonStr\n$q;\n}\n';
      File('lib/eatscript/default_song_eat.dart').writeAsStringSync(fileContent);
      expect(File('lib/eatscript/default_song_eat.dart').existsSync(), isTrue);
    });

    test('DawState loads DefaultSongEat.midnightBitesEat seamlessly', () {
      final dawState = DawState();
      final songCode = File('lib/eatscript/default_song_eat.dart').readAsStringSync();
      final match = RegExp(r"midnightBitesEat = r'''([\s\S]*?)''';", multiLine: true).firstMatch(songCode);
      expect(match, isNotNull);
      final rawEat = match!.group(1)!;

      dawState.loadFromEatsLua(rawEat);
      expect(dawState.projectName, equals('Midnight Bites'));
      expect(dawState.bpm, equals(124.0));
      expect(dawState.patterns.length, equals(2));
      expect(dawState.patterns.first.tracks.length, equals(4));
      expect(dawState.activePattern.tracks.first.name, equals('Eats Kick'));
    });

    test('EatTranspiler transpiles Lua preset to Eatscript and compiles cleanly', () {
      final luaCode = '''
-- @id: custom_test_synth
-- @name: Custom Test Synth
-- @category: instrument
-- @description: Test instrument preset
Param.add("Cutoff", 100.0, 5000.0, 1200.0, 10.0)
Param.choice("Waveform", {"Saw", "Square"}, 0)

function TestSynth.gui()
  return {
    panel = {
      title = "TEST SYNTH",
      subtitle = "Test Subtitle",
      background = "dark",
      accent = "#FF8C00",
    }
  }
end
''';
      final eatCode = EatTranspiler.transpileLuaPreset(luaCode);
      expect(eatCode.contains('# @id: custom_test_synth'), isTrue);
      expect(eatCode.contains('def init():'), isTrue);
      expect(eatCode.contains('def gui():'), isTrue);
      expect(eatCode.contains('TEST SYNTH'), isTrue);

      final compRes = EatScriptEngine.compile(eatCode);
      expect(compRes.isSuccess, isTrue);
      expect(compRes.params.length, equals(2));
      expect(compRes.params.any((p) => p.name == 'Cutoff'), isTrue);
      expect(compRes.params.any((p) => p.name == 'Waveform'), isTrue);
      expect(compRes.guiLayout, isNotNull);
      expect(compRes.guiLayout!.title, equals('TEST SYNTH'));
    });
  });

  group('Eatscript Converted MIDI FX Live Pipeline Tests', () {
    late LuaEngine luaEngine;
    late MidiPipelineEngine pipeline;

    setUp(() {
      luaEngine = LuaEngine();
      pipeline = MidiPipelineEngine(luaEngine: luaEngine);
    });

    test('Arpeggiator FX preset runs via Eatscript in MidiPipelineEngine with live parameter scaling', () {
      final arpPreset = LuaPresetLibrary.getPresetById('arpeggiator_midi_fx')!;
      expect(arpPreset.code.contains('def init():'), isTrue);
      expect(arpPreset.code.contains('eat.arpeggiate'), isTrue);

      final track = TrackChannel(id: 't_arp', name: 'Arp Track', type: TrackType.synth, color: const Color(0xFFFF8C00));
      final clip = TrackClip(
        id: 'c_arp',
        name: 'Arp Clip',
        trackId: 't_arp',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 4.0),
          Note(id: 'n2', pitch: 64, startStep: 0.0, durationSteps: 4.0),
          Note(id: 'n3', pitch: 67, startStep: 0.0, durationSteps: 4.0),
        ],
      );
      track.clips.add(clip);

      final mfx = MidiFXInsert(
        id: 'mfx_1',
        name: arpPreset.name,
        luaScriptCode: arpPreset.code,
        luaParams: {'Rate': 1.0, 'Octaves': 2.0, 'Pattern': 0.0},
      );
      track.midiFXRack.add(mfx);

      final tc = TimeContext(
        bpm: 120.0,
        currentBar: 0.0,
        currentBeat: 0.0,
        audioTimeSeconds: 0.0,
      );

      final evaluated = pipeline.processClip(clip: clip, track: track, timeContext: tc);
      expect(evaluated.length, equals(4));
      expect(evaluated[0].pitch, equals(60));
      expect(evaluated[1].pitch, equals(64));
      expect(evaluated[2].pitch, equals(67));
      expect(evaluated[3].pitch, equals(72));

      // Test live parameter update: change Rate to 0.5 (double speed -> 8 steps)
      mfx.luaParams['Rate'] = 0.5;
      final evaluatedDoubleSpeed = pipeline.processClip(clip: clip, track: track, timeContext: tc);
      expect(evaluatedDoubleSpeed.length, equals(8));
    });

    test('Scale Snap FX preset runs via Eatscript and conforms pitches', () {
      final snapPreset = LuaPresetLibrary.getPresetById('scale_snap_midi_fx')!;
      expect(snapPreset.code.contains('eat.scale_snap'), isTrue);

      final track = TrackChannel(id: 't_snap', name: 'Snap Track', type: TrackType.synth, color: const Color(0xFF00E5FF));
      final clip = TrackClip(
        id: 'c_snap',
        name: 'Snap Clip',
        trackId: 't_snap',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 61, startStep: 0.0, durationSteps: 1.0), // C#4
        ],
      );
      track.clips.add(clip);

      final mfx = MidiFXInsert(
        id: 'mfx_snap',
        name: snapPreset.name,
        luaScriptCode: snapPreset.code,
        luaParams: {'Key': 0.0, 'Scale': 0.0}, // C Major (C# snaps to C or D)
      );
      track.midiFXRack.add(mfx);

      final tc = TimeContext(
        bpm: 120.0,
        currentBar: 0.0,
        currentBeat: 0.0,
        audioTimeSeconds: 0.0,
      );

      final evaluated = pipeline.processClip(clip: clip, track: track, timeContext: tc);
      expect(evaluated.length, equals(1));
      expect(evaluated.first.pitch, isIn([60, 62]));
    });

    test('Harmonic Chord Follower FX conforms notes to active Chord Track in Eatscript', () {
      final followPreset = LuaPresetLibrary.getPresetById('chord_follower_midi_fx')!;
      expect(followPreset.code.contains('eat.chord_follow'), isTrue);

      final track = TrackChannel(id: 't_cf', name: 'CF Track', type: TrackType.synth, color: const Color(0xFFFF8C00));
      final clip = TrackClip(
        id: 'c_cf',
        name: 'CF Clip',
        trackId: 't_cf',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 2.0),
        ],
      );
      track.clips.add(clip);

      final mfx = MidiFXInsert(
        id: 'mfx_cf',
        name: followPreset.name,
        luaScriptCode: followPreset.code,
        luaParams: {'Mode': 0.0},
      );
      track.midiFXRack.add(mfx);

      final tc = TimeContext(
        bpm: 120.0,
        currentBar: 0.0,
        currentBeat: 0.0,
        audioTimeSeconds: 0.0,
        activeChord: ChordEvent(
          id: 'ch_g',
          startBar: 0,
          rootPitchClass: 7, // G
          quality: ChordQuality.major,
        ),
      );

      final evaluated = pipeline.processClip(clip: clip, track: track, timeContext: tc);
      expect(evaluated.length, equals(1));
      // In chord tones mode for G major (G, B, D = 7, 11, 2 mod 12), pitch 60 snaps to 59(B) or 62(D)
      expect(evaluated.first.pitch % 12, isIn([7, 11, 2]));
    });

    test('Humanize & Groove FX introduces dynamic velocity jitter in Eatscript', () {
      final humanPreset = LuaPresetLibrary.getPresetById('humanize_midi_fx')!;
      expect(humanPreset.code.contains('eat.humanize'), isTrue);

      final track = TrackChannel(id: 't_h', name: 'Human Track', type: TrackType.synth, color: const Color(0xFFE040FB));
      final clip = TrackClip(
        id: 'c_h',
        name: 'Human Clip',
        trackId: 't_h',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0, velocity: 0.8),
          Note(id: 'n2', pitch: 62, startStep: 1.0, durationSteps: 1.0, velocity: 0.8),
        ],
      );
      track.clips.add(clip);

      final mfx = MidiFXInsert(
        id: 'mfx_h',
        name: humanPreset.name,
        luaScriptCode: humanPreset.code,
        luaParams: {'Timing': 0.05, 'Velocity': 0.2},
      );
      track.midiFXRack.add(mfx);

      final tc = TimeContext(
        bpm: 120.0,
        currentBar: 0.0,
        currentBeat: 0.0,
        audioTimeSeconds: 0.0,
      );

      final evaluated = pipeline.processClip(clip: clip, track: track, timeContext: tc);
      expect(evaluated.length, equals(2));
      // Notes should have jittered velocity or timing
      expect(evaluated[0].velocity != 0.8 || evaluated[1].velocity != 0.8, isTrue);
    });

    test('Supports math module, random module, and import statements in Eatscript', () {
      final code = '''
import math
import random
from math import sin, pi

def calculate():
    val = math.sin(math.pi / 2.0)
    e_val = math.exp(0.0)
    p_val = math.pow(2.0, 3.0)
    rnd = math.random()
    return val + e_val + p_val
''';
      final compiled = EatScriptEngine.compile(code);
      expect(compiled.isSuccess, isTrue);

      final interpreter = EatInterpreter();
      final program = EatParser(EatLexer(code).tokenize()).parse();
      interpreter.interpret(program);
      final fn = interpreter.globals.get('calculate', line: 1, column: 1) as EatCallable;
      final result = fn.call(interpreter, [], {}, line: 1, column: 1) as num;
      // 1.0 (sin) + 1.0 (exp) + 8.0 (pow) = 10.0
      expect(result, closeTo(10.0, 0.001));
    });

    test('LuaPreset.eatCode transpiles library presets into valid Eatscript with params and GUI', () {
      final piccolo = LuaScriptLibrary.getScriptById('concert_piccolo');
      expect(piccolo, isNotNull);

      final eatCode = piccolo!.eatCode;
      expect(EatScriptEngine.isEatScript(eatCode), isTrue);
      expect(eatCode.contains('def init():'), isTrue);
      expect(eatCode.contains('eat.param("BreathPressure"'), isTrue);
      expect(eatCode.contains('def gui():'), isTrue);

      final compiled = EatScriptEngine.compile(eatCode);
      expect(compiled.isSuccess, isTrue);
      expect(compiled.params.isNotEmpty, isTrue);
      expect(compiled.params.any((p) => p.name == 'BreathPressure'), isTrue);
      expect(compiled.guiLayout, isNotNull);
    });

    test('migrateAllScriptsToEatscript automatically transpiles all legacy Lua scripts across DawState', () {
      final state = DawState();
      final track = state.activeTrack;
      // Inject legacy Lua code into track, fx, midiFx, and clip
      track.luaScriptCode = '''
function init()
  eat.param("Pitch", 100.0, 500.0, 220.0)
end

function process(time, freq, note, params)
  return math.sin(time * 440.0)
end
''';
      expect(EatScriptEngine.isEatScript(track.luaScriptCode), isFalse);

      state.migrateAllScriptsToEatscript();

      expect(EatScriptEngine.isEatScript(track.luaScriptCode), isTrue);
      expect(track.luaScriptCode.contains('def init():'), isTrue);
      expect(track.luaScriptCode.contains('def process('), isTrue);
    });

    test('getScriptCodeForTarget transparently transpiles legacy Lua scripts to Eatscript', () {
      final state = DawState();
      final track = state.activeTrack;
      track.luaScriptCode = '''
function process(time, freq, note, params)
  return math.sin(time * 200.0)
end
''';
      final target = state.activeScriptTarget;
      final retrievedCode = state.getScriptCodeForTarget(target);

      expect(EatScriptEngine.isEatScript(retrievedCode), isTrue);
      expect(retrievedCode.contains('def process('), isTrue);
      expect(EatScriptEngine.isEatScript(track.luaScriptCode), isTrue);
    });

    test('loadFromEatsLua converts legacy Lua song projects to Eatscript in memory', () {
      final state = DawState();
      state.loadFromEatsLua(DefaultSong.midnightBitesLua);

      for (final track in state.activePattern.tracks) {
        if (track.luaScriptCode.isNotEmpty) {
          expect(EatScriptEngine.isEatScript(track.luaScriptCode), isTrue,
              reason: 'Track "${track.name}" should have been converted to Eatscript');
          expect(track.luaScriptCode.contains('def process('), isTrue);
        }
      }
    });

    test('convertAllLegacyProjectsOnDisk migrates saved Lua projects to Eatscript format', () async {
      EatsStorageHelper.setTestMode(true);
      final state = DawState();

      // Save a legacy project file
      await EatsStorageHelper.saveProjectFile('LegacyProject', DefaultSong.midnightBitesLua);

      final migrated = await state.convertAllLegacyProjectsOnDisk();
      expect(migrated, greaterThanOrEqualTo(1));

      final saved = await EatsStorageHelper.listSavedProjects();
      expect(saved.any((p) => p.name == 'LegacyProject'), isTrue);
    });
  });
}
