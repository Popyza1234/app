import SwiftUI

@main
struct DekpopApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.defaultRawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: dekpop launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage.resolving(languageCode)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .onAppear {
                    // Migrate stored codes from the removed Vietnamese / Chinese builds.
                    if AppLanguage(rawValue: languageCode) == nil {
                        languageCode = AppLanguage.english.rawValue
                    }
                    appState.detectSupport()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    appState.detectSupport()
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        // Single acceptance gate. It ignores the version string entirely, so
        // point releases (27.0.1), beta builds and future majors are all
        // accepted. Logged so the in-app log proves what this device runs.
        let supported = ExploitSupportPolicy.accepts(
            version: AppInfo.osVersion,
            build: AppInfo.osBuild
        )
        log("compat: iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) accepted=\(supported) — every version is enabled")
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // Universal: sandbox access is an optional enhancement on every iOS
        // version. If a live escape is already present, skip the kernel
        // exploit entirely. A success is never downgraded back to .notStarted
        // — kernel R/W persists for the lifetime of this process, and forcing
        // a re-run when the optional escape disappeared is what broke iOS 27+.
        if KernelExploit.hasSandboxAccess(),
           !exploitStatus.isSuccess,
           !exploitStatus.isFailed {
            exploitStatus = .success(method: "sandbox")
            log("app: active sandbox access detected; skipping kernel exploit")
        }
        ContainerAccessPolicy.resetProbing()
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    ContainerAccessPolicy.resetProbing()
                    log("app: kernel exploit success — universal file access active on iOS \(AppInfo.osVersion)")
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    // A kernel exploit failure is no longer a dead end: Files
                    // keeps trying direct, MCM, grant and inode reads.
                    log("app: kernel exploit failed — file browsing continues with fallback access layers")
                }
            }
        }
    }
}
