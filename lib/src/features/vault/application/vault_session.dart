import 'package:flutter/foundation.dart';

/// Holds the unlocked vault master key in memory for the lifetime of the
/// process (biometric unlock keeps its own copy, see SecureKeyStore).
/// [unlocked] lets the UI react to lock/unlock.
class VaultSession {
  VaultSession._();
  static final VaultSession instance = VaultSession._();

  final ValueNotifier<bool> unlocked = ValueNotifier<bool>(false);
  Uint8List? _masterKey;

  Uint8List get masterKey {
    final key = _masterKey;
    if (key == null) throw StateError('Vault is locked');
    return key;
  }

  void unlock(Uint8List masterKey) {
    _masterKey = masterKey;
    unlocked.value = true;
  }

  void lock() {
    _masterKey = null;
    unlocked.value = false;
  }
}
