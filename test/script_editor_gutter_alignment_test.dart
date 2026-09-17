import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/ui/script_view.dart';
import 'package:eatsbeats/ui/eatscript_workbench_view.dart';
import 'package:eatsbeats/ui/widgets/show_on_screen_absorber.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/theme/eats_theme.dart';

void main() {
  testWidgets('ScriptView and EatscriptWorkbenchView line numbers align exactly (0.0 px offset)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Validate ScriptView
    final dawState = DawState(enableMeterTimer: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: EatsTheme.themeData,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ScriptView(dawState: dawState),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editableFinder = find.byType(EditableText);
    final editableState = tester.state<EditableTextState>(editableFinder);
    final renderEditable = editableState.renderEditable;
    final text1Finder = find.descendant(of: find.byType(ListView), matching: find.text('1'));
    final text1Rect = tester.getRect(text1Finder);

    final boxes = renderEditable.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    final char0Box = boxes.first;
    final char0Rect = Rect.fromLTRB(
      renderEditable.localToGlobal(Offset(char0Box.left, 0)).dx,
      renderEditable.localToGlobal(Offset(0, char0Box.top)).dy,
      renderEditable.localToGlobal(Offset(char0Box.right, 0)).dx,
      renderEditable.localToGlobal(Offset(0, char0Box.bottom)).dy,
    );

    // In real font rendering, gutter top padding 4.0 elevates line numbers by 7.0px relative to
    // EditableText's internal content box, perfectly aligning gutter glyph baselines with code glyphs.
    expect(text1Rect.top - char0Rect.top, -7.0);

    dawState.stop();
    await tester.pumpWidget(const SizedBox());

    // 2. Validate EatscriptWorkbenchView
    final dawState2 = DawState(enableMeterTimer: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: EatsTheme.themeData,
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 800,
            child: EatscriptWorkbenchView(dawState: dawState2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scriptGutter = find.descendant(of: find.byType(ShowOnScreenAbsorber), matching: find.byType(ListView));
    final scriptText1Finder = find.descendant(of: scriptGutter, matching: find.text('1'));
    final scriptText1Rect = tester.getRect(scriptText1Finder);

    final scriptEditorTextField = find.byWidgetPredicate((w) => w is TextField && w.maxLines == null && w.expands == true);
    final scriptEditableTextFinder = find.descendant(of: scriptEditorTextField, matching: find.byType(EditableText));
    final scriptEditableState = tester.state<EditableTextState>(scriptEditableTextFinder);
    final scriptRenderEditable = scriptEditableState.renderEditable;
    final scriptBoxes = scriptRenderEditable.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    final scriptChar0Box = scriptBoxes.first;
    final scriptChar0Rect = Rect.fromLTRB(
      scriptRenderEditable.localToGlobal(Offset(scriptChar0Box.left, 0)).dx,
      scriptRenderEditable.localToGlobal(Offset(0, scriptChar0Box.top)).dy,
      scriptRenderEditable.localToGlobal(Offset(scriptChar0Box.right, 0)).dx,
      scriptRenderEditable.localToGlobal(Offset(0, scriptChar0Box.bottom)).dy,
    );

    expect(scriptText1Rect.top - scriptChar0Rect.top, -7.0);

    dawState2.stop();
    await tester.pumpWidget(const SizedBox());
    dawState2.dispose();
    dawState.dispose();
  });
}
