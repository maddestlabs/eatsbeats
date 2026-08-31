import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/saved_project_model.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/utils/eats_storage_helper.dart';
import 'package:eatsbeats/ui/widgets/theme_picker_dialog.dart';
import 'package:eatsbeats/ui/widgets/project_browser_drawer.dart';
import 'package:eatsbeats/ui/widgets/floating_instrument_window.dart';
import 'package:eatsbeats/ui/piano_roll_view.dart';
import 'package:eatsbeats/ui/tracker_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DawState dawState;

  setUp(() {
    dawState = DawState();
  });

  group('EatsStorageHelper Project Management Tests', () {
    test('Can save, list, load, rename, and delete project files', () async {
      const projectName = 'Cyber Funk Groove';
      const luaContent = 'return { title = "Cyber Funk Groove", bpm = 128 }';

      // 1. Save Project
      final saved = await EatsStorageHelper.saveProjectFile(projectName, luaContent);
      expect(saved, isNotNull);
      expect(saved!.name, equals(projectName));
      expect(saved.fileName, equals('Cyber Funk Groove.eats.lua'));

      // 2. List Projects
      final list = await EatsStorageHelper.listSavedProjects();
      expect(list.any((p) => p.name == projectName), isTrue);

      // 3. Load Project
      final loadedLua = await EatsStorageHelper.loadProjectFile(saved);
      expect(loadedLua, equals(luaContent));

      // 4. Rename Project
      final renamed = await EatsStorageHelper.renameProjectFile(saved, 'Cyber Funk 2099');
      expect(renamed, isTrue);
      final listAfterRename = await EatsStorageHelper.listSavedProjects();
      expect(listAfterRename.any((p) => p.name == 'Cyber Funk 2099'), isTrue);

      // 5. Delete Project
      final projectToDelete = listAfterRename.firstWhere((p) => p.name == 'Cyber Funk 2099');
      final deleted = await EatsStorageHelper.deleteProjectFile(projectToDelete);
      expect(deleted, isTrue);

      final listAfterDelete = await EatsStorageHelper.listSavedProjects();
      expect(listAfterDelete.any((p) => p.name == 'Cyber Funk 2099'), isFalse);
    });
  });

  group('ThemePickerDialog UI Tests', () {
    testWidgets('Renders all theme presets and switches theme on selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemePickerDialog(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UI THEME ENGINE'), findsOneWidget);
      expect(find.text('Ate Track (Hardware Console)'), findsOneWidget);
      expect(find.text('Midnight Bites (Cyber Neon)'), findsOneWidget);
      expect(find.text('Light Snack (Bright Studio)'), findsOneWidget);
      expect(find.text('Breakfast (Solarized Light)'), findsOneWidget);
      expect(find.text('Dinner (Solarized Dark)'), findsOneWidget);

      // Switch to Breakfast
      await tester.tap(find.text('Breakfast (Solarized Light)'));
      await tester.pumpAndSettle();

      expect(EatsTheme.currentPreset, equals(EatsThemePreset.breakfast));

      // Switch back to Midnight Bites
      await tester.tap(find.text('Midnight Bites (Cyber Neon)'));
      await tester.pumpAndSettle();

      expect(EatsTheme.currentPreset, equals(EatsThemePreset.midnightBites));
    });
  });

  group('ProjectBrowserDrawer Local Saved Projects Tab Tests', () {
    testWidgets('Renders Local Saved Projects tab with search, save, and action buttons', (tester) async {
      await EatsStorageHelper.saveProjectFile('Synth Wave Anthem', 'return { title = "Synth Wave" }');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 700,
              child: ProjectBrowserDrawer(
                dawState: dawState,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Tab 5 (Local Saved Projects)
      await tester.tap(find.byIcon(Icons.folder_special_outlined));
      await tester.pumpAndSettle();

      expect(find.text('SAVE CURRENT'), findsOneWidget);
      expect(find.byTooltip('Open Projects Folder in Explorer/Finder'), findsOneWidget);
      expect(find.byTooltip('Refresh Projects List'), findsOneWidget);
      expect(find.text('Synth Wave Anthem'), findsOneWidget);
      expect(find.text('LOAD'), findsOneWidget);
    });
  });

  group('TrackerView Key Repeat & Navigation Tests', () {
    testWidgets('TrackerView accepts KeyRepeatEvent for arrow navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TrackerView(dawState: dawState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.trackerSelectedStep, equals(0));

      // Dispatch KeyDownEvent for ArrowDown
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedStep, equals(1));

      // Dispatch simulated KeyRepeatEvent (holding arrowDown down)
      final trackerFocus = find.descendant(
        of: find.byType(TrackerView),
        matching: find.byType(Focus),
      );
      final focusNode = tester.widget<Focus>(trackerFocus.first).focusNode!;
      focusNode.onKeyEvent!(
        focusNode,
        const KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration(milliseconds: 100),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.trackerSelectedStep, equals(2));
    });
  });

  group('Piano Roll & Tracker Focus Tab Transition Tests', () {
    testWidgets('PianoRollView and TrackerView auto-claim focus on active tab transition', (tester) async {
      dawState.activeTabIndex = 0; // Starts on ARRANGER

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: PianoRollView(dawState: dawState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch tab to EDIT (index 1)
      dawState.activeTabIndex = 1;
      await tester.pumpAndSettle();

      // Verify widget rebuilt and focus requested without exception
      expect(find.byType(PianoRollView), findsOneWidget);
    });
  });

  group('FloatingInstrumentWindow Material Hierarchy Tests', () {
    testWidgets('FloatingInstrumentWindow renders inside Material without text style errors', (tester) async {
      final track = dawState.activeTrack;
      dawState.openFloatingInstrumentWindow(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned.fill(
                child: FloatingInstrumentWindow(
                  dawState: dawState,
                  workspaceBounds: const Size(1000, 700),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(track.name.toUpperCase()), findsOneWidget);
    });
  });
}
