import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/ui/widgets/code_editor_scroll_controller.dart';

void main() {
  testWidgets('CodeEditorScrollController suppresses high-frequency opposing oscillation jumps', (tester) async {
    final controller = CodeEditorScrollController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 300,
          child: SingleChildScrollView(
            controller: controller,
            child: const SizedBox(height: 3000),
          ),
        ),
      ),
    );

    // Initial position
    expect(controller.offset, 0.0);

    // User or autoscroll moves forward to 500
    controller.jumpTo(500.0);
    expect(controller.offset, 500.0);

    // Autoscroll moves slightly further forward to 520
    controller.jumpTo(520.0);
    expect(controller.offset, 520.0);

    // Bug simulation: within 10ms, a large opposing reverse jump of 350px back towards the selection base is requested
    controller.jumpTo(170.0);

    // The opposing reverse oscillation jump must be suppressed, maintaining forward selection!
    expect(controller.offset, 520.0);

    // Autoscroll continues forward to 540
    controller.jumpTo(540.0);
    expect(controller.offset, 540.0);

    controller.dispose();
  });
}
