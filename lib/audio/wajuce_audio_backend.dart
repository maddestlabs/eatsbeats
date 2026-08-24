import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wajuce/wajuce.dart';

import '../utils/platform_env_helper.dart';

import '../models/track_model.dart';
import 'convolver_engine.dart';
import 'procedural_ir_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TrackChannelStrip
//  Persistent audio graph branch per track:
//  [inputBus] -> [FX Rack Nodes] -> [volumeNode] -> [pannerNode] -> [masterGain]
// ─────────────────────────────────────────────────────────────────────────────
class TrackChannelStrip {
  final String trackId;
  final WAContext ctx;
  final WANode destination;

  late final WAGainNode inputBus;
  late final WAGainNode volumeNode;
  late final WAStereoPannerNode pannerNode;

  final List<WANode> _fxNodes = [];
  int _lastFxHash = 0;

  TrackChannelStrip({
    required this.trackId,
    required this.ctx,
    required this.destination,
  }) {
    inputBus = ctx.createGain()..gain.value = 1.0;
    volumeNode = ctx.createGain()..gain.value = 1.0;
    pannerNode = ctx.createStereoPanner()..pan.value = 0.0;

    inputBus.connect(volumeNode);
    volumeNode.connect(pannerNode);
    pannerNode.connect(destination);
  }

  void update({
    required double volume,
    required double pan,
    required List<FXInsert> fxRack,
    required Map<String, WABuffer?> irCache,
    required Future<WABuffer?> Function(String) loadIrAsync,
  }) {
    volumeNode.gain.value = volume.clamp(0.0, 1.5);
    pannerNode.pan.value = pan.clamp(-1.0, 1.0);

    final currentFxHash = _computeFxHash(fxRack);
    if (currentFxHash != _lastFxHash) {
      _rebuildFxChain(fxRack, irCache, loadIrAsync);
      _lastFxHash = currentFxHash;
    }
  }

  void setTargetParam(String targetId, double value) {
    final lower = targetId.toLowerCase();
    if (lower.contains('volume')) {
      volumeNode.gain.value = value.clamp(0.0, 1.5);
    } else if (lower.contains('pan')) {
      pannerNode.pan.value = value.clamp(-1.0, 1.0);
    } else if (lower.contains('cutoff')) {
      for (final node in _fxNodes) {
        if (node is WABiquadFilterNode) {
          node.frequency.value = value.clamp(20.0, 20000.0);
        }
      }
    } else if (lower.contains('resonance')) {
      for (final node in _fxNodes) {
        if (node is WABiquadFilterNode) {
          node.Q.value = value.clamp(0.1, 20.0);
        }
      }
    }
  }

  void _rebuildFxChain(
    List<FXInsert> fxRack,
    Map<String, WABuffer?> irCache,
    Future<WABuffer?> Function(String) loadIrAsync,
  ) {
    // Disconnect old FX chain
    inputBus.disconnect();
    for (final node in _fxNodes) {
      node.disconnect();
      node.dispose();
    }
    _fxNodes.clear();

    WANode current = inputBus;
    for (final fx in fxRack) {
      if (!fx.enabled) continue;
      final mix = fx.mix.clamp(0.0, 1.0);
      if (mix <= 0.0) continue;

      switch (fx.type) {
        case FXType.distortion:
          current = _addWaveShaper(current, fx.params, mix);
        case FXType.bitcrusher:
          current = _addBitcrusher(current, fx.params, mix);
        case FXType.biquadFilter:
          final filter = ctx.createBiquadFilter();
          filter.type = WABiquadFilterType.lowpass;
          filter.frequency.value = (fx.params['Cutoff'] ?? 3500.0).clamp(20.0, 20000.0);
          filter.Q.value = (fx.params['Resonance'] ?? 1.5).clamp(0.1, 20.0);
          _fxNodes.add(filter);
          current.connect(filter);
          current = filter;
        case FXType.delay:
          current = _addDelay(current, fx.params, mix);
        case FXType.compressor:
          current = _addCompressor(current, fx.params, mix);
        case FXType.limiter:
          current = _addLimiter(current, fx.params, mix);
        case FXType.convolutionReverb:
          current = _addConvReverb(current, fx, mix, irCache, loadIrAsync);
        case FXType.luaFX:
          break;
      }
    }

    current.connect(volumeNode);
  }

