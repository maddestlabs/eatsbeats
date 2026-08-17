import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/compact_value_dialog.dart';

class PianoRollView extends StatefulWidget {
  final DawState dawState;

  const PianoRollView({super.key, required this.dawState});

  @override
  State<PianoRollView> createState() => _PianoRollViewState();
}

class _PianoRollViewState extends State<PianoRollView> {
  static const int minPitch = 24; // C1
  static const int maxPitch = 84; // C6
  static const int totalKeys = maxPitch - minPitch + 1;
  static const int totalSteps = 64; // Extended horizontal grid (16 bars of 4 steps)

  double _stepWidth = 28.0;
  double _keyHeight = 24.0;
  double _baseStepWidth = 28.0;
  double _baseKeyHeight = 24.0;

  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _keysScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();

  bool _isSyncingScroll = false;
  String? _selectedNoteId;

  // Draggable Note Properties dialog state
  Offset? _notePropertiesOffset;
  String? _draggedNoteId;

  // Move tracking variables
  String? _activeMoveNoteId;
  double? _moveStartStep;
  int? _moveStartPitch;
  Offset? _moveStartPos;

  // Resize tracking variables
  String? _activeResizeNoteId;
  double? _resizeStartDuration;
  Offset? _resizeStartPos;

  // Active keyboard pressed keys map (pitch -> velocity) for visual feedback
  final Map<int, double> _activeKeyboardPitches = {};
  bool _isMiddleMouseDragging = false;
  DateTime? _lastNoteTapTime;
  String? _lastNoteTapId;
  DateTime? _lastNotePointerDownTime;

  void _handleKeyPointerDown(PointerDownEvent e, int pitch, double keyWidth) {
    final normX = (e.localPosition.dx / keyWidth).clamp(0.0, 1.0);
    final velocity = (0.15 + 0.85 * normX).clamp(0.15, 1.0);
    _activeKeyboardPitches[pitch] = velocity;
    final track = widget.dawState.activeTrack;
    widget.dawState.audioEngine.playNoteOrSample(
      track: track,
      midiNote: pitch,
      velocity: velocity,
    );
    setState(() {});
  }

  void _handleKeyPointerMove(PointerMoveEvent e, int pitch, double keyWidth) {
    final normX = (e.localPosition.dx / keyWidth).clamp(0.0, 1.0);
    final velocity = (0.15 + 0.85 * normX).clamp(0.15, 1.0);
    if (_activeKeyboardPitches[pitch] != velocity) {
      _activeKeyboardPitches[pitch] = velocity;
      setState(() {});
    }
  }

