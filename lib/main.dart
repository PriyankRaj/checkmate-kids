import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/storage/prefs_store.dart';
import 'core/theme/board_theme.dart';
import 'profile/controller/progress_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefsStore = await PrefsStore.create();

  // The app must work fully offline, so fall back to bundled system fonts
  // rather than fetching from Google's CDN on first use.
  GoogleFonts.config.allowRuntimeFetching = false;

  final devicePixelRatio =
      WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio ?? 1.0;
  await ChessgroundImages.instance
      .loadAll(BoardTheme.classic.pieceAssets, devicePixelRatio: devicePixelRatio);
  await ChessgroundImages.instance
      .loadAll(BoardTheme.kids.pieceAssets, devicePixelRatio: devicePixelRatio);

  runApp(ProviderScope(
    overrides: [prefsStoreProvider.overrideWithValue(prefsStore)],
    child: const CheckmateKidsApp(),
  ));
}