  WANode _addWaveShaper(WANode input, Map<String, double> params, double mix) {
    final preGainVal = (params['Pre'] ?? (params['Drive'] ?? 1.0)).clamp(0.1, 10.0);
    final postGainVal = (params['Post'] ?? (params['OutGain'] ?? 1.0)).clamp(0.0, 4.0);
    final dcFilter = (params['DCFilter'] ?? 1.0) > 0.5;
    final curveType = (params['Shape'] ?? (params['Curve'] ?? 0.0)).toInt();
    final tension = (params['Tension'] ?? 0.0).clamp(-1.0, 1.0);

    final preGain = ctx.createGain()..gain.value = preGainVal;
    final postGain = ctx.createGain()..gain.value = postGainVal;
    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildCustomWaveShaperCurve(curveType, tension);
    shaper.oversample = kIsWeb ? WAOverSampleType.x4 : WAOverSampleType.x2;
    _fxNodes.addAll([preGain, shaper, postGain]);

    input.connect(preGain);
    preGain.connect(shaper);
    WANode wetChain = shaper;

    if (dcFilter) {
      final dcHighpass = ctx.createBiquadFilter()
        ..type = WABiquadFilterType.highpass
        ..frequency.value = 15.0
        ..Q.value = 0.707;
      _fxNodes.add(dcHighpass);
      shaper.connect(dcHighpass);
      wetChain = dcHighpass;
    }

    wetChain.connect(postGain);

    if (mix >= 0.99 && postGainVal == 1.0 && preGainVal == 1.0 && !dcFilter) {
      return postGain;
    }

    final bus = ctx.createGain();
    final dry = ctx.createGain()..gain.value = (1.0 - mix).clamp(0.0, 1.0);
    final wet = ctx.createGain()..gain.value = mix.clamp(0.0, 1.0);
    _fxNodes.addAll([bus, dry, wet]);

    input.connect(dry);
    dry.connect(bus);
    postGain.connect(wet);
    wet.connect(bus);
    return bus;
  }

