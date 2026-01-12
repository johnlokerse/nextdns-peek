import SwiftUI

struct StatsSummaryView: View {
  let stats: Stats?

  private let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
  }()

  var body: some View {
    HStack(spacing: 12) {
      statColumn(title: "Requests", value: formatted(stats?.requestsTotal))
      statColumn(title: "Blocked", value: formatted(stats?.blockedTotal))
      statColumn(title: "Block Rate", value: stats?.blockRatePercent ?? "--")
    }
  }

  private func statColumn(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
      Text(value)
        .font(.headline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func formatted(_ value: Int?) -> String {
    guard let value else {
      return "--"
    }
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
  }
}
