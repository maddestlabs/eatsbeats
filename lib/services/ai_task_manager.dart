import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../lua/lua_script_library.dart';
import 'gemini_service.dart';
import 'ai_mixing_engine.dart';

enum AiTaskStatus {
  idle,
  running,
  readyForReview,
  failed,
  cancelled,
}

enum AiTaskType {
  mixAndMaster,
  soundInstrument,
  soundFx,
  songArrangement,
}

/// Manages non-blocking background AI tasks, cancellation tokens, and pending approval gates.
class AiTaskManager extends ChangeNotifier {
  static final AiTaskManager instance = AiTaskManager._internal();
  AiTaskManager._internal();

  AiTaskStatus _status = AiTaskStatus.idle;
  AiTaskStatus get status => _status;
  bool get isRunning => _status == AiTaskStatus.running;
  bool get hasPendingReview => _status == AiTaskStatus.readyForReview;

  AiTaskType? _taskType;
  AiTaskType? get taskType => _taskType;

  int get targetTab {
    switch (_taskType) {
      case AiTaskType.mixAndMaster:
        return 0;
      case AiTaskType.songArrangement:
        return 1;
      case AiTaskType.soundInstrument:
      case AiTaskType.soundFx:
        return 2;
      default:
        return 0;
    }
  }

  String _taskTitle = '';
  String get taskTitle => _taskTitle;

  final Stopwatch _stopwatch = Stopwatch();
  Duration get elapsed => _stopwatch.elapsed;

  AiMixResult? _pendingMixResult;
  AiMixResult? get pendingMixResult => _pendingMixResult;

  String? _pendingLuaScript;
  String? get pendingLuaScript => _pendingLuaScript;