  void _handleKeyPointerUp(int pitch) {
    if (_activeKeyboardPitches.containsKey(pitch)) {
      _activeKeyboardPitches.remove(pitch);
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _centerViewOnNotesOrDefault();
      }
    });
  }

  void _centerViewOnNotesOrDefault({bool animate = false}) {
    if (!_gridScrollController.hasClients) return;
    final track = widget.dawState.activeTrack;
    final maxScroll = _gridScrollController.position.maxScrollExtent;
    final viewportH = _gridScrollController.position.viewportDimension;

    double targetY;

    if (track.notes.isNotEmpty) {
      int minP = 127;
      int maxP = 0;
      for (final n in track.notes) {
        if (n.pitch < minP) minP = n.pitch;
        if (n.pitch > maxP) maxP = n.pitch;
      }
      final midPitch = (minP + maxP) / 2.0;
      final midKeyIdx = maxPitch - midPitch;
      targetY = (midKeyIdx * _keyHeight) - (viewportH / 2) + (_keyHeight / 2);
    } else {
      // Default to showing C4 (MIDI pitch 60) and downward
      const defaultPitch = 60; // C4
      final c4KeyIdx = maxPitch - defaultPitch;
      targetY = c4KeyIdx * _keyHeight;
    }

    targetY = targetY.clamp(0.0, maxScroll);

    if (animate) {
      _gridScrollController.animateTo(
        targetY,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _gridScrollController.jumpTo(targetY);
    }
    _syncKeysScroll();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _keysScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  bool _isBlackKey(int midiPitch) {
    final noteInOctave = midiPitch % 12;
    return noteInOctave == 1 || noteInOctave == 3 || noteInOctave == 6 || noteInOctave == 8 || noteInOctave == 10;
  }

  String _getNoteName(int midiPitch) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final name = names[midiPitch % 12];
    final octave = (midiPitch / 12).floor() - 1;
    return '$name$octave';
  }

  void _syncKeysScroll() {
    if (!_isSyncingScroll && _keysScrollController.hasClients && _gridScrollController.hasClients) {
      _isSyncingScroll = true;
      _keysScrollController.jumpTo(_gridScrollController.offset);
      _isSyncingScroll = false;
    }
  }

  void _zoom(double factor) {
    final oldStepWidth = _stepWidth;
    final oldKeyHeight = _keyHeight;

    final newStepWidth = (_stepWidth * factor).clamp(12.0, 80.0);
    final newKeyHeight = (_keyHeight * factor).clamp(14.0, 48.0);

    setState(() {
      _stepWidth = newStepWidth;
      _keyHeight = newKeyHeight;
    });

    _adjustScrollForZoom(oldStepWidth, newStepWidth, oldKeyHeight, newKeyHeight);
  }

  void _resetZoom() {
    final oldStepWidth = _stepWidth;
    final oldKeyHeight = _keyHeight;

    setState(() {
      _stepWidth = 28.0;
      _keyHeight = 24.0;
    });

    _adjustScrollForZoom(oldStepWidth, 28.0, oldKeyHeight, 24.0);
  }

  void _adjustScrollForZoom(double oldWidth, double newWidth, double oldHeight, double newHeight) {
    if (oldWidth > 0 && _horizontalScroll.hasClients) {
      final ratioX = newWidth / oldWidth;
      final targetX = (_horizontalScroll.offset * ratioX).clamp(0.0, _horizontalScroll.position.maxScrollExtent);
      _horizontalScroll.jumpTo(targetX);
    }

    if (oldHeight > 0 && _gridScrollController.hasClients) {
      final ratioY = newHeight / oldHeight;
      final targetY = (_gridScrollController.offset * ratioY).clamp(0.0, _gridScrollController.position.maxScrollExtent);
      _gridScrollController.jumpTo(targetY);
      _syncKeysScroll();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncKeysScroll();
      }
    });
  }

  void _ensureNoteAndMenuVisible(Note note, {bool forceVerticalScroll = false}) {
    if (!mounted) return;

    final keyIdx = maxPitch - note.pitch;
    final noteTop = keyIdx * _keyHeight + 1;
    final noteLeft = note.startStep * _stepWidth + 1;
    final noteWidth = ((note.durationSteps * _stepWidth) - 2).clamp(8.0, double.infinity);

    // Vertical scroll check (only when forceVerticalScroll is true, e.g. for Octave Transpose +12/-12)
    if (forceVerticalScroll && _gridScrollController.hasClients) {
      final scrollY = _gridScrollController.offset;
      final viewportH = _gridScrollController.position.viewportDimension;
      final maxScrollY = _gridScrollController.position.maxScrollExtent;

      double? targetScrollY;
      if (noteTop - 100 < scrollY) {
        targetScrollY = (noteTop - 110).clamp(0.0, maxScrollY);
      } else if (noteTop + _keyHeight + 100 > scrollY + viewportH) {
        targetScrollY = (noteTop + _keyHeight + 110 - viewportH).clamp(0.0, maxScrollY);
      }

      if (targetScrollY != null && (targetScrollY - scrollY).abs() > 2) {
        _gridScrollController.animateTo(
          targetScrollY,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        _syncKeysScroll();
      }
    }

    // Horizontal scroll check: only scroll if note is actually outside visible area
    if (_horizontalScroll.hasClients) {
      final scrollX = _horizontalScroll.offset;
      final viewportW = _horizontalScroll.position.viewportDimension;
      final maxScrollX = _horizontalScroll.position.maxScrollExtent;

      double? targetScrollX;
      if (noteLeft < scrollX) {
        targetScrollX = (noteLeft - 30).clamp(0.0, maxScrollX);
      } else if (noteLeft + noteWidth > scrollX + viewportW) {
        targetScrollX = (noteLeft + noteWidth + 30 - viewportW).clamp(0.0, maxScrollX);
      }

      if (targetScrollX != null && (targetScrollX - scrollX).abs() > 4) {
        _horizontalScroll.jumpTo(targetScrollX);
      }
    }
  }

  void _selectPreviousNote(TrackChannel track) {
    if (track.notes.isEmpty) return;
    final sorted = List<Note>.from(track.notes)..sort((a, b) {
      final stepComp = a.startStep.compareTo(b.startStep);
      if (stepComp != 0) return stepComp;
      return a.pitch.compareTo(b.pitch);
    });

    int currIdx = sorted.indexWhere((n) => n.id == _selectedNoteId);
    int targetIdx;
    if (currIdx <= 0) {
      targetIdx = sorted.length - 1;
    } else {
      targetIdx = currIdx - 1;
    }

    final note = sorted[targetIdx];
    setState(() {
      _selectedNoteId = note.id;
    });
    widget.dawState.audioEngine.playNoteOrSample(
      track: track,
      midiNote: note.pitch,
      velocity: note.velocity,
    );
    _ensureNoteAndMenuVisible(note);
  }

  void _selectNextNote(TrackChannel track) {
    if (track.notes.isEmpty) return;
    final sorted = List<Note>.from(track.notes)..sort((a, b) {
      final stepComp = a.startStep.compareTo(b.startStep);
      if (stepComp != 0) return stepComp;
      return a.pitch.compareTo(b.pitch);
    });

    int currIdx = sorted.indexWhere((n) => n.id == _selectedNoteId);
    int targetIdx;
    if (currIdx == -1 || currIdx >= sorted.length - 1) {
      targetIdx = 0;
    } else {
      targetIdx = currIdx + 1;
    }

    final note = sorted[targetIdx];
    setState(() {
      _selectedNoteId = note.id;
    });
    widget.dawState.audioEngine.playNoteOrSample(
      track: track,
      midiNote: note.pitch,
      velocity: note.velocity,
    );
    _ensureNoteAndMenuVisible(note);
  }

  void _transposeSelectedNote(TrackChannel track, Note note, int semitones) {
    final newPitch = (note.pitch + semitones).clamp(minPitch, maxPitch);
    if (newPitch != note.pitch) {
      final isOctave = semitones.abs() == 12;
      if (isOctave) {
        _notePropertiesOffset = null; // Auto-reposition dialog to follow octave transpose!
      }
      final updatedNote = note.copyWith(pitch: newPitch);
      widget.dawState.updateNote(track, updatedNote);
      widget.dawState.audioEngine.playNoteOrSample(
        track: track,
        midiNote: newPitch,
        velocity: note.velocity,
      );
      _ensureNoteAndMenuVisible(updatedNote, forceVerticalScroll: isOctave);
    }
  }

  void _changeSelectedNotePosition(TrackChannel track, Note note, double newStartStep) {
    final maxStep = (totalSteps - note.durationSteps).clamp(0.0, double.infinity);
    final clamped = newStartStep.clamp(0.0, maxStep);
    double snappedStep = clamped;
    final snap = widget.dawState.quantizeSnap;
    if (snap > 0) {
      snappedStep = (clamped / snap).round() * snap;
      snappedStep = snappedStep.clamp(0.0, maxStep);
    }
    widget.dawState.updateNote(track, note.copyWith(startStep: snappedStep));
  }

  void _changeSelectedNoteDuration(TrackChannel track, Note note, double newDur) {
    final minDur = widget.dawState.quantizeSnap > 0 ? widget.dawState.quantizeSnap : 0.25;
    final clamped = newDur.clamp(minDur, totalSteps - note.startStep);
    widget.dawState.updateNote(track, note.copyWith(durationSteps: clamped));
  }

  void _changeSelectedNoteVelocity(TrackChannel track, Note note, double newVel) {
    final clamped = newVel.clamp(0.05, 1.0);
    widget.dawState.updateNote(track, note.copyWith(velocity: clamped));
  }

  void _openManualPositionDialog(BuildContext context, TrackChannel track, Note note) {
    showCompactValueEditDialog(
      context: context,
      title: 'EDIT NOTE POSITION (STEP)',
      initialValue: note.startStep.toStringAsFixed(2),
      minMaxHint: 'Range: Step 0.0 to ${(totalSteps - note.durationSteps).toStringAsFixed(1)}',
      accentColor: EatsTheme.accentGold,
      onSubmit: (val) {
        final parsed = double.tryParse(val);
        if (parsed != null) {
          _changeSelectedNotePosition(track, note, parsed);
        }
      },
    );
  }

  void _openManualDurationDialog(BuildContext context, TrackChannel track, Note note) {
    showCompactValueEditDialog(
      context: context,
      title: 'EDIT NOTE DURATION (STEPS)',
      initialValue: note.durationSteps.toStringAsFixed(2),
      minMaxHint: 'Min: 0.25 steps, Max: ${(totalSteps - note.startStep).toStringAsFixed(1)} steps',
      accentColor: EatsTheme.primaryCyan,
      onSubmit: (val) {
        final parsed = double.tryParse(val);
        if (parsed != null && parsed > 0) {
          _changeSelectedNoteDuration(track, note, parsed);
        }
      },
    );
  }

  void _openManualVelocityDialog(BuildContext context, TrackChannel track, Note note) {
    final velPercent = (note.velocity * 100).round();
    showCompactValueEditDialog(
      context: context,
      title: 'EDIT NOTE VELOCITY (%)',
      initialValue: '$velPercent',
      minMaxHint: 'Range: 5% to 100%',
      accentColor: EatsTheme.accentGold,
      onSubmit: (val) {
        final parsed = double.tryParse(val);
        if (parsed != null) {
          final normalized = (parsed / 100.0).clamp(0.05, 1.0);
          _changeSelectedNoteVelocity(track, note, normalized);
          widget.dawState.audioEngine.playNoteOrSample(
            track: track,
            midiNote: note.pitch,
            velocity: normalized,
          );
        }
      },
    );
  }

  Widget _buildCompactButton(String label, VoidCallback onTap, {String? tooltip}) {
    final btn = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: EatsTheme.controlBackground,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: EatsTheme.textMuted.withOpacity(0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _buildNoteInspectorSidebar(TrackChannel track, Note note, double snap) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final maxPosStep = (totalSteps - note.durationSteps).clamp(0.0, double.infinity);
    final nudgeStep = snap > 0 ? snap : 1.0;
    final minDur = snap > 0 ? snap : 0.25;
    final velPercent = (note.velocity * 100).round();

    return Material(
      elevation: 12,
      color: Colors.transparent,
      child: Container(
        width: 270,
        decoration: BoxDecoration(
          color: isGrungy ? const Color(0xFF1E1A17) : EatsTheme.panelBackground,
          border: Border(
            left: BorderSide(color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.panelHeader, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(-3, 0)),
          ],
        ),
        child: Column(
          children: [
            // Sidebar Header (Note Title & Badges)
            Container(
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
                  Text(
                    'NOTE INSPECTOR',
                    style: EatsTheme.getDisplayFontStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: EatsTheme.textLight,
                    ),
                  ),
                  const Spacer(),
                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Delete Note (Del)',
                    onPressed: () {
                      widget.dawState.removeNote(track, note.id);
                      setState(() => _selectedNoteId = null);
                    },
                  ),
                  const SizedBox(width: 4),
                  // Close Button
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: EatsTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Close Inspector',
                    onPressed: () => setState(() => _selectedNoteId = null),
                  ),
                ],
              ),
            ),

            // Note Summary Badge
            Container(
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
                    _getNoteName(note.pitch),
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
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                children: [
                  // Section 1: Pitch Transposition
                  _buildSidebarSectionHeader('PITCH TRANSPOSE'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCompactButton('-12', () => _transposeSelectedNote(track, note, -12), tooltip: '-1 Octave'),
                      _buildCompactButton('-1', () => _transposeSelectedNote(track, note, -1), tooltip: '-1 Semitone'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getNoteName(note.pitch),
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildCompactButton('+1', () => _transposeSelectedNote(track, note, 1), tooltip: '+1 Semitone'),
                      _buildCompactButton('+12', () => _transposeSelectedNote(track, note, 12), tooltip: '+1 Octave'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 2: Position (Start Step)
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
                          _buildCompactButton('-STEP', () => _changeSelectedNotePosition(track, note, note.startStep - nudgeStep), tooltip: 'Nudge Left'),
                          const SizedBox(width: 4),
                          _buildCompactButton('+STEP', () => _changeSelectedNotePosition(track, note, note.startStep + nudgeStep), tooltip: 'Nudge Right'),
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
                      value: note.startStep.clamp(0.0, maxPosStep),
                      min: 0.0,
                      max: math.max(0.1, maxPosStep),
                      onChanged: (val) => _changeSelectedNotePosition(track, note, val),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section 3: Length / Duration
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
                          _buildCompactButton('-LEN', () => _changeSelectedNoteDuration(track, note, note.durationSteps - nudgeStep), tooltip: 'Shorten'),
                          const SizedBox(width: 4),
                          _buildCompactButton('+LEN', () => _changeSelectedNoteDuration(track, note, note.durationSteps + nudgeStep), tooltip: 'Lengthen'),
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
                      value: note.durationSteps.clamp(minDur, 16.0),
                      min: minDur,
                      max: 16.0,
                      onChanged: (val) => _changeSelectedNoteDuration(track, note, val),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section 4: Velocity
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
                      onChanged: (val) => _changeSelectedNoteVelocity(track, note, val),
                      onChangeEnd: (val) {
                        widget.dawState.audioEngine.playNoteOrSample(
                          track: track,
                          midiNote: note.pitch,
                          velocity: val.clamp(0.05, 1.0),
                        );
                      },
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

  Widget _buildSidebarSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          color: EatsTheme.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.dawState.activeTrack;
    final activeClip = widget.dawState.activeTrackClip;
    final activeClipSteps = (activeClip.barLength * 4.0).clamp(4.0, 64.0);
    final snap = widget.dawState.quantizeSnap;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Find selected note object if it still exists
    Note? selectedNote;
    double? selectedNoteLeft;
    double? selectedNoteTop;
    double? selectedNoteWidth;
    double? selectedNoteHeight;

    if (_selectedNoteId != null) {
      final idx = track.notes.indexWhere((n) => n.id == _selectedNoteId);
      if (idx != -1) {
        selectedNote = track.notes[idx];
        final keyIdx = maxPitch - selectedNote.pitch;
        selectedNoteLeft = selectedNote.startStep * _stepWidth + 1;
        selectedNoteTop = keyIdx * _keyHeight + 1;
        selectedNoteWidth = ((selectedNote.durationSteps * _stepWidth) - 2).clamp(8.0, double.infinity);
        selectedNoteHeight = _keyHeight - 2;
      }
    }

    return Stack(
      children: [
        RepaintBoundary(
          child: Column(
            children: [
            // Sub-toolbar for Piano Roll (Note Stepper, Snap & Zoom Controls)
            Container(
              height: 32,
              color: EatsTheme.panelBackground,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Text(
                    'PIANO ROLL',
                    style: EatsTheme.getPrimaryFontStyle(
                      color: EatsTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              const SizedBox(width: 8),

              // Note Stepper Buttons
              Text('NOTES:', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 12),
                color: EatsTheme.primaryCyan,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Select Previous Note',
                onPressed: () => _selectPreviousNote(track),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 12),
                color: EatsTheme.primaryCyan,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Select Next Note',
                onPressed: () => _selectNextNote(track),
              ),
              IconButton(
                icon: const Icon(Icons.center_focus_strong, size: 14),
                color: EatsTheme.primaryCyan,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Center View vertically on Clip Notes (or C4)',
                onPressed: () => _centerViewOnNotesOrDefault(animate: true),
              ),
              const SizedBox(width: 8),

              // Clip Length Stepper
              Text('CLIP:', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 14),
                color: EatsTheme.accentGold,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                tooltip: 'Shorten Clip Loop Length',
                onPressed: () {
                  final activeClip = widget.dawState.activeTrackClip;
                  if (activeClip.barLength > 1) {
                    widget.dawState.setTrackClipBarLength(activeClip, activeClip.barLength - 1);
                  }
                },
              ),
              Text(
                '${widget.dawState.activeTrackClip.barLength} BAR${widget.dawState.activeTrackClip.barLength > 1 ? 'S' : ''}',
                style: TextStyle(color: EatsTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 14),
                color: EatsTheme.accentGold,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                tooltip: 'Extend Clip Loop Length',
                onPressed: () {
                  final activeClip = widget.dawState.activeTrackClip;
                  if (activeClip.barLength < 16) {
                    widget.dawState.setTrackClipBarLength(activeClip, activeClip.barLength + 1);
                  }
                },
              ),
              const Spacer(),

              // Snap Quantize Dropdown
              Text('SNAP:', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 2),
              DropdownButton<double>(
                value: widget.dawState.quantizeSnap,
                dropdownColor: EatsTheme.panelBackground,
                underline: const SizedBox(),
                isDense: true,
                style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('1/32')),
                  DropdownMenuItem(value: 1.0, child: Text('1/16')),
                  DropdownMenuItem(value: 2.0, child: Text('1/8')),
                  DropdownMenuItem(value: 4.0, child: Text('1/4')),
                  DropdownMenuItem(value: 0.0, child: Text('Off')),
                ],
                onChanged: (val) {
                  if (val != null) widget.dawState.setQuantizeSnap(val);
                },
              ),
              const SizedBox(width: 8),

              // Zoom Controls
              Text('ZOOM:', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.zoom_out, size: 15),
                color: EatsTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Zoom Out',
                onPressed: () => _zoom(0.8),
              ),
              IconButton(
                icon: const Icon(Icons.aspect_ratio, size: 13),
                color: EatsTheme.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Reset Zoom',
                onPressed: _resetZoom,
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in, size: 15),
                color: EatsTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Zoom In',
                onPressed: () => _zoom(1.25),
              ),
            ],
          ),
        ),

        // Main Piano Roll Canvas & Keyboard
        Expanded(
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons == kMiddleMouseButton) {
                _isMiddleMouseDragging = true;
                setState(() {});
              }
            },
            onPointerMove: (event) {
              if (_isMiddleMouseDragging || (event.buttons & kMiddleMouseButton) != 0) {
                if (_horizontalScroll.hasClients) {
                  final targetX = (_horizontalScroll.offset - event.delta.dx)
                      .clamp(0.0, _horizontalScroll.position.maxScrollExtent);
                  _horizontalScroll.jumpTo(targetX);
                }
                if (_gridScrollController.hasClients) {
                  final targetY = (_gridScrollController.offset - event.delta.dy)
                      .clamp(0.0, _gridScrollController.position.maxScrollExtent);
                  _gridScrollController.jumpTo(targetY);
                  _syncKeysScroll();
                }
              }
            },
            onPointerUp: (event) {
              if (_isMiddleMouseDragging) {
                _isMiddleMouseDragging = false;
                setState(() {});
              }
            },
            onPointerCancel: (event) {
              if (_isMiddleMouseDragging) {
                _isMiddleMouseDragging = false;
                setState(() {});
              }
            },
            child: MouseRegion(
              cursor: _isMiddleMouseDragging ? SystemMouseCursors.allScroll : MouseCursor.defer,
              child: GestureDetector(
                onScaleStart: (details) {
                  _baseStepWidth = _stepWidth;
                  _baseKeyHeight = _keyHeight;
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount >= 2) {
                    // 2-Finger Pinch-to-Zoom
                    final oldWidth = _stepWidth;
                    final oldHeight = _keyHeight;

                    final newWidth = (_baseStepWidth * details.horizontalScale).clamp(12.0, 80.0);
                    final newHeight = (_baseKeyHeight * details.verticalScale).clamp(14.0, 48.0);

                    setState(() {
                      _stepWidth = newWidth;
                      _keyHeight = newHeight;
                    });

                    _adjustScrollForZoom(oldWidth, newWidth, oldHeight, newHeight);

                    // Handle focal point panning during 2-finger pinch
                    if (details.focalPointDelta != Offset.zero) {
                      if (_horizontalScroll.hasClients) {
                        final targetX = (_horizontalScroll.offset - details.focalPointDelta.dx)
                            .clamp(0.0, _horizontalScroll.position.maxScrollExtent);
                        _horizontalScroll.jumpTo(targetX);
                      }
                      if (_gridScrollController.hasClients) {
                        final targetY = (_gridScrollController.offset - details.focalPointDelta.dy)
                            .clamp(0.0, _gridScrollController.position.maxScrollExtent);
                        _gridScrollController.jumpTo(targetY);
                        _syncKeysScroll();
                      }
                    }
                  }
                },
                child: Row(
                  children: [
                    // Virtual Piano Keyboard Column (Left - Synced SingleChildScrollView layout)
                    RepaintBoundary(
                      child: SizedBox(
                        width: 70,
                        child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          controller: _keysScrollController,
                          scrollDirection: Axis.vertical,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            height: totalKeys * _keyHeight,
                            child: Column(
                              children: List.generate(totalKeys, (idx) {
                                final pitch = maxPitch - idx;
                                final isBlackKey = _isBlackKey(pitch);
                                final noteName = _getNoteName(pitch);
                                final isActive = _activeKeyboardPitches.containsKey(pitch);
                                final activeVel = _activeKeyboardPitches[pitch];

                                return Listener(
                                  onPointerDown: (e) => _handleKeyPointerDown(e, pitch, 70.0),
                                  onPointerMove: (e) => _handleKeyPointerMove(e, pitch, 70.0),
                                  onPointerUp: (_) => _handleKeyPointerUp(pitch),
                                  onPointerCancel: (_) => _handleKeyPointerUp(pitch),
                                  child: Container(
                                    height: _keyHeight,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Color.lerp(
                                              isBlackKey ? const Color(0xFF2A2E3D) : const Color(0xFFE2EAFA),
                                              track.color,
                                              0.5,
                                            )!
                                          : (isBlackKey ? const Color(0xFF1E222D) : const Color(0xFFDCDFE5)),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isBlackKey ? Colors.black45 : Colors.grey.shade400,
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Horizontal Velocity Fill Bar on active touch (no gradient)
                                        if (isActive && activeVel != null)
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            width: 70.0 * activeVel,
                                            child: Container(
                                              color: track.color.withOpacity(isBlackKey ? 0.85 : 0.75),
                                            ),
                                          ),
                                        Positioned.fill(
                                          right: 6,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              noteName,
                                              style: TextStyle(
                                                color: isActive
                                                    ? Colors.white
                                                    : (isBlackKey ? Colors.white70 : Colors.black87),
                                                fontSize: (_keyHeight * 0.38).clamp(8.0, 12.0),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ),

                // Note Grid Surface (Right, Synced Vertical Scroll)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalSteps * _stepWidth,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _syncKeysScroll();
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _gridScrollController,
                          scrollDirection: Axis.vertical,
                          child: GestureDetector(
                            onTap: () {
                              // Only deselect active note if tap was actually on empty canvas, not on a note
                              if (_lastNotePointerDownTime != null &&
                                  DateTime.now().difference(_lastNotePointerDownTime!) < const Duration(milliseconds: 350)) {
                                return;
                              }
                              // Single tap on grid deselects active note and hides Note Properties dialog
                              if (_selectedNoteId != null) {
                                setState(() {
                                  _selectedNoteId = null;
                                });
                              }
                            },
                            onDoubleTapDown: (details) {
                              final localPos = details.localPosition;
                              final int stepIdx = (localPos.dx / _stepWidth).floor();
                              final int keyIdx = (localPos.dy / _keyHeight).floor();
                              final int pitch = maxPitch - keyIdx;

                              if (stepIdx >= 0 && stepIdx < totalSteps && pitch >= minPitch && pitch <= maxPitch) {
                                double snappedStep = stepIdx.toDouble();
                                double duration = 1.0;
                                if (snap > 0) {
                                  snappedStep = (stepIdx / snap).floor() * snap;
                                  duration = snap;
                                }

                                final existingIndex = track.notes.indexWhere((n) =>
                                    n.pitch == pitch && n.startStep <= snappedStep && (n.startStep + n.durationSteps) > snappedStep);

                                if (existingIndex == -1) {
                                  final newNoteId = DateTime.now().millisecondsSinceEpoch.toString();
                                  final newNote = Note(
                                    id: newNoteId,
                                    pitch: pitch,
                                    startStep: snappedStep,
                                    durationSteps: duration,
                                    velocity: 0.85,
                                  );
                                  widget.dawState.addNote(track, newNote);
                                  setState(() {
                                    _selectedNoteId = newNoteId;
                                  });
                                  _ensureNoteAndMenuVisible(newNote);
                                }
                              }
                            },
                            child: Container(
                              height: totalKeys * _keyHeight,
                              color: EatsTheme.backgroundDark,
                              child: Stack(
                                children: [
                                  // High-Performance Background Grid Painter (Zero Widget Heap Allocation)
                                  CustomPaint(
                                    size: Size(totalSteps * _stepWidth, totalKeys * _keyHeight),
                                    painter: _PianoRollGridPainter(
                                      totalKeys: totalKeys,
                                      totalSteps: totalSteps,
                                      keyHeight: _keyHeight,
                                      stepWidth: _stepWidth,
                                      maxPitch: maxPitch,
                                      activeClipSteps: activeClipSteps,
                                      isLight: EatsTheme.isLight,
                                      cyanColor: EatsTheme.primaryCyan,
                                    ),
                                  ),

                              // Active Clip Loop End Line & Tag Badge
                              Positioned(
                                left: activeClipSteps * _stepWidth,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  color: EatsTheme.accentGold.withOpacity(0.85),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        top: 4,
                                        left: -38,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: EatsTheme.accentGold,
                                            borderRadius: BorderRadius.circular(3),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4),
                                            ],
                                          ),
                                          child: Text(
                                            'END OF CLIP',
                                            style: TextStyle(
                                              color: EatsTheme.backgroundDark,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Playhead Position Line
                              Positioned(
                                left: widget.dawState.currentStep * _stepWidth,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  color: EatsTheme.primaryCyan,
                                ),
                              ),

                              // Render Note Events Blocks
                              ...track.notes.map((note) {
                                final keyIdx = maxPitch - note.pitch;
                                if (keyIdx < 0 || keyIdx >= totalKeys) return const SizedBox();

                                final noteLeft = note.startStep * _stepWidth + 1;
                                final noteTop = keyIdx * _keyHeight + 1;
                                final noteWidth = ((note.durationSteps * _stepWidth) - 2).clamp(8.0, double.infinity);
                                final noteHeight = _keyHeight - 2;
                                final isSelected = note.id == _selectedNoteId;
                                final isPastClipLoop = note.startStep >= activeClipSteps;

                                final touchWidth = isMobile ? noteWidth.clamp(28.0, double.infinity) : noteWidth;
                                final touchHeight = isMobile ? noteHeight.clamp(28.0, double.infinity) : noteHeight;
                                final touchLeft = isMobile ? (noteLeft - (touchWidth - noteWidth) / 2).clamp(0.0, double.infinity) : noteLeft;
                                final touchTop = isMobile ? (noteTop - (touchHeight - noteHeight) / 2).clamp(0.0, double.infinity) : noteTop;

                                final rawVelocityColor = Color.lerp(
                                  const Color(0xFF0C0D12),
                                  track.color,
                                  (0.25 + 0.75 * note.velocity.clamp(0.05, 1.0)),
                                )!;
                                final effectiveNoteColor = isPastClipLoop
                                    ? rawVelocityColor.withOpacity(0.55)
                                    : rawVelocityColor;

                                  return Positioned(
                                    left: touchLeft,
                                    top: touchTop,
                                    width: touchWidth,
                                    height: touchHeight,
                                    child: Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerDown: (event) {
                                        if (event.buttons == kSecondaryMouseButton) return;
                                        _lastNotePointerDownTime = DateTime.now();
                                        final now = DateTime.now();
                                        if (_lastNoteTapId == note.id &&
                                            _lastNoteTapTime != null &&
                                            now.difference(_lastNoteTapTime!) < const Duration(milliseconds: 280)) {
                                          // Instant Double Tap -> Delete Note
                                          widget.dawState.removeNote(track, note.id);
                                          setState(() {
                                            if (_selectedNoteId == note.id) {
                                              _selectedNoteId = null;
                                            }
                                          });
                                          _lastNoteTapTime = null;
                                          _lastNoteTapId = null;
                                        } else {
                                          // Instant Single Tap (0ms latency, no gesture arena delay) -> Select Note
                                          _lastNoteTapTime = now;
                                          _lastNoteTapId = note.id;
                                          if (_selectedNoteId != note.id) {
                                            setState(() {
                                              _selectedNoteId = note.id;
                                            });
                                          }
                                        }
                                      },
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          // Absorb tap gesture to prevent grid onTap from deselecting note
                                        },
                                        onPanStart: (details) {
                                          _activeMoveNoteId = note.id;
                                          _moveStartStep = note.startStep;
                                          _moveStartPitch = note.pitch;
                                          _moveStartPos = details.globalPosition;
                                          if (_selectedNoteId != note.id) {
                                            setState(() => _selectedNoteId = note.id);
                                          }
                                        },
                                        onPanUpdate: (details) {
                                          if (_activeMoveNoteId != note.id ||
                                              _moveStartStep == null ||
                                              _moveStartPitch == null ||
                                              _moveStartPos == null) return;

                                          final dxSteps = (details.globalPosition.dx - _moveStartPos!.dx) / _stepWidth;
                                          final dyPitches = -((details.globalPosition.dy - _moveStartPos!.dy) / _keyHeight).round();

                                          double candidateStep = (_moveStartStep! + dxSteps).clamp(0.0, totalSteps - note.durationSteps);
                                          if (snap > 0) {
                                            candidateStep = (candidateStep / snap).round() * snap;
                                          }
                                          int candidatePitch = (_moveStartPitch! + dyPitches).clamp(minPitch, maxPitch);

                                          widget.dawState.updateNote(
                                            track,
                                            note.copyWith(startStep: candidateStep, pitch: candidatePitch),
                                          );
                                        },
                                        onPanEnd: (_) {
                                          if (_activeMoveNoteId == note.id) {
                                            _activeMoveNoteId = null;
                                            widget.dawState.audioEngine.playNoteOrSample(
                                              track: track,
                                              midiNote: note.pitch,
                                              velocity: note.velocity,
                                            );
                                            _ensureNoteAndMenuVisible(note);
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: effectiveNoteColor,
                                            borderRadius: BorderRadius.circular(4),
                                            border: isSelected
                                                ? Border.all(color: EatsTheme.primaryCyan, width: 2.0)
                                                : (isPastClipLoop
                                                    ? Border.all(color: EatsTheme.accentGold.withOpacity(0.5), width: 1.0)
                                                    : Border.all(color: Colors.black45, width: 0.5)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isSelected ? EatsTheme.primaryCyan.withOpacity(0.8) : effectiveNoteColor.withOpacity(0.4),
                                                blurRadius: isSelected ? 6 : 3,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getNoteName(note.pitch),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? EatsTheme.backgroundDark
                                                    : (note.velocity < 0.45 ? Colors.white70 : EatsTheme.backgroundDark),
                                                fontSize: (_keyHeight * 0.38).clamp(8.0, 11.0),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                  }),

                                  // Draw Dynamic "<>" Resize Handle directly after the selected note
                                  if (selectedNote != null &&
                                      selectedNoteLeft != null &&
                                      selectedNoteTop != null &&
                                      selectedNoteWidth != null &&
                                      selectedNoteHeight != null)
                                    Positioned(
                                      left: selectedNoteLeft + selectedNoteWidth + 1,
                                      top: selectedNoteTop,
                                      width: 22,
                                      height: selectedNoteHeight,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (details) {
                                          _activeResizeNoteId = selectedNote!.id;
                                          _resizeStartDuration = selectedNote.durationSteps;
                                          _resizeStartPos = details.globalPosition;
                                        },
                                        onPanUpdate: (details) {
                                          if (_activeResizeNoteId != selectedNote!.id ||
                                              _resizeStartDuration == null ||
                                              _resizeStartPos == null) return;

                                          final dxSteps = (details.globalPosition.dx - _resizeStartPos!.dx) / _stepWidth;
                                          final double minDur = snap > 0 ? snap : 0.25;
                                          double candidateDur = (_resizeStartDuration! + dxSteps).clamp(minDur, totalSteps - selectedNote.startStep);

                                          if (snap > 0) {
                                            candidateDur = (candidateDur / snap).round() * snap;
                                            if (candidateDur < snap) candidateDur = snap;
                                          }

                                          widget.dawState.updateNote(
                                            track,
                                            selectedNote.copyWith(durationSteps: candidateDur),
                                          );
                                        },
                                        onPanEnd: (_) {
                                          _activeResizeNoteId = null;
                                        },
                                        child: Tooltip(
                                          message: 'Drag to resize note',
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: EatsTheme.primaryCyan,
                                              borderRadius: const BorderRadius.only(
                                                topRight: Radius.circular(4),
                                                bottomRight: Radius.circular(4),
                                              ),
                                              boxShadow: [
                                                BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.6), blurRadius: 4),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                '<>',
                                                style: TextStyle(
                                                  color: EatsTheme.isLight ? Colors.white : Colors.black,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
),

        // Right-Hand Note Inspector Sidebar (Aligns to left of Project Browser if open)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 150),
          curve: Curves.fastOutSlowIn,
          top: 32,
          bottom: 0,
          right: selectedNote != null
              ? (widget.dawState.isBrowserOpen ? 320.0 : 0.0)
              : -290.0,
          width: 270,
          child: RepaintBoundary(
            child: selectedNote != null
                ? _buildNoteInspectorSidebar(track, selectedNote, snap)
                : const SizedBox(),
          ),
        ),
      ],
    );
  }
}

class _PianoRollGridPainter extends CustomPainter {
  final int totalKeys;
  final int totalSteps;
  final double keyHeight;
  final double stepWidth;
  final int maxPitch;
  final double activeClipSteps;
  final bool isLight;
  final Color cyanColor;

  _PianoRollGridPainter({
    required this.totalKeys,
    required this.totalSteps,
    required this.keyHeight,
    required this.stepWidth,
    required this.maxPitch,
    required this.activeClipSteps,
    required this.isLight,
    required this.cyanColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final blackKeyPaint = Paint()
      ..color = isLight ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    final rowBorderPaint = Paint()
      ..color = isLight ? Colors.black.withOpacity(0.12) : Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    final pastClipPaint = Paint()
      ..color = isLight ? Colors.black.withOpacity(0.06) : Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final stepBorderPaint = Paint()
      ..color = isLight ? Colors.black.withOpacity(0.12) : Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    final barHeaderPaint = Paint()
      ..color = cyanColor.withOpacity(0.45)
      ..strokeWidth = 1.5;

    final barHeaderPastClipPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5;

    // 1. Draw Row backgrounds & horizontal separators
    for (int idx = 0; idx < totalKeys; idx++) {
      final pitch = maxPitch - idx;
      final isBlack = _isBlackKey(pitch);
      final y = idx * keyHeight;

      if (isBlack) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, keyHeight), blackKeyPaint);
      }
      canvas.drawLine(Offset(0, y + keyHeight), Offset(size.width, y + keyHeight), rowBorderPaint);
    }

    // 2. Draw Past-Clip dim overlay
    final clipX = activeClipSteps * stepWidth;
    if (clipX < size.width) {
      canvas.drawRect(Rect.fromLTWH(clipX, 0, size.width - clipX, size.height), pastClipPaint);
    }

    // 3. Draw Vertical Step/Bar Lines
    for (int step = 0; step <= totalSteps; step++) {
      final x = step * stepWidth;
      final isBarHeader = step % 4 == 0;
      final isPastClip = step >= activeClipSteps;

      if (isBarHeader) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), isPastClip ? barHeaderPastClipPaint : barHeaderPaint);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), stepBorderPaint);
      }
    }
  }

  static bool _isBlackKey(int pitch) {
    final noteInOctave = pitch % 12;
    return noteInOctave == 1 || noteInOctave == 3 || noteInOctave == 6 || noteInOctave == 8 || noteInOctave == 10;
  }

  @override
  bool shouldRepaint(covariant _PianoRollGridPainter old) {
    return old.totalKeys != totalKeys ||
        old.totalSteps != totalSteps ||
        old.keyHeight != keyHeight ||
        old.stepWidth != stepWidth ||
        old.maxPitch != maxPitch ||
        old.activeClipSteps != activeClipSteps ||
        old.isLight != isLight ||
        old.cyanColor != cyanColor;
  }
}
