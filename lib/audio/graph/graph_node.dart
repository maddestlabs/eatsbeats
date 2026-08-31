import 'dart:math' as math;
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
  }) : totalSamples = (sampleRate * durationSec).toInt().clamp(1, 441000);

  double getParam(String name, double defaultValue) {
    return params[name] ?? defaultValue;
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
