import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart';

/// Supported procedural texture styles for DAW hardware, synths, and FX modules.
enum DawTextureType {
  walnut,
  mahogany,
  blondePine,
  rosewood,
  brushedSteel,
  brushedSteelVert,
  matteMetal,
  grunge,
  tolex,
  carbon,
  mesh,
  dx7Membrane,
  harpsichordLacquer,
  c64Breadbin,
}

/// A high-performance procedural texture generator and GPU-resident cache for DAW gear.
/// Generates 100% mathematically toroidal and seamless procedural textures once into `ui.Image`
/// tiles, which are tiled infinitely via `ImageShader` with zero seams and zero runtime overhead.
class DawTextureEngine {
  static final DawTextureEngine instance = DawTextureEngine._();
  DawTextureEngine._();

  // Cache map: Key -> ui.Image
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Shader> _shaderCache = {};

  /// Convert `PanelBackgroundStyle` to `DawTextureType` if applicable.
  static DawTextureType? mapStyleToTexture(PanelBackgroundStyle style) {
    switch (style) {
      case PanelBackgroundStyle.walnut:
        return DawTextureType.walnut;
      case PanelBackgroundStyle.mahogany:
        return DawTextureType.mahogany;
      case PanelBackgroundStyle.blondePine:
        return DawTextureType.blondePine;
      case PanelBackgroundStyle.rosewood:
        return DawTextureType.rosewood;
      case PanelBackgroundStyle.brushedSteel:
        return DawTextureType.brushedSteel;
      case PanelBackgroundStyle.brushedSteelVert:
        return DawTextureType.brushedSteelVert;
      case PanelBackgroundStyle.matteMetal:
        return DawTextureType.matteMetal;
      case PanelBackgroundStyle.grunge:
        return DawTextureType.grunge;
      case PanelBackgroundStyle.tolex:
        return DawTextureType.tolex;
      case PanelBackgroundStyle.carbon:
        return DawTextureType.carbon;
      case PanelBackgroundStyle.mesh:
        return DawTextureType.mesh;
      case PanelBackgroundStyle.dx7Membrane:
        return DawTextureType.dx7Membrane;
      case PanelBackgroundStyle.harpsichordLacquer:
        return DawTextureType.harpsichordLacquer;
      case PanelBackgroundStyle.c64Breadbin:
        return DawTextureType.c64Breadbin;
      case PanelBackgroundStyle.silver:
        return DawTextureType.brushedSteel;
      default:
        return null;
    }
  }

  /// Get or synchronously bake a procedural texture `ui.Image`.
  ui.Image getTextureImage(DawTextureType type, {int size = 256, int seed = 42}) {
    final key = '${type.name}_${size}_$seed';
    if (_imageCache.containsKey(key)) {
      return _imageCache[key]!;
    }

    final image = _bakeProceduralImage(type, size: size, seed: seed);
    _imageCache[key] = image;
    return image;
  }

  /// Get or create an `ImageShader` for repeating textures with optional rotation & scale.
  Shader getTextureShader(
    DawTextureType type, {
    int size = 256,
    int seed = 42,
    double rotationDegrees = 0.0,
    double scale = 1.0,
  }) {
    final key = '${type.name}_${size}_${seed}_${rotationDegrees}_$scale';
    if (_shaderCache.containsKey(key)) {
      return _shaderCache[key]!;
    }

    final image = getTextureImage(type, size: size, seed: seed);
    
    // Matrix4 transform for rotation and scaling inside the shader
    final matrix = Matrix4.identity();
    if (scale != 1.0) {
      matrix.scale(scale, scale);
    }
    if (rotationDegrees != 0.0) {
      final rad = rotationDegrees * math.pi / 180.0;
      matrix.rotateZ(rad);
    }

    final shader = ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      matrix.storage,
    );

