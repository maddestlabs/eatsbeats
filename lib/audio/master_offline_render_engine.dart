import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import 'audio_engine.dart';
import 'track_freeze_engine.dart';
import 'offline_dsp_fx_processor.dart';
import 'wav_exporter.dart';

/// Progress callback for master offline rendering.
typedef MasterRenderProgressCallback = void Function(double progress, String status);

/// Encapsulates the output of a master offline audio mixdown.
class MasterRenderResult {
  final Float32List leftBuffer;
  final Float32List rightBuffer;
  final Uint8List wavBytes;
  final double durationSec;
  final int totalSamples;
  final int sampleRate;
  final double peakDbfs;

  const MasterRenderResult({
    required this.leftBuffer,
    required this.rightBuffer,
    required this.wavBytes,
    required this.durationSec,
    required this.totalSamples,
    required this.sampleRate,
    required this.peakDbfs,
  });
}

/// Offline master DSP render engine that renders an entire song or section across all
/// tracks into a pristine, stereo 16-bit PCM WAV stream with equal-power panning,
/// track FX, master EQ, master FX rack, and master bus limiting.
class MasterOfflineRenderEngine {
  /// Computes the effective timeline duration in bars across tracks.
  static int computeEffectiveSongBars(List<TrackChannel> tracks, {int defaultMinBars = 4}) {
    int maxBar = defaultMinBars;
    for (final track in tracks) {
      if (track.isFolder) continue;
      for (final clip in track.clips) {
        final end = clip.startBar + clip.barLength;
        if (end > maxBar) maxBar = end;
      }
      for (final note in track.notes) {
        final endBar = ((note.startStep + note.durationSteps) / 16.0).ceil();
        if (endBar > maxBar) maxBar = endBar;
      }
      for (int s = 0; s < track.steps.length; s++) {
        if (track.steps[s].active) {
          final endBar = ((s + 1) / 16.0).ceil();
          if (endBar > maxBar) maxBar = endBar;
        }
      }
    }
    return maxBar;
  }

