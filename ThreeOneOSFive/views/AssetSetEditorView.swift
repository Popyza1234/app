import SwiftUI
import UniformTypeIdentifiers

struct AssetSetEditorView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: AssetCategory
    @State private var version: String
    @State private var items: [AssetItem]
    @State private var newItemSlot: AssetSlot = .other
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var didSave = false
    @State private var importedItems: [AssetItem] = []

    private let editingSet: AssetSet?
    private let workingSetID: UUID
    private let createdAt: Date
    private let originalItems: [AssetItem]
    private let onSave: (AssetSet) -> Void

    init(set: AssetSet?, onSave: @escaping (AssetSet) -> Void) {
        self.editingSet = set
        self.onSave = onSave
        self.workingSetID = set?.id ?? UUID()
        self.createdAt = set?.createdAt ?? Date()
        self.originalItems = set?.items ?? []
        _name = State(initialValue: set?.name ?? "")
        _category = State(initialValue: set?.category ?? .outfit)
        _version = State(initialValue: set?.version ?? "1.0")
        _items = State(initialValue: set?.items ?? [])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var workingSet: AssetSet {
        AssetSet(
            id: workingSetID,
            name: name,
            category: category,
            version: version,
            iconName: category.iconName,
            createdAt: createdAt,
            items: items
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("asset.basic_info")) {
                    TextField(language.text("asset.name_placeholder"), text: $name)
                    Picker(language.text("asset.category"), selection: $category) {
                        ForEach(AssetCategory.allCases) { cat in
                            Text(cat.localizedName(language: language)).tag(cat)
                        }
                    }
                    TextField(language.text("asset.version_placeholder"), text: $version)
                }

                Section {
                    Picker(language.text("asset.slot_for_next"), selection: $newItemSlot) {
                        ForEach(AssetSlot.allCases) { slot in
                            Text(slot.localizedName(language: language)).tag(slot)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        isImporting = true
                    } label: {
                        Label(language.text("asset.import_files"), systemImage: "square.and.arrow.down")
                    }
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [.data, .image, .archive],
                        allowsMultipleSelection: true
                    ) { result in
                        handleImport(result: result)
                    }

                    if items.isEmpty {
                        Text(language.text("asset.no_items_yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .lineLimit(1)
                                    Text(item.relativePath)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Picker(
                                    language.text("asset.slot"),
                                    selection: Binding(
                                        get: { item.slot },
                                        set: { setSlot($0, for: item.id) }
                                    )
                                ) {
                                    ForEach(AssetSlot.allCases) { slot in
                                        Text(slot.localizedName(language: language)).tag(slot)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }
                        .onDelete { indexSet in
                            items.remove(atOffsets: indexSet)
                        }
                    }
                } header: {
                    Text(language.text("asset.items_section"))
                } footer: {
                    if !items.isEmpty {
                        Text(language.text("asset.items_footer", Int64(items.count)))
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
            .navigationTitle(editingSet == nil ? language.text("asset.new_set") : language.text("asset.edit_set"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("common.save")) { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .onDisappear(perform: discardUnusedFiles)
    }

    private func setSlot(_ slot: AssetSlot, for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].slot = slot
    }

    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard !urls.isEmpty else { return }
            let importResults = AssetSetService.importFiles(
                urls: urls,
                into: workingSet,
                slot: newItemSlot
            )
            var imported: [AssetItem] = []
            for (item, outcome) in importResults {
                if case .success = outcome {
                    imported.append(item)
                }
            }
            items.append(contentsOf: imported)
            importedItems.append(contentsOf: imported)
            if imported.count != importResults.count {
                errorMessage = language.text("asset.import_partial", Int64(imported.count), Int64(importResults.count))
            } else {
                errorMessage = nil
            }
        } catch {
            errorMessage = language.text("asset.import_failed")
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        var set = workingSet
        set.name = trimmedName
        let remainingIDs = Set(items.map(\.id))
        for item in originalItems + importedItems where !remainingIDs.contains(item.id) {
            AssetSetService.deleteItemFile(item, in: set)
        }
        didSave = true
        onSave(set)
        dismiss()
    }

    private func discardUnusedFiles() {
        guard !didSave else { return }
        if editingSet == nil {
            AssetSetService.deleteItemFiles(of: workingSet)
            return
        }
        for item in importedItems {
            AssetSetService.deleteItemFile(item, in: workingSet)
        }
    }
}
