import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import '../lua/lua_preset_library.dart';
import '../utils/platform_env_helper.dart';
import 'widgets/lcd_display_widget.dart';
import 'widgets/skeuomorphic_hardware_button.dart';
import 'widgets/skeuomorphic_hardware_knob.dart';
import 'widgets/skeuomorphic_hardware_slider.dart';
import 'widgets/stereo_meter_widget.dart';
import 'widgets/modular_fx_rack_widget.dart';
import 'widgets/fx_rack_dialog.dart';
import 'widgets/project_browser_drawer.dart';

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

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (!PlatformEnvHelper.isFlutterTest) {
      _ticker.repeat();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTracks = widget.dawState.visibleTracks;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Master Channel Strip
          _buildMasterChannelStrip(context, widget.dawState),
          VerticalDivider(color: EatsTheme.panelHeader, width: 24, thickness: 1.5),

          // Individual Track Strips (Folder-Aware)
          ...List.generate(visibleTracks.length, (tIdx) {
            return _buildTrackStrip(context, widget.dawState, visibleTracks[tIdx], tIdx);
          }),
        ],
      ),
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

        return Container(
          width: 165,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovering ? EatsTheme.primaryCyan.withOpacity(0.18) : EatsTheme.panelBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovering ? Colors.white : EatsTheme.primaryCyan.withOpacity(0.6),
              width: isHovering ? 2.0 : 1.5,
            ),
            boxShadow: isHovering
                ? [
                    BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.5), blurRadius: 10, spreadRadius: 1),
                  ]
                : const [
                    BoxShadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
                  ],
          ),
          child: Column(
            children: [
              // Top Backlit LCD Screen
              LcdDisplayWidget(
                title: 'MASTER',
                leftText: 'st-out',
                rightText: '${(dawState.masterVolume * 100).toInt()}%',
                width: 148,
                height: 38,
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

              // Fader (Left) + Glass Meter (Right) + FX Button (Far Right)
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

                    // Glass Meter Readout on Right (Animated per frame)
                    AnimatedBuilder(
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
                    const SizedBox(width: 5),

                    // Compact FX Button Column on Far Right of LED readout
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: 'Master Bus FX Rack (Limiter, Compressor, Reverb, etc.)',
                          child: SkeuomorphicHardwareButton(
                            label: 'FX',
                            isActive: dawState.masterTrack.fxRack.any((f) => f.enabled),
                            activeColor: EatsTheme.primaryCyan,
                            onTap: () => _showFXRackDialog(context, dawState, dawState.masterTrack),
                            height: 26,
                            width: 26,
                            padding: EdgeInsets.zero,
                            showLed: false,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
            dawState.activeTabIndex = 0; // Switch to Arranger with Track selected in Inspector
          },
          onSecondaryTap: () {
            final allIdx = dawState.activePattern.tracks.indexOf(track);
            if (allIdx != -1) dawState.activeTrackIndex = allIdx;
            dawState.activeTabIndex = 0;
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
            if (isDoubleTap) {
              if (track.isFolder) {
                dawState.toggleFolderCollapsed(track);
              } else {
                dawState.openFloatingInstrumentWindow(track);
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
                LcdDisplayWidget(
                  title: '${track.isFolder ? "[📁] " : ""}${track.name.toUpperCase()}',
                  leftText: track.pan == 0 ? 'center' : (track.pan < 0 ? 'L${(track.pan.abs() * 100).toInt()}' : 'R${(track.pan * 100).toInt()}'),
                  rightText: '${(track.volume * 100).toInt()}%',
                  width: 124,
                  height: 38,
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

                      // Inset Glass-Encased Stereo Meter on RIGHT side of fader (Animated per frame)
                      AnimatedBuilder(
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
                            height: 26,
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
                            height: 26,
                            width: 26,
                            padding: EdgeInsets.zero,
                            showLed: false,
                            borderRadius: BorderRadius.zero,
                          ),
                          SkeuomorphicHardwareButton(
                            label: 'FX',
                            isActive: track.fxRack.any((f) => f.enabled),
                            activeColor: EatsTheme.primaryCyan,
                            onTap: () => _showFXRackDialog(context, dawState, track),
                            height: 26,
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
}
