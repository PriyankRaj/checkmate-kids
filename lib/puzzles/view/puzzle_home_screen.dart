import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../profile/controller/progress_controller.dart';
import '../data/puzzle_repository.dart';
import '../model/puzzle.dart';

/// (label, minRating, maxRating-or-null-for-open-ended)
const _ratingBands = <(String, int, int?)>[
  ('400-800', 400, 800),
  ('800-1200', 800, 1200),
  ('1200-1600', 1200, 1600),
  ('1600-2000', 1600, 2000),
  ('2000-2400', 2000, 2400),
  ('2400+', 2400, null),
];

const _themeFilters = <String>[
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

/// Browse/filter screen for puzzles: rating band + theme chips, current
/// puzzle rating and solved count, and a list of matching puzzles.
///
/// Changing a filter here also updates the saved puzzle defaults (see
/// `SettingsController`), so the next time "Puzzles" is tapped from Home it
/// jumps straight into a matching puzzle without asking.
class PuzzleHomeScreen extends ConsumerStatefulWidget {
  const PuzzleHomeScreen({super.key});

  @override
  ConsumerState<PuzzleHomeScreen> createState() => _PuzzleHomeScreenState();
}

class _PuzzleHomeScreenState extends ConsumerState<PuzzleHomeScreen> {
  int? _selectedBandIndex;
  String? _selectedTheme;
  bool _initialized = false;

  void _persistDefaults() {
    final band = _selectedBandIndex != null ? _ratingBands[_selectedBandIndex!] : null;
    ref.read(settingsControllerProvider.notifier).updatePuzzleDefaults(
          minRating: band?.$2,
          maxRating: band?.$3,
          theme: _selectedTheme,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      final settings = ref.read(settingsControllerProvider);
      _selectedBandIndex = _ratingBands.indexWhere(
        (band) => band.$2 == settings.puzzleMinRating && band.$3 == settings.puzzleMaxRating,
      );
      if (_selectedBandIndex == -1) _selectedBandIndex = null;
      _selectedTheme = settings.puzzleTheme;
      _initialized = true;
    }
    final repoAsync = ref.watch(puzzleRepositoryProvider);
    final progress = ref.watch(progressControllerProvider);

    return AppScaffold(
      title: 'Puzzles',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Puzzle rating', style: Theme.of(context).textTheme.labelMedium),
                        Text('${progress.puzzleRating}', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solved', style: Theme.of(context).textTheme.labelMedium),
                        Text(
                          '${progress.solvedPuzzleIds.length}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Rating', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _ratingBands.length; i++)
                ChoiceChip(
                  label: Text(_ratingBands[i].$1),
                  selected: _selectedBandIndex == i,
                  onSelected: (selected) {
                    setState(() => _selectedBandIndex = selected ? i : null);
                    _persistDefaults();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Theme', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in _themeFilters)
                ChoiceChip(
                  label: Text(theme),
                  selected: _selectedTheme == theme,
                  onSelected: (selected) {
                    setState(() => _selectedTheme = selected ? theme : null);
                    _persistDefaults();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          repoAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Could not load puzzles: $error')),
            ),
            data: (repo) => _PuzzleList(
              puzzles: _filtered(repo.all),
              solvedIds: progress.solvedPuzzleIds,
            ),
          ),
        ],
      ),
    );
  }

  List<Puzzle> _filtered(List<Puzzle> puzzles) {
    final band = _selectedBandIndex != null ? _ratingBands[_selectedBandIndex!] : null;
    return puzzles.where((p) {
      if (band != null) {
        final (_, min, max) = band;
        if (p.rating < min || (max != null && p.rating >= max)) return false;
      }
      if (_selectedTheme != null && !p.themes.contains(_selectedTheme)) return false;
      return true;
    }).toList();
  }
}

class _PuzzleList extends StatelessWidget {
  const _PuzzleList({required this.puzzles, required this.solvedIds});

  final List<Puzzle> puzzles;
  final Set<String> solvedIds;

  @override
  Widget build(BuildContext context) {
    if (puzzles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No puzzles match those filters.')),
      );
    }
    return Column(
      children: [
        for (final puzzle in puzzles.take(200))
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  solvedIds.contains(puzzle.id) ? Icons.check : Icons.extension_outlined,
                ),
              ),
              title: Text('Puzzle ${puzzle.id} · ${puzzle.rating}'),
              subtitle: Text(puzzle.themes.take(4).join(', ')),
              onTap: () => context.push('/puzzles/${puzzle.id}'),
            ),
          ),
      ],
    );
  }
}
