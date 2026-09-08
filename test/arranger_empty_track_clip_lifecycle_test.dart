import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Arranger Empty Track & Clip Lifecycle Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    tearDown(() {
      dawState.dispose();
    });

    test('Deleting the only clip on a track leaves the track with 0 clips', () {
      final track = dawState.activeTrack;
      expect(track.clips.isNotEmpty, isTrue, reason: 'Initial track has at least one clip');

      // If track has multiple clips, keep only 1 for test
      while (track.clips.length > 1) {
        track.clips.removeLast();
      }
      expect(track.clips.length, 1);

      final singleClip = track.clips.first;
      dawState.selectClip(singleClip);
      expect(dawState.activeClip, equals(singleClip));

      // Delete the only clip
      dawState.deleteClip(track, singleClip);

      expect(track.clips.isEmpty, isTrue, reason: 'Track should now have 0 clips');
      expect(dawState.activeClip, isNull, reason: 'Active clip should be null when no clips remain');
    });

    test('Selecting an empty track does not resurrect or recreate a phantom clip', () {
      expect(dawState.activePattern.tracks.length, greaterThanOrEqualTo(2));

      final track0 = dawState.activePattern.tracks[0];
      final track1 = dawState.activePattern.tracks[1];

      // Empty track0
      track0.clips.clear();
      expect(track0.clips.isEmpty, isTrue);

      // Switch active track to track 1
      dawState.activeTrackIndex = 1;
      expect(dawState.activeTrack.id, equals(track1.id));

      // Switch active track back to empty track 0
      dawState.activeTrackIndex = 0;
      expect(dawState.activeTrack.id, equals(track0.id));
      expect(track0.clips.isEmpty, isTrue, reason: 'Selecting track0 must not create a clip');

      // Access activeTrackClip (which occurs when editor rebuilds)
      final clip = dawState.activeTrackClip;
      expect(clip, isNotNull);
      expect(track0.clips.isEmpty, isTrue, reason: 'activeTrackClip must return a transient clip without mutating track0.clips');
    });

    test('Moving all clips from Track A to Track B leaves Track A empty permanently upon reselection', () {
      expect(dawState.activePattern.tracks.length, greaterThanOrEqualTo(2));

      final sourceTrack = dawState.activePattern.tracks[0];
      final targetTrack = dawState.activePattern.tracks[1];

      // Ensure sourceTrack has 1 clip
      if (sourceTrack.clips.isEmpty) {
        sourceTrack.clips.add(TrackClip(
          id: 'clip_src',
          name: 'Source Clip',
          trackId: sourceTrack.id,
          startBar: 0,
          barLength: 2,
        ));
      }

      final clipToMove = sourceTrack.clips.first;
      final moved = dawState.moveClipToTrack(clipToMove, sourceTrack, targetTrack, targetStartBar: 4);

      expect(moved, isTrue);
      expect(sourceTrack.clips.isEmpty, isTrue, reason: 'Source track should now have 0 clips');
      expect(targetTrack.clips.any((c) => c.id == clipToMove.id), isTrue);

      // Select source track again
      dawState.activeTrackIndex = 0;
      expect(dawState.activeTrack.id, equals(sourceTrack.id));
      expect(sourceTrack.clips.isEmpty, isTrue, reason: 'Reselecting source track must not recreate the clip');

      // Trigger activeTrackClip lookup
      final transient = dawState.activeTrackClip;
      expect(transient.id.startsWith('transient_clip_'), isTrue);
      expect(sourceTrack.clips.isEmpty, isTrue);
    });

    test('Authoring a note on an empty track creates a clip for that note', () {
      final track = dawState.activeTrack;
      track.clips.clear();
      expect(track.clips.isEmpty, isTrue);

      dawState.addNote(track, Note(
        id: 'n_authored',
        pitch: 60,
        startStep: 0,
        durationSteps: 2,
      ));

      expect(track.clips.length, 1, reason: 'Adding a note on an empty track should instantiate a clip');
      expect(track.clips.first.notes.any((n) => n.id == 'n_authored'), isTrue);
      expect(dawState.activeClip, equals(track.clips.first));
    });

    test('Toggling a step on an empty track creates a clip for that step', () {
      final track = dawState.activeTrack;
      track.clips.clear();
      for (final s in track.steps) {
        s.active = false;
      }
      expect(track.clips.isEmpty, isTrue);

      dawState.toggleStep(track, 0);

      expect(track.steps[0].active, isTrue);
      expect(track.clips.length, 1, reason: 'Toggling an active step on an empty track should instantiate a clip');
      expect(track.clips.first.notes.isNotEmpty, isTrue);
      expect(dawState.activeClip, equals(track.clips.first));
    });
  });
}
