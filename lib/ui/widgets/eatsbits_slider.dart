import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';
import 'skeuomorphic_hardware_slider.dart';

class EatsBitsSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final String? label;
  final ValueChanged<double> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final int? divisions;
  final double step;
  final String Function(double)? formatValue;

  const EatsBitsSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.defaultValue,
    this.label,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.divisions,
    this.step = 0.0,
    this.formatValue,
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
      activeColor: activeColor ?? EatsTheme.primaryCyan,
      divisions: divisions,
      step: step,
      formatValue: formatValue,
    );
  }
}
