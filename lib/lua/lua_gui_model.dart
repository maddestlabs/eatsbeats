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
  spaceVisualizer,
  waveshaperCanvas,
  oscilloscope,
  spectrum,
  dpad,
  gamepad,
  segmentedPill,
  unknown,
}

enum KnobStyle {
  standard,
  chrome,
  vintage,
  snes,
  minimalWhite,
}

enum SliderStyle {
  console,
  capsule,
  minimalPill,
}

enum PanelBackgroundStyle {
  dark,
  silver,
  grunge,
  snes,
  custom,
  walnut,
  mahogany,
  blondePine,
  rosewood,
  brushedSteel,
  brushedSteelVert,
  matteMetal,
  tolex,
  carbon,
  mesh,
  dx7Membrane,
  harpsichordLacquer,
  c64Breadbin,
  minimalWhite,
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
  final PanelBackgroundStyle? backgroundStyle;
  final Color? backgroundColor;
  final double? textureRotation; // degrees (e.g. 0, 90)
  final double? textureScale;
  final double? cornerRadius;
  final List<String> options;
  final String orientation; // 'horizontal' or 'vertical'
  final String align; // 'space_around', 'space_between', 'center', 'left', 'right', 'top', 'bottom', 'start', 'end'
  final String crossAlign; // 'center', 'top', 'bottom', 'left', 'right', 'start', 'end', 'stretch'
  final String? leftText;
  final String? rightText;
  final String? text;
  final String? action;
  final KnobStyle knobStyle;
  final SliderStyle sliderStyle;
  final String canvasMode; // 'pixel', 'vector', 'grid', 'custom'
  final int cols;
  final int rows;
  final double scale;
  final bool showDpad;
  final bool showActionButtons;
  final bool showLabel;
  final bool showValue;
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
    this.backgroundStyle,
    this.backgroundColor,
    this.textureRotation,
    this.textureScale,
    this.cornerRadius,
    this.options = const [],
    this.orientation = 'vertical',
    this.align = 'space_around',
    this.crossAlign = 'center',
    this.leftText,
    this.rightText,
    this.text,
    this.action,
    this.knobStyle = KnobStyle.standard,
    this.sliderStyle = SliderStyle.capsule,
    this.canvasMode = 'pixel',
    this.cols = 32,
    this.rows = 24,
    this.scale = 1.0,
    this.showDpad = false,
    this.showActionButtons = false,
    this.showLabel = true,
    this.showValue = true,
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
      case 'hslider':
      case 'horizontalslider':
      case 'vslider':
      case 'verticalslider':
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
      case 'space':
      case 'spacevisualizer':
      case 'roomvisualizer':
      case 'cabvisualizer':
      case 'roomcanvas':
      case 'cabcanvas':
        return LuaGuiNodeType.spaceVisualizer;
      case 'waveshaper':
      case 'shaper':
      case 'waveshapercanvas':
      case 'shapercanvas':
      case 'transfercanvas':
        return LuaGuiNodeType.waveshaperCanvas;
      case 'oscilloscope':
      case 'scope':
      case 'waveform':
      case 'wavevisualizer':
      case 'eatsscope':
        return LuaGuiNodeType.oscilloscope;
      case 'spectrum':
      case 'fft':
      case 'spectrumanalyzer':
      case 'eatsspectrum':
        return LuaGuiNodeType.spectrum;
      case 'segmented_pill':
      case 'segmentedpill':
      case 'segmented':
      case 'pill_selector':
      case 'pillselector':
      case 'pill_switch':
      case 'mode_pill':
        return LuaGuiNodeType.segmentedPill;
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
    if (clean.contains('minimal') || clean.contains('ceramic') || clean.contains('clean_white') || clean.contains('matte_white')) {
      return KnobStyle.minimalWhite;
    }
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

