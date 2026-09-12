import 'package:checkmate_kids/app.dart';
import 'package:checkmate_kids/core/storage/prefs_store.dart';
import 'package:checkmate_kids/profile/controller/progress_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home screen shows all four feature areas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefsStore = await PrefsStore.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsStoreProvider.overrideWithValue(prefsStore)],
        child: const CheckmateKidsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checkmate Kids'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Puzzles'), findsOneWidget);
    expect(find.text('Learn to play'), findsOneWidget);
    expect(find.text('Challenges'), findsOneWidget);
  });
}
