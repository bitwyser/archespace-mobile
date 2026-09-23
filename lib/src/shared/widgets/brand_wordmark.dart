import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/shared/brand/brand_paths.dart';

/// The full ArcheSpace wordmark: "Arche" in the accent colour and "Space" in
/// the theme text colour. Built from inline SVG so both tones recolour live
/// with the accent and light/dark theme. [height] sizes it; the width follows
/// the wordmark's aspect ratio.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = 24,
    this.archeColor,
    this.spaceColor,
  });

  final double height;

  /// Colour of the "Arche" half; defaults to the current accent.
  final Color? archeColor;

  /// Colour of the "Space" half; defaults to the theme's onSurface.
  final Color? spaceColor;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final arche = archeColor ?? AppearanceController.instance.accent;
    final space = spaceColor ?? Theme.of(context).colorScheme.onSurface;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$kBrandWordmarkViewBox">'
        '<path d="$kBrandArchePath" fill="${_hex(arche)}" fill-rule="evenodd"/>'
        '<path d="$kBrandSpacePath" fill="${_hex(space)}" fill-rule="evenodd"/>'
        '</svg>';
    return SvgPicture.string(svg, height: height, semanticsLabel: 'ArcheSpace');
  }
}
