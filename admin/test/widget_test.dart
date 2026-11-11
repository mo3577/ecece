import 'package:flutter_test/flutter_test.dart';
import 'package:ece_admin/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const EceAdminApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EceAdminApp), findsOneWidget);
  });
}
