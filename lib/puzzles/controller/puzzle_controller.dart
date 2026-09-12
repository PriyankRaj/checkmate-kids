import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/game_feedback.dart';
import '../../profile/controller/progress_controller.dart';
import '../data/puzzle_repository.dart';
import '../model/puzzle.dart';

enum PuzzleStatus {
  /// The opponent's first move (`moves[0]`) hasn't been auto-played yet.
  starting,

  /// Auto-playing an opponent move; the board should reject input.
  opponentMoving,

  /// Waiting for the solver to play the next move in [PuzzleAttemptState.puzzle].
  awaitingPlayerMove,

  /// The solver's last attempt didn't match the expected move.
  wrongMove,

  /// All moves have been played correctly.
  solved,
}

/// One puzzle-solving attempt: the live [Position], where we are in
/// [Puzzle.moves], and what the UI should show. See `puzzle_controller.dart`
/// header docs on the auto-play-opponent-move-first flow.
class PuzzleAttemptState {
  const PuzzleAttemptState({
    required this.puzzle,
    required this.position,
    required this.nextMoveIndex,
    required this.status,
    this.lastMove,
    this.hintSquare,
  });

  final Puzzle puzzle;
  final Position position;

  /// Index into [Puzzle.moves] of the move that should be played next
  /// (by either side — opponent moves and player moves share the index).
  final int nextMoveIndex;

  final PuzzleStatus status;
  final Move? lastMove;
  final Square? hintSquare;

  /// The side the solver is playing. `moves[0]` is always the opponent's
  /// move played from [puzzle]'s FEN, so the solver plays the side that is
  /// *not* to move in that starting position.
  Side get solverSide {
    final startingTurn = Chess.fromSetup(Setup.parseFen(puzzle.fen)).turn;
    return startingTurn == Side.white ? Side.black : Side.white;
  }

  bool get isSolved => status == PuzzleStatus.solved;
  bool get isInteractive => status == PuzzleStatus.awaitingPlayerMove || status == PuzzleStatus.wrongMove;

  PuzzleAttemptState copyWith({
    Position? position,
    int? nextMoveIndex,
    PuzzleStatus? status,
    Move? lastMove,
    Square? hintSquare,
    bool clearHint = false,
  }) {
    return PuzzleAttemptState(
      puzzle: puzzle,
      position: position ?? this.position,
      nextMoveIndex: nextMoveIndex ?? this.nextMoveIndex,
      status: status ?? this.status,
      lastMove: lastMove ?? this.lastMove,
      hintSquare: clearHint ? null : (hintSquare ?? this.hintSquare),
    );
  }
}

/// Drives a single puzzle attempt, keyed by puzzle id. Requires
/// [puzzleRepositoryProvider] to have already resolved — the view is
/// responsible for handling that provider's loading/error states before
/// mounting a widget that reads this one.
class PuzzleController extends Notifier<PuzzleAttemptState> {
  PuzzleController(this.puzzleId);

  final String puzzleId;

  @override
  PuzzleAttemptState build() {
    final repo = ref.watch(puzzleRepositoryProvider).requireValue;
    final puzzle = repo.byId(puzzleId);
    if (puzzle == null) {
      throw StateError('Puzzle not found: $puzzleId');
    }
    return PuzzleAttemptState(
      puzzle: puzzle,
      position: Chess.fromSetup(Setup.parseFen(puzzle.fen)),
      nextMoveIndex: 0,
      status: PuzzleStatus.starting,
    );
  }

