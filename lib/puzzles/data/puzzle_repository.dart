import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/puzzle.dart';

/// Loads the bundled Lichess-derived puzzle set once and exposes query
/// helpers used by the browse screen and the puzzle attempt controller.
class PuzzleRepository {
  PuzzleRepository(this._puzzles) : _byId = {for (final p in _puzzles) p.id: p};

  final List<Puzzle> _puzzles;
  final Map<String, Puzzle> _byId;

  List<Puzzle> get all => List.unmodifiable(_puzzles);

  Puzzle? byId(String id) => _byId[id];

  List<Puzzle> byTheme(String theme) =>
      _puzzles.where((p) => p.themes.contains(theme)).toList(growable: false);

  /// [minRating] inclusive, [maxRating] exclusive-or-inclusive doesn't
  /// matter much for a browse filter — both bounds are inclusive here.
  List<Puzzle> byRatingRange(int minRating, int maxRating) => _puzzles
      .where((p) => p.rating >= minRating && p.rating <= maxRating)
      .toList(growable: false);

  /// Returns a random puzzle matching the optional [theme] and rating range,
  /// excluding [excludeId] if given (used by "next puzzle" so it doesn't
  /// repeat immediately). Falls back to any puzzle if the filtered set is
  /// empty, and returns null only if there are no puzzles at all.
  Puzzle? randomPuzzle({
    String? theme,
    int? minRating,
    int? maxRating,
    String? excludeId,
  }) {
    if (_puzzles.isEmpty) return null;
    var candidates = _puzzles.where((p) {
      if (theme != null && !p.themes.contains(theme)) return false;
      if (minRating != null && p.rating < minRating) return false;
      if (maxRating != null && p.rating > maxRating) return false;
      return true;
    }).toList();
    if (excludeId != null) {
      final withoutExcluded = candidates.where((p) => p.id != excludeId).toList();
      if (withoutExcluded.isNotEmpty) candidates = withoutExcluded;
    }
    if (candidates.isEmpty) candidates = _puzzles;
    return candidates[Random().nextInt(candidates.length)];
  }
}

/// Loads and parses `assets/puzzles/puzzles.json` once per app session.
final puzzleRepositoryProvider = FutureProvider<PuzzleRepository>((ref) async {
  final raw = await rootBundle.loadString('assets/puzzles/puzzles.json');
  final decoded = jsonDecode(raw) as List<dynamic>;
  final puzzles = [
    for (final entry in decoded) Puzzle.fromJson(entry as Map<String, dynamic>),
  ];
  return PuzzleRepository(puzzles);
});
