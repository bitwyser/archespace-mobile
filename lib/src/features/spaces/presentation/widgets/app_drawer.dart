import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/features/settings/presentation/settings_screen.dart';
import 'package:archespace_mobile/src/features/storage/data/storage_repository.dart';
import 'package:archespace_mobile/src/features/storage/presentation/storage_screen.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/widgets/brand_glyph.dart';
import 'package:archespace_mobile/src/shared/widgets/confirm_dialog.dart';

/// The app's navigation drawer: the brand mark plus a theme "shuffle" at the
/// top, the primary destinations (Spaces, Archive, Recycle bin) with their
/// counts, and the session actions (Lock, Sign out, Settings) pinned to the
/// bottom.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.spacesCount,
    this.refreshToken = 0,
  });

  /// Number of top-level spaces, shown next to the Spaces destination.
  final int spacesCount;

  /// Bumped by the host each time the drawer opens; a change re-fetches the
  /// archive and bin counts so they stay fresh.
  final int refreshToken;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Cached across drawer instances so the last known counts show instantly on
  // reopen while a fresh fetch runs in the background.
  static int? _cachedArchive;
  static int? _cachedBin;

  late int? _archiveCount = _cachedArchive;
  late int? _binCount = _cachedBin;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The host bumps refreshToken when the drawer opens - re-fetch the counts.
    if (oldWidget.refreshToken != widget.refreshToken) _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final repo = StorageRepository(VaultSession.instance.masterKey);
      // ids-only counts: no decryption, so these return quickly.
      final archived = await repo.archivedCount();
      final deleted = await repo.deletedCount();
      _cachedArchive = archived;
      _cachedBin = deleted;
      if (mounted) {
        setState(() {
          _archiveCount = archived;
          _binCount = deleted;
        });
      }
    } catch (_) {
      // Keep the last cached counts if a refresh fails.
    }
  }

  Future<void> _open(BuildContext context, Widget screen) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the drawer
    await navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _lock(BuildContext context) {
    VaultSession.instance.lock();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'You will need your login password and vault PIN to sign back in.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!ok) return;
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListenableBuilder(
              listenable: AppearanceController.instance,
              builder: (context, _) {
                final accent = AppearanceController.instance.accent;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      const BrandGlyph(size: 24, framed: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            children: [
                              TextSpan(
                                text: 'Arche',
                                style: TextStyle(color: accent),
                              ),
                              TextSpan(
                                text: 'Space',
                                style: TextStyle(color: scheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined),
                        tooltip: 'Shuffle accent and theme',
                        onPressed: () => AppearanceController.instance.randomize(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 6),
            _tile(
              context,
              icon: Icons.grid_view_rounded,
              label: 'Spaces',
              selected: true,
              count: widget.spacesCount,
              onTap: () => Navigator.of(context).pop(),
            ),
            _tile(
              context,
              icon: Icons.archive_outlined,
              label: 'Archive',
              count: _archiveCount,
              onTap: () =>
                  _open(context, const StorageScreen(mode: StorageMode.archive)),
            ),
            _tile(
              context,
              icon: Icons.delete_outline,
              label: 'Recycle bin',
              count: _binCount,
              onTap: () =>
                  _open(context, const StorageScreen(mode: StorageMode.bin)),
            ),
            const Spacer(),
            const Divider(height: 1),
            const SizedBox(height: 6),
            _tile(
              context,
              icon: Icons.lock_outline,
              label: 'Lock vault',
              onTap: () => _lock(context),
            ),
            _tile(
              context,
              icon: Icons.logout,
              label: 'Sign out',
              color: scheme.error,
              onTap: () => _signOut(context),
            ),
            _tile(
              context,
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => _open(context, const SettingsScreen()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    Color? color,
    int? count,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? (selected ? scheme.primary : scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        minLeadingWidth: 0,
        horizontalTitleGap: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(icon, size: 22, color: tint),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: color ?? (selected ? scheme.primary : null),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: count == null
            ? null
            : Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
        selected: selected,
        selectedTileColor: scheme.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}
