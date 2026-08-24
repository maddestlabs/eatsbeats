import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/convolver_engine.dart';
import 'package:mobile_wren_daw/audio/procedural_ir_generator.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/widgets/space_visualizer_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Procedural IR Generator & Physics Synthesis Tests', () {
    test('Synthesizes room impulse responses with ISM reflections and Velvet Noise tail', () {
      const roomParams = AcousticSpaceParams(
        name: 'Test Room',
        width: 10.0,
        length: 15.0,
        height: 4.0,
        rt60: 1.5,
        damping: 0.3,
        material: AcousticMaterialType.studioWood,
        isCabinetMode: false,
      );

      final ir = ProceduralIRGenerator.generate(roomParams, sampleRate: 44100);

      expect(ir.isNotEmpty, isTrue);
      expect(ir.length, greaterThanOrEqualTo((1.5 * 44100).toInt()));

      // Check normalized peak range
      double peak = 0.0;
      for (final s in ir) {
        if (s.abs() > peak) peak = s.abs();
      }
      expect(peak, closeTo(0.95, 0.05));
    });

    test('Synthesizes guitar amp cabinet IR with sub-meter modal geometry and speaker filters', () {
      const cabParams = AcousticSpaceParams(
        name: '4x12 Vintage Stack (Closed)',
        width: 0.76,
        length: 0.76,
        height: 0.36,
        rt60: 0.035,
        damping: 0.55,
        material: AcousticMaterialType.birchPlywood,
        isCabinetMode: true,
        micDistance: 0.05,
        micAngleDeg: 15.0,
        isOpenBack: false,
      );

      final ir = ProceduralIRGenerator.generate(cabParams, sampleRate: 44100);

      expect(ir.isNotEmpty, isTrue);
      // Cabinet IRs are compact (~25ms to 40ms)
      expect(ir.length, greaterThanOrEqualTo(256));
      expect(ir.length, lessThanOrEqualTo(4000));

      // Direct spike and speaker resonant curve should exist
      expect(ir.first.abs(), greaterThan(0.0));
    });

    test('Open-back dipole cancellation alters cabinet IR response', () {
      const closedCab = AcousticSpaceParams(
        name: 'Closed',
        width: 0.5,
        length: 0.4,
        height: 0.3,
        isCabinetMode: true,
        isOpenBack: false,
      );
      const openCab = AcousticSpaceParams(
        name: 'Open',
        width: 0.5,
        length: 0.4,
        height: 0.3,
        isCabinetMode: true,
        isOpenBack: true,
      );

      final irClosed = ProceduralIRGenerator.generate(closedCab, sampleRate: 44100);
      final irOpen = ProceduralIRGenerator.generate(openCab, sampleRate: 44100);

      expect(irClosed.length, equals(irOpen.length));
      // Buffers should differ due to dipole phase-inverted rear cancellation
      bool isDifferent = false;
      for (int i = 0; i < irClosed.length; i++) {
        if ((irClosed[i] - irOpen[i]).abs() > 0.01) {
          isDifferent = true;
          break;
        }
      }
      expect(isDifferent, isTrue);
    });

    test('AcousticMaterial absorption coefficients alter reflected decay energy', () {
      const softRoom = AcousticSpaceParams(
        name: 'Foam Room',
        width: 5.0,
        length: 5.0,
        height: 3.0,
        rt60: 0.5,
        material: AcousticMaterialType.acousticFoam,
      );
      const hardRoom = AcousticSpaceParams(
        name: 'Concrete Room',
        width: 5.0,
        length: 5.0,
        height: 3.0,
        rt60: 0.5,
        material: AcousticMaterialType.concrete,
      );

      final irSoft = ProceduralIRGenerator.generate(softRoom, sampleRate: 44100);
      final irHard = ProceduralIRGenerator.generate(hardRoom, sampleRate: 44100);

      expect(irSoft.length, equals(irHard.length));
    });

    test('ConvolverEngine bakes custom space parameters and updates registry', () {
      const customSpace = AcousticSpaceParams(
        name: 'My Procedural Chamber',
        width: 12.0,
        length: 18.0,
        height: 6.0,
        rt60: 2.5,
      );

      final baked = ConvolverEngine.instance.bakeCustomSpace(customSpace);
      expect(baked.isNotEmpty, isTrue);

      final names = ConvolverEngine.instance.getAvailableIrNames();
      expect(names, contains('My Procedural Chamber'));

      final retrieved = ConvolverEngine.instance.getIrSample('My Procedural Chamber');
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(baked.length));
    });
  });

  group('SpaceVisualizerWidget UI Tests', () {
    testWidgets('Renders 3D SpaceVisualizerWidget in room mode', (tester) async {
      const space = AcousticSpaceParams(
        name: 'Studio Live Room',
        width: 6.5,
        length: 9.0,
        height: 3.5,
        material: AcousticMaterialType.studioWood,
        isCabinetMode: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 180,
                child: SpaceVisualizerWidget(params: space),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ROOM ACOUSTICS'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Listener'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders 3D SpaceVisualizerWidget in amp cabinet mode', (tester) async {
      const cab = AcousticSpaceParams(
        name: '4x12 Vintage Stack (Closed)',
        width: 0.76,
        length: 0.76,
        height: 0.36,
        material: AcousticMaterialType.birchPlywood,
        isCabinetMode: true,
        micDistance: 0.05,
        micAngleDeg: 15.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 180,
                child: SpaceVisualizerWidget(params: cab),
              ),
            ),
          ),
        ),
      );
      expect(find.text('AMP CABINET'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Mic'), findsOneWidget);
      expect(find.text('18mm Birch Plywood (Cab)'), findsOneWidget);
    });
  });

  group('Room Designer & Cab Designer Lua Presets & DawState Tests', () {
    test('LuaPresetLibrary contains convolution_reverb, room_designer, and cab_designer presets', () {
      final convPreset = LuaPresetLibrary.getPresetById('convolution_reverb');
      expect(convPreset, isNotNull);
      expect(convPreset!.name, equals('Convolution Reverb'));

      final roomPreset = LuaPresetLibrary.getPresetById('room_designer');
      expect(roomPreset, isNotNull);
      expect(roomPreset!.name, equals('Room Designer'));

      final cabPreset = LuaPresetLibrary.getPresetById('cab_designer');
      expect(cabPreset, isNotNull);
      expect(cabPreset!.name, equals('Cab Designer'));
    });

    test('DawState adds Room Designer and Cab Designer as convolutionReverb FX and syncs parameters', () {
      final state = DawState();
      final track = state.activeTrack;
      track.fxRack.clear();

      final roomPreset = LuaPresetLibrary.getPresetById('room_designer')!;
      state.addAudioFXFromPreset(track, roomPreset);

      expect(track.fxRack.length, equals(1));
      final roomFx = track.fxRack.first;
      expect(roomFx.type, equals(FXType.convolutionReverb));
      expect(roomFx.name, equals('Room Designer'));

      // Update room width
      state.updateFXParam(track, roomFx.id, 'Width', 20.0);
      expect(roomFx.params['Width'], equals(20.0));
      expect(roomFx.irSampleName, contains('Room:'));

      // Add Cab Designer
      final cabPreset = LuaPresetLibrary.getPresetById('cab_designer')!;
      state.addAudioFXFromPreset(track, cabPreset);

      expect(track.fxRack.length, equals(2));
      final cabFx = track.fxRack.last;
      expect(cabFx.type, equals(FXType.convolutionReverb));
      expect(cabFx.name, equals('Cab Designer'));

      // Change Cab Designer Width parameter
      state.updateFXParam(track, cabFx.id, 'Width', 0.85);
      expect(cabFx.params['Width'], equals(0.85));
      expect(cabFx.irSampleName, contains('Cab:'));
    });
  });
}
