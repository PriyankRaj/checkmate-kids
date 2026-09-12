import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'router.dart';

class CheckmateKidsApp extends StatelessWidget {
  const CheckmateKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Checkmate Kids',
      theme: buildClassicTheme(),
      routerConfig: appRouter,
    );
  }
}
