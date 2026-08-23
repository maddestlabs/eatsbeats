import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'modular_fx_rack_widget.dart';

void showFxRackDialog(BuildContext context, DawState dawState, TrackChannel track) {
  showDialog(
    context: context,
    builder: (context) {
      return ListenableBuilder(
        listenable: dawState,
        builder: (context, _) {
          return Dialog(
            backgroundColor: EatsTheme.panelBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: track.color, width: 2),
            ),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(track.iconData, size: 16, color: track.color),
                      const SizedBox(width: 6),
                      Text(
                        'FX INSERT RACK: ${track.name.toUpperCase()}',
                        style: EatsTheme.getPrimaryFontStyle(
                          color: EatsTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: EatsTheme.textMuted, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: ModularFxRackWidget(
                        dawState: dawState,
                        track: track,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
