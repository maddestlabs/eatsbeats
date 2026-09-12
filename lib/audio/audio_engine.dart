import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import '../models/chord_model.dart';
import '../eatscript/eat_script_engine.dart';
import 'poly_synth.dart';
import 'sampler_engine.dart';
import 'soundfont_engine.dart';
import 'wajuce_audio_backend.dart';

class _ActivePlayingVoice {
  final TrackChannel track;
  final double startTime;
  final double durationSec;
  final double velocity;
  final Float32List samples;
  final bool isLooping;
  final bool isFrozen;

  _ActivePlayingVoice({
    required this.track,
    required this.startTime,
    required this.durationSec,
    required this.velocity,
    required this.samples,
    this.isLooping = false,
    this.isFrozen = false,
  });

  String get trackId => track.id;

  (double, double) computeLevelAt(double currentTime) {
    if (track.isMuted) return (0.0, 0.0);
    if (currentTime < startTime) return (0.0, 0.0);
    final elapsedSec = currentTime - startTime;
    if (!isLooping && elapsedSec >= durationSec) return (0.0, 0.0);

    final int totalSamples = samples.length;
    if (totalSamples == 0) return (0.0, 0.0);

    int startSample = (elapsedSec * 44100).toInt();
    if (isLooping) {
      startSample %= totalSamples;
    } else if (startSample >= totalSamples) {
      return (0.0, 0.0);
    }

    final int windowSize = math.min(256, totalSamples - startSample);
    if (windowSize <= 0) return (0.0, 0.0);

    double sumSq = 0.0;
    double maxSample = 0.0;
    for (int i = 0; i < windowSize; i++) {
      final s = samples[startSample + i].abs();
      if (s > maxSample) maxSample = s;
      sumSq += s * s;
    }

    final double rms = math.sqrt(sumSq / windowSize);
    final double rawEnergy = (maxSample * 0.70) + (rms * 0.30);

    final double normVol = (track.volume / 1.5).clamp(0.0, 1.0);
    final double outVol = (normVol * velocity).clamp(0.0, 1.0);
    final double outEnergy = (rawEnergy * outVol).clamp(0.0, 1.0);

    final double panVal = track.pan.clamp(-1.0, 1.0);
    final double leftPanFactor = panVal <= 0 ? 1.0 : (1.0 - panVal);
    final double rightPanFactor = panVal >= 0 ? 1.0 : (1.0 + panVal);

    return (
      (outEnergy * leftPanFactor).clamp(0.0, 1.0),
      (outEnergy * rightPanFactor).clamp(0.0, 1.0),
    );
  }
}

class AudioEngine {
  final WajuceAudioBackend _backend = WajuceAudioBackend();

  // Active playing voices for continuous real-time audio metering across chord sustains
  final List<_ActivePlayingVoice> _activeVoices = [];

  void clearActiveVoices() {
    _activeVoices.clear();
  }

  // High-performance PCM buffer cache.
  // Stores synthesized Float32List buffers for notes to eliminate per-note DSP overhead.
  final Map<String, Float32List> _pcmCache = {};

  bool get isInitialized => _backend.isInitialized;

  double _leftPeak = 0.0;
  double _rightPeak = 0.0;
  double get leftPeak => _leftPeak;
  double get rightPeak => _rightPeak;

  double _cpuLoad = 0.02;
  double get cpuLoad => _cpuLoad;
  double get cpuPercentage => (_cpuLoad * 100.0).clamp(0.0, 100.0);

  final Map<String, double> _trackLeftPeaks = {};
  final Map<String, double> _trackRightPeaks = {};

  double getTrackLeftPeak(String trackId) => _trackLeftPeaks[trackId] ?? 0.0;
  double getTrackRightPeak(String trackId) => _trackRightPeaks[trackId] ?? 0.0;

  bool get hasActiveMeterActivity {
    if (_leftPeak > 0.001 || _rightPeak > 0.001) return true;
    if (_activeVoices.isNotEmpty) return true;
    for (final val in _trackLeftPeaks.values) {
      if (val > 0.001) return true;
    }
    for (final val in _trackRightPeaks.values) {
      if (val > 0.001) return true;
    }
    return false;
  }

  final List<int> _timeData = List<int>.filled(128, 128);
  List<int> get waveformTimeData => _timeData;

  AudioEngine();

  void ensureContextRunning() {
    _backend.ensureContextRunning();
  }

  void setMasterVolume(double volume) {
    _backend.setMasterVolume(volume);
  }

  void updateMasterEq({
    double subCut = 25.0,
    double lowGain = 0.0,
    double midFreq = 320.0,
    double midGain = 0.0,
    double highGain = 0.0,
  }) {
    _backend.updateMasterEq(
      subCut: subCut,
      lowGain: lowGain,
      midFreq: midFreq,
      midGain: midGain,
      highGain: highGain,
    );
  }

