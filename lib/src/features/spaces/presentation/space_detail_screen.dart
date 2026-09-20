import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:archespace_mobile/src/features/items/data/item_repository.dart';
import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_card.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_editor_screen.dart';
import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_editor_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/widgets/space_card.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/export/pdf_exporter.dart';
import 'package:archespace_mobile/src/shared/realtime/table_watcher.dart';
import 'package:archespace_mobile/src/shared/sort/sort.dart';
import 'package:archespace_mobile/src/shared/widgets/action_icon_button.dart';
import 'package:archespace_mobile/src/shared/widgets/bulk_action_bar.dart';
import 'package:archespace_mobile/src/shared/widgets/confirm_dialog.dart';
import 'package:archespace_mobile/src/shared/widgets/offline_banner.dart';
import 'package:archespace_mobile/src/shared/widgets/scrollable_message.dart';
import 'package:archespace_mobile/src/shared/widgets/tag_filter_bar.dart';

class SpaceDetailScreen extends StatefulWidget {
  const SpaceDetailScreen({super.key, required this.space, this.focusItemId});

  final Space space;

  /// When set, the screen scrolls to this item and briefly highlights it
  /// (used by search's jump-to-item).
  final String? focusItemId;

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  List<SpaceItem>? _items;
  List<Space> _subSpaces = const [];
  Object? _error;
  bool _offline = false;
  TableWatcher? _watcher;
  final GlobalKey _focusKey = GlobalKey();
  String? _flashId;
  bool _focusHandled = false;
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
      final saved = prefs.getString('sort_items');
      final view = prefs.getString('items_view');
      if (!mounted) return;
      setState(() {
        if (saved != null) _sort = saved;
        if (view == 'grid') _view = 'grid';
      });
    });
    _watcher = TableWatcher(
      channelName: 'items-${widget.space.id}',
      table: 'space_items',
      filterColumn: 'space_id',
      filterValue: widget.space.id,
      onChange: _load,
    );
  }

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await ItemRepository(
        VaultSession.instance.masterKey,
      ).listItems(widget.space.id);
      // Sub-spaces (one-level nesting): only a top-level space can have them.
      List<Space> subs = const [];
      if (widget.space.parentId == null) {
        try {
          subs = await SpaceRepository(
            VaultSession.instance.masterKey,
          ).listSubSpaces(widget.space.id);
        } catch (_) {
          // Non-fatal: items still load without the sub-space list.
        }
      }
      if (mounted) {
        setState(() {
          _items = result.items;
          _subSpaces = subs;
          _offline = result.fromCache;
          _error = null;
        });
      }
      if (widget.focusItemId != null && !_focusHandled && mounted) {
        _focusHandled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocus());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _revealFocus() {
    final ctx = _focusKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        alignment: 0.1,
      );
    }
    setState(() => _flashId = widget.focusItemId);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  Future<void> _createSubSpace() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SpaceEditorScreen(parentId: widget.space.id),
      ),
    );
    if (created == true && mounted) _load();
  }

  void _openSubSpace(Space sub) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SpaceDetailScreen(space: sub),
          ),
        )
        .then((_) {
          if (mounted) _load();
        });
  }

  Future<void> _subSpaceOp(
    Future<void> Function(SpaceRepository) op,
    String errorMsg,
  ) async {
    try {
      await op(SpaceRepository(VaultSession.instance.masterKey));
      if (mounted) _load();
    } catch (_) {
      _showError(errorMsg);
    }
  }

  Future<void> _editSubSpace(Space sub) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SpaceEditorScreen(existing: sub)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _deleteSubSpace(Space sub) async {
    final ok = await confirmAction(
      context,
      title: 'Move space to recycle bin?',
      message: 'This space and all its items will be moved to the recycle bin.',
      confirmLabel: 'Move to recycle bin',
      destructive: true,
    );
    if (ok) {
      await _subSpaceOp(
        (r) => r.deleteSpace(sub.id),
        "Couldn't delete the space.",
      );
    }
  }

  Widget _subSpaceCard(Space sub) => SpaceCard(
    space: sub,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    onTap: () => _openSubSpace(sub),
    onTogglePin: () => _subSpaceOp(
      (r) => r.setPinned(sub.id, !sub.pinned),
      "Couldn't update the space.",
    ),
    onEdit: () => _editSubSpace(sub),
    onDuplicate: () => _subSpaceOp(
      (r) => r.duplicateSpace(sub),
      "Couldn't duplicate the space.",
    ),
    onArchive: () => _subSpaceOp(
      (r) => r.archiveSpace(sub.id),
      "Couldn't archive the space.",
    ),
    onDelete: () => _deleteSubSpace(sub),
  );

  Future<void> _editItem(SpaceItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditorScreen(
          spaceId: widget.space.id,
          type: item.type,
          existing: item,
        ),
      ),
    );
    if (saved == true && mounted) _load();
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
      ..addAll((_items ?? const <SpaceItem>[]).map((i) => i.id));
  });

  void _setSort(String value) {
    setState(() => _sort = value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('sort_items', value),
    );
  }

  void _setView(String value) {
    setState(() => _view = value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('items_view', value),
    );
  }

  /// `newIndex` arrives already adjusted for the removed item (onReorderItem).
  void _onReorder(int oldIndex, int newIndex) {
    final list = List<SpaceItem>.of(_items ?? const []);
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _items = list);
    _persistOrder(list);
  }

  Future<void> _persistOrder(List<SpaceItem> list) async {
    try {
      await ItemRepository(
        VaultSession.instance.masterKey,
      ).reorder(list.map((i) => i.id).toList());
    } catch (_) {
      _showError("Couldn't save the new order.");
      if (mounted) _load();
    }
  }

  Future<void> _runBulk(Future<void> Function(ItemRepository) op) async {
    if (_selected.isEmpty) return;
    try {
      await op(ItemRepository(VaultSession.instance.masterKey));
      if (mounted) {
        _exitSelect();
        _load();
      }
    } catch (_) {
      _showError("Couldn't complete that action.");
    }
  }

  Future<void> _bulkDeleteItems() async {
    final ids = _selected.toList();
    await _runBulk((r) => r.bulkDelete(ids));
  }

  Future<void> _bulkMoveItems() async {
    List<Space> spaces;
    try {
      spaces = (await SpaceRepository(
        VaultSession.instance.masterKey,
      ).listSpaces()).spaces;
    } catch (_) {
      _showError("Couldn't load spaces.");
      return;
    }
    final destinations = spaces.where((s) => s.id != widget.space.id).toList();
    if (!mounted) return;
    if (destinations.isEmpty) {
      _showError('No other space to move to.');
      return;
    }
    final target = await showModalBottomSheet<Space>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Move to space',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final s in destinations)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(s.name.isEmpty ? 'Untitled' : s.name),
                onTap: () => Navigator.pop(sheetContext, s),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    final ids = _selected.toList();
    await _runBulk((r) => r.bulkMove(ids, target.id));
  }

  Future<void> _togglePinItem(SpaceItem item) async {
    try {
      await ItemRepository(
        VaultSession.instance.masterKey,
      ).setPinned(item.id, !item.pinned);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update the item.")),
        );
      }
    }
  }

  Future<void> _duplicateItem(SpaceItem item) async {
    try {
      await ItemRepository(
        VaultSession.instance.masterKey,
      ).duplicateItem(widget.space.id, item);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item duplicated')));
      }
    } catch (_) {
      _showError("Couldn't duplicate the item.");
    }
  }

  Future<void> _moveItem(SpaceItem item) async {
    List<Space> spaces;
    try {
      spaces = (await SpaceRepository(
        VaultSession.instance.masterKey,
      ).listSpaces()).spaces;
    } catch (_) {
      _showError("Couldn't load spaces.");
      return;
    }
    final destinations = spaces.where((s) => s.id != widget.space.id).toList();
    if (!mounted) return;
    if (destinations.isEmpty) {
      _showError('No other space to move to.');
      return;
    }
    final target = await showModalBottomSheet<Space>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Move to space',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final s in destinations)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(s.name.isEmpty ? 'Untitled' : s.name),
                onTap: () => Navigator.pop(sheetContext, s),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    try {
      await ItemRepository(
        VaultSession.instance.masterKey,
      ).moveItem(item.id, target.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Moved to ${target.name}')));
      }
    } catch (_) {
      _showError("Couldn't move the item.");
    }
  }

  Future<void> _archiveItem(SpaceItem item) async {
    try {
      await ItemRepository(
        VaultSession.instance.masterKey,
      ).archiveItem(item.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item archived')));
      }
    } catch (_) {
      _showError("Couldn't archive the item.");
    }
  }

  Future<void> _deleteItem(SpaceItem item) async {
    final name = item.title.isEmpty ? 'this item' : '"${item.title}"';
    final ok = await confirmAction(
      context,
      title: 'Move item to bin?',
      message: '$name will be moved to the recycle bin.',
      confirmLabel: 'Move to bin',
    );
    if (!ok) return;
    try {
      await ItemRepository(VaultSession.instance.masterKey).deleteItem(item.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item moved to recycle bin')),
        );
      }
    } catch (_) {
      _showError("Couldn't delete the item.");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _fileName(String name) {
    final safe = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    return '${safe.isEmpty ? 'export' : safe}.pdf';
  }

  Future<void> _exportSpace() => _export(
    build: () => PdfExporter.buildSpace(widget.space.name, _items ?? const []),
    filename: _fileName(widget.space.name),
    label: 'space',
  );

  Future<void> _exportItem(SpaceItem item) => _export(
    build: () => PdfExporter.buildItem(item),
    filename: _fileName(item.title),
    label: 'item',
  );

  /// Build the PDF behind a progress spinner (so a large space doesn't look
  /// like a frozen screen), then hand it to the share sheet. Any failure is
  /// surfaced instead of silently doing nothing.
  Future<void> _export({
    required Future<Uint8List> Function() build,
    required String filename,
    required String label,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      // Yield a frame so the spinner paints before the (synchronous) PDF build.
      await Future<void>.delayed(Duration.zero);
      final bytes = await build();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError("Couldn't export the $label: $e");
    }
  }

  Future<void> _addItem(String type) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditorScreen(spaceId: widget.space.id, type: type),
      ),
    );
    if (saved == true && mounted) _load();
  }

  void _openAddSheet() {
    // Scroll-controlled with a fixed ~70% height so it opens taller than the
    // default half sheet but not full screen; the list scrolls within it. The
    // tiles are dense to keep the menu compact.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.7,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              for (final def in kItemTypes.where((d) => d.editable))
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(def.icon),
                  title: Text(def.label),
                  subtitle: Text(def.description),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _addItem(def.type);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A compact app-bar icon action with a consistent circular tap splash.
  Widget _barAction(IconData icon, String tooltip, VoidCallback onPressed) =>
      ActionIconButton(icon: icon, tooltip: tooltip, onPressed: onPressed);

  @override
  Widget build(BuildContext context) {
    final hasItems = (_items ?? const <SpaceItem>[]).isNotEmpty;
    return Scaffold(
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
          : AppBar(
              titleSpacing: 0,
              title: Text(
                widget.space.name.isEmpty ? 'Untitled' : widget.space.name,
              ),
              actions: [
                // Wait until items have loaded so the actions all appear at
                // once, rather than this one showing during the load.
                // Sub-spaces (one-level): only a top-level space can create them.
                if (_items != null &&
                    !_selectMode &&
                    widget.space.parentId == null)
                  _barAction(
                    Icons.create_new_folder_outlined,
                    'New space',
                    _createSubSpace,
                  ),
                if (hasItems)
                  _barAction(
                    _view == 'grid'
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_outlined,
                    _view == 'grid' ? 'List view' : 'Grid view',
                    () => _setView(_view == 'grid' ? 'list' : 'grid'),
                  ),
                if (hasItems)
                  _barAction(Icons.checklist, 'Select', _enterSelect),
                if (hasItems) SortMenu(value: _sort, onChanged: _setSort),
                if (hasItems)
                  _barAction(
                    Icons.picture_as_pdf_outlined,
                    'Export PDF',
                    _exportSpace,
                  ),
                const SizedBox(width: 4),
              ],
            ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: _openAddSheet,
              tooltip: 'Add item',
              child: const Icon(Icons.add),
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
                  icon: Icons.drive_file_move_outlined,
                  label: 'Move',
                  onPressed: _bulkMoveItems,
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
                  onPressed: _bulkDeleteItems,
                ),
              ],
            )
          : null,
      body: _items == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_offline) const OfflineBanner(),
                  Expanded(
                    child: RefreshIndicator(onRefresh: _load, child: _body()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _body() {
    if (_items == null && _error != null) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load items",
        message: 'Something went wrong. Check your connection and try again.',
        actionLabel: 'Retry',
        actionIcon: Icons.refresh,
        onAction: _load,
        destructiveIcon: true,
      );
    }
    final all = _items ?? const <SpaceItem>[];
    // Sub-spaces render above the items in the same view (matching the web),
    // hidden while selecting items.
    final subSection = (_subSpaces.isEmpty || _selectMode)
        ? null
        : Column(children: [for (final s in _subSpaces) _subSpaceCard(s)]);
    if (all.isEmpty && subSection == null) {
      return StateMessage(
        icon: Icons.note_add_outlined,
        title: 'No items yet',
        message: 'Add notes, lists, secrets, and more to this space.',
        actionLabel: 'Add item',
        actionIcon: Icons.add,
        onAction: _openAddSheet,
      );
    }
    final allTags = <String>{for (final i in all) ...i.tags}.toList()..sort();
    final filtered = _activeTags.isEmpty
        ? all
        : all.where((i) => i.tags.any(_activeTags.contains)).toList();
    final items = applySort(
      filtered,
      _sort,
      name: (i) => i.title,
      createdAt: (i) => i.createdAt,
      pinned: (i) => i.pinned,
    );
    final Widget list = _view == 'grid'
        ? _grid(items, header: subSection)
        : ReorderableListView.builder(
            header: subSection,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 88),
            buildDefaultDragHandles:
                !_selectMode &&
                !_offline &&
                _sort == kSortDefault &&
                _activeTags.isEmpty,
            onReorderItem: _onReorder,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isFocus = item.id == widget.focusItemId;
              return AnimatedContainer(
                key: ValueKey(item.id),
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _flashId == item.id
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                child: KeyedSubtree(
                  key: isFocus ? _focusKey : null,
                  child: _itemCard(item, margin: EdgeInsets.zero),
                ),
              );
            },
          );
    // Hide the tag filter bar while selecting items.
    if (allTags.isEmpty || _selectMode) return list;
    return Column(
      children: [
        _tagFilterBar(allTags),
        Expanded(child: list),
      ],
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

  Future<void> _setTags(SpaceItem item, List<String> tags) async {
    // Optimistic: reflect the change immediately, then persist.
    setState(() {
      _items = _items
          ?.map(
            (i) => i.id == item.id
                ? SpaceItem(
                    id: i.id,
                    type: i.type,
                    title: i.title,
                    content: i.content,
                    pinned: i.pinned,
                    tags: tags,
                    createdAt: i.createdAt,
                  )
                : i,
          )
          .toList();
    });
    try {
      await ItemRepository(
        VaultSession.instance.masterKey,
      ).setTags(item.id, tags);
    } catch (_) {
      if (mounted) _load(); // revert to server truth on failure
    }
  }

  /// Two-column masonry grid: items are distributed round-robin so each keeps
  /// its natural height (no reordering in this view).
  Widget _grid(List<SpaceItem> items, {Widget? header}) {
    final columns = <List<Widget>>[<Widget>[], <Widget>[]];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isFocus = item.id == widget.focusItemId;
      columns[i % 2].add(
        AnimatedContainer(
          key: ValueKey(item.id),
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _flashId == item.id
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: KeyedSubtree(
            key: isFocus ? _focusKey : null,
            child: _itemCard(item, margin: const EdgeInsets.all(4), grid: true),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 88),
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

  Widget _itemCard(
    SpaceItem item, {
    EdgeInsetsGeometry? margin,
    bool grid = false,
  }) => ItemCard(
    item: item,
    margin: margin,
    grid: grid,
    selectMode: _selectMode,
    selected: _selected.contains(item.id),
    onSelectToggle: () => _toggleSelect(item.id),
    onTap: isEditableType(item.type) ? () => _editItem(item) : null,
    onTogglePin: () => _togglePinItem(item),
    onDuplicate: () => _duplicateItem(item),
    onMove: () => _moveItem(item),
    onArchive: () => _archiveItem(item),
    onExport: () => _exportItem(item),
    onDelete: () => _deleteItem(item),
    onSetTags: _offline ? null : (tags) => _setTags(item, tags),
  );
}
