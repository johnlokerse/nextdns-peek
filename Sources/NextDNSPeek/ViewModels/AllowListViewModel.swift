import Combine
import Foundation

@MainActor
final class AllowListViewModel: ObservableObject {
  @Published var entries: [AllowListEntry] = []
  @Published var isLoading = false
  @Published var isWorking = false
  @Published var pendingEntryIds = Set<String>()

  private let appState: AppState
  private let client: NextDNSClient
  private var cancellables = Set<AnyCancellable>()
  private var loadTask: Task<Void, Never>?

  init(appState: AppState, client: NextDNSClient) {
    self.appState = appState
    self.client = client

    appState.$selectedProfileId
      .removeDuplicates()
      .sink { [weak self] _ in
        self?.loadAllowList()
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .tokenUpdated)
      .sink { [weak self] _ in
        self?.loadAllowList()
      }
      .store(in: &cancellables)
  }

  func loadAllowList() {
    loadTask?.cancel()
    loadTask = Task { [weak self] in
      await self?.loadAllowListAsync()
    }
  }

  func addEntry(domain: String) async -> Bool {
    let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDomain.isEmpty else {
      return false
    }

    if entries.contains(where: { $0.domain.caseInsensitiveCompare(trimmedDomain) == .orderedSame }) {
      appState.setError(AppError(kind: .unknown, message: "Domain is already in the allow list", at: Date()))
      return false
    }

    guard let token = appState.currentToken(), !token.isEmpty else {
      appState.authState = .missingToken
      appState.setError(AppError(kind: .unauthorized, message: "Missing API token", at: Date()))
      return false
    }

    isWorking = true
    appState.setError(nil)
    defer {
      isWorking = false
    }

    do {
      let profile = try await ensureProfile(token: token)
      let entry = try await client.addAllowListEntry(
        profileId: profile.id,
        domain: trimmedDomain,
        isEnabled: true,
        token: token
      )
      upsert(entry)
      return true
    } catch let error as NextDNSError {
      handle(error)
      return false
    } catch {
      appState.setError(AppError(kind: .unknown, message: "Unable to add allow list entry", at: Date()))
      return false
    }
  }

  func removeEntry(_ entry: AllowListEntry) async {
    guard let token = appState.currentToken(), !token.isEmpty else {
      appState.authState = .missingToken
      appState.setError(AppError(kind: .unauthorized, message: "Missing API token", at: Date()))
      return
    }

    isWorking = true
    appState.setError(nil)
    defer {
      isWorking = false
    }

    do {
      let profile = try await ensureProfile(token: token)
      try await client.removeAllowListEntry(profileId: profile.id, entryId: entry.id, token: token)
      entries.removeAll { $0.id == entry.id }
    } catch let error as NextDNSError {
      handle(error)
    } catch {
      appState.setError(AppError(kind: .unknown, message: "Unable to remove allow list entry", at: Date()))
    }
  }

  func setEntryEnabled(_ entry: AllowListEntry, isEnabled: Bool) {
    guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
      return
    }

    let previousValue = entries[index].isEnabled
    entries[index].isEnabled = isEnabled
    pendingEntryIds.insert(entry.id)

    Task { [weak self] in
      await self?.updateEntry(
        entryId: entry.id,
        isEnabled: isEnabled,
        fallbackValue: previousValue
      )
    }
  }

  func isEntryPending(_ entry: AllowListEntry) -> Bool {
    pendingEntryIds.contains(entry.id)
  }

  func containsDomain(_ domain: String) -> Bool {
    let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDomain.isEmpty else {
      return false
    }
    return entries.contains { $0.domain.caseInsensitiveCompare(trimmedDomain) == .orderedSame }
  }

  private func loadAllowListAsync() async {
    guard !isLoading else {
      return
    }

    guard let token = appState.currentToken(), !token.isEmpty else {
      appState.authState = .missingToken
      appState.setError(AppError(kind: .unauthorized, message: "Missing API token", at: Date()))
      return
    }

    isLoading = true
    appState.setError(nil)
    defer {
      isLoading = false
    }

    do {
      let profile = try await ensureProfile(token: token)
      let fetchedEntries = try await client.fetchAllowList(profileId: profile.id, token: token)
      entries = fetchedEntries.sorted(by: sortEntries)
    } catch let error as NextDNSError {
      handle(error)
    } catch {
      appState.setError(AppError(kind: .unknown, message: "Unable to load allow list", at: Date()))
    }
  }

  private func updateEntry(entryId: String, isEnabled: Bool, fallbackValue: Bool) async {
    defer {
      pendingEntryIds.remove(entryId)
    }

    guard let token = appState.currentToken(), !token.isEmpty else {
      revertEntry(entryId: entryId, value: fallbackValue)
      appState.authState = .missingToken
      appState.setError(AppError(kind: .unauthorized, message: "Missing API token", at: Date()))
      return
    }

    do {
      let profile = try await ensureProfile(token: token)
      if let updatedEntry = try await client.updateAllowListEntry(
        profileId: profile.id,
        entryId: entryId,
        isEnabled: isEnabled,
        token: token
      ) {
        upsert(updatedEntry)
      }
    } catch let error as NextDNSError {
      revertEntry(entryId: entryId, value: fallbackValue)
      handle(error)
    } catch {
      revertEntry(entryId: entryId, value: fallbackValue)
      appState.setError(AppError(kind: .unknown, message: "Unable to update allow list entry", at: Date()))
    }
  }

  private func revertEntry(entryId: String, value: Bool) {
    guard let index = entries.firstIndex(where: { $0.id == entryId }) else {
      return
    }
    entries[index].isEnabled = value
  }

  private func ensureProfile(token: String) async throws -> Profile {
    if let profile = appState.profile {
      return profile
    }

    let profiles = try await client.fetchProfiles(token)
    appState.updateProfiles(profiles)
    guard let profile = appState.profile else {
      throw NextDNSError.noProfiles
    }
    return profile
  }

  private func upsert(_ entry: AllowListEntry) {
    if let index = entries.firstIndex(where: { $0.id == entry.id }) {
      entries[index] = entry
    } else {
      entries.append(entry)
    }
    entries.sort(by: sortEntries)
  }

  private func sortEntries(_ lhs: AllowListEntry, _ rhs: AllowListEntry) -> Bool {
    lhs.domain.localizedCaseInsensitiveCompare(rhs.domain) == .orderedAscending
  }

  private func handle(_ error: NextDNSError) {
    let now = Date()
    switch error {
    case .unauthorized:
      appState.authState = .unauthorized
      appState.profile = nil
      appState.setError(AppError(kind: .unauthorized, message: "Token invalid or expired", at: now))
    case .rateLimited:
      appState.setError(AppError(kind: .rateLimited, message: "Rate limited, retrying soon", at: now))
    case .offline:
      appState.setError(AppError(kind: .offline, message: "Offline, showing cached data", at: now))
    case .server:
      appState.setError(AppError(kind: .server, message: "Server error, retry later", at: now))
    case .decoding:
      appState.setError(AppError(kind: .unknown, message: "Unable to read response", at: now))
    case .noProfiles:
      appState.setError(AppError(kind: .unauthorized, message: "No profiles available", at: now))
    case .unexpected:
      appState.setError(AppError(kind: .unknown, message: "Something went wrong", at: now))
    }
  }
}
