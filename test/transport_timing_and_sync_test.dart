import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeContext Timeline & Beat Consistency Tests', () {
    test('TimeContext accurately reports step and beat across bars without double-counting', () {
      final dawState = DawState();

      // Bar 0, Step 0
      dawState.seekToBar(0);
      expect(dawState.currentBar, equals(0));
      expect(dawState.currentStep, equals(0));
      var ctx = dawState.timeContext;
      expect(ctx.currentBeat, equals(0.0));
      expect(ctx.currentBar, equals(1.0)); // 1-indexed in TimeContext (Bar 1, Beat 1)

      // Bar 1 (Step 16)
      dawState.seekToBar(1);
      expect(dawState.currentBar, equals(1));
      expect(dawState.currentStep, equals(16));
      ctx = dawState.timeContext;
      // In 4/4 time, 16 steps = 4 beats = start of Bar 2
      expect(ctx.currentBeat, equals(4.0));
      expect(ctx.currentBar, equals(2.0));

      // Bar 3 (Step 48)
      dawState.seekToBar(3);
      expect(dawState.currentBar, equals(3));
      expect(dawState.currentStep, equals(48));
      ctx = dawState.timeContext;
      // 48 steps = 12 beats = start of Bar 4
      expect(ctx.currentBeat, equals(12.0));
      expect(ctx.currentBar, equals(4.0));

      // Fractional Arranger Step 18.0 (Bar 1, Beat 1.5)
      dawState.seekToArrangerStep(18.0);
      expect(dawState.currentStep, equals(18));
      expect(dawState.currentBar, equals(1));
      ctx = dawState.timeContext;
      expect(ctx.currentBeat, equals(4.5));
      expect(ctx.currentBar, equals(2.125));

      dawState.dispose();
    });
  });

  group('Master Audio Clock & Transport Synchronization Tests', () {
    test('Scheduler loop uses audio hardware clock without wall-clock drift or stalls', () async {
      final dawState = DawState();

      expect(dawState.isPlaying, isFalse);
      expect(dawState.currentStep, equals(0));

      dawState.setLooping(false);
      dawState.togglePlay();
      expect(dawState.isPlaying, isTrue);

      final initialAudioTime = dawState.audioEngine.currentTime;

      // Allow several scheduler loops to execute
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final activeAudioTime = dawState.audioEngine.currentTime;
      expect(activeAudioTime, greaterThan(initialAudioTime));

      // Steps should have advanced
      expect(dawState.currentStep, greaterThan(1));
      expect(dawState.arrangerStep, greaterThan(1));
      expect(dawState.continuousArrangerStepNotifier.value, greaterThan(0.5));

      // Seek during active playback immediately re-anchors timeline and steps
      dawState.seekToBar(4);
      expect(dawState.currentStep, equals(64));
      expect(dawState.arrangerStep, equals(64));
      expect(dawState.currentBar, equals(4));
      expect(dawState.continuousArrangerStepNotifier.value, equals(64.0));

      // Allow playback to proceed from new position
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(dawState.currentStep, greaterThanOrEqualTo(64));
      expect(dawState.continuousArrangerStepNotifier.value, greaterThan(64.0));

      dawState.stop();
      expect(dawState.isPlaying, isFalse);

      dawState.dispose();
    });

    test('Transport respects loop boundaries seamlessly with audio clock', () async {
      final dawState = DawState();
      dawState.setBpm(180.0); // Fast tempo to observe looping
      dawState.setLoopPoints(0, 1); // Loop between Bar 0 and Bar 1 (0 to 16 steps)
      dawState.setLooping(true);

      dawState.togglePlay();
      expect(dawState.isPlaying, isTrue);

      // Wait enough time for at least 1 full loop cycle
      // At 180 BPM in 4/4, 1 bar = 1.33 seconds. We can advance or test seek near loop boundary
      dawState.seekToArrangerStep(15.0);
      expect(dawState.currentStep, equals(15));

      // Wait 350ms to cross the 16-step loop point
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // Should have looped back within [0, 16)
      expect(dawState.currentStep, lessThan(16));

      dawState.stop();
      dawState.dispose();
    });
  });
}
