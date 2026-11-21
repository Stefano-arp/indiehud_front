import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/main.dart';

void main() {
  testWidgets('IndieHub arranca en Home', (WidgetTester tester) async {
    await tester.pumpWidget(const IndieHubApp());
    await tester.pump();
    expect(find.text('IndieHub'), findsOneWidget);
  });
}