    _shaderCache[key] = shader;
    return shader;
  }

  /// Synchronously synthesizes the procedural texture using `ui.PictureRecorder`
  ui.Image _bakeProceduralImage(DawTextureType type, {required int size, required int seed}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    final random = math.Random(seed);

    switch (type) {
      case DawTextureType.walnut:
        _paintSeamlessWoodTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF4A2F1D),
          grainColor1: const Color(0xFF331D0F),
          grainColor2: const Color(0xFF221208),
          highlightColor: const Color(0xFF633F27),
          frequency: 5.0,
        );
        break;

      case DawTextureType.mahogany:
        _paintSeamlessWoodTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF561F17),
          grainColor1: const Color(0xFF3B120C),
          grainColor2: const Color(0xFF240A06),
          highlightColor: const Color(0xFF70281E),
          frequency: 4.0,
        );
        break;

      case DawTextureType.blondePine:
        _paintSeamlessWoodTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFFD6C5A2),
          grainColor1: const Color(0xFFB8A279),
          grainColor2: const Color(0xFF99835A),
          highlightColor: const Color(0xFFE2D6BC),
          frequency: 6.0,
        );
        break;

      case DawTextureType.rosewood:
        _paintSeamlessWoodTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF2B1B17),
          grainColor1: const Color(0xFF1E110E),
          grainColor2: const Color(0xFF120907),
          highlightColor: const Color(0xFF38231E),
          frequency: 7.0,
        );
        break;

      case DawTextureType.brushedSteel:
        _paintSeamlessBrushedMetalTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF4C525D),
          highlightColor: const Color(0xFF8B93A0),
          isVertical: false,
        );
        break;

      case DawTextureType.brushedSteelVert:
        _paintSeamlessBrushedMetalTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF4C525D),
          highlightColor: const Color(0xFF8B93A0),
          isVertical: true,
        );
        break;

      case DawTextureType.matteMetal:
        _paintSeamlessMatteMetalTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF1B1E26),
          speckleColor: const Color(0xFF303644),
        );
        break;

      case DawTextureType.grunge:
        _paintSeamlessGrungeTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF241F1A),
          rustColor: const Color(0xFF4E2C1A),
          patinaColor: const Color(0xFF1C221F),
        );
        break;

      case DawTextureType.tolex:
        _paintSeamlessTolexTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF18181A),
          bumpColor: const Color(0xFF2E2E33),
        );
        break;

      case DawTextureType.carbon:
        _paintSeamlessCarbonFiberTexture(
          canvas,
          size,
          baseColor: const Color(0xFF121418),
          weaveColor: const Color(0xFF282C34),
        );
        break;

      case DawTextureType.mesh:
        _paintSeamlessMeshGrilleTexture(
          canvas,
          size,
          baseColor: const Color(0xFF15171C),
          holeColor: const Color(0xFF08090C),
          rimColor: const Color(0xFF383D48),
        );
        break;

      case DawTextureType.dx7Membrane:
        _paintSeamlessDx7MembraneTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF162220),
          lineColor: const Color(0xFF00E5FF),
          accentColor: const Color(0xFF26A69A),
        );
        break;

      case DawTextureType.harpsichordLacquer:
        _paintSeamlessHarpsichordLacquerTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF110D0A),
          woodGrainColor: const Color(0xFF23160F),
          goldTrimColor: const Color(0xFFD4AF37),
        );
        break;

      case DawTextureType.c64Breadbin:
        _paintSeamlessC64BreadbinTexture(
          canvas,
          size,
          random,
          baseColor: const Color(0xFF2A2622),
          ridgeColor: const Color(0xFF38332C),
          highlightColor: const Color(0xFF4A443D),
        );
        break;
    }

    final picture = recorder.endRecording();
    return picture.toImageSync(size, size);
  }

  // --- 100% MATHEMATICALLY TOROIDAL SEAMLESS GENERATORS ---

  /// Seamless Wood Texture: Uses integer harmonic sine waves for 100% boundary continuity.
  void _paintSeamlessWoodTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color grainColor1,
    required Color grainColor2,
    required Color highlightColor,
    required double frequency,
  }) {
    final double s = size.toDouble();

    // 1. Base solid coat
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Seamless continuous growth rings
    // All coordinates use integer multiples of 2*pi so f(0, y) == f(s, y) and f(x, 0) == f(x, s)
    final ringPaint = Paint()..style = PaintingStyle.stroke;

    for (double y = 0; y < s; y += 2.0) {
      final ty = y / s;
      
      final path = Path();
      for (double x = 0; x <= s; x += 4.0) {
        final tx = x / s;
        
        // Toroidal periodic wave perturbation
        final wave1 = math.sin(tx * 2.0 * math.pi) * 3.0;
        final wave2 = math.cos(tx * 4.0 * math.pi + ty * 2.0 * math.pi) * 1.5;
        final yPos = y + wave1 + wave2;

        if (x == 0) {
          path.moveTo(x, yPos);
        } else {
          path.lineTo(x, yPos);
        }
      }

      final intensity = (math.sin(ty * frequency * 2.0 * math.pi) + 1.0) * 0.5;
      final color = Color.lerp(grainColor1, highlightColor, intensity)!.withValues(alpha: 0.22 + intensity * 0.35);
      ringPaint.color = color;
      ringPaint.strokeWidth = 1.2 + intensity * 1.0;
      canvas.drawPath(path, ringPaint);
    }

    // 3. Continuous longitudinal micro-grain fibers (span from top to bottom seamlessly)
    final fiberPaint = Paint()
      ..color = grainColor2.withValues(alpha: 0.12)
      ..strokeWidth = 0.75;

    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * s;
      final waveOffset = (random.nextDouble() - 0.5) * 2.0;
      final path = Path();
      path.moveTo(x, 0);
      for (double y = 0; y <= s; y += 16.0) {
        final ty = y / s;
        final wx = x + math.sin(ty * 2.0 * math.pi) * waveOffset;
        path.lineTo(wx, y);
      }
      canvas.drawPath(path, fiberPaint);
    }
  }

  /// Seamless Brushed Metal: Hairlines extend edge-to-edge across the tile with zero boundary jumps.
  void _paintSeamlessBrushedMetalTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color highlightColor,
    required bool isVertical,
  }) {
    final double s = size.toDouble();

    // 1. Base metallic background
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Continuous edge-to-edge hairlines
    // By drawing every scratch across the entire tile dimension (0 to s),
    // when the tile repeats in that direction, the line continues seamlessly!
    final scratchPaint = Paint()..strokeWidth = 0.65;
    
    for (int i = 0; i < 650; i++) {
      final isLight = random.nextBool();
      final alpha = 0.03 + random.nextDouble() * 0.09;
      scratchPaint.color = isLight
          ? Colors.white.withValues(alpha: alpha)
          : Colors.black.withValues(alpha: alpha * 1.25);

      final pos = random.nextDouble() * s;

      if (isVertical) {
        // Vertical grain: from y = 0 to y = s
        canvas.drawLine(Offset(pos, 0), Offset(pos, s), scratchPaint);
      } else {
        // Horizontal grain: from x = 0 to x = s
        canvas.drawLine(Offset(0, pos), Offset(s, pos), scratchPaint);
      }
    }
  }

  /// Seamless Matte Sandblast Metal: Uniform Poisson stipple that tiles infinitely.
  void _paintSeamlessMatteMetalTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color speckleColor,
  }) {
    final double s = size.toDouble();

    // 1. Dark matte base
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Uniform non-vignetted sandblast speckles
    final specklePaint = Paint();
    for (int i = 0; i < 2200; i++) {
      final x = random.nextDouble() * s;
      final y = random.nextDouble() * s;
      final isBright = random.nextBool();
      final radius = 0.4 + random.nextDouble() * 0.6;

      specklePaint.color = isBright
          ? speckleColor.withValues(alpha: 0.10 + random.nextDouble() * 0.12)
          : Colors.black.withValues(alpha: 0.12 + random.nextDouble() * 0.15);

      canvas.drawCircle(Offset(x, y), radius, specklePaint);
    }
  }

  /// Seamless Grunge / Weathered Patina: Toroidal periodic noise splotches and wrapped scratches.
  void _paintSeamlessGrungeTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color rustColor,
    required Color patinaColor,
  }) {
    final double s = size.toDouble();

    // 1. Base industrial iron
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Toroidal rust & patina splotches (drawn at (x, y) and wrapped around borders)
    final splotchPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * s;
      final y = random.nextDouble() * s;
      final r = 5.0 + random.nextDouble() * 16.0;
      final isPatina = random.nextDouble() > 0.65;

      splotchPaint.color = isPatina
          ? patinaColor.withValues(alpha: 0.18 + random.nextDouble() * 0.2)
          : rustColor.withValues(alpha: 0.22 + random.nextDouble() * 0.25);

      _drawWrappedCircle(canvas, Offset(x, y), r, splotchPaint, s);
    }

    // 3. Hairline scratches
    final scratchPaint = Paint()..strokeWidth = 0.8;
    for (int i = 0; i < 30; i++) {
      final x1 = random.nextDouble() * s;
      final y1 = random.nextDouble() * s;
      final len = 6.0 + random.nextDouble() * 20.0;
      final angle = random.nextDouble() * math.pi * 2;
      final x2 = x1 + math.cos(angle) * len;
      final y2 = y1 + math.sin(angle) * len;

      scratchPaint.color = Colors.white.withValues(alpha: 0.06 + random.nextDouble() * 0.1);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), scratchPaint);
    }
  }

  /// Seamless Tolex Amp Vinyl: Periodic cellular bumps that tile seamlessly on a 16px grid.
  void _paintSeamlessTolexTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color bumpColor,
  }) {
    final double s = size.toDouble();

    // 1. Vinyl base
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Periodic interlocking lattice (step = 16 divides 256 evenly)
    const step = 16.0;
    final bumpPaint = Paint();
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);

    for (double y = 0; y < s; y += step) {
      final rowOffset = ((y ~/ step) % 2 == 0) ? 0.0 : step * 0.5;
      for (double x = 0; x < s; x += step) {
        final cx = (x + rowOffset) % s;
        final cy = y;
        const r = 3.6;

        // Shadow & Specular bump drawn with toroidal wrapping
        _drawWrappedCircle(canvas, Offset(cx + 0.6, cy + 0.6), r, shadowPaint, s);

        bumpPaint.color = bumpColor.withValues(alpha: 0.45 + (math.sin(cx + cy) * 0.15).abs());
        _drawWrappedCircle(canvas, Offset(cx, cy), r, bumpPaint, s);
      }
    }
  }

  /// Seamless Carbon Fiber 2x2 Twill: Cell size 16px (divides 256 evenly).
  void _paintSeamlessCarbonFiberTexture(
    Canvas canvas,
    int size, {
    required Color baseColor,
    required Color weaveColor,
  }) {
    final double s = size.toDouble();

    // 1. Carbon base
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. 2x2 Twill weave grid
    const cellSize = 16.0;
    final darkPaint = Paint()..color = baseColor.withValues(alpha: 0.9);
    final lightPaint = Paint()..color = weaveColor;
    final highlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);

    for (double y = 0; y < s; y += cellSize) {
      for (double x = 0; x < s; x += cellSize) {
        final isDiagonal = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
        final rect = Rect.fromLTWH(x, y, cellSize, cellSize);

        if (isDiagonal) {
          canvas.drawRect(rect, lightPaint);
          canvas.drawLine(rect.topLeft, rect.bottomRight, highlightPaint);
        } else {
          canvas.drawRect(rect, darkPaint);
        }
      }
    }
  }

  /// Seamless Perforated Mesh Grille: Step 16px (divides 256 evenly).
  void _paintSeamlessMeshGrilleTexture(
    Canvas canvas,
    int size, {
    required Color baseColor,
    required Color holeColor,
    required Color rimColor,
  }) {
    final double s = size.toDouble();

    // 1. Chassis plate
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Hex vent perforations (step 16px)
    const spacing = 16.0;
    const holeRadius = 3.6;
    final holePaint = Paint()..color = holeColor;
    final rimPaint = Paint()
      ..color = rimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (double y = 0; y < s; y += spacing) {
      final xOffset = ((y ~/ spacing) % 2 == 0) ? 0.0 : spacing * 0.5;
      for (double x = 0; x < s; x += spacing) {
        final cx = (x + xOffset) % s;
        final center = Offset(cx, y);
        _drawWrappedCircle(canvas, center + const Offset(0.5, 0.5), holeRadius + 0.3, highlightPaint, s);
        _drawWrappedCircle(canvas, center, holeRadius, holePaint, s);
        _drawWrappedCircle(canvas, center, holeRadius, rimPaint, s);
      }
    }
  }

  /// Helper to draw a circle with toroidal border wrapping across tile dimensions
  void _drawWrappedCircle(Canvas canvas, Offset center, double radius, Paint paint, double size) {
    canvas.drawCircle(center, radius, paint);
    // If overlapping left or right boundary
    if (center.dx - radius < 0) {
      canvas.drawCircle(Offset(center.dx + size, center.dy), radius, paint);
    } else if (center.dx + radius > size) {
      canvas.drawCircle(Offset(center.dx - size, center.dy), radius, paint);
    }
    // If overlapping top or bottom boundary
    if (center.dy - radius < 0) {
      canvas.drawCircle(Offset(center.dx, center.dy + size), radius, paint);
    } else if (center.dy + radius > size) {
      canvas.drawCircle(Offset(center.dx, center.dy - size), radius, paint);
    }
  }

  /// Seamless 1983 DX7 Synthetic Membrane Texture:
  /// Charcoal-teal matte polymer with micro-stipple and subtle technical membrane lines.
  void _paintSeamlessDx7MembraneTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color lineColor,
    required Color accentColor,
  }) {
    final double s = size.toDouble();

    // 1. Matte charcoal-teal base
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Fine synthetic matte stipple (toroidal periodic noise)
    final noisePaint = Paint()..style = PaintingStyle.fill;
    for (int y = 0; y < size; y += 4) {
      final ty = y / s;
      for (int x = 0; x < size; x += 4) {
        final tx = x / s;
        final val = math.sin(tx * 32.0 * math.pi) * math.cos(ty * 32.0 * math.pi);
        if (val > 0.4) {
          noisePaint.color = Colors.white.withValues(alpha: 0.035);
          canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.5, 1.5), noisePaint);
        } else if (val < -0.4) {
          noisePaint.color = Colors.black.withValues(alpha: 0.08);
          canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.5, 1.5), noisePaint);
        }
      }
    }

    // 3. Subtle retro Yamaha cyan membrane grid accent lines (every 64px)
    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.09)
      ..strokeWidth = 0.8;
    for (double step = 0; step < s; step += 64.0) {
      canvas.drawLine(Offset(0, step), Offset(s, step), gridPaint);
      canvas.drawLine(Offset(step, 0), Offset(step, s), gridPaint);
    }
  }

  /// Seamless Baroque Harpsichord Lacquer & Gilded Trim Texture:
  /// Deep black piano lacquer with delicate burl wood under-glow and antique gold trim borders.
  void _paintSeamlessHarpsichordLacquerTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color woodGrainColor,
    required Color goldTrimColor,
  }) {
    final double s = size.toDouble();

    // 1. Deep antique black/ebony lacquer base
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Warm wood burl under-glow (smooth 2D periodic harmonic waves)
    final burlPaint = Paint()..style = PaintingStyle.fill;
    for (double y = 0; y < s; y += 8.0) {
      final ty = y / s;
      for (double x = 0; x < s; x += 8.0) {
        final tx = x / s;
        final wave = (math.sin(tx * 2.0 * math.pi) * math.cos(ty * 2.0 * math.pi) +
                math.sin(tx * 4.0 * math.pi + ty * 4.0 * math.pi) * 0.5 +
                1.5) /
            3.0;
        burlPaint.color = woodGrainColor.withValues(alpha: 0.15 + wave * 0.35);
        canvas.drawRect(Rect.fromLTWH(x, y, 8.0, 8.0), burlPaint);
      }
    }

    // 3. Antique gold hairline pinstripe trim (seamless border perimeter)
    final goldPaint = Paint()
      ..color = goldTrimColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(2, 2, s - 4, s - 4), goldPaint);
  }

  /// Seamless Commodore 64 Breadbin Texture:
  /// Warm vintage matte brown-beige casing with subtle horizontal ventilation ridges and retro micro-stipple.
  void _paintSeamlessC64BreadbinTexture(
    Canvas canvas,
    int size,
    math.Random random, {
    required Color baseColor,
    required Color ridgeColor,
    required Color highlightColor,
  }) {
    final double s = size.toDouble();

    // 1. Warm vintage chassis base
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = baseColor);

    // 2. Horizontal ventilation cooling micro-ridges (seamless periodic bands every 16px)
    final ridgePaint = Paint()..style = PaintingStyle.fill;
    final hiPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.75;

    for (double y = 0; y < s; y += 16.0) {
      ridgePaint.color = ridgeColor.withValues(alpha: 0.35);
      canvas.drawRect(Rect.fromLTWH(0, y, s, 7.0), ridgePaint);

      // Highlight line on top of each ridge
      hiPaint.color = highlightColor.withValues(alpha: 0.25);
      canvas.drawLine(Offset(0, y), Offset(s, y), hiPaint);

      // Shadow line beneath each ridge
      hiPaint.color = Colors.black.withValues(alpha: 0.45);
      canvas.drawLine(Offset(0, y + 7.0), Offset(s, y + 7.0), hiPaint);
    }

    // 3. Toroidal matte plastic micro-grain stipple
    final noisePaint = Paint()..style = PaintingStyle.fill;
    for (int y = 0; y < size; y += 4) {
      final ty = y / s;
      for (int x = 0; x < size; x += 4) {
        final tx = x / s;
        final val = math.sin(tx * 32.0 * math.pi) * math.cos(ty * 32.0 * math.pi);
        if (val > 0.45) {
          noisePaint.color = highlightColor.withValues(alpha: 0.04);
          canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.5, 1.5), noisePaint);
        } else if (val < -0.45) {
          noisePaint.color = Colors.black.withValues(alpha: 0.06);
          canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.5, 1.5), noisePaint);
        }
      }
    }
  }
}

