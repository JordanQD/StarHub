import SwiftUI

extension ModListView {
    static let navigationKeys: Set<KeyEquivalent> = [.upArrow, .downArrow, .home, .end, .return,
                                                     .space, .escape, "a"]

    func handleListKey(_ press: KeyPress, order: [String], results: [ModItem],
                       proxy: ScrollViewProxy) -> KeyPress.Result {
        let move: ModListKeyStep.Move
        switch press.key {
        case .return:
            guard let id = vm.selectedModID,
                  order.contains(id),
                  let mod = results.first(where: { $0.folderName == id }) else { return .ignored }
            vm.navigationStore.setViewingModDetail(mod)
            return .handled
        case .space:
            return listState.toggleSelection(vm) ? .handled : .ignored
        case .escape:
            return clearModSelection() ? .handled : .ignored
        case "a":
            guard press.modifiers.contains(.command) else { return .ignored }
            listState.selection.selectAll(order)
            if vm.selectedModID.map(order.contains) != true {
                vm.selectedModID = order.first
            }
            return .handled
        case .upArrow: move = .previous
        case .downArrow: move = .next
        case .home: move = .first
        case .end: move = .last
        default: return .ignored
        }
        guard let target = ModListKeyStep.target(from: vm.selectedModID, move: move, in: order)
        else { return .handled }
        vm.selectedModID = target
        listState.selection.click(target,
                                  kind: press.modifiers.contains(.shift) ? .extend : .plain, in: order)
        proxy.scrollTo(target)
        return .handled
    }
}
