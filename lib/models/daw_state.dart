import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/platform_env_helper.dart';
import '../utils/eats_storage_helper.dart';
import '../utils/midi_file_parser.dart';

import '../audio/audio_engine.dart';
import '../audio/convolver_engine.dart';
import '../audio/procedural_ir_generator.dart';
import '../audio/sampler_engine.dart';
import '../audio/soundfont_engine.dart';
import '../audio/tts_engine.dart';
import '../audio/wav_exporter.dart';
import '../theme/eats_theme.dart';
import '../lua/lua_engine.dart';
import '../lua/lua_gui_model.dart';
import '../lua/eats_lua_serializer.dart';
import '../lua/eats_lua_parser.dart';
import '../audio/time_context.dart';
import '../lua/lua_preset_library.dart';
import '../lua/midi_pipeline_engine.dart';
import '../lua/default_song.dart';
import 'track_model.dart';
import 'chord_model.dart';
import 'history_manager.dart';
import 'lyric_model.dart';
import 'script_target_model.dart';
import 'automation_model.dart';
import '../audio/easing.dart';

class DawState extends ChangeNotifier {
  final AudioEngine audioEngine = AudioEngine();
  final LuaEngine luaEngine = LuaEngine();
  final HistoryManager history = HistoryManager();

  String projectName = 'Untitled Song';
  String authorName = 'Anonymous Producer';

  // Global Harmonic & Chord Track State
  String _songKey = 'C Major';
  String get songKey => _songKey;
  
  int get songKeyRoot {
    final rootPart = _songKey.split(' ').first;
    final idx = ChordTheory.pitchClassNames.indexOf(rootPart);
    if (idx != -1) return idx;
    final flatIdx = ChordTheory.pitchClassFlatNames.indexOf(rootPart);
    if (flatIdx != -1) return flatIdx;
    return 0;
  }

  bool get isSongKeyMinor => _songKey.toLowerCase().contains('minor') || _songKey.toLowerCase().contains('min');

  void setSongKey(String newKey) {
    if (_songKey != newKey) {
      _songKey = newKey;
      recordHistory('Set Song Key: $newKey', icon: Icons.music_note);
      triggerAutoSave();
      notifyListeners();
    }
  }

  List<ChordEvent> chordTrack = [];

  ChordEvent? getActiveChordAtStep(int stepIdx) {
    final bar = stepIdx / 16.0;
    for (final chord in chordTrack) {
      if (bar >= chord.startBar && bar < (chord.startBar + chord.barLength)) {
        return chord;
      }
    }
    return null;
  }

  ChordEvent? getActiveChordAtBar(int barIdx) {
    for (final chord in chordTrack) {
      if (barIdx >= chord.startBar && barIdx < (chord.startBar + chord.barLength)) {
        return chord;
      }
    }
    return null;
  }

  void addOrUpdateChord(ChordEvent chord) {
    final existingIdx = chordTrack.indexWhere((c) => c.id == chord.id);
    if (existingIdx != -1) {
      chordTrack[existingIdx] = chord;
    } else {
      // Remove any overlapping chord at exactly that start bar
      chordTrack.removeWhere((c) => c.startBar == chord.startBar);
      chordTrack.add(chord);
      chordTrack.sort((a, b) => a.startBar.compareTo(b.startBar));
    }
    recordHistory('Set Chord ${chord.displayName} at Bar ${chord.startBar + 1}', icon: Icons.queue_music);
    triggerAutoSave();
    notifyListeners();
  }

  void removeChord(String chordId) {
    final removed = chordTrack.firstWhere((c) => c.id == chordId, orElse: () => ChordEvent(id: '', startBar: 0, rootPitchClass: 0, quality: ChordQuality.major));
    chordTrack.removeWhere((c) => c.id == chordId);
    if (removed.id.isNotEmpty) {
      recordHistory('Removed Chord ${removed.displayName}', icon: Icons.delete_outline);
      triggerAutoSave();
      notifyListeners();
    }
  }

  void clearChordTrack() {
    chordTrack.clear();
    recordHistory('Cleared Chord Track', icon: Icons.clear_all);
    triggerAutoSave();
    notifyListeners();
  }

  void applyChordProgressionPreset(ChordProgressionPreset preset, {int startBar = 0}) {
    int currentBar = startBar;
    for (final chordDef in preset.chords) {
      final rootPc = (songKeyRoot + chordDef.$1) % 12;
      chordTrack.removeWhere((c) => c.startBar >= currentBar && c.startBar < (currentBar + chordDef.$3));
      chordTrack.add(ChordEvent(
        id: 'chord_${DateTime.now().millisecondsSinceEpoch}_$currentBar',
        startBar: currentBar,
        barLength: chordDef.$3,
        rootPitchClass: rootPc,
        quality: chordDef.$2,
      ));
      currentBar += chordDef.$3.toInt();
    }
    chordTrack.sort((a, b) => a.startBar.compareTo(b.startBar));
    recordHistory('Applied Progression "${preset.name}"', icon: Icons.auto_awesome);
    triggerAutoSave();
    notifyListeners();
  }

  void auditionChord(ChordEvent chord) {
    final midiNotes = ChordTheory.getAuditionMidiNotes(chord);
    for (final pitch in midiNotes) {
      audioEngine.playNoteOrSample(
        track: activeTrack,
        midiNote: pitch,
        velocity: 0.8,
        durationSec: 1.2,
      );
    }
  }

  void setTrackChordFollowMode(TrackChannel track, ChordFollowMode mode) {
    track.chordFollowMode = mode;
    recordHistory('Track "${track.name}" Follow: ${mode.displayName}', icon: Icons.tune);
    triggerAutoSave();
    notifyListeners();
  }

  void bakeTrackChordsToMidi(TrackChannel track) {
    if (track.chordFollowMode == ChordFollowMode.off) return;

    for (final clip in track.clips) {
      for (final note in clip.notes) {
        final stepIdx = (clip.startBar * 16) + note.startStep.toInt();
        final chord = getActiveChordAtStep(stepIdx);
        if (chord != null) {
          note.pitch = ChordTheory.remapPitchForChord(note.pitch, chord, track.chordFollowMode.name);
        }
      }
    }
    for (int i = 0; i < track.steps.length; i++) {
      final step = track.steps[i];
      if (step.active) {
        final chord = getActiveChordAtStep(i);
        if (chord != null) {
          step.pitch = ChordTheory.remapPitchForChord(step.pitch, chord, track.chordFollowMode.name);
        }
      }
    }
    track.chordFollowMode = ChordFollowMode.off;
    _syncClipNotes(track);
    recordHistory('Baked Chords to MIDI for "${track.name}"', icon: Icons.lock_clock);
    triggerAutoSave();
    notifyListeners();
  }

