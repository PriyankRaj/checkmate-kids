import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/board_theme.dart';
import '../../core/theme/kids_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/celebration_overlay.dart';
import '../../core/widgets/responsive_board.dart';
import '../controller/lesson_controller.dart';
import '../data/lesson_repository.dart';
import '../model/lesson.dart';

/// Converts a lesson's hex color string (e.g. `'#4CAF50'`) into a [Color].
Color _colorFromHex(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

/// Converts a data-only [ShapeSpec] into a real chessground [Shape].
Shape _shapeFromSpec(ShapeSpec spec) {
  final color = _colorFromHex(spec.color);
  final orig = Square.fromName(spec.orig);
  if (spec.kind == 'circle') {
    return Circle(color: color, orig: orig);
  }
  return Arrow(color: color, orig: orig, dest: Square.fromName(spec.dest!));
}

/// Plays through one lesson: info steps with an illustrative diagram, and
/// interactive move steps on a live board. `lessonId` comes straight from
/// the `/lessons/:id` route.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repositoryAsync = ref.watch(lessonRepositoryProvider);
    return Theme(
      data: buildKidsTheme(),
      child: repositoryAsync.when(
        loading: () => const AppScaffold(
          title: 'Loading…',
          body: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (error, stackTrace) => AppScaffold(
          title: 'Oops',
          body: Center(child: Text('Could not load this lesson: $error')),
        ),
        data: (repository) => _LessonPlayer(lesson: repository.byId(lessonId)),
      ),
    );
  }
}

