import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sibeni/core/api_service.dart';
import 'package:sibeni/core/user_session.dart';
import 'package:sibeni/features/inspection_screen.dart';
import 'package:sibeni/main.dart';

/// ---------------------------------------------------------------------------
/// Regression suite for the blank HSE inspection screen.
///
/// The screen used to crash with a RangeError for every HSE account: the
/// action label read `_stages[stage]` while a finished ticket sits at stage 6
/// and the list only has six entries. In release mode that error painted an
/// empty box, so the whole screen looked blank while the supervisor account
/// — which never reads that index — worked fine.
///
/// These tests render the screen with the **real production payload** (two
/// finished tickets at stage 6) so the crash cannot come back unnoticed.
/// ---------------------------------------------------------------------------

Map<String, dynamic> _fixture() {
  final raw = File('test/fixtures/api_fixtures.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() {
    ApiService.readOverride = null;
  });

  tearDown(() {
    ApiService.readOverride = null;
  });

  void serveProductionPayloads() {
    final fixtures = _fixture();
    ApiService.readOverride = (url) {
      if (url.contains('/api/inspections')) {
        return fixtures['inspections'] as Map<String, dynamic>;
      }
      if (url.contains('/api/reports')) {
        return fixtures['reports_all'] as Map<String, dynamic>;
      }
      if (url.contains('/api/notifications')) {
        return {'notifications': <dynamic>[], 'unread_count': 0};
      }
      if (url.contains('/api/coordination')) {
        return {'requests': <dynamic>[], 'counts': <String, dynamic>{}};
      }
      return <String, dynamic>{};
    };
  }

  testWidgets('the HSE inspection screen renders tickets that are already '
      'at the last stage', (tester) async {
    serveProductionPayloads();

    UserSession.instance.currentUser.value = const UserProfile(
      employeeId: 'HSE-001',
      fullName: 'Dr. Citra Utami',
      role: AppRole.hse,
      workZone: 'Pit Utama',
    );

    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionScreen())),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(errors, isEmpty, reason: errors.map((e) => e.exception).join(' | '));

    // The production ticket must be on screen, not swallowed by a crash.
    expect(find.textContaining('Webbing Sling'), findsOneWidget);
    expect(find.text('Tindak Lanjut'), findsOneWidget);
  });

  testWidgets('the supervisor inspection screen renders the same payload',
      (tester) async {
    serveProductionPayloads();

    UserSession.instance.currentUser.value = const UserProfile(
      employeeId: 'SPV-202',
      fullName: 'Hendro Wijaya',
      role: AppRole.supervisor,
      workZone: 'Pit Utama',
    );

    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionScreen())),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(errors, isEmpty, reason: errors.map((e) => e.exception).join(' | '));
    expect(find.textContaining('Webbing Sling'), findsOneWidget);
  });

  testWidgets('every HSE tab renders with production payloads', (tester) async {
    serveProductionPayloads();

    UserSession.instance.currentUser.value = const UserProfile(
      employeeId: 'HSE-001',
      fullName: 'Dr. Citra Utami',
      role: AppRole.hse,
      workZone: 'Pit Utama',
    );

    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(const SiBeniApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));

    for (final tab in ['Peta', 'Inspeksi', 'Laporan', 'Koordinasi', 'Dashboard']) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(errors, isEmpty, reason: errors.map((e) => e.exception).join(' | '));
  });
}
