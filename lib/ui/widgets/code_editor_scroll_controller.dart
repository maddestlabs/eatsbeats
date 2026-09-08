import 'package:flutter/widgets.dart';

/// A specialized [ScrollController] that prevents Flutter's notorious multiline
/// text-selection auto-scroll looping glitch (Flutter issues #132047, #96434, #91464).
///
/// In Flutter, when dragging to select text across a multiline [TextField] or
/// scrollable editable past line 0, Flutter's internal `RenderEditable` alternately
/// attempts to keep the base selection anchor and the extent selection handle in view.
/// This causes high-frequency (16-30ms) oscillating jumps of magnitude ~viewport height,
/// trapping the viewport in an infinite scrolling loop.
///
/// This controller creates a [_CodeEditorScrollPosition] that detects this rapid
/// opposing oscillation during text selection drags and suppresses the spurious
/// jump-back, enabling smooth, uninterrupted selection across multiline text.
class CodeEditorScrollController extends ScrollController {
  CodeEditorScrollController({super.initialScrollOffset, super.keepScrollOffset});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _CodeEditorScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
    );
  }
}

class _CodeEditorScrollPosition extends ScrollPositionWithSingleContext {
  _CodeEditorScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
  });

  DateTime _lastJumpTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastDirection = 0; // +1.0 for down, -1.0 for up

  @override
  void jumpTo(double value) {
    if (_shouldSuppressOscillationJump(value)) {
      return;
    }
    _recordJump(value);
    super.jumpTo(value);
  }

  bool _shouldSuppressOscillationJump(double targetPixels) {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastJumpTime).inMilliseconds;
    final delta = targetPixels - pixels;

    // Only inspect high-frequency jumps occurring within 65ms (1-4 frames)
    if (elapsedMs < 65 && hasViewportDimension && viewportDimension > 60) {
      final currentDirection = delta > 0 ? 1.0 : (delta < 0 ? -1.0 : 0.0);
      final isOpposingDirection = (currentDirection != 0 && _lastDirection != 0 && currentDirection != _lastDirection);
      // The bug causes jumps of ~viewport dimension back to the selection anchor.
      final isLargeReverseJump = delta.abs() > (viewportDimension * 0.35);

      if (isOpposingDirection && isLargeReverseJump) {
        // Suppress the spurious reverse jump that causes the infinite ping-pong loop!
        return true;
      }
    }
    return false;
  }

  void _recordJump(double targetPixels) {
    final delta = targetPixels - pixels;
    if (delta.abs() > 1.0) {
      _lastJumpTime = DateTime.now();
      _lastDirection = delta > 0 ? 1.0 : -1.0;
    }
  }
}