  /// Plays `moves[0]` (the opponent's move) after a short delay so it's
  /// visible to the player. Safe to call once per attempt; the screen calls
  /// this from `initState`.
  Future<void> playOpponentFirstMove() async {
    if (state.status != PuzzleStatus.starting) return;
    state = state.copyWith(status: PuzzleStatus.opponentMoving);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!ref.mounted) return;
    _applyMoveAtCurrentIndex(nextStatus: PuzzleStatus.awaitingPlayerMove);
  }

  void _applyMoveAtCurrentIndex({required PuzzleStatus nextStatus}) {
    final uci = state.puzzle.moves[state.nextMoveIndex];
    final move = NormalMove.fromUci(uci);
    final newPosition = state.position.play(move);
    final newIndex = state.nextMoveIndex + 1;
    final done = newIndex >= state.puzzle.moves.length;
    state = state.copyWith(
      position: newPosition,
      nextMoveIndex: newIndex,
      lastMove: move,
      status: done ? PuzzleStatus.solved : nextStatus,
      clearHint: true,
    );
  }

  /// Validates [move] against the expected next move. Rejects (doesn't
  /// apply) mismatches. On a correct move, auto-plays the opponent's reply
  /// (if any remain) after a short delay, or marks the puzzle solved.
  Future<void> attemptMove(Move move) async {
    if (!state.isInteractive) return;
    final expectedUci = state.puzzle.moves[state.nextMoveIndex];
    if (move.uci != expectedUci) {
      state = state.copyWith(status: PuzzleStatus.wrongMove, clearHint: true);
      ref.read(gameFeedbackProvider).wrongMove();
      return;
    }

    final newPosition = state.position.play(move);
    final newIndex = state.nextMoveIndex + 1;
    final solved = newIndex >= state.puzzle.moves.length;
    state = state.copyWith(
      position: newPosition,
      nextMoveIndex: newIndex,
      lastMove: move,
      status: solved ? PuzzleStatus.solved : PuzzleStatus.opponentMoving,
      clearHint: true,
    );

    if (solved) {
      ref.read(gameFeedbackProvider).win();
      _awardProgress();
      return;
    }
    ref.read(gameFeedbackProvider).success();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!ref.mounted) return;
    _applyMoveAtCurrentIndex(nextStatus: PuzzleStatus.awaitingPlayerMove);
  }

  void _awardProgress() {
    final progress = ref.read(progressControllerProvider);
    final delta = _ratingDelta(puzzleRating: state.puzzle.rating, playerRating: progress.puzzleRating);
    ref.read(progressControllerProvider.notifier).markPuzzleSolved(
          state.puzzle.id,
          puzzleRatingDelta: delta,
        );
  }

  /// Small Elo-flavored heuristic: solving something at or above your
  /// current rating earns a few points (more for a bigger gap); solving
  /// something well below barely moves the needle (and can dip slightly).
  static int _ratingDelta({required int puzzleRating, required int playerRating}) {
    final diff = puzzleRating - playerRating;
    if (diff >= 0) return (6 + diff / 80).clamp(6, 25).round();
    return (diff / 150).clamp(-8, 0).round();
  }

  /// Highlights the origin square of the expected move, for a hint
  /// affordance. No-op if not currently awaiting a player move.
  void showHint() {
    if (!state.isInteractive) return;
    final expected = NormalMove.fromUci(state.puzzle.moves[state.nextMoveIndex]);
    state = state.copyWith(hintSquare: expected.from);
  }

  /// Plays out the rest of the solution automatically. Does not award
  /// puzzle-rating progress, since the solver didn't find it themselves.
  Future<void> showSolution() async {
    while (state.status != PuzzleStatus.solved) {
      if (!state.isInteractive && state.status != PuzzleStatus.wrongMove) {
        // Currently mid opponent-move animation; wait for it to settle.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!ref.mounted) return;
        continue;
      }
      final uci = state.puzzle.moves[state.nextMoveIndex];
      final move = NormalMove.fromUci(uci);
      final newPosition = state.position.play(move);
      final newIndex = state.nextMoveIndex + 1;
      final done = newIndex >= state.puzzle.moves.length;
      state = state.copyWith(
        position: newPosition,
        nextMoveIndex: newIndex,
        lastMove: move,
        status: done ? PuzzleStatus.solved : PuzzleStatus.opponentMoving,
        clearHint: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!ref.mounted) return;
    }
  }
}

final puzzleControllerProvider =
    NotifierProvider.family<PuzzleController, PuzzleAttemptState, String>(
  PuzzleController.new,
);
