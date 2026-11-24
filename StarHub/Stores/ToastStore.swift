import SwiftUI

/// Non-blocking, auto-dismissing toast notification store for transient
/// success feedback (e.g., mod or translation installation).
@MainActor
@Observable
final class ToastStore {
    struct ToastMessage: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let symbol: String
        let tint: Color
    }

    private(set) var current: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String,
              symbol: String = "checkmark.circle.fill",
              tint: Color = AppDesign.Color.success,
              duration: TimeInterval = 3.5) {
        dismissTask?.cancel()
        let toast = ToastMessage(message: message, symbol: symbol, tint: tint)
        withMotion(.snappy) {
            current = toast
        }
        let toastId = toast.id
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.dismiss(id: toastId)
        }
    }

    func dismiss(id: UUID? = nil) {
        if let id, current?.id != id { return }
        dismissTask?.cancel()
        dismissTask = nil
        withMotion(.snappy) {
            current = nil
        }
    }
}
