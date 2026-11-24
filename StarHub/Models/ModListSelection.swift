import Foundation

/// I-T20 — la sélection multiple de la liste des mods.
///
/// Pur, sans SwiftUI ni AppKit : la vue traduit le geste (clic, ⌘clic,
/// ⇧clic, ⇧↑↓) en `ClickKind` et reçoit la sélection à teinter. Les
/// identifiants sont des chemins de dossier logiques. Les opérations
/// groupées filtrent les composants de pack en amont.
///
/// L’ordre passé est le cadrage complet, fourni par `ModListState.displayOrder`.
/// Un mod sorti du cadrage cesse de compter sans être oublié s’il y revient.
public struct ModListSelection: Equatable, Sendable {
    public enum ClickKind: Sendable { case plain, toggle, extend }

    public private(set) var selected: Set<String> = []
    /// Le point fixe des plages : le dernier mod cliqué sans ⇧.
    public private(set) var anchor: String?

    public init() {}

    public mutating func click(_ id: String, kind: ClickKind, in order: [String]) {
        switch kind {
        case .plain:
            selected = [id]
            anchor = id
        case .toggle:
            if selected.remove(id) == nil { selected.insert(id) }
            anchor = id
        case .extend:
            guard let anchor, let from = order.firstIndex(of: anchor),
                  let to = order.firstIndex(of: id) else {
                click(id, kind: .plain, in: order)
                return
            }
            selected = Set(order[min(from, to)...max(from, to)])
        }
    }

    public mutating func selectAll(_ order: [String]) {
        selected = Set(order)
        anchor = order.first
    }

    /// Imports the native table selection in visible row order.
    public mutating func replace(with ids: Set<String>, in order: [String]) {
        let visible = order.filter(ids.contains)
        selected = Set(visible)
        if anchor.map(selected.contains) != true { anchor = visible.first }
    }

    public mutating func clear() {
        selected = []
        anchor = nil
    }

    /// La sélection dans l'ordre du cadrage, sans ce qui en est sorti.
    public func members(in order: [String]) -> [String] {
        order.filter(selected.contains)
    }

    /// Les membres ; à défaut, la ligne courante — seulement si elle est
    /// affichée : repliée ou filtrée, un geste ne la toucherait pas à vue.
    public func effectiveMembers(in order: [String], current: String?) -> [String] {
        let members = members(in: order)
        guard members.isEmpty, let current, order.contains(current) else { return members }
        return [current]
    }

    /// Espace : un seul mod en pause dans la sélection, et tout s'active ;
    /// sinon tout se met en pause.
    public static func spaceEnables(_ mods: [ModItem]) -> Bool {
        mods.contains { !$0.isEnabled }
    }
}
