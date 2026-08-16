import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import '../lua/lua_engine.dart';
import 'convolver_engine.dart';
import 'poly_synth.dart';

import 'sampler_engine.dart';
import 'soundfont_engine.dart';

import 'audio_engine_stub.dart'
    if (dart.library.js_interop) 'audio_engine_web.dart'
    if (dart.library.io) 'audio_engine_native.dart';

class AudioEngine {
  final AudioEngineWebImpl _webImpl = AudioEngineWebImpl();

  bool get isInitialized => _webImpl.isInitialized;

  double _leftPeak = 0.0;
  double _rightPeak = 0.0;
  double get leftPeak => _leftPeak;
  double get rightPeak => _rightPeak;

  final Map<String, double> _trackLeftPeaks = {};
  final Map<String, double> _trackRightPeaks = {};

  double getTrackLeftPeak(String trackId) => _trackLeftPeaks[trackId] ?? 0.0;
  double getTrackRightPeak(String trackId) => _trackRightPeaks[trackId] ?? 0.0;

  bool get hasActiveMeterActivity {
    if (_leftPeak > 0.001 || _rightPeak > 0.001) return true;
    for (final val in _trackLeftPeaks.values) {
      if (val > 0.001) return true;
    }
    for (final val in _trackRightPeaks.values) {
      if (val > 0.001) return true;
    }
    return false;
  }

  final Uint8List _timeData = Uint8List(128);
  Uint8List get waveformTimeData => _timeData;

  void ensureContextRunning() {
    _webImpl.ensureContextRunning();
  }

  void setMasterVolume(double volume) {
    _webImpl.setMasterVolume(volume);
  }

  Map<String, double> getMeterSnapshot() {
    updateMeters();
    return {
      'leftPeak': _leftPeak,
      'rightPeak': _rightPeak,
      'rms': (_leftPeak + _rightPeak) / 2.0,
      'currentTime': currentTime,
    };
  }

  String createNode(String type, Map<String, dynamic> config) {
    return _webImpl.createNode(type, config);
  }

  void connect(String sourceId, String targetId, [int outputIndex = 0, int inputIndex = 0]) {
    _webImpl.connect(sourceId, targetId, outputIndex, inputIndex);
  }

  void connectToParam(String sourceId, String targetNodeId, String paramName) {
    _webImpl.connectToParam(sourceId, targetNodeId, paramName);
  }

  void disconnect(String nodeId) {
    _webImpl.disconnect(nodeId);
  }

  void scheduleParamOp({
    required String nodeId,
    required String paramName,
    required String method,
    required double value,
    required double scheduledTime,
    double? timeConstant,
  }) {
    _webImpl.scheduleParamOp(
      nodeId: nodeId,
      paramName: paramName,
      method: method,
      value: value,
      scheduledTime: scheduledTime,
      timeConstant: timeConstant,
    );
  }

  void processCommandQueue(List<Map<String, dynamic>> commands) {
    for (final cmd in commands) {
      final type = cmd['type'] as String?;
      if (type == 'CREATE_NODE') {
        createNode(cmd['nodeType'] as String, cmd['config'] as Map<String, dynamic>? ?? {});
      } else if (type == 'CONNECT') {
        connect(cmd['sourceId'] as String, cmd['targetId'] as String);
      } else if (type == 'CONNECT_PARAM') {
        connectToParam(cmd['sourceId'] as String, cmd['targetNodeId'] as String, cmd['paramName'] as String);
      } else if (type == 'PARAM_AUTOMATE') {
        scheduleParamOp(
          nodeId: cmd['nodeId'] as String,
          paramName: cmd['paramName'] as String,
          method: cmd['method'] as String,
          value: (cmd['value'] as num).toDouble(),
          scheduledTime: (cmd['scheduledTime'] as num).toDouble(),
          timeConstant: (cmd['timeConstant'] as num?)?.toDouble(),
        );
      } else if (type == 'NOTE_ON') {
        final note = (cmd['pitch'] as num).toInt();
        final vel = (cmd['velocity'] as num).toDouble();
        final time = (cmd['time'] as num).toDouble();
        final dur = (cmd['duration'] as num).toDouble();
        _webImpl.playPcmBuffer(
          PolySynth.generateSynthToneBuffer(midiNote: note, waveform: 'sawtooth', lengthSec: dur),
          vel,
          0.0,
          time,
        );
      }
    }
  }

  void updateMeters() {
    _webImpl.updateMeters(_timeData, (l, r) {
      _leftPeak = l;
      _rightPeak = r;
    });

    for (final id in _trackLeftPeaks.keys.toList()) {
      final dec = (_trackLeftPeaks[id] ?? 0.0) * 0.82;
      _trackLeftPeaks[id] = dec < 0.001 ? 0.0 : dec;
    }
    for (final id in _trackRightPeaks.keys.toList()) {
      final dec = (_trackRightPeaks[id] ?? 0.0) * 0.82;
      _trackRightPeaks[id] = dec < 0.001 ? 0.0 : dec;
    }
  }

  double get currentTime => _webImpl.currentTime;

