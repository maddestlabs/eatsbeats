import 'package:flutter/material.dart';
import '../../lua/lua_preset_library.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';
import '../../audio/soundfont_engine.dart';
import '../../utils/soundfont_pack_manager.dart';
import '../../utils/ir_pack_manager.dart';
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
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.dawState.browserTabIndex);
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
                Row(
                  children: [
                    Icon(Icons.folder_copy, color: EatsTheme.primaryCyan, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'PROJECT BROWSER',
                      style: EatsTheme.getDisplayFontStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: EatsTheme.textLight,
                      ),
                    ),
                  ],
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
              labelStyle: EatsTheme.getDisplayFontStyle(fontSize: 10, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'ASSETS'),
                Tab(text: 'PRESETS'),
                Tab(text: 'PACKS'),
                Tab(text: 'THEMES'),
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
          );
        }),

        const SizedBox(height: 12),
        _buildSectionHeader('ACTIVE LUA SCRIPTS', Icons.code),
        ...activePattern.tracks.where((t) => t.luaScriptCode.isNotEmpty).map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              leading: const Icon(Icons.integration_instructions, size: 16, color: Color(0xFFFF8C00)),
              title: Text(
                t.name,
                style: EatsTheme.getPrimaryFontStyle(fontSize: 11, color: EatsTheme.textLight),
              ),
              subtitle: Text(
                'Bound to Channel ${t.name}',
                style: EatsTheme.getPrimaryFontStyle(fontSize: 9, color: EatsTheme.textMuted),
              ),
              onTap: () {
                final idx = activePattern.tracks.indexOf(t);
                if (idx != -1) state.activeTrackIndex = idx;
                state.activeTabIndex = 4; // Jump to Lua Workbench
              },
            ),
          );
        }),

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

                return Draggable<SoundFontDragItem>(
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
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        leading: const Icon(Icons.piano, size: 16, color: Color(0xFF00FF66)),
                        title: Text(displayName, style: EatsTheme.getPrimaryFontStyle(fontSize: 11, color: EatsTheme.textLight)),
                        subtitle: Text('SoundFont Instrument Bank (Drag to Track)', style: EatsTheme.getPrimaryFontStyle(fontSize: 9, color: EatsTheme.textMuted)),
                      ),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      leading: const Icon(Icons.piano, size: 16, color: Color(0xFF00FF66)),
                      title: Text(displayName, style: EatsTheme.getPrimaryFontStyle(fontSize: 11, color: EatsTheme.textLight)),
                      subtitle: Text('SoundFont Instrument Bank (Drag or Tap to select)', style: EatsTheme.getPrimaryFontStyle(fontSize: 9, color: EatsTheme.textMuted)),
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

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              _buildCategoryChip(null, 'ALL'),
              _buildCategoryChip(LuaPresetCategory.instrument, 'SYNTH'),
              _buildCategoryChip(LuaPresetCategory.audioFx, 'AUDIO FX'),
              _buildCategoryChip(LuaPresetCategory.midiFx, 'MIDI FX'),
              _buildCategoryChip(LuaPresetCategory.utility, 'UTIL'),
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

                    return Draggable<LuaPreset>(
                      data: preset,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: EatsTheme.primaryCyan,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                          ),
                          child: Text(
                            '📄 ${preset.name}',
                            style: EatsTheme.getPrimaryFontStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: EatsTheme.panelHeader.withOpacity(0.6), width: 1),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Icon(
                            _getCategoryIcon(preset.category),
                            size: 18,
                            color: _getCategoryColor(preset.category),
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
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            tooltip: 'Apply to Active Track',
                            color: EatsTheme.primaryCyan,
                            onPressed: () {
                              widget.dawState.applyPreset(preset);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Applied preset "${preset.name}" to channel'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
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
        'name': '8-Track Vintage (Ate Track)',
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

  Widget _buildCategoryChip(LuaPresetCategory? category, String label) {
    final isSelected = _selectedCategoryFilter == category;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: EatsTheme.getDisplayFontStyle(
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : EatsTheme.textLight,
          ),
        ),
        selected: isSelected,
        selectedColor: EatsTheme.primaryCyan,
        backgroundColor: Colors.black.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (selected) {
          setState(() {
            _selectedCategoryFilter = selected ? category : null;
          });
        },
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
      case LuaPresetCategory.utility:
        return const Color(0xFFBD00FF);
    }
  }
}
