import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../audio/convolver_engine.dart';
import '../../audio/procedural_ir_generator.dart';
import '../../audio/snes_dsp_engine.dart';
import '../../audio/soundfont_engine.dart';
import '../../audio/soundfont_decoder.dart';
import '../../lua/lua_engine.dart';
import '../../lua/lua_gui_model.dart';
import '../../lua/lua_script_library.dart';
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
import 'live_track_visualizer_widget.dart';
import 'lua_programmable_canvas_widget.dart';
import 'skeuomorphic_hardware_button.dart';
import 'skeuomorphic_hardware_knob.dart';
import 'skeuomorphic_hardware_slider.dart';
import 'skeuomorphic_hardware_switch.dart';
import '../../models/script_preset_model.dart';
import 'preset_browser_dialog.dart';
import 'script_search_dialog.dart';
import 'space_visualizer_widget.dart';
import 'stereo_meter_widget.dart';
import 'waveform_painter.dart';
import 'waveshaper_canvas_widget.dart';
import '../textures/daw_texture_engine.dart';

class DynamicInstrumentGuiWidget extends StatelessWidget {
  final DawState dawState;
  final TrackChannel track;
  final TrackChannel? hostTrack;
  final bool hideHeader;
  final void Function(String paramName, double value)? onParamChanged;

  const DynamicInstrumentGuiWidget({
    super.key,
    required this.dawState,
    required this.track,
    this.hostTrack,
    this.hideHeader = false,
    this.onParamChanged,
  });

  static final Map<String, LuaCompilationResult> _compilationCache = {};

  static LuaCompilationResult _getCompilation(String code, LuaCompilationResult fallback) {
    if (code.isEmpty) return fallback;
    final cached = _compilationCache[code];
    if (cached != null) return cached;
    final compiled = LuaEngine.compile(code);
    _compilationCache[code] = compiled;
    if (_compilationCache.length > 50) {
      _compilationCache.remove(_compilationCache.keys.first);
    }
    return compiled;
  }

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
        final trackCompilation = _getCompilation(track.luaScriptCode, dawState.compilationResult);

        final guiLayout = trackCompilation.guiLayout;

        // 1. If custom GUI layout is defined by script, render custom hardware rack faceplate
        if (guiLayout != null) {
          return _buildCustomRackPanel(context, guiLayout, trackCompilation);
        }

        // 2. If dynamic script parameters exist, render default dynamic parameters
        if (trackCompilation.params.isNotEmpty) {
          return _buildDefaultDynamicParams(context, trackCompilation);
        }

