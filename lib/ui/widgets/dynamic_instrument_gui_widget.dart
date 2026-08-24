import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../audio/convolver_engine.dart';
import '../../audio/procedural_ir_generator.dart';
import '../../audio/snes_dsp_engine.dart';
import '../../audio/soundfont_engine.dart';
import '../../audio/soundfont_decoder.dart';
import '../../lua/lua_engine.dart';
import '../../lua/lua_gui_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'compact_value_dialog.dart';
import 'eatsbeats_slider.dart';
import 'glowing_nixie_display.dart';
import 'grungy_rack_panel.dart';
import 'hardware_listbox_widget.dart';
import 'interactive_game_canvas_widget.dart';
import 'lcd_display_widget.dart';
import 'skeuomorphic_hardware_button.dart';
import 'skeuomorphic_hardware_knob.dart';
import 'skeuomorphic_hardware_slider.dart';
import 'skeuomorphic_hardware_switch.dart';
import 'space_visualizer_widget.dart';
import 'stereo_meter_widget.dart';
import 'waveshaper_canvas_widget.dart';

class DynamicInstrumentGuiWidget extends StatelessWidget {
  final DawState dawState;
  final TrackChannel track;
  final bool hideHeader;
  final void Function(String paramName, double value)? onParamChanged;

  const DynamicInstrumentGuiWidget({
    super.key,
    required this.dawState,
    required this.track,
    this.hideHeader = false,
    this.onParamChanged,
  });

