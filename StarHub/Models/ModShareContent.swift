import Foundation

/// Shares public Nexus pages when possible, with mod details as a text fallback.
enum ModShareContent: Equatable {
    case links([URL])
    case text(String)

    static func make(for mods: [ModItem], customIDs: [String: String],
                     isPageUnavailable: (ModItem) -> Bool,
                     describe: (ModItem) -> String) -> Self? {
        guard !mods.isEmpty else { return nil }

        // A pack with its own source represents one release. An aggregate
        // without its own source can contain several independent releases.
        let entries = mods.flatMap { mod in
            if mod.isGroup, !mod.components.isEmpty,
               NexusModIdentity.effectiveId(for: mod, customIds: customIDs).isEmpty,
               mod.nexusUrl.isEmpty {
                return mod.components
            }
            return [mod]
        }.map { mod in
            (mod: mod, url: shareablePage(for: mod, customIDs: customIDs, isPageUnavailable: isPageUnavailable))
        }

        let urls = entries.compactMap(\.url)
        if urls.count == entries.count {
            var seen = Set<URL>()
            return .links(urls.filter { seen.insert($0).inserted })
        }

        return .text(entries.map { entry in
            let details = describe(entry.mod)
            guard let url = entry.url else { return details }
            return details + "\n" + url.absoluteString
        }.joined(separator: "\n\n"))
    }

    private static func shareablePage(for mod: ModItem, customIDs: [String: String],
                                      isPageUnavailable: (ModItem) -> Bool) -> URL? {
        guard let url = nexusPage(for: mod, customIDs: customIDs) else { return nil }
        if mod.isGroup {
            let unavailable = mod.components.contains {
                isPageUnavailable($0) && nexusPage(for: $0, customIDs: customIDs) == url
            }
            return unavailable ? nil : url
        }
        return isPageUnavailable(mod) ? nil : url
    }

    private static func nexusPage(for mod: ModItem, customIDs: [String: String]) -> URL? {
        let effectiveID = NexusModIdentity.effectiveId(for: mod, customIds: customIDs)
        if !effectiveID.isEmpty { return canonicalPage(id: effectiveID) }

        guard let components = URLComponents(string: mod.nexusUrl),
              let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = components.host?.lowercased(), host == "nexusmods.com" || host == "www.nexusmods.com",
              components.user == nil, components.password == nil, components.port == nil
        else { return nil }

        let path = components.path.split(separator: "/")
        let page = path.first == "games" ? path.dropFirst() : path[...]
        guard page.count == 3, page.first == "stardewvalley", page.dropFirst().first == "mods",
              let id = page.last else { return nil }
        return canonicalPage(id: String(id))
    }

    private static func canonicalPage(id: String) -> URL? {
        guard let number = Int(id), number > 0,
              let page = ModManifest.parseNexusId(fromUpdateKeys: ["Nexus:\(number)"])
        else { return nil }
        return URL(string: page.url)
    }
}
