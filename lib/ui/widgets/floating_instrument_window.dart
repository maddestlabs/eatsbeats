import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../lua/lua_engine.dart';
import '../../models/daw_state.dart';
import '../../models/script_target_model.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import '../modular/modular_rack_canvas.dart';
import 'dynamic_instrument_gui_widget.dart';
import 'preset_browser_dialog.dart';

/// A sleek, movable, resizable floating in-app VSTi Instrument & Audio FX window.
/// Supports both Skeuomorphic Hardware Panel mode and Eurorack Multi-Row Modular Rack mode.
class FloatingInstrumentWindow extends StatefulWidget {
  final DawState dawState;
  final Size? workspaceBounds;

  const FloatingInstrumentWindow({
    super.key,
    required this.dawState,
    this.workspaceBounds,
  });

  @override
  State<FloatingInstrumentWindow> createState() => _FloatingInstrumentWindowState();
}

class _FloatingInstrumentWindowState extends State<FloatingInstrumentWindow> {
  bool _isModularRackMode = false;
  String? _lastFittedTrackId;

  @override
  Widget build(BuildContext context) {
    if (!widget.dawState.isFloatingWindowVisible) {
      _lastFittedTrackId = null;
      return const SizedBox.shrink();
    }

    final fxInsert = widget.dawState.floatingFxInsert;
    final fxParentTrack = widget.dawState.floatingFxTrack;

    final TrackChannel? track;
    final void Function(String, double)? onParamChanged;
    final bool isFxMode;

    if (fxInsert != null && fxParentTrack != null) {
      isFxMode = true;
      track = TrackChannel(
        id: fxInsert.id,
        name: fxInsert.name,
        type: TrackType.luaScript,
        color: EatsTheme.secondaryMagenta,
        luaScriptCode: fxInsert.luaScriptCode ?? '',
        luaParams: fxInsert.luaParams,
      );
      onParamChanged = (param, val) {
        widget.dawState.updateFXParam(fxParentTrack, fxInsert.id, param, val);
      };
    } else {
      isFxMode = false;
      track = widget.dawState.floatingInstrumentTrack;
      onParamChanged = null;
    }

    if (track == null) return const SizedBox.shrink();
    final effectiveTrack = track;

    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final trackCompilation = effectiveTrack.luaScriptCode.isNotEmpty
        ? LuaEngine.compile(effectiveTrack.luaScriptCode)
        : widget.dawState.compilationResult;
    final guiLayout = trackCompilation.guiLayout;

    final accentColor = guiLayout?.accentColor ??
        (isFxMode
            ? EatsTheme.secondaryMagenta
            : (isGrungy ? const Color(0xFFFF8C00) : effectiveTrack.color));
    final titleText = (guiLayout?.title ?? effectiveTrack.name).toUpperCase();
    final subtitleText = guiLayout?.subtitle ??
        (isFxMode
            ? 'AUDIO FX INSERT'
            : (effectiveTrack.type == TrackType.luaScript ? 'INSTRUMENT' : effectiveTrack.type.name.toUpperCase()));
    final hasUpgrade = !isFxMode && widget.dawState.isPresetUpgradeAvailable(effectiveTrack);
    final isMaximized = widget.dawState.isFloatingWindowMaximized;
    final wsBounds = widget.workspaceBounds ?? MediaQuery.of(context).size;

    // Auto-scale window to "Fit to Screen" proportions whenever opened for a track (only when not maximized)
    if (!widget.dawState.isFloatingWindowMaximized && _lastFittedTrackId != effectiveTrack.id) {
      _lastFittedTrackId = effectiveTrack.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.dawState.isFloatingWindowVisible && !widget.dawState.isFloatingWindowMaximized) {
          widget.dawState.fitFloatingWindowToWorkspace(wsBounds, effectiveTrack);
        }
      });
    }

    return Material(
      type: MaterialType.transparency,
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
          color: isGrungy ? const Color(0xFF1B1714) : const Color(0xFF14171E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.75),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 16,
            ),
          ],
        ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // --- TOP TITLE BAR (DRAGGABLE WINDOW HEADER) ---
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isGrungy ? const Color(0xFF2B241E) : const Color(0xFF1E222B),
                border: Border(
                  bottom: BorderSide(color: accentColor.withOpacity(0.4), width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  // Track Color Dot & Title Area (Draggable Window Header)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        widget.dawState.updateFloatingWindowPosition(details.delta, parentBounds: wsBounds);
                      },
                      onDoubleTap: () {
                        if (isMaximized) {
                          widget.dawState.fitFloatingWindowToWorkspace(wsBounds, effectiveTrack);
                        } else {
                          widget.dawState.toggleMaximizeFloatingWindow(wsBounds);
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: accentColor.withOpacity(0.8), blurRadius: 5),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tooltip(
                              message: subtitleText,
                              child: Text(
                                titleText,
                                style: EatsTheme.getPrimaryFontStyle(
                                  color: EatsTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                    // Preset Update Available Button in Titlebar
                    if (hasUpgrade) ...[
                      GestureDetector(
                        onTap: () {
                          widget.dawState.upgradeTrackPreset(effectiveTrack);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Upgraded "$titleText" to latest preset! (Settings preserved)'),
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

                    // Preset Selector in Titlebar
                    _buildTitleBarPresetStrip(context, effectiveTrack, accentColor, isFxMode, fxInsert, fxParentTrack),

                    // 1. Open in Design tab
                    Tooltip(
                      message: 'Open in Design tab',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (isFxMode && fxInsert != null && fxParentTrack != null) {
                            final target = ScriptTarget(
                              id: 'fx_${fxParentTrack.id}_${fxInsert.id}',
                              type: ScriptTargetType.audioFx,
                              title: '${fxInsert.name} (${fxParentTrack.name})',
                              subtitle: 'Audio FX Insert Module',
                              trackId: fxParentTrack.id,
                              trackName: fxParentTrack.name,
                              trackColor: fxParentTrack.color,
                              secondaryId: fxInsert.id,
                            );
                            widget.dawState.openScriptInEditor(target);
                            widget.dawState.closeFloatingInstrumentWindow();
                          } else {
                            final target = ScriptTarget(
                              id: 'track_${effectiveTrack.id}_dsp',
                              type: ScriptTargetType.trackDsp,
                              title: '${effectiveTrack.name} (Synth DSP)',
                              subtitle: effectiveTrack.luaScriptCode.isNotEmpty ? 'Custom Lua Synth / DSP' : 'Instrument DSP Script',
                              trackId: effectiveTrack.id,
                              trackName: effectiveTrack.name,
                              trackColor: effectiveTrack.color,
                            );
                            widget.dawState.openScriptInEditor(target);
                            widget.dawState.closeFloatingInstrumentWindow();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: EatsTheme.controlBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.developer_board, size: 14, color: EatsTheme.primaryCyan),
                        ),
                      ),
                    ),

                    // 2. Fit to Screen
                    Tooltip(
                      message: 'Fit to screen',
                      child: InkWell(
                        onTap: () => widget.dawState.fitFloatingWindowToWorkspace(wsBounds),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: EatsTheme.controlBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.fit_screen, size: 14, color: EatsTheme.textSecondary),
                        ),
                      ),
                    ),

                    // 3. Fullscreen Toggle
                    Tooltip(
                      message: isMaximized ? 'Restore window size' : 'Fullscreen',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.dawState.toggleMaximizeFloatingWindow(wsBounds),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isMaximized
                                ? accentColor.withOpacity(0.25)
                                : EatsTheme.controlBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
                            size: 15,
                            color: isMaximized ? accentColor : EatsTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),

                    // 4. Tactical Chassis Screw Close Icon (Tooltip: "Close")
                    _InteractiveScrewButton(
                      accentColor: accentColor,
                      onTap: widget.dawState.closeFloatingInstrumentWindow,
                    ),
                  ],
                ),
              ),

            // --- WINDOW BODY (PROPORTIONALLY SCALED 1:1 TO FIT FLUSH WITH 0 PADDING) ---
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.all(6),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 520,
                          child: DynamicInstrumentGuiWidget(
                            dawState: widget.dawState,
                            track: effectiveTrack,
                            hostTrack: isFxMode ? fxParentTrack : null,
                            hideHeader: true,
                            onParamChanged: onParamChanged,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- CORNER RESIZE HANDLE (DYNAMIC RESIZE & AUTO 1:1 SCALING) ---
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        widget.dawState.updateFloatingWindowSize(details.delta);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.25),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                          ),
                        ),
                        child: CustomPaint(
                          painter: _ResizeGripPainter(color: accentColor),
                        ),
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
  );
}

  Widget _buildTitleBarPresetStrip(
    BuildContext context,
    TrackChannel track,
    Color accentColor,
    bool isFxMode,
    FXInsert? fxInsert,
    TrackChannel? fxParentTrack,
  ) {
    final trackPresets = widget.dawState.getPresetsForTrack(track);

    String activeName = 'PRESET';
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
                final targetPreset = trackPresets[targetIdx];
                widget.dawState.applyScriptPreset(track, targetPreset);
                if (isFxMode && fxInsert != null && fxParentTrack != null) {
                  for (final entry in targetPreset.params.entries) {
                    widget.dawState.updateFXParam(fxParentTrack, fxInsert.id, entry.key, entry.value);
                  }
                }
              },
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: accentColor.withOpacity(0.35)),
                ),
                child: Icon(Icons.chevron_left, size: 13, color: accentColor),
              ),
            ),
          if (trackPresets.isNotEmpty) const SizedBox(width: 3),

          // Preset Name Dropdown / Modal Button
          InkWell(
            onTap: () => PresetBrowserDialog.show(context, widget.dawState, track),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: accentColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 10, color: accentColor),
                  const SizedBox(width: 3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 85),
                    child: Text(
                      activeName.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: EatsTheme.getDisplayFontStyle(
                        color: accentColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 11, color: accentColor),
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
                final targetPreset = trackPresets[targetIdx];
                widget.dawState.applyScriptPreset(track, targetPreset);
                if (isFxMode && fxInsert != null && fxParentTrack != null) {
                  for (final entry in targetPreset.params.entries) {
                    widget.dawState.updateFXParam(fxParentTrack, fxInsert.id, entry.key, entry.value);
                  }
                }
              },
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: accentColor.withOpacity(0.35)),
                ),
                child: Icon(Icons.chevron_right, size: 13, color: accentColor),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tactile vintage hardware chassis mounting screw that closes the window when unscrewed/tapped.
