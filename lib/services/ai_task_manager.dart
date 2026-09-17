import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../audio/procgen/ensemble_blueprint.dart';
import '../audio/procgen/procedural_ensemble_engine.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../eatscript/eats_script_library.dart';
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
  styleAssessmentAndTakes,
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
      case AiTaskType.songArrangement:
        return 0; // Compose
      case AiTaskType.styleAssessmentAndTakes:
        return 1; // Extend
      case AiTaskType.soundInstrument:
      case AiTaskType.soundFx:
        return 2; // Design
      case AiTaskType.mixAndMaster:
        return 3; // Master
      default:
        return 0;
    }
  }

  String _taskTitle = '';
  String get taskTitle => _taskTitle;

  SongStyleAssessment? _pendingStyleAssessment;
  SongStyleAssessment? get pendingStyleAssessment => _pendingStyleAssessment;

  int _selectedTakeIndex = 0;
  int get selectedTakeIndex => _selectedTakeIndex;
  set selectedTakeIndex(int idx) {
    if (_selectedTakeIndex != idx) {
      _selectedTakeIndex = idx;
      if (_pendingStyleAssessment != null && _pendingStyleAssessment!.takes.isNotEmpty) {
        final clamped = idx.clamp(0, _pendingStyleAssessment!.takes.length - 1);
        _pendingBlueprint = _pendingStyleAssessment!.takes[clamped];
        _pendingBlueprintSeed = (DateTime.now().microsecondsSinceEpoch % 900000) + 100000;
        _pendingEatScript = const JsonEncoder.withIndent('  ').convert(_pendingBlueprint!.toJson());
      }
      notifyListeners();
    }
  }

  final Stopwatch _stopwatch = Stopwatch();
  Duration get elapsed => _stopwatch.elapsed;

  AiMixResult? _pendingMixResult;
  AiMixResult? get pendingMixResult => _pendingMixResult;

  String? _pendingEatScript;
  String? get pendingEatScript => _pendingEatScript;

  SongStructureBlueprint? _pendingBlueprint;
  SongStructureBlueprint? get pendingBlueprint => _pendingBlueprint;

  int? _pendingBlueprintSeed;
  int? get pendingBlueprintSeed => _pendingBlueprintSeed;

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
    _taskType = category == 'instrument'
        ? AiTaskType.soundInstrument
        : (category == 'midi_fx' ? AiTaskType.soundFx : AiTaskType.soundFx);
    final catName = category == 'instrument' ? 'Instrument' : (category == 'midi_fx' ? 'MIDI FX' : 'Audio FX');
    _taskTitle = 'Generating $catName: "$prompt"';
    _errorMessage = null;
    _pendingEatScript = null;
    _targetTrack = targetTrack;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifyListeners();

    _activeClient = http.Client();

    try {
      String eatScriptCode = '';
      if (category == 'instrument') {
        eatScriptCode = await GeminiService.generateInstrumentScript(prompt: prompt);
      } else if (category == 'midi_fx') {
        eatScriptCode = await GeminiService.generateMidiFxScript(prompt: prompt);
      } else {
        eatScriptCode = await GeminiService.generateAudioFxScript(prompt: prompt);
      }

      if (_status == AiTaskStatus.cancelled) return;

      _pendingEatScript = eatScriptCode;
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

  /// Initiates a background Song Architect ensemble arrangement generation task using Gemini.
  Future<void> startGenerateSong(
    DawState dawState, {
    required String prompt,
    int? requestedBars,
  }) async {
    if (isRunning) return;

    _status = AiTaskStatus.running;
    _taskType = AiTaskType.songArrangement;
    _taskTitle = 'Composing Song Architecture ("$prompt")';
    _errorMessage = null;
    _pendingEatScript = null;
    _pendingBlueprint = null;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifyListeners();

    _activeClient = http.Client();

    try {
      final blueprint = await GeminiService.generateEnsembleBlueprint(
        prompt: prompt,
        requestedBars: requestedBars,
      );

      if (_status == AiTaskStatus.cancelled) return;

      _pendingBlueprint = blueprint;
      _pendingBlueprintSeed = (DateTime.now().microsecondsSinceEpoch % 900000) + 100000;
      const encoder = JsonEncoder.withIndent('  ');
      _pendingEatScript = encoder.convert(blueprint.toJson());
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

  /// Initiates a background song style assessment and alternative takes generation task.
  Future<void> startSongStyleAssessmentAndTakes(DawState dawState) async {
    if (isRunning) return;

    _status = AiTaskStatus.running;
    _taskType = AiTaskType.styleAssessmentAndTakes;
    _taskTitle = 'Analyzing Project Style & Composing Takes';
    _errorMessage = null;
    _pendingStyleAssessment = null;
    _pendingBlueprint = null;
    _pendingEatScript = null;
    _selectedTakeIndex = 0;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifyListeners();

    _activeClient = http.Client();

    try {
      final telemetry = dawState.extractSongStyleTelemetry();
      final assessment = await GeminiService.analyzeSongStyleAndGenerateTakes(telemetry: telemetry);

      if (_status == AiTaskStatus.cancelled) return;

      _pendingStyleAssessment = assessment;
      if (assessment.takes.isNotEmpty) {
        _selectedTakeIndex = 0;
        _pendingBlueprint = assessment.takes[0];
        _pendingBlueprintSeed = (DateTime.now().microsecondsSinceEpoch % 900000) + 100000;
        _pendingEatScript = const JsonEncoder.withIndent('  ').convert(_pendingBlueprint!.toJson());
      }
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
    _pendingEatScript = null;
    _pendingBlueprint = null;
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
    } else if (_taskType == AiTaskType.soundInstrument && _pendingEatScript != null && _targetTrack != null) {
      final scriptDef = EatScriptLibrary.parseFromScript(_pendingEatScript!);
      dawState.applyPreset(scriptDef, targetTrack: _targetTrack);
    } else if (_taskType == AiTaskType.soundFx && _pendingEatScript != null && _targetTrack != null) {
      final scriptDef = EatScriptLibrary.parseFromScript(_pendingEatScript!);
      dawState.addAudioFXFromPreset(_targetTrack!, scriptDef);
    } else if (_taskType == AiTaskType.styleAssessmentAndTakes && _pendingBlueprint != null) {
      dawState.applyArrangementTake(
        _pendingBlueprint!,
        takeTitle: _pendingBlueprint!.title,
      );
    } else if (_taskType == AiTaskType.songArrangement && _pendingBlueprint != null) {
      final seed = _pendingBlueprintSeed ?? 42;
      dawState.beginHistoryTransaction('AI Song Architect: ${_pendingBlueprint!.title} (#$seed)', icon: Icons.auto_awesome);
      ProceduralEnsembleEngine.renderBlueprint(dawState, _pendingBlueprint!, seed: seed);
      dawState.commitHistoryTransaction();
    } else if (_taskType == AiTaskType.songArrangement && _pendingEatScript != null) {
      dawState.beginHistoryTransaction('Gemini Generated Song', icon: Icons.music_note);
      dawState.loadFromEats(_pendingEatScript!);
      dawState.commitHistoryTransaction();
    }

    reset();
  }

  /// Discards pending AI results without modifying the DAW project.
  void discardPendingResult() {
    reset();
  }

  /// Injects a pending blueprint for testing review and DAW application workflows.
  @visibleForTesting
  void setMockBlueprintForReview(SongStructureBlueprint blueprint, {int seed = 42}) {
    _status = AiTaskStatus.readyForReview;
    _taskType = AiTaskType.songArrangement;
    _taskTitle = blueprint.title;
    _pendingBlueprint = blueprint;
    _pendingBlueprintSeed = seed;
    _pendingEatScript = jsonEncode(blueprint.toJson());
    notifyListeners();
  }

  /// Injects a mock style assessment and takes for review and testing.
  @visibleForTesting
  void setMockStyleAssessmentForReview(SongStyleAssessment assessment, {int selectedTake = 0}) {
    _status = AiTaskStatus.readyForReview;
    _taskType = AiTaskType.styleAssessmentAndTakes;
    _taskTitle = assessment.detectedGenre;
    _pendingStyleAssessment = assessment;
    _selectedTakeIndex = selectedTake;
    if (assessment.takes.isNotEmpty) {
      _pendingBlueprint = assessment.takes[selectedTake.clamp(0, assessment.takes.length - 1)];
      _pendingBlueprintSeed = 42;
      _pendingEatScript = jsonEncode(_pendingBlueprint!.toJson());
    }
    notifyListeners();
  }

  /// Clears the task state back to idle.
  void reset() {
    _status = AiTaskStatus.idle;
    _taskType = null;
    _taskTitle = '';
    _pendingMixResult = null;
    _pendingEatScript = null;
    _pendingBlueprint = null;
    _pendingBlueprintSeed = null;
    _pendingStyleAssessment = null;
    _selectedTakeIndex = 0;
    _targetTrack = null;
    _errorMessage = null;
    _stopwatch.reset();
    notifyListeners();
  }
}
