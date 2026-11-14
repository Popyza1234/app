<p align="center">
  <img src="docs/images/app-icon.png" width="132" alt="dekpop app icon">
</p>

<h1 align="center">dekpop</h1>

<p align="center">
  A Files-only native iOS app for browsing and managing app-container files.
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-4.0.1-6C4CF1?style=flat-square">
  <img alt="iOS" src="https://img.shields.io/badge/iOS-All%20versions%2016.0%2B-222222?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-F05138?style=flat-square&logo=swift&logoColor=white">
  <img alt="Edition" src="https://img.shields.io/badge/edition-Files%20only-FF4F8B?style=flat-square">
</p>

<p align="center">
  <a href="README.th.md">ภาษาไทย</a> ·
  <a href="docs/QUICKSTART.th.md">คู่มือภาษาไทย</a> ·
  <a href="#compatibility">Compatibility</a> ·
  <a href="#license">License</a>
</p>

> [!WARNING]
> dekpop is research software for personal device management. Keep a backup and use it only on devices and data you own. It can modify files inside app containers.

## What's new in 4.0.1 — a cleaner release notice

> Same release card, restyled to look official and cost nothing to display.

- **Official card.** The notice now uses a branded gradient header with the dekpop wordmark, the release version and a single close control, followed by a quiet eyebrow, the title, the body and one clear primary action.
- **Zero photo cost.** The 1 MB JPEG banner and its imageset are deleted. A photo no longer has to be decoded, so the card appears instantly even on an iPhone with little free memory.
- **Shorter motion.** Entrance and exit are 0.18 s fades with a 0.97 scale, honoring Reduce Motion; the card keeps one small shadow, no blur and no repeating animation.
- Version is now `4.0.1` (build 35).

## What's new in 4.0.0 — exploit-free, lean and smooth

> The kernel exploit is gone. No launch freeze, no watchdog hang, no reboot.

- **Exploit chain deleted.** `kexploit/`, `KernelExploit.swift`, the exploit status banner, the opt-in prompt and the launch-time run are removed. Files reaches every readable folder through the safe layers: direct read, MCM activation, traversal grant and the inode walk.
- **Hidden extras removed.** An obfuscated attribution URL, a fake `AppInfo` attestation call and a disguised window gesture are gone, together with a `fork()` override used to dodge jailbreak detection.
- **Launch stays responsive.** One serial discovery queue, 10-minute caches for bundle metadata and LaunchServices, preliminary list published before the filesystem walk, progressive updates throttled to 0.5 s.
- **UI that fits.** Icon-only Files toolbar, clamped selection/paste bars, capped tab chips, and every list kept inside the responsive inset and 760 pt clamp.
- **Smaller binary.** Patch, cleaner, wallpaper, onboarding, settings and asset-set code (about 40 files) deleted; the in-app log is capped at 800 entries.
- Version is now `4.0.0` (build 34).

## What's new in 3.0.0 — lighter, faster, smoother

> Rebuilt for older iPhones: no more frozen frames, no UI past the bezel, and no unused Asset Sets.

- **Static design layer.** The whole app paints one base fill and a few static gradients. The 30 fps `Canvas` aurora, 28 particles, animated 4× blur mesh and the third animated blurred list background are gone, along with every `repeatForever`, `plusLighter` and `.ultraThinMaterial` on a visible screen.
- **UI that fits.** The Files category picker is a custom equal-width control that cannot overflow, search is a lightweight capsule, and lists/secondary screens are clamped to 760 pt and centred with responsive insets. Nothing runs under the right bezel on an iPhone SE.
- **Calmer chrome.** Language and theme plus four folder actions collapsed into one options menu, the tabs button and one overflow menu, so the navigation bar has room for the title.
- **Faster lists.** File rows are 52 pt, app icons load through one serial utility queue, and progressive container discovery publishes at most once per 24 new apps instead of re-sorting the whole catalogue on every callback.
- **Faster launch.** The kernel exploit runs 0.8 s after the first frame at `.utility` QoS, so the app list and first paint are not blocked. The launch screen is static with one fade-in, and announcements appear once per notice instead of on every launch.
- **Asset Sets removed.** Models, service and all five screens are deleted. Saved folder shortcuts still work and are migrated automatically to the new `ShortcutStore`.
- Version is now `3.0.0` (build 30). English/Thai string tables stay at full key parity.

