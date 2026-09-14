import 'package:flutter/material.dart';
import '../ui/vector/vector_skin_model.dart';
import '../ui/hardware/eat_hardware_knob_model.dart';
import '../ui/hardware/eat_hardware_scale.dart';

// Backwards-compatibility aliases
typedef LuaGuiNodeType = EatScriptGuiNodeType;
typedef LuaGuiNode = EatScriptGuiNode;
typedef LuaGuiPanelDef = EatScriptGuiPanelDef;
typedef LuaGuiGradientDef = EatScriptGuiGradientDef;

enum EatScriptGuiNodeType {
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
  drumPads,
  unknown,
}

enum KnobStyle {
  standard,
  chrome,
  vintage,
  snes,
  minimalWhite,
  customVector,
  hardwareKnob,
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
  pcbGreen,
}

class EatScriptGuiNode {
  final EatScriptGuiNodeType type;
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
  final CustomControlSkin? customSkin;
  final EatHardwareKnobStyle? hardwareKnobStyle;
  final EatScaleGraduation? hardwareScale;
  final double? opacity; // 0.0 = completely transparent background, 1.0 = solid
  final double? borderWidth; // 0.0 = no border
  final Color? borderColor;
  final Color? capColor;
  final Color? bodyColor;
  final Color? indicatorColor;
  final Color? dialColor;
  final double? capSize;          // Cap radius ratio (e.g. 0.55 .. 0.98)
  final double? bodySize;         // Skirt / body fullness ratio (e.g. 1.0 .. 1.45)
  final double? indicatorLength;  // Indicator ratio (0.3 .. 0.95)
  final double? indicatorWidth;   // Indicator width (1.0 .. 5.0)
  final List<EatScriptGuiNode> children;

  const EatScriptGuiNode({
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
    this.customSkin,
    this.hardwareKnobStyle,
    this.hardwareScale,
    this.opacity,
    this.borderWidth,
    this.borderColor,
    this.capColor,
    this.bodyColor,
    this.indicatorColor,
    this.dialColor,
    this.capSize,
    this.bodySize,
    this.indicatorLength,
    this.indicatorWidth,
    this.children = const [],
  });

  EatScriptGuiNode copyWith({
    EatScriptGuiNodeType? type,
    String? param,
    String? label,
    String? unit,
    double? size,
    double? width,
    double? height,
    Color? accentColor,
    PanelBackgroundStyle? backgroundStyle,
    Color? backgroundColor,
    double? textureRotation,
    double? textureScale,
    double? cornerRadius,
    List<String>? options,
    String? orientation,
    String? align,
    String? crossAlign,
    String? leftText,
    String? rightText,
    String? text,
    String? action,
    KnobStyle? knobStyle,
    SliderStyle? sliderStyle,
    String? canvasMode,
    int? cols,
    int? rows,
    double? scale,
    bool? showDpad,
    bool? showActionButtons,
    bool? showLabel,
    bool? showValue,
    List<Color>? palette,
    CustomControlSkin? customSkin,
    EatHardwareKnobStyle? hardwareKnobStyle,
    EatScaleGraduation? hardwareScale,
    bool clearHardwareKnobStyle = false,
    bool clearHardwareScale = false,
    double? opacity,
    double? borderWidth,
    Color? borderColor,
    Color? capColor,
    Color? bodyColor,
    Color? indicatorColor,
    Color? dialColor,
    double? capSize,
    double? bodySize,
    double? indicatorLength,
    double? indicatorWidth,
    List<EatScriptGuiNode>? children,
  }) {
    return EatScriptGuiNode(
      type: type ?? this.type,
      param: param ?? this.param,
      label: label ?? this.label,
      unit: unit ?? this.unit,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      accentColor: accentColor ?? this.accentColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textureRotation: textureRotation ?? this.textureRotation,
      textureScale: textureScale ?? this.textureScale,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      options: options ?? this.options,
      orientation: orientation ?? this.orientation,
      align: align ?? this.align,
      crossAlign: crossAlign ?? this.crossAlign,
      leftText: leftText ?? this.leftText,
      rightText: rightText ?? this.rightText,
      text: text ?? this.text,
      action: action ?? this.action,
      knobStyle: knobStyle ?? this.knobStyle,
      sliderStyle: sliderStyle ?? this.sliderStyle,
      canvasMode: canvasMode ?? this.canvasMode,
      cols: cols ?? this.cols,
      rows: rows ?? this.rows,
      scale: scale ?? this.scale,
      showDpad: showDpad ?? this.showDpad,
      showActionButtons: showActionButtons ?? this.showActionButtons,
      showLabel: showLabel ?? this.showLabel,
      showValue: showValue ?? this.showValue,
      palette: palette ?? this.palette,
      customSkin: customSkin ?? this.customSkin,
      hardwareKnobStyle: clearHardwareKnobStyle ? null : (hardwareKnobStyle ?? this.hardwareKnobStyle),
      hardwareScale: clearHardwareScale ? null : (hardwareScale ?? this.hardwareScale),
      opacity: opacity ?? this.opacity,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      capColor: capColor ?? this.capColor,
      bodyColor: bodyColor ?? this.bodyColor,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      dialColor: dialColor ?? this.dialColor,
      capSize: capSize ?? this.capSize,
      bodySize: bodySize ?? this.bodySize,
      indicatorLength: indicatorLength ?? this.indicatorLength,
      indicatorWidth: indicatorWidth ?? this.indicatorWidth,
      children: children ?? this.children,
    );
  }

