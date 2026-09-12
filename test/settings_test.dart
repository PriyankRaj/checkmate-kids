import 'package:checkmate_kids/core/settings/app_settings.dart';
import 'package:checkmate_kids/engine/difficulty.dart';
import 'package:checkmate_kids/game/model/clock.dart';
import 'package:checkmate_kids/game/model/game_state.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default settings are sensible for a first-time user', () {
    const settings = AppSettings();
    expect(settings.gameMode, GameMode.vsComputer);
    expect(settings.humanSide, Side.white);
    expect(settings.difficulty, Difficulty.club);
    expect(settings.timeControl, isNull);
    expect(settings.puzzleMinRating, isNull);
    expect(settings.puzzleMaxRating, isNull);
    expect(settings.puzzleTheme, isNull);
  });

  test('round-trips through JSON, including a timed game', () {
    const settings = AppSettings(
      gameMode: GameMode.vsComputer,
      humanSide: Side.black,
      difficulty: Difficulty.expert,
      timeControl: TimeControl(initialSeconds: 300, incrementSeconds: 3),
      puzzleMinRating: 1200,
      puzzleMaxRating: 1600,
      puzzleTheme: 'fork',
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.gameMode, settings.gameMode);
    expect(restored.humanSide, settings.humanSide);
    expect(restored.difficulty, settings.difficulty);
    expect(restored.timeControl, TimeControl.blitz);
    expect(restored.puzzleMinRating, 1200);
    expect(restored.puzzleMaxRating, 1600);
    expect(restored.puzzleTheme, 'fork');
  });

  test('round-trips an untimed game as null, not a zero-length clock', () {
    const settings = AppSettings(timeControl: null);
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.timeControl, isNull);
  });

  test('unknown/corrupt enum values fall back to sensible defaults', () {
    final restored = AppSettings.fromJson({
      'gameMode': 'not-a-real-mode',
      'humanSide': 'not-a-real-side',
      'difficulty': 'not-a-real-difficulty',
    });
    expect(restored.gameMode, GameMode.vsComputer);
    expect(restored.humanSide, Side.white);
    expect(restored.difficulty, Difficulty.club);
  });

  test('copyWith can clear a value back to null via the sentinel default', () {
    const withTheme = AppSettings(puzzleTheme: 'pin');
    final cleared = withTheme.copyWith(puzzleTheme: null);
    expect(cleared.puzzleTheme, isNull);
  });
}
