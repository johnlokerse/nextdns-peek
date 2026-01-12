import Foundation

enum RefreshInterval: String, CaseIterable, Identifiable {
  case off
  case oneMinute
  case fiveMinutes
  case fifteenMinutes

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .off:
      return "Off"
    case .oneMinute:
      return "1 Minute"
    case .fiveMinutes:
      return "5 Minutes"
    case .fifteenMinutes:
      return "15 Minutes"
    }
  }

  var timeInterval: TimeInterval? {
    switch self {
    case .off:
      return nil
    case .oneMinute:
      return 60
    case .fiveMinutes:
      return 5 * 60
    case .fifteenMinutes:
      return 15 * 60
    }
  }
}
