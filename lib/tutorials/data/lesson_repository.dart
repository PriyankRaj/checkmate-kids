import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/lesson.dart';

/// Filenames of every bundled lesson, in the order new lessons should be
/// appended. Kept as an explicit list (rather than parsing
/// `AssetManifest.json`) so adding a lesson is just "drop a JSON file here
/// and add its name to this list" — see `pubspec.yaml`'s `flutter.assets`
/// for the matching directory declaration.
const _lessonAssetPaths = [
  'assets/lessons/01_board_basics.json',
  'assets/lessons/02_rook.json',
  'assets/lessons/03_bishop.json',
  'assets/lessons/04_queen.json',
  'assets/lessons/05_knight.json',
  'assets/lessons/06_king.json',
  'assets/lessons/07_pawn.json',
  'assets/lessons/08_capturing.json',
  'assets/lessons/09_check.json',
  'assets/lessons/10_checkmate.json',
  'assets/lessons/11_castling.json',
  'assets/lessons/12_en_passant.json',
  'assets/lessons/13_promotion.json',
  'assets/lessons/14_stalemate_and_draws.json',
  'assets/lessons/15_fork.json',
  'assets/lessons/16_pin.json',
  'assets/lessons/17_back_rank_mate.json',
  'assets/lessons/18_king_queen_vs_king.json',
];

/// Loads and parses the bundled lesson track. Exposed as a [FutureProvider]
/// per Riverpod 3 idioms — screens `ref.watch` this and handle the
/// loading/error/data cases with `AsyncValue`.
final lessonRepositoryProvider = FutureProvider<LessonRepository>((ref) async {
  final lessons = <Lesson>[];
  for (final path in _lessonAssetPaths) {
    final raw = await rootBundle.loadString(path);
    lessons.add(Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }
  lessons.sort((a, b) => a.order.compareTo(b.order));
  return LessonRepository(lessons);
});

/// The parsed, ordered lesson track, with lookup by id.
class LessonRepository {
  LessonRepository(this.lessons) : _byId = {for (final lesson in lessons) lesson.id: lesson};

  /// All lessons, ordered by [Lesson.order].
  final List<Lesson> lessons;

  final Map<String, Lesson> _byId;

  Lesson byId(String id) {
    final lesson = _byId[id];
    if (lesson == null) {
      throw ArgumentError.value(id, 'id', 'No lesson with this id');
    }
    return lesson;
  }
}
