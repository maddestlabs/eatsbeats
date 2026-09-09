import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/time_context.dart';
import '../models/automation_model.dart';
import 'eat_dsp_synthesizer.dart';
import 'eat_script_engine.dart';
import 'eat_param_model.dart';

export 'eat_param_model.dart';

// Backwards-compatibility alias
typedef LuaEngine = EatEngine;

class EatEngine {
  /// Evaluates a 4-stage ADSR envelope at [time] seconds.
  /// [attack]: Attack time in seconds (0.0 to N)
  /// [decay]: Decay time in seconds (0.0 to N)
  /// [sustain]: Sustain gain level (0.0 to 1.0)
  /// [release]: Release time in seconds (0.001 to N)
  /// [duration]: Note active gate duration before release phase (default 0.4s)
  static double evaluateAdsr(
    double time,
    double attack,
    double decay,
    double sustain,
    double release, [
    double duration = 0.4,
  ]) {
    final a = math.max(0.0, attack);
    final d = math.max(0.001, decay);
    final s = sustain.clamp(0.0, 1.0);
    final r = math.max(0.001, release);
    final gate = math.max(a + d, duration);

    if (time < a) {
      if (a <= 0.0001) return 1.0;
      return (time / a).clamp(0.0, 1.0);
    } else if (time < a + d) {
      final decayProgress = (time - a) / d;
      return 1.0 - (decayProgress * (1.0 - s));
    } else if (time < gate) {
      return s;
    } else {
      final releaseProgress = (time - gate) / r;
      return (s * math.max(0.0, 1.0 - releaseProgress)).clamp(0.0, 1.0);
    }
  }

  /// Evaluates a 2-stage Attack-Release envelope at [time] seconds.
  static double evaluateEnv(
    double time,
    double attack,
    double release, [
    double duration = 0.4,
  ]) {
    return evaluateAdsr(time, attack, 0.001, 1.0, release, duration);
  }

  /// Clears the compilation cache if needed.
  static void clearCompilationCache() {
    EatScriptEngine.clearCache();
  }

  static LuaCompilationResult compile(String code) {
    return EatScriptEngine.compile(code).toLuaCompilationResult();
  }

  /// Resets persistent DSP voice states for a given [trackId] or all tracks when loading/transitioning songs.
  static void resetVoiceStates([String? trackId]) => EatDspSynthesizer.resetVoiceStates(trackId);

  // Fast synthesis of complete buffer avoiding redundant per-sample parsing
  static Float32List synthesizeBuffer({
    required String code,
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) => EatDspSynthesizer.synthesizeBuffer(
    code: code,
    durationSec: durationSec,
    freq: freq,
    note: note,
    params: params,
    targetMidiNote: targetMidiNote,
    isSlide: isSlide,
    isAccent: isAccent,
    trackId: trackId,
    articulation: articulation,
    releaseVelocity: releaseVelocity,
    pitchBendPoints: pitchBendPoints,
    pressurePoints: pressurePoints,
    timbrePoints: timbrePoints,
    velocity: velocity,
  );

  // DSP Math & Synthesis Evaluator for custom synths and drum engines
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
  );

  /// Evaluates an automation lane at a specific step and time context.
  static double evaluateAutomation({
    required AutomationLane lane,
    required double step,
    TimeContext? timeCtx,
  }) => EatDspSynthesizer.evaluateAutomation(lane: lane, step: step, timeCtx: timeCtx);
}
