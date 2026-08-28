import 'package:flutter/material.dart';
import '../lua/lua_preset_library.dart';
import '../lua/lua_script_library.dart';
import '../ui/widgets/project_script_runner_dialog.dart';
import '../theme/eats_theme.dart';
import '../ui/widgets/ui_scale_dialog.dart';
import '../utils/fullscreen_helper.dart';
import 'daw_state.dart';
import 'track_model.dart';

enum CommandCategory {
  action,
  preset,
  view,
  theme,
  asset,
}

extension CommandCategoryExtension on CommandCategory {
  String get displayName {
    switch (this) {
      case CommandCategory.action:
        return 'ACTION';
      case CommandCategory.preset:
        return 'PRESET';
      case CommandCategory.view:
        return 'VIEW';
      case CommandCategory.theme:
        return 'THEME';
      case CommandCategory.asset:
        return 'ASSET';
    }
  }

  Color get categoryColor {
    switch (this) {
      case CommandCategory.action:
        return const Color(0xFF21F4E8); // Cyan
      case CommandCategory.preset:
        return const Color(0xFFFF8C00); // Orange
      case CommandCategory.view:
        return const Color(0xFF00FF66); // Neon Green
      case CommandCategory.theme:
        return const Color(0xFFBD00FF); // Purple
      case CommandCategory.asset:
        return const Color(0xFFFF0055); // Pink / Red
    }
  }
}

class QuickCommand {
  final String id;
  final String title;
  final String subtitle;
  final CommandCategory category;
  final IconData icon;
  final String? shortcutHint;
  final void Function(DawState dawState, BuildContext context) onExecute;

  const QuickCommand({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    this.shortcutHint,
    required this.onExecute,
  });
}

