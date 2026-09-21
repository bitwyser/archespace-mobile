import 'package:flutter/material.dart';

/// Definition of an item type: label, icon, and whether a mobile editor exists
/// yet. Editors are being added one type at a time; [editable] gates which
/// types show in the "add item" picker and open for editing on tap.
class ItemTypeDef {
  const ItemTypeDef({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    this.editable = false,
  });

  final String type;
  final String label;
  final String description;
  final IconData icon;

  /// Accent colour for this type (badge + add-menu icon), matching the web's
  /// per-type palette.
  final Color color;
  final bool editable;
}

const List<ItemTypeDef> kItemTypes = [
  ItemTypeDef(
    type: 'textbox',
    label: 'Note',
    description: 'Free-form plain text',
    icon: Icons.notes,
    color: Color(0xFF60A5FA), // blue
    editable: true,
  ),
  ItemTypeDef(
    type: 'richtext',
    label: 'Rich Text',
    description: 'Formatted text - bold, italic, underline, font size',
    icon: Icons.text_fields,
    color: Color(0xFFFB7185), // rose
    editable: true,
  ),
  ItemTypeDef(
    type: 'markdown',
    label: 'Markdown',
    description: 'Rich text with markdown',
    icon: Icons.code,
    color: Color(0xFF2DD4BF), // teal
    editable: true,
  ),
  ItemTypeDef(
    type: 'menu_list',
    label: 'List',
    description: 'Simple bullet list',
    icon: Icons.list,
    color: Color(0xFFC084FC), // purple
    editable: true,
  ),
  ItemTypeDef(
    type: 'numbered_list',
    label: 'Numbered list',
    description: 'Ordered list',
    icon: Icons.format_list_numbered,
    color: Color(0xFFF472B6), // pink
    editable: true,
  ),
  ItemTypeDef(
    type: 'checkbox_list',
    label: 'Checklist',
    description: 'Items with checkboxes',
    icon: Icons.checklist,
    color: Color(0xFF4ADE80), // green
    editable: true,
  ),
  ItemTypeDef(
    type: 'card_list',
    label: 'Cards',
    description: 'Title and description pairs',
    icon: Icons.view_agenda_outlined,
    color: Color(0xFFFBBF24), // amber
    editable: true,
  ),
  ItemTypeDef(
    type: 'table',
    label: 'Table',
    description: 'Rows and columns of text',
    icon: Icons.table_chart_outlined,
    color: Color(0xFF38BDF8), // sky
    editable: true,
  ),
  ItemTypeDef(
    type: 'secret',
    label: 'Secret',
    description: 'PIN-protected hidden text',
    icon: Icons.lock_outline,
    color: Color(0xFF818CF8), // indigo
    editable: true,
  ),
  ItemTypeDef(
    type: 'draw',
    label: 'Drawing',
    description: 'Freehand sketch',
    icon: Icons.brush_outlined,
    color: Color(0xFFE879F9), // fuchsia
    editable: true,
  ),
  ItemTypeDef(
    type: 'code',
    label: 'Code',
    description: 'Code snippet with syntax highlighting',
    icon: Icons.data_object,
    color: Color(0xFFFB923C), // orange
    editable: true,
  ),
  ItemTypeDef(
    type: 'authenticator',
    label: 'Authenticator',
    description: 'Two-factor (TOTP) codes for your accounts',
    icon: Icons.shield_outlined,
    color: Color(0xFF34D399), // emerald
    editable: true,
  ),
];

ItemTypeDef? itemTypeDef(String type) {
  for (final def in kItemTypes) {
    if (def.type == type) return def;
  }
  return null;
}

bool isEditableType(String type) => itemTypeDef(type)?.editable ?? false;

/// The starting content for a newly created item, matching the web defaults.
Map<String, dynamic> defaultContentFor(String type) {
  switch (type) {
    case 'textbox':
    case 'markdown':
      return {'text': ''};
    case 'richtext':
      return {'html': ''};
    case 'code':
      return {'code': ''};
    case 'menu_list':
    case 'numbered_list':
    case 'card_list':
      return {'items': <dynamic>[]};
    case 'checkbox_list':
      return {
        'items': [
          {'id': _newId(), 'text': '', 'checked': false},
        ],
      };
    case 'table':
      return {
        'columns': ['', ''],
        'rows': [
          ['', ''],
          ['', ''],
        ],
      };
    case 'secret':
      return {'secret': true, 'cipher': ''};
    case 'draw':
      return {'strokes': <dynamic>[]};
    case 'authenticator':
      return {'entries': <dynamic>[]};
    default:
      return <String, dynamic>{};
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
