import 'package:flutter/material.dart';
import '../../lua/lua_engine.dart';
import '../../lua/lua_gui_parser.dart';
import '../../lua/lua_script_library.dart';
import '../../lua/note_splitter_engine.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

class NoteSplitterDialog extends StatefulWidget {
  final DawState dawState;
  final TrackClip clip;

  const NoteSplitterDialog({
    super.key,
    required this.dawState,
    required this.clip,
  });

  static Future<void> show(BuildContext context, DawState dawState, TrackClip clip) {
    return showDialog(
      context: context,
      builder: (context) => NoteSplitterDialog(
        dawState: dawState,
        clip: clip,
      ),
    );
  }

  @override
  State<NoteSplitterDialog> createState() => _NoteSplitterDialogState();
}

class _NoteSplitterDialogState extends State<NoteSplitterDialog> {
  late List<LuaScriptDef> _presets;
  late LuaScriptDef _selectedPreset;
  final Map<String, double> _paramValues = {};
  List<LuaParamDef> _paramDefs = [];
  bool _removeOriginalClip = false;

  @override
  void initState() {
    super.initState();
    _presets = LuaScriptLibrary.getPresetsByCategory(LuaScriptCategory.noteSplitter);
    if (_presets.isEmpty) {
      _presets = LuaScriptLibrary.presets.where((p) => p.isNoteSplitter).toList();
    }
    _selectedPreset = _presets.isNotEmpty ? _presets.first : LuaScriptLibrary.scripts.first;
    _loadPresetParams(_selectedPreset);
  }

  void _loadPresetParams(LuaScriptDef preset) {
    _paramValues.clear();
    _paramDefs = LuaEngine.compile(preset.code).params;
    for (final def in _paramDefs) {
      _paramValues[def.name] = def.defaultValue;
    }
  }

  List<NoteSplitterTrackResult> _calculatePreview() {
    final notes = widget.clip.embeddedTranscribedNotes.isNotEmpty
        ? widget.clip.embeddedTranscribedNotes
        : widget.clip.notes;

    return NoteSplitterEngine.splitWithPreset(
      notes,
      _selectedPreset,
      params: _paramValues,
    );
  }

  void _performSplit() {
    final created = widget.dawState.splitClipNotesWithPreset(
      widget.clip,
      _selectedPreset,
      params: _paramValues,
      removeOriginalClip: _removeOriginalClip,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EatsTheme.primaryCyan,
        content: Text(
          'Split "${widget.clip.name}" into ${created.length} tracks using ${_selectedPreset.name}!',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceNotes = widget.clip.embeddedTranscribedNotes.isNotEmpty
        ? widget.clip.embeddedTranscribedNotes
        : widget.clip.notes;

    final previewTracks = _calculatePreview();

    return Dialog(
      backgroundColor: const Color(0xFF16181E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.4), width: 1.5),
      ),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EatsTheme.primaryCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.call_split, color: EatsTheme.primaryCyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Split Notes into Tracks',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Source Clip: "${widget.clip.name}" (${sourceNotes.length} notes)',
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Preset Selector
              Text(
                'SEPARATION ALGORITHM / PRESET',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.primaryCyan, letterSpacing: 1.1),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LuaScriptDef>(
                    value: _selectedPreset,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1F222B),
                    icon: Icon(Icons.arrow_drop_down, color: EatsTheme.primaryCyan),
                    items: _presets.map((preset) {
                      return DropdownMenuItem<LuaScriptDef>(
                        value: preset,
                        child: Row(
                          children: [
                            Icon(Icons.auto_fix_high, size: 16, color: EatsTheme.primaryCyan),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                preset.name,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newPreset) {
                      if (newPreset != null) {
                        setState(() {
                          _selectedPreset = newPreset;
                          _loadPresetParams(newPreset);
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedPreset.description,
                style: const TextStyle(fontSize: 11.5, color: Colors.white60, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),

              // Parameter Sliders (if any)
              if (_paramDefs.isNotEmpty) ...[
                Text(
                  'ALGORITHM TUNING',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.primaryCyan, letterSpacing: 1.1),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: _paramDefs.map((def) {
                      final val = _paramValues[def.name] ?? def.defaultValue;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: Text(def.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: EatsTheme.primaryCyan,
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: EatsTheme.primaryCyan,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                ),
                                child: Slider(
                                  value: val.clamp(def.min, def.max),
                                  min: def.min,
                                  max: def.max,
                                  divisions: def.isInteger ? (def.max - def.min).toInt() : 50,
                                  onChanged: (newVal) {
                                    setState(() {
                                      _paramValues[def.name] = newVal;
                                    });
                                  },
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 45,
                              child: Text(
                                def.getFormattedValue(val),
                                style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Output Destination Tracks Live Preview
              Text(
                'DESTINATION TRACKS PREVIEW (${previewTracks.length} TRACKS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.primaryCyan, letterSpacing: 1.1),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: previewTracks.map((track) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: track.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: track.color.withOpacity(0.4), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: track.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              track.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${track.notes.length} notes',
                              style: TextStyle(color: track.color, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Options
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Mute or Remove original source clip after split', style: TextStyle(color: Colors.white70, fontSize: 12)),
                value: _removeOriginalClip,
                activeColor: EatsTheme.primaryCyan,
                checkColor: Colors.black,
                onChanged: (val) => setState(() => _removeOriginalClip = val ?? false),
              ),

              const SizedBox(height: 18),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EatsTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: previewTracks.isEmpty ? null : _performSplit,
                    icon: const Icon(Icons.call_split, size: 18),
                    label: Text(
                      'Split into ${previewTracks.length} Tracks',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
