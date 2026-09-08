import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'piano_roll_view.dart';
import 'score/score_view.dart';
import 'tracker_view.dart';
import 'script_view.dart';
import 'widgets/note_inspector_sidebar.dart';
import 'widgets/skeuomorphic_hardware_button.dart';

class EditView extends StatelessWidget {
  final DawState dawState;

  const EditView({super.key, required this.dawState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dawState,
      builder: (context, _) {
        final track = dawState.activeTrack;
        final isMobile = MediaQuery.of(context).size.width < 600;
        final isBrowserOpen = dawState.isBrowserOpen;

        return Column(
          children: [
            // Editor Header View Switcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: EatsTheme.panelHeader,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: track.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isMobile ? track.name.toUpperCase() : 'EDITING: ${track.name.toUpperCase()}',
                      style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),

                  // Ghost Notes Opacity Control (Piano Roll & Score Views)
                  if (track.activeView == MusicViewType.pianoRoll || track.activeView == MusicViewType.score) ...[
                    _GhostNotesControl(dawState: dawState, isMobile: isMobile),
                    const SizedBox(width: 8),
                  ],

                  // View Switcher Buttons (Right-aligned, Icon-only on Mobile)
                  SkeuomorphicHardwareButton(
                    label: isMobile ? null : 'PIANO ROLL',
                    icon: Icons.piano,
                    isActive: track.activeView == MusicViewType.pianoRoll,
                    activeColor: EatsTheme.primaryCyan,
                    onTap: () => dawState.setTrackActiveView(track, MusicViewType.pianoRoll),
                    height: 32,
                  ),
                  const SizedBox(width: 6),
                  SkeuomorphicHardwareButton(
                    label: isMobile ? null : 'TRACKER',
                    icon: Icons.view_column,
                    isActive: track.activeView == MusicViewType.tracker,
                    activeColor: EatsTheme.secondaryMagenta,
                    onTap: () => dawState.setTrackActiveView(track, MusicViewType.tracker),
                    height: 32,
                  ),
                  const SizedBox(width: 6),
                  SkeuomorphicHardwareButton(
                    label: isMobile ? null : 'SCORE',
                    icon: Icons.music_note,
                    isActive: track.activeView == MusicViewType.score,
                    activeColor: EatsTheme.secondaryMagenta,
                    onTap: () => dawState.setTrackActiveView(track, MusicViewType.score),
                    height: 32,
                  ),
                  const SizedBox(width: 6),
                  SkeuomorphicHardwareButton(
                    label: isMobile ? null : 'SCRIPT',
                    icon: Icons.code,
                    isActive: track.activeView == MusicViewType.script,
                    activeColor: EatsTheme.primaryCyan,
                    onTap: () => dawState.setTrackActiveView(track, MusicViewType.script),
                    height: 32,
                  ),
                ],
              ),
            ),

            // Main Editor Canvas & Persistent Selection Sidebar
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildActiveView(track.activeView),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.fastOutSlowIn,
                    top: 0,
                    bottom: 0,
                    right: track.hasSelectedNotes
                        ? (isBrowserOpen ? 320.0 : 0.0)
                        : -295.0,
                    width: 275,
                    child: RepaintBoundary(
                      child: track.hasSelectedNotes
                          ? NoteInspectorSidebar(
                              dawState: dawState,
                              track: track,
                              snap: dawState.quantizeSnap,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveView(MusicViewType activeView) {
    final track = dawState.activeTrack;
    switch (activeView) {
      case MusicViewType.tracker:
        return TrackerView(key: ValueKey('tracker_${track.id}'), dawState: dawState);
      case MusicViewType.script:
        return ScriptView(key: ValueKey('script_${track.id}'), dawState: dawState);
      case MusicViewType.score:
        return ScoreView(key: ValueKey('score_${track.id}'), dawState: dawState);
      case MusicViewType.pianoRoll:
        return PianoRollView(key: ValueKey('piano_roll_${track.id}'), dawState: dawState);
    }
  }
}

class _GhostNotesControl extends StatefulWidget {
  final DawState dawState;
  final bool isMobile;

  const _GhostNotesControl({
    required this.dawState,
    required this.isMobile,
  });

  @override
  State<_GhostNotesControl> createState() => _GhostNotesControlState();
}

class _GhostNotesControlState extends State<_GhostNotesControl> {
  double _lastNonZeroOpacity = 0.35;

  void _toggleGhostNotes() {
    final current = widget.dawState.ghostNotesOpacity;
    if (current > 0.0) {
      _lastNonZeroOpacity = current;
      widget.dawState.setGhostNotesOpacity(0.0);
    } else {
      widget.dawState.setGhostNotesOpacity(_lastNonZeroOpacity > 0 ? _lastNonZeroOpacity : 0.35);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.dawState.isGhostNotesEnabled;
    final opacity = widget.dawState.ghostNotesOpacity;
    final percentText = opacity <= 0.0 ? 'OFF' : '${(opacity * 100).round()}%';

    if (widget.isMobile) {
      return Tooltip(
        message: 'Ghost Notes (Background Tracks): $percentText (Tap to toggle)',
        child: InkWell(
          onTap: _toggleGhostNotes,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isEnabled
                  ? EatsTheme.primaryCyan.withValues(alpha: 0.15)
                  : EatsTheme.backgroundDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isEnabled
                    ? EatsTheme.primaryCyan.withValues(alpha: 0.6)
                    : EatsTheme.lcdBorder.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 14,
                  color: isEnabled ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  percentText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isEnabled ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: EatsTheme.backgroundDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEnabled
              ? EatsTheme.primaryCyan.withValues(alpha: 0.55)
              : EatsTheme.lcdBorder.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: EatsTheme.primaryCyan.withValues(alpha: 0.12),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: isEnabled ? 'Click to disable Ghost Notes' : 'Click to enable Ghost Notes',
            child: InkWell(
              onTap: _toggleGhostNotes,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEnabled ? Icons.layers : Icons.layers_outlined,
                      size: 15,
                      color: isEnabled ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'GHOST',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: isEnabled ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 75,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                activeTrackColor: EatsTheme.primaryCyan,
                inactiveTrackColor: EatsTheme.lcdBorder.withValues(alpha: 0.4),
                thumbColor: isEnabled ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                overlayColor: EatsTheme.primaryCyan.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: opacity,
                min: 0.0,
                max: 1.0,
                onChanged: (val) {
                  if (val > 0.0) {
                    _lastNonZeroOpacity = val;
                  }
                  widget.dawState.setGhostNotesOpacity(val);
                },
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              percentText,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: EatsTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
