import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum KeyboardOrientation {
  horizontal,
  vertical,
}

class KeyboardActiveTouch {
  final int pointerId;
  final int pitch;
  final double velocity;
  final bool isBlack;

  KeyboardActiveTouch({
    required this.pointerId,
    required this.pitch,
    required this.velocity,
    required this.isBlack,
  });

  KeyboardActiveTouch copyWith({
    int? pointerId,
    int? pitch,
    double? velocity,
    bool? isBlack,
  }) {
    return KeyboardActiveTouch(
      pointerId: pointerId ?? this.pointerId,
      pitch: pitch ?? this.pitch,
      velocity: velocity ?? this.velocity,
      isBlack: isBlack ?? this.isBlack,
    );
  }
}

/// A unified controller managing coordinate-to-pitch mapping, velocity calculation,
/// multi-touch glissando dragging, and note-on / note-off ADSR lifecycle for both
/// horizontal (Virtual Keyboard) and vertical (Piano Roll) keyboards.
class KeyboardTouchController extends ChangeNotifier {
  final KeyboardOrientation orientation;
  int baseOctave;
  final int octavesCount;
  final int minPitch;
  final int maxPitch;
  final double keyHeight;
  final void Function(int pitch, double velocity)? onNoteOn;
  final void Function(int pitch)? onNoteOff;

  final Map<int, KeyboardActiveTouch> _activeTouches = {};
  Map<int, KeyboardActiveTouch> get activeTouches => Map.unmodifiable(_activeTouches);

  KeyboardTouchController({
    this.orientation = KeyboardOrientation.horizontal,
    this.baseOctave = 3,
    this.octavesCount = 3,
    this.minPitch = 0,
    this.maxPitch = 127,
    this.keyHeight = 24.0,
    this.onNoteOn,
    this.onNoteOff,
  });

  static bool isBlackKey(int midiPitch) {
    final noteInOctave = midiPitch % 12;
    return noteInOctave == 1 ||
        noteInOctave == 3 ||
        noteInOctave == 6 ||
        noteInOctave == 8 ||
        noteInOctave == 10;
  }

