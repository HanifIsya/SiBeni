import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/notification_service.dart';
import '../core/theme.dart';
import '../widgets/pills.dart';
import '../widgets/sb_button.dart';
import '../widgets/states.dart';

/// Personal inbox. Opened from the bell in the app bar.
Future<void> showNotificationCenter(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _NotificationCenterSheet(),
  );
}

class _NotificationCenterSheet extends StatefulWidget {
  const _NotificationCenterSheet();

  @override
  State<_NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<_NotificationCenterSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await NotificationService.instance.fetch();
    if (!mounted) return;
    setState(() {
      _items = result.notifications;
      _loading = false;
    });
  }

  Future<void> _open(Map<String, dynamic> item) async {
    if (item['is_read'] != true) {
      final result = await NotificationService.instance.markRead(
        (item['id'] ?? '').toString(),
      );
      if (result.isSuccess && mounted) {
        setState(() {
          final index = _items.indexWhere((entry) => entry['id'] == item['id']);
          if (index >= 0) {
            _items[index] = {..._items[index], 'is_read': true};
          }
        });
      }
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.brLg),
        title: Text(
          (item['title'] ?? 'Notifikasi').toString(),
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (item['body'] ?? 'Tidak ada detail.').toString(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _timeLabel(item['created_at']),
              style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAll() async {
    setState(() => _markingAll = true);
    final result = await NotificationService.instance.markAllRead();
    if (!mounted) return;
    setState(() {
      if (result.isSuccess) {
        _items = _items
            .map((item) => {...item, 'is_read': true})
            .toList(growable: false);
      }
      _markingAll = false;
    });
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.riskCritical,
          content: Text(result.error ?? 'Gagal menandai notifikasi.'),
        ),
      );
    }
  }

  static String _timeLabel(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (parsed == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(day).inDays;
    final clock = DateFormat('HH:mm').format(parsed);
    if (diff == 0) return 'Hari ini, $clock';
    if (diff == 1) return 'Kemarin, $clock';
    return '${DateFormat('d MMM yyyy').format(parsed)}, $clock';
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.hairline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(alpha: 0.10),
                      borderRadius: AppTheme.brSm,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      size: 20,
                      color: AppTheme.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifikasi Saya',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Laporan, persetujuan, evaluasi, dan koordinasi',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Muat ulang',
                    color: AppTheme.inkMuted,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 21),
                    tooltip: 'Tutup',
                    color: AppTheme.ink,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Row(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: NotificationService.instance.unread,
                    builder: (context, unread, _) => SbPill(
                      label: '$unread BELUM DIBACA',
                      color: unread > 0 ? AppTheme.riskHigh : AppTheme.inkFaint,
                      dense: true,
                    ),
                  ),
                  const Spacer(),
                  SbButton(
                    label: 'Tandai semua',
                    icon: Icons.done_all_rounded,
                    height: 38,
                    expand: false,
                    variant: SbButtonVariant.ghost,
                    tone: AppTheme.brand,
                    loading: _markingAll,
                    onPressed: _markingAll ? null : _markAll,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.hairline),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.brand),
                    )
                  : _items.isEmpty
                      ? const EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'Belum ada notifikasi',
                          message:
                              'Notifikasi akan muncul saat laporan, tindakan, persetujuan, atau koordinasi baru masuk.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.brand,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) => _NotificationTile(
                              item: _items[index],
                              onTap: () => _open(_items[index]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  static (Color, IconData) _style(String category) {
    switch (category.toUpperCase()) {
      case 'REPORT':
        return (AppTheme.brand, Icons.assignment_rounded);
      case 'ACTION':
        return (AppTheme.riskHigh, Icons.build_circle_rounded);
      case 'APPROVAL':
        return (const Color(0xFF6D28D9), Icons.approval_rounded);
      case 'EVALUATION':
        return (AppTheme.online, Icons.fact_check_rounded);
      case 'COORDINATION':
        return (const Color(0xFF0E7490), Icons.forum_rounded);
      default:
        return (AppTheme.inkMuted, Icons.info_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style((item['category'] ?? 'INFO').toString());
    final unread = item['is_read'] != true;

    return Material(
      color: unread
          ? Color.alphaBlend(color.withValues(alpha: 0.055), AppTheme.surface)
          : AppTheme.surface,
      borderRadius: AppTheme.brMd,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppTheme.brMd,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppTheme.brMd,
            border: Border.all(
              color: unread
                  ? color.withValues(alpha: 0.28)
                  : AppTheme.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: AppTheme.brSm,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (item['title'] ?? 'Notifikasi').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ((item['body'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item['body'].toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _NotificationCenterSheetState._timeLabel(
                        item['created_at'],
                      ),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
