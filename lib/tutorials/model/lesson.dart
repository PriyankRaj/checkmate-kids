/// Data model for the Kids' Tutorials feature.
///
/// Lessons are authored as JSON under `assets/lessons/` (see
/// [LessonRepository]) so a non-programmer can add or edit lesson text
/// without touching Dart code. This file only knows about plain data: no
/// Flutter, dartchess, or chessground types leak in here. The view layer
/// (`lesson_screen.dart`) is responsible for turning [ShapeSpec]s into
/// actual board arrows/circles and [String] squares into dartchess/
/// chessground types.
library;

/// A single visual annotation to draw on a board: either an arrow between
/// two squares or a circle around one square.
class ShapeSpec {
  const ShapeSpec({required this.kind, required this.orig, this.dest, this.color = '#4CAF50'});

  /// `'arrow'` or `'circle'`.
  final String kind;

  /// Origin square in algebraic notation, e.g. `'e2'`.
  final String orig;

  /// Destination square, required for `'arrow'`, ignored for `'circle'`.
  final String? dest;

  /// Hex color string, e.g. `'#4CAF50'`.
  final String color;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'orig': orig,
        if (dest != null) 'dest': dest,
        'color': color,
      };

  factory ShapeSpec.fromJson(Map<String, dynamic> json) => ShapeSpec(
        kind: json['kind'] as String,
        orig: json['orig'] as String,
        dest: json['dest'] as String?,
        color: json['color'] as String? ?? '#4CAF50',
      );
}

/// One step within a [Lesson]. Either an explanatory [InfoStep] or an
/// interactive [MoveStep] the child must play out on the board.
sealed class LessonStep {
  const LessonStep();

  factory LessonStep.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'info' => InfoStep.fromJson(json),
      'move' => MoveStep.fromJson(json),
      _ => throw FormatException('Unknown lesson step type: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

/// A purely explanatory step: some text, an optional diagram, and a "Next"
/// button. No interaction beyond reading.
class InfoStep extends LessonStep {
  const InfoStep({required this.text, this.fen, this.shapes = const []});

  /// Warm, simple explanatory text aimed at a young beginner.
  final String text;

  /// Optional position to illustrate the point, shown on a [StaticChessboard].
  final String? fen;

  /// Arrows/circles drawn on the diagram, if [fen] is set.
  final List<ShapeSpec> shapes;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'info',
        'text': text,
        if (fen != null) 'fen': fen,
        if (shapes.isNotEmpty) 'shapes': [for (final s in shapes) s.toJson()],
      };

  factory InfoStep.fromJson(Map<String, dynamic> json) => InfoStep(
        text: json['text'] as String,
        fen: json['fen'] as String?,
        shapes: [
          for (final s in (json['shapes'] as List? ?? const []))
            ShapeSpec.fromJson(s as Map<String, dynamic>),
        ],
      );
}

/// An interactive step: set up [fen], ask the child to play one of
/// [expectedUci], and react with warmth either way.
class MoveStep extends LessonStep {
  const MoveStep({
    required this.fen,
    required this.expectedUci,
    required this.prompt,
    required this.successText,
    this.retryText = 'Not quite — try again!',
    this.hints = const [],
  });

  /// The position the child plays from.
  final String fen;

  /// UCI strings (e.g. `'e2e4'`, promotions as `'e7e8q'`) of every move that
  /// counts as correct for this step. More than one entry means there are
  /// multiple valid correct answers (e.g. several valid captures).
  final List<String> expectedUci;

  /// Instruction shown above the board, e.g. "Move the rook to capture the pawn.".
  final String prompt;

  /// Shown when the child plays a correct move.
  final String successText;

  /// Shown when the child plays an incorrect (but legal or illegal) move.
  final String retryText;

  /// Arrows/circles revealed when the child taps the hint button.
  final List<ShapeSpec> hints;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'move',
        'fen': fen,
        'expectedUci': expectedUci,
        'prompt': prompt,
        'successText': successText,
        'retryText': retryText,
        if (hints.isNotEmpty) 'hints': [for (final h in hints) h.toJson()],
      };

  factory MoveStep.fromJson(Map<String, dynamic> json) => MoveStep(
        fen: json['fen'] as String,
        expectedUci: [for (final m in json['expectedUci'] as List) m as String],
        prompt: json['prompt'] as String,
        successText: json['successText'] as String,
        retryText: json['retryText'] as String? ?? 'Not quite — try again!',
        hints: [
          for (final h in (json['hints'] as List? ?? const []))
            ShapeSpec.fromJson(h as Map<String, dynamic>),
        ],
      );
}

/// A full beginner lesson: a short track of [steps] that teaches one concept.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.order,
    required this.steps,
  });

  /// Stable identifier, used in routing (`/lessons/:id`) and in
  /// [Progress.completedLessonIds].
  final String id;

  final String title;

  /// One or two sentences shown in the lesson list.
  final String summary;

  /// Position of this lesson within the overall beginner track.
  final int order;

  final List<LessonStep> steps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'order': order,
        'steps': [for (final s in steps) s.toJson()],
      };

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        order: json['order'] as int,
        steps: [
          for (final s in json['steps'] as List) LessonStep.fromJson(s as Map<String, dynamic>),
        ],
      );
}
