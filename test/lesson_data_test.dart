// Validates every bundled lesson asset: every FEN must parse and represent a
// legal chess position, every move-step's expected move(s) must be legal at
// that FEN, and step/lesson structure must be internally consistent.
//
// Reads the JSON files directly from disk with dart:io (same rationale as
// any other pure-data test in this repo: no need to spin up a widget tree
// or the asset bundle just to validate content).
import 'dart:convert';
import 'dart:io';

import 'package:checkmate_kids/tutorials/model/lesson.dart';
import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Directory('assets/lessons');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('assets/lessons directory is not empty', () {
    expect(files, isNotEmpty, reason: 'Expected lesson JSON files under assets/lessons/');
  });

  final lessons = <Lesson>[];
  for (final file in files) {
    test('${file.path} parses into a valid Lesson', () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final lesson = Lesson.fromJson(json);
      lessons.add(lesson);

      expect(lesson.id, isNotEmpty);
      expect(lesson.title, isNotEmpty);
      expect(lesson.summary, isNotEmpty);
      expect(lesson.steps, isNotEmpty, reason: 'Lesson ${lesson.id} has no steps');

      for (final (i, step) in lesson.steps.indexed) {
        switch (step) {
          case InfoStep(text: final text, fen: final fen, shapes: final shapes):
            expect(text, isNotEmpty, reason: '${lesson.id} step $i: info text is empty');
            if (fen != null) {
              expect(
                () => Chess.fromSetup(Setup.parseFen(fen)),
                returnsNormally,
                reason: '${lesson.id} step $i: invalid FEN "$fen"',
              );
            }
            for (final shape in shapes) {
              expect(
                () => Square.fromName(shape.orig),
                returnsNormally,
                reason: '${lesson.id} step $i: bad shape.orig "${shape.orig}"',
              );
              if (shape.dest != null) {
                expect(
                  () => Square.fromName(shape.dest!),
                  returnsNormally,
                  reason: '${lesson.id} step $i: bad shape.dest "${shape.dest}"',
                );
              }
            }
          case MoveStep(
              fen: final fen,
              expectedUci: final expectedUci,
              prompt: final prompt,
              successText: final successText,
            ):
            expect(prompt, isNotEmpty, reason: '${lesson.id} step $i: move prompt is empty');
            expect(successText, isNotEmpty, reason: '${lesson.id} step $i: successText is empty');
            expect(expectedUci, isNotEmpty, reason: '${lesson.id} step $i: no expectedUci moves');

            late Position position;
            expect(
              () => position = Chess.fromSetup(Setup.parseFen(fen)),
              returnsNormally,
              reason: '${lesson.id} step $i: invalid FEN "$fen"',
            );

            for (final uci in expectedUci) {
              final move = NormalMove.fromUci(uci);
              expect(
                position.isLegal(move),
                isTrue,
                reason: '${lesson.id} step $i: expected move "$uci" is not legal at FEN "$fen"',
              );
            }
        }
      }
    });
  }

  test('lesson ids are unique and orders form a contiguous sequence', () {
    // Re-parse independently of the per-file tests above (test bodies run
    // lazily), so do a final pass over disk here too.
    final parsed = [
      for (final file in files) Lesson.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>),
    ]..sort((a, b) => a.order.compareTo(b.order));

    final ids = parsed.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'Duplicate lesson ids: $ids');

    final orders = parsed.map((l) => l.order).toList();
    expect(orders, List.generate(orders.length, (i) => i + 1), reason: 'Lesson orders should be 1..N with no gaps/dupes');

    expect(parsed.length, greaterThanOrEqualTo(12), reason: 'Expected at least 12 lessons');

    final totalSteps = parsed.fold<int>(0, (sum, l) => sum + l.steps.length);
    // ignore: avoid_print
    print('Validated ${parsed.length} lessons, $totalSteps total steps.');
  });
}
