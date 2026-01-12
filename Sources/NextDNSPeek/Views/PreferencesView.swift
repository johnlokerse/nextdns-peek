import SwiftUI

struct PreferencesView: View {
  @ObservedObject var viewModel: PreferencesViewModel
  @EnvironmentObject var appState: AppState

  private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
  }()

  var body: some View {
    Form {
      Section("API Token") {
        SecureField("Token", text: $viewModel.tokenInput)

        HStack {
          Button("Validate & Save") {
            viewModel.validateAndSave()
          }
          .disabled(viewModel.isWorking)

          Button("Remove Token") {
            viewModel.removeToken()
          }
          .disabled(!appState.hasToken)
        }

        if appState.hasToken {
          Button("Reload Profiles") {
            viewModel.loadProfiles()
          }
          .disabled(viewModel.isWorking)
        }

        if let statusMessage = viewModel.statusMessage {
          Text(statusMessage)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Section("Refresh") {
        Picker("Interval", selection: $appState.refreshInterval) {
          ForEach(RefreshInterval.allCases) { interval in
            Text(interval.displayName).tag(interval)
          }
        }

        Toggle("Refresh on click", isOn: $appState.refreshOnClick)

        Picker("Time Range", selection: $appState.timeRange) {
          ForEach(TimeRange.allCases) { range in
            Text(range.displayName).tag(range)
          }
        }
      }

      Section("Profile") {
        if appState.profiles.isEmpty {
          Text("No profiles loaded yet.")
            .font(.caption)
            .foregroundColor(.secondary)
        } else {
          Picker("Profile", selection: $appState.selectedProfileId) {
            ForEach(appState.profiles) { profile in
              Text(profile.name).tag(Optional(profile.id))
            }
          }
        }
      }

      Section("Privacy") {
        Toggle("Hide domains", isOn: $appState.privacyMode)
      }

      Section("Diagnostics") {
        HStack {
          Text("Last refresh")
          Spacer()
          Text(lastRefreshText)
            .foregroundColor(.secondary)
        }

        HStack {
          Text("Last error")
          Spacer()
          Text(lastErrorText)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(16)
    .frame(width: 420)
  }

  private var lastRefreshText: String {
    guard let lastRefresh = appState.lastRefreshAt else {
      return "Never"
    }
    return timestampFormatter.string(from: lastRefresh)
  }

  private var lastErrorText: String {
    guard let error = appState.lastError else {
      return "None"
    }
    return error.message
  }
}
