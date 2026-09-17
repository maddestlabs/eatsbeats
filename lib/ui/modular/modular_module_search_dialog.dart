import 'package:flutter/material.dart';
import 'modular_theme.dart';

/// Module Model for Dynamic Modular Rack Editing
class DynamicModuleDefinition {
  final String id;
  final String title;
  final String subtitle;
  final int hpWidth;
  final Color accentColor;
  final String category; // 'VCO', 'VCF', 'MOD', 'FX', 'SCRIPT', 'OUT'
  final List<String> inputJacks;
  final List<String> outputJacks;
  final String description;
  final String? scriptCode;
  final Map<String, double>? defaultParams;

  const DynamicModuleDefinition({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.hpWidth,
    this.accentColor = const Color(0xFF00E5FF),
    required this.category,
    this.inputJacks = const [],
    this.outputJacks = const [],
    this.description = '',
    this.scriptCode,
    this.defaultParams,
  });
}

/// Catalog of all Eatscript DSP modules (`eat.node.*`) and programmable script cores.
class ModularModuleLibrary {
  static const List<DynamicModuleDefinition> modules = [
    // --- VCO: OSCILLATORS ---
    DynamicModuleDefinition(
      id: 'osc',
      title: 'ANALOG VCO',
      subtitle: 'Multi-Wave Core (eat.node.osc)',
      hpWidth: 14,
      accentColor: Color(0xFFFF5722),
      category: 'VCO',
      description: 'Multi-waveform oscillator (Saw, Sine, Square, Tri, Pulse, Noise) with detune and unison.',
      inputJacks: ['1V/Oct', 'Sync In', 'Pitch In'],
      outputJacks: ['Saw Out', 'Audio Out'],
      defaultParams: {'Waveform': 0.0, 'Detune': 0.0},
    ),
    DynamicModuleDefinition(
      id: 'sub',
      title: 'SUB OSCILLATOR',
      subtitle: 'Sub-Bass Generator (eat.node.sub)',
      hpWidth: 10,
      accentColor: Color(0xFFFF9800),
      category: 'VCO',
      description: 'Deep sub-harmonic oscillator (-1 or -2 octaves) for heavy low-end bass foundations.',
      inputJacks: ['Pitch In'],
      outputJacks: ['Sub Out'],
      defaultParams: {'Octave': -1.0, 'Level': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'noise',
      title: 'WHITE/PINK NOISE',
      subtitle: 'Stochastic Generator (eat.node.noise)',
      hpWidth: 8,
      accentColor: Color(0xFFB0BEC5),
      category: 'VCO',
      description: 'Digital white and pink noise generator for percussive crackle, breath, and texture.',
      inputJacks: [],
      outputJacks: ['White Out', 'Pink Out'],
      defaultParams: {'Type': 0.0},
    ),

    // --- PHYSICAL: PHYSICAL MODELING ---
    DynamicModuleDefinition(
      id: 'hammer',
      title: 'HAMMER EXCITER',
      subtitle: 'Nonlinear Strike (eat.node.hammer)',
      hpWidth: 10,
      accentColor: Color(0xFFFF5252),
      category: 'PHYSICAL',
      description: 'Nonlinear felt/wood hammer impact exciter based on felt compression physics.',
      inputJacks: ['Strike In', 'Force CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Hardness': 0.5, 'Velocity': 1.0},
    ),
    DynamicModuleDefinition(
      id: 'pluck',
      title: 'PLECTRUM PLUCK',
      subtitle: 'String Exciter (eat.node.pluck)',
      hpWidth: 10,
      accentColor: Color(0xFFFF5252),
      category: 'PHYSICAL',
      description: 'Plectrum release / string pluck exciter with adjustable pick stiffness.',
      inputJacks: ['Pluck In', 'Position CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Position': 0.2, 'Stiffness': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'bow',
      title: 'BOWED FRICTION',
      subtitle: 'Violin/Cello Exciter (eat.node.bow)',
      hpWidth: 10,
      accentColor: Color(0xFFFF5252),
      category: 'PHYSICAL',
      description: 'Continuous stick-slip friction exciter modeling rosin friction curve on string.',
      inputJacks: ['Velocity CV', 'Force CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Force': 0.5, 'Friction': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'waveguide',
      title: 'DIGITAL WAVEGUIDE',
      subtitle: 'Acoustic String Resonator (eat.node.waveguide)',
      hpWidth: 14,
      accentColor: Color(0xFF00E5FF),
      category: 'PHYSICAL',
      description: 'Bidirectional delay-line waveguide with dispersion, frequency-dependent damping, and tension modulation.',
      inputJacks: ['Exciter In', 'Pitch CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Damping': 0.95, 'Tension': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'modal_bank',
      title: 'MODAL RESONATOR',
      subtitle: 'Multi-Mode Bank (eat.node.modal_bank)',
      hpWidth: 14,
      accentColor: Color(0xFF00E5FF),
      category: 'PHYSICAL',
      description: 'Bank of tuned 2nd-order bandpass resonators for struck bars, bells, plates, and drums.',
      inputJacks: ['Exciter In', 'Structure CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Structure': 0.0, 'Brightness': 0.7, 'Damping': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'acoustic_body',
      title: 'ACOUSTIC BODY',
      subtitle: 'Morphing Cavity (eat.node.acoustic_body)',
      hpWidth: 12,
      accentColor: Color(0xFF8D6E63),
      category: 'PHYSICAL',
      description: 'Morphing resonant chamber modeling guitar, cello, violin, and marimba box resonances.',
      inputJacks: ['Resonator In', 'Morph CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Body Type': 0.0, 'Size': 1.0},
    ),

    // --- VCF: FILTERS ---
    DynamicModuleDefinition(
      id: 'svf',
      title: 'STATE VARIABLE VCF',
      subtitle: '12dB Chamberlin Filter (eat.node.svf)',
      hpWidth: 14,
      accentColor: Color(0xFF00E5FF),
      category: 'VCF',
      description: '12dB/oct Chamberlin state-variable filter with simultaneous Lowpass, Bandpass, and Highpass outputs.',
      inputJacks: ['Audio In', 'Cutoff CV', 'Reso CV'],
      outputJacks: ['LP Out', 'BP Out', 'HP Out'],
      defaultParams: {'Cutoff': 2000.0, 'Resonance': 0.7},
    ),
    DynamicModuleDefinition(
      id: 'moog',
      title: 'MOOG LADDER VCF',
      subtitle: '24dB 4-Pole Lowpass (eat.node.moog)',
      hpWidth: 14,
      accentColor: Color(0xFFFF9100),
      category: 'VCF',
      description: 'Legendary 24dB/oct resonant 4-pole transistor ladder filter with warm drive and self-oscillation.',
      inputJacks: ['Audio In', 'Cutoff CV', 'Reso CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Cutoff': 1000.0, 'Resonance': 0.7},
    ),

    // --- MOD: MODULATION & ENVELOPES ---
    DynamicModuleDefinition(
      id: 'adsr',
      title: 'ADSR ENVELOPE',
      subtitle: 'Linear Envelope (eat.node.adsr)',
      hpWidth: 14,
      accentColor: Color(0xFF00E676),
      category: 'MOD',
      description: 'Classic Attack, Decay, Sustain, Release voltage envelope generator for amplitude and filter sculpting.',
      inputJacks: ['Gate In'],
      outputJacks: ['Env Out'],
      defaultParams: {'Attack': 0.01, 'Decay': 0.2, 'Sustain': 0.7, 'Release': 0.3},
    ),
    DynamicModuleDefinition(
      id: 'lfo',
      title: 'MULTI-WAVE LFO',
      subtitle: 'Low Frequency Osc (eat.node.lfo)',
      hpWidth: 10,
      accentColor: Color(0xFFE040FB),
      category: 'MOD',
      description: 'Low frequency oscillator (Sine, Tri, Saw, Square) with sync and depth controls.',
      inputJacks: ['Rate CV', 'Reset In'],
      outputJacks: ['LFO Out'],
      defaultParams: {'Rate': 2.0, 'Depth': 1.0, 'Waveform': 0.0},
    ),

    DynamicModuleDefinition(
      id: 'pitch_sweep',
      title: 'PITCH SWEEP',
      subtitle: 'Transient Pitch EG (eat.node.pitch_sweep)',
      hpWidth: 10,
      accentColor: Color(0xFFE040FB),
      category: 'MOD',
      description: 'Exponential pitch sweep envelope for kick drums, laser drops, and percussion punch.',
      inputJacks: ['Gate In'],
      outputJacks: ['Pitch CV'],
      defaultParams: {'Start': 140.0, 'End': 46.0, 'Decay': 0.045},
    ),
    DynamicModuleDefinition(
      id: 'decay',
      title: 'DECAY ENVELOPE',
      subtitle: 'Exponential Decay (eat.node.decay)',
      hpWidth: 8,
      accentColor: Color(0xFF76FF03),
      category: 'MOD',
      description: 'Fast analog exponential decay generator for snappy percussion and plucks.',
      inputJacks: ['Gate In'],
      outputJacks: ['Env Out'],
      defaultParams: {'Decay': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'multi_burst',
      title: 'BURST ENVELOPE',
      subtitle: 'Multi-Transient Burst (eat.node.multi_burst)',
      hpWidth: 10,
      accentColor: Color(0xFFFFD600),
      category: 'MOD',
      description: 'Multi-burst micro-transient trigger envelope for authentic 808/909 handclaps and Flamenco rasgueado.',
      inputJacks: ['Gate In'],
      outputJacks: ['Burst Out'],
      defaultParams: {'Bursts': 4.0, 'Spread': 0.011, 'Decay': 0.28},
    ),
    DynamicModuleDefinition(
      id: 'metallic_cluster',
      title: 'METALLIC CLUSTER',
      subtitle: '6-Osc Inharmonic Core (eat.node.metallic_cluster)',
      hpWidth: 12,
      accentColor: Color(0xFF90A4AE),
      category: 'VCO',
      description: 'Authentic 808/909 6-oscillator inharmonic square wave cluster for hi-hats, cymbals, and cowbells.',
      inputJacks: ['Pitch CV'],
      outputJacks: ['Cluster Out'],
      defaultParams: {'Tune': 1.0},
    ),
    DynamicModuleDefinition(
      id: 'tr909_kick',
      title: 'TR-909 KICK',
      subtitle: 'Physical Model (eat.node.tr909_kick)',
      hpWidth: 14,
      accentColor: Color(0xFFFF5722),
      category: 'VCO',
      description: 'Authentic André Michelle 909 bass drum with 274Hz-53Hz sweep and attack click.',
      inputJacks: ['Gate In'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Tune': 0.018, 'Decay': 0.05, 'Attack': 1.0},
    ),
    DynamicModuleDefinition(
      id: 'tr909_snare',
      title: 'TR-909 SNARE',
      subtitle: 'Dual-Layer Snare (eat.node.tr909_snare)',
      hpWidth: 14,
      accentColor: Color(0xFFFF9800),
      category: 'VCO',
      description: 'Authentic 909 dual-layer snare: tuned analog body + snappy noise wires.',
      inputJacks: ['Gate In'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Tune': 0.0, 'Snappy': 1.0, 'Tone': 0.12},
    ),
    DynamicModuleDefinition(
      id: 'tr909_voice',
      title: 'TR-909 ROM VOICE',
      subtitle: '6-Bit PCM Voice (eat.node.tr909_voice)',
      hpWidth: 12,
      accentColor: Color(0xFFFFD600),
      category: 'VCO',
      description: 'Authentic 909 6-bit compressed PCM voice with analog VCA decay (hi-hats, rimshot, clap).',
      inputJacks: ['Gate In'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Tune': 0.0, 'Decay': 0.05},
    ),
    DynamicModuleDefinition(
      id: 'melodic_tom',
      title: 'MELODIC TOM',
      subtitle: 'Cylindrical Shell (eat.node.melodic_tom)',
      hpWidth: 14,
      accentColor: Color(0xFF3A86FF),
      category: 'VCO',
      description: 'Acoustic modal tom with dual-head membrane coupling, pitch bend, and stick click.',
      inputJacks: ['Gate In', 'Pitch CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Decay': 0.85, 'Coupling': 0.55, 'PitchBend': 0.4, 'Stick': 0.6},
    ),
    DynamicModuleDefinition(
      id: 'reverse_cymbal',
      title: 'REVERSE CYMBAL',
      subtitle: 'Bronze Plate Swell (eat.node.reverse_cymbal)',
      hpWidth: 14,
      accentColor: Color(0xFFFFBE0B),
      category: 'VCO',
      description: 'Modal bronze cymbal with time-inverted crescendo swell and choke snap.',
      inputJacks: ['Gate In'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Duration': 1.5, 'Curve': 2.2, 'Shimmer': 0.75, 'Choke': 0.6},
    ),

    // --- UTIL: MIXING & ROUTING ---
    DynamicModuleDefinition(
      id: 'midi_to_cv',
      title: 'MIDI TO CV',
      subtitle: '1V/Oct & Gate Interface (eat.node.midi_to_cv)',
      hpWidth: 8,
      accentColor: Color(0xFFFF4081),
      category: 'UTIL',
      description: 'Converts DAW MIDI note events to Eurorack 1V/Oct pitch CV, Gate trigger, and Velocity CV.',
      inputJacks: [],
      outputJacks: ['1V/Oct', 'Gate Out', 'Velocity'],
    ),
    DynamicModuleDefinition(
      id: 'input',
      title: 'AUDIO IN',
      subtitle: 'Track Input Jack (eat.node.input)',
      hpWidth: 8,
      accentColor: Color(0xFF00E676),
      category: 'UTIL',
      description: 'Incoming audio signal from track or bus for insert FX processing.',
      inputJacks: [],
      outputJacks: ['Audio Out'],
    ),
    DynamicModuleDefinition(
      id: 'gain',
      title: 'VCA GAIN',
      subtitle: 'Voltage Controlled Amplifier (eat.node.gain)',
      hpWidth: 8,
      accentColor: Color(0xFF64FFDA),
      category: 'UTIL',
      description: 'Linear/exponential voltage controlled amplifier for envelope level contouring and amplitude modulation.',
      inputJacks: ['Audio In', 'Gain CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Gain': 1.0},
    ),
    DynamicModuleDefinition(
      id: 'mix',
      title: 'AUDIO MIXER',
      subtitle: '2-Channel Summer (eat.node.mix)',
      hpWidth: 10,
      accentColor: Color(0xFF78909C),
      category: 'UTIL',
      description: 'Linear 2-channel signal summer and attenuator for audio or CV combining.',
      inputJacks: ['In A', 'In B', 'Balance CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Gain A': 0.5, 'Gain B': 0.5},
    ),

    // --- FX: EFFECTS & PROCESSORS ---
    DynamicModuleDefinition(
      id: 'delay',
      title: 'TAPE DELAY FX',
      subtitle: 'Tape Delay Line (eat.node.delay)',
      hpWidth: 12,
      accentColor: Color(0xFF9C27B0),
      category: 'FX',
      description: 'Echo delay line with feedback, damping, and stereo spatialization.',
      inputJacks: ['Audio In', 'Time CV'],
      outputJacks: ['Wet Out', 'Dry Out', 'Echo Out'],
      defaultParams: {'Time': 0.3, 'Feedback': 0.4},
    ),
    DynamicModuleDefinition(
      id: 'saturate',
      title: 'POLYNOMIAL DRIVE',
      subtitle: 'Soft Clip & Saturation (eat.node.saturate)',
      hpWidth: 10,
      accentColor: Color(0xFFE91E63),
      category: 'FX',
      description: 'Analog-style cubic soft-clipping and harmonic distortion processor.',
      inputJacks: ['Audio In', 'Drive CV'],
      outputJacks: ['Audio Out'],
      defaultParams: {'Drive': 1.0},
    ),
    DynamicModuleDefinition(
      id: 'bitcrush',
      title: '8-BIT CRUSHER',
      subtitle: 'Bit-Depth & Decimator (eat.node.bitcrush)',
      hpWidth: 10,
      accentColor: Color(0xFFFFD700),
      category: 'FX',
      description: 'Hardware bit-depth reduction and sample-rate decimation for authentic 8-bit chip textures.',
      inputJacks: ['Audio In'],
      outputJacks: ['Crushed Out'],
      defaultParams: {'Bits': 8.0, 'Downsample': 1.0, 'Mix': 1.0},
    ),
    DynamicModuleDefinition(
      id: 'chorus',
      title: 'STEREO CHORUS',
      subtitle: 'Modulated Dual Delay (eat.node.chorus)',
      hpWidth: 10,
      accentColor: Color(0xFFAB47BC),
      category: 'FX',
      description: 'Dual quadrature LFO modulated delay for spatial width, shimmer, and lush analog ensemble.',
      inputJacks: ['Audio In', 'Rate CV'],
      outputJacks: ['Chorus Out'],
      defaultParams: {'Rate': 0.8, 'Depth': 0.65, 'Feedback': 0.2, 'Mix': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'tremolo',
      title: 'STEREO TREMOLO',
      subtitle: 'Optical Tremolo (eat.node.tremolo)',
      hpWidth: 10,
      accentColor: Color(0xFF00E5FF),
      category: 'FX',
      description: 'Vintage optical photocell tremolo and 180° ping-pong auto-panner.',
      inputJacks: ['Audio In', 'Rate CV'],
      outputJacks: ['Trem Out'],
      defaultParams: {'Rate': 4.5, 'Depth': 0.65},
    ),
    DynamicModuleDefinition(
      id: 'compressor',
      title: 'VCA COMPRESSOR',
      subtitle: 'Dynamics Compressor (eat.node.compressor)',
      hpWidth: 14,
      accentColor: Color(0xFF00FF9D),
      category: 'FX',
      description: 'Studio dynamic range compressor with threshold, ratio, attack, release, and auto-makeup gain.',
      inputJacks: ['Audio In', 'Sidechain'],
      outputJacks: ['Comp Out'],
      defaultParams: {'Threshold': -18.0, 'Ratio': 4.0, 'Attack': 15.0, 'Release': 100.0, 'Makeup': 0.0, 'Mix': 1.0},
    ),
    DynamicModuleDefinition(
      id: 'limiter',
      title: 'MASTER LIMITER',
      subtitle: 'Brickwall Limiter (eat.node.limiter)',
      hpWidth: 12,
      accentColor: Color(0xFFFF3366),
      category: 'FX',
      description: 'Zero-overshoot brickwall peak limiter with lookahead protection and transparent release.',
      inputJacks: ['Audio In'],
      outputJacks: ['Limiter Out'],
      defaultParams: {'Ceiling': -0.1, 'Release': 50.0},
    ),

    // --- SCRIPT: PROGRAMMABLE DSP MODULES ---
    DynamicModuleDefinition(
      id: 'custom_script_dsp',
      title: 'CUSTOM LUA DSP',
      subtitle: 'Live Eatscript DSP Core',
      hpWidth: 16,
      accentColor: Color(0xFF00E5FF),
      category: 'SCRIPT',
      description: 'Real-time programmable DSP block running custom sample-level Eatscript processing.',
      inputJacks: ['Audio In', 'CV In'],
      outputJacks: ['Audio Out', 'Aux Out'],
      scriptCode: '-- Custom Script DSP\nfunction process(sample, cv1, cv2)\n    return sample * 1.0\nend\n',
      defaultParams: {'Param 1': 0.5, 'Param 2': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'midi_script_mod',
      title: 'MIDI LUA TRANSFORM',
      subtitle: 'Event Processing & Macro Logic',
      hpWidth: 14,
      accentColor: Color(0xFFFFD600),
      category: 'SCRIPT',
      description: 'Programmable MIDI event processor, arpeggiator, and algorithmic pattern transformer in Eatscript.',
      inputJacks: ['MIDI In', 'Clock'],
      outputJacks: ['MIDI Out', 'Gate Out'],
      scriptCode: 'def on_note(pitch, vel):\n    return pitch, vel\n',
      defaultParams: {'Division': 0.25, 'Swing': 0.0},
    ),

    // --- OUT: OUTPUTS ---
    DynamicModuleDefinition(
      id: 'out',
      title: 'MASTER AUDIO OUT',
      subtitle: 'Master Output VCA (eat.node.out)',
      hpWidth: 10,
      accentColor: Color(0xFFFFD600),
      category: 'OUT',
      description: 'Stereo master output with volume control and soft peak limiter.',
      inputJacks: ['L In', 'R In'],
      outputJacks: ['Main L', 'Main R'],
      defaultParams: {'Volume': 0.8},
    ),
  ];
}

/// Search & Selection Dialog for adding Eatscript DSP modules into the rack.
class ModularModuleSearchDialog extends StatefulWidget {
  final int targetRow;
  final ValueChanged<DynamicModuleDefinition> onModuleSelected;

  const ModularModuleSearchDialog({
    super.key,
    required this.targetRow,
    required this.onModuleSelected,
  });

  @override
  State<ModularModuleSearchDialog> createState() => _ModularModuleSearchDialogState();
}

class _ModularModuleSearchDialogState extends State<ModularModuleSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'ALL';

  final List<String> _categories = [
    'ALL',
    'VCO (OSC)',
    'PHYSICAL (ACOUSTIC)',
    'VCF (FILTER)',
    'MOD (ENVELOPE/LFO)',
    'FX (EFFECTS)',
    'UTIL (MIX/ROUTING)',
    'SCRIPT DSP',
    'OUT',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesCategory(String itemCategory, String filter) {
    if (filter == 'ALL') return true;
    if (filter.startsWith('VCO') && itemCategory == 'VCO') return true;
    if (filter.startsWith('PHYSICAL') && itemCategory == 'PHYSICAL') return true;
    if (filter.startsWith('VCF') && itemCategory == 'VCF') return true;
    if (filter.startsWith('MOD') && itemCategory == 'MOD') return true;
    if (filter.startsWith('FX') && itemCategory == 'FX') return true;
    if (filter.startsWith('UTIL') && itemCategory == 'UTIL') return true;
    if (filter.startsWith('SCRIPT') && itemCategory == 'SCRIPT') return true;
    if (filter.startsWith('OUT') && itemCategory == 'OUT') return true;
    return itemCategory == filter;
  }

  List<DynamicModuleDefinition> get _filteredModules {
    final query = _searchCtrl.text.trim().toLowerCase();
    return ModularModuleLibrary.modules.where((m) {
      final matchesCat = _matchesCategory(m.category, _selectedCategory);
      final matchesQuery = query.isEmpty ||
          m.title.toLowerCase().contains(query) ||
          m.subtitle.toLowerCase().contains(query) ||
          m.description.toLowerCase().contains(query) ||
          m.id.toLowerCase().contains(query);
      return matchesCat && matchesQuery;
    }).toList();
  }

  Color _getCategoryColor(String cat) {
    if (cat.contains('VCO')) return const Color(0xFFFF5722);
    if (cat.contains('PHYSICAL')) return const Color(0xFFFF5252);
    if (cat.contains('VCF')) return const Color(0xFF00E5FF);
    if (cat.contains('MOD')) return const Color(0xFF00E676);
    if (cat.contains('FX')) return const Color(0xFFE91E63);
    if (cat.contains('UTIL')) return const Color(0xFF78909C);
    if (cat.contains('SCRIPT')) return const Color(0xFF00BCD4);
    if (cat.contains('OUT')) return const Color(0xFFFFD600);
    return const Color(0xFF00E5FF);
  }

  IconData _getCategoryIcon(String cat) {
    if (cat.contains('VCO')) return Icons.waves;
    if (cat.contains('PHYSICAL')) return Icons.piano;
    if (cat.contains('VCF')) return Icons.filter_alt;
    if (cat.contains('MOD')) return Icons.timeline;
    if (cat.contains('FX')) return Icons.auto_awesome;
    if (cat.contains('UTIL')) return Icons.alt_route;
    if (cat.contains('SCRIPT')) return Icons.code;
    if (cat.contains('OUT')) return Icons.volume_up;
    return Icons.extension;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredModules;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 780,
        height: 560,
        decoration: BoxDecoration(
          color: ModularTheme.caseBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ModularTheme.railMetalColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 24,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: ModularTheme.railMetalColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_circle, color: ModularTheme.cablePitchCv, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'ADD MODULE TO ROW ${widget.targetRow}',
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // --- SEARCH & CATEGORY FILTER BAR ---
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF070C11),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search DSP modules (osc, vcf, adsr, delay, script)...',
                        hintStyle: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.white38),
                        prefixIcon: Icon(Icons.search, size: 16, color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.black : Colors.white70,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: _getCategoryColor(cat),
                            backgroundColor: const Color(0xFF141A22),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // --- MODULE CARDS GRID ---
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching DSP modules found',
                        style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.white38),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.3,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildModuleCard(filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(DynamicModuleDefinition mod) {
    final catColor = _getCategoryColor(mod.category);

    return InkWell(
      onTap: () {
        widget.onModuleSelected(mod);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1720),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: mod.accentColor.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_getCategoryIcon(mod.category), size: 12, color: catColor),
                    const SizedBox(width: 5),
                    Text(
                      mod.category,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: catColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '${mod.hpWidth} HP',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mod.title,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mod.subtitle,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 9,
                    color: mod.accentColor.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Text(
              mod.description,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 8.5,
                color: Colors.white54,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'IN: ${mod.inputJacks.length} • OUT: ${mod.outputJacks.length}',
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 8,
                    color: Colors.white38,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: mod.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: mod.accentColor.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 10, color: mod.accentColor),
                      const SizedBox(width: 3),
                      Text(
                        'ADD',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: mod.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
