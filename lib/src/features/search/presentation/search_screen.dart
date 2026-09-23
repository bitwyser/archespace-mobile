import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/search/data/search_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_detail_screen.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/widgets/scrollable_message.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SearchHit>? _all;
  Object? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final hits = await SearchRepository(
        VaultSession.instance.masterKey,
      ).loadIndex();
      if (mounted) setState(() => _all = hits);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _open(SearchHit hit) {
    final space = Space(
      id: hit.spaceId,
      name: hit.spaceName.isEmpty ? hit.title : hit.spaceName,
      description: '',
      pinned: false,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpaceDetailScreen(
          space: space,
          focusItemId: hit.isSpace ? null : hit.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search spaces and items',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _all == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(top: false, child: _results()),
    );
  }

  Widget _results() {
    if (_all == null && _error != null) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Search unavailable',
        message: 'Something went wrong. Check your connection and try again.',
        actionLabel: 'Retry',
        actionIcon: Icons.refresh,
        onAction: _load,
        destructiveIcon: true,
      );
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return const StateMessage(
        icon: Icons.search,
        title: 'Search your vault',
        message: 'Find spaces and items by name, tag, or content.',
      );
    }
    final matches = _all!.where((h) => h.haystack.contains(q)).toList();
    final spaces = matches.where((h) => h.isSpace).toList();
    final items = matches.where((h) => !h.isSpace).toList();
    if (matches.isEmpty) {
      return StateMessage(
        icon: Icons.search_off,
        title: 'No results',
        message: 'Nothing matched "${_query.trim()}". Try a different term.',
      );
    }
    return ListView(
      children: [
        if (spaces.isNotEmpty) const _Header('Spaces'),
        for (final hit in spaces)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(hit.title.isEmpty ? 'Untitled' : hit.title),
            onTap: () => _open(hit),
          ),
        if (items.isNotEmpty) const _Header('Items'),
        for (final hit in items)
          ListTile(
            leading: Icon(itemTypeDef(hit.type)?.icon ?? Icons.notes),
            title: Text(hit.title.isEmpty ? 'Untitled' : hit.title),
            subtitle: hit.spaceName.isEmpty
                ? null
                : Text('in ${hit.spaceName}'),
            onTap: () => _open(hit),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
