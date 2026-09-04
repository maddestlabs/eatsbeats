import 'package:flutter/material.dart';
import '../../lua/lua_engine.dart';
import '../../lua/lua_gui_model.dart';
import '../../lua/lua_gui_parser.dart';
import '../../lua/lua_gui_serializer.dart';
import '../../audio/procedural_ir_generator.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../models/script_target_model.dart';
import '../../theme/eats_theme.dart';
import '../widgets/dynamic_instrument_gui_widget.dart';
import '../widgets/skeuomorphic_hardware_knob.dart';
import '../widgets/skeuomorphic_hardware_slider.dart';
import '../widgets/skeuomorphic_hardware_switch.dart';
import '../widgets/glowing_nixie_display.dart';
import '../widgets/hardware_listbox_widget.dart';
import '../widgets/skeuomorphic_hardware_button.dart';
import '../widgets/space_visualizer_widget.dart';
import '../widgets/waveshaper_canvas_widget.dart';
import '../textures/daw_texture_engine.dart';
import 'gui_inspector_sidebar.dart';
import 'gui_widget_palette.dart';

class GuiWidgetLocation {
  final int rowIndex;
  final int? childIndex;
  final int? stackChildIndex;

  const GuiWidgetLocation({
    required this.rowIndex,
    this.childIndex,
    this.stackChildIndex,
  });
}

class GuiDesignerCanvasView extends StatefulWidget {
  final DawState dawState;
  final ScriptTarget target;
  final String scriptCode;
  final void Function(String updatedScriptCode) onScriptCodeChanged;

  const GuiDesignerCanvasView({
    super.key,
    required this.dawState,
    required this.target,
    required this.scriptCode,
    required this.onScriptCodeChanged,
  });

  @override
  State<GuiDesignerCanvasView> createState() => _GuiDesignerCanvasViewState();
}

class _GuiDesignerCanvasViewState extends State<GuiDesignerCanvasView> {
  late LuaGuiPanelDef _panel;
  int? _selectedRowIndex;
  int? _selectedChildIndex;
  int? _selectedStackChildIndex;
  bool _isPaletteOpen = true;
  bool _isInspectorOpen = true;

  @override
  void initState() {
    super.initState();
    _initPanelFromCode();
  }

