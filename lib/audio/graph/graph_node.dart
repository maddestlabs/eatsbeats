import 'dart:typed_data';
import 'dart:math' as math;

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
  final Float32List? inputBuffer;

  // Articulations & MPE Dimensions
  final String? articulation;
  final double releaseVelocity;
  final List<List<double>>? pitchBendPoints;
  final List<List<double>>? pressurePoints;
  final List<List<double>>? timbrePoints;

  // Persistent reusable scratch buffer pool (zero-allocation DSP across notes)
  static final List<Float32List> _sharedScratchPool = [];
  int _scratchIdx = 0;

  Float32List acquireScratch(int length) {
    if (_scratchIdx < _sharedScratchPool.length) {
      var buf = _sharedScratchPool[_scratchIdx];
      if (buf.length < length) {
        buf = Float32List(length);
        _sharedScratchPool[_scratchIdx] = buf;
      }
      _scratchIdx++;
      return buf;
    }
    final buf = Float32List(length);
    _sharedScratchPool.add(buf);
    _scratchIdx++;
    return buf;
  }

  void releaseScratch() {
    if (_scratchIdx > 0) _scratchIdx--;
  }

  void resetScratch() {
    _scratchIdx = 0;
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
    this.inputBuffer,
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

/// A node representing incoming channel or bus audio stream for audio effect chains.
class AudioInputNode extends GraphNode {
  const AudioInputNode();

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final inBuf = ctx.inputBuffer;
    if (inBuf != null) {
      final len = math.min(inBuf.length, outBuffer.length);
      outBuffer.setRange(0, len, inBuf);
      if (len < outBuffer.length) {
        outBuffer.fillRange(len, outBuffer.length, 0.0);
      }
    } else {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
    }
  }
}

/// Pitch, gate, and velocity CV extractor for MIDI-to-modular signal pipelines.
class MidiToCvNode extends GraphNode {
  final String outputMode; // 'pitch', 'gate', 'velocity'

  const MidiToCvNode({this.outputMode = 'pitch'});

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    switch (outputMode.toLowerCase()) {
      case 'gate':
        outBuffer.fillRange(0, outBuffer.length, 1.0);
        break;
      case 'velocity':
      case 'vel':
        final v = ctx.velocity;
        outBuffer.fillRange(0, outBuffer.length, v);
        break;
      case 'pitch':
      default:
        final f = ctx.freq > 0 ? ctx.freq : 440.0;
        outBuffer.fillRange(0, outBuffer.length, f);
        break;
    }
  }
}

/// Bitcrusher & Sample-Rate Decimator Node.
class BitcrusherNode extends GraphNode {
  final GraphNode input;
  final double bits;
  final String? bitsParam;
  final double downsample;
  final String? downsampleParam;
  final double mix;
  final String? mixParam;

  const BitcrusherNode({
    required this.input,
    this.bits = 8.0,
    this.bitsParam,
    this.downsample = 1.0,
    this.downsampleParam,
    this.mix = 1.0,
    this.mixParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double b = (bitsParam != null ? ctx.getParam(bitsParam!, bits) : bits).clamp(1.0, 16.0);
    final double ds = (downsampleParam != null ? ctx.getParam(downsampleParam!, downsample) : downsample).clamp(1.0, 64.0);
    final double m = (mixParam != null ? ctx.getParam(mixParam!, mix) : mix).clamp(0.0, 1.0);

    final double steps = math.pow(2.0, b).toDouble();
    final int stepInterval = ds.toInt().clamp(1, 64);

    double heldSample = 0.0;
    for (int i = 0; i < outBuffer.length; i++) {
      final double inSample = outBuffer[i];
      if (i % stepInterval == 0) {
        heldSample = (inSample * steps).roundToDouble() / steps;
      }
      outBuffer[i] = inSample * (1.0 - m) + heldSample * m;
    }
  }
}

/// Stereo/Mono Chorus & Modulated Delay Node.
class ChorusNode extends GraphNode {
  final GraphNode input;
  final double rateHz;
  final String? rateParam;
  final double depth;
  final String? depthParam;
  final double feedback;
  final String? feedbackParam;
  final double mix;
  final String? mixParam;

  const ChorusNode({
    required this.input,
    this.rateHz = 0.8,
    this.rateParam,
    this.depth = 0.65,
    this.depthParam,
    this.feedback = 0.2,
    this.feedbackParam,
    this.mix = 0.5,
    this.mixParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = ctx.acquireScratch(len);
    input.process(ctx, inBuf);

    final double rate = (rateParam != null ? ctx.getParam(rateParam!, rateHz) : rateHz).clamp(0.05, 10.0);
    final double d = (depthParam != null ? ctx.getParam(depthParam!, depth) : depth).clamp(0.0, 1.0);
    final double fb = (feedbackParam != null ? ctx.getParam(feedbackParam!, feedback) : feedback).clamp(0.0, 0.9);
    final double m = (mixParam != null ? ctx.getParam(mixParam!, mix) : mix).clamp(0.0, 1.0);
    final double sr = ctx.sampleRate;

    final int maxDelaySamples = (0.035 * sr).toInt() + 16;
    final delayLine = Float32List(maxDelaySamples);
    int writeIdx = 0;
    const double twoPi = 2.0 * math.pi;

    for (int i = 0; i < len; i++) {
      final double inSample = inBuf[i];
      final double t = i / sr;
      final double lfo = math.sin(twoPi * rate * t);
      final double delaySec = 0.005 + (0.015 * (lfo * 0.5 + 0.5) * d);
      final double delaySamples = (delaySec * sr).clamp(1.0, maxDelaySamples - 2.0);

      final double readPos = writeIdx - delaySamples;
      double rIdx = readPos >= 0 ? readPos : (readPos + maxDelaySamples);
      while (rIdx >= maxDelaySamples) {
        rIdx -= maxDelaySamples;
      }
      while (rIdx < 0) {
        rIdx += maxDelaySamples;
      }

      final int i0 = rIdx.toInt() % maxDelaySamples;
      final int i1 = (i0 + 1) % maxDelaySamples;
      final double frac = rIdx - i0;
      final double wet = delayLine[i0] + frac * (delayLine[i1] - delayLine[i0]);

      delayLine[writeIdx] = inSample + wet * fb;
      writeIdx = (writeIdx + 1) % maxDelaySamples;

      outBuffer[i] = inSample * (1.0 - m) + wet * m;
    }
    ctx.releaseScratch();
  }
}