## What's new in 3.0.2 - the exploit result is visible

> Enabling the exploit no longer leaves a silent empty list.

- **Real failure code.** The status row shows the stage that stopped (kernel primitive, `proc_self`, offset mismatch, or a specific sandbox-escape layout) instead of a fixed `-1`.
- **Banner in Files.** A failed run shows a red banner with the detail, a retry button and one-tap **Copy diagnostics**; kernel R/W without the sandbox escape shows an orange one.
- **The list rebuilds.** A finished exploit run reloads the app list and clears the empty-folder cache, so a successful escape appears without relaunching.
- **Fragile check fixed.** The pre-escape sanity check now accepts `proc.p_pid` as well as `proc.p_name`, so a moved name field does not abort a correct offset table.
- Version is now `3.0.2` (build 32).

## What's new in 3.0.1 - iOS 27 diagnostics and panic guard

> Deep access needs a working exploit. On iOS 27 and later the app now stops before it can corrupt the kernel.

- **Exploit safety window.** `kexploit/offsets.m` is verified through iOS 26.x. Past that window the exploit no longer starts automatically; Files still tries direct reads, MCM activation, traversal grants and the inode walk.
- **Opt-in with a warning.** An orange banner in Files and a toggle in Settings let you run the unverified exploit deliberately, after a confirmation that explains the restart risk.
- **Offset sanity check.** After kernel R/W, the app reads the kernel name of its own process; if it is not `dekpop`, the sandbox escape is skipped instead of patching unrelated memory.
- **Diagnostics.** The compatibility sheet now reports the last exploit stage and a traversal-grant matrix (depth 6-12 x two container classes), so an Apple patch appears as "all variants denied".
- Version is now `3.0.1` (build 31).

## What's new in 2.1.0 — 27.0.1 compatibility & safe folders

> iOS **27.0.1** is explicitly accepted, and Files now works there even when app-container access is blocked.

- **No version gate at all.** `ExploitSupportPolicy.accepts(version:build:)` is the one acceptance gate and ignores both arguments, so `27.0.1`, beta builds and future majors are accepted exactly like `16.0`. The Files hero card shows **"iOS 27.0.1 · supported"**, and the launch screen can no longer display an "unsupported" message.
- **Why it still looked broken:** on iOS 27.0.1 the optional kernel exploit has no matching offsets, so every privileged container layer fails. That is a capability limitation, not a version restriction — but the empty-app overlay hid the one folder that always works.
- **Files that always work.** A **Choose a folder…** button opens the system document picker; the selected folder is saved as a security-scoped bookmark and browsed with the normal file browser. No exploit, no private entitlement, no kernel offsets — so file access genuinely works on 27.0.1. The dekpop Documents folder is always available too.
- **No dead end.** The empty state now offers **Open dekpop Documents**, **Choose a folder…** and **Compatibility diagnostics** directly.
- **Compatibility diagnostics** shows a per-layer report (own Documents, direct container read, MCM, traversal grant, inode walk, sandbox escape) with the exact failure detail, logs it, and can copy it for sharing.
- Version is now `2.1.0` (build 21). English/Thai: 672 keys each, perfect parity.

> Browsing *other apps' containers* still needs kernel offsets matching the running kernel; those are not available for iOS 27.0.1. The diagnostics report tells you precisely which layer fails. Safe folders and dekpop Documents work regardless.

## What's new in 2.0.0 — Universal Files access

> Major update. **Every iOS version shares one capability-based access chain** — a failing layer no longer disables the rest. Reading other apps' containers still needs a working exploit or entitlement.