  @override
  void didUpdateWidget(covariant GuiDesignerCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptCode != widget.scriptCode || oldWidget.target.id != widget.target.id) {
      _initPanelFromCode();
    }
  }

  void _initPanelFromCode() {
    final parsed = LuaGuiParser.parseFromCode(widget.scriptCode);
    if (parsed != null) {
      _panel = parsed;
    } else {
      final compilation = LuaEngine.compile(widget.scriptCode);
      _panel = LuaGuiSerializer.generateDefaultPanel(
        title: widget.target.title.toUpperCase(),
        params: compilation.params,
      );
    }
  }

  void _applyPanelChanges(LuaGuiPanelDef updatedPanel) {
    setState(() {
      _panel = updatedPanel;
    });

    final serialized = LuaGuiSerializer.serialize(
      panel: updatedPanel,
      existingScriptCode: widget.scriptCode,
      instrumentName: widget.target.title,
    );

    widget.onScriptCodeChanged(serialized);
  }

  void _addRow() {
    final rows = List<LuaGuiNode>.from(_panel.children);
    rows.add(const LuaGuiNode(
      type: LuaGuiNodeType.row,
      children: [],
    ));

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));

    setState(() {
      _selectedRowIndex = rows.length - 1;
      _selectedChildIndex = null;
      _selectedStackChildIndex = null;
    });
  }

  void _deleteRow(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _panel.children.length) return;
    final rows = List<LuaGuiNode>.from(_panel.children);
    rows.removeAt(rowIndex);

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));

    setState(() {
      _selectedRowIndex = null;
      _selectedChildIndex = null;
      _selectedStackChildIndex = null;
    });
  }

  void _moveRow(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _panel.children.length) return;
    if (newIndex < 0 || newIndex >= _panel.children.length) return;

    final rows = List<LuaGuiNode>.from(_panel.children);
    final item = rows.removeAt(oldIndex);
    rows.insert(newIndex, item);

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));

    setState(() {
      _selectedRowIndex = newIndex;
      _selectedChildIndex = null;
      _selectedStackChildIndex = null;
    });
  }

  void _addWidgetToRow(int rowIndex, GuiPaletteItem item, {int? insertIndex}) {
    if (rowIndex < 0 || rowIndex >= _panel.children.length) return;
    final rows = List<LuaGuiNode>.from(_panel.children);
    final row = rows[rowIndex];

    final compilation = LuaEngine.compile(widget.scriptCode);
    final availableParams = compilation.params.map((p) => p.name).toList();
    final nextUnusedParam = availableParams.firstWhere(
      (p) => !_panelHasParam(p),
      orElse: () => availableParams.isNotEmpty ? availableParams.first : 'Param',
    );

    final newNode = item.createNode(defaultParam: nextUnusedParam);
    final newChildren = List<LuaGuiNode>.from(row.children);
    if (insertIndex != null && insertIndex >= 0 && insertIndex <= newChildren.length) {
      newChildren.insert(insertIndex, newNode);
    } else {
      newChildren.add(newNode);
    }

    rows[rowIndex] = LuaGuiNode(
      type: row.type,
      orientation: row.orientation,
      align: row.align,
      children: newChildren,
    );

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));

    setState(() {
      _selectedRowIndex = rowIndex;
      _selectedChildIndex = insertIndex ?? (newChildren.length - 1);
      _selectedStackChildIndex = null;
    });
  }

  void _addWidgetToStack(int rowIndex, int childIndex, GuiPaletteItem item, {int? insertIndex}) {
    if (rowIndex < 0 || rowIndex >= _panel.children.length) return;
    final rows = List<LuaGuiNode>.from(_panel.children);
    final row = rows[rowIndex];
    if (childIndex < 0 || childIndex >= row.children.length) return;
    final stackNode = row.children[childIndex];

    final compilation = LuaEngine.compile(widget.scriptCode);
    final availableParams = compilation.params.map((p) => p.name).toList();
    final nextUnusedParam = availableParams.firstWhere(
      (p) => !_panelHasParam(p),
      orElse: () => availableParams.isNotEmpty ? availableParams.first : 'Param',
    );

    final newNode = item.createNode(defaultParam: nextUnusedParam);
    final newStackChildren = List<LuaGuiNode>.from(stackNode.children);
    if (insertIndex != null && insertIndex >= 0 && insertIndex <= newStackChildren.length) {
      newStackChildren.insert(insertIndex, newNode);
    } else {
      newStackChildren.add(newNode);
    }

    final newRowChildren = List<LuaGuiNode>.from(row.children);
    newRowChildren[childIndex] = LuaGuiNode(
      type: stackNode.type,
      orientation: stackNode.orientation,
      align: stackNode.align,
      children: newStackChildren,
    );

    rows[rowIndex] = LuaGuiNode(
      type: row.type,
      orientation: row.orientation,
      align: row.align,
      children: newRowChildren,
    );

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));

    setState(() {
      _selectedRowIndex = rowIndex;
      _selectedChildIndex = childIndex;
      _selectedStackChildIndex = insertIndex ?? (newStackChildren.length - 1);
    });
  }

  void _moveWidget(
    GuiWidgetLocation source, {
    required int toRow,
    int? toChild,
    int? toStackChild,
  }) {
    final rows = List<LuaGuiNode>.from(_panel.children);
    if (source.rowIndex < 0 || source.rowIndex >= rows.length) return;
    final srcRow = rows[source.rowIndex];

    LuaGuiNode? extractedNode;

    // 1. Extract from source
    if (source.childIndex != null && source.childIndex! >= 0 && source.childIndex! < srcRow.children.length) {
      if (source.stackChildIndex != null) {
        final stackNode = srcRow.children[source.childIndex!];
        if (source.stackChildIndex! >= 0 && source.stackChildIndex! < stackNode.children.length) {
          final newStackChildren = List<LuaGuiNode>.from(stackNode.children);
          extractedNode = newStackChildren.removeAt(source.stackChildIndex!);

          final newRowChildren = List<LuaGuiNode>.from(srcRow.children);
          newRowChildren[source.childIndex!] = LuaGuiNode(
            type: stackNode.type,
            orientation: stackNode.orientation,
            align: stackNode.align,
            children: newStackChildren,
          );
          rows[source.rowIndex] = LuaGuiNode(
            type: srcRow.type,
            orientation: srcRow.orientation,
            align: srcRow.align,
            children: newRowChildren,
          );
        }
      } else {
        final newRowChildren = List<LuaGuiNode>.from(srcRow.children);
        extractedNode = newRowChildren.removeAt(source.childIndex!);
        rows[source.rowIndex] = LuaGuiNode(
          type: srcRow.type,
          orientation: srcRow.orientation,
          align: srcRow.align,
          children: newRowChildren,
        );
      }
    }

    if (extractedNode == null) return;

    // 2. Insert into destination
    if (toRow < 0 || toRow >= rows.length) return;
    final targetRow = rows[toRow];

    if (toChild != null && toChild >= 0 && toChild < targetRow.children.length && (targetRow.children[toChild].type == LuaGuiNodeType.column || targetRow.children[toChild].type == LuaGuiNodeType.group)) {
      // Drop into a stack
      final stackNode = targetRow.children[toChild];
      final newStackChildren = List<LuaGuiNode>.from(stackNode.children);
      if (toStackChild != null && toStackChild >= 0 && toStackChild <= newStackChildren.length) {
        newStackChildren.insert(toStackChild, extractedNode);
      } else {
        newStackChildren.add(extractedNode);
      }

      final newRowChildren = List<LuaGuiNode>.from(targetRow.children);
      newRowChildren[toChild] = LuaGuiNode(
        type: stackNode.type,
        orientation: stackNode.orientation,
        align: stackNode.align,
        children: newStackChildren,
      );
      rows[toRow] = LuaGuiNode(
        type: targetRow.type,
        orientation: targetRow.orientation,
        align: targetRow.align,
        children: newRowChildren,
      );
    } else {
      // Drop into a row
      final newRowChildren = List<LuaGuiNode>.from(targetRow.children);
      if (toChild != null && toChild >= 0 && toChild <= newRowChildren.length) {
        newRowChildren.insert(toChild, extractedNode);
      } else {
        newRowChildren.add(extractedNode);
      }
      rows[toRow] = LuaGuiNode(
        type: targetRow.type,
        orientation: targetRow.orientation,
        align: targetRow.align,
        children: newRowChildren,
      );
    }

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));

    setState(() {
      _selectedRowIndex = toRow;
      _selectedChildIndex = toChild;
      _selectedStackChildIndex = toStackChild;
    });
  }

  bool _panelHasParam(String paramName) {
    for (final row in _panel.children) {
      for (final child in row.children) {
        if (child.param == paramName) return true;
      }
    }
    return false;
  }

  void _deleteSelected() {
    final r = _selectedRowIndex;
    final c = _selectedChildIndex;
    final s = _selectedStackChildIndex;
    if (r == null || r < 0 || r >= _panel.children.length) return;

    final rows = List<LuaGuiNode>.from(_panel.children);
    final row = rows[r];

    if (c != null && c >= 0 && c < row.children.length) {
      final childNode = row.children[c];
      if (s != null &&
          (childNode.type == LuaGuiNodeType.column || childNode.type == LuaGuiNodeType.group) &&
          s >= 0 &&
          s < childNode.children.length) {
        final newStackChildren = List<LuaGuiNode>.from(childNode.children)..removeAt(s);
        final newRowChildren = List<LuaGuiNode>.from(row.children);
        newRowChildren[c] = LuaGuiNode(
          type: childNode.type,
          orientation: childNode.orientation,
          align: childNode.align,
          crossAlign: childNode.crossAlign,
          size: childNode.size,
          width: childNode.width,
          height: childNode.height,
          label: childNode.label,
          showLabel: childNode.showLabel,
          showValue: childNode.showValue,
          knobStyle: childNode.knobStyle,
          sliderStyle: childNode.sliderStyle,
          canvasMode: childNode.canvasMode,
          options: childNode.options,
          children: newStackChildren,
        );
        rows[r] = LuaGuiNode(
          type: row.type,
          orientation: row.orientation,
          align: row.align,
          crossAlign: row.crossAlign,
          children: newRowChildren,
        );
        setState(() {
          _selectedStackChildIndex = null;
        });
      } else {
        final newChildren = List<LuaGuiNode>.from(row.children)..removeAt(c);
        rows[r] = LuaGuiNode(
          type: row.type,
          orientation: row.orientation,
          align: row.align,
          crossAlign: row.crossAlign,
          children: newChildren,
        );
        setState(() {
          _selectedChildIndex = null;
          _selectedStackChildIndex = null;
        });
      }
    } else {
      rows.removeAt(r);
      setState(() {
        _selectedRowIndex = null;
        _selectedChildIndex = null;
        _selectedStackChildIndex = null;
      });
    }

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));
  }

  void _duplicateSelected() {
    final r = _selectedRowIndex;
    final c = _selectedChildIndex;
    final s = _selectedStackChildIndex;
    if (r == null || r < 0 || r >= _panel.children.length) return;

    final rows = List<LuaGuiNode>.from(_panel.children);
    final row = rows[r];

    if (c != null && c >= 0 && c < row.children.length) {
      final childNode = row.children[c];
      if (s != null &&
          (childNode.type == LuaGuiNodeType.column || childNode.type == LuaGuiNodeType.group) &&
          s >= 0 &&
          s < childNode.children.length) {
        final stackItem = childNode.children[s];
        final newStackChildren = List<LuaGuiNode>.from(childNode.children)..insert(s + 1, stackItem);
        final newRowChildren = List<LuaGuiNode>.from(row.children);
        newRowChildren[c] = LuaGuiNode(
          type: childNode.type,
          orientation: childNode.orientation,
          align: childNode.align,
          crossAlign: childNode.crossAlign,
          size: childNode.size,
          width: childNode.width,
          height: childNode.height,
          label: childNode.label,
          showLabel: childNode.showLabel,
          showValue: childNode.showValue,
          knobStyle: childNode.knobStyle,
          sliderStyle: childNode.sliderStyle,
          canvasMode: childNode.canvasMode,
          options: childNode.options,
          children: newStackChildren,
        );
        rows[r] = LuaGuiNode(
          type: row.type,
          orientation: row.orientation,
          align: row.align,
          crossAlign: row.crossAlign,
          children: newRowChildren,
        );
        setState(() {
          _selectedStackChildIndex = s + 1;
        });
      } else {
        final node = row.children[c];
        final newChildren = List<LuaGuiNode>.from(row.children)..insert(c + 1, node);
        rows[r] = LuaGuiNode(
          type: row.type,
          orientation: row.orientation,
          align: row.align,
          crossAlign: row.crossAlign,
          children: newChildren,
        );
        setState(() {
          _selectedChildIndex = c + 1;
          _selectedStackChildIndex = null;
        });
      }
    } else {
      rows.insert(r + 1, row);
      setState(() {
        _selectedRowIndex = r + 1;
        _selectedChildIndex = null;
        _selectedStackChildIndex = null;
      });
    }

    _applyPanelChanges(LuaGuiPanelDef(
      title: _panel.title,
      subtitle: _panel.subtitle,
      style: _panel.style,
      backgroundStyle: _panel.backgroundStyle,
      backgroundColor: _panel.backgroundColor,
      accentColor: _panel.accentColor,
      defaultKnobStyle: _panel.defaultKnobStyle,
      children: rows,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final compilation = LuaEngine.compile(widget.scriptCode);
    final availableParams = compilation.params.map((p) => p.name).toList();
    final effectiveTrackColor = widget.target.trackColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Left Widget Palette Drawer
        if (_isPaletteOpen)
          GuiWidgetPaletteDrawer(
            onAddItem: (item) {
              final targetRow = _selectedRowIndex ?? (_panel.children.isNotEmpty ? 0 : -1);
              if (targetRow == -1) {
                _addRow();
                _addWidgetToRow(0, item);
              } else {
                _addWidgetToRow(targetRow, item);
              }
            },
          ),

        // 2. Center Faceplate Designer Canvas Viewport
        Expanded(
          child: Container(
            color: const Color(0xFF0B0D12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Designer Workspace Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF14171F),
                    border: Border(bottom: BorderSide(color: Color(0xFF222836))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(_isPaletteOpen ? Icons.menu_open : Icons.menu, size: 18),
                            tooltip: 'Toggle Widget Toolbox',
                            color: _isPaletteOpen ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                            onPressed: () => setState(() => _isPaletteOpen = !_isPaletteOpen),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: EatsTheme.accentGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: EatsTheme.accentGreen.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_note, size: 14, color: Color(0xFF00FF9D)),
                                const SizedBox(width: 4),
                                Text(
                                  'VISUAL DESIGN STUDIO',
                                  style: EatsTheme.getDisplayFontStyle(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF00FF9D)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('ADD ROW'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F2633),
                              foregroundColor: EatsTheme.primaryCyan,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _addRow,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(_isInspectorOpen ? Icons.tune : Icons.tune_outlined, size: 18),
                            tooltip: 'Toggle Properties Inspector',
                            color: _isInspectorOpen ? EatsTheme.accentGreen : EatsTheme.textMuted,
                            onPressed: () => setState(() => _isInspectorOpen = !_isInspectorOpen),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Faceplate Canvas Viewport
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _buildDesignerFaceplate(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Right Properties Inspector Sidebar
        if (_isInspectorOpen)
          GuiInspectorSidebar(
            panel: _panel,
            selectedRowIndex: _selectedRowIndex,
            selectedChildIndex: _selectedChildIndex,
            selectedStackChildIndex: _selectedStackChildIndex,
            trackColor: effectiveTrackColor,
            availableParams: availableParams,
            onPanelUpdated: _applyPanelChanges,
            onAddChildToStack: _addWidgetToStack,
            onDeleteSelected: _deleteSelected,
            onDuplicateSelected: _duplicateSelected,
          ),
      ],
    );
  }

  Widget _buildDesignerFaceplate() {
    final bgStyle = _panel.backgroundStyle;
    final isMinimal = bgStyle == PanelBackgroundStyle.minimalWhite;
    final isSilver = bgStyle == PanelBackgroundStyle.silver;
    final isSnes = bgStyle == PanelBackgroundStyle.snes;
    final isGrunge = bgStyle == PanelBackgroundStyle.grunge;
    final textureType = DawTextureEngine.mapStyleToTexture(bgStyle);

    Color chassisBg = const Color(0xFF14171E);
    if (_panel.backgroundColor != null) {
      chassisBg = _panel.backgroundColor!;
    } else if (isMinimal) {
      chassisBg = const Color(0xFFECEEF2);
    } else if (isSilver) {
      chassisBg = const Color(0xFFD4D0C5);
    } else if (isSnes) {
      chassisBg = const Color(0xFFD8D6CD);
    } else if (isGrunge) {
      chassisBg = const Color(0xFF1A1412);
    } else if (bgStyle == PanelBackgroundStyle.walnut) {
      chassisBg = const Color(0xFF3B2414);
    } else if (bgStyle == PanelBackgroundStyle.mahogany) {
      chassisBg = const Color(0xFF451912);
    } else if (bgStyle == PanelBackgroundStyle.blondePine) {
      chassisBg = const Color(0xFFC7B591);
    } else if (bgStyle == PanelBackgroundStyle.rosewood) {
      chassisBg = const Color(0xFF211310);
    } else if (bgStyle == PanelBackgroundStyle.brushedSteel || bgStyle == PanelBackgroundStyle.brushedSteelVert) {
      chassisBg = const Color(0xFF383D47);
    } else if (bgStyle == PanelBackgroundStyle.tolex) {
      chassisBg = const Color(0xFF161618);
    } else if (bgStyle == PanelBackgroundStyle.carbon) {
      chassisBg = const Color(0xFF121418);
    }

    final isLight = isMinimal || isSilver || isSnes || bgStyle == PanelBackgroundStyle.blondePine || (chassisBg.computeLuminance() > 0.5);
    final effectiveTrackColor = widget.target.trackColor;
    final accent = _panel.accentColor ??
        (isMinimal
            ? const Color(0xFF1E1E24)
            : (isSnes ? const Color(0xFFE52521) : effectiveTrackColor));

    Widget faceplate = DawTexturedContainer(
      texture: textureType,
      textureRotation: _panel.textureRotation,
      textureScale: _panel.textureScale,
      color: chassisBg,
      sideCheeks: _panel.sideCheeks,
      borderRadius: BorderRadius.circular(_panel.cornerRadius ?? (isMinimal ? 16.0 : 10.0)),
      border: Border.all(
        color: isMinimal
            ? const Color(0xFFD8DBE2)
            : (isSilver
                ? const Color(0xFF9E9A8A)
                : (isSnes ? const Color(0xFFE52521) : accent.withOpacity(0.5))),
        width: 2.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chassis Faceplate Header
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedRowIndex = null;
                _selectedChildIndex = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isLight ? Colors.black.withOpacity(0.04) : Colors.black26,
                border: Border(
                  bottom: BorderSide(
                    color: isLight ? Colors.black12 : Colors.white10,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: accent.withOpacity(0.6), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _panel.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: isLight ? const Color(0xFF1B1A17) : Colors.white,
                          ),
                        ),
                        if (_panel.subtitle != null && _panel.subtitle!.isNotEmpty)
                          Text(
                            _panel.subtitle!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isLight ? const Color(0xFF555048) : Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_selectedRowIndex == null && _selectedChildIndex == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accent, width: 1),
                      ),
                      child: Text(
                        'CHASSIS SELECTED',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accent),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Faceplate Content Area
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (_panel.children.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.dashboard_customize_outlined, size: 32, color: Colors.white38),
                        const SizedBox(height: 8),
                        const Text(
                          'No Rows Added Yet',
                          style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Click "+ ADD ROW" to start designing your custom synthesizer faceplate.',
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('CREATE FIRST ROW'),
                          onPressed: _addRow,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  for (int r = 0; r < _panel.children.length; r++) ...[
                    _buildRowDesigner(r, _panel.children[r], isLight, accent),
                    if (r < _panel.children.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return faceplate;
  }

  Widget _buildRowDesigner(int rowIndex, LuaGuiNode rowNode, bool isLight, Color accent) {
    final isRowSelected = _selectedRowIndex == rowIndex && _selectedChildIndex == null;
    final rowTextureType = rowNode.backgroundStyle != null ? DawTextureEngine.mapStyleToTexture(rowNode.backgroundStyle!) : null;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is GuiPaletteItem) {
          _addWidgetToRow(rowIndex, data);
        } else if (data is GuiWidgetLocation) {
          _moveWidget(data, toRow: rowIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropHovered = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedRowIndex = rowIndex;
              _selectedChildIndex = null;
              _selectedStackChildIndex = null;
            });
          },
          child: DawTexturedContainer(
            texture: rowTextureType,
            textureRotation: rowNode.textureRotation ?? 0.0,
            textureScale: rowNode.textureScale ?? 1.0,
            color: isDropHovered
                ? EatsTheme.primaryCyan.withOpacity(0.18)
                : (isRowSelected
                    ? (isLight ? Colors.blue.withOpacity(0.08) : Colors.blueAccent.withOpacity(0.12))
                    : (rowNode.backgroundColor ?? (isLight ? Colors.black.withOpacity(0.03) : Colors.black.withOpacity(0.2)))),
            padding: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDropHovered
                  ? EatsTheme.primaryCyan
                  : (isRowSelected ? Colors.blueAccent : (isLight ? Colors.black12 : Colors.white12)),
              width: (isDropHovered || isRowSelected) ? 1.5 : 1.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row Management Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.drag_indicator, size: 14, color: isLight ? Colors.black38 : Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          rowNode.type == LuaGuiNodeType.group
                              ? 'GROUP: ${(rowNode.label ?? "SECTION").toUpperCase()} (${rowNode.children.length} items)'
                              : 'ROW ${rowIndex + 1} (${rowNode.children.length} widgets)',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: rowNode.accentColor ?? (isLight ? Colors.black54 : Colors.white54),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (rowIndex > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 14),
                            tooltip: 'Move Row Up',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            onPressed: () => _moveRow(rowIndex, rowIndex - 1),
                          ),
                        if (rowIndex < _panel.children.length - 1)
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 14),
                            tooltip: 'Move Row Down',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            onPressed: () => _moveRow(rowIndex, rowIndex + 1),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 14),
                          tooltip: 'Delete Row',
                          color: Colors.redAccent.withOpacity(0.8),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          onPressed: () => _deleteRow(rowIndex),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row Children
                if (rowNode.children.isEmpty) ...[
                  Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                    ),
                    child: Text(
                      'Empty Row • Drag or click widgets in toolbox to add here',
                      style: TextStyle(fontSize: 10, color: isLight ? Colors.black38 : Colors.white38),
                    ),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: _parseWrapAlignment(rowNode.align),
                    crossAxisAlignment: _parseWrapCrossAlignment(rowNode.crossAlign),
                    children: [
                      for (int c = 0; c < rowNode.children.length; c++) ...[
                        _buildWidgetDesignerSlot(rowIndex, c, rowNode.children[c], isLight, accent),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWidgetDesignerSlot(int rowIndex, int childIndex, LuaGuiNode node, bool isLight, Color accent) {
    if (node.type == LuaGuiNodeType.column || node.type == LuaGuiNodeType.group) {
      return _buildStackDesignerSlot(rowIndex, childIndex, node, isLight, accent);
    }

    final isSelected = _selectedRowIndex == rowIndex && _selectedChildIndex == childIndex && _selectedStackChildIndex == null;

    final widgetSlot = GestureDetector(
      onTap: () {
        setState(() {
          _selectedRowIndex = rowIndex;
          _selectedChildIndex = childIndex;
          _selectedStackChildIndex = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? EatsTheme.primaryCyan.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? EatsTheme.primaryCyan : Colors.transparent,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.4), blurRadius: 8)]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _renderMockWidget(node, isLight, accent),

            if (isSelected)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );

    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is GuiPaletteItem) {
          _addWidgetToRow(rowIndex, data, insertIndex: childIndex);
        } else if (data is GuiWidgetLocation) {
          _moveWidget(data, toRow: rowIndex, toChild: childIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Draggable<GuiWidgetLocation>(
          data: GuiWidgetLocation(rowIndex: rowIndex, childIndex: childIndex),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2430),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: EatsTheme.primaryCyan, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 10),
                  ],
                ),
                child: _renderMockWidget(node, isLight, accent),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: widgetSlot),
          child: Container(
            decoration: isHovered
                ? BoxDecoration(
                    border: Border.all(color: EatsTheme.primaryCyan, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: widgetSlot,
          ),
        );
      },
    );
  }

  Widget _buildStackDesignerSlot(int rowIndex, int childIndex, LuaGuiNode node, bool isLight, Color accent) {
    final isStackSelected = _selectedRowIndex == rowIndex && _selectedChildIndex == childIndex && _selectedStackChildIndex == null;
    final isMinimal = _panel.backgroundStyle == PanelBackgroundStyle.minimalWhite || node.backgroundStyle == PanelBackgroundStyle.minimalWhite;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is GuiPaletteItem) {
          _addWidgetToStack(rowIndex, childIndex, data);
        } else if (data is GuiWidgetLocation) {
          _moveWidget(data, toRow: rowIndex, toChild: childIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedRowIndex = rowIndex;
              _selectedChildIndex = childIndex;
              _selectedStackChildIndex = null;
            });
          },
          child: Container(
            padding: EdgeInsets.all(isMinimal ? 10 : 6),
            decoration: BoxDecoration(
              color: isHovered
                  ? EatsTheme.primaryCyan.withOpacity(0.2)
                  : (isStackSelected
                      ? EatsTheme.primaryCyan.withOpacity(0.12)
                      : (isMinimal
                          ? const Color(0xFFFBFBFC)
                          : (isLight ? Colors.black.withOpacity(0.04) : Colors.black.withOpacity(0.2)))),
              borderRadius: BorderRadius.circular(isMinimal ? 16 : 6),
              border: Border.all(
                color: isHovered
                    ? EatsTheme.primaryCyan
                    : (isStackSelected
                        ? EatsTheme.primaryCyan
                        : (isMinimal ? const Color(0xFFE4E7EE) : (isLight ? Colors.black26 : Colors.white24))),
                width: (isHovered || isStackSelected) ? 2.0 : 1.0,
              ),
              boxShadow: (isMinimal && !isHovered && !isStackSelected)
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: _parseMainAxisAlignment(node.align),
              crossAxisAlignment: _parseCrossAxisAlignment(node.crossAlign),
              children: [
                // Stack Header & Add Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_column, size: 12, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'STACK (${node.children.length})',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: accent),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<GuiPaletteItem>(
                      tooltip: 'Add item into this stack',
                      color: const Color(0xFF1E2430),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      icon: Icon(Icons.add_circle_outline, size: 14, color: EatsTheme.accentGreen),
                      onSelected: (item) => _addWidgetToStack(rowIndex, childIndex, item),
                      itemBuilder: (context) => GuiWidgetPalette.items
                          .where((i) => i.id != 'column')
                          .map((i) => PopupMenuItem(
                                value: i,
                                child: Row(
                                  children: [
                                    Icon(i.icon, size: 14, color: EatsTheme.accentGreen),
                                    const SizedBox(width: 8),
                                    Text(i.title, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Stack Children
                if (node.children.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('Drop or + Add widgets', style: TextStyle(fontSize: 8.5, color: isLight ? Colors.black38 : Colors.white38)),
                  ),
                ] else ...[
                  for (int sc = 0; sc < node.children.length; sc++) ...[
                    _buildStackChildSlot(rowIndex, childIndex, sc, node.children[sc], isLight, accent),
                    if (sc < node.children.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackChildSlot(
    int rowIndex,
    int childIndex,
    int stackChildIndex,
    LuaGuiNode childNode,
    bool isLight,
    Color accent,
  ) {
    final isSelected = _selectedRowIndex == rowIndex &&
        _selectedChildIndex == childIndex &&
        _selectedStackChildIndex == stackChildIndex;

    final childSlot = GestureDetector(
      onTap: () {
        setState(() {
          _selectedRowIndex = rowIndex;
          _selectedChildIndex = childIndex;
          _selectedStackChildIndex = stackChildIndex;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? EatsTheme.primaryCyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? EatsTheme.primaryCyan : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: _renderMockWidget(childNode, isLight, accent),
      ),
    );

    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is GuiPaletteItem) {
          _addWidgetToStack(rowIndex, childIndex, data, insertIndex: stackChildIndex);
        } else if (data is GuiWidgetLocation) {
          _moveWidget(data, toRow: rowIndex, toChild: childIndex, toStackChild: stackChildIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Draggable<GuiWidgetLocation>(
          data: GuiWidgetLocation(rowIndex: rowIndex, childIndex: childIndex, stackChildIndex: stackChildIndex),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2430),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EatsTheme.primaryCyan, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 8),
                  ],
                ),
                child: _renderMockWidget(childNode, isLight, accent),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: childSlot),
          child: Container(
            decoration: isHovered
                ? BoxDecoration(
                    border: Border.all(color: EatsTheme.primaryCyan, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: childSlot,
          ),
        );
      },
    );
  }

  Widget _renderMockWidget(LuaGuiNode node, bool isLight, Color accent) {
    switch (node.type) {
      case LuaGuiNodeType.column:
      case LuaGuiNodeType.group:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isLight ? Colors.black.withOpacity(0.04) : Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: node.children.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Empty Stack', style: TextStyle(fontSize: 8.5, color: isLight ? Colors.black38 : Colors.white38)),
                    )
                  ]
                : node.children
                    .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: _renderMockWidget(c, isLight, accent),
                        ))
                    .toList(),
          ),
        );

      case LuaGuiNodeType.knob:
        return SkeuomorphicHardwareKnob(
          label: node.label ?? (node.param ?? 'KNOB'),
          showLabelText: node.showLabel,
          showValueText: node.showValue,
          value: 0.5,
          min: 0.0,
          max: 1.0,
          defaultValue: 0.5,
          size: node.size ?? 52,
          knobStyle: node.knobStyle,
          accentColor: accent,
          onChanged: (_) {},
        );

      case LuaGuiNodeType.slider:
      case LuaGuiNodeType.fader:
        final isH = node.orientation == 'horizontal';
        return SizedBox(
          width: isH ? (node.width ?? 320) : 60,
          height: isH ? 50 : (node.height ?? 120),
          child: SkeuomorphicHardwareSlider(
            label: node.showLabel ? (node.label ?? (node.param ?? 'SLIDER')) : null,
            value: 0.5,
            min: 0.0,
            max: 1.0,
            defaultValue: 0.5,
            orientation: node.orientation == 'horizontal' ? Axis.horizontal : Axis.vertical,
            style: node.sliderStyle,
            onChanged: (_) {},
          ),
        );

      case LuaGuiNodeType.switchToggle:
        return SkeuomorphicHardwareSwitch(
          label: node.showLabel ? (node.label ?? (node.param ?? 'SWITCH')) : null,
          value: false,
          orientation: node.orientation == 'vertical' ? Axis.vertical : Axis.horizontal,
          onChanged: (_) {},
        );

      case LuaGuiNodeType.button:
        return SkeuomorphicHardwareButton(
          label: node.label ?? 'TRIGGER',
          width: node.width ?? 90,
          height: node.height ?? 36,
          onTap: () {},
        );

      case LuaGuiNodeType.listBox:
        return Container(
          width: node.width ?? 140,
          height: node.height ?? 75,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (node.showLabel) ...[
                Text(
                  (node.label ?? 'CHOICE').toUpperCase(),
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: accent),
                ),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: (node.options.isNotEmpty ? node.options : const ['Item 1', 'Item 2', 'Item 3'])
                      .map((opt) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              opt,
                              style: const TextStyle(fontSize: 9.5, color: Colors.white70, fontFamily: 'monospace'),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        );

      case LuaGuiNodeType.nixie:
        return GlowingNixieDisplay(
          label: node.label ?? 'NIXIE',
          showLabel: node.showLabel,
          valueText: '120.0',
          unit: node.unit ?? 'Hz',
          width: node.width ?? 110,
          glowColor: accent,
        );

      case LuaGuiNodeType.oscilloscope:
      case LuaGuiNodeType.spectrum:
        return Container(
          width: node.width ?? 320,
          height: node.height ?? 140,
          decoration: BoxDecoration(
            color: const Color(0xFF090D0A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            node.type == LuaGuiNodeType.spectrum ? 'SPECTRUM FFT' : 'OSCILLOSCOPE',
            style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: accent),
          ),
        );

      case LuaGuiNodeType.spaceVisualizer:
        return SizedBox(
          width: 280,
          height: 140,
          child: SpaceVisualizerWidget(
            params: AcousticSpaceParams(
              name: 'Room Preview',
              width: 15.0,
              length: 25.0,
              height: 10.0,
            ),
            height: 140,
          ),
        );

      case LuaGuiNodeType.waveshaperCanvas:
        return const SizedBox(
          width: 320,
          height: 140,
          child: WaveshaperCanvasWidget(shapeType: 0, tension: 0.0),
        );

      case LuaGuiNodeType.canvas:
        return Container(
          width: node.width ?? 340,
          height: node.height ?? 180,
          decoration: BoxDecoration(
            color: const Color(0xFF090D14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
          ),
          child: Stack(
            children: [
              CustomPaint(
                size: Size(node.width ?? 340, node.height ?? 180),
                painter: _MockGridPainter(accent: accent),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.brush_outlined, size: 22, color: accent),
                    const SizedBox(height: 4),
                    Text(
                      'PROGRAMMABLE 2D CANVAS',
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'function .draw(canvas, w, h, params, time)',
                      style: TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: EatsTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case LuaGuiNodeType.divider:
        return Container(width: 1.5, height: 50, color: isLight ? Colors.black26 : Colors.white24);

      case LuaGuiNodeType.row:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: _parseWrapAlignment(node.align),
          crossAxisAlignment: _parseWrapCrossAlignment(node.crossAlign),
          children: [
            for (final child in node.children)
              _renderMockWidget(child, isLight, node.accentColor ?? accent),
          ],
        );

      case LuaGuiNodeType.column:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: _parseMainAxisAlignment(node.align),
          crossAxisAlignment: _parseCrossAxisAlignment(node.crossAlign),
          children: [
            for (final child in node.children)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: _renderMockWidget(child, isLight, node.accentColor ?? accent),
              ),
          ],
        );

      case LuaGuiNodeType.group:
        final groupAccent = node.accentColor ?? accent;
        return Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isLight ? Colors.black.withOpacity(0.04) : Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: groupAccent.withOpacity(0.4), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node.label != null) ...[
                Text(
                  node.label!.toUpperCase(),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: groupAccent),
                ),
                const SizedBox(height: 6),
              ],
              for (final child in node.children)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: _renderMockWidget(child, isLight, groupAccent),
                ),
            ],
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(node.label ?? node.type.name.toUpperCase(), style: TextStyle(fontSize: 10, color: isLight ? Colors.black87 : Colors.white70)),
        );
    }
  }

  WrapAlignment _parseWrapAlignment(String align) {
    switch (align.toLowerCase()) {
      case 'space_between':
      case 'spacebetween':
        return WrapAlignment.spaceBetween;
      case 'space_evenly':
      case 'spaceevenly':
        return WrapAlignment.spaceEvenly;
      case 'center':
        return WrapAlignment.center;
      case 'start':
      case 'left':
        return WrapAlignment.start;
      case 'end':
      case 'right':
        return WrapAlignment.end;
      case 'space_around':
      case 'spacearound':
      default:
        return WrapAlignment.spaceAround;
    }
  }

  WrapCrossAlignment _parseWrapCrossAlignment(String align) {
    switch (align.toLowerCase()) {
      case 'start':
      case 'top':
      case 'left':
        return WrapCrossAlignment.start;
      case 'end':
      case 'bottom':
      case 'right':
        return WrapCrossAlignment.end;
      case 'center':
      default:
        return WrapCrossAlignment.center;
    }
  }

  MainAxisAlignment _parseMainAxisAlignment(String align) {
    switch (align.toLowerCase()) {
      case 'space_between':
      case 'spacebetween':
        return MainAxisAlignment.spaceBetween;
      case 'space_evenly':
      case 'spaceevenly':
        return MainAxisAlignment.spaceEvenly;
      case 'center':
        return MainAxisAlignment.center;
      case 'start':
      case 'left':
      case 'top':
        return MainAxisAlignment.start;
      case 'end':
      case 'right':
      case 'bottom':
        return MainAxisAlignment.end;
      case 'space_around':
      case 'spacearound':
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String align) {
    switch (align.toLowerCase()) {
      case 'start':
      case 'top':
      case 'left':
        return CrossAxisAlignment.start;
      case 'end':
      case 'bottom':
      case 'right':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'center':
      default:
        return CrossAxisAlignment.center;
    }
  }
}

class _MockGridPainter extends CustomPainter {
  final Color accent;
  _MockGridPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accent.withOpacity(0.08)
      ..strokeWidth = 1.0;
    const cols = 8;
    const rows = 6;
    final dx = size.width / cols;
    final dy = size.height / rows;
    for (int c = 1; c < cols; c++) {
      canvas.drawLine(Offset(c * dx, 0), Offset(c * dx, size.height), p);
    }
    for (int r = 1; r < rows; r++) {
      canvas.drawLine(Offset(0, r * dy), Offset(size.width, r * dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
