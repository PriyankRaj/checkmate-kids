import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// Wraps [child] (typically a board) and, when [trigger] flips from false to
/// true, layers a non-blocking confetti burst on top of it. The burst never
/// intercepts touches — [IgnorePointer] keeps the board underneath fully
/// interactive — and the final board position stays visible the whole time,
/// unlike a modal dialog or a full-screen result replacement.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.trigger, required this.child});

  final bool trigger;
  final Widget child;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late final ConfettiController _controller =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.play();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.trigger) _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        widget.child,
        IgnorePointer(
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            maxBlastForce: 18,
            minBlastForce: 6,
            gravity: 0.25,
            emissionFrequency: 0.03,
            colors: const [
              Colors.amber,
              Colors.pinkAccent,
              Colors.lightBlueAccent,
              Colors.greenAccent,
              Colors.deepOrangeAccent,
            ],
          ),
        ),
      ],
    );
  }
}

/// A small scale-in "badge" for lighter celebrations (a solved puzzle, a
/// correct lesson step) where a full confetti burst would be too much.
class PopBadge extends StatefulWidget {
  const PopBadge({super.key, required this.trigger, required this.child});

  final bool trigger;
  final Widget child;

  @override
  State<PopBadge> createState() => _PopBadgeState();
}

class _PopBadgeState extends State<PopBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void didUpdateWidget(PopBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.trigger) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// A subtle "shake" for wrong answers — used instead of nothing so an
/// incorrect move/tap reads as a deliberate response, not a no-op.
class ShakeOnTrigger extends StatefulWidget {
  const ShakeOnTrigger({super.key, required this.trigger, required this.child});

  final bool trigger;
  final Widget child;

  @override
  State<ShakeOnTrigger> createState() => _ShakeOnTriggerState();
}

class _ShakeOnTriggerState extends State<ShakeOnTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void didUpdateWidget(ShakeOnTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = sin(_controller.value * pi * 6) * 6 * (1 - _controller.value);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}
