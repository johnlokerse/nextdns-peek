import SwiftUI

struct AllowListView: View {
  @ObservedObject var viewModel: AllowListViewModel
  @State private var newDomain = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      addRow
      listContent
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear {
      viewModel.loadAllowList()
    }
  }

  private var header: some View {
    HStack {
      Text("Allow List")
        .font(.headline)
      Spacer()
      if viewModel.isLoading {
        ProgressView()
          .scaleEffect(0.8)
      }
    }
  }

  private var addRow: some View {
    HStack(spacing: 8) {
      TextField("Add domain", text: $newDomain)

      Button("Add") {
        let domain = newDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
          let didAdd = await viewModel.addEntry(domain: domain)
          if didAdd {
            newDomain = ""
          }
        }
      }
      .disabled(!canAddDomain)
    }
  }

  private var listContent: some View {
    Group {
      if viewModel.entries.isEmpty && !viewModel.isLoading {
        Text("No allow list entries")
          .font(.caption)
          .foregroundColor(.secondary)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.entries) { entry in
              allowListRow(entry)
              Divider()
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .layoutPriority(1)
      }
    }
  }

  private func allowListRow(_ entry: AllowListEntry) -> some View {
    HStack(spacing: 12) {
      Text(entry.domain)
        .font(.subheadline)
        .lineLimit(1)

      Spacer()

      Toggle("", isOn: Binding(
        get: { entry.isEnabled },
        set: { viewModel.setEntryEnabled(entry, isEnabled: $0) }
      ))
      .toggleStyle(.switch)
      .labelsHidden()
      .disabled(viewModel.isEntryPending(entry))
    }
    .contextMenu {
      Button("Remove") {
        Task {
          await viewModel.removeEntry(entry)
        }
      }
    }
  }

  private var canAddDomain: Bool {
    !newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isWorking
  }
}
