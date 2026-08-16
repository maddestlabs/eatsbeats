import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Script Parameter Engine Upgrades (Step & Choice)', () {
    test('LuaEngine compiles Param.add with 5th step argument', () {
      const code = '''
        Param.add("BankNum", 0, 128, 0, 1)
        Param.add("Cutoff", 20, 20000, 1000)

        function process(t, freq)
          return math.sin(t * freq)
        end
      ''';

      final res = LuaEngine.compile(code);
      expect(res.isSuccess, isTrue);
      expect(res.params.length, equals(2));

      final bankParam = res.params.firstWhere((p) => p.name == 'BankNum');
      expect(bankParam.step, equals(1.0));
      expect(bankParam.isInteger, isTrue);
      expect(bankParam.getFormattedValue(24.0), equals('24'));

      final cutoffParam = res.params.firstWhere((p) => p.name == 'Cutoff');
      expect(cutoffParam.step, equals(0.0));
      expect(cutoffParam.getFormattedValue(1000.4), equals('1000.4'));
    });

    test('LuaEngine compiles Param.choice with string options list', () {
      const code = '''
        Param.choice("InstrumentStyle", {"Clean Piano", "Acoustic Guitar", "Lead Synth"}, 1)

        function process(t, freq)
          return math.sin(t * freq)
        end
      ''';

      final res = LuaEngine.compile(code);
      expect(res.isSuccess, isTrue);
      expect(res.params.length, equals(1));

      final choiceParam = res.params.first;
      expect(choiceParam.name, equals('InstrumentStyle'));
      expect(choiceParam.min, equals(0.0));
      expect(choiceParam.max, equals(2.0));
      expect(choiceParam.defaultValue, equals(1.0));
      expect(choiceParam.options.length, equals(3));
      expect(choiceParam.isInteger, isTrue);

      expect(choiceParam.getFormattedValue(0.0), equals('Clean Piano'));
      expect(choiceParam.getFormattedValue(1.0), equals('Acoustic Guitar'));
      expect(choiceParam.getFormattedValue(2.0), equals('Lead Synth'));
    });
  });
}