- **Root cause fixed.** A hidden `majorVersion >= 26` split forced iOS 26+ through `bad_query` grants and declared the app failed whenever the optional sandbox escape did not succeed. That is why iOS 27 came up empty instead of showing the layers that still work. Older releases kept working via direct reads — hence the version-dependent behaviour.
- **One capability-based chain on every iOS version** — direct `FileManager` read → MCM activation → `bad_query` traversal grant → inode walk / raw MCM metadata plist. Layers are probed at runtime; a failing layer never disables the others. No version number is consulted anywhere in the file access path.
- **Sandbox escape is now optional.** `KernelExploit.run()` succeeds as soon as kernel R/W is established, on any release. If the escape fails, direct/MCM/grant/inode fallbacks stay active instead of marking Files as failed.
- **Folder listing has a fallback.** `listFiles(at:)` now falls back to the inode walk, so a folder that `FileManager` refuses on a newer kernel is no longer shown as empty. Grant probing is capability-based and re-tried on each reload.
- **Future-proof native layer** — kernel-base detection accepts the first validated Mach-O header on any build with a bounded scan (no infinite loop on unknown layouts); unknown CPU families on iOS 26+ use the newest known offsets rather than the iOS 17 baseline.
- The Files hero card shows a localized **Universal file access · every iOS version** line; the launch announcement is localized in English and Thai.
- Version is now `2.0.0` (build 20). IPA layout, bundle identifier and the two-language setup are unchanged.

## What's new in 1.5.0 — Apps / Shortcuts / Mods

