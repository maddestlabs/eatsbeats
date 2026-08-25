import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../models/script_target_model.dart';
import '../theme/eats_theme.dart';
import '../lua/lua_engine.dart';
import '../lua/lua_preset_library.dart';
import 'modular/eurorack_theme.dart';
import 'modular/modular_rack_canvas.dart';
import 'widgets/dynamic_instrument_gui_widget.dart';
import 'widgets/eatsbeats_slider.dart';
import 'widgets/skeuomorphic_hardware_button.dart';
import 'widgets/waveform_painter.dart';

enum DesignStudioViewMode {
  code,
  modularRack,
  split,
  guiPreview,
}

class LuaWorkbenchView extends StatefulWidget {
  final DawState dawState;

  const LuaWorkbenchView({super.key, required this.dawState});

  @override
  State<LuaWorkbenchView> createState() => _LuaWorkbenchViewState();
}

class _LuaWorkbenchViewState extends State<LuaWorkbenchView> {
  late TextEditingController _codeController;
  late FocusNode _editorFocusNode;
  late ScrollController _editorScrollController;
  late ScrollController _gutterScrollController;
  late String _lastTargetId;
  bool _isExplorerOpen = true;
  String _scriptFilterQuery = '';
  DesignStudioViewMode _viewMode = DesignStudioViewMode.code;

  @override
  void initState() {
    super.initState();
    final activeTarget = widget.dawState.activeScriptTarget;
    _lastTargetId = activeTarget.id;
    _codeController = TextEditingController(text: widget.dawState.getScriptCodeForTarget(activeTarget));
    _codeController.addListener(_onCodeChanged);
    _editorFocusNode = FocusNode(debugLabel: 'LuaWorkbenchEditor');

    _editorScrollController = ScrollController();
    _gutterScrollController = ScrollController();

    _editorScrollController.addListener(() {
      if (_gutterScrollController.hasClients &&
          _gutterScrollController.offset != _editorScrollController.offset) {
        _gutterScrollController.jumpTo(_editorScrollController.offset);
      }
    });
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _gutterScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LuaWorkbenchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeTarget = widget.dawState.activeScriptTarget;
    if (activeTarget.id != _lastTargetId) {
      _lastTargetId = activeTarget.id;
      _codeController.text = widget.dawState.getScriptCodeForTarget(activeTarget);
    }
  }

