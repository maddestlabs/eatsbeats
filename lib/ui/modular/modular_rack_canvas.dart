import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../widgets/skeuomorphic_hardware_knob.dart';
import 'modular_theme.dart';
import 'modular_faceplate_widget.dart';
import 'modular_jack_widget.dart';
import 'patch_cable_painter.dart';
import 'modular_module_search_dialog.dart';
import 'modular_rack_dsl.dart';
import '../../eatscript/eatscript_graph_model.dart';
import '../../eatscript/eats_script_engine.dart';

/// Interactive Eurorack Modular Studio Canvas.
/// Visualizes, patches, and live-edits Eatscript signal graphs with bi-directional synchronization.
class ModularRackCanvas extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;

  const ModularRackCanvas({
    super.key,
    required this.dawState,
    required this.track,
  });

  /// Calculates mathematically exact subpixel socket coordinates inside the scrollable rack canvas.
  static Offset computeJackCenter({
    required int row,
    required List<int> previousHpList,
    required int currentHp,
    required int jackIndex,
    required int totalJacks,
  }) {
    // 8px container padding + cumulative (hp * 16px + 4px margin)
    double moduleLeft = 8.0;
    for (final hp in previousHpList) {
      moduleLeft += (hp * ModularTheme.standardHpUnit) + 4.0;
    }

    final double moduleWidth = currentHp * ModularTheme.standardHpUnit;
    final double innerWidth = moduleWidth - 16.0;

    double jackLocalX;
    if (totalJacks <= 1) {
      jackLocalX = moduleWidth * 0.5;
    } else {
      final double slotWidth = innerWidth / totalJacks;
      jackLocalX = 8.0 + (slotWidth * (jackIndex + 0.5));
    }

    final double tierTop = (row - 1) * 211.0;
    final double jackY = tierTop + 18.0 + 148.0;

    return Offset(moduleLeft + jackLocalX, jackY);
  }

  @override
  State<ModularRackCanvas> createState() => _ModularRackCanvasState();
}

class _ModularRackCanvasState extends State<ModularRackCanvas> {
  final TransformationController _transformController = TransformationController();

  int _totalRowCount = 2;
  double _cableOpacity = 0.95;

  // Active module definitions organized by row index
  final Map<int, List<DynamicModuleDefinition>> _modulesByRow = {1: [], 2: []};
  final List<DynamicPatchConnection> _connections = [];

  // Active Dragging State
  JackKey? _dragStartKey;
  Offset? _dragStartPos;
  Offset? _dragCurrentPos;
  Color _dragCableColor = ModularTheme.cableAudio;

  @override
  void initState() {
    super.initState();
    _loadFromTrackScript();
  }

