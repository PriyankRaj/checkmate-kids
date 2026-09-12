import 'package:dartchess/dartchess.dart';

import '../../engine/difficulty.dart';
import '../../game/model/clock.dart';
import '../../game/model/game_state.dart';

/// Persisted defaults so "Play" and "Puzzles" can start immediately from
/// Home without asking every time — these are only ever changed explicitly,
/// via the "change" affordance on the New Game / Puzzle browse screens.
class AppSettings {
  const AppSettings({
    this.gameMode = GameMode.vsComputer,
    this.humanSide = Side.white,
    this.difficulty = Difficulty.club,
    this.timeControl,
    this.puzzleMinRating,
    this.puzzleMaxRating,
    this.puzzleTheme,
  });

  /// Game defaults.
  final GameMode gameMode;
  final Side humanSide;
  final Difficulty difficulty;

  /// `null` means untimed.
  final TimeControl? timeControl;

  /// Puzzle defaults — a rating band (`null`/`null` means "any rating") and
  /// an optional theme filter (`null` means "any theme").
  final int? puzzleMinRating;
  final int? puzzleMaxRating;
  final String? puzzleTheme;

  AppSettings copyWith({
    GameMode? gameMode,
    Side? humanSide,
    Difficulty? difficulty,
    Object? timeControl = _sentinel,
    Object? puzzleMinRating = _sentinel,
    Object? puzzleMaxRating = _sentinel,
    Object? puzzleTheme = _sentinel,
  }) {
    return AppSettings(
      gameMode: gameMode ?? this.gameMode,
      humanSide: humanSide ?? this.humanSide,
      difficulty: difficulty ?? this.difficulty,
      timeControl: timeControl == _sentinel ? this.timeControl : timeControl as TimeControl?,
      puzzleMinRating: puzzleMinRating == _sentinel ? this.puzzleMinRating : puzzleMinRating as int?,
      puzzleMaxRating: puzzleMaxRating == _sentinel ? this.puzzleMaxRating : puzzleMaxRating as int?,
      puzzleTheme: puzzleTheme == _sentinel ? this.puzzleTheme : puzzleTheme as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'gameMode': gameMode.name,
        'humanSide': humanSide.name,
        'difficulty': difficulty.name,
        'timeControlInitial': timeControl?.initialSeconds,
        'timeControlIncrement': timeControl?.incrementSeconds,
        'puzzleMinRating': puzzleMinRating,
        'puzzleMaxRating': puzzleMaxRating,
        'puzzleTheme': puzzleTheme,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final initial = json['timeControlInitial'] as int?;
    final increment = json['timeControlIncrement'] as int?;
    return AppSettings(
      gameMode: GameMode.values.firstWhere(
        (m) => m.name == json['gameMode'],
        orElse: () => GameMode.vsComputer,
      ),
      humanSide: Side.values.firstWhere(
        (s) => s.name == json['humanSide'],
        orElse: () => Side.white,
      ),
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => Difficulty.club,
      ),
      timeControl: initial == null
          ? null
          : TimeControl(initialSeconds: initial, incrementSeconds: increment ?? 0),
      puzzleMinRating: json['puzzleMinRating'] as int?,
      puzzleMaxRating: json['puzzleMaxRating'] as int?,
      puzzleTheme: json['puzzleTheme'] as String?,
    );
  }
}

const _sentinel = Object();
