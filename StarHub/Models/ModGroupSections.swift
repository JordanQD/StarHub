import Foundation

public enum ModGrouping: String, CaseIterable, Sendable { case none, groups, category }

public enum ModSectionKey: Hashable, Sendable {
    case group(UUID), ungrouped, category(Int), uncategorized

    public var collapseKey: String {
        switch self {
        case .group(let id): return id.uuidString
        case .ungrouped: return "group:none"
        case .category(let id): return "category:\(id)"
        case .uncategorized: return "category:none"
        }
    }
}

public struct ModListSectionModel: Equatable, Sendable {
    public let key: ModSectionKey
    public let title: String?
    public let mods: [ModItem]
    public let collapsed: Bool
    public var pausedCount: Int { mods.filter { !$0.isEnabled }.count }
}

/// Section order for the mod list and its selection.
public enum ModGroupSections {
    public static func sections(display: [ModItem], mode: ModGrouping, state: ModGroupsState,
                                category: (ModItem) -> (id: Int, name: String)?) -> [ModListSectionModel] {
        switch mode {
        case .none:
            return []   // la vue garde son rendu d'avant, sans sections
        case .groups:
            var byGroup: [UUID: [ModItem]] = [:]
            var ungrouped: [ModItem] = []
            for mod in display {
                if let id = state.group(of: mod.folderName)?.id { byGroup[id, default: []].append(mod) }
                else { ungrouped.append(mod) }
            }
            var out = state.groups.compactMap { group -> ModListSectionModel? in
                guard let mods = byGroup[group.id], !mods.isEmpty else { return nil }
                return ModListSectionModel(key: .group(group.id), title: group.name, mods: mods,
                                           collapsed: group.collapsed)
            }
            if !ungrouped.isEmpty {
                out.append(ModListSectionModel(key: .ungrouped, title: nil, mods: ungrouped,
                                               collapsed: state.collapsedCategories.contains("group:none")))
            }
            return out
        case .category:
            var byId: [Int: (name: String, mods: [ModItem])] = [:]
            var none: [ModItem] = []
            for mod in display {
                if let cat = category(mod) { byId[cat.id, default: (cat.name, [])].mods.append(mod) }
                else { none.append(mod) }
            }
            var out = byId.sorted { $0.value.name.localizedStandardCompare($1.value.name) == .orderedAscending }
                .map { id, entry in
                    ModListSectionModel(key: .category(id), title: entry.name, mods: entry.mods,
                                        collapsed: state.collapsedCategories.contains("category:\(id)"))
                }
            if !none.isEmpty {
                out.append(ModListSectionModel(key: .uncategorized, title: nil, mods: none,
                                               collapsed: state.collapsedCategories.contains("category:none")))
            }
            return out
        }
    }

    public static func navigationOrder(_ sections: [ModListSectionModel]) -> [String] {
        sections.filter { !$0.collapsed }.flatMap { $0.mods.map(\.folderName) }
    }
}
