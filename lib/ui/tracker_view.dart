import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/eatsbeats_slider.dart';

class TrackerView extends StatefulWidget {
  final DawState dawState;

  const TrackerView({super.key, required this.dawState});

  @override
  State<TrackerView> createState() => _TrackerViewState();
}

class _TrackerViewState extends State<TrackerView> {
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  int _qwertyBaseOctave = 4; // Default C4 = 60

  DateTime? _lastTapTime;
  String? _lastTapCellKey;
  bool _followPlayback = true;
  int _lastFollowStep = -1;

  // 2D Matrix Block Selection State
  int? _selectionAnchorStep;
  int? _selectionAnchorCol;
  int? _selectionCurrentStep;
  int? _selectionCurrentCol;
  Offset? _longPressStartGlobalPos;
  bool _isMouseDown = false;

  bool get _hasBlockSelection =>
      _selectionAnchorStep != null &&
      _selectionAnchorCol != null &&
      _selectionCurrentStep != null &&
      _selectionCurrentCol != null &&
      (_selectionAnchorStep != _selectionCurrentStep || _selectionAnchorCol != _selectionCurrentCol);

  int get _selectionMinStep => math.min(
      _selectionAnchorStep ?? widget.dawState.trackerSelectedStep,
      _selectionCurrentStep ?? widget.dawState.trackerSelectedStep);
  int get _selectionMaxStep => math.max(
      _selectionAnchorStep ?? widget.dawState.trackerSelectedStep,
      _selectionCurrentStep ?? widget.dawState.trackerSelectedStep);
  int get _selectionMinCol => math.min(
      _selectionAnchorCol ?? widget.dawState.trackerSelectedColumn,
      _selectionCurrentCol ?? widget.dawState.trackerSelectedColumn);
  int get _selectionMaxCol => math.max(
      _selectionAnchorCol ?? widget.dawState.trackerSelectedColumn,
      _selectionCurrentCol ?? widget.dawState.trackerSelectedColumn);

  bool _isCellInBlock(int step, int col) {
    if (!_hasBlockSelection) return false;
    return step >= _selectionMinStep &&
        step <= _selectionMaxStep &&
        col >= _selectionMinCol &&
        col <= _selectionMaxCol;
  }

  void _clearBlockSelection() {
    setState(() {
      _selectionAnchorStep = null;
      _selectionAnchorCol = null;
      _selectionCurrentStep = null;
      _selectionCurrentCol = null;
    });
  }

  int _lastTabIndex = -1;
  MusicViewType? _lastActiveView;

  @override
  void initState() {
    super.initState();
    widget.dawState.addListener(_onDawStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TrackerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dawState != widget.dawState) {
      oldWidget.dawState.removeListener(_onDawStateChanged);
      widget.dawState.addListener(_onDawStateChanged);
    }
    if (widget.dawState.activeTabIndex == 1 && widget.dawState.activeTrack.activeView == MusicViewType.tracker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.dawState.removeListener(_onDawStateChanged);
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDawStateChanged() {
    if (!mounted) return;
    final bool isEditTab = widget.dawState.activeTabIndex == 1;
    final bool isTrackerActive = widget.dawState.activeTrack.activeView == MusicViewType.tracker;
    final bool shouldCenter = widget.dawState.shouldCenterEditViewOnOpen;
    if (shouldCenter || (isEditTab && isTrackerActive && (_lastTabIndex != 1 || _lastActiveView != MusicViewType.tracker))) {
      widget.dawState.shouldCenterEditViewOnOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
        if (_verticalScroll.hasClients) {
          final activeClip = widget.dawState.activeClip;
          final clipStartStep = (activeClip?.startBar ?? 0) * 16;
          final totalSteps = (activeClip?.barLength ?? 4) * 16;
          final stepInClip = (widget.dawState.arrangerStep - clipStartStep).clamp(0, totalSteps - 1);
          widget.dawState.selectTrackerCell(stepInClip, widget.dawState.trackerSelectedColumn);
          final viewportH = _verticalScroll.position.viewportDimension;
          final targetOffset = (stepInClip * 32.0) - (viewportH / 2.0) + 16.0;
          _verticalScroll.jumpTo(targetOffset.clamp(0.0, _verticalScroll.position.maxScrollExtent));
        }
      });
    }
    _lastTabIndex = widget.dawState.activeTabIndex;
    _lastActiveView = widget.dawState.activeTrack.activeView;

    if (_followPlayback && widget.dawState.isPlaying) {
      final currentStep = widget.dawState.currentStep;
      if (currentStep != _lastFollowStep && _verticalScroll.hasClients) {
        _lastFollowStep = currentStep;
        final targetOffset = (currentStep * 32.0) - 100.0;
        final maxScroll = _verticalScroll.position.maxScrollExtent;
        _verticalScroll.jumpTo(targetOffset.clamp(0.0, maxScroll));
      }
    }
    setState(() {});
  }

