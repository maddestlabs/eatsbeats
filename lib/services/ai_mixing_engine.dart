import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import 'gemini_service.dart';

class AiMixResult {
  final bool success;
  final String summary;
  final int tracksAdjusted;
  final Map<String, dynamic> rawPatch;
  final String? errorMessage;

  const AiMixResult({
    required this.success,
    required this.summary,
    required this.tracksAdjusted,
    required this.rawPatch,
    this.errorMessage,
  });
}

/// Orchestrates AI mixing and mastering passes on active DawState instances.
class AiMixingEngine {
  /// Analyzes the project state, prompts Gemini, and safely applies surgical mixing adjustments.
  static Future<AiMixResult> runAutoMixMaster({
    required DawState dawState,
    String genre = 'auto',
    double targetLufs = -14.0,
    String customInstructions = '',
  }) async {
    try {
      // 1. Extract comprehensive acoustic & spectral telemetry
      final telemetry = dawState.extractMixTelemetry(
        genreVibe: genre,
        targetLufs: targetLufs,
      );

      // 2. Request Gemini AI mix patch
      final patch = await GeminiService.executeMixAndMaster(
        telemetry: telemetry,
        genre: genre,
        targetLufs: targetLufs,
        customInstructions: customInstructions,
      );

      // 3. Begin single undoable transaction for the entire mix pass
      dawState.beginHistoryTransaction('Gemini Auto-Mix & Master', icon: Icons.auto_awesome);

      int tracksModified = 0;

      // 4. Apply Track Channel adjustments
      final rawTracks = patch['tracks'];
      if (rawTracks is Map) {
        for (final entry in rawTracks.entries) {
          final trackId = entry.key.toString();
          final data = entry.value;
          if (data is! Map) continue;

          // Match track by ID or fallback by name
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
            tracksModified++;

            // Volume & Pan
            if (data['volume'] is num) {
              dawState.setTrackVolume(targetTrack, (data['volume'] as num).toDouble());
            }
            if (data['pan'] is num) {
              dawState.setTrackPan(targetTrack, (data['pan'] as num).toDouble());
            }

            // Channel Strip EQ
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

      // 5. Apply Master Bus Processing
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

      // 6. Commit history transaction
      dawState.commitHistoryTransaction();

      final summary = patch['summary'] as String? ?? 'Mastering and track balancing applied successfully.';
      return AiMixResult(
        success: true,
        summary: summary,
        tracksAdjusted: tracksModified,
        rawPatch: patch,
      );
    } catch (e) {
      debugPrint('[AiMixingEngine] error: $e');
      return AiMixResult(
        success: false,
        summary: 'Mixing failed: $e',
        tracksAdjusted: 0,
        rawPatch: {},
        errorMessage: e.toString(),
      );
    }
  }
}
