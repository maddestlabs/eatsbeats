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

    test('Convolution Reverb preset receives and updates authentic IR sample names', () {
      final dawState = DawState();
      final track = dawState.activeTrack;

      final convPreset = LuaPresetLibrary.getPresetById('convolution_reverb')!;
      dawState.applyPreset(convPreset, targetTrack: track);

      final fx = track.fxRack.last;
      expect(fx.type, equals(FXType.convolutionReverb));
      expect(fx.irSampleName, isNotNull);
      // Must NOT be a baked dummy room ('Conv: Track 1_...')
      expect(fx.irSampleName!.startsWith('Conv:'), isFalse);

      // Change IR Sample via updateFXIrSample
      dawState.updateFXIrSample(track, fx.id, 'Stone Cathedral');
      expect(fx.irSampleName, equals('Stone Cathedral'));

      // Update param IRSample
      dawState.updateFXParam(track, fx.id, 'IRSample', 2.0);
      expect(fx.irSampleName, isNotNull);
      expect(fx.irSampleName!.startsWith('Conv:'), isFalse);

      dawState.dispose();
    });
  });
}
