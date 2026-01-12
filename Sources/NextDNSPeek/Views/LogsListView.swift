import SwiftUI

struct LogsListView: View {
  let logs: [LogEntry]
  let privacyMode: Bool
  @ObservedObject var allowListViewModel: AllowListViewModel

  private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Recent Logs")
        .font(.headline)

      if logs.isEmpty {
        Text("No recent logs")
          .font(.caption)
          .foregroundColor(.secondary)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(logs) { entry in
              Group {
                if entry.decision == .blocked {
                  logRow(entry)
                    .contextMenu {
                      Button("Add to Allow List") {
                        Task {
                          _ = await allowListViewModel.addEntry(domain: entry.domain)
                        }
                      }
                      .disabled(!canAddToAllowList(entry))
                    }
                } else {
                  logRow(entry)
                }
              }
              Divider()
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .layoutPriority(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func logRow(_ entry: LogEntry) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .top) {
        Text(timeFormatter.string(from: entry.timestamp))
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 60, alignment: .leading)

        VStack(alignment: .leading, spacing: 2) {
          Text(privacyMode ? "hidden" : entry.domain)
            .font(.subheadline)
            .lineLimit(1)

          HStack(spacing: 6) {
            Text(entry.decision == .blocked ? "Blocked" : "Allowed")
              .font(.caption)
              .foregroundColor(entry.decision == .blocked ? .red : .green)

            if let client = entry.client {
              Text(client)
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let device = entry.device {
              Text(device)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
  }

  private func canAddToAllowList(_ entry: LogEntry) -> Bool {
    guard entry.decision == .blocked else {
      return false
    }
    guard !privacyMode else {
      return false
    }
    guard !allowListViewModel.isWorking else {
      return false
    }
    let trimmedDomain = entry.domain.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDomain.isEmpty else {
      return false
    }
    return !allowListViewModel.containsDomain(trimmedDomain)
  }
}
