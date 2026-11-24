import AppKit
import SwiftUI

/// Champ natif permanent, placé au centre de la barre d’outils.
struct DiscoverySearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusRequest: Int
    let onSubmit: (String) -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.controlSize = .large
        field.sendsWholeSearchString = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        field.placeholderString = placeholder
        field.setAccessibilityLabel(placeholder)
        if field.stringValue != text { field.stringValue = text }
        if coordinator.lastFocusRequest != focusRequest, field.window?.makeFirstResponder(field) == true {
            coordinator.lastFocusRequest = focusRequest
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: DiscoverySearchField
        var lastFocusRequest: Int

        init(parent: DiscoverySearchField) {
            self.parent = parent
            lastFocusRequest = parent.focusRequest
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        @objc func submit(_ field: NSSearchField) {
            let query = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                parent.text = ""
            } else {
                parent.onSubmit(query)
            }
        }
    }
}
