# Changelog

All notable user-facing changes are documented in this file.

## [2.1.0] - 2026-11-13 — 27.0.1 compatibility, safe folders and diagnostics

### What was reported

After 2.0.0, iOS **27.0.1** still appeared "unsupported" / Files still showed an
empty list. No whitelist or version comparison remained in the code, so this was
**not** a version check: on that kernel the optional exploit and every privileged
container layer are unavailable, and the empty-app overlay hid the only folder
that always works (the app's own Documents).

### Added

- **Explicit universal acceptance** — `ExploitSupportPolicy.accepts(version:build:)`
  is now the single acceptance gate and ignores both parameters. `27.0.1`,
  four-component beta strings and future majors are accepted exactly like `16.0`.
  `AppState.detectSupport()` logs the accepted version on every launch.
- The **"iOS <version> · supported"** badge is now shown on the Files hero card,
  and `launch.status_unsupported` can no longer be displayed — the launch screen
  has no unsupported branch at all.
- **Safe folders (guaranteed file access on any iOS version)** — a **Choose a
  folder…** button opens the system document picker (`UTType.folder`). The chosen
  folder is stored as a security-scoped bookmark (`SafeFolderBookmarks`) and opens
  in the normal `FileBrowserView`. This needs no exploit, no private entitlement
  and no kernel offsets, so Files genuinely works on 27.0.1.
- A **Files that always work** section on the Files root, and the same actions
  (**Open dekpop Documents**, **Choose a folder…**, **Compatibility diagnostics**)
  directly in the empty state, so a failed container scan never leaves a dead end.
- **Compatibility diagnostics** (`CompatibilitySelfTest` + `CompatibilityReportView`)
  — probes own Documents, direct container read, MCM activation, traversal grant,
  inode enumeration and sandbox escape, shows OK/unavailable per layer with the
  exact error detail/handle, writes each result to the in-app log, and can copy the whole
  report for sharing.
- English and Thai string tables: 672 keys each, perfect parity, no format-specifier
  mismatches.

### Changed

- Version is now `2.1.0` (build 21). IPA layout, bundle identifier and the
  two-language setup are unchanged.

> Note: browsing *other apps' containers* still requires kernel offsets that
> match the running kernel. Apple has not published those for iOS 27.0.1, so that
> specific capability may still be unavailable; the diagnostics report shows
> exactly which layer fails. Safe folders and dekpop Documents work regardless.

## [2.0.0] - 2026-11-13 — Universal Files access (major update)

### Fixed — iOS 27+ could not access files

The version whitelist had already been removed, but a second, hidden split remained:
`majorVersion >= 26` forced all file enumeration through `bad_query` traversal grants, and
`KernelExploit.run()` treated a failed sandbox escape as a fatal error on iOS 26+. On iOS 27
the sandbox escape / kernel offsets do not match yet, so the exploit was marked failed, grants
returned `-1`, the metadata scan was skipped, and every LaunchServices candidate was dropped —
Files showed nothing. Older iOS versions kept working because they took the direct-read path.

### Changed

- **One access chain for every iOS version.** `ContainerAccessPolicy` is now capability-based,
  not version-based: direct `FileManager` read → MCM activation → `bad_query` traversal grant →
  `bad_query_list` inode walk / raw MCM metadata plist. No layer is skipped because of a version
  number, and a failing layer falls through to the next one.
- `KernelExploit.run()` returns success as soon as kernel R/W is established on **any** iOS
  version. Sandbox escape is now an optional enhancement; `proc_self()` returning 0 is no longer
  fatal. `requiresSandboxEscape` and `shouldUseBadQuery` were removed.
- `AppState` no longer downgrades a successful access state when the optional escape disappears,
  so iOS 27+ is not stuck re-running the exploit. The hero card and launch screen show "ready"
  based on support + exploit running, not on exploit success.
- `ContainerStore.launchServicesStoreIdentifiers()` attempts a direct read even when a grant
  fails (previously `continue`d and lost all candidates on iOS 26+).
- `ContainerStore.resolveAppContainerPathByMetadataScan()` always runs (previously skipped on
  iOS 26+ without full sandbox access).
- `ContainerStore.enumerateDirectoriesWithTraversalGrant()` tries direct read → grant → inode
  walk on every version; `listFiles(at:)` gained the inode fallback so folders are not empty
  when `FileManager` refuses them.
- `ContainerAccessPolicy.shouldRequestGrant` is now capability-based instead of version-based;
  grant probing is rate-limited (3 consecutive failures) and reset on each reload and after a
  successful kernel exploit, so a late-appearing capability is picked up. Nested folders inherit
  the root grant and additionally get the direct-read / inode fallback in `listFiles`.
- **Native layer is future-version safe.** `kexploit_opa334.m` no longer branches on the iOS
  version to validate the kernel Mach-O header: the first validated header is accepted on any
  build and the backwards walk is bounded (32 MB), so an unknown kernel layout cannot hang.
  `offsets.m` treats an unknown CPU family on iOS 26+ as the newest known generation instead
  of silently using the iOS 17 baseline offsets, and logs unverified future releases.
- The Files hero card now shows a localized **"Universal file access · every iOS version"** line; the (currently unreachable) `SettingsView` also displays the engine label `Universal · direct / MCM / grant / inode`.
- The launch announcement is now localized through `announcement.200_title` / `_body` keys
  instead of hard-coded Thai text.
- English and Thai string tables: 648 keys each, perfect parity, no duplicates.
- Version is now `2.0.0` (build 20). IPA layout and bundle identifier are unchanged.

## [Unreleased] - 2026-11-13 — themes, look & feel

### Added

- **Six themes** (`DekpopPaletteID`, `DekpopPalette`, `ThemeManager`) — Violet Pop, Midnight, Sunset, Sakura, Forest and Graphite. Each palette drives the accent, secondary accent, gradient, icons and launch screen, and still follows light/dark mode. The choice is saved in `UserDefaults` (`dekpop.theme`) and restored on the next launch.
- **Theme picker** (`DekpopThemePicker`) — a sheet with a live preview card per palette, palette swatches, a checkmark on the active theme, selection haptics and a Done button. Reachable from the `paintpalette` toolbar button on the Files root and inside every folder.
- **Animated background** (`DekpopAnimatedBackground`) — soft palette-coloured light drifts slowly behind the Files list (disabled automatically with Reduce Motion).
- `DekpopPressStyle` springy press feedback and `DekpopHaptics` helpers.

### Changed

- `AppTheme` colours and gradients are now theme-aware computed values instead of fixed constants, so every existing call site follows the selected palette without changes.
- The hero card gained drifting highlights, a moving sheen and a gradient border; the launch screen decorations now float.
- The Files root list uses a transparent scroll background so the animated palette backdrop shows behind the cards.
- The announcement card is now shown on **every** app launch instead of once per announcement id. Dismissing it only closes the card for the current session, so the newest notice (`AnnouncementStore.current`) always appears after the launch screen.
- Localization keys `theme.*` added in English and Thai (636 → 645 keys each).

## [1.5.0] - 2026-11-13 — Apps / Shortcuts / Mods

### Added

- **Home category tabs** — a segmented picker above the list (Apps / Shortcuts / Mods) replaces the old Quick Access row. Search is scoped to the selected tab and hidden on Mods.
- **Branded launch screen** (`LaunchView.swift`) — a full-screen gradient splash with an animated logo, shimmer progress bar and live container-access status, shown briefly once per launch.
- **Announcements** (`Announcements.swift`, `AnnouncementView.swift`) — a one-shot notice card appears after the launch screen; it supports a title, body, a bundled image and an optional link, and is remembered per announcement id so new notices resurface.
- **New app icon** — the dark clay "p" tile replaces the gradient folder icon (`AppIcon-1024.png`).
- **Editable folder shortcuts** (`ShortcutsView.swift`) — the Shortcuts tab lists saved folders with name, relative path, search, swipe-delete and a context menu (open in new tab, edit, copy path, delete). `ShortcutEditorView` picks a target app container or the dekpop workspace, accepts a relative or absolute path, previews the resolved folder, warns about duplicates, and can infer the target container from a pasted absolute path.
- **Add shortcut from Files** — long-press any folder and choose **Add shortcut**, or use **Add shortcut** in the + menu for the current folder. Duplicate shortcuts are rejected with a notice.
- **Copy path** — long-press any file or folder and choose **Copy path**, or **Copy this folder's path** in the + menu. The copied address can be pasted straight into the shortcut editor.
- **Cheat iOS VIP** — [mods.cheatiosvip.net](https://mods.cheatiosvip.net/) joins KenModz in the Mods tab. `ModBrowserView.swift` was generalized to a `ModSite` list; both sites share the same in-app browser (theme, cookies, progress bar, back / forward / home / reload, Open in Safari, error retry).
- Localization keys for `home.*`, `shortcuts.*`, `mods.*` and the new browser path actions in both English and Thai (631 keys each, format specifiers matched).

### Removed

- **Download Center** (`DownloadsView.swift`) and the per-set saved destination fields (`AssetSet.destination`, `AssetSet.lastAppliedAt`, `AssetSetDestination`). Asset sets keep their Apply flow and target picker.
- The old `KenModzView` / `kenmodz.*` keys and the `downloads.*` keys.

### Changed

- `DownloadShortcut` is now `FolderShortcut`, with `relativePath` and `resolvedPath(path:containerPath:)` helpers. Stored shortcuts remain in `AssetSets/download-shortcuts.json`, so existing shortcuts survive the upgrade.
- Version is now `1.5.0` (build 14). IPA layout and bundle identifier are unchanged.

## [1.4.0] - 2026-11-13 — Asset Sets (creator toolkit)

### Added

- **Asset Set Manager** — a new in-app toolkit for organizing your own files into named, reusable sets (character / outfit / weapon / bundle categories). Reachable from the cube-box toolbar button on the Files root.
- `AssetSetModels.swift` / `AssetSetService.swift` — generic data model and JSON persistence inside the dekpop document workspace (`AssetSets/` folder).
- `AssetSetsView` — grid of sets with category filter chips and search.
- `AssetSetDetailView` — preview, item list, rename/edit/delete, and **Apply** to copy the set's files into a target you choose.
- `AssetSetEditorView` — create/edit a set, import your own files via the system file picker (including while creating a brand-new set), assign each file to a slot (head/face/body/pants/shoes/accessory/weapon/other), and change slots later.
- `AssetSetApplyView` — choose an app container discovered by dekpop, the dekpop workspace folder, a folder from the Files app, or a custom path; optionally copy into a subfolder. Conflict policy: replace / keep both / skip. Results report copied, skipped and failed counts.
- **Download Center** (`DownloadsView`) — a dedicated window reachable from the Quick Access row on the Files root. Saved sets appear as one-tap downloads with their remembered destination, per-set copied/skipped/failed results, last-download time, and a **Download all** action.
- **Saved destinations** — each asset set can remember an app container, workspace or custom folder plus an optional subfolder, so installing a mod no longer requires picking a target every time.
- **Folder shortcuts** — save locations (app container, workspace or custom folder + subfolder) that open directly in the Files browser on tap, either in the current tab or a new tab. Shortcuts support add, edit, swipe-delete and search.
- **KenModz** (`KenModzView`) — an in-app browser for [kenmodz.com](https://kenmodz.com/) that keeps the dekpop theme and English/Thai controls. Opens from Quick Access, persists cookies/sessions through the default `WKWebsiteDataStore`, shows a reading-progress bar, and provides back / forward / home / reload plus **Open in Safari**. External schemes open in the system browser, and error states offer retry.
- New localization keys (`asset.*`, `downloads.*`, `kenmodz.*`, `common.save`) added to both English and Thai (now 633 keys each).

### Fixed

- Importing files while creating a new set now works; previously the import silently did nothing. Cancelling an edit discards only the files staged during that session.
- Deleting a set or an individual item now removes its files from disk instead of leaving them orphaned in `AssetSets/`.

### Changed

- Version is now `1.4.0` (build 12). IPA layout and bundle identifier are unchanged.

## [1.3.0] - 2026-11-12 — English + Thai

### Added

- Thai (`th.lproj/Localizable.strings`) with all 509 keys translated; every `%@` / `%lld` format specifier matches the English source.
- `dekpop.language` and `dekpop.language_hint` keys for the new switcher.
- `DekpopLanguageMenu` (globe icon) in the Files root toolbar **and** every folder view's toolbar, plus a visible segmented `DekpopLanguagePicker` at the top of the Files root list. These are reachable because `SettingsView` is no longer part of the Files-only app.
- `AppLanguage.preferredDefault`: Thai devices start in Thai, everything else starts in English. Stored `vi` / `zh-Hans` values from older builds migrate to English on launch.
- `README.th.md` as the Thai README; `CFBundleLocalizations = (en, th)`.

### Changed

- `AppLanguage` now has exactly two cases: `.english` and `.thai`; added `resolving(_:)` for safe migration and `nativeHint` for onboarding labels.
- `Info.plist`, `project.pbxproj` and `DekpopBrand` bumped to `1.3.0` (build 9).
- `knownRegions`, the `PBXVariantGroup` and the file references now contain `en` + `th` only.

### Removed

- `vi.lproj/Localizable.strings`, `zh-Hans.lproj/Localizable.strings` and `README.vi.md`. No Vietnamese or Simplified Chinese resources ship in the app bundle.

## [1.2.0] - 2026-11-12 — dekpop (Files-only edition)

### Changed

- Rebranded the app to **dekpop**: new display name, `PRODUCT_NAME`, executable name, `.app` bundle, version `1.2.0` (build 8), and a new 1024×1024 opaque app icon generated by `scripts/generate-app-icon.py`.
- Completely redesigned the UI around a violet → pink brand system: `DekpopWordmark`, gradient hero card with device / iOS / access status, rounded search field, gradient row icons, branded empty state and footer.
- **Files is now the only feature.** `ContentView` hosts `AppDataBrowserView` directly; the tab bar, dashboard, patches, cleaner, Wallpaper Lab, onboarding, attribution sheet, update prompt and `.onOpenURL` patch import were removed from `App.swift`.
- Removed `AppSection`, `FeatureVisibility`, `WallpaperFeatureSupportPolicy` and `AppTabNavigationState`; only file-browser destinations and `FilesTabSession` remain in `AppTabNavigationState.swift`.
- `Info.plist`: dropped patch document/URL/exported types, updated usage descriptions, removed the old `3105` metadata. The reserved bundle identifier `com.apple.mobile.MobileHouseArrest` is unchanged because MHA-C2 container activation requires it.
- EN / VI / ZH-Hans localizations: all user-facing `3105` text changed to `dekpop`, plus four new `dekpop.*` keys for the hero card and workspace subtitle (503 → 507 keys per language).
- Non-Files views/helpers remain in the Xcode target so the project compiles unchanged, but are unreachable. Files-coupled helpers with "Patch" in the name are still required by the file browser.
- Removed the last non-Files **Create Patch** context-menu action from `FileBrowserView`, including its draft/error helpers and `PatchDraftCoordinator` environment object.
- The Files home now resolves the app's own Documents folder directly instead of calling `PatchWorkspaceService`, so the patch-era `Patches` directory is no longer created on launch.
- Rebranded remaining internal identifiers from `3105` to `dekpop`: in-app and native log prefixes, Quick Look preview folder, staging/temp file names, sandbox probe name, log/attribution views, update URLs, User-Agent, and the legacy patch/wallpaper identifiers in unreachable code. Only the Xcode target/project folder names (`3105`, `ThreeOneOSFive`) and historical release notes still contain the old name.

### Tooling

- `scripts/build-unsigned-ipa.sh` now expects `Payload/dekpop.app` and writes `dekpop-unsigned.ipa`.
- `.github/workflows/build-unsigned-ipa.yml` verifies `Payload/dekpop.app/Info.plist` and uploads the `dekpop-unsigned-ipa` artifact.
- `scripts/download-unsigned-ipa.py` / `.cmd` download and verify the dekpop IPA, and the Windows signing scripts default to `dekpop-signed.ipa`.
- `scripts/generate-app-icon.py` regenerates the app icon (requires Pillow).
- README, Vietnamese README, Thai quick-start and project layout updated for dekpop.

## [Unreleased] - 2026-11-12

### Added

- `scripts/build-unsigned-ipa.sh`, `scripts/resign-ipa.sh`, `scripts/install-ipa.sh`, `scripts/resign-windows-zsign.ps1`, `scripts/ExportOptions-Enterprise.plist` for building, re-signing, and installing an unsigned IPA.
- `scripts/push-to-github.sh` and `.github/workflows/build-unsigned-ipa.yml` so a no-Mac workflow can produce `3105-unsigned.ipa` on a GitHub-hosted macOS runner. No certificates or tokens are stored in the repository.
- `docs/QUICKSTART.th.md`: Thai step-by-step guide for creating an empty GitHub repo, pushing, downloading the CI artifact, and signing/installing the IPA.
- `scripts/push-now.cmd`: double-clickable Windows launcher for an interactive GitHub sign-in + `git push -u origin main`, for shells where a non-interactive push cannot prompt for credentials. Self-contained: default remote (overridable via first argument), project-folder detection with a Desktop fallback, and full `git init` / stage / secret check / commit / `chmod +x` / `origin` setup without requiring Git Bash.
- `scripts/download-unsigned-ipa.py` and `scripts/download-unsigned-ipa.cmd`: fetch the `3105-unsigned-ipa` artifact into the project root using the GitHub credential already cached by Git Credential Manager (never printed or stored), then verify the IPA layout and `Info.plist`.

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
