import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/lcd_display_widget.dart';
import 'widgets/skeuomorphic_hardware_button.dart';
import 'widgets/skeuomorphic_hardware_knob.dart';
import 'widgets/skeuomorphic_hardware_slider.dart';
import 'widgets/stereo_meter_widget.dart';
import 'widgets/modular_fx_rack_widget.dart';
import 'widgets/rename_track_dialog.dart';



class MixerView extends StatefulWidget {
  final DawState dawState;

  const MixerView({super.key, required this.dawState});

  @override
  State<MixerView> createState() => _MixerViewState();
}

class _MixerViewState extends State<MixerView> {
  DateTime? _lastTapTime;
  int? _lastTapTrackIdx;

  @override
  Widget build(BuildContext context) {
    final pattern = widget.dawState.activePattern;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Master Channel Strip
          _buildMasterChannelStrip(widget.dawState),
          VerticalDivider(color: EatsTheme.panelHeader, width: 24, thickness: 1.5),

          // Individual Track Strips
          ...List.generate(pattern.tracks.length, (tIdx) {
            return _buildTrackStrip(context, widget.dawState, pattern.tracks[tIdx], tIdx);
          }),
        ],
      ),
    );
  }

  Widget _buildMasterChannelStrip(DawState dawState) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EatsTheme.panelBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.6), width: 1.5),
        boxShadow: const [
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
            width: 124,
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
              size: 36.0,
              accentColor: EatsTheme.primaryCyan,
              onChanged: (_) {},
              formatValue: (v) => 'C',
            ),
          ),

          const SizedBox(height: 10),

          // Fader + Inset Glass Meter on Right
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
                  ),
                ),
                const SizedBox(width: 4),

                // Glass Meter Readout on Right
                StereoMeterWidget(
                  leftLevel: dawState.audioEngine.leftPeak,
                  rightLevel: dawState.audioEngine.rightPeak,
                  accentColor: EatsTheme.primaryCyan,
                  width: 38.0,
                  height: double.infinity,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackStrip(BuildContext context, DawState dawState, TrackChannel track, int trackIdx) {
    final isSelected = trackIdx == dawState.activeTrackIndex;
    final leftPeak = dawState.audioEngine.getTrackLeftPeak(track.id);
    final rightPeak = dawState.audioEngine.getTrackRightPeak(track.id);

    return GestureDetector(
      onLongPress: () => showRenameTrackDialog(context, dawState, track),
      onSecondaryTap: () => showRenameTrackDialog(context, dawState, track),
      onTapDown: (_) {
        final now = DateTime.now();
        final isDoubleTap = _lastTapTrackIdx == trackIdx &&
            _lastTapTime != null &&
            now.difference(_lastTapTime!).inMilliseconds < 300;
        _lastTapTime = now;
        _lastTapTrackIdx = trackIdx;

        dawState.activeTrackIndex = trackIdx;
        if (isDoubleTap) {
          dawState.activeTabIndex = 2; // Switch to TRACK section
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? EatsTheme.controlBackground : EatsTheme.panelBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? track.color : Colors.transparent, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
          ],
        ),
        child: Column(
          children: [
            // Top Backlit LCD Screen
            LcdDisplayWidget(
              title: '${trackIdx + 1}  ${track.name.toUpperCase()}',
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
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Inset Glass-Encased Stereo Meter on RIGHT side of fader
                  StereoMeterWidget(
                    leftLevel: leftPeak,
                    rightLevel: rightPeak,
                    accentColor: track.color,
                    width: 38.0,
                    height: double.infinity,
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
  }

  void _showFXRackDialog(BuildContext context, DawState dawState, TrackChannel track) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: EatsTheme.panelBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: EatsTheme.secondaryMagenta, width: 2),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'MIXER FX RACK: ${track.name.toUpperCase()}',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.secondaryMagenta,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: EatsTheme.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: ModularFxRackWidget(
                      dawState: dawState,
                      track: track,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

