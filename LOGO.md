# ArcheSpace logo usage (mobile)

The "A" mark is the app icon, and it appears only as an icon (shared with the
web app; see the web repo's `LOGO.md`). Everywhere else the name is plain text:
"ArcheSpace".

## Where the "A" appears

| Context             | Form                         |
| ------------------- | ---------------------------- |
| Launcher icon       | Mint mark on a dark square   |
| Splash screen       | The app icon (76, rounded) above the name |

## Where the name is text

The README writes "ArcheSpace" as text. The PDF export carries no brand, only
the site URL in its top-right corner. The app's other screens show no logo.

## Assets

- `assets/icon/app_icon.png` - the launcher icon, also bundled for the splash
  screen.
- `assets/icon/app_icon_foreground.png` - the adaptive icon's foreground (see
  `flutter_launcher_icons` in `pubspec.yaml`).
