import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import '../lua/midi_pipeline_engine.dart';
import '../lua/lua_script_library.dart';
import '../eatscript/eat_script_engine.dart';
import '../eatscript/eat_param_model.dart';

class ScriptView extends StatefulWidget {
  final DawState dawState;

  const ScriptView({super.key, required this.dawState});

  @override
  State<ScriptView> createState() => _ScriptViewState();
}

class _ScriptViewState extends State<ScriptView> {
  static const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  static String _getNoteName(int pitch) {
    if (pitch < 0 || pitch > 127) return 'P$pitch';
    final octave = (pitch ~/ 12) - 1;
    return '${_noteNames[pitch % 12]}$octave';
  }

  late TextEditingController _codeController;
  late FocusNode _focusNode;
  String _currentClipId = '';
  String _lastSyncedCode = '';
  LuaCompilationResult _compilationResult = LuaCompilationResult(
    isSuccess: true,
    errorMessage: 'Ready',
    params: [],
    scriptType: 'generator',
  );

  /// Resolves the actual script code for [clip].
  /// If the clip already has custom script (not the stale Euclidean fallback), uses it.
  /// If clip has notes, serializes them to clean sequence Lua table format.
  /// Otherwise provides a clean MIDI sequence template.
  String _resolveClipScript(TrackClip clip) {
    if (clip.luaScriptCode.trim().isNotEmpty &&
        !clip.luaScriptCode.startsWith('# Generative Euclidean Rhythm (Eatscript)')) {
      if (clip.notes.isNotEmpty && clip.luaScriptCode.contains('notes = {')) {
        return MidiPipelineEngine.serializeNotesToLua(clip.notes, existingCode: clip.luaScriptCode);
      }
      return clip.luaScriptCode;
    }

    if (clip.notes.isNotEmpty) {
      return MidiPipelineEngine.serializeNotesToLua(clip.notes);
    }

    return '''-- @name: ${clip.name}
-- @category: midiSeq

notes = {
}

function process(notes, time_ctx)
  return notes
end
''';
  }

  @override
  void initState() {
    super.initState();
    final clip = widget.dawState.activeTrackClip;
    _currentClipId = clip.id;

    final initialCode = _resolveClipScript(clip);
    clip.luaScriptCode = initialCode;
    _lastSyncedCode = initialCode;

    _codeController = TextEditingController(text: initialCode);
    _focusNode = FocusNode(debugLabel: 'ScriptViewCodeEditor');
    _recompile(initialCode);

    widget.dawState.addListener(_onDawStateChanged);
  }

