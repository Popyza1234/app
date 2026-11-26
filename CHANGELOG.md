# Changelog

All notable user-facing changes are documented in this file.

## [2.2 Beta 1] - 2026-11-26

### Added

- iOS 27.0–27.2.1 support through the `worse_query` route, including iOS 27.0.1 and 27.1.
- Access-route reporting in Settings and the support views (`kernel`, `bad_query`, `worse_query`, AirLift, unsupported).
- **Unlock iOS Repo**, an opt-in Settings switch that allows installing repository packages on iOS versions their author did not declare.
- Previous session logs: Logs keeps the last five sessions and can open and share each one.

### Changed

- Support ranges now match 2.2: iOS 17.0–17.7.x, iOS 18.0–18.7.1, iOS 26.0–26.7.2 and iOS 27.0–27.2.1.
- The kernel exploit only runs on iOS 17–18.0–18.7.1; `bad_query` and `worse_query` builds no longer attempt it at launch.
- App metadata is now 2.2 Beta 1 (build 15).

### Compatibility

- Verified ranges: iOS 17.0–17.7.x, iOS 18.0–18.7.1, iOS 26.0–26.7.2, iOS 27.0–27.2.1.
- iOS 18.7.2–18.7.10 requires AirLift and is reported as unsupported by this build.
- AirLift pairing, Apple Wallet backgrounds, keypad themes, system-feature installers and license activation from the 2.2 IPA are not included in this source build.

## [1.0.1] - 2026-08-15

### Added

- Bundle-tree Patch workspace v2 under `On My iPhone/3105/Patches`, synchronized automatically when applying or exporting.
- Multiple independent Files tabs with preserved navigation state.
- ZIP extraction with path, symbolic-link, CRC, and available-space validation.
- Responsive iPad split-view and landscape navigation.
- Home toggles for showing or hiding Cleaner and Wallpaper features.

### Changed

- Patch creation from an app-container file or folder now captures the stable bundle identifier and editable destination tree automatically.
- Patch package imports no longer use the previous fixed payload-size or file-count ceiling; practical device storage and memory still apply.
- Files and Patch screens now use consistent grouped cards, compact icons, balanced nested rows, and stable search presentation.
- Legacy v1 `.3105` packages remain importable and usable.

### Fixed

- Patch Restore now restores files that existed before Apply, removes files introduced by the patch, and removes patch-created folders after they become empty.
- File navigation remains at the current folder when switching app sections and restores the correct folder independently for each Files tab.
- Empty Patch and Cleaner actions now share the same visual treatment.
- Corrected PosterBoard wallpaper activation guidance and the iOS 27 Collections prerequisite.
- Refined navigation icon rendering and nested file-row spacing.

### Compatibility

- Verified iOS 26.0–26.6.1.
- Verified iOS 27 Developer Beta 1–4, including Public Beta 1–2 mappings listed in the app.
- Added iPhone and iPad interface support; device-level features still require enterprise signing.

## [1.0 beta 3] - 2026-08-14

### Added

- Bundle-based App Data Browser with MHA-C2 container discovery.
- Native file operations: search, multi-file import, rename, delete, create file/folder, and conflict handling.
- Portable `.3105` patch projects with optional password protection and file/folder rules.
- Limited per-app cleaner for `Library/Caches` and `tmp`.
- Wallpaper Lab for validated `.tendies` packages with installation receipts and targeted reset.
- English, Vietnamese, and Simplified Chinese localization.

### Changed

- Simplified the app into a five-tab, native SwiftUI layout inspired by focused iOS container tools.
- Moved the enterprise-signing notice below device information on Home.
- Refined the orange accent, empty states, actions, and navigation presentation.

### Fixed

- Stabilized persistent search presentation in app and file browsers.
- Fixed native document selection for replacement files and `.3105` package imports.
- Resolved bundle-name mapping for enumerated app containers where metadata is available.
- Limited wallpaper reset to active content installed by 3105.
- Corrected Cleaner layout when no removable app data is found.

### Compatibility

- Verified iOS 26.0–26.6.1.
- Verified iOS 27 beta 1–4 builds listed in the app.
- Unlisted iOS 27 builds remain disabled until explicitly verified.
