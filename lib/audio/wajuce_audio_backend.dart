import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wajuce/wajuce.dart';

import '../utils/platform_env_helper.dart';

import '../models/track_model.dart';
import 'convolver_engine.dart';
import 'procedural_ir_generator.dart';

class _FxNodeBinding {
  final FXInsert fx;
  final WANode outputNode;
  final WAGainNode? dryGainNode;
  final WAGainNode? wetGainNode;
  final WABiquadFilterNode? filterNode;
  final WABiquadFilterNode? hpFilterNode;
  final WABiquadFilterNode? lpFilterNode;
  final WABiquadFilterNode? headBumpFilterNode;
  final WADelayNode? delayNode;
  final WAGainNode? fbGainNode;
  final WAGainNode? preGainNode;
  final WAGainNode? postGainNode;
  final WAWaveShaperNode? shaperNode;
  final WAGainNode? noiseGainNode;
  final WAGainNode? hissGainNode;
  final WAGainNode? crackleGainNode;
  final WAGainNode? rumbleGainNode;

  _FxNodeBinding({
    required this.fx,
    required this.outputNode,
    this.dryGainNode,
    this.wetGainNode,
    this.filterNode,
    this.hpFilterNode,
    this.lpFilterNode,
    this.headBumpFilterNode,
    this.delayNode,
    this.fbGainNode,
    this.preGainNode,
    this.postGainNode,
    this.shaperNode,
    this.noiseGainNode,
    this.hissGainNode,
    this.crackleGainNode,
    this.rumbleGainNode,
  });

