import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chord_model.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/track_properties_dialog.dart';

class SequenceEditorView extends StatefulWidget {
  final DawState dawState;
  final void Function(TrackChannel track)? onOpenTrackProperties;
  final void Function(TrackChannel track, TrackClip clip)? onOpenClipProperties;

  const SequenceEditorView({
    super.key,
    required this.dawState,
    this.onOpenTrackProperties,
    this.onOpenClipProperties,
  });

  @override
  State<SequenceEditorView> createState() => _SequenceEditorViewState();
}

class _SequenceEditorViewState extends State<SequenceEditorView> {
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const double rowHeight = 28.0;
  static const double posColumnWidth = 110.0;
  static const double trackColWidth = 100.0;

  bool _followPlayback = true;
  int _lastFollowBar = -1;

  // 2-digit Hex input buffer for rapid keyboard entry
  String _hexBuffer = '';
  Timer? _hexBufferTimer;

  DateTime? _lastTapTime;
  String? _lastTapKey;

  @override
  void initState() {
    super.initState();
    widget.dawState.addListener(_onDawStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _scrollToSelectedBar(animate: false);
      }
    });
  }

  @override
  void dispose() {
    widget.dawState.removeListener(_onDawStateChanged);
    _hexBufferTimer?.cancel();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDawStateChanged() {
    if (!mounted) return;

    if (_followPlayback && widget.dawState.isPlaying) {
      final currentBar = (widget.dawState.arrangerStep / 16.0).floor();
      if (currentBar != _lastFollowBar && _verticalScroll.hasClients) {
        _lastFollowBar = currentBar;
        final viewportH = _verticalScroll.position.viewportDimension;
        final targetOffset = (currentBar * rowHeight) - (viewportH / 2.0) + (rowHeight / 2.0);
        _verticalScroll.jumpTo(targetOffset.clamp(0.0, _verticalScroll.position.maxScrollExtent));
      }
    }
    setState(() {});
  }

  void _scrollToSelectedBar({bool animate = true}) {
    if (!_verticalScroll.hasClients) return;
    final targetOffset = (widget.dawState.sequenceSelectedBar * rowHeight) - 100.0;
    final maxScroll = _verticalScroll.position.maxScrollExtent;
    final clamped = targetOffset.clamp(0.0, maxScroll);

    if (animate) {
      _verticalScroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else {
      _verticalScroll.jumpTo(clamped);
    }
  }

  void _scrollToSelectedTrack() {
    if (!_horizontalScroll.hasClients) return;
    final targetOffset = widget.dawState.sequenceSelectedTrackIndex * (trackColWidth + 2.0);
    final currentOffset = _horizontalScroll.offset;
    final viewportW = _horizontalScroll.position.viewportDimension - posColumnWidth;

    if (targetOffset < currentOffset || targetOffset > (currentOffset + viewportW - trackColWidth)) {
      _horizontalScroll.animateTo(
        targetOffset.clamp(0.0, _horizontalScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleCellTap(int bar, int trackIdx) {
    _focusNode.requestFocus();
    widget.dawState.selectSequenceCell(bar, trackIdx);
    widget.dawState.seekToBar(bar);

    final visibleTracks = widget.dawState.visibleTracks;
    if (trackIdx >= 0 && trackIdx < visibleTracks.length) {
      final trk = visibleTracks[trackIdx];
      final allIdx = widget.dawState.activePattern.tracks.indexOf(trk);
      if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
      final clip = widget.dawState.getClipAtBar(trk, bar);
      widget.dawState.selectClip(clip);
    }

    final now = DateTime.now();
    final cellKey = '${bar}_$trackIdx';
    if (_lastTapTime != null && _lastTapKey == cellKey && now.difference(_lastTapTime!).inMilliseconds < 320) {
      if (trackIdx >= 0 && trackIdx < visibleTracks.length) {
        widget.dawState.openSequenceCellInEditor(visibleTracks[trackIdx], bar);
      }
      _lastTapTime = null;
      _lastTapKey = null;
    } else {
      _lastTapTime = now;
      _lastTapKey = cellKey;
    }
    setState(() {});
  }

  void _handleTrackHeaderSecondaryTap(TrackChannel track) {
    _focusNode.requestFocus();
    final allIdx = widget.dawState.activePattern.tracks.indexOf(track);
    if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
    widget.dawState.selectClip(null);

    if (widget.onOpenTrackProperties != null) {
      widget.onOpenTrackProperties!(track);
    } else {
      showTrackPropertiesDialog(context, widget.dawState, track);
    }
    setState(() {});
  }

  void _handleCellSecondaryTap(int bar, int trackIdx, TrackChannel track, TrackClip? clip) {
    _focusNode.requestFocus();
    widget.dawState.selectSequenceCell(bar, trackIdx);
    widget.dawState.seekToBar(bar);

    final allIdx = widget.dawState.activePattern.tracks.indexOf(track);
    if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;

    if (clip != null) {
      widget.dawState.selectClip(clip);
      if (widget.onOpenClipProperties != null) {
        widget.onOpenClipProperties!(track, clip);
      } else {
        showTrackPropertiesDialog(context, widget.dawState, track);
      }
    } else {
      widget.dawState.selectClip(null);
      if (widget.onOpenTrackProperties != null) {
        widget.onOpenTrackProperties!(track);
      } else {
        showTrackPropertiesDialog(context, widget.dawState, track);
      }
    }
    setState(() {});
  }

  void _processHexDigit(String char) {
    final hexChar = char.toUpperCase();
    _hexBufferTimer?.cancel();
    _hexBuffer += hexChar;

    final visibleTracks = widget.dawState.visibleTracks;
    final selTrackIdx = widget.dawState.sequenceSelectedTrackIndex;
    final selBar = widget.dawState.sequenceSelectedBar;

    if (selTrackIdx >= 0 && selTrackIdx < visibleTracks.length) {
      final track = visibleTracks[selTrackIdx];
      if (_hexBuffer.length >= 2) {
        final val = int.tryParse(_hexBuffer, radix: 16) ?? 0;
        widget.dawState.setPatternIndexAtBar(track, selBar, val);
        _hexBuffer = '';
        // Auto-advance cursor down 1 bar like tracker pattern entry
        widget.dawState.selectSequenceCell(selBar + 1, selTrackIdx);
        _scrollToSelectedBar();
      } else {
        // Set single digit preview / pattern index immediately
        final val = int.tryParse(_hexBuffer, radix: 16) ?? 0;
        widget.dawState.setPatternIndexAtBar(track, selBar, val);
        _hexBufferTimer = Timer(const Duration(milliseconds: 900), () {
          _hexBuffer = '';
          if (mounted) setState(() {});
        });
      }
    }
    setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    final totalBars = widget.dawState.totalTimelineBars;
    final visibleTracks = widget.dawState.visibleTracks;
    final totalTracks = visibleTracks.length;
    if (totalTracks == 0) return KeyEventResult.ignored;

    final curBar = widget.dawState.sequenceSelectedBar;
    final curTrack = widget.dawState.sequenceSelectedTrackIndex;

    // Tab -> Toggle between Timeline and Sequence
    if (key == LogicalKeyboardKey.tab) {
      widget.dawState.toggleArrangerViewMode();
      return KeyEventResult.handled;
    }

    // Navigation Keys
    if (key == LogicalKeyboardKey.arrowUp) {
      final newBar = (curBar - 1).clamp(0, totalBars - 1);
      widget.dawState.selectSequenceCell(newBar, curTrack);
      _scrollToSelectedBar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final newBar = (curBar + 1).clamp(0, totalBars - 1);
      widget.dawState.selectSequenceCell(newBar, curTrack);
      _scrollToSelectedBar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      final newTrack = (curTrack - 1).clamp(0, totalTracks - 1);
      widget.dawState.selectSequenceCell(curBar, newTrack);
      _scrollToSelectedTrack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final newTrack = (curTrack + 1).clamp(0, totalTracks - 1);
      widget.dawState.selectSequenceCell(curBar, newTrack);
      _scrollToSelectedTrack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      final newBar = (curBar - 4).clamp(0, totalBars - 1);
      widget.dawState.selectSequenceCell(newBar, curTrack);
      _scrollToSelectedBar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      final newBar = (curBar + 4).clamp(0, totalBars - 1);
      widget.dawState.selectSequenceCell(newBar, curTrack);
      _scrollToSelectedBar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      widget.dawState.selectSequenceCell(0, curTrack);
      _scrollToSelectedBar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      widget.dawState.selectSequenceCell(totalBars - 1, curTrack);
      _scrollToSelectedBar();
      return KeyEventResult.handled;
    }

    // Spacebar -> Toggle Playback
    if (key == LogicalKeyboardKey.space) {
      widget.dawState.togglePlay();
      return KeyEventResult.handled;
    }

    // Enter -> Open cell in EDIT > Tracker
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (curTrack >= 0 && curTrack < totalTracks) {
        widget.dawState.openSequenceCellInEditor(visibleTracks[curTrack], curBar);
      }
      return KeyEventResult.handled;
    }

    // Delete / Backspace / Period -> Clear Pattern Cell
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.period) {
      if (isCtrl && key == LogicalKeyboardKey.delete) {
        // Ctrl+Del -> Delete whole row across all tracks
        widget.dawState.deleteBarRow(curBar);
      } else {
        if (curTrack >= 0 && curTrack < totalTracks) {
          widget.dawState.deleteClipAtBar(visibleTracks[curTrack], curBar);
        }
      }
      return KeyEventResult.handled;
    }

    // Insert Key -> Insert Bar Row across all tracks
    if (key == LogicalKeyboardKey.insert) {
      widget.dawState.insertBarRow(curBar);
      return KeyEventResult.handled;
    }

    // Ctrl+D -> Duplicate / Clone Pattern into unique index
    if (isCtrl && key == LogicalKeyboardKey.keyD) {
      if (curTrack >= 0 && curTrack < totalTracks) {
        widget.dawState.duplicatePatternAtBar(visibleTracks[curTrack], curBar);
      }
      return KeyEventResult.handled;
    }

    // Plus / Equals -> Increment Pattern Index
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add) {
      if (curTrack >= 0 && curTrack < totalTracks) {
        final trk = visibleTracks[curTrack];
        final clip = widget.dawState.getClipAtBar(trk, curBar);
        final nextIdx = clip != null ? (clip.patternIndex + 1).clamp(0, 255) : 0;
        widget.dawState.setPatternIndexAtBar(trk, curBar, nextIdx);
      }
      return KeyEventResult.handled;
    }

    // Minus -> Decrement Pattern Index
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      if (curTrack >= 0 && curTrack < totalTracks) {
        final trk = visibleTracks[curTrack];
        final clip = widget.dawState.getClipAtBar(trk, curBar);
        final nextIdx = clip != null ? (clip.patternIndex - 1).clamp(0, 255) : 0;
        widget.dawState.setPatternIndexAtBar(trk, curBar, nextIdx);
      }
      return KeyEventResult.handled;
    }

    // Hex Digit Keys: 0-9
    const digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    for (int i = 0; i < digits.length; i++) {
      if (key == digits[i]) {
        _processHexDigit('${i % 10}');
        return KeyEventResult.handled;
      }
    }

    // Hex Alpha Keys: A-F
    final hexLetters = {
      LogicalKeyboardKey.keyA: 'A',
      LogicalKeyboardKey.keyB: 'B',
      LogicalKeyboardKey.keyC: 'C',
      LogicalKeyboardKey.keyD: 'D',
      LogicalKeyboardKey.keyE: 'E',
      LogicalKeyboardKey.keyF: 'F',
    };
    if (hexLetters.containsKey(key)) {
      _processHexDigit(hexLetters[key]!);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final totalBars = widget.dawState.totalTimelineBars;
    final visibleTracks = widget.dawState.visibleTracks;
    final totalTracks = visibleTracks.length;
    final currentPlayheadBar = (widget.dawState.arrangerStep / 16.0).floor();
    final isPlaying = widget.dawState.isPlaying;

    final selBar = widget.dawState.sequenceSelectedBar;
    final selTrack = widget.dawState.sequenceSelectedTrackIndex;

    final double gridWidth = posColumnWidth + (totalTracks * (trackColWidth + 2.0));

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          // Sub-bar control & shortcut helper ribbon
          Container(
            height: 28,
            color: EatsTheme.controlBackground,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Row(
                  children: [
                    Icon(Icons.view_module, size: 14, color: EatsTheme.primaryCyan),
                    const SizedBox(width: 6),
                    Text(
                      'SEQUENCE EDITOR',
                      style: TextStyle(
                        color: EatsTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: EatsTheme.panelHeader,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'BAR ${selBar.toRadixString(16).padLeft(2, '0').toUpperCase()} (${selBar + 1}) | TRK ${selTrack + 1}/$totalTracks',
                        style: TextStyle(color: EatsTheme.accentGold, fontSize: 9.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_hexBuffer.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: EatsTheme.primaryCyan.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: EatsTheme.primaryCyan),
                        ),
                        child: Text(
                          'INPUT: ${_hexBuffer}_',
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 9.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isWide) ...[
                      Flexible(
                        child: Text(
                          '0-9/A-F: Pattern | Enter: Edit | Del: Clear | Space: Play',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: EatsTheme.textMuted, fontSize: 8.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    InkWell(
                      onTap: () => setState(() => _followPlayback = !_followPlayback),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _followPlayback ? Icons.gps_fixed : Icons.gps_not_fixed,
                            size: 13,
                            color: _followPlayback ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'FOLLOW',
                            style: TextStyle(
                              color: _followPlayback ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Scrollable Track Headers and Synchronized Grid
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  children: [
                    // Column Track Header Row
                    Container(
                      height: 32,
                      color: EatsTheme.panelHeader,
                      child: Row(
                        children: [
                          // Left POS Header
                          Container(
                            width: posColumnWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: Colors.white12, width: 1)),
                            ),
                            child: Text(
                              'BAR / CHORD',
                              style: TextStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),

                          // Track Columns
                          ...List.generate(totalTracks, (tIdx) {
                            final trk = visibleTracks[tIdx];
                            final isCurCol = selTrack == tIdx;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final allIdx = widget.dawState.activePattern.tracks.indexOf(trk);
                                if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
                                widget.dawState.selectClip(null);
                                widget.dawState.selectSequenceCell(selBar, tIdx);
                              },
                              onSecondaryTap: () => _handleTrackHeaderSecondaryTap(trk),
                              child: Container(
                                width: trackColWidth,
                                margin: const EdgeInsets.only(right: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCurCol ? trk.color.withOpacity(0.2) : EatsTheme.backgroundDark,
                                  border: Border(
                                    bottom: BorderSide(color: isCurCol ? trk.color : Colors.white12, width: 1.5),
                                    right: const BorderSide(color: Colors.white10, width: 1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: trk.color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${tIdx.toRadixString(16).padLeft(2, '0').toUpperCase()}:${trk.name}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isCurCol ? Colors.white : EatsTheme.textSecondary,
                                              fontSize: 9,
                                              fontWeight: isCurCol ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (trk.isMuted)
                                      const Text('M', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold))
                                    else if (trk.isSoloed)
                                      const Text('S', style: TextStyle(color: EatsTheme.accentGold, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Vertical Bars Matrix (Virtualized ListView)
                    Expanded(
                      child: ListView.builder(
                        controller: _verticalScroll,
                        itemCount: totalBars,
                        itemExtent: rowHeight,
                        itemBuilder: (context, barIdx) {
                          final isPlayheadRow = isPlaying && currentPlayheadBar == barIdx;
                          final isBeatAccent = barIdx % 4 == 0;
                          final isSectionAccent = barIdx % 16 == 0;
                          final chordAtBar = widget.dawState.getActiveChordAtBar(barIdx);

                          Color rowBg = Colors.transparent;
                          if (isPlayheadRow) {
                            rowBg = EatsTheme.primaryCyan.withOpacity(0.18);
                          } else if (isSectionAccent) {
                            rowBg = Colors.white.withOpacity(0.04);
                          } else if (isBeatAccent) {
                            rowBg = Colors.white.withOpacity(0.015);
                          }

                          return Container(
                            height: rowHeight,
                            color: rowBg,
                            child: Row(
                              children: [
                                // Left POS / Chord Indicator
                                InkWell(
                                  onTap: () {
                                    widget.dawState.selectSequenceCell(barIdx, selTrack);
                                    widget.dawState.seekToBar(barIdx);
                                  },
                                  child: Container(
                                    width: posColumnWidth,
                                    height: rowHeight,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: isPlayheadRow
                                          ? EatsTheme.primaryCyan.withOpacity(0.25)
                                          : (isBeatAccent ? EatsTheme.panelHeader.withOpacity(0.6) : Colors.black12),
                                      border: Border(
                                        right: const BorderSide(color: Colors.white12, width: 1),
                                        bottom: BorderSide(color: Colors.white.withOpacity(0.03), width: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          barIdx.toRadixString(16).padLeft(2, '0').toUpperCase(),
                                          style: TextStyle(
                                            color: isPlayheadRow
                                                ? EatsTheme.primaryCyan
                                                : (isBeatAccent ? EatsTheme.accentGold : EatsTheme.textSecondary),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${barIdx + 1}',
                                          style: TextStyle(
                                            color: EatsTheme.textMuted,
                                            fontSize: 8.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (chordAtBar != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: EatsTheme.secondaryMagenta.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: Text(
                                              chordAtBar.displayName,
                                              style: TextStyle(
                                                color: EatsTheme.secondaryMagenta,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Matrix Track Cells
                                ...List.generate(totalTracks, (tIdx) {
                                  final trk = visibleTracks[tIdx];
                                  final isCellSelected = selBar == barIdx && selTrack == tIdx;
                                  final clip = widget.dawState.getClipAtBar(trk, barIdx);

                                  final bool isClipStart = clip != null && clip.startBar == barIdx;
                                  final bool isClipSustain = clip != null && clip.startBar < barIdx;

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _handleCellTap(barIdx, tIdx),
                                    onSecondaryTap: () => _handleCellSecondaryTap(barIdx, tIdx, trk, clip),
                                    child: Container(
                                      width: trackColWidth,
                                      height: rowHeight,
                                      margin: const EdgeInsets.only(right: 2),
                                      decoration: BoxDecoration(
                                        color: isCellSelected
                                            ? EatsTheme.primaryCyan.withOpacity(0.14)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isCellSelected
                                              ? EatsTheme.primaryCyan
                                              : (isPlayheadRow ? EatsTheme.primaryCyan.withOpacity(0.3) : Colors.white.withOpacity(0.04)),
                                          width: isCellSelected ? 1.5 : 0.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: _buildCellContent(trk, clip, isClipStart, isClipSustain, isCellSelected),
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
        ],
      ),
    );
  }

  Widget _buildCellContent(
    TrackChannel track,
    TrackClip? clip,
    bool isClipStart,
    bool isClipSustain,
    bool isSelected,
  ) {
    if (clip == null) {
      // Empty Silence cell
      return Text(
        '··',
        style: TextStyle(
          color: isSelected ? EatsTheme.primaryCyan : Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
    }

    if (isClipStart) {
      // Hex Pattern Header Block
      final hex = clip.patternHex;
      return Container(
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: track.color.withOpacity(0.22),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: track.color.withOpacity(0.85), width: 1),
          boxShadow: [
            BoxShadow(
              color: track.color.withOpacity(0.2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hex,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
            if (clip.name.isNotEmpty && !clip.name.startsWith('P$hex')) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  clip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: track.color,
                    fontSize: 8.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Sustained continuation line across multi-bar clip
    return Center(
      child: Container(
        width: 2,
        height: rowHeight,
        color: track.color.withOpacity(0.4),
      ),
    );
  }
}
