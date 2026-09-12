import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tactile + audio feedback for the whole app. One [AudioPlayer] in
/// [PlayerMode.lowLatency] (fire-and-forget, no seeking/position events —
/// exactly what a short repeated UI sound effect needs) shared across every
/// call so overlapping cues (e.g. a move immediately followed by a check)
/// don't spin up new players.
///
/// Sound files are CC0 (Kenney "Interface Sounds") — see
/// assets/sounds/LICENSE-kenney.txt.
class GameFeedback {
  final AudioPlayer _player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  Future<void> _play(String asset) async {
    try {
      await _player.play(AssetSource('sounds/$asset'));
    } catch (_) {
      // Audio is a nice-to-have; never let a playback failure break gameplay.
    }
  }

  /// A generic UI tap (menu buttons, chip selection).
  void tap() {
    HapticFeedback.selectionClick();
    _play('tap.wav');
  }

  /// A piece move landing on the board.
  void move() {
    HapticFeedback.lightImpact();
    _play('tap.wav');
  }

  /// An invalid/incorrect move or answer (puzzle, lesson, challenge).
  void wrongMove() {
    HapticFeedback.heavyImpact();
    _play('error.wav');
  }

  /// A correct move/answer that isn't the final win (puzzle solved, lesson
  /// step correct, challenge point scored).
  void success() {
    HapticFeedback.mediumImpact();
    _play('success.wav');
  }

  /// The big win moment: checkmate, puzzle set complete, challenge won,
  /// lesson finished.
  void win() {
    HapticFeedback.heavyImpact();
    _play('win.wav');
  }

  /// A loss or a challenge run ending in failure.
  void lose() {
    HapticFeedback.heavyImpact();
    _play('error.wav');
  }

  void dispose() {
    _player.dispose();
  }
}

final gameFeedbackProvider = Provider<GameFeedback>((ref) {
  final feedback = GameFeedback();
  ref.onDispose(feedback.dispose);
  return feedback;
}, name: 'gameFeedbackProvider');