  WANode _addCompressor(WANode input, Map<String, double> params, double mix) {
    final threshDb = (params['Threshold'] ?? -18.0).clamp(-60.0, 0.0);
    final ratio = (params['Ratio'] ?? 4.0).clamp(1.0, 20.0);
    final kneeDb = (params['Knee'] ?? 12.0).clamp(0.0, 40.0);

    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildCompressorCurve(threshDb, ratio, kneeDb);
    shaper.oversample = kIsWeb ? WAOverSampleType.x4 : WAOverSampleType.x2;
    _fxNodes.add(shaper);

    if (mix >= 0.98) {
      input.connect(shaper);
      return shaper;
    }
    final bus = ctx.createGain();
    final dry = ctx.createGain()..gain.value = 1.0 - mix;
    final wet = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dry, wet]);

    input.connect(dry)..connect(bus);
    input.connect(shaper)..connect(wet)..connect(bus);
    return bus;
  }

  WANode _addLimiter(WANode input, Map<String, double> params, double mix) {
    final threshDb = (params['Threshold'] ?? -1.0).clamp(-24.0, 0.0);
    final ceilingDb = (params['Ceiling'] ?? -0.1).clamp(-12.0, 0.0);

    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildLimiterCurve(threshDb, ceilingDb);
    shaper.oversample = kIsWeb ? WAOverSampleType.x4 : WAOverSampleType.x2;
    _fxNodes.add(shaper);

    if (mix >= 0.98) {
      input.connect(shaper);
      return shaper;
    }
    final bus = ctx.createGain();
    final dry = ctx.createGain()..gain.value = 1.0 - mix;
    final wet = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dry, wet]);

    input.connect(dry)..connect(bus);
    input.connect(shaper)..connect(wet)..connect(bus);
    return bus;
  }

  WANode _addBitcrusher(WANode input, Map<String, double> params, double mix) {
    final bits = (params['Bits'] ?? 8.0).clamp(1.0, 16.0);
    final drive = (params['Drive'] ?? 1.0).clamp(0.1, 4.0);
    final downsample = (params['Downsample'] ?? 1.0).clamp(1.0, 32.0);

    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildBitcrusherCurve(bits, downsample);
    shaper.oversample = WAOverSampleType.none;
    _fxNodes.add(shaper);

    WANode source = input;
    if (drive != 1.0) {
      final driveGain = ctx.createGain()..gain.value = drive;
      _fxNodes.add(driveGain);
      input.connect(driveGain);
      source = driveGain;
    }

    source.connect(shaper);

    if (mix >= 0.98 && drive == 1.0) {
      return shaper;
    }
    final bus = ctx.createGain();
    final dry = ctx.createGain()..gain.value = 1.0 - mix;
    final wet = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dry, wet]);

    input.connect(dry)..connect(bus);
    shaper.connect(wet)..connect(bus);
    return bus;
  }

  WANode _addDelay(WANode input, Map<String, double> params, double mix) {
    final timeMs = (params['TimeMs'] ?? 250.0).clamp(10.0, 1000.0);
    final feedback = (params['Feedback'] ?? 0.4).clamp(0.0, 0.95);
    final bus = ctx.createGain();
    final delNode = ctx.createDelay(2.0)..delayTime.value = timeMs / 1000.0;
    final fbGain = ctx.createGain()..gain.value = feedback;
    final dryGain = ctx.createGain()..gain.value = 1.0 - mix;
    final wetGain = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, delNode, fbGain, dryGain, wetGain]);

    delNode.connect(fbGain);
    fbGain.connect(delNode);
    input.connect(dryGain);
    dryGain.connect(bus);
    input.connect(delNode);
    delNode.connect(wetGain);
    wetGain.connect(bus);
    return bus;
  }

  WANode _addConvReverb(
    WANode input,
    FXInsert fx,
    double mix,
    Map<String, WABuffer?> irCache,
    Future<WABuffer?> Function(String) loadIrAsync,
  ) {
    final irName = fx.irSampleName ?? 'Great Hall';
    final isCab = (fx.presetId == 'cab_designer') ||
        (fx.name.toLowerCase().contains('cab')) ||
        (fx.params['isCabinet'] == 1.0) ||
        (irName.toLowerCase().contains('stack')) ||
        (irName.toLowerCase().contains('celestion')) ||
        (irName.toLowerCase().contains('tweed')) ||
        (irName.toLowerCase().contains('fridge')) ||
        (irName.toLowerCase().contains('radio')) ||
        (ProceduralIRGenerator.presets[irName]?.isCabinetMode ?? false);

    // Disable Web Audio's auto-normalization on cabinets to preserve physical frequency/resonance curves
    final convolver = ctx.createConvolver()..normalize = !isCab;
    _fxNodes.add(convolver);

    // Retrieve or construct WABuffer synchronously from ConvolverEngine memory
    var cached = irCache[irName];
    if (cached == null) {
      final samples = ConvolverEngine.instance.getIrSample(irName);
      if (samples != null && samples.isNotEmpty) {
        Float32List irData;
        if (!kIsWeb && samples.length > 2048) {
          irData = Float32List(2048);
          for (int i = 0; i < 2048; i++) {
            final fade = 1.0 - (i / 2048.0);
            irData[i] = (samples[i] * fade).toDouble();
          }
        } else {
          irData = Float32List.fromList(samples);
        }
        cached = WABuffer(
          numberOfChannels: 1,
          length: irData.length,
          sampleRate: 44100,
          channels: [irData],
        );
        irCache[irName] = cached;
      }
    }

    if (cached != null) {
      convolver.buffer = cached;
    } else {
      loadIrAsync(irName).then((wabuf) {
        if (wabuf != null) convolver.buffer = wabuf;
      });
    }

    final dryLevel = fx.params['DryLevel'] ?? (isCab ? 0.0 : 1.0);
    final wetLevel = fx.params['WetLevel'] ?? (isCab ? 1.0 : 0.5);

    final bus = ctx.createGain();
    final dryGain = ctx.createGain()..gain.value = (dryLevel * (1.0 - (isCab ? 1.0 - (1.0 - mix) : mix * 0.5))).clamp(0.0, 2.0);
    final wetGain = ctx.createGain()..gain.value = (wetLevel * (isCab ? 1.0 : mix * 2.0)).clamp(0.0, 2.0);
    _fxNodes.addAll([bus, dryGain, wetGain]);

    input.connect(dryGain);
    dryGain.connect(bus);

    WANode wetSource = convolver;

    final highCut = fx.params['HighCut'];
    if (highCut != null && highCut < 19000.0) {
      final filter = ctx.createBiquadFilter();
      filter.type = WABiquadFilterType.lowpass;
      filter.frequency.value = highCut.clamp(100.0, 20000.0);
      _fxNodes.add(filter);
      convolver.connect(filter);
      wetSource = filter;
    }

    // On Native desktop for non-cabinet spaces:
    // Add lightweight prime-spaced diffuser feedback tail for medium-to-large spaces (RT60 > 0.70s).
    // Small rooms and booths (RT60 <= 0.70s) already fit entirely into the 2048-sample pristine FIR!
    if (!kIsWeb && !isCab) {
      final presetRt60 = ProceduralIRGenerator.presets[irName]?.rt60;
      final rt60 = (fx.params['RT60'] ?? (presetRt60 ?? (irName.toLowerCase().contains('cathedral') ? 3.8 : (irName.toLowerCase().contains('hall') ? 1.6 : (irName.toLowerCase().contains('plate') ? 1.5 : 1.1))))).clamp(0.1, 5.0);
      final damping = (fx.params['Damping'] ?? (ProceduralIRGenerator.presets[irName]?.damping ?? 0.35)).clamp(0.0, 1.0);

      if (rt60 > 0.70) {
        // Tail injection scales smoothly with space size:
        // rt60 = 0.8s -> tailMix = 0.08
        // rt60 = 1.6s (Great Hall) -> tailMix = 0.35
        // rt60 = 3.8s (Cathedral) -> tailMix = 0.70
        final tailMix = ((rt60 - 0.70) / 4.0).clamp(0.05, 0.70);
        final tailBus = ctx.createGain()..gain.value = 1.0 - (tailMix * 0.5);
        wetSource.connect(tailBus);

        final tailWet = ctx.createGain()..gain.value = tailMix;
        final fb = math.exp(-6.907 * 0.039 / rt60).clamp(0.1, 0.93);
        final dampCutoff = (16000.0 * (1.0 - damping * 0.75)).clamp(800.0, 16000.0);

        final delays = [0.027, 0.039, 0.053];
        for (int d = 0; d < delays.length; d++) {
          final del = ctx.createDelay(1.0)..delayTime.value = delays[d];
          final fbg = ctx.createGain()..gain.value = fb;
          final dampFilter = ctx.createBiquadFilter()
            ..type = WABiquadFilterType.lowpass
            ..frequency.value = dampCutoff;

          _fxNodes.addAll([del, fbg, dampFilter]);

          wetSource.connect(del);
          del.connect(dampFilter);
          dampFilter.connect(fbg);
          fbg.connect(del);
          del.connect(tailWet);
        }
        tailWet.connect(tailBus);
        _fxNodes.addAll([tailBus, tailWet]);
        wetSource = tailBus;
      }
    }

    input.connect(convolver);
    wetSource.connect(wetGain);
    wetGain.connect(bus);
    return bus;
  }

  static int _computeFxHash(List<FXInsert> fxRack) {
    int h = 0;
    for (final fx in fxRack) {
      if (!fx.enabled) continue;
      h = (h * 31) ^ fx.type.index;
      h = (h * 31) ^ (fx.mix * 100).round();
      for (final e in fx.params.entries) {
        h = (h * 31) ^ e.key.hashCode ^ (e.value * 100).round();
      }
      if (fx.irSampleName != null) {
        h = (h * 31) ^ fx.irSampleName.hashCode;
      }
    }
    return h;
  }

  void dispose() {
    inputBus.disconnect();
    volumeNode.disconnect();
    pannerNode.disconnect();
    for (final node in _fxNodes) {
      node.disconnect();
      node.dispose();
    }
    _fxNodes.clear();
    inputBus.dispose();
    volumeNode.dispose();
    pannerNode.dispose();
  }

  static Float32List _buildDriveCurve(double drive) {
    const n = 256;
    final curve = Float32List(n);
    final k = 1.0 + drive * 19.0;
    for (int i = 0; i < n; i++) {
      final x = (2.0 * i / (n - 1)) - 1.0;
      curve[i] = _tanhF(x * k) / _tanhF(k);
    }
    return curve;
  }

  static Float32List _buildCompressorCurve(double threshDb, double ratio, double kneeDb) {
    const n = 512;
    final curve = Float32List(n);
    for (int i = 0; i < n; i++) {
      final x = (2.0 * i / (n - 1)) - 1.0;
      final xAbs = x.abs();
      if (xAbs < 1e-5) {
        curve[i] = 0.0;
        continue;
      }
      final xDb = 20.0 * (math.log(xAbs) / math.ln10);
      double yDb;
      if (kneeDb <= 0.001) {
        yDb = xDb <= threshDb ? xDb : threshDb + (xDb - threshDb) / ratio;
      } else {
        final halfKnee = kneeDb / 2.0;
        if (xDb <= threshDb - halfKnee) {
          yDb = xDb;
        } else if (xDb >= threshDb + halfKnee) {
          yDb = threshDb + (xDb - threshDb) / ratio;
        } else {
          final dx = xDb - threshDb + halfKnee;
          yDb = xDb + ((1.0 / ratio) - 1.0) * (dx * dx) / (2.0 * kneeDb);
        }
      }
      final yLin = math.pow(10.0, yDb / 20.0).toDouble();
      curve[i] = (x < 0 ? -yLin : yLin).clamp(-1.0, 1.0);
    }
    return curve;
  }

  static Float32List _buildLimiterCurve(double threshDb, double ceilingDb) {
    const n = 512;
    final curve = Float32List(n);
    final ceilingLin = math.pow(10.0, ceilingDb / 20.0).toDouble().clamp(0.01, 1.0);
    final threshLin = math.pow(10.0, threshDb / 20.0).toDouble().clamp(0.001, ceilingLin);
    final range = math.max(0.001, ceilingLin - threshLin);

    for (int i = 0; i < n; i++) {
      final x = (2.0 * i / (n - 1)) - 1.0;
      final xAbs = x.abs();
      if (xAbs <= threshLin) {
        curve[i] = x;
      } else {
        final d = xAbs - threshLin;
        final yAbs = threshLin + range * _tanhF(d / range);
        curve[i] = (x < 0 ? -yAbs : yAbs).clamp(-ceilingLin, ceilingLin);
      }
    }
    return curve;
  }

  static Float32List _buildCustomWaveShaperCurve(int shape, double tension) {
    const n = 512;
    final curve = Float32List(n);
    for (int i = 0; i < n; i++) {
      final x = (2.0 * i / (n - 1)) - 1.0;
      double y = x;
      switch (shape) {
        case 0: // Soft S-Curve / Tanh (FL Studio WaveShaper)
          final k = 1.0 + (tension + 1.0) * 3.0;
          y = _tanhF(x * k) / _tanhF(k);
        case 1: // Asymmetric Tube Warmth
          if (x > 0) {
            y = 1.0 - math.exp(-x * (2.0 + tension * 1.5));
          } else {
            y = -(1.0 - math.exp(x * (1.2 - tension * 0.5))) * 0.85;
          }
        case 2: // Sine Wavefold Distortion
          y = math.sin(x * math.pi * (1.0 + (tension + 1.0) * 0.7));
        case 3: // Angry 1 (Kilohearts multi-fold)
          final folded = (x * (2.0 + tension * 1.5)).abs() % 2.0;
          y = (folded > 1.0 ? 2.0 - folded : folded) * 2.0 - 1.0;
          if (x < 0) y = -y;
        case 4: // Angry 2 (Extreme wavefold crunch)
          final fold2 = math.sin(x * math.pi * 2.0 * (1.2 + tension));
          y = _tanhF(fold2 * 2.5);
        default:
          y = _tanhF(x * 2.0);
      }
      curve[i] = y.clamp(-1.0, 1.0);
    }
    return curve;
  }

  static Float32List _buildBitcrusherCurve(double bits, double downsample) {
    const n = 1024;
    final curve = Float32List(n);
    final b = bits.clamp(1.0, 16.0);
    final steps = math.pow(2.0, b - 1.0).toDouble();
    for (int i = 0; i < n; i++) {
      final x = (2.0 * i / (n - 1)) - 1.0;
      final quantized = (x * steps).roundToDouble() / steps;
      curve[i] = quantized.clamp(-1.0, 1.0);
    }
    return curve;
  }

  static double _tanhF(double x) {
    if (x > 3) return 1.0;
    if (x < -3) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WajuceAudioBackend
// ─────────────────────────────────────────────────────────────────────────────
class WajuceAudioBackend {
  WAContext? _ctx;
  WAGainNode? _masterInputBus;
  TrackChannelStrip? _masterStrip;
  WAGainNode? _masterGain;
  WAAnalyserNode? _analyser;

  // Persistent channel strips per track (0 node accumulation!)
  final Map<String, TrackChannelStrip> _channelStrips = {};

  // Per-track active source nodes (for monophonic stop)
  final Map<String, WABufferSourceNode> _activeSources = {};

  // WABuffer cache – reuse sample data between note-on events
  final Map<String, WABuffer> _bufferCache = {};

  // Decoded IR buffer cache for ConvolverNode
  final Map<String, WABuffer?> _irCache = {};
  final Map<String, Future<WABuffer?>> _irPending = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  late final Future<void> _readyFuture;

  double get currentTime => _ctx?.currentTime ?? 0.0;

  // ── Init ───────────────────────────────────────────────────────────────────

  WajuceAudioBackend() {
    _readyFuture = _initialize();
  }

  Future<void> get ready => _readyFuture;

  static bool get isTestEnvironment => PlatformEnvHelper.isFlutterTest;

  Future<void> _initialize() async {
    if (isTestEnvironment) {
      _initialized = true;
      return;
    }
    try {
      // Optimal configuration: Standardize 44.1 kHz sample rate across all platforms
      // to match internal synth/soundfont/sampler/Lua buffer generation and eliminate real-time
      // resampling overhead in iPlug2. Use 512 buffer size for crisp, low-latency audio response.
      final ctx = WAContext(sampleRate: 44100, bufferSize: 512);
      final masterInputBus = ctx.createGain();
      masterInputBus.gain.value = 1.0;
      final masterGain = ctx.createGain();
      masterGain.gain.value = 1.0;
      final masterStrip = TrackChannelStrip(
        trackId: 'master_bus',
        ctx: ctx,
        destination: masterGain,
      );
      masterInputBus.connect(masterStrip.inputBus);

      final analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      masterGain.connect(analyser);
      analyser.connect(ctx.destination);

      await ctx.resume();

      _ctx = ctx;
      _masterInputBus = masterInputBus;
      _masterStrip = masterStrip;
      _masterGain = masterGain;
      _analyser = analyser;
      _initialized = true;
    } catch (e) {
      debugPrint('[WajuceAudioBackend] init error: $e');
    }
  }

  void ensureContextRunning() {
    final ctx = _ctx;
    if (ctx != null && ctx.state == WAAudioContextState.suspended) {
      ctx.resume();
    }
  }

  void setMasterVolume(double volume) {
    _masterGain?.gain.value = volume.clamp(0.0, 1.5);
  }

  void updateMasterFx(List<FXInsert> masterFxRack) {
    _masterStrip?.update(
      volume: 1.0,
      pan: 0.0,
      fxRack: masterFxRack,
      irCache: _irCache,
      loadIrAsync: _loadIrAsync,
    );
  }

  void updateTrackFx(String trackId, List<FXInsert> fxRack, {double volume = 1.0, double pan = 0.0}) {
    final strip = _channelStrips[trackId];
    if (strip != null) {
      strip.update(
        volume: volume,
        pan: pan,
        fxRack: fxRack,
        irCache: _irCache,
        loadIrAsync: _loadIrAsync,
      );
    }
  }

  void invalidateIrCache([String? irName]) {
    if (irName != null) {
      _irCache.remove(irName);
      _irPending.remove(irName);
    } else {
      _irCache.clear();
      _irPending.clear();
    }
  }

  void setTrackParam(String trackId, String targetId, double value) {
    final strip = _channelStrips[trackId];
    if (strip != null) {
      strip.setTargetParam(targetId, value);
    }
  }

  void dispose() {
    for (final strip in _channelStrips.values) {
      strip.dispose();
    }
    _channelStrips.clear();
    _masterStrip?.dispose();
    _masterStrip = null;
    _masterInputBus?.dispose();
    _masterInputBus = null;
    _ctx?.close();
  }

  // ── Meters ─────────────────────────────────────────────────────────────────

  void updateMeters(Uint8List timeData, Function(double l, double r) setPeaks) {
    final analyser = _analyser;
    if (!_initialized || analyser == null) {
      setPeaks(0, 0);
      return;
    }
    try {
      analyser.getByteTimeDomainData(timeData);
      double sumL = 0, sumR = 0;
      for (int i = 0; i < timeData.length; i++) {
        final v = (timeData[i] - 128) / 128.0;
        if (i.isEven) {
          sumL += v * v;
        } else {
          sumR += v * v;
        }
      }
      final half = timeData.length / 2;
      setPeaks(
        (math.sqrt(sumL / half) * 2.5).clamp(0.0, 1.0),
        (math.sqrt(sumR / half) * 2.5).clamp(0.0, 1.0),
      );
    } catch (_) {}
  }

  // ── PCM Buffer Playback via Persistent Track Channel Strips ───────────────

  void playPcmBuffer(
    Float32List samples,
    double volume,
    double pan,
    double? scheduledTime,
    String? trackId,
    bool isMonophonic,
    bool isSlide,
    bool loop,
    List<FXInsert> fxRack, {
    String? bufferCacheKey,
  }) {
    final ctx = _ctx;
    final masterGain = _masterGain;
    if (!_initialized || ctx == null || masterGain == null) return;
    try {
      final effectiveTrackId = trackId ?? 'default_track';

      // 1. Stop previous note if monophonic
      if (isMonophonic) {
        final prev = _activeSources[effectiveTrackId];
        if (prev != null) {
          try {
            if (scheduledTime != null && scheduledTime > 0) {
              prev.stop(scheduledTime);
            } else {
              prev.stop();
            }
          } catch (_) {}
        }
      }

      // 2. Get or create persistent channel strip for this track
      final destination = _masterInputBus ?? masterGain;
      final strip = _channelStrips.putIfAbsent(
        effectiveTrackId,
        () => TrackChannelStrip(
          trackId: effectiveTrackId,
          ctx: ctx,
          destination: destination,
        ),
      );

      // 3. Update strip volume, pan, and FX rack
      strip.update(
        volume: volume,
        pan: pan,
        fxRack: fxRack,
        irCache: _irCache,
        loadIrAsync: _loadIrAsync,
      );

      // 4. Retrieve or create WABuffer
      WABuffer buf;
      if (bufferCacheKey != null && _bufferCache.containsKey(bufferCacheKey)) {
        buf = _bufferCache[bufferCacheKey]!;
      } else {
        buf = WABuffer(
          numberOfChannels: 1,
          length: samples.length,
          sampleRate: 44100,
          channels: [samples],
        );
        if (bufferCacheKey != null) {
          _bufferCache[bufferCacheKey] = buf;
        }
      }

      // 5. Create one-shot buffer source, connect to strip input, and start
      final source = ctx.createBufferSource();
      source.buffer = buf;
      if (loop) source.loop = true;

      _activeSources[effectiveTrackId] = source;

      // Connect source to the track's persistent input bus
      source.connect(strip.inputBus);

      // Auto-cleanup source when done
      source.onEnded = () {
        try {
          source.disconnect();
          source.dispose();
          if (_activeSources[effectiveTrackId] == source) {
            _activeSources.remove(effectiveTrackId);
          }
        } catch (_) {}
      };

      final startTime = (scheduledTime != null && scheduledTime > ctx.currentTime)
          ? scheduledTime
          : ctx.currentTime;
      source.start(startTime);
    } catch (e) {
      debugPrint('[WajuceAudioBackend] playPcmBuffer error: $e');
    }
  }

  void stopTrackNotes(String trackId) {
    try {
      final src = _activeSources.remove(trackId);
      if (src != null) {
        try {
          src.stop((_ctx?.currentTime ?? 0) + 0.03);
        } catch (_) {
          try { src.stop(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Panic: Stops all active audio source nodes immediately.
  void stopAllSound() {
    try {
      for (final src in _activeSources.values) {
        try {
          src.stop();
        } catch (_) {}
      }
      _activeSources.clear();
    } catch (_) {}
  }

  // ── IR loading ─────────────────────────────────────────────────────────────

  Future<WABuffer?> _loadIrAsync(String irName) {
    return _irPending.putIfAbsent(irName, () async {
      try {
        final samples = ConvolverEngine.instance.getIrSample(irName);
        if (samples == null || samples.isEmpty) return null;
        Float32List irData;
        if (!kIsWeb && samples.length > 2048) {
          irData = Float32List(2048);
          for (int i = 0; i < 2048; i++) {
            final fade = 1.0 - (i / 2048.0);
            irData[i] = (samples[i] * fade).toDouble();
          }
        } else {
          irData = Float32List.fromList(samples);
        }
        final wabuf = WABuffer(
          numberOfChannels: 1,
          length: irData.length,
          sampleRate: 44100,
          channels: [irData],
        );
        _irCache[irName] = wabuf;
        _irPending.remove(irName);
        return wabuf;
      } catch (_) {
        _irPending.remove(irName);
        return null;
      }
    });
  }

  Future<void> preloadIrSamples() async {
    for (final name in ConvolverEngine.instance.getAvailableIrNames()) {
      if (!_irCache.containsKey(name)) {
        await _loadIrAsync(name);
      }
    }
  }
}
