import 'dart:typed_data';

/// Execution context passed to graph nodes during buffer synthesis.
class GraphContext {
  final double sampleRate;
  final double durationSec;
  final int totalSamples;
  final double freq;
  final int midiNote;
  final double velocity;
  final bool isAccent;
  final bool isSlide;
  final int? targetMidiNote;
  final Map<String, double> params;

  // Articulations & MPE Dimensions
  final String? articulation;
  final double releaseVelocity;
  final List<List<double>>? pitchBendPoints;
  final List<List<double>>? pressurePoints;
  final List<List<double>>? timbrePoints;

  // Reusable scratch buffer pool (zero-allocation DSP)
  final List<Float32List> _scratchPool = [];
  int _scratchIdx = 0;

  Float32List acquireScratch(int length) {
    if (_scratchIdx < _scratchPool.length) {
      var buf = _scratchPool[_scratchIdx];
      if (buf.length < length) {
        buf = Float32List(length);
        _scratchPool[_scratchIdx] = buf;
      }
      _scratchIdx++;
      return buf;
    }
    final buf = Float32List(length);
    _scratchPool.add(buf);
    _scratchIdx++;
    return buf;
  }

  void releaseScratch() {
    if (_scratchIdx > 0) _scratchIdx--;
  }

  GraphContext({
    this.sampleRate = 44100.0,
    required this.durationSec,
    required this.freq,
    required this.midiNote,
    this.velocity = 1.0,
    this.isAccent = false,
    this.isSlide = false,
    this.targetMidiNote,
    this.params = const {},
    this.articulation,
    this.releaseVelocity = 0.5,
    this.pitchBendPoints,
    this.pressurePoints,
    this.timbrePoints,
    int? seed,
  })  : totalSamples = (sampleRate * durationSec).toInt().clamp(1, 441000),
        seed = seed ?? (DateTime.now().microsecondsSinceEpoch ^ (midiNote << 12));

  final int seed;
  final Map<String, double> _variedParamCache = {};

  bool isParamVarianceExempt(String name) {
    final lower = name.toLowerCase();
    if (params['Variance_$name'] == 0.0 ||
        params['no_variance_$name'] == 1.0 ||
        params['ignore_variance_$name'] == 1.0 ||
        params['allow_variance_$name'] == 0.0) {
      return true;
    }
    return lower == 'variance' ||
        lower == 'variation' ||
        lower == 'strike_drift' ||
        lower == 'strikedrift' ||
        lower == 'humanize' ||
        lower == 'dynamics' ||
        lower.contains('octave') ||
        lower.contains('waveform') ||
        lower.contains('subwaveform') ||
        lower.contains('preset') ||
        lower.contains('bank') ||
        lower.contains('program') ||
        lower.contains('algorithm') ||
        lower.contains('feedback') ||
        lower.contains('mode') ||
        lower.contains('type') ||
        lower.contains('channel') ||
        lower.contains('polyphony');
  }

  double getParam(String name, double defaultValue) {
    final baseVal = params[name] ?? defaultValue;
    final variance = (params['Variance'] ?? params['Variation'] ?? params['Humanize'] ?? params['StrikeDrift'] ?? 0.0).clamp(0.0, 1.0);
    if (variance <= 0.001 || isParamVarianceExempt(name)) {
      return baseVal;
    }

    if (_variedParamCache.containsKey(name)) {
      return _variedParamCache[name]!;
    }

    // Deterministic pseudo-random float in [-1.0, 1.0] derived from seed and param name hash
    int h = seed ^ name.hashCode;
    h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
    final double rnd = (h / 2147483647.0) * 2.0 - 1.0;

    final lower = name.toLowerCase();
    double scale = 0.08;
    if (lower.contains('pitch') || lower.contains('freq') || lower.contains('tune')) {
      scale = 0.03; // Micro-pitch deflection
    } else if (lower.contains('decay') || lower.contains('rel') || lower.contains('dwell') || lower.contains('time')) {
      scale = 0.12; // Dwell/damping variation
    } else if (lower.contains('fm') || lower.contains('depth') || lower.contains('click') || lower.contains('punch') || lower.contains('mod')) {
      scale = 0.15; // Strike/transient variation
    } else if (lower.contains('gain') || lower.contains('reso') || lower.contains('q')) {
      scale = 0.07;
    }

    final double effectiveAmount = variance * scale;
    final double offset = (baseVal.abs() > 1e-6) ? baseVal * effectiveAmount * rnd : effectiveAmount * rnd;
    final double variedVal = baseVal + offset;
    _variedParamCache[name] = variedVal;
    return variedVal;
  }

  static double interpolateCurve(List<List<double>>? points, double progress, double fallback) {
    if (points == null || points.isEmpty) return fallback;
    if (points.length == 1) return points[0].length > 1 ? points[0][1] : fallback;

    final p = progress.clamp(0.0, 1.0);
    if (p <= points.first[0]) return points.first.length > 1 ? points.first[1] : fallback;
    if (p >= points.last[0]) return points.last.length > 1 ? points.last[1] : fallback;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final t0 = p0[0];
      final t1 = p1[0];
      if (p >= t0 && p <= t1) {
        final span = t1 - t0;
        if (span <= 0.00001) return p1.length > 1 ? p1[1] : fallback;
        final norm = (p - t0) / span;
        final v0 = p0.length > 1 ? p0[1] : fallback;
        final v1 = p1.length > 1 ? p1[1] : fallback;
        return v0 + (v1 - v0) * norm;
      }
    }
    return points.last.length > 1 ? points.last[1] : fallback;
  }

  double getPitchBendAt(double progress) => interpolateCurve(pitchBendPoints, progress, 0.0);
  double getPressureAt(double progress) => interpolateCurve(pressurePoints, progress, velocity);
  double getTimbreAt(double progress) => interpolateCurve(timbrePoints, progress, 0.5);
}

/// Abstract base class for all audio & modulation graph nodes.
abstract class GraphNode {
  const GraphNode();

  /// Evaluates and fills [outBuffer] from sample 0 to [ctx.totalSamples].
  void process(GraphContext ctx, Float32List outBuffer);
}

/// A node that outputs a static constant value.
class ConstantNode extends GraphNode {
  final double value;
  const ConstantNode(this.value);

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    for (int i = 0; i < outBuffer.length; i++) {
      outBuffer[i] = value.toDouble();
    }
  }
}

/// A node that pulls a dynamic parameter by name from context.
class ParamRefNode extends GraphNode {
  final String paramName;
  final double defaultValue;

  const ParamRefNode(this.paramName, [this.defaultValue = 0.0]);

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final val = ctx.getParam(paramName, defaultValue);
    for (int i = 0; i < outBuffer.length; i++) {
      outBuffer[i] = val;
    }
  }
}
