import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../game/model/clock.dart';
import '../../game/model/game_state.dart';
import '../../profile/controller/progress_controller.dart';
import 'app_settings.dart';

const _settingsKey = 'app_settings';

/// Persisted defaults for "Play" and "Puzzles", read via [prefsStoreProvider]
/// — the same [PrefsStore] instance `progress_controller.dart` uses. Home
/// reads this to start immediately without asking; the New Game and Puzzle
/// browse screens are the only places that change it.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(prefsStoreProvider);
    return AppSettings.fromJson(prefs.readJson(_settingsKey));
  }

  void _persist() {
    ref.read(prefsStoreProvider).writeJson(_settingsKey, state.toJson());
  }

  void updateGameDefaults({
    required GameMode mode,
    required Side humanSide,
    required Difficulty difficulty,
    TimeControl? timeControl,
  }) {
    state = state.copyWith(
      gameMode: mode,
      humanSide: humanSide,
      difficulty: difficulty,
      timeControl: timeControl,
    );
    _persist();
  }

  void updatePuzzleDefaults({
    int? minRating,
    int? maxRating,
    String? theme,
  }) {
    state = state.copyWith(
      puzzleMinRating: minRating,
      puzzleMaxRating: maxRating,
      puzzleTheme: theme,
    );
    _persist();
  }
}

final settingsControllerProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
