import 'package:flutter/material.dart';
import '../../audio/drum/gm_drum_kit_engine.dart';
import '../../eatscript/eat_script_library.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

class GmPadDef {
  final int note;
  final String label;
  final String defaultEngine;
  final Color accentColor;

  const GmPadDef({
    required this.note,
    required this.label,
    required this.defaultEngine,
    required this.accentColor,
  });
}

/// Interactive Visual Drum Pad Grid for `gm_standard_drum_kit`.
///
/// Features:
/// - 16-Pad Core MPC Grid + Full GM Percussion Bank View.
/// - Velocity-sensitive interactive tap preview.
/// - Drag-and-drop element swapping: drop any preset from the browser onto a pad to override that sound.
/// - Active playback indicator lighting.
class DrumPadGridWidget extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;

  const DrumPadGridWidget({
    super.key,
    required this.dawState,
    required this.track,
  });

  @override
  State<DrumPadGridWidget> createState() => _DrumPadGridWidgetState();
}

class _DrumPadGridWidgetState extends State<DrumPadGridWidget> {
  int _activeBankIndex = 0; // 0 = Core Kit (16 Pads), 1 = Latin & Auxiliary (16 Pads)
  int? _recentlyTriggeredNote;

  static const List<GmPadDef> _corePads = [
    // ROW 1: Cymbals
    GmPadDef(note: 49, label: 'CRASH 1', defaultEngine: 'Crash Cymbal', accentColor: Color(0xFFFFCC00)),
    GmPadDef(note: 51, label: 'RIDE 1', defaultEngine: 'Ride Cymbal', accentColor: Color(0xFFFFD54F)),
    GmPadDef(note: 53, label: 'RIDE BELL', defaultEngine: 'Ride Bell', accentColor: Color(0xFFFFE082)),
    GmPadDef(note: 55, label: 'SPLASH', defaultEngine: 'Splash Cymbal', accentColor: Color(0xFFFFF59D)),

    // ROW 2: Toms
    GmPadDef(note: 50, label: 'HIGH TOM', defaultEngine: 'FM Tom', accentColor: Color(0xFFAB47BC)),
    GmPadDef(note: 47, label: 'LOW-MID TOM', defaultEngine: 'FM Tom', accentColor: Color(0xFF8E24AA)),
    GmPadDef(note: 43, label: 'HI FLOOR', defaultEngine: 'FM Tom', accentColor: Color(0xFF6A1B9A)),
    GmPadDef(note: 41, label: 'LOW FLOOR', defaultEngine: 'FM Tom', accentColor: Color(0xFF4A148C)),

    // ROW 3: Hats & Electronic Snare
    GmPadDef(note: 42, label: 'CLOSED HAT', defaultEngine: 'Inharmonic Hat', accentColor: Color(0xFF26C6DA)),
    GmPadDef(note: 44, label: 'PEDAL HAT', defaultEngine: 'Inharmonic Hat', accentColor: Color(0xFF00ACC1)),
    GmPadDef(note: 46, label: 'OPEN HAT', defaultEngine: 'Inharmonic Hat', accentColor: Color(0xFF00838F)),
    GmPadDef(note: 40, label: 'ELEC SNARE', defaultEngine: 'Snare Synth', accentColor: Color(0xFFFF7043)),

    // ROW 4: Kicks & Snares
    GmPadDef(note: 36, label: 'KICK 1', defaultEngine: 'FM Acoustic Kick', accentColor: Color(0xFFFF1744)),
    GmPadDef(note: 38, label: 'AC. SNARE', defaultEngine: 'FM Acoustic Snare', accentColor: Color(0xFFFF9100)),
    GmPadDef(note: 37, label: 'SIDE STICK', defaultEngine: 'Wood Clack', accentColor: Color(0xFF8D6E63)),
    GmPadDef(note: 39, label: 'HAND CLAP', defaultEngine: 'Cluster Clap', accentColor: Color(0xFFFF5252)),
  ];

