import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../engine/difficulty.dart';
import '../controller/game_controller.dart';
import '../model/clock.dart';
import '../model/game_state.dart';

/// Lets the player change the saved game defaults (see
/// `SettingsController`) — reached via the settings icon on `GameScreen`.
/// Starting a game here also updates those defaults, so next time "Play"
/// is tapped from Home it starts with these same settings, no asking.
class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({super.key});

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  late GameMode _mode;
  late Side _humanSide;
  late Difficulty _difficulty;
  late TimeControl? _timeControl;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      final settings = ref.read(settingsControllerProvider);
      _mode = settings.gameMode;
      _humanSide = settings.humanSide;
      _difficulty = settings.difficulty;
      _timeControl = settings.timeControl;
      _initialized = true;
    }
    return AppScaffold(
      title: 'New game',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<GameMode>(
            segments: const [
              ButtonSegment(value: GameMode.vsComputer, label: Text('vs Computer')),
              ButtonSegment(value: GameMode.passAndPlay, label: Text('Pass & Play')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 24),
          if (_mode == GameMode.vsComputer) ...[
            Text('Your side', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<Side>(
              segments: const [
                ButtonSegment(value: Side.white, label: Text('White')),
                ButtonSegment(value: Side.black, label: Text('Black')),
              ],
              selected: {_humanSide},
              onSelectionChanged: (s) => setState(() => _humanSide = s.first),
            ),
            const SizedBox(height: 24),
            Text('Difficulty', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RadioGroup<Difficulty>(
              groupValue: _difficulty,
              onChanged: (value) => setState(() => _difficulty = value!),
              child: Column(
                children: Difficulty.values.map((d) {
                  final profile = difficultyProfiles[d]!;
                  return RadioListTile<Difficulty>(
                    value: d,
                    title: Text(profile.label),
                    subtitle: Text(profile.description),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('Time control', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Untimed'),
                selected: _timeControl == null,
                onSelected: (_) => setState(() => _timeControl = null),
              ),
              ...TimeControl.presets.map((tc) => ChoiceChip(
                    label: Text(tc.label),
                    selected: _timeControl == tc,
                    onSelected: (_) => setState(() => _timeControl = tc),
                  )),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              ref.read(settingsControllerProvider.notifier).updateGameDefaults(
                    mode: _mode,
                    humanSide: _humanSide,
                    difficulty: _difficulty,
                    timeControl: _timeControl,
                  );
              ref.read(gameControllerProvider.notifier).startGame(
                    mode: _mode,
                    humanSide: _humanSide,
                    difficulty: _mode == GameMode.vsComputer ? _difficulty : null,
                    timeControl: _timeControl,
                  );
              context.push('/play/board');
            },
            child: const Text('Start game'),
          ),
        ],
      ),
    );
  }
}
