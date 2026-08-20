import 'package:flutter/material.dart';
import '../../lua/lua_preset_library.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';
import '../../audio/soundfont_engine.dart';
import '../../utils/soundfont_pack_manager.dart';
import '../../utils/ir_pack_manager.dart';
import '../../models/history_manager.dart';
import '../../models/track_model.dart';
import '../../models/script_target_model.dart';
import 'command_palette_dialog.dart';

class SoundFontDragItem {
  final String fontId;
  final String displayName;

  SoundFontDragItem({
    required this.fontId,
    required this.displayName,
  });
}

class ProjectBrowserDrawer extends StatefulWidget {
  final DawState dawState;
  final VoidCallback onClose;

  const ProjectBrowserDrawer({
    super.key,
    required this.dawState,
    required this.onClose,
  });

  @override
  State<ProjectBrowserDrawer> createState() => _ProjectBrowserDrawerState();
}

class _ProjectBrowserDrawerState extends State<ProjectBrowserDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _presetSearchController = TextEditingController();
  LuaPresetCategory? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.dawState.browserTabIndex.clamp(0, 4),
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        widget.dawState.browserTabIndex = _tabController.index;
      }
    });
    _presetSearchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _presetSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final drawerBg = isGrungy ? const Color(0xFF1E1A17) : EatsTheme.backgroundDark;
    final borderColor = isGrungy ? const Color(0xFF4A423A) : EatsTheme.panelHeader;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: drawerBg,
        border: Border(
          left: BorderSide(color: borderColor, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 10,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: EatsTheme.panelHeader,
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.folder_copy, color: EatsTheme.primaryCyan, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'PROJECT BROWSER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EatsTheme.getDisplayFontStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: EatsTheme.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search, size: 18),
                      tooltip: 'Open Quick Command Palette (Ctrl+Shift+P)',
                      color: EatsTheme.primaryCyan,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => CommandPaletteDialog.show(context, widget.dawState),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Close Browser Drawer (Ctrl+B)',
                      color: EatsTheme.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Selection Strip
          Container(
            color: isGrungy ? const Color(0xFF2B2621) : EatsTheme.panelHeader.withOpacity(0.5),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: EatsTheme.primaryCyan,
              indicatorWeight: 3,
              labelColor: EatsTheme.primaryCyan,
              unselectedLabelColor: EatsTheme.textMuted,
              tabs: const [
                Tab(
                  icon: Tooltip(
                    message: 'Project Assets (Tracks & SoundFonts)',
                    child: Icon(Icons.inventory_2_outlined, size: 20),
                  ),
                ),
                Tab(
                  icon: Tooltip(
                    message: 'Preset Library (Synths & Sequences)',
                    child: Icon(Icons.library_music_outlined, size: 20),
                  ),
                ),
                Tab(
                  icon: Tooltip(
                    message: 'Expansion Packs (SoundFonts & IRs)',
                    child: Icon(Icons.cloud_download_outlined, size: 20),
                  ),
                ),
                Tab(
                  icon: Tooltip(
                    message: 'UI Themes & Visual Styles',
                    child: Icon(Icons.palette_outlined, size: 20),
                  ),
                ),
                Tab(
                  icon: Tooltip(
                    message: 'History & Time Travel (Undo/Redo)',
                    child: Icon(Icons.history, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Tab Body Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectAssetsTab(),
                _buildPresetsTab(),
                _buildPacksTab(),
                _buildThemesTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: PROJECT ASSETS ---
  Widget _buildProjectAssetsTab() {
    final state = widget.dawState;
    final activePattern = state.activePattern;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('CHANNEL TRACKS (${activePattern.tracks.length})', Icons.audiotrack),
        ...activePattern.tracks.asMap().entries.map((entry) {
          final idx = entry.key;
          final track = entry.value;
          final isSelected = idx == state.activeTrackIndex;

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isSelected ? EatsTheme.primaryCyan.withOpacity(0.15) : Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? EatsTheme.primaryCyan : Colors.transparent,
                width: 1,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                leading: CircleAvatar(
                  radius: 6,
                  backgroundColor: track.color,
                ),
                title: Text(
                  track.name,
                  style: EatsTheme.getPrimaryFontStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : EatsTheme.textLight,
                  ),
                ),
                subtitle: Text(
                  '${track.type.name.toUpperCase()} • ${track.clips.length} clip(s)',
                  style: EatsTheme.getPrimaryFontStyle(fontSize: 10, color: EatsTheme.textMuted),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, size: 14, color: EatsTheme.primaryCyan)
                    : null,
                onTap: () {
                  state.activeTrackIndex = idx;
                },
              ),
            ),
          );
        }),

        const SizedBox(height: 12),
        _buildSectionHeader('PROJECT SCRIPT MATRIX', Icons.code),
        ..._buildProjectScriptMatrixList(state),

        const SizedBox(height: 12),
        _buildSectionHeader('AUDIO FX INSERTS', Icons.tune),
        ..._buildAudioFxInsertsList(state),

        const SizedBox(height: 12),
        _buildSectionHeader('SOUNDFONTS & IMPULSES', Icons.library_music),
        AnimatedBuilder(
          animation: SoundFontEngine.instance,
          builder: (context, _) {
            final loadedFonts = SoundFontEngine.instance.loadedDisplayFonts;
            return Column(
              children: loadedFonts.entries.map((entry) {
                final fontId = entry.key;
                final displayName = entry.value;
                final dragItem = SoundFontDragItem(fontId: fontId, displayName: displayName);

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EatsTheme.panelHeader.withOpacity(0.6), width: 1),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      leading: Draggable<SoundFontDragItem>(
                        data: dragItem,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: EatsTheme.panelHeader,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: EatsTheme.accentGreen, width: 2),
                              boxShadow: [
                                BoxShadow(color: EatsTheme.accentGreen.withOpacity(0.4), blurRadius: 12),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.piano, color: EatsTheme.accentGreen, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  displayName,
                                  style: EatsTheme.getPrimaryFontStyle(
                                    color: EatsTheme.accentGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Tooltip(
                          message: 'Drag icon to track',
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF66).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.piano, size: 18, color: Color(0xFF00FF66)),
                          ),
                        ),
                      ),
                    ),
                    title: Text(displayName, style: EatsTheme.getPrimaryFontStyle(fontSize: 11, color: EatsTheme.textLight)),
                    subtitle: Text('SoundFont Instrument Bank (Drag icon or tap)', style: EatsTheme.getPrimaryFontStyle(fontSize: 9, color: EatsTheme.textMuted)),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      tooltip: 'Add as New Track',
                      color: EatsTheme.accentGreen,
                      onPressed: () {
                        widget.dawState.addNewSoundFontTrack(fontId, displayName: displayName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added new track with SoundFont "$displayName"'),
                            backgroundColor: EatsTheme.panelHeader,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      widget.dawState.applySoundFont(fontId, displayName: displayName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Loaded SoundFont "$displayName" onto active track'),
                          backgroundColor: EatsTheme.panelHeader,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildProjectScriptMatrixList(DawState state) {
    final targets = state.getAllScriptTargets();
    if (targets.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text('No active scripts in project', style: EatsTheme.getPrimaryFontStyle(fontSize: 10, color: EatsTheme.textMuted)),
        ),
      ];
    }

    return targets.map((target) {
      final isCurrent = state.activeScriptTarget.id == target.id;
      final badgeBg = target.type == ScriptTargetType.trackDsp
          ? EatsTheme.primaryCyan
          : (target.type == ScriptTargetType.midiFx ? EatsTheme.accentGold : EatsTheme.secondaryMagenta);

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isCurrent ? EatsTheme.primaryCyan.withOpacity(0.15) : Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isCurrent ? EatsTheme.primaryCyan : Colors.transparent,
            width: 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: badgeBg.withOpacity(0.6), width: 0.8),
              ),
              child: Icon(target.iconData, size: 14, color: badgeBg),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    target.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EatsTheme.getPrimaryFontStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.white : EatsTheme.textLight,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    target.typeBadge,
                    style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              target.subtitle,
              style: EatsTheme.getPrimaryFontStyle(fontSize: 9, color: EatsTheme.textMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 11, color: Colors.white30),
            onTap: () {
              state.openScriptInEditor(target);
            },
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildAudioFxInsertsList(DawState state) {
    final fxEntries = <Map<String, dynamic>>[];
    for (final track in state.activePattern.tracks) {
      for (final fx in track.fxRack) {
        fxEntries.add({
          'fx': fx,
          'track': track,
        });
      }
    }

    if (fxEntries.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text('No Audio FX inserts active', style: EatsTheme.getPrimaryFontStyle(fontSize: 10, color: EatsTheme.textMuted)),
        ),
      ];
    }

    return fxEntries.map((entry) {
      final FXInsert fx = entry['fx'];
      final TrackChannel track = entry['track'];

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: Icon(
              Icons.tune,
              size: 16,
              color: fx.enabled ? EatsTheme.secondaryMagenta : EatsTheme.textMuted,
            ),
            title: Text(
              fx.name,
              style: EatsTheme.getPrimaryFontStyle(
                fontSize: 11,
                color: fx.enabled ? EatsTheme.textLight : EatsTheme.textMuted,
              ),
            ),
            subtitle: Text(
              'Track: ${track.name} • Mix: ${(fx.mix * 100).round()}%',
              style: EatsTheme.getPrimaryFontStyle(fontSize: 9, color: EatsTheme.textMuted),
            ),
            trailing: Text(
              fx.enabled ? 'ACTIVE' : 'BYPASS',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: fx.enabled ? EatsTheme.accentGreen : EatsTheme.muteColor,
              ),
            ),
            onTap: () {
              final tIdx = state.activePattern.tracks.indexOf(track);
              if (tIdx != -1) state.activeTrackIndex = tIdx;
              state.activeTabIndex = 2; // Jump to Track Inspector
            },
          ),
        ),
      );
    }).toList();
  }

  // --- TAB 2: PRESET LIBRARY (WITH DRAG & DROP) ---
  Widget _buildPresetsTab() {
    final query = _presetSearchController.text.trim().toLowerCase();
    List<LuaPreset> presets = LuaPresetLibrary.presets;

    if (_selectedCategoryFilter != null) {
      presets = presets.where((p) => p.category == _selectedCategoryFilter).toList();
    }

    if (query.isNotEmpty) {
      presets = presets.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query) ||
            p.category.displayName.toLowerCase().contains(query);
      }).toList();
    }

    return Column(
      children: [
        // Preset Search Input
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _presetSearchController,
            style: EatsTheme.getDisplayFontStyle(fontSize: 12, color: EatsTheme.textLight),
            decoration: InputDecoration(
              hintText: 'Filter presets...',
              hintStyle: EatsTheme.getPrimaryFontStyle(fontSize: 11, color: EatsTheme.textMuted),
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: EatsTheme.panelHeader),
              ),
            ),
          ),
        ),

        // Category Filter Chips (Compact Icons)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryChip(
                category: null,
                icon: Icons.apps,
                tooltip: 'All Presets',
              ),
              _buildCategoryChip(
                category: LuaPresetCategory.midiSeq,
                icon: Icons.view_timeline_outlined,
                tooltip: 'Filter: MIDI Sequences',
              ),
              _buildCategoryChip(
                category: LuaPresetCategory.instrument,
                icon: Icons.piano,
                tooltip: 'Filter: Synth Instruments',
              ),
              _buildCategoryChip(
                category: LuaPresetCategory.audioFx,
                icon: Icons.graphic_eq,
                tooltip: 'Filter: Audio FX',
              ),
              _buildCategoryChip(
                category: LuaPresetCategory.midiFx,
                icon: Icons.music_note,
                tooltip: 'Filter: MIDI FX',
              ),
              _buildCategoryChip(
                category: LuaPresetCategory.utility,
                icon: Icons.build,
                tooltip: 'Filter: Utilities',
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Presets List with Draggable Wrapper
        Expanded(
          child: presets.isEmpty
              ? Center(
                  child: Text(
                    'No matching presets',
                    style: EatsTheme.getPrimaryFontStyle(fontSize: 12, color: EatsTheme.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final preset = presets[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EatsTheme.panelHeader.withOpacity(0.6), width: 1),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Draggable<LuaPreset>(
                          data: preset,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(preset.category),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getCategoryIcon(preset.category), size: 16, color: Colors.black),
                                  const SizedBox(width: 6),
                                  Text(
                                    preset.name,
                                    style: EatsTheme.getPrimaryFontStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Tooltip(
                              message: preset.isInstrument
                                  ? 'Drag instrument to track or empty space to create track'
                                  : preset.isAudioFx
                                      ? 'Drag FX to existing track header or FX rack'
                                      : preset.isMidiFx
                                          ? 'Drag MIDI FX to clip in arranger'
                                          : preset.isMidiSeq
                                              ? 'Drag sequence to clip in arranger'
                                              : 'Drag to track',
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(preset.category).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  _getCategoryIcon(preset.category),
                                  size: 18,
                                  color: _getCategoryColor(preset.category),
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          preset.name,
                          style: EatsTheme.getPrimaryFontStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: EatsTheme.textLight,
                          ),
                        ),
                        subtitle: Text(
                          '${preset.category.displayName} • ${preset.description}',
                          style: EatsTheme.getPrimaryFontStyle(fontSize: 10, color: EatsTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            preset.isInstrument
                                ? Icons.add_circle_outline
                                : preset.isAudioFx
                                    ? Icons.playlist_add
                                    : preset.isMidiFx
                                        ? Icons.auto_fix_high
                                        : Icons.playlist_add,
                            size: 18,
                          ),
                          tooltip: preset.isInstrument
                              ? 'Add as New Track'
                              : preset.isAudioFx
                                  ? 'Add FX to Active Track FX Chain'
                                  : preset.isMidiFx
                                      ? 'Apply MIDI FX to Active Clip'
                                      : 'Add as Clip to Active Track',
                          color: _getCategoryColor(preset.category),
                          onPressed: () {
                            if (preset.isInstrument) {
                              widget.dawState.addNewPresetTrack(preset);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added new track "${preset.name}"'),
                                  backgroundColor: EatsTheme.panelHeader,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else if (preset.isAudioFx) {
                              widget.dawState.applyPreset(preset, targetTrack: widget.dawState.activeTrack);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added FX "${preset.name}" to ${widget.dawState.activeTrack.name}'),
                                  backgroundColor: EatsTheme.panelHeader,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else if (preset.isMidiFx) {
                              widget.dawState.applyPreset(preset, targetTrack: widget.dawState.activeTrack);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added MIDI FX "${preset.name}" to ${widget.dawState.activeTrack.name}'),
                                  backgroundColor: EatsTheme.panelHeader,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else if (preset.isMidiSeq) {
                              widget.dawState.addClipWithPresetToTrack(
                                widget.dawState.activeTrack,
                                widget.dawState.currentBar,
                                preset,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added sequence "${preset.name}" as clip at Bar ${widget.dawState.currentBar + 1}'),
                                  backgroundColor: EatsTheme.panelHeader,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        onTap: () {
                          if (preset.isMidiFx) {
                            widget.dawState.applyPreset(preset, targetTrack: widget.dawState.activeTrack);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added MIDI FX "${preset.name}" to ${widget.dawState.activeTrack.name}'),
                                backgroundColor: EatsTheme.panelHeader,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else if (preset.isMidiSeq) {
                            final clip = widget.dawState.activeClip ??
                                (widget.dawState.activeTrack.clips.isNotEmpty ? widget.dawState.activeTrack.clips.first : null);
                            if (clip != null) {
                              widget.dawState.applyPresetToClip(
                                widget.dawState.activeTrack,
                                clip,
                                preset,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Applied sequence "${preset.name}" to clip "${clip.name}"'),
                                  backgroundColor: EatsTheme.panelHeader,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else {
                              widget.dawState.addClipWithPresetToTrack(
                                widget.dawState.activeTrack,
                                widget.dawState.currentBar,
                                preset,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added sequence "${preset.name}" as clip at Bar ${widget.dawState.currentBar + 1}'),
                                  backgroundColor: EatsTheme.panelHeader,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else if (preset.isAudioFx) {
                            widget.dawState.applyPreset(preset, targetTrack: widget.dawState.activeTrack);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added FX "${preset.name}" to end of ${widget.dawState.activeTrack.name} FX rack'),
                                backgroundColor: EatsTheme.panelHeader,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else {
                            widget.dawState.applyPreset(preset);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Applied instrument "${preset.name}" to ${widget.dawState.activeTrack.name}'),
                                backgroundColor: EatsTheme.panelHeader,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: DOWNLOAD & EXPANSION PACKS ---
  Widget _buildPacksTab() {
    return AnimatedBuilder(
      animation: SoundFontPackManager.instance,
      builder: (context, _) {
        final sfPacks = SoundFontPackManager.instance.packs;

        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            _buildSectionHeader('SOUNDFONT EXPANSION PACKS', Icons.library_music),
            ...sfPacks.map((pack) {
              final isInstalled = pack.isDownloaded;
              final isDownloading = pack.isDownloading;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isInstalled ? const Color(0xFF00FF66).withOpacity(0.4) : EatsTheme.panelHeader,
                    width: 1,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.all(8),
                      leading: Icon(
                        isInstalled ? Icons.check_circle_outline : (isDownloading ? Icons.sync : Icons.cloud_download_outlined),
                        color: isInstalled ? const Color(0xFF00FF66) : EatsTheme.primaryCyan,
                      ),
                      title: Text(
                        pack.title,
                        style: EatsTheme.getPrimaryFontStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EatsTheme.textLight),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.description,
                            style: EatsTheme.getPrimaryFontStyle(fontSize: 10, color: EatsTheme.textMuted),
                          ),
                          if (pack.statusMessage.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              pack.statusMessage,
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 9,
                                color: pack.statusMessage.startsWith('Error') || pack.statusMessage.startsWith('Download failed')
                                    ? Colors.redAccent
                                    : EatsTheme.primaryCyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: GestureDetector(
                        onTap: () {
                          if (!isInstalled && !isDownloading) {
                            SoundFontPackManager.instance.downloadAndInstallPack(pack);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isInstalled
                                ? Colors.green.withOpacity(0.2)
                                : (isDownloading ? Colors.orange.withOpacity(0.2) : EatsTheme.primaryCyan.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isInstalled
                                  ? const Color(0xFF00FF66)
                                  : (isDownloading ? Colors.orange : EatsTheme.primaryCyan),
                            ),
                          ),
                          child: Text(
                            isInstalled ? 'INSTALLED' : (isDownloading ? 'DOWNLOADING...' : 'DOWNLOAD (${pack.fileSizeMb}MB)'),
                            style: EatsTheme.getDisplayFontStyle(
                              fontSize: 9,
                              color: isInstalled
                                  ? const Color(0xFF00FF66)
                                  : (isDownloading ? Colors.orange : EatsTheme.primaryCyan),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isDownloading) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: LinearProgressIndicator(
                          value: pack.downloadProgress,
                          backgroundColor: Colors.black.withOpacity(0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          ],
        );
      },
    );
  }

  // --- TAB 4: VISUAL THEMES ---
  Widget _buildThemesTab() {
    final currentTheme = EatsTheme.currentPreset;

    final themes = [
      {
        'preset': EatsThemePreset.ateTrack,
        'name': 'Ate Track',
        'desc': 'Skeuomorphic analog console, metallic texture & nixie tubes',
        'color': const Color(0xFFFF8C00),
      },
      {
        'preset': EatsThemePreset.midnightBites,
        'name': 'Midnight Bites',
        'desc': 'Obsidian dark cyber theme with neon cyan & purple accents',
        'color': const Color(0xFF21F4E8),
      },
      {
        'preset': EatsThemePreset.lightSnack,
        'name': 'Light Snack',
        'desc': 'Bright studio theme optimized for daylight visibility',
        'color': const Color(0xFF0088FF),
      },
      {
        'preset': EatsThemePreset.breakfast,
        'name': 'Breakfast',
        'desc': 'Solarized light theme with creamy parchment & warm accents',
        'color': const Color(0xFFB58900),
      },
      {
        'preset': EatsThemePreset.dinner,
        'name': 'Dinner',
        'desc': 'Solarized dark theme with deep ocean teal & cyan accents',
        'color': const Color(0xFF2AA198),
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('UI THEME ENGINE', Icons.palette),
        ...themes.map((t) {
          final themePreset = t['preset'] as EatsThemePreset;
          final isSelected = themePreset == currentTheme;
          final accentColor = t['color'] as Color;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? accentColor.withOpacity(0.18) : Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? accentColor : EatsTheme.panelHeader,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: accentColor,
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
                ),
                title: Text(
                  t['name'] as String,
                  style: EatsTheme.getPrimaryFontStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : EatsTheme.textLight,
                  ),
                ),
                subtitle: Text(
                  t['desc'] as String,
                  style: EatsTheme.getPrimaryFontStyle(fontSize: 10, color: EatsTheme.textMuted),
                ),
                onTap: () {
                  widget.dawState.setThemePreset(themePreset);
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- HELPERS & UTILITIES ---
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: EatsTheme.primaryCyan),
          const SizedBox(width: 6),
          Text(
            title,
            style: EatsTheme.getDisplayFontStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: EatsTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required LuaPresetCategory? category,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _selectedCategoryFilter == category;
    final accentColor = category != null ? _getCategoryColor(category) : EatsTheme.primaryCyan;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          setState(() {
            _selectedCategoryFilter = isSelected ? null : category;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.2) : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? accentColor : EatsTheme.panelHeader.withOpacity(0.8),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? accentColor : (category != null ? accentColor.withOpacity(0.7) : EatsTheme.textMuted),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(LuaPresetCategory category) {
    switch (category) {
      case LuaPresetCategory.instrument:
        return Icons.piano;
      case LuaPresetCategory.audioFx:
        return Icons.graphic_eq;
      case LuaPresetCategory.midiFx:
        return Icons.music_note;
      case LuaPresetCategory.midiSeq:
        return Icons.view_timeline_outlined;
      case LuaPresetCategory.utility:
        return Icons.build;
    }
  }

  Color _getCategoryColor(LuaPresetCategory category) {
    switch (category) {
      case LuaPresetCategory.instrument:
        return const Color(0xFFFF8C00);
      case LuaPresetCategory.audioFx:
        return const Color(0xFF21F4E8);
      case LuaPresetCategory.midiFx:
        return const Color(0xFF00FF66);
      case LuaPresetCategory.midiSeq:
        return const Color(0xFFFFD700);
      case LuaPresetCategory.utility:
        return const Color(0xFFBD00FF);
    }
  }

  // --- TAB 5: HISTORY & TIME TRAVEL ---
  Widget _buildHistoryTab() {
    final state = widget.dawState;
    final history = state.history;

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final timeline = history.timeline;
        final currentIndex = history.currentTimelineIndex;
        final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;

        return Column(
          children: [
            // Top Controls Bar (Undo, Redo, + Checkpoint, Clear)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: EatsTheme.panelHeader,
                border: Border(
                  bottom: BorderSide(
                    color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.controlBackground,
                    width: 1.0,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Undo Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: history.canUndo ? () => history.undo(state) : null,
                          icon: const Icon(Icons.undo, size: 14),
                          label: const Text('UNDO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EatsTheme.primaryCyan.withOpacity(0.15),
                            foregroundColor: EatsTheme.primaryCyan,
                            disabledBackgroundColor: Colors.white.withOpacity(0.04),
                            disabledForegroundColor: EatsTheme.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: history.canUndo
                                    ? EatsTheme.primaryCyan.withOpacity(0.4)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Redo Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: history.canRedo ? () => history.redo(state) : null,
                          icon: const Icon(Icons.redo, size: 14),
                          label: const Text('REDO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EatsTheme.secondaryMagenta.withOpacity(0.15),
                            foregroundColor: EatsTheme.secondaryMagenta,
                            disabledBackgroundColor: Colors.white.withOpacity(0.04),
                            disabledForegroundColor: EatsTheme.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: history.canRedo
                                    ? EatsTheme.secondaryMagenta.withOpacity(0.4)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Add Checkpoint / Milestone
                      IconButton(
                        tooltip: 'Save Milestone / Checkpoint',
                        icon: const Icon(Icons.bookmark_add, size: 18),
                        color: EatsTheme.accentGold,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        style: IconButton.styleFrom(
                          backgroundColor: EatsTheme.accentGold.withOpacity(0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _showCreateCheckpointDialog(context),
                      ),
                      const SizedBox(width: 4),
                      // Clear History
                      IconButton(
                        tooltip: 'Clear History Stack',
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        color: EatsTheme.textMuted,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: timeline.length > 1
                            ? () {
                                history.clear(state);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('History stack cleared.'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Status summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STEP ${currentIndex + 1} OF ${timeline.length}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: EatsTheme.primaryCyan,
                        ),
                      ),
                      Text(
                        'DIFF SOURCE: .eats.lua',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 0.5,
                          color: EatsTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Interactive Timeline List
            Expanded(
              child: timeline.isEmpty
                  ? Center(
                      child: Text(
                        'No history entries recorded yet.',
                        style: TextStyle(color: EatsTheme.textMuted, fontSize: 11),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: timeline.length,
                      itemBuilder: (context, index) {
                        final timelineIndex = (timeline.length - 1) - index;
                        final entry = timeline[timelineIndex];
                        final isCurrent = timelineIndex == currentIndex;
                        final isPast = timelineIndex < currentIndex;
                        final isFuture = timelineIndex > currentIndex;

                        Color itemColor;
                        if (isCurrent) {
                          itemColor = EatsTheme.primaryCyan;
                        } else if (entry.isMilestone) {
                          itemColor = EatsTheme.accentGold;
                        } else if (isPast) {
                          itemColor = EatsTheme.textPrimary;
                        } else {
                          itemColor = EatsTheme.textMuted.withOpacity(0.5);
                        }

                        final timeStr = entry.timestamp.toLocal().toString().length >= 19
                            ? entry.timestamp.toLocal().toString().substring(11, 19)
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? EatsTheme.primaryCyan.withOpacity(0.12)
                                : entry.isMilestone
                                    ? EatsTheme.accentGold.withOpacity(0.08)
                                    : EatsTheme.controlBackground.withOpacity(isFuture ? 0.3 : 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? EatsTheme.primaryCyan
                                  : entry.isMilestone
                                      ? EatsTheme.accentGold.withOpacity(0.6)
                                      : Colors.white.withOpacity(isFuture ? 0.03 : 0.08),
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: isCurrent
                                ? null
                                : () {
                                    history.jumpToTimelineIndex(state, timelineIndex);
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  // Timeline Marker Icon
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? EatsTheme.primaryCyan.withOpacity(0.2)
                                          : entry.isMilestone
                                              ? EatsTheme.accentGold.withOpacity(0.2)
                                              : Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCurrent
                                          ? Icons.play_arrow
                                          : (entry.isMilestone ? Icons.bookmark : entry.icon),
                                      size: 13,
                                      color: itemColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Description & Timestamp
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                entry.description,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                  color: itemColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isCurrent)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: EatsTheme.primaryCyan,
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: const Text(
                                                  'CURRENT',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            else if (isFuture)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  'REDO',
                                                  style: TextStyle(
                                                    color: EatsTheme.textMuted,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (entry.isMilestone && entry.milestoneName != null) ...[
                                              Text(
                                                '🔖 ${entry.milestoneName!} • ',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: EatsTheme.accentGold,
                                                ),
                                              ),
                                            ],
                                            Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: EatsTheme.textMuted.withOpacity(isFuture ? 0.4 : 0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Diff Button
                                  IconButton(
                                    icon: const Icon(Icons.difference_outlined, size: 16),
                                    tooltip: 'Inspect Lua Diff',
                                    color: EatsTheme.primaryCyan.withOpacity(0.8),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () {
                                      final prevEntry = timelineIndex > 0 ? timeline[timelineIndex - 1] : null;
                                      _showDiffDialog(context, entry, prevEntry);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateCheckpointDialog(BuildContext context) {
    final controller = TextEditingController(text: 'Milestone ${DateTime.now().minute}');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: EatsTheme.panelBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.bookmark_add, color: EatsTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'SAVE CHECKPOINT',
                style: EatsTheme.getDisplayFontStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: EatsTheme.accentGold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bookmark this exact project state as a named milestone.',
                style: TextStyle(color: EatsTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: EatsTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Checkpoint Name',
                  labelStyle: TextStyle(color: EatsTheme.textMuted),
                  filled: true,
                  fillColor: EatsTheme.controlBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('CANCEL', style: TextStyle(color: EatsTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: EatsTheme.accentGold),
              onPressed: () {
                final name = controller.text.trim();
                widget.dawState.history.createMilestone(widget.dawState, name);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Checkpoint "$name" saved!'),
                    backgroundColor: EatsTheme.panelBackground,
                  ),
                );
              },
              child: const Text('SAVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDiffDialog(BuildContext context, HistoryEntry entry, HistoryEntry? prevEntry) {
    final oldText = prevEntry?.snapshotLua ?? '';
    final newText = entry.snapshotLua;
    final diff = HistoryManager.computeDiff(oldText, newText);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: EatsTheme.backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.4), width: 1.5),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.difference, color: EatsTheme.primaryCyan, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LUA STATE DIFF',
                        style: EatsTheme.getDisplayFontStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: EatsTheme.primaryCyan,
                        ),
                      ),
                      Text(
                        entry.description,
                        style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: EatsTheme.textMuted,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 450,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EatsTheme.controlBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListView.builder(
                itemCount: diff.length,
                itemBuilder: (ctx, i) {
                  final line = diff[i];
                  Color textColor;
                  Color? bgColor;
                  String prefix;

                  switch (line.type) {
                    case HistoryDiffType.added:
                      textColor = const Color(0xFF00FF66);
                      bgColor = const Color(0xFF00FF66).withOpacity(0.1);
                      prefix = '+ ';
                      break;
                    case HistoryDiffType.removed:
                      textColor = const Color(0xFFFF4040);
                      bgColor = const Color(0xFFFF4040).withOpacity(0.1);
                      prefix = '- ';
                      break;
                    case HistoryDiffType.unchanged:
                      textColor = EatsTheme.textMuted;
                      bgColor = null;
                      prefix = '  ';
                      break;
                  }

                  return Container(
                    color: bgColor,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Text(
                      '$prefix${line.text}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: textColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('CLOSE', style: TextStyle(color: EatsTheme.primaryCyan)),
            ),
          ],
        );
      },
    );
  }
}

