import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../eatscript/eat_gui_model.dart';
import '../../theme/eats_theme.dart';
import '../vector/built_in_vector_skins.dart';
import '../vector/vector_skin_model.dart';
import '../hardware/eat_hardware_knob_model.dart';
import '../hardware/eat_hardware_scale.dart';
import 'gui_widget_palette.dart';

class GuiInspectorSidebar extends StatefulWidget {
  final LuaGuiPanelDef panel;
  final int? selectedRowIndex;
  final int? selectedChildIndex;
  final int? selectedStackChildIndex;
  final Color? trackColor;
  final List<String> availableParams;
  final void Function(LuaGuiPanelDef updatedPanel) onPanelUpdated;
  final void Function(int rowIndex, int childIndex, GuiPaletteItem item)? onAddChildToStack;
  final VoidCallback onDeleteSelected;
  final VoidCallback onDuplicateSelected;

  const GuiInspectorSidebar({
    super.key,
    required this.panel,
    this.selectedRowIndex,
    this.selectedChildIndex,
    this.selectedStackChildIndex,
    this.trackColor,
    required this.availableParams,
    required this.onPanelUpdated,
    this.onAddChildToStack,
    required this.onDeleteSelected,
    required this.onDuplicateSelected,
  });

  @override
  State<GuiInspectorSidebar> createState() => _GuiInspectorSidebarState();
}

