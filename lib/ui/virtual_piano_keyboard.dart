import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';

import 'widgets/keyboard_touch_controller.dart';

class VirtualPianoKeyboard extends StatefulWidget {
  final DawState dawState;

  const VirtualPianoKeyboard({
    super.key,
    required this.dawState,
  });

  @override
  State<VirtualPianoKeyboard> createState() => _VirtualPianoKeyboardState();
}

class _VirtualPianoKeyboardState extends State<VirtualPianoKeyboard>
    with SingleTickerProviderStateMixin {
  // Drawer state
  bool _isExpanded = false;
  double _expandedHeight = 220.0;
  static const double _minExpandedHeight = 150.0;
  static const double _maxExpandedHeight = 320.0;
  static const double _pullTabHeight = 24.0;

  // Octave state (default Octave 3 => C3 = 48)
  int _baseOctave = 3; // MIDI note 48 (C3)
  static const int _octavesCount = 3; // Shows 3 octaves (36 keys)

  late final KeyboardTouchController _touchController = KeyboardTouchController(
    orientation: KeyboardOrientation.horizontal,
    baseOctave: _baseOctave,
    octavesCount: _octavesCount,
    onNoteOn: (pitch, velocity) {
      final track = widget.dawState.activeTrack;
      widget.dawState.audioEngine.noteOn(
        track: track,
        midiNote: pitch,
        velocity: velocity,
        sustainDurationSec: 0.85,
      );
      if (track.activeView == MusicViewType.tracker) {
        widget.dawState.addOrUpdateTrackerNote(
          pitch: pitch,
          velocity: velocity,
          autoAdvance: true,
        );
      }
    },
    onNoteOff: (pitch) {
      final track = widget.dawState.activeTrack;
      widget.dawState.audioEngine.noteOff(
        track: track,
        midiNote: pitch,
        releaseSec: 0.12,
      );
    },
  );

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _touchController.addListener(_onTouchesChanged);
  }

  void _onTouchesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _touchController.removeListener(_onTouchesChanged);
    _touchController.clearAllTouches();
    _touchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _shiftOctave(int delta) {
    setState(() {
      _baseOctave = (_baseOctave + delta).clamp(1, 6);
      _touchController.setBaseOctave(_baseOctave);
    });
  }

  String _getNoteName(int midiPitch) => KeyboardTouchController.getNoteName(midiPitch);
  bool _isBlackKey(int midiPitch) => KeyboardTouchController.isBlackKey(midiPitch);

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final activeTrack = widget.dawState.activeTrack;
    final trackColor = activeTrack.color;

    final double totalHeight = _isExpanded ? _pullTabHeight + _expandedHeight : _pullTabHeight;

    return Container(
      width: double.infinity,
      height: totalHeight,
      decoration: BoxDecoration(
        color: isGrungy ? const Color(0xFF1B1815) : EatsTheme.panelBackground,
        border: Border(
          top: BorderSide(
            color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.panelHeader,
            width: 1.5,
          ),
        ),
      ),
      child: ClipRect(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // Drag / Pull Tab Header
          GestureDetector(
            onTap: _toggleExpand,
            onVerticalDragUpdate: (details) {
              setState(() {
                if (!_isExpanded && details.delta.dy < -2) {
                  _isExpanded = true;
                } else if (_isExpanded) {
                  _expandedHeight = (_expandedHeight - details.delta.dy)
                      .clamp(_minExpandedHeight, _maxExpandedHeight);
                  if (_expandedHeight <= _minExpandedHeight + 10 && details.delta.dy > 5) {
                    _isExpanded = false;
                    _expandedHeight = 220.0;
                  }
                }
              });
            },
            child: Container(
              height: _pullTabHeight - 1.5,
              width: double.infinity,
              color: isGrungy ? const Color(0xFF28231E) : EatsTheme.panelHeader,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Tab visual pill
                  Container(
                    width: 70,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isGrungy ? const Color(0xFF8C7A6B) : EatsTheme.textMuted,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.piano,
                          size: 14,
                          color: _isExpanded ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PIANO KEYBOARD',
                          style: TextStyle(
                            color: _isExpanded ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    child: Icon(
                      _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      size: 16,
                      color: EatsTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Virtual Piano Drawer Body
          if (_isExpanded)
            Expanded(
              child: Column(
                children: [
                  // Top Control Strip (Track Info, Octave Controls, Active Notes Display)
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: isGrungy ? const Color(0xFF201C18) : const Color(0xFF171922),
                    child: Row(
                      children: [
                        // Active Track Selector / Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: trackColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: trackColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: trackColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<int>(
                                initialValue: widget.dawState.activeTrackIndex,
                                onSelected: (idx) {
                                  widget.dawState.activeTrackIndex = idx;
                                },
                                tooltip: 'Select Track',
                                style: ButtonStyle(
                                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                                  minimumSize: WidgetStateProperty.all(Size.zero),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      activeTrack.name.toUpperCase(),
                                      style: TextStyle(
                                        color: trackColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                                  ],
                                ),
                                itemBuilder: (context) {
                                  return List.generate(
                                    widget.dawState.activePattern.tracks.length,
                                    (idx) {
                                      final trk = widget.dawState.activePattern.tracks[idx];
                                      return PopupMenuItem<int>(
                                        value: idx,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: trk.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              trk.name,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Active Pressed Note & Velocity Display
                        if (_touchController.activeTouches.isNotEmpty)
                          Builder(builder: (context) {
                            final touch = _touchController.activeTouches.values.last;
                            final noteName = _getNoteName(touch.pitch);
                            final velPercent = (touch.velocity * 100).round();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: EatsTheme.primaryCyan.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: EatsTheme.primaryCyan, width: 1),
                              ),
                              child: Text(
                                '$noteName | VEL: $velPercent%',
                                style: TextStyle(
                                  color: EatsTheme.primaryCyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),

                        const Spacer(),

                        // Octave Navigation Controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'OCT:',
                              style: TextStyle(
                                color: EatsTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              color: _baseOctave > 1 ? EatsTheme.textPrimary : EatsTheme.textMuted.withOpacity(0.5),
                              onPressed: _baseOctave > 1 ? () => _shiftOctave(-1) : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: EatsTheme.controlBackground,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'C$_baseOctave - C${_baseOctave + 2}',
                                style: TextStyle(
                                  color: EatsTheme.primaryCyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              color: _baseOctave < 6 ? EatsTheme.textPrimary : EatsTheme.textMuted.withOpacity(0.5),
                              onPressed: _baseOctave < 6 ? () => _shiftOctave(1) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Piano Keys Canvas Container
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final keyWidth = constraints.maxWidth;
                        final keyHeight = constraints.maxHeight;

                        return Listener(
                          onPointerDown: (e) {
                            _touchController.handlePointerDown(e, e.localPosition, Size(keyWidth, keyHeight));
                          },
                          onPointerMove: (e) {
                            _touchController.handlePointerMove(e, e.localPosition, Size(keyWidth, keyHeight));
                          },
                          onPointerUp: (e) => _touchController.handlePointerUpOrCancel(e.pointer),
                          onPointerCancel: (e) => _touchController.handlePointerUpOrCancel(e.pointer),
                          child: CustomPaint(
                            size: Size(keyWidth, keyHeight),
                            painter: _PianoKeyboardPainter(
                              baseOctave: _baseOctave,
                              octavesCount: _octavesCount,
                              activeTouches: _touchController.activeTouches.values.toList(),
                              trackColor: trackColor,
                              isGrungy: isGrungy,
                            ),
                          ),
                        );
                      },
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

class _PianoKeyboardPainter extends CustomPainter {
  final int baseOctave;
  final int octavesCount;
  final List<KeyboardActiveTouch> activeTouches;
  final Color trackColor;
  final bool isGrungy;

  _PianoKeyboardPainter({
    required this.baseOctave,
    required this.octavesCount,
    required this.activeTouches,
    required this.trackColor,
    required this.isGrungy,
  });

  bool _isBlackKey(int midiPitch) {
    final noteInOctave = midiPitch % 12;
    return noteInOctave == 1 ||
        noteInOctave == 3 ||
        noteInOctave == 6 ||
        noteInOctave == 8 ||
        noteInOctave == 10;
  }

  String _getNoteName(int midiPitch) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final name = names[midiPitch % 12];
    final octave = (midiPitch / 12).floor() - 1;
    return '$name$octave';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final startPitch = (baseOctave + 1) * 12; // C3 = 48
    final totalNotes = octavesCount * 12; // 36 keys

    // Count white keys
    int whiteKeyCount = 0;
    for (int p = startPitch; p < startPitch + totalNotes; p++) {
      if (!_isBlackKey(p)) whiteKeyCount++;
    }

    final double whiteKeyWidth = size.width / whiteKeyCount;
    final double blackKeyWidth = whiteKeyWidth * 0.65;
    final double blackKeyHeight = size.height * 0.60;

    // Active touch pitch map
    final activePitches = <int, KeyboardActiveTouch>{};
    for (final t in activeTouches) {
      activePitches[t.pitch] = t;
    }

    // 1. Draw White Keys
    int currentWhiteIdx = 0;
    for (int p = startPitch; p < startPitch + totalNotes; p++) {
      if (!_isBlackKey(p)) {
        final double left = currentWhiteIdx * whiteKeyWidth;
        final Rect keyRect = Rect.fromLTWH(left, 0, whiteKeyWidth, size.height);
        final bool isActive = activePitches.containsKey(p);
        final activeTouch = activePitches[p];

        // White Key Background
        final Paint keyPaint = Paint();
        if (isActive) {
          keyPaint.color = Color.lerp(
            const Color(0xFFE2EAFA),
            trackColor,
            0.45,
          )!;
        } else {
          keyPaint.color = isGrungy ? const Color(0xFFDCD8CF) : const Color(0xFFF2F4F8);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(keyRect, const Radius.circular(3)),
          keyPaint,
        );

        // Velocity Fill Bar on active touch (Y-axis visual feedback, top to touch position)
        if (isActive && activeTouch != null) {
          final double velHeight = size.height * activeTouch.velocity;
          final Rect velRect = Rect.fromLTWH(
            left + 2,
            0,
            whiteKeyWidth - 4,
            velHeight,
          );
          final Paint velPaint = Paint()..color = trackColor.withOpacity(0.75);
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              velRect,
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2),
              bottomLeft: velHeight >= size.height - 4 ? const Radius.circular(2) : Radius.zero,
              bottomRight: velHeight >= size.height - 4 ? const Radius.circular(2) : Radius.zero,
            ),
            velPaint,
          );
        }

        // Key Border & Separator
        final Paint borderPaint = Paint()
          ..color = isGrungy ? const Color(0xFF5C5248) : Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawRect(keyRect, borderPaint);

        // Note Name Label at bottom of key (especially for 'C' notes or active keys)
        final String name = _getNoteName(p);
        final bool isC = name.startsWith('C') && !name.contains('#');
        if (isC || isActive) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: name,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.black54,
                fontSize: math.min(10.0, whiteKeyWidth * 0.45),
                fontWeight: isC ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              left + (whiteKeyWidth - textPainter.width) / 2,
              size.height - textPainter.height - 4,
            ),
          );
        }

        currentWhiteIdx++;
      }
    }

    // 2. Draw Black Keys (Overlaid)
    currentWhiteIdx = 0;
    for (int p = startPitch; p < startPitch + totalNotes; p++) {
      if (_isBlackKey(p)) {
        final double left = (currentWhiteIdx * whiteKeyWidth) - (blackKeyWidth / 2.0);
        final Rect keyRect = Rect.fromLTWH(left, 0, blackKeyWidth, blackKeyHeight);
        final bool isActive = activePitches.containsKey(p);
        final activeTouch = activePitches[p];

        final Paint keyPaint = Paint();
        if (isActive) {
          keyPaint.color = Color.lerp(const Color(0xFF2A2E3D), trackColor, 0.75)!;
        } else {
          keyPaint.color = isGrungy ? const Color(0xFF2B2520) : const Color(0xFF1E222A);
        }

        // Drop shadow under black key
        final Paint shadowPaint = Paint()
          ..color = Colors.black45
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left - 1, 0, blackKeyWidth + 2, blackKeyHeight + 3),
            bottomLeft: const Radius.circular(3),
            bottomRight: const Radius.circular(3),
          ),
          shadowPaint,
        );

        // Black key body
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            keyRect,
            bottomLeft: const Radius.circular(3),
            bottomRight: const Radius.circular(3),
          ),
          keyPaint,
        );

        // Velocity Fill Bar on active touch for black key (top to touch position)
        if (isActive && activeTouch != null) {
          final double velHeight = blackKeyHeight * activeTouch.velocity;
          final Rect velRect = Rect.fromLTWH(
            left + 1,
            0,
            blackKeyWidth - 2,
            velHeight,
          );
          final Paint velPaint = Paint()..color = trackColor.withOpacity(0.85);
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              velRect,
              bottomLeft: velHeight >= blackKeyHeight - 2 ? const Radius.circular(3) : Radius.zero,
              bottomRight: velHeight >= blackKeyHeight - 2 ? const Radius.circular(3) : Radius.zero,
            ),
            velPaint,
          );
        }

        // Highlight top rim bevel
        final Paint bevelPaint = Paint()
          ..color = isActive ? trackColor : Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(left + 2, blackKeyHeight - 2),
          Offset(left + blackKeyWidth - 2, blackKeyHeight - 2),
          bevelPaint,
        );
      } else {
        currentWhiteIdx++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PianoKeyboardPainter oldDelegate) {
    return oldDelegate.baseOctave != baseOctave ||
        oldDelegate.octavesCount != octavesCount ||
        oldDelegate.activeTouches != activeTouches ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.isGrungy != isGrungy;
  }
}
