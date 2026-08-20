import 'dart:math' as math;
import '../audio/easing.dart';
import '../audio/time_context.dart';

/// Defines an automatable parameter destination (continuous or discrete).
class AutomationTarget {
  final String id; // e.g. 'track.volume', 'track.pan', 'fx.cutoff', 'ym2612.reg_0x28'
  final String name; // User-facing name, e.g. 'Volume', 'Filter Cutoff'
  final double min;
  final double max;
  final double defaultValue;
  final String unit; // 'dB', '%', 'Hz', 'ms', ''
  final bool isDiscrete; // True for integer steps, chip registers, algorithm switches
  final List<String> options;

  const AutomationTarget({
    required this.id,
    required this.name,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.unit = '',
    this.isDiscrete = false,
    this.options = const [],
  });

  // ── Standard Built-in Parameter Targets ────────────────────────────────────

  static const volume = AutomationTarget(
    id: 'track.volume',
    name: 'Volume',
    min: 0.0,
    max: 1.5,
    defaultValue: 1.0,
    unit: '%',
  );

  static const pan = AutomationTarget(
    id: 'track.pan',
    name: 'Pan',
    min: -1.0,
    max: 1.0,
    defaultValue: 0.0,
    unit: 'L/R',
  );

  static const cutoff = AutomationTarget(
    id: 'filter.cutoff',
    name: 'Filter Cutoff',
    min: 20.0,
    max: 20000.0,
    defaultValue: 3500.0,
    unit: 'Hz',
  );

  static const resonance = AutomationTarget(
    id: 'filter.resonance',
    name: 'Filter Resonance',
    min: 0.1,
    max: 20.0,
    defaultValue: 1.5,
    unit: 'Q',
  );

