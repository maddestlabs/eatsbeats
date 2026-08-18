import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/daw_state.dart';
import 'theme/eats_theme.dart';
import 'ui/arranger_view.dart';
import 'ui/eatsbits_loading_screen.dart';
import 'ui/edit_view.dart';
import 'ui/lua_workbench_view.dart';
import 'ui/mixer_view.dart';
import 'ui/track_inspector_view.dart';
import 'ui/transport_header.dart';
import 'ui/widgets/skeuomorphic_hardware_button.dart';
import 'ui/widgets/command_palette_dialog.dart';
import 'ui/widgets/project_browser_drawer.dart';
import 'ui/virtual_piano_keyboard.dart';
import 'utils/eats_file_helper.dart';

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
  runApp(const WrenDawApp());
}

class WrenDawApp extends StatefulWidget {
  const WrenDawApp({super.key});

  @override
  State<WrenDawApp> createState() => _WrenDawAppState();
}

class _WrenDawAppState extends State<WrenDawApp> {
  final DawState _dawState = DawState();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
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
    return AnimatedBuilder(
      animation: _dawState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Eatsbits',
          debugShowCheckedModeBanner: false,
          theme: EatsTheme.themeData,
          builder: (context, child) {
            final scale = _dawState.uiScale;
            if (scale == 1.0) {
              return child ?? const SizedBox.shrink();
            }
            return LayoutBuilder(
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
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _isInitialized
                ? DawMainShell(key: const ValueKey('daw_shell'), dawState: _dawState)
                : EatsbitsLoadingScreen(
                    key: const ValueKey('loading_screen'),
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
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            final editableState = primaryFocus.context!.findAncestorStateOfType<EditableTextState>();
            if (editableState != null) {
              return; // User is editing text (Script Editor, TextFields, manual dialogs). Do not interrupt typing.
            }
          }
          widget.dawState.togglePlay();
        },
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
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            if (primaryFocus.context!.findAncestorStateOfType<EditableTextState>() != null) return;
          }
          widget.dawState.undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            if (primaryFocus.context!.findAncestorStateOfType<EditableTextState>() != null) return;
          }
          widget.dawState.undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            if (primaryFocus.context!.findAncestorStateOfType<EditableTextState>() != null) return;
          }
          widget.dawState.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            if (primaryFocus.context!.findAncestorStateOfType<EditableTextState>() != null) return;
          }
          widget.dawState.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            if (primaryFocus.context!.findAncestorStateOfType<EditableTextState>() != null) return;
          }
          widget.dawState.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            if (primaryFocus.context!.findAncestorStateOfType<EditableTextState>() != null) return;
          }
          widget.dawState.redo();
        },
      },
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IndexedStack(
                          index: widget.dawState.activeTabIndex,
                          children: [
                            ArrangerView(dawState: widget.dawState),
                            EditView(dawState: widget.dawState),
                            TrackInspectorView(dawState: widget.dawState),
                            MixerView(dawState: widget.dawState),
                            LuaWorkbenchView(dawState: widget.dawState),
                          ],
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
              _buildNavButton(context, 4, 'SCRIPTS', Icons.code),
            ],
          ),
        ),
      ),
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
