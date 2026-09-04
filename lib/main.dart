import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/daw_state.dart';
import 'theme/eats_theme.dart';
import 'ui/arranger_view.dart';
import 'ui/eatsbeats_loading_screen.dart';
import 'ui/edit_view.dart';
import 'ui/lua_workbench_view.dart';
import 'ui/mixer_view.dart';
import 'ui/track_inspector_view.dart';
import 'ui/transport_header.dart';
import 'ui/widgets/skeuomorphic_hardware_button.dart';
import 'ui/widgets/command_palette_dialog.dart';
import 'ui/widgets/project_browser_drawer.dart';
import 'ui/widgets/floating_instrument_window.dart';
import 'ui/virtual_piano_keyboard.dart';
import 'utils/eats_file_helper.dart';
import 'utils/fullscreen_helper.dart';
import 'utils/url_script_helper.dart';
import 'shaders/shader_post_process_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }
  FlutterError.onError = (details) {
    debugPrint('FLUTTER ERROR: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PLATFORM UNHANDLED ERROR: $error\n$stack');
    return false;
  };
  runApp(const EatsbeatsApp());
}

class EatsbeatsApp extends StatefulWidget {
  const EatsbeatsApp({super.key});

  @override
  State<EatsbeatsApp> createState() => _EatsbeatsAppState();
}

