<p align="center">
  <img src="docs/images/app-icon.png" width="132" alt="dekpop app icon">
</p>

<h1 align="center">dekpop</h1>

<p align="center">
  A Files-only native iOS app for browsing and managing app-container files.
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-1.4.0-6C4CF1?style=flat-square">
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

## What's new in 1.4.0 — Asset Sets (creator toolkit)

- **Asset Set Manager** — organize your own files into named, reusable sets directly inside dekpop. Open it from the cube-box toolbar button on the Files root.
- Create a set, choose a category (character / outfit / weapon / bundle), import your own files, assign each to a slot, then **Apply** to copy the whole set into an app container, the dekpop folder, a folder from the Files app, or a custom path (with an optional subfolder).
- Apply reports copied, skipped and failed counts, and supports replace / keep both / skip conflict policies.
- **Download Center** — open it from the Quick Access row on the Files root to reinstall any saved set in one tap into its remembered destination, see copied/skipped/failed results, or download every configured set at once.
- **Folder shortcuts** — save app containers, the dekpop workspace or custom folders (plus a subfolder) and open them instantly from the same window, in the current tab or a new one.
- Everything is stored in the dekpop document workspace (`AssetSets/`), so it is reachable from the Files browser and survives app updates.
- Works with files you own or have the right to use — no game-specific bundles, paths, or assets are baked in.

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

## Highlights

- **App Data Browser** — resolves volatile container UUIDs to stable app bundle identifiers and exposes a native file workspace.
- **File operations** — search, preview, share, import multiple files, copy, move, paste, rename, delete, create files and folders, make ZIP archives, and safely handle name conflicts.
- **Multi-tab browsing** — independent tabs with preserved folder positions (iPad gets a tab strip).
- **dekpop workspace** — your own folder under `On My iPhone`, available from the Files browser.
- **No jailbreak installation** — no persistent jailbreak, bootstrap, or daemon is installed; no code is injected into third-party apps.
- **Two-language interface** — English and Thai, switchable instantly from the Files toolbar or the top of the Files list.

## Compatibility

Every iOS version that can install the app is enabled — no version or build whitelist:

| Item | Status |
| --- | --- |
| Supported versions | All iOS versions 16.0 and later (release, beta, and future majors) |
| Build whitelist | Removed |
| Deployment target | iOS 16.0 |
| Offset fallback | iOS 26.0 baseline for unverified 26.1+; iOS 17.0 baseline for below 17.0 |

> [!NOTE]
> The kernel exploit still needs offsets matching the running kernel. On an iOS version not covered by the offset table the exploit may fail; it logs an `offsets: ... unverified` hint and falls back to the newest known offsets instead of aborting. A failed attempt may restart the app.

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
│   ├── views/               # AppDataBrowserView, FileBrowserView, DesignSystem, tab controls
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
