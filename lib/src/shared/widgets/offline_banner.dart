import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/shared/widgets/status_banner.dart';

/// A thin banner shown when a list is displaying cached data because the
/// network was unavailable. A [StatusBanner] so it matches the pending-sync
/// banner.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBanner(
      icon: Icons.cloud_off,
      message: 'Offline - showing saved data',
    );
  }
}
