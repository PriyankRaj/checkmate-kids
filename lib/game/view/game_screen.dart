import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/board_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/celebration_overlay.dart';
import '../../core/widgets/responsive_board.dart';
import '../../core/widgets/result_sheet.dart';
import '../controller/game_controller.dart';
import '../model/game_state.dart';
import 'widgets/clock_view.dart';
import 'widgets/engine_hint_button.dart';
import 'widgets/move_list.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ChessboardController _boardController;
  Side _orientation = Side.white;
  NormalMove? _hintMove;
  bool _celebrate = false;
  PersistentBottomSheetController? _resultSheet;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(gameControllerProvider);
    _orientation = initial.mode == GameMode.vsComputer ? initial.humanSide : Side.white;
    _boardController = ChessboardController(game: _gameDataFor(initial));
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  GameData _gameDataFor(GameState state) {
    final playerSide = switch (state.mode) {
      GameMode.vsComputer =>
        state.humanSide == Side.white ? PlayerSide.white : PlayerSide.black,
      GameMode.passAndPlay || GameMode.analysis => PlayerSide.both,
    };
    return GameData(
      fen: state.position.fen,
      playerSide: state.isGameOver || state.isEngineThinking ? PlayerSide.none : playerSide,
      sideToMove: state.sideToMove,
      validMoves: makeLegalMoves(state.position),
      lastMove: state.lastMove,
      kingSquareInCheck:
          state.position.isCheck ? state.position.board.kingOf(state.position.turn) : null,
    );
  }

  bool _humanWon(GameState state, String description) {
    if (state.mode != GameMode.vsComputer) return !description.startsWith('Draw');
    final humanIsWhite = state.humanSide == Side.white;
    return description.contains(humanIsWhite ? 'White wins' : 'Black wins');
  }

  void _showResult(GameState state) {
    final description = state.resultDescription;
    if (description == null) return;
    final isDraw = description.startsWith('Draw');
    final won = _humanWon(state, description);

    final feedback = ref.read(gameFeedbackProvider);
    if (isDraw) {
      feedback.success();
    } else if (won) {
      feedback.win();
    } else {
      feedback.lose();
    }
    setState(() => _celebrate = won);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resultSheet?.close();
      _resultSheet = showResultSheet(
        scaffoldKey: _scaffoldKey,
        content: ResultSheetContent(
          icon: won ? Icons.emoji_events : (isDraw ? Icons.handshake_outlined : Icons.flag_outlined),
          title: won ? 'You won!' : (isDraw ? 'Draw' : 'Game over'),
          subtitle: description,
          actions: [
            TextButton(onPressed: () => _resultSheet?.close(), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                _resultSheet?.close();
                setState(() => _celebrate = false);
                ref.read(gameControllerProvider.notifier).startGame(
                      mode: state.mode,
                      humanSide: state.humanSide,
                      difficulty: state.difficulty,
                      timeControl: state.timeControl,
                    );
              },
              child: const Text('Rematch'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardTheme = Theme.of(context).extension<BoardTheme>() ?? BoardTheme.classic;

    ref.listen<GameState>(gameControllerProvider, (previous, next) {
      _boardController.updatePosition(_gameDataFor(next));
      if (previous != null && next.history.length != previous.history.length) {
        setState(() => _hintMove = null);
      }
      if (previous != null && next.isGameOver && !previous.isGameOver) {
        _showResult(next);
      }
    });

    final state = ref.watch(gameControllerProvider);

    return AppScaffold(
      title: 'Play',
      scrollable: false,
      scaffoldKey: _scaffoldKey,
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Move history',
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: MoveList(history: state.history),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.flip_camera_android_outlined),
          tooltip: 'Flip board',
          onPressed: () => setState(() {
            _orientation = _orientation == Side.white ? Side.black : Side.white;
          }),
        ),
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: 'Game settings',
          onPressed: () => context.push('/play'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.clock != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClockView(clock: state.clock!, whiteToMove: state.sideToMove == Side.white),
            )
          else
            _StatusStrip(state: state),
          Expanded(
            child: Center(
              child: ResponsiveBoard(
                builder: (context, size) => CelebrationOverlay(
                  trigger: _celebrate,
                  child: Chessboard(
                    size: size,
                    controller: _boardController,
                    orientation: _orientation,
                    settings: ChessboardSettings(
                      colorScheme: boardTheme.colorScheme,
                      pieceAssets: boardTheme.pieceAssets,
                      autoQueenPromotion: boardTheme.playful,
                    ),
                    shapes: hintArrowShapes(_hintMove),
                    onMove: (move, {viaDragAndDrop}) {
                      ref.read(gameFeedbackProvider).move();
                      setState(() => _hintMove = null);
                      ref.read(gameControllerProvider.notifier).playHumanMove(move);
                    },
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
                  child: EngineHintButton(
                    fen: state.position.fen,
                    position: state.position,
                    enabled: state.isHumanTurn && !state.isGameOver && !state.isEngineThinking,
                    onSuggestion: (move) => setState(() => _hintMove = move),
                  ),
                ),
                if (state.isEngineThinking) ...[
                  const SizedBox(width: 12),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  const Text('Thinking…'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state.mode) {
      GameMode.vsComputer =>
        state.isEngineThinking ? 'Computer is thinking…' : 'Your move',
      GameMode.passAndPlay =>
        "${state.sideToMove == Side.white ? 'White' : 'Black'} to move",
      GameMode.analysis => 'Analysis',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
