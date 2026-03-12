import 'package:flutter_test/flutter_test.dart';
import 'package:qdc_gci/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const QdcGciApp());
    expect(find.byType(QdcGciApp), findsOneWidget);
  });
}
