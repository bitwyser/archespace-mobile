import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/shared/widgets/action_icon_button.dart';

const String kSortDefault = 'default';
const String kSortName = 'name';
const String kSortNewest = 'newest';

/// Sort [list] by [mode]. Pinned entries always stay on top (matching the web),
/// then name (case-insensitive) or newest (created_at descending). `default`
/// keeps the incoming (position) order.
List<T> applySort<T>(
  List<T> list,
  String mode, {
  required String Function(T) name,
  required DateTime? Function(T) createdAt,
  required bool Function(T) pinned,
}) {
  if (mode == kSortDefault) return list;
  final sorted = List<T>.of(list);
  sorted.sort((a, b) {
    final pa = pinned(a);
    final pb = pinned(b);
    if (pa != pb) return pa ? -1 : 1;
    if (mode == kSortName) {
      return name(a).toLowerCase().compareTo(name(b).toLowerCase());
    }
    final ca = createdAt(a);
    final cb = createdAt(b);
    if (ca == null && cb == null) return 0;
    if (ca == null) return 1;
    if (cb == null) return -1;
    return cb.compareTo(ca); // newest first
  });
  return sorted;
}

/// App-bar sort dropdown with a check on the active option.
class SortMenu extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ActionIconButton(
      icon: Icons.sort,
      tooltip: 'Sort',
      size: size,
      onPressed: () => _open(context),
    );
  }

  /// Open the sort menu anchored to the button, so the trigger can be the same
  /// circular ActionIconButton used by the other app-bar actions.
  Future<void> _open(BuildContext context) async {
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _sortItem(kSortDefault, 'Default'),
        _sortItem(kSortName, 'Name'),
        _sortItem(kSortNewest, 'Newest'),
      ],
    );
    if (selected != null) onChanged(selected);
  }

  /// A compact menu row (matching the 3-dot action menus) with an inline check
  /// on the active option instead of a bulkier CheckedPopupMenuItem.
  PopupMenuItem<String> _sortItem(String option, String label) {
    return PopupMenuItem<String>(
      value: option,
      height: 40,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value == option) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }
}
