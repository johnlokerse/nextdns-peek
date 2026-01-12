import Foundation

final class NextDNSPingClient {
  private let session: URLSession
  private let requestTimeout: TimeInterval = 2

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchCurrentResolver() async -> ResolverStatus? {
    guard let testResult = try? await fetchTestResult() else {
      return nil
    }

    if let status = testResult.status?.lowercased(), status == "unconfigured" {
      return nil
    }

    guard let pop = testResult.pop else {
      return nil
    }

    let candidates = buildHostCandidates(ipVersion: testResult.ipVersion, method: testResult.method)
    for candidate in candidates {
      guard let info = try? await fetchInfo(host: candidate.host) else {
        continue
      }

      if info.pop == pop {
        return ResolverStatus(pop: pop, ipVersion: candidate.ipVersion, latencyMs: info.latencyMs)
      }
    }

    return ResolverStatus(pop: pop, ipVersion: testResult.ipVersion, latencyMs: nil)
  }

  private struct TestResponse: Decodable {
    let status: String?
    let anycast: Bool?
    let server: String?
    let client: String?
    let resolver: String?
    let srcIP: String?
  }

  private struct TestResult {
    let status: String?
    let pop: String?
    let ipVersion: Int?
    let method: ResolverMethod?
  }

  private enum ResolverMethod {
    case anycast
    case ultralow
  }

  private struct InfoResponse: Decodable {
    let pop: String?
    let rtt: Int?
  }

  private struct InfoResult {
    let pop: String
    let latencyMs: Int?
  }

  private struct HostCandidate {
    let host: String
    let ipVersion: Int
  }

  private func fetchTestResult() async throws -> TestResult {
    let nonce = UUID().uuidString.lowercased()
    guard let url = URL(string: "https://\(nonce).test.nextdns.io/") else {
      throw URLError(.badURL)
    }

    let response: TestResponse = try await load(url: url)
    let pop = parsePop(from: response.server)
    let ipVersion = parseIpVersion(from: [response.client, response.resolver, response.srcIP])
    let method = response.anycast.map { $0 ? ResolverMethod.anycast : ResolverMethod.ultralow }
    return TestResult(status: response.status, pop: pop, ipVersion: ipVersion, method: method)
  }

  private func fetchInfo(host: String) async throws -> InfoResult? {
    guard let url = URL(string: "https://\(host)/info") else {
      return nil
    }

    let response: InfoResponse = try await load(url: url)
    guard let pop = response.pop else {
      return nil
    }

    let latencyMs = response.rtt.map { Int((Double($0) / 1000.0).rounded()) }
    return InfoResult(pop: pop, latencyMs: latencyMs)
  }

  private func buildHostCandidates(ipVersion: Int?, method: ResolverMethod?) -> [HostCandidate] {
    let ipVersions = ipVersion.flatMap { [normalizeIpVersion($0)] } ?? [4, 6]
    let methods = method.map { [$0] } ?? [.anycast, .ultralow]
    var candidates: [HostCandidate] = []

    for version in ipVersions {
      for index in [1, 2] {
        for method in methods {
          let host: String
          switch method {
          case .anycast:
            host = "ipv\(version)-anycast.dns\(index).nextdns.io"
          case .ultralow:
            host = "ipv\(version).dns\(index).nextdns.io"
          }
          candidates.append(HostCandidate(host: host, ipVersion: version))
        }
      }
    }

    return candidates
  }

  private func parsePop(from server: String?) -> String? {
    guard let server else {
      return nil
    }

    let parts = server.split(separator: "-")
    guard !parts.isEmpty else {
      return nil
    }

    if parts.count >= 2 {
      return "\(parts[0])-\(parts[1])"
    }

    return server
  }

  private func parseIpVersion(from values: [String?]) -> Int? {
    for value in values {
      guard let value, !value.isEmpty else {
        continue
      }
      return value.contains(":") ? 6 : 4
    }
    return nil
  }

  private func normalizeIpVersion(_ version: Int) -> Int {
    version == 6 ? 6 : 4
  }

  private func load<T: Decodable>(url: URL) async throws -> T {
    var request = URLRequest(url: url)
    request.timeoutInterval = requestTimeout

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          200 ... 299 ~= httpResponse.statusCode else {
      throw URLError(.badServerResponse)
    }

    return try JSONDecoder().decode(T.self, from: data)
  }
}
