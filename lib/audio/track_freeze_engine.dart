import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/track_model.dart';
import 'audio_engine.dart';

/// Callback for reporting freeze progress from 0.0 to 1.0.
typedef FreezeProgressCallback = void Function(double progress, String status);

/// Offline DSP rendering engine that bakes a [TrackChannel] into a contiguous
/// Float32 PCM audio stream.
class TrackFreezeEngine {
  /// Computes a deterministic content hash for a track's scripts, notes, parameters, and FX.
  static String computeTrackHash(TrackChannel track, {double bpm = 120.0, int timelineBars = 16}) {
    final buffer = StringBuffer();
    buffer.write('${track.id}|${track.type.name}|${track.name}|${track.synthWaveform}|');
    buffer.write('${track.sampleName}|${track.cutoff}|${track.resonance}|${track.attack}|${track.release}|');
    buffer.write('bpm:$bpm|bars:$timelineBars|');
    buffer.write('luaCode:${track.luaScriptCode.hashCode}|');
    
    // Parameters
    final sortedParamKeys = track.luaParams.keys.toList()..sort();
    for (final k in sortedParamKeys) {
      buffer.write('$k:${track.luaParams[k]};');
    }

    // Notes & Steps
    if (track.clips.isNotEmpty) {
      for (final clip in track.clips) {
        buffer.write('clip:${clip.id}_${clip.startBar}_${clip.barLength}_${clip.effectiveLoopLengthBars}_${clip.luaScriptCode.hashCode}_');
        for (final n in clip.notes) {
          buffer.write('${n.pitch},${n.startStep},${n.durationSteps},${n.velocity},${n.isSlide ? 1 : 0},${n.isAccent ? 1 : 0};');
        }
      }
    } else if (track.notes.isNotEmpty) {
      for (final n in track.notes) {
        buffer.write('n:${n.pitch},${n.startStep},${n.durationSteps},${n.velocity},${n.isSlide ? 1 : 0},${n.isAccent ? 1 : 0};');
      }
    } else {
      for (int i = 0; i < track.steps.length; i++) {
        final s = track.steps[i];
        if (s.active) {
          buffer.write('s:$i,${s.pitch},${s.velocity},${s.isSlide ? 1 : 0};');
        }
      }
    }

    // FX Rack
    for (final fx in track.fxRack) {
      if (fx.enabled) {
        buffer.write('fx:${fx.id}_${fx.type.name}_${fx.mix}_${fx.irSampleName}_${fx.luaScriptCode?.hashCode}_');
        for (final entry in fx.params.entries) {
          buffer.write('${entry.key}:${entry.value};');
        }
      }
    }

    final raw = buffer.toString();
    // 64-bit FNV-1a hash formatted as hex (using BigInt for cross-platform Web/JS compatibility)
    final fnvPrime = BigInt.parse('100000001b3', radix: 16);
    final mask64 = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    for (int i = 0; i < raw.length; i++) {
      hash = ((hash ^ BigInt.from(raw.codeUnitAt(i))) * fnvPrime) & mask64;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Bakes the given [track] across the song timeline into a contiguous stereo/mono [Float32List].
  ///
  /// Uses non-blocking microtask chunking so the UI remains 60fps responsive on Web
  /// and mobile browsers.
  static Future<Float32List> renderTrackOffline({
    required TrackChannel track,
    required AudioEngine audioEngine,
    double bpm = 120.0,
    int totalTimelineBars = 16,
    int sampleRate = 44100,
    bool includeFx = true,
    FreezeProgressCallback? onProgress,
  }) async {
    final double stepDurationSec = 60.0 / bpm / 4.0;
    final double barDurationSec = stepDurationSec * 16.0;
    final int safeTotalBars = math.max(1, totalTimelineBars);
    final double totalDurationSec = safeTotalBars * barDurationSec;
    final int totalSamples = (totalDurationSec * sampleRate).ceil();

    if (totalSamples <= 0) return Float32List(0);

    onProgress?.call(0.05, 'Allocating audio buffer (${(totalSamples * 4 / (1024 * 1024)).toStringAsFixed(1)} MB)...');
    await Future.delayed(Duration.zero);

    final Float32List masterBuffer = Float32List(totalSamples);

    // 1. Collect all note events with absolute step positions
    final List<_ScheduledNoteEvent> events = [];

    if (track.clips.isNotEmpty) {
      for (final clip in track.clips) {
        final int clipStartStep = clip.startBar * 16;
        final int clipTotalSteps = clip.barLength * 16;
        final int loopSteps = clip.effectiveLoopLengthBars * 16;

        final List<Note> sourceNotes = clip.notes.isNotEmpty ? clip.notes : track.notes;
        if (sourceNotes.isEmpty) continue;

        if (loopSteps > 0 && loopSteps < clipTotalSteps) {
          // Looped clip: repeat notes over clip span
          int repOffset = 0;
          while (repOffset < clipTotalSteps) {
            for (final n in sourceNotes) {
              final double absStep = clipStartStep + repOffset + n.startStep;
              if (absStep < clipStartStep + clipTotalSteps) {
                events.add(_ScheduledNoteEvent(
                  note: n,
                  absStartStep: absStep,
                  durationSec: math.max(0.02, n.durationSteps * stepDurationSec),
                ));
              }
            }
            repOffset += loopSteps;
          }
        } else {
          for (final n in sourceNotes) {
            final double absStep = clipStartStep + n.startStep;
            if (absStep < clipStartStep + clipTotalSteps) {
              events.add(_ScheduledNoteEvent(
                note: n,
                absStartStep: absStep,
                durationSec: math.max(0.02, n.durationSteps * stepDurationSec),
              ));
            }
          }
        }
      }
    } else if (track.notes.isNotEmpty) {
      // Pattern mode notes
      for (final n in track.notes) {
        events.add(_ScheduledNoteEvent(
          note: n,
          absStartStep: n.startStep,
          durationSec: math.max(0.02, n.durationSteps * stepDurationSec),
        ));
      }
    } else {
      // Step sequencer fallback
      for (int sIdx = 0; sIdx < track.steps.length; sIdx++) {
        final s = track.steps[sIdx];
        if (s.active) {
          final nextStep = track.steps[(sIdx + 1) % track.steps.length];
          final bool isSlideStep = s.isSlide || (track.isMonophonicTrack && nextStep.active);
          final int? targetPitch = nextStep.active ? nextStep.pitch : null;

          events.add(_ScheduledNoteEvent(
            note: Note(
              id: 'step_$sIdx',
              pitch: s.pitch,
              startStep: sIdx.toDouble(),
              durationSteps: 1.0,
              velocity: s.velocity,
              isSlide: isSlideStep,
              isAccent: s.isAccent,
            ),
            absStartStep: sIdx.toDouble(),
            durationSec: stepDurationSec,
            targetMidiNote: targetPitch,
          ));
        }
      }
    }

    events.sort((a, b) => a.absStartStep.compareTo(b.absStartStep));

    final int totalEvents = events.length;
    if (totalEvents == 0) {
      onProgress?.call(1.0, 'Track is empty (silent render complete)');
      return masterBuffer;
    }

    // 2. Synthesize each note event and overlay onto masterBuffer
    for (int i = 0; i < totalEvents; i++) {
      final ev = events[i];
      final double noteStartSec = ev.absStartStep * stepDurationSec;
      final int startSampleIdx = (noteStartSec * sampleRate).round();

      if (startSampleIdx >= totalSamples) continue;

      // Synthesize PCM via AudioEngine
      final Float32List notePcm = audioEngine.synthesizeBufferForTrack(
        track: track,
        midiNote: ev.note.pitch,
        velocity: ev.note.velocity,
        durationSec: ev.durationSec,
        targetMidiNote: ev.targetMidiNote,
        isSlide: ev.note.isSlide,
        isAccent: ev.note.isAccent,
        articulation: ev.note.articulation,
        releaseVelocity: ev.note.releaseVelocity ?? 0.5,
        pitchBendPoints: ev.note.pitchBendPoints,
        pressurePoints: ev.note.pressurePoints,
        timbrePoints: ev.note.timbrePoints,
      );

      final double trackVolNorm = (track.volume / 1.5).clamp(0.0, 1.0);
      final double noteGain = (trackVolNorm * ev.note.velocity).clamp(0.0, 1.0);

      // Mix samples into master buffer
      final int samplesToMix = math.min(notePcm.length, totalSamples - startSampleIdx);
      for (int s = 0; s < samplesToMix; s++) {
        final int targetIdx = startSampleIdx + s;
        masterBuffer[targetIdx] += notePcm[s] * noteGain;
      }

      // Non-blocking UI yield every 8 notes
      if (i % 8 == 0 || i == totalEvents - 1) {
        final progress = 0.1 + (0.75 * (i + 1) / totalEvents);
        onProgress?.call(progress, 'Baking note ${i + 1}/$totalEvents (${((i + 1) * 100 / totalEvents).toInt()}%)...');
        await Future.delayed(Duration.zero);
      }
    }

    // 3. Post-render processing: soft peak limiter / normalization
    onProgress?.call(0.90, 'Normalizing & limiting peaks...');
    await Future.delayed(Duration.zero);

    double maxPeak = 0.0;
    for (int i = 0; i < totalSamples; i++) {
      final absVal = masterBuffer[i].abs();
      if (absVal > maxPeak) maxPeak = absVal;
    }

    if (maxPeak > 0.99) {
      final double attenuation = 0.98 / maxPeak;
      for (int i = 0; i < totalSamples; i++) {
        masterBuffer[i] *= attenuation;
      }
    }

    onProgress?.call(1.0, 'Bake complete (${(totalDurationSec).toStringAsFixed(1)}s audio ready)');
    return masterBuffer;
  }
}

class _ScheduledNoteEvent {
  final Note note;
  final double absStartStep;
  final double durationSec;
  final int? targetMidiNote;

  _ScheduledNoteEvent({
    required this.note,
    required this.absStartStep,
    required this.durationSec,
    this.targetMidiNote,
  });
}
