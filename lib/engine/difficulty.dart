/// The computer-opponent difficulty ladder.
///
/// Stockfish's `UCI_Elo` floor is 1320, far too strong for a beginner, so the
/// bottom rungs are built from `Skill Level`, a hard search-depth cap, and a
/// blunder probability applied in [EngineService] itself rather than in the
/// engine.
enum Difficulty {
  kitten,
  beginner,
  easy,
  casual,
  club,
  strong,
  expert,
  master,
  maximum,
}

class DifficultyProfile {
  const DifficultyProfile({
    required this.label,
    required this.description,
    this.skillLevel,
    this.limitStrength = false,
    this.elo,
    this.searchDepth,
    this.moveTimeMs,
    this.blunderProbability = 0.0,
  });

  final String label;
  final String description;

  /// `Skill Level` UCI option (0-20). Null leaves it at the engine default.
  final int? skillLevel;

  /// Whether to set `UCI_LimitStrength true` and use [elo].
  final bool limitStrength;

  /// `UCI_Elo` value (1320-3190), only used when [limitStrength] is true.
  final int? elo;

  /// Hard `go depth <n>` cap. Used instead of movetime at weak levels so a
  /// fast phone doesn't out-calculate the intended weakness in milliseconds.
  final int? searchDepth;

  /// `go movetime <ms>` cap. Used instead of depth at the top level.
  final int? moveTimeMs;

  /// Probability [0, 1] that [EngineService] substitutes a random legal move
  /// instead of the engine's chosen move.
  final double blunderProbability;
}

const Map<Difficulty, DifficultyProfile> difficultyProfiles = {
  Difficulty.kitten: DifficultyProfile(
    label: 'Kitten',
    description: 'Barely knows the rules. Great for very first games.',
    skillLevel: 0,
    searchDepth: 1,
    blunderProbability: 0.35,
  ),
  Difficulty.beginner: DifficultyProfile(
    label: 'Beginner',
    description: 'Makes obvious mistakes and simple tactics.',
    skillLevel: 0,
    searchDepth: 2,
    blunderProbability: 0.15,
  ),
  Difficulty.easy: DifficultyProfile(
    label: 'Easy',
    description: 'A gentle challenge for newer players.',
    skillLevel: 3,
    searchDepth: 4,
    blunderProbability: 0.05,
  ),
  Difficulty.casual: DifficultyProfile(
    label: 'Casual',
    description: 'Plays casually, roughly a new club player.',
    limitStrength: true,
    elo: 1320,
  ),
  Difficulty.club: DifficultyProfile(
    label: 'Club',
    description: 'A solid club-level opponent.',
    limitStrength: true,
    elo: 1600,
  ),
  Difficulty.strong: DifficultyProfile(
    label: 'Strong',
    description: 'A strong, tactically sharp opponent.',
    limitStrength: true,
    elo: 2000,
  ),
  Difficulty.expert: DifficultyProfile(
    label: 'Expert',
    description: 'Expert-level play. Few mistakes.',
    limitStrength: true,
    elo: 2400,
  ),
  Difficulty.master: DifficultyProfile(
    label: 'Master',
    description: 'Master-level play. Punishes almost anything.',
    limitStrength: true,
    elo: 2850,
  ),
  Difficulty.maximum: DifficultyProfile(
    label: 'Maximum',
    description: 'Full strength. No mercy.',
    moveTimeMs: 1000,
  ),
};
