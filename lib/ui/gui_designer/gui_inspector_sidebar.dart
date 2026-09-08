import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../lua/lua_gui_model.dart';
import '../../theme/eats_theme.dart';
import '../vector/built_in_vector_skins.dart';
import '../vector/vector_skin_model.dart';
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

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.panel.title);
    _subtitleController = TextEditingController(text: widget.panel.subtitle ?? '');
    _svgController = TextEditingController(text: widget.panel.backgroundSvg ?? '');

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

                  _buildTextField(
                    'Custom Chassis Hex (e.g. #ECEEF2)',
                    TextEditingController(
                      text: widget.panel.backgroundColor != null
                          ? '#${widget.panel.backgroundColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'
                          : (widget.panel.backgroundStyle == PanelBackgroundStyle.minimalWhite
                              ? '#ECEEF2'
                              : (widget.panel.backgroundStyle == PanelBackgroundStyle.silver
                                  ? '#D4D0C5'
                                  : (widget.panel.backgroundStyle == PanelBackgroundStyle.snes ? '#D8D6CD' : ''))),
                    ),
                    (v) {
                      final col = LuaGuiNode.parseColor(v);
                      widget.onPanelUpdated(widget.panel.copyWith(
                        backgroundStyle: col != null ? PanelBackgroundStyle.custom : widget.panel.backgroundStyle,
                        backgroundColor: col,
                      ));
                    },
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
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: selectedNode.param,
                            label: selectedNode.label,
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            knobStyle: selectedNode.knobStyle,
                            sliderStyle: selectedNode.sliderStyle,
                            orientation: selectedNode.orientation,
                            options: selectedNode.options,
                            align: v,
                            crossAlign: selectedNode.crossAlign,
                            children: selectedNode.children,
                          ));
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
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: selectedNode.param,
                            label: selectedNode.label,
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            backgroundStyle: selectedNode.backgroundStyle,
                            backgroundColor: selectedNode.backgroundColor,
                            textureRotation: selectedNode.textureRotation,
                            textureScale: selectedNode.textureScale,
                            knobStyle: selectedNode.knobStyle,
                            sliderStyle: selectedNode.sliderStyle,
                            orientation: selectedNode.orientation,
                            options: selectedNode.options,
                            align: selectedNode.align,
                            crossAlign: v,
                            children: selectedNode.children,
                          ));
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
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: selectedNode.param,
                            label: selectedNode.label,
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            backgroundStyle: style,
                            backgroundColor: selectedNode.backgroundColor,
                            textureRotation: selectedNode.textureRotation,
                            textureScale: selectedNode.textureScale,
                            knobStyle: selectedNode.knobStyle,
                            sliderStyle: selectedNode.sliderStyle,
                            orientation: selectedNode.orientation,
                            options: selectedNode.options,
                            align: selectedNode.align,
                            crossAlign: selectedNode.crossAlign,
                            children: selectedNode.children,
                          ));
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
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: selectedNode.param,
                            label: selectedNode.label,
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            backgroundStyle: selectedNode.backgroundStyle,
                            backgroundColor: selectedNode.backgroundColor,
                            textureRotation: v,
                            textureScale: selectedNode.textureScale,
                            knobStyle: selectedNode.knobStyle,
                            sliderStyle: selectedNode.sliderStyle,
                            orientation: selectedNode.orientation,
                            options: selectedNode.options,
                            align: selectedNode.align,
                            crossAlign: selectedNode.crossAlign,
                            children: selectedNode.children,
                          ));
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
                      _updateSelectedNode(LuaGuiNode(
                        type: selectedNode.type,
                        param: selectedNode.param,
                        label: selectedNode.label,
                        unit: selectedNode.unit,
                        size: selectedNode.size,
                        width: selectedNode.width,
                        height: selectedNode.height,
                        knobStyle: selectedNode.knobStyle,
                        sliderStyle: selectedNode.sliderStyle,
                        orientation: selectedNode.orientation,
                        options: selectedNode.options,
                        align: selectedNode.align,
                        crossAlign: selectedNode.crossAlign,
                        showLabel: v ?? true,
                        showValue: selectedNode.showValue,
                        children: selectedNode.children,
                      ));
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
                        _updateSelectedNode(LuaGuiNode(
                          type: selectedNode.type,
                          param: selectedNode.param,
                          label: selectedNode.label,
                          unit: selectedNode.unit,
                          size: selectedNode.size,
                          width: selectedNode.width,
                          height: selectedNode.height,
                          knobStyle: selectedNode.knobStyle,
                          sliderStyle: selectedNode.sliderStyle,
                          orientation: selectedNode.orientation,
                          options: selectedNode.options,
                          align: selectedNode.align,
                          crossAlign: selectedNode.crossAlign,
                          showLabel: selectedNode.showLabel,
                          showValue: v ?? true,
                          children: selectedNode.children,
                        ));
                      },
                    ),
                  ],
                  const SizedBox(height: 8),

                  _buildTextField('Display Label', _labelController, (v) {
                    _updateSelectedNode(LuaGuiNode(
                      type: selectedNode.type,
                      param: selectedNode.param,
                      label: v,
                      unit: selectedNode.unit,
                      size: selectedNode.size,
                      width: selectedNode.width,
                      height: selectedNode.height,
                      knobStyle: selectedNode.knobStyle,
                      sliderStyle: selectedNode.sliderStyle,
                      orientation: selectedNode.orientation,
                      options: selectedNode.options,
                      align: selectedNode.align,
                      crossAlign: selectedNode.crossAlign,
                      showLabel: selectedNode.showLabel,
                      showValue: selectedNode.showValue,
                      children: selectedNode.children,
                    ));
                  }),
                  const SizedBox(height: 8),

                  _buildTextField('Unit String (e.g. Hz, dB, ms, %)', _unitController, (v) {
                    _updateSelectedNode(LuaGuiNode(
                      type: selectedNode.type,
                      param: selectedNode.param,
                      label: selectedNode.label,
                      unit: v,
                      size: selectedNode.size,
                      width: selectedNode.width,
                      height: selectedNode.height,
                      knobStyle: selectedNode.knobStyle,
                      sliderStyle: selectedNode.sliderStyle,
                      orientation: selectedNode.orientation,
                      options: selectedNode.options,
                      align: selectedNode.align,
                      crossAlign: selectedNode.crossAlign,
                      showLabel: selectedNode.showLabel,
                      showValue: selectedNode.showValue,
                      children: selectedNode.children,
                    ));
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
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: selectedNode.param,
                            label: selectedNode.label,
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            knobStyle: selectedNode.knobStyle,
                            sliderStyle: selectedNode.sliderStyle,
                            orientation: v,
                            options: selectedNode.options,
                            align: selectedNode.align,
                            crossAlign: selectedNode.crossAlign,
                            showLabel: selectedNode.showLabel,
                            showValue: selectedNode.showValue,
                            children: selectedNode.children,
                          ));
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
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: v,
                            label: v.toUpperCase(),
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            knobStyle: selectedNode.knobStyle,
                            sliderStyle: selectedNode.sliderStyle,
                            orientation: selectedNode.orientation,
                            options: selectedNode.options,
                            align: selectedNode.align,
                            crossAlign: selectedNode.crossAlign,
                            showLabel: selectedNode.showLabel,
                            showValue: selectedNode.showValue,
                            children: selectedNode.children,
                          ));
                        }
                      },
                    ),
                  ] else ...[
                    _buildTextField('Parameter Name', TextEditingController(text: selectedNode.param ?? ''), (v) {
                      _updateSelectedNode(LuaGuiNode(
                        type: selectedNode.type,
                        param: v,
                        label: selectedNode.label,
                        unit: selectedNode.unit,
                        size: selectedNode.size,
                        width: selectedNode.width,
                        height: selectedNode.height,
                        knobStyle: selectedNode.knobStyle,
                        sliderStyle: selectedNode.sliderStyle,
                        orientation: selectedNode.orientation,
                        options: selectedNode.options,
                        align: selectedNode.align,
                        crossAlign: selectedNode.crossAlign,
                        showLabel: selectedNode.showLabel,
                        showValue: selectedNode.showValue,
                        children: selectedNode.children,
                      ));
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
                        _updateSelectedNode(LuaGuiNode(
                          type: selectedNode.type,
                          param: selectedNode.param,
                          label: selectedNode.label,
                          unit: selectedNode.unit,
                          size: v,
                          width: selectedNode.width,
                          height: selectedNode.height,
                          knobStyle: selectedNode.knobStyle,
                          sliderStyle: selectedNode.sliderStyle,
                          orientation: selectedNode.orientation,
                          options: selectedNode.options,
                          align: selectedNode.align,
                          crossAlign: selectedNode.crossAlign,
                          children: selectedNode.children,
                        ));
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildDropdown<KnobStyle>(
                      label: 'Knob Skin',
                      value: selectedNode.knobStyle,
                      items: const [
                        DropdownMenuItem(value: KnobStyle.standard, child: Text('Standard Hardware')),
                        DropdownMenuItem(value: KnobStyle.chrome, child: Text('Chrome Fluted (303)')),
                        DropdownMenuItem(value: KnobStyle.vintage, child: Text('Vintage Bakelite')),
                        DropdownMenuItem(value: KnobStyle.snes, child: Text('SNES Console Cream')),
                        DropdownMenuItem(value: KnobStyle.minimalWhite, child: Text('Minimalist Matte Ceramic')),
                        DropdownMenuItem(value: KnobStyle.customVector, child: Text('Custom Vector (SVG)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: selectedNode.param,
                            label: selectedNode.label,
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            knobStyle: v,
                            customSkin: v == KnobStyle.customVector
                                ? (selectedNode.customSkin ?? BuiltInVectorSkins.getSkinForKnobStyle(selectedNode.knobStyle))
                                : selectedNode.customSkin,
                            sliderStyle: selectedNode.sliderStyle,
                            orientation: selectedNode.orientation,
                            options: selectedNode.options,
                            align: selectedNode.align,
                            crossAlign: selectedNode.crossAlign,
                            children: selectedNode.children,
                          ));
                        }
                      },
                    ),
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
                          _updateSelectedNode(LuaGuiNode(
                            type: selectedNode.type,
                            param: selectedNode.param,
                            label: selectedNode.label,
                            unit: selectedNode.unit,
                            size: selectedNode.size,
                            width: selectedNode.width,
                            height: selectedNode.height,
                            knobStyle: selectedNode.knobStyle,
                            sliderStyle: v,
                            orientation: selectedNode.orientation,
                            options: selectedNode.options,
                            align: selectedNode.align,
                            crossAlign: selectedNode.crossAlign,
                            children: selectedNode.children,
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
              _updateSelectedNode(LuaGuiNode(
                type: node.type,
                param: node.param,
                label: node.label,
                unit: node.unit,
                size: node.size,
                width: node.width,
                height: node.height,
                knobStyle: KnobStyle.customVector,
                customSkin: skin,
                sliderStyle: node.sliderStyle,
                orientation: node.orientation,
                options: node.options,
                align: node.align,
                crossAlign: node.crossAlign,
                children: node.children,
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
