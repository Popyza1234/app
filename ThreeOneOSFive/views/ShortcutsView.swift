import SwiftUI
import UIKit

struct ShortcutEditorView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    let apps: [InstalledApp]
    let shortcut: FolderShortcut?
    let existingShortcuts: [FolderShortcut]
    let onSave: (FolderShortcut) -> Void

    @State private var name: String
    @State private var selectedContainerPath: String
    @State private var path: String
    @State private var statusMessage: String?

    init(
        apps: [InstalledApp],
        shortcut: FolderShortcut?,
        existingShortcuts: [FolderShortcut],
        onSave: @escaping (FolderShortcut) -> Void
    ) {
        self.apps = apps
        self.shortcut = shortcut
        self.existingShortcuts = existingShortcuts
        self.onSave = onSave

        let candidates = apps.filter { !$0.containerPath.isEmpty }
        let workspacePath = ShortcutStore.workspaceURL?.path
        let initialContainer = shortcut?.containerPath
            ?? workspacePath
            ?? candidates.first?.containerPath
            ?? ""
        _selectedContainerPath = State(initialValue: initialContainer)
        _name = State(initialValue: shortcut?.name ?? "")
        _path = State(initialValue: shortcut?.relativePath ?? "")
    }

    private var appCandidates: [InstalledApp] {
        apps.filter { !$0.containerPath.isEmpty }
    }

    private var workspacePath: String? {
        ShortcutStore.workspaceURL?.path
    }

    private var bundleID: String? {
        appCandidates.first { $0.containerPath == selectedContainerPath }?.bundleID
    }

    private var resolvedPath: String {
        guard !selectedContainerPath.isEmpty else { return "" }
        return FolderShortcut.resolvedPath(path: path, containerPath: selectedContainerPath)
    }

    private var duplicate: FolderShortcut? {
        existingShortcuts.first {
            $0.id != shortcut?.id && $0.startPath == resolvedPath
        }
    }

    private var canSave: Bool {
        !selectedContainerPath.isEmpty && !resolvedPath.isEmpty && duplicate == nil
    }

    private var editorTitle: String {
        language.text(shortcut == nil ? "shortcuts.editor_new" : "shortcuts.editor_edit")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(language.text("shortcuts.name_placeholder"), text: $name)
                        .textInputAutocapitalization(.words)

                    Picker(language.text("shortcuts.target"), selection: $selectedContainerPath) {
                        ForEach(appCandidates) { app in
                            Text(app.displayName).tag(app.containerPath)
                        }
                        if let workspacePath {
                            Text(language.text("browser.workspace")).tag(workspacePath)
                        }
                        if !selectedContainerPath.isEmpty,
                           !optionsContain(selectedContainerPath) {
                            Text(fallbackName(for: selectedContainerPath))
                                .tag(selectedContainerPath)
                        }
                    }
                } header: {
                    Text(language.text("shortcuts.details"))
                } footer: {
                    if selectedContainerPath.isEmpty {
                        Text(language.text("shortcuts.target_missing"))
                            .foregroundStyle(.orange)
                    } else {
                        Text(bundleID ?? language.text("browser.workspace"))
                            .font(.caption2.monospaced())
                    }
                }

                Section {
                    TextField(language.text("shortcuts.path_placeholder"), text: $path)
                        .font(.subheadline.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack(spacing: 12) {
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label(language.text("shortcuts.paste"), systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)

                        Button {
                            path = ""
                            statusMessage = nil
                        } label: {
                            Label(language.text("shortcuts.clear"), systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(path.isEmpty)
                    }
                } header: {
                    Text(language.text("shortcuts.path"))
                } footer: {
                    if let statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.orange)
                    } else {
                        Text(language.text("shortcuts.relative_hint"))
                    }
                }

                Section(language.text("shortcuts.preview")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.text("shortcuts.will_open"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(resolvedPath.isEmpty
                            ? language.text("shortcuts.target_missing")
                            : resolvedPath)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)

                    if let duplicate {
                        Label(
                            language.text("shortcuts.duplicate", duplicate.name),
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language.text("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.save")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func optionsContain(_ containerPath: String) -> Bool {
        if containerPath == workspacePath { return true }
        return appCandidates.contains { $0.containerPath == containerPath }
    }

    private func fallbackName(for containerPath: String) -> String {
        let component = (containerPath as NSString).lastPathComponent
        return component.isEmpty ? containerPath : component
    }

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !pasted.isEmpty else {
            statusMessage = language.text("shortcuts.paste_empty")
            return
        }

        if let app = appCandidates.first(where: {
            pasted == $0.containerPath || pasted.hasPrefix($0.containerPath + "/")
        }) {
            selectedContainerPath = app.containerPath
        } else if let workspacePath,
                  pasted == workspacePath || pasted.hasPrefix(workspacePath + "/") {
            selectedContainerPath = workspacePath
        }

        if !selectedContainerPath.isEmpty,
           pasted.hasPrefix(selectedContainerPath + "/") {
            path = String(pasted.dropFirst(selectedContainerPath.count + 1))
        } else {
            path = pasted
        }
        statusMessage = nil

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = (pasted as NSString).lastPathComponent
        }
    }

    private func save() {
        let resolved = resolvedPath
        guard !resolved.isEmpty else {
            statusMessage = language.text("shortcuts.target_missing")
            return
        }
        guard duplicate == nil else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let component = (resolved as NSString).lastPathComponent
        let finalName = trimmedName.isEmpty
            ? (component.isEmpty ? language.text("shortcuts.default_name") : component)
            : trimmedName
        let saved = FolderShortcut(
            id: shortcut?.id ?? UUID(),
            name: finalName,
            containerPath: selectedContainerPath,
            startPath: resolved,
            bundleID: bundleID,
            createdAt: shortcut?.createdAt ?? Date()
        )
        onSave(saved)
        dismiss()
    }
}
