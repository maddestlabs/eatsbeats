import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// Shows a small, compact dialog for entering numeric or parameter values manually.
/// Supports an optional percentage ('%') mode for intuitive parameter scaling.
void showCompactValueEditDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  double? minValue,
  double? maxValue,
  String? minMaxHint,
  Color? accentColor,
  required ValueChanged<String> onSubmit,
  VoidCallback? onResetDefault,
}) {
  final effectiveAccent = accentColor ?? EatsTheme.primaryCyan;
  final bool hasRange = minValue != null && maxValue != null && maxValue > minValue;

  showDialog(
    context: context,
    builder: (context) {
      bool isPercentMode = false;
      final controller = TextEditingController(text: initialValue)
        ..selection = TextSelection(baseOffset: 0, extentOffset: initialValue.length);

      return StatefulBuilder(
        builder: (context, setDialogState) {
          void togglePercentMode() {
            final rawInput = controller.text.replaceAll('%', '').trim();
            final parsed = double.tryParse(rawInput);

            if (!isPercentMode) {
              // Convert direct value -> percentage (0% - 100%)
              if (parsed != null && hasRange) {
                final double pct = ((parsed - minValue) / (maxValue - minValue)) * 100.0;
                final rounded = (pct * 10).roundToDouble() / 10;
                controller.text = (rounded == rounded.roundToDouble())
                    ? rounded.toInt().toString()
                    : rounded.toStringAsFixed(1);
              } else {
                controller.text = '50';
              }
              isPercentMode = true;
            } else {
              // Convert percentage -> direct value
              if (parsed != null && hasRange) {
                final double val = minValue + (parsed / 100.0) * (maxValue - minValue);
                final rounded = (val * 1000).roundToDouble() / 1000;
                controller.text = (rounded == rounded.roundToDouble())
                    ? rounded.toInt().toString()
                    : (rounded.abs() < 10 ? rounded.toStringAsFixed(3) : rounded.toStringAsFixed(2))
                        .replaceFirst(RegExp(r'\.?0+$'), '');
              }
              isPercentMode = false;
            }
            controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
          }

          void handleSubmit() {
            final rawInput = controller.text.trim();
            if (rawInput.isEmpty) {
              Navigator.of(context).pop();
              return;
            }

            final bool inputHasPercent = rawInput.contains('%');
            if (hasRange && (isPercentMode || inputHasPercent)) {
              final cleaned = rawInput.replaceAll('%', '').trim();
              final pct = double.tryParse(cleaned);
              if (pct != null) {
                final double calculated = minValue + (pct / 100.0) * (maxValue - minValue);
                final double clamped = calculated.clamp(minValue, maxValue);
                final formatted = (clamped == clamped.roundToDouble())
                    ? clamped.toInt().toString()
                    : (clamped.abs() < 10 ? clamped.toStringAsFixed(3) : clamped.toStringAsFixed(2))
                        .replaceFirst(RegExp(r'\.?0+$'), '');
                onSubmit(formatted);
                Navigator.of(context).pop();
                return;
              }
            }

            onSubmit(rawInput.replaceAll('%', '').trim());
            Navigator.of(context).pop();
          }

          return Dialog(
            backgroundColor: EatsTheme.panelBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: effectiveAccent.withValues(alpha: 0.6), width: 1.5),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Container(
              width: 270,
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row: Title, Optional % Toggle Chip & Reset Default Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EatsTheme.getPrimaryFontStyle(
                            color: effectiveAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (hasRange) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              togglePercentMode();
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Tooltip(
                            message: isPercentMode ? 'Switch to direct value' : 'Switch to percentage (%)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPercentMode
                                    ? effectiveAccent.withValues(alpha: 0.25)
                                    : EatsTheme.controlBackground,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isPercentMode
                                      ? effectiveAccent
                                      : (EatsTheme.isLight ? Colors.black26 : Colors.white24),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                '%',
                                style: TextStyle(
                                  color: isPercentMode ? effectiveAccent : EatsTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (onResetDefault != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            onResetDefault();
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                color: effectiveAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isPercentMode && hasRange
                        ? 'Percent mode (0% - 100% of $minValue - $maxValue)'
                        : (minMaxHint ?? (hasRange ? 'Range: $minValue - $maxValue' : '')),
                    style: TextStyle(color: EatsTheme.textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 10),

                  // Compact Numeric Input TextField
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    autofocus: true,
                    style: EatsTheme.getDisplayFontStyle(
                      color: effectiveAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: EatsTheme.controlBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixText: isPercentMode ? '%' : null,
                      suffixStyle: TextStyle(
                        color: effectiveAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: effectiveAccent.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: effectiveAccent, width: 1.5),
                      ),
                    ),
                    onChanged: (text) {
                      // If user types '%' anywhere in text, auto-activate percent mode
                      if (hasRange && !isPercentMode && text.contains('%')) {
                        setDialogState(() {
                          isPercentMode = true;
                          controller.text = text.replaceAll('%', '').trim();
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );
                        });
                      }
                    },
                    onSubmitted: (_) => handleSubmit(),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons: Cancel / OK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('CANCEL', style: TextStyle(color: EatsTheme.textMuted, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: effectiveAccent,
                          foregroundColor: EatsTheme.isLight ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
