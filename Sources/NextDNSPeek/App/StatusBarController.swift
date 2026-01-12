import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
  private let statusItem: NSStatusItem
  private let popover: NSPopover
  private let appState: AppState
  private let dashboardViewModel: DashboardViewModel
  private let allowListViewModel: AllowListViewModel

  init(
    appState: AppState,
    dashboardViewModel: DashboardViewModel,
    allowListViewModel: AllowListViewModel,
    onOpenPreferences: @escaping () -> Void
  ) {
    self.appState = appState
    self.dashboardViewModel = dashboardViewModel
    self.allowListViewModel = allowListViewModel
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.isVisible = true
    popover = NSPopover()
    popover.behavior = .transient
    let popoverWidthScale: CGFloat = 1.35
    let popoverSize = NSSize(width: 380 * popoverWidthScale, height: 520)
    popover.contentSize = popoverSize
    popover.contentViewController = NSHostingController(
      rootView: DashboardView(
        viewModel: dashboardViewModel,
        allowListViewModel: allowListViewModel,
        contentWidth: popoverSize.width,
        contentHeight: popoverSize.height,
        onOpenPreferences: onOpenPreferences
      )
        .environmentObject(appState)
    )

    if let button = statusItem.button {
      let image = NSImage(
        systemSymbolName: "shield.lefthalf.filled",
        accessibilityDescription: "NextDNS Peek"
      ) ?? NSImage(systemSymbolName: "shield", accessibilityDescription: "NextDNS Peek")
        ?? NSImage(named: NSImage.statusAvailableName)

      if let image {
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        button.image = image
      } else {
        button.title = "NX"
      }

      button.toolTip = "NextDNS Peek"
      button.action = #selector(togglePopover(_:))
      button.target = self
    }
  }

  @objc private func togglePopover(_ sender: Any?) {
    guard let button = statusItem.button else {
      return
    }

    if popover.isShown {
      popover.performClose(sender)
    } else {
      if appState.refreshOnClick {
        dashboardViewModel.refresh(reason: .popoverOpen)
      }
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }
}
