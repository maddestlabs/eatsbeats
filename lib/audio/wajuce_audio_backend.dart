import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wajuce/wajuce.dart';

import '../models/track_model.dart';
import 'convolver_engine.dart';

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
          current = _addWaveShaper(current, fx.params['Drive'] ?? 0.5, mix);
        case FXType.bitcrusher:
          current = _addBitcrusher(current, fx.params['Bits'] ?? 8.0, mix);
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
        case FXType.convolutionReverb:
          current = _addConvReverb(current, fx, mix, irCache, loadIrAsync);
        case FXType.luaFX:
          break;
      }
    }

    current.connect(volumeNode);
  }

  WANode _addWaveShaper(WANode input, double rawDrive, double mix) {
    final drive = rawDrive <= 1.0 ? rawDrive : rawDrive / 20.0;
    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildDriveCurve(drive);
    shaper.oversample = WAOverSampleType.x4;
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

  WANode _addBitcrusher(WANode input, double bits, double mix) {
    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildBitcrusherCurve(bits.round().clamp(1, 16));
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
    final convolver = ctx.createConvolver()..normalize = true;
    _fxNodes.add(convolver);

    final cached = irCache[irName];
    if (cached != null) {
      convolver.buffer = cached;
    } else {
      loadIrAsync(irName).then((wabuf) {
        if (wabuf != null) convolver.buffer = wabuf;
      });
    }

    final bus = ctx.createGain();
    final dryGain = ctx.createGain()..gain.value = 1.0 - mix;
    final wetGain = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dryGain, wetGain]);

    input.connect(dryGain);
    dryGain.connect(bus);
    input.connect(convolver);
    convolver.connect(wetGain);
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

  static Float32List _buildBitcrusherCurve(int bits) {
    const n = 256;
    final curve = Float32List(n);
    final steps = math.pow(2.0, bits - 1).toDouble();
    for (int i = 0; i < n; i++) {
      final x = (2.0 * i / (n - 1)) - 1.0;
      curve[i] = (x * steps).roundToDouble() / steps;
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

  Future<void> _initialize() async {
    try {
      final ctx = WAContext(sampleRate: 44100, bufferSize: 512);
      final masterGain = ctx.createGain();
      masterGain.gain.value = 1.0;
      final analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      masterGain.connect(analyser);
      analyser.connect(ctx.destination);

      await ctx.resume();

      _ctx = ctx;
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

  void dispose() {
    for (final strip in _channelStrips.values) {
      strip.dispose();
    }
    _channelStrips.clear();
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
      final strip = _channelStrips.putIfAbsent(
        effectiveTrackId,
        () => TrackChannelStrip(
          trackId: effectiveTrackId,
          ctx: ctx,
          destination: masterGain,
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

  // ── IR loading ─────────────────────────────────────────────────────────────

  Future<WABuffer?> _loadIrAsync(String irName) {
    return _irPending.putIfAbsent(irName, () async {
      try {
        final samples = ConvolverEngine.instance.getIrSample(irName);
        if (samples == null || samples.isEmpty) return null;
        Float32List irData;
        if (!kIsWeb && samples.length > 2048) {
          // Native wajuce uses direct time-domain convolution (O(N) per sample).
          // Cap to 2048 samples with smooth exponential fade-out to ensure 0 audio thread stall.
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
