import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';
import 'modular_theme.dart';

/// Module Model for Dynamic Modular Rack Editing
class DynamicModuleDefinition {
  final String id;
  final String title;
  final String subtitle;
  final int hpWidth;
  final Color accentColor;
  final String category; // 'VCO', 'VCF', 'MOD', 'FX', 'SCRIPT', 'OUT', 'UTILITY'
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

/// Catalog of all built-in Eurorack hardware and programmable Script modules.
class ModularModuleLibrary {
  static const List<DynamicModuleDefinition> modules = [
    // --- VCO: OSCILLATORS ---
    DynamicModuleDefinition(
      id: 'vco_saw_sqr',
      title: 'ANALOG VCO',
      subtitle: 'Saw/Square Core',
      hpWidth: 10,
      accentColor: Color(0xFFFF5722),
      category: 'VCO',
      description: 'Analog multi-waveform core with 1V/Oct exponential tracking and hard sync.',
      inputJacks: ['1V/Oct', 'Sync In', 'PWM CV'],
      outputJacks: ['Saw Out', 'Sqr Out', 'Tri Out'],
      defaultParams: {'Tune': 0.5, 'Fine': 0.5, 'PWM': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'vco_complex_dual',
      title: 'COMPLEX DUAL VCO',
      subtitle: 'FM & Wavefolder',
      hpWidth: 14,
      accentColor: Color(0xFFFF3D00),
      category: 'VCO',
      description: 'Dual interconnected oscillators with thru-zero FM, wavefolding, and ring mod.',
      inputJacks: ['1V/Oct A', '1V/Oct B', 'FM In', 'Fold CV'],
      outputJacks: ['Primary Out', 'Fold Out'],
      defaultParams: {'Ratio': 0.5, 'FM Index': 0.4, 'Fold': 0.3},
    ),
    DynamicModuleDefinition(
      id: 'vco_chip_noise',
      title: 'CHIP NOISE & SFX',
      subtitle: 'Lo-Fi Retro Noise',
      hpWidth: 12,
      accentColor: Color(0xFFFF7043),
      category: 'VCO',
      description: 'Retro 8-bit LFSR pseudo-random noise generator and game sound FX generator.',
      inputJacks: ['Clock In', 'Pitch CV', 'Mode CV'],
      outputJacks: ['Noise Out', 'Pulse Out'],
      defaultParams: {'Density': 0.5, 'Color': 0.6},
    ),
    DynamicModuleDefinition(
      id: 'vco_wavetable',
      title: 'WAVETABLE OSC',
      subtitle: 'Morphing Tables',
      hpWidth: 12,
      accentColor: Color(0xFFFF9E80),
      category: 'VCO',
      description: 'Digital wavetable synthesis core with continuous 2D position morphing.',
      inputJacks: ['1V/Oct', 'Morph CV', 'Phase In'],
      outputJacks: ['Table Out', 'Sub Out'],
      defaultParams: {'Table': 0.2, 'Morph': 0.5, 'Sub': 0.3},
    ),

    // --- VCF: FILTERS ---
    DynamicModuleDefinition(
      id: 'vcf_ladder',
      title: 'DIODE LADDER VCF',
      subtitle: '24dB Resonant Filter',
      hpWidth: 12,
      accentColor: Color(0xFFFF9800),
      category: 'VCF',
      description: 'Saturating 4-pole transistor diode ladder lowpass with nonlinear resonance.',
      inputJacks: ['Audio In', 'Cutoff CV', 'Res CV'],
      outputJacks: ['LP Out', 'Drive Out'],
      defaultParams: {'Cutoff': 0.6, 'Resonance': 0.4, 'Drive': 0.3},
    ),
    DynamicModuleDefinition(
      id: 'vcf_svf',
      title: 'STATE VARIABLE VCF',
      subtitle: '12dB Multi-Mode SVF',
      hpWidth: 12,
      accentColor: Color(0xFFFFB74D),
      category: 'VCF',
      description: 'Clean state-variable filter providing simultaneous LP, BP, HP, and Notch outputs.',
      inputJacks: ['Audio In', 'Cutoff CV', 'FM In'],
      outputJacks: ['Lowpass', 'Bandpass', 'Highpass'],
      defaultParams: {'Freq': 0.5, 'Q Factor': 0.3},
    ),
    DynamicModuleDefinition(
      id: 'vcf_acid_303',
      title: 'ACID DIODE VCF',
      subtitle: 'TB-303 Screaming Diode',
      hpWidth: 10,
      accentColor: Color(0xFFFFC107),
      category: 'VCF',
      description: 'Authentic 18dB diode filter with rubbery squelch and accent envelope mod.',
      inputJacks: ['Audio In', 'Env In', 'Accent In'],
      outputJacks: ['VCF Out'],
      defaultParams: {'Cutoff': 0.45, 'Resonance': 0.75, 'Env Mod': 0.6},
    ),
    DynamicModuleDefinition(
      id: 'vcf_formant',
      title: 'FORMANT VOWEL VCF',
      subtitle: 'Triple Formant Resonator',
      hpWidth: 12,
      accentColor: Color(0xFFFFE082),
      category: 'VCF',
      description: 'Triple parallel bandpass filter tuned to vocal vowel frequencies (A-E-I-O-U).',
      inputJacks: ['Audio In', 'Vowel CV', 'Shift CV'],
      outputJacks: ['Vocal Out'],
      defaultParams: {'Vowel': 0.5, 'Brightness': 0.5},
    ),

    // --- MOD: MODULATION & ENVELOPES ---
    DynamicModuleDefinition(
      id: 'mod_adsr',
      title: 'ADSR ENVELOPE',
      subtitle: '4-Stage Modulator',
      hpWidth: 11,
      accentColor: Color(0xFF00E676),
      category: 'MOD',
      description: 'Classic Attack-Decay-Sustain-Release envelope with linear/exponential curves.',
      inputJacks: ['Gate In', 'Retrig', 'CV Mod'],
      outputJacks: ['Env Out', 'Inv Out'],
      defaultParams: {'Attack': 0.05, 'Decay': 0.3, 'Sustain': 0.6, 'Release': 0.4},
    ),
    DynamicModuleDefinition(
      id: 'mod_dual_lfo',
      title: 'DUAL SYNC LFO',
      subtitle: 'BPM-Locked Modulator',
      hpWidth: 10,
      accentColor: Color(0xFF69F0AE),
      category: 'MOD',
      description: 'Twin low frequency oscillators with tempo sync, phase reset, and wave shaping.',
      inputJacks: ['Sync In', 'Rate CV', 'Reset In'],
      outputJacks: ['LFO 1 Out', 'LFO 2 Out'],
      defaultParams: {'Rate 1': 0.25, 'Rate 2': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'mod_maths_function',
      title: 'FUNCTION GENERATOR',
      subtitle: 'Dual Slew & Envelope',
      hpWidth: 12,
      accentColor: Color(0xFFB9F6CA),
      category: 'MOD',
      description: 'Versatile analog computing module for envelopes, slew limiting, and cycling LFO.',
      inputJacks: ['Rise CV', 'Fall CV', 'Trig In', 'Signal In'],
      outputJacks: ['Function Out', 'End Of Cycle'],
      defaultParams: {'Rise': 0.2, 'Fall': 0.4, 'Curve': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'mod_step_seq',
      title: 'STEP CV SEQUENCER',
      subtitle: '8-Step Mod Matrix',
      hpWidth: 14,
      accentColor: Color(0xFF00B0FF),
      category: 'MOD',
      description: '8-step analog voltage sequencer with selectable glide, range, and clock divider.',
      inputJacks: ['Clock In', 'Reset In', 'Glide CV'],
      outputJacks: ['Pitch Out', 'Gate Out'],
      defaultParams: {'Glide': 0.1, 'Length': 8.0},
    ),

    // --- FX: AUDIO EFFECTS ---
    DynamicModuleDefinition(
      id: 'fx_tape_delay',
      title: 'TAPE DELAY FX',
      subtitle: 'Analog Bucket Echo',
      hpWidth: 12,
      accentColor: Color(0xFF00BCD4),
      category: 'FX',
      description: 'Warm tape delay simulation with flutter, saturation, and feedback resonance.',
      inputJacks: ['Audio In', 'Time CV', 'Feedback CV'],
      outputJacks: ['Wet Out', 'Direct Out'],
      defaultParams: {'Time': 0.35, 'Feedback': 0.45, 'Mix': 0.4},
    ),
    DynamicModuleDefinition(
      id: 'fx_drive',
      title: 'TANH OVERDRIVE',
      subtitle: 'Tube Saturation VCA',
      hpWidth: 10,
      accentColor: Color(0xFFE91E63),
      category: 'FX',
      description: 'Hyperbolic tangent saturator and soft clipper for thick harmonic distortion.',
      inputJacks: ['In', 'Drive CV', 'Tone CV'],
      outputJacks: ['Clipped Out'],
      defaultParams: {'Drive': 0.6, 'Tone': 0.5, 'Level': 0.7},
    ),
    DynamicModuleDefinition(
      id: 'fx_stereo_reverb',
      title: 'STEREO REVERB',
      subtitle: 'Algorithmic Space',
      hpWidth: 12,
      accentColor: Color(0xFF80DEEA),
      category: 'FX',
      description: 'Rich algorithmic reverb with plate and spring diffusion algorithms.',
      inputJacks: ['In L', 'In R', 'Decay CV'],
      outputJacks: ['Out L', 'Out R'],
      defaultParams: {'Decay': 0.6, 'Damping': 0.3, 'Wet': 0.35},
    ),
    DynamicModuleDefinition(
      id: 'fx_bitcrusher',
      title: 'BITCRUSHER FX',
      subtitle: 'Lo-Fi Downsampler',
      hpWidth: 10,
      accentColor: Color(0xFFFF4081),
      category: 'FX',
      description: 'Quantization distortion and sample rate reduction for 8-bit grit.',
      inputJacks: ['In', 'Bits CV', 'Crush CV'],
      outputJacks: ['Crushed Out'],
      defaultParams: {'Bits': 8.0, 'Downsample': 0.2, 'Mix': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'fx_stereo_chorus',
      title: 'STEREO CHORUS',
      subtitle: 'BBD Ensemble FX',
      hpWidth: 12,
      accentColor: Color(0xFF4DD0E1),
      category: 'FX',
      description: 'Dual-phase bucket brigade ensemble chorus with dimension width expansion.',
      inputJacks: ['In L', 'In R', 'Rate CV'],
      outputJacks: ['Out L', 'Out R'],
      defaultParams: {'Rate': 0.3, 'Depth': 0.5, 'Width': 0.8},
    ),

    // --- SCRIPT: PROGRAMMABLE CODE MODULES ---
    DynamicModuleDefinition(
      id: 'script_dsp_node',
      title: 'CUSTOM LUA DSP',
      subtitle: 'Programmable Script Node',
      hpWidth: 15,
      accentColor: Color(0xFF00E5FF),
      category: 'SCRIPT',
      description: 'Programmable real-time DSP module running custom Lua audio code, filters & synths.',
      inputJacks: ['Audio In L', 'CV In 1', 'CV In 2', 'Gate In'],
      outputJacks: ['Audio Out L', 'Audio Out R', 'Mod Out'],
      defaultParams: {'Param 1': 0.5, 'Param 2': 0.5, 'Drive': 0.4},
      scriptCode: '-- Custom Lua DSP Module\nfunction process(sample, cv1, cv2)\n  return sample * (1.0 + cv1 * 0.5)\nend\n',
    ),
    DynamicModuleDefinition(
      id: 'script_midi_transform',
      title: 'MIDI LUA TRANSFORM',
      subtitle: 'Algorithmic Note FX',
      hpWidth: 12,
      accentColor: Color(0xFFFFD54F),
      category: 'SCRIPT',
      description: 'Custom script processor for chord generation, arpeggiation, and pitch transforms.',
      inputJacks: ['MIDI In', 'Gate In', 'Transpose CV'],
      outputJacks: ['MIDI Out', 'Gate Out', 'Pitch CV'],
      defaultParams: {'Chance': 0.8, 'Div': 0.5},
      scriptCode: '-- MIDI Script Processor\nfunction onNote(note, vel)\n  return note, vel\nend\n',
    ),
    DynamicModuleDefinition(
      id: 'script_math_logic',
      title: 'LUA MATH & LOGIC',
      subtitle: 'Scripted Signal Math',
      hpWidth: 10,
      accentColor: Color(0xFF76FF03),
      category: 'SCRIPT',
      description: 'Fast mathematical expressions, logical gates, and CV rectifiers defined in Lua.',
      inputJacks: ['CV A', 'CV B', 'Trig In'],
      outputJacks: ['Sum Out', 'Logic Out'],
      defaultParams: {'Scale A': 1.0, 'Scale B': 1.0},
      scriptCode: '-- CV Math\nfunction calc(a, b)\n  return math.max(a, b)\nend\n',
    ),

    // --- OUT / UTILITY: ROUTING & MIXING ---
    DynamicModuleDefinition(
      id: 'out_vca',
      title: 'STEREO OUT VCA',
      subtitle: 'Master Summing Bus',
      hpWidth: 10,
      accentColor: Color(0xFFFFD600),
      category: 'OUT',
      description: 'Dual linear/exponential VCA with stereo panning and master output limiting.',
      inputJacks: ['L In', 'R In', 'Level CV'],
      outputJacks: ['Out L', 'Out R'],
      defaultParams: {'Volume': 0.8, 'Pan': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'util_4ch_mixer',
      title: '4-CH AUDIO MIXER',
      subtitle: 'Level & Pan Summing',
      hpWidth: 12,
      accentColor: Color(0xFFE0E0E0),
      category: 'OUT',
      description: '4-channel DC-coupled utility mixer for combining audio signals or CV modulations.',
      inputJacks: ['Ch 1', 'Ch 2', 'Ch 3', 'Ch 4'],
      outputJacks: ['Master L', 'Master R'],
      defaultParams: {'Ch1': 0.7, 'Ch2': 0.7, 'Ch3': 0.5, 'Ch4': 0.5},
    ),
    DynamicModuleDefinition(
      id: 'util_attenuverter',
      title: 'ATTENUVERTER',
      subtitle: 'Dual Inverter & Offset',
      hpWidth: 8,
      accentColor: Color(0xFFB0BEC5),
      category: 'OUT',
      description: 'Scale, invert, and add DC bias to modulation signals before patching.',
      inputJacks: ['In A', 'In B'],
      outputJacks: ['Out A', 'Out B'],
      defaultParams: {'Atten A': 0.5, 'Offset A': 0.0, 'Atten B': 0.5, 'Offset B': 0.0},
    ),
  ];
}

/// Unified Search & Filter Modal Dialog for Modular Rack Modules.
/// Replaces hardcoded bottom sheet with rich categorization, HP badges, and instant search.
class ModularModuleSearchDialog extends StatefulWidget {
  final int targetRow;
  final String? initialCategory;

  const ModularModuleSearchDialog({
    super.key,
    required this.targetRow,
    this.initialCategory,
  });

  static Future<DynamicModuleDefinition?> show(
    BuildContext context, {
    required int targetRow,
    String? initialCategory,
  }) {
    return showDialog<DynamicModuleDefinition>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => ModularModuleSearchDialog(
        targetRow: targetRow,
        initialCategory: initialCategory,
      ),
    );
  }

  @override
  State<ModularModuleSearchDialog> createState() => _ModularModuleSearchDialogState();
}

class _ModularModuleSearchDialogState extends State<ModularModuleSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  late String? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'VCO':
        return const Color(0xFFFF5722);
      case 'VCF':
        return const Color(0xFFFF9800);
      case 'MOD':
        return const Color(0xFF00E676);
      case 'FX':
        return const Color(0xFF00BCD4);
      case 'SCRIPT':
        return const Color(0xFF00E5FF);
      case 'OUT':
      case 'UTILITY':
      default:
        return const Color(0xFFFFD600);
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'VCO':
        return Icons.waves;
      case 'VCF':
        return Icons.tune;
      case 'MOD':
        return Icons.show_chart;
      case 'FX':
        return Icons.graphic_eq;
      case 'SCRIPT':
        return Icons.code;
      case 'OUT':
      case 'UTILITY':
      default:
        return Icons.alt_route;
    }
  }

  List<DynamicModuleDefinition> _getFilteredModules() {
    var list = ModularModuleLibrary.modules;
    if (_selectedCategory != null) {
      list = list.where((m) => m.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((m) {
        return m.title.toLowerCase().contains(q) ||
            m.subtitle.toLowerCase().contains(q) ||
            m.category.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            m.inputJacks.any((j) => j.toLowerCase().contains(q)) ||
            m.outputJacks.any((j) => j.toLowerCase().contains(q));
      }).toList();
    }
    return list;
  }

  Widget _buildCategoryFilterChip(String? category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    final color = category != null ? _getCategoryColor(category) : EatsTheme.primaryCyan;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedCategory = category;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.22) : Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.white24,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? color : EatsTheme.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : EatsTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredModules();
    final isSmallScreen = MediaQuery.of(context).size.width < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 680,
        height: 600,
        decoration: BoxDecoration(
          color: ModularTheme.caseBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ModularTheme.railMetalColor,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: ModularTheme.railMetalColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_circle, color: ModularTheme.cablePitchCv, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ADD MODULE TO ROW ${widget.targetRow}',
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // --- SEARCH & CATEGORIES ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Input
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search modules by name, jacks, DSP description...',
                        hintStyle: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, size: 18, color: ModularTheme.cablePitchCv),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryFilterChip(null, 'ALL', Icons.apps),
                        _buildCategoryFilterChip('VCO', 'VCO (OSC)', Icons.waves),
                        _buildCategoryFilterChip('VCF', 'VCF (FILTERS)', Icons.tune),
                        _buildCategoryFilterChip('MOD', 'MOD & ENVELOPES', Icons.show_chart),
                        _buildCategoryFilterChip('FX', 'AUDIO FX', Icons.graphic_eq),
                        _buildCategoryFilterChip('SCRIPT', 'SCRIPT DSP', Icons.code),
                        _buildCategoryFilterChip('OUT', 'OUT & UTILITIES', Icons.alt_route),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- STATUS BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'MODULE' : 'MODULES'} AVAILABLE',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),
                  const Text(
                    'CLICK TO INSERT INTO RACK',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 9,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // --- MODULE CARDS GRID ---
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.search_off, size: 36, color: Colors.white24),
                          SizedBox(height: 8),
                          Text(
                            'No matching modular hardware found',
                            style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isSmallScreen ? 1 : 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isSmallScreen ? 2.4 : 1.9,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final mod = filtered[index];
                        return _buildModuleCard(context, mod);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, DynamicModuleDefinition mod) {
    final catColor = _getCategoryColor(mod.category);
    final isScript = mod.category == 'SCRIPT';

    return InkWell(
      onTap: () => Navigator.of(context).pop(mod),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ModularTheme.faceplateDarkBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isScript ? const Color(0xFF00E5FF).withOpacity(0.6) : mod.accentColor.withOpacity(0.4),
            width: isScript ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Category & HP Width
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
                    color: Colors.black.withOpacity(0.5),
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

            // Title & Subtitle
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
                    color: mod.accentColor.withOpacity(0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // Description
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

            // Jacks Footer
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
                    color: mod.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: mod.accentColor.withOpacity(0.6)),
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
