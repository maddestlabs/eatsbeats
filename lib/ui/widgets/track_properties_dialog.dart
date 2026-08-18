import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

Future<void> showTrackPropertiesDialog(BuildContext context, DawState dawState, TrackChannel track) async {
  final controller = TextEditingController(text: track.name)
    ..selection = TextSelection(baseOffset: 0, extentOffset: track.name.length);
  Color selectedColor = track.color;
  bool isColorsExpanded = false;

  final List<Color> initialColorPalette = [
    const Color(0xFF21F4E8), // Neon Cyan
    const Color(0xFFFF8C00), // Vintage Amber
    const Color(0xFF00FF66), // Acid Green
    const Color(0xFFFF007A), // Hot Pink
    const Color(0xFFBD00FF), // Electric Purple
    const Color(0xFFFF3333), // Crimson Red
    const Color(0xFFFFD700), // Gold
    const Color(0xFF3399FF), // Sky Blue
  ];

  final List<Color> expandedColorPalette = [
    const Color(0xFF21F4E8), const Color(0xFFFF8C00), const Color(0xFF00FF66), const Color(0xFFFF007A),
    const Color(0xFFBD00FF), const Color(0xFFFF3333), const Color(0xFFFFD700), const Color(0xFF3399FF),
    const Color(0xFF00E5FF), const Color(0xFFFFAB00), const Color(0xFF76FF03), const Color(0xFFF50057),
    const Color(0xFFD500F9), const Color(0xFFFF1744), const Color(0xFFFFEA00), const Color(0xFF2979FF),
    const Color(0xFF1DE9B6), const Color(0xFFFF6D00), const Color(0xFFAEEA00), const Color(0xFFE040FB),
    const Color(0xFF651FFF), const Color(0xFFFF5252), const Color(0xFFFFC400), const Color(0xFF00B0FF),
  ];

  final List<String> musicEmojiPalette = [
    '🎹', '🎸', '🥁', '🎷', '🎺', '🎻', '🪕', '🪗',
    '🎙️', '🎛️', '🔊', '⚡', '🎧', '🎵', '🎶', '👾',
    '🤖', '🔥', '✨', '🌊', '💣', '🎤', '🪘', '🔔',
    '📼', '💻', '💿', '📻', '📢', '🪐',
  ];

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final isSingleTrack = dawState.activePattern.tracks.length <= 1;

          return AlertDialog(
            backgroundColor: EatsTheme.panelBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: selectedColor, width: 2),
            ),
            title: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TRACK PROPERTIES',
                  style: EatsTheme.getPrimaryFontStyle(
                    color: EatsTheme.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: EatsTheme.controlBackground,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EatsTheme.panelHeader),
                  ),
                  child: Text(
                    track.type.name.toUpperCase(),
                    style: TextStyle(color: selectedColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Track Name Input
                    Text(
                      'TRACK NAME',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: EatsTheme.controlBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: EatsTheme.panelHeader),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: selectedColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Track Color Swatches
                    Row(
                      children: [
                        Text(
                          'TRACK COLOR',
                          style: EatsTheme.getPrimaryFontStyle(
                            color: EatsTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (!isColorsExpanded)
                          GestureDetector(
                            onTap: () => setState(() => isColorsExpanded = true),
                            child: Text(
                              '+ MORE COLORS',
                              style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...(isColorsExpanded ? expandedColorPalette : initialColorPalette).map((color) {
                          final isSelected = color.value == selectedColor.value;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedColor = color;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.black26,
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 18, color: Colors.black)
                                  : null,
                            ),
                          );
                        }),
                        if (!isColorsExpanded)
                          GestureDetector(
                            onTap: () => setState(() => isColorsExpanded = true),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: EatsTheme.controlBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: EatsTheme.panelHeader, width: 1.5),
                              ),
                              child: Icon(Icons.add, size: 18, color: EatsTheme.textMuted),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. Quick Music / Instrument Emoji Palette
                    Text(
                      'QUICK INSTRUMENT / EMOJI SYMBOLS (CLICK TO ADD)',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: musicEmojiPalette.map((emoji) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            final cur = controller.text;
                            if (cur.isEmpty) {
                              controller.text = '$emoji ';
                            } else if (!cur.startsWith(emoji)) {
                              controller.text = '$emoji $cur';
                            } else {
                              controller.text = '$cur $emoji';
                            }
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                            setState(() {});
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: EatsTheme.controlBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: EatsTheme.panelHeader, width: 1.0),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // 4. Quick Mute / Solo Toggles
                    Row(
                      children: [
                        Text(
                          'CHANNEL STATUS',
                          style: EatsTheme.getPrimaryFontStyle(
                            color: EatsTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            dawState.toggleMute(track);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: track.isMuted ? EatsTheme.muteColor : EatsTheme.panelHeader,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'MUTE',
                              style: TextStyle(
                                color: track.isMuted ? Colors.white : EatsTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            dawState.toggleSolo(track);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: track.isSoloed ? EatsTheme.soloColor : EatsTheme.panelHeader,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SOLO',
                              style: TextStyle(
                                color: track.isSoloed ? Colors.black : EatsTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),

                    // 5. Duplicate & Delete Actions
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: EatsTheme.primaryCyan,
                            side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('DUPLICATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            dawState.duplicateTrack(track);
                          },
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isSingleTrack ? EatsTheme.textMuted : EatsTheme.muteColor,
                            side: BorderSide(color: isSingleTrack ? Colors.white12 : EatsTheme.muteColor.withOpacity(0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: const Text('DELETE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: isSingleTrack
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  _confirmDeleteTrack(context, dawState, track);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CANCEL', style: TextStyle(color: EatsTheme.textMuted, fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final trimmed = controller.text.trim();
                  if (trimmed.isNotEmpty) {
                    track.name = trimmed;
                  }
                  dawState.setTrackColor(track, selectedColor);
                  Navigator.of(context).pop();
                },
                child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          );
        },
      );
    },
  );
}

void _confirmDeleteTrack(BuildContext context, DawState dawState, TrackChannel track) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: EatsTheme.panelBackground,
        title: Text(
          'DELETE TRACK?',
          style: TextStyle(color: EatsTheme.muteColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        content: Text(
          'Are you sure you want to delete track "${track.name}"? This action cannot be undone.',
          style: TextStyle(color: EatsTheme.textPrimary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('CANCEL', style: TextStyle(color: EatsTheme.textMuted, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EatsTheme.muteColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              dawState.deleteTrack(track);
            },
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      );
    },
  );
}
