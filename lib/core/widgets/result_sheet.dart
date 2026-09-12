import 'package:flutter/material.dart';

/// Shows [content] as a **persistent, non-modal** bottom sheet via
/// `scaffoldKey.currentState!.showBottomSheet` — deliberately not
/// `showDialog`/`showModalBottomSheet`. Those add a darkening scrim that
/// covers the board; this only occupies the bottom fraction of the screen,
/// so the final position (checkmate, solved puzzle, finished challenge)
/// stays fully visible above it.
///
/// [scaffoldKey] must be the same key passed to the screen's `AppScaffold`
/// — `Scaffold.of(context)` doesn't work here since the caller's `context`
/// sits above `AppScaffold`'s internal `Scaffold`, not inside its body.
///
/// Returns the [PersistentBottomSheetController] so callers can `close()` it
/// (e.g. when starting a rematch) — closing is idempotent-safe to call even
/// if already closed.
PersistentBottomSheetController showResultSheet({
  required GlobalKey<ScaffoldState> scaffoldKey,
  required Widget content,
}) {
  return scaffoldKey.currentState!.showBottomSheet(
    (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(top: false, child: content),
    ),
  );
}

/// Standard content layout for a [showResultSheet] call: title, optional
/// subtitle/score line, and a row of action buttons.
class ResultSheetContent extends StatelessWidget {
  const ResultSheetContent({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final action in actions) Padding(padding: const EdgeInsets.only(left: 8), child: action),
          ],
        ),
      ],
    );
  }
}
