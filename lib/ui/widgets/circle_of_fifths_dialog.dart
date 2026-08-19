import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chord_model.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';

/// Studio One-style interactive Circle of Fifths chord picker modal.
class CircleOfFifthsDialog extends StatefulWidget {
  final DawState dawState;
  final int targetBar;
  final ChordEvent? initialChord;
  final ValueChanged<ChordEvent>? onChordSelected;

  const CircleOfFifthsDialog({
    super.key,
    required this.dawState,
    this.targetBar = 0,
    this.initialChord,
    this.onChordSelected,
  });

  static Future<ChordEvent?> show(
    BuildContext context, {
    required DawState dawState,
    int targetBar = 0,
    ChordEvent? initialChord,
  }) {
    return showDialog<ChordEvent>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (context) => CircleOfFifthsDialog(
        dawState: dawState,
        targetBar: targetBar,
        initialChord: initialChord,
      ),
    );
  }

  @override
  State<CircleOfFifthsDialog> createState() => _CircleOfFifthsDialogState();
}

class _CircleOfFifthsDialogState extends State<CircleOfFifthsDialog> {
  late int _selectedRoot;
  late ChordQuality _selectedQuality;
  int? _selectedBass;
  late double _barLength;

  @override
  void initState() {
    super.initState();
    if (widget.initialChord != null) {
      _selectedRoot = widget.initialChord!.rootPitchClass;
      _selectedQuality = widget.initialChord!.quality;
      _selectedBass = widget.initialChord!.bassPitchClass;
      _barLength = widget.initialChord!.barLength;
    } else {
      _selectedRoot = widget.dawState.songKeyRoot;
      _selectedQuality = widget.dawState.isSongKeyMinor ? ChordQuality.minor : ChordQuality.major;
      _selectedBass = null;
      _barLength = 1.0;
    }
  }

  ChordEvent get _currentChord => ChordEvent(
        id: widget.initialChord?.id ?? 'chord_${DateTime.now().millisecondsSinceEpoch}_${widget.targetBar}',
        startBar: widget.targetBar,
        barLength: _barLength,
        rootPitchClass: _selectedRoot,
        quality: _selectedQuality,
        bassPitchClass: _selectedBass,
      );

  void _auditionCurrentChord() {
    widget.dawState.auditionChord(_currentChord);
  }

  void _onWheelSectorTapped(int pitchClass, bool isMinorSector) {
    setState(() {
      _selectedRoot = pitchClass;
      // Auto-switch to major or minor unless user already explicitly picked an extension
      if (_selectedQuality == ChordQuality.major || _selectedQuality == ChordQuality.minor) {
        _selectedQuality = isMinorSector ? ChordQuality.minor : ChordQuality.major;
      }
      _selectedBass = null;
    });
    _auditionCurrentChord();
  }

