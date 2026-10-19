import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sibeni/core/user_session.dart';
import 'package:sibeni/features/emergency_screen.dart';
import 'package:sibeni/features/inspection_screen.dart';
import 'package:sibeni/features/management_evaluation_screen.dart';
import 'package:sibeni/features/profile_edit_screen.dart';
import 'package:sibeni/features/risk_map_screen.dart';
import 'package:sibeni/features/settings_sheet.dart';
import 'package:sibeni/widgets/chamfer.dart';
import 'package:sibeni/widgets/role_workspace.dart';

/// ---------------------------------------------------------------------------
/// UX regression suite.
///
/// Every test here encodes a request that came back from the client review:
/// one SOS wordmark, one sign-out button, a header that is not a permanent
/// card, and a card shape that is not a rounded template.
/// ---------------------------------------------------------------------------

Widget _host(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    builder: (context, c) => c!,
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() {
    UserSession.instance.currentUser.value = const UserProfile(
      employeeId: 'MGT-099',
      fullName: 'Ir. Bambang Suryos',
      role: AppRole.management,
      workZone: 'Pit Utama',
    );
  });

  testWidgets('the SOS control carries exactly one SOS wordmark', (tester) async {
    await tester.pumpWidget(_host(const EmergencyScreen()));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('SOS'), findsOneWidget);
  });

  testWidgets('sign-out lives on the profile screen only', (tester) async {
    await tester.pumpWidget(_host(const ProfileEditScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    // The action sits at the bottom of the account page.
    await tester.dragUntilVisible(
      find.text('Keluar Akun (Log Out)'),
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Keluar Akun (Log Out)'), findsOneWidget);
  });

  testWidgets('the settings and profile sheets have no sign-out button',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () => showSettingsSheet(context),
                child: const Text('open-settings'),
              ),
              ElevatedButton(
                onPressed: () => showProfileSheet(context),
                child: const Text('open-profile'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final label in ['open-settings', 'open-profile']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        find.textContaining('Keluar Akun'),
        findsNothing,
        reason: 'sign-out must not be duplicated in $label',
      );

      await tester.tapAt(const Offset(180, 4));
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('working screens use the compact role strip, not a panel',
      (tester) async {
    await tester.pumpWidget(_host(const ManagementEvaluationScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    final banner = tester.widget<RoleWorkspaceBanner>(
      find.byType(RoleWorkspaceBanner),
    );
    expect(banner.variant, RoleBannerVariant.compact);
  });

  testWidgets('the home screen keeps the full role workspace panel',
      (tester) async {
    await tester.pumpWidget(
      _host(
        RiskMapScreen(onNavigateToReport: () {}, onNavigateToEmergency: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final banner = tester.widget<RoleWorkspaceBanner>(
      find.byType(RoleWorkspaceBanner),
    );
    expect(banner.variant, RoleBannerVariant.full);
  });

  testWidgets('cards are cut-corner panels, not rounded templates',
      (tester) async {
    await tester.pumpWidget(_host(const InspectionScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is ChamferClipper,
      ),
      findsWidgets,
    );
  });
}
