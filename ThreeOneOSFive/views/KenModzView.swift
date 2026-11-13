import SwiftUI
import UIKit
import WebKit

struct KenModzView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var model = KenModzWebViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                KenModzWebContainer(model: model)

                if model.isLoading {
                    ProgressView(value: min(max(model.progress, 0), 1))
                        .progressViewStyle(.linear)
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 2)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if let errorMessage = model.errorMessage {
                    errorView(message: errorMessage)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .navigationTitle(language.text("kenmodz.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(language.text("common.close"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        openURL(model.currentURL ?? KenModzWebViewModel.homeURL)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel(language.text("kenmodz.open_external"))
                }
            }
            .onAppear {
                model.start()
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            navigationButton(
                systemName: "chevron.left",
                label: language.text("common.back"),
                enabled: model.canGoBack
            ) {
                model.goBack()
            }
            navigationButton(
                systemName: "chevron.right",
                label: language.text("kenmodz.forward"),
                enabled: model.canGoForward
            ) {
                model.goForward()
            }
            Spacer(minLength: 0)
            navigationButton(
                systemName: "house",
                label: language.text("kenmodz.home"),
                enabled: true
            ) {
                model.loadHome()
            }
            Spacer(minLength: 0)
            navigationButton(
                systemName: "arrow.clockwise",
                label: language.text("kenmodz.reload"),
                enabled: true
            ) {
                model.reload()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 50)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func navigationButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 52, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.brandGradient)
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)

            Text(language.text("kenmodz.error_title"))
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message.isEmpty ? language.text("kenmodz.error_message") : message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button(language.text("kenmodz.retry")) {
                    model.reload()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                Button(language.text("kenmodz.open_external")) {
                    openURL(model.currentURL ?? KenModzWebViewModel.homeURL)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct KenModzWebContainer: UIViewRepresentable {
    @ObservedObject var model: KenModzWebViewModel

    func makeUIView(context: Context) -> WKWebView {
        model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

final class KenModzWebViewModel: NSObject, ObservableObject {
    static let homeURL = URL(string: "https://kenmodz.com/")!

    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentURL: URL?
    @Published private(set) var errorMessage: String?

    let webView: WKWebView
    private var observers: [NSKeyValueObservation] = []
    private var hasStarted = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        observe()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        loadHome()
    }

    func loadHome() {
        errorMessage = nil
        webView.load(URLRequest(url: Self.homeURL))
    }

    func reload() {
        errorMessage = nil
        if webView.url == nil {
            loadHome()
        } else {
            webView.reload()
        }
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        webView.goForward()
    }

    private func observe() {
        observers = [
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                self?.publish { $0.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                self?.publish { $0.canGoForward = view.canGoForward }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                self?.publish { $0.isLoading = view.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                self?.publish { $0.progress = view.estimatedProgress }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                self?.publish { $0.currentURL = view.url }
            }
        ]
    }

    private func publish(_ update: @escaping (KenModzWebViewModel) -> Void) {
        if Thread.isMainThread {
            update(self)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                update(self)
            }
        }
    }

    private func handle(_ error: Error) {
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
        publish { $0.errorMessage = error.localizedDescription }
    }
}

extension KenModzWebViewModel: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           !["http", "https", "about", "blob", "data", "file"].contains(scheme) {
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        publish { $0.errorMessage = nil }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        handle(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

extension KenModzWebViewModel: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
