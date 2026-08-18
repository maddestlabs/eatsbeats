import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';
import 'glowing_nixie_display.dart';
import 'skeuomorphic_hardware_button.dart';

/// Modal dialog allowing the user to adjust the global UI scale of Eatsbits
/// with live real-time preview and guaranteed revert on cancel or dismiss.
class UiScaleDialog extends StatefulWidget {
  final DawState dawState;

  const UiScaleDialog({super.key, required this.dawState});

  static Future<void> show(BuildContext context, DawState dawState) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => UiScaleDialog(dawState: dawState),
    );
  }

  @override
  State<UiScaleDialog> createState() => _UiScaleDialogState();
}

class _UiScaleDialogState extends State<UiScaleDialog> {
  late double _initialScale;
  late double _currentScale;
  bool _isCommitted = false;

  @override
  void initState() {
    super.initState();
    _initialScale = widget.dawState.uiScale;
    _currentScale = _initialScale;
  }

  @override
  void dispose() {
    if (!_isCommitted && widget.dawState.uiScale != _initialScale) {
      widget.dawState.revertUiScale(_initialScale);
    }
    super.dispose();
  }

  void _onScaleChanged(double val) {
    setState(() {
      _currentScale = (val * 100).roundToDouble() / 100;
    });
    widget.dawState.setUiScalePreview(_currentScale);
  }

  void _applyAndClose() {
    _isCommitted = true;
    widget.dawState.commitUiScale(_currentScale);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: EatsTheme.panelHeader,
        content: Text(
          'UI Scale set to ${(_currentScale * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: EatsTheme.primaryCyan,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _cancelAndClose() {
    _isCommitted = false;
    widget.dawState.revertUiScale(_initialScale);
    Navigator.of(context).pop();
  }

  String _getScaleDescription(double scale) {
    if (scale <= 0.75) return 'Ultra-Compact (Max Screen Real Estate)';
    if (scale <= 0.85) return 'Compact (Optimal for Multitrack & Laptops)';
    if (scale >= 0.95 && scale <= 1.05) return 'Standard 1:1 Native Resolution';
    if (scale <= 1.15) return 'Relaxed (High-DPI / High-Res Monitors)';
    return 'Large / Zoomed (Touch Friendly)';
  }

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final percentage = (_currentScale * 100).toStringAsFixed(0);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!_isCommitted && widget.dawState.uiScale != _initialScale) {
          widget.dawState.revertUiScale(_initialScale);
        }
      },
      child: Dialog(
        backgroundColor: EatsTheme.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.primaryCyan.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: EatsTheme.panelBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.aspect_ratio, color: EatsTheme.primaryCyan, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DISPLAY & UI SCALE',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.primaryCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ).copyWith(letterSpacing: 1.0),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelAndClose,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close, color: EatsTheme.textMuted, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Nixie Display Readout Well
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: EatsTheme.controlBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isGrungy ? const Color(0xFF332F2A) : const Color(0xFF2B3245),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MAGNIFICATION',
                                style: TextStyle(
                                  color: EatsTheme.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getScaleDescription(_currentScale),
                                style: TextStyle(
                                  color: EatsTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlowingNixieDisplay(
                          label: '',
                          valueText: percentage,
                          unit: '%',
                          fontSize: 16,
                          glowColor: _currentScale == 1.0
                              ? EatsTheme.primaryCyan
                              : (_currentScale < 1.0 ? EatsTheme.accentGreen : EatsTheme.accentGold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Continuous Slider with Min/Max Labels
                    Row(
                      children: [
                        Text(
                          '70%',
                          style: TextStyle(
                            color: EatsTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: EatsTheme.primaryCyan,
                              inactiveTrackColor: Colors.black45,
                              thumbColor: EatsTheme.primaryCyan,
                              overlayColor: EatsTheme.primaryCyan.withOpacity(0.2),
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                            ),
                            child: Slider(
                              value: _currentScale,
                              min: 0.70,
                              max: 1.30,
                              divisions: 12,
                              onChanged: _onScaleChanged,
                            ),
                          ),
                        ),
                        Text(
                          '130%',
                          style: TextStyle(
                            color: EatsTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Quick Presets Row
              Text(
                'QUICK PRESETS',
                style: TextStyle(
                  color: EatsTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPresetChip('75% Compact', 0.75),
                  _buildPresetChip('85%', 0.85),
                  _buildPresetChip('100% Default', 1.00),
                  _buildPresetChip('115%', 1.15),
                  _buildPresetChip('125% Large', 1.25),
                ],
              ),

              const SizedBox(height: 14),

              // Informational note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: EatsTheme.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Live preview updates the DAW layout in real-time. If you close without clicking Update, the scale will revert.',
                      style: TextStyle(
                        color: EatsTheme.textMuted,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reset (100%) Button
                  TextButton.icon(
                    onPressed: () => _onScaleChanged(1.0),
                    style: TextButton.styleFrom(
                      foregroundColor: EatsTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    icon: const Icon(Icons.restart_alt, size: 14),
                    label: const Text('RESET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cancel Button
                      TextButton(
                        onPressed: _cancelAndClose,
                        style: TextButton.styleFrom(
                          foregroundColor: EatsTheme.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Update / Apply Button
                      ElevatedButton.icon(
                        onPressed: _applyAndClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EatsTheme.primaryCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.check, size: 15, color: Colors.black),
                        label: const Text(
                          'UPDATE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double scale) {
    final isSelected = (_currentScale - scale).abs() < 0.01;
    return InkWell(
      onTap: () => _onScaleChanged(scale),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? EatsTheme.primaryCyan.withOpacity(0.2) : EatsTheme.controlBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? EatsTheme.primaryCyan : Colors.white12,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
