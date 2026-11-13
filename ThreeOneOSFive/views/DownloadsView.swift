import SwiftUI
import UniformTypeIdentifiers

/// One place for everything the user installs or jumps to:
/// saved asset sets with one-tap downloads and quick folder shortcuts.
struct DownloadsView: View {
    private enum ActiveSheet: Identifiable {
        case destination(AssetSet)
        case editShortcut(DownloadShortcut)
        case newShortcut
        case manageSets

        var id: String {
            switch self {
            case .destination(let set): return "destination-\(set.id)"
            case .editShortcut(let shortcut): return "shortcut-\(shortcut.id)"
            case .newShortcut: return "new-shortcut"
            case .manageSets: return "manage-sets"
            }
        }
    }

    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    let apps: [InstalledApp]
    let onOpenDestination: (FileBrowserDestination, Bool) -> Void

    @State private var sets: [AssetSet] = []
    @State private var shortcuts: [DownloadShortcut] = []
    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet?
    @State private var showDownloadAll = false
    @State private var isDownloadingAll = false
    @State private var busySetIDs: Set<UUID> = []
    @State private var results: [UUID: AssetSetApplicationResult] = [:]
    @State private var failureMessage: String?

    private var filteredSets: [AssetSet] {
        guard !searchText.isEmpty else { return sets }
        return sets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredShortcuts: [DownloadShortcut] {
        guard !searchText.isEmpty else { return shortcuts }
        return shortcuts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.startPath.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var downloadableSets: [AssetSet] {
        sets.filter { $0.destination != nil && !$0.items.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                modsSection
                shortcutsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(language.text("downloads.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: language.text("downloads.search")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.close")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .manageSets
                        } label: {
                            Label(language.text("asset.sets_title"), systemImage: "cube.box")
                        }
                        Button {
                            activeSheet = .newShortcut
                        } label: {
                            Label(language.text("downloads.add_shortcut"), systemImage: "plus")
                        }
                        Button {
                            showDownloadAll = true
                        } label: {
                            Label(language.text("downloads.download_all"), systemImage: "arrow.down.circle")
                        }
                        .disabled(downloadableSets.isEmpty || isDownloadingAll)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(language.text("downloads.more"))
                }
            }
        }
        .onAppear(perform: reload)
        .sheet(item: $activeSheet, onDismiss: reload) { sheet in
            switch sheet {
            case .destination(let set):
                DownloadDestinationEditorView(apps: apps, initial: set.destination) { destination in
                    saveDestination(destination, for: set.id)
                }
            case .editShortcut(let shortcut):
                DownloadShortcutEditorView(apps: apps, shortcut: shortcut) { updated in
                    saveShortcut(updated)
                }
            case .newShortcut:
                DownloadShortcutEditorView(apps: apps, shortcut: nil) { created in
                    saveShortcut(created)
                }
            case .manageSets:
                AssetSetsView(apps: apps)
            }
        }
        .confirmationDialog(
            language.text("downloads.download_all_confirm_title"),
            isPresented: $showDownloadAll,
            titleVisibility: .visible
        ) {
            Button(language.text("downloads.download_all")) { downloadAll() }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(language.text("downloads.download_all_confirm_message", Int64(downloadableSets.count)))
        }
        .alert(
            language.text("downloads.error_title"),
            isPresented: Binding(
                get: { failureMessage != nil },
                set: { if !$0 { failureMessage = nil } }
            )
        ) {
            Button(language.text("common.ok"), role: .cancel) { failureMessage = nil }
        } message: {
            Text(failureMessage ?? "")
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 14) {
                AppRowIcon(systemName: "arrow.down.circle.fill", tint: AppTheme.accent, frameSize: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("downloads.summary_title"))
                        .font(.headline)
                    Text(language.text("downloads.summary_subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(language.text("downloads.mod_count", Int64(sets.count)))
                        .font(.caption.weight(.semibold))
                    Text(language.text("downloads.shortcut_count", Int64(shortcuts.count)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var modsSection: some View {
        Section {
            if sets.isEmpty {
                Text(language.text("downloads.no_mods"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredSets) { set in
                    modRow(set)
                }
            }
            Button {
                activeSheet = .manageSets
            } label: {
                Label(language.text("asset.sets_title"), systemImage: "cube.box")
            }
        } header: {
            Text(language.text("downloads.mods_section"))
        } footer: {
            Text(language.text("downloads.mods_footer"))
        }
    }

    private func modRow(_ set: AssetSet) -> some View {
        let isBusy = busySetIDs.contains(set.id)
        let result = results[set.id]
        return HStack(spacing: 12) {
            AssetSetIcon(set: set, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(set.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let destination = set.destination {
                    Label(destination.summary, systemImage: destination.kind.iconName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Label(language.text("downloads.no_destination"), systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if let result {
                    resultLine(result)
                } else if let lastAppliedAt = set.lastAppliedAt {
                    Text(language.text("downloads.last_applied", formattedDate(lastAppliedAt)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if set.destination != nil {
                Button {
                    download(set)
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .tint(AppTheme.accent)
                .accessibilityLabel(language.text("downloads.download"))
            } else {
                Button {
                    activeSheet = .destination(set)
                } label: {
                    Text(language.text("downloads.set_destination"))
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            if set.destination != nil {
                Button {
                    download(set)
                } label: {
                    Label(language.text("downloads.download"), systemImage: "arrow.down.circle")
                }
                Button {
                    activeSheet = .destination(set)
                } label: {
                    Label(language.text("downloads.edit_destination"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    clearDestination(for: set.id)
                } label: {
                    Label(language.text("downloads.clear_destination"), systemImage: "xmark.circle")
                }
            } else {
                Button {
                    activeSheet = .destination(set)
                } label: {
                    Label(language.text("downloads.set_destination"), systemImage: "folder.badge.plus")
                }
            }
        }
    }

    private func resultLine(_ result: AssetSetApplicationResult) -> some View {
        HStack(spacing: 5) {
            Image(systemName: result.failedCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
            Text(
                language.text(
                    "downloads.result",
                    Int64(result.copiedCount),
                    Int64(result.skippedCount),
                    Int64(result.failedCount)
                )
            )
        }
        .font(.caption2)
        .foregroundStyle(result.failedCount == 0 ? Color.secondary : Color.orange)
    }

    private var shortcutsSection: some View {
        Section {
            if shortcuts.isEmpty {
                Text(language.text("downloads.no_shortcuts"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredShortcuts) { shortcut in
                    Button {
                        openShortcut(shortcut, inNewTab: false)
                    } label: {
                        shortcutRow(shortcut)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            openShortcut(shortcut, inNewTab: false)
                        } label: {
                            Label(language.text("downloads.open"), systemImage: "arrow.up.right.square")
                        }
                        Button {
                            openShortcut(shortcut, inNewTab: true)
                        } label: {
                            Label(language.text("downloads.open_new_tab"), systemImage: "square.on.square")
                        }
                        Button {
                            activeSheet = .editShortcut(shortcut)
                        } label: {
                            Label(language.text("downloads.edit_shortcut"), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteShortcut(shortcut)
                        } label: {
                            Label(language.text("downloads.delete_shortcut"), systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteShortcuts)
            }

            Button {
                activeSheet = .newShortcut
            } label: {
                Label(language.text("downloads.add_shortcut"), systemImage: "plus.circle")
            }
        } header: {
            Text(language.text("downloads.shortcuts_section"))
        } footer: {
            Text(language.text("downloads.shortcuts_footer"))
        }
    }

    private func shortcutRow(_ shortcut: DownloadShortcut) -> some View {
        HStack(spacing: 12) {
            AppRowIcon(
                systemName: shortcut.bundleID == nil ? "folder.fill" : "app",
                tint: AppTheme.accentSecondary,
                frameSize: 40
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(shortcut.startPath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private func reload() {
        sets = AssetSetService.loadSets()
        shortcuts = AssetSetService.loadShortcuts()
    }

    private func saveDestination(_ destination: AssetSetDestination, for setID: UUID) {
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        sets[index].destination = destination
        AssetSetService.saveSets(sets)
    }

    private func clearDestination(for setID: UUID) {
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        sets[index].destination = nil
        AssetSetService.saveSets(sets)
    }

    private func download(_ set: AssetSet) {
        guard let destination = set.destination else {
            activeSheet = .destination(set)
            return
        }
        guard let target = destination.targetURL(workspaceURL: AssetSetService.workspaceURL) else {
            failureMessage = language.text("downloads.invalid_destination")
            return
        }
        guard !busySetIDs.contains(set.id) else { return }

        busySetIDs.insert(set.id)
        results[set.id] = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = AssetSetService.apply(set: set, to: target, conflictPolicy: .replace)
            DispatchQueue.main.async {
                busySetIDs.remove(set.id)
                results[set.id] = result
                if result.copiedCount == 0 && result.failedCount > 0 {
                    failureMessage = language.text("downloads.download_failed")
                }
                if result.copiedCount > 0 {
                    markApplied(set.id)
                }
            }
        }
    }

    private func markApplied(_ setID: UUID) {
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        sets[index].lastAppliedAt = Date()
        AssetSetService.saveSets(sets)
    }

    private func downloadAll() {
        let queue = downloadableSets.filter { !busySetIDs.contains($0.id) }
        guard !queue.isEmpty else { return }
        isDownloadingAll = true
        for set in queue {
            busySetIDs.insert(set.id)
            results[set.id] = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var newResults: [UUID: AssetSetApplicationResult] = [:]
            var failedSets = 0
            for set in queue {
                guard let destination = set.destination,
                      let target = destination.targetURL(workspaceURL: AssetSetService.workspaceURL) else {
                    continue
                }
                let result = AssetSetService.apply(set: set, to: target, conflictPolicy: .replace)
                newResults[set.id] = result
                if result.copiedCount == 0 && result.failedCount > 0 {
                    failedSets += 1
                }
            }
            DispatchQueue.main.async {
                isDownloadingAll = false
                for set in queue {
                    busySetIDs.remove(set.id)
                    if let result = newResults[set.id] {
                        results[set.id] = result
                        if result.copiedCount > 0,
                           let index = sets.firstIndex(where: { $0.id == set.id }) {
                            sets[index].lastAppliedAt = Date()
                        }
                    }
                }
                AssetSetService.saveSets(sets)
                if failedSets > 0 {
                    failureMessage = language.text("downloads.download_all_partial", Int64(failedSets))
                }
            }
        }
    }

    private func saveShortcut(_ shortcut: DownloadShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
        } else {
            shortcuts.append(shortcut)
        }
        shortcuts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        AssetSetService.saveShortcuts(shortcuts)
    }

    private func deleteShortcut(_ shortcut: DownloadShortcut) {
        shortcuts.removeAll { $0.id == shortcut.id }
        AssetSetService.saveShortcuts(shortcuts)
    }

    private func deleteShortcuts(at offsets: IndexSet) {
        let ids = Set(offsets.map { filteredShortcuts[$0].id })
        shortcuts.removeAll { ids.contains($0.id) }
        AssetSetService.saveShortcuts(shortcuts)
    }

    private func openShortcut(_ shortcut: DownloadShortcut, inNewTab: Bool) {
        onOpenDestination(shortcut.fileBrowserDestination, inNewTab)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = language.locale
        return formatter.string(from: date)
    }
}

struct DownloadDestinationEditorView: View {
    private enum TargetKind: String, CaseIterable, Identifiable {
        case app
        case workspace
        case custom

        var id: String { rawValue }

        func title(language: AppLanguage) -> String {
            language.text("downloads.target_\(rawValue)")
        }
    }

    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    let apps: [InstalledApp]
    let onSave: (AssetSetDestination) -> Void

    @State private var kind: TargetKind
    @State private var selectedAppID: String
    @State private var customPath: String
    @State private var subfolder: String
    @State private var isChoosingFolder = false
    @State private var errorMessage: String?

    init(
        apps: [InstalledApp],
        initial: AssetSetDestination?,
        onSave: @escaping (AssetSetDestination) -> Void
    ) {
        self.apps = apps
        self.onSave = onSave
        let candidates = apps.filter { !$0.containerPath.isEmpty }
        let initialKind: TargetKind
        if let initial {
            switch initial.kind {
            case .app: initialKind = .app
            case .workspace: initialKind = .workspace
            case .custom: initialKind = .custom
            }
        } else {
            initialKind = candidates.isEmpty ? .workspace : .app
        }
        _kind = State(initialValue: initialKind)
        let matchingApp = candidates.first { $0.containerPath == initial?.path }
        _selectedAppID = State(initialValue: matchingApp?.bundleID ?? candidates.first?.bundleID ?? "")
        _customPath = State(initialValue: initial?.kind == .custom ? (initial?.path ?? "") : "")
        _subfolder = State(initialValue: initial?.subfolder ?? "")
    }

    private var appCandidates: [InstalledApp] {
        apps.filter { !$0.containerPath.isEmpty }
    }

    private var trimmedCustomPath: String {
        customPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSubfolder: String {
        subfolder
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .joined(separator: "/")
    }

    private var baseURL: URL? {
        switch kind {
        case .app:
            guard let app = appCandidates.first(where: { $0.bundleID == selectedAppID }) else { return nil }
            return URL(fileURLWithPath: app.containerPath, isDirectory: true)
        case .workspace:
            return AssetSetService.workspaceURL
        case .custom:
            return trimmedCustomPath.isEmpty
                ? nil
                : URL(fileURLWithPath: trimmedCustomPath, isDirectory: true)
        }
    }

    private var finalURL: URL? {
        guard let baseURL else { return nil }
        return normalizedSubfolder.isEmpty
            ? baseURL
            : baseURL.appendingPathComponent(normalizedSubfolder, isDirectory: true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(language.text("downloads.destination_target"), selection: $kind) {
                        ForEach(TargetKind.allCases) { target in
                            Text(target.title(language: language)).tag(target)
                        }
                    }
                    .pickerStyle(.menu)

                    targetContent

                    TextField(language.text("asset.subfolder"), text: $subfolder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text(language.text("downloads.destination_title"))
                } footer: {
                    if let finalURL {
                        Text(finalURL.path)
                            .font(.caption2.monospaced())
                    } else {
                        Text(language.text("asset.target_missing"))
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(language.text("downloads.destination_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("common.save")) { save() }
                        .disabled(finalURL == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var targetContent: some View {
        switch kind {
        case .app:
            if appCandidates.isEmpty {
                Text(language.text("asset.no_apps"))
                    .foregroundStyle(.secondary)
            } else {
                Picker(language.text("downloads.destination_app"), selection: $selectedAppID) {
                    ForEach(appCandidates) { app in
                        Text(app.displayName).tag(app.bundleID)
                    }
                }
                .pickerStyle(.menu)
            }
        case .workspace:
            if let workspace = AssetSetService.workspaceURL {
                Text(workspace.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text(language.text("asset.target_missing"))
                    .foregroundStyle(.orange)
            }
        case .custom:
            TextField(language.text("downloads.custom_path_placeholder"), text: $customPath)
                .font(.subheadline.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                isChoosingFolder = true
            } label: {
                Label(language.text("asset.choose_folder"), systemImage: "folder")
            }
            .fileImporter(
                isPresented: $isChoosingFolder,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { outcome in
                switch outcome {
                case .success(let urls):
                    if let url = urls.first {
                        customPath = url.path
                        errorMessage = nil
                    }
                case .failure:
                    errorMessage = language.text("asset.folder_pick_failed")
                }
            }
        }
    }

    private func save() {
        guard let resolved = resolvedDestination() else {
            errorMessage = language.text("asset.target_missing")
            return
        }
        onSave(resolved)
        dismiss()
    }

    private func resolvedDestination() -> AssetSetDestination? {
        guard finalURL != nil else { return nil }
        switch kind {
        case .app:
            guard let app = appCandidates.first(where: { $0.bundleID == selectedAppID }) else { return nil }
            return AssetSetDestination(
                kind: .app,
                path: app.containerPath,
                subfolder: normalizedSubfolder,
                displayName: app.displayName
            )
        case .workspace:
            guard let workspace = AssetSetService.workspaceURL else { return nil }
            return AssetSetDestination(
                kind: .workspace,
                path: workspace.path,
                subfolder: normalizedSubfolder,
                displayName: language.text("downloads.workspace_label")
            )
        case .custom:
            guard !trimmedCustomPath.isEmpty else { return nil }
            let folderName = URL(fileURLWithPath: trimmedCustomPath, isDirectory: true).lastPathComponent
            return AssetSetDestination(
                kind: .custom,
                path: trimmedCustomPath,
                subfolder: normalizedSubfolder,
                displayName: folderName.isEmpty ? trimmedCustomPath : folderName
            )
        }
    }
}

struct DownloadShortcutEditorView: View {
    private enum TargetKind: String, CaseIterable, Identifiable {
        case app
        case workspace
        case custom

        var id: String { rawValue }

        func title(language: AppLanguage) -> String {
            language.text("downloads.target_\(rawValue)")
        }
    }

    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    let apps: [InstalledApp]
    let shortcut: DownloadShortcut?
    let onSave: (DownloadShortcut) -> Void

    @State private var name: String
    @State private var kind: TargetKind
    @State private var selectedAppID: String
    @State private var customPath: String
    @State private var subfolder: String
    @State private var isChoosingFolder = false
    @State private var errorMessage: String?

    init(
        apps: [InstalledApp],
        shortcut: DownloadShortcut?,
        onSave: @escaping (DownloadShortcut) -> Void
    ) {
        self.apps = apps
        self.shortcut = shortcut
        self.onSave = onSave
        let candidates = apps.filter { !$0.containerPath.isEmpty }
        let workspacePath = AssetSetService.workspaceURL?.path

        let inferredKind: TargetKind
        if let shortcut {
            if shortcut.bundleID != nil {
                inferredKind = .app
            } else if let workspacePath, shortcut.containerPath == workspacePath {
                inferredKind = .workspace
            } else {
                inferredKind = .custom
            }
        } else {
            inferredKind = candidates.isEmpty ? .workspace : .app
        }
        _kind = State(initialValue: inferredKind)

        let matchingApp = candidates.first { $0.bundleID == shortcut?.bundleID }
        _selectedAppID = State(initialValue: matchingApp?.bundleID ?? candidates.first?.bundleID ?? "")

        let base = shortcut?.containerPath ?? ""
        let inferredSubfolder: String
        if let shortcut, shortcut.startPath.hasPrefix(base + "/") {
            inferredSubfolder = String(shortcut.startPath.dropFirst(base.count + 1))
        } else {
            inferredSubfolder = ""
        }
        _customPath = State(initialValue: inferredKind == .custom ? base : "")
        _subfolder = State(initialValue: inferredSubfolder)
        _name = State(initialValue: shortcut?.name ?? "")
    }

    private var appCandidates: [InstalledApp] {
        apps.filter { !$0.containerPath.isEmpty }
    }

    private var trimmedCustomPath: String {
        customPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSubfolder: String {
        subfolder
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .joined(separator: "/")
    }

    private var baseURL: URL? {
        switch kind {
        case .app:
            guard let app = appCandidates.first(where: { $0.bundleID == selectedAppID }) else { return nil }
            return URL(fileURLWithPath: app.containerPath, isDirectory: true)
        case .workspace:
            return AssetSetService.workspaceURL
        case .custom:
            return trimmedCustomPath.isEmpty
                ? nil
                : URL(fileURLWithPath: trimmedCustomPath, isDirectory: true)
        }
    }

    private var finalURL: URL? {
        guard let baseURL else { return nil }
        return normalizedSubfolder.isEmpty
            ? baseURL
            : baseURL.appendingPathComponent(normalizedSubfolder, isDirectory: true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("downloads.shortcut_name")) {
                    TextField(language.text("downloads.shortcut_name_placeholder"), text: $name)
                }

                Section {
                    Picker(language.text("downloads.shortcut_target"), selection: $kind) {
                        ForEach(TargetKind.allCases) { target in
                            Text(target.title(language: language)).tag(target)
                        }
                    }
                    .pickerStyle(.menu)

                    targetContent

                    TextField(language.text("asset.subfolder"), text: $subfolder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text(language.text("downloads.shortcut_target"))
                } footer: {
                    if let finalURL {
                        Text(finalURL.path)
                            .font(.caption2.monospaced())
                    } else {
                        Text(language.text("asset.target_missing"))
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(
                shortcut == nil
                    ? language.text("downloads.add_shortcut")
                    : language.text("downloads.edit_shortcut")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("common.save")) { save() }
                        .disabled(finalURL == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var targetContent: some View {
        switch kind {
        case .app:
            if appCandidates.isEmpty {
                Text(language.text("asset.no_apps"))
                    .foregroundStyle(.secondary)
            } else {
                Picker(language.text("downloads.destination_app"), selection: $selectedAppID) {
                    ForEach(appCandidates) { app in
                        Text(app.displayName).tag(app.bundleID)
                    }
                }
                .pickerStyle(.menu)
            }
        case .workspace:
            if let workspace = AssetSetService.workspaceURL {
                Text(workspace.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text(language.text("asset.target_missing"))
                    .foregroundStyle(.orange)
            }
        case .custom:
            TextField(language.text("downloads.custom_path_placeholder"), text: $customPath)
                .font(.subheadline.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                isChoosingFolder = true
            } label: {
                Label(language.text("asset.choose_folder"), systemImage: "folder")
            }
            .fileImporter(
                isPresented: $isChoosingFolder,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { outcome in
                switch outcome {
                case .success(let urls):
                    if let url = urls.first {
                        customPath = url.path
                        errorMessage = nil
                    }
                case .failure:
                    errorMessage = language.text("asset.folder_pick_failed")
                }
            }
        }
    }

    private func save() {
        guard let base = baseURL, let final = finalURL else {
            errorMessage = language.text("asset.target_missing")
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName: String
        if !trimmedName.isEmpty {
            resolvedName = trimmedName
        } else if kind == .app,
                  let app = appCandidates.first(where: { $0.bundleID == selectedAppID }) {
            resolvedName = app.displayName
        } else if kind == .workspace {
            resolvedName = language.text("downloads.workspace_label")
        } else {
            let folderName = URL(fileURLWithPath: trimmedCustomPath, isDirectory: true).lastPathComponent
            resolvedName = folderName.isEmpty
                ? language.text("downloads.shortcut_default_name")
                : folderName
        }

        let updated = DownloadShortcut(
            id: shortcut?.id ?? UUID(),
            name: resolvedName,
            containerPath: base.path,
            startPath: final.path,
            bundleID: kind == .app ? selectedAppID : nil,
            createdAt: shortcut?.createdAt ?? Date()
        )
        onSave(updated)
        dismiss()
    }
}
