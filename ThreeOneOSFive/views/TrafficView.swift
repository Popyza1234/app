import SwiftUI
import UIKit

/// Request/response inspector: the app's own calls plus flows captured by the
/// mitmproxy instance the customer already runs.
struct TrafficView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var recorder = TrafficRecorder.shared

    @State private var source: Source = .app
    @State private var remote: [TrafficEntry] = []
    @State private var query = ""
    @State private var isRefreshing = false
    @State private var failure: String?
    @State private var config = FlowClient.Config()
    @State private var selected: TrafficEntry?
    @State private var screenWidth = DekpopLayout.defaultWidth

    enum Source: String, CaseIterable {
        case app
        case proxy
    }

    private var visible: [TrafficEntry] {
        let base = source == .app ? recorder.entries : remote
        guard !query.isEmpty else { return base }
        let needle = query.lowercased()
        return base.filter {
            $0.url.lowercased().contains(needle) || $0.method.lowercased().contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DekpopAuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("", selection: $source) {
                            Text(language.text("traffic.tab_app")).tag(Source.app)
                            Text(language.text("traffic.tab_proxy")).tag(Source.proxy)
                        }
                        .pickerStyle(.segmented)

                        if source == .proxy {
                            sourceCard
                        }

                        if let failure {
                            Label(failure, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if visible.isEmpty {
                            emptyState
                        } else {
                            ForEach(visible) { entry in
                                Button {
                                    selected = entry
                                } label: {
                                    row(entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .dekpopContentWidth(inset: DekpopLayout.inset(for: screenWidth))
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .dekpopMeasureWidth { screenWidth = $0 }
                .searchable(text: $query, prompt: Text(language.text("traffic.search")))
            }
            .navigationTitle(language.text("traffic.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.close")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .tint(AppTheme.accent)
        .sheet(item: $selected) { entry in
            TrafficDetailView(entry: entry)
        }
        .onAppear { config = FlowClient.Config() }
    }

    // MARK: - Pieces

    private var sourceCard: some View {
        DekpopGlassCard(padding: 14, cornerRadius: DekpopRadius.medium) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("traffic.proxy_source"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("http://82.26.104.242:8081", text: $config.baseURL)
                    .font(.system(.caption, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))

                SecureField(language.text("traffic.token"), text: $config.token)
                    .font(.system(.caption, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))

                Button {
                    config.save()
                    Task { await refresh() }
                } label: {
                    Label(language.text("traffic.load"), systemImage: "arrow.down.circle")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(source == .app ? language.text("traffic.empty_app") : language.text("traffic.empty_proxy"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func row(_ entry: TrafficEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.method)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(methodColor(entry.method))
                .frame(width: 42, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(methodColor(entry.method).opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.shortTarget)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if let status = entry.status {
                        Text("\(status)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(statusColor(entry.statusColorKey))
                    }
                    Text(entry.started, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if entry.duration > 0 {
                        Text("\(Int(entry.duration)) ms")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .green
        case "POST": return .blue
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .secondary
        }
    }

    private func statusColor(_ key: String) -> Color {
        switch key {
        case "ok": return .green
        case "redirect": return .blue
        case "client": return .orange
        case "server": return .red
        default: return .secondary
        }
    }

    // MARK: - Actions

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        failure = nil

        if source == .app {
            // Nothing to fetch: the list is live.
            return
        }

        config.save()
        do {
            remote = try await FlowClient.fetch(config)
            if remote.isEmpty {
                failure = language.text("traffic.empty_proxy")
            }
        } catch {
            failure = language.text("traffic.failed", String(describing: error))
        }
    }
}

/// Full detail for one exchange, with the pieces a debugger actually needs.
struct TrafficDetailView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    let entry: TrafficEntry

    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summary

                    section(language.text("traffic.request_headers"), headers: entry.requestHeaders)
                    if let body = entry.requestBody {
                        bodySection(language.text("traffic.request_body"), text: body)
                    }
                    section(language.text("traffic.response_headers"), headers: entry.responseHeaders)
                    if let body = entry.responseBody {
                        bodySection(language.text("traffic.response_body"), text: body)
                    }

                    Button {
                        UIPasteboard.general.string = entry.curlCommand
                        copied = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label(
                            copied ? language.text("traffic.copied") : language.text("traffic.copy_curl"),
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DekpopGradientButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(language.text("traffic.detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.close")) { dismiss() }
                }
            }
        }
        .tint(AppTheme.accent)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.method)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.accent.opacity(0.15)))

                if let status = entry.status {
                    Text("\(status)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(status < 400 ? Color.green : Color.red)
                }

                Spacer(minLength: 0)

                Text("\(Int(entry.duration)) ms")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(entry.url)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func section(_ title: String, headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            if headers.isEmpty {
                Text("—").font(.caption2).foregroundStyle(.tertiary)
            } else {
                ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack(alignment: .top, spacing: 6) {
                        Text(key)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .frame(width: 110, alignment: .leading)
                        Text(value)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func bodySection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}
