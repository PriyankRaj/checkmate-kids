/// A single tactics puzzle sourced from the Lichess puzzle database (CC0).
///
/// [fen] is the position *before* the opponent's move — i.e. exactly as it
/// appears in the source data. [moves] is the *full* UCI move list including
/// that opponent move as `moves[0]`; the solver's side to move is the
/// opposite of the side to move in [fen]. See `puzzle_controller.dart` for
/// how the auto-play-then-solve flow is driven from this data.
class Puzzle {
  const Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
  });

  final String id;
  final String fen;
  final List<String> moves;
  final int rating;
  final List<String> themes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fen': fen,
        'moves': moves,
        'rating': rating,
        'themes': themes,
      };

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String,
      fen: json['fen'] as String,
      moves: [for (final m in json['moves'] as List) m as String],
      rating: json['rating'] as int,
      themes: [for (final t in json['themes'] as List) t as String],
    );
  }
}
