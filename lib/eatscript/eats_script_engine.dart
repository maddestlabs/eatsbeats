import 'dart:typed_data';
import 'eats_gui_model.dart';
import 'eats_gui_parser.dart';
import '../models/automation_model.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../audio/time_context.dart';
import 'eats_api.dart';
import 'eats_ast.dart';
import 'eats_dsp_synthesizer.dart';
import 'eats_interpreter.dart';
import 'eats_lexer.dart';
import 'eats_param_model.dart';
import 'eats_parser.dart';
import 'eats_script_library.dart';
import 'eats_transpiler.dart';
import 'project_script_engine.dart';
import 'eats_synth_type.dart';
import 'eats_engine_registry.dart';

class EatScriptEngine {
  static final Map<String, EatCompilationResult> _cache = {};

  static void clearCache() => _cache.clear();

  /// Fast DSP synthesis of complete buffer for Eatscript instruments, drums, and physical models.
  static Float32List synthesizeBuffer({
    required String code,
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    int? fromMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
    EatSynthType? synthType,
  }) => EatDspSynthesizer.synthesizeBuffer(
    code: code,
    durationSec: durationSec,
    freq: freq,
    note: note,
    params: params,
    targetMidiNote: targetMidiNote,
    fromMidiNote: fromMidiNote,
    isSlide: isSlide,
    isAccent: isAccent,
    trackId: trackId,
    articulation: articulation,
    releaseVelocity: releaseVelocity,
    pitchBendPoints: pitchBendPoints,
    pressurePoints: pressurePoints,
    timbrePoints: timbrePoints,
    velocity: velocity,
    synthType: synthType,
  );

  /// Evaluates an automation lane procedurally (LFO, ramp, ADSR) or via keyframe interpolation.
  static double evaluateAutomation({
    required AutomationLane lane,
    required double step,
    TimeContext? timeCtx,
  }) => EatDspSynthesizer.evaluateAutomation(lane: lane, step: step, timeCtx: timeCtx);

  /// Resets voice DSP states.
  static void resetVoiceStates([String? trackId]) => EatDspSynthesizer.resetVoiceStates(trackId);

  /// Clears cached DSP buffer executors, synth/FX type detectors, and param regexes.
  static void clearDispatchCaches() => EatDspSynthesizer.clearDispatchCaches();

  /// Evaluates synth sample-by-sample.
  static double evaluateSynth({
    required String code,
    required double time,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    int sampleIndex = 0,
    int totalSamples = 1,
    EatSynthType? synthType,
  }) => EatDspSynthesizer.evaluateSynth(
    code: code,
    time: time,
    freq: freq,
    note: note,
    params: params,
    targetMidiNote: targetMidiNote,
    isSlide: isSlide,
    isAccent: isAccent,
    trackId: trackId,
    sampleIndex: sampleIndex,
    totalSamples: totalSamples,
    synthType: synthType,
  );

  /// Evaluates an ADSR envelope.
  static double evaluateAdsr(
    double time,
    double attack,
    double decay,
    double sustain,
    double release, [
    double duration = 0.4,
  ]) => EatDspSynthesizer.evaluateAdsr(time, attack, decay, sustain, release, duration);

  /// Determines whether a code block is Eatscript.
  static bool isEatScript(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    // Definite Eatscript markers: Python function definitions
    if (RegExp(r'^\s*def\s+\w+', multiLine: true).hasMatch(trimmed)) {
      return true;
    }

    // Reject legacy function/local markers
    final hasLegacyKeywords = RegExp(r'(?:^|[;\s])(?:function\s+[\w\.:]+|function\s*\(|local\s+\w+|then\s*$|elseif\s+|end\s*$|end[;\s])', multiLine: true).hasMatch(trimmed) ||
        trimmed.startsWith('--') ||
        trimmed.contains('\n--');
    if (hasLegacyKeywords) {
      return false;
    }

    return true;
  }

