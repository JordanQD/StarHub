/// Keyboard navigation uses the ordered, visible results.
public enum ModListKeyStep {
    public enum Move: Sendable { case previous, next, first, last }

    public static func target(from current: String?, move: Move, in order: [String]) -> String? {
        let index = current.flatMap { order.firstIndex(of: $0) }
        switch (move, index) {
        case (.first, _), (.next, nil):
            return order.first
        case (.last, _), (.previous, nil):
            return order.last
        case (.next, let index?):
            return order.indices.contains(index + 1) ? order[index + 1] : nil
        case (.previous, let index?):
            return index > 0 ? order[index - 1] : nil
        }
    }
}
