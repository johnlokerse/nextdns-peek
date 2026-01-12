import Foundation

struct ResolverStatus: Equatable {
  let pop: String
  let ipVersion: Int?
  let latencyMs: Int?

  var popLabel: String {
    guard let ipVersion else {
      return pop
    }
    return "\(pop) (IPv\(ipVersion))"
  }

  var displayText: String {
    guard let latencyMs else {
      return popLabel
    }
    return "\(popLabel) - \(latencyMs) ms"
  }
}
