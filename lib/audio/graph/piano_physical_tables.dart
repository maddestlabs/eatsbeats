import 'dart:math' as math;

/// Piecewise-linear breakpoint table lookup from Stanford CCRMA / Bank-Bensa / Faust physical piano model.
class PianoBreakpoints {
  final List<double> points; // [x0, y0, x1, y1, ...]

  const PianoBreakpoints(this.points);

  double lookup(double x) {
    if (points.isEmpty) return 0.0;
    if (points.length == 2) return points[1];

    final int numPoints = points.length ~/ 2;
    if (x <= points[0]) return points[1];
    if (x >= points[(numPoints - 1) * 2]) return points[(numPoints - 1) * 2 + 1];

    for (int i = 0; i < numPoints - 1; i++) {
      final double x0 = points[i * 2];
      final double y0 = points[i * 2 + 1];
      final double x1 = points[(i + 1) * 2];
      final double y1 = points[(i + 1) * 2 + 1];

      if (x >= x0 && x <= x1) {
        final double span = x1 - x0;
        if (span <= 0.000001) return y0;
        final double frac = (x - x0) / span;
        return y0 + frac * (y1 - y0);
      }
    }
    return points.last;
  }
}

/// Empirical 88-key physical piano measurements (Bank, Bensa, Smith, Michon).
class PianoPhysicalTables {
  static const singleStringDecayRate = PianoBreakpoints([
    21.0, -1.5,
    24.0, -1.5,
    28.0, -1.5,
    29.0, -6.0,
    36.0, -6.0,
    42.0, -6.1,
    48.0, -7.0,
    52.836, -7.0,
    60.0, -7.3,
    66.0, -7.7,
    72.0, -8.0,
    78.0, -8.8,
    84.0, -10.0,
    88.619, -11.215,
    92.368, -12.348,
    95.684, -13.934,
    99.0, -15.0,
  ]);

  static const singleStringZero = PianoBreakpoints([
    21.0, -1.0,
    24.0, -1.0,
    28.0, -1.0,
    29.0, -1.0,
    32.534, -1.0,
    36.0, -0.7,
    42.0, -0.4,
    48.0, -0.2,
    54.0, -0.12,
    60.0, -0.08,
    66.0, -0.07,
    72.0, -0.07,
    79.0, -0.065,
    84.0, -0.063,
    88.0, -0.060,
    96.0, -0.050,
    99.0, -0.050,
  ]);

  static const singleStringPole = PianoBreakpoints([
    21.0, 0.350,
    24.604, 0.318,
    26.335, 0.279,
    28.0, 0.250,
    32.0, 0.150,
    36.0, 0.0,
    42.0, 0.0,
    48.0, 0.0,
    54.0, 0.0,
    60.0, 0.0,
    66.0, 0.0,
    72.0, 0.0,
    76.0, 0.0,
    84.0, 0.0,
    88.0, 0.0,
    96.0, 0.0,
    99.0, 0.0,
  ]);

  static const releaseLoopGain = PianoBreakpoints([
    21.0, 0.865,
    24.0, 0.880,
    29.0, 0.896,
    36.0, 0.910,
    48.0, 0.920,
    60.0, 0.950,
    72.0, 0.965,
    84.0, 0.988,
    88.0, 0.997,
    99.0, 0.988,
  ]);

  static const detuningHz = PianoBreakpoints([
    21.0, 0.003,
    24.0, 0.003,
    28.0, 0.003,
    29.0, 0.060,
    31.0, 0.100,
    36.0, 0.110,
    42.0, 0.120,
    48.0, 0.200,
    54.0, 0.200,
    60.0, 0.250,
    66.0, 0.270,
    72.232, 0.300,
    78.0, 0.350,
    84.0, 0.500,
    88.531, 0.582,
    92.116, 0.664,
    95.844, 0.793,
    99.0, 1.000,
  ]);

  static const stiffnessCoefficient = PianoBreakpoints([
    21.0, -0.850,
    23.595, -0.850,
    27.055, -0.830,
    29.0, -0.700,
    37.725, -0.516,
    46.952, -0.352,
    60.0, -0.250,
    73.625, -0.036,
    93.810, -0.006,
    99.0, 1.011,
  ]);

  static const strikePosition = PianoBreakpoints([
    21.0, 0.050,
    24.0, 0.050,
    28.0, 0.050,
    35.0, 0.050,
    41.0, 0.050,
    42.0, 0.125,
    48.0, 0.125,
    60.0, 0.125,
    72.0, 0.125,
    84.0, 0.125,
    96.0, 0.125,
    99.0, 0.125,
  ]);

  static const eqGain = PianoBreakpoints([
    21.0, 2.0,
    24.0, 2.0,
    28.0, 2.0,
    30.0, 2.0,
    35.562, 1.882,
    41.0, 1.2,
    42.0, 0.6,
    48.0, 0.5,
    54.0, 0.5,
    59.928, 0.502,
    66.704, 0.489,
    74.201, 0.477,
    91.791, 1.0,
    99.0, 1.0,
  ]);

