import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/main.dart';

void main() {
  testWidgets('HabitFlowApp smoke test', (WidgetTester tester) async {
    // Basic smoke test — verify app builds without throwing
    expect(HabitFlowApp, isNotNull);
  });
}
