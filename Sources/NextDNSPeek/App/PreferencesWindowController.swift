import Cocoa
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
  init(appState: AppState, viewModel: PreferencesViewModel) {
    let rootView = PreferencesView(viewModel: viewModel)
      .environmentObject(appState)
    let hostingController = NSHostingController(rootView: rootView)
    let window = NSWindow(contentViewController: hostingController)
    window.title = "Preferences"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.setContentSize(NSSize(width: 420, height: 480))
    window.isReleasedWhenClosed = false
    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
