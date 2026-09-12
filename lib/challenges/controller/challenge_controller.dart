import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/game_feedback.dart';
import '../../engine/difficulty.dart';
import '../../engine/engine_provider.dart';
import '../../profile/controller/progress_controller.dart';
import '../data/challenge_repository.dart';
import '../model/challenge.dart';

enum ChallengePhase { idle, running, success, failure }

/// State for whichever [Challenge] the screen is currently showing. Only the
/// fields relevant to `challenge.type` are ever non-null/non-default — see
/// the doc comment on each field.
class ChallengeState {
  const ChallengeState({
    required this.challenge,
    this.phase = ChallengePhase.idle,
    this.score = 0,
    this.isNewBest = false,
    this.secondsRemaining,
    this.movesRemaining,
    this.position,
    this.lastMove,
    this.isEngineThinking = false,
    this.message,
    this.targetSquareName,
    this.lastTappedSquareName,
    this.lastTapWasCorrect,
    this.sequence = const [],
    this.revealIndex = 0,
    this.recallInput = const [],
    this.showBoard = true,
  });

  final Challenge challenge;
  final ChallengePhase phase;

  /// The running score. Meaning depends on `challenge.scoreLabel`.
  final int score;

  /// Set once, when the run ends, if [score] beat the previous best.
  final bool isNewBest;

  /// mateInOneBlitz, coordinateRush.
  final int? secondsRemaining;

  /// knightHunt, pawnRace, endgameBoss.
  final int? movesRemaining;

  /// mateInOneBlitz, knightHunt, pawnRace, survive, endgameBoss.
  final Position? position;
  final Move? lastMove;
  final bool isEngineThinking;

  /// Short status line shown under the board/controls.
  final String? message;

  /// coordinateRush.
  final String? targetSquareName;
  final String? lastTappedSquareName;
  final bool? lastTapWasCorrect;

  /// blindfoldSteps: the full move sequence for this round, in UCI.
  final List<String> sequence;

  /// blindfoldSteps: how many moves of [sequence] have been shown so far
  /// during playback.
  final int revealIndex;

  /// blindfoldSteps: square names tapped so far during recall.
  final List<String> recallInput;

  /// blindfoldSteps: false while the board is hidden for recall.
  final bool showBoard;

  ChallengeState copyWith({
    ChallengePhase? phase,
    int? score,
    bool? isNewBest,
    Object? secondsRemaining = _sentinel,
    Object? movesRemaining = _sentinel,
    Object? position = _sentinel,
    Object? lastMove = _sentinel,
    bool? isEngineThinking,
    Object? message = _sentinel,
    Object? targetSquareName = _sentinel,
    Object? lastTappedSquareName = _sentinel,
    Object? lastTapWasCorrect = _sentinel,
    List<String>? sequence,
    int? revealIndex,
    List<String>? recallInput,
    bool? showBoard,
  }) {
    return ChallengeState(
      challenge: challenge,
      phase: phase ?? this.phase,
      score: score ?? this.score,
      isNewBest: isNewBest ?? this.isNewBest,
      secondsRemaining:
          secondsRemaining == _sentinel ? this.secondsRemaining : secondsRemaining as int?,
      movesRemaining: movesRemaining == _sentinel ? this.movesRemaining : movesRemaining as int?,
      position: position == _sentinel ? this.position : position as Position?,
      lastMove: lastMove == _sentinel ? this.lastMove : lastMove as Move?,
      isEngineThinking: isEngineThinking ?? this.isEngineThinking,
      message: message == _sentinel ? this.message : message as String?,
      targetSquareName:
          targetSquareName == _sentinel ? this.targetSquareName : targetSquareName as String?,
      lastTappedSquareName: lastTappedSquareName == _sentinel
          ? this.lastTappedSquareName
          : lastTappedSquareName as String?,
      lastTapWasCorrect:
          lastTapWasCorrect == _sentinel ? this.lastTapWasCorrect : lastTapWasCorrect as bool?,
      sequence: sequence ?? this.sequence,
      revealIndex: revealIndex ?? this.revealIndex,
      recallInput: recallInput ?? this.recallInput,
      showBoard: showBoard ?? this.showBoard,
    );
  }
}

const _sentinel = Object();

/// Drives one challenge run: timer/move-budget bookkeeping, goal checks, and
/// recording the result via [ProgressController.recordChallengeScore].
///
/// One controller instance per challenge id (via the `.family` provider), so
/// switching challenges from the list screen never leaks timers between
/// runs. Riverpod 3 recreates the [Notifier] on rebuild, so the countdown/
/// engine-move timers are always torn down via [Ref.onDispose].
class ChallengeController extends Notifier<ChallengeState> {
  ChallengeController(this.challengeId);

