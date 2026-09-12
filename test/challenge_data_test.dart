import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checkmate_kids/challenges/data/challenge_repository.dart';

void main() {
  group('mate-in-one challenge pool', () {
    for (final fen in mateInOneFenPool) {
      test('has at least one legal move that delivers checkmate: $fen', () {
        final position = Chess.fromSetup(Setup.parseFen(fen));
        expect(position.isCheckmate, isFalse, reason: 'Position should not already be checkmate.');
        expect(position.isGameOver, isFalse, reason: 'Position should not already be game over.');

        final legalMoves = <NormalMove>[
          for (final entry in position.legalMoves.entries)
            for (final to in entry.value.squares) NormalMove(from: entry.key, to: to),
        ];
        expect(legalMoves, isNotEmpty, reason: 'Position must have legal moves to be a valid puzzle.');

        final matingMoves = legalMoves.where((move) => position.play(move).isCheckmate).toList();
        expect(
          matingMoves,
          isNotEmpty,
          reason: 'Expected at least one legal move from this FEN to deliver checkmate.',
        );
      });
    }
  });

  test('challenge repository has unique, non-empty ids', () {
    final ids = challengeRepository.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'Challenge ids must be unique.');
    for (final challenge in challengeRepository) {
      expect(challenge.id, isNotEmpty);
      expect(challenge.title, isNotEmpty);
      expect(challenge.goal, isNotEmpty);
    }
  });

  test('fixed-position challenge FENs parse and are not already game over', () {
    for (final challenge in challengeRepository) {
      final fen = challenge.startFen;
      if (fen == null) continue;
      final position = Chess.fromSetup(Setup.parseFen(fen));
      expect(position.isGameOver, isFalse, reason: '${challenge.id} starting position should be playable.');
    }
  });
}
