import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/game_feedback.dart';
import '../../profile/controller/progress_controller.dart';
import '../model/lesson.dart';

/// Feedback shown to the child after they attempt a move on a [MoveStep].
enum StepFeedback {
  /// No attempt has been made yet (or feedback has been cleared).
  none,

  /// The last attempt matched one of the step's expected moves.
  correct,

  /// The last attempt didn't match — show a gentle "try again".
  retry,
}

/// Snapshot of where a child is within one [Lesson] play-through.
class LessonSessionState {
  const LessonSessionState({
    required this.lesson,
    required this.stepIndex,
    this.feedback = StepFeedback.none,
    this.hintRevealed = false,
    this.completed = false,
  });

  factory LessonSessionState.initial(Lesson lesson) =>
      LessonSessionState(lesson: lesson, stepIndex: 0);

  final Lesson lesson;
  final int stepIndex;
  final StepFeedback feedback;
  final bool hintRevealed;

  /// True once the child has finished the lesson's last step.
  final bool completed;

  LessonStep get currentStep => lesson.steps[stepIndex];
  bool get isLastStep => stepIndex == lesson.steps.length - 1;
  int get stepNumber => stepIndex + 1;
  int get totalSteps => lesson.steps.length;

  LessonSessionState copyWith({
    int? stepIndex,
    StepFeedback? feedback,
    bool? hintRevealed,
    bool? completed,
  }) {
    return LessonSessionState(
      lesson: lesson,
      stepIndex: stepIndex ?? this.stepIndex,
      feedback: feedback ?? this.feedback,
      hintRevealed: hintRevealed ?? this.hintRevealed,
      completed: completed ?? this.completed,
    );
  }
}

/// Drives a single [Lesson] play-through: current step, live feedback, and
/// marking the lesson complete in [progressControllerProvider] once the
/// child finishes the last step.
///
/// Parameterized per lesson via `.family`, keyed by the already-loaded
/// [Lesson] object (see `LessonRepository` — the view awaits the repository
/// before ever building this controller, so there's no need for the
/// controller itself to know how to load lesson data).
class LessonController extends Notifier<LessonSessionState> {
  LessonController(this.lesson);

  final Lesson lesson;

  @override
  LessonSessionState build() => LessonSessionState.initial(lesson);

  /// Reveals the hint arrow/circle for the current move step.
  void revealHint() {
    state = state.copyWith(hintRevealed: true);
  }

  /// Called by the view when the child plays [move] on an interactive
  /// [MoveStep] board. Sets [StepFeedback.correct] or [StepFeedback.retry]
  /// depending on whether it matches one of the step's expected moves.
  void submitMove(Move move) {
    final step = state.currentStep;
    if (step is! MoveStep) return;
    final isCorrect = step.expectedUci.contains(move.uci);
    state = state.copyWith(feedback: isCorrect ? StepFeedback.correct : StepFeedback.retry);
    isCorrect ? ref.read(gameFeedbackProvider).success() : ref.read(gameFeedbackProvider).wrongMove();
  }

  /// Clears a transient [StepFeedback.retry] so the board becomes
  /// interactive again for another attempt.
  void clearFeedback() {
    state = state.copyWith(feedback: StepFeedback.none);
  }

  /// Advances past an [InfoStep], or past a [MoveStep] once
  /// [StepFeedback.correct] has been shown. On the last step, marks the
  /// lesson completed instead of advancing further.
  void advance() {
    if (state.isLastStep) {
      if (!state.completed) {
        ref.read(progressControllerProvider.notifier).markLessonCompleted(lesson.id);
        ref.read(gameFeedbackProvider).win();
      }
      state = state.copyWith(completed: true, feedback: StepFeedback.none);
      return;
    }
    state = state.copyWith(
      stepIndex: state.stepIndex + 1,
      feedback: StepFeedback.none,
      hintRevealed: false,
    );
  }
}

final lessonControllerProvider =
    NotifierProvider.family<LessonController, LessonSessionState, Lesson>(
  (lesson) => LessonController(lesson),
);
