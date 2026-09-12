import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:stockfish/stockfish.dart';

import 'difficulty.dart';

/// Wraps the single process-wide Stockfish instance.
///
/// `stockfish` throws a [StateError] if you construct a second instance
/// while one is alive, so every feature (game, puzzles, challenges,
/// analysis) must share one [EngineService] and queue requests through it.
/// [main.dart] provisions exactly one via `engineServiceProvider`.
class EngineService {
  Stockfish? _stockfish;
  Future<void> _queue = Future<void>.value();

  Future<Stockfish> _ensureReady() async {
    final existing = _stockfish;
    if (existing != null && existing.state.value == StockfishState.ready) {
      return existing;
    }
    final sf = await stockfishAsync();
    _stockfish = sf;
    return sf;
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Runs `go` at the given [difficulty] from [fen] and returns the chosen
  /// move in UCI form (e.g. `e2e4`), or null if the engine has no move
  /// (checkmate/stalemate already reached).
  ///
  /// [position] is the current position, used only to pick a random legal
  /// move when the difficulty's blunder chance triggers — the engine itself
  /// is never asked to play badly beyond `Skill Level`/depth caps.
  Future<String?> bestMoveUci({
    required String fen,
    required Position position,
    required Difficulty difficulty,
    Random? random,
  }) {
    return _enqueue(() async {
      final profile = difficultyProfiles[difficulty]!;
      final sf = await _ensureReady();

      sf.stdin = 'setoption name Skill Level value ${profile.skillLevel ?? 20}';
      sf.stdin =
          'setoption name UCI_LimitStrength value ${profile.limitStrength}';
      if (profile.limitStrength && profile.elo != null) {
        sf.stdin = 'setoption name UCI_Elo value ${profile.elo}';
      }
      sf.stdin = 'position fen $fen';

      final goCommand = profile.searchDepth != null
          ? 'go depth ${profile.searchDepth}'
          : 'go movetime ${profile.moveTimeMs ?? 1000}';

      final bestMoveCompleter = Completer<String?>();
      final subscription = sf.stdout.listen((line) {
        if (line.startsWith('bestmove')) {
          final token = line.split(' ').skip(1).firstOrNull;
          if (!bestMoveCompleter.isCompleted) {
            bestMoveCompleter.complete(
              token == null || token == '(none)' ? null : token,
            );
          }
        }
      });
      sf.stdin = goCommand;

      final engineMove = await bestMoveCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
      await subscription.cancel();

      if (engineMove == null) return null;

      final rng = random ?? Random();
      if (profile.blunderProbability > 0 &&
          rng.nextDouble() < profile.blunderProbability) {
        final legal = position.legalMoves.entries
            .expand((e) => e.value.squares.map((to) => NormalMove(
                  from: e.key,
                  to: to,
                )))
            .toList();
        if (legal.isNotEmpty) {
          return legal[rng.nextInt(legal.length)].uci;
        }
      }
      return engineMove;
    });
  }

  /// Runs the engine at maximum strength to suggest a move — used by the
  /// analysis board and by "show hint" affordances.
  Future<String?> suggestMoveUci({
    required String fen,
    required Position position,
    int moveTimeMs = 800,
  }) {
    return _enqueue(() async {
      final sf = await _ensureReady();
      sf.stdin = 'setoption name Skill Level value 20';
      sf.stdin = 'setoption name UCI_LimitStrength value false';
      sf.stdin = 'position fen $fen';

      final bestMoveCompleter = Completer<String?>();
      final subscription = sf.stdout.listen((line) {
        if (line.startsWith('bestmove')) {
          final token = line.split(' ').skip(1).firstOrNull;
          if (!bestMoveCompleter.isCompleted) {
            bestMoveCompleter.complete(
              token == null || token == '(none)' ? null : token,
            );
          }
        }
      });
      sf.stdin = 'go movetime $moveTimeMs';

      final move = await bestMoveCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
      await subscription.cancel();
      return move;
    });
  }

  void dispose() {
    _stockfish?.dispose();
    _stockfish = null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
