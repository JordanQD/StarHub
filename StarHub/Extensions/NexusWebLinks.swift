import AppKit

/// Ouverture des pages de recherche du **site** Nexus Mods — pas l'API :
/// une dépendance manquante ou un auteur n'a pas de fiche locale, la vue
/// délègue au navigateur. Mince wrapper AppKit : les URL elles-mêmes sont
/// construites par `MissingDependencies` (Core, testé), seul domicile —
/// avant la passe de simplification 2026-10-03, trois vues portaient une
/// copie identique et `MissingDependencies` une quatrième.
enum NexusWebLinks {
    /// Recherche plein texte du site pour un terme donné.
    static func openSearch(for searchTerm: String) {
        if let url = MissingDependencies.searchPage(for: searchTerm) {
            NSWorkspace.shared.open(url)
        }
    }

    /// La liste des mods d'un auteur. Le filtre `?author=` est plus précis
    /// qu'une recherche plein texte pour retrouver tous les mods d'un même
    /// auteur.
    static func openAuthorSearch(for author: String) {
        if let url = MissingDependencies.authorPage(for: author) {
            NSWorkspace.shared.open(url)
        }
    }

    static func updatePageID(for link: String) -> Int? {
        guard let url = URL(string: link),
              let host = url.host?.lowercased(), host == "nexusmods.com" || host == "www.nexusmods.com"
        else { return nil }
        let path = url.path.split(separator: "/")
        let page = path.first == "games" ? path.dropFirst() : path[...]
        guard page.count >= 3, page.first == "stardewvalley", page.dropFirst().first == "mods",
              let id = Int(page[page.index(page.startIndex, offsetBy: 2)]), id > 0
        else { return nil }
        return id
    }

    static func openUpdateFiles(for link: String) {
        guard var components = URLComponents(string: link),
              components.scheme == "https" || components.scheme == "http" else { return }
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "tab" }
            + [URLQueryItem(name: "tab", value: "files")]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }
}

extension NexusUpdateChecker.ModUpdate {
    var updateWebsite: URL? {
        let link = url.isEmpty ? ModManifest.parseNexusId(fromUpdateKeys: ["Nexus:\(nexusModId)"])?.url ?? "" : url
        guard let website = URL(string: link), let scheme = website.scheme?.lowercased(),
              scheme == "https" || scheme == "http", website.host != nil else { return nil }
        return website
    }

    var updatePageID: Int? {
        updateWebsite.flatMap { NexusWebLinks.updatePageID(for: $0.absoluteString) }
    }
}
