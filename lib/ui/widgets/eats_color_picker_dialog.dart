import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

class EatsColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;
  final ValueChanged<Color> onColorSelected;

  const EatsColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title = 'SELECT TRACK COLOR',
    required this.onColorSelected,
  });

  @override
  State<EatsColorPickerDialog> createState() => _EatsColorPickerDialogState();
}

class _EatsColorPickerDialogState extends State<EatsColorPickerDialog> {
  late Color _currentColor;
  late TextEditingController _hexController;

  static const List<Map<String, dynamic>> _colorCategories = [
    {
      'name': 'NEON & CYBERPUNK',
      'colors': [
        Color(0xFF21F4E8), // Neon Cyan
        Color(0xFFFF007A), // Hot Pink / Magenta
        Color(0xFF00FF66), // Acid Lime
        Color(0xFFBD00FF), // Electric Purple
        Color(0xFFFF8C00), // Neon Orange
        Color(0xFFFFE600), // Solar Yellow
        Color(0xFF00E5FF), // Bright Cyan
        Color(0xFFFF3366), // Laser Coral
      ],
    },
    {
      'name': 'CLASSIC SYNTH & STUDIO',
      'colors': [
        Color(0xFFF77F00), // Roland Amber
        Color(0xFFE63946), // TR Red
        Color(0xFF0077B6), // Yamaha Blue
        Color(0xFF2A9D8F), // Moog Teal
        Color(0xFFE0A96D), // Oberheim Gold
        Color(0xFF7209B7), // Korg Violet
        Color(0xFF457B9D), // Steel Slate
        Color(0xFFD4A373), // Warm Wood
      ],
    },
    {
      'name': 'VIBRANT PALETTE',
      'colors': [
        Color(0xFFFF1744), // Crimson
        Color(0xFFFF5252), // Light Red
        Color(0xFFFF6D00), // Deep Orange
        Color(0xFFFFAB00), // Amber
        Color(0xFFFFD700), // Gold
        Color(0xFFAEEA00), // Lime
        Color(0xFF76FF03), // Bright Green
        Color(0xFF00E676), // Emerald
        Color(0xFF1DE9B6), // Mint
        Color(0xFF00B0FF), // Light Sky
        Color(0xFF2979FF), // Vivid Blue
        Color(0xFF651FFF), // Deep Violet
        Color(0xFFD500F9), // Magenta Violet
        Color(0xFFF50057), // Rose Pink
        Color(0xFFE040FB), // Orchid
        Color(0xFF3399FF), // Sky Blue
      ],
    },
    {
      'name': 'PASTELS & SUBTLE',
      'colors': [
        Color(0xFFFFB4A2), // Soft Peach
        Color(0xFFE5989B), // Dusky Rose
        Color(0xFFB5E48C), // Sage Mint
        Color(0xFF90E0EF), // Pale Sky
        Color(0xFFCDB4DB), // Lilac
        Color(0xFFFFC8DD), // Blossom
        Color(0xFFD8E2DC), // Soft Ash
        Color(0xFFFDE2E4), // Shell Pink
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _updateFromHex(String hex) {
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final val = int.tryParse('FF$cleaned', radix: 16);
      if (val != null) {
        setState(() {
          _currentColor = Color(val);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_currentColor);

    return Dialog(
      backgroundColor: EatsTheme.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _currentColor.withOpacity(0.8), width: 2),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _currentColor.withOpacity(0.8), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: EatsTheme.getPrimaryFontStyle(
                    color: EatsTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: EatsTheme.textMuted, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Color Categories Swatches Grid
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _colorCategories.map((cat) {
                    final String name = cat['name'];
                    final List<Color> colors = cat['colors'];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: EatsTheme.textMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: colors.map((color) {
                            final isSelected = color.value == _currentColor.value;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentColor = color;
                                  _hexController.text = _colorToHex(color);
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.black45,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withOpacity(0.8),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(color: Color(0xFF2B3245), height: 20),

            // Custom Fine-Tuning (Hue / Sat / Val & Hex)
            Row(
              children: [
                // Live Color Preview Chip
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: _currentColor.withOpacity(0.5), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Hex input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEX COLOR CODE',
                        style: TextStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _hexController,
                        style: TextStyle(
                          color: _currentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: EatsTheme.panelHeader,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF2B3245)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: _currentColor, width: 1.5),
                          ),
                        ),
                        onChanged: _updateFromHex,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Hue Quick Slider
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HUE (${hsv.hue.round()}°)',
                        style: TextStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          activeTrackColor: _currentColor,
                          inactiveTrackColor: const Color(0xFF2B3245),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: hsv.hue,
                          min: 0.0,
                          max: 360.0,
                          onChanged: (newHue) {
                            final newColor = HSVColor.fromAHSV(
                              1.0,
                              newHue,
                              hsv.saturation == 0 ? 0.85 : hsv.saturation,
                              hsv.value == 0 ? 0.95 : hsv.value,
                            ).toColor();
                            setState(() {
                              _currentColor = newColor;
                              _hexController.text = _colorToHex(newColor);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(color: EatsTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('APPLY COLOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentColor,
                    foregroundColor: _currentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    widget.onColorSelected(_currentColor);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showEatsColorPickerDialog(
  BuildContext context, {
  required Color currentColor,
  String title = 'SELECT TRACK COLOR',
  required ValueChanged<Color> onColorSelected,
}) {
  showDialog(
    context: context,
    builder: (ctx) => EatsColorPickerDialog(
      initialColor: currentColor,
      title: title,
      onColorSelected: onColorSelected,
    ),
  );
}
