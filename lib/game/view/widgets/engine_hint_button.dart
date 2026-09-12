import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/engine_provider.dart';

/// A "Hint" button that asks [EngineService.suggestMoveUci] for the current
/// [position] and reports the result as a [NormalMove] via [onSuggestion] —
/// callers render it as an on-board `Arrow` shape (same visual language as
/// puzzles' hint `Circle`) rather than plain text.
///
/// One instance per screen; shared across game/challenges/analysis so the
/// "ask engine, show spinner, disable while thinking" logic isn't
/// duplicated three times.
class EngineHintButton extends ConsumerStatefulWidget {
  const EngineHintButton({
    super.key,
    required this.fen,
    required this.position,
    required this.onSuggestion,
    this.enabled = true,
  });

  final String fen;
  final Position position;
  final bool enabled;
  final ValueChanged<NormalMove?> onSuggestion;

  @override
  ConsumerState<EngineHintButton> createState() => _EngineHintButtonState();
}

class _EngineHintButtonState extends ConsumerState<EngineHintButton> {
  bool _loading = false;

  Future<void> _requestHint() async {
    setState(() => _loading = true);
    final engine = ref.read(engineServiceProvider);
    final uci = await engine.suggestMoveUci(fen: widget.fen, position: widget.position);
    if (!mounted) return;
    setState(() => _loading = false);
    final move = uci == null ? null : Move.parse(uci);
    widget.onSuggestion(move is NormalMove ? move : null);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: widget.enabled && !_loading ? _requestHint : null,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lightbulb_outline),
      label: Text(_loading ? 'Thinking…' : 'Hint'),
    );
  }
}

/// Builds the amber hint arrow shape from a suggested [move], or an empty
/// set if there is none — pass straight into `Chessboard(shapes: ...)`.
Set<Shape> hintArrowShapes(NormalMove? move) {
  if (move == null) return const {};
  return {Arrow(color: Colors.amber.withValues(alpha: 0.85), orig: move.from, dest: move.to)};
}