  static String getNoteName(int midiPitch) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final name = names[midiPitch % 12];
    final octave = (midiPitch / 12).floor() - 1;
    return '$name$octave';
  }

  void setBaseOctave(int newOctave) {
    if (baseOctave != newOctave) {
      clearAllTouches();
      baseOctave = newOctave;
      notifyListeners();
    }
  }

  KeyboardActiveTouch? pitchAndVelocityFromOffset(
    Offset pos,
    Size size, {
    int? maxPitchOverride,
    double? keyHeightOverride,
  }) {
    if (orientation == KeyboardOrientation.horizontal) {
      return _horizontalPitchAndVelocity(pos, size);
    } else {
      return _verticalPitchAndVelocity(
        pos,
        size,
        maxPitchOverride: maxPitchOverride ?? maxPitch,
        keyHeightOverride: keyHeightOverride ?? keyHeight,
      );
    }
  }

  KeyboardActiveTouch? _horizontalPitchAndVelocity(Offset pos, Size size) {
    final double clampedX = pos.dx.clamp(0.0, math.max(1.0, size.width - 0.001));
    final double clampedY = pos.dy.clamp(0.0, math.max(1.0, size.height));

    final startPitch = (baseOctave + 1) * 12; // C3 = 48
    final totalNotes = octavesCount * 12;

    int whiteKeyCount = 0;
    for (int p = startPitch; p < startPitch + totalNotes; p++) {
      if (!isBlackKey(p)) whiteKeyCount++;
    }
    if (whiteKeyCount == 0) return null;

    final double whiteKeyWidth = size.width / whiteKeyCount;
    final double blackKeyWidth = whiteKeyWidth * 0.65;
    final double blackKeyHeight = size.height * 0.60;

    // 1. Check Black Keys (Top 60% overlay)
    if (clampedY <= blackKeyHeight) {
      int currentWhiteIdx = 0;
      for (int p = startPitch; p < startPitch + totalNotes; p++) {
        if (isBlackKey(p)) {
          final double left = (currentWhiteIdx * whiteKeyWidth) - (blackKeyWidth / 2.0);
          final double right = left + blackKeyWidth;
          if (clampedX >= left && clampedX <= right) {
            final double normY = (clampedY / blackKeyHeight).clamp(0.0, 1.0);
            final double velocity = (0.15 + 0.85 * normY).clamp(0.15, 1.0);
            return KeyboardActiveTouch(
              pointerId: 0,
              pitch: p,
              velocity: velocity,
              isBlack: true,
            );
          }
        } else {
          currentWhiteIdx++;
        }
      }
    }

    // 2. Check White Keys
    int whiteIdx = (clampedX / whiteKeyWidth).floor().clamp(0, whiteKeyCount - 1);
    int currentWhiteIdx = 0;
    for (int p = startPitch; p < startPitch + totalNotes; p++) {
      if (!isBlackKey(p)) {
        if (currentWhiteIdx == whiteIdx) {
          final double normY = (clampedY / size.height).clamp(0.0, 1.0);
          final double velocity = (0.15 + 0.85 * normY).clamp(0.15, 1.0);
          return KeyboardActiveTouch(
            pointerId: 0,
            pitch: p,
            velocity: velocity,
            isBlack: false,
          );
        }
        currentWhiteIdx++;
      }
    }

    return null;
  }

  KeyboardActiveTouch? _verticalPitchAndVelocity(
    Offset pos,
    Size size, {
    required int maxPitchOverride,
    required double keyHeightOverride,
  }) {
    final double totalHeight = (maxPitchOverride - minPitch + 1) * keyHeightOverride;
    final double clampedY = pos.dy.clamp(0.0, math.max(1.0, totalHeight - 0.001));
    final double clampedX = pos.dx.clamp(0.0, math.max(1.0, size.width));

    final int keyIdx = (clampedY / keyHeightOverride).floor();
    final int pitch = (maxPitchOverride - keyIdx).clamp(minPitch, maxPitchOverride);

    // Horizontal X position across the key controls velocity (0.15 at left to 1.0 at right)
    final double normX = (clampedX / math.max(1.0, size.width)).clamp(0.0, 1.0);
    final double velocity = (0.15 + 0.85 * normX).clamp(0.15, 1.0);

    return KeyboardActiveTouch(
      pointerId: 0,
      pitch: pitch,
      velocity: velocity,
      isBlack: isBlackKey(pitch),
    );
  }

  void handlePointerDown(
    PointerDownEvent event,
    Offset localPos,
    Size size, {
    int? maxPitchOverride,
    double? keyHeightOverride,
  }) {
    final touchInfo = pitchAndVelocityFromOffset(
      localPos,
      size,
      maxPitchOverride: maxPitchOverride,
      keyHeightOverride: keyHeightOverride,
    );
    if (touchInfo == null) return;

    final touch = touchInfo.copyWith(pointerId: event.pointer);
    _activeTouches[event.pointer] = touch;
    onNoteOn?.call(touch.pitch, touch.velocity);
    notifyListeners();
  }

  void handlePointerMove(
    PointerMoveEvent event,
    Offset localPos,
    Size size, {
    int? maxPitchOverride,
    double? keyHeightOverride,
  }) {
    // Only track drag movement if mouse button is actively held down or pointer is already active
    final bool isPressed = (event.buttons & kPrimaryMouseButton) != 0 || event.down || _activeTouches.containsKey(event.pointer);
    if (!isPressed) {
      if (_activeTouches.containsKey(event.pointer)) {
        final removed = _activeTouches.remove(event.pointer);
        if (removed != null) {
          onNoteOff?.call(removed.pitch);
        }
        notifyListeners();
      }
      return;
    }

    final touchInfo = pitchAndVelocityFromOffset(
      localPos,
      size,
      maxPitchOverride: maxPitchOverride,
      keyHeightOverride: keyHeightOverride,
    );
    final prevTouch = _activeTouches[event.pointer];

    if (touchInfo != null) {
      final updatedTouch = touchInfo.copyWith(pointerId: event.pointer);
      if (prevTouch == null) {
        _activeTouches[event.pointer] = updatedTouch;
        onNoteOn?.call(updatedTouch.pitch, updatedTouch.velocity);
        notifyListeners();
      } else if (prevTouch.pitch != updatedTouch.pitch) {
        onNoteOff?.call(prevTouch.pitch);
        _activeTouches[event.pointer] = updatedTouch;
        onNoteOn?.call(updatedTouch.pitch, updatedTouch.velocity);
        notifyListeners();
      } else if ((prevTouch.velocity - updatedTouch.velocity).abs() > 0.08) {
        _activeTouches[event.pointer] = updatedTouch;
        notifyListeners();
      }
    } else {
      if (_activeTouches.containsKey(event.pointer)) {
        final removed = _activeTouches.remove(event.pointer);
        if (removed != null) {
          onNoteOff?.call(removed.pitch);
        }
        notifyListeners();
      }
    }
  }

  void handlePointerUpOrCancel(int pointerId) {
    if (_activeTouches.containsKey(pointerId)) {
      final removed = _activeTouches.remove(pointerId);
      if (removed != null) {
        onNoteOff?.call(removed.pitch);
      }
      notifyListeners();
    }
  }

  void clearAllTouches() {
    for (final touch in _activeTouches.values) {
      onNoteOff?.call(touch.pitch);
    }
    _activeTouches.clear();
    notifyListeners();
  }
}