        // 3. Fallback: Render standard skeuomorphic track instrument panel
        return _buildFallbackTrackControls(context, trackCompilation);
      },
    );
  }

  Widget _buildFallbackTrackControls(
    BuildContext context,
    LuaCompilationResult compilation,
  ) {
    final baseAccent = track.color;
    return RepaintBoundary(
      child: Container(
        margin: hideHeader ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EatsTheme.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: baseAccent.withOpacity(0.4), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.piano, color: baseAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.name.toUpperCase(),
                    style: EatsTheme.getPrimaryFontStyle(
                      color: baseAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    PresetSearchDialog.show(
                      context,
                      dawState: dawState,
                      track: track,
                      initialCategory: LuaPresetCategory.instrument,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: baseAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: baseAccent.withOpacity(0.6)),
                    ),
                    child: Text(
                      'PRESETS',
                      style: TextStyle(color: baseAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SkeuomorphicHardwareKnob(
                  label: 'CUTOFF',
                  value: track.cutoff,
                  min: 20.0,
                  max: 20000.0,
                  defaultValue: 3000.0,
                  size: 52.0,
                  accentColor: baseAccent,
                  onChanged: (v) => dawState.setTrackCutoff(track, v),
                ),
                SkeuomorphicHardwareKnob(
                  label: 'RESO',
                  value: track.resonance,
                  min: 0.1,
                  max: 10.0,
                  defaultValue: 1.0,
                  size: 52.0,
                  accentColor: EatsTheme.secondaryMagenta,
                  onChanged: (v) => dawState.setTrackResonance(track, v),
                ),
                SkeuomorphicHardwareKnob(
                  label: 'ATTACK',
                  value: track.attack,
                  min: 0.001,
                  max: 2.0,
                  defaultValue: 0.01,
                  size: 52.0,
                  accentColor: EatsTheme.accentGold,
                  onChanged: (v) => dawState.setTrackAttack(track, v),
                ),
                SkeuomorphicHardwareKnob(
                  label: 'RELEASE',
                  value: track.release,
                  min: 0.01,
                  max: 5.0,
                  defaultValue: 0.3,
                  size: 52.0,
                  accentColor: EatsTheme.primaryCyan,
                  onChanged: (v) => dawState.setTrackRelease(track, v),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final isMinimal = layout.backgroundStyle == PanelBackgroundStyle.minimalWhite;
    final textureType = DawTextureEngine.mapStyleToTexture(layout.backgroundStyle);
    final isLightChassis = isSilver || isSnes || isMinimal || layout.backgroundStyle == PanelBackgroundStyle.blondePine;
    final baseAccent = layout.accentColor ??
        (isMinimal
            ? const Color(0xFF1E1E24)
            : (isSilver
                ? const Color(0xFF141416)
                : (isSnes ? const Color(0xFFE52521) : track.color)));
    final hasUpgrade = dawState.isPresetUpgradeAvailable(track);

    if (hideHeader) {
      Color basePanel;
      if (layout.backgroundColor != null) {
        basePanel = layout.backgroundColor!;
      } else if (isMinimal) {
        basePanel = const Color(0xFFECEEF2);
      } else if (isSnes) {
        basePanel = const Color(0xFFD8D6CD);
      } else if (isSilver) {
        basePanel = const Color(0xFFD4D0C5);
      } else if (isGrungy) {
        basePanel = const Color(0xFF26221D);
      } else if (layout.backgroundStyle == PanelBackgroundStyle.walnut) {
        basePanel = const Color(0xFF3B2414);
      } else if (layout.backgroundStyle == PanelBackgroundStyle.mahogany) {
        basePanel = const Color(0xFF451912);
      } else if (layout.backgroundStyle == PanelBackgroundStyle.blondePine) {
        basePanel = const Color(0xFFC7B591);
      } else if (layout.backgroundStyle == PanelBackgroundStyle.rosewood) {
        basePanel = const Color(0xFF211310);
      } else if (layout.backgroundStyle == PanelBackgroundStyle.brushedSteel || layout.backgroundStyle == PanelBackgroundStyle.brushedSteelVert) {
        basePanel = const Color(0xFF383D47);
      } else if (layout.backgroundStyle == PanelBackgroundStyle.tolex) {
        basePanel = const Color(0xFF161618);
      } else if (layout.backgroundStyle == PanelBackgroundStyle.carbon) {
        basePanel = const Color(0xFF121418);
      } else {
        basePanel = EatsTheme.panelBackground;
      }

      return RepaintBoundary(
        child: DawTexturedContainer(
          texture: textureType,
          textureRotation: layout.textureRotation,
          textureScale: layout.textureScale,
          color: basePanel,
          sideCheeks: layout.sideCheeks,
          cornerRadius: layout.cornerRadius,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: Border.all(
            color: isSnes
                ? const Color(0xFF908C82)
                : (isSilver
                    ? const Color(0xFF8C887D)
                    : (isGrungy ? const Color(0xFF423B33) : EatsTheme.panelHeader)),
            width: 1.2,
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
            textureRotation: layout.textureRotation,
            textureScale: layout.textureScale,
            cornerRadius: layout.cornerRadius,
            sideCheeks: layout.sideCheeks,
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
              _buildPresetStrip(context, baseAccent, isSilver),
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

  Widget _buildPresetStrip(BuildContext context, Color baseAccent, bool isSilver) {
    final trackPresets = dawState.getPresetsForTrack(track);
    final fgColor = isSilver ? const Color(0xFF141416) : baseAccent;

    String activeName = 'Custom';
    int activeIndex = -1;

    for (int i = 0; i < trackPresets.length; i++) {
      final p = trackPresets[i];
      bool isMatch = true;
      for (final e in p.params.entries) {
        if ((track.luaParams[e.key] ?? -999.0) != e.value) {
          isMatch = false;
          break;
        }
      }
      if (isMatch) {
        activeName = p.name;
        activeIndex = i;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous [<]
          if (trackPresets.isNotEmpty)
            InkWell(
              onTap: () {
                final targetIdx = activeIndex <= 0 ? trackPresets.length - 1 : activeIndex - 1;
                dawState.applyScriptPreset(track, trackPresets[targetIdx]);
              },
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: (isSilver ? Colors.black : Colors.white).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: fgColor.withOpacity(0.35)),
                ),
                child: Icon(Icons.chevron_left, size: 13, color: fgColor),
              ),
            ),
          if (trackPresets.isNotEmpty) const SizedBox(width: 3),

          // Preset Name Dropdown / Modal Button
          InkWell(
            onTap: () => PresetBrowserDialog.show(context, dawState, track),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (isSilver ? Colors.black : Colors.white).withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: fgColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 11, color: fgColor),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      activeName.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: EatsTheme.getDisplayFontStyle(
                        color: fgColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_drop_down, size: 12, color: fgColor),
                ],
              ),
            ),
          ),
          if (trackPresets.isNotEmpty) const SizedBox(width: 3),

          // Next [>]
          if (trackPresets.isNotEmpty)
            InkWell(
              onTap: () {
                final targetIdx = activeIndex >= trackPresets.length - 1 ? 0 : activeIndex + 1;
                dawState.applyScriptPreset(track, trackPresets[targetIdx]);
              },
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: (isSilver ? Colors.black : Colors.white).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: fgColor.withOpacity(0.35)),
                ),
                child: Icon(Icons.chevron_right, size: 13, color: fgColor),
              ),
            ),
        ],
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
        Widget rowWidget = Row(
          mainAxisAlignment: _parseMainAxisAlignment(node.align),
          crossAxisAlignment: _parseCrossAxisAlignment(node.crossAlign),
          children: node.children
              .map((c) => _buildNode(context, c, compilation, accent, isLightChassis))
              .toList(),
        );

        if (node.backgroundStyle != null || node.backgroundColor != null) {
          final isNodeLight = node.backgroundStyle == PanelBackgroundStyle.blondePine ||
              node.backgroundStyle == PanelBackgroundStyle.silver ||
              node.backgroundStyle == PanelBackgroundStyle.snes;
          rowWidget = DawTexturedContainer(
            backgroundStyle: node.backgroundStyle,
            color: node.backgroundColor ?? (isLightChassis ? Colors.black.withOpacity(0.05) : Colors.black.withOpacity(0.2)),
            textureRotation: node.textureRotation ?? 0.0,
            textureScale: node.textureScale ?? 1.0,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isNodeLight
                  ? const Color(0xFF9E9A8E)
                  : accent.withOpacity(0.25),
              width: 1.0,
            ),
            child: rowWidget,
          );
        }
        return rowWidget;

      case LuaGuiNodeType.column:
        final isMinimalColCard = node.backgroundStyle == PanelBackgroundStyle.minimalWhite ||
            (isLightChassis && node.backgroundStyle == null && node.children.length > 1 && node.width != null);

        Widget colWidget = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: _parseMainAxisAlignment(node.align),
          crossAxisAlignment: _parseCrossAxisAlignment(node.crossAlign),
          children: [
            if (node.action == 'bypass' || node.param == 'bypass' || node.param == 'power') ...[
              _buildPowerBypassButton(node, compilation, accent),
              const SizedBox(height: 12),
            ],
            ...node.children.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: _buildNode(context, c, compilation, accent, isLightChassis),
                )),
          ],
        );

        if (isMinimalColCard) {
          colWidget = Container(
            width: node.width,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBFC),
              borderRadius: BorderRadius.circular(node.cornerRadius ?? 26.0),
              border: Border.all(color: const Color(0xFFE4E7EE), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.95),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: colWidget,
          );
        } else if (node.backgroundStyle != null || node.backgroundColor != null) {
          final isNodeLight = node.backgroundStyle == PanelBackgroundStyle.blondePine ||
              node.backgroundStyle == PanelBackgroundStyle.silver ||
              node.backgroundStyle == PanelBackgroundStyle.snes;
          colWidget = DawTexturedContainer(
            backgroundStyle: node.backgroundStyle,
            color: node.backgroundColor ?? (isLightChassis ? Colors.black.withOpacity(0.05) : Colors.black.withOpacity(0.2)),
            textureRotation: node.textureRotation ?? 0.0,
            textureScale: node.textureScale ?? 1.0,
            padding: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isNodeLight
                  ? const Color(0xFF9E9A8E)
                  : accent.withOpacity(0.25),
              width: 1.0,
            ),
            child: colWidget,
          );
        }
        return colWidget;

      case LuaGuiNodeType.divider:
        if (node.action == 'link' || node.label == 'link' || node.text == 'link') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 24, height: 1, color: const Color(0xFFC0C4CC)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E9EE),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFB8BCC6), width: 0.8),
                  ),
                  child: const Icon(Icons.link, size: 11, color: Color(0xFF3A3D45)),
                ),
                Container(width: 24, height: 1, color: const Color(0xFFC0C4CC)),
              ],
            ),
          );
        }
        if (node.orientation == 'vertical') {
          return Container(
            width: node.width ?? 2.0,
            height: node.height ?? node.size ?? 68.0,
            margin: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: isLightChassis ? const Color(0xFFD4D8DF) : Colors.white12,
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
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: isLightChassis ? const Color(0xFFD4D8DF) : Colors.white12,
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
        final hasCustomBg = node.backgroundStyle != null || node.backgroundColor != null;
        final isMinimalGroup = node.backgroundStyle == PanelBackgroundStyle.minimalWhite || (isLightChassis && !hasCustomBg);
        final isNodeLight = node.backgroundStyle == PanelBackgroundStyle.blondePine ||
            node.backgroundStyle == PanelBackgroundStyle.silver ||
            node.backgroundStyle == PanelBackgroundStyle.snes ||
            isLightChassis;

        final groupBody = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (node.action == 'bypass' || node.param == 'bypass' || node.param == 'power') ...[
              _buildPowerBypassButton(node, compilation, accent),
              const SizedBox(height: 12),
            ],
            if (node.label != null && node.label != 'bypass') ...[
              Text(
                node.label!.toUpperCase(),
                style: EatsTheme.getDisplayFontStyle(
                  color: isNodeLight ? const Color(0xFF1E1E24) : accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ...node.children.map((c) => _buildNode(context, c, compilation, accent, isNodeLight)),
          ],
        );

        if (isMinimalGroup) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBFC),
              borderRadius: BorderRadius.circular(node.cornerRadius ?? 26.0),
              border: Border.all(color: const Color(0xFFE4E7EE), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.95),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: groupBody,
          );
        }

        if (hasCustomBg) {
          return DawTexturedContainer(
            backgroundStyle: node.backgroundStyle,
            color: node.backgroundColor ?? (isNodeLight ? Colors.black.withOpacity(0.05) : EatsTheme.panelHeader.withOpacity(0.6)),
            textureRotation: node.textureRotation ?? 0.0,
            textureScale: node.textureScale ?? 1.0,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(vertical: 4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isNodeLight
                  ? const Color(0xFF9E9A8E)
                  : accent.withOpacity(0.5),
              width: 1.2,
            ),
            child: groupBody,
          );
        }

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
                  : accent.withOpacity(0.5),
              width: 1.2,
            ),
          ),
          child: groupBody,
        );

      case LuaGuiNodeType.knob:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
        final currentVal = paramDef.isInteger ? rawVal.roundToDouble() : rawVal;

        return SkeuomorphicHardwareKnob(
          label: node.label ?? paramDef.name.toUpperCase(),
          showLabelText: node.showLabel,
          showValueText: node.showValue,
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
        final isVertical = node.orientation == 'vertical' || node.type == LuaGuiNodeType.fader || (node.sliderStyle == SliderStyle.minimalPill && node.orientation != 'horizontal');

        if (isVertical) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: node.height ?? 100.0,
                  width: node.width ?? 32.0,
                  child: SkeuomorphicHardwareSlider(
                    value: currentVal,
                    min: paramDef.min,
                    max: paramDef.max,
                    defaultValue: paramDef.defaultValue,
                    label: node.label ?? paramDef.name,
                    activeColor: accent,
                    orientation: Axis.vertical,
                    style: node.sliderStyle,
                    showLevelMarkings: false,
                    showTooltip: true,
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
                if (node.showLabel) ...[
                  const SizedBox(height: 6),
                  Text(
                    node.label ?? paramDef.name,
                    style: EatsTheme.getDisplayFontStyle(
                      color: isLightChassis ? const Color(0xFF1E1E24) : const Color(0xFFE2DDD5),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final displayFormatted = () {
          final f = paramDef.getFormattedValue(currentVal);
          return node.unit != null ? '$f ${node.unit}' : f;
        }();

        Widget sliderWidget = SizedBox(
          width: node.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      node.label ?? paramDef.name.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: EatsTheme.getDisplayFontStyle(
                        color: isLightChassis ? const Color(0xFF1B1A17) : const Color(0xFFE2DDD5),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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

        if (node.width == null) {
          sliderWidget = Expanded(child: sliderWidget);
        }
        return sliderWidget;

      case LuaGuiNodeType.segmentedPill:
        final paramDef = _findParam(node.param, compilation);
        final options = node.options.isNotEmpty
            ? node.options
            : (paramDef.options.isNotEmpty ? paramDef.options : ['Fast', 'Slow', 'Auto']);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue);
        final currentIdx = rawVal.round().toInt().clamp(0, options.length - 1);

        return _buildSegmentedPill(
          label: node.label,
          showLabel: node.showLabel,
          options: options,
          selectedIndex: currentIdx,
          accentColor: accent,
          isLightChassis: isLightChassis,
          onSelected: (idx) {
            _setParam(paramDef.name, idx.toDouble());
          },
        );

      case LuaGuiNodeType.switchToggle:
        final paramDef = _findParam(node.param, compilation);
        final rawVal = (track.luaParams[node.param] ?? paramDef.defaultValue);
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
            _setParam(paramDef.name, val ? 1.0 : 0.0);
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

            if (actionClean == 'trigger_tape_stop' ||
                actionClean.contains('tape_stop') ||
                labelClean.contains('tape stop')) {
              final stopTime = (track.luaParams['StopTime'] ?? 0.8).clamp(0.1, 3.0);
              final spinUpTime = (track.luaParams['SpinUpTime'] ?? 0.4).clamp(0.1, 2.0);
              dawState.triggerTapeStop(track.id, stopTime: stopTime, spinUpTime: spinUpTime);
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
              dawState.changeTrackSoundFont(track, fontId, displayName: displayName, renameTrack: false);
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

          final currentIr = track.sampleName.isNotEmpty
              ? track.sampleName
              : (track.luaParams['IRSample'] != null
                  ? (effectiveOptions.isNotEmpty
                      ? effectiveOptions[(track.luaParams['IRSample'] ?? 0.0).toInt().clamp(0, effectiveOptions.length - 1)]
                      : 'Great Hall')
                  : 'Great Hall');
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
        } else {
          onSelectionChanged = (newIdx) {
            track.luaParams[paramDef.name] = newIdx.toDouble();
            _setParam(paramDef.name, newIdx.toDouble());
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
          showLabel: node.showLabel,
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

      case LuaGuiNodeType.oscilloscope:
      case LuaGuiNodeType.spectrum:
        if (isLightChassis || node.canvasMode == 'formant_curve' || node.canvasMode == 'formant') {
          return _MinimalistFormantScreenWidget(
            width: node.width ?? 180.0,
            height: node.height ?? 100.0,
            accentColor: node.accentColor ?? const Color(0xFFD9603B),
            dawState: dawState,
            track: hostTrack ?? track,
          );
        }
        return LiveTrackVisualizerWidget(
          audioEngine: dawState.audioEngine,
          track: hostTrack ?? track,
          isSpectrum: node.type == LuaGuiNodeType.spectrum,
          accentColor: accent,
          width: node.width,
          height: node.height,
        );

      case LuaGuiNodeType.spaceVisualizer:
        final isCab = (track.luaParams['isCabinet'] == 1.0) ||
            (node.canvasMode == 'cabinet') ||
            (track.name.toLowerCase().contains('cab'));
        final matIdx = (track.luaParams['Material'] ?? 0.0).toInt().clamp(0, AcousticMaterialType.values.length - 1);
        final currentSpace = AcousticSpaceParams(
          name: '${track.name}_space',
          width: track.luaParams['Width'] ?? (isCab ? 0.76 : 12.0),
          length: track.luaParams['Length'] ?? (isCab ? 0.76 : 18.0),
          height: track.luaParams['Height'] ?? (isCab ? 0.36 : 6.0),
          sourceX: track.luaParams['SourceX'] ?? 0.5,
          sourceY: track.luaParams['SourceY'] ?? 0.5,
          sourceZ: track.luaParams['SourceZ'] ?? 0.5,
          listenerX: track.luaParams['ListenerX'] ?? 0.5,
          listenerY: track.luaParams['ListenerY'] ?? 0.8,
          listenerZ: track.luaParams['ListenerZ'] ?? 0.5,
          material: AcousticMaterialType.values[matIdx],
          rt60: isCab ? 0.035 : (track.luaParams['RT60'] ?? (track.luaParams['Decay'] ?? 1.8)),
          damping: track.luaParams['Damping'] ?? (isCab ? 0.55 : 0.40),
          isCabinetMode: isCab,
          micDistance: track.luaParams['MicDistance'] ?? 0.05,
          micAngleDeg: track.luaParams['MicAngle'] ?? (track.luaParams['OffAxis'] ?? 0.0),
          isOpenBack: (track.luaParams['OpenBack'] ?? 0.0) == 1.0,
          stereoWidth: track.luaParams['StereoWidth'] ?? (isCab ? 0.08 : 0.20),
        );

        return SpaceVisualizerWidget(
          params: currentSpace,
          height: node.height ?? 140.0,
          onParamsChanged: (newP) {
            _setParam('Width', newP.width);
            _setParam('Length', newP.length);
            _setParam('Height', newP.height);
            _setParam('SourceX', newP.sourceX);
            _setParam('SourceY', newP.sourceY);
            _setParam('SourceZ', newP.sourceZ);
            _setParam('ListenerX', newP.listenerX);
            _setParam('ListenerY', newP.listenerY);
            _setParam('ListenerZ', newP.listenerZ);
            _setParam('StereoWidth', newP.stereoWidth);
            _setParam('Material', newP.material.index.toDouble());
            _setParam('RT60', newP.rt60);
            _setParam('Decay', newP.rt60);
            _setParam('Damping', newP.damping);
            _setParam('MicDistance', newP.micDistance);
            _setParam('MicAngle', newP.micAngleDeg);
            _setParam('OffAxis', newP.micAngleDeg);
            _setParam('OpenBack', newP.isOpenBack ? 1.0 : 0.0);
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
        final mode = (node.canvasMode ?? '').toLowerCase();
        if (node.showDpad || node.showActionButtons || mode == 'grid' || mode == 'pixel' || mode == 'game' || mode == 'nibbles' || mode == 'runner' || mode == 'vector' || mode == 'spectrum' || mode == 'fft' || mode == 'oscilloscope' || mode == 'scope') {
          return InteractiveGameCanvasWidget(
            dawState: dawState,
            track: track,
            hostTrack: hostTrack,
            node: node,
            accentColor: accent,
            isLightChassis: isLightChassis,
          );
        }
        return LuaProgrammableCanvasWidget(
          dawState: dawState,
          track: hostTrack ?? track,
          node: node,
          accentColor: accent,
          isLightChassis: isLightChassis,
        );

      case LuaGuiNodeType.dpad:
      case LuaGuiNodeType.gamepad:
        return InteractiveGameCanvasWidget(
          dawState: dawState,
          track: track,
          hostTrack: hostTrack,
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
      case 'top':
        return MainAxisAlignment.start;
      case 'end':
      case 'right':
      case 'bottom':
        return MainAxisAlignment.end;
      case 'space_around':
      case 'spacearound':
      default:
        return MainAxisAlignment.spaceAround;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String align) {
    switch (align.toLowerCase()) {
      case 'start':
      case 'top':
      case 'left':
        return CrossAxisAlignment.start;
      case 'end':
      case 'bottom':
      case 'right':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'center':
      default:
        return CrossAxisAlignment.center;
    }
  }

  Widget _buildPowerBypassButton(LuaGuiNode node, LuaCompilationResult compilation, Color accent) {
    final paramName = node.param ?? (node.action ?? 'bypass');
    final rawVal = (track.luaParams[paramName] ?? 1.0);
    final isPoweredOn = rawVal > 0.5;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final nextVal = isPoweredOn ? 0.0 : 1.0;
          _setParam(paramName, nextVal);
        },
        child: Tooltip(
          message: 'Toggle Bypass (${isPoweredOn ? "Active" : "Bypassed"})',
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8EBF0),
              border: Border.all(color: const Color(0xFFD4D8DF), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 2,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.power_settings_new,
                size: 16,
                color: isPoweredOn ? const Color(0xFF1B1B1E) : const Color(0xFF9EA3B0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedPill({
    String? label,
    bool showLabel = true,
    required List<String> options,
    required int selectedIndex,
    required Color accentColor,
    required bool isLightChassis,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && showLabel) ...[
          Text(
            label.toUpperCase(),
            style: EatsTheme.getDisplayFontStyle(
              color: isLightChassis ? const Color(0xFF1E1E24) : const Color(0xFFE2DDD5),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Container(
          padding: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            color: isLightChassis ? const Color(0xFFE2E4EB) : const Color(0xFF14171E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLightChassis ? const Color(0xFFD0D4DD) : const Color(0xFF282D3A),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(options.length, (idx) {
              final isSelected = idx == selectedIndex;
              final optText = options[idx];

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isLightChassis ? const Color(0xFFFFFFFF) : accentColor)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    optText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (isLightChassis ? const Color(0xFF1B1B1E) : Colors.black)
                          : (isLightChassis ? const Color(0xFF6B707E) : const Color(0xFF8C92A4)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
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

class _OscilloscopeLivePainter extends CustomPainter {
  final Color accentColor;
  final bool isSpectrum;

  _OscilloscopeLivePainter({
    required this.accentColor,
    required this.isSpectrum,
  });

  // Pre-allocated static worker objects
  static final Paint _gridPaint = Paint()..strokeWidth = 0.75;
  static final Paint _barPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _beamPaint = Paint()
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _glowPaint = Paint()
    ..strokeWidth = 4.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Path _reusablePath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw subtle background oscilloscope reticle grid
    _gridPaint.color = accentColor.withOpacity(0.12);

    const divisionsX = 8;
    const divisionsY = 4;
    final stepX = size.width / divisionsX;
    final stepY = size.height / divisionsY;

    for (int i = 1; i < divisionsX; i++) {
      canvas.drawLine(Offset(i * stepX, 0), Offset(i * stepX, size.height), _gridPaint);
    }
    for (int j = 1; j < divisionsY; j++) {
      canvas.drawLine(Offset(0, j * stepY), Offset(size.width, j * stepY), _gridPaint);
    }

    final centerY = size.height / 2.0;

    if (isSpectrum) {
      // Draw FFT Frequency Spectrum Bars
      _barPaint.color = accentColor;

      const numBars = 32;
      final barWidth = size.width / numBars;
      for (int i = 0; i < numBars; i++) {
        final normIdx = i / numBars;
        // Simulated harmonic distribution for high-tech aesthetic
        final h = (0.2 + 0.7 * (1.0 - normIdx) * (1.0 + 0.3 * (i % 3))) * (size.height * 0.75);
        final rect = Rect.fromLTWH(i * barWidth + 1.5, size.height - h - 4, barWidth - 3, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), _barPaint);
      }
    } else {
      // Draw Analog Oscilloscope Continuous Waveform Beam
      _beamPaint.color = accentColor;
      _glowPaint.color = accentColor.withOpacity(0.35);

      _reusablePath.reset();
      const points = 100;
      for (int i = 0; i <= points; i++) {
        final t = i / points;
        final x = t * size.width;
        // Dynamic simulated analog phase for vibrant live aesthetic
        final y = centerY + (centerY * 0.7) * (0.8 * (t * 6.28 * 2.0).clamp(-1.0, 1.0) * (1.0 - (t - 0.5).abs() * 0.5));
        if (i == 0) {
          _reusablePath.moveTo(x, y);
        } else {
          _reusablePath.lineTo(x, y);
        }
      }
      canvas.drawPath(_reusablePath, _glowPaint);
      canvas.drawPath(_reusablePath, _beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OscilloscopeLivePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor || oldDelegate.isSpectrum != isSpectrum;
  }
}

class _MinimalistFormantScreenWidget extends StatelessWidget {
  final double width;
  final double height;
  final Color accentColor;
  final DawState dawState;
  final TrackChannel track;

  const _MinimalistFormantScreenWidget({
    required this.width,
    required this.height,
    required this.accentColor,
    required this.dawState,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    final f1 = track.luaParams['f1'] ?? track.luaParams['Low'] ?? 0.6;
    final f2 = track.luaParams['f2'] ?? track.luaParams['Mid'] ?? 0.45;
    final f3 = track.luaParams['f3'] ?? track.luaParams['High'] ?? 0.25;
    final air = track.luaParams['air'] ?? track.luaParams['Air'] ?? 0.35;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: const Color(0xFFD6D9E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC0C4CE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: CustomPaint(
          painter: _MinimalistFormantScreenPainter(
            accentColor: accentColor,
            formants: [f1, f2, f3, air],
            phase: 0.0,
          ),
        ),
      ),
    );
  }
}

class _MinimalistFormantScreenPainter extends CustomPainter {
  final Color accentColor;
  final List<double> formants;
  final double phase;

  _MinimalistFormantScreenPainter({
    required this.accentColor,
    required this.formants,
    required this.phase,
  });

  static final Paint _workerShader = Paint();
  static final Paint _innerShadow = Paint()
    ..color = const Color(0x99B5BAC4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _gridDotPaint = Paint()
    ..color = const Color(0x999095A2)
    ..strokeWidth = 0.8;
  static final Paint _curvePaint = Paint()
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Path _formantPath = Path();
  static final Path _curvePath = Path();

  static const List<String> _dbLevels = ['+12', '0', '-12', '-24'];
  static final List<TextPainter> _cachedDbPainters = _dbLevels.map((label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6E7382),
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return tp;
  }).toList();

  static const List<String> _freqs = ['100Hz', '500Hz', '2kHz', '10kHz'];
  static final List<TextPainter> _cachedFreqPainters = _freqs.map((label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 7.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6E7382),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return tp;
  }).toList();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Screen Bevel / LCD Surface Gradient
    final screenGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFDFE2E8),
        Color(0xFFCFD3DA),
      ],
    );
    _workerShader.shader = screenGradient.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _workerShader);
    canvas.drawRect(Offset.zero & size, _innerShadow);

    const padLeft = 24.0;
    const padRight = 8.0;
    const padTop = 10.0;
    const padBottom = 16.0;

    final plotW = size.width - padLeft - padRight;
    final plotH = size.height - padTop - padBottom;

    // 2. dB Level Axis Markings & Dotted Guide Lines
    for (int i = 0; i < _cachedDbPainters.length; i++) {
      final y = padTop + (i / (_cachedDbPainters.length - 1)) * plotH;
      for (double x = padLeft; x < padLeft + plotW; x += 4.0) {
        canvas.drawCircle(Offset(x, y), 0.5, _gridDotPaint);
      }
      final tp = _cachedDbPainters[i];
      tp.paint(canvas, Offset(2.0, y - tp.height / 2));
    }

    // 3. Frequency Guide Lines & Text
    for (int i = 0; i < _cachedFreqPainters.length; i++) {
      final x = padLeft + (i / (_cachedFreqPainters.length - 1)) * plotW;
      for (double y = padTop; y < padTop + plotH; y += 4.0) {
        canvas.drawCircle(Offset(x, y), 0.5, _gridDotPaint);
      }
      final tp = _cachedFreqPainters[i];
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - tp.height - 2));
    }

    // 4. Formant Translucent Filled Waveform Silhouette
    _formantPath.reset();
    _formantPath.moveTo(padLeft, padTop + plotH);

    final f1 = (formants.isNotEmpty ? formants[0] : 0.6).clamp(0.0, 1.0);
    final f2 = (formants.length > 1 ? formants[1] : 0.45).clamp(0.0, 1.0);
    final f3 = (formants.length > 2 ? formants[2] : 0.25).clamp(0.0, 1.0);
    final air = (formants.length > 3 ? formants[3] : 0.35).clamp(0.0, 1.0);

    const int steps = 60;
    for (int i = 0; i <= steps; i++) {
      final normX = i / steps;
      final x = padLeft + normX * plotW;

      final p1 = math.exp(-math.pow((normX - 0.18) / 0.10, 2)) * f1;
      final p2 = math.exp(-math.pow((normX - 0.42) / 0.12, 2)) * f2;
      final p3 = math.exp(-math.pow((normX - 0.68) / 0.10, 2)) * f3;
      final p4 = math.exp(-math.pow((normX - 0.88) / 0.14, 2)) * air;

      final combined = (p1 + p2 + p3 + p4).clamp(0.05, 0.95);
      final y = padTop + (1.0 - combined) * plotH;

      _formantPath.lineTo(x, y);
    }
    _formantPath.lineTo(padLeft + plotW, padTop + plotH);
    _formantPath.close();

    final fillGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x8CFFFFFF),
        Color(0x59B0B6C2),
      ],
    );
    _workerShader.shader = fillGradient.createShader(Rect.fromLTWH(padLeft, padTop, plotW, plotH));
    canvas.drawPath(_formantPath, _workerShader);

    // 5. Active Vibrant Formant Curve Line
    _curvePath.reset();
    for (int i = 0; i <= steps; i++) {
      final normX = i / steps;
      final x = padLeft + normX * plotW;

      final p1 = math.exp(-math.pow((normX - 0.18) / 0.10, 2)) * f1;
      final p2 = math.exp(-math.pow((normX - 0.42) / 0.12, 2)) * f2;
      final p3 = math.exp(-math.pow((normX - 0.68) / 0.10, 2)) * f3;
      final p4 = math.exp(-math.pow((normX - 0.88) / 0.14, 2)) * air;

      final combined = (p1 + p2 + p3 + p4).clamp(0.05, 0.95);
      final y = padTop + (1.0 - combined) * plotH;

      if (i == 0) {
        _curvePath.moveTo(x, y);
      } else {
        _curvePath.lineTo(x, y);
      }
    }

    _curvePaint.color = accentColor;
    canvas.drawPath(_curvePath, _curvePaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalistFormantScreenPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.phase != phase ||
        oldDelegate.formants != formants;
  }
}


