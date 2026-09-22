import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/search/presentation/search_screen.dart';
import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_detail_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_editor_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/widgets/app_drawer.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/widgets/space_card.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/offline/write_queue.dart';
import 'package:archespace_mobile/src/shared/realtime/table_watcher.dart';
import 'package:archespace_mobile/src/shared/sort/sort.dart';
import 'package:archespace_mobile/src/shared/widgets/action_icon_button.dart';
import 'package:archespace_mobile/src/shared/widgets/add_glyph.dart';
import 'package:archespace_mobile/src/shared/widgets/app_snackbar.dart';
import 'package:archespace_mobile/src/shared/widgets/bulk_action_bar.dart';
import 'package:archespace_mobile/src/shared/widgets/offline_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archespace_mobile/src/shared/widgets/scrollable_message.dart';
import 'package:archespace_mobile/src/shared/widgets/tag_filter_bar.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  List<Space>? _spaces;
  Object? _error;
  bool _offline = false;
  TableWatcher? _watcher;
  bool _selectMode = false;
  final Set<String> _selected = {};
  String _sort = kSortDefault;
  String _view = 'list';
  final Set<String> _activeTags = {};

  @override
  void initState() {
    super.initState();
    _load();
    SharedPreferences.getInstance().then((prefs) {
      final sort = prefs.getString('sort_spaces');
      final view = prefs.getString('spaces_view');
      if (!mounted) return;
      setState(() {
        if (sort != null) _sort = sort;
        if (view == 'grid') _view = 'grid';
      });
    });
    _watcher = TableWatcher(
      channelName: 'spaces-realtime',
      table: 'spaces',
      onChange: _load,
    );
  }

  void _setSort(String value) {
    setState(() => _sort = value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('sort_spaces', value),
    );
  }

  void _setView(String value) {
    setState(() => _view = value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('spaces_view', value),
    );
  }

  bool get _canReorder =>
      !_selectMode && !_offline && _sort == kSortDefault && _activeTags.isEmpty;

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await SpaceRepository(
        VaultSession.instance.masterKey,
      ).listSpaces();
      if (mounted) {
        setState(() {
          _spaces = result.spaces;
          _offline = result.fromCache;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _createSpace() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const SpaceEditorScreen()));
    if (saved == true && mounted) _load();
  }

  Future<void> _togglePinSpace(Space space) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).setPinned(space.id, !space.pinned);
      if (mounted) _load();
    } catch (_) {
      if (mounted) showErrorSnack(context, "Couldn't update the space.");
    }
  }

  // ── Selection mode ──
  void _enterSelect() => setState(() => _selectMode = true);

  void _exitSelect() => setState(() {
    _selectMode = false;
    _selected.clear();
  });

  void _toggleSelect(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _selectAll() => setState(() {
    _selected
      ..clear()
      ..addAll(
        (_spaces ?? const <Space>[])
            .where((s) => s.parentId == null)
            .map((s) => s.id),
      );
  });

  void _snack(String message) {
    if (mounted) showErrorSnack(context, message);
  }

  /// `newIndex` arrives already adjusted for the removed item (onReorderItem).
  void _onReorder(int oldIndex, int newIndex) {
    final list = List<Space>.of(_spaces ?? const []);
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _spaces = list);
    _persistOrder(list);
  }

  Future<void> _persistOrder(List<Space> list) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).reorder(list.map((s) => s.id).toList());
    } catch (_) {
      _snack("Couldn't save the new order.");
      if (mounted) _load();
    }
  }

  /// Reorder by space id (used by the grid's drag-and-drop): move [fromId] into
  /// [toId]'s slot and persist the new order.
  void _moveSpaceById(String fromId, String toId) {
    if (fromId == toId) return;
    final list = List<Space>.of(_spaces ?? const []);
    final from = list.indexWhere((s) => s.id == fromId);
    final to = list.indexWhere((s) => s.id == toId);
    if (from < 0 || to < 0) return;
    final moved = list.removeAt(from);
    list.insert(from < to ? to - 1 : to, moved);
    setState(() => _spaces = list);
    _persistOrder(list);
  }

  Future<void> _runBulk(Future<void> Function(SpaceRepository) op) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    try {
      await op(SpaceRepository(VaultSession.instance.masterKey));
      if (mounted) {
        _exitSelect();
        _load();
      }
    } catch (_) {
      _snack("Couldn't complete that action.");
    }
  }

  Future<void> _bulkDelete() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Move $count ${count == 1 ? 'space' : 'spaces'} to bin?'),
        content: const Text('They and their items go to the recycle bin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Move to bin'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = _selected.toList();
    await _runBulk((r) => r.bulkDelete(ids));
  }

  Future<void> _duplicateSpace(Space space) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).duplicateSpace(space);
      if (mounted) {
        _load();
        showSuccessSnack(context, 'Space duplicated');
      }
    } catch (_) {
      if (mounted) showErrorSnack(context, "Couldn't duplicate the space.");
    }
  }

  Future<void> _archiveSpace(Space space) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).archiveSpace(space.id);
      if (mounted) {
        _load();
        showSuccessSnack(context, 'Space archived');
      }
    } catch (_) {
      if (mounted) showErrorSnack(context, "Couldn't archive the space.");
    }
  }

  Future<void> _editSpace(Space space) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SpaceEditorScreen(existing: space)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _deleteSpace(Space space) async {
    final name = space.name.isEmpty ? 'Untitled' : space.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move space to bin?'),
        content: Text(
          '"$name" and its items will be moved to the recycle bin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Move to bin'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).deleteSpace(space.id);
      if (mounted) _load();
    } catch (_) {
      if (mounted) showErrorSnack(context, "Couldn't delete the space.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _selectMode ? null : const AppDrawer(),
      appBar: _selectMode
          ? AppBar(
              leading: IconButton(
                onPressed: _exitSelect,
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
              ),
              title: Text('${_selected.length} selected'),
              actions: [
                ActionIconButton(
                  icon: Icons.select_all,
                  tooltip: 'Select all',
                  onPressed: _selectAll,
                ),
              ],
            )
          : null,
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: _createSpace,
              tooltip: 'New space',
              child: const AddGlyph(),
            ),
      bottomNavigationBar: _selectMode
          ? BulkActionBar(
              count: _selected.length,
              actions: [
                BulkAction(
                  icon: Icons.push_pin,
                  label: 'Pin',
                  onPressed: () {
                    final ids = _selected.toList();
                    _runBulk((r) => r.bulkSetPinned(ids, true));
                  },
                ),
                BulkAction(
                  icon: Icons.push_pin_outlined,
                  label: 'Unpin',
                  onPressed: () {
                    final ids = _selected.toList();
                    _runBulk((r) => r.bulkSetPinned(ids, false));
                  },
                ),
                BulkAction(
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  onPressed: () {
                    final ids = _selected.toList();
                    _runBulk((r) => r.bulkArchive(ids));
                  },
                ),
                BulkAction(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onPressed: _bulkDelete,
                ),
              ],
            )
          : null,
      body: _spaces == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // No AppBar in normal mode, so this must take the top inset;
              // select mode still has an AppBar handling it.
              top: !_selectMode,
              child: Column(
                children: [
                  // The search bar is the fixed top bar (with the drawer
                  // toggle); the "Spaces" count/actions header and tag filter
                  // scroll with the list (see _body).
                  if (!_selectMode) _buildSearchBar(context),
                  if (_offline) const OfflineBanner(),
                  ValueListenableBuilder<int>(
                    valueListenable: WriteQueue.instance.pending,
                    builder: (context, count, _) => count == 0
                        ? const SizedBox.shrink()
                        : Container(
                            width: double.infinity,
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              '$count change${count == 1 ? '' : 's'} waiting to sync',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: RefreshIndicator(onRefresh: _load, child: _body()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // The drawer toggle lives inside the search bar; Builder gives it
            // a context under this Scaffold so openDrawer() can find it.
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: scheme.onSurfaceVariant),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Search spaces and items',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            // Balances the leading menu button so the placeholder reads centred.
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSpacesHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4, top: 2, bottom: 4),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              children: [
                const TextSpan(text: 'Spaces'),
                TextSpan(
                  text: ' · $count',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ActionIconButton(
            icon: _view == 'grid'
                ? Icons.view_agenda_outlined
                : Icons.grid_view_outlined,
            tooltip: _view == 'grid' ? 'List view' : 'Grid view',
            onPressed: () => _setView(_view == 'grid' ? 'list' : 'grid'),
          ),
          ActionIconButton(
            icon: Icons.checklist,
            tooltip: 'Select',
            onPressed: _enterSelect,
          ),
          SortMenu(value: _sort, onChanged: _setSort),
        ],
      ),
    );
  }

  Widget _body() {
    if (_spaces == null && _error != null) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load your spaces",
        message: 'Something went wrong. Check your connection and try again.',
        actionLabel: 'Retry',
        actionIcon: Icons.refresh,
        onAction: _load,
        destructiveIcon: true,
      );
    }
    // Only top-level spaces on the dashboard; sub-spaces live inside their parent.
    final all = (_spaces ?? const <Space>[])
        .where((s) => s.parentId == null)
        .toList();
    if (all.isEmpty) {
      return StateMessage(
        icon: Icons.workspaces_outline,
        title: 'No spaces yet',
        message: 'Spaces keep your notes and items organized. Create your '
            'first one to get started.',
        actionLabel: 'New space',
        actionIcon: Icons.add,
        onAction: _createSpace,
      );
    }
    final allTags = <String>{for (final s in all) ...s.tags}.toList()..sort();
    final filtered = _activeTags.isEmpty
        ? all
        : all.where((s) => s.tags.any(_activeTags.contains)).toList();
    final spaces = applySort(
      filtered,
      _sort,
      name: (s) => s.name,
      createdAt: (s) => s.createdAt,
      pinned: (s) => s.pinned,
    );
    // The count/actions header and tag filter scroll with the list, and are
    // hidden while selecting (the app bar shows the selection state instead).
    final headerChildren = <Widget>[];
    if (!_selectMode) {
      headerChildren.add(
        _buildSpacesHeader(context, (_spaces ?? const <Space>[]).length),
      );
      if (allTags.isNotEmpty) headerChildren.add(_tagFilterBar(allTags));
    }
    final header = headerChildren.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: headerChildren,
          );

    return _view == 'grid'
        ? _grid(spaces, header: header)
        : ReorderableListView.builder(
            header: header,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 88),
            buildDefaultDragHandles: _canReorder,
            onReorderItem: _onReorder,
            itemCount: spaces.length,
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey(spaces[index].id),
              child: _spaceCard(spaces[index]),
            ),
          );
  }

  Widget _tagFilterBar(List<String> allTags) {
    return compactTagFilterBar(
      context: context,
      allTags: allTags,
      activeTags: _activeTags,
      onChanged: () => setState(() {}),
    );
  }

  /// Two-column masonry grid. Cards keep their natural height (round-robin
  /// distribution); when reordering is allowed each is a long-press draggable
  /// and a drop target, persisting the new order like the list view.
  Widget _grid(List<Space> spaces, {Widget? header}) {
    final canReorder = _canReorder;
    final columns = <List<Widget>>[<Widget>[], <Widget>[]];
    for (var i = 0; i < spaces.length; i++) {
      columns[i % 2].add(_gridCard(spaces[i], canReorder));
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: columns[0])),
              Expanded(child: Column(children: columns[1])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridCard(Space space, bool canReorder) {
    final card = _spaceCard(space, margin: const EdgeInsets.all(2));
    if (!canReorder) {
      return KeyedSubtree(key: ValueKey(space.id), child: card);
    }
    return DragTarget<String>(
      key: ValueKey(space.id),
      onWillAcceptWithDetails: (d) => d.data != space.id,
      onAcceptWithDetails: (d) => _moveSpaceById(d.data, space.id),
      builder: (context, candidate, rejected) {
        final over = candidate.isNotEmpty;
        return LongPressDraggable<String>(
          data: space.id,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 2 - 16,
              child: Opacity(opacity: 0.95, child: card),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: over
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: card,
          ),
        );
      },
    );
  }

  Widget _spaceCard(Space space, {EdgeInsetsGeometry? margin}) => SpaceCard(
    space: space,
    margin: margin,
    selectMode: _selectMode,
    selected: _selected.contains(space.id),
    onSelectToggle: () => _toggleSelect(space.id),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SpaceDetailScreen(space: space)),
    ),
    onTogglePin: () => _togglePinSpace(space),
    onEdit: () => _editSpace(space),
    onDuplicate: () => _duplicateSpace(space),
    onArchive: () => _archiveSpace(space),
    onDelete: () => _deleteSpace(space),
    activeTags: _activeTags,
    onTagClick: (tag) => setState(() {
      if (!_activeTags.remove(tag)) _activeTags.add(tag);
    }),
  );
}
