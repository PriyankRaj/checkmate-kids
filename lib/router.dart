import 'package:go_router/go_router.dart';

import 'challenges/view/challenge_list_screen.dart';
import 'challenges/view/challenge_screen.dart';
import 'core/widgets/home_screen.dart';
import 'game/view/analysis_screen.dart';
import 'game/view/game_screen.dart';
import 'game/view/new_game_screen.dart';
import 'profile/view/profile_screen.dart';
import 'puzzles/view/puzzle_home_screen.dart';
import 'puzzles/view/puzzle_screen.dart';
import 'tutorials/view/lesson_list_screen.dart';
import 'tutorials/view/lesson_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/play',
      builder: (context, state) => const NewGameScreen(),
      routes: [
        GoRoute(path: 'board', builder: (context, state) => const GameScreen()),
        GoRoute(path: 'analysis', builder: (context, state) => const AnalysisScreen()),
      ],
    ),
    GoRoute(
      path: '/puzzles',
      builder: (context, state) => const PuzzleHomeScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) => PuzzleScreen(puzzleId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/lessons',
      builder: (context, state) => const LessonListScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) => LessonScreen(lessonId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/challenges',
      builder: (context, state) => const ChallengeListScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) => ChallengeScreen(challengeId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
  ],
);
