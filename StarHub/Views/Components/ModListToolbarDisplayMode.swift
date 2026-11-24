import AppKit
import SwiftUI

/// SwiftUI owns the controls. AppKit provides the active window's display mode.
struct ModListToolbarDisplayMode: NSViewRepresentable {
    @Binding var showsLabels: Bool

    func makeNSView(context: Context) -> ObserverView {
        ObserverView(frame: .zero)
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.showsLabels = $showsLabels
    }

    static func dismantleNSView(_ view: ObserverView, coordinator: ()) {
        view.stopObserving()
    }

    final class ObserverView: NSView {
        var showsLabels: Binding<Bool>?
        private var timer: Timer?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard window != nil else { return }

            // NSToolbar.displayMode does not emit KVO when it changes.
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncDisplayMode() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        func stopObserving() {
            timer?.invalidate()
            timer = nil
        }

        private func syncDisplayMode() {
            guard let mode = window?.toolbar?.displayMode, let showsLabels else { return }
            let labels = mode == .iconAndLabel || mode == .labelOnly
            if showsLabels.wrappedValue != labels { showsLabels.wrappedValue = labels }
        }
    }
}
