import SwiftUI
import UIKit

struct AssetSetDetailView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State var set: AssetSet
    let apps: [InstalledApp]
    let onSave: (AssetSet) -> Void
    let onDelete: (AssetSet) -> Void

    @State private var isEditing = false
    @State private var showApplySheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                header
            }

            Section {
                if set.items.isEmpty {
                    Text(language.text("asset.no_items"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(set.items) { item in
                        AssetItemRow(item: item, set: set)
                    }
                    .onDelete(perform: deleteItems)
                }
            } header: {
                HStack {
                    Text(language.text("asset.items_section"))
                    Spacer()
                    Text(language.text("asset.item_count", Int64(set.items.count)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    showApplySheet = true
                } label: {
                    Label(language.text("asset.apply_set"), systemImage: "arrow.down.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(AppTheme.accent)
                .disabled(set.items.isEmpty)

                Button {
                    isEditing = true
                } label: {
                    Label(language.text("asset.edit_set"), systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(language.text("asset.delete_set"), systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                }
            } footer: {
                if set.items.isEmpty {
                    Text(language.text("asset.apply_add_items_first"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(language.text("asset.set_detail"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            AssetSetEditorView(set: set) { updated in
                set = updated
                onSave(updated)
                isEditing = false
            }
        }
        .sheet(isPresented: $showApplySheet) {
            AssetSetApplyView(set: set, apps: apps) { result in
                log(
                    "asset-sets: applied \(result.set.name) -> " +
                    "\(result.copiedCount) copied, \(result.skippedCount) skipped, \(result.failedCount) failed"
                )
            }
        }
        .confirmationDialog(
            language.text("asset.delete_confirm_title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("asset.delete_set"), role: .destructive) {
                onDelete(set)
                dismiss()
            }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(language.text("asset.delete_confirm_message"))
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AssetSetIcon(set: set, size: 76)
            VStack(alignment: .leading, spacing: 5) {
                Text(set.name)
                    .font(.title3.weight(.bold))
                HStack(spacing: 6) {
                    Image(systemName: set.category.iconName)
                    Text(set.category.localizedName(language: language))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if !set.version.isEmpty {
                    Text(language.text("asset.version_label", set.version))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(language.text("asset.created_label", formattedCreationDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var formattedCreationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = language.locale
        return formatter.string(from: set.createdAt)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            AssetSetService.deleteItemFile(set.items[index], in: set)
        }
        set.items.remove(atOffsets: offsets)
        onSave(set)
    }
}

struct AssetItemRow: View {
    let item: AssetItem
    let set: AssetSet
    @Environment(\.appLanguage) private var language

    private var fileURL: URL? {
        AssetSetService.fileURL(for: item, in: set)
    }

    private var fileExists: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let fileURL,
               fileExists,
               let uiImage = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                AppRowIcon(
                    systemName: "doc",
                    tint: fileExists ? AppTheme.accent : .orange,
                    frameSize: 46
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.slot.localizedName(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !fileExists {
                Text(language.text("asset.item_missing"))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 3)
    }
}