  void _scrollToSelectedStep() {
    if (!_verticalScroll.hasClients) return;
    final targetOffset = widget.dawState.trackerSelectedStep * 32.0;
    final double currentMin = _verticalScroll.offset;
    final double currentMax = currentMin + 250.0;
    if (targetOffset < currentMin || targetOffset > currentMax) {
      _verticalScroll.animateTo(
        targetOffset.clamp(0.0, _verticalScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleCellTap(int stepIdx, int colIdx, TrackChannel track, Note noteMatch) {
    _focusNode.requestFocus();

    if (HardwareKeyboard.instance.isShiftPressed) {
      setState(() {
        _selectionAnchorStep ??= widget.dawState.trackerSelectedStep;
        _selectionAnchorCol ??= widget.dawState.trackerSelectedColumn;
        _selectionCurrentStep = stepIdx;
        _selectionCurrentCol = colIdx;
        widget.dawState.selectTrackerCell(stepIdx, colIdx);
      });
      return;
    }

    _clearBlockSelection();
    widget.dawState.selectTrackerCell(stepIdx, colIdx);
    setState(() {});

    final now = DateTime.now();
    final cellKey = '${stepIdx}_$colIdx';

    if (_lastTapTime != null &&
        _lastTapCellKey == cellKey &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 320)) {
      _showTrackerCellEditor(context, track, stepIdx, colIdx, noteMatch);
      _lastTapTime = null;
      _lastTapCellKey = null;
    } else {
      _lastTapTime = now;
      _lastTapCellKey = cellKey;
    }
  }

  Future<void> _copyTrackerBlock() async {
    final track = widget.dawState.activeTrack;
    String lua = '';
    int count = 0;
    if (_hasBlockSelection) {
      final minS = _selectionMinStep;
      final maxS = _selectionMaxStep;
      final minC = _selectionMinCol;
      final maxC = _selectionMaxCol;
      lua = await widget.dawState.copyTrackerBlockToClipboard(
        startStep: minS,
        endStep: maxS,
        startCol: minC,
        endCol: maxC,
      );
      count = track.notes.where((n) {
        final s = n.startStep.toInt();
        return s >= minS && s <= maxS && n.column >= minC && n.column <= maxC;
      }).length;
    } else {
      final s = widget.dawState.trackerSelectedStep;
      final c = widget.dawState.trackerSelectedColumn;
      final noteMatch = track.notes.where((n) => n.startStep.toInt() == s && n.column == c).toList();
      if (noteMatch.isNotEmpty) {
        lua = await widget.dawState.copyNotesToClipboard(track, [noteMatch.first.id]);
        count = 1;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count > 0 ? 'Copied $count note${count != 1 ? 's' : ''} as Lua to clipboard' : 'No notes in selection to copy'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cutTrackerBlock() async {
    await _copyTrackerBlock();
    if (_hasBlockSelection) {
      widget.dawState.deleteTrackerNotesInBlock(
        startStep: _selectionMinStep,
        endStep: _selectionMaxStep,
        startCol: _selectionMinCol,
        endCol: _selectionMaxCol,
      );
      _clearBlockSelection();
    } else {
      widget.dawState.deleteTrackerNoteAtSelectedCell();
    }
  }

  Future<void> _pasteTrackerNotes() async {
    final track = widget.dawState.activeTrack;
    final targetStep = widget.dawState.trackerSelectedStep.toDouble();
    final targetCol = widget.dawState.trackerSelectedColumn;
    final pasted = await widget.dawState.pasteNotesFromClipboard(
      track,
      targetStep: targetStep,
      targetCol: targetCol,
    );

    if (!mounted) return;
    if (pasted.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pasted ${pasted.length} note${pasted.length != 1 ? 's' : ''} at Step ${targetStep.toInt()}, Col ${targetCol + 1}'),
          backgroundColor: EatsTheme.panelHeader,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final track = widget.dawState.activeTrack;
    final int clipSteps = (widget.dawState.activeTrackClip.barLength * 16).toInt();
    final int patternSteps = widget.dawState.activePattern.lengthSteps;
    final int maxNoteStep = track.notes.fold<int>(0, (int m, Note n) => math.max<int>(m, (n.startStep + n.durationSteps).ceil()));
    final int totalSteps = math.max<int>(16, math.max<int>(clipSteps, math.max<int>(patternSteps, maxNoteStep)));
    final int totalColumns = track.trackerColumns;
    final key = event.logicalKey;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    // Ctrl+A / Cmd+A -> Select All Matrix Cells
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyA) {
      setState(() {
        _selectionAnchorStep = 0;
        _selectionAnchorCol = 0;
        _selectionCurrentStep = totalSteps - 1;
        _selectionCurrentCol = totalColumns - 1;
      });
      return KeyEventResult.handled;
    }

    // Ctrl+C / Cmd+C -> Copy Block Notes as Lua
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyC) {
      _copyTrackerBlock();
      return KeyEventResult.handled;
    }

    // Ctrl+X / Cmd+X -> Cut Block Notes
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyX) {
      _cutTrackerBlock();
      return KeyEventResult.handled;
    }

    // Ctrl+V / Cmd+V -> Paste Notes at selected cell
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyV) {
      _pasteTrackerNotes();
      return KeyEventResult.handled;
    }

    // Escape -> Clear Block Selection, or return to Arranger tab if already cleared
    if (key == LogicalKeyboardKey.escape) {
      if (_hasBlockSelection) {
        _clearBlockSelection();
        return KeyEventResult.handled;
      }
      final activeClip = widget.dawState.activeClip;
      if (activeClip != null) {
        final tIdx = widget.dawState.visibleTracks.indexWhere((t) => t.id == activeClip.trackId);
        if (tIdx != -1) {
          widget.dawState.selectSequenceCell(activeClip.startBar, tIdx);
        }
      }
      widget.dawState.activeTabIndex = 0;
      return KeyEventResult.handled;
    }

    // Helper for Shift-Arrow / Arrow Navigation
    void moveSelection(int newStep, int newCol) {
      final int clampedStep = newStep.clamp(0, totalSteps - 1).toInt();
      final int clampedCol = newCol.clamp(0, totalColumns - 1).toInt();
      if (isShift) {
        setState(() {
          _selectionAnchorStep ??= widget.dawState.trackerSelectedStep;
          _selectionAnchorCol ??= widget.dawState.trackerSelectedColumn;
          _selectionCurrentStep = clampedStep;
          _selectionCurrentCol = clampedCol;
          widget.dawState.selectTrackerCell(clampedStep, clampedCol);
        });
      } else {
        _clearBlockSelection();
        widget.dawState.selectTrackerCell(clampedStep, clampedCol);
      }
      _scrollToSelectedStep();
    }

    // Arrow & Navigation Keys
    if (key == LogicalKeyboardKey.arrowUp) {
      moveSelection(widget.dawState.trackerSelectedStep - 1, widget.dawState.trackerSelectedColumn);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      moveSelection(widget.dawState.trackerSelectedStep + 1, widget.dawState.trackerSelectedColumn);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      moveSelection(widget.dawState.trackerSelectedStep, widget.dawState.trackerSelectedColumn - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      moveSelection(widget.dawState.trackerSelectedStep, widget.dawState.trackerSelectedColumn + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      moveSelection(widget.dawState.trackerSelectedStep - 4, widget.dawState.trackerSelectedColumn);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      moveSelection(widget.dawState.trackerSelectedStep + 4, widget.dawState.trackerSelectedColumn);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      moveSelection(0, widget.dawState.trackerSelectedColumn);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      moveSelection(totalSteps - 1, widget.dawState.trackerSelectedColumn);
      return KeyEventResult.handled;
    }

    // Delete / Erase Note(s)
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (_hasBlockSelection) {
        widget.dawState.deleteTrackerNotesInBlock(
          startStep: _selectionMinStep,
          endStep: _selectionMaxStep,
          startCol: _selectionMinCol,
          endCol: _selectionMaxCol,
        );
        _clearBlockSelection();
      } else {
        widget.dawState.deleteTrackerNoteAtSelectedCell();
      }
      return KeyEventResult.handled;
    }

    // Base Octave adjustment keys
    if (key == LogicalKeyboardKey.bracketLeft || key == LogicalKeyboardKey.minus) {
      setState(() => _qwertyBaseOctave = (_qwertyBaseOctave - 1).clamp(1, 6));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketRight || key == LogicalKeyboardKey.equal) {
      setState(() => _qwertyBaseOctave = (_qwertyBaseOctave + 1).clamp(1, 6));
      return KeyEventResult.handled;
    }

    // Desktop QWERTY DAW Tracker Keymap (FastTracker2 / Renoise / FL Studio Style)
    final qwertyNoteMap = <LogicalKeyboardKey, int>{
      // Lower Octave
      LogicalKeyboardKey.keyZ: 0, // C
      LogicalKeyboardKey.keyS: 1, // C#
      LogicalKeyboardKey.keyX: 2, // D
      LogicalKeyboardKey.keyD: 3, // D#
      LogicalKeyboardKey.keyC: 4, // E
      LogicalKeyboardKey.keyV: 5, // F
      LogicalKeyboardKey.keyG: 6, // F#
      LogicalKeyboardKey.keyB: 7, // G
      LogicalKeyboardKey.keyH: 8, // G#
      LogicalKeyboardKey.keyN: 9, // A
      LogicalKeyboardKey.keyJ: 10, // A#
      LogicalKeyboardKey.keyM: 11, // B

      // Upper Octave (+1 Octave)
      LogicalKeyboardKey.keyQ: 12, // C
      LogicalKeyboardKey.digit2: 13, // C#
      LogicalKeyboardKey.keyW: 14, // D
      LogicalKeyboardKey.digit3: 15, // D#
      LogicalKeyboardKey.keyE: 16, // E
      LogicalKeyboardKey.keyR: 17, // F
      LogicalKeyboardKey.digit5: 18, // F#
      LogicalKeyboardKey.keyT: 19, // G
      LogicalKeyboardKey.digit6: 20, // G#
      LogicalKeyboardKey.keyY: 21, // A
      LogicalKeyboardKey.digit7: 22, // A#
      LogicalKeyboardKey.keyU: 23, // B
      LogicalKeyboardKey.keyI: 24, // C (+2 Octaves)
      LogicalKeyboardKey.digit9: 25, // C#
      LogicalKeyboardKey.keyO: 26, // D
      LogicalKeyboardKey.digit0: 27, // D#
      LogicalKeyboardKey.keyP: 28, // E
    };

    // Shift+S or Alt+S -> Toggle Slide / Bend on selected tracker cell
    if ((HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isAltPressed) && key == LogicalKeyboardKey.keyS) {
      widget.dawState.toggleTrackerSlideAtSelectedCell();
      return KeyEventResult.handled;
    }

    if (qwertyNoteMap.containsKey(key)) {
      final semitones = qwertyNoteMap[key]!;
      final pitch = (_qwertyBaseOctave + 1) * 12 + semitones;
      widget.dawState.addOrUpdateTrackerNote(
        pitch: pitch,
        velocity: 0.85,
        autoAdvance: true,
      );
      _scrollToSelectedStep();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.dawState.activeTrack;
    final int clipSteps = (widget.dawState.activeTrackClip.barLength * 16).toInt();
    final int patternSteps = widget.dawState.activePattern.lengthSteps;
    final int maxNoteStep = track.notes.fold<int>(0, (int m, Note n) => math.max<int>(m, (n.startStep + n.durationSteps).ceil()));
    final int totalSteps = math.max<int>(16, math.max<int>(clipSteps, math.max<int>(patternSteps, maxNoteStep)));
    final int totalColumns = track.trackerColumns;

    final noteMap = <String, Note>{};
    for (final n in track.notes) {
      noteMap['${n.startStep.toInt()}_${n.column}'] = n;
    }

    const double columnWidth = 142.0;
    const double rowHeaderWidth = 44.0;
    final double tableWidth = rowHeaderWidth + (totalColumns * (columnWidth + 4.0));

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          // Sub-channel Column Titles Header & Desktop Octave Display
          Container(
            color: EatsTheme.controlBackground,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.view_column, size: 16, color: EatsTheme.primaryCyan),
                const SizedBox(width: 6),
                Text(
                  'TRACKER MATRIX',
                  style: TextStyle(
                    color: EatsTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),

                if (_hasBlockSelection) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: EatsTheme.primaryCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.6)),
                    ),
                    child: Text(
                      'BLOCK: R${_selectionMinStep}..R${_selectionMaxStep} (C${_selectionMinCol + 1}..C${_selectionMaxCol + 1})',
                      style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('SEMITONES:', style: TextStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 2),
                  ...[-12, -1, 1, 12].map((st) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: InkWell(
                          onTap: () {
                            widget.dawState.transposeTrackerNotesInBlock(
                              startStep: _selectionMinStep,
                              endStep: _selectionMaxStep,
                              startCol: _selectionMinCol,
                              endCol: _selectionMaxCol,
                              semitones: st,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: EatsTheme.panelHeader,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              st > 0 ? '+$st' : '$st',
                              style: TextStyle(color: EatsTheme.accentGold, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )),
                  IconButton(
                    icon: Icon(Icons.copy, color: EatsTheme.primaryCyan, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: 'Copy Block as Lua (Ctrl+C)',
                    onPressed: _copyTrackerBlock,
                  ),
                  IconButton(
                    icon: Icon(Icons.cut, color: EatsTheme.accentGold, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: 'Cut Block (Ctrl+X)',
                    onPressed: _cutTrackerBlock,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 15),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: 'Delete Block Notes (Del)',
                    onPressed: () {
                      widget.dawState.deleteTrackerNotesInBlock(
                        startStep: _selectionMinStep,
                        endStep: _selectionMaxStep,
                        startCol: _selectionMinCol,
                        endCol: _selectionMaxCol,
                      );
                      _clearBlockSelection();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: EatsTheme.textMuted, size: 15),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: 'Deselect Block (Esc)',
                    onPressed: _clearBlockSelection,
                  ),
                ],

                const Spacer(),

                // Global Clipboard Buttons
                IconButton(
                  icon: Icon(Icons.copy, color: EatsTheme.primaryCyan, size: 15),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: _hasBlockSelection ? 'Copy Block as Lua (Ctrl+C)' : 'Copy Selected Note as Lua (Ctrl+C)',
                  onPressed: _copyTrackerBlock,
                ),
                IconButton(
                  icon: Icon(Icons.paste, color: EatsTheme.accentGreen, size: 15),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Paste Notes at Cursor Cell (Ctrl+V)',
                  onPressed: _pasteTrackerNotes,
                ),
                const SizedBox(width: 6),

                // Tracker Column Controls
                Text('COLS: ', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: EatsTheme.textSecondary, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Remove Tracker Column',
                  onPressed: () => widget.dawState.setTrackerColumns(track, track.trackerColumns - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${track.trackerColumns}',
                    style: EatsTheme.getDisplayFontStyle(color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: EatsTheme.primaryCyan, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Add Tracker Column',
                  onPressed: () => widget.dawState.setTrackerColumns(track, track.trackerColumns + 1),
                ),
                const SizedBox(width: 8),

                // Follow Playback Toggle Button
                InkWell(
                  onTap: () {
                    setState(() {
                      _followPlayback = !_followPlayback;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Tooltip(
                    message: _followPlayback ? 'Follow Playback: ON' : 'Follow Playback: OFF',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _followPlayback
                            ? EatsTheme.primaryCyan.withOpacity(0.2)
                            : EatsTheme.panelBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _followPlayback ? EatsTheme.primaryCyan : EatsTheme.panelHeader,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gps_fixed,
                            size: 13,
                            color: _followPlayback ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FOLLOW',
                            style: TextStyle(
                              color: _followPlayback ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // High-Performance Unified Scroll Matrix Layout
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerUp: (_) {
                if (_isMouseDown) setState(() => _isMouseDown = false);
              },
              onPointerCancel: (_) {
                if (_isMouseDown) setState(() => _isMouseDown = false);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _focusNode.requestFocus(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalScroll,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                      // Sub-channel Column Header Row
                      Container(
                        height: 24,
                        color: EatsTheme.panelBackground,
                        child: Row(
                          children: [
                            // Step counter header spacer
                            SizedBox(
                              width: rowHeaderWidth,
                              child: Center(
                                child: Text(
                                  'STEP',
                                  style: TextStyle(
                                    color: EatsTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // Sub-channel Column Labels
                            ...List.generate(totalColumns, (colIdx) {
                              final isSelectedCol = widget.dawState.trackerSelectedColumn == colIdx;
                              return Container(
                                width: columnWidth,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelectedCol
                                      ? EatsTheme.primaryCyan.withOpacity(0.15)
                                      : EatsTheme.controlBackground.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: isSelectedCol ? EatsTheme.primaryCyan : Colors.transparent,
                                    width: 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'CH ${colIdx + 1} (NOTE/VOL/SLD/FX)',
                                  style: TextStyle(
                                    color: isSelectedCol
                                        ? EatsTheme.accentGold
                                        : (colIdx % 2 == 0 ? EatsTheme.primaryCyan : EatsTheme.secondaryMagenta),
                                    fontSize: 9.5,
                                    fontWeight: isSelectedCol ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      // Vertical Steps Builder
                      Expanded(
                        child: ListView.builder(
                          controller: _verticalScroll,
                          itemCount: totalSteps,
                          itemBuilder: (context, stepIdx) {
                            final isCurrentStep = widget.dawState.isPlaying && widget.dawState.currentStep == stepIdx;
                            final isSelectedLine = widget.dawState.trackerSelectedStep == stepIdx;
                            final isBeatFour = stepIdx % 4 == 0;

                            return Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCurrentStep
                                    ? EatsTheme.primaryCyan.withOpacity(0.30)
                                    : (isSelectedLine
                                        ? EatsTheme.highlightColor.withOpacity(0.20)
                                        : (isBeatFour ? EatsTheme.panelBackground : EatsTheme.backgroundDark)),
                                border: Border(
                                  bottom: BorderSide(
                                    color: isSelectedLine
                                        ? EatsTheme.highlightColor.withOpacity(0.8)
                                        : (isBeatFour ? EatsTheme.panelHeader : EatsTheme.controlBackground.withOpacity(0.4)),
                                    width: isSelectedLine ? 1.5 : (isBeatFour ? 1.5 : 0.5),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Step Row Counter
                                  SizedBox(
                                    width: rowHeaderWidth,
                                    child: Center(
                                      child: Text(
                                        stepIdx.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          color: isCurrentStep
                                              ? EatsTheme.accentGreen
                                              : (isSelectedLine
                                                  ? EatsTheme.highlightColor
                                                  : (isBeatFour ? EatsTheme.accentGold : EatsTheme.textMuted)),
                                          fontFamily: 'monospace',
                                          fontWeight: (isCurrentStep || isSelectedLine) ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Sub-Channel Note Data Columns
                                  ...List.generate(totalColumns, (colIdx) {
                                    final noteMatch = noteMap['${stepIdx}_$colIdx'] ?? Note(id: '', pitch: -1, startStep: -1);

                                    final hasNote = noteMatch.pitch != -1;
                                    final isSelectedCell = isSelectedLine && widget.dawState.trackerSelectedColumn == colIdx;
                                    final isInBlock = _isCellInBlock(stepIdx, colIdx);

                                    final noteStr = hasNote ? _formatTrackerNote(noteMatch.pitch) : '---';
                                    final volStr = hasNote ? 'V${(noteMatch.velocity * 99).toInt().toString().padLeft(2, '0')}' : '..';
                                    final sldStr = hasNote ? (noteMatch.isSlide ? 'S' : '.') : '.';
                                    final fxStr = hasNote ? noteMatch.effectCommand : '00';

                                    return MouseRegion(
                                      onEnter: (_) {
                                        if (_isMouseDown) {
                                          if (_selectionCurrentStep != stepIdx || _selectionCurrentCol != colIdx) {
                                            setState(() {
                                              _selectionCurrentStep = stepIdx;
                                              _selectionCurrentCol = colIdx;
                                            });
                                          }
                                        }
                                      },
                                      child: Listener(
                                        onPointerDown: (event) {
                                          if (event.kind == PointerDeviceKind.mouse && (event.buttons & kPrimaryMouseButton) != 0) {
                                            _isMouseDown = true;
                                            _focusNode.requestFocus();
                                            if (HardwareKeyboard.instance.isShiftPressed) {
                                              setState(() {
                                                _selectionAnchorStep ??= widget.dawState.trackerSelectedStep;
                                                _selectionAnchorCol ??= widget.dawState.trackerSelectedColumn;
                                                _selectionCurrentStep = stepIdx;
                                                _selectionCurrentCol = colIdx;
                                              });
                                            } else {
                                              setState(() {
                                                _selectionAnchorStep = stepIdx;
                                                _selectionAnchorCol = colIdx;
                                                _selectionCurrentStep = stepIdx;
                                                _selectionCurrentCol = colIdx;
                                              });
                                            }
                                          }
                                        },
                                        onPointerUp: (event) {
                                          if (_isMouseDown) {
                                            _isMouseDown = false;
                                          }
                                        },
                                        onPointerCancel: (event) {
                                          _isMouseDown = false;
                                        },
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (_) {
                                            _handleCellTap(stepIdx, colIdx, track, noteMatch);
                                          },
                                          onLongPressStart: (details) {
                                            _focusNode.requestFocus();
                                            _longPressStartGlobalPos = details.globalPosition;
                                            setState(() {
                                              _selectionAnchorStep = stepIdx;
                                              _selectionAnchorCol = colIdx;
                                              _selectionCurrentStep = stepIdx;
                                              _selectionCurrentCol = colIdx;
                                              widget.dawState.selectTrackerCell(stepIdx, colIdx);
                                            });
                                          },
                                          onLongPressMoveUpdate: (details) {
                                            if (_longPressStartGlobalPos != null) {
                                              final deltaY = details.globalPosition.dy - _longPressStartGlobalPos!.dy;
                                              final deltaX = details.globalPosition.dx - _longPressStartGlobalPos!.dx;
                                              final int targetStep = (stepIdx + (deltaY / 32.0).round()).clamp(0, totalSteps - 1).toInt();
                                              final int targetCol = (colIdx + (deltaX / (columnWidth + 4.0)).round()).clamp(0, totalColumns - 1).toInt();
                                              if (_selectionCurrentStep != targetStep || _selectionCurrentCol != targetCol) {
                                                setState(() {
                                                  _selectionCurrentStep = targetStep;
                                                  _selectionCurrentCol = targetCol;
                                                });
                                              }
                                            }
                                          },
                                          onLongPressEnd: (_) {
                                            _longPressStartGlobalPos = null;
                                          },
                                          child: Container(
                                            width: columnWidth,
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isInBlock
                                                  ? EatsTheme.primaryCyan.withOpacity(0.35)
                                                  : (isSelectedCell
                                                      ? EatsTheme.highlightColor.withOpacity(0.40)
                                                      : (hasNote
                                                          ? (noteMatch.isSlide ? EatsTheme.accentGold.withOpacity(0.25) : track.color.withOpacity(0.25))
                                                          : EatsTheme.controlBackground.withOpacity(0.3))),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isInBlock
                                                    ? EatsTheme.primaryCyan
                                                    : (isSelectedCell
                                                        ? EatsTheme.highlightColor
                                                        : (hasNote ? (noteMatch.isSlide ? EatsTheme.accentGold.withOpacity(0.8) : track.color.withOpacity(0.6)) : Colors.transparent)),
                                                width: (isInBlock || isSelectedCell) ? 2.0 : 1.0,
                                              ),
                                              boxShadow: (isInBlock || isSelectedCell)
                                                  ? [
                                                      BoxShadow(
                                                        color: (isInBlock ? EatsTheme.primaryCyan : EatsTheme.highlightColor).withOpacity(0.4),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      )
                                                    ]
                                                  : null,
                                            ),
                                            child: Text(
                                              '$noteStr $volStr $sldStr $fxStr${(hasNote && noteMatch.lyric != null && noteMatch.lyric!.isNotEmpty) ? ' "${noteMatch.lyric}"' : ''}',
                                              overflow: TextOverflow.ellipsis,
                                              style: EatsTheme.getDisplayFontStyle(
                                                color: (isInBlock || isSelectedCell)
                                                    ? Colors.white
                                                    : (hasNote ? (noteMatch.isSlide ? EatsTheme.accentGold : EatsTheme.textPrimary) : EatsTheme.textMuted),
                                                fontSize: 10.5,
                                                fontWeight: (hasNote || isSelectedCell || isInBlock) ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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

  String _formatTrackerNote(int pitch) {
    if (pitch < 0) return '---';
    final names = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-'];
    final octave = (pitch ~/ 12) - 1;
    return '${names[pitch % 12]}$octave';
  }

  void _showTrackerCellEditor(
    BuildContext context,
    TrackChannel track,
    int stepIdx,
    int colIdx,
    Note existingNote,
  ) {
    int selectedPitch = existingNote.pitch != -1 ? existingNote.pitch : 60;
    double selectedVol = existingNote.pitch != -1 ? existingNote.velocity : 0.85;
    bool selectedSlide = existingNote.pitch != -1 ? existingNote.isSlide : false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: EatsTheme.panelBackground,
              title: Text(
                'ROW ${stepIdx.toString().padLeft(2, '0')} - COL 0${colIdx + 1}',
                style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 14),
              ),
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('NOTE PITCH:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 12)),
                        Text(_formatTrackerNote(selectedPitch), style: const TextStyle(color: EatsTheme.accentGold, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    EatsBeatsSlider(
                      value: selectedPitch.toDouble(),
                      min: 24,
                      max: 84,
                      defaultValue: 60,
                      label: 'Note Pitch',
                      activeColor: track.color,
                      onChanged: (val) {
                        setDialogState(() => selectedPitch = val.toInt());
                        widget.dawState.audioEngine.playNoteOrSample(
                          track: track,
                          midiNote: selectedPitch,
                          velocity: selectedVol,
                          isSlide: selectedSlide,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('VELOCITY:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 12)),
                        Text('${(selectedVol * 100).toInt()}%', style: TextStyle(color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    EatsBeatsSlider(
                      value: selectedVol,
                      min: 0.0,
                      max: 1.0,
                      defaultValue: 0.9,
                      label: 'Note Velocity',
                      activeColor: EatsTheme.primaryCyan,
                      onChanged: (val) {
                        setDialogState(() => selectedVol = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('NOTE TYPE:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 12)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChoiceChip(
                              label: const Text('Normal', style: TextStyle(fontSize: 10)),
                              selected: !selectedSlide,
                              selectedColor: EatsTheme.primaryCyan.withOpacity(0.35),
                              onSelected: (val) {
                                if (val) setDialogState(() => selectedSlide = false);
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Bend (Slide)', style: TextStyle(fontSize: 10)),
                              selected: selectedSlide,
                              selectedColor: EatsTheme.accentGold.withOpacity(0.35),
                              onSelected: (val) {
                                if (val) setDialogState(() => selectedSlide = true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                if (existingNote.pitch != -1)
                  TextButton(
                    onPressed: () {
                      widget.dawState.removeNote(track, existingNote.id);
                      Navigator.pop(context);
                    },
                    child: const Text('DELETE', style: TextStyle(color: EatsTheme.muteColor)),
                  ),
                TextButton(
                  onPressed: () {
                    if (existingNote.pitch != -1) {
                      widget.dawState.removeNote(track, existingNote.id);
                    }
                    widget.dawState.addNote(
                      track,
                      Note(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        pitch: selectedPitch,
                        startStep: stepIdx.toDouble(),
                        durationSteps: 1.0,
                        velocity: selectedVol,
                        column: colIdx,
                        isSlide: selectedSlide,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: Text('SET NOTE', style: TextStyle(color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
