import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../models/chord_model.dart';
import '../../theme/eats_theme.dart';

/// High-performance FL Studio-style minimap overview scrollbar for Eatsbeats Arranger.
///
/// Features:
/// - Miniature track lanes with track-colored clip blocks and core highlights
/// - Mini chord track lane in accent gold
/// - Shaded loop region overlay
/// - Smooth live playhead indicator connected to [DawState.continuousArrangerStepNotifier]
/// - Real-time responsive glassmorphic viewport lens (scrollbar thumb) supporting instant tap-to-jump and 1:1 live drag scrubbing
/// - 0 memory allocation during paint passes via static reusable [Paint] and [Path] instances
class ArrangerMinimapScrollbar extends StatefulWidget {
  final DawState dawState;
  final ScrollController horizontalScroll;
  final double barWidth;
  final int totalBars;
  final double height;

  const ArrangerMinimapScrollbar({
    super.key,
    required this.dawState,
    required this.horizontalScroll,
    required this.barWidth,
    required this.totalBars,
    this.height = 26.0,
  });

  @override
  State<ArrangerMinimapScrollbar> createState() => _ArrangerMinimapScrollbarState();
}

class _ArrangerMinimapScrollbarState extends State<ArrangerMinimapScrollbar> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1017),
        border: Border(
          top: BorderSide(color: const Color(0xFF1E2330), width: 1.0),
          bottom: BorderSide(color: const Color(0xFF1E2330), width: 1.0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width <= 0) return const SizedBox.shrink();

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _handlePointerDown(event.localPosition.dx, width);
            },
            onPointerMove: (event) {
              if (_isDragging) {
                _handlePointerMove(event.delta.dx, width);
              }
            },
            onPointerUp: (event) {
              if (_isDragging && mounted) {
                setState(() => _isDragging = false);
              }
            },
            onPointerCancel: (event) {
              if (_isDragging && mounted) {
                setState(() => _isDragging = false);
              }
            },
            child: MouseRegion(
              cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  widget.horizontalScroll,
                  widget.dawState,
                  widget.dawState.continuousArrangerStepNotifier,
                ]),
                builder: (context, _) {
                  final double scrollOffset = widget.horizontalScroll.hasClients
                      ? widget.horizontalScroll.offset
                      : 0.0;

                  return RepaintBoundary(
                    child: CustomPaint(
                      size: Size(width, widget.height),
                      painter: _MinimapPainter(
                        dawState: widget.dawState,
                        horizontalScroll: widget.horizontalScroll,
                        scrollOffset: scrollOffset,
                        barWidth: widget.barWidth,
                        totalBars: widget.totalBars,
                        isDragging: _isDragging,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePointerDown(double localX, double totalWidth) {
    if (!widget.horizontalScroll.hasClients || totalWidth <= 0 || widget.totalBars <= 0) return;

    final position = widget.horizontalScroll.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final totalArrangerWidth = widget.totalBars * widget.barWidth;
    final viewportDimension = position.viewportDimension;
    final thumbWidth = (viewportDimension / totalArrangerWidth * totalWidth).clamp(24.0, totalWidth);
    final availableTrack = totalWidth - thumbWidth;
    if (availableTrack <= 0) return;

    final scrollOffset = position.pixels;
    final thumbStartX = (scrollOffset / totalArrangerWidth * totalWidth).clamp(0.0, availableTrack);

    setState(() => _isDragging = true);

    final isInsideThumb = localX >= thumbStartX && localX <= (thumbStartX + thumbWidth);
    if (!isInsideThumb) {
      // Center the thumb directly on the tapped position
      final targetThumbLeft = (localX - (thumbWidth / 2.0)).clamp(0.0, availableTrack);
      final targetScroll = (targetThumbLeft / availableTrack) * maxScroll;
      widget.horizontalScroll.jumpTo(targetScroll.clamp(0.0, maxScroll));
    }
  }

  void _handlePointerMove(double deltaDx, double totalWidth) {
    if (!widget.horizontalScroll.hasClients || totalWidth <= 0 || widget.totalBars <= 0 || deltaDx == 0.0) return;

    final position = widget.horizontalScroll.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final totalArrangerWidth = widget.totalBars * widget.barWidth;
    final viewportDimension = position.viewportDimension;
    final thumbWidth = (viewportDimension / totalArrangerWidth * totalWidth).clamp(24.0, totalWidth);
    final availableTrack = totalWidth - thumbWidth;
    if (availableTrack <= 0) return;

    // Scale minimap pixel delta to horizontal scroll units
    final scrollDelta = deltaDx * (maxScroll / availableTrack);
    final newScroll = (position.pixels + scrollDelta).clamp(0.0, maxScroll);
    widget.horizontalScroll.jumpTo(newScroll);
  }
}

class _MinimapPainter extends CustomPainter {
  final DawState dawState;
  final ScrollController horizontalScroll;
  final double scrollOffset;
  final double barWidth;
  final int totalBars;
  final bool isDragging;

  _MinimapPainter({
    required this.dawState,
    required this.horizontalScroll,
    required this.scrollOffset,
    required this.barWidth,
    required this.totalBars,
    required this.isDragging,
  });

  // Pre-allocated static reusable Paint and Path instances (0 allocation during repaint)
  static final Paint _bgPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _gridPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _chordPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _clipPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _clipCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round;
  static final Paint _loopFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _loopBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _thumbFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _thumbBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final Paint _thumbGripPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _playheadPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final Paint _playheadNotchPaint = Paint()..style = PaintingStyle.fill;
  static final Path _playheadNotchPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || totalBars <= 0) return;

    final width = size.width;
    final height = size.height;

    // 1. Background fill
    _bgPaint.color = const Color(0xFF0B0E14);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), _bgPaint);

    // 2. Bar grid markers (every 4 bars subtle, every 16 bars prominent)
    final double barPixelW = width / totalBars;
    _gridPaint.strokeWidth = 0.5;
    for (int b = 4; b < totalBars; b += 4) {
      final x = b * barPixelW;
      final isMajor = (b % 16 == 0);
      _gridPaint.color = isMajor ? const Color(0x35FFFFFF) : const Color(0x14FFFFFF);
      canvas.drawLine(Offset(x, 0), Offset(x, height), _gridPaint);
    }

    // 3. Shaded loop region overlay (if looping enabled)
    if (dawState.isLooping && dawState.loopEndBar > dawState.loopStartBar) {
      final loopStartX = (dawState.loopStartBar / totalBars) * width;
      final loopEndX = (dawState.loopEndBar / totalBars) * width;
      final loopW = math.max(1.0, loopEndX - loopStartX);

      _loopFillPaint.color = EatsTheme.accentGold.withOpacity(0.13);
      canvas.drawRect(Rect.fromLTWH(loopStartX, 0, loopW, height), _loopFillPaint);

      _loopBorderPaint.color = EatsTheme.accentGold.withOpacity(0.6);
      canvas.drawLine(Offset(loopStartX, 0), Offset(loopStartX, height), _loopBorderPaint);
      canvas.drawLine(Offset(loopEndX, 0), Offset(loopEndX, height), _loopBorderPaint);
    }

    // 4. Chords Lane (Top 3.5px)
    const double chordLaneH = 3.5;
    if (dawState.chordTrack.isNotEmpty) {
      _chordPaint.color = EatsTheme.accentGold.withOpacity(0.85);
      for (final chord in dawState.chordTrack) {
        final double chordX = (chord.startBar / totalBars) * width;
        final double chordW = math.max(1.5, (chord.barLength / totalBars) * width);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(chordX, 1.0, chordW, chordLaneH),
          const Radius.circular(0.8),
        );
        canvas.drawRRect(rect, _chordPaint);
      }
    }

    // 5. Track Lanes & Clips
    final tracks = dawState.visibleTracks;
    final int numTracks = tracks.length;
    if (numTracks > 0) {
      const double startY = 5.5;
      final double availH = height - startY - 2.0;
      final double laneH = (availH / numTracks).clamp(1.8, 6.0);

      for (int t = 0; t < numTracks; t++) {
        final track = tracks[t];
        final laneY = startY + (t * laneH);

        // Clips in this track
        for (final clip in track.clips) {
          final clipX = (clip.startBar / totalBars) * width;
          final clipW = math.max(2.0, (clip.barLength / totalBars) * width);
          final clipRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(clipX, laneY + 0.4, clipW, math.max(1.2, laneH - 0.6)),
            const Radius.circular(1.0),
          );

          // Track clip block fill
          _clipPaint.color = track.color.withOpacity(track.isMuted ? 0.28 : 0.85);
          canvas.drawRRect(clipRect, _clipPaint);

          // Subtle tonal interior core line for clips with notes or audio
          if (clip.notes.isNotEmpty || clip.isAudioClip || track.notes.isNotEmpty) {
            _clipCorePaint.color = Colors.white.withOpacity(0.4);
            final midY = laneY + (laneH * 0.5);
            canvas.drawLine(
              Offset(clipX + 0.8, midY),
              Offset(clipX + clipW - 0.8, midY),
              _clipCorePaint,
            );
          }
        }
      }
    }

    // 6. Active Viewport Lens (Scrollbar Thumb)
    double thumbStartX = 0.0;
    double thumbWidth = width;
    if (horizontalScroll.hasClients && horizontalScroll.position.maxScrollExtent > 0) {
      final totalArrangerW = totalBars * barWidth;
      final viewportDimension = horizontalScroll.position.viewportDimension;
      thumbWidth = (viewportDimension / totalArrangerW * width).clamp(24.0, width);
      thumbStartX = (scrollOffset / totalArrangerW * width).clamp(0.0, width - thumbWidth);
    }

    final thumbRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(thumbStartX, 1.0, thumbWidth, height - 2.0),
      const Radius.circular(3.0),
    );

    // Thumb fill (glassmorphic cyan tint)
    _thumbFillPaint.color = EatsTheme.primaryCyan.withOpacity(isDragging ? 0.26 : 0.16);
    canvas.drawRRect(thumbRRect, _thumbFillPaint);

    // Thumb border
    _thumbBorderPaint.color = EatsTheme.primaryCyan.withOpacity(isDragging ? 0.95 : 0.65);
    canvas.drawRRect(thumbRRect, _thumbBorderPaint);

    // Subtle 3-tick center grip marks if thumb is wide enough
    if (thumbWidth >= 36.0) {
      final centerX = thumbStartX + (thumbWidth / 2.0);
      final midY = height / 2.0;
      _thumbGripPaint.color = EatsTheme.primaryCyan.withOpacity(isDragging ? 0.8 : 0.5);
      canvas.drawLine(Offset(centerX - 3.5, midY - 3.5), Offset(centerX - 3.5, midY + 3.5), _thumbGripPaint);
      canvas.drawLine(Offset(centerX, midY - 4.5), Offset(centerX, midY + 4.5), _thumbGripPaint);
      canvas.drawLine(Offset(centerX + 3.5, midY - 3.5), Offset(centerX + 3.5, midY + 3.5), _thumbGripPaint);
    }

    // 7. Live Arranger Playhead (Continuous Sub-Pixel Motion)
    final double step = dawState.continuousArrangerStepNotifier.value;
    final double curBar = step / 16.0;
    final double playheadX = (curBar / totalBars) * width;

    if (playheadX >= 0 && playheadX <= width) {
      _playheadPaint.color = EatsTheme.primaryCyan;
      canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, height), _playheadPaint);

      // Top notch / triangle
      _playheadNotchPaint.color = EatsTheme.primaryCyan;
      _playheadNotchPath.reset();
      _playheadNotchPath.moveTo(playheadX - 2.5, 0);
      _playheadNotchPath.lineTo(playheadX + 2.5, 0);
      _playheadNotchPath.lineTo(playheadX, 4.0);
      _playheadNotchPath.close();
      canvas.drawPath(_playheadNotchPath, _playheadNotchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.totalBars != totalBars ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.dawState.arrangerStep != dawState.arrangerStep ||
        oldDelegate.dawState.loopStartBar != dawState.loopStartBar ||
        oldDelegate.dawState.loopEndBar != dawState.loopEndBar ||
        oldDelegate.dawState.isLooping != dawState.isLooping ||
        oldDelegate.dawState.chordTrack.length != dawState.chordTrack.length ||
        oldDelegate.dawState.visibleTracks.length != dawState.visibleTracks.length;
  }
}
