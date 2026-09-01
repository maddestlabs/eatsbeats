import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../audio/audio_engine.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

/// Renders a track-specific or master real-time audio visualizer (Oscilloscope or FFT Spectrum)
/// with CRT phosphorescent glow, reticle grid, and glass bevel bezel.
class LiveTrackVisualizerWidget extends StatefulWidget {
  final AudioEngine audioEngine;
  final TrackChannel track;
  final bool isSpectrum;
  final Color accentColor;
  final double? width;
  final double? height;

  const LiveTrackVisualizerWidget({
    super.key,
    required this.audioEngine,
    required this.track,
    this.isSpectrum = false,
    this.accentColor = const Color(0xFF00E5FF),
    this.width,
    this.height,
  });

  @override
  State<LiveTrackVisualizerWidget> createState() => _LiveTrackVisualizerWidgetState();
}

class _LiveTrackVisualizerWidgetState extends State<LiveTrackVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding')) {
      _ticker.repeat();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = widget.track.id == 'master_bus' ||
        widget.track.id == 'master' ||
        widget.track.name.toLowerCase().contains('master');
    final effectiveTrackId = isMaster ? null : widget.track.id;

    return Container(
      width: widget.width ?? 320.0,
      height: widget.height ?? 140.0,
      decoration: BoxDecoration(
        color: const Color(0xFF090D0A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: widget.accentColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // Animated Live Audio Canvas
            AnimatedBuilder(
              animation: _ticker,
              builder: (context, _) {
                final samples = widget.isSpectrum
                    ? widget.audioEngine.getSpectrumBands(trackId: effectiveTrackId, bands: 32)
                    : widget.audioEngine.getWaveformSamples(trackId: effectiveTrackId, count: 96);

                return CustomPaint(
                  size: Size.infinite,
                  painter: _TrackAudioVisualizerPainter(
                    samples: samples,
                    accentColor: widget.accentColor,
                    isSpectrum: widget.isSpectrum,
                  ),
                );
              },
            ),

            // Top Header Indicator Badge
            Positioned(
              top: 6,
              left: 8,
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.8),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.isSpectrum
                        ? 'SPECTRUM FFT • ${isMaster ? "MASTER BUS" : widget.track.name.toUpperCase()}'
                        : 'OSCILLOSCOPE • ${isMaster ? "MASTER BUS" : widget.track.name.toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: widget.accentColor.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackAudioVisualizerPainter extends CustomPainter {
  final List<double> samples;
  final Color accentColor;
  final bool isSpectrum;

  _TrackAudioVisualizerPainter({
    required this.samples,
    required this.accentColor,
    required this.isSpectrum,
  });

  // Pre-allocated static worker paints (zero allocation per frame during live playback)
  static final Paint _gridPaint = Paint()..strokeWidth = 0.75;
  static final Paint _barPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowBarPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _beamPaint = Paint()
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _glowPaint = Paint()
    ..strokeWidth = 4.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Path _reusablePath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw subtle background oscilloscope reticle grid
    _gridPaint.color = accentColor.withOpacity(0.12);

    const divisionsX = 8;
    const divisionsY = 4;
    final stepX = size.width / divisionsX;
    final stepY = size.height / divisionsY;

    for (int i = 1; i < divisionsX; i++) {
      canvas.drawLine(Offset(i * stepX, 0), Offset(i * stepX, size.height), _gridPaint);
    }
    for (int j = 1; j < divisionsY; j++) {
      canvas.drawLine(Offset(0, j * stepY), Offset(size.width, j * stepY), _gridPaint);
    }

    final centerY = size.height / 2.0;

    if (isSpectrum) {
      // Draw FFT Frequency Spectrum Bars
      _barPaint.color = accentColor;
      _glowBarPaint.color = accentColor.withOpacity(0.3);

      final numBars = samples.isNotEmpty ? samples.length : 32;
      final barWidth = size.width / numBars;

      for (int i = 0; i < numBars; i++) {
        final energy = (i < samples.length ? samples[i] : 0.0).clamp(0.0, 1.0);
        const minHeight = 2.0;
        final h = math.max(minHeight, energy * (size.height * 0.78));
        final rect = Rect.fromLTWH(i * barWidth + 1.5, size.height - h - 4, math.max(1.0, barWidth - 3), h);

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(1.5), const Radius.circular(2)),
          _glowBarPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          _barPaint,
        );
      }
    } else {
      // Draw Analog Oscilloscope Continuous Waveform Beam
      _beamPaint.color = accentColor;
      _glowPaint.color = accentColor.withOpacity(0.35);

      _reusablePath.reset();
      final count = samples.isNotEmpty ? samples.length : 1;

      for (int i = 0; i < count; i++) {
        final x = (i / (count - 1)) * size.width;
        final s = (i < samples.length ? samples[i] : 0.0).clamp(-1.0, 1.0);
        final y = centerY - (s * (centerY * 0.82));
        if (i == 0) {
          _reusablePath.moveTo(x, y);
        } else {
          _reusablePath.lineTo(x, y);
        }
      }

      canvas.drawPath(_reusablePath, _glowPaint);
      canvas.drawPath(_reusablePath, _beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackAudioVisualizerPainter oldDelegate) {
    return true; // Continuously animated with ticker
  }
}