  void updateMasterLimiter({
    bool enabled = true,
    double ceilingDbfs = -0.3,
    double driveDb = 0.0,
    double targetLufs = -14.0,
  }) {
    _backend.updateMasterLimiter(
      enabled: enabled,
      ceilingDbfs: ceilingDbfs,
      driveDb: driveDb,
      targetLufs: targetLufs,
    );
  }

  void updateTrackEq(
    String trackId, {
    required bool enabled,
    required double hpf,
    required double lowGain,
    required double midFreq,
    required double midGain,
    required double midQ,
    required double highGain,
  }) {
    _backend.updateTrackEq(
      trackId,
      enabled: enabled,
      hpf: hpf,
      lowGain: lowGain,
      midFreq: midFreq,
      midGain: midGain,
      midQ: midQ,
      highGain: highGain,
    );
  }

  void updateMasterFx(List<FXInsert> fxRack) {
    _backend.updateMasterFx(fxRack);
  }

  void updateTrackFx(String trackId, List<FXInsert> fxRack, {double volume = 1.0, double pan = 0.0}) {
    _backend.updateTrackFx(trackId, fxRack, volume: volume, pan: pan);
  }

  void invalidateIrCache([String? irName]) {
    _backend.invalidateIrCache(irName);
  }

  /// Updates or modulates an automated parameter on a track's audio graph strip.
  void setTrackParam(String trackId, String targetId, double value) {
    _backend.setTrackParam(trackId, targetId, value);
  }

  /// Triggers a real-time Tape Stop motor deceleration and spin-up effect on a track.
  void triggerTapeStop(String trackId, {double stopTime = 0.8, double spinUpTime = 0.4}) {
    _backend.triggerTapeStop(trackId, stopTime: stopTime, spinUpTime: spinUpTime);
  }

  /// Records DSP execution time in microseconds against audio duration.
  void recordDspExecution(int microsecs, double durationSec) {
    if (durationSec <= 0) return;
    final instantLoad = (microsecs / (durationSec * 1000000.0)).clamp(0.01, 1.0);
    _cpuLoad = (_cpuLoad * 0.75) + (instantLoad * 0.25);
  }

  /// Clears cached PCM audio buffers for a track whose parameters or script changed.
  void invalidateLuaCache(String trackId, [TrackChannel? track]) {
    track?.invalidateParamsHash();
    _pcmCache.removeWhere((key, _) => key.startsWith('${trackId}_'));
  }

  int get pcmCacheCount => _pcmCache.length;

  Map<String, double> getMeterSnapshot() {
    updateMeters();
    return {
      'leftPeak': _leftPeak,
      'rightPeak': _rightPeak,
      'rms': (_leftPeak + _rightPeak) / 2.0,
      'currentTime': currentTime,
      'cpuLoad': _cpuLoad,
      'cpuPercentage': cpuPercentage,
    };
  }

  final Uint8List _meterBuffer = Uint8List(128);

  void disposeTrack(String trackId) {
    _backend.disposeTrackStrip(trackId);
    invalidateLuaCache(trackId);
    _trackLeftPeaks.remove(trackId);
    _trackRightPeaks.remove(trackId);
  }

  DateTime _lastMeterUpdateTime = DateTime.now();
  DateTime _lastNativeMeterCall = DateTime.fromMillisecondsSinceEpoch(0);
  // Separate throttle for visualization-driven meter polls (waveform/spectrum widgets).
  DateTime _lastVizMeterUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Fast pure-Dart meter decay without calling native FFI. Used when idle/stopped.
  void decayMeters() {
    final now = DateTime.now();
    final dt = (now.difference(_lastMeterUpdateTime).inMicroseconds / 1000000.0).clamp(0.001, 0.5);
    _lastMeterUpdateTime = now;
    final decay = math.exp(-dt / 0.15); // Smooth 150ms release
    _leftPeak = (_leftPeak * decay) < 0.001 ? 0.0 : _leftPeak * decay;
    _rightPeak = (_rightPeak * decay) < 0.001 ? 0.0 : _rightPeak * decay;
    _cpuLoad = (_cpuLoad * 0.90) + (0.015 * 0.10);
    _trackLeftPeaks.updateAll((_, val) => (val * decay) < 0.001 ? 0.0 : val * decay);
    _trackRightPeaks.updateAll((_, val) => (val * decay) < 0.001 ? 0.0 : val * decay);
  }

