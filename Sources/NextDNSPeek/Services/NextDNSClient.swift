import Foundation

enum NextDNSError: Error {
  case unauthorized
  case rateLimited(retryAfter: TimeInterval?)
  case server
  case offline
  case decoding
  case noProfiles
  case unexpected
}

final class NextDNSClient {
  private let baseURL: URL
  private let session: URLSession
  private let apiKeyHeader = "X-API-Key"

  init(
    baseURL: URL = URL(string: "https://api.nextdns.io")!,
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.session = session
  }

  func validateToken(_ token: String) async throws -> Profile {
    let profiles = try await fetchProfiles(token)
    guard let first = profiles.first else {
      throw NextDNSError.noProfiles
    }
    return first
  }

  func fetchProfiles(_ token: String) async throws -> [Profile] {
    let data = try await request(path: "profiles", queryItems: [], token: token)
    let profiles = try decodeProfiles(from: data)
    guard !profiles.isEmpty else {
      throw NextDNSError.noProfiles
    }
    return profiles
  }

  func fetchStats(profileId: String, range: TimeRange, token: String) async throws -> Stats {
    let data = try await request(
      path: "profiles/\(profileId)/analytics/status",
      queryItems: range.queryItems,
      token: token
    )
    return try decodeStats(from: data, range: range)
  }

  func fetchLogs(
    profileId: String,
    range: TimeRange,
    limit: Int,
    token: String
  ) async throws -> [LogEntry] {
    var queryItems = range.queryItems
    queryItems.append(URLQueryItem(name: "limit", value: String(limit)))

    let data = try await request(
      path: "profiles/\(profileId)/logs",
      queryItems: queryItems,
      token: token
    )
    return try decodeLogs(from: data)
  }

  func fetchAllowList(profileId: String, token: String) async throws -> [AllowListEntry] {
    let data = try await request(
      path: "profiles/\(profileId)/allowlist",
      queryItems: [],
      token: token
    )
    return try decodeAllowList(from: data)
  }

  func addAllowListEntry(
    profileId: String,
    domain: String,
    isEnabled: Bool,
    token: String
  ) async throws -> AllowListEntry {
    let payload: [String: Any] = ["id": domain, "active": isEnabled]
    let data = try await request(
      path: "profiles/\(profileId)/allowlist",
      method: "POST",
      queryItems: [],
      token: token,
      body: try JSONSerialization.data(withJSONObject: payload)
    )
    if data.isEmpty {
      return AllowListEntry(id: domain, domain: domain, isEnabled: isEnabled)
    }
    let entries = try decodeAllowList(from: data)
    if let first = entries.first {
      return first
    }
    return AllowListEntry(id: domain, domain: domain, isEnabled: isEnabled)
  }

  func updateAllowListEntry(
    profileId: String,
    entryId: String,
    isEnabled: Bool,
    token: String
  ) async throws -> AllowListEntry? {
    let payload = ["active": isEnabled]
    let data = try await request(
      path: "profiles/\(profileId)/allowlist/\(escapePathComponent(entryId))",
      method: "PATCH",
      queryItems: [],
      token: token,
      body: try JSONSerialization.data(withJSONObject: payload)
    )
    guard !data.isEmpty else {
      return nil
    }
    return try decodeAllowList(from: data).first
  }

  func removeAllowListEntry(profileId: String, entryId: String, token: String) async throws {
    _ = try await request(
      path: "profiles/\(profileId)/allowlist/\(escapePathComponent(entryId))",
      method: "DELETE",
      queryItems: [],
      token: token
    )
  }

