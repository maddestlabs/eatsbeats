import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/convolver_engine.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/utils/ir_pack_manager.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConvolverEngine & Modular FX Rack Tests', () {
    test('ConvolverEngine initializes synthetic impulse responses out-of-the-box', () {
      final names = ConvolverEngine.instance.getAvailableIrNames();
      expect(names, contains('Great Hall'));
      expect(names, contains('Plate Reverb'));
      expect(names, contains('Warm Room'));
      expect(names, contains('Spring Tank'));
    });

    test('ConvolverEngine processes convolution reverb on input PCM buffer', () {
      final input = [0.8, 0.4, 0.0, -0.4, -0.8];
      final output = ConvolverEngine.instance.processConvolver(input, 'Great Hall', 0.5);

      expect(output.length, equals(input.length));
      expect(output.first, isNot(equals(0.0)));
    });

    test('DawState supports dynamic FX insert rack management', () {
      final dawState = DawState();
      final track = dawState.activeTrack;

      final initialFxCount = track.fxRack.length;

      // Add Convolution Reverb
      dawState.addFXInsert(track, FXType.convolutionReverb);
      expect(track.fxRack.length, equals(initialFxCount + 1));
      final addedFx = track.fxRack.last;
      expect(addedFx.type, equals(FXType.convolutionReverb));

      // Update Dry/Wet Mix
      dawState.updateFXMix(track, addedFx.id, 0.75);
      expect(addedFx.mix, equals(0.75));

      // Reorder FX Inserts (move up and down)
      dawState.addFXInsert(track, FXType.distortion);
      dawState.addFXInsert(track, FXType.bitcrusher);
      final distFx = track.fxRack[track.fxRack.length - 2];
      final bitFx = track.fxRack.last;

      final bitIndex = track.fxRack.length - 1;
      dawState.moveFXUp(track, bitIndex);
      expect(track.fxRack[bitIndex - 1].id, equals(bitFx.id));

      dawState.moveFXDown(track, bitIndex - 1);
      expect(track.fxRack[bitIndex].id, equals(bitFx.id));

      // Remove FX Insert
      dawState.removeFXInsert(track, addedFx.id);
      dawState.removeFXInsert(track, distFx.id);
      dawState.removeFXInsert(track, bitFx.id);
      expect(track.fxRack.length, equals(initialFxCount));

      dawState.dispose();
    });

    test('ConvolverEngine stereo IR generation creates pristine stereo pairs with full room decay', () {
      final stereo = ConvolverEngine.instance.getIrStereoSample('Great Hall');
      expect(stereo, isNotNull);
      expect(stereo!.left.isNotEmpty, isTrue);
      expect(stereo.right.isNotEmpty, isTrue);
      expect(stereo.left.length, equals(stereo.right.length));
      // Full fidelity impulse response should be >= 10000 samples for a 1.6s room
      expect(stereo.left.length, greaterThan(10000));
    });

    test('AudioEngine getWaveformSamples and getSpectrumBands extract point-in-chain signal taps', () {
      final dawState = DawState();
      final track = dawState.activeTrack;
      dawState.addFXInsert(track, FXType.distortion);
      final fx = track.fxRack.last;

      final waveMaster = dawState.audioEngine.getWaveformSamples();
      final waveFx = dawState.audioEngine.getWaveformSamples(trackId: fx.id);
      final spectrumFx = dawState.audioEngine.getSpectrumBands(trackId: fx.id);

      expect(waveMaster.length, equals(64));
      expect(waveFx.length, equals(64));
      expect(spectrumFx.length, equals(16));

      dawState.dispose();
    });

    test('IrPackManager catalog contains designated Sadiquecat IR zip collection', () {
      final catalog = IrPackManager.instance.catalog;
      expect(catalog.isNotEmpty, isTrue);
      expect(catalog.first.id, equals('sadiquecat_ir_collection'));
      expect(catalog.first.zipUrl, equals('audio/ir/43771__sadiquecat__impulse-response.zip'));
    });

    test('Room Designer and Cab Designer presets initialize and bake authentic procedural impulse responses', () {
      final dawState = DawState();
      final track = dawState.activeTrack;

      final roomPreset = LuaPresetLibrary.getPresetById('room_designer')!;
      dawState.applyPreset(roomPreset, targetTrack: track);

      final roomFx = track.fxRack.last;
      expect(roomFx.type, equals(FXType.convolutionReverb));
      expect(roomFx.irSampleName, isNotNull);
      expect(roomFx.irSampleName!.startsWith('Room:'), isTrue);

      // Verify that changing RT60 rebakes the space
      dawState.updateFXParam(track, roomFx.id, 'RT60', 3.0);
      expect(roomFx.params['RT60'], equals(3.0));

      final cabPreset = LuaPresetLibrary.getPresetById('cab_designer')!;
      dawState.applyPreset(cabPreset, targetTrack: track);

      final cabFx = track.fxRack.last;
      expect(cabFx.type, equals(FXType.convolutionReverb));
      expect(cabFx.irSampleName, isNotNull);
      expect(cabFx.irSampleName!.startsWith('Cab:'), isTrue);

      dawState.dispose();
    });

    test('Eats Vinyl preset initializes, compiles hardware GUI, and handles Medium preset switching', () {
      final vintagePreset = LuaPresetLibrary.getPresetById('vintage_era_degrader');
      expect(vintagePreset, isNotNull);
      expect(vintagePreset!.name, equals('Eats Vinyl'));
      expect(vintagePreset.isAudioFx, isTrue);

      final dawState = DawState();
      final track = dawState.activeTrack;

      dawState.applyPreset(vintagePreset, targetTrack: track);
      final fx = track.fxRack.last;

      expect(fx.type, equals(FXType.vintageTape));
      expect(fx.name, equals('Eats Vinyl'));
      expect(fx.params['Era'], equals(1974.0));
      expect(fx.params['WowDepth'], equals(25.0));
      expect(fx.params['FlutterDepth'], equals(15.0));
      expect(fx.params['StutterDepth'], equals(35.0));
      expect(fx.params['TapeDropouts'], equals(15.0));

      // Test In-Place Parameter Modulation
      dawState.updateFXParam(track, fx.id, 'Era', 1982.0);
      expect(fx.params['Era'], equals(1982.0));

      // Test Medium Preset Selection: Tape 15 IPS (Studio Master - idx 0)
      dawState.updateFXParam(track, fx.id, 'Medium', 0.0);
      expect(fx.params['Era'], equals(1982.0));
      expect(fx.params['WowDepth'], equals(6.0));
      expect(fx.params['FlutterDepth'], equals(4.0));
      expect(fx.params['HissLevel'], equals(12.0));
      expect(fx.params['VinylCrackle'], equals(0.0));

      // Test Medium Preset Selection: Shellac 78 RPM (idx 3)
      dawState.updateFXParam(track, fx.id, 'Medium', 3.0);
      expect(fx.params['Era'], equals(1952.0));
      expect(fx.params['WowDepth'], equals(35.0));
      expect(fx.params['FlutterDepth'], equals(25.0));
      expect(fx.params['VinylCrackle'], equals(65.0));

      // Test JSON Serialization & Deserialization
      final jsonMap = fx.toJson();
      final revived = FXInsert.fromJson(jsonMap);
      expect(revived.type, equals(FXType.vintageTape));
      expect(revived.params['Era'], equals(1952.0));
      expect(revived.params['WowDepth'], equals(35.0));

      // Test Triggering Tape Stop
      dawState.triggerTapeStop(track.id, stopTime: 0.2, spinUpTime: 0.1);

      dawState.dispose();
    });
  });
}