  final String challengeId;

  Timer? _timer;
  final Random _random = Random();

  @override
  ChallengeState build() {
    final challenge = ref.watch(challengeByIdProvider(challengeId));
    if (challenge == null) {
      throw ArgumentError('Unknown challenge id: $challengeId');
    }
    ref.onDispose(() => _timer?.cancel());
    return ChallengeState(challenge: challenge);
  }

  // --- Shared lifecycle -----------------------------------------------

  void start() {
    _timer?.cancel();
    final challenge = state.challenge;
    state = ChallengeState(challenge: challenge, phase: ChallengePhase.running);
    switch (challenge.type) {
      case ChallengeType.mateInOneBlitz:
        _startMateInOneBlitz();
      case ChallengeType.coordinateRush:
        _startCoordinateRush();
      case ChallengeType.knightHunt:
      case ChallengeType.pawnRace:
        _startFixedPositionDrill();
      case ChallengeType.survive:
        _startSurvive();
      case ChallengeType.endgameBoss:
        _startEndgameBoss();
      case ChallengeType.blindfoldSteps:
        _startBlindfoldSteps();
    }
  }

  void retry() => start();

  void _finish({required bool success, int? scoreOverride}) {
    _timer?.cancel();
    final score = scoreOverride ?? state.score;
    bool isNewBest = false;
    final alwaysRecordsScore =
        state.challenge.type == ChallengeType.survive || state.challenge.type == ChallengeType.blindfoldSteps;
    if (success || alwaysRecordsScore) {
      final notifier = ref.read(progressControllerProvider.notifier);
      final previousBest = ref.read(progressControllerProvider).challengeBestScores[state.challenge.id];
      notifier.recordChallengeScore(state.challenge.id, score, higherIsBetter: state.challenge.higherIsBetter);
      final higherIsBetter = state.challenge.higherIsBetter;
      isNewBest = previousBest == null || (higherIsBetter ? score > previousBest : score < previousBest);
    }
    state = state.copyWith(
      phase: success ? ChallengePhase.success : ChallengePhase.failure,
      score: score,
      isNewBest: isNewBest,
    );
    success ? ref.read(gameFeedbackProvider).win() : ref.read(gameFeedbackProvider).lose();
  }

