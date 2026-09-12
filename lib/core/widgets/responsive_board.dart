import 'dart:math';

import 'package:flutter/material.dart';

/// Sizes [builder]'s board to the largest square that fits the available
/// space, capped at [maxSize]. `Chessboard`/`StaticChessboard` both take a
/// single `size` — this is the one place that computes it.
class ResponsiveBoard extends StatelessWidget {
  const ResponsiveBoard({super.key, required this.builder, this.maxSize = 560});

  final Widget Function(BuildContext context, double size) builder;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(
          maxSize,
          min(constraints.maxWidth, constraints.maxHeight.isFinite ? constraints.maxHeight : constraints.maxWidth),
        );
        return builder(context, size);
      },
    );
  }
}
