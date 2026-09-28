import 'package:flutter/material.dart';

/// The "New space" and "Add item" floating buttons, stacked and styled alike:
/// New space above, Add item in the primary (lowest, thumb-reach) spot. Pass
/// no [onNewSpace] to show only Add item (e.g. inside a sub-space, which can't
/// hold further spaces).
class CreateFabs extends StatelessWidget {
  const CreateFabs({super.key, required this.onAddItem, this.onNewSpace});

  final VoidCallback onAddItem;
  final VoidCallback? onNewSpace;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onNewSpace != null) ...[
          FloatingActionButton(
            // Two FABs on one screen need distinct hero tags.
            heroTag: 'fab-new-space',
            onPressed: onNewSpace,
            tooltip: 'New space',
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: 'fab-add-item',
          onPressed: onAddItem,
          tooltip: 'Add item',
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}