  /// Renders all active tracks offline into a stereo WAV mixdown.
  static Future<MasterRenderResult> renderSongOffline({
    required List<TrackChannel> tracks,
    required AudioEngine audioEngine,
    TrackChannel? masterTrack,
    String songKey = 'C Major',
    double bpm = 120.0,
    int? totalTimelineBars,
    int sampleRate = 44100,
    double masterVolume = 1.0,
    double masterSubCut = 25.0,
    double masterLowGain = 0.0,
    double masterMidFreq = 1000.0,
    double masterMidGain = 0.0,
    double masterHighGain = 0.0,
    bool masterLimiterEnabled = true,
    double masterCeilingDbfs = -0.3,
    double tailReleaseSec = 1.5,
    bool includeFx = true,
    MasterRenderProgressCallback? onProgress,
  }) async {
    final int effectiveBars = totalTimelineBars ?? computeEffectiveSongBars(tracks);
    final double stepDurationSec = 60.0 / bpm / 4.0;
    final double barDurationSec = stepDurationSec * 16.0;
    final double songDurationSec = effectiveBars * barDurationSec;
    final double totalDurationSec = songDurationSec + tailReleaseSec;
    final int totalSamples = math.max(1, (totalDurationSec * sampleRate).ceil());

    onProgress?.call(0.02, 'Allocating master mixdown buffers (${(totalSamples * 8 / (1024 * 1024)).toStringAsFixed(1)} MB)...');
    await Future.delayed(Duration.zero);

    final Float32List leftMaster = Float32List(totalSamples);
    final Float32List rightMaster = Float32List(totalSamples);

    // Solo & Mute filtering
    final bool anySolo = tracks.any((t) => t.isSoloed);
    final List<TrackChannel> renderTracks = tracks.where((t) {
      if (t.isFolder) return false;
      if (anySolo) return t.isSoloed;
      return !t.isMuted;
    }).toList();

    final int numTracks = renderTracks.length;
    if (numTracks == 0) {
      onProgress?.call(1.0, 'No active tracks to render (silence complete).');
      final wavBytes = WavExporter.encodeWav(
        leftSamples: leftMaster,
        rightSamples: rightMaster,
        sampleRate: sampleRate,
      );
      return MasterRenderResult(
        leftBuffer: leftMaster,
        rightBuffer: rightMaster,
        wavBytes: wavBytes,
        durationSec: totalDurationSec,
        totalSamples: totalSamples,
        sampleRate: sampleRate,
        peakDbfs: -100.0,
      );
    }

    // Render each track offline (including track MIDI FX, synth DSP, and track Audio FX)
    for (int tIdx = 0; tIdx < numTracks; tIdx++) {
      final track = renderTracks[tIdx];
      final double trackStartProgress = 0.05 + (0.80 * tIdx / numTracks);
      final double trackSpanProgress = 0.80 / numTracks;

      onProgress?.call(
        trackStartProgress,
        'Rendering track ${tIdx + 1}/$numTracks ("${track.name}")...',
      );
      await Future.delayed(Duration.zero);

      Float32List trackAudio;
      if (track.isFrozen && track.frozenAudioBuffer != null) {
        trackAudio = track.frozenAudioBuffer!;
      } else {
        trackAudio = await TrackFreezeEngine.renderTrackOffline(
          track: track,
          audioEngine: audioEngine,
          bpm: bpm,
          songKey: songKey,
          totalTimelineBars: effectiveBars,
          sampleRate: sampleRate,
          includeFx: includeFx,
          onProgress: (p, msg) {
            final overallP = trackStartProgress + (trackSpanProgress * p);
            onProgress?.call(overallP, 'Track "${track.name}": $msg');
          },
        );
      }

      // Equal-power stereo panning
      final double panClamped = track.pan.clamp(-1.0, 1.0);
      final double panAngle = (panClamped + 1.0) * (math.pi / 4.0); // 0 to pi/2
      final double leftPanGain = math.cos(panAngle);
      final double rightPanGain = math.sin(panAngle);

      final int mixSamples = math.min(trackAudio.length, totalSamples);
      for (int s = 0; s < mixSamples; s++) {
        final sample = trackAudio[s];
        leftMaster[s] += sample * leftPanGain;
        rightMaster[s] += sample * rightPanGain;
      }
    }

    // ────────────────────────────────────────────────────────────────────────
    // Master Bus Processing (Master Mixer Channel)
    // ────────────────────────────────────────────────────────────────────────

    // 1. Master EQ & Sub-cut
    onProgress?.call(0.86, 'Mastering bus: applying Master EQ & sub-cut...');
    await Future.delayed(Duration.zero);
    OfflineDspFxProcessor.processMasterEq(
      leftMaster,
      rightMaster,
      subCutFreq: masterSubCut,
      lowGainDb: masterLowGain,
      midFreq: masterMidFreq,
      midGainDb: masterMidGain,
      highGainDb: masterHighGain,
      sampleRate: sampleRate,
    );

    // 2. Master Audio FX Rack
    if (includeFx && masterTrack != null && masterTrack.fxRack.any((f) => f.enabled && f.mix > 0.0)) {
      onProgress?.call(0.89, 'Mastering bus: processing Master FX Rack (${masterTrack.fxRack.length} inserts)...');
      await Future.delayed(Duration.zero);
      OfflineDspFxProcessor.processStereoFx(
        leftMaster,
        rightMaster,
        fxRack: masterTrack.fxRack,
        bpm: bpm,
        sampleRate: sampleRate,
      );
    }

    // 3. Master Volume & Limiter
    onProgress?.call(0.92, 'Mastering bus: applying volume & peak limiter...');
    await Future.delayed(Duration.zero);

    final double effectiveMasterGain = (masterVolume / 1.5).clamp(0.0, 2.0);
    for (int i = 0; i < totalSamples; i++) {
      leftMaster[i] *= effectiveMasterGain;
      rightMaster[i] *= effectiveMasterGain;
    }

    // Peak measurement
    double maxPeak = 0.0;
    for (int i = 0; i < totalSamples; i++) {
      final l = leftMaster[i].abs();
      final r = rightMaster[i].abs();
      if (l > maxPeak) maxPeak = l;
      if (r > maxPeak) maxPeak = r;
    }

    final double ceilingLinear = math.pow(10.0, masterCeilingDbfs / 20.0).toDouble().clamp(0.01, 1.0);
    if (masterLimiterEnabled && maxPeak > ceilingLinear) {
      final double attenuation = ceilingLinear / maxPeak;
      for (int i = 0; i < totalSamples; i++) {
        leftMaster[i] *= attenuation;
        rightMaster[i] *= attenuation;
      }
      maxPeak = ceilingLinear;
    }

    final double peakDbfs = maxPeak > 0 ? 20.0 * math.log(maxPeak) / math.ln10 : -100.0;

    // Encode to WAV
    onProgress?.call(0.95, 'Encoding stereo 16-bit WAV file...');
    await Future.delayed(Duration.zero);

    final Uint8List wavBytes = WavExporter.encodeWav(
      leftSamples: leftMaster,
      rightSamples: rightMaster,
      sampleRate: sampleRate,
    );

    onProgress?.call(1.0, 'Song mixdown complete (${totalDurationSec.toStringAsFixed(1)}s, ${peakDbfs.toStringAsFixed(1)} dBFS peak).');

    return MasterRenderResult(
      leftBuffer: leftMaster,
      rightBuffer: rightMaster,
      wavBytes: wavBytes,
      durationSec: totalDurationSec,
      totalSamples: totalSamples,
      sampleRate: sampleRate,
      peakDbfs: peakDbfs,
    );
  }
}
