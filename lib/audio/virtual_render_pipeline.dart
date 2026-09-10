import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'master_offline_render_engine.dart';

/// Context provided to per-frame macro hooks or video renderers during non-realtime rendering.
class VirtualRenderFrame {
  final int frameIndex;
  final int totalFrames;
  final double virtualTimeSec;
  final double virtualStep;
  final double virtualBar;
  final double progress;
  final Float32List audioLeftSlice;
  final Float32List audioRightSlice;

  const VirtualRenderFrame({
    required this.frameIndex,
    required this.totalFrames,
    required this.virtualTimeSec,
    required this.virtualStep,
    required this.virtualBar,
    required this.progress,
    required this.audioLeftSlice,
    required this.audioRightSlice,
  });
}

/// Configuration options for non-realtime video and audio frame rendering.
class VirtualRenderOptions {
  final int fps;
  final int width;
  final int height;
  final int sampleRate;

  const VirtualRenderOptions({
    this.fps = 30,
    this.width = 1920,
    this.height = 1080,
    this.sampleRate = 44100,
  });
}

/// Virtual non-realtime timeline engine for driving deterministic audio and visual frame exports
/// at arbitrary FPS and arbitrary resolution.
class VirtualRenderPipeline {
  /// Steps through an offline master audio mixdown frame-by-frame, executing [onFrame]
  /// for each virtual frame time tick.
  static Future<void> stepVirtualTimeline({
    required MasterRenderResult audioRender,
    VirtualRenderOptions options = const VirtualRenderOptions(),
    required double bpm,
    Future<void> Function(VirtualRenderFrame frame)? onFrame,
    void Function(double progress, String status)? onProgress,
  }) async {
    final int fps = math.max(1, options.fps);
    final int totalFrames = math.max(1, (audioRender.durationSec * fps).ceil());
    final double stepDurationSec = 60.0 / bpm / 4.0;
    final int sampleRate = audioRender.sampleRate;
    final int totalAudioSamples = audioRender.totalSamples;

    for (int k = 0; k < totalFrames; k++) {
      final double virtualTimeSec = k / fps.toDouble();
      final double virtualStep = virtualTimeSec / stepDurationSec;
      final double virtualBar = virtualStep / 16.0;
      final double progress = (k + 1) / totalFrames.toDouble();

      final int startSample = (k * sampleRate / fps).floor();
      final int endSample = math.min(
        totalAudioSamples,
        ((k + 1) * sampleRate / fps).floor(),
      );

      final int sliceLen = math.max(0, endSample - startSample);
      final Float32List leftSlice = Float32List(sliceLen);
      final Float32List rightSlice = Float32List(sliceLen);

      for (int s = 0; s < sliceLen; s++) {
        leftSlice[s] = audioRender.leftBuffer[startSample + s];
        rightSlice[s] = audioRender.rightBuffer[startSample + s];
      }

      final frame = VirtualRenderFrame(
        frameIndex: k,
        totalFrames: totalFrames,
        virtualTimeSec: virtualTimeSec,
        virtualStep: virtualStep,
        virtualBar: virtualBar,
        progress: progress,
        audioLeftSlice: leftSlice,
        audioRightSlice: rightSlice,
      );

      if (onFrame != null) {
        await onFrame(frame);
      }

      if (k % fps == 0 || k == totalFrames - 1) {
        onProgress?.call(
          progress,
          'Rendering virtual frame ${k + 1}/$totalFrames (${(progress * 100).toInt()}%)...',
        );
        await Future.delayed(Duration.zero);
      }
    }
  }
}
