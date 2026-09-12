import 'package:dartchess/dartchess.dart';

import '../../engine/difficulty.dart';
import 'clock.dart';

enum GameMode { vsComputer, passAndPlay, analysis }

/// One completed ply, kept for the move list and PGN export.
class MoveRecord {
  const MoveRecord({required this.san, required this.move, required this.side});

  final String san;
  final Move move;
  final Side side;
}

/// The whole state of an in-progress or finished game. Immutable — the
/// controller replaces it wholesale on every move.
class GameState {
  const GameState({
    required this.position,
    required this.mode,
    required this.history,
    this.humanSide = Side.white,
    this.difficulty,
    this.timeControl,
    this.clock,
    this.isEngineThinking = false,
    this.lastMove,
  });

  factory GameState.newGame({
    required GameMode mode,
    Side humanSide = Side.white,
    Difficulty? difficulty,
    TimeControl? timeControl,
  }) {
    return GameState(
      position: Chess.initial,
      mode: mode,
      history: const [],
      humanSide: humanSide,
      difficulty: difficulty,
      timeControl: timeControl,
      clock: timeControl == null ? null : ClockState.fromTimeControl(timeControl),
    );
  }

  final Position position;
  final GameMode mode;
  final List<MoveRecord> history;
  final Side humanSide;
  final Difficulty? difficulty;
  final TimeControl? timeControl;
  final ClockState? clock;
  final bool isEngineThinking;
  final Move? lastMove;

  Side get sideToMove => position.turn;

  bool get isGameOver => position.isGameOver || (clock?.whiteFlagged ?? false) || (clock?.blackFlagged ?? false);

  String? get resultDescription {
    if (clock?.whiteFlagged ?? false) return 'Black wins on time';
    if (clock?.blackFlagged ?? false) return 'White wins on time';
    if (!position.isGameOver) return null;
    final outcome = position.outcome;
    if (outcome == null) return null;
    if (outcome.winner == Side.white) return 'White wins by checkmate';
    if (outcome.winner == Side.black) return 'Black wins by checkmate';
    if (position.isStalemate) return 'Draw by stalemate';
    if (position.isInsufficientMaterial) return 'Draw by insufficient material';
    return 'Draw';
  }

  bool get isHumanTurn => mode == GameMode.passAndPlay || sideToMove == humanSide;

  GameState copyWith({
    Position? position,
    List<MoveRecord>? history,
    ClockState? clock,
    bool? isEngineThinking,
    Move? lastMove,
  }) {
    return GameState(
      position: position ?? this.position,
      mode: mode,
      history: history ?? this.history,
      humanSide: humanSide,
      difficulty: difficulty,
      timeControl: timeControl,
      clock: clock ?? this.clock,
      isEngineThinking: isEngineThinking ?? this.isEngineThinking,
      lastMove: lastMove ?? this.lastMove,
    );
  }
}