/// A versatile Flutter widget that renders procedural DAW textures with optional
/// rotation, scale, border radius, inner bevels, and vintage wooden side-cheeks.
class DawTexturedContainer extends StatelessWidget {
  final DawTextureType? texture;
  final PanelBackgroundStyle? backgroundStyle;
  final double textureRotation; // in degrees (0, 90, 180, etc.)
  final double textureScale;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Widget? child;
  final double? cornerRadius;
  final String? sideCheeks; // 'walnut', 'mahogany', 'blondePine', 'rosewood', 'brushedSteel', etc.
  final double sideCheekWidth;

  const DawTexturedContainer({
    super.key,
    this.texture,
    this.backgroundStyle,
    this.textureRotation = 0.0,
    this.textureScale = 1.0,
    this.color,
    this.borderRadius,
    this.border,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.child,
    this.cornerRadius,
    this.sideCheeks,
    this.sideCheekWidth = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTexture = texture ??
        (backgroundStyle != null ? DawTextureEngine.mapStyleToTexture(backgroundStyle!) : null);

    final hasSideCheeks = sideCheeks != null && sideCheeks!.isNotEmpty && sideCheeks!.toLowerCase() != 'none';

    final effectiveBorderRadius = borderRadius ??
        (cornerRadius != null
            ? BorderRadius.circular(cornerRadius!)
            : (hasSideCheeks ? BorderRadius.zero : BorderRadius.circular(8)));

    Widget content = Container(
      padding: padding,
      child: child,
    );

    if (effectiveTexture != null) {
      content = CustomPaint(
        painter: _DawTexturePainter(
          texture: effectiveTexture,
          rotationDegrees: textureRotation,
          scale: textureScale,
          tintColor: color,
          borderRadius: effectiveBorderRadius,
          border: border,
        ),
        child: content,
      );
    } else if (color != null || borderRadius != null || border != null) {
      content = Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: effectiveBorderRadius,
          border: border,
        ),
        child: content,
      );
    }

