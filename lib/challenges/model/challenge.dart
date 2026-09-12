import '../../engine/difficulty.dart';

/// The kind of drill a [Challenge] represents. The controller and screen each
/// branch on this once; every other difference between challenges (starting
/// position, time limit, move budget, difficulty) lives in data on
/// [Challenge] itself, so adding challenge #8 only means adding a new
/// [Challenge] entry to `challenge_repository.dart` — never new UI code,
/// unless it truly is a new kind of interaction.
enum ChallengeType {
  /// Rotating set of hand-authored mate-in-1 positions, timed.
  mateInOneBlitz,

  /// Flash a square name, tap it on a blank board, timed.
  coordinateRush,

  /// Capture every pawn with a lone knight within a move budget.
  knightHunt,

  /// Push a lone pawn to promotion within a move budget.
  pawnRace,

  /// Survive as long as possible against the engine from a bad position.
  survive,

  /// Convert a K+R vs K endgame against the engine within a move budget.
  endgameBoss,

  /// Watch a move sequence, then replay it from memory.
  blindfoldSteps,
}

/// A single playable drill. Which fields are meaningful depends on [type] —
/// see the doc comment on each field for which challenge types read it.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.type,
    required this.higherIsBetter,
    required this.scoreLabel,
    this.scoreSuffix = '',
    this.timeLimitSeconds,
    this.moveBudget,
    this.startFen,
    this.fenPool = const [],
    this.difficulty,
    this.blindfoldStartLength = 2,
  });

  final String id;
  final String title;
  final String description;

  /// Short, concrete statement of what "winning" this drill means, shown on
  /// both the list and the challenge screen.
  final String goal;

  final ChallengeType type;

  /// Passed straight through to `recordChallengeScore`.
  final bool higherIsBetter;

  /// How the numeric score is labelled on the result screen, e.g. "puzzles
  /// solved" or "moves taken".
  final String scoreLabel;

  /// Optional unit appended after the number, e.g. " moves".
  final String scoreSuffix;

  /// Countdown length for timed challenges (mateInOneBlitz, coordinateRush).
  final int? timeLimitSeconds;

  /// Move budget for challenges scored/limited by move count (knightHunt,
  /// pawnRace, endgameBoss).
  final int? moveBudget;

  /// Starting position for board-based challenges that use a single fixed
  /// setup (knightHunt, pawnRace, survive, endgameBoss). Ignored by
  /// mateInOneBlitz, which uses [fenPool] instead.
  final String? startFen;

  /// Pool of hand-authored positions to rotate through (mateInOneBlitz).
  final List<String> fenPool;

  /// Engine strength to play against (survive, endgameBoss).
  final Difficulty? difficulty;

  /// Length of the first move sequence to recall (blindfoldSteps).
  final int blindfoldStartLength;
}
