import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AppDataBrowserView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var apps: [InstalledApp] = []
    @State private var shortcuts: [FolderShortcut] = []
    @State private var isLoading = false
    @State private var isResolving = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    @State private var workspaceURL: URL?
    @State private var selectedCategory: HomeCategory = .apps
    @State private var activeSheet: FilesRootSheet?
    @State private var copiedPath: String?
    @State private var safeFolders: [SafeFolder] = []
    @State private var showingFolderPicker = false
    @State private var safeFolderNotice: String?
    @Binding private var tabSession: FilesTabSession

    init(tabSession: Binding<FilesTabSession>) {
        _tabSession = tabSession
    }

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        let q = searchText.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
        }
    }

    private var filteredShortcuts: [FolderShortcut] {
        guard !searchText.isEmpty else { return shortcuts }
        let q = searchText.lowercased()
        return shortcuts.filter {
            $0.name.lowercased().contains(q) || $0.relativePath.lowercased().contains(q)
        }
    }

    private var overlayState: AppBrowserOverlayState {
        if (isLoading || isResolving) && apps.isEmpty { return .loading }
        if apps.isEmpty { return .empty }
        if filteredApps.isEmpty { return .noResults }
        return .none
    }

    private var interfaceAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.20)
    }

    var body: some View {
        NavigationStack(path: activeNavigationPath) {
            appList
            .navigationTitle(DekpopBrand.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    DekpopLanguageMenu()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    DekpopThemeToolbarButton()
                }
                ToolbarItem(placement: .principal) {
                    DekpopWordmark(compact: true)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { activeSheet = .assetSets } label: {
                        Image(systemName: "cube.box")
                    }
                    .accessibilityLabel(language.text("asset.sets_title"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    FilesTabToolbarButton(session: $tabSession)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { reload() } label: {
                        if isResolving {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isResolving)
                    .accessibilityLabel(language.text("browser.retry"))
                }
            }
            .onAppear {
                if workspaceURL == nil {
                    workspaceURL = try? FileManager.default.url(
                        for: .documentDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    )
                }
                loadShortcuts()
                safeFolders = SafeFolderBookmarks.load()
                if !hasLoaded {
                    hasLoaded = true
                    reload()
                }
            }
            .onChange(of: tabSession.activeTab?.navigationPath.count ?? 0) { count in
                if count == 0 {
                    loadShortcuts()
                }
            }
            .navigationDestination(for: FileBrowserDestination.self) { destination in
                if destination.startPath == destination.containerPath {
                    FileBrowserView(
                        containerPath: destination.containerPath,
                        title: destination.title,
                        bundleID: destination.bundleID,
                        filesTabSession: $tabSession
                    )
                } else {
                    FileBrowserView(
                        containerPath: destination.containerPath,
                        startPath: destination.startPath,
                        title: destination.title,
                        bundleID: destination.bundleID,
                        filesTabSession: $tabSession
                    )
                }
            }
        }
        .sheet(item: $activeSheet, onDismiss: loadShortcuts) { sheet in
            switch sheet {
            case .assetSets:
                AssetSetsView(apps: apps)
            case .newShortcut:
                ShortcutEditorView(
                    apps: apps,
                    shortcut: nil,
                    existingShortcuts: shortcuts
                ) { shortcut in
                    addShortcut(shortcut)
                }
            case .editShortcut(let shortcut):
                ShortcutEditorView(
                    apps: apps,
                    shortcut: shortcut,
                    existingShortcuts: shortcuts
                ) { updated in
                    updateShortcut(updated)
                }
            case .site(let site):
                ModBrowserView(site: site)
            case .diagnostics(let report):
                CompatibilityReportView(report: report)
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderPicker(result)
        }
        .onChange(of: activeSheet?.id) { _ in
            safeFolders = SafeFolderBookmarks.load()
        }
        .alert(
            language.text("browser.copy_path_done"),
            isPresented: Binding(
                get: { copiedPath != nil },
                set: { isPresented in
                    if !isPresented { copiedPath = nil }
                }
            )
        ) {
            Button(language.text("common.done"), role: .cancel) {
                copiedPath = nil
            }
        } message: {
            Text(copiedPath ?? "")
        }
    }

    private var activeNavigationPath: Binding<[FileBrowserDestination]> {
        Binding(
            get: { tabSession.activeTab?.navigationPath ?? [] },
            set: { tabSession.setActiveNavigationPath($0) }
        )
    }

    private var appList: some View {
        VStack(spacing: 0) {
            if horizontalSizeClass == .regular {
                FilesTabStrip(session: $tabSession)
            }
            categoryPicker
            if selectedCategory != .mods {
                AppSearchField(
                    text: $searchText,
                    prompt: language.text(selectedCategory == .apps ? "browser.search" : "shortcuts.search"),
                    clearLabel: language.text("common.clear")
                )
            }
            Divider()
            homeRows
        }
        .background(DekpopAnimatedBackground().ignoresSafeArea())
    }

    private var categoryPicker: some View {
        Picker(language.text("home.category"), selection: $selectedCategory) {
            ForEach(HomeCategory.allCases) { category in
                Text(language.text(category.titleKey)).tag(category)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.clear)
        .onChange(of: selectedCategory) { _ in
            searchText = ""
        }
    }

    @ViewBuilder
    private var homeRows: some View {
        List {
            switch selectedCategory {
            case .apps:
                appsContent
            case .shortcuts:
                shortcutsContent
            case .mods:
                modsContent
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 48)
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if selectedCategory == .apps {
                Group {
                    switch overlayState {
                    case .loading:
                        ProgressView(language.text("browser.loading"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .empty:
                        emptyView
                    case .noResults:
                        searchEmptyView
                    case .none:
                        EmptyView()
                    }
                }
                .transition(.opacity)
                .animation(interfaceAnimation, value: overlayState)
            }
        }
    }

    @ViewBuilder
    private var appsContent: some View {
        Section {
            DekpopHeroCard()
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }

        Section {
            DekpopLanguagePicker()
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
        } header: {
            Text(language.text("dekpop.language"))
        } footer: {
            Text(language.text("dekpop.language_hint"))
        }

        if let workspaceURL {
            Section(language.text("browser.workspace")) {
                let workspaceDestination = FileBrowserDestination(
                    containerPath: workspaceURL.path,
                    startPath: workspaceURL.path,
                    title: DekpopBrand.displayName,
                    bundleID: nil
                )
                NavigationLink(value: workspaceDestination) {
                    HStack(spacing: 10) {
                        AppRowIcon(
                            systemName: "folder.fill",
                            tint: AppTheme.accentSecondary,
                            frameSize: 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DekpopBrand.displayName)
                                .font(.subheadline.weight(.bold))
                            Text(language.text("dekpop.workspace_subtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    openInNewTabButton(workspaceDestination)
                }
            }
        }
        safeAccessSection
        Section {
            ForEach(filteredApps) { app in
                if app.containerPath.isEmpty {
                    appRow(app)
                } else {
                    let appDestination = FileBrowserDestination(
                        containerPath: app.containerPath,
                        startPath: app.containerPath,
                        title: app.displayName,
                        bundleID: app.bundleID
                    )
                    NavigationLink(value: appDestination) {
                        appRow(app)
                    }
                    .contextMenu {
                        openInNewTabButton(appDestination)
                    }
                }
            }
        } header: {
            HStack(spacing: 8) {
                Text(language.text("browser.apps_count", Int64(filteredApps.count)))
                Spacer()
                if isResolving {
                    ProgressView()
                        .controlSize(.mini)
                    Text(language.text("browser.mha_scanning"))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(nil)
        }
        Section {
            DekpopFooterView()
        }
    }

    @ViewBuilder
    private var shortcutsContent: some View {
        Section {
            Button {
                activeSheet = .newShortcut
            } label: {
                HStack(spacing: 10) {
                    AppRowIcon(
                        systemName: "plus",
                        tint: AppTheme.accent,
                        frameSize: 34
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.text("shortcuts.add"))
                            .font(.subheadline.weight(.bold))
                        Text(language.text("shortcuts.add_subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } header: {
            Text(language.text("shortcuts.title"))
        } footer: {
            Text(language.text("shortcuts.footer"))
        }

        if filteredShortcuts.isEmpty {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "bookmark" : "magnifyingglass")
                        .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(language.text(searchText.isEmpty
                        ? "shortcuts.empty_title"
                        : "shortcuts.search_empty"))
                        .font(.subheadline.weight(.medium))
                    if searchText.isEmpty {
                        Text(language.text("shortcuts.empty_message"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        } else {
            Section {
                ForEach(filteredShortcuts) { shortcut in
                    NavigationLink(value: shortcut.fileBrowserDestination) {
                        shortcutRow(shortcut)
                    }
                    .contextMenu {
                        Button {
                            openShortcut(shortcut, inNewTab: true)
                        } label: {
                            Label(language.text("browser.open_new_tab"), systemImage: "square.on.square")
                        }
                        Button {
                            activeSheet = .editShortcut(shortcut)
                        } label: {
                            Label(language.text("shortcuts.edit"), systemImage: "pencil")
                        }
                        Button {
                            copyPath(shortcut.startPath)
                        } label: {
                            Label(language.text("shortcuts.copy_path"), systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteShortcut(shortcut)
                        } label: {
                            Label(language.text("shortcuts.delete"), systemImage: "trash")
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteShortcut(shortcut)
                        } label: {
                            Label(language.text("shortcuts.delete"), systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(language.text("shortcuts.count", Int64(filteredShortcuts.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }

        Section {
            DekpopFooterView()
        }
    }

    @ViewBuilder
    private var modsContent: some View {
        Section {
            ForEach(ModSite.all) { site in
                Button {
                    activeSheet = .site(site)
                } label: {
                    HStack(spacing: 10) {
                        AppRowIcon(
                            systemName: "globe",
                            tint: AppTheme.accentSecondary,
                            frameSize: 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.title)
                                .font(.subheadline.weight(.bold))
                            Text(language.text(site.subtitleKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(language.text("mods.title"))
        } footer: {
            Text(language.text("mods.footer"))
        }

        Section {
            Text(language.text("mods.intro"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Section {
            DekpopFooterView()
        }
    }

    private func shortcutRow(_ shortcut: FolderShortcut) -> some View {
        HStack(spacing: 10) {
            AppRowIcon(
                systemName: "folder.fill",
                tint: AppTheme.accentSecondary,
                frameSize: 34
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text(shortcut.relativePath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            BrowserAppIcon(app: app)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text(app.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if !app.version.isEmpty {
                Text(app.version)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
    }

    private func openInNewTabButton(_ destination: FileBrowserDestination) -> some View {
        Button {
            tabSession.openTab(navigationPath: [destination])
        } label: {
            Label(language.text("browser.open_new_tab"), systemImage: "square.on.square")
        }
    }

    private func openShortcut(_ shortcut: FolderShortcut, inNewTab: Bool) {
        if inNewTab {
            tabSession.openTab(navigationPath: [shortcut.fileBrowserDestination])
        } else {
            tabSession.setActiveNavigationPath([shortcut.fileBrowserDestination])
        }
    }

    private func copyPath(_ path: String) {
        UIPasteboard.general.string = path
        copiedPath = path
    }

    private func loadShortcuts() {
        shortcuts = AssetSetService.loadShortcuts()
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func addShortcut(_ shortcut: FolderShortcut) {
        guard !shortcuts.contains(where: { $0.id == shortcut.id }) else { return }
        var updated = shortcuts
        updated.insert(shortcut, at: 0)
        shortcuts = updated
        AssetSetService.saveShortcuts(updated)
    }

    private func updateShortcut(_ shortcut: FolderShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        var updated = shortcuts
        updated[index] = shortcut
        shortcuts = updated
        AssetSetService.saveShortcuts(updated)
    }

    private func deleteShortcut(_ shortcut: FolderShortcut) {
        var updated = shortcuts
        updated.removeAll { $0.id == shortcut.id }
        shortcuts = updated
        AssetSetService.saveShortcuts(updated)
    }

    // MARK: - Safe access (works on iOS 27.0.1 without any exploit)

    @ViewBuilder
    private var safeAccessSection: some View {
        Section {
            ForEach(safeFolders) { folder in
                Button { openSafeFolder(folder) } label: {
                    HStack(spacing: 10) {
                        AppRowIcon(
                            systemName: "folder.fill",
                            tint: .green,
                            frameSize: 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name)
                                .font(.subheadline.weight(.bold))
                            Text(language.text("safe.folder_subtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        SafeFolderBookmarks.remove(id: folder.id)
                        safeFolders = SafeFolderBookmarks.load()
                    } label: {
                        Label(language.text("safe.remove"), systemImage: "trash")
                    }
                }
            }

            Button { showingFolderPicker = true } label: {
                Label(language.text("safe.choose_folder"), systemImage: "folder.badge.plus")
            }
            Button { showDiagnostics() } label: {
                Label(language.text("safe.diagnostics"), systemImage: "stethoscope")
            }
        } header: {
            Text(language.text("safe.section"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(language.text("safe.section_footer"))
                if let safeFolderNotice {
                    Text(safeFolderNotice)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func showDiagnostics() {
        // The probes touch the filesystem and the container manager; keep
        // them off the main thread so the UI never freezes on a slow device.
        DispatchQueue.global(qos: .userInitiated).async {
            let report = CompatibilitySelfTest.run()
            DispatchQueue.main.async {
                self.activeSheet = .diagnostics(report)
            }
        }
    }

    private func handleFolderPicker(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard SafeFolderBookmarks.add(url: url) else {
                safeFolderNotice = language.text("safe.add_failed")
                log("safe: bookmark creation failed for \(url.lastPathComponent)")
                return
            }
            safeFolderNotice = nil
            safeFolders = SafeFolderBookmarks.load()
            log("safe: granted folder \(url.lastPathComponent)")
            openSafeFolder(safeFolders.last { $0.name == url.lastPathComponent })
        case .failure(let error):
            safeFolderNotice = error.localizedDescription
            log("safe: folder picker failed — \(error.localizedDescription)")
        }
    }

    private func openSafeFolder(_ folder: SafeFolder?) {
        guard let folder, let url = SafeFolderBookmarks.resolve(folder) else {
            safeFolderNotice = language.text("safe.add_failed")
            return
        }
        let destination = FileBrowserDestination(
            containerPath: url.path,
            startPath: url.path,
            title: folder.name,
            bundleID: nil
        )
        tabSession.setActiveNavigationPath([destination])
    }

    private func openWorkspace() {
        guard let path = workspaceURL?.path else { return }
        tabSession.setActiveNavigationPath([
            FileBrowserDestination(
                containerPath: path,
                startPath: path,
                title: DekpopBrand.displayName,
                bundleID: nil
            )
        ])
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.brandGradient)
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)
            Text(language.text("safe.empty_hint", AppInfo.osVersion))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button { openWorkspace() } label: {
                Label(language.text("safe.open_workspace"), systemImage: "folder.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            Button { showingFolderPicker = true } label: {
                Label(language.text("safe.choose_folder"), systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)

            Button { showDiagnostics() } label: {
                Label(language.text("safe.diagnostics"), systemImage: "stethoscope")
            }
            .buttonStyle(.bordered)

            Button(language.text("browser.retry")) { reload() }
                .font(.footnote)
        }
        .padding()
    }

    private var searchEmptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("browser.search_empty"))
                .font(.subheadline.weight(.medium))
            Text(language.text("browser.search_apps_empty_message"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func reload() {
        isLoading = true
        isResolving = true
        errorMessage = nil
        // Re-probe every access layer on each reload. Capabilities can appear
        // after the kernel exploit finishes, so nothing is cached across loads.
        ContainerAccessPolicy.resetProbing()
        let emptyMessage = language.text("browser.empty")
        DispatchQueue.global(qos: .userInitiated).async {
            let bundleMetadata = ContainerStore.applicationBundleMetadataCatalog()
            let apiApps = ContainerStore.applyingBundleMetadata(
                to: ContainerStore.installedAppsFromAPI(),
                catalog: bundleMetadata
            )
            if apiApps.isEmpty {
                log("browser: installed-app API unavailable; trying MCM class-2 enumeration...")
            }
            let dynamicIdentifiers = ContainerStore.dynamicAppIdentifiers()
            let mcmApps = ContainerStore.installedAppsFromMCM(
                identifiers: dynamicIdentifiers,
                bundleMetadata: bundleMetadata
            )
            let filesystemApps = ContainerStore.containersFromFilesystem()
            let baseIdentifiedApps = mcmApps + apiApps
            var result = ContainerDiscoveryMerger.merge(
                enumerated: filesystemApps,
                identified: baseIdentifiedApps,
                path: { $0.containerPath }
            )
            log("browser: merged api=\(apiApps.count), MCM=\(mcmApps.count), filesystem=\(filesystemApps.count) -> \(result.count)")
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            let preliminary = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            DispatchQueue.main.async {
                apps = preliminary
                isLoading = false
            }

            let launchServicesIdentifiers = ContainerStore.launchServicesStoreIdentifiers()
            let mhaIdentifiers = MHAIdentifierCatalog.identifiers(
                dynamic: dynamicIdentifiers,
                installed: apiApps.map(\.bundleID),
                research: ContainerStore.researchAppIdentifiers,
                custom: bundleMetadata.keys.sorted(),
                launchServices: launchServicesIdentifiers
            )
            log(
                "browser: MHA catalog dynamic=\(dynamicIdentifiers.count), " +
                "installed=\(apiApps.count), research=\(ContainerStore.researchAppIdentifiers.count), " +
                "LaunchServices=\(launchServicesIdentifiers.count) -> \(mhaIdentifiers.count) candidates"
            )
            let mhaApps = ContainerStore.installedAppsFromMHACandidates(
                identifiers: mhaIdentifiers,
                bundleMetadata: bundleMetadata
            ) { discoveredApps in
                var progressiveResult = AppDataCatalogMerger.merge(
                    identified: discoveredApps + baseIdentifiedApps,
                    fallback: [],
                    identifier: { $0.bundleID },
                    path: { $0.containerPath }
                )
                progressiveResult = progressiveResult.filter {
                    ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
                }
                progressiveResult.sort {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                DispatchQueue.main.async {
                    apps = progressiveResult
                }
            }

            let allKnownApps = mhaApps + baseIdentifiedApps
            let identifiedPaths = Set(allKnownApps.map {
                ContainerDiscoveryMerger.canonicalPath($0.containerPath)
            })
            let unmatchedFilesystemApps = filesystemApps.filter {
                !identifiedPaths.contains(
                    ContainerDiscoveryMerger.canonicalPath($0.containerPath)
                )
            }
            let inferredFilesystemApps = ContainerStore.inferUnidentifiedApps(
                in: unmatchedFilesystemApps,
                knownApps: allKnownApps,
                launchServicesIdentifiers: Set(launchServicesIdentifiers)
            ).filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            result = AppDataCatalogMerger.merge(
                identified: allKnownApps,
                fallback: inferredFilesystemApps,
                identifier: { $0.bundleID },
                path: { $0.containerPath }
            )
            result = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            result.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

            DispatchQueue.main.async {
                apps = result
                isLoading = false
                isResolving = false
                if result.isEmpty {
                    errorMessage = emptyMessage
                }
            }
        }
    }
}

private enum HomeCategory: String, CaseIterable, Identifiable {
    case apps
    case shortcuts
    case mods

    var id: String { rawValue }

    var titleKey: String {
        "home.category_\(rawValue)"
    }
}

private enum FilesRootSheet: Identifiable {
    case assetSets
    case newShortcut
    case editShortcut(FolderShortcut)
    case site(ModSite)
    case diagnostics(CompatibilitySelfTest.Report)

    var id: String {
        switch self {
        case .assetSets:
            return "assetSets"
        case .newShortcut:
            return "newShortcut"
        case .editShortcut(let shortcut):
            return "edit-\(shortcut.id.uuidString)"
        case .site(let site):
            return "site-\(site.id)"
        case .diagnostics:
            return "diagnostics"
        }
    }
}

private enum AppBrowserOverlayState: Equatable {
    case loading
    case empty
    case noResults
    case none
}

/// In-app compatibility report. Proves which iOS version is running, that it
/// is accepted, and which physical file-access layers actually work here.
struct CompatibilityReportView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    let report: CompatibilitySelfTest.Report

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text(language.text("compat.supported_badge"))
                                .font(.headline)
                        }
                        Text(language.text("compat.header_detail", report.version, report.build))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(report.device)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(language.text("compat.layers")) {
                    ForEach(report.probes) { probe in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: probe.succeeded
                                  ? "checkmark.circle.fill"
                                  : "xmark.circle.fill")
                                .foregroundStyle(probe.succeeded ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.text(probe.titleKey))
                                    .font(.subheadline.weight(.medium))
                                Text(probe.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text(language.text("compat.footer"))
                }

                Section {
                    Button {
                        UIPasteboard.general.string = plainText
                    } label: {
                        Label(language.text("compat.copy"), systemImage: "doc.on.doc")
                    }
                }
            }
            .navigationTitle(language.text("compat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("common.done")) { dismiss() }
                }
            }
        }
    }

    private var plainText: String {
        var lines = [
            "dekpop \(DekpopBrand.version) (\(DekpopBrand.build))",
            "iOS \(report.version) (\(report.build)) · \(report.device)",
            "versionAccepted=\(report.versionAccepted)"
        ]
        for probe in report.probes {
            lines.append("\(probe.id): \(probe.succeeded ? "OK" : "FAIL") — \(probe.detail)")
        }
        return lines.joined(separator: "\n")
    }
}

struct BrowserAppIcon: View {
    let app: InstalledApp
    @State private var resolvedIcon: UIImage?
    @State private var didRequestIcon = false

    init(app: InstalledApp) {
        self.app = app
        _resolvedIcon = State(initialValue: app.icon)
    }

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(uiImage: resolvedIcon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app")
                    .font(.system(size: AppTheme.rowIconSize, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: AppTheme.appIconSize, height: AppTheme.appIconSize)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
        .onAppear {
            guard resolvedIcon == nil, !didRequestIcon else { return }
            didRequestIcon = true
            let bundleID = app.bundleID
            DispatchQueue.global(qos: .utility).async {
                let icon = iconForBundleID(bundleID)
                DispatchQueue.main.async {
                    resolvedIcon = icon
                }
            }
        }
    }
}
