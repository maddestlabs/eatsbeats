import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/eats_theme.dart';
import '../widgets/compact_value_dialog.dart';
import 'eat_hardware_knob_model.dart';
import 'eat_hardware_knob_painters.dart';

/// Definitive Rotary Mixer Knob for Eatsbeats.
/// Implements the 6-Zone Anatomical Hardware Taxonomy, Dual-Layer GPU Caching,
/// and Zero-Heap-Allocation real-time animation.
class EatHardwareKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final String? label;
  final bool showLabelText;
  final bool showValueText;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final double size;
  final EatHardwareKnobStyle style;
  final String Function(double)? formatValue;

  const EatHardwareKnob({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.defaultValue,
    this.step = 0.0,
    this.label,
    this.showLabelText = true,
    this.showValueText = false,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.size = 64.0,
    required this.style,
    this.formatValue,
  });

  @override
  State<EatHardwareKnob> createState() => _EatHardwareKnobState();
}

class _EatHardwareKnobState extends State<EatHardwareKnob> {
  double _dragStartValue = 0.0;
  double _dragStartY = 0.0;
  double _dragStartX = 0.0;

  @override
  Widget build(BuildContext context) {
    final range = widget.max - widget.min;
    final normalized = range > 0
        ? ((widget.value - widget.min) / range).clamp(0.0, 1.0)
        : 0.0;

    final displayVal = widget.formatValue != null
        ? widget.formatValue!(widget.value)
        : widget.value.toStringAsFixed(2);

    final labelWidget = (widget.label != null && widget.showLabelText)
        ? Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Text(
              widget.label!.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.0,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: widget.style.scale.labelColor ?? const Color(0xFF1E1E24),
              ),
              textAlign: TextAlign.center,
            ),
          )
        : null;

    final hasScaleLabels = widget.style.scale.labels.isNotEmpty;
    final hasScaleTicks = widget.style.scale.tickDivisions > 0;
    final scalePad = hasScaleLabels ? 22.0 : (hasScaleTicks ? 10.0 : 4.0);
    final dialBoxSize = widget.size + scalePad;

    final dialWidget = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        widget.onChangeStart?.call();
        _dragStartValue = widget.value;
        _dragStartY = details.globalPosition.dy;
        _dragStartX = details.globalPosition.dx;
      },
      onPanUpdate: (details) {
        final dy = _dragStartY - details.globalPosition.dy;
        final dx = details.globalPosition.dx - _dragStartX;
        final dragDelta = (dy.abs() >= dx.abs()) ? dy : dx;

        // Shift key modifier for fine-tune precision (1/4 sensitivity)
        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
        final sensitivity = isShiftPressed ? 600.0 : 150.0;
        final delta = (dragDelta / sensitivity) * range;

        double newValue = (_dragStartValue + delta).clamp(widget.min, widget.max);
        if (widget.step > 0) {
          newValue = (newValue / widget.step).roundToDouble() * widget.step;
          newValue = newValue.clamp(widget.min, widget.max);
        }
        widget.onChanged(newValue);
      },
      onPanEnd: (_) => widget.onChangeEnd?.call(),
      onPanCancel: () => widget.onChangeEnd?.call(),
      onDoubleTap: () {
        widget.onChangeStart?.call();
        widget.onChanged(widget.defaultValue);
        widget.onChangeEnd?.call();
      },
      onLongPress: () => _showManualEditDialog(context),
      onSecondaryTap: () => _showManualEditDialog(context),
      child: Tooltip(
        message: '${widget.label != null ? '${widget.label}: ' : ''}$displayVal (Double-tap to reset, Right-click to edit)',
        child: SizedBox(
          width: dialBoxSize,
          height: dialBoxSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // LAYER 1 (STATIC): Ticks, legends, inactive arc, collar
              // Decoupled into RepaintBoundary to cache GPU rasterization
              RepaintBoundary(
                child: CustomPaint(
                  painter: EatStaticDialPainter(style: widget.style),
                ),
              ),

              // LAYER 2 (DYNAMIC): Rotating body, knurling, pointer, active arc
              // Zero allocations in paint() running at 60/120 FPS
              RepaintBoundary(
                child: CustomPaint(
                  painter: EatDynamicKnobPainter(
                    normalizedValue: normalized,
                    style: widget.style,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        dialWidget,
        if (labelWidget != null) labelWidget,
        if (widget.showValueText) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.black12, width: 0.8),
            ),
            child: Text(
              displayVal,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1A17),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showManualEditDialog(BuildContext context) {
    final displayVal = widget.formatValue != null
        ? widget.formatValue!(widget.value)
        : widget.value.toStringAsFixed(2);

    showCompactValueEditDialog(
      context: context,
      title: widget.label != null ? 'Set ${widget.label}' : 'Set Knob Value',
      initialValue: displayVal,
      minValue: widget.min,
      maxValue: widget.max,
      minMaxHint: 'Range: ${widget.min} - ${widget.max}',
      accentColor: widget.style.trackActiveColor,
      onResetDefault: () => widget.onChanged(widget.defaultValue),
      onSubmit: (text) {
        final double? parsed = double.tryParse(text);
        if (parsed != null) {
          widget.onChanged(parsed.clamp(widget.min, widget.max));
        }
      },
    );
  }
}
