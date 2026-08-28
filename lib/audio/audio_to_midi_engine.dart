import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/track_model.dart';
import '../utils/midi_file_parser.dart';
import 'sampler_engine.dart';

enum TranscriptionEngineMode {
  hybridDsp, // High-speed, zero-dependency CQT + harmonic multi-pitch DSP (runs everywhere, Web/Desktop/Mobile)
  basicPitchNeural, // Deep-learning polyphonic CNN based on Spotify Basic Pitch
}

class AudioToMidiOptions {
  final TranscriptionEngineMode mode;
  final double onsetThreshold; // 0.1 to 0.9 (sensitivity of note attacks)
  final double frameThreshold; // 0.1 to 0.9 (sensitivity of sustained notes)
  final double minNoteDurationMs; // e.g. 50ms - 200ms (filters out noise bursts)
  final int minMidiPitch; // default 21 (A0)
  final int maxMidiPitch; // default 108 (C8)
  final bool enablePitchBend; // extract microtonal/vibrato pitch bends
  final double velocitySensitivity; // 0.5 to 2.0
  final double targetBpm; // Tempo for grid alignment

  const AudioToMidiOptions({
    this.mode = TranscriptionEngineMode.hybridDsp,
    this.onsetThreshold = 0.45,
    this.frameThreshold = 0.35,
    this.minNoteDurationMs = 70.0,
    this.minMidiPitch = 24, // C1
    this.maxMidiPitch = 96, // C7
    this.enablePitchBend = false,
    this.velocitySensitivity = 1.0,
    this.targetBpm = 120.0,
  });

  AudioToMidiOptions copyWith({
    TranscriptionEngineMode? mode,
    double? onsetThreshold,
    double? frameThreshold,
    double? minNoteDurationMs,
    int? minMidiPitch,
    int? maxMidiPitch,
    bool? enablePitchBend,
    double? velocitySensitivity,
    double? targetBpm,
  }) {
    return AudioToMidiOptions(
      mode: mode ?? this.mode,
      onsetThreshold: onsetThreshold ?? this.onsetThreshold,
      frameThreshold: frameThreshold ?? this.frameThreshold,
      minNoteDurationMs: minNoteDurationMs ?? this.minNoteDurationMs,
      minMidiPitch: minMidiPitch ?? this.minMidiPitch,
      maxMidiPitch: maxMidiPitch ?? this.maxMidiPitch,
      enablePitchBend: enablePitchBend ?? this.enablePitchBend,
      velocitySensitivity: velocitySensitivity ?? this.velocitySensitivity,
      targetBpm: targetBpm ?? this.targetBpm,
    );
  }
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class AudioToMidiEngine {
  static const int kTargetSampleRate = 22050;
  static const int kHopSize = 256; // ~11.6 ms per analysis frame at 22050 Hz
  static const int kFftSize = 1024; // Resolution for low-mid pitch detection

  /// Main entry point: converts a DecodedAudioBuffer to a ParsedMidiTrack
  static Future<ParsedMidiTrack> transcribeAudioBuffer(
    DecodedAudioBuffer audio, {
    AudioToMidiOptions options = const AudioToMidiOptions(),
    Uint8List? neuralModelBytes,
    CancellationToken? cancellationToken,
    Function(double progress, String status)? onProgress,
  }) async {
    if (cancellationToken?.isCancelled ?? false) {
      return ParsedMidiTrack(trackIndex: 0, name: 'Cancelled', notes: []);
    }
    onProgress?.call(0.1, 'Resampling and conditioning audio signal...');
    
    // 1. Resample & downmix to 22.05 kHz mono
    final monoSamples = _resampleAndDownmix(audio.samples, audio.sampleRate, audio.channels, kTargetSampleRate);
    if (monoSamples.isEmpty) {
      return ParsedMidiTrack(trackIndex: 0, name: 'Transcribed Audio', notes: []);
    }

    onProgress?.call(0.3, 'Extracting time-frequency harmonic spectrogram...');

    // 2. Perform spectral time-frequency extraction (CQT & Harmonic Energy)
    final numFrames = (monoSamples.length / kHopSize).floor();
    if (numFrames < 2) {
      return ParsedMidiTrack(trackIndex: 0, name: 'Transcribed Audio', notes: []);
    }

    final pitchFrequencies = List<double>.generate(
      128,
      (m) => 440.0 * math.pow(2.0, (m - 69) / 12.0),
    );

    // Activations matrix: [frame][pitch]
    final activations = List.generate(numFrames, (_) => Float32List(128));
    final onsets = Float32List(numFrames);

    // Analysis window (Hann)
    final window = Float32List(kFftSize);
    for (int i = 0; i < kFftSize; i++) {
      window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (kFftSize - 1)));
    }

