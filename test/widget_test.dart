import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:espace_app/app/app.dart';

void main() {
  testWidgets('App boots smoke test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: EspaceApp()));
    await tester.pump();

    // The app shell renders without throwing.
    expect(find.byType(EspaceApp), findsOneWidget);
  });
}