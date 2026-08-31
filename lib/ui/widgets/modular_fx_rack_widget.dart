import 'package:flutter/material.dart';
import '../../audio/convolver_engine.dart';
import '../../audio/procedural_ir_generator.dart';
import '../../lua/lua_preset_library.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'dynamic_instrument_gui_widget.dart';
import 'eatsbeats_slider.dart';
import 'fx_rack_dialog.dart';
import 'preset_search_dialog.dart';
import 'skeuomorphic_hardware_switch.dart';
import 'space_visualizer_widget.dart';

class ModularFxRackWidget extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;

  const ModularFxRackWidget({
    super.key,
    required this.dawState,
    required this.track,
  });

  @override
  State<ModularFxRackWidget> createState() => _ModularFxRackWidgetState();
}

class _ModularFxRackWidgetState extends State<ModularFxRackWidget> {
  final Set<String> _expandedGuiFxIds = {};
  void _toggleGuiExpanded(String fxId) {
    setState(() {
      if (_expandedGuiFxIds.contains(fxId)) {
        _expandedGuiFxIds.remove(fxId);
      } else {
        _expandedGuiFxIds.add(fxId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dawState = widget.dawState;
    final track = widget.track;

    return ListenableBuilder(
      listenable: dawState,
      builder: (context, _) {
        final availableIrs = ConvolverEngine.instance.getAvailableIrNames();
        final allAudioPresets = LuaPresetLibrary.presets.where((p) => p.isAudioFx).toList();

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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isHovering ? EatsTheme.secondaryMagenta.withOpacity(0.2) : EatsTheme.panelBackground,
                borderRadius: BorderRadius.circular(8),
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
                      Icon(Icons.tune, color: EatsTheme.secondaryMagenta, size: 16),
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
                      Tooltip(
                        message: 'Search and Add FX from Library',
                        child: InkWell(
                          onTap: () => PresetSearchDialog.showAudioFx(
                            context,
                            dawState: dawState,
                            track: track,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: EatsTheme.panelHeader,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: EatsTheme.secondaryMagenta),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search, size: 12, color: EatsTheme.secondaryMagenta),
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
                        ),
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
                      final isExpanded = _expandedGuiFxIds.contains(fx.id);

                      final fxTrack = TrackChannel(
                        id: fx.id,
                        name: fx.name,
                        type: TrackType.luaScript,
                        color: EatsTheme.secondaryMagenta,
                        luaScriptCode: fx.luaScriptCode ?? '',
                        luaParams: fx.luaParams,
                        sampleName: fx.irSampleName ?? 'Great Hall',
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
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
                            // Header Strip
                            Row(
                              children: [
                                SkeuomorphicHardwareSwitch(
                                  value: fx.enabled,
                                  style: SwitchStyle.modernPill,
                                  orientation: Axis.vertical,
                                  width: 16.0,
                                  height: 28.0,
                                  activeColor: EatsTheme.secondaryMagenta,
                                  tooltip: 'Toggle ${fx.name} (Bypass / Active)',
                                  onChanged: (val) => dawState.toggleFXInsert(track, fx.id, val),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _toggleGuiExpanded(fx.id),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            fx.name.toUpperCase(),
                                            style: EatsTheme.getPrimaryFontStyle(
                                              color: fx.enabled ? EatsTheme.textPrimary : EatsTheme.textMuted,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isExpanded ? Icons.expand_less : Icons.expand_more,
                                          size: 14,
                                          color: EatsTheme.secondaryMagenta,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move FX Up',
                                  icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                                  color: isFirst ? Colors.white12 : EatsTheme.primaryCyan,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                  onPressed: isFirst ? null : () => dawState.moveFXUp(track, idx),
                                ),
                                IconButton(
                                  tooltip: 'Move FX Down',
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                  color: isLast ? Colors.white12 : EatsTheme.primaryCyan,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                  onPressed: isLast ? null : () => dawState.moveFXDown(track, idx),
                                ),
                                IconButton(
                                  tooltip: 'Remove FX',
                                  icon: Icon(Icons.delete_outline, color: EatsTheme.textMuted, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                  onPressed: () => dawState.removeFXInsert(track, fx.id),
                                ),
                              ],
                            ),

                            // Inline Hardware Faceplate GUI (when expanded or Lua script has GUI)
                            if (isExpanded && (fx.luaScriptCode?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _expandedGuiFxIds.remove(fx.id);
                                      });
                                      dawState.openFloatingFxWindow(track, fx);
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.open_in_new, size: 12, color: EatsTheme.primaryCyan),
                                        const SizedBox(width: 4),
                                        Text(
                                          'POPOUT',
                                          style: EatsTheme.getDisplayFontStyle(fontSize: 9, color: EatsTheme.primaryCyan),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: EatsTheme.secondaryMagenta.withOpacity(0.4)),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    const designWidth = 520.0;
                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.topLeft,
                                        child: SizedBox(
                                          width: designWidth,
                                          child: DynamicInstrumentGuiWidget(
                                            dawState: dawState,
                                            track: fxTrack,
                                            hostTrack: track,
                                            hideHeader: true,
                                            onParamChanged: (p, v) => dawState.updateFXParam(track, fx.id, p, v),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ] else if (isExpanded && fx.type == FXType.convolutionReverb) ...[
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
                                    child: EatsBeatsSlider(
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
                                    child: EatsBeatsSlider(
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
                                      if (newIr != null) {
                                        dawState.updateFXIrSample(track, fx.id, newIr);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ] else if (isExpanded) ...[
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
                                    child: EatsBeatsSlider(
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
                                        child: EatsBeatsSlider(
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

  List<PopupMenuEntry<LuaPreset>> _buildFxMenuItems(List<LuaPreset> presets) {
    return presets.map((p) {
      return PopupMenuItem<LuaPreset>(
        value: p,
        child: Row(
          children: [
            Icon(
              p.id.contains('scope') || p.id.contains('spectrum')
                  ? Icons.remove_red_eye_outlined
                  : Icons.graphic_eq,
              size: 14,
              color: p.id.contains('scope') || p.id.contains('spectrum')
                  ? const Color(0xFF00E5FF)
                  : EatsTheme.secondaryMagenta,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    style: EatsTheme.getPrimaryFontStyle(
                      color: EatsTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    p.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EatsTheme.getPrimaryFontStyle(
                      color: EatsTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
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