  void updateMeters({bool force = false}) {
    final now = DateTime.now();
    final dt = (now.difference(_lastMeterUpdateTime).inMicroseconds / 1000000.0).clamp(0.001, 0.5);
    _lastMeterUpdateTime = now;

    // Time-constant decay: ~300ms release time for standard ballistic release
    final decay = math.exp(-dt / 0.30);

    final currentAudioTime = currentTime;

    // 1. Prune finished voices (with 100ms grace window for natural release tail)
    _activeVoices.removeWhere((v) => !v.isLooping && (currentAudioTime >= v.startTime + v.durationSec + 0.1));

    if (_activeVoices.isEmpty && !_backend.hasActiveAudioSources) {
      decayMeters();
      return;
    }

    // 2. Measure active voices per track
    final Set<String> mutedTrackIds = {};
    final Map<String, (double, double)> activeTrackLevels = {};
    for (final voice in _activeVoices) {
      if (voice.track.isMuted) {
        mutedTrackIds.add(voice.trackId);
        continue;
      }
      final (lvlLeft, lvlRight) = voice.computeLevelAt(currentAudioTime);
      if (lvlLeft > 0.0001 || lvlRight > 0.0001) {
        final existing = activeTrackLevels[voice.trackId] ?? (0.0, 0.0);
        // Headroom soft saturation when combining polyphonic voices on same track
        final combinedL = 1.0 - (1.0 - existing.$1) * (1.0 - lvlLeft);
        final combinedR = 1.0 - (1.0 - existing.$2) * (1.0 - lvlRight);
        activeTrackLevels[voice.trackId] = (combinedL, combinedR);
      }
    }

    // 3. Query native hardware analyser for master bus
    double hwMasterL = 0.0;
    double hwMasterR = 0.0;
    if (_backend.hasActiveAudioSources) {
      _backend.updateMeters(_meterBuffer, (l, r) {
        hwMasterL = l;
        hwMasterR = r;
      });
      for (int i = 0; i < _timeData.length && i < _meterBuffer.length; i++) {
        _timeData[i] = _meterBuffer[i];
      }
    }

    // 4. Update track peaks with instantaneous attack and smooth ballistic decay
    final allTrackKeys = {..._trackLeftPeaks.keys, ..._trackRightPeaks.keys, ...activeTrackLevels.keys};
    double sumTrackL = 0.0;
    double sumTrackR = 0.0;

    for (final trackId in allTrackKeys) {
      if (mutedTrackIds.contains(trackId)) {
        _trackLeftPeaks[trackId] = 0.0;
        _trackRightPeaks[trackId] = 0.0;
        continue;
      }
      final active = activeTrackLevels[trackId];
      if (active != null) {
        final prevL = _trackLeftPeaks[trackId] ?? 0.0;
        final prevR = _trackRightPeaks[trackId] ?? 0.0;
        _trackLeftPeaks[trackId] = math.max(prevL * decay, active.$1);
        _trackRightPeaks[trackId] = math.max(prevR * decay, active.$2);
      } else {
        final prevL = _trackLeftPeaks[trackId] ?? 0.0;
        final prevR = _trackRightPeaks[trackId] ?? 0.0;
        final newL = prevL * decay;
        final newR = prevR * decay;
        _trackLeftPeaks[trackId] = newL < 0.001 ? 0.0 : newL;
        _trackRightPeaks[trackId] = newR < 0.001 ? 0.0 : newR;
      }
      sumTrackL += _trackLeftPeaks[trackId] ?? 0.0;
      sumTrackR += _trackRightPeaks[trackId] ?? 0.0;
    }

    // 5. Update master peak (blend hardware analyser readout with active track sum)
    final double voiceMasterL = (sumTrackL * 0.85).clamp(0.0, 1.0);
    final double voiceMasterR = (sumTrackR * 0.85).clamp(0.0, 1.0);
    final double targetL = math.max(hwMasterL, voiceMasterL);
    final double targetR = math.max(hwMasterR, voiceMasterR);

    if (targetL > 0.001 || targetR > 0.001) {
      _leftPeak = math.max(_leftPeak * decay, targetL);
      _rightPeak = math.max(_rightPeak * decay, targetR);
    } else {
      _leftPeak = (_leftPeak * decay) < 0.001 ? 0.0 : _leftPeak * decay;
      _rightPeak = (_rightPeak * decay) < 0.001 ? 0.0 : _rightPeak * decay;
    }

    // Smoothly decay CPU meter towards baseline when audio load drops
    if (_leftPeak < 0.001 && _rightPeak < 0.001 && _activeVoices.isEmpty) {
      _cpuLoad = (_cpuLoad * 0.90) + (0.015 * 0.10);
    }
  }

  final Uint8List _trackTapBuffer = Uint8List(256);

  // Helper: compute RMS activity [0.0, 1.0] directly from a byte buffer (values around 128 = silence)
  double _bufferRms(Uint8List buf) {
    if (buf.isEmpty) return 0.0;
    double sum = 0.0;
    for (final b in buf) {
      final v = (b - 128) / 128.0;
      sum += v * v;
    }
    return math.sqrt(sum / buf.length).clamp(0.0, 1.0);
  }

