import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/code_editor_scroll_controller.dart';
import 'widgets/show_on_screen_absorber.dart';

enum ScriptVimMode { normal, visualLine, insert, search }

/// High-density declarative Musical Event Notepad and Script Editor.
/// Canonical textual representation of the clip's notes, articulations, glissandos,
/// lyrics, and MIDI events. Supports line-level multi-selection, bi-directional sync,
/// and optional Vim modal keybindings.
class ScriptView extends StatefulWidget {
  final DawState dawState;

  const ScriptView({super.key, required this.dawState});

  @override
  State<ScriptView> createState() => _ScriptViewState();
}

class _ScriptViewState extends State<ScriptView> {
  static const double _editorFontSize = 12.0;
  static const double _editorLineHeight = 1.5; // Exactly 18.0 px line box
  static const double _editorRowHeight = 18.0;
  static const double _editorVerticalPadding = 8.0;

  static final StrutStyle _editorStrutStyle = StrutStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: EatsTheme.displayFontFallbacks,
    fontSize: _editorFontSize,
    height: _editorLineHeight,
    forceStrutHeight: true,
    leadingDistribution: TextLeadingDistribution.even,
  );

  late TextEditingController _codeController;
  late FocusNode _focusNode;
  final ScrollController _editorScrollController = CodeEditorScrollController();
  final ScrollController _gutterScrollController = ScrollController();

  String _currentClipId = '';
  String _lastSyncedCode = '';
  Timer? _debounceTimer;
  bool _isInternalTextChange = false;

  // Vim Modal Mode State
  bool _isVimModeEnabled = false;
  ScriptVimMode _vimMode = ScriptVimMode.normal;
  int _cursorLineIndex = 0;
  int? _visualAnchorLineIndex;
  String _statusMessage = 'Ready';

  @override
  void initState() {
    super.initState();
    final clip = widget.dawState.activeTrackClip;
    _currentClipId = clip.id;

    final initialText = _serializeNotesToNotepad(clip.notes, clip.name);
    _codeController = TextEditingController(text: initialText);
    _lastSyncedCode = initialText;
    _focusNode = FocusNode(
      debugLabel: 'ScriptNotepadFocus',
      onKeyEvent: _handleVimKey,
    );

    _editorScrollController.addListener(_syncGutterScroll);

    widget.dawState.addListener(_onDawStateChanged);
  }

  void _syncGutterScroll() {
    if (_gutterScrollController.hasClients && _editorScrollController.hasClients) {
      final maxGutter = _gutterScrollController.position.maxScrollExtent;
      final target = _editorScrollController.offset.clamp(0.0, maxGutter);
      if (_gutterScrollController.offset != target) {
        _gutterScrollController.jumpTo(target);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.dawState.removeListener(_onDawStateChanged);
    _codeController.dispose();
    _focusNode.dispose();
    _editorScrollController.removeListener(_syncGutterScroll);
    _editorScrollController.dispose();
    _gutterScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Serialization & Parsing
  // ---------------------------------------------------------------------------

  /// Serializes notes into human-readable, declarative Lua/Eatscript table syntax.
  static String _serializeNotesToNotepad(List<Note> notes, String clipName) {
    final buffer = StringBuffer();
    buffer.writeln('-- Clip: "$clipName" | Events: ${notes.length}');
    buffer.writeln('-- Syntax: { pitch = "C4", step = 0.0, dur = 1.0, vel = 0.90, art = "pizzicato", slide = true, lyric = "word" }');
    buffer.writeln();

    final sorted = List<Note>.from(notes)..sort((a, b) {
      final s = a.startStep.compareTo(b.startStep);
      return s != 0 ? s : a.pitch.compareTo(b.pitch);
    });

    for (final n in sorted) {
      final pName = Note.formatPitch(n.pitch);
      final stepStr = n.startStep.toStringAsFixed(n.startStep % 1 == 0 ? 1 : 2);
      final durStr = n.durationSteps.toStringAsFixed(n.durationSteps % 1 == 0 ? 1 : 2);
      final velStr = n.velocity.toStringAsFixed(2);

      buffer.write('{ pitch = "$pName", step = $stepStr, dur = $durStr, vel = $velStr');

      if (n.articulation != null && n.articulation!.isNotEmpty) {
        buffer.write(', art = "${n.articulation}"');
      }
      if (n.isSlide) {
        buffer.write(', slide = true');
      }
      if (n.lyric != null && n.lyric!.isNotEmpty) {
        buffer.write(', lyric = "${n.lyric}"');
      }
      if (n.column > 0) {
        buffer.write(', col = ${n.column}');
      }
      if (n.effectCommand != '00' && n.effectCommand.isNotEmpty) {
        buffer.write(', fx = "${n.effectCommand}"');
      }

      buffer.writeln(' }');
    }

    return buffer.toString();
  }

  /// Parses declarative note definitions from text into [Note] objects.
  static List<Note> _parseNotesFromNotepad(String text, String clipId) {
    final List<Note> result = [];
    final lines = text.split('\n');
    int counter = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('--') || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }

      // Check if line contains a dictionary / table
      if (!line.contains('{') || !line.contains('}')) continue;

      final content = line.substring(line.indexOf('{') + 1, line.lastIndexOf('}')).trim();
      final pairs = content.split(RegExp(r',\s*'));

      int pitch = 60;
      double step = 0.0;
      double dur = 1.0;
      double vel = 0.90;
      String? art;
      bool isSlide = false;
      String? lyric;
      int col = 0;
      String fx = '00';

      for (final pair in pairs) {
        final kv = pair.split(RegExp(r'\s*[:=]\s*'));
        if (kv.length < 2) continue;
        final key = kv[0].trim().toLowerCase();
        final rawVal = kv[1].trim().replaceAll('"', '').replaceAll("'", '');

        switch (key) {
          case 'pitch':
          case 'note':
          case 'p':
            final parsedPitch = Note.parsePitch(rawVal);
            if (parsedPitch != null) pitch = parsedPitch;
            break;
          case 'step':
          case 'start':
          case 's':
            step = double.tryParse(rawVal) ?? step;
            break;
          case 'dur':
          case 'duration':
          case 'd':
          case 'len':
            dur = double.tryParse(rawVal) ?? dur;
            break;
          case 'vel':
          case 'velocity':
          case 'v':
            final cleanVel = rawVal.replaceAll('%', '');
            final v = double.tryParse(cleanVel);
            if (v != null) {
              vel = v > 1.0 ? (v / 100.0).clamp(0.01, 1.0) : v.clamp(0.01, 1.0);
            }
            break;
          case 'art':
          case 'articulation':
            if (rawVal != 'normal' && rawVal.isNotEmpty) art = rawVal.toLowerCase();
            break;
          case 'slide':
          case 'gliss':
          case 'bend':
            isSlide = rawVal.toLowerCase() == 'true' || rawVal == '1' || rawVal == 's';
            break;
          case 'lyric':
          case 'word':
          case 'syl':
            if (rawVal.isNotEmpty) lyric = rawVal;
            break;
          case 'col':
          case 'column':
          case 'c':
            col = int.tryParse(rawVal) ?? col;
            break;
          case 'fx':
          case 'effect':
            if (rawVal.isNotEmpty) fx = rawVal;
            break;
        }
      }

      result.add(Note(
        id: 'n_script_${clipId}_$counter',
        pitch: pitch,
        startStep: step.clamp(0.0, 64.0),
        durationSteps: dur.clamp(0.25, 32.0),
        velocity: vel,
        articulation: art,
        isSlide: isSlide,
        lyric: lyric,
        column: col,
        effectCommand: fx,
      ));
      counter++;
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Sync Logic
  // ---------------------------------------------------------------------------

  void _onDawStateChanged() {
    if (!mounted) return;
    final clip = widget.dawState.activeTrackClip;

    if (clip.id != _currentClipId) {
      _currentClipId = clip.id;
      final newText = _serializeNotesToNotepad(clip.notes, clip.name);
      _lastSyncedCode = newText;
      _codeController.text = newText;
      if (mounted) setState(() {});
      return;
    }

    // External change (e.g. note edited in Piano Roll, Tracker, Score, or Sidebar)
    if (!_focusNode.hasFocus || _vimMode != ScriptVimMode.insert) {
      final currentCode = _serializeNotesToNotepad(clip.notes, clip.name);
      if (currentCode != _lastSyncedCode) {
        _lastSyncedCode = currentCode;
        _isInternalTextChange = true;
        _codeController.text = currentCode;
        _isInternalTextChange = false;
        if (mounted) setState(() {});
      }
    }
  }

  void _onTextChanged(String text) {
    if (_isInternalTextChange) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _parseAndApplyText(text);
    });
  }

  void _parseAndApplyText(String text) {
    final clip = widget.dawState.activeTrackClip;
    final track = widget.dawState.activeTrack;
    final parsed = _parseNotesFromNotepad(text, clip.id);

    clip.notes = parsed;
    track.notes = parsed.map((n) => n.copyWith()).toList();
    _lastSyncedCode = text;

    widget.dawState.recordHistory('Edit Notes in Script (${clip.name})', icon: Icons.code, force: true);
    setState(() {
      _statusMessage = 'Parsed ${parsed.length} notes';
    });
  }

  // ---------------------------------------------------------------------------
  // Line-to-Note Mapping & Selection
  // ---------------------------------------------------------------------------

  /// Returns the note corresponding to line index [lineIdx], if any.
  Note? _getNoteAtLine(int lineIdx) {
    final lines = _codeController.text.split('\n');
    if (lineIdx < 0 || lineIdx >= lines.length) return null;
    final line = lines[lineIdx].trim();
    if (!line.startsWith('{') || !line.contains('pitch')) return null;

    final track = widget.dawState.activeTrack;
    // Count which note definition line this is
    int noteDefCount = 0;
    for (int i = 0; i < lineIdx; i++) {
      final l = lines[i].trim();
      if (l.startsWith('{') && l.contains('pitch')) {
        noteDefCount++;
      }
    }

    if (noteDefCount < track.notes.length) {
      return track.notes[noteDefCount];
    }
    return null;
  }

  void _handleLineGutterClick(int lineIdx) {
    final track = widget.dawState.activeTrack;
    final note = _getNoteAtLine(lineIdx);
    if (note == null) return;

    if (HardwareKeyboard.instance.isShiftPressed) {
      widget.dawState.toggleNoteSelection(track, note.id);
    } else {
      widget.dawState.selectNotes(track, [note.id]);
    }
    _cursorLineIndex = lineIdx;
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Vim Modal Keybindings Handler
  // ---------------------------------------------------------------------------

  KeyEventResult _handleVimKey(FocusNode node, KeyEvent event) {
    if (!_isVimModeEnabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final track = widget.dawState.activeTrack;
    final lines = _codeController.text.split('\n');

    // Escape -> Return to Normal mode and clear selection
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _vimMode = ScriptVimMode.normal;
        _visualAnchorLineIndex = null;
        widget.dawState.clearNoteSelection(track);
        _statusMessage = '-- NORMAL --';
      });
      return KeyEventResult.handled;
    }

    // Insert Mode: allow standard typing
    if (_vimMode == ScriptVimMode.insert) {
      return KeyEventResult.ignored;
    }

    // Normal & Visual Modes
    if (_vimMode == ScriptVimMode.normal || _vimMode == ScriptVimMode.visualLine) {
      // 'i' or 'a' -> Enter Insert Mode
      if (key == LogicalKeyboardKey.keyI || key == LogicalKeyboardKey.keyA) {
        setState(() {
          _vimMode = ScriptVimMode.insert;
          _statusMessage = '-- INSERT --';
        });
        return KeyEventResult.handled;
      }

      // 'V' -> Toggle Visual Line Mode
      if (key == LogicalKeyboardKey.keyV) {
        setState(() {
          if (_vimMode == ScriptVimMode.visualLine) {
            _vimMode = ScriptVimMode.normal;
            _visualAnchorLineIndex = null;
            widget.dawState.clearNoteSelection(track);
            _statusMessage = '-- NORMAL --';
          } else {
            _vimMode = ScriptVimMode.visualLine;
            _visualAnchorLineIndex = _cursorLineIndex;
            _syncVisualLineSelection(track);
            _statusMessage = '-- VISUAL LINE --';
          }
        });
        return KeyEventResult.handled;
      }

      // 'j' -> Move down
      if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _cursorLineIndex = (_cursorLineIndex + 1).clamp(0, math.max(0, lines.length - 1));
          if (_vimMode == ScriptVimMode.visualLine) {
            _syncVisualLineSelection(track);
          } else {
            final n = _getNoteAtLine(_cursorLineIndex);
            if (n != null) widget.dawState.selectNotes(track, [n.id]);
          }
        });
        return KeyEventResult.handled;
      }

      // 'k' -> Move up
      if (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _cursorLineIndex = (_cursorLineIndex - 1).clamp(0, math.max(0, lines.length - 1));
          if (_vimMode == ScriptVimMode.visualLine) {
            _syncVisualLineSelection(track);
          } else {
            final n = _getNoteAtLine(_cursorLineIndex);
            if (n != null) widget.dawState.selectNotes(track, [n.id]);
          }
        });
        return KeyEventResult.handled;
      }

      // 'd' -> Delete selected notes / line
      if (key == LogicalKeyboardKey.keyD || key == LogicalKeyboardKey.delete) {
        if (track.hasSelectedNotes) {
          widget.dawState.removeNotes(track, track.selectedNoteIds);
          _rebuildTextFromTrackNotes(track);
          _vimMode = ScriptVimMode.normal;
          _statusMessage = 'Deleted selected notes';
          setState(() {});
          return KeyEventResult.handled;
        }
      }

      // 'y' -> Yank (Copy to clipboard)
      if (key == LogicalKeyboardKey.keyY) {
        widget.dawState.copyNotesToClipboard(track, track.selectedNoteIds);
        _statusMessage = 'Yanked ${track.selectedNoteIds.length} notes';
        setState(() {});
        return KeyEventResult.handled;
      }

      // '+' or '=' -> Transpose +1 semitone
      if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add) {
        if (track.hasSelectedNotes) {
          widget.dawState.transposeNotes(track, track.selectedNoteIds, 1);
          _rebuildTextFromTrackNotes(track);
          _statusMessage = 'Transposed +1 semitone';
          setState(() {});
          return KeyEventResult.handled;
        }
      }

      // '-' -> Transpose -1 semitone
      if (key == LogicalKeyboardKey.minus) {
        if (track.hasSelectedNotes) {
          widget.dawState.transposeNotes(track, track.selectedNoteIds, -1);
          _rebuildTextFromTrackNotes(track);
          _statusMessage = 'Transposed -1 semitone';
          setState(() {});
          return KeyEventResult.handled;
        }
      }

      // ']' -> Transpose +12 semitones (Octave Up)
      if (key == LogicalKeyboardKey.bracketRight) {
        if (track.hasSelectedNotes) {
          widget.dawState.transposeNotes(track, track.selectedNoteIds, 12);
          _rebuildTextFromTrackNotes(track);
          _statusMessage = 'Transposed +1 Octave';
          setState(() {});
          return KeyEventResult.handled;
        }
      }

      // '[' -> Transpose -12 semitones (Octave Down)
      if (key == LogicalKeyboardKey.bracketLeft) {
        if (track.hasSelectedNotes) {
          widget.dawState.transposeNotes(track, track.selectedNoteIds, -12);
          _rebuildTextFromTrackNotes(track);
          _statusMessage = 'Transposed -1 Octave';
          setState(() {});
          return KeyEventResult.handled;
        }
      }

      // '>' or '.' -> Nudge position right by snap
      if (key == LogicalKeyboardKey.period) {
        if (track.hasSelectedNotes) {
          widget.dawState.nudgeNotesPosition(track, track.selectedNoteIds, widget.dawState.quantizeSnap);
          _rebuildTextFromTrackNotes(track);
          _statusMessage = 'Nudged right';
          setState(() {});
          return KeyEventResult.handled;
        }
      }

      // '<' or ',' -> Nudge position left by snap
      if (key == LogicalKeyboardKey.comma) {
        if (track.hasSelectedNotes) {
          widget.dawState.nudgeNotesPosition(track, track.selectedNoteIds, -widget.dawState.quantizeSnap);
          _rebuildTextFromTrackNotes(track);
          _statusMessage = 'Nudged left';
          setState(() {});
          return KeyEventResult.handled;
        }
      }

      // '/' -> Search
      if (key == LogicalKeyboardKey.slash) {
        _openSearchDialog();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _syncVisualLineSelection(TrackChannel track) {
    if (_visualAnchorLineIndex == null) return;
    final minIdx = math.min(_visualAnchorLineIndex!, _cursorLineIndex);
    final maxIdx = math.max(_visualAnchorLineIndex!, _cursorLineIndex);

    final Set<String> targetIds = {};
    for (int i = minIdx; i <= maxIdx; i++) {
      final n = _getNoteAtLine(i);
      if (n != null) targetIds.add(n.id);
    }
    widget.dawState.selectNotes(track, targetIds);
  }

  void _rebuildTextFromTrackNotes(TrackChannel track) {
    final clip = widget.dawState.activeTrackClip;
    clip.notes = track.notes.map((n) => n.copyWith()).toList();
    final newText = _serializeNotesToNotepad(clip.notes, clip.name);
    _isInternalTextChange = true;
    _codeController.text = newText;
    _lastSyncedCode = newText;
    _isInternalTextChange = false;
  }

  void _openSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: EatsTheme.panelBackground,
          title: Text(
            'SEARCH & SELECT NOTES',
            style: EatsTheme.getDisplayFontStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EatsTheme.primaryCyan),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. "pizzicato", "C4", "vel > 0.8"',
              hintStyle: TextStyle(color: EatsTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: EatsTheme.primaryCyan, foregroundColor: Colors.black),
              onPressed: () {
                final q = ctrl.text.trim().toLowerCase();
                Navigator.of(ctx).pop();
                if (q.isNotEmpty) _searchAndSelectNotes(q);
              },
              child: const Text('SELECT MATCHES'),
            ),
          ],
        );
      },
    );
  }

  void _searchAndSelectNotes(String query) {
    final track = widget.dawState.activeTrack;
    final Set<String> matched = {};

    for (final n in track.notes) {
      final pitchName = Note.formatPitch(n.pitch).toLowerCase();
      final art = (n.articulation ?? '').toLowerCase();
      final lyric = (n.lyric ?? '').toLowerCase();

      if (pitchName.contains(query) ||
          art.contains(query) ||
          lyric.contains(query) ||
          (query == 'slide' && n.isSlide) ||
          (query == 'bend' && n.isSlide)) {
        matched.add(n.id);
      }
    }

    if (matched.isNotEmpty) {
      widget.dawState.selectNotes(track, matched);
      _statusMessage = 'Matched ${matched.length} notes';
    } else {
      _statusMessage = 'No notes matched "$query"';
    }
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Build Method
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final track = widget.dawState.activeTrack;
    final clip = widget.dawState.activeTrackClip;
    final lines = _codeController.text.split('\n');

    return Column(
      children: [
          // Top Toolbar: Declarative Notepad Controls & Vim Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: EatsTheme.panelBackground,
            child: Row(
              children: [
                Icon(Icons.notes, size: 16, color: EatsTheme.primaryCyan),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'NOTEPAD: ${clip.name.toUpperCase()} (${clip.notes.length} NOTES)',
                    style: EatsTheme.getDisplayFontStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: EatsTheme.textLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // Search button
                IconButton(
                  icon: const Icon(Icons.search, size: 16),
                  color: EatsTheme.primaryCyan,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Search & Select Notes (/)',
                  onPressed: _openSearchDialog,
                ),
                const SizedBox(width: 8),

                // Re-format button
                IconButton(
                  icon: const Icon(Icons.format_align_left, size: 16),
                  color: EatsTheme.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Format & Sort Notes',
                  onPressed: () {
                    _rebuildTextFromTrackNotes(track);
                    setState(() {});
                  },
                ),
                const SizedBox(width: 8),

                // Select All Quick Action (Crucial for mobile and fast editing)
                InkWell(
                  onTap: () {
                    _codeController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _codeController.text.length,
                    );
                    _focusNode.requestFocus();
                    setState(() {
                      _statusMessage = 'Selected all notes';
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.select_all, size: 13, color: EatsTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          'SELECT ALL',
                          style: EatsTheme.getPrimaryFontStyle(
                            color: EatsTheme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Copy Quick Action
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: _codeController.text));
                    setState(() {
                      _statusMessage = 'Copied script to clipboard';
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 13, color: EatsTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          'COPY',
                          style: EatsTheme.getPrimaryFontStyle(
                            color: EatsTheme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Vim Mode Toggle Button
                InkWell(
                  onTap: () {
                    setState(() {
                      _isVimModeEnabled = !_isVimModeEnabled;
                      _vimMode = _isVimModeEnabled ? ScriptVimMode.normal : ScriptVimMode.insert;
                      _statusMessage = _isVimModeEnabled ? '-- NORMAL --' : 'Vim Mode Disabled';
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isVimModeEnabled
                          ? EatsTheme.accentGold.withOpacity(0.2)
                          : EatsTheme.controlBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isVimModeEnabled ? EatsTheme.accentGold : EatsTheme.textMuted.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard,
                          size: 13,
                          color: _isVimModeEnabled ? EatsTheme.accentGold : EatsTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isVimModeEnabled ? 'VIM: ON' : 'VIM: OFF',
                          style: TextStyle(
                            color: _isVimModeEnabled ? EatsTheme.accentGold : EatsTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code Text Area with Line Number Gutter & Multi-Selection Highlight
          Expanded(
            child: Container(
              color: EatsTheme.codeEditorBackground,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gutter (Line Numbers & Selection Badges with hidden scrollbar & mouse wheel pass-through)
                  Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent && _editorScrollController.hasClients) {
                        final maxScroll = _editorScrollController.position.maxScrollExtent;
                        final newOffset = (_editorScrollController.offset + event.scrollDelta.dy).clamp(0.0, maxScroll);
                        _editorScrollController.jumpTo(newOffset);
                      }
                    },
                    child: Container(
                      width: 44,
                      color: EatsTheme.codeEditorGutterBackground,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: ListView.builder(
                          controller: _gutterScrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 4.0, bottom: _editorVerticalPadding),
                          itemCount: lines.length,
                          itemExtent: _editorRowHeight,
                          itemBuilder: (context, i) {
                            final note = _getNoteAtLine(i);
                            final isNoteSelected = note != null && track.isNoteSelected(note.id);
                            final isCursorLine = _isVimModeEnabled && _cursorLineIndex == i;

                            return InkWell(
                              onTap: () => _handleLineGutterClick(i),
                              child: Container(
                                height: _editorRowHeight,
                                padding: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isNoteSelected
                                      ? EatsTheme.primaryCyan.withOpacity(0.30)
                                      : (isCursorLine ? EatsTheme.accentGold.withOpacity(0.20) : Colors.transparent),
                                  border: Border(
                                    right: BorderSide(
                                      color: isNoteSelected
                                          ? EatsTheme.primaryCyan
                                          : (isCursorLine ? EatsTheme.accentGold : Colors.transparent),
                                      width: isNoteSelected || isCursorLine ? 3.0 : 0.0,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${i + 1}',
                                  strutStyle: _editorStrutStyle,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontFamilyFallback: EatsTheme.displayFontFallbacks,
                                    fontSize: _editorFontSize,
                                    height: _editorLineHeight,
                                    leadingDistribution: TextLeadingDistribution.even,
                                    fontWeight: isNoteSelected || isCursorLine ? FontWeight.bold : FontWeight.normal,
                                    color: isNoteSelected
                                        ? EatsTheme.primaryCyan
                                        : (isCursorLine ? EatsTheme.accentGold : EatsTheme.codeEditorGutterTextColor),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Main Text Field wrapped in ShowOnScreenAbsorber to prevent outer scroll jumps
                  Expanded(
                    child: ShowOnScreenAbsorber(
                      child: TextField(
                        controller: _codeController,
                        focusNode: _focusNode,
                        scrollController: _editorScrollController,
                        scrollPhysics: const ClampingScrollPhysics(),
                        readOnly: _isVimModeEnabled && _vimMode != ScriptVimMode.insert,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        strutStyle: _editorStrutStyle,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontFamilyFallback: EatsTheme.displayFontFallbacks,
                          fontSize: _editorFontSize,
                          height: _editorLineHeight,
                          leadingDistribution: TextLeadingDistribution.even,
                          color: EatsTheme.codeEditorTextColor,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.fromLTRB(8, _editorVerticalPadding, 8, _editorVerticalPadding),
                          border: InputBorder.none,
                          hintText: '-- Write note events here...',
                          hintStyle: TextStyle(
                            color: EatsTheme.textMuted,
                            fontFamily: 'monospace',
                            fontFamilyFallback: EatsTheme.displayFontFallbacks,
                          ),
                        ),
                        onChanged: _onTextChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Vim Mode & Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: const Color(0xFF0F141C),
            child: Row(
              children: [
                if (_isVimModeEnabled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _vimMode == ScriptVimMode.insert
                          ? Colors.greenAccent.withOpacity(0.25)
                          : (_vimMode == ScriptVimMode.visualLine
                              ? EatsTheme.primaryCyan.withOpacity(0.25)
                              : EatsTheme.accentGold.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _vimMode == ScriptVimMode.insert
                          ? 'INSERT'
                          : (_vimMode == ScriptVimMode.visualLine ? 'VISUAL LINE' : 'NORMAL'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: _vimMode == ScriptVimMode.insert
                            ? Colors.greenAccent
                            : (_vimMode == ScriptVimMode.visualLine ? EatsTheme.primaryCyan : EatsTheme.accentGold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'LINE: ${_cursorLineIndex + 1} | SELECTED: ${track.selectedNoteIds.length} NOTES',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    color: EatsTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    color: EatsTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }
}
