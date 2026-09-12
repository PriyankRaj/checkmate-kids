// Standalone script — run manually with `dart run tool/fetch_puzzles.dart`.
// Not part of the app. Builds assets/puzzles/puzzles.json from the CC0
// Lichess puzzle database via the HuggingFace datasets-server rows API,
// stratified across rating bands and major themes, with every puzzle
// validated (FEN parses, every move is legal in sequence) before it's
// written out.
//
// Falls back to a small real, validated sample from
// https://raw.githubusercontent.com/mcognetta/lichess-combined-puzzle-game-db
// only if the main HuggingFace approach fails entirely after retries.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartchess/dartchess.dart' hide File;

const _hfBase = 'https://datasets-server.huggingface.co/rows';
const _dataset = 'Lichess%2Fchess-puzzles';
const _pageLength = 100;
// Dataset has ~6.1M rows as of writing; leave headroom below the true max
// so offset + length never runs past the end.
const _maxOffset = 6000000;

const _fallbackUrl =
    'https://raw.githubusercontent.com/mcognetta/lichess-combined-puzzle-game-db/main/sample_100.csv';

/// (name, minInclusive, maxExclusive-or-null-for-open-ended)
const _ratingBands = <(String, int, int?)>[
  ('400-800', 400, 800),
  ('800-1200', 800, 1200),
  ('1200-1600', 1200, 1600),
  ('1600-2000', 1600, 2000),
  ('2000-2400', 2000, 2400),
  ('2400+', 2400, null),
];

const _majorThemes = <String>[
  'mateIn1',
  'mateIn2',
  'mateIn3',
  'fork',
  'pin',
  'skewer',
  'discoveredAttack',
  'hangingPiece',
  'sacrifice',
  'promotion',
  'enPassant',
  'backRankMate',
  'zugzwang',
  'endgame',
  'opening',
  'middlegame',
];

const _targetTotal = 3000;
const _minAcceptable = 500;
// Requests are cheap but the dataset is huge and mostly mid-rated; cap the
// number of pages we fetch so the script terminates in reasonable time even
// if some bands never fill up.
const _maxRequests = 600;

String _bandFor(int rating) {
  for (final (name, min, max) in _ratingBands) {
    if (rating >= min && (max == null || rating < max)) return name;
  }
  return _ratingBands.last.$1;
}

int _bandQuota() => (_targetTotal / _ratingBands.length).ceil();

/// Soft cap so a single theme doesn't dominate a band's quota. Puzzles
/// without any major theme (or with themes already at cap) still count
/// toward the band quota — this only limits how many *major-theme-tagged*
/// slots a single theme can claim.
int _themeCapPerBand() => max(20, (_bandQuota() * 0.4).ceil());

class RawPuzzle {
  RawPuzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
    required this.popularity,
  });

  final String id;
  final String fen;
  final List<String> moves;
  final int rating;
  final List<String> themes;
  final int popularity;
}

Future<String> _httpGet(HttpClient client, Uri uri, {int retries = 3}) async {
  Object? lastError;
  for (var attempt = 0; attempt < retries; attempt++) {
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} for $uri');
      }
      return await response.transform(utf8.decoder).join();
    } catch (e) {
      lastError = e;
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
  }
  throw StateError('Failed to GET $uri after $retries attempts: $lastError');
}

/// Validates a puzzle's FEN and full move list with dartchess. Returns the
/// final [Position] after all moves are played, or null if anything about
/// the puzzle is malformed or illegal.
Position? _validate(String fen, List<String> moves) {
  try {
    Position position = Chess.fromSetup(Setup.parseFen(fen));
    for (final uci in moves) {
      final move = NormalMove.fromUci(uci);
      if (!position.isLegal(move)) return null;
      position = position.play(move);
    }
    return position;
  } catch (_) {
    return null;
  }
}

