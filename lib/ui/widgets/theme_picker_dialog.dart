import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';
import 'skeuomorphic_hardware_button.dart';

class ThemePickerDialog extends StatelessWidget {
  final DawState dawState;

  const ThemePickerDialog({super.key, required this.dawState});

  static Future<void> show(BuildContext context, DawState dawState) {
    return showDialog(
      context: context,
      builder: (ctx) => ThemePickerDialog(dawState: dawState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = EatsTheme.currentPreset;
    final isGrungy = currentTheme == EatsThemePreset.ateTrack;

    final themes = [
      {
        'preset': EatsThemePreset.ateTrack,
        'name': 'Ate Track (Hardware Console)',
        'desc': 'Skeuomorphic analog console, metallic textures, warm lamps & nixie tubes',
        'accent': const Color(0xFFFF8C00),
        'palette': [const Color(0xFFFF8C00), const Color(0xFF24201C), const Color(0xFF141210)],
      },
      {
        'preset': EatsThemePreset.midnightBites,
        'name': 'Midnight Bites (Cyber Neon)',
        'desc': 'Obsidian dark cyber theme with neon cyan and glowing magenta accents',
        'accent': const Color(0xFF21F4E8),
        'palette': [const Color(0xFF21F4E8), const Color(0xFFFF007A), const Color(0xFF0F1015)],
      },
      {
        'preset': EatsThemePreset.lightSnack,
        'name': 'Light Snack (Bright Studio)',
        'desc': 'Bright high-contrast studio theme optimized for daytime outdoor visibility',
        'accent': const Color(0xFF0088FF),
        'palette': [const Color(0xFF0088FF), const Color(0xFFD8DEE9), const Color(0xFFECEFF4)],
      },
      {
        'preset': EatsThemePreset.breakfast,
        'name': 'Breakfast (Solarized Light)',
        'desc': 'Solarized light theme with creamy parchment background & warm gold tones',
        'accent': const Color(0xFFB58900),
        'palette': [const Color(0xFFB58900), const Color(0xFFCB4B16), const Color(0xFFFDF6E3)],
      },
      {
        'preset': EatsThemePreset.dinner,
        'name': 'Dinner (Solarized Dark)',
        'desc': 'Solarized dark theme with deep oceanic teal, cyan & emerald accents',
        'accent': const Color(0xFF2AA198),
        'palette': [const Color(0xFF2AA198), const Color(0xFF859900), const Color(0xFF002B36)],
      },
    ];

    return AlertDialog(
      backgroundColor: EatsTheme.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.primaryCyan.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: EatsTheme.primaryCyan, size: 22),
              const SizedBox(width: 8),
              Text(
                'UI THEME ENGINE',
                style: EatsTheme.getDisplayFontStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: EatsTheme.primaryCyan,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: EatsTheme.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a visual studio skin. The interface updates instantly.',
                style: TextStyle(color: EatsTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 12),
              ...themes.map((t) {
                final preset = t['preset'] as EatsThemePreset;
                final isSelected = preset == currentTheme;
                final accent = t['accent'] as Color;
                final palette = t['palette'] as List<Color>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withOpacity(0.18) : EatsTheme.controlBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? accent : EatsTheme.panelHeader,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        dawState.setThemePreset(preset);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Selection Indicator / Swatch
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: accent, width: 1.5),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, size: 16, color: accent)
                                  : null,
                            ),
                            const SizedBox(width: 12),

                            // Name & Description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t['name'] as String,
                                          style: EatsTheme.getPrimaryFontStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? Colors.white : EatsTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    t['desc'] as String,
                                    style: EatsTheme.getPrimaryFontStyle(
                                      fontSize: 10.5,
                                      color: isSelected ? EatsTheme.textLight : EatsTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Swatches
                                  Row(
                                    children: palette.map((color) {
                                      return Container(
                                        width: 14,
                                        height: 14,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white24, width: 1),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        SkeuomorphicHardwareButton(
          label: 'DONE',
          icon: Icons.check,
          isActive: true,
          activeColor: EatsTheme.primaryCyan,
          onTap: () => Navigator.of(context).pop(),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ],
    );
  }
}
