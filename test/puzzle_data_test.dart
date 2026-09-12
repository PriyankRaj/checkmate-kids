// Data-integrity test for the bundled puzzle set. Reads
// assets/puzzles/puzzles.json directly off disk with dart:io rather than
// through rootBundle, since flutter_test only auto-bundles assets when the
// test is configured for it — plain file I/O is simpler and equally valid
// for checking the data itself rather than the asset pipeline.
import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter_test/flutter_test.dart';

/// Locates assets/puzzles/puzzles.json relative to the repo root regardless
/// of the working directory `flutter test` is invoked from.
File _puzzlesFile() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File('${dir.path}/assets/puzzles/puzzles.json');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  // Fall back to the direct relative path — this is what `flutter test`
  // uses in practice, since it runs from the package root.
  return File('assets/puzzles/puzzles.json');
}

void main() {
  test('every bundled puzzle is a legal, well-formed puzzle', () {
    final file = _puzzlesFile();
    expect(file.existsSync(), isTrue, reason: 'assets/puzzles/puzzles.json must exist');

    final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    expect(decoded, isNotEmpty);

    var validated = 0;
    var mateChecks = 0;

    for (final entry in decoded) {
      final json = entry as Map<String, dynamic>;
      final id = json['id'] as String;
      final fen = json['fen'] as String;
      final moves = [for (final m in json['moves'] as List) m as String];
      final themes = [for (final t in json['themes'] as List) t as String];

      Position position;
      expect(
        () => position = Chess.fromSetup(Setup.parseFen(fen)),
        returnsNormally,
        reason: 'Puzzle $id: FEN "$fen" must parse',
      );
      position = Chess.fromSetup(Setup.parseFen(fen));

      for (final uci in moves) {
        final NormalMove move;
        expect(
          () => NormalMove.fromUci(uci),
          returnsNormally,
          reason: 'Puzzle $id: move "$uci" must parse as a UCI move',
        );
        move = NormalMove.fromUci(uci);
        expect(
          position.isLegal(move),
          isTrue,
          reason: 'Puzzle $id: move "$uci" must be legal at its point in the sequence',
        );
        position = position.play(move);
      }

      final isMateThemed = themes.any((t) => t.startsWith('mateIn'));
      if (isMateThemed) {
        expect(
          position.isCheckmate,
          isTrue,
          reason: 'Puzzle $id is tagged $themes but the final position is not checkmate',
        );
        mateChecks++;
      }

      validated++;
    }

    // ignore: avoid_print
    print('Validated $validated puzzles ($mateChecks mate-themed) from ${file.path}');
    expect(validated, greaterThanOrEqualTo(500));
  });
}
