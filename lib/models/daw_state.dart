import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/platform_env_helper.dart';
import '../utils/eats_storage_helper.dart';

import '../audio/audio_engine.dart';
import '../audio/sampler_engine.dart';
import '../audio/soundfont_engine.dart';
import '../audio/wav_exporter.dart';
import '../theme/eats_theme.dart';
import '../lua/lua_engine.dart';
import '../lua/eats_lua_serializer.dart';
import '../lua/eats_lua_parser.dart';
import '../audio/time_context.dart';
import '../lua/lua_preset_library.dart';
import '../lua/midi_pipeline_engine.dart';
import '../lua/default_song.dart';
import 'track_model.dart';
import 'chord_model.dart';
import 'history_manager.dart';

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
    final curStep = (_currentBar * 16 + _currentStep).toInt();
    return TimeContext.fromBeat(
      beat: (_currentBar * 4 + _currentStep / 4).toDouble(),
      bpm: _bpm,
      activeChord: getActiveChordAtStep(curStep),
      chordTrack: List.unmodifiable(chordTrack),
      songKey: songKey,
      songKeyRoot: songKeyRoot,
      isSongKeyMinor: isSongKeyMinor,
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

  void setUiScalePreview(double scale) {
    _uiScale = (scale * 100).roundToDouble() / 100;
    notifyListeners();
  }

  void commitUiScale(double scale) {
    _uiScale = (scale * 100).roundToDouble() / 100;
    EatsStorageHelper.setDouble(EatsStorageHelper.keyUiScale, _uiScale);
    notifyListeners();
  }

  void revertUiScale(double originalScale) {
    _uiScale = (originalScale * 100).roundToDouble() / 100;
    notifyListeners();
  }

  void resetUiScale() {
    commitUiScale(1.0);
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
      compileLuaCode(preset.code);
      recordHistory('Applied instrument "${preset.name}" to ${track.name}', icon: Icons.piano);
    } else if (preset.isAudioFx) {
      FXType fxType = FXType.distortion;
      final lowerId = preset.id.toLowerCase();
      final lowerName = preset.name.toLowerCase();
      if (lowerId.contains('delay') || lowerName.contains('delay') || lowerName.contains('chorus')) {
        fxType = FXType.delay;
      } else if (lowerId.contains('crush') || lowerName.contains('crush') || lowerName.contains('bit')) {
        fxType = FXType.bitcrusher;
      } else if (lowerId.contains('reverb') || lowerName.contains('reverb')) {
        fxType = FXType.convolutionReverb;
      } else if (lowerId.contains('filter') || lowerName.contains('filter')) {
        fxType = FXType.biquadFilter;
      }
      final fx = FXInsert.create(fxType);
      fx.name = preset.name;
      track.fxRack.add(fx);
      audioEngine.invalidateLuaCache(track.id);
      recordHistory('Add FX "${preset.name}" to end of ${track.name} FX rack', icon: Icons.tune);
    } else if (preset.isMidiFx) {
      if (activeClip != null && activeClip!.trackId == track.id) {
        applyPresetToClip(track, activeClip!, preset);
      } else if (track.clips.isNotEmpty) {
        applyPresetToClip(track, track.clips.first, preset);
      } else {
        addMidiFXInsert(
          track,
          name: preset.name,
          luaScriptCode: preset.code,
        );
        recordHistory('Add MIDI FX "${preset.name}" to ${track.name}', icon: Icons.music_note);
      }
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
      startBar: 0,
      barLength: 2,
    );

    newTrack.clips.add(clip);
    activePattern.tracks.add(newTrack);
    activeTrackIndex = activePattern.tracks.length - 1;
    notifyListeners();
  }

  void changeTrackSoundFont(TrackChannel track, String fontId, {String? displayName}) {
    track.sampleName = fontId;
    if (displayName != null && displayName.isNotEmpty) {
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

  void applySoundFont(String fontId, {String? displayName, TrackChannel? targetTrack}) {
    final track = targetTrack ?? activeTrack;
    changeTrackSoundFont(track, fontId, displayName: displayName);
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

  int _currentBar = 0;
  int get currentBar => _currentBar;

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

  void loadFromEatsLua(String eatsLuaCode) {
    history.pauseRecording();
    try {
      projectName = EatsLuaParser.populateDawState(this, eatsLuaCode);
      resetActiveIndices();
    } finally {
      history.resumeRecording();
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
    if (_activeTrackIndex != newIndex || luaCode.isEmpty) {
      _activeTrackIndex = newIndex;
      activeClip = null;
      if (activeTrack.luaScriptCode.isNotEmpty) {
        luaCode = activeTrack.luaScriptCode;
        compilationResult = LuaEngine.compile(luaCode);
      } else {
        luaCode = '';
        compilationResult = LuaCompilationResult(
          isSuccess: true,
          errorMessage: 'No active Lua script on channel',
          params: [],
          scriptType: 'synth',
        );
      }
    } else {
      // Also clear active clip if re-selecting active track without clicking a clip
      activeClip = null;
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

  // Backward compatibility getters
  String get wrenCode => luaCode;
  set wrenCode(String val) => luaCode = val;

  static bool get isTestEnvironment => PlatformEnvHelper.isFlutterTest;

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  DawState({bool? enableMeterTimer}) {
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
    _meterTimer?.cancel();
    _playbackTimer?.cancel();
    history.dispose();
    audioEngine.setMasterVolume(0.0);
    super.dispose();
  }

  void _initDemoTracks() {
    loadFromEatsLua(DefaultSong.midnightBitesLua);
  }

  // Lua Engine Compilation & Hot Swap
  void compileLuaCode(String code) {
    luaCode = code;
    compilationResult = LuaEngine.compile(code);

    if (compilationResult.isSuccess) {
      // Synchronize Lua parameters to active track
      activeTrack.luaScriptCode = code;
      activeTrack.type = TrackType.luaScript;

      final newParams = <String, double>{};
      for (final p in compilationResult.params) {
        newParams[p.name] = activeTrack.luaParams[p.name] ?? p.defaultValue;
      }
      activeTrack.luaParams = newParams;

      // Invalidate PCM cache entries for this track so the next note trigger
      // re-synthesizes with the new Lua code rather than playing stale buffers.
      audioEngine.invalidateLuaCache(activeTrack.id);
      recordHistory('Compile Lua Script (${activeTrack.name})', icon: Icons.code);
    }
    notifyListeners();
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
    final idx = track.clips.indexOf(clip);
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
    clip.name = preset.name;
    clip.luaScriptCode = preset.code;

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

    recordHistory('Apply Preset "${preset.name}" to Clip', icon: Icons.tune);
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
      luaScriptCode: preset.code,
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

  void selectClip(TrackClip clip) {
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
    notifyListeners();
  }

  double _nextNoteTime = 0.0;
  // 100ms lookahead ensures the audio thread is always supplied with
  // timestamped notes ahead of time, preventing OS timer jitter from causing stutter.
  double get _scheduleAheadTime => 0.100;

  void togglePlay() {
    audioEngine.ensureContextRunning();
    _isPlaying = !_isPlaying;
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

  void stop() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _currentStep = _isLooping ? _loopStartBar * 16 : 0;
    _arrangerStep = _currentStep;
    _currentBar = _currentStep ~/ 16;
    notifyListeners();
  }

  /// Panic Button: Instantly halts all playback, stops active sound source nodes,
  /// clears PCM note audio cache and calculations, and resets meters.
  void panic() {
    stop();
    audioEngine.stopAllSound();
    audioEngine.clearPcmCache();
    notifyListeners();
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
      if (++loopGuard > 16) {
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
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
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

      // Arranger Clip Position Playback Logic
      for (final clip in track.clips) {
        final int clipStartStep = clip.startBar * 16;
        final int clipEndStep = (clip.startBar + clip.barLength) * 16;

        if (stepIdx >= clipStartStep && stepIdx < clipEndStep) {
          final int localStep = stepIdx - clipStartStep;
          
          final List<Note> effectiveNotes = clip.evaluatedNotesCache ??
              ((track.midiFXRack.any((f) => f.enabled) || clip.hasMidiScript)
                  ? pipeline.processClip(clip: clip, track: track, timeContext: timeContext)
                  : clip.notes);

          if (effectiveNotes.isNotEmpty) {
            // Find all notes starting within this 16th step window: [localStep, localStep + 1.0)
            final matchingNotes = effectiveNotes.where(
              (n) => n.startStep >= localStep && n.startStep < (localStep + 1.0),
            ).toList();

            if (matchingNotes.isNotEmpty) {
              if (track.isMonophonicTrack) {
                for (int mIdx = 0; mIdx < matchingNotes.length; mIdx++) {
                  final note = matchingNotes[mIdx];
                  final double subOffset = (note.startStep - localStep).clamp(0.0, 0.99);
                  final double noteHardwareTime = hardwareTime + (subOffset * stepDurationSec);

                  final nextNotes = effectiveNotes.where((n) => n.startStep > note.startStep && n.startStep <= (note.startStep + 1.5)).toList();
                  final int? rawTargetPitch = nextNotes.isNotEmpty ? nextNotes.first.pitch : null;
                  final int? targetPitch = rawTargetPitch != null ? remapPitch(rawTargetPitch) : null;

                  final bool hasPrevOverlap = effectiveNotes.any(
                    (n) => n.startStep < note.startStep && (n.startStep + n.durationSteps) > note.startStep,
                  );

                  final bool isSlideNote = note.isSlide ||
                      hasPrevOverlap ||
                      (note.durationSteps > 1.0) ||
                      (nextNotes.isNotEmpty && (note.isSlide || note.durationSteps >= 1.0));
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

  // Quantization Snap Setting (0.0 = No Snap, 0.5 = 1/32, 1.0 = 1/16, 2.0 = 1/8, 4.0 = 1/4)
  double _quantizeSnap = 1.0;
  double get quantizeSnap => _quantizeSnap;
  void setQuantizeSnap(double val) {
    _quantizeSnap = val;
    notifyListeners();
  }

  // Piano Roll Note Editing
  void addNote(TrackChannel track, Note note) {
    track.notes.add(note);
    _syncClipNotes(track);
    audioEngine.playNoteOrSample(
      track: track,
      midiNote: note.pitch,
      velocity: note.velocity,
    );
    recordHistory('Add Note ${_formatPitch(note.pitch)} (${track.name})', icon: Icons.music_note);
    notifyListeners();
  }

  void updateNote(TrackChannel track, Note updatedNote) {
    final idx = track.notes.indexWhere((n) => n.id == updatedNote.id);
    if (idx != -1) {
      track.notes[idx] = updatedNote;
      _syncClipNotes(track);
      recordHistory('Update Note ${_formatPitch(updatedNote.pitch)} (${track.name})', icon: Icons.music_note);
      notifyListeners();
    }
  }

  void removeNote(TrackChannel track, String noteId) {
    track.notes.removeWhere((n) => n.id == noteId);
    _syncClipNotes(track);
    recordHistory('Delete Note (${track.name})', icon: Icons.delete_outline);
    notifyListeners();
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
    notifyListeners();
  }

  void deleteTrack(TrackChannel track) {
    if (activePattern.tracks.length <= 1) return;
    final index = activePattern.tracks.indexOf(track);
    if (index != -1) {
      activePattern.tracks.removeAt(index);
      if (_activeTrackIndex >= activePattern.tracks.length) {
        _activeTrackIndex = activePattern.tracks.length - 1;
      }
      recordHistory('Delete Track "${track.name}"', icon: Icons.delete);
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

    final track = activePattern.tracks.removeAt(oldIndex);
    activePattern.tracks.insert(newIndex, track);
    _activeTrackIndex = newIndex;
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
  void addFXInsert(TrackChannel track, FXType type) {
    track.fxRack.add(FXInsert.create(type));
    audioEngine.invalidateLuaCache(track.id);
    notifyListeners();
  }

  void removeFXInsert(TrackChannel track, String fxId) {
    track.fxRack.removeWhere((f) => f.id == fxId);
    audioEngine.invalidateLuaCache(track.id);
    notifyListeners();
  }

  void reorderFXInsert(TrackChannel track, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex >= 0 && oldIndex < track.fxRack.length && newIndex >= 0 && newIndex <= track.fxRack.length) {
      final item = track.fxRack.removeAt(oldIndex);
      track.fxRack.insert(newIndex, item);
      audioEngine.invalidateLuaCache(track.id);
      notifyListeners();
    }
  }

  void moveFXUp(TrackChannel track, int index) {
    if (index > 0 && index < track.fxRack.length) {
      final fx = track.fxRack.removeAt(index);
      track.fxRack.insert(index - 1, fx);
      audioEngine.invalidateLuaCache(track.id);
      recordHistory('Move FX Up (${fx.name})', icon: Icons.arrow_upward);
      notifyListeners();
    }
  }

  void moveFXDown(TrackChannel track, int index) {
    if (index >= 0 && index < track.fxRack.length - 1) {
      final fx = track.fxRack.removeAt(index);
      track.fxRack.insert(index + 1, fx);
      audioEngine.invalidateLuaCache(track.id);
      recordHistory('Move FX Down (${fx.name})', icon: Icons.arrow_downward);
      notifyListeners();
    }
  }

  void toggleFXInsert(TrackChannel track, String fxId, bool enabled) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.enabled = enabled;
        audioEngine.invalidateLuaCache(track.id);
        notifyListeners();
        break;
      }
    }
  }

  void updateFXMix(TrackChannel track, String fxId, double mix) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.mix = mix.clamp(0.0, 1.0);
        audioEngine.invalidateLuaCache(track.id);
        notifyListeners();
        break;
      }
    }
  }

  void updateFXParam(TrackChannel track, String fxId, String paramName, double val) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.params[paramName] = val;
        audioEngine.invalidateLuaCache(track.id);
        notifyListeners();
        break;
      }
    }
  }

  void updateFXIrSample(TrackChannel track, String fxId, String irName) {
    for (final f in track.fxRack) {
      if (f.id == fxId) {
        f.irSampleName = irName;
        audioEngine.invalidateLuaCache(track.id);
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

  void loadFromEatsZipOrLua({Uint8List? zipBytes, String? luaContent}) {
    if (zipBytes != null) {
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
    final isLua = cleanName.toLowerCase().endsWith('.lua');

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


  void compileWrenCode(String code) => compileLuaCode(code);

  void loadLuaPreset(LuaPreset preset) {
    luaCode = preset.code;
    compileLuaCode(preset.code);
  }

  void loadWrenPreset(dynamic preset) {
    if (preset is LuaPreset) {
      loadLuaPreset(preset);
    } else {
      compileLuaCode(preset.code);
    }
  }

  void updateLuaParam(String paramName, double value) {
    activeTrack.luaParams[paramName] = value;
    notifyListeners();
  }

  void updateWrenParam(String paramName, double value) => updateLuaParam(paramName, value);

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

    WavExporter.saveWavFile(wavBytes, 'wren_daw_song.wav');
  }
}