  void updateParams(FXInsert newFx) {
    final mix = newFx.mix.clamp(0.0, 1.0);
    final params = newFx.params;

    dryGainNode?.gain.value = (1.0 - mix).clamp(0.0, 1.0);
    wetGainNode?.gain.value = mix.clamp(0.0, 1.0);

    switch (newFx.type) {
      case FXType.biquadFilter:
        final cutoff = (params['Cutoff'] ?? 3500.0).clamp(20.0, 20000.0);
        final reso = (params['Resonance'] ?? 1.5).clamp(0.1, 20.0);
        filterNode?.frequency.value = cutoff;
        filterNode?.Q.value = reso;
        break;

      case FXType.delay:
        final timeMs = (params['TimeMs'] ?? 250.0).clamp(10.0, 1000.0);
        final fb = (params['Feedback'] ?? 0.4).clamp(0.0, 0.95);
        delayNode?.delayTime.value = timeMs / 1000.0;
        fbGainNode?.gain.value = fb;
        break;

      case FXType.bitcrusher:
        final bits = (params['Bits'] ?? 8.0).clamp(1.0, 16.0);
        final drive = (params['Drive'] ?? 1.0).clamp(0.1, 4.0);
        final downsample = (params['Downsample'] ?? 1.0).clamp(1.0, 32.0);
        preGainNode?.gain.value = drive;
        shaperNode?.curve = TrackChannelStrip._buildBitcrusherCurve(bits, downsample);
        break;

      case FXType.distortion:
        final preGainVal = (params['Pre'] ?? (params['Drive'] ?? 1.0)).clamp(0.1, 10.0);
        final postGainVal = (params['Post'] ?? (params['OutGain'] ?? 1.0)).clamp(0.0, 4.0);
        final curveType = (params['Shape'] ?? (params['Curve'] ?? 0.0)).toInt();
        final tension = (params['Tension'] ?? 0.0).clamp(-1.0, 1.0);
        preGainNode?.gain.value = preGainVal;
        postGainNode?.gain.value = postGainVal;
        shaperNode?.curve = TrackChannelStrip._buildCustomWaveShaperCurve(curveType, tension);
        break;

      case FXType.compressor:
        final threshDb = (params['Threshold'] ?? -18.0).clamp(-60.0, 0.0);
        final ratio = (params['Ratio'] ?? 4.0).clamp(1.0, 20.0);
        final kneeDb = (params['Knee'] ?? 12.0).clamp(0.0, 40.0);
        shaperNode?.curve = TrackChannelStrip._buildCompressorCurve(threshDb, ratio, kneeDb);
        break;

      case FXType.limiter:
        final threshDb = (params['Threshold'] ?? -1.0).clamp(-24.0, 0.0);
        final ceilingDb = (params['Ceiling'] ?? -0.1).clamp(-12.0, 0.0);
        shaperNode?.curve = TrackChannelStrip._buildLimiterCurve(threshDb, ceilingDb);
        break;

      case FXType.vintageTape:
        final era = (params['Era'] ?? 1974.0).clamp(1950.0, 1989.0);
        final eraProgress = ((era - 1950.0) / 39.0).clamp(0.0, 1.0);
        final hpCutoff = 250.0 * math.pow(20.0 / 250.0, eraProgress);
        final lpCutoff = 4500.0 * math.pow(18500.0 / 4500.0, eraProgress);
        final headBumpDb = (params['HeadBump'] ?? 3.0).clamp(0.0, 12.0);

        hpFilterNode?.frequency.value = hpCutoff.clamp(20.0, 500.0);
        lpFilterNode?.frequency.value = lpCutoff.clamp(1000.0, 20000.0);
        headBumpFilterNode?.gain.value = headBumpDb;

        final hissLevel = (params['HissLevel'] ?? 20.0).clamp(0.0, 100.0) / 100.0;
        final vinylCrackle = (params['VinylCrackle'] ?? 25.0).clamp(0.0, 100.0) / 100.0;
        final grooveRumble = (params['GrooveRumble'] ?? 15.0).clamp(0.0, 100.0) / 100.0;

        hissGainNode?.gain.value = (hissLevel * 0.04).clamp(0.0, 0.12);
        crackleGainNode?.gain.value = (math.pow(vinylCrackle, 1.2) * 0.09).clamp(0.0, 0.18);
        rumbleGainNode?.gain.value = (grooveRumble * 0.06).clamp(0.0, 0.12);
        noiseGainNode?.gain.value = 1.0;
        break;

      case FXType.convolutionReverb:
        final isCab = (newFx.presetId == 'cab_designer') || (newFx.name.toLowerCase().contains('cab'));
        final dryLevel = params['DryLevel'] ?? (isCab ? 0.0 : 1.0);
        final wetLevel = params['WetLevel'] ?? (isCab ? 1.0 : 0.5);
        dryGainNode?.gain.value = (dryLevel * (isCab ? 0.0 : (1.0 - mix))).clamp(0.0, 1.0);
        wetGainNode?.gain.value = (wetLevel * (isCab ? 1.0 : mix)).clamp(0.0, 1.0);
        final highCut = params['HighCut'];
        if (highCut != null && filterNode != null) {
          filterNode!.frequency.value = highCut.clamp(100.0, 20000.0);
        }
        break;

      default:
        break;
    }
  }
}

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
  late final WAAnalyserNode analyserNode;

  final List<WANode> _fxNodes = [];
  final List<_FxNodeBinding> _fxBindings = [];
  int _lastStructuralHash = 0;

  // Real-time Tape Stop & Wow/Flutter Modulation State
  WADelayNode? _tapeStopDelay;
  WABiquadFilterNode? _tapeStopFilter;
  WAGainNode? _tapeStopGain;
  double _baseTapeDelay = 0.020;
  double _baseCutoffLp = 18000.0;
  bool _isTapeStopTriggered = false;
  Timer? _lfoTimer;
  final Map<String, double> _vintageLfoParams = {};

  TrackChannelStrip({
    required this.trackId,
    required this.ctx,
    required this.destination,
  }) {
    inputBus = ctx.createGain()..gain.value = 1.0;
    volumeNode = ctx.createGain()..gain.value = 1.0;
    pannerNode = ctx.createStereoPanner()..pan.value = 0.0;
    analyserNode = ctx.createAnalyser()..fftSize = 256;

    inputBus.connect(volumeNode);
    volumeNode.connect(pannerNode);
    pannerNode.connect(analyserNode);
    analyserNode.connect(destination);
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

    final currentStructuralHash = _computeStructuralHash(fxRack);
    if (currentStructuralHash != _lastStructuralHash) {
      _rebuildFxChain(fxRack, irCache, loadIrAsync);
      _lastStructuralHash = currentStructuralHash;
    } else {
      _updateFxParamsInPlace(fxRack);
    }
  }

  void _updateFxParamsInPlace(List<FXInsert> fxRack) {
    for (int i = 0; i < fxRack.length && i < _fxBindings.length; i++) {
      final fx = fxRack[i];
      final binding = _fxBindings[i];
      if (binding.fx.id == fx.id) {
        binding.updateParams(fx);
      }
      if (fx.type == FXType.vintageTape || fx.presetId == 'vintage_era_degrader') {
        _vintageLfoParams.addAll(fx.params);
      }
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

  /// Triggers an authentic physical tape stop / motor deceleration and spin-up effect.
  void triggerTapeStop({double stopTime = 0.8, double spinUpTime = 0.4}) {
    if (_tapeStopDelay == null || _tapeStopFilter == null || _tapeStopGain == null) return;
    if (_isTapeStopTriggered) return;
    _isTapeStopTriggered = true;

    final startDelay = _baseTapeDelay;
    final targetDelay = (startDelay + (stopTime * 0.9)).clamp(0.01, 3.5);
    final startCutoff = _baseCutoffLp;
    const targetCutoff = 40.0;

    final steps = (stopTime * 60).round().clamp(10, 180);
    final dtMs = math.max(8, ((stopTime * 1000) / steps).round());

    // 1. Deceleration Phase
    int step = 0;
    Timer.periodic(Duration(milliseconds: dtMs), (decelTimer) {
      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      final decel = t * t; // Quadratic deceleration curve

      _tapeStopDelay?.delayTime.value = startDelay + (targetDelay - startDelay) * decel;
      _tapeStopFilter?.frequency.value = (startCutoff * math.pow(targetCutoff / startCutoff, t)).clamp(20.0, 20000.0);
      _tapeStopGain?.gain.value = (1.0 - decel * 0.98).clamp(0.0, 1.0);

      if (step >= steps) {
        decelTimer.cancel();

        // 2. Brief Hold, then Spin-Up Phase
        Future.delayed(const Duration(milliseconds: 60), () {
          final spinSteps = (spinUpTime * 60).round().clamp(10, 120);
          final spinDtMs = math.max(8, ((spinUpTime * 1000) / spinSteps).round());
          int spinStep = 0;

          Timer.periodic(Duration(milliseconds: spinDtMs), (spinTimer) {
            spinStep++;
            final st = (spinStep / spinSteps).clamp(0.0, 1.0);
            final accel = 1.0 - math.pow(1.0 - st, 3); // Cubic ease out acceleration

            _tapeStopDelay?.delayTime.value = targetDelay - (targetDelay - startDelay) * accel;
            _tapeStopFilter?.frequency.value = (targetCutoff * math.pow(startCutoff / targetCutoff, accel)).clamp(20.0, 20000.0);
            _tapeStopGain?.gain.value = (0.02 + accel * 0.98).clamp(0.0, 1.0);

            if (spinStep >= spinSteps) {
              spinTimer.cancel();
              _tapeStopDelay?.delayTime.value = startDelay;
              _tapeStopFilter?.frequency.value = startCutoff;
              _tapeStopGain?.gain.value = 1.0;
              _isTapeStopTriggered = false;
            }
          });
        });
      }
    });
  }

  void _rebuildFxChain(
    List<FXInsert> fxRack,
    Map<String, WABuffer?> irCache,
    Future<WABuffer?> Function(String) loadIrAsync,
  ) {
    // Disconnect old FX chain and cancel any active LFO timers
    _lfoTimer?.cancel();
    _lfoTimer = null;
    _tapeStopDelay = null;
    _tapeStopFilter = null;
    _tapeStopGain = null;
    _isTapeStopTriggered = false;

    inputBus.disconnect();
    for (final node in _fxNodes) {
      try {
        node.disconnect();
        node.dispose();
      } catch (_) {}
    }
    _fxNodes.clear();
    _fxBindings.clear();

    WANode current = inputBus;
    for (final fx in fxRack) {
      if (!fx.enabled) continue;
      final mix = fx.mix.clamp(0.0, 1.0);
      if (mix <= 0.0) continue;

      switch (fx.type) {
        case FXType.distortion:
          current = _addWaveShaper(current, fx, mix);
        case FXType.bitcrusher:
          current = _addBitcrusher(current, fx, mix);
        case FXType.biquadFilter:
          final filter = ctx.createBiquadFilter();
          filter.type = WABiquadFilterType.lowpass;
          filter.frequency.value = (fx.params['Cutoff'] ?? 3500.0).clamp(20.0, 20000.0);
          filter.Q.value = (fx.params['Resonance'] ?? 1.5).clamp(0.1, 20.0);
          _fxNodes.add(filter);
          current.connect(filter);
          _fxBindings.add(_FxNodeBinding(fx: fx, outputNode: filter, filterNode: filter));
          current = filter;
        case FXType.delay:
          current = _addDelay(current, fx, mix);
        case FXType.compressor:
          current = _addCompressor(current, fx, mix);
        case FXType.limiter:
          current = _addLimiter(current, fx, mix);
        case FXType.convolutionReverb:
          current = _addConvReverb(current, fx, mix, irCache, loadIrAsync);
        case FXType.vintageTape:
          current = _addVintageDegrader(current, fx, mix);
        case FXType.luaFX:
          if (fx.presetId == 'vintage_era_degrader' ||
              (fx.luaScriptCode != null && fx.luaScriptCode!.contains('vintage_era_degrader'))) {
            current = _addVintageDegrader(current, fx, mix);
          }
          break;
      }
    }

    current.connect(volumeNode);
  }

  WANode _addWaveShaper(WANode input, FXInsert fx, double mix) {
    final params = fx.params;
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
      _fxBindings.add(_FxNodeBinding(
        fx: fx,
        outputNode: postGain,
        preGainNode: preGain,
        postGainNode: postGain,
        shaperNode: shaper,
      ));
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

    _fxBindings.add(_FxNodeBinding(
      fx: fx,
      outputNode: bus,
      dryGainNode: dry,
      wetGainNode: wet,
      preGainNode: preGain,
      postGainNode: postGain,
      shaperNode: shaper,
    ));
    return bus;
  }

  WANode _addCompressor(WANode input, FXInsert fx, double mix) {
    final params = fx.params;
    final threshDb = (params['Threshold'] ?? -18.0).clamp(-60.0, 0.0);
    final ratio = (params['Ratio'] ?? 4.0).clamp(1.0, 20.0);
    final kneeDb = (params['Knee'] ?? 12.0).clamp(0.0, 40.0);

    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildCompressorCurve(threshDb, ratio, kneeDb);
    shaper.oversample = kIsWeb ? WAOverSampleType.x4 : WAOverSampleType.x2;
    _fxNodes.add(shaper);

    if (mix >= 0.98) {
      input.connect(shaper);
      _fxBindings.add(_FxNodeBinding(fx: fx, outputNode: shaper, shaperNode: shaper));
      return shaper;
    }
    final bus = ctx.createGain();
    final dry = ctx.createGain()..gain.value = 1.0 - mix;
    final wet = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dry, wet]);

    input.connect(dry)..connect(bus);
    input.connect(shaper)..connect(wet)..connect(bus);
    _fxBindings.add(_FxNodeBinding(
      fx: fx,
      outputNode: bus,
      dryGainNode: dry,
      wetGainNode: wet,
      shaperNode: shaper,
    ));
    return bus;
  }

  WANode _addLimiter(WANode input, FXInsert fx, double mix) {
    final params = fx.params;
    final threshDb = (params['Threshold'] ?? -1.0).clamp(-24.0, 0.0);
    final ceilingDb = (params['Ceiling'] ?? -0.1).clamp(-12.0, 0.0);

    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildLimiterCurve(threshDb, ceilingDb);
    shaper.oversample = kIsWeb ? WAOverSampleType.x4 : WAOverSampleType.x2;
    _fxNodes.add(shaper);

    if (mix >= 0.98) {
      input.connect(shaper);
      _fxBindings.add(_FxNodeBinding(fx: fx, outputNode: shaper, shaperNode: shaper));
      return shaper;
    }
    final bus = ctx.createGain();
    final dry = ctx.createGain()..gain.value = 1.0 - mix;
    final wet = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dry, wet]);

    input.connect(dry)..connect(bus);
    input.connect(shaper)..connect(wet)..connect(bus);
    _fxBindings.add(_FxNodeBinding(
      fx: fx,
      outputNode: bus,
      dryGainNode: dry,
      wetGainNode: wet,
      shaperNode: shaper,
    ));
    return bus;
  }

  WANode _addBitcrusher(WANode input, FXInsert fx, double mix) {
    final params = fx.params;
    final bits = (params['Bits'] ?? 8.0).clamp(1.0, 16.0);
    final drive = (params['Drive'] ?? 1.0).clamp(0.1, 4.0);
    final downsample = (params['Downsample'] ?? 1.0).clamp(1.0, 32.0);

    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildBitcrusherCurve(bits, downsample);
    shaper.oversample = WAOverSampleType.none;
    _fxNodes.add(shaper);

    WAGainNode? driveGain;
    WANode source = input;
    if (drive != 1.0) {
      driveGain = ctx.createGain()..gain.value = drive;
      _fxNodes.add(driveGain);
      input.connect(driveGain);
      source = driveGain;
    }

    source.connect(shaper);

    if (mix >= 0.98 && drive == 1.0) {
      _fxBindings.add(_FxNodeBinding(fx: fx, outputNode: shaper, shaperNode: shaper));
      return shaper;
    }
    final bus = ctx.createGain();
    final dry = ctx.createGain()..gain.value = 1.0 - mix;
    final wet = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dry, wet]);

    input.connect(dry)..connect(bus);
    shaper.connect(wet)..connect(bus);
    _fxBindings.add(_FxNodeBinding(
      fx: fx,
      outputNode: bus,
      dryGainNode: dry,
      wetGainNode: wet,
      preGainNode: driveGain,
      shaperNode: shaper,
    ));
    return bus;
  }

  WANode _addDelay(WANode input, FXInsert fx, double mix) {
    final params = fx.params;
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

    _fxBindings.add(_FxNodeBinding(
      fx: fx,
      outputNode: bus,
      dryGainNode: dryGain,
      wetGainNode: wetGain,
      delayNode: delNode,
      fbGainNode: fbGain,
    ));
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

    // Disable Web Audio's auto-normalization to prevent RMS-based +20dB volume inflation on truncated impulse responses
    final convolver = ctx.createConvolver()..normalize = false;
    _fxNodes.add(convolver);

    // Retrieve or construct WABuffer synchronously from ConvolverEngine memory
    var cached = irCache[irName];
    if (cached == null) {
      final stereo = ConvolverEngine.instance.getIrStereoSample(irName);
      if (stereo != null && stereo.left.isNotEmpty) {
        Float32List irDataL;
        Float32List irDataR;
        const int maxNativeIrLength = 384;
        if (!kIsWeb && stereo.left.length > maxNativeIrLength) {
          irDataL = Float32List(maxNativeIrLength);
          irDataR = Float32List(maxNativeIrLength);
          const int fadeLen = 64;
          final int nonFadeLen = maxNativeIrLength - fadeLen;
          for (int i = 0; i < nonFadeLen; i++) {
            irDataL[i] = stereo.left[i].toDouble();
            irDataR[i] = stereo.right[i].toDouble();
          }
          for (int i = 0; i < fadeLen; i++) {
            final double fade = 0.5 * (1.0 + math.cos(math.pi * i / fadeLen));
            irDataL[nonFadeLen + i] = (stereo.left[nonFadeLen + i] * fade).toDouble();
            irDataR[nonFadeLen + i] = (stereo.right[nonFadeLen + i] * fade).toDouble();
          }
        } else {
          irDataL = Float32List.fromList(stereo.left);
          irDataR = Float32List.fromList(stereo.right);
        }
        cached = WABuffer(
          numberOfChannels: 2,
          length: irDataL.length,
          sampleRate: 44100,
          channels: [irDataL, irDataR],
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
    final dryGain = ctx.createGain()..gain.value = (dryLevel * (isCab ? 0.0 : (1.0 - mix))).clamp(0.0, 1.0);
    final wetGain = ctx.createGain()..gain.value = (wetLevel * (isCab ? 1.0 : mix)).clamp(0.0, 1.0);
    _fxNodes.addAll([bus, dryGain, wetGain]);

    input.connect(dryGain);
    dryGain.connect(bus);

    WANode wetSource = convolver;

    WABiquadFilterNode? filter;
    final highCut = fx.params['HighCut'];
    if (highCut != null && highCut < 19000.0) {
      filter = ctx.createBiquadFilter();
      filter.type = WABiquadFilterType.lowpass;
      filter.frequency.value = highCut.clamp(100.0, 20000.0);
      _fxNodes.add(filter);
      convolver.connect(filter);
      wetSource = filter;
    }

    // On Native desktop for non-cabinet acoustic spaces:
    // Generate lush, dense, multi-second decay tails using prime-spaced feedback diffuser delay lines
    if (!kIsWeb && !isCab) {
      final presetRt60 = ProceduralIRGenerator.presets[irName]?.rt60;
      final rt60 = (fx.params['RT60'] ?? (presetRt60 ?? (irName.toLowerCase().contains('cathedral') ? 3.8 : (irName.toLowerCase().contains('hall') ? 1.6 : (irName.toLowerCase().contains('plate') ? 1.8 : 1.2))))).clamp(0.2, 8.0);
      final damping = (fx.params['Damping'] ?? (ProceduralIRGenerator.presets[irName]?.damping ?? 0.35)).clamp(0.0, 1.0);

      // Tail blend scales smoothly with room RT60 (longer spaces receive deeper tail diffusion)
      final tailMix = ((rt60 - 0.5) / 3.5).clamp(0.15, 0.70);
      final tailBus = ctx.createGain()..gain.value = 1.0;
      final earlyGain = ctx.createGain()..gain.value = 1.0 - (tailMix * 0.5);
      final tailWet = ctx.createGain()..gain.value = tailMix * 0.7;
      final dampCutoff = (16000.0 * (1.0 - damping * 0.70)).clamp(800.0, 16000.0);

      final delays = [0.0297, 0.0371, 0.0433, 0.0531];
      final tapGain = 1.0 / delays.length; // 0.25 scaling so 4 delay lines sum to unity
      for (int d = 0; d < delays.length; d++) {
        final dt = delays[d];
        final fb = math.exp(-6.9077 * dt / rt60).clamp(0.05, 0.78);
        final del = ctx.createDelay(1.0)..delayTime.value = dt;
        final fbg = ctx.createGain()..gain.value = fb;
        final dampFilter = ctx.createBiquadFilter()
          ..type = WABiquadFilterType.lowpass
          ..frequency.value = dampCutoff;
        final tapGainNode = ctx.createGain()..gain.value = tapGain;

        _fxNodes.addAll([del, fbg, dampFilter, tapGainNode]);

        wetSource.connect(del);
        del.connect(dampFilter);
        dampFilter.connect(fbg);
        fbg.connect(del);
        del.connect(tapGainNode);
        tapGainNode.connect(tailWet);
      }

      wetSource.connect(earlyGain);
      earlyGain.connect(tailBus);
      tailWet.connect(tailBus);
      _fxNodes.addAll([tailBus, earlyGain, tailWet]);
      wetSource = tailBus;
    }

    input.connect(convolver);
    wetSource.connect(wetGain);
    wetGain.connect(bus);

    _fxBindings.add(_FxNodeBinding(
      fx: fx,
      outputNode: bus,
      dryGainNode: dryGain,
      wetGainNode: wetGain,
      filterNode: filter,
    ));
    return bus;
  }

  WANode _addVintageDegrader(WANode input, FXInsert fx, double mix) {
    final params = fx.params;
    _vintageLfoParams.clear();
    _vintageLfoParams.addAll(params);

    final era = (params['Era'] ?? 1974.0).clamp(1950.0, 1989.0);
    final mediumIdx = (params['Medium'] ?? 2.0).round().clamp(0, 3);
    final wowDepth = (params['WowDepth'] ?? 25.0).clamp(0.0, 100.0) / 100.0;
    final flutterDepth = (params['FlutterDepth'] ?? 15.0).clamp(0.0, 100.0) / 100.0;
    final motorJitter = (params['MotorJitter'] ?? 10.0).clamp(0.0, 100.0) / 100.0;
    final warpSwell = (params['WarpSwell'] ?? 20.0).clamp(0.0, 100.0) / 100.0;
    final tapeDropouts = (params['TapeDropouts'] ?? 15.0).clamp(0.0, 100.0) / 100.0;
    final needleBumpFreq = (params['NeedleBumpFreq'] ?? 25.0).clamp(0.0, 100.0) / 100.0;
    final stutterDepth = (params['StutterDepth'] ?? 35.0).clamp(0.0, 100.0) / 100.0;
    final thudLevel = (params['ThudLevel'] ?? 30.0).clamp(0.0, 100.0) / 100.0;
    final tapeWarmth = (params['TapeWarmth'] ?? 45.0).clamp(0.0, 100.0) / 100.0;
    final headBumpDb = (params['HeadBump'] ?? 3.0).clamp(0.0, 12.0);
    final hissLevel = (params['HissLevel'] ?? 20.0).clamp(0.0, 100.0) / 100.0;
    final vinylCrackle = (params['VinylCrackle'] ?? 25.0).clamp(0.0, 100.0) / 100.0;
    final grooveRumble = (params['GrooveRumble'] ?? 15.0).clamp(0.0, 100.0) / 100.0;

    // 1. Era Bandwidth Morph Calculation (1950s - 1980s)
    final eraProgress = ((era - 1950.0) / 39.0).clamp(0.0, 1.0);
    final hpCutoff = 250.0 * math.pow(20.0 / 250.0, eraProgress);
    final lpCutoff = 4500.0 * math.pow(18500.0 / 4500.0, eraProgress);
    _baseCutoffLp = lpCutoff;

    // 2. Tape Saturation & Warmth Pre-Stage
    final shaper = ctx.createWaveShaper();
    shaper.curve = _buildTapeSaturationCurve(tapeWarmth);
    shaper.oversample = kIsWeb ? WAOverSampleType.x4 : WAOverSampleType.x2;
    _fxNodes.add(shaper);

    // 3. Modulated Delay Node (Wow, Flutter, Doppler Slip & Tape Stop)
    _baseTapeDelay = 0.020;
    final delNode = ctx.createDelay(4.0)..delayTime.value = _baseTapeDelay;
    _tapeStopDelay = delNode;
    _fxNodes.add(delNode);

    // 4. Era EQ (Highpass + Lowpass + Peaking Head Bump)
    final hpFilter = ctx.createBiquadFilter()
      ..type = WABiquadFilterType.highpass
      ..frequency.value = hpCutoff.clamp(20.0, 500.0)
      ..Q.value = 0.707;

    final lpFilter = ctx.createBiquadFilter()
      ..type = WABiquadFilterType.lowpass
      ..frequency.value = lpCutoff.clamp(1000.0, 20000.0)
      ..Q.value = 0.85;
    _tapeStopFilter = lpFilter;

    final headBump = ctx.createBiquadFilter()
      ..type = WABiquadFilterType.peaking
      ..frequency.value = (mediumIdx == 1 ? 95.0 : (mediumIdx >= 2 ? 65.0 : 80.0))
      ..Q.value = 1.2
      ..gain.value = headBumpDb;

    _fxNodes.addAll([hpFilter, lpFilter, headBump]);

    // 5. Volume & AM Swell / Tape Stop Gain
    final stopGain = ctx.createGain()..gain.value = 1.0;
    _tapeStopGain = stopGain;
    _fxNodes.add(stopGain);

    // Signal Routing: input -> shaper -> delNode -> hpFilter -> headBump -> lpFilter -> stopGain
    input.connect(shaper);
    shaper.connect(delNode);
    delNode.connect(hpFilter);
    hpFilter.connect(headBump);
    headBump.connect(lpFilter);
    lpFilter.connect(stopGain);

    // 6. Real-time LFO Modulations for Delay Time & Volume
    if (wowDepth > 0.001 || flutterDepth > 0.001 || warpSwell > 0.001 || needleBumpFreq > 0.001 || tapeDropouts > 0.001) {
      _startVintageLfoModulators(
        delNode: delNode,
        stopGain: stopGain,
        mediumIdx: mediumIdx,
      );
    }

    // 7. Background Noise (Hiss + Procedural Vinyl Crackle + Groove Rumble)
    final noiseSetup = _createVintageNoiseSource(
      hissLevel: hissLevel,
      vinylCrackle: vinylCrackle,
      grooveRumble: grooveRumble,
      mediumIdx: mediumIdx,
    );
    if (noiseSetup != null) {
      noiseSetup.$1.connect(stopGain);
    }

    if (mix >= 0.98) {
      _fxBindings.add(_FxNodeBinding(
        fx: fx,
        outputNode: stopGain,
        hpFilterNode: hpFilter,
        lpFilterNode: lpFilter,
        headBumpFilterNode: headBump,
        delayNode: delNode,
        noiseGainNode: noiseSetup?.$1 is WAGainNode ? noiseSetup!.$1 as WAGainNode : null,
        hissGainNode: noiseSetup?.$2,
        crackleGainNode: noiseSetup?.$3,
        rumbleGainNode: noiseSetup?.$4,
      ));
      return stopGain;
    }

    // Dry / Wet Bus
    final bus = ctx.createGain();
    final dryGain = ctx.createGain()..gain.value = 1.0 - mix;
    final wetGain = ctx.createGain()..gain.value = mix;
    _fxNodes.addAll([bus, dryGain, wetGain]);

    input.connect(dryGain)..connect(bus);
    stopGain.connect(wetGain)..connect(bus);

    _fxBindings.add(_FxNodeBinding(
      fx: fx,
      outputNode: bus,
      dryGainNode: dryGain,
      wetGainNode: wetGain,
      hpFilterNode: hpFilter,
      lpFilterNode: lpFilter,
      headBumpFilterNode: headBump,
      delayNode: delNode,
      noiseGainNode: noiseSetup?.$1 is WAGainNode ? noiseSetup!.$1 as WAGainNode : null,
      hissGainNode: noiseSetup?.$2,
      crackleGainNode: noiseSetup?.$3,
      rumbleGainNode: noiseSetup?.$4,
    ));
    return bus;
  }

  void _startVintageLfoModulators({
    required WADelayNode delNode,
    required WAGainNode stopGain,
    required int mediumIdx,
  }) {
    _lfoTimer?.cancel();

    double wowPhase = 0.0;
    double flutterPhase = 0.0;
    double bumpSlip = 0.0;
    double bumpDuck = 1.0;
    double dropoutGain = 1.0;
    double smoothDelay = _baseTapeDelay;
    final rng = math.Random();

    // Medium rotation speeds
    final wowRate = (mediumIdx == 3) ? 1.30 : ((mediumIdx == 2) ? 0.55 : ((mediumIdx == 4) ? 0.75 : 0.65));
    final flutterRate = (mediumIdx == 1) ? 14.5 : ((mediumIdx == 4) ? 16.0 : 12.0);

    const dtSec = 0.016; // 60 FPS tick rate
    _lfoTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_isTapeStopTriggered) return;

      final wowDepth = (_vintageLfoParams['WowDepth'] ?? 25.0).clamp(0.0, 100.0) / 100.0;
      final flutterDepth = (_vintageLfoParams['FlutterDepth'] ?? 15.0).clamp(0.0, 100.0) / 100.0;
      final motorJitter = (_vintageLfoParams['MotorJitter'] ?? 10.0).clamp(0.0, 100.0) / 100.0;
      final warpSwell = (_vintageLfoParams['WarpSwell'] ?? 20.0).clamp(0.0, 100.0) / 100.0;
      final tapeDropouts = (_vintageLfoParams['TapeDropouts'] ?? 15.0).clamp(0.0, 100.0) / 100.0;
      final needleBumpFreq = (_vintageLfoParams['NeedleBumpFreq'] ?? 25.0).clamp(0.0, 100.0) / 100.0;
      final stutterDepth = (_vintageLfoParams['StutterDepth'] ?? 35.0).clamp(0.0, 100.0) / 100.0;

      wowPhase = (wowPhase + (2.0 * math.pi * wowRate * dtSec)) % (2.0 * math.pi);
      flutterPhase = (flutterPhase + (2.0 * math.pi * flutterRate * dtSec)) % (2.0 * math.pi);

      // Calibrated physical delay fluctuations:
      // Wow: low-frequency gentle tape/platter sway (~0.0035s max)
      // Flutter: subtle sub-millisecond shimmer (~0.00035s max)
      final wowMod = math.sin(wowPhase) * wowDepth * 0.0035;
      final flutterMod = math.sin(flutterPhase) * flutterDepth * 0.00035;
      final jitterMod = (rng.nextDouble() * 2.0 - 1.0) * motorJitter * 0.0003;

      // Needle Bump / Stutter Trigger
      if (needleBumpFreq > 0.001 && rng.nextDouble() < (needleBumpFreq * 0.025)) {
        bumpSlip = (0.0015 + rng.nextDouble() * 0.003) * stutterDepth;
        bumpDuck = (1.0 - (0.4 + rng.nextDouble() * 0.45) * stutterDepth).clamp(0.1, 1.0);
      } else {
        bumpSlip *= 0.85;
        bumpDuck = (bumpDuck + (1.0 - bumpDuck) * 0.18).clamp(0.0, 1.0);
      }

      // Tape Dropouts
      if (tapeDropouts > 0.001 && rng.nextDouble() < (tapeDropouts * 0.018)) {
        dropoutGain = (1.0 - (0.3 + rng.nextDouble() * 0.5) * tapeDropouts).clamp(0.1, 1.0);
      } else {
        dropoutGain = (dropoutGain + (1.0 - dropoutGain) * 0.15).clamp(0.0, 1.0);
      }

      // AM Warp Swell
      final swellMod = 1.0 + math.sin(wowPhase - math.pi / 2.0) * warpSwell * 0.22;

      final targetDelay = (_baseTapeDelay + wowMod + flutterMod + jitterMod + bumpSlip).clamp(0.001, 3.5);
      // Continuous exponential sub-sample smoothing eliminates stair-step discontinuities / clipping
      smoothDelay += (targetDelay - smoothDelay) * 0.35;
      delNode.delayTime.value = smoothDelay;

      final totalGain = (swellMod * bumpDuck * dropoutGain * 0.85).clamp(0.0, 1.0);
      stopGain.gain.value = totalGain;
    });
  }

  static WABuffer? _cachedHissNoiseBuf;
  static WABuffer? _cachedVinylCrackleBuf;

  (WANode, WAGainNode, WAGainNode, WAGainNode)? _createVintageNoiseSource({
    required double hissLevel,
    required double vinylCrackle,
    required double grooveRumble,
    required int mediumIdx,
  }) {
    try {
      const sr = 44100;

      // 1. Generate Analog Tape / Floor Hiss Buffer (Pink / Thermal Noise)
      if (_cachedHissNoiseBuf == null) {
        const durSec = 3.0;
        final totalSamples = (sr * durSec).toInt();
        final hissL = Float32List(totalSamples);
        final hissR = Float32List(totalSamples);

        double b0L = 0, b1L = 0, b2L = 0;
        double b0R = 0, b1R = 0, b2R = 0;
        final rng = math.Random(1984);

        for (int i = 0; i < totalSamples; i++) {
          final wL = (rng.nextDouble() * 2.0 - 1.0);
          final wR = (rng.nextDouble() * 2.0 - 1.0);

          b0L = 0.99886 * b0L + wL * 0.0555179;
          b1L = 0.99332 * b1L + wL * 0.0750759;
          b2L = 0.96900 * b2L + wL * 0.1538520;
          final pinkL = (b0L + b1L + b2L + wL * 0.5362) * 0.18;

          b0R = 0.99886 * b0R + wR * 0.0555179;
          b1R = 0.99332 * b1R + wR * 0.0750759;
          b2R = 0.96900 * b2R + wR * 0.1538520;
          final pinkR = (b0R + b1R + b2R + wR * 0.5362) * 0.18;

          hissL[i] = pinkL.clamp(-1.0, 1.0);
          hissR[i] = pinkR.clamp(-1.0, 1.0);
        }

        _cachedHissNoiseBuf = WABuffer(
          numberOfChannels: 2,
          length: totalSamples,
          sampleRate: sr,
          channels: [hissL, hissR],
        );
      }

      // 2. Generate Authentic Procedural Vinyl Crackle Buffer (Multi-stage Poisson clicks, pops & groove rumble)
      if (_cachedVinylCrackleBuf == null) {
        const durSec = 6.0;
        final totalSamples = (sr * durSec).toInt();
        final crackleL = Float32List(totalSamples);
        final crackleR = Float32List(totalSamples);
        final rng = math.Random(1977);

        int clickRemaining = 0;
        double clickAmpL = 0.0;
        double clickAmpR = 0.0;
        double clickDecay = 0.85;

        for (int i = 0; i < totalSamples; i++) {
          // Low-frequency groove friction / rumble (33.3 RPM periodic sway ~ 0.55 Hz + 31.5 Hz turntable motor hum)
          final grooveSway = math.sin(i * 2.0 * math.pi * 0.55 / sr);
          final rumble = (math.sin(i * 2.0 * math.pi * 31.5 / sr) * 0.35 +
                          math.sin(i * 2.0 * math.pi * 63.0 / sr) * 0.15) * (0.8 + 0.2 * grooveSway);

          // Random Poisson Vinyl Click / Pop / Scratch Trigger
          if (clickRemaining <= 0) {
            final roll = rng.nextDouble();
            if (roll < 0.0018) {
              // Micro dust tick
              clickRemaining = 6 + rng.nextInt(12);
              final polarity = rng.nextBool() ? 1.0 : -1.0;
              final amp = (0.25 + rng.nextDouble() * 0.5) * polarity;
              clickAmpL = amp;
              clickAmpR = amp * (0.6 + rng.nextDouble() * 0.8);
              clickDecay = 0.65 + rng.nextDouble() * 0.20;
            } else if (roll < 0.0021) {
              // Medium vinyl pop / surface scratch
              clickRemaining = 25 + rng.nextInt(60);
              final polarity = rng.nextBool() ? 1.0 : -1.0;
              final amp = (0.6 + rng.nextDouble() * 0.4) * polarity;
              clickAmpL = amp;
              clickAmpR = amp * (0.4 + rng.nextDouble() * 1.2);
              clickDecay = 0.88 + rng.nextDouble() * 0.08;
            } else if (roll < 0.00215) {
              // Heavy needle pop with sub resonance
              clickRemaining = 60 + rng.nextInt(120);
              final amp = (0.8 + rng.nextDouble() * 0.2);
              clickAmpL = amp;
              clickAmpR = amp * 0.85;
              clickDecay = 0.94;
            }
          }

          double currentClickL = 0.0;
          double currentClickR = 0.0;
          if (clickRemaining > 0) {
            currentClickL = clickAmpL;
            currentClickR = clickAmpR;
            clickAmpL *= clickDecay;
            clickAmpR *= clickDecay;
            clickRemaining--;
          }

          // Subtle groove surface friction noise
          final surfaceFriction = (rng.nextDouble() * 2.0 - 1.0) * 0.02;

          crackleL[i] = (currentClickL + surfaceFriction + rumble * 0.25).clamp(-1.0, 1.0);
          crackleR[i] = (currentClickR + surfaceFriction + rumble * 0.25).clamp(-1.0, 1.0);
        }

        _cachedVinylCrackleBuf = WABuffer(
          numberOfChannels: 2,
          length: totalSamples,
          sampleRate: sr,
          channels: [crackleL, crackleR],
        );
      }

      final hissSource = ctx.createBufferSource()
        ..buffer = _cachedHissNoiseBuf
        ..loop = true;

      final crackleSource = ctx.createBufferSource()
        ..buffer = _cachedVinylCrackleBuf
        ..loop = true;

      final hissGainNode = ctx.createGain()
        ..gain.value = (hissLevel * 0.04).clamp(0.0, 0.12);

      // Crackle gain scaled for realistic ambient vinyl crackle
      final crackleGainNode = ctx.createGain()
        ..gain.value = (math.pow(vinylCrackle, 1.2) * 0.09).clamp(0.0, 0.18);

      final rumbleGainNode = ctx.createGain()
        ..gain.value = (grooveRumble * 0.06).clamp(0.0, 0.12);

      final noiseMixer = ctx.createGain()..gain.value = 1.0;
      _fxNodes.addAll([hissSource, crackleSource, hissGainNode, crackleGainNode, rumbleGainNode, noiseMixer]);

      hissSource.connect(hissGainNode);
      hissGainNode.connect(noiseMixer);

      crackleSource.connect(crackleGainNode);
      crackleGainNode.connect(noiseMixer);

      hissSource.start();
      crackleSource.start();

      return (noiseMixer, hissGainNode, crackleGainNode, rumbleGainNode);
    } catch (_) {
      return null;
    }
  }

  static int _computeStructuralHash(List<FXInsert> fxRack) {
    int h = 0;
    for (final fx in fxRack) {
      if (!fx.enabled) continue;
      h = (h * 31) ^ fx.type.index;
      h = (h * 31) ^ fx.id.hashCode;
      if (fx.irSampleName != null) {
        h = (h * 31) ^ fx.irSampleName.hashCode;
      }
      if (fx.type == FXType.convolutionReverb) {
        final p = fx.params;
        h = (h * 31) ^ (p['Material']?.toInt() ?? 0);
        h = (h * 31) ^ ((p['Width'] ?? 0.0) * 10).round();
        h = (h * 31) ^ ((p['Length'] ?? 0.0) * 10).round();
        h = (h * 31) ^ ((p['Height'] ?? 0.0) * 10).round();
        h = (h * 31) ^ ((p['RT60'] ?? 0.0) * 100).round();
        h = (h * 31) ^ ((p['Damping'] ?? 0.0) * 100).round();
        h = (h * 31) ^ (p['isCabinet']?.toInt() ?? 0);
        h = (h * 31) ^ ((p['MicDistance'] ?? 0.0) * 100).round();
        h = (h * 31) ^ ((p['MicAngle'] ?? 0.0) * 10).round();
        h = (h * 31) ^ (p['OpenBack']?.toInt() ?? 0);
        h = (h * 31) ^ ((p['StereoWidth'] ?? 0.0) * 100).round();
      }
    }
    return h;
  }

  void dispose() {
    try {
      _lfoTimer?.cancel();
      _lfoTimer = null;
      inputBus.disconnect();
      volumeNode.disconnect();
      pannerNode.disconnect();
      try { analyserNode.disconnect(); } catch (_) {}
      for (final node in _fxNodes) {
        try {
          node.disconnect();
          node.dispose();
        } catch (_) {}
      }
      _fxNodes.clear();
      _fxBindings.clear();
      inputBus.dispose();
      volumeNode.dispose();
      pannerNode.dispose();
      try { analyserNode.dispose(); } catch (_) {}
    } catch (_) {}
  }

  static Float32List _buildTapeSaturationCurve(double warmth) {
    const n = 512;
    final curve = Float32List(n);
    final drive = 1.0 + warmth * 4.0;
    for (int i = 0; i < n; i++) {
      final x = (2.0 * i / (n - 1)) - 1.0;
      double y;
      if (x >= 0) {
        y = _tanhF(x * drive) + 0.06 * x * x * warmth;
      } else {
        y = _tanhF(x * drive * 1.1) - 0.03 * x * x * warmth;
      }
      curve[i] = (y / _tanhF(drive)).clamp(-1.0, 1.0);
    }
    return curve;
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

  // Per-track active frozen audio streams
  final Map<String, WABufferSourceNode> _frozenSources = {};

  // WABuffer cache – reuse sample data between note-on events
  final Map<String, WABuffer> _bufferCache = {};

  // Decoded IR buffer cache for ConvolverNode
  final Map<String, WABuffer?> _irCache = {};
  final Map<String, Future<WABuffer?>> _irPending = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  late final Future<void> _readyFuture;

  final Stopwatch _fallbackClock = Stopwatch();

  double get currentTime {
    final ctx = _ctx;
    if (ctx != null) {
      try {
        return ctx.currentTime;
      } catch (_) {}
    }
    if (!_fallbackClock.isRunning) {
      _fallbackClock.start();
    }
    return _fallbackClock.elapsedMicroseconds / 1000000.0;
  }

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
      // Explicitly set inputChannels: 0, outputChannels: 2 to avoid Windows audio device init failure on systems without a mic.
      final ctx = WAContext(
        sampleRate: 44100,
        bufferSize: 512,
        inputChannels: 0,
        outputChannels: 2,
      );
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
    if (!_fallbackClock.isRunning) {
      _fallbackClock.start();
    }
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

  void disposeTrackStrip(String trackId) {
    final strip = _channelStrips.remove(trackId);
    strip?.dispose();
    final src = _activeSources.remove(trackId);
    try { src?.stop(); src?.dispose(); } catch (_) {}
  }

  /// Clears all track channel strips, stops active sources, and flushes buffer cache.
  void clearChannelStrips() {
    stopAllSound();
    for (final strip in _channelStrips.values) {
      try { strip.dispose(); } catch (_) {}
    }
    _channelStrips.clear();
    _bufferCache.clear();
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

  // ── Meters & Point-in-Chain Analyser Taps ──────────────────────────────────

  WAAnalyserNode? getAnalyser({String? targetId}) {
    if (targetId != null && targetId != 'master' && targetId != 'master_bus') {
      final strip = _channelStrips[targetId];
      if (strip != null) return strip.analyserNode;
      final ctx = _ctx;
      if (ctx != null) {
        final destination = _masterInputBus ?? _masterGain;
        if (destination != null) {
          final newStrip = _channelStrips.putIfAbsent(
            targetId,
            () => TrackChannelStrip(
              trackId: targetId,
              ctx: ctx,
              destination: destination,
            ),
          );
          return newStrip.analyserNode;
        }
      }
      return null;
    }
    return _analyser;
  }

  void getTimeDomainData(Uint8List timeData, {String? targetId}) {
    final analyser = getAnalyser(targetId: targetId);
    if (!_initialized || analyser == null) {
      timeData.fillRange(0, timeData.length, 128);
      return;
    }
    try {
      analyser.getByteTimeDomainData(timeData);
    } catch (_) {
      timeData.fillRange(0, timeData.length, 128);
    }
  }

  void getFrequencyData(Uint8List freqData, {String? targetId}) {
    final analyser = getAnalyser(targetId: targetId);
    if (!_initialized || analyser == null) {
      freqData.fillRange(0, freqData.length, 0);
      return;
    }
    try {
      analyser.getByteFrequencyData(freqData);
    } catch (_) {
      freqData.fillRange(0, freqData.length, 0);
    }
  }

  void updateMeters(Uint8List timeData, Function(double l, double r) setPeaks, {String? targetId}) {
    final analyser = getAnalyser(targetId: targetId);
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

      final now = ctx.currentTime;
      double startTime = now;
      if (scheduledTime != null && scheduledTime > now && scheduledTime < now + 0.3) {
        startTime = scheduledTime;
      }

      // 1. Stop previous note if monophonic
      if (isMonophonic) {
        final prev = _activeSources[effectiveTrackId];
        if (prev != null) {
          try {
            if (startTime > now) {
              prev.stop(startTime);
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
          if (_bufferCache.length >= 128) {
            _bufferCache.remove(_bufferCache.keys.first);
          }
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

  /// Triggers real-time Tape Stop motor deceleration and spin-up on a track channel or master strip.
  void triggerTapeStop(String trackId, {double stopTime = 0.8, double spinUpTime = 0.4}) {
    if (trackId == 'master' || trackId == 'master_bus') {
      _masterStrip?.triggerTapeStop(stopTime: stopTime, spinUpTime: spinUpTime);
      return;
    }
    final strip = _channelStrips[trackId];
    strip?.triggerTapeStop(stopTime: stopTime, spinUpTime: spinUpTime);
  }

  /// Plays or seeks a pre-rendered frozen audio buffer stream for a track channel.
  void playFrozenStream({
    required String trackId,
    required Float32List samples,
    double startOffsetSec = 0.0,
    double volume = 1.0,
    double pan = 0.0,
    List<FXInsert>? fxRack,
    double? scheduledTime,
  }) {
    if (samples.isEmpty) return;
    final ctx = _ctx;
    if (ctx == null) return;

    try {
      // 1. Stop existing frozen stream for this track
      stopFrozenStream(trackId);

      // 2. Resolve TrackChannelStrip
      final strip = _channelStrips.putIfAbsent(
        trackId,
        () => TrackChannelStrip(
          trackId: trackId,
          ctx: ctx,
          destination: _masterInputBus ?? ctx.destination,
        ),
      );

      // 3. Update strip volume, pan, and FX rack
      strip.update(
        volume: volume,
        pan: pan,
        fxRack: fxRack ?? const [],
        irCache: _irCache,
        loadIrAsync: _loadIrAsync,
      );

      final int offsetSamples = (startOffsetSec * 44100).round().clamp(0, samples.length);
      final Float32List streamSamples = (offsetSamples > 0 && offsetSamples < samples.length)
          ? Float32List.sublistView(samples, offsetSamples)
          : samples;

      if (streamSamples.isEmpty) return;

      // 4. Create WABuffer
      final buf = WABuffer(
        numberOfChannels: 1,
        length: streamSamples.length,
        sampleRate: 44100,
        channels: [streamSamples],
      );

      final source = ctx.createBufferSource();
      source.buffer = buf;
      _frozenSources[trackId] = source;

      source.connect(strip.inputBus);

      source.onEnded = () {
        try {
          source.disconnect();
          source.dispose();
          if (_frozenSources[trackId] == source) {
            _frozenSources.remove(trackId);
          }
        } catch (_) {}
      };

      final double startTime = scheduledTime ?? ctx.currentTime;
      source.start(startTime);
    } catch (e) {
      debugPrint('[WajuceAudioBackend] playFrozenStream error: $e');
    }
  }

  /// Stops any active frozen audio stream for a track channel.
  void stopFrozenStream(String trackId) {
    try {
      final src = _frozenSources.remove(trackId);
      if (src != null) {
        try {
          src.stop((_ctx?.currentTime ?? 0) + 0.02);
        } catch (_) {
          try { src.stop(); } catch (_) {}
        }
        try {
          src.disconnect();
          src.dispose();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Stops all active frozen audio streams.
  void stopAllFrozenStreams() {
    try {
      for (final src in _frozenSources.values) {
        try { src.stop(); } catch (_) {}
        try { src.disconnect(); src.dispose(); } catch (_) {}
      }
      _frozenSources.clear();
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
      stopAllFrozenStreams();
    } catch (_) {}
  }

  // ── IR loading ─────────────────────────────────────────────────────────────

  Future<WABuffer?> _loadIrAsync(String irName) {
    return _irPending.putIfAbsent(irName, () async {
      try {
        final stereo = ConvolverEngine.instance.getIrStereoSample(irName);
        if (stereo == null || stereo.left.isEmpty) return null;
        Float32List irDataL;
        Float32List irDataR;
        const int maxNativeIrLength = 384;
        if (!kIsWeb && stereo.left.length > maxNativeIrLength) {
          irDataL = Float32List(maxNativeIrLength);
          irDataR = Float32List(maxNativeIrLength);
          const int fadeLen = 64;
          final int nonFadeLen = maxNativeIrLength - fadeLen;
          for (int i = 0; i < nonFadeLen; i++) {
            irDataL[i] = stereo.left[i].toDouble();
            irDataR[i] = stereo.right[i].toDouble();
          }
          for (int i = 0; i < fadeLen; i++) {
            final double fade = 0.5 * (1.0 + math.cos(math.pi * i / fadeLen));
            irDataL[nonFadeLen + i] = (stereo.left[nonFadeLen + i] * fade).toDouble();
            irDataR[nonFadeLen + i] = (stereo.right[nonFadeLen + i] * fade).toDouble();
          }
        } else {
          irDataL = Float32List.fromList(stereo.left);
          irDataR = Float32List.fromList(stereo.right);
        }
        final wabuf = WABuffer(
          numberOfChannels: 2,
          length: irDataL.length,
          sampleRate: 44100,
          channels: [irDataL, irDataR],
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

  Future<void> preloadIrSamples([Iterable<String>? specificIrNames]) async {
    final names = specificIrNames ?? ConvolverEngine.instance.getAvailableIrNames();
    for (final name in names) {
      if (!_irCache.containsKey(name)) {
        await _loadIrAsync(name);
      }
    }
  }
}
