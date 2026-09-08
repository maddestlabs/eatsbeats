import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'compact_value_dialog.dart';

/// Unified persistent Note Inspector Sidebar shared across all EDIT pane views
/// (Piano Roll, Tracker, Score, and Script). Supports single-note and multi-note batch editing.
class NoteInspectorSidebar extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;
  final double snap;

  const NoteInspectorSidebar({
    super.key,
    required this.dawState,
    required this.track,
    this.snap = 1.0,
  });

  @override
  State<NoteInspectorSidebar> createState() => _NoteInspectorSidebarState();
}

class _NoteInspectorSidebarState extends State<NoteInspectorSidebar> {
  static const List<String> _articulations = [
    'normal',
    'pizzicato',
    'staccato',
    'legato',
    'harmonics',
    'slap',
    'flam',
  ];

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final selectedNotes = track.selectedNotes;
    if (selectedNotes.isEmpty) return const SizedBox.shrink();

    final isSingle = selectedNotes.length == 1;
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;

    return Material(
      elevation: 12,
      color: Colors.transparent,
      child: Container(
        width: 275,
        decoration: BoxDecoration(
          color: isGrungy ? const Color(0xFF1E1A17) : EatsTheme.panelBackground,
          border: Border(
            left: BorderSide(
              color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.panelHeader,
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(-3, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(track, selectedNotes, isSingle),
            if (isSingle)
              _buildSingleNoteSummary(track, selectedNotes.first)
            else
              _buildMultiNoteSummary(track, selectedNotes),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                children: isSingle
                    ? _buildSingleNoteSections(track, selectedNotes.first)
                    : _buildMultiNoteSections(track, selectedNotes),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(TrackChannel track, List<Note> selectedNotes, bool isSingle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: EatsTheme.panelHeader,
        border: Border(bottom: BorderSide(color: EatsTheme.panelHeader, width: 1.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: track.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSingle ? 'NOTE INSPECTOR' : 'MULTI-NOTE INSPECTOR',
              overflow: TextOverflow.ellipsis,
              style: EatsTheme.getDisplayFontStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: EatsTheme.textLight,
              ),
            ),
          ),
          // Delete selected
          IconButton(
            icon: Icon(
              isSingle ? Icons.delete_forever : Icons.delete_sweep,
              size: 17,
              color: Colors.redAccent,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            tooltip: isSingle ? 'Delete Note (Del)' : 'Delete ${selectedNotes.length} Selected Notes (Del)',
            onPressed: () {
              widget.dawState.removeNotes(track, track.selectedNoteIds);
            },
          ),
          const SizedBox(width: 2),
          // Close button
          IconButton(
            icon: Icon(Icons.close, size: 16, color: EatsTheme.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            tooltip: 'Clear Selection (Esc)',
            onPressed: () => widget.dawState.clearNoteSelection(track),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summaries
  // ---------------------------------------------------------------------------

  Widget _buildSingleNoteSummary(TrackChannel track, Note note) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: track.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: track.color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            Note.formatPitch(note.pitch),
            style: TextStyle(
              color: track.color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Step ${note.startStep.toStringAsFixed(note.startStep % 1 == 0 ? 0 : 1)} (${note.durationSteps.toStringAsFixed(2)} st)',
            style: TextStyle(
              color: EatsTheme.textLight,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiNoteSummary(TrackChannel track, List<Note> selectedNotes) {
    final count = selectedNotes.length;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: EatsTheme.primaryCyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count Notes Selected',
            style: TextStyle(
              color: EatsTheme.primaryCyan,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: EatsTheme.controlBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'BATCH MODE',
              style: TextStyle(
                color: EatsTheme.textLight,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single-Note Sections
  // ---------------------------------------------------------------------------

  List<Widget> _buildSingleNoteSections(TrackChannel track, Note note) {
    final nudgeStep = widget.snap > 0 ? widget.snap : 1.0;
    final velPercent = (note.velocity * 100).round();
    final currentArt = note.articulation ?? 'normal';

    return [
      // Pitch Transposition
      _buildSidebarSectionHeader('PITCH TRANSPOSE'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCompactButton('-12', () => widget.dawState.transposeNotes(track, [note.id], -12), tooltip: '-1 Octave'),
          _buildCompactButton('-1', () => widget.dawState.transposeNotes(track, [note.id], -1), tooltip: '-1 Semitone'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: EatsTheme.controlBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              Note.formatPitch(note.pitch),
              style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          _buildCompactButton('+1', () => widget.dawState.transposeNotes(track, [note.id], 1), tooltip: '+1 Semitone'),
          _buildCompactButton('+12', () => widget.dawState.transposeNotes(track, [note.id], 12), tooltip: '+1 Octave'),
        ],
      ),
      const SizedBox(height: 12),

      // Position (Start Step)
      _buildSidebarSectionHeader('POSITION (START STEP)'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onLongPress: () => _openManualPositionDialog(context, track, note),
            onSecondaryTap: () => _openManualPositionDialog(context, track, note),
            child: Tooltip(
              message: 'Tap / Right-click for manual numeric step input',
              child: Text(
                'Step ${note.startStep.toStringAsFixed(note.startStep % 1 == 0 ? 0 : 1)}',
                style: TextStyle(color: EatsTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactButton('-STEP', () => widget.dawState.nudgeNotesPosition(track, [note.id], -nudgeStep), tooltip: 'Nudge Left'),
              const SizedBox(width: 4),
              _buildCompactButton('+STEP', () => widget.dawState.nudgeNotesPosition(track, [note.id], nudgeStep), tooltip: 'Nudge Right'),
            ],
          ),
        ],
      ),
      const SizedBox(height: 4),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          activeTrackColor: EatsTheme.accentGold,
          inactiveTrackColor: EatsTheme.controlBackground,
          thumbColor: EatsTheme.accentGold,
        ),
        child: Slider(
          value: note.startStep.clamp(0.0, 64.0),
          min: 0.0,
          max: 64.0,
          onChanged: (val) {
            note.startStep = val;
            widget.dawState.updateNote(track, note);
          },
        ),
      ),
      const SizedBox(height: 12),

      // Length / Duration
      _buildSidebarSectionHeader('LENGTH / DURATION'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onLongPress: () => _openManualDurationDialog(context, track, note),
            onSecondaryTap: () => _openManualDurationDialog(context, track, note),
            child: Tooltip(
              message: 'Tap / Right-click for manual numeric input',
              child: Text(
                '${note.durationSteps.toStringAsFixed(2)} steps',
                style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactButton('-LEN', () => widget.dawState.changeNotesDuration(track, [note.id], -nudgeStep), tooltip: 'Shorten'),
              const SizedBox(width: 4),
              _buildCompactButton('+LEN', () => widget.dawState.changeNotesDuration(track, [note.id], nudgeStep), tooltip: 'Lengthen'),
            ],
          ),
        ],
      ),
      const SizedBox(height: 4),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          activeTrackColor: EatsTheme.primaryCyan,
          inactiveTrackColor: EatsTheme.controlBackground,
          thumbColor: EatsTheme.primaryCyan,
        ),
        child: Slider(
          value: note.durationSteps.clamp(0.25, 16.0),
          min: 0.25,
          max: 16.0,
          onChanged: (val) {
            note.durationSteps = val;
            widget.dawState.updateNote(track, note);
          },
        ),
      ),
      const SizedBox(height: 12),

      // Velocity
      _buildSidebarSectionHeader('VELOCITY ($velPercent%)'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onLongPress: () => _openManualVelocityDialog(context, track, note),
            onSecondaryTap: () => _openManualVelocityDialog(context, track, note),
            child: Tooltip(
              message: 'Tap / Right-click for manual numeric input',
              child: Text(
                '$velPercent%',
                style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up, size: 16),
            color: EatsTheme.primaryCyan,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Preview Note Sound',
            onPressed: () {
              widget.dawState.audioEngine.playNoteOrSample(
                track: track,
                midiNote: note.pitch,
                velocity: note.velocity,
              );
            },
          ),
        ],
      ),
      const SizedBox(height: 4),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          activeTrackColor: EatsTheme.primaryCyan,
          inactiveTrackColor: EatsTheme.controlBackground,
          thumbColor: EatsTheme.primaryCyan,
        ),
        child: Slider(
          value: note.velocity.clamp(0.05, 1.0),
          min: 0.05,
          max: 1.0,
          onChanged: (val) => widget.dawState.setNotesVelocity(track, [note.id], val),
          onChangeEnd: (val) {
            widget.dawState.audioEngine.playNoteOrSample(
              track: track,
              midiNote: note.pitch,
              velocity: val.clamp(0.05, 1.0),
            );
          },
        ),
      ),
      const SizedBox(height: 12),

      // Articulations (pizzicato, staccato, etc.)
      _buildSidebarSectionHeader('ARTICULATION'),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _articulations.map((art) {
          final isSelected = currentArt == art;
          return InkWell(
            onTap: () {
              widget.dawState.setNoteArticulation(track, note, art == 'normal' ? null : art);
              setState(() {});
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? EatsTheme.primaryCyan.withOpacity(0.25) : EatsTheme.controlBackground,
                border: Border.all(color: isSelected ? EatsTheme.primaryCyan : Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                art.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),

      // Slide / Glissando / Bend
      _buildSidebarSectionHeader('NOTE TYPE / GLISSANDO'),
      Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => widget.dawState.setNoteSlide(track, note, false),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: !note.isSlide ? EatsTheme.primaryCyan.withOpacity(0.25) : EatsTheme.controlBackground,
                  border: Border.all(color: !note.isSlide ? EatsTheme.primaryCyan : Colors.transparent),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 12, color: !note.isSlide ? EatsTheme.primaryCyan : EatsTheme.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        'REGULAR',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: !note.isSlide ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () => widget.dawState.setNoteSlide(track, note, true),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: note.isSlide ? EatsTheme.accentGold.withOpacity(0.25) : EatsTheme.controlBackground,
                  border: Border.all(color: note.isSlide ? EatsTheme.accentGold : Colors.transparent),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 12, color: note.isSlide ? EatsTheme.accentGold : EatsTheme.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        'GLISS / BEND',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: note.isSlide ? EatsTheme.accentGold : EatsTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Lyric / Syllable
      _buildSidebarSectionHeader('LYRIC / SYLLABLE'),
      Row(
        children: [
          Expanded(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: EatsTheme.controlBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EatsTheme.textMuted.withOpacity(0.3)),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                note.lyric != null && note.lyric!.isNotEmpty ? note.lyric! : '(No syllable)',
                style: TextStyle(
                  color: note.lyric != null && note.lyric!.isNotEmpty ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildCompactButton('EDIT', () {
            showCompactValueEditDialog(
              context: context,
              title: 'NOTE LYRIC SYLLABLE',
              initialValue: note.lyric ?? '',
              minMaxHint: 'Enter syllable (e.g. "Wel-", "come")',
              accentColor: EatsTheme.primaryCyan,
              onSubmit: (val) {
                widget.dawState.setNoteLyric(track, note, val);
                setState(() {});
              },
            );
          }),
          if (note.lyric != null && note.lyric!.isNotEmpty) ...[
            const SizedBox(width: 4),
            _buildCompactButton('CLEAR', () {
              widget.dawState.setNoteLyric(track, note, null);
              setState(() {});
            }),
          ],
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  // ---------------------------------------------------------------------------
  // Multi-Note Sections
  // ---------------------------------------------------------------------------

  List<Widget> _buildMultiNoteSections(TrackChannel track, List<Note> selectedNotes) {
    final nudgeStep = widget.snap > 0 ? widget.snap : 1.0;
    final count = selectedNotes.length;
    final avgVel = selectedNotes.map((n) => n.velocity).reduce((a, b) => a + b) / count;
    final velPercent = (avgVel * 100).round();
    final noteIds = track.selectedNoteIds;

    return [
      // Batch Pitch Transpose
      _buildSidebarSectionHeader('BATCH PITCH TRANSPOSE'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCompactButton('-12', () => widget.dawState.transposeNotes(track, noteIds, -12), tooltip: '-1 Octave (All)'),
          _buildCompactButton('-1', () => widget.dawState.transposeNotes(track, noteIds, -1), tooltip: '-1 Semitone (All)'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: EatsTheme.controlBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '± PITCH',
              style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          _buildCompactButton('+1', () => widget.dawState.transposeNotes(track, noteIds, 1), tooltip: '+1 Semitone (All)'),
          _buildCompactButton('+12', () => widget.dawState.transposeNotes(track, noteIds, 12), tooltip: '+1 Octave (All)'),
        ],
      ),
      const SizedBox(height: 12),

      // Batch Position Nudge
      _buildSidebarSectionHeader('BATCH POSITION NUDGE'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Shift by ${nudgeStep.toStringAsFixed(widget.snap > 0 && widget.snap < 1 ? 2 : 0)} step(s)',
            style: TextStyle(color: EatsTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactButton('-STEP', () => widget.dawState.nudgeNotesPosition(track, noteIds, -nudgeStep), tooltip: 'Nudge Left (All)'),
              const SizedBox(width: 4),
              _buildCompactButton('+STEP', () => widget.dawState.nudgeNotesPosition(track, noteIds, nudgeStep), tooltip: 'Nudge Right (All)'),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Batch Duration
      _buildSidebarSectionHeader('BATCH LENGTH / DURATION'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Change duration',
            style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactButton('-LEN', () => widget.dawState.changeNotesDuration(track, noteIds, -nudgeStep), tooltip: 'Shorten (All)'),
              const SizedBox(width: 4),
              _buildCompactButton('+LEN', () => widget.dawState.changeNotesDuration(track, noteIds, nudgeStep), tooltip: 'Lengthen (All)'),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Batch Velocity
      _buildSidebarSectionHeader('BATCH VELOCITY ($velPercent% avg)'),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          activeTrackColor: EatsTheme.primaryCyan,
          inactiveTrackColor: EatsTheme.controlBackground,
          thumbColor: EatsTheme.primaryCyan,
        ),
        child: Slider(
          value: avgVel.clamp(0.05, 1.0),
          min: 0.05,
          max: 1.0,
          onChanged: (val) => widget.dawState.setNotesVelocity(track, noteIds, val),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCompactButton('25%', () => widget.dawState.setNotesVelocity(track, noteIds, 0.25), tooltip: 'Soft (25%)'),
          _buildCompactButton('50%', () => widget.dawState.setNotesVelocity(track, noteIds, 0.50), tooltip: 'Medium (50%)'),
          _buildCompactButton('75%', () => widget.dawState.setNotesVelocity(track, noteIds, 0.75), tooltip: 'Strong (75%)'),
          _buildCompactButton('100%', () => widget.dawState.setNotesVelocity(track, noteIds, 1.00), tooltip: 'Full (100%)'),
          _buildCompactButton('Humanize', () => widget.dawState.batchHumanizeNotes(track, noteIds), tooltip: 'Humanize (±15%)'),
        ],
      ),
      const SizedBox(height: 12),

      // Batch Articulations
      _buildSidebarSectionHeader('BATCH ARTICULATION'),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _articulations.map((art) {
          return InkWell(
            onTap: () {
              widget.dawState.setNotesArticulation(track, noteIds, art == 'normal' ? null : art);
              setState(() {});
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: EatsTheme.controlBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                art.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: EatsTheme.textLight,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),

      // Selection Utilities
      _buildSidebarSectionHeader('SELECTION UTILITIES'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildActionButton(
            icon: Icons.copy,
            label: 'Copy Lua',
            tooltip: 'Copy selected notes as Lua code (Ctrl+C)',
            onTap: () async {
              await widget.dawState.copyNotesToClipboard(track, noteIds);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied ${noteIds.length} notes to clipboard'), duration: const Duration(seconds: 1)),
                );
              }
            },
          ),
          _buildActionButton(
            icon: Icons.cut,
            label: 'Cut',
            tooltip: 'Cut selected notes to clipboard (Ctrl+X)',
            onTap: () async {
              await widget.dawState.cutNotesToClipboard(track, noteIds);
              widget.dawState.clearNoteSelection(track);
            },
          ),
          _buildActionButton(
            icon: Icons.select_all,
            label: 'Select All',
            tooltip: 'Select all notes in clip (Ctrl+A)',
            onTap: () => widget.dawState.selectAllNotes(track),
          ),
          _buildActionButton(
            icon: Icons.flip,
            label: 'Invert',
            tooltip: 'Invert note selection',
            onTap: () => widget.dawState.invertNoteSelection(track),
          ),
          _buildActionButton(
            icon: Icons.grid_on,
            label: 'Quantize Start',
            tooltip: 'Snap note start times to grid',
            onTap: () => widget.dawState.batchQuantizeNotes(track, noteIds, widget.snap),
          ),
          _buildActionButton(
            icon: Icons.trending_up,
            label: 'Set All as Bend',
            tooltip: 'Convert all selected notes to Bend/Slide notes',
            onTap: () => widget.dawState.setNotesSlide(track, noteIds, true),
          ),
          _buildActionButton(
            icon: Icons.music_note,
            label: 'Set All Regular',
            tooltip: 'Convert all selected notes to Regular notes',
            onTap: () => widget.dawState.setNotesSlide(track, noteIds, false),
          ),
          _buildActionButton(
            icon: Icons.deselect,
            label: 'Clear',
            tooltip: 'Clear selection (Esc)',
            onTap: () => widget.dawState.clearNoteSelection(track),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  // ---------------------------------------------------------------------------
  // Helpers & Dialogs
  // ---------------------------------------------------------------------------

  Widget _buildSidebarSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          color: EatsTheme.textMuted,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCompactButton(String label, VoidCallback onTap, {String? tooltip}) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: EatsTheme.controlBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EatsTheme.panelHeader),
        ),
        child: Text(
          label,
          style: TextStyle(color: EatsTheme.textLight, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: EatsTheme.controlBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EatsTheme.panelHeader),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: EatsTheme.primaryCyan),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: EatsTheme.textLight, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  void _openManualPositionDialog(BuildContext context, TrackChannel track, Note note) {
    showCompactValueEditDialog(
      context: context,
      title: 'EDIT NOTE START STEP',
      initialValue: note.startStep.toStringAsFixed(2),
      minMaxHint: 'Enter step (0.0 to 64.0)',
      accentColor: EatsTheme.accentGold,
      onSubmit: (val) {
        final parsed = double.tryParse(val);
        if (parsed != null) {
          note.startStep = parsed.clamp(0.0, 64.0);
          widget.dawState.updateNote(track, note);
        }
      },
    );
  }

  void _openManualDurationDialog(BuildContext context, TrackChannel track, Note note) {
    showCompactValueEditDialog(
      context: context,
      title: 'EDIT NOTE DURATION',
      initialValue: note.durationSteps.toStringAsFixed(2),
      minMaxHint: 'Enter duration in steps (0.25 to 16.0)',
      accentColor: EatsTheme.primaryCyan,
      onSubmit: (val) {
        final parsed = double.tryParse(val);
        if (parsed != null) {
          note.durationSteps = parsed.clamp(0.25, 16.0);
          widget.dawState.updateNote(track, note);
        }
      },
    );
  }

  void _openManualVelocityDialog(BuildContext context, TrackChannel track, Note note) {
    showCompactValueEditDialog(
      context: context,
      title: 'EDIT NOTE VELOCITY (%)',
      initialValue: (note.velocity * 100).round().toString(),
      minMaxHint: 'Enter velocity 1% to 100%',
      accentColor: EatsTheme.primaryCyan,
      onSubmit: (val) {
        final parsed = double.tryParse(val);
        if (parsed != null) {
          widget.dawState.setNotesVelocity(track, [note.id], (parsed / 100).clamp(0.01, 1.0));
        }
      },
    );
  }
}
