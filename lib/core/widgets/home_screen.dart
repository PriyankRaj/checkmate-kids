import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/settings_controller.dart';
import '../../game/controller/game_controller.dart';
import '../../game/model/game_state.dart';
import '../../puzzles/data/puzzle_repository.dart';
import 'feature_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Starts a game immediately using the saved defaults (see
  /// `SettingsController`) — no config screen first. Change defaults via
  /// the settings icon on the Play screen.
  void _quickPlay(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsControllerProvider);
    ref.read(gameControllerProvider.notifier).startGame(
          mode: settings.gameMode,
          humanSide: settings.humanSide,
          difficulty: settings.gameMode == GameMode.vsComputer ? settings.difficulty : null,
          timeControl: settings.timeControl,
        );
    context.push('/play/board');
  }

  /// Jumps straight into a puzzle matching the saved default filter — no
  /// browse screen first. Change the filter via the icon on the puzzle
  /// screen, which opens the browse screen.
  Future<void> _quickPuzzle(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsControllerProvider);
    final repo = await ref.read(puzzleRepositoryProvider.future);
    final puzzle = repo.randomPuzzle(
      theme: settings.puzzleTheme,
      minRating: settings.puzzleMinRating,
      maxRating: settings.puzzleMaxRating,
    );
    if (puzzle == null || !context.mounted) return;
    context.push('/puzzles/${puzzle.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkmate Kids'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                Text(
                  'Learn, practice, and play chess.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FeatureCard(
                  title: 'Play',
                  subtitle: 'Challenge the computer or pass and play',
                  icon: Icons.smart_toy_outlined,
                  color: Colors.indigo,
                  onTap: () => _quickPlay(context, ref),
                ),
                const SizedBox(height: 12),
                FeatureCard(
                  title: 'Puzzles',
                  subtitle: 'Solve real tactics, sorted by theme and rating',
                  icon: Icons.extension_outlined,
                  color: Colors.teal,
                  onTap: () => _quickPuzzle(context, ref),
                ),
                const SizedBox(height: 12),
                FeatureCard(
                  title: 'Learn to play',
                  subtitle: 'Guided lessons for brand-new players',
                  icon: Icons.child_care_outlined,
                  color: Colors.deepOrange,
                  onTap: () => context.push('/lessons'),
                ),
                const SizedBox(height: 12),
                FeatureCard(
                  title: 'Challenges',
                  subtitle: 'Quick timed drills to sharpen your skills',
                  icon: Icons.emoji_events_outlined,
                  color: Colors.amber.shade800,
                  onTap: () => context.push('/challenges'),
                ),
                const SizedBox(height: 12),
                FeatureCard(
                  title: 'Analysis board',
                  subtitle: 'Set up any position and get engine suggestions',
                  icon: Icons.insights_outlined,
                  color: Colors.blueGrey,
                  onTap: () => context.push('/play/analysis'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
