import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/script_preset_model.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

/// Modal dialog for browsing, filtering, searching, and managing instrument/FX presets.
class PresetBrowserDialog extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;

  const PresetBrowserDialog({
    super.key,
    required this.dawState,
    required this.track,
  });

  static Future<ScriptPreset?> show(BuildContext context, DawState dawState, TrackChannel track) {
    return showDialog<ScriptPreset>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => PresetBrowserDialog(dawState: dawState, track: track),
    );
  }

  @override
  State<PresetBrowserDialog> createState() => _PresetBrowserDialogState();
}

class _PresetBrowserDialogState extends State<PresetBrowserDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  bool _filterUserOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSaveDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: '${widget.track.name} Custom');
    String category = 'Lead';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: EatsTheme.panelHeader,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: widget.track.color, width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.save, color: widget.track.color, size: 20),
                  const SizedBox(width: 8),
                  Text('Save Preset', style: EatsTheme.getDisplayFontStyle(color: EatsTheme.textPrimary, fontSize: 14)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save current parameters for "${widget.track.name}" as a reusable sound patch.',
                    style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: EatsTheme.getPrimaryFontStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'PRESET NAME',
                      labelStyle: EatsTheme.getDisplayFontStyle(color: EatsTheme.primaryCyan, fontSize: 10),
                      filled: true,
                      fillColor: const Color(0xFF0F121C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.track.color)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('CATEGORY / TAG:', style: EatsTheme.getDisplayFontStyle(color: EatsTheme.textMuted, fontSize: 9.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['Bass', 'Lead', 'Pad', 'Pluck', 'FX', 'Keys', 'Drums'].map((cat) {
                      final isSel = category == cat;
                      return ChoiceChip(
                        label: Text(cat, style: EatsTheme.getPrimaryFontStyle(color: isSel ? Colors.black : EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                        selected: isSel,
                        selectedColor: widget.track.color,
                        backgroundColor: const Color(0xFF1B2030),
                        onSelected: (sel) {
                          if (sel) setDialogState(() => category = cat);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('CANCEL', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: widget.track.color, foregroundColor: Colors.black),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('SAVE PRESET'),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      widget.dawState.saveTrackScriptPreset(widget.track, name, category);
                      Navigator.of(ctx).pop();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved preset "$name" to your library!'),
                          backgroundColor: EatsTheme.panelHeader,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackPresets = widget.dawState.getPresetsForTrack(widget.track);
    final allPresets = ScriptPresetLibrary.instance.allPresets;
    final baseList = trackPresets.isNotEmpty ? trackPresets : allPresets;

    final query = _searchController.text.trim().toLowerCase();
    final filtered = baseList.where((p) {
      if (_filterUserOnly && p.isStock) return false;
      if (_selectedCategory != 'ALL' && p.category.toUpperCase() != _selectedCategory) return false;
      if (query.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesDesc = (p.description ?? '').toLowerCase().contains(query);
        final matchesCat = p.category.toLowerCase().contains(query);
        if (!matchesName && !matchesDesc && !matchesCat) return false;
      }
      return true;
    }).toList();

    final categories = ['ALL', 'BASS', 'LEAD', 'PAD', 'PLUCK', 'FX', 'KEYS', 'DRUMS'];

    return Dialog(
      backgroundColor: EatsTheme.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: widget.track.color.withOpacity(0.6), width: 1.5),
      ),
      child: Container(
        width: 620,
        height: 520,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: widget.track.color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.piano, color: widget.track.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRESET LIBRARY • ${widget.track.name.toUpperCase()}',
                        style: EatsTheme.getDisplayFontStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Select a sound patch or save your current hardware configuration',
                        style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.track.color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.save, size: 14),
                  label: const Text('SAVE AS PRESET'),
                  onPressed: () => _openSaveDialog(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: EatsTheme.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Search Bar & Filter Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: EatsTheme.getPrimaryFontStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search presets by sound, mood, or tag...',
                      hintStyle: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 11),
                      prefixIcon: Icon(Icons.search, size: 16, color: EatsTheme.textMuted),
                      filled: true,
                      fillColor: const Color(0xFF0F121C),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2B3245))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.track.color)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('User Only', style: EatsTheme.getPrimaryFontStyle(fontSize: 10.5, color: _filterUserOnly ? Colors.black : EatsTheme.textMuted, fontWeight: FontWeight.bold)),
                  selected: _filterUserOnly,
                  selectedColor: EatsTheme.accentGold,
                  backgroundColor: const Color(0xFF1B2030),
                  onSelected: (val) => setState(() => _filterUserOnly = val),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Category Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(cat, style: EatsTheme.getPrimaryFontStyle(color: isSel ? Colors.black : EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: widget.track.color,
                      backgroundColor: const Color(0xFF141724),
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: Color(0xFF252B3B), height: 1),
            const SizedBox(height: 8),

            // Preset List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.library_music_outlined, size: 36, color: EatsTheme.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text('No presets found matching criteria', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Tweak your parameters and save a custom preset above!', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted.withOpacity(0.6), fontSize: 10)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final p = filtered[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121522),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF23283B)),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.track.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: widget.track.color.withOpacity(0.4)),
                              ),
                              child: Text(
                                p.category.toUpperCase(),
                                style: EatsTheme.getDisplayFontStyle(color: widget.track.color, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  p.name,
                                  style: EatsTheme.getPrimaryFontStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                if (!p.isStock)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: EatsTheme.accentGold.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                                    child: Text('USER', style: EatsTheme.getDisplayFontStyle(color: EatsTheme.accentGold, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: p.description != null
                                ? Text(p.description!, style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10))
                                : Text('${p.params.length} parameters (${p.author})', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.track.color.withOpacity(0.2),
                                    foregroundColor: widget.track.color,
                                    side: BorderSide(color: widget.track.color),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () {
                                    widget.dawState.applyScriptPreset(widget.track, p);
                                    Navigator.of(context).pop(p);
                                  },
                                  child: const Text('LOAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                if (!p.isStock) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    tooltip: 'Delete Preset',
                                    onPressed: () {
                                      ScriptPresetLibrary.instance.deleteUserPreset(p.id);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
