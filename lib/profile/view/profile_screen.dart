import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../challenges/data/challenge_repository.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../tutorials/data/lesson_repository.dart';
import '../controller/progress_controller.dart';

/// Profile / stats screen. Ambient (classic) theme — profile is neutral,
/// unlike the kids-themed challenges/tutorials screens.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressControllerProvider);
    final challenges = ref.watch(challengeRepositoryProvider);
    final lessonsAsync = ref.watch(lessonRepositoryProvider);
    final totalLessons = lessonsAsync.maybeWhen(data: (repo) => repo.lessons.length, orElse: () => null);

    final challengesById = {for (final c in challenges) c.id: c};

    return AppScaffold(
      title: 'Profile',
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Third-party notices',
          onPressed: () => _showThirdPartyNotices(context),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.military_tech_outlined,
                  label: 'Puzzle rating',
                  value: '${progress.puzzleRating}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.extension_outlined,
                  label: 'Puzzles solved',
                  value: '${progress.solvedPuzzleIds.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.child_care_outlined,
            label: 'Lessons completed',
            value: totalLessons != null
                ? '${progress.completedLessonIds.length} / $totalLessons'
                : '${progress.completedLessonIds.length}',
          ),
          const SizedBox(height: 20),
          Text('Challenge best scores', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (progress.challengeBestScores.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No challenges attempted yet — head over and give one a try!'),
              ),
            )
          else
            for (final entry in progress.challengeBestScores.entries)
              Card(
                child: ListTile(
                  title: Text(challengesById[entry.key]?.title ?? entry.key),
                  trailing: Text(
                    '${entry.value}${challengesById[entry.key]?.scoreSuffix ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(challengesById[entry.key]?.scoreLabel ?? 'score'),
                ),
              ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () => _rateWithParentalGate(context),
              icon: const Icon(Icons.star_outline),
              label: const Text('Grown-ups: rate Checkmate Kids'),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => _showThirdPartyNotices(context),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Third-party notices'),
            ),
          ),
        ],
      ),
    );
  }

  /// The audience is 6–12, so the rating link never fires on its own and
  /// sits behind a simple grown-up check before it leaves the app.
  Future<void> _rateWithParentalGate(BuildContext context) async {
    final passed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ParentalGateDialog(),
    );
    if (passed != true) return;
    try {
      await InAppReview.instance.openStoreListing(appStoreId: '6812977406');
    } catch (e) {
      debugPrint('openStoreListing failed: $e');
    }
  }

  void _showThirdPartyNotices(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Third-party notices'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Checkmate Kids is built on the following open-source projects, '
                'all licensed under the GNU General Public License v3.0 (GPL-3.0):',
              ),
              SizedBox(height: 12),
              _NoticeEntry(name: 'dartchess', note: 'Chess rules engine and move generation.'),
              _NoticeEntry(name: 'chessground', note: 'The interactive chessboard widget.'),
              _NoticeEntry(name: 'stockfish', note: 'The chess engine used for computer opponents and hints.'),
              SizedBox(height: 12),
              Text(
                'Source code for each project is available under the same GPL-3.0 '
                'license from its respective project page.',
              ),
              SizedBox(height: 12),
              Text(
                'Sound effects: "Interface Sounds" by Kenney (kenney.nl), '
                'licensed CC0 1.0 (public domain).',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _NoticeEntry extends StatelessWidget {
  const _NoticeEntry({required this.name, required this.note});

  final String name;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name — GPL-3.0', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(note),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ParentalGateDialog extends StatefulWidget {
  const _ParentalGateDialog();

  @override
  State<_ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<_ParentalGateDialog> {
  final _rng = Random();
  late final int _a = 6 + _rng.nextInt(7);
  late final int _b = 6 + _rng.nextInt(7);
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (int.tryParse(_controller.text.trim()) == _a * _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grown-ups only'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('To continue, what is $_a × $_b?'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(errorText: _wrong ? 'Not quite — try again' : null),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _check, child: const Text('Continue')),
      ],
    );
  }
}
