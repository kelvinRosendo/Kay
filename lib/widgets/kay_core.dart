import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kay_state.dart';

/// Visual core of Kay.
///
/// The public API intentionally stays tiny: the controller only needs to pass
/// the current [KayState] and a tap callback. The particle system can later be
/// driven by real microphone amplitude without changing the rest of the app.
class KayCore extends StatefulWidget {
  const KayCore({
    super.key,
    required this.state,
    required this.onTap,
  });

  final KayState state;
  final VoidCallback onTap;

  @override
  State<KayCore> createState() => _KayCoreState();
}

class _KayCoreState extends State<KayCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation =
      AnimationController(vsync: this);

  bool _reduceMotion = false;

  void _configureAnimation() {
    _animation
      ..stop()
      ..duration = Duration(
        milliseconds: switch (widget.state) {
          KayState.idle => 4200,
          KayState.listening => 1900,
          KayState.thinking => 2600,
          KayState.speaking => 1250,
        },
      );

    if (!_reduceMotion) {
      _animation.repeat();
    } else {
      _animation.value = .18;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant KayCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _configureAnimation();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final dimension = math.min(
          360.0,
          math.min(bounds.maxWidth, bounds.maxHeight) * .86,
        );

        return Semantics(
          label: 'Kay',
          value: widget.state.label,
          button: true,
          hint: 'Toque para falar ou interromper',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: SizedBox.square(
              dimension: dimension,
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _KayParticlePainter(
                        state: widget.state,
                        progress: _animation.value,
                        reduceMotion: _reduceMotion,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KayParticlePainter extends CustomPainter {
  const _KayParticlePainter({
    required this.state,
    required this.progress,
    required this.reduceMotion,
  });

  static const int _particleCount = 112;

  final KayState state;
  final double progress;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortSide = math.min(size.width, size.height);
    final phase = progress * math.pi * 2;
    final stateColor = _colorFor(state);

    // Very subtle aura behind the particles. It keeps the core readable on
    // OLED-dark backgrounds without turning it into a glowing blob.
    final auraRadius = shortSide * (.24 + .015 * math.sin(phase));
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          stateColor.withValues(alpha: .12),
          stateColor.withValues(alpha: .025),
          Colors.transparent,
        ],
        stops: const [0, .48, 1],
      ).createShader(
        Rect.fromCircle(center: center, radius: auraRadius * 1.8),
      );

    canvas.drawCircle(center, auraRadius * 1.8, auraPaint);

    for (var i = 0; i < _particleCount; i++) {
      final seed = _hash(i);
      final secondarySeed = _hash(i + 701);
      final k = _kTarget(i, _particleCount);
      final cloud = _cloudTarget(
        i,
        seed,
        secondarySeed,
        phase,
        state,
      );

      final blend = switch (state) {
        KayState.idle => .04,
        KayState.listening => .78,
        KayState.thinking => .93,
        KayState.speaking => .68,
      };

      final transitionWave =
          .5 + .5 * math.sin(phase + i * .105 + seed * math.pi);
      final dynamicBlend = reduceMotion
          ? blend
          : (blend + transitionWave * .035).clamp(0.0, 1.0);

      var nx = _mix(k.dx, cloud.dx, dynamicBlend);
      var ny = _mix(k.dy, cloud.dy, dynamicBlend);

      // A tiny breathing motion keeps the idle K from feeling like static text.
      if (!reduceMotion && state == KayState.idle) {
        final breath = 1 + .018 * math.sin(phase);
        nx *= breath;
        ny *= breath;
      }

      // Speaking gets an intentionally asymmetric pulse so it feels closer to
      // a voice waveform than to a loading spinner.
      if (!reduceMotion && state == KayState.speaking) {
        final voice =
            .035 +
            .055 *
                math.pow(
                  math.sin(phase * 2.4 + seed * 8 + i * .07),
                  2,
                );
        nx *= 1 + voice;
        ny *= 1 + voice * .72;
      }

      final position = Offset(
        center.dx + nx * shortSide,
        center.dy + ny * shortSide,
      );

      final twinkle = reduceMotion
          ? .5
          : .5 + .5 * math.sin(phase * 1.35 + i * .61);
      final radius =
          shortSide *
          (.0042 + seed * .0031) *
          (state == KayState.listening ? 1.08 : 1) *
          (state == KayState.speaking ? .95 + twinkle * .35 : 1);

      final alpha =
          (.52 + secondarySeed * .35 + twinkle * .1).clamp(0.0, 1.0);

      final glowPaint = Paint()
        ..color = stateColor.withValues(alpha: alpha * .18)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          radius * (2.4 + twinkle),
        );
      canvas.drawCircle(position, radius * 2.15, glowPaint);

      final particlePaint = Paint()
        ..color = Color.lerp(
          stateColor,
          Colors.white,
          .08 + secondarySeed * .18,
        )!.withValues(alpha: alpha);

      canvas.drawCircle(position, radius, particlePaint);
    }

    _drawCenterPulse(canvas, center, shortSide, stateColor, phase);
  }

  void _drawCenterPulse(
    Canvas canvas,
    Offset center,
    double shortSide,
    Color color,
    double phase,
  ) {
    if (state == KayState.idle) return;

    final base = switch (state) {
      KayState.listening => .072,
      KayState.thinking => .05,
      KayState.speaking => .06,
      KayState.idle => 0.0,
    };

    final pulse = reduceMotion
        ? .5
        : .5 + .5 * math.sin(phase * (state == KayState.speaking ? 2 : 1));

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: .08 + .11 * pulse);

    canvas.drawCircle(
      center,
      shortSide * (base + pulse * .018),
      ringPaint,
    );
  }

  Offset _cloudTarget(
    int index,
    double seed,
    double secondarySeed,
    double phase,
    KayState state,
  ) {
    final angleSeed = seed * math.pi * 2;

    switch (state) {
      case KayState.idle:
        return Offset(
          (seed - .5) * .055 + math.sin(phase + index) * .006,
          (secondarySeed - .5) * .055 + math.cos(phase + index) * .006,
        );

      case KayState.listening:
        final radius = .11 + secondarySeed * .25;
        final drift = reduceMotion ? 0 : math.sin(phase + index * .43) * .028;
        return Offset(
          math.cos(angleSeed + phase * .17) * (radius + drift),
          math.sin(angleSeed + phase * .12) * (radius * .82 + drift),
        );

      case KayState.thinking:
        final ring = .17 + (index % 4) * .041;
        final direction = index.isEven ? 1.0 : -1.0;
        final angle = angleSeed + phase * direction * (.72 + seed * .42);
        return Offset(
          math.cos(angle) * ring,
          math.sin(angle) * ring * .78,
        );

      case KayState.speaking:
        final radius = .09 + secondarySeed * .22;
        final wave = reduceMotion
            ? 0
            : math.sin(phase * 2.3 + index * .33) * (.025 + seed * .05);
        return Offset(
          math.cos(angleSeed) * (radius + wave),
          math.sin(angleSeed) * (radius * .64 + wave * .6),
        );
    }
  }

  /// Normalized point in a stylised K.
  ///
  /// The points are distributed across a vertical spine and two diagonals.
  /// Slight deterministic jitter prevents the mark from looking like a
  /// computer font when the particles settle.
  Offset _kTarget(int index, int total) {
    final spineCount = (total * .42).round();
    final upperCount = ((total - spineCount) / 2).round();

    double x;
    double y;

    if (index < spineCount) {
      final t = index / math.max(1, spineCount - 1);
      x = -.17;
      y = -.31 + t * .62;
    } else if (index < spineCount + upperCount) {
      final local = index - spineCount;
      final t = local / math.max(1, upperCount - 1);
      x = -.15 + t * .34;
      y = -.015 - t * .295;
    } else {
      final local = index - spineCount - upperCount;
      final count = total - spineCount - upperCount;
      final t = local / math.max(1, count - 1);
      x = -.15 + t * .35;
      y = .012 + t * .30;
    }

    final jitterX = (_hash(index + 1201) - .5) * .018;
    final jitterY = (_hash(index + 1907) - .5) * .018;

    return Offset(x + jitterX, y + jitterY);
  }

  static Color _colorFor(KayState state) => switch (state) {
    KayState.idle => const Color(0xFFBDEBFF),
    KayState.listening => const Color(0xFF32D7FF),
    KayState.thinking => const Color(0xFF9D7BFF),
    KayState.speaking => const Color(0xFF5CFFCB),
  };

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  static double _hash(int value) {
    final x = math.sin(value * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _KayParticlePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.progress != progress ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
