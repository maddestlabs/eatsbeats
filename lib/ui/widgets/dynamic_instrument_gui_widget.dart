import 'package:flutter/material.dart';
import '../../lua/lua_engine.dart';
import '../../lua/lua_gui_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'eatsbits_slider.dart';
import 'glowing_nixie_display.dart';
import 'grungy_rack_panel.dart';
import 'hardware_listbox_widget.dart';
import 'lcd_display_widget.dart';
import 'skeuomorphic_hardware_button.dart';
import 'skeuomorphic_hardware_knob.dart';
import 'skeuomorphic_hardware_slider.dart';
import 'skeuomorphic_hardware_switch.dart';
import 'stereo_meter_widget.dart';

class DynamicInstrumentGuiWidget extends StatelessWidget {
  final DawState dawState;
  final TrackChannel track;
  final bool hideHeader;

  const DynamicInstrumentGuiWidget({
    super.key,
    required this.dawState,
    required this.track,
    this.hideHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final trackCompilation = track.luaScriptCode.isNotEmpty
        ? LuaEngine.compile(track.luaScriptCode)
        : dawState.compilationResult;

    final guiLayout = trackCompilation.guiLayout;

    // 1. If custom GUI layout is defined by script, render custom hardware rack faceplate
    if (guiLayout != null) {
      return _buildCustomRackPanel(context, guiLayout, trackCompilation);
    }

    // 2. If no custom GUI is provided, fallback to standard dynamic script parameters
    if (trackCompilation.params.isNotEmpty) {
      return _buildDefaultDynamicParams(context, trackCompilation);
    }

    return const SizedBox.shrink();
  }

  Widget _buildCustomRackPanel(
    BuildContext context,
    LuaGuiPanelDef layout,
    LuaCompilationResult compilation,
  ) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final baseAccent = layout.accentColor ?? (isGrungy ? const Color(0xFFFF8C00) : track.color);
    final hasUpgrade = dawState.isPresetUpgradeAvailable(track);

    if (hideHeader) {
      return RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isGrungy ? const Color(0xFF26221D) : EatsTheme.panelBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isGrungy ? const Color(0xFF423B33) : EatsTheme.panelHeader,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: layout.children.map((node) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildNode(context, node, compilation, baseAccent),
              );
            }).toList(),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
          if (hasUpgrade) _buildUpgradeBanner(context),
          GrungyRackPanel(
            title: layout.title,
            subtitle: layout.subtitle ?? 'Hardware Script Interface',
            accentColor: baseAccent,
            headerActions: [
              if (hasUpgrade) ...[
                GestureDetector(
                  onTap: () {
                    dawState.upgradeTrackPreset(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Upgraded "${track.name}" to latest factory preset! (Settings preserved)'),
                        backgroundColor: EatsTheme.panelHeader,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: EatsTheme.accentGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EatsTheme.accentGold, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upgrade, size: 13, color: EatsTheme.accentGold),
                        const SizedBox(width: 4),
                        Text(
                          'UPDATE CODE',
                          style: EatsTheme.getPrimaryFontStyle(
                            color: EatsTheme.accentGold,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: baseAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: baseAccent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.memory, size: 12, color: baseAccent),
                    const SizedBox(width: 4),
                    Text(
                      'LUA VSTi',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: baseAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Column(
              children: layout.children.map((node) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildNode(context, node, compilation, baseAccent),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNode(
    BuildContext context,
    LuaGuiNode node,
    LuaCompilationResult compilation,
    Color defaultAccent,
  ) {
    final accent = node.accentColor ?? defaultAccent;

    switch (node.type) {
      case LuaGuiNodeType.row:
        return Row(
          mainAxisAlignment: _parseMainAxisAlignment(node.align),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: node.children
              .map((c) => _buildNode(context, c, compilation, defaultAccent))
              .toList(),
        );

      case LuaGuiNodeType.column:
        return Column(
          mainAxisAlignment: _parseMainAxisAlignment(node.align),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: node.children
              .map((c) => _buildNode(context, c, compilation, defaultAccent))
              .toList(),
        );

      case LuaGuiNodeType.group:
        return Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: EatsTheme.panelHeader.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (node.label != null) ...[
                Text(
                  node.label!.toUpperCase(),
                  style: EatsTheme.getPrimaryFontStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ...node.children.map((c) => _buildNode(context, c, compilation, defaultAccent)),
            ],
          ),
        );

      case LuaGuiNodeType.knob:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
        final currentVal = paramDef.isInteger ? rawVal.roundToDouble() : rawVal;

        return SkeuomorphicHardwareKnob(
          label: node.label ?? paramDef.name.toUpperCase(),
          value: currentVal,
          min: paramDef.min,
          max: paramDef.max,
          defaultValue: paramDef.defaultValue,
          size: node.size ?? 56.0,
          accentColor: accent,
          onChanged: (val) {
            final snapped = paramDef.isInteger ? val.roundToDouble() : val;
            dawState.updateLuaParam(paramDef.name, snapped);
          },
          onChangeStart: () => dawState.beginHistoryTransaction(
            '${paramDef.name} (${track.name})',
            icon: Icons.tune,
          ),
          onChangeEnd: () => dawState.commitHistoryTransaction(),
          formatValue: (v) {
            final f = paramDef.getFormattedValue(v);
            return node.unit != null ? '$f ${node.unit}' : f;
          },
        );

      case LuaGuiNodeType.slider:
      case LuaGuiNodeType.fader:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
        final currentVal = paramDef.isInteger ? rawVal.roundToDouble() : rawVal;

        return SkeuomorphicHardwareSlider(
          label: node.label ?? paramDef.name.toUpperCase(),
          value: currentVal,
          min: paramDef.min,
          max: paramDef.max,
          defaultValue: paramDef.defaultValue,
          orientation: node.orientation == 'horizontal' ? Axis.horizontal : Axis.vertical,
          length: node.size ?? 140.0,
          activeColor: accent,
          onChanged: (val) {
            final snapped = paramDef.isInteger ? val.roundToDouble() : val;
            dawState.updateLuaParam(paramDef.name, snapped);
          },
          onChangeStart: () => dawState.beginHistoryTransaction(
            '${paramDef.name} (${track.name})',
            icon: Icons.linear_scale,
          ),
          onChangeEnd: () => dawState.commitHistoryTransaction(),
          formatValue: (v) {
            final f = paramDef.getFormattedValue(v);
            return node.unit != null ? '$f ${node.unit}' : f;
          },
        );

      case LuaGuiNodeType.switchToggle:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
        final bool isChecked = rawVal > 0.5;

        return SkeuomorphicHardwareSwitch(
          label: node.label ?? paramDef.name.toUpperCase(),
          value: isChecked,
          activeColor: accent,
          ledColor: accent,
          onChanged: (bool val) {
            dawState.beginHistoryTransaction('Toggle ${paramDef.name} (${track.name})', icon: Icons.toggle_on);
            dawState.updateLuaParam(paramDef.name, val ? 1.0 : 0.0);
            dawState.commitHistoryTransaction();
          },
        );

      case LuaGuiNodeType.button:
        return SkeuomorphicHardwareButton(
          label: node.label ?? 'TRIGGER',
          activeColor: accent,
          onTap: () {
            if (node.param != null) {
              final paramDef = _findParam(node.param, compilation);
              dawState.updateLuaParam(paramDef.name, 1.0);
              Future.delayed(const Duration(milliseconds: 150), () {
                dawState.updateLuaParam(paramDef.name, 0.0);
              });
            }
          },
        );

      case LuaGuiNodeType.listBox:
        final paramDef = _findParam(node.param, compilation);
        final effectiveOptions = node.options.isNotEmpty ? node.options : paramDef.options;

        return HardwareListBoxWidget(
          dawState: dawState,
          track: track,
          paramName: paramDef.name,
          label: node.label ?? paramDef.name.toUpperCase(),
          options: effectiveOptions,
          width: node.width ?? 160.0,
          height: node.height ?? (node.size ?? 100.0),
          accentColor: accent,
        );

      case LuaGuiNodeType.nixie:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
        final formattedVal = paramDef.getFormattedValue(rawVal);

        return GlowingNixieDisplay(
          label: node.label ?? (node.param ?? 'READOUT').toUpperCase(),
          valueText: formattedVal,
          unit: node.unit ?? '',
          glowColor: accent,
        );

      case LuaGuiNodeType.lcd:
        return LcdDisplayWidget(
          title: node.label ?? track.name.toUpperCase(),
          leftText: node.leftText ?? (track.pan == 0 ? 'CENTER' : (track.pan < 0 ? 'L${(track.pan.abs() * 100).toInt()}' : 'R${(track.pan * 100).toInt()}')),
          rightText: node.rightText ?? '${(track.volume * 100).toInt()}%',
        );

      case LuaGuiNodeType.meter:
        return StereoMeterWidget(
          leftLevel: (track.volume * 0.8).clamp(0.0, 1.2),
          rightLevel: (track.volume * 0.8).clamp(0.0, 1.2),
          accentColor: accent,
          height: node.size ?? 120.0,
        );

      case LuaGuiNodeType.label:
        return Text(
          node.text ?? node.label ?? '',
          style: EatsTheme.getPrimaryFontStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        );

      case LuaGuiNodeType.spacer:
        return SizedBox(
          width: node.size ?? 16,
          height: node.size ?? 16,
        );

      case LuaGuiNodeType.unknown:
        return const SizedBox.shrink();
    }
  }

  LuaParamDef _findParam(String? name, LuaCompilationResult compilation) {
    if (name == null || name.isEmpty) {
      return LuaParamDef(name: 'Param', min: 0.0, max: 1.0, defaultValue: 0.0);
    }
    return compilation.params.firstWhere(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
      orElse: () => LuaParamDef(name: name, min: 0.0, max: 1.0, defaultValue: 0.0),
    );
  }

  MainAxisAlignment _parseMainAxisAlignment(String align) {
    switch (align.toLowerCase()) {
      case 'space_between':
      case 'spacebetween':
        return MainAxisAlignment.spaceBetween;
      case 'space_evenly':
      case 'spaceevenly':
        return MainAxisAlignment.spaceEvenly;
      case 'center':
        return MainAxisAlignment.center;
      case 'start':
      case 'left':
        return MainAxisAlignment.start;
      case 'end':
      case 'right':
        return MainAxisAlignment.end;
      case 'space_around':
      case 'spacearound':
      default:
        return MainAxisAlignment.spaceAround;
    }
  }

  Widget _buildUpgradeBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EatsTheme.panelHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EatsTheme.accentGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: EatsTheme.accentGold.withOpacity(0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EatsTheme.accentGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_awesome, color: EatsTheme.accentGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRESET UPDATE AVAILABLE',
                  style: EatsTheme.getPrimaryFontStyle(
                    color: EatsTheme.accentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upgrade to latest factory instrument script with custom hardware GUI while preserving your tuned parameter settings.',
                  style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () {
              dawState.upgradeTrackPreset(track);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upgraded "${track.name}" to latest preset! (All settings preserved)'),
                  backgroundColor: EatsTheme.panelHeader,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EatsTheme.accentGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.upgrade, size: 16),
            label: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultDynamicParams(
    BuildContext context,
    LuaCompilationResult compilation,
  ) {
    final hasUpgrade = dawState.isPresetUpgradeAvailable(track);

    return RepaintBoundary(
      child: Column(
        children: [
        if (hasUpgrade && !hideHeader) _buildUpgradeBanner(context),
        Container(
          margin: hideHeader ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
          padding: hideHeader ? const EdgeInsets.all(10) : const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EatsTheme.panelBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EatsTheme.accentGreen.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideHeader) ...[
                Row(
                  children: [
                    const Icon(Icons.tune, color: EatsTheme.accentGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DYNAMIC SCRIPT PARAMETERS (CODE DRIVEN)',
                        style: EatsTheme.getPrimaryFontStyle(
                          color: EatsTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
          ...compilation.params.map((paramDef) {
            final rawVal = (track.luaParams[paramDef.name] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
            final currentVal = paramDef.isInteger ? rawVal.roundToDouble() : rawVal;
            final displayLabel = paramDef.getFormattedValue(currentVal);

            if (paramDef.options.isNotEmpty) {
              final selectedIdx = currentVal.toInt().clamp(0, paramDef.options.length - 1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        paramDef.name,
                        style: EatsTheme.getPrimaryFontStyle(
                          color: EatsTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: EatsTheme.panelBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: EatsTheme.accentGreen.withOpacity(0.4)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: selectedIdx.toDouble(),
                            isExpanded: true,
                            dropdownColor: EatsTheme.panelBackground,
                            icon: const Icon(Icons.arrow_drop_down, color: EatsTheme.accentGreen, size: 20),
                            items: List.generate(paramDef.options.length, (idx) {
                              return DropdownMenuItem<double>(
                                value: idx.toDouble(),
                                child: Text(
                                  paramDef.options[idx],
                                  style: EatsTheme.getDisplayFontStyle(
                                    color: EatsTheme.accentGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                dawState.beginHistoryTransaction('Change ${paramDef.name} (${track.name})', icon: Icons.tune);
                                dawState.updateLuaParam(paramDef.name, val);
                                dawState.commitHistoryTransaction();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      paramDef.name,
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: EatsBitsSlider(
                      value: currentVal,
                      min: paramDef.min,
                      max: paramDef.max,
                      defaultValue: paramDef.defaultValue,
                      label: paramDef.name,
                      activeColor: EatsTheme.accentGreen,
                      onChanged: (val) {
                        final snapped = paramDef.isInteger ? val.roundToDouble() : val;
                        dawState.updateLuaParam(paramDef.name, snapped);
                      },
                      onChangeStart: () => dawState.beginHistoryTransaction(
                        '${paramDef.name} (${track.name})',
                        icon: Icons.tune,
                      ),
                      onChangeEnd: () => dawState.commitHistoryTransaction(),
                    ),
                  ),
                  SizedBox(
                    width: 75,
                    child: Text(
                      displayLabel,
                      style: EatsTheme.getDisplayFontStyle(
                        color: EatsTheme.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              );
            }),
          ],
        ),
      ),
    ],
  ),
);
  }
}
