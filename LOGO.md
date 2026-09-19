# ArcheSpace logo usage (mobile)

Two lockups, one system - shared with the web app. Use them consistently; the
same widget, the same sizes per context. Don't restyle the logo per screen.

## The two variants

- **Full wordmark** - the whole `ArcheSpace` name. "Arche" (with the mark) uses
  the current accent; "Space" follows the theme text colour (white on dark,
  ink on light). Widget: `BrandWordmark(height: ...)`. Default brand
  presentation.
- **Short mark** - the "A" glyph only. Use it when width is constrained or the
  wordmark would fall below its minimum size. Widget: `BrandGlyph(size: ...)`.

## Sizes (visible glyph height)

| Context                         | Variant | Height          |
| ------------------------------- | ------- | --------------- |
| App bar / top bar               | Full    | 24 (`BrandWordmark(height: 24)`) |
| Auth / login                    | Full    | 40 (`BrandWordmark(height: 40)`) |
| Splash / hero                   | Full    | 46 (`BrandWordmark(height: 46)`) |
| Launcher / app icon             | Short (rounded square) | per platform |

## Rules

1. **Optical sizing** - match the logo to neighbouring heavy text by visible
   cap height, not the bounding box.
2. **Minimum size** - don't render the wordmark below ~16 tall; use the short
   mark instead.
3. **Icon fallback** - when width is tight, use the short mark.
4. **Clear space** - keep padding around the logo at least equal to the mark's
   height.
5. **Contrast** - "Space" is white on dark, ink on light, and must clear ~3:1
   against its background.
6. **The badge is only for the launcher icon** - in-UI marks are the bare glyph.
7. **Reuse the widgets** - never hand-roll a logo or a one-off size.

## Assets

- README banner: `assets/archespace-logo.svg` (dark: Arche mint / Space white)
  and `assets/archespace-logo-light.svg` (light: Arche mint / Space ink), 360px.
