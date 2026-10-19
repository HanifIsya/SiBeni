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
    // HSE verifies reports and never files them: no "Lapor" tab. HSE instead
    // gets the report register, field inspections, coordination, and the K3
    // dashboard. SOS is available from the app-bar overflow.
    expect(find.text('Peta'), findsOneWidget);
    expect(find.text('Lapor'), findsNothing);
    expect(find.text('Darurat'), findsNothing);
    expect(find.text('Inspeksi'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Koordinasi'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);

    UserSession.instance.currentUser.value = null;
  });

  testWidgets('each role gets a distinct navigation set', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A worker files reports and triggers alarms; nothing else.
    expect(AppRole.worker.canVerifyTickets, isFalse);
    expect(AppRole.worker.canReviewReports, isFalse);
    expect(AppRole.worker.canViewInsight, isFalse);

    // A supervisor verifies corrective actions but never reviews reports or
    // publishes warnings.
    expect(AppRole.supervisor.canVerifyTickets, isTrue);
    expect(AppRole.supervisor.canReviewReports, isFalse);
    expect(AppRole.supervisor.canManageWarnings, isFalse);
    expect(AppRole.supervisor.canViewInsight, isTrue);
    expect(AppRole.supervisor.canEditInsight, isFalse);

    // HSE owns hazard review and early warnings.
    expect(AppRole.hse.canReviewReports, isTrue);
    expect(AppRole.hse.canManageWarnings, isTrue);
    expect(AppRole.hse.canEditInsight, isFalse);

    // Only management owns the official K3 / ESG record.
    expect(AppRole.management.canEditInsight, isTrue);

    // And the four sets are genuinely different.
    final signatures = AppRole.values
        .map((r) => [
              r.canVerifyTickets,
              r.canReviewReports,
              r.canManageWarnings,
              r.canViewInsight,
              r.canEditInsight,
            ].join())
        .toSet();
    expect(signatures.length, AppRole.values.length,
        reason: 'every role must have a distinct capability signature');
  });
}