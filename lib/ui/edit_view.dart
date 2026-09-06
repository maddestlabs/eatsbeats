import 'package:flutter/material.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'piano_roll_view.dart';
import 'score/score_view.dart';
import 'tracker_view.dart';
import 'script_view.dart';
import 'widgets/skeuomorphic_hardware_button.dart';

class EditView extends StatelessWidget {
  final DawState dawState;

  const EditView({super.key, required this.dawState});

  @override
  Widget build(BuildContext context) {
    final track = dawState.activeTrack;
    final isMobile = MediaQuery.of(context).size.width < 600;

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

        // Main Editor Canvas
        Expanded(
          child: _buildActiveView(track.activeView),
        ),
      ],
    );
  }

  Widget _buildActiveView(MusicViewType activeView) {
    switch (activeView) {
      case MusicViewType.tracker:
        return TrackerView(dawState: dawState);
      case MusicViewType.script:
        return ScriptView(dawState: dawState);
      case MusicViewType.score:
        return ScoreView(dawState: dawState);
      case MusicViewType.pianoRoll:
        return PianoRollView(dawState: dawState);
    }
  }
}
