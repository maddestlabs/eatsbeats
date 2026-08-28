import 'package:flutter/material.dart';
import '../../lua/lua_engine.dart';
import '../../lua/lua_script_library.dart';
import '../../lua/project_script_engine.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';

class ProjectScriptRunnerDialog extends StatefulWidget {
  final DawState dawState;
  final LuaScriptDef script;

  const ProjectScriptRunnerDialog({
    super.key,
    required this.dawState,
    required this.script,
  });

  static Future<ProjectScriptResult?> show(
    BuildContext context, {
    required DawState dawState,
    required LuaScriptDef script,
  }) {
    return showDialog<ProjectScriptResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProjectScriptRunnerDialog(
        dawState: dawState,
        script: script,
      ),
    );
  }

  @override
  State<ProjectScriptRunnerDialog> createState() => _ProjectScriptRunnerDialogState();
}

class _ProjectScriptRunnerDialogState extends State<ProjectScriptRunnerDialog> {
  late final List<LuaParamDef> _paramDefs;
  final Map<String, dynamic> _paramValues = {};
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    final compResult = LuaEngine.compile(widget.script.code);
    _paramDefs = compResult.params;
    for (final p in _paramDefs) {
      _paramValues[p.name] = p.defaultValue;
    }
  }

  void _runScript() {
    setState(() => _isExecuting = true);

    final result = widget.dawState.runProjectScript(
      widget.script,
      params: _paramValues,
    );

    setState(() => _isExecuting = false);

    Navigator.of(context).pop(result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.isSuccess ? const Color(0xFF00FF66) : const Color(0xFFFF3333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(
              result.isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.black,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.message,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF141923),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBD00FF).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBD00FF).withValues(alpha: 0.25),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF263043))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBD00FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFFBD00FF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.script.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.script.description,
                          style: const TextStyle(
                            color: Color(0xFF8E9BAE),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8E9BAE), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Parameters Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_paramDefs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2638),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF21F4E8), size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This script executes directly against the project without requiring additional parameters.',
                                style: TextStyle(color: Color(0xFFCFD6E4), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._paramDefs.map((param) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildParamControl(param),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Footer / Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF263043))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: Color(0xFF8E9BAE), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBD00FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isExecuting ? null : _runScript,
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      _isExecuting ? 'RUNNING...' : 'EXECUTE ON PROJECT',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamControl(LuaParamDef param) {
    if (param.options.isNotEmpty) {
      final currentVal = (_paramValues[param.name] ?? param.defaultValue).toDouble();
      final currentIdx = currentVal.round().clamp(0, param.options.length - 1);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                param.name.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF21F4E8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                param.options[currentIdx],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2638),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF33425B)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: currentIdx,
                dropdownColor: const Color(0xFF1E2638),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF21F4E8)),
                items: List.generate(param.options.length, (i) {
                  return DropdownMenuItem<int>(
                    value: i,
                    child: Text(param.options[i]),
                  );
                }),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _paramValues[param.name] = val.toDouble());
                  }
                },
              ),
            ),
          ),
        ],
      );
    }

    final double val = (_paramValues[param.name] ?? param.defaultValue).toDouble();
    final displayStr = param.getFormattedValue(val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              param.name.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF21F4E8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              displayStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFBD00FF),
            inactiveTrackColor: const Color(0xFF1E2638),
            thumbColor: const Color(0xFF21F4E8),
            overlayColor: const Color(0xFF21F4E8).withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: val.clamp(param.min, param.max),
            min: param.min,
            max: param.max,
            divisions: param.step > 0 ? ((param.max - param.min) / param.step).round() : null,
            onChanged: (newVal) {
              setState(() => _paramValues[param.name] = newVal);
            },
          ),
        ),
      ],
    );
  }
}
