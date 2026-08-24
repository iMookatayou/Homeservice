// Basic app-boot smoke test: with no stored session, the app should start
// at the splash screen and land on the login screen once auth resolves to
// "unauthenticated" (no valid token in secure storage in the test env).

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeservice/main.dart';
import 'package:homeservice/screens/login_screen.dart';

void main() {
  testWidgets('App boots and redirects to login when unauthenticated', (
    WidgetTester tester,
  ) async {
    // main() normally loads .env.development; do the same here so
    // ApiClient/Env reads don't hit dotenv's NotInitializedError.
    dotenv.loadFromString(envString: 'API_BASE_URL=http://127.0.0.1:8080/api/v1');

    await tester.pumpWidget(
      const ProviderScope(child: HomeServiceApp()),
    );

    // Let the splash screen resolve the (non-existent) session and redirect.
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
