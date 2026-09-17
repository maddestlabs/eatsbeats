import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/eats_theme.dart';
import '../widgets/compact_value_dialog.dart';
import 'eat_hardware_knob_model.dart';
import 'eat_hardware_knob_painters.dart';
import 'eat_hardware_scale.dart';

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
  final bool isLightChassis;
  final List<String>? options;

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
    this.isLightChassis = false,
    this.options,
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
    final isOptionKnob = widget.options != null && widget.options!.isNotEmpty;
    final effectiveOptions = widget.options ?? const [];
    final effectiveMin = isOptionKnob ? 0.0 : widget.min;
    final effectiveMax = isOptionKnob ? (effectiveOptions.length - 1).toDouble() : widget.max;
    final effectiveStep = isOptionKnob ? 1.0 : widget.step;

    final range = effectiveMax - effectiveMin;
    final normalized = range > 0
        ? ((widget.value - effectiveMin) / range).clamp(0.0, 1.0)
        : 0.0;

    final displayVal = isOptionKnob
        ? (effectiveOptions.isNotEmpty
            ? effectiveOptions[widget.value.round().clamp(0, effectiveOptions.length - 1)]
            : widget.value.toStringAsFixed(0))
        : (widget.formatValue != null
            ? widget.formatValue!(widget.value)
            : widget.value.toStringAsFixed(2));

    var effectiveStyle = widget.style;
    if (effectiveStyle.isLightChassis != widget.isLightChassis) {
      effectiveStyle = effectiveStyle.copyWith(isLightChassis: widget.isLightChassis);
    }
    if (isOptionKnob && effectiveStyle.scale.labels.isEmpty) {
      final defaultTick = widget.isLightChassis ? const Color(0xFF1E1E24) : const Color(0xFFA0A5B0);
      final defaultText = widget.isLightChassis ? const Color(0xFF1E1E24) : const Color(0xFFE2DDD5);
      effectiveStyle = effectiveStyle.copyWith(
        scale: EatScaleGraduation.optionsSelector(
          labels: effectiveOptions,
          tickColor: effectiveStyle.scale.tickColor ?? defaultTick,
          labelColor: effectiveStyle.scale.labelColor ?? defaultText,
        ),
      );
    }

    final labelColor = effectiveStyle.scale.labelColor ??
        (widget.isLightChassis ? const Color(0xFF1E1E24) : const Color(0xFFE2DDD5));

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
                color: labelColor,
              ),
              textAlign: TextAlign.center,
            ),
          )
        : null;

    final hasScaleLabels = effectiveStyle.scale.labels.isNotEmpty;
    final hasScaleTicks = effectiveStyle.scale.tickDivisions > 0;
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

        double newValue = (_dragStartValue + delta).clamp(effectiveMin, effectiveMax);
        if (effectiveStep > 0) {
          newValue = (newValue / effectiveStep).roundToDouble() * effectiveStep;
          newValue = newValue.clamp(effectiveMin, effectiveMax);
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
        message: '${widget.label != null ? '${widget.label}: ' : ''}$displayVal (Double-tap to reset, Right-click to choose)',
        child: SizedBox(
          width: dialBoxSize,
          height: dialBoxSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // LAYER 1 (STATIC): Ticks, legends, inactive arc, collar
              RepaintBoundary(
                child: CustomPaint(
                  painter: EatStaticDialPainter(style: effectiveStyle),
                ),
              ),

              // LAYER 2 (DYNAMIC): Rotating body, knurling, pointer, active arc
              RepaintBoundary(
                child: CustomPaint(
                  painter: EatDynamicKnobPainter(
                    normalizedValue: normalized,
                    style: effectiveStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          dialWidget,
          if (labelWidget != null) labelWidget,
          if (widget.showValueText) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: widget.isLightChassis
                    ? Colors.black.withOpacity(0.08)
                    : Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: widget.isLightChassis ? Colors.black12 : Colors.white24,
                  width: 0.8,
                ),
              ),
              child: Text(
                displayVal,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: widget.isLightChassis
                      ? const Color(0xFF1B1A17)
                      : const Color(0xFFE2DDD5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showManualEditDialog(BuildContext context) {
    if (widget.options != null && widget.options!.isNotEmpty) {
      _showOptionChooserDialog(context);
      return;
    }

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

  void _showOptionChooserDialog(BuildContext context) {
    final opts = widget.options!;
    final currentIdx = widget.value.round().clamp(0, opts.length - 1);
    final accent = widget.style.trackActiveColor;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: EatsTheme.panelBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: accent.withOpacity(0.6), width: 1.5),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            width: 290,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (widget.label ?? 'CHOOSE OPTION').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EatsTheme.getPrimaryFontStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        widget.onChanged(widget.defaultValue);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RESET',
                          style: TextStyle(
                            fontSize: 10,
                            color: EatsTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(opts.length, (idx) {
                    final opt = opts[idx];
                    final isSelected = idx == currentIdx;
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        widget.onChanged(idx.toDouble());
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withOpacity(0.25)
                              : (widget.isLightChassis ? Colors.black.withOpacity(0.06) : Colors.white10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? accent : (widget.isLightChassis ? Colors.black12 : Colors.white12),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? (widget.isLightChassis ? Colors.black : accent)
                                : (widget.isLightChassis ? Colors.black87 : Colors.white70),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
