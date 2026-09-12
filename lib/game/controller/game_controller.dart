import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../engine/engine_provider.dart';
import '../../engine/engine_service.dart';
import '../model/clock.dart';
import '../model/game_state.dart';

/// Drives one game: applies human moves, ticks the clock, and — for
/// [GameMode.vsComputer] — asks [EngineService] for the reply.
///
/// Riverpod 3 recreates a [Notifier] whenever its provider rebuilds, so the
/// clock [Timer] is torn down in [ref.onDispose] rather than relying on a
/// widget's dispose.
class GameController extends Notifier<GameState> {
  Timer? _clockTimer;

  @override
  GameState build() {
    ref.onDispose(() => _clockTimer?.cancel());
    return GameState.newGame(mode: GameMode.passAndPlay);
  }

  void startGame({
    required GameMode mode,
    Side humanSide = Side.white,
    Difficulty? difficulty,
    TimeControl? timeControl,
  }) {
    _clockTimer?.cancel();
    state = GameState.newGame(
      mode: mode,
      humanSide: humanSide,
      difficulty: difficulty,
      timeControl: timeControl,
    );
    _startClockIfNeeded();
    _maybeTriggerEngineMove();
  }

  void _startClockIfNeeded() {
    if (state.clock == null) return;
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isGameOver) {
        _clockTimer?.cancel();
        return;
      }
      final whiteToMove = state.sideToMove == Side.white;
      state = state.copyWith(clock: state.clock!.tick(whiteToMove));
    });
  }

  /// Applies a move the player made on the board. [move] is already a fully
  /// resolved dartchess [Move] (chessground resolves promotion internally).
  void playHumanMove(Move move) {
    if (state.isGameOver || !state.isHumanTurn || state.isEngineThinking) return;
    _applyMove(move);
    _maybeTriggerEngineMove();
  }

  void _applyMove(Move move) {
    final side = state.sideToMove;
    final (nextPosition, san) = state.position.makeSan(move);
    final wasWhiteMove = side == Side.white;
    state = state.copyWith(
      position: nextPosition,
      history: [...state.history, MoveRecord(san: san, move: move, side: side)],
      lastMove: move,
      clock: state.clock?.applyIncrement(wasWhiteMove),
    );
  }

  Future<void> _maybeTriggerEngineMove() async {
    if (state.mode != GameMode.vsComputer) return;
    if (state.isGameOver) return;
    if (state.sideToMove == state.humanSide) return;

    final difficulty = state.difficulty ?? Difficulty.club;
    state = state.copyWith(isEngineThinking: true);
    final engine = ref.read(engineServiceProvider);
    final uci = await engine.bestMoveUci(
      fen: state.position.fen,
      position: state.position,
      difficulty: difficulty,
    );
    // The game may have moved on (reset, disposed) while we awaited.
    if (uci == null) {
      state = state.copyWith(isEngineThinking: false);
      return;
    }
    final move = Move.parse(uci);
    state = state.copyWith(isEngineThinking: false);
    if (move != null && state.position.isLegal(move)) {
      _applyMove(move);
    }
  }

  /// Used by the analysis board to step through an arbitrary move, ignoring
  /// turn/mode restrictions.
  void playAnyMove(Move move) {
    if (!state.position.isLegal(move)) return;
    _applyMove(move);
  }
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

/// A second, independent [GameController] instance for the free-setup
/// analysis board, so it never shares state with the main "Play" game.
final analysisControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);
