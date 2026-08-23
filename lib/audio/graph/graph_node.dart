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
  }) : totalSamples = (sampleRate * durationSec).toInt().clamp(1, 441000);

  double getParam(String name, double defaultValue) {
    return params[name] ?? defaultValue;
  }
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
