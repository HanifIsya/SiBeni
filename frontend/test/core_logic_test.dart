import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:sibeni/core/network_service.dart';
import 'package:sibeni/core/offline_sync_manager.dart';
import 'package:sibeni/core/zone_model.dart';

void main() {
  group('Link resolution', () {
    test('prefers Wi-Fi when several transports are reported', () {
      expect(
        NetworkService.resolveForTest([
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
        LinkType.wifi,
      );
    });

    test('identifies cellular-only links', () {
      expect(
        NetworkService.resolveForTest([ConnectivityResult.mobile]),
        LinkType.cellular,
      );
    });

    test('treats VPN as a usable link', () {
      expect(
        NetworkService.resolveForTest([ConnectivityResult.vpn]),
        LinkType.wifi,
      );
    });

    test('reports no link when nothing is available', () {
      expect(
        NetworkService.resolveForTest([ConnectivityResult.none]),
        LinkType.none,
      );
    });
  });

  group('Online state', () {
    test('cellular is allowed by default so mobile data works out of the box', () {
      expect(NetworkService.instance.allowMobileData.value, isTrue);
    });

    test('describe() never claims a connection that does not exist', () {
      final service = NetworkService.instance;
      final previous = service.state.value;
      addTearDown(() => service.state.value = previous);

      service.state.value = OnlineState.offline;
      expect(service.describe(), 'Offline');

      service.state.value = OnlineState.mobileBlocked;
      expect(service.describe(), 'Hanya Wi-Fi');

      service.state.value = OnlineState.unreachable;
      expect(service.describe(), 'Server tidak terjangkau');
    });
  });

  group('ZoneGeometry', () {
    test('parses the documented centre / polygon / assembly contract', () {
      final geometry = ZoneGeometry.fromJson(jsonDecode('''
        {
          "center": [-2.1458291, 115.3489124],
          "polygon": [[-2.14,115.34],[-2.15,115.34],[-2.15,115.36]],
          "assembly": [-2.146, 115.345]
        }
      '''));

      expect(geometry.center!.latitude, closeTo(-2.1458291, 1e-7));
      expect(geometry.polygon.length, 3);
      expect(geometry.assembly!.longitude, closeTo(115.345, 1e-6));
      expect(geometry.isEmpty, isFalse);
    });

    test('accepts a bare polygon ring and derives its centre', () {
      final geometry = ZoneGeometry.fromJson([
        [-2.14, 115.34],
        [-2.16, 115.34],
        [-2.16, 115.38],
      ]);

      expect(geometry.center, isNotNull);
      expect(geometry.center!.latitude, closeTo(-2.1533333, 1e-5));
      expect(geometry.center!.longitude, closeTo(115.3533333, 1e-5));
    });

    test('null geometry yields an empty zone rather than a fake position', () {
      final geometry = ZoneGeometry.fromJson(null);
      expect(geometry.isEmpty, isTrue);
      expect(geometry.center, isNull);
      expect(geometry.assembly, isNull);
    });

    test('malformed geometry degrades gracefully', () {
      final geometry = ZoneGeometry.fromJson({'center': 'nonsense', 'polygon': 42});
      expect(geometry.isEmpty, isTrue);
    });

    test('distance is measured on the ground, not in degrees', () {
      // ~111.3 m per 0.001 degree of latitude at the equator.
      final a = const LatLng(0, 0);
      final b = const LatLng(0.001, 0);
      expect(ZoneGeometry.distanceMetres(a, b), closeTo(111.2, 1.0));
    });
  });

  group('Offline outbox', () {
    test('exposes queue and sync state for the UI to observe', () {
      final manager = OfflineSyncManager.instance;
      expect(manager.queueCount.value, isA<int>());
      expect(manager.isSyncing.value, isFalse);
    });
  });
}