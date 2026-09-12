import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs_store.dart';
import '../model/progress.dart';

const _progressKey = 'progress';

/// Provided by [main.dart]/an app-level override once `SharedPreferences`
/// is ready. Every feature reads/writes progress through this one
/// controller — see `Progress` for the field each feature owns.
class ProgressController extends Notifier<Progress> {
  @override
  Progress build() {
    final prefs = ref.watch(prefsStoreProvider);
    return Progress.fromJson(prefs.readJson(_progressKey));
  }

  void _persist() {
    ref.read(prefsStoreProvider).writeJson(_progressKey, state.toJson());
  }

  void markPuzzleSolved(String puzzleId, {required int puzzleRatingDelta}) {
    state = state.copyWith(
      solvedPuzzleIds: {...state.solvedPuzzleIds, puzzleId},
      puzzleRating: (state.puzzleRating + puzzleRatingDelta).clamp(400, 3000),
    );
    _persist();
  }

  void markLessonCompleted(String lessonId) {
    state = state.copyWith(completedLessonIds: {...state.completedLessonIds, lessonId});
    _persist();
  }

  /// Records [score] for [challengeId] if it improves on the previous best.
  /// [higherIsBetter] lets challenges use either "most moves survived" or
  /// "fastest time" semantics.
  void recordChallengeScore(
    String challengeId,
    int score, {
    required bool higherIsBetter,
  }) {
    final previous = state.challengeBestScores[challengeId];
    final isBetter = previous == null ||
        (higherIsBetter ? score > previous : score < previous);
    if (!isBetter) return;
    state = state.copyWith(
      challengeBestScores: {...state.challengeBestScores, challengeId: score},
    );
    _persist();
  }
}

final progressControllerProvider = NotifierProvider<ProgressController, Progress>(
  ProgressController.new,
);

/// Overridden in `main.dart` with the app's single [PrefsStore] instance
/// once `SharedPreferences.getInstance()` resolves.
final prefsStoreProvider = Provider<PrefsStore>((ref) {
  throw UnimplementedError('prefsStoreProvider must be overridden in main.dart');
});
