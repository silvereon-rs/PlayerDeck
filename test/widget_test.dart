import 'package:flutter_test/flutter_test.dart';
import 'package:playersdeck/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PlayerDeckApp());
    expect(find.text('PlayerDeck'), findsNothing); // Initial frame before load
  });
}
