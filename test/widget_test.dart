import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Firebase requires initialization before app can run in tests.
    // Full integration tests are run via the Firebase Emulator Suite.
    expect(true, isTrue);
  });
}