  @override
  void didUpdateWidget(covariant ModularRackCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.luaScriptCode != widget.track.luaScriptCode) {
      _loadFromTrackScript();
    }
  }

  void _loadFromTrackScript() {
    final code = widget.track.luaScriptCode;
    final parsed = ModularRackDsl.parse(code);

    if (parsed != null && (parsed.modulesByRow.values.any((list) => list.isNotEmpty))) {
      setState(() {
        _totalRowCount = math.max(2, parsed.totalRows);
        _modulesByRow.clear();
        for (int r = 1; r <= _totalRowCount; r++) {
          _modulesByRow[r] = List.from(parsed.modulesByRow[r] ?? []);
        }
        _connections.clear();
        _connections.addAll(parsed.cables);
      });
      return;
    }

    // Default Eatscript Synthesizer Topology
    final defaultDef = ModularRackDsl.generateDefault(code, trackName: widget.track.name);
    setState(() {
      _totalRowCount = math.max(2, defaultDef.totalRows);
      _modulesByRow.clear();
      for (int r = 1; r <= _totalRowCount; r++) {
        _modulesByRow[r] = List.from(defaultDef.modulesByRow[r] ?? []);
      }
      _connections.clear();
      _connections.addAll(defaultDef.cables);
    });
  }

  void _syncToScript() {
    final isEatScript = EatScriptEngine.isEatScript(widget.track.luaScriptCode) ||
        widget.track.luaScriptCode.contains('def graph') ||
        !widget.track.luaScriptCode.contains('function');

    if (isEatScript) {
      // Build EatscriptGraphDef directly
      final nodes = <EatscriptNodeDef>[];
      final Map<String, String> jackToNode = {};

      for (int r = 1; r <= _totalRowCount; r++) {
        final mods = _modulesByRow[r] ?? [];
        for (int m = 0; m < mods.length; m++) {
          final mod = mods[m];
          final nodeType = mod.id.replaceAll(RegExp(r'\d+$'), '');
          final nodeId = mod.id;

          final ports = <EatscriptPortDef>[];
          for (final inJ in mod.inputJacks) {
            ports.add(EatscriptPortDef(id: inJ.toLowerCase().replaceAll(' ', '_'), name: inJ, isInput: true));
          }
          for (final outJ in mod.outputJacks) {
            ports.add(EatscriptPortDef(id: outJ.toLowerCase().replaceAll(' ', '_'), name: outJ, isInput: false));
          }

          nodes.add(EatscriptNodeDef(
            id: nodeId,
            type: nodeType,
            title: mod.title,
            params: Map.from(mod.defaultParams ?? {}),
            ports: ports,
          ));

          for (int j = 0; j < mod.inputJacks.length + mod.outputJacks.length; j++) {
            jackToNode['$r:$m:$j'] = nodeId;
          }
        }
      }

      final graphCables = <EatscriptCableDef>[];
      for (final c in _connections) {
        final fromNode = jackToNode[c.fromKey.serializedKey];
        final toNode = jackToNode[c.toKey.serializedKey];
        if (fromNode != null && toNode != null) {
          graphCables.add(EatscriptCableDef(
            fromNodeId: fromNode,
            fromPort: c.fromKey.label.toLowerCase().replaceAll(' ', '_'),
            toNodeId: toNode,
            toPort: c.toKey.label.toLowerCase().replaceAll(' ', '_'),
            color: c.color,
          ));
        }
      }

      final graphDef = EatscriptGraphDef(nodes: nodes, cables: graphCables);
      final newCode = EatscriptGraphDef.serialize(
        graphDef,
        existingCode: widget.track.luaScriptCode,
        instrumentName: widget.track.name.isNotEmpty ? widget.track.name : 'Instrument',
      );

      if (widget.track.luaScriptCode != newCode) {
        widget.track.luaScriptCode = newCode;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        widget.dawState.notifyListeners();
      }
    } else {
      // Legacy serialization
      final serialized = ModularRackDsl.serialize(
        totalRows: _totalRowCount,
        customModulesByRow: _modulesByRow,
        cables: _connections,
        existingScriptCode: widget.track.luaScriptCode,
        instrumentName: widget.track.name.replaceAll(RegExp(r'[^A-Za-z0-9_]'), ''),
      );
      if (widget.track.luaScriptCode != serialized) {
        widget.track.luaScriptCode = serialized;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        widget.dawState.notifyListeners();
      }
    }
  }

  List<int> _getRowHpList(int row) {
    return (_modulesByRow[row] ?? []).map((m) => m.hpWidth).toList();
  }

  Offset _resolveJackOffset(JackKey key) {
    final hpList = _getRowHpList(key.row);
    final previousHps = hpList.take(key.moduleIndex).toList();
    final currentHp = key.moduleIndex < hpList.length ? hpList[key.moduleIndex] : 10;
    final totalJacks = _getModuleJackCount(key.row, key.moduleIndex);

    return ModularRackCanvas.computeJackCenter(
      row: key.row,
      previousHpList: previousHps,
      currentHp: currentHp,
      jackIndex: key.jackIndex,
      totalJacks: totalJacks,
    );
  }

  int _getModuleJackCount(int row, int moduleIndex) {
    final mods = _modulesByRow[row] ?? [];
    if (moduleIndex < mods.length) {
      final mod = mods[moduleIndex];
      return mod.inputJacks.length + mod.outputJacks.length;
    }
    return 2;
  }

  JackKey? _findClosestJack(Offset canvasPos) {
    JackKey? bestKey;
    double bestDist = 36.0;

    for (int r = 1; r <= _totalRowCount; r++) {
      final mods = _modulesByRow[r] ?? [];
      for (int m = 0; m < mods.length; m++) {
        final totalJacks = _getModuleJackCount(r, m);
        for (int j = 0; j < totalJacks; j++) {
          final key = JackKey(row: r, moduleIndex: m, jackIndex: j, label: 'Jack');
          final jackPos = _resolveJackOffset(key);
          final dist = (jackPos - canvasPos).distance;
          if (dist < bestDist) {
            bestDist = dist;
            bestKey = key;
          }
        }
      }
    }
    return bestKey;
  }

  void _onJackTap(JackKey key) {
    final existingIdx = _connections.indexWhere((c) =>
      c.fromKey == key || c.toKey == key ||
      (c.fromKey.row == key.row && c.fromKey.moduleIndex == key.moduleIndex && c.fromKey.label.toLowerCase() == key.label.toLowerCase()) ||
      (c.toKey.row == key.row && c.toKey.moduleIndex == key.moduleIndex && c.toKey.label.toLowerCase() == key.label.toLowerCase()),
    );
    if (existingIdx != -1) {
      final conn = _connections[existingIdx];
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF10161D),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.palette, color: conn.color),
                title: const Text('Cycle Cable Color', style: TextStyle(fontFamily: 'Courier', color: Colors.white, fontSize: 13)),
                subtitle: const Text('Audio -> CV -> Gate -> Mod', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    Color nextColor = ModularTheme.cableAudio;
                    if (conn.color == ModularTheme.cableAudio) nextColor = ModularTheme.cablePitchCv;
                    else if (conn.color == ModularTheme.cablePitchCv) nextColor = ModularTheme.cableGate;
                    else if (conn.color == ModularTheme.cableGate) nextColor = ModularTheme.cableModulation;
                    else nextColor = ModularTheme.cableAudio;

                    _connections[existingIdx] = DynamicPatchConnection(
                      fromKey: conn.fromKey,
                      toKey: conn.toKey,
                      color: nextColor,
                      tension: conn.tension,
                    );
                  });
                  _syncToScript();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.redAccent),
                title: const Text('Disconnect Patch Cable', style: TextStyle(fontFamily: 'Courier', color: Colors.redAccent, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _connections.removeAt(existingIdx);
                  });
                  _syncToScript();
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openAddModuleDialog(int row) {
    showDialog(
      context: context,
      builder: (ctx) => ModularModuleSearchDialog(
        targetRow: row,
        onModuleSelected: (selectedMod) {
          setState(() {
            final uniqueId = '${selectedMod.id}_${DateTime.now().millisecondsSinceEpoch % 1000}';
            final newMod = DynamicModuleDefinition(
              id: uniqueId,
              title: selectedMod.title,
              subtitle: selectedMod.subtitle,
              hpWidth: selectedMod.hpWidth,
              accentColor: selectedMod.accentColor,
              category: selectedMod.category,
              inputJacks: List.from(selectedMod.inputJacks),
              outputJacks: List.from(selectedMod.outputJacks),
              description: selectedMod.description,
              scriptCode: selectedMod.scriptCode,
              defaultParams: Map.from(selectedMod.defaultParams ?? {}),
            );
            _modulesByRow[row] ??= [];
            _modulesByRow[row]!.add(newMod);
          });
          _syncToScript();
        },
      ),
    );
  }

  void _openScriptEditorDialog(DynamicModuleDefinition mod) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10161D),
        title: Text('SCRIPT: ${mod.title}', style: const TextStyle(fontFamily: 'Courier', color: Colors.white, fontSize: 14)),
        content: Container(
          width: 500,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF070C11),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            mod.scriptCode ?? '# Programmable Eatscript DSP Core\ndef process(time, freq, note, params):\n    return eat.saw(freq)\n',
            style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Color(0xFF00E5FF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double canvasWidth = 3200.0;
    final double canvasHeight = math.max(760.0, _totalRowCount * 220.0 + 100.0);

    return Container(
      color: ModularTheme.caseBackground,
      child: Column(
        children: [
          // --- TOP TOOLBAR ---
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: ModularTheme.railMetalColor,
            child: Row(
              children: [
                const Icon(Icons.cable, color: ModularTheme.cableAudio, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MODULAR RACK: ${widget.track.name.toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFFCCCCCC),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // DSP Sync status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, size: 11, color: Color(0xFF00E676)),
                      const SizedBox(width: 4),
                      Text(
                        widget.track.luaScriptCode.contains('function') ? 'LUA SYNC: OK' : 'DSP SYNC: OK',
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                      ),
                    ],
                  ),
                ),

                // Reset Camera Zoom/Pan
                IconButton(
                  icon: const Icon(Icons.center_focus_strong, size: 14, color: Colors.white70),
                  tooltip: 'Reset Viewport',
                  onPressed: () => _transformController.value = Matrix4.identity(),
                ),

                // Reset Patch Cables
                InkWell(
                  onTap: () {
                    setState(() {
                      final defaultDef = ModularRackDsl.generateDefault(widget.track.luaScriptCode, trackName: widget.track.name);
                      _connections.clear();
                      _connections.addAll(defaultDef.cables);
                    });
                    _syncToScript();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ModularTheme.faceplateDarkBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 12, color: Colors.white70),
                        SizedBox(width: 4),
                        Text('RESET PATCH', style: TextStyle(fontFamily: 'Courier', fontSize: 8.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),

                // Cable Opacity Control
                const Text('CABLES:', style: TextStyle(fontFamily: 'Courier', fontSize: 9, color: Color(0xFF888888))),
                SizedBox(
                  width: 75,
                  child: SliderTheme(
                    data: const SliderThemeData(
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                      trackHeight: 2,
                      activeTrackColor: ModularTheme.cableAudio,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: ModularTheme.cableAudio,
                    ),
                    child: Slider(
                      value: _cableOpacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) => setState(() => _cableOpacity = val),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 2D PAN & ZOOM MODULAR CANVAS ---
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(400),
              minScale: 0.6,
              maxScale: 1.6,
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  children: [
                    // Rack Rails & Modules
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int r = 1; r <= _totalRowCount; r++) ...[
                          _buildRailBar('ROW $r: ${_getRailDescription(r)}', canvasWidth),
                          Container(
                            height: ModularTheme.moduleHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                ..._buildRowModules(r),
                                _buildAddModuleBlankPlate(r),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // + ADD ROW BUTTON
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _totalRowCount++;
                                _modulesByRow[_totalRowCount] = [];
                              });
                              _syncToScript();
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: ModularTheme.railMetalColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ModularTheme.cablePitchCv.withValues(alpha: 0.6)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, color: ModularTheme.cablePitchCv, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    '+ ADD RACK ROW (EXPAND MODULAR CASE)',
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: ModularTheme.cablePitchCv,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Patch Cables Overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: PatchCablePainter(
                            opacity: _cableOpacity,
                            cables: [
                              for (final conn in _connections)
                                ModularPatchCable(
                                  from: _resolveJackOffset(conn.fromKey),
                                  to: _resolveJackOffset(conn.toKey),
                                  color: conn.color,
                                  tension: conn.tension,
                                ),
                              if (_dragStartPos != null && _dragCurrentPos != null)
                                ModularPatchCable(
                                  from: _dragStartPos!,
                                  to: _dragCurrentPos!,
                                  color: _dragCableColor,
                                  tension: 0.5,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailBar(String title, double width) {
    return Container(
      width: width,
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: ModularTheme.railMetalColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.white54,
            ),
          ),
          const Row(
            children: [
              Icon(Icons.crop_square, size: 10, color: Colors.white24),
              SizedBox(width: 8),
              Icon(Icons.crop_square, size: 10, color: Colors.white24),
              SizedBox(width: 8),
              Icon(Icons.crop_square, size: 10, color: Colors.white24),
            ],
          ),
        ],
      ),
    );
  }

  String _getRailDescription(int row) {
    if (row == 1) return 'AUDIO GENERATION, HARDWARE CORES & PRIMARY FILTERS';
    if (row == 2) return 'MODULATION ENVELOPES, DSP GLUE & MASTER OUT';
    return 'CUSTOM EXPANSION TIER & SIGNAL PROCESSORS';
  }

  List<Widget> _buildRowModules(int row) {
    final modules = _modulesByRow[row] ?? [];
    final List<Widget> widgets = [];

    for (int m = 0; m < modules.length; m++) {
      widgets.add(_buildModuleWidget(row, m, modules[m]));
    }
    return widgets;
  }

  Widget _buildModuleWidget(int row, int moduleIndex, DynamicModuleDefinition mod) {
    final isScript = mod.category == 'SCRIPT';
    final hasParams = widget.track.luaParams.isNotEmpty;
    final paramCount = widget.track.luaParams.length;

    // Display title: if core DSP module, show LUA/EATSCRIPT DSP CORE
    String displayTitle = mod.title;
    if (mod.id == 'core') {
      if (widget.track.luaScriptCode.contains('function')) {
        displayTitle = 'LUA SCRIPT DSP CORE';
      } else {
        displayTitle = 'EATSCRIPT DSP CORE';
      }
    }

    return ModularFaceplateWidget(
      title: displayTitle,
      subtitle: mod.subtitle,
      hpWidth: mod.hpWidth,
      accentColor: mod.accentColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Subtitle / Track Name header if custom track
          if (mod.id == 'core') ...[
            Text(
              widget.track.name.toUpperCase(),
              style: const TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ],
          if (mod.id == 'core' || isScript) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF071217),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: mod.accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: mod.accentColor)),
                      const SizedBox(width: 4),
                      Text('DSP ACTIVE', style: TextStyle(fontFamily: 'Courier', fontSize: 7, fontWeight: FontWeight.bold, color: mod.accentColor)),
                    ],
                  ),
                  if (hasParams)
                    Text('$paramCount PARAMS', style: const TextStyle(fontFamily: 'Courier', fontSize: 6.5, color: Colors.white70)),
                  InkWell(
                    onTap: () => _openScriptEditorDialog(mod),
                    child: Text('EDIT', style: TextStyle(fontFamily: 'Courier', fontSize: 6.5, fontWeight: FontWeight.bold, color: mod.accentColor)),
                  ),
                ],
              ),
            ),
          ],

          // Knobs / Parameter Controls
          Expanded(
            child: _buildModuleControls(mod),
          ),

          // Jacks Row
          _buildModuleJacksRow(row, moduleIndex, mod),
        ],
      ),
    );
  }

  Widget _buildModuleControls(DynamicModuleDefinition mod) {
    // If track has specific luaParams (like Harmonics, Feedback)
    if (widget.track.luaParams.isNotEmpty && (mod.id == 'core' || mod.category == 'SCRIPT')) {
      final entries = widget.track.luaParams.entries.take(2).toList();
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: entries.map((e) {
            final label = e.key.length > 7 ? e.key.substring(0, 7).toUpperCase() : e.key.toUpperCase();
            return SkeuomorphicHardwareKnob(
              label: label,
              value: e.value,
              min: 0.0,
              max: 1.0,
              defaultValue: 0.5,
              size: 32,
              accentColor: mod.accentColor,
              onChanged: (v) {
                setState(() => widget.track.luaParams[e.key] = v);
                // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                widget.dawState.notifyListeners();
              },
            );
          }).toList(),
        ),
      );
    }

    final paramEntries = (mod.defaultParams ?? {}).entries.take(2).toList();
    if (paramEntries.isEmpty) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SkeuomorphicHardwareKnob(
              label: 'PARAM 1',
              value: 0.5,
              min: 0.0,
              max: 1.0,
              defaultValue: 0.5,
              size: 30,
              accentColor: mod.accentColor,
              onChanged: (v) {},
            ),
            SkeuomorphicHardwareKnob(
              label: 'PARAM 2',
              value: 0.5,
              min: 0.0,
              max: 1.0,
              defaultValue: 0.5,
              size: 30,
              accentColor: mod.accentColor,
              onChanged: (v) {},
            ),
          ],
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: paramEntries.map((e) {
          final label = e.key.length > 7 ? e.key.substring(0, 7).toUpperCase() : e.key.toUpperCase();
          return SkeuomorphicHardwareKnob(
            label: label,
            value: e.value,
            min: 0.0,
            max: 1.0,
            defaultValue: e.value,
            size: 32,
            accentColor: mod.accentColor,
            onChanged: (v) {
              setState(() => mod.defaultParams?[e.key] = v);
              _syncToScript();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModuleJacksRow(int row, int moduleIndex, DynamicModuleDefinition mod) {
    final List<Widget> jackWidgets = [];
    int jackIdx = 0;

    // Inputs
    for (final inJ in mod.inputJacks) {
      final key = JackKey(row: row, moduleIndex: moduleIndex, jackIndex: jackIdx, label: inJ);
      final isConn = _connections.any((c) => c.fromKey == key || c.toKey == key);
      final label = inJ.length > 7 ? inJ.substring(0, 7).toUpperCase() : inJ.toUpperCase();

      jackWidgets.add(
        ModularJackWidget(
          label: label,
          type: JackType.input,
          isConnected: isConn,
          onTap: () => _onJackTap(key),
          onDragStart: (details) => _startJackDrag(key, details.globalPosition),
          onDragUpdate: (details) => _updateJackDrag(details.globalPosition),
          onDragEnd: (details) => _endJackDrag(),
        ),
      );
      jackIdx++;
    }

    // Outputs
    for (final outJ in mod.outputJacks) {
      final key = JackKey(row: row, moduleIndex: moduleIndex, jackIndex: jackIdx, label: outJ);
      final isConn = _connections.any((c) => c.fromKey == key || c.toKey == key);
      final label = outJ.length > 7 ? outJ.substring(0, 7).toUpperCase() : outJ.toUpperCase();

      jackWidgets.add(
        ModularJackWidget(
          label: label,
          type: JackType.output,
          isConnected: isConn,
          onTap: () => _onJackTap(key),
          onDragStart: (details) => _startJackDrag(key, details.globalPosition),
          onDragUpdate: (details) => _updateJackDrag(details.globalPosition),
          onDragEnd: (details) => _endJackDrag(),
        ),
      );
      jackIdx++;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: jackWidgets,
        ),
      ),
    );
  }

  Widget _buildAddModuleBlankPlate(int row) {
    return Container(
      width: 48,
      height: ModularTheme.moduleHeight,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: InkWell(
        onTap: () => _openAddModuleDialog(row),
        borderRadius: BorderRadius.circular(4),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, color: ModularTheme.cablePitchCv, size: 22),
              SizedBox(height: 4),
              Text(
                '+ ADD',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: ModularTheme.cablePitchCv,
                ),
              ),
              Text(
                'MODULE',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 7.5,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startJackDrag(JackKey key, Offset globalPos) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final canvasPos = _resolveJackOffset(key);

    setState(() {
      _dragStartKey = key;
      _dragStartPos = canvasPos;
      _dragCurrentPos = canvasPos;
      _dragCableColor = key.label.toLowerCase().contains('pitch') || key.label.contains('1V')
          ? ModularTheme.cablePitchCv
          : (key.label.toLowerCase().contains('gate') ? ModularTheme.cableGate : ModularTheme.cableAudio);
    });
  }

  void _updateJackDrag(Offset globalPos) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final scenePos = _transformController.toScene(local);

    setState(() {
      _dragCurrentPos = scenePos;
    });
  }

  void _endJackDrag() {
    if (_dragStartKey != null && _dragCurrentPos != null) {
      final targetKey = _findClosestJack(_dragCurrentPos!);
      if (targetKey != null && targetKey != _dragStartKey) {
        // Prevent duplicate connections
        final alreadyExists = _connections.any(
          (c) => (c.fromKey == _dragStartKey && c.toKey == targetKey) ||
                 (c.fromKey == targetKey && c.toKey == _dragStartKey),
        );

        if (!alreadyExists) {
          setState(() {
            _connections.add(DynamicPatchConnection(
              fromKey: _dragStartKey!,
              toKey: targetKey,
              color: _dragCableColor,
              tension: 0.5,
            ));
          });
          _syncToScript();
        }
      }
    }

    setState(() {
      _dragStartKey = null;
      _dragStartPos = null;
      _dragCurrentPos = null;
    });
  }
}
