import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../lua/lua_engine.dart';
import '../../models/daw_state.dart';
import '../../models/script_target_model.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import '../modular/modular_rack_canvas.dart';
import 'dynamic_instrument_gui_widget.dart';

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

    // Auto-scale window to "Fit to Screen" proportions whenever opened for a track
    if (_lastFittedTrackId != effectiveTrack.id) {
      _lastFittedTrackId = effectiveTrack.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.dawState.isFloatingWindowVisible) {
          widget.dawState.fitFloatingWindowToWorkspace(wsBounds, effectiveTrack);
        }
      });
    }

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isGrungy ? const Color(0xFF1B1714) : EatsTheme.panelBackground,
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
            GestureDetector(
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
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isGrungy ? const Color(0xFF2B241E) : EatsTheme.panelHeader,
                  border: Border(
                    bottom: BorderSide(color: accentColor.withOpacity(0.4), width: 1.2),
                  ),
                ),
                child: Row(
                  children: [
                    // Track Color Dot
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

                    // Script-provided Window Title with Subtitle on Hover Tooltip
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

                    // Fit to Screen (Minimal Padding Proportional Sizing)
                    Tooltip(
                      message: 'Fit to Screen (Auto-scale Proportions)',
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

                    // Fill Workspace / Fullscreen Mode Toggle
                    Tooltip(
                      message: isMaximized ? 'Restore Window Size' : 'Fill Workspace (Fullscreen)',
                      child: InkWell(
                        onTap: () => widget.dawState.toggleMaximizeFloatingWindow(wsBounds),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 5),
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

                    // Open Code Editor Button
                    Tooltip(
                      message: 'Open in Script Editor (Tab 5)',
                      child: InkWell(
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
                            final idx = widget.dawState.activePattern.tracks.indexOf(effectiveTrack);
                            if (idx != -1) widget.dawState.activeTrackIndex = idx;
                            widget.dawState.activeTabIndex = 4;
                            widget.dawState.closeFloatingInstrumentWindow();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: EatsTheme.controlBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.code, size: 14, color: EatsTheme.primaryCyan),
                        ),
                      ),
                    ),

                    // Tactical Chassis Screw (Tap to Unscrew / Close Panel)
                    _InteractiveScrewButton(
                      accentColor: accentColor,
                      onTap: widget.dawState.closeFloatingInstrumentWindow,
                    ),
                  ],
                ),
              ),
            ),

            // --- WINDOW BODY (PROPORTIONALLY SCALED 1:1 TO FIT FLUSH WITH 0 PADDING) ---
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () {
                        if (isMaximized) {
                          widget.dawState.fitFloatingWindowToWorkspace(wsBounds, effectiveTrack);
                        } else {
                          widget.dawState.toggleMaximizeFloatingWindow(wsBounds);
                        }
                      },
                      child: Container(
                        color: isGrungy ? const Color(0xFF221E19) : EatsTheme.panelBackground,
                        padding: EdgeInsets.zero,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 520,
                            child: DynamicInstrumentGuiWidget(
                              dawState: widget.dawState,
                              track: effectiveTrack,
                              hideHeader: true,
                              onParamChanged: onParamChanged,
                            ),
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
      message: 'Unscrew Panel (Close VSTi - Esc)',
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
