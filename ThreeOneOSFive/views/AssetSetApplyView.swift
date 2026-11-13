import SwiftUI
import UniformTypeIdentifiers

struct AssetSetApplyView: View {
    private enum TargetKind: String, CaseIterable, Identifiable {
        case app
        case workspace
        case folder
        case custom

        var id: String { rawValue }

        func title(language: AppLanguage) -> String {
            language.text("asset.destination_\(rawValue)")
        }
    }

    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    let set: AssetSet
    let apps: [InstalledApp]
    let onComplete: (AssetSetApplicationResult) -> Void

    @State private var targetKind: TargetKind
    @State private var selectedAppID: String
    @State private var folderURL: URL?
    @State private var customPath = ""
    @State private var subfolder = ""
    @State private var conflictPolicy: FileConflictPolicy = .replace
    @State private var isChoosingFolder = false
    @State private var isApplying = false
    @State private var result: AssetSetApplicationResult?
    @State private var errorMessage: String?

    init(set: AssetSet, apps: [InstalledApp], onComplete: @escaping (AssetSetApplicationResult) -> Void) {
        self.set = set
        self.apps = apps
        self.onComplete = onComplete
        let firstApp = apps.first { !$0.containerPath.isEmpty }
        _selectedAppID = State(initialValue: firstApp?.bundleID ?? "")
        _targetKind = State(initialValue: firstApp == nil ? .workspace : .app)
    }

    private var appCandidates: [InstalledApp] {
        apps.filter { !$0.containerPath.isEmpty }
    }

    private var normalizedSubfolder: String {
        subfolder
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .joined(separator: "/")
    }

    private var baseTargetURL: URL? {
        switch targetKind {
        case .app:
            guard let app = appCandidates.first(where: { $0.bundleID == selectedAppID }) else { return nil }
            return URL(fileURLWithPath: app.containerPath, isDirectory: true)
        case .workspace:
            return AssetSetService.workspaceURL
        case .folder:
            return folderURL
        case .custom:
            let path = customPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    private var finalTargetURL: URL? {
        guard let base = baseTargetURL else { return nil }
        return normalizedSubfolder.isEmpty
            ? base
            : base.appendingPathComponent(normalizedSubfolder, isDirectory: true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(language.text("asset.apply_intro"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker(language.text("asset.destination"), selection: $targetKind) {
                        ForEach(TargetKind.allCases) { kind in
                            Text(kind.title(language: language)).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)

                    destinationContent

                    TextField(language.text("asset.subfolder"), text: $subfolder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text(language.text("asset.destination"))
                } footer: {
                    if let finalTargetURL {
                        Text(finalTargetURL.path)
                            .font(.caption2.monospaced())
                    } else {
                        Text(language.text("asset.target_missing"))
                            .foregroundStyle(.orange)
                    }
                }

                Section(language.text("asset.conflict_policy")) {
                    Picker(language.text("asset.conflict_policy"), selection: $conflictPolicy) {
                        Text(language.text("asset.conflict_replace")).tag(FileConflictPolicy.replace)
                        Text(language.text("asset.conflict_keep")).tag(FileConflictPolicy.keepBoth)
                        Text(language.text("asset.conflict_fail")).tag(FileConflictPolicy.fail)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Button {
                        apply()
                    } label: {
                        HStack {
                            if isApplying {
                                ProgressView()
                                    .padding(.trailing, 6)
                            }
                            Text(language.text("asset.apply_now"))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .disabled(finalTargetURL == nil || isApplying || set.items.isEmpty)
                    .tint(AppTheme.accent)
                } footer: {
                    if set.items.isEmpty {
                        Text(language.text("asset.apply_add_items_first"))
                    }
                }

                if let result {
                    Section(language.text("asset.apply_result")) {
                        Label(
                            language.text("asset.copied_count", Int64(result.copiedCount)),
                            systemImage: "checkmark.circle"
                        )
                        if result.skippedCount > 0 {
                            Label(
                                language.text("asset.skipped_count", Int64(result.skippedCount)),
                                systemImage: "arrow.right.circle"
                            )
                            .foregroundStyle(.secondary)
                        }
                        if result.failedCount > 0 {
                            Label(
                                language.text("asset.failed_count", Int64(result.failedCount)),
                                systemImage: "exclamationmark.triangle"
                            )
                            .foregroundStyle(.orange)
                        }
                        Text(language.text("asset.applied_to", result.targetDirectory.path))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
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
            .navigationTitle(language.text("asset.apply_set"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.close")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch targetKind {
        case .app:
            if appCandidates.isEmpty {
                Text(language.text("asset.no_apps"))
                    .foregroundStyle(.secondary)
            } else {
                Picker(language.text("asset.app_picker"), selection: $selectedAppID) {
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
        case .folder:
            Button {
                isChoosingFolder = true
            } label: {
                HStack {
                    Label(language.text("asset.choose_folder"), systemImage: "folder")
                    Spacer()
                    if let folderURL {
                        Text(folderURL.lastPathComponent)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .fileImporter(
                isPresented: $isChoosingFolder,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { outcome in
                switch outcome {
                case .success(let urls):
                    folderURL = urls.first
                    errorMessage = nil
                case .failure:
                    errorMessage = language.text("asset.folder_pick_failed")
                }
            }
            if folderURL == nil {
                Text(language.text("asset.folder_none"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .custom:
            TextField(language.text("asset.target_placeholder"), text: $customPath, axis: .vertical)
                .font(.subheadline.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private func apply() {
        guard let target = finalTargetURL else {
            errorMessage = language.text("asset.target_missing")
            return
        }
        let scopedFolder: URL? = targetKind == .folder ? folderURL : nil
        let hasFolderScope = scopedFolder?.startAccessingSecurityScopedResource() ?? false
        isApplying = true
        errorMessage = nil
        result = nil
        let policy = conflictPolicy
        let assetSet = set
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = AssetSetService.apply(set: assetSet, to: target, conflictPolicy: policy)
            DispatchQueue.main.async {
                if hasFolderScope {
                    scopedFolder?.stopAccessingSecurityScopedResource()
                }
                isApplying = false
                result = outcome
                if outcome.copiedCount == 0 && outcome.failedCount > 0 {
                    errorMessage = language.text("asset.apply_all_failed")
                }
                onComplete(outcome)
            }
        }
    }
}