  static EatScriptGuiNodeType parseType(String? rawType) {
    if (rawType == null) return EatScriptGuiNodeType.unknown;
    final clean = rawType.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (clean) {
      case 'knob':
      case 'rotary':
        return EatScriptGuiNodeType.knob;
      case 'slider':
      case 'hslider':
      case 'horizontalslider':
      case 'vslider':
      case 'verticalslider':
        return EatScriptGuiNodeType.slider;
      case 'fader':
        return EatScriptGuiNodeType.fader;
      case 'switch':
      case 'toggle':
      case 'rocker':
      case 'slideswitch':
        return EatScriptGuiNodeType.switchToggle;
      case 'button':
      case 'pushbutton':
      case 'arcadebutton':
        return EatScriptGuiNodeType.button;
      case 'listbox':
      case 'list':
      case 'listview':
      case 'select':
      case 'dropdown':
        return EatScriptGuiNodeType.listBox;
      case 'nixie':
      case 'nixiedisplay':
        return EatScriptGuiNodeType.nixie;
      case 'lcd':
      case 'lcddisplay':
        return EatScriptGuiNodeType.lcd;
      case 'meter':
      case 'vumeter':
        return EatScriptGuiNodeType.meter;
      case 'space':
      case 'spacevisualizer':
      case 'roomvisualizer':
      case 'cabvisualizer':
      case 'roomcanvas':
      case 'cabcanvas':
        return EatScriptGuiNodeType.spaceVisualizer;
      case 'waveshaper':
      case 'shaper':
      case 'waveshapercanvas':
      case 'shapercanvas':
      case 'transfercanvas':
        return EatScriptGuiNodeType.waveshaperCanvas;
      case 'oscilloscope':
      case 'scope':
      case 'waveform':
      case 'wavevisualizer':
      case 'eatsscope':
        return EatScriptGuiNodeType.oscilloscope;
      case 'spectrum':
      case 'fft':
      case 'spectrumanalyzer':
      case 'eatsspectrum':
        return EatScriptGuiNodeType.spectrum;
      case 'segmented_pill':
      case 'segmentedpill':
      case 'segmented':
      case 'pill_selector':
      case 'pillselector':
      case 'pill_switch':
      case 'mode_pill':
        return EatScriptGuiNodeType.segmentedPill;
      case 'canvas':
      case 'gamecanvas':
      case 'screen':
      case 'display':
      case 'viewport':
      case 'visualizer':
      case 'framebuffer':
        return EatScriptGuiNodeType.canvas;
      case 'drumpads':
      case 'drumpad':
      case 'drumpadgrid':
      case 'pads':
        return EatScriptGuiNodeType.drumPads;
      case 'dpad':
      case 'joystick':
      case 'directional':
        return EatScriptGuiNodeType.dpad;
      case 'gamepad':
      case 'arcadebuttons':
      case 'actionbuttons':
      case 'controller':
        return EatScriptGuiNodeType.gamepad;
      case 'divider':
      case 'separator':
      case 'line':
      case 'vbar':
      case 'hbar':
        return EatScriptGuiNodeType.divider;
      case 'row':
      case 'hgroup':
      case 'hbox':
        return EatScriptGuiNodeType.row;
      case 'column':
      case 'col':
      case 'vgroup':
      case 'vbox':
        return EatScriptGuiNodeType.column;
      case 'group':
      case 'section':
      case 'panel':
        return EatScriptGuiNodeType.group;
      case 'label':
      case 'text':
        return EatScriptGuiNodeType.label;
      case 'spacer':
      case 'space':
        return EatScriptGuiNodeType.spacer;
      default:
        return EatScriptGuiNodeType.unknown;
    }
  }

  static KnobStyle parseKnobStyle(String? raw) {
    if (raw == null) return KnobStyle.standard;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('hardware') ||
        clean.contains('console_knob') ||
        clean.contains('consoleknob') ||
        clean.contains('fluted') ||
        clean.contains('stepped') ||
        clean.contains('twotone') ||
        clean.contains('two_tone')) {
      return KnobStyle.hardwareKnob;
    }
    if (clean.contains('custom') || clean.contains('vector') || clean.contains('svg')) {
      return KnobStyle.customVector;
    }
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

  static SvgTileMode parseSvgTileMode(dynamic raw) {
    if (raw == null) return SvgTileMode.none;
    final s = raw.toString().toLowerCase().trim();
    if (s == 'x' || s == 'repeat_x' || s == 'repeat-x' || s == 'horizontal' || s == 'tile_x') return SvgTileMode.x;
    if (s == 'y' || s == 'repeat_y' || s == 'repeat-y' || s == 'vertical' || s == 'tile_y') return SvgTileMode.y;
    if (s == 'xy' || s == 'both' || s == 'repeat' || s == 'repeat_xy' || s == 'all') return SvgTileMode.xy;
    return SvgTileMode.none;
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
    if (clean.contains('pcb') || clean.contains('circuit') || clean.contains('solder') || clean.contains('board')) {
      return PanelBackgroundStyle.pcbGreen;
    }
    return PanelBackgroundStyle.dark;
  }