    if (hasSideCheeks) {
      final cheekType = _parseSideCheekType(sideCheeks!);
      return Container(
        margin: margin,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Wood Cheek
              _buildSideCheek(cheekType, isLeft: true),
              // Center Chassis
              Expanded(child: content),
              // Right Wood Cheek
              _buildSideCheek(cheekType, isLeft: false),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      child: content,
    );
  }

  DawTextureType _parseSideCheekType(String cheek) {
    final clean = cheek.toLowerCase().trim();
    if (clean.contains('steel') || clean.contains('aluminum') || clean.contains('silver') || clean.contains('metal_vert')) {
      return DawTextureType.brushedSteelVert;
    }
    if (clean.contains('matte') || clean.contains('anodized')) {
      return DawTextureType.matteMetal;
    }
    if (clean.contains('tolex') || clean.contains('vinyl')) {
      return DawTextureType.tolex;
    }
    if (clean.contains('carbon')) {
      return DawTextureType.carbon;
    }
    if (clean.contains('grunge') || clean.contains('rust') || clean.contains('weathered')) {
      return DawTextureType.grunge;
    }
    if (clean.contains('mahogany')) return DawTextureType.mahogany;
    if (clean.contains('blonde') || clean.contains('pine')) return DawTextureType.blondePine;
    if (clean.contains('rosewood') || clean.contains('dark')) return DawTextureType.rosewood;
    return DawTextureType.walnut;
  }