  String _formatPitch(int pitch) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (pitch ~/ 12) - 1;
    return '${names[pitch % 12]}$octave';
  }

  void setProjectDetails(String name, String author) {
    projectName = name.trim().isEmpty ? 'Untitled Song' : name.trim();
    authorName = author.trim().isEmpty ? 'Anonymous Producer' : author.trim();
    recordHistory('Project Info: "$projectName"', icon: Icons.edit);
    notifyListeners();
  }

  void notifyState() => notifyListeners();

  TimeContext get timeContext {
    final curStep = (_currentBar * 16 + _currentStep).toDouble();

    Map<String, dynamic>? activeWord;
    Map<String, dynamic>? activeLine;
    final List<Map<String, dynamic>> upcoming = [];
    final List<Map<String, dynamic>> allLyricsList = [];

    final activeTracksWithLyrics = activePattern.tracks.where((t) => t.hasLyrics).toList();
    for (final track in activeTracksWithLyrics) {
      final List<LyricCue> allCues = [];
      if (track.clips.isNotEmpty) {
        for (final clip in track.clips) {
          final clipStart = clip.startBar * 16.0;
          for (final cue in clip.lyrics) {
            allCues.add(cue.copyWith(startStep: clipStart + cue.startStep));
          }
          for (final note in clip.notes) {
            if (note.lyric != null && note.lyric!.isNotEmpty) {
              allCues.add(LyricCue(
                id: 'note_${note.id}',
                startStep: clipStart + note.startStep,
                durationSteps: note.durationSteps,
                text: note.lyric!,
              ));
            }
          }
        }
      } else {
        allCues.addAll(track.lyrics);
        for (final note in track.notes) {
          if (note.lyric != null && note.lyric!.isNotEmpty) {
            allCues.add(LyricCue(
              id: 'note_${note.id}',
              startStep: note.startStep,
              durationSteps: note.durationSteps,
              text: note.lyric!,
            ));
          }
        }
      }

      allCues.sort((a, b) => a.startStep.compareTo(b.startStep));

      for (final cue in allCues) {
        final map = {
          'id': cue.id,
          'trackId': track.id,
          'trackName': track.name,
          'text': cue.text,
          'startStep': cue.startStep,
          'durationSteps': cue.durationSteps,
          'pitch': cue.pitch,
          'rate': cue.rate,
        };
        allLyricsList.add(map);

        if (curStep >= cue.startStep && curStep < (cue.startStep + cue.durationSteps)) {
          final prog = ((curStep - cue.startStep) / math.max(0.1, cue.durationSteps)).clamp(0.0, 1.0);
          activeWord = {
            ...map,
            'progress': prog,
          };
        } else if (cue.startStep > curStep && upcoming.length < 5) {
          upcoming.add(map);
        }
      }
    }

    return TimeContext.fromBeat(
      beat: (_currentBar * 4 + _currentStep / 4).toDouble(),
      bpm: _bpm,
      activeChord: getActiveChordAtStep(curStep.toInt()),
      chordTrack: List.unmodifiable(chordTrack),
      songKey: songKey,
      songKeyRoot: songKeyRoot,
      isSongKeyMinor: isSongKeyMinor,
      activeLyricWord: activeWord,
      activeLyricLine: activeLine,
      upcomingLyrics: upcoming,
      allLyrics: allLyricsList,
    );
  }

  TrackClip get activeTrackClip {
    if (activeTrack.clips.isEmpty) {
      activeTrack.clips.add(TrackClip(
        id: 'clip_${activeTrack.id}_0',
        name: '${activeTrack.name} Clip',
        trackId: activeTrack.id,
        startBar: 0,
        barLength: 2,
        notes: activeTrack.notes.map((n) => n.copyWith()).toList(),
        luaScriptCode: '',
        luaParams: {},
      ));
    }
    return activeTrack.clips.first;
  }

  // Navigation & View Mode
  int _activeTabIndex = 0; // 0: Arranger, 1: Edit, 2: Track, 3: Mixer, 4: Scripts
  int get activeTabIndex => _activeTabIndex;
  set activeTabIndex(int index) {
    _activeTabIndex = index;
    notifyListeners();
  }

  // UI Scale Settings (0.70x to 1.30x)
  double _uiScale = 1.0;
  double get uiScale => _uiScale;
  final ValueNotifier<double> uiScaleNotifier = ValueNotifier<double>(1.0);

  void setUiScalePreview(double scale) {
    _uiScale = (scale * 100).roundToDouble() / 100;
    uiScaleNotifier.value = _uiScale;
    notifyListeners();
  }

  void commitUiScale(double scale) {
    _uiScale = (scale * 100).roundToDouble() / 100;
    uiScaleNotifier.value = _uiScale;
    EatsStorageHelper.setDouble(EatsStorageHelper.keyUiScale, _uiScale);
    notifyListeners();
  }

  void revertUiScale(double originalScale) {
    _uiScale = (originalScale * 100).roundToDouble() / 100;
    uiScaleNotifier.value = _uiScale;
    notifyListeners();
  }

  void resetUiScale() {
    commitUiScale(1.0);
  }

  // Floating In-App VSTi Window State
  String? _floatingInstrumentTrackId;
  String? get floatingInstrumentTrackId => _floatingInstrumentTrackId;

  bool _isFloatingWindowVisible = false;
  bool get isFloatingWindowVisible => _isFloatingWindowVisible;

  bool _isFloatingWindowMaximized = false;
  bool get isFloatingWindowMaximized => _isFloatingWindowMaximized;

  Offset _preMaximizedPosition = const Offset(60, 40);
  Size _preMaximizedSize = const Size(540, 340);

  Offset _floatingWindowPosition = const Offset(120, 60);
  Offset get floatingWindowPosition => _floatingWindowPosition;

  Size _floatingWindowSize = const Size(540, 340);
  Size get floatingWindowSize => _floatingWindowSize;

  double _floatingWindowScale = 1.0;
  double get floatingWindowScale => _floatingWindowScale;

  String? _floatingFxTrackId;
  String? _floatingFxInsertId;
  String? get floatingFxTrackId => _floatingFxTrackId;
  String? get floatingFxInsertId => _floatingFxInsertId;

  FXInsert? get floatingFxInsert {
    if (_floatingFxInsertId == null || _floatingFxTrackId == null) return null;
    final parent = _floatingFxTrackId == masterTrack.id
        ? masterTrack
        : activePattern.tracks.firstWhere(
            (t) => t.id == _floatingFxTrackId,
            orElse: () => activeTrack,
          );
    try {
      return parent.fxRack.firstWhere((f) => f.id == _floatingFxInsertId);
    } catch (_) {
      return null;
    }
  }

  TrackChannel? get floatingFxTrack {
    if (_floatingFxTrackId == null) return null;
    if (_floatingFxTrackId == masterTrack.id) return masterTrack;
    return activePattern.tracks.firstWhere(
      (t) => t.id == _floatingFxTrackId,
      orElse: () => activeTrack,
    );
  }

  TrackChannel? get floatingInstrumentTrack {
    if (_floatingInstrumentTrackId == null) return activeTrack;
    return activePattern.tracks.firstWhere(
      (t) => t.id == _floatingInstrumentTrackId,
      orElse: () => activeTrack,
    );
  }

  void openFloatingInstrumentWindow([TrackChannel? track, Size? workspaceSize]) {
    final target = track ?? activeTrack;
    _floatingFxTrackId = null;
    _floatingFxInsertId = null;
    _floatingInstrumentTrackId = target.id;
    _isFloatingWindowVisible = true;
    final trackIdx = activePattern.tracks.indexOf(target);
    if (trackIdx != -1) {
      activeTrackIndex = trackIdx;
    }
    if (workspaceSize != null) {
      fitFloatingWindowToWorkspace(workspaceSize, target);
    } else {
      final naturalH = getTrackNaturalGuiHeight(target);
      _floatingWindowSize = Size(540, (naturalH + 38.0).clamp(240.0, 680.0));
      notifyListeners();
    }
  }

  void openFloatingFxWindow(TrackChannel track, FXInsert fx, {Size? workspaceSize}) {
    _floatingInstrumentTrackId = null;
    _floatingFxTrackId = track.id;
    _floatingFxInsertId = fx.id;
    _isFloatingWindowVisible = true;

    final fxTrack = TrackChannel(
      id: fx.id,
      name: fx.name,
      type: TrackType.luaScript,
      color: EatsTheme.secondaryMagenta,
      luaScriptCode: fx.luaScriptCode ?? '',
      luaParams: fx.luaParams,
      sampleName: fx.irSampleName ?? 'Great Hall',
    );

    if (workspaceSize != null) {
      fitFloatingWindowToWorkspace(workspaceSize, fxTrack);
    } else {
      final naturalH = getTrackNaturalGuiHeight(fxTrack);
      _floatingWindowSize = Size(540, (naturalH + 38.0).clamp(240.0, 680.0));
      notifyListeners();
    }
  }

  void closeFloatingInstrumentWindow() {
    _isFloatingWindowVisible = false;
    _isFloatingWindowMaximized = false;
    _floatingFxTrackId = null;
    _floatingFxInsertId = null;
    _floatingInstrumentTrackId = null;
    notifyListeners();
  }

  void setFloatingInstrumentTrack(TrackChannel track, {Size? workspaceSize}) {
    final prevId = _floatingInstrumentTrackId;
    _floatingFxTrackId = null;
    _floatingFxInsertId = null;
    _floatingInstrumentTrackId = track.id;
    _isFloatingWindowVisible = true;

    if (workspaceSize != null) {
      fitFloatingWindowToWorkspace(workspaceSize, track);
    } else if (prevId != track.id) {
      final naturalH = getTrackNaturalGuiHeight(track);
      _floatingWindowSize = Size(540, (naturalH + 38.0).clamp(240.0, 680.0));
      notifyListeners();
    }
  }

  void toggleFloatingInstrumentWindow([TrackChannel? track, Size? workspaceSize]) {
    final target = track ?? activeTrack;
    if (_isFloatingWindowVisible && _floatingInstrumentTrackId == target.id && _floatingFxInsertId == null) {
      closeFloatingInstrumentWindow();
    } else {
      openFloatingInstrumentWindow(target, workspaceSize);
    }
  }

  void toggleFloatingWindowForTrack(TrackChannel target, {Size? workspaceSize}) {
    if (_isFloatingWindowVisible && _floatingInstrumentTrackId == target.id && _floatingFxInsertId == null) {
      closeFloatingInstrumentWindow();
    } else {
      openFloatingInstrumentWindow(target, workspaceSize);
    }
  }

  /// Calculates the exact natural content height of a track's GUI
  /// to eliminate any letterboxing or empty padding in floating windows.
  double getTrackNaturalGuiHeight(TrackChannel track) {
    final compilation = track.luaScriptCode.isNotEmpty
        ? LuaEngine.compile(track.luaScriptCode)
        : compilationResult;
    final gui = compilation.guiLayout;

    if (gui != null && gui.children.isNotEmpty) {
      double totalHeight = 16.0; // container top/bottom padding
      for (final node in gui.children) {
        double nodeH = 70.0;
        if (node.type == LuaGuiNodeType.row || node.type == LuaGuiNodeType.column) {
          final hasListBox = node.children.any((c) => c.type == LuaGuiNodeType.listBox);
          final onlyHorizontalSliders = node.children.isNotEmpty && node.children.every((c) => (c.type == LuaGuiNodeType.slider) && c.orientation != 'vertical');
          final hasKnobOrSlider = node.children.any((c) => c.type == LuaGuiNodeType.knob || c.type == LuaGuiNodeType.slider || c.type == LuaGuiNodeType.fader);
          final onlyDisplays = node.children.every((c) => c.type == LuaGuiNodeType.nixie || c.type == LuaGuiNodeType.lcd || c.type == LuaGuiNodeType.label || c.type == LuaGuiNodeType.button);

          if (onlyHorizontalSliders) {
            nodeH = 40.0;
          } else if (hasListBox) {
            nodeH = 76.0;
          } else if (hasKnobOrSlider) {
            nodeH = 70.0;
          } else if (onlyDisplays) {
            nodeH = 42.0;
          }
        } else if (node.type == LuaGuiNodeType.group) {
          nodeH = 88.0;
        } else if (node.type == LuaGuiNodeType.nixie || node.type == LuaGuiNodeType.lcd) {
          nodeH = 42.0;
        } else if (node.type == LuaGuiNodeType.listBox) {
          nodeH = 76.0;
        } else if (node.type == LuaGuiNodeType.spaceVisualizer || node.type == LuaGuiNodeType.waveshaperCanvas) {
          nodeH = node.height ?? 160.0;
        }
        totalHeight += nodeH + 8.0;
      }
      return totalHeight.clamp(120.0, 600.0);
    }

    if (compilation.params.isNotEmpty) {
      final rows = (compilation.params.length / 4.0).ceil();
      return (rows * 72.0 + 20.0).clamp(120.0, 600.0);
    }

    return 160.0;
  }

  /// Automatically calculates the optimal proportional window dimensions
  /// matching the instrument layout with zero vertical or horizontal padding.
  void fitFloatingWindowToWorkspace(Size workspaceSize, [TrackChannel? track]) {
    _isFloatingWindowMaximized = false;
    final targetTrack = track ?? floatingInstrumentTrack ?? activeTrack;
    final naturalContentHeight = getTrackNaturalGuiHeight(targetTrack);

    final availW = math.max(280.0, workspaceSize.width - 16.0);
    final availH = math.max(160.0, workspaceSize.height - 16.0);

    const contentW = 520.0;
    final contentH = naturalContentHeight;
    const titlebarH = 38.0;

    final scaleW = availW / contentW;
    final scaleH = (availH - titlebarH) / contentH;
    final scale = math.min(scaleW, scaleH).clamp(0.4, 1.4);

    final targetW = (contentW * scale).clamp(260.0, availW);
    final targetH = (contentH * scale + titlebarH).clamp(140.0, availH);

    _floatingWindowSize = Size(targetW, targetH);
    final posX = ((workspaceSize.width - targetW) / 2.0).clamp(0.0, math.max(0.0, workspaceSize.width - targetW)).toDouble();
    final posY = ((workspaceSize.height - targetH) / 2.0).clamp(0.0, math.max(0.0, workspaceSize.height - targetH)).toDouble();
    _floatingWindowPosition = Offset(posX, posY);
    notifyListeners();
  }

  /// Toggles maximizing the floating window across the full workspace area.
  void toggleMaximizeFloatingWindow(Size workspaceSize) {
    if (_isFloatingWindowMaximized) {
      _isFloatingWindowMaximized = false;
      _floatingWindowPosition = _preMaximizedPosition;
      _floatingWindowSize = _preMaximizedSize;
    } else {
      _preMaximizedPosition = _floatingWindowPosition;
      _preMaximizedSize = _floatingWindowSize;
      _isFloatingWindowMaximized = true;

      const pad = 4.0;
      final maxW = math.max(300.0, workspaceSize.width - (pad * 2));
      final maxH = math.max(220.0, workspaceSize.height - (pad * 2));
      _floatingWindowPosition = const Offset(pad, pad);
      _floatingWindowSize = Size(maxW, maxH);
    }
    notifyListeners();
  }

  void updateFloatingWindowPosition(Offset delta, {Size? parentBounds}) {
    _isFloatingWindowMaximized = false;
    double newX = _floatingWindowPosition.dx + delta.dx;
    double newY = _floatingWindowPosition.dy + delta.dy;
    if (parentBounds != null) {
      newX = newX.clamp(0.0, math.max(0.0, parentBounds.width - 100));
      newY = newY.clamp(0.0, math.max(0.0, parentBounds.height - 60));
    } else {
      newX = math.max(0.0, newX);
      newY = math.max(0.0, newY);
    }
    _floatingWindowPosition = Offset(newX, newY);
    notifyListeners();
  }

  void updateFloatingWindowSize(Offset delta) {
    _isFloatingWindowMaximized = false;
    final newW = (_floatingWindowSize.width + delta.dx).clamp(280.0, 1400.0);
    final newH = (_floatingWindowSize.height + delta.dy).clamp(180.0, 1000.0);
    _floatingWindowSize = Size(newW, newH);
    notifyListeners();
  }

  void setFloatingWindowScale(double scale) {
    _floatingWindowScale = scale.clamp(0.6, 1.6);
    notifyListeners();
  }

  // Header Master Meter / CPU Meter Display State
  bool _showCpuMeter = false;
  bool get showCpuMeter => _showCpuMeter;
  void toggleCpuMeter() {
    _showCpuMeter = !_showCpuMeter;
    notifyListeners();
  }

  // Session Persistence & Auto-Restore Settings
  bool _autoRestoreSession = true;
  bool get autoRestoreSession => _autoRestoreSession;
  set autoRestoreSession(bool val) {
    _autoRestoreSession = val;
    EatsStorageHelper.setBool(EatsStorageHelper.keyAutoRestoreSession, val);
    notifyListeners();
  }

  bool _autoSaveEnabled = true;
  bool get autoSaveEnabled => _autoSaveEnabled;
  set autoSaveEnabled(bool val) {
    _autoSaveEnabled = val;
    EatsStorageHelper.setBool(EatsStorageHelper.keyAutoSaveEnabled, val);
    notifyListeners();
  }

  Timer? _autoSaveDebounceTimer;

  void triggerAutoSave() {
    if (_isDisposed || !_autoSaveEnabled || isTestEnvironment) return;
    _autoSaveDebounceTimer?.cancel();
    _autoSaveDebounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (_isDisposed) return;
      try {
        final luaScript = exportToEatsLua();
        await EatsStorageHelper.saveSessionLua(luaScript);
        debugPrint('DawState: Autosaved session (${luaScript.length} chars)');
      } catch (e) {
        debugPrint('DawState: Autosave error: $e');
      }
    });
  }

  Future<void> saveSessionNow() async {
    if (_isDisposed || !_autoSaveEnabled) return;
    _autoSaveDebounceTimer?.cancel();
    try {
      final luaScript = exportToEatsLua();
      await EatsStorageHelper.saveSessionLua(luaScript);
      debugPrint('DawState: Immediate saved session (${luaScript.length} chars)');
    } catch (e) {
      debugPrint('DawState: Immediate save error: $e');
    }
  }

  Future<void> loadPersistedSettings() async {
    try {
      final themeName = await EatsStorageHelper.getString(EatsStorageHelper.keyThemePreset);
      if (themeName != null) {
        for (final p in EatsThemePreset.values) {
          if (p.name == themeName) {
            EatsTheme.currentPreset = p;
            break;
          }
        }
      }

      final scale = await EatsStorageHelper.getDouble(EatsStorageHelper.keyUiScale);
      if (scale != null && scale >= 0.70 && scale <= 1.30) {
        _uiScale = (scale * 100).roundToDouble() / 100;
        uiScaleNotifier.value = _uiScale;
      }

      final autoRestore = await EatsStorageHelper.getBool(EatsStorageHelper.keyAutoRestoreSession);
      if (autoRestore != null) {
        _autoRestoreSession = autoRestore;
      }

      final autoSave = await EatsStorageHelper.getBool(EatsStorageHelper.keyAutoSaveEnabled);
      if (autoSave != null) {
        _autoSaveEnabled = autoSave;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('DawState: Error loading persisted settings: $e');
    }
  }

  Future<bool> restoreSavedSession() async {
    try {
      final savedLua = await EatsStorageHelper.loadSessionLua();
      if (savedLua != null && savedLua.trim().isNotEmpty) {
        loadFromEatsLua(savedLua);
        debugPrint('DawState: Restored saved session successfully.');
        return true;
      }
    } catch (e) {
      debugPrint('DawState: Error restoring saved session: $e');
    }
    return false;
  }

  Future<void> clearSavedSession() async {
    await EatsStorageHelper.clearSessionLua();
    debugPrint('DawState: Cleared saved session.');
  }

  bool isBrowserOpen = false;
  int browserTabIndex = 0;

  void toggleBrowser() {
    isBrowserOpen = !isBrowserOpen;
    notifyListeners();
  }

  void applyPreset(LuaPreset preset, {TrackChannel? targetTrack}) {
    final track = targetTrack ?? activeTrack;
    if (preset.isInstrument) {
      track.name = preset.name;
      track.type = TrackType.luaScript;
      track.luaScriptCode = preset.code;
      final compiled = LuaEngine.compile(preset.code);
      track.luaParams.clear();
      for (final p in compiled.params) {
        track.luaParams[p.name] = p.defaultValue;
      }
      if (track.id == activeTrack.id) {
        luaCode = preset.code;
        compilationResult = compiled;
      }
      audioEngine.invalidateLuaCache(track.id);
      recordHistory('Applied instrument "${preset.name}" to ${track.name}', icon: Icons.piano);
    } else if (preset.isAudioFx) {
      addAudioFXFromPreset(track, preset);
      return;
    } else if (preset.isMidiFx) {
      addMidiFXInsert(
        track,
        name: preset.name,
        luaScriptCode: preset.code,
      );
      recordHistory('Add MIDI FX "${preset.name}" to ${track.name}', icon: Icons.music_note);
    } else if (preset.isMidiSeq) {
      if (activeClip != null && activeClip!.trackId == track.id) {
        applyPresetToClip(track, activeClip!, preset);
      } else if (track.clips.isNotEmpty) {
        applyPresetToClip(track, track.clips.first, preset);
      }
    } else {
      track.luaScriptCode = preset.code;
      compileLuaCode(preset.code);
    }
    notifyListeners();
  }

  bool isPresetUpgradeAvailable(TrackChannel track) {
    if (track.type != TrackType.luaScript && track.luaScriptCode.trim().isEmpty) {
      return false;
    }
    return LuaPresetLibrary.isUpgradeAvailable(track.luaScriptCode, trackName: track.name);
  }

  List<TrackChannel> get tracks => activePattern.tracks;

  int get availablePresetUpgradeCount {
    int count = 0;
    for (final track in tracks) {
      if (isPresetUpgradeAvailable(track)) count++;
    }
    return count;
  }

  void upgradeTrackPreset(TrackChannel track) {
    final preset = LuaPresetLibrary.findMatchingPreset(track.luaScriptCode, fallbackName: track.name);
    if (preset == null) return;

    beginHistoryTransaction('Upgrade ${track.name} to latest preset', icon: Icons.upgrade);

    final oldParams = Map<String, double>.from(track.luaParams);
    track.luaScriptCode = preset.code;
    track.type = TrackType.luaScript;
    final compiled = LuaEngine.compile(preset.code);

    final newParams = <String, double>{};
    for (final p in compiled.params) {
      newParams[p.name] = oldParams[p.name] ?? p.defaultValue;
    }
    track.luaParams = newParams;

    if (track.id == activeTrack.id) {
      luaCode = preset.code;
      compilationResult = compiled;
    }

    audioEngine.invalidateLuaCache(track.id);
    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();
  }

  void upgradeAllTrackPresets() {
    final upgradableTracks = tracks.where(isPresetUpgradeAvailable).toList();
    if (upgradableTracks.isEmpty) return;

    beginHistoryTransaction('Upgrade ${upgradableTracks.length} tracks to latest presets', icon: Icons.auto_awesome);

    for (final track in upgradableTracks) {
      final preset = LuaPresetLibrary.findMatchingPreset(track.luaScriptCode, fallbackName: track.name);
      if (preset != null) {
        final oldParams = Map<String, double>.from(track.luaParams);
        track.luaScriptCode = preset.code;
        track.type = TrackType.luaScript;
        final compiled = LuaEngine.compile(preset.code);

        final newParams = <String, double>{};
        for (final p in compiled.params) {
          newParams[p.name] = oldParams[p.name] ?? p.defaultValue;
        }
        track.luaParams = newParams;

        if (track.id == activeTrack.id) {
          luaCode = preset.code;
          compilationResult = compiled;
        }
        audioEngine.invalidateLuaCache(track.id);
      }
    }

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();
  }

  void addNewPresetTrack(LuaPreset preset) {
    if (!preset.isInstrument) {
      debugPrint('DawState: Cannot create a new track from non-instrument preset "${preset.name}" (${preset.category.displayName})');
      return;
    }

    final trackId = 'track_${DateTime.now().millisecondsSinceEpoch}';
    final trackColors = [
      const Color(0xFF21F4E8),
      const Color(0xFFFF8C00),
      const Color(0xFF00FF66),
      const Color(0xFFFF0055),
      const Color(0xFFBD00FF),
    ];
    final color = trackColors[activePattern.tracks.length % trackColors.length];

    final compiled = LuaEngine.compile(preset.code);
    final initialParams = <String, double>{};
    for (final p in compiled.params) {
      initialParams[p.name] = p.defaultValue;
    }

    final newTrack = TrackChannel(
      id: trackId,
      name: preset.name,
      type: TrackType.luaScript,
      color: color,
      luaScriptCode: preset.code,
      luaParams: initialParams,
    );

    final clip = TrackClip(
      id: 'clip_${trackId}_0',
      name: preset.name,
      trackId: trackId,
      startBar: 0,
      barLength: 2,
    );

    newTrack.clips.add(clip);
    activePattern.tracks.add(newTrack);
    _activeTrackIndex = activePattern.tracks.length - 1;
    luaCode = preset.code;
    compilationResult = compiled;
    activeClip = null;
    recordHistory('Added track "${preset.name}"', icon: Icons.add);
    notifyListeners();
  }

  void changeTrackSoundFont(TrackChannel track, String fontId, {String? displayName, bool renameTrack = false}) {
    track.sampleName = fontId;
    if (renameTrack && displayName != null && displayName.isNotEmpty) {
      track.name = displayName;
    }
    track.luaParams['PresetNum'] = 0.0;
    track.luaParams['BankNum'] = 0.0;
    final sfPreset = LuaPresetLibrary.presets.firstWhere(
      (p) => p.id == 'soundfont_sampler',
      orElse: () => LuaPresetLibrary.presets.first,
    );
    track.luaScriptCode = sfPreset.code;
    compileLuaCode(sfPreset.code);
    notifyListeners();
  }

  void applySoundFont(String fontId, {String? displayName, TrackChannel? targetTrack, bool renameTrack = false}) {
    final track = targetTrack ?? activeTrack;
    changeTrackSoundFont(track, fontId, displayName: displayName, renameTrack: renameTrack);
  }

  void addNewSoundFontTrack(String fontId, {String? displayName}) {
    final sfPreset = LuaPresetLibrary.presets.firstWhere(
      (p) => p.id == 'soundfont_sampler',
      orElse: () => LuaPresetLibrary.presets.first,
    );

    final trackId = 'track_${DateTime.now().millisecondsSinceEpoch}';
    final trackColors = [
      const Color(0xFF21F4E8),
      const Color(0xFFFF8C00),
      const Color(0xFF00FF66),
      const Color(0xFFFF0055),
      const Color(0xFFBD00FF),
    ];
    final color = trackColors[activePattern.tracks.length % trackColors.length];
    final name = displayName ?? fontId.replaceAll('.sf2', '').replaceAll('_', ' ');

    final newTrack = TrackChannel(
      id: trackId,
      name: name,
      type: TrackType.luaScript,
      color: color,
      sampleName: fontId,
      luaScriptCode: sfPreset.code,
    );

    final clip = TrackClip(
      id: 'clip_${trackId}_0',
      name: name,
      trackId: trackId,
      startBar: 0,
      barLength: 2,
    );

    newTrack.clips.add(clip);
    activePattern.tracks.add(newTrack);
    activeTrackIndex = activePattern.tracks.length - 1;
    compileLuaCode(sfPreset.code);
    notifyListeners();
  }

  // ── Automation Lane Management ─────────────────────────────────────────────

  void addTrackAutomationLane(TrackChannel track, AutomationTarget target) {
    final lane = AutomationLane(
      id: 'auto_${DateTime.now().millisecondsSinceEpoch}_${target.id.replaceAll('.', '_')}',
      name: '${track.name} ${target.name}',
      target: target,
      points: [
        AutomationPoint(
          id: 'pt_0',
          step: 0.0,
          value: target.defaultValue,
          easing: target.isDiscrete ? EasingType.step : EasingType.linear,
        ),
      ],
    );
    track.automationLanes.add(lane);
    recordHistory('Added Automation: ${target.name}', icon: Icons.tune);
    triggerAutoSave();
    notifyListeners();
  }

  void removeTrackAutomationLane(TrackChannel track, String laneId) {
    track.automationLanes.removeWhere((l) => l.id == laneId);
    recordHistory('Removed Automation Lane', icon: Icons.delete_outline);
    triggerAutoSave();
    notifyListeners();
  }

  void setAutomationPoint(
    AutomationLane lane,
    double step,
    double value, {
    EasingType easing = EasingType.linear,
    double tension = 0.0,
  }) {
    final existingIdx = lane.points.indexWhere((p) => (p.step - step).abs() < 0.05);
    if (existingIdx != -1) {
      lane.points[existingIdx] = lane.points[existingIdx].copyWith(
        value: value,
        easing: easing,
        tension: tension,
      );
    } else {
      lane.points.add(AutomationPoint(
        id: 'pt_${DateTime.now().millisecondsSinceEpoch}',
        step: step,
        value: value,
        easing: easing,
        tension: tension,
      ));
    }
    lane.points.sort((a, b) => a.step.compareTo(b.step));
    triggerAutoSave();
    notifyListeners();
  }

  void removeAutomationPoint(AutomationLane lane, String pointId) {
    lane.points.removeWhere((p) => p.id == pointId);
    triggerAutoSave();
    notifyListeners();
  }

  void setAutomationScript(AutomationLane lane, String luaCode) {
    lane.luaScriptCode = luaCode;
    lane.isCustomLua = luaCode.trim().isNotEmpty;
    triggerAutoSave();
    notifyListeners();
  }

  void setThemePreset(EatsThemePreset preset) {
    EatsTheme.currentPreset = preset;
    EatsStorageHelper.setString(EatsStorageHelper.keyThemePreset, preset.name);
    notifyListeners();
  }

  void applyLuaTheme(Map<String, dynamic> themeConfig) {
    if (themeConfig.containsKey('preset')) {
      final pName = themeConfig['preset']?.toString();
      for (final p in EatsThemePreset.values) {
        if (p.name == pName) {
          setThemePreset(p);
          break;
        }
      }
    }
    notifyListeners();
  }



  // Playback & Clock State
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  void toggleRecord() {
    _isRecording = !_isRecording;
    notifyListeners();
  }

  bool _isSongMode = false;
  bool get isSongMode => _isSongMode;
  set isSongMode(bool val) {
    _isSongMode = val;
    notifyListeners();
  }

  double _bpm = 124.0;
  double get bpm => _bpm;

  int _currentStep = 0;
  int get currentStep => _currentStep;
  final ValueNotifier<int> currentStepNotifier = ValueNotifier<int>(0);

  int _currentBar = 0;
  int get currentBar => _currentBar;
  final ValueNotifier<int> currentBarNotifier = ValueNotifier<int>(0);

  double _masterVolume = 0.85;
  double get masterVolume => _masterVolume;

  void resetActiveIndices() {
    _activePatternIndex = 0;
    _activeTrackIndex = 0;
    if (activeTrack.clips.isNotEmpty) {
      activeClip = activeTrack.clips.first;
    }
    if (activeTrack.luaScriptCode.isNotEmpty) {
      luaCode = activeTrack.luaScriptCode;
      compilationResult = LuaEngine.compile(luaCode);
    }
    notifyListeners();
  }

  String exportToEatsLua() {
    return EatsLuaSerializer.serialize(this, projectName: projectName);
  }

  /// Computes a fast O(N) integer fingerprint of active song state
  /// to eliminate expensive full-string serializations on duplicate history triggers.
  int computeStateFingerprint() {
    int h = _bpm.hashCode ^ _songKey.hashCode ^ _masterVolume.hashCode ^ projectName.hashCode ^ authorName.hashCode;
    for (final pattern in patterns) {
      h = (h * 31) ^ pattern.id.hashCode;
      for (final track in pattern.tracks) {
        h = (h * 31) ^ track.id.hashCode ^ (track.volume * 100).round() ^ (track.pan * 100).round() ^ (track.isMuted ? 1 : 0) ^ (track.isSoloed ? 2 : 0) ^ track.color.value;
        for (final entry in track.luaParams.entries) {
          h = (h * 31) ^ entry.key.hashCode ^ (entry.value * 100).round();
        }
        for (final clip in track.clips) {
          h = (h * 31) ^ clip.id.hashCode ^ clip.startBar ^ clip.barLength;
          for (final note in clip.notes) {
            h = (h * 31) ^ note.id.hashCode ^ note.pitch ^ (note.startStep * 100).round() ^ (note.durationSteps * 100).round() ^ (note.velocity * 100).round() ^ (note.isSlide ? 1 : 0) ^ (note.isAccent ? 2 : 0);
          }
        }
      }
    }
    for (final chord in chordTrack) {
      h = (h * 31) ^ chord.id.hashCode ^ chord.rootPitchClass ^ chord.quality.index ^ (chord.startBar * 10).round() ^ (chord.barLength * 10).round();
    }
    return h;
  }

  void loadFromEatsLua(String eatsLuaCode) {
    history.pauseRecording();
    try {
      projectName = EatsLuaParser.populateDawState(this, eatsLuaCode);
      resetActiveIndices();
    } finally {
      history.resumeRecording();
    }
    triggerAutoSave();
  }

  Timer? _playbackTimer;

  // Tap Tempo state
  final List<DateTime> _tapTimes = [];

  // Patterns & Tracks
  List<Pattern> patterns = [];
  int _activePatternIndex = 0;
  int get activePatternIndex => _activePatternIndex;

  Pattern get activePattern => patterns.isNotEmpty
      ? patterns[_activePatternIndex.clamp(0, patterns.length - 1)]
      : Pattern(id: 'p0', name: 'Pattern 1', tracks: []);

  int _activeTrackIndex = 0;
  int get activeTrackIndex => _activeTrackIndex;
  TrackChannel get activeTrack => (activePattern.tracks.isNotEmpty)
      ? activePattern.tracks[_activeTrackIndex.clamp(0, activePattern.tracks.length - 1)]
      : TrackChannel(id: 'dummy', name: 'Track', color: const Color(0xFF00E5FF), type: TrackType.synth);

  set activeTrackIndex(int index) {
    final newIndex = index.clamp(0, activePattern.tracks.length - 1);
    _activeTrackIndex = newIndex;
    activeClip = null;
    if (activeTrack.luaScriptCode.isNotEmpty) {
      luaCode = activeTrack.luaScriptCode;
      compilationResult = LuaEngine.compile(luaCode);
      for (final p in compilationResult.params) {
        activeTrack.luaParams.putIfAbsent(p.name, () => p.defaultValue);
      }
    } else {
      luaCode = '';
      compilationResult = LuaCompilationResult(
        isSuccess: true,
        errorMessage: 'No active Lua script on channel',
        params: [],
        scriptType: 'synth',
      );
    }
    notifyListeners();
  }

  // Song Arrangement
  List<ArrangementItem> arrangement = [
    ArrangementItem(patternId: 'p0', startBar: 0, barLength: 2),
    ArrangementItem(patternId: 'p1', startBar: 2, barLength: 2),
  ];

  // Lua Editor Active Code & Logs
  String luaCode = LuaPresetLibrary.presets.first.code;
  LuaCompilationResult compilationResult = LuaEngine.compile(LuaPresetLibrary.presets.first.code);

  static bool get isTestEnvironment => PlatformEnvHelper.isFlutterTest;

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  late final TrackChannel masterTrack;

  DawState({bool? enableMeterTimer}) {
    masterTrack = TrackChannel(
      id: 'master_bus',
      name: 'Master',
      type: TrackType.synth,
      color: EatsTheme.primaryCyan,
      volume: _masterVolume,
    );
    SoundFontEngine.instance.loadDefaultBundledFont();
    _initDemoTracks();
    history.init(this, initialDescription: 'Project Started');
    final shouldStartTimer = enableMeterTimer ?? !isTestEnvironment;
    if (shouldStartTimer) {
      _startMeterTimer();
    }
  }

  // History & Time Travel convenience methods
  bool undo() => history.undo(this);
  bool redo() => history.redo(this);
  void recordHistory(
    String description, {
    IconData icon = Icons.edit,
    bool isMilestone = false,
    String? milestoneName,
    bool force = false,
  }) {
    history.record(
      this,
      description,
      icon: icon,
      isMilestone: isMilestone,
      milestoneName: milestoneName,
      force: force,
    );
    triggerAutoSave();
  }
  void beginHistoryTransaction(String description, {IconData icon = Icons.tune}) =>
      history.beginTransaction(this, description, icon: icon);
  void commitHistoryTransaction() => history.commitTransaction(this);
  void cancelHistoryTransaction() => history.cancelTransaction();

  Timer? _meterTimer;

  void _startMeterTimer() {
    _meterTimer?.cancel();
    _meterTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_isPlaying || audioEngine.hasActiveMeterActivity) {
        audioEngine.updateMeters();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoSaveDebounceTimer?.cancel();
    if (_autoSaveEnabled && !isTestEnvironment) {
      try {
        final luaScript = exportToEatsLua();
        EatsStorageHelper.saveSessionLua(luaScript);
      } catch (_) {}
    }
    _meterTimer?.cancel();
    _playbackTimer?.cancel();
    isPlayingNotifier.dispose();
    currentStepNotifier.dispose();
    currentBarNotifier.dispose();
    arrangerStepNotifier.dispose();
    history.dispose();
    audioEngine.setMasterVolume(0.0);
    super.dispose();
  }

  void _initDemoTracks() {
    loadFromEatsLua(DefaultSong.midnightBitesLua);
  }

  // Script Target & Project Script Management
  ScriptTarget? _activeScriptTarget;

  ScriptTarget get activeScriptTarget {
    final targets = getAllScriptTargets();
    if (targets.isEmpty) {
      return ScriptTarget(
        id: 'track_${activeTrack.id}_dsp',
        type: ScriptTargetType.trackDsp,
        title: '${activeTrack.name} (Synth DSP)',
        subtitle: 'Channel Instrument Script',
        trackId: activeTrack.id,
        trackName: activeTrack.name,
        trackColor: activeTrack.color,
      );
    }
    if (_activeScriptTarget != null) {
      final existing = targets.where((t) => t.id == _activeScriptTarget!.id).firstOrNull;
      if (existing != null) return existing;
    }
    final trackTarget = targets.where((t) => t.trackId == activeTrack.id && t.type == ScriptTargetType.trackDsp).firstOrNull;
    return trackTarget ?? targets.first;
  }

  set activeScriptTarget(ScriptTarget target) {
    selectScriptTarget(target);
  }

  List<ScriptTarget> getAllScriptTargets() {
    final list = <ScriptTarget>[];
    for (final track in activePattern.tracks) {
      // 1. Track DSP / Synth Script
      list.add(
        ScriptTarget(
          id: 'track_${track.id}_dsp',
          type: ScriptTargetType.trackDsp,
          title: '${track.name} (Synth DSP)',
          subtitle: track.luaScriptCode.isNotEmpty ? 'Custom Lua Synth / DSP' : 'Instrument DSP Script',
          trackId: track.id,
          trackName: track.name,
          trackColor: track.color,
        ),
      );

      // 2. Track Audio FX Scripts
      for (final fx in track.fxRack) {
        if (fx.luaScriptCode?.isNotEmpty ?? false) {
          list.add(
            ScriptTarget(
              id: 'fx_${track.id}_${fx.id}',
              type: ScriptTargetType.audioFx,
              title: '${fx.name} (${track.name})',
              subtitle: 'Audio FX Insert Module',
              trackId: track.id,
              trackName: track.name,
              trackColor: track.color,
              secondaryId: fx.id,
            ),
          );
        }
      }

      // 3. Track MIDI FX Modules
      for (final mfx in track.midiFXRack) {
        list.add(
          ScriptTarget(
            id: 'mfx_${track.id}_${mfx.id}',
            type: ScriptTargetType.midiFx,
            title: '${mfx.name} (${track.name})',
            subtitle: 'MIDI FX Insert Module',
            trackId: track.id,
            trackName: track.name,
            trackColor: track.color,
            secondaryId: mfx.id,
          ),
        );
      }

      // 4. Track Clip Scripts
      for (final clip in track.clips) {
        list.add(
          ScriptTarget(
            id: 'clip_${track.id}_${clip.id}',
            type: ScriptTargetType.clipScript,
            title: '${clip.name.isNotEmpty ? clip.name : "Clip"} (${track.name})',
            subtitle: 'Generative Clip / Sequence Script',
            trackId: track.id,
            trackName: track.name,
            trackColor: track.color,
            secondaryId: clip.id,
            clipName: clip.name,
          ),
        );
      }
    }

    // 5. Master Bus Audio FX Scripts
    for (final fx in masterTrack.fxRack) {
      if (fx.luaScriptCode?.isNotEmpty ?? false) {
        list.add(
          ScriptTarget(
            id: 'fx_${masterTrack.id}_${fx.id}',
            type: ScriptTargetType.audioFx,
            title: '${fx.name} (Master)',
            subtitle: 'Master Bus Audio FX',
            trackId: masterTrack.id,
            trackName: masterTrack.name,
            trackColor: masterTrack.color,
            secondaryId: fx.id,
          ),
        );
      }
    }
    return list;
  }

  TrackChannel _getTrackForScriptTarget(ScriptTarget target) {
    if (target.trackId == masterTrack.id) return masterTrack;
    return activePattern.tracks.where((t) => t.id == target.trackId).firstOrNull ?? activeTrack;
  }

  String getScriptCodeForTarget(ScriptTarget target) {
    final track = _getTrackForScriptTarget(target);
    switch (target.type) {
      case ScriptTargetType.trackDsp:
        return track.luaScriptCode;
      case ScriptTargetType.audioFx:
        final fx = track.fxRack.where((f) => f.id == target.secondaryId).firstOrNull;
        return fx?.luaScriptCode ?? '';
      case ScriptTargetType.midiFx:
        final mfx = track.midiFXRack.where((f) => f.id == target.secondaryId).firstOrNull;
        return mfx?.luaScriptCode ?? '';
      case ScriptTargetType.clipScript:
        final clip = track.clips.where((c) => c.id == target.secondaryId).firstOrNull;
        return clip?.luaScriptCode ?? '';
    }
  }

  Map<String, double> getScriptParamsForTarget(ScriptTarget target) {
    final track = _getTrackForScriptTarget(target);
    switch (target.type) {
      case ScriptTargetType.trackDsp:
        return track.luaParams;
      case ScriptTargetType.audioFx:
        final fx = track.fxRack.where((f) => f.id == target.secondaryId).firstOrNull;
        return fx?.luaParams ?? {};
      case ScriptTargetType.midiFx:
        final mfx = track.midiFXRack.where((f) => f.id == target.secondaryId).firstOrNull;
        return mfx?.luaParams ?? {};
      case ScriptTargetType.clipScript:
        final clip = track.clips.where((c) => c.id == target.secondaryId).firstOrNull;
        return clip?.luaParams ?? {};
    }
  }

  void updateScriptParamForTarget(ScriptTarget target, String paramName, double value) {
    final track = _getTrackForScriptTarget(target);
    switch (target.type) {
      case ScriptTargetType.trackDsp:
        track.luaParams[paramName] = value;
        break;
      case ScriptTargetType.audioFx:
        updateFXParam(track, target.secondaryId ?? '', paramName, value);
        return;
      case ScriptTargetType.midiFx:
        updateMidiFXParam(track, target.secondaryId ?? '', paramName, value);
        return;
      case ScriptTargetType.clipScript:
        final clip = track.clips.where((c) => c.id == target.secondaryId).firstOrNull;
        if (clip != null) {
          clip.luaParams[paramName] = value;
          final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
          pipeline.processClip(clip: clip, track: track, timeContext: timeContext);
        }
        break;
    }
    notifyListeners();
  }

  void selectScriptTarget(ScriptTarget target) {
    _activeScriptTarget = target;
    final tIdx = activePattern.tracks.indexWhere((t) => t.id == target.trackId);
    if (tIdx != -1 && tIdx != _activeTrackIndex) {
      _activeTrackIndex = tIdx;
    }
    luaCode = getScriptCodeForTarget(target);
    compilationResult = LuaEngine.compile(luaCode);
    notifyListeners();
  }

  void openScriptInEditor(ScriptTarget target) {
    selectScriptTarget(target);
    _activeTabIndex = 4; // Navigate to SCRIPTS tab
    notifyListeners();
  }

  // Lua Engine Compilation & Hot Swap across all script types
  void compileScriptTarget(ScriptTarget target, String code) {
    // 1. SAVE STATE BEFORE RECOMPILING FOR HISTORY MANAGER
    recordHistory('Compile ${target.typeBadge}: ${target.title}', icon: Icons.code, force: true);

    luaCode = code;
    compilationResult = LuaEngine.compile(code);

    final track = _getTrackForScriptTarget(target);

    if (compilationResult.isSuccess) {
      switch (target.type) {
        case ScriptTargetType.trackDsp:
          track.luaScriptCode = code;
          track.type = TrackType.luaScript;
          final newParams = <String, double>{};
          for (final p in compilationResult.params) {
            newParams[p.name] = track.luaParams[p.name] ?? p.defaultValue;
          }
          track.luaParams = newParams;
          audioEngine.invalidateLuaCache(track.id);
          break;

        case ScriptTargetType.audioFx:
          final fx = track.fxRack.where((f) => f.id == target.secondaryId).firstOrNull;
          if (fx != null) {
            fx.luaScriptCode = code;
            final newParams = <String, double>{};
            for (final p in compilationResult.params) {
              newParams[p.name] = fx.luaParams[p.name] ?? p.defaultValue;
            }
            fx.luaParams = newParams;
            _syncFxAudio(track);
          }
          break;

        case ScriptTargetType.midiFx:
          final mfx = track.midiFXRack.where((f) => f.id == target.secondaryId).firstOrNull;
          if (mfx != null) {
            mfx.luaScriptCode = code;
            final newParams = <String, double>{};
            for (final p in compilationResult.params) {
              newParams[p.name] = mfx.luaParams[p.name] ?? p.defaultValue;
            }
            mfx.luaParams = newParams;
          }
          break;

        case ScriptTargetType.clipScript:
          final clip = track.clips.where((c) => c.id == target.secondaryId).firstOrNull;
          if (clip != null) {
            clip.luaScriptCode = code;
            final newParams = <String, double>{};
            for (final p in compilationResult.params) {
              newParams[p.name] = clip.luaParams[p.name] ?? p.defaultValue;
            }
            clip.luaParams = newParams;
            final parsedNotes = MidiPipelineEngine.parseNotesFromLuaTable(code);
            if (parsedNotes.isNotEmpty) {
              clip.notes = parsedNotes;
              track.notes = parsedNotes;
            }
            final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
            pipeline.processClip(clip: clip, track: track, timeContext: timeContext);
          }
          break;
      }
    }
    notifyListeners();
  }

  void compileLuaCode(String code) {
    compileScriptTarget(activeScriptTarget, code);
  }

  TrackClip? activeClip;

  void openClipInEditor(TrackClip clip) {
    activeClip = clip;
    final tIdx = activePattern.tracks.indexWhere((t) => t.id == clip.trackId);
    if (tIdx != -1) {
      _activeTrackIndex = tIdx;
    }
    _activeTabIndex = 1; // Switch to EDIT tab
    notifyListeners();
  }

  void addClipToTrack(TrackChannel track, int startBar) {
    final newClip = TrackClip(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: '${track.name} Clip',
      trackId: track.id,
      startBar: startBar,
      barLength: 2,
      notes: track.notes.map((n) => n.copyWith()).toList(),
      luaScriptCode: '',
      luaParams: {},
    );
    track.clips.add(newClip);
    activeClip = newClip;
    recordHistory('Add Clip to ${track.name} (Bar ${startBar + 1})', icon: Icons.view_timeline);
    notifyListeners();
  }

  void deleteClip(TrackChannel track, TrackClip clip) {
    final idx = track.clips.indexWhere((c) => c.id == clip.id);
    if (idx != -1) {
      track.clips.removeAt(idx);
      if (activeClip?.id == clip.id) {
        activeClip = track.clips.isNotEmpty ? track.clips.first : null;
      }
      recordHistory('Delete Clip "${clip.name}" from ${track.name}', icon: Icons.delete_outline);
      notifyListeners();
    }
  }

  void duplicateClip(TrackChannel track, TrackClip clip) {
    final newStartBar = clip.startBar + clip.barLength;
    final duplicated = TrackClip(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: '${clip.name} (Copy)',
      trackId: track.id,
      startBar: newStartBar,
      barLength: clip.barLength,
      notes: clip.notes.map((n) => n.copyWith()).toList(),
      luaScriptCode: clip.luaScriptCode,
      luaParams: Map.from(clip.luaParams),
    );
    track.clips.add(duplicated);
    activeClip = duplicated;
    recordHistory('Duplicate Clip "${clip.name}"', icon: Icons.copy);
    notifyListeners();
  }

  void renameClip(TrackClip clip, String newName) {
    if (newName.trim().isNotEmpty && clip.name != newName.trim()) {
      clip.name = newName.trim();
      recordHistory('Rename Clip to "${clip.name}"', icon: Icons.edit);
      notifyListeners();
    }
  }

  void setTrackClipStartBar(TrackClip clip, int startBar) {
    clip.startBar = startBar.clamp(0, 128);
    recordHistory('Move Clip "${clip.name}" to Bar ${clip.startBar + 1}', icon: Icons.drag_handle);
    notifyListeners();
  }

  void toggleTrackMidiFXRack(TrackChannel track, bool enableAll) {
    for (final fx in track.midiFXRack) {
      fx.enabled = enableAll;
    }
    invalidateTrackMidiCache(track);
    recordHistory('${enableAll ? "Enable" : "Bypass"} MIDI FX Rack on ${track.name}', icon: Icons.bolt);
    notifyListeners();
  }

  void toggleTrackAudioFXRack(TrackChannel track, bool enableAll) {
    for (final fx in track.fxRack) {
      fx.enabled = enableAll;
    }
    audioEngine.invalidateLuaCache(track.id);
    recordHistory('${enableAll ? "Enable" : "Bypass"} Audio FX Rack on ${track.name}', icon: Icons.tune);
    notifyListeners();
  }

  void applyPresetToClip(TrackChannel track, TrackClip clip, LuaPreset preset) {
    if (preset.isMidiFx) {
      addMidiFXInsert(
        track,
        name: preset.name,
        luaScriptCode: preset.code,
      );
      recordHistory('Add MIDI FX "${preset.name}" to ${track.name}', icon: Icons.music_note);
      notifyListeners();
      return;
    }

    clip.name = preset.name;
    clip.luaScriptCode = '';

    // Parse notes from sequence script if present
    final parsedNotes = MidiPipelineEngine.parseNotesFromLuaTable(preset.code);
    if (parsedNotes.isNotEmpty) {
      if (clip.barLength > 1) {
        // Tile 1-bar (16 steps) sequence across multi-bar clips
        final List<Note> tiledNotes = [];
        for (int bar = 0; bar < clip.barLength; bar++) {
          final barOffset = bar * 16.0;
          for (final n in parsedNotes) {
            tiledNotes.add(n.copyWith(
              id: 'n_clip_${clip.id}_b${bar}_${n.startStep}',
              startStep: n.startStep + barOffset,
            ));
          }
        }
        clip.notes = tiledNotes;
      } else {
        clip.notes = parsedNotes.map((n) => n.copyWith(id: 'n_clip_${clip.id}_${n.startStep}')).toList();
      }

      // If this clip is the active clip, sync active track notes
      if (activeClip?.id == clip.id) {
        track.notes = clip.notes.map((n) => n.copyWith()).toList();
      }
    }

    // Process clip through MidiPipelineEngine
    final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
    pipeline.processClip(
      clip: clip,
      track: track,
      timeContext: timeContext,
    );

    recordHistory('Apply Sequence "${preset.name}" to Clip', icon: Icons.tune);
    notifyListeners();
  }

  void addClipWithPresetToTrack(TrackChannel track, int startBar, LuaPreset preset, {int barLength = 1}) {
    final parsedNotes = MidiPipelineEngine.parseNotesFromLuaTable(preset.code);
    final clipId = 'c_${DateTime.now().millisecondsSinceEpoch}';
    final List<Note> initialNotes = [];

    if (parsedNotes.isNotEmpty) {
      for (int bar = 0; bar < barLength; bar++) {
        final barOffset = bar * 16.0;
        for (final n in parsedNotes) {
          initialNotes.add(n.copyWith(
            id: 'n_clip_${clipId}_b${bar}_${n.startStep}',
            startStep: n.startStep + barOffset,
          ));
        }
      }
    }

    final newClip = TrackClip(
      id: clipId,
      name: preset.name,
      trackId: track.id,
      startBar: startBar,
      barLength: barLength,
      notes: initialNotes,
      luaScriptCode: '',
      luaParams: {},
    );

    track.clips.add(newClip);
    activeClip = newClip;
    if (activeTrack.id == track.id) {
      track.notes = newClip.notes.map((n) => n.copyWith()).toList();
    }

    final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
    pipeline.processClip(
      clip: newClip,
      track: track,
      timeContext: timeContext,
    );

    recordHistory('Add Clip "${preset.name}" to ${track.name}', icon: Icons.view_timeline);
    notifyListeners();
  }

  void selectClip(TrackClip? clip) {
    activeClip = clip;
    notifyListeners();
  }

  void selectPattern(int index) {
    _activePatternIndex = index.clamp(0, patterns.length - 1);
    notifyListeners();
  }

  void setBpm(double newBpm) {
    _bpm = newBpm.clamp(40.0, 240.0);
    if (_isPlaying) {
      // Step duration changed — re-warm the cache at the new BPM so the
      // restarted scheduler immediately finds correctly-sized buffers.
      final double stepDurationSec = 60.0 / _bpm / 4.0;
      audioEngine.prewarmPatternCache(activePattern.tracks, stepDurationSec);
      _restartTimer();
    }
    recordHistory('Set BPM to ${_bpm.toStringAsFixed(1)}', icon: Icons.speed);
    notifyListeners();
  }

  void tapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 4) _tapTimes.removeAt(0);

    if (_tapTimes.length >= 2) {
      double totalDiffMs = 0;
      for (int i = 1; i < _tapTimes.length; i++) {
        totalDiffMs += _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds;
      }
      final avgDiffMs = totalDiffMs / (_tapTimes.length - 1);
      if (avgDiffMs > 0) {
        setBpm(60000.0 / avgDiffMs);
      }
    }
  }

  void setMasterVolume(double vol) {
    _masterVolume = vol.clamp(0.0, 1.5);
    masterTrack.volume = _masterVolume;
    audioEngine.setMasterVolume(_masterVolume);
    notifyListeners();
  }

  // Loop Points & Arranger Seek State
  int _loopStartBar = 0;
  int get loopStartBar => _loopStartBar;

  int _loopEndBar = 2;
  int get loopEndBar => _loopEndBar;

  bool _isLooping = true;
  bool get isLooping => _isLooping;

  int _arrangerStep = 0;
  int get arrangerStep => _arrangerStep;
  final ValueNotifier<int> arrangerStepNotifier = ValueNotifier<int>(0);

  void setLoopPoints(int startBar, int endBar) {
    _loopStartBar = math.max(0, math.min(startBar, endBar - 1));
    _loopEndBar = math.max(_loopStartBar + 1, endBar);
    _isLooping = true;
    notifyListeners();
  }

  void toggleLoop() {
    _isLooping = !_isLooping;
    notifyListeners();
  }

  void setLooping(bool looping) {
    _isLooping = looping;
    notifyListeners();
  }

  void seekToBar(int bar) {
    final targetBar = bar.clamp(0, 31);
    _currentStep = targetBar * 16;
    _arrangerStep = targetBar * 16;
    _currentBar = targetBar;
    currentStepNotifier.value = _currentStep;
    arrangerStepNotifier.value = _arrangerStep;
    currentBarNotifier.value = _currentBar;
    notifyListeners();
  }

  void seekToArrangerStep(double step) {
    final clamped = step.clamp(0.0, (32 * 16.0) - 1.0);
    _arrangerStep = clamped.toInt();
    _currentStep = clamped.toInt();
    _currentBar = _arrangerStep ~/ 16;
    currentStepNotifier.value = _currentStep;
    arrangerStepNotifier.value = _arrangerStep;
    currentBarNotifier.value = _currentBar;
    notifyListeners();
  }

  double _nextNoteTime = 0.0;
  // Lookahead window: 80ms unified lookahead for tight, responsive audio scheduling.
  double get _scheduleAheadTime => 0.080;

  void togglePlay() {
    audioEngine.ensureContextRunning();
    _isPlaying = !_isPlaying;
    isPlayingNotifier.value = _isPlaying;
    if (_isPlaying) {
      // Pre-warm the PCM cache for every non-slide note in the active pattern
      // BEFORE starting the scheduler. This guarantees the first loop runs
      // entirely from cache (sub-millisecond buffer lookups), making timing
      // consistent from beat 1 rather than only after the first pass.
      final double stepDurationSec = 60.0 / _bpm / 4.0;
      audioEngine.prewarmPatternCache(activePattern.tracks, stepDurationSec);

      _nextNoteTime = audioEngine.currentTime + 0.02;
      _startSchedulerTimer();
    } else {
      _playbackTimer?.cancel();
    }
    notifyListeners();
  }

  /// Stop & Panic: Halts playback, stops all active audio/echo nodes,
  /// clears synthesized note audio caches, and resets playback position.
  void stop() {
    _isPlaying = false;
    isPlayingNotifier.value = false;
    _playbackTimer?.cancel();
    _currentStep = _isLooping ? _loopStartBar * 16 : 0;
    _arrangerStep = _currentStep;
    _currentBar = _currentStep ~/ 16;
    currentStepNotifier.value = _currentStep;
    arrangerStepNotifier.value = _arrangerStep;
    currentBarNotifier.value = _currentBar;
    audioEngine.stopAllSound();
    audioEngine.clearPcmCache();
    TtsEngine().stop();
    notifyListeners();
  }

  /// Panic Button: Instantly halts all playback, stops active sound source nodes,
  /// clears PCM note audio cache and calculations, and resets meters.
  void panic() {
    stop();
  }

  void _startSchedulerTimer() {
    _playbackTimer?.cancel();
    // High frequency 25ms ticker enqueueing notes into WebAudio hardware clock queue
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      _schedulerLoop();
    });
  }

  void _restartTimer() {
    if (_isPlaying) _startSchedulerTimer();
  }

  void _schedulerLoop() {
    if (!_isPlaying) return;

    final double stepDurationSec = 60.0 / _bpm / 4.0; // 16th note step length in seconds
    const int maxSteps = 32 * 16;

    int loopGuard = 0;
    while (_nextNoteTime < audioEngine.currentTime + _scheduleAheadTime) {
      if (++loopGuard > 32) {
        _nextNoteTime = audioEngine.currentTime + 0.02;
        break;
      }
      _scheduleStep(_currentStep, _nextNoteTime, stepDurationSec);
      _nextNoteTime += stepDurationSec;

      _currentStep++;
      if (_isLooping && _currentStep >= _loopEndBar * 16) {
        _currentStep = _loopStartBar * 16;
      } else if (_currentStep >= maxSteps) {
        _currentStep = _isLooping ? _loopStartBar * 16 : 0;
      }

      _arrangerStep = _currentStep;
      _currentBar = _currentStep ~/ 16;
      currentStepNotifier.value = _currentStep;
      arrangerStepNotifier.value = _arrangerStep;
      currentBarNotifier.value = _currentBar;
    }
  }

  void _scheduleStep(int stepIdx, double hardwareTime, double stepDurationSec) {
    final currentPattern = activePattern;
    final hasSolo = currentPattern.tracks.any((t) => t.isSoloed);
    final activeChord = getActiveChordAtStep(stepIdx);
    final pipeline = MidiPipelineEngine(luaEngine: luaEngine);

    for (final track in currentPattern.tracks) {
      if (track.isMuted) continue;
      if (hasSolo && !track.isSoloed) continue;

      int remapPitch(int pitch) {
        if (activeChord != null && track.chordFollowMode != ChordFollowMode.off) {
          return ChordTheory.remapPitchForChord(pitch, activeChord, track.chordFollowMode.name);
        }
        return pitch;
      }

      // Evaluate Track Automation Lanes
      for (final lane in track.automationLanes) {
        if (!lane.enabled) continue;
        final val = LuaEngine.evaluateAutomation(lane: lane, step: stepIdx.toDouble(), timeCtx: timeContext);
        audioEngine.setTrackParam(track.id, lane.target.id, val);
      }

      // Arranger Clip Position Playback Logic
      if (track.clips.isNotEmpty) {
        for (final clip in track.clips) {
          final int clipStartStep = clip.startBar * 16;
          final int clipEndStep = (clip.startBar + clip.barLength) * 16;

          if (stepIdx >= clipStartStep && stepIdx < clipEndStep) {
            final int localStep = stepIdx - clipStartStep;

            // Evaluate Clip Automation Lanes
            for (final lane in clip.automationLanes) {
              if (!lane.enabled) continue;
              final val = LuaEngine.evaluateAutomation(lane: lane, step: localStep.toDouble(), timeCtx: timeContext);
              audioEngine.setTrackParam(track.id, lane.target.id, val);
            }
            
            final List<Note> effectiveNotes = clip.evaluatedNotesCache ??
                (track.midiFXRack.any((f) => f.enabled)
                    ? pipeline.processClip(clip: clip, track: track, timeContext: timeContext)
                    : clip.notes);

            // Trigger TTS speech ONLY if track is a TTS Voice Synth instrument or enabled
            final isTtsInstrument = track.type == TrackType.tts ||
                track.enableTts ||
                track.luaScriptCode.contains('TtsSynth') ||
                track.sampleName.toLowerCase().contains('tts');

            if (isTtsInstrument) {
              final double effPitch = track.luaParams['Pitch'] ?? track.ttsPitch;
              final double effRate = track.luaParams['Rate'] ?? track.ttsRate;
              final double effVol = (track.luaParams['Volume'] ?? track.ttsVolume) * track.volume;

              // 1. Check track-level lyric cues
              final matchingTrackLyrics = track.lyrics.where(
                (l) => l.startStep >= stepIdx && l.startStep < (stepIdx + 1.0),
              );
              for (final cue in matchingTrackLyrics) {
                TtsEngine().speak(
                  cue.phoneticOverride ?? cue.text,
                  voice: track.ttsVoice,
                  pitch: (cue.pitch * effPitch).clamp(0.5, 2.0),
                  rate: (cue.rate * effRate).clamp(0.1, 2.0),
                  volume: effVol.clamp(0.0, 1.0),
                );
              }

              // 2. Check clip-level lyric cues
              final matchingClipLyrics = clip.lyrics.where(
                (l) => l.startStep >= localStep && l.startStep < (localStep + 1.0),
              );
              for (final cue in matchingClipLyrics) {
                TtsEngine().speak(
                  cue.phoneticOverride ?? cue.text,
                  voice: track.ttsVoice,
                  pitch: (cue.pitch * effPitch).clamp(0.5, 2.0),
                  rate: (cue.rate * effRate).clamp(0.1, 2.0),
                  volume: effVol.clamp(0.0, 1.0),
                );
              }

              // 3. Check note-attached lyric syllables
              for (final note in effectiveNotes) {
                if (note.lyric != null &&
                    note.lyric!.isNotEmpty &&
                    note.startStep >= localStep &&
                    note.startStep < (localStep + 1.0)) {
                  final semitoneOffset = (note.pitch - 60) / 12.0;
                  final notePitchMult = math.pow(2.0, semitoneOffset).toDouble();
                  TtsEngine().speak(
                    note.lyric!,
                    voice: track.ttsVoice,
                    pitch: (notePitchMult * effPitch).clamp(0.5, 2.0),
                    rate: effRate.clamp(0.1, 2.0),
                    volume: (note.velocity * effVol).clamp(0.0, 1.0),
                  );
                }
              }
            }

            if (effectiveNotes.isNotEmpty) {
              // Find all notes starting within this 16th step window: [localStep, localStep + 1.0)
              final matchingNotes = effectiveNotes.where(
                (n) => n.startStep >= localStep && n.startStep < (localStep + 1.0),
              ).toList();

              if (matchingNotes.isNotEmpty) {
                if (track.isMonophonicTrack) {
                  final sortedNotes = matchingNotes.toList()..sort((a, b) => a.startStep.compareTo(b.startStep));
                  final hasSlideParam = (track.luaParams['Slide'] ?? 0.0) > 0.01 ||
                      (track.luaParams['Portamento'] ?? 0.0) > 0.01 ||
                      (track.luaParams['Glide'] ?? 0.0) > 0.01;

                  for (int mIdx = 0; mIdx < sortedNotes.length; mIdx++) {
                    final note = sortedNotes[mIdx];
                    final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                    final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);

                    final otherMatching = sortedNotes.where((n) => n != note).toList();
                    final nextNotes = effectiveNotes.where((n) => n.startStep > note.startStep && n.startStep <= (note.startStep + math.max(1.5, note.durationSteps + 0.5))).toList();

                    int? rawTargetPitch;
                    if (otherMatching.isNotEmpty && (mIdx < sortedNotes.length - 1 || sortedNotes.length > 1)) {
                      // Simultaneous notes in pattern sequencer / clip: slide towards the concurrent note
                      final targetSimNote = sortedNotes.last != note ? sortedNotes.last : sortedNotes.first;
                      rawTargetPitch = targetSimNote.pitch;
                    } else if (nextNotes.isNotEmpty) {
                      rawTargetPitch = nextNotes.first.pitch;
                    }

                    final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;

                    final bool hasPrevOverlap = effectiveNotes.any(
                      (n) => n.startStep < note.startStep && (n.startStep + n.durationSteps) > note.startStep,
                    );

                    final bool isSlideNote = note.isSlide ||
                        hasPrevOverlap ||
                        otherMatching.isNotEmpty ||
                        hasSlideParam ||
                        (note.durationSteps > 1.0) ||
                        (nextNotes.isNotEmpty && (note.isSlide || hasSlideParam || note.durationSteps >= 1.0));
                    final bool isAccentNote = note.isAccent || note.velocity > 0.75;
                    final effectiveMidi = remapPitch(note.pitch);

                    audioEngine.playNoteOrSample(
                      track: track,
                      midiNote: effectiveMidi,
                      targetMidiNote: targetPitch,
                      isSlide: isSlideNote,
                      isAccent: isAccentNote,
                      velocity: note.velocity,
                      durationSec: math.max(0.02, note.durationSteps * stepDurationSec),
                      scheduledTime: noteHardwareTime,
                    );
                  }
                } else {
                  // Polyphonic track: schedule all simultaneous / sub-step notes in this window
                  for (final note in matchingNotes) {
                    final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                    final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);
                    final bool isAccentNote = note.isAccent || note.velocity > 0.75;
                    final effectiveMidi = remapPitch(note.pitch);

                    audioEngine.playNoteOrSample(
                      track: track,
                      midiNote: effectiveMidi,
                      isSlide: note.isSlide,
                      isAccent: isAccentNote,
                      velocity: note.velocity,
                      durationSec: math.max(0.02, note.durationSteps * stepDurationSec),
                      scheduledTime: noteHardwareTime,
                    );
                  }
                }
              }
            } else if (localStep < track.steps.length) {
              final step = track.steps[localStep % track.steps.length];
              if (step.active) {
                final nextStep = track.steps[(localStep + 1) % track.steps.length];
                final prevStep = track.steps[(localStep - 1 + track.steps.length) % track.steps.length];
                final bool isSlideStep = step.isSlide ||
                    (track.isMonophonicTrack && nextStep.active) ||
                    (track.isMonophonicTrack && prevStep.active);
                final int? rawTargetPitch = nextStep.active ? nextStep.pitch : null;
                final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;
                final bool isAccentStep = step.isAccent || step.velocity > 0.75;

                final effectiveMidi = remapPitch(step.pitch);

                audioEngine.playNoteOrSample(
                  track: track,
                  midiNote: effectiveMidi,
                  targetMidiNote: targetPitch,
                  isSlide: isSlideStep,
                  isAccent: isAccentStep,
                  velocity: step.velocity,
                  durationSec: stepDurationSec, // synthesize only one 16th note, not the 0.4s default
                  scheduledTime: hardwareTime,
                );
              }
            }
          }
        }
      } else {
        // Pattern Sequencer Playback without clips (EDIT pane / Pattern Mode)
        final int localStep = stepIdx % 16;
        final List<Note> effectiveNotes = track.notes;

        final isTtsInstrument = track.type == TrackType.tts ||
            track.enableTts ||
            track.luaScriptCode.contains('TtsSynth') ||
            track.sampleName.toLowerCase().contains('tts');

        if (isTtsInstrument) {
          final double effPitch = track.luaParams['Pitch'] ?? track.ttsPitch;
          final double effRate = track.luaParams['Rate'] ?? track.ttsRate;
          final double effVol = (track.luaParams['Volume'] ?? track.ttsVolume) * track.volume;

          final matchingLyrics = track.lyrics.where(
            (l) => l.startStep >= localStep && l.startStep < (localStep + 1.0),
          );
          for (final cue in matchingLyrics) {
            TtsEngine().speak(
              cue.phoneticOverride ?? cue.text,
              voice: track.ttsVoice,
              pitch: (cue.pitch * effPitch).clamp(0.5, 2.0),
              rate: (cue.rate * effRate).clamp(0.1, 2.0),
              volume: effVol.clamp(0.0, 1.0),
            );
          }

          for (final note in effectiveNotes) {
            if (note.lyric != null &&
                note.lyric!.isNotEmpty &&
                note.startStep >= localStep &&
                note.startStep < (localStep + 1.0)) {
              final semitoneOffset = (note.pitch - 60) / 12.0;
              final notePitchMult = math.pow(2.0, semitoneOffset).toDouble();
              TtsEngine().speak(
                note.lyric!,
                voice: track.ttsVoice,
                pitch: (notePitchMult * effPitch).clamp(0.5, 2.0),
                rate: effRate.clamp(0.1, 2.0),
                volume: (note.velocity * effVol).clamp(0.0, 1.0),
              );
            }
          }
        }

        if (effectiveNotes.isNotEmpty) {
          final matchingNotes = effectiveNotes.where(
            (n) => n.startStep >= localStep && n.startStep < (localStep + 1.0),
          ).toList();

          if (matchingNotes.isNotEmpty) {
            if (track.isMonophonicTrack) {
              final sortedNotes = matchingNotes.toList()..sort((a, b) => a.startStep.compareTo(b.startStep));
              final hasSlideParam = (track.luaParams['Slide'] ?? 0.0) > 0.01 ||
                  (track.luaParams['Portamento'] ?? 0.0) > 0.01 ||
                  (track.luaParams['Glide'] ?? 0.0) > 0.01;

              for (int mIdx = 0; mIdx < sortedNotes.length; mIdx++) {
                final note = sortedNotes[mIdx];
                final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);

                final otherMatching = sortedNotes.where((n) => n != note).toList();
                final nextNotes = effectiveNotes.where((n) => n.startStep > note.startStep && n.startStep <= (note.startStep + math.max(1.5, note.durationSteps + 0.5))).toList();

                int? rawTargetPitch;
                if (otherMatching.isNotEmpty && (mIdx < sortedNotes.length - 1 || sortedNotes.length > 1)) {
                  // Simultaneous notes in pattern sequencer: slide towards concurrent note
                  final targetSimNote = sortedNotes.last != note ? sortedNotes.last : sortedNotes.first;
                  rawTargetPitch = targetSimNote.pitch;
                } else if (nextNotes.isNotEmpty) {
                  rawTargetPitch = nextNotes.first.pitch;
                }

                final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;
                final bool hasPrevOverlap = effectiveNotes.any(
                  (n) => n.startStep < note.startStep && (n.startStep + n.durationSteps) > note.startStep,
                );

                final bool isSlideNote = note.isSlide ||
                    hasPrevOverlap ||
                    otherMatching.isNotEmpty ||
                    hasSlideParam ||
                    (note.durationSteps > 1.0) ||
                    (nextNotes.isNotEmpty && (note.isSlide || hasSlideParam || note.durationSteps >= 1.0));
                final bool isAccentNote = note.isAccent || note.velocity > 0.75;
                final effectiveMidi = remapPitch(note.pitch);

                audioEngine.playNoteOrSample(
                  track: track,
                  midiNote: effectiveMidi,
                  targetMidiNote: targetPitch,
                  isSlide: isSlideNote,
                  isAccent: isAccentNote,
                  velocity: note.velocity,
                  durationSec: math.max(0.02, note.durationSteps * stepDurationSec),
                  scheduledTime: noteHardwareTime,
                );
              }
            } else {
              for (final note in matchingNotes) {
                final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);
                final bool isAccentNote = note.isAccent || note.velocity > 0.75;
                final effectiveMidi = remapPitch(note.pitch);

                audioEngine.playNoteOrSample(
                  track: track,
                  midiNote: effectiveMidi,
                  isSlide: note.isSlide,
                  isAccent: isAccentNote,
                  velocity: note.velocity,
                  durationSec: math.max(0.02, note.durationSteps * stepDurationSec),
                  scheduledTime: noteHardwareTime,
                );
              }
            }
          }
        } else if (localStep < track.steps.length) {
          final step = track.steps[localStep % track.steps.length];
          if (step.active) {
            final nextStep = track.steps[(localStep + 1) % track.steps.length];
            final prevStep = track.steps[(localStep - 1 + track.steps.length) % track.steps.length];
            final bool isSlideStep = step.isSlide ||
                (track.isMonophonicTrack && nextStep.active) ||
                (track.isMonophonicTrack && prevStep.active);
            final int? rawTargetPitch = nextStep.active ? nextStep.pitch : null;
            final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;
            final bool isAccentStep = step.isAccent || step.velocity > 0.75;

            final effectiveMidi = remapPitch(step.pitch);

            audioEngine.playNoteOrSample(
              track: track,
              midiNote: effectiveMidi,
              targetMidiNote: targetPitch,
              isSlide: isSlideStep,
              isAccent: isAccentStep,
              velocity: step.velocity,
              durationSec: stepDurationSec,
              scheduledTime: hardwareTime,
            );
          }
        }
      }
    }
  }

  void _syncClipNotes(TrackChannel track) {
    if (track.clips.isNotEmpty) {
      for (final clip in track.clips) {
        clip.notes = track.notes;
      }
    }
  }

  // Step Editing
  void toggleStep(TrackChannel track, int stepIndex) {
    if (stepIndex >= 0 && stepIndex < track.steps.length) {
      final step = track.steps[stepIndex];
      step.active = !step.active;

      if (step.active) {
        // Add matching note for Piano Roll
        track.notes.removeWhere((n) => n.startStep.toInt() == stepIndex && n.pitch == step.pitch);
        track.notes.add(Note(
          id: 'step_${track.id}_$stepIndex',
          pitch: step.pitch,
          startStep: stepIndex.toDouble(),
          durationSteps: 1.0,
          velocity: step.velocity,
        ));
        audioEngine.playNoteOrSample(
          track: track,
          midiNote: step.pitch,
          velocity: step.velocity,
        );
      } else {
        // Remove matching note
        track.notes.removeWhere((n) => n.startStep.toInt() == stepIndex && n.pitch == step.pitch);
      }
      _syncClipNotes(track);
      recordHistory(
        '${step.active ? "Activate" : "Deactivate"} Step ${stepIndex + 1} (${track.name})',
        icon: Icons.grid_view,
      );
      notifyListeners();
    }
  }

  void setStepVelocity(TrackChannel track, int stepIndex, double velocity) {
    if (stepIndex >= 0 && stepIndex < track.steps.length) {
      track.steps[stepIndex].velocity = velocity.clamp(0.0, 1.0);
      notifyListeners();
    }
  }

  // Quantization Snap Setting for Piano Roll (0.0 = No Snap, 0.5 = 1/32, 1.0 = 1/16, 2.0 = 1/8, 4.0 = 1/4)
  double _quantizeSnap = 1.0;
  double get quantizeSnap => _quantizeSnap;
  void setQuantizeSnap(double val) {
    _quantizeSnap = val;
    notifyListeners();
  }

  // Arranger Timeline & Playhead Snap (16.0 = 1 Bar, 8.0 = 1/2 Bar, 4.0 = 1/4 Bar (Beat), 2.0 = 1/8 Bar, 1.0 = 1/16 Step, 0.0 = Off / Freeform)
  double _arrangerSnap = 16.0;
  double get arrangerSnap => _arrangerSnap;
  void setArrangerSnap(double val) {
    _arrangerSnap = val;
    notifyListeners();
  }

  // Piano Roll Note Editing
  void addNote(TrackChannel track, Note note) {
    track.notes.add(note);
    _syncClipNotes(track);

    int? targetSlidePitch;
    bool isSlide = note.isSlide;
    if (track.isMonophonicTrack) {
      final simNotes = track.notes.where((n) => n.id != note.id && (n.startStep - note.startStep).abs() < 0.5).toList();
      if (simNotes.isNotEmpty) {
        targetSlidePitch = note.pitch;
        isSlide = true;
      }
    }

    audioEngine.playNoteOrSample(
      track: track,
      midiNote: note.pitch,
      targetMidiNote: targetSlidePitch,
      isSlide: isSlide,
      isAccent: note.isAccent || note.velocity > 0.75,
      velocity: note.velocity,
    );
    recordHistory('Add Note ${_formatPitch(note.pitch)} (${track.name})', icon: Icons.music_note, force: true);
    notifyListeners();
  }

  void updateNote(TrackChannel track, Note updatedNote) {
    final idx = track.notes.indexWhere((n) => n.id == updatedNote.id);
    if (idx != -1) {
      track.notes[idx] = updatedNote;
      _syncClipNotes(track);
      recordHistory('Update Note ${_formatPitch(updatedNote.pitch)} (${track.name})', icon: Icons.music_note, force: true);
      notifyListeners();
    }
  }

  void removeNote(TrackChannel track, String noteId) {
    track.notes.removeWhere((n) => n.id == noteId);
    _syncClipNotes(track);
    recordHistory('Delete Note (${track.name})', icon: Icons.delete_outline, force: true);
    notifyListeners();
  }

  void removeNotes(TrackChannel track, Iterable<String> noteIds) {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty) return;
    track.notes.removeWhere((n) => idSet.contains(n.id));
    _syncClipNotes(track);
    recordHistory('Delete ${idSet.length} Notes (${track.name})', icon: Icons.delete_outline, force: true);
    notifyListeners();
  }

  void transposeNotes(TrackChannel track, Iterable<String> noteIds, int semitones) {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty || semitones == 0) return;
    for (final n in track.notes) {
      if (idSet.contains(n.id)) {
        n.pitch = (n.pitch + semitones).clamp(0, 127);
      }
    }
    _syncClipNotes(track);
    recordHistory('Transpose ${idSet.length} Notes by ${semitones > 0 ? "+$semitones" : semitones} (${track.name})', icon: Icons.tune, force: true);
    notifyListeners();
  }

  void setNotesVelocity(TrackChannel track, Iterable<String> noteIds, double velocity) {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty) return;
    final clampedVel = velocity.clamp(0.01, 1.0);
    for (final n in track.notes) {
      if (idSet.contains(n.id)) {
        n.velocity = clampedVel;
      }
    }
    _syncClipNotes(track);
    notifyListeners();
  }

  void nudgeNotesPosition(TrackChannel track, Iterable<String> noteIds, double deltaSteps) {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty || deltaSteps == 0) return;
    for (final n in track.notes) {
      if (idSet.contains(n.id)) {
        n.startStep = (n.startStep + deltaSteps).clamp(0.0, 64.0);
      }
    }
    _syncClipNotes(track);
    recordHistory('Nudge ${idSet.length} Notes (${track.name})', icon: Icons.open_with, force: true);
    notifyListeners();
  }

  void changeNotesDuration(TrackChannel track, Iterable<String> noteIds, double deltaSteps) {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty || deltaSteps == 0) return;
    for (final n in track.notes) {
      if (idSet.contains(n.id)) {
        n.durationSteps = (n.durationSteps + deltaSteps).clamp(0.25, 64.0);
      }
    }
    _syncClipNotes(track);
    recordHistory('Change Duration of ${idSet.length} Notes (${track.name})', icon: Icons.straighten, force: true);
    notifyListeners();
  }

  // Note Clipboard State & Operations (Universal Cross-Platform Lua Clipboard)
  List<Note> noteClipboard = [];

  Future<String> copyNotesToClipboard(TrackChannel track, Iterable<String> noteIds) async {
    final idSet = noteIds.toSet();
    final notesToCopy = idSet.isEmpty
        ? track.notes.map((n) => n.copyWith()).toList()
        : track.notes.where((n) => idSet.contains(n.id)).map((n) => n.copyWith()).toList();

    if (notesToCopy.isEmpty) return '';

    final luaCode = EatsLuaSerializer.serializeNotes(notesToCopy, relativeSteps: true);
    noteClipboard = notesToCopy;

    try {
      await Clipboard.setData(ClipboardData(text: luaCode));
    } catch (_) {}

    return luaCode;
  }

  Future<void> cutNotesToClipboard(TrackChannel track, Iterable<String> noteIds) async {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty) return;
    await copyNotesToClipboard(track, noteIds);
    removeNotes(track, noteIds);
  }

  Future<String> copyTrackerBlockToClipboard({
    required int startStep,
    required int endStep,
    required int startCol,
    required int endCol,
  }) async {
    final minS = math.min(startStep, endStep);
    final maxS = math.max(startStep, endStep);
    final minC = math.min(startCol, endCol);
    final maxC = math.max(startCol, endCol);

    final notesInBlock = activeTrack.notes.where((n) {
      final s = n.startStep.toInt();
      return s >= minS && s <= maxS && n.column >= minC && n.column <= maxC;
    }).map((n) => n.copyWith()).toList();

    if (notesInBlock.isEmpty) return '';

    final luaCode = EatsLuaSerializer.serializeNotes(notesInBlock, relativeSteps: true);
    noteClipboard = notesInBlock;

    try {
      await Clipboard.setData(ClipboardData(text: luaCode));
    } catch (_) {}

    return luaCode;
  }

  Future<List<Note>> pasteNotesFromClipboard(
    TrackChannel track, {
    double? targetStep,
    int? targetCol,
  }) async {
    List<Note> sourceNotes = [];

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.trim().isNotEmpty) {
        sourceNotes = EatsLuaParser.parseNotes(clipboardData.text!);
      }
    } catch (_) {}

    if (sourceNotes.isEmpty) {
      sourceNotes = noteClipboard.map((n) => n.copyWith()).toList();
    }

    if (sourceNotes.isEmpty) return [];

    final insertStep = targetStep ?? currentStep.toDouble();
    final insertCol = targetCol ?? trackerSelectedColumn;

    final double minStep = sourceNotes.map((n) => n.startStep).reduce((a, b) => a < b ? a : b);
    final int minCol = sourceNotes.map((n) => n.column).reduce((a, b) => a < b ? a : b);

    final pastedNotes = <Note>[];
    final now = DateTime.now().microsecondsSinceEpoch;

    beginHistoryTransaction('Paste ${sourceNotes.length} Notes', icon: Icons.paste);

    for (int i = 0; i < sourceNotes.length; i++) {
      final src = sourceNotes[i];
      final newStep = (insertStep + (src.startStep - minStep)).clamp(0.0, 64.0);
      final newCol = (insertCol + (src.column - minCol)).clamp(0, 16);

      final newNote = Note(
        id: 'p_${now}_$i',
        pitch: src.pitch.clamp(0, 127),
        startStep: newStep,
        durationSteps: src.durationSteps.clamp(0.1, 64.0),
        velocity: src.velocity.clamp(0.01, 1.0),
        column: newCol,
        effectCommand: src.effectCommand,
        isSlide: src.isSlide,
        isAccent: src.isAccent,
      );

      track.notes.add(newNote);
      pastedNotes.add(newNote);
    }

    _syncClipNotes(track);
    commitHistoryTransaction();
    notifyListeners();

    return pastedNotes;
  }

  void setTrackClipBarLength(TrackClip clip, int newBarLength) {
    final clamped = newBarLength.clamp(1, 16);
    clip.barLength = clamped;
    recordHistory('Resize Clip "${clip.name}" to $clamped Bars', icon: Icons.straighten);
    notifyListeners();
  }

  // Mixer Editing
  void setTrackVolume(TrackChannel track, double volume) {
    track.volume = volume.clamp(0.0, 1.5);
    notifyListeners();
  }

  void setTrackPan(TrackChannel track, double pan) {
    track.pan = pan.clamp(-1.0, 1.0);
    notifyListeners();
  }

  void toggleMute(TrackChannel track) {
    track.isMuted = !track.isMuted;
    recordHistory('${track.isMuted ? "Mute" : "Unmute"} ${track.name}', icon: Icons.volume_off);
    notifyListeners();
  }

  void toggleSolo(TrackChannel track) {
    track.isSoloed = !track.isSoloed;
    recordHistory('${track.isSoloed ? "Solo" : "Unsolo"} ${track.name}', icon: Icons.headphones);
    notifyListeners();
  }

  void setTrackColor(TrackChannel track, Color color) {
    track.color = color;
    if (track.isFolder && track.syncColorWithChildren) {
      for (final child in getFolderChildren(track.id)) {
        child.color = color;
      }
    }
    notifyListeners();
  }

  List<TrackChannel> get folderTracks => activePattern.tracks.where((t) => t.isFolder).toList();

  List<TrackChannel> getFolderChildren(String folderId) {
    return activePattern.tracks.where((t) => t.parentFolderId == folderId).toList();
  }

  bool isTrackEffectivelyMuted(TrackChannel track) {
    if (track.isMuted) return true;
    if (track.parentFolderId != null && track.parentFolderId!.isNotEmpty) {
      final parent = activePattern.tracks.where((t) => t.id == track.parentFolderId).firstOrNull;
      if (parent != null && parent.isMuted) return true;
    }
    return false;
  }

  bool isTrackEffectivelySoloed(TrackChannel track) {
    if (track.isSoloed) return true;
    if (track.parentFolderId != null && track.parentFolderId!.isNotEmpty) {
      final parent = activePattern.tracks.where((t) => t.id == track.parentFolderId).firstOrNull;
      if (parent != null && parent.isSoloed) return true;
    }
    return false;
  }

  /// Returns the list of tracks visible in Arranger / Mixer taking folded state into account.
  List<TrackChannel> get visibleTracks {
    final result = <TrackChannel>[];
    final allTracks = activePattern.tracks;
    final folderMap = {for (final t in allTracks.where((t) => t.isFolder)) t.id: t};

    for (final track in allTracks) {
      if (track.parentFolderId == null || track.parentFolderId!.isEmpty) {
        result.add(track);
      } else {
        final parent = folderMap[track.parentFolderId];
        // Only visible if parent folder exists and is NOT collapsed
        if (parent != null && !parent.isCollapsed) {
          result.add(track);
        } else if (parent == null) {
          // Parent no longer exists; include track as orphaned top-level
          result.add(track);
        }
      }
    }
    return result;
  }

  TrackChannel createTrackFolder({
    String? name,
    List<String>? initialTrackIds,
    Color? color,
  }) {
    final folderId = 'folder_${DateTime.now().millisecondsSinceEpoch}';
    final folderColors = [
      const Color(0xFF4A90E2),
      const Color(0xFF00FFC2),
      const Color(0xFFFF8C00),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFFFFEB3B),
    ];
    final folderColor = color ?? folderColors[folderTracks.length % folderColors.length];

    final folderTrack = TrackChannel(
      id: folderId,
      name: name ?? 'Folder ${folderTracks.length + 1}',
      type: TrackType.folder,
      color: folderColor,
      iconName: 'folder',
      isCollapsed: false,
      isFolderBus: true,
      syncColorWithChildren: true,
    );

    beginHistoryTransaction('Create Folder "${folderTrack.name}"', icon: Icons.create_new_folder);

    // Determine insertion position
    int insertIndex = activePattern.tracks.length;
    if (initialTrackIds != null && initialTrackIds.isNotEmpty) {
      final firstIdx = activePattern.tracks.indexWhere((t) => initialTrackIds.contains(t.id));
      if (firstIdx != -1) {
        insertIndex = firstIdx;
      }
    }

    activePattern.tracks.insert(insertIndex, folderTrack);

    if (initialTrackIds != null && initialTrackIds.isNotEmpty) {
      for (final trk in activePattern.tracks) {
        if (initialTrackIds.contains(trk.id) && trk.id != folderId) {
          trk.parentFolderId = folderId;
          if (folderTrack.syncColorWithChildren) {
            trk.color = folderColor;
          }
        }
      }
    }

    _activeTrackIndex = activePattern.tracks.indexOf(folderTrack);
    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();
    return folderTrack;
  }

  void groupTracks(List<String> trackIds, {String? folderName, Color? color}) {
    if (trackIds.isEmpty) return;
    createTrackFolder(name: folderName, initialTrackIds: trackIds, color: color);
  }

  void ungroupTrack(String trackId) {
    final track = activePattern.tracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null || track.parentFolderId == null) return;

    track.parentFolderId = null;
    recordHistory('Ungroup Track "${track.name}"', icon: Icons.folder_off);
    triggerAutoSave();
    notifyListeners();
  }

  void setTrackFolder(String trackId, String? folderId) {
    final track = activePattern.tracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;
    if (track.isFolder) return; // Prevent nested folders for 1-level simplicity

    final oldFolderId = track.parentFolderId;
    if (oldFolderId == folderId) return;

    track.parentFolderId = folderId;
    if (folderId != null) {
      final folder = activePattern.tracks.where((t) => t.id == folderId).firstOrNull;
      if (folder != null && folder.syncColorWithChildren) {
        track.color = folder.color;
      }
      recordHistory('Move "${track.name}" to Folder "${folder?.name ?? "Folder"}"', icon: Icons.drive_file_move);
    } else {
      recordHistory('Remove "${track.name}" from Folder', icon: Icons.folder_off);
    }

    triggerAutoSave();
    notifyListeners();
  }

  void toggleFolderCollapsed(TrackChannel folderTrack) {
    if (!folderTrack.isFolder) return;
    folderTrack.isCollapsed = !folderTrack.isCollapsed;
    notifyListeners();
  }

  void toggleFolderColorSync(TrackChannel folderTrack) {
    if (!folderTrack.isFolder) return;
    folderTrack.syncColorWithChildren = !folderTrack.syncColorWithChildren;
    if (folderTrack.syncColorWithChildren) {
      for (final child in getFolderChildren(folderTrack.id)) {
        child.color = folderTrack.color;
      }
    }
    notifyListeners();
  }

  void deleteTrack(TrackChannel track) {
    if (activePattern.tracks.length <= 1) return;
    final index = activePattern.tracks.indexWhere((t) => t.id == track.id);
    if (index != -1) {
      beginHistoryTransaction('Delete Track "${track.name}"', icon: Icons.delete);
      if (track.isFolder) {
        // Unparent child tracks so user does not lose them
        for (final child in getFolderChildren(track.id)) {
          child.parentFolderId = null;
        }
      }
      activePattern.tracks.removeAt(index);
      audioEngine.disposeTrack(track.id);
      if (_activeTrackIndex >= activePattern.tracks.length) {
        _activeTrackIndex = activePattern.tracks.length - 1;
      }
      commitHistoryTransaction();
      triggerAutoSave();
      notifyListeners();
    }
  }

  void moveTrackUp(TrackChannel track) {
    final idx = activePattern.tracks.indexOf(track);
    if (idx > 0) {
      activePattern.tracks.removeAt(idx);
      activePattern.tracks.insert(idx - 1, track);
      _activeTrackIndex = idx - 1;
      recordHistory('Move Track "${track.name}" Up', icon: Icons.keyboard_arrow_up);
      triggerAutoSave();
      notifyListeners();
    }
  }

  void moveTrackDown(TrackChannel track) {
    final idx = activePattern.tracks.indexOf(track);
    if (idx != -1 && idx < activePattern.tracks.length - 1) {
      activePattern.tracks.removeAt(idx);
      activePattern.tracks.insert(idx + 1, track);
      _activeTrackIndex = idx + 1;
      recordHistory('Move Track "${track.name}" Down', icon: Icons.keyboard_arrow_down);
      triggerAutoSave();
      notifyListeners();
    }
  }

  void reorderTracks(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= activePattern.tracks.length) return;
    if (newIndex < 0 || newIndex >= activePattern.tracks.length) return;
    if (oldIndex == newIndex) return;

    final track = activePattern.tracks[oldIndex];
    if (track.isFolder) {
      final children = getFolderChildren(track.id);
      final tracksToMove = [track, ...children];
      for (final t in tracksToMove) {
        activePattern.tracks.remove(t);
      }
      final safeNewIdx = newIndex.clamp(0, activePattern.tracks.length);
      activePattern.tracks.insertAll(safeNewIdx, tracksToMove);
      _activeTrackIndex = safeNewIdx;
    } else {
      final item = activePattern.tracks.removeAt(oldIndex);
      activePattern.tracks.insert(newIndex, item);
      _activeTrackIndex = newIndex;
    }
    recordHistory('Reorder Track "${track.name}" to position ${newIndex + 1}', icon: Icons.swap_vert);
    triggerAutoSave();
    notifyListeners();
  }

  void duplicateTrack(TrackChannel track) {
    final newId = 't_${DateTime.now().millisecondsSinceEpoch}';
    final duplicatedClips = track.clips.map((c) {
      return TrackClip(
        id: 'clip_${newId}_${c.id}',
        name: '${c.name} Copy',
        trackId: newId,
        startBar: c.startBar,
        barLength: c.barLength,
        notes: c.notes.map((n) => n.copyWith()).toList(),
        luaScriptCode: c.luaScriptCode,
        luaParams: Map.from(c.luaParams),
      );
    }).toList();

    final newTrack = TrackChannel(
      id: newId,
      name: '${track.name} (Copy)',
      color: track.color,
      type: track.type,
      volume: track.volume,
      pan: track.pan,
      isMuted: track.isMuted,
      isSoloed: track.isSoloed,
      sampleName: track.sampleName,
      synthWaveform: track.synthWaveform,
      cutoff: track.cutoff,
      resonance: track.resonance,
      attack: track.attack,
      release: track.release,
      luaScriptCode: track.luaScriptCode,
      luaParams: Map.from(track.luaParams),
      steps: track.steps.map((s) => StepEvent(active: s.active, velocity: s.velocity, pitch: s.pitch, isSlide: s.isSlide, isAccent: s.isAccent)).toList(),
      notes: track.notes.map((n) => n.copyWith()).toList(),
      clips: duplicatedClips,
      fxRack: track.fxRack.map((f) => FXInsert(id: f.id, name: f.name, type: f.type, enabled: f.enabled, mix: f.mix, params: Map.from(f.params))).toList(),
      trackerColumns: track.trackerColumns,
      activeView: track.activeView,
      isMonophonic: track.isMonophonic,
    );

    final insertIdx = activePattern.tracks.indexOf(track) + 1;
    if (insertIdx > 0 && insertIdx <= activePattern.tracks.length) {
      activePattern.tracks.insert(insertIdx, newTrack);
      activeTrackIndex = insertIdx;
    } else {
      activePattern.tracks.add(newTrack);
      activeTrackIndex = activePattern.tracks.length - 1;
    }
    recordHistory('Duplicate Track "${track.name}"', icon: Icons.copy);
    notifyListeners();
  }

  // Modular FX Insert Management
  void _syncFxAudio(TrackChannel track) {
    if (track.id == masterTrack.id || track == masterTrack) {
      audioEngine.updateMasterFx(masterTrack.fxRack);
    } else {
      audioEngine.updateTrackFx(track.id, track.fxRack, volume: track.volume, pan: track.pan);
      audioEngine.invalidateLuaCache(track.id);
    }
  }

  void addAudioFXFromPreset(TrackChannel track, LuaPreset preset) {
    final compiled = LuaEngine.compile(preset.code);
    final initialParams = <String, double>{};
    for (final p in compiled.params) {
      initialParams[p.name] = p.defaultValue;
    }

    FXType type = FXType.luaFX;
    final lowerId = preset.id.toLowerCase();
    final lowerName = preset.name.toLowerCase();
    if (lowerId == 'limiter' || lowerName.contains('limiter')) {
      type = FXType.limiter;
    } else if (lowerId == 'compressor' || lowerName.contains('compressor')) {
      type = FXType.compressor;
    } else if (lowerId.contains('reverb') || lowerName.contains('reverb') || lowerId == 'room_designer' || lowerId == 'cab_designer' || lowerName.contains('designer')) {
      type = FXType.convolutionReverb;
    } else if (lowerId == 'biquad_filter' || lowerId == 'lowpass_filter') {
      type = FXType.biquadFilter;
    } else if (lowerId.contains('shaper') || lowerName.contains('shaper') || lowerId == 'tube_distortion' || lowerName.contains('distortion')) {
      type = FXType.distortion;
    } else if (lowerId.contains('bitcrush') || lowerName.contains('bitcrush') || lowerName.contains('crusher')) {
      type = FXType.bitcrusher;
    } else if (lowerId == 'stereo_delay' || lowerId.contains('delay')) {
      type = FXType.delay;
    }

    final fx = FXInsert.create(
      type,
      name: preset.name,
      luaScriptCode: preset.code,
      presetId: preset.id,
      luaParams: initialParams,
    );
    for (final e in initialParams.entries) {
      fx.params[e.key] = e.value;
    }
    if (lowerId == 'cab_designer' || lowerId == 'room_designer') {
      final isCab = lowerId == 'cab_designer';
      final customName = isCab ? 'Cab: ${track.name}_${fx.id}' : 'Room: ${track.name}_${fx.id}';
      final matIdx = (initialParams['Material'] ?? 0.0).toInt().clamp(0, AcousticMaterialType.values.length - 1);
      final spaceParams = AcousticSpaceParams(
        name: customName,
        width: initialParams['Width'] ?? (isCab ? 0.76 : 15.0),
        length: initialParams['Length'] ?? (isCab ? 0.76 : 25.0),
        height: initialParams['Height'] ?? (isCab ? 0.36 : 10.0),
        material: AcousticMaterialType.values[matIdx],
        rt60: isCab ? 0.035 : (initialParams['RT60'] ?? 2.2),
        damping: initialParams['Damping'] ?? (isCab ? 0.55 : 0.25),
        isCabinetMode: isCab,
        micDistance: initialParams['MicDistance'] ?? 0.05,
        micAngleDeg: initialParams['MicAngle'] ?? 0.0,
        isOpenBack: (initialParams['OpenBack'] ?? 0.0) == 1.0,
      );
      ConvolverEngine.instance.bakeCustomSpace(spaceParams);
      audioEngine.invalidateIrCache(customName);
      fx.irSampleName = customName;
      if (isCab) {
        fx.params['DryLevel'] = 0.0;
        fx.params['WetLevel'] = 1.0;
        fx.luaParams['DryLevel'] = 0.0;
        fx.luaParams['WetLevel'] = 1.0;
      }
    }
    track.fxRack.add(fx);
    _syncFxAudio(track);
    recordHistory('Add FX "${preset.name}" to ${track.name} FX rack', icon: Icons.tune);
    notifyListeners();
  }

  void addFXInsert(TrackChannel track, FXType type) {
    track.fxRack.add(FXInsert.create(type));
    _syncFxAudio(track);
    notifyListeners();
  }

  void removeFXInsert(TrackChannel track, String fxId) {
    track.fxRack.removeWhere((f) => f.id == fxId);
    _syncFxAudio(track);
    notifyListeners();
  }

  void reorderFXInsert(TrackChannel track, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex >= 0 && oldIndex < track.fxRack.length && newIndex >= 0 && newIndex <= track.fxRack.length) {
      final item = track.fxRack.removeAt(oldIndex);
      track.fxRack.insert(newIndex, item);
      _syncFxAudio(track);
      notifyListeners();
    }
  }

  void moveFXUp(TrackChannel track, int index) {
    if (index > 0 && index < track.fxRack.length) {
      final fx = track.fxRack.removeAt(index);
      track.fxRack.insert(index - 1, fx);
      _syncFxAudio(track);
      recordHistory('Move FX Up (${fx.name})', icon: Icons.arrow_upward);
      notifyListeners();
    }
  }

  void moveFXDown(TrackChannel track, int index) {
    if (index >= 0 && index < track.fxRack.length - 1) {
      final fx = track.fxRack.removeAt(index);
      track.fxRack.insert(index + 1, fx);
      _syncFxAudio(track);
      recordHistory('Move FX Down (${fx.name})', icon: Icons.arrow_downward);
      notifyListeners();
    }
  }

  void toggleFXInsert(TrackChannel track, String fxId, bool enabled) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.enabled = enabled;
        _syncFxAudio(track);
        notifyListeners();
        break;
      }
    }
  }

  void updateFXMix(TrackChannel track, String fxId, double mix) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.mix = mix.clamp(0.0, 1.0);
        _syncFxAudio(track);
        notifyListeners();
        break;
      }
    }
  }

  void updateFXParam(TrackChannel track, String fxId, String paramName, double val) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.params[paramName] = val;
        f.luaParams[paramName] = val;

        // If this is an IRSample choice parameter in Convolution Reverb
        if (paramName == 'IRSample') {
          final allIrs = ConvolverEngine.instance.getAvailableIrNames();
          final idx = val.toInt().clamp(0, allIrs.length - 1);
          if (allIrs.isNotEmpty) {
            f.irSampleName = allIrs[idx];
            audioEngine.invalidateIrCache(f.irSampleName);
          }
        }

        // If this is a Room or Cabinet Designer parameter
        final isRoomDesigner = f.presetId == 'room_designer' || f.name.toLowerCase().contains('room designer');
        final isCabDesigner = f.presetId == 'cab_designer' || f.name.toLowerCase().contains('cab');
        if (isRoomDesigner || isCabDesigner) {
          final customName = isCabDesigner ? 'Cab: ${track.name}_${f.id}' : 'Room: ${track.name}_${f.id}';

          if (isCabDesigner && paramName == 'CabType') {
            final cabPresetKeys = [
              '4x12 Vintage Stack (Closed)',
              '2x12 British Celestion',
              '1x12 Tweed Combo (Open-Back)',
              'Bass 8x10 Fridge',
              'Small Radio Speaker',
            ];
            final cIdx = val.toInt().clamp(0, cabPresetKeys.length - 1);
            final cabPreset = ProceduralIRGenerator.presets[cabPresetKeys[cIdx]];
            if (cabPreset != null) {
              f.params['Width'] = cabPreset.width;
              f.params['Length'] = cabPreset.length;
              f.params['Height'] = cabPreset.height;
              f.params['MicDistance'] = cabPreset.micDistance;
              f.params['MicAngle'] = cabPreset.micAngleDeg;
              f.params['OpenBack'] = cabPreset.isOpenBack ? 1.0 : 0.0;
              f.luaParams['Width'] = cabPreset.width;
              f.luaParams['Length'] = cabPreset.length;
              f.luaParams['Height'] = cabPreset.height;
              f.luaParams['MicDistance'] = cabPreset.micDistance;
              f.luaParams['MicAngle'] = cabPreset.micAngleDeg;
              f.luaParams['OpenBack'] = cabPreset.isOpenBack ? 1.0 : 0.0;
            }
          }

          final matIdx = (f.params['Material'] ?? 0.0).toInt().clamp(0, AcousticMaterialType.values.length - 1);
          final spaceParams = AcousticSpaceParams(
            name: customName,
            width: f.params['Width'] ?? (isCabDesigner ? 0.76 : 8.0),
            length: f.params['Length'] ?? (isCabDesigner ? 0.76 : 12.0),
            height: f.params['Height'] ?? (isCabDesigner ? 0.36 : 4.0),
            material: AcousticMaterialType.values[matIdx],
            rt60: isCabDesigner ? 0.035 : (f.params['RT60'] ?? (f.params['Decay'] ?? 1.8)),
            damping: f.params['Damping'] ?? (isCabDesigner ? 0.55 : 0.40),
            isCabinetMode: isCabDesigner,
            micDistance: f.params['MicDistance'] ?? 0.05,
            micAngleDeg: f.params['MicAngle'] ?? 0.0,
            isOpenBack: (f.params['OpenBack'] ?? 0.0) == 1.0,
          );

          ConvolverEngine.instance.bakeCustomSpace(spaceParams);
          audioEngine.invalidateIrCache(customName);
          f.irSampleName = customName;
        }

        _syncFxAudio(track);
        notifyListeners();
        break;
      }
    }
  }

  void updateFXIrSample(TrackChannel track, String fxId, String irName) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.irSampleName = irName;
        audioEngine.invalidateIrCache(irName);
        _syncFxAudio(track);
        notifyListeners();
        break;
      }
    }
  }

  // MIDI FX Insert Management
  void addMidiFXInsert(
    TrackChannel track, {
    String name = 'Arpeggiator FX',
    String luaScriptCode = 'arpeggiator',
    Map<String, double>? params,
  }) {
    final id = 'mfx_${DateTime.now().millisecondsSinceEpoch}_${track.midiFXRack.length}';
    final initialParams = params ?? {
      'Rate': 1.0,
      'Octaves': 2.0,
      'Pattern': 0.0,
      'Gate': 0.85,
      'Swing': 0.0,
    };
    track.midiFXRack.add(MidiFXInsert(
      id: id,
      name: name,
      enabled: true,
      luaScriptCode: luaScriptCode,
      luaParams: initialParams,
    ));
    invalidateTrackMidiCache(track);
    recordHistory('Add MIDI FX "$name" to ${track.name}', icon: Icons.music_note);
    notifyListeners();
  }

  void addMidiFXFromPreset(TrackChannel track, LuaPreset preset) {
    final initialParams = <String, double>{};
    final compilation = LuaEngine.compile(preset.code);
    for (final p in compilation.params) {
      initialParams[p.name] = p.defaultValue;
    }

    addMidiFXInsert(
      track,
      name: preset.name,
      luaScriptCode: preset.code,
      params: initialParams,
    );
  }

  void removeMidiFXInsert(TrackChannel track, String midiFxId) {
    track.midiFXRack.removeWhere((f) => f.id == midiFxId);
    invalidateTrackMidiCache(track);
    recordHistory('Remove MIDI FX from ${track.name}', icon: Icons.delete_outline);
    notifyListeners();
  }

  void reorderMidiFXInsert(TrackChannel track, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex >= 0 && oldIndex < track.midiFXRack.length && newIndex >= 0 && newIndex <= track.midiFXRack.length) {
      final item = track.midiFXRack.removeAt(oldIndex);
      track.midiFXRack.insert(newIndex, item);
      invalidateTrackMidiCache(track);
      notifyListeners();
    }
  }

  void moveMidiFXUp(TrackChannel track, int index) {
    if (index > 0 && index < track.midiFXRack.length) {
      final fx = track.midiFXRack.removeAt(index);
      track.midiFXRack.insert(index - 1, fx);
      invalidateTrackMidiCache(track);
      recordHistory('Move MIDI FX Up (${fx.name})', icon: Icons.arrow_upward);
      notifyListeners();
    }
  }

  void moveMidiFXDown(TrackChannel track, int index) {
    if (index >= 0 && index < track.midiFXRack.length - 1) {
      final fx = track.midiFXRack.removeAt(index);
      track.midiFXRack.insert(index + 1, fx);
      invalidateTrackMidiCache(track);
      recordHistory('Move MIDI FX Down (${fx.name})', icon: Icons.arrow_downward);
      notifyListeners();
    }
  }

  void toggleMidiFXInsert(TrackChannel track, String midiFxId, bool enabled) {
    for (final f in track.midiFXRack) {
      if (f.id == midiFxId) {
        f.enabled = enabled;
        invalidateTrackMidiCache(track);
        notifyListeners();
        break;
      }
    }
  }

  void updateMidiFXParam(TrackChannel track, String midiFxId, String paramName, double val) {
    for (final f in track.midiFXRack) {
      if (f.id == midiFxId) {
        f.luaParams[paramName] = val;
        invalidateTrackMidiCache(track);
        notifyListeners();
        break;
      }
    }
  }

  void invalidateTrackMidiCache(TrackChannel track) {
    final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
    for (final clip in track.clips) {
      clip.evaluatedNotesCache = pipeline.processClip(
        clip: clip,
        track: track,
        timeContext: timeContext,
      );
    }
    if (activeClip != null && activeClip!.trackId == track.id) {
      activeClip!.evaluatedNotesCache = pipeline.processClip(
        clip: activeClip!,
        track: track,
        timeContext: timeContext,
      );
    }
  }

  /// Bakes / renders transformed MIDI FX notes down into real permanent notes in a single [clip].
  void bakeMidiFXToClip(TrackChannel track, TrackClip clip, {bool disableTrackMidiFx = false}) {
    final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
    final evaluated = pipeline.processClip(
      clip: clip,
      track: track,
      timeContext: timeContext,
    );

    clip.notes = evaluated.map((n) => n.copyWith(id: 'n_${clip.id}_baked_${n.startStep}_${n.pitch}')).toList();
    clip.evaluatedNotesCache = null;
    clip.luaScriptCode = ''; // Clear clip-level transform
    clip.luaParams.clear();

    if (activeTrack.id == track.id && activeClip?.id == clip.id) {
      track.notes = clip.notes.map((n) => n.copyWith()).toList();
    }

    if (disableTrackMidiFx) {
      for (final fx in track.midiFXRack) {
        fx.enabled = false;
      }
    }

    invalidateTrackMidiCache(track);
    recordHistory('Bake MIDI FX to Clip "${clip.name}"', icon: Icons.auto_fix_high);
    notifyListeners();
  }

  /// Bakes / renders transformed MIDI FX notes across all clips on the [track] and disables the MIDI FX rack.
  void bakeTrackMidiFX(TrackChannel track) {
    final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
    for (final clip in track.clips) {
      final evaluated = pipeline.processClip(
        clip: clip,
        track: track,
        timeContext: timeContext,
      );
      clip.notes = evaluated.map((n) => n.copyWith(id: 'n_${clip.id}_baked_${n.startStep}_${n.pitch}')).toList();
      clip.evaluatedNotesCache = null;
    }

    if (activeTrack.id == track.id && activeClip != null) {
      track.notes = activeClip!.notes.map((n) => n.copyWith()).toList();
    }

    for (final fx in track.midiFXRack) {
      fx.enabled = false;
    }

    invalidateTrackMidiCache(track);
    recordHistory('Bake MIDI FX on Track "${track.name}"', icon: Icons.auto_fix_high);
    notifyListeners();
  }

  /// Returns real-time evaluated notes for ghost preview rendering in Piano Roll and Arranger.
  List<Note> getEvaluatedClipNotes(TrackClip clip, TrackChannel track) {
    if (clip.evaluatedNotesCache != null && clip.evaluatedNotesCache!.isNotEmpty) {
      return clip.evaluatedNotesCache!;
    }
    final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
    return pipeline.processClip(
      clip: clip,
      track: track,
      timeContext: timeContext,
    );
  }

  // Legacy compatibility methods
  void toggleBitcrusher(TrackChannel track, bool enabled) {
    if (enabled) {
      if (!track.fxRack.any((f) => f.type == FXType.bitcrusher || f.name.contains('Bitcrusher'))) {
        addFXInsert(track, FXType.bitcrusher);
      }
    } else {
      track.fxRack.removeWhere((f) => f.type == FXType.bitcrusher || f.name.contains('Bitcrusher'));
      audioEngine.invalidateLuaCache(track.id);
      notifyListeners();
    }
  }

  void toggleDistortion(TrackChannel track, bool enabled) {
    if (enabled) {
      if (!track.fxRack.any((f) => f.type == FXType.distortion || f.name.contains('Distortion'))) {
        addFXInsert(track, FXType.distortion);
      }
    } else {
      track.fxRack.removeWhere((f) => f.type == FXType.distortion || f.name.contains('Distortion'));
      audioEngine.invalidateLuaCache(track.id);
      notifyListeners();
    }
  }


  // Project Serialization & .eats.zip Export / Import
  Uint8List exportToEatsZip() {
    final luaScript = exportToEatsLua();
    final luaBytes = utf8.encode(luaScript);

    final archive = Archive();
    archive.addFile(ArchiveFile('project.eats.lua', luaBytes.length, luaBytes));

    for (final entry in SamplerEngine.instance.loadedSamples.entries) {
      final sampleId = entry.key;
      final buffer = entry.value;
      final wavBytes = WavExporter.encodeWav(
        leftSamples: buffer.samples,
        rightSamples: buffer.samples,
        sampleRate: buffer.sampleRate,
      );
      final safeName = sampleId.endsWith('.wav') ? sampleId : '$sampleId.wav';
      archive.addFile(ArchiveFile('samples/$safeName', wavBytes.length, wavBytes));
    }

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData ?? []);
  }

  void loadFromEatsZipOrLua({Uint8List? zipBytes, String? luaContent, String? fileName}) {
    if (zipBytes != null && zipBytes.isNotEmpty) {
      // 1. Check for MIDI File (MThd signature: 0x4D, 0x54, 0x68, 0x64)
      if (zipBytes.length >= 4 &&
          zipBytes[0] == 0x4D &&
          zipBytes[1] == 0x54 &&
          zipBytes[2] == 0x68 &&
          zipBytes[3] == 0x64) {
        importMidiFileBytes(zipBytes, fileName: fileName ?? 'imported.mid');
        return;
      }

      // 2. Check for SoundFont File (.sf2)
      if (fileName != null && fileName.toLowerCase().endsWith('.sf2')) {
        SoundFontEngine.instance.registerSoundFont(fileName, zipBytes);
        return;
      }

      try {
        final archive = ZipDecoder().decodeBytes(zipBytes);
        ArchiveFile? luaFile;
        for (final file in archive) {
          if (file.name.endsWith('.lua') || file.name.endsWith('.eats.lua')) {
            luaFile = file;
            break;
          }
        }

        for (final file in archive) {
          if (file.isFile && (file.name.endsWith('.wav') || file.name.endsWith('.mp3'))) {
            final contentBytes = file.content as List<int>;
            final sampleName = file.name.split('/').last;
            SamplerEngine.instance.registerSampleBytes(sampleName, Uint8List.fromList(contentBytes));
          }
        }

        if (luaFile != null) {
          final content = utf8.decode(luaFile.content as List<int>);
          loadFromEatsLua(content);
        }
      } catch (e) {
        debugPrint('Error loading .eats.zip archive: $e');
      }
    } else if (luaContent != null) {
      loadFromEatsLua(luaContent);
    }
  }

  void addSampleTrackFromFile({
    required String fileName,
    required Uint8List fileBytes,
    int startBar = 0,
    int barLength = 4,
  }) {
    final cleanName = fileName.replaceAll('\\', '/').split('/').last;
    final lowerName = cleanName.toLowerCase();

    // 1. Standard MIDI File (.mid / .midi)
    if (lowerName.endsWith('.mid') || lowerName.endsWith('.midi')) {
      importMidiFileBytes(fileBytes, fileName: cleanName);
      return;
    }

    final isLua = lowerName.endsWith('.lua');

    if (isLua) {
      final luaCode = utf8.decode(fileBytes);
      final preset = LuaPresetLibrary.parseFromLuaScript(
        luaCode,
        fallbackName: cleanName.replaceAll(RegExp(r'\.lua$', caseSensitive: false), ''),
      );

      if (preset.category == LuaPresetCategory.audioFx) {
        addFXInsert(activeTrack, FXType.distortion);
        final fx = activeTrack.fxRack.last;
        fx.name = preset.name;
        notifyListeners();
        return;
      }

      final trackId = 'track_${DateTime.now().millisecondsSinceEpoch}';
      final trackColors = [
        const Color(0xFF21F4E8),
        const Color(0xFFFF8C00),
        const Color(0xFF00FF66),
        const Color(0xFFFF0055),
        const Color(0xFFBD00FF),
      ];
      final color = trackColors[activePattern.tracks.length % trackColors.length];

      final newTrack = TrackChannel(
        id: trackId,
        name: preset.name,
        type: TrackType.luaScript,
        color: color,
        luaScriptCode: preset.code,
      );

      final clip = TrackClip(
        id: 'clip_${trackId}_0',
        name: preset.name,
        trackId: trackId,
        startBar: startBar,
        barLength: barLength,
      );

      newTrack.clips.add(clip);
      activePattern.tracks.add(newTrack);
      activeTrackIndex = activePattern.tracks.length - 1;
      notifyListeners();
      return;
    }

    final isSf2 = cleanName.toLowerCase().endsWith('.sf2');


    if (isSf2) {
      SoundFontEngine.instance.registerSoundFont(cleanName, fileBytes);
    } else {
      final registered = SamplerEngine.instance.registerSampleBytes(cleanName, fileBytes);
      if (!registered) {
        debugPrint('Failed to register sample bytes for $cleanName');
      }
    }

    final trackId = 'track_${DateTime.now().millisecondsSinceEpoch}';
    final trackName = cleanName
        .replaceAll(RegExp(r'\.(wav|mp3|ogg|flac|sf2)$', caseSensitive: false), '')
        .trim();

    final trackColors = [
      const Color(0xFF21F4E8),
      const Color(0xFFFF8C00),
      const Color(0xFF00FF66),
      const Color(0xFFFF0055),
      const Color(0xFFBD00FF),
    ];
    final color = trackColors[activePattern.tracks.length % trackColors.length];

    final presetId = isSf2 ? 'soundfont_sampler' : 'sampler_instrument';

    final newTrack = TrackChannel(
      id: trackId,
      name: trackName.isEmpty ? (isSf2 ? 'SoundFont Track' : 'Sample Track') : trackName,
      type: TrackType.sampler,
      sampleName: cleanName,
      color: color,
      luaScriptCode: LuaPresetLibrary.presets.firstWhere(
        (p) => p.id == presetId,
        orElse: () => LuaPresetLibrary.presets.first,
      ).code,
    );

    final clip = TrackClip(
      id: 'clip_${trackId}_0',
      name: cleanName,
      trackId: trackId,
      startBar: startBar,
      barLength: barLength,
    );
    clip.notes.add(Note(
      id: 'note_${trackId}_0',
      pitch: 60,
      startStep: 0.0,
      durationSteps: (barLength * 16).toDouble(),
      velocity: 0.9,
    ));
    newTrack.clips.add(clip);

    activePattern.tracks.add(newTrack);
    activeTrackIndex = activePattern.tracks.length - 1;
    notifyListeners();
  }

  /// Imports a Standard MIDI File (.mid / .midi) bytes into the project.
  /// Matches MIDI tracks against existing tracks in the active pattern by name
  /// (e.g. SongGen tracks: 'Track 1', 'Drums', 'Bass', 'Chords', 'Lead') and replaces their notes.
  /// Unmatched tracks with notes are appended as new tracks using appropriate SoundFont/GM presets.
  /// Also synchronizes project BPM from the MIDI tempo track.
  bool importMidiFileBytes(Uint8List midiBytes, {String fileName = 'imported.mid'}) {
    final parsedSong = MidiFileParser.parse(midiBytes);
    if (parsedSong == null || parsedSong.tracks.isEmpty) {
      debugPrint('importMidiFileBytes: Failed to parse MIDI from $fileName');
      return false;
    }

    final cleanName = fileName
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'\.(mid|midi)$', caseSensitive: false), '');
    beginHistoryTransaction('Import MIDI: $cleanName', icon: Icons.album);

    // 1. Sync BPM if specified
    if (parsedSong.bpm != null && parsedSong.bpm! > 0) {
      final roundedBpm = ((parsedSong.bpm! * 100).round()) / 100.0;
      setBpm(roundedBpm);
    }

    final tracksToProcess = parsedSong.tracks.where((t) => t.notes.isNotEmpty).toList();
    final matchedTrackIds = <String>{};
    int replacedCount = 0;
    int createdCount = 0;

    for (final midiTrack in tracksToProcess) {
      final midiNameLower = midiTrack.name.toLowerCase().trim();

      // Match against existing project tracks
      TrackChannel? targetTrack;

      // 1. Exact or normalized match
      for (final track in activePattern.tracks) {
        if (matchedTrackIds.contains(track.id)) continue;
        final trackNameLower = track.name.toLowerCase().trim();

        if (trackNameLower == midiNameLower) {
          targetTrack = track;
          break;
        }
      }

      // 2. Fuzzy / SongGen semantic matching if exact match not found
      if (targetTrack == null) {
        for (final track in activePattern.tracks) {
          if (matchedTrackIds.contains(track.id)) continue;
          final trackNameLower = track.name.toLowerCase().trim();

          final isDrumsMatch = (midiNameLower.contains('drum') || midiTrack.channel == 9) &&
              (trackNameLower.contains('drum') || track.iconName == 'drums');
          final isBassMatch = midiNameLower.contains('bass') &&
              (trackNameLower.contains('bass') || track.iconName == 'bass');
          final isChordsMatch = (midiNameLower.contains('chord') ||
                  midiNameLower.contains('key') ||
                  midiNameLower.contains('piano') ||
                  midiNameLower.contains('harmony')) &&
              (trackNameLower.contains('chord') ||
                  trackNameLower.contains('key') ||
                  trackNameLower.contains('piano') ||
                  trackNameLower.contains('rhodes') ||
                  trackNameLower.contains('harmony'));
          final isLeadMatch = (midiNameLower.contains('lead') ||
                  midiNameLower.contains('solo') ||
                  midiNameLower.contains('melody')) &&
              (trackNameLower.contains('lead') ||
                  trackNameLower.contains('solo') ||
                  trackNameLower.contains('melody') ||
                  trackNameLower.contains('synth'));
          final isTrack1Match = (midiNameLower == 'track 1' || midiNameLower == 'track1') &&
              (trackNameLower == 'track 1' ||
                  trackNameLower == 'track1' ||
                  trackNameLower.contains('intro') ||
                  trackNameLower.contains('melody'));

          if (isDrumsMatch || isBassMatch || isChordsMatch || isLeadMatch || isTrack1Match) {
            targetTrack = track;
            break;
          }
        }
      }

      if (targetTrack != null) {
        // Target track found: replace contents!
        matchedTrackIds.add(targetTrack.id);
        replacedCount++;
        _replaceTrackNotesWithMidi(targetTrack, midiTrack);
      } else {
        // Unmatched track: create new track with appropriate preset
        createdCount++;
        _createNewTrackFromMidi(midiTrack);
      }
    }

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();
    debugPrint(
        'Successfully imported MIDI "$fileName": Replaced $replacedCount tracks, created $createdCount tracks, BPM: $bpm');
    return true;
  }

  void _replaceTrackNotesWithMidi(TrackChannel track, ParsedMidiTrack midiTrack) {
    final totalBars = midiTrack.totalBars;
    track.clips.clear();
    track.notes.clear();

    final clip = TrackClip(
      id: 'clip_${track.id}_${DateTime.now().millisecondsSinceEpoch}_${midiTrack.trackIndex}',
      name: '${track.name} Clip',
      trackId: track.id,
      startBar: 0,
      barLength: totalBars,
      notes: midiTrack.notes.map((n) => n.copyWith()).toList(),
    );

    track.clips.add(clip);
    track.notes = clip.notes.map((n) => n.copyWith()).toList();

    // Populate step sequencer grid for the first 16 steps
    for (int i = 0; i < track.steps.length; i++) {
      final notesAtStep = midiTrack.notes.where((n) => n.startStep.toInt() == i).toList();
      if (notesAtStep.isNotEmpty) {
        track.steps[i] = StepEvent(
          active: true,
          pitch: notesAtStep.first.pitch,
          velocity: notesAtStep.first.velocity,
        );
      } else {
        track.steps[i] = StepEvent(active: false);
      }
    }
  }

  void _createNewTrackFromMidi(ParsedMidiTrack midiTrack) {
    final trackId = 'track_${DateTime.now().millisecondsSinceEpoch}_${midiTrack.trackIndex}';
    final trackColors = [
      const Color(0xFF21F4E8),
      const Color(0xFFFF8C00),
      const Color(0xFF00FF66),
      const Color(0xFFFF0055),
      const Color(0xFFBD00FF),
    ];
    final color = trackColors[activePattern.tracks.length % trackColors.length];
    final lowerName = midiTrack.name.toLowerCase();

    String iconName = 'synth';
    TrackType trackType = TrackType.luaScript;
    String presetId = 'soundfont_sampler';
    String sampleName = 'super_small_font.sf2';
    double presetNum = (midiTrack.programNumber ?? 0).toDouble();

    if (midiTrack.channel == 9 || lowerName.contains('drum')) {
      iconName = 'drums';
      trackType = TrackType.sampler;
      sampleName = 'super_small_font.sf2';
      presetNum = 0.0;
    } else if (lowerName.contains('bass')) {
      iconName = 'bass';
      presetNum = 33.0; // Electric Bass (finger)
    } else if (lowerName.contains('chord') ||
        lowerName.contains('piano') ||
        lowerName.contains('key')) {
      iconName = 'piano';
      presetNum = 0.0; // Acoustic Grand Piano
    } else if (lowerName.contains('lead') ||
        lowerName.contains('melody') ||
        lowerName.contains('solo')) {
      iconName = 'synth';
      presetNum = 80.0; // Lead 1 (square)
    }

    final sfPreset = LuaPresetLibrary.presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => LuaPresetLibrary.presets.first,
    );

    final newTrack = TrackChannel(
      id: trackId,
      name: midiTrack.name,
      type: trackType,
      color: color,
      sampleName: sampleName,
      iconName: iconName,
      luaScriptCode: sfPreset.code,
      luaParams: {
        'PresetNum': presetNum,
        'BankNum': (midiTrack.channel == 9) ? 128.0 : 0.0,
      },
    );

    final totalBars = midiTrack.totalBars;
    final clip = TrackClip(
      id: 'clip_${trackId}_0',
      name: '${midiTrack.name} Clip',
      trackId: trackId,
      startBar: 0,
      barLength: totalBars,
      notes: midiTrack.notes.map((n) => n.copyWith()).toList(),
    );

    newTrack.clips.add(clip);
    newTrack.notes = clip.notes.map((n) => n.copyWith()).toList();

    // Step sequencer grid
    for (int i = 0; i < newTrack.steps.length; i++) {
      final notesAtStep = midiTrack.notes.where((n) => n.startStep.toInt() == i).toList();
      if (notesAtStep.isNotEmpty) {
        newTrack.steps[i] = StepEvent(
          active: true,
          pitch: notesAtStep.first.pitch,
          velocity: notesAtStep.first.velocity,
        );
      } else {
        newTrack.steps[i] = StepEvent(active: false);
      }
    }

    activePattern.tracks.add(newTrack);
  }

  void loadLuaPreset(LuaPreset preset) {
    luaCode = preset.code;
    compileLuaCode(preset.code);
  }

  void updateLuaParam(String paramName, double value) {
    activeTrack.luaParams[paramName] = value;
    notifyListeners();
  }

  void setPatternLength(Pattern pattern, int length) {
    pattern.lengthSteps = length;
    notifyListeners();
  }

  void removeArrangementItem(int index) {
    if (index >= 0 && index < arrangement.length) {
      arrangement.removeAt(index);
      notifyListeners();
    }
  }

  void setTrackActiveView(TrackChannel track, MusicViewType viewType) {
    track.activeView = viewType;
    notifyListeners();
  }

  void setTrackerColumns(TrackChannel track, int columns) {
    track.trackerColumns = columns.clamp(1, 8);
    if (trackerSelectedColumn >= track.trackerColumns) {
      trackerSelectedColumn = track.trackerColumns - 1;
    }
    notifyListeners();
  }

  // Tracker State & Editing
  int trackerSelectedStep = 0;
  int trackerSelectedColumn = 0;

  void selectTrackerCell(int step, int column) {
    trackerSelectedStep = step.clamp(0, activePattern.lengthSteps - 1);
    trackerSelectedColumn = column.clamp(0, activeTrack.trackerColumns - 1);
    notifyListeners();
  }

  void addOrUpdateTrackerNote({
    required int pitch,
    double velocity = 0.85,
    bool autoAdvance = true,
  }) {
    final track = activeTrack;
    track.notes.removeWhere(
      (n) => n.startStep.toInt() == trackerSelectedStep && n.column == trackerSelectedColumn,
    );

    track.notes.add(
      Note(
        id: 'trk_${DateTime.now().millisecondsSinceEpoch}',
        pitch: pitch,
        startStep: trackerSelectedStep.toDouble(),
        durationSteps: 1.0,
        velocity: velocity,
        column: trackerSelectedColumn,
      ),
    );

    audioEngine.playNoteOrSample(
      track: track,
      midiNote: pitch,
      velocity: velocity,
    );

    if (autoAdvance) {
      trackerSelectedStep = (trackerSelectedStep + 1) % activePattern.lengthSteps;
    }

    _syncClipNotes(track);
    notifyListeners();
  }

  void deleteTrackerNoteAtSelectedCell() {
    final track = activeTrack;
    track.notes.removeWhere(
      (n) => n.startStep.toInt() == trackerSelectedStep && n.column == trackerSelectedColumn,
    );
    _syncClipNotes(track);
    notifyListeners();
  }

  void deleteTrackerNotesInBlock({
    required int startStep,
    required int endStep,
    required int startCol,
    required int endCol,
  }) {
    final minS = math.min(startStep, endStep);
    final maxS = math.max(startStep, endStep);
    final minC = math.min(startCol, endCol);
    final maxC = math.max(startCol, endCol);

    final track = activeTrack;
    track.notes.removeWhere(
      (n) => n.startStep.toInt() >= minS && n.startStep.toInt() <= maxS && n.column >= minC && n.column <= maxC,
    );
    _syncClipNotes(track);
    recordHistory('Clear Tracker Block ($minS..$maxS, C$minC..C$maxC)', icon: Icons.delete_outline);
    notifyListeners();
  }

  void transposeTrackerNotesInBlock({
    required int startStep,
    required int endStep,
    required int startCol,
    required int endCol,
    required int semitones,
  }) {
    if (semitones == 0) return;
    final minS = math.min(startStep, endStep);
    final maxS = math.max(startStep, endStep);
    final minC = math.min(startCol, endCol);
    final maxC = math.max(startCol, endCol);

    final track = activeTrack;
    for (final n in track.notes) {
      if (n.startStep.toInt() >= minS && n.startStep.toInt() <= maxS && n.column >= minC && n.column <= maxC) {
        n.pitch = (n.pitch + semitones).clamp(0, 127);
      }
    }
    _syncClipNotes(track);
    recordHistory('Transpose Tracker Block by ${semitones > 0 ? "+$semitones" : semitones}', icon: Icons.tune);
    notifyListeners();
  }

  // WAV Song Export


  void exportWavSong() {
    final int totalSamples = (44100 * (60.0 / _bpm) * 16).toInt();
    final leftBuffer = List<double>.filled(totalSamples, 0.0);
    final rightBuffer = List<double>.filled(totalSamples, 0.0);

    // Simple audio render pass
    for (int i = 0; i < totalSamples; i++) {
      final t = i / 44100.0;
      final osc = math.sin(2.0 * math.pi * 120.0 * t) * math.exp(-t * 2.0);
      leftBuffer[i] = osc * 0.7;
      rightBuffer[i] = osc * 0.7;
    }

    final wavBytes = WavExporter.encodeWav(
      leftSamples: leftBuffer,
      rightSamples: rightBuffer,
    );

    WavExporter.saveWavFile(wavBytes, 'eatsbeats_song.wav');
  }

  // ==========================================
  // Lyrics & TTS Management API
  // ==========================================

  void addLyricCue(TrackChannel track, LyricCue cue, {TrackClip? clip}) {
    if (clip != null) {
      clip.lyrics.removeWhere((c) => c.id == cue.id);
      clip.lyrics.add(cue);
      clip.lyrics.sort((a, b) => a.startStep.compareTo(b.startStep));
    } else {
      track.lyrics.removeWhere((c) => c.id == cue.id);
      track.lyrics.add(cue);
      track.lyrics.sort((a, b) => a.startStep.compareTo(b.startStep));
    }
    recordHistory('Add Lyric "${cue.text}" to ${track.name}', icon: Icons.short_text);
    triggerAutoSave();
    notifyListeners();
  }

  void updateLyricCue(TrackChannel track, LyricCue cue, {TrackClip? clip}) {
    if (clip != null) {
      final idx = clip.lyrics.indexWhere((c) => c.id == cue.id);
      if (idx != -1) {
        clip.lyrics[idx] = cue;
      }
    } else {
      final idx = track.lyrics.indexWhere((c) => c.id == cue.id);
      if (idx != -1) {
        track.lyrics[idx] = cue;
      }
    }
    recordHistory('Edit Lyric "${cue.text}"', icon: Icons.edit);
    triggerAutoSave();
    notifyListeners();
  }

  void removeLyricCue(TrackChannel track, String cueId, {TrackClip? clip}) {
    if (clip != null) {
      clip.lyrics.removeWhere((c) => c.id == cueId);
    } else {
      track.lyrics.removeWhere((c) => c.id == cueId);
    }
    recordHistory('Remove Lyric Cue', icon: Icons.delete_outline);
    triggerAutoSave();
    notifyListeners();
  }

  void clearTrackLyrics(TrackChannel track, {TrackClip? clip}) {
    if (clip != null) {
      clip.lyrics.clear();
    } else {
      track.lyrics.clear();
    }
    recordHistory('Clear Lyrics for ${track.name}', icon: Icons.clear_all);
    triggerAutoSave();
    notifyListeners();
  }

  void importLrcToTrack(TrackChannel track, String lrcContent, {TrackClip? clip}) {
    final parsed = LrcParser.parse(lrcContent, bpm: _bpm);
    if (clip != null) {
      clip.lyrics = parsed;
    } else {
      track.lyrics = parsed;
    }
    recordHistory('Import LRC Lyrics (${parsed.length} cues)', icon: Icons.file_upload);
    triggerAutoSave();
    notifyListeners();
  }

  String exportTrackLrc(TrackChannel track, {TrackClip? clip}) {
    final cues = clip != null ? clip.lyrics : track.lyrics;
    return LrcParser.exportToLrc(cues, bpm: _bpm, title: projectName, artist: authorName);
  }

  void setTrackTts(
    TrackChannel track, {
    bool? enableTts,
    String? voice,
    double? pitch,
    double? rate,
    double? volume,
  }) {
    if (enableTts != null) track.enableTts = enableTts;
    if (voice != null) track.ttsVoice = voice;
    if (pitch != null) track.ttsPitch = pitch;
    if (rate != null) track.ttsRate = rate;
    if (volume != null) track.ttsVolume = volume;
    recordHistory('Update TTS Config for ${track.name}', icon: Icons.record_voice_over);
    triggerAutoSave();
    notifyListeners();
  }

  void setNoteLyric(TrackChannel track, Note note, String? lyric) {
    note.lyric = lyric?.trim().isEmpty == true ? null : lyric?.trim();
    _syncClipNotes(track);
    recordHistory('Set Note Lyric: "${note.lyric ?? ''}"', icon: Icons.short_text);
    triggerAutoSave();
    notifyListeners();
  }
}
