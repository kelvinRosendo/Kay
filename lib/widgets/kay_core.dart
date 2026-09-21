import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kay_state.dart';

class KayCore extends StatefulWidget {
  const KayCore({super.key, required this.state, required this.onTap});
  final KayState state;
  final VoidCallback onTap;
  @override
  State<KayCore> createState() => _KayCoreState();
}

class _KayCoreState extends State<KayCore> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this);
  bool _reduceMotion = false;
  void _configure() {
    _animation.stop();
    _animation.duration = Duration(
      milliseconds: switch (widget.state) {
        KayState.idle => 3600,
        KayState.listening => 1500,
        KayState.thinking => 2800,
        KayState.speaking => 1000,
      },
    );
    if (!_reduceMotion) _animation.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _configure();
  }

  @override
  void didUpdateWidget(KayCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _configure();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final size = math.min(
        320.0,
        math.min(bounds.maxWidth, bounds.maxHeight) * .72,
      );
      final color = switch (widget.state) {
        KayState.idle => const Color(0xFFDCE6EB),
        KayState.listening => const Color(0xFF87E6F7),
        KayState.thinking => const Color(0xFFB6A3F5),
        KayState.speaking => const Color(0xFFA1F0D2),
      };
      return Semantics(
        label: 'Kay',
        value: widget.state.label,
        button: true,
        hint: 'Toque para falar ou interromper',
        child: SizedBox.square(
          dimension: size,
          child: TextButton(
            onPressed: widget.onTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: color,
              shape: const CircleBorder(),
            ),
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final phase = _animation.value * math.pi * 2;
                  final breath = (1 - math.cos(phase)) / 2;
                  final pulse = widget.state == KayState.speaking
                      ? .65 * breath + .35 * math.pow(math.sin(phase * 2), 2)
                      : breath;
                  final amplitude = switch (widget.state) {
                    KayState.idle => .045,
                    KayState.listening => .09,
                    KayState.thinking => .025,
                    KayState.speaking => .11,
                  };
                  return Transform.rotate(
                    angle: !_reduceMotion && widget.state == KayState.thinking
                        ? math.sin(phase) * .035
                        : 0,
                    child: Transform.scale(
                      scale: _reduceMotion ? 1 : 1 + amplitude * pulse,
                      child: Text(
                        'K',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: size * .64,
                          height: 1,
                          fontWeight: FontWeight.w300,
                          color: color,
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: .16),
                              blurRadius: _reduceMotion ? 20 : 16 + 20 * pulse,
                            ),
                          ],
                        ),
                      ),
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