  /// Returns normalized real-time audio waveform samples (-1.0 to 1.0)
  /// If [trackId] is specified, extracts point-in-chain data for that track; otherwise returns master mix.
  List<double> getWaveformSamples({
    String? trackId,
    int count = 64,
    double gain = 1.0,
    double timebase = 1.0,
  }) {
    final now = DateTime.now();
    final isMaster = trackId == null || trackId == 'master_bus' || trackId == 'master' || trackId.toLowerCase().contains('master');
    final targetId = isMaster ? null : trackId;

    if (now.difference(_lastVizMeterUpdateTime).inMilliseconds >= 30) {
      _lastVizMeterUpdateTime = now;
      _backend.getTimeDomainData(_trackTapBuffer, targetId: targetId);
    }

    // Derive activity directly from the buffer RMS — avoids relying solely on decaying note-on peaks
    final bufRms = _bufferRms(_trackTapBuffer);
    final noteOnPeak = isMaster
        ? math.max(_leftPeak, _rightPeak)
        : (trackId != null ? math.max(getTrackLeftPeak(trackId), getTrackRightPeak(trackId)) : 0.0);
    final activity = math.max(bufRms * 4.0, noteOnPeak);

    final result = List<double>.filled(count, 0.0);
    final len = _trackTapBuffer.length;
    if (len == 0) return result;

    final nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final bool isBufferFlat = bufRms < 0.002;

    for (int i = 0; i < count; i++) {
      final idx = ((i * timebase * len / count) % len).toInt();
      final byteVal = _trackTapBuffer[idx];
      double sample = (byteVal - 128) / 128.0;

      if (isBufferFlat && activity > 0.0005) {
        final t = nowSec * 120.0 + (i * timebase * 0.25);
        sample = (math.sin(t) * 0.65 + math.sin(t * 2.1) * 0.25 + math.sin(t * 0.5) * 0.1) * activity;
      }
      result[i] = (sample * gain).clamp(-1.0, 1.0);
    }
    return result;
  }

  /// Returns multi-band normalized frequency spectrum energy (0.0 to 1.0)
  /// If [trackId] is specified, extracts point-in-chain spectrum for that track; otherwise returns master mix.
  List<double> getSpectrumBands({
    String? trackId,
    int bands = 16,
    double gain = 1.0,
    double decay = 0.6,
  }) {
    final now = DateTime.now();
    // Throttle to 30ms (≈33Hz) — same gate as getWaveformSamples.
    if (now.difference(_lastVizMeterUpdateTime).inMilliseconds >= 30) {
      updateMeters();
      _lastVizMeterUpdateTime = now;
    }
    final isMaster = trackId == null || trackId == 'master_bus' || trackId == 'master' || trackId.toLowerCase().contains('master');
    final targetId = isMaster ? null : trackId;

    _backend.getFrequencyData(_trackTapBuffer, targetId: targetId);

    // Derive activity from frequency buffer energy (0 = no signal in FFT)
    final freqEnergy = _trackTapBuffer.fold<double>(0.0, (acc, b) => acc + b) / (255.0 * _trackTapBuffer.length);
    final noteOnPeak = isMaster
        ? math.max(_leftPeak, _rightPeak)
        : (trackId != null ? math.max(getTrackLeftPeak(trackId), getTrackRightPeak(trackId)) : 0.0);
    final activity = math.max(freqEnergy * 4.0, noteOnPeak);

    final result = List<double>.filled(bands, 0.0);
    final len = _trackTapBuffer.length;
    if (len == 0) return result;

    final nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final samplesPerBand = math.max(1, len ~/ bands);
    for (int b = 0; b < bands; b++) {
      double bandSum = 0.0;
      final startIdx = b * samplesPerBand;
      for (int i = 0; i < samplesPerBand && (startIdx + i) < len; i++) {
        final val = _trackTapBuffer[startIdx + i] / 255.0;
        bandSum += val;
      }
      double bandEnergy = (bandSum / samplesPerBand) * 1.8;

      // If frequency buffer is flat but activity exists, synthesize frequency distribution
      if (bandEnergy < 0.01 && activity > 0.0005) {
        final freqCurve = math.exp(-b * (1.8 / bands)) * activity;
        final harmonicPulsing = (math.sin((nowSec * 24.0) + (b * 0.75)).abs() * 0.35) * activity;
        bandEnergy = math.max(bandEnergy, (freqCurve * 0.8 + harmonicPulsing));
      }

      result[b] = (bandEnergy * gain).clamp(0.0, 1.0);
    }
    return result;
  }

  (double left, double right) getPeakLevels({String? trackId}) {
    updateMeters();
    if (trackId == null || trackId == 'master_bus' || trackId == 'master') {
      return (_leftPeak, _rightPeak);
    }
    return (getTrackLeftPeak(trackId), getTrackRightPeak(trackId));
  }

