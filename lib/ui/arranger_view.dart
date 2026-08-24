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
import 'widgets/project_browser_drawer.dart';
import 'widgets/skeuomorphic_hardware_knob.dart';

class ArrangerView extends StatefulWidget {
  final DawState dawState;

  const ArrangerView({super.key, required this.dawState});

  @override
  State<ArrangerView> createState() => _ArrangerViewState();
}

class _ArrangerViewState extends State<ArrangerView> {
  static const double barWidth = 60.0;
  static const double trackRowHeight = 82.0;
  static const int totalBars = 32;

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
  double _moveDragDxAccumulator = 0.0;
  double _resizeDragDxAccumulator = 0.0;
  double _chordMoveDragDxAccumulator = 0.0;
  double _chordResizeDragDxAccumulator = 0.0;

  DateTime? _lastHeaderTapTime;
  int? _lastHeaderTapTrackIdx;
  DateTime? _lastClipTapTime;
  String? _lastClipTapId;
  int? _dragLoopStartBar;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _leftTrackScroll.dispose();
    _rightGridScroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.dawState.activePattern.tracks;
    final double playheadX = (widget.dawState.arrangerStep / 16.0) * barWidth;
    final double loopStartX = widget.dawState.loopStartBar * barWidth;
    final double loopWidth = (widget.dawState.loopEndBar - widget.dawState.loopStartBar) * barWidth;
    final bool isBrowserOpen = widget.dawState.isBrowserOpen;
    final double drawerWidth = _isPropertiesExpanded
        ? _kPropertiesPullTabWidth + _propertiesWidth
        : _kPropertiesPullTabWidth;

