import 'package:checkmate_kids/game/model/clock.dart';
import 'package:checkmate_kids/game/model/game_state.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClockState', () {
    test('tick decrements only the side to move', () {
      final clock = ClockState.fromTimeControl(TimeControl.blitz);
      final afterWhiteTick = clock.tick(true);
      expect(afterWhiteTick.whiteRemaining, clock.whiteRemaining - 1);
      expect(afterWhiteTick.blackRemaining, clock.blackRemaining);
    });

    test('flag falls at zero, not before', () {
      const clock = ClockState(whiteRemaining: 1, blackRemaining: 10);
      expect(clock.whiteFlagged, isFalse);
      expect(clock.tick(true).whiteFlagged, isTrue);
    });

    test('increment is added only to the side that just moved', () {
      const clock = ClockState(whiteRemaining: 10, blackRemaining: 10, increment: 5);
      final afterWhiteMove = clock.applyIncrement(true);
      expect(afterWhiteMove.whiteRemaining, 15);
      expect(afterWhiteMove.blackRemaining, 10);
    });
  });

  group('GameState', () {
    test('a fresh game starts at the initial position with white to move', () {
      final state = GameState.newGame(mode: GameMode.passAndPlay);
      expect(state.position.fen, Chess.initial.fen);
      expect(state.sideToMove, Side.white);
      expect(state.isGameOver, isFalse);
    });

    test('pass-and-play always reports it is the human turn', () {
      final state = GameState.newGame(mode: GameMode.passAndPlay);
      expect(state.isHumanTurn, isTrue);
    });

    test('vsComputer is only the human turn when it matches humanSide', () {
      final asWhite = GameState.newGame(mode: GameMode.vsComputer, humanSide: Side.white);
      expect(asWhite.isHumanTurn, isTrue);

      final asBlack = GameState.newGame(mode: GameMode.vsComputer, humanSide: Side.black);
      expect(asBlack.isHumanTurn, isFalse);
    });

    test('fool\'s mate is detected as game over with a result description', () {
      // 1. f3 e5 2. g4 Qh4#
      Position pos = Chess.initial;
      for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        pos = pos.play(NormalMove.fromUci(uci));
      }
      expect(pos.isCheckmate, isTrue);

      final state = GameState.newGame(mode: GameMode.passAndPlay).copyWith(position: pos);
      expect(state.isGameOver, isTrue);
      expect(state.resultDescription, 'Black wins by checkmate');
    });
  });
}
