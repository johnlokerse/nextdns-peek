import Foundation

struct Stats: Equatable {
  let range: TimeRange
  let requestsTotal: Int
  let blockedTotal: Int
  let blockRate: Double

  var blockRatePercent: String {
    let percent = blockRate * 100
    return String(format: "%.1f%%", percent)
  }
}
