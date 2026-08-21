import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/services.dart';
import '../audio/easing.dart';
import '../models/automation_model.dart';
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
  final FocusNode _focusNode = FocusNode();

  bool _isSyncingScroll = false;
  Set<String> _selectedNoteIds = {};

  // Marquee Selection State
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;
  bool _isMarqueeSelecting = false;

  // Draggable Note Properties dialog state
  Offset? _notePropertiesOffset;
  String? _draggedNoteId;

  // Move tracking variables
  String? _activeMoveNoteId;
  double? _moveStartStep;
  int? _moveStartPitch;
  Offset? _moveStartPos;
  final Map<String, double> _batchStartSteps = {};
  final Map<String, int> _batchStartPitches = {};

  // Resize tracking variables
  String? _activeResizeNoteId;
  double? _resizeStartDuration;
  Offset? _resizeStartPos;
  final Map<String, double> _batchStartDurations = {};

  // Active keyboard pressed keys map (pitch -> velocity) for visual feedback
  final Map<int, double> _activeKeyboardPitches = {};
  bool _isMiddleMouseDragging = false;
  DateTime? _lastNoteTapTime;
  String? _lastNoteTapId;
  DateTime? _lastNotePointerDownTime;

  // Mouse instant drag-marquee tracking
  Offset? _mouseDragOrigin;
  bool _isMouseMarqueeCandidate = false;

  // Automation Lane Drawer State
  bool _isAutomationDrawerOpen = false;
  String? _activeAutomationLaneId;
  String? _draggedAutomationPointId;
  EasingType _selectedPointEasing = EasingType.linear;

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
    _focusNode.dispose();
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

  List<Note> _getSelectedNotes(TrackChannel track) {
    return track.notes.where((n) => _selectedNoteIds.contains(n.id)).toList();
  }

  Note? _getPrimarySelectedNote(TrackChannel track) {
    final selected = _getSelectedNotes(track);
    return selected.isNotEmpty ? selected.last : null;
  }

  void _selectNotesByPitch(TrackChannel track, int pitch) {
    final matching = track.notes.where((n) => n.pitch == pitch).map((n) => n.id).toSet();
    if (matching.isNotEmpty) {
      setState(() {
        if (HardwareKeyboard.instance.isShiftPressed) {
          _selectedNoteIds.addAll(matching);
        } else {
          _selectedNoteIds = matching;
        }
      });
      widget.dawState.audioEngine.playNoteOrSample(
        track: track,
        midiNote: pitch,
        velocity: 0.85,
      );
    }
  }

  void _selectAllNotes(TrackChannel track) {
    setState(() {
      _selectedNoteIds = track.notes.map((n) => n.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedNoteIds.clear();
    });
  }

  void _deleteSelectedNotes(TrackChannel track) {
    if (_selectedNoteIds.isEmpty) return;
    widget.dawState.removeNotes(track, _selectedNoteIds);
    setState(() {
      _selectedNoteIds.clear();
    });
  }

  void _updateSelectionFromMarquee(TrackChannel track, Rect marqueeRect) {
    final newSelected = <String>{};
    for (final n in track.notes) {
      final keyIdx = maxPitch - n.pitch;
      final noteLeft = n.startStep * _stepWidth + 1;
      final noteTop = keyIdx * _keyHeight + 1;
      final noteWidth = ((n.durationSteps * _stepWidth) - 2).clamp(8.0, double.infinity);
      final noteHeight = _keyHeight - 2;
      final noteRect = Rect.fromLTWH(noteLeft, noteTop, noteWidth, noteHeight);

      if (marqueeRect.overlaps(noteRect)) {
        newSelected.add(n.id);
      }
    }

    setState(() {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _selectedNoteIds.addAll(newSelected);
      } else {
        _selectedNoteIds = newSelected;
      }
    });
  }

  void _batchTransposeSelectedNotes(TrackChannel track, int semitones) {
    if (_selectedNoteIds.isEmpty || semitones == 0) return;
    final selected = _getSelectedNotes(track);
    if (selected.isEmpty) return;

    int minP = 127;
    int maxP = 0;
    for (final n in selected) {
      if (n.pitch < minP) minP = n.pitch;
      if (n.pitch > maxP) maxP = n.pitch;
    }
    int effSemitones = semitones;
    if (minP + effSemitones < minPitch) {
      effSemitones = minPitch - minP;
    } else if (maxP + effSemitones > maxPitch) {
      effSemitones = maxPitch - maxP;
    }
    if (effSemitones == 0) return;

    widget.dawState.transposeNotes(track, _selectedNoteIds, effSemitones);
    final samplePitch = (selected.first.pitch + effSemitones).clamp(minPitch, maxPitch);
    widget.dawState.audioEngine.playNoteOrSample(
      track: track,
      midiNote: samplePitch,
      velocity: selected.first.velocity,
    );
    setState(() {});
  }

  void _batchNudgeSelectedNotes(TrackChannel track, double deltaSteps) {
    if (_selectedNoteIds.isEmpty || deltaSteps == 0) return;
    final selected = _getSelectedNotes(track);
    if (selected.isEmpty) return;

    double minStep = double.infinity;
    double maxEndStep = 0.0;
    for (final n in selected) {
      if (n.startStep < minStep) minStep = n.startStep;
      if (n.startStep + n.durationSteps > maxEndStep) maxEndStep = n.startStep + n.durationSteps;
    }
    double effDelta = deltaSteps;
    if (minStep + effDelta < 0.0) {
      effDelta = -minStep;
    }
    if (maxEndStep + effDelta > totalSteps) {
      effDelta = totalSteps - maxEndStep;
    }
    if (effDelta == 0) return;

    widget.dawState.nudgeNotesPosition(track, _selectedNoteIds, effDelta);
    setState(() {});
  }

  void _batchChangeDurationSelectedNotes(TrackChannel track, double deltaSteps) {
    if (_selectedNoteIds.isEmpty || deltaSteps == 0) return;
    widget.dawState.changeNotesDuration(track, _selectedNoteIds, deltaSteps);
    setState(() {});
  }

  void _batchSetVelocitySelectedNotes(TrackChannel track, double velocity) {
    if (_selectedNoteIds.isEmpty) return;
    widget.dawState.setNotesVelocity(track, _selectedNoteIds, velocity);
    setState(() {});
  }

  void _batchHumanizeVelocitySelectedNotes(TrackChannel track) {
    if (_selectedNoteIds.isEmpty) return;
    final rand = math.Random();
    widget.dawState.beginHistoryTransaction('Humanize Velocities', icon: Icons.auto_fix_high);
    for (final n in track.notes) {
      if (_selectedNoteIds.contains(n.id)) {
        final delta = (rand.nextDouble() * 0.30) - 0.15; // ±15%
        n.velocity = (n.velocity + delta).clamp(0.10, 1.0);
      }
    }
    widget.dawState.commitHistoryTransaction();
    widget.dawState.notifyListeners();
    setState(() {});
  }

  void _batchQuantizeSelectedNotes(TrackChannel track, double snap) {
    if (_selectedNoteIds.isEmpty || snap <= 0) return;
    widget.dawState.beginHistoryTransaction('Quantize Notes', icon: Icons.grid_on);
    for (final n in track.notes) {
      if (_selectedNoteIds.contains(n.id)) {
        n.startStep = (n.startStep / snap).round() * snap;
      }
    }
    widget.dawState.commitHistoryTransaction();
    widget.dawState.notifyListeners();
    setState(() {});
  }

  void _selectPreviousNote(TrackChannel track) {
    if (track.notes.isEmpty) return;
    final sorted = List<Note>.from(track.notes)..sort((a, b) {
      final stepComp = a.startStep.compareTo(b.startStep);
      if (stepComp != 0) return stepComp;
      return a.pitch.compareTo(b.pitch);
    });

    final currentId = _selectedNoteIds.isNotEmpty ? _selectedNoteIds.last : null;
    int currIdx = sorted.indexWhere((n) => n.id == currentId);
    int targetIdx;
    if (currIdx <= 0) {
      targetIdx = sorted.length - 1;
    } else {
      targetIdx = currIdx - 1;
    }

    final note = sorted[targetIdx];
    setState(() {
      _selectedNoteIds = {note.id};
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

    final currentId = _selectedNoteIds.isNotEmpty ? _selectedNoteIds.last : null;
    int currIdx = sorted.indexWhere((n) => n.id == currentId);
    int targetIdx;
    if (currIdx == -1 || currIdx >= sorted.length - 1) {
      targetIdx = 0;
    } else {
      targetIdx = currIdx + 1;
    }

    final note = sorted[targetIdx];
    setState(() {
      _selectedNoteIds = {note.id};
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
          border: Border.all(color: EatsTheme.textMuted.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: EatsTheme.primaryCyan),
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
                      setState(() => _selectedNoteIds.remove(note.id));
                    },
                  ),
                  const SizedBox(width: 4),
                  // Close Button
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: EatsTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Close Inspector',
                    onPressed: () => setState(() => _selectedNoteIds.remove(note.id)),
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

  Widget _buildMultiNoteInspectorSidebar(TrackChannel track, List<Note> selectedNotes, double snap) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final nudgeStep = snap > 0 ? snap : 1.0;
    final count = selectedNotes.length;
    final avgVel = selectedNotes.map((n) => n.velocity).reduce((a, b) => a + b) / count;
    final velPercent = (avgVel * 100).round();

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
            // Header
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
                    'MULTI-NOTE INSPECTOR',
                    style: EatsTheme.getDisplayFontStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: EatsTheme.textLight,
                    ),
                  ),
                  const Spacer(),
                  // Delete All Selected Button
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Delete $count Selected Notes (Del)',
                    onPressed: () => _deleteSelectedNotes(track),
                  ),
                  const SizedBox(width: 4),
                  // Close Button
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: EatsTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Clear Selection (Esc)',
                    onPressed: _clearSelection,
                  ),
                ],
              ),
            ),

            // Summary Badge
            Container(
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
                  Text(
                    'Batch Mode',
                    style: TextStyle(
                      color: EatsTheme.textLight,
                      fontSize: 10,
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
                  _buildSidebarSectionHeader('BATCH PITCH TRANSPOSE'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCompactButton('-12', () => _batchTransposeSelectedNotes(track, -12), tooltip: '-1 Octave (All)'),
                      _buildCompactButton('-1', () => _batchTransposeSelectedNotes(track, -1), tooltip: '-1 Semitone (All)'),
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
                      _buildCompactButton('+1', () => _batchTransposeSelectedNotes(track, 1), tooltip: '+1 Semitone (All)'),
                      _buildCompactButton('+12', () => _batchTransposeSelectedNotes(track, 12), tooltip: '+1 Octave (All)'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 2: Position Nudge
                  _buildSidebarSectionHeader('BATCH POSITION NUDGE'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shift by ${nudgeStep.toStringAsFixed(snap > 0 && snap < 1 ? 2 : 0)} step(s)',
                        style: TextStyle(color: EatsTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCompactButton('-STEP', () => _batchNudgeSelectedNotes(track, -nudgeStep), tooltip: 'Nudge Left (All)'),
                          const SizedBox(width: 4),
                          _buildCompactButton('+STEP', () => _batchNudgeSelectedNotes(track, nudgeStep), tooltip: 'Nudge Right (All)'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 3: Duration / Length
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
                          _buildCompactButton('-LEN', () => _batchChangeDurationSelectedNotes(track, -nudgeStep), tooltip: 'Shorten (All)'),
                          const SizedBox(width: 4),
                          _buildCompactButton('+LEN', () => _batchChangeDurationSelectedNotes(track, nudgeStep), tooltip: 'Lengthen (All)'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 4: Velocity
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
                      onChanged: (val) => _batchSetVelocitySelectedNotes(track, val),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCompactButton('25%', () => _batchSetVelocitySelectedNotes(track, 0.25), tooltip: 'Soft (25%)'),
                      _buildCompactButton('50%', () => _batchSetVelocitySelectedNotes(track, 0.50), tooltip: 'Medium (50%)'),
                      _buildCompactButton('75%', () => _batchSetVelocitySelectedNotes(track, 0.75), tooltip: 'Strong (75%)'),
                      _buildCompactButton('100%', () => _batchSetVelocitySelectedNotes(track, 1.00), tooltip: 'Full (100%)'),
                      _buildCompactButton('Humanize', () => _batchHumanizeVelocitySelectedNotes(track), tooltip: 'Humanize (±15%)'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 5: Selection Utilities
                  _buildSidebarSectionHeader('SELECTION UTILITIES'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildActionButton(
                        icon: Icons.copy,
                        label: 'Copy Lua',
                        tooltip: 'Copy selected notes as Lua code (Ctrl+C)',
                        onTap: () => _copyNotes(track),
                      ),
                      _buildActionButton(
                        icon: Icons.cut,
                        label: 'Cut',
                        tooltip: 'Cut selected notes to clipboard (Ctrl+X)',
                        onTap: () => _cutNotes(track),
                      ),
                      _buildActionButton(
                        icon: Icons.paste,
                        label: 'Paste',
                        tooltip: 'Paste notes at playhead step (Ctrl+V)',
                        onTap: () => _pasteNotes(track, snap),
                      ),
                      _buildActionButton(
                        icon: Icons.select_all,
                        label: 'Select All',
                        tooltip: 'Select all notes in clip (Ctrl+A)',
                        onTap: () => _selectAllNotes(track),
                      ),
                      _buildActionButton(
                        icon: Icons.flip,
                        label: 'Invert',
                        tooltip: 'Invert note selection',
                        onTap: () {
                          setState(() {
                            final allIds = track.notes.map((n) => n.id).toSet();
                            _selectedNoteIds = allIds.difference(_selectedNoteIds);
                          });
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.grid_on,
                        label: 'Quantize Start',
                        tooltip: 'Snap note start times to grid',
                        onTap: () => _batchQuantizeSelectedNotes(track, snap),
                      ),
                      _buildActionButton(
                        icon: Icons.deselect,
                        label: 'Clear',
                        tooltip: 'Clear selection (Esc)',
                        onTap: _clearSelection,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyNotes(TrackChannel track) async {
    final lua = await widget.dawState.copyNotesToClipboard(track, _selectedNoteIds);
    if (!mounted) return;
    final count = _selectedNoteIds.isEmpty ? track.notes.length : _selectedNoteIds.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $count note${count != 1 ? 's' : ''} as Lua to clipboard'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cutNotes(TrackChannel track) async {
    if (_selectedNoteIds.isEmpty) return;
    final count = _selectedNoteIds.length;
    await widget.dawState.cutNotesToClipboard(track, _selectedNoteIds);
    if (!mounted) return;
    setState(() => _selectedNoteIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cut $count note${count != 1 ? 's' : ''} to clipboard'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pasteNotes(TrackChannel track, double snap) async {
    double targetStep = widget.dawState.currentStep.toDouble();
    if (snap > 0) {
      targetStep = (targetStep / snap).floor() * snap;
    }
    final pasted = await widget.dawState.pasteNotesFromClipboard(track, targetStep: targetStep);
    if (!mounted) return;
    if (pasted.isNotEmpty) {
      setState(() {
        _selectedNoteIds = pasted.map((n) => n.id).toSet();
      });
      _ensureNoteAndMenuVisible(pasted.first);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pasted ${pasted.length} note${pasted.length != 1 ? 's' : ''} at Step ${targetStep.toStringAsFixed(1)}'),
          backgroundColor: EatsTheme.panelHeader,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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

  KeyEventResult _handlePianoRollKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final track = widget.dawState.activeTrack;
    final snap = widget.dawState.quantizeSnap;
    final key = event.logicalKey;
    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    // Ctrl+A / Cmd+A -> Select All Notes
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyA) {
      _selectAllNotes(track);
      return KeyEventResult.handled;
    }

    // Ctrl+C / Cmd+C -> Copy Notes as Lua
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyC) {
      _copyNotes(track);
      return KeyEventResult.handled;
    }

    // Ctrl+X / Cmd+X -> Cut Notes
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyX) {
      if (_selectedNoteIds.isNotEmpty) {
        _cutNotes(track);
        return KeyEventResult.handled;
      }
    }

    // Ctrl+V / Cmd+V -> Paste Notes at playhead
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyV) {
      _pasteNotes(track, snap);
      return KeyEventResult.handled;
    }

    // Escape -> Deselect All
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedNoteIds.isNotEmpty) {
        _clearSelection();
        return KeyEventResult.handled;
      }
    }

    // Delete / Backspace -> Delete Selected Notes
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (_selectedNoteIds.isNotEmpty) {
        _deleteSelectedNotes(track);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.dawState.activeTrack;
    final activeClip = widget.dawState.activeTrackClip;
    final activeClipSteps = (activeClip.barLength * 4.0).clamp(4.0, 64.0);
    final snap = widget.dawState.quantizeSnap;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Find selected note objects
    final selectedNotes = _getSelectedNotes(track);
    final primarySelectedNote = selectedNotes.isNotEmpty ? selectedNotes.last : null;
    double? selectedNoteLeft;
    double? selectedNoteTop;
    double? selectedNoteWidth;
    double? selectedNoteHeight;

    if (primarySelectedNote != null) {
      final keyIdx = maxPitch - primarySelectedNote.pitch;
      selectedNoteLeft = primarySelectedNote.startStep * _stepWidth + 1;
      selectedNoteTop = keyIdx * _keyHeight + 1;
      selectedNoteWidth = ((primarySelectedNote.durationSteps * _stepWidth) - 2).clamp(8.0, double.infinity);
      selectedNoteHeight = _keyHeight - 2;
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handlePianoRollKeyEvent,
      child: Stack(
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

                IconButton(
                  icon: const Icon(Icons.center_focus_strong, size: 14),
                  color: EatsTheme.primaryCyan,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Center View vertically on Clip Notes (or C4)',
                  onPressed: () => _centerViewOnNotesOrDefault(animate: true),
                ),

                if (track.midiFXRack.any((fx) => fx.enabled)) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      widget.dawState.bakeMidiFXToClip(track, activeClip);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Baked MIDI FX to Clip "${activeClip.name}"'),
                          backgroundColor: EatsTheme.panelHeader,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: EatsTheme.panelHeader,
                      foregroundColor: EatsTheme.accentGold,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      side: BorderSide(color: EatsTheme.accentGold.withOpacity(0.6)),
                    ),
                    icon: const Icon(Icons.auto_fix_high, size: 13),
                    label: const Text('BAKE MIDI FX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],

                const SizedBox(width: 8),

                // Clipboard Actions (Copy / Cut / Paste)
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  color: EatsTheme.primaryCyan,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: _selectedNoteIds.isNotEmpty
                      ? 'Copy ${_selectedNoteIds.length} Selected Note(s) as Lua (Ctrl+C)'
                      : 'Copy All Clip Notes as Lua (Ctrl+C)',
                  onPressed: () => _copyNotes(track),
                ),
                if (_selectedNoteIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.cut, size: 14),
                    color: EatsTheme.accentGold,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Cut ${_selectedNoteIds.length} Selected Note(s) (Ctrl+X)',
                    onPressed: () => _cutNotes(track),
                  ),
                IconButton(
                  icon: const Icon(Icons.paste, size: 14),
                  color: EatsTheme.accentGreen,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Paste Note(s) at Playhead Step (Ctrl+V)',
                  onPressed: () => _pasteNotes(track, snap),
                ),

                const SizedBox(width: 8),

                // Automation Drawer Toggle Button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAutomationDrawerOpen = !_isAutomationDrawerOpen;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: _isAutomationDrawerOpen
                        ? EatsTheme.primaryCyan.withOpacity(0.2)
                        : EatsTheme.controlBackground,
                    foregroundColor: _isAutomationDrawerOpen
                        ? EatsTheme.primaryCyan
                        : EatsTheme.textLight,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: BorderSide(
                      color: _isAutomationDrawerOpen
                          ? EatsTheme.primaryCyan
                          : EatsTheme.textMuted.withOpacity(0.3),
                    ),
                  ),
                  icon: Icon(
                    Icons.show_chart,
                    size: 13,
                    color: _isAutomationDrawerOpen
                        ? EatsTheme.primaryCyan
                        : EatsTheme.textMuted,
                  ),
                  label: const Text(
                    'AUTOMATION',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
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
                                    child: GestureDetector(
                                      onLongPress: () => _selectNotesByPitch(track, pitch),
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
                            child: Listener(
                              onPointerDown: (event) {
                                if (event.kind == PointerDeviceKind.mouse && (event.buttons & kPrimaryMouseButton) != 0) {
                                  _focusNode.requestFocus();
                                  _mouseDragOrigin = event.localPosition;
                                  _isMouseMarqueeCandidate = true;
                                }
                              },
                              onPointerMove: (event) {
                                if (_isMouseMarqueeCandidate &&
                                    _mouseDragOrigin != null &&
                                    _activeMoveNoteId == null &&
                                    _activeResizeNoteId == null &&
                                    (event.buttons & kPrimaryMouseButton) != 0) {
                                  final delta = (event.localPosition - _mouseDragOrigin!).distance;
                                  if (!_isMarqueeSelecting && delta > 4.0) {
                                    _isMarqueeSelecting = true;
                                    _marqueeStart = _mouseDragOrigin;
                                    _marqueeCurrent = event.localPosition;
                                    setState(() {});
                                  }
                                  if (_isMarqueeSelecting) {
                                    setState(() {
                                      _marqueeCurrent = event.localPosition;
                                    });
                                    final marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeCurrent!);
                                    _updateSelectionFromMarquee(track, marqueeRect);
                                  }
                                }
                              },
                              onPointerUp: (event) {
                                if (_isMouseMarqueeCandidate) {
                                  if (_isMarqueeSelecting) {
                                    setState(() {
                                      _isMarqueeSelecting = false;
                                      _marqueeStart = null;
                                      _marqueeCurrent = null;
                                    });
                                  }
                                  _mouseDragOrigin = null;
                                  _isMouseMarqueeCandidate = false;
                                }
                              },
                              onPointerCancel: (event) {
                                if (_isMouseMarqueeCandidate) {
                                  if (_isMarqueeSelecting) {
                                    setState(() {
                                      _isMarqueeSelecting = false;
                                      _marqueeStart = null;
                                      _marqueeCurrent = null;
                                    });
                                  }
                                  _mouseDragOrigin = null;
                                  _isMouseMarqueeCandidate = false;
                                }
                              },
                              child: GestureDetector(
                                onTap: () {
                                  _focusNode.requestFocus();
                                  // Only deselect active notes if tap was actually on empty canvas, not on a note
                                  if (_lastNotePointerDownTime != null &&
                                      DateTime.now().difference(_lastNotePointerDownTime!) < const Duration(milliseconds: 350)) {
                                    return;
                                  }
                                  // Single tap on grid deselects active notes
                                  if (_selectedNoteIds.isNotEmpty) {
                                    setState(() {
                                      _selectedNoteIds.clear();
                                    });
                                  }
                                },
                                // Touch Long-Press Drag Marquee for Mobile/Tablet Touchscreens
                                onLongPressStart: (details) {
                                  _focusNode.requestFocus();
                                  final pos = details.localPosition;
                                  setState(() {
                                    _marqueeStart = pos;
                                    _marqueeCurrent = pos;
                                    _isMarqueeSelecting = true;
                                  });
                                },
                                onLongPressMoveUpdate: (details) {
                                  if (!_isMarqueeSelecting || _marqueeStart == null) return;
                                  final pos = details.localPosition;
                                  setState(() {
                                    _marqueeCurrent = pos;
                                  });
                                  final marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeCurrent!);
                                  _updateSelectionFromMarquee(track, marqueeRect);
                                },
                                onLongPressEnd: (_) {
                                  setState(() {
                                    _isMarqueeSelecting = false;
                                    _marqueeStart = null;
                                    _marqueeCurrent = null;
                                  });
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
                                      _selectedNoteIds = {newNoteId};
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

                                // Render Real-Time MIDI FX Ghost / Arpeggiator Notes Layer
                                if (track.midiFXRack.any((fx) => fx.enabled))
                                  ...widget.dawState.getEvaluatedClipNotes(activeClip, track)
                                      .where((gn) => !track.notes.any((bn) => bn.id == gn.id))
                                      .map((ghostNote) {
                                    final keyIdx = maxPitch - ghostNote.pitch;
                                    if (keyIdx < 0 || keyIdx >= totalKeys) return const SizedBox();

                                    final noteLeft = ghostNote.startStep * _stepWidth + 1;
                                    final noteTop = keyIdx * _keyHeight + 1;
                                    final noteWidth = ((ghostNote.durationSteps * _stepWidth) - 2).clamp(4.0, double.infinity);
                                    final noteHeight = _keyHeight - 2;

                                    return Positioned(
                                      left: noteLeft,
                                      top: noteTop,
                                      width: noteWidth,
                                      height: noteHeight,
                                      child: IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: EatsTheme.primaryCyan.withOpacity(0.20),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(
                                              color: EatsTheme.primaryCyan.withOpacity(0.65),
                                              width: 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: EatsTheme.primaryCyan.withOpacity(0.2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getNoteName(ghostNote.pitch),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: EatsTheme.primaryCyan,
                                                fontSize: (_keyHeight * 0.32).clamp(7.0, 9.5),
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                // Render Note Events Blocks
                                ...track.notes.map((note) {
                                  final keyIdx = maxPitch - note.pitch;
                                  if (keyIdx < 0 || keyIdx >= totalKeys) return const SizedBox();

                                  final noteLeft = note.startStep * _stepWidth + 1;
                                  final noteTop = keyIdx * _keyHeight + 1;
                                  final noteWidth = ((note.durationSteps * _stepWidth) - 2).clamp(8.0, double.infinity);
                                  final noteHeight = _keyHeight - 2;
                                  final isSelected = _selectedNoteIds.contains(note.id);
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
                                          _isMouseMarqueeCandidate = false;
                                          _mouseDragOrigin = null;
                                          _focusNode.requestFocus();
                                          if (event.buttons == kSecondaryMouseButton) return;
                                          _lastNotePointerDownTime = DateTime.now();
                                          final now = DateTime.now();
                                          if (_lastNoteTapId == note.id &&
                                              _lastNoteTapTime != null &&
                                              now.difference(_lastNoteTapTime!) < const Duration(milliseconds: 280)) {
                                            // Instant Double Tap -> Delete Note (or delete all selected)
                                            if (_selectedNoteIds.contains(note.id) && _selectedNoteIds.length > 1) {
                                              _deleteSelectedNotes(track);
                                            } else {
                                              widget.dawState.removeNote(track, note.id);
                                              setState(() => _selectedNoteIds.remove(note.id));
                                            }
                                            _lastNoteTapTime = null;
                                            _lastNoteTapId = null;
                                          } else {
                                            // Instant Single Tap -> Select / Toggle Note
                                            _lastNoteTapTime = now;
                                            _lastNoteTapId = note.id;
                                            if (HardwareKeyboard.instance.isShiftPressed) {
                                              setState(() {
                                                if (_selectedNoteIds.contains(note.id)) {
                                                  _selectedNoteIds.remove(note.id);
                                                } else {
                                                  _selectedNoteIds.add(note.id);
                                                }
                                              });
                                            } else if (!_selectedNoteIds.contains(note.id)) {
                                              setState(() {
                                                _selectedNoteIds = {note.id};
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
                                            if (!_selectedNoteIds.contains(note.id)) {
                                              if (HardwareKeyboard.instance.isShiftPressed) {
                                                _selectedNoteIds.add(note.id);
                                              } else {
                                                _selectedNoteIds = {note.id};
                                              }
                                            }
                                            _activeMoveNoteId = note.id;
                                            _moveStartPos = details.globalPosition;
                                            _batchStartSteps.clear();
                                            _batchStartPitches.clear();
                                            for (final n in track.notes) {
                                              if (_selectedNoteIds.contains(n.id)) {
                                                _batchStartSteps[n.id] = n.startStep;
                                                _batchStartPitches[n.id] = n.pitch;
                                              }
                                            }
                                            widget.dawState.beginHistoryTransaction(
                                              _selectedNoteIds.length > 1
                                                  ? 'Move ${_selectedNoteIds.length} Notes'
                                                  : 'Move Note ${_getNoteName(note.pitch)}',
                                              icon: Icons.open_with,
                                            );
                                            setState(() {});
                                          },
                                          onPanUpdate: (details) {
                                            if (_activeMoveNoteId == null ||
                                                _moveStartPos == null ||
                                                _batchStartSteps.isEmpty) return;

                                            final dxSteps = (details.globalPosition.dx - _moveStartPos!.dx) / _stepWidth;
                                            final dyPitches = -((details.globalPosition.dy - _moveStartPos!.dy) / _keyHeight).round();

                                            // Calculate boundary limits across all moving notes
                                            double minAllowedDx = -double.infinity;
                                            double maxAllowedDx = double.infinity;
                                            int minAllowedDy = -999;
                                            int maxAllowedDy = 999;

                                            for (final entry in _batchStartSteps.entries) {
                                              final startS = entry.value;
                                              final dur = track.notes.firstWhere((n) => n.id == entry.key, orElse: () => note).durationSteps;
                                              final minDx = -startS;
                                              final maxDx = (totalSteps - dur) - startS;
                                              if (minDx > minAllowedDx) minAllowedDx = minDx;
                                              if (maxDx < maxAllowedDx) maxAllowedDx = maxDx;
                                            }
                                            for (final entry in _batchStartPitches.entries) {
                                              final startP = entry.value;
                                              final minDy = minPitch - startP;
                                              final maxDy = maxPitch - startP;
                                              if (minDy > minAllowedDy) minAllowedDy = minDy;
                                              if (maxDy < maxAllowedDy) maxAllowedDy = maxDy;
                                            }

                                            double candidateDx = dxSteps.clamp(minAllowedDx, maxAllowedDx);
                                            if (snap > 0) {
                                              candidateDx = (candidateDx / snap).round() * snap;
                                              candidateDx = candidateDx.clamp(minAllowedDx, maxAllowedDx);
                                            }
                                            int candidateDy = dyPitches.clamp(minAllowedDy, maxAllowedDy);

                                            for (final n in track.notes) {
                                              if (_selectedNoteIds.contains(n.id) && _batchStartSteps.containsKey(n.id)) {
                                                final baseStep = _batchStartSteps[n.id]!;
                                                final basePitch = _batchStartPitches[n.id]!;
                                                n.startStep = (baseStep + candidateDx).clamp(0.0, totalSteps - n.durationSteps);
                                                n.pitch = (basePitch + candidateDy).clamp(minPitch, maxPitch);
                                              }
                                            }
                                            widget.dawState.notifyListeners();
                                            setState(() {});
                                          },
                                          onPanEnd: (_) {
                                            if (_activeMoveNoteId != null) {
                                              _activeMoveNoteId = null;
                                              _moveStartPos = null;
                                              _batchStartSteps.clear();
                                              _batchStartPitches.clear();
                                              widget.dawState.commitHistoryTransaction();
                                              widget.dawState.audioEngine.playNoteOrSample(
                                                track: track,
                                                midiNote: note.pitch,
                                                velocity: note.velocity,
                                              );
                                              _ensureNoteAndMenuVisible(note);
                                            }
                                          },
                                          onPanCancel: () {
                                            _activeMoveNoteId = null;
                                            _moveStartPos = null;
                                            _batchStartSteps.clear();
                                            _batchStartPitches.clear();
                                            widget.dawState.commitHistoryTransaction();
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

                                    // Draw Dynamic "<>" Resize Handles for selected notes (supporting single and multi-selection)
                                    ...selectedNotes.map((sNote) {
                                      final keyIdx = maxPitch - sNote.pitch;
                                      if (keyIdx < 0 || keyIdx >= totalKeys) return const SizedBox();
                                      final sLeft = sNote.startStep * _stepWidth + 1;
                                      final sTop = keyIdx * _keyHeight + 1;
                                      final sWidth = ((sNote.durationSteps * _stepWidth) - 2).clamp(8.0, double.infinity);
                                      final sHeight = _keyHeight - 2;

                                      return Positioned(
                                        left: sLeft + sWidth + 1,
                                        top: sTop,
                                        width: 22,
                                        height: sHeight,
                                        child: Listener(
                                          behavior: HitTestBehavior.opaque,
                                          onPointerDown: (event) {
                                            _isMouseMarqueeCandidate = false;
                                            _mouseDragOrigin = null;
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (details) {
                                              _isMouseMarqueeCandidate = false;
                                              _mouseDragOrigin = null;
                                              _activeResizeNoteId = sNote.id;
                                              _resizeStartDuration = sNote.durationSteps;
                                              _resizeStartPos = details.globalPosition;
                                              _batchStartDurations.clear();
                                              for (final n in selectedNotes) {
                                                _batchStartDurations[n.id] = n.durationSteps;
                                              }
                                              widget.dawState.beginHistoryTransaction(
                                                selectedNotes.length > 1
                                                    ? 'Resize ${selectedNotes.length} Notes'
                                                    : 'Resize Note',
                                                icon: Icons.straighten,
                                              );
                                            },
                                            onPanUpdate: (details) {
                                              if (_activeResizeNoteId == null ||
                                                  _resizeStartPos == null ||
                                                  _batchStartDurations.isEmpty) return;

                                              final dxSteps = (details.globalPosition.dx - _resizeStartPos!.dx) / _stepWidth;
                                              final double minDur = snap > 0 ? snap : 0.25;

                                              for (final n in track.notes) {
                                                if (_batchStartDurations.containsKey(n.id)) {
                                                  final baseDur = _batchStartDurations[n.id]!;
                                                  double candidateDur = (baseDur + dxSteps).clamp(minDur, totalSteps - n.startStep);
                                                  if (snap > 0) {
                                                    candidateDur = (candidateDur / snap).round() * snap;
                                                    if (candidateDur < snap) candidateDur = snap;
                                                  }
                                                  n.durationSteps = candidateDur;
                                                }
                                              }
                                              widget.dawState.notifyListeners();
                                              setState(() {});
                                            },
                                            onPanEnd: (_) {
                                              _activeResizeNoteId = null;
                                              _batchStartDurations.clear();
                                              widget.dawState.commitHistoryTransaction();
                                            },
                                            onPanCancel: () {
                                              _activeResizeNoteId = null;
                                              _batchStartDurations.clear();
                                              widget.dawState.commitHistoryTransaction();
                                            },
                                            child: Tooltip(
                                              message: selectedNotes.length > 1
                                                  ? 'Drag to resize ${selectedNotes.length} selected notes'
                                                  : 'Drag to resize note',
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
                                      );
                                    }),

                                    // Marquee Box Selection Overlay
                                    if (_isMarqueeSelecting && _marqueeStart != null && _marqueeCurrent != null)
                                      Positioned.fromRect(
                                        rect: Rect.fromPoints(_marqueeStart!, _marqueeCurrent!),
                                        child: IgnorePointer(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: EatsTheme.primaryCyan.withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.85), width: 1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: EatsTheme.primaryCyan.withOpacity(0.3),
                                                  blurRadius: 8,
                                                ),
                                              ],
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
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    if (_isAutomationDrawerOpen) _buildAutomationDrawer(track),
  ],
),
),

          // Right-Hand Note Inspector Sidebar (Aligns to left of Project Browser if open)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.fastOutSlowIn,
            top: 32,
            bottom: 0,
            right: selectedNotes.isNotEmpty
                ? (widget.dawState.isBrowserOpen ? 320.0 : 0.0)
                : -290.0,
            width: 270,
            child: RepaintBoundary(
              child: selectedNotes.isEmpty
                  ? const SizedBox()
                  : (selectedNotes.length == 1
                      ? _buildNoteInspectorSidebar(track, selectedNotes.first, snap)
                      : _buildMultiNoteInspectorSidebar(track, selectedNotes, snap)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationDrawer(TrackChannel track) {
    if (track.automationLanes.isEmpty) {
      track.automationLanes.add(AutomationLane(
        id: 'auto_vol_${track.id}',
        name: '${track.name} Volume',
        target: AutomationTarget.volume,
        points: [
          AutomationPoint(id: 'p0', step: 0.0, value: track.volume, easing: EasingType.linear),
          AutomationPoint(id: 'p1', step: 16.0, value: track.volume, easing: EasingType.linear),
        ],
      ));
    }

    final activeLane = track.automationLanes.firstWhere(
      (l) => l.id == _activeAutomationLaneId,
      orElse: () => track.automationLanes.first,
    );
    _activeAutomationLaneId = activeLane.id;

    final target = activeLane.target;
    final totalWidth = totalSteps * _stepWidth;
    const drawerHeight = 130.0;

    return Container(
      height: drawerHeight,
      decoration: BoxDecoration(
        color: EatsTheme.panelBackground,
        border: Border(
          top: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.4), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          // Left Controls (70px wide)
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: EatsTheme.panelHeader,
              border: Border(
                right: BorderSide(color: EatsTheme.panelBackground, width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Lane Target Selector
                PopupMenuButton<AutomationTarget>(
                  tooltip: 'Select or Add Parameter Lane',
                  color: EatsTheme.panelBackground,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                    decoration: BoxDecoration(
                      color: EatsTheme.controlBackground,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: EatsTheme.textMuted.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          target.name.toUpperCase(),
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 8, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${target.min.toInt()}..${target.max.toInt()}${target.unit}',
                          style: TextStyle(color: EatsTheme.textMuted, fontSize: 7),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (ctx) {
                    final items = <PopupMenuEntry<AutomationTarget>>[];
                    for (final lane in track.automationLanes) {
                      items.add(PopupMenuItem(
                        value: lane.target,
                        child: Text(lane.name, style: TextStyle(color: lane.id == activeLane.id ? EatsTheme.primaryCyan : EatsTheme.textLight, fontSize: 11)),
                      ));
                    }
                    items.add(const PopupMenuDivider());
                    items.add(PopupMenuItem(
                      value: AutomationTarget.cutoff,
                      child: Text('+ Filter Cutoff', style: TextStyle(color: EatsTheme.accentGold, fontSize: 11)),
                    ));
                    items.add(PopupMenuItem(
                      value: AutomationTarget.pan,
                      child: Text('+ Pan', style: TextStyle(color: EatsTheme.accentGold, fontSize: 11)),
                    ));
                    items.add(PopupMenuItem(
                      value: AutomationTarget.custom(id: 'ym2612.algorithm', name: 'YM2612 Alg (0..7)', min: 0.0, max: 7.0, defaultValue: 4.0, isDiscrete: true),
                      child: Text('+ YM2612 Algorithm', style: TextStyle(color: EatsTheme.accentGold, fontSize: 11)),
                    ));
                    items.add(PopupMenuItem(
                      value: AutomationTarget.custom(id: 'ym2612.feedback', name: 'YM2612 Feedback', min: 0.0, max: 7.0, defaultValue: 5.0, isDiscrete: true),
                      child: Text('+ YM2612 Feedback', style: TextStyle(color: EatsTheme.accentGold, fontSize: 11)),
                    ));
                    return items;
                  },
                  onSelected: (selectedTarget) {
                    final existing = track.automationLanes.where((l) => l.target.id == selectedTarget.id);
                    if (existing.isNotEmpty) {
                      setState(() => _activeAutomationLaneId = existing.first.id);
                    } else {
                      widget.dawState.addTrackAutomationLane(track, selectedTarget);
                      setState(() => _activeAutomationLaneId = track.automationLanes.last.id);
                    }
                  },
                ),
                const SizedBox(height: 3),

                // Easing dropdown
                DropdownButton<EasingType>(
                  value: _selectedPointEasing,
                  dropdownColor: EatsTheme.panelBackground,
                  underline: const SizedBox(),
                  isDense: true,
                  style: TextStyle(color: EatsTheme.accentGold, fontSize: 8, fontWeight: FontWeight.bold),
                  items: EasingType.values.map((e) {
                    return DropdownMenuItem(
                      value: e,
                      child: Text(e.displayName, style: const TextStyle(fontSize: 10)),
                    );
                  }).toList(),
                  onChanged: (e) {
                    if (e != null) {
                      setState(() => _selectedPointEasing = e);
                    }
                  },
                ),
                const Spacer(),

                // Lua Script Button
                InkWell(
                  onTap: () => _showLuaAutomationScriptModal(activeLane),
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: activeLane.isCustomLua ? EatsTheme.accentGreen.withOpacity(0.25) : EatsTheme.controlBackground,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: activeLane.isCustomLua ? EatsTheme.accentGreen : EatsTheme.textMuted.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code, size: 9, color: activeLane.isCustomLua ? EatsTheme.accentGreen : EatsTheme.textLight),
                        const SizedBox(width: 2),
                        Text(
                          activeLane.isCustomLua ? 'LUA FX' : 'LUA',
                          style: TextStyle(
                            color: activeLane.isCustomLua ? EatsTheme.accentGreen : EatsTheme.textLight,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Graph Canvas (Horizontally scrollable with _horizontalScroll)
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: GestureDetector(
                onTapDown: (details) {
                  final step = (details.localPosition.dx / _stepWidth).clamp(0.0, totalSteps.toDouble());
                  final normY = (1.0 - (details.localPosition.dy / (drawerHeight - 16)).clamp(0.0, 1.0));
                  final val = target.min + (target.max - target.min) * normY;
                  final snappedStep = widget.dawState.quantizeSnap > 0
                      ? (step / widget.dawState.quantizeSnap).round() * widget.dawState.quantizeSnap
                      : (step * 2).round() / 2.0;

                  widget.dawState.setAutomationPoint(
                    activeLane,
                    snappedStep,
                    target.isDiscrete ? val.roundToDouble() : val,
                    easing: target.isDiscrete ? EasingType.step : _selectedPointEasing,
                  );
                },
                child: SizedBox(
                  width: totalWidth,
                  height: drawerHeight,
                  child: CustomPaint(
                    painter: _AutomationLanePainter(
                      lane: activeLane,
                      stepWidth: _stepWidth,
                      totalSteps: totalSteps,
                      currentStep: widget.dawState.currentStep.toDouble(),
                      color: track.color,
                      isLight: EatsTheme.isLight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLuaAutomationScriptModal(AutomationLane lane) {
    final controller = TextEditingController(
      text: lane.luaScriptCode.isNotEmpty ? lane.luaScriptCode : lane.generateLuaScript(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EatsTheme.panelBackground,
        title: Row(
          children: [
            Icon(Icons.code, color: EatsTheme.primaryCyan, size: 18),
            const SizedBox(width: 8),
            Text(
              'Lua Automation: ${lane.name}',
              style: TextStyle(color: EatsTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit the Lua script to define custom mathematical LFOs, procedural sweeps, or envelope expressions.',
                style: TextStyle(color: EatsTheme.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EatsTheme.backgroundDark,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EatsTheme.panelHeader),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.text = lane.generateLuaScript();
            },
            child: Text('Regenerate from Points', style: TextStyle(color: EatsTheme.accentGold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: EatsTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.dawState.setAutomationScript(lane, controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: EatsTheme.primaryCyan),
            child: const Text('Apply Script', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AutomationLanePainter extends CustomPainter {
  final AutomationLane lane;
  final double stepWidth;
  final int totalSteps;
  final double currentStep;
  final Color color;
  final bool isLight;

  _AutomationLanePainter({
    required this.lane,
    required this.stepWidth,
    required this.totalSteps,
    required this.currentStep,
    required this.color,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isLight ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    final barPaint = Paint()
      ..color = isLight ? Colors.black.withOpacity(0.18) : EatsTheme.primaryCyan.withOpacity(0.3)
      ..strokeWidth = 1.5;

    // 1. Draw Grid Lines
    for (int s = 0; s <= totalSteps; s++) {
      final x = s * stepWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), s % 4 == 0 ? barPaint : gridPaint);
    }

    // 2. Sample curve path across width
    final path = Path();
    final fillPath = Path();
    final target = lane.target;
    final minVal = target.min;
    final maxVal = target.max;
    final valRange = math.max(0.0001, maxVal - minVal);

    bool isFirst = true;
    for (double x = 0; x <= size.width; x += 4.0) {
      final step = x / stepWidth;
      final val = lane.evaluateAtStep(step);
      final normY = ((val - minVal) / valRange).clamp(0.0, 1.0);
      final y = size.height - (normY * (size.height - 16.0)) - 8.0;

      if (isFirst) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw curve fill & line
    final fillPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // 3. Draw Breakpoint Handles
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final pt in lane.points) {
      final x = pt.step * stepWidth;
      final normY = ((pt.value - minVal) / valRange).clamp(0.0, 1.0);
      final y = size.height - (normY * (size.height - 16.0)) - 8.0;

      canvas.drawCircle(Offset(x, y), 5.0, pointPaint);
      canvas.drawCircle(Offset(x, y), 5.0, pointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AutomationLanePainter old) => true;
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
