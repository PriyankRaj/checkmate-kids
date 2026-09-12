import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/board_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/celebration_overlay.dart';
import '../../core/widgets/responsive_board.dart';
import '../controller/puzzle_controller.dart';
import '../data/puzzle_repository.dart';

/// Plays out a single puzzle: loads it, auto-plays the opponent's first
/// move, then accepts/rejects the solver's attempts move by move. See
/// `puzzle_controller.dart` for the state machine this screen renders.
class PuzzleScreen extends ConsumerWidget {
  const PuzzleScreen({super.key, required this.puzzleId});

  final String puzzleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(puzzleRepositoryProvider);
    return AppScaffold(
      title: 'Puzzle',
      scrollable: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: 'Rating & theme filters',
          onPressed: () => context.push('/puzzles'),
        ),
      ],
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load puzzles: $error')),
        data: (repo) {
          if (repo.byId(puzzleId) == null) {
            return Center(child: Text('Puzzle "$puzzleId" was not found.'));
          }
          return _PuzzleBoard(puzzleId: puzzleId);
        },
      ),
    );
  }
}

class _PuzzleBoard extends ConsumerStatefulWidget {
  const _PuzzleBoard({required this.puzzleId});

  final String puzzleId;

  @override
  ConsumerState<_PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends ConsumerState<_PuzzleBoard> {
  late final ChessboardController _boardController;
  bool _celebrate = false;
  bool _shakeWrong = false;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(puzzleControllerProvider(widget.puzzleId));
    _boardController = ChessboardController(game: _gameDataFor(initial));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(puzzleControllerProvider(widget.puzzleId).notifier).playOpponentFirstMove();
    });
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  GameData _gameDataFor(PuzzleAttemptState state) {
    final position = state.position;
    return GameData(
      fen: position.fen,
      playerSide: state.isInteractive
          ? (state.solverSide == Side.white ? PlayerSide.white : PlayerSide.black)
          : PlayerSide.none,
      sideToMove: position.turn,
      validMoves: state.isInteractive ? makeLegalMoves(position) : const {},
      lastMove: state.lastMove,
      kingSquareInCheck: position.isCheck ? position.board.kingOf(position.turn) : null,
    );
  }

  void _pickNextPuzzle(BuildContext context) {
    final repo = ref.read(puzzleRepositoryProvider).value;
    if (repo == null) return;
    final next = repo.randomPuzzle(excludeId: widget.puzzleId);
    if (next == null) return;
    setState(() => _celebrate = false);
    context.pushReplacement('/puzzles/${next.id}');
  }

  String _statusText(PuzzleAttemptState state) {
    final solverLabel = state.solverSide == Side.white ? 'White' : 'Black';
    switch (state.status) {
      case PuzzleStatus.starting:
      case PuzzleStatus.opponentMoving:
        return 'Watch the opponent\'s move…';
      case PuzzleStatus.awaitingPlayerMove:
        return 'Find the best move for $solverLabel';
      case PuzzleStatus.wrongMove:
        return 'Not quite — try again';
      case PuzzleStatus.solved:
        return 'Solved!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = puzzleControllerProvider(widget.puzzleId);
    final boardTheme = Theme.of(context).extension<BoardTheme>() ?? BoardTheme.classic;

    ref.listen<PuzzleAttemptState>(provider, (previous, next) {
      _boardController.updatePosition(_gameDataFor(next), animate: true);
      if (previous?.status != PuzzleStatus.solved && next.status == PuzzleStatus.solved) {
        setState(() => _celebrate = true);
      }
      if (previous?.status != PuzzleStatus.wrongMove && next.status == PuzzleStatus.wrongMove) {
        setState(() => _shakeWrong = !_shakeWrong);
      }
    });

    final state = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: PopBadge(
                  trigger: state.status == PuzzleStatus.solved,
                  child: Text(
                    _statusText(state),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Text('${state.puzzle.rating}', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: ResponsiveBoard(
              builder: (context, size) => CelebrationOverlay(
                trigger: _celebrate,
                child: ShakeOnTrigger(
                  trigger: _shakeWrong,
                  child: Chessboard(
                    size: size,
                    controller: _boardController,
                    orientation: state.solverSide,
                    settings: ChessboardSettings(
                      colorScheme: boardTheme.colorScheme,
                      pieceAssets: boardTheme.pieceAssets,
                      autoQueenPromotion: boardTheme.playful,
                    ),
                    shapes: state.hintSquare == null
                        ? const {}
                        : {
                            Circle(color: Colors.amber.withValues(alpha: 0.8), orig: state.hintSquare!),
                          },
                    onMove: (move, {viaDragAndDrop}) {
                      ref.read(gameFeedbackProvider).move();
                      ref.read(provider.notifier).attemptMove(move);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.isInteractive
                      ? () => ref.read(provider.notifier).showHint()
                      : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hint'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.isSolved
                      ? null
                      : () => ref.read(provider.notifier).showSolution(),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Solution'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickNextPuzzle(context),
                  icon: const Icon(Icons.skip_next_outlined),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
