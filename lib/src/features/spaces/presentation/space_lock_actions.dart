import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/vault/application/content_lock.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/features/vault/presentation/widgets/vault_pin_prompt.dart';
import 'package:archespace_mobile/src/shared/widgets/app_snackbar.dart';

/// Open a locked space with the vault PIN. True when it can be shown.
Future<bool> unlockSpace(BuildContext context, Space space) async {
  final ok = await askVaultPin(
    context,
    title: 'Unlock space',
    message:
        'Enter your vault PIN to open '
        '"${space.name.isEmpty ? 'Untitled' : space.name}".',
  );
  if (ok) ContentLock.instance.revealSpace(space.id);
  return ok;
}

/// Lock a space, or remove its lock. Locking is instant and hides it at
/// once; removing the lock needs the PIN unless the space is already open.
/// True when the lock changed (the caller reloads).
Future<bool> toggleSpaceLock(
  BuildContext context,
  Space space, {
  required bool locked,
}) async {
  final lock = ContentLock.instance;
  if (locked && !lock.isRevealed(space.id)) {
    final ok = await askVaultPin(
      context,
      title: 'Remove lock',
      message:
          'Enter your vault PIN to remove the lock. The space will open '
          'without the PIN.',
      confirmLabel: 'Remove lock',
    );
    if (!ok) return false;
  }
  try {
    await SpaceRepository(
      VaultSession.instance.masterKey,
    ).setLocked(space.id, !locked);
    if (context.mounted) {
      showSuccessSnack(context, locked ? 'Lock removed' : 'Space locked');
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showErrorSnack(
        context,
        locked ? "Couldn't remove the lock." : "Couldn't lock the space.",
      );
    }
    return false;
  }
}