class _LessonPlayer extends ConsumerStatefulWidget {
  const _LessonPlayer({required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<_LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends ConsumerState<_LessonPlayer> {
  ChessboardController? _boardController;
  int? _controllerStepIndex;

  @override
  void dispose() {
    _boardController?.dispose();
    super.dispose();
  }

  GameData _gameDataFor(MoveStep step, {bool locked = false}) {
    final position = Chess.fromSetup(Setup.parseFen(step.fen));
    final side = position.turn == Side.white
        ? PlayerSide.white
        : PlayerSide.black;
    return GameData(
      fen: step.fen,
      playerSide: locked ? PlayerSide.none : side,
      sideToMove: position.turn,
      validMoves: locked ? const {} : makeLegalMoves(position),
      kingSquareInCheck: position.isCheck
          ? position.board.kingOf(position.turn)
          : null,
    );
  }

  void _ensureController(int stepIndex, MoveStep step) {
    final controller = _boardController;
    if (controller == null) {
      _boardController = ChessboardController(game: _gameDataFor(step));
      _controllerStepIndex = stepIndex;
    } else if (_controllerStepIndex != stepIndex) {
      controller.updatePosition(_gameDataFor(step), animate: true);
      _controllerStepIndex = stepIndex;
    }
  }

  void _handleMove(MoveStep step, Move move) {
    final notifier = ref.read(lessonControllerProvider(widget.lesson).notifier);
    final isCorrect = step.expectedUci.contains(move.uci);
    notifier.submitMove(move);
    if (isCorrect) {
      _boardController?.updatePosition(
        _gameDataFor(step, locked: true),
        animate: true,
      );
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        notifier.advance();
      });
    } else {
      // Snap the piece back: same FEN, board stays interactive so the child
      // can try again straight away.
      _boardController?.updatePosition(_gameDataFor(step), animate: true);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        notifier.clearFeedback();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final state = ref.watch(lessonControllerProvider(lesson));
    final boardTheme =
        Theme.of(context).extension<BoardTheme>() ?? BoardTheme.kids;

    if (state.completed) {
      return AppScaffold(
        title: lesson.title,
        body: _LessonCompleteView(lesson: lesson),
      );
    }

    final step = state.currentStep;
    return AppScaffold(
      title: lesson.title,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step ${state.stepNumber} of ${state.totalSteps}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.stepNumber / state.totalSteps,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (step) {
              InfoStep() => SingleChildScrollView(
                child: _InfoStepView(
                  step: step,
                  boardTheme: boardTheme,
                  onNext: () {
                    ref
                        .read(lessonControllerProvider(lesson).notifier)
                        .advance();
                  },
                ),
              ),
              MoveStep() => _MoveStepView(
                step: step,
                state: state,
                boardTheme: boardTheme,
                ensureController: () =>
                    _ensureController(state.stepIndex, step),
                boardController: _boardController,
                onMove: (move, {viaDragAndDrop}) {
                  ref.read(gameFeedbackProvider).move();
                  _handleMove(step, move);
                },
                onHint: () => ref
                    .read(lessonControllerProvider(lesson).notifier)
                    .revealHint(),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _InfoStepView extends StatelessWidget {
  const _InfoStepView({
    required this.step,
    required this.boardTheme,
    required this.onNext,
  });

  final InfoStep step;
  final BoardTheme boardTheme;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              step.text,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        if (step.fen != null) ...[
          const SizedBox(height: 16),
          Center(
            child: ResponsiveBoard(
              builder: (context, size) => StaticChessboard(
                size: size,
                orientation: Side.white,
                fen: step.fen!,
                settings: StaticChessboardSettings(
                  colorScheme: boardTheme.colorScheme,
                  pieceAssets: boardTheme.pieceAssets,
                  enableCoordinates: true,
                ),
                shapes: {
                  for (final shape in step.shapes) _shapeFromSpec(shape),
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: FilledButton(
            onPressed: onNext,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Next'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoveStepView extends StatelessWidget {
  const _MoveStepView({
    required this.step,
    required this.state,
    required this.boardTheme,
    required this.ensureController,
    required this.boardController,
    required this.onMove,
    required this.onHint,
  });

  final MoveStep step;
  final LessonSessionState state;
  final BoardTheme boardTheme;
  final VoidCallback ensureController;
  final ChessboardController? boardController;
  final void Function(Move move, {bool? viaDragAndDrop}) onMove;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    // Side-effect kept minimal and idempotent: creates the board controller
    // on first build, or repoints it at the new step's position when the
    // step changes. Mirrors GameScreen's controller lifecycle.
    ensureController();
    final controller = boardController!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              step.prompt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: ResponsiveBoard(
              builder: (context, size) => Chessboard(
                size: size,
                controller: controller,
                orientation: Side.white,
                settings: ChessboardSettings(
                  colorScheme: boardTheme.colorScheme,
                  pieceAssets: boardTheme.pieceAssets,
                  autoQueenPromotion: boardTheme.playful,
                  enableCoordinates: true,
                ),
                shapes: state.hintRevealed
                    ? {for (final hint in step.hints) _shapeFromSpec(hint)}
                    : const {},
                onMove: onMove,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (state.feedback) {
            StepFeedback.correct => _FeedbackBanner(
              key: const ValueKey('correct'),
              text: step.successText,
              emoji: '🎉',
              color: Colors.green,
            ),
            StepFeedback.retry => _FeedbackBanner(
              key: const ValueKey('retry'),
              text: step.retryText,
              emoji: '🤔',
              color: Colors.orange,
            ),
            StepFeedback.none =>
              step.hints.isEmpty
                  ? const SizedBox(key: ValueKey('empty'), height: 48)
                  : Center(
                      key: const ValueKey('hint-button'),
                      child: OutlinedButton.icon(
                        onPressed: onHint,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text(
                          state.hintRevealed ? 'Hint shown' : 'Show me a hint',
                        ),
                      ),
                    ),
          },
        ),
      ],
    );
  }
}

class _FeedbackBanner extends StatefulWidget {
  const _FeedbackBanner({
    super.key,
    required this.text,
    required this.emoji,
    required this.color,
  });

  final String text;
  final String emoji;
  final Color color;

  @override
  State<_FeedbackBanner> createState() => _FeedbackBannerState();
}

class _FeedbackBannerState extends State<_FeedbackBanner> {
  @override
  Widget build(BuildContext context) {
    return PopBadge(
      trigger: true,
      child: Card(
        color: widget.color.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCompleteView extends StatelessWidget {
  const _LessonCompleteView({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return CelebrationOverlay(
      trigger: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const Text('🏆', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            'Lesson complete!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Great job finishing "${lesson.title}"!',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/lessons'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Back to lessons'),
            ),
          ),
        ],
      ),
    );
  }
}
