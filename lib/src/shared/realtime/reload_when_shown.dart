import 'package:flutter/widgets.dart';

/// Realtime reloads for a screen that may sit under another one. While it's
/// covered (an item open in the editor, a dialog, another screen), a change
/// only marks it stale, and it reloads once when it shows again - instead of
/// re-fetching and re-decrypting behind the screen in use on every save.
mixin ReloadWhenShown<T extends StatefulWidget> on State<T> {
  bool _staleWhileHidden = false;

  /// Reload the screen's data.
  Future<void> reloadShown();

  bool get _isShown => ModalRoute.of(context)?.isCurrent ?? true;

  /// For a realtime watcher: reload now if showing, else when shown again.
  void reloadWhenShown() {
    if (!mounted) return;
    if (_isShown) {
      reloadShown();
    } else {
      _staleWhileHidden = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depends on the route's status, so this runs again when it's uncovered.
    if (_isShown && _staleWhileHidden) {
      _staleWhileHidden = false;
      reloadShown();
    }
  }
}