  /// Special sentinel color designating that a component dynamically follows the DAW track color.
  static const Color trackColorSentinel = Color(0x00000001);

  /// Checks if a given color matches the dynamic track color sentinel.
  static bool isTrackColor(Color? c) => c != null && c.value == 0x00000001;

  static Color? parseColor(dynamic colorVal) {
    if (colorVal == null) return null;
    if (colorVal is int) {
      if (colorVal == 0x00000001) return trackColorSentinel;
      return Color(colorVal);
    }
    if (colorVal is Color) return colorVal;
    if (colorVal is String) {
      final s = colorVal.trim();
      if (s.toLowerCase() == 'track') {
        return trackColorSentinel;
      }
      if (s.toLowerCase() == 'auto' || s.toLowerCase() == 'none') {
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

enum PanelGradientType {
  linear,
  radial,
}

class EatScriptGuiGradientDef {
  final PanelGradientType type;
  final List<Color> colors;
  final List<double>? stops;
  final Alignment begin;
  final Alignment end;
  final Alignment center;
  final double radius;

  const EatScriptGuiGradientDef({
    this.type = PanelGradientType.radial,
    required this.colors,
    this.stops,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.center = Alignment.center,
    this.radius = 1.0,
  });

  Gradient toFlutterGradient() {
    if (type == PanelGradientType.linear) {
      return LinearGradient(
        colors: colors,
        stops: stops,
        begin: begin,
        end: end,
      );
    } else {
      return RadialGradient(
        colors: colors,
        stops: stops,
        center: center,
        radius: radius,
      );
    }
  }
}

enum SvgTileMode {
  none,
  x,
  y,
  xy,
}

enum SvgLayerStyle {
  stroke,
  fill,
}

class SvgLayerDef {
  final String path;
  final Color? color;
  final double? strokeWidth;
  final SvgLayerStyle style;
  final double opacity;
  final SvgTileMode tileMode;

  const SvgLayerDef({
    required this.path,
    this.color,
    this.strokeWidth,
    this.style = SvgLayerStyle.stroke,
    this.opacity = 1.0,
    this.tileMode = SvgTileMode.none,
  });
}

class EatScriptGuiPanelDef {
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
  final String? backgroundSvg; // Optional SVG path watermark rendered across panel chassis
  final double backgroundSvgOpacity;
  final double? backgroundSvgStrokeWidth; // Optional stroke thickness for watermark line art
  final SvgTileMode backgroundSvgTile; // Tiling mode: none, x, y, xy
  final EatScriptGuiGradientDef? backgroundGradient; // Optional linear or radial GPU gradient
  final List<SvgLayerDef>? backgroundSvgLayers; // Optional multi-path layered vector watermark
  final List<EatScriptGuiNode> children;

  const EatScriptGuiPanelDef({
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
    this.backgroundSvg,
    this.backgroundSvgOpacity = 0.20,
    this.backgroundSvgStrokeWidth,
    this.backgroundSvgTile = SvgTileMode.none,
    this.backgroundGradient,
    this.backgroundSvgLayers,
    required this.children,
  });

  EatScriptGuiPanelDef copyWith({
    String? title,
    String? subtitle,
    String? style,
    PanelBackgroundStyle? backgroundStyle,
    Color? backgroundColor,
    Color? accentColor,
    KnobStyle? defaultKnobStyle,
    double? textureRotation,
    double? textureScale,
    String? sideCheeks,
    double? cornerRadius,
    String? backgroundSvg,
    double? backgroundSvgOpacity,
    double? backgroundSvgStrokeWidth,
    SvgTileMode? backgroundSvgTile,
    EatScriptGuiGradientDef? backgroundGradient,
    List<SvgLayerDef>? backgroundSvgLayers,
    List<EatScriptGuiNode>? children,
  }) {
    return EatScriptGuiPanelDef(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      style: style ?? this.style,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      accentColor: accentColor ?? this.accentColor,
      defaultKnobStyle: defaultKnobStyle ?? this.defaultKnobStyle,
      textureRotation: textureRotation ?? this.textureRotation,
      textureScale: textureScale ?? this.textureScale,
      sideCheeks: sideCheeks ?? this.sideCheeks,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      backgroundSvg: backgroundSvg ?? this.backgroundSvg,
      backgroundSvgOpacity: backgroundSvgOpacity ?? this.backgroundSvgOpacity,
      backgroundSvgStrokeWidth: backgroundSvgStrokeWidth ?? this.backgroundSvgStrokeWidth,
      backgroundSvgTile: backgroundSvgTile ?? this.backgroundSvgTile,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      backgroundSvgLayers: backgroundSvgLayers ?? this.backgroundSvgLayers,
      children: children ?? this.children,
    );
  }
}


