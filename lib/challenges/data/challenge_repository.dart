import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../model/challenge.dart';

/// Hand-authored, `dartchess`-validated mate-in-1 positions for
/// [ChallengeType.mateInOneBlitz]. Every position here is checked against
/// `dartchess` in `test/challenge_data_test.dart`: at least one legal move
/// from the position must deliver checkmate. The controller doesn't store a
/// single "intended" solution — any legal move that results in checkmate
/// counts as solving the puzzle, which is simpler and more forgiving than
/// requiring one specific move.
const mateInOneFenPool = <String>[
  // Back-rank mate: 1.Re1-e8#
  '6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1',
  // Back-rank mate: 1.Rf1-f8#
  '2k5/1ppp4/8/8/8/8/8/5R1K w - - 0 1',
  // Back-rank mate: 1.Rh1-h8#
  '5k2/4ppp1/8/8/8/8/8/K6R w - - 0 1',
  // Back-rank mate: 1.Re1-e8#
  '1k6/ppp5/8/8/8/8/8/4R2K w - - 0 1',
  // Queen mate defended by the king: 1.Qg1-g7#
  '7k/5K2/8/8/8/8/8/6Q1 w - - 0 1',
  // Smothered mate: 1.Nd6-f7#
  '6rk/6pp/3N4/8/8/8/8/K7 w - - 0 1',
];

/// The fixed list of challenges. Hand-authored here (rather than JSON assets)
/// since there are few of them and they rarely change; see `Challenge` for
/// what each field means per [ChallengeType].
final challengeRepository = <Challenge>[
  const Challenge(
    id: 'mate-in-one-blitz',
    title: 'Mate in One Blitz',
    description: 'A rotating set of real checkmate-in-one positions.',
    goal: 'Find checkmate in one move as many times as you can in 60 seconds.',
    type: ChallengeType.mateInOneBlitz,
    higherIsBetter: true,
    scoreLabel: 'puzzles solved',
    timeLimitSeconds: 60,
    fenPool: mateInOneFenPool,
  ),
  const Challenge(
    id: 'coordinate-rush',
    title: 'Coordinate Rush',
    description: 'Name a square, find it fast.',
    goal: 'Tap the flashed square as many times as you can in 60 seconds.',
    type: ChallengeType.coordinateRush,
    higherIsBetter: true,
    scoreLabel: 'correct taps',
    timeLimitSeconds: 60,
  ),
  const Challenge(
    id: 'knight-hunt',
    title: 'Knight Hunt',
    description: 'A lone knight versus a field of pawns.',
    goal: 'Capture every pawn before you run out of moves.',
    type: ChallengeType.knightHunt,
    higherIsBetter: true,
    scoreLabel: 'moves remaining',
    startFen: '7k/8/1p1p1p2/8/3N4/2p2p2/8/K7 w - - 0 1',
    moveBudget: 12,
  ),
  const Challenge(
    id: 'pawn-race',
    title: 'Pawn Race',
    description: 'One pawn, one goal: the eighth rank.',
    goal: 'Promote your pawn before you run out of moves.',
    type: ChallengeType.pawnRace,
    higherIsBetter: false,
    scoreLabel: 'moves taken',
    startFen: '7k/8/8/8/8/8/1P6/K7 w - - 0 1',
    moveBudget: 7,
  ),
  const Challenge(
    id: 'survive',
    title: 'Survive',
    description: "You're down a queen, two bishops, and two knights.",
    goal: 'Survive as many moves as you can against the engine.',
    type: ChallengeType.survive,
    higherIsBetter: true,
    scoreLabel: 'moves survived',
    startFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPP2PPP/R3K2R w - - 0 1',
    difficulty: Difficulty.strong,
  ),
  const Challenge(
    id: 'endgame-boss',
    title: 'Endgame Boss',
    description: 'King and rook versus a lone, running king.',
    goal: 'Checkmate the engine before you run out of moves.',
    type: ChallengeType.endgameBoss,
    higherIsBetter: false,
    scoreLabel: 'moves taken',
    startFen: '8/8/8/4k3/8/8/8/R3K3 w - - 0 1',
    moveBudget: 30,
    difficulty: Difficulty.club,
  ),
  const Challenge(
    id: 'blindfold-steps',
    title: 'Blindfold Steps',
    description: 'Watch the moves, then play them back from memory.',
    goal: 'Recall the longest move sequence you can, one step longer each round.',
    type: ChallengeType.blindfoldSteps,
    higherIsBetter: true,
    scoreLabel: 'moves recalled',
    blindfoldStartLength: 2,
  ),
];

final challengeRepositoryProvider = Provider<List<Challenge>>((ref) => challengeRepository);

final challengeByIdProvider = Provider.family<Challenge?, String>((ref, id) {
  for (final challenge in challengeRepository) {
    if (challenge.id == id) return challenge;
  }
  return null;
});
