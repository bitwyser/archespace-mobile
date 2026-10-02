/// A decrypted item within a space. [content] is the decrypted JSON object,
/// whose shape depends on [type] (see the web item type definitions).
class SpaceItem {
  SpaceItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.pinned,
    this.starred = false,
    this.locked = false,
    this.spaceId,
    this.tags = const [],
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final Map<String, dynamic> content;
  final bool pinned;

  /// In the Starred view. A quick-access flag only: it never affects order.
  final bool starred;

  /// Protected: the title and tags show, but the content needs the vault PIN
  /// (see ContentLock). A flag only; the content is encrypted as always.
  final bool locked;

  /// The item's space, or null for a dashboard item. Always read from the row,
  /// so a screen showing items from many spaces (Starred) saves each one back
  /// to its own space.
  final String? spaceId;
  final List<String> tags;
  final DateTime? createdAt;
}
