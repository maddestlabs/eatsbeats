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
              const Icon(Icons.tune, color: EatsTheme.secondaryMagenta, size: 18),
              const SizedBox(width: 8),
              Text(
                'MODULAR FX INSERT RACK (${track.fxRack.length})',
                style: EatsTheme.getPrimaryFontStyle(
                  color: EatsTheme.secondaryMagenta,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
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
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: EatsTheme.secondaryMagenta, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '+ ADD FX',
                        style: EatsTheme.getPrimaryFontStyle(
                          color: EatsTheme.secondaryMagenta,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
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

          const SizedBox(height: 12),

          if (track.fxRack.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No FX Inserts on this track. Click "+ ADD FX" to add Convolution Reverb, Distortion, or Bitcrusher.',
                  style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 11),
                ),
              ),
            )
          else
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
                            width: 45,
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
                            width: 45,
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

                      ...fx.params.entries.map((p) {
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
                                  value: p.value,
                                  min: p.key == 'Drive' ? 0.0 : 1.0,
                                  max: p.key == 'Drive' ? 1.0 : (p.key == 'Bits' ? 16.0 : 10000.0),
                                  defaultValue: p.key == 'Drive' ? 0.5 : (p.key == 'Bits' ? 8.0 : 3500.0),
                                  label: p.key,
                                  activeColor: EatsTheme.secondaryMagenta,
                                  onChanged: (val) => dawState.updateFXParam(track, fx.id, p.key, val),
                                ),
                              ),
                              SizedBox(
                                width: 45,
                                child: Text(
                                  p.value.toStringAsFixed(1),
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
      ),
    );
  },
);
  }
}