  static const eqBandwidthFactor = PianoBreakpoints([
    21.0, 5.0,
    24.112, 5.0,
    28.0, 5.0,
    35.0, 4.956,
    41.0, 6.0,
    42.0, 2.0,
    48.773, 1.072,
    57.558, 1.001,
    63.226, 1.048,
    69.178, 1.120,
    72.862, 1.525,
    80.404, 2.788,
    97.659, 1.739,
  ]);

  static const loudPole = PianoBreakpoints([
    21.0, 0.875,
    23.719, 0.871,
    27.237, 0.836,
    28.996, 0.828,
    32.355, 0.820,
    36.672, 0.816,
    40.671, 0.820,
    45.788, 0.812,
    47.867, 0.812,
    54.0, 0.810,
    60.0, 0.800,
    66.0, 0.800,
    72.0, 0.810,
    78.839, 0.824,
    84.446, 0.844,
    89.894, 0.844,
    96.463, 0.848,
    103.512, 0.840,
    107.678, 0.840,
  ]);

  static const softPole = PianoBreakpoints([
    21.0, 0.990,
    24.0, 0.990,
    28.0, 0.990,
    29.0, 0.990,
    36.0, 0.990,
    42.0, 0.990,
    48.0, 0.985,
    54.0, 0.970,
    60.0, 0.960,
    66.0, 0.960,
    72.0, 0.960,
    78.0, 0.970,
    84.673, 0.975,
    91.157, 0.990,
    100.982, 0.970,
    104.205, 0.950,
  ]);

  static const loudGain = PianoBreakpoints([
    21.873, 0.891,
    25.194, 0.870,
    30.538, 0.848,
    35.448, 0.853,
    41.513, 0.842,
    47.434, 0.826,
    53.644, 0.820,
    60.720, 0.815,
    65.630, 0.820,
    72.995, 0.853,
    79.060, 0.920,
    85.270, 1.028,
    91.624, 1.247,
    95.668, 1.296,
    99.0, 1.300,
    100.0, 1.100,
  ]);

  static const softGain = PianoBreakpoints([
    20.865, 0.400,
    22.705, 0.400,
    25.960, 0.400,
    28.224, 0.400,
    31.196, 0.400,
    36.715, 0.400,
    44.499, 0.400,
    53.981, 0.400,
    60.0, 0.350,
    66.0, 0.350,
    72.661, 0.350,
    81.435, 0.430,
    88.311, 0.450,
    93.040, 0.500,
    96.434, 0.500,
  ]);

  static const dryTapAmpT60 = PianoBreakpoints([
    21.001, 0.491,
    26.587, 0.498,
    34.249, 0.470,
    40.794, 0.441,
    47.977, 0.392,
    55.0, 0.370,
    60.0, 0.370,
    66.0, 0.370,
    71.934, 0.370,
    78.0, 0.370,
    83.936, 0.390,
    88.557, 0.387,
    92.858, 0.400,
    97.319, 0.469,
    102.400, 0.500,
    107.198, 0.494,
  ]);

  static const sustainPedalLevel = PianoBreakpoints([
    21.0, 0.050,
    24.0, 0.050,
    31.0, 0.030,
    36.0, 0.025,
    48.0, 0.010,
    60.0, 0.005,
    66.0, 0.003,
    72.0, 0.002,
    78.0, 0.002,
    84.0, 0.003,
    90.0, 0.003,
    96.0, 0.003,
    108.0, 0.002,
  ]);

  static const dcBa1 = PianoBreakpoints([
    21.0, -0.999,
    24.0, -0.999,
    30.0, -0.999,
    36.0, -0.999,
    42.0, -0.999,
    48.027, -0.993,
    60.0, -0.995,
    72.335, -0.960,
    78.412, -0.924,
    84.329, -0.850,
    87.688, -0.770,
    91.0, -0.700,
    92.0, -0.910,
    96.783, -0.850,
    99.0, -0.800,
    100.0, -0.850,
    104.634, -0.700,
    107.518, -0.500,
  ]);

  static const secondStageAmpRatio = PianoBreakpoints([
    82.277, -18.508,
    88.0, -30.0,
    90.0, -30.0,
    93.451, -30.488,
    98.891, -30.633,
    107.573, -30.633,
  ]);

  static const r1_1db = PianoBreakpoints([
    100.0, -75.0,
    103.802, -237.513,
    108.0, -400.0,
  ]);

  static const r1_2db = PianoBreakpoints([
    98.388, -16.562,
    100.743, -75.531,
    103.242, -154.156,
    108.0, -300.0,
  ]);

  static const r2db = PianoBreakpoints([
    100.0, -115.898,
    107.858, -250.0,
  ]);

  static const r3db = PianoBreakpoints([
    100.0, -150.0,
    108.0, -400.0,
  ]);

  static const secondPartialFactor = PianoBreakpoints([
    88.0, 2.0,
    108.0, 2.1,
  ]);

  static const thirdPartialFactor = PianoBreakpoints([
    88.0, 3.1,
    108.0, 3.1,
  ]);

  static const bq4_gEarBalled = PianoBreakpoints([
    100.0, 0.040,
    102.477, 0.100,
    104.518, 0.300,
    106.0, 0.500,
    107.0, 1.000,
    108.0, 1.500,
  ]);
}
