import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/sampler_engine.dart';
import '../lua/lua_preset_library.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../models/chord_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/arranger_context_inspector.dart';
import 'widgets/circle_of_fifths_dialog.dart';
import 'widgets/eatsbeats_slider.dart';
import 'widgets/fx_rack_dialog.dart';
import 'widgets/preset_search_dialog.dart';
import 'widgets/project_browser_drawer.dart';
import 'widgets/skeuomorphic_hardware_button.dart';
import 'widgets/skeuomorphic_hardware_knob.dart';
import 'sequence_editor_view.dart';

class ArrangerView extends StatefulWidget {
  final DawState dawState;

  const ArrangerView({super.key, required this.dawState});

  @override
  State<ArrangerView> createState() => _ArrangerViewState();
}

class _ArrangerViewState extends State<ArrangerView> {
  static const double barWidth = 60.0;
  static const double trackRowHeight = 82.0;
  int get totalBars => widget.dawState.totalTimelineBars;

  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _leftTrackScroll = ScrollController();
  final ScrollController _rightGridScroll = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSyncingScroll = false;
  bool _isMiddleMouseDragging = false;
  bool _isPropertiesExpanded = false;
  static const double _kMinPropertiesWidth = 290.0;
  static const double _kDefaultPropertiesWidth = _kMinPropertiesWidth;
  static const double _kMaxPropertiesWidth = 720.0;
  static const double _kPropertiesPullTabWidth = 24.0;
  double _propertiesWidth = _kDefaultPropertiesWidth;
  double _lastDragX = 0.0;

  DateTime? _lastHeaderTapTime;
  int? _lastHeaderTapTrackIdx;
  DateTime? _lastClipTapTime;
  String? _lastClipTapId;

  double _moveDragDxAccumulator = 0.0;
  double _moveDragDyAccumulator = 0.0;
  double _resizeDragDxAccumulator = 0.0;
  double _loopResizeDragDxAccumulator = 0.0;
  int? _initialLoopPointOnDrag;
  int? _dragSourceTrackIdx;
  int? _dragHoverTrackIdx;
  TrackClip? _draggedClip;
  TrackChannel? _draggedClipSourceTrack;
  double _chordMoveDragDxAccumulator = 0.0;
  double _chordResizeDragDxAccumulator = 0.0;
  int? _dragLoopStartBar;

  @override
  void initState() {
    super.initState();
    widget.dawState.addListener(_onDawStateChanged);
  }

