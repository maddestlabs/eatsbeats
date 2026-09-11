import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

import 'package:eatsbeats/eatscript/default_song_eat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Piano Roll and Arranger Tab Synchronization Tests', () {
    test('Notes edited in Piano Roll persist when switching tabs and track selection', () {
      final state = DawState();
      state.loadFromEatsLua(DefaultSongEat.midnightBitesEat);

      final track = state.activeTrack;
      expect(track.clips.isNotEmpty, isTrue);

      // Switch to Edit tab
      state.activeTabIndex = 1;
      expect(state.activeTabIndex, equals(1));

      // Add a test note to track
      final testNote = Note(
        id: 'test_persist_note_1',
        pitch: 55,
        startStep: 4.0,
        durationSteps: 2.0,
        velocity: 0.88,
      );
      state.addNote(track, testNote);

      expect(track.notes.any((n) => n.id == 'test_persist_note_1'), isTrue);
      expect(state.activeTrackClip.notes.any((n) => n.id == 'test_persist_note_1'), isTrue);

      // Mutate note positions as during Piano Roll dragging/resizing
      final targetNote = track.notes.firstWhere((n) => n.id == 'test_persist_note_1');
      targetNote.startStep = 6.0;
      targetNote.durationSteps = 4.0;
      state.syncActiveTrackNotesToClip();

      expect(state.activeTrackClip.notes.firstWhere((n) => n.id == 'test_persist_note_1').startStep, equals(6.0));
      expect(state.activeTrackClip.notes.firstWhere((n) => n.id == 'test_persist_note_1').durationSteps, equals(4.0));

      // Switch back to Arranger tab (index 0)
      state.activeTabIndex = 0;
      expect(state.activeTabIndex, equals(0));

      // Re-select track or clip in Arranger
      final initialTrackIndex = state.activeTrackIndex;
      state.activeTrackIndex = initialTrackIndex;
      final clip = state.getClipAtBar(track, 0) ?? track.clips.first;
      state.selectClip(clip);

      // Switch back to Edit tab (index 1)
      state.activeTabIndex = 1;
      expect(state.activeTabIndex, equals(1));

      // Verify the changes are completely intact
      expect(state.activeTrack.notes.any((n) => n.id == 'test_persist_note_1'), isTrue);
      final persistedNote = state.activeTrack.notes.firstWhere((n) => n.id == 'test_persist_note_1');
      expect(persistedNote.startStep, equals(6.0));
      expect(persistedNote.durationSteps, equals(4.0));
    });
  });
}