  static SliderStyle parseSliderStyle(String? raw) {
    if (raw == null) return SliderStyle.capsule;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('minimal') || clean.contains('pill') || clean.contains('minimal_pill') || clean.contains('minimalpill')) {
      return SliderStyle.minimalPill;
    }
    if (clean.contains('console') || clean.contains('mixer') || clean.contains('fader') || clean.contains('vintage')) {
      return SliderStyle.console;
    }
    return SliderStyle.capsule;
  }

  static PanelBackgroundStyle parseBackgroundStyle(String? raw) {
    if (raw == null) return PanelBackgroundStyle.dark;
    final clean = raw.toLowerCase().trim();
    if (clean.startsWith('#') || clean.contains('custom') || clean.startsWith('0x') || clean.startsWith('rgba')) {
      return PanelBackgroundStyle.custom;
    }
    if (clean.contains('minimal') || clean.contains('ceramic') || clean.contains('clean_white') || clean.contains('matte_white')) {
      return PanelBackgroundStyle.minimalWhite;
    }
    if (clean.contains('snes') || clean.contains('famicom') || clean.contains('offwhite') || clean.contains('console') || clean.contains('beige')) {
      return PanelBackgroundStyle.snes;
    }
    if (clean.contains('silver') || clean.contains('303') || clean.contains('aluminum') || clean.contains('champagne') || clean.contains('light')) {
      return PanelBackgroundStyle.silver;
    }
    if (clean.contains('grunge') || clean.contains('rust') || clean.contains('distressed')) {
      return PanelBackgroundStyle.grunge;
    }
    if (clean.contains('walnut') || clean.contains('wood') || clean.contains('timber') || clean.contains('oak')) {
      return PanelBackgroundStyle.walnut;
    }
    if (clean.contains('mahogany') || clean.contains('redwood')) {
      return PanelBackgroundStyle.mahogany;
    }
    if (clean.contains('blonde') || clean.contains('pine') || clean.contains('ash') || clean.contains('birch')) {
      return PanelBackgroundStyle.blondePine;
    }
    if (clean.contains('rosewood') || clean.contains('darkwood') || clean.contains('ebony')) {
      return PanelBackgroundStyle.rosewood;
    }
    if (clean.contains('steel_vert') || clean.contains('brushed_vert') || clean.contains('vert_steel')) {
      return PanelBackgroundStyle.brushedSteelVert;
    }
    if (clean.contains('steel') || clean.contains('brushed') || clean.contains('iron')) {
      return PanelBackgroundStyle.brushedSteel;
    }
    if (clean.contains('matte') || clean.contains('anodized') || clean.contains('chassis')) {
      return PanelBackgroundStyle.matteMetal;
    }
    if (clean.contains('tolex') || clean.contains('vinyl') || clean.contains('amp') || clean.contains('tweed')) {
      return PanelBackgroundStyle.tolex;
    }
    if (clean.contains('carbon') || clean.contains('kevlar') || clean.contains('weave')) {
      return PanelBackgroundStyle.carbon;
    }
    if (clean.contains('mesh') || clean.contains('grille') || clean.contains('vent') || clean.contains('perforated')) {
      return PanelBackgroundStyle.mesh;
    }
    if (clean.contains('dx7') || clean.contains('membrane') || clean.contains('teal_membrane')) {
      return PanelBackgroundStyle.dx7Membrane;
    }
    if (clean.contains('harpsichord') || clean.contains('lacquer') || clean.contains('cembalo') || clean.contains('gilded')) {
      return PanelBackgroundStyle.harpsichordLacquer;
    }
    if (clean.contains('c64') || clean.contains('breadbin') || clean.contains('commodore') || clean.contains('sid')) {
      return PanelBackgroundStyle.c64Breadbin;
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
  final double textureRotation; // degrees (e.g. 0, 90)
  final double textureScale;
  final String? sideCheeks; // 'walnut', 'mahogany', 'blondePine', 'rosewood', 'none'
  final double? cornerRadius; // in pixels (e.g. 0 for flush rack, 4, 8, 12)
  final List<LuaGuiNode> children;

  const LuaGuiPanelDef({
    required this.title,
    this.subtitle,
    this.style = 'rack',
    this.backgroundStyle = PanelBackgroundStyle.dark,
    this.backgroundColor,
    this.accentColor,
    this.defaultKnobStyle = KnobStyle.standard,
    this.textureRotation = 0.0,
    this.textureScale = 1.0,
    this.sideCheeks,
    this.cornerRadius,
    required this.children,
  });
}
