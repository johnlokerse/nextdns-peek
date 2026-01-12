import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
  enum RefreshReason {
    case appLaunch
    case popoverOpen
    case manual
    case scheduled
  }

  @Published var stats: Stats?
  @Published var logs: [LogEntry] = []
  @Published var isLoading = false
  @Published var resolverStatus: ResolverStatus?

  private let appState: AppState
  private let client: NextDNSClient
  private let pingClient: NextDNSPingClient
  private var cancellables = Set<AnyCancellable>()
  private var timer: DispatchSourceTimer?
  private var rateLimitUntil: Date?
  private var refreshTask: Task<Void, Never>?

  private let throttleSeconds: TimeInterval = 15
  private let logLimit = 20

  init(appState: AppState, client: NextDNSClient, pingClient: NextDNSPingClient) {
    self.appState = appState
    self.client = client
    self.pingClient = pingClient

    appState.$refreshInterval
      .removeDuplicates { $0.rawValue == $1.rawValue }
      .sink { [weak self] interval in
        self?.scheduleTimer(interval)
      }
      .store(in: &cancellables)

    appState.$selectedProfileId
      .removeDuplicates()
      .sink { [weak self] _ in
        self?.refresh(reason: .manual)
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .tokenUpdated)
      .sink { [weak self] _ in
        self?.refresh(reason: .manual)
      }
      .store(in: &cancellables)
  }

  func refresh(reason: RefreshReason) {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      await self?.refreshAsync(reason: reason)
    }
  }

  private func refreshAsync(reason: RefreshReason) async {
    guard !isLoading else {
      return
    }

    let now = Date()
    if let lastRefresh = appState.lastRefreshAt,
       now.timeIntervalSince(lastRefresh) < throttleSeconds {
      return
    }

    if let rateLimitUntil, now < rateLimitUntil {
      appState.setError(AppError(kind: .rateLimited, message: "Rate limited, retrying soon", at: now))
      return
    }

    guard let token = appState.currentToken(), !token.isEmpty else {
      appState.authState = .missingToken
      appState.setError(AppError(kind: .unauthorized, message: "Missing API token", at: now))
      return
    }

    isLoading = true
    appState.setError(nil)

    defer {
      isLoading = false
    }

    do {
      let profile = try await ensureProfile(token: token)
      let result = try await fetchWithRetry(profileId: profile.id, token: token)

      stats = result.stats
      logs = result.logs
      resolverStatus = result.resolverStatus
      appState.lastRefreshAt = Date()
      appState.authState = .valid
      appState.profile = profile
    } catch let error as NextDNSError {
      handle(error)
    } catch {
      appState.setError(AppError(kind: .unknown, message: "Something went wrong", at: Date()))
    }
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

  private func fetchWithRetry(profileId: String, token: String) async throws -> (
    stats: Stats,
    logs: [LogEntry],
    resolverStatus: ResolverStatus?
  ) {
    do {
      return try await fetchAll(profileId: profileId, token: token)
    } catch NextDNSError.server {
      try await Task.sleep(nanoseconds: 2_000_000_000)
      return try await fetchAll(profileId: profileId, token: token)
    }
  }

  private func fetchAll(profileId: String, token: String) async throws -> (
    stats: Stats,
    logs: [LogEntry],
    resolverStatus: ResolverStatus?
  ) {
    async let stats = client.fetchStats(profileId: profileId, range: appState.timeRange, token: token)
    async let logs = client.fetchLogs(profileId: profileId, range: appState.timeRange, limit: logLimit, token: token)
    async let resolverStatus = pingClient.fetchCurrentResolver()
    return try await (stats, logs, resolverStatus)
  }

  private func handle(_ error: NextDNSError) {
    let now = Date()
    switch error {
    case .unauthorized:
      appState.authState = .unauthorized
      appState.profile = nil
      appState.setError(AppError(kind: .unauthorized, message: "Token invalid or expired", at: now))
    case .rateLimited(let retryAfter):
      let delay = retryAfter ?? 60
      rateLimitUntil = now.addingTimeInterval(delay)
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

  private func scheduleTimer(_ interval: RefreshInterval) {
    timer?.cancel()
    timer = nil

    guard let timeInterval = interval.timeInterval else {
      return
    }

    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + timeInterval, repeating: timeInterval)
    timer.setEventHandler { [weak self] in
      self?.refresh(reason: .scheduled)
    }
    timer.resume()
    self.timer = timer
  }
}
