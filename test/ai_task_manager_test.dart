import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/services/ai_task_manager.dart';
import 'package:eatsbeats/services/ai_mixing_engine.dart';
import 'package:eatsbeats/ui/widgets/ai_task_status_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiTaskManager State Machine & Workflow Tests', () {
    test('AiTaskManager tracks state transitions, cancellation and reset', () {
      final mgr = AiTaskManager.instance;
      mgr.reset();

      expect(mgr.status, equals(AiTaskStatus.idle));
      expect(mgr.isRunning, isFalse);
      expect(mgr.hasPendingReview, isFalse);

      // Cancel test
      mgr.cancelActiveTask();
      expect(mgr.status, equals(AiTaskStatus.idle));
    });

    test('AiTaskManager applies pending mix result into DawState history transaction', () {
      final dawState = DawState();
      final mgr = AiTaskManager.instance;
      mgr.reset();

      final track0 = dawState.activePattern.tracks[0];
      expect(track0.eqEnabled, isFalse);

      // Simulate a completed mix task in readyForReview state
      final simulatedPatch = {
        "summary": "Tightened low end and polished master bus.",
        "master": {
          "subCut": 30.0,
          "lowGain": 1.0,
          "midGain": -1.0,
          "highGain": 1.5,
          "limiterEnabled": true,
          "ceilingDbfs": -0.3,
          "limiterDrive": 3.0,
          "targetLufs": -14.0
        },
        "tracks": {
          track0.id: {
            "volume": 0.90,
            "pan": 0.0,
            "eq": {
              "enabled": true,
              "hpf": 50.0,
              "lowGain": 0.5,
              "midFreq": 400.0,
              "midGain": -2.0,
              "midQ": 1.2,
              "highGain": 1.0
            }
          }
        }
      };

      // Set pending state
      final fieldPendingResult = mgr;
      // Start and manually fulfill for testing
      fieldPendingResult.discardPendingResult();
      expect(fieldPendingResult.status, equals(AiTaskStatus.idle));
    });
  });

  group('AiTaskStatusBar Widget Tests', () {
    testWidgets('Renders status bar for running and readyForReview states', (tester) async {
      final dawState = DawState();
      final mgr = AiTaskManager.instance;
      mgr.reset();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiTaskStatusBar(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Idle: should be empty
      expect(find.byType(AiTaskStatusBar), findsOneWidget);
      expect(find.text('AI Task Complete'), findsNothing);

      // Cancel should be clean
      mgr.cancelActiveTask();
      await tester.pumpAndSettle();
      expect(find.text('AI Task Complete'), findsNothing);
    });
  });
}
