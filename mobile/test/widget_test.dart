import 'package:flutter_test/flutter_test.dart';
import 'package:khu_nyi_kal_sal/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KhuNyiKalSalApp());
    // Verify the login screen renders
    expect(find.text('Khu Nyi Kal Sal'), findsOneWidget);
  });
}