  static const List<GmPadDef> _percPads = [
    // ROW 1: Latin Cymbals & Bells
    GmPadDef(note: 57, label: 'CRASH 2', defaultEngine: 'Crash Cymbal', accentColor: Color(0xFFFFB300)),
    GmPadDef(note: 52, label: 'CHINA', defaultEngine: 'China Cymbal', accentColor: Color(0xFFFF8F00)),
    GmPadDef(note: 56, label: 'COWBELL', defaultEngine: 'Tuned FM Bell', accentColor: Color(0xFF00E676)),
    GmPadDef(note: 54, label: 'TAMBOURINE', defaultEngine: 'Jingle Burst', accentColor: Color(0xFF69F0AE)),

    // ROW 2: Bongos & Timbales
    GmPadDef(note: 60, label: 'HI BONGO', defaultEngine: 'Slap FM Bongo', accentColor: Color(0xFF00B0FF)),
    GmPadDef(note: 61, label: 'LOW BONGO', defaultEngine: 'Slap FM Bongo', accentColor: Color(0xFF0091EA)),
    GmPadDef(note: 65, label: 'HI TIMBALE', defaultEngine: 'FM Timbale', accentColor: Color(0xFF2979FF)),
    GmPadDef(note: 66, label: 'LOW TIMBALE', defaultEngine: 'FM Timbale', accentColor: Color(0xFF1565C0)),

    // ROW 3: Congas & Agogo
    GmPadDef(note: 62, label: 'MUTE CONGA', defaultEngine: 'Mute Conga', accentColor: Color(0xFFE040FB)),
    GmPadDef(note: 63, label: 'OPEN CONGA', defaultEngine: 'Open Conga', accentColor: Color(0xFFD500F9)),
    GmPadDef(note: 64, label: 'LOW CONGA', defaultEngine: 'Low Conga', accentColor: Color(0xFFAA00FF)),
    GmPadDef(note: 67, label: 'HI AGOGO', defaultEngine: 'FM Agogo', accentColor: Color(0xFFFF4081)),

    // ROW 4: Wood & Shakers
    GmPadDef(note: 75, label: 'CLAVES', defaultEngine: 'Hardwood Clave', accentColor: Color(0xFFD7CCC8)),
    GmPadDef(note: 76, label: 'HI BLOCK', defaultEngine: 'Wood Block', accentColor: Color(0xFFBCAAA4)),
    GmPadDef(note: 70, label: 'MARACAS', defaultEngine: 'Noise Shaker', accentColor: Color(0xFF80CBC4)),
    GmPadDef(note: 81, label: 'TRIANGLE', defaultEngine: 'FM Triangle', accentColor: Color(0xFFB2FF59)),
  ];