class _EatsbeatsAppState extends State<EatsbeatsApp> {
  final DawState _dawState = DawState();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _dawState.loadPersistedSettings();
    EatsFileHelper.initGlobalAudioDrop((fileName, fileBytes) {
      _dawState.addSampleTrackFromFile(fileName: fileName, fileBytes: fileBytes);
    });
  }

  @override
  void dispose() {
    _dawState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _dawState.uiScaleNotifier,
      builder: (context, scale, _) {
        return MaterialApp(
          title: 'Eatsbeats',
          debugShowCheckedModeBanner: false,
          theme: EatsTheme.themeData,
          builder: (context, child) {
            Widget appContent;
            if (scale == 1.0) {
              appContent = child ?? const SizedBox.shrink();
            } else {
              appContent = LayoutBuilder(
                builder: (context, constraints) {
                  final logicalWidth = constraints.maxWidth / scale;
                  final logicalHeight = constraints.maxHeight / scale;
                  final logicalSize = Size(logicalWidth, logicalHeight);
                  final mediaQuery = MediaQuery.of(context);

                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: logicalWidth,
                        height: logicalHeight,
                        child: MediaQuery(
                          data: mediaQuery.copyWith(
                            size: logicalSize,
                          ),
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return ShaderPostProcessHost(
              dawState: _dawState,
              child: appContent,
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _isInitialized
                ? DawMainShell(key: const ValueKey('daw_shell'), dawState: _dawState)
                : EatsbeatsLoadingScreen(
                    key: const ValueKey('loading_screen'),
                    dawState: _dawState,
                    onInitializationComplete: () {
                      setState(() {
                        _isInitialized = true;
                      });
                    },
                  ),
          ),
        );
      },
    );
  }
}

class DawMainShell extends StatefulWidget {
  final DawState dawState;

  const DawMainShell({super.key, required this.dawState});

  @override
  State<DawMainShell> createState() => _DawMainShellState();
}

class _DawMainShellState extends State<DawMainShell> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _checkUrlScriptParam();
  }

  Future<void> _checkUrlScriptParam() async {
    try {
      final scriptParam = Uri.base.queryParameters['script'] ??
          Uri.base.queryParameters['gist'] ??
          Uri.base.queryParameters['song'];
      if (scriptParam != null && scriptParam.isNotEmpty) {
        final content = await UrlScriptHelper.resolveScript(scriptParam);
        if (content != null && content.isNotEmpty && mounted) {
          widget.dawState.loadFromEatsLua(content);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Loaded song from URL parameters!'),
              backgroundColor: EatsTheme.panelHeader,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading script from URL parameter: $e');
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _isEditingText() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;

    // Check specific debugLabels for code editors or Flutter's default EditableText
    final label = (primaryFocus.debugLabel ?? '').toLowerCase();
    if (label.contains('editabletext') ||
        label.contains('scriptviewcodeeditor') ||
        label.contains('luaworkbencheditor') ||
        label.contains('textfield') ||
        label.contains('text') ||
        label.contains('input')) {
      return true;
    }

    final context = primaryFocus.context;
    if (context != null && context.mounted) {
      try {
        if (context.findAncestorStateOfType<EditableTextState>() != null) return true;
        if (context.findAncestorWidgetOfExactType<EditableText>() != null) return true;
        if (context.findAncestorWidgetOfExactType<TextField>() != null) return true;
        if (context.findAncestorWidgetOfExactType<TextFormField>() != null) return true;
        if (context.widget is EditableText) return true;
      } catch (_) {}
    }

    return false;
  }

  void _handleDelete() {
    if (_isEditingText()) return;
    if (widget.dawState.activeTabIndex != 0) return; // Only delete in Arranger tab

    final activeClip = widget.dawState.activeClip;
    if (activeClip != null) {
      final track = widget.dawState.activePattern.tracks.firstWhere(
        (t) => t.id == activeClip.trackId || t.clips.any((c) => c.id == activeClip.id),
        orElse: () => widget.dawState.activeTrack,
      );
      widget.dawState.deleteClip(track, activeClip);
    } else {
      if (widget.dawState.activePattern.tracks.length > 1) {
        widget.dawState.deleteTrack(widget.dawState.activeTrack);
      }
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Desktop Fullscreen Shortcuts (F11 or Alt+Enter)
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      FullscreenHelper.toggleFullscreen();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (HardwareKeyboard.instance.isAltPressed ||
         HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.altLeft) ||
         HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.altRight))) {
      FullscreenHelper.toggleFullscreen();
      return true;
    }

    // Spacebar Play / Stop (respects text editing focus)
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (_isEditingText()) {
        return false; // Let text field receive space keystroke
      }
      widget.dawState.togglePlay();
      return true;
    }

    // Escape -> Close floating instrument window or return from EDIT view to ARRANGER view
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!_isEditingText()) {
        if (widget.dawState.isFloatingWindowVisible) {
          widget.dawState.closeFloatingInstrumentWindow();
          return true;
        } else if (widget.dawState.activeTabIndex == 1) {
          setState(() => widget.dawState.activeTabIndex = 0);
          return true;
        }
      }
    }

    return false;
  }
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dawState,
      builder: (context, _) {
        final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;

        return DropTarget(
          onDragDone: (detail) async {
            for (final file in detail.files) {
              try {
                final bytes = await file.readAsBytes();
                widget.dawState.addSampleTrackFromFile(
                  fileName: file.name,
                  fileBytes: bytes,
                );
              } catch (e) {
                debugPrint('Desktop drop error on ${file.name}: $e');
              }
            }
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          CommandPaletteDialog.show(context, widget.dawState);
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true): () {
          CommandPaletteDialog.show(context, widget.dawState);
        },
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
          CommandPaletteDialog.show(context, widget.dawState);
        },
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true): () {
          CommandPaletteDialog.show(context, widget.dawState);
        },
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          widget.dawState.toggleBrowser();
        },
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          widget.dawState.toggleBrowser();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (_isEditingText()) return;
          widget.dawState.undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
          if (_isEditingText()) return;
          widget.dawState.undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          if (_isEditingText()) return;
          widget.dawState.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): () {
          if (_isEditingText()) return;
          widget.dawState.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
          if (_isEditingText()) return;
          widget.dawState.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): () {
          if (_isEditingText()) return;
          widget.dawState.redo();
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (_isEditingText()) return;
          if (widget.dawState.activeTabIndex != 0) return;
          _handleDelete();
        },
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (_isEditingText()) return;
          final activeClip = widget.dawState.activeClip;
          if (activeClip != null) {
            final track = widget.dawState.activePattern.tracks.firstWhere(
              (t) => t.id == activeClip.trackId || t.clips.any((c) => c.id == activeClip.id),
              orElse: () => widget.dawState.activeTrack,
            );
            widget.dawState.duplicateClip(track, activeClip);
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (widget.dawState.isFloatingWindowVisible) {
            widget.dawState.closeFloatingInstrumentWindow();
          } else if (!_isEditingText() && widget.dawState.activeTabIndex == 1) {
            setState(() => widget.dawState.activeTabIndex = 0);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () {
          if (_isEditingText()) return;
          final activeClip = widget.dawState.activeClip;
          if (activeClip != null) {
            final track = widget.dawState.activePattern.tracks.firstWhere(
              (t) => t.id == activeClip.trackId || t.clips.any((c) => c.id == activeClip.id),
              orElse: () => widget.dawState.activeTrack,
            );
            widget.dawState.duplicateClip(track, activeClip);
          }
        },
        // macOS Desktop Fullscreen Shortcuts (Cmd+F / Ctrl+Cmd+F)
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          if (_isEditingText()) return;
          FullscreenHelper.toggleFullscreen();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, meta: true): () {
          FullscreenHelper.toggleFullscreen();
        },
      },
      child: FocusScope(
        autofocus: true,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              TickerMode(
                enabled: widget.dawState.guiAnimationsEnabled &&
                    !(widget.dawState.isFloatingWindowVisible && widget.dawState.isFloatingWindowMaximized),
                child: Offstage(
                  offstage: widget.dawState.isFloatingWindowVisible && widget.dawState.isFloatingWindowMaximized,
                  child: Scaffold(
                    backgroundColor: EatsTheme.backgroundDark,
                  body: SafeArea(
                    child: Column(
                      children: [
                        // Top Transport Header (Always Visible)
                        TransportHeader(dawState: widget.dawState),

                        // Main Studio Workbench Body & Optional Project Browser Drawer
                        Expanded(
                          child: Container(
                            color: EatsTheme.backgroundDark,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final wsBounds = Size(constraints.maxWidth, constraints.maxHeight);
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: IndexedStack(
                                        index: widget.dawState.activeTabIndex,
                                        children: [
                                          TickerMode(
                                            enabled: widget.dawState.activeTabIndex == 0,
                                            child: ArrangerView(dawState: widget.dawState),
                                          ),
                                          TickerMode(
                                            enabled: widget.dawState.activeTabIndex == 1,
                                            child: EditView(dawState: widget.dawState),
                                          ),
                                          TickerMode(
                                            enabled: widget.dawState.activeTabIndex == 2,
                                            child: TrackInspectorView(dawState: widget.dawState),
                                          ),
                                          TickerMode(
                                            enabled: widget.dawState.activeTabIndex == 3,
                                            child: MixerView(dawState: widget.dawState),
                                          ),
                                          TickerMode(
                                            enabled: widget.dawState.activeTabIndex == 4,
                                            child: LuaWorkbenchView(dawState: widget.dawState),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Scalable, Movable, Resizable Floating In-App VSTi Window (Normal Floating Mode)
                                    if (widget.dawState.isFloatingWindowVisible && !widget.dawState.isFloatingWindowMaximized)
                                      Positioned(
                                        left: widget.dawState.floatingWindowPosition.dx,
                                        top: widget.dawState.floatingWindowPosition.dy,
                                        width: widget.dawState.floatingWindowSize.width,
                                        height: widget.dawState.floatingWindowSize.height,
                                        child: FloatingInstrumentWindow(
                                          dawState: widget.dawState,
                                          workspaceBounds: wsBounds,
                                        ),
                                      ),

                                    // Fast 150ms Animated Slide-In / Slide-Out Project Browser Drawer
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 150),
                                      curve: Curves.fastOutSlowIn,
                                      top: 0,
                                      bottom: 0,
                                      right: widget.dawState.isBrowserOpen ? 0 : -330,
                                      width: 320,
                                      child: IgnorePointer(
                                        ignoring: !widget.dawState.isBrowserOpen,
                                        child: ProjectBrowserDrawer(
                                          dawState: widget.dawState,
                                          onClose: widget.dawState.toggleBrowser,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        // Virtual Piano Keyboard Drawer (Pull tab right above bottom panel)
                        VirtualPianoKeyboard(dawState: widget.dawState),
                      ],
                    ),
                  ),

                  // Hardware Mechanical Navigation Control Strip
                  bottomNavigationBar: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isGrungy ? const Color(0xFF24201C) : EatsTheme.panelHeader,
                      border: Border(
                        top: BorderSide(
                          color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.panelHeader,
                          width: 1.5,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavButton(context, 0, 'ARRANGER', Icons.view_timeline),
                        _buildNavButton(context, 1, 'EDIT', Icons.edit_note),
                        _buildNavButton(context, 2, 'TRACK', Icons.settings_input_component),
                        _buildNavButton(context, 3, 'MIXER', Icons.equalizer),
                        _buildNavButton(context, 4, 'DESIGN', Icons.developer_board),
                      ],
                    ),
                  ),
                ),
              ),
            ),

              // Dedicated High-Performance Fullscreen Device Modal (Instrument, MIDI FX, Audio FX)
              if (widget.dawState.isFloatingWindowVisible && widget.dawState.isFloatingWindowMaximized)
                Positioned.fill(
                  child: SafeArea(
                    child: Material(
                      color: EatsTheme.backgroundDark,
                      child: TickerMode(
                        enabled: widget.dawState.guiAnimationsEnabled,
                        child: FloatingInstrumentWindow(
                          dawState: widget.dawState,
                          workspaceBounds: MediaQuery.of(context).size,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
},
);
}

  Widget _buildNavButton(BuildContext context, int index, String label, IconData icon) {
    final isSelected = widget.dawState.activeTabIndex == index;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: SkeuomorphicHardwareButton(
          label: isMobile ? null : label,
          icon: icon,
          isActive: isSelected,
          activeColor: EatsTheme.primaryCyan,
          onTap: () => setState(() => widget.dawState.activeTabIndex = index),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
      ),
    );
  }
}