  static AutomationTarget ymfmRegister(String chipName, int registerAddress, {String? customName}) {
    final hexReg = '0x${registerAddress.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    return AutomationTarget(
      id: '$chipName.reg_$hexReg',
      name: customName ?? '$chipName Reg $hexReg',
      min: 0.0,
      max: 255.0,
      defaultValue: 0.0,
      unit: 'hex',
      isDiscrete: true,
    );
  }

  static AutomationTarget custom({
    required String id,
    required String name,
    double min = 0.0,
    double max = 1.0,
    double defaultValue = 0.5,
    String unit = '',
    bool isDiscrete = false,
    List<String> options = const [],
  }) {
    return AutomationTarget(
      id: id,
      name: name,
      min: min,
      max: max,
      defaultValue: defaultValue,
      unit: unit,
      isDiscrete: isDiscrete,
      options: options,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'min': min,
    'max': max,
    'defaultValue': defaultValue,
    'unit': unit,
    'isDiscrete': isDiscrete,
    'options': options,
  };

  factory AutomationTarget.fromJson(Map<String, dynamic> json) => AutomationTarget(
    id: json['id'] ?? 'custom.param',
    name: json['name'] ?? 'Parameter',
    min: (json['min'] as num?)?.toDouble() ?? 0.0,
    max: (json['max'] as num?)?.toDouble() ?? 1.0,
    defaultValue: (json['defaultValue'] as num?)?.toDouble() ?? 0.5,
    unit: json['unit'] ?? '',
    isDiscrete: json['isDiscrete'] ?? false,
    options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

/// A single keyframe point on an automation timeline.
class AutomationPoint {
  final String id;
  double step; // Step position along arrangement / clip (0.0, 1.0, 1.5...)
  double value; // Actual parameter value
  EasingType easing; // Easing curve to the NEXT point
  double tension; // -1.0 to 1.0 curve tension
  double handleX1; // Custom bezier handle 1 X
  double handleY1; // Custom bezier handle 1 Y
  double handleX2; // Custom bezier handle 2 X
  double handleY2; // Custom bezier handle 2 Y

  AutomationPoint({
    required this.id,
    required this.step,
    required this.value,
    this.easing = EasingType.linear,
    this.tension = 0.0,
    this.handleX1 = 0.25,
    this.handleY1 = 0.1,
    this.handleX2 = 0.25,
    this.handleY2 = 1.0,
  });

  AutomationPoint copyWith({
    String? id,
    double? step,
    double? value,
    EasingType? easing,
    double? tension,
    double? handleX1,
    double? handleY1,
    double? handleX2,
    double? handleY2,
  }) {
    return AutomationPoint(
      id: id ?? this.id,
      step: step ?? this.step,
      value: value ?? this.value,
      easing: easing ?? this.easing,
      tension: tension ?? this.tension,
      handleX1: handleX1 ?? this.handleX1,
      handleY1: handleY1 ?? this.handleY1,
      handleX2: handleX2 ?? this.handleX2,
      handleY2: handleY2 ?? this.handleY2,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'step': step,
    'value': value,
    'easing': easing.name,
    'tension': tension,
    'handleX1': handleX1,
    'handleY1': handleY1,
    'handleX2': handleX2,
    'handleY2': handleY2,
  };

  factory AutomationPoint.fromJson(Map<String, dynamic> json) => AutomationPoint(
    id: json['id'] ?? '',
    step: (json['step'] as num?)?.toDouble() ?? 0.0,
    value: (json['value'] as num?)?.toDouble() ?? 0.0,
    easing: EasingType.values.firstWhere(
      (e) => e.name == json['easing'],
      orElse: () => EasingType.linear,
    ),
    tension: (json['tension'] as num?)?.toDouble() ?? 0.0,
    handleX1: (json['handleX1'] as num?)?.toDouble() ?? 0.25,
    handleY1: (json['handleY1'] as num?)?.toDouble() ?? 0.1,
    handleX2: (json['handleX2'] as num?)?.toDouble() ?? 0.25,
    handleY2: (json['handleY2'] as num?)?.toDouble() ?? 1.0,
  );
}

/// An automation lane governing a single parameter target across time.
/// Supports both declarative breakpoint interpolation and Lua scripted generators.
class AutomationLane {
  final String id;
  String name;
  AutomationTarget target;
  bool enabled;
  List<AutomationPoint> points;
  String luaScriptCode;
  bool isCustomLua; // If true, Lua script drives value instead of breakpoints

  AutomationLane({
    required this.id,
    required this.name,
    required this.target,
    this.enabled = true,
    List<AutomationPoint>? points,
    this.luaScriptCode = '',
    this.isCustomLua = false,
  }) : points = points ?? [];

  /// Evaluates parameter value at a given [step] position.
  double evaluateAtStep(double step, [TimeContext? timeCtx]) {
    if (!enabled) return target.defaultValue;

    if (points.isEmpty) return target.defaultValue;

    // 1. Sort points by step order if needed
    final sortedPoints = List<AutomationPoint>.from(points)
      ..sort((a, b) => a.step.compareTo(b.step));

    // 2. Before first point
    if (step <= sortedPoints.first.step) {
      return sortedPoints.first.value.clamp(target.min, target.max);
    }

    // 3. After last point
    if (step >= sortedPoints.last.step) {
      return sortedPoints.last.value.clamp(target.min, target.max);
    }

    // 4. Find bounding points
    AutomationPoint p0 = sortedPoints.first;
    AutomationPoint p1 = sortedPoints.last;

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      if (step >= sortedPoints[i].step && step <= sortedPoints[i + 1].step) {
        p0 = sortedPoints[i];
        p1 = sortedPoints[i + 1];
        break;
      }
    }

    final span = p1.step - p0.step;
    if (span <= 0.00001) return p0.value.clamp(target.min, target.max);

    final t = ((step - p0.step) / span).clamp(0.0, 1.0);

    // If target is discrete, force step easing
    final effectiveEasing = target.isDiscrete ? EasingType.step : p0.easing;

    final interpolated = Easing.interpolate(
      t,
      p0.value,
      p1.value,
      effectiveEasing,
      tension: p0.tension,
      cx1: p0.handleX1,
      cy1: p0.handleY1,
      cx2: p0.handleX2,
      cy2: p0.handleY2,
    );

    return target.isDiscrete
        ? interpolated.roundToDouble().clamp(target.min, target.max)
        : interpolated.clamp(target.min, target.max);
  }

  /// Automatically generates executable Lua script code representing this automation lane.
  String generateLuaScript() {
    final sb = StringBuffer();
    sb.writeln('-- Eatsbits Automation Script: ${target.name} (${target.id})');
    sb.writeln('-- Generated automatically from automation curve points');
    sb.writeln('local lane = {}');
    sb.writeln('lane.target = "${target.id}"');
    sb.writeln('lane.min = ${target.min}');
    sb.writeln('lane.max = ${target.max}');
    sb.writeln('lane.defaultValue = ${target.defaultValue}');
    sb.writeln();
    sb.writeln('function evaluate(step, ctx)');
    
    if (points.isEmpty) {
      sb.writeln('  return ${target.defaultValue}');
      sb.writeln('end');
      return sb.toString();
    }

    final sorted = List<AutomationPoint>.from(points)
      ..sort((a, b) => a.step.compareTo(b.step));

    sb.writeln('  local points = {');
    for (final p in sorted) {
      sb.writeln('    { step = ${p.step.toStringAsFixed(2)}, value = ${p.value.toStringAsFixed(3)}, easing = "${p.easing.name}" },');
    }
    sb.writeln('  }');
    sb.writeln('  return eatsbits.automation.evaluatePoints(points, step, lane.min, lane.max, lane.defaultValue)');
    sb.writeln('end');

    return sb.toString();
  }

  AutomationLane copyWith({
    String? id,
    String? name,
    AutomationTarget? target,
    bool? enabled,
    List<AutomationPoint>? points,
    String? luaScriptCode,
    bool? isCustomLua,
  }) {
    return AutomationLane(
      id: id ?? this.id,
      name: name ?? this.name,
      target: target ?? this.target,
      enabled: enabled ?? this.enabled,
      points: points ?? this.points.map((p) => p.copyWith()).toList(),
      luaScriptCode: luaScriptCode ?? this.luaScriptCode,
      isCustomLua: isCustomLua ?? this.isCustomLua,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target': target.toJson(),
    'enabled': enabled,
    'points': points.map((p) => p.toJson()).toList(),
    'luaScriptCode': luaScriptCode,
    'isCustomLua': isCustomLua,
  };

  factory AutomationLane.fromJson(Map<String, dynamic> json) => AutomationLane(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    target: json['target'] != null
        ? AutomationTarget.fromJson(json['target'])
        : AutomationTarget.volume,
    enabled: json['enabled'] ?? true,
    points: (json['points'] as List?)
            ?.map((p) => AutomationPoint.fromJson(p))
            .toList() ??
        [],
    luaScriptCode: json['luaScriptCode'] ?? '',
    isCustomLua: json['isCustomLua'] ?? false,
  );
}
