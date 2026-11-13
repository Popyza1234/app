import SwiftUI
import UIKit

struct AssetSetsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    var apps: [InstalledApp] = []
    @State private var sets: [AssetSet] = []
    @State private var searchText = ""
    @State private var selectedCategory: AssetCategory? = nil
    @State private var isCreating = false

    private var filteredSets: [AssetSet] {
        sets.filter { set in
            let matchesSearch = searchText.isEmpty
                || set.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || set.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilter
                assetGrid
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(language.text("asset.sets_title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: language.text("asset.search_sets")
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(language.text("common.close"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isCreating = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(language.text("asset.new_set"))
                }
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $isCreating) {
            AssetSetEditorView(set: nil) { newSet in
                sets.append(newSet)
                AssetSetService.saveSets(sets)
                isCreating = false
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(
                    title: language.text("common.all"),
                    systemName: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                ForEach(AssetCategory.allCases) { category in
                    CategoryChip(
                        title: category.localizedName(language: language),
                        systemName: category.iconName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, AppTheme.pageInset)
            .padding(.vertical, 10)
        }
    }

    private var assetGrid: some View {
        ScrollView {
            if filteredSets.isEmpty {
                emptyView
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(filteredSets) { set in
                        NavigationLink(value: set) {
                            AssetSetCard(set: set)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.pageInset)
            }
        }
        .navigationDestination(for: AssetSet.self) { set in
            AssetSetDetailView(set: set, apps: apps) { updated in
                if let idx = sets.firstIndex(where: { $0.id == updated.id }) {
                    sets[idx] = updated
                } else {
                    sets.append(updated)
                }
                AssetSetService.saveSets(sets)
            } onDelete: { deleted in
                sets.removeAll { $0.id == deleted.id }
                AssetSetService.deleteItemFiles(of: deleted)
                AssetSetService.saveSets(sets)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            AppRowIcon(systemName: "cube.box", tint: AppTheme.accentSecondary, frameSize: 56)
            Text(language.text("asset.empty_title"))
                .font(.headline)
            Text(language.text("asset.empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { isCreating = true } label: {
                Text(language.text("asset.new_set"))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func load() {
        sets = AssetSetService.loadSets()
    }
}

struct CategoryChip: View {
    let title: String
    let systemName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.accent.opacity(0.18) : AppTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppTheme.accent.opacity(0.45) : Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? AppTheme.accent : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct AssetSetCard: View {
    let set: AssetSet
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardBackground)
                AssetSetIcon(set: set, size: 72)
            }
            .frame(height: 110)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(set.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: set.category.iconName)
                        .font(.caption2)
                    Text(set.category.localizedName(language: language))
                        .font(.caption2)
                    Spacer()
                    Text(language.text("asset.item_count", Int64(set.items.count)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct AssetSetIcon: View {
    let set: AssetSet
    var size: CGFloat = 64

    private var previewImage: UIImage? {
        guard let first = set.items.first,
              let previewURL = AssetSetService.fileURL(for: first, in: set) else { return nil }
        return UIImage(contentsOfFile: previewURL.path)
    }

    var body: some View {
        Group {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.brandGradient
                    Image(systemName: set.category.iconName)
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}
