import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/daw_state.dart';
import '../theme/eats_theme.dart';
import '../lua/lua_engine.dart';
import '../lua/midi_pipeline_engine.dart';

class ScriptView extends StatefulWidget {
  final DawState dawState;

  const ScriptView({super.key, required this.dawState});

  @override
  State<ScriptView> createState() => _ScriptViewState();
}

class _ScriptViewState extends State<ScriptView> {
  late TextEditingController _codeController;
  late FocusNode _focusNode;
  LuaCompilationResult _compilationResult = LuaCompilationResult(
    isSuccess: true,
    errorMessage: 'Ready',
    params: [],
    scriptType: 'generator',
  );

  final List<Map<String, String>> _presetTemplates = [
    {
      'name': 'Pattern Arpeggiator',
      'code': '''-- Arpeggiator Clip Script (eatsbits.v1)
clip:registerParam("rate", 0.125, 1.0, 0.25)

function process(notes, time_ctx)
  return arpeggiate(notes, params.rate)
end''',
    },
    {
      'name': 'Scale Snap (Major Scale)',
      'code': '''-- Scale Snap Transformer (eatsbits.v1)
clip:registerParam("key", 0, 11, 0) -- 0 = C Major

function process(notes, time_ctx)
  return scale_snap(notes, params.key)
end''',
    },
    {
      'name': 'Humanize Velocity & Timing',
      'code': '''-- Humanizer Hook (eatsbits.v1)
clip:registerParam("timing", 0.0, 0.1, 0.02)
clip:registerParam("velocity", 0.0, 0.3, 0.08)

function process(notes, time_ctx)
  return humanize(notes, params.timing, params.velocity)
end''',
    },
    {
      'name': 'Pitch Transpose (+2 Semitones)',
      'code': '''-- Transpose Hook (eatsbits.v1)
clip:registerParam("semitones", -12, 12, 2)

function process(notes, time_ctx)
  return transpose(notes, params.semitones)
end''',
    },
    {
      'name': 'Euclidean Rhythm Generator',
      'code': '''-- Generative Euclidean Rhythm (eatsbits.v1)
clip:registerParam("pulses", 1, 16, 5)
clip:registerParam("steps", 4, 32, 16)

function process(notes, time_ctx)
  return generate_euclidean(params.pulses, params.steps, 60)
end''',
    },
  ];

  @override
  void initState() {
    super.initState();
    final clip = widget.dawState.activeTrackClip;

    // Synchronize visual notes into Lua table code on demand
    final initialCode = MidiPipelineEngine.serializeNotesToLua(
      clip.notes,
      existingCode: clip.luaScriptCode.isNotEmpty ? clip.luaScriptCode : null,
    );

    clip.luaScriptCode = initialCode;
    _codeController = TextEditingController(text: initialCode);
    _focusNode = FocusNode();
    _recompile(initialCode);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _recompile(String code) {
    setState(() {
      _compilationResult = LuaEngine.compile(code);
    });
  }

  void _executeScript() {
    final clip = widget.dawState.activeTrackClip;
    final track = widget.dawState.activeTrack;
    final code = _codeController.text;

    // Update clip code and parameter values
    clip.luaScriptCode = code;
    for (final p in _compilationResult.params) {
      if (!clip.luaParams.containsKey(p.name)) {
        clip.luaParams[p.name] = p.defaultValue;
      }
    }

    // Parse notes from Lua table if present and sync back to clip notes
    final parsedNotes = MidiPipelineEngine.parseNotesFromLuaTable(code);
    if (parsedNotes.isNotEmpty) {
      clip.notes = parsedNotes;
      track.notes = parsedNotes;
    }

    // Re-evaluate clip notes through MidiPipelineEngine
    final pipeline = MidiPipelineEngine(luaEngine: widget.dawState.luaEngine);
    pipeline.processClip(
      clip: clip,
      track: track,
      timeContext: widget.dawState.timeContext,
    );

    widget.dawState.notifyState();
  }

  void _applyPreset(String templateCode) {
    _codeController.text = templateCode;
    _recompile(templateCode);
    _executeScript();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.dawState.activeTrackClip;
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _executeScript,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _executeScript,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            // Top Toolbar: Presets & Execute Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isGrungy ? const Color(0xFF28231D) : EatsTheme.panelBackground,
              child: Row(
                children: [
                  Icon(Icons.code_off, size: 16, color: EatsTheme.accentGold),
                  const SizedBox(width: 6),
                  Text(
                    'SCRIPT PRESETS:',
                    style: EatsTheme.getDisplayFontStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EatsTheme.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isDense: true,
                      isExpanded: true,
                      dropdownColor: isGrungy ? const Color(0xFF1E1B18) : EatsTheme.panelBackground,
                      underline: const SizedBox(),
                      hint: Text('Select Template...', style: TextStyle(fontSize: 11, color: EatsTheme.textSecondary)),
                      items: _presetTemplates.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['code'],
                          child: Text(t['name']!, style: const TextStyle(fontSize: 11)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _applyPreset(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _executeScript,
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('RUN SCRIPT (Ctrl+Enter)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EatsTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
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
                    // Line Number Gutter
                    Container(
                      width: 36,
                      color: EatsTheme.codeEditorGutterBackground,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          _codeController.text.split('\n').length.clamp(1, 999),
                          (i) => Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 2),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: (i + 1 == _compilationResult.errorLine)
                                    ? Colors.redAccent
                                    : EatsTheme.codeEditorGutterTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
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
      ),
    );
  }
}
