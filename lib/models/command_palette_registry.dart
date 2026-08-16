import 'package:flutter/material.dart';
import '../lua/lua_preset_library.dart';
import '../theme/eats_theme.dart';
import 'daw_state.dart';

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
  /// Generates a comprehensive list of all executable quick commands in Eatsbits.
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
    ]);

    // --- 2. TRANSPORT & DAW ACTIONS ---
    commands.addAll([
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
        return '8-Track Vintage (Ate Track)';
      case EatsThemePreset.midnightBites:
        return 'Midnight Bites (Obsidian Dark)';
      case EatsThemePreset.lightSnack:
        return 'Light Snack (Bright Studio)';
    }
  }

  static String _getThemeDescription(EatsThemePreset preset) {
    switch (preset) {
      case EatsThemePreset.ateTrack:
        return 'Authentic retro skeuomorphic hardware aesthetic with nixie displays & metallic grunts';
      case EatsThemePreset.midnightBites:
        return 'Sleek dark neon cyber aesthetic with high-contrast glowing accents';
      case EatsThemePreset.lightSnack:
        return 'Clean daylight studio theme for high visibility';
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
      case LuaPresetCategory.utility:
        return Icons.build;
    }
  }
}
