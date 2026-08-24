import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart' show SliderStyle;
import '../../theme/eats_theme.dart';
import 'skeuomorphic_hardware_slider.dart';

class EatsBeatsSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final String? label;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;
  final int? divisions;
  final double step;
  final String Function(double)? formatValue;
  final bool showTooltip;
  final Axis orientation;
  final SliderStyle style;

  const EatsBeatsSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.defaultValue,
    this.label,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
    this.divisions,
    this.step = 0.0,
    this.formatValue,
    this.showTooltip = true,
    this.orientation = Axis.horizontal,
    this.style = SliderStyle.capsule,
  });

  @override
  Widget build(BuildContext context) {
    return SkeuomorphicHardwareSlider(
      value: value,
      min: min,
      max: max,
      defaultValue: defaultValue,
      label: label,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      activeColor: activeColor ?? EatsTheme.primaryCyan,
      orientation: orientation,
      style: style,
      divisions: divisions,
      step: step,
      formatValue: formatValue,
      showTooltip: showTooltip,
    );
  }
}
