import 'package:flutter_test/flutter_test.dart';
import 'package:aura_frontend/main.dart';
import 'package:aura_frontend/services/settings_service.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    final settings = await SettingsService.detect();
    await tester.pumpWidget(AuraApp(settings: settings));
    expect(find.text('AURA'), findsOneWidget);
  });
}