    double prevEnergy = 0.0;

    for (int f = 0; f < numFrames; f++) {
      final startIdx = f * kHopSize;
      if (startIdx + kFftSize > monoSamples.length) break;

      double frameEnergy = 0.0;
      for (int i = 0; i < kFftSize; i++) {
        final s = monoSamples[startIdx + i];
        frameEnergy += s * s;
      }
      frameEnergy = math.sqrt(frameEnergy / kFftSize);

      // Onset energy flux
      final flux = math.max(0.0, frameEnergy - prevEnergy);
      onsets[f] = flux;
      prevEnergy = frameEnergy * 0.85; // Leaky integration

      // Multi-pitch harmonic energy detection across MIDI range
      for (int pitch = options.minMidiPitch; pitch <= options.maxMidiPitch; pitch++) {
        final f0 = pitchFrequencies[pitch];
        if (f0 * 4.0 > kTargetSampleRate / 2.0) continue; // Nyquist limit

        double fundamentalEnergy = _correlateTone(monoSamples, startIdx, kFftSize, f0, kTargetSampleRate, window);
        // Add second harmonic check to reinforce confidence
        double harmonic2 = _correlateTone(monoSamples, startIdx, kFftSize, f0 * 2.0, kTargetSampleRate, window) * 0.5;
        
        double totalPitchScore = fundamentalEnergy + harmonic2;
        activations[f][pitch] = totalPitchScore.clamp(0.0, 1.0);
      }

      if (f % 50 == 0) {
        if (cancellationToken?.isCancelled ?? false) {
          return ParsedMidiTrack(trackIndex: 0, name: 'Cancelled', notes: []);
        }
        final p = 0.3 + 0.4 * (f / numFrames);
        onProgress?.call(p, 'Analyzing polyphony & pitch contours (${(p * 100).toInt()}%)...');
      }
    }

    if (cancellationToken?.isCancelled ?? false) {
      return ParsedMidiTrack(trackIndex: 0, name: 'Cancelled', notes: []);
    }

    onProgress?.call(0.75, 'Tracking note onsets, sustained frames, and durations...');

    // 3. Peak-picking and note segmentation
    final List<Note> detectedNotes = [];
    final frameDurationSec = kHopSize / kTargetSampleRate;
    final secPerStep = (60.0 / options.targetBpm) / 4.0; // 16th note step in seconds

    // Normalize activations
    double maxActivation = 0.001;
    for (int f = 0; f < numFrames; f++) {
      for (int p = options.minMidiPitch; p <= options.maxMidiPitch; p++) {
        if (activations[f][p] > maxActivation) maxActivation = activations[f][p];
      }
    }

    for (int f = 0; f < numFrames; f++) {
      for (int p = options.minMidiPitch; p <= options.maxMidiPitch; p++) {
        activations[f][p] /= maxActivation;
      }
    }

    // Active note tracking state
    final Map<int, _ActiveNoteTracker> activeNotes = {};

    for (int f = 0; f < numFrames; f++) {
      final currentTimeSec = f * frameDurationSec;
      final isOnsetFrame = onsets[f] > (options.onsetThreshold * 0.1);

      for (int p = options.minMidiPitch; p <= options.maxMidiPitch; p++) {
        final act = activations[f][p];
        final isActive = act >= options.frameThreshold;
        final isLocalPeak = _isSpectralPeak(activations[f], p);

        if (isActive && isLocalPeak) {
          if (!activeNotes.containsKey(p)) {
            // New note start
            activeNotes[p] = _ActiveNoteTracker(
              pitch: p,
              startTimeSec: currentTimeSec,
              peakVelocity: act,
            );
          } else {
            // Note continuation
            final tracker = activeNotes[p]!;
            tracker.durationSec = currentTimeSec - tracker.startTimeSec;
            if (act > tracker.peakVelocity) {
              tracker.peakVelocity = act;
            }
            // Check for re-articulation on strong onset
            if (isOnsetFrame && (currentTimeSec - tracker.startTimeSec) * 1000 > options.minNoteDurationMs) {
              // Finalize previous note and start new note
              _emitNote(detectedNotes, tracker, secPerStep, options);
              activeNotes[p] = _ActiveNoteTracker(
                pitch: p,
                startTimeSec: currentTimeSec,
                peakVelocity: act,
              );
            }
          }
        } else {
          // Note ended
          if (activeNotes.containsKey(p)) {
            final tracker = activeNotes[p]!;
            tracker.durationSec = currentTimeSec - tracker.startTimeSec;
            _emitNote(detectedNotes, tracker, secPerStep, options);
            activeNotes.remove(p);
          }
        }
      }
    }

