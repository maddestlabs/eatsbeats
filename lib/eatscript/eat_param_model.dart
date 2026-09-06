import '../lua/lua_gui_model.dart';

/// Unified script parameter definition for Eatscript and legacy script engines.
class LuaParamDef {
  final String name;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final List<String> options;

  LuaParamDef({
    required this.name,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.step = 0.0,
    this.options = const [],
  });

  bool get isInteger =>
      step >= 1.0 ||
      options.isNotEmpty ||
      name.toLowerCase().contains('preset') ||
      name.toLowerCase().contains('bank') ||
      name.toLowerCase().contains('program') ||
      name.toLowerCase().contains('seed') ||
      name.toLowerCase().contains('algorithm') ||
      name.toLowerCase().contains('feedback') ||
      name.toLowerCase().contains('index');

  String getFormattedValue(double value) {
    if (options.isNotEmpty) {
      final idx = value.round().clamp(0, options.length - 1);
      return options[idx];
    }
    if (isInteger) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

/// Unified script compilation and parameter discovery result.
class LuaCompilationResult {
  final bool isSuccess;
  final String errorMessage;
  final int errorLine;
  final List<LuaParamDef> params;
  final String scriptType; // 'synth', 'drum', 'effect', or 'generator'
  final LuaGuiPanelDef? guiLayout;

  LuaCompilationResult({
    required this.isSuccess,
    this.errorMessage = '',
    this.errorLine = 0,
    required this.params,
    required this.scriptType,
    this.guiLayout,
  });
}

typedef EatParamDef = LuaParamDef;
typedef ScriptParamDef = LuaParamDef;
typedef ScriptCompilationResult = LuaCompilationResult;
