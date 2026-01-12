import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
  case lastHour
  case last24Hours

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .lastHour:
      return "Last Hour"
    case .last24Hours:
      return "Last 24 Hours"
    }
  }

  var duration: TimeInterval {
    switch self {
    case .lastHour:
      return 60 * 60
    case .last24Hours:
      return 24 * 60 * 60
    }
  }

  var queryItems: [URLQueryItem] {
    let now = Date()
    let from = now.addingTimeInterval(-duration)
    return [
      URLQueryItem(name: "from", value: String(Int(from.timeIntervalSince1970))),
      URLQueryItem(name: "to", value: String(Int(now.timeIntervalSince1970)))
    ]
  }
}
