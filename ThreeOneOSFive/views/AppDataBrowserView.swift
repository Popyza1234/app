import SwiftUI
import UIKit

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
            }
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
        .background(AppTheme.pageBackground)
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
            Text(errorMessage ?? language.text("browser.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(language.text("browser.retry")) { reload() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
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
        }
    }
}

private enum AppBrowserOverlayState: Equatable {
    case loading
    case empty
    case noResults
    case none
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
