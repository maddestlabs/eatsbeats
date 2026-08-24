import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/history_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryManager & Lua Diff Tests', () {
    test('Initializes with initial state snapshot', () {
      final state = DawState();
      expect(state.history.current, isNotNull);
      expect(state.history.canUndo, isFalse);
      expect(state.history.canRedo, isFalse);
      expect(state.history.current!.isMilestone, isTrue);
      state.dispose();
    });

    test('Records action and enables Undo', () {
      final state = DawState();
      final originalBpm = state.bpm;

      state.setBpm(140.0);
      state.recordHistory('Changed BPM to 140');

      expect(state.history.canUndo, isTrue);
      expect(state.history.canRedo, isFalse);
      expect(state.history.nextUndoDescription, contains('Project Started'));

      // Perform Undo
      final undoSuccess = state.undo();
      expect(undoSuccess, isTrue);
      expect(state.bpm, equals(originalBpm));
      expect(state.history.canUndo, isFalse);
      expect(state.history.canRedo, isTrue);
      expect(state.history.nextRedoDescription, contains('140'));

      // Perform Redo
      final redoSuccess = state.redo();
      expect(redoSuccess, isTrue);
      expect(state.bpm, equals(140.0));
      expect(state.history.canUndo, isTrue);
      expect(state.history.canRedo, isFalse);
      state.dispose();
    });

    test('Transaction coalescing groups continuous changes into single undo step', () {
      final state = DawState();
      final originalVol = state.masterVolume;

      state.beginHistoryTransaction('Adjust Master Volume');
      state.setMasterVolume(0.5);
      state.setMasterVolume(0.6);
      state.setMasterVolume(0.75);
      state.commitHistoryTransaction();

      expect(state.masterVolume, equals(0.75));
      expect(state.history.canUndo, isTrue);

      // Undo should revert to original before transaction started
      state.undo();
      expect(state.masterVolume, equals(originalVol));

      // Redo restores final transaction value
      state.redo();
      expect(state.masterVolume, equals(0.75));
      state.dispose();
    });

    test('Timeline multi-step jump / time-travel works correctly', () {
      final state = DawState();
      state.setBpm(100.0);
      state.recordHistory('Step 1: BPM 100');

      state.setBpm(110.0);
      state.recordHistory('Step 2: BPM 110');

      state.setBpm(120.0);
      state.recordHistory('Step 3: BPM 120');

      expect(state.bpm, equals(120.0));
      expect(state.history.timeline.length, equals(4)); // Init + 3 steps

      // Jump back to step 1 (timeline index 1)
      final jumpSuccess = state.history.jumpToTimelineIndex(state, 1);
      expect(jumpSuccess, isTrue);
      expect(state.bpm, equals(100.0));
      expect(state.history.canUndo, isTrue);
      expect(state.history.canRedo, isTrue);

      // Jump forward to step 3 (timeline index 3)
      state.history.jumpToTimelineIndex(state, 3);
      expect(state.bpm, equals(120.0));
      state.dispose();
    });

    test('Creates and preserves named milestones / checkpoints', () {
      final state = DawState();
      state.setProjectDetails('Cyber Neon Beat', 'Eats Producer');
      state.history.createMilestone(state, 'Bassline Arranged');

      expect(state.history.current!.isMilestone, isTrue);
      expect(state.history.current!.milestoneName, equals('Bassline Arranged'));
      state.dispose();
    });

    test('History max depth limit properly discards oldest items', () {
      final history = HistoryManager(maxDepth: 3);
      final state = DawState();
      history.init(state);

      for (int i = 1; i <= 5; i++) {
        state.setBpm(100.0 + i);
        history.record(state, 'Set BPM to ${100 + i}', force: true);
      }

      expect(history.past.length, lessThanOrEqualTo(3));
      state.dispose();
    });

    test('Computes line-by-line diff between two Lua scripts', () {
      const oldLua = 'bpm = 120\nvolume = 0.8\nname = "Intro"';
      const newLua = 'bpm = 128\nvolume = 0.8\nname = "Intro"\npan = 0.0';

      final diff = HistoryManager.computeDiff(oldLua, newLua);

      expect(diff.any((d) => d.type == HistoryDiffType.removed && d.text.contains('bpm = 120')), isTrue);
      expect(diff.any((d) => d.type == HistoryDiffType.added && d.text.contains('bpm = 128')), isTrue);
      expect(diff.any((d) => d.type == HistoryDiffType.unchanged && d.text.contains('volume = 0.8')), isTrue);
      expect(diff.any((d) => d.type == HistoryDiffType.added && d.text.contains('pan = 0.0')), isTrue);
    });
  });
}
