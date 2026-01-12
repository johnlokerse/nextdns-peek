import Foundation

@MainActor
final class PreferencesViewModel: ObservableObject {
  @Published var tokenInput = ""
  @Published var statusMessage: String?
  @Published var isWorking = false

  private let appState: AppState
  private let client: NextDNSClient
  private let keychainStore: KeychainStore

  init(appState: AppState, client: NextDNSClient, keychainStore: KeychainStore) {
    self.appState = appState
    self.client = client
    self.keychainStore = keychainStore
  }

  func validateAndSave() {
    let token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      statusMessage = "Token is required"
      return
    }

    isWorking = true
    statusMessage = nil

    Task {
      do {
        let profiles = try await client.fetchProfiles(token)
        try keychainStore.saveToken(token)
        appState.setToken(token, profiles: profiles)
        NotificationCenter.default.post(name: .tokenUpdated, object: nil)
        tokenInput = ""
        statusMessage = "Token saved"
      } catch let error as NextDNSError {
        statusMessage = map(error)
      } catch {
        statusMessage = "Unable to save token"
      }
      isWorking = false
    }
  }

  func removeToken() {
    Task {
      do {
        try keychainStore.deleteToken()
        appState.clearToken()
        statusMessage = "Token removed"
      } catch {
        statusMessage = "Unable to remove token"
      }
    }
  }

  func loadProfiles() {
    guard let token = appState.currentToken(), !token.isEmpty else {
      statusMessage = "Missing API token"
      return
    }

    isWorking = true
    statusMessage = nil

    Task {
      do {
        let profiles = try await client.fetchProfiles(token)
        appState.updateProfiles(profiles)
        statusMessage = "Profiles updated"
      } catch let error as NextDNSError {
        statusMessage = map(error)
      } catch {
        statusMessage = "Unable to load profiles"
      }
      isWorking = false
    }
  }

  private func map(_ error: NextDNSError) -> String {
    switch error {
    case .unauthorized:
      return "Token invalid or expired"
    case .rateLimited:
      return "Rate limited, try again later"
    case .offline:
      return "Offline, check your connection"
    case .server:
      return "Server error, try again"
    case .noProfiles:
      return "No profiles available"
    default:
      return "Unable to validate token"
    }
  }
}
