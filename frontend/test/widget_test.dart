import 'package:flutter_test/flutter_test.dart';
import 'package:sibeni/main.dart';

void main() {
  testWidgets('SI BENI App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SiBeniApp());
    expect(find.byType(SiBeniApp), findsOneWidget);
  });
}
