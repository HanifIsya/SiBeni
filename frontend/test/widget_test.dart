import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sibeni/core/user_session.dart';
import 'package:sibeni/features/auth_screen.dart';
import 'package:sibeni/main.dart';

/// App-level smoke tests: the root widget must reach a real screen for both
/// the signed-out and signed-in states, without layout errors.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('unauthenticated launch lands on the auth screen', (tester) async {
    UserSession.instance.currentUser.value = null;

    await tester.pumpWidget(const SiBeniApp());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('SI BENI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated launch lands on the app shell', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    UserSession.instance.currentUser.value = const UserProfile(
      employeeId: 'OP-501',
      fullName: 'Ahmad Rizky',
      role: AppRole.hse,
      workZone: 'Pit Utama',
    );

    await tester.pumpWidget(const SiBeniApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(AppShell), findsOneWidget);
    // Role-aware navigation exposes five destinations for an HSE account.
    expect(find.text('Peta'), findsOneWidget);
    expect(find.text('Lapor'), findsOneWidget);
    expect(find.text('Darurat'), findsOneWidget);
    expect(find.text('Inspeksi'), findsOneWidget);
    expect(find.text('Insight'), findsOneWidget);
    expect(tester.takeException(), isNull);

    UserSession.instance.currentUser.value = null;
  });
}