  void _onDawStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ArrangerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dawState != widget.dawState) {
      oldWidget.dawState.removeListener(_onDawStateChanged);
      widget.dawState.addListener(_onDawStateChanged);
    }
  }

  @override
  void dispose() {
    widget.dawState.removeListener(_onDawStateChanged);
    _horizontalScroll.dispose();
    _leftTrackScroll.dispose();
    _rightGridScroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.dawState.visibleTracks;
    final double playheadX = (widget.dawState.arrangerStep / 16.0) * barWidth;
    final double loopStartX = widget.dawState.loopStartBar * barWidth;
    final double loopWidth = (widget.dawState.loopEndBar - widget.dawState.loopStartBar) * barWidth;
    final bool isBrowserOpen = widget.dawState.isBrowserOpen;
    final double drawerWidth = _isPropertiesExpanded
        ? _kPropertiesPullTabWidth + _propertiesWidth
        : _kPropertiesPullTabWidth;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
          setState(() {
            widget.dawState.toggleArrangerViewMode();
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          // Main Multitrack Arranger Content (Timeline & Track Panels)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.fastOutSlowIn,
            top: 0,
            bottom: 0,
            left: 0,
            right: (isBrowserOpen ? 320.0 : 0.0) + drawerWidth,
            child: Column(
              children: [
                _buildArrangerHeader(),
                Expanded(
                  child: widget.dawState.arrangerViewMode == ArrangerViewMode.sequence
                      ? SequenceEditorView(
                          dawState: widget.dawState,
                          onOpenTrackProperties: (track) {
                            setState(() {
                              _isPropertiesExpanded = true;
                              final allIdx = widget.dawState.activePattern.tracks.indexOf(track);
                              if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
                              widget.dawState.selectClip(null);
                            });
                          },
                          onOpenClipProperties: (track, clip) {
                            setState(() {
                              _isPropertiesExpanded = true;
                              final allIdx = widget.dawState.activePattern.tracks.indexOf(track);
                              if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
                              widget.dawState.selectClip(clip);
                            });
                          },
                        )
                      : Row(
                          children: [
              // Left Panel: Vertical Track Control Strips (Synced Scroll)
                      SizedBox(
                        width: 210,
                        child: Column(
                          children: [
                    // Top Left Track Header & Loop Toggle Button
                    Container(
                      height: 24,
                      color: EatsTheme.panelHeader,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          Text('TRACKS', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          InkWell(
                            onTap: widget.dawState.toggleLoop,
                            child: Tooltip(
                              message: 'Toggle Loop Mode',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    size: 13,
                                    color: widget.dawState.isLooping ? EatsTheme.accentGold : EatsTheme.textMuted,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.dawState.isLooping ? 'LOOP' : 'OFF',
                                    style: TextStyle(
                                      color: widget.dawState.isLooping ? EatsTheme.accentGold : EatsTheme.textMuted,
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
                    // Chord Track Left Control Strip (Height 28)
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: EatsTheme.panelHeader.withOpacity(0.9),
                        border: Border(
                          bottom: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.3), width: 1),
                          left: const BorderSide(color: EatsTheme.accentGold, width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.queue_music, size: 12, color: EatsTheme.accentGold),
                          const SizedBox(width: 4),
                          Text(
                            'CHORDS',
                            style: EatsTheme.getPrimaryFontStyle(
                              color: EatsTheme.accentGold,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Song Key Selector Button
                          PopupMenuButton<String>(
                            tooltip: 'Song Key: ${widget.dawState.songKey}',
                            color: EatsTheme.controlBackground,
                            padding: EdgeInsets.zero,
                            popUpAnimationStyle: const AnimationStyle(
                              duration: Duration(milliseconds: 100),
                              curve: Curves.fastOutSlowIn,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: EatsTheme.controlBackground,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: EatsTheme.accentGold.withOpacity(0.5), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.dawState.songKey.replaceAll(' Major', '').replaceAll(' Minor', 'm'),
                                    style: const TextStyle(color: EatsTheme.accentGold, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 10, color: EatsTheme.accentGold),
                                ],
                              ),
                            ),
                            itemBuilder: (context) {
                              const keys = [
                                'C Major', 'G Major', 'D Major', 'A Major', 'E Major', 'B Major', 'F# Major', 'Db Major', 'Ab Major', 'Eb Major', 'Bb Major', 'F Major',
                                'A Minor', 'E Minor', 'B Minor', 'F# Minor', 'C# Minor', 'G# Minor', 'D# Minor', 'Bb Minor', 'F Minor', 'C Minor', 'G Minor', 'D Minor',
                              ];
                              return keys.map((k) => PopupMenuItem(value: k, child: Text(k, style: TextStyle(fontSize: 11, color: EatsTheme.textPrimary)))).toList();
                            },
                            onSelected: (k) => widget.dawState.setSongKey(k),
                          ),
                          const SizedBox(width: 4),
                          // Chords Dialog Button
                          InkWell(
                            onTap: () {
                              final curBar = (widget.dawState.arrangerStep ~/ 16).clamp(0, totalBars - 1);
                              final existing = widget.dawState.getActiveChordAtBar(curBar);
                              CircleOfFifthsDialog.show(context, dawState: widget.dawState, targetBar: curBar, initialChord: existing);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: EatsTheme.primaryCyan.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5), width: 0.8),
                              ),
                              child: Tooltip(
                                message: 'Chords',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.album_outlined, size: 11, color: EatsTheme.primaryCyan),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Chords',
                                      style: TextStyle(
                                        color: EatsTheme.primaryCyan,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
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
                    Expanded(
                      child: DragTarget<Object>(
                        onWillAcceptWithDetails: (details) {
                          final data = details.data;
                          if (data is SoundFontDragItem) return true;
                          if (data is LuaPreset) return data.isInstrument;
                          return false;
                        },
                        onAcceptWithDetails: (details) {
                          final data = details.data;
                          if (data is SoundFontDragItem) {
                            widget.dawState.addNewSoundFontTrack(data.fontId, displayName: data.displayName);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Created new track with SoundFont "${data.displayName}"'),
                                backgroundColor: EatsTheme.panelHeader,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else if (data is LuaPreset && data.isInstrument) {
                            widget.dawState.addNewPresetTrack(data);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Created new track with instrument "${data.name}"'),
                                backgroundColor: EatsTheme.panelHeader,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHoveringEmpty = candidateData.isNotEmpty;

                          return Container(
                            color: isHoveringEmpty ? EatsTheme.primaryCyan.withOpacity(0.15) : Colors.transparent,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (!_isSyncingScroll && notification is ScrollUpdateNotification) {
                                  _isSyncingScroll = true;
                                  if (_rightGridScroll.hasClients) {
                                    _rightGridScroll.jumpTo(_leftTrackScroll.offset);
                                  }
                                  _isSyncingScroll = false;
                                }
                                return false;
                              },
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                controller: _leftTrackScroll,
                                itemCount: tracks.length + 1,
                                itemBuilder: (context, trackIdx) {
                                  if (trackIdx == tracks.length) {
                                    return DragTarget<Object>(
                                      onWillAcceptWithDetails: (details) {
                                        final data = details.data;
                                        if (data is SoundFontDragItem) return true;
                                        if (data is LuaPreset) return data.isInstrument;
                                        return false;
                                      },
                                      onAcceptWithDetails: (details) {
                                        final data = details.data;
                                        if (data is SoundFontDragItem) {
                                          widget.dawState.addNewSoundFontTrack(data.fontId, displayName: data.displayName);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Created new track with SoundFont "${data.displayName}"'),
                                              backgroundColor: EatsTheme.panelHeader,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        } else if (data is LuaPreset && data.isInstrument) {
                                          widget.dawState.addNewPresetTrack(data);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Created new track with instrument "${data.name}"'),
                                              backgroundColor: EatsTheme.panelHeader,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      builder: (context, hoverData, _) {
                                        final isHover = hoverData.isNotEmpty;
                                        return Container(
                                          height: 44,
                                          margin: const EdgeInsets.only(top: 4, bottom: 28),
                                          decoration: BoxDecoration(
                                            color: isHover
                                                ? EatsTheme.primaryCyan.withOpacity(0.2)
                                                : EatsTheme.controlBackground.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isHover ? EatsTheme.primaryCyan : EatsTheme.panelHeader,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () => PresetSearchDialog.showAddTrack(
                                              context,
                                              dawState: widget.dawState,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '+ ADD',
                                                style: TextStyle(
                                                  color: isHover ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }

                                  final track = tracks[trackIdx];
                                  final allIdx = widget.dawState.activePattern.tracks.indexOf(track);
                                  final isSelected = widget.dawState.activeTrack.id == track.id;

                                  return DragTarget<Object>(
                                    onWillAcceptWithDetails: (details) {
                                      final data = details.data;
                                      if (data is TrackChannel) return data.id != track.id;
                                      if (data is SoundFontDragItem) return true;
                                      if (data is LuaPreset) {
                                        return data.isInstrument || data.isAudioFx || data.isMidiFx;
                                      }
                                      return false;
                                    },
                                    onAcceptWithDetails: (details) {
                                      final data = details.data;
                                      if (data is TrackChannel) {
                                        if (track.isFolder && !data.isFolder) {
                                          widget.dawState.setTrackFolder(data.id, track.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Added "' + data.name + '" to folder "' + track.name + '"'),
                                              backgroundColor: EatsTheme.panelHeader,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        } else {
                                       final oldIdx = widget.dawState.activePattern.tracks.indexOf(data);
                                       final newIdx = allIdx != -1 ? allIdx : trackIdx;
                                       if (oldIdx != -1 && oldIdx != newIdx) {
                                         widget.dawState.reorderTracks(oldIdx, newIdx);
                                       }
                                     }
                                   } else if (data is SoundFontDragItem) {
                                     widget.dawState.applySoundFont(data.fontId, displayName: data.displayName, targetTrack: track);
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                         content: Text('Switched SoundFont on ${track.name} to "${data.displayName}"'),
                                         backgroundColor: EatsTheme.panelHeader,
                                         duration: const Duration(seconds: 2),
                                       ),
                                     );
                                   } else if (data is LuaPreset) {
                                     final preset = data;
                                     widget.dawState.applyPreset(preset, targetTrack: track);
                                     String msg = 'Applied preset "${preset.name}" to ${track.name}';
                                     if (preset.isInstrument) {
                                       msg = 'Applied instrument "${preset.name}" to ${track.name}';
                                     } else if (preset.isAudioFx) {
                                       msg = 'Added audio FX "${preset.name}" to end of ${track.name} FX rack';
                                     } else if (preset.isMidiFx) {
                                       msg = 'Added MIDI FX "${preset.name}" to ${track.name}';
                                     }
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                         content: Text(msg),
                                         backgroundColor: EatsTheme.panelHeader,
                                         duration: const Duration(seconds: 2),
                                       ),
                                     );
                                   }
                                 },
                                 builder: (context, trackHoverData, _) {
                                   final isTrackHovering = trackHoverData.isNotEmpty;
                                   final isTrackReordering = trackHoverData.any((d) => d is TrackChannel);

                                   return GestureDetector(
                                     onLongPress: () {
                                       setState(() => _isPropertiesExpanded = true);
                                       if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
                                       widget.dawState.selectClip(null);
                                     },
                                     onSecondaryTap: () {
                                       setState(() => _isPropertiesExpanded = true);
                                       if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
                                       widget.dawState.selectClip(null);
                                     },
                                     onTapDown: (_) {
                                       final now = DateTime.now();
                                       final isDoubleTap = _lastHeaderTapTrackIdx == trackIdx &&
                                           _lastHeaderTapTime != null &&
                                           now.difference(_lastHeaderTapTime!).inMilliseconds < 300;
                                       _lastHeaderTapTime = now;
                                       _lastHeaderTapTrackIdx = trackIdx;

                                       if (allIdx != -1) widget.dawState.activeTrackIndex = allIdx;
                                       widget.dawState.selectClip(null);
                                        if (isDoubleTap) {
                                          if (track.isFolder) {
                                            widget.dawState.toggleFolderCollapsed(track);
                                          } else {
                                            // DOUBLE-TAP TRACK HEADER: Expose the Instrument in the Track Properties sidebar
                                            setState(() {
                                              _isPropertiesExpanded = true;
                                            });
                                          }
                                        }
                                     },
                                     child: Container(
                                       height: trackRowHeight,
                                       margin: const EdgeInsets.only(bottom: 2),
                                       decoration: BoxDecoration(
                                         color: isTrackHovering
                                             ? (isTrackReordering ? EatsTheme.primaryCyan.withOpacity(0.2) : EatsTheme.primaryCyan.withOpacity(0.3))
                                             : (isSelected
                                                 ? EatsTheme.controlBackground
                                                 : (track.isFolder ? const Color(0xFF141A24) : EatsTheme.panelBackground)),
                                         border: Border(
                                           top: isTrackReordering
                                               ? BorderSide(color: EatsTheme.primaryCyan, width: 2)
                                               : BorderSide.none,
                                           bottom: BorderSide(
                                             color: isTrackReordering ? EatsTheme.primaryCyan : EatsTheme.panelHeader,
                                             width: isTrackReordering ? 2 : 1,
                                           ),
                                           left: track.isFolder
                                               ? BorderSide(color: track.color, width: 4)
                                               : (track.isChildTrack ? BorderSide(color: track.color.withOpacity(0.4), width: 3) : BorderSide.none),
                                         ),
                                         boxShadow: isTrackHovering
                                             ? [BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.3), blurRadius: 6)]
                                             : null,
                                       ),
                                       child: Row(
                                         children: [
                                           if (track.isChildTrack)
                                             Container(
                                               width: 14,
                                               alignment: Alignment.center,
                                               child: Container(
                                                 width: 1.5,
                                                 height: double.infinity,
                                                 color: track.color.withOpacity(0.3),
                                               ),
                                             ),
                                           // Expanded Left-Hand Color Handle & Draggable Reorder Grip
                                           Draggable<TrackChannel>(
                                             data: track,
                                             feedback: Material(
                                               color: Colors.transparent,
                                               elevation: 10,
                                               child: Container(
                                                 width: 190,
                                                 height: trackRowHeight - 4,
                                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                 decoration: BoxDecoration(
                                                   color: EatsTheme.controlBackground.withOpacity(0.95),
                                                   borderRadius: BorderRadius.circular(4),
                                                   border: Border.all(color: track.color, width: 1.5),
                                                   boxShadow: [
                                                     BoxShadow(
                                                       color: track.color.withOpacity(0.4),
                                                       blurRadius: 10,
                                                       offset: const Offset(0, 4),
                                                     ),
                                                   ],
                                                 ),
                                                 child: Row(
                                                   children: [
                                                     Container(
                                                       width: 8,
                                                       height: double.infinity,
                                                       decoration: BoxDecoration(
                                                         color: track.color,
                                                         borderRadius: BorderRadius.circular(2),
                                                       ),
                                                     ),
                                                     const SizedBox(width: 8),
                                                     Expanded(
                                                       child: Text(
                                                         track.name,
                                                         style: const TextStyle(
                                                           color: Colors.white,
                                                           fontWeight: FontWeight.bold,
                                                           fontSize: 11,
                                                         ),
                                                         overflow: TextOverflow.ellipsis,
                                                       ),
                                                     ),
                                                     Icon(track.isFolder ? Icons.folder : Icons.swap_vert, size: 16, color: track.color),
                                                   ],
                                                 ),
                                               ),
                                             ),
                                             childWhenDragging: Container(
                                               width: 10,
                                               color: track.color.withOpacity(0.3),
                                             ),
                                             child: Tooltip(
                                               message: 'Drag to reorder "${track.name}"',
                                               child: MouseRegion(
                                                 cursor: SystemMouseCursors.grab,
                                                 child: Container(
                                                   width: 10,
                                                   color: isTrackHovering ? EatsTheme.primaryCyan : track.color,
                                                   alignment: Alignment.center,
                                                   child: Container(
                                                     width: 2,
                                                     height: 16,
                                                     decoration: BoxDecoration(
                                                       color: Colors.black.withOpacity(0.35),
                                                       borderRadius: BorderRadius.circular(1),
                                                     ),
                                                   ),
                                                 ),
                                               ),
                                             ),
                                           ),
                                           // Track Content (Row 1: Name & M/S/FX/Follow; Row 2: Volume & Pan)
                                           Expanded(
                                             child: Padding(
                                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                               child: Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 mainAxisAlignment: MainAxisAlignment.center,
                                                 children: [
                                                   // Row 1: Readable Name (with emoji support) & Follow, M, S Action Buttons
                                                   Row(
                                                     children: [
                                                       if (track.isFolder) ...[
                                                         InkWell(
                                                           onTap: () => widget.dawState.toggleFolderCollapsed(track),
                                                           child: Icon(
                                                             track.isCollapsed ? Icons.chevron_right : Icons.expand_more,
                                                             size: 14,
                                                             color: track.color,
                                                           ),
                                                         ),
                                                         const SizedBox(width: 2),
                                                       ],
                                                       Expanded(
                                                         child: Text(
                                                           track.name,
                                                           maxLines: 1,
                                                           overflow: TextOverflow.ellipsis,
                                                           style: EatsTheme.getPrimaryFontStyle(
                                                             color: isSelected ? EatsTheme.primaryCyan : EatsTheme.textPrimary,
                                                             fontWeight: (isSelected || track.isFolder) ? FontWeight.bold : FontWeight.normal,
                                                             fontSize: 11,
                                                           ),
                                                         ),
                                                       ),
                                                       if (track.hasLyrics && !track.isFolder) ...[
                                                         Tooltip(
                                                           message: 'Track contains lyrics / vocal cues',
                                                           child: Container(
                                                             margin: const EdgeInsets.only(right: 2),
                                                             padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                             decoration: BoxDecoration(
                                                               color: EatsTheme.secondaryMagenta.withOpacity(0.2),
                                                               borderRadius: BorderRadius.circular(2),
                                                             ),
                                                             child: const Icon(Icons.chat_bubble, size: 8, color: EatsTheme.secondaryMagenta),
                                                           ),
                                                         ),
                                                       ],
                                                       if (track.isFolder) ...[
                                                         Container(
                                                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                           margin: const EdgeInsets.only(right: 3),
                                                           decoration: BoxDecoration(
                                                             color: track.color.withOpacity(0.18),
                                                             borderRadius: BorderRadius.circular(3),
                                                             border: Border.all(color: track.color.withOpacity(0.4), width: 0.8),
                                                           ),
                                                           child: Text(
                                                             '${widget.dawState.getFolderChildren(track.id).length}',
                                                             style: TextStyle(color: track.color, fontSize: 8, fontWeight: FontWeight.bold),
                                                           ),
                                                         ),
                                                       ] else ...[
                                                         const SizedBox(width: 3),
                                                         _buildFollowModeButton(track),
                                                       ],
                                                       const SizedBox(width: 3),
                                                       _buildMuteButton(track),
                                                       const SizedBox(width: 2),
                                                       _buildSoloButton(track),
                                                       const SizedBox(width: 2),
                                                       _buildFreezeButton(track),
                                                     ],
                                                   ),
                                                  const SizedBox(height: 4),
                                                  // Row 2: Volume Slider with Level Readout & Skeuomorphic Pan Knob
                                                  Row(
                                                    children: [
                                                      // Volume Control & Level Readout
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  'VOL',
                                                                  style: TextStyle(color: EatsTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold),
                                                                ),
                                                                const Spacer(),
                                                                Text(
                                                                  '${(track.volume * 100).round()}%',
                                                                  style: TextStyle(
                                                                    color: isSelected ? EatsTheme.primaryCyan : EatsTheme.textPrimary,
                                                                    fontSize: 8,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 2),
                                                            SizedBox(
                                                              height: 14,
                                                              child: EatsBeatsSlider(
                                                                value: track.volume,
                                                                min: 0.0,
                                                                max: 1.5,
                                                                defaultValue: 1.0,
                                                                label: '${track.name} Volume',
                                                                showTooltip: false,
                                                                activeColor: track.color,
                                                                onChanged: (val) => widget.dawState.setTrackVolume(track, val),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Skeuomorphic Hardware Pan Knob
                                                      SkeuomorphicHardwareKnob(
                                                        label: 'Pan',
                                                        showLabelText: false,
                                                        value: track.pan,
                                                        min: -1.0,
                                                        max: 1.0,
                                                        defaultValue: 0.0,
                                                        size: 28.0,
                                                        accentColor: track.color,
                                                        formatValue: (v) => v == 0 ? 'C' : (v < 0 ? 'L${(v.abs() * 100).round()}' : 'R${(v * 100).round()}'),
                                                        onChanged: (val) => widget.dawState.setTrackPan(track, val),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

              // Right Multitrack Timeline Grid with Top Bar Ruler & Live Playhead
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: _horizontalScroll,
                      builder: (context, _) {
                        final double scrollX = _horizontalScroll.hasClients ? _horizontalScroll.offset : 0.0;
                        final double viewW = constraints.maxWidth;
                        final int minVisibleBar = math.max(0, (scrollX / barWidth).floor() - 2);
                        final int maxVisibleBar = math.min(totalBars, ((scrollX + viewW) / barWidth).ceil() + 2);

                        return Listener(
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
                      if (_rightGridScroll.hasClients) {
                        final targetY = (_rightGridScroll.offset - event.delta.dy)
                            .clamp(0.0, _rightGridScroll.position.maxScrollExtent);
                        _rightGridScroll.jumpTo(targetY);
                        if (_leftTrackScroll.hasClients) {
                          _leftTrackScroll.jumpTo(targetY);
                        }
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
                    child: SingleChildScrollView(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: totalBars * barWidth,
                        child: Column(
                          children: [
                        // Top Timeline Bar Ruler (Bar 1, Bar 2 ... Bar 32 with Tap to Jump & Loop Region)
                        GestureDetector(
                          onTapUp: (details) {
                            final double localX = details.localPosition.dx;
                            final double step = (localX / barWidth) * 16.0;
                            widget.dawState.seekToArrangerStep(step);
                          },
                          onLongPressStart: (details) {
                            final double localX = details.localPosition.dx;
                            final int tappedBar = (localX / barWidth).floor().clamp(0, totalBars - 1);
                            _dragLoopStartBar = tappedBar;
                            // Set loop start at tapped bar, end at tapped bar + 4 by default
                            widget.dawState.setLoopPoints(tappedBar, tappedBar + 4);
                          },
                          onLongPressMoveUpdate: (details) {
                            if (_dragLoopStartBar == null) return;
                            final double localX = details.localPosition.dx;
                            final int currentBar = (localX / barWidth).floor().clamp(0, totalBars - 1);
                            if (currentBar >= _dragLoopStartBar!) {
                              widget.dawState.setLoopPoints(_dragLoopStartBar!, currentBar + 1);
                            } else {
                              widget.dawState.setLoopPoints(currentBar, _dragLoopStartBar! + 1);
                            }
                          },
                          onLongPressEnd: (_) {
                            _dragLoopStartBar = null;
                          },
                          child: Container(
                            height: 24,
                            color: EatsTheme.panelHeader,
                            child: Stack(
                              children: [
                                Row(
                                  children: List.generate(totalBars, (barIdx) {
                                    return Container(
                                      width: barWidth,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        '${barIdx + 1}',
                                        style: EatsTheme.getDisplayFontStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }),
                                ),

                                // Shaded Loop Region Overlay
                                if (widget.dawState.isLooping)
                                  Positioned(
                                    left: loopStartX,
                                    width: loopWidth,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: EatsTheme.accentGold.withOpacity(0.2),
                                        border: Border(
                                          left: BorderSide(color: EatsTheme.accentGold, width: 2),
                                          right: BorderSide(color: EatsTheme.accentGold, width: 2),
                                        ),
                                      ),
                                      alignment: Alignment.topCenter,
                                      child: Text(
                                        'LOOP',
                                        style: TextStyle(
                                          color: EatsTheme.accentGold,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                 // Playhead Head Marker Badge
                                 ValueListenableBuilder<int>(
                                   valueListenable: widget.dawState.arrangerStepNotifier,
                                   builder: (context, curStep, _) {
                                     final curPlayheadX = (curStep / 16.0) * barWidth;
                                     return Positioned(
                                       left: curPlayheadX - 6,
                                       top: 2,
                                       child: RepaintBoundary(
                                         child: Container(
                                           width: 12,
                                           height: 20,
                                           decoration: BoxDecoration(
                                             color: EatsTheme.primaryCyan,
                                             borderRadius: BorderRadius.circular(3),
                                           ),
                                           child: const Icon(Icons.arrow_drop_down, size: 12, color: Colors.black),
                                         ),
                                       ),
                                     );
                                   },
                                 ),
                              ],
                            ),
                          ),
                        ),

                        // Chord Track Timeline Lane (Height 28)
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1219),
                            border: Border(
                              bottom: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.3), width: 1),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Bar Grid Lines and tap-to-add chord triggers
                              Row(
                                children: List.generate(totalBars, (barIdx) {
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) {
                                      final double localX = (barIdx * barWidth) + details.localPosition.dx;
                                      final double step = (localX / barWidth) * 16.0;
                                      widget.dawState.seekToArrangerStep(step);
                                    },
                                    onDoubleTap: () {
                                      final existing = widget.dawState.getActiveChordAtBar(barIdx);
                                      CircleOfFifthsDialog.show(
                                        context,
                                        dawState: widget.dawState,
                                        targetBar: barIdx,
                                        initialChord: existing,
                                      );
                                    },
                                    child: Container(
                                      width: barWidth,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.04), width: 1)),
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              // Rendered Chord Blocks (Drag & Drop Move, Resize Handle & Context Menu) - Viewport Culled
                              ...widget.dawState.chordTrack
                                  .where((chord) => (chord.startBar + chord.barLength) >= minVisibleBar && chord.startBar <= maxVisibleBar)
                                  .map((chord) {
                                final double chordX = chord.startBar * barWidth;
                                final double chordW = math.max(20.0, chord.barLength * barWidth - 2.0);
                                final roman = ChordTheory.getRomanNumeral(
                                  widget.dawState.songKeyRoot,
                                  widget.dawState.isSongKeyMinor,
                                  chord.rootPitchClass,
                                  chord.quality,
                                );

                                return Positioned(
                                  left: chordX + 1,
                                  width: chordW,
                                  top: 2,
                                  bottom: 2,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) {
                                      final double localX = chordX + details.localPosition.dx;
                                      final double step = (localX / barWidth) * 16.0;
                                      widget.dawState.seekToArrangerStep(step);
                                    },
                                    onDoubleTap: () {
                                      CircleOfFifthsDialog.show(
                                        context,
                                        dawState: widget.dawState,
                                        targetBar: chord.startBar,
                                        initialChord: chord,
                                      );
                                    },
                                    onSecondaryTap: () {
                                      widget.dawState.removeChord(chord.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted chord "${chord.displayName}" (Ctrl+Z to Undo)'),
                                          backgroundColor: EatsTheme.panelHeader,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    onSecondaryTapDown: (_) {
                                      widget.dawState.removeChord(chord.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted chord "${chord.displayName}" (Ctrl+Z to Undo)'),
                                          backgroundColor: EatsTheme.panelHeader,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    onHorizontalDragStart: (_) {
                                      _chordMoveDragDxAccumulator = 0.0;
                                      widget.dawState.beginHistoryTransaction('Move Chord "${chord.displayName}"', icon: Icons.open_with);
                                    },
                                    onHorizontalDragUpdate: (details) {
                                      _chordMoveDragDxAccumulator += details.delta.dx;
                                      if (_chordMoveDragDxAccumulator.abs() >= barWidth * 0.5) {
                                        final shiftBars = (_chordMoveDragDxAccumulator / barWidth).round();
                                        if (shiftBars != 0) {
                                          setState(() {
                                            chord.startBar = (chord.startBar + shiftBars).clamp(0, totalBars - chord.barLength.ceil());
                                          });
                                          _chordMoveDragDxAccumulator -= shiftBars * barWidth;
                                        }
                                      }
                                    },
                                    onHorizontalDragEnd: (_) {
                                      widget.dawState.commitHistoryTransaction();
                                      widget.dawState.notifyListeners();
                                    },
                                    onHorizontalDragCancel: () => widget.dawState.commitHistoryTransaction(),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            EatsTheme.primaryCyan.withOpacity(0.35),
                                            EatsTheme.secondaryMagenta.withOpacity(0.25),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.8), width: 1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: EatsTheme.primaryCyan.withOpacity(0.15),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Chord Title & Roman Numeral
                                          Positioned.fill(
                                            right: 14,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      chord.displayName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: EatsTheme.getDisplayFontStyle(
                                                        color: EatsTheme.chordTrackTextColor,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black54,
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                    child: Text(
                                                      roman,
                                                      style: const TextStyle(color: EatsTheme.accentGold, fontSize: 8, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Right Resize Handle
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            bottom: 0,
                                            width: 14,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onHorizontalDragStart: (_) {
                                                _chordResizeDragDxAccumulator = 0.0;
                                                widget.dawState.beginHistoryTransaction('Resize Chord "${chord.displayName}"', icon: Icons.straighten);
                                              },
                                              onHorizontalDragUpdate: (details) {
                                                _chordResizeDragDxAccumulator += details.delta.dx;
                                                if (_chordResizeDragDxAccumulator.abs() >= barWidth * 0.5) {
                                                  final shiftBars = (_chordResizeDragDxAccumulator / barWidth).round();
                                                  if (shiftBars != 0) {
                                                    setState(() {
                                                      final newLen = (chord.barLength + shiftBars).clamp(1.0, (totalBars - chord.startBar).toDouble());
                                                      chord.barLength = newLen;
                                                    });
                                                    _chordResizeDragDxAccumulator -= shiftBars * barWidth;
                                                  }
                                                }
                                              },
                                              onHorizontalDragEnd: (_) {
                                                widget.dawState.commitHistoryTransaction();
                                                widget.dawState.notifyListeners();
                                              },
                                              onHorizontalDragCancel: () => widget.dawState.commitHistoryTransaction(),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: EatsTheme.primaryCyan.withOpacity(0.25),
                                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white70),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        // Multitrack Timeline Grid (Synced Scroll, Smooth Clip Drag/Resize & Playhead Line)
                        Expanded(
                          child: Stack(
                            children: [
                              NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (!_isSyncingScroll && notification is ScrollUpdateNotification) {
                                    _isSyncingScroll = true;
                                    if (_leftTrackScroll.hasClients) {
                                      _leftTrackScroll.jumpTo(_rightGridScroll.offset);
                                    }
                                    _isSyncingScroll = false;
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  controller: _rightGridScroll,
                                  itemCount: tracks.length + 1,
                                  itemBuilder: (context, trackIdx) {
                                    if (trackIdx == tracks.length) {
                                      return DragTarget<Object>(
                                        onWillAcceptWithDetails: (details) {
                                          final data = details.data;
                                          if (data is SoundFontDragItem) return true;
                                          if (data is LuaPreset) return data.isInstrument;
                                          return false;
                                        },
                                        onAcceptWithDetails: (details) {
                                          final data = details.data;
                                          if (data is SoundFontDragItem) {
                                            widget.dawState.addNewSoundFontTrack(data.fontId, displayName: data.displayName);
                                          } else if (data is LuaPreset && data.isInstrument) {
                                            widget.dawState.addNewPresetTrack(data);
                                          }
                                        },
                                        builder: (context, hoverData, _) {
                                          final isHover = hoverData.isNotEmpty;
                                          return Container(
                                            height: 44,
                                            margin: const EdgeInsets.only(top: 4, bottom: 28),
                                            decoration: BoxDecoration(
                                              color: isHover ? EatsTheme.primaryCyan.withOpacity(0.15) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isHover ? EatsTheme.primaryCyan : Colors.white.withOpacity(0.04),
                                                width: 1,
                                              ),
                                            ),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () => PresetSearchDialog.showAddTrack(
                                                context,
                                                dawState: widget.dawState,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '+ ADD',
                                                  style: TextStyle(
                                                    color: isHover ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }

                                    final track = tracks[trackIdx];
                                    final isDropTargetHover = _dragHoverTrackIdx == trackIdx && _dragSourceTrackIdx != trackIdx;
                                    final bool canAcceptDrop = isDropTargetHover && _draggedClip != null && widget.dawState.canMoveClipToTrack(_draggedClip!, track);

                                    return Container(
                                      height: trackRowHeight,
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        color: isDropTargetHover
                                            ? (canAcceptDrop ? EatsTheme.primaryCyan.withOpacity(0.12) : Colors.red.withOpacity(0.12))
                                            : EatsTheme.backgroundDark,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: isDropTargetHover
                                                ? (canAcceptDrop ? EatsTheme.primaryCyan : Colors.redAccent)
                                                : EatsTheme.panelHeader,
                                            width: isDropTargetHover ? 1.5 : 1,
                                          ),
                                          top: isDropTargetHover
                                              ? BorderSide(color: canAcceptDrop ? EatsTheme.primaryCyan : Colors.redAccent, width: 1.5)
                                              : BorderSide.none,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                           // Bar Grid Lines
                                           Row(
                                             children: List.generate(totalBars, (barIdx) {
                                               return GestureDetector(
                                                 behavior: HitTestBehavior.opaque,
                                                 onTapUp: (details) {
                                                   widget.dawState.activeTrackIndex = trackIdx;
                                                   final double stepWithinBar = (details.localPosition.dx / barWidth) * 16.0;
                                                   final double step = (barIdx * 16.0 + stepWithinBar).clamp(0.0, (totalBars * 16.0) - 1.0);
                                                   widget.dawState.seekToArrangerStep(step);
                                                 },
                                                 onDoubleTap: () {
                                                   widget.dawState.activeTrackIndex = trackIdx;
                                                   widget.dawState.addClipToTrack(track, barIdx);
                                                 },
                                                 child: Container(
                                                   width: barWidth,
                                                   height: trackRowHeight,
                                                   decoration: BoxDecoration(
                                                     color: Colors.transparent,
                                                     border: Border(
                                                       right: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                                                     ),
                                                   ),
                                                 ),
                                               );
                                             }),
                                           ),

                                           // Cross-Track Drag Target Ghost Preview
                                           if (isDropTargetHover && _draggedClip != null)
                                             Positioned(
                                               left: _draggedClip!.startBar * barWidth + 2,
                                               top: 6,
                                               width: (_draggedClip!.barLength * barWidth) - 4,
                                               height: trackRowHeight - 12,
                                               child: Container(
                                                 decoration: BoxDecoration(
                                                   color: canAcceptDrop ? EatsTheme.primaryCyan.withOpacity(0.22) : Colors.red.withOpacity(0.18),
                                                   borderRadius: BorderRadius.circular(6),
                                                   border: Border.all(
                                                     color: canAcceptDrop ? EatsTheme.primaryCyan : Colors.redAccent,
                                                     width: 1.5,
                                                   ),
                                                 ),
                                                 alignment: Alignment.center,
                                                 child: Row(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     Icon(
                                                       canAcceptDrop ? Icons.swap_vert : Icons.block,
                                                       size: 13,
                                                       color: canAcceptDrop ? EatsTheme.primaryCyan : Colors.redAccent,
                                                     ),
                                                     const SizedBox(width: 4),
                                                     Text(
                                                       canAcceptDrop ? 'MOVE TO ${track.name.toUpperCase()}' : 'WAVE / FOLDER TRACK NOT COMPATIBLE',
                                                       style: TextStyle(
                                                         color: canAcceptDrop ? EatsTheme.primaryCyan : Colors.redAccent,
                                                         fontSize: 8.5,
                                                         fontWeight: FontWeight.bold,
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                                   ),

                                               // Time-Synced Track Lyrics Ribbon - Viewport Culled
                                               if (track.lyrics.isNotEmpty) ...[
                                                 ...track.lyrics
                                                     .where((cue) {
                                                       final cueBar = cue.startStep / 16.0;
                                                       return cueBar >= minVisibleBar - 1 && cueBar <= maxVisibleBar + 1;
                                                     })
                                                     .map((cue) {
                                                   final cueLeft = (cue.startStep / 16.0) * barWidth + 2;
                                                   return Positioned(
                                                     left: cueLeft,
                                                     bottom: 3,
                                                     height: 16,
                                                     child: Tooltip(
                                                       message: 'Lyric: "${cue.text}" @ step ${cue.startStep.toStringAsFixed(1)}',
                                                       child: Container(
                                                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                         decoration: BoxDecoration(
                                                           color: EatsTheme.backgroundDark.withOpacity(0.85),
                                                           borderRadius: BorderRadius.circular(3),
                                                           border: Border.all(color: track.color.withOpacity(0.8), width: 0.8),
                                                         ),
                                                         child: Row(
                                                           mainAxisSize: MainAxisSize.min,
                                                           children: [
                                                             Icon(Icons.chat_bubble_outline, size: 8, color: track.color),
                                                             const SizedBox(width: 3),
                                                             Text(
                                                               cue.text,
                                                               style: const TextStyle(
                                                                 color: Colors.white,
                                                                 fontSize: 8.5,
                                                                 fontWeight: FontWeight.bold,
                                                               ),
                                                             ),
                                                           ],
                                                         ),
                                                       ),
                                                     ),
                                                   );
                                                 }),
                                               ],

                                               // Render Aggregated Ghost Clips when Folder is Collapsed
                                               if (track.isFolder && track.isCollapsed) ...[
                                                 ...() {
                                                   final children = widget.dawState.getFolderChildren(track.id);
                                                   final List<Widget> ghostWidgets = [];
                                                   for (final child in children) {
                                                     for (final clip in child.clips) {
                                                       if ((clip.startBar + clip.barLength) < minVisibleBar || clip.startBar > maxVisibleBar) continue;
                                                       ghostWidgets.add(
                                                         Positioned(
                                                           left: clip.startBar * barWidth + 2,
                                                           top: 6.0,
                                                           width: math.max(20.0, (clip.barLength * barWidth) - 4),
                                                           height: trackRowHeight - 12.0,
                                                           child: Tooltip(
                                                             message: '${child.name}: ${clip.name} (Double-tap to expand folder)',
                                                             child: GestureDetector(
                                                               onDoubleTap: () => widget.dawState.toggleFolderCollapsed(track),
                                                               child: Container(
                                                                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                                 decoration: BoxDecoration(
                                                                   color: child.color.withOpacity(0.35),
                                                                   borderRadius: BorderRadius.circular(4),
                                                                   border: Border.all(color: child.color.withOpacity(0.8), width: 1),
                                                                 ),
                                                                 alignment: Alignment.centerLeft,
                                                                 child: Row(
                                                                   mainAxisSize: MainAxisSize.min,
                                                                   children: [
                                                                     Icon(child.iconData, size: 10, color: Colors.white),
                                                                     const SizedBox(width: 3),
                                                                     Flexible(
                                                                       child: Text(
                                                                         '${child.name}: ${clip.name}',
                                                                         maxLines: 1,
                                                                         overflow: TextOverflow.ellipsis,
                                                                         style: const TextStyle(
                                                                           color: Colors.white,
                                                                           fontSize: 9,
                                                                           fontWeight: FontWeight.bold,
                                                                         ),
                                                                       ),
                                                                     ),
                                                                   ],
                                                                 ),
                                                               ),
                                                             ),
                                                           ),
                                                         ),
                                                       );
                                                     }
                                                   }
                                                   return ghostWidgets;
                                                 }(),
                                               ] else ...[
                                                 // Per-track Pattern Clips with Smooth Drag-Move, Edge-Resize, and Preset DragTarget (Viewport Culled)
                                                 ...track.clips
                                                     .where((clip) => clip == _draggedClip ||
                                                         widget.dawState.activeClip == clip ||
                                                         ((clip.startBar + clip.barLength) >= minVisibleBar && clip.startBar <= maxVisibleBar))
                                                     .map((clip) {
                                                   final isClipSelected = widget.dawState.activeClip?.id == clip.id;

                                                   return Positioned(
                                                     left: clip.startBar * barWidth + 2,
                                                     top: 6,
                                                     width: (clip.barLength * barWidth) - 4,
                                                     height: trackRowHeight - 12,
                                                     child: DragTarget<Object>(
                                                       onWillAcceptWithDetails: (details) {
                                                         final data = details.data;
                                                         if (data is LuaPreset) {
                                                           return data.isMidiSeq || data.isMidiFx;
                                                         }
                                                         return false;
                                                       },
                                                       onAcceptWithDetails: (details) {
                                                         final data = details.data;
                                                         if (data is LuaPreset) {
                                                           if (data.isMidiSeq) {
                                                             widget.dawState.activeTrackIndex = trackIdx;
                                                             widget.dawState.selectClip(clip);
                                                             widget.dawState.applyPresetToClip(track, clip, data);
                                                             ScaffoldMessenger.of(context).showSnackBar(
                                                               SnackBar(
                                                                 content: Text('Applied sequence "${data.name}" to clip "${clip.name}"'),
                                                                 backgroundColor: EatsTheme.panelHeader,
                                                                 duration: const Duration(seconds: 2),
                                                               ),
                                                             );
                                                           } else if (data.isMidiFx) {
                                                             widget.dawState.activeTrackIndex = trackIdx;
                                                             widget.dawState.addMidiFXInsert(
                                                               track,
                                                               name: data.name,
                                                               luaScriptCode: data.code,
                                                             );
                                                             ScaffoldMessenger.of(context).showSnackBar(
                                                               SnackBar(
                                                                 content: Text('Added MIDI FX "${data.name}" to ${track.name}'),
                                                                 backgroundColor: EatsTheme.panelHeader,
                                                                 duration: const Duration(seconds: 2),
                                                               ),
                                                             );
                                                           }
                                                         }
                                                       },
                                                       builder: (context, hoverData, _) {
                                                         final isPresetHover = hoverData.isNotEmpty;

                                                         return GestureDetector(
                                                           behavior: HitTestBehavior.opaque,
                                                           onTapDown: (details) {
                                                             final now = DateTime.now();
                                                             final isDoubleTap = _lastClipTapId == clip.id &&
                                                                 _lastClipTapTime != null &&
                                                                 now.difference(_lastClipTapTime!).inMilliseconds < 300;
                                                             _lastClipTapTime = now;
                                                             _lastClipTapId = clip.id;

                                                             widget.dawState.activeTrackIndex = trackIdx;
                                                             widget.dawState.selectClip(clip);

                                                             // Move playhead to tapped position
                                                             final double clipGlobalX = (clip.startBar * barWidth) + details.localPosition.dx;
                                                             final double step = (clipGlobalX / barWidth) * 16.0;
                                                             widget.dawState.seekToArrangerStep(step);

                                                             if (isDoubleTap) {
                                                               // DOUBLE-TAP CLIP: Open MIDI clip in Piano Roll / Tracker; for Audio clips, focus clip properties inspector
                                                               if (track.type != TrackType.sampler && !clip.isAudioClip) {
                                                                 widget.dawState.openClipInEditor(clip);
                                                               } else {
                                                                 setState(() => _isPropertiesExpanded = true);
                                                               }
                                                             }
                                                           },
                                                           onSecondaryTap: () {
                                                             setState(() => _isPropertiesExpanded = true);
                                                             widget.dawState.activeTrackIndex = trackIdx;
                                                             widget.dawState.selectClip(clip);
                                                           },
                                                           onLongPress: () {
                                                             setState(() => _isPropertiesExpanded = true);
                                                             widget.dawState.activeTrackIndex = trackIdx;
                                                             widget.dawState.selectClip(clip);
                                                           },
                                                           onPanStart: (details) {
                                                             _moveDragDxAccumulator = 0.0;
                                                             _moveDragDyAccumulator = 0.0;
                                                             _draggedClip = clip;
                                                             _draggedClipSourceTrack = track;
                                                             _dragSourceTrackIdx = trackIdx;
                                                             _dragHoverTrackIdx = trackIdx;
                                                             widget.dawState.beginHistoryTransaction('Move Clip "${clip.name}"', icon: Icons.open_with);
                                                           },
                                                           onPanUpdate: (details) {
                                                             _moveDragDxAccumulator += details.delta.dx;
                                                             _moveDragDyAccumulator += details.delta.dy;

                                                             // Horizontal Bar Drag Shift
                                                             if (_moveDragDxAccumulator.abs() >= barWidth * 0.5) {
                                                               final shiftBars = (_moveDragDxAccumulator / barWidth).round();
                                                               if (shiftBars != 0) {
                                                                 setState(() {
                                                                   clip.startBar = (clip.startBar + shiftBars).clamp(0, totalBars - clip.barLength);
                                                                 });
                                                                 _moveDragDxAccumulator -= shiftBars * barWidth;
                                                               }
                                                             }

                                                             // Vertical Track Drag Shift
                                                             final trackShift = (_moveDragDyAccumulator / (trackRowHeight + 2.0)).round();
                                                             if (_dragSourceTrackIdx != null) {
                                                               final targetIdx = (_dragSourceTrackIdx! + trackShift).clamp(0, tracks.length - 1);
                                                               if (targetIdx != _dragHoverTrackIdx) {
                                                                 setState(() {
                                                                   _dragHoverTrackIdx = targetIdx;
                                                                 });
                                                               }
                                                             }
                                                           },
                                                           onPanEnd: (_) {
                                                             if (_dragHoverTrackIdx != null && _dragSourceTrackIdx != null && _dragHoverTrackIdx != _dragSourceTrackIdx) {
                                                               final targetTrack = tracks[_dragHoverTrackIdx!];
                                                               if (widget.dawState.canMoveClipToTrack(clip, targetTrack)) {
                                                                 widget.dawState.moveClipToTrack(clip, track, targetTrack, targetStartBar: clip.startBar);
                                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                                   SnackBar(
                                                                     content: Text('Moved pattern clip "${clip.name}" to ${targetTrack.name}'),
                                                                     backgroundColor: EatsTheme.panelHeader,
                                                                     duration: const Duration(seconds: 1),
                                                                   ),
                                                                 );
                                                               } else {
                                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                                   SnackBar(
                                                                     content: Text('Cannot drop pattern clip onto ${targetTrack.type == TrackType.sampler ? "Audio Wave Track" : "Folder Track"}'),
                                                                     backgroundColor: Colors.redAccent.shade700,
                                                                     duration: const Duration(seconds: 2),
                                                                   ),
                                                                 );
                                                               }
                                                             }
                                                             setState(() {
                                                               _draggedClip = null;
                                                               _draggedClipSourceTrack = null;
                                                               _dragSourceTrackIdx = null;
                                                               _dragHoverTrackIdx = null;
                                                             });
                                                             widget.dawState.commitHistoryTransaction();
                                                           },
                                                           onPanCancel: () {
                                                             setState(() {
                                                               _draggedClip = null;
                                                               _draggedClipSourceTrack = null;
                                                               _dragSourceTrackIdx = null;
                                                               _dragHoverTrackIdx = null;
                                                             });
                                                             widget.dawState.commitHistoryTransaction();
                                                           },
                                                           child: AnimatedContainer(
                                                             duration: const Duration(milliseconds: 120),
                                                             decoration: BoxDecoration(
                                                               color: isPresetHover
                                                                   ? EatsTheme.accentGold.withOpacity(0.3)
                                                                   : (isClipSelected
                                                                       ? Color.alphaBlend(Colors.white.withOpacity(0.18), track.color)
                                                                       : track.color),
                                                               borderRadius: BorderRadius.circular(6),
                                                               border: Border.all(
                                                                 color: isPresetHover
                                                                     ? EatsTheme.accentGold
                                                                     : (isClipSelected ? EatsTheme.highlightColor : Colors.white.withOpacity(0.15)),
                                                                 width: isPresetHover ? 2.0 : (isClipSelected ? 2.0 : 1.0),
                                                               ),
                                                               boxShadow: [
                                                                 if (isPresetHover)
                                                                   BoxShadow(
                                                                     color: EatsTheme.accentGold.withOpacity(0.6),
                                                                     blurRadius: 12,
                                                                     spreadRadius: 2,
                                                                   )
                                                                 else if (isClipSelected)
                                                                   BoxShadow(
                                                                     color: EatsTheme.highlightColor.withOpacity(0.6),
                                                                     blurRadius: 10,
                                                                     spreadRadius: 1,
                                                                   ),
                                                                 BoxShadow(color: track.color.withOpacity(0.4), blurRadius: 6),
                                                               ],
                                                             ),
                                                             child: ClipRRect(
                                                               borderRadius: BorderRadius.circular(5),
                                                               child: Stack(
                                                                 children: [
                                                                   // Full Dimensions Note Content Preview Canvas
                                                                   Positioned.fill(
                                                                     child: CustomPaint(
                                                                       painter: PatternClipNotePainter(
                                                                         clip: clip,
                                                                         track: track,
                                                                         isSelected: isClipSelected,
                                                                       ),
                                                                     ),
                                                                   ),

                                                                   // 2. Full-Width Top Clip Title Header Bar (Tightly aligned to top-left)
                                                                   Positioned(
                                                                     left: 0,
                                                                     right: 0,
                                                                     top: 0,
                                                                     child: Container(
                                                                       height: 18,
                                                                       padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                       decoration: BoxDecoration(
                                                                         color: EatsTheme.backgroundDark.withOpacity(0.78),
                                                                         border: Border(
                                                                           bottom: BorderSide(
                                                                             color: isClipSelected
                                                                                 ? EatsTheme.highlightColor.withOpacity(0.55)
                                                                                 : Colors.white.withOpacity(0.12),
                                                                             width: 0.8,
                                                                           ),
                                                                         ),
                                                                       ),
                                                                       child: Row(
                                                                         children: [
                                                                           if (isClipSelected) ...[
                                                                             Container(
                                                                               width: 5,
                                                                               height: 5,
                                                                               margin: const EdgeInsets.only(right: 4),
                                                                               decoration: BoxDecoration(
                                                                                 color: EatsTheme.highlightColor,
                                                                                 shape: BoxShape.circle,
                                                                                 boxShadow: [
                                                                                   BoxShadow(
                                                                                     color: EatsTheme.highlightColor.withOpacity(0.8),
                                                                                     blurRadius: 4,
                                                                                   ),
                                                                                 ],
                                                                               ),
                                                                             ),
                                                                           ],
                                                                           Container(
                                                                             padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                                                                             margin: const EdgeInsets.only(right: 3),
                                                                             decoration: BoxDecoration(
                                                                               color: Colors.black38,
                                                                               borderRadius: BorderRadius.circular(2),
                                                                             ),
                                                                             child: Text(
                                                                               clip.patternHex,
                                                                               style: const TextStyle(
                                                                                 color: EatsTheme.accentGold,
                                                                                 fontSize: 7.5,
                                                                                 fontWeight: FontWeight.bold,
                                                                                 fontFamily: 'monospace',
                                                                               ),
                                                                             ),
                                                                           ),
                                                                           Expanded(
                                                                             child: Text(
                                                                               clip.name,
                                                                               style: TextStyle(
                                                                                 color: isClipSelected ? EatsTheme.highlightColor : EatsTheme.clipTextColor,
                                                                                 fontWeight: FontWeight.bold,
                                                                                 fontSize: 9,
                                                                               ),
                                                                               overflow: TextOverflow.ellipsis,
                                                                               maxLines: 1,
                                                                             ),
                                                                           ),
                                                                            if (clip.isLooped) ...[
                                                                              const SizedBox(width: 4),
                                                                              Container(
                                                                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                                                decoration: BoxDecoration(
                                                                                  color: EatsTheme.accentGold.withOpacity(0.35),
                                                                                  borderRadius: BorderRadius.circular(2),
                                                                                  border: Border.all(color: EatsTheme.accentGold.withOpacity(0.8), width: 0.5),
                                                                                ),
                                                                                child: Row(
                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                  children: [
                                                                                    const Icon(Icons.loop, size: 7.5, color: EatsTheme.accentGold),
                                                                                    const SizedBox(width: 2),
                                                                                    Text(
                                                                                      '${clip.loopLengthBars}b LOOP',
                                                                                      style: const TextStyle(
                                                                                        color: EatsTheme.accentGold,
                                                                                        fontSize: 7.0,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ],
                                                                            if (clip.hasLyrics) ...[
                                                                              const SizedBox(width: 4),
                                                                              Container(
                                                                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                                                decoration: BoxDecoration(
                                                                                  color: EatsTheme.secondaryMagenta.withOpacity(0.35),
                                                                                  borderRadius: BorderRadius.circular(2),
                                                                                  border: Border.all(color: EatsTheme.secondaryMagenta.withOpacity(0.8), width: 0.5),
                                                                                ),
                                                                                child: Row(
                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                  children: [
                                                                                    const Icon(Icons.chat_bubble, size: 7, color: EatsTheme.secondaryMagenta),
                                                                                    const SizedBox(width: 2),
                                                                                    Text(
                                                                                      'LYRIC',
                                                                                      style: TextStyle(
                                                                                        color: EatsTheme.secondaryMagenta,
                                                                                        fontSize: 7.0,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ],
                                                                            if (track.midiFXRack.any((fx) => fx.enabled)) ...[
                                                                              const SizedBox(width: 4),
                                                                              Container(
                                                                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                                                decoration: BoxDecoration(
                                                                                  color: EatsTheme.primaryCyan.withOpacity(0.3),
                                                                                  borderRadius: BorderRadius.circular(2),
                                                                                  border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.8), width: 0.5),
                                                                                ),
                                                                                child: Row(
                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                  children: [
                                                                                    const Icon(Icons.bolt, size: 8, color: EatsTheme.accentGold),
                                                                                    const SizedBox(width: 1),
                                                                                    Text(
                                                                                      track.midiFXRack.isNotEmpty
                                                                                          ? track.midiFXRack.first.name.split(' ').first.toUpperCase()
                                                                                          : 'MIDI FX',
                                                                                      style: TextStyle(
                                                                                        color: EatsTheme.primaryCyan,
                                                                                        fontSize: 7.5,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),

                                                                    // 2.5 Clip Lyrics Sub-Banner
                                                                    if (clip.hasLyrics)
                                                                      Positioned(
                                                                        left: 0,
                                                                        right: 0,
                                                                        bottom: 0,
                                                                        height: 15,
                                                                        child: Container(
                                                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                                                          decoration: BoxDecoration(
                                                                            color: EatsTheme.backgroundDark.withOpacity(0.82),
                                                                            border: Border(
                                                                              top: BorderSide(
                                                                                color: isClipSelected ? EatsTheme.highlightColor.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                                                                                width: 0.5,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          child: Row(
                                                                            children: [
                                                                              Icon(Icons.format_quote, size: 8.5, color: isClipSelected ? EatsTheme.highlightColor : EatsTheme.primaryCyan),
                                                                              const SizedBox(width: 3),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  clip.lyrics.isNotEmpty
                                                                                      ? clip.lyrics.map((c) => c.text).join(' ')
                                                                                      : clip.notes.where((n) => n.lyric != null && n.lyric!.isNotEmpty).map((n) => n.lyric).join(' '),
                                                                                  maxLines: 1,
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                  style: TextStyle(
                                                                                    color: isClipSelected ? EatsTheme.highlightColor : Colors.white.withOpacity(0.92),
                                                                                    fontSize: 8.5,
                                                                                    fontWeight: FontWeight.w600,
                                                                                    fontStyle: FontStyle.italic,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),

                                                                   // 3. Drop Hover Overlay
                                                                   if (isPresetHover)
                                                                     Positioned.fill(
                                                                       child: Container(
                                                                         color: Colors.black54,
                                                                         alignment: Alignment.center,
                                                                         child: const Text(
                                                                           'APPLY',
                                                                           style: TextStyle(
                                                                             color: EatsTheme.accentGold,
                                                                             fontWeight: FontWeight.bold,
                                                                             fontSize: 10,
                                                                             letterSpacing: 1.0,
                                                                           ),
                                                                         ),
                                                                       ),
                                                                     ),

                                                                   // 4a. Top Right Edge Loop Resize Handle (OpenDAW-style Loop cursor & Looping drag)
                                                                   Positioned(
                                                                     right: 0,
                                                                     top: 0,
                                                                     height: 18,
                                                                     width: 22,
                                                                     child: MouseRegion(
                                                                       cursor: SystemMouseCursors.allScroll,
                                                                       child: Tooltip(
                                                                         message: 'Loop Resize (Repeats pattern every ${clip.effectiveLoopLengthBars} bars)',
                                                                         child: GestureDetector(
                                                                           behavior: HitTestBehavior.opaque,
                                                                           onHorizontalDragStart: (_) {
                                                                             _loopResizeDragDxAccumulator = 0.0;
                                                                             _initialLoopPointOnDrag = clip.effectiveLoopLengthBars;
                                                                             widget.dawState.beginHistoryTransaction('Loop Resize Clip "${clip.name}"', icon: Icons.loop);
                                                                           },
                                                                           onHorizontalDragUpdate: (details) {
                                                                             _loopResizeDragDxAccumulator += details.delta.dx;
                                                                             if (_loopResizeDragDxAccumulator.abs() >= barWidth * 0.5) {
                                                                               final shiftBars = (_loopResizeDragDxAccumulator / barWidth).round();
                                                                               if (shiftBars != 0) {
                                                                                 final newBarLength = (clip.barLength + shiftBars).clamp(1, totalBars - clip.startBar);
                                                                                 setState(() {
                                                                                   clip.barLength = newBarLength;
                                                                                   final initPoint = _initialLoopPointOnDrag ?? 2;
                                                                                   if (newBarLength > initPoint) {
                                                                                     clip.loopLengthBars = initPoint;
                                                                                   } else {
                                                                                     clip.loopLengthBars = null;
                                                                                   }
                                                                                 });
                                                                                 _loopResizeDragDxAccumulator -= shiftBars * barWidth;
                                                                               }
                                                                             }
                                                                           },
                                                                           onHorizontalDragEnd: (_) {
                                                                             _initialLoopPointOnDrag = null;
                                                                             widget.dawState.commitHistoryTransaction();
                                                                           },
                                                                           onHorizontalDragCancel: () {
                                                                             _initialLoopPointOnDrag = null;
                                                                             widget.dawState.commitHistoryTransaction();
                                                                           },
                                                                           child: Container(
                                                                             color: Colors.transparent,
                                                                             alignment: Alignment.center,
                                                                             child: Icon(
                                                                               Icons.sync,
                                                                               size: 11,
                                                                               color: clip.isLooped
                                                                                   ? EatsTheme.accentGold
                                                                                   : (isClipSelected ? EatsTheme.highlightColor : Colors.white.withOpacity(0.7)),
                                                                             ),
                                                                           ),
                                                                         ),
                                                                       ),
                                                                     ),
                                                                   ),

                                                                   // 4b. Bottom Right Edge Standard Resize Handle (Simple resize without looping)
                                                                   Positioned(
                                                                     right: 0,
                                                                     top: 18,
                                                                     bottom: 0,
                                                                     width: 22,
                                                                     child: MouseRegion(
                                                                       cursor: SystemMouseCursors.resizeLeftRight,
                                                                       child: Tooltip(
                                                                         message: 'Resize Clip Length',
                                                                         child: GestureDetector(
                                                                           behavior: HitTestBehavior.opaque,
                                                                           onHorizontalDragStart: (_) {
                                                                             _resizeDragDxAccumulator = 0.0;
                                                                             widget.dawState.beginHistoryTransaction('Resize Clip "${clip.name}"', icon: Icons.straighten);
                                                                           },
                                                                           onHorizontalDragUpdate: (details) {
                                                                             _resizeDragDxAccumulator += details.delta.dx;
                                                                             if (_resizeDragDxAccumulator.abs() >= barWidth * 0.5) {
                                                                               final shiftBars = (_resizeDragDxAccumulator / barWidth).round();
                                                                               if (shiftBars != 0) {
                                                                                 setState(() {
                                                                                   clip.barLength = (clip.barLength + shiftBars).clamp(1, totalBars - clip.startBar);
                                                                                   if (clip.loopLengthBars != null && clip.loopLengthBars! >= clip.barLength) {
                                                                                     clip.loopLengthBars = null;
                                                                                   }
                                                                                 });
                                                                                 _resizeDragDxAccumulator -= shiftBars * barWidth;
                                                                               }
                                                                             }
                                                                           },
                                                                           onHorizontalDragEnd: (_) => widget.dawState.commitHistoryTransaction(),
                                                                           onHorizontalDragCancel: () => widget.dawState.commitHistoryTransaction(),
                                                                           child: Container(
                                                                             color: Colors.transparent,
                                                                             alignment: Alignment.center,
                                                                             child: Icon(
                                                                               Icons.code,
                                                                               size: 11,
                                                                               color: isClipSelected ? EatsTheme.highlightColor : EatsTheme.backgroundDark.withOpacity(0.8),
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
                                                         );
                                                       },
                                                     ),
                                                   );
                                                 }),
                                               ],
                                             ],
                                           ),
                                        );
                                      },
                                  ),
                                ),

                                  // Vertical Song Timeline Playhead Line Across Multitrack Rows
                                  ValueListenableBuilder<int>(
                                    valueListenable: widget.dawState.arrangerStepNotifier,
                                    builder: (context, curStep, _) {
                                      final curPlayheadX = (curStep / 16.0) * barWidth;
                                      return Positioned(
                                        left: curPlayheadX,
                                        top: 0,
                                        bottom: 0,
                                        child: RepaintBoundary(
                                          child: Container(
                                            width: 2,
                                            decoration: BoxDecoration(
                                              color: EatsTheme.primaryCyan,
                                              boxShadow: [
                                                BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.8), blurRadius: 4),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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
              },
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

    // Right-Sidebar Vertical Track Properties Pullout Drawer (Styled with exact pullout method from Virtual Piano Keyboard)
    AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.fastOutSlowIn,
      top: 0,
      bottom: 0,
      right: isBrowserOpen ? 320.0 : 0.0,
      width: drawerWidth,
      child: _buildVerticalTrackPropertiesPullout(context),
    ),
  ],
),
);
  }

  Widget _buildArrangerHeader() {
    final isTimeline = widget.dawState.arrangerViewMode == ArrangerViewMode.timeline;
    final tracks = widget.dawState.visibleTracks;

    return Container(
      height: 32,
      color: EatsTheme.panelHeader,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SkeuomorphicHardwareButton(
            label: 'TIMELINE',
            icon: Icons.view_timeline,
            isActive: isTimeline,
            activeColor: EatsTheme.primaryCyan,
            onTap: () {
              if (widget.dawState.arrangerViewMode != ArrangerViewMode.timeline) {
                setState(() {
                  widget.dawState.arrangerViewMode = ArrangerViewMode.timeline;
                });
              }
            },
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(width: 4),
          SkeuomorphicHardwareButton(
            label: 'SEQUENCE',
            icon: Icons.view_column,
            isActive: !isTimeline,
            activeColor: EatsTheme.secondaryMagenta,
            onTap: () {
              if (widget.dawState.arrangerViewMode != ArrangerViewMode.sequence) {
                setState(() {
                  widget.dawState.arrangerViewMode = ArrangerViewMode.sequence;
                });
              }
            },
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Toggle view with Tab key',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text('TAB', style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'TRACKS (${tracks.length})',
            style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          InkWell(
            onTap: widget.dawState.toggleLoop,
            child: Tooltip(
              message: 'Toggle Loop Mode',
              child: Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 13,
                    color: widget.dawState.isLooping ? EatsTheme.accentGold : EatsTheme.textMuted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    widget.dawState.isLooping ? 'LOOP' : 'OFF',
                    style: TextStyle(
                      color: widget.dawState.isLooping ? EatsTheme.accentGold : EatsTheme.textMuted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => PresetSearchDialog.showAddTrack(context, dawState: widget.dawState),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: EatsTheme.primaryCyan.withOpacity(0.18),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.6), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 11, color: EatsTheme.primaryCyan),
                  const SizedBox(width: 2),
                  Text(
                    'TRACK',
                    style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalTrackPropertiesPullout(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final activeTrack = widget.dawState.activeTrack;
    final activeClip = widget.dawState.activeClip;
    final trackColor = activeTrack.color;

    return Container(
      decoration: BoxDecoration(
        color: isGrungy ? const Color(0xFF1B1815) : EatsTheme.panelBackground,
        border: Border(
          left: BorderSide(
            color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.panelHeader,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Vertical Pull Tab Strip (24px wide, full height)
          Tooltip(
            message: _isPropertiesExpanded ? 'Collapse Track Properties' : 'Open Properties Panel',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _isPropertiesExpanded = !_isPropertiesExpanded;
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  if (!_isPropertiesExpanded && details.delta.dx < -2) {
                    _isPropertiesExpanded = true;
                  } else if (_isPropertiesExpanded) {
                    _propertiesWidth = (_propertiesWidth - details.delta.dx)
                        .clamp(_kMinPropertiesWidth, _kMaxPropertiesWidth);
                    if (_propertiesWidth <= _kMinPropertiesWidth + 10 && details.delta.dx > 5) {
                      _isPropertiesExpanded = false;
                      _propertiesWidth = _kDefaultPropertiesWidth;
                    }
                  }
                });
              },
              child: Container(
                width: _kPropertiesPullTabWidth - 1.5,
                height: double.infinity,
                color: isGrungy ? const Color(0xFF28231E) : EatsTheme.panelHeader,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centered vertical visual pill drag handle
                    Container(
                      width: 5,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isGrungy ? const Color(0xFF8C7A6B) : EatsTheme.textMuted,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Top: Active track color circle
                    Positioned(
                      top: 14,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: trackColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: trackColor.withOpacity(0.7), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),

                    // Bottom: Arrow indicator
                    Positioned(
                      bottom: 12,
                      child: Icon(
                        _isPropertiesExpanded ? Icons.chevron_right : Icons.chevron_left,
                        size: 16,
                        color: EatsTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded Vertical Properties Inspector Body
          if (_isPropertiesExpanded)
            Expanded(
              child: ArrangerContextInspector(
                dawState: widget.dawState,
                onClose: () => setState(() => _isPropertiesExpanded = false),
                onResize: (deltaX) {
                  setState(() {
                    _propertiesWidth = (_propertiesWidth - deltaX)
                        .clamp(_kMinPropertiesWidth, _kMaxPropertiesWidth);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMuteButton(TrackChannel track) {
    return GestureDetector(
      onTap: () => widget.dawState.toggleMute(track),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: track.isMuted ? EatsTheme.muteColor : EatsTheme.panelHeader,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text('M', style: TextStyle(color: track.isMuted ? Colors.white : EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSoloButton(TrackChannel track) {
    return GestureDetector(
      onTap: () => widget.dawState.toggleSolo(track),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: track.isSoloed ? EatsTheme.soloColor : EatsTheme.panelHeader,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text('S', style: TextStyle(color: track.isSoloed ? Colors.black : EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFreezeButton(TrackChannel track) {
    if (track.isFolder) return const SizedBox.shrink();

    if (track.isBaking) {
      return Container(
        margin: const EdgeInsets.only(left: 2),
        padding: const EdgeInsets.all(2),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan),
        ),
      );
    }

    final isFrozen = track.isFrozen;
    return Tooltip(
      message: isFrozen
          ? 'Track is Frozen (${track.frozenDurationSec.toStringAsFixed(1)}s audio). Click to unfreeze.'
          : 'Freeze / Bake track to static audio (saves CPU)',
      child: GestureDetector(
        onTap: () => widget.dawState.toggleFreezeTrack(track),
        child: Container(
          margin: const EdgeInsets.only(left: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isFrozen ? EatsTheme.primaryCyan.withOpacity(0.25) : EatsTheme.panelHeader,
            borderRadius: BorderRadius.circular(3),
            border: isFrozen ? Border.all(color: EatsTheme.primaryCyan.withOpacity(0.6), width: 0.8) : null,
          ),
          child: Icon(
            Icons.ac_unit,
            size: 10,
            color: isFrozen ? EatsTheme.primaryCyan : EatsTheme.textMuted,
          ),
        ),
      ),
    );
  }


  Widget _buildFollowModeButton(TrackChannel track) {
    final mode = track.chordFollowMode;
    Color badgeColor;
    switch (mode) {
      case ChordFollowMode.off:
        badgeColor = EatsTheme.textMuted;
        break;
      case ChordFollowMode.bass:
        badgeColor = EatsTheme.primaryCyan;
        break;
      case ChordFollowMode.chord:
        badgeColor = EatsTheme.secondaryMagenta;
        break;
      case ChordFollowMode.scale:
        badgeColor = EatsTheme.accentGold;
        break;
      case ChordFollowMode.colorLead:
        badgeColor = const Color(0xFF00FF66);
        break;
    }

    return PopupMenuButton<String>(
      tooltip: 'Chord Follow: ${mode.displayName} - ${mode.description}',
      color: EatsTheme.controlBackground,
      padding: EdgeInsets.zero,
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 100),
        curve: Curves.fastOutSlowIn,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: mode != ChordFollowMode.off ? badgeColor.withOpacity(0.2) : EatsTheme.panelHeader,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: mode != ChordFollowMode.off ? badgeColor : Colors.white.withOpacity(0.1),
            width: 0.6,
          ),
        ),
        child: Text(
          mode == ChordFollowMode.off ? 'CHORD' : mode.displayName.toUpperCase(),
          style: TextStyle(
            color: mode != ChordFollowMode.off ? badgeColor : EatsTheme.textMuted,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      itemBuilder: (context) {
        return [
          ...ChordFollowMode.values.map((m) {
            return PopupMenuItem<String>(
              value: m.name,
              child: Row(
                children: [
                  Icon(
                    m == mode ? Icons.check_circle : Icons.circle_outlined,
                    size: 13,
                    color: m == mode ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: m == mode ? EatsTheme.primaryCyan : EatsTheme.textPrimary,
                        ),
                      ),
                      Text(
                        m.description,
                        style: TextStyle(fontSize: 8.5, color: EatsTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'bake',
            child: Row(
              children: [
                const Icon(Icons.lock_clock, size: 13, color: EatsTheme.accentGold),
                const SizedBox(width: 8),
                Text(
                  'Bake Chords to MIDI Notes',
                  style: const TextStyle(fontSize: 10.5, color: EatsTheme.accentGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ];
      },
      onSelected: (val) {
        if (val == 'bake') {
          widget.dawState.bakeTrackChordsToMidi(track);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Baked chord follow pitches into MIDI for "${track.name}"'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          final newMode = ChordFollowMode.values.firstWhere((m) => m.name == val, orElse: () => ChordFollowMode.off);
          widget.dawState.setTrackChordFollowMode(track, newMode);
        }
      },
    );
  }



  void _showChordContextMenu(BuildContext context, Offset position, ChordEvent chord) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect rect = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 1, 1),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: rect,
      color: EatsTheme.panelHeader,
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 100),
        curve: Curves.fastOutSlowIn,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.album_outlined, size: 16, color: EatsTheme.primaryCyan),
              const SizedBox(width: 8),
              Text('Edit in Circle of Fifths', style: TextStyle(color: EatsTheme.textPrimary, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF4D6D)),
              SizedBox(width: 8),
              Text('Delete Chord', style: TextStyle(color: Color(0xFFFF4D6D), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'edit') {
        CircleOfFifthsDialog.show(
          context,
          dawState: widget.dawState,
          targetBar: chord.startBar,
          initialChord: chord,
        );
      } else if (choice == 'delete') {
        widget.dawState.removeChord(chord.id);
      }
    });
  }
}

class PatternClipNotePainter extends CustomPainter {
  final TrackClip clip;
  final TrackChannel track;
  final bool isSelected;

  PatternClipNotePainter({
    required this.clip,
    required this.track,
    required this.isSelected,
  });

  // Pre-allocated static reusable Paint and Path instances (0 allocation during playback)
  static final Paint _noteFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _noteBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  static const Color _noteFillCycle0 = Color(0x660B0E14);
  static const Color _noteFillCycleN = Color(0x4D0B0E14);
  static const Color _noteBorderCycle0 = Color(0x66FFFFFF);
  static const Color _noteBorderCycleN = Color(0x40FFFFFF);

  static final Paint _loopLinePaint = Paint()
    ..color = const Color(0x59FFFFFF)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  static final Paint _notchPaint = Paint()
    ..color = const Color(0xE6FFD700)
    ..style = PaintingStyle.fill;
  static final Path _notchPath = Path();

  static final Paint _waveformLinePaint = Paint()
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _centerLinePaint = Paint()
    ..color = const Color(0x40FFFFFF)
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final overview = SamplerEngine.instance.getWaveformOverview(track.sampleName);
    if (track.type == TrackType.sampler || overview != null) {
      if (overview != null) {
        _drawWaveformOverview(canvas, size, overview);
        return;
      }
    }

    List<Note> notesToDraw = clip.evaluatedNotesCache ?? (clip.notes.isNotEmpty ? clip.notes : track.notes);

    if (notesToDraw.isEmpty) {
      final stepNotes = <Note>[];
      for (int i = 0; i < track.steps.length; i++) {
        if (track.steps[i].active) {
          stepNotes.add(Note(
            id: 'step_$i',
            pitch: track.steps[i].pitch,
            startStep: i.toDouble(),
            durationSteps: 1.0,
            velocity: track.steps[i].velocity,
          ));
        }
      }
      notesToDraw = stepNotes;
    }

    if (notesToDraw.isEmpty) return;

    final double totalSteps = (clip.barLength * 16).toDouble();

    int minPitch = 127;
    int maxPitch = 0;
    for (final note in notesToDraw) {
      if (note.pitch < minPitch) minPitch = note.pitch;
      if (note.pitch > maxPitch) maxPitch = note.pitch;
    }

    if (maxPitch - minPitch < 12) {
      final center = (minPitch + maxPitch) ~/ 2;
      minPitch = center - 6;
      maxPitch = center + 6;
    }
    final int pitchSpan = math.max(1, maxPitch - minPitch);

    final int loopBars = clip.effectiveLoopLengthBars;
    final double loopSteps = loopBars * 16.0;
    final int numCycles = clip.isLooped ? (clip.barLength / loopBars).ceil() : 1;

    for (int cycle = 0; cycle < numCycles; cycle++) {
      final double cycleStepOffset = cycle * loopSteps;
      _noteFillPaint.color = cycle == 0 ? _noteFillCycle0 : _noteFillCycleN;
      _noteBorderPaint.color = cycle == 0 ? _noteBorderCycle0 : _noteBorderCycleN;

      for (final note in notesToDraw) {
        final double startStep = note.startStep + cycleStepOffset;
        if (startStep >= totalSteps) continue;

        final double x = (startStep / totalSteps) * size.width;
        final double width = (note.durationSteps / totalSteps) * size.width;
        final double clampedWidth = math.max(2.5, width);

        final double normalizedPitch = ((note.pitch - minPitch) / pitchSpan).clamp(0.0, 1.0);
        const double minNoteHeight = 3.0;
        final double maxNoteHeight = math.min(10.0, size.height * 0.32);
        final double noteHeight = (maxNoteHeight * (note.velocity / 1.0)).clamp(minNoteHeight, maxNoteHeight);
        final double y = (1.0 - normalizedPitch) * (size.height - noteHeight);

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, clampedWidth, noteHeight),
          const Radius.circular(1.0),
        );

        canvas.drawRRect(rect, _noteFillPaint);
        canvas.drawRRect(rect, _noteBorderPaint);

        // Render note syllable lyric text if present
        if (note.lyric != null && note.lyric!.isNotEmpty) {
          final textSpan = TextSpan(
            text: note.lyric,
            style: TextStyle(
              color: Colors.white.withOpacity(cycle == 0 ? 1.0 : 0.8),
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 2)],
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 80.0);
          final textX = (x + 1.0).clamp(0.0, math.max(0.0, size.width - textPainter.width)).toDouble();
          final textY = (y - 8.0).clamp(2.0, math.max(2.0, size.height - 10.0)).toDouble();
          textPainter.paint(canvas, Offset(textX, textY));
        }
      }
    }

    // Draw vertical seam lines and top notch ticks for loop repetitions
    if (clip.isLooped && loopBars > 0 && numCycles > 1) {
      for (int cycle = 1; cycle < numCycles; cycle++) {
        final double cycleX = (cycle * loopSteps / totalSteps) * size.width;
        if (cycleX < size.width) {
          canvas.drawLine(Offset(cycleX, 0), Offset(cycleX, size.height), _loopLinePaint);
          _notchPath.reset();
          _notchPath.moveTo(cycleX - 3.5, 0);
          _notchPath.lineTo(cycleX + 3.5, 0);
          _notchPath.lineTo(cycleX, 5);
          _notchPath.close();
          canvas.drawPath(_notchPath, _notchPaint);
        }
      }
    }
  }

  void _drawWaveformOverview(Canvas canvas, Size size, WaveformOverview overview) {
    if (overview.maxPeaks.isEmpty) return;

    final centerY = size.height / 2.0;
    final totalPoints = overview.maxPeaks.length;
    final dx = size.width / (totalPoints - 1);

    _waveformLinePaint.color = isSelected ? EatsTheme.highlightColor : EatsTheme.primaryCyan;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), _centerLinePaint);

    for (int i = 0; i < totalPoints; i++) {
      final x = i * dx;
      final maxVal = overview.maxPeaks[i].clamp(0.0, 1.0);
      final minVal = overview.minPeaks[i].clamp(-1.0, 0.0);

      final yTop = centerY - (maxVal * (centerY * 0.85));
      final yBottom = centerY - (minVal * (centerY * 0.85));

      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), _waveformLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PatternClipNotePainter oldDelegate) {
    return oldDelegate.clip != clip ||
        oldDelegate.track != track ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.clip.barLength != clip.barLength ||
        oldDelegate.clip.loopLengthBars != clip.loopLengthBars ||
        oldDelegate.clip.notes.length != clip.notes.length ||
        oldDelegate.clip.lyrics.length != clip.lyrics.length ||
        oldDelegate.track.lyrics.length != track.lyrics.length ||
        oldDelegate.track.notes.length != track.notes.length ||
        oldDelegate.track.steps != track.steps;
  }
}