class _InteractiveScrewButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color accentColor;

  const _InteractiveScrewButton({
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<_InteractiveScrewButton> createState() => _InteractiveScrewButtonState();
}

class _InteractiveScrewButtonState extends State<_InteractiveScrewButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.2),
                radius: 0.8,
                colors: _isHovered
                    ? [const Color(0xFFC0B8A8), const Color(0xFF5A5248)]
                    : [const Color(0xFF7A7265), const Color(0xFF26221F)],
              ),
              border: Border.all(
                color: _isHovered ? widget.accentColor : const Color(0xFF3E372E),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 3,
                  offset: const Offset(0, 1.5),
                ),
                if (_isHovered)
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.5),
                    blurRadius: 6,
                  ),
              ],
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(10, 10),
                painter: _ScrewSlotPainter(
                  color: _isHovered ? const Color(0xFF141210) : const Color(0xFF181512),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrewSlotPainter extends CustomPainter {
  final Color color;

  const _ScrewSlotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    const r = 3.5;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(15 * math.pi / 180);

    // Diagonal Cross slot cuts on screw head (15 deg rotated)
    canvas.drawLine(const Offset(-r, 0), const Offset(r, 0), paint);
    canvas.drawLine(const Offset(0, -r), const Offset(0, r), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScrewSlotPainter oldDelegate) => oldDelegate.color != color;
}

class _ResizeGripPainter extends CustomPainter {
  final Color color;

  const _ResizeGripPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(size.width - 4, size.height - 14), Offset(size.width - 14, size.height - 4), paint);
    canvas.drawLine(Offset(size.width - 4, size.height - 9), Offset(size.width - 9, size.height - 4), paint);
    canvas.drawLine(Offset(size.width - 4, size.height - 4), Offset(size.width - 4, size.height - 4), paint);
  }

  @override
  bool shouldRepaint(covariant _ResizeGripPainter oldDelegate) => oldDelegate.color != color;
}
