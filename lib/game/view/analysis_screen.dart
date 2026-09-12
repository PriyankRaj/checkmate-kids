import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/board_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/responsive_board.dart';
import '../controller/game_controller.dart';
import '../model/game_state.dart';
import 'widgets/engine_hint_button.dart';
import 'widgets/move_list.dart';

/// Free-setup analysis board: step through moves for either side and ask
/// the engine for a suggestion at any point.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late final ChessboardController _boardController;
  NormalMove? _hintMove;

  @override
  void initState() {
    super.initState();
    // The analysis controller already starts in passAndPlay mode (equivalent
    // interactivity to analysis — both allow moving either side), so the
    // board can render immediately. Explicitly reset to GameMode.analysis
    // after the first frame — resetting a provider during initState itself
    // is disallowed by Riverpod 3 while the widget tree is still building.
    _boardController = ChessboardController(game: _gameDataFor(ref.read(analysisControllerProvider)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analysisControllerProvider.notifier).startGame(mode: GameMode.analysis);
    });
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  GameData _gameDataFor(GameState state) {
    return GameData(
      fen: state.position.fen,
      playerSide: state.isGameOver ? PlayerSide.none : PlayerSide.both,
      sideToMove: state.sideToMove,
      validMoves: makeLegalMoves(state.position),
      lastMove: state.lastMove,
      kingSquareInCheck:
          state.position.isCheck ? state.position.board.kingOf(state.position.turn) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardTheme = Theme.of(context).extension<BoardTheme>() ?? BoardTheme.classic;

    ref.listen<GameState>(analysisControllerProvider, (previous, next) {
      _boardController.updatePosition(_gameDataFor(next));
      setState(() => _hintMove = null);
    });

    final state = ref.watch(analysisControllerProvider);

    return AppScaffold(
      title: 'Analysis board',
      scrollable: false,
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
          icon: const Icon(Icons.restart_alt),
          tooltip: 'Reset',
          onPressed: () {
            ref.read(analysisControllerProvider.notifier).startGame(mode: GameMode.analysis);
            setState(() => _hintMove = null);
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: ResponsiveBoard(
                builder: (context, size) => Chessboard(
                  size: size,
                  controller: _boardController,
                  orientation: Side.white,
                  settings: ChessboardSettings(
                    colorScheme: boardTheme.colorScheme,
                    pieceAssets: boardTheme.pieceAssets,
                  ),
                  shapes: hintArrowShapes(_hintMove),
                  onMove: (move, {viaDragAndDrop}) {
                    ref.read(gameFeedbackProvider).move();
                    setState(() => _hintMove = null);
                    ref.read(analysisControllerProvider.notifier).playAnyMove(move);
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: EngineHintButton(
              fen: state.position.fen,
              position: state.position,
              enabled: !state.isGameOver,
              onSuggestion: (move) => setState(() => _hintMove = move),
            ),
          ),
        ],
      ),
    );
  }
}
