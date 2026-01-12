import Foundation

struct LogEntry: Identifiable, Equatable {
  let id = UUID()
  let timestamp: Date
  let domain: String
  let decision: Decision
  let client: String?
  let device: String?
}

enum Decision: String {
  case blocked
  case allowed

  init(from value: String) {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.contains("block") {
      self = .blocked
    } else {
      self = .allowed
    }
  }
}
