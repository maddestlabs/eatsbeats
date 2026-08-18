import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/convolver_engine.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/utils/ir_pack_manager.dart';

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

      // Remove FX Insert
      dawState.removeFXInsert(track, addedFx.id);
      expect(track.fxRack.length, equals(initialFxCount));

      dawState.dispose();
    });

    test('IrPackManager catalog contains designated Sadiquecat IR zip collection', () {
      final catalog = IrPackManager.instance.catalog;
      expect(catalog.isNotEmpty, isTrue);
      expect(catalog.first.id, equals('sadiquecat_ir_collection'));
      expect(catalog.first.zipUrl, equals('audio/ir/43771__sadiquecat__impulse-response.zip'));
    });
  });
}
