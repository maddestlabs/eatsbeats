import 'package:flutter/material.dart';

enum LuaGuiNodeType {
  knob,
  slider,
  fader,
  switchToggle,
  button,
  listBox,
  nixie,
  lcd,
  meter,
  divider,
  row,
  column,
  group,
  label,
  spacer,
  canvas,
  dpad,
  gamepad,
  unknown,
}

enum KnobStyle {
  standard,
  chrome,
  vintage,
  snes,
}

enum PanelBackgroundStyle {
  dark,
  silver,
  grunge,
  snes,
  custom,
}

class LuaGuiNode {
  final LuaGuiNodeType type;
  final String? param;
  final String? label;
  final String? unit;
  final double? size;
  final double? width;
  final double? height;
  final Color? accentColor;
  final List<String> options;
  final String orientation; // 'horizontal' or 'vertical'
  final String align; // 'space_around', 'space_between', 'center', 'start', 'end'
  final String? leftText;
  final String? rightText;
  final String? text;
  final String? action;
  final KnobStyle knobStyle;
  final String canvasMode; // 'pixel', 'vector', 'grid'
  final int cols;
  final int rows;
  final double scale;
  final bool showDpad;
  final bool showActionButtons;
  final List<Color> palette;
  final List<LuaGuiNode> children;

  const LuaGuiNode({
    required this.type,
    this.param,
    this.label,
    this.unit,
    this.size,
    this.width,
    this.height,
    this.accentColor,
    this.options = const [],
    this.orientation = 'vertical',
    this.align = 'space_around',
    this.leftText,
    this.rightText,
    this.text,
    this.action,
    this.knobStyle = KnobStyle.standard,
    this.canvasMode = 'pixel',
    this.cols = 32,
    this.rows = 24,
    this.scale = 1.0,
    this.showDpad = false,
    this.showActionButtons = false,
    this.palette = const [],
    this.children = const [],
  });

  static LuaGuiNodeType parseType(String? rawType) {
    if (rawType == null) return LuaGuiNodeType.unknown;
    final clean = rawType.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (clean) {
      case 'knob':
      case 'rotary':
        return LuaGuiNodeType.knob;
      case 'slider':
        return LuaGuiNodeType.slider;
      case 'fader':
        return LuaGuiNodeType.fader;
      case 'switch':
      case 'toggle':
      case 'rocker':
      case 'slideswitch':
        return LuaGuiNodeType.switchToggle;
      case 'button':
      case 'pushbutton':
      case 'arcadebutton':
        return LuaGuiNodeType.button;
      case 'listbox':
      case 'list':
      case 'listview':
      case 'select':
      case 'dropdown':
        return LuaGuiNodeType.listBox;
      case 'nixie':
      case 'nixiedisplay':
        return LuaGuiNodeType.nixie;
      case 'lcd':
      case 'lcddisplay':
        return LuaGuiNodeType.lcd;
      case 'meter':
      case 'vumeter':
        return LuaGuiNodeType.meter;
      case 'canvas':
      case 'gamecanvas':
      case 'screen':
      case 'display':
      case 'viewport':
      case 'visualizer':
      case 'framebuffer':
        return LuaGuiNodeType.canvas;
      case 'dpad':
      case 'joystick':
      case 'directional':
        return LuaGuiNodeType.dpad;
      case 'gamepad':
      case 'arcadebuttons':
      case 'actionbuttons':
      case 'controller':
        return LuaGuiNodeType.gamepad;
      case 'divider':
      case 'separator':
      case 'line':
      case 'vbar':
      case 'hbar':
        return LuaGuiNodeType.divider;
      case 'row':
      case 'hgroup':
      case 'hbox':
        return LuaGuiNodeType.row;
      case 'column':
      case 'col':
      case 'vgroup':
      case 'vbox':
        return LuaGuiNodeType.column;
      case 'group':
      case 'section':
      case 'panel':
        return LuaGuiNodeType.group;
      case 'label':
      case 'text':
        return LuaGuiNodeType.label;
      case 'spacer':
      case 'space':
        return LuaGuiNodeType.spacer;
      default:
        return LuaGuiNodeType.unknown;
    }
  }

  static KnobStyle parseKnobStyle(String? raw) {
    if (raw == null) return KnobStyle.standard;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('snes') || clean.contains('white') || clean.contains('controller') || clean.contains('famicom')) {
      return KnobStyle.snes;
    }
    if (clean.contains('chrome') || clean.contains('303') || clean.contains('metal') || clean.contains('silver')) {
      return KnobStyle.chrome;
    }
    if (clean.contains('vintage') || clean.contains('retro') || clean.contains('bakelite')) {
      return KnobStyle.vintage;
    }
    return KnobStyle.standard;
  }

  static PanelBackgroundStyle parseBackgroundStyle(String? raw) {
    if (raw == null) return PanelBackgroundStyle.dark;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('snes') || clean.contains('famicom') || clean.contains('offwhite') || clean.contains('console') || clean.contains('beige')) {
      return PanelBackgroundStyle.snes;
    }
    if (clean.contains('silver') || clean.contains('303') || clean.contains('aluminum') || clean.contains('champagne') || clean.contains('light')) {
      return PanelBackgroundStyle.silver;
    }
    if (clean.contains('grunge') || clean.contains('rust') || clean.contains('distressed')) {
      return PanelBackgroundStyle.grunge;
    }
    return PanelBackgroundStyle.dark;
  }

  static Color? parseColor(dynamic colorVal) {
    if (colorVal == null) return null;
    if (colorVal is int) return Color(colorVal);
    if (colorVal is String) {
      final s = colorVal.trim();
      if (s.toLowerCase() == 'track' || s.toLowerCase() == 'auto' || s.toLowerCase() == 'none') {
        return null;
      }
      if (s.startsWith('#')) {
        final hex = s.substring(1);
        if (hex.length == 6) {
          final val = int.tryParse('FF$hex', radix: 16);
          if (val != null) return Color(val);
        } else if (hex.length == 8) {
          final val = int.tryParse(hex, radix: 16);
          if (val != null) return Color(val);
        }
      }
      switch (s.toLowerCase()) {
        case 'orange':
          return const Color(0xFFFF8C00);
        case 'cyan':
          return const Color(0xFF00E5FF);
        case 'mint':
        case 'neon':
          return const Color(0xFF00FF9D);
        case 'green':
          return const Color(0xFF00E676);
        case 'gold':
        case 'yellow':
          return const Color(0xFFFFD700);
        case 'red':
          return const Color(0xFFFF3D00);
        case 'magenta':
        case 'purple':
          return const Color(0xFFE040FB);
        case 'blue':
          return const Color(0xFF2979FF);
        case 'silver':
          return const Color(0xFFD6D3C8);
        case 'black':
          return const Color(0xFF141416);
      }
    }
    return null;
  }
}

class LuaGuiPanelDef {
  final String title;
  final String? subtitle;
  final String style; // 'rack', 'vintage', 'modern', 'grunge', 'silver', 'tb303'
  final PanelBackgroundStyle backgroundStyle;
  final Color? backgroundColor;
  final Color? accentColor;
  final KnobStyle defaultKnobStyle;
  final List<LuaGuiNode> children;

  const LuaGuiPanelDef({
    required this.title,
    this.subtitle,
    this.style = 'rack',
    this.backgroundStyle = PanelBackgroundStyle.dark,
    this.backgroundColor,
    this.accentColor,
    this.defaultKnobStyle = KnobStyle.standard,
    required this.children,
  });
}