  void _compileCurrentScript() {
    final activeTarget = widget.dawState.activeScriptTarget;
    widget.dawState.compileScriptTarget(activeTarget, _codeController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.dawState.compilationResult.isSuccess
              ? 'Compiled & hot-swapped ${activeTarget.title} (Snapshot saved in History)'
              : 'Compilation failed: ${widget.dawState.compilationResult.errorMessage}',
        ),
        backgroundColor: widget.dawState.compilationResult.isSuccess ? const Color(0xFF1B281F) : const Color(0xFF331416),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _loadTemplate(String code, String name) {
    final activeTarget = widget.dawState.activeScriptTarget;
    setState(() {
      _codeController.text = code;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded template "$name" for ${activeTarget.title}. Press COMPILE & RUN to apply.'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTarget = widget.dawState.activeScriptTarget;
    final allTargets = widget.dawState.getAllScriptTargets();
    final activeTrack = widget.dawState.activeTrack;
    final result = widget.dawState.compilationResult;
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final isMobile = MediaQuery.of(context).size.width < 750;

    // Sync controller if external load or target switch occurred
    if (_lastTargetId != activeTarget.id) {
      _lastTargetId = activeTarget.id;
      final targetCode = widget.dawState.getScriptCodeForTarget(activeTarget);
      if (_codeController.text != targetCode) {
        _codeController.text = targetCode;
      }
    }

    final targetBadgeBg = activeTarget.type == ScriptTargetType.trackDsp
        ? EatsTheme.primaryCyan
        : (activeTarget.type == ScriptTargetType.midiFx ? EatsTheme.accentGold : EatsTheme.secondaryMagenta);

    final currentTargetParams = widget.dawState.getScriptParamsForTarget(activeTarget);
    final lines = _codeController.text.split('\n');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _compileCurrentScript,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _compileCurrentScript,
      },
      child: Column(
          children: [
            // Top Toolbar: Explorer Toggle, Target Selector, Mode Switcher, Compile Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: EatsTheme.panelHeader,
              child: Row(
                children: [
                  // Explorer Sidebar Toggle Button
                  IconButton(
                    icon: Icon(
                      _isExplorerOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                      color: _isExplorerOpen ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                      size: 20,
                    ),
                    tooltip: _isExplorerOpen ? 'Hide Script Explorer' : 'Show Script Explorer',
                    onPressed: () => setState(() => _isExplorerOpen = !_isExplorerOpen),
                  ),

                  const SizedBox(width: 4),

                  // Active Target Badge & Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: targetBadgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activeTarget.typeBadge,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: EatsTheme.controlBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: targetBadgeBg.withOpacity(0.5)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ScriptTarget>(
                          isExpanded: true,
                          value: allTargets.where((t) => t.id == activeTarget.id).firstOrNull ?? (allTargets.isNotEmpty ? allTargets.first : null),
                          dropdownColor: EatsTheme.panelBackground,
                          icon: Icon(Icons.arrow_drop_down, color: targetBadgeBg),
                          items: allTargets.map((target) {
                            final badgeColor = target.type == ScriptTargetType.trackDsp
                                ? EatsTheme.primaryCyan
                                : (target.type == ScriptTargetType.midiFx
                                    ? EatsTheme.accentGold
                                    : (target.type == ScriptTargetType.audioFx
                                        ? EatsTheme.secondaryMagenta
                                        : EatsTheme.accentGreen));

                            return DropdownMenuItem<ScriptTarget>(
                              value: target,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: target.trackColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: badgeColor, width: 0.5),
                                    ),
                                    child: Text(
                                      target.typeBadge,
                                      style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      target.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: EatsTheme.getPrimaryFontStyle(
                                        color: target.id == activeTarget.id ? EatsTheme.textPrimary : EatsTheme.textSecondary,
                                        fontWeight: target.id == activeTarget.id ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newTarget) {
                            if (newTarget != null) {
                              setState(() {
                                widget.dawState.selectScriptTarget(newTarget);
                                _codeController.text = widget.dawState.getScriptCodeForTarget(newTarget);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // View Mode Switcher Buttons: [CODE] [MODULAR] [SPLIT] [GUI]
                  SkeuomorphicHardwareButton(
                    label: isMobile ? null : 'CODE',
                    icon: Icons.code,
                    isActive: _viewMode == DesignStudioViewMode.code,
                    activeColor: EatsTheme.primaryCyan,
                    onTap: () => setState(() => _viewMode = DesignStudioViewMode.code),
                    height: 32,
                  ),
                  const SizedBox(width: 4),
                  SkeuomorphicHardwareButton(
                    label: isMobile ? null : 'MODULAR',
                    icon: Icons.cable,
                    isActive: _viewMode == DesignStudioViewMode.modularRack,
                    activeColor: EurorackTheme.cableAudio,
                    onTap: () => setState(() => _viewMode = DesignStudioViewMode.modularRack),
                    height: 32,
                  ),
                  const SizedBox(width: 4),
                  if (!isMobile) ...[
                    SkeuomorphicHardwareButton(
                      label: 'SPLIT',
                      icon: Icons.vertical_split,
                      isActive: _viewMode == DesignStudioViewMode.split,
                      activeColor: EatsTheme.accentGold,
                      onTap: () => setState(() => _viewMode = DesignStudioViewMode.split),
                      height: 32,
                    ),
                    const SizedBox(width: 4),
                  ],
                  SkeuomorphicHardwareButton(
                    label: isMobile ? null : 'GUI',
                    icon: Icons.dashboard,
                    isActive: _viewMode == DesignStudioViewMode.guiPreview,
                    activeColor: EatsTheme.secondaryMagenta,
                    onTap: () => setState(() => _viewMode = DesignStudioViewMode.guiPreview),
                    height: 32,
                  ),

                  const SizedBox(width: 8),

                  // Compile & Run Button
                  SkeuomorphicHardwareButton(
                    label: isMobile ? 'COMPILE' : 'COMPILE & RUN',
                    icon: Icons.play_arrow,
                    isActive: true,
                    activeColor: EatsTheme.accentGreen,
                    onTap: _compileCurrentScript,
                    height: 34,
                  ),
                ],
              ),
            ),

            // Main Studio Body: Depending on _viewMode
            Expanded(
              child: _buildStudioBody(
                allTargets: allTargets,
                activeTarget: activeTarget,
                activeTrack: activeTrack,
                currentTargetParams: currentTargetParams,
                lines: lines,
                result: result,
                isGrungy: isGrungy,
                targetBadgeBg: targetBadgeBg,
                isMobile: isMobile,
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildStudioBody({
    required List<ScriptTarget> allTargets,
    required ScriptTarget activeTarget,
    required TrackChannel activeTrack,
    required Map<String, double> currentTargetParams,
    required List<String> lines,
    required LuaCompilationResult result,
    required bool isGrungy,
    required Color targetBadgeBg,
    required bool isMobile,
  }) {
    switch (_viewMode) {
      case DesignStudioViewMode.modularRack:
        return ModularRackCanvas(
          dawState: widget.dawState,
          track: activeTrack,
        );

      case DesignStudioViewMode.guiPreview:
        return Container(
          color: EatsTheme.panelBackground,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: DynamicInstrumentGuiWidget(
              dawState: widget.dawState,
              track: activeTrack,
            ),
          ),
        );

      case DesignStudioViewMode.split:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isExplorerOpen)
              Container(
                width: 210,
                decoration: BoxDecoration(
                  color: EatsTheme.panelBackground,
                  border: const Border(right: BorderSide(color: Color(0xFF2B3245), width: 1.2)),
                ),
                child: _buildScriptExplorer(allTargets, activeTarget),
              ),
            Expanded(
              flex: 5,
              child: _buildCodeEditorCanvas(
                activeTarget: activeTarget,
                currentTargetParams: currentTargetParams,
                lines: lines,
                result: result,
                isGrungy: isGrungy,
                targetBadgeBg: targetBadgeBg,
              ),
            ),
            Container(width: 2, color: const Color(0xFF2B3245)),
            Expanded(
              flex: 6,
              child: ModularRackCanvas(
                dawState: widget.dawState,
                track: activeTrack,
              ),
            ),
          ],
        );

      case DesignStudioViewMode.code:
      default:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isExplorerOpen)
              Container(
                width: isMobile ? 220 : 250,
                decoration: BoxDecoration(
                  color: EatsTheme.panelBackground,
                  border: const Border(right: BorderSide(color: Color(0xFF2B3245), width: 1.2)),
                ),
                child: _buildScriptExplorer(allTargets, activeTarget),
              ),
            Expanded(
              child: _buildCodeEditorCanvas(
                activeTarget: activeTarget,
                currentTargetParams: currentTargetParams,
                lines: lines,
                result: result,
                isGrungy: isGrungy,
                targetBadgeBg: targetBadgeBg,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildCodeEditorCanvas({
    required ScriptTarget activeTarget,
    required Map<String, double> currentTargetParams,
    required List<String> lines,
    required LuaCompilationResult result,
    required bool isGrungy,
    required Color targetBadgeBg,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Real-time Audio Oscilloscope LCD Display
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF0D130E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2A3628), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0xB3000000), offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WaveformPainter(timeData: widget.dawState.audioEngine.waveformTimeData),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 8,
                    child: Text(
                      'OSCILLOSCOPE [AUDIO OUT]',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: const Color(0xFF98B890).withOpacity(0.85),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _LcdOscilloscopeGlassReflectionPainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Code Editor Box: Fixed ~20 visible lines with synchronized scrolling
          DragTarget<LuaPreset>(
            onAcceptWithDetails: (details) {
              final preset = details.data;
              setState(() {
                _codeController.text = preset.code;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Loaded preset "${preset.name}" into editor for ${activeTarget.title}. Press COMPILE & RUN to apply.'),
                  backgroundColor: EatsTheme.panelHeader,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;

              return Container(
                decoration: BoxDecoration(
                  color: EatsTheme.codeEditorBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHovering ? EatsTheme.primaryCyan : EatsTheme.codeEditorBorder,
                    width: isHovering ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Editor Sub-header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: EatsTheme.panelHeader,
                      child: Row(
                        children: [
                          Icon(Icons.terminal, size: 14, color: EatsTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'TARGET: ${activeTarget.title.toUpperCase()}',
                              style: EatsTheme.getPrimaryFontStyle(
                                color: targetBadgeBg,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${lines.length} lines • Ctrl+Enter to run',
                            style: EatsTheme.getPrimaryFontStyle(
                              color: EatsTheme.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Synchronized 20-line Viewport (Height = 20 * 16.8px + 16px = 352px)
                    SizedBox(
                      height: 340,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Line Number Gutter (Synced scroll offset)
                          Container(
                            width: 42,
                            color: EatsTheme.codeEditorGutterBackground,
                            child: SingleChildScrollView(
                              controller: _gutterScrollController,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(
                                  lines.length.clamp(1, 9999),
                                  (i) => Container(
                                    height: 16.8,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        height: 1.4,
                                        color: (i + 1 == result.errorLine)
                                            ? Colors.redAccent
                                            : EatsTheme.codeEditorGutterTextColor,
                                        fontWeight: (i + 1 == result.errorLine) ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Code Editor Text Field (Master Scroll)
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              focusNode: _editorFocusNode,
                              scrollController: _editorScrollController,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              style: TextStyle(
                                color: EatsTheme.codeEditorTextColor,
                                fontSize: 12,
                                height: 1.4,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.all(8),
                                border: InputBorder.none,
                                hintText: '-- Write Lua DSP, MIDI FX, or Clip script here...',
                                hintStyle: TextStyle(color: EatsTheme.textMuted, fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // Compiler Diagnostics Status Bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: result.isSuccess ? EatsTheme.accentGreen.withOpacity(0.1) : EatsTheme.muteColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: result.isSuccess ? EatsTheme.accentGreen.withOpacity(0.5) : EatsTheme.muteColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  result.isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: result.isSuccess ? EatsTheme.accentGreen : EatsTheme.muteColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.errorMessage,
                    style: EatsTheme.getDisplayFontStyle(
                      color: result.isSuccess ? EatsTheme.accentGreen : EatsTheme.muteColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Dynamic Live Parameter Controls for Active Script Target
          if (result.params.isNotEmpty) ...[
            Text(
              'LIVE SCRIPT PARAMETERS (${activeTarget.title.toUpperCase()})',
              style: EatsTheme.getPrimaryFontStyle(color: targetBadgeBg, fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: result.params.map((param) {
                final currentVal = currentTargetParams[param.name] ?? param.defaultValue;

                return Container(
                  width: 160,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EatsTheme.panelBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: targetBadgeBg.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              param.name,
                              overflow: TextOverflow.ellipsis,
                              style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 10.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentVal.toStringAsFixed(1),
                            style: EatsTheme.getDisplayFontStyle(color: targetBadgeBg, fontWeight: FontWeight.bold, fontSize: 10.5),
                          ),
                        ],
                      ),
                      EatsBeatsSlider(
                        value: currentVal.clamp(param.min, param.max),
                        min: param.min,
                        max: param.max,
                        defaultValue: param.defaultValue,
                        label: param.name,
                        activeColor: targetBadgeBg,
                        onChanged: (val) {
                          widget.dawState.updateScriptParamForTarget(activeTarget, param.name, val);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --- Dedicated Left Script Explorer Tree Widget ---
  Widget _buildScriptExplorer(List<ScriptTarget> allTargets, ScriptTarget activeTarget) {
    final query = _scriptFilterQuery.trim().toLowerCase();
    final dspTargets = allTargets.where((t) => t.type == ScriptTargetType.trackDsp).where((t) => query.isEmpty || t.title.toLowerCase().contains(query)).toList();
    final audioFxTargets = allTargets.where((t) => t.type == ScriptTargetType.audioFx).where((t) => query.isEmpty || t.title.toLowerCase().contains(query)).toList();
    final midiFxTargets = allTargets.where((t) => t.type == ScriptTargetType.midiFx).where((t) => query.isEmpty || t.title.toLowerCase().contains(query)).toList();
    final clipTargets = allTargets.where((t) => t.type == ScriptTargetType.clipScript).where((t) => query.isEmpty || t.title.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        // Explorer Header & Filter Field
        Container(
          padding: const EdgeInsets.all(8),
          color: EatsTheme.panelHeader,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.account_tree_outlined, size: 14, color: EatsTheme.primaryCyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'PROJECT SCRIPTS',
                            style: EatsTheme.getDisplayFontStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.textLight),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${allTargets.length}',
                    style: TextStyle(fontSize: 10, color: EatsTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                onChanged: (val) => setState(() => _scriptFilterQuery = val),
                style: const TextStyle(fontSize: 11, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Filter scripts...',
                  hintStyle: TextStyle(fontSize: 10, color: EatsTheme.textMuted),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 14, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        // Categorized Script List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              // 1. Synth Instruments & DSP
              _buildExplorerCategoryHeader('SYNTHS & DSP (${dspTargets.length})', Icons.piano, EatsTheme.primaryCyan),
              ...dspTargets.map((t) => _buildExplorerScriptItem(t, activeTarget)),

              const Divider(color: Color(0xFF2B3245), height: 12),

              // 2. Audio FX Inserts
              _buildExplorerCategoryHeader('AUDIO FX INSERTS (${audioFxTargets.length})', Icons.graphic_eq, EatsTheme.secondaryMagenta),
              if (audioFxTargets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text('No Audio FX modules in tracks', style: TextStyle(fontSize: 9.5, color: EatsTheme.textMuted, fontStyle: FontStyle.italic)),
                )
              else
                ...audioFxTargets.map((t) => _buildExplorerScriptItem(t, activeTarget)),

              const Divider(color: Color(0xFF2B3245), height: 12),

              // 3. Track MIDI FX Inserts
              _buildExplorerCategoryHeader('TRACK MIDI FX (${midiFxTargets.length})', Icons.bolt, EatsTheme.accentGold),
              if (midiFxTargets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text('No MIDI FX modules in tracks', style: TextStyle(fontSize: 9.5, color: EatsTheme.textMuted, fontStyle: FontStyle.italic)),
                )
              else
                ...midiFxTargets.map((t) => _buildExplorerScriptItem(t, activeTarget)),

              const Divider(color: Color(0xFF2B3245), height: 12),

              // 4. Generative Clip Scripts
              _buildExplorerCategoryHeader('CLIP SCRIPTS (${clipTargets.length})', Icons.view_timeline, EatsTheme.accentGreen),
              if (clipTargets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text('No clip scripts active', style: TextStyle(fontSize: 9.5, color: EatsTheme.textMuted, fontStyle: FontStyle.italic)),
                )
              else
                ...clipTargets.map((t) => _buildExplorerScriptItem(t, activeTarget)),

              const Divider(color: Color(0xFF2B3245), height: 12),

              // 5. Preset Templates & Boilerplates
              _buildExplorerCategoryHeader('QUICK TEMPLATES', Icons.bookmark_border, EatsTheme.accentGreen),
              _buildTemplateTile('Acid 303 Synth', '-- Acid 303 DSP\nfunction Synth.render() end', EatsTheme.primaryCyan),
              _buildTemplateTile('Pattern Arpeggiator', '-- Arpeggiator Script\nclip:registerParam("rate", 0.125, 1.0, 0.25)\nfunction process(notes, time_ctx)\n  return arpeggiate(notes, params.rate)\nend', EatsTheme.accentGold),
              _buildTemplateTile('Scale Snap (C Major)', '-- Scale Snap\nclip:registerParam("key", 0, 11, 0)\nfunction process(notes, time_ctx)\n  return scale_snap(notes, params.key)\nend', EatsTheme.accentGreen),
              _buildTemplateTile('Euclidean Rhythm', '-- Euclidean Generator\nclip:registerParam("pulses", 1, 16, 5)\nclip:registerParam("steps", 4, 32, 16)\nfunction process(notes, time_ctx)\n  return generate_euclidean(params.pulses, params.steps, 60)\nend', EatsTheme.secondaryMagenta),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExplorerCategoryHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EatsTheme.getPrimaryFontStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerScriptItem(ScriptTarget target, ScriptTarget activeTarget) {
    final isSelected = target.id == activeTarget.id;
    final badgeColor = target.type == ScriptTargetType.trackDsp
        ? EatsTheme.primaryCyan
        : (target.type == ScriptTargetType.midiFx
            ? EatsTheme.accentGold
            : (target.type == ScriptTargetType.audioFx
                ? EatsTheme.secondaryMagenta
                : EatsTheme.accentGreen));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? badgeColor.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isSelected ? badgeColor : Colors.transparent, width: 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            setState(() {
              widget.dawState.selectScriptTarget(target);
              _codeController.text = widget.dawState.getScriptCodeForTarget(target);
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: target.trackColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    target.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? (EatsTheme.isLight ? badgeColor : EatsTheme.textPrimary) : EatsTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateTile(String name, String code, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _loadTemplate(code, name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, size: 11, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(fontSize: 10, color: EatsTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.file_download_outlined, size: 12, color: color.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<int> timeData;

  WaveformPainter({required this.timeData});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1B2A1C)
      ..strokeWidth = 1.0;

    final centerPaint = Paint()
      ..color = const Color(0xFF28402A)
      ..strokeWidth = 1.2;

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), centerPaint);

    for (double y = midY - 18; y > 0; y -= 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double y = midY + 18; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const numVertDivisions = 8;
    final vertStep = size.width / numVertDivisions;
    for (int i = 1; i < numVertDivisions; i++) {
      final vx = i * vertStep;
      canvas.drawLine(Offset(vx, 0), Offset(vx, size.height), gridPaint);
    }

    if (timeData.isEmpty) return;

    final path = Path();
    final sliceWidth = size.width / timeData.length;

    double x = 0;
    for (int i = 0; i < timeData.length; i++) {
      final v = timeData[i] / 128.0;
      final y = v * size.height / 2;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      x += sliceWidth;
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF00FF66)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawPath(path, glowPaint);

    final tracePaint = Paint()
      ..color = const Color(0xFFE5FFEC)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, tracePaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}

class _LcdOscilloscopeGlassReflectionPainter extends CustomPainter {
  const _LcdOscilloscopeGlassReflectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glarePath = Path();
    glarePath.moveTo(0, 0);
    glarePath.lineTo(size.width, 0);
    glarePath.lineTo(size.width, size.height * 0.45);
    glarePath.close();

    final glarePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));

    canvas.drawPath(glarePath, glarePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
