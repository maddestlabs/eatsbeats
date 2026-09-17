import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../eatscript/eats_preset_library.dart';
import '../../models/chord_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

typedef PresetSearchDialog = ScriptSearchDialog;

class ScriptSearchDialog extends StatefulWidget {
  final DawState dawState;
  final TrackChannel? track;
  final EatScriptCategory? initialCategory;
  final String? customTitle;
  final bool isAddTrackMode;
  final bool isChordProgressionMode;
  final int chordTargetBar;

  const ScriptSearchDialog({
    super.key,
    required this.dawState,
    this.track,
    this.initialCategory,
    this.customTitle,
    this.isAddTrackMode = false,
    this.isChordProgressionMode = false,
    this.chordTargetBar = 0,
  });

  static Future<EatScriptDef?> show(
    BuildContext context, {
    required DawState dawState,
    required TrackChannel track,
    EatScriptCategory? initialCategory,
    String? customTitle,
  }) {
    return showDialog<EatScriptDef>(
      context: context,
      builder: (context) => ScriptSearchDialog(
        dawState: dawState,
        track: track,
        initialCategory: initialCategory,
        customTitle: customTitle,
        isAddTrackMode: false,
      ),
    );
  }

  static Future<ChordProgressionPreset?> showChordProgressions(
    BuildContext context, {
    required DawState dawState,
    int startBar = 0,
  }) {
    return showDialog<ChordProgressionPreset>(
      context: context,
      builder: (context) => ScriptSearchDialog(
        dawState: dawState,
        isChordProgressionMode: true,
        chordTargetBar: startBar,
        customTitle: 'CHORD PROGRESSIONS • BAR ${startBar + 1}',
      ),
    );
  }

  static Future<Object?> showAddTrack(
    BuildContext context, {
    required DawState dawState,
  }) {
    return showDialog<Object>(
      context: context,
      builder: (context) => ScriptSearchDialog(
        dawState: dawState,
        isAddTrackMode: true,
        initialCategory: null,
        customTitle: 'ADD TRACK / FOLDER',
      ),
    );
  }

  static Future<EatScriptDef?> showAudioFx(
    BuildContext context, {
    required DawState dawState,
    required TrackChannel track,
  }) {
    return show(
      context,
      dawState: dawState,
      track: track,
      initialCategory: EatScriptCategory.audioFx,
      customTitle: 'ADD AUDIO FX • ${track.name.toUpperCase()}',
    );
  }

  static Future<EatScriptDef?> showMidiFx(
    BuildContext context, {
    required DawState dawState,
    required TrackChannel track,
  }) {
    return show(
      context,
      dawState: dawState,
      track: track,
      initialCategory: EatScriptCategory.midiFx,
      customTitle: 'ADD MIDI FX • ${track.name.toUpperCase()}',
    );
  }

  @override
  State<PresetSearchDialog> createState() => _PresetSearchDialogState();
}