- **Category tabs on the home screen** — a segmented picker at the top switches between **Apps**, **Shortcuts** and **Mods**, so the app opens on exactly what you need.
- **Editable folder shortcuts** — save any folder and jump straight into it. Create one from the Shortcuts tab, or from Files: long-press a folder and choose **Add shortcut**, or use **Add shortcut** in the + menu for the folder you are currently in.
- **Copy a file address** — long-press any file or folder and choose **Copy path** (or **Copy this folder's path** in the + menu). Paste that path into the shortcut editor's **Paste** button; the editor detects which app container the path belongs to and stores just the relative part.
- **Shortcut editor** — pick the target app container or the dekpop workspace, type or paste a path (absolute paths starting with `/` are accepted too), preview the exact folder that will open, and get a warning when the same folder already has a shortcut. Shortcuts can be edited, opened in a new tab, copied or deleted.
- **Mods tab with two sites** — **KenModz** ([kenmodz.com](https://kenmodz.com/)) and **Cheat iOS VIP** ([mods.cheatiosvip.net](https://mods.cheatiosvip.net/)) open in a built-in browser that keeps the dekpop theme, remembers cookies and sessions, shows a progress bar, and offers back / forward / home / reload plus *Open in Safari*.
- **Download Center removed** — the separate Downloads window is gone. Asset sets still live on the cube-box toolbar button and still use the same Apply flow, target picker and conflict policies.
- **Branded launch screen + announcements** — the app opens on a gradient splash with an animated progress bar, then the announcement card (with image support) appears on every launch.
- **New app icon** — a dark clay tile replaces the old gradient folder icon.
- Everything is stored in the dekpop document workspace (`AssetSets/`), so shortcuts survive app updates and stay reachable from the Files browser.
- Version is now `1.5.0` (build 14). IPA layout and bundle identifier are unchanged.

## What's new in 1.3.0 — English + Thai

- **Exactly two languages** — English (`en`) and Thai (`th`) only. Vietnamese and Simplified Chinese localizations were removed from the project and the built bundle; `CFBundleLocalizations` is now `(en, th)`.
- **Full Thai translation** — all 509 `Localizable.strings` keys are translated, with every `%@` / `%lld` format specifier preserved.
- **Reachable language switcher** — because the app is Files-only and `SettingsView` is no longer reachable, a globe menu was added to both the Files root toolbar and every folder view, plus a visible segmented `English / ไทย` picker at the top of the Files list. The change applies immediately.
- **Smart default** — Thai devices start in Thai; all other devices start in English. Old stored `vi` / `zh-Hans` values migrate to English automatically.
- Version is now `1.3.0` (build 9). IPA layout and bundle identifier are unchanged.

## What's new in 1.2.0 — the dekpop edition

- **Completely redesigned UI** — a violet-to-pink brand system, custom wordmark, gradient hero card with device/iOS/access status, rounded controls, and a new 1024×1024 app icon.
- **Files is the only feature** — the tab bar, dashboard, patches, cleaner, Wallpaper Lab, onboarding, attribution sheet, update prompt and patch-import URL handling are gone. The Files browser opens directly at launch.
- **Own identity** — display name, product name, executable and `.app` bundle are `dekpop`; version `1.2.0` (build 8); localizations in English / Vietnamese / Simplified Chinese updated to dekpop.
- **Unchanged core** — the app-container browser, multi-tab navigation, search, Quick Look, copy/move/rename/delete, import, ZIP create/extract and the `dekpop` workspace folder all still work.
- **CI renamed** — the artifact is now `dekpop-unsigned-ipa` containing `dekpop-unsigned.ipa` (`Payload/dekpop.app/`).

> [!IMPORTANT]
> The bundle identifier is intentionally still `com.apple.mobile.MobileHouseArrest`. `mcm_bridge.m` checks this identifier before MHA-C2 container activation; changing it breaks Files. Only the visible identity changed.

Legacy guides under `docs/PATCH_GUIDE*.md` and release notes describe features of the upstream 1.0/1.1 project; those screens are no longer reachable in dekpop.

## Themes

Six looks ship in the app — **Violet Pop**, **Midnight**, **Sunset**, **Sakura**, **Forest** and **Graphite**. Switch them from the palette button in the toolbar (Files root and every folder); the picker previews each palette and applies it instantly to accents, icons, the hero card, gradients and the launch screen. The selection is remembered and still follows light/dark mode.

## Highlights

- **App Data Browser** — resolves volatile container UUIDs to stable app bundle identifiers and exposes a native file workspace.
- **File operations** — search, preview, share, import multiple files, copy, move, paste, rename, delete, create files and folders, make ZIP archives, and safely handle name conflicts.
- **Multi-tab browsing** — independent tabs with preserved folder positions (iPad gets a tab strip).
- **dekpop workspace** — your own folder under `On My iPhone`, available from the Files browser.
- **Folder shortcuts** — save any folder and open it in one tap, with copy-path support so a file address can be pasted into the shortcut editor.
- **Mods browser** — KenModz and Cheat iOS VIP open inside dekpop with native navigation controls.
- **No jailbreak installation** — no persistent jailbreak, bootstrap, or daemon is installed; no code is injected into third-party apps.
- **Two-language interface** — English and Thai, switchable instantly from the Files toolbar or the top of the Files list.

## Compatibility

Every iOS version that can install the app is enabled — no version or build whitelist:

| Item | Status |
| --- | --- |
| Supported versions | All iOS versions 16.0 and later (release, beta, and future majors) |
| iOS 27.0.1 | Explicitly accepted — no whitelist, no maximum version |
| Build whitelist | Removed |
| Guaranteed file access | dekpop Documents + folders chosen in the Files app (works even when container access is blocked) |
| Deployment target | iOS 16.0 |
| File access engine | Universal · direct / MCM / grant / inode — identical on every iOS version |
| Version-based access split | Removed in 2.0.0 (`>= 26` branch deleted) |
| Offset fallback | iOS 26.0 baseline for unverified 26.1+ and future majors; iOS 17.0 baseline for below 17.0; unknown CPU families on iOS 26+ use the newest known generation |

> [!NOTE]
> The optional kernel exploit still needs offsets matching the running kernel. On an iOS version not covered by the offset table it may fail; it logs an `offsets: ... unverified` hint and falls back to the newest known offsets instead of aborting. **Files keeps working through the direct / MCM / grant / inode fallbacks regardless of that result** — a failed exploit no longer disables file access on iOS 27+.

## Installation notes

- Device functionality requires signing with an **enterprise certificate**.
- SideStore, AltStore, 3uTools, and LiveContainer are not supported installation paths.
- The bundle identifier is intentionally `com.apple.mobile.MobileHouseArrest`; changing it breaks the MHA-C2 app-container workflow.
- The source tree contains no certificates, provisioning profiles, signed applications, or IPA files; CI produces an **unsigned** IPA.

## Build, sign & install

`scripts/` contains the full toolchain wiring. It deliberately contains **no** certificates, profiles, passwords, or team IDs — supply your own, on your own Mac:

```bash
# 1. Build an unsigned IPA (Xcode + Command Line Tools required)
./scripts/build-unsigned-ipa.sh

# 2. Import YOUR OWN enterprise certificate, then list the identity
security import /path/to/enterprise.p12 -k ~/Library/Keychains/login.keychain-db -P 'YOUR_P12_PASSWORD' -T /usr/bin/codesign
security find-identity -v -p codesigning

# 3. Re-sign with an enterprise profile covering com.apple.mobile.MobileHouseArrest
./scripts/resign-ipa.sh dekpop-unsigned.ipa "iPhone Distribution: Your Enterprise" /path/to/profile.mobileprovision dekpop-signed.ipa

# 4. Install onto a USB-connected device (Apple Configurator or libimobiledevice)
./scripts/install-ipa.sh dekpop-signed.ipa
```

The Xcode target is still named `3105` (`xcodebuild -target 3105`), but `PRODUCT_NAME` is `dekpop`, so the built bundle is `dekpop.app`. For `Product > Archive > Distribute App (Enterprise)`, copy `scripts/ExportOptions-Enterprise.plist` and replace `YOUR_TEAM_ID` / `YOUR_ENTERPRISE_PROFILE_NAME`. For enterprise OTA or MDM delivery, host the **signed** IPA plus an `itms-services` manifest over HTTPS (or push it through your MDM); an unsigned IPA cannot be installed.

> [!CAUTION]
> Use only an enterprise certificate you are authorized to use. Never commit `.p12`, passwords, or `.mobileprovision` files, and never paste private keys into chats or issue trackers. `.gitignore` already excludes signing material and build artifacts. `com.apple.mobile.MobileHouseArrest` is an Apple-reserved identifier, so a standard developer account usually cannot create a matching App ID — that is why the project distributes an unsigned IPA for re-signing.

## Without a Mac

> ภาษาไทย: [docs/QUICKSTART.th.md](docs/QUICKSTART.th.md) — คู่มือแบบคลิกทีละขั้นตอน (สร้าง repo → push → โหลด IPA → เซ็น → ติดตั้ง)

An enterprise certificate and a provisioning profile covering `com.apple.mobile.MobileHouseArrest` are still required — no workaround removes that. The Mac itself is optional:

1. **Build in CI** — `.github/workflows/build-unsigned-ipa.yml` runs on a GitHub-hosted `macos-latest` runner (free for public repos; private repos use your plan's minutes). Push the repo, open **Actions > Build unsigned IPA > Run workflow**, then download the `dekpop-unsigned-ipa` artifact. No certificate is needed for this step (`CODE_SIGNING_ALLOWED=NO`).
2. **Sign on the iPhone with ESign** — copy the unsigned IPA to the device (Files / AirDrop), import your `.p12` + `.mobileprovision` into ESign, then sign and install.
3. **Sign on Windows/Linux with zsign** — `zhlynn/zsign` re-signs an IPA without Xcode:

   ```powershell
   .\scripts\resign-windows-zsign.ps1 -Ipa .\dekpop-unsigned.ipa `
     -P12 .\enterprise.p12 -P12Password 'YOUR_PASSWORD' `
     -MobileProvision .\profile.mobileprovision
   ```

   Copy `dekpop-signed.ipa` to the device and install it with ESign, or serve it over HTTPS with an `itms-services` manifest / push it through MDM.

### Push to GitHub from Windows (no Mac)

The project is already initialized as a Git repository with a local commit. You only supply the URL of **your own** repository — the script never handles or prints a token.

1. Create a **new empty repository** on GitHub. Do **not** tick "Add a README", a license, or a `.gitignore`, and leave the default branch as `main`.
2. From the project root, in **Git Bash** (or WSL / macOS Terminal), run:

   ```bash
   ./scripts/push-to-github.sh https://github.com/<user>/<repo>.git
   ```

   Authentication happens in Git Credential Manager / your normal `git` credential prompt. If you use a Personal Access Token, paste it **only** into that prompt — never into a chat, issue, or file. The script stages and commits any remaining changes, verifies that no `.p12`, `.mobileprovision`, `.env`, or similar secret is tracked, checks that the CI workflow is included, forces the `main` branch, sets `origin`, and pushes.

   If a non-interactive shell reports `could not read Username` / `Authentication failed`, run `scripts\push-now.cmd` from Windows Explorer or `cmd` so Git Credential Manager can open its sign-in window. The launcher is self-contained: it has a default remote (overridable with the first argument), finds the project folder even when the `.cmd` was opened from a copied/downloaded location, initializes Git and commits if needed, sets `origin`, pushes `main`, and prints the Actions/artifact steps. No token is stored by the script.
3. Pushing to `main` triggers **Build unsigned IPA** automatically; you can also start it manually under **Actions > Build unsigned IPA > Run workflow**. A GitHub-hosted `macos-latest` runner builds `dekpop-unsigned.ipa` and uploads it as the `dekpop-unsigned-ipa` artifact (retained 14 days).
4. Download and unzip the artifact. It contains `dekpop-unsigned.ipa`, which is **unsigned** — sign it with your own authorized enterprise certificate and matching provisioning profile (ESign on-device, or `scripts/resign-windows-zsign.ps1`) before installing via ESign, enterprise OTA / MDM, or Apple Configurator.

   To fetch it from the command line, double-click `scripts\download-unsigned-ipa.cmd` or run `python scripts/download-unsigned-ipa.py`. It finds the latest successful run, uses the GitHub credential already cached by Git Credential Manager (never printed or stored), saves `dekpop-unsigned.ipa` to the project root, and verifies `Info.plist`. Artifacts expire after 14 days — re-run the workflow if the artifact has expired.

If the first push is rejected because the remote already has commits, run `git pull --rebase origin main && git push -u origin main`, or recreate the repository empty.

To have CI produce a *signed* IPA, add a step after the build that decodes secrets (`P12_BASE64`, `P12_PASSWORD`, `MOBILEPROVISION_BASE64`) into `RUNNER_TEMP`, imports the certificate into a temporary keychain, and calls `scripts/resign-ipa.sh`. Only do this with a certificate your team owns and is licensed to distribute; never commit signing material, and remember fork pull requests receive no secrets.

Rented cloud Macs (MacInCloud, MacStadium, AWS EC2 Mac) are a last resort if you need the full Xcode GUI; this project does not require it.

## Project layout

```text
dekpop/
├── ThreeOneOSFive/          # SwiftUI app, helpers, native bridges, localizations
│   ├── App.swift            # @main DekpopApp + AppState (kernel access bootstrap)
│   ├── ContentView.swift    # Files-only root view
│   ├── views/               # AppDataBrowserView, FileBrowserView, ModBrowserView, ShortcutsView, DesignSystem
│   ├── en.lproj/            # English strings
│   ├── th.lproj/            # Thai strings
│   └── Assets.xcassets/     # dekpop app icon
├── ThreeOneOSFive.xcodeproj # Xcode project (target name 3105, PRODUCT_NAME dekpop)
├── scripts/                 # unsigned IPA build, re-sign, install, GitHub push, artifact download, icon generator
├── .github/workflows/       # macOS-runner CI build for an unsigned IPA
└── docs/                    # Thai quick-start, legacy guides, artwork
```

`scripts/generate-app-icon.py` regenerates the icon (`python -m pip install Pillow` first).

> Non-Files view/helper sources remain in the Xcode target so the project keeps compiling unchanged, but nothing in the app navigates to them. Files-coupled helpers with "Patch" in their names (`PatchWorkspaceService`, `PatchDraftCoordinator`, `PatchPathValidator`, …) are still required by the file browser.

## Security and responsible use

Do not publish logs, app containers, cookies, or account databases containing personal data. Report security-sensitive issues privately to the maintainer.

## Credits

dekpop is a Files-only custom edition of the 3105 project by [YangJiii](https://x.com/duongduong0908).

Special thanks to [0xjohnny](https://x.com/0xjohnny) for [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop) and related research:

- [MobileHouseArrest-PoC](https://github.com/0xjohnnydev/MobileHouseArrest-PoC) — ContainerManager identity-trust bug
- [Geod-MCM-PoC](https://github.com/0xjohnnydev/Geod-MCM-PoC) — `geod` MobileContainerManager `partDomain` traversal
- [InstallCoordination-PoC](https://github.com/0xjohnnydev/InstallCoordination-PoC) — persisted-state and final-symlink chain
- [CFPrefsZeroFile-PoC](https://github.com/0xjohnnydev/CFPrefsZeroFile-PoC) — `cfprefsd` zero-file creation

The project also builds on work from Pocket Poster/Nugget, CrazyMind90, forcequitOS, Dopamine, and their contributors. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for full attribution and upstream links.

## License

Original portions of the upstream 3105 project are distributed under the [GNU General Public License v3.0](LICENSE). Third-party components remain subject to their respective upstream copyright and license terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The dekpop branding and new UI assets follow the same license terms.
