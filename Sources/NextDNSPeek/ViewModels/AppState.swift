import Foundation

@MainActor
final class AppState: ObservableObject {
  enum AuthState {
    case unknown
    case missingToken
    case valid
    case unauthorized
  }

  @Published var profile: Profile?
  @Published var profiles: [Profile] = [] {
    didSet {
      syncSelectedProfile()
    }
  }
  @Published var lastRefreshAt: Date?
  @Published var lastError: AppError?
  @Published var refreshInterval: RefreshInterval {
    didSet {
      settingsStore.refreshInterval = refreshInterval
    }
  }
  @Published var refreshOnClick: Bool {
    didSet {
      settingsStore.refreshOnClick = refreshOnClick
    }
  }
  @Published var privacyMode: Bool {
    didSet {
      settingsStore.privacyMode = privacyMode
    }
  }
  @Published var timeRange: TimeRange {
    didSet {
      settingsStore.timeRange = timeRange
    }
  }
  @Published var selectedProfileId: String? {
    didSet {
      settingsStore.selectedProfileId = selectedProfileId
      syncSelectedProfile()
    }
  }
  @Published var authState: AuthState
  @Published private(set) var hasToken: Bool

  private let settingsStore: SettingsStore
  private let keychainStore: KeychainStore
  private var token: String?

  init(settingsStore: SettingsStore, keychainStore: KeychainStore) {
    self.settingsStore = settingsStore
    self.keychainStore = keychainStore
    refreshInterval = settingsStore.refreshInterval
    refreshOnClick = settingsStore.refreshOnClick
    privacyMode = settingsStore.privacyMode
    timeRange = settingsStore.timeRange
    selectedProfileId = settingsStore.selectedProfileId
    authState = .unknown
    hasToken = false
  }

  func loadToken() async {
    do {
      token = try keychainStore.loadToken()
      hasToken = token != nil
      authState = token == nil ? .missingToken : .unknown
    } catch {
      token = nil
      hasToken = false
      authState = .missingToken
    }
  }

  func setToken(_ token: String, profiles: [Profile]) {
    self.token = token
    hasToken = true
    authState = .valid
    updateProfiles(profiles)
  }

  func clearToken() {
    token = nil
    hasToken = false
    authState = .missingToken
    profile = nil
    profiles = []
    selectedProfileId = nil
    lastError = nil
  }

  func currentToken() -> String? {
    token
  }

  func updateProfiles(_ profiles: [Profile]) {
    self.profiles = profiles
    syncSelectedProfile()
  }

  func setError(_ error: AppError?) {
    lastError = error
  }

  private func syncSelectedProfile() {
    guard !profiles.isEmpty else {
      profile = nil
      return
    }

    if let selectedProfileId,
       let match = profiles.first(where: { $0.id == selectedProfileId }) {
      profile = match
      return
    }

    let first = profiles[0]
    if selectedProfileId != first.id {
      selectedProfileId = first.id
    }
    profile = first
  }
}
