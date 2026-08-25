import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../audio/soundfont_engine.dart';
import '../models/daw_state.dart';
import '../theme/eats_theme.dart';
import '../utils/html_preloader_helper.dart';
import '../utils/soundfont_pack_manager.dart';
import 'transport_header.dart';

/// Skeuomorphic vintage rack panel loading screen for Eatsbeats startup.
class EatsbeatsLoadingScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;
  final DawState? dawState;

  const EatsbeatsLoadingScreen({
    super.key,
    required this.onInitializationComplete,
    this.dawState,
  });

  @override
  State<EatsbeatsLoadingScreen> createState() => _EatsbeatsLoadingScreenState();
}

class _EatsbeatsLoadingScreenState extends State<EatsbeatsLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentStepIndex = 0;
  double _progress = 0.0;
  Timer? _stepTimer;

  final List<String> _initSteps = const [
    'POWERING ON DIGITAL RACK HARDWARE...',
    'INITIALIZING WEBAUDIO GRAPH CONTEXT...',
    'PRE-LOADING BUNDLED SOUNDFONT (SUPER SMALL FONT)...',
    'RESTORE CACHED SOUNDFONTS & USER PREFERENCES...',
    'PRE-COMPILING LUA SYNTH MODULES (303, KICK, SNARE)...',
    'WARMING UP DSP RACK FX PROCESSORS...',
    'SYSTEM INITIALIZATION COMPLETE - DAWN OF SOUND',
  ];

  @override
  void initState() {
    super.initState();
    HtmlPreloaderHelper.dismissHtmlPreloader();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startInitializationSequence();
  }

  void _startInitializationSequence() {
    final initFuture = () async {
      SoundFontEngine.instance.loadDefaultBundledFont();
      await SoundFontPackManager.instance.restoreCachedPacks();
      if (widget.dawState != null) {
        await widget.dawState!.loadPersistedSettings();
        if (widget.dawState!.autoRestoreSession) {
          await widget.dawState!.restoreSavedSession();
        }
      }
    }();

    const totalDurationMs = 1500;
    const intervalMs = 60;
    const totalTicks = totalDurationMs ~/ intervalMs;
    int tickCount = 0;

    _stepTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      tickCount++;
      setState(() {
        _progress = (tickCount / totalTicks).clamp(0.0, 1.0);
        _currentStepIndex = ((_progress * (_initSteps.length - 1)).floor()).clamp(0, _initSteps.length - 1);
      });

      if (tickCount >= totalTicks) {
        timer.cancel();
        try {
          await initFuture;
        } catch (e) {
          debugPrint('Startup init error: $e');
        }
        if (mounted) {
          widget.onInitializationComplete();
        }
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAmberTheme = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final primaryColor = EatsTheme.primaryCyan;
    const accentAmber = Color(0xFFFF8C00);

    return Scaffold(
      backgroundColor: EatsTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540),
              decoration: BoxDecoration(
                color: EatsTheme.panelBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAmberTheme ? const Color(0xFF4A423A) : EatsTheme.panelHeader,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Corner Hex Screws (Skeuomorphic hardware detail)
                  Positioned(top: 10, left: 10, child: _buildHexScrew()),
                  Positioned(top: 10, right: 10, child: _buildHexScrew()),
                  Positioned(bottom: 10, left: 10, child: _buildHexScrew()),
                  Positioned(bottom: 10, right: 10, child: _buildHexScrew()),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 36.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header / Brand Logo Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1218),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accentAmber, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentAmber.withOpacity(0.35),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: EatsBeatsMonsterIcon(
                                size: 36,
                                backgroundColor: accentAmber,
                                iconColor: const Color(0xFF0F1218),
                                eyeColor: accentAmber,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EATSBEATS',
                                  style: EatsTheme.getDisplayFontStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: accentAmber,
                                  ),
                                ),
                                Text(
                                  'MODEL 808-LUA // HARDWARE RACK SYSTEM',
                                  style: EatsTheme.getPrimaryFontStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: EatsTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Hardware Status LED Lamps
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0A09),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF26221D)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatusLed('POWER', true, const Color(0xFF00FF66)),
                              _buildStatusLed('AUDIO', _progress > 0.2, primaryColor),
                              _buildStatusLed('LUA CORE', _progress > 0.5, accentAmber),
                              _buildStatusLed('DSP READY', _progress > 0.85, const Color(0xFFFF007A)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Simulated VU Level Meter Warm-up Graphic
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _HardwareMeterPainter(
                              progress: _progress,
                              pulse: _animController.value,
                              primaryColor: primaryColor,
                              accentAmber: accentAmber,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Progress Bar Container
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF080706),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFF332F2A)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor,
                                        accentAmber,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.6),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Monospaced Diagnostic Terminal Status
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF080706),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1E1A16)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '> ',
                                style: EatsTheme.getDisplayFontStyle(
                                  fontSize: 12,
                                  color: accentAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _initSteps[_currentStepIndex],
                                  style: EatsTheme.getDisplayFontStyle(
                                    fontSize: 11,
                                    color: EatsTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(_progress * 100).toInt()}%',
                                style: EatsTheme.getDisplayFontStyle(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHexScrew() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF181614),
        border: Border.all(color: const Color(0xFF4A423A), width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0A0908),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLed(String label, bool isOn, Color ledColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn ? ledColor : const Color(0xFF201D19),
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: ledColor.withOpacity(0.8),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: EatsTheme.getDisplayFontStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: isOn ? EatsTheme.textPrimary : EatsTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _HardwareMeterPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final Color primaryColor;
  final Color accentAmber;

  _HardwareMeterPainter({
    required this.progress,
    required this.pulse,
    required this.primaryColor,
    required this.accentAmber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const numBars = 24;
    final barWidth = (size.width - (numBars - 1) * 3) / numBars;

    for (int i = 0; i < numBars; i++) {
      final x = i * (barWidth + 3);
      final threshold = i / numBars;
      final isActive = progress >= threshold;

      Color color;
      if (i < 14) {
        color = primaryColor;
      } else if (i < 20) {
        color = accentAmber;
      } else {
        color = const Color(0xFFFF007A);
      }

      final activeHeight = (size.height * (0.3 + 0.7 * math.sin((i + pulse * 10) * 0.5).abs())).clamp(6.0, size.height);

      final paint = Paint()
        ..color = isActive ? color : const Color(0xFF1E1B17);

      if (isActive && i == (progress * numBars).floor()) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      }

      final rect = Rect.fromLTWH(
        x,
        size.height - (isActive ? activeHeight : 6.0),
        barWidth,
        isActive ? activeHeight : 6.0,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HardwareMeterPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}
