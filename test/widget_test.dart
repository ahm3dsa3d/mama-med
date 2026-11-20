import 'package:flutter_test/flutter_test.dart';
import 'package:mama_meds/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MamaMedsApp());
    // The home screen title should appear
    expect(find.text('دواء ماما'), findsWidgets);
  });
}
