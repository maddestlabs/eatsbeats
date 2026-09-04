import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/services/gemini_service.dart';
import 'package:eatsbeats/services/ai_mixing_engine.dart';
import 'package:eatsbeats/ui/widgets/ai_assistant_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiService Configuration & Helper Tests', () {
    test('GeminiService manages API key and model properties', () {
      expect(GeminiService.hasApiKey, isFalse);

      GeminiService.apiKey = 'AIzaSyFakeKeyTest123';
      expect(GeminiService.hasApiKey, isTrue);
      expect(GeminiService.apiKey, equals('AIzaSyFakeKeyTest123'));

      expect(GeminiService.activeModel, equals('gemini-3.6-flash'));
      GeminiService.activeModel = 'gemini-3.0-flash';
      expect(GeminiService.activeModel, equals('gemini-3.0-flash'));
      GeminiService.activeModel = 'gemini-3.6-flash';
    });
  });

  group('AiMixingEngine Patch Application Tests', () {
    test('Applies full surgical mix and master adjustments to DawState', () async {
      final dawState = DawState();
      dawState.projectName = 'AI Mix Engine Test';

      final kickTrack = dawState.activePattern.tracks[0];
      kickTrack.name = 'Kick Drum';
      final bassTrack = dawState.activePattern.tracks[1];
      bassTrack.name = 'Acid Bass';

      // Verify starting state is flat
      expect(kickTrack.eqEnabled, isFalse);
      expect(dawState.masterSubCut, 25.0);

      // Simulated Gemini JSON patch
      final simulatedPatch = {
        "summary": "Tightened low end, carved 300Hz mud from kick, boosted master limiter to -14 LUFS.",
        "master": {
          "subCut": 32.0,
          "lowGain": 1.2,
          "midFreq": 340.0,
          "midGain": -1.5,
          "highGain": 2.0,
          "limiterEnabled": true,
          "ceilingDbfs": -0.3,
          "limiterDrive": 4.5,
          "targetLufs": -14.0
        },
        "tracks": {
          kickTrack.id: {
            "volume": 0.95,
            "pan": 0.0,
            "eq": {
              "enabled": true,
              "hpf": 35.0,
              "lowGain": 1.0,
              "midFreq": 300.0,
              "midGain": -2.5,
              "midQ": 1.8,
              "highGain": 0.5
            },
            "comment": "Notched 300Hz boxiness"
          },
          bassTrack.id: {
            "volume": 0.82,
            "pan": 0.0,
            "eq": {
              "enabled": true,
              "hpf": 40.0,
              "lowGain": -0.5,
              "midFreq": 500.0,
              "midGain": -1.0,
              "midQ": 1.0,
              "highGain": 0.0
            },
            "comment": "Locked sub fundamental"
          }
        }
      };

      // Apply the simulated patch logic directly through DawState
      dawState.beginHistoryTransaction('Gemini Auto-Mix & Master', icon: Icons.auto_awesome);

      for (final entry in (simulatedPatch['tracks'] as Map).entries) {
        final tId = entry.key;
        final data = entry.value as Map;
        final track = dawState.activePattern.tracks.firstWhere((t) => t.id == tId);
        dawState.setTrackVolume(track, (data['volume'] as num).toDouble());
        dawState.setTrackPan(track, (data['pan'] as num).toDouble());
        final eq = data['eq'] as Map;
        dawState.setTrackEq(
          track: track,
          enabled: eq['enabled'] == true,
          hpf: (eq['hpf'] as num?)?.toDouble(),
          lowGain: (eq['lowGain'] as num?)?.toDouble(),
          midFreq: (eq['midFreq'] as num?)?.toDouble(),
          midGain: (eq['midGain'] as num?)?.toDouble(),
          midQ: (eq['midQ'] as num?)?.toDouble(),
          highGain: (eq['highGain'] as num?)?.toDouble(),
        );
      }

      final master = simulatedPatch['master'] as Map;
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

      dawState.commitHistoryTransaction();

      // Verify applied parameters
      expect(kickTrack.volume, equals(0.95));
      expect(kickTrack.eqEnabled, isTrue);
      expect(kickTrack.eqHpf, equals(35.0));
      expect(kickTrack.eqMidFreq, equals(300.0));
      expect(kickTrack.eqMidGain, equals(-2.5));

      expect(dawState.masterSubCut, equals(32.0));
      expect(dawState.masterLowGain, equals(1.2));
      expect(dawState.masterMidGain, equals(-1.5));
      expect(dawState.masterHighGain, equals(2.0));
      expect(dawState.masterLimiterEnabled, isTrue);
      expect(dawState.masterLimiterDrive, equals(4.5));
      expect(dawState.masterTargetLufs, equals(-14.0));

      // Verify single undo restores previous state
      expect(dawState.history.canUndo, isTrue);
      dawState.undo();
      expect(dawState.activePattern.tracks[0].eqEnabled, isFalse);
      expect(dawState.masterSubCut, equals(25.0));
    });
  });

  group('AiAssistantDialog Widget Tests', () {
    testWidgets('Renders AiAssistantDialog and navigates between tabs', (tester) async {
      final dawState = DawState();
      GeminiService.apiKey = 'AIzaSyTestKey';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiAssistantDialog(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show Header and all 4 tabs
      expect(find.text('GEMINI AI ASSISTANT'), findsOneWidget);
      expect(find.text('MIX & MASTER'), findsOneWidget);
      expect(find.text('SONG ARCHITECT'), findsOneWidget);
      expect(find.text('SOUND ARCHITECT'), findsOneWidget);
      expect(find.text('AI SETTINGS'), findsOneWidget);

      // Switch to Song Architect tab
      await tester.tap(find.text('SONG ARCHITECT'));
      await tester.pumpAndSettle();
      expect(find.text('SONG ARRANGEMENT PROMPT:'), findsOneWidget);

      // Switch to Sound Architect tab
      await tester.tap(find.text('SOUND ARCHITECT'));
      await tester.pumpAndSettle();
      expect(find.text('PROMPT SOUND DESIGN:'), findsOneWidget);

      // Switch to AI Settings tab
      await tester.tap(find.text('AI SETTINGS'));
      await tester.pumpAndSettle();
      expect(find.text('GOOGLE GEMINI API KEY (FREE)'), findsOneWidget);
      expect(find.text('TEST KEY CONNECTION'), findsOneWidget);
    });
  });
}