  TrackChannel? _targetTrack;
  TrackChannel? get targetTrack => _targetTrack;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  http.Client? _activeClient;
  Timer? _tickerTimer;

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_status == AiTaskStatus.running) {
        notifyListeners();
      } else {
        _tickerTimer?.cancel();
      }
    });
  }

  /// Initiates a background Auto-Mix & Master task.
  Future<void> startAutoMix(
    DawState dawState, {
    String genre = 'Lo-Fi Chill',
    double targetLufs = -14.0,
    String customInstructions = '',
  }) async {
    if (isRunning) return;

    _status = AiTaskStatus.running;
    _taskType = AiTaskType.mixAndMaster;
    _taskTitle = 'AI Mix & Master ($genre, ${targetLufs.toInt()} LUFS)';
    _errorMessage = null;
    _pendingMixResult = null;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifyListeners();

    _activeClient = http.Client();

    try {
      final telemetry = dawState.extractMixTelemetry(
        genreVibe: genre,
        targetLufs: targetLufs,
      );

      final patch = await GeminiService.executeMixAndMaster(
        telemetry: telemetry,
        genre: genre,
        targetLufs: targetLufs,
        customInstructions: customInstructions,
      );

      if (_status == AiTaskStatus.cancelled) return;

      _pendingMixResult = AiMixResult(
        success: true,
        summary: patch['summary'] as String? ?? 'Mastering and balancing prepared.',
        tracksAdjusted: (patch['tracks'] as Map?)?.length ?? 0,
        rawPatch: patch,
      );

      _status = AiTaskStatus.readyForReview;
      _stopwatch.stop();
      notifyListeners();
    } catch (e) {
      if (_status == AiTaskStatus.cancelled) return;
      _status = AiTaskStatus.failed;
      _errorMessage = e.toString();
      _stopwatch.stop();
      notifyListeners();
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }
  }

  /// Initiates a background Sound Architect instrument/FX DSP generation task.
  Future<void> startGenerateSound(
    DawState dawState, {
    required String prompt,
    required String category, // 'instrument' or 'audio_fx'
    required TrackChannel targetTrack,
  }) async {
    if (isRunning) return;

    _status = AiTaskStatus.running;
    _taskType = category == 'instrument' ? AiTaskType.soundInstrument : AiTaskType.soundFx;
    _taskTitle = 'Generating ${category == 'instrument' ? "Instrument" : "Audio FX"}: "$prompt"';
    _errorMessage = null;
    _pendingLuaScript = null;
    _targetTrack = targetTrack;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifyListeners();

    _activeClient = http.Client();

    try {
      String luaCode = '';
      if (category == 'instrument') {
        luaCode = await GeminiService.generateInstrumentScript(prompt: prompt);
      } else {
        luaCode = await GeminiService.generateAudioFxScript(prompt: prompt);
      }

      if (_status == AiTaskStatus.cancelled) return;

      _pendingLuaScript = luaCode;
      _status = AiTaskStatus.readyForReview;
      _stopwatch.stop();
      notifyListeners();
    } catch (e) {
      if (_status == AiTaskStatus.cancelled) return;
      _status = AiTaskStatus.failed;
      _errorMessage = e.toString();
      _stopwatch.stop();
      notifyListeners();
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }
  }

  /// Initiates a background Song Architect full 4-track arrangement generation task.
  Future<void> startGenerateSong(
    DawState dawState, {
    required String prompt,
    String genre = 'Synthwave',
    double bpm = 120.0,
    String songKey = 'C Minor',
    int barLength = 8,
  }) async {
    if (isRunning) return;

    _status = AiTaskStatus.running;
    _taskType = AiTaskType.songArrangement;
    _taskTitle = 'Arranging $barLength-Bar $genre Song ("$prompt")';
    _errorMessage = null;
    _pendingLuaScript = null;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifyListeners();

    _activeClient = http.Client();

    try {
      final luaSong = await GeminiService.generateSongProject(
        prompt: prompt,
        genre: genre,
        bpm: bpm,
        songKey: songKey,
        barLength: barLength,
      );

      if (_status == AiTaskStatus.cancelled) return;

      _pendingLuaScript = luaSong;
      _status = AiTaskStatus.readyForReview;
      _stopwatch.stop();
      notifyListeners();
    } catch (e) {
      if (_status == AiTaskStatus.cancelled) return;
      _status = AiTaskStatus.failed;
      _errorMessage = e.toString();
      _stopwatch.stop();
      notifyListeners();
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }
  }

  /// Cancels the currently active in-flight AI task immediately.
  void cancelActiveTask() {
    if (_status != AiTaskStatus.running) return;
    _status = AiTaskStatus.cancelled;
    _activeClient?.close();
    _activeClient = null;
    _stopwatch.stop();
    _pendingMixResult = null;
    _pendingLuaScript = null;
    notifyListeners();
  }

  /// Applies the pending AI Mix, Sound, or Song changes to the active project state.
  void applyPendingResult(DawState dawState) {
    if (_status != AiTaskStatus.readyForReview) return;

    if (_taskType == AiTaskType.mixAndMaster && _pendingMixResult != null) {
      final patch = _pendingMixResult!.rawPatch;

      dawState.beginHistoryTransaction('Gemini Auto-Mix & Master', icon: Icons.auto_awesome);

      // Tracks
      final rawTracks = patch['tracks'];
      if (rawTracks is Map) {
        for (final entry in rawTracks.entries) {
          final trackId = entry.key.toString();
          final data = entry.value;
          if (data is! Map) continue;

          TrackChannel? targetTrack;
          for (final pattern in dawState.patterns) {
            for (final t in pattern.tracks) {
              if (t.id == trackId || t.name.toLowerCase() == trackId.toLowerCase()) {
                targetTrack = t;
                break;
              }
            }
            if (targetTrack != null) break;
          }

          if (targetTrack != null) {
            if (data['volume'] is num) {
              dawState.setTrackVolume(targetTrack, (data['volume'] as num).toDouble());
            }
            if (data['pan'] is num) {
              dawState.setTrackPan(targetTrack, (data['pan'] as num).toDouble());
            }
            final eq = data['eq'];
            if (eq is Map) {
              dawState.setTrackEq(
                track: targetTrack,
                enabled: eq['enabled'] == true,
                hpf: (eq['hpf'] as num?)?.toDouble(),
                lowGain: (eq['lowGain'] as num?)?.toDouble(),
                midFreq: (eq['midFreq'] as num?)?.toDouble(),
                midGain: (eq['midGain'] as num?)?.toDouble(),
                midQ: (eq['midQ'] as num?)?.toDouble(),
                highGain: (eq['highGain'] as num?)?.toDouble(),
              );
            }
          }
        }
      }

      // Master Bus
      final master = patch['master'];
      if (master is Map) {
        dawState.setMasterEq(
          subCut: (master['subCut'] as num?)?.toDouble(),
          lowGain: (master['lowGain'] as num?)?.toDouble(),
          midFreq: (master['midFreq'] as num?)?.toDouble(),
          midGain: (master['midGain'] as num?)?.toDouble(),
          highGain: (master['highGain'] as num?)?.toDouble(),
        );

        dawState.setMasterLimiter(
          enabled: master['limiterEnabled'] == true,
          ceilingDbfs: (master['ceilingDbfs'] as num?)?.toDouble(),
          driveDb: (master['limiterDrive'] as num?)?.toDouble(),
          targetLufs: (master['targetLufs'] as num?)?.toDouble(),
        );
      }

      dawState.commitHistoryTransaction();
    } else if (_taskType == AiTaskType.soundInstrument && _pendingLuaScript != null && _targetTrack != null) {
      final scriptDef = LuaScriptLibrary.parseFromLuaScript(_pendingLuaScript!);
      dawState.applyPreset(scriptDef, targetTrack: _targetTrack);
    } else if (_taskType == AiTaskType.soundFx && _pendingLuaScript != null && _targetTrack != null) {
      final scriptDef = LuaScriptLibrary.parseFromLuaScript(_pendingLuaScript!);
      dawState.addAudioFXFromPreset(_targetTrack!, scriptDef);
    } else if (_taskType == AiTaskType.songArrangement && _pendingLuaScript != null) {
      dawState.beginHistoryTransaction('Gemini Generated Song', icon: Icons.music_note);
      dawState.loadFromEatsLua(_pendingLuaScript!);
      dawState.commitHistoryTransaction();
    }

    reset();
  }

  /// Discards pending AI results without modifying the DAW project.
  void discardPendingResult() {
    reset();
  }

  /// Clears the task state back to idle.
  void reset() {
    _status = AiTaskStatus.idle;
    _taskType = null;
    _taskTitle = '';
    _pendingMixResult = null;
    _pendingLuaScript = null;
    _targetTrack = null;
    _errorMessage = null;
    _stopwatch.reset();
    notifyListeners();
  }
}
