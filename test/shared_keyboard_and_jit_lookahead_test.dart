import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/widgets/keyboard_touch_controller.dart';
import 'package:eatsbeats/ui/virtual_piano_keyboard.dart';
import 'package:eatsbeats/ui/piano_roll_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyboardTouchController Tests', () {
    test('Note pitch names and black key identification', () {
      expect(KeyboardTouchController.getNoteName(48), 'C3');
      expect(KeyboardTouchController.getNoteName(49), 'C#3');
      expect(KeyboardTouchController.getNoteName(60), 'C4');
      expect(KeyboardTouchController.getNoteName(71), 'B4');

      expect(KeyboardTouchController.isBlackKey(48), isFalse); // C
      expect(KeyboardTouchController.isBlackKey(49), isTrue);  // C#
      expect(KeyboardTouchController.isBlackKey(50), isFalse); // D
      expect(KeyboardTouchController.isBlackKey(51), isTrue);  // D#
      expect(KeyboardTouchController.isBlackKey(52), isFalse); // E
      expect(KeyboardTouchController.isBlackKey(53), isFalse); // F
      expect(KeyboardTouchController.isBlackKey(54), isTrue);  // F#
    });

    test('Horizontal keyboard coordinate-to-pitch & velocity mapping', () {
      int? triggeredOnPitch;
      double? triggeredOnVel;
      int? triggeredOffPitch;

      final controller = KeyboardTouchController(
        orientation: KeyboardOrientation.horizontal,
        baseOctave: 3, // C3 to B5 (48 to 83)
        octavesCount: 3,
        onNoteOn: (p, v) {
          triggeredOnPitch = p;
          triggeredOnVel = v;
        },
        onNoteOff: (p) {
          triggeredOffPitch = p;
        },
      );

      const canvasSize = Size(600.0, 150.0);

      // Tap near bottom-left: should hit C3 (white key, pitch 48) with high velocity
      controller.handlePointerDown(
        const PointerDownEvent(pointer: 1),
        const Offset(10.0, 140.0),
        canvasSize,
      );

      expect(triggeredOnPitch, 48);
      expect(triggeredOnVel, isNotNull);
      expect(triggeredOnVel!, greaterThan(0.8));
      expect(controller.activeTouches.containsKey(1), isTrue);

      // Drag to right: should glissando to next white or black key
      controller.handlePointerMove(
        const PointerMoveEvent(pointer: 1),
        const Offset(120.0, 140.0),
        canvasSize,
      );

      expect(triggeredOffPitch, 48); // Released old pitch
      expect(triggeredOnPitch, isNot(48)); // Triggered new pitch

      // Pointer up: triggers noteOff and clears touch
      final currentPitch = triggeredOnPitch;
      controller.handlePointerUpOrCancel(1);
      expect(triggeredOffPitch, currentPitch);
      expect(controller.activeTouches.isEmpty, isTrue);

      controller.dispose();
    });

    test('Vertical keyboard coordinate-to-pitch & velocity mapping', () {
      int? lastOnPitch;
      double? lastOnVel;
      int? lastOffPitch;

      final controller = KeyboardTouchController(
        orientation: KeyboardOrientation.vertical,
        minPitch: 24,
        maxPitch: 84,
        keyHeight: 20.0,
        onNoteOn: (p, v) {
          lastOnPitch = p;
          lastOnVel = v;
        },
        onNoteOff: (p) {
          lastOffPitch = p;
        },
      );

      const sidebarSize = Size(70.0, 1220.0);

      // Tap at the top (pos.dy = 5.0) -> maxPitch = 84
      controller.handlePointerDown(
        const PointerDownEvent(pointer: 2),
        const Offset(35.0, 5.0),
        sidebarSize,
        maxPitchOverride: 84,
        keyHeightOverride: 20.0,
      );

      expect(lastOnPitch, 84);
      expect(lastOnVel, closeTo(0.575, 0.05)); // Halfway across horizontal 70px

      // Drag vertically downward across keys (glissando down 40px = down 2 keys => pitch 82)
      controller.handlePointerMove(
        const PointerMoveEvent(pointer: 2),
        const Offset(35.0, 45.0),
        sidebarSize,
        maxPitchOverride: 84,
        keyHeightOverride: 20.0,
      );

      expect(lastOffPitch, 84); // Released pitch 84
      expect(lastOnPitch, 82);  // Activated pitch 82

      // Release key
      controller.handlePointerUpOrCancel(2);
      expect(lastOffPitch, 82);
      expect(controller.activeTouches.isEmpty, isTrue);

      controller.dispose();
    });
  });

  group('JIT Lookahead Playback & ADSR Tests', () {
    test('AudioEngine noteOn and noteOff ADSR lifecycle', () {
      final state = DawState();
      final track = state.activeTrack;

      // noteOn triggers and registers active voice
      state.audioEngine.noteOn(
        track: track,
        midiNote: 60,
        velocity: 0.85,
        sustainDurationSec: 2.0,
      );

      // noteOff stops the note smoothly with release
      state.audioEngine.noteOff(
        track: track,
        midiNote: 60,
        releaseSec: 0.12,
      );

      // stopAllLiveNotes clears all live voices
      state.audioEngine.stopAllLiveNotes();
    });

    test('prewarmPatternCache uses JIT lookahead window without full-song stalls', () {
      final state = DawState();
      final track = state.activeTrack;

      // Add a lengthy 32-bar clip
      final longClip = TrackClip(
        id: 'long_clip',
        name: 'Lengthy 32 Bar Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 32,
        notes: List.generate(64, (idx) {
          return Note(
            id: 'note_$idx',
            pitch: 48 + (idx % 12),
            startStep: idx * 2.0, // Every 2 steps across 32 bars (128 steps)
            durationSteps: 2.0,
            velocity: 0.8,
          );
        }),
      );
      track.clips.add(longClip);

      final double stepDurationSec = 60.0 / 120.0 / 4.0;

      // JIT prewarm at step 0 with lookahead 16 steps (1 bar)
      state.audioEngine.clearPcmCache();
      state.audioEngine.prewarmPatternCache(
        [track],
        stepDurationSec,
        startStep: 0,
        lookaheadSteps: 16,
      );

      // Verify that only the 9 notes within the lookahead window [0..16] were cached,
      // while the remaining 55 notes across the 32-bar clip are deferred JIT
      expect(state.audioEngine.pcmCacheCount, equals(9));
    });

    testWidgets('VirtualPianoKeyboard and PianoRollView render with shared controller without errors', (tester) async {
      final dawState = DawState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: PianoRollView(dawState: dawState)),
                VirtualPianoKeyboard(dawState: dawState),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(PianoRollView), findsOneWidget);
      expect(find.byType(VirtualPianoKeyboard), findsOneWidget);
    });
  });
}
