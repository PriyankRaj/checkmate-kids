/// Persisted progress across puzzles, lessons, and challenges. This is the
/// single shared contract between those three features and the profile
/// screen — each feature reads/writes its own slice via [ProgressStore]
/// without needing to know about the others' internals.
class Progress {
  const Progress({
    this.solvedPuzzleIds = const {},
    this.puzzleRating = 1200,
    this.completedLessonIds = const {},
    this.challengeBestScores = const {},
  });

  /// IDs of puzzles solved at least once (from `Puzzle.id`).
  final Set<String> solvedPuzzleIds;

  /// A simple Elo-like rating the player earns by solving puzzles above or
  /// below their current rating. Starts at 1200.
  final int puzzleRating;

  /// IDs of fully completed lessons (from `Lesson.id`).
  final Set<String> completedLessonIds;

  /// Best score per challenge, keyed by `Challenge.id`. The meaning of the
  /// score (time in ms, moves survived, etc.) is defined by each challenge.
  final Map<String, int> challengeBestScores;

  Progress copyWith({
    Set<String>? solvedPuzzleIds,
    int? puzzleRating,
    Set<String>? completedLessonIds,
    Map<String, int>? challengeBestScores,
  }) {
    return Progress(
      solvedPuzzleIds: solvedPuzzleIds ?? this.solvedPuzzleIds,
      puzzleRating: puzzleRating ?? this.puzzleRating,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      challengeBestScores: challengeBestScores ?? this.challengeBestScores,
    );
  }

  Map<String, dynamic> toJson() => {
        'solvedPuzzleIds': solvedPuzzleIds.toList(),
        'puzzleRating': puzzleRating,
        'completedLessonIds': completedLessonIds.toList(),
        'challengeBestScores': challengeBestScores,
      };

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      solvedPuzzleIds: {
        for (final id in (json['solvedPuzzleIds'] as List? ?? [])) id as String,
      },
      puzzleRating: json['puzzleRating'] as int? ?? 1200,
      completedLessonIds: {
        for (final id in (json['completedLessonIds'] as List? ?? [])) id as String,
      },
      challengeBestScores: {
        for (final entry in (json['challengeBestScores'] as Map? ?? {}).entries)
          entry.key as String: entry.value as int,
      },
    );
  }
}