  double get currentTime => _backend.currentTime;

  // ── Note / Sample Playback ─────────────────────────────────────────────────

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
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
  }) {
    if (track.isMuted) return;

    if (!_backend.isInitialized) {
      _backend.ready.then((_) {
        if (!_backend.isInitialized) return;
        playNoteOrSample(
          track: track,
          midiNote: midiNote,
          velocity: velocity,
          durationSec: durationSec,
          scheduledTime: scheduledTime,
          targetMidiNote: targetMidiNote,
          isSlide: isSlide,
          isAccent: isAccent,
          loop: loop,
          articulation: articulation,
          releaseVelocity: releaseVelocity,
          pitchBendPoints: pitchBendPoints,
          pressurePoints: pressurePoints,
          timbrePoints: timbrePoints,
        );
      });
      return;
    }

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

    final bool activeAccent = isAccent || velocity > 0.75;

    final (samples, cacheKey) = _getOrCreateBuffer(
      track: track,
      midiNote: midiNote,
      velocity: velocity,
      durationSec: durationSec,
      targetMidiNote: targetMidiNote,
      isSlide: isSlide,
      isAccent: activeAccent,
      articulation: articulation,
      releaseVelocity: releaseVelocity,
      pitchBendPoints: pitchBendPoints,
      pressurePoints: pressurePoints,
      timbrePoints: timbrePoints,
    );

    if (track.isMonophonicTrack) {
      _activeVoices.removeWhere((v) => v.trackId == track.id);
    }
    while (_activeVoices.length >= 64) {
      _activeVoices.removeAt(0);
    }
    _activeVoices.add(_ActivePlayingVoice(
      track: track,
      startTime: scheduledTime ?? currentTime,
      durationSec: durationSec,
      velocity: velocity,
      samples: samples,
      isLooping: loop,
    ));

    _backend.playPcmBuffer(
      samples,
      outVol,
      track.pan,
      scheduledTime,
      track.id,
      track.isMonophonicTrack,
      isSlide,
      loop,
      track.fxRack,
      bufferCacheKey: cacheKey,
    );
  }

  /// Plays a pre-rendered frozen audio stream for a track channel.
  void playFrozenTrack({
    required TrackChannel track,
    double startOffsetSec = 0.0,
    double? scheduledTime,
  }) {
    if (track.isMuted) return;
    final samples = track.frozenAudioBuffer;
    if (samples == null || samples.isEmpty) return;

    ensureContextRunning();

    final double normVol = (track.volume / 1.5).clamp(0.0, 1.0);
    final double panVal = track.pan.clamp(-1.0, 1.0);
    final double leftPanFactor = panVal <= 0 ? 1.0 : (1.0 - panVal);
    final double rightPanFactor = panVal >= 0 ? 1.0 : (1.0 + panVal);
    final double trkLeft = (normVol * leftPanFactor).clamp(0.0, 1.0);
    final double trkRight = (normVol * rightPanFactor).clamp(0.0, 1.0);

    _trackLeftPeaks[track.id] = math.max(_trackLeftPeaks[track.id] ?? 0.0, trkLeft);
    _trackRightPeaks[track.id] = math.max(_trackRightPeaks[track.id] ?? 0.0, trkRight);
    _leftPeak = math.max(_leftPeak, trkLeft * 0.85);
    _rightPeak = math.max(_rightPeak, trkRight * 0.85);

    _activeVoices.add(_ActivePlayingVoice(
      track: track,
      startTime: scheduledTime ?? currentTime,
      durationSec: math.max(0.0, (samples.length / 44100.0) - startOffsetSec),
      velocity: 1.0,
      samples: samples,
      isLooping: false,
      isFrozen: true,
    ));

    _backend.playFrozenStream(
      trackId: track.id,
      samples: samples,
      startOffsetSec: startOffsetSec,
      volume: normVol,
      pan: track.pan,
      fxRack: track.fxRack,
      scheduledTime: scheduledTime,
    );
  }

  /// Stops frozen stream on a specific track.
  void stopFrozenTrack(String trackId) {
    _backend.stopFrozenStream(trackId);
    _activeVoices.removeWhere((v) => v.trackId == trackId && v.isFrozen);
  }

  /// Stops all active frozen audio streams.
  void stopAllFrozenTracks() {
    _backend.stopAllFrozenStreams();
    _activeVoices.removeWhere((v) => v.isFrozen);
  }

  /// Synthesizes a note PCM buffer for a given track (used for live synthesis and offline baking).
  Float32List synthesizeBufferForTrack({
    required TrackChannel track,
    required int midiNote,
    required double velocity,
    required double durationSec,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
  }) {
    return _synthesizeTrackBuffer(
      track: track,
      midiNote: midiNote,
      velocity: velocity,
      durationSec: durationSec,
      targetMidiNote: targetMidiNote,
      isSlide: isSlide,
      isAccent: isAccent,
      articulation: articulation,
      releaseVelocity: releaseVelocity,
      pitchBendPoints: pitchBendPoints,
      pressurePoints: pressurePoints,
      timbrePoints: timbrePoints,
    );
  }

  // ── Buffer Generation & Caching ────────────────────────────────────────────

  @visibleForTesting
  bool isBufferCached({
    required TrackChannel track,
    required int midiNote,
    required double durationSec,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? articulation,
  }) {
    final hasVariance = (track.luaParams['Variance'] ?? track.luaParams['variance'] ?? 0.0) > 0.001 ||
        (track.luaParams['Variation'] ?? track.luaParams['variation'] ?? 0.0) > 0.001 ||
        (track.luaParams['Humanize'] ?? track.luaParams['humanize'] ?? 0.0) > 0.001;
    if (hasVariance) return false;

    final durMs = (durationSec * 1000).round();
    final pHash = _computeParamsHash(track);
    final targetPitchStr = (isSlide && targetMidiNote != null) ? '_tgt$targetMidiNote' : '';
    final artStr = (articulation != null && articulation.isNotEmpty) ? '_art$articulation' : '';
    final cacheKey = '${track.id}_${midiNote}${targetPitchStr}${artStr}_${durMs}_${isAccent ? 1 : 0}_${isSlide ? 1 : 0}_$pHash';
    return _pcmCache.containsKey(cacheKey);
  }

  (Float32List, String?) _getOrCreateBuffer({
    required TrackChannel track,
    required int midiNote,
    required double velocity,
    required double durationSec,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
  }) {
    final durMs = (durationSec * 1000).round();
    final pHash = _computeParamsHash(track);
    final targetPitchStr = (isSlide && targetMidiNote != null) ? '_tgt$targetMidiNote' : '';
    final artStr = (articulation != null && articulation.isNotEmpty) ? '_art$articulation' : '';
    final hasMpe = (pitchBendPoints != null && pitchBendPoints.isNotEmpty) ||
        (pressurePoints != null && pressurePoints.isNotEmpty) ||
        (timbrePoints != null && timbrePoints.isNotEmpty);
    final hasVariance = (track.luaParams['Variance'] ?? track.luaParams['variance'] ?? 0.0) > 0.001 ||
        (track.luaParams['Variation'] ?? track.luaParams['variation'] ?? 0.0) > 0.001 ||
        (track.luaParams['Humanize'] ?? track.luaParams['humanize'] ?? 0.0) > 0.001;
    final cacheKey = (hasMpe || hasVariance)
        ? null // Do not cache dynamic MPE curves or note-to-note variance to preserve acoustic variation
        : '${track.id}_${midiNote}${targetPitchStr}${artStr}_${durMs}_${isAccent ? 1 : 0}_${isSlide ? 1 : 0}_$pHash';

    if (cacheKey != null) {
      final cached = _pcmCache[cacheKey];
      if (cached != null) {
        return (cached, cacheKey);
      }
    }

    final sw = Stopwatch()..start();
    final buffer = _synthesizeTrackBuffer(
      track: track,
      midiNote: midiNote,
      velocity: velocity,
      durationSec: durationSec,
      targetMidiNote: targetMidiNote,
      isSlide: isSlide,
      isAccent: isAccent,
      articulation: articulation,
      releaseVelocity: releaseVelocity,
      pitchBendPoints: pitchBendPoints,
      pressurePoints: pressurePoints,
      timbrePoints: timbrePoints,
    );
    sw.stop();
    recordDspExecution(sw.elapsedMicroseconds, durationSec);

    if (cacheKey != null) {
      if (_pcmCache.length >= 512) {
        _pcmCache.remove(_pcmCache.keys.first);
      }
      _pcmCache[cacheKey] = buffer;
    }
    return (buffer, cacheKey);
  }

  Float32List _synthesizeTrackBuffer({
    required TrackChannel track,
    required int midiNote,
    required double velocity,
    required double durationSec,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
  }) {
    final isSfTrack = (track.type == TrackType.sampler && track.sampleName.toLowerCase().endsWith('.sf2')) ||
        (track.type == TrackType.luaScript &&
            (track.luaScriptCode.contains('SoundFontSampler') || track.luaScriptCode.contains('SoundFont.readZone')));

    if (isSfTrack) {
      final fontId = track.sampleName.isNotEmpty ? track.sampleName : 'super_small_font.sf2';
      final sfBuffer = SoundFontEngine.instance.getPitchShiftedBuffer(
        fontId: fontId,
        presetNum: (track.luaParams['PresetNum'] ?? 0.0).toInt(),
        bankNum: (track.luaParams['BankNum'] ?? 0.0).toInt(),
        midiNote: midiNote,
        velocity: velocity,
        targetDurationSec: durationSec,
        fallbackDefault: true,
      );
      if (sfBuffer.isNotEmpty) {
        return sfBuffer;
      }
    }

    if (track.type == TrackType.sampler) {
      final customBuffer = SamplerEngine.instance.getPitchShiftedPcm(
          track.sampleName, (midiNote - 60).toDouble());
      if (customBuffer.isNotEmpty) {
        return Float32List.fromList(customBuffer);
      } else {
        return _generateDrumBuffer(track.sampleName);
      }
    } else if (track.type == TrackType.luaScript) {
      final double freq = PolySynth.midiToFreq(midiNote);
      return EatScriptEngine.synthesizeBuffer(
        code: track.luaScriptCode,
        durationSec: durationSec,
        freq: freq,
        note: midiNote,
        params: track.luaParams,
        targetMidiNote: targetMidiNote,
        isSlide: isSlide,
        isAccent: isAccent,
        trackId: track.id,
        articulation: articulation,
        releaseVelocity: releaseVelocity,
        pitchBendPoints: pitchBendPoints,
        pressurePoints: pressurePoints,
        timbrePoints: timbrePoints,
        velocity: velocity,
      );
    } else {
      return PolySynth.generateSynthToneBuffer(
        midiNote: midiNote,
        waveform: track.synthWaveform,
        cutoff: track.cutoff,
        attack: track.attack,
        release: track.release,
        lengthSec: durationSec,
        targetMidiNote: targetMidiNote,
        isSlide: isSlide,
      );
    }
  }

  static Float32List _generateDrumBuffer(String sampleName) {
    switch (sampleName.toLowerCase()) {
      case 'snare':
        return PolySynth.generateSnareBuffer();
      case 'hihat':
      case 'hi-hat':
        return PolySynth.generateHiHatBuffer(open: false);
      case 'openhat':
        return PolySynth.generateHiHatBuffer(open: true);
      case 'clap':
        return PolySynth.generateClapBuffer();
      case 'kick':
      default:
        return PolySynth.generateKickBuffer();
    }
  }

  static int _computeParamsHash(TrackChannel track) {
    return track.paramsHash;
  }

  void stopNote(TrackChannel track, [int? pitch]) {
    _backend.stopTrackNotes(track.id);
    _activeVoices.removeWhere((v) => v.trackId == track.id);
  }

  /// Panic: Immediately stops all playing sources and clears audio meters.
  void stopAllSound() {
    _backend.stopAllSound();
    _activeVoices.clear();
    _leftPeak = 0.0;
    _rightPeak = 0.0;
    _trackLeftPeaks.clear();
    _trackRightPeaks.clear();
  }

  /// Clears all synthesized PCM note/audio caches and buffers.
  void clearPcmCache() {
    _pcmCache.clear();
  }

  /// Flushes backend channel strips, active sources, and PCM caches when changing songs.
  /// Plays a live sustaining note with proper ADSR note-on lifecycle, or one-shot for drums.
  void noteOn({
    required TrackChannel track,
    required int midiNote,
    required double velocity,
    double sustainDurationSec = 2.5,
    String? articulation,
    bool loop = true,
  }) {
    if (track.isMuted) return;

    final bool isDrumLike = track.isDrumTrack ||
        track.sampleName.toLowerCase().contains('drum') ||
        track.luaScriptCode.contains('gm_standard_drum_kit') ||
        track.luaScriptCode.contains('modular_drumpad_kit') ||
        track.luaScriptCode.contains('GmDrumKitEngine');
    final bool effectiveLoop = isDrumLike ? false : loop;

    if (!_backend.isInitialized) {
      _backend.ready.then((_) {
        if (!_backend.isInitialized) return;
        noteOn(
          track: track,
          midiNote: midiNote,
          velocity: velocity,
          sustainDurationSec: sustainDurationSec,
          articulation: articulation,
          loop: loop,
        );
      });
      return;
    }

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

    final (samples, cacheKey) = _getOrCreateBuffer(
      track: track,
      midiNote: midiNote,
      velocity: velocity,
      durationSec: sustainDurationSec,
      articulation: articulation,
    );

    if (track.isMonophonicTrack) {
      _activeVoices.removeWhere((v) => v.trackId == track.id);
    }
    _activeVoices.add(_ActivePlayingVoice(
      track: track,
      startTime: currentTime,
      durationSec: sustainDurationSec,
      velocity: velocity,
      samples: samples,
      isLooping: effectiveLoop,
    ));

    _backend.noteOn(
      samples: samples,
      volume: outVol,
      pan: track.pan,
      trackId: track.id,
      midiNote: midiNote,
      fxRack: track.fxRack,
      isMonophonic: track.isMonophonicTrack,
      bufferCacheKey: cacheKey,
      loop: effectiveLoop,
    );
  }

  /// Releases a live note with smooth ADSR release phase.
  void noteOff({
    required TrackChannel track,
    required int midiNote,
    double releaseSec = 0.12,
  }) {
    _activeVoices.removeWhere((v) => v.trackId == track.id && v.isLooping);
    _backend.noteOff(
      trackId: track.id,
      midiNote: midiNote,
      releaseSec: releaseSec,
    );
  }

  /// Stops all active live sustaining notes.
  void stopAllLiveNotes({String? trackId}) {
    _backend.stopAllLiveNotes(trackId: trackId);
    if (trackId != null) {
      _activeVoices.removeWhere((v) => v.trackId == trackId && v.isLooping);
    } else {
      _activeVoices.removeWhere((v) => v.isLooping);
    }
  }

  void clearChannelStrips() {
    _backend.clearChannelStrips();
    clearPcmCache();
  }

  /// Pre-warms the PCM cache and IR samples so playback has 0 latency.
  /// Uses a JIT lookahead window [lookaheadSteps] (default 16 steps / 1 bar)
  /// from [startStep] to prevent blocking the UI thread on lengthy 24+ bar clips.
  void prewarmPatternCache(
    List<TrackChannel> tracks,
    double stepDurationSec, {
    int startStep = 0,
    int lookaheadSteps = 16,
    bool eagerAll = false,
    ChordEvent? Function(int step)? chordLookup,
  }) {
    final Set<String> activeIrNames = {};
    for (final track in tracks) {
      if (track.isMuted) continue;
      for (final fx in track.fxRack) {
        if (fx.enabled && fx.type == FXType.convolutionReverb && fx.irSampleName != null) {
          activeIrNames.add(fx.irSampleName!);
        }
      }
    }
    if (activeIrNames.isNotEmpty) {
      _backend.preloadIrSamples(activeIrNames);
    }

    final int endStep = eagerAll ? 999999 : (startStep + lookaheadSteps);

    for (final track in tracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips) {
        final int clipStart = clip.startBar * 16;
        final int clipEnd = (clip.startBar + clip.barLength) * 16;

        // Skip clips completely outside the lookahead window
        if (!eagerAll && (clipEnd <= startStep || clipStart >= endStep)) {
          continue;
        }

        final notes = clip.notes;
        for (int nIdx = 0; nIdx < notes.length; nIdx++) {
          final note = notes[nIdx];
          final double absoluteNoteStep = clipStart + note.startStep;

          if (!eagerAll && (absoluteNoteStep < startStep || absoluteNoteStep >= endStep)) {
            continue;
          }

          int? targetPitch;
          final double slideMaxStep = note.startStep + math.max(1.5, note.durationSteps + 0.5);
          if (track.isMonophonicTrack) {
            for (int k = 0; k < notes.length; k++) {
              final n = notes[k];
              if (n.startStep > note.startStep && n.startStep <= slideMaxStep) {
                targetPitch = n.pitch;
                break;
              }
            }
          } else {
            // Polyphonic track: match slide target on the same tracker column
            for (int k = 0; k < notes.length; k++) {
              final n = notes[k];
              if (n.column == note.column && n.startStep > note.startStep && n.startStep <= slideMaxStep) {
                if (n.isSlide) targetPitch = n.pitch;
                break;
              }
            }
          }

          // Remap pitch with harmonic chord track context if active, matching _scheduleStep
          int effectivePitch = note.pitch;
          final chord = chordLookup?.call(absoluteNoteStep.toInt());
          if (chord != null && track.chordFollowMode != ChordFollowMode.off) {
            effectivePitch = ChordTheory.remapPitchForChord(note.pitch, chord, track.chordFollowMode.name);
          }

          int? effectiveTargetPitch = targetPitch;
          if (targetPitch != null && chord != null && track.chordFollowMode != ChordFollowMode.off) {
            effectiveTargetPitch = ChordTheory.remapPitchForChord(targetPitch, chord, track.chordFollowMode.name);
          }

          final hasSlideParam = (track.luaParams['Slide'] ?? 0.0) > 0.01 ||
              (track.luaParams['Portamento'] ?? 0.0) > 0.01 ||
              (track.luaParams['Glide'] ?? 0.0) > 0.01;
          final bool isSlideNote = note.isSlide || hasSlideParam || effectiveTargetPitch != null;
          final bool isAccentNote = note.isAccent || note.velocity > 0.75;
          final double noteDurSec = math.max(0.02, math.min(3.0, stepDurationSec * note.durationSteps));

          _getOrCreateBuffer(
            track: track,
            midiNote: effectivePitch,
            velocity: note.velocity,
            durationSec: noteDurSec,
            isSlide: isSlideNote,
            isAccent: isAccentNote,
            targetMidiNote: effectiveTargetPitch,
          );
        }
      }
    }
  }
}
