import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that absorbs [RenderObject.showOnScreen] requests from its descendants,
/// preventing internal child scrolling (such as text selection auto-scrolling in a [TextField])
/// from bubbling up and inadvertently scrolling ancestor scrollables (such as an outer
/// [SingleChildScrollView]).
class ShowOnScreenAbsorber extends SingleChildRenderObjectWidget {
  const ShowOnScreenAbsorber({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderShowOnScreenAbsorber();
}

class _RenderShowOnScreenAbsorber extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    // Intentionally absorbed: do not propagate showOnScreen calls to ancestor scrollables.
  }
}
