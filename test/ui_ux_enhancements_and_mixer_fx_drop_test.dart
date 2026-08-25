import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/ui/mixer_view.dart';
import 'package:eatsbeats/ui/widgets/project_browser_drawer.dart';
import 'package:eatsbeats/main.dart';
import 'package:eatsbeats/utils/eats_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delete Key Focus & History Restoration Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('Delete key on focused clip removes only the clip and supports undo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DawMainShell(dawState: dawState),
        ),
      );
      await tester.pumpAndSettle();

      final track = dawState.activeTrack;
      dawState.addClipToTrack(track, 2);
      await tester.pumpAndSettle();

      final initialClipCount = track.clips.length;
      expect(initialClipCount, greaterThanOrEqualTo(2));
      final clipToDelete = track.clips.last;
      dawState.activeClip = clipToDelete;
      await tester.pump();

      // Simulate Delete key
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(dawState.activeTrack.clips.length, equals(initialClipCount - 1));
      expect(dawState.activeTrack.clips.any((c) => c.id == clipToDelete.id), isFalse);

      // Undo deletion
      expect(dawState.undo(), isTrue);
      await tester.pumpAndSettle();

      expect(dawState.activeTrack.clips.length, equals(initialClipCount));
      expect(dawState.activeTrack.clips.any((c) => c.id == clipToDelete.id), isTrue);
    });

    testWidgets('Delete key when no clip is selected removes the active track and supports undo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DawMainShell(dawState: dawState),
        ),
      );
      await tester.pumpAndSettle();

      dawState.activeClip = null;
      await tester.pump();
      final initialTrackCount = dawState.activePattern.tracks.length;
      expect(initialTrackCount, greaterThan(1));
      final trackToDelete = dawState.activeTrack;

      // Simulate Delete key
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(dawState.activePattern.tracks.length, equals(initialTrackCount - 1));
      expect(dawState.activePattern.tracks.any((t) => t.id == trackToDelete.id), isFalse);

      // Undo deletion
      expect(dawState.undo(), isTrue);
      await tester.pumpAndSettle();

      expect(dawState.activePattern.tracks.length, equals(initialTrackCount));
      expect(dawState.activePattern.tracks.any((t) => t.id == trackToDelete.id), isTrue);
    });
  });

  group('Mixer View Drag & Drop Audio FX Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('Renders DragTarget on track strips and accepts Audio FX preset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find DragTarget widgets
      expect(find.byType(DragTarget<Object>), findsWidgets);

      final track = dawState.activeTrack;
      final initialFxCount = track.fxRack.length;

      // Find Stereo Delay audio FX preset
      final delayPreset = LuaPresetLibrary.getPresetById('stereo_delay')!;

      // Find the first DragTarget corresponding to the active track
      final dragTargets = tester.widgetList<DragTarget<Object>>(find.byType(DragTarget<Object>)).toList();
      expect(dragTargets.length, greaterThanOrEqualTo(2)); // Master + at least 1 track

      // Simulate dropping delay preset onto track
      dawState.applyPreset(delayPreset, targetTrack: track);
      await tester.pumpAndSettle();

      expect(track.fxRack.length, equals(initialFxCount + 1));
      expect(track.fxRack.any((f) => f.name.contains('Delay') || f.id.contains('delay')), isTrue);
    });

    testWidgets('Renders DragTarget on Master strip and accepts Audio FX preset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialMasterFxCount = dawState.masterTrack.fxRack.length;
      final limiterPreset = LuaPresetLibrary.getPresetById('master_limiter')!;

      dawState.addAudioFXFromPreset(dawState.masterTrack, limiterPreset);
      await tester.pumpAndSettle();

      expect(dawState.masterTrack.fxRack.length, equals(initialMasterFxCount + 1));
      expect(dawState.masterTrack.fxRack.any((f) => f.name.contains('Limiter') || f.id.contains('limiter')), isTrue);
    });
  });

  group('Session Auto-Restore & Persistence Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    tearDown(() {
      dawState.dispose();
    });

    test('Immediate save and session restoration roundtrip', () async {
      dawState.setProjectDetails('My Restored Hit', 'Producer X');
      dawState.setBpm(138.0);
      await dawState.saveSessionNow();

      // Create new DAW instance simulating restart
      final newDaw = DawState(enableMeterTimer: false);
      final restored = await newDaw.restoreSavedSession();
      expect(restored, isTrue);
      expect(newDaw.projectName, equals('My Restored Hit'));
      expect(newDaw.bpm, equals(138.0));
      newDaw.dispose();
    });
  });
}