  void _startCountdown(int seconds, void Function() onExpire) {
    state = state.copyWith(secondsRemaining: seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = (state.secondsRemaining ?? 1) - 1;
      if (remaining <= 0) {
        _timer?.cancel();
        state = state.copyWith(secondsRemaining: 0);
        onExpire();
      } else {
        state = state.copyWith(secondsRemaining: remaining);
      }
    });
  }

  // --- Mate in One Blitz -------------------------------------------------

  void _startMateInOneBlitz() {
    _loadRandomMatePosition();
    _startCountdown(state.challenge.timeLimitSeconds!, () => _finish(success: true));
  }

  void _loadRandomMatePosition() {
    final pool = state.challenge.fenPool;
    final fen = pool[_random.nextInt(pool.length)];
    final position = Chess.fromSetup(Setup.parseFen(fen));
    state = state.copyWith(position: position, lastMove: null, message: 'Find checkmate in one!');
  }

  /// Called by the screen when the player attempts [move] on the current
  /// mate-in-one position. Any legal move that delivers checkmate counts —
  /// there's no single stored "solution".
  void submitMateInOneMove(Move move) {
    final position = state.position;
    if (position == null || state.phase != ChallengePhase.running) return;
    if (!position.isLegal(move)) return;
    final played = position.play(move);
    if (played.isCheckmate) {
      state = state.copyWith(score: state.score + 1, position: played, lastMove: move, message: 'Checkmate!');
      ref.read(gameFeedbackProvider).success();
      Timer(const Duration(milliseconds: 500), () {
        if (state.phase == ChallengePhase.running) _loadRandomMatePosition();
      });
    } else {
      state = state.copyWith(message: "Not mate — try again!");
      ref.read(gameFeedbackProvider).wrongMove();
    }
  }

  // --- Coordinate Rush ----------------------------------------------------

  void _startCoordinateRush() {
    _pickNewTarget();
    _startCountdown(state.challenge.timeLimitSeconds!, () => _finish(success: true));
  }

  void _pickNewTarget() {
    final next = Square.values[_random.nextInt(64)].name;
    state = state.copyWith(
      targetSquareName: next,
      lastTappedSquareName: null,
      lastTapWasCorrect: null,
    );
  }

  void tapCoordinateSquare(String squareName) {
    if (state.phase != ChallengePhase.running) return;
    final correct = squareName == state.targetSquareName;
    state = state.copyWith(
      score: correct ? state.score + 1 : state.score,
      lastTappedSquareName: squareName,
      lastTapWasCorrect: correct,
    );
    correct ? ref.read(gameFeedbackProvider).success() : ref.read(gameFeedbackProvider).wrongMove();
    _pickNewTarget();
  }

  // --- Knight Hunt / Pawn Race (fixed position, move-budget, no opponent) -

  void _startFixedPositionDrill() {
    final challenge = state.challenge;
    final position = Chess.fromSetup(Setup.parseFen(challenge.startFen!));
    state = state.copyWith(
      position: position,
      movesRemaining: challenge.moveBudget,
      lastMove: null,
      message: challenge.goal,
    );
  }

  /// Forces [position] back to White to move. Knight Hunt and Pawn Race are
  /// single-side drills — there's no opponent turn to play — so after each
  /// move we simply hand the turn back to White rather than modelling a
  /// (nonexistent) Black reply. `ignoreImpossibleCheck` guards against the
  /// otherwise-illegal "side not to move is in check" validation, which
  /// doesn't apply here since Black never actually moves.
  Position _handBackToWhite(Position position) {
    final fields = position.fen.split(' ');
    fields[1] = 'w';
    return Chess.fromSetup(Setup.parseFen(fields.join(' ')), ignoreImpossibleCheck: true);
  }

  void playKnightHuntMove(Move move) {
    final position = state.position;
    if (position == null || state.phase != ChallengePhase.running) return;
    if (!position.isLegal(move)) return;
    var played = position.play(move);
    played = _handBackToWhite(played);
    final movesRemaining = (state.movesRemaining ?? 1) - 1;
    final pawnsLeft = played.board.piecesOf(Side.black, Role.pawn).isNotEmpty;
    state = state.copyWith(position: played, lastMove: move, movesRemaining: movesRemaining);
    if (!pawnsLeft) {
      _finish(success: true, scoreOverride: movesRemaining);
    } else if (movesRemaining <= 0) {
      _finish(success: false, scoreOverride: 0);
    }
  }

  void playPawnRaceMove(Move move) {
    final position = state.position;
    if (position == null || state.phase != ChallengePhase.running) return;
    if (!position.isLegal(move)) return;
    final movesTaken = (state.challenge.moveBudget! - (state.movesRemaining ?? 1)) + 1;
    final promoted = move is NormalMove && move.promotion != null;
    var played = position.play(move);
    if (!promoted) played = _handBackToWhite(played);
    final movesRemaining = (state.movesRemaining ?? 1) - 1;
    state = state.copyWith(position: played, lastMove: move, movesRemaining: movesRemaining);
    if (promoted) {
      _finish(success: true, scoreOverride: movesTaken);
    } else if (movesRemaining <= 0) {
      _finish(success: false, scoreOverride: 0);
    }
  }

  // --- Survive --------------------------------------------------------

  void _startSurvive() {
    final challenge = state.challenge;
    final position = Chess.fromSetup(Setup.parseFen(challenge.startFen!));
    state = state.copyWith(position: position, movesRemaining: 0, lastMove: null, message: challenge.goal);
  }

  Future<void> playSurviveMove(Move move) async {
    final position = state.position;
    if (position == null || state.phase != ChallengePhase.running || state.isEngineThinking) return;
    if (position.turn != Side.white) return;
    if (!position.isLegal(move)) return;
    var played = position.play(move);
    final movesSurvived = (state.movesRemaining ?? 0) + 1;
    state = state.copyWith(position: played, lastMove: move, movesRemaining: movesSurvived);
    if (played.isGameOver) {
      _finish(success: !played.isCheckmate, scoreOverride: movesSurvived);
      return;
    }
    await _playEngineReply(difficulty: state.challenge.difficulty!, onApplied: (afterEngine, engineMove) {
      state = state.copyWith(position: afterEngine, lastMove: engineMove);
      if (afterEngine.isGameOver) {
        _finish(success: !afterEngine.isCheckmate, scoreOverride: movesSurvived);
      }
    });
  }

  void resignSurvive() {
    if (state.phase != ChallengePhase.running) return;
    _finish(success: false, scoreOverride: state.movesRemaining ?? 0);
  }

  // --- Endgame Boss -----------------------------------------------------

  void _startEndgameBoss() {
    final challenge = state.challenge;
    final position = Chess.fromSetup(Setup.parseFen(challenge.startFen!));
    state = state.copyWith(
      position: position,
      movesRemaining: challenge.moveBudget,
      lastMove: null,
      message: challenge.goal,
    );
  }

  Future<void> playEndgameBossMove(Move move) async {
    final position = state.position;
    if (position == null || state.phase != ChallengePhase.running || state.isEngineThinking) return;
    if (position.turn != Side.white) return;
    if (!position.isLegal(move)) return;
    final played = position.play(move);
    final movesTaken = (state.challenge.moveBudget! - (state.movesRemaining ?? 1)) + 1;
    final movesRemaining = (state.movesRemaining ?? 1) - 1;
    state = state.copyWith(position: played, lastMove: move, movesRemaining: movesRemaining);
    if (played.isCheckmate) {
      _finish(success: true, scoreOverride: movesTaken);
      return;
    }
    if (played.isGameOver || movesRemaining <= 0) {
      _finish(success: false, scoreOverride: 0);
      return;
    }
    await _playEngineReply(difficulty: state.challenge.difficulty!, onApplied: (afterEngine, engineMove) {
      state = state.copyWith(position: afterEngine, lastMove: engineMove);
      if (afterEngine.isGameOver) {
        // The engine has no legal moves: either we already mated it above,
        // or it's stalemated, which forfeits the run.
        if (!afterEngine.isCheckmate) _finish(success: false, scoreOverride: 0);
      }
    });
  }

  Future<void> _playEngineReply({
    required Difficulty difficulty,
    required void Function(Position afterEngine, Move engineMove) onApplied,
  }) async {
    state = state.copyWith(isEngineThinking: true);
    final position = state.position!;
    final engine = ref.read(engineServiceProvider);
    final uci = await engine.bestMoveUci(fen: position.fen, position: position, difficulty: difficulty);
    state = state.copyWith(isEngineThinking: false);
    if (state.phase != ChallengePhase.running) return;
    if (uci == null) return;
    final move = Move.parse(uci);
    if (move != null && state.position!.isLegal(move)) {
      onApplied(state.position!.play(move), move);
    }
  }

  // --- Blindfold Steps ----------------------------------------------------

  void _startBlindfoldSteps() {
    _loadBlindfoldRound(state.challenge.blindfoldStartLength);
  }

  void _loadBlindfoldRound(int length) {
    final sequence = _randomMoveSequence(length);
    state = state.copyWith(
      sequence: sequence,
      revealIndex: 0,
      recallInput: const [],
      showBoard: true,
      position: Chess.initial,
      lastMove: null,
      message: 'Watch closely…',
    );
    _revealNextBlindfoldMove();
  }

  List<String> _randomMoveSequence(int length) {
    Position position = Chess.initial;
    final moves = <String>[];
    for (var i = 0; i < length; i++) {
      final legal = position.legalMoves.entries
          .expand((entry) => entry.value.squares.map((to) => NormalMove(from: entry.key, to: to)))
          .toList();
      if (legal.isEmpty) break;
      final move = legal[_random.nextInt(legal.length)];
      moves.add(move.uci);
      position = position.play(move);
    }
    return moves;
  }

  void _revealNextBlindfoldMove() {
    final index = state.revealIndex;
    if (index >= state.sequence.length) {
      // Playback done — hide the board and wait for recall taps.
      Timer(const Duration(milliseconds: 400), () {
        state = state.copyWith(showBoard: false, message: 'Now play it back from memory.');
      });
      return;
    }
    Timer(const Duration(milliseconds: 700), () {
      if (state.phase != ChallengePhase.running) return;
      final move = NormalMove.fromUci(state.sequence[index]);
      final played = state.position!.play(move);
      state = state.copyWith(position: played, lastMove: move, revealIndex: index + 1);
      _revealNextBlindfoldMove();
    });
  }

  /// Called by the screen with each square the player taps during recall.
  /// Every move in [ChallengeState.sequence] is a from/to pair, so recall
  /// input is compared two taps at a time against the flattened square list.
  void tapBlindfoldSquare(Square square) {
    if (state.phase != ChallengePhase.running || state.showBoard) return;
    final input = [...state.recallInput, square.name];
    final expected = <String>[
      for (final uci in state.sequence) ...[uci.substring(0, 2), uci.substring(2, 4)],
    ];
    final index = input.length - 1;
    if (index >= expected.length || input[index] != expected[index]) {
      state = state.copyWith(recallInput: input, message: 'Not quite — that breaks the streak.');
      ref.read(gameFeedbackProvider).wrongMove();
      _finish(success: false, scoreOverride: state.score);
      return;
    }
    state = state.copyWith(recallInput: input);
    if (input.length == expected.length) {
      final completedLength = state.sequence.length;
      state = state.copyWith(score: completedLength);
      ref.read(gameFeedbackProvider).success();
      Timer(const Duration(milliseconds: 500), () {
        if (state.phase == ChallengePhase.running) {
          state = state.copyWith(message: 'Nice! One more move next round…');
          _loadBlindfoldRound(completedLength + 1);
        }
      });
    }
  }
}

final challengeControllerProvider =
    NotifierProvider.family<ChallengeController, ChallengeState, String>(ChallengeController.new);
