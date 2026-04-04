import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundrypro/app.dart';

void main() {
  testWidgets('Point app mounts', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LaundryProApp()),
    );
    await tester.pump();
    expect(find.byType(LaundryProApp), findsOneWidget);
  });
}
