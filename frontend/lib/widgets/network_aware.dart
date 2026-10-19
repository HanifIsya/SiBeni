import 'package:flutter/material.dart';

import '../core/network_service.dart';

/// Reloads a screen when the device regains a working connection.
///
/// The first request of a session is the one most likely to fail: the app may
/// start while the radio is still settling, or the server may be cold. Without
/// this, the user is left staring at a failed screen until they pull to
/// refresh. With it, the screen heals itself the moment the link comes back.
mixin NetworkAwareState<T extends StatefulWidget> on State<T> {
  /// Called after the connection is restored.
  void onNetworkRestored() {}

  OnlineState _previousNetworkState = OnlineState.offline;

  @override
  void initState() {
    super.initState();
    _previousNetworkState = NetworkService.instance.state.value;
    NetworkService.instance.state.addListener(_handleNetworkState);
  }

  void _handleNetworkState() {
    final current = NetworkService.instance.state.value;
    final restored =
        current == OnlineState.online && _previousNetworkState != OnlineState.online;
    _previousNetworkState = current;
    if (!restored || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onNetworkRestored();
    });
  }

  @override
  void dispose() {
    NetworkService.instance.state.removeListener(_handleNetworkState);
    super.dispose();
  }
}
