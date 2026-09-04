import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/sequence_editor_view.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';

void main() {
  group('TrackClip Pattern Index & Hex Model Tests', () {
    test('TrackClip defaults to patternIndex 0 and patternHex "00"', () {
      final clip = TrackClip(id: 'c1', name: 'Test Clip', trackId: 't1');
      expect(clip.patternIndex, 0);
      expect(clip.patternHex, '00');
    });

    test('TrackClip correctly formats patternHex for various numbers', () {
      final clip1 = TrackClip(id: 'c1', name: 'P1', trackId: 't1', patternIndex: 10);
      expect(clip1.patternHex, '0A');

      final clip2 = TrackClip(id: 'c2', name: 'P2', trackId: 't1', patternIndex: 255);
      expect(clip2.patternHex, 'FF');

      final clip3 = TrackClip(id: 'c3', name: 'P3', trackId: 't1', patternIndex: 16);
      expect(clip3.patternHex, '10');
    });

    test('TrackClip JSON serialization and deserialization preserves patternIndex', () {
      final clip = TrackClip(id: 'c1', name: 'Synth', trackId: 't1', patternIndex: 42);
      final json = clip.toJson();
      expect(json['patternIndex'], 42);

      final decoded = TrackClip.fromJson(json);
      expect(decoded.patternIndex, 42);
      expect(decoded.patternHex, '2A');
    });

    test('TrackClip.copyWith preserves or updates patternIndex', () {
      final clip = TrackClip(id: 'c1', name: 'Base', trackId: 't1', patternIndex: 5);
      final copiedSame = clip.copyWith();
      expect(copiedSame.patternIndex, 5);

      final copiedNew = clip.copyWith(patternIndex: 99);
      expect(copiedNew.patternIndex, 99);
      expect(copiedNew.patternHex, '63');
    });
  });

  group('DawState Sequence Editor Operations Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    test('Arranger view mode toggles properly between timeline and sequence', () {
      expect(dawState.arrangerViewMode, ArrangerViewMode.timeline);
      dawState.toggleArrangerViewMode();
      expect(dawState.arrangerViewMode, ArrangerViewMode.sequence);
      dawState.toggleArrangerViewMode();
      expect(dawState.arrangerViewMode, ArrangerViewMode.timeline);
    });

    test('selectSequenceCell clamps bar and track index within valid ranges', () {
      dawState.selectSequenceCell(12, 0);
      expect(dawState.sequenceSelectedBar, 12);
      expect(dawState.sequenceSelectedTrackIndex, 0);

      dawState.selectSequenceCell(-5, -2);
      expect(dawState.sequenceSelectedBar, 0);
      expect(dawState.sequenceSelectedTrackIndex, 0);

      dawState.selectSequenceCell(9999, 9999);
      expect(dawState.sequenceSelectedBar, dawState.totalTimelineBars - 1);
      expect(dawState.sequenceSelectedTrackIndex, dawState.visibleTracks.length - 1);
    });

    test('setPatternIndexAtBar and deleteClipAtBar update clips at bar', () {
      final track = dawState.activeTrack;
      track.clips.clear();

      // Add pattern index 7 at bar 4
      dawState.setPatternIndexAtBar(track, 4, 7);
      final clip = dawState.getClipAtBar(track, 4);
      expect(clip, isNotNull);
      expect(clip!.startBar, 4);
      expect(clip.patternIndex, 7);
      expect(clip.patternHex, '07');

      // Update pattern index to 15 at same bar
      dawState.setPatternIndexAtBar(track, 4, 15);
      final updatedClip = dawState.getClipAtBar(track, 4);
      expect(updatedClip!.patternIndex, 15);
      expect(updatedClip.patternHex, '0F');

      // Delete clip at bar 4
      dawState.deleteClipAtBar(track, 4);
      expect(dawState.getClipAtBar(track, 4), isNull);
    });

    test('duplicatePatternAtBar clones pattern with unique patternIndex', () {
      final track = dawState.activeTrack;
      track.clips.clear();

      dawState.setPatternIndexAtBar(track, 0, 0);
      dawState.duplicatePatternAtBar(track, 0);

      final cloned = dawState.getClipAtBar(track, 0);
      expect(cloned, isNotNull);
      expect(cloned!.name.contains('(Clone)'), isTrue);
      expect(cloned.patternIndex != 0, isTrue);
    });

    test('insertBarRow and deleteBarRow shift clips across tracks', () {
      final track = dawState.activeTrack;
      track.clips.clear();

      dawState.setPatternIndexAtBar(track, 2, 1);
      dawState.setPatternIndexAtBar(track, 6, 2);

      // Insert row at bar 4
      dawState.insertBarRow(4);
      // Clip at 2 should remain at 2
      expect(dawState.getClipAtBar(track, 2)?.patternIndex, 1);
      // Clip at 6 should be shifted to 7
      expect(dawState.getClipAtBar(track, 7)?.patternIndex, 2);

      // Delete row at bar 4
      dawState.deleteBarRow(4);
      expect(dawState.getClipAtBar(track, 2)?.patternIndex, 1);
      expect(dawState.getClipAtBar(track, 6)?.patternIndex, 2);
    });

    test('openSequenceCellInEditor navigates to EDIT tab in tracker view', () {
      final track = dawState.activeTrack;
      dawState.activeTabIndex = 0;

      dawState.openSequenceCellInEditor(track, 8);

      expect(dawState.activeTabIndex, 1); // EDIT tab
      expect(track.activeView, MusicViewType.tracker);
      expect(dawState.activeClip, isNotNull);
      expect(dawState.activeClip!.startBar, 8);
    });
  });

  group('Lua Serialization & Parser Tests for Pattern Index', () {
    test('eats_lua_serializer and eats_lua_parser preserve patternIndex', () {
      final daw = DawState();
      final track = daw.activeTrack;
      track.clips.clear();
      track.clips.add(TrackClip(
        id: 'lua_clip_test',
        name: 'Lead Melody',
        trackId: track.id,
        startBar: 2,
        barLength: 4,
        patternIndex: 43,
      ));

      final luaString = daw.exportToEatsLua();
      expect(luaString.contains('patternIndex = 43'), isTrue);

      final restoredState = DawState();
      EatsLuaParser.populateDawState(restoredState, luaString);
      final parsedTrack = restoredState.activePattern.tracks.firstWhere((t) => t.id == track.id);
      final parsedClip = parsedTrack.clips.firstWhere((c) => c.id == 'lua_clip_test');

      expect(parsedClip.patternIndex, 43);
      expect(parsedClip.patternHex, '2B');
    });
  });

  group('ArrangerView & SequenceEditorView Widget Tests', () {
    testWidgets('ArrangerView renders TIMELINE and SEQUENCE buttons and toggles views', (tester) async {
      final daw = DawState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: daw),
          ),
        ),
      );
      await tester.pump();

      // View switcher buttons are visible in header
      expect(find.text('TIMELINE'), findsOneWidget);
      expect(find.text('SEQUENCE'), findsOneWidget);

      // Initially in timeline mode
      expect(daw.arrangerViewMode, ArrangerViewMode.timeline);
      expect(find.byType(SequenceEditorView), findsNothing);

      // Tap SEQUENCE button
      await tester.tap(find.text('SEQUENCE'));
      await tester.pumpAndSettle();

      expect(daw.arrangerViewMode, ArrangerViewMode.sequence);
      expect(find.byType(SequenceEditorView), findsOneWidget);
      expect(find.text('SEQUENCE EDITOR'), findsOneWidget);
      expect(find.text('BAR / CHORD'), findsOneWidget);

      // Tap TIMELINE button to return
      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(daw.arrangerViewMode, ArrangerViewMode.timeline);
      expect(find.byType(SequenceEditorView), findsNothing);
    });

    testWidgets('SequenceEditorView right-click on track header triggers onOpenTrackProperties', (tester) async {
      final daw = DawState();
      TrackChannel? openedTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SequenceEditorView(
              dawState: daw,
              onOpenTrackProperties: (t) => openedTrack = t,
            ),
          ),
        ),
      );
      await tester.pump();

      final trackHeaderFinder = find.textContaining(daw.visibleTracks.first.name);
      expect(trackHeaderFinder, findsAtLeastNWidgets(1));

      await tester.tap(trackHeaderFinder.first, buttons: kSecondaryMouseButton);
      await tester.pump();

      expect(openedTrack, isNotNull);
      expect(openedTrack!.id, daw.visibleTracks.first.id);
      expect(daw.activeClip, isNull);
    });

    testWidgets('SequenceEditorView right-click on clip cell triggers onOpenClipProperties', (tester) async {
      final daw = DawState();
      final track = daw.visibleTracks.first;
      track.clips.clear();
      final testClip = TrackClip(id: 'c_test', name: 'Bass Clip', trackId: track.id, startBar: 0, barLength: 2, patternIndex: 42);
      track.clips.add(testClip);

      TrackClip? openedClip;
      TrackChannel? openedTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SequenceEditorView(
              dawState: daw,
              onOpenTrackProperties: (t) => openedTrack = t,
              onOpenClipProperties: (t, c) {
                openedTrack = t;
                openedClip = c;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final clipCellFinder = find.text('2A');
      expect(clipCellFinder, findsOneWidget);

      await tester.tap(clipCellFinder, buttons: kSecondaryMouseButton);
      await tester.pump();

      expect(openedTrack, isNotNull);
      expect(openedClip, isNotNull);
      expect(openedClip!.id, 'c_test');
      expect(daw.activeClip?.id, 'c_test');
    });
  });
}
