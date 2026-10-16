import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sibeni/core/theme.dart';
import 'package:sibeni/core/user_session.dart';
import 'package:sibeni/features/auth_screen.dart';
import 'package:sibeni/features/dashboard_screen.dart';
import 'package:sibeni/features/emergency_screen.dart';
import 'package:sibeni/features/inspection_screen.dart';
import 'package:sibeni/features/quick_report_screen.dart';
import 'package:sibeni/features/risk_map_screen.dart';
import 'package:sibeni/features/settings_sheet.dart';
import 'package:sibeni/main.dart';
import 'package:sibeni/widgets/sb_button.dart';
import 'package:sibeni/widgets/sb_card.dart';

/// ---------------------------------------------------------------------------
/// Layout regression suite.
///
/// Every screen is rendered across the full range of supported viewports and at
/// the maximum supported OS text scale. A RenderFlex overflow — the "content is
/// out of screen" class of bug — is reported as a test failure, which is far
/// more reliable than eyeballing a device.
/// ---------------------------------------------------------------------------

const _viewports = <String, Size>{
  'small phone (360x640)': Size(360, 640),
  'phone (411x914)': Size(411, 914),
  'large phone (430x932)': Size(430, 932),
  'tablet portrait (800x1280)': Size(800, 1280),
  'tablet landscape (1280x800)': Size(1280, 800),
  'narrow phone with 1.3x text (320x568)': Size(320, 568),
};

Widget _host(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: c!,
    ),
    // The real shell hosts every screen inside a Scaffold; mirror that so the
    // test measures the same Material constraints the device does.
    home: Scaffold(body: child),
  );
}

/// Captures every Flutter error (including RenderFlex overflows, which carry
/// the offending widget) so failures name the exact source of the problem.
Future<List<FlutterErrorDetails>> _pumpAndCollect(
  WidgetTester tester,
  Widget screen,
  Size size, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;

  await tester.pumpWidget(_host(screen, textScale: textScale));
  await tester.pump(const Duration(milliseconds: 700));
  // Drain any deferred frames (e.g. the staggered entrance animation).
  await tester.pump(const Duration(milliseconds: 700));

  FlutterError.onError = previous;
  tester.takeException();
  return captured;
}

String _describe(List<FlutterErrorDetails> errors) {
  return errors
      .map((e) => '${e.exception}\n${e.context}\n${e.informationCollector?.call()}')
      .join('\n---\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // No network in tests; fonts must resolve to the bundled fallback.
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() {
    UserSession.instance.currentUser.value = const UserProfile(
      employeeId: 'OP-501',
      fullName: 'Ahmad Rizky',
      role: AppRole.hse,
      workZone: 'Pit Utama',
    );
  });

  final screens = <String, Widget Function()>{
    'Risk map': () => RiskMapScreen(onNavigateToReport: () {}, onNavigateToEmergency: () {}),
    'Quick report': () => const QuickReportScreen(),
    'Emergency': () => const EmergencyScreen(),
    'Inspection': () => const InspectionScreen(),
    'Insight': () => const DashboardScreen(),
  };

  screens.forEach((name, build) {
    for (final entry in _viewports.entries) {
      testWidgets('$name lays out without overflow — ${entry.key}',
          (tester) async {
        final errors = await _pumpAndCollect(tester, build(), entry.value);
        expect(errors, isEmpty, reason: _describe(errors));
      });
    }

    testWidgets('$name survives a 1.3x OS text scale', (tester) async {
      final errors = await _pumpAndCollect(
        tester,
        build(),
        const Size(320, 568),
        textScale: 1.3,
      );
      expect(errors, isEmpty, reason: _describe(errors));
    });
  });

  // --------------------------------------------------------------- primitives
  testWidgets('Auth screen fits every viewport', (tester) async {
    for (final entry in _viewports.entries) {
      final errors = await _pumpAndCollect(tester, const AuthScreen(), entry.value);
      expect(errors, isEmpty, reason: '${entry.key}\n${_describe(errors)}');
    }
  });

  testWidgets('App shell chrome fits every viewport', (tester) async {
    for (final entry in _viewports.entries) {
      final errors = await _pumpAndCollect(tester, const AppShell(), entry.value);
      expect(errors, isEmpty, reason: '${entry.key}\n${_describe(errors)}');
    }
  });

  testWidgets('Settings and network sheets fit a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(_host(
      Builder(
        builder: (context) => Column(
          children: [
            ElevatedButton(
              onPressed: () => showSettingsSheet(context),
              child: const Text('open-settings'),
            ),
            ElevatedButton(
              onPressed: () => showNetworkSheet(context),
              child: const Text('open-network'),
            ),
            ElevatedButton(
              onPressed: () => showProfileSheet(context),
              child: const Text('open-profile'),
            ),
          ],
        ),
      ),
    ));

    for (final label in ['open-settings', 'open-network', 'open-profile']) {
      captured.clear();
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(captured, isEmpty, reason: '$label\n${_describe(captured)}');
      tester.takeException();
      // The sheets are bottom-anchored; the top strip is the dismiss barrier.
      await tester.tapAt(const Offset(180, 4));
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('SbButton renders long labels without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Center(
            child: SbButton(
              label: 'Kirim Laporan Tanggap Darurat Morgens',
              icon: Icons.send_rounded,
              onPressed: () {},
            ),
          ),
        ),
        textScale: 1.3,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SbCard with accent rail renders inside narrow bounds', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const Scaffold(
          body: SbCard(
            accent: AppTheme.riskCritical,
            child: Text('TemuanXivIVXIVIIVXIVIIVXVIXVIVX'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}