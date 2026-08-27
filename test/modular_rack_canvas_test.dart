import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/lua_workbench_view.dart';
import 'package:eatsbeats/ui/modular/modular_theme.dart';
import 'package:eatsbeats/ui/modular/modular_faceplate_widget.dart';
import 'package:eatsbeats/ui/modular/modular_jack_widget.dart';
import 'package:eatsbeats/ui/modular/modular_rack_canvas.dart';
import 'package:eatsbeats/ui/modular/modular_module_search_dialog.dart';
import 'package:eatsbeats/ui/modular/modular_rack_dsl.dart';
import 'package:eatsbeats/ui/modular/patch_cable_painter.dart';
import 'package:eatsbeats/ui/widgets/floating_instrument_window.dart';
import 'package:eatsbeats/models/script_target_model.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VCV Rack-Style Modular Canvas & Subpixel Cable Tests', () {
    test('computeJackCenter calculates mathematically exact subpixel coordinates without vertical offset error', () {
      // Row 1, Module 0 (HP=11), Jack 0 of 2
      final p1 = ModularRackCanvas.computeJackCenter(
        row: 1,
        previousHpList: [],
        currentHp: 11,
        jackIndex: 0,
        totalJacks: 2,
      );
      // Fixed Jack Y for row 1 = 18px (rail) + 148px = 166.0px
      expect(p1.dy, 166.0);
      expect(p1.dx, greaterThan(40.0));
      expect(p1.dx, lessThan(60.0));

      // Row 2, Module 0 (HP=15), Jack 0 of 2
      final p2 = ModularRackCanvas.computeJackCenter(
        row: 2,
        previousHpList: [],
        currentHp: 15,
        jackIndex: 0,
        totalJacks: 2,
      );
      // Row 2 TierTop = 211.0px -> Jack Y = 211 + 18 + 148 = 377.0px
      expect(p2.dy, 377.0);
    });

    testWidgets('PatchCablePainter paints gravity-droop cables without error', (tester) async {
      const cables = [
        ModularPatchCable(
          from: Offset(10, 20),
          to: Offset(100, 150),
          color: ModularTheme.cableAudio,
          tension: 0.5,
        ),
        ModularPatchCable(
          from: Offset(30, 40),
          to: Offset(80, 200),
          color: ModularTheme.cablePitchCv,
          tension: 0.7,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: PatchCablePainter(cables: cables, opacity: 0.9),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ModularJackWidget renders fixed 48px slot and responds to tap & drag', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModularJackWidget(
              label: '1V/Oct',
              type: JackType.input,
              signalType: JackSignalType.pitchCv,
              isConnected: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('1V/OCT'), findsOneWidget);
      await tester.tap(find.byType(ModularJackWidget));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('ModularRackCanvas renders InteractiveViewer with + ADD ROW and + ADD MODULE buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'modular_edit_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Verify InteractiveViewer is present for 2D panning and zooming
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Verify + ADD ROW button exists
      expect(find.text('+ ADD RACK ROW (EXPAND MODULAR CASE)'), findsOneWidget);

      // Verify + ADD MODULE blank plates exist
      expect(find.text('+ ADD'), findsWidgets);

      // Tap + ADD RACK ROW
      await tester.tap(find.text('+ ADD RACK ROW (EXPAND MODULAR CASE)'));
      await tester.pumpAndSettle();

      // Now Row 3 should be added
      expect(find.textContaining('ROW 3:'), findsOneWidget);
    });

    testWidgets('Tapping connected jack opens context menu for disconnecting or cycling color', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'modular_connect_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Find Saw Out jack (which is connected by default in Acid 303)
      final sawOutFinder = find.text('SAW OUT');
      expect(sawOutFinder, findsOneWidget);

      // Tap the connected jack
      await tester.tap(sawOutFinder);
      await tester.pumpAndSettle();

      // Verify Jack context menu opens
      expect(find.text('Cycle Cable Color'), findsOneWidget);
      expect(find.text('Disconnect Patch Cable'), findsOneWidget);

      // Tap Disconnect Patch Cable
      await tester.tap(find.text('Disconnect Patch Cable'));
      await tester.pumpAndSettle();

      // Menu closes
      expect(find.text('Disconnect Patch Cable'), findsNothing);
    });

    testWidgets('Dragging from a jack tracks movement in all 2D directions and snaps near targets', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'drag_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      final jackFinder = find.text('1V/OCT');
      expect(jackFinder, findsOneWidget);

      // Drag in any 2D direction (e.g. up, left, right, down)
      final gesture = await tester.startGesture(tester.getCenter(jackFinder));
      await gesture.moveBy(const Offset(50, -30));
      await tester.pump();
      await gesture.moveBy(const Offset(-20, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(ModularRackCanvas), findsOneWidget);
    });

    testWidgets('LuaWorkbenchView (Design Studio) switches modes: CODE, MODULAR, SPLIT, GUI', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'design_303',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );
      dawState.activePattern.tracks.add(track);
      dawState.activeTrackIndex = dawState.activePattern.tracks.indexOf(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 900,
              child: LuaWorkbenchView(
                dawState: dawState,
              ),
            ),
          ),
        ),
      );

      // Default is CODE mode
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('MODULAR'), findsOneWidget);
      expect(find.text('SPLIT'), findsOneWidget);
      expect(find.text('GUI'), findsOneWidget);

      // Switch to MODULAR mode
      await tester.tap(find.text('MODULAR'));
      await tester.pumpAndSettle();

      expect(find.textContaining('MODULAR RACK:'), findsOneWidget);
      expect(find.text('303 VCO'), findsOneWidget);

      // Switch to SPLIT mode
      await tester.tap(find.text('SPLIT'));
      await tester.pumpAndSettle();

      expect(find.textContaining('MODULAR RACK:'), findsOneWidget);
      expect(find.text('303 VCO'), findsOneWidget);

      // Switch to GUI preview mode
      await tester.tap(find.text('GUI'));
      await tester.pumpAndSettle();

      expect(find.byType(LuaWorkbenchView), findsOneWidget);
    });

    testWidgets('+ ADD MODULE opens ModularModuleSearchDialog with search and category filters', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'search_module_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Find first + ADD MODULE blank plate
      final addBlankPlate = find.text('+ ADD').first;
      expect(addBlankPlate, findsWidgets);

      await tester.tap(addBlankPlate);
      await tester.pumpAndSettle();

      // Verify ModularModuleSearchDialog opened
      expect(find.byType(ModularModuleSearchDialog), findsOneWidget);
      expect(find.text('ADD MODULE TO ROW 1'), findsOneWidget);
      expect(find.text('VCO (OSC)'), findsOneWidget);
      expect(find.text('SCRIPT DSP'), findsOneWidget);

      // Filter by SCRIPT DSP category
      await tester.ensureVisible(find.text('SCRIPT DSP'));
      await tester.tap(find.text('SCRIPT DSP'));
      await tester.pumpAndSettle();

      expect(find.text('CUSTOM LUA DSP'), findsOneWidget);
      expect(find.text('MIDI LUA TRANSFORM'), findsOneWidget);

      // Search by text "tape delay"
      await tester.ensureVisible(find.text('ALL'));
      await tester.tap(find.text('ALL'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'tape');
      await tester.pumpAndSettle();

      expect(find.text('TAPE DELAY FX'), findsOneWidget);

      // Select TAPE DELAY FX
      await tester.ensureVisible(find.text('TAPE DELAY FX'));
      await tester.tap(find.text('TAPE DELAY FX'));
      await tester.pumpAndSettle();

      // Dialog closed and module inserted
      expect(find.byType(ModularModuleSearchDialog), findsNothing);
      expect(find.text('TAPE DELAY FX'), findsOneWidget);
    });

    testWidgets('Custom or generic Lua script tracks render programmable LUA SCRIPT DSP CORE', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'custom_dsp_track',
        name: 'Custom Math Synth',
        type: TrackType.luaScript,
        color: const Color(0xFF00E5FF),
        luaScriptCode: '-- @name: Custom Math Synth\nfunction process(s) return s end',
        luaParams: {
          'Harmonics': 0.75,
          'Feedback': 0.42,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Verify LUA SCRIPT DSP CORE faceplate renders
      expect(find.text('LUA SCRIPT DSP CORE'), findsOneWidget);
      expect(find.text('CUSTOM MATH SYNTH'), findsOneWidget);
      expect(find.text('DSP ACTIVE'), findsOneWidget);
      expect(find.text('2 PARAMS'), findsOneWidget);
      expect(find.text('HARMONI'), findsOneWidget);
      expect(find.text('FEEDBAC'), findsOneWidget);
    });

    testWidgets('Script modules render DSP ACTIVE badge and tapping EDIT opens script inspector', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'script_edit_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Tap + ADD to open module library
      await tester.tap(find.text('+ ADD').first);
      await tester.pumpAndSettle();

      // Filter by SCRIPT
      await tester.ensureVisible(find.text('SCRIPT DSP'));
      await tester.tap(find.text('SCRIPT DSP'));
      await tester.pumpAndSettle();

      // Add CUSTOM LUA DSP
      await tester.ensureVisible(find.text('CUSTOM LUA DSP'));
      await tester.tap(find.text('CUSTOM LUA DSP'));
      await tester.pumpAndSettle();

      // Module is rendered in rack
      expect(find.text('CUSTOM LUA DSP'), findsOneWidget);

      // Tap EDIT on the module's DSP ACTIVE banner
      final editBtn = find.text('EDIT');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Script code modal opens
      expect(find.text('SCRIPT: CUSTOM LUA DSP'), findsOneWidget);
      expect(find.textContaining('function process(sample, cv1, cv2)'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();

      expect(find.text('SCRIPT: CUSTOM LUA DSP'), findsNothing);
    });

    test('ModularRackDsl parses and serializes declarative Lua rack tables', () {
      const sampleLua = '''
-- @name: SynthLab
local SynthLab = {}

function SynthLab.init()
  Param.add("Cutoff", 20.0, 20000.0, 1000.0)
end

function SynthLab.rack()
  return {
    rows = {
      {
        { id = "osc1", title = "ANALOG VCO", hp = 12, row = 1, category = "VCO" },
        { id = "vcf1", title = "LADDER VCF", hp = 10, row = 1, category = "VCF" },
      }
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
    }
  }
end

return SynthLab
''';

      final parsed = ModularRackDsl.parse(sampleLua);
      expect(parsed, isNotNull);
      expect(parsed!.totalRows, greaterThanOrEqualTo(1));
      expect(parsed.modulesByRow[1]?.length, 2);
      expect(parsed.modulesByRow[1]?[0].title, 'ANALOG VCO');
      expect(parsed.modulesByRow[1]?[1].title, 'LADDER VCF');
      expect(parsed.cables.length, 1);
      expect(parsed.cables[0].fromKey.serializedKey, '1:0:1');
      expect(parsed.cables[0].toKey.serializedKey, '1:1:0');

      // Test serialization
      final serialized = ModularRackDsl.serialize(
        totalRows: 2,
        customModulesByRow: {
          1: [
            const DynamicModuleDefinition(id: 'osc1', title: 'ANALOG VCO', hpWidth: 12, category: 'VCO'),
          ]
        },
        cables: [
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 0, label: 'In'),
            color: ModularTheme.cableAudio,
          )
        ],
        existingScriptCode: sampleLua,
        instrumentName: 'SynthLab',
      );

      expect(serialized, contains('function SynthLab.rack()'));
      expect(serialized, contains('ANALOG VCO'));
      expect(serialized, contains('from = "1:0:1", to = "1:1:0"'));
      expect(serialized, contains('return SynthLab'));
    });

    test('ModularRackDsl generates default topologies for legacy presets without breaking them', () {
      final kickRack = ModularRackDsl.generateDefault('fm_acoustic_kick');
      expect(kickRack.cables.length, greaterThanOrEqualTo(4));

      final tb303Rack = ModularRackDsl.generateDefault('acid_303');
      expect(tb303Rack.cables.length, greaterThanOrEqualTo(3));

      final genericRack = ModularRackDsl.generateDefault('generic');
      expect(genericRack.cables.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Adding a module visually on ModularRackCanvas automatically serializes rack() into track.luaScriptCode', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'bidirectional_track',
        name: 'Super Synth',
        type: TrackType.luaScript,
        color: const Color(0xFF00E5FF),
        luaScriptCode: '-- @name: Super Synth\nlocal SuperSynth = {}\n\nfunction SuperSynth.init()\n  Param.add("Gain", 0, 1, 0.8)\nend\n\nreturn SuperSynth\n',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Verify Lua Sync toolbar chip renders
      expect(find.text('LUA SYNC: OK'), findsOneWidget);

      // Add a module via + ADD MODULE
      await tester.tap(find.text('+ ADD').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'tape');
      await tester.pumpAndSettle();

      expect(find.text('TAPE DELAY FX'), findsOneWidget);
      await tester.tap(find.text('TAPE DELAY FX'));
      await tester.pumpAndSettle();

      // Verify track.luaScriptCode now contains serialized function SuperSynth.rack()
      expect(track.luaScriptCode, contains('function SuperSynth.rack()'));
      expect(track.luaScriptCode, contains('TAPE DELAY FX'));
      expect(track.luaScriptCode, contains('return SuperSynth'));
    });

    testWidgets('Clicking Code icon on FloatingInstrumentWindow navigates directly to that specific track script', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track2 = dawState.activePattern.tracks[1]; // Track 2
      dawState.openFloatingInstrumentWindow(track2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: FloatingInstrumentWindow(
                dawState: dawState,
              ),
            ),
          ),
        ),
      );

      // Tap Code icon button
      final codeBtn = find.byIcon(Icons.code);
      expect(codeBtn, findsOneWidget);
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();

      // Verify activeTabIndex is switched to 4 (SCRIPTS) and activeScriptTarget points to Track 2
      expect(dawState.activeTabIndex, 4);
      expect(dawState.activeScriptTarget.trackId, track2.id);
    });

    test('DawState.getScriptCodeForTarget retrieves full populated Lua code for all targets', () {
      final dawState = DawState();
      final allTargets = dawState.getAllScriptTargets();

      expect(allTargets.length, greaterThanOrEqualTo(dawState.activePattern.tracks.length));

      for (final target in allTargets) {
        final code = dawState.getScriptCodeForTarget(target);
        expect(code, isNotEmpty, reason: 'Target ${target.title} should have non-empty Lua code');
        if (target.type == ScriptTargetType.trackDsp) {
          expect(code, contains('.rack()'), reason: 'Target ${target.title} should contain .rack() block');
        }
      }
    });

    test('ModularRackDsl.ensureRackBlock automatically injects .rack() block into scripts without one', () {
      const legacyCode = '''-- @name: Simple Synth
local SimpleSynth = {}

function SimpleSynth.init()
  Param.add("Cutoff", 100, 10000, 2000)
end

function SimpleSynth.gui()
  return {}
end

return SimpleSynth
''';

      final codeWithRack = ModularRackDsl.ensureRackBlock(legacyCode, trackName: 'Simple Synth');
      expect(codeWithRack, contains('function SimpleSynth.rack()'));
      expect(codeWithRack, contains('rows = {'));
      expect(codeWithRack, contains('cables = {'));
      expect(codeWithRack, contains('return SimpleSynth'));
    });

    test('SNES Synth and SNES Sfxr contain complete modular Lua DSP and rack definitions', () {
      final snesSynth = LuaPresetLibrary.getPresetById('snes_console_synth');
      expect(snesSynth, isNotNull);
      expect(snesSynth!.code, contains('function SNESConsole.wavetable('));
      expect(snesSynth.code, contains('function SNESConsole.adsr('));
      expect(snesSynth.code, contains('function SNESConsole.echo('));
      expect(snesSynth.code, contains('function SNESConsole.process('));
      expect(snesSynth.code, contains('function SNESConsole.rack('));

      final snesSfx = LuaPresetLibrary.getPresetById('eats_sfxr');
      expect(snesSfx, isNotNull);
      expect(snesSfx!.code, contains('function SNESSFX.oscillator('));
      expect(snesSfx.code, contains('function SNESSFX.envelope('));
      expect(snesSfx.code, contains('function SNESSFX.echo('));
      expect(snesSfx.code, contains('function SNESSFX.process('));
      expect(snesSfx.code, contains('function SNESSFX.rack('));
    });
  });
}
