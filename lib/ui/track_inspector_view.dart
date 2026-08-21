import 'package:flutter/material.dart';
import '../audio/soundfont_engine.dart';
import '../audio/soundfont_decoder.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../models/script_target_model.dart';
import '../lua/lua_preset_library.dart';
import '../theme/eats_theme.dart';
import 'widgets/eatsbits_slider.dart';
import 'widgets/project_browser_drawer.dart';
import 'widgets/modular_fx_rack_widget.dart';
import 'widgets/midi_fx_rack_widget.dart';
import 'widgets/dynamic_instrument_gui_widget.dart';



class TrackInspectorView extends StatelessWidget {
  final DawState dawState;

  const TrackInspectorView({super.key, required this.dawState});

  Widget _buildSoundFontPresetSelector(BuildContext context, TrackChannel track) {
    final isSoundFontTrack = track.sampleName.toLowerCase().endsWith('.sf2') ||
        track.name.toLowerCase().contains('soundfont') ||
        track.luaScriptCode.contains('SoundFont') ||
        track.luaParams.containsKey('PresetNum');

    if (!isSoundFontTrack) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: SoundFontEngine.instance.getSoundFont('default.sf2') != null
          ? Future.value(true)
          : SoundFontEngine.instance.loadDefaultBundledFont(),
      builder: (context, snapshot) {
        final fontData = SoundFontEngine.instance.getSoundFont(track.sampleName) ??
            SoundFontEngine.instance.getSoundFont('default.sf2');

        if (fontData == null || fontData.presets.isEmpty) {
          return const SizedBox.shrink();
        }

        final currentBank = (track.luaParams['BankNum'] ?? 0.0).toInt();
        final currentPreset = (track.luaParams['PresetNum'] ?? 0.0).toInt();

        final activePresetIdx = fontData.presets.indexWhere(
          (p) => p.presetNum == currentPreset && p.bankNum == currentBank,
        );
        final validIdx = activePresetIdx != -1
            ? activePresetIdx
            : fontData.presets.indexWhere((p) => p.presetNum == currentPreset);
        final finalIdx = validIdx != -1 ? validIdx : 0;

        final loadedFonts = SoundFontEngine.instance.loadedDisplayFonts;
        final currentFontId = loadedFonts.containsKey(track.sampleName) ? track.sampleName : loadedFonts.keys.first;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EatsTheme.panelBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EatsTheme.accentGreen, width: 1.5),
            boxShadow: [
              BoxShadow(color: EatsTheme.accentGreen.withOpacity(0.15), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.piano, color: EatsTheme.accentGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'SOUNDFONT BANK',
                    style: EatsTheme.getPrimaryFontStyle(
                      color: EatsTheme.accentGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (loadedFonts.length > 1) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: EatsTheme.panelHeader,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2B3245)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentFontId,
                      isExpanded: true,
                      dropdownColor: EatsTheme.panelHeader,
                      style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      items: loadedFonts.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (newFontId) {
                        if (newFontId != null) {
                          dawState.changeTrackSoundFont(track, newFontId, displayName: loadedFonts[newFontId]);
                        }
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'SELECT PROGRAM PRESET (${fontData.presets.length} AVAILABLE):',
                style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 10),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: EatsTheme.panelHeader,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2B3245)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: finalIdx,
                    isExpanded: true,
                    dropdownColor: EatsTheme.panelHeader,
                    style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                    items: fontData.presets.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final preset = entry.value;
                      final label = GeneralMidiNames.getPresetDisplayName(preset.bankNum, preset.presetNum, preset.name);
                      return DropdownMenuItem<int>(
                        value: idx,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (newIdx) {
                      if (newIdx != null && newIdx >= 0 && newIdx < fontData.presets.length) {
                        final p = fontData.presets[newIdx];
                        dawState.updateLuaParam('PresetNum', p.presetNum.toDouble());
                        dawState.updateLuaParam('BankNum', p.bankNum.toDouble());
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }





  @override
  Widget build(BuildContext context) {
    final track = dawState.activeTrack;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data is SoundFontDragItem) return true;
        if (data is LuaPreset) {
          return data.isInstrument || data.isAudioFx;
        }
        return false;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is SoundFontDragItem) {
          dawState.applySoundFont(data.fontId, displayName: data.displayName, targetTrack: track);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched ${track.name} SoundFont to "${data.displayName}"'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (data is LuaPreset) {
          dawState.applyPreset(data, targetTrack: track);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data.isInstrument
                  ? 'Applied instrument "${data.name}" to ${track.name}'
                  : 'Added FX "${data.name}" to end of ${track.name} FX chain'),
              backgroundColor: EatsTheme.panelHeader,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Container(
          color: isHovering ? EatsTheme.primaryCyan.withOpacity(0.12) : Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Track Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EatsTheme.panelBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: track.color, width: 2),
              boxShadow: [
                BoxShadow(color: track.color.withOpacity(0.2), blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 48,
                  decoration: BoxDecoration(color: track.color, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onLongPress: () {
                    dawState.activeTabIndex = 0; // Arranger tab with track selected
                  },
                  onSecondaryTap: () {
                    dawState.activeTabIndex = 0;
                  },
                  onDoubleTap: () {
                    final target = ScriptTarget(
                      id: 'track_${track.id}_dsp',
                      type: ScriptTargetType.trackDsp,
                      title: '${track.name} (Synth DSP)',
                      subtitle: 'Channel Instrument Script',
                      trackId: track.id,
                      trackName: track.name,
                      trackColor: track.color,
                    );
                    dawState.openScriptInEditor(target);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name.toUpperCase(),
                        style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'TYPE: ${track.type.name.toUpperCase()} (DOUBLE-TAP FOR CODE)',
                        style: EatsTheme.getPrimaryFontStyle(color: track.color, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Actions & Mute & Solo
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Pop Out Floating VSTi GUI Window',
                      icon: const Icon(Icons.picture_in_picture_alt, size: 18),
                      color: EatsTheme.accentGold,
                      onPressed: () {
                        dawState.openFloatingInstrumentWindow(track);
                        dawState.activeTabIndex = 0; // Switch to Arranger with floating GUI active
                      },
                    ),
                    IconButton(
                      tooltip: 'Open Track Script in Scripts Editor',
                      icon: const Icon(Icons.code, size: 18),
                      color: EatsTheme.primaryCyan,
                      onPressed: () {
                        final target = ScriptTarget(
                          id: 'track_${track.id}_dsp',
                          type: ScriptTargetType.trackDsp,
                          title: '${track.name} (Synth DSP)',
                          subtitle: 'Channel Instrument Script',
                          trackId: track.id,
                          trackName: track.name,
                          trackColor: track.color,
                        );
                        dawState.openScriptInEditor(target);
                      },
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => dawState.toggleMute(track),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: track.isMuted ? EatsTheme.muteColor : EatsTheme.panelHeader,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('MUTE', style: EatsTheme.getPrimaryFontStyle(color: track.isMuted ? Colors.white : EatsTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => dawState.toggleSolo(track),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: track.isSoloed ? EatsTheme.soloColor : EatsTheme.panelHeader,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('SOLO', style: EatsTheme.getPrimaryFontStyle(color: track.isSoloed ? Colors.black : EatsTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 1. Mixer Controls Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EatsTheme.panelBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2B3245)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHANNEL MIXER SETTINGS', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 12),

                // Volume Slider
                Row(
                  children: [
                    SizedBox(width: 70, child: Text('VOLUME', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textSecondary, fontSize: 11))),
                    Expanded(
                      child: EatsBitsSlider(
                        value: track.volume,
                        min: 0.0,
                        max: 1.5,
                        defaultValue: 1.0,
                        label: '${track.name} Volume',
                        activeColor: track.color,
                        onChanged: (val) => dawState.setTrackVolume(track, val),
                        onChangeStart: () => dawState.beginHistoryTransaction('Volume (${track.name})', icon: Icons.volume_up),
                        onChangeEnd: () => dawState.commitHistoryTransaction(),
                      ),
                    ),
                    SizedBox(width: 45, child: Text('${(track.volume * 100).toInt()}%', style: EatsTheme.getDisplayFontStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                ),

                // Pan Slider
                Row(
                  children: [
                    SizedBox(width: 70, child: Text('PAN', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textSecondary, fontSize: 11))),
                    Expanded(
                      child: EatsBitsSlider(
                        value: track.pan,
                        min: -1.0,
                        max: 1.0,
                        defaultValue: 0.0,
                        label: '${track.name} Pan',
                        activeColor: track.color,
                        onChanged: (val) => dawState.setTrackPan(track, val),
                        onChangeStart: () => dawState.beginHistoryTransaction('Pan (${track.name})', icon: Icons.tune),
                        onChangeEnd: () => dawState.commitHistoryTransaction(),
                      ),
                    ),
                    SizedBox(width: 45, child: Text(track.pan == 0 ? 'C' : (track.pan < 0 ? 'L${(track.pan.abs() * 100).toInt()}' : 'R${(track.pan * 100).toInt()}'), style: EatsTheme.getDisplayFontStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. GUI (if provided) / Instrument & SoundFont Bank Selector
          _buildSoundFontPresetSelector(context, track),
          DynamicInstrumentGuiWidget(dawState: dawState, track: track),

          const SizedBox(height: 16),

          // 3. Harmonic Chord Track Follow Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EatsTheme.panelBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: track.chordFollowMode != ChordFollowMode.off ? EatsTheme.primaryCyan : const Color(0xFF2B3245),
                width: 1.5,
              ),
              boxShadow: track.chordFollowMode != ChordFollowMode.off
                  ? [BoxShadow(color: EatsTheme.primaryCyan.withOpacity(0.12), blurRadius: 8)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.queue_music, color: EatsTheme.accentGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'HARMONIC CHORD TRACK FOLLOW',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.accentGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (track.chordFollowMode != ChordFollowMode.off)
                      TextButton.icon(
                        onPressed: () {
                          dawState.bakeTrackChordsToMidi(track);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Baked chord follow pitches into MIDI for "${track.name}"'),
                              backgroundColor: EatsTheme.panelHeader,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: EatsTheme.accentGold,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.lock_clock, size: 14),
                        label: const Text('Bake to MIDI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Conform notes on this track non-destructively to the active chord progression on the Chord Track.',
                  style: TextStyle(color: EatsTheme.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ChordFollowMode.values.map((mode) {
                    final isSelected = track.chordFollowMode == mode;
                    return ChoiceChip(
                      label: Text(
                        mode.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? (EatsTheme.isLight ? Colors.white : EatsTheme.backgroundDark)
                              : EatsTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: EatsTheme.primaryCyan,
                      backgroundColor: EatsTheme.controlBackground,
                      side: BorderSide(
                        color: isSelected ? EatsTheme.primaryCyan : EatsTheme.textMuted.withOpacity(0.35),
                      ),
                      onSelected: (_) => dawState.setTrackChordFollowMode(track, mode),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  track.chordFollowMode.description,
                  style: TextStyle(
                    color: track.chordFollowMode != ChordFollowMode.off ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. MIDI FX Rack (Arpeggiator, Chord Arp, Scale Snap, Humanize)
          MidiFxRackWidget(dawState: dawState, track: track),

          const SizedBox(height: 16),

          // 5. Audio FX Insert Rack (Delay, Chorus, Bitcrusher, Reverb, Filters)
          ModularFxRackWidget(dawState: dawState, track: track),
        ],
      ),
    ),
  );
},
);
}
}

