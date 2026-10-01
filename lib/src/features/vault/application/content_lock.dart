import 'package:flutter/foundation.dart';

import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';

/// Locked items and spaces. A locked item keeps its title and tags in view
/// and a locked space its name, but the content needs the vault PIN again.
/// An item in a locked space (or in a sub-space of one) is hidden too,
/// wherever it's listed. The lock is a flag on the row; the content is
/// encrypted with the vault key as always.
///
/// What has been opened lives only in memory: restarting the app, or the
/// vault locking, hides it all again.
class ContentLock extends ChangeNotifier {
  ContentLock._() {
    VaultSession.instance.unlocked.addListener(() {
      if (!VaultSession.instance.unlocked.value) hideAll();
    });
  }
  static final ContentLock instance = ContentLock._();

  final Set<String> _revealed = {};
  final Map<String, ({bool locked, String? parentId})> _spaces = {};

  bool isRevealed(String id) => _revealed.contains(id);

  /// Whether a space's contents must stay hidden: it, or its parent, is
  /// locked and not opened.
  bool isSpaceHidden(String? spaceId) {
    var id = spaceId;
    // Spaces nest one level; the bound only guards against a bad cycle.
    for (var depth = 0; id != null && depth < 4; depth++) {
      final space = _spaces[id];
      if (space == null) return false;
      if (space.locked && !_revealed.contains(id)) return true;
      id = space.parentId;
    }
    return false;
  }

  /// Whether an item's content must stay hidden.
  bool isItemHidden(SpaceItem item) =>
      (item.locked && !_revealed.contains(item.id)) ||
      isSpaceHidden(item.spaceId);

  void reveal(String id) {
    if (_revealed.add(id)) notifyListeners();
  }

  /// Open everything that hides [item]: its own lock and its spaces'.
  void revealItem(SpaceItem item) {
    var changed = false;
    if (item.locked) changed |= _revealed.add(item.id);
    var id = item.spaceId;
    for (var depth = 0; id != null && depth < 4; depth++) {
      final space = _spaces[id];
      if (space == null) break;
      if (space.locked) changed |= _revealed.add(id);
      id = space.parentId;
    }
    if (changed) notifyListeners();
  }

  /// Open a space and any locked space above it.
  void revealSpace(String spaceId) {
    var changed = false;
    String? id = spaceId;
    for (var depth = 0; id != null && depth < 4; depth++) {
      final space = _spaces[id];
      if (space == null) break;
      if (space.locked) changed |= _revealed.add(id);
      id = space.parentId;
    }
    if (changed) notifyListeners();
  }

  /// A space's lock as last loaded, or null if it hasn't been seen.
  bool? isSpaceLocked(String id) => _spaces[id]?.locked;

  void hide(String id) {
    if (_revealed.remove(id)) notifyListeners();
  }

  void hideAll() {
    if (_revealed.isEmpty) return;
    _revealed.clear();
    notifyListeners();
  }

  /// Record which spaces are locked (called whenever spaces load).
  void setSpaces(Iterable<Space> spaces) {
    var changed = false;
    for (final s in spaces) {
      changed |= _record(s.id, s.locked, s.parentId);
    }
    if (changed) notifyListeners();
  }

  /// Record spaces' locks from raw rows (for lists that don't build [Space]s),
  /// with one update for the lot.
  void registerSpaces(
    Iterable<({String id, bool locked, String? parentId})> spaces,
  ) {
    var changed = false;
    for (final s in spaces) {
      changed |= _record(s.id, s.locked, s.parentId);
    }
    if (changed) notifyListeners();
  }

  bool _record(String id, bool locked, String? parentId) {
    final next = (locked: locked, parentId: parentId);
    if (_spaces[id] == next) return false;
    _spaces[id] = next;
    return true;
  }

  /// A space was just locked or unlocked here (ahead of the next load).
  void setSpaceLocked(String id, bool locked) {
    final current = _spaces[id];
    _spaces[id] = (locked: locked, parentId: current?.parentId);
    if (locked) _revealed.remove(id);
    notifyListeners();
  }

  /// Wrong PINs entered in a row at the lock prompt. After [maxAttempts] the
  /// whole vault locks, so a lock can't be guessed at.
  int failedAttempts = 0;
  static const int maxAttempts = 5;
}