  void playNoteOrSample({
    required TrackChannel track,
    required int midiNote,
    required double velocity,
    double durationSec = 0.4,
    double? scheduledTime,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    bool loop = false,
  }) {
    if (track.isMuted) return;

    final double normVol = (track.volume / 1.5).clamp(0.0, 1.0);
    final double effectiveVel = velocity.clamp(0.0, 1.0);
    final double outVol = (normVol * effectiveVel).clamp(0.0, 1.0);

    final double panVal = track.pan.clamp(-1.0, 1.0);
    final double leftPanFactor = panVal <= 0 ? 1.0 : (1.0 - panVal);
    final double rightPanFactor = panVal >= 0 ? 1.0 : (1.0 + panVal);

    final double trkLeft = (outVol * leftPanFactor).clamp(0.0, 1.0);
    final double trkRight = (outVol * rightPanFactor).clamp(0.0, 1.0);

    _trackLeftPeaks[track.id] = math.max(_trackLeftPeaks[track.id] ?? 0.0, trkLeft);
    _trackRightPeaks[track.id] = math.max(_trackRightPeaks[track.id] ?? 0.0, trkRight);

    _leftPeak = math.max(_leftPeak, trkLeft * 0.85);
    _rightPeak = math.max(_rightPeak, trkRight * 0.85);

    ensureContextRunning();

    List<double> pcmBuffer = [];

    final isSfTrack = track.sampleName.toLowerCase().endsWith('.sf2') ||
        track.name.toLowerCase().contains('soundfont') ||
        track.luaScriptCode.contains('SoundFont');

    if (isSfTrack) {
      final sfBuffer = SoundFontEngine.instance.getPitchShiftedBuffer(
        fontId: track.sampleName,
        presetNum: (track.luaParams['PresetNum'] ?? 0.0).toInt(),
        bankNum: (track.luaParams['BankNum'] ?? 0.0).toInt(),
        midiNote: midiNote,
        velocity: velocity,
        targetDurationSec: durationSec,
        fallbackDefault: true,
      );
      if (sfBuffer.isNotEmpty) {
        pcmBuffer = sfBuffer;
      }
    }

    if (pcmBuffer.isEmpty && track.type == TrackType.sampler) {

      final customBuffer = SamplerEngine.instance.getPitchShiftedPcm(
        track.sampleName,
        (midiNote - 60).toDouble(),
      );
      if (customBuffer.isNotEmpty) {
        pcmBuffer = customBuffer;
      } else {
        switch (track.sampleName.toLowerCase()) {
          case 'snare':
            pcmBuffer = PolySynth.generateSnareBuffer();
            break;
          case 'hihat':
          case 'hi-hat':
            pcmBuffer = PolySynth.generateHiHatBuffer(open: false);
            break;
          case 'openhat':
            pcmBuffer = PolySynth.generateHiHatBuffer(open: true);
            break;
          case 'clap':
            pcmBuffer = PolySynth.generateClapBuffer();
            break;
          case 'kick':
          default:
            pcmBuffer = PolySynth.generateKickBuffer();
            break;
        }
      }
    } else if (pcmBuffer.isEmpty && track.type == TrackType.luaScript) {
      pcmBuffer = List<double>.filled((44100 * durationSec).toInt(), 0.0);
      final double freq = PolySynth.midiToFreq(midiNote);
      final bool activeAccent = isAccent || velocity > 0.75;

      for (int i = 0; i < pcmBuffer.length; i++) {
        final double t = i / 44100.0;
        pcmBuffer[i] = LuaEngine.evaluateSynth(
          code: track.luaScriptCode,
          time: t,
          freq: freq,
          note: midiNote,
          params: track.luaParams,
          targetMidiNote: targetMidiNote,
          isSlide: isSlide,
          isAccent: activeAccent,
          trackId: track.id,
          sampleIndex: i,
          totalSamples: pcmBuffer.length,
        );
      }
    } else if (pcmBuffer.isEmpty) {
      pcmBuffer = PolySynth.generateSynthToneBuffer(
        midiNote: midiNote,
        waveform: track.synthWaveform,
        cutoff: track.cutoff,
        attack: track.attack,
        release: track.release,
        lengthSec: durationSec,
      );
    }

    final hasReverbOrDelay = track.fxRack.any((fx) =>

        fx.enabled &&
        (fx.type == FXType.convolutionReverb ||
            fx.type == FXType.delay ||
            fx.name == 'Convolution Reverb'));

    if (hasReverbOrDelay) {
      final tailSamples = (44100 * 2.0).toInt();
      final extendedBuffer = List<double>.filled(pcmBuffer.length + tailSamples, 0.0);
      for (int i = 0; i < pcmBuffer.length; i++) {
        extendedBuffer[i] = pcmBuffer[i];
      }
      pcmBuffer = extendedBuffer;
    }

    List<double>? webIrBuffer;
    String? webIrName;
    double webIrMix = 0.0;

    for (final fx in track.fxRack) {
      if (!fx.enabled) continue;

      if (fx.type == FXType.convolutionReverb || fx.name == 'Convolution Reverb') {
        if (kIsWeb) {
          webIrName = fx.irSampleName ?? 'Great Hall';
          webIrMix = fx.mix;
          webIrBuffer = ConvolverEngine.instance.getIrSample(webIrName);
        } else {
          pcmBuffer = ConvolverEngine.instance.processConvolver(
            pcmBuffer,
            fx.irSampleName ?? 'Great Hall',
            fx.mix,
          );
        }
      } else {
        for (int i = 0; i < pcmBuffer.length; i++) {
          final t = i / 44100.0;
          final processed = LuaEngine.evaluateEffect(
            code: fx.name,
            inputSample: pcmBuffer[i],
            time: t,
            params: fx.params,
          );
          pcmBuffer[i] = (pcmBuffer[i] * (1.0 - fx.mix)) + (processed * fx.mix);
        }
      }
    }

    _webImpl.playPcmBuffer(
      pcmBuffer,
      track.volume * velocity,
      track.pan,
      scheduledTime,
      track.id,
      track.isMonophonicTrack,
      isSlide,
      loop,
      webIrBuffer,
      webIrName,
      webIrMix,
      track.fxRack,
    );


  }

  void stopNote(TrackChannel track, [int? pitch]) {
    _webImpl.stopTrackNotes(track.id);
  }
}