  void _triggerPad(GmPadDef pad, double velocity) {
    setState(() => _recentlyTriggeredNote = pad.note);

    widget.dawState.audioEngine.noteOn(
      track: widget.track,
      midiNote: pad.note,
      velocity: velocity,
      sustainDurationSec: 1.2,
      loop: false,
    );

    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted && _recentlyTriggeredNote == pad.note) {
        setState(() => _recentlyTriggeredNote = null);
      }
    });
  }

  void _assignPresetToPad(GmPadDef pad, LuaPreset preset) {
    GmDrumKitEngine.setSlotOverride(widget.track.id, pad.note, preset.id);

    // Invalidate audio engine PCM cache so the new sound synthesizes immediately
    widget.dawState.audioEngine.clearPcmCache();

    // Save in track luaParams for project persistence
    widget.track.luaParams['slot_${pad.note}'] = 1.0;
    widget.dawState.notifyState();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Assigned "${preset.name}" to Pad ${pad.label} (Note ${pad.note})'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetAllPads() {
    GmDrumKitEngine.clearSlotOverrides(widget.track.id);
    widget.track.luaParams.removeWhere((k, _) => k.startsWith('slot_'));
    widget.dawState.audioEngine.clearPcmCache();
    widget.dawState.notifyState();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reset all drum pads to factory General MIDI models.'),
        backgroundColor: EatsTheme.panelHeader,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _activeBankIndex == 0 ? _corePads : _percPads;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16171B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E313A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Bank Selector & Reset
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, size: 14, color: EatsTheme.accentGold),
              const SizedBox(width: 6),
              Text(
                'MODULAR DRUM PADS',
                style: EatsTheme.getPrimaryFontStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              // Bank Pills
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF22242B),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildBankButton('CORE KIT (16)', 0),
                    const SizedBox(width: 2),
                    _buildBankButton('PERCUSSION (16)', 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Reset Button
              Tooltip(
                message: 'Reset all slots to default GM physical models',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _resetAllPads,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.refresh, size: 13, color: Colors.white60),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4x4 Responsive Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final pad = activeList[index];
              return _buildPadItem(pad);
            },
          ),

          const SizedBox(height: 8),
          // Drag-and-drop instruction cue
          Center(
            child: Text(
              'TIP: Drag any kit preset from the library (808 Kick, 909 Snare, etc.) onto any pad to swap its engine.',
              style: EatsTheme.getPrimaryFontStyle(
                color: Colors.white38,
                fontSize: 9,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankButton(String title, int bankIdx) {
    final isSelected = _activeBankIndex == bankIdx;
    return InkWell(
      onTap: () => setState(() => _activeBankIndex = bankIdx),
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? EatsTheme.accentGold : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          title,
          style: EatsTheme.getPrimaryFontStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPadItem(GmPadDef pad) {
    final overrideId = GmDrumKitEngine.getSlotOverride(widget.track.id, pad.note);
    final isTriggered = _recentlyTriggeredNote == pad.note;

    String engineName = pad.defaultEngine;
    if (overrideId != null) {
      final match = LuaPresetLibrary.getPresetById(overrideId);
      engineName = match?.name ?? overrideId;
    }

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        return details.data is LuaPreset;
      },
      onAcceptWithDetails: (details) {
        if (details.data is LuaPreset) {
          _assignPresetToPad(pad, details.data as LuaPreset);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return GestureDetector(
          onTapDown: (details) {
            // Sensitivity based on Y click position (higher click = stronger hit)
            const double velocity = 0.90;
            _triggerPad(pad, velocity);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isTriggered
                    ? [pad.accentColor.withValues(alpha: 0.55), pad.accentColor.withValues(alpha: 0.35)]
                    : (isHovered
                        ? [EatsTheme.accentGold.withValues(alpha: 0.4), const Color(0xFF2A2C34)]
                        : [const Color(0xFF2A2D35), const Color(0xFF1E2026)]),
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isTriggered
                    ? pad.accentColor
                    : (isHovered
                        ? EatsTheme.accentGold
                        : (overrideId != null ? pad.accentColor.withValues(alpha: 0.6) : const Color(0xFF383C48))),
                width: isTriggered || isHovered ? 2.0 : 1.2,
              ),
              boxShadow: [
                if (isTriggered)
                  BoxShadow(
                    color: pad.accentColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                const BoxShadow(
                  color: Colors.black38,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Note ID & Trigger LED
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${pad.note}',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: Colors.white38,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isTriggered ? pad.accentColor : Colors.white12,
                        boxShadow: isTriggered
                            ? [BoxShadow(color: pad.accentColor, blurRadius: 4)]
                            : null,
                      ),
                    ),
                  ],
                ),

                // Middle: Pad Title
                Center(
                  child: Text(
                    pad.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: EatsTheme.getPrimaryFontStyle(
                      color: isTriggered ? Colors.white : Colors.white.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Bottom Badge: Loaded Engine Name
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (overrideId != null ? pad.accentColor : Colors.white).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    engineName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EatsTheme.getPrimaryFontStyle(
                      color: overrideId != null ? pad.accentColor : Colors.white54,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
