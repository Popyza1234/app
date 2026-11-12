# Changelog

All notable user-facing changes are documented in this file.

## [Unreleased] - 2026-11-12

### Added

- `scripts/build-unsigned-ipa.sh`, `scripts/resign-ipa.sh`, `scripts/install-ipa.sh`, `scripts/resign-windows-zsign.ps1`, `scripts/ExportOptions-Enterprise.plist` for building, re-signing, and installing an unsigned IPA.
- `scripts/push-to-github.sh` and `.github/workflows/build-unsigned-ipa.yml` so a no-Mac workflow can produce `3105-unsigned.ipa` on a GitHub-hosted macOS runner. No certificates or tokens are stored in the repository.

### Changed

- Removed the iOS version/build whitelist. `ExploitSupportPolicy.isSupported` now returns `true` for every version and build, so all installable iOS versions (16.0+) are enabled, including iOS 27 release builds, later betas, and future majors.
- `offsets_init` no longer aborts on iOS below 17.0 or iOS 26.1+; unknown releases use the newest known offset table and log an `offsets: ... unverified` hint.
- Kernel base detection accepts iOS 27+ builds whose second-word magic differs from iOS 26 instead of scanning backwards indefinitely.
- Wallpaper Lab is available on every iOS version.
- Settings and onboarding show "All iOS versions" instead of the verified-range/beta-build list; EN/VI/ZH strings and READMEs updated.

### Compatibility

- No version or build gating. Device features are attempted on every iOS version; unverified newer releases may need updated kernel offsets, and a failed exploit attempt may restart the app.

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
