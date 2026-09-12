import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine_service.dart';

/// The single, process-wide Stockfish handle. Kept alive for the whole app
/// lifetime — `stockfish` allows only one live instance, so every consumer
/// (game, puzzles, challenges, analysis) reads this same provider rather
/// than creating its own [EngineService].
final engineServiceProvider = Provider<EngineService>((ref) {
  final service = EngineService();
  ref.onDispose(service.dispose);
  return service;
}, name: 'engineServiceProvider');
