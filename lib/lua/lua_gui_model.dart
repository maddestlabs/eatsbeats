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
  row,
  column,
  group,
  label,
  spacer,
  unknown,
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
        return LuaGuiNodeType.switchToggle;
      case 'button':
      case 'pushbutton':
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

  static Color? parseColor(dynamic colorVal) {
    if (colorVal == null) return null;
    if (colorVal is int) return Color(colorVal);
    if (colorVal is String) {
      final s = colorVal.trim();
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
      }
    }
    return null;
  }
}

class LuaGuiPanelDef {
  final String title;
  final String? subtitle;
  final String style; // 'rack', 'vintage', 'modern', 'grunge'
  final Color? accentColor;
  final List<LuaGuiNode> children;

  const LuaGuiPanelDef({
    required this.title,
    this.subtitle,
    this.style = 'rack',
    this.accentColor,
    required this.children,
  });
}