  void _setParam(String paramName, double value) {
    track.luaParams[paramName] = value;
    if (onParamChanged != null) {
      onParamChanged!(paramName, value);
    } else {
      dawState.updateLuaParam(paramName, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SoundFontEngine.instance,
      builder: (context, _) {
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
      },
    );
  }

  Widget _buildCustomRackPanel(
    BuildContext context,
    LuaGuiPanelDef layout,
    LuaCompilationResult compilation,
  ) {
    final isGrungy = layout.backgroundStyle == PanelBackgroundStyle.grunge ||
        (layout.backgroundStyle == PanelBackgroundStyle.dark && EatsTheme.currentPreset == EatsThemePreset.ateTrack);
    final isSilver = layout.backgroundStyle == PanelBackgroundStyle.silver;
    final isSnes = layout.backgroundStyle == PanelBackgroundStyle.snes;
    final isLightChassis = isSilver || isSnes;
    final baseAccent = layout.accentColor ?? (isSilver ? const Color(0xFF141416) : track.color);
    final hasUpgrade = dawState.isPresetUpgradeAvailable(track);

    if (hideHeader) {
      return RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSnes
                ? const Color(0xFFD8D6CD)
                : (isSilver
                    ? const Color(0xFFD4D0C5)
                    : (isGrungy ? const Color(0xFF26221D) : EatsTheme.panelBackground)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSnes
                  ? const Color(0xFF908C82)
                  : (isSilver
                      ? const Color(0xFF8C887D)
                      : (isGrungy ? const Color(0xFF423B33) : EatsTheme.panelHeader)),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: layout.children.map((node) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildNode(context, node, compilation, baseAccent, isLightChassis),
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
            panelColor: layout.backgroundColor,
            backgroundStyle: layout.backgroundStyle,
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
                  color: (isSilver ? const Color(0xFF141416) : baseAccent).withOpacity(isSilver ? 0.08 : 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: (isSilver ? const Color(0xFF141416) : baseAccent).withOpacity(isSilver ? 0.35 : 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.piano, size: 12, color: isSilver ? const Color(0xFF141416) : baseAccent),
                    const SizedBox(width: 4),
                    Text(
                      'INSTRUMENT',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: isSilver ? const Color(0xFF141416) : baseAccent,
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
                  child: _buildNode(context, node, compilation, baseAccent, isLightChassis),
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
    Color defaultAccent, [
    bool isLightChassis = false,
  ]) {
    final accent = node.accentColor ?? defaultAccent;

    switch (node.type) {
      case LuaGuiNodeType.row:
        return Row(
          mainAxisAlignment: _parseMainAxisAlignment(node.align),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: node.children
              .map((c) => _buildNode(context, c, compilation, defaultAccent, isLightChassis))
              .toList(),
        );

      case LuaGuiNodeType.column:
        return Column(
          mainAxisAlignment: _parseMainAxisAlignment(node.align),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: node.children
              .map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: _buildNode(context, c, compilation, defaultAccent, isLightChassis),
                  ))
              .toList(),
        );

      case LuaGuiNodeType.divider:
        if (node.orientation == 'vertical') {
          return Container(
            width: node.width ?? 2.0,
            height: node.height ?? node.size ?? 68.0,
            margin: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: isLightChassis ? const Color(0xFF4A463E) : Colors.white12,
              borderRadius: BorderRadius.circular(1.0),
              boxShadow: isLightChassis
                  ? [
                      const BoxShadow(
                        color: Color(0xFFFFFFFF),
                        offset: Offset(1, 0),
                        blurRadius: 0.5,
                      )
                    ]
                  : null,
            ),
          );
        } else {
          return Container(
            height: node.height ?? 2.0,
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            decoration: BoxDecoration(
              color: isLightChassis ? const Color(0xFF4A463E) : Colors.white12,
              borderRadius: BorderRadius.circular(1.0),
              boxShadow: isLightChassis
                  ? [
                      const BoxShadow(
                        color: Color(0xFFFFFFFF),
                        offset: Offset(0, 1),
                        blurRadius: 0.5,
                      )
                    ]
                  : null,
            ),
          );
        }

      case LuaGuiNodeType.group:
        return Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isLightChassis
                ? Colors.black.withOpacity(0.05)
                : EatsTheme.panelHeader.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isLightChassis
                  ? const Color(0xFF9E9A8E)
                  : accent.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (node.label != null) ...[
                Text(
                  node.label!.toUpperCase(),
                  style: EatsTheme.getPrimaryFontStyle(
                    color: isLightChassis ? const Color(0xFF1B1A17) : accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ...node.children.map((c) => _buildNode(context, c, compilation, defaultAccent, isLightChassis)),
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
          knobStyle: node.knobStyle,
          isLightChassis: isLightChassis,
          onChanged: (val) {
            final snapped = paramDef.isInteger ? val.roundToDouble() : val;
            _setParam(paramDef.name, snapped);
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

        final isVert = node.orientation == 'vertical';
        if (isVert) {
          return SkeuomorphicHardwareSlider(
            label: node.label ?? paramDef.name.toUpperCase(),
            value: currentVal,
            min: paramDef.min,
            max: paramDef.max,
            defaultValue: paramDef.defaultValue,
            orientation: Axis.vertical,
            length: node.size ?? 120.0,
            activeColor: accent,
            onChanged: (val) {
              final snapped = paramDef.isInteger ? val.roundToDouble() : val;
              _setParam(paramDef.name, snapped);
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
        }

        // Horizontal Slider (matching Track Volume and Track Inspector layout)
        final displayFormatted = () {
          final f = paramDef.getFormattedValue(currentVal);
          return node.unit != null ? '$f ${node.unit}' : f;
        }();

        return SizedBox(
          width: node.width ?? 235.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    node.label ?? paramDef.name.toUpperCase(),
                    style: EatsTheme.getDisplayFontStyle(
                      color: EatsTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    displayFormatted,
                    style: EatsTheme.getDisplayFontStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 24,
                child: EatsBeatsSlider(
                  value: currentVal,
                  min: paramDef.min,
                  max: paramDef.max,
                  defaultValue: paramDef.defaultValue,
                  label: node.label ?? paramDef.name,
                  activeColor: accent,
                  style: node.sliderStyle,
                  showTooltip: false,
                  onChanged: (val) {
                    final snapped = paramDef.isInteger ? val.roundToDouble() : val;
                    _setParam(paramDef.name, snapped);
                  },
                  onChangeStart: () => dawState.beginHistoryTransaction(
                    '${paramDef.name} (${track.name})',
                    icon: Icons.linear_scale,
                  ),
                  onChangeEnd: () => dawState.commitHistoryTransaction(),
                ),
              ),
            ],
          ),
        );

      case LuaGuiNodeType.switchToggle:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
        final bool isChecked = rawVal > 0.5;

        final isEats303 = track.name.toLowerCase().contains('303') ||
            track.luaScriptCode.contains('Eats303') ||
            track.luaScriptCode.contains('JC303');
        final isOpenBack = paramDef.name.toLowerCase().contains('openback') || (node.param ?? '').toLowerCase().contains('openback');
        final switchStyle = (isEats303 || isOpenBack) ? SwitchStyle.vintageBat : SwitchStyle.modernPill;
        final effectiveLabel = node.label ?? (isOpenBack ? 'OPEN' : paramDef.name.toUpperCase());

        return SkeuomorphicHardwareSwitch(
          style: switchStyle,
          label: effectiveLabel,
          value: isChecked,
          orientation: isOpenBack || node.orientation == 'vertical' ? Axis.vertical : Axis.horizontal,
          activeColor: accent,
          ledColor: accent,
          showText: switchStyle != SwitchStyle.vintageBat,
          onChanged: (bool val) {
            dawState.beginHistoryTransaction('Toggle ${paramDef.name} (${track.name})', icon: Icons.toggle_on);
            _setParam(paramDef.name, val ? 1.0 : 0.0);
            dawState.commitHistoryTransaction();
          },
        );

      case LuaGuiNodeType.button:
        return SkeuomorphicHardwareButton(
          label: node.label ?? 'TRIGGER',
          activeColor: accent,
          width: node.width,
          height: node.height ?? node.size ?? 32.0,
          onTap: () {
            final actionClean = (node.action ?? '').toLowerCase().trim();
            final labelClean = (node.label ?? '').toLowerCase().trim();

            if (actionClean == 'randomize' ||
                actionClean == 'randomize_sfx' ||
                actionClean == 'mutate' ||
                labelClean.contains('random') ||
                labelClean.contains('rng seed') ||
                labelClean.contains('generate')) {
              final sfxType = (track.luaParams['SFXType'] ?? 0.0).toInt();
              final currentSeed = (track.luaParams['Seed'] ?? 42.0).toInt();
              final newSeed = (currentSeed + DateTime.now().millisecond * 7 + 17) % 9990 + 1;
              final newParams = SNESSFXRGenerator.generateParamsForType(sfxType, seed: newSeed);

              dawState.beginHistoryTransaction('Randomize ${track.name}', icon: Icons.casino);
              for (final entry in newParams.entries) {
                track.luaParams[entry.key] = entry.value;
                _setParam(entry.key, entry.value);
              }
              dawState.commitHistoryTransaction();

              // Auto-audition a brief C5 (MIDI 72) note for instant SFX preview
              dawState.audioEngine.playNoteOrSample(
                track: track,
                midiNote: 72,
                velocity: 0.85,
                durationSec: 0.6,
              );
              return;
            }

            if (node.param != null) {
              final paramDef = _findParam(node.param, compilation);
              _setParam(paramDef.name, 1.0);
              Future.delayed(const Duration(milliseconds: 150), () {
                _setParam(paramDef.name, 0.0);
              });
            }
          },
        );

      case LuaGuiNodeType.listBox:
        final paramDef = _findParam(node.param, compilation);
        List<String> effectiveOptions = node.options.isNotEmpty ? node.options : paramDef.options;
        ValueChanged<int>? onSelectionChanged;

        final paramNameLower = paramDef.name.toLowerCase();

        // 1. SoundFont Bank ListBox dynamic handling
        if (paramNameLower == 'soundfontbank' || paramNameLower == 'sf2bank' || (node.param != null && node.param!.toLowerCase() == 'soundfontbank')) {
          final loadedFonts = SoundFontEngine.instance.loadedDisplayFonts;
          final fontKeys = loadedFonts.keys.toList();
          final fontNames = loadedFonts.values.toList();
          if (fontNames.isNotEmpty) {
            effectiveOptions = fontNames;
          }

          // Sync current selection based on track.sampleName
          final currentKey = track.sampleName;
          final keyIdx = fontKeys.indexOf(currentKey);
          if (keyIdx != -1) {
            track.luaParams[paramDef.name] = keyIdx.toDouble();
          }

          onSelectionChanged = (newIdx) {
            if (newIdx >= 0 && newIdx < fontKeys.length) {
              final fontId = fontKeys[newIdx];
              final displayName = fontNames[newIdx];
              dawState.changeTrackSoundFont(track, fontId, displayName: displayName);
              track.luaParams[paramDef.name] = newIdx.toDouble();
              track.luaParams['Preset'] = 0.0;
              track.luaParams['PresetNum'] = 0.0;
              track.luaParams['BankNum'] = 0.0;
              _setParam('PresetNum', 0.0);
              _setParam('BankNum', 0.0);
            }
          };
        }
        // 2. SoundFont Program Preset ListBox dynamic handling
        else if (paramNameLower == 'preset' || paramNameLower == 'presetnum' || (node.param != null && node.param!.toLowerCase() == 'preset')) {
          final fontData = SoundFontEngine.instance.getSoundFont(track.sampleName) ??
              SoundFontEngine.instance.getSoundFont('default.sf2');
          if (fontData != null && fontData.presets.isNotEmpty) {
            effectiveOptions = fontData.presets
                .map((p) => GeneralMidiNames.getPresetDisplayName(p.bankNum, p.presetNum, p.name))
                .toList();

            final currentPresetNum = (track.luaParams['PresetNum'] ?? 0.0).toInt();
            final currentBankNum = (track.luaParams['BankNum'] ?? 0.0).toInt();
            final activePresetIdx = fontData.presets.indexWhere(
              (p) => p.presetNum == currentPresetNum && p.bankNum == currentBankNum,
            );
            final validIdx = activePresetIdx != -1
                ? activePresetIdx
                : fontData.presets.indexWhere((p) => p.presetNum == currentPresetNum);
            if (validIdx != -1) {
              track.luaParams[paramDef.name] = validIdx.toDouble();
            }
          }

          onSelectionChanged = (newIdx) {
            final activeFontData = SoundFontEngine.instance.getSoundFont(track.sampleName) ??
                SoundFontEngine.instance.getSoundFont('default.sf2');
            if (activeFontData != null && newIdx >= 0 && newIdx < activeFontData.presets.length) {
              final p = activeFontData.presets[newIdx];
              track.luaParams[paramDef.name] = newIdx.toDouble();
              track.luaParams['PresetNum'] = p.presetNum.toDouble();
              track.luaParams['BankNum'] = p.bankNum.toDouble();
              _setParam('PresetNum', p.presetNum.toDouble());
              _setParam('BankNum', p.bankNum.toDouble());
            }
          };
        }
        // 3. SNES SFXR Type ListBox handling
        else if (paramDef.name == 'SFXType' || node.param == 'SFXType') {
          onSelectionChanged = (newTypeIdx) {
            final currentSeed = (track.luaParams['Seed'] ?? 42.0).toInt();
            final newSeed = (currentSeed + DateTime.now().millisecond * 7 + 17) % 9990 + 1;
            final newParams = SNESSFXRGenerator.generateParamsForType(newTypeIdx, seed: newSeed);

            dawState.beginHistoryTransaction('Select SFX Type (${track.name})', icon: Icons.casino);
            for (final entry in newParams.entries) {
              track.luaParams[entry.key] = entry.value;
              _setParam(entry.key, entry.value);
            }
            dawState.commitHistoryTransaction();

            // Auto-audition a brief C5 (MIDI 72) note for instant SFX preview
            dawState.audioEngine.playNoteOrSample(
              track: track,
              midiNote: 72,
              velocity: 0.85,
              durationSec: 0.6,
            );
          };
        }
        // 4. IRSample ListBox dynamic handling
        else if (paramNameLower == 'irsample' || paramNameLower == 'space' || paramNameLower == 'impulseresponse') {
          final allIrs = ConvolverEngine.instance.getAvailableIrNames();
          if (allIrs.isNotEmpty) {
            effectiveOptions = allIrs;
          }

          final currentIr = track.sampleName.isNotEmpty ? track.sampleName : 'Great Hall';
          final irIdx = effectiveOptions.indexWhere((opt) =>
              opt.toLowerCase() == currentIr.toLowerCase() ||
              opt.toLowerCase().startsWith(currentIr.toLowerCase()) ||
              currentIr.toLowerCase().startsWith(opt.toLowerCase()));
          if (irIdx != -1) {
            track.luaParams[paramDef.name] = irIdx.toDouble();
          }

          onSelectionChanged = (newIdx) {
            if (newIdx >= 0 && newIdx < effectiveOptions.length) {
              final chosenName = effectiveOptions[newIdx];
              track.luaParams[paramDef.name] = newIdx.toDouble();
              track.sampleName = chosenName;
              _setParam(paramDef.name, newIdx.toDouble());
            }
          };
        }

        return HardwareListBoxWidget(
          dawState: dawState,
          track: track,
          paramName: paramDef.name,
          label: node.label ?? paramDef.name.toUpperCase(),
          options: effectiveOptions,
          width: node.width ?? 160.0,
          height: node.height ?? (node.size ?? 100.0),
          accentColor: accent,
          onSelectionChanged: onSelectionChanged,
        );

      case LuaGuiNodeType.nixie:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
        final formattedVal = paramDef.getFormattedValue(rawVal);
        final displayVal = paramDef.isInteger ? rawVal.round().toString() : formattedVal;

        void updateParamValue(double val) {
          final clamped = val.clamp(paramDef.min, paramDef.max);
          final finalVal = paramDef.isInteger ? clamped.roundToDouble() : clamped;
          dawState.beginHistoryTransaction('Set ${paramDef.name} (${track.name})', icon: Icons.tune);
          track.luaParams[paramDef.name] = finalVal;
          _setParam(paramDef.name, finalVal);

          if ((paramDef.name == 'Seed' || paramDef.name == 'SFXType') && track.luaParams.containsKey('SFXType')) {
            final sfxType = (track.luaParams['SFXType'] ?? 0.0).toInt();
            final seed = (track.luaParams['Seed'] ?? 42.0).toInt();
            final newParams = SNESSFXRGenerator.generateParamsForType(sfxType, seed: seed);
            for (final entry in newParams.entries) {
              track.luaParams[entry.key] = entry.value;
              _setParam(entry.key, entry.value);
            }
            dawState.audioEngine.playNoteOrSample(
              track: track,
              midiNote: 72,
              velocity: 0.85,
              durationSec: 0.6,
            );
          }
          dawState.commitHistoryTransaction();
        }

        void showEditDialog() {
          showCompactValueEditDialog(
            context: context,
            title: node.label ?? paramDef.name.toUpperCase(),
            initialValue: displayVal,
            minMaxHint: 'Range: ${paramDef.min} - ${paramDef.max}',
            accentColor: accent,
            onSubmit: (val) {
              final parsed = double.tryParse(val.trim());
              if (parsed == null || parsed.isNaN || parsed.isInfinite) {
                // Revert / preserve existing value on unusable input
                return;
              }
              updateParamValue(parsed);
            },
            onResetDefault: () => updateParamValue(paramDef.defaultValue),
          );
        }

        return GlowingNixieDisplay(
          label: node.label ?? (node.param ?? 'READOUT').toUpperCase(),
          valueText: formattedVal,
          unit: node.unit,
          glowColor: accent,
          width: node.width,
          height: node.height,
          centerLabel: node.width != null,
          tooltip: '${node.label ?? paramDef.name}: $formattedVal (Scroll or Hold/Right-click to edit)',
          onLongPress: showEditDialog,
          onSecondaryTap: showEditDialog,
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final scrollDelta = pointerSignal.scrollDelta.dy;
              if (scrollDelta == 0) return;
              final step = paramDef.step > 0
                  ? paramDef.step
                  : (paramDef.isInteger ? 1.0 : (paramDef.max - paramDef.min) / 100.0);
              final delta = scrollDelta < 0 ? step : -step;
              final current = (track.luaParams[paramDef.name] ?? paramDef.defaultValue);
              updateParamValue(current + delta);
            }
          },
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

      case LuaGuiNodeType.spaceVisualizer:
        final isCab = (track.luaParams['isCabinet'] == 1.0) ||
            (node.canvasMode == 'cabinet') ||
            (track.name.toLowerCase().contains('cab'));
        final matIdx = (track.luaParams['Material'] ?? 0.0).toInt().clamp(0, AcousticMaterialType.values.length - 1);
        final currentSpace = AcousticSpaceParams(
          name: '${track.name}_space',
          width: track.luaParams['Width'] ?? (isCab ? 0.76 : 8.0),
          length: track.luaParams['Length'] ?? (isCab ? 0.76 : 12.0),
          height: track.luaParams['Height'] ?? (isCab ? 0.36 : 4.0),
          material: AcousticMaterialType.values[matIdx],
          rt60: isCab ? 0.035 : (track.luaParams['RT60'] ?? (track.luaParams['Decay'] ?? 1.8)),
          damping: track.luaParams['Damping'] ?? (isCab ? 0.55 : 0.40),
          isCabinetMode: isCab,
          micDistance: track.luaParams['MicDistance'] ?? 0.05,
          micAngleDeg: track.luaParams['MicAngle'] ?? (track.luaParams['OffAxis'] ?? 0.0),
          isOpenBack: (track.luaParams['OpenBack'] ?? 0.0) == 1.0,
        );

        return SpaceVisualizerWidget(
          params: currentSpace,
          height: node.height ?? 150.0,
          onParamsChanged: (newP) {
            track.luaParams['Width'] = newP.width;
            track.luaParams['Length'] = newP.length;
            track.luaParams['Height'] = newP.height;
            _setParam('Width', newP.width);
            _setParam('Length', newP.length);
            _setParam('Height', newP.height);
          },
        );

      case LuaGuiNodeType.waveshaperCanvas:
        final shapeVal = (track.luaParams['Shape'] ?? (track.luaParams['Curve'] ?? 0.0)).round().toInt();
        final tensionVal = (track.luaParams['Tension'] ?? 0.0);
        final preVal = (track.luaParams['Pre'] ?? (track.luaParams['Drive'] ?? 1.0));
        final postVal = (track.luaParams['Post'] ?? (track.luaParams['OutGain'] ?? 1.0));
        final dcFilterVal = (track.luaParams['DCFilter'] ?? 1.0) > 0.5;

        return WaveshaperCanvasWidget(
          shapeType: shapeVal,
          tension: tensionVal,
          preGain: preVal,
          postGain: postVal,
          dcFilter: dcFilterVal,
          height: node.height ?? 160.0,
          onShapeChanged: (newShape) {
            dawState.beginHistoryTransaction('WaveShaper Shape', icon: Icons.show_chart);
            _setParam('Shape', newShape.toDouble());
            _setParam('Curve', newShape.toDouble());
            dawState.commitHistoryTransaction();
          },
          onTensionChanged: (newTension) {
            dawState.beginHistoryTransaction('WaveShaper Tension', icon: Icons.gesture);
            _setParam('Tension', newTension);
            dawState.commitHistoryTransaction();
          },
        );

      case LuaGuiNodeType.canvas:
      case LuaGuiNodeType.dpad:
      case LuaGuiNodeType.gamepad:
        return InteractiveGameCanvasWidget(
          dawState: dawState,
          track: track,
          node: node,
          accentColor: accent,
          isLightChassis: isLightChassis,
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
    final baseAccent = track.color;

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
            border: Border.all(color: baseAccent.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideHeader) ...[
                Row(
                  children: [
                    Icon(Icons.tune, color: baseAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DYNAMIC SCRIPT PARAMETERS (CODE DRIVEN)',
                        style: EatsTheme.getPrimaryFontStyle(
                          color: baseAccent,
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
                          border: Border.all(color: baseAccent.withOpacity(0.4)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: selectedIdx.toDouble(),
                            isExpanded: true,
                            dropdownColor: EatsTheme.panelBackground,
                            icon: Icon(Icons.arrow_drop_down, color: baseAccent, size: 20),
                            items: List.generate(paramDef.options.length, (idx) {
                              return DropdownMenuItem<double>(
                                value: idx.toDouble(),
                                child: Text(
                                  paramDef.options[idx],
                                  style: EatsTheme.getDisplayFontStyle(
                                    color: baseAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                dawState.beginHistoryTransaction('Change ${paramDef.name} (${track.name})', icon: Icons.tune);
                                _setParam(paramDef.name, val);
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
                    child: EatsBeatsSlider(
                      value: currentVal,
                      min: paramDef.min,
                      max: paramDef.max,
                      defaultValue: paramDef.defaultValue,
                      label: paramDef.name,
                      activeColor: baseAccent,
                      onChanged: (val) {
                        final snapped = paramDef.isInteger ? val.roundToDouble() : val;
                        _setParam(paramDef.name, snapped);
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
                        color: baseAccent,
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
