import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';
import 'arranger_context_inspector.dart';

class TrackPropertiesPullout extends StatelessWidget {
  final DawState dawState;
  final bool isExpanded;
  final double propertiesWidth;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onClose;
  final InspectorTab initialTab;

  static const double minPropertiesWidth = 290.0;
  static const double defaultPropertiesWidth = 290.0;
  static const double maxPropertiesWidth = 720.0;
  static const double pullTabWidth = 24.0;

  const TrackPropertiesPullout({
    super.key,
    required this.dawState,
    required this.isExpanded,
    required this.propertiesWidth,
    required this.onToggleExpand,
    required this.onExpansionChanged,
    required this.onWidthChanged,
    required this.onClose,
    this.initialTab = InspectorTab.track,
  });

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final activeTrack = dawState.activeTrack;
    final trackColor = activeTrack.color;

    return Container(
      decoration: BoxDecoration(
        color: isGrungy ? const Color(0xFF1B1815) : EatsTheme.panelBackground,
        border: Border(
          left: BorderSide(
            color: isGrungy ? const Color(0xFF4A423A) : EatsTheme.panelHeader,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Vertical Pull Tab Strip (24px wide, full height)
          Tooltip(
            message: isExpanded ? 'Collapse Track Properties' : 'Open Properties Panel',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleExpand,
              onHorizontalDragUpdate: (details) {
                if (!isExpanded && details.delta.dx < -2) {
                  onExpansionChanged(true);
                } else if (isExpanded) {
                  final newWidth = (propertiesWidth - details.delta.dx)
                      .clamp(minPropertiesWidth, maxPropertiesWidth);
                  onWidthChanged(newWidth);
                  if (newWidth <= minPropertiesWidth + 10 && details.delta.dx > 5) {
                    onExpansionChanged(false);
                    onWidthChanged(defaultPropertiesWidth);
                  }
                }
              },
              child: Container(
                width: pullTabWidth - 1.5,
                height: double.infinity,
                color: isGrungy ? const Color(0xFF28231E) : EatsTheme.panelHeader,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centered vertical visual pill drag handle
                    Container(
                      width: 5,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isGrungy ? const Color(0xFF8C7A6B) : EatsTheme.textMuted,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Top: Active track color circle
                    Positioned(
                      top: 14,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: trackColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: trackColor.withOpacity(0.7), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),

                    // Bottom: Arrow indicator
                    Positioned(
                      bottom: 12,
                      child: Icon(
                        isExpanded ? Icons.chevron_right : Icons.chevron_left,
                        size: 16,
                        color: EatsTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded Vertical Properties Inspector Body
          if (isExpanded)
            Expanded(
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: onClose,
                initialTab: initialTab,
                onResize: (deltaX) {
                  final newWidth = (propertiesWidth - deltaX)
                      .clamp(minPropertiesWidth, maxPropertiesWidth);
                  onWidthChanged(newWidth);
                },
              ),
            ),
        ],
      ),
    );
  }
}