class CommandPaletteRegistry {
  /// Generates a comprehensive list of all executable quick commands in Eatsbeats.
  static List<QuickCommand> getCommands(DawState dawState, BuildContext context) {
    final List<QuickCommand> commands = [];

    // --- 1. VIEWS & NAVIGATION ---
    commands.addAll([
      QuickCommand(
        id: 'nav_arranger',
        title: 'Switch View: Arranger Timeline',
        subtitle: 'Main multi-track pattern clip arrangement workspace',
        category: CommandCategory.view,
        icon: Icons.view_timeline,
        shortcutHint: 'Nav Tab 1',
        onExecute: (state, ctx) => state.activeTabIndex = 0,
      ),
      QuickCommand(
        id: 'nav_edit',
        title: 'Switch View: Piano Roll & Note Editor',
        subtitle: 'Piano Roll, Tracker grid, and step sequence inspector',
        category: CommandCategory.view,
        icon: Icons.edit_note,
        shortcutHint: 'Nav Tab 2',
        onExecute: (state, ctx) => state.activeTabIndex = 1,
      ),
      QuickCommand(
        id: 'nav_track',
        title: 'Switch View: Track Inspector & FX Rack',
        subtitle: 'Track parameters, synth settings, modular audio/MIDI FX',
        category: CommandCategory.view,
        icon: Icons.settings_input_component,
        shortcutHint: 'Nav Tab 3',
        onExecute: (state, ctx) => state.activeTabIndex = 2,
      ),
      QuickCommand(
        id: 'nav_mixer',
        title: 'Switch View: Studio Mixer Desk',
        subtitle: 'Channel strips, volume meters, pan controls, and master bus',
        category: CommandCategory.view,
        icon: Icons.equalizer,
        shortcutHint: 'Nav Tab 4',
        onExecute: (state, ctx) => state.activeTabIndex = 3,
      ),
      QuickCommand(
        id: 'nav_scripts',
        title: 'Switch View: Lua Scripting Workbench',
        subtitle: 'Live Lua script editor, compiler, and DSP code workbench',
        category: CommandCategory.view,
        icon: Icons.code,
        shortcutHint: 'Nav Tab 5',
        onExecute: (state, ctx) => state.activeTabIndex = 4,
      ),
      QuickCommand(
        id: 'action_toggle_browser',
        title: 'Toggle Project & Preset Browser Drawer',
        subtitle: 'Open or close the side panel asset browser',
        category: CommandCategory.view,
        icon: Icons.folder_open,
        shortcutHint: 'Ctrl+B',
        onExecute: (state, ctx) => state.toggleBrowser(),
      ),
      QuickCommand(
        id: 'nav_history_browser',
        title: 'Open History & Time Travel Drawer',
        subtitle: 'Inspect action timeline, Lua diffs, and time-travel',
        category: CommandCategory.view,
        icon: Icons.history,
        shortcutHint: 'Browser Tab 5',
        onExecute: (state, ctx) {
          state.browserTabIndex = 4;
          if (!state.isBrowserOpen) state.toggleBrowser();
        },
      ),
      QuickCommand(
        id: 'view_toggle_fullscreen',
        title: 'View: Toggle Fullscreen Mode',
        subtitle: 'Toggle borderless desktop fullscreen display',
        category: CommandCategory.view,
        icon: Icons.fullscreen,
        shortcutHint: 'F11 / Alt+Enter',
        onExecute: (state, ctx) => FullscreenHelper.toggleFullscreen(),
      ),
      QuickCommand(
        id: 'view_adjust_scale',
        title: 'View: Adjust UI Scale (Magnification)...',
        subtitle: 'Open UI scale configuration dialog (70% - 130%)',
        category: CommandCategory.view,
        icon: Icons.aspect_ratio,
        onExecute: (state, ctx) => UiScaleDialog.show(ctx, state),
      ),
      QuickCommand(
        id: 'view_scale_100',
        title: 'View: Reset UI Scale to 100% (Default)',
        subtitle: 'Reset interface scaling to standard 1:1 ratio',
        category: CommandCategory.view,
        icon: Icons.restart_alt,
        onExecute: (state, ctx) => state.resetUiScale(),
      ),
      QuickCommand(
        id: 'view_scale_75',
        title: 'View: Set UI Scale to 75% (Compact)',
        subtitle: 'Compact UI scaling for maximum workspace visibility',
        category: CommandCategory.view,
        icon: Icons.zoom_out,
        onExecute: (state, ctx) => state.commitUiScale(0.75),
      ),
      QuickCommand(
        id: 'view_scale_125',
        title: 'View: Set UI Scale to 125% (Large)',
        subtitle: 'Enlarged UI scaling for high-resolution displays',
        category: CommandCategory.view,
        icon: Icons.zoom_in,
        onExecute: (state, ctx) => state.commitUiScale(1.25),
      ),
    ]);

    // --- 2. TRANSPORT & DAW ACTIONS ---
    commands.addAll([
      if (dawState.history.canUndo)
        QuickCommand(
          id: 'action_undo',
          title: 'Undo: ${dawState.history.nextUndoDescription ?? "Previous Action"}',
          subtitle: 'Revert last modification to song state',
          category: CommandCategory.action,
          icon: Icons.undo,
          shortcutHint: 'Ctrl+Z',
          onExecute: (state, ctx) => state.undo(),
        ),
      if (dawState.history.canRedo)
        QuickCommand(
          id: 'action_redo',
          title: 'Redo: ${dawState.history.nextRedoDescription ?? "Next Action"}',
          subtitle: 'Re-apply reverted modification',
          category: CommandCategory.action,
          icon: Icons.redo,
          shortcutHint: 'Ctrl+Y',
          onExecute: (state, ctx) => state.redo(),
        ),
      QuickCommand(
        id: 'action_save_checkpoint',
        title: 'Save Project Checkpoint / Milestone',
        subtitle: 'Bookmark current state in the history timeline',
        category: CommandCategory.action,
        icon: Icons.bookmark_add,
        onExecute: (state, ctx) {
          state.history.createMilestone(state, 'Checkpoint ${DateTime.now().minute}');
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Project checkpoint saved to history!'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
      QuickCommand(
        id: 'action_play_pause',
        title: dawState.isPlaying ? 'Pause Playback' : 'Start Playback',
        subtitle: 'Toggle master audio transport engine',
        category: CommandCategory.action,
        icon: dawState.isPlaying ? Icons.pause : Icons.play_arrow,
        shortcutHint: 'Space',
        onExecute: (state, ctx) => state.togglePlay(),
      ),
      QuickCommand(
        id: 'action_record',
        title: dawState.isRecording ? 'Stop Recording' : 'Arm Recording',
        subtitle: 'Toggle real-time step and live note recording',
        category: CommandCategory.action,
        icon: Icons.fiber_manual_record,
        shortcutHint: 'Rec',
        onExecute: (state, ctx) => state.toggleRecord(),
      ),
      QuickCommand(
        id: 'action_tap_tempo',
        title: 'Tap Tempo (Calculate BPM)',
        subtitle: 'Tap to set master project BPM dynamically',
        category: CommandCategory.action,
        icon: Icons.touch_app,
        onExecute: (state, ctx) => state.tapTempo(),
      ),
      QuickCommand(
        id: 'action_toggle_floating_vsti_window',
        title: 'Toggle Floating Instrument Window (VSTi)',
        subtitle: 'Show/hide resizable floating instrument GUI over the active workspace',
        category: CommandCategory.action,
        icon: Icons.picture_in_picture_alt,
        onExecute: (state, ctx) {
          state.toggleFloatingInstrumentWindow();
        },
      ),
      QuickCommand(
        id: 'action_upgrade_active_track_preset',
        title: 'Upgrade Active Track to Latest Preset Code',
        subtitle: 'Update active channel instrument script with latest GUI while keeping settings',
        category: CommandCategory.action,
        icon: Icons.upgrade,
        onExecute: (state, ctx) {
          if (state.isPresetUpgradeAvailable(state.activeTrack)) {
            state.upgradeTrackPreset(state.activeTrack);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Upgraded "${state.activeTrack.name}" to latest preset!'),
                duration: const Duration(seconds: 2),
                backgroundColor: EatsTheme.panelHeader,
              ),
            );
          } else {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: const Text('Active track is already up to date!'),
                duration: const Duration(seconds: 2),
                backgroundColor: EatsTheme.panelHeader,
              ),
            );
          }
        },
      ),
      QuickCommand(
        id: 'action_upgrade_all_track_presets',
        title: 'Upgrade All Tracks to Latest Preset Codes',
        subtitle: 'Batch update all project instruments with latest factory GUIs',
        category: CommandCategory.action,
        icon: Icons.auto_awesome,
        onExecute: (state, ctx) {
          final count = state.availablePresetUpgradeCount;
          if (count > 0) {
            state.upgradeAllTrackPresets();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Upgraded $count tracks to latest preset versions!'),
                duration: const Duration(seconds: 2),
                backgroundColor: EatsTheme.panelHeader,
              ),
            );
          } else {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: const Text('All project tracks are already up to date!'),
                duration: const Duration(seconds: 2),
                backgroundColor: EatsTheme.panelHeader,
              ),
            );
          }
        },
      ),
      // --- PROJECT ACTION & PROCEDURAL GENERATION SCRIPTS ---
      ...LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.projectAction).map((script) {
        return QuickCommand(
          id: 'project_script_${script.id}',
          title: 'Run Script: ${script.name}',
          subtitle: script.description,
          category: CommandCategory.action,
          icon: Icons.auto_awesome,
          onExecute: (state, ctx) {
            ProjectScriptRunnerDialog.show(ctx, dawState: state, script: script);
          },
        );
      }),
      QuickCommand(
        id: 'action_add_synth_track',
        title: 'Add Track: Synth / Instrument',
        subtitle: 'Create a new synthesizer channel',
        category: CommandCategory.action,
        icon: Icons.add,
        onExecute: (state, ctx) {
          state.addNewPresetTrack(
            LuaPresetLibrary.getPresetsByCategory(LuaPresetCategory.instrument).first,
          );
        },
      ),
      QuickCommand(
        id: 'action_add_lua_track',
        title: 'Add Track: Custom Lua DSP Script',
        subtitle: 'Create a scriptable Lua audio instrument channel',
        category: CommandCategory.action,
        icon: Icons.integration_instructions,
        onExecute: (state, ctx) {
          final customPreset = LuaPresetLibrary.presets.firstWhere(
            (p) => p.isInstrument,
            orElse: () => LuaPresetLibrary.presets.first,
          );
          state.addNewPresetTrack(customPreset);
        },
      ),
      QuickCommand(
        id: 'action_add_fx_reverb',
        title: 'Insert FX: Convolution Reverb',
        subtitle: 'Add space & acoustic impulse response reverb insert to active track',
        category: CommandCategory.action,
        icon: Icons.waves,
        onExecute: (state, ctx) {
          state.addFXInsert(state.activeTrack, FXType.convolutionReverb);
        },
      ),
      QuickCommand(
        id: 'action_add_fx_delay',
        title: 'Insert FX: Stereo Delay / Echo',
        subtitle: 'Add tempo-synced feedback delay insert to active track',
        category: CommandCategory.action,
        icon: Icons.replay,
        onExecute: (state, ctx) {
          state.addFXInsert(state.activeTrack, FXType.delay);
        },
      ),
      QuickCommand(
        id: 'action_add_fx_distortion',
        title: 'Insert FX: Overdrive / Distortion',
        subtitle: 'Add analog-style saturator distortion insert to active track',
        category: CommandCategory.action,
        icon: Icons.bolt,
        onExecute: (state, ctx) {
          state.addFXInsert(state.activeTrack, FXType.distortion);
        },
      ),
      QuickCommand(
        id: 'action_add_fx_compressor',
        title: 'Insert FX: Dynamics Compressor',
        subtitle: 'Add threshold & ratio dynamic range compression to active track',
        category: CommandCategory.action,
        icon: Icons.compress,
        onExecute: (state, ctx) {
          state.addFXInsert(state.activeTrack, FXType.compressor);
        },
      ),
      QuickCommand(
        id: 'action_add_fx_limiter',
        title: 'Insert FX: Brickwall Peak Limiter',
        subtitle: 'Add ceiling & threshold peak limiter insert to active track',
        category: CommandCategory.action,
        icon: Icons.speed,
        onExecute: (state, ctx) {
          state.addFXInsert(state.activeTrack, FXType.limiter);
        },
      ),
      QuickCommand(
        id: 'action_add_master_limiter',
        title: 'Master FX: Add Master Bus Limiter',
        subtitle: 'Add peak limiter to master output bus to prevent clipping',
        category: CommandCategory.action,
        icon: Icons.shield,
        onExecute: (state, ctx) {
          state.addFXInsert(state.masterTrack, FXType.limiter);
        },
      ),
      QuickCommand(
        id: 'action_add_master_compressor',
        title: 'Master FX: Add Master Bus Compressor',
        subtitle: 'Add glue dynamic compression to master mix output bus',
        category: CommandCategory.action,
        icon: Icons.compress,
        onExecute: (state, ctx) {
          state.addFXInsert(state.masterTrack, FXType.compressor);
        },
      ),
    ]);

    // --- 3. VISUAL THEMES ---
    for (final preset in EatsThemePreset.values) {
      commands.add(
        QuickCommand(
          id: 'theme_${preset.name}',
          title: 'Set Theme: ${_getThemeDisplayName(preset)}',
          subtitle: _getThemeDescription(preset),
          category: CommandCategory.theme,
          icon: Icons.palette,
          onExecute: (state, ctx) => state.setThemePreset(preset),
        ),
      );
    }

    // --- 4. LUA PRESETS & INSTRUMENTS / FX ---
    for (final preset in LuaPresetLibrary.presets) {
      commands.add(
        QuickCommand(
          id: 'preset_${preset.id}',
          title: 'Preset: ${preset.name}',
          subtitle: '${preset.category.displayName} • ${preset.description}',
          category: CommandCategory.preset,
          icon: _getPresetIcon(preset.category),
          onExecute: (state, ctx) {
            state.applyPreset(preset);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Applied "${preset.name}" to active channel'),
                duration: const Duration(seconds: 2),
                backgroundColor: EatsTheme.panelHeader,
              ),
            );
          },
        ),
      );
    }

    // --- 5. CURRENT PROJECT ASSETS & TRACKS ---
    final currentTrackIndex = dawState.activeTrackIndex;
    for (int i = 0; i < dawState.activePattern.tracks.length; i++) {
      final track = dawState.activePattern.tracks[i];
      final isCurrent = i == currentTrackIndex;
      commands.add(
        QuickCommand(
          id: 'asset_track_${track.id}',
          title: 'Jump to Channel: ${track.name}',
          subtitle: '${track.type.name.toUpperCase()} ${isCurrent ? "(ACTIVE)" : ""}',
          category: CommandCategory.asset,
          icon: Icons.audiotrack,
          onExecute: (state, ctx) {
            state.activeTrackIndex = i;
            state.activeTabIndex = 2; // Jump to track inspector
          },
        ),
      );
    }

    return commands;
  }

  /// Searches and filters commands by query text.
  static List<QuickCommand> search(String query, DawState dawState, BuildContext context) {
    final allCommands = getCommands(dawState, context);
    final cleanQuery = query.trim().toLowerCase();

    if (cleanQuery.isEmpty) {
      return allCommands;
    }

    final words = cleanQuery.split(RegExp(r'\s+'));

    return allCommands.where((cmd) {
      final searchableText = '${cmd.title} ${cmd.subtitle} ${cmd.category.displayName} ${cmd.shortcutHint ?? ""}'.toLowerCase();
      return words.every((word) => searchableText.contains(word));
    }).toList();
  }

  static String _getThemeDisplayName(EatsThemePreset preset) {
    switch (preset) {
      case EatsThemePreset.ateTrack:
        return 'Ate Track';
      case EatsThemePreset.midnightBites:
        return 'Midnight Bites (Obsidian Dark)';
      case EatsThemePreset.lightSnack:
        return 'Light Snack (Bright Studio)';
      case EatsThemePreset.breakfast:
        return 'Breakfast (Solarized Light)';
      case EatsThemePreset.dinner:
        return 'Dinner (Solarized Dark)';
    }
  }

  static String _getThemeDescription(EatsThemePreset preset) {
    switch (preset) {
      case EatsThemePreset.ateTrack:
        return 'Authentic retro skeuomorphic hardware aesthetic with nixie displays & metallic chassis';
      case EatsThemePreset.midnightBites:
        return 'Sleek dark neon cyber aesthetic with high-contrast glowing accents';
      case EatsThemePreset.lightSnack:
        return 'Clean daylight studio theme for high visibility';
      case EatsThemePreset.breakfast:
        return 'Solarized light theme with creamy parchment & warm accents';
      case EatsThemePreset.dinner:
        return 'Solarized dark theme with deep ocean teal & cyan accents';
    }
  }

  static IconData _getPresetIcon(LuaPresetCategory category) {
    switch (category) {
      case LuaPresetCategory.instrument:
        return Icons.piano;
      case LuaPresetCategory.audioFx:
        return Icons.graphic_eq;
      case LuaPresetCategory.midiFx:
        return Icons.music_note;
      case LuaPresetCategory.midiSeq:
        return Icons.view_timeline_outlined;
      case LuaPresetCategory.noteSplitter:
        return Icons.call_split;
      case LuaPresetCategory.projectAction:
        return Icons.auto_awesome;
      case LuaPresetCategory.utility:
        return Icons.build;
    }
  }
}
