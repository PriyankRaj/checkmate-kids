/// A single time control: [initial] time per side plus a per-move
/// [increment], both in seconds. `null` means untimed.
class TimeControl {
  const TimeControl({required this.initialSeconds, required this.incrementSeconds});

  final int initialSeconds;
  final int incrementSeconds;

  static const bullet = TimeControl(initialSeconds: 60, incrementSeconds: 0);
  static const blitz = TimeControl(initialSeconds: 300, incrementSeconds: 3);
  static const rapid = TimeControl(initialSeconds: 600, incrementSeconds: 5);
  static const classical = TimeControl(initialSeconds: 1800, incrementSeconds: 10);

  static const List<TimeControl> presets = [bullet, blitz, rapid, classical];

  String get label {
    final minutes = initialSeconds ~/ 60;
    final seconds = initialSeconds % 60;
    final base = seconds == 0 ? '$minutes min' : '${initialSeconds}s';
    return incrementSeconds == 0 ? base : '$base + $incrementSeconds';
  }

  /// Value equality — needed so a [TimeControl] reconstructed from storage
  /// (e.g. `AppSettings.fromJson`) still matches one of [presets] for chip
  /// selection, even though it isn't the same const instance.
  @override
  bool operator ==(Object other) =>
      other is TimeControl &&
      other.initialSeconds == initialSeconds &&
      other.incrementSeconds == incrementSeconds;

  @override
  int get hashCode => Object.hash(initialSeconds, incrementSeconds);
}

/// Remaining time for both sides, in whole seconds. Immutable — every tick
/// or increment produces a new [ClockState].
class ClockState {
  const ClockState({
    required this.whiteRemaining,
    required this.blackRemaining,
    this.increment = 0,
  });

  final int whiteRemaining;
  final int blackRemaining;
  final int increment;

  factory ClockState.fromTimeControl(TimeControl tc) => ClockState(
        whiteRemaining: tc.initialSeconds,
        blackRemaining: tc.initialSeconds,
        increment: tc.incrementSeconds,
      );

  bool get whiteFlagged => whiteRemaining <= 0;
  bool get blackFlagged => blackRemaining <= 0;

  ClockState tick(bool whiteToMove) {
    if (whiteToMove) {
      return ClockState(
        whiteRemaining: whiteRemaining - 1,
        blackRemaining: blackRemaining,
        increment: increment,
      );
    }
    return ClockState(
      whiteRemaining: whiteRemaining,
      blackRemaining: blackRemaining - 1,
      increment: increment,
    );
  }

  ClockState applyIncrement(bool whiteJustMoved) {
    if (increment == 0) return this;
    if (whiteJustMoved) {
      return ClockState(
        whiteRemaining: whiteRemaining + increment,
        blackRemaining: blackRemaining,
        increment: increment,
      );
    }
    return ClockState(
      whiteRemaining: whiteRemaining,
      blackRemaining: blackRemaining + increment,
      increment: increment,
    );
  }
}
