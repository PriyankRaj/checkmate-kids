import 'package:flutter/material.dart';

import '../../model/clock.dart';

class ClockView extends StatelessWidget {
  const ClockView({super.key, required this.clock, required this.whiteToMove});

  final ClockState clock;
  final bool whiteToMove;

  String _format(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Widget _pill(BuildContext context, String label, int seconds, bool active) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 8),
          Text(_format(seconds), style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _pill(context, 'Black', clock.blackRemaining, !whiteToMove),
        _pill(context, 'White', clock.whiteRemaining, whiteToMove),
      ],
    );
  }
}
