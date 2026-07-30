import 'package:flutter_test/flutter_test.dart';

import 'package:blog_phone/main.dart';

void main() {
  testWidgets('renders the Blog Phone app', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Blog Phone'), findsOneWidget);
  });
}