  @override
  Widget build(BuildContext context) {
    final chord = _currentChord;
    final roman = ChordTheory.getRomanNumeral(
      widget.dawState.songKeyRoot,
      widget.dawState.isSongKeyMinor,
      chord.rootPitchClass,
      chord.quality,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: EatsTheme.backgroundDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: EatsTheme.primaryCyan.withOpacity(0.15),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: EatsTheme.panelHeader,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Icon(Icons.album_outlined, color: EatsTheme.primaryCyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'CHORD SELECTOR & CIRCLE OF FIFTHS',
                    style: EatsTheme.getDisplayFontStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: EatsTheme.controlBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: EatsTheme.accentGold.withOpacity(0.5)),
                    ),
                    child: Text(
                      'KEY: ${widget.dawState.songKey.toUpperCase()}',
                      style: const TextStyle(color: EatsTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: EatsTheme.controlBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                    ),
                    child: Text(
                      'BAR ${widget.targetBar + 1}',
                      style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: EatsTheme.textMuted, size: 20),
                  ),
                ],
              ),
            ),

            // Main Body: Wheel & Modifiers Matrix
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Interactive Circle of Fifths Wheel
                    Column(
                      children: [
                        SizedBox(
                          width: 320,
                          height: 320,
                          child: GestureDetector(
                            onTapUp: (details) => _handleWheelTap(details.localPosition, 320, 320),
                            child: CustomPaint(
                              painter: _CircleOfFifthsPainter(
                                selectedRoot: _selectedRoot,
                                selectedQuality: _selectedQuality,
                                songKeyRoot: widget.dawState.songKeyRoot,
                                isSongKeyMinor: widget.dawState.isSongKeyMinor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Quick Audition Button
                        ElevatedButton.icon(
                          onPressed: _auditionCurrentChord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EatsTheme.controlBackground,
                            foregroundColor: EatsTheme.primaryCyan,
                            side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                          icon: const Icon(Icons.volume_up, size: 18),
                          label: Text(
                            'AUDITION (${chord.displayName})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 20),

                    // Right Column: Chord Preview, Quality Selector & Inversions
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active Chord Hero Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  EatsTheme.primaryCyan.withOpacity(0.2),
                                  EatsTheme.secondaryMagenta.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SELECTED CHORD',
                                      style: EatsTheme.getPrimaryFontStyle(
                                        color: EatsTheme.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      chord.displayName,
                                      style: EatsTheme.getDisplayFontStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Roman Numeral Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: EatsTheme.controlBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: EatsTheme.accentGold, width: 1.5),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'DEGREE',
                                        style: EatsTheme.getPrimaryFontStyle(
                                          color: EatsTheme.accentGold,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        roman,
                                        style: EatsTheme.getDisplayFontStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Chord Qualities / Extensions Matrix
                          Text(
                            'CHORD QUALITY & EXTENSIONS',
                            style: EatsTheme.getPrimaryFontStyle(
                              color: EatsTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: ChordQuality.values.map((quality) {
                              final isSelected = _selectedQuality == quality;
                              return ChoiceChip(
                                label: Text(
                                  quality.displayName,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: EatsTheme.primaryCyan,
                                backgroundColor: EatsTheme.controlBackground,
                                side: BorderSide(
                                  color: isSelected ? EatsTheme.primaryCyan : Colors.white.withOpacity(0.12),
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedQuality = quality);
                                  _auditionCurrentChord();
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 14),

                          // Bass Note / Inversion Selector
                          Text(
                            'BASS / SLASH NOTE (INVERSION)',
                            style: EatsTheme.getPrimaryFontStyle(
                              color: EatsTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Default Root Bass Chip
                              ChoiceChip(
                                label: const Text('Root Bass', style: TextStyle(fontSize: 11)),
                                selected: _selectedBass == null,
                                selectedColor: EatsTheme.accentGold,
                                backgroundColor: EatsTheme.controlBackground,
                                onSelected: (_) => setState(() => _selectedBass = null),
                              ),
                              const SizedBox(width: 8),
                              // Dropdown for custom slash bass
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: EatsTheme.controlBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      value: _selectedBass,
                                      hint: Text('Slash Bass Note (e.g. /E)', style: TextStyle(fontSize: 11, color: EatsTheme.textMuted)),
                                      dropdownColor: EatsTheme.controlBackground,
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('None (Default Root)', style: TextStyle(fontSize: 11, color: Colors.white)),
                                        ),
                                        ...List.generate(12, (pc) {
                                          return DropdownMenuItem<int?>(
                                            value: pc,
                                            child: Text('/${ChordTheory.pitchClassNames[pc]}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                                          );
                                        }),
                                      ],
                                      onChanged: (val) {
                                        setState(() => _selectedBass = val);
                                        _auditionCurrentChord();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),



                          const SizedBox(height: 16),

                          // Progression Presets Quick Apply
                          Text(
                            'QUICK PROGRESSION PRESETS',
                            style: EatsTheme.getPrimaryFontStyle(
                              color: EatsTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: EatsTheme.controlBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: EatsTheme.accentGold.withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ChordProgressionPreset>(
                                hint: const Text('Insert Progression from Bar...', style: TextStyle(fontSize: 11, color: EatsTheme.accentGold)),
                                dropdownColor: EatsTheme.controlBackground,
                                isExpanded: true,
                                items: ChordTheory.progressionPresets.map((preset) {
                                  return DropdownMenuItem<ChordProgressionPreset>(
                                    value: preset,
                                    child: Text(
                                      '${preset.name} (${preset.genre})',
                                      style: const TextStyle(fontSize: 11, color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (preset) {
                                  if (preset != null) {
                                    widget.dawState.applyChordProgressionPreset(preset, startBar: widget.targetBar);
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: EatsTheme.panelHeader,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  if (widget.initialChord != null)
                    TextButton.icon(
                      onPressed: () {
                        widget.dawState.removeChord(widget.initialChord!.id);
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete Chord', style: TextStyle(fontSize: 11)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('CANCEL', style: TextStyle(color: EatsTheme.textMuted, fontSize: 11)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      final c = _currentChord;
                      widget.dawState.addOrUpdateChord(c);
                      if (widget.onChordSelected != null) {
                        widget.onChordSelected!(c);
                      }
                      Navigator.of(context).pop(c);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EatsTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      'APPLY TO BAR ${widget.targetBar + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleWheelTap(Offset localPos, double width, double height) {
    final center = Offset(width / 2, height / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final outerRadius = width / 2;
    final midRadius = outerRadius * 0.65;
    final innerRadius = outerRadius * 0.32;

    if (distance < innerRadius || distance > outerRadius) {
      return; // Center display tap or outside wheel
    }

    // Angle in radians (-pi to pi), 0 is 3 o'clock. We want 12 o'clock (top) to be sector 0.
    double angle = math.atan2(dy, dx) + (math.pi / 2);
    if (angle < 0) angle += 2 * math.pi;

    // 12 sectors, each 2*pi / 12 radians
    final sectorIndex = ((angle + (math.pi / 12)) % (2 * math.pi) / (2 * math.pi / 12)).floor() % 12;

    if (distance >= midRadius) {
      // Outer ring: Major Keys
      final pitchClass = ChordTheory.circleOfFifthsMajor[sectorIndex];
      _onWheelSectorTapped(pitchClass, false);
    } else {
      // Inner ring: Minor Keys
      final pitchClass = ChordTheory.circleOfFifthsMinor[sectorIndex];
      _onWheelSectorTapped(pitchClass, true);
    }
  }
}

/// Custom painter for the dual-ring Circle of Fifths.
class _CircleOfFifthsPainter extends CustomPainter {
  final int selectedRoot;
  final ChordQuality selectedQuality;
  final int songKeyRoot;
  final bool isSongKeyMinor;

  _CircleOfFifthsPainter({
    required this.selectedRoot,
    required this.selectedQuality,
    required this.songKeyRoot,
    required this.isSongKeyMinor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 4;
    final midRadius = outerRadius * 0.65;
    final innerRadius = outerRadius * 0.32;

    final sectorAngle = 2 * math.pi / 12;

    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF0F1318)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, bgPaint);

    // Outer Ring: 12 Major Sectors
    for (int i = 0; i < 12; i++) {
      final pc = ChordTheory.circleOfFifthsMajor[i];
      final isSelected = pc == selectedRoot && (selectedQuality == ChordQuality.major || selectedQuality == ChordQuality.major7 || selectedQuality == ChordQuality.maj9 || selectedQuality == ChordQuality.dominant7 || selectedQuality == ChordQuality.dom9 || selectedQuality == ChordQuality.sus2 || selectedQuality == ChordQuality.sus4 || selectedQuality == ChordQuality.add9 || selectedQuality == ChordQuality.augmented);
      final isKeyTonic = pc == songKeyRoot && !isSongKeyMinor;
      final isDiatonic = _isDiatonicMajorSector(pc, songKeyRoot, isSongKeyMinor);

      final startAngle = (i * sectorAngle) - (math.pi / 2) - (sectorAngle / 2);

      // Draw Sector Arc
      final sectorPath = Path()
        ..arcTo(Rect.fromCircle(center: center, radius: outerRadius), startAngle, sectorAngle, false)
        ..arcTo(Rect.fromCircle(center: center, radius: midRadius), startAngle + sectorAngle, -sectorAngle, false)
        ..close();

      final sectorPaint = Paint()
        ..color = isSelected
            ? EatsTheme.primaryCyan.withOpacity(0.4)
            : (isKeyTonic
                ? EatsTheme.accentGold.withOpacity(0.3)
                : (isDiatonic ? const Color(0xFF1E293B) : const Color(0xFF141A22)))
        ..style = PaintingStyle.fill;

      canvas.drawPath(sectorPath, sectorPaint);

      // Border stroke
      final borderPaint = Paint()
        ..color = isSelected
            ? EatsTheme.primaryCyan
            : (isKeyTonic ? EatsTheme.accentGold : Colors.white.withOpacity(0.1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected || isKeyTonic ? 2.0 : 1.0;

      canvas.drawPath(sectorPath, borderPaint);

      // Draw Label
      final labelAngle = startAngle + (sectorAngle / 2);
      final labelRadius = (outerRadius + midRadius) / 2;
      final labelPos = Offset(
        center.dx + labelRadius * math.cos(labelAngle),
        center.dy + labelRadius * math.sin(labelAngle),
      );

      final textSpan = TextSpan(
        text: ChordTheory.circleMajorLabels[i],
        style: TextStyle(
          color: isSelected ? EatsTheme.primaryCyan : (isKeyTonic ? EatsTheme.accentGold : Colors.white),
          fontSize: 13,
          fontWeight: isSelected || isKeyTonic ? FontWeight.bold : FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(labelPos.dx - textPainter.width / 2, labelPos.dy - textPainter.height / 2),
      );
    }

    // Inner Ring: 12 Minor Sectors
    for (int i = 0; i < 12; i++) {
      final pc = ChordTheory.circleOfFifthsMinor[i];
      final isSelected = pc == selectedRoot && (selectedQuality == ChordQuality.minor || selectedQuality == ChordQuality.minor7 || selectedQuality == ChordQuality.min9 || selectedQuality == ChordQuality.diminished || selectedQuality == ChordQuality.halfDiminished7);
      final isKeyTonic = pc == songKeyRoot && isSongKeyMinor;
      final isDiatonic = _isDiatonicMinorSector(pc, songKeyRoot, isSongKeyMinor);

      final startAngle = (i * sectorAngle) - (math.pi / 2) - (sectorAngle / 2);

      final sectorPath = Path()
        ..arcTo(Rect.fromCircle(center: center, radius: midRadius), startAngle, sectorAngle, false)
        ..arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle + sectorAngle, -sectorAngle, false)
        ..close();

      final sectorPaint = Paint()
        ..color = isSelected
            ? EatsTheme.secondaryMagenta.withOpacity(0.4)
            : (isKeyTonic
                ? EatsTheme.accentGold.withOpacity(0.3)
                : (isDiatonic ? const Color(0xFF192231) : const Color(0xFF0F141B)))
        ..style = PaintingStyle.fill;

      canvas.drawPath(sectorPath, sectorPaint);

      final borderPaint = Paint()
        ..color = isSelected
            ? EatsTheme.secondaryMagenta
            : (isKeyTonic ? EatsTheme.accentGold : Colors.white.withOpacity(0.08))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected || isKeyTonic ? 2.0 : 1.0;

      canvas.drawPath(sectorPath, borderPaint);

      final labelAngle = startAngle + (sectorAngle / 2);
      final labelRadius = (midRadius + innerRadius) / 2;
      final labelPos = Offset(
        center.dx + labelRadius * math.cos(labelAngle),
        center.dy + labelRadius * math.sin(labelAngle),
      );

      final textSpan = TextSpan(
        text: ChordTheory.circleMinorLabels[i],
        style: TextStyle(
          color: isSelected ? EatsTheme.secondaryMagenta : (isKeyTonic ? EatsTheme.accentGold : EatsTheme.textSecondary),
          fontSize: 10,
          fontWeight: isSelected || isKeyTonic ? FontWeight.bold : FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(labelPos.dx - textPainter.width / 2, labelPos.dy - textPainter.height / 2),
      );
    }

    // Center Hub Circle
    final centerPaint = Paint()
      ..color = EatsTheme.backgroundDark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, centerPaint);

    final centerBorder = Paint()
      ..color = EatsTheme.primaryCyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, innerRadius, centerBorder);

    // Center icon/text
    final centerSpan = TextSpan(
      text: ChordTheory.pitchClassNames[selectedRoot % 12],
      style: TextStyle(
        color: EatsTheme.primaryCyan,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
    final centerPainter = TextPainter(
      text: centerSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    centerPainter.paint(canvas, Offset(center.dx - centerPainter.width / 2, center.dy - centerPainter.height / 2));
  }

  bool _isDiatonicMajorSector(int pc, int keyRoot, bool isMinor) {
    final diff = (pc - keyRoot + 12) % 12;
    if (!isMinor) {
      // In Major key: I (0), IV (5), V (7) are major
      return diff == 0 || diff == 5 || diff == 7;
    } else {
      // In Minor key: III (3), VI (8), VII (10) are major
      return diff == 3 || diff == 8 || diff == 10;
    }
  }

  bool _isDiatonicMinorSector(int pc, int keyRoot, bool isMinor) {
    final diff = (pc - keyRoot + 12) % 12;
    if (!isMinor) {
      // In Major key: ii (2), iii (4), vi (9) are minor
      return diff == 2 || diff == 4 || diff == 9;
    } else {
      // In Minor key: i (0), iv (5), v (7) are minor
      return diff == 0 || diff == 5 || diff == 7;
    }
  }

  @override
  bool shouldRepaint(covariant _CircleOfFifthsPainter oldDelegate) {
    return oldDelegate.selectedRoot != selectedRoot ||
        oldDelegate.selectedQuality != selectedQuality ||
        oldDelegate.songKeyRoot != songKeyRoot ||
        oldDelegate.isSongKeyMinor != isSongKeyMinor;
  }
}