  @override
  void dispose() {
    widget.dawState.removeListener(_onDawStateChanged);
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDawStateChanged() {
    if (!mounted) return;
    final clip = widget.dawState.activeTrackClip;
    if (clip.id != _currentClipId) {
      _currentClipId = clip.id;
      final newCode = _resolveClipScript(clip);
      clip.luaScriptCode = newCode;
      _lastSyncedCode = newCode;
      _codeController.text = newCode;
      _recompile(newCode);
      if (mounted) setState(() {});
      return;
    }

    // Check if external change (e.g. Undo/Redo or dropped sequence) updated clip
    if (!_focusNode.hasFocus) {
      final currentClipCode = _resolveClipScript(clip);
      if (currentClipCode != _lastSyncedCode && currentClipCode != _codeController.text) {
        _lastSyncedCode = currentClipCode;
        _codeController.text = currentClipCode;
        _recompile(currentClipCode);
        if (mounted) setState(() {});
      }
    }
  }

  void _recompile(String code) {
    setState(() {
      _compilationResult = DawState.compileScript(code);
    });
  }

  void _executeScript() {
    final clip = widget.dawState.activeTrackClip;
    final track = widget.dawState.activeTrack;
    final code = _codeController.text;

    // Update clip code and parameter values
    clip.luaScriptCode = code;
    _lastSyncedCode = code;

    for (final p in _compilationResult.params) {
      if (!clip.luaParams.containsKey(p.name)) {
        clip.luaParams[p.name] = p.defaultValue;
      }
    }

    List<Note> newNotes = [];
    if (EatScriptEngine.isEatScript(code)) {
      // Execute Eatscript clip transformation
      final generatedNotes = EatScriptEngine.executeClipScript(
        code,
        clip.notes,
        paramValues: clip.luaParams,
        tempo: widget.dawState.bpm,
        keyRoot: widget.dawState.songKeyRoot,
        isMinor: widget.dawState.isSongKeyMinor,
        timeContext: widget.dawState.timeContext,
      );
      newNotes = generatedNotes;
    } else {
      // Parse notes from legacy Lua table if present and sync back to clip notes
      final parsedNotes = MidiPipelineEngine.parseNotesFromLuaTable(code);
      if (parsedNotes.isNotEmpty) {
        if (clip.barLength > 1 && parsedNotes.every((n) => n.startStep < 16.0)) {
          final List<Note> tiled = [];
          for (int bar = 0; bar < clip.barLength; bar++) {
            final barOffset = bar * 16.0;
            for (final n in parsedNotes) {
              tiled.add(n.copyWith(
                id: 'n_clip_${clip.id}_b${bar}_${n.startStep}',
                startStep: n.startStep + barOffset,
              ));
            }
          }
          newNotes = tiled;
        } else {
          newNotes = parsedNotes.map((n) => n.copyWith(id: 'n_clip_${clip.id}_${n.startStep}')).toList();
        }
      }
    }

    clip.notes = newNotes;
    if (widget.dawState.activeClip?.id == clip.id || widget.dawState.activeTrackClip.id == clip.id) {
      track.notes = clip.notes.map((n) => n.copyWith()).toList();
    }

    // Re-evaluate clip notes through MidiPipelineEngine
    final pipeline = MidiPipelineEngine();
    pipeline.processClip(
      clip: clip,
      track: track,
      timeContext: widget.dawState.timeContext,
    );

    widget.dawState.recordHistory('Replace Clip Notes (${clip.name})', icon: Icons.sync_alt);
    widget.dawState.notifyState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replaced clip "${clip.name}" notes (${newNotes.length} notes) - Undoable with Ctrl+Z'),
          backgroundColor: EatsTheme.panelHeader,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onSelectMidiSequence(LuaScriptDef sequence) async {
    final clip = widget.dawState.activeTrackClip;
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isGrungy ? const Color(0xFF1E1B18) : EatsTheme.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: EatsTheme.accentGold.withOpacity(0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.view_timeline_outlined, color: EatsTheme.accentGold, size: 20),
            const SizedBox(width: 8),
            Text(
              'Apply MIDI Sequence',
              style: EatsTheme.getDisplayFontStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EatsTheme.textLight),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sequence.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (sequence.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sequence.description,
                style: TextStyle(fontSize: 11, color: EatsTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'Target Clip: "${clip.name}" (${clip.barLength} bars, ${clip.notes.length} notes)\n'
                'Replacing will overwrite the clip\'s notes with this sequence. Full undo is supported (Ctrl+Z).',
                style: TextStyle(fontSize: 11, color: EatsTheme.textMuted, height: 1.35),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: Text('CANCEL', style: TextStyle(color: EatsTheme.textMuted, fontSize: 11)),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(ctx).pop('load'),
            icon: const Icon(Icons.code, size: 14),
            label: const Text('LOAD SCRIPT ONLY', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: EatsTheme.textSecondary,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop('replace'),
            icon: const Icon(Icons.sync_alt, size: 14),
            label: const Text('REPLACE CLIP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: EatsTheme.primaryCyan,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );

    if (choice == 'load') {
      _codeController.text = sequence.code;
      _lastSyncedCode = sequence.code;
      _recompile(sequence.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded sequence "${sequence.name}" into editor. Click REPLACE (Ctrl+Enter) to apply.'),
            backgroundColor: EatsTheme.panelHeader,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (choice == 'replace') {
      _replaceClipWithSequence(sequence);
    }
  }

  void _replaceClipWithSequence(LuaScriptDef sequence) {
    final clip = widget.dawState.activeTrackClip;
    final track = widget.dawState.activeTrack;

    _codeController.text = sequence.code;
    _lastSyncedCode = sequence.code;
    _recompile(sequence.code);

    widget.dawState.applyPresetToClip(track, clip, sequence);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replaced clip "${clip.name}" notes with "${sequence.name}" (Undoable with Ctrl+Z)'),
          backgroundColor: EatsTheme.panelHeader,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.dawState.activeTrackClip;
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final midiSequences = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.midiSeq);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _executeScript,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _executeScript,
      },
      child: Column(
          children: [
            // Top Toolbar: MIDI Sequences & Replace Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isGrungy ? const Color(0xFF28231D) : EatsTheme.panelBackground,
              child: Row(
                children: [
                  Icon(Icons.view_timeline_outlined, size: 16, color: EatsTheme.accentGold),
                  const SizedBox(width: 6),
                  Text(
                    'MIDI SEQUENCES:',
                    style: EatsTheme.getDisplayFontStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EatsTheme.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<LuaScriptDef>(
                      isDense: true,
                      isExpanded: true,
                      dropdownColor: isGrungy ? const Color(0xFF1E1B18) : EatsTheme.panelBackground,
                      underline: const SizedBox(),
                      hint: Text('Select MIDI Sequence to Replace...', style: TextStyle(fontSize: 11, color: EatsTheme.textSecondary)),
                      items: midiSequences.map((s) {
                        return DropdownMenuItem<LuaScriptDef>(
                          value: s,
                          child: Text(s.name, style: const TextStyle(fontSize: 11)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _onSelectMidiSequence(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Replace clip notes with evaluated script output (Ctrl+Enter)',
                    child: ElevatedButton.icon(
                      onPressed: _executeScript,
                      icon: const Icon(Icons.sync_alt, size: 14),
                      label: const Text('REPLACE (Ctrl+Enter)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EatsTheme.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Follow Playback Toggle Button
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.dawState.isFollowPlaybackNotifier,
                    builder: (context, isFollowing, _) {
                      return InkWell(
                        onTap: widget.dawState.toggleFollowPlayback,
                        borderRadius: BorderRadius.circular(4),
                        child: Tooltip(
                          message: isFollowing ? 'Follow Playback: ON (F)' : 'Follow Playback: OFF (F)',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isFollowing ? EatsTheme.primaryCyan.withOpacity(0.2) : EatsTheme.controlBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isFollowing ? EatsTheme.primaryCyan : Colors.white12,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location,
                                  size: 13,
                                  color: isFollowing ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'FOLLOW',
                                  style: TextStyle(
                                    color: isFollowing ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Real-Time Playhead Follow & Active Sounding Notes Telemetry Strip
            ValueListenableBuilder<double>(
              valueListenable: widget.dawState.continuousArrangerStepNotifier,
              builder: (context, continuousStep, _) {
                final clip = widget.dawState.activeTrackClip;
                final clipStartStep = ((clip.startBar) * 16).toDouble();
                final clipEndStep = clipStartStep + (clip.barLength * 16).toDouble();
                final bool isWithinClip = continuousStep >= clipStartStep && continuousStep <= clipEndStep;
                final stepInClip = continuousStep - clipStartStep;

                final activeNotes = isWithinClip && widget.dawState.isPlaying
                    ? clip.notes.where((n) => stepInClip >= n.startStep && stepInClip < (n.startStep + n.durationSteps)).toList()
                    : <Note>[];

                final isFollowing = widget.dawState.isFollowPlayback;
                if (!isFollowing && !widget.dawState.isPlaying) {
                  return const SizedBox.shrink();
                }

                return Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: isGrungy ? const Color(0xFF1B1815) : const Color(0xFF0F141C),
                  child: Row(
                    children: [
                      Icon(
                        widget.dawState.isPlaying ? Icons.play_arrow : Icons.pause,
                        size: 13,
                        color: widget.dawState.isPlaying ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'STEP: ${stepInClip.clamp(0.0, 999.0).toStringAsFixed(1)} | BAR: ${(stepInClip / 16.0 + 1.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: EatsTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ACTIVE NOTES (${activeNotes.length}):',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: activeNotes.isNotEmpty ? EatsTheme.accentGold : EatsTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (activeNotes.isEmpty)
                        Text(
                          'None',
                          style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: EatsTheme.textMuted),
                        )
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: activeNotes.map((n) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: EatsTheme.primaryCyan.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: EatsTheme.primaryCyan, width: 0.8),
                                  ),
                                  child: Text(
                                    '${_getNoteName(n.pitch)} (P:${n.pitch} V:${(n.velocity * 100).toInt()}%)',
                                    style: TextStyle(
                                      color: EatsTheme.primaryCyan,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            // Dynamic Parameter Control Sliders
            if (_compilationResult.params.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: isGrungy ? const Color(0xFF1F1C18) : EatsTheme.controlBackground,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _compilationResult.params.map((p) {
                      final currentVal = clip.luaParams[p.name] ?? p.defaultValue;
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          children: [
                            Text(
                              '${p.name.toUpperCase()}: ${currentVal.toStringAsFixed(2)}',
                              style: EatsTheme.getDisplayFontStyle(fontSize: 10, color: EatsTheme.accentGold, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(
                              width: 110,
                              child: Slider(
                                value: currentVal.clamp(p.min, p.max),
                                min: p.min,
                                max: p.max,
                                activeColor: EatsTheme.secondaryMagenta,
                                inactiveColor: EatsTheme.controlBackground,
                                onChanged: (val) {
                                  setState(() {
                                    clip.luaParams[p.name] = val;
                                  });
                                  _executeScript();
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            // Code Editor Canvas with Line Numbers
            Expanded(
              child: Container(
                color: EatsTheme.codeEditorBackground,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Line Number Gutter (with Active Note Playback Follow Highlighting)
                    ValueListenableBuilder<double>(
                      valueListenable: widget.dawState.continuousArrangerStepNotifier,
                      builder: (context, continuousStep, _) {
                        final clip = widget.dawState.activeTrackClip;
                        final clipStartStep = ((clip.startBar) * 16).toDouble();
                        final stepInClip = continuousStep - clipStartStep;
                        final activeNotes = widget.dawState.isPlaying && widget.dawState.isFollowPlayback
                            ? clip.notes.where((n) => stepInClip >= n.startStep && stepInClip < (n.startStep + n.durationSteps)).toList()
                            : <Note>[];

                        final lines = _codeController.text.split('\n');

                        return Container(
                          width: 36,
                          color: EatsTheme.codeEditorGutterBackground,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              lines.length.clamp(1, 999),
                              (i) {
                                final lineText = i < lines.length ? lines[i] : '';
                                bool isNoteLine = false;
                                if (activeNotes.isNotEmpty) {
                                  for (final n in activeNotes) {
                                    final noteName = _getNoteName(n.pitch);
                                    if (lineText.contains('${n.pitch}') || lineText.contains(noteName)) {
                                      isNoteLine = true;
                                      break;
                                    }
                                  }
                                }

                                final isError = (i + 1 == _compilationResult.errorLine);

                                return Container(
                                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                                  decoration: isNoteLine
                                      ? BoxDecoration(
                                          border: Border(right: BorderSide(color: EatsTheme.primaryCyan, width: 2.5)),
                                          color: EatsTheme.primaryCyan.withOpacity(0.12),
                                        )
                                      : null,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: isNoteLine ? FontWeight.bold : FontWeight.normal,
                                      color: isError
                                          ? Colors.redAccent
                                          : (isNoteLine ? EatsTheme.primaryCyan : EatsTheme.codeEditorGutterTextColor),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    // Code Editor Text Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _codeController,
                          focusNode: _focusNode,
                          maxLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.3,
                            color: EatsTheme.codeEditorTextColor,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '-- Write Lua clip generator script here...',
                            hintStyle: TextStyle(color: EatsTheme.textMuted, fontFamily: 'monospace'),
                          ),
                          onChanged: (val) {
                            _recompile(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Diagnostic & Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: _compilationResult.isSuccess ? const Color(0xFF1B281F) : const Color(0xFF331416),
              child: Row(
                children: [
                  Icon(
                    _compilationResult.isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    size: 14,
                    color: _compilationResult.isSuccess ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _compilationResult.errorMessage,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: _compilationResult.isSuccess ? Colors.greenAccent : Colors.redAccent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}
