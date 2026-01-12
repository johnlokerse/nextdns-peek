import Foundation

final class SettingsStore {
  private enum Keys {
    static let refreshInterval = "refreshInterval"
    static let refreshOnClick = "refreshOnClick"
    static let privacyMode = "privacyMode"
    static let timeRange = "timeRange"
    static let selectedProfileId = "selectedProfileId"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var refreshInterval: RefreshInterval {
    get {
      if let raw = defaults.string(forKey: Keys.refreshInterval),
         let value = RefreshInterval(rawValue: raw) {
        return value
      }
      return .fiveMinutes
    }
    set {
      defaults.set(newValue.rawValue, forKey: Keys.refreshInterval)
    }
  }

  var refreshOnClick: Bool {
    get {
      if let value = defaults.object(forKey: Keys.refreshOnClick) as? Bool {
        return value
      }
      return true
    }
    set {
      defaults.set(newValue, forKey: Keys.refreshOnClick)
    }
  }

  var privacyMode: Bool {
    get {
      defaults.bool(forKey: Keys.privacyMode)
    }
    set {
      defaults.set(newValue, forKey: Keys.privacyMode)
    }
  }

  var timeRange: TimeRange {
    get {
      if let raw = defaults.string(forKey: Keys.timeRange),
         let value = TimeRange(rawValue: raw) {
        return value
      }
      return .last24Hours
    }
    set {
      defaults.set(newValue.rawValue, forKey: Keys.timeRange)
    }
  }

  var selectedProfileId: String? {
    get {
      defaults.string(forKey: Keys.selectedProfileId)
    }
    set {
      defaults.set(newValue, forKey: Keys.selectedProfileId)
    }
  }
}
