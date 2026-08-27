import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart';
import '../../theme/eats_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.panel.title);
    _subtitleController = TextEditingController(text: widget.panel.subtitle ?? '');

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
            (childNode.type == LuaGuiNodeType.column || childNode.type == LuaGuiNodeType.group) &&
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
          (childNode.type == LuaGuiNodeType.column || childNode.type == LuaGuiNodeType.group) &&
          s >= 0 &&
          s < childNode.children.length) {
        final newStackChildren = List<LuaGuiNode>.from(childNode.children);
        newStackChildren[s] = updatedNode;
        newChildren[c] = LuaGuiNode(
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
      } else {
        newChildren[c] = updatedNode;
      }
      rows[r] = LuaGuiNode(
        type: rowNode.type,
        orientation: rowNode.orientation,
        align: rowNode.align,
        crossAlign: rowNode.crossAlign,
        children: newChildren,
      );
    } else {
      rows[r] = updatedNode;
    }

    widget.onPanelUpdated(LuaGuiPanelDef(
      title: widget.panel.title,
      subtitle: widget.panel.subtitle,
      style: widget.panel.style,
      backgroundStyle: widget.panel.backgroundStyle,
      backgroundColor: widget.panel.backgroundColor,
      accentColor: widget.panel.accentColor,
      defaultKnobStyle: widget.panel.defaultKnobStyle,
      children: rows,
    ));
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
                    widget.onPanelUpdated(LuaGuiPanelDef(
                      title: v.isEmpty ? 'CUSTOM INSTRUMENT' : v,
                      subtitle: widget.panel.subtitle,
                      style: widget.panel.style,
                      backgroundStyle: widget.panel.backgroundStyle,
                      backgroundColor: widget.panel.backgroundColor,
                      accentColor: widget.panel.accentColor,
                      defaultKnobStyle: widget.panel.defaultKnobStyle,
                      children: widget.panel.children,
                    ));
                  }),
                  const SizedBox(height: 8),
                  _buildTextField('Subtitle', _subtitleController, (v) {
                    widget.onPanelUpdated(LuaGuiPanelDef(
                      title: widget.panel.title,
                      subtitle: v,
                      style: widget.panel.style,
                      backgroundStyle: widget.panel.backgroundStyle,
                      backgroundColor: widget.panel.backgroundColor,
                      accentColor: widget.panel.accentColor,
                      defaultKnobStyle: widget.panel.defaultKnobStyle,
                      children: widget.panel.children,
                    ));
                  }),
                  const SizedBox(height: 14),

                  _buildSectionHeader('CHASSIS & THEME'),
                  const SizedBox(height: 6),
                  _buildDropdown<PanelBackgroundStyle>(
                    label: 'Background Theme',
                    value: widget.panel.backgroundStyle,
                    items: const [
                      DropdownMenuItem(value: PanelBackgroundStyle.dark, child: Text('Dark Studio (Anodized)')),
                      DropdownMenuItem(value: PanelBackgroundStyle.silver, child: Text('Silver Brushed (TB-303)')),
                      DropdownMenuItem(value: PanelBackgroundStyle.grunge, child: Text('Industrial Grunge')),
                      DropdownMenuItem(value: PanelBackgroundStyle.snes, child: Text('16-Bit SNES Console')),
                      DropdownMenuItem(value: PanelBackgroundStyle.custom, child: Text('Custom Hex Color')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onPanelUpdated(LuaGuiPanelDef(
                          title: widget.panel.title,
                          subtitle: widget.panel.subtitle,
                          style: widget.panel.style,
                          backgroundStyle: v,
                          backgroundColor: widget.panel.backgroundColor,
                          accentColor: widget.panel.accentColor,
                          defaultKnobStyle: widget.panel.defaultKnobStyle,
                          children: widget.panel.children,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  _buildTextField(
                    'Custom Chassis Hex (e.g. #1E1E24)',
                    TextEditingController(
                      text: widget.panel.backgroundColor != null
                          ? '#${widget.panel.backgroundColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'
                          : '',
                    ),
                    (v) {
                      final col = LuaGuiNode.parseColor(v);
                      if (col != null) {
                        widget.onPanelUpdated(LuaGuiPanelDef(
                          title: widget.panel.title,
                          subtitle: widget.panel.subtitle,
                          style: widget.panel.style,
                          backgroundStyle: PanelBackgroundStyle.custom,
                          backgroundColor: col,
                          accentColor: widget.panel.accentColor,
                          defaultKnobStyle: widget.panel.defaultKnobStyle,
                          children: widget.panel.children,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildDropdown<KnobStyle>(
                    label: 'Default Knob Skin',
                    value: widget.panel.defaultKnobStyle,
                    items: const [
                      DropdownMenuItem(value: KnobStyle.standard, child: Text('Standard Hardware')),
                      DropdownMenuItem(value: KnobStyle.chrome, child: Text('Chrome Fluted (303)')),
                      DropdownMenuItem(value: KnobStyle.vintage, child: Text('Vintage Bakelite')),
                      DropdownMenuItem(value: KnobStyle.snes, child: Text('SNES Console Cream')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onPanelUpdated(LuaGuiPanelDef(
                          title: widget.panel.title,
                          subtitle: widget.panel.subtitle,
                          style: widget.panel.style,
                          backgroundStyle: widget.panel.backgroundStyle,
                          backgroundColor: widget.panel.backgroundColor,
                          accentColor: widget.panel.accentColor,
                          defaultKnobStyle: v,
                          children: widget.panel.children,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildSectionHeader('ACCENT COLOR'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      widget.onPanelUpdated(LuaGuiPanelDef(
                        title: widget.panel.title,
                        subtitle: widget.panel.subtitle,
                        style: widget.panel.style,
                        backgroundStyle: widget.panel.backgroundStyle,
                        backgroundColor: widget.panel.backgroundColor,
                        accentColor: null, // Track Color (auto dynamic)
                        defaultKnobStyle: widget.panel.defaultKnobStyle,
                        children: widget.panel.children,
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
                          widget.onPanelUpdated(LuaGuiPanelDef(
                            title: widget.panel.title,
                            subtitle: widget.panel.subtitle,
                            style: widget.panel.style,
                            backgroundStyle: widget.panel.backgroundStyle,
                            backgroundColor: widget.panel.backgroundColor,
                            accentColor: col,
                            defaultKnobStyle: widget.panel.defaultKnobStyle,
                            children: widget.panel.children,
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
                  'ROW ${rowIndex + 1} PROPERTIES',
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
              _updateSelectedNode(LuaGuiNode(
                type: rowNode.type,
                orientation: rowNode.orientation,
                align: v,
                crossAlign: rowNode.crossAlign,
                children: rowNode.children,
              ));
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
              _updateSelectedNode(LuaGuiNode(
                type: rowNode.type,
                orientation: rowNode.orientation,
                align: rowNode.align,
                crossAlign: v,
                children: rowNode.children,
              ));
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
}
