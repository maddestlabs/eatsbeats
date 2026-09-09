import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'score_layout_engine.dart';
import 'score_vector_glyphs.dart';

class ScoreView extends StatefulWidget {
  final DawState dawState;

  const ScoreView({super.key, required this.dawState});

  @override
  State<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends State<ScoreView> {
  // Score configuration state
  ScoreClef _selectedClef = ScoreClef.auto;
  ScoreNoteType _selectedDuration = ScoreNoteType.quarter;
  ScoreAccidental _selectedAccidental = ScoreAccidental.none;

  // View scaling & metrics
  final double _stepWidth = 32.0;
  static const double _staffSpace = 13.0;
  static const double _gutterWidth = 92.0;

  /// Dynamically computes total steps in the score view to allow arbitrary-length panning.
  int get _totalSteps {
    int maxSteps = 64;
    final clip = widget.dawState.activeTrackClip;
    final clipEnd = (clip.startBar + clip.barLength) * 16;
    if (clipEnd > maxSteps) maxSteps = clipEnd;
    final timelineSteps = widget.dawState.totalTimelineBars * 16;
    if (timelineSteps > maxSteps) maxSteps = timelineSteps;
    for (final note in widget.dawState.activeTrack.notes) {
      final end = (note.startStep + note.durationSteps).ceil();
      if (end + 16 > maxSteps) maxSteps = end + 16;
    }
    return math.max(maxSteps, 64) + 64;
  }

  // Scroll & Selection
  final ScrollController _horizontalScroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Set<String> get _selectedNoteIds => widget.dawState.activeTrack.selectedNoteIds;
  set _selectedNoteIds(Set<String> s) {
    widget.dawState.selectNotes(widget.dawState.activeTrack, s);
  }

  // Tap & Double-Tap Tracking (for instant delete or insert)
  DateTime? _lastNoteTapTime;
  String? _lastNoteTapId;
  DateTime? _lastGridTapTime;
  Offset? _lastGridTapPos;

  // Modeless Gesture Tracking: Pan vs Multi-Select Marquee vs Note Drag
  Timer? _holdTimer;
  Offset? _pointerDownPos;
  bool _isMarqueeSelecting = false;
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;

  bool _isCanvasPanning = false;
  double? _canvasPanStartScrollOffset;

  String? _draggedNoteId;
  Offset? _noteDragStartPos;
  int? _lastAuditionedPitch;
  final Map<String, double> _batchStartSteps = {};
  final Map<String, int> _batchStartPitches = {};

  @override
  void initState() {
    super.initState();
    widget.dawState.addListener(_onDawStateChanged);
    widget.dawState.continuousArrangerStepNotifier.addListener(_onContinuousPlayheadFollow);
  }

  void _onContinuousPlayheadFollow() {
    if (!mounted) return;
    if (widget.dawState.activeTabIndex != 1) return;
    if (widget.dawState.activeTrack.activeView != MusicViewType.score) return;
    if (widget.dawState.isFollowPlayback && widget.dawState.isPlaying) {
      if (_horizontalScroll.hasClients && !_isCanvasPanning && !_isMarqueeSelecting && _draggedNoteId == null) {
        final continuousStep = widget.dawState.continuousArrangerStepNotifier.value;

        final clip = widget.dawState.activeTrackClip;
        final clipStartStep = (clip.startBar * 16).toDouble();
        final clipEndStep = clipStartStep + _totalSteps.toDouble();
        if (continuousStep >= clipStartStep && continuousStep <= clipEndStep) {
          final activeStepInClip = continuousStep - clipStartStep;
          final contentPlayheadX = _gutterWidth + (activeStepInClip * _stepWidth);
          final viewportW = _horizontalScroll.position.viewportDimension;
          final targetX = (contentPlayheadX - (viewportW / 2.0)).clamp(0.0, _horizontalScroll.position.maxScrollExtent);
          if ((_horizontalScroll.offset - targetX).abs() > 0.5) {
            _horizontalScroll.jumpTo(targetX);
          }
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant ScoreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dawState != widget.dawState) {
      oldWidget.dawState.removeListener(_onDawStateChanged);
      oldWidget.dawState.continuousArrangerStepNotifier.removeListener(_onContinuousPlayheadFollow);
      widget.dawState.addListener(_onDawStateChanged);
      widget.dawState.continuousArrangerStepNotifier.addListener(_onContinuousPlayheadFollow);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    widget.dawState.removeListener(_onDawStateChanged);
    widget.dawState.continuousArrangerStepNotifier.removeListener(_onContinuousPlayheadFollow);
    _horizontalScroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDawStateChanged() {
    if (mounted) setState(() {});
  }

  /// Resolves whether to display Treble or Bass staff when clef mode is [auto].
  bool _resolveIsTrebleStaff(TrackChannel track) {
    if (_selectedClef == ScoreClef.treble) return true;
    if (_selectedClef == ScoreClef.bass) return false;

    // Auto detection
    if (track.type == TrackType.bass) return false;
    if (track.name.toLowerCase().contains('bass') ||
        track.name.toLowerCase().contains('303') ||
        track.name.toLowerCase().contains('kick') ||
        track.name.toLowerCase().contains('sub')) {
      return false;
    }

    if (track.notes.isNotEmpty) {
      final avgPitch = track.notes.map((n) => n.pitch).reduce((a, b) => a + b) / track.notes.length;
      return avgPitch >= 57; // A3 and above goes to Treble
    }

    return true;
  }

  double _durationToSteps(ScoreNoteType type) {
    switch (type) {
      case ScoreNoteType.whole:
        return 16.0;
      case ScoreNoteType.half:
        return 8.0;
      case ScoreNoteType.quarter:
        return 4.0;
      case ScoreNoteType.eighth:
        return 2.0;
      case ScoreNoteType.sixteenth:
        return 1.0;
    }
  }

  // ---------------------------------------------------------------------------
  // Note Operations
  // ---------------------------------------------------------------------------

  void _auditionNote(int pitch, {double velocity = 0.85}) {
    widget.dawState.audioEngine.playNoteOrSample(
      track: widget.dawState.activeTrack,
      midiNote: pitch,
      velocity: velocity,
    );
  }

  void _insertNoteAt(double step, int pitch) {
    final track = widget.dawState.activeTrack;
    final duration = _durationToSteps(_selectedDuration);

    track.notes.removeWhere((n) => (n.startStep - step).abs() < 0.2 && n.pitch == pitch);

    final newNote = Note(
      id: 'score_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}',
      pitch: pitch,
      startStep: step,
      durationSteps: duration,
      velocity: 0.85,
    );

    widget.dawState.addNote(track, newNote);
    setState(() {
      _selectedNoteIds = {newNote.id};
    });
  }

  void _deleteSelectedNotes() {
    final track = widget.dawState.activeTrack;
    for (final noteId in _selectedNoteIds) {
      widget.dawState.removeNote(track, noteId);
    }
    setState(() {
      _selectedNoteIds.clear();
    });
  }

  void _deleteNote(String noteId) {
    widget.dawState.removeNote(widget.dawState.activeTrack, noteId);
    setState(() {
      _selectedNoteIds.remove(noteId);
    });
  }

  void _transposeSelectedNotes(int delta) {
    final track = widget.dawState.activeTrack;
    for (final note in track.notes) {
      if (_selectedNoteIds.contains(note.id)) {
        note.pitch = (note.pitch + delta).clamp(0, 127);
      }
    }
    widget.dawState.commitHistoryTransaction();
    if (_selectedNoteIds.isNotEmpty) {
      final first = track.notes.where((n) => n.id == _selectedNoteIds.first).firstOrNull;
      if (first != null) _auditionNote(first.pitch, velocity: first.velocity);
    }
    setState(() {});
  }

  void _nudgeSelectedNotesPosition(double deltaSteps) {
    final track = widget.dawState.activeTrack;
    for (final note in track.notes) {
      if (_selectedNoteIds.contains(note.id)) {
        note.startStep = math.max(0.0, note.startStep + deltaSteps);
      }
    }
    widget.dawState.commitHistoryTransaction();
    setState(() {});
  }

  void _changeSelectedNotesDuration(double deltaSteps) {
    final track = widget.dawState.activeTrack;
    for (final note in track.notes) {
      if (_selectedNoteIds.contains(note.id)) {
        note.durationSteps = math.max(0.25, note.durationSteps + deltaSteps);
      }
    }
    widget.dawState.commitHistoryTransaction();
    setState(() {});
  }

  void _changeSelectedNotesVelocity(double newVelocity) {
    final track = widget.dawState.activeTrack;
    for (final note in track.notes) {
      if (_selectedNoteIds.contains(note.id)) {
        note.velocity = newVelocity.clamp(0.05, 1.0);
      }
    }
    widget.dawState.commitHistoryTransaction();
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Keyboard Shortcuts
  // ---------------------------------------------------------------------------

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_selectedNoteIds.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _transposeSelectedNotes(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _transposeSelectedNotes(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _nudgeSelectedNotesPosition(-1.0);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _nudgeSelectedNotesPosition(1.0);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
        _deleteSelectedNotes();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.dawState.clearNoteSelection(widget.dawState.activeTrack);
        setState(() {});
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Layout Coordinates Helpers
  // ---------------------------------------------------------------------------

  double _getStaffLine1Y(bool isTrebleStaff, bool isGrandStaff, double canvasHeight, {bool trebleOfGrand = true}) {
    if (!isGrandStaff) {
      return (canvasHeight * 0.60).clamp(110.0, 320.0);
    }
    // Grand Staff: Treble upper, Bass lower
    return trebleOfGrand ? (canvasHeight * 0.38) : (canvasHeight * 0.80);
  }

  Note? _findNoteAt(Offset pos, bool isTrebleStaff, bool isGrandStaff, double canvasHeight) {
    final track = widget.dawState.activeTrack;

    for (final note in track.notes) {
      final bool isNoteTreble = isGrandStaff ? (note.pitch >= 60) : isTrebleStaff;
      final staffLine1Y = _getStaffLine1Y(isTrebleStaff, isGrandStaff, canvasHeight, trebleOfGrand: isNoteTreble);

      final visual = ScoreLayoutEngine.computeVisual(
        pitchLayout: ScoreLayoutEngine.pitchToLayout(note.pitch),
        durationSteps: note.durationSteps,
        staffLine1Y: staffLine1Y,
        sp: _staffSpace,
        isTrebleStaff: isNoteTreble,
      );

      final noteX = _gutterWidth + (note.startStep * _stepWidth);
      final noteY = visual.yPos;

      final dist = (pos - Offset(noteX, noteY)).distance;
      if (dist < 20.0) {
        return note;
      }
    }
    return null;
  }

  void _updateMarqueeSelection(TrackChannel track, bool isTrebleStaff, bool isGrandStaff, double canvasHeight) {
    if (_marqueeStart == null || _marqueeCurrent == null) return;
    final marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeCurrent!);

    final newSelected = <String>{};
    for (final note in track.notes) {
      final bool isNoteTreble = isGrandStaff ? (note.pitch >= 60) : isTrebleStaff;
      final staffLine1Y = _getStaffLine1Y(isTrebleStaff, isGrandStaff, canvasHeight, trebleOfGrand: isNoteTreble);

      final visual = ScoreLayoutEngine.computeVisual(
        pitchLayout: ScoreLayoutEngine.pitchToLayout(note.pitch),
        durationSteps: note.durationSteps,
        staffLine1Y: staffLine1Y,
        sp: _staffSpace,
        isTrebleStaff: isNoteTreble,
      );

      final noteX = _gutterWidth + (note.startStep * _stepWidth);
      final noteY = visual.yPos;
      final noteRect = Rect.fromCenter(center: Offset(noteX, noteY), width: _staffSpace * 2.2, height: _staffSpace * 2.2);

      if (marqueeRect.overlaps(noteRect)) {
        newSelected.add(note.id);
      }
    }

    if (newSelected != _selectedNoteIds) {
      setState(() {
        _selectedNoteIds = newSelected;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final track = widget.dawState.activeTrack;
    final isTrebleStaff = _resolveIsTrebleStaff(track);
    final isGrandStaff = _selectedClef == ScoreClef.grandStaff;
    final isLight = EatsTheme.isLight;
    final selectedNotes = track.notes.where((n) => _selectedNoteIds.contains(n.id)).toList();

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        color: EatsTheme.backgroundDark,
        child: Column(
          children: [
            // Top Control Toolbar
            _buildToolbar(isTrebleStaff, isGrandStaff, selectedNotes.length),

            // Score Canvas & Note Inspector Sidebar Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Raw pointer listener to distinguish Pan vs Click+Hold Marquee
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent && _horizontalScroll.hasClients) {
                            final delta = event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
                            final maxScroll = _horizontalScroll.position.maxScrollExtent;
                            final target = (_horizontalScroll.offset + delta).clamp(0.0, maxScroll);
                            _horizontalScroll.jumpTo(target);
                          }
                        },
                        onPointerDown: (event) {
                          _focusNode.requestFocus();
                          final viewportPos = event.localPosition;
                          _pointerDownPos = viewportPos;
                          _isMarqueeSelecting = false;
                          _isCanvasPanning = false;
                          _marqueeStart = null;
                          _marqueeCurrent = null;

                          final double scrollOffset = _horizontalScroll.hasClients ? _horizontalScroll.offset : 0.0;
                          final contentPos = Offset(viewportPos.dx + scrollOffset, viewportPos.dy);

                          final hitNote = _findNoteAt(contentPos, isTrebleStaff, isGrandStaff, constraints.maxHeight);

                          if (hitNote != null) {
                            // Hit a note -> Handle note tap / double tap / drag
                            final now = DateTime.now();
                            if (_lastNoteTapId == hitNote.id &&
                                _lastNoteTapTime != null &&
                                now.difference(_lastNoteTapTime!) < const Duration(milliseconds: 280)) {
                              _deleteNote(hitNote.id);
                              _lastNoteTapTime = null;
                              _lastNoteTapId = null;
                              _draggedNoteId = null;
                              return;
                            }

                            _lastNoteTapTime = now;
                            _lastNoteTapId = hitNote.id;

                            if (HardwareKeyboard.instance.isShiftPressed) {
                              widget.dawState.toggleNoteSelection(track, hitNote.id);
                              setState(() {});
                            } else if (!_selectedNoteIds.contains(hitNote.id)) {
                              widget.dawState.selectNotes(track, [hitNote.id]);
                              setState(() {});
                            }
                            _auditionNote(hitNote.pitch, velocity: hitNote.velocity);

                            // Setup note dragging in content coordinates
                            _draggedNoteId = hitNote.id;
                            _noteDragStartPos = contentPos;
                            _lastAuditionedPitch = hitNote.pitch;
                            _batchStartSteps.clear();
                            _batchStartPitches.clear();
                            for (final n in track.notes) {
                              if (_selectedNoteIds.contains(n.id)) {
                                _batchStartSteps[n.id] = n.startStep;
                                _batchStartPitches[n.id] = n.pitch;
                              }
                            }
                          } else if (contentPos.dx >= _gutterWidth) {
                            // Empty canvas: Start hold timer for Multi-Select Marquee!
                            _draggedNoteId = null;
                            _holdTimer?.cancel();
                            _holdTimer = Timer(const Duration(milliseconds: 220), () {
                              if (mounted && _pointerDownPos != null && !_isCanvasPanning) {
                                final double curScroll = _horizontalScroll.hasClients ? _horizontalScroll.offset : 0.0;
                                final startPos = Offset(_pointerDownPos!.dx + curScroll, _pointerDownPos!.dy);
                                setState(() {
                                  _isMarqueeSelecting = true;
                                  _marqueeStart = startPos;
                                  _marqueeCurrent = startPos;
                                });
                                HapticFeedback.selectionClick();
                              }
                            });
                          }
                        },
                        onPointerMove: (event) {
                          if (_pointerDownPos == null) return;
                          final viewportPos = event.localPosition;
                          final moveDist = (viewportPos - _pointerDownPos!).distance;
                          final double scrollOffset = _horizontalScroll.hasClients ? _horizontalScroll.offset : 0.0;
                          final contentPos = Offset(viewportPos.dx + scrollOffset, viewportPos.dy);

                          // 1. Note Dragging / Transposing
                          if (_draggedNoteId != null && _noteDragStartPos != null && _batchStartSteps.isNotEmpty) {
                            final bool isNoteTreble = isGrandStaff ? (_batchStartPitches[_draggedNoteId]! >= 60) : isTrebleStaff;
                            final staffLine1Y = _getStaffLine1Y(isTrebleStaff, isGrandStaff, constraints.maxHeight, trebleOfGrand: isNoteTreble);

                            final currentPitch = ScoreLayoutEngine.yToMidiPitch(
                              y: contentPos.dy,
                              staffLine1Y: staffLine1Y,
                              sp: _staffSpace,
                              isTrebleStaff: isNoteTreble,
                              forcedAccidental: _selectedAccidental,
                            );

                            final startPitch = ScoreLayoutEngine.yToMidiPitch(
                              y: _noteDragStartPos!.dy,
                              staffLine1Y: staffLine1Y,
                              sp: _staffSpace,
                              isTrebleStaff: isNoteTreble,
                              forcedAccidental: _selectedAccidental,
                            );

                            final int pitchDelta = currentPitch - startPitch;
                            final double stepDelta = ((contentPos.dx - _noteDragStartPos!.dx) / _stepWidth).roundToDouble();

                            for (final n in track.notes) {
                              if (_selectedNoteIds.contains(n.id) && _batchStartSteps.containsKey(n.id)) {
                                final baseStep = _batchStartSteps[n.id]!;
                                final basePitch = _batchStartPitches[n.id]!;
                                n.startStep = math.max(0.0, baseStep + stepDelta);
                                n.pitch = (basePitch + pitchDelta).clamp(0, 127);
                              }
                            }

                            if (_lastAuditionedPitch != currentPitch) {
                              _lastAuditionedPitch = currentPitch;
                              _auditionNote(currentPitch);
                            }
                            setState(() {});
                            return;
                          }

                          // 2. Marquee Selecting
                          if (_isMarqueeSelecting) {
                            setState(() {
                              _marqueeCurrent = contentPos;
                              _updateMarqueeSelection(track, isTrebleStaff, isGrandStaff, constraints.maxHeight);
                            });
                            return;
                          }

                          // 3. Fast move before hold timer -> Cancel timer and PAN the staff view!
                          if (!_isCanvasPanning && moveDist > 5.0) {
                            _holdTimer?.cancel();
                            _isCanvasPanning = true;
                            _canvasPanStartScrollOffset = _horizontalScroll.hasClients ? _horizontalScroll.offset : 0.0;
                          }

                          if (_isCanvasPanning && _canvasPanStartScrollOffset != null && _horizontalScroll.hasClients) {
                            final dx = viewportPos.dx - _pointerDownPos!.dx;
                            final targetOffset = (_canvasPanStartScrollOffset! - dx).clamp(
                              0.0,
                              _horizontalScroll.position.maxScrollExtent,
                            );
                            _horizontalScroll.jumpTo(targetOffset);
                            // Pure scroll update: do not call setState during pan to prevent rebuild thrashing and ghosting
                          }
                        },
                        onPointerUp: (event) {
                          _holdTimer?.cancel();
                          final viewportPos = event.localPosition;
                          final moveDist = _pointerDownPos != null ? (viewportPos - _pointerDownPos!).distance : 0.0;
                          final double scrollOffset = _horizontalScroll.hasClients ? _horizontalScroll.offset : 0.0;
                          final contentPos = Offset(viewportPos.dx + scrollOffset, viewportPos.dy);
                          final bool wasInteractingWithNote = _draggedNoteId != null;

                          // Finish Note Drag
                          if (_draggedNoteId != null) {
                            widget.dawState.commitHistoryTransaction();
                            _draggedNoteId = null;
                            _noteDragStartPos = null;
                            _batchStartSteps.clear();
                            _batchStartPitches.clear();
                          }

                          // Finish Marquee
                          if (_isMarqueeSelecting) {
                            setState(() {
                              _isMarqueeSelecting = false;
                              _marqueeStart = null;
                              _marqueeCurrent = null;
                            });
                          }

                          // Tap on empty background (no significant move and did not tap/drag a note)
                          if (!_isCanvasPanning && !_isMarqueeSelecting && !wasInteractingWithNote && moveDist < 6.0 && contentPos.dx >= _gutterWidth) {
                            final now = DateTime.now();

                            if (_lastGridTapPos != null &&
                                _lastGridTapTime != null &&
                                (contentPos - _lastGridTapPos!).distance < 20.0 &&
                                now.difference(_lastGridTapTime!) < const Duration(milliseconds: 320)) {
                              // Double tap on grid -> Insert Note!
                              final rawStep = (contentPos.dx - _gutterWidth) / _stepWidth;
                              final quantizeUnit = math.min(1.0, _durationToSteps(_selectedDuration));
                              final quantizedStep = (rawStep / quantizeUnit).floor() * quantizeUnit;

                              final bool isNoteTreble = isGrandStaff ? (contentPos.dy < constraints.maxHeight * 0.58) : isTrebleStaff;
                              final staffLine1Y = _getStaffLine1Y(isTrebleStaff, isGrandStaff, constraints.maxHeight, trebleOfGrand: isNoteTreble);

                              final pitch = ScoreLayoutEngine.yToMidiPitch(
                                y: contentPos.dy,
                                staffLine1Y: staffLine1Y,
                                sp: _staffSpace,
                                isTrebleStaff: isNoteTreble,
                                forcedAccidental: _selectedAccidental,
                              );

                              _insertNoteAt(quantizedStep, pitch);
                              _lastGridTapTime = null;
                              _lastGridTapPos = null;
                            } else {
                              // Single tap on empty grid -> Deselect active notes
                              _lastGridTapTime = now;
                              _lastGridTapPos = contentPos;
                              widget.dawState.clearNoteSelection(track);
                              setState(() {});
                            }
                          }

                          _isCanvasPanning = false;
                          _pointerDownPos = null;
                          _canvasPanStartScrollOffset = null;
                        },
                        onPointerCancel: (event) {
                          _holdTimer?.cancel();
                          if (_draggedNoteId != null) {
                            widget.dawState.commitHistoryTransaction();
                            _draggedNoteId = null;
                            _noteDragStartPos = null;
                            _batchStartSteps.clear();
                            _batchStartPitches.clear();
                          }
                          if (_isMarqueeSelecting) {
                            setState(() {
                              _isMarqueeSelecting = false;
                              _marqueeStart = null;
                              _marqueeCurrent = null;
                            });
                          }
                          _isCanvasPanning = false;
                          _pointerDownPos = null;
                          _canvasPanStartScrollOffset = null;
                        },
                        child: MouseRegion(
                          cursor: _isCanvasPanning ? SystemMouseCursors.grabbing : MouseCursor.defer,
                          child: SingleChildScrollView(
                            controller: _horizontalScroll,
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              width: math.max(
                                constraints.maxWidth,
                                _gutterWidth + (_totalSteps * _stepWidth) + 96.0,
                              ),
                              height: constraints.maxHeight,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: ScoreCanvasPainter(
                                        track: track,
                                        isTrebleStaff: isTrebleStaff,
                                        isGrandStaff: isGrandStaff,
                                        stepWidth: _stepWidth,
                                        staffSpace: _staffSpace,
                                        gutterWidth: _gutterWidth,
                                        totalSteps: _totalSteps,
                                        selectedNoteIds: _selectedNoteIds,
                                        isLight: isLight,
                                        marqueeStart: _marqueeStart,
                                        marqueeCurrent: _marqueeCurrent,
                                        backgroundTracks: widget.dawState.visibleTracks
                                            .where((t) => t.id != track.id && !t.isMuted)
                                            .toList(),
                                        ghostNotesOpacity: widget.dawState.ghostNotesOpacity,
                                      ),
                                    ),
                                  ),

                                  // Real-time Playhead (Continuous Sub-Pixel Motion in scrollable space)
                                  ValueListenableBuilder<double>(
                                    valueListenable: widget.dawState.continuousArrangerStepNotifier,
                                    builder: (context, continuousStep, _) {
                                      final clip = widget.dawState.activeTrackClip;
                                      final clipStartStep = (clip.startBar * 16).toDouble();
                                      final clipEndStep = clipStartStep + _totalSteps.toDouble();
                                      if (continuousStep < clipStartStep || continuousStep > clipEndStep) {
                                        return const SizedBox.shrink();
                                      }
                                      final activeStepInClip = continuousStep - clipStartStep;
                                      final double playheadX = _gutterWidth + (activeStepInClip * _stepWidth);

                                      return Positioned(
                                        left: playheadX - 1.5,
                                        top: 0,
                                        bottom: 0,
                                        child: RepaintBoundary(
                                          child: IgnorePointer(
                                            child: Container(
                                              width: 3.0,
                                              decoration: BoxDecoration(
                                                color: EatsTheme.primaryCyan,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: EatsTheme.primaryCyan.withValues(alpha: 0.8),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Fixed Clef & Key Signature Gutter on Left
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: _gutterWidth,
                        child: RepaintBoundary(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: ScoreGutterPainter(
                                isTrebleStaff: isTrebleStaff,
                                isGrandStaff: isGrandStaff,
                                staffSpace: _staffSpace,
                                gutterWidth: _gutterWidth,
                                isLight: isLight,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Note Inspector is rendered persistently by parent EditView
                      const SizedBox.shrink(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar Widget
  // ---------------------------------------------------------------------------

  Widget _buildToolbar(bool isTrebleStaff, bool isGrandStaff, int selectedCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 960;
        final bool isVeryCompact = constraints.maxWidth < 700;

        return Container(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
          decoration: BoxDecoration(
            color: EatsTheme.panelHeader,
            border: Border(
              bottom: BorderSide(
                color: EatsTheme.isLight
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              // Clef Selector
              _buildClefButton(isTrebleStaff, isGrandStaff, isCompact: isCompact),

              SizedBox(width: isCompact ? 5 : 8),
              _buildDivider(),
              SizedBox(width: isCompact ? 5 : 8),

              // Duration Palette for Note Entry
              _buildDurationSelector(isCompact: isCompact),

              SizedBox(width: isCompact ? 5 : 8),
              _buildDivider(),
              SizedBox(width: isCompact ? 5 : 8),

              // Accidental Selector
              _buildAccidentalSelector(isCompact: isCompact),

              SizedBox(width: isCompact ? 5 : 8),
              _buildDivider(),
              SizedBox(width: isCompact ? 5 : 8),

              // Follow Playback Toggle Button
              ValueListenableBuilder<bool>(
                valueListenable: widget.dawState.isFollowPlaybackNotifier,
                builder: (context, isFollowing, _) {
                  return InkWell(
                    onTap: widget.dawState.toggleFollowPlayback,
                    borderRadius: BorderRadius.circular(4),
                    child: Tooltip(
                      message: isFollowing ? 'Follow Playhead: ON (F)' : 'Follow Playhead: OFF (F)',
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 6 : 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isFollowing
                              ? EatsTheme.primaryCyan.withValues(alpha: 0.2)
                              : EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFollowing
                                ? EatsTheme.primaryCyan
                                : (EatsTheme.isLight ? Colors.black12 : Colors.white12),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location,
                              size: 13,
                              color: isFollowing ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                            ),
                            if (!isVeryCompact) ...[
                              const SizedBox(width: 4),
                              Text(
                                'FOLLOW',
                                style: TextStyle(
                                  color: isFollowing ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Selection Count & Deselect Button
              if (selectedCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: EatsTheme.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EatsTheme.primaryCyan.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 14, color: EatsTheme.primaryCyan),
                      const SizedBox(width: 4),
                      Text(
                        '$selectedCount Selected',
                        style: TextStyle(
                          color: EatsTheme.primaryCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: EatsTheme.textMuted),
                  tooltip: 'Deselect All (Esc)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    widget.dawState.clearNoteSelection(widget.dawState.activeTrack);
                    setState(() {});
                  },
                ),
              ] else if (!isCompact) ...[
                Flexible(
                  child: Text(
                    'Drag background to pan  •  Hold & drag to multi-select  •  Double-click to add/delete',
                    style: TextStyle(
                      color: EatsTheme.textMuted,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClefButton(bool isTrebleStaff, bool isGrandStaff, {bool isCompact = false}) {
    String label;
    if (_selectedClef == ScoreClef.auto) {
      label = isCompact ? 'AUTO' : (isTrebleStaff ? 'AUTO (TREBLE)' : 'AUTO (BASS)');
    } else if (_selectedClef == ScoreClef.treble) {
      label = 'TREBLE';
    } else if (_selectedClef == ScoreClef.bass) {
      label = 'BASS';
    } else {
      label = 'GRAND';
    }

    return PopupMenuButton<ScoreClef>(
      initialValue: _selectedClef,
      tooltip: 'Select Clef',
      onSelected: (clef) {
        setState(() {
          _selectedClef = clef;
        });
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: ScoreClef.auto, child: Text('Auto (Track Pitch)')),
        PopupMenuItem(value: ScoreClef.treble, child: Text('Treble Clef (G)')),
        PopupMenuItem(value: ScoreClef.bass, child: Text('Bass Clef (F)')),
        PopupMenuItem(value: ScoreClef.grandStaff, child: Text('Grand Staff (Both)')),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10, vertical: 5),
        decoration: BoxDecoration(
          color: EatsTheme.controlBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: EatsTheme.isLight
                ? Colors.black.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTrebleStaff ? Icons.graphic_eq : Icons.straighten,
              size: 14,
              color: EatsTheme.primaryCyan,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: EatsTheme.isLight ? Colors.black87 : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: EatsTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector({bool isCompact = false}) {
    final durations = [
      (ScoreNoteType.whole, '1/1', 'Whole Note'),
      (ScoreNoteType.half, '1/2', 'Half Note'),
      (ScoreNoteType.quarter, '1/4', 'Quarter Note'),
      (ScoreNoteType.eighth, '1/8', '8th Note'),
      (ScoreNoteType.sixteenth, '1/16', '16th Note'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: durations.map((d) {
        final isSelected = _selectedDuration == d.$1;
        return Padding(
          padding: EdgeInsets.only(right: isCompact ? 2 : 3),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedDuration = d.$1;
              });
            },
            borderRadius: BorderRadius.circular(3),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? EatsTheme.primaryCyan.withValues(alpha: 0.22) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isSelected
                      ? EatsTheme.primaryCyan
                      : (EatsTheme.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Text(
                d.$2,
                style: TextStyle(
                  color: isSelected
                      ? EatsTheme.primaryCyan
                      : (EatsTheme.isLight ? Colors.black87 : Colors.white70),
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccidentalSelector({bool isCompact = false}) {
    final accidentals = [
      (ScoreAccidental.none, '♮', 'Natural'),
      (ScoreAccidental.sharp, '♯', 'Sharp'),
      (ScoreAccidental.flat, '♭', 'Flat'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: accidentals.map((a) {
        final isSelected = _selectedAccidental == a.$1;
        return Padding(
          padding: EdgeInsets.only(right: isCompact ? 2 : 3),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedAccidental = a.$1;
              });
            },
            borderRadius: BorderRadius.circular(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? EatsTheme.secondaryMagenta.withValues(alpha: 0.25) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isSelected
                      ? EatsTheme.secondaryMagenta
                      : (EatsTheme.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Text(
                a.$2,
                style: TextStyle(
                  color: isSelected
                      ? EatsTheme.secondaryMagenta
                      : (EatsTheme.isLight ? Colors.black87 : Colors.white70),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      color: EatsTheme.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.1),
    );
  }
}

// -----------------------------------------------------------------------------
// Score Canvas Painter
// -----------------------------------------------------------------------------

class ScoreCanvasPainter extends CustomPainter {
  final TrackChannel track;
  final bool isTrebleStaff;
  final bool isGrandStaff;
  final double stepWidth;
  final double staffSpace;
  final double gutterWidth;
  final int totalSteps;
  final Set<String> selectedNoteIds;
  final bool isLight;
  final Offset? marqueeStart;
  final Offset? marqueeCurrent;
  final List<TrackChannel> backgroundTracks;
  final double ghostNotesOpacity;

  ScoreCanvasPainter({
    required this.track,
    required this.isTrebleStaff,
    required this.isGrandStaff,
    required this.stepWidth,
    required this.staffSpace,
    required this.gutterWidth,
    required this.totalSteps,
    required this.selectedNoteIds,
    required this.isLight,
    this.marqueeStart,
    this.marqueeCurrent,
    this.backgroundTracks = const [],
    this.ghostNotesOpacity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double totalWidth = gutterWidth + (totalSteps * stepWidth);

    // High performance viewport culling: only draw what is inside visible clip bounds
    final clipBounds = canvas.getLocalClipBounds();
    final double visibleLeft = clipBounds.isFinite ? math.max(gutterWidth, clipBounds.left) : gutterWidth;
    final double visibleRight = clipBounds.isFinite ? math.min(totalWidth, clipBounds.right) : totalWidth;

    final double lineStartX = visibleLeft;
    final double lineEndX = visibleRight;

    final int startStep = math.max(0, ((visibleLeft - gutterWidth) / stepWidth).floor() - 2);
    final int endStep = math.min(totalSteps, ((visibleRight - gutterWidth) / stepWidth).ceil() + 2);

    final staffPaint = Paint()
      ..color = isLight
          ? const Color(0xFF2E2A25).withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final barLinePaint = Paint()
      ..color = isLight
          ? const Color(0xFF22201D).withValues(alpha: 0.60)
          : Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final beatLinePaint = Paint()
      ..color = isLight
          ? Colors.black.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (!isGrandStaff) {
      // -----------------------------------------------------------------------
      // Single Staff Mode (Treble or Bass)
      // -----------------------------------------------------------------------
      final double staffLine1Y = (size.height * 0.60).clamp(110.0, 320.0);

      // Draw 5 Staff Lines only across visible viewport
      for (int i = 0; i < 5; i++) {
        final double y = staffLine1Y - (i * staffSpace);
        canvas.drawLine(Offset(lineStartX, y), Offset(lineEndX, y), staffPaint);
      }

      // Measures & Beats culled to visible range
      for (int s = startStep; s <= endStep; s++) {
        final double x = gutterWidth + (s * stepWidth);
        final bool isBarStart = s % 16 == 0;
        final bool isBeat = s % 4 == 0;

        if (isBarStart) {
          final double topY = staffLine1Y - (4 * staffSpace);
          final double botY = staffLine1Y;
          canvas.drawLine(Offset(x, topY), Offset(x, botY), barLinePaint);

          final int barNumber = (s ~/ 16) + 1;
          final textSpan = TextSpan(
            text: '$barNumber',
            style: TextStyle(
              color: isLight ? EatsTheme.primaryCyan : EatsTheme.primaryCyan.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          );
          final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
          tp.paint(canvas, Offset(x + 4, topY - 24));
        } else if (isBeat) {
          final double topY = staffLine1Y - (4 * staffSpace);
          final double botY = staffLine1Y;
          canvas.drawLine(Offset(x, topY), Offset(x, botY), beatLinePaint);
        }
      }

      // Render Ghost Notes from Background Tracks
      if (ghostNotesOpacity > 0.0 && backgroundTracks.isNotEmpty) {
        for (final bgTrack in backgroundTracks) {
          if (bgTrack.notes.isEmpty) continue;
          _renderGhostNotes(canvas, bgTrack.notes, staffLine1Y, isTrebleStaff, visibleLeft, visibleRight, bgTrack.color, ghostNotesOpacity);
        }
      }

      // Render Notes with viewport culling
      _renderNotes(canvas, track.notes, staffLine1Y, isTrebleStaff, visibleLeft, visibleRight);
    } else {
      // -----------------------------------------------------------------------
      // Grand Staff Mode (Treble on top, Bass on bottom, like screenshot)
      // -----------------------------------------------------------------------
      final double trebleLine1Y = size.height * 0.38;
      final double bassLine1Y = size.height * 0.80;

      // Draw Treble 5 lines across visible viewport
      for (int i = 0; i < 5; i++) {
        final double y = trebleLine1Y - (i * staffSpace);
        canvas.drawLine(Offset(lineStartX, y), Offset(lineEndX, y), staffPaint);
      }
      // Draw Bass 5 lines across visible viewport
      for (int i = 0; i < 5; i++) {
        final double y = bassLine1Y - (i * staffSpace);
        canvas.drawLine(Offset(lineStartX, y), Offset(lineEndX, y), staffPaint);
      }

      // Measures & Beats spanning across the grand staff
      for (int s = startStep; s <= endStep; s++) {
        final double x = gutterWidth + (s * stepWidth);
        final bool isBarStart = s % 16 == 0;
        final bool isBeat = s % 4 == 0;

        if (isBarStart) {
          final double topY = trebleLine1Y - (4 * staffSpace);
          final double botY = bassLine1Y;
          canvas.drawLine(Offset(x, topY), Offset(x, botY), barLinePaint);

          final int barNumber = (s ~/ 16) + 1;
          final textSpan = TextSpan(
            text: '$barNumber',
            style: TextStyle(
              color: isLight ? EatsTheme.primaryCyan : EatsTheme.primaryCyan.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          );
          final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
          tp.paint(canvas, Offset(x + 4, topY - 24));
        } else if (isBeat) {
          canvas.drawLine(Offset(x, trebleLine1Y - (4 * staffSpace)), Offset(x, trebleLine1Y), beatLinePaint);
          canvas.drawLine(Offset(x, bassLine1Y - (4 * staffSpace)), Offset(x, bassLine1Y), beatLinePaint);
        }
      }

      // Partition notes by register: C4 (60) and above on Treble, below on Bass
      final trebleNotes = track.notes.where((n) => n.pitch >= 60).toList();
      final bassNotes = track.notes.where((n) => n.pitch < 60).toList();

      // Render Ghost Notes from Background Tracks
      if (ghostNotesOpacity > 0.0 && backgroundTracks.isNotEmpty) {
        for (final bgTrack in backgroundTracks) {
          if (bgTrack.notes.isEmpty) continue;
          final bgTreble = bgTrack.notes.where((n) => n.pitch >= 60).toList();
          final bgBass = bgTrack.notes.where((n) => n.pitch < 60).toList();
          _renderGhostNotes(canvas, bgTreble, trebleLine1Y, true, visibleLeft, visibleRight, bgTrack.color, ghostNotesOpacity);
          _renderGhostNotes(canvas, bgBass, bassLine1Y, false, visibleLeft, visibleRight, bgTrack.color, ghostNotesOpacity);
        }
      }

      _renderNotes(canvas, trebleNotes, trebleLine1Y, true, visibleLeft, visibleRight);
      _renderNotes(canvas, bassNotes, bassLine1Y, false, visibleLeft, visibleRight);
    }

    // -------------------------------------------------------------------------
    // Draw Marquee Selection Overlay if active
    // -------------------------------------------------------------------------
    if (marqueeStart != null && marqueeCurrent != null) {
      final rect = Rect.fromPoints(marqueeStart!, marqueeCurrent!);
      final marqueeFill = Paint()..color = EatsTheme.primaryCyan.withValues(alpha: 0.18);
      final marqueeBorder = Paint()
        ..color = EatsTheme.primaryCyan.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawRect(rect, marqueeFill);
      canvas.drawRect(rect, marqueeBorder);
    }
  }

  void _renderNotes(
    Canvas canvas,
    List<Note> notes,
    double staffLine1Y,
    bool isTrebleStaff,
    double visibleLeft,
    double visibleRight,
  ) {
    final effectiveNoteColor = isLight
        ? Color.lerp(const Color(0xFF181512), track.color, 0.35)!
        : track.color;

    final normalNotePaint = Paint()
      ..color = effectiveNoteColor
      ..style = PaintingStyle.fill;

    final selectedNotePaint = Paint()
      ..color = EatsTheme.primaryCyan
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = EatsTheme.primaryCyan.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5.0);

    final ledgerPaint = Paint()
      ..color = isLight
          ? const Color(0xFF1E1A16).withValues(alpha: 0.70)
          : Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final note in notes) {
      final double noteX = gutterWidth + (note.startStep * stepWidth);

      // High-performance Viewport Culling: Skip offscreen notes
      if (noteX + 60.0 < visibleLeft || noteX - 60.0 > visibleRight) {
        continue;
      }

      final bool isSelected = selectedNoteIds.contains(note.id);
      final visual = ScoreLayoutEngine.computeVisual(
        pitchLayout: ScoreLayoutEngine.pitchToLayout(note.pitch),
        durationSteps: note.durationSteps,
        staffLine1Y: staffLine1Y,
        sp: staffSpace,
        isTrebleStaff: isTrebleStaff,
      );

      final double noteY = visual.yPos;
      final noteCenter = Offset(noteX, noteY);
      final activePaint = isSelected ? selectedNotePaint : normalNotePaint;

      // Draw Ledger Lines
      for (final ledgerY in visual.ledgerLineYPositions) {
        ScoreVectorGlyphs.drawLedgerLine(canvas, Offset(noteX, ledgerY), staffSpace, ledgerPaint);
      }

      // Draw Accidental (Exact Bravura Bézier shapes)
      if (visual.pitchLayout.accidental == ScoreAccidental.sharp) {
        ScoreVectorGlyphs.drawSharp(canvas, Offset(noteX - staffSpace * 0.95, noteY), staffSpace, activePaint);
      } else if (visual.pitchLayout.accidental == ScoreAccidental.flat) {
        ScoreVectorGlyphs.drawFlat(canvas, Offset(noteX - staffSpace * 0.85, noteY), staffSpace, activePaint);
      } else if (visual.pitchLayout.accidental == ScoreAccidental.natural) {
        ScoreVectorGlyphs.drawNatural(canvas, Offset(noteX - staffSpace * 0.85, noteY), staffSpace, activePaint);
      }

      // Draw Glow if Selected
      if (isSelected && !isLight) {
        ScoreVectorGlyphs.drawBlackNotehead(canvas, noteCenter, staffSpace, glowPaint);
      }

      // Draw Notehead
      switch (visual.noteType) {
        case ScoreNoteType.whole:
          ScoreVectorGlyphs.drawWholeNotehead(canvas, noteCenter, staffSpace, activePaint, null);
          break;
        case ScoreNoteType.half:
          ScoreVectorGlyphs.drawHalfNotehead(canvas, noteCenter, staffSpace, activePaint, null);
          break;
        case ScoreNoteType.quarter:
        case ScoreNoteType.eighth:
        case ScoreNoteType.sixteenth:
          ScoreVectorGlyphs.drawBlackNotehead(canvas, noteCenter, staffSpace, activePaint);
          break;
      }

      // Selected ring border in Light Mode
      if (isSelected && isLight) {
        final selectBorder = Paint()
          ..color = EatsTheme.primaryCyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(noteCenter, staffSpace * 0.8, selectBorder);
      }

      // Draw Stem & Flags
      if (visual.noteType != ScoreNoteType.whole) {
        final stemTip = ScoreVectorGlyphs.drawStem(
          canvas: canvas,
          noteCenter: noteCenter,
          sp: staffSpace,
          isUp: visual.isStemUp,
          paint: activePaint,
        );

        if (visual.noteType == ScoreNoteType.eighth) {
          ScoreVectorGlyphs.drawFlag(
            canvas: canvas,
            stemTip: stemTip,
            sp: staffSpace,
            isUp: visual.isStemUp,
            flagCount: 1,
            paint: activePaint,
          );
        } else if (visual.noteType == ScoreNoteType.sixteenth) {
          ScoreVectorGlyphs.drawFlag(
            canvas: canvas,
            stemTip: stemTip,
            sp: staffSpace,
            isUp: visual.isStemUp,
            flagCount: 2,
            paint: activePaint,
          );
        }
      }

      // Draw Dot
      if (visual.isDotted) {
        canvas.drawCircle(
          Offset(noteCenter.dx + staffSpace * 0.85, noteCenter.dy),
          staffSpace * 0.16,
          activePaint,
        );
      }

      // Draw Lyrics
      if (note.lyric != null && note.lyric!.isNotEmpty) {
        final lyricSpan = TextSpan(
          text: note.lyric,
          style: TextStyle(
            color: isLight ? Colors.black87 : Colors.white,
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
          ),
        );
        final lyricTp = TextPainter(text: lyricSpan, textDirection: TextDirection.ltr)..layout();
        lyricTp.paint(canvas, Offset(noteCenter.dx - lyricTp.width / 2, staffLine1Y + staffSpace * 2.0));
      }
    }
  }

  void _renderGhostNotes(
    Canvas canvas,
    List<Note> notes,
    double staffLine1Y,
    bool isTrebleStaff,
    double visibleLeft,
    double visibleRight,
    Color trackColor,
    double opacity,
  ) {
    if (opacity <= 0.0 || notes.isEmpty) return;

    final ghostColor = isLight
        ? Color.lerp(const Color(0xFF181512), trackColor, 0.45)!.withValues(alpha: (opacity * 0.55).clamp(0.0, 1.0))
        : trackColor.withValues(alpha: (opacity * 0.55).clamp(0.0, 1.0));

    final ghostPaint = Paint()
      ..color = ghostColor
      ..style = PaintingStyle.fill;

    final ghostLedgerPaint = Paint()
      ..color = isLight
          ? const Color(0xFF1E1A16).withValues(alpha: (opacity * 0.40).clamp(0.0, 1.0))
          : Colors.white.withValues(alpha: (opacity * 0.35).clamp(0.0, 1.0))
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final note in notes) {
      final double noteX = gutterWidth + (note.startStep * stepWidth);

      // Viewport Culling: Skip offscreen notes
      if (noteX + 60.0 < visibleLeft || noteX - 60.0 > visibleRight) {
        continue;
      }

      final visual = ScoreLayoutEngine.computeVisual(
        pitchLayout: ScoreLayoutEngine.pitchToLayout(note.pitch),
        durationSteps: note.durationSteps,
        staffLine1Y: staffLine1Y,
        sp: staffSpace,
        isTrebleStaff: isTrebleStaff,
      );

      final double noteY = visual.yPos;
      final noteCenter = Offset(noteX, noteY);

      // Ledger lines
      for (final ledgerY in visual.ledgerLineYPositions) {
        ScoreVectorGlyphs.drawLedgerLine(canvas, Offset(noteX, ledgerY), staffSpace, ghostLedgerPaint);
      }

      // Accidental
      if (visual.pitchLayout.accidental == ScoreAccidental.sharp) {
        ScoreVectorGlyphs.drawSharp(canvas, Offset(noteX - staffSpace * 0.95, noteY), staffSpace, ghostPaint);
      } else if (visual.pitchLayout.accidental == ScoreAccidental.flat) {
        ScoreVectorGlyphs.drawFlat(canvas, Offset(noteX - staffSpace * 0.85, noteY), staffSpace, ghostPaint);
      } else if (visual.pitchLayout.accidental == ScoreAccidental.natural) {
        ScoreVectorGlyphs.drawNatural(canvas, Offset(noteX - staffSpace * 0.85, noteY), staffSpace, ghostPaint);
      }

      // Notehead
      switch (visual.noteType) {
        case ScoreNoteType.whole:
          ScoreVectorGlyphs.drawWholeNotehead(canvas, noteCenter, staffSpace, ghostPaint, null);
          break;
        case ScoreNoteType.half:
          ScoreVectorGlyphs.drawHalfNotehead(canvas, noteCenter, staffSpace, ghostPaint, null);
          break;
        case ScoreNoteType.quarter:
        case ScoreNoteType.eighth:
        case ScoreNoteType.sixteenth:
          ScoreVectorGlyphs.drawBlackNotehead(canvas, noteCenter, staffSpace, ghostPaint);
          break;
      }

      // Stem & Flags
      if (visual.noteType != ScoreNoteType.whole) {
        final stemTip = ScoreVectorGlyphs.drawStem(
          canvas: canvas,
          noteCenter: noteCenter,
          sp: staffSpace,
          isUp: visual.isStemUp,
          paint: ghostPaint,
        );

        if (visual.noteType == ScoreNoteType.eighth) {
          ScoreVectorGlyphs.drawFlag(
            canvas: canvas,
            stemTip: stemTip,
            sp: staffSpace,
            isUp: visual.isStemUp,
            flagCount: 1,
            paint: ghostPaint,
          );
        } else if (visual.noteType == ScoreNoteType.sixteenth) {
          ScoreVectorGlyphs.drawFlag(
            canvas: canvas,
            stemTip: stemTip,
            sp: staffSpace,
            isUp: visual.isStemUp,
            flagCount: 2,
            paint: ghostPaint,
          );
        }
      }

      // Dot
      if (visual.isDotted) {
        canvas.drawCircle(
          Offset(noteCenter.dx + staffSpace * 0.85, noteCenter.dy),
          staffSpace * 0.16,
          ghostPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScoreCanvasPainter oldDelegate) {
    return true;
  }
}

// -----------------------------------------------------------------------------
// Score Gutter Painter (Authentic Bravura SMuFL Clefs & Accolade Bracket)
// -----------------------------------------------------------------------------

class ScoreGutterPainter extends CustomPainter {
  final bool isTrebleStaff;
  final bool isGrandStaff;
  final double staffSpace;
  final double gutterWidth;
  final bool isLight;

  ScoreGutterPainter({
    required this.isTrebleStaff,
    required this.isGrandStaff,
    required this.staffSpace,
    required this.gutterWidth,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gutter Background
    final bgPaint = Paint()
      ..color = isLight ? EatsTheme.panelBackground : const Color(0xFF11151C);
    canvas.drawRect(Rect.fromLTWH(0, 0, gutterWidth, size.height), bgPaint);

    final borderPaint = Paint()
      ..color = isLight
          ? Colors.black.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(gutterWidth, 0), Offset(gutterWidth, size.height), borderPaint);

    final staffPaint = Paint()
      ..color = isLight
          ? const Color(0xFF2E2A25).withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.1;

    final clefPaint = Paint()
      ..color = isLight ? const Color(0xFF181512) : Colors.white.withValues(alpha: 0.90);

    if (!isGrandStaff) {
      // -----------------------------------------------------------------------
      // Single Staff Gutter
      // -----------------------------------------------------------------------
      final double staffLine1Y = (size.height * 0.60).clamp(110.0, 320.0);

      for (int i = 0; i < 5; i++) {
        final double y = staffLine1Y - (i * staffSpace);
        canvas.drawLine(Offset(10, y), Offset(gutterWidth, y), staffPaint);
      }

      const double clefX = 22.0;
      if (isTrebleStaff) {
        final double gLineY = staffLine1Y - (1 * staffSpace);
        ScoreVectorGlyphs.drawTrebleClef(canvas, clefX, gLineY, staffSpace, clefPaint);
      } else {
        final double fLineY = staffLine1Y - (3 * staffSpace);
        ScoreVectorGlyphs.drawBassClef(canvas, clefX, fLineY, staffSpace, clefPaint);
      }

      // Time Signature
      _drawTimeSignature(canvas, 64.0, staffLine1Y);
    } else {
      // -----------------------------------------------------------------------
      // Grand Staff Gutter (Grand Staff Brace + Treble & Bass Clefs)
      // -----------------------------------------------------------------------
      final double trebleLine1Y = size.height * 0.38;
      final double bassLine1Y = size.height * 0.80;
      final double trebleLine5Y = trebleLine1Y - (4 * staffSpace);

      // 1. Classical Curly Grand Staff Bracket / Accolade (Bravura uniE000)
      ScoreVectorGlyphs.drawGrandStaffBracket(
        canvas,
        8.0,
        trebleLine5Y,
        bassLine1Y,
        staffSpace,
        clefPaint,
      );

      // Staff lines inside gutter start after bracket connector bar
      const double linesStartX = 26.0;
      for (int i = 0; i < 5; i++) {
        final double y = trebleLine1Y - (i * staffSpace);
        canvas.drawLine(Offset(linesStartX, y), Offset(gutterWidth, y), staffPaint);
      }
      for (int i = 0; i < 5; i++) {
        final double y = bassLine1Y - (i * staffSpace);
        canvas.drawLine(Offset(linesStartX, y), Offset(gutterWidth, y), staffPaint);
      }

      // 2. Classical Treble Clef on top staff (Bravura uniE050)
      ScoreVectorGlyphs.drawTrebleClef(
        canvas,
        32.0,
        trebleLine1Y - (1 * staffSpace),
        staffSpace,
        clefPaint,
      );

      // 3. Classical Bass Clef on bottom staff (Bravura uniE062)
      ScoreVectorGlyphs.drawBassClef(
        canvas,
        30.0,
        bassLine1Y - (3 * staffSpace),
        staffSpace,
        clefPaint,
      );

      // 4. Time Signatures
      _drawTimeSignature(canvas, 68.0, trebleLine1Y);
      _drawTimeSignature(canvas, 68.0, bassLine1Y);
    }
  }

  void _drawTimeSignature(Canvas canvas, double x, double staffLine1Y) {
    final timeSigColor = isLight ? const Color(0xFF181512) : Colors.white.withValues(alpha: 0.85);

    final timeSigTopSpan = TextSpan(
      text: '4',
      style: TextStyle(
        color: timeSigColor,
        fontSize: staffSpace * 1.8,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );
    final tpTop = TextPainter(text: timeSigTopSpan, textDirection: TextDirection.ltr)..layout();
    tpTop.paint(canvas, Offset(x, staffLine1Y - staffSpace * 3.8));

    final timeSigBotSpan = TextSpan(
      text: '4',
      style: TextStyle(
        color: timeSigColor,
        fontSize: staffSpace * 1.8,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );
    final tpBot = TextPainter(text: timeSigBotSpan, textDirection: TextDirection.ltr)..layout();
    tpBot.paint(canvas, Offset(x, staffLine1Y - staffSpace * 1.9));
  }

  @override
  bool shouldRepaint(covariant ScoreGutterPainter oldDelegate) {
    return oldDelegate.isTrebleStaff != isTrebleStaff ||
        oldDelegate.isGrandStaff != isGrandStaff ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.isLight != isLight;
  }
}
