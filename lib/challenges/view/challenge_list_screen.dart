import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kids_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../profile/controller/progress_controller.dart';
import '../data/challenge_repository.dart';
import '../model/challenge.dart';

/// Kids-themed landing page listing every [Challenge], each with the
/// player's current best score. Tapping one pushes `/challenges/:id`.
class ChallengeListScreen extends ConsumerWidget {
  const ChallengeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(challengeRepositoryProvider);
    final progress = ref.watch(progressControllerProvider);

    return Theme(
      data: buildKidsTheme(),
      child: AppScaffold(
        title: 'Challenges',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick timed drills to sharpen your skills.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            for (final challenge in challenges) ...[
              _ChallengeTile(
                challenge: challenge,
                bestScore: progress.challengeBestScores[challenge.id],
                onTap: () => context.push('/challenges/${challenge.id}'),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.challenge, required this.bestScore, required this.onTap});

  final Challenge challenge;
  final int? bestScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bestScore == null
                          ? 'Not attempted yet'
                          : 'Best: $bestScore${challenge.scoreSuffix} ${challenge.scoreLabel}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