class _GuiInspectorSidebarState extends State<GuiInspectorSidebar> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _labelController;
  late TextEditingController _unitController;
  late TextEditingController _svgController;
  late TextEditingController _chassisHexController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  String _getChassisDisplayText(LuaGuiPanelDef panel) {
    if (panel.backgroundColor != null) {
      return '#${panel.backgroundColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    }
    switch (panel.backgroundStyle) {
      case PanelBackgroundStyle.dark:
        return 'dark';
      case PanelBackgroundStyle.silver:
        return 'silver';
      case PanelBackgroundStyle.grunge:
        return 'grunge';
      case PanelBackgroundStyle.snes:
        return 'snes';
      case PanelBackgroundStyle.minimalWhite:
        return 'minimal_white';
      case PanelBackgroundStyle.walnut:
        return 'walnut';
      case PanelBackgroundStyle.mahogany:
        return 'mahogany';
      case PanelBackgroundStyle.blondePine:
        return 'blonde_pine';
      case PanelBackgroundStyle.rosewood:
        return 'rosewood';
      case PanelBackgroundStyle.brushedSteel:
        return 'brushed_steel';
      case PanelBackgroundStyle.brushedSteelVert:
        return 'brushed_steel_vert';
      case PanelBackgroundStyle.matteMetal:
        return 'matte_metal';
      case PanelBackgroundStyle.tolex:
        return 'tolex';
      case PanelBackgroundStyle.carbon:
        return 'carbon';
      case PanelBackgroundStyle.mesh:
        return 'mesh';
      case PanelBackgroundStyle.pcbGreen:
        return 'pcb_green';
      default:
        return 'dark';
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.panel.title);
    _subtitleController = TextEditingController(text: widget.panel.subtitle ?? '');
    _svgController = TextEditingController(text: widget.panel.backgroundSvg ?? '');
    _chassisHexController = TextEditingController(text: _getChassisDisplayText(widget.panel));

    final selectedNode = _getSelectedNode();
    _labelController = TextEditingController(text: selectedNode?.label ?? '');
    _unitController = TextEditingController(text: selectedNode?.unit ?? '');
  }

  @override
  void didUpdateWidget(covariant GuiInspectorSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.panel.title != widget.panel.title) {
      _titleController.text = widget.panel.title;
    }
    if (oldWidget.panel.subtitle != widget.panel.subtitle) {
      _subtitleController.text = widget.panel.subtitle ?? '';
    }
    if (oldWidget.panel.backgroundSvg != widget.panel.backgroundSvg) {
      _svgController.text = widget.panel.backgroundSvg ?? '';
    }
    if (oldWidget.panel.backgroundColor != widget.panel.backgroundColor ||
        oldWidget.panel.backgroundStyle != widget.panel.backgroundStyle) {
      final expectedText = _getChassisDisplayText(widget.panel);
      if (_chassisHexController.text.trim().toLowerCase() != expectedText.toLowerCase()) {
        _chassisHexController.text = expectedText;
      }
    }

    final selectedNode = _getSelectedNode();
    if (selectedNode != null) {
      _labelController.text = selectedNode.label ?? '';
      _unitController.text = selectedNode.unit ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _labelController.dispose();
    _unitController.dispose();
    _svgController.dispose();
    _chassisHexController.dispose();
    super.dispose();
  }

  LuaGuiNode? _getSelectedNode() {
    final r = widget.selectedRowIndex;
    final c = widget.selectedChildIndex;
    final s = widget.selectedStackChildIndex;
    if (r != null && r >= 0 && r < widget.panel.children.length) {
      final rowNode = widget.panel.children[r];
      if (c != null && c >= 0 && c < rowNode.children.length) {
        final childNode = rowNode.children[c];
        if (s != null &&
            (childNode.type == LuaGuiNodeType.column || childNode.type == LuaGuiNodeType.group || childNode.type == LuaGuiNodeType.row) &&
            s >= 0 &&
            s < childNode.children.length) {
          return childNode.children[s];
        }
        return childNode;
      }
      return rowNode;
    }
    return null;
  }

  void _updateSelectedNode(LuaGuiNode updatedNode) {
    final r = widget.selectedRowIndex;
    final c = widget.selectedChildIndex;
    final s = widget.selectedStackChildIndex;
    if (r == null || r < 0 || r >= widget.panel.children.length) return;

    final rows = List<LuaGuiNode>.from(widget.panel.children);
    final rowNode = rows[r];

    if (c != null && c >= 0 && c < rowNode.children.length) {
      final childNode = rowNode.children[c];
      final newChildren = List<LuaGuiNode>.from(rowNode.children);
      if (s != null &&
          (childNode.type == LuaGuiNodeType.column || childNode.type == LuaGuiNodeType.group || childNode.type == LuaGuiNodeType.row) &&
          s >= 0 &&
          s < childNode.children.length) {
        final newStackChildren = List<LuaGuiNode>.from(childNode.children);
        newStackChildren[s] = updatedNode;
        newChildren[c] = childNode.copyWith(children: newStackChildren);
      } else {
        newChildren[c] = updatedNode;
      }
      rows[r] = rowNode.copyWith(children: newChildren);
    } else {
      rows[r] = updatedNode;
    }

    widget.onPanelUpdated(widget.panel.copyWith(children: rows));
  }

  @override
  Widget build(BuildContext context) {
    final selectedNode = _getSelectedNode();
    final isWidgetSelected = selectedNode != null && widget.selectedChildIndex != null;
    final isRowSelected = widget.selectedRowIndex != null && widget.selectedChildIndex == null && selectedNode != null;

    final effectiveTrackColor = widget.trackColor ?? const Color(0xFF00E5FF);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF14171F),
        border: Border(left: BorderSide(color: Color(0xFF2B3245))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF0F1218),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, size: 16, color: EatsTheme.accentGreen),
                    const SizedBox(width: 8),
                    Text(
                      isRowSelected
                          ? 'ROW PROPERTIES'
                          : (isWidgetSelected
                              ? (widget.selectedStackChildIndex != null ? 'STACK ITEM PROPERTIES' : 'WIDGET PROPERTIES')
                              : 'PANEL PROPERTIES'),
                      style: EatsTheme.getDisplayFontStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.textLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (isRowSelected) ...[
                  _buildRowAlignmentInspector(selectedNode!, widget.selectedRowIndex!),
                ] else if (!isWidgetSelected) ...[
                  // --- PANEL SETTINGS ---
                  _buildSectionHeader('PANEL IDENTITY'),
                  const SizedBox(height: 6),
                  _buildTextField('Title', _titleController, (v) {
                    widget.onPanelUpdated(widget.panel.copyWith(
                      title: v.isEmpty ? 'CUSTOM INSTRUMENT' : v,
                    ));
                  }),
                  const SizedBox(height: 8),
                  _buildTextField('Subtitle', _subtitleController, (v) {
                    widget.onPanelUpdated(widget.panel.copyWith(
                      subtitle: v,
                    ));
                  }),
                  const SizedBox(height: 14),

                  _buildSectionHeader('CHASSIS & THEME'),
                  const SizedBox(height: 6),
                  _buildDropdown<PanelBackgroundStyle>(
                    label: 'Background Theme / Texture',
                    value: widget.panel.backgroundStyle,
                    items: const [
                      DropdownMenuItem(value: PanelBackgroundStyle.dark, child: Text('Dark Studio (Anodized)')),
                      DropdownMenuItem(value: PanelBackgroundStyle.silver, child: Text('Silver Brushed (TB-303)')),
                      DropdownMenuItem(value: PanelBackgroundStyle.grunge, child: Text('Industrial Grunge / Weathered')),
                      DropdownMenuItem(value: PanelBackgroundStyle.snes, child: Text('16-Bit SNES Console Cream')),
                      DropdownMenuItem(value: PanelBackgroundStyle.walnut, child: Text('Vintage Walnut Wood')),
                      DropdownMenuItem(value: PanelBackgroundStyle.mahogany, child: Text('Rich Mahogany Wood')),
                      DropdownMenuItem(value: PanelBackgroundStyle.blondePine, child: Text('Blonde Pine / Nordic Ash')),
                      DropdownMenuItem(value: PanelBackgroundStyle.rosewood, child: Text('Dark Rosewood / Ebony')),
                      DropdownMenuItem(value: PanelBackgroundStyle.brushedSteel, child: Text('Brushed Steel (Horizontal)')),
                      DropdownMenuItem(value: PanelBackgroundStyle.brushedSteelVert, child: Text('Brushed Steel (Vertical)')),
                      DropdownMenuItem(value: PanelBackgroundStyle.matteMetal, child: Text('Anodized Sandblast Metal')),
                      DropdownMenuItem(value: PanelBackgroundStyle.tolex, child: Text('Vintage Tolex Amp Vinyl')),
                      DropdownMenuItem(value: PanelBackgroundStyle.carbon, child: Text('Carbon Fiber Twill Weave')),
                      DropdownMenuItem(value: PanelBackgroundStyle.mesh, child: Text('Perforated Mesh Grille')),
                      DropdownMenuItem(value: PanelBackgroundStyle.minimalWhite, child: Text('Minimalist Matte White (Ceramic)')),
                      DropdownMenuItem(value: PanelBackgroundStyle.custom, child: Text('Custom Hex Color')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onPanelUpdated(widget.panel.copyWith(
                          backgroundStyle: v,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildDropdown<double>(
                    label: 'Texture Grain Rotation',
                    value: widget.panel.textureRotation,
                    items: const [
                      DropdownMenuItem(value: 0.0, child: Text('0° (Horizontal Grain)')),
                      DropdownMenuItem(value: 90.0, child: Text('90° (Vertical Grain)')),
                      DropdownMenuItem(value: 180.0, child: Text('180° (Inverted Horizontal)')),
                      DropdownMenuItem(value: 270.0, child: Text('270° (Inverted Vertical)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onPanelUpdated(widget.panel.copyWith(
                          textureRotation: v,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildDropdown<String>(
                    label: 'Rack Sides & End-Cheeks',
                    value: widget.panel.sideCheeks ?? 'none',
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None (Flush Chassis)')),
                      DropdownMenuItem(value: 'walnut', child: Text('Vintage Walnut (Wood)')),
                      DropdownMenuItem(value: 'mahogany', child: Text('Rich Mahogany (Wood)')),
                      DropdownMenuItem(value: 'blondePine', child: Text('Blonde Pine / Koa (Wood)')),
                      DropdownMenuItem(value: 'rosewood', child: Text('Dark Rosewood (Wood)')),
                      DropdownMenuItem(value: 'brushedSteel', child: Text('Brushed Steel (Metal)')),
                      DropdownMenuItem(value: 'matteMetal', child: Text('Anodized Matte Metal (Metal)')),
                      DropdownMenuItem(value: 'grunge', child: Text('Weathered Patina (Metal)')),
                      DropdownMenuItem(value: 'tolex', child: Text('Vintage Tolex (Amp Vinyl)')),
                      DropdownMenuItem(value: 'carbon', child: Text('Carbon Fiber (Composite)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onPanelUpdated(widget.panel.copyWith(
                          sideCheeks: v == 'none' ? null : v,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildDropdown<double>(
                    label: 'Chassis Corner Radius',
                    value: widget.panel.cornerRadius ?? (widget.panel.sideCheeks != null && widget.panel.sideCheeks != 'none' ? 0.0 : 8.0),
                    items: const [
                      DropdownMenuItem(value: 0.0, child: Text('0px (Flush / Sharp Rack)')),
                      DropdownMenuItem(value: 4.0, child: Text('4px (Subtle Curve)')),
                      DropdownMenuItem(value: 8.0, child: Text('8px (Standard Rounded)')),
                      DropdownMenuItem(value: 12.0, child: Text('12px (Smooth / Modern)')),
                      DropdownMenuItem(value: 16.0, child: Text('16px (Extra Round)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onPanelUpdated(widget.panel.copyWith(
                          cornerRadius: v,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Chassis Color Hex / Theme (e.g. #24211D, dark, silver)',
                          _chassisHexController,
                          (v) {
                            final clean = v.trim().toLowerCase();
                            if (clean == 'dark') {
                              widget.onPanelUpdated(widget.panel.copyWith(
                                backgroundStyle: PanelBackgroundStyle.dark,
                                backgroundColor: null,
                              ));
                              return;
                            }
                            final bgStyle = LuaGuiNode.parseBackgroundStyle(clean);
                            if (clean != 'dark' && clean.isNotEmpty && !clean.startsWith('#') && bgStyle != PanelBackgroundStyle.dark) {
                              widget.onPanelUpdated(widget.panel.copyWith(
                                backgroundStyle: bgStyle,
                                backgroundColor: null,
                              ));
                              return;
                            }
                            final col = LuaGuiNode.parseColor(v);
                            if (col != null && !LuaGuiNode.isTrackColor(col)) {
                              widget.onPanelUpdated(widget.panel.copyWith(
                                backgroundStyle: PanelBackgroundStyle.custom,
                                backgroundColor: col,
                              ));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: InkWell(
                          onTap: () {
                            _showColorPickerDialog(
                              context: context,
                              title: 'Chassis Background Color',
                              currentColor: widget.panel.backgroundColor,
                              defaultColor: EatsTheme.panelBackground,
                              onColorChanged: (col) {
                                if (col != null) {
                                  _chassisHexController.text = _hex(col);
                                  widget.onPanelUpdated(widget.panel.copyWith(
                                    backgroundStyle: PanelBackgroundStyle.custom,
                                    backgroundColor: col,
                                  ));
                                } else {
                                  _chassisHexController.text = 'dark';
                                  widget.onPanelUpdated(widget.panel.copyWith(
                                    backgroundStyle: PanelBackgroundStyle.dark,
                                    backgroundColor: null,
                                  ));
                                }
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: widget.panel.backgroundColor ?? EatsTheme.panelBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: const Icon(Icons.colorize, size: 14, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _buildDropdown<KnobStyle>(
                    label: 'Default Knob Skin',
                    value: widget.panel.defaultKnobStyle,
                    items: const [
                      DropdownMenuItem(value: KnobStyle.standard, child: Text('Standard Hardware')),
                      DropdownMenuItem(value: KnobStyle.minimalWhite, child: Text('Minimalist Matte White')),
                      DropdownMenuItem(value: KnobStyle.chrome, child: Text('Chrome Fluted (303)')),
                      DropdownMenuItem(value: KnobStyle.vintage, child: Text('Vintage Bakelite')),
                      DropdownMenuItem(value: KnobStyle.snes, child: Text('SNES Console Cream')),
                      DropdownMenuItem(value: KnobStyle.customVector, child: Text('Custom Vector (SVG)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onPanelUpdated(widget.panel.copyWith(
                          defaultKnobStyle: v,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildSectionHeader('ACCENT COLOR'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      widget.onPanelUpdated(widget.panel.copyWith(
                        accentColor: null, // Track Color (auto dynamic)
                      ));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.panel.accentColor == null ? effectiveTrackColor.withOpacity(0.2) : const Color(0xFF1E2430),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: widget.panel.accentColor == null ? effectiveTrackColor : const Color(0xFF2E384D),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: effectiveTrackColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DYNAMIC TRACK ACCENT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: widget.panel.accentColor == null ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                          if (widget.panel.accentColor == null)
                            const Icon(Icons.check, size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Color(0xFF00E5FF),
                      const Color(0xFF00FF9D),
                      const Color(0xFF00E676),
                      const Color(0xFFFFD700),
                      const Color(0xFFFF8C00),
                      const Color(0xFFFF3D00),
                      const Color(0xFFE040FB),
                      const Color(0xFF9C27B0),
                      const Color(0xFF2979FF),
                      const Color(0xFF00B0FF),
                      const Color(0xFF1DE9B6),
                      const Color(0xFFFF4081),
                      const Color(0xFFD6D3C8),
                      const Color(0xFF8D6E63),
                      const Color(0xFF78909C),
                      const Color(0xFF141416),
                    ].map((col) {
                      final isSelected = widget.panel.accentColor?.value == col.value;
                      return InkWell(
                        onTap: () {
                          widget.onPanelUpdated(widget.panel.copyWith(
                            accentColor: col,
                          ));
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.0,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: col.withOpacity(0.6), blurRadius: 6)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  _buildSectionHeader('CHASSIS VECTOR / SVG WATERMARK'),
                  const SizedBox(height: 6),
                  _buildTextField('SVG Path Data', _svgController, (v) {
                    widget.onPanelUpdated(widget.panel.copyWith(
                      backgroundSvg: v.trim().isEmpty ? null : v.trim(),
                    ));
                  }),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'WATERMARK OPACITY',
                          style: EatsTheme.getDisplayFontStyle(fontSize: 9, color: EatsTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(widget.panel.backgroundSvgOpacity * 100).toInt()}%',
                        style: EatsTheme.getDisplayFontStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EatsTheme.accentGold),
                      ),
                    ],
                  ),
                  Slider(
                    value: widget.panel.backgroundSvgOpacity.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    activeColor: EatsTheme.accentGold,
                    onChanged: (v) {
                      widget.onPanelUpdated(widget.panel.copyWith(
                        backgroundSvgOpacity: v,
                      ));
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'STROKE WIDTH',
                          style: EatsTheme.getDisplayFontStyle(fontSize: 9, color: EatsTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(widget.panel.backgroundSvgStrokeWidth ?? 0.75).toStringAsFixed(2)}px',
                        style: EatsTheme.getDisplayFontStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EatsTheme.accentGold),
                      ),
                    ],
                  ),
                  Slider(
                    value: (widget.panel.backgroundSvgStrokeWidth ?? 0.75).clamp(0.1, 4.0),
                    min: 0.1,
                    max: 4.0,
                    divisions: 39,
                    activeColor: EatsTheme.accentGold,
                    onChanged: (v) {
                      widget.onPanelUpdated(widget.panel.copyWith(
                        backgroundSvgStrokeWidth: v,
                      ));
                    },
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildPresetChip('🔥 Fire', 'M 100 220 C 60 220, 20 180, 20 130 C 20 90, 60 50, 80 10 C 90 40, 100 60, 110 50 C 130 30, 140 10, 150 0 C 170 50, 190 90, 190 140 C 190 190, 150 220, 100 220 Z M 100 195 C 120 195, 135 175, 135 145 C 135 115, 115 95, 105 70 C 95 95, 75 115, 75 145 C 75 175, 85 195, 100 195 Z'),
                      _buildPresetChip('🌧 Rain', 'M 60 90 C 45 90, 30 75, 30 60 C 30 45, 42 35, 55 35 C 60 20, 80 10, 105 10 C 130 10, 150 25, 155 45 C 165 45, 175 55, 175 65 C 175 80, 160 90, 145 90 Z M 50 115 L 40 145 M 85 115 L 75 145 M 120 115 L 110 145 M 155 115 L 145 145 M 65 155 L 55 185 M 100 155 L 90 185 M 135 155 L 125 185'),
                      _buildPresetChip('💨 Wind', 'M 10 50 C 70 50, 120 20, 160 20 C 190 20, 210 35, 210 50 C 210 65, 190 80, 170 80 C 145 80, 135 60, 145 45 C 155 35, 175 40, 175 50 M 20 85 C 80 85, 130 65, 165 65 C 195 65, 220 80, 220 95 C 220 110, 200 120, 180 120 C 160 120, 150 105, 160 95 M 5 120 C 65 120, 110 105, 145 105 C 180 105, 200 115, 210 130'),
                      ActionChip(
                        label: const Text('✕ Clear', style: TextStyle(fontSize: 10, color: Colors.white70)),
                        backgroundColor: Colors.white10,
                        onPressed: () {
                          _svgController.clear();
                          widget.onPanelUpdated(widget.panel.copyWith(
                            backgroundSvg: null,
                          ));
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  // --- SELECTED WIDGET / STACK ITEM SETTINGS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: EatsTheme.primaryCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                          ),
                          child: Text(
                            widget.selectedStackChildIndex != null
                                ? '${selectedNode!.type.name.toUpperCase()} (IN STACK)'
                                : selectedNode!.type.name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: EatsTheme.getDisplayFontStyle(fontSize: 9.5, color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Duplicate Widget',
                            color: EatsTheme.textLight,
                            onPressed: widget.onDuplicateSelected,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            tooltip: 'Delete Widget',
                            color: Colors.redAccent,
                            onPressed: widget.onDeleteSelected,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (selectedNode.type == LuaGuiNodeType.column || selectedNode.type == LuaGuiNodeType.group) ...[
                    _buildSectionHeader('STACK ALIGNMENT & DISTRIBUTION'),
                    const SizedBox(height: 6),
                    _buildDropdown<String>(
                      label: 'Vertical Distribution',
                      value: selectedNode.align,
                      items: const [
                        DropdownMenuItem(value: 'top', child: Text('Top Aligned')),
                        DropdownMenuItem(value: 'center', child: Text('Center')),
                        DropdownMenuItem(value: 'bottom', child: Text('Bottom Aligned')),
                        DropdownMenuItem(value: 'space_between', child: Text('Space Between')),
                        DropdownMenuItem(value: 'space_evenly', child: Text('Space Evenly')),
                        DropdownMenuItem(value: 'space_around', child: Text('Space Around')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateSelectedNode(selectedNode.copyWith(align: v));
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDropdown<String>(
                      label: 'Horizontal Cross-Alignment',
                      value: selectedNode.crossAlign,
                      items: const [
                        DropdownMenuItem(value: 'center', child: Text('Center')),
                        DropdownMenuItem(value: 'left', child: Text('Left Aligned')),
                        DropdownMenuItem(value: 'right', child: Text('Right Aligned')),
                        DropdownMenuItem(value: 'stretch', child: Text('Stretch Full Width')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateSelectedNode(selectedNode.copyWith(crossAlign: v));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (selectedNode.type == LuaGuiNodeType.row || selectedNode.type == LuaGuiNodeType.column || selectedNode.type == LuaGuiNodeType.group) ...[
                    _buildSectionHeader('SECTION BACKGROUND & INLAY'),
                    const SizedBox(height: 6),
                    _buildDropdown<String>(
                      label: 'Background Material',
                      value: selectedNode.backgroundStyle != null ? selectedNode.backgroundStyle!.name : 'none',
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None (Inherit Chassis)')),
                        DropdownMenuItem(value: 'walnut', child: Text('Vintage Walnut Wood')),
                        DropdownMenuItem(value: 'mahogany', child: Text('Rich Mahogany Wood')),
                        DropdownMenuItem(value: 'blondePine', child: Text('Blonde Pine / Ash')),
                        DropdownMenuItem(value: 'rosewood', child: Text('Dark Rosewood')),
                        DropdownMenuItem(value: 'brushedSteel', child: Text('Brushed Steel (Horizontal)')),
                        DropdownMenuItem(value: 'brushedSteelVert', child: Text('Brushed Steel (Vertical)')),
                        DropdownMenuItem(value: 'matteMetal', child: Text('Anodized Sandblast Metal')),
                        DropdownMenuItem(value: 'tolex', child: Text('Vintage Tolex Amp Vinyl')),
                        DropdownMenuItem(value: 'carbon', child: Text('Carbon Fiber Weave')),
                        DropdownMenuItem(value: 'mesh', child: Text('Perforated Mesh Grille')),
                        DropdownMenuItem(value: 'silver', child: Text('Silver Brushed (TB-303)')),
                        DropdownMenuItem(value: 'grunge', child: Text('Industrial Grunge')),
                        DropdownMenuItem(value: 'dark', child: Text('Dark Studio Plate')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          final style = v == 'none' ? null : LuaGuiNode.parseBackgroundStyle(v);
                          _updateSelectedNode(selectedNode.copyWith(backgroundStyle: style));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown<double>(
                      label: 'Grain Rotation',
                      value: selectedNode.textureRotation ?? 0.0,
                      items: const [
                        DropdownMenuItem(value: 0.0, child: Text('0° (Horizontal Grain)')),
                        DropdownMenuItem(value: 90.0, child: Text('90° (Vertical Grain)')),
                        DropdownMenuItem(value: 180.0, child: Text('180° (Inverted Horizontal)')),
                        DropdownMenuItem(value: 270.0, child: Text('270° (Inverted Vertical)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateSelectedNode(selectedNode.copyWith(textureRotation: v));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  _buildSectionHeader('VISIBILITY & LABELS'),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    title: const Text('Show Label', style: TextStyle(fontSize: 11, color: Colors.white)),
                    value: selectedNode.showLabel,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: EatsTheme.primaryCyan,
                    onChanged: (v) {
                      _updateSelectedNode(selectedNode.copyWith(showLabel: v ?? true));
                    },
                  ),
                  if (selectedNode.type == LuaGuiNodeType.knob) ...[
                    CheckboxListTile(
                      title: const Text('Show Value Readout', style: TextStyle(fontSize: 11, color: Colors.white)),
                      value: selectedNode.showValue,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: EatsTheme.primaryCyan,
                      onChanged: (v) {
                        _updateSelectedNode(selectedNode.copyWith(showValue: v ?? true));
                      },
                    ),
                  ],
                  const SizedBox(height: 8),

                  _buildTextField('Display Label', _labelController, (v) {
                    _updateSelectedNode(selectedNode.copyWith(label: v));
                  }),
                  const SizedBox(height: 8),

                  _buildTextField('Unit String (e.g. Hz, dB, ms, %)', _unitController, (v) {
                    _updateSelectedNode(selectedNode.copyWith(unit: v));
                  }),
                  const SizedBox(height: 12),

                  if (selectedNode.type == LuaGuiNodeType.switchToggle) ...[
                    _buildSectionHeader('SWITCH PROPERTIES'),
                    const SizedBox(height: 6),
                    _buildDropdown<String>(
                      label: 'Switch Orientation',
                      value: selectedNode.orientation == 'vertical' ? 'vertical' : 'horizontal',
                      items: const [
                        DropdownMenuItem(value: 'horizontal', child: Text('Horizontal Pill')),
                        DropdownMenuItem(value: 'vertical', child: Text('Vertical Slim Switch')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateSelectedNode(selectedNode.copyWith(orientation: v));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  _buildSectionHeader('PARAMETER BINDING'),
                  const SizedBox(height: 6),
                  if (widget.availableParams.isNotEmpty) ...[
                    _buildDropdown<String>(
                      label: 'Bound Lua Parameter',
                      value: widget.availableParams.contains(selectedNode.param) ? selectedNode.param : null,
                      items: widget.availableParams.map((p) {
                        return DropdownMenuItem(value: p, child: Text(p));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          _labelController.text = v.toUpperCase();
                          _updateSelectedNode(selectedNode.copyWith(
                            param: v,
                            label: v.toUpperCase(),
                          ));
                        }
                      },
                    ),
                  ] else ...[
                    _buildTextField('Parameter Name', TextEditingController(text: selectedNode.param ?? ''), (v) {
                      _updateSelectedNode(selectedNode.copyWith(param: v));
                    }),
                  ],
                  const SizedBox(height: 14),

                  if (selectedNode.type == LuaGuiNodeType.knob) ...[
                    _buildSectionHeader('KNOB PROPERTIES'),
                    const SizedBox(height: 6),
                    Text('Knob Diameter: ${(selectedNode.size ?? 52).toInt()}px', style: TextStyle(fontSize: 10, color: EatsTheme.textMuted)),
                    Slider(
                      value: (selectedNode.size ?? 52).clamp(36.0, 76.0),
                      min: 36.0,
                      max: 76.0,
                      divisions: 10,
                      activeColor: EatsTheme.primaryCyan,
                      onChanged: (v) {
                        _updateSelectedNode(selectedNode.copyWith(size: v));
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildDropdown<String>(
                      label: 'Hardware Model Preset',
                      value: selectedNode.knobStyle == KnobStyle.customVector
                          ? 'custom_vector'
                          : _getHardwarePresetName(selectedNode.hardwareKnobStyle),
                      items: const [
                        DropdownMenuItem(value: 'vintage_bakelite', child: Text('Vintage Bakelite (Body 0-10)')),
                        DropdownMenuItem(value: 'cream_fluted', child: Text('Cream Fluted (Pitch Arc)')),
                        DropdownMenuItem(value: 'chrome_fluted', child: Text('Chrome Fluted (303 Bassline)')),
                        DropdownMenuItem(value: 'tb303_potentiometer', child: Text('TB-303 Potentiometer (48-Tooth Sawtooth)')),
                        DropdownMenuItem(value: 'tb303_acid_halo', child: Text('TB-303 Acid Neon Halo (D16 Glow)')),
                        DropdownMenuItem(value: 'tb303_selector', child: Text('TB-303 Rotary Selector (Mode / Wave)')),
                        DropdownMenuItem(value: 'standard_hardware', child: Text('Standard Metallic (Gunmetal/Cyan)')),
                        DropdownMenuItem(value: 'anodized_knurled', child: Text('Anodized Knurled (Head / Sustain)')),
                        DropdownMenuItem(value: 'two_tone_stepped', child: Text('Two-Tone Stepped (Punch / Rattle)')),
                        DropdownMenuItem(value: 'snes_console', child: Text('SNES Console Cream (16-Bit Retro)')),
                        DropdownMenuItem(value: 'minimal_white', child: Text('Minimalist Matte Ceramic (Clean)')),
                        DropdownMenuItem(value: 'encoder', child: Text('Studio Neon LED Encoder')),
                        DropdownMenuItem(value: 'custom_vector', child: Text('Custom Vector (SVG Skin)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          if (v == 'custom_vector') {
                            _updateSelectedNode(selectedNode.copyWith(
                              knobStyle: KnobStyle.customVector,
                              customSkin: selectedNode.customSkin ?? BuiltInVectorSkins.getSkinForKnobStyle(selectedNode.knobStyle),
                            ));
                          } else {
                            EatHardwareKnobStyle hwStyle;
                            switch (v) {
                              case 'tb303_potentiometer':
                                hwStyle = EatHardwareKnobStyle.tb303Potentiometer(accentColor: selectedNode.accentColor);
                                break;
                              case 'tb303_acid_halo':
                                hwStyle = EatHardwareKnobStyle.tb303AcidHalo(accentColor: selectedNode.accentColor);
                                break;
                              case 'tb303_selector':
                                hwStyle = EatHardwareKnobStyle.tb303Selector(accentColor: selectedNode.accentColor);
                                break;
                              case 'standard_hardware':
                                hwStyle = EatHardwareKnobStyle.standardHardware(accentColor: selectedNode.accentColor);
                                break;
                              case 'cream_fluted':
                                hwStyle = EatHardwareKnobStyle.creamFluted(accentColor: selectedNode.accentColor);
                                break;
                              case 'chrome_fluted':
                                hwStyle = EatHardwareKnobStyle.chromeFluted(accentColor: selectedNode.accentColor);
                                break;
                              case 'snes_console':
                                hwStyle = EatHardwareKnobStyle.snesConsole(accentColor: selectedNode.accentColor);
                                break;
                              case 'minimal_white':
                                hwStyle = EatHardwareKnobStyle.minimalWhite(accentColor: selectedNode.accentColor);
                                break;
                              case 'anodized_knurled':
                                hwStyle = EatHardwareKnobStyle.anodizedKnurled(accentColor: selectedNode.accentColor);
                                break;
                              case 'two_tone_stepped':
                                hwStyle = EatHardwareKnobStyle.twoToneStepped(accentColor: selectedNode.accentColor);
                                break;
                              case 'encoder':
                                hwStyle = EatHardwareKnobStyle.illuminatedEncoder(activeColor: selectedNode.accentColor ?? const Color(0xFF00E5FF));
                                break;
                              default:
                                hwStyle = EatHardwareKnobStyle.vintageBakelite(accentColor: selectedNode.accentColor);
                            }
                            _updateSelectedNode(selectedNode.copyWith(
                              knobStyle: KnobStyle.hardwareKnob,
                              hardwareKnobStyle: hwStyle,
                            ));
                          }
                        }
                      },
                    ),
                    if (selectedNode.knobStyle != KnobStyle.customVector) ...[
                      const SizedBox(height: 6),
                      _buildDropdown<String>(
                        label: 'Dial / Scale Graduations',
                        value: _getScalePresetName(selectedNode.hardwareScale ?? (selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite()).scale),
                        items: const [
                          DropdownMenuItem(value: 'zero_to_ten', child: Text('0 to 10 Numbers')),
                          DropdownMenuItem(value: 'clean_ticks', child: Text('Clean Graduation Ticks (10 Ticks)')),
                          DropdownMenuItem(value: 'tb303_dial', child: Text('TB-303 Calibrated (12-O\'clock Block)')),
                          DropdownMenuItem(value: 'low_mid_high', child: Text('Low / Mid / High (Pitch Scale)')),
                          DropdownMenuItem(value: 'sustain_1_to_6', child: Text('1 to 6 (dyn Sustain Scale)')),
                          DropdownMenuItem(value: 'bipolar', child: Text('-5 to +5 Bipolar Center')),
                          DropdownMenuItem(value: 'mode_steps', child: Text('Mode Selector (Classic / Step / Wave...)')),
                          DropdownMenuItem(value: 'none', child: Text('Unmarked / No Ticks')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            final currentStyle = selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite();
                            final tickCol = currentStyle.scale.tickColor ?? selectedNode.dialColor ?? const Color(0xFF1E1E24);
                            final labelCol = currentStyle.scale.labelColor ?? selectedNode.dialColor ?? const Color(0xFF1E1E24);
                            EatScaleGraduation newScale;
                            switch (v) {
                              case 'clean_ticks':
                                newScale = EatScaleGraduation.cleanTicks(tickColor: tickCol, labelColor: labelCol);
                                break;
                              case 'tb303_dial':
                                newScale = EatScaleGraduation.tb303Dial(tickColor: tickCol, labelColor: labelCol);
                                break;
                              case 'low_mid_high':
                                newScale = EatScaleGraduation.lowMidHigh(tickColor: tickCol, labelColor: labelCol);
                                break;
                              case 'sustain_1_to_6':
                                newScale = EatScaleGraduation.sustainOneToSix(tickColor: tickCol, labelColor: labelCol);
                                break;
                              case 'bipolar':
                                newScale = EatScaleGraduation.bipolar(tickColor: tickCol, labelColor: labelCol);
                                break;
                              case 'mode_steps':
                                newScale = EatScaleGraduation.tb303Selector(tickColor: tickCol, labelColor: labelCol);
                                break;
                              case 'none':
                                newScale = const EatScaleGraduation(tickDivisions: 0, labels: []);
                                break;
                              case 'zero_to_ten':
                              default:
                                newScale = EatScaleGraduation.zeroToTen(tickColor: tickCol, labelColor: labelCol);
                                break;
                            }
                            _updateSelectedNode(selectedNode.copyWith(
                              hardwareScale: newScale,
                              hardwareKnobStyle: currentStyle.copyWith(scale: newScale),
                            ));
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildSectionHeader('HARDWARE KNOB COLORS & ACCENTS'),
                      const SizedBox(height: 6),
                      _buildColorTileRow(
                        context: context,
                        label: 'Cap / Disc Color',
                        currentColor: selectedNode.capColor ?? selectedNode.hardwareKnobStyle?.capColor,
                        defaultColor: (selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite()).capColor,
                        onColorChanged: (col) {
                          final currentStyle = selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite();
                          _updateSelectedNode(selectedNode.copyWith(
                            capColor: col,
                            hardwareKnobStyle: col != null ? currentStyle.copyWith(capColor: col) : currentStyle,
                          ));
                        },
                      ),
                      _buildColorTileRow(
                        context: context,
                        label: 'Body / Skirt Color',
                        currentColor: selectedNode.bodyColor ?? selectedNode.hardwareKnobStyle?.bodyColor,
                        defaultColor: (selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite()).bodyColor,
                        onColorChanged: (col) {
                          final currentStyle = selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite();
                          _updateSelectedNode(selectedNode.copyWith(
                            bodyColor: col,
                            hardwareKnobStyle: col != null ? currentStyle.copyWith(bodyColor: col) : currentStyle,
                          ));
                        },
                      ),
                      _buildColorTileRow(
                        context: context,
                        label: 'Indicator / Notch Color',
                        currentColor: selectedNode.indicatorColor ?? selectedNode.hardwareKnobStyle?.indicatorColor,
                        defaultColor: (selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite()).indicatorColor,
                        onColorChanged: (col) {
                          final currentStyle = selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite();
                          _updateSelectedNode(selectedNode.copyWith(
                            indicatorColor: col,
                            hardwareKnobStyle: col != null ? currentStyle.copyWith(indicatorColor: col) : currentStyle,
                          ));
                        },
                      ),
                      _buildColorTileRow(
                        context: context,
                        label: 'Dial / Scale Color',
                        currentColor: selectedNode.dialColor ?? selectedNode.hardwareKnobStyle?.scale.tickColor,
                        defaultColor: (selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite()).scale.tickColor ?? const Color(0xFFE8E5DC),
                        onColorChanged: (col) {
                          final currentStyle = selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite();
                          _updateSelectedNode(selectedNode.copyWith(
                            dialColor: col,
                            hardwareKnobStyle: col != null
                                ? currentStyle.copyWith(scale: currentStyle.scale.copyWith(tickColor: col, labelColor: col))
                                : currentStyle,
                          ));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildSectionHeader('KNOB ANATOMY PROPORTIONS'),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (ctx) {
                          final currentStyle = selectedNode.hardwareKnobStyle ?? EatHardwareKnobStyle.vintageBakelite();
                          final defaultCap = currentStyle.capStyle == EatCapStyle.insetRim ? 0.82 : 0.94;
                          final capRatio = selectedNode.capSize ?? currentStyle.capRadiusRatio ?? defaultCap;
                          final bodyRatio = selectedNode.bodySize ?? currentStyle.skirtRadiusRatio;
                          final indLen = selectedNode.indicatorLength ?? currentStyle.indicatorLength;
                          final indWidth = selectedNode.indicatorWidth ?? currentStyle.indicatorWidth;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Cap Diameter Ratio', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                                  Text('${(capRatio * 100).toInt()}%', style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.white)),
                                ],
                              ),
                              Slider(
                                value: capRatio.clamp(0.50, 0.98),
                                min: 0.50,
                                max: 0.98,
                                divisions: 24,
                                activeColor: EatsTheme.primaryCyan,
                                onChanged: (v) {
                                  _updateSelectedNode(selectedNode.copyWith(
                                    capSize: v,
                                    hardwareKnobStyle: currentStyle.copyWith(capRadiusRatio: v),
                                  ));
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Body / Skirt Fullness', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                                  Text('${(bodyRatio * 100).toInt()}%', style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.white)),
                                ],
                              ),
                              Slider(
                                value: bodyRatio.clamp(1.0, 1.40),
                                min: 1.0,
                                max: 1.40,
                                divisions: 20,
                                activeColor: EatsTheme.primaryCyan,
                                onChanged: (v) {
                                  _updateSelectedNode(selectedNode.copyWith(
                                    bodySize: v,
                                    hardwareKnobStyle: currentStyle.copyWith(skirtRadiusRatio: v),
                                  ));
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Indicator Notch Length', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                                  Text('${(indLen * 100).toInt()}%', style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.white)),
                                ],
                              ),
                              Slider(
                                value: indLen.clamp(0.30, 0.95),
                                min: 0.30,
                                max: 0.95,
                                divisions: 13,
                                activeColor: EatsTheme.primaryCyan,
                                onChanged: (v) {
                                  _updateSelectedNode(selectedNode.copyWith(
                                    indicatorLength: v,
                                    hardwareKnobStyle: currentStyle.copyWith(indicatorLength: v),
                                  ));
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Indicator Notch Width', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                                  Text('${indWidth.toStringAsFixed(1)}px', style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.white)),
                                ],
                              ),
                              Slider(
                                value: indWidth.clamp(1.0, 5.0),
                                min: 1.0,
                                max: 5.0,
                                divisions: 8,
                                activeColor: EatsTheme.primaryCyan,
                                onChanged: (v) {
                                  _updateSelectedNode(selectedNode.copyWith(
                                    indicatorWidth: v,
                                    hardwareKnobStyle: currentStyle.copyWith(indicatorWidth: v),
                                  ));
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: Icon(Icons.fork_right, size: 14, color: EatsTheme.primaryCyan),
                      label: const Text('Fork Skin to EatScript / SVG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EatsTheme.primaryCyan,
                        side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _showForkSkinDialog(context, selectedNode),
                    ),
                  ],

                  if (selectedNode.type == LuaGuiNodeType.slider || selectedNode.type == LuaGuiNodeType.fader) ...[
                    _buildSectionHeader('SLIDER PROPERTIES'),
                    const SizedBox(height: 6),
                    _buildDropdown<SliderStyle>(
                      label: 'Slider Track Style',
                      value: selectedNode.sliderStyle,
                      items: const [
                        DropdownMenuItem(value: SliderStyle.capsule, child: Text('Capsule Track')),
                        DropdownMenuItem(value: SliderStyle.console, child: Text('Console Studio Fader')),
                        DropdownMenuItem(value: SliderStyle.minimalPill, child: Text('Minimalist Slit Fader')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateSelectedNode(selectedNode.copyWith(
                            sliderStyle: v,
                          ));
                        }
                      },
                    ),
                  ],

                  if (selectedNode.type == LuaGuiNodeType.column || selectedNode.type == LuaGuiNodeType.group) ...[
                    _buildSectionHeader('VERTICAL STACK ITEMS'),
                    const SizedBox(height: 6),
                    Text('${selectedNode.children.length} items in stack', style: TextStyle(fontSize: 10, color: EatsTheme.textMuted)),
                    const SizedBox(height: 6),
                    PopupMenuButton<GuiPaletteItem>(
                      tooltip: 'Add item into stack',
                      color: const Color(0xFF1E2430),
                      onSelected: (item) {
                        if (widget.onAddChildToStack != null && widget.selectedRowIndex != null && widget.selectedChildIndex != null) {
                          widget.onAddChildToStack!(widget.selectedRowIndex!, widget.selectedChildIndex!, item);
                        }
                      },
                      itemBuilder: (context) => GuiWidgetPalette.items
                          .where((i) => i.id != 'column') // don't nest columns recursively
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: EatsTheme.primaryCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 14, color: EatsTheme.primaryCyan),
                            const SizedBox(width: 6),
                            Text('+ ADD WIDGET INTO STACK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EatsTheme.primaryCyan)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowAlignmentInspector(LuaGuiNode rowNode, int rowIndex) {
    final isGroup = rowNode.type == LuaGuiNodeType.group;
    final double opacityVal = rowNode.opacity ?? 1.0;
    final double borderVal = rowNode.borderWidth ?? (isGroup ? 1.0 : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: EatsTheme.primaryCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                ),
                child: Text(
                  isGroup ? 'GROUP PROPERTIES' : 'ROW ${rowIndex + 1} PROPERTIES',
                  overflow: TextOverflow.ellipsis,
                  style: EatsTheme.getDisplayFontStyle(fontSize: 9.5, color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              tooltip: 'Delete Row',
              color: Colors.redAccent,
              onPressed: widget.onDeleteSelected,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('IDENTITY & CARD STYLING'),
        const SizedBox(height: 6),
        _buildTextField(
          isGroup ? 'Group Header / Label' : 'Row Header (Optional)',
          TextEditingController(text: rowNode.label ?? ''),
          (v) {
            _updateSelectedNode(rowNode.copyWith(label: v.isEmpty ? null : v));
          },
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'BACKGROUND OPACITY',
                style: EatsTheme.getDisplayFontStyle(fontSize: 9, color: EatsTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              opacityVal <= 0.0 ? '0% (Transparent)' : '${(opacityVal * 100).toInt()}%',
              style: EatsTheme.getDisplayFontStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: opacityVal <= 0.0 ? EatsTheme.primaryCyan : EatsTheme.accentGold,
              ),
            ),
          ],
        ),
        Slider(
          value: opacityVal.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          divisions: 20,
          activeColor: EatsTheme.primaryCyan,
          onChanged: (v) {
            _updateSelectedNode(rowNode.copyWith(opacity: v));
          },
        ),
        const SizedBox(height: 6),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'BORDER WIDTH',
                style: EatsTheme.getDisplayFontStyle(fontSize: 9, color: EatsTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              borderVal <= 0.0 ? '0px (None)' : '${borderVal.toStringAsFixed(1)}px',
              style: EatsTheme.getDisplayFontStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: borderVal <= 0.0 ? EatsTheme.primaryCyan : EatsTheme.accentGold,
              ),
            ),
          ],
        ),
        Slider(
          value: borderVal.clamp(0.0, 4.0),
          min: 0.0,
          max: 4.0,
          divisions: 16,
          activeColor: EatsTheme.primaryCyan,
          onChanged: (v) {
            _updateSelectedNode(rowNode.copyWith(borderWidth: v));
          },
        ),
        const SizedBox(height: 6),

        _buildTextField(
          'Border Hex Color (e.g. #DCDFE6 or empty)',
          TextEditingController(
            text: rowNode.borderColor != null
                ? '#${rowNode.borderColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'
                : '',
          ),
          (v) {
            final col = LuaGuiNode.parseColor(v);
            _updateSelectedNode(rowNode.copyWith(borderColor: col));
          },
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('HORIZONTAL DISTRIBUTION'),
        const SizedBox(height: 6),
        _buildDropdown<String>(
          label: 'Item Spacing / Align',
          value: rowNode.align,
          items: const [
            DropdownMenuItem(value: 'space_around', child: Text('Space Around (Balanced)')),
            DropdownMenuItem(value: 'space_between', child: Text('Space Between (Edges)')),
            DropdownMenuItem(value: 'space_evenly', child: Text('Space Evenly')),
            DropdownMenuItem(value: 'center', child: Text('Center Grouped')),
            DropdownMenuItem(value: 'left', child: Text('Left Aligned')),
            DropdownMenuItem(value: 'right', child: Text('Right Aligned')),
          ],
          onChanged: (v) {
            if (v != null) {
              _updateSelectedNode(rowNode.copyWith(align: v));
            }
          },
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('VERTICAL CROSS-ALIGNMENT'),
        const SizedBox(height: 6),
        _buildDropdown<String>(
          label: 'Vertical Alignment',
          value: rowNode.crossAlign,
          items: const [
            DropdownMenuItem(value: 'center', child: Text('Center Vertical')),
            DropdownMenuItem(value: 'top', child: Text('Top Aligned')),
            DropdownMenuItem(value: 'bottom', child: Text('Bottom Aligned')),
          ],
          onChanged: (v) {
            if (v != null) {
              _updateSelectedNode(rowNode.copyWith(crossAlign: v));
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: EatsTheme.primaryCyan.withOpacity(0.9)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, void Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: EatsTheme.textMuted)),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2430),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2E384D)),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 11, color: Colors.white),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: EatsTheme.textMuted)),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2430),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2E384D)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E2430),
              style: const TextStyle(fontSize: 11, color: Colors.white),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  String _getHardwarePresetName(EatHardwareKnobStyle? style) {
    if (style == null) return 'vintage_bakelite';
    if (style.capStyle == EatCapStyle.diagonalBar) return 'tb303_selector';
    if (style.haloColor != null) return 'tb303_acid_halo';
    if (style.knurlStyle == EatKnurlStyle.fineSawtooth) return 'tb303_potentiometer';
    if (style.indicatorColor == const Color(0xFF51388E)) return 'snes_console';
    if (style.capColor == const Color(0xFFF6F6F7)) return 'minimal_white';
    if (style.capColor == const Color(0xFF1E2026)) return 'standard_hardware';
    if (style.capColor == const Color(0xFFDCDFE5)) return 'chrome_fluted';
    if (style.knurlStyle == EatKnurlStyle.fluted) return 'cream_fluted';
    if (style.knurlStyle == EatKnurlStyle.diamond) return 'anodized_knurled';
    if (style.skirtStyle == EatSkirtStyle.stepped) return 'two_tone_stepped';
    if (style.indicatorStyle == EatIndicatorStyle.illuminatedLed) return 'encoder';
    return 'vintage_bakelite';
  }

  String _getScalePresetName(EatScaleGraduation scale) {
    if (scale.labels.contains('CLASSIC')) return 'mode_steps';
    if (scale.labels.contains('low')) return 'low_mid_high';
    if (scale.labels.contains('dyn') || scale.leadLabel == 'dyn') return 'sustain_1_to_6';
    if (scale.hasBlockCenterDetent) return 'tb303_dial';
    if (scale.labels.length == 11 && scale.labels.first == '0') return 'zero_to_ten';
    if (scale.labels.contains('0') && scale.hasCenterDetent) return 'bipolar';
    if (scale.tickDivisions == 0 && scale.labels.isEmpty) return 'none';
    if (scale.labels.isEmpty && scale.tickDivisions > 0) return 'clean_ticks';
    return 'zero_to_ten';
  }

  String _hex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Widget _buildColorTileRow({
    required BuildContext context,
    required String label,
    required Color? currentColor,
    required Color defaultColor,
    required ValueChanged<Color?> onColorChanged,
  }) {
    final isTrack = LuaGuiNode.isTrackColor(currentColor);
    final effectiveColor = isTrack
        ? (widget.trackColor ?? EatsTheme.primaryCyan)
        : (currentColor ?? defaultColor);

    String textBadge;
    if (isTrack) {
      textBadge = 'TRACK ACCENT';
    } else if (currentColor != null) {
      textBadge = _hex(currentColor);
    } else {
      textBadge = 'PRESET DEFAULT';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showColorPickerDialog(
          context: context,
          title: label,
          currentColor: currentColor,
          defaultColor: defaultColor,
          onColorChanged: onColorChanged,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: effectiveColor,
                  border: Border.all(
                    color: isTrack ? EatsTheme.primaryCyan : Colors.white60,
                    width: isTrack ? 1.8 : 1.0,
                  ),
                  boxShadow: isTrack
                      ? [BoxShadow(color: effectiveColor.withOpacity(0.6), blurRadius: 6)]
                      : null,
                ),
                child: isTrack
                    ? const Center(
                        child: Icon(Icons.graphic_eq, size: 10, color: Colors.black),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      textBadge,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                        color: isTrack ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                        fontWeight: isTrack ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, size: 14, color: EatsTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPickerDialog({
    required BuildContext context,
    required String title,
    required Color? currentColor,
    required Color defaultColor,
    required ValueChanged<Color?> onColorChanged,
  }) {
    Color? workingColor = currentColor;
    final hexController = TextEditingController(
      text: currentColor != null && !LuaGuiNode.isTrackColor(currentColor)
          ? _hex(currentColor)
          : (LuaGuiNode.isTrackColor(currentColor) ? 'track' : ''),
    );
    final trackColor = widget.trackColor ?? EatsTheme.primaryCyan;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isTrack = LuaGuiNode.isTrackColor(workingColor);
            final previewColor = isTrack
                ? trackColor
                : (workingColor ?? defaultColor);

            return AlertDialog(
              backgroundColor: const Color(0xFF141822),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.5), width: 1.2),
              ),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              title: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: previewColor,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: previewColor.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: isTrack
                        ? const Center(child: Icon(Icons.graphic_eq, size: 12, color: Colors.black))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: EatsTheme.getDisplayFontStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isTrack
                          ? 'TRACK ACCENT'
                          : (workingColor != null ? _hex(workingColor!) : 'DEFAULT'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DYNAMIC DAW COLOR',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white60),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            workingColor = LuaGuiNode.trackColorSentinel;
                            hexController.text = 'track';
                          });
                          onColorChanged(LuaGuiNode.trackColorSentinel);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isTrack
                                ? EatsTheme.primaryCyan.withOpacity(0.16)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isTrack ? EatsTheme.primaryCyan : Colors.white24,
                              width: isTrack ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: trackColor,
                                  boxShadow: [
                                    BoxShadow(color: trackColor.withOpacity(0.6), blurRadius: 4),
                                  ],
                                ),
                                child: const Icon(Icons.graphic_eq, size: 11, color: Colors.black),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dynamic DAW Track Accent',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isTrack ? EatsTheme.primaryCyan : Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Always reflects current track color (${_hex(trackColor)})',
                                      style: TextStyle(fontSize: 9, color: EatsTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (isTrack)
                                Icon(Icons.check_circle, size: 16, color: EatsTheme.primaryCyan),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'CURATED STUDIO SWATCHES',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white60),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: const [
                          Color(0xFFE8E5DC), // Cream Off-White
                          Color(0xFFF6F6F7), // Matte Pure White
                          Color(0xFFDCDFE5), // Brushed Chrome
                          Color(0xFF90939A), // Anodized Silver
                          Color(0xFF2A2D35), // Studio Gunmetal
                          Color(0xFF202024), // Bakelite Black
                          Color(0xFF141416), // Pitch Dark
                          Color(0xFF00E5FF), // Cyan Neon
                          Color(0xFF00FF9D), // Acid Green
                          Color(0xFFFF3D00), // Signal Red
                          Color(0xFFFFD700), // Amber Gold
                          Color(0xFF51388E), // SNES Classic Purple
                          Color(0xFFE040FB), // Synth Magenta
                          Color(0xFF2979FF), // Cobalt Blue
                        ].map((col) {
                          final isSelected = !isTrack && workingColor?.value == col.value;
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                workingColor = col;
                                hexController.text = _hex(col);
                              });
                              onColorChanged(col);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.white24,
                                  width: isSelected ? 2.2 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: col.withOpacity(0.8), blurRadius: 6)]
                                    : null,
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Icon(
                                        Icons.check,
                                        size: 13,
                                        color: col.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'CUSTOM HEX OR NAME',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white60),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: hexController,
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '#00E5FF or track',
                                hintStyle: TextStyle(color: EatsTheme.textMuted, fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: const Color(0xFF0C0F16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: EatsTheme.primaryCyan),
                                ),
                              ),
                              onChanged: (v) {
                                final clean = v.trim().toLowerCase();
                                if (clean == 'track') {
                                  setModalState(() {
                                    workingColor = LuaGuiNode.trackColorSentinel;
                                  });
                                  onColorChanged(LuaGuiNode.trackColorSentinel);
                                  return;
                                }
                                final col = LuaGuiNode.parseColor(v);
                                if (col != null) {
                                  setModalState(() {
                                    workingColor = col;
                                  });
                                  onColorChanged(col);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    onColorChanged(null);
                    Navigator.of(dialogCtx).pop();
                  },
                  child: Text('Reset to Default', style: TextStyle(fontSize: 11, color: EatsTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EatsTheme.primaryCyan,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showForkSkinDialog(BuildContext context, LuaGuiNode node) {
    final skin = node.customSkin ?? BuiltInVectorSkins.getSkinForKnobStyle(node.knobStyle);
    final scriptCode = BuiltInVectorSkins.exportToEatScript(skin, node.param ?? 'custom_knob');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: EatsTheme.primaryCyan, width: 1.2),
        ),
        title: Row(
          children: [
            Icon(Icons.fork_right, color: EatsTheme.primaryCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'Fork Vector Skin: ${skin.name ?? skin.id}',
              style: EatsTheme.getDisplayFontStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This EatScript definition contains the full 2-pass vector and SVG path commands. Copy it into your script or apply it directly to this knob as a custom vector skin.',
                style: TextStyle(fontSize: 11, color: EatsTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Container(
                height: 220,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    scriptCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF00FFCC),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy to Clipboard', style: TextStyle(fontSize: 11)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: scriptCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vector skin EatScript copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Apply as Custom Vector', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: EatsTheme.primaryCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              _updateSelectedNode(node.copyWith(
                knobStyle: KnobStyle.customVector,
                customSkin: skin,
              ));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Knob converted to Custom 2-Pass Vector Skin!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String svg) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: Colors.white12,
      onPressed: () {
        _svgController.text = svg;
        widget.onPanelUpdated(widget.panel.copyWith(
          backgroundSvg: svg,
          backgroundSvgOpacity: 0.22,
        ));
      },
    );
  }
}
