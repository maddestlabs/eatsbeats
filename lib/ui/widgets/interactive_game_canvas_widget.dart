import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/snes_dsp_engine.dart';
import '../../lua/lua_gui_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

class GridPos {
  final int x;
  final int y;
  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPos && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Interactive hardware canvas supporting pixel framebuffers, retro tile matrices
/// (like FastTracker II Nibbles), vector arcade oscilloscopes, and audiovisual runner games.
class InteractiveGameCanvasWidget extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;
  final LuaGuiNode node;
  final Color accentColor;
  final bool isLightChassis;

  const InteractiveGameCanvasWidget({
    super.key,
    required this.dawState,
    required this.track,
    required this.node,
    required this.accentColor,
    this.isLightChassis = false,
  });

  @override
  State<InteractiveGameCanvasWidget> createState() => _InteractiveGameCanvasWidgetState();
}

class _InteractiveGameCanvasWidgetState extends State<InteractiveGameCanvasWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final FocusNode _focusNode = FocusNode();

  // Common Game / Visual State
  double _gameTime = 0.0;
  int _lastTickStep = -1;

  // FT2 Nibbles State
  late int _gridCols;
  late int _gridRows;
  List<GridPos> _snake = [const GridPos(10, 10), const GridPos(9, 10), const GridPos(8, 10)];
  GridPos _snakeDir = const GridPos(1, 0);
  GridPos _nextSnakeDir = const GridPos(1, 0);
  GridPos _food = const GridPos(20, 12);
  int _score = 0;
  bool _isGameOver = false;
  double _tickAccumulator = 0.0;

  // 16-Bit Runner State
  double _playerY = 0.0;
  double _playerVy = 0.0;
  bool _isGrounded = true;
  double _scrollOffset = 0.0;
  List<double> _obstacleXs = [180.0, 320.0, 480.0];
  List<double> _coinXs = [120.0, 240.0, 380.0];
  int _runnerScore = 0;
  double _lastJumpParam = 0.0;

  @override
  void initState() {
    super.initState();
    _gridCols = widget.node.cols > 0 ? widget.node.cols : 32;
    _gridRows = widget.node.rows > 0 ? widget.node.rows : 22;

    _resetNibbles();

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    _ticker.repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetNibbles() {
    _snake = [
      GridPos(_gridCols ~/ 3, _gridRows ~/ 2),
      GridPos(_gridCols ~/ 3 - 1, _gridRows ~/ 2),
      GridPos(_gridCols ~/ 3 - 2, _gridRows ~/ 2),
    ];
    _snakeDir = const GridPos(1, 0);
    _nextSnakeDir = const GridPos(1, 0);
    _spawnFood();
    _score = 0;
    _isGameOver = false;
    _tickAccumulator = 0.0;
  }

  void _spawnFood() {
    final rng = math.Random();
    int fx, fy;
    int attempts = 0;
    do {
      fx = rng.nextInt(_gridCols);
      fy = rng.nextInt(_gridRows);
      attempts++;
    } while (_snake.contains(GridPos(fx, fy)) && attempts < 100);
    _food = GridPos(fx, fy);
  }

  void _playSfx(String typeName, {int seed = 42, int midiPitch = 72}) {
    try {
      final sfxIdx = _getSfxTypeIndex(typeName);
      final generatedParams = SNESSFXRGenerator.generateParamsForType(sfxIdx, seed: seed);

      // Temporarily audition note via DawState audio engine
      widget.dawState.audioEngine.playNoteOrSample(
        track: widget.track,
        midiNote: midiPitch,
        velocity: 0.9,
        durationSec: 0.35,
      );
    } catch (_) {}
  }

  int _getSfxTypeIndex(String name) {
    switch (name.toLowerCase()) {
      case 'laser': return 0;
      case 'explosion': return 1;
      case 'powerup': return 2;
      case 'coin': return 3;
      case 'jump': return 4;
      case 'hurt': return 5;
      case 'lose': return 6;
      case 'button': return 7;
      case 'warp': return 8;
      case 'mutate': return 9;
      default: return 3;
    }
  }

  void _onTick() {
    if (!mounted) return;
    if (!TickerMode.of(context)) return;

    final dt = 0.0166; // approx 60fps frame delta
    _gameTime += dt;
    _scrollOffset += dt * 90.0;

    final isNibbles = _isNibblesGame();
    final isRunner = _isRunnerGame();

    // Check transport beat-sync
    final currentStep = widget.dawState.currentStep.toInt();
    final bool stepTriggered = currentStep != _lastTickStep && widget.dawState.isPlaying;
    _lastTickStep = currentStep;

    // Check automated Jump / Action params
    final jumpParam = widget.track.luaParams['Jump'] ?? widget.track.luaParams['TriggerJump'] ?? 0.0;
    if (jumpParam > 0.5 && _lastJumpParam <= 0.5) {
      _triggerJump();
    }
    _lastJumpParam = jumpParam;

    if (isNibbles) {
      _updateNibbles(dt, stepTriggered);
    } else if (isRunner) {
      _updateRunner(dt);
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _isNibblesGame() {
    final code = widget.track.luaScriptCode.toLowerCase();
    final name = widget.track.name.toLowerCase();
    final mode = widget.node.canvasMode.toLowerCase();
    return code.contains('nibble') ||
        code.contains('snake') ||
        name.contains('nibble') ||
        name.contains('snake') ||
        mode == 'grid' ||
        widget.node.type == LuaGuiNodeType.dpad;
  }

  bool _isRunnerGame() {
    final code = widget.track.luaScriptCode.toLowerCase();
    final name = widget.track.name.toLowerCase();
    return code.contains('runner') ||
        code.contains('sidescroll') ||
        code.contains('jump') ||
        name.contains('runner') ||
        name.contains('platform');
  }

  void _updateNibbles(double dt, bool stepTriggered) {
    if (_isGameOver) return;

    final speedParam = widget.track.luaParams['Speed'] ?? 12.0;
    final tickInterval = 1.0 / math.max(4.0, speedParam);

    _tickAccumulator += dt;

    // Optional beat sync: turn on step
    final beatSync = (widget.track.luaParams['BeatSync'] ?? 0.0) > 0.5;
    if (beatSync && stepTriggered) {
      // Auto turn rhythmically
      if (_snakeDir.x != 0) {
        _nextSnakeDir = _snake.first.y > _food.y ? const GridPos(0, -1) : const GridPos(0, 1);
      } else {
        _nextSnakeDir = _snake.first.x > _food.x ? const GridPos(-1, 0) : const GridPos(1, 0);
      }
    }

    if (_tickAccumulator >= tickInterval) {
      _tickAccumulator -= tickInterval;
      _snakeDir = _nextSnakeDir;

      final head = _snake.first;
      final newHead = GridPos(head.x + _snakeDir.x, head.y + _snakeDir.y);

      // Wall collision
      if (newHead.x < 0 || newHead.x >= _gridCols || newHead.y < 0 || newHead.y >= _gridRows) {
        _isGameOver = true;
        _playSfx('Explosion', seed: 999);
        return;
      }

      // Self collision
      if (_snake.contains(newHead)) {
        _isGameOver = true;
        _playSfx('Explosion', seed: 777);
        return;
      }

      _snake.insert(0, newHead);

      // Eat food
      if (newHead == _food) {
        _score += 10;
        _spawnFood();
        _playSfx('Coin', seed: _score * 19 + 7, midiPitch: 72 + (_score % 12));
      } else {
        _snake.removeLast();
      }
    }
  }

  void _updateRunner(double dt) {
    // Gravity & Jump Physics
    if (!_isGrounded) {
      _playerVy += 650.0 * dt;
      _playerY += _playerVy * dt;
      if (_playerY >= 0.0) {
        _playerY = 0.0;
        _playerVy = 0.0;
        _isGrounded = true;
      }
    }

    // Scroll obstacles
    for (int i = 0; i < _obstacleXs.length; i++) {
      _obstacleXs[i] -= dt * 120.0;
      if (_obstacleXs[i] < -30.0) {
        _obstacleXs[i] = 340.0 + (i * 140.0);
      }

      // Collision check with player
      if (_obstacleXs[i] > 30.0 && _obstacleXs[i] < 60.0 && _playerY > -20.0) {
        // Hit obstacle
        _obstacleXs[i] = -40.0;
        _playSfx('Hurt', seed: 333);
      }
    }

    // Scroll coins
    for (int i = 0; i < _coinXs.length; i++) {
      _coinXs[i] -= dt * 120.0;
      if (_coinXs[i] < -30.0) {
        _coinXs[i] = 300.0 + (i * 120.0);
      }

      // Collect check
      if (_coinXs[i] > 30.0 && _coinXs[i] < 60.0 && _playerY < -15.0) {
        _coinXs[i] = -40.0;
        _runnerScore += 5;
        _playSfx('Coin', seed: 1200 + _runnerScore, midiPitch: 76);
      }
    }
  }

  void _triggerJump() {
    if (_isGrounded) {
      _isGrounded = false;
      _playerVy = -320.0;
      _playSfx('Jump', seed: 543, midiPitch: 68);
    }
  }

  void _handleDirectionInput(GridPos newDir) {
    if (_isGameOver) {
      _resetNibbles();
      return;
    }
    // Prevent 180-degree instant reversal
    if (newDir.x != -_snakeDir.x || newDir.y != -_snakeDir.y) {
      _nextSnakeDir = newDir;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
        _handleDirectionInput(const GridPos(0, -1));
        _triggerJump();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
        _handleDirectionInput(const GridPos(0, 1));
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
        _handleDirectionInput(const GridPos(-1, 0));
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
        _handleDirectionInput(const GridPos(1, 0));
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
        if (_isGameOver) {
          _resetNibbles();
        } else {
          _triggerJump();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.node.width ?? 320.0;
    final height = widget.node.height ?? 200.0;
    final showControls = _isNibblesGame() || _isRunnerGame();

    final trackId = widget.track.id;
    final isMasterBus = trackId == 'master_bus' || trackId == 'master' || widget.track.name.toLowerCase().contains('master');
    final targetTrackId = isMasterBus ? null : trackId;

    final gainParam = widget.track.luaParams['Gain'] ?? 1.0;
    final timebaseParam = widget.track.luaParams['Timebase'] ?? 1.0;
    final decayParam = widget.track.luaParams['Decay'] ?? 0.6;
    final modeParam = widget.track.luaParams['Mode'] ?? 0.0;
    final glowColorParam = widget.track.luaParams['GlowColor'] ?? 0.0;

    Color effectiveAccent = widget.accentColor;
    if (widget.track.luaParams.containsKey('GlowColor')) {
      final colIdx = glowColorParam.toInt().clamp(0, 4);
      const glowPalette = [
        Color(0xFF00FF9D), // Neon Mint
        Color(0xFF00E5FF), // Cyber Cyan
        Color(0xFFFF3366), // Laser Red
        Color(0xFFFFD700), // Gold Solar
        Color(0xFFE040FB), // Purple Dream
      ];
      effectiveAccent = glowPalette[colIdx];
    }

    final waveform = widget.dawState.audioEngine.getWaveformSamples(
      trackId: targetTrackId,
      count: 96,
      gain: gainParam,
      timebase: timebaseParam,
    );

    final numSpectrumBands = (modeParam == 1.0) ? 8 : 16;
    final spectrum = widget.dawState.audioEngine.getSpectrumBands(
      trackId: targetTrackId,
      bands: numSpectrumBands,
      gain: gainParam,
      decay: decayParam,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Focus(
          focusNode: _focusNode,
          autofocus: showControls,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              return _handleKeyEvent(node, event);
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
              if (_isGameOver) _resetNibbles();
            },
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0E12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: effectiveAccent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveAccent.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.5),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(width, height),
                      painter: _GameCanvasPainter(
                        mode: widget.node.canvasMode,
                        accentColor: effectiveAccent,
                        gameTime: _gameTime,
                        scrollOffset: _scrollOffset,
                        isNibbles: _isNibblesGame(),
                        isRunner: _isRunnerGame(),
                        gridCols: _gridCols,
                        gridRows: _gridRows,
                        snake: _snake,
                        food: _food,
                        score: _isRunnerGame() ? _runnerScore : _score,
                        isGameOver: _isGameOver,
                        playerY: _playerY,
                        obstacleXs: _obstacleXs,
                        coinXs: _coinXs,
                        isPlaying: widget.dawState.isPlaying,
                        waveform: waveform,
                        spectrum: spectrum,
                      ),
                    ),
                    // Retro CRT Scanline Overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ScanlineOverlayPainter(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Virtual Touch D-Pad & Action Buttons for Mobile / Touch
        if (showControls) ...[
          const SizedBox(height: 10),
          _buildVirtualGameControls(),
        ],
      ],
    );
  }

  Widget _buildVirtualGameControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF16171D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Virtual D-Pad
          SizedBox(
            width: 96,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Up
                Positioned(
                  top: 0,
                  child: _buildDPadBtn(
                    icon: Icons.keyboard_arrow_up,
                    onTap: () => _handleDirectionInput(const GridPos(0, -1)),
                  ),
                ),
                // Down
                Positioned(
                  bottom: 0,
                  child: _buildDPadBtn(
                    icon: Icons.keyboard_arrow_down,
                    onTap: () => _handleDirectionInput(const GridPos(0, 1)),
                  ),
                ),
                // Left
                Positioned(
                  left: 0,
                  child: _buildDPadBtn(
                    icon: Icons.keyboard_arrow_left,
                    onTap: () => _handleDirectionInput(const GridPos(-1, 0)),
                  ),
                ),
                // Right
                Positioned(
                  right: 0,
                  child: _buildDPadBtn(
                    icon: Icons.keyboard_arrow_right,
                    onTap: () => _handleDirectionInput(const GridPos(1, 0)),
                  ),
                ),
                // Center pip
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22242D),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Action Buttons (Jump / Reset / Fire)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildArcadeBtn(
                label: 'RESET',
                color: const Color(0xFFFF5252),
                onTap: () {
                  _resetNibbles();
                  _playSfx('Button', seed: 101);
                },
              ),
              const SizedBox(width: 12),
              _buildArcadeBtn(
                label: 'JUMP',
                color: widget.accentColor,
                onTap: () {
                  _triggerJump();
                  if (_isGameOver) _resetNibbles();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDPadBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D38),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24, width: 1.0),
          boxShadow: const [
            BoxShadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2),
          ],
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildArcadeBtn({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 1.2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6),
                const BoxShadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 3),
              ],
            ),
            child: const Center(
              child: Icon(Icons.touch_app, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for retro gaming, pixel maps, and vector arcade oscilloscopes.
class _GameCanvasPainter extends CustomPainter {
  final String mode;
  final Color accentColor;
  final double gameTime;
  final double scrollOffset;
  final bool isNibbles;
  final bool isRunner;
  final int gridCols;
  final int gridRows;
  final List<GridPos> snake;
  final GridPos food;
  final int score;
  final bool isGameOver;
  final double playerY;
  final List<double> obstacleXs;
  final List<double> coinXs;
  final bool isPlaying;
  final List<double> waveform;
  final List<double> spectrum;

  _GameCanvasPainter({
    required this.mode,
    required this.accentColor,
    required this.gameTime,
    required this.scrollOffset,
    required this.isNibbles,
    required this.isRunner,
    required this.gridCols,
    required this.gridRows,
    required this.snake,
    required this.food,
    required this.score,
    required this.isGameOver,
    required this.playerY,
    required this.obstacleXs,
    required this.coinXs,
    required this.isPlaying,
    required this.waveform,
    required this.spectrum,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == 'spectrum' || mode == 'bars' || mode == 'equalizer' || mode == 'analyzer') {
      _paintSpectrumAnalyzer(canvas, size);
    } else if (isNibbles || mode == 'grid') {
      _paintNibblesGrid(canvas, size);
    } else if (isRunner) {
      _paint16BitRunner(canvas, size);
    } else {
      _paintVectorOscilloscope(canvas, size);
    }
  }

  void _paintNibblesGrid(Canvas canvas, Size size) {
    final cellW = size.width / gridCols;
    final cellH = size.height / gridRows;

    // Grid Background / border
    final bgPaint = Paint()..color = const Color(0xFF090A0E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Subtle grid lines (FT2 Text-matrix style)
    final linePaint = Paint()
      ..color = const Color(0xFF141620)
      ..strokeWidth = 0.5;
    for (int x = 0; x <= gridCols; x++) {
      canvas.drawLine(Offset(x * cellW, 0), Offset(x * cellW, size.height), linePaint);
    }
    for (int y = 0; y <= gridRows; y++) {
      canvas.drawLine(Offset(0, y * cellH), Offset(size.width, y * cellH), linePaint);
    }

    // Food (Apple / Heart / Dot)
    final foodRect = Rect.fromLTWH(
      food.x * cellW + 1.5,
      food.y * cellH + 1.5,
      cellW - 3,
      cellH - 3,
    );
    final foodPaint = Paint()..color = const Color(0xFFFF3366);
    canvas.drawRRect(RRect.fromRectAndRadius(foodRect, const Radius.circular(3)), foodPaint);

    // Snake Body & Head
    final snakeHeadPaint = Paint()..color = const Color(0xFF00FF9D);
    final snakeBodyPaint = Paint()..color = const Color(0xFF00B36B);

    for (int i = 0; i < snake.length; i++) {
      final p = snake[i];
      final bodyRect = Rect.fromLTWH(
        p.x * cellW + 1.0,
        p.y * cellH + 1.0,
        cellW - 2.0,
        cellH - 2.0,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(i == 0 ? 3.0 : 1.5)),
        i == 0 ? snakeHeadPaint : snakeBodyPaint,
      );
    }

    // HUD Header / Score in FastTracker II font style
    _drawText(
      canvas,
      'SCORE: $score',
      const Offset(8, 6),
      const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00FF9D),
        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
      ),
    );

    if (isGameOver) {
      final bannerRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 200,
        height: 48,
      );
      canvas.drawRect(bannerRect, Paint()..color = Colors.black87);
      canvas.drawRect(
        bannerRect,
        Paint()
          ..color = const Color(0xFFFF3366)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      _drawText(
        canvas,
        'GAME OVER',
        Offset(size.width / 2 - 44, size.height / 2 - 14),
        const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF3366),
        ),
      );
      _drawText(
        canvas,
        'PRESS SPACE TO RETRY',
        Offset(size.width / 2 - 64, size.height / 2 + 4),
        const TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          color: Colors.white70,
        ),
      );
    }
  }

  void _paint16BitRunner(Canvas canvas, Size size) {
    final horizonY = size.height * 0.72;

    // Sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F051D), Color(0xFF261142), Color(0xFF4A154B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizonY));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizonY), skyPaint);

    // Scrolling Stars
    final starPaint = Paint()..color = Colors.white70;
    for (int i = 0; i < 20; i++) {
      final sx = ((i * 37.0 - scrollOffset * 0.2) % size.width + size.width) % size.width;
      final sy = (i * 19.0) % (horizonY - 10.0);
      canvas.drawCircle(Offset(sx, sy), (i % 3 == 0) ? 1.5 : 1.0, starPaint);
    }

    // Mountains / Cityline
    final mountainPath = Path();
    mountainPath.moveTo(0, horizonY);
    for (double x = 0; x <= size.width + 40; x += 40) {
      final my = horizonY - 15.0 - math.sin((x + scrollOffset * 0.4) * 0.05) * 12.0;
      mountainPath.lineTo(x, my);
    }
    mountainPath.lineTo(size.width, horizonY);
    mountainPath.close();
    canvas.drawPath(mountainPath, Paint()..color = const Color(0xFF1E0A38));

    // Ground (Synthwave / SNES Grid floor)
    final groundPaint = Paint()..color = const Color(0xFF120C1F);
    canvas.drawRect(Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY), groundPaint);

    // Scrolling Ground grid lines
    final gridLinePaint = Paint()
      ..color = const Color(0xFF6B2FB5).withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    final groundOffset = scrollOffset % 24.0;
    for (double gx = -groundOffset; gx < size.width; gx += 24.0) {
      canvas.drawLine(Offset(gx, horizonY), Offset(gx - 20, size.height), gridLinePaint);
    }
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), gridLinePaint);

    // Obstacles (Spikes / Blocks)
    final obstaclePaint = Paint()..color = const Color(0xFFFF3366);
    for (final ox in obstacleXs) {
      if (ox >= -20 && ox <= size.width + 20) {
        final obsPath = Path()
          ..moveTo(ox, horizonY)
          ..lineTo(ox + 10, horizonY - 20)
          ..lineTo(ox + 20, horizonY)
          ..close();
        canvas.drawPath(obsPath, obstaclePaint);
      }
    }

    // Collectible Coins
    final coinPaint = Paint()..color = const Color(0xFFFFD700);
    for (final cx in coinXs) {
      if (cx >= -20 && cx <= size.width + 20) {
        canvas.drawCircle(Offset(cx + 8, horizonY - 32), 6.0, coinPaint);
      }
    }

    // 16-Bit Player (Cyber Sprite)
    final px = 45.0;
    final py = horizonY - 24.0 + playerY;

    final playerBodyPaint = Paint()..color = const Color(0xFF00E5FF);
    final playerVisorPaint = Paint()..color = const Color(0xFFFF0055);

    // Torso / Jetpack
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px, py, 14, 24), const Radius.circular(3)),
      playerBodyPaint,
    );
    // Visor
    canvas.drawRect(Rect.fromLTWH(px + 6, py + 4, 8, 4), playerVisorPaint);

    // HUD
    _drawText(
      canvas,
      'SCORE: $score',
      const Offset(8, 6),
      const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00E5FF),
      ),
    );
  }

  void _paintVectorOscilloscope(Canvas canvas, Size size) {
    // Vector Oscilloscope background
    final bgPaint = Paint()..color = const Color(0xFF0A0C10);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Subtle Reticle Grid Lines (CRT Oscilloscope)
    final gridLinePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..strokeWidth = 0.6;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), gridLinePaint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), gridLinePaint);

    for (double gx = 0; gx <= size.width; gx += size.width / 8.0) {
      canvas.drawLine(Offset(gx, cy - 3), Offset(gx, cy + 3), gridLinePaint);
    }
    for (double gy = 0; gy <= size.height; gy += size.height / 6.0) {
      canvas.drawLine(Offset(cx - 3, gy), Offset(cx + 3, gy), gridLinePaint);
    }

    // Glowing Neon Waveform from real audio waveform samples
    final wavePath = Path();
    final centerY = size.height / 2;
    final numPoints = waveform.length;

    if (numPoints > 0) {
      wavePath.moveTo(0, centerY - (waveform[0] * size.height * 0.44));
      for (int i = 1; i < numPoints; i++) {
        final x = i * (size.width / (numPoints - 1));
        final y = centerY - (waveform[i] * size.height * 0.44);
        wavePath.lineTo(x, y);
      }
    } else {
      wavePath.moveTo(0, centerY);
      wavePath.lineTo(size.width, centerY);
    }

    // Glow line (outer neon bloom)
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.40)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(wavePath, glowPaint);

    // Crisp core line
    final corePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(wavePath, corePaint);

    _drawText(
      canvas,
      'VECTOR OSCILLOSCOPE',
      const Offset(8, 6),
      TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: accentColor,
      ),
    );
  }

  void _paintSpectrumAnalyzer(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = const Color(0xFF090B0E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final numBands = spectrum.isNotEmpty ? spectrum.length : 16;
    final totalSpacing = 4.0 * (numBands + 1);
    final barW = (size.width - totalSpacing) / numBands;
    final maxH = size.height - 36.0;

    for (int i = 0; i < numBands; i++) {
      final x = 4.0 + i * (barW + 4.0);
      final level = (i < spectrum.length ? spectrum[i] : 0.05).clamp(0.02, 1.0);
      final barH = maxH * level;
      final y = size.height - 12.0 - barH;

      // Bar Segment Gradient
      final barRect = Rect.fromLTWH(x, y, barW, barH);
      final barShader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF00FF9D),
          accentColor,
          const Color(0xFFFFD700),
          const Color(0xFFFF3366),
        ],
        stops: const [0.0, 0.5, 0.8, 1.0],
      ).createShader(barRect);

      final barPaint = Paint()..shader = barShader;
      canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)), barPaint);

      // Peak Cap Dot
      final peakY = (y - 3.0).clamp(0.0, size.height - 12.0);
      final peakPaint = Paint()..color = const Color(0xFFFFE066);
      canvas.drawRect(Rect.fromLTWH(x, peakY, barW, 2.0), peakPaint);
    }

    _drawText(
      canvas,
      'SPECTRUM ANALYZER ($numBands-BAND)',
      const Offset(8, 6),
      TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: accentColor,
      ),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GameCanvasPainter oldDelegate) => true;
}

/// Subtle CRT scanline overlay effect for retro gaming aesthetics.
class _ScanlineOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlineOverlayPainter oldDelegate) => false;
}
