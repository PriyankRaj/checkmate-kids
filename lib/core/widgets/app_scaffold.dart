import 'package:flutter/material.dart';

/// Shared scaffold for feature screens: title, optional back button, and a
/// centered, width-capped body so the layout reads well on tablets too.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.maxContentWidth = 720,
    this.scrollable = true,
    this.scaffoldKey,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final double maxContentWidth;
  final bool scrollable;

  /// Pass this when a caller needs `scaffoldKey.currentState!.showBottomSheet(...)`
  /// (e.g. [showResultSheet]) — `Scaffold.of(context)` doesn't work from the
  /// caller's own `context`, since that context sits *above* this widget's
  /// internal `Scaffold`, not inside its body subtree.
  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: body,
        ),
      ),
    );
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}
