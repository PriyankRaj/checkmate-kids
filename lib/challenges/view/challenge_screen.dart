import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/board_theme.dart';
import '../../core/theme/kids_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/celebration_overlay.dart';
import '../../core/widgets/responsive_board.dart';
import '../../core/widgets/result_sheet.dart';
import '../../game/view/widgets/engine_hint_button.dart';
import '../controller/challenge_controller.dart';
import '../model/challenge.dart';

/// Renders whichever [Challenge] `challengeId` points to: the right
/// board/UI for its [ChallengeType] while running, and a result banner with
/// the score and whether it's a new best. Kids-themed, per the design note
/// that challenges (like tutorials) are pitched at kids too.
///
/// The challenge starts the instant this screen opens — no separate
/// goal/"Start" gate. The goal text is still available on demand via the
/// AppBar info button.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  ChessboardController? _boardController;
  NormalMove? _hintMove;
  bool _celebrate = false;
  PersistentBottomSheetController? _resultSheet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = challengeControllerProvider(widget.challengeId);
      if (ref.read(provider).phase == ChallengePhase.idle) {
        ref.read(provider.notifier).start();
      }
    });
  }

  GameData _gameDataFor(ChallengeState state) {
    final position = state.position!;
    final interactive = state.phase == ChallengePhase.running && !state.isEngineThinking;
    return GameData(
      fen: position.fen,
      playerSide: interactive ? PlayerSide.white : PlayerSide.none,
      sideToMove: position.turn,
      validMoves: interactive ? makeLegalMoves(position) : const {},
      lastMove: state.lastMove,
      kingSquareInCheck: position.isCheck ? position.board.kingOf(position.turn) : null,
    );
  }

  @override
  void dispose() {
    _boardController?.dispose();
    super.dispose();
  }

  void _onMove(ChallengeController notifier, ChallengeType type, Move move) {
    ref.read(gameFeedbackProvider).move();
    setState(() => _hintMove = null);
    switch (type) {
      case ChallengeType.mateInOneBlitz:
        notifier.submitMateInOneMove(move);
      case ChallengeType.knightHunt:
        notifier.playKnightHuntMove(move);
      case ChallengeType.pawnRace:
        notifier.playPawnRaceMove(move);
      case ChallengeType.survive:
        notifier.playSurviveMove(move);
      case ChallengeType.endgameBoss:
        notifier.playEndgameBossMove(move);
      case ChallengeType.coordinateRush:
      case ChallengeType.blindfoldSteps:
        break;
    }
  }

  void _showGoal(BuildContext context, Challenge challenge) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(challenge.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(challenge.description),
            const SizedBox(height: 12),
            Text('Goal', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(challenge.goal),
          ],
        ),
      ),
    );
  }

  void _showResult(BuildContext context, ChallengeState state, ChallengeController notifier) {
    final success = state.phase == ChallengePhase.success;
    setState(() => _celebrate = success);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resultSheet?.close();
      _resultSheet = showResultSheet(
        scaffoldKey: _scaffoldKey,
        content: ResultSheetContent(
          icon: success ? Icons.celebration_outlined : Icons.refresh_outlined,
          title: success ? 'Nice work!' : 'Out of moves',
          subtitle: '${state.score}${state.challenge.scoreSuffix} ${state.challenge.scoreLabel}'
              '${state.isNewBest ? ' — new best!' : ''}',
          actions: [
            TextButton(onPressed: () => _resultSheet?.close(), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                _resultSheet?.close();
                setState(() => _celebrate = false);
                notifier.retry();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = challengeControllerProvider(widget.challengeId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final challenge = state.challenge;

    ref.listen(provider, (previous, next) {
      if (next.position != null) {
        final controller = _boardController;
        if (controller == null) {
          _boardController = ChessboardController(game: _gameDataFor(next));
        } else {
          final samePositionObject = previous?.position == next.position;
          controller.updatePosition(_gameDataFor(next), animate: !samePositionObject);
        }
      }
      if (previous != null &&
          previous.phase == ChallengePhase.running &&
          next.phase != ChallengePhase.running) {
        _showResult(context, next, notifier);
      }
    });

    return Theme(
      data: buildKidsTheme(),
      child: AppScaffold(
        title: challenge.title,
        scrollable: false,
        scaffoldKey: _scaffoldKey,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Goal',
            onPressed: () => _showGoal(context, challenge),
          ),
        ],
        body: state.phase == ChallengePhase.idle
            ? const Center(child: CircularProgressIndicator())
            : _buildRunning(context, state, notifier),
      ),
    );
  }

  Widget _buildRunning(BuildContext context, ChallengeState state, ChallengeController notifier) {
    final challenge = state.challenge;
    final hintEligible = const {
      ChallengeType.mateInOneBlitz,
      ChallengeType.knightHunt,
      ChallengeType.pawnRace,
      ChallengeType.survive,
      ChallengeType.endgameBoss,
    }.contains(challenge.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusBar(state: state),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: CelebrationOverlay(
              trigger: _celebrate,
              child: switch (challenge.type) {
                ChallengeType.coordinateRush =>
                  _CoordinateRushBoard(state: state, onTap: notifier.tapCoordinateSquare),
                ChallengeType.blindfoldSteps =>
                  _BlindfoldBoard(state: state, onTap: notifier.tapBlindfoldSquare),
                ChallengeType.mateInOneBlitz ||
                ChallengeType.knightHunt ||
                ChallengeType.pawnRace ||
                ChallengeType.survive ||
                ChallengeType.endgameBoss =>
                  _InteractiveBoard(
                    state: state,
                    controller: _boardController,
                    hintShapes: hintArrowShapes(_hintMove),
                    onMove: (move, {viaDragAndDrop}) => _onMove(notifier, challenge.type, move),
                  ),
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              if (state.message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    state.message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              if (state.isEngineThinking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Engine thinking…'),
                    ],
                  ),
                ),
              Row(
                children: [
                  if (hintEligible && state.position != null)
                    Expanded(
                      child: EngineHintButton(
                        fen: state.position!.fen,
                        position: state.position!,
                        enabled: state.phase == ChallengePhase.running && !state.isEngineThinking,
                        onSuggestion: (move) => setState(() => _hintMove = move),
                      ),
                    ),
                  if (challenge.type == ChallengeType.survive) ...[
                    if (hintEligible) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: notifier.resignSurvive,
                        child: const Text('Stop here'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final ChallengeState state;

  @override
  Widget build(BuildContext context) {
    final challenge = state.challenge;
    final chips = <Widget>[];
    if (state.secondsRemaining != null) {
      chips.add(Chip(label: Text('⏱ ${state.secondsRemaining}s')));
    }
    if (challenge.type != ChallengeType.survive && state.movesRemaining != null) {
      chips.add(Chip(label: Text('Moves left: ${state.movesRemaining}')));
    }
    if (challenge.type == ChallengeType.survive) {
      chips.add(Chip(label: Text('Survived: ${state.movesRemaining ?? 0}')));
    }
    chips.add(Chip(label: Text('${challenge.scoreLabel}: ${state.score}')));
    return Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: chips);
  }
}

class _InteractiveBoard extends StatelessWidget {
  const _InteractiveBoard({
    required this.state,
    required this.controller,
    required this.onMove,
    this.hintShapes = const {},
  });

  final ChallengeState state;
  final ChessboardController? controller;
  final Set<Shape> hintShapes;
  final void Function(Move move, {bool? viaDragAndDrop}) onMove;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null || state.position == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final boardTheme = Theme.of(context).extension<BoardTheme>() ?? BoardTheme.kids;
    return ResponsiveBoard(
      builder: (context, size) => Chessboard(
        size: size,
        controller: controller,
        orientation: Side.white,
        settings: ChessboardSettings(
          colorScheme: boardTheme.colorScheme,
          pieceAssets: boardTheme.pieceAssets,
          autoQueenPromotion: true,
        ),
        shapes: hintShapes,
        onMove: onMove,
      ),
    );
  }
}

/// Flashes a square name; the player taps it on a bare board. There's no
/// piece to place, so this uses [StaticChessboard] with an always-empty
/// position rather than the interactive [Chessboard].
class _CoordinateRushBoard extends StatelessWidget {
  const _CoordinateRushBoard({required this.state, required this.onTap});

  final ChallengeState state;
  final void Function(String squareName) onTap;

  @override
  Widget build(BuildContext context) {
    final boardTheme = Theme.of(context).extension<BoardTheme>() ?? BoardTheme.kids;
    final highlights = <Square, SquareHighlight>{};
    final tapped = state.lastTappedSquareName;
    if (tapped != null) {
      final color = (state.lastTapWasCorrect ?? false) ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5);
      highlights[Square.fromName(tapped)] = SquareHighlight(details: HighlightDetails(solidColor: color));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          state.targetSquareName?.toUpperCase() ?? '',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ResponsiveBoard(
          builder: (context, size) => StaticChessboard(
            size: size,
            orientation: Side.white,
            fen: kEmptyFEN,
            settings: StaticChessboardSettings(colorScheme: boardTheme.colorScheme),
            squareHighlights: highlights,
            onTouchedSquare: (square) => onTap(square.name),
          ),
        ),
      ],
    );
  }
}

/// Plays back a move sequence from the start position, then hides the board
/// and lets the player tap the same from/to squares from memory.
class _BlindfoldBoard extends StatelessWidget {
  const _BlindfoldBoard({required this.state, required this.onTap});

  final ChallengeState state;
  final void Function(Square square) onTap;

  @override
  Widget build(BuildContext context) {
    final boardTheme = Theme.of(context).extension<BoardTheme>() ?? BoardTheme.kids;
    if (!state.showBoard) {
      return ResponsiveBoard(
        builder: (context, size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(boardTheme.cardRadius),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
            itemCount: 64,
            itemBuilder: (context, index) {
              final file = index % 8;
              final rank = 7 - index ~/ 8;
              final square = Square.fromCoords(File(file), Rank(rank));
              return GestureDetector(
                onTap: () => onTap(square),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  color: state.recallInput.contains(square.name)
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              );
            },
          ),
        ),
      );
    }
    return ResponsiveBoard(
      builder: (context, size) => StaticChessboard(
        size: size,
        orientation: Side.white,
        fen: state.position?.fen ?? kInitialFEN,
        lastMove: state.lastMove,
        settings: StaticChessboardSettings(colorScheme: boardTheme.colorScheme, pieceAssets: boardTheme.pieceAssets),
      ),
    );
  }
}
