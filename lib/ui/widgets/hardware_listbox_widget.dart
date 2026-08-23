import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

/// A skeuomorphic vintage hardware LCD/VFD preset and waveform listbox widget.
/// Supports direct selection, smooth mousewheel/drag scrolling, and stepper buttons.
class HardwareListBoxWidget extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;
  final String paramName;
  final String? label;
  final List<String> options;
  final double width;
  final double height;
  final Color accentColor;
  final ValueChanged<int>? onSelectionChanged;

  const HardwareListBoxWidget({
    super.key,
    required this.dawState,
    required this.track,
    required this.paramName,
    this.label,
    required this.options,
    this.width = 160,
    this.height = 100,
    required this.accentColor,
    this.onSelectionChanged,
  });

  @override
  State<HardwareListBoxWidget> createState() => _HardwareListBoxWidgetState();
}

class _HardwareListBoxWidgetState extends State<HardwareListBoxWidget> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: false));
  }

  @override
  void didUpdateWidget(covariant HardwareListBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.luaParams[oldWidget.paramName] != widget.track.luaParams[widget.paramName] ||
        oldWidget.paramName != widget.paramName) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: true));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    final rawVal = widget.track.luaParams[widget.paramName] ?? 0.0;
    return rawVal.round().clamp(0, widget.options.isEmpty ? 0 : widget.options.length - 1);
  }

  void _scrollToSelected({bool animate = true}) {
    if (!_scrollController.hasClients || widget.options.isEmpty) return;
    const itemHeight = 24.0;
    final targetOffset = (_selectedIndex * itemHeight) - (widget.height / 2) + (itemHeight / 2);
    final clamped = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  void _selectIndex(int index) {
    if (index < 0 || index >= widget.options.length) return;
    widget.dawState.beginHistoryTransaction(
      '${widget.paramName} (${widget.options[index]})',
      icon: Icons.list,
    );
    widget.track.luaParams[widget.paramName] = index.toDouble();
    widget.dawState.updateLuaParam(widget.paramName, index.toDouble());
    widget.dawState.commitHistoryTransaction();
    widget.onSelectionChanged?.call(index);
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: true));
    }
  }

  void _step(int delta) {
    final next = (_selectedIndex + delta).clamp(0, widget.options.length - 1);
    _selectIndex(next);
  }

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final accent = widget.accentColor;

    return Container(
      width: widget.width,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Optional Header Label Strip
          if (widget.label != null && widget.label!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: accent.withOpacity(0.8), blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.label!.toUpperCase(),
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Current index badge (e.g. 02/11)
                  Text(
                    '${(_selectedIndex + 1).toString().padLeft(2, '0')}/${widget.options.length.toString().padLeft(2, '0')}',
                    style: EatsTheme.getDisplayFontStyle(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Main Hardware LCD Recessed Screen with Glass Enclosure
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: isGrungy ? const Color(0xFF14110E) : const Color(0xFF0D1017),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isGrungy ? const Color(0xFF3B332A) : EatsTheme.panelHeader,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.7),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        // Listbox Scroll Items
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              scrollbarTheme: ScrollbarThemeData(
                                thumbColor: MaterialStateProperty.all(accent.withOpacity(0.6)),
                                trackColor: MaterialStateProperty.all(Colors.black38),
                                thickness: MaterialStateProperty.all(4),
                                radius: const Radius.circular(2),
                              ),
                            ),
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                itemCount: widget.options.length,
                                itemExtent: 24,
                                itemBuilder: (context, idx) {
                                  final isSelected = idx == _selectedIndex;
                                  final text = widget.options[idx];

                                  return InkWell(
                                    onTap: () => _selectIndex(idx),
                                    child: Container(
                                      height: 24,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accent.withOpacity(0.22)
                                            : Colors.transparent,
                                        border: isSelected
                                            ? Border(
                                                left: BorderSide(color: accent, width: 3),
                                                bottom: BorderSide(
                                                  color: accent.withOpacity(0.3),
                                                  width: 0.8,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          if (isSelected) ...[
                                            Icon(
                                              Icons.play_arrow,
                                              size: 10,
                                              color: accent,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Expanded(
                                            child: Text(
                                              text,
                                              style: EatsTheme.getPrimaryFontStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : EatsTheme.textSecondary,
                                                fontSize: 10.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Mini Stepper Buttons on Right Edge
                        Container(
                          width: 18,
                          decoration: BoxDecoration(
                            color: isGrungy ? const Color(0xFF1E1A16) : EatsTheme.panelHeader,
                            border: Border(
                              left: BorderSide(
                                color: isGrungy ? const Color(0xFF332B23) : const Color(0xFF202632),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _step(-1),
                                  child: Center(
                                    child: Icon(
                                      Icons.keyboard_arrow_up,
                                      size: 14,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: isGrungy ? const Color(0xFF332B23) : const Color(0xFF202632),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _step(1),
                                  child: Center(
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 14,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Glossy Glass Reflection Overlay (CRT Scanlines & Specular Glare)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ListBoxGlassReflectionPainter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListBoxGlassReflectionPainter extends CustomPainter {
  const _ListBoxGlassReflectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Curved Glass Specular Glare Streak Reflection
    final glarePath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.75, 0)
      ..lineTo(0, size.height * 0.85)
      ..close();
    canvas.drawPath(
      glarePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.15), Colors.transparent],
        ).createShader(Offset.zero & size),
    );

    // 2. CRT Micro-Scanlines
    final scanlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..strokeWidth = 1.0;
    for (double y = 1; y < size.height; y += 2.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // 3. Dark Recessed Glass Inner Bezel Border Shadow
    final bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black.withOpacity(0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      bezelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
