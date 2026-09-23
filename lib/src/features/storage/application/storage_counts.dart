import 'package:flutter/foundation.dart';

import 'package:archespace_mobile/src/features/storage/data/storage_repository.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';

/// Holds the archive and recycle-bin counts app-wide so the drawer can show
/// them instantly (like the spaces count, which is already in memory). Loaded
/// once at launch and refreshed when the drawer opens or storage changes.
class StorageCounts extends ChangeNotifier {
  StorageCounts._();
  static final StorageCounts instance = StorageCounts._();

  int? archive;
  int? bin;
  bool _loading = false;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final repo = StorageRepository(VaultSession.instance.masterKey);
      final counts = await Future.wait([
        repo.archivedCount(),
        repo.deletedCount(),
      ]);
      archive = counts[0];
      bin = counts[1];
      notifyListeners();
    } catch (_) {
      // Keep the last known values on failure.
    } finally {
      _loading = false;
    }
  }

  /// Clear the counts (e.g. on lock/sign-out) so a new session reloads them.
  void reset() {
    archive = null;
    bin = null;
    notifyListeners();
  }
}
