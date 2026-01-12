import SwiftUI

@main
struct NextDNSPeekApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      PreferencesView(viewModel: AppEnvironment.shared.preferencesViewModel)
        .environmentObject(AppEnvironment.shared.appState)
    }
  }
}