    return Stack(
      children: [
        // Main Multitrack Arranger Content (Timeline & Track Panels)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 150),
          curve: Curves.fastOutSlowIn,
          top: 0,
          bottom: 0,
          left: 0,
          right: (isBrowserOpen ? 320.0 : 0.0) + drawerWidth,
          child: Row(
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
                                    widget.dawState.songKey,
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
                          // Circle of Fifths Dialog Button
                          InkWell(
                            onTap: () {
                              final curBar = (widget.dawState.arrangerStep ~/ 16).clamp(0, totalBars - 1);
                              final existing = widget.dawState.getActiveChordAtBar(curBar);
                              CircleOfFifthsDialog.show(context, dawState: widget.dawState, targetBar: curBar, initialChord: existing);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: EatsTheme.primaryCyan.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Tooltip(
                                message: 'Open Circle of Fifths Chord Selector',
                                child: Icon(Icons.circle_outlined, size: 13, color: EatsTheme.primaryCyan),
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
                                        onTap: () {
                                          final kickPreset = LuaPresetLibrary.presets.firstWhere(
                                            (p) => p.id == 'procedural_kick',
                                            orElse: () => LuaPresetLibrary.presets.first,
                                          );
                                          widget.dawState.addNewPresetTrack(kickPreset);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Added new track "Eats Kick"'),
                                              backgroundColor: EatsTheme.panelHeader,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_circle_outline,
                                              color: isHover ? EatsTheme.primaryCyan : EatsTheme.accentGold,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'ADD TRACK',
                                              style: TextStyle(
                                                color: isHover ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              final track = tracks[trackIdx];
                              final isSelected = trackIdx == widget.dawState.activeTrackIndex;

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
                                    final oldIdx = widget.dawState.activePattern.tracks.indexOf(data);
                                    final newIdx = trackIdx;
                                    if (oldIdx != -1 && oldIdx != newIdx) {
                                      widget.dawState.reorderTracks(oldIdx, newIdx);
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
                                      widget.dawState.activeTrackIndex = trackIdx;
                                      widget.dawState.selectClip(null);
                                    },
                                    onSecondaryTap: () {
                                      setState(() => _isPropertiesExpanded = true);
                                      widget.dawState.activeTrackIndex = trackIdx;
                                      widget.dawState.selectClip(null);
                                    },
                                    onTapDown: (_) {
                                      final now = DateTime.now();
                                      final isDoubleTap = _lastHeaderTapTrackIdx == trackIdx &&
                                          _lastHeaderTapTime != null &&
                                          now.difference(_lastHeaderTapTime!).inMilliseconds < 300;
                                      _lastHeaderTapTime = now;
                                      _lastHeaderTapTrackIdx = trackIdx;

                                      widget.dawState.activeTrackIndex = trackIdx;
                                      widget.dawState.selectClip(null);
                                      if (isDoubleTap) {
                                        // DOUBLE-TAP TRACK HEADER: Open Floating In-App VSTi GUI Window
                                        widget.dawState.openFloatingInstrumentWindow(track);
                                      }
                                    },
                                    child: Container(
                                      height: trackRowHeight,
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        color: isTrackHovering
                                            ? (isTrackReordering ? EatsTheme.primaryCyan.withOpacity(0.2) : EatsTheme.primaryCyan.withOpacity(0.3))
                                            : (isSelected ? EatsTheme.controlBackground : EatsTheme.panelBackground),
                                        border: Border(
                                          top: isTrackReordering
                                              ? BorderSide(color: EatsTheme.primaryCyan, width: 2)
                                              : BorderSide.none,
                                          bottom: BorderSide(
                                            color: isTrackReordering ? EatsTheme.primaryCyan : EatsTheme.panelHeader,
                                            width: isTrackReordering ? 2 : 1,
                                          ),
                                        ),
                                        boxShadow: isTrackHovering
                                            ? [BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.3), blurRadius: 6)]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
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
                                                    Icon(Icons.swap_vert, size: 16, color: track.color),
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
                                                      Expanded(
                                                        child: Text(
                                                          track.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: EatsTheme.getPrimaryFontStyle(
                                                            color: isSelected ? EatsTheme.primaryCyan : EatsTheme.textPrimary,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      _buildFollowModeButton(track),
                                                      const SizedBox(width: 3),
                                                      _buildMuteButton(track),
                                                      const SizedBox(width: 2),
                                                      _buildSoloButton(track),
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
                            final int tappedBar = (localX / barWidth).floor().clamp(0, totalBars - 1);
                            widget.dawState.seekToBar(tappedBar);
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
                                Positioned(
                                  left: playheadX - 6,
                                  top: 2,
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
                                    onTap: () {
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

                              // Rendered Chord Blocks (Drag & Drop Move, Resize Handle & Context Menu)
                              ...widget.dawState.chordTrack.map((chord) {
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
                                    onTap: () {
                                      CircleOfFifthsDialog.show(
                                        context,
                                        dawState: widget.dawState,
                                        targetBar: chord.startBar,
                                        initialChord: chord,
                                      );
                                    },
                                    onSecondaryTapDown: (details) {
                                      _showChordContextMenu(context, details.globalPosition, chord);
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
                                            child: Center(
                                              child: Text(
                                                isHover ? 'Drop preset or SoundFont to create track' : '+ Drop preset here or click Add Track',
                                                style: TextStyle(
                                                  color: isHover ? EatsTheme.primaryCyan : EatsTheme.textMuted.withOpacity(0.4),
                                                  fontSize: 10,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }

                                    final track = tracks[trackIdx];

                                    return Container(
                                      height: trackRowHeight,
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        color: EatsTheme.backgroundDark,
                                        border: Border(bottom: BorderSide(color: EatsTheme.panelHeader, width: 1)),
                                      ),
                                      child: Stack(
                                        children: [
                                           // Bar Grid Lines
                                           Row(
                                             children: List.generate(totalBars, (barIdx) {
                                               return GestureDetector(
                                                 onTap: () {
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

                                           // Per-track Pattern Clips with Smooth Drag-Move, Edge-Resize, and Preset DragTarget
                                           ...track.clips.map((clip) {
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
                                                     onTapDown: (_) {
                                                       final now = DateTime.now();
                                                       final isDoubleTap = _lastClipTapId == clip.id &&
                                                           _lastClipTapTime != null &&
                                                           now.difference(_lastClipTapTime!).inMilliseconds < 300;
                                                       _lastClipTapTime = now;
                                                       _lastClipTapId = clip.id;

                                                       widget.dawState.activeTrackIndex = trackIdx;
                                                       widget.dawState.selectClip(clip);
                                                       if (isDoubleTap) {
                                                         // DOUBLE-TAP CLIP: Open clip in Edit section (Piano Roll / Tracker View)
                                                         widget.dawState.openClipInEditor(clip);
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
                                                     onHorizontalDragStart: (_) {
                                                       _moveDragDxAccumulator = 0.0;
                                                       widget.dawState.beginHistoryTransaction('Move Clip "${clip.name}"', icon: Icons.open_with);
                                                     },
                                                     onHorizontalDragUpdate: (details) {
                                                       _moveDragDxAccumulator += details.delta.dx;
                                                       if (_moveDragDxAccumulator.abs() >= barWidth * 0.5) {
                                                         final shiftBars = (_moveDragDxAccumulator / barWidth).round();
                                                         if (shiftBars != 0) {
                                                           setState(() {
                                                             clip.startBar = (clip.startBar + shiftBars).clamp(0, totalBars - clip.barLength);
                                                           });
                                                           _moveDragDxAccumulator -= shiftBars * barWidth;
                                                         }
                                                       }
                                                     },
                                                     onHorizontalDragEnd: (_) => widget.dawState.commitHistoryTransaction(),
                                                     onHorizontalDragCancel: () => widget.dawState.commitHistoryTransaction(),
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
                                                                          ),
                                                                        ),
                                                                      ],
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

                                                             // 3. Drop Hover Overlay
                                                             if (isPresetHover)
                                                               Positioned.fill(
                                                                 child: Container(
                                                                   color: Colors.black54,
                                                                   alignment: Alignment.center,
                                                                   child: Container(
                                                                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                     decoration: BoxDecoration(
                                                                       color: EatsTheme.accentGold,
                                                                       borderRadius: BorderRadius.circular(4),
                                                                     ),
                                                                     child: const Text(
                                                                       'REPLACE SEQUENCE',
                                                                       style: TextStyle(
                                                                         color: Colors.black,
                                                                         fontWeight: FontWeight.bold,
                                                                         fontSize: 8.5,
                                                                       ),
                                                                     ),
                                                                   ),
                                                                 ),
                                                               ),

                                                             // 4. Right Edge Drag Handle to Resize Clip Length (Transparent Background)
                                                             Positioned(
                                                               right: 0,
                                                               top: 0,
                                                               bottom: 0,
                                                               width: 18,
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
                                       ),
                                    );
                                  },
                                ),
                              ),

                              // Vertical Song Timeline Playhead Line Across Multitrack Rows
                              Positioned(
                                left: playheadX,
                                top: 0,
                                bottom: 0,
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
                            ],
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

    final notePaint = Paint()..style = PaintingStyle.fill;
    final noteBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final note in notesToDraw) {
      final double startStep = note.startStep;
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

      notePaint.color = EatsTheme.backgroundDark.withOpacity(0.40);
      noteBorderPaint.color = Colors.white.withOpacity(0.40);

      canvas.drawRRect(rect, notePaint);
      canvas.drawRRect(rect, noteBorderPaint);
    }
  }

  void _drawWaveformOverview(Canvas canvas, Size size, WaveformOverview overview) {
    if (overview.maxPeaks.isEmpty) return;

    final centerY = size.height / 2.0;
    final totalPoints = overview.maxPeaks.length;
    final dx = size.width / (totalPoints - 1);

    final linePaint = Paint()
      ..color = isSelected ? EatsTheme.highlightColor : EatsTheme.primaryCyan
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), centerLinePaint);

    for (int i = 0; i < totalPoints; i++) {
      final x = i * dx;
      final maxVal = overview.maxPeaks[i].clamp(0.0, 1.0);
      final minVal = overview.minPeaks[i].clamp(-1.0, 0.0);

      final yTop = centerY - (maxVal * (centerY * 0.85));
      final yBottom = centerY - (minVal * (centerY * 0.85));

      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PatternClipNotePainter oldDelegate) {
    return oldDelegate.clip != clip ||
        oldDelegate.track != track ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.clip.notes.length != clip.notes.length ||
        oldDelegate.track.notes.length != track.notes.length ||
        oldDelegate.track.steps != track.steps;
  }
}

