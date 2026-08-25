import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/widgets/preset_search_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track Folders & Group Tracks Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    test('Create Track Folder and group initial tracks', () {
      expect(dawState.activePattern.tracks.isNotEmpty, true);
      final initialCount = dawState.activePattern.tracks.length;
      final t1 = dawState.activePattern.tracks[0];
      final t2 = dawState.activePattern.tracks[1];

      final folder = dawState.createTrackFolder(
        name: 'Drums Group',
        initialTrackIds: [t1.id, t2.id],
        color: const Color(0xFFFF5722),
      );

      expect(folder.isFolder, true);
      expect(folder.type, TrackType.folder);
      expect(folder.name, 'Drums Group');
      expect(folder.color, const Color(0xFFFF5722));
      expect(t1.parentFolderId, folder.id);
      expect(t2.parentFolderId, folder.id);
      expect(t1.color, const Color(0xFFFF5722)); // Color sync
      expect(t2.color, const Color(0xFFFF5722));

      final children = dawState.getFolderChildren(folder.id);
      expect(children.length, 2);
      expect(children.contains(t1), true);
      expect(children.contains(t2), true);
    });

    test('Folder collapse and visibleTracks behavior', () {
      final t1 = dawState.activePattern.tracks[0];
      final t2 = dawState.activePattern.tracks[1];

      final folder = dawState.createTrackFolder(
        name: 'Synth Group',
        initialTrackIds: [t1.id, t2.id],
      );

      // Initially expanded
      expect(folder.isCollapsed, false);
      expect(dawState.visibleTracks.contains(folder), true);
      expect(dawState.visibleTracks.contains(t1), true);
      expect(dawState.visibleTracks.contains(t2), true);

      // Collapse folder
      dawState.toggleFolderCollapsed(folder);
      expect(folder.isCollapsed, true);

      // When collapsed, folder is visible but children are hidden in visibleTracks
      expect(dawState.visibleTracks.contains(folder), true);
      expect(dawState.visibleTracks.contains(t1), false);
      expect(dawState.visibleTracks.contains(t2), false);

      // Expand again
      dawState.toggleFolderCollapsed(folder);
      expect(folder.isCollapsed, false);
      expect(dawState.visibleTracks.contains(t1), true);
      expect(dawState.visibleTracks.contains(t2), true);
    });

    test('Ungroup track and move between folders', () {
      final t1 = dawState.activePattern.tracks[0];
      final folder1 = dawState.createTrackFolder(name: 'Folder 1', initialTrackIds: [t1.id]);
      expect(t1.parentFolderId, folder1.id);

      final folder2 = dawState.createTrackFolder(name: 'Folder 2');
      dawState.setTrackFolder(t1.id, folder2.id);
      expect(t1.parentFolderId, folder2.id);

      dawState.ungroupTrack(t1.id);
      expect(t1.parentFolderId, isNull);
      expect(t1.isChildTrack, false);
    });

    test('Deleting folder unparents children gracefully without deleting them', () {
      final t1 = dawState.activePattern.tracks[0];
      final t2 = dawState.activePattern.tracks[1];

      final folder = dawState.createTrackFolder(
        name: 'Temp Folder',
        initialTrackIds: [t1.id, t2.id],
      );

      expect(dawState.activePattern.tracks.contains(folder), true);
      expect(t1.parentFolderId, folder.id);

      dawState.deleteTrack(folder);

      expect(dawState.activePattern.tracks.contains(folder), false);
      expect(dawState.activePattern.tracks.contains(t1), true);
      expect(dawState.activePattern.tracks.contains(t2), true);
      expect(t1.parentFolderId, isNull);
      expect(t2.parentFolderId, isNull);
    });

    test('Effective mute and solo hierarchy', () {
      final t1 = dawState.activePattern.tracks[0];
      final folder = dawState.createTrackFolder(
        name: 'Vocal Stack',
        initialTrackIds: [t1.id],
      );

      expect(dawState.isTrackEffectivelyMuted(t1), false);
      expect(dawState.isTrackEffectivelySoloed(t1), false);

      // Muting folder mutes child
      folder.isMuted = true;
      expect(dawState.isTrackEffectivelyMuted(t1), true);

      folder.isMuted = false;
      expect(dawState.isTrackEffectivelyMuted(t1), false);

      // Soloing folder solos child
      folder.isSoloed = true;
      expect(dawState.isTrackEffectivelySoloed(t1), true);
    });

    test('JSON serialization and deserialization backward compatibility', () {
      final t1 = dawState.activePattern.tracks[0];
      final folder = dawState.createTrackFolder(
        name: 'Bass Group',
        initialTrackIds: [t1.id],
        color: const Color(0xFF00E5FF),
      );
      folder.isCollapsed = true;

      final folderJson = folder.toJson();
      expect(folderJson['type'], 'folder');
      expect(folderJson['isCollapsed'], true);
      expect(folderJson['isFolderBus'], true);

      final decodedFolder = TrackChannel.fromJson(folderJson);
      expect(decodedFolder.isFolder, true);
      expect(decodedFolder.isCollapsed, true);
      expect(decodedFolder.name, 'Bass Group');
      expect(decodedFolder.color.value, const Color(0xFF00E5FF).value);

      final childJson = t1.toJson();
      expect(childJson['parentFolderId'], folder.id);

      final decodedChild = TrackChannel.fromJson(childJson);
      expect(decodedChild.parentFolderId, folder.id);
      expect(decodedChild.isChildTrack, true);
    });

    testWidgets('PresetSearchDialog.showAddTrack renders Track Folder as first item and creates folder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => PresetSearchDialog.showAddTrack(context, dawState: dawState),
                child: const Text('Open Add'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Add'));
      await tester.pumpAndSettle();

      // Verify dialog header and Track Folder card as first item
      expect(find.text('ADD TRACK / FOLDER'), findsOneWidget);
      expect(find.text('Track Folder'), findsOneWidget);
      expect(find.text('FOLDER'), findsOneWidget);
      expect(find.text('SYNTHS & INSTRUMENTS'), findsOneWidget);

      final initialTrackCount = dawState.activePattern.tracks.length;

      // Tap on the Track Folder card
      await tester.tap(find.text('Track Folder'));
      await tester.pumpAndSettle();

      // Verify a new folder track was created
      expect(dawState.activePattern.tracks.length, initialTrackCount + 1);
      final newFolder = dawState.activePattern.tracks.last;
      expect(newFolder.isFolder, true);
    });
  });
}

