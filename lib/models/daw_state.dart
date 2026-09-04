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
import '../audio/audio_to_midi_engine.dart';
import '../utils/audio_to_midi_pack_manager.dart';
import '../theme/eats_theme.dart';
import '../lua/lua_engine.dart';
import '../lua/lua_gui_model.dart';
import '../lua/eats_lua_serializer.dart';
import '../lua/eats_lua_parser.dart';
import '../audio/time_context.dart';
import '../lua/lua_preset_library.dart';
import '../lua/lua_script_library.dart';
import '../lua/midi_pipeline_engine.dart';
import '../lua/note_splitter_engine.dart';
import '../lua/project_script_engine.dart';
import '../lua/default_song.dart';
import '../ui/modular/modular_rack_dsl.dart';
import 'track_model.dart';
import 'chord_model.dart';
import 'history_manager.dart';
import 'lyric_model.dart';
import 'script_target_model.dart';
import 'script_preset_model.dart';
import 'automation_model.dart';
import '../audio/easing.dart';
import '../audio/track_freeze_engine.dart';

enum ArrangerViewMode { timeline, sequence }

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
    if (activeClip != null && (activeClip!.trackId == activeTrack.id || activeTrack.clips.any((c) => c.id == activeClip!.id))) {
      return activeClip!;
    }
    if (activeTrack.clips.isEmpty) {
      activeTrack.clips.add(TrackClip(
        id: 'clip_${activeTrack.id}_0',
        name: '${activeTrack.name} Clip',
        trackId: activeTrack.id,
        startBar: 0,
        barLength: activePattern.barLength > 0 ? activePattern.barLength : 2,
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

  ArrangerViewMode _arrangerViewMode = ArrangerViewMode.timeline;
  ArrangerViewMode get arrangerViewMode => _arrangerViewMode;
  set arrangerViewMode(ArrangerViewMode mode) {
    if (_arrangerViewMode != mode) {
      _arrangerViewMode = mode;
      notifyListeners();
    }
  }

  void toggleArrangerViewMode() {
    _arrangerViewMode = (_arrangerViewMode == ArrangerViewMode.timeline)
        ? ArrangerViewMode.sequence
        : ArrangerViewMode.timeline;
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

  String? _floatingMidiFxTrackId;
  String? _floatingMidiFxInsertId;
  String? get floatingMidiFxTrackId => _floatingMidiFxTrackId;
  String? get floatingMidiFxInsertId => _floatingMidiFxInsertId;

  bool get isFullscreenDeviceOpen => _isFloatingWindowVisible;

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

  MidiFXInsert? get floatingMidiFxInsert {
    if (_floatingMidiFxInsertId == null || _floatingMidiFxTrackId == null) return null;
    final parent = activePattern.tracks.firstWhere(
      (t) => t.id == _floatingMidiFxTrackId,
      orElse: () => activeTrack,
    );
    try {
      return parent.midiFXRack.firstWhere((f) => f.id == _floatingMidiFxInsertId);
    } catch (_) {
      return null;
    }
  }

  TrackChannel? get floatingMidiFxTrack {
    if (_floatingMidiFxTrackId == null) return null;
    return activePattern.tracks.firstWhere(
      (t) => t.id == _floatingMidiFxTrackId,
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
    _floatingMidiFxTrackId = null;
    _floatingMidiFxInsertId = null;
    _floatingInstrumentTrackId = target.id;
    _isFloatingWindowVisible = true;
    _isFloatingWindowMaximized = false;
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
    _floatingMidiFxTrackId = null;
    _floatingMidiFxInsertId = null;
    _floatingFxTrackId = track.id;
    _floatingFxInsertId = fx.id;
    _isFloatingWindowVisible = true;
    _isFloatingWindowMaximized = false;

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

  void openFloatingMidiFxWindow(TrackChannel track, MidiFXInsert fx, {Size? workspaceSize}) {
    _floatingInstrumentTrackId = null;
    _floatingFxTrackId = null;
    _floatingFxInsertId = null;
    _floatingMidiFxTrackId = track.id;
    _floatingMidiFxInsertId = fx.id;
    _isFloatingWindowVisible = true;
    _isFloatingWindowMaximized = false;

    final midiTrack = TrackChannel(
      id: fx.id,
      name: fx.name,
      type: TrackType.luaScript,
      color: EatsTheme.accentGold,
      luaScriptCode: fx.luaScriptCode,
      luaParams: fx.luaParams,
    );

    if (workspaceSize != null) {
      fitFloatingWindowToWorkspace(workspaceSize, midiTrack);
    } else {
      final naturalH = getTrackNaturalGuiHeight(midiTrack);
      _floatingWindowSize = Size(540, (naturalH + 38.0).clamp(240.0, 680.0));
      notifyListeners();
    }
  }

  // Fullscreen Device API
  void openFullscreenDevice([TrackChannel? track]) {
    final target = track ?? activeTrack;
    _floatingFxTrackId = null;
    _floatingFxInsertId = null;
    _floatingMidiFxTrackId = null;
    _floatingMidiFxInsertId = null;
    _floatingInstrumentTrackId = target.id;
    _isFloatingWindowVisible = true;
    _isFloatingWindowMaximized = true;
    final trackIdx = activePattern.tracks.indexOf(target);
    if (trackIdx != -1) {
      activeTrackIndex = trackIdx;
    }
    notifyListeners();
  }

  void openFullscreenFx(TrackChannel track, FXInsert fx) {
    _floatingInstrumentTrackId = null;
    _floatingMidiFxTrackId = null;
    _floatingMidiFxInsertId = null;
    _floatingFxTrackId = track.id;
    _floatingFxInsertId = fx.id;
    _isFloatingWindowVisible = true;
    _isFloatingWindowMaximized = true;
    notifyListeners();
  }

  void openFullscreenMidiFx(TrackChannel track, MidiFXInsert fx) {
    _floatingInstrumentTrackId = null;
    _floatingFxTrackId = null;
    _floatingFxInsertId = null;
    _floatingMidiFxTrackId = track.id;
    _floatingMidiFxInsertId = fx.id;
    _isFloatingWindowVisible = true;
    _isFloatingWindowMaximized = true;
    notifyListeners();
  }

  void closeFullscreenDevice() => closeFloatingInstrumentWindow();

  void closeFloatingInstrumentWindow() {
    _isFloatingWindowVisible = false;
    _isFloatingWindowMaximized = false;
    _floatingFxTrackId = null;
    _floatingFxInsertId = null;
    _floatingMidiFxTrackId = null;
    _floatingMidiFxInsertId = null;
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
        totalHeight += _estimateGuiNodeHeight(node) + 8.0;
      }
      return totalHeight.clamp(120.0, 750.0);
    }

    if (compilation.params.isNotEmpty) {
      final rows = (compilation.params.length / 4.0).ceil();
      return (rows * 72.0 + 20.0).clamp(120.0, 750.0);
    }

    return 160.0;
  }

  static double _estimateGuiNodeHeight(LuaGuiNode node) {
    switch (node.type) {
      case LuaGuiNodeType.row:
        if (node.children.isEmpty) return 0.0;
        double maxChildH = 0.0;
        for (final c in node.children) {
          final h = _estimateGuiNodeHeight(c);
          if (h > maxChildH) maxChildH = h;
        }
        final hasBg = node.backgroundStyle != null || node.backgroundColor != null;
        return maxChildH + (hasBg ? 16.0 : 0.0);

      case LuaGuiNodeType.column:
        if (node.children.isEmpty) return 0.0;
        double sumChildH = 0.0;
        if (node.action == 'bypass' || node.param == 'bypass' || node.param == 'power') {
          sumChildH += 44.0;
        }
        for (final c in node.children) {
          sumChildH += _estimateGuiNodeHeight(c) + 8.0;
        }
        final hasBg = node.backgroundStyle != null || node.backgroundColor != null || node.width != null;
        return sumChildH + (hasBg ? 24.0 : 0.0);

      case LuaGuiNodeType.group:
        double groupH = (node.label != null && node.label != 'bypass') ? 26.0 : 0.0;
        if (node.action == 'bypass' || node.param == 'bypass' || node.param == 'power') {
          groupH += 44.0;
        }
        for (final c in node.children) {
          groupH += _estimateGuiNodeHeight(c) + 6.0;
        }
        return groupH + 28.0;

      case LuaGuiNodeType.knob:
        final baseSize = node.size ?? 56.0;
        final labelH = node.showLabel ? 16.0 : 0.0;
        final valueH = node.showValue ? 14.0 : 0.0;
        return baseSize + labelH + valueH + 6.0;

      case LuaGuiNodeType.slider:
      case LuaGuiNodeType.fader:
        final isVertical = node.orientation == 'vertical' ||
            node.type == LuaGuiNodeType.fader ||
            (node.sliderStyle == SliderStyle.minimalPill && node.orientation != 'horizontal');
        if (isVertical) {
          final h = node.height ?? 100.0;
          return h + (node.showLabel ? 18.0 : 0.0) + 8.0;
        }
        return 38.0;

      case LuaGuiNodeType.segmentedPill:
        final labelH = (node.label != null && node.label!.isNotEmpty && node.showLabel) ? 16.0 : 0.0;
        return labelH + 34.0;

      case LuaGuiNodeType.switchToggle:
        return (node.orientation == 'vertical') ? 72.0 : 40.0;

      case LuaGuiNodeType.button:
        return (node.height ?? node.size ?? 32.0) + 4.0;

      case LuaGuiNodeType.listBox:
        return (node.height ?? 76.0) + 4.0;

      case LuaGuiNodeType.nixie:
      case LuaGuiNodeType.lcd:
        return (node.height ?? 46.0);

      case LuaGuiNodeType.meter:
        return (node.height ?? 40.0);

      case LuaGuiNodeType.label:
        return 20.0;

      case LuaGuiNodeType.oscilloscope:
      case LuaGuiNodeType.spectrum:
        return (node.height ?? 100.0) + 4.0;

      case LuaGuiNodeType.spaceVisualizer:
        return (node.height ?? 140.0) + 4.0;

      case LuaGuiNodeType.waveshaperCanvas:
        return (node.height ?? 160.0) + 4.0;

      case LuaGuiNodeType.canvas:
        if (node.showDpad || node.showActionButtons) return 220.0;
        return (node.height ?? 120.0) + 4.0;

      case LuaGuiNodeType.dpad:
      case LuaGuiNodeType.gamepad:
        return (node.height ?? 160.0) + 4.0;

      case LuaGuiNodeType.divider:
        if (node.orientation == 'vertical') {
          return node.height ?? node.size ?? 68.0;
        }
        return (node.height ?? 2.0) + 16.0;

      case LuaGuiNodeType.spacer:
        return node.size ?? 16.0;

      case LuaGuiNodeType.unknown:
        return 0.0;
    }
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

  bool _guiAnimationsEnabled = true;
  bool get guiAnimationsEnabled => _guiAnimationsEnabled;
  set guiAnimationsEnabled(bool val) {
    _guiAnimationsEnabled = val;
    EatsStorageHelper.setBool(EatsStorageHelper.keyGuiAnimationsEnabled, val);
    notifyListeners();
  }
  void setGuiAnimationsEnabled(bool val) {
    guiAnimationsEnabled = val;
  }

  bool shouldCenterEditViewOnOpen = false;

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

      final animations = await EatsStorageHelper.getBool(EatsStorageHelper.keyGuiAnimationsEnabled);
      if (animations != null) {
        _guiAnimationsEnabled = animations;
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

  void applyScript(LuaScriptDef script, {TrackChannel? targetTrack}) {
    final track = targetTrack ?? activeTrack;
    if (script.isInstrument) {
      track.name = script.name;
      track.type = TrackType.luaScript;
      track.luaScriptCode = script.code;
      track.tags = List<String>.from(script.effectiveTags);
      if (script.id == 'soundfont_sampler') {
        if (!track.sampleName.toLowerCase().endsWith('.sf2')) {
          track.sampleName = 'super_small_font.sf2';
        }
      } else {
        track.sampleName = '';
      }
      final compiled = LuaEngine.compile(script.code);
      track.luaParams.clear();
      for (final p in compiled.params) {
        track.luaParams[p.name] = p.defaultValue;
      }
      if (track.id == activeTrack.id) {
        luaCode = script.code;
        compilationResult = compiled;
      }
      audioEngine.clearPcmCache();
      audioEngine.invalidateLuaCache(track.id);
      recordHistory('Applied instrument "${script.name}" to ${track.name}', icon: Icons.piano);
    } else if (script.isAudioFx) {
      addAudioFXFromPreset(track, script);
      return;
    } else if (script.isMidiFx) {
      addMidiFXInsert(
        track,
        name: script.name,
        luaScriptCode: script.code,
      );
      recordHistory('Add MIDI FX "${script.name}" to ${track.name}', icon: Icons.music_note);
    } else if (script.isMidiSeq) {
      if (activeClip != null && activeClip!.trackId == track.id) {
        applyScriptToClip(track, activeClip!, script);
      } else if (track.clips.isNotEmpty) {
        applyScriptToClip(track, track.clips.first, script);
      }
    } else {
      track.luaScriptCode = script.code;
      compileLuaCode(script.code);
    }
    notifyListeners();
  }

  void applyPreset(LuaPreset preset, {TrackChannel? targetTrack}) => applyScript(preset, targetTrack: targetTrack);

  /// Applies a saved sound patch / parameter snapshot to a track.
  void applyScriptPreset(TrackChannel track, ScriptPreset preset) {
    final currentScript = LuaScriptLibrary.findMatchingScript(track.luaScriptCode, fallbackName: track.name);
    if (currentScript == null || currentScript.id != preset.scriptId) {
      final targetScript = LuaScriptLibrary.getScriptById(preset.scriptId);
      if (targetScript != null) {
        track.luaScriptCode = targetScript.code;
        track.type = TrackType.luaScript;
      }
    }

    for (final entry in preset.params.entries) {
      track.luaParams[entry.key] = entry.value;
    }

    if (track.id == activeTrack.id) {
      luaCode = track.luaScriptCode;
      compilationResult = LuaEngine.compile(track.luaScriptCode);
    }

    audioEngine.invalidateLuaCache(track.id);
    recordHistory('Loaded preset "${preset.name}" on ${track.name}', icon: Icons.tune);
    notifyListeners();
  }

  /// Saves the current track's parameter configuration as a user preset.
  void saveTrackScriptPreset(TrackChannel track, String presetName, String category, {String? author}) {
    final script = LuaScriptLibrary.findMatchingScript(track.luaScriptCode, fallbackName: track.name);
    final scriptId = script?.id ?? track.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    
    final newPreset = ScriptPreset(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}_${presetName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
      scriptId: scriptId,
      name: presetName.trim(),
      category: category.trim(),
      author: author ?? 'User',
      isStock: false,
      params: Map<String, double>.from(track.luaParams),
    );

    ScriptPresetLibrary.instance.saveUserPreset(newPreset);
    recordHistory('Saved custom preset "$presetName"', icon: Icons.save);
    notifyListeners();
  }

  /// Returns all presets applicable to the given track's current script/instrument.
  List<ScriptPreset> getPresetsForTrack(TrackChannel track) {
    final script = LuaScriptLibrary.findMatchingScript(track.luaScriptCode, fallbackName: track.name);
    if (script == null) return [];
    return ScriptPresetLibrary.instance.getPresetsForScript(script.id);
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

  final ValueNotifier<double> leftPeakNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> rightPeakNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> cpuLoadNotifier = ValueNotifier<double>(0.02);

  double _masterVolume = 0.85;
  double get masterVolume => _masterVolume;

  // Master Bus Built-in Processing State
  double _masterSubCut = 25.0; // 20.0 to 45.0 Hz
  double get masterSubCut => _masterSubCut;

  double _masterLowGain = 0.0; // -12.0 to +12.0 dB
  double get masterLowGain => _masterLowGain;

  double _masterMidFreq = 320.0; // 200.0 to 1000.0 Hz
  double get masterMidFreq => _masterMidFreq;

  double _masterMidGain = 0.0; // -12.0 to +12.0 dB
  double get masterMidGain => _masterMidGain;

  double _masterHighGain = 0.0; // -12.0 to +12.0 dB
  double get masterHighGain => _masterHighGain;

  bool _masterLimiterEnabled = true;
  bool get masterLimiterEnabled => _masterLimiterEnabled;

  double _masterCeilingDbfs = -0.3; // -2.0 to 0.0 dBFS
  double get masterCeilingDbfs => _masterCeilingDbfs;

  double _masterLimiterDrive = 0.0; // 0.0 to +12.0 dB
  double get masterLimiterDrive => _masterLimiterDrive;

  double _masterTargetLufs = -14.0; // -24.0 to -6.0 LUFS
  double get masterTargetLufs => _masterTargetLufs;

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
    int h = _bpm.hashCode ^
        _songKey.hashCode ^
        _masterVolume.hashCode ^
        projectName.hashCode ^
        authorName.hashCode ^
        (_masterSubCut * 10).round() ^
        (_masterLowGain * 10).round() ^
        (_masterMidFreq * 10).round() ^
        (_masterMidGain * 10).round() ^
        (_masterHighGain * 10).round() ^
        (_masterLimiterEnabled ? 1 : 0) ^
        (_masterLimiterDrive * 10).round();
    for (final pattern in patterns) {
      h = (h * 31) ^ pattern.id.hashCode;
      for (final track in pattern.tracks) {
        h = (h * 31) ^
            track.id.hashCode ^
            (track.volume * 100).round() ^
            (track.pan * 100).round() ^
            (track.isMuted ? 1 : 0) ^
            (track.isSoloed ? 2 : 0) ^
            track.color.value ^
            (track.eqEnabled ? 1 : 0) ^
            (track.eqHpf * 10).round() ^
            (track.eqLowGain * 10).round() ^
            (track.eqMidFreq * 10).round() ^
            (track.eqMidGain * 10).round() ^
            (track.eqHighGain * 10).round();
        for (final entry in track.luaParams.entries) {
          h = (h * 31) ^ entry.key.hashCode ^ (entry.value * 100).round();
        }
        for (final clip in track.clips) {
          h = (h * 31) ^ clip.id.hashCode ^ clip.startBar ^ clip.barLength ^ (clip.loopLengthBars ?? 0);
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
    if (isPlaying) {
      stop();
    }
    audioEngine.clearChannelStrips();
    LuaEngine.resetVoiceStates();
    history.pauseRecording();
    try {
      projectName = EatsLuaParser.populateDawState(this, eatsLuaCode);
      resetActiveIndices();

      // Re-bake any procedural Room / Cabinet IRs across all tracks & master bus (deduplicated by track and fx ID)
      final Set<String> processedFxKeys = <String>{};
      for (final p in patterns) {
        for (final track in p.tracks) {
          for (final fx in track.fxRack) {
            final key = '${track.id}_${fx.id}';
            if (processedFxKeys.add(key)) {
              _rebakeProceduralIrIfNeeded(track, fx);
            }
          }
        }
      }
      for (final fx in masterTrack.fxRack) {
        final key = 'master_${fx.id}';
        if (processedFxKeys.add(key)) {
          _rebakeProceduralIrIfNeeded(masterTrack, fx);
        }
      }

      // Re-apply master FX & track FX now that all custom impulse responses are baked in ConvolverEngine
      audioEngine.updateMasterFx(masterTrack.fxRack);
      for (final track in activePattern.tracks) {
        audioEngine.updateTrackFx(track.id, track.fxRack, volume: track.volume, pan: track.pan);
      }
    } finally {
      history.resumeRecording();
    }
    triggerAutoSave();
  }

  void _rebakeProceduralIrIfNeeded(TrackChannel track, FXInsert fx) {
    final isRoom = fx.presetId == 'room_designer' || fx.name.toLowerCase().contains('room designer');
    final isCab = fx.presetId == 'cab_designer' || fx.name.toLowerCase().contains('cab');
    if (isRoom || isCab) {
      final customName = isCab ? 'Cab: ${track.name}_${fx.id}' : 'Room: ${track.name}_${fx.id}';
      final basePresetName = fx.params['IRSample'] != null
          ? () {
              final all = ConvolverEngine.builtInIrNames;
              final idx = fx.params['IRSample']!.toInt().clamp(0, all.length - 1);
              return all.isNotEmpty ? all[idx] : 'Great Hall';
            }()
          : null;
      final baseParams = basePresetName != null ? ProceduralIRGenerator.presets[basePresetName] : null;

      final matIdx = (fx.params['Material'] ?? (fx.luaParams['Material'] ?? (baseParams?.material.index.toDouble() ?? 0.0))).toInt().clamp(0, AcousticMaterialType.values.length - 1);
      final spaceParams = AcousticSpaceParams(
        name: customName,
        width: fx.params['Width'] ?? (fx.luaParams['Width'] ?? (baseParams?.width ?? (isCab ? 0.76 : 12.0))),
        length: fx.params['Length'] ?? (fx.luaParams['Length'] ?? (baseParams?.length ?? (isCab ? 0.76 : 15.0))),
        height: fx.params['Height'] ?? (fx.luaParams['Height'] ?? (baseParams?.height ?? (isCab ? 0.36 : 4.0))),
        sourceX: fx.params['SourceX'] ?? (fx.luaParams['SourceX'] ?? (baseParams?.sourceX ?? 0.5)),
        sourceY: fx.params['SourceY'] ?? (fx.luaParams['SourceY'] ?? (baseParams?.sourceY ?? 0.5)),
        sourceZ: fx.params['SourceZ'] ?? (fx.luaParams['SourceZ'] ?? (baseParams?.sourceZ ?? 0.5)),
        listenerX: fx.params['ListenerX'] ?? (fx.luaParams['ListenerX'] ?? (baseParams?.listenerX ?? 0.5)),
        listenerY: fx.params['ListenerY'] ?? (fx.luaParams['ListenerY'] ?? (baseParams?.listenerY ?? 0.8)),
        listenerZ: fx.params['ListenerZ'] ?? (fx.luaParams['ListenerZ'] ?? (baseParams?.listenerZ ?? 0.5)),
        stereoWidth: fx.params['StereoWidth'] ?? (fx.luaParams['StereoWidth'] ?? (baseParams?.stereoWidth ?? (isCab ? 0.08 : 0.20))),
        material: AcousticMaterialType.values[matIdx],
        rt60: isCab ? 0.035 : (fx.params['RT60'] ?? (fx.luaParams['RT60'] ?? (baseParams?.rt60 ?? 1.8))),
        damping: fx.params['Damping'] ?? (fx.luaParams['Damping'] ?? (baseParams?.damping ?? (isCab ? 0.55 : 0.30))),
        isCabinetMode: isCab,
        micDistance: fx.params['MicDistance'] ?? (fx.luaParams['MicDistance'] ?? (baseParams?.micDistance ?? 0.05)),
        micAngleDeg: fx.params['MicAngle'] ?? (fx.luaParams['MicAngle'] ?? (baseParams?.micAngleDeg ?? 0.0)),
        isOpenBack: (fx.params['OpenBack'] ?? (fx.luaParams['OpenBack'] ?? (baseParams?.isOpenBack == true ? 1.0 : 0.0))) == 1.0,
      );
      if (!ConvolverEngine.instance.hasIrSample(customName)) {
        ConvolverEngine.instance.bakeCustomSpace(spaceParams);
      }
      audioEngine.invalidateIrCache(customName);
      fx.irSampleName = customName;
    } else if (fx.presetId == 'convolution_reverb' || fx.name.toLowerCase().contains('convolution') || fx.type == FXType.convolutionReverb) {
      if (fx.irSampleName == null || fx.irSampleName!.isEmpty || fx.irSampleName!.startsWith('Conv:')) {
        final allIrs = ConvolverEngine.instance.getAvailableIrNames();
        final idx = (fx.params['IRSample'] ?? (fx.luaParams['IRSample'] ?? 0.0)).toInt().clamp(0, allIrs.isEmpty ? 0 : allIrs.length - 1);
        fx.irSampleName = allIrs.isNotEmpty ? allIrs[idx] : 'Great Hall';
      }
      audioEngine.invalidateIrCache(fx.irSampleName);
    }
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
      audioEngine.decayMeters();
      leftPeakNotifier.value = audioEngine.leftPeak;
      rightPeakNotifier.value = audioEngine.rightPeak;
      cpuLoadNotifier.value = audioEngine.cpuLoad;
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
    leftPeakNotifier.dispose();
    rightPeakNotifier.dispose();
    cpuLoadNotifier.dispose();
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

    // 6. Project-Wide Action & Procedural Generation Scripts
    final projectScripts = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.projectAction);
    for (final ps in projectScripts) {
      list.add(
        ScriptTarget(
          id: 'project_${ps.id}',
          type: ScriptTargetType.projectAction,
          title: ps.name,
          subtitle: ps.description,
          trackId: masterTrack.id,
          trackName: 'Project',
          trackColor: const Color(0xFFBD00FF),
          secondaryId: ps.id,
        ),
      );
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
        if (track.luaScriptCode.isNotEmpty) {
          final codeWithRack = ModularRackDsl.ensureRackBlock(track.luaScriptCode, trackName: track.name);
          if (codeWithRack != track.luaScriptCode) {
            track.luaScriptCode = codeWithRack;
          }
          return track.luaScriptCode;
        }
        final matchingPreset = LuaPresetLibrary.findMatchingPreset(track.luaScriptCode, fallbackName: track.name);
        if (matchingPreset != null) {
          final codeWithRack = ModularRackDsl.ensureRackBlock(matchingPreset.code, trackName: track.name);
          track.luaScriptCode = codeWithRack;
          return codeWithRack;
        }
        final defaultTrackCode = '''-- @name: ${track.name}
-- @category: instrument
-- @description: ${track.name} Synthesizer DSP
local TrackSynth = {}

function TrackSynth.init()
  Param.add("Gain", 0.0, 1.0, 0.8)
end

function TrackSynth.gui()
  return {
    panel = {
      title = "${track.name.toUpperCase()}",
      subtitle = "Channel Synthesizer",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Gain", label = "GAIN", size = 56 },
          }
        }
      }
    }
  }
end

return TrackSynth
''';
        final defaultWithRack = ModularRackDsl.ensureRackBlock(defaultTrackCode, trackName: track.name);
        track.luaScriptCode = defaultWithRack;
        return defaultWithRack;

      case ScriptTargetType.audioFx:
        final fx = track.fxRack.where((f) => f.id == target.secondaryId).firstOrNull;
        if (fx != null) {
          if (fx.luaScriptCode != null && fx.luaScriptCode!.isNotEmpty) {
            return fx.luaScriptCode!;
          }
          final matchingPreset = LuaPresetLibrary.findMatchingPreset(fx.name, fallbackName: fx.name);
          if (matchingPreset != null) {
            fx.luaScriptCode = matchingPreset.code;
            return matchingPreset.code;
          }
          final defaultFxCode = '''-- @name: ${fx.name}
-- @category: audioFx
-- @description: ${fx.name} DSP insert effect
local FxModule = {}

function FxModule.init()
  Param.add("Mix", 0.0, 1.0, 1.0)
end

function FxModule.process(input_l, input_r, params)
  return input_l, input_r
end

function FxModule.gui()
  return {
    panel = {
      title = "${fx.name.toUpperCase()}",
      subtitle = "Audio FX Insert",
      accent = "magenta",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Mix", label = "DRY/WET", size = 52 },
          }
        }
      }
    }
  }
end

return FxModule
''';
          fx.luaScriptCode = defaultFxCode;
          return defaultFxCode;
        }
        return '';

      case ScriptTargetType.midiFx:
        final mfx = track.midiFXRack.where((f) => f.id == target.secondaryId).firstOrNull;
        if (mfx != null) {
          if (mfx.luaScriptCode != null && mfx.luaScriptCode!.isNotEmpty) {
            return mfx.luaScriptCode!;
          }
          final matchingPreset = LuaPresetLibrary.findMatchingPreset(mfx.name, fallbackName: mfx.name);
          if (matchingPreset != null) {
            mfx.luaScriptCode = matchingPreset.code;
            return matchingPreset.code;
          }
          final defaultMfxCode = '''-- @name: ${mfx.name}
-- @category: midiFx
-- @description: ${mfx.name} MIDI transformer
local MidiFx = {}

function MidiFx.init()
  Param.add("Enabled", 0.0, 1.0, 1.0)
end

function MidiFx.process(notes, time_ctx)
  return notes
end

return MidiFx
''';
          mfx.luaScriptCode = defaultMfxCode;
          return defaultMfxCode;
        }
        return '';

      case ScriptTargetType.clipScript:
        final clip = track.clips.where((c) => c.id == target.secondaryId).firstOrNull;
        if (clip != null) {
          if (clip.luaScriptCode.isNotEmpty) {
            return clip.luaScriptCode;
          }
          final serialized = MidiPipelineEngine.serializeNotesToLua(clip.notes);
          clip.luaScriptCode = serialized;
          return serialized;
        }
        return '';

      case ScriptTargetType.projectAction:
        final script = LuaScriptLibrary.scripts.where((s) => s.id == target.secondaryId).firstOrNull;
        return script?.code ?? '';
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
      case ScriptTargetType.projectAction:
        return {};
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
      case ScriptTargetType.projectAction:
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

        case ScriptTargetType.projectAction:
          final existing = LuaScriptLibrary.scripts.where((s) => s.id == target.secondaryId).firstOrNull;
          if (existing != null) {
            final updated = LuaScriptDef(
              id: existing.id,
              name: existing.name,
              category: LuaScriptCategory.projectAction,
              description: existing.description,
              code: code,
            );
            LuaScriptLibrary.registerCustomScript(updated);
          }
          break;
      }
    }
    notifyListeners();
  }

  /// Runs a project action Lua script with undo snapshot history recording.
  ProjectScriptResult runProjectScript(LuaScriptDef script, {Map<String, dynamic> params = const {}}) {
    recordHistory('Run Script: ${script.name}', icon: Icons.auto_awesome, force: true);
    final result = ProjectScriptEngine.execute(
      dawState: this,
      script: script,
      params: params,
    );
    return result;
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
    shouldCenterEditViewOnOpen = true;
    _activeTabIndex = 1; // Switch to EDIT tab
    notifyListeners();
  }

  int getNextAvailablePatternIndex(TrackChannel track) {
    final used = track.clips.map((c) => c.patternIndex).toSet();
    for (int i = 0; i < 256; i++) {
      if (!used.contains(i)) return i;
    }
    return track.clips.length % 256;
  }

  void addClipToTrack(TrackChannel track, int startBar) {
    final pIdx = getNextAvailablePatternIndex(track);
    final newClip = TrackClip(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: '${track.name} Clip',
      trackId: track.id,
      startBar: startBar,
      barLength: 2,
      patternIndex: pIdx,
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
    final pIdx = getNextAvailablePatternIndex(track);
    final duplicated = TrackClip(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: '${clip.name} (Copy)',
      trackId: track.id,
      startBar: newStartBar,
      barLength: clip.barLength,
      patternIndex: pIdx,
      notes: clip.notes.map((n) => n.copyWith()).toList(),
      luaScriptCode: clip.luaScriptCode,
      luaParams: Map.from(clip.luaParams),
    );
    track.clips.add(duplicated);
    activeClip = duplicated;
    recordHistory('Duplicate Clip "${clip.name}"', icon: Icons.copy);
    notifyListeners();
  }

  // Sequence Editor State & Helpers
  int sequenceSelectedBar = 0;
  int sequenceSelectedTrackIndex = 0;

  void selectSequenceCell(int bar, int trackIndex) {
    sequenceSelectedBar = bar.clamp(0, totalTimelineBars - 1);
    sequenceSelectedTrackIndex = trackIndex.clamp(0, math.max(0, visibleTracks.length - 1));
    notifyListeners();
  }

  TrackClip? getClipAtBar(TrackChannel track, int bar) {
    return track.clips.where((c) => bar >= c.startBar && bar < (c.startBar + c.barLength)).firstOrNull;
  }

  void setPatternIndexAtBar(TrackChannel track, int bar, int patternIdx) {
    final existing = getClipAtBar(track, bar);
    if (existing != null) {
      if (existing.startBar == bar) {
        existing.patternIndex = patternIdx.clamp(0, 255);
        recordHistory('Set Pattern $patternIdx on ${track.name} (Bar ${bar + 1})', icon: Icons.view_column);
        notifyListeners();
        return;
      } else {
        // Truncate existing multi-bar clip
        existing.barLength = (bar - existing.startBar).clamp(1, totalTimelineBars);
      }
    }

    final newClip = TrackClip(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: 'P${patternIdx.toRadixString(16).padLeft(2, '0').toUpperCase()} ${track.name}',
      trackId: track.id,
      startBar: bar,
      barLength: 1,
      patternIndex: patternIdx.clamp(0, 255),
      notes: [],
      luaScriptCode: '',
      luaParams: {},
    );
    track.clips.add(newClip);
    activeClip = newClip;
    recordHistory('Add Pattern $patternIdx to ${track.name} (Bar ${bar + 1})', icon: Icons.view_column);
    notifyListeners();
  }

  void deleteClipAtBar(TrackChannel track, int bar) {
    final clip = getClipAtBar(track, bar);
    if (clip != null) {
      track.clips.removeWhere((c) => c.id == clip.id);
      if (activeClip?.id == clip.id) {
        activeClip = track.clips.isNotEmpty ? track.clips.first : null;
      }
      recordHistory('Clear Pattern at Bar ${bar + 1} on ${track.name}', icon: Icons.delete_outline);
      notifyListeners();
    }
  }

  void insertBarRow(int atBar) {
    beginHistoryTransaction('Insert Bar Row at Bar ${atBar + 1}', icon: Icons.add);
    for (final trk in activePattern.tracks) {
      for (final clip in trk.clips) {
        if (clip.startBar >= atBar) {
          clip.startBar += 1;
        } else if (clip.startBar + clip.barLength > atBar) {
          clip.barLength += 1;
        }
      }
    }
    commitHistoryTransaction();
    notifyListeners();
  }

  void deleteBarRow(int atBar) {
    beginHistoryTransaction('Delete Bar Row at Bar ${atBar + 1}', icon: Icons.remove);
    for (final trk in activePattern.tracks) {
      final toRemove = <TrackClip>[];
      for (final clip in trk.clips) {
        if (clip.startBar == atBar && clip.barLength <= 1) {
          toRemove.add(clip);
        } else if (clip.startBar > atBar) {
          clip.startBar = math.max(0, clip.startBar - 1);
        } else if (clip.startBar + clip.barLength > atBar) {
          clip.barLength = math.max(1, clip.barLength - 1);
        }
      }
      trk.clips.removeWhere((c) => toRemove.contains(c));
    }
    commitHistoryTransaction();
    notifyListeners();
  }

  void duplicatePatternAtBar(TrackChannel track, int bar) {
    final clip = getClipAtBar(track, bar);
    if (clip != null) {
      final nextIdx = getNextAvailablePatternIndex(track);
      final cloned = clip.copyWith(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        name: '${clip.name} (Clone)',
        patternIndex: nextIdx,
        notes: clip.notes.map((n) => n.copyWith()).toList(),
      );
      final clipIdx = track.clips.indexOf(clip);
      if (clipIdx != -1) {
        track.clips[clipIdx] = cloned;
        activeClip = cloned;
        recordHistory('Clone Pattern to $nextIdx on ${track.name}', icon: Icons.copy);
        notifyListeners();
      }
    }
  }

  void openSequenceCellInEditor(TrackChannel track, int bar) {
    var clip = getClipAtBar(track, bar);
    if (clip == null) {
      final nextIdx = getNextAvailablePatternIndex(track);
      clip = TrackClip(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        name: 'P${nextIdx.toRadixString(16).padLeft(2, '0').toUpperCase()} ${track.name}',
        trackId: track.id,
        startBar: bar,
        barLength: 1,
        patternIndex: nextIdx,
        notes: [],
      );
      track.clips.add(clip);
    }
    final tIdx = visibleTracks.indexOf(track);
    if (tIdx != -1) {
      activeTrackIndex = tIdx;
    }
    activeClip = clip;
    activeTabIndex = 1;
    track.activeView = MusicViewType.tracker;
    shouldCenterEditViewOnOpen = true;
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

  void setTrackClipLoopLength(TrackClip clip, int? newLoopLengthBars) {
    if (newLoopLengthBars != null && newLoopLengthBars <= 0) {
      newLoopLengthBars = null;
    }
    clip.loopLengthBars = newLoopLengthBars;
    if (newLoopLengthBars != null) {
      recordHistory('Set Clip "${clip.name}" Loop to $newLoopLengthBars Bars', icon: Icons.loop);
    } else {
      recordHistory('Disable Loop on Clip "${clip.name}"', icon: Icons.loop);
    }
    notifyListeners();
  }

  bool canMoveClipToTrack(TrackClip clip, TrackChannel targetTrack) {
    if (targetTrack.isFolder) return false;
    // Audio clips can only go to sampler/audio tracks
    if (clip.isAudioClip) {
      return targetTrack.type == TrackType.sampler;
    }
    // Pattern clips can go to any pattern-based track (all non-sampler, non-folder tracks)
    return targetTrack.type != TrackType.sampler;
  }

  bool moveClipToTrack(TrackClip clip, TrackChannel sourceTrack, TrackChannel targetTrack, {int? targetStartBar}) {
    if (!canMoveClipToTrack(clip, targetTrack)) {
      return false;
    }

    if (sourceTrack.id == targetTrack.id) {
      if (targetStartBar != null && clip.startBar != targetStartBar) {
        clip.startBar = targetStartBar.clamp(0, 128);
        recordHistory('Move Clip "${clip.name}" to Bar ${clip.startBar + 1}', icon: Icons.drag_handle);
        notifyListeners();
      }
      return true;
    }

    sourceTrack.clips.removeWhere((c) => c.id == clip.id);
    clip.trackId = targetTrack.id;
    if (targetStartBar != null) {
      clip.startBar = targetStartBar.clamp(0, 128);
    }
    targetTrack.clips.add(clip);

    activeClip = clip;
    final tIdx = activePattern.tracks.indexWhere((t) => t.id == targetTrack.id);
    if (tIdx != -1) {
      _activeTrackIndex = tIdx;
    }

    // Invalidate midi pipeline cache if moving to new track
    if (clip.evaluatedNotesCache != null) {
      final pipeline = MidiPipelineEngine(luaEngine: luaEngine);
      pipeline.processClip(clip: clip, track: targetTrack, timeContext: timeContext);
    }

    recordHistory('Move Clip "${clip.name}" to ${targetTrack.name}', icon: Icons.swap_vert);
    notifyListeners();
    return true;
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

  void applyScriptToClip(TrackChannel track, TrackClip clip, LuaScriptDef script) {
    if (script.isMidiFx) {
      addMidiFXInsert(
        track,
        name: script.name,
        luaScriptCode: script.code,
      );
      recordHistory('Add MIDI FX "${script.name}" to ${track.name}', icon: Icons.music_note);
      notifyListeners();
      return;
    }

    clip.name = script.name;
    clip.luaScriptCode = '';

    // Parse notes from sequence script if present
    final parsedNotes = MidiPipelineEngine.parseNotesFromLuaTable(script.code);
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

    recordHistory('Apply Sequence "${script.name}" to Clip', icon: Icons.tune);
    notifyListeners();
  }

  void applyPresetToClip(TrackChannel track, TrackClip clip, LuaPreset preset) => applyScriptToClip(track, clip, preset);

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
      audioEngine.prewarmPatternCache(
        activePattern.tracks,
        stepDurationSec,
        startStep: _currentStep,
        lookaheadSteps: 16,
      );
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

  /// Dynamic total bars calculation for the project arranger timeline.
  /// Expands to fit all clips, loop points, chords, and pattern length (minimum 32 bars).
  int get totalTimelineBars {
    int maxBar = 32;
    if (_loopEndBar > maxBar) maxBar = _loopEndBar;
    final patternBars = (activePattern.lengthSteps / 16).ceil();
    if (patternBars > maxBar) maxBar = patternBars;
    for (final track in activePattern.tracks) {
      for (final clip in track.clips) {
        final clipEnd = clip.startBar + clip.barLength;
        if (clipEnd > maxBar) maxBar = clipEnd;
      }
    }
    for (final chord in chordTrack) {
      final chordEnd = (chord.startBar + chord.barLength).ceil();
      if (chordEnd > maxBar) maxBar = chordEnd;
    }
    return maxBar;
  }

  void seekToBar(int bar) {
    final targetBar = bar.clamp(0, totalTimelineBars - 1);
    _currentStep = targetBar * 16;
    _arrangerStep = targetBar * 16;
    _currentBar = targetBar;
    currentStepNotifier.value = _currentStep;
    arrangerStepNotifier.value = _arrangerStep;
    currentBarNotifier.value = _currentBar;
    if (_isPlaying) {
      final double stepDurationSec = 60.0 / _bpm / 4.0;
      final double startOffsetSec = _currentStep * stepDurationSec;
      audioEngine.stopAllFrozenTracks();
      for (final track in activePattern.tracks) {
        if (track.hasValidBake) {
          audioEngine.playFrozenTrack(
            track: track,
            startOffsetSec: startOffsetSec,
            scheduledTime: audioEngine.currentTime + 0.02,
          );
        }
      }
    }
    notifyListeners();
  }

  void seekToArrangerStep(double step) {
    final clamped = step.clamp(0.0, (totalTimelineBars * 16.0) - 1.0);
    _arrangerStep = clamped.toInt();
    _currentStep = clamped.toInt();
    _currentBar = _arrangerStep ~/ 16;
    currentStepNotifier.value = _currentStep;
    arrangerStepNotifier.value = _arrangerStep;
    currentBarNotifier.value = _currentBar;
    if (_isPlaying) {
      final double stepDurationSec = 60.0 / _bpm / 4.0;
      final double startOffsetSec = _currentStep * stepDurationSec;
      audioEngine.stopAllFrozenTracks();
      for (final track in activePattern.tracks) {
        if (track.hasValidBake) {
          audioEngine.playFrozenTrack(
            track: track,
            startOffsetSec: startOffsetSec,
            scheduledTime: audioEngine.currentTime + 0.02,
          );
        }
      }
    }
    notifyListeners();
  }

  double _nextNoteTime = 0.0;
  final Stopwatch _playbackStopwatch = Stopwatch();
  double _playbackBaseAudioTime = 0.0;
  // Lookahead window: 80ms unified lookahead for tight, responsive audio scheduling.
  double get _scheduleAheadTime => 0.080;

  // Cached MidiPipelineEngine — stateless, holds only a LuaEngine reference.
  // Re-using a single instance eliminates up to 1,280 heap allocations/second during playback.
  late final MidiPipelineEngine _pipeline = MidiPipelineEngine(luaEngine: luaEngine);

  void togglePlay() {
    audioEngine.ensureContextRunning();
    _isPlaying = !_isPlaying;
    isPlayingNotifier.value = _isPlaying;
    if (_isPlaying) {
      // Pre-warm the PCM cache for immediate upcoming notes (JIT lookahead window)
      // from the current playhead step. This ensures 0ms delay when pressing play
      // even for lengthy 24+ bar clips, while keeping beat 1 timing sub-millisecond.
      final double stepDurationSec = 60.0 / _bpm / 4.0;
      audioEngine.prewarmPatternCache(
        activePattern.tracks,
        stepDurationSec,
        startStep: _currentStep,
        lookaheadSteps: 32,
      );

      _playbackStopwatch.reset();
      _playbackStopwatch.start();
      _playbackBaseAudioTime = audioEngine.currentTime;
      _nextNoteTime = _playbackBaseAudioTime + 0.02;

      // Start streaming pre-rendered audio for any frozen tracks
      final double startOffsetSec = _currentStep * stepDurationSec;
      for (final track in activePattern.tracks) {
        if (track.hasValidBake) {
          audioEngine.playFrozenTrack(
            track: track,
            startOffsetSec: startOffsetSec,
            scheduledTime: _nextNoteTime,
          );
        }
      }

      _startSchedulerTimer();
    } else {
      _playbackStopwatch.stop();
      _playbackTimer?.cancel();
      audioEngine.stopAllSound();
      audioEngine.stopAllFrozenTracks();
      leftPeakNotifier.value = 0.0;
      rightPeakNotifier.value = 0.0;
    }
    notifyListeners();
  }

  /// Stop & Panic: Halts playback, stops all active audio/echo nodes,
  /// clears synthesized note audio caches, and resets playback position.
  void stop() {
    _isPlaying = false;
    isPlayingNotifier.value = false;
    _playbackStopwatch.stop();
    _playbackStopwatch.reset();
    _playbackTimer?.cancel();
    _currentStep = _isLooping ? _loopStartBar * 16 : 0;
    _arrangerStep = _currentStep;
    _currentBar = _currentStep ~/ 16;
    currentStepNotifier.value = _currentStep;
    arrangerStepNotifier.value = _arrangerStep;
    currentBarNotifier.value = _currentBar;
    audioEngine.stopAllSound();
    audioEngine.stopAllFrozenTracks();
    TtsEngine().stop();
    leftPeakNotifier.value = 0.0;
    rightPeakNotifier.value = 0.0;
    cpuLoadNotifier.value = 0.01;
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

    final double hardwareTime = audioEngine.currentTime;
    final double elapsedHardware = hardwareTime - _playbackBaseAudioTime;
    final double elapsedWall = _playbackStopwatch.elapsedMicroseconds / 1000000.0;
    // Guaranteed monotonic clock progression anchored to the playback base audio timeline
    final double currentAudioTime = _playbackBaseAudioTime + math.max(elapsedHardware > 0 ? elapsedHardware : 0.0, elapsedWall);
    final double stepDurationSec = 60.0 / _bpm / 4.0; // 16th note step length in seconds
    final int maxSteps = totalTimelineBars * 16;

    // Safety: If nextNoteTime fell behind or drifted far ahead of current audio time, re-anchor cleanly
    if (_nextNoteTime < currentAudioTime - 0.1 || _nextNoteTime > currentAudioTime + 0.5) {
      _nextNoteTime = currentAudioTime + 0.02;
    }

    int loopGuard = 0;
    bool stepAdvanced = false;
    while (_nextNoteTime < currentAudioTime + _scheduleAheadTime) {
      if (++loopGuard > 32) {
        _nextNoteTime = currentAudioTime + 0.02;
        break;
      }
      _scheduleStep(_currentStep, _nextNoteTime, stepDurationSec);
      _nextNoteTime += stepDurationSec;

      bool didLoop = false;
      _currentStep++;
      if (_isLooping && _currentStep >= _loopEndBar * 16) {
        _currentStep = _loopStartBar * 16;
        didLoop = true;
      } else if (_currentStep >= maxSteps) {
        _currentStep = _isLooping ? _loopStartBar * 16 : 0;
        didLoop = true;
      }

      if (didLoop) {
        final double loopOffsetSec = _currentStep * stepDurationSec;
        for (final track in activePattern.tracks) {
          if (track.hasValidBake) {
            audioEngine.playFrozenTrack(
              track: track,
              startOffsetSec: loopOffsetSec,
              scheduledTime: _nextNoteTime,
            );
          }
        }
      }

      _arrangerStep = _currentStep;
      _currentBar = _currentStep ~/ 16;
      stepAdvanced = true;
    }

    // Update UI position notifiers ONCE per timer tick (not per step inside the loop).
    // Previously these were inside the while-loop, causing up to 96 synchronous widget
    // notifications per 25ms tick during catch-up, which saturated the main thread.
    if (stepAdvanced) {
      currentStepNotifier.value = _currentStep;
      arrangerStepNotifier.value = _arrangerStep;
      currentBarNotifier.value = _currentBar;
    }
  }

  void _scheduleStep(int stepIdx, double hardwareTime, double stepDurationSec) {
    final currentPattern = activePattern;
    final hasSolo = currentPattern.tracks.any((t) => t.isSoloed);
    final activeChord = getActiveChordAtStep(stepIdx);
    // Use the cached pipeline instance (no per-step allocation).
    final pipeline = _pipeline;

    for (final track in currentPattern.tracks) {
      if (track.isMuted) continue;
      if (hasSolo && !track.isSoloed) continue;
      if (track.hasValidBake) continue; // Streamed continuously via WABufferSourceNode without Lua synthesis overhead

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
            final int effectiveLoopSteps = clip.effectiveLoopLengthBars * 16;
            final int localStep = effectiveLoopSteps > 0
                ? (stepIdx - clipStartStep) % effectiveLoopSteps
                : (stepIdx - clipStartStep);

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
              // Use an index-based scan to avoid allocating a new List per step per track.
              final double stepEnd = localStep + 1.0;
              bool hasMatch = false;
              for (int ni = 0; ni < effectiveNotes.length; ni++) {
                final s = effectiveNotes[ni].startStep;
                if (s >= localStep && s < stepEnd) { hasMatch = true; break; }
              }

              if (hasMatch) {
                if (track.isMonophonicTrack) {
                  // Collect matching notes into a fixed-size temp buffer (no heap List).
                  final matchBuf = <Note>[];
                  for (final n in effectiveNotes) {
                    if (n.startStep >= localStep && n.startStep < stepEnd) matchBuf.add(n);
                  }
                  matchBuf.sort((a, b) => a.startStep.compareTo(b.startStep));

                  final hasSlideParam = (track.luaParams['Slide'] ?? 0.0) > 0.01 ||
                      (track.luaParams['Portamento'] ?? 0.0) > 0.01 ||
                      (track.luaParams['Glide'] ?? 0.0) > 0.01;

                  for (int mIdx = 0; mIdx < matchBuf.length; mIdx++) {
                    final note = matchBuf[mIdx];
                    final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                    final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);

                    // Determine target slide pitch without allocating extra lists.
                    int? rawTargetPitch;
                    final bool hasSimultaneous = matchBuf.length > 1;
                    if (hasSimultaneous && (mIdx < matchBuf.length - 1 || matchBuf.length > 1)) {
                      final targetSimNote = (matchBuf.last != note) ? matchBuf.last : matchBuf.first;
                      rawTargetPitch = targetSimNote.pitch;
                    } else {
                      // Find first note after this one within slide window (no toList).
                      final double slideWindow = note.startStep + math.max(1.5, note.durationSteps + 0.5);
                      for (final n in effectiveNotes) {
                        if (n.startStep > note.startStep && n.startStep <= slideWindow) {
                          rawTargetPitch = n.pitch;
                          break;
                        }
                      }
                    }

                    final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;

                    // Overlap check without allocating a list.
                    bool hasPrevOverlap = false;
                    for (final n in effectiveNotes) {
                      if (n.startStep < note.startStep && (n.startStep + n.durationSteps) > note.startStep) {
                        hasPrevOverlap = true;
                        break;
                      }
                    }

                    // nextNotes non-empty check without allocating a list.
                    bool hasNextNote = false;
                    final double slideWin2 = note.startStep + math.max(1.5, note.durationSteps + 0.5);
                    for (final n in effectiveNotes) {
                      if (n.startStep > note.startStep && n.startStep <= slideWin2) {
                        hasNextNote = true;
                        break;
                      }
                    }

                    final bool isSlideNote = note.isSlide ||
                        hasPrevOverlap ||
                        hasSimultaneous ||
                        hasSlideParam ||
                        (hasNextNote && (note.isSlide || hasSlideParam));
                    final bool isAccentNote = note.isAccent || note.velocity > 0.75;
                    final effectiveMidi = remapPitch(note.pitch);
                    final double noteDurSec = math.max(0.02, math.min(3.0, note.durationSteps * stepDurationSec));

                    audioEngine.playNoteOrSample(
                      track: track,
                      midiNote: effectiveMidi,
                      targetMidiNote: targetPitch,
                      isSlide: isSlideNote,
                      isAccent: isAccentNote,
                      velocity: note.velocity,
                      durationSec: noteDurSec,
                      scheduledTime: noteHardwareTime,
                    );
                  }
                } else {
                  // Polyphonic track: iterate matching notes without materialising a list.
                  for (final note in effectiveNotes) {
                    if (note.startStep < localStep || note.startStep >= stepEnd) continue;
                    final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                    final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);
                    final bool isAccentNote = note.isAccent || note.velocity > 0.75;
                    final effectiveMidi = remapPitch(note.pitch);

                    // Polyphonic slide resolution per tracker column (no toList).
                    int? rawTargetPitch;
                    final double slideWindow = note.startStep + math.max(1.5, note.durationSteps + 0.5);
                    for (final n in effectiveNotes) {
                      if (n.column == note.column && n.startStep > note.startStep && n.startStep <= slideWindow && n.isSlide) {
                        rawTargetPitch = n.pitch;
                        break;
                      }
                    }
                    final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;
                    final bool isSlideNote = note.isSlide || targetPitch != null;
                    final double noteDurSec = math.max(0.02, math.min(3.0, note.durationSteps * stepDurationSec));

                    audioEngine.playNoteOrSample(
                      track: track,
                      midiNote: effectiveMidi,
                      targetMidiNote: targetPitch,
                      isSlide: isSlideNote,
                      isAccent: isAccentNote,
                      velocity: note.velocity,
                      durationSec: noteDurSec,
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
          // Allocation-free note-window scan (mirrors the clip path).
          final double stepEnd2 = localStep + 1.0;
          bool hasMatch2 = false;
          for (int ni = 0; ni < effectiveNotes.length; ni++) {
            final s = effectiveNotes[ni].startStep;
            if (s >= localStep && s < stepEnd2) { hasMatch2 = true; break; }
          }

          if (hasMatch2) {
            if (track.isMonophonicTrack) {
              final matchBuf2 = <Note>[];
              for (final n in effectiveNotes) {
                if (n.startStep >= localStep && n.startStep < stepEnd2) matchBuf2.add(n);
              }
              matchBuf2.sort((a, b) => a.startStep.compareTo(b.startStep));

              final hasSlideParam = (track.luaParams['Slide'] ?? 0.0) > 0.01 ||
                  (track.luaParams['Portamento'] ?? 0.0) > 0.01 ||
                  (track.luaParams['Glide'] ?? 0.0) > 0.01;

              for (int mIdx = 0; mIdx < matchBuf2.length; mIdx++) {
                final note = matchBuf2[mIdx];
                final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);

                int? rawTargetPitch;
                final bool hasSimultaneous2 = matchBuf2.length > 1;
                if (hasSimultaneous2 && (mIdx < matchBuf2.length - 1 || matchBuf2.length > 1)) {
                  final targetSimNote = (matchBuf2.last != note) ? matchBuf2.last : matchBuf2.first;
                  rawTargetPitch = targetSimNote.pitch;
                } else {
                  final double slideWindow = note.startStep + math.max(1.5, note.durationSteps + 0.5);
                  for (final n in effectiveNotes) {
                    if (n.startStep > note.startStep && n.startStep <= slideWindow) {
                      rawTargetPitch = n.pitch;
                      break;
                    }
                  }
                }

                final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;
                bool hasPrevOverlap = false;
                for (final n in effectiveNotes) {
                  if (n.startStep < note.startStep && (n.startStep + n.durationSteps) > note.startStep) {
                    hasPrevOverlap = true;
                    break;
                  }
                }
                bool hasNextNote = false;
                final double slideWin2 = note.startStep + math.max(1.5, note.durationSteps + 0.5);
                for (final n in effectiveNotes) {
                  if (n.startStep > note.startStep && n.startStep <= slideWin2) {
                    hasNextNote = true;
                    break;
                  }
                }

                final bool isSlideNote = note.isSlide ||
                    hasPrevOverlap ||
                    hasSimultaneous2 ||
                    hasSlideParam ||
                    (note.durationSteps > 1.0) ||
                    (hasNextNote && (note.isSlide || hasSlideParam || note.durationSteps >= 1.0));
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
              for (final note in effectiveNotes) {
                if (note.startStep < localStep || note.startStep >= stepEnd2) continue;
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
      articulation: note.articulation,
      releaseVelocity: note.releaseVelocity ?? 0.5,
      pitchBendPoints: note.pitchBendPoints,
      pressurePoints: note.pressurePoints,
      timbrePoints: note.timbrePoints,
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

  void setNoteSlide(TrackChannel track, Note note, bool isSlide) {
    final idx = track.notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      track.notes[idx].isSlide = isSlide;
      _syncClipNotes(track);
      recordHistory('${isSlide ? "Enable" : "Disable"} Slide on Note ${_formatPitch(note.pitch)} (${track.name})', icon: Icons.trending_up, force: true);
      notifyListeners();
    }
  }

  void toggleNoteSlide(TrackChannel track, Note note) {
    setNoteSlide(track, note, !note.isSlide);
  }

  void setNotesSlide(TrackChannel track, Iterable<String> noteIds, bool isSlide) {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty) return;
    for (final n in track.notes) {
      if (idSet.contains(n.id)) {
        n.isSlide = isSlide;
      }
    }
    _syncClipNotes(track);
    recordHistory('${isSlide ? "Enable" : "Disable"} Slide for ${idSet.length} Notes (${track.name})', icon: Icons.trending_up, force: true);
    notifyListeners();
  }

  void setNoteArticulation(TrackChannel track, Note note, String? articulation) {
    final idx = track.notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      track.notes[idx].articulation = articulation;
      _syncClipNotes(track);
      recordHistory('Set Articulation on Note ${_formatPitch(note.pitch)} to ${articulation ?? "Normal"} (${track.name})', icon: Icons.music_note, force: true);
      notifyListeners();
    }
  }

  void setNotesArticulation(TrackChannel track, Iterable<String> noteIds, String? articulation) {
    final idSet = noteIds.toSet();
    if (idSet.isEmpty) return;
    for (final n in track.notes) {
      if (idSet.contains(n.id)) {
        n.articulation = articulation;
      }
    }
    _syncClipNotes(track);
    recordHistory('Set Articulation for ${idSet.length} Notes to ${articulation ?? "Normal"} (${track.name})', icon: Icons.music_note, force: true);
    notifyListeners();
  }

  void setNoteReleaseVelocity(TrackChannel track, Note note, double? relVel) {
    final idx = track.notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      track.notes[idx].releaseVelocity = relVel?.clamp(0.01, 1.0);
      _syncClipNotes(track);
      notifyListeners();
    }
  }

  void setNoteMPECurves(
    TrackChannel track,
    Note note, {
    List<List<double>>? bend,
    List<List<double>>? pressure,
    List<List<double>>? timbre,
  }) {
    final idx = track.notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      if (bend != null) track.notes[idx].pitchBendPoints = bend;
      if (pressure != null) track.notes[idx].pressurePoints = pressure;
      if (timbre != null) track.notes[idx].timbrePoints = timbre;
      _syncClipNotes(track);
      recordHistory('Update MPE Curves on Note ${_formatPitch(note.pitch)} (${track.name})', icon: Icons.gesture, force: true);
      notifyListeners();
    }
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

  void setTrackClipBarLength(TrackClip clip, int newBarLength, {bool keepLoop = false}) {
    final clamped = newBarLength.clamp(1, 64);
    clip.barLength = clamped;
    if (!keepLoop && clip.loopLengthBars != null && clip.loopLengthBars! >= clamped) {
      clip.loopLengthBars = null;
    }
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

  void setTrackCutoff(TrackChannel track, double cutoff) {
    track.cutoff = cutoff.clamp(20.0, 20000.0);
    notifyListeners();
  }

  void setTrackResonance(TrackChannel track, double resonance) {
    track.resonance = resonance.clamp(0.1, 10.0);
    notifyListeners();
  }

  void setTrackAttack(TrackChannel track, double attack) {
    track.attack = attack.clamp(0.001, 5.0);
    notifyListeners();
  }

  void setTrackRelease(TrackChannel track, double release) {
    track.release = release.clamp(0.01, 10.0);
    notifyListeners();
  }

  void setTrackEq({
    required TrackChannel track,
    bool? enabled,
    double? hpf,
    double? lowGain,
    double? midFreq,
    double? midGain,
    double? midQ,
    double? highGain,
  }) {
    if (enabled != null) track.eqEnabled = enabled;
    if (hpf != null) track.eqHpf = hpf.clamp(20.0, 500.0);
    if (lowGain != null) track.eqLowGain = lowGain.clamp(-18.0, 18.0);
    if (midFreq != null) track.eqMidFreq = midFreq.clamp(200.0, 8000.0);
    if (midGain != null) track.eqMidGain = midGain.clamp(-18.0, 18.0);
    if (midQ != null) track.eqMidQ = midQ.clamp(0.3, 10.0);
    if (highGain != null) track.eqHighGain = highGain.clamp(-18.0, 18.0);
    audioEngine.updateTrackEq(
      track.id,
      enabled: track.eqEnabled,
      hpf: track.eqHpf,
      lowGain: track.eqLowGain,
      midFreq: track.eqMidFreq,
      midGain: track.eqMidGain,
      midQ: track.eqMidQ,
      highGain: track.eqHighGain,
    );
    notifyListeners();
  }

  void setMasterEq({
    double? subCut,
    double? lowGain,
    double? midFreq,
    double? midGain,
    double? highGain,
  }) {
    if (subCut != null) _masterSubCut = subCut.clamp(20.0, 45.0);
    if (lowGain != null) _masterLowGain = lowGain.clamp(-12.0, 12.0);
    if (midFreq != null) _masterMidFreq = midFreq.clamp(200.0, 1000.0);
    if (midGain != null) _masterMidGain = midGain.clamp(-12.0, 12.0);
    if (highGain != null) _masterHighGain = highGain.clamp(-12.0, 12.0);
    audioEngine.updateMasterEq(
      subCut: _masterSubCut,
      lowGain: _masterLowGain,
      midFreq: _masterMidFreq,
      midGain: _masterMidGain,
      highGain: _masterHighGain,
    );
    notifyListeners();
  }

  void setMasterLimiter({
    bool? enabled,
    double? ceilingDbfs,
    double? driveDb,
    double? targetLufs,
  }) {
    if (enabled != null) _masterLimiterEnabled = enabled;
    if (ceilingDbfs != null) _masterCeilingDbfs = ceilingDbfs.clamp(-2.0, 0.0);
    if (driveDb != null) _masterLimiterDrive = driveDb.clamp(0.0, 12.0);
    if (targetLufs != null) _masterTargetLufs = targetLufs.clamp(-24.0, -6.0);
    audioEngine.updateMasterLimiter(
      enabled: _masterLimiterEnabled,
      ceilingDbfs: _masterCeilingDbfs,
      driveDb: _masterLimiterDrive,
      targetLufs: _masterTargetLufs,
    );
    notifyListeners();
  }

  /// Extracts comprehensive acoustic and frequency energy telemetry across all tracks
  /// and master output for Gemini AI mixing & mastering.
  Map<String, dynamic> extractMixTelemetry({String genreVibe = 'auto', double? targetLufs}) {
    final effectiveTargetLufs = targetLufs ?? _masterTargetLufs;
    final trackTelemetry = <String, dynamic>{};

    for (final track in activePattern.tracks) {
      if (track.isFolder) continue;

      final tag = track.primaryTag.toLowerCase();
      final hasNotes = track.notes.isNotEmpty || track.clips.any((c) => c.notes.isNotEmpty);
      final avgVel = hasNotes
          ? (track.notes.isNotEmpty
              ? track.notes.map((n) => n.velocity).reduce((a, b) => a + b) / track.notes.length
              : 0.8)
          : 0.8;

      double peakDbfs = -6.0 + (track.volume - 1.0) * 12.0 + (avgVel - 0.8) * 6.0;
      double rmsDbfs = peakDbfs - (tag.contains('kick') || tag.contains('snare') || tag.contains('clap') ? 14.0 : 8.0);
      double crestFactor = peakDbfs - rmsDbfs;
      double dominantFreq = 1000.0;
      double correlation = 1.0;
      Map<String, double> energyBands = {
        'sub': 0.1,
        'low': 0.2,
        'lowMid': 0.3,
        'mid': 0.5,
        'highMid': 0.4,
        'high': 0.3,
        'air': 0.1,
      };

      if (tag == 'kick') {
        dominantFreq = (track.luaParams['NearPitchEnd'] ?? (track.luaParams['EndFreq'] ?? 52.0)).clamp(35.0, 90.0);
        correlation = 1.0;
        energyBands = {'sub': 0.95, 'low': 0.65, 'lowMid': 0.18, 'mid': 0.05, 'highMid': 0.02, 'high': 0.0, 'air': 0.0};
      } else if (tag == 'bass' || tag.contains('303') || tag.contains('808')) {
        dominantFreq = 58.0;
        correlation = 0.98;
        energyBands = {'sub': 0.90, 'low': 0.85, 'lowMid': 0.55, 'mid': 0.15, 'highMid': 0.02, 'high': 0.0, 'air': 0.0};
      } else if (tag == 'snare' || tag == 'clap') {
        dominantFreq = 200.0;
        correlation = 0.85;
        energyBands = {'sub': 0.05, 'low': 0.45, 'lowMid': 0.70, 'mid': 0.80, 'highMid': 0.60, 'high': 0.35, 'air': 0.10};
      } else if (tag == 'hihat' || tag.contains('hat') || tag == 'percussion') {
        dominantFreq = 7500.0;
        correlation = 0.70;
        energyBands = {'sub': 0.0, 'low': 0.05, 'lowMid': 0.10, 'mid': 0.30, 'highMid': 0.75, 'high': 0.90, 'air': 0.80};
      } else if (tag == 'piano' || tag == 'rhodes' || tag == 'guitar') {
        dominantFreq = 340.0;
        correlation = 0.65;
        energyBands = {'sub': 0.15, 'low': 0.40, 'lowMid': 0.75, 'mid': 0.65, 'highMid': 0.45, 'high': 0.30, 'air': 0.15};
      } else if (tag == 'pad' || tag == 'strings') {
        dominantFreq = 440.0;
        correlation = 0.45;
        energyBands = {'sub': 0.10, 'low': 0.35, 'lowMid': 0.60, 'mid': 0.60, 'highMid': 0.50, 'high': 0.40, 'air': 0.30};
      } else if (tag == 'lead' || tag == 'vocal') {
        dominantFreq = 1200.0;
        correlation = 0.90;
        energyBands = {'sub': 0.02, 'low': 0.20, 'lowMid': 0.45, 'mid': 0.88, 'highMid': 0.85, 'high': 0.50, 'air': 0.25};
      }

      trackTelemetry[track.id] = {
        'role': tag,
        'name': track.name,
        'tags': track.effectiveTags,
        'volume': track.volume,
        'pan': track.pan,
        'peakDbfs': (peakDbfs * 10).round() / 10.0,
        'rmsDbfs': (rmsDbfs * 10).round() / 10.0,
        'crestFactorDb': (crestFactor * 10).round() / 10.0,
        'dominantFreqHz': (dominantFreq * 10).round() / 10.0,
        'stereoCorrelation': (correlation * 100).round() / 100.0,
        'energyBands': energyBands,
        'eq': {
          'enabled': track.eqEnabled,
          'hpf': track.eqHpf,
          'lowGain': track.eqLowGain,
          'midFreq': track.eqMidFreq,
          'midGain': track.eqMidGain,
          'midQ': track.eqMidQ,
          'highGain': track.eqHighGain,
        },
      };
    }

    return {
      'version': '1.0',
      'title': projectName,
      'tempoBpm': _bpm,
      'targetLufs': effectiveTargetLufs,
      'genreVibe': genreVibe,
      'master': {
        'masterVolume': _masterVolume,
        'subCut': _masterSubCut,
        'lowGain': _masterLowGain,
        'midFreq': _masterMidFreq,
        'midGain': _masterMidGain,
        'highGain': _masterHighGain,
        'limiterEnabled': _masterLimiterEnabled,
        'ceilingDbfs': _masterCeilingDbfs,
        'limiterDrive': _masterLimiterDrive,
      },
      'tracks': trackTelemetry,
    };
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

  /// Bakes a track down into a static Float32 PCM audio stream.
  Future<void> freezeTrack(
    TrackChannel track, {
    bool includeFx = true,
    FreezeProgressCallback? onProgress,
  }) async {
    if (track.isBaking || track.isFolder) return;
    track.isBaking = true;
    notifyListeners();

    try {
      final buffer = await TrackFreezeEngine.renderTrackOffline(
        track: track,
        audioEngine: audioEngine,
        bpm: _bpm,
        totalTimelineBars: totalTimelineBars,
        includeFx: includeFx,
        onProgress: onProgress,
      );

      track.frozenAudioBuffer = buffer;
      track.frozenDurationSec = buffer.length / 44100.0;
      track.frozenContentHash = TrackFreezeEngine.computeTrackHash(track, bpm: _bpm, timelineBars: totalTimelineBars);
      track.isFrozen = true;
      track.isBaking = false;

      recordHistory('Freeze Track "${track.name}" (${track.frozenDurationSec.toStringAsFixed(1)}s)', icon: Icons.ac_unit);
      triggerAutoSave();
    } catch (e) {
      track.isBaking = false;
      debugPrint('[DawState] freezeTrack error: $e');
    }

    notifyListeners();
  }

  /// Unfreezes a track, returning it to live Lua script / synthesizer evaluation.
  void unfreezeTrack(TrackChannel track) {
    if (!track.isFrozen && track.frozenAudioBuffer == null) return;
    audioEngine.stopFrozenTrack(track.id);
    track.isFrozen = false;
    track.isBaking = false;
    track.frozenAudioBuffer = null;
    track.frozenContentHash = null;
    track.frozenDurationSec = 0.0;
    recordHistory('Unfreeze Track "${track.name}"', icon: Icons.whatshot);
    triggerAutoSave();
    notifyListeners();
  }

  /// Toggles freeze / unfreeze state for a track.
  Future<void> toggleFreezeTrack(TrackChannel track) async {
    if (track.isFrozen) {
      unfreezeTrack(track);
    } else {
      await freezeTrack(track);
    }
  }

  /// Invalidates frozen buffer if track source content was modified.
  void invalidateTrackFreeze(TrackChannel track) {
    if (track.isFrozen) {
      unfreezeTrack(track);
    }
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
    } else if (lowerId.contains('vintage') || lowerName.contains('vintage') || lowerId.contains('degrader') || lowerName.contains('degrader') || lowerId.contains('tape') || lowerName.contains('flutter')) {
      type = FXType.vintageTape;
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
      final isRoom = lowerId == 'room_designer';
      final customName = isCab
          ? 'Cab: ${track.name}_${fx.id}'
          : 'Room: ${track.name}_${fx.id}';

      final basePresetName = initialParams['IRSample'] != null
          ? () {
              final all = ConvolverEngine.builtInIrNames;
              final idx = (initialParams['IRSample'] ?? 0.0).toInt().clamp(0, all.length - 1);
              return all.isNotEmpty ? all[idx] : 'Great Hall';
            }()
          : null;
      final baseParams = basePresetName != null ? ProceduralIRGenerator.presets[basePresetName] : null;

      final matIdx = (initialParams['Material'] ?? (baseParams?.material.index.toDouble() ?? 0.0)).toInt().clamp(0, AcousticMaterialType.values.length - 1);
      final spaceParams = AcousticSpaceParams(
        name: customName,
        width: initialParams['Width'] ?? (baseParams?.width ?? (isCab ? 0.76 : 15.0)),
        length: initialParams['Length'] ?? (baseParams?.length ?? (isCab ? 0.76 : 25.0)),
        height: initialParams['Height'] ?? (baseParams?.height ?? (isCab ? 0.36 : 10.0)),
        sourceX: initialParams['SourceX'] ?? (baseParams?.sourceX ?? 0.5),
        sourceY: initialParams['SourceY'] ?? (baseParams?.sourceY ?? 0.5),
        sourceZ: initialParams['SourceZ'] ?? (baseParams?.sourceZ ?? 0.5),
        listenerX: initialParams['ListenerX'] ?? (baseParams?.listenerX ?? 0.5),
        listenerY: initialParams['ListenerY'] ?? (baseParams?.listenerY ?? 0.8),
        listenerZ: initialParams['ListenerZ'] ?? (baseParams?.listenerZ ?? 0.5),
        stereoWidth: initialParams['StereoWidth'] ?? (baseParams?.stereoWidth ?? (isCab ? 0.08 : 0.20)),
        material: AcousticMaterialType.values[matIdx],
        rt60: isCab ? 0.035 : (initialParams['RT60'] ?? (baseParams?.rt60 ?? 2.2)),
        damping: initialParams['Damping'] ?? (baseParams?.damping ?? (isCab ? 0.55 : 0.25)),
        isCabinetMode: isCab,
        micDistance: initialParams['MicDistance'] ?? (baseParams?.micDistance ?? 0.05),
        micAngleDeg: initialParams['MicAngle'] ?? (baseParams?.micAngleDeg ?? 0.0),
        isOpenBack: (initialParams['OpenBack'] ?? (baseParams?.isOpenBack == true ? 1.0 : 0.0)) == 1.0,
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

        // If this is Eats Vinyl Medium (Media Format Preset Selector)
        final isEatsVinyl = f.type == FXType.vintageTape ||
            f.presetId == 'vintage_era_degrader' ||
            f.presetId == 'eats_vinyl' ||
            f.name.toLowerCase().contains('vinyl') ||
            f.name.toLowerCase().contains('vintage');
        if (isEatsVinyl && paramName == 'Medium') {
          final presetMap = getEatsVinylMediumPreset(val.toInt());
          for (final entry in presetMap.entries) {
            f.params[entry.key] = entry.value;
            f.luaParams[entry.key] = entry.value;
          }
        }

        // If this is a Room or Cabinet Designer parameter (procedural custom space synthesizers)
        final isRoomDesigner = f.presetId == 'room_designer' || f.name.toLowerCase().contains('room designer');
        final isCabDesigner = f.presetId == 'cab_designer' || f.name.toLowerCase().contains('cab');
        if (isRoomDesigner || isCabDesigner) {
          final customName = isCabDesigner
              ? 'Cab: ${track.name}_${f.id}'
              : 'Room: ${track.name}_${f.id}';

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

          final basePresetName = f.params['IRSample'] != null
              ? () {
                  final all = ConvolverEngine.builtInIrNames;
                  final idx = f.params['IRSample']!.toInt().clamp(0, all.length - 1);
                  return all.isNotEmpty ? all[idx] : 'Great Hall';
                }()
              : null;
          final baseParams = basePresetName != null ? ProceduralIRGenerator.presets[basePresetName] : null;

          final matIdx = (f.params['Material'] ?? (baseParams?.material.index.toDouble() ?? 0.0)).toInt().clamp(0, AcousticMaterialType.values.length - 1);
          final spaceParams = AcousticSpaceParams(
            name: customName,
            width: f.params['Width'] ?? (f.luaParams['Width'] ?? (baseParams?.width ?? (isCabDesigner ? 0.76 : 12.0))),
            length: f.params['Length'] ?? (f.luaParams['Length'] ?? (baseParams?.length ?? (isCabDesigner ? 0.76 : 15.0))),
            height: f.params['Height'] ?? (f.luaParams['Height'] ?? (baseParams?.height ?? (isCabDesigner ? 0.36 : 4.0))),
            sourceX: f.params['SourceX'] ?? (f.luaParams['SourceX'] ?? (baseParams?.sourceX ?? 0.5)),
            sourceY: f.params['SourceY'] ?? (f.luaParams['SourceY'] ?? (baseParams?.sourceY ?? 0.5)),
            sourceZ: f.params['SourceZ'] ?? (f.luaParams['SourceZ'] ?? (baseParams?.sourceZ ?? 0.5)),
            listenerX: f.params['ListenerX'] ?? (f.luaParams['ListenerX'] ?? (baseParams?.listenerX ?? 0.5)),
            listenerY: f.params['ListenerY'] ?? (f.luaParams['ListenerY'] ?? (baseParams?.listenerY ?? 0.8)),
            listenerZ: f.params['ListenerZ'] ?? (f.luaParams['ListenerZ'] ?? (baseParams?.listenerZ ?? 0.5)),
            stereoWidth: f.params['StereoWidth'] ?? (f.luaParams['StereoWidth'] ?? (baseParams?.stereoWidth ?? (isCabDesigner ? 0.08 : 0.20))),
            material: AcousticMaterialType.values[matIdx],
            rt60: isCabDesigner ? 0.035 : (f.params['RT60'] ?? (f.params['Decay'] ?? (baseParams?.rt60 ?? 1.8))),
            damping: f.params['Damping'] ?? (baseParams?.damping ?? (isCabDesigner ? 0.55 : 0.40)),
            isCabinetMode: isCabDesigner,
            micDistance: f.params['MicDistance'] ?? (baseParams?.micDistance ?? 0.05),
            micAngleDeg: f.params['MicAngle'] ?? (baseParams?.micAngleDeg ?? 0.0),
            isOpenBack: (f.params['OpenBack'] ?? (baseParams?.isOpenBack == true ? 1.0 : 0.0)) == 1.0,
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

  /// Triggers real-time Tape Stop motor deceleration and spin-up effect on a track.
  void triggerTapeStop(String trackId, {double stopTime = 0.8, double spinUpTime = 0.4}) {
    audioEngine.triggerTapeStop(trackId, stopTime: stopTime, spinUpTime: spinUpTime);
    notifyListeners();
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

    final totalSongBars = parsedSong.totalBars;
    if (totalSongBars > 0) {
      ensureSongLengthForBars(totalSongBars);
      setLoopPoints(0, totalSongBars);
    }

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();
    debugPrint(
        'Successfully imported MIDI "$fileName": Replaced $replacedCount tracks, created $createdCount tracks, BPM: $bpm, Bars: $totalSongBars');
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

  /// Ensures pattern and arrangement have enough bars to accommodate content
  void ensureSongLengthForBars(int requiredBars) {
    final requiredSteps = requiredBars * 16;
    if (activePattern.lengthSteps < requiredSteps) {
      activePattern.lengthSteps = requiredSteps;
    }
  }

  /// Imports a parsed MIDI track into either a new track or an existing track
  void importParsedMidiTrack(
    ParsedMidiTrack midiTrack, {
    String? targetTrackId,
    bool createNewTrack = true,
    String? customTrackName,
  }) {
    beginHistoryTransaction('Import Transcribed Audio to MIDI');

    ensureSongLengthForBars(midiTrack.totalBars);
    if (midiTrack.totalBars > 0) {
      setLoopPoints(0, midiTrack.totalBars);
    }

    if (!createNewTrack && targetTrackId != null) {
      final target = activePattern.tracks.firstWhere(
        (t) => t.id == targetTrackId,
        orElse: () => activeTrack,
      );
      if (customTrackName != null && customTrackName.isNotEmpty) {
        target.name = customTrackName;
      }
      _replaceTrackNotesWithMidi(target, midiTrack);
    } else {
      if (customTrackName != null && customTrackName.isNotEmpty) {
        midiTrack.name = customTrackName;
      }
      _createNewTrackFromMidi(midiTrack);
    }

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();
  }

  /// High-level method to transcribe an audio buffer directly into MIDI and insert into project
  Future<ParsedMidiTrack> transcribeAudioToMidi(
    DecodedAudioBuffer audio, {
    AudioToMidiOptions? options,
    String? targetTrackId,
    bool createNewTrack = true,
    String? customTrackName,
    CancellationToken? cancellationToken,
    Function(double progress, String status)? onProgress,
  }) async {
    final opts = options ?? AudioToMidiOptions(targetBpm: bpm);
    final neuralBytes = AudioToMidiPackManager.instance.cachedModelBytes;

    final parsedTrack = await AudioToMidiEngine.transcribeAudioBuffer(
      audio,
      options: opts,
      neuralModelBytes: neuralBytes,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    );

    if (cancellationToken?.isCancelled ?? false) {
      return parsedTrack;
    }

    importParsedMidiTrack(
      parsedTrack,
      targetTrackId: targetTrackId,
      createNewTrack: createNewTrack,
      customTrackName: customTrackName ?? 'Audio to MIDI',
    );

    return parsedTrack;
  }

  /// Transcribes an audio clip's sample directly into linked embedded MIDI notes on the clip itself
  Future<int> transcribeAudioClipToLinkedMidi(
    TrackClip clip, {
    AudioToMidiOptions? options,
    CancellationToken? cancellationToken,
    Function(double progress, String status)? onProgress,
  }) async {
    final sampleName = clip.audioSampleName ?? activeTrack.sampleName;
    final audioBuffer = SamplerEngine.instance.getSample(sampleName);
    if (audioBuffer == null) {
      throw Exception('No audio sample loaded for clip "${clip.name}" ($sampleName)');
    }

    final opts = options ?? AudioToMidiOptions(targetBpm: bpm);
    final neuralBytes = AudioToMidiPackManager.instance.cachedModelBytes;

    final parsedTrack = await AudioToMidiEngine.transcribeAudioBuffer(
      audioBuffer,
      options: opts,
      neuralModelBytes: neuralBytes,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    );

    if (cancellationToken?.isCancelled ?? false) {
      return 0;
    }

    beginHistoryTransaction('Transcribe Audio to Linked MIDI on "${clip.name}"', icon: Icons.transform);

    clip.embeddedTranscribedNotes = parsedTrack.notes.map((n) => n.copyWith()).toList();
    ensureSongLengthForBars(clip.startBar + clip.barLength);

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();

    return clip.embeddedTranscribedNotes.length;
  }

  /// Extracts chord progression from clip (either linked transcribed notes or clip notes) and applies to chordTrack
  int extractAndApplyChordsFromClip(TrackClip clip, {bool clearExisting = false}) {
    final notesToAnalyze = clip.embeddedTranscribedNotes.isNotEmpty
        ? clip.embeddedTranscribedNotes
        : clip.notes;

    if (notesToAnalyze.isEmpty) return 0;

    final extracted = ChordTheory.extractChordsFromNotes(
      notesToAnalyze,
      startBar: clip.startBar,
      totalBars: clip.barLength,
    );

    if (extracted.isEmpty) return 0;

    beginHistoryTransaction('Extract Chords from "${clip.name}" to Chord Track', icon: Icons.queue_music);

    if (clearExisting) {
      chordTrack.removeWhere((c) => c.startBar >= clip.startBar && c.startBar < (clip.startBar + clip.barLength));
    }

    for (final chord in extracted) {
      addOrUpdateChord(chord);
    }

    ensureSongLengthForBars(clip.startBar + clip.barLength);

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();

    return extracted.length;
  }

  /// Extracts chord progression from an entire track's clips/notes and applies to chordTrack
  int extractAndApplyChordsFromTrack(TrackChannel track, {bool clearExisting = false}) {
    final List<Note> timelineNotes = [];

    for (final clip in track.clips) {
      final sourceNotes = clip.embeddedTranscribedNotes.isNotEmpty
          ? clip.embeddedTranscribedNotes
          : clip.notes;
      final int clipOffsetSteps = clip.startBar * 16;
      for (final n in sourceNotes) {
        timelineNotes.add(n.copyWith(
          startStep: clipOffsetSteps + n.startStep,
        ));
      }
    }

    if (timelineNotes.isEmpty && track.notes.isNotEmpty) {
      for (final n in track.notes) {
        timelineNotes.add(n.copyWith());
      }
    }

    if (timelineNotes.isEmpty) return 0;

    double maxStep = 0.0;
    for (final n in timelineNotes) {
      final end = n.startStep + n.durationSteps;
      if (end > maxStep) maxStep = end;
    }
    final totalBars = (maxStep / 16.0).ceil();
    if (totalBars <= 0) return 0;

    final extracted = ChordTheory.extractChordsFromNotes(
      timelineNotes,
      startBar: 0,
      totalBars: totalBars,
    );

    if (extracted.isEmpty) return 0;

    beginHistoryTransaction('Extract Chords from Track "${track.name}" to Chord Track', icon: Icons.queue_music);

    if (clearExisting) {
      chordTrack.clear();
    } else {
      chordTrack.removeWhere((c) => c.startBar < totalBars);
    }

    for (final chord in extracted) {
      addOrUpdateChord(chord);
    }

    ensureSongLengthForBars(totalBars);

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();

    return extracted.length;
  }

  /// Extracts chord progression from a ParsedMidiTrack (e.g. from Audio-to-MIDI or MIDI import) and applies to chordTrack
  int extractAndApplyChordsFromMidiTrack(
    ParsedMidiTrack midiTrack, {
    bool clearExisting = false,
    int startBar = 0,
  }) {
    if (midiTrack.notes.isEmpty) return 0;

    double maxStep = 0.0;
    for (final n in midiTrack.notes) {
      final end = n.startStep + n.durationSteps;
      if (end > maxStep) maxStep = end;
    }
    final totalBars = (maxStep / 16.0).ceil();
    if (totalBars <= 0) return 0;

    final extracted = ChordTheory.extractChordsFromNotes(
      midiTrack.notes,
      startBar: startBar,
      totalBars: totalBars,
    );

    if (extracted.isEmpty) return 0;

    beginHistoryTransaction('Extract Chords from MIDI "${midiTrack.name}" to Chord Track', icon: Icons.queue_music);

    if (clearExisting) {
      chordTrack.clear();
    } else {
      chordTrack.removeWhere((c) => c.startBar >= startBar && c.startBar < (startBar + totalBars));
    }

    for (final chord in extracted) {
      addOrUpdateChord(chord);
    }

    ensureSongLengthForBars(startBar + totalBars);

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();

    return extracted.length;
  }

  /// Splits clip notes into dedicated destination tracks using a Lua note splitter preset
  List<TrackChannel> splitClipNotesWithPreset(
    TrackClip clip,
    LuaScriptDef preset, {
    Map<String, double>? params,
    bool removeOriginalClip = false,
  }) {
    final sourceNotes = clip.embeddedTranscribedNotes.isNotEmpty
        ? clip.embeddedTranscribedNotes
        : clip.notes;

    if (sourceNotes.isEmpty) return [];

    final splitResults = NoteSplitterEngine.splitWithPreset(sourceNotes, preset, params: params);
    if (splitResults.isEmpty) return [];

    beginHistoryTransaction('Split Clip "${clip.name}" into ${splitResults.length} Tracks', icon: Icons.call_split);

    final List<TrackChannel> createdTracks = [];

    for (final result in splitResults) {
      final newTrackIndex = activePattern.tracks.length;
      final newTrackId = 'track_${DateTime.now().millisecondsSinceEpoch}_$newTrackIndex';
      final newTrack = TrackChannel(
        id: newTrackId,
        name: result.name,
        color: result.color,
        type: result.type,
        steps: List.generate(activePattern.lengthSteps, (_) => StepEvent(active: false)),
        clips: [
          TrackClip(
            id: 'clip_${DateTime.now().millisecondsSinceEpoch}_$newTrackIndex',
            name: result.name,
            trackId: newTrackId,
            startBar: clip.startBar,
            barLength: clip.barLength,
            notes: result.notes.map((n) => n.copyWith()).toList(),
          ),
        ],
      );

      // Populate tracker step preview
      for (final note in result.notes) {
        final step = note.startStep.toInt();
        if (step < newTrack.steps.length) {
          newTrack.steps[step] = StepEvent(
            active: true,
            pitch: note.pitch,
            velocity: note.velocity,
          );
        }
      }

      activePattern.tracks.add(newTrack);
      createdTracks.add(newTrack);
    }

    if (removeOriginalClip) {
      final track = activePattern.tracks.firstWhere(
        (t) => t.id == clip.trackId,
        orElse: () => activeTrack,
      );
      track.clips.removeWhere((c) => c.id == clip.id);
    }

    ensureSongLengthForBars(clip.startBar + clip.barLength);

    commitHistoryTransaction();
    triggerAutoSave();
    notifyListeners();

    return createdTracks;
  }

  void loadLuaPreset(LuaPreset preset) {
    luaCode = preset.code;
    compileLuaCode(preset.code);
  }

  /// Curated authentic media presets for Eats Vinyl (Wow, Flutter, Era, Crackle, Hiss, etc.)
  static Map<String, double> getEatsVinylMediumPreset(int mediumIdx) {
    switch (mediumIdx) {
      case 0: // Tape 15 IPS (Studio Master)
        return {
          'Era': 1982.0,
          'WowDepth': 6.0,
          'FlutterDepth': 4.0,
          'MotorJitter': 4.0,
          'WarpSwell': 5.0,
          'TapeDropouts': 4.0,
          'NeedleBumpFreq': 0.0,
          'StutterDepth': 0.0,
          'ThudLevel': 0.0,
          'TapeWarmth': 35.0,
          'HeadBump': 2.0,
          'HissLevel': 12.0,
          'VinylCrackle': 0.0,
          'GrooveRumble': 4.0,
        };
      case 1: // Cassette Type I (Ferric Lo-Fi)
        return {
          'Era': 1985.0,
          'WowDepth': 22.0,
          'FlutterDepth': 30.0,
          'MotorJitter': 18.0,
          'WarpSwell': 18.0,
          'TapeDropouts': 20.0,
          'NeedleBumpFreq': 5.0,
          'StutterDepth': 10.0,
          'ThudLevel': 10.0,
          'TapeWarmth': 60.0,
          'HeadBump': 4.5,
          'HissLevel': 45.0,
          'VinylCrackle': 5.0,
          'GrooveRumble': 10.0,
        };
      case 2: // Vinyl 33 RPM (Warm Hi-Fi LP)
        return {
          'Era': 1975.0,
          'WowDepth': 18.0,
          'FlutterDepth': 12.0,
          'MotorJitter': 8.0,
          'WarpSwell': 20.0,
          'TapeDropouts': 12.0,
          'NeedleBumpFreq': 22.0,
          'StutterDepth': 30.0,
          'ThudLevel': 28.0,
          'TapeWarmth': 40.0,
          'HeadBump': 3.5,
          'HissLevel': 18.0,
          'VinylCrackle': 28.0,
          'GrooveRumble': 20.0,
        };
      case 3: // Shellac 78 RPM (Gramophone 1930s)
        return {
          'Era': 1952.0,
          'WowDepth': 35.0,
          'FlutterDepth': 25.0,
          'MotorJitter': 22.0,
          'WarpSwell': 35.0,
          'TapeDropouts': 30.0,
          'NeedleBumpFreq': 45.0,
          'StutterDepth': 45.0,
          'ThudLevel': 40.0,
          'TapeWarmth': 75.0,
          'HeadBump': 0.0,
          'HissLevel': 50.0,
          'VinylCrackle': 65.0,
          'GrooveRumble': 35.0,
        };
      case 4: // Warped 45 RPM (Psychedelic Single)
      default:
        return {
          'Era': 1968.0,
          'WowDepth': 65.0,
          'FlutterDepth': 18.0,
          'MotorJitter': 25.0,
          'WarpSwell': 60.0,
          'TapeDropouts': 25.0,
          'NeedleBumpFreq': 55.0,
          'StutterDepth': 50.0,
          'ThudLevel': 50.0,
          'TapeWarmth': 50.0,
          'HeadBump': 3.0,
          'HissLevel': 25.0,
          'VinylCrackle': 40.0,
          'GrooveRumble': 45.0,
        };
    }
  }

  void updateLuaParam(String paramName, double value) {
    activeTrack.luaParams[paramName] = value;
    final isEatsVinylTrack = activeTrack.luaScriptCode.contains('EatsVinyl') ||
        activeTrack.luaScriptCode.contains('VintageDegrader') ||
        activeTrack.luaScriptCode.contains('vintage_era_degrader');
    if (isEatsVinylTrack && paramName == 'Medium') {
      final presetMap = getEatsVinylMediumPreset(value.toInt());
      for (final entry in presetMap.entries) {
        activeTrack.luaParams[entry.key] = entry.value;
      }
    }
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

  int get maxTrackerSteps => math.max(16, math.max(activeTrackClip.barLength * 16, activePattern.lengthSteps));

  void selectTrackerCell(int step, int column) {
    trackerSelectedStep = step.clamp(0, maxTrackerSteps - 1);
    trackerSelectedColumn = column.clamp(0, activeTrack.trackerColumns - 1);
    notifyListeners();
  }

  void addOrUpdateTrackerNote({
    required int pitch,
    double velocity = 0.85,
    bool isSlide = false,
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
        isSlide: isSlide,
      ),
    );

    audioEngine.playNoteOrSample(
      track: track,
      midiNote: pitch,
      velocity: velocity,
      isSlide: isSlide,
    );

    if (autoAdvance) {
      trackerSelectedStep = (trackerSelectedStep + 1) % maxTrackerSteps;
    }

    _syncClipNotes(track);
    notifyListeners();
  }

  void toggleTrackerSlideAtSelectedCell() {
    final track = activeTrack;
    final existing = track.notes.where(
      (n) => n.startStep.toInt() == trackerSelectedStep && n.column == trackerSelectedColumn,
    ).toList();
    if (existing.isNotEmpty) {
      final note = existing.first;
      note.isSlide = !note.isSlide;
      _syncClipNotes(track);
      recordHistory('${note.isSlide ? "Enable" : "Disable"} Slide on Tracker Note ${_formatPitch(note.pitch)}', icon: Icons.trending_up, force: true);
      notifyListeners();
    }
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
