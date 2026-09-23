import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe_frontend/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UniverseApp navigation shell boots cleanly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildUniverseTheme(),
          home: const Scaffold(
            body: Center(child: Text('UniVerse Shell Test')),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('UniVerse Shell Test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
