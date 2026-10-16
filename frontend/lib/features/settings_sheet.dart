import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_config.dart';
import '../core/auth_service.dart';
import '../core/location_service.dart';
import '../core/network_service.dart';
import '../core/offline_sync_manager.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';

/// Bottom sheet chrome shared by every modal in the product.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.inkMuted),
                ),
              ],
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Profile
// ===========================================================================
Future<void> showProfileSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;
    return _Sheet(
      title: user?.fullName ?? 'Pengguna',
      subtitle: user == null
          ? null
          : '${user.roleDisplayName} · ${user.employeeId}\n${user.workZone}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SbCard(
            padding: const EdgeInsets.all(AppTheme.md),
            child: Column(
              children: [
                _Row(
                  icon: Icons.badge_outlined,
                  label: 'Nomor Pegawai',
                  value: user?.employeeId ?? '—',
                ),
                _Divider(),
                _Row(
                  icon: Icons.map_outlined,
                  label: 'Zona Penugasan',
                  value: (user?.workZone ?? '—').split(' (').first,
                ),
                _Divider(),
                _Row(
                  icon: Icons.phone_outlined,
                  label: 'Kontak',
                  value: user?.phone ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SbButton(
            label: 'Keluar Akun',
            icon: Icons.logout_rounded,
            variant: SbButtonVariant.ghost,
            tone: AppTheme.riskCritical,
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.instance.signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.inkMuted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(height: 1);
}

// ===========================================================================
// Network / connectivity
// ===========================================================================
Future<void> showNetworkSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _NetworkSheet(),
  );
}

class _NetworkSheet extends StatelessWidget {
  const _NetworkSheet();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OnlineState>(
      valueListenable: NetworkService.instance.state,
      builder: (context, state, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: NetworkService.instance.allowMobileData,
          builder: (context, allowMobile, _) {
            return ValueListenableBuilder<int>(
              valueListenable: OfflineSyncManager.instance.queueCount,
              builder: (context, queue, _) {
                return _Sheet(
                  title: 'Koneksi',
                  subtitle: NetworkService.instance.describe(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SbCard(
                        padding: const EdgeInsets.all(AppTheme.md),
                        child: Column(
                          children: [
                            _Row(
                              icon: Icons.router_rounded,
                              label: 'Koneksi aktif',
                              value: _linkLabel(NetworkService.instance.link.value),
                            ),
                            _Divider(),
                            _Row(
                              icon: Icons.cloud_queue_rounded,
                              label: 'Menunggu sinkron',
                              value: '$queue laporan',
                            ),
                            _Divider(),
                            _Row(
                              icon: Icons.schedule_rounded,
                              label: 'Sinkron terakhir',
                              value: _lastSyncLabel(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mobile-data policy — the switch that makes cellular work.
                      SbCard(
                        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.brand.withValues(alpha: 0.10),
                                borderRadius: AppTheme.brSm,
                              ),
                              child: const Icon(Icons.network_cell_rounded,
                                  size: 20, color: AppTheme.brand),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Izinkan Data Seluler',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    allowMobile
                                        ? 'Pakai Wi-Fi dan paket data.'
                                        : 'Hanya Wi-Fi. Laporan tetap tersimpan.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: AppTheme.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: allowMobile,
                              activeThumbColor: AppTheme.brand,
                              onChanged: (v) async {
                                HapticFeedback.selectionClick();
                                await NetworkService.instance.setAllowMobileData(v);
                                if (NetworkService.instance.isOnline) {
                                  await OfflineSyncManager.instance.syncQueuedReports();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      SbButton(
                        label: 'Periksa Koneksi Sekarang',
                        icon: Icons.refresh_rounded,
                        variant: SbButtonVariant.ghost,
                        tone: AppTheme.brand,
                        onPressed: () async {
                          await NetworkService.instance.refresh(force: true);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(NetworkService.instance.describe())),
                          );
                        },
                      ),
                      if (queue > 0) ...[
                        const SizedBox(height: 10),
                        SbButton(
                          label: 'Kirim $queue Laporan Tertunda',
                          icon: Icons.cloud_upload_rounded,
                          loading: OfflineSyncManager.instance.isSyncing.value,
                          onPressed: () async {
                            await OfflineSyncManager.instance.syncQueuedReports();
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static String _linkLabel(LinkType type) {
    switch (type) {
      case LinkType.wifi:
        return 'Wi-Fi';
      case LinkType.cellular:
        return 'Paket Data';
      case LinkType.ethernet:
        return 'Kabel';
      case LinkType.bluetooth:
        return 'Bluetooth';
      case LinkType.none:
        return 'Tidak ada';
    }
  }

  static String _lastSyncLabel() {
    final at = OfflineSyncManager.instance.lastSyncedAt.value;
    if (at == null) return 'Belum pernah';
    return DateFormat('d MMM, HH:mm').format(at);
  }
}

// ===========================================================================
// Settings hub
// ===========================================================================
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Pengaturan',
      subtitle: 'Preferensi perangkat dan lokasi untuk lapangan.',
      child: ValueListenableBuilder<GpsStatus>(
        valueListenable: LocationService.instance.status,
        builder: (context, gps, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GpsTile(status: gps),
              const SizedBox(height: 14),
              SbCard(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  children: [
                    _Row(
                      icon: Icons.info_outline_rounded,
                      label: 'Versi aplikasi',
                      value: '1.2.0',
                    ),
                    _Divider(),
                    _Row(
                      icon: Icons.business_rounded,
                      label: 'Organisasi',
                      value: AppConfig.organisation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'SI BENI — ${AppConfig.appTagline}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GpsTile extends StatelessWidget {
  const _GpsTile({required this.status});
  final GpsStatus status;

  @override
  Widget build(BuildContext context) {
    final ready = status == GpsStatus.ready;
    final color = ready
        ? AppTheme.online
        : (status == GpsStatus.blocked || status == GpsStatus.serviceOff
            ? AppTheme.offline
            : AppTheme.inkFaint);

    return SbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppTheme.brSm,
                ),
                child: Icon(Icons.my_location_rounded, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posisi GNSS',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText(status),
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SbPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    LocationService.instance.coordinatesLabel,
                    style: AppTheme.mono(size: 12, weight: FontWeight.w700, color: AppTheme.ink),
                  ),
                ),
                Text(
                  LocationService.instance.accuracyLabel,
                  style: AppTheme.mono(size: 11, color: AppTheme.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SbButton(
                  label: 'Segarkan',
                  icon: Icons.refresh_rounded,
                  variant: SbButtonVariant.ghost,
                  tone: AppTheme.brand,
                  height: 44,
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await LocationService.instance.ensureFix();
                  },
                ),
              ),
              if (status == GpsStatus.blocked || status == GpsStatus.serviceOff) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SbButton(
                    label: 'Buka Setelan',
                    icon: Icons.settings_rounded,
                    variant: SbButtonVariant.ghost,
                    tone: AppTheme.brand,
                    height: 44,
                    onPressed: () => LocationService.instance.openSettings(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _statusText(GpsStatus status) {
    switch (status) {
      case GpsStatus.ready:
        return 'Sinyal posisi aktif.';
      case GpsStatus.locating:
        return 'Mencari sinyal satelit…';
      case GpsStatus.requesting:
        return 'Menunggu izin lokasi.';
      case GpsStatus.blocked:
        return 'Izin lokasi diblokir. Aktifkan di pengaturan sistem.';
      case GpsStatus.serviceOff:
        return 'Layanan lokasi perangkat nonaktif. Nyalakan GPS.';
      case GpsStatus.unavailable:
        return 'Sinyal posisi tidak tersedia.';
      case GpsStatus.idle:
        return 'Belum diakses.';
    }
  }
}