import AppKit
import SwiftUI

struct DashboardView: View {
  @ObservedObject var viewModel: DashboardViewModel
  @ObservedObject var allowListViewModel: AllowListViewModel
  @EnvironmentObject var appState: AppState
  let contentWidth: CGFloat
  let contentHeight: CGFloat
  let onOpenPreferences: () -> Void

  private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }()

  var body: some View {
    ZStack {
      backgroundGradient

      VStack(alignment: .leading, spacing: 12) {
        header

        if let error = appState.lastError {
          ErrorBannerView(error: error)
        }

        if !appState.hasToken {
          Text("Add your API token in Preferences to load data.")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        TabView {
          overviewTab
            .tabItem {
              Text("Overview")
            }

          allowListTab
            .tabItem {
              Text("Allow List")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
        .background(Color.clear)

        actions
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(width: contentWidth, height: contentHeight)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("NextDNS Peek")
            .font(.headline)
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(appState.profile?.name ?? "No profile")
              .font(.subheadline)
              .foregroundColor(.secondary)

            Spacer()

            if let resolverStatusText {
              Text(resolverStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer()
        if viewModel.isLoading {
          ProgressView()
            .scaleEffect(0.8)
        }
      }

      Text(lastUpdatedText)
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private var actions: some View {
    HStack {
      Button("Refresh") {
        viewModel.refresh(reason: .manual)
      }
      .disabled(viewModel.isLoading || !appState.hasToken)

      Button("Preferences...") {
        onOpenPreferences()
      }

      Spacer()

      Button("Quit") {
        NSApp.terminate(nil)
      }
    }
  }

  private var overviewTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      StatsSummaryView(stats: viewModel.stats)

      LogsListView(
        logs: viewModel.logs,
        privacyMode: appState.privacyMode,
        allowListViewModel: allowListViewModel
      )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var allowListTab: some View {
    AllowListView(viewModel: allowListViewModel)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var lastUpdatedText: String {
    if let lastUpdated = appState.lastRefreshAt {
      return "Last updated \(timestampFormatter.string(from: lastUpdated))"
    }
    return "Not updated yet"
  }

  private var resolverStatusText: String? {
    guard appState.profile != nil else {
      return nil
    }
    return viewModel.resolverStatus?.displayText
  }

  private var backgroundGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color(red: 0.08, green: 0.12, blue: 0.28, opacity: 0.22),
        Color(red: 0.08, green: 0.12, blue: 0.28, opacity: 0.05)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}
