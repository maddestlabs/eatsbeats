import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import '../eatscript/eat_preset_library.dart';
import '../utils/platform_env_helper.dart';
import 'widgets/lcd_display_widget.dart';
import 'widgets/skeuomorphic_hardware_button.dart';
import 'widgets/skeuomorphic_hardware_knob.dart';
import 'widgets/skeuomorphic_hardware_slider.dart';
import 'widgets/stereo_meter_widget.dart';
import 'widgets/modular_fx_rack_widget.dart';
import 'widgets/fx_rack_dialog.dart';
import 'widgets/ai_assistant_dialog.dart';
import 'widgets/project_browser_drawer.dart';
import 'widgets/track_properties_pullout.dart';

class MixerView extends StatefulWidget {
  final DawState dawState;

  const MixerView({super.key, required this.dawState});

  @override
  State<MixerView> createState() => _MixerViewState();
}

class _MixerViewState extends State<MixerView> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  DateTime? _lastTapTime;
  int? _lastTapTrackIdx;
  bool _isPropertiesExpanded = true;
  double _propertiesWidth = TrackPropertiesPullout.defaultPropertiesWidth;

  @override
  void initState() {
    super.initState();
    widget.dawState.selectClip(null);
    widget.dawState.addListener(_onDawStateChanged);
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _ticker.addListener(() {
      widget.dawState.audioEngine.updateMeters();
    });
    if (!PlatformEnvHelper.isFlutterTest) {
      _ticker.repeat();
    }
  }

  void _onDawStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MixerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dawState != widget.dawState) {
      oldWidget.dawState.removeListener(_onDawStateChanged);
      widget.dawState.addListener(_onDawStateChanged);
    }
  }

  @override
  void dispose() {
    widget.dawState.removeListener(_onDawStateChanged);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTracks = widget.dawState.visibleTracks;
    final bool isBrowserOpen = widget.dawState.isBrowserOpen;
    final double drawerWidth = _isPropertiesExpanded
        ? TrackPropertiesPullout.pullTabWidth + _propertiesWidth
        : TrackPropertiesPullout.pullTabWidth;

    return Stack(
      children: [
        // Main Mixer Content (Master Channel Pinned Left + Scrollable Track Strips)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 150),
          curve: Curves.fastOutSlowIn,
          top: 0,
          bottom: 0,
          left: 0,
          right: (isBrowserOpen ? 320.0 : 0.0) + drawerWidth,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pinned Master Channel Strip (Always in view on the left)
                _buildMasterChannelStrip(context, widget.dawState),
                VerticalDivider(color: EatsTheme.panelHeader, width: 24, thickness: 1.5),

                // Horizontally Scrollable Virtualized Track Strips
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: visibleTracks.length,
                    itemBuilder: (context, tIdx) {
                      return _buildTrackStrip(context, widget.dawState, visibleTracks[tIdx], tIdx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right-Sidebar Vertical Track Properties Pullout Drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 150),
          curve: Curves.fastOutSlowIn,
          top: 0,
          bottom: 0,
          right: isBrowserOpen ? 320.0 : 0.0,
          width: drawerWidth,
          child: TrackPropertiesPullout(
            dawState: widget.dawState,
            isExpanded: _isPropertiesExpanded,
            propertiesWidth: _propertiesWidth,
            onToggleExpand: () {
              setState(() {
                _isPropertiesExpanded = !_isPropertiesExpanded;
                if (_isPropertiesExpanded) {
                  widget.dawState.selectClip(null);
                }
              });
            },
            onExpansionChanged: (expanded) {
              setState(() {
                _isPropertiesExpanded = expanded;
                if (_isPropertiesExpanded) {
                  widget.dawState.selectClip(null);
                }
              });
            },
            onWidthChanged: (width) {
              setState(() {
                _propertiesWidth = width;
              });
            },
            onClose: () => setState(() => _isPropertiesExpanded = false),
          ),
        ),
      ],
    );
  }

  Widget _buildMasterChannelStrip(BuildContext context, DawState dawState) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data is LuaPreset) {
          return data.isAudioFx;
        }
        return false;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is LuaPreset && data.isAudioFx) {
          dawState.addAudioFXFromPreset(dawState.masterTrack, data);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added FX "${data.name}" to Master Bus FX chain'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final isSelected = dawState.isMasterSelected;

        return GestureDetector(
          onTap: () {
            dawState.selectMasterTrack();
            setState(() => _isPropertiesExpanded = true);
          },
          onSecondaryTap: () {
            dawState.selectMasterTrack();
            setState(() => _isPropertiesExpanded = true);
          },
          child: Container(
            width: 140,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHovering
                  ? EatsTheme.primaryCyan.withOpacity(0.18)
                  : (isSelected ? EatsTheme.controlBackground : EatsTheme.panelBackground),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovering
                    ? Colors.white
                    : (isSelected ? EatsTheme.primaryCyan : EatsTheme.primaryCyan.withOpacity(0.6)),
                width: isHovering || isSelected ? 2.0 : 1.5,
              ),
              boxShadow: isHovering || isSelected
                  ? [
                      BoxShadow(color: EatsTheme.primaryCyan.withOpacity(isSelected ? 0.35 : 0.5), blurRadius: 10, spreadRadius: 1),
                    ]
                  : const [
                      BoxShadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
                    ],
            ),
            child: Column(
              children: [
                // Top Backlit LCD Screen
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: 'Configure Master Bus & FX in Sidebar',
                    child: LcdDisplayWidget(
                      title: 'MASTER',
                      leftText: 'st-out',
                      rightText: '${(dawState.masterVolume * 100).toInt()}%',
                      width: 124,
                      height: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Master Balance Control
                Center(
                  child: SkeuomorphicHardwareKnob(
                    label: 'Master Balance',
                    showLabelText: false,
                    value: 0.0,
                    min: -1.0,
                    max: 1.0,
                    defaultValue: 0.0,
                    size: 34.0,
                    accentColor: EatsTheme.primaryCyan,
                    onChanged: (_) {},
                    formatValue: (v) => 'C',
                  ),
                ),

                const SizedBox(height: 10),

                // Fader (Left) + Glass Meter (Right)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fader Slider on Left (with level scale markings)
                      Expanded(
                        child: SkeuomorphicHardwareSlider(
                          value: dawState.masterVolume,
                          min: 0.0,
                          max: 1.5,
                          defaultValue: 0.85,
                          label: 'Master Volume',
                          activeColor: EatsTheme.primaryCyan,
                          orientation: Axis.vertical,
                          length: 160.0,
                          showLevelMarkings: true,
                          onChanged: (val) => dawState.setMasterVolume(val),
                          onChangeStart: () => dawState.beginHistoryTransaction('Master Volume', icon: Icons.volume_up),
                          onChangeEnd: () => dawState.commitHistoryTransaction(),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Glass Meter Readout on Right (Isolated RepaintBoundary)
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _ticker,
                          builder: (context, _) {
                            return StereoMeterWidget(
                              leftLevel: dawState.audioEngine.leftPeak,
                              rightLevel: dawState.audioEngine.rightPeak,
                              accentColor: EatsTheme.primaryCyan,
                              width: 38.0,
                              height: double.infinity,
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
      },
    );
  }

  Widget _buildTrackStrip(BuildContext context, DawState dawState, TrackChannel track, int trackIdx) {
    final isSelected = dawState.activeTrack.id == track.id;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data is SoundFontDragItem) return true;
        if (data is LuaPreset) {
          return data.isAudioFx || data.isInstrument;
        }
        return false;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is SoundFontDragItem) {
          dawState.applySoundFont(data.fontId, displayName: data.displayName, targetTrack: track);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched ${track.name} SoundFont to "${data.displayName}"'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (data is LuaPreset) {
          dawState.applyPreset(data, targetTrack: track);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data.isInstrument
                  ? 'Applied instrument "${data.name}" to ${track.name}'
                  : 'Added FX "${data.name}" to ${track.name} FX chain'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return GestureDetector(
          onLongPress: () {
            final allIdx = dawState.activePattern.tracks.indexOf(track);
            if (allIdx != -1) dawState.activeTrackIndex = allIdx;
            dawState.selectClip(null);
            setState(() => _isPropertiesExpanded = true);
          },
          onSecondaryTap: () {
            final allIdx = dawState.activePattern.tracks.indexOf(track);
            if (allIdx != -1) dawState.activeTrackIndex = allIdx;
            dawState.selectClip(null);
            setState(() => _isPropertiesExpanded = true);
          },
          onTapDown: (_) {
            final now = DateTime.now();
            final isDoubleTap = _lastTapTrackIdx == trackIdx &&
                _lastTapTime != null &&
                now.difference(_lastTapTime!).inMilliseconds < 300;
            _lastTapTime = now;
            _lastTapTrackIdx = trackIdx;

            final allIdx = dawState.activePattern.tracks.indexOf(track);
            if (allIdx != -1) dawState.activeTrackIndex = allIdx;
            dawState.selectClip(null);
            setState(() => _isPropertiesExpanded = true);
            if (isDoubleTap) {
              if (track.isFolder) {
                dawState.toggleFolderCollapsed(track);
              } else {
                dawState.openFullscreenDevice(track);
              }
            }
          },
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHovering
                  ? track.color.withOpacity(0.2)
                  : (isSelected ? EatsTheme.controlBackground : (track.isFolder ? const Color(0xFF141A24) : EatsTheme.panelBackground)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovering ? Colors.white : (isSelected ? track.color : (track.isFolder ? track.color.withOpacity(0.5) : Colors.transparent)),
                width: isHovering ? 2.0 : 1.5,
              ),
              boxShadow: isHovering
                  ? [
                      BoxShadow(color: track.color.withOpacity(0.6), blurRadius: 10, spreadRadius: 1),
                    ]
                  : const [
                      BoxShadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
                    ],
            ),
            child: Column(
              children: [
                if (track.isFolder) ...[
                  Row(
                    children: [
                      Icon(track.isCollapsed ? Icons.folder : Icons.folder_open, size: 12, color: track.color),
                      const SizedBox(width: 4),
                      Text('FOLDER', style: TextStyle(color: track.color, fontSize: 8, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      InkWell(
                        onTap: () => dawState.toggleFolderCollapsed(track),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: EatsTheme.panelBackground,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: track.color.withOpacity(0.4)),
                          ),
                          child: Text(
                            track.isCollapsed ? 'EXPAND' : 'FOLD',
                            style: TextStyle(color: track.color, fontSize: 7, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                // Top Backlit LCD Screen
                GestureDetector(
                  onTap: () {
                    final allIdx = dawState.activePattern.tracks.indexOf(track);
                    if (allIdx != -1) dawState.activeTrackIndex = allIdx;
                    dawState.selectClip(null);
                    setState(() => _isPropertiesExpanded = true);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Configure ${track.name} Properties',
                      child: LcdDisplayWidget(
                        title: '${track.isFolder ? "[📁] " : ""}${track.name.toUpperCase()}',
                        leftText: track.pan == 0 ? 'center' : (track.pan < 0 ? 'L${(track.pan.abs() * 100).toInt()}' : 'R${(track.pan * 100).toInt()}'),
                        rightText: '${(track.volume * 100).toInt()}%',
                        width: 124,
                        height: 38,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Hardware Knob Row (Pan knob)
                Center(
                  child: SkeuomorphicHardwareKnob(
                    label: 'Pan',
                    showLabelText: false,
                    value: track.pan,
                    min: -1.0,
                    max: 1.0,
                    defaultValue: 0.0,
                    size: 34.0,
                    accentColor: track.color,
                    onChanged: (val) => dawState.setTrackPan(track, val),
                    onChangeStart: () => dawState.beginHistoryTransaction('Pan (${track.name})', icon: Icons.tune),
                    onChangeEnd: () => dawState.commitHistoryTransaction(),
                    formatValue: (v) => v == 0 ? 'C' : (v < 0 ? 'L${(v.abs() * 100).toInt()}' : 'R${(v * 100).toInt()}'),
                  ),
                ),

                const SizedBox(height: 10),

                // Fader (Left) + Glass Meter (Right) + Mechanical Buttons Column (Far Right)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Vertical Console Fader with level scale markings
                      Expanded(
                        child: SkeuomorphicHardwareSlider(
                          value: track.volume,
                          min: 0.0,
                          max: 1.5,
                          defaultValue: 1.0,
                          label: '${track.name} Volume',
                          activeColor: track.color,
                          orientation: Axis.vertical,
                          length: 160.0,
                          showLevelMarkings: true,
                          onChanged: (val) => dawState.setTrackVolume(track, val),
                          onChangeStart: () => dawState.beginHistoryTransaction('Volume (${track.name})', icon: Icons.volume_up),
                          onChangeEnd: () => dawState.commitHistoryTransaction(),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Inset Glass-Encased Stereo Meter on RIGHT side of fader (Isolated RepaintBoundary)
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _ticker,
                          builder: (context, _) {
                            return StereoMeterWidget(
                              leftLevel: dawState.audioEngine.getTrackLeftPeak(track.id),
                              rightLevel: dawState.audioEngine.getTrackRightPeak(track.id),
                              accentColor: track.color,
                              width: 38.0,
                              height: double.infinity,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Compact Vertical Attached Hardware Button Column
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SkeuomorphicHardwareButton(
                            label: 'm',
                            isActive: track.isMuted,
                            activeColor: EatsTheme.muteColor,
                            onTap: () => dawState.toggleMute(track),
                            height: 24,
                            width: 26,
                            padding: EdgeInsets.zero,
                            showLed: false,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                          SkeuomorphicHardwareButton(
                            label: 's',
                            isActive: track.isSoloed,
                            activeColor: EatsTheme.soloColor,
                            onTap: () => dawState.toggleSolo(track),
                            height: 24,
                            width: 26,
                            padding: EdgeInsets.zero,
                            showLed: false,
                            borderRadius: track.isFolder ? const BorderRadius.vertical(bottom: Radius.circular(4)) : BorderRadius.zero,
                          ),
                          if (!track.isFolder)
                            SkeuomorphicHardwareButton(
                              label: '❄',
                              isActive: track.isFrozen,
                              activeColor: EatsTheme.primaryCyan,
                              onTap: () => dawState.toggleFreezeTrack(track),
                              height: 24,
                              width: 26,
                              padding: EdgeInsets.zero,
                              showLed: false,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
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
      },
    );
  }

  void _showFXRackDialog(BuildContext context, DawState dawState, TrackChannel track) {
    showFxRackDialog(context, dawState, track);
  }

  void _showTrackEqDialog(BuildContext context, DawState dawState, TrackChannel track) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: EatsTheme.panelBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: track.color, width: 1.5),
              ),
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.tune, color: track.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${track.name.toUpperCase()} — CHANNEL EQ',
                            style: TextStyle(
                              color: EatsTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SkeuomorphicHardwareButton(
                          label: track.eqEnabled ? 'ACTIVE' : 'BYPASS',
                          isActive: track.eqEnabled,
                          activeColor: track.color,
                          onTap: () {
                            dawState.setTrackEq(track: track, enabled: !track.eqEnabled);
                            setDialogState(() {});
                          },
                          height: 24,
                          width: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: EatsTheme.textSecondary,
                          onPressed: () => Navigator.of(ctx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Knob Row 1: HPF Cutoff & Low Shelf
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SkeuomorphicHardwareKnob(
                          label: 'HPF CUT',
                          value: track.eqHpf,
                          min: 20.0,
                          max: 500.0,
                          defaultValue: 20.0,
                          size: 44,
                          accentColor: track.color,
                          onChanged: (val) {
                            dawState.setTrackEq(track: track, hpf: val);
                            setDialogState(() {});
                          },
                          formatValue: (v) => '${v.toInt()}Hz',
                        ),
                        SkeuomorphicHardwareKnob(
                          label: 'LOW GAIN',
                          value: track.eqLowGain,
                          min: -18.0,
                          max: 18.0,
                          defaultValue: 0.0,
                          size: 44,
                          accentColor: track.color,
                          onChanged: (val) {
                            dawState.setTrackEq(track: track, lowGain: val);
                            setDialogState(() {});
                          },
                          formatValue: (v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}dB',
                        ),
                        SkeuomorphicHardwareKnob(
                          label: 'HIGH GAIN',
                          value: track.eqHighGain,
                          min: -18.0,
                          max: 18.0,
                          defaultValue: 0.0,
                          size: 44,
                          accentColor: track.color,
                          onChanged: (val) {
                            dawState.setTrackEq(track: track, highGain: val);
                            setDialogState(() {});
                          },
                          formatValue: (v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}dB',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Knob Row 2: Parametric Mid Bell (Freq, Gain, Q)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SkeuomorphicHardwareKnob(
                          label: 'MID FREQ',
                          value: track.eqMidFreq,
                          min: 200.0,
                          max: 8000.0,
                          defaultValue: 1000.0,
                          size: 44,
                          accentColor: track.color,
                          onChanged: (val) {
                            dawState.setTrackEq(track: track, midFreq: val);
                            setDialogState(() {});
                          },
                          formatValue: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '${v.toInt()}Hz',
                        ),
                        SkeuomorphicHardwareKnob(
                          label: 'MID GAIN',
                          value: track.eqMidGain,
                          min: -18.0,
                          max: 18.0,
                          defaultValue: 0.0,
                          size: 44,
                          accentColor: track.color,
                          onChanged: (val) {
                            dawState.setTrackEq(track: track, midGain: val);
                            setDialogState(() {});
                          },
                          formatValue: (v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}dB',
                        ),
                        SkeuomorphicHardwareKnob(
                          label: 'MID Q',
                          value: track.eqMidQ,
                          min: 0.3,
                          max: 10.0,
                          defaultValue: 1.0,
                          size: 44,
                          accentColor: track.color,
                          onChanged: (val) {
                            dawState.setTrackEq(track: track, midQ: val);
                            setDialogState(() {});
                          },
                          formatValue: (v) => v.toStringAsFixed(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Reset button
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('RESET FLAT', style: TextStyle(fontSize: 10)),
                        style: TextButton.styleFrom(
                          foregroundColor: EatsTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        onPressed: () {
                          dawState.setTrackEq(
                            track: track,
                            hpf: 20.0,
                            lowGain: 0.0,
                            midFreq: 1000.0,
                            midGain: 0.0,
                            midQ: 1.0,
                            highGain: 0.0,
                          );
                          setDialogState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMasterBusDialog(BuildContext context, DawState dawState) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: EatsTheme.panelBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: EatsTheme.primaryCyan, width: 1.5),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.equalizer, color: EatsTheme.primaryCyan, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'MASTER BUS CONSOLE',
                            style: TextStyle(
                              color: EatsTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: EatsTheme.textSecondary,
                          onPressed: () => Navigator.of(ctx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // SECTION 1: MASTER PRECISION EQ
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EatsTheme.controlBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MASTER 4-BAND EQ', style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SkeuomorphicHardwareKnob(
                                label: 'SUB CUT',
                                value: dawState.masterSubCut,
                                min: 20.0,
                                max: 45.0,
                                defaultValue: 25.0,
                                size: 40,
                                accentColor: EatsTheme.primaryCyan,
                                onChanged: (val) {
                                  dawState.setMasterEq(subCut: val);
                                  setDialogState(() {});
                                },
                                formatValue: (v) => '${v.toInt()}Hz',
                              ),
                              SkeuomorphicHardwareKnob(
                                label: 'LOW GAIN',
                                value: dawState.masterLowGain,
                                min: -12.0,
                                max: 12.0,
                                defaultValue: 0.0,
                                size: 40,
                                accentColor: EatsTheme.primaryCyan,
                                onChanged: (val) {
                                  dawState.setMasterEq(lowGain: val);
                                  setDialogState(() {});
                                },
                                formatValue: (v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}dB',
                              ),
                              SkeuomorphicHardwareKnob(
                                label: 'MID GAIN',
                                value: dawState.masterMidGain,
                                min: -12.0,
                                max: 12.0,
                                defaultValue: 0.0,
                                size: 40,
                                accentColor: EatsTheme.primaryCyan,
                                onChanged: (val) {
                                  dawState.setMasterEq(midGain: val);
                                  setDialogState(() {});
                                },
                                formatValue: (v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}dB',
                              ),
                              SkeuomorphicHardwareKnob(
                                label: 'HIGH GAIN',
                                value: dawState.masterHighGain,
                                min: -12.0,
                                max: 12.0,
                                defaultValue: 0.0,
                                size: 40,
                                accentColor: EatsTheme.primaryCyan,
                                onChanged: (val) {
                                  dawState.setMasterEq(highGain: val);
                                  setDialogState(() {});
                                },
                                formatValue: (v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}dB',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SECTION 2: TRUE PEAK BRICKWALL LIMITER
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EatsTheme.controlBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('TRUE PEAK BRICKWALL LIMITER', style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              SkeuomorphicHardwareButton(
                                label: dawState.masterLimiterEnabled ? 'ON' : 'OFF',
                                isActive: dawState.masterLimiterEnabled,
                                activeColor: EatsTheme.primaryCyan,
                                onTap: () {
                                  dawState.setMasterLimiter(enabled: !dawState.masterLimiterEnabled);
                                  setDialogState(() {});
                                },
                                height: 20,
                                width: 44,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SkeuomorphicHardwareKnob(
                                label: 'CEILING',
                                value: dawState.masterCeilingDbfs,
                                min: -2.0,
                                max: 0.0,
                                defaultValue: -0.3,
                                size: 40,
                                accentColor: EatsTheme.primaryCyan,
                                onChanged: (val) {
                                  dawState.setMasterLimiter(ceilingDbfs: val);
                                  setDialogState(() {});
                                },
                                formatValue: (v) => '${v.toStringAsFixed(1)}dB',
                              ),
                              SkeuomorphicHardwareKnob(
                                label: 'DRIVE BOOST',
                                value: dawState.masterLimiterDrive,
                                min: 0.0,
                                max: 12.0,
                                defaultValue: 0.0,
                                size: 40,
                                accentColor: EatsTheme.primaryCyan,
                                onChanged: (val) {
                                  dawState.setMasterLimiter(driveDb: val);
                                  setDialogState(() {});
                                },
                                formatValue: (v) => '+${v.toStringAsFixed(1)}dB',
                              ),
                              SkeuomorphicHardwareKnob(
                                label: 'TARGET LUFS',
                                value: dawState.masterTargetLufs,
                                min: -24.0,
                                max: -6.0,
                                defaultValue: -14.0,
                                size: 40,
                                accentColor: EatsTheme.primaryCyan,
                                onChanged: (val) {
                                  dawState.setMasterLimiter(targetLufs: val);
                                  setDialogState(() {});
                                },
                                formatValue: (v) => '${v.toInt()} LUFS',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SECTION 3: GEMINI AI AUTO-MASTER TRIGGER
                    SkeuomorphicHardwareButton(
                      label: '✨ OPEN GEMINI AI AUTO-MIX & MASTER',
                      isActive: true,
                      activeColor: EatsTheme.primaryCyan,
                      height: 34,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        AiAssistantDialog.show(context, dawState, initialTab: 0);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