  private func request(
    path: String,
    method: String = "GET",
    queryItems: [URLQueryItem],
    token: String,
    body: Data? = nil
  ) async throws -> Data {
    guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
      throw NextDNSError.unexpected
    }
    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    guard let url = components.url else {
      throw NextDNSError.unexpected
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue(token, forHTTPHeaderField: apiKeyHeader)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    request.timeoutInterval = 15

    do {
      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw NextDNSError.unexpected
      }

      switch httpResponse.statusCode {
      case 200 ... 299:
        return data
      case 401, 403:
        throw NextDNSError.unauthorized
      case 429:
        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
        throw NextDNSError.rateLimited(retryAfter: retryAfter)
      case 500 ... 599:
        throw NextDNSError.server
      default:
        throw NextDNSError.unexpected
      }
    } catch let error as URLError {
      if error.code == .notConnectedToInternet ||
          error.code == .networkConnectionLost ||
          error.code == .timedOut {
        throw NextDNSError.offline
      }
      throw NextDNSError.unexpected
    }
  }

  private func decodeProfiles(from data: Data) throws -> [Profile] {
    let json = try JSONSerialization.jsonObject(with: data)
    let profileObjects = extractArray(from: json) ?? []

    let profiles = profileObjects.compactMap { item -> Profile? in
      let id = stringValue(in: item, keys: ["id", "profile", "profileId"])
      guard let profileId = id else {
        return nil
      }
      let name = stringValue(in: item, keys: ["name", "profileName"]) ?? "Profile"
      return Profile(id: profileId, name: name)
    }
    return profiles
  }

  private func decodeAllowList(from data: Data) throws -> [AllowListEntry] {
    let json = try JSONSerialization.jsonObject(with: data)

    if let entries = extractArray(from: json) {
      let parsed = entries.compactMap { parseAllowListEntry(from: $0) }
      if !parsed.isEmpty {
        return parsed
      }
    }

    if let dict = json as? [String: Any],
       let entry = parseAllowListEntry(from: dict) {
      return [entry]
    }

    throw NextDNSError.decoding
  }

  private func decodeStats(from data: Data, range: TimeRange) throws -> Stats {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let rows = extractArray(from: json) else {
      throw NextDNSError.decoding
    }

    var requests = 0
    var blocked = 0

    for row in rows {
      let queries = findFirstInt(in: row, keys: ["queries", "count", "requests"]) ?? 0
      requests += queries
      if let status = stringValue(in: row, keys: ["status"])?.lowercased(),
         status == "blocked" {
        blocked += queries
      }
    }

    let blockRate = requests > 0 ? Double(blocked) / Double(requests) : 0
    return Stats(range: range, requestsTotal: requests, blockedTotal: blocked, blockRate: blockRate)
  }

  private func decodeLogs(from data: Data) throws -> [LogEntry] {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let entries = extractArray(from: json) else {
      throw NextDNSError.decoding
    }

    let formatter = ISO8601DateFormatter()

    return entries.compactMap { item in
      let timestampValue = value(in: item, keys: ["timestamp", "time", "ts"])
      let timestamp = parseDate(from: timestampValue, formatter: formatter) ?? Date()
      let domain = stringValue(in: item, keys: ["domain", "name", "qname", "host"]) ?? "unknown"
      let decisionRaw = stringValue(in: item, keys: ["decision", "status", "result", "action"]) ?? "allowed"
      let client = stringValue(in: item, keys: ["client", "client_name", "clientName"])
      let device = stringValue(in: item, keys: ["device", "device_name", "deviceName"])

      return LogEntry(
        timestamp: timestamp,
        domain: domain,
        decision: Decision(from: decisionRaw),
        client: client,
        device: device
      )
    }
  }

  private func extractArray(from json: Any) -> [[String: Any]]? {
    if let array = json as? [[String: Any]] {
      return array
    }
    if let dict = json as? [String: Any] {
      for key in ["data", "logs", "items", "results", "profiles", "allowlist", "allowList"] {
        if let array = dict[key] as? [[String: Any]] {
          return array
        }
      }
    }
    return nil
  }

  private func parseAllowListEntry(from dict: [String: Any]) -> AllowListEntry? {
    guard let id = stringValue(in: dict, keys: ["id", "domain", "name", "value", "host"]) else {
      return nil
    }
    let domain = stringValue(in: dict, keys: ["domain", "name", "value", "host"]) ?? id
    let isEnabled = boolValue(in: dict, keys: ["active", "enabled", "status"]) ?? true
    return AllowListEntry(id: id, domain: domain, isEnabled: isEnabled)
  }

  private func stringValue(in dict: [String: Any], keys: [String]) -> String? {
    for key in keys {
      if let value = dict[key] as? String {
        return value
      }
    }
    return nil
  }

  private func boolValue(in dict: [String: Any], keys: [String]) -> Bool? {
    for key in keys {
      if let value = dict[key] as? Bool {
        return value
      }
      if let value = dict[key] as? Int {
        return value != 0
      }
      if let value = dict[key] as? String {
        let normalized = value.lowercased()
        if ["true", "yes", "enabled", "1"].contains(normalized) {
          return true
        }
        if ["false", "no", "disabled", "0"].contains(normalized) {
          return false
        }
      }
    }
    return nil
  }

  private func value(in dict: [String: Any], keys: [String]) -> Any? {
    for key in keys {
      if let value = dict[key] {
        return value
      }
    }
    return nil
  }

  private func escapePathComponent(_ value: String) -> String {
    let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }

  private func findFirstInt(in json: Any, keys: [String]) -> Int? {
    if let dict = json as? [String: Any] {
      for key in keys {
        if let intValue = dict[key] as? Int {
          return intValue
        }
        if let stringValue = dict[key] as? String, let intValue = Int(stringValue) {
          return intValue
        }
      }
      for value in dict.values {
        if let found = findFirstInt(in: value, keys: keys) {
          return found
        }
      }
    } else if let array = json as? [Any] {
      for value in array {
        if let found = findFirstInt(in: value, keys: keys) {
          return found
        }
      }
    }
    return nil
  }

  private func parseDate(from value: Any?, formatter: ISO8601DateFormatter) -> Date? {
    if let doubleValue = value as? Double {
      return Date(timeIntervalSince1970: doubleValue)
    }
    if let intValue = value as? Int {
      return Date(timeIntervalSince1970: TimeInterval(intValue))
    }
    if let stringValue = value as? String {
      if let intValue = Int(stringValue) {
        return Date(timeIntervalSince1970: TimeInterval(intValue))
      }
      return formatter.date(from: stringValue)
    }
    return nil
  }
}
