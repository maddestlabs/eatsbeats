import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// Shows a small, compact dialog for entering numeric or parameter values manually.
void showCompactValueEditDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  String? minMaxHint,
  Color? accentColor,
  required ValueChanged<String> onSubmit,
  VoidCallback? onResetDefault,
}) {
  final effectiveAccent = accentColor ?? EatsTheme.primaryCyan;
  final controller = TextEditingController(text: initialValue)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initialValue.length);

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: EatsTheme.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: effectiveAccent.withOpacity(0.6), width: 1.5),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Title & Optional Reset Default Button
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
                  if (onResetDefault != null)
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
              ),
              if (minMaxHint != null && minMaxHint.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  minMaxHint,
                  style: TextStyle(color: EatsTheme.textMuted, fontSize: 10),
                ),
              ],
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: effectiveAccent.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: effectiveAccent, width: 1.5),
                  ),
                ),
                onSubmitted: (val) {
                  onSubmit(val);
                  Navigator.of(context).pop();
                },
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
                    onPressed: () {
                      onSubmit(controller.text);
                      Navigator.of(context).pop();
                    },
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
}

