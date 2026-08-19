import 'package:flutter/material.dart';
import '../audio/soundfont_engine.dart';
import '../audio/soundfont_decoder.dart';
import '../lua/lua_preset_library.dart';

import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';
import 'widgets/eatsbits_slider.dart';
import 'widgets/skeuomorphic_hardware_knob.dart';
import 'widgets/grungy_rack_panel.dart';
import 'widgets/glowing_nixie_display.dart';
import 'widgets/project_browser_drawer.dart';
import 'widgets/modular_fx_rack_widget.dart';
import 'widgets/midi_fx_rack_widget.dart';



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
                    // DOUBLE TAP TRACK TITLE: Navigate to Scripts Section (tab 4)
                    dawState.activeTabIndex = 4;
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
                // Mute & Solo
                Row(
                  children: [
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

          // Mixer Controls Section
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

          // Pre-Instrument MIDI FX Rack (Arpeggiator, Chord Arp, Scale Snap, Humanize)
          MidiFxRackWidget(dawState: dawState, track: track),

          const SizedBox(height: 16),

          // Harmonic Chord Track Follow Card
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
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: EatsTheme.primaryCyan,
                      backgroundColor: EatsTheme.controlBackground,
                      side: BorderSide(
                        color: isSelected ? EatsTheme.primaryCyan : Colors.white.withOpacity(0.12),
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

          // SoundFont 2 Bank & Preset Selector Card (if SoundFont track)
          _buildSoundFontPresetSelector(context, track),

          // Dynamic Lua Script Parameters (Exposed by Code)
          if ((track.type == TrackType.luaScript || track.luaParams.isNotEmpty) && dawState.compilationResult.params.isNotEmpty) ...[

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EatsTheme.panelBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: EatsTheme.accentGreen.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.code, color: EatsTheme.accentGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'DYNAMIC SCRIPT PARAMETERS (CODE DRIVEN)',
                        style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...dawState.compilationResult.params.map((paramDef) {
                    final rawVal = (track.luaParams[paramDef.name] ?? paramDef.defaultValue).clamp(paramDef.min, paramDef.max);
                    final currentVal = paramDef.isInteger ? rawVal.roundToDouble() : rawVal;
                    final displayLabel = paramDef.getFormattedValue(currentVal);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              paramDef.name,
                              style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: EatsBitsSlider(
                              value: currentVal,
                              min: paramDef.min,
                              max: paramDef.max,
                              defaultValue: paramDef.defaultValue,
                              label: paramDef.name,
                              activeColor: EatsTheme.accentGreen,
                              onChanged: (val) {
                                final snapped = paramDef.isInteger ? val.roundToDouble() : val;
                                dawState.updateLuaParam(paramDef.name, snapped);
                              },
                              onChangeStart: () => dawState.beginHistoryTransaction('${paramDef.name} (${track.name})', icon: Icons.tune),
                              onChangeEnd: () => dawState.commitHistoryTransaction(),
                            ),
                          ),
                          SizedBox(
                            width: 75,
                            child: Text(
                              displayLabel,
                              style: EatsTheme.getDisplayFontStyle(color: EatsTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Modular FX Insert Rack
          ModularFxRackWidget(dawState: dawState, track: track),



          const SizedBox(height: 16),

          // Vintage Skeuomorphic Hardware Rack Unit (SILT / PunchBOX Style)
          GrungyRackPanel(
            title: 'Analog Hardware DSP Unit - SILT 808',
            subtitle: 'Real-Time Skeuomorphic Rotary Controls & Nixie Segment Readouts',
            accentColor: EatsTheme.currentPreset == EatsThemePreset.ateTrack
                ? const Color(0xFFFF8C00)
                : track.color,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GlowingNixieDisplay(
                      label: 'GAIN OUTPUT',
                      valueText: '${(track.volume * 100).toInt()}',
                      unit: '%',
                      glowColor: EatsTheme.currentPreset == EatsThemePreset.ateTrack
                          ? const Color(0xFFFF8C00)
                          : track.color,
                    ),
                    GlowingNixieDisplay(
                      label: 'STEREO POSITION',
                      valueText: track.pan == 0
                          ? 'CENTER'
                          : (track.pan < 0 ? 'L${(track.pan.abs() * 100).toInt()}' : 'R${(track.pan * 100).toInt()}'),
                      glowColor: EatsTheme.currentPreset == EatsThemePreset.ateTrack
                          ? const Color(0xFFFF8C00)
                          : track.color,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SkeuomorphicHardwareKnob(
                      label: 'VOL GAIN',
                      value: track.volume,
                      min: 0.0,
                      max: 1.5,
                      defaultValue: 1.0,
                      accentColor: EatsTheme.currentPreset == EatsThemePreset.ateTrack
                          ? const Color(0xFFFF8C00)
                          : track.color,
                      onChanged: (val) => dawState.setTrackVolume(track, val),
                      onChangeStart: () => dawState.beginHistoryTransaction('Volume (${track.name})', icon: Icons.volume_up),
                      onChangeEnd: () => dawState.commitHistoryTransaction(),
                      formatValue: (v) => '${(v * 100).toInt()}%',
                    ),
                    SkeuomorphicHardwareKnob(
                      label: 'PAN BALANCE',
                      value: track.pan,
                      min: -1.0,
                      max: 1.0,
                      defaultValue: 0.0,
                      accentColor: EatsTheme.currentPreset == EatsThemePreset.ateTrack
                          ? const Color(0xFFFF8C00)
                          : track.color,
                      onChanged: (val) => dawState.setTrackPan(track, val),
                      onChangeStart: () => dawState.beginHistoryTransaction('Pan (${track.name})', icon: Icons.tune),
                      onChangeEnd: () => dawState.commitHistoryTransaction(),
                      formatValue: (v) => v == 0 ? 'CTR' : (v < 0 ? 'L${(v.abs() * 100).toInt()}' : 'R${(v * 100).toInt()}'),
                    ),

                    // Dynamic Script Parameters Card

                    if (dawState.compilationResult.params.isNotEmpty) ...[
                      SkeuomorphicHardwareKnob(
                        label: dawState.compilationResult.params.first.name.toUpperCase(),
                        value: (track.luaParams[dawState.compilationResult.params.first.name] ??
                                dawState.compilationResult.params.first.defaultValue)
                            .clamp(
                              dawState.compilationResult.params.first.min,
                              dawState.compilationResult.params.first.max,
                            ),
                        min: dawState.compilationResult.params.first.min,
                        max: dawState.compilationResult.params.first.max,
                        defaultValue: dawState.compilationResult.params.first.defaultValue,
                        accentColor: EatsTheme.accentGreen,
                        onChanged: (val) {
                          dawState.updateLuaParam(dawState.compilationResult.params.first.name, val);
                        },
                        onChangeStart: () => dawState.beginHistoryTransaction(
                          '${dawState.compilationResult.params.first.name} (${track.name})',
                          icon: Icons.tune,
                        ),
                        onChangeEnd: () => dawState.commitHistoryTransaction(),
                      ),
                    ],
                  ],
                ),
              ],
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

