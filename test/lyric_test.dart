import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/lyric_model.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/ui/arranger_view.dart';

void main() {
  group('Lyrics & LRC System Tests', () {
    test('LyricCue JSON roundtrip', () {
      final cue = LyricCue(
        id: 'cue_1',
        startStep: 16.0,
        durationSteps: 4.0,
        text: 'Welcome',
        phoneticOverride: 'w eh l k ah m',
        pitch: 1.2,
        rate: 0.9,
      );

      final json = cue.toJson();
      final restored = LyricCue.fromJson(json);

      expect(restored.id, equals('cue_1'));
      expect(restored.startStep, equals(16.0));
      expect(restored.durationSteps, equals(4.0));
      expect(restored.text, equals('Welcome'));
      expect(restored.phoneticOverride, equals('w eh l k ah m'));
      expect(restored.pitch, equals(1.2));
      expect(restored.rate, equals(0.9));
    });

    test('LrcParser parses standard line-synced LRC', () {
      const lrc = '''
[ti:Test Song]
[ar:EatsBeats]
[00:00.00] Intro line
[00:02.00] Second lyric line
''';

      final cues = LrcParser.parse(lrc, bpm: 120.0);
      expect(cues.length, equals(2));
      expect(cues[0].text, equals('Intro line'));
      expect(cues[0].startStep, equals(0.0));
      // At 120 BPM, 1 step = 0.125s, so 2.0s = 16.0 steps
      expect(cues[1].text, equals('Second lyric line'));
      expect(cues[1].startStep, closeTo(16.0, 0.1));
    });

    test('LrcParser exports cues back to LRC format', () {
      final cues = [
        LyricCue(id: '1', startStep: 0.0, text: 'Hello'),
        LyricCue(id: '2', startStep: 16.0, text: 'World'),
      ];

      final exported = LrcParser.exportToLrc(cues, bpm: 120.0, title: 'My Track');
      expect(exported, contains('[00:00.00] Hello'));
      expect(exported, contains('[00:02.00] World'));
    });

    test('TrackChannel with Lyrics and TTS configuration serializes correctly', () {
      final track = TrackChannel(
        id: 'track_vox',
        name: 'Lead Vocal',
        color: const Color(0xFF00FFE0),
        type: TrackType.tts,
        enableTts: true,
        ttsVoice: 'en-US',
        ttsPitch: 1.1,
        ttsRate: 1.2,
        lyrics: [
          LyricCue(id: 'cue_a', startStep: 4.0, text: 'Yeah'),
        ],
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, lyric: 'Wel-'),
          Note(id: 'n2', pitch: 64, startStep: 2.0, lyric: 'come'),
        ],
      );

      expect(track.hasLyrics, isTrue);

      final json = track.toJson();
      final restored = TrackChannel.fromJson(json);

      expect(restored.hasLyrics, isTrue);
      expect(restored.enableTts, isTrue);
      expect(restored.ttsVoice, equals('en-US'));
      expect(restored.lyrics.length, equals(1));
      expect(restored.lyrics.first.text, equals('Yeah'));
      expect(restored.notes[0].lyric, equals('Wel-'));
      expect(restored.notes[1].lyric, equals('come'));
    });

    testWidgets('ArrangerView displays track and clip lyrics properly', (tester) async {
      final dawState = DawState();
      final track = dawState.activePattern.tracks[0];
      track.lyrics = [
        LyricCue(id: 'c1', startStep: 0.0, durationSteps: 4.0, text: 'TrackLyric1'),
      ];
      final clip = TrackClip(
        id: 'clip_with_lyric',
        trackId: track.id,
        name: 'Vocal Hook',
        startBar: 0,
        barLength: 2,
        lyrics: [
          LyricCue(id: 'c2', startStep: 0.0, durationSteps: 4.0, text: 'ClipLyricText'),
        ],
      );
      track.clips.add(clip);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify track lyric text is rendered on timeline
      expect(find.text('TrackLyric1'), findsOneWidget);
      // Verify clip lyric text is rendered on clip banner
      expect(find.text('ClipLyricText'), findsOneWidget);
      // Verify LYRIC badge appears in clip header
      expect(find.text('LYRIC'), findsOneWidget);
    });
  });
}
