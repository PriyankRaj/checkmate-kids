import 'package:flutter/material.dart';

import '../../model/game_state.dart';

class MoveList extends StatelessWidget {
  const MoveList({super.key, required this.history});

  final List<MoveRecord> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No moves yet.'),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < history.length; i += 2) {
      final moveNumber = (i ~/ 2) + 1;
      final white = history[i].san;
      final black = i + 1 < history.length ? history[i + 1].san : '';
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text('$moveNumber.')),
            SizedBox(width: 72, child: Text(white)),
            SizedBox(width: 72, child: Text(black)),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}