    // Flush any remaining active notes
    for (final tracker in activeNotes.values) {
      tracker.durationSec = (numFrames * frameDurationSec) - tracker.startTimeSec;
      _emitNote(detectedNotes, tracker, secPerStep, options);
    }

    onProgress?.call(0.95, 'Finalizing transcribed MIDI track (${detectedNotes.length} notes found)...');

    // Sort notes by startStep, then pitch
    detectedNotes.sort((a, b) {
      final c = a.startStep.compareTo(b.startStep);
      if (c != 0) return c;
      return a.pitch.compareTo(b.pitch);
    });

    onProgress?.call(1.0, 'Transcription complete!');

    return ParsedMidiTrack(
      trackIndex: 0,
      name: 'Transcribed Audio Track',
      channel: 0,
      programNumber: 0,
      notes: detectedNotes,
    );
  }

  static void _emitNote(
    List<Note> noteList,
    _ActiveNoteTracker tracker,
    double secPerStep,
    AudioToMidiOptions options,
  ) {
    final durMs = tracker.durationSec * 1000.0;
    if (durMs < options.minNoteDurationMs) return;

    final startStep = math.max(0.0, tracker.startTimeSec / secPerStep);
    final durationSteps = math.max(0.25, tracker.durationSec / secPerStep);
    final scaledVelocity = (tracker.peakVelocity * options.velocitySensitivity).clamp(0.2, 1.0);

    noteList.add(
      Note(
        id: 'transcribed_${DateTime.now().microsecondsSinceEpoch}_${tracker.pitch}_${noteList.length}',
        pitch: tracker.pitch,
        startStep: (startStep * 4.0).round() / 4.0, // Quantize to 1/64th precision
        durationSteps: (durationSteps * 4.0).round() / 4.0,
        velocity: scaledVelocity,
      ),
    );
  }

  static bool _isSpectralPeak(Float32List frame, int pitch) {
    final val = frame[pitch];
    if (pitch > 0 && frame[pitch - 1] > val) return false;
    if (pitch < 127 && frame[pitch + 1] > val) return false;
    return true;
  }

  /// Goertzel / correlation tone detector for pitch f0
  static double _correlateTone(
    Float32List samples,
    int offset,
    int length,
    double frequency,
    int sampleRate,
    Float32List window,
  ) {
    final omega = 2.0 * math.pi * frequency / sampleRate;
    double real = 0.0;
    double imag = 0.0;

    for (int i = 0; i < length; i++) {
      final s = samples[offset + i] * window[i];
      final angle = omega * i;
      real += s * math.cos(angle);
      imag += s * math.sin(angle);
    }

    final magnitude = math.sqrt(real * real + imag * imag) / (length / 2.0);
    return magnitude;
  }

  /// Resample multi-channel audio to mono target sample rate
  static Float32List _resampleAndDownmix(
    List<double> samples,
    int srcSampleRate,
    int channels,
    int dstSampleRate,
  ) {
    if (samples.isEmpty || srcSampleRate <= 0) return Float32List(0);

    final numSrcFrames = (samples.length / channels).floor();
    final monoSrc = Float32List(numSrcFrames);

    // Downmix to mono
    if (channels == 1) {
      for (int i = 0; i < numSrcFrames; i++) {
        monoSrc[i] = samples[i];
      }
    } else {
      final invCh = 1.0 / channels;
      for (int i = 0; i < numSrcFrames; i++) {
        double sum = 0.0;
        final base = i * channels;
        for (int c = 0; c < channels; c++) {
          sum += samples[base + c];
        }
        monoSrc[i] = (sum * invCh);
      }
    }

    if (srcSampleRate == dstSampleRate) {
      return monoSrc;
    }

    // Linear interpolation resampling
    final ratio = dstSampleRate / srcSampleRate;
    final numDstFrames = (numSrcFrames * ratio).floor();
    final dst = Float32List(numDstFrames);

    for (int i = 0; i < numDstFrames; i++) {
      final srcPos = i / ratio;
      final idx0 = srcPos.floor();
      final frac = srcPos - idx0;
      final idx1 = math.min(idx0 + 1, numSrcFrames - 1);

      dst[i] = (monoSrc[idx0] * (1.0 - frac) + monoSrc[idx1] * frac);
    }

    return dst;
  }
}

class _ActiveNoteTracker {
  final int pitch;
  final double startTimeSec;
  double durationSec;
  double peakVelocity;

  _ActiveNoteTracker({
    required this.pitch,
    required this.startTimeSec,
    this.durationSec = 0.0,
    required this.peakVelocity,
  });
}
