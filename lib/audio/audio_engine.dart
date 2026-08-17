import 'dart:math' as math;
import 'dart:typed_data';

import '../models/track_model.dart';
import '../lua/lua_engine.dart';
import 'poly_synth.dart';
import 'sampler_engine.dart';
import 'soundfont_engine.dart';
import 'wajuce_audio_backend.dart';

class AudioEngine {
  final WajuceAudioBackend _backend = WajuceAudioBackend();

  // High-performance PCM buffer cache.
  // Stores synthesized Float32List buffers for notes to eliminate per-note DSP overhead.
  final Map<String, Float32List> _pcmCache = {};

  bool get isInitialized => _backend.isInitialized;

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

  final List<int> _timeData = List<int>.filled(128, 128);
  List<int> get waveformTimeData => _timeData;

  AudioEngine();

  void ensureContextRunning() {
    _backend.ensureContextRunning();
  }

  void setMasterVolume(double volume) {
    _backend.setMasterVolume(volume);
  }

  /// Clears cached PCM audio buffers for a track whose parameters or script changed.
  void invalidateLuaCache(String trackId) {
    _pcmCache.removeWhere((key, _) => key.startsWith('${trackId}_'));
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

  void updateMeters() {
    final u8 = Uint8List.fromList(_timeData);
    _backend.updateMeters(u8, (l, r) {
      _leftPeak = l;
      _rightPeak = r;
    });
    for (int i = 0; i < _timeData.length && i < u8.length; i++) {
      _timeData[i] = u8[i];
    }

    for (final id in _trackLeftPeaks.keys.toList()) {
      final dec = (_trackLeftPeaks[id] ?? 0.0) * 0.82;
      _trackLeftPeaks[id] = dec < 0.001 ? 0.0 : dec;
    }
    for (final id in _trackRightPeaks.keys.toList()) {
      final dec = (_trackRightPeaks[id] ?? 0.0) * 0.82;
      _trackRightPeaks[id] = dec < 0.001 ? 0.0 : dec;
    }
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
  }) {
    if (track.isMuted) return;

    if (!_backend.isInitialized) {
      _backend.ready.then((_) {
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

    // Retrieve or synthesize the PCM buffer
    final (samples, cacheKey) = _getOrCreateBuffer(
      track: track,
      midiNote: midiNote,
      velocity: velocity,
      durationSec: durationSec,
      targetMidiNote: targetMidiNote,
      isSlide: isSlide,
      isAccent: activeAccent,
    );

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

  // ── Buffer Generation & Caching ────────────────────────────────────────────

  (Float32List, String?) _getOrCreateBuffer({
    required TrackChannel track,
    required int midiNote,
    required double velocity,
    required double durationSec,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
  }) {
    // Dynamic legato slides shouldn't use static cache
    if (isSlide && targetMidiNote != null && targetMidiNote != midiNote) {
      final buffer = _synthesizeTrackBuffer(
        track: track,
        midiNote: midiNote,
        velocity: velocity,
        durationSec: durationSec,
        targetMidiNote: targetMidiNote,
        isSlide: true,
        isAccent: isAccent,
      );
      return (buffer, null);
    }

    final durMs = (durationSec * 1000).round();
    final pHash = _computeParamsHash(track);
    final cacheKey = '${track.id}_${midiNote}_${durMs}_${isAccent ? 1 : 0}_$pHash';

    final cached = _pcmCache[cacheKey];
    if (cached != null) {
      return (cached, cacheKey);
    }

    final buffer = _synthesizeTrackBuffer(
      track: track,
      midiNote: midiNote,
      velocity: velocity,
      durationSec: durationSec,
      targetMidiNote: targetMidiNote,
      isSlide: isSlide,
      isAccent: isAccent,
    );

    _pcmCache[cacheKey] = buffer;
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
  }) {
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
        return Float32List.fromList(sfBuffer);
      }
    }

    if (track.type == TrackType.sampler) {
      final customBuffer = SamplerEngine.instance.getPitchShiftedPcm(
          track.sampleName, (midiNote - 60).toDouble());
      if (customBuffer.isNotEmpty) {
        return Float32List.fromList(customBuffer);
      } else {
        return Float32List.fromList(_generateDrumBuffer(track.sampleName));
      }
    } else if (track.type == TrackType.luaScript) {
      final double freq = PolySynth.midiToFreq(midiNote);
      return LuaEngine.synthesizeBuffer(
        code: track.luaScriptCode,
        durationSec: durationSec,
        freq: freq,
        note: midiNote,
        params: track.luaParams,
        targetMidiNote: targetMidiNote,
        isSlide: isSlide,
        isAccent: isAccent,
        trackId: track.id,
      );
    } else {
      return Float32List.fromList(
        PolySynth.generateSynthToneBuffer(
          midiNote: midiNote,
          waveform: track.synthWaveform,
          cutoff: track.cutoff,
          attack: track.attack,
          release: track.release,
          lengthSec: durationSec,
        ),
      );
    }
  }

  static List<double> _generateDrumBuffer(String sampleName) {
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
    int h = track.sampleName.hashCode ^ track.synthWaveform.hashCode;
    for (final e in track.luaParams.entries) {
      h = (h * 31) ^ (e.key.hashCode ^ (e.value * 100).round());
    }
    return h;
  }

  void stopNote(TrackChannel track, [int? pitch]) {
    _backend.stopTrackNotes(track.id);
  }

  /// Pre-warms the PCM cache and IR samples so playback has 0 latency.
  void prewarmPatternCache(List<TrackChannel> tracks, double stepDurationSec) {
    _backend.preloadIrSamples();
    for (final track in tracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips) {
        for (final note in clip.notes) {
          final dur = stepDurationSec * note.durationSteps;
          _getOrCreateBuffer(
            track: track,
            midiNote: note.pitch,
            velocity: note.velocity,
            durationSec: dur,
            isSlide: note.isSlide,
            isAccent: note.isAccent,
            targetMidiNote: null,
          );
        }
      }
    }
  }
}
