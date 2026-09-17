import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/services/gemini_service.dart';
import 'package:eatsbeats/services/ai_task_manager.dart';
import 'package:eatsbeats/audio/procgen/ensemble_blueprint.dart';
import 'package:eatsbeats/eatscript/eats_script_library.dart';
import 'package:eatsbeats/utils/eats_storage_helper.dart';
import 'package:eatsbeats/ui/widgets/ai_assistant_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Song Style Assessment & Alternative Takes Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
      dawState.projectName = 'Eats Lofi';
      dawState.setBpm(125.0);
      dawState.setSongKey('C Major');

      // Clear default tracks and create the 6 tracks from the user's loop
      final pattern = dawState.activePattern;
      pattern.tracks.clear();

      // 1. Kick
      final kick = TrackChannel(
        id: 'track_kick',
        name: 'FM Acoustic Kick',
        color: const Color(0xFF21F4E8),
        type: TrackType.eatScript,
        eatScriptCode: 'def process(): return 0.0\nFmAcousticKick = True',
        clips: [
          TrackClip(
            id: 'c_kick',
            name: 'Kick Clip',
            trackId: 'track_kick',
            startBar: 0,
            barLength: 4,
            notes: [
              Note(id: 'k1', pitch: 36, startStep: 0.0, durationSteps: 4.0),
              Note(id: 'k2', pitch: 36, startStep: 16.0, durationSteps: 4.0),
            ],
          )
        ],
      );
      pattern.tracks.add(kick);

      // 2. Hi-Hat
      final hat = TrackChannel(
        id: 'track_hat',
        name: 'FM Acoustic Hi-Hat',
        color: const Color(0xFFF9C74F),
        type: TrackType.eatScript,
        clips: [
          TrackClip(
            id: 'c_hat',
            name: 'Hats Clip',
            trackId: 'track_hat',
            startBar: 0,
            barLength: 4,
            notes: [
              Note(id: 'h1', pitch: 42, startStep: 0.0, durationSteps: 1.0),
              Note(id: 'h2', pitch: 42, startStep: 4.0, durationSteps: 1.0),
            ],
          )
        ],
      );
      pattern.tracks.add(hat);

      // 3. Snare
      final snare = TrackChannel(
        id: 'track_snare',
        name: 'Analog 808 Snare',
        color: const Color(0xFFF94144),
        type: TrackType.eatScript,
        clips: [
          TrackClip(
            id: 'c_snare',
            name: 'Snare Clip',
            trackId: 'track_snare',
            startBar: 0,
            barLength: 4,
            notes: [
              Note(id: 's1', pitch: 38, startStep: 8.0, durationSteps: 2.0),
              Note(id: 's2', pitch: 38, startStep: 24.0, durationSteps: 2.0),
            ],
          )
        ],
      );
      pattern.tracks.add(snare);

      // 4. DX7 E-Piano
      final dx7 = TrackChannel(
        id: 'track_dx7',
        name: 'Yamaha DX7 E-Piano',
        color: const Color(0xFF90BE6D),
        type: TrackType.eatScript,
        chordFollowMode: ChordFollowMode.chord,
        eatScriptCode: 'def process(): return 0.0\nDX7EPiano = True',
        clips: [
          TrackClip(
            id: 'c_dx7',
            name: 'DX7 Clip',
            trackId: 'track_dx7',
            startBar: 0,
            barLength: 4,
            notes: [
              Note(id: 'd1', pitch: 65, startStep: 0.0, durationSteps: 16.0),
              Note(id: 'd2', pitch: 69, startStep: 16.0, durationSteps: 16.0),
            ],
          )
        ],
      );
      pattern.tracks.add(dx7);

      // 5. Steel-String Acoustic Guitar (Muted)
      final guitar = TrackChannel(
        id: 'track_guitar',
        name: 'Steel-String Acoustic Guitar',
        color: const Color(0xFFF3722C),
        type: TrackType.eatScript,
        isMuted: true,
        chordFollowMode: ChordFollowMode.chord,
        eatScriptCode: 'def process(): return 0.0\nSteelAcoustic = True',
        clips: [
          TrackClip(
            id: 'c_gtr',
            name: 'Acoustic Guitar Clip',
            trackId: 'track_guitar',
            startBar: 0,
            barLength: 4,
            notes: [
              Note(id: 'g1', pitch: 79, startStep: 4.0, durationSteps: 2.0),
              Note(id: 'g2', pitch: 70, startStep: 6.5, durationSteps: 2.0),
              Note(id: 'g3', pitch: 75, startStep: 12.0, durationSteps: 2.0),
            ],
          )
        ],
      );
      pattern.tracks.add(guitar);

      // 6. Eats-303
      final bass = TrackChannel(
        id: 'track_303',
        name: 'Eats-303',
        color: const Color(0xFF43AA8B),
        type: TrackType.eatScript,
        chordFollowMode: ChordFollowMode.bass,
        eatScriptCode: 'def process(): return 0.0\nEats303 = True',
        clips: [
          TrackClip(
            id: 'c_303',
            name: '303 Bass Clip',
            trackId: 'track_303',
            startBar: 0,
            barLength: 4,
            notes: [
              Note(id: 'b1', pitch: 36, startStep: 0.0, durationSteps: 4.0),
              Note(id: 'b2', pitch: 48, startStep: 20.0, durationSteps: 4.0),
            ],
          )
        ],
      );
      pattern.tracks.add(bass);

      // 4-Bar Chord Track (IVmaj9 - iiim7 - vim9 - Imaj7)
      dawState.chordTrack = [
        ChordEvent(id: 'c1', startBar: 0, barLength: 1.0, rootPitchClass: 5, quality: ChordQuality.maj9),
        ChordEvent(id: 'c2', startBar: 1, barLength: 1.0, rootPitchClass: 4, quality: ChordQuality.minor7),
        ChordEvent(id: 'c3', startBar: 2, barLength: 1.0, rootPitchClass: 9, quality: ChordQuality.min9),
        ChordEvent(id: 'c4', startBar: 3, barLength: 1.0, rootPitchClass: 0, quality: ChordQuality.major7),
      ];
      dawState.setLoopPoints(0, 4);
      dawState.history.init(dawState, initialDescription: 'Initial 4-Bar Loop');
    });

    test('extractSongStyleTelemetry accurately captures musical and track telemetry', () {
      final telemetry = dawState.extractSongStyleTelemetry();

      expect(telemetry['title'], equals('Eats Lofi'));
      expect(telemetry['bpm'], equals(125.0));
      expect(telemetry['songKey'], equals('C Major'));
      expect(telemetry['isMinor'], isFalse);

      final chords = telemetry['chordTrack'] as List;
      expect(chords.length, equals(4));
      expect(chords[0]['chord'], contains('F'));
      expect(chords[1]['chord'], contains('E'));

      final tracks = telemetry['tracks'] as List;
      expect(tracks.length, equals(6));

      final guitarMeta = tracks.firstWhere((t) => t['name'] == 'Steel-String Acoustic Guitar');
      expect(guitarMeta['isMuted'], isTrue, reason: 'Muted acoustic guitar must be flagged as a reserved layer');
      expect(guitarMeta['role'], equals('guitar'));

      final kickMeta = tracks.firstWhere((t) => t['name'] == 'FM Acoustic Kick');
      expect(kickMeta['isMuted'], isFalse);
    });

    test('analyzeSongStyleAndGenerateTakes generates 3 contrasting arrangement takes with bridge contrast', () async {
      final telemetry = dawState.extractSongStyleTelemetry();
      final assessment = await GeminiService.analyzeSongStyleAndGenerateTakes(telemetry: telemetry);

      expect(assessment.detectedGenre, contains('Lo-Fi'));
      expect(assessment.stylisticVibe, isNotEmpty);
      expect(assessment.harmonicObservations, isNotEmpty);
      expect(assessment.arrangementOpportunities.length, greaterThanOrEqualTo(2));
      expect(assessment.takes.length, equals(3));

      // Take 1 (Classic Arc)
      final take1 = assessment.takes[0];
      expect(take1.title, contains('Take 1'));
      expect(take1.totalBars, equals(32));
      expect(take1.sections.length, equals(5)); // Intro, Verse 1, Chorus 1, Verse 2, Outro

      // Take 2 (Neo-Soul Bridge Modulation)
      final take2 = assessment.takes[1];
      expect(take2.title, contains('Take 2'));
      expect(take2.totalBars, equals(40));
      expect(take2.sections.any((s) => s.name.contains('Bridge')), isTrue);

      // Verify Bridge in Take 2 contains contrasting chords
      final bridgeSection = take2.sections.firstWhere((s) => s.name.contains('Bridge'));
      expect(bridgeSection.chords.length, greaterThanOrEqualTo(2));
      expect(bridgeSection.chords.any((c) => c.quality == ChordQuality.dominant7), isTrue);
    });

    test('applyArrangementTake arranges timeline non-destructively and activates muted guitar in chorus', () async {
      final telemetry = dawState.extractSongStyleTelemetry();
      final assessment = await GeminiService.analyzeSongStyleAndGenerateTakes(telemetry: telemetry);
      final take2 = assessment.takes[1]; // 40-bar take with Bridge

      // Verify initial state before arrangement
      final guitarTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'track_guitar');
      expect(guitarTrack.isMuted, isTrue);
      expect(guitarTrack.clips.length, equals(1));
      expect(dawState.loopEndBar, equals(4));
      expect(dawState.totalTimelineBars, equals(32)); // Arranger minimum canvas bars is 32

      // Apply Take 2 non-destructively
      final result = dawState.applyArrangementTake(take2, takeTitle: take2.title);

      expect(result.isSuccess, isTrue);
      expect(dawState.totalTimelineBars, equals(40));
      expect(dawState.loopEndBar, equals(40));
      expect(dawState.isSongMode, isTrue);

      // 1. Verify user tracks were PRESERVED (not cleared or replaced with factory presets)
      expect(dawState.activePattern.tracks.length, equals(6));
      expect(dawState.activePattern.tracks[0].eatScriptCode, contains('FmAcousticKick'));
      expect(dawState.activePattern.tracks[3].eatScriptCode, contains('DX7EPiano'));
      expect(dawState.activePattern.tracks[4].eatScriptCode, contains('SteelAcoustic'));
      expect(dawState.activePattern.tracks[5].eatScriptCode, contains('Eats303'));

      // 2. Verify Section Clip placement:
      // Intro (Bars 0-4): Drums, Bass, and Guitar are silent (tacet); DX7 plays
      final kickTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'track_kick');
      final dx7Track = dawState.activePattern.tracks.firstWhere((t) => t.id == 'track_dx7');
      final bassTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'track_303');

      expect(kickTrack.clips.any((c) => c.startBar == 0), isFalse, reason: 'Kick must rest in Intro');
      expect(bassTrack.clips.any((c) => c.startBar == 0), isFalse, reason: 'Bass must rest in Intro');
      expect(guitarTrack.clips.any((c) => c.startBar == 0), isFalse, reason: 'Guitar must rest in Intro');
      expect(dx7Track.clips.any((c) => c.startBar == 0), isTrue, reason: 'DX7 must play in Intro');

      // Verse 1 (Bars 4-12): Kick, Bass, DX7 active; Guitar rests
      expect(kickTrack.clips.any((c) => c.startBar == 4), isTrue, reason: 'Kick must enter in Verse 1');
      expect(bassTrack.clips.any((c) => c.startBar == 4), isTrue, reason: 'Bass must enter in Verse 1');
      expect(guitarTrack.clips.any((c) => c.startBar == 4), isFalse, reason: 'Guitar must remain quiet in Verse 1');

      // Chorus 1 (Bars 12-20): ALL tracks active, GUITAR UNMUTED AND ACTIVE!
      expect(guitarTrack.clips.any((c) => c.startBar == 12), isTrue, reason: 'Guitar MUST enter in Chorus 1');
      expect(kickTrack.clips.any((c) => c.startBar == 12), isTrue);
      expect(bassTrack.clips.any((c) => c.startBar == 12), isTrue);
      expect(dx7Track.clips.any((c) => c.startBar == 12), isTrue);

      // Channel mute un-toggled so timeline clips sound
      expect(guitarTrack.isMuted, isFalse);

      // 3. Verify Bridge chords are present in chordTrack (Bars 20-28)
      final bridgeChords = dawState.chordTrack.where((c) => c.startBar >= 20 && c.startBar < 28).toList();
      expect(bridgeChords, isNotEmpty);
      expect(bridgeChords.any((c) => c.quality == ChordQuality.dominant7 || c.quality == ChordQuality.min9), isTrue);

      // 4. Test Undo Functionality
      dawState.history.undo(dawState);
      expect(dawState.loopEndBar, equals(4));
      expect(dawState.totalTimelineBars, equals(32));
      expect(dawState.activePattern.tracks[4].clips.length, equals(1));
    });

    test('AiTaskManager startSongStyleAssessmentAndTakes lifecycle works properly', () async {
      final mgr = AiTaskManager.instance;
      expect(mgr.isRunning, isFalse);

      await mgr.startSongStyleAssessmentAndTakes(dawState);

      expect(mgr.status, equals(AiTaskStatus.readyForReview));
      expect(mgr.taskType, equals(AiTaskType.styleAssessmentAndTakes));
      expect(mgr.pendingStyleAssessment, isNotNull);
      expect(mgr.pendingStyleAssessment!.takes.length, equals(3));
      expect(mgr.selectedTakeIndex, equals(0));
      expect(mgr.pendingBlueprint, isNotNull);

      // Switch take to Take 2
      mgr.selectedTakeIndex = 1;
      expect(mgr.selectedTakeIndex, equals(1));
      expect(mgr.pendingBlueprint!.title, contains('Take 2'));

      // Apply to DAW state
      mgr.applyPendingResult(dawState);
      expect(mgr.status, equals(AiTaskStatus.idle));
      expect(dawState.totalTimelineBars, equals(40));
    });

    test('Non-destructive arrangement macro is registered in Project Macros and executes successfully', () {
      // 1. Verify registered in EatScriptLibrary as macro/projectAction
      final macro = EatScriptLibrary.getPresetById('action_non_destructive_arranger');
      expect(macro, isNotNull);
      expect(macro!.isMacro, isTrue);
      expect(macro.category, equals(EatScriptCategory.projectAction));
      expect(macro.name, contains('Non-Destructive Takes'));

      // 2. Execute Macro via DawState.runProjectScript with Take 2 (40 Bars)
      final result = dawState.runProjectScript(macro, params: {'Take': 0});
      expect(result.isSuccess, isTrue);
      expect(dawState.totalTimelineBars, equals(40));
      expect(dawState.loopEndBar, equals(40));

      // 3. User synth code preserved
      expect(dawState.activePattern.tracks[0].eatScriptCode, contains('FmAcousticKick'));
      expect(dawState.activePattern.tracks[4].eatScriptCode, contains('SteelAcoustic'));

      // 4. Undo restores initial state
      dawState.history.undo(dawState);
      expect(dawState.loopEndBar, equals(4));
    });

    test('DX7 looped 2-bar clip is tiled across all 4 bars in arranged sections without empty space', () {
      // Create a DX7 track where clip barLength is 4, but notes only cover 2 bars (step 0..32) with loopLengthBars = 2
      final dx7Track = dawState.activePattern.tracks.firstWhere((t) => t.id == 'track_dx7');
      dx7Track.clips.clear();
      dx7Track.clips.add(TrackClip(
        id: 'dx7_loop_clip',
        name: 'DX7 Looped',
        trackId: 'track_dx7',
        startBar: 0,
        barLength: 4,
        loopLengthBars: 2,
        notes: [
          Note(id: 'dx7_n0', pitch: 60, startStep: 0, durationSteps: 16),
          Note(id: 'dx7_n1', pitch: 64, startStep: 16, durationSteps: 16),
        ],
      ));

      // Apply Take 1
      final telemetry = dawState.extractSongStyleTelemetry();
      final assessment = GeminiService.generateOfflineStyleAssessment(telemetry);
      dawState.applyArrangementTake(assessment.takes[0]);

      // Verify the DX7 track clips
      expect(dx7Track.clips.isNotEmpty, isTrue);
      final firstClip = dx7Track.clips.first;
      expect(firstClip.barLength, equals(4));
      // First clip notes must be tiled to 4 bars (contains notes starting at step 0, 16, 32, 48)
      final noteStarts = firstClip.notes.map((n) => n.startStep).toList();
      expect(noteStarts.contains(0.0), isTrue);
      expect(noteStarts.contains(16.0), isTrue);
      expect(noteStarts.contains(32.0), isTrue, reason: 'Bar 2 must not be empty space');
      expect(noteStarts.contains(48.0), isTrue, reason: 'Bar 3 must not be empty space');

      // Timeline notes must also be populated across all 4 bars of each section
      final introNotes = dx7Track.notes.where((n) => n.startStep < 64.0).toList();
      expect(introNotes.any((n) => n.startStep >= 32.0 && n.startStep < 48.0), isTrue);
      expect(introNotes.any((n) => n.startStep >= 48.0 && n.startStep < 64.0), isTrue);
    });

    test('Arranger maintains project chord progression (Fmaj9, Emin7, Amin9, Cmaj7) without altering roots', () {
      dawState.chordTrack = [
        ChordEvent(id: 'c0', startBar: 0, barLength: 1.0, rootPitchClass: 5, quality: ChordQuality.maj9),
        ChordEvent(id: 'c1', startBar: 1, barLength: 1.0, rootPitchClass: 4, quality: ChordQuality.minor7),
        ChordEvent(id: 'c2', startBar: 2, barLength: 1.0, rootPitchClass: 9, quality: ChordQuality.min9),
        ChordEvent(id: 'c3', startBar: 3, barLength: 1.0, rootPitchClass: 0, quality: ChordQuality.major7),
      ];

      final macro = EatScriptLibrary.getPresetById('action_non_destructive_arranger')!;

      // 1. Run with Take 1 (Classic Arc, Take: 1)
      final result = dawState.runProjectScript(macro, params: {'Take': 1});
      expect(result.isSuccess, isTrue);

      // Verify chordTrack preserves roots: 5, 4, 9, 0 repeatedly
      expect(dawState.chordTrack.length, greaterThanOrEqualTo(32));
      expect(dawState.chordTrack[0].rootPitchClass, equals(5));
      expect(dawState.chordTrack[0].quality, equals(ChordQuality.maj9));
      expect(dawState.chordTrack[1].rootPitchClass, equals(4));
      expect(dawState.chordTrack[1].quality, equals(ChordQuality.minor7));
      expect(dawState.chordTrack[2].rootPitchClass, equals(9));
      expect(dawState.chordTrack[2].quality, equals(ChordQuality.min9));
      expect(dawState.chordTrack[3].rootPitchClass, equals(0));
      expect(dawState.chordTrack[3].quality, equals(ChordQuality.major7));

      // Bar 4 (Verse 1 start) must continue with Fmaj9
      expect(dawState.chordTrack[4].rootPitchClass, equals(5));
      expect(dawState.chordTrack[5].rootPitchClass, equals(4));

      // 2. Run with Take 0 (Take 2 with bridge) and ContrastBridgeChords: 1 ("No (Repeat Base Progression)")
      dawState.history.undo(dawState);
      final resultNoMod = dawState.runProjectScript(macro, params: {
        'Take': 0,
        'ContrastBridgeChords': 1,
      });
      expect(resultNoMod.isSuccess, isTrue);

      // In the bridge (around bar 20), chords must still repeat the base progression (root 5, 4, 9, 0)
      final bridgeChord = dawState.chordTrack[20];
      expect(bridgeChord.rootPitchClass, equals(5), reason: 'Bridge must repeat base progression when contrast is disabled');
    });

    test('saveArrangementTakesAsProjects saves all 3 takes to Projects directory without altering active session and triggers auto-refresh', () async {
      EatsStorageHelper.setTestMode(true);

      int refreshNotifications = 0;
      void onNotify() => refreshNotifications++;
      EatsStorageHelper.onProjectsChanged.addListener(onNotify);

      final telemetry = dawState.extractSongStyleTelemetry();
      final assessment = GeminiService.generateOfflineStyleAssessment(telemetry);

      final initialBars = dawState.totalTimelineBars;
      final initialName = dawState.projectName;

      final saved = await dawState.saveArrangementTakesAsProjects(assessment);
      expect(saved.length, equals(3));
      expect(saved[0], contains('Take 1'));
      expect(saved[1], contains('Take 2'));
      expect(saved[2], contains('Take 3'));

      // Active state was untouched
      expect(dawState.totalTimelineBars, equals(initialBars));
      expect(dawState.projectName, equals(initialName));

      // Browser Projects tab selected and UI notified to refresh
      expect(dawState.browserTabIndex, equals(4));
      expect(refreshNotifications, greaterThan(0));

      EatsStorageHelper.onProjectsChanged.removeListener(onNotify);
    });

    testWidgets('AiAssistantDialog renders 5 tabs and initialTab routing works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiAssistantDialog(
              dawState: dawState,
              initialTab: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPOSE'), findsOneWidget);
      expect(find.text('EXTEND'), findsOneWidget);
      expect(find.text('DESIGN'), findsOneWidget);
      expect(find.text('MASTER'), findsOneWidget);
      expect(find.text('AI SETTINGS'), findsOneWidget);
    });

    testWidgets('AiAssistantDialog banner redirects to AI SETTINGS tab', (tester) async {
      GeminiService.apiKey = ''; // Ensure no key
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiAssistantDialog(
              dawState: dawState,
              initialTab: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GO TO AI SETTINGS'), findsOneWidget);
      await tester.tap(find.text('GO TO AI SETTINGS'));
      await tester.pumpAndSettle();

      // Should now be on AI SETTINGS tab (tab 4)
      expect(find.text('GOOGLE GEMINI API KEY (FREE)'), findsOneWidget);
    });

    testWidgets('Extend tab detects long projects and provides override', (tester) async {
      // Set key so banner is bypassed
      GeminiService.apiKey = 'AIzaSyTestKey';

      // Ensure timeline has > 8 bars
      dawState.activePattern.tracks.first.clips.add(
        TrackClip(
          id: 'c_long',
          name: 'Long Clip',
          trackId: 'track_kick',
          startBar: 8,
          barLength: 16,
          notes: [],
        ),
      );
      expect(dawState.totalTimelineBars, greaterThan(8));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiAssistantDialog(
              dawState: dawState,
              initialTab: 1, // Extend
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('FULL SONG DETECTED'), findsOneWidget);
      expect(find.textContaining('FORCE RE-ARRANGE'), findsOneWidget);

      // Tap force re-arrange
      await tester.tap(find.textContaining('FORCE RE-ARRANGE'));
      await tester.pumpAndSettle();

      // Now extender panel is displayed with OVERRIDE tag
      expect(find.text('OVERRIDE'), findsOneWidget);
      expect(find.text('LOOP EXTENDER & NON-DESTRUCTIVE TAKES'), findsOneWidget);

      GeminiService.apiKey = '';
    });
  });
}
