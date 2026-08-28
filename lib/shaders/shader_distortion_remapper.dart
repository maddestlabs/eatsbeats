import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps a widget tree and transforms incoming mouse / touch hit-test coordinates
/// so that pointer interactions align with visual shader curvature distortions.
class ShaderDistortionPointerRemapper extends SingleChildRenderObjectWidget {
  /// Normalized UV coordinate transformation function [0..1] -> [0..1].
  /// If null or returns identity, no hit-test transformation is applied.
  final Offset Function(Offset normalizedUv)? uvDistortionMap;

  const ShaderDistortionPointerRemapper({
    super.key,
    required this.uvDistortionMap,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDistortionRemapper(uvDistortionMap);
  }

  @override
  void updateRenderObject(BuildContext context, RenderDistortionRemapper renderObject) {
    renderObject.uvDistortionMap = uvDistortionMap;
  }
}

class RenderDistortionRemapper extends RenderProxyBox {
  Offset Function(Offset normalizedUv)? _uvDistortionMap;

  RenderDistortionRemapper(this._uvDistortionMap);

  set uvDistortionMap(Offset Function(Offset normalizedUv)? value) {
    if (_uvDistortionMap != value) {
      _uvDistortionMap = value;
      markNeedsPaint();
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.isEmpty) return false;

    if (_uvDistortionMap == null) {
      return super.hitTest(result, position: position);
    }

    // 1. Normalize physical mouse / touch position to [0.0 .. 1.0]
    final uv = Offset(
      (position.dx / size.width).clamp(0.0, 1.0),
      (position.dy / size.height).clamp(0.0, 1.0),
    );

    // 2. Apply the exact forward barrel curvature equation from the shader
    final warpedUv = _uvDistortionMap!(uv);

    // If click lands on the dark outer bezel casing outside the active tube
    if (warpedUv.dx < 0.0 || warpedUv.dx > 1.0 || warpedUv.dy < 0.0 || warpedUv.dy > 1.0) {
      return false;
    }

    // 3. Convert warped coordinate back into child's pixel space
    final correctedPosition = Offset(
      warpedUv.dx * size.width,
      warpedUv.dy * size.height,
    );

    // 4. Dispatch the hit test with the corrected position to child widget tree
    if (child != null) {
      final isHit = child!.hitTest(result, position: correctedPosition);
      if (isHit) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }

    return false;
  }
}
