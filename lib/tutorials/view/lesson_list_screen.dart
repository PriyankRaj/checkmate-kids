import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kids_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../profile/controller/progress_controller.dart';
import '../data/lesson_repository.dart';
import '../model/lesson.dart';

/// The kids' tutorial track: an ordered list of beginner chess lessons with
/// a star for each one already completed.
class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonRepositoryProvider);
    final completedIds = ref.watch(
      progressControllerProvider.select((progress) => progress.completedLessonIds),
    );

    return Theme(
      data: buildKidsTheme(),
      child: AppScaffold(
        title: "Let's Learn Chess!",
        body: lessonsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('Could not load lessons: $error')),
          ),
          data: (repository) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick a lesson and learn a new chess skill!',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (final lesson in repository.lessons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LessonTile(
                    lesson: lesson,
                    completed: completedIds.contains(lesson.id),
                    onTap: () => context.push('/lessons/${lesson.id}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.completed, required this.onTap});

  final Lesson lesson;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: completed ? Colors.amber : colorScheme.primaryContainer,
                child: Text(
                  '${lesson.order}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: completed ? Colors.white : colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(lesson.summary, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                completed ? Icons.star_rounded : Icons.chevron_right_rounded,
                color: completed ? Colors.amber : colorScheme.outline,
                size: completed ? 32 : 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