Future<List<RawPuzzle>> _fetchFromHuggingFace(HttpClient client) async {
  final random = Random();
  final results = <RawPuzzle>[];
  final seenIds = <String>{};
  final bandCounts = <String, int>{for (final b in _ratingBands) b.$1: 0};
  final themeCountsByBand = <String, Map<String, int>>{
    for (final b in _ratingBands) b.$1: {},
  };
  final bandQuota = _bandQuota();
  final themeCap = _themeCapPerBand();

  var requests = 0;
  var consecutiveFailures = 0;

  bool bandsFull() => bandCounts.values.every((c) => c >= bandQuota);

  while (requests < _maxRequests && !bandsFull() && consecutiveFailures < 8) {
    final offset = random.nextInt(_maxOffset);
    final uri = Uri.parse(
      '$_hfBase?dataset=$_dataset&config=default&split=train&offset=$offset&length=$_pageLength',
    );
    requests++;
    String body;
    try {
      body = await _httpGet(client, uri);
      consecutiveFailures = 0;
    } catch (e) {
      consecutiveFailures++;
      stderr.writeln('Request failed ($offset): $e');
      continue;
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('Failed to decode response at offset $offset: $e');
      continue;
    }
    final rows = decoded['rows'] as List? ?? const [];

    for (final entry in rows) {
      final row = (entry as Map<String, dynamic>)['row'] as Map<String, dynamic>;
      final id = row['PuzzleId'] as String?;
      final fen = row['FEN'] as String?;
      final movesStr = row['Moves'] as String?;
      final rating = row['Rating'];
      final popularity = row['Popularity'];
      final themesRaw = row['Themes'];
      if (id == null || fen == null || movesStr == null || rating == null) continue;
      if (seenIds.contains(id)) continue;
      final popularityInt = popularity is int ? popularity : int.tryParse('$popularity') ?? 0;
      if (popularityInt <= 50) continue;

      final ratingInt = rating is int ? rating : int.tryParse('$rating') ?? -1;
      final band = _bandFor(ratingInt);
      if (bandCounts[band]! >= bandQuota) continue;

      final moves = movesStr.trim().split(RegExp(r'\s+'));
      if (moves.length < 2) continue;

      final themes = <String>[
        if (themesRaw is List) for (final t in themesRaw) t.toString(),
      ];

      // Soft theme-diversity gate: if every major theme this puzzle carries
      // is already at cap for this band, skip it to leave room for other
      // themes (but don't block puzzles with no major theme tags at all).
      final majorThemesHere = themes.where(_majorThemes.contains).toList();
      if (majorThemesHere.isNotEmpty) {
        final counts = themeCountsByBand[band]!;
        final allAtCap = majorThemesHere.every((t) => (counts[t] ?? 0) >= themeCap);
        if (allAtCap) continue;
      }

      if (_validate(fen, moves) == null) continue;

      seenIds.add(id);
      bandCounts[band] = bandCounts[band]! + 1;
      final counts = themeCountsByBand[band]!;
      for (final t in majorThemesHere) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
      results.add(RawPuzzle(
        id: id,
        fen: fen,
        moves: moves,
        rating: ratingInt,
        themes: themes,
        popularity: popularityInt,
      ));
    }

    if (requests % 20 == 0) {
      stderr.writeln(
        'Progress: $requests requests, ${results.length} accepted, '
        'bands=${bandCounts.entries.map((e) => '${e.key}:${e.value}/$bandQuota').join(', ')}',
      );
    }
  }

  return results;
}

Future<List<RawPuzzle>> _fetchFallback(HttpClient client) async {
  stderr.writeln('Falling back to GitHub sample dataset...');
  final body = await _httpGet(client, Uri.parse(_fallbackUrl), retries: 3);
  final lines = const LineSplitter().convert(body).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return const [];
  final header = lines.first.split(',');
  final idIdx = header.indexOf('PuzzleId');
  final fenIdx = header.indexOf('FEN');
  final movesIdx = header.indexOf('Moves');
  final ratingIdx = header.indexOf('Rating');
  final themesIdx = header.indexOf('Themes');

  final results = <RawPuzzle>[];
  for (final line in lines.skip(1)) {
    final parts = line.split(',');
    if (parts.length <= movesIdx) continue;
    final id = parts[idIdx];
    final fen = parts[fenIdx];
    final moves = parts[movesIdx].trim().split(RegExp(r'\s+'));
    final rating = int.tryParse(parts[ratingIdx]) ?? 1500;
    final themes = themesIdx >= 0 && themesIdx < parts.length
        ? parts[themesIdx].split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList()
        : <String>[];
    if (_validate(fen, moves) == null) continue;
    results.add(RawPuzzle(
      id: id,
      fen: fen,
      moves: moves,
      rating: rating,
      themes: themes,
      popularity: 100,
    ));
  }
  return results;
}

Future<void> main() async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  List<RawPuzzle> puzzles;
  var usedFallback = false;
  try {
    puzzles = await _fetchFromHuggingFace(client);
    if (puzzles.length < _minAcceptable) {
      stderr.writeln(
        'Only ${puzzles.length} puzzles from HuggingFace (< $_minAcceptable) — trying fallback too.',
      );
      final fallback = await _fetchFallback(client);
      final seen = puzzles.map((p) => p.id).toSet();
      for (final p in fallback) {
        if (seen.add(p.id)) puzzles.add(p);
      }
      usedFallback = true;
    }
  } catch (e) {
    stderr.writeln('HuggingFace approach failed entirely: $e');
    puzzles = await _fetchFallback(client);
    usedFallback = true;
  } finally {
    client.close(force: true);
  }

  if (puzzles.isEmpty) {
    stderr.writeln('No puzzles fetched from any source. Aborting.');
    exitCode = 1;
    return;
  }

  final file = File('assets/puzzles/puzzles.json');
  await file.parent.create(recursive: true);
  final jsonList = [
    for (final p in puzzles)
      {
        'id': p.id,
        'fen': p.fen,
        'moves': p.moves,
        'rating': p.rating,
        'themes': p.themes,
      },
  ];
  final encoded = jsonEncode(jsonList);
  await file.writeAsString(encoded);

  final sizeBytes = await file.length();
  stderr.writeln('Wrote ${puzzles.length} puzzles to ${file.path} '
      '(${(sizeBytes / 1024).toStringAsFixed(1)} KB, usedFallback=$usedFallback).');

  // Print a small distribution summary for the final report.
  final bandCounts = <String, int>{};
  for (final p in puzzles) {
    final band = _bandFor(p.rating);
    bandCounts[band] = (bandCounts[band] ?? 0) + 1;
  }
  stderr.writeln('Rating band distribution: $bandCounts');

  if (sizeBytes > 1536 * 1024) {
    stderr.writeln('File exceeds ~1.5MB — consider gzip (not auto-applied by this run).');
  }
}
