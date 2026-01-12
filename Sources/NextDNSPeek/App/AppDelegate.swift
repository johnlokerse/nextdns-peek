import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let environment = AppEnvironment.shared
  private var statusBarController: StatusBarController?
  private var preferencesWindowController: PreferencesWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    statusBarController = StatusBarController(
      appState: environment.appState,
      dashboardViewModel: environment.dashboardViewModel,
      allowListViewModel: environment.allowListViewModel,
      onOpenPreferences: { [weak self] in
        self?.openPreferences()
      }
    )

    Task {
      await environment.appState.loadToken()
      if environment.appState.hasToken {
        environment.dashboardViewModel.refresh(reason: .appLaunch)
      }
    }
  }

  private func openPreferences() {
    if preferencesWindowController == nil {
      preferencesWindowController = PreferencesWindowController(
        appState: environment.appState,
        viewModel: environment.preferencesViewModel
      )
    }
    preferencesWindowController?.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
