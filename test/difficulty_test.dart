import 'package:checkmate_kids/engine/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every difficulty has a profile', () {
    for (final d in Difficulty.values) {
      expect(difficultyProfiles.containsKey(d), isTrue, reason: '$d missing a profile');
    }
  });

  test('ladder gets stronger: blunder probability decreases, elo increases', () {
    final kitten = difficultyProfiles[Difficulty.kitten]!;
    final beginner = difficultyProfiles[Difficulty.beginner]!;
    final easy = difficultyProfiles[Difficulty.easy]!;
    expect(kitten.blunderProbability, greaterThan(beginner.blunderProbability));
    expect(beginner.blunderProbability, greaterThan(easy.blunderProbability));

    final casual = difficultyProfiles[Difficulty.casual]!;
    final club = difficultyProfiles[Difficulty.club]!;
    final strong = difficultyProfiles[Difficulty.strong]!;
    final expert = difficultyProfiles[Difficulty.expert]!;
    final master = difficultyProfiles[Difficulty.master]!;
    expect(casual.elo, lessThan(club.elo!));
    expect(club.elo, lessThan(strong.elo!));
    expect(strong.elo, lessThan(expert.elo!));
    expect(expert.elo, lessThan(master.elo!));
  });

  test('elo-limited levels respect Stockfish minimum of 1320', () {
    for (final profile in difficultyProfiles.values) {
      if (profile.limitStrength && profile.elo != null) {
        expect(profile.elo, greaterThanOrEqualTo(1320));
      }
    }
  });

  test('maximum difficulty has no artificial weakening', () {
    final max = difficultyProfiles[Difficulty.maximum]!;
    expect(max.blunderProbability, 0.0);
    expect(max.limitStrength, isFalse);
  });
}
