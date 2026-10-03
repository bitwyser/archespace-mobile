import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space_colors.dart';
import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/features/settings/presentation/settings_screen.dart';
import 'package:archespace_mobile/src/features/storage/application/storage_counts.dart';
import 'package:archespace_mobile/src/features/storage/presentation/storage_screen.dart';
import 'package:archespace_mobile/src/features/starred/presentation/starred_screen.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';

const _spacesOpenKey = 'drawer_spaces_open';

/// The app's navigation drawer: a theme "shuffle" at the top, All spaces and
/// the top-level spaces (folding under their heading), the library (Starred,
/// Archive, Recycle bin) with counts, and Lock vault and Settings at the
/// bottom. Sign out lives in Settings.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.spaces,
    required this.onOpenSpace,
    this.refreshToken = 0,
  });

  /// The top-level spaces, in the home screen's order.
  final List<Space> spaces;

  /// Opens a space (called after the drawer closes).
  final ValueChanged<Space> onOpenSpace;

  /// Bumped by the host each time the drawer opens; a change re-fetches the
  /// archive and bin counts so they stay fresh.
  final int refreshToken;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Kept across drawer opens (the drawer is rebuilt each time) so the list
  // doesn't flash open before the saved choice loads.
  static bool? _spacesOpenCache;
  bool _spacesOpen = _spacesOpenCache ?? true;

  @override
  void initState() {
    super.initState();
    if (_spacesOpenCache == null) {
      SharedPreferences.getInstance().then((prefs) {
        final open = prefs.getBool(_spacesOpenKey) ?? true;
        _spacesOpenCache = open;
        if (mounted) setState(() => _spacesOpen = open);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The host bumps refreshToken when the drawer opens - refresh the counts.
    if (oldWidget.refreshToken != widget.refreshToken) {
      StorageCounts.instance.refresh();
    }
  }

  void _toggleSpaces() {
    final open = !_spacesOpen;
    setState(() => _spacesOpen = open);
    _spacesOpenCache = open;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_spacesOpenKey, open),
    );
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: 'Shuffle accent and theme',
                  onPressed: () => AppearanceController.instance.randomize(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _tile(
                    context,
                    icon: Icons.grid_view_rounded,
                    label: 'All spaces',
                    selected: true,
                    count: widget.spaces.length,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  if (widget.spaces.isNotEmpty) ...[
                    _sectionLabel(
                      context,
                      'Spaces',
                      expanded: _spacesOpen,
                      onTap: _toggleSpaces,
                    ),
                    // Only the space list scrolls; the library below stays.
                    if (_spacesOpen)
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            for (final space in widget.spaces)
                              _tile(
                                context,
                                icon: Icons.folder_outlined,
                                iconColor: spaceColor(
                                  space.color,
                                )?.withValues(alpha: 0.8),
                                label: space.name.isEmpty
                                    ? 'Untitled'
                                    : space.name,
                                protected: space.locked,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  widget.onOpenSpace(space);
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                  _sectionLabel(context, 'Library'),
                  ListenableBuilder(
                    listenable: StorageCounts.instance,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tile(
                          context,
                          icon: Icons.star_outline_rounded,
                          label: 'Starred',
                          count: StorageCounts.instance.starred,
                          onTap: () => _open(context, const StarredScreen()),
                        ),
                        _tile(
                          context,
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          count: StorageCounts.instance.archive,
                          onTap: () => _open(
                            context,
                            const StorageScreen(mode: StorageMode.archive),
                          ),
                        ),
                        _tile(
                          context,
                          icon: Icons.delete_outline,
                          label: 'Recycle bin',
                          count: StorageCounts.instance.bin,
                          onTap: () => _open(
                            context,
                            const StorageScreen(mode: StorageMode.bin),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              context,
              icon: Icons.lock_outline,
              label: 'Lock vault',
              onTap: () => _lock(context),
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

  /// A faint section heading. With [onTap] it folds its section, with a
  /// chevron showing which way.
  Widget _sectionLabel(
    BuildContext context,
    String label, {
    bool expanded = true,
    VoidCallback? onTap,
  }) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final text = Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          AnimatedRotation(
            turns: expanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 150),
            child: Icon(Icons.chevron_right, size: 16, color: color),
          ),
        ],
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      child: text,
    );
    if (onTap == null) return padded;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(onTap: onTap, child: padded),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    bool protected = false,
    Color? iconColor,
    int? count,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // The current page reads through a soft fill and an accent icon, not an
    // accent-tinted row.
    final tint = selected
        ? scheme.primary
        : iconColor ?? scheme.onSurfaceVariant;
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
            color: selected ? scheme.onSurface : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: protected
            ? Icon(
                Icons.lock_outline,
                size: 14,
                color: scheme.onSurfaceVariant,
                semanticLabel: 'Protected',
              )
            : count == null
            ? null
            : Text(
                '$count',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
        selected: selected,
        selectedColor: scheme.onSurface,
        selectedTileColor: scheme.onSurface.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}
