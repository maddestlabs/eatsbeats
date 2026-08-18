import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../audio/sampler_engine.dart';
import '../lua/lua_preset_library.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/eatsbits_slider.dart';
import 'widgets/fx_rack_dialog.dart';
import 'widgets/project_browser_drawer.dart';
import 'widgets/rename_track_dialog.dart';
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

  bool _isSyncingScroll = false;
  bool _isMiddleMouseDragging = false;
  double _moveDragDxAccumulator = 0.0;
  double _resizeDragDxAccumulator = 0.0;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.dawState.activePattern.tracks;
    final double playheadX = (widget.dawState.arrangerStep / 16.0) * barWidth;
    final double loopStartX = widget.dawState.loopStartBar * barWidth;
    final double loopWidth = (widget.dawState.loopEndBar - widget.dawState.loopStartBar) * barWidth;

    return Column(
      children: [
        // Multitrack Grid & Track Panels (Synchronized Scroll)
        Expanded(
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
                    Expanded(
                      child: DragTarget<Object>(
                        onWillAcceptWithDetails: (details) => details.data is LuaPreset || details.data is SoundFontDragItem,
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
                          } else if (data is LuaPreset) {
                            final preset = data;
                            if (preset.isInstrument) {
                              widget.dawState.addNewPresetTrack(preset);
                            } else {
                              widget.dawState.addNewPresetTrack(
                                LuaPresetLibrary.getPresetsByCategory(LuaPresetCategory.instrument).first,
                              );
                              widget.dawState.applyPreset(preset, targetTrack: widget.dawState.activeTrack);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Created new track with preset "${preset.name}"'),
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
                                  onWillAcceptWithDetails: (details) => details.data is LuaPreset || details.data is SoundFontDragItem,
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
                                    } else if (data is LuaPreset) {
                                      widget.dawState.addNewPresetTrack(data);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Created new track with preset "${data.name}"'),
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
                                onWillAcceptWithDetails: (details) => details.data is LuaPreset || details.data is SoundFontDragItem,
                                onAcceptWithDetails: (details) {
                                  final data = details.data;
                                  if (data is SoundFontDragItem) {
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(preset.isInstrument
                                            ? 'Applied instrument "${preset.name}" to ${track.name}'
                                            : 'Added FX "${preset.name}" to ${track.name} chain'),
                                        backgroundColor: EatsTheme.panelHeader,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                builder: (context, trackHoverData, _) {
                                  final isTrackHovering = trackHoverData.isNotEmpty;

                                  return GestureDetector(
                                    onLongPress: () => showRenameTrackDialog(context, widget.dawState, track),
                                    onSecondaryTap: () => showRenameTrackDialog(context, widget.dawState, track),
                                    onTapDown: (_) {
                                      final now = DateTime.now();
                                      final isDoubleTap = _lastHeaderTapTrackIdx == trackIdx &&
                                          _lastHeaderTapTime != null &&
                                          now.difference(_lastHeaderTapTime!).inMilliseconds < 300;
                                      _lastHeaderTapTime = now;
                                      _lastHeaderTapTrackIdx = trackIdx;

                                      widget.dawState.activeTrackIndex = trackIdx;
                                      if (isDoubleTap) {
                                        // DOUBLE-TAP TRACK HEADER: Navigate to Track Inspector tab
                                        widget.dawState.activeTabIndex = 2; // Track section
                                      }
                                    },
                                    child: Container(
                                      height: trackRowHeight,
                                      margin: const EdgeInsets.only(bottom: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isTrackHovering
                                            ? EatsTheme.primaryCyan.withOpacity(0.3)
                                            : (isSelected ? EatsTheme.controlBackground : EatsTheme.panelBackground),
                                        border: Border(
                                          left: BorderSide(
                                            color: isTrackHovering ? EatsTheme.primaryCyan : track.color,
                                            width: isTrackHovering ? 6 : 4,
                                          ),
                                          bottom: BorderSide(color: EatsTheme.panelHeader, width: 1),
                                        ),
                                        boxShadow: isTrackHovering
                                            ? [BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.3), blurRadius: 6)]
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Row 1: Readable Name (with emoji support) & M, S, FX Action Buttons
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
                                              const SizedBox(width: 4),
                                              _buildMuteButton(track),
                                              const SizedBox(width: 2),
                                              _buildSoloButton(track),
                                              const SizedBox(width: 2),
                                              _buildFXButton(track),
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
                                                      child: EatsBitsSlider(
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
                                        onWillAcceptWithDetails: (details) => details.data is LuaPreset || details.data is SoundFontDragItem,
                                        onAcceptWithDetails: (details) {
                                          final data = details.data;
                                          if (data is SoundFontDragItem) {
                                            widget.dawState.addNewSoundFontTrack(data.fontId, displayName: data.displayName);
                                          } else if (data is LuaPreset) {
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
                                           // Bar Grid Lines (With Preset DragTarget Support)
                                           Row(
                                             children: List.generate(totalBars, (barIdx) {
                                               return DragTarget<Object>(
                                                 onWillAcceptWithDetails: (details) => details.data is LuaPreset,
                                                 onAcceptWithDetails: (details) {
                                                   final data = details.data;
                                                   if (data is LuaPreset) {
                                                     widget.dawState.activeTrackIndex = trackIdx;
                                                     widget.dawState.addClipWithPresetToTrack(track, barIdx, data);
                                                     ScaffoldMessenger.of(context).showSnackBar(
                                                       SnackBar(
                                                         content: Text('Created clip "${data.name}" at Bar ${barIdx + 1}'),
                                                         backgroundColor: EatsTheme.panelHeader,
                                                         duration: const Duration(seconds: 2),
                                                       ),
                                                     );
                                                   }
                                                 },
                                                 builder: (context, hoverData, _) {
                                                   final isHover = hoverData.isNotEmpty;
                                                   return GestureDetector(
                                                     onTap: () {
                                                       widget.dawState.activeTrackIndex = trackIdx;
                                                       widget.dawState.addClipToTrack(track, barIdx);
                                                     },
                                                     child: Container(
                                                       width: barWidth,
                                                       height: trackRowHeight,
                                                       decoration: BoxDecoration(
                                                         color: isHover ? EatsTheme.primaryCyan.withOpacity(0.18) : Colors.transparent,
                                                         border: Border(
                                                           right: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                                                           left: isHover ? BorderSide(color: EatsTheme.primaryCyan, width: 1.5) : BorderSide.none,
                                                         ),
                                                       ),
                                                     ),
                                                   );
                                                 },
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
                                                 onWillAcceptWithDetails: (details) => details.data is LuaPreset,
                                                 onAcceptWithDetails: (details) {
                                                   final data = details.data;
                                                   if (data is LuaPreset) {
                                                     widget.dawState.activeTrackIndex = trackIdx;
                                                     widget.dawState.selectClip(clip);
                                                     widget.dawState.applyPresetToClip(track, clip, data);
                                                     ScaffoldMessenger.of(context).showSnackBar(
                                                       SnackBar(
                                                         content: Text('Applied sequence "${data.name}" to clip'),
                                                         backgroundColor: EatsTheme.panelHeader,
                                                         duration: const Duration(seconds: 2),
                                                       ),
                                                     );
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

                                                             // 2. Top-Left Clip Title Badge with Background Container
                                                             Positioned(
                                                               left: 4,
                                                               top: 3,
                                                               child: Container(
                                                                 padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                 decoration: BoxDecoration(
                                                                   color: EatsTheme.backgroundDark.withOpacity(0.72),
                                                                   borderRadius: BorderRadius.circular(3),
                                                                   border: Border.all(
                                                                     color: isClipSelected ? EatsTheme.highlightColor.withOpacity(0.8) : Colors.white12,
                                                                     width: 0.8,
                                                                   ),
                                                                 ),
                                                                 child: Row(
                                                                   mainAxisSize: MainAxisSize.min,
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
                                                                     Text(
                                                                       clip.name,
                                                                       style: TextStyle(
                                                                         color: isClipSelected ? EatsTheme.highlightColor : Colors.white,
                                                                         fontWeight: FontWeight.bold,
                                                                         fontSize: 9,
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
  ],
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

  Widget _buildFXButton(TrackChannel track) {
    final hasFX = track.fxRack.any((f) => f.enabled);
    return GestureDetector(
      onTap: () {
        final tIdx = widget.dawState.activePattern.tracks.indexWhere((t) => t.id == track.id);
        if (tIdx != -1) {
          widget.dawState.activeTrackIndex = tIdx;
        }
        showFxRackDialog(context, widget.dawState, track);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: hasFX ? EatsTheme.primaryCyan.withOpacity(0.3) : EatsTheme.panelHeader,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: hasFX ? EatsTheme.primaryCyan : Colors.transparent, width: 0.5),
        ),
        child: Text(
          'FX',
          style: TextStyle(
            color: hasFX ? EatsTheme.primaryCyan : EatsTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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

    List<Note> notesToDraw = clip.notes.isNotEmpty ? clip.notes : track.notes;

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

