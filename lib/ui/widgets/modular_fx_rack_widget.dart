import 'package:flutter/material.dart';
import '../../audio/convolver_engine.dart';
import '../../lua/lua_preset_library.dart';
import '../../models/daw_state.dart';

import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'eatsbits_slider.dart';
import 'skeuomorphic_hardware_switch.dart';

class ModularFxRackWidget extends StatelessWidget {
  final DawState dawState;
  final TrackChannel track;

  const ModularFxRackWidget({
    super.key,
    required this.dawState,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dawState,
      builder: (context, _) {
        final availableIrs = ConvolverEngine.instance.getAvailableIrNames();

        return DragTarget<LuaPreset>(
          onWillAcceptWithDetails: (details) => details.data.isAudioFx,
          onAcceptWithDetails: (details) {
            final preset = details.data;
            dawState.applyPreset(preset, targetTrack: track);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added FX "${preset.name}" to end of ${track.name} FX rack'),
                backgroundColor: EatsTheme.panelHeader,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isHovering ? EatsTheme.secondaryMagenta.withOpacity(0.2) : EatsTheme.panelBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHovering ? EatsTheme.secondaryMagenta : EatsTheme.secondaryMagenta.withOpacity(0.5),
                  width: isHovering ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: EatsTheme.secondaryMagenta.withOpacity(isHovering ? 0.3 : 0.1),
                    blurRadius: isHovering ? 12 : 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: EatsTheme.secondaryMagenta, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'AUDIO FX RACK (${track.fxRack.length})',
                          overflow: TextOverflow.ellipsis,
                          style: EatsTheme.getPrimaryFontStyle(
                            color: EatsTheme.secondaryMagenta,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<FXType>(
                        tooltip: 'Add FX Insert',
                        color: EatsTheme.panelHeader,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: EatsTheme.panelHeader,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: EatsTheme.secondaryMagenta),
                          ),
                          child: Text(
                            '+ ADD FX',
                            style: EatsTheme.getPrimaryFontStyle(
                              color: EatsTheme.secondaryMagenta,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: FXType.limiter, child: Text('Master Limiter / Peak')),
                          const PopupMenuItem(value: FXType.compressor, child: Text('Dynamics Compressor')),
                          const PopupMenuItem(value: FXType.convolutionReverb, child: Text('Convolution Reverb')),
                          const PopupMenuItem(value: FXType.distortion, child: Text('Tube Distortion')),
                          const PopupMenuItem(value: FXType.bitcrusher, child: Text('Bitcrusher 8-Bit')),
                          const PopupMenuItem(value: FXType.delay, child: Text('Stereo Delay')),
                          const PopupMenuItem(value: FXType.biquadFilter, child: Text('Lowpass Filter')),
                        ],
                        onSelected: (type) => dawState.addFXInsert(track, type),
                      ),
                    ],
                  ),

                  if (track.fxRack.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...track.fxRack.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final fx = entry.value;
                      final isFirst = idx == 0;
                      final isLast = idx == track.fxRack.length - 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EatsTheme.panelHeader,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: fx.enabled ? EatsTheme.secondaryMagenta : const Color(0xFF2B3245),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SkeuomorphicHardwareSwitch(
                                  value: fx.enabled,
                                  activeColor: EatsTheme.secondaryMagenta,
                                  tooltip: 'Toggle ${fx.name} (Bypass / Active)',
                                  onChanged: (val) => dawState.toggleFXInsert(track, fx.id, val),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    fx.name.toUpperCase(),
                                    style: EatsTheme.getPrimaryFontStyle(
                                      color: fx.enabled ? EatsTheme.textPrimary : EatsTheme.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move FX Up',
                                  icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                                  color: isFirst ? Colors.white12 : EatsTheme.primaryCyan,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: isFirst ? null : () => dawState.moveFXUp(track, idx),
                                ),
                                IconButton(
                                  tooltip: 'Move FX Down',
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  color: isLast ? Colors.white12 : EatsTheme.primaryCyan,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: isLast ? null : () => dawState.moveFXDown(track, idx),
                                ),
                                IconButton(
                                  tooltip: 'Remove FX',
                                  icon: Icon(Icons.delete_outline, color: EatsTheme.textMuted, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => dawState.removeFXInsert(track, fx.id),
                                ),
                              ],
                            ),

                            // FX Specific Parameters
                            if (fx.type == FXType.convolutionReverb) ...[
                              const SizedBox(height: 6),
                              // Dry Level Slider
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'DRY LEVEL',
                                      style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10),
                                    ),
                                  ),
                                  Expanded(
                                    child: EatsBitsSlider(
                                      value: fx.params['DryLevel'] ?? 1.0,
                                      min: 0.0,
                                      max: 1.5,
                                      defaultValue: 1.0,
                                      label: 'Dry Level',
                                      activeColor: EatsTheme.accentGreen,
                                      onChanged: (val) => dawState.updateFXParam(track, fx.id, 'DryLevel', val),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 55,
                                    child: Text(
                                      '${((fx.params['DryLevel'] ?? 1.0) * 100).toInt()}%',
                                      style: EatsTheme.getDisplayFontStyle(color: EatsTheme.accentGreen, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Wet Level Slider
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'WET LEVEL',
                                      style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10),
                                    ),
                                  ),
                                  Expanded(
                                    child: EatsBitsSlider(
                                      value: fx.params['WetLevel'] ?? 0.5,
                                      min: 0.0,
                                      max: 1.5,
                                      defaultValue: 0.5,
                                      label: 'Wet Level',
                                      activeColor: EatsTheme.secondaryMagenta,
                                      onChanged: (val) => dawState.updateFXParam(track, fx.id, 'WetLevel', val),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 55,
                                    child: Text(
                                      '${((fx.params['WetLevel'] ?? 0.5) * 100).toInt()}%',
                                      style: EatsTheme.getDisplayFontStyle(color: EatsTheme.secondaryMagenta, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'IMPULSE RESPONSE (IR):',
                                style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: EatsTheme.panelBackground,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF2B3245)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: availableIrs.contains(fx.irSampleName)
                                        ? fx.irSampleName
                                        : (availableIrs.isNotEmpty ? availableIrs.first : 'Great Hall'),
                                    isExpanded: true,
                                    dropdownColor: EatsTheme.panelBackground,
                                    style: EatsTheme.getPrimaryFontStyle(
                                      color: EatsTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: availableIrs
                                        .map((ir) => DropdownMenuItem(value: ir, child: Text(ir)))
                                        .toList(),
                                    onChanged: (newIr) {
                                      if (newIr != null) dawState.updateFXIrSample(track, fx.id, newIr);
                                    },
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Dry/Wet Mix Slider
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'DRY/WET MIX',
                                      style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10),
                                    ),
                                  ),
                                  Expanded(
                                    child: EatsBitsSlider(
                                      value: fx.mix,
                                      min: 0.0,
                                      max: 1.0,
                                      defaultValue: 1.0,
                                      label: 'Mix',
                                      activeColor: EatsTheme.primaryCyan,
                                      onChanged: (val) => dawState.updateFXMix(track, fx.id, val),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 55,
                                    child: Text(
                                      '${(fx.mix * 100).round()}%',
                                      style: EatsTheme.getDisplayFontStyle(color: EatsTheme.primaryCyan, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              ...fx.params.entries.map((p) {
                                final minV = _getParamMin(p.key);
                                final maxV = _getParamMax(p.key);
                                final defV = _getParamDefault(p.key);

                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          p.key.toUpperCase(),
                                          style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10),
                                        ),
                                      ),
                                      Expanded(
                                        child: EatsBitsSlider(
                                          value: p.value.clamp(minV, maxV),
                                          min: minV,
                                          max: maxV,
                                          defaultValue: defV,
                                          label: p.key,
                                          activeColor: EatsTheme.secondaryMagenta,
                                          onChanged: (val) => dawState.updateFXParam(track, fx.id, p.key, val),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 55,
                                        child: Text(
                                          _formatParamVal(p.key, p.value),
                                          style: EatsTheme.getDisplayFontStyle(color: EatsTheme.secondaryMagenta, fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  static double _getParamMin(String key) {
    switch (key) {
      case 'Threshold':
        return -60.0;
      case 'Ceiling':
        return -12.0;
      case 'Ratio':
        return 1.0;
      case 'Attack':
        return 0.001;
      case 'Release':
        return 0.01;
      case 'Knee':
        return 0.0;
      case 'TimeMs':
        return 10.0;
      case 'Feedback':
        return 0.0;
      case 'Cutoff':
        return 20.0;
      case 'Resonance':
        return 0.1;
      case 'Drive':
        return 0.0;
      case 'Tone':
        return 200.0;
      case 'Bits':
        return 1.0;
      case 'Downsample':
        return 1.0;
      default:
        return 0.0;
    }
  }

  static double _getParamMax(String key) {
    switch (key) {
      case 'Threshold':
      case 'Ceiling':
        return 0.0;
      case 'Ratio':
        return 20.0;
      case 'Attack':
      case 'Release':
        return 1.0;
      case 'Knee':
        return 40.0;
      case 'TimeMs':
        return 1000.0;
      case 'Feedback':
        return 0.95;
      case 'Cutoff':
        return 20000.0;
      case 'Resonance':
        return 20.0;
      case 'Drive':
        return 1.0;
      case 'Tone':
        return 10000.0;
      case 'Bits':
        return 16.0;
      case 'Downsample':
        return 32.0;
      default:
        return 1.0;
    }
  }

  static double _getParamDefault(String key) {
    switch (key) {
      case 'Threshold':
        return -18.0;
      case 'Ceiling':
        return -0.1;
      case 'Ratio':
        return 4.0;
      case 'Attack':
        return 0.02;
      case 'Release':
        return 0.25;
      case 'Knee':
        return 12.0;
      case 'TimeMs':
        return 250.0;
      case 'Feedback':
        return 0.4;
      case 'Cutoff':
        return 3500.0;
      case 'Resonance':
        return 1.5;
      case 'Drive':
        return 0.5;
      case 'Tone':
        return 5000.0;
      case 'Bits':
        return 8.0;
      case 'Downsample':
        return 4.0;
      default:
        return 0.5;
    }
  }

  static String _formatParamVal(String key, double val) {
    if (key == 'Threshold' || key == 'Ceiling' || key == 'Knee') {
      return '${val.toStringAsFixed(1)}dB';
    }
    if (key == 'Ratio') {
      return '${val.toStringAsFixed(1)}:1';
    }
    if (key == 'Attack' || key == 'Release') {
      return '${(val * 1000).round()}ms';
    }
    if (key == 'TimeMs') {
      return '${val.round()}ms';
    }
    if (key == 'Cutoff' || key == 'Tone') {
      return '${val.round()}Hz';
    }
    if (key == 'Bits') {
      return '${val.round()}b';
    }
    return val.toStringAsFixed(1);
  }
}
