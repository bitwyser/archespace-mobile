# ArcheSpace logo usage (mobile)

The "A" mark is the app icon, and it appears only as an icon (shared with the
web app; see the web repo's `LOGO.md`). Everywhere else the name is plain text:
"ArcheSpace".

## Where the "A" appears

| Context             | Form                         |
| ------------------- | ---------------------------- |
| Launcher icon       | Mint mark on a dark square   |

## Where the name is text

The README writes "ArcheSpace" as text, and so does the app-open screen above
its tagline. The PDF export carries no brand, only the site URL in its
top-right corner. No screen in the app shows the logo.

## Assets

- `assets/icon/app_icon.png` - the launcher icon (the source for
  `flutter_launcher_icons`; not bundled into the app).
- `assets/icon/app_icon_foreground.png` - the adaptive icon's foreground (see
  `flutter_launcher_icons` in `pubspec.yaml`).