  /// Compiles Eatscript source code, performs static analysis,
  /// discovers declared `eat.param(...)` controls, and parses GUI layouts.
  static EatCompilationResult compile(
    String code, {
    Map<String, dynamic>? initialParamValues,
  }) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const EatCompilationResult(
        isSuccess: false,
        errorMessage: 'Script is empty.',
        params: [],
        scriptType: 'generator',
      );
    }

    final cached = _cache[code];
    if (cached != null) return cached;

    final isLegacy = !isEatScript(code);

    if (isLegacy) {
      final params = EatTranspiler.extractLegacyParams(code);
      final guiPanel = EatGuiParser.parseFromCode(code);
      final result = EatCompilationResult(
        isSuccess: true,
        errorMessage: 'Script parameters loaded. Active parameters: ${params.length}${guiPanel != null ? " [Custom Hardware GUI Active]" : ""}',
        params: params,
        scriptType: (code.contains('processSignal') || code.contains('StereoDelayFX') || code.contains('Bitcrusher')) ? 'effect' : 'synth',
        guiLayout: guiPanel,
      );
      if (_cache.length > 256) {
        _cache.remove(_cache.keys.first);
      }
      _cache[code] = result;
      return result;
    }

    try {
      final lexer = EatLexer(code);
      final tokens = lexer.tokenize();

      final parser = EatParser(tokens);
      final program = parser.parse();

      // Perform a dry-run evaluation with an isolated context to collect eat.param() and eat.gui()
      final dryContext = EatScriptContext(
        notes: [],
        paramValues: initialParamValues != null ? Map.from(initialParamValues) : {},
      );

      final interpreter = EatInterpreter(maxExecutionSteps: 50000);
      EatHostApi.install(interpreter, dryContext);

      // Run dry-run
      try {
        interpreter.interpret(program);

        // If the script defined an init() function, call it to register parameters
        if (interpreter.globals.has('init')) {
          final initFn = interpreter.globals.get('init', line: 1, column: 1);
          if (initFn is EatCallable) {
            initFn.call(interpreter, [], {}, line: 1, column: 1);
          }
        }

        // If the script defined a gui() function, call it to obtain GUI layout
        if (interpreter.globals.has('gui')) {
          final guiFn = interpreter.globals.get('gui', line: 1, column: 1);
          if (guiFn is EatCallable) {
            final res = guiFn.call(interpreter, [], {}, line: 1, column: 1);
            if (res is Map && dryContext.guiLayout == null) {
              dryContext.guiLayout = Map<String, dynamic>.from(res);
            }
          }
        }
      } catch (_) {
        // Dry-run might fail if user code relies on runtime data; params collected up to failure are preserved
      }

      // Check if GUI definition was declared via eat.gui(...) or fallback to parser
      EatScriptGuiPanelDef? guiPanel;
      if (dryContext.guiLayout != null) {
        guiPanel = _buildGuiPanelFromMap(dryContext.guiLayout!);
      } else {
        guiPanel = EatGuiParser.parseFromCode(code);
      }

      final detectedEngineId = dryContext.engineId ?? EatEngineRegistry.detectEngineId(code);

      final warnings = <String>[];

      // Diagnostic 1: Check engine ID validity if specified
      if (detectedEngineId != null && !EatEngineRegistry.isRegistered(detectedEngineId)) {
        final sampleEngines = EatEngineRegistry.allEngineIds.take(10).join(', ');
        warnings.add(
          "Unknown engine ID '$detectedEngineId'. Valid engines include: $sampleEngines... (see docs/api/03_dsp_node_catalog.md)",
        );
      }

      // Diagnostic 2: Check GUI widget parameters match declared parameters
      if (guiPanel != null) {
        final declaredParamNames = dryContext.params.map((p) => p.name.trim()).toSet();
        final guiParamNames = <String>{};
        _collectGuiParamNames(guiPanel.children, guiParamNames);

        for (final gp in guiParamNames) {
          if (!declaredParamNames.contains(gp)) {
            warnings.add(
              "GUI control references undeclared parameter '$gp'. (Declared parameters: ${declaredParamNames.isEmpty ? 'none' : declaredParamNames.join(', ')})",
            );
          }
        }
      }

      String scriptType = 'clip';
      if (detectedEngineId != null) {
        if (EatEngineRegistry.audioFxTypes.containsKey(detectedEngineId)) {
          scriptType = 'effect';
        } else if (EatEngineRegistry.specializedSynthTypes.containsKey(detectedEngineId) ||
            EatEngineRegistry.graphModels.containsKey(detectedEngineId)) {
          scriptType = 'synth';
        }
      } else if (code.contains('eat.add_note') || code.contains('euclidean') || code.contains('arpeggiate')) {
        scriptType = 'generator';
      } else if (code.contains('transpose') || code.contains('humanize') || code.contains('transform')) {
        scriptType = 'transformer';
      }

      String message = 'Compiled successfully (Eatscript Live Engine)! Active parameters: ${dryContext.params.length}';
      if (warnings.isNotEmpty) {
        message += '\n[Diagnostics / Warnings]:\n• ' + warnings.join('\n• ');
      }

      final result = EatCompilationResult(
        isSuccess: true,
        errorMessage: message,
        params: dryContext.params,
        scriptType: scriptType,
        guiLayout: guiPanel,
        program: program,
        engineId: detectedEngineId,
        warnings: warnings,
      );

      if (_cache.length > 256) {
        _cache.remove(_cache.keys.first);
      }
      _cache[code] = result;
      return result;
    } on EatLexerException catch (e) {
      return EatCompilationResult(
        isSuccess: false,
        errorMessage: 'Syntax Error (Lexer): ${e.message}',
        errorLine: e.line,
        errorColumn: e.column,
        params: [],
        scriptType: 'generator',
      );
    } on EatParserException catch (e) {
      return EatCompilationResult(
        isSuccess: false,
        errorMessage: 'Syntax Error (Parser): ${e.message}',
        errorLine: e.line,
        errorColumn: e.column,
        params: [],
        scriptType: 'generator',
      );
    } catch (e) {
      return EatCompilationResult(
        isSuccess: false,
        errorMessage: 'Compilation Error: ${e.toString()}',
        errorLine: 1,
        errorColumn: 1,
        params: [],
        scriptType: 'generator',
      );
    }
  }

  /// Executes an Eatscript clip script, taking base notes and returning transformed/generated notes.
  static List<Note> executeClipScript(
    String code,
    List<Note> baseNotes, {
    Map<String, dynamic>? paramValues,
    double tempo = 120.0,
    int keyRoot = 0,
    bool isMinor = false,
    TimeContext? timeContext,
  }) {
    final compResult = compile(code, initialParamValues: paramValues);
    if (!compResult.isSuccess || compResult.program == null) {
      return baseNotes;
    }

    final context = EatScriptContext(
      notes: baseNotes.map((n) => n.copyWith()).toList(),
      params: compResult.params,
      paramValues: paramValues != null ? Map.from(paramValues) : {},
      tempo: tempo,
      keyRoot: keyRoot,
      isMinor: isMinor,
      timeContext: timeContext,
    );

    final interpreter = EatInterpreter(maxExecutionSteps: 100000);
    EatHostApi.install(interpreter, context);

    try {
      interpreter.interpret(compResult.program!);

      final noteMaps = context.notes.map((n) => n.toJson()).toList();
      final tcMap = {
        'bpm': tempo,
        'song_key_root': keyRoot,
        'is_minor': isMinor,
      };

      // 1. Check `transform_notes(notes, params, time_context)`
      if (interpreter.globals.has('transform_notes')) {
        final fn = interpreter.globals.get('transform_notes', line: 1, column: 1);
        if (fn is EatCallable) {
          final res = fn.call(interpreter, [noteMaps, context.paramValues, tcMap], {}, line: 1, column: 1);
          final converted = _convertResultToNotes(res);
          if (converted.isNotEmpty) return converted;
        }
      }
      // 2. Check `transform(notes)`
      else if (interpreter.globals.has('transform')) {
        final fn = interpreter.globals.get('transform', line: 1, column: 1);
        if (fn is EatCallable) {
          final res = fn.call(interpreter, [noteMaps], {}, line: 1, column: 1);
          final converted = _convertResultToNotes(res);
          if (converted.isNotEmpty) return converted;
        }
      }
      // 3. Check `process(notes)`
      else if (interpreter.globals.has('process')) {
        final fn = interpreter.globals.get('process', line: 1, column: 1);
        if (fn is EatCallable) {
          final res = fn.call(interpreter, [noteMaps], {}, line: 1, column: 1);
          final converted = _convertResultToNotes(res);
          if (converted.isNotEmpty) return converted;
        }
      }

      return context.notes;
    } catch (e) {
      // Return base notes on runtime failure
      return baseNotes;
    }
  }

  static List<Note> _convertResultToNotes(dynamic res) {
    if (res is List) {
      final converted = <Note>[];
      for (final item in res) {
        if (item is Note) {
          converted.add(item);
        } else if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final pitch = ((m['pitch'] ?? 60) as num).toInt().clamp(0, 127);
          final start = ((m['start'] ?? m['startStep'] ?? 0.0) as num).toDouble().clamp(0.0, 1024.0);
          final dur = ((m['duration'] ?? m['durationSteps'] ?? 1.0) as num).toDouble().clamp(0.05, 1024.0);
          final vel = ((m['velocity'] ?? m['vel'] ?? 0.85) as num).toDouble().clamp(0.01, 1.0);
          final id = (m['id'] as String?) ?? 'eat_${DateTime.now().microsecondsSinceEpoch}_${converted.length}';
          converted.add(Note(id: id, pitch: pitch, startStep: start, durationSteps: dur, velocity: vel));
        }
      }
      return converted;
    }
    return [];
  }

  static EatScriptGuiPanelDef? _buildGuiPanelFromMap(Map<String, dynamic> map) {
    try {
      return EatGuiParser.parseFromMap(map);
    } catch (_) {
      return null;
    }
  }

  static void _collectGuiParamNames(List<EatScriptGuiNode> nodes, Set<String> out) {
    for (final node in nodes) {
      if (node.param != null && node.param!.trim().isNotEmpty) {
        out.add(node.param!.trim());
      }
      if (node.children.isNotEmpty) {
        _collectGuiParamNames(node.children, out);
      }
    }
  }

  /// Parses an Eatscript / Python dictionary file (e.g. `song = { ... }` or `{ ... }`) into a Map.
  static Map<String, dynamic> parseDataMap(String code) {
    try {
      final lexer = EatLexer(code);
      final tokens = lexer.tokenize();
      final parser = EatParser(tokens);
      final program = parser.parse();
      final interpreter = EatInterpreter(maxExecutionSteps: 300000);
      final lastResult = interpreter.interpret(program);

      if (interpreter.globals.has('song')) {
        final songVal = interpreter.globals.get('song', line: 1, column: 1);
        if (songVal is Map) return Map<String, dynamic>.from(songVal);
      }
      if (lastResult is Map) {
        return Map<String, dynamic>.from(lastResult);
      }
    } catch (_) {
      // Fallback
    }
    return {};
  }

  /// Executes an Eatscript Macro against [DawState] with the provided [params].
  static ProjectScriptResult executeMacro({
    required DawState dawState,
    required EatScriptDef script,
    Map<String, dynamic> params = const {},
  }) {
    final compResult = compile(script.code, initialParamValues: params);
    if (!compResult.isSuccess || compResult.program == null) {
      return ProjectScriptResult(
        isSuccess: false,
        message: 'Macro Compilation Error: ${compResult.errorMessage}',
      );
    }

    final context = EatScriptContext(
      notes: [],
      params: compResult.params,
      paramValues: Map.from(params),
      tempo: dawState.bpm,
      keyRoot: dawState.songKeyRoot,
      isMinor: dawState.isSongKeyMinor,
      dawState: dawState,
    );

    final initialTrackCount = dawState.activePattern.tracks.length;
    final initialNoteCount = dawState.activePattern.tracks.fold<int>(0, (sum, t) => sum + t.notes.length + t.clips.fold<int>(0, (cs, c) => cs + c.notes.length));
    final initialChordCount = dawState.chordTrack.length;

    final interpreter = EatInterpreter(maxExecutionSteps: 300000);
    EatHostApi.install(interpreter, context);

    try {
      interpreter.interpret(compResult.program!);

      dynamic macroReturn;
      // 1. Check `run(project, params)`
      if (interpreter.globals.has('run')) {
        final fn = interpreter.globals.get('run', line: 1, column: 1);
        if (fn is EatCallable) {
          final projectApi = interpreter.globals.get('project', line: 1, column: 1);
          macroReturn = fn.call(interpreter, [projectApi, context.paramValues], {}, line: 1, column: 1);
        }
      }
      // 2. Check `main()`
      else if (interpreter.globals.has('main')) {
        final fn = interpreter.globals.get('main', line: 1, column: 1);
        if (fn is EatCallable) {
          macroReturn = fn.call(interpreter, [], {}, line: 1, column: 1);
        }
      }

      final finalTrackCount = dawState.activePattern.tracks.length;
      final finalNoteCount = dawState.activePattern.tracks.fold<int>(0, (sum, t) => sum + t.notes.length + t.clips.fold<int>(0, (cs, c) => cs + c.notes.length));
      final finalChordCount = dawState.chordTrack.length;

      final affectedTracks = (finalTrackCount - initialTrackCount).abs();
      final affectedNotes = (finalNoteCount - initialNoteCount).abs();
      final affectedChords = (finalChordCount - initialChordCount).abs();

      String resultMessage = 'Macro executed successfully.';
      if (macroReturn is Map && macroReturn.containsKey('message')) {
        resultMessage = macroReturn['message'].toString();
      } else if (context.logs.isNotEmpty) {
        resultMessage = context.logs.join('; ');
      } else if (affectedTracks > 0 || affectedNotes > 0 || affectedChords > 0) {
        resultMessage = 'Macro completed: $affectedTracks track(s), $affectedNotes note(s), $affectedChords chord(s) modified.';
      }

      return ProjectScriptResult(
        isSuccess: true,
        message: resultMessage,
        affectedTracksCount: affectedTracks,
        affectedNotesCount: affectedNotes,
        affectedChordsCount: affectedChords,
        logs: List.unmodifiable(context.logs),
      );
    } catch (e) {
      return ProjectScriptResult(
        isSuccess: false,
        message: 'Macro Execution Error: ${e.toString()}',
      );
    }
  }
}
