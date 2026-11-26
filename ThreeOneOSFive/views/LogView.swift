import SwiftUI

struct LogView: View {
    @ObservedObject var appLog = AppLog.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language
    @State private var copied = false
    @State private var showPreviousSessions = false

    private var shareText: String {
        var lines: [String] = []
        lines.append("3105 Log")
        lines.append("iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) — \(AppInfo.machineName)")
        lines.append("Generated: \(Date())")
        lines.append("")
        lines.append(contentsOf: appLog.entries)
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if appLog.entries.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "apple.terminal")
                            .font(.system(size: AppTheme.emptyIconSize, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(language.text("logs.empty_title"))
                            .font(.title3.bold())
                        Text(language.text("logs.empty_message"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(appLog.entries.enumerated()), id: \.offset) { index, entry in
                                    VStack(spacing: 0) {
                                        Text(entry)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 11)

                                        if index < appLog.entries.count - 1 {
                                            Divider()
                                        }
                                    }
                                    .id(index)
                                    .accessibilityLabel(language.text("accessibility.log_entry", Int64(index + 1), entry))
                                }
                            }
                            .padding(AppTheme.pageInset)
                            .background(AppTheme.consoleBackground)
                        }
                        .onChange(of: appLog.entries.count) { count in
                            guard count > 0 else { return }
                            if reduceMotion {
                                proxy.scrollTo(count - 1, anchor: .bottom)
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .background(AppTheme.consoleBackground.ignoresSafeArea())
            .navigationTitle(language.text("logs.title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPreviousSessions) {
                PreviousSessionLogView()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        showPreviousSessions = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel(language.text("logs.previous_sessions"))

                    Button(language.text("logs.clear"), role: .destructive) { appLog.entries.removeAll() }
                        .disabled(appLog.entries.isEmpty)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = shareText
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(appLog.entries.isEmpty)
                    .accessibilityLabel(language.text("logs.copy"))

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(appLog.entries.isEmpty)
                    .accessibilityLabel(language.text("logs.share"))

                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct PreviousSessionLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @State private var sessions: [SessionLogFile] = []

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    Section {
                        Text(language.text("logs.previous_empty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(sessions) { session in
                            NavigationLink {
                                PreviousSessionLogDetailView(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.startedAt, style: .date)
                                    Text(session.startedAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(language.text("logs.previous_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                sessions = SessionLogStore.previousSessions()
            }
        }
    }
}

private struct PreviousSessionLogDetailView: View {
    @Environment(\.appLanguage) private var language
    let session: SessionLogFile

    private var text: String {
        let contents = SessionLogStore.contents(of: session)
        return contents.isEmpty ? language.text("logs.previous_empty") : contents
    }

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.pageInset)
                .background(AppTheme.consoleBackground)
        }
        .background(AppTheme.consoleBackground.ignoresSafeArea())
        .navigationTitle(language.text("logs.previous_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ShareLink(item: text) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(language.text("logs.share"))
            }
        }
    }
}
