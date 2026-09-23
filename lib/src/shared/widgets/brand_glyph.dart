import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/shared/brand/brand_paths.dart';

/// The standalone ArcheSpace "A" mark (the same glyph used for the launcher
/// icon), rendered in the accent colour by default. Built from an inline SVG so
/// it recolours live when the accent changes.
///
/// With [framed] it sits inside a rounded-square outline in the accent colour
/// (an app-icon style badge); [size] is then the outer frame and the mark is
/// inset within it.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({super.key, this.size = 72, this.color, this.framed = false});

  final double size;

  /// Fill colour for the mark; defaults to the current accent.
  final Color? color;

  /// Wrap the mark in a rounded-square accent border.
  final bool framed;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppearanceController.instance.accent;
    // Inside a frame the mark is inset so the border reads as a badge.
    final markSize = framed ? size * 0.62 : size;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$kBrandGlyphViewBox">'
        '<path d="$kBrandAPath" fill="${_hex(fill)}" fill-rule="evenodd"/>'
        '</svg>';
    final mark = SvgPicture.string(
      svg,
      width: markSize,
      height: markSize,
      semanticsLabel: 'ArcheSpace',
    );
    if (!framed) return mark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: fill, width: size >= 44 ? 2 : 1.5),
      ),
      child: mark,
    );
  }
}
