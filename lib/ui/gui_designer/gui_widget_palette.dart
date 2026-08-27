import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart';
import '../../theme/eats_theme.dart';

class GuiPaletteItem {
  final String id;
  final String title;
  final String category;
  final IconData icon;
  final LuaGuiNode Function({String? defaultParam}) createNode;

  const GuiPaletteItem({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.createNode,
  });
}

class GuiWidgetPalette {
  static final List<GuiPaletteItem> items = [
    // 1. Controls
    GuiPaletteItem(
      id: 'knob',
      title: 'Rotary Knob',
      category: 'CONTROLS',
      icon: Icons.radio_button_checked,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.knob,
        param: defaultParam ?? 'Param',
        label: (defaultParam ?? 'KNOB').toUpperCase(),
        size: 52,
      ),
    ),
    GuiPaletteItem(
      id: 'hslider',
      title: 'Horizontal Slider',
      category: 'CONTROLS',
      icon: Icons.linear_scale,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.slider,
        param: defaultParam ?? 'Param',
        label: (defaultParam ?? 'SLIDER').toUpperCase(),
        orientation: 'horizontal',
        width: 440,
        sliderStyle: SliderStyle.capsule,
      ),
    ),
    GuiPaletteItem(
      id: 'vslider',
      title: 'Vertical Fader',
      category: 'CONTROLS',
      icon: Icons.tune,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.slider,
        param: defaultParam ?? 'Param',
        label: (defaultParam ?? 'FADER').toUpperCase(),
        orientation: 'vertical',
        height: 120,
        sliderStyle: SliderStyle.console,
      ),
    ),
    GuiPaletteItem(
      id: 'switch',
      title: 'Toggle Switch',
      category: 'CONTROLS',
      icon: Icons.toggle_on_outlined,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.switchToggle,
        param: defaultParam ?? 'Switch',
        label: (defaultParam ?? 'SWITCH').toUpperCase(),
      ),
    ),
    GuiPaletteItem(
      id: 'button',
      title: 'Push Button',
      category: 'CONTROLS',
      icon: Icons.smart_button,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.button,
        action: 'trigger',
        label: 'TRIGGER',
        width: 90,
        height: 36,
      ),
    ),
    GuiPaletteItem(
      id: 'listbox',
      title: 'Choice Listbox',
      category: 'CONTROLS',
      icon: Icons.list_alt,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.listBox,
        param: defaultParam ?? 'Mode',
        label: (defaultParam ?? 'CHOICE').toUpperCase(),
        width: 140,
        height: 75,
      ),
    ),

    // 2. Displays
    GuiPaletteItem(
      id: 'nixie',
      title: 'Nixie Tube Display',
      category: 'DISPLAYS',
      icon: Icons.pin,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.nixie,
        param: defaultParam ?? 'Param',
        label: (defaultParam ?? 'NIXIE').toUpperCase(),
        unit: 'Hz',
        width: 110,
      ),
    ),
    GuiPaletteItem(
      id: 'lcd',
      title: 'LCD Value Readout',
      category: 'DISPLAYS',
      icon: Icons.monitor,
      createNode: ({String? defaultParam}) => LuaGuiNode(
        type: LuaGuiNodeType.lcd,
        param: defaultParam ?? 'Param',
        label: (defaultParam ?? 'LCD READOUT').toUpperCase(),
      ),
    ),

    // 3. Visualizers & 3D
    GuiPaletteItem(
      id: 'oscilloscope',
      title: 'Audio Oscilloscope',
      category: 'VISUALIZERS',
      icon: Icons.graphic_eq,
      createNode: ({String? defaultParam}) => const LuaGuiNode(
        type: LuaGuiNodeType.oscilloscope,
        width: 320,
        height: 140,
      ),
    ),
    GuiPaletteItem(
      id: 'spectrum',
      title: 'FFT Spectrum Analyzer',
      category: 'VISUALIZERS',
      icon: Icons.equalizer,
      createNode: ({String? defaultParam}) => const LuaGuiNode(
        type: LuaGuiNodeType.spectrum,
        width: 320,
        height: 140,
      ),
    ),
    GuiPaletteItem(
      id: 'space_visualizer',
      title: '3D Space Visualizer',
      category: 'VISUALIZERS',
      icon: Icons.view_in_ar,
      createNode: ({String? defaultParam}) => const LuaGuiNode(
        type: LuaGuiNodeType.spaceVisualizer,
        height: 140,
      ),
    ),
    GuiPaletteItem(
      id: 'waveshaper_canvas',
      title: 'WaveShaper Transfer Canvas',
      category: 'VISUALIZERS',
      icon: Icons.gesture,
      createNode: ({String? defaultParam}) => const LuaGuiNode(
        type: LuaGuiNodeType.waveshaperCanvas,
        height: 150,
      ),
    ),
    GuiPaletteItem(
      id: 'vector_canvas',
      title: 'Programmable 2D Canvas',
      category: 'VISUALIZERS',
      icon: Icons.brush_outlined,
      createNode: ({String? defaultParam}) => const LuaGuiNode(
        type: LuaGuiNodeType.canvas,
        canvasMode: 'custom',
        width: 340,
        height: 180,
      ),
    ),

    // 4. Structure
    GuiPaletteItem(
      id: 'column',
      title: 'Vertical Stack / Column',
      category: 'STRUCTURE',
      icon: Icons.view_column,
      createNode: ({String? defaultParam}) => const LuaGuiNode(
        type: LuaGuiNodeType.column,
        children: [],
      ),
    ),
    GuiPaletteItem(
      id: 'divider',
      title: 'Vertical Divider Line',
      category: 'STRUCTURE',
      icon: Icons.more_vert,
      createNode: ({String? defaultParam}) => const LuaGuiNode(
        type: LuaGuiNodeType.divider,
      ),
    ),
  ];
}

class GuiWidgetPaletteDrawer extends StatelessWidget {
  final void Function(GuiPaletteItem item) onAddItem;

  const GuiWidgetPaletteDrawer({super.key, required this.onAddItem});

  @override
  Widget build(BuildContext context) {
    final categories = ['CONTROLS', 'DISPLAYS', 'VISUALIZERS', 'STRUCTURE'];

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF14171F),
        border: Border(right: BorderSide(color: Color(0xFF2B3245))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF0F1218),
            child: Row(
              children: [
                Icon(Icons.widgets_outlined, size: 16, color: EatsTheme.primaryCyan),
                const SizedBox(width: 8),
                Text(
                  'WIDGET TOOLBOX',
                  style: EatsTheme.getDisplayFontStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.textLight),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final cat in categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: EatsTheme.primaryCyan.withOpacity(0.8),
                      ),
                    ),
                  ),
                  for (final item in GuiWidgetPalette.items.where((i) => i.category == cat)) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Draggable<GuiPaletteItem>(
                        data: item,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2430),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: EatsTheme.primaryCyan, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(item.icon, size: 16, color: EatsTheme.primaryCyan),
                                const SizedBox(width: 6),
                                Text(
                                  item.title,
                                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: Material(
                          color: const Color(0xFF1C222E),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => onAddItem(item),
                            hoverColor: EatsTheme.primaryCyan.withOpacity(0.15),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(item.icon, size: 16, color: EatsTheme.accentGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: EatsTheme.getPrimaryFontStyle(fontSize: 11, color: EatsTheme.textPrimary),
                                    ),
                                  ),
                                  Icon(Icons.drag_indicator, size: 14, color: EatsTheme.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
