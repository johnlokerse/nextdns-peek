import Foundation

@MainActor
final class AppEnvironment {
  static let shared = AppEnvironment()

  let appState: AppState
  let dashboardViewModel: DashboardViewModel
  let allowListViewModel: AllowListViewModel
  let preferencesViewModel: PreferencesViewModel

  private init() {
    let settingsStore = SettingsStore()
    let keychainStore = KeychainStore()
    let client = NextDNSClient()
    let pingClient = NextDNSPingClient()
    appState = AppState(settingsStore: settingsStore, keychainStore: keychainStore)
    dashboardViewModel = DashboardViewModel(appState: appState, client: client, pingClient: pingClient)
    allowListViewModel = AllowListViewModel(appState: appState, client: client)
    preferencesViewModel = PreferencesViewModel(
      appState: appState,
      client: client,
      keychainStore: keychainStore
    )
  }
}