  Widget _buildSideCheek(DawTextureType cheekType, {required bool isLeft}) {
    return Container(
      width: sideCheekWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(6) : Radius.zero,
          right: !isLeft ? const Radius.circular(6) : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: Offset(isLeft ? -2 : 2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(6) : Radius.zero,
          right: !isLeft ? const Radius.circular(6) : Radius.zero,
        ),
        child: CustomPaint(
          size: Size.infinite,
          painter: _DawTexturePainter(
            texture: cheekType,
            rotationDegrees: 90.0, // Vertical grain for side-panels
            scale: 1.0,
            borderRadius: BorderRadius.horizontal(
              left: isLeft ? const Radius.circular(6) : Radius.zero,
              right: !isLeft ? const Radius.circular(6) : Radius.zero,
            ),
            border: Border(
              left: isLeft ? BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1.0) : BorderSide.none,
              right: !isLeft ? BorderSide(color: Colors.black.withValues(alpha: 0.5), width: 1.0) : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _DawTexturePainter extends CustomPainter {
  final DawTextureType texture;
  final double rotationDegrees;
  final double scale;
  final Color? tintColor;
  final BorderRadius borderRadius;
  final Border? border;

  _DawTexturePainter({
    required this.texture,
    required this.rotationDegrees,
    required this.scale,
    this.tintColor,
    required this.borderRadius,
    this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    canvas.save();
    canvas.clipRRect(rrect);

    // 1. Tiled Micro-Grain Shader (100% Seamless)
    final shader = DawTextureEngine.instance.getTextureShader(
      texture,
      rotationDegrees: rotationDegrees,
      scale: scale,
    );

    final texturePaint = Paint()..shader = shader;
    if (tintColor != null) {
      texturePaint.colorFilter = ColorFilter.mode(
        tintColor!.withValues(alpha: 0.35),
        BlendMode.srcATop,
      );
    }

    canvas.drawRRect(rrect, texturePaint);

    // 2. Panel-Wide Continuous Lighting & Sheen (Rendered continuously across the FULL panel size)
    if (texture == DawTextureType.brushedSteel || texture == DawTextureType.brushedSteelVert) {
      // Continuous Anisotropic Specular Highlight sweeping across the entire panel
      final isVert = texture == DawTextureType.brushedSteelVert || rotationDegrees == 90.0;
      final anisoPaint = Paint()
        ..shader = LinearGradient(
          begin: isVert ? Alignment.topCenter : Alignment.centerLeft,
          end: isVert ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.18),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.20),
          ],
          stops: const [0.0, 0.28, 0.50, 0.75, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect, anisoPaint);
    } else if (texture == DawTextureType.walnut ||
        texture == DawTextureType.mahogany ||
        texture == DawTextureType.blondePine ||
        texture == DawTextureType.rosewood) {
      // Continuous Satin Wood Lacquer Specular Reflection
      final woodSheenPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.09),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect, woodSheenPaint);
    } else if (texture == DawTextureType.grunge) {
      // Continuous Industrial Soot Burn & Rust Perimeter Vignette
      final grungeVignette = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
        ).createShader(rect);
      canvas.drawRRect(rrect, grungeVignette);
    }

    // 3. Beveled Inner Chassis Shadow / Perimeter Bevel Highlight
    final topBevelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.25),
        ],
        stops: const [0.0, 0.08, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, topBevelPaint);

    canvas.restore();

    // 4. Outer border if present
    if (border != null) {
      border!.paint(canvas, rect, borderRadius: borderRadius);
    }
  }

  @override
  bool shouldRepaint(covariant _DawTexturePainter oldDelegate) {
    return oldDelegate.texture != texture ||
        oldDelegate.rotationDegrees != rotationDegrees ||
        oldDelegate.scale != scale ||
        oldDelegate.tintColor != tintColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.border != border;
  }
}