class _PresetSearchDialogState extends State<PresetSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late EatScriptCategory? _selectedCategory;
  String? _selectedCustomFilter;
  String _selectedGenre = 'ALL';
  String _searchQuery = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 64.0;
    final targetOffset = index * itemHeight;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    if (targetOffset < currentOffset) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
      );
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _scrollController.animateTo(
        (targetOffset + itemHeight - viewportHeight).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isChordMode = widget.isChordProgressionMode;
    final int totalCount;
    if (isChordMode) {
      totalCount = _getFilteredChordProgressions().length;
    } else {
      final filtered = _getFilteredPresets();
      final showFolder = widget.isAddTrackMode &&
          (_selectedCustomFilter == 'FOLDERS' || (_selectedCategory == null && _selectedCustomFilter == null)) &&
          (_searchQuery.isEmpty ||
              'track folder group container'.contains(_searchQuery.toLowerCase()) ||
              'folder'.contains(_searchQuery.toLowerCase()));
      totalCount = filtered.length + (showFolder ? 1 : 0);
    }

    if (totalCount == 0) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % totalCount;
      });
      _scrollToIndex(_selectedIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + totalCount) % totalCount;
      });
      _scrollToIndex(_selectedIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _selectHighlightedItem();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _selectHighlightedItem() {
    if (!mounted) return;
    if (widget.isChordProgressionMode) {
      final chordList = _getFilteredChordProgressions();
      if (_selectedIndex >= 0 && _selectedIndex < chordList.length) {
        _applyChordProgression(chordList[_selectedIndex]);
      }
    } else {
      final showFolder = widget.isAddTrackMode &&
          (_selectedCustomFilter == 'FOLDERS' || (_selectedCategory == null && _selectedCustomFilter == null)) &&
          (_searchQuery.isEmpty ||
              'track folder group container'.contains(_searchQuery.toLowerCase()) ||
              'folder'.contains(_searchQuery.toLowerCase()));
      if (showFolder && _selectedIndex == 0) {
        _createFolder();
        return;
      }
      final filtered = _getFilteredPresets();
      final presetIndex = showFolder ? _selectedIndex - 1 : _selectedIndex;
      if (presetIndex >= 0 && presetIndex < filtered.length) {
        _applyPreset(filtered[presetIndex]);
      }
    }
  }

  Color _getCategoryColor(EatScriptCategory cat) {
    switch (cat) {
      case EatScriptCategory.instrument:
        return EatsTheme.primaryCyan;
      case EatScriptCategory.audioFx:
        return EatsTheme.secondaryMagenta;
      case EatScriptCategory.midiFx:
        return EatsTheme.accentGold;
      case EatScriptCategory.midiSeq:
        return const Color(0xFF00E676);
      case EatScriptCategory.noteSplitter:
        return const Color(0xFFFF007A);
      case EatScriptCategory.projectAction:
      case EatScriptCategory.utility:
      case EatScriptCategory.macro:
        return const Color(0xFFBD00FF);
    }
  }

  IconData _getCategoryIcon(EatScriptCategory cat) {
    switch (cat) {
      case EatScriptCategory.instrument:
        return Icons.piano;
      case EatScriptCategory.audioFx:
        return Icons.graphic_eq;
      case EatScriptCategory.midiFx:
        return Icons.bolt;
      case EatScriptCategory.midiSeq:
        return Icons.view_timeline_outlined;
      case EatScriptCategory.noteSplitter:
        return Icons.call_split;
      case EatScriptCategory.projectAction:
      case EatScriptCategory.utility:
      case EatScriptCategory.macro:
        return Icons.auto_awesome;
    }
  }

  List<ChordProgressionPreset> _getFilteredChordProgressions() {
    var list = ChordTheory.progressionPresets;
    if (_selectedGenre != 'ALL') {
      final g = _selectedGenre.toLowerCase();
      list = list.where((p) => p.genre.toLowerCase().contains(g) || p.tags.any((t) => t.toLowerCase().contains(g))).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.genre.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.romanSummary.toLowerCase().contains(q) ||
            p.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }
    return list;
  }

  void _applyChordProgression(ChordProgressionPreset preset) {
    widget.dawState.applyChordProgressionPreset(preset, startBar: widget.chordTargetBar);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${preset.name}" at Bar ${widget.chordTargetBar + 1} (Ctrl+Z to Undo)'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop(preset);
  }

  List<EatScriptDef> _getFilteredPresets() {
    if (_selectedCustomFilter == 'FOLDERS') {
      return [];
    }

    var list = EatScriptLibrary.presets;
    if (_selectedCategory != null) {
      if (_selectedCategory == EatScriptCategory.macro) {
        list = list.where((p) => p.isMacro).toList();
      } else {
        list = list.where((p) => p.category == _selectedCategory).toList();
      }
    } else if (widget.isAddTrackMode && _selectedCustomFilter == null) {
      // In add track mode with ALL selected, show instruments first, then others
      list = [
        ...list.where((p) => p.isInstrument),
        ...list.where((p) => !p.isInstrument),
      ];
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.category.displayName.toLowerCase().contains(q) ||
            p.id.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _createFolder() {
    final folder = widget.dawState.createTrackFolder();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created new Track Folder "${folder.name}"'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop(folder);
  }

  void _applyPreset(EatScriptDef preset) {
    if (widget.isAddTrackMode) {
      if (preset.isInstrument) {
        widget.dawState.addNewPresetTrack(preset);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added new track "${preset.name}"'),
            backgroundColor: EatsTheme.panelHeader,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (preset.isMidiSeq) {
        final kickPreset = EatScriptLibrary.presets.firstWhere(
          (p) => p.id == 'procedural_kick',
          orElse: () => EatScriptLibrary.presets.first,
        );
        widget.dawState.addNewPresetTrack(kickPreset);
        final newTrack = widget.dawState.activeTrack;
        if (newTrack.clips.isNotEmpty) {
          widget.dawState.applyPresetToClip(newTrack, newTrack.clips.first, preset);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added track with sequence "${preset.name}"'),
            backgroundColor: EatsTheme.panelHeader,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        final targetTrack = widget.track ?? widget.dawState.activeTrack;
        if (preset.isAudioFx) {
          widget.dawState.addAudioFXFromPreset(targetTrack, preset);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added FX "${preset.name}" to ${targetTrack.name}'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (preset.isMidiFx) {
          widget.dawState.addMidiFXFromPreset(targetTrack, preset);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added MIDI FX "${preset.name}" to ${targetTrack.name}'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      Navigator.of(context).pop(preset);
      return;
    }

    final currentTrack = widget.track ?? widget.dawState.activeTrack;
    if (preset.isAudioFx) {
      widget.dawState.addAudioFXFromPreset(currentTrack, preset);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added FX "${preset.name}" to ${currentTrack.name}'),
          backgroundColor: EatsTheme.panelHeader,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (preset.isMidiFx) {
      widget.dawState.addMidiFXFromPreset(currentTrack, preset);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added MIDI FX "${preset.name}" to ${currentTrack.name}'),
          backgroundColor: EatsTheme.panelHeader,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      widget.dawState.applyPreset(preset, targetTrack: currentTrack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied "${preset.name}" to ${currentTrack.name}'),
          backgroundColor: EatsTheme.panelHeader,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    Navigator.of(context).pop(preset);
  }

  Widget _buildFolderCard({bool isSelected = false}) {
    final folderColor = EatsTheme.primaryCyan;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? folderColor.withOpacity(0.20) : folderColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: folderColor.withOpacity(isSelected ? 1.0 : 0.6),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: folderColor.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                )
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onHover: (hovering) {
            if (hovering) setState(() => _selectedIndex = 0);
          },
          onTap: _createFolder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: folderColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.create_new_folder_outlined, size: 20, color: folderColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Track Folder',
                            style: EatsTheme.getPrimaryFontStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: folderColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: folderColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: folderColor.withOpacity(0.5), width: 0.8),
                            ),
                            child: Text(
                              'FOLDER',
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: folderColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Group & organize multiple tracks into a collapsible folder',
                        style: EatsTheme.getPrimaryFontStyle(
                          fontSize: 10,
                          color: EatsTheme.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: folderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.keyboard_return, size: 12, color: Colors.black),
                        const SizedBox(width: 2),
                        Text(
                          'CREATE',
                          style: EatsTheme.getPrimaryFontStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChordProgressionCard(ChordProgressionPreset preset, int index, {bool isSelected = false}) {
    const accentColor = EatsTheme.accentGold;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withOpacity(0.18) : Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? accentColor : accentColor.withOpacity(0.35),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.25),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                )
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onHover: (hovering) {
            if (hovering) setState(() => _selectedIndex = index);
          },
          onTap: () => _applyChordProgression(preset),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Gold Icon Badge
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(isSelected ? 0.3 : 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.queue_music, size: 18, color: accentColor),
                ),
                const SizedBox(width: 10),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preset.name,
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: EatsTheme.textLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: accentColor.withOpacity(0.4), width: 0.8),
                            ),
                            child: Text(
                              preset.genre.toUpperCase(),
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preset.description,
                        style: EatsTheme.getPrimaryFontStyle(
                          fontSize: 10,
                          color: EatsTheme.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Roman Numeral Preview Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          preset.romanSummary,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: EatsTheme.accentGold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Apply Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : accentColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: accentColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.keyboard_return : Icons.add,
                        size: 14,
                        color: isSelected ? Colors.black : accentColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'APPLY',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : accentColor,
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

  Widget _buildCategoryFilterChip(EatScriptCategory? cat, String label, IconData icon) {
    final isSelected = _selectedCategory == cat;
    final color = cat != null ? _getCategoryColor(cat) : EatsTheme.primaryCyan;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selectedCategory = cat;
          _selectedCustomFilter = null;
          _selectedIndex = 0;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.25) : EatsTheme.panelHeader,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : EatsTheme.panelHeader, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 12, color: isSelected ? color : EatsTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: EatsTheme.getPrimaryFontStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : EatsTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFilterChip(String filter, IconData icon, Color color) {
    final isSelected = _selectedCustomFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selectedCustomFilter = filter;
          _selectedCategory = null;
          _selectedIndex = 0;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.25) : EatsTheme.panelHeader,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : EatsTheme.panelHeader, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 12, color: isSelected ? color : EatsTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                filter,
                style: EatsTheme.getPrimaryFontStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : EatsTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard(EatScriptDef preset, int index, {bool isSelected = false}) {
    final catColor = _getCategoryColor(preset.category);
    final catIcon = _getCategoryIcon(preset.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? catColor.withOpacity(0.18) : Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? catColor : EatsTheme.panelHeader.withOpacity(0.8),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: catColor.withOpacity(0.25),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                )
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onHover: (hovering) {
            if (hovering) setState(() => _selectedIndex = index);
          },
          onTap: () => _applyPreset(preset),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Draggable Category Badge
                Draggable<EatScriptDef>(
                  data: preset,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(catIcon, size: 16, color: Colors.black),
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
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(isSelected ? 0.3 : 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(catIcon, size: 18, color: catColor),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preset.name,
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: EatsTheme.textLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: catColor.withOpacity(0.4), width: 0.8),
                            ),
                            child: Text(
                              preset.category.displayName,
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preset.description,
                        style: EatsTheme.getPrimaryFontStyle(
                          fontSize: 10,
                          color: EatsTheme.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Add Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? catColor : catColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: catColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.keyboard_return : Icons.add,
                        size: 14,
                        color: isSelected ? Colors.black : catColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isSelected ? 'SELECT' : 'ADD',
                        style: EatsTheme.getPrimaryFontStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : catColor,
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

  Widget _buildChordDialog(BuildContext context) {
    final chordList = _getFilteredChordProgressions();
    const accentColor = EatsTheme.accentGold;
    final title = widget.customTitle ?? 'CHORD PROGRESSION PRESETS • BAR ${widget.chordTargetBar + 1}';

    final genres = [
      'ALL',
      'Pop',
      'Synthwave',
      'EDM',
      'Jazz',
      'Lo-Fi',
      'Cinematic',
      'Rock',
      'Latin',
      'Anime',
    ];

    return Dialog(
      backgroundColor: EatsTheme.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: accentColor, width: 2),
      ),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.queue_music, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: EatsTheme.getPrimaryFontStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: EatsTheme.textMuted, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar Input
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: EatsTheme.panelHeader),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.search, size: 18, color: EatsTheme.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      style: EatsTheme.getPrimaryFontStyle(fontSize: 12, color: EatsTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search progressions by name, genre, Roman numerals (I-V-vi-IV)...',
                        hintStyle: EatsTheme.getPrimaryFontStyle(fontSize: 12, color: EatsTheme.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _selectHighlightedItem(),
                      onChanged: (val) => setState(() {
                        _searchQuery = val.trim();
                        _selectedIndex = 0;
                      }),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, size: 16, color: EatsTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedIndex = 0;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Genre Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: genres.map((g) {
                  final isSelected = _selectedGenre == g;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() {
                        _selectedGenre = g;
                        _selectedIndex = 0;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor.withOpacity(0.25) : EatsTheme.panelHeader,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? accentColor : EatsTheme.panelHeader, width: 1),
                        ),
                        child: Text(
                          g.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? accentColor : EatsTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 4),

            // Count Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${chordList.length} PROGRESSIONS FOUND',
                  style: EatsTheme.getPrimaryFontStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: EatsTheme.textMuted,
                  ),
                ),
                Text(
                  '↑↓ NAVIGATE • ↵ SELECT',
                  style: EatsTheme.getPrimaryFontStyle(
                    fontSize: 9,
                    color: EatsTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Items List
            Flexible(
              child: chordList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 36, color: EatsTheme.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              'No matching chord progressions found',
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 12,
                                color: EatsTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      itemCount: chordList.length,
                      itemBuilder: (context, index) {
                        return _buildChordProgressionCard(
                          chordList[index],
                          index,
                          isSelected: index == _selectedIndex,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetDialog(BuildContext context) {
    final filtered = _getFilteredPresets();
    final isAudioFxMode = _selectedCategory == EatScriptCategory.audioFx && !widget.isAddTrackMode;
    final isMidiFxMode = _selectedCategory == EatScriptCategory.midiFx && !widget.isAddTrackMode;
    final accentColor = widget.isAddTrackMode
        ? EatsTheme.primaryCyan
        : (isAudioFxMode
            ? EatsTheme.secondaryMagenta
            : (isMidiFxMode ? EatsTheme.accentGold : EatsTheme.primaryCyan));

    final trackName = widget.track?.name.toUpperCase() ?? '';
    final title = widget.customTitle ??
        (widget.isAddTrackMode
            ? 'ADD TRACK / FOLDER'
            : (isAudioFxMode
                ? 'ADD AUDIO FX • $trackName'
                : (isMidiFxMode
                    ? 'ADD MIDI FX • $trackName'
                    : 'PRESET LIBRARY • $trackName')));

    final bool showFolder = widget.isAddTrackMode &&
        (_selectedCustomFilter == 'FOLDERS' || (_selectedCategory == null && _selectedCustomFilter == null)) &&
        (_searchQuery.isEmpty ||
            'track folder group container'.contains(_searchQuery.toLowerCase()) ||
            'folder'.contains(_searchQuery.toLowerCase()));

    final int totalCount = filtered.length + (showFolder ? 1 : 0);

    return Dialog(
      backgroundColor: EatsTheme.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor, width: 2),
      ),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 580),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  widget.isAddTrackMode
                      ? Icons.add_circle_outline
                      : (isAudioFxMode
                          ? Icons.graphic_eq
                          : (isMidiFxMode ? Icons.bolt : Icons.library_music)),
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: EatsTheme.getPrimaryFontStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: EatsTheme.textMuted, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar Input
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: EatsTheme.panelHeader),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.search, size: 18, color: EatsTheme.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      style: EatsTheme.getPrimaryFontStyle(fontSize: 12, color: EatsTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: widget.isAddTrackMode
                            ? 'Search instruments, synths, drums, folders...'
                            : (isAudioFxMode
                                ? 'Search Audio FX by name, type, algorithm...'
                                : (isMidiFxMode
                                    ? 'Search MIDI FX by name, chords, arp...'
                                    : 'Search presets by keyword...')),
                        hintStyle: EatsTheme.getPrimaryFontStyle(fontSize: 12, color: EatsTheme.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _selectHighlightedItem(),
                      onChanged: (val) => setState(() {
                        _searchQuery = val.trim();
                        _selectedIndex = 0;
                      }),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, size: 16, color: EatsTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedIndex = 0;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Category Chips
            if (widget.initialCategory == null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _buildCategoryFilterChip(null, 'ALL', Icons.apps),
                    if (widget.isAddTrackMode)
                      _buildCustomFilterChip('FOLDERS', Icons.folder, EatsTheme.primaryCyan),
                    _buildCategoryFilterChip(
                      EatScriptCategory.instrument,
                      widget.isAddTrackMode ? 'SYNTHS & INSTRUMENTS' : 'SYNTHS',
                      Icons.piano,
                    ),
                    _buildCategoryFilterChip(EatScriptCategory.midiSeq, 'SEQUENCES', Icons.view_timeline_outlined),
                    _buildCategoryFilterChip(EatScriptCategory.audioFx, 'AUDIO FX', Icons.graphic_eq),
                    _buildCategoryFilterChip(EatScriptCategory.midiFx, 'MIDI FX', Icons.bolt),
                    _buildCategoryFilterChip(EatScriptCategory.macro, 'MACROS', Icons.auto_awesome),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            // Count Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalCount ${totalCount == 1 ? 'ITEM' : 'ITEMS'} FOUND',
                  style: EatsTheme.getPrimaryFontStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: EatsTheme.textMuted,
                  ),
                ),
                Text(
                  '↑↓ NAVIGATE • ↵ SELECT',
                  style: EatsTheme.getPrimaryFontStyle(
                    fontSize: 9,
                    color: EatsTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Items List
            Flexible(
              child: totalCount == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 36, color: EatsTheme.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              'No matching items found',
                              style: EatsTheme.getPrimaryFontStyle(
                                fontSize: 12,
                                color: EatsTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      itemCount: totalCount,
                      itemBuilder: (context, index) {
                        if (showFolder && index == 0) {
                          return _buildFolderCard(isSelected: _selectedIndex == 0);
                        }

                        final presetIndex = showFolder ? index - 1 : index;
                        final preset = filtered[presetIndex];
                        return _buildPresetCard(
                          preset,
                          index,
                          isSelected: index == _selectedIndex,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialog = widget.isChordProgressionMode
        ? _buildChordDialog(context)
        : _buildPresetDialog(context);

    return Focus(
      autofocus: false,
      onKeyEvent: _handleKeyEvent,
      child: dialog,
    );
  }
}
